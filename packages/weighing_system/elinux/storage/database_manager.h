#ifndef DATABASE_MANAGER_H
#define DATABASE_MANAGER_H

#include <sqlite3.h>
#include <string>
#include <mutex>
#include <functional>
#include <vector>
#include <map>
#include "../common_types.h"

namespace weighing
{

	class DatabaseManager
	{
	public:
		static DatabaseManager &Instance();

		bool Open(const std::string &db_path);
		void Close();
		bool IsOpen() const { return db_ != nullptr; }

		// Generic execute
		bool Execute(const std::string &sql);
		bool ExecuteWithParams(const std::string &sql,
							   const std::vector<std::string> &params);

		// Query with callback
		using RowCallback = std::function<void(const std::map<std::string, std::string> &)>;
		bool Query(const std::string &sql, RowCallback callback);
		bool QueryWithParams(const std::string &sql,
							 const std::vector<std::string> &params,
							 RowCallback callback);

		// Schema initialization
		bool InitializeSchema();
		// 🚀 新增：为全新子系统在数据库中初始化一条占位记录
		bool InitSubsystemConfig(uint32_t subsystem_id, AppType app_type, std::string *err = nullptr);

	private:
		DatabaseManager() = default;
		~DatabaseManager();

		sqlite3 *db_ = nullptr;
		std::mutex db_mutex_;
	};

} // namespace weighing

#endif // DATABASE_MANAGER_H