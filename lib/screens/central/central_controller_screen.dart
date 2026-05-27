import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import './recipe_editor_screen.dart';

class CentralControllerScreen extends StatefulWidget {
  const CentralControllerScreen({super.key});

  @override
  State<CentralControllerScreen> createState() =>
      _CentralControllerScreenState();
}

class _CentralControllerScreenState extends State<CentralControllerScreen> {
  double _masterFlow = 0.0;
  double _totalActualFlow = 0.0;
  Map<int, Map<String, dynamic>> _subsystemStatuses = {};
  int _currentBatchId = 0;
  Map<String, dynamic>? _activeRecipe;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPeriodicUpdate();
  }

  Future<void> _loadData() async {
    final masterFlow = await WeighingPlatform.instance.getMasterFlow();
    final totalFlow = await WeighingPlatform.instance.getTotalActualFlow();
    final statuses = await WeighingPlatform.instance.getAllSubsystemStatuses();
    final batchId = await WeighingPlatform.instance.getCurrentBatchId();

    setState(() {
      _masterFlow = masterFlow;
      _totalActualFlow = totalFlow;
      _subsystemStatuses = statuses;
      _currentBatchId = batchId;
    });
  }

  void _startPeriodicUpdate() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadData();
        _startPeriodicUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('中央控制器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showRecipeSelector,
          ),
        ],
      ),
      body: Column(
        children: [
          // 主流量控制卡片
          _buildMasterFlowCard(),

          const Divider(height: 1),

          // 子系统状态列表
          Expanded(child: _buildSubsystemList()),

          // 批次控制栏
          _buildBatchControlBar(),
        ],
      ),
    );
  }

  // ============================================================================
  // 主流量控制卡片
  // ============================================================================
  Widget _buildMasterFlowCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 32, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  '总流量控制',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_activeRecipe != null)
                  Chip(
                    label: Text(_activeRecipe!['name'] ?? 'Unknown Recipe'),
                    avatar: const Icon(Icons.receipt, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 主流量设定
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '目标流量 (kg/h)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _masterFlow.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '实际流量 (kg/h)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _totalActualFlow.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getFlowErrorColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '偏差 (%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFlowError().toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getFlowErrorColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 流量调节滑块
            Row(
              children: [
                const Text('调节: '),
                Expanded(
                  child: Slider(
                    value: _masterFlow,
                    min: 0,
                    max: 1000,
                    divisions: 100,
                    label: '${_masterFlow.toStringAsFixed(0)} kg/h',
                    onChanged: (value) {
                      setState(() => _masterFlow = value);
                    },
                    onChangeEnd: (value) {
                      WeighingPlatform.instance.setMasterFlow(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'kg/h',
                      isDense: true,
                    ),
                    controller: TextEditingController(
                      text: _masterFlow.toStringAsFixed(0),
                    ),
                    onSubmitted: (value) {
                      final flow = double.tryParse(value) ?? 0.0;
                      setState(() => _masterFlow = flow);
                      WeighingPlatform.instance.setMasterFlow(flow);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getFlowErrorColor() {
    if (_masterFlow == 0) return Colors.grey;
    final error = (_totalActualFlow - _masterFlow).abs() / _masterFlow * 100;
    if (error < 5) return Colors.green;
    if (error < 10) return Colors.orange;
    return Colors.red;
  }

  double _getFlowError() {
    if (_masterFlow == 0) return 0.0;
    return (_totalActualFlow - _masterFlow) / _masterFlow * 100;
  }

  // ============================================================================
  // 子系统状态列表
  // ============================================================================
  Widget _buildSubsystemList() {
    if (_subsystemStatuses.isEmpty) {
      return const Center(child: Text('无子系统注册'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _subsystemStatuses.length,
      itemBuilder: (context, index) {
        final subsystemId = _subsystemStatuses.keys.elementAt(index);
        final status = _subsystemStatuses[subsystemId]!;
        return _buildSubsystemCard(subsystemId, status);
      },
    );
  }

  Widget _buildSubsystemCard(int subsystemId, Map<String, dynamic> status) {
    final actualFlow = (status['actualFlow'] as num?)?.toDouble() ?? 0.0;
    final targetFlow = (status['targetFlow'] as num?)?.toDouble() ?? 0.0;
    final controlRate = (status['controlRate'] as num?)?.toDouble() ?? 0.0;
    final remainingWeight =
        (status['remainingWeight'] as num?)?.toDouble() ?? 0.0;
    final isRefilling = status['isRefilling'] as bool? ?? false;
    final isFault = status['isFault'] as bool? ?? false;
    final refillCount = status['refillCount'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isFault
          ? Colors.red.shade50
          : isRefilling
          ? Colors.orange.shade50
          : null,
      child: ExpansionTile(
        leading: _buildSubsystemIcon(subsystemId, isFault, isRefilling),
        title: Text(
          '子系统 $subsystemId',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${actualFlow.toStringAsFixed(1)} / ${targetFlow.toStringAsFixed(1)} kg/h',
        ),
        trailing: _buildStatusBadge(isFault, isRefilling),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 流量信息
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        '实际流量',
                        '${actualFlow.toStringAsFixed(1)} kg/h',
                        Icons.trending_up,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        '目标流量',
                        '${targetFlow.toStringAsFixed(1)} kg/h',
                        Icons.flag,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 控制率和剩余量
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        '控制率',
                        '${controlRate.toStringAsFixed(1)} %',
                        Icons.speed,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        '剩余物料',
                        '${remainingWeight.toStringAsFixed(2)} kg',
                        Icons.inventory_2,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 补料次数
                Row(
                  children: [
                    const Icon(Icons.refresh, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '补料次数: $refillCount',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),

                // 流量进度条
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: targetFlow > 0
                      ? (actualFlow / targetFlow).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(actualFlow, targetFlow),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsystemIcon(int subsystemId, bool isFault, bool isRefilling) {
    IconData icon;
    Color color;

    if (isFault) {
      icon = Icons.error;
      color = Colors.red;
    } else if (isRefilling) {
      icon = Icons.water_drop;
      color = Colors.orange;
    } else {
      icon = Icons.scale;
      color = Colors.blue;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildStatusBadge(bool isFault, bool isRefilling) {
    if (isFault) {
      return const Chip(
        label: Text('故障', style: TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: Colors.red,
        padding: EdgeInsets.symmetric(horizontal: 8),
      );
    } else if (isRefilling) {
      return const Chip(
        label: Text('补料中', style: TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: Colors.orange,
        padding: EdgeInsets.symmetric(horizontal: 8),
      );
    } else {
      return const Chip(
        label: Text('运行中', style: TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: Colors.green,
        padding: EdgeInsets.symmetric(horizontal: 8),
      );
    }
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double actual, double target) {
    if (target == 0) return Colors.grey;
    final ratio = actual / target;
    if (ratio >= 0.95 && ratio <= 1.05) return Colors.green;
    if (ratio >= 0.85 && ratio <= 1.15) return Colors.orange;
    return Colors.red;
  }

  // ============================================================================
  // 批次控制栏
  // ============================================================================
  Widget _buildBatchControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentBatchId > 0) ...[
            const Icon(Icons.play_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('批次运行中', style: TextStyle(fontSize: 12)),
                Text(
                  'ID: $_currentBatchId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _endBatch,
              icon: const Icon(Icons.stop),
              label: const Text('结束批次'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            const Icon(Icons.stop_circle, color: Colors.grey, size: 32),
            const SizedBox(width: 12),
            const Text('无批次运行', style: TextStyle(fontSize: 16)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _startBatch,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始批次'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // 批次操作
  // ============================================================================
  Future<void> _startBatch() async {
    final operatorController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开始新批次'),
        content: TextField(
          controller: operatorController,
          decoration: const InputDecoration(
            labelText: '操作员姓名',
            hintText: '请输入操作员姓名',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batchId = await WeighingPlatform.instance.startBatch(
        operatorController.text.isEmpty ? 'Unknown' : operatorController.text,
      );

      if (batchId > 0 && mounted) {
        setState(() => _currentBatchId = batchId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批次 $batchId 已开始')));
      }
    }
  }

  Future<void> _endBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认结束批次'),
        content: Text('确定结束批次 $_currentBatchId 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('结束'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await WeighingPlatform.instance.endBatch();
      if (ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批次 $_currentBatchId 已结束')));
        setState(() => _currentBatchId = 0);
      }
    }
  }

  // ============================================================================
  // 配方选择
  // ============================================================================
  Future<void> _showRecipeSelector() async {
    final recipes = await WeighingPlatform.instance.getAllRecipes();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择配方'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(recipe['name'] ?? 'Unknown'),
                subtitle: Text(
                  '目标流量: ${recipe['totalTargetFlow']?.toStringAsFixed(0) ?? 0} kg/h',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadRecipe(recipe['recipeId'] as int);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showRecipeEditor();
            },
            icon: const Icon(Icons.add),
            label: const Text('新建配方'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRecipe(int recipeId) async {
    final ok = await WeighingPlatform.instance.loadRecipe(recipeId);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配方已加载')));
      _loadData();
    }
  }

  void _showRecipeEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecipeEditorScreen()),
    );
  }
}
