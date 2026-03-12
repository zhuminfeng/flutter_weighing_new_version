import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final int _scaleId = 0;
  int _linearMode = 0;
  final List<TextEditingController> _loadControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  String _calStatus = '';
  bool _calInProgress = false;

  static const _linearModeLabels = [
    'Disabled (Zero + 1 point)',
    '3-Point (Zero + Mid + High)',
    '4-Point (Zero + Low + Mid + High)',
    '5-Point (Zero + Low + Mid + MidHigh + High)',
  ];

  // Step calibration
  final TextEditingController _stepWeightController = TextEditingController(
    text: '10.0',
  );

  @override
  void dispose() {
    for (var c in _loadControllers) c.dispose();
    _stepWeightController.dispose();
    super.dispose();
  }

  Future<void> _doZeroCal() async {
    setState(() {
      _calInProgress = true;
      _calStatus = 'Zero calibration in progress...';
    });
    try {
      await WeighingPlatform.instance.triggerCalZero(_scaleId);
      // In real app: listen to calibration event stream for completion
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _calStatus = 'Zero calibration completed';
        _calInProgress = false;
      });
    } catch (e) {
      setState(() {
        _calStatus = 'Zero calibration failed: $e';
        _calInProgress = false;
      });
    }
  }

  Future<void> _doSpanCal() async {
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
        setState(() => _calStatus = 'Invalid test load ${i + 1}');
        return;
      }
      loads.add(v);
    }

    setState(() {
      _calInProgress = true;
      _calStatus = 'Span calibration in progress...';
    });
    try {
      await WeighingPlatform.instance.triggerCalSpan(
        _scaleId,
        _linearMode,
        loads,
      );
      await Future.delayed(const Duration(seconds: 5));
      setState(
        () => _calStatus = 'Span calibration - waiting for confirmation',
      );
    } catch (e) {
      setState(() {
        _calStatus = 'Span calibration failed: $e';
        _calInProgress = false;
      });
    }
  }

  Future<void> _saveCal() async {
    try {
      final ok = await WeighingPlatform.instance.triggerSaveCalibration(
        _scaleId,
      );
      setState(() {
        _calStatus = ok
            ? 'Calibration saved successfully'
            : 'Failed to save calibration';
        _calInProgress = false;
      });
    } catch (e) {
      setState(() {
        _calStatus = 'Save failed: $e';
        _calInProgress = false;
      });
    }
  }

  Future<void> _abortCal() async {
    await WeighingPlatform.instance.triggerAbortCalibration(_scaleId);
    setState(() {
      _calStatus = 'Calibration aborted';
      _calInProgress = false;
    });
  }

  Future<void> _doStepCal() async {
    final w = double.tryParse(_stepWeightController.text);
    if (w == null || w <= 0) {
      setState(() => _calStatus = 'Invalid step test weight');
      return;
    }
    setState(() {
      _calInProgress = true;
      _calStatus = 'Step calibration started...';
    });
    try {
      await WeighingPlatform.instance.triggerStepCalibration(_scaleId, w);
    } catch (e) {
      setState(() {
        _calStatus = 'Step calibration failed: $e';
        _calInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
      appBar: AppBar(title: Text(l.tr('calibration'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status
          if (_calStatus.isNotEmpty)
            Card(
              color:
                  _calStatus.contains('failed') ||
                      _calStatus.contains('Invalid')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: ListTile(
                leading: Icon(
                  _calStatus.contains('failed') ? Icons.error : Icons.info,
                  color: _calStatus.contains('failed')
                      ? Colors.red
                      : Colors.green,
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
                    l.tr('calZero'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Clear the scale platform and press Start.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.tr('calStart')),
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
                    l.tr('calSpan'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    value: _linearMode,
                    decoration: const InputDecoration(
                      labelText: 'Linear Calibration',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(
                      4,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(_linearModeLabels[i]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _linearMode = v!),
                  ),
                  const SizedBox(height: 12),

                  for (int i = 0; i < numPoints; i++) ...[
                    TextFormField(
                      controller: _loadControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Test Load ${i + 1} (kg)',
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
                        label: Text(l.tr('calStart')),
                        onPressed: _calInProgress ? null : _doSpanCal,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(l.tr('calSave')),
                        onPressed: _calInProgress ? _saveCal : null,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: Text(l.tr('calAbort')),
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
                    l.tr('calStep'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stepWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Test Weight (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.tr('calStart')),
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
