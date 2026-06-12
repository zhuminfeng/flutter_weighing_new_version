#ifndef LIW_APPLICATION_H
#define LIW_APPLICATION_H

#include "../app_base.h"
#include "liw_pid_controller.h"
#include <chrono>

namespace weighing
{

	// === LIW Configuration Structures ===

	struct LiwBaseConfig
	{
		LiwMode mode = LiwMode::kContinuous;
		LiwSubMode sub_mode = LiwSubMode::kFlowControl;
	};

	struct LiwSystemConfig
	{
		float safety_limit = 100.0f;	   // %
		float hopper_min = 0.0f;		   // kg
		float hopper_max = 15.0f;		   // kg
		float target_flow = 50.0f;		   // kg/h (when sub_mode = flow control)
		float target_control_rate = 10.0f; // % (when sub_mode = fixed frequency)
		bool pre_refill = false;
	};

	struct LiwSystemIdConfig
	{
		float adjust_range_lower = 0.0f;  // %
		float adjust_range_upper = 90.0f; // %
		bool smart_step_control = false;
		float step_duration = 10.0f; // seconds
		float filter_window = 0.5f;	 // seconds
	};

	struct LiwControllerConfig
	{
		PidTuningMode tuning_mode = PidTuningMode::kManual;
		float filter_window = 0.5f;
		float Kp = 1.0f;
		float Ki = 1.0f;
		float Kd = 0.0f;
		float max_flow = 100.0f;   // kg/h
		float startup_time = 0.0f; // seconds
	};

	struct LiwRefillConfig
	{
		RefillMode mode = RefillMode::kAutomatic;
		float lower_limit = 1.0f;  // kg
		float upper_limit = 10.0f; // kg
		RefillControlMode control_mode = RefillControlMode::kLastFrequency;
		float control_setpoint = 10.0f; // % (when fixed output)
		float stabilize_time = 10.0f;	// seconds

		// === 新增：补料比例因子 (默认 100%) ===
		float refill_scale_factor = 100.0f;
	};

	struct LiwTargetValuesConfig
	{
		float batch_target = 1.0f;		  // kg
		float in_flight = 0.0f;			  // kg
		float fine_feed_threshold = 0.0f; // kg
		float fine_feed_flow = 2.0f;	  // kg/h
	};

	struct LiwToleranceCheckConfig
	{
		float pre_check_delay = 0.0f;	// seconds
		float stability_timeout = 0.0f; // seconds
		float tolerance = 0.0f;			// kg
	};

	struct LiwEmptyingConfig
	{
		bool auto_stop_at_alarm = true;
		float control_setpoint = 10.0f; // %
	};

	struct LiwWarningConfig
	{
		float control_rate_lower = 20.0f; // %
		float control_rate_upper = 80.0f; // %
		float refill_timeout = 10.0f;	  // seconds
		bool stop_on_error = false;
	};

	struct LiwFlowMonitorConfig
	{
		float evaluation_window = 3.0f;	   // seconds
		float deviation_threshold = 10.0f; // %
		float surge_threshold = 150.0f;	   // %
	};

	struct LiwAdvancedConfig
	{
		bool interlock_enabled = false;
		float interlock_delay = 0.0f; // seconds
	};

	struct LiwStatsConfig
	{
		float sample_period = 60.0f;	// seconds
		float sample_tolerance = 10.0f; // %
	};

	// === LIW Statistics ===

	struct LiwStatistics
	{
		double startup_accumulated = 0.0;
		double total_accumulated = 0.0;
		double sample_weight = 0.0;
		double last_sample_time = 0.0;
		int sample_count = 0;
	};

	// === LIW Application ===

	class LiwApplication : public AppBase
	{
	public:
		explicit LiwApplication(uint32_t subsystem_id);
		~LiwApplication() override;

		bool Initialize() override;
		void Start() override;
		void Stop() override;

		void ProcessDioInputs(const DioInputSignals &inputs) override;
		void OnWeightUpdate(const WeightData &data) override;

		// Configuration
		void SetBaseConfig(const LiwBaseConfig &cfg) { base_config_ = cfg; }
		void SetSystemConfig(const LiwSystemConfig &cfg) { system_config_ = cfg; }
		void SetSystemIdConfig(const LiwSystemIdConfig &cfg) { sysid_config_ = cfg; }
		void SetControllerConfig(const LiwControllerConfig &cfg);
		void SetRefillConfig(const LiwRefillConfig &cfg) { refill_config_ = cfg; }
		void SetTargetValuesConfig(const LiwTargetValuesConfig &cfg) { target_config_ = cfg; }
		void SetToleranceCheckConfig(const LiwToleranceCheckConfig &cfg) { tolerance_config_ = cfg; }
		void SetEmptyingConfig(const LiwEmptyingConfig &cfg) { emptying_config_ = cfg; }
		void SetWarningConfig(const LiwWarningConfig &cfg) { warning_config_ = cfg; }
		void SetFlowMonitorConfig(const LiwFlowMonitorConfig &cfg) { flow_monitor_config_ = cfg; }
		void SetAdvancedConfig(const LiwAdvancedConfig &cfg) { advanced_config_ = cfg; }
		void SetStatsConfig(const LiwStatsConfig &cfg) { stats_config_ = cfg; }

		LiwBaseConfig GetBaseConfig() const { return base_config_; }
		LiwSystemConfig GetSystemConfig() const { return system_config_; }
		LiwSystemIdConfig GetSystemIdConfig() const { return sysid_config_; }
		LiwControllerConfig GetControllerConfig() const { return controller_config_; }
		LiwRefillConfig GetRefillConfig() const { return refill_config_; }
		LiwTargetValuesConfig GetTargetValuesConfig() const { return target_config_; }
		LiwToleranceCheckConfig GetToleranceCheckConfig() const { return tolerance_config_; }
		LiwEmptyingConfig GetEmptyingConfig() const { return emptying_config_; }
		LiwWarningConfig GetWarningConfig() const { return warning_config_; }
		LiwFlowMonitorConfig GetFlowMonitorConfig() const { return flow_monitor_config_; }
		LiwAdvancedConfig GetAdvancedConfig() const { return advanced_config_; }
		LiwStatsConfig GetStatsConfig() const { return stats_config_; }
		LiwStatistics GetStatistics() const { return stats_; }

		// Emptying control
		void TriggerEmptying();
		void CancelEmptying();

		// Refill control (manual mode)
		void TriggerManualRefill();
		void EndManualRefill();

		// Statistics
		void ResetStatistics();

	private:
		void ControlLoop() override;
		void ContinuousFlowControlLoop(float dt);
		void ContinuousFixedFreqLoop(float dt);
		void BatchModeLoop(float dt);
		void SystemIdLoop(float dt);

		// Flow calculation
		float CalculateFlow(float dt);

		// Refill management
		void CheckRefill();
		void StartRefill();
		void EndRefill();
		void StartStabilization();
		bool IsRefilling() const { return is_refilling_.load(); }

		// Pre-refill management
		void StartPreRefill();
		void EndPreRefill();
		bool IsPreRefilling() const { return is_pre_refilling_.load(); }
		bool IsWaitingForManualPreRefill() const { return waiting_for_manual_pre_refill_.load(); }

		// Warning checks
		void CheckWarnings();

		enum class SysIdPhase
		{
			kSettling,
			kMeasuring
		}; // 识别子阶段
		SysIdPhase sysid_phase_ = SysIdPhase::kSettling;

		struct SysIdPoint
		{
			float rate;
			float flow;
		};
		std::vector<SysIdPoint> sysid_points_; // 存储识别到的 5 个点

		void CalculateParametersFromSysId(); // 核心计算算法

		// Configuration
		LiwBaseConfig base_config_;
		LiwSystemConfig system_config_;
		LiwSystemIdConfig sysid_config_;
		LiwControllerConfig controller_config_;
		LiwRefillConfig refill_config_;
		LiwTargetValuesConfig target_config_;
		LiwToleranceCheckConfig tolerance_config_;
		LiwEmptyingConfig emptying_config_;
		LiwWarningConfig warning_config_;
		LiwFlowMonitorConfig flow_monitor_config_;
		LiwAdvancedConfig advanced_config_;
		LiwStatsConfig stats_config_;

		// PID controller
		LiwPidController pid_;

		// State
		std::atomic<bool> is_refilling_{false};
		std::atomic<bool> is_emptying_{false};
		std::atomic<bool> is_in_startup_{false};

		// 新增：预补料状态标记
		std::atomic<bool> is_pre_refilling_{false};
		std::atomic<bool> waiting_for_manual_pre_refill_{false};

		std::atomic<bool> is_stabilizing_{false};			 // 新增：稳定期状态
		std::atomic<bool> waiting_for_manual_refill_{false}; // 新增：待补料指示

		// Flow calculation
		double prev_weight_ = 0.0;
		double current_flow_ = 0.0;
		double refill_last_control_rate_ = 0.0;

		// === 新增：用于智能适应的平滑基准频率 ===
		double refill_smart_base_rate_ = 0.0;

		// Timing
		std::chrono::steady_clock::time_point last_time_;
		std::chrono::steady_clock::time_point startup_start_;
		std::chrono::steady_clock::time_point refill_start_;
		std::chrono::steady_clock::time_point sample_start_;

		std::chrono::steady_clock::time_point stabilize_start_;

		// Statistics
		LiwStatistics stats_;

		// Batch mode state
		double batch_accumulated_ = 0.0;
		bool batch_fine_feed_ = false;
		bool batch_completed_ = false;

		// System identification state
		int sysid_step_ = 0;
		int sysid_total_steps_ = 5;
		float sysid_current_rate_ = 0.0f;
		std::chrono::steady_clock::time_point sysid_step_start_;
		double sysid_step_start_weight_ = 0.0;

		// Interlock
		bool interlock_active_ = true;
	};

} // namespace weighing

#endif // LIW_APPLICATION_H