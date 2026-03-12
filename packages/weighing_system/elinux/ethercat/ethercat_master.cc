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
		{
			fprintf(stderr, "ECMaster: Master not initialized\n");
			return false;
		}

		ec_slave_config_t *sc = ecrt_master_slave_config(
			master_, desc.alias, desc.position, desc.vendor_id, desc.product_code);
		if (!sc)
		{
			fprintf(stderr, "ECMaster: Failed to get slave config for pos=%u "
							"(VID=0x%08X PID=0x%08X)\n",
					desc.position, desc.vendor_id, desc.product_code);
			return false;
		}

		// 创建运行时记录
		SlaveRuntime rt{};
		rt.descriptor = desc;
		rt.role = desc.role;
		if (rt.role == SlaveRole::kUnknown)
		{
			rt.role = IdentifySlave(desc.vendor_id, desc.product_code);
		}
		memset(&rt.offsets, 0, sizeof(rt.offsets));

		// 按类型配置 PDO
		bool ok = false;
		switch (rt.role)
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
			fprintf(stderr, "ECMaster: Unknown slave role at pos=%u\n", desc.position);
			return false;
		}

		if (!ok)
			return false;

		rt.configured = true;
		slave_configs_.push_back(sc);
		slaves_[desc.position] = rt;

		printf("ECMaster: Slave configured - pos=%u role=%d desc='%s'\n",
			   desc.position, static_cast<int>(rt.role), desc.description.c_str());
		return true;
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
		static ec_pdo_entry_info_t entries[] = {
			// RxPDO (0x1701)
			{0x6040, 0x00, 16}, // Control Word
			{0x607A, 0x00, 32}, // Target Position
			{0x60B8, 0x00, 16}, // Touch Probe Function
			{0x60FE, 0x01, 32}, // Digital Outputs
			// TxPDO (0x1B01)
			{0x603F, 0x00, 16}, // Error Code
			{0x6041, 0x00, 16}, // Status Word
			{0x6064, 0x00, 32}, // Actual Position
			{0x6077, 0x00, 16}, // Actual Torque
			{0x60F4, 0x00, 32}, // Following Error
			{0x60B9, 0x00, 16}, // Touch Probe Status
			{0x60BA, 0x00, 32}, // Touch Probe Pos1
			{0x60BC, 0x00, 32}, // Touch Probe Pos2
			{0x60FD, 0x00, 32}, // Digital Inputs
		};

		static ec_pdo_info_t pdos[] = {
			{0x1701, 4, entries + 0},
			{0x1B01, 9, entries + 4},
		};

		static ec_sync_info_t syncs[] = {
			{0, EC_DIR_OUTPUT, 0, NULL, EC_WD_DISABLE},
			{1, EC_DIR_INPUT, 0, NULL, EC_WD_DISABLE},
			{2, EC_DIR_OUTPUT, 1, pdos + 0, EC_WD_ENABLE},
			{3, EC_DIR_INPUT, 1, pdos + 1, EC_WD_DISABLE},
			{0xff}};

		if (ecrt_slave_config_pdos(sc, EC_END, syncs))
		{
			fprintf(stderr, "ECMaster: PDO config failed for InoSV630N\n");
			return false;
		}

		// 【新增 1】：配置分布式时钟 DC (0x0300, 周期1ms = 1000000ns)
		ecrt_slave_config_dc(sc, 0x0300, 1000000, 0, 0, 0);

		// 【新增 2】：通过 SDO 将运行模式(0x6060)设为 8 (CSP: 周期同步位置模式)
		// 因为你的 ServoController 是通过不断累加 TargetPosition (0x607A) 来控制的
		ecrt_slave_config_sdo8(sc, 0x6060, 0, 8);

		uint16_t pos = rt.descriptor.position;
		uint32_t vid = inosv630n::VENDOR_ID;
		uint32_t pid = inosv630n::PRODUCT_CODE;

		// RxPDO offsets
		pdo_regs_.push_back({0, pos, vid, pid, 0x6040, 0x00, &rt.offsets.servo.off_control_word});
		pdo_regs_.push_back({0, pos, vid, pid, 0x607A, 0x00, &rt.offsets.servo.off_target_position});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60B8, 0x00, &rt.offsets.servo.off_touch_probe_func});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60FE, 0x01, &rt.offsets.servo.off_digital_outputs});

		// TxPDO offsets
		pdo_regs_.push_back({0, pos, vid, pid, 0x603F, 0x00, &rt.offsets.servo.off_error_code});
		pdo_regs_.push_back({0, pos, vid, pid, 0x6041, 0x00, &rt.offsets.servo.off_status_word});
		pdo_regs_.push_back({0, pos, vid, pid, 0x6064, 0x00, &rt.offsets.servo.off_actual_position});
		pdo_regs_.push_back({0, pos, vid, pid, 0x6077, 0x00, &rt.offsets.servo.off_actual_torque});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60F4, 0x00, &rt.offsets.servo.off_following_error});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60B9, 0x00, &rt.offsets.servo.off_touch_probe_stat});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60BA, 0x00, &rt.offsets.servo.off_touch_probe_pos1});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60BC, 0x00, &rt.offsets.servo.off_touch_probe_pos2});
		pdo_regs_.push_back({0, pos, vid, pid, 0x60FD, 0x00, &rt.offsets.servo.off_digital_inputs});

		return true;
	}

	// ============================================================================
	// PDO 配置 - 称重从站 (根据实际从站型号调整)
	// ============================================================================
	bool EtherCATMaster::ConfigureWeighing(ec_slave_config_t *sc, SlaveRuntime &rt)
	{
		// 称重从站的 PDO 配置取决于具体型号
		// 这里给出通用框架，实际使用时按从站手册填写

		static ec_pdo_entry_info_t entries[] = {
			{0x6000, 0x01, 32}, // 原始重量/ADC值 (示例)
			{0x6000, 0x02, 16}, // 状态字 (示例)
		};

		static ec_pdo_info_t pdos[] = {
			{0x1a00, 2, entries + 0},
		};

		static ec_sync_info_t syncs[] = {
			{0, EC_DIR_OUTPUT, 0, NULL, EC_WD_DISABLE},
			{1, EC_DIR_INPUT, 0, NULL, EC_WD_DISABLE},
			{2, EC_DIR_OUTPUT, 0, NULL, EC_WD_DISABLE},
			{3, EC_DIR_INPUT, 1, pdos + 0, EC_WD_DISABLE},
			{0xff}};

		if (ecrt_slave_config_pdos(sc, EC_END, syncs))
		{
			fprintf(stderr, "ECMaster: PDO config failed for weighing slave\n");
			return false;
		}

		uint16_t pos = rt.descriptor.position;
		uint32_t vid = rt.descriptor.vendor_id;
		uint32_t pid = rt.descriptor.product_code;

		pdo_regs_.push_back({0, pos, vid, pid, 0x6000, 0x01, &rt.offsets.weighing.off_weight_raw});
		pdo_regs_.push_back({0, pos, vid, pid, 0x6000, 0x02, &rt.offsets.weighing.off_status});

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

} // namespace weighing