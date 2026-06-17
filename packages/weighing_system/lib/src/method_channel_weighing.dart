import 'dart:async';
import 'package:flutter/services.dart';
import 'weighing_platform.dart';
import 'models/weight_data.dart';
import 'models/scale_params.dart';
import 'models/zero_config.dart';
import 'models/tare_config.dart';
import 'models/filter_stability_config.dart';
import 'models/liw_config.dart';
import 'models/filling_config.dart';
import 'models/system_status.dart';
import 'models/subsystem_config.dart';

class ELinuxWeighingSystem extends WeighingPlatform {
  static const MethodChannel _channel =
      MethodChannel('plugins.weighing_system/method');
  static const EventChannel _weightEventChannel =
      EventChannel('plugins.weighing_system/weight_events');
  static const EventChannel _statusEventChannel =
      EventChannel('plugins.weighing_system/status_events');

  Stream<WeightData>? _weightStream;
  Stream<Map<String, dynamic>>? _statusStreamCached;

  static void registerWith() {
    WeighingPlatform.instance = ELinuxWeighingSystem();
  }

  // ============ System ============

  @override
  Future<bool> initialize(
      {String dbPath = '/data/weighing_system.db',
      String inputConfigPath = '/etc/weighing/input_mode.json'}) async {
    final result = await _channel.invokeMethod<bool>('initialize', {
      'dbPath': dbPath,
      'inputConfigPath': inputConfigPath,
    });
    return result ?? false;
  }

  @override
  Future<void> shutdown() => _channel.invokeMethod('shutdown');

  // ============ Weight Stream ============

  @override
  Stream<WeightData> get weightStream {
    _weightStream ??= _weightEventChannel.receiveBroadcastStream().map(
        (event) => WeightData.fromMap(Map<String, dynamic>.from(event as Map)));
    return _weightStream!;
  }

  @override
  Stream<Map<String, dynamic>> get statusStream {
    _statusStreamCached ??= _statusEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _statusStreamCached!;
  }

  // ============ Scale Config ============

  @override
  Future<bool> updateScaleParams(int scaleId, ScaleParams params) async {
    final result = await _channel.invokeMethod<bool>('updateScaleParams', {
      'scaleId': scaleId,
      ...params.toMap(),
    });
    return result ?? false;
  }

  @override
  Future<ScaleParams> getScaleParams(int scaleId) async {
    final result = await _channel
        .invokeMethod<Map>('getScaleParams', {'scaleId': scaleId});
    return ScaleParams.fromMap(Map<String, dynamic>.from(result!));
  }

  @override
  Future<bool> updateZeroConfig(int scaleId, ZeroConfig config) async {
    final result = await _channel.invokeMethod<bool>('updateZeroConfig', {
      'scaleId': scaleId,
      ...config.toMap(),
    });
    return result ?? false;
  }

  @override
  Future<ZeroConfig> getZeroConfig(int scaleId) async {
    final result =
        await _channel.invokeMethod<Map>('getZeroConfig', {'scaleId': scaleId});
    return ZeroConfig.fromMap(Map<String, dynamic>.from(result!));
  }

  @override
  Future<bool> updateTareConfig(int scaleId, TareConfig config) async {
    final result = await _channel.invokeMethod<bool>('updateTareConfig', {
      'scaleId': scaleId,
      ...config.toMap(),
    });
    return result ?? false;
  }

  @override
  Future<TareConfig> getTareConfig(int scaleId) async {
    final result =
        await _channel.invokeMethod<Map>('getTareConfig', {'scaleId': scaleId});
    return TareConfig.fromMap(Map<String, dynamic>.from(result!));
  }

  @override
  Future<bool> updateFilterStability(
      int scaleId, FilterStabilityConfig config) async {
    final result = await _channel.invokeMethod<bool>('updateFilterStability', {
      'scaleId': scaleId,
      ...config.toMap(),
    });
    return result ?? false;
  }

  @override
  Future<FilterStabilityConfig> getFilterStability(int scaleId) async {
    final result = await _channel
        .invokeMethod<Map>('getFilterStability', {'scaleId': scaleId});
    return FilterStabilityConfig.fromMap(Map<String, dynamic>.from(result!));
  }

  // ============ Scale Operations ============

  @override
  Future<bool> doZero(int scaleId) async {
    final result =
        await _channel.invokeMethod<bool>('doZero', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> doTare(int scaleId) async {
    final result =
        await _channel.invokeMethod<bool>('doTare', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> clearTare(int scaleId) async {
    final result =
        await _channel.invokeMethod<bool>('clearTare', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> setPresetTare(int scaleId, double value) async {
    final result = await _channel.invokeMethod<bool>('setPresetTare', {
      'scaleId': scaleId,
      'value': value,
    });
    return result ?? false;
  }

  // ============ Calibration ============

  @override
  Future<bool> triggerCalZero(int scaleId) async {
    final result = await _channel
        .invokeMethod<bool>('triggerCalZero', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> triggerCalSpan(
      int scaleId, int linearMode, List<double> testLoads) async {
    final result = await _channel.invokeMethod<bool>('triggerCalSpan', {
      'scaleId': scaleId,
      'linearMode': linearMode,
      'testLoads': testLoads,
    });
    return result ?? false;
  }

  @override
  Future<bool> triggerSaveCalibration(int scaleId) async {
    final result = await _channel
        .invokeMethod<bool>('triggerSaveCalibration', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> triggerAbortCalibration(int scaleId) async {
    final result = await _channel
        .invokeMethod<bool>('triggerAbortCalibration', {'scaleId': scaleId});
    return result ?? false;
  }

  @override
  Future<bool> triggerStepCalibration(int scaleId, double testWeight) async {
    final result = await _channel.invokeMethod<bool>('triggerStepCalibration', {
      'scaleId': scaleId,
      'testWeight': testWeight,
    });
    return result ?? false;
  }

  // ============ LIW Config (all sub-configs follow same pattern) ============

  Future<bool> _updateConfig(
      String method, int subsystemId, Map<String, dynamic> config) async {
    final result = await _channel.invokeMethod<bool>(method, {
      'subsystemId': subsystemId,
      ...config,
    });
    return result ?? false;
  }

  Future<Map<String, dynamic>> _getConfig(
      String method, int subsystemId) async {
    final result =
        await _channel.invokeMethod<Map>(method, {'subsystemId': subsystemId});
    return Map<String, dynamic>.from(result!);
  }

  @override
  Future<bool> updateLiwBaseConfig(int id, LiwBaseConfig c) =>
      _updateConfig('updateLiwBaseConfig', id, c.toMap());
  @override
  Future<LiwBaseConfig> getLiwBaseConfig(int id) async =>
      LiwBaseConfig.fromMap(await _getConfig('getLiwBaseConfig', id));

  @override
  Future<bool> updateLiwSystemConfig(int id, LiwSystemConfig c) =>
      _updateConfig('updateLiwSystemConfig', id, c.toMap());
  @override
  Future<LiwSystemConfig> getLiwSystemConfig(int id) async =>
      LiwSystemConfig.fromMap(await _getConfig('getLiwSystemConfig', id));

  @override
  Future<bool> updateLiwSystemIdConfig(int id, LiwSystemIdConfig c) =>
      _updateConfig('updateLiwSystemIdConfig', id, c.toMap());
  @override
  Future<LiwSystemIdConfig> getLiwSystemIdConfig(int id) async =>
      LiwSystemIdConfig.fromMap(await _getConfig('getLiwSystemIdConfig', id));

  @override
  Future<bool> updateLiwControllerConfig(int id, LiwControllerConfig c) =>
      _updateConfig('updateLiwControllerConfig', id, c.toMap());
  @override
  Future<LiwControllerConfig> getLiwControllerConfig(int id) async =>
      LiwControllerConfig.fromMap(
          await _getConfig('getLiwControllerConfig', id));

  @override
  Future<bool> updateLiwRefillConfig(int id, LiwRefillConfig c) =>
      _updateConfig('updateLiwRefillConfig', id, c.toMap());
  @override
  Future<LiwRefillConfig> getLiwRefillConfig(int id) async =>
      LiwRefillConfig.fromMap(await _getConfig('getLiwRefillConfig', id));

  @override
  Future<bool> updateLiwTargetValuesConfig(int id, LiwTargetValuesConfig c) =>
      _updateConfig('updateLiwTargetValuesConfig', id, c.toMap());
  @override
  Future<LiwTargetValuesConfig> getLiwTargetValuesConfig(int id) async =>
      LiwTargetValuesConfig.fromMap(
          await _getConfig('getLiwTargetValuesConfig', id));

  @override
  Future<bool> updateLiwToleranceCheckConfig(
          int id, LiwToleranceCheckConfig c) =>
      _updateConfig('updateLiwToleranceCheckConfig', id, c.toMap());
  @override
  Future<LiwToleranceCheckConfig> getLiwToleranceCheckConfig(int id) async =>
      LiwToleranceCheckConfig.fromMap(
          await _getConfig('getLiwToleranceCheckConfig', id));

  @override
  Future<bool> updateLiwEmptyingConfig(int id, LiwEmptyingConfig c) =>
      _updateConfig('updateLiwEmptyingConfig', id, c.toMap());
  @override
  Future<LiwEmptyingConfig> getLiwEmptyingConfig(int id) async =>
      LiwEmptyingConfig.fromMap(await _getConfig('getLiwEmptyingConfig', id));

  @override
  Future<bool> updateLiwWarningConfig(int id, LiwWarningConfig c) =>
      _updateConfig('updateLiwWarningConfig', id, c.toMap());
  @override
  Future<LiwWarningConfig> getLiwWarningConfig(int id) async =>
      LiwWarningConfig.fromMap(await _getConfig('getLiwWarningConfig', id));

  @override
  Future<bool> updateLiwFlowMonitorConfig(int id, LiwFlowMonitorConfig c) =>
      _updateConfig('updateLiwFlowMonitorConfig', id, c.toMap());
  @override
  Future<LiwFlowMonitorConfig> getLiwFlowMonitorConfig(int id) async =>
      LiwFlowMonitorConfig.fromMap(
          await _getConfig('getLiwFlowMonitorConfig', id));

  @override
  Future<bool> updateLiwAdvancedConfig(int id, LiwAdvancedConfig c) =>
      _updateConfig('updateLiwAdvancedConfig', id, c.toMap());
  @override
  Future<LiwAdvancedConfig> getLiwAdvancedConfig(int id) async =>
      LiwAdvancedConfig.fromMap(await _getConfig('getLiwAdvancedConfig', id));

  @override
  Future<bool> updateLiwStatsConfig(int id, LiwStatsConfig c) =>
      _updateConfig('updateLiwStatsConfig', id, c.toMap());
  @override
  Future<LiwStatsConfig> getLiwStatsConfig(int id) async =>
      LiwStatsConfig.fromMap(await _getConfig('getLiwStatsConfig', id));

  // ============ Filling Config ============

  @override
  Future<bool> updateFillingGeneralConfig(int id, FillingGeneralConfig c) =>
      _updateConfig('updateFillingGeneralConfig', id, c.toMap());
  @override
  Future<FillingGeneralConfig> getFillingGeneralConfig(int id) async =>
      FillingGeneralConfig.fromMap(
          await _getConfig('getFillingGeneralConfig', id));

  @override
  Future<bool> updateFillingSystemConfig(int id, FillingSystemConfig c) =>
      _updateConfig('updateFillingSystemConfig', id, c.toMap());
  @override
  Future<FillingSystemConfig> getFillingSystemConfig(int id) async =>
      FillingSystemConfig.fromMap(
          await _getConfig('getFillingSystemConfig', id));

  @override
  Future<bool> updateFillingTargetConfig(int id, FillingTargetConfig c) =>
      _updateConfig('updateFillingTargetConfig', id, c.toMap());
  @override
  Future<FillingTargetConfig> getFillingTargetConfig(int id) async =>
      FillingTargetConfig.fromMap(
          await _getConfig('getFillingTargetConfig', id));

  @override
  Future<bool> updateFillingAutoTareConfig(int id, FillingAutoTareConfig c) =>
      _updateConfig('updateFillingAutoTareConfig', id, c.toMap());
  @override
  Future<FillingAutoTareConfig> getFillingAutoTareConfig(int id) async =>
      FillingAutoTareConfig.fromMap(
          await _getConfig('getFillingAutoTareConfig', id));

  @override
  Future<bool> updateFillingToleranceConfig(int id, FillingToleranceConfig c) =>
      _updateConfig('updateFillingToleranceConfig', id, c.toMap());
  @override
  Future<FillingToleranceConfig> getFillingToleranceConfig(int id) async =>
      FillingToleranceConfig.fromMap(
          await _getConfig('getFillingToleranceConfig', id));

  @override
  Future<bool> updateFillingSpillOptConfig(int id, FillingSpillOptConfig c) =>
      _updateConfig('updateFillingSpillOptConfig', id, c.toMap());
  @override
  Future<FillingSpillOptConfig> getFillingSpillOptConfig(int id) async =>
      FillingSpillOptConfig.fromMap(
          await _getConfig('getFillingSpillOptConfig', id));

  @override
  Future<bool> updateFillingCutoffOptConfig(int id, FillingCutoffOptConfig c) =>
      _updateConfig('updateFillingCutoffOptConfig', id, c.toMap());
  @override
  Future<FillingCutoffOptConfig> getFillingCutoffOptConfig(int id) async =>
      FillingCutoffOptConfig.fromMap(
          await _getConfig('getFillingCutoffOptConfig', id));

  @override
  Future<bool> updateFillingJogConfig(int id, FillingJogConfig c) =>
      _updateConfig('updateFillingJogConfig', id, c.toMap());
  @override
  Future<FillingJogConfig> getFillingJogConfig(int id) async =>
      FillingJogConfig.fromMap(await _getConfig('getFillingJogConfig', id));

  @override
  Future<bool> updateFillingRefillConfig(int id, FillingRefillConfig c) =>
      _updateConfig('updateFillingRefillConfig', id, c.toMap());
  @override
  Future<FillingRefillConfig> getFillingRefillConfig(int id) async =>
      FillingRefillConfig.fromMap(
          await _getConfig('getFillingRefillConfig', id));

  @override
  Future<bool> updateFillingEmptyingConfig(int id, FillingEmptyingConfig c) =>
      _updateConfig('updateFillingEmptyingConfig', id, c.toMap());
  @override
  Future<FillingEmptyingConfig> getFillingEmptyingConfig(int id) async =>
      FillingEmptyingConfig.fromMap(
          await _getConfig('getFillingEmptyingConfig', id));

  @override
  Future<bool> updateFillingEventsConfig(int id, FillingEventsConfig c) =>
      _updateConfig('updateFillingEventsConfig', id, c.toMap());
  @override
  Future<FillingEventsConfig> getFillingEventsConfig(int id) async =>
      FillingEventsConfig.fromMap(
          await _getConfig('getFillingEventsConfig', id));

  @override
  Future<bool> updateFillingAdvancedConfig(int id, FillingAdvancedConfig c) =>
      _updateConfig('updateFillingAdvancedConfig', id, c.toMap());
  @override
  Future<FillingAdvancedConfig> getFillingAdvancedConfig(int id) async =>
      FillingAdvancedConfig.fromMap(
          await _getConfig('getFillingAdvancedConfig', id));

  // ============ App Control ============

  @override
  Future<bool> startApp(int subsystemId) async {
    final result = await _channel
        .invokeMethod<bool>('startApp', {'subsystemId': subsystemId});
    return result ?? false;
  }

  @override
  Future<bool> stopApp(int subsystemId) async {
    final result = await _channel
        .invokeMethod<bool>('stopApp', {'subsystemId': subsystemId});
    return result ?? false;
  }

  @override
  Future<bool> setManualControlRate(int subsystemId, double ratePct) async {
    final result = await _channel.invokeMethod<bool>('setManualControlRate', {
      'subsystemId': subsystemId,
      'ratePct': ratePct,
    });
    return result ?? false;
  }

  @override
  Future<AppStatusData> getAppStatus(int subsystemId) async {
    final result = await _channel
        .invokeMethod<Map>('getAppStatus', {'subsystemId': subsystemId});
    return AppStatusData.fromMap(Map<String, dynamic>.from(result!));
  }

  // ============ Subsystem Config ============

  @override
  Future<String> getSubsystemName(int subsystemId) async {
    final result = await _channel
        .invokeMethod<Map>('getSubsystemName', {'subsystemId': subsystemId});
    return (result?['name'] as String?) ?? '';
  }

  @override
  Future<bool> updateSubsystemName(int subsystemId, String name) async {
    final result = await _channel.invokeMethod<bool>(
        'updateSubsystemName', {'subsystemId': subsystemId, 'name': name});
    return result ?? false;
  }

  @override
  Future<DioInputConfig> getDioInputConfig(int subsystemId) async {
    final result = await _channel
        .invokeMethod<Map>('getDioInputConfig', {'subsystemId': subsystemId});
    return DioInputConfig.fromMap(Map<String, dynamic>.from(result!));
  }

  @override
  Future<bool> updateDioInputConfig(
      int subsystemId, DioInputConfig config) async {
    final args = <String, dynamic>{'subsystemId': subsystemId};
    args.addAll(config.toMap());
    final result =
        await _channel.invokeMethod<bool>('updateDioInputConfig', args);
    return result ?? false;
  }
}
