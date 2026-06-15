#include "database_manager.h"
#include <cstring>

namespace weighing
{

	DatabaseManager &DatabaseManager::Instance()
	{
		static DatabaseManager instance;
		return instance;
	}

	DatabaseManager::~DatabaseManager()
	{
		Close();
	}

	bool DatabaseManager::Open(const std::string &db_path)
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (db_)
			return true;

		int rc = sqlite3_open(db_path.c_str(), &db_);
		if (rc != SQLITE_OK)
		{
			db_ = nullptr;
			return false;
		}

		// Enable WAL mode for better concurrency
		sqlite3_exec(db_, "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr);
		sqlite3_exec(db_, "PRAGMA synchronous=NORMAL;", nullptr, nullptr, nullptr);

		return true;
	}

	void DatabaseManager::Close()
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (db_)
		{
			sqlite3_close(db_);
			db_ = nullptr;
		}
	}

	bool DatabaseManager::Execute(const std::string &sql)
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (!db_)
			return false;

		char *err_msg = nullptr;
		int rc = sqlite3_exec(db_, sql.c_str(), nullptr, nullptr, &err_msg);
		if (err_msg)
			sqlite3_free(err_msg);
		return rc == SQLITE_OK;
	}

	bool DatabaseManager::ExecuteWithParams(const std::string &sql,
											const std::vector<std::string> &params)
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (!db_)
			return false;

		sqlite3_stmt *stmt = nullptr;
		int rc = sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr);
		if (rc != SQLITE_OK)
			return false;

		for (size_t i = 0; i < params.size(); i++)
		{
			sqlite3_bind_text(stmt, static_cast<int>(i + 1),
							  params[i].c_str(), -1, SQLITE_TRANSIENT);
		}

		rc = sqlite3_step(stmt);
		sqlite3_finalize(stmt);
		return (rc == SQLITE_DONE || rc == SQLITE_ROW);
	}

	bool DatabaseManager::Query(const std::string &sql, RowCallback callback)
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (!db_)
			return false;

		sqlite3_stmt *stmt = nullptr;
		int rc = sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr);
		if (rc != SQLITE_OK)
			return false;

		while (sqlite3_step(stmt) == SQLITE_ROW)
		{
			std::map<std::string, std::string> row;
			int col_count = sqlite3_column_count(stmt);
			for (int i = 0; i < col_count; i++)
			{
				const char *name = sqlite3_column_name(stmt, i);
				const char *value = reinterpret_cast<const char *>(sqlite3_column_text(stmt, i));
				row[name ? name : ""] = value ? value : "";
			}
			callback(row);
		}

		sqlite3_finalize(stmt);
		return true;
	}

	bool DatabaseManager::QueryWithParams(const std::string &sql,
										  const std::vector<std::string> &params,
										  RowCallback callback)
	{
		std::lock_guard<std::mutex> lock(db_mutex_);
		if (!db_)
			return false;

		sqlite3_stmt *stmt = nullptr;
		int rc = sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr);
		if (rc != SQLITE_OK)
			return false;

		for (size_t i = 0; i < params.size(); i++)
		{
			sqlite3_bind_text(stmt, static_cast<int>(i + 1),
							  params[i].c_str(), -1, SQLITE_TRANSIENT);
		}

		while (sqlite3_step(stmt) == SQLITE_ROW)
		{
			std::map<std::string, std::string> row;
			int col_count = sqlite3_column_count(stmt);
			for (int i = 0; i < col_count; i++)
			{
				const char *name = sqlite3_column_name(stmt, i);
				const char *value = reinterpret_cast<const char *>(sqlite3_column_text(stmt, i));
				row[name ? name : ""] = value ? value : "";
			}
			callback(row);
		}

		sqlite3_finalize(stmt);
		return true;
	}

	bool DatabaseManager::InitializeSchema()
	{
		const char *schema = R"SQL(
        CREATE TABLE IF NOT EXISTS scale_config (
            scale_id INTEGER PRIMARY KEY,
            primary_unit INTEGER DEFAULT 1,
            capacity REAL DEFAULT 15.0,
            division REAL DEFAULT 0.005,
            overload_range INTEGER DEFAULT 9,
            auto_zero_mode INTEGER DEFAULT 1,
            auto_zero_range_d REAL DEFAULT 0.5,
            underload_range_d REAL DEFAULT 20.0,
            power_up_zero INTEGER DEFAULT 1,
            power_up_zero_pos_pct REAL DEFAULT 2.0,
            power_up_zero_neg_pct REAL DEFAULT 2.0,
            pushbutton_zero_enabled INTEGER DEFAULT 1,
            pushbutton_zero_pos_pct REAL DEFAULT 2.0,
            pushbutton_zero_neg_pct REAL DEFAULT 2.0,
            pushbutton_tare_enabled INTEGER DEFAULT 1,
            preset_tare_enabled INTEGER DEFAULT 1,
            lp_filter_level INTEGER DEFAULT 0,
            notch_enabled INTEGER DEFAULT 0,
            notch_frequency REAL DEFAULT 50.0,
            adaptive_enabled INTEGER DEFAULT 0,
            adaptive_range_d REAL DEFAULT 1.0,
            motion_range_d REAL DEFAULT 1.0,
            motion_detect_time REAL DEFAULT 0.3,
            stability_timeout REAL DEFAULT 3.0
        );

        CREATE TABLE IF NOT EXISTS calibration_data (
            scale_id INTEGER,
            point_index INTEGER,
            raw_reading REAL,
            known_weight REAL,
            PRIMARY KEY (scale_id, point_index)
        );

        CREATE TABLE IF NOT EXISTS calibration_zero (
            scale_id INTEGER PRIMARY KEY,
            zero_raw REAL DEFAULT 0.0,
            is_valid INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS subsystem_config (
            subsystem_id INTEGER PRIMARY KEY,
            name TEXT DEFAULT '',
            app_type INTEGER DEFAULT 0,
            scale_ids TEXT DEFAULT '',
            slave_ids TEXT DEFAULT '',

			-- 新增字段
			digital_io_pos INTEGER DEFAULT 0,   -- 数字 IO 模块位置
			servo_pos INTEGER DEFAULT 0,        -- 伺服驱动器位置
			material_name TEXT,                 -- 物料名称
			material_code TEXT,                 -- 物料编号
			priority INTEGER DEFAULT 0,         -- 优先级
			enabled INTEGER DEFAULT 1,          -- 是否启用
			register_to_central INTEGER DEFAULT 1  -- 是否注册到中央控制器
        );

        CREATE TABLE IF NOT EXISTS liw_config (
            subsystem_id INTEGER PRIMARY KEY,
            mode INTEGER DEFAULT 0,
            sub_mode INTEGER DEFAULT 0,
            safety_limit REAL DEFAULT 100.0,
            hopper_min REAL DEFAULT 0.0,
            hopper_max REAL DEFAULT 15.0,
            target_flow REAL DEFAULT 10.0,
            target_control_rate REAL DEFAULT 10.0,
            pre_refill INTEGER DEFAULT 0,
            sysid_lower REAL DEFAULT 0.0,
            sysid_upper REAL DEFAULT 90.0,
            sysid_smart INTEGER DEFAULT 0,
            sysid_step_duration REAL DEFAULT 10.0,
            sysid_filter_window REAL DEFAULT 0.5,
            pid_tuning_mode INTEGER DEFAULT 1,
            pid_filter_window REAL DEFAULT 0.5,
            pid_kp REAL DEFAULT 1.0,
            pid_ki REAL DEFAULT 1.0,
            pid_kd REAL DEFAULT 0.0,
            pid_max_flow REAL DEFAULT 100.0,
            pid_startup_time REAL DEFAULT 0.0,
            refill_mode INTEGER DEFAULT 0,
            refill_lower REAL DEFAULT 1.0,
            refill_upper REAL DEFAULT 10.0,
            refill_control_mode INTEGER DEFAULT 1,
            refill_setpoint REAL DEFAULT 10.0,
            refill_stabilize_time REAL DEFAULT 10.0,
            batch_target REAL DEFAULT 1.0,
            batch_in_flight REAL DEFAULT 0.0,
            batch_fine_threshold REAL DEFAULT 0.0,
            batch_fine_flow REAL DEFAULT 2.0,
            tolerance_delay REAL DEFAULT 0.0,
            tolerance_timeout REAL DEFAULT 0.0,
            tolerance_value REAL DEFAULT 0.0,
            emptying_auto_stop INTEGER DEFAULT 1,
            emptying_setpoint REAL DEFAULT 10.0,
            warning_rate_lower REAL DEFAULT 20.0,
            warning_rate_upper REAL DEFAULT 80.0,
            warning_refill_timeout REAL DEFAULT 10.0,
            warning_stop_on_error INTEGER DEFAULT 0,
            flow_eval_window REAL DEFAULT 3.0,
            flow_deviation REAL DEFAULT 10.0,
            flow_surge REAL DEFAULT 150.0,
            interlock_enabled INTEGER DEFAULT 0,
            interlock_delay REAL DEFAULT 0.0,
            stats_sample_period REAL DEFAULT 60.0,
            stats_sample_tolerance REAL DEFAULT 10.0
        );

        CREATE TABLE IF NOT EXISTS filling_config (
            subsystem_id INTEGER PRIMARY KEY,
            power_fail_recovery INTEGER DEFAULT 0,
            start_delay INTEGER DEFAULT 0,
            work_mode INTEGER DEFAULT 0,
            feed_speed INTEGER DEFAULT 1,
            target_value REAL DEFAULT 1.0,
            in_flight REAL DEFAULT 0.0,
            feed REAL DEFAULT 0.0,
            feed_inhibit_time REAL DEFAULT 0.0,
            fast_feed_inhibit_time REAL DEFAULT 0.0,
            auto_tare_enabled INTEGER DEFAULT 0,
            container_tare_upper REAL DEFAULT 0.0,
            container_tare_lower REAL DEFAULT 0.0,
            tolerance_delay REAL DEFAULT 0.0,
            tolerance_timeout REAL DEFAULT 0.0,
            tolerance_positive REAL DEFAULT 0.0,
            tolerance_negative REAL DEFAULT 0.0,
            spill_opt_mode INTEGER DEFAULT 0,
            spill_opt_range REAL DEFAULT 0.0,
            spill_opt_samples INTEGER DEFAULT 5,
            spill_opt_factor REAL DEFAULT 0.5,
            cutoff_opt_mode INTEGER DEFAULT 0,
            cutoff_opt_range REAL DEFAULT 0.0,
            cutoff_opt_cycles INTEGER DEFAULT 5,
            cutoff_opt_factor REAL DEFAULT 0.5,
            jog_mode INTEGER DEFAULT 0,
            jog_duration REAL DEFAULT 0.5,
            jog_pause REAL DEFAULT 1.0,
            jog_max_cycles INTEGER DEFAULT 3,
            refill_upper REAL DEFAULT 10.0,
            refill_lower REAL DEFAULT 1.0,
            emptying_mode INTEGER DEFAULT 0,
            emptying_residual REAL DEFAULT 0.1,
            emptying_time REAL DEFAULT 5.0,
            event_feed_timeout REAL DEFAULT 30.0,
            event_emptying_timeout REAL DEFAULT 60.0,
            event_refill_timeout REAL DEFAULT 60.0,
            event_process_timeout REAL DEFAULT 120.0,
            cycle_confirm INTEGER DEFAULT 0,
            fast_recovery INTEGER DEFAULT 0,
            interlock_enabled INTEGER DEFAULT 0,
            fast_feed_speed REAL DEFAULT 100.0,
            fine_feed_speed REAL DEFAULT 30.0
        );

        CREATE TABLE IF NOT EXISTS weight_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scale_id INTEGER,
            timestamp TEXT,
            gross_weight REAL,
            net_weight REAL,
            tare_weight REAL,
            unit INTEGER,
            is_stable INTEGER,
            record_type TEXT DEFAULT 'print'
        );

		-- 配方表
		CREATE TABLE IF NOT EXISTS recipe (
			recipe_id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			total_target_flow REAL DEFAULT 0.0,
			enable_stagger_refill INTEGER DEFAULT 1,
			refill_interval_min REAL DEFAULT 10.0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		);

		-- 配方明细表
		CREATE TABLE IF NOT EXISTS recipe_detail (
			recipe_id INTEGER NOT NULL,
			subsystem_id INTEGER NOT NULL,
			flow_ratio REAL NOT NULL,
			PRIMARY KEY (recipe_id, subsystem_id),
			FOREIGN KEY (recipe_id) REFERENCES recipe(recipe_id) ON DELETE CASCADE
		);

		-- 批次追溯表
		CREATE TABLE IF NOT EXISTS batch_trace (
			batch_id INTEGER PRIMARY KEY AUTOINCREMENT,
			recipe_id INTEGER NOT NULL,
			start_time TEXT NOT NULL,
			end_time TEXT,
			total_weight REAL DEFAULT 0.0,
			status TEXT DEFAULT 'running',
			operator_name TEXT,
			notes TEXT
		);

		-- 批次明细表
		CREATE TABLE IF NOT EXISTS batch_detail (
			batch_id INTEGER NOT NULL,
			subsystem_id INTEGER NOT NULL,
			target_flow REAL,
			actual_flow_avg REAL,
			accumulated_weight REAL,
			refill_count INTEGER DEFAULT 0,
			PRIMARY KEY (batch_id, subsystem_id),
			FOREIGN KEY (batch_id) REFERENCES batch_trace(batch_id) ON DELETE CASCADE
		);

		-- 物料配方元数据表（记录每种物料的参数快照）
		CREATE TABLE IF NOT EXISTS material_recipe (
			recipe_id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			app_type INTEGER NOT NULL DEFAULT 0,
			subsystem_id INTEGER NOT NULL DEFAULT 0,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP
		);

		-- 失重秤物料配方参数表（与 liw_config 列对齐）
		CREATE TABLE IF NOT EXISTS material_recipe_liw (
			recipe_id INTEGER PRIMARY KEY,
			mode INTEGER DEFAULT 0,
			sub_mode INTEGER DEFAULT 0,
			safety_limit REAL DEFAULT 100.0,
			hopper_min REAL DEFAULT 0.0,
			hopper_max REAL DEFAULT 15.0,
			target_flow REAL DEFAULT 10.0,
			target_control_rate REAL DEFAULT 10.0,
			pre_refill INTEGER DEFAULT 0,
			sysid_lower REAL DEFAULT 0.0,
			sysid_upper REAL DEFAULT 90.0,
			sysid_smart INTEGER DEFAULT 0,
			sysid_step_duration REAL DEFAULT 10.0,
			sysid_filter_window REAL DEFAULT 0.5,
			pid_tuning_mode INTEGER DEFAULT 1,
			pid_filter_window REAL DEFAULT 0.5,
			pid_kp REAL DEFAULT 1.0,
			pid_ki REAL DEFAULT 1.0,
			pid_kd REAL DEFAULT 0.0,
			pid_max_flow REAL DEFAULT 100.0,
			pid_startup_time REAL DEFAULT 0.0,
			refill_mode INTEGER DEFAULT 0,
			refill_lower REAL DEFAULT 1.0,
			refill_upper REAL DEFAULT 10.0,
			refill_control_mode INTEGER DEFAULT 1,
			refill_setpoint REAL DEFAULT 10.0,
			refill_stabilize_time REAL DEFAULT 10.0,
			batch_target REAL DEFAULT 1.0,
			batch_in_flight REAL DEFAULT 0.0,
			batch_fine_threshold REAL DEFAULT 0.0,
			batch_fine_flow REAL DEFAULT 2.0,
			tolerance_delay REAL DEFAULT 0.0,
			tolerance_timeout REAL DEFAULT 0.0,
			tolerance_value REAL DEFAULT 0.0,
			emptying_auto_stop INTEGER DEFAULT 1,
			emptying_setpoint REAL DEFAULT 10.0,
			warning_rate_lower REAL DEFAULT 20.0,
			warning_rate_upper REAL DEFAULT 80.0,
			warning_refill_timeout REAL DEFAULT 10.0,
			warning_stop_on_error INTEGER DEFAULT 0,
			flow_eval_window REAL DEFAULT 3.0,
			flow_deviation REAL DEFAULT 10.0,
			flow_surge REAL DEFAULT 150.0,
			interlock_enabled INTEGER DEFAULT 0,
			interlock_delay REAL DEFAULT 0.0,
			stats_sample_period REAL DEFAULT 60.0,
			stats_sample_tolerance REAL DEFAULT 10.0,
			FOREIGN KEY (recipe_id) REFERENCES material_recipe(recipe_id) ON DELETE CASCADE
		);

		-- 罐装秤物料配方参数表（与 filling_config 列对齐）
		CREATE TABLE IF NOT EXISTS material_recipe_filling (
			recipe_id INTEGER PRIMARY KEY,
			power_fail_recovery INTEGER DEFAULT 0,
			start_delay INTEGER DEFAULT 0,
			work_mode INTEGER DEFAULT 0,
			feed_speed INTEGER DEFAULT 1,
			target_value REAL DEFAULT 1.0,
			in_flight REAL DEFAULT 0.0,
			feed REAL DEFAULT 0.0,
			feed_inhibit_time REAL DEFAULT 0.0,
			fast_feed_inhibit_time REAL DEFAULT 0.0,
			auto_tare_enabled INTEGER DEFAULT 0,
			container_tare_upper REAL DEFAULT 0.0,
			container_tare_lower REAL DEFAULT 0.0,
			tolerance_delay REAL DEFAULT 0.0,
			tolerance_timeout REAL DEFAULT 0.0,
			tolerance_positive REAL DEFAULT 0.0,
			tolerance_negative REAL DEFAULT 0.0,
			spill_opt_mode INTEGER DEFAULT 0,
			spill_opt_range REAL DEFAULT 0.0,
			spill_opt_samples INTEGER DEFAULT 5,
			spill_opt_factor REAL DEFAULT 0.5,
			cutoff_opt_mode INTEGER DEFAULT 0,
			cutoff_opt_range REAL DEFAULT 0.0,
			cutoff_opt_cycles INTEGER DEFAULT 5,
			cutoff_opt_factor REAL DEFAULT 0.5,
			jog_mode INTEGER DEFAULT 0,
			jog_duration REAL DEFAULT 0.5,
			jog_pause REAL DEFAULT 1.0,
			jog_max_cycles INTEGER DEFAULT 3,
			refill_upper REAL DEFAULT 10.0,
			refill_lower REAL DEFAULT 1.0,
			emptying_mode INTEGER DEFAULT 0,
			emptying_residual REAL DEFAULT 0.1,
			emptying_time REAL DEFAULT 5.0,
			event_feed_timeout REAL DEFAULT 30.0,
			event_emptying_timeout REAL DEFAULT 60.0,
			event_refill_timeout REAL DEFAULT 60.0,
			event_process_timeout REAL DEFAULT 120.0,
			cycle_confirm INTEGER DEFAULT 0,
			fast_recovery INTEGER DEFAULT 0,
			interlock_enabled INTEGER DEFAULT 0,
			fast_feed_speed REAL DEFAULT 100.0,
			fine_feed_speed REAL DEFAULT 30.0,
			FOREIGN KEY (recipe_id) REFERENCES material_recipe(recipe_id) ON DELETE CASCADE
		);
    )SQL";

		return Execute(schema);
	}

} // namespace weighing