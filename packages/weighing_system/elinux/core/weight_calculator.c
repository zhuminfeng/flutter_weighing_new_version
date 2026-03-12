#include "weight_calculator.h"
#include <string.h>
#include <math.h>

void weight_calc_init(weight_calculator_t *calc, double capacity, double division)
{
	if (calc == NULL)
		return;
	memset(calc, 0, sizeof(weight_calculator_t));
	calc->capacity = capacity;
	calc->division = division;
	calc->unit_factor = 1.0;
	// Default linear: weight = (raw - zero_raw) * default_scale
	calc->num_cal_points = 0;
	calc->num_coeffs = 2;
	calc->coeffs[0] = 0.0; // offset
	calc->coeffs[1] = 1.0; // gain (raw units = weight units by default)
}

double weight_calc_raw_to_weight(weight_calculator_t *calc, double filtered_raw)
{
	if (calc == NULL)
		return 0.0;

	double adjusted = filtered_raw - calc->zero_raw;

	double weight;
	if (calc->num_cal_points >= 1)
	{
		// Use piecewise linear interpolation
		if (calc->num_cal_points == 1)
		{
			// Single point: linear from zero
			double raw_span = calc->cal_points_raw[0] - calc->zero_raw;
			if (fabs(raw_span) < 1e-10)
				return 0.0;
			weight = adjusted * (calc->cal_points_weight[0] / raw_span);
		}
		else
		{
			// Multi-point: piecewise linear
			// Find segment
			double prev_raw = 0.0;
			double prev_wt = 0.0;
			weight = 0.0;

			for (int i = 0; i < calc->num_cal_points; i++)
			{
				double cur_raw = calc->cal_points_raw[i] - calc->zero_raw;
				double cur_wt = calc->cal_points_weight[i];

				if (adjusted <= cur_raw || i == calc->num_cal_points - 1)
				{
					double raw_diff = cur_raw - prev_raw;
					if (fabs(raw_diff) < 1e-10)
					{
						weight = cur_wt;
					}
					else
					{
						double ratio = (adjusted - prev_raw) / raw_diff;
						weight = prev_wt + ratio * (cur_wt - prev_wt);
					}
					break;
				}
				prev_raw = cur_raw;
				prev_wt = cur_wt;
			}
		}
	}
	else
	{
		// No calibration: use default coefficients
		weight = calc->coeffs[0] + calc->coeffs[1] * adjusted;
	}

	calc->gross_weight = weight - calc->zero_reference;

	// Calculate net
	if (calc->is_tared || calc->has_preset_tare)
	{
		calc->net_weight = calc->gross_weight - calc->tare_weight;
	}
	else
	{
		calc->net_weight = calc->gross_weight;
	}

	return calc->gross_weight;
}

double weight_calc_round_to_division(weight_calculator_t *calc, double weight)
{
	if (calc == NULL || calc->division <= 0)
		return weight;
	return round(weight / calc->division) * calc->division;
}

void weight_calc_set_zero_cal(weight_calculator_t *calc, double zero_raw)
{
	if (calc == NULL)
		return;
	calc->zero_raw = zero_raw;
}

void weight_calc_add_span_point(weight_calculator_t *calc, double raw_value, double known_weight)
{
	if (calc == NULL)
		return;
	if (calc->num_cal_points >= MAX_CAL_POINTS)
		return;

	calc->cal_points_raw[calc->num_cal_points] = raw_value;
	calc->cal_points_weight[calc->num_cal_points] = known_weight;
	calc->num_cal_points++;
}

void weight_calc_compute_linearization(weight_calculator_t *calc)
{
	if (calc == NULL)
		return;
	// Linearization is done via piecewise in raw_to_weight
	// Sort points by raw value
	for (int i = 0; i < calc->num_cal_points - 1; i++)
	{
		for (int j = i + 1; j < calc->num_cal_points; j++)
		{
			if (calc->cal_points_raw[j] < calc->cal_points_raw[i])
			{
				double tmp_r = calc->cal_points_raw[i];
				double tmp_w = calc->cal_points_weight[i];
				calc->cal_points_raw[i] = calc->cal_points_raw[j];
				calc->cal_points_weight[i] = calc->cal_points_weight[j];
				calc->cal_points_raw[j] = tmp_r;
				calc->cal_points_weight[j] = tmp_w;
			}
		}
	}
}

void weight_calc_clear_calibration(weight_calculator_t *calc)
{
	if (calc == NULL)
		return;
	calc->num_cal_points = 0;
	calc->zero_raw = 0.0;
}

bool weight_calc_do_zero(weight_calculator_t *calc, double current_weight,
						 double pos_range_pct, double neg_range_pct)
{
	if (calc == NULL)
		return false;

	double pos_limit = calc->capacity * pos_range_pct / 100.0;
	double neg_limit = calc->capacity * neg_range_pct / 100.0;

	if (current_weight > pos_limit || current_weight < -neg_limit)
	{
		return false; // out of range
	}

	calc->zero_reference += current_weight;
	return true;
}

bool weight_calc_do_tare(weight_calculator_t *calc, double current_gross)
{
	if (calc == NULL)
		return false;

	calc->tare_weight = current_gross;
	calc->is_tared = true;
	calc->has_preset_tare = false;
	return true;
}

void weight_calc_set_preset_tare(weight_calculator_t *calc, double tare_value)
{
	if (calc == NULL)
		return;
	// Round to nearest division
	calc->tare_weight = round(tare_value / calc->division) * calc->division;
	calc->has_preset_tare = true;
	calc->is_tared = false;
}

void weight_calc_clear_tare(weight_calculator_t *calc)
{
	if (calc == NULL)
		return;
	calc->tare_weight = 0.0;
	calc->is_tared = false;
	calc->has_preset_tare = false;
}

double weight_calc_get_gross(weight_calculator_t *calc)
{
	return calc ? calc->gross_weight : 0.0;
}

double weight_calc_get_net(weight_calculator_t *calc)
{
	return calc ? calc->net_weight : 0.0;
}

double weight_calc_get_tare(weight_calculator_t *calc)
{
	return calc ? calc->tare_weight : 0.0;
}

bool weight_calc_is_net_mode(weight_calculator_t *calc)
{
	return calc ? (calc->is_tared || calc->has_preset_tare) : false;
}