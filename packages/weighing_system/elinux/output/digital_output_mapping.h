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
		kBagClamp = 8, // 新增：夹松袋（支持全电动伺服夹爪/气动夹爪）
	};

	struct DigitalOutputBinding
	{
		uint32_t subsystem_id = 0;
		uint16_t io_pos = 0;
		uint16_t channel = 0; // 0/1 for channelized signals
		DigitalSignalType signal = DigitalSignalType::kFeedFast;
		uint8_t bit_index = 0; // 0..15
		bool active_high = true;
		bool enabled = true;
		int app_scope = -1; // -1 both, 0 LIW, 1 Filling
	};

	// === 新增：伺服电机设备功能绑定结构体 ===
	struct ServoOutputBinding
	{
		uint32_t subsystem_id = 0;
		uint16_t servo_pos = 0;									 // EtherCAT 从站物理位置(position)
		DigitalSignalType signal = DigitalSignalType::kFeedFast; // 赋予该电机的工艺角色
		bool enabled = true;
		int app_scope = -1; // -1:通用, 0:失重, 1:灌装
	};

	struct DigitalOutputMapConfig
	{
		int version = 1;
		std::vector<DigitalOutputBinding> bindings;		// 数字量绑定列表
		std::vector<ServoOutputBinding> servo_bindings; // 新增：伺服设备绑定列表
	};

	class DigitalOutputMap
	{
	public:
		bool SetConfig(const DigitalOutputMapConfig &cfg, std::string *err = nullptr);
		const DigitalOutputMapConfig &GetConfig() const { return cfg_; }

		// 返回 bit mask（未考虑 active_high）
		std::optional<uint16_t> ResolveBit(uint32_t subsystem_id,
										   uint16_t io_pos,
										   uint16_t channel,
										   DigitalSignalType signal,
										   AppType app_type) const;

		bool Validate(std::string *err) const;

		// 单子系统默认映射（你已有）
		DigitalOutputMapConfig BuildDefaultDigitalOutputMap(uint32_t subsystem_id,
															uint16_t io_pos);

		// 多子系统默认映射：按 subsystem -> io_pos 批量生成
		DigitalOutputMapConfig BuildDefaultDigitalOutputMapForAll(
			const std::map<uint32_t, uint16_t> &subsystem_io_map);

	private:
		DigitalOutputMapConfig cfg_;
	};

} // namespace weighing

#endif