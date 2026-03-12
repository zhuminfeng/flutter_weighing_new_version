#ifndef ZERO_TRACKING_H
#define ZERO_TRACKING_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

	typedef enum
	{
		ZT_MODE_OFF = 0,
		ZT_MODE_GROSS = 1,
		ZT_MODE_GROSS_AND_NET = 2,
	} zt_mode_t;

	typedef struct
	{
		zt_mode_t mode;
		float range_d;			   // AZT range in divisions
		float division_value;	   // weight per division
		float current_zero_offset; // accumulated zero offset
		float tracking_rate;	   // tracking speed (divisions per update)
		bool is_net_mode;		   // current tare mode
		bool is_stable;			   // from stability detector
	} zero_tracking_t;

	void zero_tracking_init(zero_tracking_t *zt, float division_value,
							zt_mode_t mode, float range_d);
	float zero_tracking_update(zero_tracking_t *zt, float weight, bool is_stable, bool is_net_mode);
	void zero_tracking_reset(zero_tracking_t *zt);
	float zero_tracking_get_offset(zero_tracking_t *zt);

#ifdef __cplusplus
}
#endif

#endif /* ZERO_TRACKING_H */