#include "calibration_engine.h"
#include <string.h>
#include <math.h>

void cal_engine_init(calibration_engine_t *eng)
{
	if (eng == NULL)
		return;
	memset(eng, 0, sizeof(calibration_engine_t));
	eng->state = CAL_STATE_IDLE;
}

void cal_engine_start_zero(calibration_engine_t *eng)
{
	if (eng == NULL)
		return;
	eng->state = CAL_STATE_ZERO_SETTLING;
	eng->settle_sum = 0.0;
	eng->settle_count = 0;
	eng->was_stable = false;
	eng->error_msg[0] = '\0';
}

void cal_engine_start_span(calibration_engine_t *eng, int linear_mode,
						   const double *test_loads, int num_loads)
{
	if (eng == NULL)
		return;

	eng->linear_mode = linear_mode;
	eng->current_span_idx = 0;

	switch (linear_mode)
	{
	case 0:
		eng->total_span_points = 1;
		break; // zero + 1 point
	case 1:
		eng->total_span_points = 2;
		break; // 3-point
	case 2:
		eng->total_span_points = 3;
		break; // 4-point
	case 3:
		eng->total_span_points = 4;
		break; // 5-point
	default:
		eng->total_span_points = 1;
		break;
	}

	int copy_count = (num_loads < eng->total_span_points) ? num_loads : eng->total_span_points;
	for (int i = 0; i < copy_count; i++)
	{
		eng->test_loads[i] = test_loads[i];
	}

	eng->state = CAL_STATE_SPAN_SETTLING;
	eng->settle_sum = 0.0;
	eng->settle_count = 0;
	eng->was_stable = false;
	eng->error_msg[0] = '\0';
}

void cal_engine_feed_sample(calibration_engine_t *eng, double raw_value, bool is_stable)
{
	if (eng == NULL)
		return;

	switch (eng->state)
	{
	case CAL_STATE_ZERO_SETTLING:
		eng->settle_sum += raw_value;
		eng->settle_count++;
		if (is_stable)
			eng->was_stable = true;

		if (eng->settle_count >= CAL_SETTLE_SAMPLES)
		{
			eng->zero_raw = eng->settle_sum / eng->settle_count;
			if (eng->was_stable)
			{
				eng->state = CAL_STATE_ZERO_COMPLETE;
			}
			else
			{
				eng->state = CAL_STATE_DYNAMIC_COMPLETE;
			}
		}
		break;

	case CAL_STATE_SPAN_SETTLING:
		eng->settle_sum += raw_value;
		eng->settle_count++;
		if (is_stable)
			eng->was_stable = true;

		if (eng->settle_count >= CAL_SETTLE_SAMPLES)
		{
			double avg_raw = eng->settle_sum / eng->settle_count;
			eng->span_raw[eng->current_span_idx] = avg_raw;
			eng->span_weight[eng->current_span_idx] = eng->test_loads[eng->current_span_idx];

			eng->current_span_idx++;

			if (eng->current_span_idx >= eng->total_span_points)
			{
				if (eng->was_stable)
				{
					eng->state = CAL_STATE_SPAN_COMPLETE;
				}
				else
				{
					eng->state = CAL_STATE_DYNAMIC_COMPLETE;
				}
			}
			else
			{
				// Wait for next load point
				eng->state = CAL_STATE_SPAN_WAITING;
				eng->settle_sum = 0.0;
				eng->settle_count = 0;
				eng->was_stable = false;
			}
		}
		break;

	case CAL_STATE_STEP_WAITING_LOAD:
		// Accumulate for step cal load measurement
		eng->settle_sum += raw_value;
		eng->settle_count++;
		if (eng->settle_count >= CAL_SETTLE_SAMPLES)
		{
			double avg_raw = eng->settle_sum / eng->settle_count;
			eng->span_raw[0] = avg_raw;
			eng->span_weight[0] = eng->step_target_weight;
			eng->state = CAL_STATE_STEP_COMPLETE;
		}
		break;

	default:
		break;
	}
}

void cal_engine_accept_dynamic(calibration_engine_t *eng, bool accept)
{
	if (eng == NULL)
		return;
	if (eng->state == CAL_STATE_DYNAMIC_COMPLETE)
	{
		if (accept)
		{
			// Check what was being calibrated
			if (eng->settle_count > 0 && eng->current_span_idx == 0)
			{
				eng->state = CAL_STATE_ZERO_COMPLETE;
			}
			else
			{
				eng->state = CAL_STATE_SPAN_COMPLETE;
			}
		}
		else
		{
			eng->state = CAL_STATE_FAILED;
			strncpy(eng->error_msg, "Dynamic calibration rejected", sizeof(eng->error_msg) - 1);
		}
	}
}

void cal_engine_start_step(calibration_engine_t *eng, double test_weight)
{
	if (eng == NULL)
		return;
	eng->step_test_weight = test_weight;
	eng->step_accumulated_substitute = 0.0;
	eng->step_number = 0;
	eng->step_target_weight = test_weight;
	eng->state = CAL_STATE_STEP_WAITING_LOAD;
	eng->settle_sum = 0.0;
	eng->settle_count = 0;
}

void cal_engine_step_remove_confirm(calibration_engine_t *eng)
{
	if (eng == NULL)
		return;
	eng->state = CAL_STATE_STEP_WAITING_SUBSTITUTE;
}

void cal_engine_step_substitute_confirm(calibration_engine_t *eng, double substitute_weight)
{
	if (eng == NULL)
		return;
	eng->step_accumulated_substitute += substitute_weight;
	eng->step_target_weight = eng->step_accumulated_substitute + eng->step_test_weight;
	eng->step_number++;
	eng->state = CAL_STATE_STEP_WAITING_LOAD;
	eng->settle_sum = 0.0;
	eng->settle_count = 0;
}

void cal_engine_step_add_load(calibration_engine_t *eng)
{
	if (eng == NULL)
		return;
	if (eng->state == CAL_STATE_SPAN_WAITING)
	{
		eng->state = CAL_STATE_SPAN_SETTLING;
		eng->settle_sum = 0.0;
		eng->settle_count = 0;
		eng->was_stable = false;
	}
}

void cal_engine_abort(calibration_engine_t *eng)
{
	if (eng == NULL)
		return;
	eng->state = CAL_STATE_IDLE;
	strncpy(eng->error_msg, "Calibration aborted", sizeof(eng->error_msg) - 1);
}

cal_state_t cal_engine_get_state(calibration_engine_t *eng)
{
	return eng ? eng->state : CAL_STATE_IDLE;
}

bool cal_engine_is_complete(calibration_engine_t *eng)
{
	if (eng == NULL)
		return false;
	return (eng->state == CAL_STATE_ZERO_COMPLETE ||
			eng->state == CAL_STATE_SPAN_COMPLETE ||
			eng->state == CAL_STATE_STEP_COMPLETE ||
			eng->state == CAL_STATE_DYNAMIC_COMPLETE);
}