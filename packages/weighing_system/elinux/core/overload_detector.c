#include "overload_detector.h"
#include <string.h>

void overload_init(overload_detector_t *det, float capacity,
				   float division_value, int overload_range,
				   float underload_range_d)
{
	if (det == NULL)
		return;
	memset(det, 0, sizeof(overload_detector_t));
	det->capacity = capacity;
	det->division_value = division_value;
	det->overload_range = overload_range;
	det->underload_range_d = underload_range_d;
	det->current_zero = 0.0f;
}

void overload_update(overload_detector_t *det, float gross_weight, float zero_ref)
{
	if (det == NULL)
		return;
	det->current_zero = zero_ref;

	float weight_from_zero = gross_weight - zero_ref;
	float overload_limit = det->capacity + det->overload_range * det->division_value;
	float underload_limit = -(det->underload_range_d * det->division_value);

	det->is_overload = (weight_from_zero > overload_limit);
	det->is_underload = (weight_from_zero < underload_limit);
}

void overload_set_params(overload_detector_t *det, float capacity,
						 float division_value, int overload_range,
						 float underload_range_d)
{
	if (det == NULL)
		return;
	det->capacity = capacity;
	det->division_value = division_value;
	det->overload_range = overload_range;
	det->underload_range_d = underload_range_d;
}