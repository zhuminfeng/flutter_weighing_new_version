import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

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
    final l = AppLocalizations.of(context)!;
    final r = await WeighingPlatform.instance.validateDigitalOutputMap(_cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r['ok'] == true
              ? l.validationPassed
              : '${l.validationFailed}${r['error']}',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final ok = await WeighingPlatform.instance.updateDigitalOutputMap(_cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l.saveSuccess : l.saveFailedMsg)),
    );
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
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l.confirmDelete),
          content: Text(l.confirmDeleteDOMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.delete),
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
    final l = AppLocalizations.of(context)!;
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
            title: Text(l.editMapping),
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
                child: Text(l.cancel),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.enterValidInteger)),
                    );
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
                child: Text(l.confirm),
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

    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.digitalOutputMapping),
        actions: [
          TextButton(onPressed: _addBinding, child: Text(l.add)),
          TextButton(onPressed: _validate, child: Text(l.validate)),
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: _cfg.bindings.isEmpty
          ? Center(child: Text(l.noMappingsMsg))
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
