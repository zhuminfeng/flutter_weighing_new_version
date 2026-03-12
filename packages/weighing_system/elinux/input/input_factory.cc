#include "input_factory.h"
#include "ethercat_input.h"
#include "shmem_input.h"
#include "../ethercat/ethercat_master.h"
#include <fstream>
#include <cstring>
#include <cstdio>

namespace weighing
{

	InputMode InputFactory::ParseInputMode(const std::string &config_path)
	{
		std::ifstream file(config_path);
		if (!file.is_open())
		{
			return InputMode::kEtherCAT;
		}

		std::string content((std::istreambuf_iterator<char>(file)),
							std::istreambuf_iterator<char>());

		if (content.find("\"shmem\"") != std::string::npos ||
			content.find("\"shared_memory\"") != std::string::npos)
		{
			return InputMode::kSharedMemory;
		}

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