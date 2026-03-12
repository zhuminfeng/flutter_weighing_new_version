#include "stability_detector.h"
#include <string.h>
#include <math.h>

void stability_init(stability_detector_t *det, float division_value,
					float motion_range_d, float motion_detect_time,
					float stability_timeout, float sample_rate)
{
	if (det == NULL)
		return;
	memset(det, 0, sizeof(stability_detector_t));

	det->division_value = division_value;
	det->motion_range_d = motion_range_d;
	det->motion_detect_time = motion_detect_time;
	det->stability_timeout = stability_timeout;
	det->sample_rate = sample_rate;

	// Window size = enough samples for motion detect window
	det->window_size = (uint32_t)(sample_rate * motion_detect_time);
	if (det->window_size < 4)
		det->window_size = 4;
	if (det->window_size > STABILITY_WINDOW_MAX)
		det->window_size = STABILITY_WINDOW_MAX;

	det->required_stable = det->window_size;
	det->max_timeout = (uint32_t)(sample_rate * stability_timeout);
	if (det->max_timeout == 0)
		det->max_timeout = 1;

	det->is_stable = false;
	det->timed_out = false;
}

float stability_get_range(stability_detector_t *det)
{
	if (det == NULL || det->count < 2)
		return 0.0f;

	uint32_t n = (det->count < det->window_size) ? det->count : det->window_size;
	float min_val = det->window[0];
	float max_val = det->window[0];

	for (uint32_t i = 1; i < n; i++)
	{
		if (det->window[i] < min_val)
			min_val = det->window[i];
		if (det->window[i] > max_val)
			max_val = det->window[i];
	}
	return max_val - min_val;
}

float stability_get_variance(stability_detector_t *det)
{
	if (det == NULL || det->count < 2)
		return 0.0f;

	uint32_t n = (det->count < det->window_size) ? det->count : det->window_size;
	float sum = 0.0f;
	for (uint32_t i = 0; i < n; i++)
		sum += det->window[i];
	float mean = sum / n;

	float var_sum = 0.0f;
	for (uint32_t i = 0; i < n; i++)
	{
		float diff = det->window[i] - mean;
		var_sum += diff * diff;
	}
	return var_sum / (n - 1);
}

bool stability_update(stability_detector_t *det, float filtered_weight)
{
	if (det == NULL)
		return false;

	// Push into sliding window
	det->window[det->write_idx] = filtered_weight;
	det->write_idx = (det->write_idx + 1) % det->window_size;
	if (det->count < det->window_size)
		det->count++;

	// Not enough data yet
	if (det->count < det->window_size)
	{
		det->is_stable = false;
		return false;
	}

	// Calculate range
	float range = stability_get_range(det);
	float threshold = det->motion_range_d * det->division_value;

	if (range <= threshold)
	{
		det->stable_count++;
		det->timeout_count = 0;
		if (det->stable_count >= det->required_stable)
		{
			det->is_stable = true;
			det->timed_out = false;
		}
	}
	else
	{
		det->stable_count = 0;
		det->is_stable = false;
		det->timeout_count++;
		if (det->timeout_count >= det->max_timeout)
		{
			det->timed_out = true;
		}
	}

	return det->is_stable;
}

void stability_reset(stability_detector_t *det)
{
	if (det == NULL)
		return;
	det->write_idx = 0;
	det->count = 0;
	det->stable_count = 0;
	det->timeout_count = 0;
	det->is_stable = false;
	det->timed_out = false;
}