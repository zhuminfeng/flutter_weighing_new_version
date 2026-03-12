#ifndef STABILITY_DETECTOR_H
#define STABILITY_DETECTOR_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define STABILITY_WINDOW_MAX 256

	typedef struct
	{
		float window[STABILITY_WINDOW_MAX];
		uint32_t window_size;
		uint32_t write_idx;
		uint32_t count;

		float motion_range_d;	  // motion band in divisions
		float division_value;	  // weight per division
		float motion_detect_time; // seconds required stable
		float stability_timeout;  // seconds before timeout
		float sample_rate;		  // samples per second

		uint32_t stable_count;	  // consecutive stable samples
		uint32_t required_stable; // required consecutive stable
		uint32_t timeout_count;
		uint32_t max_timeout;

		bool is_stable;
		bool timed_out;
	} stability_detector_t;

	void stability_init(stability_detector_t *det, float division_value,
						float motion_range_d, float motion_detect_time,
						float stability_timeout, float sample_rate);

	bool stability_update(stability_detector_t *det, float filtered_weight);

	void stability_reset(stability_detector_t *det);

	float stability_get_variance(stability_detector_t *det);
	float stability_get_range(stability_detector_t *det);

#ifdef __cplusplus
}
#endif

#endif /* STABILITY_DETECTOR_H */