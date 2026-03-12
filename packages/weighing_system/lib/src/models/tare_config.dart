class TareConfig {
  final bool pushbuttonTareEnabled;
  final bool presetTareEnabled;

  const TareConfig(
      {this.pushbuttonTareEnabled = true, this.presetTareEnabled = true});

  Map<String, dynamic> toMap() => {
        'pushbuttonTareEnabled': pushbuttonTareEnabled,
        'presetTareEnabled': presetTareEnabled,
      };

  factory TareConfig.fromMap(Map<String, dynamic> m) => TareConfig(
        pushbuttonTareEnabled: m['pushbuttonTareEnabled'] ?? true,
        presetTareEnabled: m['presetTareEnabled'] ?? true,
      );
}
