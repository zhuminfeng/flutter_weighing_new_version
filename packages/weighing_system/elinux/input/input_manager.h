/**
 * @file input_manager.h
 * @brief 负责管理离散输入的动态路由.
 */
#ifndef INPUT_MANAGER_H
#define INPUT_MANAGER_H

#include "../common_types.h"
#include "../ethercat/ethercat_master.h"
#include "digital_input_mapping.h"

#include <map>
#include <vector>
#include <functional>
#include <string>

namespace weighing
{
	// 回调直接传递子系统ID，而不再是物理从站的pos，真正实现逻辑与物理的解耦
	using DioInputCallback = std::function<void(uint32_t subsystem_id, const DioInputSignals &signals)>;

	class InputManager
	{
	public:
		static InputManager &Instance();

		bool Initialize();
		bool Start();
		void Stop();

		// 热更新离散输入配置映射表
		bool UpdateDigitalInputMap(const DigitalInputMapConfig &cfg, std::string *err = nullptr);
		DigitalInputMapConfig GetDigitalInputMapConfig() const;

		// 注册回调，用于将解析后的逻辑信号传递给子系统
		void SetDioInputCallback(DioInputCallback cb) { dio_callback_ = cb; }

	private:
		InputManager() = default;
		~InputManager() { Stop(); }

		// EtherCAT Master 的实时回调函数
		void OnCyclicInput(uint8_t *domain_data);

		DigitalInputMap input_map_;
		DioInputCallback dio_callback_;
		bool initialized_ = false;
	};

} // namespace weighing

#endif // INPUT_MANAGER_H