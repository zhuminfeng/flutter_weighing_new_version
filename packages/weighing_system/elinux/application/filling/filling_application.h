#ifndef FILLING_APPLICATION_H
#define FILLING_APPLICATION_H

#include "../app_base.h"
#include <chrono>

namespace weighing
{

	// === Filling Configuration Structures ===
	// （配置结构体和枚举全部保持不变）

	struct FillingGeneralConfig
	{
		PowerFailRecovery power_fail_recovery = PowerFailRecovery::kIdle;
		PowerFailStartDelay start_delay = PowerFailStartDelay::kDisabled;
	};

	struct FillingSystemConfig
	{
		FillingWorkMode work_mode = FillingWorkMode::kFill;
		FeedSpeed feed_speed = FeedSpeed::kDualSpeed;
	};

	struct FillingTargetConfig
	{
		double target_value = 1.0;
		double in_flight = 0.0;
		double feed = 0.0;
		double feed_inhibit_time = 0.0;
		double fast_feed_inhibit_time = 0.0;
	};

	struct FillingAutoTareConfig
	{
		bool auto_tare_enabled = false;
		double container_tare_upper = 0.0;
		double container_tare_lower = 0.0;
	};

	struct FillingToleranceConfig
	{
		double pre_check_delay = 0.0;
		double stability_timeout = 0.0;
		double positive_tolerance = 0.0;
		double negative_tolerance = 0.0;
	};

	struct FillingSpillOptConfig
	{
		SpillOptMode mode = SpillOptMode::kDisabled;
		double adjust_range = 0.0;
		int adjust_samples = 5;
		double adjust_factor = 0.5;
	};

	struct FillingCutoffOptConfig
	{
		CutoffOptMode mode = CutoffOptMode::kDisabled;
		double control_reliability_range = 0.0;
		int adjust_cycles = 5;
		double adjust_factor = 0.5;
	};

	struct FillingJogConfig
	{
		JogMode mode = JogMode::kDisabled;
		double jog_duration = 0.5;
		double jog_pause_time = 1.0;
		int max_cycles = 3;
	};

	struct FillingRefillConfig
	{
		double upper_limit = 10.0;
		double lower_limit = 1.0;
	};

	struct FillingEmptyingConfig
	{
		EmptyingCompleteMode complete_mode = EmptyingCompleteMode::kResidualWeight;
		double residual_weight = 0.1;
		double completion_time = 5.0;
	};

	struct FillingEventsConfig
	{
		double initial_feed_timeout = 30.0;
		double emptying_timeout = 60.0;
		double refill_timeout = 60.0;
		double process_timeout = 120.0;
	};

	struct FillingAdvancedConfig
	{
		CycleResultConfirm cycle_confirm = CycleResultConfirm::kDisabled;
		FastRecovery fast_recovery = FastRecovery::kAutomatic;
		bool interlock_enabled = false;
		double fast_feed_speed = 100.0;
		double fine_feed_speed = 30.0;
	};

	enum class FillingPhase : int
	{
		kIdle = 0,
		kRunning = 1,
		kAutoTare = 2,
		kCheckMaterial = 3,
		kRefilling = 4,
		kFeeding = 5,
		kFastFeed = 6,
		kFineFeed = 7,
		kInFlight = 8,
		kToleranceCheck = 9,
		kJog = 10,
		kFeedComplete = 11,
		kEmptying = 12,
		kEmptyingByWeight = 13,
		kEmptyingByTime = 14,
		kWaitConfirm = 15,
		kClearTare = 16,
		kError = 17,
	};

	enum class ToleranceResult : int
	{
		kNotChecked = 0,
		kInTolerance = 1,
		kAboveTolerance = 2,
		kBelowTolerance = 3,
	};

	// === Filling Application ===

	class FillingApplication : public AppBase
	{
	public:
		explicit FillingApplication(uint32_t subsystem_id);
		~FillingApplication() override;

		bool Initialize() override;
		void Start() override;
		void Stop() override;

		// 使用拆分后的类型
		void ProcessDioInputs(const DioInputSignals &inputs) override;
		void OnWeightUpdate(const WeightData &data) override;

		// Configuration setters/getters（全部不变）
		void SetGeneralConfig(const FillingGeneralConfig &cfg) { general_config_ = cfg; }
		void SetSystemConfig(const FillingSystemConfig &cfg) { system_config_ = cfg; }
		void SetTargetConfig(const FillingTargetConfig &cfg) { target_config_ = cfg; }
		void SetAutoTareConfig(const FillingAutoTareConfig &cfg) { auto_tare_config_ = cfg; }
		void SetToleranceConfig(const FillingToleranceConfig &cfg) { tolerance_config_ = cfg; }
		void SetSpillOptConfig(const FillingSpillOptConfig &cfg) { spill_opt_config_ = cfg; }
		void SetCutoffOptConfig(const FillingCutoffOptConfig &cfg) { cutoff_opt_config_ = cfg; }
		void SetJogConfig(const FillingJogConfig &cfg) { jog_config_ = cfg; }
		void SetRefillConfig(const FillingRefillConfig &cfg) { refill_config_ = cfg; }
		void SetEmptyingConfig(const FillingEmptyingConfig &cfg) { emptying_config_ = cfg; }
		void SetEventsConfig(const FillingEventsConfig &cfg) { events_config_ = cfg; }
		void SetAdvancedConfig(const FillingAdvancedConfig &cfg) { advanced_config_ = cfg; }

		FillingGeneralConfig GetGeneralConfig() const { return general_config_; }
		FillingSystemConfig GetSystemConfig() const { return system_config_; }
		FillingTargetConfig GetTargetConfig() const { return target_config_; }
		FillingAutoTareConfig GetAutoTareConfig() const { return auto_tare_config_; }
		FillingToleranceConfig GetToleranceConfig() const { return tolerance_config_; }
		FillingSpillOptConfig GetSpillOptConfig() const { return spill_opt_config_; }
		FillingCutoffOptConfig GetCutoffOptConfig() const { return cutoff_opt_config_; }
		FillingJogConfig GetJogConfig() const { return jog_config_; }
		FillingRefillConfig GetRefillConfig() const { return refill_config_; }
		FillingEmptyingConfig GetEmptyingConfig() const { return emptying_config_; }
		FillingEventsConfig GetEventsConfig() const { return events_config_; }
		FillingAdvancedConfig GetAdvancedConfig() const { return advanced_config_; }

		FillingPhase GetPhase() const { return phase_.load(std::memory_order_acquire); }
		ToleranceResult GetToleranceResult() const { return tolerance_result_; }

		void TriggerManualJog();
		void EndManualJog();
		void ConfirmCycleResult();

	private:
		void ControlLoop() override;

		void FillModeStateMachine(float dt);
		void FillEmptyModeStateMachine(float dt);
		void DispenseModeStateMachine(float dt);
		void RefillDispenseModeStateMachine(float dt);
		void AbsoluteModeStateMachine(float dt);

		bool PerformAutoTare();
		void StartFeeding();
		void StopFeeding();
		void StartFastFeed();
		void StartFineFeed();
		void HandleInFlight(float dt);
		void HandleToleranceCheck(float dt);
		void HandleJog(float dt);
		void HandleEmptying(float dt);
		void HandleFeedComplete();
		bool CheckMaterialSufficient();

		// 补料阀门控制（通过 OutputManager）
		void SetRefillValve(bool open);

		void UpdateSpillOptimization(double actual_final_weight);
		void UpdateCutoffOptimization(double overshoot);

		void SetPhase(FillingPhase phase);

		// Configuration
		FillingGeneralConfig general_config_;
		FillingSystemConfig system_config_;
		FillingTargetConfig target_config_;
		FillingAutoTareConfig auto_tare_config_;
		FillingToleranceConfig tolerance_config_;
		FillingSpillOptConfig spill_opt_config_;
		FillingCutoffOptConfig cutoff_opt_config_;
		FillingJogConfig jog_config_;
		FillingRefillConfig refill_config_;
		FillingEmptyingConfig emptying_config_;
		FillingEventsConfig events_config_;
		FillingAdvancedConfig advanced_config_;

		// State
		std::atomic<FillingPhase> phase_{FillingPhase::kIdle};
		ToleranceResult tolerance_result_ = ToleranceResult::kNotChecked;

		// Timing
		std::chrono::steady_clock::time_point phase_start_;
		std::chrono::steady_clock::time_point last_time_;
		std::chrono::steady_clock::time_point process_start_;

		// Feed state
		double feed_start_weight_ = 0.0;
		double current_dispensed_ = 0.0;
		double effective_in_flight_ = 0.0;

		// Jog state
		int jog_cycles_ = 0;
		bool jog_active_ = false;
		std::chrono::steady_clock::time_point jog_start_;

		// Emptying state
		std::chrono::steady_clock::time_point emptying_start_;

		// Spill optimization data
		double spill_history_[32] = {};
		int spill_history_count_ = 0;
		int spill_history_idx_ = 0;

		// Cutoff optimization data
		double cutoff_history_[32] = {};
		int cutoff_history_count_ = 0;
		int cutoff_history_idx_ = 0;

		int cycle_count_ = 0;
		bool interlock_active_ = true;
	};

} // namespace weighing

#endif // FILLING_APPLICATION_H