#include "strong_tracking_kalman.h"
#include <string.h>
#include <stdio.h>
#include <math.h>

void st_kalman_init(st_kalman_filter_t *filter, float initial_value,
					float process_noise, float measurement_noise,
					float rho, float beta)
{
	if (filter == NULL)
		return;

	memset(filter, 0, sizeof(st_kalman_filter_t));

	filter->x = initial_value;
	filter->P = 1.0f;
	filter->Q = process_noise;
	filter->R = measurement_noise;
	filter->K = 0.0f;

	filter->fading_factor = 1.0f;
	filter->innovation = 0.0f;
	filter->innovation_cov = measurement_noise;
	filter->rho = (rho > 0.0f && rho <= 1.0f) ? rho : 0.95f;
	filter->beta = (beta >= 1.0f) ? beta : 2.0f;

	filter->sample_count = 0;
	filter->innovation_mean = 0.0f;
	filter->innovation_variance = measurement_noise;

	filter->is_tracking = true;
	filter->tracking_threshold = 3.0f;
}

static float calculate_fading_factor(st_kalman_filter_t *filter)
{
	// float theoretical_cov = filter->P + filter->R;

	if (filter->sample_count < 20)
	{
		filter->innovation_cov = (filter->innovation_cov * filter->sample_count +
								  filter->innovation * filter->innovation) /
								 (filter->sample_count + 1);
	}
	else
	{
		filter->innovation_cov = filter->rho * filter->innovation_cov +
								 (1.0f - filter->rho) * (filter->innovation * filter->innovation);
	}

	float N = filter->innovation_cov - filter->beta * filter->R;
	if (N < 0.0f)
		N = 0.0f;

	float M = filter->P;
	if (M < 1e-6f)
		M = 1e-6f;

	float lambda = N / M;

	if (lambda < 1.0f)
	{
		lambda = 1.0f;
	}
	else if (lambda > 10.0f)
	{
		lambda = 10.0f;
	}

	float innovation_ratio = fabsf(filter->innovation) / sqrtf(filter->R + 1e-6f);
	if (innovation_ratio > 4.0f)
	{
		lambda *= 1.2f;
	}
	else if (innovation_ratio < 1.0f)
	{
		lambda *= 0.9f;
	}

	return lambda;
}

float st_kalman_process(st_kalman_filter_t *filter, float measurement)
{
	if (filter == NULL)
		return measurement;

	filter->sample_count++;

	float x_pred = filter->x;
	float P_pred = filter->P + filter->Q;

	filter->innovation = measurement - x_pred;

	if (filter->sample_count < 30)
	{
		float initial_gain = 0.6f / (1.0f + filter->sample_count * 0.03f);
		filter->x = x_pred + initial_gain * filter->innovation;
		filter->P = (1.0f - initial_gain) * P_pred;

		if (filter->sample_count == 1)
		{
			filter->innovation_mean = filter->innovation;
			filter->innovation_variance = filter->R;
		}
		else
		{
			float alpha = 0.15f;
			filter->innovation_mean = (1.0f - alpha) * filter->innovation_mean +
									  alpha * filter->innovation;
			filter->innovation_variance = (1.0f - alpha) * filter->innovation_variance +
										  alpha * (filter->innovation * filter->innovation);
		}
		return filter->x;
	}

	float alpha = 0.08f;
	filter->innovation_mean = (1.0f - alpha) * filter->innovation_mean +
							  alpha * filter->innovation;
	filter->innovation_variance = (1.0f - alpha) * filter->innovation_variance +
								  alpha * (filter->innovation * filter->innovation);

	filter->fading_factor = calculate_fading_factor(filter);

	P_pred *= filter->fading_factor;

	filter->K = P_pred / (P_pred + filter->R);

	if (filter->K < 0.02f)
		filter->K = 0.02f;
	if (filter->K > 0.8f)
		filter->K = 0.8f;

	filter->x = x_pred + filter->K * filter->innovation;
	filter->P = (1.0f - filter->K) * P_pred;

	float innovation_std = sqrtf(filter->innovation_variance + 1e-6f);
	float normalized_innovation = fabsf(filter->innovation - filter->innovation_mean) /
								  (innovation_std + 1e-6f);
	filter->is_tracking = (normalized_innovation < filter->tracking_threshold);

	return filter->x;
}

void st_kalman_reset(st_kalman_filter_t *filter, float initial_value)
{
	if (filter == NULL)
		return;

	filter->x = initial_value;
	filter->P = 1.0f;
	filter->K = 0.0f;
	filter->fading_factor = 1.0f;
	filter->innovation = 0.0f;
	filter->innovation_cov = filter->R;
	filter->sample_count = 0;
	filter->innovation_mean = 0.0f;
	filter->innovation_variance = filter->R;
	filter->is_tracking = true;
}

void st_kalman_set_parameters(st_kalman_filter_t *filter, float Q, float R)
{
	if (filter == NULL)
		return;
	filter->Q = (Q > 0.0f && Q <= 1.0f) ? Q : STF_DEFAULT_Q;
	filter->R = (R > 0.0f && R <= 10.0f) ? R : STF_DEFAULT_R;
}

void st_kalman_get_status(st_kalman_filter_t *filter, char *status_str)
{
	if (filter == NULL || status_str == NULL)
		return;

	snprintf(status_str, 256,
			 "STF: x=%.4f lambda=%.3f K=%.3f innov=%.4f P=%.6f tracking=%d samples=%lu",
			 filter->x, filter->fading_factor, filter->K,
			 filter->innovation, filter->P,
			 filter->is_tracking, (unsigned long)filter->sample_count);
}