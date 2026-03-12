class FillingGeneralConfig {
  final int powerFailRecovery; // 0=idle, 1=pause
  final int startDelay; // 0=disabled, 1=5min, 2=15min, 3=30min
  const FillingGeneralConfig({this.powerFailRecovery = 0, this.startDelay = 0});
  Map<String, dynamic> toMap() =>
      {'powerFailRecovery': powerFailRecovery, 'startDelay': startDelay};
  factory FillingGeneralConfig.fromMap(Map<String, dynamic> m) =>
      FillingGeneralConfig(
          powerFailRecovery: m['powerFailRecovery'] ?? 0,
          startDelay: m['startDelay'] ?? 0);
}

class FillingSystemConfig {
  final int
      workMode; // 0=fill, 1=fill/empty, 2=dispense, 3=refill/dispense, 4=absolute
  final int feedSpeed; // 0=single, 1=dual
  const FillingSystemConfig({this.workMode = 0, this.feedSpeed = 1});
  Map<String, dynamic> toMap() =>
      {'workMode': workMode, 'feedSpeed': feedSpeed};
  factory FillingSystemConfig.fromMap(Map<String, dynamic> m) =>
      FillingSystemConfig(
          workMode: m['workMode'] ?? 0, feedSpeed: m['feedSpeed'] ?? 1);
}

class FillingTargetConfig {
  final double targetValue,
      inFlight,
      feed,
      feedInhibitTime,
      fastFeedInhibitTime;
  const FillingTargetConfig(
      {this.targetValue = 1,
      this.inFlight = 0,
      this.feed = 0,
      this.feedInhibitTime = 0,
      this.fastFeedInhibitTime = 0});
  Map<String, dynamic> toMap() => {
        'targetValue': targetValue,
        'inFlight': inFlight,
        'feed': feed,
        'feedInhibitTime': feedInhibitTime,
        'fastFeedInhibitTime': fastFeedInhibitTime
      };
  factory FillingTargetConfig.fromMap(Map<String, dynamic> m) =>
      FillingTargetConfig(
          targetValue: (m['targetValue'] ?? 1).toDouble(),
          inFlight: (m['inFlight'] ?? 0).toDouble(),
          feed: (m['feed'] ?? 0).toDouble(),
          feedInhibitTime: (m['feedInhibitTime'] ?? 0).toDouble(),
          fastFeedInhibitTime: (m['fastFeedInhibitTime'] ?? 0).toDouble());
}

class FillingAutoTareConfig {
  final bool autoTareEnabled;
  final double containerTareUpper, containerTareLower;
  const FillingAutoTareConfig(
      {this.autoTareEnabled = false,
      this.containerTareUpper = 0,
      this.containerTareLower = 0});
  Map<String, dynamic> toMap() => {
        'autoTareEnabled': autoTareEnabled,
        'containerTareUpper': containerTareUpper,
        'containerTareLower': containerTareLower
      };
  factory FillingAutoTareConfig.fromMap(Map<String, dynamic> m) =>
      FillingAutoTareConfig(
          autoTareEnabled: m['autoTareEnabled'] ?? false,
          containerTareUpper: (m['containerTareUpper'] ?? 0).toDouble(),
          containerTareLower: (m['containerTareLower'] ?? 0).toDouble());
}

class FillingToleranceConfig {
  final double preCheckDelay,
      stabilityTimeout,
      positiveTolerance,
      negativeTolerance;
  const FillingToleranceConfig(
      {this.preCheckDelay = 0,
      this.stabilityTimeout = 0,
      this.positiveTolerance = 0,
      this.negativeTolerance = 0});
  Map<String, dynamic> toMap() => {
        'preCheckDelay': preCheckDelay,
        'stabilityTimeout': stabilityTimeout,
        'positiveTolerance': positiveTolerance,
        'negativeTolerance': negativeTolerance
      };
  factory FillingToleranceConfig.fromMap(Map<String, dynamic> m) =>
      FillingToleranceConfig(
          preCheckDelay: (m['preCheckDelay'] ?? 0).toDouble(),
          stabilityTimeout: (m['stabilityTimeout'] ?? 0).toDouble(),
          positiveTolerance: (m['positiveTolerance'] ?? 0).toDouble(),
          negativeTolerance: (m['negativeTolerance'] ?? 0).toDouble());
}

class FillingSpillOptConfig {
  final int mode; // 0=disabled, 1=auto, 2=manual
  final double adjustRange, adjustFactor;
  final int adjustSamples;
  const FillingSpillOptConfig(
      {this.mode = 0,
      this.adjustRange = 0,
      this.adjustSamples = 5,
      this.adjustFactor = 0.5});
  Map<String, dynamic> toMap() => {
        'mode': mode,
        'adjustRange': adjustRange,
        'adjustSamples': adjustSamples,
        'adjustFactor': adjustFactor
      };
  factory FillingSpillOptConfig.fromMap(Map<String, dynamic> m) =>
      FillingSpillOptConfig(
          mode: m['mode'] ?? 0,
          adjustRange: (m['adjustRange'] ?? 0).toDouble(),
          adjustSamples: m['adjustSamples'] ?? 5,
          adjustFactor: (m['adjustFactor'] ?? 0.5).toDouble());
}

class FillingCutoffOptConfig {
  final int mode;
  final double controlReliabilityRange, adjustFactor;
  final int adjustCycles;
  const FillingCutoffOptConfig(
      {this.mode = 0,
      this.controlReliabilityRange = 0,
      this.adjustCycles = 5,
      this.adjustFactor = 0.5});
  Map<String, dynamic> toMap() => {
        'mode': mode,
        'controlReliabilityRange': controlReliabilityRange,
        'adjustCycles': adjustCycles,
        'adjustFactor': adjustFactor
      };
  factory FillingCutoffOptConfig.fromMap(Map<String, dynamic> m) =>
      FillingCutoffOptConfig(
          mode: m['mode'] ?? 0,
          controlReliabilityRange:
              (m['controlReliabilityRange'] ?? 0).toDouble(),
          adjustCycles: m['adjustCycles'] ?? 5,
          adjustFactor: (m['adjustFactor'] ?? 0.5).toDouble());
}

class FillingJogConfig {
  final int mode; // 0=disabled, 1=auto, 2=single pulse, 3=manual
  final double jogDuration, jogPauseTime;
  final int maxCycles;
  const FillingJogConfig(
      {this.mode = 0,
      this.jogDuration = 0.5,
      this.jogPauseTime = 1,
      this.maxCycles = 3});
  Map<String, dynamic> toMap() => {
        'mode': mode,
        'jogDuration': jogDuration,
        'jogPauseTime': jogPauseTime,
        'maxCycles': maxCycles
      };
  factory FillingJogConfig.fromMap(Map<String, dynamic> m) => FillingJogConfig(
      mode: m['mode'] ?? 0,
      jogDuration: (m['jogDuration'] ?? 0.5).toDouble(),
      jogPauseTime: (m['jogPauseTime'] ?? 1).toDouble(),
      maxCycles: m['maxCycles'] ?? 3);
}

class FillingRefillConfig {
  final double upperLimit, lowerLimit;
  const FillingRefillConfig({this.upperLimit = 10, this.lowerLimit = 1});
  Map<String, dynamic> toMap() =>
      {'upperLimit': upperLimit, 'lowerLimit': lowerLimit};
  factory FillingRefillConfig.fromMap(Map<String, dynamic> m) =>
      FillingRefillConfig(
          upperLimit: (m['upperLimit'] ?? 10).toDouble(),
          lowerLimit: (m['lowerLimit'] ?? 1).toDouble());
}

class FillingEmptyingConfig {
  final int completeMode; // 0=residual weight, 1=time
  final double residualWeight, completionTime;
  const FillingEmptyingConfig(
      {this.completeMode = 0,
      this.residualWeight = 0.1,
      this.completionTime = 5});
  Map<String, dynamic> toMap() => {
        'completeMode': completeMode,
        'residualWeight': residualWeight,
        'completionTime': completionTime
      };
  factory FillingEmptyingConfig.fromMap(Map<String, dynamic> m) =>
      FillingEmptyingConfig(
          completeMode: m['completeMode'] ?? 0,
          residualWeight: (m['residualWeight'] ?? 0.1).toDouble(),
          completionTime: (m['completionTime'] ?? 5).toDouble());
}

class FillingEventsConfig {
  final double initialFeedTimeout,
      emptyingTimeout,
      refillTimeout,
      processTimeout;
  const FillingEventsConfig(
      {this.initialFeedTimeout = 30,
      this.emptyingTimeout = 60,
      this.refillTimeout = 60,
      this.processTimeout = 120});
  Map<String, dynamic> toMap() => {
        'initialFeedTimeout': initialFeedTimeout,
        'emptyingTimeout': emptyingTimeout,
        'refillTimeout': refillTimeout,
        'processTimeout': processTimeout
      };
  factory FillingEventsConfig.fromMap(Map<String, dynamic> m) =>
      FillingEventsConfig(
          initialFeedTimeout: (m['initialFeedTimeout'] ?? 30).toDouble(),
          emptyingTimeout: (m['emptyingTimeout'] ?? 60).toDouble(),
          refillTimeout: (m['refillTimeout'] ?? 60).toDouble(),
          processTimeout: (m['processTimeout'] ?? 120).toDouble());
}

class FillingAdvancedConfig {
  final int cycleConfirm; // 0=disabled, 1=every, 2=out of tolerance
  final int fastRecovery; // 0=auto, 1=static, 2=disabled
  final bool interlockEnabled;
  final double fastFeedSpeed, fineFeedSpeed;
  const FillingAdvancedConfig(
      {this.cycleConfirm = 0,
      this.fastRecovery = 0,
      this.interlockEnabled = false,
      this.fastFeedSpeed = 100,
      this.fineFeedSpeed = 30});
  Map<String, dynamic> toMap() => {
        'cycleConfirm': cycleConfirm,
        'fastRecovery': fastRecovery,
        'interlockEnabled': interlockEnabled,
        'fastFeedSpeed': fastFeedSpeed,
        'fineFeedSpeed': fineFeedSpeed
      };
  factory FillingAdvancedConfig.fromMap(Map<String, dynamic> m) =>
      FillingAdvancedConfig(
          cycleConfirm: m['cycleConfirm'] ?? 0,
          fastRecovery: m['fastRecovery'] ?? 0,
          interlockEnabled: m['interlockEnabled'] ?? false,
          fastFeedSpeed: (m['fastFeedSpeed'] ?? 100).toDouble(),
          fineFeedSpeed: (m['fineFeedSpeed'] ?? 30).toDouble());
}
