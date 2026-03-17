#ifndef SERVO_CONTROLLER_H
#define SERVO_CONTROLLER_H

#include "../ethercat/ethercat_types.h"
#include "../ethercat/ethercat_slave_config.h"
#include "../ethercat/ethercat_master.h"
#include <cstdint>
#include <atomic>

namespace weighing
{

	class ServoController
	{
	public:
		explicit ServoController(uint16_t slave_position);

		// 每个周期在 output callback 中调用
		void CyclicTask(uint8_t *domain_data);

		void Enable();
		void Disable();
		void FaultReset();
		void Halt();
		void SetControlRate(float rate_pct);
		void SetTargetPosition(int32_t position);
		void SetDigitalOutputs(uint32_t outputs);

		bool IsEnabled() const { return enabled_.load(); }
		bool IsFaulted() const { return faulted_.load(); }
		uint16_t GetStatusWord() const { return last_status_word_.load(); }
		int32_t GetActualPosition() const { return actual_position_.load(); }
		int16_t GetActualTorque() const { return actual_torque_.load(); }
		uint16_t GetErrorCode() const { return error_code_.load(); }

		void SetMaxSpeed(int32_t max_speed) { max_speed_ = max_speed; }

	private:
		const ServoOffsets *offsets_ = nullptr;

		std::atomic<bool> enable_request_{false};
		std::atomic<bool> disable_request_{false};
		std::atomic<bool> fault_reset_request_{false};
		std::atomic<bool> halt_request_{false};

		std::atomic<float> target_rate_{0.0f};
		std::atomic<int32_t> target_position_{0};
		std::atomic<uint32_t> target_digital_out_{0};

		std::atomic<bool> enabled_{false};
		std::atomic<bool> faulted_{false};
		std::atomic<uint16_t> last_status_word_{0};
		std::atomic<int32_t> actual_velocity_{0};
		std::atomic<int32_t> actual_position_{0};
		std::atomic<int16_t> actual_torque_{0};
		std::atomic<uint16_t> error_code_{0};

		int32_t max_speed_ = 1000000;

		// 【新增】：用于复刻 C 语言状态机的掩码
		uint16_t state_command_mask_ = 0x004F;

		uint16_t BuildControlWord(inosv630n::Ds402State state);
	};

} // namespace weighing

#endif