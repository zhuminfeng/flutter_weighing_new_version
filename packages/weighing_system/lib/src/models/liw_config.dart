// All LIW sub-configs as Dart models

class LiwBaseConfig {
  final int mode; // 0=continuous, 1=batch, 2=sysid
  final int subMode; // 0=flow control, 1=fixed freq
  const LiwBaseConfig({this.mode = 0, this.subMode = 0});
  Map<String, dynamic> toMap() => {'mode': mode, 'subMode': subMode};
  factory LiwBaseConfig.fromMap(Map<String, dynamic> m) =>
      LiwBaseConfig(mode: m['mode'] ?? 0, subMode: m['subMode'] ?? 0);
}

class LiwSystemConfig {
  final double safetyLimit, hopperMin, hopperMax, targetFlow, targetControlRate;
  final bool preRefill;
  const LiwSystemConfig(
      {this.safetyLimit = 100,
      this.hopperMin = 0,
      this.hopperMax = 15,
      this.targetFlow = 10,
      this.targetControlRate = 10,
      this.preRefill = false});
  Map<String, dynamic> toMap() => {
        'safetyLimit': safetyLimit,
        'hopperMin': hopperMin,
        'hopperMax': hopperMax,
        'targetFlow': targetFlow,
        'targetControlRate': targetControlRate,
        'preRefill': preRefill
      };
  factory LiwSystemConfig.fromMap(Map<String, dynamic> m) => LiwSystemConfig(
      safetyLimit: (m['safetyLimit'] ?? 100).toDouble(),
      hopperMin: (m['hopperMin'] ?? 0).toDouble(),
      hopperMax: (m['hopperMax'] ?? 15).toDouble(),
      targetFlow: (m['targetFlow'] ?? 10).toDouble(),
      targetControlRate: (m['targetControlRate'] ?? 10).toDouble(),
      preRefill: m['preRefill'] ?? false);
}

class LiwSystemIdConfig {
  final double adjustRangeLower, adjustRangeUpper, stepDuration, filterWindow;
  final bool smartStepControl;
  const LiwSystemIdConfig(
      {this.adjustRangeLower = 0,
      this.adjustRangeUpper = 90,
      this.smartStepControl = false,
      this.stepDuration = 10,
      this.filterWindow = 0.5});
  Map<String, dynamic> toMap() => {
        'adjustRangeLower': adjustRangeLower,
        'adjustRangeUpper': adjustRangeUpper,
        'smartStepControl': smartStepControl,
        'stepDuration': stepDuration,
        'filterWindow': filterWindow
      };
  factory LiwSystemIdConfig.fromMap(Map<String, dynamic> m) =>
      LiwSystemIdConfig(
          adjustRangeLower: (m['adjustRangeLower'] ?? 0).toDouble(),
          adjustRangeUpper: (m['adjustRangeUpper'] ?? 90).toDouble(),
          smartStepControl: m['smartStepControl'] ?? false,
          stepDuration: (m['stepDuration'] ?? 10).toDouble(),
          filterWindow: (m['filterWindow'] ?? 0.5).toDouble());
}

class LiwControllerConfig {
  final int tuningMode; // 0=auto, 1=manual
  final double filterWindow, kp, ki, kd, maxFlow, startupTime;
  const LiwControllerConfig(
      {this.tuningMode = 1,
      this.filterWindow = 0.5,
      this.kp = 1,
      this.ki = 1,
      this.kd = 0,
      this.maxFlow = 100,
      this.startupTime = 0});
  Map<String, dynamic> toMap() => {
        'tuningMode': tuningMode,
        'filterWindow': filterWindow,
        'kp': kp,
        'ki': ki,
        'kd': kd,
        'maxFlow': maxFlow,
        'startupTime': startupTime
      };
  factory LiwControllerConfig.fromMap(Map<String, dynamic> m) =>
      LiwControllerConfig(
          tuningMode: m['tuningMode'] ?? 1,
          filterWindow: (m['filterWindow'] ?? 0.5).toDouble(),
          kp: (m['kp'] ?? 1).toDouble(),
          ki: (m['ki'] ?? 1).toDouble(),
          kd: (m['kd'] ?? 0).toDouble(),
          maxFlow: (m['maxFlow'] ?? 100).toDouble(),
          startupTime: (m['startupTime'] ?? 0).toDouble());
}

class LiwRefillConfig {
  final int mode; // 0=auto, 1=manual
  final double lowerLimit, upperLimit, controlSetpoint, stabilizeTime;
  final int controlMode; // 0=fixed, 1=last freq, 2=smart
  const LiwRefillConfig(
      {this.mode = 0,
      this.lowerLimit = 1,
      this.upperLimit = 10,
      this.controlMode = 1,
      this.controlSetpoint = 10,
      this.stabilizeTime = 10});
  Map<String, dynamic> toMap() => {
        'mode': mode,
        'lowerLimit': lowerLimit,
        'upperLimit': upperLimit,
        'controlMode': controlMode,
        'controlSetpoint': controlSetpoint,
        'stabilizeTime': stabilizeTime
      };
  factory LiwRefillConfig.fromMap(Map<String, dynamic> m) => LiwRefillConfig(
      mode: m['mode'] ?? 0,
      lowerLimit: (m['lowerLimit'] ?? 1).toDouble(),
      upperLimit: (m['upperLimit'] ?? 10).toDouble(),
      controlMode: m['controlMode'] ?? 1,
      controlSetpoint: (m['controlSetpoint'] ?? 10).toDouble(),
      stabilizeTime: (m['stabilizeTime'] ?? 10).toDouble());
}

class LiwTargetValuesConfig {
  final double batchTarget, inFlight, fineFeedThreshold, fineFeedFlow;
  const LiwTargetValuesConfig(
      {this.batchTarget = 1,
      this.inFlight = 0,
      this.fineFeedThreshold = 0,
      this.fineFeedFlow = 2});
  Map<String, dynamic> toMap() => {
        'batchTarget': batchTarget,
        'inFlight': inFlight,
        'fineFeedThreshold': fineFeedThreshold,
        'fineFeedFlow': fineFeedFlow
      };
  factory LiwTargetValuesConfig.fromMap(Map<String, dynamic> m) =>
      LiwTargetValuesConfig(
          batchTarget: (m['batchTarget'] ?? 1).toDouble(),
          inFlight: (m['inFlight'] ?? 0).toDouble(),
          fineFeedThreshold: (m['fineFeedThreshold'] ?? 0).toDouble(),
          fineFeedFlow: (m['fineFeedFlow'] ?? 2).toDouble());
}

class LiwToleranceCheckConfig {
  final double preCheckDelay, stabilityTimeout, tolerance;
  const LiwToleranceCheckConfig(
      {this.preCheckDelay = 0, this.stabilityTimeout = 0, this.tolerance = 0});
  Map<String, dynamic> toMap() => {
        'preCheckDelay': preCheckDelay,
        'stabilityTimeout': stabilityTimeout,
        'tolerance': tolerance
      };
  factory LiwToleranceCheckConfig.fromMap(Map<String, dynamic> m) =>
      LiwToleranceCheckConfig(
          preCheckDelay: (m['preCheckDelay'] ?? 0).toDouble(),
          stabilityTimeout: (m['stabilityTimeout'] ?? 0).toDouble(),
          tolerance: (m['tolerance'] ?? 0).toDouble());
}

class LiwEmptyingConfig {
  final bool autoStopAtAlarm;
  final double controlSetpoint;
  const LiwEmptyingConfig(
      {this.autoStopAtAlarm = true, this.controlSetpoint = 10});
  Map<String, dynamic> toMap() =>
      {'autoStopAtAlarm': autoStopAtAlarm, 'controlSetpoint': controlSetpoint};
  factory LiwEmptyingConfig.fromMap(Map<String, dynamic> m) =>
      LiwEmptyingConfig(
          autoStopAtAlarm: m['autoStopAtAlarm'] ?? true,
          controlSetpoint: (m['controlSetpoint'] ?? 10).toDouble());
}

class LiwWarningConfig {
  final double controlRateLower, controlRateUpper, refillTimeout;
  final bool stopOnError;
  const LiwWarningConfig(
      {this.controlRateLower = 20,
      this.controlRateUpper = 80,
      this.refillTimeout = 10,
      this.stopOnError = false});
  Map<String, dynamic> toMap() => {
        'controlRateLower': controlRateLower,
        'controlRateUpper': controlRateUpper,
        'refillTimeout': refillTimeout,
        'stopOnError': stopOnError
      };
  factory LiwWarningConfig.fromMap(Map<String, dynamic> m) => LiwWarningConfig(
      controlRateLower: (m['controlRateLower'] ?? 20).toDouble(),
      controlRateUpper: (m['controlRateUpper'] ?? 80).toDouble(),
      refillTimeout: (m['refillTimeout'] ?? 10).toDouble(),
      stopOnError: m['stopOnError'] ?? false);
}

class LiwFlowMonitorConfig {
  final double evaluationWindow, deviationThreshold, surgeThreshold;
  const LiwFlowMonitorConfig(
      {this.evaluationWindow = 3,
      this.deviationThreshold = 10,
      this.surgeThreshold = 150});
  Map<String, dynamic> toMap() => {
        'evaluationWindow': evaluationWindow,
        'deviationThreshold': deviationThreshold,
        'surgeThreshold': surgeThreshold
      };
  factory LiwFlowMonitorConfig.fromMap(Map<String, dynamic> m) =>
      LiwFlowMonitorConfig(
          evaluationWindow: (m['evaluationWindow'] ?? 3).toDouble(),
          deviationThreshold: (m['deviationThreshold'] ?? 10).toDouble(),
          surgeThreshold: (m['surgeThreshold'] ?? 150).toDouble());
}

class LiwAdvancedConfig {
  final bool interlockEnabled;
  final double interlockDelay;
  const LiwAdvancedConfig(
      {this.interlockEnabled = false, this.interlockDelay = 0});
  Map<String, dynamic> toMap() =>
      {'interlockEnabled': interlockEnabled, 'interlockDelay': interlockDelay};
  factory LiwAdvancedConfig.fromMap(Map<String, dynamic> m) =>
      LiwAdvancedConfig(
          interlockEnabled: m['interlockEnabled'] ?? false,
          interlockDelay: (m['interlockDelay'] ?? 0).toDouble());
}

class LiwStatsConfig {
  final double samplePeriod, sampleTolerance;
  const LiwStatsConfig({this.samplePeriod = 60, this.sampleTolerance = 10});
  Map<String, dynamic> toMap() =>
      {'samplePeriod': samplePeriod, 'sampleTolerance': sampleTolerance};
  factory LiwStatsConfig.fromMap(Map<String, dynamic> m) => LiwStatsConfig(
      samplePeriod: (m['samplePeriod'] ?? 60).toDouble(),
      sampleTolerance: (m['sampleTolerance'] ?? 10).toDouble());
}
