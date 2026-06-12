#ifndef APP_BASE_H
#define APP_BASE_H

#include "../common_types.h"
#include "../scale/scale_platform.h"
#include "../output/output_manager.h"
#include <atomic>
#include <thread>
#include <string>
#include <functional>
#include <mutex>

namespace weighing
{

	enum class AppRunState : int
	{
		kIdle = 0,
		kRunning = 1,
		kPaused = 2,
		kCompleted = 3,
		kError = 4,
		kRefilling = 5,
		kEmptying = 6,
	};

	struct AppStatusData
	{
		AppRunState state = AppRunState::kIdle;
		AppType app_type = AppType::kLossInWeight;
		double current_weight = 0.0;
		double current_flow = 0.0;
		double control_rate = 0.0;
		double target_flow = 0.0;
		double target_weight = 0.0;
		double accumulated_weight = 0.0;
		double total_accumulated = 0.0;
		double remaining_time = 0.0;
		int step_number = 0;
		std::string status_message;
		bool warning_active = false;
		std::string warning_message;
	};

	using AppStatusCallback = std::function<void(uint32_t subsystem_id, const AppStatusData &)>;

	class AppBase
	{
	public:
		AppBase(uint32_t subsystem_id, AppType type);
		virtual ~AppBase();

		AppBase(const AppBase &) = delete;
		AppBase &operator=(const AppBase &) = delete;

		virtual bool Initialize() = 0;
		virtual void Start();
		virtual void Stop();
		virtual void Pause();
		virtual void Resume();

		// DIO 输入处理（接收输入信号）
		virtual void ProcessDioInputs(const DioInputSignals &inputs) = 0;

		// 获取当前 DIO 输出状态（供查询）
		virtual DioOutputSignals GetDioOutputs() const { return dio_outputs_; }

		// Weight update from scale
		virtual void OnWeightUpdate(const WeightData &data) = 0;

		/// 多秤台模式：指定通道的重量更新
		virtual void OnChannelWeightUpdate(uint16_t channel, const WeightData &data)
		{
			// 默认行为：调用单秤台接口 (兼容性)
			OnWeightUpdate(data);
		}

		// Basic operations
		virtual void DoZero();
		virtual void DoTare();
		virtual void ClearTare();
		virtual void EPrint();

		// Getters
		AppRunState GetRunState() const { return run_state_.load(std::memory_order_acquire); }
		AppType GetAppType() const { return app_type_; }
		uint32_t GetSubsystemId() const { return subsystem_id_; }
		AppStatusData GetStatus() const;

		void SetScale(ScalePlatform *scale) { scale_ = scale; }
		void SetStatusCallback(AppStatusCallback cb) { status_callback_ = cb; }

	protected:
		virtual void ControlLoop() = 0;
		void SetRunState(AppRunState state);
		void EmitWarning(const std::string &msg);
		void ClearWarning();

		// === 新增：统一的信号驱动型伺服控制接口 ===
		// 1. 设置指定工艺电机的速度百分比 (CSV模式)
		void SetServoRate(DigitalSignalType signal, float rate_pct)
		{
			OutputManager::Instance().SetServoRateBySignal(subsystem_id_, signal, rate_pct);
		}

		// 2. 设置指定工艺电机的位置目标值 (CSP/PP模式，如夹袋)
		void SetServoPosition(DigitalSignalType signal, int32_t position)
		{
			OutputManager::Instance().SetServoPositionBySignal(subsystem_id_, signal, position);
		}

		// 3. 一键安全关断本子系统名下的所有伺服电机
		void StopAllServos()
		{
			OutputManager::Instance().StopAllServos(subsystem_id_);
		}

		void SetValveOutputs(uint16_t channel, bool fast, bool slow, bool refill, bool emptying)
		{
			OutputManager::Instance().SetValveOutputs(subsystem_id_, channel, app_type_, fast, slow, refill, emptying);
		}

		void SetAlarmOutput(bool active);
		void SetRunningOutput(bool running);
		void SetWarningOutput(bool warning);

		uint32_t subsystem_id_;
		AppType app_type_;
		ScalePlatform *scale_ = nullptr;

		std::atomic<AppRunState> run_state_{AppRunState::kIdle};
		std::thread control_thread_;
		std::atomic<bool> thread_running_{false};

		std::atomic<double> current_weight_{0.0};
		std::atomic<double> current_gross_{0.0};
		std::atomic<double> current_net_{0.0};
		std::atomic<bool> is_stable_{false};

		mutable std::mutex status_mutex_;
		AppStatusData status_data_;
		AppStatusCallback status_callback_;

		// DIO 输出状态（仅状态指示，阀门由 SetValveOutputs 控制）
		DioOutputSignals dio_outputs_;
	};

} // namespace weighing

#endif // APP_BASE_H