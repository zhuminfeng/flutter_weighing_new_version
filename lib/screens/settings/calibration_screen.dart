import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

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
  final List<TextEditingController> _loadControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  String _calStatus = '';
  bool _calInProgress = false;
  bool _loading = true;
  bool _loadFailed = false;
  // 新增一个 flag，用于正确判断状态框颜色，避免依赖英文字符串匹配
  bool _isCalError = false;

  // Step calibration
  final TextEditingController _stepWeightController = TextEditingController(
    text: '10.0',
  );

  @override
  void initState() {
    super.initState();
    _loadScaleContext();
  }

  @override
  void dispose() {
    for (var c in _loadControllers) c.dispose();
    _stepWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadScaleContext() async {
    _loadFailed = false;
    try {
      _scaleId = await _resolveScaleId();
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
    throw StateError(
      'Unable to locate scale configuration for subsystem: ${widget.subsystemId}',
    );
  }

  Future<void> _doZeroCal() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _calInProgress = true;
      _isCalError = false;
      _calStatus = l.calZeroInProgress;
    });
    try {
      await WeighingPlatform.instance.triggerCalZero(_scaleId);
      // In real app: listen to calibration event stream for completion
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _calStatus = l.calZeroCompleted;
        _calInProgress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.calZeroFailed}$e';
        _calInProgress = false;
      });
    }
  }

  Future<void> _doSpanCal() async {
    final l = AppLocalizations.of(context)!;
    List<double> loads = [];
    int numPoints;
    switch (_linearMode) {
      case 0:
        numPoints = 1;
        break;
      case 1:
        numPoints = 2;
        break;
      case 2:
        numPoints = 3;
        break;
      case 3:
        numPoints = 4;
        break;
      default:
        numPoints = 1;
    }

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
      _calInProgress = true;
      _isCalError = false;
      _calStatus = l.calSpanInProgress;
    });
    try {
      await WeighingPlatform.instance.triggerCalSpan(
        _scaleId,
        _linearMode,
        loads,
      );
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _calStatus = l.calSpanWaiting;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.calSpanFailed}$e';
        _calInProgress = false;
      });
    }
  }

  Future<void> _saveCal() async {
    final l = AppLocalizations.of(context)!;
    try {
      final ok = await WeighingPlatform.instance.triggerSaveCalibration(
        _scaleId,
      );
      if (!mounted) return;
      setState(() {
        _isCalError = !ok;
        _calStatus = ok ? l.calSavedSuccess : l.calSaveFailed;
        _calInProgress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCalError = true;
        _calStatus = '${l.saveFailed}$e';
        _calInProgress = false;
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
      _calInProgress = false;
    });
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
      _calInProgress = true;
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
        _calInProgress = false;
      });
    }
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

    // 动态生成模式标签，支持国际化切换
    final linearModeLabels = [
      l.linearDisabled,
      l.linear3Point,
      l.linear4Point,
      l.linear5Point,
    ];

    int numPoints;
    switch (_linearMode) {
      case 0:
        numPoints = 1;
        break;
      case 1:
        numPoints = 2;
        break;
      case 2:
        numPoints = 3;
        break;
      case 3:
        numPoints = 4;
        break;
      default:
        numPoints = 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.calibration)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Box
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

          // === Zero Calibration ===
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.calStart),
                    onPressed: _calInProgress ? null : _doZeroCal,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // === Span Calibration ===
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
                    onChanged: (v) => setState(() => _linearMode = v!),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < numPoints; i++) ...[
                    TextFormField(
                      controller: _loadControllers[i],
                      decoration: InputDecoration(
                        // 使用带参生成的属性
                        labelText: l.testLoadKg(i + 1),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l.calStart),
                        onPressed: _calInProgress ? null : _doSpanCal,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(l.calSave),
                        onPressed: _calInProgress ? _saveCal : null,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: Text(l.calAbort),
                        onPressed: _calInProgress ? _abortCal : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // === Step Calibration ===
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
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.calStart),
                    onPressed: _calInProgress ? null : _doStepCal,
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
