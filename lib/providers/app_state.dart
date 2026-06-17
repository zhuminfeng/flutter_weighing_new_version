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
  Map<String, dynamic> _configStatus = const {};
  List<SubsystemMappingInfo> _subsystems = [];

  StreamSubscription<WeightData>? _weightSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  bool get initialized => _initialized;
  int get selectedAppType => _selectedAppType;
  int get activeSubsystemId => _activeSubsystemId;
  Locale get locale => _locale;
  Map<String, dynamic> get configStatus => _configStatus;
  List<SubsystemMappingInfo> get subsystems => _subsystems;

  /// 是否已配置子系统（配置文件中有显式子系统条目）
  bool get hasConfiguredSubsystems =>
      (_configStatus['subsystem_count'] as int? ?? 0) > 0 ||
      _subsystems.isNotEmpty;

  WeightData getWeightData(int scaleId) =>
      _weightDataMap[scaleId] ?? const WeightData();

  AppStatusData getAppStatus(int subsystemId) =>
      _appStatusMap[subsystemId] ?? const AppStatusData();

  Future<void> initialize() async {
    try {
      _initialized = await _platform.initialize();
      if (_initialized) {
        _configStatus = await _platform.getConfigStatus();
        _subsystems = await _platform.getSubsystemMappings();
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
      _configStatus = const {};
      _subsystems = [];
      await _platform.shutdown();
    } catch (_) {}
    _initialized = false;
    notifyListeners();
    await initialize();
  }

  Future<void> refreshSubsystems() async {
    try {
      _subsystems = await _platform.getSubsystemMappings();
      _configStatus = await _platform.getConfigStatus();
      notifyListeners();
    } catch (_) {}
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

  Future<void> startApp(int subsystemId) => _platform.startApp(subsystemId);
  Future<void> stopApp(int subsystemId) => _platform.stopApp(subsystemId);

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

  Future<void> refreshAppStatusForSubsystem(int subsystemId) async {
    try {
      final status = await _platform.getAppStatus(subsystemId);
      _appStatusMap[subsystemId] = status;
      notifyListeners();
    } catch (_) {}
  }

  // ============ Material Recipe API ============

  /// 将当前子系统参数保存为物料配方
  Future<bool> saveMaterialRecipe(
          int subsystemId, String name, int appType) =>
      _platform.saveMaterialRecipe(subsystemId, name, appType);

  /// 将物料配方参数载入子系统
  Future<bool> loadMaterialRecipe(
          int subsystemId, int recipeId, int appType) =>
      _platform.loadMaterialRecipe(subsystemId, recipeId, appType);

  /// 获取指定应用类型的所有物料配方
  Future<List<Map<String, dynamic>>> getAllMaterialRecipes(int appType) =>
      _platform.getAllMaterialRecipes(appType);

  /// 删除物料配方
  Future<bool> deleteMaterialRecipe(int recipeId, int appType) =>
      _platform.deleteMaterialRecipe(recipeId, appType);

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

