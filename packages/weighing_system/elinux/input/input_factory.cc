#include "input_factory.h"
#include "ethercat_input.h"
#include "shmem_input.h"
#include "../ethercat/ethercat_master.h"
#include <fstream>
#include <cstring>
#include "../include/nlohmann/json.hpp"
#include <cstdio>

namespace weighing
{

	InputMode InputFactory::ParseInputMode(const std::string &config_path)
	{
		std::ifstream file(config_path);
		if (!file.is_open())
		{
			fprintf(stderr, "InputFactory: Failed to open %s. Defaulting to EtherCAT.\n", config_path.c_str());
			return InputMode::kEtherCAT;
		}

		try
		{
			// 🚀 使用标准 JSON 解析树去精确读取配置
			nlohmann::json j;
			file >> j;

			if (j.contains("input_mode") && j["input_mode"].is_string())
			{
				std::string mode_str = j["input_mode"].get<std::string>();
				if (mode_str == "shmem" || mode_str == "shared_memory")
				{
					return InputMode::kSharedMemory;
				}
			}
		}
		catch (const std::exception &e)
		{
			fprintf(stderr, "InputFactory: JSON parse error in %s: %s\n", config_path.c_str(), e.what());
		}

		// 默认兜底：EtherCAT
		return InputMode::kEtherCAT;
	}

	std::unique_ptr<InputSource> InputFactory::Create(const std::string &config_path)
	{
		InputMode mode = ParseInputMode(config_path);
		std::unique_ptr<InputSource> source;

		switch (mode)
		{
		case InputMode::kEtherCAT:
		{
			auto &master = EtherCATMaster::Instance();
			if (!master.IsOperational())
			{
				fprintf(stderr, "InputFactory: EtherCATMaster not operational. "
								"Call SystemInitializer::Initialize() first.\n");
				return nullptr;
			}
			source = std::make_unique<EtherCATInput>();
			break;
		}
		case InputMode::kSharedMemory:
		{
			source = std::make_unique<ShmemInput>();
			break;
		}
		}

		if (source)
		{
			if (!source->Initialize(config_path))
			{
				fprintf(stderr, "InputFactory: Input source initialization failed\n");
				return nullptr;
			}
		}

		return source;
	}

} // namespace weighing