import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../providers/app_state.dart';
import '../../l10n/app_localizations.dart';
import 'subsystem_config_screen.dart'; // === 引入以便复用 detectSlaveRole 和 SlaveRole ===

// === 提取一个顶层信号名称转换函数，方便主副页面共用 ===
String getDigitalSignalTypeName(
  BuildContext context,
  DigitalSignalType signal,
) {
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
      return l.bagClamp;
    default:
      return signal.name;
  }
}

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

  // === 分别保存过滤后的 IO 模块和 伺服 模块 ===
  List<EthercatSlaveInfo> _ioSlaves = [];
  List<EthercatSlaveInfo> _servoSlaves = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await WeighingPlatform.instance.getDigitalOutputMap();
    final slaves = await WeighingPlatform.instance.scanEthercatSlaves();

    setState(() {
      _cfg = c;
      // 1. 严格过滤：数字量输出仅可选择 SlaveRole.digitalIo 的设备
      _ioSlaves = slaves
          .where(
            (s) =>
                detectSlaveRole(s.vendorId, s.productCode) ==
                SlaveRole.digitalIo,
          )
          .toList();

      // 2. 伺服电机输出仅可选择 SlaveRole.servo 的设备
      _servoSlaves = slaves
          .where(
            (s) =>
                detectSlaveRole(s.vendorId, s.productCode) == SlaveRole.servo,
          )
          .toList();

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

  // ==================== 导航到数字量映射分配界面 ====================
  Future<void> _openPinAllocator(int? initialIoPos) async {
    final updatedCfg = await Navigator.of(context).push<DigitalOutputMapConfig>(
      MaterialPageRoute(
        builder: (ctx) => _DigitalIoAllocatorScreen(
          cfg: _cfg,
          ioSlaves: _ioSlaves,
          initialIoPos: initialIoPos,
        ),
      ),
    );

    if (updatedCfg != null) {
      setState(() {
        _cfg = updatedCfg;
      });
    }
  }

  // ==================== 主界面删除数字量配置 ====================
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
    if (confirmed == true) _removeBinding(index);
  }

  // ==================== 伺服相关操作 ====================
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
          content: Text(l.confirmDeleteServoMsg),
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
    if (confirmed == true) _removeServoBinding(index);
  }

  void _addServoBinding() {
    final list = List<ServoOutputBinding>.from(_cfg.servoBindings);
    list.add(
      ServoOutputBinding(
        subsystemId: 0,
        servoPos: _servoSlaves.isNotEmpty ? _servoSlaves.first.position : 0,
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

  Future<void> _editServoBinding(int index) async {
    final l = AppLocalizations.of(context)!;
    final current = _cfg.servoBindings[index];
    final subsystemController = TextEditingController(
      text: current.subsystemId.toString(),
    );
    final appScopeController = TextEditingController(
      text: current.appScope.toString(),
    );

    var servoPos = current.servoPos;
    var signal = current.signal;
    var enabled = current.enabled;

    final updated = await showDialog<ServoOutputBinding>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l.editServoMapping),
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
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: servoPos,
                    decoration: InputDecoration(
                      labelText: l.servoPosition,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _buildServoSlaveDropdownItems(servoPos),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => servoPos = v);
                    },
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
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: DigitalSignalType.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(getDigitalSignalTypeName(context, e)),
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
                  final appScope = int.tryParse(appScopeController.text);
                  if (subsystemId == null || appScope == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.enterValidInteger)),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    ServoOutputBinding(
                      subsystemId: subsystemId,
                      servoPos: servoPos,
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

    if (updated != null) _replaceServoBinding(index, updated);
  }

  List<DropdownMenuItem<int>> _buildServoSlaveDropdownItems(int currentValue) {
    final items = _servoSlaves.map((s) {
      final label = s.userAlias.isNotEmpty ? s.userAlias : s.description;
      return DropdownMenuItem<int>(
        value: s.position,
        child: Text('${s.position} - $label'),
      );
    }).toList();

    if (!_servoSlaves.any((s) => s.position == currentValue)) {
      items.insert(
        0,
        DropdownMenuItem<int>(
          value: currentValue,
          child: Text('$currentValue (未识别到该伺服)'),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.digitalOutputMapping),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 0)
                _openPinAllocator(null);
              else if (value == 1)
                _addServoBinding();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.settings_input_component, size: 20),
                    const SizedBox(width: 8),
                    Text(l.addDigitalIo),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 20),
                    const SizedBox(width: 8),
                    Text(l.addServoMotor),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
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
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _buildBody(context, l),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ================= 数字量输出 (IO位配置) 列表展示 =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.digitalIoMappingSection,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _openPinAllocator(null),
              icon: const Icon(Icons.add),
              label: Text(l.addDigitalIo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cfg.bindings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                '暂无数字量输出映射',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._cfg.bindings.asMap().entries.map(
            (e) => _buildBindingCard(e.value, e.key),
          ),

        const SizedBox(height: 32),

        // ================= 伺服输出映射 列表展示 =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.servoRoutingSection,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addServoBinding,
              icon: const Icon(Icons.add),
              label: Text(l.addServoMotor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cfg.servoBindings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                '暂无伺服输出映射',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._cfg.servoBindings.asMap().entries.map(
            (e) => _buildServoBindingCard(e.value, e.key),
          ),
      ],
    );
  }

  Widget _buildBindingCard(DigitalOutputBinding b, int index) {
    final l = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPinAllocator(b.ioPos), // 点击卡片打开分配器
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    b.enabled ? l.enabled : l.disabled,
                    style: TextStyle(
                      color: b.enabled ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openPinAllocator(b.ioPos),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _confirmRemoveBinding(index),
                  ),
                ],
              ),
              _buildInfoRow(
                l.signal,
                getDigitalSignalTypeName(context, b.signal),
                Icons.signal_cellular_alt,
              ),
              _buildInfoRow(
                '硬件引脚',
                '子系统ID: ${b.subsystemId} | 设备位置: ${b.ioPos} | 引脚位(Bit): ${b.bitIndex}',
                Icons.developer_board,
              ),
              _buildInfoRow(
                l.appScope,
                '${l.appScope}: ${b.appScope == -1 ? l.scopeBoth : (b.appScope == 0 ? l.scopeLiwOnly : l.scopeFillingOnly)}',
                Icons.apps,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServoBindingCard(ServoOutputBinding b, int index) {
    final l = AppLocalizations.of(context)!;
    final scopeName = b.appScope == -1
        ? l.scopeBoth
        : (b.appScope == 0 ? l.scopeLiwOnly : l.scopeFillingOnly);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _editServoBinding(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    b.enabled ? l.enabled : l.disabled,
                    style: TextStyle(
                      color: b.enabled ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editServoBinding(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _confirmRemoveServoBinding(index),
                  ),
                ],
              ),
              _buildInfoRow(
                l.signal,
                getDigitalSignalTypeName(context, b.signal),
                Icons.settings_ethernet,
              ),
              _buildInfoRow(
                l.hardwareConfig,
                '子系统ID: ${b.subsystemId} | 伺服位置: ${b.servoPos}',
                Icons.developer_board,
              ),
              _buildInfoRow(
                l.appScope,
                '${l.appScope}: $scopeName',
                Icons.apps,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text('$label: $value', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ==============================================================================
// === 专用的数字量引脚分配器页面（之前的 8位小圆灯界面）===
// ==============================================================================
// ==============================================================================
// === 专用的数字量引脚分配器页面（之前的 8位小圆灯界面）===
// ==============================================================================
class _DigitalIoAllocatorScreen extends StatefulWidget {
  final DigitalOutputMapConfig cfg;
  final List<EthercatSlaveInfo> ioSlaves;
  final int? initialIoPos;

  const _DigitalIoAllocatorScreen({
    required this.cfg,
    required this.ioSlaves,
    this.initialIoPos,
  });

  @override
  State<_DigitalIoAllocatorScreen> createState() =>
      _DigitalIoAllocatorScreenState();
}

class _DigitalIoAllocatorScreenState extends State<_DigitalIoAllocatorScreen> {
  late DigitalOutputMapConfig _localCfg;
  int? _selectedIoPos;
  final TextEditingController _subsystemController = TextEditingController(
    text: "0",
  );
  bool _saving = false; // === 新增：保存状态 ===

  @override
  void initState() {
    super.initState();
    // 浅拷贝外部的配置状态，内部修改完统一返回
    _localCfg = DigitalOutputMapConfig(
      version: widget.cfg.version,
      bindings: List.from(widget.cfg.bindings),
      servoBindings: widget.cfg.servoBindings,
    );
    _selectedIoPos =
        widget.initialIoPos ??
        (widget.ioSlaves.isNotEmpty ? widget.ioSlaves.first.position : null);
  }

  @override
  void dispose() {
    _subsystemController.dispose();
    super.dispose();
  }

  // === 新增：页面内直接保存的方法 ===
  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final ok = await WeighingPlatform.instance.updateDigitalOutputMap(
      _localCfg,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  // 构建下拉列表
  List<DropdownMenuItem<int>> _buildIoSlaveDropdownItems(int? currentValue) {
    final items = widget.ioSlaves.map((s) {
      final label = s.userAlias.isNotEmpty ? s.userAlias : s.description;
      return DropdownMenuItem<int>(
        value: s.position,
        child: Text('${s.position} - $label'),
      );
    }).toList();

    if (currentValue != null &&
        !widget.ioSlaves.any((s) => s.position == currentValue)) {
      items.insert(
        0,
        DropdownMenuItem<int>(
          value: currentValue,
          child: Text('$currentValue (模块不在线/配置异常)'),
        ),
      );
    }
    return items;
  }

  DigitalOutputBinding? _getBinding(int bitIndex) {
    if (_selectedIoPos == null) return null;
    try {
      return _localCfg.bindings.firstWhere(
        (b) => b.ioPos == _selectedIoPos && b.bitIndex == bitIndex,
      );
    } catch (e) {
      return null;
    }
  }

  void _updateBinding(
    int bitIndex,
    DigitalSignalType? newSignal,
    DigitalOutputBinding? existing,
  ) {
    if (_selectedIoPos == null) return;
    final list = List<DigitalOutputBinding>.from(_localCfg.bindings);
    list.removeWhere(
      (b) => b.ioPos == _selectedIoPos && b.bitIndex == bitIndex,
    );

    if (newSignal != null) {
      final subId =
          existing?.subsystemId ??
          (int.tryParse(_subsystemController.text) ?? 0);
      list.add(
        DigitalOutputBinding(
          subsystemId: subId,
          ioPos: _selectedIoPos!,
          bitIndex: bitIndex,
          signal: newSignal,
          activeHigh: existing?.activeHigh ?? true,
          enabled: existing?.enabled ?? true,
          appScope: existing?.appScope ?? -1,
        ),
      );
    }

    setState(() {
      _localCfg = DigitalOutputMapConfig(
        version: _localCfg.version,
        bindings: list,
        servoBindings: _localCfg.servoBindings,
      );
    });
  }

  Future<void> _editAdvancedSettings(DigitalOutputBinding current) async {
    final l = AppLocalizations.of(context)!;
    final subsystemController = TextEditingController(
      text: current.subsystemId.toString(),
    );
    final appScopeController = TextEditingController(
      text: current.appScope.toString(),
    );
    var activeHigh = current.activeHigh;
    var enabled = current.enabled;

    final updated = await showDialog<DigitalOutputBinding>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('${l.editMapping} - Bit ${current.bitIndex}'),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.activeHigh),
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
                  final appScope = int.tryParse(appScopeController.text);
                  if (subsystemId == null || appScope == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.enterValidInteger)),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    DigitalOutputBinding(
                      subsystemId: subsystemId,
                      ioPos: current.ioPos,
                      bitIndex: current.bitIndex,
                      signal: current.signal,
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
      final list = List<DigitalOutputBinding>.from(_localCfg.bindings);
      final index = list.indexWhere(
        (b) => b.ioPos == updated.ioPos && b.bitIndex == updated.bitIndex,
      );
      if (index != -1) {
        list[index] = updated;
        setState(() {
          _localCfg = DigitalOutputMapConfig(
            version: _localCfg.version,
            bindings: list,
            servoBindings: _localCfg.servoBindings,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('数字量输出端口分配'),
        actions: [
          // === 修改：去掉写死的 color: Colors.white，跟随主题颜色 ===
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save), // 去掉白色限制
            tooltip: l.save,
            onPressed: _saving ? null : _save,
          ),
          TextButton.icon(
            icon: const Icon(Icons.keyboard_return), // 去掉白色限制
            label: const Text('返回'), // 去掉白色限制
            onPressed: () => Navigator.of(context).pop(_localCfg),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: _selectedIoPos,
                          decoration: const InputDecoration(
                            labelText: '选择数字量 IO 模块 (EtherCAT Position)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _selectedIoPos == null
                              ? []
                              : _buildIoSlaveDropdownItems(_selectedIoPos!),
                          onChanged: (v) => setState(() => _selectedIoPos = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _subsystemController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '默认子系统 ID',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  if (widget.ioSlaves.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '未扫描到数字量 IO 模块\n(请在硬件配置页确认已扫描到 SlaveRole.digitalIo 的设备)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                      ),
                    )
                  else if (_selectedIoPos != null)
                    ...List.generate(8, (index) => _buildBitRow(index, l)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBitRow(int bitIndex, AppLocalizations l) {
    final existing = _getBinding(bitIndex);
    final isBound = existing != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBound ? Colors.green : Colors.grey.shade300,
              boxShadow: isBound
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$bitIndex',
              style: TextStyle(
                color: isBound ? Colors.white : Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DigitalSignalType?>(
                  value: existing?.signal,
                  hint: const Text('未分配 (None)'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<DigitalSignalType?>(
                      value: null,
                      child: Text('未分配 (None)'),
                    ),
                    ...DigitalSignalType.values.map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(getDigitalSignalTypeName(context, e)),
                      ),
                    ),
                  ],
                  onChanged: (val) => _updateBinding(bitIndex, val, existing),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isBound) ...[
            SizedBox(
              width: 100,
              child: Text(
                'SubSys: ${existing.subsystemId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              color: Theme.of(context).colorScheme.primary,
              tooltip: '高级设置 (使能, 高电平等)',
              onPressed: () => _editAdvancedSettings(existing),
            ),
          ] else
            const SizedBox(width: 148),
        ],
      ),
    );
  }
}
