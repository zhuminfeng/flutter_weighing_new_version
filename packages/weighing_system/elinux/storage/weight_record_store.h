#ifndef WEIGHT_RECORD_STORE_H
#define WEIGHT_RECORD_STORE_H

#include "../common_types.h"
#include <string>

namespace weighing
{

	class WeightRecordStore
	{
	public:
		static WeightRecordStore &Instance();

		bool SaveRecord(const WeightData &data, const std::string &record_type = "print");

	private:
		WeightRecordStore() = default;
	};

} // namespace weighing

#endif