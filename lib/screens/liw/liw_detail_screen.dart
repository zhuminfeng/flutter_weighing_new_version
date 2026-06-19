import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../widgets/weight_display.dart';
import '../../widgets/status_indicator.dart';

class LiwDetailScreen extends StatefulWidget {
  const LiwDetailScreen({super.key});

  @override
  State<LiwDetailScreen> createState() => _LiwDetailScreenState();
}

class _LiwDetailScreenState extends State<LiwDetailScreen> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // 保持高频轮询以刷新详情页数据
    _statusTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) AppStateProvider.of(context).refreshAppStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppStateProvider.of(context);

    final int subId = state.activeSubsystemId;
    final weightData = state.getWeightData(subId);
    final appStatus = state.getAppStatus(subId);

    // ====================================================================
    // 【修复】：解析底层状态，计算 StatusIndicator 需要的真实参数
    // ====================================================================
    Color indicatorColor = Colors.grey;
    bool isIndicatorActive = false;
    String displayLabel = appStatus.statusMessage.isEmpty
        ? "Idle / 待机"
        : appStatus.statusMessage;

    if (appStatus.warningActive) {
      indicatorColor = Colors.redAccent;
      isIndicatorActive = true;
      if (appStatus.warningMessage.isNotEmpty) {
        displayLabel = appStatus.warningMessage;
      }
    } else if (displayLabel.contains("Feeding") ||
        displayLabel.contains("喂料")) {
      indicatorColor = Colors.greenAccent;
      isIndicatorActive = true;
    } else if (displayLabel.contains("Refill") || displayLabel.contains("补料")) {
      indicatorColor = Colors.blueAccent;
      isIndicatorActive = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${subId + 1}# 失重秤详情仪表盘'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 顶部状态栏
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 【修复】：使用正确的参数调用 StatusIndicator
                StatusIndicator(
                  label: displayLabel,
                  isActive: isIndicatorActive,
                  color: indicatorColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 核心重量显示区
            Expanded(
              flex: 4,
              child: WeightDisplay(
                weight: weightData.netWeight,
                unit: 'kg',
                isStable: weightData.isStable,
                isZero: weightData.isZero,
                isNetMode: weightData.isNetMode,
              ),
            ),
            const SizedBox(height: 16),

            // 流量与PID控制信息面板
            Expanded(
              flex: 3,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDataColumn(
                        '当前流速 (PV)',
                        '${appStatus.currentFlow.toStringAsFixed(2)} kg/h',
                        Colors.green.shade700,
                      ),
                      _buildDataColumn(
                        '目标流速 (SV)',
                        '${appStatus.targetFlow.toStringAsFixed(1)} kg/h',
                        Colors.black87,
                      ),
                      _buildDataColumn(
                        '控制率 (Out)',
                        '${appStatus.controlRate.toStringAsFixed(1)} %',
                        Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 底部操作按钮栏
            Row(
              children: [
                _LargeActionButton(
                  label: l?.start ?? '启动',
                  icon: Icons.play_arrow,
                  color: Colors.green.shade700,
                  isPrimary: true,
                  onPressed: () => state.startApp(subId),
                ),
                _LargeActionButton(
                  label: l?.stop ?? '停止',
                  icon: Icons.stop,
                  color: Colors.red.shade700,
                  isPrimary: true,
                  onPressed: () => state.stopApp(subId),
                ),
                _LargeActionButton(
                  label: l?.zero ?? '清零',
                  icon: Icons.exposure_zero,
                  onPressed: () => state.doZero(subId),
                ),
                _LargeActionButton(
                  label: l?.tare ?? '去皮',
                  icon: Icons.remove_circle_outline,
                  onPressed: () => state.doTare(subId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn(String label, String value, Color valueColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
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
    );
  }
}
