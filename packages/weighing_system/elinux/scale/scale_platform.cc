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
		WeightData copy;
		uint32_t seq0, seq1;

		do
		{
			// 读取开始时的序列号
			seq0 = shared_weight_.seq.load(std::memory_order_acquire);

			// 如果序列号是奇数，说明 RT 线程正在写入，此时数据是撕裂的
			if (seq0 & 1)
			{
				// 发送 CPU yield/pause 指令，防止紧循环空转烤机
#if defined(__aarch64__) || defined(__arm__)
				asm volatile("yield" ::: "memory");
#elif defined(__x86_64__) || defined(__i386__)
				asm volatile("pause" ::: "memory");
#else
				std::this_thread::yield();
#endif
				continue;
			}

			// 快速深拷贝整个结构体
			copy = shared_weight_.data;

			// 读取结束时的序列号
			seq1 = shared_weight_.seq.load(std::memory_order_acquire);

			// 如果序列号发生改变，说明拷贝途中被 RT 线程篡改了，必须重试
		} while (seq0 != seq1 || (seq0 & 1));

		return copy;
	}

	void ScalePlatform::ProcessLoop()
	{
		AdcSample sample;
		while (running_.load(std::memory_order_acquire))
		{
			// 【新增】如果处于模拟模式，就不再去读真实的传感器ADC了，防止覆盖我们的假重量
			if (mock_mode_.load(std::memory_order_acquire))
			{
				std::this_thread::sleep_for(std::chrono::milliseconds(10));
				continue;
			}
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

	// 🚀 新增：计算单位转换倍率 (从标定单位 -> 目标工作单位)
	double GetUnitMultiplier(WeightUnit from, WeightUnit to)
	{
		auto to_kg = [](int u) -> double
		{
			switch (u)
			{
			case 0:
				return 0.001; // g
			case 1:
				return 1.0; // kg
			case 2:
				return 0.45359237; // lb
			case 3:
				return 1000.0; // t
			case 4:
				return 1000.0; // ton
			default:
				return 1.0;
			}
		};
		return to_kg(static_cast<int>(from)) / to_kg(static_cast<int>(to));
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
		double gross = weight_calc_raw_to_weight(&weight_calc_,
												 static_cast<double>(stkf_out));
		// double gross = weight;
		double net = weight_calc_get_net(&weight_calc_);

		// 🚀 核心修改：在四舍五入之前，将“标定单位”换算为用户需要的“显示单位”
		double factor = GetUnitMultiplier(params_.calibration_unit, static_cast<WeightUnit>(params_.primary_unit));
		gross *= factor;
		net *= factor;

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
		WeightData new_data;
		new_data.gross_weight = gross;
		new_data.net_weight = net;
		new_data.tare_weight = weight_calc_get_tare(&weight_calc_);
		new_data.motion = static_cast<MotionState>(is_stable ? 0 : 1);
		new_data.is_zero = std::abs(gross) < params_.division;
		new_data.is_overload = overload_.is_overload;
		new_data.is_underload = overload_.is_underload;
		new_data.is_net_mode = is_net;
		new_data.unit = static_cast<WeightUnit>(params_.primary_unit);
		new_data.timestamp_ns = sample.timestamp_ns;
		new_data.scale_id = scale_id_;

		// === SeqLock 写入序列 ===
		uint32_t current_seq = shared_weight_.seq.load(std::memory_order_relaxed);
		// 序列号加 1 (奇数)，标记开始写入
		shared_weight_.seq.store(current_seq + 1, std::memory_order_release);

		// 覆盖结构体
		shared_weight_.data = new_data;

		// 序列号再加 1 (偶数)，标记写入完成
		shared_weight_.seq.store(current_seq + 2, std::memory_order_release);

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

		static int print_divider_1 = 0;
		if (print_divider_1++ % 100 == 0)
		{ // 降频打印，每秒打印10次左右，防止日志刷屏卡死
			printf("[Probe-1 EtherCAT] Scale %d | Gross: %f | Raw ADC: %d\n",
				   sample.channel_id, GetWeightData().gross_weight, sample.raw_value);
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
		double gross = GetWeightData().gross_weight;
		return weight_calc_do_zero(&weight_calc_, gross, 100.0, 100.0);
	}

	bool ScalePlatform::DoPushbuttonZero()
	{
		if (!zero_cfg_.pushbutton_zero_enabled)
			return false;
		if (!stability_.is_stable)
			return false;
		double gross = GetWeightData().gross_weight;
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
		double gross = GetWeightData().gross_weight;
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

	// 【新增】开启/关闭模拟模式
	void ScalePlatform::SetMockMode(bool enable)
	{
		mock_mode_.store(enable, std::memory_order_release);
	}

	// 【新增】注入模拟数据
	void ScalePlatform::FeedMockWeight(double net_weight)
	{
		WeightData new_data;
		new_data.gross_weight = net_weight;
		new_data.net_weight = net_weight;
		new_data.tare_weight = 0.0;
		new_data.motion = static_cast<MotionState>(0); // 稳定
		new_data.is_zero = (net_weight <= 0.01);
		new_data.is_overload = false;
		new_data.is_underload = false;
		new_data.is_net_mode = false;
		new_data.unit = static_cast<WeightUnit>(params_.primary_unit);

		auto now = std::chrono::steady_clock::now().time_since_epoch();
		new_data.timestamp_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(now).count();
		new_data.scale_id = scale_id_;

		// === SeqLock 写入序列 ===
		uint32_t current_seq = shared_weight_.seq.load(std::memory_order_relaxed);
		shared_weight_.seq.store(current_seq + 1, std::memory_order_release);

		shared_weight_.data = new_data;

		shared_weight_.seq.store(current_seq + 2, std::memory_order_release);

		// 触发回调
		if (weight_callback_)
		{
			weight_callback_(GetWeightData());
		}
	}

} // namespace weighing