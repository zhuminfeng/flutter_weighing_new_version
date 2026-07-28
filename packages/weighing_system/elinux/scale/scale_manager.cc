#include "scale_manager.h"
#include <cstdio>

namespace weighing
{

	ScaleManager &ScaleManager::Instance()
	{
		static ScaleManager instance;
		return instance;
	}

	ScalePlatform *ScaleManager::CreateScale(uint32_t scale_id, float sample_rate)
	{
		std::lock_guard<std::mutex> lock(scales_mutex_);

		auto it = scales_.find(scale_id);
		if (it != scales_.end())
		{
			return it->second.get();
		}

		auto scale = std::make_unique<ScalePlatform>(scale_id, sample_rate);

		// if (global_weight_cb_)
		// {
		// 	scale->SetWeightCallback(global_weight_cb_);
		// }
		if (global_status_cb_)
		{
			scale->SetStatusCallback(global_status_cb_);
		}
		if (global_cal_cb_)
			scale->SetCalibrationCallback(global_cal_cb_);

		auto *ptr = scale.get();
		scales_[scale_id] = std::move(scale);
		printf("ScaleManager: Created scale %u (sample_rate=%.0f)\n", scale_id, sample_rate);
		return ptr;
	}

	ScalePlatform *ScaleManager::GetScale(uint32_t scale_id)
	{
		std::lock_guard<std::mutex> lock(scales_mutex_);
		auto it = scales_.find(scale_id);
		if (it != scales_.end())
		{
			return it->second.get();
		}
		return nullptr;
	}

	void ScaleManager::RemoveScale(uint32_t scale_id)
	{
		std::lock_guard<std::mutex> lock(scales_mutex_);
		scales_.erase(scale_id);
	}

	std::vector<uint32_t> ScaleManager::GetScaleIds() const
	{
		std::lock_guard<std::mutex> lock(scales_mutex_);
		std::vector<uint32_t> ids;
		for (const auto &pair : scales_)
		{
			ids.push_back(pair.first);
		}
		return ids;
	}

	void ScaleManager::StopAll()
	{
		// 先停输入源
		if (input_source_)
		{
			input_source_->Stop();
			printf("ScaleManager: Input source stopped\n");
		}

		// 秤台的 ProcessLoop 线程会在析构时 join
		// 这里不需要手动操作，但可以标记
		printf("ScaleManager: All scales stopped (%zu)\n", scales_.size());
	}

} // namespace weighing