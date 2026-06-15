#include "include/weighing_system_elinux/weighing_system_elinux_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <thread>

#include "common_types.h"
#include "scale/scale_manager.h"
#include "subsystem/subsystem_manager.h"
#include "input/input_factory.h"
#include "output/output_manager.h"
#include "storage/database_manager.h"
#include "storage/config_store.h"
#include "storage/calibration_store.h"
#include "storage/weight_record_store.h"
#include "system/system_initializer.h"
#include "central/central_controller.h"
#include "central/recipe.h"

using namespace weighing;

namespace
{

	constexpr char kChannelName[] = "plugins.weighing_system/method";
	constexpr char kWeightEventChannel[] = "plugins.weighing_system/weight_events";
	constexpr char kStatusEventChannel[] = "plugins.weighing_system/status_events";

	// Helper: extract int from encodable value
	int GetInt(const flutter::EncodableMap &map, const std::string &key, int def = 0)
	{
		auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end())
		{
			if (auto *val = std::get_if<int32_t>(&it->second))
				return *val;
			if (auto *val = std::get_if<int64_t>(&it->second))
				return static_cast<int>(*val);
		}
		return def;
	}

	double GetDouble(const flutter::EncodableMap &map, const std::string &key, double def = 0.0)
	{
		auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end())
		{
			if (auto *val = std::get_if<double>(&it->second))
				return *val;
			if (auto *val = std::get_if<int32_t>(&it->second))
				return static_cast<double>(*val);
		}
		return def;
	}

	bool GetBool(const flutter::EncodableMap &map, const std::string &key, bool def = false)
	{
		auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end())
		{
			if (auto *val = std::get_if<bool>(&it->second))
				return *val;
			if (auto *val = std::get_if<int32_t>(&it->second))
				return *val != 0;
		}
		return def;
	}

	std::string GetString(const flutter::EncodableMap &map, const std::string &key,
						  const std::string &def = "")
	{
		auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end())
		{
			if (auto *val = std::get_if<std::string>(&it->second))
				return *val;
		}
		return def;
	}

	using EV = flutter::EncodableValue;
	using EMap = flutter::EncodableMap;
	using EList = flutter::EncodableList;

	bool GetIntField(const EMap &m, const char *key, int *out)
	{
		auto it = m.find(EV(key));
		if (it == m.end())
			return false;
		if (auto p = std::get_if<int>(&it->second))
		{
			*out = *p;
			return true;
		}
		if (auto p64 = std::get_if<int64_t>(&it->second))
		{
			*out = static_cast<int>(*p64);
			return true;
		}
		return false;
	}

	bool GetBoolField(const EMap &m, const char *key, bool *out)
	{
		auto it = m.find(EV(key));
		if (it == m.end())
			return false;
		if (auto p = std::get_if<bool>(&it->second))
		{
			*out = *p;
			return true;
		}
		return false;
	}

	bool ParseBinding(const EMap &item,
					  weighing::DigitalOutputBinding *out,
					  std::string *err)
	{
		int subsystem_id = 0, io_pos = 0, channel = 0, signal = 0, bit_index = 0, app_scope = -1;
		bool active_high = true, enabled = true;

		if (!GetIntField(item, "subsystem_id", &subsystem_id))
		{
			if (err)
				*err = "binding missing subsystem_id";
			return false;
		}
		if (!GetIntField(item, "io_pos", &io_pos))
		{
			if (err)
				*err = "binding missing io_pos";
			return false;
		}
		if (!GetIntField(item, "channel", &channel))
		{
			if (err)
				*err = "binding missing channel";
			return false;
		}
		if (!GetIntField(item, "signal", &signal))
		{
			if (err)
				*err = "binding missing signal";
			return false;
		}
		if (!GetIntField(item, "bit_index", &bit_index))
		{
			if (err)
				*err = "binding missing bit_index";
			return false;
		}

		// 可选字段
		(void)GetBoolField(item, "active_high", &active_high);
		(void)GetBoolField(item, "enabled", &enabled);
		(void)GetIntField(item, "app_scope", &app_scope);

		// 【修改】：校验范围扩展至 kBagClamp，兼容全伺服功能
		if (signal < 0 || signal > static_cast<int>(weighing::DigitalSignalType::kBagClamp))
		{
			if (err)
				*err = "binding signal out of range";
			return false;
		}

		out->subsystem_id = static_cast<uint32_t>(subsystem_id);
		out->io_pos = static_cast<uint16_t>(io_pos);
		out->channel = static_cast<uint16_t>(channel);
		out->signal = static_cast<weighing::DigitalSignalType>(signal);
		out->bit_index = static_cast<uint8_t>(bit_index);
		out->active_high = active_high;
		out->enabled = enabled;
		out->app_scope = app_scope;
		return true;
	}

	// === 【新增】：解析伺服映射绑定的独立函数 ===
	bool ParseServoBinding(const EMap &item,
						   weighing::ServoOutputBinding *out,
						   std::string *err)
	{
		int subsystem_id = 0, servo_pos = 0, channel = 0, signal = 0, app_scope = -1;
		bool enabled = true;

		if (!GetIntField(item, "subsystem_id", &subsystem_id))
		{
			if (err)
				*err = "servo_binding missing subsystem_id";
			return false;
		}
		if (!GetIntField(item, "servo_pos", &servo_pos))
		{
			if (err)
				*err = "servo_binding missing servo_pos";
			return false;
		}
		if (!GetIntField(item, "signal", &signal))
		{
			if (err)
				*err = "servo_binding missing signal";
			return false;
		}

		// 可选字段
		(void)GetBoolField(item, "enabled", &enabled);
		(void)GetIntField(item, "app_scope", &app_scope);

		if (signal < 0 || signal > static_cast<int>(weighing::DigitalSignalType::kBagClamp))
		{
			if (err)
				*err = "servo_binding signal out of range";
			return false;
		}

		out->subsystem_id = static_cast<uint32_t>(subsystem_id);
		out->servo_pos = static_cast<uint16_t>(servo_pos);
		out->signal = static_cast<weighing::DigitalSignalType>(signal);
		out->enabled = enabled;
		out->app_scope = app_scope;
		return true;
	}

	bool ParseDigitalOutputMapConfig(const EMap &args,
									 weighing::DigitalOutputMapConfig *cfg,
									 std::string *err)
	{
		int version = 1;
		(void)GetIntField(args, "version", &version);
		cfg->version = version;
		cfg->bindings.clear();
		cfg->servo_bindings.clear(); // 确保初始化时清空

		// ==========================================
		// 1. 解析传统的数字量 IO 绑定 (保持不变)
		// ==========================================
		auto it = args.find(EV("bindings"));
		if (it == args.end())
		{
			if (err)
				*err = "missing bindings";
			return false;
		}

		const auto *list = std::get_if<EList>(&it->second);
		if (!list)
		{
			if (err)
				*err = "bindings must be list";
			return false;
		}

		for (size_t i = 0; i < list->size(); ++i)
		{
			const auto *item_map = std::get_if<EMap>(&(*list)[i]);
			if (!item_map)
			{
				if (err)
					*err = "bindings[" + std::to_string(i) + "] must be map";
				return false;
			}
			weighing::DigitalOutputBinding b;
			std::string item_err;
			if (!ParseBinding(*item_map, &b, &item_err))
			{
				if (err)
					*err = "bindings[" + std::to_string(i) + "]: " + item_err;
				return false;
			}
			cfg->bindings.push_back(b);
		}

		// ==========================================
		// 2. 【新增】：解析伺服电机功能绑定
		// ==========================================
		auto it_servo = args.find(EV("servo_bindings"));
		if (it_servo != args.end())
		{
			const auto *servo_list = std::get_if<EList>(&it_servo->second);
			if (!servo_list)
			{
				if (err)
					*err = "servo_bindings must be list";
				return false;
			}

			for (size_t i = 0; i < servo_list->size(); ++i)
			{
				const auto *item_map = std::get_if<EMap>(&(*servo_list)[i]);
				if (!item_map)
				{
					if (err)
						*err = "servo_bindings[" + std::to_string(i) + "] must be map";
					return false;
				}
				weighing::ServoOutputBinding sb;
				std::string item_err;
				if (!ParseServoBinding(*item_map, &sb, &item_err))
				{
					if (err)
						*err = "servo_bindings[" + std::to_string(i) + "]: " + item_err;
					return false;
				}
				cfg->servo_bindings.push_back(sb);
			}
		}

		return true;
	}

	flutter::EncodableMap BuildMapResult(bool ok, const std::string &error = "")
	{
		flutter::EncodableMap out;
		out[EV("ok")] = EV(ok);
		out[EV("error")] = EV(error);
		return out;
	}

	flutter::EncodableMap WeightDataToMap(const WeightData &data)
	{
		flutter::EncodableMap map;
		map[flutter::EncodableValue("scaleId")] = flutter::EncodableValue(static_cast<int>(data.scale_id));
		map[flutter::EncodableValue("grossWeight")] = flutter::EncodableValue(data.gross_weight);
		map[flutter::EncodableValue("netWeight")] = flutter::EncodableValue(data.net_weight);
		map[flutter::EncodableValue("tareWeight")] = flutter::EncodableValue(data.tare_weight);
		map[flutter::EncodableValue("isStable")] = flutter::EncodableValue(data.motion == MotionState::kStable);
		map[flutter::EncodableValue("isZero")] = flutter::EncodableValue(data.is_zero);
		map[flutter::EncodableValue("isOverload")] = flutter::EncodableValue(data.is_overload);
		map[flutter::EncodableValue("isUnderload")] = flutter::EncodableValue(data.is_underload);
		map[flutter::EncodableValue("isNetMode")] = flutter::EncodableValue(data.is_net_mode);
		map[flutter::EncodableValue("unit")] = flutter::EncodableValue(static_cast<int>(data.unit));
		map[flutter::EncodableValue("timestampNs")] = flutter::EncodableValue(static_cast<int64_t>(data.timestamp_ns));
		return map;
	}

	flutter::EncodableMap RecipeToMap(const Recipe &recipe)
	{
		flutter::EncodableMap map;
		map[flutter::EncodableValue("recipeId")] = flutter::EncodableValue(static_cast<int>(recipe.recipe_id));
		map[flutter::EncodableValue("name")] = flutter::EncodableValue(recipe.name);
		map[flutter::EncodableValue("totalTargetFlow")] = flutter::EncodableValue(recipe.total_target_flow);
		map[flutter::EncodableValue("enableStaggerRefill")] = flutter::EncodableValue(recipe.enable_stagger_refill);
		map[flutter::EncodableValue("refillIntervalMin")] = flutter::EncodableValue(recipe.refill_interval_min);

		flutter::EncodableMap ratios;
		for (const auto &[sub_id, ratio] : recipe.subsystem_ratios)
		{
			ratios[flutter::EncodableValue(static_cast<int>(sub_id))] = flutter::EncodableValue(ratio);
		}
		map[flutter::EncodableValue("subsystemRatios")] = flutter::EncodableValue(ratios);

		return map;
	}

	Recipe MapToRecipe(const flutter::EncodableMap &map)
	{
		Recipe recipe;
		recipe.recipe_id = GetInt(map, "recipeId");
		recipe.name = GetString(map, "name", "");
		recipe.total_target_flow = GetDouble(map, "totalTargetFlow");
		recipe.enable_stagger_refill = GetBool(map, "enableStaggerRefill", true);
		recipe.refill_interval_min = GetDouble(map, "refillIntervalMin", 10.0);

		auto it = map.find(flutter::EncodableValue("subsystemRatios"));
		if (it != map.end() && std::holds_alternative<flutter::EncodableMap>(it->second))
		{
			const auto *ratios_map = std::get_if<flutter::EncodableMap>(&it->second);
			for (const auto &[key, value] : *ratios_map)
			{
				if (std::holds_alternative<int>(key) && std::holds_alternative<double>(value))
				{
					uint32_t sub_id = std::get<int>(key);
					double ratio = std::get<double>(value);
					recipe.subsystem_ratios[sub_id] = ratio;
				}
			}
		}

		return recipe;
	}

	flutter::EncodableMap SubsystemStatusToMap(const SubsystemStatus &status)
	{
		flutter::EncodableMap map;
		map[flutter::EncodableValue("subsystemId")] = flutter::EncodableValue(static_cast<int>(status.subsystem_id));
		map[flutter::EncodableValue("actualFlow")] = flutter::EncodableValue(status.actual_flow);
		map[flutter::EncodableValue("targetFlow")] = flutter::EncodableValue(status.target_flow);
		map[flutter::EncodableValue("controlRate")] = flutter::EncodableValue(status.control_rate);
		map[flutter::EncodableValue("remainingWeight")] = flutter::EncodableValue(status.remaining_weight);
		map[flutter::EncodableValue("accumulatedWeight")] = flutter::EncodableValue(status.accumulated_weight);
		map[flutter::EncodableValue("isRefilling")] = flutter::EncodableValue(status.is_refilling);
		map[flutter::EncodableValue("isFault")] = flutter::EncodableValue(status.is_fault);
		map[flutter::EncodableValue("refillCount")] = flutter::EncodableValue(status.refill_count);
		return map;
	}

	class WeighingSystemPlugin : public flutter::Plugin
	{
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrar *registrar);

		WeighingSystemPlugin(flutter::PluginRegistrar *registrar) {}
		// : registrar_(registrar) {}

		~WeighingSystemPlugin() override
		{
			StopMockThread();
			StopWeightEventStream();
			SystemInitializer::Instance().Shutdown();
		}

	private:
		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue> &call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === System ===
		void HandleInitialize(const flutter::EncodableMap &args,
							  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleShutdown(
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Scale ===
		void HandleUpdateScaleParams(const flutter::EncodableMap &args,
									 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetScaleParams(const flutter::EncodableMap &args,
								  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateZeroConfig(const flutter::EncodableMap &args,
									std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetZeroConfig(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateTareConfig(const flutter::EncodableMap &args,
									std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetTareConfig(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFilterStability(const flutter::EncodableMap &args,
										 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFilterStability(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Scale operations ===
		void HandleDoZero(const flutter::EncodableMap &args,
						  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleDoTare(const flutter::EncodableMap &args,
						  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleClearTare(const flutter::EncodableMap &args,
							 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleSetPresetTare(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Calibration ===
		void HandleTriggerCalZero(const flutter::EncodableMap &args,
								  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleTriggerCalSpan(const flutter::EncodableMap &args,
								  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleTriggerSaveCalibration(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleTriggerAbortCalibration(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleTriggerStepCalibration(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === LIW config ===
		void HandleUpdateLiwBaseConfig(const flutter::EncodableMap &args,
									   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwBaseConfig(const flutter::EncodableMap &args,
									std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwSystemConfig(const flutter::EncodableMap &args,
										 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwSystemConfig(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwSystemIdConfig(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwSystemIdConfig(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwControllerConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwControllerConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwRefillConfig(const flutter::EncodableMap &args,
										 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwRefillConfig(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwTargetValuesConfig(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwTargetValuesConfig(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwToleranceCheckConfig(const flutter::EncodableMap &args,
												 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwToleranceCheckConfig(const flutter::EncodableMap &args,
											  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwEmptyingConfig(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwEmptyingConfig(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwWarningConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwWarningConfig(const flutter::EncodableMap &args,
									   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwFlowMonitorConfig(const flutter::EncodableMap &args,
											  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwFlowMonitorConfig(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwAdvancedConfig(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwAdvancedConfig(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateLiwStatsConfig(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetLiwStatsConfig(const flutter::EncodableMap &args,
									 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Filling config handlers ===
		void HandleUpdateFillingGeneralConfig(const flutter::EncodableMap &args,
											  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingGeneralConfig(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingSystemConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingSystemConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingTargetConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingTargetConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingAutoTareConfig(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingAutoTareConfig(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingToleranceConfig(const flutter::EncodableMap &args,
												std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingToleranceConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingSpillOptConfig(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingSpillOptConfig(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingCutoffOptConfig(const flutter::EncodableMap &args,
												std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingCutoffOptConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingJogConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingJogConfig(const flutter::EncodableMap &args,
									   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingRefillConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingRefillConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingEmptyingConfig(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingEmptyingConfig(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingEventsConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingEventsConfig(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateFillingAdvancedConfig(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetFillingAdvancedConfig(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Application control ===
		void HandleStartApp(const flutter::EncodableMap &args,
							std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleStopApp(const flutter::EncodableMap &args,
						   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleSetManualControlRate(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetAppStatus(const flutter::EncodableMap &args,
								std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === Digital output mapping ===
		void HandleUpdateDigitalOutputMapConfig(const flutter::EncodableMap &args,
												std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleValidateDigitalOutputMapConfig(const flutter::EncodableMap &args,
												  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetDigitalOutputMapConfig(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// ===== CentralController Methods =====
		void HandleLoadRecipe(const flutter::EncodableMap &args,
							  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleSaveRecipe(const flutter::EncodableMap &args,
							  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetAllRecipes(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleDeleteRecipe(const flutter::EncodableMap &args,
								std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		void HandleSetMasterFlow(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetMasterFlow(const flutter::EncodableMap &args,
								 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetTotalActualFlow(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		void HandleGetSubsystemStatus(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetAllSubsystemStatuses(const flutter::EncodableMap &args,
										   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		void HandleStartBatch(const flutter::EncodableMap &args,
							  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleEndBatch(const flutter::EncodableMap &args,
							std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetCurrentBatchId(const flutter::EncodableMap &args,
									 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === HMI Subsystem Config ===
		void HandleScanEthercatSlaves(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetInputMode(const flutter::EncodableMap &args,
								std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetSubsystemMappings(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateSubsystemMapping(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleUpdateSlaveAlias(const flutter::EncodableMap &args,
									std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleAddSubsystemMapping(const flutter::EncodableMap &args,
									   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleRemoveSubsystemMapping(const flutter::EncodableMap &args,
										  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// === 硬件配置状态 ===
		void HandleGetConfigStatus(const flutter::EncodableMap &args,
								   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleSaveEthercatHardwareConfig(const flutter::EncodableMap &args,
											  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// ===== 物料配方管理 =====
		void HandleSaveMaterialRecipe(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleLoadMaterialRecipe(const flutter::EncodableMap &args,
									  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleGetAllMaterialRecipes(const flutter::EncodableMap &args,
										 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
		void HandleDeleteMaterialRecipe(const flutter::EncodableMap &args,
										std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

		// flutter::PluginRegistrar *registrar_;
		std::unique_ptr<InputSource> input_source_;
		std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> weight_event_sink_;
		std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_event_sink_;

		// Weight event stream management
		void StartWeightEventStream();

		void StopWeightEventStream();

		// ================= MOCK MODE 样例数据环境 =================
		std::unique_ptr<std::thread> mock_thread_;
		std::atomic<bool> mock_thread_running_{false};

		// 【新增】：用于直接喂给 UI 的平滑显示数据
		std::atomic<double> mock_ui_flow_{0.0};
		std::atomic<double> mock_ui_weight_{10.0};
		std::string mock_ui_status_ = "Idle";
		std::mutex mock_ui_mutex_;

		void StartMockThread();
		void StopMockThread();
	};

	// static
	void WeighingSystemPlugin::RegisterWithRegistrar(flutter::PluginRegistrar *registrar)
	{
		auto plugin = std::make_unique<WeighingSystemPlugin>(registrar);

		// Method channel
		auto method_channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), kChannelName,
				&flutter::StandardMethodCodec::GetInstance());

		method_channel->SetMethodCallHandler(
			[plugin_ptr = plugin.get()](const auto &call, auto result)
			{
				plugin_ptr->HandleMethodCall(call, std::move(result));
			});

		// Weight event channel
		auto weight_event_channel =
			std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
				registrar->messenger(), kWeightEventChannel,
				&flutter::StandardMethodCodec::GetInstance());

		auto weight_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
			[plugin_ptr = plugin.get()](
				const flutter::EncodableValue *arguments,
				std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events)
				-> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
			{
				plugin_ptr->weight_event_sink_ = std::move(events);
				return nullptr;
			},
			[plugin_ptr = plugin.get()](const flutter::EncodableValue *arguments)
				-> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
			{
				plugin_ptr->weight_event_sink_.reset();
				return nullptr;
			});
		weight_event_channel->SetStreamHandler(std::move(weight_handler));

		// Status event channel
		auto status_event_channel =
			std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
				registrar->messenger(), kStatusEventChannel,
				&flutter::StandardMethodCodec::GetInstance());

		auto status_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
			[plugin_ptr = plugin.get()](
				const flutter::EncodableValue *arguments,
				std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events)
				-> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
			{
				plugin_ptr->status_event_sink_ = std::move(events);
				return nullptr;
			},
			[plugin_ptr = plugin.get()](const flutter::EncodableValue *arguments)
				-> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
			{
				plugin_ptr->status_event_sink_.reset();
				return nullptr;
			});
		status_event_channel->SetStreamHandler(std::move(status_handler));

		registrar->AddPlugin(std::move(plugin));
	}

	void WeighingSystemPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue> &call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{

		const std::string &method = call.method_name();
		const auto *args_ptr = call.arguments();
		flutter::EncodableMap args;
		if (args_ptr)
		{
			if (auto *map = std::get_if<flutter::EncodableMap>(args_ptr))
			{
				args = *map;
			}
		}

		// === System ===
		if (method == "initialize")
		{
			HandleInitialize(args, std::move(result));
		}
		else if (method == "shutdown")
		{
			HandleShutdown(std::move(result));
		}
		// === Scale config ===
		else if (method == "updateScaleParams")
		{
			HandleUpdateScaleParams(args, std::move(result));
		}
		else if (method == "getScaleParams")
		{
			HandleGetScaleParams(args, std::move(result));
		}
		else if (method == "updateZeroConfig")
		{
			HandleUpdateZeroConfig(args, std::move(result));
		}
		else if (method == "getZeroConfig")
		{
			HandleGetZeroConfig(args, std::move(result));
		}
		else if (method == "updateTareConfig")
		{
			HandleUpdateTareConfig(args, std::move(result));
		}
		else if (method == "getTareConfig")
		{
			HandleGetTareConfig(args, std::move(result));
		}
		else if (method == "updateFilterStability")
		{
			HandleUpdateFilterStability(args, std::move(result));
		}
		else if (method == "getFilterStability")
		{
			HandleGetFilterStability(args, std::move(result));
		}
		// === Scale operations ===
		else if (method == "doZero")
		{
			HandleDoZero(args, std::move(result));
		}
		else if (method == "doTare")
		{
			HandleDoTare(args, std::move(result));
		}
		else if (method == "clearTare")
		{
			HandleClearTare(args, std::move(result));
		}
		else if (method == "setPresetTare")
		{
			HandleSetPresetTare(args, std::move(result));
		}
		// === Calibration ===
		else if (method == "triggerCalZero")
		{
			HandleTriggerCalZero(args, std::move(result));
		}
		else if (method == "triggerCalSpan")
		{
			HandleTriggerCalSpan(args, std::move(result));
		}
		else if (method == "triggerSaveCalibration")
		{
			HandleTriggerSaveCalibration(args, std::move(result));
		}
		else if (method == "triggerAbortCalibration")
		{
			HandleTriggerAbortCalibration(args, std::move(result));
		}
		else if (method == "triggerStepCalibration")
		{
			HandleTriggerStepCalibration(args, std::move(result));
		}
		// === LIW Config ===
		else if (method == "updateLiwBaseConfig")
		{
			HandleUpdateLiwBaseConfig(args, std::move(result));
		}
		else if (method == "getLiwBaseConfig")
		{
			HandleGetLiwBaseConfig(args, std::move(result));
		}
		// === LIW System Config ===
		else if (method == "updateLiwSystemConfig")
		{
			HandleUpdateLiwSystemConfig(args, std::move(result));
		}
		else if (method == "getLiwSystemConfig")
		{
			HandleGetLiwSystemConfig(args, std::move(result));
		}
		// === LIW System ID Config ===
		else if (method == "updateLiwSystemIdConfig")
		{
			HandleUpdateLiwSystemIdConfig(args, std::move(result));
		}
		else if (method == "getLiwSystemIdConfig")
		{
			HandleGetLiwSystemIdConfig(args, std::move(result));
		}
		// === LIW Controller Config ===
		else if (method == "updateLiwControllerConfig")
		{
			HandleUpdateLiwControllerConfig(args, std::move(result));
		}
		else if (method == "getLiwControllerConfig")
		{
			HandleGetLiwControllerConfig(args, std::move(result));
		}
		// === LIW Refill Config ===
		else if (method == "updateLiwRefillConfig")
		{
			HandleUpdateLiwRefillConfig(args, std::move(result));
		}
		else if (method == "getLiwRefillConfig")
		{
			HandleGetLiwRefillConfig(args, std::move(result));
		}
		// === LIW Target Values Config ===
		else if (method == "updateLiwTargetValuesConfig")
		{
			HandleUpdateLiwTargetValuesConfig(args, std::move(result));
		}
		else if (method == "getLiwTargetValuesConfig")
		{
			HandleGetLiwTargetValuesConfig(args, std::move(result));
		}
		// === LIW Tolerance Check Config ===
		else if (method == "updateLiwToleranceCheckConfig")
		{
			HandleUpdateLiwToleranceCheckConfig(args, std::move(result));
		}
		else if (method == "getLiwToleranceCheckConfig")
		{
			HandleGetLiwToleranceCheckConfig(args, std::move(result));
		}
		// === LIW Emptying Config ===
		else if (method == "updateLiwEmptyingConfig")
		{
			HandleUpdateLiwEmptyingConfig(args, std::move(result));
		}
		else if (method == "getLiwEmptyingConfig")
		{
			HandleGetLiwEmptyingConfig(args, std::move(result));
		}
		// === LIW Warning Config ===
		else if (method == "updateLiwWarningConfig")
		{
			HandleUpdateLiwWarningConfig(args, std::move(result));
		}
		else if (method == "getLiwWarningConfig")
		{
			HandleGetLiwWarningConfig(args, std::move(result));
		}
		// === LIW Flow Monitor Config ===
		else if (method == "updateLiwFlowMonitorConfig")
		{
			HandleUpdateLiwFlowMonitorConfig(args, std::move(result));
		}
		else if (method == "getLiwFlowMonitorConfig")
		{
			HandleGetLiwFlowMonitorConfig(args, std::move(result));
		}
		// === LIW Advanced Config ===
		else if (method == "updateLiwAdvancedConfig")
		{
			HandleUpdateLiwAdvancedConfig(args, std::move(result));
		}
		else if (method == "getLiwAdvancedConfig")
		{
			HandleGetLiwAdvancedConfig(args, std::move(result));
		}
		// === LIW Stats Config ===
		else if (method == "updateLiwStatsConfig")
		{
			HandleUpdateLiwStatsConfig(args, std::move(result));
		}
		else if (method == "getLiwStatsConfig")
		{
			HandleGetLiwStatsConfig(args, std::move(result));
		}
		// === Filling General Config ===
		else if (method == "updateFillingGeneralConfig")
		{
			HandleUpdateFillingGeneralConfig(args, std::move(result));
		}
		else if (method == "getFillingGeneralConfig")
		{
			HandleGetFillingGeneralConfig(args, std::move(result));
		}
		// === Filling System Config ===
		else if (method == "updateFillingSystemConfig")
		{
			HandleUpdateFillingSystemConfig(args, std::move(result));
		}
		else if (method == "getFillingSystemConfig")
		{
			HandleGetFillingSystemConfig(args, std::move(result));
		}
		// === Filling Target Config ===
		else if (method == "updateFillingTargetConfig")
		{
			HandleUpdateFillingTargetConfig(args, std::move(result));
		}
		else if (method == "getFillingTargetConfig")
		{
			HandleGetFillingTargetConfig(args, std::move(result));
		}
		// === Filling Auto Tare Config ===
		else if (method == "updateFillingAutoTareConfig")
		{
			HandleUpdateFillingAutoTareConfig(args, std::move(result));
		}
		else if (method == "getFillingAutoTareConfig")
		{
			HandleGetFillingAutoTareConfig(args, std::move(result));
		}
		// === Filling Tolerance Config ===
		else if (method == "updateFillingToleranceConfig")
		{
			HandleUpdateFillingToleranceConfig(args, std::move(result));
		}
		else if (method == "getFillingToleranceConfig")
		{
			HandleGetFillingToleranceConfig(args, std::move(result));
		}
		// === Filling Spill Opt Config ===
		else if (method == "updateFillingSpillOptConfig")
		{
			HandleUpdateFillingSpillOptConfig(args, std::move(result));
		}
		else if (method == "getFillingSpillOptConfig")
		{
			HandleGetFillingSpillOptConfig(args, std::move(result));
		}
		// === Filling Cutoff Opt Config ===
		else if (method == "updateFillingCutoffOptConfig")
		{
			HandleUpdateFillingCutoffOptConfig(args, std::move(result));
		}
		else if (method == "getFillingCutoffOptConfig")
		{
			HandleGetFillingCutoffOptConfig(args, std::move(result));
		}
		// === Filling Jog Config ===
		else if (method == "updateFillingJogConfig")
		{
			HandleUpdateFillingJogConfig(args, std::move(result));
		}
		else if (method == "getFillingJogConfig")
		{
			HandleGetFillingJogConfig(args, std::move(result));
		}
		// === Filling Refill Config ===
		else if (method == "updateFillingRefillConfig")
		{
			HandleUpdateFillingRefillConfig(args, std::move(result));
		}
		else if (method == "getFillingRefillConfig")
		{
			HandleGetFillingRefillConfig(args, std::move(result));
		}
		// === Filling Emptying Config ===
		else if (method == "updateFillingEmptyingConfig")
		{
			HandleUpdateFillingEmptyingConfig(args, std::move(result));
		}
		else if (method == "getFillingEmptyingConfig")
		{
			HandleGetFillingEmptyingConfig(args, std::move(result));
		}
		// === Filling Events Config ===
		else if (method == "updateFillingEventsConfig")
		{
			HandleUpdateFillingEventsConfig(args, std::move(result));
		}
		else if (method == "getFillingEventsConfig")
		{
			HandleGetFillingEventsConfig(args, std::move(result));
		}
		// === Filling Advanced Config ===
		else if (method == "updateFillingAdvancedConfig")
		{
			HandleUpdateFillingAdvancedConfig(args, std::move(result));
		}
		else if (method == "getFillingAdvancedConfig")
		{
			HandleGetFillingAdvancedConfig(args, std::move(result));
		}

		// === App control ===
		else if (method == "startApp")
		{
			HandleStartApp(args, std::move(result));
		}
		else if (method == "stopApp")
		{
			HandleStopApp(args, std::move(result));
		}
		else if (method == "setManualControlRate")
		{
			HandleSetManualControlRate(args, std::move(result));
		}
		else if (method == "getAppStatus")
		{
			HandleGetAppStatus(args, std::move(result));
		}
		else if (method == "getDigitalOutputMap")
		{
			HandleGetDigitalOutputMapConfig(args, std::move(result));
		}

		else if (method == "validateDigitalOutputMap")
		{
			HandleValidateDigitalOutputMapConfig(args, std::move(result));
		}

		else if (method == "updateDigitalOutputMap")
		{
			HandleUpdateDigitalOutputMapConfig(args, std::move(result));
		}
		else if (method == "loadRecipe")
		{
			HandleLoadRecipe(args, std::move(result));
		}
		else if (method == "saveRecipe")
		{
			HandleSaveRecipe(args, std::move(result));
		}
		else if (method == "getAllRecipes")
		{
			HandleGetAllRecipes(args, std::move(result));
		}
		else if (method == "deleteRecipe")
		{
			HandleDeleteRecipe(args, std::move(result));
		}
		else if (method == "setMasterFlow")
		{
			HandleSetMasterFlow(args, std::move(result));
		}
		else if (method == "getMasterFlow")
		{
			HandleGetMasterFlow(args, std::move(result));
		}
		else if (method == "getTotalActualFlow")
		{
			HandleGetTotalActualFlow(args, std::move(result));
		}
		else if (method == "getSubsystemStatus")
		{
			HandleGetSubsystemStatus(args, std::move(result));
		}
		else if (method == "getAllSubsystemStatuses")
		{
			HandleGetAllSubsystemStatuses(args, std::move(result));
		}
		else if (method == "startBatch")
		{
			HandleStartBatch(args, std::move(result));
		}
		else if (method == "endBatch")
		{
			HandleEndBatch(args, std::move(result));
		}
		else if (method == "getCurrentBatchId")
		{
			HandleGetCurrentBatchId(args, std::move(result));
		}
		// === HMI SubSystem Config ===
		else if (method == "scanEthercatSlaves")
		{
			HandleScanEthercatSlaves(args, std::move(result));
		}
		else if (method == "getInputMode")
		{
			HandleGetInputMode(args, std::move(result));
		}
		else if (method == "getSubsystemMappings")
		{
			HandleGetSubsystemMappings(args, std::move(result));
		}
		else if (method == "updateSubsystemMapping")
		{
			HandleUpdateSubsystemMapping(args, std::move(result));
		}
		else if (method == "updateSlaveAlias")
		{
			HandleUpdateSlaveAlias(args, std::move(result));
		}
		else if (method == "addSubsystemMapping")
		{
			HandleAddSubsystemMapping(args, std::move(result));
		}
		else if (method == "removeSubsystemMapping")
		{
			HandleRemoveSubsystemMapping(args, std::move(result));
		}
		else if (method == "getConfigStatus")
		{
			HandleGetConfigStatus(args, std::move(result));
		}
		else if (method == "saveEthercatHardwareConfig")
		{
			HandleSaveEthercatHardwareConfig(args, std::move(result));
		}
		else if (method == "saveMaterialRecipe")
		{
			HandleSaveMaterialRecipe(args, std::move(result));
		}
		else if (method == "loadMaterialRecipe")
		{
			HandleLoadMaterialRecipe(args, std::move(result));
		}
		else if (method == "getAllMaterialRecipes")
		{
			HandleGetAllMaterialRecipes(args, std::move(result));
		}
		else if (method == "deleteMaterialRecipe")
		{
			HandleDeleteMaterialRecipe(args, std::move(result));
		}
		else
		{
			result->NotImplemented();
		}
	}

	// ============ Implementation of handlers ============

	void WeighingSystemPlugin::HandleShutdown(
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		StopWeightEventStream();
		StopMockThread();
		SystemInitializer::Instance().Shutdown();
		result->Success(flutter::EncodableValue(true));
	}

	// HandleInitialize 保持一个参数版本
	void WeighingSystemPlugin::HandleInitialize(const flutter::EncodableMap &args,
												std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		std::string db_path = GetString(args, "dbPath", "/data/weighing_system.db");
		std::string config_path = GetString(args, "inputConfigPath", "/etc/weighing/input_mode.json");

		bool ok = SystemInitializer::Instance().Initialize(config_path, db_path);

		// 启动物理闭环模型
		StartMockThread();
		if (ok)
		{
			StartWeightEventStream();
			printf("Plugin: Initialization successful (input=%s)\n",
				   SystemInitializer::Instance().GetInputMode().c_str());
		}

		result->Success(flutter::EncodableValue(ok));
	}

	void WeighingSystemPlugin::HandleUpdateScaleParams(const flutter::EncodableMap &args,
													   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		ScaleParams params;
		params.primary_unit = static_cast<WeightUnit>(GetInt(args, "primaryUnit", 1));
		params.capacity = GetDouble(args, "capacity", 15.0);
		params.division = GetDouble(args, "division", 0.005);
		params.overload_range = GetInt(args, "overloadRange", 9);

		// Validate division count
		if (params.division > 0 && params.capacity / params.division > 100000)
		{
			// Auto-adjust division
			params.division = params.capacity / 100000.0;
		}
		if (params.division > 0 && params.capacity / params.division < 500)
		{
			params.division = params.capacity / 500.0;
		}

		scale->UpdateScaleParams(params);
		auto zc = scale->GetZeroConfig();
		auto tc = scale->GetTareConfig();
		auto fc = scale->GetFilterStabilityConfig();
		ConfigStore::Instance().SaveScaleConfig(scale_id, params, zc, tc, fc);

		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetScaleParams(const flutter::EncodableMap &args,
													std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		auto params = scale->GetScaleParams();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("primaryUnit")] = flutter::EncodableValue(static_cast<int>(params.primary_unit));
		map[flutter::EncodableValue("capacity")] = flutter::EncodableValue(params.capacity);
		map[flutter::EncodableValue("division")] = flutter::EncodableValue(params.division);
		map[flutter::EncodableValue("overloadRange")] = flutter::EncodableValue(params.overload_range);
		map[flutter::EncodableValue("maxDivisions")] = flutter::EncodableValue(params.max_divisions());

		result->Success(flutter::EncodableValue(map));
	}

	void WeighingSystemPlugin::HandleUpdateZeroConfig(const flutter::EncodableMap &args,
													  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		ZeroConfig cfg;
		cfg.auto_zero_mode = static_cast<AutoZeroMode>(GetInt(args, "autoZeroMode", 1));
		cfg.auto_zero_range_d = GetDouble(args, "autoZeroRangeD", 0.5);
		cfg.underload_range_d = GetDouble(args, "underloadRangeD", 20.0);
		cfg.power_up_zero = static_cast<PowerUpZeroMode>(GetInt(args, "powerUpZero", 1));
		cfg.power_up_zero_pos_pct = GetDouble(args, "powerUpZeroPosPct", 2.0);
		cfg.power_up_zero_neg_pct = GetDouble(args, "powerUpZeroNegPct", 2.0);
		cfg.pushbutton_zero_enabled = GetBool(args, "pushbuttonZeroEnabled", true);
		cfg.pushbutton_zero_pos_pct = GetDouble(args, "pushbuttonZeroPosPct", 2.0);
		cfg.pushbutton_zero_neg_pct = GetDouble(args, "pushbuttonZeroNegPct", 2.0);

		scale->UpdateZeroConfig(cfg);
		auto sp = scale->GetScaleParams();
		auto tc = scale->GetTareConfig();
		auto fc = scale->GetFilterStabilityConfig();
		ConfigStore::Instance().SaveScaleConfig(scale_id, sp, cfg, tc, fc);

		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetZeroConfig(const flutter::EncodableMap &args,
												   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		auto cfg = scale->GetZeroConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("autoZeroMode")] = flutter::EncodableValue(static_cast<int>(cfg.auto_zero_mode));
		map[flutter::EncodableValue("autoZeroRangeD")] = flutter::EncodableValue(cfg.auto_zero_range_d);
		map[flutter::EncodableValue("underloadRangeD")] = flutter::EncodableValue(cfg.underload_range_d);
		map[flutter::EncodableValue("powerUpZero")] = flutter::EncodableValue(static_cast<int>(cfg.power_up_zero));
		map[flutter::EncodableValue("powerUpZeroPosPct")] = flutter::EncodableValue(cfg.power_up_zero_pos_pct);
		map[flutter::EncodableValue("powerUpZeroNegPct")] = flutter::EncodableValue(cfg.power_up_zero_neg_pct);
		map[flutter::EncodableValue("pushbuttonZeroEnabled")] = flutter::EncodableValue(cfg.pushbutton_zero_enabled);
		map[flutter::EncodableValue("pushbuttonZeroPosPct")] = flutter::EncodableValue(cfg.pushbutton_zero_pos_pct);
		map[flutter::EncodableValue("pushbuttonZeroNegPct")] = flutter::EncodableValue(cfg.pushbutton_zero_neg_pct);
		result->Success(flutter::EncodableValue(map));
	}

	void WeighingSystemPlugin::HandleUpdateTareConfig(const flutter::EncodableMap &args,
													  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		TareConfig cfg;
		cfg.pushbutton_tare_enabled = GetBool(args, "pushbuttonTareEnabled", true);
		cfg.preset_tare_enabled = GetBool(args, "presetTareEnabled", true);
		scale->UpdateTareConfig(cfg);

		auto sp = scale->GetScaleParams();
		auto zc = scale->GetZeroConfig();
		auto fc = scale->GetFilterStabilityConfig();
		ConfigStore::Instance().SaveScaleConfig(scale_id, sp, zc, cfg, fc);
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetTareConfig(const flutter::EncodableMap &args,
												   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		auto cfg = scale->GetTareConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("pushbuttonTareEnabled")] = flutter::EncodableValue(cfg.pushbutton_tare_enabled);
		map[flutter::EncodableValue("presetTareEnabled")] = flutter::EncodableValue(cfg.preset_tare_enabled);
		result->Success(flutter::EncodableValue(map));
	}

	void WeighingSystemPlugin::HandleUpdateFilterStability(const flutter::EncodableMap &args,
														   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		FilterStabilityConfig cfg;
		cfg.low_pass_level = static_cast<LowPassFilterLevel>(GetInt(args, "lowPassLevel", 0));
		cfg.notch_enabled = GetBool(args, "notchEnabled", false);
		cfg.notch_frequency = GetDouble(args, "notchFrequency", 50.0);
		cfg.adaptive_enabled = GetBool(args, "adaptiveEnabled", false);
		cfg.adaptive_range_d = GetDouble(args, "adaptiveRangeD", 1.0);
		cfg.motion_range_d = GetDouble(args, "motionRangeD", 1.0);
		cfg.motion_detect_time = GetDouble(args, "motionDetectTime", 0.3);
		cfg.stability_timeout = GetDouble(args, "stabilityTimeout", 3.0);

		scale->UpdateFilterStability(cfg);
		auto sp = scale->GetScaleParams();
		auto zc = scale->GetZeroConfig();
		auto tc = scale->GetTareConfig();
		ConfigStore::Instance().SaveScaleConfig(scale_id, sp, zc, tc, cfg);
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFilterStability(const flutter::EncodableMap &args,
														std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		auto cfg = scale->GetFilterStabilityConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("lowPassLevel")] = flutter::EncodableValue(static_cast<int>(cfg.low_pass_level));
		map[flutter::EncodableValue("notchEnabled")] = flutter::EncodableValue(cfg.notch_enabled);
		map[flutter::EncodableValue("notchFrequency")] = flutter::EncodableValue(cfg.notch_frequency);
		map[flutter::EncodableValue("adaptiveEnabled")] = flutter::EncodableValue(cfg.adaptive_enabled);
		map[flutter::EncodableValue("adaptiveRangeD")] = flutter::EncodableValue(cfg.adaptive_range_d);
		map[flutter::EncodableValue("motionRangeD")] = flutter::EncodableValue(cfg.motion_range_d);
		map[flutter::EncodableValue("motionDetectTime")] = flutter::EncodableValue(cfg.motion_detect_time);
		map[flutter::EncodableValue("stabilityTimeout")] = flutter::EncodableValue(cfg.stability_timeout);
		result->Success(flutter::EncodableValue(map));
	}

	// === Scale Operations ===

	void WeighingSystemPlugin::HandleDoZero(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		result->Success(flutter::EncodableValue(scale->DoPushbuttonZero()));
	}

	void WeighingSystemPlugin::HandleDoTare(const flutter::EncodableMap &args,
											std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		result->Success(flutter::EncodableValue(scale->DoTare()));
	}

	void WeighingSystemPlugin::HandleClearTare(const flutter::EncodableMap &args,
											   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		scale->ClearTare();
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleSetPresetTare(const flutter::EncodableMap &args,
												   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		double value = GetDouble(args, "value", 0.0);
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		scale->SetPresetTare(value);
		result->Success(flutter::EncodableValue(true));
	}

	// === Calibration ===

	void WeighingSystemPlugin::HandleTriggerCalZero(const flutter::EncodableMap &args,
													std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		scale->StartZeroCalibration();
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleTriggerCalSpan(const flutter::EncodableMap &args,
													std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		int linear_mode = GetInt(args, "linearMode", 0);
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		// Extract test loads array
		std::vector<double> loads;
		auto it = args.find(flutter::EncodableValue("testLoads"));
		if (it != args.end())
		{
			if (auto *list = std::get_if<flutter::EncodableList>(&it->second))
			{
				for (const auto &v : *list)
				{
					if (auto *d = std::get_if<double>(&v))
						loads.push_back(*d);
					else if (auto *i = std::get_if<int32_t>(&v))
						loads.push_back(static_cast<double>(*i));
				}
			}
		}

		scale->StartSpanCalibration(linear_mode, loads.data(), static_cast<int>(loads.size()));
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleTriggerSaveCalibration(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}

		if (scale->SaveCalibration())
		{
			CalibrationStore::Instance().SaveCalibration(scale_id, scale->GetCalibrationData());
			result->Success(flutter::EncodableValue(true));
		}
		else
		{
			result->Error("CAL_ERROR", "Calibration not complete");
		}
	}

	void WeighingSystemPlugin::HandleTriggerAbortCalibration(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		scale->AbortCalibration();
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleTriggerStepCalibration(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int scale_id = GetInt(args, "scaleId");
		double test_weight = GetDouble(args, "testWeight", 1.0);
		auto *scale = ScaleManager::Instance().GetScale(scale_id);
		if (!scale)
		{
			result->Error("NOT_FOUND", "Scale not found");
			return;
		}
		scale->StartStepCalibration(test_weight);
		result->Success(flutter::EncodableValue(true));
	}

	// === LIW Base Config ===

	void WeighingSystemPlugin::HandleUpdateLiwBaseConfig(const flutter::EncodableMap &args,
														 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwBaseConfig cfg;
		cfg.mode = static_cast<LiwMode>(GetInt(args, "mode", 0));
		cfg.sub_mode = static_cast<LiwSubMode>(GetInt(args, "subMode", 0));
		sub->GetLiwApp()->SetBaseConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwBaseConfig(const flutter::EncodableMap &args,
													  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetBaseConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("mode")] = flutter::EncodableValue(static_cast<int>(cfg.mode));
		map[flutter::EncodableValue("subMode")] = flutter::EncodableValue(static_cast<int>(cfg.sub_mode));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW System Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwSystemConfig(const flutter::EncodableMap &args,
														   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwSystemConfig cfg;
		cfg.safety_limit = static_cast<float>(GetDouble(args, "safetyLimit", 100.0));
		cfg.hopper_min = static_cast<float>(GetDouble(args, "hopperMin", 0.0));
		cfg.hopper_max = static_cast<float>(GetDouble(args, "hopperMax", 15.0));
		cfg.target_flow = static_cast<float>(GetDouble(args, "targetFlow", 10.0));
		cfg.target_control_rate = static_cast<float>(GetDouble(args, "targetControlRate", 10.0));
		cfg.pre_refill = GetBool(args, "preRefill", false);

		sub->GetLiwApp()->SetSystemConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwSystemConfig(const flutter::EncodableMap &args,
														std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetSystemConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("safetyLimit")] = flutter::EncodableValue(static_cast<double>(cfg.safety_limit));
		map[flutter::EncodableValue("hopperMin")] = flutter::EncodableValue(static_cast<double>(cfg.hopper_min));
		map[flutter::EncodableValue("hopperMax")] = flutter::EncodableValue(static_cast<double>(cfg.hopper_max));
		map[flutter::EncodableValue("targetFlow")] = flutter::EncodableValue(static_cast<double>(cfg.target_flow));
		map[flutter::EncodableValue("targetControlRate")] = flutter::EncodableValue(static_cast<double>(cfg.target_control_rate));
		map[flutter::EncodableValue("preRefill")] = flutter::EncodableValue(cfg.pre_refill);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW System ID Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwSystemIdConfig(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwSystemIdConfig cfg;
		cfg.adjust_range_lower = static_cast<float>(GetDouble(args, "adjustRangeLower", 0.0));
		cfg.adjust_range_upper = static_cast<float>(GetDouble(args, "adjustRangeUpper", 90.0));
		cfg.smart_step_control = GetBool(args, "smartStepControl", false);
		cfg.step_duration = static_cast<float>(GetDouble(args, "stepDuration", 10.0));
		cfg.filter_window = static_cast<float>(GetDouble(args, "filterWindow", 0.5));

		sub->GetLiwApp()->SetSystemIdConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwSystemIdConfig(const flutter::EncodableMap &args,
														  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetSystemIdConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("adjustRangeLower")] = flutter::EncodableValue(static_cast<double>(cfg.adjust_range_lower));
		map[flutter::EncodableValue("adjustRangeUpper")] = flutter::EncodableValue(static_cast<double>(cfg.adjust_range_upper));
		map[flutter::EncodableValue("smartStepControl")] = flutter::EncodableValue(cfg.smart_step_control);
		map[flutter::EncodableValue("stepDuration")] = flutter::EncodableValue(static_cast<double>(cfg.step_duration));
		map[flutter::EncodableValue("filterWindow")] = flutter::EncodableValue(static_cast<double>(cfg.filter_window));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Controller Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwControllerConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwControllerConfig cfg;
		cfg.tuning_mode = static_cast<PidTuningMode>(GetInt(args, "tuningMode", 1));
		cfg.filter_window = static_cast<float>(GetDouble(args, "filterWindow", 0.5));
		cfg.Kp = static_cast<float>(GetDouble(args, "kp", 1.0));
		cfg.Ki = static_cast<float>(GetDouble(args, "ki", 1.0));
		cfg.Kd = static_cast<float>(GetDouble(args, "kd", 0.0));
		cfg.max_flow = static_cast<float>(GetDouble(args, "maxFlow", 100.0));
		cfg.startup_time = static_cast<float>(GetDouble(args, "startupTime", 0.0));

		sub->GetLiwApp()->SetControllerConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwControllerConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetControllerConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("tuningMode")] = flutter::EncodableValue(static_cast<int>(cfg.tuning_mode));
		map[flutter::EncodableValue("filterWindow")] = flutter::EncodableValue(static_cast<double>(cfg.filter_window));
		map[flutter::EncodableValue("kp")] = flutter::EncodableValue(static_cast<double>(cfg.Kp));
		map[flutter::EncodableValue("ki")] = flutter::EncodableValue(static_cast<double>(cfg.Ki));
		map[flutter::EncodableValue("kd")] = flutter::EncodableValue(static_cast<double>(cfg.Kd));
		map[flutter::EncodableValue("maxFlow")] = flutter::EncodableValue(static_cast<double>(cfg.max_flow));
		map[flutter::EncodableValue("startupTime")] = flutter::EncodableValue(static_cast<double>(cfg.startup_time));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Refill Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwRefillConfig(const flutter::EncodableMap &args,
														   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwRefillConfig cfg;
		cfg.mode = static_cast<RefillMode>(GetInt(args, "mode", 0));
		cfg.lower_limit = static_cast<float>(GetDouble(args, "lowerLimit", 1.0));
		cfg.upper_limit = static_cast<float>(GetDouble(args, "upperLimit", 10.0));
		cfg.control_mode = static_cast<RefillControlMode>(GetInt(args, "controlMode", 1));
		cfg.control_setpoint = static_cast<float>(GetDouble(args, "controlSetpoint", 10.0));
		cfg.stabilize_time = static_cast<float>(GetDouble(args, "stabilizeTime", 10.0));

		sub->GetLiwApp()->SetRefillConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwRefillConfig(const flutter::EncodableMap &args,
														std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetRefillConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("mode")] = flutter::EncodableValue(static_cast<int>(cfg.mode));
		map[flutter::EncodableValue("lowerLimit")] = flutter::EncodableValue(static_cast<double>(cfg.lower_limit));
		map[flutter::EncodableValue("upperLimit")] = flutter::EncodableValue(static_cast<double>(cfg.upper_limit));
		map[flutter::EncodableValue("controlMode")] = flutter::EncodableValue(static_cast<int>(cfg.control_mode));
		map[flutter::EncodableValue("controlSetpoint")] = flutter::EncodableValue(static_cast<double>(cfg.control_setpoint));
		map[flutter::EncodableValue("stabilizeTime")] = flutter::EncodableValue(static_cast<double>(cfg.stabilize_time));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Target Values Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwTargetValuesConfig(const flutter::EncodableMap &args,
																 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwTargetValuesConfig cfg;
		cfg.batch_target = static_cast<float>(GetDouble(args, "batchTarget", 1.0));
		cfg.in_flight = static_cast<float>(GetDouble(args, "inFlight", 0.0));
		cfg.fine_feed_threshold = static_cast<float>(GetDouble(args, "fineFeedThreshold", 0.0));
		cfg.fine_feed_flow = static_cast<float>(GetDouble(args, "fineFeedFlow", 2.0));

		sub->GetLiwApp()->SetTargetValuesConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwTargetValuesConfig(const flutter::EncodableMap &args,
															  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetTargetValuesConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("batchTarget")] = flutter::EncodableValue(static_cast<double>(cfg.batch_target));
		map[flutter::EncodableValue("inFlight")] = flutter::EncodableValue(static_cast<double>(cfg.in_flight));
		map[flutter::EncodableValue("fineFeedThreshold")] = flutter::EncodableValue(static_cast<double>(cfg.fine_feed_threshold));
		map[flutter::EncodableValue("fineFeedFlow")] = flutter::EncodableValue(static_cast<double>(cfg.fine_feed_flow));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Tolerance Check Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwToleranceCheckConfig(const flutter::EncodableMap &args,
																   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwToleranceCheckConfig cfg;
		cfg.pre_check_delay = static_cast<float>(GetDouble(args, "preCheckDelay", 0.0));
		cfg.stability_timeout = static_cast<float>(GetDouble(args, "stabilityTimeout", 0.0));
		cfg.tolerance = static_cast<float>(GetDouble(args, "tolerance", 0.0));

		sub->GetLiwApp()->SetToleranceCheckConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwToleranceCheckConfig(const flutter::EncodableMap &args,
																std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetToleranceCheckConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("preCheckDelay")] = flutter::EncodableValue(static_cast<double>(cfg.pre_check_delay));
		map[flutter::EncodableValue("stabilityTimeout")] = flutter::EncodableValue(static_cast<double>(cfg.stability_timeout));
		map[flutter::EncodableValue("tolerance")] = flutter::EncodableValue(static_cast<double>(cfg.tolerance));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Emptying Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwEmptyingConfig(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwEmptyingConfig cfg;
		cfg.auto_stop_at_alarm = GetBool(args, "autoStopAtAlarm", true);
		cfg.control_setpoint = static_cast<float>(GetDouble(args, "controlSetpoint", 10.0));

		sub->GetLiwApp()->SetEmptyingConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwEmptyingConfig(const flutter::EncodableMap &args,
														  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetEmptyingConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("autoStopAtAlarm")] = flutter::EncodableValue(cfg.auto_stop_at_alarm);
		map[flutter::EncodableValue("controlSetpoint")] = flutter::EncodableValue(static_cast<double>(cfg.control_setpoint));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Warning Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwWarningConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwWarningConfig cfg;
		cfg.control_rate_lower = static_cast<float>(GetDouble(args, "controlRateLower", 20.0));
		cfg.control_rate_upper = static_cast<float>(GetDouble(args, "controlRateUpper", 80.0));
		cfg.refill_timeout = static_cast<float>(GetDouble(args, "refillTimeout", 10.0));
		cfg.stop_on_error = GetBool(args, "stopOnError", false);

		sub->GetLiwApp()->SetWarningConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwWarningConfig(const flutter::EncodableMap &args,
														 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetWarningConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("controlRateLower")] = flutter::EncodableValue(static_cast<double>(cfg.control_rate_lower));
		map[flutter::EncodableValue("controlRateUpper")] = flutter::EncodableValue(static_cast<double>(cfg.control_rate_upper));
		map[flutter::EncodableValue("refillTimeout")] = flutter::EncodableValue(static_cast<double>(cfg.refill_timeout));
		map[flutter::EncodableValue("stopOnError")] = flutter::EncodableValue(cfg.stop_on_error);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Flow Monitor Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwFlowMonitorConfig(const flutter::EncodableMap &args,
																std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwFlowMonitorConfig cfg;
		cfg.evaluation_window = static_cast<float>(GetDouble(args, "evaluationWindow", 3.0));
		cfg.deviation_threshold = static_cast<float>(GetDouble(args, "deviationThreshold", 10.0));
		cfg.surge_threshold = static_cast<float>(GetDouble(args, "surgeThreshold", 150.0));

		sub->GetLiwApp()->SetFlowMonitorConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwFlowMonitorConfig(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetFlowMonitorConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("evaluationWindow")] = flutter::EncodableValue(static_cast<double>(cfg.evaluation_window));
		map[flutter::EncodableValue("deviationThreshold")] = flutter::EncodableValue(static_cast<double>(cfg.deviation_threshold));
		map[flutter::EncodableValue("surgeThreshold")] = flutter::EncodableValue(static_cast<double>(cfg.surge_threshold));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Advanced Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwAdvancedConfig(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwAdvancedConfig cfg;
		cfg.interlock_enabled = GetBool(args, "interlockEnabled", false);
		cfg.interlock_delay = static_cast<float>(GetDouble(args, "interlockDelay", 0.0));

		sub->GetLiwApp()->SetAdvancedConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwAdvancedConfig(const flutter::EncodableMap &args,
														  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetAdvancedConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("interlockEnabled")] = flutter::EncodableValue(cfg.interlock_enabled);
		map[flutter::EncodableValue("interlockDelay")] = flutter::EncodableValue(static_cast<double>(cfg.interlock_delay));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// LIW Stats Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateLiwStatsConfig(const flutter::EncodableMap &args,
														  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		LiwStatsConfig cfg;
		cfg.sample_period = static_cast<float>(GetDouble(args, "samplePeriod", 60.0));
		cfg.sample_tolerance = static_cast<float>(GetDouble(args, "sampleTolerance", 10.0));

		sub->GetLiwApp()->SetStatsConfig(cfg);
		ConfigStore::Instance().SaveLiwConfig(sub_id, sub->GetLiwApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetLiwStatsConfig(const flutter::EncodableMap &args,
													   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetLiwApp())
		{
			result->Error("NOT_FOUND", "LIW app not found");
			return;
		}

		auto cfg = sub->GetLiwApp()->GetStatsConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("samplePeriod")] = flutter::EncodableValue(static_cast<double>(cfg.sample_period));
		map[flutter::EncodableValue("sampleTolerance")] = flutter::EncodableValue(static_cast<double>(cfg.sample_tolerance));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling General Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingGeneralConfig(const flutter::EncodableMap &args,
																std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingGeneralConfig cfg;
		cfg.power_fail_recovery = static_cast<PowerFailRecovery>(GetInt(args, "powerFailRecovery", 0));
		cfg.start_delay = static_cast<PowerFailStartDelay>(GetInt(args, "startDelay", 0));

		sub->GetFillingApp()->SetGeneralConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingGeneralConfig(const flutter::EncodableMap &args,
															 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetGeneralConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("powerFailRecovery")] = flutter::EncodableValue(static_cast<int>(cfg.power_fail_recovery));
		map[flutter::EncodableValue("startDelay")] = flutter::EncodableValue(static_cast<int>(cfg.start_delay));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling System Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingSystemConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingSystemConfig cfg;
		cfg.work_mode = static_cast<FillingWorkMode>(GetInt(args, "workMode", 0));
		cfg.feed_speed = static_cast<FeedSpeed>(GetInt(args, "feedSpeed", 1));

		sub->GetFillingApp()->SetSystemConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingSystemConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetSystemConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("workMode")] = flutter::EncodableValue(static_cast<int>(cfg.work_mode));
		map[flutter::EncodableValue("feedSpeed")] = flutter::EncodableValue(static_cast<int>(cfg.feed_speed));
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Target Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingTargetConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingTargetConfig cfg;
		cfg.target_value = GetDouble(args, "targetValue", 1.0);
		cfg.in_flight = GetDouble(args, "inFlight", 0.0);
		cfg.feed = GetDouble(args, "feed", 0.0);
		cfg.feed_inhibit_time = GetDouble(args, "feedInhibitTime", 0.0);
		cfg.fast_feed_inhibit_time = GetDouble(args, "fastFeedInhibitTime", 0.0);

		sub->GetFillingApp()->SetTargetConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingTargetConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetTargetConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("targetValue")] = flutter::EncodableValue(cfg.target_value);
		map[flutter::EncodableValue("inFlight")] = flutter::EncodableValue(cfg.in_flight);
		map[flutter::EncodableValue("feed")] = flutter::EncodableValue(cfg.feed);
		map[flutter::EncodableValue("feedInhibitTime")] = flutter::EncodableValue(cfg.feed_inhibit_time);
		map[flutter::EncodableValue("fastFeedInhibitTime")] = flutter::EncodableValue(cfg.fast_feed_inhibit_time);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Auto Tare Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingAutoTareConfig(const flutter::EncodableMap &args,
																 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingAutoTareConfig cfg;
		cfg.auto_tare_enabled = GetBool(args, "autoTareEnabled", false);
		cfg.container_tare_upper = GetDouble(args, "containerTareUpper", 0.0);
		cfg.container_tare_lower = GetDouble(args, "containerTareLower", 0.0);

		sub->GetFillingApp()->SetAutoTareConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingAutoTareConfig(const flutter::EncodableMap &args,
															  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetAutoTareConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("autoTareEnabled")] = flutter::EncodableValue(cfg.auto_tare_enabled);
		map[flutter::EncodableValue("containerTareUpper")] = flutter::EncodableValue(cfg.container_tare_upper);
		map[flutter::EncodableValue("containerTareLower")] = flutter::EncodableValue(cfg.container_tare_lower);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Tolerance Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingToleranceConfig(const flutter::EncodableMap &args,
																  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingToleranceConfig cfg;
		cfg.pre_check_delay = GetDouble(args, "preCheckDelay", 0.0);
		cfg.stability_timeout = GetDouble(args, "stabilityTimeout", 0.0);
		cfg.positive_tolerance = GetDouble(args, "positiveTolerance", 0.0);
		cfg.negative_tolerance = GetDouble(args, "negativeTolerance", 0.0);

		sub->GetFillingApp()->SetToleranceConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingToleranceConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetToleranceConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("preCheckDelay")] = flutter::EncodableValue(cfg.pre_check_delay);
		map[flutter::EncodableValue("stabilityTimeout")] = flutter::EncodableValue(cfg.stability_timeout);
		map[flutter::EncodableValue("positiveTolerance")] = flutter::EncodableValue(cfg.positive_tolerance);
		map[flutter::EncodableValue("negativeTolerance")] = flutter::EncodableValue(cfg.negative_tolerance);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Spill Optimization Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingSpillOptConfig(const flutter::EncodableMap &args,
																 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingSpillOptConfig cfg;
		cfg.mode = static_cast<SpillOptMode>(GetInt(args, "mode", 0));
		cfg.adjust_range = GetDouble(args, "adjustRange", 0.0);
		cfg.adjust_samples = GetInt(args, "adjustSamples", 5);
		cfg.adjust_factor = GetDouble(args, "adjustFactor", 0.5);

		sub->GetFillingApp()->SetSpillOptConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingSpillOptConfig(const flutter::EncodableMap &args,
															  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetSpillOptConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("mode")] = flutter::EncodableValue(static_cast<int>(cfg.mode));
		map[flutter::EncodableValue("adjustRange")] = flutter::EncodableValue(cfg.adjust_range);
		map[flutter::EncodableValue("adjustSamples")] = flutter::EncodableValue(cfg.adjust_samples);
		map[flutter::EncodableValue("adjustFactor")] = flutter::EncodableValue(cfg.adjust_factor);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Cutoff Optimization Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingCutoffOptConfig(const flutter::EncodableMap &args,
																  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingCutoffOptConfig cfg;
		cfg.mode = static_cast<CutoffOptMode>(GetInt(args, "mode", 0));
		cfg.control_reliability_range = GetDouble(args, "controlReliabilityRange", 0.0);
		cfg.adjust_cycles = GetInt(args, "adjustCycles", 5);
		cfg.adjust_factor = GetDouble(args, "adjustFactor", 0.5);

		sub->GetFillingApp()->SetCutoffOptConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingCutoffOptConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetCutoffOptConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("mode")] = flutter::EncodableValue(static_cast<int>(cfg.mode));
		map[flutter::EncodableValue("controlReliabilityRange")] = flutter::EncodableValue(cfg.control_reliability_range);
		map[flutter::EncodableValue("adjustCycles")] = flutter::EncodableValue(cfg.adjust_cycles);
		map[flutter::EncodableValue("adjustFactor")] = flutter::EncodableValue(cfg.adjust_factor);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Jog Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingJogConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingJogConfig cfg;
		cfg.mode = static_cast<JogMode>(GetInt(args, "mode", 0));
		cfg.jog_duration = GetDouble(args, "jogDuration", 0.5);
		cfg.jog_pause_time = GetDouble(args, "jogPauseTime", 1.0);
		cfg.max_cycles = GetInt(args, "maxCycles", 3);

		sub->GetFillingApp()->SetJogConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingJogConfig(const flutter::EncodableMap &args,
														 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetJogConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("mode")] = flutter::EncodableValue(static_cast<int>(cfg.mode));
		map[flutter::EncodableValue("jogDuration")] = flutter::EncodableValue(cfg.jog_duration);
		map[flutter::EncodableValue("jogPauseTime")] = flutter::EncodableValue(cfg.jog_pause_time);
		map[flutter::EncodableValue("maxCycles")] = flutter::EncodableValue(cfg.max_cycles);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Refill Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingRefillConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingRefillConfig cfg;
		cfg.upper_limit = GetDouble(args, "upperLimit", 10.0);
		cfg.lower_limit = GetDouble(args, "lowerLimit", 1.0);

		sub->GetFillingApp()->SetRefillConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingRefillConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetRefillConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("upperLimit")] = flutter::EncodableValue(cfg.upper_limit);
		map[flutter::EncodableValue("lowerLimit")] = flutter::EncodableValue(cfg.lower_limit);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Emptying Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingEmptyingConfig(const flutter::EncodableMap &args,
																 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingEmptyingConfig cfg;
		cfg.complete_mode = static_cast<EmptyingCompleteMode>(GetInt(args, "completeMode", 0));
		cfg.residual_weight = GetDouble(args, "residualWeight", 0.1);
		cfg.completion_time = GetDouble(args, "completionTime", 5.0);

		sub->GetFillingApp()->SetEmptyingConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingEmptyingConfig(const flutter::EncodableMap &args,
															  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetEmptyingConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("completeMode")] = flutter::EncodableValue(static_cast<int>(cfg.complete_mode));
		map[flutter::EncodableValue("residualWeight")] = flutter::EncodableValue(cfg.residual_weight);
		map[flutter::EncodableValue("completionTime")] = flutter::EncodableValue(cfg.completion_time);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Events Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingEventsConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingEventsConfig cfg;
		cfg.initial_feed_timeout = GetDouble(args, "initialFeedTimeout", 30.0);
		cfg.emptying_timeout = GetDouble(args, "emptyingTimeout", 60.0);
		cfg.refill_timeout = GetDouble(args, "refillTimeout", 60.0);
		cfg.process_timeout = GetDouble(args, "processTimeout", 120.0);

		sub->GetFillingApp()->SetEventsConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingEventsConfig(const flutter::EncodableMap &args,
															std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetEventsConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("initialFeedTimeout")] = flutter::EncodableValue(cfg.initial_feed_timeout);
		map[flutter::EncodableValue("emptyingTimeout")] = flutter::EncodableValue(cfg.emptying_timeout);
		map[flutter::EncodableValue("refillTimeout")] = flutter::EncodableValue(cfg.refill_timeout);
		map[flutter::EncodableValue("processTimeout")] = flutter::EncodableValue(cfg.process_timeout);
		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// Filling Advanced Config
	// ============================================================================
	void WeighingSystemPlugin::HandleUpdateFillingAdvancedConfig(const flutter::EncodableMap &args,
																 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		FillingAdvancedConfig cfg;
		cfg.cycle_confirm = static_cast<CycleResultConfirm>(GetInt(args, "cycleConfirm", 0));
		cfg.fast_recovery = static_cast<FastRecovery>(GetInt(args, "fastRecovery", 0));
		cfg.interlock_enabled = GetBool(args, "interlockEnabled", false);
		cfg.fast_feed_speed = GetDouble(args, "fastFeedSpeed", 100.0);
		cfg.fine_feed_speed = GetDouble(args, "fineFeedSpeed", 30.0);

		sub->GetFillingApp()->SetAdvancedConfig(cfg);
		ConfigStore::Instance().SaveFillingConfig(sub_id, sub->GetFillingApp());
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetFillingAdvancedConfig(const flutter::EncodableMap &args,
															  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetFillingApp())
		{
			result->Error("NOT_FOUND", "Filling app not found");
			return;
		}

		auto cfg = sub->GetFillingApp()->GetAdvancedConfig();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("cycleConfirm")] = flutter::EncodableValue(static_cast<int>(cfg.cycle_confirm));
		map[flutter::EncodableValue("fastRecovery")] = flutter::EncodableValue(static_cast<int>(cfg.fast_recovery));
		map[flutter::EncodableValue("interlockEnabled")] = flutter::EncodableValue(cfg.interlock_enabled);
		map[flutter::EncodableValue("fastFeedSpeed")] = flutter::EncodableValue(cfg.fast_feed_speed);
		map[flutter::EncodableValue("fineFeedSpeed")] = flutter::EncodableValue(cfg.fine_feed_speed);
		result->Success(flutter::EncodableValue(map));
	}

	// === Application Control ===

	void WeighingSystemPlugin::HandleStartApp(const flutter::EncodableMap &args,
											  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub)
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}
		sub->Start();
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleStopApp(const flutter::EncodableMap &args,
											 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub)
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}
		sub->Stop();
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleSetManualControlRate(const flutter::EncodableMap &args,
														  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		double rate = GetDouble(args, "ratePct", 0.0);

		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub)
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}

		if (rate < 0.0)
			rate = 0.0;
		if (rate > 100.0)
			rate = 100.0;

		OutputManager::Instance().SetControlRate(static_cast<uint32_t>(sub_id), static_cast<float>(rate));
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetAppStatus(const flutter::EncodableMap &args,
												  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub || !sub->GetApplication())
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}

		auto status = sub->GetApplication()->GetStatus();
		flutter::EncodableMap map;
		map[flutter::EncodableValue("state")] = flutter::EncodableValue(static_cast<int>(status.state));
		map[flutter::EncodableValue("appType")] = flutter::EncodableValue(static_cast<int>(status.app_type));

		// 使用真实后端数据（不再被仿真线程覆盖）
		map[flutter::EncodableValue("currentWeight")] = flutter::EncodableValue(status.current_weight);
		map[flutter::EncodableValue("currentFlow")] = flutter::EncodableValue(status.current_flow);
		map[flutter::EncodableValue("statusMessage")] = flutter::EncodableValue(status.status_message);

		map[flutter::EncodableValue("controlRate")] = flutter::EncodableValue(status.control_rate);
		map[flutter::EncodableValue("targetFlow")] = flutter::EncodableValue(status.target_flow);
		map[flutter::EncodableValue("targetWeight")] = flutter::EncodableValue(status.target_weight);
		map[flutter::EncodableValue("accumulatedWeight")] = flutter::EncodableValue(status.accumulated_weight);
		map[flutter::EncodableValue("totalAccumulated")] = flutter::EncodableValue(status.total_accumulated);
		map[flutter::EncodableValue("remainingTime")] = flutter::EncodableValue(status.remaining_time);
		map[flutter::EncodableValue("stepNumber")] = flutter::EncodableValue(status.step_number);
		map[flutter::EncodableValue("warningActive")] = flutter::EncodableValue(status.warning_active);
		map[flutter::EncodableValue("warningMessage")] = flutter::EncodableValue(status.warning_message);

		result->Success(flutter::EncodableValue(map));
	}

	void WeighingSystemPlugin::HandleGetDigitalOutputMapConfig(const flutter::EncodableMap &args,
															   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto cfg = weighing::OutputManager::Instance().GetDigitalOutputMapConfig();

		flutter::EncodableList bindings;
		for (const auto &b : cfg.bindings)
		{
			flutter::EncodableMap item;
			item[flutter::EncodableValue("subsystem_id")] = flutter::EncodableValue((int)b.subsystem_id);
			item[flutter::EncodableValue("io_pos")] = flutter::EncodableValue((int)b.io_pos);
			item[flutter::EncodableValue("channel")] = flutter::EncodableValue((int)b.channel);
			item[flutter::EncodableValue("signal")] = flutter::EncodableValue((int)b.signal);
			item[flutter::EncodableValue("bit_index")] = flutter::EncodableValue((int)b.bit_index);
			item[flutter::EncodableValue("active_high")] = flutter::EncodableValue(b.active_high);
			item[flutter::EncodableValue("enabled")] = flutter::EncodableValue(b.enabled);
			item[flutter::EncodableValue("app_scope")] = flutter::EncodableValue((int)b.app_scope);
			bindings.emplace_back(item);
		}

		// === 新增：序列化 servo_bindings ===
		flutter::EncodableList servo_bindings_list;
		for (const auto &b : cfg.servo_bindings)
		{
			flutter::EncodableMap sb_map;
			sb_map[flutter::EncodableValue("subsystem_id")] = flutter::EncodableValue(static_cast<int32_t>(b.subsystem_id));
			sb_map[flutter::EncodableValue("servo_pos")] = flutter::EncodableValue(static_cast<int32_t>(b.servo_pos));
			sb_map[flutter::EncodableValue("signal")] = flutter::EncodableValue(static_cast<int32_t>(b.signal));
			sb_map[flutter::EncodableValue("enabled")] = flutter::EncodableValue(b.enabled);
			sb_map[flutter::EncodableValue("app_scope")] = flutter::EncodableValue(b.app_scope);
			servo_bindings_list.push_back(flutter::EncodableValue(sb_map));
		}

		flutter::EncodableMap out;
		out[flutter::EncodableValue("version")] = flutter::EncodableValue(cfg.version);
		out[flutter::EncodableValue("bindings")] = flutter::EncodableValue(bindings);
		out[flutter::EncodableValue("servo_bindings")] = flutter::EncodableValue(servo_bindings_list);
		result->Success(flutter::EncodableValue(out));
		return;
	}

	void WeighingSystemPlugin::HandleValidateDigitalOutputMapConfig(const flutter::EncodableMap &args,
																	std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		weighing::DigitalOutputMapConfig cfg;
		std::string parse_err;
		if (!ParseDigitalOutputMapConfig(args, &cfg, &parse_err))
		{
			result->Success(flutter::EncodableValue(BuildMapResult(false, parse_err)));
			return;
		}

		weighing::DigitalOutputMap tmp;
		std::string err;
		bool ok = tmp.SetConfig(cfg, &err);

		flutter::EncodableMap out;
		out[flutter::EncodableValue("ok")] = flutter::EncodableValue(ok);
		out[flutter::EncodableValue("error")] = flutter::EncodableValue(err);
		result->Success(flutter::EncodableValue(out));
		return;
	}

	void WeighingSystemPlugin::HandleUpdateDigitalOutputMapConfig(const flutter::EncodableMap &args,
																  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		weighing::DigitalOutputMapConfig cfg;
		std::string parse_err;
		if (!ParseDigitalOutputMapConfig(args, &cfg, &parse_err))
		{
			result->Success(flutter::EncodableValue(BuildMapResult(false, parse_err)));
			return;
		}

		std::string err;

		// 1) 先校验 + 热应用（内存）
		if (!OutputManager::Instance().UpdateDigitalOutputMap(cfg, &err))
		{
			result->Success(flutter::EncodableValue(BuildMapResult(false, "apply: " + err)));
			return;
		}

		// 2) 再持久化到 input_mode.json
		if (!SystemInitializer::Instance().SaveDigitalOutputMapToConfig(cfg, &err))
		{
			result->Success(flutter::EncodableValue(BuildMapResult(false, "save: " + err)));
			return;
		}

		result->Success(flutter::EncodableValue(BuildMapResult(true, "")));
		return;
	}

	// ============================================================================
	// 配方管理实现
	// ============================================================================

	void WeighingSystemPlugin::HandleLoadRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int recipe_id = GetInt(args, "recipeId");

		bool ok = CentralController::Instance().LoadRecipe(recipe_id);
		result->Success(flutter::EncodableValue(ok));
	}

	void WeighingSystemPlugin::HandleSaveRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto it = args.find(flutter::EncodableValue("recipe"));
		if (it == args.end() || !std::holds_alternative<flutter::EncodableMap>(it->second))
		{
			result->Error("INVALID_ARGUMENT", "recipe map required");
			return;
		}

		const auto *recipe_map = std::get_if<flutter::EncodableMap>(&it->second);
		Recipe recipe = MapToRecipe(*recipe_map);

		bool ok = CentralController::Instance().SaveRecipe(recipe);
		result->Success(flutter::EncodableValue(ok));
	}

	void WeighingSystemPlugin::HandleGetAllRecipes(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto recipes = CentralController::Instance().GetAllRecipes();

		flutter::EncodableList list;
		for (const auto &recipe : recipes)
		{
			list.push_back(flutter::EncodableValue(RecipeToMap(recipe)));
		}

		result->Success(flutter::EncodableValue(list));
	}

	void WeighingSystemPlugin::HandleDeleteRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int recipe_id = GetInt(args, "recipeId");

		bool ok = CentralController::Instance().DeleteRecipe(recipe_id);
		result->Success(flutter::EncodableValue(ok));
	}

	// ============================================================================
	// 物料配方管理实现
	// ============================================================================

	void WeighingSystemPlugin::HandleSaveMaterialRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		int app_type = GetInt(args, "appType"); // 0=liw, 1=filling
		std::string name = GetString(args, "name", "未命名配方");

		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub)
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}

		uint32_t recipe_id = 0;
		if (app_type == 0)
		{
			auto *liw_app = sub->GetLiwApp();
			if (!liw_app)
			{
				result->Error("NOT_FOUND", "LIW app not found");
				return;
			}
			recipe_id = ConfigStore::Instance().SaveLiwMaterialRecipe(sub_id, name, liw_app);
		}
		else
		{
			auto *fill_app = sub->GetFillingApp();
			if (!fill_app)
			{
				result->Error("NOT_FOUND", "Filling app not found");
				return;
			}
			recipe_id = ConfigStore::Instance().SaveFillingMaterialRecipe(sub_id, name, fill_app);
		}

		result->Success(flutter::EncodableValue(recipe_id > 0));
	}

	void WeighingSystemPlugin::HandleLoadMaterialRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int sub_id = GetInt(args, "subsystemId");
		int recipe_id = GetInt(args, "recipeId");
		int app_type = GetInt(args, "appType"); // 0=liw, 1=filling

		auto *sub = SubsystemManager::Instance().GetSubsystem(sub_id);
		if (!sub)
		{
			result->Error("NOT_FOUND", "Subsystem not found");
			return;
		}

		bool ok = false;
		if (app_type == 0)
		{
			auto *liw_app = sub->GetLiwApp();
			if (!liw_app)
			{
				result->Error("NOT_FOUND", "LIW app not found");
				return;
			}
			ok = ConfigStore::Instance().LoadLiwMaterialRecipe(recipe_id, liw_app);
			if (ok)
				ConfigStore::Instance().SaveLiwConfig(sub_id, liw_app);
		}
		else
		{
			auto *fill_app = sub->GetFillingApp();
			if (!fill_app)
			{
				result->Error("NOT_FOUND", "Filling app not found");
				return;
			}
			ok = ConfigStore::Instance().LoadFillingMaterialRecipe(recipe_id, fill_app);
			if (ok)
				ConfigStore::Instance().SaveFillingConfig(sub_id, fill_app);
		}

		result->Success(flutter::EncodableValue(ok));
	}

	void WeighingSystemPlugin::HandleGetAllMaterialRecipes(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int app_type = GetInt(args, "appType", -1); // -1 = all

		auto recipes = ConfigStore::Instance().GetAllMaterialRecipes(app_type);

		flutter::EncodableList list;
		for (const auto &r : recipes)
		{
			flutter::EncodableMap item;
			item[flutter::EncodableValue("recipeId")] = flutter::EncodableValue(static_cast<int>(r.recipe_id));
			item[flutter::EncodableValue("name")] = flutter::EncodableValue(r.name);
			item[flutter::EncodableValue("appType")] = flutter::EncodableValue(r.app_type);
			item[flutter::EncodableValue("subsystemId")] = flutter::EncodableValue(static_cast<int>(r.subsystem_id));
			item[flutter::EncodableValue("createdAt")] = flutter::EncodableValue(r.created_at);
			list.push_back(flutter::EncodableValue(item));
		}

		result->Success(flutter::EncodableValue(list));
	}

	void WeighingSystemPlugin::HandleDeleteMaterialRecipe(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int recipe_id = GetInt(args, "recipeId");
		int app_type = GetInt(args, "appType");

		bool ok = ConfigStore::Instance().DeleteMaterialRecipe(recipe_id, app_type);
		result->Success(flutter::EncodableValue(ok));
	}

	// ============================================================================
	// 流量控制实现
	// ============================================================================

	void WeighingSystemPlugin::HandleSetMasterFlow(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		double flow = GetDouble(args, "flow");

		CentralController::Instance().SetMasterFlow(flow);
		result->Success(flutter::EncodableValue(true));
	}

	void WeighingSystemPlugin::HandleGetMasterFlow(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		double flow = CentralController::Instance().GetMasterFlow();
		result->Success(flutter::EncodableValue(flow));
	}

	void WeighingSystemPlugin::HandleGetTotalActualFlow(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		double flow = CentralController::Instance().GetTotalActualFlow();
		result->Success(flutter::EncodableValue(flow));
	}

	// ============================================================================
	// 状态查询实现
	// ============================================================================

	void WeighingSystemPlugin::HandleGetSubsystemStatus(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int subsystem_id = GetInt(args, "subsystemId");

		auto status = CentralController::Instance().GetSubsystemStatus(subsystem_id);
		result->Success(flutter::EncodableValue(SubsystemStatusToMap(status)));
	}

	void WeighingSystemPlugin::HandleGetAllSubsystemStatuses(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto statuses = CentralController::Instance().GetAllStatuses();

		flutter::EncodableMap map;
		for (const auto &[sub_id, status] : statuses)
		{
			map[flutter::EncodableValue(static_cast<int>(sub_id))] =
				flutter::EncodableValue(SubsystemStatusToMap(status));
		}

		result->Success(flutter::EncodableValue(map));
	}

	// ============================================================================
	// 批次管理实现
	// ============================================================================

	void WeighingSystemPlugin::HandleStartBatch(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		std::string operator_name = GetString(args, "operatorName", "");

		uint32_t batch_id = CentralController::Instance().StartBatch(operator_name);
		result->Success(flutter::EncodableValue(static_cast<int>(batch_id)));
	}

	void WeighingSystemPlugin::HandleEndBatch(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		bool ok = CentralController::Instance().EndBatch();
		result->Success(flutter::EncodableValue(ok));
	}

	void WeighingSystemPlugin::HandleGetCurrentBatchId(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		uint32_t batch_id = CentralController::Instance().GetCurrentBatchId();
		result->Success(flutter::EncodableValue(static_cast<int>(batch_id)));
	}

	// ============================================================================
	// HMI Subsystem 配置 — 新增处理器实现
	// ============================================================================

	void WeighingSystemPlugin::HandleScanEthercatSlaves(
		const flutter::EncodableMap & /*args*/,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto slaves = EtherCATMaster::Instance().ScanSlaves();

		flutter::EncodableList list;
		for (const auto &s : slaves)
		{
			flutter::EncodableMap item;
			item[EV("position")] = EV(static_cast<int32_t>(s.position));
			item[EV("alias")] = EV(static_cast<int32_t>(s.alias));
			item[EV("vendorId")] = EV(static_cast<int64_t>(s.vendor_id));
			item[EV("productCode")] = EV(static_cast<int64_t>(s.product_code));
			item[EV("description")] = EV(s.description);
			item[EV("userAlias")] = EV(s.user_alias);
			list.push_back(EV(item));
		}
		result->Success(EV(list));
	}

	void WeighingSystemPlugin::HandleGetInputMode(
		const flutter::EncodableMap & /*args*/,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		result->Success(EV(SystemInitializer::Instance().GetInputMode()));
	}

	void WeighingSystemPlugin::HandleGetSubsystemMappings(
		const flutter::EncodableMap & /*args*/,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		const auto &mappings = SystemInitializer::Instance().GetSubsystemMappings();
		flutter::EncodableList list;
		for (const auto &m : mappings)
		{
			flutter::EncodableMap item;
			item[EV("subsystemId")] = EV(static_cast<int32_t>(m.sub_id));
			item[EV("scaleId")] = EV(static_cast<int32_t>(m.scale_id));
			item[EV("ioPosition")] = EV(static_cast<int32_t>(m.io_position));
			item[EV("description")] = EV(m.description);
			list.push_back(EV(item));
		}
		result->Success(EV(list));
	}

	void WeighingSystemPlugin::HandleUpdateSubsystemMapping(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int subsystem_id = GetInt(args, "subsystemId");
		int scale_id = GetInt(args, "scaleId");

		std::string err;
		bool ok = SystemInitializer::Instance().SaveSubsystemMappingToConfig(
			static_cast<uint32_t>(subsystem_id),
			static_cast<uint32_t>(scale_id),
			&err);

		result->Success(EV(BuildMapResult(ok, err)));
	}

	void WeighingSystemPlugin::HandleUpdateSlaveAlias(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int position = GetInt(args, "position");
		std::string alias = GetString(args, "alias");

		std::string err;
		bool ok = SystemInitializer::Instance().SaveSlaveAliasToConfig(
			static_cast<uint16_t>(position), alias, &err);

		result->Success(EV(BuildMapResult(ok, err)));
	}

	void WeighingSystemPlugin::HandleAddSubsystemMapping(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int subsystem_id = GetInt(args, "subsystemId");
		int io_position = GetInt(args, "ioPosition", 0);
		int scale_id = GetInt(args, "scaleId", 0);
		std::string description = GetString(args, "description");

		std::string err;
		bool ok = SystemInitializer::Instance().AddSubsystemToConfig(
			static_cast<uint32_t>(subsystem_id),
			static_cast<uint16_t>(io_position),
			static_cast<uint32_t>(scale_id),
			description,
			&err);

		result->Success(EV(BuildMapResult(ok, err)));
	}

	void WeighingSystemPlugin::HandleRemoveSubsystemMapping(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		int subsystem_id = GetInt(args, "subsystemId");

		std::string err;
		bool ok = SystemInitializer::Instance().RemoveSubsystemFromConfig(
			static_cast<uint32_t>(subsystem_id),
			&err);

		result->Success(EV(BuildMapResult(ok, err)));
	}

	// Weight event stream management
	void WeighingSystemPlugin::StartWeightEventStream()
	{
		ScaleManager::Instance().SetGlobalWeightCallback(
			[this](const WeightData &data)
			{
				// 【核心修复】一旦启用了闭环模拟线程，直接抛弃底层的真实 ADC 回调！
				// 避免 shmem 共享内存一直发 0.0 kg 把 UI 刷没。
				if (mock_thread_running_)
					return;

				if (weight_event_sink_)
				{
					auto map = WeightDataToMap(data);
					weight_event_sink_->Success(flutter::EncodableValue(map));
				}
			});

		ScaleManager::Instance().SetGlobalStatusCallback(
			[this](uint32_t scale_id, ScaleState state, const std::string &msg)
			{
				if (mock_thread_running_)
					return; // 同样屏蔽杂乱的状态报警

				if (status_event_sink_)
				{
					flutter::EncodableMap map;
					map[flutter::EncodableValue("scaleId")] = flutter::EncodableValue(static_cast<int>(scale_id));
					map[flutter::EncodableValue("state")] = flutter::EncodableValue(static_cast<int>(state));
					map[flutter::EncodableValue("message")] = flutter::EncodableValue(msg);
					status_event_sink_->Success(flutter::EncodableValue(map));
				}
			});
	}

	void WeighingSystemPlugin::StopWeightEventStream()
	{
		ScaleManager::Instance().SetGlobalWeightCallback(nullptr);
		ScaleManager::Instance().SetGlobalStatusCallback(nullptr);
	}

	// 3. 重写模拟线程（精华部分：物理环境闭环仿真）
	void WeighingSystemPlugin::StartMockThread()
	{
		if (mock_thread_running_)
			return;
		mock_thread_running_ = true;

		mock_thread_ = std::make_unique<std::thread>([this]()
													 {
			auto last_time = std::chrono::steady_clock::now();
			
			double current_weight = 10.0; 
			const double max_capacity_kg_h = 25.0; 
			int refill_anim_frames = 0; // 用于维持补料动画的时间

			while (mock_thread_running_) {
				auto now = std::chrono::steady_clock::now();
				double dt_sec = std::chrono::duration<double>(now - last_time).count();
				last_time = now;

				auto* scale = ScaleManager::Instance().GetScale(0);
				if (scale) scale->SetMockMode(true);

				bool is_refilling = false; // 【新增】用于记录当前是否在补料

				auto* sub = SubsystemManager::Instance().GetSubsystem(0);
				if (sub && sub->GetApplication()) {
					auto status = sub->GetApplication()->GetStatus();
					
					std::lock_guard<std::mutex> lock(mock_ui_mutex_); // 保护字符串赋值

					// 优先展示补料动画 (维持大约 0.5 秒)
					if (refill_anim_frames > 0) {
						mock_ui_status_ = "Refilling / 补料";
						mock_ui_flow_.store(0.0);
						refill_anim_frames--;
						is_refilling = true; // 状态标记为补料中
					}
					// 只有底层在运行，我们才显示喂料
					else if (status.state == AppRunState::kRunning || status.state == AppRunState::kEmptying) {
						double ctrl_rate = status.control_rate; 
						
						double actual_flow_kg_h = max_capacity_kg_h * (ctrl_rate / 100.0);
						actual_flow_kg_h += ((rand() % 100) - 50) / 2000.0; 
						if (actual_flow_kg_h < 0) actual_flow_kg_h = 0;

						double weight_drop = actual_flow_kg_h * (dt_sec / 3600.0);
						current_weight -= weight_drop;
						
						// 锁定 UI 显示为连续喂料，防止闪烁
						mock_ui_flow_.store(actual_flow_kg_h);
						mock_ui_status_ = "Feeding / 喂料"; 
					} 
					else {
						mock_ui_flow_.store(0.0);
						mock_ui_status_ = "Idle / 待机";
					}
					
					// 触发自动补料
					if (current_weight <= 9.0) {
						current_weight = 10.0; 
						refill_anim_frames = 100; // 50ms * 100 = 5s 补料动画
						is_refilling = true; // 状态标记为补料中
					}
				}

				// ====================================================================
				// 【新增】：将补料状态下发给物理 IO 模块！
				// 参数：(子系统ID, 通道, 快速加料, 慢速加料, 补料阀, 排料阀)
				// ====================================================================
				OutputManager::Instance().SetValveOutputs(0, 0, sub->GetApplication()->GetAppType(), false, false, is_refilling, false);

				mock_ui_weight_.store(current_weight); // 存给 API 读取

				if (scale) {
					scale->FeedMockWeight(current_weight); // 依然喂给底层PID
				}

				// 实时推送重量事件给 Flutter
				if (weight_event_sink_) {
					WeightData data{};
					data.scale_id = 0;
					data.gross_weight = current_weight;
					data.net_weight = current_weight;
					data.tare_weight = 0.0;
					data.motion = MotionState::kStable;
					data.is_zero = (current_weight < 0.01);
					data.is_overload = false;
					data.is_underload = false;
					data.is_net_mode = false;
					data.unit = WeightUnit::kKilogram;
					
					auto map = WeightDataToMap(data);
					weight_event_sink_->Success(flutter::EncodableValue(map));
				}

				std::this_thread::sleep_for(std::chrono::milliseconds(50)); 
			} });
	}

	void WeighingSystemPlugin::StopMockThread()
	{
		mock_thread_running_ = false;
		if (mock_thread_ && mock_thread_->joinable())
		{
			mock_thread_->join();
		}
		mock_thread_.reset();
	}

	// ============================================================================
	// 硬件配置状态
	// ============================================================================

	void WeighingSystemPlugin::HandleGetConfigStatus(
		const flutter::EncodableMap & /*args*/,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		auto &si = SystemInitializer::Instance();
		flutter::EncodableMap out;
		out[EV("has_output_slaves")] = EV(si.GetHasOutputSlaves());
		out[EV("has_input_source")] = EV(si.GetHasInputSourceConfig());
		out[EV("has_digital_output_map")] = EV(si.GetHasDioMapCfg());
		result->Success(EV(out));
	}

	void WeighingSystemPlugin::HandleSaveEthercatHardwareConfig(
		const flutter::EncodableMap &args,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		// Parse output_slaves list
		std::vector<SystemInitializer::SlaveEntry> output_slaves;
		auto it_out = args.find(EV("outputSlaves"));
		if (it_out != args.end())
		{
			const auto &list = std::get<flutter::EncodableList>(it_out->second);
			for (const auto &item : list)
			{
				const auto &m = std::get<flutter::EncodableMap>(item);
				SystemInitializer::SlaveEntry e;
				e.alias = static_cast<uint16_t>(GetInt(m, "alias"));
				e.position = static_cast<uint16_t>(GetInt(m, "position"));
				e.vendor_id = static_cast<uint32_t>(GetInt(m, "vendorId"));
				e.product_code = static_cast<uint32_t>(GetInt(m, "productCode"));
				e.description = GetString(m, "description", "");
				output_slaves.push_back(e);
			}
		}

		// Parse input_slaves list
		std::vector<SystemInitializer::SlaveEntry> input_slaves;
		auto it_in = args.find(EV("inputSlaves"));
		if (it_in != args.end())
		{
			const auto &list = std::get<flutter::EncodableList>(it_in->second);
			for (const auto &item : list)
			{
				const auto &m = std::get<flutter::EncodableMap>(item);
				SystemInitializer::SlaveEntry e;
				e.alias = static_cast<uint16_t>(GetInt(m, "alias"));
				e.position = static_cast<uint16_t>(GetInt(m, "position"));
				e.vendor_id = static_cast<uint32_t>(GetInt(m, "vendorId"));
				e.product_code = static_cast<uint32_t>(GetInt(m, "productCode"));
				e.description = GetString(m, "description", "");
				input_slaves.push_back(e);
			}
		}

		std::string err;
		bool ok = SystemInitializer::Instance().SaveEthercatHardwareConfig(
			output_slaves, input_slaves, &err);
		result->Success(EV(BuildMapResult(ok, err)));
	}

} // namespace

void WeighingSystemElinuxPluginRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar)
{
	WeighingSystemPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarManager::GetInstance()
			->GetRegistrar<flutter::PluginRegistrar>(registrar));
}