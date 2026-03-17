#ifndef SCALE_PLATFORM_H
#define SCALE_PLATFORM_H

#include "../common_types.h"

extern "C"
{
#include "strong_tracking_kalman.h"
#include "stability_detector.h"
#include "zero_tracking.h"
#include "overload_detector.h"
#include "weight_calculator.h"
#include "calibration_engine.h"
#include "filter_engine.h"
}

#include <atomic>
#include <thread>
#include <functional>
#include <string>

namespace weighing
{

	class ScalePlatform
	{
	public:
		explicit ScalePlatform(uint32_t scale_id, float sample_rate = 1000.0f);
		~ScalePlatform();

		// Non-copyable
		ScalePlatform(const ScalePlatform &) = delete;
		ScalePlatform &operator=(const ScalePlatform &) = delete;

		// Initialize with config
		bool Initialize(const ScaleParams &params, const ZeroConfig &zero_cfg,
						const TareConfig &tare_cfg, const FilterStabilityConfig &filter_cfg);

		// Feed raw ADC sample (called from input thread)
		void FeedAdcSample(const AdcSample &sample);

		// Get latest weight data (lock-free read)
		WeightData GetWeightData() const;

		// Scale operations
		bool DoZero();
		bool DoPushbuttonZero();
		bool DoTare();
		void SetPresetTare(double value);
		void ClearTare();

		// Calibration
		void StartZeroCalibration();
		void StartSpanCalibration(int linear_mode, const double *test_loads, int num_loads);
		void CalibrationAddLoad();
		void AcceptDynamicCalibration(bool accept);
		void StartStepCalibration(double test_weight);
		void StepRemoveConfirm();
		void StepSubstituteConfirm(double substitute_weight);
		void StepAddLoad();
		bool SaveCalibration();
		void AbortCalibration();
		CalibrationState GetCalibrationState() const;

		// Configuration updates
		void UpdateScaleParams(const ScaleParams &params);
		void UpdateZeroConfig(const ZeroConfig &cfg);
		void UpdateTareConfig(const TareConfig &cfg);
		void UpdateFilterStability(const FilterStabilityConfig &cfg);

		// Getters
		ScaleParams GetScaleParams() const { return params_; }
		ZeroConfig GetZeroConfig() const { return zero_cfg_; }
		TareConfig GetTareConfig() const { return tare_cfg_; }
		FilterStabilityConfig GetFilterStabilityConfig() const { return filter_cfg_; }
		CalibrationData GetCalibrationData() const { return cal_data_; }
		uint32_t GetScaleId() const { return scale_id_; }
		ScaleState GetState() const { return state_.load(std::memory_order_acquire); }

		// Callbacks
		void SetWeightCallback(WeightCallback cb) { weight_callback_ = cb; }
		void SetStatusCallback(StatusCallback cb) { status_callback_ = cb; }
		void SetCalibrationCallback(CalibrationCallback cb) { cal_callback_ = cb; }

		// Load calibration from stored data
		void LoadCalibrationData(const CalibrationData &data);

		// 【新增】注入模拟重量数据的接口
		void SetMockMode(bool enable);
		void FeedMockWeight(double net_weight);

	private:
		void ProcessingSample(const AdcSample &sample);
		void UpdateState(ScaleState new_state, const std::string &msg = "");

		uint32_t scale_id_;
		float sample_rate_;

		// Configuration
		ScaleParams params_;
		ZeroConfig zero_cfg_;
		TareConfig tare_cfg_;
		FilterStabilityConfig filter_cfg_;
		CalibrationData cal_data_;

		// Core algorithm instances (per-scale, no sharing)
		st_kalman_filter_t stkf_;
		stability_detector_t stability_;
		zero_tracking_t zero_tracker_;
		overload_detector_t overload_;
		weight_calculator_t weight_calc_;
		calibration_engine_t cal_engine_;
		filter_engine_t filter_engine_;

		// Atomic state for lock-free access
		std::atomic<ScaleState> state_;

		// Latest weight data (atomic-friendly struct with padding)
		struct alignas(64) AtomicWeightData
		{
			std::atomic<double> gross_weight{0.0};
			std::atomic<double> net_weight{0.0};
			std::atomic<double> tare_weight{0.0};
			std::atomic<int> motion{0};
			std::atomic<bool> is_zero{false};
			std::atomic<bool> is_overload{false};
			std::atomic<bool> is_underload{false};
			std::atomic<bool> is_net_mode{false};
			std::atomic<int> unit{1}; // kg
			std::atomic<uint64_t> timestamp_ns{0};
		} atomic_weight_;

		// ADC input ring buffer (lock-free)
		LockFreeRingBuffer<AdcSample, 4096> adc_buffer_;

		// Processing thread
		std::thread process_thread_;
		std::atomic<bool> running_{false};
		void ProcessLoop();

		// Callbacks
		WeightCallback weight_callback_;
		StatusCallback status_callback_;
		CalibrationCallback cal_callback_;

		// 【新增】标识是否开启了模拟模式
		std::atomic<bool> mock_mode_{false};
	};

} // namespace weighing

#endif // SCALE_PLATFORM_H