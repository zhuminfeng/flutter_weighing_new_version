#include "weight_record_store.h"
#include "database_manager.h"
#include <sstream>
#include <chrono>
#include <ctime>
#include <iomanip>

namespace weighing
{

	WeightRecordStore &WeightRecordStore::Instance()
	{
		static WeightRecordStore instance;
		return instance;
	}

	bool WeightRecordStore::SaveRecord(const WeightData &data, const std::string &record_type)
	{
		auto &db = DatabaseManager::Instance();

		auto now = std::chrono::system_clock::now();
		auto time_t_now = std::chrono::system_clock::to_time_t(now);
		std::ostringstream ts;
		ts << std::put_time(std::localtime(&time_t_now), "%Y-%m-%d %H:%M:%S");

		std::ostringstream sql;
		sql << "INSERT INTO weight_records (scale_id, timestamp, gross_weight, net_weight, "
			<< "tare_weight, unit, is_stable, record_type) VALUES ("
			<< data.scale_id << ",'" << ts.str() << "',"
			<< data.gross_weight << "," << data.net_weight << ","
			<< data.tare_weight << "," << static_cast<int>(data.unit) << ","
			<< (data.motion == MotionState::kStable ? 1 : 0) << ",'"
			<< record_type << "')";

		return db.Execute(sql.str());
	}

} // namespace weighing