#include "liw_pid_controller.h"
#include <cstring>
#include <cmath>
#include <algorithm>

namespace weighing
{

	LiwPidController::LiwPidController()
		: sample_rate_(1000.0f), target_flow_(0.0f), output_(0.0f),
		  integral_(0.0f), prev_error_(0.0f), first_cycle_(true),
		  flow_window_size_(50), flow_write_idx_(0), flow_count_(0)
	{
		memset(flow_window_, 0, sizeof(flow_window_));
	}

	void LiwPidController::Initialize(const PidConfig &config, float sample_rate)
	{
		config_ = config;
		sample_rate_ = sample_rate;

		// Calculate flow window size from filter_window seconds
		flow_window_size_ = static_cast<int>(config.filter_window * sample_rate);
		if (flow_window_size_ < 1)
			flow_window_size_ = 1;
		if (flow_window_size_ > FLOW_WINDOW_MAX)
			flow_window_size_ = FLOW_WINDOW_MAX;

		Reset();
	}

	void LiwPidController::Reset()
	{
		integral_ = 0.0f;
		prev_error_ = 0.0f;
		first_cycle_ = true;
		output_ = 0.0f;
		flow_write_idx_ = 0;
		flow_count_ = 0;
		memset(flow_window_, 0, sizeof(flow_window_));
	}

	void LiwPidController::SetTarget(float target_flow_kgh)
	{
		target_flow_ = target_flow_kgh;
	}

	void LiwPidController::SetParameters(float Kp, float Ki, float Kd)
	{
		config_.Kp = Kp;
		config_.Ki = Ki;
		config_.Kd = Kd;
	}

	float LiwPidController::SmoothFlow(float raw_flow)
	{
		flow_window_[flow_write_idx_] = raw_flow;
		flow_write_idx_ = (flow_write_idx_ + 1) % flow_window_size_;
		if (flow_count_ < flow_window_size_)
			flow_count_++;

		float sum = 0.0f;
		for (int i = 0; i < flow_count_; i++)
		{
			sum += flow_window_[i];
		}
		return sum / flow_count_;
	}

	float LiwPidController::Process(float current_flow_kgh, float dt_seconds)
	{
		if (dt_seconds <= 0.0f)
			return output_;

		// Smooth flow reading
		float smoothed_flow = SmoothFlow(current_flow_kgh);

		// Calculate error
		float error = target_flow_ - smoothed_flow;

		// Proportional
		float p_term = config_.Kp * error;

		// Integral with anti-windup
		integral_ += error * dt_seconds;
		float max_integral = config_.safety_limit / (config_.Ki + 1e-6f);
		integral_ = std::clamp(integral_, -max_integral, max_integral);
		float i_term = config_.Ki * integral_;

		// Derivative (on error, with filter)
		float d_term = 0.0f;
		if (!first_cycle_)
		{
			float derivative = (error - prev_error_) / dt_seconds;
			d_term = config_.Kd * derivative;
		}
		first_cycle_ = false;
		prev_error_ = error;

		// Calculate output
		// Normalize: at max_flow, control_rate = 100%
		float feed_forward = 0.0f;
		if (config_.max_flow > 0.0f)
		{
			feed_forward = (target_flow_ / config_.max_flow) * 100.0f;
		}

		output_ = feed_forward + p_term + i_term + d_term;

		// Clamp to safety limit
		output_ = std::clamp(output_, 0.0f, config_.safety_limit);

		return output_;
	}

} // namespace weighing