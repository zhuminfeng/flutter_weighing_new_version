#ifndef LIW_PID_CONTROLLER_H
#define LIW_PID_CONTROLLER_H

#include <cstdint>

namespace weighing
{

	struct PidConfig
	{
		float Kp = 1.0f;
		float Ki = 1.0f;
		float Kd = 0.0f;
		float max_flow = 100.0f;	 // kg/h
		float filter_window = 0.5f;	 // seconds
		float startup_time = 0.0f;	 // seconds
		bool auto_tuning = false;	 // from system identification
		float safety_limit = 100.0f; // max control rate %
	};

	class LiwPidController
	{
	public:
		LiwPidController();

		void Initialize(const PidConfig &config, float sample_rate);
		void Reset();

		// Set target flow rate
		void SetTarget(float target_flow_kgh);

		// Process one cycle: returns control rate (0-100%)
		float Process(float current_flow_kgh, float dt_seconds);

		// Set PID parameters
		void SetParameters(float Kp, float Ki, float Kd);
		void SetMaxFlow(float max_flow) { config_.max_flow = max_flow; }
		void SetSafetyLimit(float limit) { config_.safety_limit = limit; }

		PidConfig GetConfig() const { return config_; }
		float GetTarget() const { return target_flow_; }
		float GetOutput() const { return output_; }

	private:
		PidConfig config_;
		float sample_rate_;
		float target_flow_;
		float output_;

		// PID state
		float integral_;
		float prev_error_;
		bool first_cycle_;

		// Flow smoothing (moving average)
		static constexpr int FLOW_WINDOW_MAX = 200;
		float flow_window_[FLOW_WINDOW_MAX];
		int flow_window_size_;
		int flow_write_idx_;
		int flow_count_;

		float SmoothFlow(float raw_flow);
	};

} // namespace weighing

#endif // LIW_PID_CONTROLLER_H