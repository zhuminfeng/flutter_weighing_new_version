import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'models/weight_data.dart';
import 'models/scale_params.dart';
import 'models/zero_config.dart';
import 'models/tare_config.dart';
import 'models/filter_stability_config.dart';
import 'models/liw_config.dart';
import 'models/filling_config.dart';
import 'models/system_status.dart';
import 'models/digital_output_map.dart';
import 'models/ethercat_device.dart';

abstract class WeighingPlatform extends PlatformInterface {
  WeighingPlatform() : super(token: _token);
  static final Object _token = Object();
  static WeighingPlatform? _instance;
  static WeighingPlatform get instance => _instance!;
  static set instance(WeighingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // System
  Future<bool> initialize(
      {String dbPath = '/data/weighing_system.db',
      String inputConfigPath = '/etc/weighing/input_mode.json'});
  Future<void> shutdown();

  // Weight stream
  Stream<WeightData> get weightStream;
  Stream<Map<String, dynamic>> get statusStream;

  // Scale config
  Future<bool> updateScaleParams(int scaleId, ScaleParams params);
  Future<ScaleParams> getScaleParams(int scaleId);
  Future<bool> updateZeroConfig(int scaleId, ZeroConfig config);
  Future<ZeroConfig> getZeroConfig(int scaleId);
  Future<bool> updateTareConfig(int scaleId, TareConfig config);
  Future<TareConfig> getTareConfig(int scaleId);
  Future<bool> updateFilterStability(int scaleId, FilterStabilityConfig config);
  Future<FilterStabilityConfig> getFilterStability(int scaleId);

  // Scale operations
  Future<bool> doZero(int scaleId);
  Future<bool> doTare(int scaleId);
  Future<bool> clearTare(int scaleId);
  Future<bool> setPresetTare(int scaleId, double value);

  // Calibration
  Future<bool> triggerCalZero(int scaleId);
  Future<bool> triggerCalSpan(
      int scaleId, int linearMode, List<double> testLoads);
  Future<bool> triggerSaveCalibration(int scaleId);
  Future<bool> triggerAbortCalibration(int scaleId);
  Future<bool> triggerStepCalibration(int scaleId, double testWeight);

  // LIW config
  Future<bool> updateLiwBaseConfig(int subsystemId, LiwBaseConfig config);
  Future<LiwBaseConfig> getLiwBaseConfig(int subsystemId);
  Future<bool> updateLiwSystemConfig(int subsystemId, LiwSystemConfig config);
  Future<LiwSystemConfig> getLiwSystemConfig(int subsystemId);
  Future<bool> updateLiwSystemIdConfig(
      int subsystemId, LiwSystemIdConfig config);
  Future<LiwSystemIdConfig> getLiwSystemIdConfig(int subsystemId);
  Future<bool> updateLiwControllerConfig(
      int subsystemId, LiwControllerConfig config);
  Future<LiwControllerConfig> getLiwControllerConfig(int subsystemId);
  Future<bool> updateLiwRefillConfig(int subsystemId, LiwRefillConfig config);
  Future<LiwRefillConfig> getLiwRefillConfig(int subsystemId);
  Future<bool> updateLiwTargetValuesConfig(
      int subsystemId, LiwTargetValuesConfig config);
  Future<LiwTargetValuesConfig> getLiwTargetValuesConfig(int subsystemId);
  Future<bool> updateLiwToleranceCheckConfig(
      int subsystemId, LiwToleranceCheckConfig config);
  Future<LiwToleranceCheckConfig> getLiwToleranceCheckConfig(int subsystemId);
  Future<bool> updateLiwEmptyingConfig(
      int subsystemId, LiwEmptyingConfig config);
  Future<LiwEmptyingConfig> getLiwEmptyingConfig(int subsystemId);
  Future<bool> updateLiwWarningConfig(int subsystemId, LiwWarningConfig config);
  Future<LiwWarningConfig> getLiwWarningConfig(int subsystemId);
  Future<bool> updateLiwFlowMonitorConfig(
      int subsystemId, LiwFlowMonitorConfig config);
  Future<LiwFlowMonitorConfig> getLiwFlowMonitorConfig(int subsystemId);
  Future<bool> updateLiwAdvancedConfig(
      int subsystemId, LiwAdvancedConfig config);
  Future<LiwAdvancedConfig> getLiwAdvancedConfig(int subsystemId);
  Future<bool> updateLiwStatsConfig(int subsystemId, LiwStatsConfig config);
  Future<LiwStatsConfig> getLiwStatsConfig(int subsystemId);

  // Filling config
  Future<bool> updateFillingGeneralConfig(
      int subsystemId, FillingGeneralConfig config);
  Future<FillingGeneralConfig> getFillingGeneralConfig(int subsystemId);
  Future<bool> updateFillingSystemConfig(
      int subsystemId, FillingSystemConfig config);
  Future<FillingSystemConfig> getFillingSystemConfig(int subsystemId);
  Future<bool> updateFillingTargetConfig(
      int subsystemId, FillingTargetConfig config);
  Future<FillingTargetConfig> getFillingTargetConfig(int subsystemId);
  Future<bool> updateFillingAutoTareConfig(
      int subsystemId, FillingAutoTareConfig config);
  Future<FillingAutoTareConfig> getFillingAutoTareConfig(int subsystemId);
  Future<bool> updateFillingToleranceConfig(
      int subsystemId, FillingToleranceConfig config);
  Future<FillingToleranceConfig> getFillingToleranceConfig(int subsystemId);
  Future<bool> updateFillingSpillOptConfig(
      int subsystemId, FillingSpillOptConfig config);
  Future<FillingSpillOptConfig> getFillingSpillOptConfig(int subsystemId);
  Future<bool> updateFillingCutoffOptConfig(
      int subsystemId, FillingCutoffOptConfig config);
  Future<FillingCutoffOptConfig> getFillingCutoffOptConfig(int subsystemId);
  Future<bool> updateFillingJogConfig(int subsystemId, FillingJogConfig config);
  Future<FillingJogConfig> getFillingJogConfig(int subsystemId);
  Future<bool> updateFillingRefillConfig(
      int subsystemId, FillingRefillConfig config);
  Future<FillingRefillConfig> getFillingRefillConfig(int subsystemId);
  Future<bool> updateFillingEmptyingConfig(
      int subsystemId, FillingEmptyingConfig config);
  Future<FillingEmptyingConfig> getFillingEmptyingConfig(int subsystemId);
  Future<bool> updateFillingEventsConfig(
      int subsystemId, FillingEventsConfig config);
  Future<FillingEventsConfig> getFillingEventsConfig(int subsystemId);
  Future<bool> updateFillingAdvancedConfig(
      int subsystemId, FillingAdvancedConfig config);
  Future<FillingAdvancedConfig> getFillingAdvancedConfig(int subsystemId);

  // Digital output mapping
  Future<bool> updateDigitalOutputMap(DigitalOutputMapConfig config);
  Future<DigitalOutputMapConfig> getDigitalOutputMap();
  Future<Map<String, dynamic>> validateDigitalOutputMap(
      DigitalOutputMapConfig config);
  Future<List<EthercatDeviceConfig>> getEthercatDevices();
  Future<bool> updateEthercatDevices(List<EthercatDeviceConfig> devices);

  /// 通过 IgH EtherCAT 库扫描当前总线上接入的从站（不依赖配置文件）
  Future<List<EthercatDeviceConfig>> scanEthercatSlaves();

  // App control
  Future<bool> startApp(int subsystemId);
  Future<bool> stopApp(int subsystemId);
  Future<bool> setManualControlRate(int subsystemId, double ratePct);
  Future<AppStatusData> getAppStatus(int subsystemId);

  // CentralController API
  Future<bool> loadRecipe(int recipeId);
  Future<bool> saveRecipe(Map<String, dynamic> recipe);
  Future<List<Map<String, dynamic>>> getAllRecipes();
  Future<bool> deleteRecipe(int recipeId);
  Future<bool> setMasterFlow(double flow);
  Future<double> getMasterFlow();
  Future<double> getTotalActualFlow();
  Future<Map<String, dynamic>?> getSubsystemStatus(int subsystemId);
  Future<Map<int, Map<String, dynamic>>> getAllSubsystemStatuses();
  Future<int> startBatch(String operatorName);
  Future<bool> endBatch();
  Future<int> getCurrentBatchId();
}
