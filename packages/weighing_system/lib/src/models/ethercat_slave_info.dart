class EthercatSlaveInfo {
  final int position;
  final int alias;
  final int vendorId;
  final int productCode;
  final String description;
  final String userAlias;

  const EthercatSlaveInfo({
    required this.position,
    required this.alias,
    required this.vendorId,
    required this.productCode,
    required this.description,
    required this.userAlias,
  });

  factory EthercatSlaveInfo.fromMap(Map<String, dynamic> m) {
    return EthercatSlaveInfo(
      position: (m['position'] as num?)?.toInt() ?? 0,
      alias: (m['alias'] as num?)?.toInt() ?? 0,
      vendorId: (m['vendorId'] as num?)?.toInt() ?? 0,
      productCode: (m['productCode'] as num?)?.toInt() ?? 0,
      description: m['description'] as String? ?? '',
      userAlias: m['userAlias'] as String? ?? '',
    );
  }

  EthercatSlaveInfo copyWith({String? userAlias}) {
    return EthercatSlaveInfo(
      position: position,
      alias: alias,
      vendorId: vendorId,
      productCode: productCode,
      description: description,
      userAlias: userAlias ?? this.userAlias,
    );
  }
}
