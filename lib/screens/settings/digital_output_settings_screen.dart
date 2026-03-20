import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';

class DigitalOutputSettingsScreen extends StatefulWidget {
  const DigitalOutputSettingsScreen({super.key});

  @override
  State<DigitalOutputSettingsScreen> createState() =>
      _DigitalOutputSettingsScreenState();
}

class _DigitalOutputSettingsScreenState
    extends State<DigitalOutputSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  DigitalOutputMapConfig _cfg = const DigitalOutputMapConfig();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await WeighingPlatform.instance.getDigitalOutputMap();
    setState(() {
      _cfg = c;
      _loading = false;
    });
  }

  Future<void> _validate() async {
    final r = await WeighingPlatform.instance.validateDigitalOutputMap(_cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r['ok'] == true ? '配置校验通过' : '校验失败: ${r['error']}'),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await WeighingPlatform.instance.updateDigitalOutputMap(_cfg);
    if (mounted) {
      setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '保存成功' : '保存失败')));
  }

  void _replaceBinding(int index, DigitalOutputBinding updated) {
    final list = List<DigitalOutputBinding>.from(_cfg.bindings);
    list[index] = updated;
    setState(() {
      _cfg = DigitalOutputMapConfig(version: _cfg.version, bindings: list);
    });
  }

  void _removeBinding(int index) {
    final list = List<DigitalOutputBinding>.from(_cfg.bindings);
    list.removeAt(index);
    setState(() {
      _cfg = DigitalOutputMapConfig(version: _cfg.version, bindings: list);
    });
  }

  Future<void> _confirmRemoveBinding(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定删除这条 Digital Output 映射吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _removeBinding(index);
    }
  }

  void _addBinding() {
    final list = List<DigitalOutputBinding>.from(_cfg.bindings);
    list.add(
      const DigitalOutputBinding(
        subsystemId: 0,
        ioPos: 0,
        channel: 0,
        bitIndex: 0,
        signal: DigitalSignalType.feedFast,
      ),
    );
    setState(() {
      _cfg = DigitalOutputMapConfig(version: _cfg.version, bindings: list);
    });
  }

  Future<void> _editBinding(int index) async {
    final current = _cfg.bindings[index];
    final subsystemController = TextEditingController(
      text: current.subsystemId.toString(),
    );
    final ioPosController = TextEditingController(
      text: current.ioPos.toString(),
    );
    final channelController = TextEditingController(
      text: current.channel.toString(),
    );
    final bitIndexController = TextEditingController(
      text: current.bitIndex.toString(),
    );
    final appScopeController = TextEditingController(
      text: current.appScope.toString(),
    );

    var signal = current.signal;
    var activeHigh = current.activeHigh;
    var enabled = current.enabled;

    final updated = await showDialog<DigitalOutputBinding>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('编辑映射'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subsystemController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'subsystem_id',
                    ),
                  ),
                  TextField(
                    controller: ioPosController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'io_pos'),
                  ),
                  TextField(
                    controller: channelController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'channel'),
                  ),
                  TextField(
                    controller: bitIndexController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'bit_index'),
                  ),
                  TextField(
                    controller: appScopeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'app_scope'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DigitalSignalType>(
                    value: signal,
                    decoration: const InputDecoration(labelText: 'signal'),
                    items: DigitalSignalType.values
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => signal = v);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('active_high'),
                    value: activeHigh,
                    onChanged: (v) => setDialogState(() => activeHigh = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('enabled'),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final subsystemId = int.tryParse(subsystemController.text);
                  final ioPos = int.tryParse(ioPosController.text);
                  final channel = int.tryParse(channelController.text);
                  final bitIndex = int.tryParse(bitIndexController.text);
                  final appScope = int.tryParse(appScopeController.text);

                  if (subsystemId == null ||
                      ioPos == null ||
                      channel == null ||
                      bitIndex == null ||
                      appScope == null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('请输入有效整数')));
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    DigitalOutputBinding(
                      subsystemId: subsystemId,
                      ioPos: ioPos,
                      channel: channel,
                      bitIndex: bitIndex,
                      signal: signal,
                      activeHigh: activeHigh,
                      enabled: enabled,
                      appScope: appScope,
                    ),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );

    if (updated != null) {
      _replaceBinding(index, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Output Mapping'),
        actions: [
          TextButton(onPressed: _addBinding, child: const Text('新增')),
          TextButton(onPressed: _validate, child: const Text('校验')),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: _cfg.bindings.isEmpty
          ? const Center(child: Text('暂无映射，点击右上角“新增”添加'))
          : ListView.builder(
              itemCount: _cfg.bindings.length,
              itemBuilder: (_, i) {
                final b = _cfg.bindings[i];
                return ListTile(
                  onTap: () => _editBinding(i),
                  title: Text(
                    'sub:${b.subsystemId} io:${b.ioPos} ch:${b.channel} bit:${b.bitIndex}',
                  ),
                  subtitle: Text(
                    'signal:${b.signal.name} enabled:${b.enabled} scope:${b.appScope}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editBinding(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmRemoveBinding(i),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
