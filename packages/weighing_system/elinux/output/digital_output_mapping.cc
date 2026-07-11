#include "digital_output_mapping.h"
#include <sstream>

namespace weighing
{

	bool DigitalOutputMap::Validate(std::string *err) const
	{
		for (const auto &b : cfg_.bindings)
		{
			if (b.bit_index > 15)
			{
				if (err)
					*err = "bit_index out of range: " + std::to_string(b.bit_index);
				return false;
			}
			// 移除了对 channel 的判断
		}
		return true;
	}

	bool DigitalOutputMap::SetConfig(const DigitalOutputMapConfig &cfg, std::string *err)
	{
		cfg_ = cfg;
		return Validate(err);
	}

	// 移除 channel 参数
	std::optional<uint16_t> DigitalOutputMap::ResolveBit(uint32_t subsystem_id,
														 uint16_t io_pos,
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
			// 移除 if (b.channel != channel)
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
											DigitalSignalType sig,
											uint8_t bit,
											int app_scope = -1)
	{
		DigitalOutputBinding b;
		b.subsystem_id = sub;
		b.io_pos = io_pos;
		b.signal = sig;
		b.bit_index = bit;
		b.active_high = true;
		b.enabled = true;
		b.app_scope = app_scope;
		return b;
	}

	DigitalOutputMapConfig DigitalOutputMap::BuildDefaultDigitalOutputMap(uint32_t subsystem_id,
																		  uint16_t io_pos)
	{
		DigitalOutputMapConfig cfg;
		cfg.version = 1;

		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kFeedFast, 0));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kFeedSlow, 1));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kRefillValve, 2));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kEmptyingValve, 3));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kAlarmOut, 8));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kRunningInd, 9));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kReadyInd, 10));
		cfg.bindings.push_back(MakeBinding(subsystem_id, io_pos, DigitalSignalType::kWarningInd, 11));

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
				continue;

			auto one = BuildDefaultDigitalOutputMap(sub_id, io_pos);
			all.bindings.insert(all.bindings.end(), one.bindings.begin(), one.bindings.end());
		}

		return all;
	}

}