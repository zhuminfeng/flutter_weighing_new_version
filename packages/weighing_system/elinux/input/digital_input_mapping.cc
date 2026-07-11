#include "digital_input_mapping.h"
#include <sstream>

namespace weighing
{

	bool DigitalInputMap::Validate(std::string *err) const
	{
		const int kMaxSignal = static_cast<int>(DigitalInputSignalType::kCustomKey4);
		for (const auto &b : cfg_.bindings)
		{
			if (b.bit_index > 15)
			{
				if (err)
					*err = "bit_index out of range: " + std::to_string(b.bit_index);
				return false;
			}
			// if (b.channel > 1)
			// {
			// 	if (err)
			// 		*err = "channel out of range: " + std::to_string(b.channel);
			// 	return false;
			// }
			if (static_cast<int>(b.signal) < 0 || static_cast<int>(b.signal) > kMaxSignal)
			{
				if (err)
					*err = "signal out of range: " + std::to_string(static_cast<int>(b.signal));
				return false;
			}
		}
		return true;
	}

	bool DigitalInputMap::SetConfig(const DigitalInputMapConfig &cfg, std::string *err)
	{
		cfg_ = cfg;
		return Validate(err);
	}

} // namespace weighing