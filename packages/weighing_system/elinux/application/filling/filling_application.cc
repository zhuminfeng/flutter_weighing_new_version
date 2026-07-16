#include "filling_application.h"
#include <cmath>
#include <algorithm>

namespace weighing
{

	FillingApplication::FillingApplication(uint32_t subsystem_id)
		: AppBase(subsystem_id, AppType::kFilling)
	{
		last_time_ = std::chrono::steady_clock::now();
		effective_in_flight_ = 0.0;
	}

	FillingApplication::~FillingApplication()
	{
		Stop();
	}

	bool FillingApplication::Initialize()
	{
		effective_in_flight_ = target_config_.in_flight;
		return true;
	}

	void FillingApplication::Start()
	{
		feed_start_weight_ = 0.0;
		current_dispensed_ = 0.0;
		tolerance_result_ = ToleranceResult::kNotChecked;
		jog_cycles_ = 0;
		jog_active_ = false;
		cycle_count_ = 0;

		last_time_ = std::chrono::steady_clock::now();
		process_start_ = last_time_;

		SetPhase(FillingPhase::kRunning);
		AppBase::Start(); // 内部调用 SetRunningOutput(true)
	}

	void FillingApplication::Stop()
	{
		StopFeeding();
		SetRefillValve(false);
		SetPhase(FillingPhase::kIdle);
		AppBase::Stop(); // 内部调用 SetRunningOutput(false) 等
	}

	void FillingApplication::OnWeightUpdate(const WeightData &data)
	{
		current_weight_.store(data.gross_weight, std::memory_order_release);
		current_gross_.store(data.gross_weight, std::memory_order_release);
		current_net_.store(data.net_weight, std::memory_order_release);
		is_stable_.store(data.motion == MotionState::kStable, std::memory_order_release);
	}

	void FillingApplication::ProcessDioInputs(const DioInputSignals &inputs)
	{
		if (inputs.start && run_state_.load() == AppRunState::kIdle)
		{
			Start();
		}
		if (inputs.stop && run_state_.load() == AppRunState::kRunning)
		{
			Stop();
		}

		if (advanced_config_.interlock_enabled)
		{
			interlock_active_ = inputs.interlock;
			if (!interlock_active_)
			{
				StopFeeding();
			}
		}
	}

	void FillingApplication::SetPhase(FillingPhase phase)
	{
		phase_.store(phase, std::memory_order_release);
		phase_start_ = std::chrono::steady_clock::now();
	}

	// ======== 阀门控制：通过 OutputManager ========

	void FillingApplication::SetRefillValve(bool open)
	{
		// channel 0 的 refill 阀门
		// fast=false, slow=false, refill=open, emptying=false
		// 注意：不影响 feed 阀门状态，需要保持当前 feed 状态
		// 这里简化为独立控制 refill 位
		// SetValveOutputs(0, false, false, open, false);
		SetOutputSignal(DigitalSignalType::kRefillValve, open);
	}

	void FillingApplication::StartFeeding()
	{
		if (system_config_.work_mode == FillingWorkMode::kDispense ||
			system_config_.work_mode == FillingWorkMode::kRefillAndDispense)
		{
			feed_start_weight_ = current_weight_.load();
		}
		else
		{
			feed_start_weight_ = current_net_.load();
		}
		current_dispensed_ = 0.0;
	}

	void FillingApplication::StopFeeding()
	{
		// 关闭所有进料阀门 + 伺服停止
		StopAllOutputs();
	}

	void FillingApplication::StartFastFeed()
	{
		// 判断是否为并行输出：如果是并行，则在快加料阶段也同时打开细加料(slow)阀门
		bool is_parallel = (system_config_.output_type == OutputType::kParallel);

		// fast = true, slow = is_parallel
		SetOutputSignal(DigitalSignalType::kFeedFast, true);
		SetOutputSignal(DigitalSignalType::kFeedSlow, is_parallel);
		SetServoRate(DigitalSignalType::kFeedFast, static_cast<float>(advanced_config_.fast_feed_speed));
		if (is_parallel)
		{
			// 并行模式：快、慢两个电机同时以各自的目标速度运转
			SetServoRate(DigitalSignalType::kFeedSlow, static_cast<float>(advanced_config_.fine_feed_speed));
		}
		else
		{
			// 独立模式：快加料阶段慢加料电机必须停转
			SetServoRate(DigitalSignalType::kFeedSlow, 0.0f);
		}
	}

	void FillingApplication::StartFineFeed()
	{
		// 无论是并行还是独立输出，在细加料(FineFeed)阶段，只有慢阀(slow)开启
		// fast = false, slow = true (此函数保持不变)
		SetOutputSignal(DigitalSignalType::kFeedFast, false);
		SetOutputSignal(DigitalSignalType::kFeedSlow, true);

		// 快加料电机停转，慢加料电机运行
		SetServoRate(DigitalSignalType::kFeedFast, 0.0f);
		SetServoRate(DigitalSignalType::kFeedSlow, static_cast<float>(advanced_config_.fine_feed_speed));
	}

	bool FillingApplication::CheckMaterialSufficient()
	{
		if (system_config_.work_mode == FillingWorkMode::kDispense ||
			system_config_.work_mode == FillingWorkMode::kRefillAndDispense)
		{
			double source_weight = current_weight_.load();
			return source_weight >= target_config_.target_value;
		}
		return true;
	}

	// // === 新增：全电动伺服夹松袋动作控制 ===
	// void FillingApplication::ClampBag()
	// {
	// 	// 控制夹袋伺服机构运动到绝对位置编码器值（位置控制模式）
	// 	SetServoPosition(DigitalSignalType::kBagClamp, advanced_config_.bag_clamp_close_pos);
	// }

	// void FillingApplication::ReleaseBag()
	// {
	// 	// 控制夹袋伺服机构恢复到零位/松开位
	// 	SetServoPosition(DigitalSignalType::kBagClamp, advanced_config_.bag_clamp_open_pos);
	// }

	// ======== Spill & Cutoff Optimization ========

	void FillingApplication::UpdateSpillOptimization(double actual_final_weight)
	{
		if (spill_opt_config_.mode == SpillOptMode::kDisabled)
			return;

		double overshoot = actual_final_weight - target_config_.target_value;

		if (spill_opt_config_.mode == SpillOptMode::kAutomatic)
		{
			effective_in_flight_ += overshoot * 0.5;
			if (effective_in_flight_ < 0)
				effective_in_flight_ = 0;
		}
		else if (spill_opt_config_.mode == SpillOptMode::kManual)
		{
			spill_history_[spill_history_idx_] = overshoot;
			spill_history_idx_ = (spill_history_idx_ + 1) % spill_opt_config_.adjust_samples;
			if (spill_history_count_ < spill_opt_config_.adjust_samples)
				spill_history_count_++;

			if (spill_history_count_ >= spill_opt_config_.adjust_samples)
			{
				double avg = 0.0;
				for (int i = 0; i < spill_history_count_; i++)
					avg += spill_history_[i];
				avg /= spill_history_count_;

				if (std::abs(avg) > spill_opt_config_.adjust_range)
				{
					effective_in_flight_ += avg * spill_opt_config_.adjust_factor;
					if (effective_in_flight_ < 0)
						effective_in_flight_ = 0;
				}
			}
		}
	}

	void FillingApplication::UpdateCutoffOptimization(double overshoot)
	{
		if (cutoff_opt_config_.mode == CutoffOptMode::kDisabled)
			return;

		if (cutoff_opt_config_.mode == CutoffOptMode::kAutomatic)
		{
			effective_in_flight_ += overshoot * 0.3;
			if (effective_in_flight_ < 0)
				effective_in_flight_ = 0;
		}
		else if (cutoff_opt_config_.mode == CutoffOptMode::kManual)
		{
			cutoff_history_[cutoff_history_idx_] = overshoot;
			cutoff_history_idx_ = (cutoff_history_idx_ + 1) % cutoff_opt_config_.adjust_cycles;
			if (cutoff_history_count_ < cutoff_opt_config_.adjust_cycles)
				cutoff_history_count_++;

			if (cutoff_history_count_ >= cutoff_opt_config_.adjust_cycles)
			{
				double avg = 0.0;
				for (int i = 0; i < cutoff_history_count_; i++)
					avg += cutoff_history_[i];
				avg /= cutoff_history_count_;

				if (std::abs(avg) > cutoff_opt_config_.control_reliability_range)
				{
					effective_in_flight_ += avg * cutoff_opt_config_.adjust_factor;
					if (effective_in_flight_ < 0)
						effective_in_flight_ = 0;
				}
			}
		}
	}

	// ======== State Machines ========

	void FillingApplication::ControlLoop()
	{
		auto now = std::chrono::steady_clock::now();
		float dt = std::chrono::duration<float>(now - last_time_).count();
		last_time_ = now;

		if (dt <= 0.0f || dt > 1.0f)
			return;

		if (advanced_config_.interlock_enabled && !interlock_active_)
		{
			StopFeeding();
			return;
		}

		float process_elapsed = std::chrono::duration<float>(now - process_start_).count();
		if (process_elapsed > events_config_.process_timeout &&
			events_config_.process_timeout > 0)
		{
			EmitWarning("Process timeout");
			StopFeeding();
			SetPhase(FillingPhase::kError);
			SetRunState(AppRunState::kError);
			return;
		}

		switch (system_config_.work_mode)
		{
		case FillingWorkMode::kFill:
			FillModeStateMachine(dt);
			break;
		case FillingWorkMode::kFillAndEmpty:
			FillEmptyModeStateMachine(dt);
			break;
		case FillingWorkMode::kDispense:
			DispenseModeStateMachine(dt);
			break;
		case FillingWorkMode::kRefillAndDispense:
			RefillDispenseModeStateMachine(dt);
			break;
		case FillingWorkMode::kAbsoluteValue:
			AbsoluteModeStateMachine(dt);
			break;
		}

		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.current_weight = current_weight_.load();
			status_data_.target_weight = target_config_.target_value;
		}
	}

	// ======== Fill Mode ========

	void FillingApplication::FillModeStateMachine(float dt)
	{
		FillingPhase phase = phase_.load();
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		switch (phase)
		{
		case FillingPhase::kRunning:
		{
			if (auto_tare_config_.auto_tare_enabled)
			{
				SetPhase(FillingPhase::kAutoTare);
			}
			else
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			break;
		}

		case FillingPhase::kAutoTare:
		{
			if (PerformAutoTare())
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			else if (phase_elapsed > events_config_.initial_feed_timeout)
			{
				EmitWarning("Auto tare timeout");
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFeeding:
		{
			double current = current_net_.load();
			double dispensed = current - feed_start_weight_;
			current_dispensed_ = dispensed;

			double target = target_config_.target_value;
			double remaining = target - dispensed - effective_in_flight_;

			if (system_config_.feed_speed == FeedSpeed::kDualSpeed &&
				target_config_.feed > 0)
			{
				double fine_threshold = target - target_config_.feed - effective_in_flight_;
				if (dispensed >= fine_threshold)
				{
					StartFineFeed();
					SetPhase(FillingPhase::kFineFeed);
					break;
				}
			}

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}

			if (phase_elapsed > events_config_.initial_feed_timeout &&
				dispensed < 0.001)
			{
				EmitWarning("Initial feed timeout - no material flow");
				StopFeeding();
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFineFeed:
		{
			double dispensed = current_net_.load() - feed_start_weight_;
			current_dispensed_ = dispensed;
			double remaining = target_config_.target_value - dispensed - effective_in_flight_;

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}
			break;
		}

		case FillingPhase::kInFlight:
			HandleInFlight(dt);
			break;

		case FillingPhase::kToleranceCheck:
			HandleToleranceCheck(dt);
			break;

		case FillingPhase::kJog:
			HandleJog(dt);
			break;

		case FillingPhase::kFeedComplete:
			HandleFeedComplete();
			break;

		case FillingPhase::kClearTare:
		{
			if (auto_tare_config_.auto_tare_enabled && scale_)
			{
				scale_->ClearTare();
			}
			SetPhase(FillingPhase::kIdle);
			SetRunState(AppRunState::kIdle);
			break;
		}

		case FillingPhase::kError:
			break;

		default:
			break;
		}
	}

	// ======== Fill/Empty Mode ========

	void FillingApplication::FillEmptyModeStateMachine(float dt)
	{
		FillingPhase phase = phase_.load();
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		switch (phase)
		{
		case FillingPhase::kRunning:
		{
			if (auto_tare_config_.auto_tare_enabled)
				SetPhase(FillingPhase::kAutoTare);
			else
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			break;
		}

		case FillingPhase::kAutoTare:
		{
			if (PerformAutoTare())
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			else if (phase_elapsed > events_config_.initial_feed_timeout)
			{
				EmitWarning("Auto tare timeout");
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFeeding:
		{
			double dispensed = current_net_.load() - feed_start_weight_;
			current_dispensed_ = dispensed;
			double target = target_config_.target_value;
			double remaining = target - dispensed - effective_in_flight_;

			if (system_config_.feed_speed == FeedSpeed::kDualSpeed &&
				target_config_.feed > 0)
			{
				double fine_threshold = target - target_config_.feed - effective_in_flight_;
				if (dispensed >= fine_threshold)
				{
					StartFineFeed();
					SetPhase(FillingPhase::kFineFeed);
					break;
				}
			}

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}

			if (phase_elapsed > events_config_.initial_feed_timeout && dispensed < 0.001)
			{
				EmitWarning("Initial feed timeout");
				StopFeeding();
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFineFeed:
		{
			double dispensed = current_net_.load() - feed_start_weight_;
			current_dispensed_ = dispensed;
			double remaining = target_config_.target_value - dispensed - effective_in_flight_;

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}
			break;
		}

		case FillingPhase::kInFlight:
			HandleInFlight(dt);
			break;

		case FillingPhase::kToleranceCheck:
			HandleToleranceCheck(dt);
			break;

		case FillingPhase::kJog:
			HandleJog(dt);
			break;

		case FillingPhase::kFeedComplete:
		{
			// 进入排空阶段
			SetPhase(FillingPhase::kEmptying);
			emptying_start_ = std::chrono::steady_clock::now();
			// 打开排空阀门
			// SetValveOutputs(0, false, false, false, true);
			SetOutputSignal(DigitalSignalType::kEmptyingValve, true);
			break;
		}

		case FillingPhase::kEmptying:
			HandleEmptying(dt);
			break;

		case FillingPhase::kClearTare:
		{
			if (auto_tare_config_.auto_tare_enabled && scale_)
				scale_->ClearTare();
			SetPhase(FillingPhase::kIdle);
			SetRunState(AppRunState::kIdle);
			break;
		}

		case FillingPhase::kError:
			break;

		default:
			break;
		}
	}

	// ======== Dispense Mode ========

	void FillingApplication::DispenseModeStateMachine(float dt)
	{
		FillingPhase phase = phase_.load();
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		switch (phase)
		{
		case FillingPhase::kRunning:
		{
			if (CheckMaterialSufficient())
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			else
			{
				EmitWarning("Insufficient material");
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFeeding:
		{
			double dispensed = feed_start_weight_ - current_weight_.load();
			current_dispensed_ = dispensed;
			double target = target_config_.target_value;
			double remaining = target - dispensed - effective_in_flight_;

			if (system_config_.feed_speed == FeedSpeed::kDualSpeed &&
				target_config_.feed > 0)
			{
				double fine_threshold = target - target_config_.feed - effective_in_flight_;
				if (dispensed >= fine_threshold)
				{
					StartFineFeed();
					SetPhase(FillingPhase::kFineFeed);
					break;
				}
			}

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}

			if (phase_elapsed > events_config_.initial_feed_timeout && dispensed < 0.001)
			{
				EmitWarning("Initial feed timeout");
				StopFeeding();
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFineFeed:
		{
			double dispensed = feed_start_weight_ - current_weight_.load();
			current_dispensed_ = dispensed;
			double remaining = target_config_.target_value - dispensed - effective_in_flight_;

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}
			break;
		}

		case FillingPhase::kInFlight:
			HandleInFlight(dt);
			break;
		case FillingPhase::kToleranceCheck:
			HandleToleranceCheck(dt);
			break;
		case FillingPhase::kJog:
			HandleJog(dt);
			break;
		case FillingPhase::kFeedComplete:
			HandleFeedComplete();
			break;
		case FillingPhase::kError:
			break;
		default:
			break;
		}
	}

	// ======== Refill/Dispense Mode ========

	void FillingApplication::RefillDispenseModeStateMachine(float dt)
	{
		FillingPhase phase = phase_.load();
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		switch (phase)
		{
		case FillingPhase::kRunning:
		{
			double source_weight = current_weight_.load();
			if (source_weight < refill_config_.lower_limit)
			{
				SetPhase(FillingPhase::kRefilling);
				SetRefillValve(true);
				SetRunState(AppRunState::kRefilling);
			}
			else
			{
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}
			break;
		}

		case FillingPhase::kRefilling:
		{
			double source_weight = current_weight_.load();
			if (source_weight >= refill_config_.upper_limit)
			{
				SetRefillValve(false);
				SetRunState(AppRunState::kRunning);
				StartFeeding();
				StartFastFeed();
				SetPhase(FillingPhase::kFeeding);
			}

			if (phase_elapsed > events_config_.refill_timeout)
			{
				EmitWarning("Refill timeout");
				SetRefillValve(false);
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFeeding:
		{
			double dispensed = feed_start_weight_ - current_weight_.load();
			current_dispensed_ = dispensed;
			double target = target_config_.target_value;
			double remaining = target - dispensed - effective_in_flight_;

			if (system_config_.feed_speed == FeedSpeed::kDualSpeed &&
				target_config_.feed > 0)
			{
				double fine_threshold = target - target_config_.feed - effective_in_flight_;
				if (dispensed >= fine_threshold)
				{
					StartFineFeed();
					SetPhase(FillingPhase::kFineFeed);
					break;
				}
			}

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}

			if (phase_elapsed > events_config_.initial_feed_timeout && dispensed < 0.001)
			{
				EmitWarning("Initial feed timeout");
				StopFeeding();
				SetPhase(FillingPhase::kError);
			}
			break;
		}

		case FillingPhase::kFineFeed:
		{
			double dispensed = feed_start_weight_ - current_weight_.load();
			current_dispensed_ = dispensed;
			double remaining = target_config_.target_value - dispensed - effective_in_flight_;

			if (remaining <= 0)
			{
				StopFeeding();
				SetPhase(FillingPhase::kInFlight);
			}
			break;
		}

		case FillingPhase::kInFlight:
			HandleInFlight(dt);
			break;
		case FillingPhase::kToleranceCheck:
			HandleToleranceCheck(dt);
			break;
		case FillingPhase::kJog:
			HandleJog(dt);
			break;
		case FillingPhase::kFeedComplete:
			HandleFeedComplete();
			break;
		case FillingPhase::kError:
			break;
		default:
			break;
		}
	}

	void FillingApplication::AbsoluteModeStateMachine(float dt)
	{
		FillModeStateMachine(dt);
	}

	// ======== Common Phase Handlers ========

	bool FillingApplication::PerformAutoTare()
	{
		if (!auto_tare_config_.auto_tare_enabled)
			return true;

		double gross = current_gross_.load();

		if (gross < auto_tare_config_.container_tare_lower)
		{
			EmitWarning("Container below minimum tare");
			return false;
		}
		if (gross > auto_tare_config_.container_tare_upper)
		{
			EmitWarning("Container above maximum tare");
			return false;
		}

		if (scale_ && scale_->GetWeightData().is_net_mode)
		{
			EmitWarning("Auto tare failed: already in net mode");
			return false;
		}

		if (!is_stable_.load())
			return false;

		if (scale_)
			return scale_->DoTare();

		return false;
	}

	void FillingApplication::HandleInFlight(float dt)
	{
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		if (is_stable_.load())
		{
			SetPhase(FillingPhase::kToleranceCheck);
		}
		else if (phase_elapsed > tolerance_config_.stability_timeout &&
				 tolerance_config_.stability_timeout > 0)
		{
			SetPhase(FillingPhase::kToleranceCheck);
		}
	}

	void FillingApplication::HandleToleranceCheck(float dt)
	{
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - phase_start_)
								  .count();

		if (phase_elapsed < tolerance_config_.pre_check_delay)
			return;

		if (!is_stable_.load())
		{
			if (phase_elapsed <= tolerance_config_.pre_check_delay +
									 tolerance_config_.stability_timeout)
				return;
		}

		double actual;
		if (system_config_.work_mode == FillingWorkMode::kDispense ||
			system_config_.work_mode == FillingWorkMode::kRefillAndDispense)
		{
			actual = feed_start_weight_ - current_weight_.load();
		}
		else
		{
			actual = current_net_.load() - feed_start_weight_;
		}

		double target = target_config_.target_value;
		double upper = target + tolerance_config_.positive_tolerance;
		double lower = target - tolerance_config_.negative_tolerance;

		if (actual >= lower && actual <= upper)
			tolerance_result_ = ToleranceResult::kInTolerance;
		else if (actual > upper)
			tolerance_result_ = ToleranceResult::kAboveTolerance;
		else
			tolerance_result_ = ToleranceResult::kBelowTolerance;

		UpdateSpillOptimization(actual);
		UpdateCutoffOptimization(actual - target);

		if (jog_config_.mode != JogMode::kDisabled &&
			tolerance_result_ == ToleranceResult::kBelowTolerance)
		{
			jog_cycles_ = 0;
			SetPhase(FillingPhase::kJog);
		}
		else
		{
			SetPhase(FillingPhase::kFeedComplete);
		}
	}

	void FillingApplication::HandleJog(float dt)
	{
		switch (jog_config_.mode)
		{
		case JogMode::kAutomatic:
		{
			if (!jog_active_)
			{
				jog_active_ = true;
				jog_start_ = std::chrono::steady_clock::now();
				StartFineFeed();
				jog_cycles_++;
			}
			else
			{
				float jog_elapsed = std::chrono::duration<float>(
										std::chrono::steady_clock::now() - jog_start_)
										.count();

				if (jog_elapsed >= jog_config_.jog_duration)
				{
					StopFeeding();
					jog_active_ = false;

					if (jog_cycles_ >= jog_config_.max_cycles)
					{
						SetPhase(FillingPhase::kToleranceCheck);
						return;
					}

					std::this_thread::sleep_for(std::chrono::milliseconds(
						static_cast<int>(jog_config_.jog_pause_time * 1000)));

					double actual;
					if (system_config_.work_mode == FillingWorkMode::kDispense ||
						system_config_.work_mode == FillingWorkMode::kRefillAndDispense)
					{
						actual = feed_start_weight_ - current_weight_.load();
					}
					else
					{
						actual = current_net_.load() - feed_start_weight_;
					}

					if (actual >= target_config_.target_value - tolerance_config_.negative_tolerance)
					{
						if (is_stable_.load())
							SetPhase(FillingPhase::kToleranceCheck);
						else
							jog_active_ = false;
					}
				}
			}
			break;
		}

		case JogMode::kSinglePulse:
		{
			if (!jog_active_)
			{
				jog_active_ = true;
				jog_start_ = std::chrono::steady_clock::now();
				StartFineFeed();
			}
			else
			{
				float jog_elapsed = std::chrono::duration<float>(
										std::chrono::steady_clock::now() - jog_start_)
										.count();
				if (jog_elapsed >= jog_config_.jog_duration)
				{
					StopFeeding();
					jog_active_ = false;
					SetPhase(FillingPhase::kToleranceCheck);
				}
			}
			break;
		}

		case JogMode::kManual:
			break;

		default:
			SetPhase(FillingPhase::kFeedComplete);
			break;
		}
	}

	void FillingApplication::HandleEmptying(float dt)
	{
		float phase_elapsed = std::chrono::duration<float>(
								  std::chrono::steady_clock::now() - emptying_start_)
								  .count();

		switch (emptying_config_.complete_mode)
		{
		case EmptyingCompleteMode::kResidualWeight:
		{
			double weight = current_weight_.load();
			if (weight <= emptying_config_.residual_weight)
			{
				// SetValveOutputs(0, false, false, false, false); // 关闭排空阀
				SetOutputSignal(DigitalSignalType::kEmptyingValve, false);
				SetPhase(FillingPhase::kClearTare);
			}

			if (phase_elapsed > events_config_.emptying_timeout)
			{
				EmitWarning("Emptying timeout");
				// SetValveOutputs(0, false, false, false, false);
				SetOutputSignal(DigitalSignalType::kEmptyingValve, false);
				SetPhase(FillingPhase::kClearTare);
			}
			break;
		}

		case EmptyingCompleteMode::kCompletionTime:
		{
			if (phase_elapsed >= emptying_config_.completion_time)
			{
				// SetValveOutputs(0, false, false, false, false);
				SetOutputSignal(DigitalSignalType::kEmptyingValve, false);
				SetPhase(FillingPhase::kClearTare);
			}
			break;
		}
		}
	}

	void FillingApplication::HandleFeedComplete()
	{
		cycle_count_++;

		if (advanced_config_.cycle_confirm == CycleResultConfirm::kEveryTime ||
			(advanced_config_.cycle_confirm == CycleResultConfirm::kOutOfTolerance &&
			 tolerance_result_ != ToleranceResult::kInTolerance))
		{
			SetPhase(FillingPhase::kWaitConfirm);
		}
		else
		{
			if (auto_tare_config_.auto_tare_enabled)
				SetPhase(FillingPhase::kClearTare);
			else
			{
				SetPhase(FillingPhase::kIdle);
				SetRunState(AppRunState::kCompleted);
			}
		}
	}

	void FillingApplication::TriggerManualJog()
	{
		if (phase_.load() == FillingPhase::kJog && jog_config_.mode == JogMode::kManual)
		{
			if (!jog_active_)
			{
				jog_active_ = true;
				StartFineFeed();
			}
		}
	}

	void FillingApplication::EndManualJog()
	{
		if (jog_active_)
		{
			jog_active_ = false;
			StopFeeding();
			SetPhase(FillingPhase::kToleranceCheck);
		}
	}

	void FillingApplication::ConfirmCycleResult()
	{
		if (phase_.load() == FillingPhase::kWaitConfirm)
		{
			if (auto_tare_config_.auto_tare_enabled)
				SetPhase(FillingPhase::kClearTare);
			else
			{
				SetPhase(FillingPhase::kIdle);
				SetRunState(AppRunState::kCompleted);
			}
		}
	}

} // namespace weighing