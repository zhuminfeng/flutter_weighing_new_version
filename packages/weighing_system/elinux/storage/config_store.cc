#include "config_store.h"
#include "database_manager.h"
#include <sstream>

namespace weighing
{

	ConfigStore &ConfigStore::Instance()
	{
		static ConfigStore instance;
		return instance;
	}

	bool ConfigStore::SaveScaleConfig(uint32_t scale_id, const ScaleParams &params,
									  const ZeroConfig &zero, const TareConfig &tare,
									  const FilterStabilityConfig &filter)
	{
		auto &db = DatabaseManager::Instance();

		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO scale_config (scale_id, primary_unit, capacity, division, "
			<< "overload_range, auto_zero_mode, auto_zero_range_d, underload_range_d, "
			<< "power_up_zero, power_up_zero_pos_pct, power_up_zero_neg_pct, "
			<< "pushbutton_zero_enabled, pushbutton_zero_pos_pct, pushbutton_zero_neg_pct, "
			<< "pushbutton_tare_enabled, preset_tare_enabled, "
			<< "lp_filter_level, notch_enabled, notch_frequency, "
			<< "adaptive_enabled, adaptive_range_d, "
			<< "motion_range_d, motion_detect_time, stability_timeout) VALUES ("
			<< scale_id << ","
			<< static_cast<int>(params.primary_unit) << ","
			<< params.capacity << "," << params.division << ","
			<< params.overload_range << ","
			<< static_cast<int>(zero.auto_zero_mode) << ","
			<< zero.auto_zero_range_d << "," << zero.underload_range_d << ","
			<< static_cast<int>(zero.power_up_zero) << ","
			<< zero.power_up_zero_pos_pct << "," << zero.power_up_zero_neg_pct << ","
			<< (zero.pushbutton_zero_enabled ? 1 : 0) << ","
			<< zero.pushbutton_zero_pos_pct << "," << zero.pushbutton_zero_neg_pct << ","
			<< (tare.pushbutton_tare_enabled ? 1 : 0) << ","
			<< (tare.preset_tare_enabled ? 1 : 0) << ","
			<< static_cast<int>(filter.low_pass_level) << ","
			<< (filter.notch_enabled ? 1 : 0) << "," << filter.notch_frequency << ","
			<< (filter.adaptive_enabled ? 1 : 0) << "," << filter.adaptive_range_d << ","
			<< filter.motion_range_d << "," << filter.motion_detect_time << ","
			<< filter.stability_timeout << ")";

		return db.Execute(sql.str());
	}

	bool ConfigStore::LoadScaleConfig(uint32_t scale_id, ScaleParams &params,
									  ZeroConfig &zero, TareConfig &tare,
									  FilterStabilityConfig &filter)
	{
		auto &db = DatabaseManager::Instance();

		std::string sql = "SELECT * FROM scale_config WHERE scale_id = " +
						  std::to_string(scale_id);
		bool found = false;

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
        found = true;
        auto get = [&](const std::string& key, double def) -> double {
            auto it = row.find(key);
            if (it != row.end() && !it->second.empty()) return std::stod(it->second);
            return def;
        };
        auto getI = [&](const std::string& key, int def) -> int {
            auto it = row.find(key);
            if (it != row.end() && !it->second.empty()) return std::stoi(it->second);
            return def;
        };

        params.primary_unit = static_cast<WeightUnit>(getI("primary_unit", 1));
        params.capacity = get("capacity", 15.0);
        params.division = get("division", 0.005);
        params.overload_range = getI("overload_range", 9);

        zero.auto_zero_mode = static_cast<AutoZeroMode>(getI("auto_zero_mode", 1));
        zero.auto_zero_range_d = get("auto_zero_range_d", 0.5);
        zero.underload_range_d = get("underload_range_d", 20.0);
        zero.power_up_zero = static_cast<PowerUpZeroMode>(getI("power_up_zero", 1));
        zero.power_up_zero_pos_pct = get("power_up_zero_pos_pct", 2.0);
        zero.power_up_zero_neg_pct = get("power_up_zero_neg_pct", 2.0);
        zero.pushbutton_zero_enabled = getI("pushbutton_zero_enabled", 1) != 0;
        zero.pushbutton_zero_pos_pct = get("pushbutton_zero_pos_pct", 2.0);
        zero.pushbutton_zero_neg_pct = get("pushbutton_zero_neg_pct", 2.0);

        tare.pushbutton_tare_enabled = getI("pushbutton_tare_enabled", 1) != 0;
        tare.preset_tare_enabled = getI("preset_tare_enabled", 1) != 0;

        filter.low_pass_level = static_cast<LowPassFilterLevel>(getI("lp_filter_level", 0));
        filter.notch_enabled = getI("notch_enabled", 0) != 0;
        filter.notch_frequency = get("notch_frequency", 50.0);
        filter.adaptive_enabled = getI("adaptive_enabled", 0) != 0;
        filter.adaptive_range_d = get("adaptive_range_d", 1.0);
        filter.motion_range_d = get("motion_range_d", 1.0);
        filter.motion_detect_time = get("motion_detect_time", 0.3);
        filter.stability_timeout = get("stability_timeout", 3.0); });

		return found;
	}

	bool ConfigStore::SaveLiwConfig(uint32_t subsystem_id, const LiwApplication *app)
	{
		if (!app)
			return false;
		auto &db = DatabaseManager::Instance();

		auto base = app->GetBaseConfig();
		auto sys = app->GetSystemConfig();
		auto sysid = app->GetSystemIdConfig();
		auto ctrl = app->GetControllerConfig();
		auto refill = app->GetRefillConfig();
		auto target = app->GetTargetValuesConfig();
		auto tol = app->GetToleranceCheckConfig();
		auto empty = app->GetEmptyingConfig();
		auto warn = app->GetWarningConfig();
		auto flow = app->GetFlowMonitorConfig();
		auto adv = app->GetAdvancedConfig();
		auto stats = app->GetStatsConfig();

		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO liw_config (subsystem_id,"
			<< "mode,sub_mode,safety_limit,hopper_min,hopper_max,"
			<< "target_flow,target_control_rate,pre_refill,"
			<< "sysid_lower,sysid_upper,sysid_smart,sysid_step_duration,sysid_filter_window,"
			<< "pid_tuning_mode,pid_filter_window,pid_kp,pid_ki,pid_kd,pid_max_flow,pid_startup_time,"
			<< "refill_mode,refill_lower,refill_upper,refill_control_mode,refill_setpoint,refill_stabilize_time,"
			<< "batch_target,batch_in_flight,batch_fine_threshold,batch_fine_flow,"
			<< "tolerance_delay,tolerance_timeout,tolerance_value,"
			<< "emptying_auto_stop,emptying_setpoint,"
			<< "warning_rate_lower,warning_rate_upper,warning_refill_timeout,warning_stop_on_error,"
			<< "flow_eval_window,flow_deviation,flow_surge,"
			<< "interlock_enabled,interlock_delay,"
			<< "stats_sample_period,stats_sample_tolerance) VALUES ("
			<< subsystem_id << ","
			<< static_cast<int>(base.mode) << "," << static_cast<int>(base.sub_mode) << ","
			<< sys.safety_limit << "," << sys.hopper_min << "," << sys.hopper_max << ","
			<< sys.target_flow << "," << sys.target_control_rate << "," << (sys.pre_refill ? 1 : 0) << ","
			<< sysid.adjust_range_lower << "," << sysid.adjust_range_upper << ","
			<< (sysid.smart_step_control ? 1 : 0) << "," << sysid.step_duration << "," << sysid.filter_window << ","
			<< static_cast<int>(ctrl.tuning_mode) << "," << ctrl.filter_window << ","
			<< ctrl.Kp << "," << ctrl.Ki << "," << ctrl.Kd << "," << ctrl.max_flow << "," << ctrl.startup_time << ","
			<< static_cast<int>(refill.mode) << "," << refill.lower_limit << "," << refill.upper_limit << ","
			<< static_cast<int>(refill.control_mode) << "," << refill.control_setpoint << "," << refill.stabilize_time << ","
			<< target.batch_target << "," << target.in_flight << "," << target.fine_feed_threshold << "," << target.fine_feed_flow << ","
			<< tol.pre_check_delay << "," << tol.stability_timeout << "," << tol.tolerance << ","
			<< (empty.auto_stop_at_alarm ? 1 : 0) << "," << empty.control_setpoint << ","
			<< warn.control_rate_lower << "," << warn.control_rate_upper << "," << warn.refill_timeout << "," << (warn.stop_on_error ? 1 : 0) << ","
			<< flow.evaluation_window << "," << flow.deviation_threshold << "," << flow.surge_threshold << ","
			<< (adv.interlock_enabled ? 1 : 0) << "," << adv.interlock_delay << ","
			<< stats.sample_period << "," << stats.sample_tolerance << ")";

		return db.Execute(sql.str());
	}

	bool ConfigStore::LoadLiwConfig(uint32_t subsystem_id, LiwApplication *app)
	{
		if (!app)
			return false;
		auto &db = DatabaseManager::Instance();

		std::string sql = "SELECT * FROM liw_config WHERE subsystem_id = " +
						  std::to_string(subsystem_id);
		bool found = false;

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
        found = true;
        auto get = [&](const std::string& key, double def) -> double {
            auto it = row.find(key); return (it != row.end() && !it->second.empty()) ? std::stod(it->second) : def;
        };
        auto getI = [&](const std::string& key, int def) -> int {
            auto it = row.find(key); return (it != row.end() && !it->second.empty()) ? std::stoi(it->second) : def;
        };

        LiwBaseConfig base;
        base.mode = static_cast<LiwMode>(getI("mode", 0));
        base.sub_mode = static_cast<LiwSubMode>(getI("sub_mode", 0));
        app->SetBaseConfig(base);

        LiwSystemConfig sys;
        sys.safety_limit = static_cast<float>(get("safety_limit", 100.0));
        sys.hopper_min = static_cast<float>(get("hopper_min", 0.0));
        sys.hopper_max = static_cast<float>(get("hopper_max", 15.0));
        sys.target_flow = static_cast<float>(get("target_flow", 10.0));
        sys.target_control_rate = static_cast<float>(get("target_control_rate", 10.0));
        sys.pre_refill = getI("pre_refill", 0) != 0;
        app->SetSystemConfig(sys);

        LiwSystemIdConfig sysid;
        sysid.adjust_range_lower = static_cast<float>(get("sysid_lower", 0.0));
        sysid.adjust_range_upper = static_cast<float>(get("sysid_upper", 90.0));
        sysid.smart_step_control = getI("sysid_smart", 0) != 0;
        sysid.step_duration = static_cast<float>(get("sysid_step_duration", 10.0));
        sysid.filter_window = static_cast<float>(get("sysid_filter_window", 0.5));
        app->SetSystemIdConfig(sysid);

        LiwControllerConfig ctrl;
        ctrl.tuning_mode = static_cast<PidTuningMode>(getI("pid_tuning_mode", 1));
        ctrl.filter_window = static_cast<float>(get("pid_filter_window", 0.5));
        ctrl.Kp = static_cast<float>(get("pid_kp", 1.0));
        ctrl.Ki = static_cast<float>(get("pid_ki", 1.0));
        ctrl.Kd = static_cast<float>(get("pid_kd", 0.0));
        ctrl.max_flow = static_cast<float>(get("pid_max_flow", 100.0));
        ctrl.startup_time = static_cast<float>(get("pid_startup_time", 0.0));
        app->SetControllerConfig(ctrl);

        LiwRefillConfig refill;
        refill.mode = static_cast<RefillMode>(getI("refill_mode", 0));
        refill.lower_limit = static_cast<float>(get("refill_lower", 1.0));
        refill.upper_limit = static_cast<float>(get("refill_upper", 10.0));
        refill.control_mode = static_cast<RefillControlMode>(getI("refill_control_mode", 1));
        refill.control_setpoint = static_cast<float>(get("refill_setpoint", 10.0));
        refill.stabilize_time = static_cast<float>(get("refill_stabilize_time", 10.0));
        app->SetRefillConfig(refill);

        LiwTargetValuesConfig target;
        target.batch_target = static_cast<float>(get("batch_target", 1.0));
        target.in_flight = static_cast<float>(get("batch_in_flight", 0.0));
        target.fine_feed_threshold = static_cast<float>(get("batch_fine_threshold", 0.0));
        target.fine_feed_flow = static_cast<float>(get("batch_fine_flow", 2.0));
        app->SetTargetValuesConfig(target);

        LiwToleranceCheckConfig tol;
        tol.pre_check_delay = static_cast<float>(get("tolerance_delay", 0.0));
        tol.stability_timeout = static_cast<float>(get("tolerance_timeout", 0.0));
        tol.tolerance = static_cast<float>(get("tolerance_value", 0.0));
        app->SetToleranceCheckConfig(tol);

        LiwEmptyingConfig empty;
        empty.auto_stop_at_alarm = getI("emptying_auto_stop", 1) != 0;
        empty.control_setpoint = static_cast<float>(get("emptying_setpoint", 10.0));
        app->SetEmptyingConfig(empty);

        LiwWarningConfig warn;
        warn.control_rate_lower = static_cast<float>(get("warning_rate_lower", 20.0));
        warn.control_rate_upper = static_cast<float>(get("warning_rate_upper", 80.0));
        warn.refill_timeout = static_cast<float>(get("warning_refill_timeout", 10.0));
        warn.stop_on_error = getI("warning_stop_on_error", 0) != 0;
        app->SetWarningConfig(warn);

        LiwFlowMonitorConfig flowm;
        flowm.evaluation_window = static_cast<float>(get("flow_eval_window", 3.0));
        flowm.deviation_threshold = static_cast<float>(get("flow_deviation", 10.0));
        flowm.surge_threshold = static_cast<float>(get("flow_surge", 150.0));
        app->SetFlowMonitorConfig(flowm);

        LiwAdvancedConfig advc;
        advc.interlock_enabled = getI("interlock_enabled", 0) != 0;
        advc.interlock_delay = static_cast<float>(get("interlock_delay", 0.0));
        app->SetAdvancedConfig(advc);

        LiwStatsConfig statsc;
        statsc.sample_period = static_cast<float>(get("stats_sample_period", 60.0));
        statsc.sample_tolerance = static_cast<float>(get("stats_sample_tolerance", 10.0));
        app->SetStatsConfig(statsc); });

		return found;
	}

	bool ConfigStore::SaveFillingConfig(uint32_t subsystem_id, const FillingApplication *app)
	{
		if (!app)
			return false;
		auto &db = DatabaseManager::Instance();

		auto gen = app->GetGeneralConfig();
		auto sys = app->GetSystemConfig();
		auto tgt = app->GetTargetConfig();
		auto at = app->GetAutoTareConfig();
		auto tol = app->GetToleranceConfig();
		auto so = app->GetSpillOptConfig();
		auto co = app->GetCutoffOptConfig();
		auto jog = app->GetJogConfig();
		auto ref = app->GetRefillConfig();
		auto emp = app->GetEmptyingConfig();
		auto evt = app->GetEventsConfig();
		auto adv = app->GetAdvancedConfig();

		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO filling_config (subsystem_id,"
			<< "power_fail_recovery,start_delay,work_mode,feed_speed,"
			<< "target_value,in_flight,feed,feed_inhibit_time,fast_feed_inhibit_time,"
			<< "auto_tare_enabled,container_tare_upper,container_tare_lower,"
			<< "tolerance_delay,tolerance_timeout,tolerance_positive,tolerance_negative,"
			<< "spill_opt_mode,spill_opt_range,spill_opt_samples,spill_opt_factor,"
			<< "cutoff_opt_mode,cutoff_opt_range,cutoff_opt_cycles,cutoff_opt_factor,"
			<< "jog_mode,jog_duration,jog_pause,jog_max_cycles,"
			<< "refill_upper,refill_lower,"
			<< "emptying_mode,emptying_residual,emptying_time,"
			<< "event_feed_timeout,event_emptying_timeout,event_refill_timeout,event_process_timeout,"
			<< "cycle_confirm,fast_recovery,interlock_enabled,"
			<< "fast_feed_speed,fine_feed_speed) VALUES ("
			<< subsystem_id << ","
			<< static_cast<int>(gen.power_fail_recovery) << "," << static_cast<int>(gen.start_delay) << ","
			<< static_cast<int>(sys.work_mode) << "," << static_cast<int>(sys.feed_speed) << ","
			<< tgt.target_value << "," << tgt.in_flight << "," << tgt.feed << ","
			<< tgt.feed_inhibit_time << "," << tgt.fast_feed_inhibit_time << ","
			<< (at.auto_tare_enabled ? 1 : 0) << "," << at.container_tare_upper << "," << at.container_tare_lower << ","
			<< tol.pre_check_delay << "," << tol.stability_timeout << "," << tol.positive_tolerance << "," << tol.negative_tolerance << ","
			<< static_cast<int>(so.mode) << "," << so.adjust_range << "," << so.adjust_samples << "," << so.adjust_factor << ","
			<< static_cast<int>(co.mode) << "," << co.control_reliability_range << "," << co.adjust_cycles << "," << co.adjust_factor << ","
			<< static_cast<int>(jog.mode) << "," << jog.jog_duration << "," << jog.jog_pause_time << "," << jog.max_cycles << ","
			<< ref.upper_limit << "," << ref.lower_limit << ","
			<< static_cast<int>(emp.complete_mode) << "," << emp.residual_weight << "," << emp.completion_time << ","
			<< evt.initial_feed_timeout << "," << evt.emptying_timeout << "," << evt.refill_timeout << "," << evt.process_timeout << ","
			<< static_cast<int>(adv.cycle_confirm) << "," << static_cast<int>(adv.fast_recovery) << ","
			<< (adv.interlock_enabled ? 1 : 0) << ","
			<< adv.fast_feed_speed << "," << adv.fine_feed_speed << ")";

		return db.Execute(sql.str());
	}

	bool ConfigStore::LoadFillingConfig(uint32_t subsystem_id, FillingApplication *app)
	{
		if (!app)
			return false;
		auto &db = DatabaseManager::Instance();

		std::string sql = "SELECT * FROM filling_config WHERE subsystem_id = " +
						  std::to_string(subsystem_id);
		bool found = false;

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
        found = true;
        auto get = [&](const std::string& key, double def) -> double {
            auto it = row.find(key); return (it != row.end() && !it->second.empty()) ? std::stod(it->second) : def;
        };
        auto getI = [&](const std::string& key, int def) -> int {
            auto it = row.find(key); return (it != row.end() && !it->second.empty()) ? std::stoi(it->second) : def;
        };

        FillingGeneralConfig gen;
        gen.power_fail_recovery = static_cast<PowerFailRecovery>(getI("power_fail_recovery", 0));
        gen.start_delay = static_cast<PowerFailStartDelay>(getI("start_delay", 0));
        app->SetGeneralConfig(gen);

        FillingSystemConfig sys;
        sys.work_mode = static_cast<FillingWorkMode>(getI("work_mode", 0));
        sys.feed_speed = static_cast<FeedSpeed>(getI("feed_speed", 1));
        app->SetSystemConfig(sys);

        FillingTargetConfig tgt;
        tgt.target_value = get("target_value", 1.0);
        tgt.in_flight = get("in_flight", 0.0);
        tgt.feed = get("feed", 0.0);
        tgt.feed_inhibit_time = get("feed_inhibit_time", 0.0);
        tgt.fast_feed_inhibit_time = get("fast_feed_inhibit_time", 0.0);
        app->SetTargetConfig(tgt);

        FillingAutoTareConfig at;
        at.auto_tare_enabled = getI("auto_tare_enabled", 0) != 0;
        at.container_tare_upper = get("container_tare_upper", 0.0);
        at.container_tare_lower = get("container_tare_lower", 0.0);
        app->SetAutoTareConfig(at);

        FillingToleranceConfig tol;
        tol.pre_check_delay = get("tolerance_delay", 0.0);
        tol.stability_timeout = get("tolerance_timeout", 0.0);
        tol.positive_tolerance = get("tolerance_positive", 0.0);
        tol.negative_tolerance = get("tolerance_negative", 0.0);
        app->SetToleranceConfig(tol);

        FillingSpillOptConfig so;
        so.mode = static_cast<SpillOptMode>(getI("spill_opt_mode", 0));
        so.adjust_range = get("spill_opt_range", 0.0);
        so.adjust_samples = getI("spill_opt_samples", 5);
        so.adjust_factor = get("spill_opt_factor", 0.5);
        app->SetSpillOptConfig(so);

        FillingCutoffOptConfig co;
        co.mode = static_cast<CutoffOptMode>(getI("cutoff_opt_mode", 0));
        co.control_reliability_range = get("cutoff_opt_range", 0.0);
        co.adjust_cycles = getI("cutoff_opt_cycles", 5);
        co.adjust_factor = get("cutoff_opt_factor", 0.5);
        app->SetCutoffOptConfig(co);

        FillingJogConfig jog;
        jog.mode = static_cast<JogMode>(getI("jog_mode", 0));
        jog.jog_duration = get("jog_duration", 0.5);
        jog.jog_pause_time = get("jog_pause", 1.0);
        jog.max_cycles = getI("jog_max_cycles", 3);
        app->SetJogConfig(jog);

        FillingRefillConfig ref;
        ref.upper_limit = get("refill_upper", 10.0);
        ref.lower_limit = get("refill_lower", 1.0);
        app->SetRefillConfig(ref);

        FillingEmptyingConfig emp;
        emp.complete_mode = static_cast<EmptyingCompleteMode>(getI("emptying_mode", 0));
        emp.residual_weight = get("emptying_residual", 0.1);
        emp.completion_time = get("emptying_time", 5.0);
        app->SetEmptyingConfig(emp);

        FillingEventsConfig evt;
        evt.initial_feed_timeout = get("event_feed_timeout", 30.0);
        evt.emptying_timeout = get("event_emptying_timeout", 60.0);
        evt.refill_timeout = get("event_refill_timeout", 60.0);
        evt.process_timeout = get("event_process_timeout", 120.0);
        app->SetEventsConfig(evt);

        FillingAdvancedConfig adv;
        adv.cycle_confirm = static_cast<CycleResultConfirm>(getI("cycle_confirm", 0));
        adv.fast_recovery = static_cast<FastRecovery>(getI("fast_recovery", 0));
        adv.interlock_enabled = getI("interlock_enabled", 0) != 0;
        adv.fast_feed_speed = get("fast_feed_speed", 100.0);
        adv.fine_feed_speed = get("fine_feed_speed", 30.0);
        app->SetAdvancedConfig(adv); });

		return found;
	}

	bool ConfigStore::SaveSubsystemConfig(const SubsystemConfig &config)
	{
		auto &db = DatabaseManager::Instance();
		std::ostringstream scale_ids_str, slave_ids_str;
		for (size_t i = 0; i < config.scale_ids.size(); i++)
		{
			if (i > 0)
				scale_ids_str << ",";
			scale_ids_str << config.scale_ids[i];
		}
		for (size_t i = 0; i < config.ethercat_slave_ids.size(); i++)
		{
			if (i > 0)
				slave_ids_str << ",";
			slave_ids_str << config.ethercat_slave_ids[i];
		}

		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO subsystem_config "
			<< "(subsystem_id, name, app_type, scale_ids, slave_ids, "
			<< "digital_io_pos, servo_pos, material_name, material_code, "
			<< "priority, enabled, register_to_central) VALUES ("
			<< config.id << ",'" << config.name << "',"
			<< static_cast<int>(config.app_type) << ",'"
			<< scale_ids_str.str() << "','" << slave_ids_str.str() << "',"
			<< config.digital_io_pos << "," << config.servo_pos << ",'"
			<< config.material_name << "','" << config.material_code << "',"
			<< config.priority << "," << (config.enabled ? 1 : 0) << ","
			<< (config.register_to_central ? 1 : 0) << ")";

		return db.Execute(sql.str());
	}

	bool ConfigStore::LoadSubsystemConfig(uint32_t subsystem_id, SubsystemConfig &config)
	{
		auto &db = DatabaseManager::Instance();
		std::string sql = "SELECT * FROM subsystem_config WHERE subsystem_id = " +
						  std::to_string(subsystem_id);
		bool found = false;

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
        found = true;
        config.id = subsystem_id;
        auto it = row.find("name");
        if (it != row.end()) config.name = it->second;

        it = row.find("app_type");
        if (it != row.end()) config.app_type = static_cast<AppType>(std::stoi(it->second));

        // Parse comma-separated scale IDs
        it = row.find("scale_ids");
        if (it != row.end() && !it->second.empty()) {
            std::istringstream ss(it->second);
            std::string token;
            while (std::getline(ss, token, ',')) {
                if (!token.empty()) config.scale_ids.push_back(std::stoul(token));
            }
        }

        it = row.find("slave_ids");
        if (it != row.end() && !it->second.empty()) {
            std::istringstream ss(it->second);
            std::string token;
            while (std::getline(ss, token, ',')) {
                if (!token.empty()) config.ethercat_slave_ids.push_back(std::stoul(token));
            }
        }

		// 新增字段
		it = row.find("digital_io_pos");
		if (it != row.end() && !it->second.empty())
			config.digital_io_pos = std::stoul(it->second);

		it = row.find("servo_pos");
		if (it != row.end() && !it->second.empty())
			config.servo_pos = std::stoul(it->second);

		it = row.find("material_name");
		if (it != row.end())
			config.material_name = it->second;

		it = row.find("material_code");
		if (it != row.end())
			config.material_code = it->second;

		it = row.find("priority");
		if (it != row.end() && !it->second.empty())
			config.priority = std::stoi(it->second);

		it = row.find("enabled");
		if (it != row.end() && !it->second.empty())
			config.enabled = (std::stoi(it->second) != 0);

		it = row.find("register_to_central");
		if (it != row.end() && !it->second.empty())
			config.register_to_central = (std::stoi(it->second) != 0); });

		return found;
	}

	std::vector<SubsystemConfig> ConfigStore::LoadAllSubsystemConfigs()
	{
		std::vector<SubsystemConfig> configs;
		auto &db = DatabaseManager::Instance();

		db.Query("SELECT * FROM subsystem_config", [&](const std::map<std::string, std::string> &row)
				 {
        SubsystemConfig cfg;
        auto it = row.find("subsystem_id");
        if (it != row.end()) cfg.id = std::stoul(it->second);

        it = row.find("name");
        if (it != row.end()) cfg.name = it->second;

        it = row.find("app_type");
        if (it != row.end()) cfg.app_type = static_cast<AppType>(std::stoi(it->second));

        it = row.find("scale_ids");
        if (it != row.end() && !it->second.empty()) {
            std::istringstream ss(it->second);
            std::string token;
            while (std::getline(ss, token, ',')) {
                if (!token.empty()) cfg.scale_ids.push_back(std::stoul(token));
            }
        }

        it = row.find("slave_ids");
        if (it != row.end() && !it->second.empty()) {
            std::istringstream ss(it->second);
            std::string token;
            while (std::getline(ss, token, ',')) {
                if (!token.empty()) cfg.ethercat_slave_ids.push_back(std::stoul(token));
            }
        }

		// 新增字段
		it = row.find("digital_io_pos");
		if (it != row.end() && !it->second.empty())
			cfg.digital_io_pos = std::stoul(it->second);

		it = row.find("servo_pos");
		if (it != row.end() && !it->second.empty())
			cfg.servo_pos = std::stoul(it->second);

		it = row.find("material_name");
		if (it != row.end())
			cfg.material_name = it->second;

		it = row.find("material_code");
		if (it != row.end())
			cfg.material_code = it->second;

		it = row.find("priority");
		if (it != row.end() && !it->second.empty())
			cfg.priority = std::stoi(it->second);

		it = row.find("enabled");
		if (it != row.end() && !it->second.empty())
			cfg.enabled = (std::stoi(it->second) != 0);

		it = row.find("register_to_central");
		if (it != row.end() && !it->second.empty())
			cfg.register_to_central = (std::stoi(it->second) != 0);

        configs.push_back(cfg); });

		return configs;
	}

	// ============================================================================
	// 加载所有秤台 ID（从 scale_config 表查询）
	// ============================================================================
	std::vector<uint32_t> ConfigStore::LoadAllScaleIds()
	{
		std::vector<uint32_t> ids;
		auto &db = DatabaseManager::Instance();

		db.Query("SELECT scale_id FROM scale_config ORDER BY scale_id",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("scale_id");
					 if (it != row.end() && !it->second.empty())
					 {
						 ids.push_back(static_cast<uint32_t>(std::stoul(it->second)));
					 }
				 });

		return ids;
	}

	// ============================================================================
	// 加载应用类型（从 subsystem_config 表查询）
	// ============================================================================
	AppType ConfigStore::LoadAppType(uint32_t subsystem_id)
	{
		auto &db = DatabaseManager::Instance();
		AppType type = AppType::kLossInWeight; // 默认值

		std::string sql = "SELECT app_type FROM subsystem_config WHERE subsystem_id = " +
						  std::to_string(subsystem_id);

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("app_type");
					 if (it != row.end() && !it->second.empty())
					 {
						 type = static_cast<AppType>(std::stoi(it->second));
					 } });

		return type;
	}

	// 配方管理
	// ============================================================================

	bool ConfigStore::SaveRecipe(const Recipe &recipe)
	{
		auto &db = DatabaseManager::Instance();

		// 保存主配方
		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO recipe "
			<< "(recipe_id, name, total_target_flow, enable_stagger_refill, refill_interval_min) "
			<< "VALUES (" << recipe.recipe_id << ", '" << recipe.name << "', "
			<< recipe.total_target_flow << ", " << (recipe.enable_stagger_refill ? 1 : 0) << ", "
			<< recipe.refill_interval_min << ")";

		if (!db.Execute(sql.str()))
		{
			fprintf(stderr, "ConfigStore: Failed to save recipe %u\n", recipe.recipe_id);
			return false;
		}

		// 删除旧的明细
		std::string del_sql = "DELETE FROM recipe_detail WHERE recipe_id = " +
							  std::to_string(recipe.recipe_id);
		db.Execute(del_sql);

		// 保存明细
		for (const auto &[sub_id, ratio] : recipe.subsystem_ratios)
		{
			std::ostringstream detail_sql;
			detail_sql << "INSERT INTO recipe_detail (recipe_id, subsystem_id, flow_ratio) "
					   << "VALUES (" << recipe.recipe_id << ", " << sub_id << ", " << ratio << ")";

			if (!db.Execute(detail_sql.str()))
			{
				fprintf(stderr, "ConfigStore: Failed to save recipe detail for subsystem %u\n", sub_id);
				return false;
			}
		}

		printf("ConfigStore: Saved recipe %u (%s)\n", recipe.recipe_id, recipe.name.c_str());
		return true;
	}

	Recipe ConfigStore::LoadRecipe(uint32_t recipe_id)
	{
		auto &db = DatabaseManager::Instance();
		Recipe recipe;
		bool found = false;

		// 加载主配方
		std::string sql = "SELECT * FROM recipe WHERE recipe_id = " + std::to_string(recipe_id);

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
            found = true;
            recipe.recipe_id = recipe_id;
            
            auto it = row.find("name");
            if (it != row.end()) recipe.name = it->second;
            
            it = row.find("total_target_flow");
            if (it != row.end() && !it->second.empty())
                recipe.total_target_flow = std::stod(it->second);
            
            it = row.find("enable_stagger_refill");
            if (it != row.end() && !it->second.empty())
                recipe.enable_stagger_refill = (std::stoi(it->second) != 0);
            
            it = row.find("refill_interval_min");
            if (it != row.end() && !it->second.empty())
                recipe.refill_interval_min = std::stod(it->second);
            
            it = row.find("created_at");
            if (it != row.end()) recipe.created_at = it->second;
            
            it = row.find("updated_at");
            if (it != row.end()) recipe.updated_at = it->second; });

		if (!found)
			return recipe;

		// 加载明细
		std::string detail_sql = "SELECT * FROM recipe_detail WHERE recipe_id = " +
								 std::to_string(recipe_id);

		db.Query(detail_sql, [&](const std::map<std::string, std::string> &row)
				 {
            uint32_t sub_id = 0;
            double ratio = 0.0;
            
            auto it = row.find("subsystem_id");
            if (it != row.end() && !it->second.empty())
                sub_id = std::stoul(it->second);
            
            it = row.find("flow_ratio");
            if (it != row.end() && !it->second.empty())
                ratio = std::stod(it->second);
            
            if (sub_id > 0)
                recipe.subsystem_ratios[sub_id] = ratio; });

		return recipe;
	}

	std::vector<Recipe> ConfigStore::LoadAllRecipes()
	{
		std::vector<Recipe> recipes;
		auto &db = DatabaseManager::Instance();

		db.Query("SELECT recipe_id FROM recipe ORDER BY recipe_id",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("recipe_id");
					 if (it != row.end() && !it->second.empty())
					 {
						 uint32_t id = std::stoul(it->second);
						 recipes.push_back(LoadRecipe(id));
					 }
				 });

		return recipes;
	}

	bool ConfigStore::DeleteRecipe(uint32_t recipe_id)
	{
		auto &db = DatabaseManager::Instance();

		// 删除明细（外键级联会自动删除）
		std::string del_detail = "DELETE FROM recipe_detail WHERE recipe_id = " +
								 std::to_string(recipe_id);
		db.Execute(del_detail);

		// 删除主配方
		std::string del_recipe = "DELETE FROM recipe WHERE recipe_id = " +
								 std::to_string(recipe_id);
		bool ok = db.Execute(del_recipe);

		if (ok)
			printf("ConfigStore: Deleted recipe %u\n", recipe_id);
		else
			fprintf(stderr, "ConfigStore: Failed to delete recipe %u\n", recipe_id);

		return ok;
	}

	// ============================================================================
	// 批次追溯
	// ============================================================================

	uint32_t ConfigStore::StartBatch(uint32_t recipe_id, const std::string &operator_name)
	{
		auto &db = DatabaseManager::Instance();

		std::ostringstream sql;
		sql << "INSERT INTO batch_trace (recipe_id, start_time, operator_name, status) "
			<< "VALUES (" << recipe_id << ", datetime('now'), '" << operator_name << "', 'running')";

		if (!db.Execute(sql.str()))
		{
			fprintf(stderr, "ConfigStore: Failed to start batch\n");
			return 0;
		}

		// 获取插入的 batch_id
		uint32_t batch_id = 0;
		db.Query("SELECT last_insert_rowid() as id",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("id");
					 if (it != row.end() && !it->second.empty())
						 batch_id = std::stoul(it->second);
				 });

		printf("ConfigStore: Started batch %u (recipe %u)\n", batch_id, recipe_id);
		return batch_id;
	}

	bool ConfigStore::EndBatch(uint32_t batch_id, double total_weight)
	{
		auto &db = DatabaseManager::Instance();

		std::ostringstream sql;
		sql << "UPDATE batch_trace SET end_time = datetime('now'), "
			<< "total_weight = " << total_weight << ", status = 'completed' "
			<< "WHERE batch_id = " << batch_id;

		bool ok = db.Execute(sql.str());

		if (ok)
			printf("ConfigStore: Ended batch %u (total: %.2f kg)\n", batch_id, total_weight);
		else
			fprintf(stderr, "ConfigStore: Failed to end batch %u\n", batch_id);

		return ok;
	}

	bool ConfigStore::UpdateBatchDetail(uint32_t batch_id, uint32_t subsystem_id,
										double target_flow, double actual_flow_avg,
										double accumulated_weight, int refill_count)
	{
		auto &db = DatabaseManager::Instance();

		std::ostringstream sql;
		sql << "INSERT OR REPLACE INTO batch_detail "
			<< "(batch_id, subsystem_id, target_flow, actual_flow_avg, accumulated_weight, refill_count) "
			<< "VALUES (" << batch_id << ", " << subsystem_id << ", "
			<< target_flow << ", " << actual_flow_avg << ", "
			<< accumulated_weight << ", " << refill_count << ")";

		return db.Execute(sql.str());
	}

	std::vector<BatchTrace> ConfigStore::QueryBatches(const std::string &start_date,
													  const std::string &end_date)
	{
		std::vector<BatchTrace> batches;
		auto &db = DatabaseManager::Instance();

		std::ostringstream sql;
		sql << "SELECT * FROM batch_trace WHERE start_time >= '" << start_date
			<< "' AND start_time <= '" << end_date << "' ORDER BY batch_id DESC";

		db.Query(sql.str(), [&](const std::map<std::string, std::string> &row)
				 {
            BatchTrace batch;
            
            auto it = row.find("batch_id");
            if (it != row.end() && !it->second.empty())
                batch.batch_id = std::stoul(it->second);
            
            it = row.find("recipe_id");
            if (it != row.end() && !it->second.empty())
                batch.recipe_id = std::stoul(it->second);
            
            it = row.find("start_time");
            if (it != row.end()) batch.start_time = it->second;
            
            it = row.find("end_time");
            if (it != row.end()) batch.end_time = it->second;
            
            it = row.find("total_weight");
            if (it != row.end() && !it->second.empty())
                batch.total_weight = std::stod(it->second);
            
            it = row.find("status");
            if (it != row.end()) batch.status = it->second;
            
            it = row.find("operator_name");
            if (it != row.end()) batch.operator_name = it->second;
            
            it = row.find("notes");
            if (it != row.end()) batch.notes = it->second;
            
            batches.push_back(batch); });

		return batches;
	}

	// ============================================================================
	// 物料配方管理
	// ============================================================================

	uint32_t ConfigStore::SaveLiwMaterialRecipe(uint32_t subsystem_id,
												const std::string &name,
												const LiwApplication *app)
	{
		auto &db = DatabaseManager::Instance();

		// 1. 在 material_recipe 插入元数据，获取 recipe_id
		std::ostringstream meta_sql;
		meta_sql << "INSERT INTO material_recipe (name, app_type, subsystem_id) VALUES ('"
				 << name << "', 0, " << subsystem_id << ")";
		if (!db.Execute(meta_sql.str()))
			return 0;

		uint32_t recipe_id = 0;
		db.Query("SELECT last_insert_rowid() as id",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("id");
					 if (it != row.end() && !it->second.empty())
						 recipe_id = std::stoul(it->second);
				 });
		if (recipe_id == 0)
			return 0;

		// 2. 从应用对象读取所有 LIW 配置，写入 material_recipe_liw
		auto base = app->GetBaseConfig();
		auto sys = app->GetSystemConfig();
		auto sysid = app->GetSystemIdConfig();
		auto ctrl = app->GetControllerConfig();
		auto refill = app->GetRefillConfig();
		auto target = app->GetTargetValuesConfig();
		auto tol = app->GetToleranceCheckConfig();
		auto empty = app->GetEmptyingConfig();
		auto warn = app->GetWarningConfig();
		auto flow_mon = app->GetFlowMonitorConfig();
		auto adv = app->GetAdvancedConfig();
		auto stats = app->GetStatsConfig();

		std::ostringstream sql;
		sql << "INSERT INTO material_recipe_liw VALUES ("
			<< recipe_id << ","
			<< static_cast<int>(base.mode) << "," << static_cast<int>(base.sub_mode) << ","
			<< sys.safety_limit << "," << sys.hopper_min << "," << sys.hopper_max << ","
			<< sys.target_flow << "," << sys.target_control_rate << "," << (sys.pre_refill ? 1 : 0) << ","
			<< sysid.adjust_range_lower << "," << sysid.adjust_range_upper << ","
			<< (sysid.smart_step_control ? 1 : 0) << "," << sysid.step_duration << "," << sysid.filter_window << ","
			<< static_cast<int>(ctrl.tuning_mode) << "," << ctrl.filter_window << ","
			<< ctrl.Kp << "," << ctrl.Ki << "," << ctrl.Kd << "," << ctrl.max_flow << "," << ctrl.startup_time << ","
			<< static_cast<int>(refill.mode) << "," << refill.lower_limit << "," << refill.upper_limit << ","
			<< static_cast<int>(refill.control_mode) << "," << refill.control_setpoint << "," << refill.stabilize_time << ","
			<< target.batch_target << "," << target.in_flight << "," << target.fine_feed_threshold << "," << target.fine_feed_flow << ","
			<< tol.pre_check_delay << "," << tol.stability_timeout << "," << tol.tolerance << ","
			<< (empty.auto_stop_at_alarm ? 1 : 0) << "," << empty.control_setpoint << ","
			<< warn.control_rate_lower << "," << warn.control_rate_upper << "," << warn.refill_timeout << "," << (warn.stop_on_error ? 1 : 0) << ","
			<< flow_mon.evaluation_window << "," << flow_mon.deviation_threshold << "," << flow_mon.surge_threshold << ","
			<< (adv.interlock_enabled ? 1 : 0) << "," << adv.interlock_delay << ","
			<< stats.sample_period << "," << stats.sample_tolerance
			<< ")";

		if (!db.Execute(sql.str()))
		{
			// 回滚元数据
			db.Execute("DELETE FROM material_recipe WHERE recipe_id = " + std::to_string(recipe_id));
			return 0;
		}

		return recipe_id;
	}

	uint32_t ConfigStore::SaveFillingMaterialRecipe(uint32_t subsystem_id,
													const std::string &name,
													const FillingApplication *app)
	{
		auto &db = DatabaseManager::Instance();

		std::ostringstream meta_sql;
		meta_sql << "INSERT INTO material_recipe (name, app_type, subsystem_id) VALUES ('"
				 << name << "', 1, " << subsystem_id << ")";
		if (!db.Execute(meta_sql.str()))
			return 0;

		uint32_t recipe_id = 0;
		db.Query("SELECT last_insert_rowid() as id",
				 [&](const std::map<std::string, std::string> &row)
				 {
					 auto it = row.find("id");
					 if (it != row.end() && !it->second.empty())
						 recipe_id = std::stoul(it->second);
				 });
		if (recipe_id == 0)
			return 0;

		auto gen = app->GetGeneralConfig();
		auto sys = app->GetSystemConfig();
		auto tgt = app->GetTargetConfig();
		auto tare = app->GetAutoTareConfig();
		auto tol = app->GetToleranceConfig();
		auto spill = app->GetSpillOptConfig();
		auto cutoff = app->GetCutoffOptConfig();
		auto jog = app->GetJogConfig();
		auto refill = app->GetRefillConfig();
		auto empty = app->GetEmptyingConfig();
		auto evt = app->GetEventsConfig();
		auto adv = app->GetAdvancedConfig();

		std::ostringstream sql;
		sql << "INSERT INTO material_recipe_filling VALUES ("
			<< recipe_id << ","
			<< static_cast<int>(gen.power_fail_recovery) << "," << static_cast<int>(gen.start_delay) << ","
			<< static_cast<int>(sys.work_mode) << "," << static_cast<int>(sys.feed_speed) << ","
			<< tgt.target_value << "," << tgt.in_flight << "," << tgt.feed << ","
			<< tgt.feed_inhibit_time << "," << tgt.fast_feed_inhibit_time << ","
			<< (tare.auto_tare_enabled ? 1 : 0) << "," << tare.container_tare_upper << "," << tare.container_tare_lower << ","
			<< tol.pre_check_delay << "," << tol.stability_timeout << "," << tol.positive_tolerance << "," << tol.negative_tolerance << ","
			<< static_cast<int>(spill.mode) << "," << spill.adjust_range << "," << spill.adjust_samples << "," << spill.adjust_factor << ","
			<< static_cast<int>(cutoff.mode) << "," << cutoff.control_reliability_range << "," << cutoff.adjust_cycles << "," << cutoff.adjust_factor << ","
			<< static_cast<int>(jog.mode) << "," << jog.jog_duration << "," << jog.jog_pause_time << "," << jog.max_cycles << ","
			<< refill.upper_limit << "," << refill.lower_limit << ","
			<< static_cast<int>(empty.complete_mode) << "," << empty.residual_weight << "," << empty.completion_time << ","
			<< evt.initial_feed_timeout << "," << evt.emptying_timeout << "," << evt.refill_timeout << "," << evt.process_timeout << ","
			<< static_cast<int>(adv.cycle_confirm) << "," << static_cast<int>(adv.fast_recovery) << ","
			<< (adv.interlock_enabled ? 1 : 0) << "," << adv.fast_feed_speed << "," << adv.fine_feed_speed
			<< ")";

		if (!db.Execute(sql.str()))
		{
			db.Execute("DELETE FROM material_recipe WHERE recipe_id = " + std::to_string(recipe_id));
			return 0;
		}

		return recipe_id;
	}

	bool ConfigStore::LoadLiwMaterialRecipe(uint32_t recipe_id, LiwApplication *app)
	{
		auto &db = DatabaseManager::Instance();
		bool found = false;

		std::string sql = "SELECT * FROM material_recipe_liw WHERE recipe_id = " +
						  std::to_string(recipe_id);

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
			found = true;
			auto get = [&](const std::string &key, double def) -> double {
				auto it = row.find(key);
				if (it != row.end() && !it->second.empty()) return std::stod(it->second);
				return def;
			};
			auto getI = [&](const std::string &key, int def) -> int {
				auto it = row.find(key);
				if (it != row.end() && !it->second.empty()) return std::stoi(it->second);
				return def;
			};

			LiwBaseConfig base;
			base.mode = static_cast<LiwMode>(getI("mode", 0));
			base.sub_mode = static_cast<LiwSubMode>(getI("sub_mode", 0));
			app->SetBaseConfig(base);

			LiwSystemConfig sys;
			sys.safety_limit = static_cast<float>(get("safety_limit", 100.0));
			sys.hopper_min = static_cast<float>(get("hopper_min", 0.0));
			sys.hopper_max = static_cast<float>(get("hopper_max", 15.0));
			sys.target_flow = static_cast<float>(get("target_flow", 10.0));
			sys.target_control_rate = static_cast<float>(get("target_control_rate", 10.0));
			sys.pre_refill = getI("pre_refill", 0) != 0;
			app->SetSystemConfig(sys);

			LiwSystemIdConfig sysid;
			sysid.adjust_range_lower = static_cast<float>(get("sysid_lower", 0.0));
			sysid.adjust_range_upper = static_cast<float>(get("sysid_upper", 90.0));
			sysid.smart_step_control = getI("sysid_smart", 0) != 0;
			sysid.step_duration = static_cast<float>(get("sysid_step_duration", 10.0));
			sysid.filter_window = static_cast<float>(get("sysid_filter_window", 0.5));
			app->SetSystemIdConfig(sysid);

			LiwControllerConfig ctrl;
			ctrl.tuning_mode = static_cast<PidTuningMode>(getI("pid_tuning_mode", 1));
			ctrl.filter_window = static_cast<float>(get("pid_filter_window", 0.5));
			ctrl.Kp = static_cast<float>(get("pid_kp", 1.0));
			ctrl.Ki = static_cast<float>(get("pid_ki", 1.0));
			ctrl.Kd = static_cast<float>(get("pid_kd", 0.0));
			ctrl.max_flow = static_cast<float>(get("pid_max_flow", 100.0));
			ctrl.startup_time = static_cast<float>(get("pid_startup_time", 0.0));
			app->SetControllerConfig(ctrl);

			LiwRefillConfig refill;
			refill.mode = static_cast<RefillMode>(getI("refill_mode", 0));
			refill.lower_limit = static_cast<float>(get("refill_lower", 1.0));
			refill.upper_limit = static_cast<float>(get("refill_upper", 10.0));
			refill.control_mode = static_cast<RefillControlMode>(getI("refill_control_mode", 1));
			refill.control_setpoint = static_cast<float>(get("refill_setpoint", 10.0));
			refill.stabilize_time = static_cast<float>(get("refill_stabilize_time", 10.0));
			app->SetRefillConfig(refill);

			LiwTargetValuesConfig target;
			target.batch_target = static_cast<float>(get("batch_target", 1.0));
			target.in_flight = static_cast<float>(get("batch_in_flight", 0.0));
			target.fine_feed_threshold = static_cast<float>(get("batch_fine_threshold", 0.0));
			target.fine_feed_flow = static_cast<float>(get("batch_fine_flow", 2.0));
			app->SetTargetValuesConfig(target);

			LiwToleranceCheckConfig tol;
			tol.pre_check_delay = static_cast<float>(get("tolerance_delay", 0.0));
			tol.stability_timeout = static_cast<float>(get("tolerance_timeout", 0.0));
			tol.tolerance = static_cast<float>(get("tolerance_value", 0.0));
			app->SetToleranceCheckConfig(tol);

			LiwEmptyingConfig empty;
			empty.auto_stop_at_alarm = getI("emptying_auto_stop", 1) != 0;
			empty.control_setpoint = static_cast<float>(get("emptying_setpoint", 10.0));
			app->SetEmptyingConfig(empty);

			LiwWarningConfig warn;
			warn.control_rate_lower = static_cast<float>(get("warning_rate_lower", 20.0));
			warn.control_rate_upper = static_cast<float>(get("warning_rate_upper", 80.0));
			warn.refill_timeout = static_cast<float>(get("warning_refill_timeout", 10.0));
			warn.stop_on_error = getI("warning_stop_on_error", 0) != 0;
			app->SetWarningConfig(warn);

			LiwFlowMonitorConfig fm;
			fm.evaluation_window = static_cast<float>(get("flow_eval_window", 3.0));
			fm.deviation_threshold = static_cast<float>(get("flow_deviation", 10.0));
			fm.surge_threshold = static_cast<float>(get("flow_surge", 150.0));
			app->SetFlowMonitorConfig(fm);

			LiwAdvancedConfig adv;
			adv.interlock_enabled = getI("interlock_enabled", 0) != 0;
			adv.interlock_delay = static_cast<float>(get("interlock_delay", 0.0));
			app->SetAdvancedConfig(adv);

			LiwStatsConfig stats;
			stats.sample_period = static_cast<float>(get("stats_sample_period", 60.0));
			stats.sample_tolerance = static_cast<float>(get("stats_sample_tolerance", 10.0));
			app->SetStatsConfig(stats); });

		return found;
	}

	bool ConfigStore::LoadFillingMaterialRecipe(uint32_t recipe_id, FillingApplication *app)
	{
		auto &db = DatabaseManager::Instance();
		bool found = false;

		std::string sql = "SELECT * FROM material_recipe_filling WHERE recipe_id = " +
						  std::to_string(recipe_id);

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
			found = true;
			auto get = [&](const std::string &key, double def) -> double {
				auto it = row.find(key);
				if (it != row.end() && !it->second.empty()) return std::stod(it->second);
				return def;
			};
			auto getI = [&](const std::string &key, int def) -> int {
				auto it = row.find(key);
				if (it != row.end() && !it->second.empty()) return std::stoi(it->second);
				return def;
			};

			FillingGeneralConfig gen;
			gen.power_fail_recovery = static_cast<PowerFailRecovery>(getI("power_fail_recovery", 0));
			gen.start_delay = static_cast<PowerFailStartDelay>(getI("start_delay", 0));
			app->SetGeneralConfig(gen);

			FillingSystemConfig sys;
			sys.work_mode = static_cast<FillingWorkMode>(getI("work_mode", 0));
			sys.feed_speed = static_cast<FeedSpeed>(getI("feed_speed", 1));
			app->SetSystemConfig(sys);

			FillingTargetConfig tgt;
			tgt.target_value = get("target_value", 1.0);
			tgt.in_flight = get("in_flight", 0.0);
			tgt.feed = get("feed", 0.0);
			tgt.feed_inhibit_time = get("feed_inhibit_time", 0.0);
			tgt.fast_feed_inhibit_time = get("fast_feed_inhibit_time", 0.0);
			app->SetTargetConfig(tgt);

			FillingAutoTareConfig tare;
			tare.auto_tare_enabled = getI("auto_tare_enabled", 0) != 0;
			tare.container_tare_upper = get("container_tare_upper", 0.0);
			tare.container_tare_lower = get("container_tare_lower", 0.0);
			app->SetAutoTareConfig(tare);

			FillingToleranceConfig tol;
			tol.pre_check_delay = get("tolerance_delay", 0.0);
			tol.stability_timeout = get("tolerance_timeout", 0.0);
			tol.positive_tolerance = get("tolerance_positive", 0.0);
			tol.negative_tolerance = get("tolerance_negative", 0.0);
			app->SetToleranceConfig(tol);

			FillingSpillOptConfig spill;
			spill.mode = static_cast<SpillOptMode>(getI("spill_opt_mode", 0));
			spill.adjust_range = get("spill_opt_range", 0.0);
			spill.adjust_samples = getI("spill_opt_samples", 5);
			spill.adjust_factor = get("spill_opt_factor", 0.5);
			app->SetSpillOptConfig(spill);

			FillingCutoffOptConfig cutoff;
			cutoff.mode = static_cast<CutoffOptMode>(getI("cutoff_opt_mode", 0));
			cutoff.control_reliability_range = get("cutoff_opt_range", 0.0);
			cutoff.adjust_cycles = getI("cutoff_opt_cycles", 5);
			cutoff.adjust_factor = get("cutoff_opt_factor", 0.5);
			app->SetCutoffOptConfig(cutoff);

			FillingJogConfig jog;
			jog.mode = static_cast<JogMode>(getI("jog_mode", 0));
			jog.jog_duration = get("jog_duration", 0.5);
			jog.jog_pause_time = get("jog_pause", 1.0);
			jog.max_cycles = getI("jog_max_cycles", 3);
			app->SetJogConfig(jog);

			FillingRefillConfig refill;
			refill.upper_limit = get("refill_upper", 10.0);
			refill.lower_limit = get("refill_lower", 1.0);
			app->SetRefillConfig(refill);

			FillingEmptyingConfig empty;
			empty.complete_mode = static_cast<EmptyingCompleteMode>(getI("emptying_mode", 0));
			empty.residual_weight = get("emptying_residual", 0.1);
			empty.completion_time = get("emptying_time", 5.0);
			app->SetEmptyingConfig(empty);

			FillingEventsConfig evt;
			evt.initial_feed_timeout = get("event_feed_timeout", 30.0);
			evt.emptying_timeout = get("event_emptying_timeout", 60.0);
			evt.refill_timeout = get("event_refill_timeout", 60.0);
			evt.process_timeout = get("event_process_timeout", 120.0);
			app->SetEventsConfig(evt);

			FillingAdvancedConfig adv;
			adv.cycle_confirm = static_cast<CycleResultConfirm>(getI("cycle_confirm", 0));
			adv.fast_recovery = static_cast<FastRecovery>(getI("fast_recovery", 0));
			adv.interlock_enabled = getI("interlock_enabled", 0) != 0;
			adv.fast_feed_speed = get("fast_feed_speed", 100.0);
			adv.fine_feed_speed = get("fine_feed_speed", 30.0);
			app->SetAdvancedConfig(adv); });

		return found;
	}

	std::vector<MaterialRecipe> ConfigStore::GetAllMaterialRecipes(int app_type)
	{
		std::vector<MaterialRecipe> recipes;
		auto &db = DatabaseManager::Instance();

		std::string sql;
		if (app_type >= 0)
			sql = "SELECT * FROM material_recipe WHERE app_type = " +
				  std::to_string(app_type) + " ORDER BY recipe_id DESC";
		else
			sql = "SELECT * FROM material_recipe ORDER BY recipe_id DESC";

		db.Query(sql, [&](const std::map<std::string, std::string> &row)
				 {
			MaterialRecipe r;
			auto it = row.find("recipe_id");
			if (it != row.end() && !it->second.empty())
				r.recipe_id = std::stoul(it->second);
			it = row.find("name");
			if (it != row.end()) r.name = it->second;
			it = row.find("app_type");
			if (it != row.end() && !it->second.empty())
				r.app_type = std::stoi(it->second);
			it = row.find("subsystem_id");
			if (it != row.end() && !it->second.empty())
				r.subsystem_id = std::stoul(it->second);
			it = row.find("created_at");
			if (it != row.end()) r.created_at = it->second;
			recipes.push_back(r); });

		return recipes;
	}

	bool ConfigStore::DeleteMaterialRecipe(uint32_t recipe_id, int app_type)
	{
		auto &db = DatabaseManager::Instance();
		// CASCADE will remove params from material_recipe_liw / material_recipe_filling
		std::string sql = "DELETE FROM material_recipe WHERE recipe_id = " +
						  std::to_string(recipe_id) + " AND app_type = " +
						  std::to_string(app_type);
		return db.Execute(sql);
	}

} // namespace weighing
