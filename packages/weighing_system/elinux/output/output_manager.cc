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

			if (dio_callback_)
			{
				bool start, stop, refill, emptying, interlock, tare, zero, jog;
				dio->ParseDioInputs(start, stop, refill, emptying, interlock, tare, zero, jog);

				// 构造输入信号结构体（使用命名字段，避免聚合初始化顺序依赖）
				DioInputSignals sig;
				sig.start = start;
				sig.stop = stop;
				sig.execute_refill = refill;
				sig.trigger_emptying = emptying;
				sig.interlock = interlock;
				sig.tare = tare;
				sig.zero = zero;
				sig.jog_trigger = jog;

				dio_callback_(pos, sig);
			}
		}
	}

	void OutputManager::MapSubsystemServo(uint32_t sub_id, uint16_t servo_pos)
	{
		subsystem_servo_map_[sub_id] = servo_pos;
	}

	void OutputManager::MapSubsystemIO(uint32_t sub_id, uint16_t io_pos)
	{
		subsystem_io_map_[sub_id] = io_pos;
	}

	void OutputManager::SetControlRate(uint32_t sub_id, float rate)
	{
		auto it = subsystem_servo_map_.find(sub_id);
		if (it != subsystem_servo_map_.end())
		{
			auto sit = servos_.find(it->second);
			if (sit != servos_.end())
				sit->second->SetControlRate(rate);
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

	bool OutputManager::UpdateDigitalOutputMap(const DigitalOutputMapConfig &cfg, std::string *err)
	{
		return dio_map_.SetConfig(cfg, err);
	}

	DigitalOutputMapConfig OutputManager::GetDigitalOutputMapConfig() const
	{
		return dio_map_.GetConfig();
	}

} // namespace weighing