import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';

class EthercatDeviceSettingsScreen extends StatefulWidget {
  const EthercatDeviceSettingsScreen({super.key});

  @override
  State<EthercatDeviceSettingsScreen> createState() =>
      _EthercatDeviceSettingsScreenState();
}

class _EthercatDeviceSettingsScreenState
    extends State<EthercatDeviceSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _scanning = false;
  List<EthercatDeviceConfig> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devices = await WeighingPlatform.instance.getEthercatDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final scanned = await WeighingPlatform.instance.scanEthercatSlaves();
    if (!mounted) return;
    setState(() => _scanning = false);

    if (scanned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未检测到任何 EtherCAT 从站')),
      );
      return;
    }

    // 将已有配置（device_alias / subsystem_id）合并到扫描结果中
    final existing = {for (final d in _devices) d.position: d};
    final merged = scanned.map((s) {
      final prev = existing[s.position];
      if (prev == null) return s;
      return s.copyWith(
        deviceAlias: prev.deviceAlias,
        subsystemId: prev.subsystemId,
      );
    }).toList();

    setState(() => _devices = merged);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已扫描到 ${merged.length} 个从站')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await WeighingPlatform.instance.updateEthercatDevices(_devices);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '保存成功' : '保存失败'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _editDevice(int index) async {
    final current = _devices[index];
    final messenger = ScaffoldMessenger.of(context);
    final aliasController = TextEditingController(text: current.deviceAlias);
    final subsystemController = TextEditingController(
      text: current.subsystemId >= 0 ? current.subsystemId.toString() : '',
    );

    final updated = await showDialog<EthercatDeviceConfig>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('设备配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(
                  labelText: '设备别名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subsystemController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '子系统ID（留空表示未分配）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = subsystemController.text.trim();
                final subsystemId = text.isEmpty ? -1 : int.tryParse(text);
                if (subsystemId == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('子系统ID必须是整数')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(
                  current.copyWith(
                    deviceAlias: aliasController.text.trim(),
                    subsystemId: subsystemId,
                  ),
                );
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (updated == null) return;
    final list = List<EthercatDeviceConfig>.from(_devices);
    list[index] = updated;
    setState(() => _devices = list);
  }

  String _hex(int value, {int width = 8}) =>
      '0x${value.toRadixString(16).padLeft(width, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EtherCAT设备配置'),
        actions: [
          IconButton(
            tooltip: '扫描从站',
            onPressed: (_scanning || _saving) ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar),
          ),
          IconButton(
            tooltip: '保存配置',
            onPressed: (_saving || _scanning) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('暂无设备，请点击右上角扫描图标自动检测'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _scanning ? null : _scan,
                        icon: const Icon(Icons.radar),
                        label: const Text('扫描 EtherCAT 从站'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final d = _devices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(
                          d.deviceAlias.isEmpty ? d.description : d.deviceAlias,
                        ),
                        subtitle: Text(
                          'position=${d.position}  VID=${_hex(d.vendorId)}  PID=${_hex(d.productCode)}\n'
                          '描述: ${d.description}\n'
                          '子系统: ${d.subsystemId >= 0 ? d.subsystemId : '未分配'}',
                        ),
                        isThreeLine: true,
                        trailing: Text(d.isInput ? '输入' : '输出'),
                        onTap: () => _editDevice(index),
                      ),
                    );
                  },
                ),
    );
  }
}
