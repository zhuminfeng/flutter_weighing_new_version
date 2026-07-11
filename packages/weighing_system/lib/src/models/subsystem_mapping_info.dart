class SubsystemMappingInfo {
  final int subsystemId;
  final int scaleId;
  final int ioPosition;
  final String description;
  final int appType;
  final bool enabled;
  final String activeRecipe;

  const SubsystemMappingInfo({
    required this.subsystemId,
    required this.scaleId,
    required this.ioPosition,
    required this.description,
    this.appType = 0,
    this.enabled = true,
    this.activeRecipe = "",
  });

  factory SubsystemMappingInfo.fromMap(Map<String, dynamic> m) {
    return SubsystemMappingInfo(
      subsystemId: (m['subsystemId'] as num?)?.toInt() ?? 0,
      scaleId: (m['scaleId'] as num?)?.toInt() ?? 0,
      ioPosition: (m['ioPosition'] as num?)?.toInt() ?? 0,
      description: m['description'] as String? ?? '',
      appType: (m['appType'] as num?)?.toInt() ?? 0,
      enabled: m['enabled'] as bool? ?? true,
      activeRecipe: m['active_recipe'] as String? ?? '',
    );
  }

  SubsystemMappingInfo copyWith({
    int? scaleId,
    int? appType,
    bool? enabled,
    String? description,
    String? activeRecipe,
  }) {
    return SubsystemMappingInfo(
      subsystemId: subsystemId,
      scaleId: scaleId ?? this.scaleId,
      ioPosition: ioPosition,
      description: description ?? this.description,
      appType: appType ?? this.appType,
      enabled: enabled ?? this.enabled,
      activeRecipe: activeRecipe ?? this.activeRecipe,
    );
  }
}
