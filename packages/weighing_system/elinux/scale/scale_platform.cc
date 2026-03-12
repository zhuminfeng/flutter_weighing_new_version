#include "scale_platform.h"
#include <cstring>
#include <cmath>
#include <chrono>

namespace weighing
{

	ScalePlatform::ScalePlatform(uint32_t scale_id, float sample_rate)
		: scale_id_(scale_id), sample_rate_(sample_rate)
	{
		state_.store(ScaleState::kIdle, std::memory_order_release);
	}

	ScalePlatform::~ScalePlatform()
	{
		running_.store(false, std::memory_order_release);
		if (process_thread_.joinable())
		{
			process_thread_.join();
		}
	}

	bool ScalePlatform::Initialize(const ScaleParams &params, const ZeroConfig &zero_cfg,
								   const TareConfig &tare_cfg,
								   const FilterStabilityConfig &filter_cfg)
	{
		params_ = params;
		zero_cfg_ = zero_cfg;
		tare_cfg_ = tare_cfg;
		filter_cfg_ = filter_cfg;

		// Init STKF
		st_kalman_init(&stkf_, 0.0f, STF_DEFAULT_Q, STF_DEFAULT_R,
					   STF_DEFAULT_RHO, STF_DEFAULT_BETA);

		// Init stability detector
		stability_init(&stability_, static_cast<float>(params.division),
					   static_cast<float>(filter_cfg.motion_range_d),
					   static_cast<float>(filter_cfg.motion_detect_time),
					   static_cast<float>(filter_cfg.stability_timeout),
					   sample_rate_);

		// Init zero tracking
		zt_mode_t zt_mode;
		switch (zero_cfg.auto_zero_mode)
		{
		case AutoZeroMode::kOff:
			zt_mode = ZT_MODE_OFF;
			break;
		case AutoZeroMode::kGross:
			zt_mode = ZT_MODE_GROSS;
			break;
		case AutoZeroMode::kGrossAndNet:
			zt_mode = ZT_MODE_GROSS_AND_NET;
			break;
		default:
			zt_mode = ZT_MODE_GROSS;
			break;
		}
		zero_tracking_init(&zero_tracker_, static_cast<float>(params.division),
						   zt_mode, static_cast<float>(zero_cfg.auto_zero_range_d));

		// Init overload detector
		overload_init(&overload_, static_cast<float>(params.capacity),
					  static_cast<float>(params.division),
					  params.overload_range,
					  static_cast<float>(zero_cfg.underload_range_d));

		// Init weight calculator
		weight_calc_init(&weight_calc_, params.capacity, params.division);

		// Init calibration engine
		cal_engine_init(&cal_engine_);

		// Init filter engine
		filter_engine_init(&filter_engine_, sample_rate_,
						   static_cast<float>(params.division));
		filter_set_lowpass(&filter_engine_,
						   static_cast<filter_lp_level_t>(filter_cfg.low_pass_level));
		if (filter_cfg.notch_enabled)
		{
			filter_set_notch(&filter_engine_, true,
							 static_cast<float>(filter_cfg.notch_frequency));
		}
		if (filter_cfg.adaptive_enabled)
		{
			filter_set_adaptive(&filter_engine_, true,
								static_cast<float>(filter_cfg.adaptive_range_d));
		}

		// Start processing thread
		running_.store(true, std::memory_order_release);
		process_thread_ = std::thread(&ScalePlatform::ProcessLoop, this);

		UpdateState(ScaleState::kRunning, "Scale initialized");
		return true;
	}

	void ScalePlatform::FeedAdcSample(const AdcSample &sample)
	{
		adc_buffer_.push(sample);
	}

	WeightData ScalePlatform::GetWeightData() const
	{
		WeightData data;
		data.gross_weight = atomic_weight_.gross_weight.load(std::memory_order_acquire);
		data.net_weight = atomic_weight_.net_weight.load(std::memory_order_acquire);
		data.tare_weight = atomic_weight_.tare_weight.load(std::memory_order_acquire);
		data.motion = static_cast<MotionState>(
			atomic_weight_.motion.load(std::memory_order_acquire));
		data.is_zero = atomic_weight_.is_zero.load(std::memory_order_acquire);
		data.is_overload = atomic_weight_.is_overload.load(std::memory_order_acquire);
		data.is_underload = atomic_weight_.is_underload.load(std::memory_order_acquire);
		data.is_net_mode = atomic_weight_.is_net_mode.load(std::memory_order_acquire);
		data.unit = static_cast<WeightUnit>(
			atomic_weight_.unit.load(std::memory_order_acquire));
		data.timestamp_ns = atomic_weight_.timestamp_ns.load(std::memory_order_acquire);
		data.scale_id = scale_id_;
		return data;
	}

	void ScalePlatform::ProcessLoop()
	{
		AdcSample sample;
		while (running_.load(std::memory_order_acquire))
		{
			if (adc_buffer_.pop(sample))
			{
				ProcessingSample(sample);
			}
			else
			{
				// No data, brief sleep to avoid busy-wait
				std::this_thread::sleep_for(std::chrono::microseconds(100));
			}
		}
	}

	void ScalePlatform::ProcessingSample(const AdcSample &sample)
	{
		// Check ADC status
		if (sample.status != 0)
		{
			// ADC error - report but continue with last known value
			if (sample.status == 1)
			{
				UpdateState(ScaleState::kError, "ADC timeout");
			}
			else if (sample.status == 2)
			{
				UpdateState(ScaleState::kError, "ADC disconnected");
			}
			else if (sample.status == 3)
			{
				UpdateState(ScaleState::kError, "ADC overrange");
			}
			return;
		}

		float raw_f = static_cast<float>(sample.raw_value);

		// 1. Pre-filtering (low-pass + notch + adaptive)
		float filtered = filter_engine_process(&filter_engine_, raw_f);

		// 2. STKF filtering
		float stkf_out = st_kalman_process(&stkf_, filtered);

		// 3. Feed to calibration engine if calibrating
		if (cal_engine_.state != CAL_STATE_IDLE &&
			cal_engine_.state != CAL_STATE_FAILED)
		{
			bool stable = stability_.is_stable;
			cal_engine_feed_sample(&cal_engine_, static_cast<double>(stkf_out), stable);

			// Check calibration state transitions
			CalibrationState dart_state;
			switch (cal_engine_.state)
			{
			case CAL_STATE_ZERO_COMPLETE:
				dart_state = CalibrationState::kCompleted;
				break;
			case CAL_STATE_SPAN_COMPLETE:
				dart_state = CalibrationState::kCompleted;
				break;
			case CAL_STATE_DYNAMIC_COMPLETE:
				dart_state = CalibrationState::kDynamicCompleted;
				break;
			case CAL_STATE_FAILED:
				dart_state = CalibrationState::kFailed;
				break;
			default:
				dart_state = CalibrationState::kInProgress;
				break;
			}

			if (cal_callback_)
			{
				cal_callback_(scale_id_, dart_state, cal_engine_.error_msg);
			}
		}

		// 4. Weight calculation
		// double weight = weight_calc_raw_to_weight(&weight_calc_,
		//   static_cast<double>(stkf_out));
		double gross = weight_calc_get_gross(&weight_calc_);
		double net = weight_calc_get_net(&weight_calc_);

		// 5. Round to division
		gross = weight_calc_round_to_division(&weight_calc_, gross);
		net = weight_calc_round_to_division(&weight_calc_, net);

		// 6. Stability detection
		bool is_stable = stability_update(&stability_, static_cast<float>(gross));

		// 7. Zero tracking
		bool is_net = weight_calc_is_net_mode(&weight_calc_);
		// float zt_weight = zero_tracking_update(&zero_tracker_,
		// 									   static_cast<float>(gross),
		// 									   is_stable, is_net);

		// 8. Overload/underload detection
		overload_update(&overload_, static_cast<float>(gross), 0.0f);

		// 9. Update atomic weight data
		atomic_weight_.gross_weight.store(gross, std::memory_order_release);
		atomic_weight_.net_weight.store(net, std::memory_order_release);
		atomic_weight_.tare_weight.store(weight_calc_get_tare(&weight_calc_),
										 std::memory_order_release);
		atomic_weight_.motion.store(is_stable ? 0 : 1, std::memory_order_release);
		atomic_weight_.is_zero.store(std::abs(gross) < params_.division,
									 std::memory_order_release);
		atomic_weight_.is_overload.store(overload_.is_overload, std::memory_order_release);
		atomic_weight_.is_underload.store(overload_.is_underload, std::memory_order_release);
		atomic_weight_.is_net_mode.store(is_net, std::memory_order_release);
		atomic_weight_.unit.store(static_cast<int>(params_.primary_unit),
								  std::memory_order_release);
		atomic_weight_.timestamp_ns.store(sample.timestamp_ns, std::memory_order_release);

		// Update state
		if (overload_.is_overload)
		{
			UpdateState(ScaleState::kOverload);
		}
		else if (overload_.is_underload)
		{
			UpdateState(ScaleState::kUnderload);
		}
		else if (state_.load(std::memory_order_acquire) != ScaleState::kCalibrating)
		{
			UpdateState(ScaleState::kRunning);
		}

		// Notify callback
		if (weight_callback_)
		{
			weight_callback_(GetWeightData());
		}
	}

	// === Scale operations ===

	bool ScalePlatform::DoZero()
	{
		if (!stability_.is_stable)
			return false;
		double gross = atomic_weight_.gross_weight.load(std::memory_order_acquire);
		return weight_calc_do_zero(&weight_calc_, gross, 100.0, 100.0);
	}

	bool ScalePlatform::DoPushbuttonZero()
	{
		if (!zero_cfg_.pushbutton_zero_enabled)
			return false;
		if (!stability_.is_stable)
			return false;
		double gross = atomic_weight_.gross_weight.load(std::memory_order_acquire);
		return weight_calc_do_zero(&weight_calc_, gross,
								   zero_cfg_.pushbutton_zero_pos_pct,
								   zero_cfg_.pushbutton_zero_neg_pct);
	}

	bool ScalePlatform::DoTare()
	{
		if (!tare_cfg_.pushbutton_tare_enabled)
			return false;
		if (!stability_.is_stable)
			return false;
		double gross = atomic_weight_.gross_weight.load(std::memory_order_acquire);
		return weight_calc_do_tare(&weight_calc_, gross);
	}

	void ScalePlatform::SetPresetTare(double value)
	{
		if (!tare_cfg_.preset_tare_enabled)
			return;
		weight_calc_set_preset_tare(&weight_calc_, value);
	}

	void ScalePlatform::ClearTare()
	{
		weight_calc_clear_tare(&weight_calc_);
	}

	// === Calibration ===

	void ScalePlatform::StartZeroCalibration()
	{
		UpdateState(ScaleState::kCalibrating, "Zero calibration started");
		cal_engine_start_zero(&cal_engine_);
	}

	void ScalePlatform::StartSpanCalibration(int linear_mode, const double *test_loads,
											 int num_loads)
	{
		UpdateState(ScaleState::kCalibrating, "Span calibration started");
		cal_engine_start_span(&cal_engine_, linear_mode, test_loads, num_loads);
	}

	void ScalePlatform::CalibrationAddLoad()
	{
		cal_engine_step_add_load(&cal_engine_);
	}

	void ScalePlatform::AcceptDynamicCalibration(bool accept)
	{
		cal_engine_accept_dynamic(&cal_engine_, accept);
	}

	void ScalePlatform::StartStepCalibration(double test_weight)
	{
		UpdateState(ScaleState::kCalibrating, "Step calibration started");
		cal_engine_start_step(&cal_engine_, test_weight);
	}

	void ScalePlatform::StepRemoveConfirm()
	{
		cal_engine_step_remove_confirm(&cal_engine_);
	}

	void ScalePlatform::StepSubstituteConfirm(double substitute_weight)
	{
		cal_engine_step_substitute_confirm(&cal_engine_, substitute_weight);
	}

	void ScalePlatform::StepAddLoad()
	{
		cal_engine_step_add_load(&cal_engine_);
	}

	bool ScalePlatform::SaveCalibration()
	{
		if (!cal_engine_is_complete(&cal_engine_))
			return false;

		// Transfer calibration data
		cal_data_.zero_raw = cal_engine_.zero_raw;
		cal_data_.span_points.clear();
		for (int i = 0; i < cal_engine_.current_span_idx; i++)
		{
			CalPoint pt;
			pt.test_load = cal_engine_.span_weight[i];
			pt.raw_reading = cal_engine_.span_raw[i];
			cal_data_.span_points.push_back(pt);
		}
		cal_data_.is_valid = true;

		// Apply to weight calculator
		weight_calc_clear_calibration(&weight_calc_);
		weight_calc_set_zero_cal(&weight_calc_, cal_data_.zero_raw);
		for (const auto &pt : cal_data_.span_points)
		{
			weight_calc_add_span_point(&weight_calc_, pt.raw_reading, pt.test_load);
		}
		weight_calc_compute_linearization(&weight_calc_);

		UpdateState(ScaleState::kRunning, "Calibration saved");
		cal_engine_init(&cal_engine_);
		return true;
	}

	void ScalePlatform::AbortCalibration()
	{
		cal_engine_abort(&cal_engine_);
		UpdateState(ScaleState::kRunning, "Calibration aborted");
	}

	CalibrationState ScalePlatform::GetCalibrationState() const
	{
		switch (cal_engine_.state)
		{
		case CAL_STATE_IDLE:
			return CalibrationState::kIdle;
		case CAL_STATE_ZERO_COMPLETE:
		case CAL_STATE_SPAN_COMPLETE:
		case CAL_STATE_STEP_COMPLETE:
			return CalibrationState::kCompleted;
		case CAL_STATE_DYNAMIC_COMPLETE:
			return CalibrationState::kDynamicCompleted;
		case CAL_STATE_FAILED:
			return CalibrationState::kFailed;
		default:
			return CalibrationState::kInProgress;
		}
	}

	// === Config updates ===

	void ScalePlatform::UpdateScaleParams(const ScaleParams &params)
	{
		params_ = params;
		weight_calc_.capacity = params.capacity;
		weight_calc_.division = params.division;
		overload_set_params(&overload_, static_cast<float>(params.capacity),
							static_cast<float>(params.division),
							params.overload_range,
							static_cast<float>(zero_cfg_.underload_range_d));
	}

	void ScalePlatform::UpdateZeroConfig(const ZeroConfig &cfg)
	{
		zero_cfg_ = cfg;
		zt_mode_t zt_mode;
		switch (cfg.auto_zero_mode)
		{
		case AutoZeroMode::kOff:
			zt_mode = ZT_MODE_OFF;
			break;
		case AutoZeroMode::kGross:
			zt_mode = ZT_MODE_GROSS;
			break;
		case AutoZeroMode::kGrossAndNet:
			zt_mode = ZT_MODE_GROSS_AND_NET;
			break;
		default:
			zt_mode = ZT_MODE_GROSS;
			break;
		}
		zero_tracking_init(&zero_tracker_, static_cast<float>(params_.division),
						   zt_mode, static_cast<float>(cfg.auto_zero_range_d));
	}

	void ScalePlatform::UpdateTareConfig(const TareConfig &cfg)
	{
		tare_cfg_ = cfg;
	}

	void ScalePlatform::UpdateFilterStability(const FilterStabilityConfig &cfg)
	{
		filter_cfg_ = cfg;
		filter_set_lowpass(&filter_engine_,
						   static_cast<filter_lp_level_t>(cfg.low_pass_level));
		filter_set_notch(&filter_engine_, cfg.notch_enabled,
						 static_cast<float>(cfg.notch_frequency));
		filter_set_adaptive(&filter_engine_, cfg.adaptive_enabled,
							static_cast<float>(cfg.adaptive_range_d));
		stability_init(&stability_, static_cast<float>(params_.division),
					   static_cast<float>(cfg.motion_range_d),
					   static_cast<float>(cfg.motion_detect_time),
					   static_cast<float>(cfg.stability_timeout),
					   sample_rate_);
	}

	void ScalePlatform::LoadCalibrationData(const CalibrationData &data)
	{
		cal_data_ = data;
		if (data.is_valid)
		{
			weight_calc_clear_calibration(&weight_calc_);
			weight_calc_set_zero_cal(&weight_calc_, data.zero_raw);
			for (const auto &pt : data.span_points)
			{
				weight_calc_add_span_point(&weight_calc_, pt.raw_reading, pt.test_load);
			}
			weight_calc_compute_linearization(&weight_calc_);
		}
	}

	void ScalePlatform::UpdateState(ScaleState new_state, const std::string &msg)
	{
		ScaleState old_state = state_.exchange(new_state, std::memory_order_acq_rel);
		if (old_state != new_state && status_callback_)
		{
			status_callback_(scale_id_, new_state, msg);
		}
	}

} // namespace weighing