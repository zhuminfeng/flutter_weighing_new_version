#include "digital_io_controller.h"
#include "../ethercat/ethercat_master.h"

namespace weighing
{

	DigitalIOController::DigitalIOController(uint16_t slave_position)
	{
		const auto *rt = EtherCATMaster::Instance().GetSlaveRuntime(slave_position);
		if (rt && rt->role == SlaveRole::kDigitalIO)
		{
			offsets_ = &rt->offsets.io;
		}
	}

	void DigitalIOController::CyclicTask(uint8_t *domain_data)
	{
		if (!offsets_ || !domain_data)
			return;
		EC_WRITE_U16(domain_data + offsets_->off_do, output_value_.load());
		last_inputs_ = EC_READ_U16(domain_data + offsets_->off_di);
	}

	void DigitalIOController::SetBit(uint16_t bit_mask)
	{
		uint16_t current = output_value_.load();
		output_value_ = current | bit_mask;
	}

	void DigitalIOController::ClearBit(uint16_t bit_mask)
	{
		uint16_t current = output_value_.load();
		output_value_ = current & ~bit_mask;
	}

	void DigitalIOController::SetOutput(uint16_t value)
	{
		output_value_ = value;
	}

	void DigitalIOController::ApplyDioOutputs(uint16_t channel_offset,
											  bool feed_fast, bool feed_slow,
											  bool refill, bool emptying)
	{
		using namespace ec3a_io1632;

		uint16_t current = output_value_.load();

		// Select channel-specific bits (channel 0 or channel 1)
		uint16_t fast_bit, slow_bit, refill_bit, empty_bit;
		if (channel_offset == 0)
		{
			fast_bit = DO_Bit::FEED_FAST_0;
			slow_bit = DO_Bit::FEED_SLOW_0;
			refill_bit = DO_Bit::REFILL_VALVE_0;
			empty_bit = DO_Bit::EMPTYING_VALVE_0;
		}
		else
		{
			fast_bit = DO_Bit::FEED_FAST_1;
			slow_bit = DO_Bit::FEED_SLOW_1;
			refill_bit = DO_Bit::REFILL_VALVE_1;
			empty_bit = DO_Bit::EMPTYING_VALVE_1;
		}

		// Clear all channel bits first
		current &= ~(fast_bit | slow_bit | refill_bit | empty_bit);

		// Set active bits
		if (feed_fast)
			current |= fast_bit;
		if (feed_slow)
			current |= slow_bit;
		if (refill)
			current |= refill_bit;
		if (emptying)
			current |= empty_bit;

		output_value_ = current;
	}

	void DigitalIOController::SetAlarm(bool active)
	{
		if (active)
			SetBit(ec3a_io1632::DO_Bit::ALARM_OUT);
		else
			ClearBit(ec3a_io1632::DO_Bit::ALARM_OUT);
	}

	void DigitalIOController::SetRunningIndicator(bool running)
	{
		if (running)
			SetBit(ec3a_io1632::DO_Bit::RUNNING_IND);
		else
			ClearBit(ec3a_io1632::DO_Bit::RUNNING_IND);
	}

	void DigitalIOController::SetWarningIndicator(bool warning)
	{
		if (warning)
			SetBit(ec3a_io1632::DO_Bit::WARNING_IND);
		else
			ClearBit(ec3a_io1632::DO_Bit::WARNING_IND);
	}

	void DigitalIOController::ParseDioInputs(
		bool &start, bool &stop, bool &execute_refill,
		bool &emptying, bool &interlock, bool &tare,
		bool &zero, bool &jog_trigger) const
	{

		uint16_t di = last_inputs_.load();
		using namespace ec3a_io1632;

		start = (di & DI_Bit::START) != 0;
		stop = (di & DI_Bit::STOP) != 0;
		execute_refill = (di & DI_Bit::EXECUTE_REFILL) != 0;
		emptying = (di & DI_Bit::EMPTYING) != 0;
		interlock = (di & DI_Bit::INTERLOCK) != 0;
		tare = (di & DI_Bit::TARE) != 0;
		zero = (di & DI_Bit::ZERO) != 0;
		jog_trigger = (di & DI_Bit::JOG_TRIGGER) != 0;
	}

} // namespace weighing