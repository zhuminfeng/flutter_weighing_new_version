class CalibrationConfig {
  final int calUnit; // 0=g, 1=kg, 2=lb, 3=t, 4=ton
  final int linearMode; // 0=disabled, 1=3pt, 2=4pt, 3=5pt

  const CalibrationConfig({this.calUnit = 1, this.linearMode = 0});

  Map<String, dynamic> toMap() =>
      {'calUnit': calUnit, 'linearMode': linearMode};

  factory CalibrationConfig.fromMap(Map<String, dynamic> m) =>
      CalibrationConfig(
        calUnit: m['calUnit'] ?? 1,
        linearMode: m['linearMode'] ?? 0,
      );
}
