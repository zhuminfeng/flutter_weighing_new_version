#include "system_initializer.h"
#include "../ethercat/ethercat_master.h"
#include "../input/input_factory.h"
#include "../input/ethercat_input.h"
#include "../input/shmem_input.h"
#include "../output/output_manager.h"
#include "../scale/scale_manager.h"
#include "../subsystem/subsystem_manager.h"
#include "../storage/database_manager.h"
#include "../storage/config_store.h"
#include "../storage/calibration_store.h"
#include "../central/central_controller.h"

#include <fstream>
#include <cstdio>
#include "../include/nlohmann/json.hpp"

namespace weighing
{

	SystemInitializer &SystemInitializer::Instance()
	{
		static SystemInitializer instance;
		return instance;
	}

	// ============================================================================
	// 完整初始化
	// ============================================================================
	bool SystemInitializer::Initialize(const std::string &config_path,
									   const std::string &db_path)
	{
		config_path_ = config_path;
		printf("======================================\n");
		printf("  System Initialization Start\n");
		printf("======================================\n");

		// Step 0: 解析配置文件
		if (!LoadConfig(config_path))
			return false;
		printf("  Input mode: %s\n", input_mode_.c_str());

		// Step 1: 初始化 EtherCAT Master（始终执行 - 输出始终需要 EtherCAT）
		printf("[1/11] Initializing EtherCAT Master...\n");
		if (!InitEtherCATMaster())
			return false;

		// Step 2: 注册输出从站（始终执行）
		printf("[2/11] Registering output slaves...\n");
		if (!RegisterOutputSlaves())
			return false;

		// Step 3: 如果 input_mode=ethercat，注册称重输入从站
		if (input_mode_ == "ethercat")
		{
			printf("[3/11] Registering EtherCAT weighing input slaves...\n");
			if (!RegisterInputSlaves())
				return false;
		}
		else
		{
			printf("[3/11] Skipped (input_mode=%s, weighing via shared memory)\n",
				   input_mode_.c_str());
		}

		// Step 4: 统一激活 Master + Domain
		printf("[4/11] Activating EtherCAT Master...\n");
		if (!ActivateMaster())
			return false;

		// Step 5-6: OutputManager（始终执行）
		printf("[5/11] Initializing Output Manager...\n");
		printf("[6/11] Starting Output Manager...\n");
		if (!InitOutputManager())
			return false;

		// Step 7-8: InputSource
		printf("[7/11] Creating Input Source...\n");
		if (!InitInputSource(config_path))
			return false;

		// Step 9: Scales
		printf("[9/11] Initializing Scales...\n");
		if (!InitScales(db_path))
			return false;

		// Step 10: Subsystems
		printf("[10/11] Initializing Subsystems...\n");
		if (!InitSubsystems(db_path))
			return false;

		// ===== 初始化中央控制器 =====
		printf("SystemInitializer: Initializing CentralController...\n");

		if (!CentralController::Instance().Initialize())
		{
			fprintf(stderr, "SystemInitializer: Failed to initialize CentralController\n");
			return false;
		}

		// 注册所有子系统到中央控制器
		for (auto &[id, sub] : SubsystemManager::Instance().GetAllSubsystems())
		{
			auto cfg = sub->GetConfig();

			// 检查是否启用且需要注册到中央控制器
			if (cfg.enabled && cfg.register_to_central && sub->GetLiwApp())
			{
				CentralController::Instance().RegisterSubsystem(id);
				printf("SystemInitializer: Registered subsystem %u '%s' (priority: %d)\n",
					   id, cfg.name.c_str(), cfg.priority);
			}
		}

		// 启动中央控制器
		CentralController::Instance().Start();

		// Step 11: 启动 RT 线程
		printf("[11/11] Starting EtherCAT RT thread (%u us)...\n", cycle_time_us_);
		if (!StartRTThread())
			return false;

		initialized_ = true;
		printf("======================================\n");
		printf("  System Initialization Complete\n");
		printf("======================================\n");
		return true;
	}

	// ============================================================================
	// 关闭（严格逆序）
	// ============================================================================
	void SystemInitializer::Shutdown()
	{
		printf("======================================\n");
		printf("  System Shutdown Start\n");
		printf("======================================\n");

		// 逆序关闭
		SubsystemManager::Instance().StopAll();		   // Step 10
		ScaleManager::Instance().StopAll();			   // Step 9 (含 InputSource::Stop)
		OutputManager::Instance().Stop();			   // Step 5-6
		EtherCATMaster::Instance().StopCyclicThread(); // Step 11
		EtherCATMaster::Instance().Shutdown();		   // Step 1-4
		DatabaseManager::Instance().Close();		   // Step 9a (数据库)

		initialized_ = false;
		printf("======================================\n");
		printf("  System Shutdown Complete\n");
		printf("======================================\n");
	}

	// ============================================================================
	// Step 0: 解析 JSON 配置
	// ============================================================================
	bool SystemInitializer::LoadConfig(const std::string &config_path)
	{
		try
		{
			std::ifstream f(config_path);
			if (!f.is_open())
			{
				fprintf(stderr, "SysInit: Cannot open config %s\n", config_path.c_str());
				return false;
			}

			nlohmann::json j;
			f >> j;

			input_mode_ = j.value("input_mode", "shmem");
			cycle_time_us_ = j.value("cycle_time_us", 1000u);

			// 输出从站（始终存在）
			if (j.contains("output") && j["output"].contains("slaves"))
			{
				master_index_ = j["output"].value("master_index", 0u);
				for (const auto &s : j["output"]["slaves"])
				{
					SlaveEntry e;
					e.alias = s.value("alias", 0);
					e.position = s.value("position", 0);
					e.vendor_id = static_cast<uint32_t>(
						std::stoul(s.value("vendor_id", "0x0"), nullptr, 16));
					e.product_code = static_cast<uint32_t>(
						std::stoul(s.value("product_code", "0x0"), nullptr, 16));
					e.description = s.value("description", "");
					parsed_.output_slaves.push_back(e);
				}
			}

			// 输入从站（仅当 ethercat 模式有意义）
			if (j.contains("input_source") && j["input_source"].contains("ethercat"))
			{
				for (const auto &s : j["input_source"]["ethercat"]["slaves"])
				{
					SlaveEntry e;
					e.alias = s.value("alias", 0);
					e.position = s.value("position", 0);
					e.vendor_id = static_cast<uint32_t>(
						std::stoul(s.value("vendor_id", "0x0"), nullptr, 16));
					e.product_code = static_cast<uint32_t>(
						std::stoul(s.value("product_code", "0x0"), nullptr, 16));
					e.description = s.value("description", "");
					parsed_.input_slaves.push_back(e);
				}
			}

			// 共享内存参数
			if (j.contains("input_source") && j["input_source"].contains("shmem"))
			{
				auto &shm = j["input_source"]["shmem"];
				parsed_.shm_path = shm.value("shm_path", "/dev/shm/adc_data");
				parsed_.shm_channels = shm.value("channels", 2);
				parsed_.shm_poll_us = shm.value("poll_interval_us", 500);
			}

			// 子系统映射
			if (j.contains("subsystem_mapping"))
			{
				for (auto &[key, val] : j["subsystem_mapping"].items())
				{
					SubMapping m;
					m.sub_id = std::stoul(key);
					m.io_position = val.value("io_position", (uint16_t)0);
					m.scale_id = val.value("scale_id", 0u);
					m.description = val.value("description", "Subsystem " + key);
					parsed_.subsystem_mappings.push_back(m);
				}
			}

			// ===== 解析 digital_output_map（直接在这里做）=====
			parsed_.has_dio_map_cfg = false;
			parsed_.dio_map_cfg = DigitalOutputMapConfig{};
			if (j.contains("digital_output_map") && j["digital_output_map"].is_object())
			{
				const auto &dm = j["digital_output_map"];
				parsed_.dio_map_cfg.version = dm.value("version", 1);

				if (dm.contains("bindings") && dm["bindings"].is_array())
				{
					for (const auto &it : dm["bindings"])
					{
						DigitalOutputBinding b;
						b.subsystem_id = it.value("subsystem_id", 0u);
						b.io_pos = static_cast<uint16_t>(it.value("io_pos", 0));
						b.channel = static_cast<uint16_t>(it.value("channel", 0));
						b.signal = static_cast<DigitalSignalType>(it.value("signal", 0));
						b.bit_index = static_cast<uint8_t>(it.value("bit_index", 0));
						b.active_high = it.value("active_high", true);
						b.enabled = it.value("enabled", true);
						b.app_scope = it.value("app_scope", -1);
						parsed_.dio_map_cfg.bindings.push_back(b);
					}
					parsed_.has_dio_map_cfg = true;
				}

				// === 新增：解析伺服电机与工艺信号的绑定 ===
				if (dm.contains("servo_bindings") && dm["servo_bindings"].is_array())
				{
					for (const auto &item : dm["servo_bindings"])
					{
						ServoOutputBinding sb;
						sb.subsystem_id = item.value("subsystem_id", 0);
						sb.servo_pos = item.value("servo_pos", 0);
						sb.signal = static_cast<DigitalSignalType>(item.value("signal", 0));
						sb.enabled = item.value("enabled", true);
						sb.app_scope = item.value("app_scope", -1);
						parsed_.dio_map_cfg.servo_bindings.push_back(sb);
					}
				}
			}
		}
		catch (const std::exception &e)
		{
			fprintf(stderr, "SysInit: Config parse error: %s\n", e.what());
			return false;
		}

		printf("  Config: %zu output slaves, %zu input slaves, %zu subsystems\n",
			   parsed_.output_slaves.size(),
			   parsed_.input_slaves.size(),
			   parsed_.subsystem_mappings.size());
		return true;
	}

	// ============================================================================
	// Step 1: 初始化 EtherCAT Master（始终执行）
	// ============================================================================
	bool SystemInitializer::InitEtherCATMaster()
	{
		return EtherCATMaster::Instance().Initialize(master_index_);
	}

	// ============================================================================
	// Step 2: 注册输出从站（始终执行）
	// ============================================================================
	bool SystemInitializer::RegisterOutputSlaves()
	{
		auto &master = EtherCATMaster::Instance();

		for (const auto &s : parsed_.output_slaves)
		{
			SlaveDescriptor desc;
			desc.alias = s.alias;
			desc.position = s.position;
			desc.vendor_id = s.vendor_id;
			desc.product_code = s.product_code;
			desc.description = s.description;
			desc.role = IdentifySlave(s.vendor_id, s.product_code);

			if (!master.AddSlave(desc))
			{
				fprintf(stderr, "SysInit: Failed to add output slave pos=%u (%s)\n",
						s.position, s.description.c_str());
				return false;
			}
			printf("  Output slave: pos=%u %s (role=%d)\n",
				   s.position, s.description.c_str(), static_cast<int>(desc.role));
		}
		return true;
	}

	// ============================================================================
	// Step 3: 注册称重输入从站（仅 ethercat 模式）
	// ============================================================================
	bool SystemInitializer::RegisterInputSlaves()
	{
		auto &master = EtherCATMaster::Instance();

		for (const auto &s : parsed_.input_slaves)
		{
			SlaveDescriptor desc;
			desc.alias = s.alias;
			desc.position = s.position;
			desc.vendor_id = s.vendor_id;
			desc.product_code = s.product_code;
			desc.description = s.description;
			desc.role = SlaveRole::kWeighingInput;

			if (!master.AddSlave(desc))
			{
				fprintf(stderr, "SysInit: Failed to add input slave pos=%u (%s)\n",
						s.position, s.description.c_str());
				return false;
			}
			printf("  Input slave: pos=%u %s\n", s.position, s.description.c_str());
		}
		return true;
	}

	// ============================================================================
	// Step 4: 统一激活
	// ============================================================================
	bool SystemInitializer::ActivateMaster()
	{
		return EtherCATMaster::Instance().Activate();
	}

	// ============================================================================
	// Step 5-6: OutputManager（始终执行）
	// ============================================================================
	bool SystemInitializer::InitOutputManager()
	{
		auto &om = OutputManager::Instance();

		// Initialize 从 EtherCATMaster 查询伺服+IO从站并创建 controller
		if (!om.Initialize())
			return false;

		// === 新增/修改：统一下发映射配置，建立动态路由表 ===
		std::string err;
		if (!om.UpdateDigitalOutputMap(parsed_.dio_map_cfg, &err))
		{
			printf("Failed to update output map: %s\n", err.c_str());
			return false;
		}

		// 设置子系统映射
		for (const auto &m : parsed_.subsystem_mappings)
		{
			om.MapSubsystemIO(m.sub_id, m.io_position);
		}

		std::string err;

		// 有配置就优先用配置
		if (parsed_.has_dio_map_cfg)
		{
			if (om.UpdateDigitalOutputMap(parsed_.dio_map_cfg, &err))
			{
				printf("  DIO map loaded from input_mode.json (%zu bindings)\n",
					   parsed_.dio_map_cfg.bindings.size());
			}
			fprintf(stderr, "SysInit: digital_output_map invalid: %s, fallback to defaults\n", err.c_str());
		}
		else
		{
			// 没有配置就根据子系统映射生成默认映射
			DigitalOutputMapConfig default_cfg = DigitalOutputMap().BuildDefaultDigitalOutputMapForAll(om.GetSubsystemIOMap());
			if (om.UpdateDigitalOutputMap(default_cfg, &err))
			{
				printf("  DIO map generated from subsystem mapping (%zu bindings)\n",
					   default_cfg.bindings.size());
			}
			else
			{
				fprintf(stderr, "SysInit: Failed to set default digital output map: %s\n", err.c_str());
				return false;
			}
		}

		// 注册 output callback 到 EtherCATMaster
		if (!om.Start())
			return false;

		return true;
	}

	// ============================================================================
	// Step 7-8: InputSource
	// ============================================================================
	bool SystemInitializer::InitInputSource(const std::string &config_path)
	{
		// 使用 InputFactory 创建（内部处理 Initialize）
		auto input = InputFactory::Create(config_path);
		if (!input)
		{
			fprintf(stderr, "SysInit: InputFactory::Create failed\n");
			return false;
		}

		printf("[8/11] Starting input source (%s)...\n",
			   input->GetMode() == InputMode::kEtherCAT ? "EtherCAT" : "SharedMemory");

		// 设置 ADC 回调 -> ScaleManager
		input->SetAdcCallback([](const AdcSample &sample)
							  {
		auto *scale = ScaleManager::Instance().GetScale(sample.channel_id);
		if (scale) {
			scale->FeedAdcSample(sample);
		} });

		if (!input->Start())
		{
			fprintf(stderr, "SysInit: Input source start failed\n");
			return false;
		}

		// ScaleManager 持有 InputSource 所有权
		ScaleManager::Instance().SetInputSource(std::move(input));
		return true;
	}

	// ============================================================================
	// Step 9: Scales
	// ============================================================================
	bool SystemInitializer::InitScales(const std::string &db_path)
	{
		// Step 9a: 打开数据库 + 建表
		auto &db = DatabaseManager::Instance();
		if (!db.Open(db_path))
		{
			fprintf(stderr, "SysInit: Failed to open database %s\n", db_path.c_str());
			return false;
		}
		if (!db.InitializeSchema())
		{
			fprintf(stderr, "SysInit: Failed to initialize database schema\n");
			return false;
		}
		printf("  Database opened: %s\n", db_path.c_str());

		// Step 9b: 从数据库查询已保存的秤台配置
		auto scale_ids = ConfigStore::Instance().LoadAllScaleIds();

		if (scale_ids.empty())
		{
			// 没有已保存的配置 -> 根据子系统映射创建默认秤台
			for (const auto &m : parsed_.subsystem_mappings)
			{
				auto *scale = ScaleManager::Instance().CreateScale(m.scale_id);
				if (scale)
				{
					// 使用默认参数初始化
					ScaleParams params;
					ZeroConfig zero;
					TareConfig tare;
					FilterStabilityConfig filter;
					scale->Initialize(params, zero, tare, filter);
					printf("  Created default scale %u\n", m.scale_id);
				}
			}

			// 保底：如果没有子系统映射，至少创建秤台0
			if (parsed_.subsystem_mappings.empty())
			{
				auto *scale = ScaleManager::Instance().CreateScale(0);
				if (scale)
				{
					ScaleParams params;
					ZeroConfig zero;
					TareConfig tare;
					FilterStabilityConfig filter;
					scale->Initialize(params, zero, tare, filter);
					printf("  Created fallback scale 0\n");
				}
			}
		}
		else
		{
			// 从数据库加载每个秤台的完整配置
			for (uint32_t sid : scale_ids)
			{
				auto *scale = ScaleManager::Instance().CreateScale(sid);
				if (!scale)
					continue;

				ScaleParams params;
				ZeroConfig zero;
				TareConfig tare;
				FilterStabilityConfig filter;

				if (ConfigStore::Instance().LoadScaleConfig(sid, params, zero, tare, filter))
				{
					scale->Initialize(params, zero, tare, filter);
					printf("  Scale %u: config loaded from database\n", sid);
				}
				else
				{
					scale->Initialize(params, zero, tare, filter); // 默认
					printf("  Scale %u: using defaults\n", sid);
				}
			}
			printf("  Loaded %zu scales from database\n", scale_ids.size());
		}

		// Step 9c: 加载校正数据
		// CalibrationStore::Instance().Initialize(db_path);
		for (auto &[id, scale] : ScaleManager::Instance().GetAllScales())
		{
			CalibrationData cal;
			if (CalibrationStore::Instance().LoadCalibration(id, cal) && cal.is_valid)
			{
				scale->LoadCalibrationData(cal);
				printf("  Scale %u: calibration loaded\n", id);
			}
		}

		return true;
	}

	// ============================================================================
	// Step 10: Subsystems
	// ============================================================================
	bool SystemInitializer::InitSubsystems(const std::string &db_path)
	{
		for (const auto &m : parsed_.subsystem_mappings)
		{
			SubsystemConfig cfg;
			cfg.id = m.sub_id;
			cfg.name = m.description;
			cfg.scale_ids.push_back(m.scale_id);

			// 从数据库加载应用类型（如果没有记录则返回默认值 kLossInWeight）
			cfg.app_type = ConfigStore::Instance().LoadAppType(m.sub_id);

			auto *sub = SubsystemManager::Instance().CreateSubsystem(cfg);
			if (!sub)
			{
				fprintf(stderr, "SysInit: Failed to create subsystem %u\n", m.sub_id);
				continue;
			}

			sub->Initialize();

			// 加载应用配置
			if (sub->GetLiwApp())
			{
				ConfigStore::Instance().LoadLiwConfig(m.sub_id, sub->GetLiwApp());
				printf("  Subsystem %u: LIW config loaded\n", m.sub_id);
			}
			if (sub->GetFillingApp())
			{
				ConfigStore::Instance().LoadFillingConfig(m.sub_id, sub->GetFillingApp());
				printf("  Subsystem %u: Filling config loaded\n", m.sub_id);
			}

			printf("  Subsystem %u created: %s (app_type=%d)\n",
				   m.sub_id, m.description.c_str(), static_cast<int>(cfg.app_type));
		}

		// 保底：如果没有映射配置，创建默认子系统
		if (parsed_.subsystem_mappings.empty())
		{
			SubsystemConfig cfg;
			cfg.id = 0;
			cfg.name = "Default";
			cfg.app_type = AppType::kLossInWeight;
			cfg.scale_ids.push_back(0);
			auto *sub = SubsystemManager::Instance().CreateSubsystem(cfg);
			if (sub)
				sub->Initialize();
			printf("  Created default subsystem 0\n");
		}

		// 注册 DIO 输入回调（始终注册，因为输出始终是 EtherCAT）
		OutputManager::Instance().SetDioInputCallback(
			[](uint32_t io_pos, const DioInputSignals &signals)
			{
				for (auto &[id, sub] : SubsystemManager::Instance().GetAllSubsystems())
				{
					sub->HandleDioInputs(signals);
				}
			});

		return true;
	}

	// ============================================================================
	// 保存 DIO 映射配置到 JSON 文件
	bool SystemInitializer::SaveDigitalOutputMapToConfig(const DigitalOutputMapConfig &cfg, std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			nlohmann::json dm;
			dm["version"] = cfg.version;
			dm["bindings"] = nlohmann::json::array();
			for (const auto &b : cfg.bindings)
			{
				dm["bindings"].push_back({{"subsystem_id", b.subsystem_id},
										  {"io_pos", b.io_pos},
										  {"channel", b.channel},
										  {"signal", static_cast<int>(b.signal)},
										  {"bit_index", b.bit_index},
										  {"active_high", b.active_high},
										  {"enabled", b.enabled},
										  {"app_scope", b.app_scope}});
			}

			// === 新增：将伺服配置序列化回 JSON ===
			dm["servo_bindings"] = nlohmann::json::array();
			for (const auto &b : cfg.servo_bindings)
			{
				dm["servo_bindings"].push_back({{"subsystem_id", b.subsystem_id},
												{"servo_pos", b.servo_pos},
												{"signal", static_cast<int>(b.signal)},
												{"enabled", b.enabled},
												{"app_scope", b.app_scope}});
			}
			j["digital_output_map"] = dm;

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();

			// 更新内存缓存（可选）
			parsed_.dio_map_cfg = cfg;
			parsed_.has_dio_map_cfg = true;
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// 更新子系统秤台映射并持久化（upsert：不存在则创建）
	// ============================================================================
	bool SystemInitializer::SaveSubsystemMappingToConfig(uint32_t subsystem_id, uint32_t scale_id, std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			std::string key = std::to_string(subsystem_id);

			// 如果 subsystem_mapping 段不存在，创建它
			if (!j.contains("subsystem_mapping") || !j["subsystem_mapping"].is_object())
			{
				j["subsystem_mapping"] = nlohmann::json::object();
			}

			// 如果该子系统条目不存在，创建默认条目（upsert）
			if (!j["subsystem_mapping"].contains(key))
			{
				j["subsystem_mapping"][key] = {
					{"scale_id", scale_id},
					{"io_position", 0},
					{"description", "Subsystem " + key}};
				// 同步更新内存缓存
				SubMapping m;
				m.sub_id = subsystem_id;
				m.scale_id = scale_id;
				m.io_position = 0;
				m.description = "Subsystem " + key;
				parsed_.subsystem_mappings.push_back(m);
			}
			else
			{
				j["subsystem_mapping"][key]["scale_id"] = scale_id;
				// 更新内存缓存
				for (auto &m : parsed_.subsystem_mappings)
				{
					if (m.sub_id == subsystem_id)
					{
						m.scale_id = scale_id;
						break;
					}
				}
			}

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// 添加新的子系统条目并持久化
	// ============================================================================
	bool SystemInitializer::AddSubsystemToConfig(uint32_t sub_id, uint16_t io_position,
												 uint32_t scale_id, const std::string &description,
												 std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			if (!j.contains("subsystem_mapping") || !j["subsystem_mapping"].is_object())
			{
				j["subsystem_mapping"] = nlohmann::json::object();
			}

			std::string key = std::to_string(sub_id);
			j["subsystem_mapping"][key] = {
				{"scale_id", scale_id},
				{"io_position", io_position},
				{"description", description.empty() ? "Subsystem " + key : description}};

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();

			// 更新内存缓存（先去重再添加）
			auto it = std::find_if(parsed_.subsystem_mappings.begin(),
								   parsed_.subsystem_mappings.end(),
								   [sub_id](const SubMapping &m)
								   { return m.sub_id == sub_id; });
			if (it != parsed_.subsystem_mappings.end())
			{
				it->scale_id = scale_id;
				it->io_position = io_position;
				it->description = description.empty() ? "Subsystem " + key : description;
			}
			else
			{
				SubMapping m;
				m.sub_id = sub_id;
				m.scale_id = scale_id;
				m.io_position = io_position;
				m.description = description.empty() ? "Subsystem " + key : description;
				parsed_.subsystem_mappings.push_back(m);
			}
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// 删除子系统条目并持久化
	// ============================================================================
	bool SystemInitializer::RemoveSubsystemFromConfig(uint32_t sub_id, std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			std::string key = std::to_string(sub_id);
			if (j.contains("subsystem_mapping") && j["subsystem_mapping"].contains(key))
			{
				j["subsystem_mapping"].erase(key);
			}

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();

			// 更新内存缓存
			parsed_.subsystem_mappings.erase(
				std::remove_if(parsed_.subsystem_mappings.begin(),
							   parsed_.subsystem_mappings.end(),
							   [sub_id](const SubMapping &m)
							   { return m.sub_id == sub_id; }),
				parsed_.subsystem_mappings.end());
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// 更新从站用户别名并持久化
	// ============================================================================
	bool SystemInitializer::SaveSlaveAliasToConfig(uint16_t position, const std::string &alias, std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			bool found = false;
			// 搜索 ethercat 输入从站
			if (j.contains("input_source") && j["input_source"].contains("ethercat"))
			{
				for (auto &s : j["input_source"]["ethercat"]["slaves"])
				{
					if (s.value("position", -1) == position)
					{
						s["user_alias"] = alias;
						found = true;
						break;
					}
				}
			}
			// 搜索输出从站
			if (!found && j.contains("output") && j["output"].contains("slaves"))
			{
				for (auto &s : j["output"]["slaves"])
				{
					if (s.value("position", -1) == position)
					{
						s["user_alias"] = alias;
						found = true;
						break;
					}
				}
			}
			if (!found)
			{
				// 从站不在已注册列表中也没关系，写入一个 user_aliases 附加表
				j["user_aliases"][std::to_string(position)] = alias;
			}

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// 保存 EtherCAT 硬件配置（output 和 input_source.ethercat）到 JSON 文件
	// ============================================================================
	bool SystemInitializer::SaveEthercatHardwareConfig(
		const std::vector<SlaveEntry> &output_slaves,
		const std::vector<SlaveEntry> &input_slaves,
		std::string *err)
	{
		try
		{
			std::ifstream ifs(config_path_);
			if (!ifs.is_open())
			{
				if (err)
					*err = "open config failed";
				return false;
			}
			nlohmann::json j;
			ifs >> j;
			ifs.close();

			auto to_hex = [](uint32_t v) -> std::string
			{
				char buf[16];
				snprintf(buf, sizeof(buf), "0x%08x", v);
				return std::string(buf);
			};

			// 输出从站 (servo + IO)
			if (!output_slaves.empty())
			{
				j["output"]["master_index"] = master_index_;
				j["output"]["slaves"] = nlohmann::json::array();
				for (const auto &s : output_slaves)
				{
					j["output"]["slaves"].push_back({
						{"alias", s.alias},
						{"position", s.position},
						{"vendor_id", to_hex(s.vendor_id)},
						{"product_code", to_hex(s.product_code)},
						{"description", s.description},
					});
				}
				// 更新内存缓存
				parsed_.output_slaves.clear();
				for (const auto &s : output_slaves)
				{
					SlaveEntry e;
					e.alias = s.alias;
					e.position = s.position;
					e.vendor_id = s.vendor_id;
					e.product_code = s.product_code;
					e.description = s.description;
					parsed_.output_slaves.push_back(e);
				}
			}

			// 输入从站 (称重仪表, 仅 ethercat 模式)
			if (!input_slaves.empty())
			{
				if (!j.contains("input_source"))
					j["input_source"] = nlohmann::json::object();
				j["input_source"]["ethercat"]["slaves"] = nlohmann::json::array();
				for (const auto &s : input_slaves)
				{
					j["input_source"]["ethercat"]["slaves"].push_back({
						{"alias", s.alias},
						{"position", s.position},
						{"vendor_id", to_hex(s.vendor_id)},
						{"product_code", to_hex(s.product_code)},
						{"description", s.description},
					});
				}
				// 更新内存缓存
				parsed_.input_slaves.clear();
				for (const auto &s : input_slaves)
				{
					SlaveEntry e;
					e.alias = s.alias;
					e.position = s.position;
					e.vendor_id = s.vendor_id;
					e.product_code = s.product_code;
					e.description = s.description;
					parsed_.input_slaves.push_back(e);
				}
			}

			std::ofstream ofs(config_path_, std::ios::trunc);
			if (!ofs.is_open())
			{
				if (err)
					*err = "write config failed";
				return false;
			}
			ofs << j.dump(2);
			ofs.close();
			return true;
		}
		catch (const std::exception &e)
		{
			if (err)
				*err = e.what();
			return false;
		}
	}

	// ============================================================================
	// Step 11: 启动 RT 线程
	// ============================================================================
	bool SystemInitializer::StartRTThread()
	{
		return EtherCATMaster::Instance().StartCyclicThread(cycle_time_us_);
	}

} // namespace weighing