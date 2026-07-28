import 'dart:async';
import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

// 🚀 新增：定义校正类型的枚举，用于隔离不同的操作流
enum CalType { none, zero, span, step }

class CalibrationScreen extends StatefulWidget {
  final int? subsystemId;
  final int? scaleId;

  const CalibrationScreen({super.key, this.subsystemId, this.scaleId});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _scaleId = 0;
  int _linearMode = 0;
  ScaleParams _currentParams = const ScaleParams();
  static const _unitOptions = ['g', 'kg', 'lb', 't', 'ton'];

  StreamSubscription? _calSubscription;
  final List<TextEditingController> _loadControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  String _calStatus = '';
  bool _loading = true;
  bool _loadFailed = false;
  bool _isCalError = false;

  // 🚀 新增：独立的状态机变量
  CalType _activeType = CalType.none; // 当前正在进行哪种校正
  int _calBackendState = 0; // 底层状态: 0=空闲, 1=进行中, 2/3=已完成, 4=失败

  final TextEditingController _stepWeightController = TextEditingController(
    text: '10.0',
  );

  @override
  void initState() {
    super.initState();
    _loadScaleContext();

    // 👇 监听底层 C++ 传来的标定进度
    _calSubscription = WeighingPlatform.instance.calibrationEvents.listen((
      event,
    ) {
      if (!mounted) return;
      final int scaleId = event['scaleId'];
      final int state = event['state'];
      final String msg = event['message'] ?? '';

      if (scaleId != _scaleId) return;

      setState(() {
        _calBackendState = state; // 同步底层状态

        if (state == 1) {
          // 1: InProgress
          _calStatus = msg;
        } else if (state == 2 || state == 3) {
          // 2/3: Completed
          _calStatus = '操作完成: $msg\n请点击【保存】使配置生效';
          _isCalError = false;
        } else if (state == 4) {
          // 4: Failed
          _calStatus = '标定失败: $msg';
          _isCalError = true;
          _activeType = CalType.none; // 失败后自动重置状态，允许重新开始
          _calBackendState = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _calSubscription?.cancel();
    for (var c in _loadControllers) c.dispose();
    _stepWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadScaleContext() async {
    _loadFailed = false;
    try {
      _scaleId = await _resolveScaleId();
      _currentParams = await WeighingPlatform.instance.getScaleParams(_scaleId);
    } catch (_) {
      _loadFailed = true;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<int> _resolveScaleId() async {
    if (widget.scaleId != null) return widget.scaleId!;
    if (widget.subsystemId == null) return 0;
    final mappings = await WeighingPlatform.instance.getSubsystemMappings();
    final idx = mappings.indexWhere((m) => m.subsystemId == widget.subsystemId);
    if (idx >= 0) return mappings[idx].scaleId;
    throw StateError('Unable to locate scale configuration.');
  }

  // ==========================================
  // 校正触发逻辑
  // ==========================================

  Future<void> _doZeroCal() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _activeType = CalType.zero; // 锁定为零点校正
      _calBackendState = 1;
      _isCalError = false;
      _calStatus = l.calZeroInProgress;
    });
    try {
      await WeighingPlatform.instance.triggerCalZero(_scaleId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.calZeroFailed}$e';
        _activeType = CalType.none;
      });
    }
  }

  Future<void> _doSpanCal() async {
    final l = AppLocalizations.of(context)!;
    List<double> loads = [];
    int numPoints = _linearMode + 1;

    for (int i = 0; i < numPoints; i++) {
      final v = double.tryParse(_loadControllers[i].text);
      if (v == null || v <= 0) {
        setState(() {
          _isCalError = true;
          _calStatus = '${l.invalidTestLoad} ${i + 1}';
        });
        return;
      }
      loads.add(v);
    }

    setState(() {
      _activeType = CalType.span; // 锁定为量程校正
      _calBackendState = 1;
      _isCalError = false;
      _calStatus = '初始化多点标定...请清空秤台以抓取零点';
    });

    try {
      await WeighingPlatform.instance.triggerCalSpan(
        _scaleId,
        _linearMode,
        loads,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.calSpanFailed}$e';
        _activeType = CalType.none;
      });
    }
  }

  Future<void> _doStepCal() async {
    final l = AppLocalizations.of(context)!;
    final w = double.tryParse(_stepWeightController.text);
    if (w == null || w <= 0) {
      setState(() {
        _isCalError = true;
        _calStatus = l.invalidStepWeight;
      });
      return;
    }
    setState(() {
      _activeType = CalType.step; // 锁定为阶跃校正
      _calBackendState = 1;
      _isCalError = false;
      _calStatus = l.calStepStarted;
    });
    try {
      await WeighingPlatform.instance.triggerStepCalibration(_scaleId, w);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.calStepFailed}$e';
        _activeType = CalType.none;
      });
    }
  }

  // ==========================================
  // 确认加码、保存、中止逻辑 (全局共享)
  // ==========================================

  Future<void> _addLoadCal() async {
    try {
      await WeighingPlatform.instance.triggerCalibrationAddLoad(_scaleId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '操作失败: $e';
      });
    }
  }

  Future<void> _saveCal() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _calStatus = '正在保存数据...';
    });
    try {
      // 1. 下发标定单位
      await WeighingPlatform.instance.updateScaleParams(
        _scaleId,
        _currentParams,
      );
      // 2. 持久化数据
      final ok = await WeighingPlatform.instance.triggerSaveCalibration(
        _scaleId,
      );

      if (!mounted) return;
      setState(() {
        _isCalError = !ok;
        _calStatus = ok ? l.calSavedSuccess : l.calSaveFailed;
        _activeType = CalType.none; // 保存完成后，彻底释放锁定
        _calBackendState = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.saveFailed}$e';
        _activeType = CalType.none;
      });
    }
  }

  Future<void> _abortCal() async {
    final l = AppLocalizations.of(context)!;
    await WeighingPlatform.instance.triggerAbortCalibration(_scaleId);
    if (!mounted) return;
    setState(() {
      _isCalError = false;
      _calStatus = l.calAborted;
      _activeType = CalType.none; // 中止后，释放锁定
      _calBackendState = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.calibration)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(title: Text(l.calibration)),
        body: Center(child: Text(l.loadScaleSettingsFailed)),
      );
    }

    final linearModeLabels = [
      l.linearDisabled,
      l.linear3Point,
      l.linear4Point,
      l.linear5Point,
    ];
    int numPoints = _linearMode + 1;

    return Scaffold(
      appBar: AppBar(title: Text(l.calibration)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === 状态提示框 ===
          if (_calStatus.isNotEmpty)
            Card(
              color: _isCalError ? Colors.red.shade50 : Colors.green.shade50,
              child: ListTile(
                leading: Icon(
                  _isCalError ? Icons.error : Icons.info,
                  color: _isCalError ? Colors.red : Colors.green,
                ),
                title: Text(_calStatus),
              ),
            ),
          const SizedBox(height: 16),

          // === 分离的“标定专用单位”下拉框 ===
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int>(
                value: _currentParams.calibrationUnit,
                decoration: const InputDecoration(
                  labelText: '物理砝码标定单位 (Calibration Unit)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(
                  _unitOptions.length,
                  (i) =>
                      DropdownMenuItem(value: i, child: Text(_unitOptions[i])),
                ),
                // 只要有任何校正在进行，就禁用单位切换
                onChanged: _activeType != CalType.none
                    ? null
                    : (v) => setState(() {
                        _currentParams = _currentParams.copyWith(
                          calibrationUnit: v!,
                        );
                      }),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // =======================================================
          // 🚀 零点校正专属区域 (Zero Calibration)
          // =======================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.calZero,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l.clearScalePressStart),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 当空闲时、或者正在进行零点校正时显示 Start，其他校正进行时隐藏
                      if (_activeType == CalType.none ||
                          _activeType == CalType.zero)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l.calStart),
                          // 运行中禁用
                          onPressed: _activeType == CalType.zero
                              ? null
                              : _doZeroCal,
                        ),

                      // 零点抓取【完成】后，专门在此处显示保存按钮
                      if (_activeType == CalType.zero &&
                          (_calBackendState == 2 || _calBackendState == 3))
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(l.calSave),
                          onPressed: _saveCal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      // 零点校正过程中，显示中止按钮
                      if (_activeType == CalType.zero)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: Text(l.calAbort),
                          onPressed: _abortCal,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // =======================================================
          // 🚀 量程校正专属区域 (Span Calibration)
          // =======================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.calSpan,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    value: _linearMode,
                    decoration: InputDecoration(
                      labelText: l.linearCalibration,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(
                      4,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(linearModeLabels[i]),
                      ),
                    ),
                    onChanged: _activeType != CalType.none
                        ? null
                        : (v) => setState(() => _linearMode = v!),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < numPoints; i++) ...[
                    TextFormField(
                      controller: _loadControllers[i],
                      decoration: InputDecoration(
                        labelText: l.testLoadKg(i + 1),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      readOnly: _activeType != CalType.none, // 标定中禁止修改目标重量
                    ),
                    const SizedBox(height: 8),
                  ],

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 空闲或量程校正时显示 Start
                      if (_activeType == CalType.none ||
                          _activeType == CalType.span)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l.calStart),
                          onPressed: _activeType == CalType.span
                              ? null
                              : _doSpanCal,
                        ),

                      // 量程校正【进行中】时，显示确认加码按钮
                      if (_activeType == CalType.span && _calBackendState == 1)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_task),
                          label: const Text('确认加码 (Next)'),
                          onPressed: _addLoadCal,
                        ),

                      // 量程校正【全部完成】后，在此处显示保存按钮
                      if (_activeType == CalType.span &&
                          (_calBackendState == 2 || _calBackendState == 3))
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(l.calSave),
                          onPressed: _saveCal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      // 量程校正过程中，显示中止按钮
                      if (_activeType == CalType.span)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: Text(l.calAbort),
                          onPressed: _abortCal,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // =======================================================
          // 🚀 阶跃校正专属区域 (Step Calibration)
          // =======================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.calStep,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stepWeightController,
                    decoration: InputDecoration(
                      labelText: l.testWeightKg,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: _activeType != CalType.none,
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_activeType == CalType.none ||
                          _activeType == CalType.step)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l.calStart),
                          onPressed: _activeType == CalType.step
                              ? null
                              : _doStepCal,
                        ),

                      if (_activeType == CalType.step && _calBackendState == 1)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_task),
                          label: const Text('确认操作 (Next)'),
                          onPressed: _addLoadCal,
                        ),

                      if (_activeType == CalType.step &&
                          (_calBackendState == 2 || _calBackendState == 3))
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(l.calSave),
                          onPressed: _saveCal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),

                      if (_activeType == CalType.step)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: Text(l.calAbort),
                          onPressed: _abortCal,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
