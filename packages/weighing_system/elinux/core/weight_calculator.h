#ifndef WEIGHT_CALCULATOR_H
#define WEIGHT_CALCULATOR_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C"
{
#endif

#define MAX_CAL_POINTS 5

	typedef struct
	{
		// Calibration data
		double zero_raw;
		double cal_points_raw[MAX_CAL_POINTS];
		double cal_points_weight[MAX_CAL_POINTS];
		int num_cal_points;

		// Linearization coefficients (polynomial)
		double coeffs[MAX_CAL_POINTS + 1];
		int num_coeffs;

		// Scale parameters
		double capacity;
		double division;
		double tare_weight;
		bool is_tared;
		double preset_tare;
		bool has_preset_tare;

		// Current values
		double gross_weight;
		double net_weight;
		double zero_reference; // current zero offset in weight

		// Unit conversion factor
		double unit_factor; // multiplier from kg base
	} weight_calculator_t;

	void weight_calc_init(weight_calculator_t *calc, double capacity, double division);

	// Convert raw ADC to weight
	double weight_calc_raw_to_weight(weight_calculator_t *calc, double filtered_raw);

	// Apply division rounding
	double weight_calc_round_to_division(weight_calculator_t *calc, double weight);

	// Calibration
	void weight_calc_set_zero_cal(weight_calculator_t *calc, double zero_raw);
	void weight_calc_add_span_point(weight_calculator_t *calc, double raw_value, double known_weight);
	void weight_calc_compute_linearization(weight_calculator_t *calc);
	void weight_calc_clear_calibration(weight_calculator_t *calc);

	// Zero/Tare operations
	bool weight_calc_do_zero(weight_calculator_t *calc, double current_weight,
							 double pos_range_pct, double neg_range_pct);
	bool weight_calc_do_tare(weight_calculator_t *calc, double current_gross);
	void weight_calc_set_preset_tare(weight_calculator_t *calc, double tare_value);
	void weight_calc_clear_tare(weight_calculator_t *calc);

	// Getters
	double weight_calc_get_gross(weight_calculator_t *calc);
	double weight_calc_get_net(weight_calculator_t *calc);
	double weight_calc_get_tare(weight_calculator_t *calc);
	bool weight_calc_is_net_mode(weight_calculator_t *calc);

#ifdef __cplusplus
}
#endif

#endif /* WEIGHT_CALCULATOR_H */