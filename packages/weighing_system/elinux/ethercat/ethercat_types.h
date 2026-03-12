#ifndef ETHERCAT_TYPES_H
#define ETHERCAT_TYPES_H

#include <cstdint>
#include <functional>
#include <vector>
#include <string>

namespace weighing
{

	// ============================================================================
	// 从站角色分类
	// ============================================================================
	enum class SlaveRole
	{
		kWeighingInput, // 称重模拟量/ADC输入从站
		kDigitalIO,		// EC3A-IO1632 数字IO
		kServo,			// InoSV630N 伺服驱动器
		kAnalogOutput,	// 比例阀等模拟量输出
		kUnknown,
	};

	// ============================================================================
	// 从站配置描述 (来自 JSON)
	// ============================================================================
	struct SlaveDescriptor
	{
		uint16_t alias = 0;
		uint16_t position = 0;
		uint32_t vendor_id = 0;
		uint32_t product_code = 0;
		uint32_t revision = 0;
		SlaveRole role = SlaveRole::kUnknown;
		std::string description;
		uint32_t assigned_subsystem = 0; // 所属子系统
		uint16_t channel_offset = 0;	 // IO通道偏移
	};

	// ============================================================================
	// PDO offset 集合 - 每个从站在 domain 中的偏移量
	// ============================================================================

	// EC3A-IO1632 offsets
	struct DigitalIOOffsets
	{
		unsigned int off_do = 0; // 0x7000:01 OUT_GEN_DO (16bit)
		unsigned int off_di = 0; // 0x6000:01 IN_GEN_DI  (16bit)
	};

	// InoSV630N offsets
	struct ServoOffsets
	{
		// RxPDO (Master -> Slave)
		unsigned int off_control_word = 0;	   // 0x6040:00 (16bit)
		unsigned int off_target_position = 0;  // 0x607A:00 (32bit)
		unsigned int off_touch_probe_func = 0; // 0x60B8:00 (16bit)
		unsigned int off_digital_outputs = 0;  // 0x60FE:01 (32bit)
		// TxPDO (Slave -> Master)
		unsigned int off_error_code = 0;	   // 0x603F:00 (16bit)
		unsigned int off_status_word = 0;	   // 0x6041:00 (16bit)
		unsigned int off_actual_position = 0;  // 0x6064:00 (32bit)
		unsigned int off_actual_torque = 0;	   // 0x6077:00 (16bit)
		unsigned int off_following_error = 0;  // 0x60F4:00 (32bit)
		unsigned int off_touch_probe_stat = 0; // 0x60B9:00 (16bit)
		unsigned int off_touch_probe_pos1 = 0; // 0x60BA:00 (32bit)
		unsigned int off_touch_probe_pos2 = 0; // 0x60BC:00 (32bit)
		unsigned int off_digital_inputs = 0;   // 0x60FD:00 (32bit)
	};

	// 称重从站 offsets (示例，根据实际从站调整)
	struct WeighingOffsets
	{
		unsigned int off_weight_raw = 0; // 原始重量/ADC值
		unsigned int off_status = 0;	 // 从站状态
	};

	// 统一的从站运行时数据
	struct SlaveRuntime
	{
		SlaveDescriptor descriptor;
		SlaveRole role = SlaveRole::kUnknown;

		// 【修改点】：为 union 定义类型名 OffsetsUnion，并添加默认构造函数
		union OffsetsUnion
		{
			DigitalIOOffsets io;
			ServoOffsets servo;
			WeighingOffsets weighing;

			// 显式提供默认构造函数，默认初始化 io 成员
			OffsetsUnion() : io{} {}
		} offsets;

		bool configured = false;
	};

} // namespace weighing

#endif // ETHERCAT_TYPES_H