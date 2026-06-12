#ifndef OUTPUT_MANAGER_H
#define OUTPUT_MANAGER_H

#include "../common_types.h"
#include "../ethercat/ethercat_master.h"
#include "servo_controller.h"
#include "digital_io_controller.h"
#include "digital_output_mapping.h"

#include <memory>
#include <map>
#include <functional>

namespace weighing
{

	// 回调使用 DioInputSignals（只含输入）
	using DioInputCallback = std::function<void(uint32_t io_pos, const DioInputSignals &signals)>;

	class OutputManager
	{
	public:
		static OutputManager &Instance();

		bool Initialize();
		bool Start();
		void Stop();

		// === 核心改造：基于功能信号点驱动任意数量的伺服电机 ===

		// 1. 速度或频率控制：统一设置某种信号角色（如快喂料、卸料、补料）下所有伺服的速度百分比 (CSV模式)
		void SetServoRateBySignal(uint32_t subsystem_id, DigitalSignalType signal, float rate_pct);

		// 2. 位置控制：统一设置某种信号角色（如伺服夹爪）下所有伺服的目标编码器绝对位置 (CSP/PP模式)
		void SetServoPositionBySignal(uint32_t subsystem_id, DigitalSignalType signal, int32_t position);

		// 3. 安全急停：停止该子系统下的所有伺服电机
		void StopAllServos(uint32_t subsystem_id);
		void SetValveOutputs(uint32_t subsystem_id,
							 uint16_t channel,
							 AppType app_type,
							 bool fast, bool slow, bool refill, bool emptying);

		// 指示灯/报警输出（直接操作指定 IO 从站位置）
		void SetAlarm(uint32_t subsystem_id, AppType app_type, bool active);
		void SetRunning(uint32_t subsystem_id, AppType app_type, bool running);
		void SetWarning(uint32_t subsystem_id, AppType app_type, bool warning);

		void SetDioInputCallback(DioInputCallback cb) { dio_callback_ = cb; }

		// 子系统映射
		// void MapSubsystemServo(uint32_t sub_id, uint16_t channel, uint16_t servo_pos);
		void MapSubsystemIO(uint32_t sub_id, uint16_t io_pos);

		// 查询映射
		uint16_t GetSubsystemIOPosition(uint32_t sub_id) const
		{
			auto it = subsystem_io_map_.find(sub_id);
			return (it != subsystem_io_map_.end()) ? it->second : 0;
		}

		// === 修改 3：查询映射时增加 channel 参数 ===
		// uint16_t GetSubsystemServoPosition(uint32_t sub_id, uint16_t channel) const
		// {
		// 	auto it = subsystem_servo_map_.find(sub_id);
		// 	if (it != subsystem_servo_map_.end())
		// 	{
		// 		auto chan_it = it->second.find(channel);
		// 		if (chan_it != it->second.end())
		// 		{
		// 			return chan_it->second;
		// 		}
		// 	}
		// 	return 0;
		// }

		// 直接访问 Controller
		ServoController *GetServo(uint16_t pos);
		DigitalIOController *GetDigitalIO(uint16_t pos);

		bool UpdateDigitalOutputMap(const DigitalOutputMapConfig &cfg, std::string *err = nullptr);
		DigitalOutputMapConfig GetDigitalOutputMapConfig() const;

		DigitalOutputMap GetDigitalOutputMap() { return dio_map_; }

		const std::map<uint32_t, uint16_t> &GetSubsystemIOMap() const { return subsystem_io_map_; }

	private:
		OutputManager() = default;
		~OutputManager() { Stop(); }

		void OnCyclicOutput(uint8_t *domain_data);
		DigitalOutputMap dio_map_;

		std::map<uint16_t, std::unique_ptr<ServoController>> servos_;
		std::map<uint16_t, std::unique_ptr<DigitalIOController>> digital_ios_;

		// === 核心数据结构修改 ===
		// 动态路由表：子系统ID -> (工艺信号类型 -> 物理从站位置数组)
		// 这样设计使得任意信号均可绑定 0 个、1 个或 N 个伺服电机，实现完全的自定义
		std::map<uint32_t, std::map<DigitalSignalType, std::vector<uint16_t>>> subsystem_servo_route_;
		std::map<uint32_t, uint16_t> subsystem_io_map_;

		DioInputCallback dio_callback_;
		bool initialized_ = false;
	};

} // namespace weighing

#endif