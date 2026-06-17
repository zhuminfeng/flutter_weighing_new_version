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

	void DigitalIOController::SetOutputBit(int bit_pos, bool active)
	{
		if (bit_pos < 0 || bit_pos > 15)
			return;
		uint16_t mask = static_cast<uint16_t>(1u << static_cast<unsigned>(bit_pos));
		if (active)
			SetBit(mask);
		else
			ClearBit(mask);
	}

	void DigitalIOController::ApplyDioOutputs(int bit_fast, int bit_slow, int bit_refill, int bit_empty,
											  bool fast, bool slow, bool refill, bool emptying)
	{
		// Build masks for the four channel bits; skip any out-of-range index
		auto mask_of = [](int idx) -> uint16_t
		{
			if (idx < 0 || idx > 15)
				return 0;
			return static_cast<uint16_t>(1u << static_cast<unsigned>(idx));
		};

		uint16_t m_fast = mask_of(bit_fast);
		uint16_t m_slow = mask_of(bit_slow);
		uint16_t m_refill = mask_of(bit_refill);
		uint16_t m_empty = mask_of(bit_empty);
		uint16_t channel_mask = m_fast | m_slow | m_refill | m_empty;

		uint16_t current = output_value_.load();
		current &= ~channel_mask;
		if (fast)
			current |= m_fast;
		if (slow)
			current |= m_slow;
		if (refill)
			current |= m_refill;
		if (emptying)
			current |= m_empty;
		output_value_ = current;
	}

	void DigitalIOController::SetAlarm(bool active)
	{
		SetOutputBit(8, active); // default: ALARM_OUT = bit 8
	}

	void DigitalIOController::SetRunningIndicator(bool running)
	{
		SetOutputBit(9, running); // default: RUNNING_IND = bit 9
	}

	void DigitalIOController::SetWarningIndicator(bool warning)
	{
		SetOutputBit(11, warning); // default: WARNING_IND = bit 11
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