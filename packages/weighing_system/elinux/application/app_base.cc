#include "app_base.h"
#include "../storage/weight_record_store.h"
#include <cstring>
#include <cstdio>

namespace weighing
{

	AppBase::AppBase(uint32_t subsystem_id, AppType type)
		: subsystem_id_(subsystem_id), app_type_(type)
	{
		status_data_.app_type = type;
	}

	AppBase::~AppBase()
	{
		Stop();
	}

	void AppBase::Start()
	{
		if (run_state_.load() == AppRunState::kRunning)
			return;

		SetRunState(AppRunState::kRunning);

		if (!thread_running_.load())
		{
			thread_running_.store(true);
			control_thread_ = std::thread([this]()
										  {
				while (thread_running_.load(std::memory_order_acquire)) {
					if (run_state_.load(std::memory_order_acquire) == AppRunState::kRunning) {
						ControlLoop();
					}
					std::this_thread::sleep_for(std::chrono::milliseconds(1));
				} });
		}

		SetRunningOutput(true);
	}

	void AppBase::Stop()
	{
		SetRunState(AppRunState::kIdle);
		thread_running_.store(false, std::memory_order_release);
		if (control_thread_.joinable())
		{
			control_thread_.join();
		}

		// 停止所有输出
		SetControlRate(0.0f);
		SetValveOutputs(0, false, false, false, false);
		SetRunningOutput(false);
		SetAlarmOutput(false);
		SetWarningOutput(false);

		// 重置输出状态
		dio_outputs_ = DioOutputSignals{};
	}

	void AppBase::Pause()
	{
		SetRunState(AppRunState::kPaused);
	}

	void AppBase::Resume()
	{
		if (run_state_.load() == AppRunState::kPaused)
		{
			SetRunState(AppRunState::kRunning);
		}
	}

	void AppBase::DoZero()
	{
		if (scale_)
			scale_->DoPushbuttonZero();
	}

	void AppBase::DoTare()
	{
		if (scale_)
			scale_->DoTare();
	}

	void AppBase::ClearTare()
	{
		if (scale_)
			scale_->ClearTare();
	}

	void AppBase::EPrint()
	{
		if (!scale_)
			return;
		auto wd = scale_->GetWeightData();
		WeightRecordStore::Instance().SaveRecord(wd, "eprint");
	}

	AppStatusData AppBase::GetStatus() const
	{
		std::lock_guard<std::mutex> lock(status_mutex_);
		return status_data_;
	}

	void AppBase::SetRunState(AppRunState state)
	{
		run_state_.store(state, std::memory_order_release);
		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.state = state;
		}
		if (status_callback_)
		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_callback_(subsystem_id_, status_data_);
		}
	}

	void AppBase::EmitWarning(const std::string &msg)
	{
		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.warning_active = true;
			status_data_.warning_message = msg;
		}
		SetWarningOutput(true);
	}

	void AppBase::ClearWarning()
	{
		{
			std::lock_guard<std::mutex> lock(status_mutex_);
			status_data_.warning_active = false;
			status_data_.warning_message.clear();
		}
		SetWarningOutput(false);
	}

	// === 通过 OutputManager 控制物理输出 ===

	void AppBase::SetAlarmOutput(bool active)
	{
		dio_outputs_.alarm = active;
		uint16_t io_pos = OutputManager::Instance().GetSubsystemIOPosition(subsystem_id_);
		if (io_pos != 0)
		{
			OutputManager::Instance().SetAlarm(io_pos, active);
		}
	}

	void AppBase::SetRunningOutput(bool running)
	{
		dio_outputs_.running = running;
		uint16_t io_pos = OutputManager::Instance().GetSubsystemIOPosition(subsystem_id_);
		if (io_pos != 0)
		{
			OutputManager::Instance().SetRunning(io_pos, running);
		}
	}

	void AppBase::SetWarningOutput(bool warning)
	{
		dio_outputs_.warning = warning;
		uint16_t io_pos = OutputManager::Instance().GetSubsystemIOPosition(subsystem_id_);
		if (io_pos != 0)
		{
			OutputManager::Instance().SetWarning(io_pos, warning);
		}
	}

} // namespace weighing