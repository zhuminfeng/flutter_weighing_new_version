import 'dart:async';
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

  bool get initialized => _initialized;
  int get selectedAppType => _selectedAppType;
  int get activeSubsystemId => _activeSubsystemId;
  Locale get locale => _locale;

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
      }
    } catch (e) {
      _initialized = false;
    }
    notifyListeners();
  }

  Future<void> reinitialize() async {
    try {
      await _weightSub?.cancel();
      _weightSub = null;
      await _statusSub?.cancel();
      _statusSub = null;
      _weightDataMap.clear();
      _appStatusMap.clear();
      await _platform.shutdown();
    } catch (_) {}
    _initialized = false;
    notifyListeners();
    await initialize();
  }

  void selectAppType(int type) {
    _selectedAppType = type;
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

  Future<void> startApp() => _platform.startApp(_activeSubsystemId);
  Future<void> stopApp() => _platform.stopApp(_activeSubsystemId);

  Future<void> doZero(int scaleId) => _platform.doZero(scaleId);
  Future<void> doTare(int scaleId) => _platform.doTare(scaleId);
  Future<void> clearTare(int scaleId) => _platform.clearTare(scaleId);

  Future<void> refreshAppStatus() async {
    try {
      final status = await _platform.getAppStatus(_activeSubsystemId);
      _appStatusMap[_activeSubsystemId] = status;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _weightSub?.cancel();
    _statusSub?.cancel();
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
