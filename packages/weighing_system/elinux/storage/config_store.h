#ifndef CONFIG_STORE_H
#define CONFIG_STORE_H

#include "../common_types.h"
#include "../application/liw/liw_application.h"
#include "../application/filling/filling_application.h"
#include "../subsystem/subsystem.h"
#include "../output/digital_output_mapping.h"

namespace weighing
{

	class ConfigStore
	{
	public:
		static ConfigStore &Instance();

		// Scale config
		bool SaveScaleConfig(uint32_t scale_id, const ScaleParams &params,
							 const ZeroConfig &zero, const TareConfig &tare,
							 const FilterStabilityConfig &filter);
		bool LoadScaleConfig(uint32_t scale_id, ScaleParams &params,
							 ZeroConfig &zero, TareConfig &tare,
							 FilterStabilityConfig &filter);

		// 查询数据库中已有的秤台 ID 列表
		std::vector<uint32_t> LoadAllScaleIds();

		// 查询子系统的应用类型（默认 kLossInWeight）
		AppType LoadAppType(uint32_t subsystem_id);

		// LIW config
		bool SaveLiwConfig(uint32_t subsystem_id, const LiwApplication *app);
		bool LoadLiwConfig(uint32_t subsystem_id, LiwApplication *app);

		// Filling config
		bool SaveFillingConfig(uint32_t subsystem_id, const FillingApplication *app);
		bool LoadFillingConfig(uint32_t subsystem_id, FillingApplication *app);

		// Subsystem config
		bool SaveSubsystemConfig(const SubsystemConfig &config);
		bool LoadSubsystemConfig(uint32_t subsystem_id, SubsystemConfig &config);
		std::vector<SubsystemConfig> LoadAllSubsystemConfigs();

	private:
		ConfigStore() = default;
	};

} // namespace weighing

#endif // CONFIG_STORE_H