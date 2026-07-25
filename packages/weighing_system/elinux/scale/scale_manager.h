#ifndef SCALE_MANAGER_H
#define SCALE_MANAGER_H

#include "scale_platform.h"
#include "../input/input_source.h"
#include <map>
#include <memory>
#include <mutex>

namespace weighing
{

	class ScaleManager
	{
	public:
		static ScaleManager &Instance();

		// 创建秤台（带 sample_rate 参数的原始版本）
		ScalePlatform *CreateScale(uint32_t scale_id, float sample_rate = 1000.0f);

		ScalePlatform *GetScale(uint32_t scale_id);
		void RemoveScale(uint32_t scale_id);
		std::vector<uint32_t> GetScaleIds() const;

		// SystemInitializer 需要的方法
		std::map<uint32_t, std::unique_ptr<ScalePlatform>> &GetAllScales() { return scales_; }
		const std::map<uint32_t, std::unique_ptr<ScalePlatform>> &GetAllScales() const { return scales_; }

		// InputSource 所有权管理
		void SetInputSource(std::unique_ptr<InputSource> source) { input_source_ = std::move(source); }
		InputSource *GetInputSource() { return input_source_.get(); }

		// 停止所有秤台和输入源
		void StopAll();

		// void SetGlobalWeightCallback(WeightCallback cb)
		// {
		// 	std::lock_guard<std::mutex> lock(scales_mutex_);
		// 	global_weight_cb_ = cb;

		// 	// 🚀 核心防呆：如果内存中已经有建好的秤台，给它们补发回调挂载！
		// 	for (auto &pair : scales_)
		// 	{
		// 		if (pair.second)
		// 		{
		// 			pair.second->SetWeightCallback(cb);
		// 		}
		// 	}
		// }
		void SetGlobalStatusCallback(StatusCallback cb)
		{
			std::lock_guard<std::mutex> lock(scales_mutex_);
			global_status_cb_ = cb;

			// 🚀 核心防呆：给已存在的秤台补发状态回调
			for (auto &pair : scales_)
			{
				if (pair.second)
				{
					pair.second->SetStatusCallback(cb);
				}
			}
		}

	private:
		ScaleManager() = default;
		~ScaleManager() = default;
		ScaleManager(const ScaleManager &) = delete;
		ScaleManager &operator=(const ScaleManager &) = delete;

		std::map<uint32_t, std::unique_ptr<ScalePlatform>> scales_;
		mutable std::mutex scales_mutex_;

		std::unique_ptr<InputSource> input_source_;

		// WeightCallback global_weight_cb_;
		StatusCallback global_status_cb_;
	};

} // namespace weighing

#endif // SCALE_MANAGER_H