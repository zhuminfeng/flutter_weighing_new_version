import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../providers/app_state.dart';
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
        backgroundColor: r['ok'] == true ? Colors.green : Colors.red,
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

  // ==========================================
  // 数字量输出映射 (Digital IO) 的 CRUD 操作
  // ==========================================
  void _replaceBinding(int index, DigitalOutputBinding updated) {
    final list = List<DigitalOutputBinding>.from(_cfg.bindings);
    list[index] = updated;
    setState(() {
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: list,
        servoBindings: _cfg.servoBindings,
      );
    });
  }

  void _removeBinding(int index) {
    final list = List<DigitalOutputBinding>.from(_cfg.bindings);
    list.removeAt(index);
    setState(() {
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: list,
        servoBindings: _cfg.servoBindings,
      );
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
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: list,
        servoBindings: _cfg.servoBindings,
      );
    });
  }

  // ==========================================
  // 伺服电机映射 (Servo Routing) 的 CRUD 操作
  // ==========================================
  void _replaceServoBinding(int index, ServoOutputBinding updated) {
    final list = List<ServoOutputBinding>.from(_cfg.servoBindings);
    list[index] = updated;
    setState(() {
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: _cfg.bindings,
        servoBindings: list,
      );
    });
  }

  void _removeServoBinding(int index) {
    final list = List<ServoOutputBinding>.from(_cfg.servoBindings);
    list.removeAt(index);
    setState(() {
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: _cfg.bindings,
        servoBindings: list,
      );
    });
  }

  Future<void> _confirmRemoveServoBinding(int index) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l.confirmDelete),
          content: Text(l.confirmDeleteServoMsg), // 使用新的国际化字段
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l.delete),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _removeServoBinding(index);
    }
  }

  void _addServoBinding() {
    final list = List<ServoOutputBinding>.from(_cfg.servoBindings);
    list.add(
      const ServoOutputBinding(
        subsystemId: 0,
        servoPos: 0,
        channel: 0,
        signal: DigitalSignalType.feedFast,
      ),
    );
    setState(() {
      _cfg = DigitalOutputMapConfig(
        version: _cfg.version,
        bindings: _cfg.bindings,
        servoBindings: list,
      );
    });
  }

  // ==========================================
  // 辅助方法
  // ==========================================
  String _getSignalTypeName(BuildContext context, DigitalSignalType signal) {
    final l = AppLocalizations.of(context)!;
    switch (signal) {
      case DigitalSignalType.feedFast:
        return l.feedFast;
      case DigitalSignalType.feedSlow:
        return l.feedSlow;
      case DigitalSignalType.refillValve:
        return l.refillValve;
      case DigitalSignalType.emptyingValve:
        return l.emptyingValve;
      case DigitalSignalType.alarmOut:
        return l.alarm;
      case DigitalSignalType.runningInd:
        return l.runningSignal;
      case DigitalSignalType.warningInd:
        return l.warningSignal;
      case DigitalSignalType.bagClamp:
        return l.bagClamp; // 使用新的国际化字段
      default:
        return signal.name;
    }
  }

  // ==========================================
  // 编辑对话框：数字量 IO
  // ==========================================
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
                  Text(
                    l.hardwareConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subsystemController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.subsystemId,
                      helperText: l.subsystemIdHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ioPosController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.ioPosition,
                      helperText: l.ioPosHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: channelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.channel,
                      helperText: l.channelHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bitIndexController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.bitIndex,
                      helperText: l.bitIndexHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l.signalConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DigitalSignalType>(
                    value: signal,
                    decoration: InputDecoration(
                      labelText: l.signal,
                      helperText: l.signalTypeHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DigitalSignalType.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_getSignalTypeName(context, e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => signal = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.activeHigh),
                    subtitle: Text(
                      l.activeHighHint,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: activeHigh,
                    onChanged: (v) => setDialogState(() => activeHigh = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.enabled),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l.scopeConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appScopeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.appScope,
                      helperText: l.appScopeHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
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

  // ==========================================
  // 编辑对话框：伺服电机
  // ==========================================
  Future<void> _editServoBinding(int index) async {
    final l = AppLocalizations.of(context)!;
    final current = _cfg.servoBindings[index];
    final subsystemController = TextEditingController(
      text: current.subsystemId.toString(),
    );
    final servoPosController = TextEditingController(
      text: current.servoPos.toString(),
    );
    final channelController = TextEditingController(
      text: current.channel.toString(),
    );
    final appScopeController = TextEditingController(
      text: current.appScope.toString(),
    );

    var signal = current.signal;
    var enabled = current.enabled;

    final updated = await showDialog<ServoOutputBinding>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l.editServoMapping), // 使用新的国际化字段
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.hardwareConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subsystemController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.subsystemId,
                      helperText: l.subsystemIdHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: servoPosController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.servoPosition, // 使用新的国际化字段
                      helperText: l.servoPositionHint, // 使用新的国际化字段
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: channelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.channel,
                      helperText: l.channelServoHint, // 使用新的国际化字段
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l.signalConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DigitalSignalType>(
                    value: signal,
                    decoration: InputDecoration(
                      labelText: l.signal,
                      helperText: l.signalTypeHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DigitalSignalType.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_getSignalTypeName(context, e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => signal = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.enabled),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l.scopeConfig,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appScopeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.appScope,
                      helperText: l.appScopeHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
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
                  final servoPos = int.tryParse(servoPosController.text);
                  final channel = int.tryParse(channelController.text);
                  final appScope = int.tryParse(appScopeController.text);

                  if (subsystemId == null ||
                      servoPos == null ||
                      channel == null ||
                      appScope == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.enterValidInteger)),
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    ServoOutputBinding(
                      subsystemId: subsystemId,
                      servoPos: servoPos,
                      channel: channel,
                      signal: signal,
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
      _replaceServoBinding(index, updated);
    }
  }

  // ==========================================
  // 构建UI组件
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final l = AppLocalizations.of(context)!;
    final bool isEmpty = _cfg.bindings.isEmpty && _cfg.servoBindings.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.digitalOutputMapping),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.add),
            tooltip: l.add,
            onSelected: (value) {
              if (value == 0) {
                _addBinding();
              } else if (value == 1) {
                _addServoBinding();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.settings_input_component, size: 20),
                    const SizedBox(width: 8),
                    Text(l.addDigitalIo), // 使用国际化字段
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 20),
                    const SizedBox(width: 8),
                    Text(l.addServoMotor), // 使用国际化字段
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: l.validate,
            onPressed: _validate,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: l.save,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _buildBody(context, l, isEmpty),
    );
  }

  // 构建页面主体（包含配置缺失提示横幅）
  Widget _buildBody(BuildContext context, AppLocalizations l, bool isEmpty) {
    final cs = Theme.of(context).colorScheme;
    final configStatus = AppStateProvider.of(context).configStatus;
    final dioMissing =
        configStatus.isNotEmpty &&
        configStatus['has_digital_output_map'] != true;

    Widget content;
    if (isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_input_composite_outlined,
              size: 80,
              color: cs.secondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l.noMappingsHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 数字量 IO 映射区
          Text(
            l.digitalIoMappingSection,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_cfg.bindings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                l.noDigitalIoConfig,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ..._cfg.bindings.asMap().entries.map(
              (e) => _buildBindingCard(e.value, e.key),
            ),

          const SizedBox(height: 32),

          // 2. 伺服电机映射区
          Text(
            l.servoRoutingSection,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_cfg.servoBindings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                l.noServoConfig,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          else
            ..._cfg.servoBindings.asMap().entries.map(
              (e) => _buildServoBindingCard(e.value, e.key),
            ),
        ],
      );
    }
    if (!dioMissing) return content;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          color: cs.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: cs.onTertiaryContainer,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dioConfigMissing,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.dioConfigMissingHint,
                        style: TextStyle(color: cs.onTertiaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  // 构建数字量 IO 绑定卡片
  Widget _buildBindingCard(DigitalOutputBinding b, int index) {
    final l = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _editBinding(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: b.enabled
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: b.enabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    child: Text(
                      b.enabled ? l.enabled : l.disabled,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: b.enabled ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l.editMapping,
                    onPressed: () => _editBinding(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l.delete,
                    color: Colors.red,
                    onPressed: () => _confirmRemoveBinding(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                l.signal,
                _getSignalTypeName(context, b.signal),
                Icons.signal_cellular_alt,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                l.hardwareConfig,
                '${l.subsystemId}: ${b.subsystemId} | ${l.ioPosition}: ${b.ioPos}',
                Icons.developer_board,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                l.channel,
                'CH${b.channel} | ${l.bitIndex}: ${b.bitIndex} | ${l.appScope}: ${b.appScope}',
                Icons.tune,
              ),
              if (!b.activeHigh) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.swap_vert,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l.activeHigh}: ${l.disabled}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 构建伺服电机绑定卡片
  Widget _buildServoBindingCard(ServoOutputBinding b, int index) {
    final l = AppLocalizations.of(context)!;
    final scopeName = b.appScope == -1
        ? l.scopeBoth
        : (b.appScope == 0 ? l.scopeLiwOnly : l.scopeFillingOnly);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _editServoBinding(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: b.enabled
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: b.enabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.precision_manufacturing,
                          size: 14,
                          color: b.enabled ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          b.enabled ? l.enabled : l.disabled,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: b.enabled ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l.editMapping,
                    onPressed: () => _editServoBinding(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l.delete,
                    color: Colors.red,
                    onPressed: () => _confirmRemoveServoBinding(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                l.signal,
                _getSignalTypeName(context, b.signal),
                Icons.settings_ethernet,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                l.hardwareConfig,
                '${l.subsystemId}: ${b.subsystemId} | ${l.slavePositionPrefix}: ${b.servoPos}',
                Icons.developer_board,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                l.channel,
                '${l.channel} ${b.channel} | ${l.appScope}: $scopeName',
                Icons.apps,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
