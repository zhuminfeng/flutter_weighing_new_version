import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';

class AppState extends ChangeNotifier {
  final WeighingPlatform _platform = WeighingPlatform.instance;

  bool _initialized = false;
  int _selectedAppType = -1; // -1=none, 0=liw, 1=filling
  int _activeSubsystemId = 0;
  final Map<int, WeightData> _weightDataMap = {};
  final Map<int, AppStatusData> _appStatusMap = {};
  Locale _locale = const Locale('zh');

  StreamSubscription<WeightData>? _weightSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Timer? _simTimer;
  bool _simulationMode = false;
  bool _simRunning = false;
  bool _simTareActive = false;
  double _simGrossWeight = 8.0;
  double _simTareWeight = 0.0;
  double _simLiwAccumulated = 0.0;
  double _simLiwTotal = 120.0;
  double _simFillingTarget = 5.0;
  double _simFillingCurrent = 0.0;
  double _simTick = 0.0;
  bool _simLiwRefilling = false;
  int _simLiwRefillTicksLeft = 0;

  bool get initialized => _initialized;
  int get selectedAppType => _selectedAppType;
  int get activeSubsystemId => _activeSubsystemId;
  Locale get locale => _locale;
  bool get simulationMode => _simulationMode;

  WeightData getWeightData(int scaleId) =>
      _weightDataMap[scaleId] ?? const WeightData();

  AppStatusData getAppStatus(int subsystemId) =>
      _appStatusMap[subsystemId] ?? const AppStatusData();

  Future<void> initialize() async {
    try {
      _initialized = await _platform.initialize();
      if (_initialized) {
        _weightSub = _platform.weightStream.listen((data) {
          _weightDataMap[data.scaleId] = data;
          notifyListeners();
        });
      } else {
        _startSimulationMode();
      }
    } catch (e) {
      _startSimulationMode();
    }
    notifyListeners();
  }

  Future<void> setSimulationMode(bool enabled) async {
    if (enabled == _simulationMode) return;

    if (enabled) {
      _weightSub?.cancel();
      _weightSub = null;
      _statusSub?.cancel();
      _statusSub = null;
      try {
        await _platform.shutdown();
      } catch (_) {}
      _startSimulationMode();
      notifyListeners();
      return;
    }

    _simTimer?.cancel();
    _simTimer = null;
    _simulationMode = false;
    _simRunning = false;

    try {
      _initialized = await _platform.initialize();
      if (_initialized) {
        _weightSub = _platform.weightStream.listen((data) {
          _weightDataMap[data.scaleId] = data;
          notifyListeners();
        });
      } else {
        _startSimulationMode();
      }
    } catch (_) {
      _startSimulationMode();
    }

    notifyListeners();
  }

  void selectAppType(int type) {
    _selectedAppType = type;
    if (_simulationMode) {
      _resetSimulationForAppType(type);
    }
    notifyListeners();
  }

  void setActiveSubsystem(int id) {
    _activeSubsystemId = id;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  Future<void> startApp() async {
    if (_simulationMode) {
      _simRunning = true;
      notifyListeners();
      return;
    }
    await _platform.startApp(_activeSubsystemId);
  }

  Future<void> stopApp() async {
    if (_simulationMode) {
      _simRunning = false;
      notifyListeners();
      return;
    }
    await _platform.stopApp(_activeSubsystemId);
  }

  Future<void> setManualControlRate(double ratePct) async {
    if (_simulationMode) {
      return;
    }
    await _platform.setManualControlRate(_activeSubsystemId, ratePct);
  }

  Future<void> doZero(int scaleId) async {
    if (_simulationMode) {
      _simGrossWeight = 0.0;
      _simFillingCurrent = 0.0;
      _simLiwAccumulated = 0.0;
      _updateSimulationData();
      return;
    }
    await _platform.doZero(scaleId);
  }

  Future<void> doTare(int scaleId) async {
    if (_simulationMode) {
      _simTareActive = true;
      _simTareWeight = _simGrossWeight;
      _updateSimulationData();
      return;
    }
    await _platform.doTare(scaleId);
  }

  Future<void> clearTare(int scaleId) async {
    if (_simulationMode) {
      _simTareActive = false;
      _simTareWeight = 0.0;
      _updateSimulationData();
      return;
    }
    await _platform.clearTare(scaleId);
  }

  Future<void> refreshAppStatus() async {
    if (_simulationMode) {
      _updateSimulationData();
      return;
    }

    try {
      final status = await _platform.getAppStatus(_activeSubsystemId);
      _appStatusMap[_activeSubsystemId] = status;
      notifyListeners();
    } catch (_) {}
  }

  void _startSimulationMode() {
    _simulationMode = true;
    _initialized = true;
    _resetSimulationForAppType(_selectedAppType < 0 ? 0 : _selectedAppType);
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _simTick += 0.2;
      _updateSimulationData();
    });
  }

  void _resetSimulationForAppType(int type) {
    if (type == 0) {
      _simGrossWeight = 8.0;
      _simLiwAccumulated = 0.0;
      _simLiwTotal = 120.0;
    } else {
      _simFillingTarget = 5.0;
      _simFillingCurrent = 0.0;
      _simGrossWeight = 0.2;
    }
    _simTick = 0.0;
    _simRunning = false;
    _simTareActive = false;
    _simTareWeight = 0.0;
    _simLiwRefilling = false;
    _simLiwRefillTicksLeft = 0;
    _updateSimulationData();
  }

  void _updateSimulationData() {
    if (_selectedAppType == 0) {
      _updateLiwSimulation();
    } else {
      _updateFillingSimulation();
    }
    notifyListeners();
  }

  void _updateLiwSimulation() {
    const targetFlow = 42.0;
    double currentFlow = 0.0;
    int simState = 0;
    String warningMessage = '';
    bool warningActive = false;

    if (_simRunning) {
      if (_simLiwRefilling) {
        simState = 5;
        _simLiwRefillTicksLeft -= 1;
        _simGrossWeight = (_simGrossWeight + 0.055).clamp(1.8, 8.8);
        currentFlow = 0.0;

        if (_simLiwRefillTicksLeft <= 0 || _simGrossWeight >= 8.6) {
          _simLiwRefilling = false;
          _simLiwRefillTicksLeft = 0;
        }
      } else {
        final wave = math.sin(_simTick * 1.4);
        currentFlow = (targetFlow + wave * 5).clamp(30.0, 52.0);
        final losePerTick = currentFlow / 3600.0 * 0.2;
        _simGrossWeight = (_simGrossWeight - losePerTick).clamp(1.5, 10.0);
        _simLiwAccumulated += losePerTick;
        _simLiwTotal += losePerTick;
        simState = 1;

        if (_simGrossWeight <= 2.9) {
          _simLiwRefilling = true;
          _simLiwRefillTicksLeft = 45;
          simState = 5;
        }
      }

      final deviation = (currentFlow - targetFlow).abs() / targetFlow;
      if (deviation > 0.18) {
        warningActive = true;
        warningMessage = 'Flow deviation warning';
      }
    }

    final tare = _simTareActive ? _simTareWeight : 0.0;
    final net = (_simGrossWeight - tare).clamp(0.0, 50.0);
    _weightDataMap[0] = WeightData(
      scaleId: 0,
      grossWeight: _simGrossWeight,
      netWeight: net,
      tareWeight: tare,
      isStable: !_simRunning || math.sin(_simTick * 5).abs() < 0.35,
      isZero: _simGrossWeight.abs() < 0.01,
      isOverload: false,
      isUnderload: false,
      isNetMode: _simTareActive,
      unit: WeightUnit.kilogram,
      timestampNs: DateTime.now().microsecondsSinceEpoch * 1000,
    );

    _appStatusMap[_activeSubsystemId] = AppStatusData(
      state: simState,
      appType: 0,
      currentWeight: _simGrossWeight,
      currentFlow: currentFlow,
      controlRate: _simRunning
          ? (currentFlow / targetFlow * 100).clamp(60, 130)
          : 0,
      targetFlow: targetFlow,
      targetWeight: 0,
      accumulatedWeight: _simLiwAccumulated,
      totalAccumulated: _simLiwTotal,
      remainingTime: 0,
      stepNumber: 1,
      statusMessage: _simRunning ? 'LIW running' : 'LIW idle',
      warningMessage: warningMessage,
      warningActive: warningActive,
    );
  }

  void _updateFillingSimulation() {
    int simState = 0;
    String warningMessage = '';
    bool warningActive = false;
    double controlRate = 0;
    double remainingTime = 0;

    if (_simRunning) {
      final fillSpeed = 0.065 + (math.sin(_simTick * 1.1) + 1) * 0.01;
      _simFillingCurrent = (_simFillingCurrent + fillSpeed).clamp(
        0.0,
        _simFillingTarget + 0.3,
      );
      _simGrossWeight = _simFillingCurrent;
      controlRate = (fillSpeed / 0.085 * 100).clamp(20, 100);
      remainingTime =
          ((_simFillingTarget - _simFillingCurrent).clamp(
            0.0,
            _simFillingTarget,
          ) /
          fillSpeed);

      if (_simFillingCurrent >= _simFillingTarget) {
        simState = 3;
        _simRunning = false;
      } else if (_simFillingCurrent >= _simFillingTarget * 0.97) {
        simState = 1;
      } else {
        simState = 1;
      }

      if ((_simFillingTarget - _simFillingCurrent) < 0.12 &&
          _simFillingCurrent < _simFillingTarget) {
        warningActive = true;
        warningMessage = 'Approaching target';
      }
    }

    final tare = _simTareActive ? _simTareWeight : 0.0;
    final net = (_simGrossWeight - tare).clamp(0.0, 50.0);
    _weightDataMap[0] = WeightData(
      scaleId: 0,
      grossWeight: _simGrossWeight,
      netWeight: net,
      tareWeight: tare,
      isStable: !_simRunning || math.sin(_simTick * 7).abs() < 0.28,
      isZero: _simGrossWeight.abs() < 0.01,
      isOverload: false,
      isUnderload: false,
      isNetMode: _simTareActive,
      unit: WeightUnit.kilogram,
      timestampNs: DateTime.now().microsecondsSinceEpoch * 1000,
    );

    _appStatusMap[_activeSubsystemId] = AppStatusData(
      state: simState,
      appType: 1,
      currentWeight: _simGrossWeight,
      currentFlow: 0,
      controlRate: controlRate,
      targetFlow: 0,
      targetWeight: _simFillingTarget,
      accumulatedWeight: _simFillingCurrent,
      totalAccumulated: _simFillingCurrent,
      remainingTime: remainingTime,
      stepNumber: 1,
      statusMessage: _simRunning ? 'Filling running' : 'Filling idle',
      warningMessage: warningMessage,
      warningActive: warningActive,
    );
  }

  @override
  void dispose() {
    _weightSub?.cancel();
    _statusSub?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }
}

class AppStateProvider extends InheritedNotifier<AppState> {
  final void Function(Locale) onLocaleChange;

  AppStateProvider({
    super.key,
    required this.onLocaleChange,
    required super.child,
  }) : super(notifier: AppState());

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!.notifier!;

  static void Function(Locale) localeChanger(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppStateProvider>()!
      .onLocaleChange;
}
