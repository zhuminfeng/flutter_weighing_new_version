enum WeightUnit { gram, kilogram, pound, metricTon, ton }

enum MotionState { stable, inMotion }

class WeightData {
  final int scaleId;
  final double grossWeight;
  final double netWeight;
  final double tareWeight;
  final bool isStable;
  final bool isZero;
  final bool isOverload;
  final bool isUnderload;
  final bool isNetMode;
  final WeightUnit unit;
  final int timestampNs;

  const WeightData({
    this.scaleId = 0,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.tareWeight = 0.0,
    this.isStable = false,
    this.isZero = false,
    this.isOverload = false,
    this.isUnderload = false,
    this.isNetMode = false,
    this.unit = WeightUnit.kilogram,
    this.timestampNs = 0,
  });

  factory WeightData.fromMap(Map<String, dynamic> map) {
    return WeightData(
      scaleId: map['scaleId'] ?? 0,
      grossWeight: (map['grossWeight'] ?? 0.0).toDouble(),
      netWeight: (map['netWeight'] ?? 0.0).toDouble(),
      tareWeight: (map['tareWeight'] ?? 0.0).toDouble(),
      isStable: map['isStable'] ?? false,
      isZero: map['isZero'] ?? false,
      isOverload: map['isOverload'] ?? false,
      isUnderload: map['isUnderload'] ?? false,
      isNetMode: map['isNetMode'] ?? false,
      unit: WeightUnit.values[map['unit'] ?? 1],
      timestampNs: map['timestampNs'] ?? 0,
    );
  }

  /// Get display weight (net if tared, gross otherwise)
  double get displayWeight => isNetMode ? netWeight : grossWeight;

  /// Format weight with appropriate precision
  String formatWeight(double division) {
    if (isOverload) return 'OL';
    if (isUnderload) return 'UL';
    int decimals = 0;
    if (division < 1) {
      String divStr = division.toString();
      int dotIdx = divStr.indexOf('.');
      if (dotIdx >= 0) decimals = divStr.length - dotIdx - 1;
    }
    return displayWeight.toStringAsFixed(decimals);
  }

  String get unitString {
    switch (unit) {
      case WeightUnit.gram:
        return 'g';
      case WeightUnit.kilogram:
        return 'kg';
      case WeightUnit.pound:
        return 'lb';
      case WeightUnit.metricTon:
        return 't';
      case WeightUnit.ton:
        return 'ton';
    }
  }
}
