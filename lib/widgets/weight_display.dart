import 'package:flutter/material.dart';

class WeightDisplay extends StatelessWidget {
  final double weight;
  final String unit;
  final bool isStable;
  final bool isOverload;
  final bool isUnderload;
  final bool isNetMode;
  final bool isZero;

  const WeightDisplay({
    super.key,
    required this.weight,
    required this.unit,
    this.isStable = false,
    this.isOverload = false,
    this.isUnderload = false,
    this.isNetMode = false,
    this.isZero = false,
  });

  @override
  Widget build(BuildContext context) {
    String displayText;
    // 默认使用深邃的工业主题蓝
    Color textColor = const Color(0xFF005C99);

    if (isOverload) {
      displayText = '--- OL ---';
      textColor = Colors.red;
    } else if (isUnderload) {
      displayText = '--- UL ---';
      textColor = Colors.red;
    } else {
      displayText = weight.toStringAsFixed(3);
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        // 适当减小内边距，给内部字体留出更多缩放空间
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isStable ? Colors.green.shade400 : Colors.orange.shade400,
            width: 2.5, // 加粗边框，提升仪器质感
          ),
        ),
        child: Column(
          children: [
            // 顶部状态指示行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Indicator(
                  label: isStable ? '◉ STABLE' : '◎ MOTION',
                  color: isStable
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                ),
                const SizedBox(width: 12),
                if (isNetMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      'NET',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                if (isZero) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '→0←',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // 核心修复区：使用 Expanded + FittedBox 让重量和单位作为整体缩放
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: FittedBox(
                  fit: BoxFit.contain, // 确保内容完全在框内等比缩放
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // 重量数字
                      Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace', // 等宽字体防止数字跳动
                          color: textColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 重量单位 (跟随在数字右侧，基线对齐)
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 32,
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
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
    );
  }
}

class _Indicator extends StatelessWidget {
  final String label;
  final Color color;
  const _Indicator({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: color,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}
