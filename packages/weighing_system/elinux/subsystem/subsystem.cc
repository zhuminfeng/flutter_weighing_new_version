#include "subsystem.h"
#include "../scale/scale_manager.h"
#include <cstdio>

namespace weighing
{

	Subsystem::Subsystem(const SubsystemConfig &config) : config_(config) {}

	Subsystem::~Subsystem()
	{
		Stop();
	}

	bool Subsystem::Initialize()
	{
		// 获取秤台引用
		scales_.clear();
		for (auto sid : config_.scale_ids)
		{
			auto *scale = ScaleManager::Instance().GetScale(sid);
			if (scale)
			{
				scales_.push_back(scale);
				printf("Subsystem %u: Found scale %u\n", config_.id, sid);
			}
			else
			{
				fprintf(stderr, "Subsystem %u: Scale %u not found\n", config_.id, sid);
			}
		}

		if (scales_.empty())
		{
			fprintf(stderr, "Subsystem %u: No valid scales\n", config_.id);
			return false;
		}

		// 验证秤台数量与模式匹配
		if (config_.scale_mode == ScaleMode::kSingle && scales_.size() != 1)
		{
			fprintf(stderr, "Subsystem %u: Single mode requires exactly 1 scale, got %zu\n",
					config_.id, scales_.size());
			return false;
		}
		else if (config_.scale_mode == ScaleMode::kDualCoarseFine && scales_.size() != 2)
		{
			fprintf(stderr, "Subsystem %u: Dual coarse-fine mode requires exactly 2 scales, got %zu\n",
					config_.id, scales_.size());
			return false;
		}

		// 根据应用类型创建应用实例
		switch (config_.app_type)
		{
		case AppType::kLossInWeight:
			app_ = std::make_unique<LiwApplication>(config_.id);
			break;
		case AppType::kFilling:
			app_ = std::make_unique<FillingApplication>(config_.id);
			break;
		}

		if (app_ && !scales_.empty())
		{
			app_->SetScale(scales_[0]); // 主秤台

			// 连接重量回调
			for (auto *scale : scales_)
			{
				uint32_t scale_id = scale->GetScaleId();

				scale->SetWeightCallback([this, scale_id](const WeightData &data)
										 { OnScaleWeightUpdate(scale_id, data); });
			}
		}

		if (app_)
		{
			return app_->Initialize();
		}

		return false;
	}

	void Subsystem::Start()
	{
		if (app_)
			app_->Start();
	}

	void Subsystem::Stop()
	{
		if (app_)
			app_->Stop();
	}

	LiwApplication *Subsystem::GetLiwApp()
	{
		if (config_.app_type == AppType::kLossInWeight)
		{
			return dynamic_cast<LiwApplication *>(app_.get());
		}
		return nullptr;
	}

	FillingApplication *Subsystem::GetFillingApp()
	{
		if (config_.app_type == AppType::kFilling)
		{
			return dynamic_cast<FillingApplication *>(app_.get());
		}
		return nullptr;
	}

	ScalePlatform *Subsystem::GetScale(uint16_t channel)
	{
		auto it = channel_to_scale_.find(channel);
		if (it != channel_to_scale_.end())
		{
			uint32_t scale_id = it->second;
			return ScaleManager::Instance().GetScale(scale_id);
		}
		return nullptr;
	}

	const std::vector<ScalePlatform *> &Subsystem::GetAllScales() const
	{
		return scales_;
	}

	void Subsystem::BuildScaleChannelMapping()
	{
		scale_to_channel_.clear();
		channel_to_scale_.clear();

		if (config_.scale_mode == ScaleMode::kSingle)
		{
			// 单秤台模式：通道 0 对应唯一的秤台
			uint32_t scale_id = config_.scale_ids[0];
			scale_to_channel_[scale_id] = 0;
			channel_to_scale_[0] = scale_id;
			printf("Subsystem %u: Scale %u -> Channel 0 (single mode)\n",
				   config_.id, scale_id);
		}
		else if (config_.scale_mode == ScaleMode::kDualCoarseFine)
		{
			// 粗精秤模式：通道 0=粗秤, 通道 1=精秤
			uint32_t coarse_scale_id = config_.scale_ids[0];
			uint32_t fine_scale_id = config_.scale_ids[1];

			scale_to_channel_[coarse_scale_id] = 0;
			scale_to_channel_[fine_scale_id] = 1;
			channel_to_scale_[0] = coarse_scale_id;
			channel_to_scale_[1] = fine_scale_id;

			printf("Subsystem %u: Scale %u -> Channel 0 (coarse scale)\n",
				   config_.id, coarse_scale_id);
			printf("Subsystem %u: Scale %u -> Channel 1 (fine scale)\n",
				   config_.id, fine_scale_id);
		}
	}

	void Subsystem::OnScaleWeightUpdate(uint32_t scale_id, const WeightData &data)
	{
		if (!app_)
			return;

		// 单秤台模式：直接调用 OnWeightUpdate
		app_->OnWeightUpdate(data);
		// auto it = scale_to_channel_.find(scale_id);
		// if (it == scale_to_channel_.end())
		// {
		// 	fprintf(stderr, "Subsystem %u: Unknown scale %u\n", config_.id, scale_id);
		// 	return;
		// }

		// uint16_t channel = it->second;

		// if (config_.scale_mode == ScaleMode::kSingle)
		// {
		// 	// 单秤台模式：直接调用 OnWeightUpdate
		// 	app_->OnWeightUpdate(data);
		// }
		// else
		// {
		// 	// 多秤台模式：调用通道接口
		// 	app_->OnChannelWeightUpdate(channel, data);
		// }
	}

	void Subsystem::HandleDioInputs(const DioInputSignals &signals)
	{
		if (app_)
		{
			app_->ProcessDioInputs(signals);
		}
	}

	DioOutputSignals Subsystem::GetDioOutputs() const
	{
		if (app_)
			return app_->GetDioOutputs();
		return DioOutputSignals{};
	}

	void Subsystem::SetEnabled(bool enabled)
	{
		config_.enabled = enabled;

		if (!enabled)
		{
			Stop();
			printf("Subsystem %u: Disabled\n", config_.id);
		}
		else
		{
			Start();
			printf("Subsystem %u: Enabled\n", config_.id);
		}

		// ConfigStore::Instance().SaveSubsystemConfig(config_);
	}

} // namespace weighing