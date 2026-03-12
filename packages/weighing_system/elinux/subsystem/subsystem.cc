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
			}
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
				scale->SetWeightCallback([this](const WeightData &data)
										 { OnScaleWeightUpdate(data); });
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

	std::vector<ScalePlatform *> Subsystem::GetScales()
	{
		return scales_;
	}

	void Subsystem::OnScaleWeightUpdate(const WeightData &data)
	{
		if (app_)
		{
			app_->OnWeightUpdate(data);
		}
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

} // namespace weighing