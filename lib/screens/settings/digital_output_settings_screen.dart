import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final ok = r['ok'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.validationPassed : '${l.validationFailed}${r['error']}'),
        backgroundColor: ok ? Colors.green : Colors.red,
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
      SnackBar(
        content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
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
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
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
    _editBinding(list.length - 1);
  }

  String _signalName(DigitalSignalType signal, AppLocalizations l) {
    switch (signal) {
      case DigitalSignalType.feedFast:
        return l.sigFeedFast;
      case DigitalSignalType.feedSlow:
        return l.sigFeedSlow;
      case DigitalSignalType.refillValve:
        return l.sigRefillValve;
      case DigitalSignalType.emptyingValve:
        return l.sigEmptyingValve;
      case DigitalSignalType.alarmOut:
        return l.sigAlarmOut;
      case DigitalSignalType.runningInd:
        return l.sigRunningInd;
      case DigitalSignalType.warningInd:
        return l.sigWarningInd;
      case DigitalSignalType.readyInd:
        return l.sigReadyInd;
      // ignore: unreachable_switch_default
      default:
        return signal.name;
    }
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: subsystemController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.doSubsystemId,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ioPosController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.doIoPos,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: channelController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.doChannel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bitIndexController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.doBitIndex,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appScopeController,
                    keyboardType: TextInputType.numberWithOptions(signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[-\d]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l.doAppScope,
                      helperText: l.doAppScopeHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DigitalSignalType>(
                    value: signal,
                    decoration: InputDecoration(
                      labelText: l.doSignalType,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DigitalSignalType.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_signalName(e, l)),
                          ),
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
                    title: Text(l.doActiveHigh),
                    value: activeHigh,
                    onChanged: (v) => setDialogState(() => activeHigh = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.enabled),
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
              FilledButton(
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.digitalOutputMapping),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.add),
            onPressed: _addBinding,
          ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l.validate),
            onPressed: _validate,
          ),
          TextButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _cfg.bindings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.device_hub_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.noMappingsMsg,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l.add),
                    onPressed: _addBinding,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _cfg.bindings.length,
              itemBuilder: (_, i) {
                final b = _cfg.bindings[i];
                return _BindingCard(
                  index: i,
                  binding: b,
                  signalName: _signalName(b.signal, l),
                  subsystemIdLabel: l.doSubsystemId,
                  ioPosLabel: l.doIoPos,
                  channelLabel: l.doChannel,
                  bitIndexLabel: l.doBitIndex,
                  appScopeLabel: l.doAppScope,
                  activeHighLabel: l.doActiveHigh,
                  enabledLabel: l.enabled,
                  disabledLabel: l.disabled,
                  onEdit: () => _editBinding(i),
                  onDelete: () => _confirmRemoveBinding(i),
                );
              },
            ),
    );
  }
}

class _BindingCard extends StatelessWidget {
  const _BindingCard({
    required this.index,
    required this.binding,
    required this.signalName,
    required this.subsystemIdLabel,
    required this.ioPosLabel,
    required this.channelLabel,
    required this.bitIndexLabel,
    required this.appScopeLabel,
    required this.activeHighLabel,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final DigitalOutputBinding binding;
  final String signalName;
  final String subsystemIdLabel;
  final String ioPosLabel;
  final String channelLabel;
  final String bitIndexLabel;
  final String appScopeLabel;
  final String activeHighLabel;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = binding.enabled;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isEnabled
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isEnabled
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signalName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isEnabled ? null : colorScheme.outline,
                      ),
                    ),
                  ),
                  _StatusChip(
                    enabled: isEnabled,
                    enabledLabel: enabledLabel,
                    disabledLabel: disabledLabel,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _FieldLabel(
                    label: subsystemIdLabel,
                    value: '${binding.subsystemId}',
                  ),
                  _FieldLabel(label: ioPosLabel, value: '${binding.ioPos}'),
                  _FieldLabel(
                    label: channelLabel,
                    value: '${binding.channel}',
                  ),
                  _FieldLabel(
                    label: bitIndexLabel,
                    value: '${binding.bitIndex}',
                  ),
                  _FieldLabel(
                    label: appScopeLabel,
                    value: '${binding.appScope}',
                  ),
                  _FieldLabel(
                    label: activeHighLabel,
                    value: binding.activeHigh ? '✓' : '✗',
                    valueColor: binding.activeHigh
                        ? Colors.green
                        : colorScheme.error,
                    semanticsLabel:
                        '$activeHighLabel: ${binding.activeHigh ? enabledLabel : disabledLabel}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.enabled,
    required this.enabledLabel,
    required this.disabledLabel,
  });

  final bool enabled;
  final String enabledLabel;
  final String disabledLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        enabled ? enabledLabel : disabledLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: enabled
              ? colorScheme.onPrimaryContainer
              : colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    required this.value,
    this.valueColor,
    this.semanticsLabel,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Optional override for screen-reader label (defaults to "$label: $value").
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel ?? '$label: $value',
      excludeSemantics: true,
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
