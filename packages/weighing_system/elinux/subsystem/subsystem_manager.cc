#include "subsystem_manager.h"

namespace weighing
{

	SubsystemManager &SubsystemManager::Instance()
	{
		static SubsystemManager instance;
		return instance;
	}

	Subsystem *SubsystemManager::CreateSubsystem(const SubsystemConfig &config)
	{
		std::lock_guard<std::mutex> lock(mutex_);
		auto sub = std::make_unique<Subsystem>(config);
		auto *ptr = sub.get();
		subsystems_[config.id] = std::move(sub);
		return ptr;
	}

	Subsystem *SubsystemManager::GetSubsystem(uint32_t id)
	{
		std::lock_guard<std::mutex> lock(mutex_);
		auto it = subsystems_.find(id);
		return (it != subsystems_.end()) ? it->second.get() : nullptr;
	}

	void SubsystemManager::RemoveSubsystem(uint32_t id)
	{
		std::lock_guard<std::mutex> lock(mutex_);
		subsystems_.erase(id);
	}

	std::vector<uint32_t> SubsystemManager::GetSubsystemIds() const
	{
		std::lock_guard<std::mutex> lock(mutex_);
		std::vector<uint32_t> ids;
		for (const auto &p : subsystems_)
			ids.push_back(p.first);
		return ids;
	}

	void SubsystemManager::StartAll()
	{
		std::lock_guard<std::mutex> lock(mutex_);
		for (auto &p : subsystems_)
		{
			p.second->Initialize();
			p.second->Start();
		}
	}

	void SubsystemManager::StopAll()
	{
		std::lock_guard<std::mutex> lock(mutex_);
		for (auto &p : subsystems_)
		{
			p.second->Stop();
		}
	}

} // namespace weighing