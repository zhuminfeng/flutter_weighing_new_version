class FilterStabilityConfig {
  final int lowPassLevel; // 0=very light, 1=light, 2=medium, 3=heavy
  final bool notchEnabled;
  final double notchFrequency;
  final bool adaptiveEnabled;
  final double adaptiveRangeD;
  final double motionRangeD;
  final double motionDetectTime;
  final double stabilityTimeout;

  const FilterStabilityConfig({
    this.lowPassLevel = 0,
    this.notchEnabled = false,
    this.notchFrequency = 50.0,
    this.adaptiveEnabled = false,
    this.adaptiveRangeD = 1.0,
    this.motionRangeD = 1.0,
    this.motionDetectTime = 0.3,
    this.stabilityTimeout = 3.0,
  });

  Map<String, dynamic> toMap() => {
        'lowPassLevel': lowPassLevel,
        'notchEnabled': notchEnabled,
        'notchFrequency': notchFrequency,
        'adaptiveEnabled': adaptiveEnabled,
        'adaptiveRangeD': adaptiveRangeD,
        'motionRangeD': motionRangeD,
        'motionDetectTime': motionDetectTime,
        'stabilityTimeout': stabilityTimeout,
      };

  factory FilterStabilityConfig.fromMap(Map<String, dynamic> m) =>
      FilterStabilityConfig(
        lowPassLevel: m['lowPassLevel'] ?? 0,
        notchEnabled: m['notchEnabled'] ?? false,
        notchFrequency: (m['notchFrequency'] ?? 50.0).toDouble(),
        adaptiveEnabled: m['adaptiveEnabled'] ?? false,
        adaptiveRangeD: (m['adaptiveRangeD'] ?? 1.0).toDouble(),
        motionRangeD: (m['motionRangeD'] ?? 1.0).toDouble(),
        motionDetectTime: (m['motionDetectTime'] ?? 0.3).toDouble(),
        stabilityTimeout: (m['stabilityTimeout'] ?? 3.0).toDouble(),
      );
}
