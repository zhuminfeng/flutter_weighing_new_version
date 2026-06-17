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

	void OutputManager::SetSubsystemOutputMapping(uint32_t sub_id, const DioOutputMapping &mapping)
	{
		subsystem_output_mapping_[sub_id] = mapping;
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
		auto io_it = subsystem_io_map_.find(sub_id);
		if (io_it == subsystem_io_map_.end())
			return;
		auto dit = digital_ios_.find(io_it->second);
		if (dit == digital_ios_.end())
			return;

		// Resolve bit positions from the output mapping (fall back to hardware defaults)
		DioOutputMapping m;
		auto map_it = subsystem_output_mapping_.find(sub_id);
		if (map_it != subsystem_output_mapping_.end())
			m = map_it->second;

		int bit_fast, bit_slow, bit_refill, bit_empty;
		if (channel == 0)
		{
			bit_fast = m.feed_fast_0;
			bit_slow = m.feed_slow_0;
			bit_refill = m.refill_valve_0;
			bit_empty = m.emptying_valve_0;
		}
		else
		{
			bit_fast = m.feed_fast_1;
			bit_slow = m.feed_slow_1;
			bit_refill = m.refill_valve_1;
			bit_empty = m.emptying_valve_1;
		}

		dit->second->ApplyDioOutputs(bit_fast, bit_slow, bit_refill, bit_empty,
									 fast, slow, refill, emptying);
	}

	void OutputManager::SetAlarm(uint32_t sub_id, bool active)
	{
		auto io_it = subsystem_io_map_.find(sub_id);
		if (io_it == subsystem_io_map_.end())
			return;
		auto dit = digital_ios_.find(io_it->second);
		if (dit == digital_ios_.end())
			return;

		auto map_it = subsystem_output_mapping_.find(sub_id);
		int bit_pos = (map_it != subsystem_output_mapping_.end()) ? map_it->second.alarm : 8;
		dit->second->SetOutputBit(bit_pos, active);
	}

	void OutputManager::SetRunning(uint32_t sub_id, bool running)
	{
		auto io_it = subsystem_io_map_.find(sub_id);
		if (io_it == subsystem_io_map_.end())
			return;
		auto dit = digital_ios_.find(io_it->second);
		if (dit == digital_ios_.end())
			return;

		auto map_it = subsystem_output_mapping_.find(sub_id);
		int bit_pos = (map_it != subsystem_output_mapping_.end()) ? map_it->second.running : 9;
		dit->second->SetOutputBit(bit_pos, running);
	}

	void OutputManager::SetWarning(uint32_t sub_id, bool warning)
	{
		auto io_it = subsystem_io_map_.find(sub_id);
		if (io_it == subsystem_io_map_.end())
			return;
		auto dit = digital_ios_.find(io_it->second);
		if (dit == digital_ios_.end())
			return;

		auto map_it = subsystem_output_mapping_.find(sub_id);
		int bit_pos = (map_it != subsystem_output_mapping_.end()) ? map_it->second.warning : 11;
		dit->second->SetOutputBit(bit_pos, warning);
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