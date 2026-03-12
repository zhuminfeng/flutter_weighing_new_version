class ScaleParams {
  final int primaryUnit; // 0=g, 1=kg, 2=lb, 3=t, 4=ton
  final double capacity;
  final double division;
  final int overloadRange;

  const ScaleParams({
    this.primaryUnit = 1,
    this.capacity = 15.0,
    this.division = 0.005,
    this.overloadRange = 9,
  });

  int get maxDivisions => division > 0 ? (capacity / division).round() : 0;

  Map<String, dynamic> toMap() => {
        'primaryUnit': primaryUnit,
        'capacity': capacity,
        'division': division,
        'overloadRange': overloadRange,
      };

  factory ScaleParams.fromMap(Map<String, dynamic> map) => ScaleParams(
        primaryUnit: map['primaryUnit'] ?? 1,
        capacity: (map['capacity'] ?? 15.0).toDouble(),
        division: (map['division'] ?? 0.005).toDouble(),
        overloadRange: map['overloadRange'] ?? 9,
      );

  ScaleParams copyWith(
          {int? primaryUnit,
          double? capacity,
          double? division,
          int? overloadRange}) =>
      ScaleParams(
        primaryUnit: primaryUnit ?? this.primaryUnit,
        capacity: capacity ?? this.capacity,
        division: division ?? this.division,
        overloadRange: overloadRange ?? this.overloadRange,
      );
}
