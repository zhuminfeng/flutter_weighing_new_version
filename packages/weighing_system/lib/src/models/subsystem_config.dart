/// 子系统离散输入自定义映射配置
/// 每个字段代表对应逻辑功能所在的硬件位索引（0-15），-1 表示未映射
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
