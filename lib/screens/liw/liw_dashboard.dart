import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../widgets/weight_display.dart';
import '../../widgets/status_indicator.dart';
import '../material_recipe_screen.dart';

const Color _themeBlue = Color(0xFF005C99);

class LiwDashboard extends StatefulWidget {
  const LiwDashboard({super.key});

  @override
  State<LiwDashboard> createState() => _LiwDashboardState();
}

class _LiwDashboardState extends State<LiwDashboard>
    with SingleTickerProviderStateMixin {
  Timer? _statusTimer;
  late AnimationController _animController;
  bool _axisTestEnabled = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        AppStateProvider.of(context).refreshAppStatus();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取强类型的本地化实例
    final l = AppLocalizations.of(context)!;
    final state = AppStateProvider.of(context);
    final weightData = state.getWeightData(0);
    final appStatus = state.getAppStatus(state.activeSubsystemId);

    // 状态解析保留，此部分不作为展示文案
    final stateStr = appStatus.stateString.toLowerCase();
    final isRefilling = stateStr.contains('refill') || stateStr.contains('补料');
    final isEmptying = stateStr.contains('empty') || stateStr.contains('清空');
    final isFeeding =
        (stateStr.contains('feed') || stateStr.contains('喂料')) &&
        !isRefilling &&
        !isEmptying;

    return Column(
      children: [
        // 顶部状态栏
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.monitor_weight_outlined,
                color: _themeBlue,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l.lossInWeight} - ${_getModeString(l, appStatus)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _themeBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusIndicator(
                label: appStatus.stateString.toUpperCase(),
                isActive: appStatus.isRunning,
                color: _getStatusColor(appStatus, isRefilling, isEmptying),
              ),
              const SizedBox(width: 12),
              StatusIndicator(
                label: weightData.isStable ? l.stable : l.inMotion,
                isActive: weightData.isStable,
                color: weightData.isStable ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),

        // 主体内容
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧：状态动画与主重量显示
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // 重量主显卡片
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 2,
                          shadowColor: _themeBlue.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            // 同步修复：提供虚拟固定画布给 WeightDisplay 供其渲染与等比缩放
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: 450,
                                    height: 180,
                                    child: WeightDisplay(
                                      weight: weightData.displayWeight,
                                      unit: weightData.unitString,
                                      isStable: weightData.isStable,
                                      isOverload: weightData.isOverload,
                                      isUnderload: weightData.isUnderload,
                                      isNetMode: weightData.isNetMode,
                                      isZero: weightData.isZero,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 动画模拟卡片
                      Expanded(
                        flex: 5,
                        child: Card(
                          elevation: 2,
                          shadowColor: _themeBlue.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _LiwProcessPainter(
                                    progress: _animController.value,
                                    isRefilling: isRefilling,
                                    isFeeding:
                                        isFeeding ||
                                        (appStatus.isRunning &&
                                            appStatus.currentFlow > 0),
                                    isEmptying: isEmptying,
                                    theme: Theme.of(context),
                                    // 传递多语言文本
                                    refillingLabel: l.refillingPhase,
                                    feedingLabel: l.feedingPhase,
                                    emptyingLabel: l.emptyingFlowPhase,
                                  ),
                                  child: const SizedBox.expand(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 右侧：数据详情与控制
                Expanded(
                  flex: 4,
                  child: Card(
                    elevation: 2,
                    shadowColor: _themeBlue.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.processDetails,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _themeBlue,
                                ),
                          ),
                          const Divider(height: 24),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HighlightDataRow(
                                    l.currentFlow,
                                    appStatus.currentFlow.toStringAsFixed(2),
                                    'kg/h',
                                    _themeBlue,
                                  ),
                                  _HighlightDataRow(
                                    l.controlRate,
                                    appStatus.controlRate.toStringAsFixed(1),
                                    '%',
                                    _themeBlue.withOpacity(0.8),
                                  ),
                                  const SizedBox(height: 16),
                                  _DataRow(
                                    l.targetFlow,
                                    '${appStatus.targetFlow.toStringAsFixed(2)} kg/h',
                                  ),
                                  _DataRow(
                                    l.accumulatedWeight,
                                    '${appStatus.accumulatedWeight.toStringAsFixed(3)} kg',
                                  ),
                                  _DataRow(
                                    l.totalAccumulated,
                                    '${appStatus.totalAccumulated.toStringAsFixed(3)} kg',
                                  ),
                                  _DataRow(
                                    l.grossWeight,
                                    '${weightData.grossWeight.toStringAsFixed(3)} ${weightData.unitString}',
                                  ),
                                  _DataRow(
                                    l.tareWeight,
                                    '${weightData.tareWeight.toStringAsFixed(3)} ${weightData.unitString}',
                                  ),
                                  if (appStatus.remainingTime > 0)
                                    _DataRow(
                                      l.remainingTime,
                                      '${appStatus.remainingTime.toStringAsFixed(0)} s',
                                    ),

                                  const SizedBox(height: 16),
                                  if (appStatus.warningActive)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange,
                                            size: 28,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              appStatus.warningMessage,
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 底部：操作按钮区
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LargeActionButton(
                label: appStatus.isRunning ? l.stop : l.start,
                icon: appStatus.isRunning ? Icons.stop : Icons.play_arrow,
                color: appStatus.isRunning ? Colors.red.shade600 : _themeBlue,
                onPressed: () => appStatus.isRunning
                    ? state.stopApp(state.activeSubsystemId)
                    : state.startApp(state.activeSubsystemId),
                isPrimary: true,
              ),
              _LargeActionButton(
                label: l.zero,
                icon: Icons.exposure_zero,
                onPressed: () => state.doZero(0),
              ),
              _LargeActionButton(
                label: l.tare,
                icon: Icons.remove_circle_outline,
                onPressed: () => state.doTare(0),
              ),
              _LargeActionButton(
                label: l.clearTare,
                icon: Icons.layers_clear,
                onPressed: () => state.clearTare(0),
              ),
              _LargeActionButton(
                label: l.eprint,
                icon: Icons.print_outlined,
                onPressed: () async {
                  final nextEnabled = !_axisTestEnabled;
                  if (mounted) {
                    setState(() => _axisTestEnabled = nextEnabled);
                  }
                },
              ),
              _LargeActionButton(
                label: '配方',
                icon: Icons.playlist_add_check,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaterialRecipeScreen(
                      appType: 0,
                      subsystemId: state.activeSubsystemId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(AppStatusData status, bool refilling, bool emptying) {
    if (status.isError) return Colors.red;
    if (refilling) return _themeBlue; // 补料状态使用主题蓝
    if (emptying) return Colors.orange;
    if (status.isRunning) return Colors.green;
    return Colors.grey;
  }

  String _getModeString(AppLocalizations l, AppStatusData status) =>
      l.continuous;
}

// 失重秤料斗与流体粒子动画
class _LiwProcessPainter extends CustomPainter {
  final double progress;
  final bool isRefilling;
  final bool isFeeding;
  final bool isEmptying;
  final ThemeData theme;

  // 多语言标签属性
  final String refillingLabel;
  final String feedingLabel;
  final String emptyingLabel;

  _LiwProcessPainter({
    required this.progress,
    required this.isRefilling,
    required this.isFeeding,
    required this.isEmptying,
    required this.theme,
    required this.refillingLabel,
    required this.feedingLabel,
    required this.emptyingLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final top = 40.0;
    final bottom = size.height - 40.0;

    // 1. 绘制带有 3D 金属渐变质感的料斗
    final hopperPath = Path()
      ..moveTo(center - 90, top)
      ..lineTo(center + 90, top)
      ..lineTo(center + 30, bottom)
      ..lineTo(center - 30, bottom)
      ..close();

    final gradient = LinearGradient(
      colors: [
        Colors.grey.shade400,
        Colors.grey.shade100,
        Colors.grey.shade500,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    final hopperPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTRB(center - 90, top, center + 90, bottom),
      )
      ..style = PaintingStyle.fill;

    final hopperBorder = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(hopperPath, hopperPaint);
    canvas.drawPath(hopperPath, hopperBorder);

    // 料斗内部的深度阴影 (加深顶部开口的立体感)
    final topOpening = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(center, top), width: 180, height: 20),
      );
    canvas.drawPath(topOpening, Paint()..color = Colors.black12);
    canvas.drawPath(topOpening, hopperBorder);

    final bottomOpening = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(center, bottom), width: 60, height: 10),
      );
    canvas.drawPath(bottomOpening, Paint()..color = Colors.black87);

    // 2. 绘制物料流动动画 (粉体/颗粒效果)
    if (isRefilling) {
      _drawParticles(canvas, center, 0, top, _themeBlue, progress, width: 80);
      _drawLabel(canvas, refillingLabel, Offset(center, 15), _themeBlue);
    }
    if (isFeeding && !isEmptying) {
      _drawParticles(
        canvas,
        center,
        bottom,
        size.height,
        Colors.green.shade600,
        progress,
        width: 20,
      );
      _drawLabel(
        canvas,
        feedingLabel,
        Offset(center, size.height - 15),
        Colors.green.shade700,
      );
    }
    if (isEmptying) {
      _drawParticles(
        canvas,
        center,
        bottom,
        size.height,
        Colors.orange,
        progress,
        width: 40,
        isFast: true,
      );
      _drawLabel(
        canvas,
        emptyingLabel,
        Offset(center, size.height - 15),
        Colors.orange.shade700,
      );
    }
  }

  // 绘制粉体颗粒动画
  void _drawParticles(
    Canvas canvas,
    double x,
    double startY,
    double endY,
    Color color,
    double progress, {
    double width = 20,
    bool isFast = false,
  }) {
    final paint = Paint()..style = PaintingStyle.fill;
    final int particleCount = 20;

    for (int i = 0; i < particleCount; i++) {
      double phase = i / particleCount;
      double speed = isFast ? 2.0 : 1.0;
      double p = (progress * speed + phase) % 1.0;

      double y = startY + p * (endY - startY);
      // 水平波动 (散开效果)
      double xOffset = math.sin(p * math.pi * 3 + i * 2) * (width / 2);

      // 颗粒大小与透明度渐变 (越往下越散、透明)
      double radius = 2.0 + (i % 3);
      double opacity = math.sin(p * math.pi); // 两端淡入淡出

      canvas.drawCircle(
        Offset(x + xOffset, y),
        radius,
        paint..color = color.withOpacity(opacity.clamp(0.0, 1.0)),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          backgroundColor: Colors.white70,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LiwProcessPainter oldDelegate) => true;
}

// ---------------- UI 复用组件 ----------------
class _HighlightDataRow extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _HighlightDataRow(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  unit,
                  style: TextStyle(fontSize: 16, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label, value;
  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _LargeActionButton({
    required this.label,
    required this.icon,
    this.color,
    this.isPrimary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isPrimary ? 3 : 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor:
                color ?? Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: color != null
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            elevation: isPrimary ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
