import 'package:flutter/material.dart';
import '../providers/app_state.dart';

/// 物料配方管理界面
/// appType: 0 = 失重秤(LIW), 1 = 罐装秤(Filling)
class MaterialRecipeScreen extends StatefulWidget {
  final int appType;
  final int subsystemId;

  const MaterialRecipeScreen({
    super.key,
    required this.appType,
    required this.subsystemId,
  });

  @override
  State<MaterialRecipeScreen> createState() => _MaterialRecipeScreenState();
}

class _MaterialRecipeScreenState extends State<MaterialRecipeScreen> {
  List<Map<String, dynamic>> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final state = AppStateProvider.read(context);
    setState(() => _loading = true);
    try {
      final list = await state.getAllMaterialRecipes(widget.appType);
      setState(() {
        _recipes = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载配方失败: $e')));
      }
    }
  }

  Future<void> _saveCurrentAsRecipe() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为配方'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '配方名称',
            hintText: '例：物料A - 细粉',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    final state = AppStateProvider.read(context);
    try {
      final ok = await state.saveMaterialRecipe(
        widget.subsystemId,
        nameCtrl.text.trim(),
        widget.appType,
      );
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配方已保存')));
        }
        await _loadRecipes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('保存失败')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _loadRecipe(Map<String, dynamic> recipe) async {
    final recipeName = recipe['name'] as String? ?? '未命名';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加载配方'),
        content: Text('将使用配方「$recipeName」的参数覆盖当前设置，确认？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认加载'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final state = AppStateProvider.read(context);
    try {
      final ok = await state.loadMaterialRecipe(
        widget.subsystemId,
        recipe['recipeId'] as int,
        recipeName,
        widget.appType,
      );

      if (mounted) {
        if (ok) {
          // 🚀 核心修复1：加载成功后，主动调用 setState 强制刷新列表UI
          setState(() {});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '配方「$recipeName」已加载' : '加载失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  Future<void> _deleteRecipe(Map<String, dynamic> recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配方'),
        content: Text('确认删除配方「${recipe['name']}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final state = AppStateProvider.read(context);
    try {
      final ok = await state.deleteMaterialRecipe(
        recipe['recipeId'] as int,
        widget.appType,
      );
      if (ok) {
        // 如果删除的是当前正在使用的配方，清除活跃名称
        if (state.getActiveRecipeName(widget.subsystemId) == recipe['name']) {
          state.setActiveRecipeName(widget.subsystemId, null);
        }

        await _loadRecipes();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配方已删除')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.appType == 0 ? '失重秤物料配方' : '罐装秤物料配方';

    // 🚀 核心修复2：将 AppState 的监听提取到 build 方法的最顶端，确保全局状态改变时列表能够整体重绘
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadRecipes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveCurrentAsRecipe,
        icon: const Icon(Icons.save),
        label: const Text('保存当前参数'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '暂无配方\n点击右下角按钮保存当前参数',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _recipes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                final createdAt = recipe['createdAt'] as String? ?? '';

                // 判断当前配方是否是处于活跃（使用中）状态
                final isActive =
                    state.getActiveRecipeName(widget.subsystemId) ==
                    recipe['name'];

                return ListTile(
                  tileColor: isActive ? Colors.blue.withOpacity(0.05) : null,
                  leading: CircleAvatar(
                    backgroundColor: isActive
                        ? Colors.blue
                        : (widget.appType == 0
                              ? Colors.blue.shade200
                              : Colors.green.shade200),
                    child: isActive
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${recipe['recipeId']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        recipe['name'] as String? ?? '未命名',
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? Colors.blue.shade700 : null,
                        ),
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '当前使用',
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('创建时间: $createdAt'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isActive)
                        TextButton.icon(
                          onPressed: () => _loadRecipe(recipe),
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            '加载',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: '删除',
                        onPressed: () => _deleteRecipe(recipe),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
