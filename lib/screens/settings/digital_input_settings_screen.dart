import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

/// 离散输入映射配置页面
class DigitalInputSettingsScreen extends StatefulWidget {
  final int subsystemId;

  const DigitalInputSettingsScreen({
    super.key,
    required this.subsystemId,
  });

  @override
  State<DigitalInputSettingsScreen> createState() =>
      _DigitalInputSettingsScreenState();
}

class _DigitalInputSettingsScreenState
    extends State<DigitalInputSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  DigitalInputMapConfig _cfg = const DigitalInputMapConfig();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await WeighingPlatform.instance.getDigitalInputMap();
    setState(() {
      // Filter to this subsystem's bindings plus allow viewing all
      _cfg = c;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final ok = await WeighingPlatform.instance.updateDigitalInputMap(_cfg);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _validate() async {
    final l = AppLocalizations.of(context)!;
    final r = await WeighingPlatform.instance.validateDigitalInputMap(_cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r['ok'] == true
              ? l.validationPassed
              : '${l.validationFailed}${r['error']}',
        ),
        backgroundColor: r['ok'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  void _replaceBinding(int index, DigitalInputBinding updated) {
    final list = List<DigitalInputBinding>.from(_cfg.bindings);
    list[index] = updated;
    setState(() {
      _cfg = DigitalInputMapConfig(
        version: _cfg.version,
        bindings: list,
      );
    });
  }

  void _removeBinding(int index) {
    final list = List<DigitalInputBinding>.from(_cfg.bindings)
      ..removeAt(index);
    setState(() {
      _cfg = DigitalInputMapConfig(version: _cfg.version, bindings: list);
    });
  }

  void _addBinding() {
    final newBinding = DigitalInputBinding(
      subsystemId: widget.subsystemId,
      ioPos: 0,
      channel: 0,
      bitIndex: 0,
      signal: DigitalInputSignalType.startSignal,
    );
    setState(() {
      _cfg = DigitalInputMapConfig(
        version: _cfg.version,
        bindings: [..._cfg.bindings, newBinding],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.digitalInputMapping),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: l.validate,
            onPressed: _validate,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l.add,
            onPressed: _addBinding,
          ),
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: l.save,
                  onPressed: _save,
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cfg.bindings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.input, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(l.noMappingsMsg),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l.add),
                        onPressed: _addBinding,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cfg.bindings.length,
                  itemBuilder: (context, index) {
                    final binding = _cfg.bindings[index];
                    return _DigitalInputBindingCard(
                      binding: binding,
                      index: index,
                      onChanged: (updated) => _replaceBinding(index, updated),
                      onDelete: () => _removeBinding(index),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Binding Card
// ---------------------------------------------------------------------------

class _DigitalInputBindingCard extends StatefulWidget {
  final DigitalInputBinding binding;
  final int index;
  final ValueChanged<DigitalInputBinding> onChanged;
  final VoidCallback onDelete;

  const _DigitalInputBindingCard({
    required this.binding,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_DigitalInputBindingCard> createState() =>
      _DigitalInputBindingCardState();
}

class _DigitalInputBindingCardState
    extends State<_DigitalInputBindingCard> {
  late TextEditingController _ioPosCtrl;
  late TextEditingController _channelCtrl;
  late TextEditingController _bitIndexCtrl;

  @override
  void initState() {
    super.initState();
    _ioPosCtrl =
        TextEditingController(text: widget.binding.ioPos.toString());
    _channelCtrl =
        TextEditingController(text: widget.binding.channel.toString());
    _bitIndexCtrl =
        TextEditingController(text: widget.binding.bitIndex.toString());
  }

  @override
  void dispose() {
    _ioPosCtrl.dispose();
    _channelCtrl.dispose();
    _bitIndexCtrl.dispose();
    super.dispose();
  }

  void _update({
    int? ioPos,
    int? channel,
    int? bitIndex,
    DigitalInputSignalType? signal,
    bool? activeHigh,
    bool? enabled,
  }) {
    widget.onChanged(widget.binding.copyWith(
      ioPos: ioPos,
      channel: channel,
      bitIndex: bitIndex,
      signal: signal,
      activeHigh: activeHigh,
      enabled: enabled,
    ));
  }

  String _signalName(DigitalInputSignalType s, AppLocalizations l) {
    switch (s) {
      case DigitalInputSignalType.startSignal:
        return l.diStart;
      case DigitalInputSignalType.stopSignal:
        return l.diStop;
      case DigitalInputSignalType.resetSignal:
        return l.diReset;
      case DigitalInputSignalType.zeroSignal:
        return l.zero;
      case DigitalInputSignalType.tareSignal:
        return l.tare;
      case DigitalInputSignalType.refillRequest:
        return l.diRefillRequest;
      case DigitalInputSignalType.emergencyStop:
        return l.diEmergencyStop;
      case DigitalInputSignalType.customKey1:
        return l.diCustomKey(1);
      case DigitalInputSignalType.customKey2:
        return l.diCustomKey(2);
      case DigitalInputSignalType.customKey3:
        return l.diCustomKey(3);
      case DigitalInputSignalType.customKey4:
        return l.diCustomKey(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final binding = widget.binding;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  '${l.diBinding} #${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Switch(
                  value: binding.enabled,
                  onChanged: (v) => _update(enabled: v),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  tooltip: l.delete,
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 12),
            // Fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ioPosCtrl,
                    decoration: InputDecoration(
                      labelText: l.ioPosition,
                      hintText: l.ioPosHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) _update(ioPos: n);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _channelCtrl,
                    decoration: InputDecoration(
                      labelText: l.channel,
                      hintText: l.channelHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) _update(channel: n);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bitIndexCtrl,
                    decoration: InputDecoration(
                      labelText: l.bitIndex,
                      hintText: l.bitIndexHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) _update(bitIndex: n);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Signal type dropdown
            DropdownButtonFormField<DigitalInputSignalType>(
              value: binding.signal,
              decoration: InputDecoration(
                labelText: l.signal,
                hintText: l.signalTypeHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: DigitalInputSignalType.values.map((sig) {
                return DropdownMenuItem(
                  value: sig,
                  child: Text(_signalName(sig, l)),
                );
              }).toList(),
              onChanged: (sig) {
                if (sig != null) _update(signal: sig);
              },
            ),
            const SizedBox(height: 8),
            // Active high toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.activeHigh),
              subtitle: Text(l.activeHighHint),
              value: binding.activeHigh,
              onChanged: (v) => _update(activeHigh: v),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
