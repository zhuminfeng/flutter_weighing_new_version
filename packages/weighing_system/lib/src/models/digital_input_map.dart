/// 离散输入信号类型
enum DigitalInputSignalType {
  startSignal, // 启动信号
  stopSignal, // 停止信号
  resetSignal, // 复位信号
  zeroSignal, // 清零信号
  tareSignal, // 去皮信号
  refillRequest, // 补料请求
  emergencyStop, // 紧急停止
  customKey1, // 自定义按键1
  customKey2, // 自定义按键2
  customKey3, // 自定义按键3
  customKey4, // 自定义按键4
}

class DigitalInputBinding {
  final int subsystemId;
  final int ioPos;
  final int channel;
  final int bitIndex;
  final int appScope;
  final DigitalInputSignalType signal;
  final bool activeHigh;
  final bool enabled;

  const DigitalInputBinding({
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

  factory DigitalInputBinding.fromMap(Map m) => DigitalInputBinding(
        subsystemId: m['subsystem_id'] as int? ?? 0,
        ioPos: m['io_pos'] as int? ?? 0,
        channel: m['channel'] as int? ?? 0,
        bitIndex: m['bit_index'] as int? ?? 0,
        signal: DigitalInputSignalType
            .values[(m['signal'] as int?) ?? 0],
        activeHigh: m['active_high'] as bool? ?? true,
        enabled: m['enabled'] as bool? ?? true,
        appScope: m['app_scope'] as int? ?? -1,
      );

  DigitalInputBinding copyWith({
    int? ioPos,
    int? channel,
    int? bitIndex,
    DigitalInputSignalType? signal,
    bool? activeHigh,
    bool? enabled,
    int? appScope,
  }) =>
      DigitalInputBinding(
        subsystemId: subsystemId,
        ioPos: ioPos ?? this.ioPos,
        channel: channel ?? this.channel,
        bitIndex: bitIndex ?? this.bitIndex,
        signal: signal ?? this.signal,
        activeHigh: activeHigh ?? this.activeHigh,
        enabled: enabled ?? this.enabled,
        appScope: appScope ?? this.appScope,
      );
}

class DigitalInputMapConfig {
  final int version;
  final List<DigitalInputBinding> bindings;

  const DigitalInputMapConfig({
    this.version = 1,
    this.bindings = const [],
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'bindings': bindings.map((b) => b.toMap()).toList(),
      };

  factory DigitalInputMapConfig.fromMap(Map m) => DigitalInputMapConfig(
        version: m['version'] as int? ?? 1,
        bindings: (m['bindings'] as List?)
                ?.map((e) => DigitalInputBinding.fromMap(e as Map))
                .toList() ??
            [],
      );
}
