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
				// 传递原始16位输入字，由订阅方负责应用自定义映射
				dio_callback_(pos, dio->GetInputs());
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

	void OutputManager::SetValveOutputs(uint32_t sub_id, uint16_t channel,
										bool fast, bool slow, bool refill, bool emptying)
	{
		auto it = subsystem_io_map_.find(sub_id);
		if (it != subsystem_io_map_.end())
		{
			auto dit = digital_ios_.find(it->second);
			if (dit != digital_ios_.end())
			{
				dit->second->ApplyDioOutputs(channel, fast, slow, refill, emptying);
			}
		}
	}

	void OutputManager::SetAlarm(uint32_t io_pos, bool active)
	{
		auto it = digital_ios_.find(static_cast<uint16_t>(io_pos));
		if (it != digital_ios_.end())
			it->second->SetAlarm(active);
	}

	void OutputManager::SetRunning(uint32_t io_pos, bool running)
	{
		auto it = digital_ios_.find(static_cast<uint16_t>(io_pos));
		if (it != digital_ios_.end())
			it->second->SetRunningIndicator(running);
	}

	void OutputManager::SetWarning(uint32_t io_pos, bool warning)
	{
		auto it = digital_ios_.find(static_cast<uint16_t>(io_pos));
		if (it != digital_ios_.end())
			it->second->SetWarningIndicator(warning);
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

} // namespace weighing