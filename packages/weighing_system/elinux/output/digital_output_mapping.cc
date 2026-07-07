#include "digital_output_mapping.h"
#include <sstream>

namespace weighing
{

	bool DigitalOutputMap::Validate(std::string *err) const
	{
		// 1. 验证数字量
		for (const auto &b : cfg_.bindings)
		{
			if (b.bit_index > 15)
			{
				if (err)
					*err = "bit_index out of range: " + std::to_string(b.bit_index);
				return false;
			}
			if (b.channel > 1)
			{
				if (err)
					*err = "channel out of range: " + std::to_string(b.channel);
				return false;
			}
		}

		// 2. === 新增：验证伺服设备绑定合法性 ===
		// for (const auto &b : cfg_.servo_bindings)
		// {
		// 	if (b.servo_pos == 0) // 假设位置0为非法总线预留位
		// 	{
		// 		if (err)
		// 			*err = "Servo position cannot be 0 for subsystem " + std::to_string(b.subsystem_id);
		// 		return false;
		// 	}
		// }
		return true;
	}

	bool DigitalOutputMap::SetConfig(const DigitalOutputMapConfig &cfg, std::string *err)
	{
		cfg_ = cfg;
		return Validate(err);
	}

	std::optional<uint16_t> DigitalOutputMap::ResolveBit(uint32_t subsystem_id,
														 uint16_t io_pos,
														 uint16_t channel,
														 DigitalSignalType signal,
														 AppType app_type) const
	{
		const int app = static_cast<int>(app_type);
		for (const auto &b : cfg_.bindings)
		{
			if (!b.enabled)
				continue;
			if (b.subsystem_id != subsystem_id)
				continue;
			if (b.io_pos != io_pos)
				continue;
			if (b.channel != channel)
				continue;
			if (b.signal != signal)
				continue;
			if (!(b.app_scope == -1 || b.app_scope == app))
				continue;
			return static_cast<uint16_t>(1u << b.bit_index);
		}
		return std::nullopt;
	}

	static DigitalOutputBinding MakeBinding(uint32_t sub,
											uint16_t io_pos,
											uint16_t ch,
											DigitalSignalType sig,
											uint8_t bit,
											int app_scope = -1)
	{
		DigitalOutputBinding b;
		b.subsystem_id = sub;
		b.io_pos = io_pos;
		b.channel = ch;
		b.signal = sig;
		b.bit_index = bit;
		b.active_high = true;
		b.enabled = true;
		b.app_scope = app_scope; // -1 both
		return b;
	}

	DigitalOutputMapConfig DigitalOutputMap::BuildDefaultDigitalOutputMap(uint32_t subsystem_id,
																		  uint16_t io_pos)
	{
		DigitalOutputMapConfig cfg;
		cfg.version = 1;

		// channel 0: bits 0..3
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kFeedFast, 0));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kFeedSlow, 1));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kRefillValve, 2));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kEmptyingValve, 3));

		// channel 1: bits 4..7
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 1, DigitalSignalType::kFeedFast, 4));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 1, DigitalSignalType::kFeedSlow, 5));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 1, DigitalSignalType::kRefillValve, 6));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 1, DigitalSignalType::kEmptyingValve, 7));

		// indicators: bits 8..11（沿用现有定义）
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kAlarmOut, 8));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kRunningInd, 9));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kReadyInd, 10));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, 0, DigitalSignalType::kWarningInd, 11));

		return cfg;
	}

	DigitalOutputMapConfig DigitalOutputMap::BuildDefaultDigitalOutputMapForAll(
		const std::map<uint32_t, uint16_t> &subsystem_io_map)
	{
		DigitalOutputMapConfig all;
		all.version = 1;

		for (const auto &kv : subsystem_io_map)
		{
			const uint32_t sub_id = kv.first;
			const uint16_t io_pos = kv.second;
			if (io_pos == 0)
				continue; // 0 通常表示未映射

			auto one = BuildDefaultDigitalOutputMap(sub_id, io_pos);
			all.bindings.insert(all.bindings.end(), one.bindings.begin(), one.bindings.end());
		}

		return all;
	}

} // namespace weighing