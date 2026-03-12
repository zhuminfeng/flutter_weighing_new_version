#include "zero_tracking.h"
#include <math.h>
#include <string.h>

void zero_tracking_init(zero_tracking_t *zt, float division_value,
						zt_mode_t mode, float range_d)
{
	if (zt == NULL)
		return;
	memset(zt, 0, sizeof(zero_tracking_t));
	zt->mode = mode;
	zt->range_d = range_d;
	zt->division_value = division_value;
	zt->current_zero_offset = 0.0f;
	zt->tracking_rate = 0.1f; // 0.1 division per update cycle
}

float zero_tracking_update(zero_tracking_t *zt, float weight, bool is_stable, bool is_net_mode)
{
	if (zt == NULL)
		return weight;

	zt->is_stable = is_stable;
	zt->is_net_mode = is_net_mode;

	// Check if tracking is applicable
	if (zt->mode == ZT_MODE_OFF)
		return weight;
	if (zt->mode == ZT_MODE_GROSS && is_net_mode)
		return weight;
	if (!is_stable)
		return weight;

	// Check if weight is within zero tracking range
	float range_weight = zt->range_d * zt->division_value;
	float adjusted_weight = weight - zt->current_zero_offset;

	if (fabsf(adjusted_weight) <= range_weight)
	{
		// Slowly track toward zero
		float step = zt->tracking_rate * zt->division_value;
		if (adjusted_weight > step)
		{
			zt->current_zero_offset += step;
		}
		else if (adjusted_weight < -step)
		{
			zt->current_zero_offset -= step;
		}
		else
		{
			zt->current_zero_offset += adjusted_weight;
		}
	}

	return weight - zt->current_zero_offset;
}

void zero_tracking_reset(zero_tracking_t *zt)
{
	if (zt == NULL)
		return;
	zt->current_zero_offset = 0.0f;
}

float zero_tracking_get_offset(zero_tracking_t *zt)
{
	if (zt == NULL)
		return 0.0f;
	return zt->current_zero_offset;
}