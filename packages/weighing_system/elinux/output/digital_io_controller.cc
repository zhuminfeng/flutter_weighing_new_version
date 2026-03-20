#include "digital_io_controller.h"
#include "../ethercat/ethercat_master.h"

namespace weighing
{

	DigitalIOController::DigitalIOController(uint16_t slave_position)
		: slave_position_(slave_position)
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

	void DigitalIOController::ApplyDioOutputs(uint32_t subsystem_id,
											  uint16_t channel,
											  AppType app_type,
											  bool fast,
											  bool slow,
											  bool refill,
											  bool emptying,
											  const DigitalOutputMap &map)
	{
		SetMappedSignal(subsystem_id, channel, app_type, DigitalSignalType::kFeedFast, fast, map);
		SetMappedSignal(subsystem_id, channel, app_type, DigitalSignalType::kFeedSlow, slow, map);
		SetMappedSignal(subsystem_id, channel, app_type, DigitalSignalType::kRefillValve, refill, map);
		SetMappedSignal(subsystem_id, channel, app_type, DigitalSignalType::kEmptyingValve, emptying, map);
	}

	void DigitalIOController::SetAlarm(uint32_t subsystem_id, AppType app_type, bool active, const DigitalOutputMap &map)
	{
		SetMappedSignal(subsystem_id, 0, app_type, DigitalSignalType::kAlarmOut, active, map);
	}

	void DigitalIOController::SetRunningIndicator(uint32_t subsystem_id, AppType app_type, bool running, const DigitalOutputMap &map)
	{
		SetMappedSignal(subsystem_id, 0, app_type, DigitalSignalType::kRunningInd, running, map);
	}

	void DigitalIOController::SetWarningIndicator(uint32_t subsystem_id, AppType app_type, bool warning, const DigitalOutputMap &map)
	{
		SetMappedSignal(subsystem_id, 0, app_type, DigitalSignalType::kWarningInd, warning, map);
	}

	void DigitalIOController::SetMappedSignal(uint32_t subsystem_id,
											  uint16_t channel,
											  AppType app_type,
											  DigitalSignalType signal,
											  bool on,
											  const DigitalOutputMap &map)
	{
		auto bit = map.ResolveBit(subsystem_id, slave_position_, channel, signal, app_type);
		if (!bit.has_value())
			return;
		if (on)
			SetBit(*bit);
		else
			ClearBit(*bit);
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