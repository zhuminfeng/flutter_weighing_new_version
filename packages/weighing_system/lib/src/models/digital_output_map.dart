enum DigitalSignalType {
  feedFast,
  feedSlow,
  refillValve,
  emptyingValve,
  alarmOut,
  runningInd,
  warningInd,
  readyInd
}

class DigitalOutputBinding {
  final int subsystemId, ioPos, channel, bitIndex, appScope;
  final DigitalSignalType signal;
  final bool activeHigh, enabled;

  const DigitalOutputBinding({
    required this.subsystemId,
    required this.ioPos,
    required this.channel,
    required this.bitIndex,
    required this.signal,
    this.activeHigh = true,
    this.enabled = true,
    this.appScope = -1,
  });

  Map<String, dynamic> toMap() => {
        'subsystem_id': subsystemId,
        'io_pos': ioPos,
        'channel': channel,
        'bit_index': bitIndex,
        'signal': signal.index,
        'active_high': activeHigh,
        'enabled': enabled,
        'app_scope': appScope,
      };

  factory DigitalOutputBinding.fromMap(Map m) => DigitalOutputBinding(
        subsystemId: m['subsystem_id'],
        ioPos: m['io_pos'],
        channel: m['channel'],
        bitIndex: m['bit_index'],
        signal: DigitalSignalType.values[m['signal']],
        activeHigh: m['active_high'] ?? true,
        enabled: m['enabled'] ?? true,
        appScope: m['app_scope'] ?? -1,
      );
}

class DigitalOutputMapConfig {
  final int version;
  final List<DigitalOutputBinding> bindings;
  const DigitalOutputMapConfig({this.version = 1, this.bindings = const []});

  Map<String, dynamic> toMap() => {
        'version': version,
        'bindings': bindings.map((e) => e.toMap()).toList(),
      };

  factory DigitalOutputMapConfig.fromMap(Map m) => DigitalOutputMapConfig(
        version: m['version'] ?? 1,
        bindings: ((m['bindings'] ?? []) as List)
            .map((e) => DigitalOutputBinding.fromMap(e))
            .toList(),
      );
}
