import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';

class RecipeEditorScreen extends StatefulWidget {
  final int? recipeId;

  const RecipeEditorScreen({super.key, this.recipeId});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalFlowController = TextEditingController();
  final _intervalController = TextEditingController();

  bool _enableStaggerRefill = true;
  Map<int, double> _subsystemRatios = {};

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _loadRecipe(widget.recipeId!);
    }
  }

  Future<void> _loadRecipe(int recipeId) async {
    // TODO: 实现加载现有配方
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeId == null ? '新建配方' : '编辑配方'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveRecipe),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 配方名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '配方名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入配方名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 总目标流量
            TextFormField(
              controller: _totalFlowController,
              decoration: const InputDecoration(
                labelText: '总目标流量 (kg/h)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入总目标流量';
                }
                final flow = double.tryParse(value);
                if (flow == null || flow <= 0) {
                  return '请输入有效的流量值';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 错峰补料
            SwitchListTile(
              title: const Text('启用错峰补料'),
              subtitle: const Text('防止多台秤同时补料造成冲击'),
              value: _enableStaggerRefill,
              onChanged: (value) {
                setState(() => _enableStaggerRefill = value);
              },
            ),

            if (_enableStaggerRefill) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _intervalController,
                decoration: const InputDecoration(
                  labelText: '最小补料间隔 (秒)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                initialValue: '10',
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // 子系统比例配置
            Row(
              children: [
                const Text(
                  '子系统配比',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addSubsystem,
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ..._subsystemRatios.entries.map((entry) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key}')),
                  title: Text('子系统 ${entry.key}'),
                  subtitle: Text('比例: ${entry.value.toStringAsFixed(1)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editSubsystemRatio(entry.key),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeSubsystem(entry.key),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (_subsystemRatios.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRatioPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatioPreview() {
    final totalRatio = _subsystemRatios.values.fold<double>(
      0,
      (sum, r) => sum + r,
    );
    final totalFlow = double.tryParse(_totalFlowController.text) ?? 0.0;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '流量分配预览',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._subsystemRatios.entries.map((entry) {
              final allocatedFlow = totalRatio > 0
                  ? (totalFlow * entry.value / totalRatio)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('子系统 ${entry.key}:'),
                    const Spacer(),
                    Text(
                      '${allocatedFlow.toStringAsFixed(1)} kg/h',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _addSubsystem() {
    final subsystemIdController = TextEditingController();
    final ratioController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加子系统'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subsystemIdController,
              decoration: const InputDecoration(labelText: '子系统 ID'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ratioController,
              decoration: const InputDecoration(labelText: '流量比例'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(subsystemIdController.text);
              final ratio = double.tryParse(ratioController.text);

              if (id != null && ratio != null && ratio > 0) {
                setState(() {
                  _subsystemRatios[id] = ratio;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _editSubsystemRatio(int subsystemId) {
    final ratioController = TextEditingController(
      text: _subsystemRatios[subsystemId]?.toStringAsFixed(1) ?? '100',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑子系统 $subsystemId 比例'),
        content: TextField(
          controller: ratioController,
          decoration: const InputDecoration(labelText: '流量比例'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final ratio = double.tryParse(ratioController.text);
              if (ratio != null && ratio > 0) {
                setState(() {
                  _subsystemRatios[subsystemId] = ratio;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _removeSubsystem(int subsystemId) {
    setState(() {
      _subsystemRatios.remove(subsystemId);
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_subsystemRatios.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少添加一个子系统')));
      return;
    }

    final recipe = {
      'recipeId':
          widget.recipeId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'name': _nameController.text,
      'totalTargetFlow': double.parse(_totalFlowController.text),
      'enableStaggerRefill': _enableStaggerRefill,
      'refillIntervalMin': _enableStaggerRefill
          ? (double.tryParse(_intervalController.text) ?? 10.0)
          : 10.0,
      'subsystemRatios': _subsystemRatios,
    };

    final ok = await WeighingPlatform.instance.saveRecipe(recipe);

    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配方已保存')));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalFlowController.dispose();
    _intervalController.dispose();
    super.dispose();
  }
}
