import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../widgets/weight_display.dart';
import '../../widgets/status_indicator.dart';
import '../material_recipe_screen.dart';

const Color _themeBlue = Color(0xFF005C99);

class FillingDashboard extends StatefulWidget {
  const FillingDashboard({super.key});

  @override
  State<FillingDashboard> createState() => _FillingDashboardState();
}

class _FillingDashboardState extends State<FillingDashboard>
    with SingleTickerProviderStateMixin {
  Timer? _statusTimer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // 液体波浪需要较平滑的周期
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) AppStateProvider.of(context).refreshAppStatus();
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
    final wd = state.getWeightData(0);
    final status = state.getAppStatus(state.activeSubsystemId);

    // 这里的字符串匹配逻辑属于解析底层状态，不涉及UI展示，予以保留
    final stateStr = status.stateString.toLowerCase();
    final isFeeding =
        stateStr.contains('feed') ||
        stateStr.contains('喂料') ||
        stateStr.contains('fill');
    final isFastFeed = stateStr.contains('fast') || stateStr.contains('粗流');
    final isEmptying = stateStr.contains('empty') || stateStr.contains('清空');

    double fillPercentage = 0.0;
    if (status.targetWeight > 0) {
      fillPercentage = (wd.netWeight / status.targetWeight).clamp(0.0, 1.0);
    }

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
                Icons.precision_manufacturing,
                color: _themeBlue,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.filling,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _themeBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusIndicator(
                label: status.stateString.toUpperCase(),
                isActive: status.isRunning,
                color: status.isError
                    ? Colors.red
                    : isEmptying
                    ? Colors.orange
                    : isFeeding
                    ? _themeBlue
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              StatusIndicator(
                label: wd.isStable ? l.stable : l.inMotion,
                isActive: wd.isStable,
                color: wd.isStable ? Colors.green : Colors.orange,
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
                // 左侧：重量显示与罐装动画
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 2,
                          shadowColor: _themeBlue.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: WeightDisplay(
                                weight: wd.displayWeight,
                                unit: wd.unitString,
                                isStable: wd.isStable,
                                isOverload: wd.isOverload,
                                isUnderload: wd.isUnderload,
                                isNetMode: wd.isNetMode,
                                isZero: wd.isZero,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  painter: _FillingProcessPainter(
                                    progress: _animController.value,
                                    isFeeding: isFeeding,
                                    isFastFeed: isFastFeed,
                                    isEmptying: isEmptying,
                                    fillPercentage: fillPercentage,
                                    theme: Theme.of(context),
                                    // 将多语言文本传给画板
                                    fastFeedLabel: l.fastFeedPhase,
                                    fineFeedLabel: l.fineFeedPhase,
                                    emptyingLabel: l.emptyingPhase,
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

                // 右侧：设定参数区
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
                            l.targetValues,
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
                                    l.targetFlow, // 这里实际上是目标重量，如果 .arb 里 targetFlow 含义不准，建议在 .arb 修改或增加 targetWeight
                                    status.targetWeight.toStringAsFixed(3),
                                    'kg',
                                    _themeBlue,
                                  ),
                                  const SizedBox(height: 12),
                                  _DataRow(
                                    l.weight,
                                    '${wd.displayWeight.toStringAsFixed(3)} ${wd.unitString}',
                                  ),
                                  _DataRow(
                                    l.controlRate,
                                    '${status.controlRate.toStringAsFixed(1)} %',
                                  ),

                                  const SizedBox(height: 32),
                                  // 主题色灌装进度条
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            l.fillProgress,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            "${(fillPercentage * 100).toStringAsFixed(1)}%",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: fillPercentage,
                                          minHeight: 16,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                fillPercentage >= 1.0
                                                    ? Colors.green
                                                    : _themeBlue,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  if (status.warningActive)
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
                                              status.warningMessage,
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

        // 底部按键区
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
                label: status.isRunning ? l.stop : l.start,
                icon: status.isRunning ? Icons.stop : Icons.play_arrow,
                color: status.isRunning ? Colors.red.shade600 : _themeBlue,
                onPressed: () => status.isRunning
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
                onPressed: () {},
              ),
              _LargeActionButton(
                label: '配方',
                icon: Icons.playlist_add_check,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaterialRecipeScreen(
                      appType: 1,
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
}

// 容器玻璃质感与液体波纹动画绘制
class _FillingProcessPainter extends CustomPainter {
  final double progress;
  final bool isFeeding;
  final bool isFastFeed;
  final bool isEmptying;
  final double fillPercentage;
  final ThemeData theme;

  // 多语言标签属性
  final String fastFeedLabel;
  final String fineFeedLabel;
  final String emptyingLabel;

  _FillingProcessPainter({
    required this.progress,
    required this.isFeeding,
    required this.isFastFeed,
    required this.isEmptying,
    required this.fillPercentage,
    required this.theme,
    required this.fastFeedLabel,
    required this.fineFeedLabel,
    required this.emptyingLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final bottom = size.height - 30;
    final top = 50.0;

    final containerRect = Rect.fromLTRB(
      center - 70,
      top + 20,
      center + 70,
      bottom,
    );
    final fillHeight = containerRect.height * fillPercentage;

    // 1. 绘制液体波纹效果 (Sine Wave)
    if (fillHeight > 0) {
      final liquidPath = Path();
      liquidPath.moveTo(containerRect.left, containerRect.bottom);
      liquidPath.lineTo(containerRect.left, containerRect.bottom - fillHeight);

      // 波浪效果计算
      final waveAmplitude = (isFeeding || isEmptying) ? 4.0 : 1.0; // 动感波浪
      for (double x = containerRect.left; x <= containerRect.right; x++) {
        // x位置归一化
        double normalizedX = (x - containerRect.left) / containerRect.width;
        // 加入动画 progress 让波浪平移
        double y =
            containerRect.bottom -
            fillHeight +
            math.sin(normalizedX * math.pi * 3 + progress * math.pi * 4) *
                waveAmplitude;
        liquidPath.lineTo(x, y);
      }

      liquidPath.lineTo(containerRect.right, containerRect.bottom);
      liquidPath.close();

      // 液体渐变色
      final liquidGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_themeBlue.withOpacity(0.7), _themeBlue],
      );

      canvas.drawPath(
        liquidPath,
        Paint()..shader = liquidGradient.createShader(containerRect),
      );
    }

    // 2. 绘制带有玻璃反光的容器边缘
    final rRect = RRect.fromRectAndRadius(
      containerRect,
      const Radius.circular(10),
    );

    // 容器背影
    canvas.drawRRect(rRect, Paint()..color = Colors.black.withOpacity(0.02));

    // 高光反光带 (左侧边缘高亮)
    final highlightRect = Rect.fromLTRB(
      containerRect.left + 4,
      containerRect.top + 4,
      containerRect.left + 16,
      containerRect.bottom - 4,
    );
    final highlightGradient = LinearGradient(
      colors: [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.0)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(6)),
      Paint()..shader = highlightGradient.createShader(highlightRect),
    );

    // 容器外框
    final containerBorder = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rRect, containerBorder);

    // 3. 绘制喂料与排空的水滴流动画
    if (isFeeding && !isEmptying) {
      final color = isFastFeed ? _themeBlue : _themeBlue.withOpacity(0.6);
      final width = isFastFeed ? 16.0 : 6.0;
      // 水柱顶部到底部液面处
      _drawWaterDrop(
        canvas,
        center,
        0,
        containerRect.bottom - fillHeight,
        color,
        progress,
        width: width,
      );
      _drawLabel(
        canvas,
        isFastFeed ? fastFeedLabel : fineFeedLabel, // 替换为动态获取的多语言文本
        Offset(center, 15),
        color,
      );
    }

    if (isEmptying) {
      _drawWaterDrop(
        canvas,
        center,
        containerRect.bottom,
        size.height,
        Colors.orange,
        progress,
        isFast: true,
        width: 20,
      );
      _drawLabel(
        canvas,
        emptyingLabel, // 替换为动态获取的多语言文本
        Offset(center, size.height - 15),
        Colors.orange,
      );
    }
  }

  // 绘制圆润水滴/水柱流效果
  void _drawWaterDrop(
    Canvas canvas,
    double x,
    double startY,
    double endY,
    Color color,
    double progress, {
    bool isFast = false,
    double width = 10,
  }) {
    if (endY <= startY) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final int dropCount = 8;
    for (int i = 0; i < dropCount; i++) {
      double phase = i / dropCount;
      double speed = isFast ? 3.0 : 1.5;
      double p = (progress * speed + phase) % 1.0;

      double dropY = startY + p * (endY - startY);
      // 利用透明度做出渐隐消失的效果
      double opacity = math.sin(p * math.pi);

      // 变细拉长形成水滴感
      double length = 10.0 + (p * 20);

      if (dropY + length > startY && dropY < endY) {
        canvas.drawLine(
          Offset(x, math.max(dropY, startY)),
          Offset(x, math.min(dropY + length, endY)),
          paint..color = color.withOpacity(opacity.clamp(0.0, 1.0)),
        );
      }
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
  bool shouldRepaint(covariant _FillingProcessPainter oldDelegate) => true;
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
