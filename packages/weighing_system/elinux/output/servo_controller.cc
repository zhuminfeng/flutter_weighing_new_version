#include "servo_controller.h"
#include <cstdio>

namespace weighing
{

	ServoController::ServoController(uint16_t slave_position)
	{
		const auto *rt = EtherCATMaster::Instance().GetSlaveRuntime(slave_position);
		if (rt && rt->role == SlaveRole::kServo)
		{
			offsets_ = &rt->offsets.servo;
		}
	}

	void ServoController::Enable()
	{
		enable_request_ = true;
		disable_request_ = false;
	}
	void ServoController::Disable()
	{
		disable_request_ = true;
		enable_request_ = false;
	}
	void ServoController::FaultReset() { fault_reset_request_ = true; }
	void ServoController::Halt() { halt_request_ = true; }
	void ServoController::SetControlRate(float r) { target_rate_ = (r < 0 ? 0 : (r > 100 ? 100 : r)); }
	void ServoController::SetTargetPosition(int32_t p) { target_position_ = p; }
	void ServoController::SetDigitalOutputs(uint32_t o) { target_digital_out_ = o; }

	void ServoController::CyclicTask(uint8_t *domain_data)
	{
		if (!offsets_ || !domain_data)
			return;

		// Read TxPDO
		uint16_t sw = EC_READ_U16(domain_data + offsets_->off_status_word);
		last_status_word_ = sw;
		error_code_ = EC_READ_U16(domain_data + offsets_->off_error_code);
		actual_position_ = EC_READ_S32(domain_data + offsets_->off_actual_position);
		actual_torque_ = static_cast<int16_t>(EC_READ_U16(domain_data + offsets_->off_actual_torque));

		auto state = inosv630n::DecodeStatusWord(sw);
		bool was_enabled = enabled_.load();
		enabled_ = (state == inosv630n::Ds402State::kOperationEnabled);
		faulted_ = (state == inosv630n::Ds402State::kFault ||
					state == inosv630n::Ds402State::kFaultReactionActive);

		// 【新增逻辑】：刚进入 Enable 状态时，对齐目标位置和实际位置，防止指令突变
		if (!was_enabled && enabled_.load())
		{
			target_position_ = actual_position_.load();
		}
		// Build control word
		uint16_t cw = BuildControlWord(state);

		// Rate -> position increment
		float rate = target_rate_.load();
		int32_t pos = target_position_.load();
		if (rate > 0.001f && enabled_.load())
		{
			int32_t inc = static_cast<int32_t>(
				(rate / 100.0f) * static_cast<float>(max_speed_) / 1000.0f);
			// pos = actual_position_.load() + inc;
			pos += inc;
			target_position_ = pos;
		}

		// Write RxPDO
		EC_WRITE_U16(domain_data + offsets_->off_control_word, cw);
		EC_WRITE_S32(domain_data + offsets_->off_target_position, pos);
		EC_WRITE_U16(domain_data + offsets_->off_touch_probe_func, 0);
		EC_WRITE_U32(domain_data + offsets_->off_digital_outputs, target_digital_out_.load());
	}

	uint16_t ServoController::BuildControlWord(inosv630n::Ds402State current_state)
	{
		using namespace inosv630n;

		if (fault_reset_request_.load())
		{
			fault_reset_request_ = false;
			if (current_state == Ds402State::kFault)
				return CtrlWord::FAULT_RESET;
		}

		if (halt_request_.load())
		{
			halt_request_ = false;
			return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE |
				   CtrlWord::QUICK_STOP | CtrlWord::ENABLE_OPERATION | CtrlWord::HALT;
		}

		if (disable_request_.load())
		{
			disable_request_ = false;
			enable_request_ = false;
			return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE | CtrlWord::QUICK_STOP;
		}

		if (enable_request_.load())
		{
			switch (current_state)
			{
			case Ds402State::kSwitchOnDisabled:
				return CtrlWord::ENABLE_VOLTAGE | CtrlWord::QUICK_STOP;
			case Ds402State::kReadyToSwitchOn:
				return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE | CtrlWord::QUICK_STOP;
			case Ds402State::kSwitchedOn:
				return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE |
					   CtrlWord::QUICK_STOP | CtrlWord::ENABLE_OPERATION;
			case Ds402State::kOperationEnabled:
				enable_request_ = false;
				return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE |
					   CtrlWord::QUICK_STOP | CtrlWord::ENABLE_OPERATION |
					   CtrlWord::NEW_SET_POINT | CtrlWord::CHANGE_SET_IMMED;
			case Ds402State::kFault:
				return CtrlWord::FAULT_RESET;
			default:
				return CtrlWord::ENABLE_VOLTAGE | CtrlWord::QUICK_STOP;
			}
		}

		if (current_state == Ds402State::kOperationEnabled)
		{
			return CtrlWord::SWITCH_ON | CtrlWord::ENABLE_VOLTAGE |
				   CtrlWord::QUICK_STOP | CtrlWord::ENABLE_OPERATION |
				   CtrlWord::NEW_SET_POINT | CtrlWord::CHANGE_SET_IMMED;
		}

		return 0;
	}

} // namespace weighing