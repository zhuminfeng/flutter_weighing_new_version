#ifndef WEIGHING_SYSTEM_COMMON_TYPES_H_
#define WEIGHING_SYSTEM_COMMON_TYPES_H_

#include <cstdint>
#include <string>
#include <atomic>
#include <vector>
#include <functional>

#define SHM_PHY_BASE_ADDR 0x08000000
namespace weighing
{

	// ============== Enumerations ==============

	enum class WeightUnit : int
	{
		kGram = 0,
		kKilogram = 1, // default
		kPound = 2,
		kMetricTon = 3,
		kTon = 4,
	};

	enum class ScaleState : int
	{
		kIdle = 0,
		kRunning = 1,
		kError = 2,
		kCalibrating = 3,
		kOverload = 4,
		kUnderload = 5,
	};

	enum class MotionState : int
	{
		kStable = 0,
		kInMotion = 1,
	};

	enum class TareMode : int
	{
		kGross = 0,
		kNet = 1,
	};

	enum class AutoZeroMode : int
	{
		kOff = 0,
		kGross = 1, // default
		kGrossAndNet = 2,
	};

	enum class PowerUpZeroMode : int
	{
		kUseLastZero = 0,
		kUseCalibratedZero = 1, // default
		kAcquireNewZero = 2,
	};

	enum class LinearCalMode : int
	{
		kDisabled = 0, // default: zero + 1 load point
		k3Point = 1,   // zero + mid + high
		k4Point = 2,   // zero + low + mid + high
		k5Point = 3,   // zero + low + mid + mid-high + high
	};

	enum class LowPassFilterLevel : int
	{
		kVeryLight = 0, // default
		kLight = 1,
		kMedium = 2,
		kHeavy = 3,
	};

	enum class CalibrationState : int
	{
		kIdle = 0,
		kInProgress = 1,
		kCompleted = 2,
		kDynamicCompleted = 3,
		kFailed = 4,
		kAborted = 5,
	};

	enum class InputMode : int
	{
		kEtherCAT = 0,	   // Mode 1
		kSharedMemory = 1, // Mode 2
	};

	enum class AppType : int
	{
		kLossInWeight = 0,
		kFilling = 1,
	};

	// LIW modes
	enum class LiwMode : int
	{
		kContinuous = 0,
		kBatch = 1,
		kSystemId = 2,
	};

	enum class LiwSubMode : int
	{
		kFlowControl = 0,
		kFixedFrequency = 1,
	};

	enum class PidTuningMode : int
	{
		kAutomatic = 0,
		kManual = 1,
	};

	enum class RefillMode : int
	{
		kAutomatic = 0,
		kManual = 1,
	};

	enum class RefillControlMode : int
	{
		kFixedOutput = 0,
		kLastFrequency = 1, // default
		kSmartAdapt = 2,
	};

	// Filling modes
	enum class FillingWorkMode : int
	{
		kFill = 0, // default
		kFillAndEmpty = 1,
		kDispense = 2,
		kRefillAndDispense = 3,
		kAbsoluteValue = 4,
	};

	enum class FeedSpeed : int
	{
		kSingleSpeed = 0,
		kDualSpeed = 1, // default
	};

	enum class SpillOptMode : int
	{
		kDisabled = 0, // default
		kAutomatic = 1,
		kManual = 2,
	};

	enum class CutoffOptMode : int
	{
		kDisabled = 0, // default
		kAutomatic = 1,
		kManual = 2,
	};

	enum class JogMode : int
	{
		kDisabled = 0, // default
		kAutomatic = 1,
		kSinglePulse = 2,
		kManual = 3,
	};

	enum class EmptyingCompleteMode : int
	{
		kResidualWeight = 0, // default
		kCompletionTime = 1,
	};

	enum class CycleResultConfirm : int
	{
		kDisabled = 0, // default
		kEveryTime = 1,
		kOutOfTolerance = 2,
	};

	enum class FastRecovery : int
	{
		kAutomatic = 0, // default
		kStatic = 1,
		kDisabled = 2,
	};

	enum class PowerFailRecovery : int
	{
		kIdle = 0, // default
		kPause = 1,
	};

	enum class PowerFailStartDelay : int
	{
		kDisabled = 0, // default
		k5Min = 1,
		k15Min = 2,
		k30Min = 3,
	};

	// ============== Data Structures ==============

	struct AdcSample
	{
		int32_t raw_value;
		uint8_t status; // 0=OK, 1=timeout, 2=disconnected, 3=overrange
		uint64_t timestamp_ns;
		uint32_t channel_id;
	};

	struct WeightData
	{
		double gross_weight;
		double net_weight;
		double tare_weight;
		MotionState motion;
		bool is_zero;
		bool is_overload;
		bool is_underload;
		bool is_net_mode;
		WeightUnit unit;
		uint64_t timestamp_ns;
		uint32_t scale_id;
	};

	struct ScaleParams
	{
		WeightUnit primary_unit = WeightUnit::kKilogram;
		WeightUnit calibration_unit = WeightUnit::kKilogram;
		double capacity = 15.0;
		double division = 0.005;
		int overload_range = 9;
		// derived
		int max_divisions() const
		{
			if (division <= 0)
				return 0;
			return static_cast<int>(capacity / division);
		}
	};

	struct ZeroConfig
	{
		// Auto zero tracking
		AutoZeroMode auto_zero_mode = AutoZeroMode::kGross;
		double auto_zero_range_d = 0.5;	 // in divisions
		double underload_range_d = 20.0; // in divisions
		// Power-up zero
		PowerUpZeroMode power_up_zero = PowerUpZeroMode::kUseCalibratedZero;
		double power_up_zero_pos_pct = 2.0;
		double power_up_zero_neg_pct = 2.0;
		// Pushbutton zero
		bool pushbutton_zero_enabled = true;
		double pushbutton_zero_pos_pct = 2.0;
		double pushbutton_zero_neg_pct = 2.0;
	};

	struct TareConfig
	{
		bool pushbutton_tare_enabled = true;
		bool preset_tare_enabled = true;
	};

	struct CalibrationConfig
	{
		WeightUnit cal_unit = WeightUnit::kKilogram;
		LinearCalMode linear_mode = LinearCalMode::kDisabled;
	};

	struct FilterStabilityConfig
	{
		// Low-pass filter
		LowPassFilterLevel low_pass_level = LowPassFilterLevel::kVeryLight;
		// Notch filter
		bool notch_enabled = false;
		double notch_frequency = 50.0; // Hz
		// Adaptive filter
		bool adaptive_enabled = false;
		double adaptive_range_d = 1.0; // in divisions
		// Stability
		double motion_range_d = 1.0;	 // divisions
		double motion_detect_time = 0.3; // seconds
		double stability_timeout = 3.0;	 // seconds
	};

	// Calibration data per point
	struct CalPoint
	{
		double test_load;	// known weight
		double raw_reading; // ADC reading at that weight
	};

	struct CalibrationData
	{
		double zero_raw = 0.0;
		std::vector<CalPoint> span_points;
		bool is_valid = false;
	};

	// ============== Lock-free Ring Buffer ==============

	template <typename T, size_t SIZE>
	class LockFreeRingBuffer
	{
	public:
		LockFreeRingBuffer() : head_(0), tail_(0) {}

		bool push(const T &item)
		{
			size_t current_head = head_.load(std::memory_order_relaxed);
			size_t next_head = (current_head + 1) % SIZE;
			if (next_head == tail_.load(std::memory_order_acquire))
			{
				return false; // full
			}
			buffer_[current_head] = item;
			head_.store(next_head, std::memory_order_release);
			return true;
		}

		bool pop(T &item)
		{
			size_t current_tail = tail_.load(std::memory_order_relaxed);
			if (current_tail == head_.load(std::memory_order_acquire))
			{
				return false; // empty
			}
			item = buffer_[current_tail];
			tail_.store((current_tail + 1) % SIZE, std::memory_order_release);
			return true;
		}

		bool empty() const
		{
			return head_.load(std::memory_order_acquire) ==
				   tail_.load(std::memory_order_acquire);
		}

		size_t size() const
		{
			size_t h = head_.load(std::memory_order_acquire);
			size_t t = tail_.load(std::memory_order_acquire);
			return (h >= t) ? (h - t) : (SIZE - t + h);
		}

	private:
		T buffer_[SIZE];
		std::atomic<size_t> head_;
		std::atomic<size_t> tail_;
	};

	// ============== Shared Memory Format ==============

#pragma pack(push, 1)
	struct ShmemAdcData
	{
		uint32_t magic;	   // 0xDEADBEEF
		uint32_t sequence; // monotonic counter
		uint64_t timestamp_ns;
		struct
		{
			int32_t raw_adc;
			uint8_t status; // 0=OK, 1=timeout, 2=disconnected, 3=overrange
			uint8_t reserved[3];
		} channel[2];
		uint32_t crc32;
	};
#pragma pack(pop)

	constexpr uint32_t SHMEM_MAGIC = 0xDEADBEEF;

	// DIO 输入信号（从 EtherCAT IO 模块读取）
	struct DioInputSignals
	{
		bool start = false;
		bool stop = false;
		bool execute_refill = false;
		bool trigger_emptying = false;
		bool interlock = false;
		bool tare = false;
		bool zero = false;
		bool jog_trigger = false;
	};

	// DIO 输出信号（写入 EtherCAT IO 模块）
	// 注意：阀门类输出由 DigitalIOController::ApplyDioOutputs() 独立控制
	//       以下仅为状态指示类输出
	struct DioOutputSignals
	{
		bool running = false;
		bool warning = false;
		bool alarm = false;
	};
	// ============================================================================
	// 伺服状态信息 (从 InoSV630N TxPDO 读取)
	// ============================================================================
	struct ServoStatus
	{
		uint16_t status_word = 0;
		uint16_t error_code = 0;
		int32_t actual_position = 0;
		int16_t actual_torque = 0; // ‰ of rated torque
		int32_t following_error = 0;
		uint32_t digital_inputs = 0;
		bool enabled = false;
		bool faulted = false;
		bool target_reached = false;
	};

	// ============================================================================
	// 控制输出指令 (应用层 -> OutputManager)
	// ============================================================================
	struct ControlOutput
	{
		uint32_t subsystem_id = 0;

		// 伺服控制
		float control_rate_pct = 0.0f; // 电机速度 0-100%

		// 阀门控制
		uint16_t valve_channel = 0;
		bool feed_fast_valve = false;
		bool feed_slow_valve = false;
		bool refill_valve = false;
		bool emptying_valve = false;

		// 指示
		bool alarm = false;
		bool running = false;
		bool warning = false;
	};

	// ============== Callback Types ==============

	using WeightCallback = std::function<void(const WeightData &)>;
	using StatusCallback = std::function<void(uint32_t scale_id, ScaleState state, const std::string &msg)>;
	using CalibrationCallback = std::function<void(uint32_t scale_id, CalibrationState state, const std::string &msg)>;

} // namespace weighing

#endif // WEIGHING_SYSTEM_COMMON_TYPES_H_