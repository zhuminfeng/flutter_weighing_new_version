#ifndef ETHERCAT_INPUT_H
#define ETHERCAT_INPUT_H

#include "input_source.h"
#include "../ethercat/ethercat_master.h"
#include <vector>
#include <atomic>

namespace weighing
{
	class EtherCATInput : public InputSource
	{
	public:
		EtherCATInput();
		~EtherCATInput() override;

		bool Initialize(const std::string &config_path) override;
		bool Start() override;
		void Stop() override;
		bool IsRunning() const override { return running_.load(); }
		InputMode GetMode() const override { return InputMode::kEtherCAT; }
		int GetChannelCount() const override { return static_cast<int>(weighing_slave_positions_.size()); }

	private:
		void OnCyclicReceive(uint8_t *domain_data);

		std::atomic<bool> running_{false};
		std::vector<uint16_t> weighing_slave_positions_;
	};

} // namespace weighing

#endif // ETHERCAT_INPUT_H