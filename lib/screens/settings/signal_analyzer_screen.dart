import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';

// 数据点模型，对应CSV导出结构
class AnalyzerDataPoint {
  final int timestamp;
  final double flowRate;
  final double targetFlow;
  final double controlRate;
  final double grossWeight;
  final double targetBatchWeight;
  final double currentBatchWeight;
  final double eta;
  final bool isRefilling;
  final bool isRunning;
  final int runMode;

  AnalyzerDataPoint({
    required this.timestamp,
    required this.flowRate,
    required this.targetFlow,
    required this.controlRate,
    required this.grossWeight,
    required this.targetBatchWeight,
    required this.currentBatchWeight,
    required this.eta,
    required this.isRefilling,
    required this.isRunning,
    required this.runMode,
  });
}

class SignalAnalyzerScreen extends StatefulWidget {
  const SignalAnalyzerScreen({super.key});

  @override
  State<SignalAnalyzerScreen> createState() => _SignalAnalyzerScreenState();
}

class _SignalAnalyzerScreenState extends State<SignalAnalyzerScreen> {
  bool _isRecording = false;
  final List<AnalyzerDataPoint> _dataPoints = [];
  int _startTime = 0;
  Timer? _timer;

  // 图表可见性开关
  final Map<String, bool> _visibleSignals = {
    'flow': true,
    'targetFlow': true,
    'control': true,
    'refill': false,
    'run': false,
    'fill': false,
  };

  // 设置项
  double _xViewWindowSeconds = 15.0;
  double _autoStopSeconds = 0.0;

  // 辅助刻度上限
  double _maxFlowScale = 100.0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _dataPoints.clear();
      _startTime = DateTime.now().millisecondsSinceEpoch;
    });
    // 10Hz 采样率收集数据
    _timer = Timer.periodic(const Duration(milliseconds: 100), _collectData);
  }

  void _stopRecording() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void _collectData(Timer timer) {
    final state = AppStateProvider.of(context);
    final status = state.getAppStatus(state.activeSubsystemId);
    final weight = state.getWeightData(0);

    final now = DateTime.now().millisecondsSinceEpoch - _startTime;

    // 动态调整流量图表上限
    if (status.currentFlow > _maxFlowScale) {
      _maxFlowScale = status.currentFlow * 1.5;
    }
    if (status.targetFlow > _maxFlowScale) {
      _maxFlowScale = status.targetFlow * 1.5;
    }

    final pt = AnalyzerDataPoint(
      timestamp: now,
      flowRate: status.currentFlow,
      targetFlow: status.targetFlow,
      controlRate: status.controlRate,
      grossWeight: weight.grossWeight,
      targetBatchWeight: status.targetWeight,
      currentBatchWeight: status.accumulatedWeight,
      eta: status.remainingTime.toDouble(),
      isRefilling:
          status.stateString.toLowerCase().contains('refill') ||
          status.stateString.contains('补料'),
      isRunning: status.isRunning,
      runMode: state.selectedAppType,
    );

    // 必须确保组件未被销毁才触发 setState
    if (mounted) {
      setState(() {
        _dataPoints.add(pt);
      });
    }

    // 记录自动停止逻辑
    if (_autoStopSeconds > 0 && now >= (_autoStopSeconds * 1000)) {
      _stopRecording();
      _exportCsv(); // 自动导出
    }
  }

  Future<void> _exportCsv() async {
    if (_dataPoints.isEmpty) return;
    final l = AppLocalizations.of(context)!;

    StringBuffer sb = StringBuffer();
    sb.writeln(
      "# File type: MT_IND360RateControl Signal Analyzer - Data Export",
    );
    sb.writeln("# Datetime: ${DateTime.now().toIso8601String()}");
    sb.writeln(
      "Timestamp(ms),Flow rate(kg/h),Target rate(kg/h),Control variable(%),Gross(kg),Target batch weight(kg),Current batch weight(kg),ETA(s),Refill,Run status,Run mode,Debug info",
    );

    for (var pt in _dataPoints) {
      sb.writeln(
        "${pt.timestamp},${pt.flowRate},${pt.targetFlow},${pt.controlRate},${pt.grossWeight},${pt.targetBatchWeight},${pt.currentBatchWeight},${pt.eta},${pt.isRefilling ? 1 : 0},${pt.isRunning ? 1 : 0},${pt.runMode},0",
      );
    }

    try {
      // 针对 eLinux 嵌入式系统的默认导出路径
      final file = File(
        '/tmp/signal_analyzer_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(sb.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.exportSuccess}${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export Failed: $e')));
      }
    }
  }

  Widget _buildFilterChip(String labelKey, String mapKey, Color color) {
    return FilterChip(
      label: Text(
        labelKey,
        style: TextStyle(
          color: _visibleSignals[mapKey]! ? Colors.white : color,
        ),
      ),
      selected: _visibleSignals[mapKey] ?? false,
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (bool value) {
        setState(() {
          _visibleSignals[mapKey] = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    int currentMs = _isRecording
        ? DateTime.now().millisecondsSinceEpoch - _startTime
        : (_dataPoints.isNotEmpty ? _dataPoints.last.timestamp : 0);

    // 获取最新数据用于运行时信息显示
    AnalyzerDataPoint? latestPt = _dataPoints.isNotEmpty
        ? _dataPoints.last
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l.signalAnalyzer)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 顶部：控制区与图例开关
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(l.showFlow, 'flow', Colors.blue),
                      _buildFilterChip(
                        l.showTargetFlow,
                        'targetFlow',
                        Colors.greenAccent.shade700,
                      ),
                      _buildFilterChip(
                        l.showControlRate,
                        'control',
                        Colors.red,
                      ),
                      _buildFilterChip(
                        l.showFillingLevel,
                        'fill',
                        Colors.orange,
                      ),
                      _buildFilterChip(
                        l.showRefill,
                        'refill',
                        Colors.lightBlue.shade300,
                      ),
                      _buildFilterChip(
                        l.showRunning,
                        'run',
                        Colors.lightGreen.shade400,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                  label: Text(_isRecording ? l.stopAnalysis : l.startAnalysis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _toggleRecording,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: Text(l.exportCsv),
                  onPressed: _isRecording || _dataPoints.isEmpty
                      ? null
                      : _exportCsv,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 中部：图表绘制区
            Expanded(
              flex: 5,
              child: Card(
                color: Colors.black87,
                clipBehavior: Clip.hardEdge,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomPaint(
                    painter: SignalChartPainter(
                      points: _dataPoints,
                      xViewWindowMs: _xViewWindowSeconds * 1000.0,
                      currentMs: currentMs,
                      visibleSignals: _visibleSignals,
                      maxFlowScale: _maxFlowScale,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 底部：运行时信息与设置区
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  // 运行时信息 (Runtime Information)
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.runtimeInfo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: GridView.count(
                                crossAxisCount: 3,
                                childAspectRatio: 3.5,
                                children: [
                                  _InfoCell(
                                    l.grossWeight,
                                    "${latestPt?.grossWeight.toStringAsFixed(3) ?? '0.000'} kg",
                                  ),
                                  _InfoCell(
                                    l.targetFlow,
                                    "${latestPt?.targetFlow.toStringAsFixed(2) ?? '0.00'} kg/h",
                                  ),
                                  _InfoCell(
                                    l.currentFlow,
                                    "${latestPt?.flowRate.toStringAsFixed(2) ?? '0.00'} kg/h",
                                  ),
                                  _InfoCell(
                                    l.showControlRate,
                                    "${latestPt?.controlRate.toStringAsFixed(1) ?? '0.0'} %",
                                  ),
                                  _InfoCell(
                                    l.batchTargetWeight,
                                    "${latestPt?.targetBatchWeight.toStringAsFixed(2) ?? '0.00'} kg",
                                  ),
                                  _InfoCell(
                                    l.currentBatchWeight,
                                    "${latestPt?.currentBatchWeight.toStringAsFixed(2) ?? '0.00'} kg",
                                  ),
                                  _InfoCell(
                                    l.eta,
                                    "${latestPt?.eta.toStringAsFixed(0) ?? '0'} s",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 设置
                  Expanded(
                    flex: 1,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextFormField(
                              initialValue: _xViewWindowSeconds.toString(),
                              decoration: InputDecoration(
                                labelText: l.xAxisViewLength,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !_isRecording,
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null && val > 0 && val <= 60) {
                                  setState(() => _xViewWindowSeconds = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _autoStopSeconds.toString(),
                              decoration: InputDecoration(
                                labelText: l.autoStopRecording,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !_isRecording,
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null && val >= 0) {
                                  setState(() => _autoStopSeconds = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCell(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "$title: ",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// 高性能画板渲染折线与信号区
class SignalChartPainter extends CustomPainter {
  final List<AnalyzerDataPoint> points;
  final double xViewWindowMs;
  final int currentMs;
  final Map<String, bool> visibleSignals;
  final double maxFlowScale;

  SignalChartPainter({
    required this.points,
    required this.xViewWindowMs,
    required this.currentMs,
    required this.visibleSignals,
    required this.maxFlowScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制网格背景
    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      double y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;

    double minXMs = math.max(0.0, currentMs - xViewWindowMs);
    double maxXMs = math.max(xViewWindowMs, currentMs.toDouble());

    // 坐标映射辅助函数
    double mapX(int t) =>
        size.width - ((maxXMs - t) / xViewWindowMs) * size.width;
    double mapYFlow(double f) =>
        size.height - (f / maxFlowScale).clamp(0.0, 1.0) * size.height;
    double mapYPct(double p) =>
        size.height - (p / 100.0).clamp(0.0, 1.0) * size.height;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 1. 绘制底层数字信号色块 (补料、运行)
    final refillPaint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final runPaint = Paint()
      ..color = Colors.lightGreen.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length - 1; i++) {
      var p1 = points[i];
      var p2 = points[i + 1];
      if (p2.timestamp < minXMs) continue;

      double x1 = mapX(math.max(minXMs.toInt(), p1.timestamp));
      double x2 = mapX(p2.timestamp);

      if (visibleSignals['refill'] == true && p1.isRefilling) {
        canvas.drawRect(
          Rect.fromLTRB(x1, size.height - 30, x2, size.height),
          refillPaint,
        );
      }
      if (visibleSignals['run'] == true && p1.isRunning) {
        canvas.drawRect(
          Rect.fromLTRB(x1, size.height - 60, x2, size.height - 30),
          runPaint,
        );
      }
    }

    // 2. 绘制连续曲线
    final flowPath = Path();
    final targetFlowPath = Path();
    final controlPath = Path();
    final fillPath = Path();

    bool firstFlow = true,
        firstTarget = true,
        firstCtrl = true,
        firstFill = true;

    for (var pt in points) {
      if (pt.timestamp < minXMs) continue;
      double x = mapX(pt.timestamp);

      if (visibleSignals['flow'] == true) {
        double y = mapYFlow(pt.flowRate);
        if (firstFlow) {
          flowPath.moveTo(x, y);
          firstFlow = false;
        } else {
          flowPath.lineTo(x, y);
        }
      }
      if (visibleSignals['targetFlow'] == true) {
        double y = mapYFlow(pt.targetFlow);
        if (firstTarget) {
          targetFlowPath.moveTo(x, y);
          firstTarget = false;
        } else {
          targetFlowPath.lineTo(x, y);
        }
      }
      if (visibleSignals['control'] == true) {
        double y = mapYPct(pt.controlRate);
        if (firstCtrl) {
          controlPath.moveTo(x, y);
          firstCtrl = false;
        } else {
          controlPath.lineTo(x, y);
        }
      }
      if (visibleSignals['fill'] == true) {
        // 近似使用 grossWeight 作为灌装量演示
        double y = mapYPct(
          (pt.grossWeight / math.max(1, pt.targetBatchWeight)) * 100,
        );
        if (firstFill) {
          fillPath.moveTo(x, y);
          firstFill = false;
        } else {
          fillPath.lineTo(x, y);
        }
      }
    }

    final flowPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final targetFlowPaint = Paint()
      ..color = Colors.greenAccent.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final controlPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (!firstFlow) canvas.drawPath(flowPath, flowPaint);
    if (!firstTarget) canvas.drawPath(targetFlowPath, targetFlowPaint);
    if (!firstCtrl) canvas.drawPath(controlPath, controlPaint);
    if (!firstFill) canvas.drawPath(fillPath, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SignalChartPainter oldDelegate) => true;
}
