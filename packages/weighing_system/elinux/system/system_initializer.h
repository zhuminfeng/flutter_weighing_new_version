#ifndef SYSTEM_INITIALIZER_H
#define SYSTEM_INITIALIZER_H

#include <string>
#include <vector>
#include "../output/digital_output_mapping.h"

namespace weighing
{

	/// 系统初始化器 - 修正后的初始化顺序
	///
	///   1. EtherCATMaster::Initialize   (始终执行 - 输出始终需要)
	///   2. 注册输出从站 (InoSV630N, EC3A-IO1632)
	///   3. 如果 input_mode=ethercat, 注册称重输入从站
	///   4. EtherCATMaster::Activate     (统一激活)
	///   5. OutputManager::Initialize    (创建 ServoController, DigitalIOController)
	///   6. OutputManager::Start         (注册 output callback)
	///   7. InputSource 创建             (EtherCAT或SharedMemory)
	///   8. 如果 input_mode=ethercat, EtherCATInput 注册 input callback
	///   9. ScaleManager 初始化          (创建秤台, 加载校正)
	///  10. SubsystemManager 初始化      (创建子系统, 加载配置, DIO回调)
	///  11. EtherCATMaster::StartCyclicThread (启动RT线程)
	///
	class SystemInitializer
	{
	public:
		static SystemInitializer &Instance();

		bool Initialize(const std::string &config_path, const std::string &db_path);
		void Shutdown();

		bool IsInitialized() const { return initialized_; }
		const std::string &GetInputMode() const { return input_mode_; }

		bool SaveDigitalOutputMapToConfig(const DigitalOutputMapConfig &cfg, std::string *err);

		bool SaveSubsystemMappingToConfig(uint32_t subsystem_id, uint32_t scale_id, std::string *err);

		// ── 1. 将用作公共接口的结构体提前声明 ────────────────────────────────
		struct SlaveEntry
		{
			uint16_t alias;
			uint16_t position;
			uint32_t vendor_id;
			uint32_t product_code;
			std::string description;
		};

		struct SubMapping
		{
			uint32_t sub_id;
			uint16_t io_position;
			uint32_t scale_id;
			std::string description;
		};

		// ── Config status accessors ──────────────────────────────────────────
		bool GetHasOutputSlaves() const { return !parsed_.output_slaves.empty(); }
		bool GetHasInputSourceConfig() const
		{
			if (input_mode_ == "ethercat")
				return !parsed_.input_slaves.empty();
			return true; // shmem always has default config
		}
		bool GetHasDioMapCfg() const { return parsed_.has_dio_map_cfg; }

		bool SaveEthercatHardwareConfig(
			const std::vector<SlaveEntry> &output_slaves,
			const std::vector<SlaveEntry> &input_slaves,
			std::string *err);

		bool AddSubsystemToConfig(uint32_t sub_id, uint16_t io_position, uint32_t scale_id,
								  const std::string &description, std::string *err);

		bool RemoveSubsystemFromConfig(uint32_t sub_id, std::string *err);

		bool SaveSlaveAliasToConfig(uint16_t position, const std::string &alias, std::string *err);

		// ── 2. 返回值直接使用公有的 SubMapping 类型 ──────────────────────────
		const std::vector<SubMapping> &GetSubsystemMappings() const
		{
			return parsed_.subsystem_mappings;
		}

	private:
		SystemInitializer() = default;

		bool LoadConfig(const std::string &config_path);
		bool InitEtherCATMaster();
		bool RegisterOutputSlaves();
		bool RegisterInputSlaves();
		bool ActivateMaster();
		bool InitOutputManager();
		bool InitInputSource(const std::string &config_path);
		bool InitScales(const std::string &db_path);
		bool InitSubsystems(const std::string &db_path);
		bool StartRTThread();

		bool initialized_ = false;
		std::string input_mode_ = "shmem";
		std::string config_path_;
		uint32_t cycle_time_us_ = 1000;
		unsigned int master_index_ = 0;

		// ── 3. 简化私有缓存结构，复用外部定义的公共结构体 ──────────────────
		struct ParsedConfig
		{
			// 直接使用 public 区域定义的 SlaveEntry 和 SubMapping
			std::vector<SlaveEntry> output_slaves;
			std::vector<SlaveEntry> input_slaves;
			std::vector<SubMapping> subsystem_mappings;

			// DIO 映射配置
			DigitalOutputMapConfig dio_map_cfg;
			bool has_dio_map_cfg = false;

			// shmem config
			std::string shm_path = "/dev/mem";
			int shm_channels = 2;
			int shm_poll_us = 500;
		} parsed_;
	};

} // namespace weighing

#endif