#ifndef OVERLOAD_DETECTOR_H
#define OVERLOAD_DETECTOR_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

	typedef struct
	{
		float capacity;
		float division_value;
		int overload_range;		 // extra divisions above capacity
		float underload_range_d; // divisions below zero
		float current_zero;		 // current zero reference

		bool is_overload;
		bool is_underload;
	} overload_detector_t;

	void overload_init(overload_detector_t *det, float capacity,
					   float division_value, int overload_range,
					   float underload_range_d);

	void overload_update(overload_detector_t *det, float gross_weight, float zero_ref);

	void overload_set_params(overload_detector_t *det, float capacity,
							 float division_value, int overload_range,
							 float underload_range_d);

#ifdef __cplusplus
}
#endif

#endif /* OVERLOAD_DETECTOR_H */