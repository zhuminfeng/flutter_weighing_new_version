#ifndef FILTER_ENGINE_H
#define FILTER_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define FILTER_FFT_SIZE 1024
#define FILTER_HISTORY_SIZE 256

	typedef enum
	{
		FILTER_LP_VERY_LIGHT = 0,
		FILTER_LP_LIGHT = 1,
		FILTER_LP_MEDIUM = 2,
		FILTER_LP_HEAVY = 3,
	} filter_lp_level_t;

	typedef struct
	{
		// Low-pass filter (IIR Butterworth approximation)
		filter_lp_level_t lp_level;
		float lp_alpha; // smoothing factor
		float lp_state;
		bool lp_initialized;

		// Notch filter (second-order IIR)
		bool notch_enabled;
		float notch_freq; // target frequency Hz
		float notch_bw;	  // bandwidth Hz
		float sample_rate;
		// Biquad coefficients
		float notch_b0, notch_b1, notch_b2;
		float notch_a1, notch_a2;
		// State
		float notch_x1, notch_x2;
		float notch_y1, notch_y2;

		// Adaptive filter
		bool adaptive_enabled;
		float adaptive_range_d; // target range in divisions
		float division_value;
		float adaptive_alpha; // current smoothing
		float adaptive_min_alpha;
		float adaptive_max_alpha;
		float adaptive_state;
		float adaptive_variance; // estimated noise variance
		bool adaptive_initialized;

		// FFT tool data
		float fft_history[FILTER_FFT_SIZE];
		uint32_t fft_write_idx;
		uint32_t fft_count;
		float fft_magnitude[FILTER_FFT_SIZE / 2];
		bool fft_ready;
	} filter_engine_t;

	void filter_engine_init(filter_engine_t *fe, float sample_rate, float division_value);

	// Configure
	void filter_set_lowpass(filter_engine_t *fe, filter_lp_level_t level);
	void filter_set_notch(filter_engine_t *fe, bool enabled, float freq_hz);
	void filter_set_adaptive(filter_engine_t *fe, bool enabled, float range_d);

	// Process one sample through the full filter chain
	float filter_engine_process(filter_engine_t *fe, float raw_sample);

	// FFT
	void filter_engine_compute_fft(filter_engine_t *fe);
	const float *filter_engine_get_fft_magnitudes(filter_engine_t *fe, uint32_t *out_size);

	// Reset
	void filter_engine_reset(filter_engine_t *fe);

#ifdef __cplusplus
}
#endif

#endif /* FILTER_ENGINE_H */