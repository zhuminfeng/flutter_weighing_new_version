import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../widgets/weight_display.dart';
import '../../widgets/status_indicator.dart';

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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    final l = AppLocalizations.of(context);
    final state = AppStateProvider.of(context);
    final wd = state.getWeightData(0);
    final status = state.getAppStatus(state.activeSubsystemId);

    final stateStr = status.stateString.toLowerCase();
    final isFeeding =
        stateStr.contains('feed') ||
        stateStr.contains('喂料') ||
        stateStr.contains('fill');
    final isFastFeed = stateStr.contains('fast') || stateStr.contains('粗流');
    final isEmptying = stateStr.contains('empty') || stateStr.contains('清空');

    double fillPercentage = 0.0;
    if (state.fillingRecipeEnabled) {
      // In recipe mode, show progress of the current step only
      final targets = state.fillingRecipeTargets;
      final step = state.fillingRecipeStep;
      if (step < targets.length && targets[step] > 0) {
        fillPercentage =
            (status.accumulatedWeight / targets[step]).clamp(0.0, 1.0);
      }
    } else if (status.targetWeight > 0) {
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
                  l.tr('filling'),
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
                label: wd.isStable ? l.tr('stable') : l.tr('inMotion'),
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
                            // 修复重量组件消失与溢出问题
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.contain,
                                  // 虚拟一块 450x180 的大画布让 WeightDisplay 尽情绘制，然后整体等比缩放
                                  child: SizedBox(
                                    width: 450,
                                    height: 180,
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
                                );
                              },
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
                      child: state.fillingRecipeEnabled
                          ? _buildRecipePanel(context, l, state, status)
                          : _buildSingleFillPanel(
                              context,
                              l,
                              status,
                              wd,
                              fillPercentage,
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
                label: status.isRunning ? l.tr('stop') : l.tr('start'),
                icon: status.isRunning ? Icons.stop : Icons.play_arrow,
                color: status.isRunning ? Colors.red.shade600 : _themeBlue,
                onPressed: () =>
                    status.isRunning ? state.stopApp() : state.startApp(),
                isPrimary: true,
              ),
              _LargeActionButton(
                label: l.tr('zero'),
                icon: Icons.exposure_zero,
                onPressed: () => state.doZero(0),
              ),
              _LargeActionButton(
                label: l.tr('tare'),
                icon: Icons.remove_circle_outline,
                onPressed: () => state.doTare(0),
              ),
              _LargeActionButton(
                label: l.tr('clearTare'),
                icon: Icons.layers_clear,
                onPressed: () => state.clearTare(0),
              ),
              _LargeActionButton(
                label: state.simulationMode
                    ? (state.fillingRecipeEnabled
                        ? l.tr('filling')
                        : l.tr('recipeMode'))
                    : l.tr('eprint'),
                icon: state.simulationMode
                    ? (state.fillingRecipeEnabled
                        ? Icons.local_drink
                        : Icons.receipt_long)
                    : Icons.print_outlined,
                color: state.simulationMode
                    ? (state.fillingRecipeEnabled
                        ? Colors.teal.shade600
                        : Colors.purple.shade600)
                    : null,
                onPressed: () {
                  if (state.simulationMode) {
                    state.toggleFillingRecipeMode();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 单目标灌装模式右侧面板
  Widget _buildSingleFillPanel(
    BuildContext context,
    AppLocalizations l,
    AppStatusData status,
    WeightData wd,
    double fillPercentage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.tr('targetValues'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  l.tr('targetFlow'),
                  status.targetWeight.toStringAsFixed(3),
                  'kg',
                  _themeBlue,
                ),
                const SizedBox(height: 12),
                _DataRow(
                  l.tr('weight'),
                  '${wd.displayWeight.toStringAsFixed(3)} ${wd.unitString}',
                ),
                _DataRow(
                  l.tr('controlRate'),
                  '${status.controlRate.toStringAsFixed(1)} %',
                ),
                const SizedBox(height: 32),
                // 灌装进度条
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "灌装进度 (Fill Progress)",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "${(fillPercentage * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fillPercentage >= 1.0 ? Colors.green : _themeBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (status.warningActive) _buildWarningBanner(status),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 配料/配方模式右侧面板
  Widget _buildRecipePanel(
    BuildContext context,
    AppLocalizations l,
    AppState state,
    AppStatusData status,
  ) {
    final targets = state.fillingRecipeTargets;
    final dispensed = state.fillingRecipeDispensed;
    final currentStep = state.fillingRecipeStep;
    final recipeTotal = targets.fold(0.0, (sum, t) => sum + t);
    final totalDispensed = dispensed.fold(0.0, (sum, v) => sum + v);
    final overallProgress =
        recipeTotal > 0 ? (totalDispensed / recipeTotal).clamp(0.0, 1.0) : 0.0;
    final recipeDone = status.isCompleted && currentStep >= targets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long, color: _themeBlue, size: 20),
            const SizedBox(width: 6),
            Text(
              l.tr('recipeMode'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _themeBlue,
              ),
            ),
          ],
        ),
        const Divider(height: 16),
        // 总进度条
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.tr('recipeProgress'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '${(overallProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: overallProgress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              recipeDone ? Colors.green : _themeBlue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 配料清单
        Expanded(
          child: ListView.builder(
            itemCount: targets.length,
            itemBuilder: (context, index) {
              final target = targets[index];
              final dispensedAmt =
                  index < dispensed.length ? dispensed[index] : 0.0;
              final isActive = index == currentStep && !recipeDone;
              final isDone =
                  index < currentStep || (recipeDone && index < targets.length);
              final stepPct =
                  target > 0 ? (dispensedAmt / target).clamp(0.0, 1.0) : 0.0;

              Color rowColor;
              IconData rowIcon;
              String statusLabel;
              if (isDone) {
                rowColor = Colors.green;
                rowIcon = Icons.check_circle;
                statusLabel = l.tr('done');
              } else if (isActive) {
                rowColor = _themeBlue;
                rowIcon = Icons.play_circle;
                statusLabel = l.tr('dispensing');
              } else {
                rowColor = Colors.grey.shade400;
                rowIcon = Icons.radio_button_unchecked;
                statusLabel = l.tr('pending');
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActive
                      ? _themeBlue.withOpacity(0.06)
                      : isDone
                      ? Colors.green.withOpacity(0.06)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? _themeBlue.withOpacity(0.4)
                        : isDone
                        ? Colors.green.withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(rowIcon, color: rowColor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l.tr('ingredientN')} ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rowColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: rowColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${dispensedAmt.toStringAsFixed(3)} / ${target.toStringAsFixed(3)} kg',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${(stepPct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: rowColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stepPct,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_themeBlue),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        // 总计
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.tr('recipeTotal'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${totalDispensed.toStringAsFixed(3)} / ${recipeTotal.toStringAsFixed(3)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (recipeDone)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    l.tr('recipeCompleted'),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (status.warningActive) _buildWarningBanner(status),
      ],
    );
  }

  Widget _buildWarningBanner(AppStatusData status) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
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
    );
  }
}

// 全新 3D 立体玻璃罐绘制
class _FillingProcessPainter extends CustomPainter {
  final double progress;
  final bool isFeeding;
  final bool isFastFeed;
  final bool isEmptying;
  final double fillPercentage;
  final ThemeData theme;

  _FillingProcessPainter({
    required this.progress,
    required this.isFeeding,
    required this.isFastFeed,
    required this.isEmptying,
    required this.fillPercentage,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final tankWidth = 140.0;
    final top = 40.0;
    final bottom = size.height - 40.0;
    final ellipseHeight = 24.0; // 决定 3D 俯视角度的立体感

    final bodyRect = Rect.fromCenter(
      center: Offset(center, (top + bottom) / 2),
      width: tankWidth,
      height: bottom - top,
    );
    final topEllipse = Rect.fromCenter(
      center: Offset(center, top),
      width: tankWidth,
      height: ellipseHeight,
    );
    final bottomEllipse = Rect.fromCenter(
      center: Offset(center, bottom),
      width: tankWidth,
      height: ellipseHeight,
    );

    // 1. 罐体背板玻璃 (半透明深色)
    final backGlassPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.black.withOpacity(0.02),
          Colors.black.withOpacity(0.08),
          Colors.black.withOpacity(0.02),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bodyRect);
    canvas.drawRect(bodyRect, backGlassPaint);
    canvas.drawOval(bottomEllipse, backGlassPaint);

    // 2. 液体渲染 (3D效果)
    final liquidHeight = bodyRect.height * fillPercentage;
    final liquidTopY = bottom - liquidHeight;

    if (liquidHeight > 0) {
      final liquidRect = Rect.fromLTRB(
        bodyRect.left,
        liquidTopY,
        bodyRect.right,
        bottom,
      );
      final liquidTopEllipse = Rect.fromCenter(
        center: Offset(center, liquidTopY),
        width: tankWidth,
        height: ellipseHeight,
      );

      // 液体主体的渐变色，边缘深中间浅，增强圆柱体质感
      final liquidGradient = LinearGradient(
        colors: [
          _themeBlue.withOpacity(0.9),
          _themeBlue.withOpacity(0.6),
          _themeBlue.withOpacity(0.95),
        ],
        stops: const [0.0, 0.4, 1.0],
      );

      canvas.drawRect(
        liquidRect,
        Paint()..shader = liquidGradient.createShader(liquidRect),
      );
      canvas.drawOval(
        bottomEllipse,
        Paint()..shader = liquidGradient.createShader(bottomEllipse),
      ); // 液体底部轮廓

      // 液体顶部表面 (立体液面，使用高亮蓝色)
      final surfaceGradient = LinearGradient(
        colors: [Colors.lightBlueAccent.shade100, Colors.blue.shade400],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      canvas.drawOval(
        liquidTopEllipse,
        Paint()..shader = surfaceGradient.createShader(liquidTopEllipse),
      );

      // 添加液体表面的高亮反射环
      canvas.drawOval(
        liquidTopEllipse,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // 3. 罐体正面玻璃反光与边框
    final frontGlassGradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.5),
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.3),
      ],
      stops: const [0.0, 0.3, 1.0],
    );
    canvas.drawRect(
      bodyRect,
      Paint()..shader = frontGlassGradient.createShader(bodyRect),
    );

    // 强烈的高光条
    final highlightRect = Rect.fromLTRB(
      bodyRect.left + 15,
      top,
      bodyRect.left + 35,
      bottom,
    );
    canvas.drawRect(
      highlightRect,
      Paint()..color = Colors.white.withOpacity(0.2),
    );

    // 工业级容器外轮廓线
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(bodyRect.left, top),
      Offset(bodyRect.left, bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(bodyRect.right, top),
      Offset(bodyRect.right, bottom),
      borderPaint,
    );
    canvas.drawOval(topEllipse, borderPaint); // 顶部开口
    canvas.drawOval(bottomEllipse, borderPaint); // 底部封口

    // 4. 动态水滴注水动画
    if (isFeeding && !isEmptying) {
      final color = isFastFeed ? _themeBlue : _themeBlue.withOpacity(0.7);
      final width = isFastFeed ? 18.0 : 8.0;
      // 水流注入至液面高度
      _drawWaterDrop(
        canvas,
        center,
        0,
        liquidTopY,
        color,
        progress,
        width: width,
      );
      _drawLabel(
        canvas,
        isFastFeed ? "粗流喂料 (Fast Feed)" : "细流喂料 (Fine Feed)",
        Offset(center, 15),
        color,
      );
    }

    if (isEmptying) {
      _drawWaterDrop(
        canvas,
        center,
        bottom,
        size.height,
        Colors.orange,
        progress,
        isFast: true,
        width: 22,
      );
      _drawLabel(
        canvas,
        "排空容器 (Emptying)",
        Offset(center, size.height - 15),
        Colors.orange,
      );
    }
  }

  // 绘制水滴流效果
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

    final int dropCount = 6;
    for (int i = 0; i < dropCount; i++) {
      double phase = i / dropCount;
      double speed = isFast ? 3.0 : 1.5;
      double p = (progress * speed + phase) % 1.0;

      double dropY = startY + p * (endY - startY);
      double opacity = math.sin(p * math.pi); // 渐隐消失
      double length = 15.0 + (p * 25); // 拉长形成水柱感

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
