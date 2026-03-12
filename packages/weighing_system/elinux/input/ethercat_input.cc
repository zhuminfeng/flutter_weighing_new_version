#include "ethercat_input.h"
#include <cstdio>
#include <ctime>

namespace weighing
{

	EtherCATInput::EtherCATInput()
	{
	}

	EtherCATInput::~EtherCATInput()
	{
		Stop();
	}

	bool EtherCATInput::Initialize(const std::string &config_path)
	{
		// 查询所有称重从站（此时 Master 已激活）
		auto weighing_slaves = EtherCATMaster::Instance().GetSlavesByRole(SlaveRole::kWeighingInput);
		for (const auto *rt : weighing_slaves)
		{
			weighing_slave_positions_.push_back(rt->descriptor.position);
		}
		printf("EtherCATInput: Found %zu weighing slaves\n", weighing_slave_positions_.size());
		return !weighing_slave_positions_.empty();
	}

	bool EtherCATInput::Start()
	{
		if (running_.load())
			return true;

		if (weighing_slave_positions_.empty())
		{
			fprintf(stderr, "EtherCATInput: No weighing slaves configured. Call Initialize() first.\n");
			return false;
		}

		// 只注册 input callback，不启动 Master（Master 由 SystemInitializer 管理）
		EtherCATMaster::Instance().RegisterInputCallback(
			[this](uint8_t *domain_data)
			{
				OnCyclicReceive(domain_data);
			});

		running_.store(true);
		printf("EtherCATInput: Input callback registered\n");
		return true;
	}

	void EtherCATInput::Stop()
	{
		running_.store(false);
		printf("EtherCATInput: Stopped\n");
	}

	void EtherCATInput::OnCyclicReceive(uint8_t *domain_data)
	{
		if (!running_.load() || !adc_callback_)
			return;

		struct timespec ts;
		clock_gettime(CLOCK_MONOTONIC, &ts);
		uint64_t now_ns = static_cast<uint64_t>(ts.tv_sec) * 1000000000ULL + ts.tv_nsec;

		for (uint16_t pos : weighing_slave_positions_)
		{
			const auto *rt = EtherCATMaster::Instance().GetSlaveRuntime(pos);
			if (!rt || !rt->configured)
				continue;

			AdcSample sample{};
			sample.channel_id = pos;
			sample.timestamp_ns = now_ns;
			sample.raw_value = EC_READ_S32(domain_data + rt->offsets.weighing.off_weight_raw);
			sample.status = EC_READ_U16(domain_data + rt->offsets.weighing.off_status);

			adc_callback_(sample);
		}
	}

} // namespace weighing