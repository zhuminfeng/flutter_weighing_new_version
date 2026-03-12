#include "liw_application.h"
#include <cmath>
#include <algorithm>

namespace weighing
{

	LiwApplication::LiwApplication(uint32_t subsystem_id)
		: AppBase(subsystem_id, AppType::kLossInWeight)
	{
		last_time_ = std::chrono::steady_clock::now();
		sample_start_ = last_time_;
	}

	LiwApplication::~LiwApplication()
	{
		Stop();
	}

	bool LiwApplication::Initialize()
	{
		// Apply controller config to PID
		PidConfig pid_cfg;
		pid_cfg.Kp = controller_config_.Kp;
		pid_cfg.Ki = controller_config_.Ki;
		pid_cfg.Kd = controller_config_.Kd;
		pid_cfg.max_flow = controller_config_.max_flow;
		pid_cfg.filter_window = controller_config_.filter_window;
		pid_cfg.safety_limit = system_config_.safety_limit;
		pid_.Initialize(pid_cfg, 1000.0f); // 1kHz control rate
		pid_.SetTarget(system_config_.target_flow);

		return true;
	}

	void LiwApplication::SetControllerConfig(const LiwControllerConfig &cfg)
	{
		controller_config_ = cfg;
		PidConfig pid_cfg;
		pid_cfg.Kp = cfg.Kp;
		pid_cfg.Ki = cfg.Ki;
		pid_cfg.Kd = cfg.Kd;
		pid_cfg.max_flow = cfg.max_flow;
		pid_cfg.filter_window = cfg.filter_window;
		pid_cfg.safety_limit = system_config_.safety_limit;
		pid_.Initialize(pid_cfg, 1000.0f);
	}

	void LiwApplication::Start()
	{
		batch_accumulated_ = 0.0;
		batch_fine_feed_ = false;
		batch_completed_ = false;
		prev_weight_ = current_weight_.load(std::memory_order_acquire);
		last_time_ = std::chrono::steady_clock::now();
		startup_start_ = last_time_;
		sample_start_ = last_time_;
		stats_.startup_accumulated = 0.0;
		is_in_startup_.store(controller_config_.startup_time > 0.0f);

		pid_.Reset();
		pid_.SetTarget(system_config_.target_flow);

		AppBase::Start(); // 内部调用 SetRunningOutput(true)
	}

	void LiwApplication::Stop()
	{
		SetControlRate(0.0f);
		AppBase::Stop(); // 内部调用 SetRunningOutput(false) + SetValveOutputs(0,false,...)
	}

	void LiwApplication::OnWeightUpdate(const WeightData &data)
	{
		current_weight_.store(data.gross_weight, std::memory_order_release);
		current_gross_.store(data.gross_weight, std::memory_order_release);
		current_net_.store(data.net_weight, std::memory_order_release);
		is_stable_.store(data.motion == MotionState::kStable, std::memory_order_release);
	}

	void LiwApplication::ProcessDioInputs(const DioInputSignals &inputs)
	{
		if (inputs.start && run_state_.load() == AppRunState::kIdle)
		{
			Start();
		}
		if (inputs.stop && run_state_.load() == AppRunState::kRunning)
		{
			Stop();
		}
		if (inputs.execute_refill)
		{
			TriggerManualRefill();
		}
		if (inputs.trigger_emptying)
		{
			TriggerEmptying();
		}

		if (advanced_config_.interlock_enabled)
		{
			interlock_active_ = inputs.interlock;
			if (!interlock_active_)
			{
				Stop();
			}
		}
	}

	float LiwApplication::CalculateFlow(float dt)
	{
		if (dt <= 0.0f)
			return 0.0f;

		double weight = current_weight_.load(std::memory_order_acquire);
		double weight_change = prev_weight_ - weight; // loss-in-weight: decreasing
		prev_weight_ = weight;

		// Convert to kg/h
		// weight_change is in kg over dt seconds
		float flow = static_cast<float>(weight_change / dt * 3600.0);

		if (flow < 0.0f)
			flow = 0.0f; // clamp negative (during refill)

		return flow;
	}

	void LiwApplication::ControlLoop()
	{
		auto now = std::chrono::steady_clock::now();
		float dt = std::chrono::duration<float>(now - last_time_).count();
		last_time_ = now;

		if (dt <= 0.0f || dt > 1.0f)
			return; // skip bad dt

		// Check interlock
		if (advanced_config_.interlock_enabled && !interlock_active_)
		{
			return;
		}

		// Check emptying
		if (is_emptying_.load())
		{
			double weight = current_weight_.load();
			float empty_rate = emptying_config_.control_setpoint;
			OutputManager::Instance().SetControlRate(subsystem_id_, empty_rate);

			if (weight <= system_config_.hopper_min)
			{
				if (emptying_config_.auto_stop_at_alarm)
				{
					is_emptying_.store(false);
					SetValveOutputs(0, false, false, false, false);
					OutputManager::Instance().SetControlRate(subsystem_id_, 0.0f);
					Stop();
				}
			}
			return;
		}

		// Check refill
		CheckRefill();
		if (is_refilling_.load())
		{
			// During refill: use refill control mode
			float refill_rate = 0.0f;
			switch (refill_config_.control_mode)
			{
			case RefillControlMode::kFixedOutput:
				refill_rate = refill_config_.control_setpoint;
				break;
			case RefillControlMode::kLastFrequency:
				refill_rate = static_cast<float>(refill_last_control_rate_);
				break;
			case RefillControlMode::kSmartAdapt:
				refill_rate = static_cast<float>(refill_last_control_rate_);
				break;
			}
			OutputManager::Instance().SetControlRate(subsystem_id_, refill_rate);

			{
				std::lock_guard<std::mutex> lock(status_mutex_);
				status_data_.control_rate = refill_rate;
				status_data_.current_weight = current_weight_.load();
			}
			return;
		}

		// Mode dispatch
		switch (base_config_.mode)
		{
		case LiwMode::kContinuous:
			if (base_config_.sub_mode == LiwSubMode::kFlowControl)
			{
				ContinuousFlowControlLoop(dt);
			}
			else
			{
				ContinuousFixedFreqLoop(dt);
			}
			break;
		case LiwMode::kBatch:
			BatchModeLoop(dt);
			break;
		case LiwMode::kSystemId:
			SystemIdLoop(dt);
			break;
		}

		// Warning checks
		CheckWarnings();

		// Statistics: sample weight accumulation
		float sample_elapsed = std::chrono::duration<float>(now - sample_start_).count();
		if (sample_elapsed >= stats_config_.sample_period)
		{
			stats_.sample_count++;
			sample_start_ = now;
		}
	}

	void LiwApplication::ContinuousFlowControlLoop(float dt)
	{
		float current_flow = CalculateFlow(dt);
		current_flow_ = current_flow;

		float control_rate;

		// Startup phase
		if (is_in_startup_.load())
		{
			float startup_elapsed = std::chrono::duration<float>(
										std::chrono::steady_clock::now() - startup_start_)
										.count();

			if (startup_elapsed < controller_config_.startup_time)
			{
				// Open-loop ramp during startup
				float ramp = startup_elapsed / controller_config_.startup_time;
				if (controller_config_.max_flow > 0)
				{
					control_rate = (system_config_.target_flow / controller_config_.max_flow) * 100.0f * ramp;
				}
				else
				{
					control_rate = 50.0f * ramp;
				}
			}
			else
			{
				is_in_startup_.store(false);
				control_rate = pid_.Process(current_flow, dt);
			}
		}
		else
		{
			control_rate = pid_.Process(current_flow, dt);
		}

		// Store last control rate for refill
		refill_last_control_rate_ = control_rate;

		// Apply output
		OutputManager::Instance().SetControlRate(subsystem_id_, control_rate);

		// Update statistics
		stats_.startup_accumulated += std::abs(current_flow * dt / 3600.0);
		stats_.total_accumulated += std::abs(current_flow * dt / 3600.0);

		// Update status
		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.current_flow = current_flow;
			status_data_.control_rate = control_rate;
			status_data_.target_flow = system_config_.target_flow;
			status_data_.current_weight = current_weight_.load();
			status_data_.accumulated_weight = stats_.startup_accumulated;
			status_data_.total_accumulated = stats_.total_accumulated;
		}
	}

	void LiwApplication::ContinuousFixedFreqLoop(float dt)
	{
		float current_flow = CalculateFlow(dt);
		current_flow_ = current_flow;

		float control_rate = system_config_.target_control_rate;
		refill_last_control_rate_ = control_rate;

		OutputManager::Instance().SetControlRate(subsystem_id_, control_rate);

		stats_.startup_accumulated += std::abs(current_flow * dt / 3600.0);
		stats_.total_accumulated += std::abs(current_flow * dt / 3600.0);

		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.current_flow = current_flow;
			status_data_.control_rate = control_rate;
			status_data_.current_weight = current_weight_.load();
			status_data_.accumulated_weight = stats_.startup_accumulated;
			status_data_.total_accumulated = stats_.total_accumulated;
		}
	}

	void LiwApplication::BatchModeLoop(float dt)
	{
		if (batch_completed_)
			return;

		float current_flow = CalculateFlow(dt);
		current_flow_ = current_flow;

		double batch_dispensed = stats_.startup_accumulated;
		double remaining = target_config_.batch_target - batch_dispensed;

		float control_rate;

		if (remaining <= target_config_.in_flight)
		{
			// Stop feeding - in-flight compensation
			control_rate = 0.0f;

			// Wait for stability then do tolerance check
			if (is_stable_.load())
			{
				double final_weight = stats_.startup_accumulated;
				double lower = target_config_.batch_target - tolerance_config_.tolerance;
				double upper = target_config_.batch_target + tolerance_config_.tolerance;

				batch_completed_ = true;

				if (final_weight >= lower && final_weight <= upper)
				{
					// In tolerance
					SetRunState(AppRunState::kCompleted);
				}
				else if (final_weight < lower)
				{
					EmitWarning("Below tolerance");
					SetRunState(AppRunState::kCompleted);
				}
				else
				{
					EmitWarning("Above tolerance");
					SetRunState(AppRunState::kCompleted);
				}
			}
		}
		else if (remaining <= (target_config_.in_flight + target_config_.fine_feed_threshold))
		{
			// Fine feed phase
			batch_fine_feed_ = true;
			pid_.SetTarget(target_config_.fine_feed_flow);
			control_rate = pid_.Process(current_flow, dt);
		}
		else
		{
			// Normal feed
			batch_fine_feed_ = false;
			pid_.SetTarget(system_config_.target_flow);
			control_rate = pid_.Process(current_flow, dt);
		}

		refill_last_control_rate_ = control_rate;
		OutputManager::Instance().SetControlRate(subsystem_id_, control_rate);

		stats_.startup_accumulated += std::abs(current_flow * dt / 3600.0);
		stats_.total_accumulated += std::abs(current_flow * dt / 3600.0);

		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.current_flow = current_flow;
			status_data_.control_rate = control_rate;
			status_data_.target_weight = target_config_.batch_target;
			status_data_.current_weight = current_weight_.load();
			status_data_.accumulated_weight = stats_.startup_accumulated;
			if (current_flow > 0.001)
			{
				status_data_.remaining_time = remaining / (current_flow / 3600.0);
			}
		}
	}

	void LiwApplication::SystemIdLoop(float dt)
	{
		auto now = std::chrono::steady_clock::now();

		if (sysid_step_ == 0)
		{
			// Start first step
			sysid_step_ = 1;
			sysid_current_rate_ = 0.0f;
			sysid_step_start_ = now;
			sysid_step_start_weight_ = current_weight_.load();
			OutputManager::Instance().SetControlRate(subsystem_id_, sysid_current_rate_);
		}

		float step_elapsed = std::chrono::duration<float>(now - sysid_step_start_).count();
		float step_dur = sysid_config_.step_duration;

		if (step_elapsed >= step_dur)
		{
			// Measure flow at current rate
			// double weight_change = sysid_step_start_weight_ - current_weight_.load();
			// double flow_at_rate = weight_change / step_elapsed * 3600.0; // kg/h

			// Advance to next step
			sysid_step_++;

			if (sysid_step_ > sysid_total_steps_)
			{
				// System ID complete
				SetRunState(AppRunState::kCompleted);
				OutputManager::Instance().SetControlRate(subsystem_id_, 0.0f);
				return;
			}

			// Calculate next test rate
			float range = sysid_config_.adjust_range_upper - sysid_config_.adjust_range_lower;
			float step_size = range / (sysid_total_steps_ - 1);
			sysid_current_rate_ = sysid_config_.adjust_range_lower +
								  step_size * (sysid_step_ - 1);

			sysid_step_start_ = now;
			sysid_step_start_weight_ = current_weight_.load();
			OutputManager::Instance().SetControlRate(subsystem_id_, sysid_current_rate_);

			// Check material level
			if (current_weight_.load() < system_config_.hopper_min)
			{
				// Need refill
				CheckRefill();
			}
		}

		float current_flow = CalculateFlow(dt);

		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.step_number = sysid_step_;
			status_data_.control_rate = sysid_current_rate_;
			status_data_.current_weight = current_weight_.load();
			status_data_.current_flow = current_flow;
		}
	}

	void LiwApplication::CheckRefill()
	{
		double weight = current_weight_.load();

		if (!is_refilling_.load())
		{
			if (weight <= refill_config_.lower_limit)
			{
				StartRefill();
			}
		}
		else
		{
			if (weight >= refill_config_.upper_limit)
			{
				EndRefill();
			}

			// Check refill timeout
			float refill_elapsed = std::chrono::duration<float>(
									   std::chrono::steady_clock::now() - refill_start_)
									   .count();
			if (refill_elapsed > warning_config_.refill_timeout)
			{
				EmitWarning("Refill timeout");
				if (warning_config_.stop_on_error)
				{
					EndRefill();
					Stop();
				}
			}
		}
	}

	void LiwApplication::StartRefill()
	{
		is_refilling_.store(true);
		refill_start_ = std::chrono::steady_clock::now();
		// 打开补料阀
		SetValveOutputs(0, false, false, true, false);
		SetRunState(AppRunState::kRefilling);
	}

	void LiwApplication::EndRefill()
	{
		is_refilling_.store(false);
		// 关闭补料阀
		SetValveOutputs(0, false, false, false, false);
		SetRunState(AppRunState::kRunning);
	}

	void LiwApplication::TriggerEmptying()
	{
		is_emptying_.store(true);
		// 打开排空阀
		SetValveOutputs(0, false, false, false, true);
		SetRunState(AppRunState::kEmptying);
	}

	void LiwApplication::CancelEmptying()
	{
		is_emptying_.store(false);
		// 关闭排空阀
		SetValveOutputs(0, false, false, false, false);
		SetRunState(AppRunState::kRunning);
	}

	void LiwApplication::TriggerManualRefill()
	{
		if (refill_config_.mode == RefillMode::kManual)
		{
			StartRefill();
		}
	}

	void LiwApplication::EndManualRefill()
	{
		if (refill_config_.mode == RefillMode::kManual)
		{
			EndRefill();
		}
	}

	void LiwApplication::CheckWarnings()
	{
		float rate = static_cast<float>(
			status_data_.control_rate);

		if (rate < warning_config_.control_rate_lower && rate > 0)
		{
			EmitWarning("Control rate below lower limit");
		}
		else if (rate > warning_config_.control_rate_upper)
		{
			EmitWarning("Control rate above upper limit");
		}

		double weight = current_weight_.load();
		if (weight >= system_config_.hopper_max)
		{
			EmitWarning("Hopper material above maximum");
			if (warning_config_.stop_on_error)
				Stop();
		}
		if (weight <= system_config_.hopper_min &&
			run_state_.load() == AppRunState::kRunning)
		{
			EmitWarning("Hopper material below minimum");
		}
	}

	void LiwApplication::ResetStatistics()
	{
		stats_ = LiwStatistics{};
		sample_start_ = std::chrono::steady_clock::now();
	}

} // namespace weighing