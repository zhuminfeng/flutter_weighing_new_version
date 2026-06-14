#include "ethercat_master.h"
#include <cstring>
#include <cstdio>
#include <ctime>
#include <sched.h>
#include <sys/mman.h>

namespace weighing
{

	EtherCATMaster &EtherCATMaster::Instance()
	{
		static EtherCATMaster instance;
		return instance;
	}

	// ============================================================================
	// 初始化
	// ============================================================================
	bool EtherCATMaster::Initialize(unsigned int master_index)
	{
		std::lock_guard<std::mutex> lock(config_mutex_);

		master_ = ecrt_request_master(master_index);
		if (!master_)
		{
			fprintf(stderr, "ECMaster: Failed to request master %u\n", master_index);
			return false;
		}

		domain_ = ecrt_master_create_domain(master_);
		if (!domain_)
		{
			fprintf(stderr, "ECMaster: Failed to create domain\n");
			ecrt_release_master(master_);
			master_ = nullptr;
			return false;
		}

		printf("ECMaster: Master %u initialized successfully\n", master_index);
		return true;
	}

	void EtherCATMaster::Shutdown()
	{
		StopCyclicThread();

		std::lock_guard<std::mutex> lock(config_mutex_);
		operational_ = false;

		if (master_)
		{
			ecrt_release_master(master_);
			master_ = nullptr;
		}
		domain_ = nullptr;
		domain_data_ = nullptr;
		slave_configs_.clear();
		slaves_.clear();
		pdo_regs_.clear();
		input_callbacks_.clear();
		output_callbacks_.clear();

		printf("ECMaster: Shutdown complete\n");
	}

	// ============================================================================
	// 添加从站
	// ============================================================================
	bool EtherCATMaster::AddSlave(const SlaveDescriptor &desc)
	{
		std::lock_guard<std::mutex> lock(config_mutex_);
		if (!master_)
			return false;

		// 【核心修复】：完全使用从 JSON 解析出来的 desc.position，绝对不能再强行赋值为 0
		ec_slave_config_t *sc = ecrt_master_slave_config(
			master_, desc.alias, desc.position, desc.vendor_id, desc.product_code);

		if (!sc)
		{
			fprintf(stderr, "ECMaster: Failed to config slave %u\n", desc.position);
			return false;
		}

		// 直接在 map 内部创建对象，拿到稳定长久的内存地址（保留了解决悬空指针的修复）
		auto &rt = slaves_[desc.position];
		rt.descriptor = desc;
		// rt.config = sc;
		rt.role = desc.role;

		bool ok = false;
		switch (desc.role)
		{
		case SlaveRole::kDigitalIO:
			ok = ConfigureDigitalIO(sc, rt);
			break;
		case SlaveRole::kServo:
			ok = ConfigureServo(sc, rt);
			break;
		case SlaveRole::kWeighingInput:
			ok = ConfigureWeighing(sc, rt);
			break;
		default:
			break;
		}

		if (ok)
		{
			slave_configs_.push_back(sc);
			printf("ECMaster: Slave configured - pos=%u role=%d desc='%s'\n",
				   desc.position, (int)desc.role, desc.description.c_str());
		}
		else
		{
			// 如果配置失败，清理占位
			slaves_.erase(desc.position);
		}

		return ok;
	}

	// ============================================================================
	// PDO 配置 - EC3A-IO1632
	// ============================================================================
	bool EtherCATMaster::ConfigureDigitalIO(ec_slave_config_t *sc, SlaveRuntime &rt)
	{
		static ec_pdo_entry_info_t entries[] = {
			{0x7000, 0x01, 16}, // OUT_GEN_DO
			{0x6000, 0x01, 16}, // IN_GEN_DI
		};

		static ec_pdo_info_t pdos[] = {
			{0x1600, 1, entries + 0}, // DOOutputs
			{0x1a00, 1, entries + 1}, // DIInputs
		};

		static ec_sync_info_t syncs[] = {
			{0, EC_DIR_OUTPUT, 0, NULL, EC_WD_DISABLE},
			{1, EC_DIR_INPUT, 0, NULL, EC_WD_DISABLE},
			{2, EC_DIR_OUTPUT, 1, pdos + 0, EC_WD_ENABLE},
			{3, EC_DIR_INPUT, 1, pdos + 1, EC_WD_DISABLE},
			{0xff}};

		if (ecrt_slave_config_pdos(sc, EC_END, syncs))
		{
			fprintf(stderr, "ECMaster: PDO config failed for EC3A-IO1632\n");
			return false;
		}

		uint16_t pos = rt.descriptor.position;
		uint32_t vid = ec3a_io1632::VENDOR_ID;
		uint32_t pid = ec3a_io1632::PRODUCT_CODE;

		pdo_regs_.push_back({0, pos, vid, pid, 0x7000, 0x01, &rt.offsets.io.off_do});
		pdo_regs_.push_back({0, pos, vid, pid, 0x6000, 0x01, &rt.offsets.io.off_di});

		return true;
	}

	// ============================================================================
	// PDO 配置 - InoSV630N
	// ============================================================================
	bool EtherCATMaster::ConfigureServo(ec_slave_config_t *sc, SlaveRuntime &rt)
	{
		static ec_pdo_entry_info_t servo_pdo_entries[] = {
			/* RxPDO: 0x1600 */
			{0x6040, 0x00, 16}, /* 控制字 */
			{0x6060, 0x00, 8},	/* 模式设定 */
			{0x60FF, 0x00, 32}, /* 目标速度 */
			{0x6083, 0x00, 32}, /* 加速度 */
			{0x6084, 0x00, 32}, /* 减速度 */
			/* TxPDO: 0x1A00 */
			{0x6041, 0x00, 16}, /* 状态字 */
			{0x606C, 0x00, 32}, /* 实际速度 */
		};

		static ec_pdo_info_t servo_pdos[] = {
			{0x1600, 5, servo_pdo_entries + 0},
			{0x1a00, 2, servo_pdo_entries + 5},
		};

		static ec_sync_info_t servo_syncs[] = {
			{0, EC_DIR_OUTPUT, 0, nullptr, EC_WD_DISABLE},
			{1, EC_DIR_INPUT, 0, nullptr, EC_WD_DISABLE},
			{2, EC_DIR_OUTPUT, 1, servo_pdos + 0, EC_WD_ENABLE},
			{3, EC_DIR_INPUT, 1, servo_pdos + 1, EC_WD_DISABLE},
			{0xff}};

		if (ecrt_slave_config_pdos(sc, EC_END, servo_syncs))
		{
			fprintf(stderr, "ECMaster: PDO config failed for Servo\n");
			return false;
		}

		// 汇川必须的 DC 分布式时钟配置
		ecrt_slave_config_dc(sc, 0x0300, cycle_time_us_ * 1000, 0, 0, 0);

		// 注册 Domain 偏移量
		uint16_t p = rt.descriptor.position;
		uint16_t a = rt.descriptor.alias;
		uint32_t v = rt.descriptor.vendor_id;
		uint32_t c = rt.descriptor.product_code;

		pdo_regs_.push_back({a, p, v, c, 0x6040, 0, &rt.offsets.servo.off_control_word});
		pdo_regs_.push_back({a, p, v, c, 0x6060, 0, &rt.offsets.servo.off_operation_mode});
		pdo_regs_.push_back({a, p, v, c, 0x60FF, 0, &rt.offsets.servo.off_target_velocity});
		pdo_regs_.push_back({a, p, v, c, 0x6083, 0, &rt.offsets.servo.off_profile_accel});
		pdo_regs_.push_back({a, p, v, c, 0x6084, 0, &rt.offsets.servo.off_profile_decel});

		pdo_regs_.push_back({a, p, v, c, 0x6041, 0, &rt.offsets.servo.off_status_word});
		pdo_regs_.push_back({a, p, v, c, 0x606C, 0, &rt.offsets.servo.off_actual_velocity});

		return true;
	}

	// ============================================================================
	// PDO 配置 - 称重从站 (根据实际从站型号调整)
	// ============================================================================
	bool EtherCATMaster::ConfigureWeighing(ec_slave_config_t *sc, SlaveRuntime &rt)
	{
		if (!sc)
			return false;

		printf("ECMaster: Configuring Weighing Slave (AD2020EB) at position %u\n", rt.descriptor.position);

		// 1. 根据 AUTODA XML 描述定义 TxPDO (0x1A00) 的数据字典条目
		// 包含：净重(32bit)、毛重(32bit)、AD内码(32bit)、状态字(16bit)
		static ec_pdo_entry_info_t ad2020eb_pdo_entries[] = {
			{0x9020, 0x01, 32}, // 净重 Net Weight (DINT)
			{0x9020, 0x02, 32}, // 毛重 Gross Weight (DINT)
			{0x9020, 0x04, 32}, // AD内码 AD Code / Raw Value (DINT)
			{0x9020, 0x05, 16}, // 状态字 Status Word (UINT)
		};

		// 2. 定义 TxPDO 属性
		static ec_pdo_info_t ad2020eb_pdos[] = {
			{0x1a00, 4, ad2020eb_pdo_entries}};

		// 3. 配置 Sync Manager 3 (称重模块的 Inputs 映射在 SM3)
		ec_sync_info_t ad2020eb_syncs[] = {
			{3, EC_DIR_INPUT, 1, ad2020eb_pdos, EC_WD_DISABLE},
			{0xff} // 终结符
		};

		// 4. 将 PDO 拓扑下发给 IgH 从站配置描述符
		if (ecrt_slave_config_pdos(sc, ad2020eb_syncs) != 0)
		{
			fprintf(stderr, "ECMaster: Failed to configure PDOs for Weighing Slave at pos %u\n", rt.descriptor.position);
			return false;
		}

		// 5. 动态注册 PDO Entry 到全局 Domain 列表中，用于自动获取运行时内存偏移量
		// 注册 0x9020:04 (AD原始内码) -> 映射至 off_weight_raw
		ec_pdo_entry_reg_t reg_raw = {
			rt.descriptor.alias,
			rt.descriptor.position,
			rt.descriptor.vendor_id,
			rt.descriptor.product_code,
			0x9020,
			0x04,
			&rt.offsets.weighing.off_weight_raw};
		domain_regs_.push_back(reg_raw); // 扔进全局注册向量

		// 注册 0x9020:05 (状态字) -> 映射至 off_status
		ec_pdo_entry_reg_t reg_status = {
			rt.descriptor.alias,
			rt.descriptor.position,
			rt.descriptor.vendor_id,
			rt.descriptor.product_code,
			0x9020,
			0x05,
			&rt.offsets.weighing.off_status};
		domain_regs_.push_back(reg_status);

		rt.configured = true;
		return true;
	}

	// ============================================================================
	// 激活
	// ============================================================================
	bool EtherCATMaster::Activate()
	{
		std::lock_guard<std::mutex> lock(config_mutex_);

		if (!master_ || !domain_)
			return false;

		// 添加哨兵终止 PDO 注册列表
		ec_pdo_entry_reg_t sentinel{};
		memset(&sentinel, 0, sizeof(sentinel));
		pdo_regs_.push_back(sentinel);

		if (ecrt_domain_reg_pdo_entry_list(domain_, pdo_regs_.data()))
		{
			fprintf(stderr, "ECMaster: PDO entry registration failed\n");
			return false;
		}

		// 【新增】：在激活主站前，选择第一个从站作为 DC 参考时钟
		if (!slave_configs_.empty())
		{
			ecrt_master_select_reference_clock(master_, slave_configs_[0]);
		}

		if (ecrt_master_activate(master_))
		{
			fprintf(stderr, "ECMaster: Activation failed\n");
			return false;
		}

		domain_data_ = ecrt_domain_data(domain_);
		if (!domain_data_)
		{
			fprintf(stderr, "ECMaster: Failed to get domain data pointer\n");
			return false;
		}

		operational_ = true;
		printf("ECMaster: Activated with %zu slaves, domain data at %p\n",
			   slaves_.size(), static_cast<void *>(domain_data_));
		return true;
	}

	// ============================================================================
	// RT 线程
	// ============================================================================
	bool EtherCATMaster::StartCyclicThread(uint32_t cycle_time_us)
	{
		if (running_)
			return true;
		if (!operational_)
			return false;

		cycle_time_us_ = cycle_time_us;
		running_ = true;

		cyclic_thread_ = std::make_unique<std::thread>(&EtherCATMaster::CyclicThread, this);

		// 设置 RT 优先级
		struct sched_param param{};
		param.sched_priority = 80;
		if (pthread_setschedparam(cyclic_thread_->native_handle(), SCHED_FIFO, &param) != 0)
		{
			fprintf(stderr, "ECMaster: Warning - failed to set RT priority\n");
		}

		// ==========================================================
		// 【新增】：2. 绑定到隔离核 3 (即 Linux 中的 CPU 2)
		// ==========================================================
		cpu_set_t cpuset;
		CPU_ZERO(&cpuset);
		CPU_SET(2, &cpuset); // 强行指定 CPU 2

		int rc = pthread_setaffinity_np(cyclic_thread_->native_handle(), sizeof(cpu_set_t), &cpuset);
		if (rc != 0)
		{
			printf("ECMaster: Warning, failed to pin thread to CPU 2 (Core 3)!\n");
		}
		else
		{
			printf("ECMaster: Successfully pinned RT thread to CPU 2 (Core 3).\n");
		}

		printf("ECMaster: Cyclic thread started at %u us\n", cycle_time_us);
		return true;
	}

	void EtherCATMaster::StopCyclicThread()
	{
		if (!running_)
			return;
		running_ = false;

		if (cyclic_thread_ && cyclic_thread_->joinable())
		{
			cyclic_thread_->join();
		}
		cyclic_thread_.reset();
		printf("ECMaster: Cyclic thread stopped\n");
	}

	void EtherCATMaster::CyclicThread()
	{
		mlockall(MCL_CURRENT | MCL_FUTURE);

		struct timespec next_cycle;
		clock_gettime(CLOCK_MONOTONIC, &next_cycle);

		while (running_)
		{
			// 【新增 1】：写入应用时间 (必须在 receive 之前)
			uint64_t app_time = (uint64_t)next_cycle.tv_sec * 1000000000ULL + next_cycle.tv_nsec;
			ecrt_master_application_time(master_, app_time);
			// ===== 1. 接收 =====
			ecrt_master_receive(master_);
			ecrt_domain_process(domain_);

			// ===== 2. 输入回调 (读 TxPDO: 称重数据等) =====
			for (auto &cb : input_callbacks_)
			{
				cb(domain_data_);
			}

			// ===== 3. 输出回调 (写 RxPDO: 伺服控制/DO等) =====
			for (auto &cb : output_callbacks_)
			{
				cb(domain_data_);
			}

			// 【新增 2】：同步主站与从站时钟 (必须在 queue/send 之前)
			ecrt_master_sync_reference_clock(master_);
			ecrt_master_sync_slave_clocks(master_);

			// ===== 4. 发送 =====
			ecrt_domain_queue(domain_);
			ecrt_master_send(master_);

			// ===== 5. 等待下一周期 =====
			next_cycle.tv_nsec += cycle_time_us_ * 1000;
			while (next_cycle.tv_nsec >= 1000000000L)
			{
				next_cycle.tv_nsec -= 1000000000L;
				next_cycle.tv_sec++;
			}
			clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_cycle, nullptr);
		}
	}

	// ============================================================================
	// 注册回调
	// ============================================================================
	void EtherCATMaster::RegisterInputCallback(CyclicCallback cb)
	{
		input_callbacks_.push_back(std::move(cb));
	}

	void EtherCATMaster::RegisterOutputCallback(CyclicCallback cb)
	{
		output_callbacks_.push_back(std::move(cb));
	}

	// ============================================================================
	// 查询
	// ============================================================================
	const SlaveRuntime *EtherCATMaster::GetSlaveRuntime(uint16_t position) const
	{
		auto it = slaves_.find(position);
		return (it != slaves_.end()) ? &it->second : nullptr;
	}

	std::vector<const SlaveRuntime *> EtherCATMaster::GetSlavesByRole(SlaveRole role) const
	{
		std::vector<const SlaveRuntime *> result;
		for (const auto &[pos, rt] : slaves_)
		{
			if (rt.role == role)
				result.push_back(&rt);
		}
		return result;
	}

	// ============================================================================
	// 扫描总线上所有已连接的从站
	// ============================================================================
	std::vector<ScannedSlaveInfo> EtherCATMaster::ScanSlaves() const
	{
		std::lock_guard<std::mutex> lock(config_mutex_);

		std::vector<ScannedSlaveInfo> results;
		if (!master_)
			return results;

		// ecrt_master() fills ec_master_info_t (slave_count etc.); not to be
		// confused with ecrt_request_master() which returns the master handle.
		ec_master_info_t master_info;
		if (ecrt_master(master_, &master_info) != 0)
		{
			fprintf(stderr, "ECMaster: ScanSlaves - ecrt_master() failed\n");
			return results;
		}

		const uint32_t slave_count = master_info.slave_count;
		for (uint32_t i = 0; i < slave_count; ++i)
		{
			ec_slave_info_t info;
			if (ecrt_master_get_slave(master_, static_cast<uint16_t>(i), &info) != 0)
				continue;

			ScannedSlaveInfo s;
			s.position = info.position;
			s.alias = info.alias;
			s.vendor_id = info.vendor_id;
			s.product_code = info.product_code;
			s.description = info.name;
			results.push_back(s);
		}

		return results;
	}

} // namespace weighing