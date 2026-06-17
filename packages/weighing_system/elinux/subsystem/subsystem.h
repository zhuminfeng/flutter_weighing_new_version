#ifndef SUBSYSTEM_H
#define SUBSYSTEM_H

#include "../common_types.h"
#include "../scale/scale_platform.h"
#include "../application/app_base.h"
#include "../application/liw/liw_application.h"
#include "../application/filling/filling_application.h"
// 删除: #include "../dio/dio_manager.h"
#include <memory>
#include <vector>

namespace weighing
{

	struct SubsystemConfig
	{
		uint32_t id = 0;
		std::string name;
		AppType app_type = AppType::kLossInWeight;
		std::vector<uint32_t> scale_ids;
		std::vector<uint32_t> ethercat_slave_ids;
		DioInputMapping dio_input_mapping;   // 离散输入自定义映射
		DioOutputMapping dio_output_mapping; // 离散输出自定义映射
	};

	class Subsystem
	{
	public:
		explicit Subsystem(const SubsystemConfig &config);
		~Subsystem();

		bool Initialize();
		void Start();
		void Stop();

		// Access
		uint32_t GetId() const { return config_.id; }
		AppBase *GetApplication() { return app_.get(); }
		LiwApplication *GetLiwApp();
		FillingApplication *GetFillingApp();
		std::vector<ScalePlatform *> GetScales();

		// Weight data routing
		void OnScaleWeightUpdate(const WeightData &data);

		// DIO（统一使用 HandleDioInputs，与 SystemInitializer 回调中的调用名一致）
		void HandleDioInputs(const DioInputSignals &signals);
		DioOutputSignals GetDioOutputs() const;

		// 根据子系统的离散输入映射，将原始硬件输入字转换为逻辑信号
		DioInputSignals ApplyDioMapping(uint16_t raw_inputs) const;

		SubsystemConfig GetConfig() const { return config_; }
		void UpdateDioInputMapping(const DioInputMapping &mapping) { config_.dio_input_mapping = mapping; }
		void UpdateDioOutputMapping(const DioOutputMapping &mapping) { config_.dio_output_mapping = mapping; }
		void UpdateName(const std::string &name) { config_.name = name; }

	private:
		SubsystemConfig config_;
		std::unique_ptr<AppBase> app_;
		std::vector<ScalePlatform *> scales_;
	};

} // namespace weighing

#endif // SUBSYSTEM_H