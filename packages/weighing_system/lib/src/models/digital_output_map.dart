enum DigitalSignalType {
  feedFast,
  feedSlow,
  refillValve,
  emptyingValve,
  alarmOut,
  runningInd,
  warningInd,
  readyInd,
  bagClamp // === 新增：夹松袋信号 ===
}

class DigitalOutputBinding {
  final int subsystemId, ioPos, bitIndex, appScope;
  final DigitalSignalType signal;
  final bool activeHigh, enabled;

  const DigitalOutputBinding({
    required this.subsystemId,
    required this.ioPos,
    required this.bitIndex,
    required this.signal,
    this.activeHigh = true,
    this.enabled = true,
    this.appScope = -1,
  });

  Map<String, dynamic> toMap() => {
        'subsystem_id': subsystemId,
        'io_pos': ioPos,
        'bit_index': bitIndex,
        'signal': signal.index,
        'active_high': activeHigh,
        'enabled': enabled,
        'app_scope': appScope,
      };

  factory DigitalOutputBinding.fromMap(Map m) => DigitalOutputBinding(
        subsystemId: m['subsystem_id'],
        ioPos: m['io_pos'],
        bitIndex: m['bit_index'],
        signal: DigitalSignalType.values[m['signal']],
        activeHigh: m['active_high'] ?? true,
        enabled: m['enabled'] ?? true,
        appScope: m['app_scope'] ?? -1,
      );
}

// === 新增：伺服电机输出绑定模型 ===
class ServoOutputBinding {
  final int subsystemId, servoPos, appScope;
  final DigitalSignalType signal;
  final bool enabled;

  const ServoOutputBinding({
    required this.subsystemId,
    required this.servoPos,
    required this.signal,
    this.enabled = true,
    this.appScope = -1,
  });

  Map<String, dynamic> toMap() => {
        'subsystem_id': subsystemId,
        'servo_pos': servoPos,
        'signal': signal.index,
        'enabled': enabled,
        'app_scope': appScope,
      };

  factory ServoOutputBinding.fromMap(Map m) => ServoOutputBinding(
        subsystemId: m['subsystem_id'] as int? ?? 0,
        servoPos: m['servo_pos'] as int? ?? 0,
        signal: DigitalSignalType.values[m['signal'] as int? ?? 0],
        enabled: m['enabled'] as bool? ?? true,
        appScope: m['app_scope'] as int? ?? -1,
      );
}

class DigitalOutputMapConfig {
  final int version;
  final List<DigitalOutputBinding> bindings;
  final List<ServoOutputBinding> servoBindings;

  const DigitalOutputMapConfig({
    this.version = 1,
    this.bindings = const [],
    this.servoBindings = const [],
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'bindings': bindings.map((b) => b.toMap()).toList(),
        'servo_bindings': servoBindings.map((b) => b.toMap()).toList(),
      };

  factory DigitalOutputMapConfig.fromMap(Map m) => DigitalOutputMapConfig(
        version: m['version'] as int? ?? 1,
        bindings: (m['bindings'] as List?)
                ?.map((e) => DigitalOutputBinding.fromMap(e as Map))
                .toList() ??
            [],
        servoBindings: (m['servo_bindings'] as List?)
                ?.map((e) => ServoOutputBinding.fromMap(e as Map))
                .toList() ??
            [],
      );
}
