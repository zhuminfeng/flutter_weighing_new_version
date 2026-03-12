#ifndef CALIBRATION_ENGINE_H
#define CALIBRATION_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define CAL_MAX_POINTS 5
#define CAL_SETTLE_SAMPLES 50

	typedef enum
	{
		CAL_STATE_IDLE = 0,
		CAL_STATE_ZERO_WAITING,
		CAL_STATE_ZERO_SETTLING,
		CAL_STATE_ZERO_COMPLETE,
		CAL_STATE_SPAN_WAITING,
		CAL_STATE_SPAN_SETTLING,
		CAL_STATE_SPAN_COMPLETE,
		CAL_STATE_STEP_WAITING_LOAD,
		CAL_STATE_STEP_WAITING_REMOVE,
		CAL_STATE_STEP_WAITING_SUBSTITUTE,
		CAL_STATE_STEP_COMPLETE,
		CAL_STATE_FAILED,
		CAL_STATE_DYNAMIC_COMPLETE,
	} cal_state_t;

	typedef struct
	{
		cal_state_t state;
		int linear_mode;	   // 0=disabled, 1=3pt, 2=4pt, 3=5pt
		int total_span_points; // 1,2,3,4 based on linear_mode
		int current_span_idx;

		// Accumulator for settling
		double settle_sum;
		uint32_t settle_count;
		bool was_stable;

		// Test load weights (user-provided)
		double test_loads[CAL_MAX_POINTS];

		// Results
		double zero_raw;
		double span_raw[CAL_MAX_POINTS];
		double span_weight[CAL_MAX_POINTS];

		// Step substitution
		double step_test_weight;
		double step_accumulated_substitute;
		int step_number;
		double step_target_weight;

		// Error
		char error_msg[128];
	} calibration_engine_t;

	void cal_engine_init(calibration_engine_t *eng);

	// Start zero calibration
	void cal_engine_start_zero(calibration_engine_t *eng);

	// Start span calibration
	void cal_engine_start_span(calibration_engine_t *eng, int linear_mode,
							   const double *test_loads, int num_loads);

	// Feed a sample during calibration
	void cal_engine_feed_sample(calibration_engine_t *eng, double raw_value, bool is_stable);

	// Confirm dynamic reading
	void cal_engine_accept_dynamic(calibration_engine_t *eng, bool accept);

	// Step calibration
	void cal_engine_start_step(calibration_engine_t *eng, double test_weight);
	void cal_engine_step_remove_confirm(calibration_engine_t *eng);
	void cal_engine_step_substitute_confirm(calibration_engine_t *eng, double substitute_weight);
	void cal_engine_step_add_load(calibration_engine_t *eng);

	// Abort
	void cal_engine_abort(calibration_engine_t *eng);

	// Get state
	cal_state_t cal_engine_get_state(calibration_engine_t *eng);
	bool cal_engine_is_complete(calibration_engine_t *eng);

#ifdef __cplusplus
}
#endif

#endif /* CALIBRATION_ENGINE_H */