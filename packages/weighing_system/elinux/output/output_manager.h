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

		// 子系统级控制（通过映射查找从站）
		void SetControlRate(uint32_t subsystem_id, float rate_pct);
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
		void MapSubsystemServo(uint32_t sub_id, uint16_t servo_pos);
		void MapSubsystemIO(uint32_t sub_id, uint16_t io_pos);

		// 查询映射
		uint16_t GetSubsystemIOPosition(uint32_t sub_id) const
		{
			auto it = subsystem_io_map_.find(sub_id);
			return (it != subsystem_io_map_.end()) ? it->second : 0;
		}

		uint16_t GetSubsystemServoPosition(uint32_t sub_id) const
		{
			auto it = subsystem_servo_map_.find(sub_id);
			return (it != subsystem_servo_map_.end()) ? it->second : 0;
		}

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

		std::map<uint32_t, uint16_t> subsystem_servo_map_;
		std::map<uint32_t, uint16_t> subsystem_io_map_;

		DioInputCallback dio_callback_;
		bool initialized_ = false;
	};

} // namespace weighing

#endif