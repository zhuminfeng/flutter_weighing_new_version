#include "calibration_store.h"
#include "database_manager.h"
#include <sstream>

namespace weighing
{

	CalibrationStore &CalibrationStore::Instance()
	{
		static CalibrationStore instance;
		return instance;
	}

	bool CalibrationStore::SaveCalibration(uint32_t scale_id, const CalibrationData &data)
	{
		auto &db = DatabaseManager::Instance();

		// Save zero
		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO calibration_zero (scale_id, zero_raw, is_valid) VALUES ("
			<< scale_id << "," << data.zero_raw << "," << (data.is_valid ? 1 : 0) << ")";
		if (!db.Execute(sql.str()))
			return false;

		// Delete old span points
		db.Execute("DELETE FROM calibration_data WHERE scale_id = " + std::to_string(scale_id));

		// Save span points
		for (size_t i = 0; i < data.span_points.size(); i++)
		{
			std::ostringstream span_sql;
			span_sql << "INSERT INTO calibration_data (scale_id, point_index, raw_reading, known_weight) VALUES ("
					 << scale_id << "," << i << ","
					 << data.span_points[i].raw_reading << ","
					 << data.span_points[i].test_load << ")";
			if (!db.Execute(span_sql.str()))
				return false;
		}

		return true;
	}

	bool CalibrationStore::LoadCalibration(uint32_t scale_id, CalibrationData &data)
	{
		auto &db = DatabaseManager::Instance();

		// Load zero
		bool found = false;
		db.Query("SELECT * FROM calibration_zero WHERE scale_id = " + std::to_string(scale_id),
				 [&](const std::map<std::string, std::string> &row)
				 {
					 found = true;
					 auto it = row.find("zero_raw");
					 if (it != row.end())
						 data.zero_raw = std::stod(it->second);
					 it = row.find("is_valid");
					 if (it != row.end())
						 data.is_valid = std::stoi(it->second) != 0;
				 });

		if (!found)
			return false;

		// Load span points
		data.span_points.clear();
		db.Query("SELECT * FROM calibration_data WHERE scale_id = " +
					 std::to_string(scale_id) + " ORDER BY point_index",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 CalPoint pt;
					 auto it = row.find("raw_reading");
					 if (it != row.end())
						 pt.raw_reading = std::stod(it->second);
					 it = row.find("known_weight");
					 if (it != row.end())
						 pt.test_load = std::stod(it->second);
					 data.span_points.push_back(pt);
				 });

		return true;
	}

} // namespace weighing