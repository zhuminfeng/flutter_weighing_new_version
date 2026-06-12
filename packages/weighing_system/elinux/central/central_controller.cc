#include "central_controller.h"
#include "../subsystem/subsystem_manager.h"
#include "../scale/scale_manager.h"
#include "../storage/config_store.h"
#include <algorithm>
#include <cmath>
#include <cstdio>

namespace weighing
{
	CentralController &CentralController::Instance()
	{
		static CentralController instance;
		return instance;
	}

	CentralController::~CentralController()
	{
		Stop();
	}

	bool CentralController::Initialize()
	{
		printf("CentralController: Initializing...\n");

		// 加载默认配方（ID=1）
		auto recipes = ConfigStore::Instance().LoadAllRecipes();
		if (!recipes.empty())
		{
			active_recipe_ = recipes[0];
			printf("CentralController: Loaded default recipe %u '%s'\n",
				   active_recipe_.recipe_id, active_recipe_.name.c_str());
		}
		else
		{
			fprintf(stderr, "CentralController: No recipes found in database\n");
		}

		return true;
	}

	void CentralController::Start()
	{
		if (running_.load())
			return;

		running_ = true;

		// 启动周期任务线程
		cyclic_thread_ = std::thread([this]()
									 {
            while (running_.load())
            {
                CyclicTask();
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            } });

		printf("CentralController: Started with recipe %u\n", active_recipe_.recipe_id);
	}

	void CentralController::Stop()
	{
		if (!running_.load())
			return;

		running_ = false;

		if (cyclic_thread_.joinable())
		{
			cyclic_thread_.join();
		}

		// 结束当前批次
		if (current_batch_id_.load() > 0)
		{
			EndBatch();
		}

		printf("CentralController: Stopped\n");
	}

	// ============================================================================
	// 周期任务：比例同步 + 补料调度 + 流量补偿 + 故障检测
	// ============================================================================
	void CentralController::CyclicTask()
	{
		std::lock_guard<std::mutex> lock(mutex_);

		// 1. 更新所有子系统状态
		UpdateSubsystemStatuses();

		// 2. 比例同步控制
		if (master_flow_.load() > 0.0)
		{
			UpdateProportionalControl();
		}

		// 3. 补料调度
		UpdateRefillScheduler();

		// 4. 健康检查
		CheckSubsystemHealth();
	}

	// ============================================================================
	// 更新子系统状态
	// ============================================================================
	void CentralController::UpdateSubsystemStatuses()
	{
		auto now = std::chrono::steady_clock::now();

		for (auto &[sub_id, status] : subsystem_statuses_)
		{
			auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
			if (!sub)
				continue;

			auto *app = sub->GetLiwApp();
			if (!app)
				continue;

			// 更新流量数据
			auto app_status = app->GetStatus();
			status.actual_flow = app_status.current_flow;
			status.control_rate = app_status.control_rate;
			status.accumulated_weight = app_status.total_accumulated;

			// 更新剩余物料量（从秤台读取净重）
			auto scales = sub->GetAllScales();
			if (!scales.empty())
			{
				status.remaining_weight = scales[0]->GetWeightData().net_weight;
			}

			// 检测是否正在补料（根据运行状态判断）
			bool was_refilling = status.is_refilling;
			status.is_refilling = (app_status.state == AppRunState::kRefilling);

			// 如果从补料状态恢复，记录时间和次数
			if (was_refilling && !status.is_refilling)
			{
				status.last_refill_time = now;
				status.refill_count++;
				printf("CentralController: Subsystem %u refill completed (count: %d)\n",
					   sub_id, status.refill_count);
			}

			status.last_update_time = now;
		}
	}

	// ============================================================================
	// 比例同步控制
	// ============================================================================
	void CentralController::SetMasterFlow(double flow)
	{
		master_flow_ = flow;
		printf("CentralController: Master flow set to %.2f kg/h\n", flow);

		UpdateProportionalControl();
	}

	void CentralController::UpdateProportionalControl()
	{
		double master = master_flow_.load();
		if (master <= 0.0)
			return;

		// 计算总比例
		double total_ratio = 0.0;
		for (const auto &[sub_id, ratio] : active_recipe_.subsystem_ratios)
		{
			// 排除故障和补料中的子系统
			auto it = subsystem_statuses_.find(sub_id);
			if (it != subsystem_statuses_.end() &&
				!it->second.is_fault && !it->second.is_refilling)
			{
				total_ratio += ratio;
			}
		}

		if (total_ratio <= 0.0)
		{
			fprintf(stderr, "CentralController: No active subsystems available\n");
			return;
		}

		// 分配各子系统流量
		for (const auto &[sub_id, ratio] : active_recipe_.subsystem_ratios)
		{
			auto it = subsystem_statuses_.find(sub_id);
			if (it == subsystem_statuses_.end())
				continue;

			auto &status = it->second;

			// 如果该子系统正在补料或故障，跳过
			if (status.is_refilling || status.is_fault)
			{
				// 流量补偿：将该子系统的目标流量分配给其他子系统
				if (status.is_refilling)
				{
					CompensateFlow(sub_id);
				}
				continue;
			}

			// 计算目标流量
			double target_flow = master * (ratio / total_ratio);

			// 设置子系统目标流量
			auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
			if (sub && sub->GetLiwApp())
			{
				auto *app = sub->GetLiwApp();
				auto sys_cfg = app->GetSystemConfig();
				sys_cfg.target_flow = static_cast<float>(target_flow);
				app->SetSystemConfig(sys_cfg);

				status.target_flow = target_flow;
			}
		}
	}

	// ============================================================================
	// 流量补偿：当某台秤补料时，其他秤微调流量补偿
	// ============================================================================
	void CentralController::CompensateFlow(uint32_t refilling_subsystem_id)
	{
		auto it = subsystem_statuses_.find(refilling_subsystem_id);
		if (it == subsystem_statuses_.end())
			return;

		double missing_flow = it->second.target_flow; // 缺失的流量

		if (missing_flow <= 0.0)
			return;

		// 找出正常运行的子系统，按比例分配补偿流量
		std::vector<uint32_t> active_subs;
		double total_active_ratio = 0.0;

		for (const auto &[sub_id, status] : subsystem_statuses_)
		{
			if (sub_id != refilling_subsystem_id &&
				!status.is_refilling &&
				!status.is_fault)
			{
				auto recipe_it = active_recipe_.subsystem_ratios.find(sub_id);
				if (recipe_it != active_recipe_.subsystem_ratios.end())
				{
					active_subs.push_back(sub_id);
					total_active_ratio += recipe_it->second;
				}
			}
		}

		if (active_subs.empty() || total_active_ratio <= 0.0)
			return;

		// 分配补偿流量
		for (uint32_t sub_id : active_subs)
		{
			double ratio = active_recipe_.subsystem_ratios[sub_id];
			double compensation = missing_flow * (ratio / total_active_ratio);

			auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
			if (sub && sub->GetLiwApp())
			{
				auto *app = sub->GetLiwApp();
				double new_target = subsystem_statuses_[sub_id].target_flow + compensation;

				auto sys_cfg = app->GetSystemConfig();
				sys_cfg.target_flow = static_cast<float>(new_target);
				app->SetSystemConfig(sys_cfg);

				printf("CentralController: Subsystem %u compensating +%.2f kg/h (total: %.2f)\n",
					   sub_id, compensation, new_target);
			}
		}
	}

	// ============================================================================
	// 补料调度：错峰补料
	// ============================================================================
	void CentralController::RequestRefill(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		// 检查是否已在队列中
		auto it = std::find_if(refill_queue_.begin(), refill_queue_.end(),
							   [subsystem_id](const RefillRequest &req)
							   {
								   return req.subsystem_id == subsystem_id;
							   });

		if (it != refill_queue_.end())
		{
			// 已在队列中，更新预测时间
			auto status_it = subsystem_statuses_.find(subsystem_id);
			if (status_it != subsystem_statuses_.end())
			{
				auto &status = status_it->second;
				double time_to_empty = 0.0;

				if (status.actual_flow > 0.0)
				{
					time_to_empty = (status.remaining_weight - 1.0) /
									(status.actual_flow / 3600.0); // 秒
				}

				it->predicted_time = time_to_empty;
				it->remaining_material = status.remaining_weight;
			}
			return;
		}

		// 预测补料时间
		auto &status = subsystem_statuses_[subsystem_id];
		double time_to_empty = 0.0;

		if (status.actual_flow > 0.0)
		{
			time_to_empty = (status.remaining_weight - 1.0) /
							(status.actual_flow / 3600.0); // 秒
		}

		RefillRequest req;
		req.subsystem_id = subsystem_id;
		req.predicted_time = time_to_empty;
		req.remaining_material = status.remaining_weight;
		// 从子系统配置中获取优先级
		auto *sub = SubsystemManager::Instance().GetSubsystem(subsystem_id);
		if (sub)
		{
			req.priority = sub->GetPriority();
		}
		req.request_time = std::chrono::steady_clock::now();

		refill_queue_.push_back(req);

		printf("CentralController: Refill requested for subsystem %u (ETA: %.1fs, remaining: %.2f kg)\n",
			   subsystem_id, time_to_empty, status.remaining_weight);
	}

	void CentralController::UpdateRefillScheduler()
	{
		if (refill_queue_.empty())
			return;

		// 按预测时间和优先级排序
		std::sort(refill_queue_.begin(), refill_queue_.end(),
				  [](const RefillRequest &a, const RefillRequest &b)
				  {
					  if (a.priority != b.priority)
						  return a.priority < b.priority;		  // 优先级高的在前
					  return a.predicted_time < b.predicted_time; // 时间紧急的在前
				  });

		// 检查是否可以启动下一个补料
		for (auto it = refill_queue_.begin(); it != refill_queue_.end();)
		{
			uint32_t sub_id = it->subsystem_id;

			if (CanRefillNow(sub_id))
			{
				ScheduleRefill(sub_id);
				it = refill_queue_.erase(it);
			}
			else
			{
				++it;
			}
		}
	}

	bool CentralController::CanRefillNow(uint32_t subsystem_id) const
	{
		if (!active_recipe_.enable_stagger_refill)
			return true; // 不启用错峰，随时可以补料

		auto now = std::chrono::steady_clock::now();

		// 检查是否有其他子系统正在补料
		for (const auto &[sub_id, status] : subsystem_statuses_)
		{
			if (sub_id == subsystem_id)
				continue;

			if (status.is_refilling)
			{
				// 检查时间间隔
				auto elapsed = std::chrono::duration<double>(
								   now - status.last_refill_time)
								   .count();

				if (elapsed < active_recipe_.refill_interval_min)
				{
					return false; // 间隔不足，不能补料
				}
			}
		}

		return true;
	}

	void CentralController::ScheduleRefill(uint32_t subsystem_id)
	{
		// 触发子系统补料（实际由 LiwApplication 的自动补料逻辑控制）
		// 这里只是更新状态和记录
		printf("CentralController: Scheduling refill for subsystem %u\n", subsystem_id);

		// 注意：实际的补料触发由 LiwApplication 的自动补料逻辑完成
		// CentralController 主要负责错峰调度
	}

	void CentralController::OnRefillStarted(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		auto it = subsystem_statuses_.find(subsystem_id);
		if (it != subsystem_statuses_.end())
		{
			it->second.is_refilling = true;
			printf("CentralController: Subsystem %u refill started\n", subsystem_id);

			// 触发流量补偿
			CompensateFlow(subsystem_id);
		}
	}

	void CentralController::OnRefillCompleted(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		auto it = subsystem_statuses_.find(subsystem_id);
		if (it != subsystem_statuses_.end())
		{
			it->second.is_refilling = false;
			it->second.last_refill_time = std::chrono::steady_clock::now();
			it->second.refill_count++;
			printf("CentralController: Subsystem %u refill completed\n", subsystem_id);

			// 恢复正常流量分配
			UpdateProportionalControl();
		}
	}

	// ============================================================================
	// 故障处理
	// ============================================================================
	void CentralController::OnSubsystemFault(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		auto it = subsystem_statuses_.find(subsystem_id);
		if (it != subsystem_statuses_.end())
		{
			it->second.is_fault = true;
			printf("CentralController: Subsystem %u fault detected\n", subsystem_id);

			if (fault_tolerance_enabled_.load())
			{
				// 降级运行：从比例分配中移除故障子系统
				printf("CentralController: Fault tolerance enabled, adjusting flow distribution\n");
				UpdateProportionalControl();
			}
			else
			{
				// 停止所有子系统
				printf("CentralController: Fault tolerance disabled, stopping all subsystems\n");
				Stop();
			}
		}
	}

	void CentralController::OnSubsystemRecovered(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		auto it = subsystem_statuses_.find(subsystem_id);
		if (it != subsystem_statuses_.end())
		{
			it->second.is_fault = false;
			printf("CentralController: Subsystem %u recovered\n", subsystem_id);

			// 恢复流量分配
			UpdateProportionalControl();
		}
	}

	void CentralController::CheckSubsystemHealth()
	{
		auto now = std::chrono::steady_clock::now();

		for (auto &[sub_id, status] : subsystem_statuses_)
		{
			// 检查是否长时间无数据更新（可能通信故障）
			auto elapsed = std::chrono::duration<double>(
							   now - status.last_update_time)
							   .count();

			if (elapsed > 5.0 && !status.is_fault)
			{
				fprintf(stderr, "CentralController: Subsystem %u no data for %.1fs\n",
						sub_id, elapsed);
				// 可以触发故障处理
				// OnSubsystemFault(sub_id);
			}

			// 检查流量异常（实际流量与目标流量偏差过大）
			if (status.target_flow > 0.0 && !status.is_refilling && !status.is_fault)
			{
				double error_pct = std::abs(status.actual_flow - status.target_flow) /
								   status.target_flow * 100.0;

				if (error_pct > 30.0) // 偏差超过30%
				{
					fprintf(stderr, "CentralController: Subsystem %u flow error %.1f%% "
									"(target: %.2f, actual: %.2f)\n",
							sub_id, error_pct, status.target_flow, status.actual_flow);
				}
			}
		}
	}

	// ============================================================================
	// 配方管理
	// ============================================================================
	bool CentralController::LoadRecipe(uint32_t recipe_id)
	{
		auto recipe = ConfigStore::Instance().LoadRecipe(recipe_id);
		if (recipe.recipe_id == 0)
		{
			fprintf(stderr, "CentralController: Recipe %u not found\n", recipe_id);
			return false;
		}

		std::lock_guard<std::mutex> lock(mutex_);
		active_recipe_ = recipe;

		printf("CentralController: Loaded recipe %u '%s'\n",
			   recipe_id, recipe.name.c_str());

		// 立即应用新配方
		SetMasterFlow(recipe.total_target_flow);

		return true;
	}

	bool CentralController::SaveRecipe(const Recipe &recipe)
	{
		return ConfigStore::Instance().SaveRecipe(recipe);
	}

	bool CentralController::DeleteRecipe(uint32_t recipe_id)
	{
		return ConfigStore::Instance().DeleteRecipe(recipe_id);
	}

	std::vector<Recipe> CentralController::GetAllRecipes()
	{
		return ConfigStore::Instance().LoadAllRecipes();
	}

	Recipe CentralController::GetActiveRecipe() const
	{
		std::lock_guard<std::mutex> lock(mutex_);
		return active_recipe_;
	}

	// ============================================================================
	// 状态查询
	// ============================================================================
	double CentralController::GetTotalActualFlow() const
	{
		std::lock_guard<std::mutex> lock(mutex_);

		double total = 0.0;
		for (const auto &[sub_id, status] : subsystem_statuses_)
		{
			if (!status.is_fault)
			{
				total += status.actual_flow;
			}
		}
		return total;
	}

	SubsystemStatus CentralController::GetSubsystemStatus(uint32_t subsystem_id) const
	{
		std::lock_guard<std::mutex> lock(mutex_);

		auto it = subsystem_statuses_.find(subsystem_id);
		if (it != subsystem_statuses_.end())
			return it->second;

		return SubsystemStatus{};
	}

	std::map<uint32_t, SubsystemStatus> CentralController::GetAllStatuses() const
	{
		std::lock_guard<std::mutex> lock(mutex_);
		return subsystem_statuses_;
	}

	size_t CentralController::GetRegisteredSubsystemCount() const
	{
		std::lock_guard<std::mutex> lock(mutex_);
		return subsystem_statuses_.size();
	}

	// ============================================================================
	// 注册子系统
	// ============================================================================
	void CentralController::RegisterSubsystem(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		SubsystemStatus status;
		status.subsystem_id = subsystem_id;
		status.last_update_time = std::chrono::steady_clock::now();

		subsystem_statuses_[subsystem_id] = status;

		printf("CentralController: Registered subsystem %u\n", subsystem_id);
	}

	void CentralController::UnregisterSubsystem(uint32_t subsystem_id)
	{
		std::lock_guard<std::mutex> lock(mutex_);

		subsystem_statuses_.erase(subsystem_id);

		printf("CentralController: Unregistered subsystem %u\n", subsystem_id);
	}

	// ============================================================================
	// 批次管理
	// ============================================================================
	uint32_t CentralController::StartBatch(const std::string &operator_name)
	{
		uint32_t batch_id = ConfigStore::Instance().StartBatch(
			active_recipe_.recipe_id, operator_name);

		if (batch_id > 0)
		{
			current_batch_id_ = batch_id;
			printf("CentralController: Started batch %u\n", batch_id);
		}

		return batch_id;
	}

	bool CentralController::EndBatch()
	{
		uint32_t batch_id = current_batch_id_.load();
		if (batch_id == 0)
			return false;

		// 计算总累积重量
		double total_weight = 0.0;
		std::lock_guard<std::mutex> lock(mutex_);

		for (const auto &[sub_id, status] : subsystem_statuses_)
		{
			total_weight += status.accumulated_weight;

			// 更新批次明细
			ConfigStore::Instance().UpdateBatchDetail(
				batch_id, sub_id,
				status.target_flow, status.actual_flow,
				status.accumulated_weight, status.refill_count);
		}

		bool ok = ConfigStore::Instance().EndBatch(batch_id, total_weight);

		if (ok)
		{
			current_batch_id_ = 0;
			printf("CentralController: Ended batch %u (total: %.2f kg)\n",
				   batch_id, total_weight);
		}

		return ok;
	}

} // namespace weighing