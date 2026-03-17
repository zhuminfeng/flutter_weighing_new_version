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

		// 1. 读取状态字和当前实际速度
		uint16_t status = EC_READ_U16(domain_data + offsets_->off_status_word);
		int32_t current_speed = EC_READ_S32(domain_data + offsets_->off_actual_velocity);

		last_status_word_.store(status);
		actual_velocity_.store(current_speed);

		// ============ 状态机诊断打印 ============
		static uint16_t last_print_status = 0xFFFF;
		if ((status & 0x006F) != last_print_status)
		{
			last_print_status = status & 0x006F;
			printf(">> [Servo] CiA402 State changed. Masked Status: 0x%04X, Full Status: 0x%04X\n", last_print_status, status);
		}

		// ====================================================================
		// 【核心修复】：未点击 Start 前，必须向控制字写入 0x0000
		// 绝对不能提前写入 0x0006 或者 0x09 模式！这会打断伺服的内部初始化自动跃迁。
		// C语言测试代码能跑通，就是因为它的 domain 数据默认全是 0！
		// ====================================================================
		if (!enable_request_.load())
		{
			// 模拟 C 语言初始化时的内存状态：全 0
			EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x0000);
			EC_WRITE_S32(domain_data + offsets_->off_target_velocity, 0);
			state_command_mask_ = 0x004F; // 重置掩码，随时准备重新启动
			return;
		}

		// ====================================================================
		// 2. 标准且严谨的 CiA402 状态机推进 (完全复刻 C 语言版本)
		// 只有进入此区块，才说明用户点击了 Start，我们才开始介入并激活电机
		// ====================================================================
		if ((status & state_command_mask_) == 0x0040)
		{
			// 此时伺服已经自动就绪 (Switch On Disabled)
			// 我们才开始写入 模式9 (CSV)，以及加减速
			EC_WRITE_U8(domain_data + offsets_->off_operation_mode, 0x09);
			EC_WRITE_U32(domain_data + offsets_->off_profile_accel, 20000);
			EC_WRITE_U32(domain_data + offsets_->off_profile_decel, 20000);

			// 下发 Shutdown (0x06)
			EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x0006);
			state_command_mask_ = 0x006F;
		}
		else if ((status & state_command_mask_) == 0x0021)
		{
			// Ready to Switch On -> Switch On (0x07)
			EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x0007);
			state_command_mask_ = 0x006F;
		}
		else if ((status & state_command_mask_) == 0x0023)
		{
			// Switched On -> Enable Operation (0x0F)
			EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x000F);
			state_command_mask_ = 0x006F;
		}
		else if ((status & state_command_mask_) == 0x0027)
		{
			// Operation Enabled (完全激活) -> 必须持续发 0x0F
			EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x000F);

			// ===== 计算并下发目标速度 =====
			float rate = target_rate_.load();
			int32_t target_spd = 0;

			if (rate > 0.01f)
			{
				target_spd = static_cast<int32_t>((rate / 100.0f) * max_speed_);
			}

			// 防冲击保护逻辑 (复刻 C 代码逻辑)
			if (current_speed == 0 || target_spd == 0)
			{
				EC_WRITE_S32(domain_data + offsets_->off_target_velocity, target_spd);
			}
			else
			{
				EC_WRITE_S32(domain_data + offsets_->off_target_velocity, target_spd);
			}

			// ============ 运行数据诊断打印 ============
			// 每隔 1000 个周期（1秒）打印一次运行状态，确认控制率是否传到了底层
			static int dbg_count = 0;
			if (++dbg_count >= 1000)
			{
				printf(">> [Servo Running] UI Rate: %.1f%% | TargetSpd CMD: %d | ActualSpd: %d\n",
					   rate, target_spd, current_speed);
				dbg_count = 0;
			}
		}
		else if ((status & 0x0008) == 0x0008)
		{
			// State: Fault (故障报警状态)
			if (fault_reset_request_.load())
			{
				EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x0080); // 发送 Fault Reset
				fault_reset_request_ = false;
			}
			else
			{
				EC_WRITE_U16(domain_data + offsets_->off_control_word, 0x0000);
			}
		}
	}

} // namespace weighing