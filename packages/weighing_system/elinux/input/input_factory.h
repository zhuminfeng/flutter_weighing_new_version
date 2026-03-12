#ifndef INPUT_FACTORY_H
#define INPUT_FACTORY_H

#include "input_source.h"
#include <memory>
#include <string>

namespace weighing
{

	class InputFactory
	{
	public:
		static std::unique_ptr<InputSource> Create(const std::string &config_path);
		static InputMode ParseInputMode(const std::string &config_path);
	};

} // namespace weighing

#endif // INPUT_FACTORY_H