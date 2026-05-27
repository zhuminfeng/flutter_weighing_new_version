#ifndef CENTRAL_CONTROLLER_H
#define CENTRAL_CONTROLLER_H

#include <vector>
#include <map>
#include <memory>
#include <atomic>
#include <mutex>
#include <thread>
#include <chrono>
#include "../subsystem/subsystem.h"
#include "recipe.h"

namespace weighing
{
	/// 补料请求
	struct RefillRequest
	{
		uint32_t subsystem_id;
		double predicted_time;	   // 预计补料时间点(秒)
		double remaining_material; // 剩余物料量(kg)
		int priority;			   // 优先级 (0=最高)
		std::chrono::steady_clock::time_point request_time;
	};

	/// 子系统运行状态
	struct SubsystemStatus
	{
		uint32_t subsystem_id = 0;
		double actual_flow = 0.0;		 // 实际流量 kg/h
		double target_flow = 0.0;		 // 目标流量 kg/h
		double control_rate = 0.0;		 // 控制率 %
		double remaining_weight = 0.0;	 // 剩余重量 kg
		double accumulated_weight = 0.0; // 累积重量 kg
		bool is_refilling = false;		 // 是否正在补料
		bool is_fault = false;			 // 是否故障
		int refill_count = 0;			 // 补料次数
		std::chrono::steady_clock::time_point last_refill_time;
		std::chrono::steady_clock::time_point last_update_time;
	};

	/// 中央控制器
	class CentralController
	{
	public:
		static CentralController &Instance();

		bool Initialize();
		void Start();
		void Stop();
		bool IsRunning() const { return running_.load(); }

		// ===== 配方管理 =====
		bool LoadRecipe(uint32_t recipe_id);
		bool SaveRecipe(const Recipe &recipe);
		bool DeleteRecipe(uint32_t recipe_id);
		std::vector<Recipe> GetAllRecipes();
		Recipe GetActiveRecipe() const;
		uint32_t GetActiveRecipeId() const { return active_recipe_.recipe_id; }

		// ===== 比例同步控制 =====
		void SetMasterFlow(double flow); // 设置主流量，自动分配各子系统
		double GetMasterFlow() const { return master_flow_.load(); }
		double GetTotalActualFlow() const;
		void UpdateProportionalControl(); // 更新比例控制

		// ===== 补料调度 =====
		void RequestRefill(uint32_t subsystem_id);
		void OnRefillStarted(uint32_t subsystem_id);
		void OnRefillCompleted(uint32_t subsystem_id);
		bool CanRefillNow(uint32_t subsystem_id) const;

		// ===== 故障处理 =====
		void OnSubsystemFault(uint32_t subsystem_id);
		void OnSubsystemRecovered(uint32_t subsystem_id);
		void EnableFaultTolerance(bool enable) { fault_tolerance_enabled_ = enable; }
		bool IsFaultToleranceEnabled() const { return fault_tolerance_enabled_.load(); }

		// ===== 状态查询 =====
		SubsystemStatus GetSubsystemStatus(uint32_t subsystem_id) const;
		std::map<uint32_t, SubsystemStatus> GetAllStatuses() const;
		size_t GetRegisteredSubsystemCount() const;

		// ===== 注册子系统 =====
		void RegisterSubsystem(uint32_t subsystem_id);
		void UnregisterSubsystem(uint32_t subsystem_id);

		// ===== 批次管理 =====
		uint32_t StartBatch(const std::string &operator_name);
		bool EndBatch();
		uint32_t GetCurrentBatchId() const { return current_batch_id_.load(); }

	private:
		CentralController() = default;
		~CentralController();

		CentralController(const CentralController &) = delete;
		CentralController &operator=(const CentralController &) = delete;

		void CyclicTask();
		void UpdateSubsystemStatuses();
		void CompensateFlow(uint32_t refilling_subsystem_id);
		void UpdateRefillScheduler();
		void ScheduleRefill(uint32_t subsystem_id);
		void CheckSubsystemHealth();

		Recipe active_recipe_;
		std::atomic<double> master_flow_{0.0};
		std::atomic<bool> running_{false};
		std::atomic<bool> fault_tolerance_enabled_{true};
		std::atomic<uint32_t> current_batch_id_{0};

		std::map<uint32_t, SubsystemStatus> subsystem_statuses_;
		std::vector<RefillRequest> refill_queue_;

		mutable std::mutex mutex_;
		std::thread cyclic_thread_;
	};

} // namespace weighing

#endif // CENTRAL_CONTROLLER_H