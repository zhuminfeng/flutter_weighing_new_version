#ifndef STRONG_TRACKING_KALMAN_H
#define STRONG_TRACKING_KALMAN_H

#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#ifdef __cplusplus
extern "C"
{
#endif

	typedef struct
	{
		// Basic Kalman parameters
		float x; // state estimate
		float P; // error covariance
		float Q; // process noise
		float R; // measurement noise
		float K; // Kalman gain

		// Strong tracking parameters
		float fading_factor;
		float innovation;
		float innovation_cov;
		float rho;	// forgetting factor (0.95-0.99)
		float beta; // weakening factor (1.0-5.0)

		// Statistics
		uint32_t sample_count;
		float innovation_mean;
		float innovation_variance;

		// Performance monitoring
		bool is_tracking;
		float tracking_threshold;
	} st_kalman_filter_t;

#define STF_DEFAULT_RHO 0.95f
#define STF_DEFAULT_BETA 2.0f
#define STF_DEFAULT_Q 0.001f
#define STF_DEFAULT_R 0.1f

	void st_kalman_init(st_kalman_filter_t *filter, float initial_value,
						float process_noise, float measurement_noise,
						float rho, float beta);

	float st_kalman_process(st_kalman_filter_t *filter, float measurement);

	void st_kalman_reset(st_kalman_filter_t *filter, float initial_value);

	void st_kalman_set_parameters(st_kalman_filter_t *filter, float Q, float R);

	void st_kalman_get_status(st_kalman_filter_t *filter, char *status_str);

#ifdef __cplusplus
}
#endif

#endif /* STRONG_TRACKING_KALMAN_H */