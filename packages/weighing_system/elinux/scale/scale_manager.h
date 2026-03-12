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

		void SetGlobalWeightCallback(WeightCallback cb) { global_weight_cb_ = cb; }
		void SetGlobalStatusCallback(StatusCallback cb) { global_status_cb_ = cb; }

	private:
		ScaleManager() = default;
		~ScaleManager() = default;
		ScaleManager(const ScaleManager &) = delete;
		ScaleManager &operator=(const ScaleManager &) = delete;

		std::map<uint32_t, std::unique_ptr<ScalePlatform>> scales_;
		mutable std::mutex scales_mutex_;

		std::unique_ptr<InputSource> input_source_;

		WeightCallback global_weight_cb_;
		StatusCallback global_status_cb_;
	};

} // namespace weighing

#endif // SCALE_MANAGER_H