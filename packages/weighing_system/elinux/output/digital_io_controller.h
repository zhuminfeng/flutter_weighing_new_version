#ifndef DIGITAL_IO_CONTROLLER_H
#define DIGITAL_IO_CONTROLLER_H

#include "../ethercat/ethercat_types.h"
#include "../ethercat/ethercat_slave_config.h"
#include "digital_output_mapping.h"
#include <cstdint>
#include <atomic>

namespace weighing
{

	class DigitalIOController
	{
	public:
		explicit DigitalIOController(uint16_t slave_position);

		void CyclicTask(uint8_t *domain_data);

		void SetBit(uint16_t bit_mask);
		void ClearBit(uint16_t bit_mask);
		void SetOutput(uint16_t value);
		// void ApplyDioOutputs(uint32_t subsystem_id,
		// 					 uint16_t channel,
		// 					 AppType app_type,
		// 					 bool fast,
		// 					 bool slow,
		// 					 bool refill,
		// 					 bool emptying,
		// 					 const DigitalOutputMap &map);
		// void SetAlarm(uint32_t subsystem_id, AppType app_type, bool active, const DigitalOutputMap &map);
		// void SetRunningIndicator(uint32_t subsystem_id, AppType app_type, bool running, const DigitalOutputMap &map);
		// void SetWarningIndicator(uint32_t subsystem_id, AppType app_type, bool warning, const DigitalOutputMap &map);

		// uint16_t GetInputs() const { return last_inputs_.load(); }

		// void ParseDioInputs(bool &start, bool &stop, bool &exec_refill,
		// 					bool &emptying, bool &interlock, bool &tare,
		// 					bool &zero, bool &jog) const;

	private:
		// void SetMappedSignal(uint32_t subsystem_id,
		// 					 uint16_t channel,
		// 					 AppType app_type,
		// 					 DigitalSignalType signal,
		// 					 bool on,
		// 					 const DigitalOutputMap &map);
		const DigitalIOOffsets *offsets_ = nullptr;
		// uint16_t slave_position_ = 0;
		std::atomic<uint16_t> output_value_{0};
		// std::atomic<uint16_t> last_inputs_{0};
	};

} // namespace weighing

#endif