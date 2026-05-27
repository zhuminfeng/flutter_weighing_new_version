#ifndef CONFIG_STORE_H
#define CONFIG_STORE_H

#include "../common_types.h"
#include "../application/liw/liw_application.h"
#include "../application/filling/filling_application.h"
#include "../subsystem/subsystem.h"
#include "../output/digital_output_mapping.h"
#include "../central/recipe.h"

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

		// ===== 配方管理 =====
		bool SaveRecipe(const Recipe &recipe);
		Recipe LoadRecipe(uint32_t recipe_id);
		std::vector<Recipe> LoadAllRecipes();
		bool DeleteRecipe(uint32_t recipe_id);

		// ===== 批次追溯 =====
		uint32_t StartBatch(uint32_t recipe_id, const std::string &operator_name);
		bool EndBatch(uint32_t batch_id, double total_weight);
		bool UpdateBatchDetail(uint32_t batch_id, uint32_t subsystem_id,
							   double target_flow, double actual_flow_avg,
							   double accumulated_weight, int refill_count);
		std::vector<BatchTrace> QueryBatches(const std::string &start_date,
											 const std::string &end_date);

	private:
		ConfigStore() = default;
	};

} // namespace weighing

#endif // CONFIG_STORE_H