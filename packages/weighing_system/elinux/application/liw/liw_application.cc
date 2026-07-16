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

		// === 新增：预补料拦截逻辑 ===
		double weight = current_weight_.load(std::memory_order_acquire);

		// 只要开启了预补料且未达到上限，就在喂料器运行前触发补料
		if (system_config_.pre_refill && weight < refill_config_.upper_limit)
		{
			StartPreRefill();
		}
		else
		{
			is_pre_refilling_.store(false);
			waiting_for_manual_pre_refill_.store(false);
		}

		AppBase::Start(); // 内部调用 SetRunningOutput(true)
	}

	void LiwApplication::Stop()
	{
		SetServoRate(DigitalSignalType::kFeedFast, 0.0f);
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
			// === 新增：判断是否在等待手动预补料 ===
			if (is_pre_refilling_.load() && waiting_for_manual_pre_refill_.load())
			{
				// 接收到手动执行信号，打开阀门
				// SetValveOutputs(0, false, false, true, false);
				SetOutputSignal(DigitalSignalType::kRefillValve, true);
				waiting_for_manual_pre_refill_.store(false);
				ClearWarning();
			}
			else
			{
				// 如果之前是待补料状态，启动补料
				if (waiting_for_manual_refill_.load())
				{
					waiting_for_manual_refill_.store(false);
					TriggerManualRefill();
				}
				else
				{
					EndManualRefill();
				}
			}
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
			float current_flow = CalculateFlow(dt); // 必须计算当前流量以供判断

			if (weight <= system_config_.hopper_min)
			{
				if (emptying_config_.auto_stop_at_alarm)
				{
					CancelEmptying();
					SetServoRate(DigitalSignalType::kFeedFast, 0.0f);
					Stop();
				}
				else
				{
					// 禁止自动停止：锁定控制率，直到彻底排空
					SetServoRate(DigitalSignalType::kFeedFast, emptying_config_.control_setpoint);

					// 【补全逻辑】检查实际流量是否 < 最大流量的 1%
					float empty_threshold = controller_config_.max_flow * 0.01f;
					if (current_flow < empty_threshold)
					{
						// 彻底排空，自动结束
						CancelEmptying();
						SetServoRate(DigitalSignalType::kFeedFast, 0.0f); // 彻底停机
						Stop();
					}
				}
			}
			// 2. 如果重量还未到达最小值
			if (run_state_.load() == AppRunState::kRunning && base_config_.sub_mode == LiwSubMode::kFlowControl)
			{
				// 【补全逻辑】如果原本在运行，则在到达最小值前继续维持闭环流量控制
				float control_rate = pid_.Process(current_flow, dt);
				SetServoRate(DigitalSignalType::kFeedFast, control_rate);
			}
			else
			{
				// 如果原本是停止状态，或者处于定频模式，直接使用清空设定值开环运行
				SetServoRate(DigitalSignalType::kFeedFast, emptying_config_.control_setpoint);
			}
			return;
		}

		// === 新增：预补料逻辑 (Pre-refill) ===
		if (is_pre_refilling_.load())
		{
			double weight = current_weight_.load();

			// 预补料期间，喂料电机强制停止
			SetServoRate(DigitalSignalType::kFeedFast, 0.0f);
			SetServoRate(DigitalSignalType::kFeedSlow, 0.0f);

			if (weight >= refill_config_.upper_limit)
			{
				EndPreRefill();
			}
			else
			{
				// 仍在预补料中，更新状态但不执行后续流量计算
				SetRunState(AppRunState::kRefilling);
				// 如果补料是伺服螺旋，下发补料速度
				if (refill_config_.mode == RefillMode::kAutomatic)
				{
					SetServoRate(DigitalSignalType::kRefillValve, refill_config_.control_setpoint);
				}

				std::lock_guard<std::mutex> lock(status_mutex_);
				status_data_.control_rate = 0.0f;
				status_data_.current_weight = weight;
			}

			// 直接返回，跳过正常的 CheckRefill() 和 PID 喂料控制
			return;
		}

		// Check refill
		CheckRefill();
		if (is_refilling_.load() || is_stabilizing_.load())
		{
			// During refill: use refill control mode
			float refill_rate = 0.0f;
			double current_w = current_weight_.load();
			// 将比例因子转换为乘数 (例如 95% -> 0.95)
			float scale_factor = refill_config_.refill_scale_factor / 100.0f;

			switch (refill_config_.control_mode)
			{
			case RefillControlMode::kFixedOutput:
				refill_rate = refill_config_.control_setpoint;
				break;
			case RefillControlMode::kLastFrequency:
				refill_rate = static_cast<float>(refill_last_control_rate_) * scale_factor;
				break;
			case RefillControlMode::kSmartAdapt:
				// 3. 智能适应：动态料位压力补偿算法
				// 计算当前的补料进度 (0.0 表示刚开始补料，1.0 表示补料完成)
				float fill_progress = static_cast<float>(
					(current_w - refill_config_.lower_limit) /
					(refill_config_.upper_limit - refill_config_.lower_limit + 0.001) // 防止除零
				);
				fill_progress = std::max(0.0f, std::min(1.0f, fill_progress));

				// 动态缩放系数：
				// 刚开始补料 (progress=0)，料仓底部压力尚未增加，系数接近 1.0 (不打折)
				// 补料即将满 (progress=1)，料仓底部压力最大，完全应用用户设置的比例因子
				float dynamic_scale = 1.0f + (scale_factor - 1.0f) * fill_progress;

				// 使用之前计算好的“平滑基准频率”，防止因瞬间抖动导致补料期全盘崩溃
				refill_rate = static_cast<float>(refill_smart_base_rate_) * dynamic_scale;
				break;
			}

			// 强制限制输出在安全范围内
			refill_rate = std::max(0.0f, std::min(refill_rate, system_config_.safety_limit));

			SetServoRate(DigitalSignalType::kFeedFast, refill_rate);

			// 稳定期时间倒计时检查
			if (is_stabilizing_.load())
			{
				float stabilize_elapsed = std::chrono::duration<float>(now - stabilize_start_).count();
				if (stabilize_elapsed >= refill_config_.stabilize_time)
				{
					// 稳定时间结束，彻底恢复闭环 PID 运行
					is_stabilizing_.store(false);

					// 重置基准频率，为下一次循环做准备
					refill_smart_base_rate_ = 0.0;

					// 重置 PID 以防止积分饱和积攒的误差释放
					pid_.Reset();
					pid_.SetTarget(system_config_.target_flow);

					SetRunState(AppRunState::kRunning);
				}
			}

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

		// === 新增：计算平滑的基准频率（供 kSmartAdapt 使用）===
		// 使用一阶低通滤波，时间常数约为 2 秒，滤除即将空仓时的剧烈抖动
		if (refill_smart_base_rate_ == 0.0)
		{
			refill_smart_base_rate_ = control_rate;
		}
		else
		{
			float alpha = dt / (2.0f + dt);
			refill_smart_base_rate_ = refill_smart_base_rate_ * (1.0f - alpha) + control_rate * alpha;
		}

		// Apply output
		SetServoRate(DigitalSignalType::kFeedFast, control_rate);

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

		SetServoRate(DigitalSignalType::kFeedFast, control_rate);

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
		SetServoRate(DigitalSignalType::kFeedFast, control_rate);

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
		float step_elapsed = std::chrono::duration<float>(now - sysid_step_start_).count();

		if (sysid_step_ == 0)
		{
			sysid_step_ = 1;
			sysid_phase_ = SysIdPhase::kSettling;
			sysid_step_start_ = now;
			sysid_points_.clear();
		}

		float target_duration = sysid_config_.step_duration;
		// 如果开启智能步进，归零平稳时间缩短以提高效率
		float settle_duration = sysid_config_.smart_step_control ? (target_duration * 0.3f) : (target_duration * 0.5f);

		if (sysid_phase_ == SysIdPhase::kSettling)
		{
			// 阶段 1: 归零平稳
			SetServoRate(DigitalSignalType::kFeedFast, 0.0f);
			if (step_elapsed >= settle_duration)
			{
				sysid_phase_ = SysIdPhase::kMeasuring;
				sysid_step_start_ = now;
				sysid_step_start_weight_ = current_weight_.load();

				// 计算当前步进的测试控制率
				float range = sysid_config_.adjust_range_upper - sysid_config_.adjust_range_lower;
				sysid_current_rate_ = sysid_config_.adjust_range_lower +
									  (range / (sysid_total_steps_ - 1)) * (sysid_step_ - 1);
			}
		}
		else
		{
			// 阶段 2: 目标率测量
			SetServoRate(DigitalSignalType::kFeedFast, sysid_current_rate_);

			if (step_elapsed >= target_duration)
			{
				double weight_drop = sysid_step_start_weight_ - current_weight_.load();
				float flow_at_rate = static_cast<float>(weight_drop / step_elapsed * 3600.0);

				// 错误检查：如果控制率 > 10% 但流量接近 0，触发喂料器堵塞预警
				if (sysid_current_rate_ > 10.0f && flow_at_rate < 0.01f)
				{
					EmitWarning("System ID Error: No material flow detected (Feeder blocked?)");
				}

				sysid_points_.push_back({sysid_current_rate_, flow_at_rate});

				if (sysid_step_ >= sysid_total_steps_)
				{
					CalculateParametersFromSysId(); // 5 个点集齐，开始计算
					SetRunState(AppRunState::kCompleted);
					Stop();
				}
				else
				{
					sysid_step_++;
					sysid_phase_ = SysIdPhase::kSettling; // 返回 0 准备下一步
					sysid_step_start_ = now;
				}
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

	void LiwApplication::CalculateParametersFromSysId()
	{
		if (sysid_points_.size() < 2)
			return;

		// 1. 使用最小二乘法计算斜率 (流量 / 控制率)
		float sum_x = 0, sum_y = 0, sum_xy = 0, sum_xx = 0;
		for (const auto &p : sysid_points_)
		{
			sum_x += p.rate;
			sum_y += p.flow;
			sum_xy += p.rate * p.flow;
			sum_xx += p.rate * p.rate;
		}
		float n = static_cast<float>(sysid_points_.size());
		float slope = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);

		// 2. 计算最大流量 (100% 控制率下的流量)
		float calculated_max_flow = slope * 100.0f;
		if (calculated_max_flow <= 0)
			calculated_max_flow = 100.0f; // 安全保底

		// 3. 计算 PID 参数 (根据 IND360 典型逻辑: Kp 与增益成反比)
		// 假设系统响应时间常数由步进周期决定
		float new_kp = 1.0f / (slope > 0 ? (slope / (calculated_max_flow / 100.0f)) : 1.0f);
		float new_ki = sysid_config_.step_duration * 0.5f; // 积分时间常数

		// 4. 更新控制器配置
		LiwControllerConfig new_cfg = controller_config_;
		new_cfg.max_flow = calculated_max_flow;
		new_cfg.Kp = std::max(0.1f, std::min(new_kp, 20.0f)); // 范围限制
		new_cfg.Ki = std::max(0.01f, new_ki);

		SetControllerConfig(new_cfg);

		// 发送系统日志
		EmitWarning("System ID Finished: MaxFlow updated to " + std::to_string(calculated_max_flow));
	}

	void LiwApplication::CheckRefill()
	{
		double weight = current_weight_.load();

		// 如果不在补料，也不在稳定期
		if (!is_refilling_.load() && !is_stabilizing_.load())
		{
			if (weight <= refill_config_.lower_limit)
			{
				if (refill_config_.mode == RefillMode::kAutomatic)
				{
					StartRefill(); // 自动模式：直接开阀
				}
				else
				{
					// 手动模式：仅设置待补料标志，不动作
					waiting_for_manual_refill_.store(true);
					// 建议这里联动 DIO 输出“待补料”信号
				}
			}
		}
		else if (is_refilling_.load())
		{
			// 自动模式下，达到上限自动关阀并进入稳定期
			if (refill_config_.mode == RefillMode::kAutomatic && weight >= refill_config_.upper_limit)
			{
				StartStabilization();
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
		SetOutputSignal(DigitalSignalType::kRefillValve, true);
		// 如果补料是伺服，此处下发补料伺服速度
		if (refill_config_.mode == RefillMode::kAutomatic)
		{
			SetServoRate(DigitalSignalType::kRefillValve, refill_config_.control_setpoint);
		}
		SetRunState(AppRunState::kRefilling);
	}

	void LiwApplication::EndRefill()
	{
		is_refilling_.store(false);
		// 关闭补料阀
		SetOutputSignal(DigitalSignalType::kRefillValve, false);
		// 如果补料是伺服，此处关闭补料伺服
		SetServoRate(DigitalSignalType::kRefillValve, 0.0f);
		SetRunState(AppRunState::kRunning);
	}

	void LiwApplication::StartPreRefill()
	{
		is_pre_refilling_.store(true);
		is_refilling_.store(false); // 确保常规补料标志关闭

		if (refill_config_.mode == RefillMode::kAutomatic)
		{
			// 自动补料模式：直接打开补料阀
			SetOutputSignal(DigitalSignalType::kRefillValve, true);
			SetServoRate(DigitalSignalType::kRefillValve, refill_config_.control_setpoint);
			waiting_for_manual_pre_refill_.store(false);
		}
		else
		{
			// 手动补料模式：不自动开阀，发出警告并等待外部 DIO 信号
			waiting_for_manual_pre_refill_.store(true);
			EmitWarning("Waiting for manual pre-refill signal (Execute Refill)");
		}
	}

	void LiwApplication::EndPreRefill()
	{
		is_pre_refilling_.store(false);
		waiting_for_manual_pre_refill_.store(false);
		SetOutputSignal(DigitalSignalType::kRefillValve, false); // 关闭补料阀
																 // 如果补料是伺服，此处关闭补料伺服
		SetServoRate(DigitalSignalType::kRefillValve, 0.0f);

		// 【关键】此时预补料完成，相当于系统才“真正”开始启动
		last_time_ = std::chrono::steady_clock::now();
		startup_start_ = last_time_;
		sample_start_ = last_time_;
		stats_.startup_accumulated = 0.0;
		is_in_startup_.store(controller_config_.startup_time > 0.0f);

		pid_.Reset();
		pid_.SetTarget(system_config_.target_flow);

		ClearWarning();
		SetRunState(AppRunState::kRunning);
	}

	void LiwApplication::StartStabilization()
	{
		is_refilling_.store(false);
		SetOutputSignal(DigitalSignalType::kRefillValve, false); // 物理上关闭补料阀

		is_stabilizing_.store(true); // 进入稳定期
		stabilize_start_ = std::chrono::steady_clock::now();
	}

	void LiwApplication::TriggerEmptying()
	{
		// === 新增：强制退出正在进行的任何补料状态 ===
		if (is_refilling_.load())
		{
			// 如果存在私有的 EndRefill() 函数，请直接调用它，以确保相关的统计和PID能正确复位
			EndRefill();
		}

		// 如果您采纳了第一问的“预补料”建议，这里也必须强行打断预补料
		if (is_pre_refilling_.load())
		{
			EndPreRefill();
		}
		is_emptying_.store(true);
		// 打开排空阀
		SetOutputSignal(DigitalSignalType::kEmptyingValve, true);
		SetRunState(AppRunState::kEmptying);
	}

	void LiwApplication::CancelEmptying()
	{
		is_emptying_.store(false);
		// 关闭排空阀
		SetOutputSignal(DigitalSignalType::kEmptyingValve, false);
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
		if (refill_config_.mode == RefillMode::kManual && is_refilling_.load())
		{
			StartStabilization();
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