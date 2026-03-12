#ifndef ETHERCAT_SLAVE_CONFIG_H
#define ETHERCAT_SLAVE_CONFIG_H

#include "ethercat_types.h"
#include <cstdint>

namespace weighing
{

	// ============================================================================
	// EC3A-IO1632 远程IO总线模块
	// Vendor ID: 0x00000b95, Product code: 0x00001101
	// ============================================================================
	namespace ec3a_io1632
	{

		constexpr uint32_t VENDOR_ID = 0x00000b95;
		constexpr uint32_t PRODUCT_CODE = 0x00001101;
		constexpr uint32_t REVISION = 0x01020109;

		namespace DO_Bit
		{
			constexpr uint16_t FEED_FAST_0 = (1 << 0);
			constexpr uint16_t FEED_SLOW_0 = (1 << 1);
			constexpr uint16_t REFILL_VALVE_0 = (1 << 2);
			constexpr uint16_t EMPTYING_VALVE_0 = (1 << 3);
			constexpr uint16_t FEED_FAST_1 = (1 << 4);
			constexpr uint16_t FEED_SLOW_1 = (1 << 5);
			constexpr uint16_t REFILL_VALVE_1 = (1 << 6);
			constexpr uint16_t EMPTYING_VALVE_1 = (1 << 7);
			constexpr uint16_t ALARM_OUT = (1 << 8);
			constexpr uint16_t RUNNING_IND = (1 << 9);
			constexpr uint16_t READY_IND = (1 << 10);
			constexpr uint16_t WARNING_IND = (1 << 11);
		}

		namespace DI_Bit
		{
			constexpr uint16_t START = (1 << 0);
			constexpr uint16_t STOP = (1 << 1);
			constexpr uint16_t EXECUTE_REFILL = (1 << 2);
			constexpr uint16_t EMPTYING = (1 << 3);
			constexpr uint16_t INTERLOCK = (1 << 4);
			constexpr uint16_t TARE = (1 << 5);
			constexpr uint16_t ZERO = (1 << 6);
			constexpr uint16_t JOG_TRIGGER = (1 << 7);
		}

	} // namespace ec3a_io1632

	// ============================================================================
	// InoSV630N 汇川伺服驱动器 (DS402)
	// Vendor ID: 0x00100000, Product code: 0x000c0112
	// ============================================================================
	namespace inosv630n
	{

		constexpr uint32_t VENDOR_ID = 0x00100000;
		constexpr uint32_t PRODUCT_CODE = 0x000c0112;
		constexpr uint32_t REVISION = 0x00010000;

		namespace CtrlWord
		{
			constexpr uint16_t SWITCH_ON = (1 << 0);
			constexpr uint16_t ENABLE_VOLTAGE = (1 << 1);
			constexpr uint16_t QUICK_STOP = (1 << 2);
			constexpr uint16_t ENABLE_OPERATION = (1 << 3);
			constexpr uint16_t NEW_SET_POINT = (1 << 4);
			constexpr uint16_t CHANGE_SET_IMMED = (1 << 5);
			constexpr uint16_t ABS_REL = (1 << 6);
			constexpr uint16_t FAULT_RESET = (1 << 7);
			constexpr uint16_t HALT = (1 << 8);
		}

		namespace StatusWord
		{
			constexpr uint16_t READY_TO_SWITCH_ON = (1 << 0);
			constexpr uint16_t SWITCHED_ON = (1 << 1);
			constexpr uint16_t OPERATION_ENABLED = (1 << 2);
			constexpr uint16_t FAULT = (1 << 3);
			constexpr uint16_t VOLTAGE_ENABLED = (1 << 4);
			constexpr uint16_t QUICK_STOP_ACTIVE = (1 << 5);
			constexpr uint16_t SWITCH_ON_DISABLED = (1 << 6);
			constexpr uint16_t WARNING = (1 << 7);
			constexpr uint16_t TARGET_REACHED = (1 << 10);
			constexpr uint16_t SET_POINT_ACK = (1 << 12);
		}

		enum class Ds402State
		{
			kNotReadyToSwitchOn,
			kSwitchOnDisabled,
			kReadyToSwitchOn,
			kSwitchedOn,
			kOperationEnabled,
			kQuickStopActive,
			kFaultReactionActive,
			kFault,
			kUnknown,
		};

		inline Ds402State DecodeStatusWord(uint16_t sw)
		{
			uint8_t low = sw & 0x006F;
			if ((low & 0x004F) == 0x0000)
				return Ds402State::kNotReadyToSwitchOn;
			if ((low & 0x006F) == 0x0040)
				return Ds402State::kSwitchOnDisabled;
			if ((low & 0x006F) == 0x0021)
				return Ds402State::kReadyToSwitchOn;
			if ((low & 0x006F) == 0x0023)
				return Ds402State::kSwitchedOn;
			if ((low & 0x006F) == 0x0027)
				return Ds402State::kOperationEnabled;
			if ((low & 0x006F) == 0x0007)
				return Ds402State::kQuickStopActive;
			if ((low & 0x004F) == 0x000F)
				return Ds402State::kFaultReactionActive;
			if ((low & 0x004F) == 0x0008)
				return Ds402State::kFault;
			return Ds402State::kUnknown;
		}

	} // namespace inosv630n

	// ============================================================================
	// 从站自动识别
	// ============================================================================
	inline SlaveRole IdentifySlave(uint32_t vendor, uint32_t product)
	{
		if (vendor == ec3a_io1632::VENDOR_ID && product == ec3a_io1632::PRODUCT_CODE)
			return SlaveRole::kDigitalIO;
		if (vendor == inosv630n::VENDOR_ID && product == inosv630n::PRODUCT_CODE)
			return SlaveRole::kServo;
		// 称重从站 vendor/product 根据实际硬件配置
		return SlaveRole::kUnknown;
	}

} // namespace weighing

#endif // ETHERCAT_SLAVE_CONFIG_H