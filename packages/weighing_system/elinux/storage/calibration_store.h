#ifndef CALIBRATION_STORE_H
#define CALIBRATION_STORE_H

#include "../common_types.h"

namespace weighing
{

	class CalibrationStore
	{
	public:
		static CalibrationStore &Instance();

		bool SaveCalibration(uint32_t scale_id, const CalibrationData &data);
		bool LoadCalibration(uint32_t scale_id, CalibrationData &data);

	private:
		CalibrationStore() = default;
	};

} // namespace weighing

#endif // CALIBRATION_STORE_H