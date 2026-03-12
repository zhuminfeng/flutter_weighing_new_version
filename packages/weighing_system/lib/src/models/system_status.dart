class AppStatusData {
  final int
      state; // 0=idle, 1=running, 2=paused, 3=completed, 4=error, 5=refilling, 6=emptying
  final int appType; // 0=liw, 1=filling
  final double currentWeight, currentFlow, controlRate;
  final double targetFlow, targetWeight;
  final double accumulatedWeight, totalAccumulated;
  final double remainingTime;
  final int stepNumber;
  final String statusMessage, warningMessage;
  final bool warningActive;

  const AppStatusData({
    this.state = 0,
    this.appType = 0,
    this.currentWeight = 0,
    this.currentFlow = 0,
    this.controlRate = 0,
    this.targetFlow = 0,
    this.targetWeight = 0,
    this.accumulatedWeight = 0,
    this.totalAccumulated = 0,
    this.remainingTime = 0,
    this.stepNumber = 0,
    this.statusMessage = '',
    this.warningMessage = '',
    this.warningActive = false,
  });

  factory AppStatusData.fromMap(Map<String, dynamic> m) => AppStatusData(
        state: m['state'] ?? 0,
        appType: m['appType'] ?? 0,
        currentWeight: (m['currentWeight'] ?? 0).toDouble(),
        currentFlow: (m['currentFlow'] ?? 0).toDouble(),
        controlRate: (m['controlRate'] ?? 0).toDouble(),
        targetFlow: (m['targetFlow'] ?? 0).toDouble(),
        targetWeight: (m['targetWeight'] ?? 0).toDouble(),
        accumulatedWeight: (m['accumulatedWeight'] ?? 0).toDouble(),
        totalAccumulated: (m['totalAccumulated'] ?? 0).toDouble(),
        remainingTime: (m['remainingTime'] ?? 0).toDouble(),
        stepNumber: m['stepNumber'] ?? 0,
        statusMessage: m['statusMessage'] ?? '',
        warningMessage: m['warningMessage'] ?? '',
        warningActive: m['warningActive'] ?? false,
      );

  String get stateString {
    switch (state) {
      case 0:
        return 'idle';
      case 1:
        return 'running';
      case 2:
        return 'paused';
      case 3:
        return 'completed';
      case 4:
        return 'error';
      case 5:
        return 'refilling';
      case 6:
        return 'emptying';
      default:
        return 'unknown';
    }
  }

  bool get isRunning => state == 1;
  bool get isIdle => state == 0;
  bool get isCompleted => state == 3;
  bool get isError => state == 4;
}
