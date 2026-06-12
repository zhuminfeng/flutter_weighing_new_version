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
                if (subsystemId == null) return;
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

  String _hex(int value) => '0x${value.toRadixString(16).padLeft(8, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EtherCAT设备配置'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
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
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final d = _devices[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
