#ifndef DIGITAL_OUTPUT_MAPPING_H
#define DIGITAL_OUTPUT_MAPPING_H

#include "../common_types.h"
#include <cstdint>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>
#include <map>

namespace weighing
{

	enum class DigitalSignalType : int
	{
		kFeedFast = 0,
		kFeedSlow = 1,
		kRefillValve = 2,
		kEmptyingValve = 3,
		kAlarmOut = 4,
		kRunningInd = 5,
		kWarningInd = 6,
		kReadyInd = 7,
		kBagClamp = 8,
	};

	struct DigitalOutputBinding
	{
		uint32_t subsystem_id = 0;
		uint16_t io_pos = 0;
		// 移除 channel
		DigitalSignalType signal = DigitalSignalType::kFeedFast;
		uint8_t bit_index = 0;
		bool active_high = true;
		bool enabled = true;
		int app_scope = -1;
	};

	struct ServoOutputBinding
	{
		uint32_t subsystem_id = 0;
		uint16_t servo_pos = 0;
		// 移除 channel
		DigitalSignalType signal = DigitalSignalType::kFeedFast;
		bool enabled = true;
		int app_scope = -1;
	};

	struct DigitalOutputMapConfig
	{
		int version = 1;
		std::vector<DigitalOutputBinding> bindings;
		std::vector<ServoOutputBinding> servo_bindings;
	};

	class DigitalOutputMap
	{
	public:
		bool SetConfig(const DigitalOutputMapConfig &cfg, std::string *err = nullptr);
		const DigitalOutputMapConfig &GetConfig() const { return cfg_; }

		// 移除传入的 channel 参数
		std::optional<uint16_t> ResolveBit(uint32_t subsystem_id,
										   uint16_t io_pos,
										   DigitalSignalType signal,
										   AppType app_type) const;

		bool Validate(std::string *err) const;

		DigitalOutputMapConfig BuildDefaultDigitalOutputMap(uint32_t subsystem_id,
															uint16_t io_pos);

		DigitalOutputMapConfig BuildDefaultDigitalOutputMapForAll(
			const std::map<uint32_t, uint16_t> &subsystem_io_map);

	private:
		DigitalOutputMapConfig cfg_;
	};

}

#endif