#ifndef ETHERCAT_MASTER_H
#define ETHERCAT_MASTER_H

#include "ethercat_types.h"
#include "ethercat_slave_config.h"
#include <ecrt.h>

#include <cstdint>
#include <vector>
#include <map>
#include <thread>
#include <atomic>
#include <mutex>
#include <functional>

namespace weighing
{

	/// Cyclic callback: 在每个 EtherCAT 周期内被调用
	using CyclicCallback = std::function<void(uint8_t *domain_data)>;

	/// 统一的 EtherCAT 主站
	/// 不区分输入/输出从站 —— 所有从站共享同一个 Master 和 Domain
	/// 输入层和输出层各自注册回调来处理自己关心的从站数据
	class EtherCATMaster
	{
	public:
		static EtherCATMaster &Instance();

		// ===== 生命周期 =====
		bool Initialize(unsigned int master_index = 0);
		void Shutdown();

		// ===== 从站注册（Activate前调用） =====
		bool AddSlave(const SlaveDescriptor &desc);

		// ===== 激活 =====
		bool Activate();

		// ===== RT 线程 =====
		bool StartCyclicThread(uint32_t cycle_time_us = 1000);
		void StopCyclicThread();

		// ===== 回调注册 =====
		/// input callback: receive 之后立即调用（读 TxPDO）
		void RegisterInputCallback(CyclicCallback cb);
		/// output callback: input 之后调用（写 RxPDO）
		void RegisterOutputCallback(CyclicCallback cb);

		// ===== 从站查询 =====
		const SlaveRuntime *GetSlaveRuntime(uint16_t position) const;
		std::vector<const SlaveRuntime *> GetSlavesByRole(SlaveRole role) const;

		/// 扫描总线上当前连接的所有 EtherCAT 从站
		std::vector<ScannedSlaveInfo> ScanSlaves() const;

		bool IsOperational() const { return operational_.load(); }
		uint8_t *GetDomainData() { return domain_data_; }

	private:
		EtherCATMaster() = default;
		~EtherCATMaster() { Shutdown(); }
		EtherCATMaster(const EtherCATMaster &) = delete;
		EtherCATMaster &operator=(const EtherCATMaster &) = delete;

		bool ConfigureDigitalIO(ec_slave_config_t *sc, SlaveRuntime &rt);
		bool ConfigureServo(ec_slave_config_t *sc, SlaveRuntime &rt);
		bool ConfigureWeighing(ec_slave_config_t *sc, SlaveRuntime &rt);

		void CyclicThread();

		ec_master_t *master_ = nullptr;
		ec_domain_t *domain_ = nullptr;
		uint8_t *domain_data_ = nullptr;

		std::vector<ec_slave_config_t *> slave_configs_;
		std::map<uint16_t, SlaveRuntime> slaves_; // key = position
		std::vector<ec_pdo_entry_reg_t> pdo_regs_;

		std::vector<CyclicCallback> input_callbacks_;
		std::vector<CyclicCallback> output_callbacks_;

		std::unique_ptr<std::thread> cyclic_thread_;
		std::atomic<bool> running_{false};
		std::atomic<bool> operational_{false};
		uint32_t cycle_time_us_ = 1000;

		mutable std::mutex config_mutex_;
	};

} // namespace weighing

#endif // ETHERCAT_MASTER_H