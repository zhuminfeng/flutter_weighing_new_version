class ZeroConfig {
  final int autoZeroMode; // 0=off, 1=gross, 2=gross+net
  final double autoZeroRangeD;
  final double underloadRangeD;
  final int powerUpZero; // 0=last, 1=calibrated, 2=new
  final double powerUpZeroPosPct;
  final double powerUpZeroNegPct;
  final bool pushbuttonZeroEnabled;
  final double pushbuttonZeroPosPct;
  final double pushbuttonZeroNegPct;

  const ZeroConfig({
    this.autoZeroMode = 1,
    this.autoZeroRangeD = 0.5,
    this.underloadRangeD = 20.0,
    this.powerUpZero = 1,
    this.powerUpZeroPosPct = 2.0,
    this.powerUpZeroNegPct = 2.0,
    this.pushbuttonZeroEnabled = true,
    this.pushbuttonZeroPosPct = 2.0,
    this.pushbuttonZeroNegPct = 2.0,
  });

  Map<String, dynamic> toMap() => {
        'autoZeroMode': autoZeroMode,
        'autoZeroRangeD': autoZeroRangeD,
        'underloadRangeD': underloadRangeD,
        'powerUpZero': powerUpZero,
        'powerUpZeroPosPct': powerUpZeroPosPct,
        'powerUpZeroNegPct': powerUpZeroNegPct,
        'pushbuttonZeroEnabled': pushbuttonZeroEnabled,
        'pushbuttonZeroPosPct': pushbuttonZeroPosPct,
        'pushbuttonZeroNegPct': pushbuttonZeroNegPct,
      };

  factory ZeroConfig.fromMap(Map<String, dynamic> m) => ZeroConfig(
        autoZeroMode: m['autoZeroMode'] ?? 1,
        autoZeroRangeD: (m['autoZeroRangeD'] ?? 0.5).toDouble(),
        underloadRangeD: (m['underloadRangeD'] ?? 20.0).toDouble(),
        powerUpZero: m['powerUpZero'] ?? 1,
        powerUpZeroPosPct: (m['powerUpZeroPosPct'] ?? 2.0).toDouble(),
        powerUpZeroNegPct: (m['powerUpZeroNegPct'] ?? 2.0).toDouble(),
        pushbuttonZeroEnabled: m['pushbuttonZeroEnabled'] ?? true,
        pushbuttonZeroPosPct: (m['pushbuttonZeroPosPct'] ?? 2.0).toDouble(),
        pushbuttonZeroNegPct: (m['pushbuttonZeroNegPct'] ?? 2.0).toDouble(),
      );
}
