#include "filter_engine.h"
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Alpha values for low-pass filter levels
static const float lp_alpha_table[] = {
	0.8f,  // VERY_LIGHT - minimal filtering
	0.5f,  // LIGHT
	0.2f,  // MEDIUM
	0.05f, // HEAVY - aggressive filtering
};

void filter_engine_init(filter_engine_t *fe, float sample_rate, float division_value)
{
	if (fe == NULL)
		return;
	memset(fe, 0, sizeof(filter_engine_t));

	fe->sample_rate = sample_rate;
	fe->division_value = division_value;
	fe->lp_level = FILTER_LP_VERY_LIGHT;
	fe->lp_alpha = lp_alpha_table[0];
	fe->lp_initialized = false;

	fe->notch_enabled = false;
	fe->adaptive_enabled = false;
	fe->adaptive_min_alpha = 0.01f;
	fe->adaptive_max_alpha = 0.8f;

	fe->fft_ready = false;
}

void filter_set_lowpass(filter_engine_t *fe, filter_lp_level_t level)
{
	if (fe == NULL)
		return;
	if (level > FILTER_LP_HEAVY)
		level = FILTER_LP_HEAVY;
	fe->lp_level = level;
	fe->lp_alpha = lp_alpha_table[level];
}

static void compute_notch_coefficients(filter_engine_t *fe)
{
	if (fe->notch_freq <= 0 || fe->sample_rate <= 0)
		return;

	float w0 = 2.0f * (float)M_PI * fe->notch_freq / fe->sample_rate;
	float bw = fe->notch_bw;
	if (bw <= 0)
		bw = 2.0f; // default bandwidth

	float alpha = sinf(w0) / (2.0f * (fe->notch_freq / bw));

	float cos_w0 = cosf(w0);

	// Notch filter coefficients (normalized)
	float a0 = 1.0f + alpha;
	fe->notch_b0 = 1.0f / a0;
	fe->notch_b1 = -2.0f * cos_w0 / a0;
	fe->notch_b2 = 1.0f / a0;
	fe->notch_a1 = -2.0f * cos_w0 / a0;
	fe->notch_a2 = (1.0f - alpha) / a0;
}

void filter_set_notch(filter_engine_t *fe, bool enabled, float freq_hz)
{
	if (fe == NULL)
		return;
	fe->notch_enabled = enabled;
	fe->notch_freq = freq_hz;
	fe->notch_bw = 2.0f; // default Q
	fe->notch_x1 = fe->notch_x2 = 0.0f;
	fe->notch_y1 = fe->notch_y2 = 0.0f;

	if (enabled)
	{
		compute_notch_coefficients(fe);
	}
}

void filter_set_adaptive(filter_engine_t *fe, bool enabled, float range_d)
{
	if (fe == NULL)
		return;
	fe->adaptive_enabled = enabled;
	fe->adaptive_range_d = range_d;
	fe->adaptive_initialized = false;
	fe->adaptive_variance = 0.0f;
	fe->adaptive_alpha = 0.5f;
}

static float apply_lowpass(filter_engine_t *fe, float sample)
{
	if (!fe->lp_initialized)
	{
		fe->lp_state = sample;
		fe->lp_initialized = true;
		return sample;
	}
	fe->lp_state = fe->lp_alpha * sample + (1.0f - fe->lp_alpha) * fe->lp_state;
	return fe->lp_state;
}

static float apply_notch(filter_engine_t *fe, float sample)
{
	if (!fe->notch_enabled)
		return sample;

	float output = fe->notch_b0 * sample +
				   fe->notch_b1 * fe->notch_x1 +
				   fe->notch_b2 * fe->notch_x2 -
				   fe->notch_a1 * fe->notch_y1 -
				   fe->notch_a2 * fe->notch_y2;

	fe->notch_x2 = fe->notch_x1;
	fe->notch_x1 = sample;
	fe->notch_y2 = fe->notch_y1;
	fe->notch_y1 = output;

	return output;
}

static float apply_adaptive(filter_engine_t *fe, float sample)
{
	if (!fe->adaptive_enabled)
		return sample;

	if (!fe->adaptive_initialized)
	{
		fe->adaptive_state = sample;
		fe->adaptive_initialized = true;
		return sample;
	}

	// Estimate instantaneous variance
	float diff = sample - fe->adaptive_state;
	float target_range = fe->adaptive_range_d * fe->division_value;

	// Adaptive alpha: large deviation -> less filtering, small -> more
	float abs_diff = fabsf(diff);
	if (target_range > 0)
	{
		float ratio = abs_diff / target_range;
		if (ratio > 1.0f)
		{
			// Large change: increase alpha (less filtering, faster tracking)
			fe->adaptive_alpha = fe->adaptive_max_alpha;
		}
		else
		{
			// Small change: decrease alpha (more filtering, smoother)
			fe->adaptive_alpha = fe->adaptive_min_alpha +
								 (fe->adaptive_max_alpha - fe->adaptive_min_alpha) * ratio * ratio;
		}
	}

	fe->adaptive_state = fe->adaptive_alpha * sample +
						 (1.0f - fe->adaptive_alpha) * fe->adaptive_state;

	// Update variance estimate
	float v_diff = sample - fe->adaptive_state;
	fe->adaptive_variance = 0.95f * fe->adaptive_variance + 0.05f * v_diff * v_diff;

	return fe->adaptive_state;
}

float filter_engine_process(filter_engine_t *fe, float raw_sample)
{
	if (fe == NULL)
		return raw_sample;

	// Store for FFT
	fe->fft_history[fe->fft_write_idx] = raw_sample;
	fe->fft_write_idx = (fe->fft_write_idx + 1) % FILTER_FFT_SIZE;
	if (fe->fft_count < FILTER_FFT_SIZE)
		fe->fft_count++;

	// Filter chain: Low-pass -> Notch -> Adaptive
	float result = apply_lowpass(fe, raw_sample);
	result = apply_notch(fe, result);
	result = apply_adaptive(fe, result);

	return result;
}

// Simple DFT (not full FFT, for diagnostic purposes)
void filter_engine_compute_fft(filter_engine_t *fe)
{
	if (fe == NULL || fe->fft_count < FILTER_FFT_SIZE)
	{
		fe->fft_ready = false;
		return;
	}

	uint32_t N = FILTER_FFT_SIZE;
	uint32_t half_N = N / 2;

	for (uint32_t k = 0; k < half_N; k++)
	{
		float real_sum = 0.0f;
		float imag_sum = 0.0f;

		for (uint32_t n = 0; n < N; n++)
		{
			uint32_t idx = (fe->fft_write_idx + n) % N;
			float angle = 2.0f * (float)M_PI * k * n / N;
			real_sum += fe->fft_history[idx] * cosf(angle);
			imag_sum -= fe->fft_history[idx] * sinf(angle);
		}

		fe->fft_magnitude[k] = sqrtf(real_sum * real_sum + imag_sum * imag_sum) / N;
	}

	fe->fft_ready = true;
}

const float *filter_engine_get_fft_magnitudes(filter_engine_t *fe, uint32_t *out_size)
{
	if (fe == NULL || !fe->fft_ready)
	{
		if (out_size)
			*out_size = 0;
		return NULL;
	}
	if (out_size)
		*out_size = FILTER_FFT_SIZE / 2;
	return fe->fft_magnitude;
}

void filter_engine_reset(filter_engine_t *fe)
{
	if (fe == NULL)
		return;
	fe->lp_initialized = false;
	fe->lp_state = 0.0f;
	fe->notch_x1 = fe->notch_x2 = 0.0f;
	fe->notch_y1 = fe->notch_y2 = 0.0f;
	fe->adaptive_initialized = false;
	fe->adaptive_state = 0.0f;
	fe->fft_count = 0;
	fe->fft_write_idx = 0;
	fe->fft_ready = false;
}