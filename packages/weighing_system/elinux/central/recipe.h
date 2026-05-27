#ifndef RECIPE_H
#define RECIPE_H

#include <string>
#include <map>
#include <vector>
#include <cstdint>

namespace weighing
{
	/// 配方定义
	struct Recipe
	{
		uint32_t recipe_id = 0;
		std::string name;
		double total_target_flow = 0.0; // 总目标流量 kg/h

		// 各子系统的流量比例
		std::map<uint32_t, double> subsystem_ratios; // subsystem_id -> ratio

		// 补料参数
		double refill_interval_min = 10.0; // 最小补料间隔(秒)
		bool enable_stagger_refill = true; // 启用错峰补料

		std::string created_at;
		std::string updated_at;
	};

	/// 批次追溯记录
	struct BatchTrace
	{
		uint32_t batch_id = 0;
		uint32_t recipe_id = 0;
		std::string start_time;
		std::string end_time;
		double total_weight = 0.0;
		std::string status; // "running", "completed", "aborted"
		std::string operator_name;
		std::string notes;

		// 各子系统明细
		std::map<uint32_t, double> subsystem_accumulated; // subsystem_id -> weight
	};

} // namespace weighing

#endif // RECIPE_H