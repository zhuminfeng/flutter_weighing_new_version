#ifndef SUBSYSTEM_MANAGER_H
#define SUBSYSTEM_MANAGER_H

#include "subsystem.h"
#include <map>
#include <memory>
#include <mutex>
#include <cstdint>

namespace weighing
{

	class SubsystemManager
	{
	public:
		static SubsystemManager &Instance();

		Subsystem *CreateSubsystem(const SubsystemConfig &config);
		Subsystem *GetSubsystem(uint32_t id);
		void RemoveSubsystem(uint32_t id);
		std::vector<uint32_t> GetSubsystemIds() const;

		std::map<uint32_t, std::unique_ptr<Subsystem>> &GetAllSubsystems() { return subsystems_; }
		const std::map<uint32_t, std::unique_ptr<Subsystem>> &GetAllSubsystems() const { return subsystems_; }

		void StartAll();
		void StopAll();

	private:
		SubsystemManager() = default;
		~SubsystemManager() = default;
		SubsystemManager(const SubsystemManager &) = delete;
		SubsystemManager &operator=(const SubsystemManager &) = delete;

		std::map<uint32_t, std::unique_ptr<Subsystem>> subsystems_;
		mutable std::mutex mutex_;
	};

} // namespace weighing

#endif // SUBSYSTEM_MANAGER_H