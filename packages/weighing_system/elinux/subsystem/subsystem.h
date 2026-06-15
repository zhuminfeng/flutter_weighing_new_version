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
	/// 秤台使用模式
	enum class ScaleMode : int
	{
		kSingle = 0,		// 单秤台模式（多机联动失重秤）
		kDualCoarseFine = 1 // 粗精秤组合（罐装应用）
	};

	struct SubsystemConfig
	{
		uint32_t id = 0;
		std::string name;
		AppType app_type = AppType::kLossInWeight;
		// ===== 秤台配置 =====
		ScaleMode scale_mode = ScaleMode::kSingle; // 秤台使用模式
		std::vector<uint32_t> scale_ids;		   // 秤台 ID 列表
												   // - 单秤台模式: scale_ids[0] 是唯一的秤台
		// - 粗精秤模式: scale_ids[0]=粗秤, scale_ids[1]=精秤

		// ===== EtherCAT 配置 =====
		std::vector<uint32_t> ethercat_slave_ids;

		// ===== 输出映射 =====
		uint32_t digital_io_pos = 0;
		uint32_t servo_pos = 0;

		// ===== 物料信息 =====
		std::string material_name;
		std::string material_code;

		// ===== 优先级和启用状态 =====
		int priority = 0;
		bool enabled = true;
		bool register_to_central = true; // 是否注册到中央控制器
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
		std::string GetName() const { return config_.name; }
		std::string GetMaterialName() const { return config_.material_name; }
		int GetPriority() const { return config_.priority; }
		bool IsEnabled() const { return config_.enabled; }
		ScaleMode GetScaleMode() const { return config_.scale_mode; }
		AppBase *GetApplication() { return app_.get(); }
		LiwApplication *GetLiwApp();
		FillingApplication *GetFillingApp();

		// ===== 秤台访问（兼容两种模式）=====
		ScalePlatform *GetPrimaryScale();			 // 获取主秤台（单秤台/粗秤）
		ScalePlatform *GetScale(uint16_t channel);	 // 获取指定通道的秤台
		const std::vector<ScalePlatform *> &GetAllScales() const; // 获取所有秤台
		size_t GetScaleCount() const { return scales_.size(); }

		// Weight data routing
		void OnScaleWeightUpdate(uint32_t scale_id, const WeightData &data);

		// DIO（统一使用 HandleDioInputs，与 SystemInitializer 回调中的调用名一致）
		void HandleDioInputs(const DioInputSignals &signals);
		DioOutputSignals GetDioOutputs() const;

		SubsystemConfig GetConfig() const { return config_; }
		void SetEnabled(bool enabled);

	private:
		void BuildScaleChannelMapping();

		SubsystemConfig config_;
		std::unique_ptr<AppBase> app_;
		std::vector<ScalePlatform *> scales_;
		std::map<uint32_t, uint16_t> scale_to_channel_; // scale_id -> channel
		std::map<uint16_t, uint32_t> channel_to_scale_; // channel -> scale_id
	};

} // namespace weighing

#endif // SUBSYSTEM_H