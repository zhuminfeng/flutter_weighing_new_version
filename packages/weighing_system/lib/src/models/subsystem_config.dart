/// 子系统离散输入自定义映射配置
///
/// 每个字段代表对应逻辑功能所绑定的硬件位索引（0–15）。
/// 值为 -1 表示该功能未映射到任何硬件输入。
class DioInputConfig {
  final int start;
  final int stop;
  final int executeRefill;
  final int triggerEmptying;
  final int interlock;
  final int tare;
  final int zero;
  final int jogTrigger;

  const DioInputConfig({
    this.start = 0,
    this.stop = 1,
    this.executeRefill = 2,
    this.triggerEmptying = 3,
    this.interlock = 4,
    this.tare = 5,
    this.zero = 6,
    this.jogTrigger = 7,
  });

  /// Returns a copy of this config with the specified fields replaced.
  DioInputConfig copyWith({
    int? start,
    int? stop,
    int? executeRefill,
    int? triggerEmptying,
    int? interlock,
    int? tare,
    int? zero,
    int? jogTrigger,
  }) =>
      DioInputConfig(
        start: start ?? this.start,
        stop: stop ?? this.stop,
        executeRefill: executeRefill ?? this.executeRefill,
        triggerEmptying: triggerEmptying ?? this.triggerEmptying,
        interlock: interlock ?? this.interlock,
        tare: tare ?? this.tare,
        zero: zero ?? this.zero,
        jogTrigger: jogTrigger ?? this.jogTrigger,
      );

  Map<String, dynamic> toMap() => {
        'start': start,
        'stop': stop,
        'executeRefill': executeRefill,
        'triggerEmptying': triggerEmptying,
        'interlock': interlock,
        'tare': tare,
        'zero': zero,
        'jogTrigger': jogTrigger,
      };

  factory DioInputConfig.fromMap(Map<String, dynamic> m) => DioInputConfig(
        start: m['start'] ?? 0,
        stop: m['stop'] ?? 1,
        executeRefill: m['executeRefill'] ?? 2,
        triggerEmptying: m['triggerEmptying'] ?? 3,
        interlock: m['interlock'] ?? 4,
        tare: m['tare'] ?? 5,
        zero: m['zero'] ?? 6,
        jogTrigger: m['jogTrigger'] ?? 7,
      );
}

/// 子系统离散输出自定义映射配置
///
/// 每个字段代表对应逻辑输出功能所绑定的硬件位索引（0–15）。
/// 值为 -1 表示该功能未映射到任何硬件输出。
class DioOutputConfig {
  // 状态指示输出
  final int alarm;
  final int running;
  final int warning;
  // 阀门控制输出 – 通道 0
  final int feedFast0;
  final int feedSlow0;
  final int refillValve0;
  final int emptyingValve0;
  // 阀门控制输出 – 通道 1
  final int feedFast1;
  final int feedSlow1;
  final int refillValve1;
  final int emptyingValve1;

  const DioOutputConfig({
    this.alarm = 8,
    this.running = 9,
    this.warning = 11,
    this.feedFast0 = 0,
    this.feedSlow0 = 1,
    this.refillValve0 = 2,
    this.emptyingValve0 = 3,
    this.feedFast1 = 4,
    this.feedSlow1 = 5,
    this.refillValve1 = 6,
    this.emptyingValve1 = 7,
  });

  /// Returns a copy of this config with the specified fields replaced.
  DioOutputConfig copyWith({
    int? alarm,
    int? running,
    int? warning,
    int? feedFast0,
    int? feedSlow0,
    int? refillValve0,
    int? emptyingValve0,
    int? feedFast1,
    int? feedSlow1,
    int? refillValve1,
    int? emptyingValve1,
  }) =>
      DioOutputConfig(
        alarm: alarm ?? this.alarm,
        running: running ?? this.running,
        warning: warning ?? this.warning,
        feedFast0: feedFast0 ?? this.feedFast0,
        feedSlow0: feedSlow0 ?? this.feedSlow0,
        refillValve0: refillValve0 ?? this.refillValve0,
        emptyingValve0: emptyingValve0 ?? this.emptyingValve0,
        feedFast1: feedFast1 ?? this.feedFast1,
        feedSlow1: feedSlow1 ?? this.feedSlow1,
        refillValve1: refillValve1 ?? this.refillValve1,
        emptyingValve1: emptyingValve1 ?? this.emptyingValve1,
      );

  Map<String, dynamic> toMap() => {
        'alarm': alarm,
        'running': running,
        'warning': warning,
        'feedFast0': feedFast0,
        'feedSlow0': feedSlow0,
        'refillValve0': refillValve0,
        'emptyingValve0': emptyingValve0,
        'feedFast1': feedFast1,
        'feedSlow1': feedSlow1,
        'refillValve1': refillValve1,
        'emptyingValve1': emptyingValve1,
      };

  factory DioOutputConfig.fromMap(Map<String, dynamic> m) => DioOutputConfig(
        alarm: m['alarm'] ?? 8,
        running: m['running'] ?? 9,
        warning: m['warning'] ?? 11,
        feedFast0: m['feedFast0'] ?? 0,
        feedSlow0: m['feedSlow0'] ?? 1,
        refillValve0: m['refillValve0'] ?? 2,
        emptyingValve0: m['emptyingValve0'] ?? 3,
        feedFast1: m['feedFast1'] ?? 4,
        feedSlow1: m['feedSlow1'] ?? 5,
        refillValve1: m['refillValve1'] ?? 6,
        emptyingValve1: m['emptyingValve1'] ?? 7,
      );
}
