class EthercatDeviceConfig {
  final bool isInput;
  final int alias;
  final int position;
  final int vendorId;
  final int productCode;
  final String description;
  final String deviceAlias;
  final int subsystemId;

  const EthercatDeviceConfig({
    required this.isInput,
    required this.alias,
    required this.position,
    required this.vendorId,
    required this.productCode,
    required this.description,
    this.deviceAlias = '',
    this.subsystemId = -1,
  });

  EthercatDeviceConfig copyWith({
    String? deviceAlias,
    int? subsystemId,
  }) {
    return EthercatDeviceConfig(
      isInput: isInput,
      alias: alias,
      position: position,
      vendorId: vendorId,
      productCode: productCode,
      description: description,
      deviceAlias: deviceAlias ?? this.deviceAlias,
      subsystemId: subsystemId ?? this.subsystemId,
    );
  }

  factory EthercatDeviceConfig.fromMap(Map m) {
    return EthercatDeviceConfig(
      isInput: m['is_input'] ?? false,
      alias: m['alias'] ?? 0,
      position: m['position'] ?? 0,
      vendorId: m['vendor_id'] ?? 0,
      productCode: m['product_code'] ?? 0,
      description: m['description'] ?? '',
      deviceAlias: m['device_alias'] ?? '',
      subsystemId: m['subsystem_id'] ?? -1,
    );
  }

  Map<String, dynamic> toMap() => {
        'is_input': isInput,
        'alias': alias,
        'position': position,
        'vendor_id': vendorId,
        'product_code': productCode,
        'description': description,
        'device_alias': deviceAlias,
        'subsystem_id': subsystemId,
      };
}
