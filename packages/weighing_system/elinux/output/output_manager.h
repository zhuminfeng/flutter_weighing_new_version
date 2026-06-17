#ifndef OUTPUT_MANAGER_H
#define OUTPUT_MANAGER_H

#include "../common_types.h"
#include "../ethercat/ethercat_master.h"
#include "servo_controller.h"
#include "digital_io_controller.h"

#include <memory>
#include <map>
#include <vector>
#include <functional>

namespace weighing
{

	// 回调传递原始16位输入字，由调用方负责应用自定义映射
	using DioInputCallback = DioInputRawCallback;

	class OutputManager
	{
	public:
		static OutputManager &Instance();

		bool Initialize();
		bool Start();
		void Stop();

		// 子系统级控制（通过映射查找从站）
		// servo_index: 子系统内第几个伺服（0 = 第一个，通常为主喂料伺服）
		void SetControlRate(uint32_t subsystem_id, float rate_pct, uint32_t servo_index = 0);
		void SetValveOutputs(uint32_t subsystem_id, uint16_t channel,
							 bool fast, bool slow, bool refill, bool emptying);

		// 指示灯/报警输出（通过子系统 ID 查找 IO 从站及输出映射）
		void SetAlarm(uint32_t sub_id, bool active);
		void SetRunning(uint32_t sub_id, bool running);
		void SetWarning(uint32_t sub_id, bool warning);

		void SetDioInputCallback(DioInputCallback cb) { dio_callback_ = cb; }

		// 子系统映射
		// 多次调用 MapSubsystemServo 可为同一子系统追加多个伺服（按追加顺序编号）
		void MapSubsystemServo(uint32_t sub_id, uint16_t servo_pos);
		void MapSubsystemIO(uint32_t sub_id, uint16_t io_pos);
		void SetSubsystemOutputMapping(uint32_t sub_id, const DioOutputMapping &mapping);

		// 查询映射
		uint16_t GetSubsystemIOPosition(uint32_t sub_id) const
		{
			auto it = subsystem_io_map_.find(sub_id);
			return (it != subsystem_io_map_.end()) ? it->second : 0;
		}

		// 返回子系统第 servo_index 个伺服的从站位置（不存在则返回 0）
		uint16_t GetSubsystemServoPosition(uint32_t sub_id, uint32_t servo_index = 0) const
		{
			auto it = subsystem_servo_map_.find(sub_id);
			if (it == subsystem_servo_map_.end() || servo_index >= it->second.size())
				return 0;
			return it->second[servo_index];
		}

		// 返回子系统所有伺服的从站位置列表
		const std::vector<uint16_t> &GetSubsystemServoPositions(uint32_t sub_id) const
		{
			static const std::vector<uint16_t> kEmpty;
			auto it = subsystem_servo_map_.find(sub_id);
			return (it != subsystem_servo_map_.end()) ? it->second : kEmpty;
		}

		// 直接访问 Controller
		ServoController *GetServo(uint16_t pos);
		DigitalIOController *GetDigitalIO(uint16_t pos);

	private:
		OutputManager() = default;
		~OutputManager() { Stop(); }

		void OnCyclicOutput(uint8_t *domain_data);

		std::map<uint16_t, std::unique_ptr<ServoController>> servos_;
		std::map<uint16_t, std::unique_ptr<DigitalIOController>> digital_ios_;

		// 子系统 -> 多个伺服从站位置（按追加顺序；index 0 通常为主喂料伺服）
		std::map<uint32_t, std::vector<uint16_t>> subsystem_servo_map_;
		std::map<uint32_t, uint16_t> subsystem_io_map_;
		std::map<uint32_t, DioOutputMapping> subsystem_output_mapping_;

		DioInputCallback dio_callback_;
		bool initialized_ = false;
	};

} // namespace weighing

#endif