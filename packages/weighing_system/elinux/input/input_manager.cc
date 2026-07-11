#include "input_manager.h"
#include <cstdio>

namespace weighing
{

	InputManager &InputManager::Instance()
	{
		static InputManager instance;
		return instance;
	}

	bool InputManager::Initialize()
	{
		initialized_ = true;
		return true;
	}

	bool InputManager::Start()
	{
		if (!initialized_)
			return false;

		// 向主站注册输入回调：在读取完从站数据后、处理子系统逻辑前触发
		EtherCATMaster::Instance().RegisterInputCallback(
			[this](uint8_t *domain_data)
			{
				OnCyclicInput(domain_data);
			});

		printf("InputManager: Started\n");
		return true;
	}

	void InputManager::Stop()
	{
		printf("InputManager: Stopped\n");
	}

	bool InputManager::UpdateDigitalInputMap(const DigitalInputMapConfig &cfg, std::string *err)
	{
		if (!input_map_.SetConfig(cfg, err))
			return false;
		return true;
	}

	DigitalInputMapConfig InputManager::GetDigitalInputMapConfig() const
	{
		return input_map_.GetConfig();
	}

	void InputManager::OnCyclicInput(uint8_t *domain_data)
	{
		if (!domain_data)
			return;

		// 临时存储各子系统的当前输入信号状态
		std::map<uint32_t, DioInputSignals> sub_signals;
		const auto &cfg = input_map_.GetConfig();

		// === 核心逻辑：遍历所有绑定的数字量输入规则 ===
		for (const auto &b : cfg.bindings)
		{
			if (!b.enabled)
				continue;

			// 1. 查找物理从站运行时偏移
			const auto *rt = EtherCATMaster::Instance().GetSlaveRuntime(b.io_pos);
			if (!rt || rt->role != SlaveRole::kDigitalIO)
				continue;

			// 2. 读取物理层 16 位输入状态
			uint16_t di = EC_READ_U16(domain_data + rt->offsets.io.off_di);

			// 3. 判断该位是否触发，并结合极性(Active High/Low)计算出最终逻辑有效性
			bool is_set = (di & (1 << b.bit_index)) != 0;
			bool active = b.active_high ? is_set : !is_set;

			// 4. 如果信号有效，将其赋值到对应的子系统逻辑上
			if (active)
			{
				auto &sigs = sub_signals[b.subsystem_id];
				switch (b.signal)
				{
				case DigitalInputSignalType::kStartSignal:
					sigs.start = true;
					break;
				case DigitalInputSignalType::kStopSignal:
					sigs.stop = true;
					break;
				case DigitalInputSignalType::kZeroSignal:
					sigs.zero = true;
					break;
				case DigitalInputSignalType::kTareSignal:
					sigs.tare = true;
					break;
				case DigitalInputSignalType::kRefillRequest:
					sigs.execute_refill = true;
					break;
				case DigitalInputSignalType::kEmergencyStop:
					sigs.interlock = true;
					break;
				// kResetSignal, kCustomKey 等可以根据需求继续扩充
				default:
					break;
				}
			}
		}

		// === 将构建好的多路逻辑信号精准分发给对应的子系统 ===
		if (dio_callback_)
		{
			for (const auto &[sub_id, sigs] : sub_signals)
			{
				dio_callback_(sub_id, sigs);
			}
		}
	}

} // namespace weighing