#ifndef DIGITAL_INPUT_MAPPING_H
#define DIGITAL_INPUT_MAPPING_H

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace weighing
{

	/// 离散输入信号类型（与 Dart DigitalInputSignalType 枚举一一对应）
	enum class DigitalInputSignalType : int
	{
		kStartSignal = 0,
		kStopSignal = 1,
		kResetSignal = 2,
		kZeroSignal = 3,
		kTareSignal = 4,
		kRefillRequest = 5,
		kEmergencyStop = 6,
		kCustomKey1 = 7,
		kCustomKey2 = 8,
		kCustomKey3 = 9,
		kCustomKey4 = 10,
	};

	struct DigitalInputBinding
	{
		uint32_t subsystem_id = 0;
		uint16_t io_pos = 0;
		uint16_t channel = 0;
		uint8_t bit_index = 0; // 0..15
		DigitalInputSignalType signal = DigitalInputSignalType::kStartSignal;
		bool active_high = true;
		bool enabled = true;
		int app_scope = -1; // -1 both, 0 LIW, 1 Filling
	};

	struct DigitalInputMapConfig
	{
		int version = 1;
		std::vector<DigitalInputBinding> bindings;
	};

	class DigitalInputMap
	{
	public:
		bool SetConfig(const DigitalInputMapConfig &cfg, std::string *err = nullptr);
		const DigitalInputMapConfig &GetConfig() const { return cfg_; }

		bool Validate(std::string *err) const;

	private:
		DigitalInputMapConfig cfg_;
	};

} // namespace weighing

#endif
