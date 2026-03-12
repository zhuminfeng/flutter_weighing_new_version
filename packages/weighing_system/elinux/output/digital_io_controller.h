#ifndef DIGITAL_IO_CONTROLLER_H
#define DIGITAL_IO_CONTROLLER_H

#include "../ethercat/ethercat_types.h"
#include "../ethercat/ethercat_slave_config.h"
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
		void ApplyDioOutputs(uint16_t channel, bool fast, bool slow, bool refill, bool emptying);
		void SetAlarm(bool active);
		void SetRunningIndicator(bool running);
		void SetWarningIndicator(bool warning);

		uint16_t GetInputs() const { return last_inputs_.load(); }
		void ParseDioInputs(bool &start, bool &stop, bool &exec_refill,
							bool &emptying, bool &interlock, bool &tare,
							bool &zero, bool &jog) const;

	private:
		const DigitalIOOffsets *offsets_ = nullptr;
		std::atomic<uint16_t> output_value_{0};
		std::atomic<uint16_t> last_inputs_{0};
	};

} // namespace weighing

#endif