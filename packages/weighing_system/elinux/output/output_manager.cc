#include "output_manager.h"
#include <cstdio>

namespace weighing
{

	OutputManager &OutputManager::Instance()
	{
		static OutputManager instance;
		return instance;
	}

	bool OutputManager::Initialize()
	{
		auto &master = EtherCATMaster::Instance();

		auto servos = master.GetSlavesByRole(SlaveRole::kServo);
		for (const auto *rt : servos)
		{
			uint16_t pos = rt->descriptor.position;
			servos_[pos] = std::make_unique<ServoController>(pos);
			printf("OutputManager: ServoController at pos %u (%s)\n",
				   pos, rt->descriptor.description.c_str());
		}

		auto ios = master.GetSlavesByRole(SlaveRole::kDigitalIO);
		for (const auto *rt : ios)
		{
			uint16_t pos = rt->descriptor.position;
			digital_ios_[pos] = std::make_unique<DigitalIOController>(pos);
			printf("OutputManager: DigitalIOController at pos %u (%s)\n",
				   pos, rt->descriptor.description.c_str());
		}

		initialized_ = true;
		return true;
	}

	bool OutputManager::Start()
	{
		if (!initialized_)
			return false;

		EtherCATMaster::Instance().RegisterOutputCallback(
			[this](uint8_t *domain_data)
			{
				OnCyclicOutput(domain_data);
			});

		for (auto &[pos, servo] : servos_)
		{
			servo->Enable();
		}

		printf("OutputManager: Started (%zu servos, %zu IOs)\n",
			   servos_.size(), digital_ios_.size());
		return true;
	}

	void OutputManager::Stop()
	{
		for (auto &[pos, servo] : servos_)
		{
			servo->SetControlRate(0.0f);
			servo->Disable();
		}
		for (auto &[pos, dio] : digital_ios_)
		{
			dio->SetOutput(0);
		}
		printf("OutputManager: Stopped\n");
	}

	void OutputManager::OnCyclicOutput(uint8_t *domain_data)
	{
		for (auto &[pos, servo] : servos_)
		{
			servo->CyclicTask(domain_data);
		}

		for (auto &[pos, dio] : digital_ios_)
		{
			dio->CyclicTask(domain_data);

			// if (dio_callback_)
			// {
			// 	bool start, stop, refill, emptying, interlock, tare, zero, jog;
			// 	dio->ParseDioInputs(start, stop, refill, emptying, interlock, tare, zero, jog);

			// 	// 构造输入信号结构体（使用命名字段，避免聚合初始化顺序依赖）
			// 	DioInputSignals sig;
			// 	sig.start = start;
			// 	sig.stop = stop;
			// 	sig.execute_refill = refill;
			// 	sig.trigger_emptying = emptying;
			// 	sig.interlock = interlock;
			// 	sig.tare = tare;
			// 	sig.zero = zero;
			// 	sig.jog_trigger = jog;

			// 	dio_callback_(pos, sig);
			// }
		}
	}

	// void OutputManager::MapSubsystemServo(uint32_t sub_id, uint16_t channel, uint16_t servo_pos)
	// {
	// 	subsystem_servo_map_[sub_id][channel] = servo_pos;
	// }

	void OutputManager::MapSubsystemIO(uint32_t sub_id, uint16_t io_pos)
	{
		subsystem_io_map_[sub_id] = io_pos;
	}

	// 根据功能信号，下发速度百分比 (适用于：快加料、慢加料、补料、卸料等 CSV速度控制场景)
	void OutputManager::SetServoRateBySignal(uint32_t subsystem_id, DigitalSignalType signal, float rate_pct)
	{
		auto sub_it = subsystem_servo_route_.find(subsystem_id);
		if (sub_it == subsystem_servo_route_.end())
			return;

		auto sig_it = sub_it->second.find(signal);
		if (sig_it == sub_it->second.end())
			return;

		// 动态遍历所有绑定至此信号的伺服电机，逐一刷新目标速度
		for (uint16_t pos : sig_it->second)
		{
			auto sit = servos_.find(pos);
			if (sit != servos_.end())
			{
				sit->second->SetControlRate(rate_pct);
			}
		}
	}

	// 根据功能信号，下发目标绝对编码器坐标 (适用于：伺服电动夹袋器的精准开合)
	void OutputManager::SetServoPositionBySignal(uint32_t subsystem_id, DigitalSignalType signal, int32_t position)
	{
		auto sub_it = subsystem_servo_route_.find(subsystem_id);
		if (sub_it == subsystem_servo_route_.end())
			return;

		auto sig_it = sub_it->second.find(signal);
		if (sig_it == sub_it->second.end())
			return;

		// 动态遍历所有绑定至此信号的位置控制伺服，统一下发目标坐标值
		for (uint16_t pos : sig_it->second)
		{
			auto sit = servos_.find(pos);
			if (sit != servos_.end())
			{
				sit->second->SetTargetPosition(position);
			}
		}
	}

	// 针对特定子系统一键关断其名下的所有自定义电机输出 (核心防抖与急停保护)
	void OutputManager::StopAllServos(uint32_t subsystem_id)
	{
		auto sub_it = subsystem_servo_route_.find(subsystem_id);
		if (sub_it == subsystem_servo_route_.end())
			return;

		for (const auto &[signal, pos_vec] : sub_it->second)
		{
			for (uint16_t pos : pos_vec)
			{
				auto sit = servos_.find(pos);
				if (sit != servos_.end())
				{
					sit->second->SetControlRate(0.0f);
				}
			}
		}
	}

	void OutputManager::SetValveOutputs(uint32_t subsystem_id,
										uint16_t channel,
										AppType app_type,
										bool fast, bool slow, bool refill, bool emptying)
	{
		const uint16_t io_pos = GetSubsystemIOPosition(subsystem_id);
		auto *dio = GetDigitalIO(io_pos);
		if (!dio)
			return;
		dio->ApplyDioOutputs(subsystem_id, channel, app_type, fast, slow, refill, emptying, dio_map_);
	}

	void OutputManager::SetAlarm(uint32_t subsystem_id, AppType app_type, bool active)
	{
		const uint16_t io_pos = GetSubsystemIOPosition(subsystem_id);
		auto *dio = GetDigitalIO(io_pos);
		if (!dio)
			return;
		dio->SetAlarm(subsystem_id, app_type, active, dio_map_);
	}

	void OutputManager::SetRunning(uint32_t subsystem_id, AppType app_type, bool running)
	{
		const uint16_t io_pos = GetSubsystemIOPosition(subsystem_id);
		auto *dio = GetDigitalIO(io_pos);
		if (!dio)
			return;
		dio->SetRunningIndicator(subsystem_id, app_type, running, dio_map_);
	}

	void OutputManager::SetWarning(uint32_t subsystem_id, AppType app_type, bool warning)
	{
		const uint16_t io_pos = GetSubsystemIOPosition(subsystem_id);
		auto *dio = GetDigitalIO(io_pos);
		if (!dio)
			return;
		dio->SetWarningIndicator(subsystem_id, app_type, warning, dio_map_);
	}
	ServoController *OutputManager::GetServo(uint16_t pos)
	{
		auto it = servos_.find(pos);
		return it != servos_.end() ? it->second.get() : nullptr;
	}

	DigitalIOController *OutputManager::GetDigitalIO(uint16_t pos)
	{
		auto it = digital_ios_.find(pos);
		return it != digital_ios_.end() ? it->second.get() : nullptr;
	}

	// === 重写配置更新逻辑：完成绑定的统一和路由表的动态构建 ===
	bool OutputManager::UpdateDigitalOutputMap(const DigitalOutputMapConfig &cfg, std::string *err)
	{
		// 1. 将配置提交给 Map 管理类完成合法性检测
		if (!dio_map_.SetConfig(cfg, err))
			return false;

		// 2. 彻底清空运行期旧路由表
		subsystem_servo_route_.clear();

		// 3. 动态解析配置，建立信号至物理电机的多通路映射
		for (const auto &b : cfg.servo_bindings)
		{
			if (!b.enabled)
				continue;

			// 将当前物理从站位置推入该子系统、该信号类型的执行队列中
			subsystem_servo_route_[b.subsystem_id][b.signal].push_back(b.servo_pos);

			printf("OutputManager Route Map: Subsystem %u, Signal %d -> Bound to Servo Pos %u\n",
				   b.subsystem_id, static_cast<int>(b.signal), b.servo_pos);
		}
		return true;
	}

	DigitalOutputMapConfig OutputManager::GetDigitalOutputMapConfig() const
	{
		return dio_map_.GetConfig();
	}

} // namespace weighing