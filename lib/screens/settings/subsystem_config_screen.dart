import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import 'subsystem_detail_config_screen.dart';

// ---------------------------------------------------------------------------
// Helper: detect slave role from vendor/product codes
// ---------------------------------------------------------------------------
enum SlaveRole { weighing, digitalIo, servo, unknown }

SlaveRole detectSlaveRole(int vendorId, int productCode) {
  if (vendorId == 0x00001071 && productCode == 0x00000001) {
    return SlaveRole.weighing;
  }
  if (vendorId == 0x00000b95 && productCode == 0x00001101) {
    return SlaveRole.digitalIo;
  }
  if (vendorId == 0x00100000 && productCode == 0x000c0112) {
    return SlaveRole.servo;
  }
  return SlaveRole.unknown;
}

IconData slaveRoleIcon(SlaveRole role) {
  switch (role) {
    case SlaveRole.weighing:
      return Icons.scale;
    case SlaveRole.digitalIo:
      return Icons.grid_on;
    case SlaveRole.servo:
      return Icons.electric_bolt;
    case SlaveRole.unknown:
      return Icons.device_unknown;
  }
}

Color slaveRoleColor(SlaveRole role, ColorScheme cs) {
  switch (role) {
    case SlaveRole.weighing:
      return cs.primary;
    case SlaveRole.digitalIo:
      return cs.tertiary;
    case SlaveRole.servo:
      return cs.secondary;
    case SlaveRole.unknown:
      return cs.outline;
  }
}

String slaveRoleLabel(SlaveRole role, AppLocalizations l) {
  switch (role) {
    case SlaveRole.weighing:
      return l.slaveRoleWeighing;
    case SlaveRole.digitalIo:
      return l.slaveRoleDigitalIO;
    case SlaveRole.servo:
      return l.slaveRoleServo;
    case SlaveRole.unknown:
      return l.slaveRoleUnknown;
  }
}

// ---------------------------------------------------------------------------
// Subsystem Config Screen (list of subsystems)
// ---------------------------------------------------------------------------
class SubsystemConfigScreen extends StatefulWidget {
  const SubsystemConfigScreen({super.key});

  @override
  State<SubsystemConfigScreen> createState() => _SubsystemConfigScreenState();
}

class _SubsystemConfigScreenState extends State<SubsystemConfigScreen> {
  final WeighingPlatform _platform = WeighingPlatform.instance;

  bool _loading = true;
  bool _scanning = false;
  bool _applying = false;
  String _inputMode = 'shmem';
  List<EthercatSlaveInfo> _slaves = [];
  List<SubsystemMappingInfo> _mappings = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    final mode = await _platform.getInputMode();
    final mappings = await _platform.getSubsystemMappings();
    setState(() {
      _inputMode = mode;
      _mappings = mappings;
      _loading = false;
    });
  }

  Future<void> _doScan() async {
    setState(() => _scanning = true);
    final slaves = await _platform.scanEthercatSlaves();
    setState(() {
      _slaves = slaves;
      _scanning = false;
    });
  }

  // Show dialog to add a new subsystem
  Future<void> _addSubsystem() async {
    final l = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    int selectedAppType = 0; // 0=LIW, 1=Filling

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.addSubsystemTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l.subsystemName,
                  hintText: l.subsystemDescHint,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text(l.appType, style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: Text(l.lossInWeight),
                      value: 0,
                      groupValue: selectedAppType,
                      onChanged: (v) =>
                          setDialogState(() => selectedAppType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: Text(l.filling),
                      value: 1,
                      groupValue: selectedAppType,
                      onChanged: (v) =>
                          setDialogState(() => selectedAppType = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.addSubsystem),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    // Auto-assign ID = max existing + 1
    final newId = _mappings.isEmpty
        ? 0
        : _mappings.map((m) => m.subsystemId).reduce((a, b) => a > b ? a : b) +
              1;

    final ok = await _platform.addSubsystemMapping(
      newId,
      name,
      appType: selectedAppType,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.addSuccess
                : AppLocalizations.of(context)!.addFailed,
          ),
        ),
      );
      if (ok) await _loadInitialData();
    }
  }

  // Remove a subsystem mapping
  Future<void> _removeSubsystem(SubsystemMappingInfo mapping) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeSubsystem),
        content: Text(l.confirmRemoveSubsystem(mapping.subsystemId)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _platform.removeSubsystemMapping(mapping.subsystemId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? l.removeSuccess : l.removeFailed)),
      );
      if (ok) await _loadInitialData();
    }
  }

  // Toggle enabled with conflict check
  Future<void> _toggleEnabled(SubsystemMappingInfo mapping) async {
    final l = AppLocalizations.of(context)!;
    final newEnabled = !mapping.enabled;

    // If enabling in ethercat mode, check for scale_id conflicts
    if (newEnabled && _inputMode == 'ethercat' && mapping.scaleId > 0) {
      final conflicts = _mappings
          .where(
            (m) =>
                m.subsystemId != mapping.subsystemId &&
                m.scaleId == mapping.scaleId &&
                m.enabled,
          )
          .toList();
      if (conflicts.isNotEmpty) {
        final conflictNames = conflicts
            .map(
              (m) => m.description.isNotEmpty
                  ? m.description
                  : 'Sub ${m.subsystemId}',
            )
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.ethercatConflictError(conflictNames)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    final ok = await _platform.setSubsystemEnabled(
      mapping.subsystemId,
      newEnabled,
    );
    if (mounted) {
      if (ok) {
        setState(() {
          _mappings = _mappings.map((m) {
            if (m.subsystemId == mapping.subsystemId) {
              return m.copyWith(enabled: newEnabled);
            }
            return m;
          }).toList();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.saveFailedMsg)));
      }
    }
  }

  // Apply config: reinitialize
  Future<void> _applyConfig() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.applyConfig),
        content: Text(l.applyConfigConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _applying = true);
    try {
      final state = AppStateProvider.of(context);
      await state.reinitialize();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.applyConfigSuccess)));
        await _loadInitialData();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.applyConfigFailed)));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.subsystemConfigTitle),
        actions: [
          if (_inputMode == 'ethercat') ...[
            _scanning
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: l.scanDevices,
                    onPressed: _doScan,
                  ),
          ],
          _applying
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: l.applyConfig,
                  onPressed: _applyConfig,
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubsystem,
        tooltip: l.addSubsystem,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── 输入模式横幅 ──────────────────────────────────────────
                  _buildInputModeBanner(l, cs),
                  const SizedBox(height: 16),

                  // ── EtherCAT 设备扫描结果 ──────────────────────────────────
                  if (_inputMode == 'ethercat' && _slaves.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.device_hub,
                      title: l.ethercatDevices,
                      trailing: Chip(
                        avatar: const Icon(Icons.sensors, size: 16),
                        label: Text(l.deviceDiscovered(_slaves.length)),
                      ),
                    ),
                    ..._slaves.map(
                      (s) => _SlaveInfoTile(
                        slave: s,
                        onEditAlias: () => _editAlias(s),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 子系统列表 ─────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.widgets,
                    title: l.subsystemScaleBinding,
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.addSubsystem),
                      onPressed: _addSubsystem,
                    ),
                  ),

                  if (_mappings.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.widgets_outlined,
                                size: 48,
                                color: cs.outline,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.noSubsystemsConfigured,
                                style: TextStyle(color: cs.outline),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(l.addSubsystem),
                                onPressed: _addSubsystem,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ..._mappings.map(
                      (m) => _SubsystemCard(
                        mapping: m,
                        inputMode: _inputMode,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubsystemDetailConfigScreen(
                                mapping: m,
                                inputMode: _inputMode,
                                slaves: _slaves,
                              ),
                            ),
                          );
                          await _loadInitialData();
                        },
                        onToggleEnabled: () => _toggleEnabled(m),
                        onRemove: () => _removeSubsystem(m),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildInputModeBanner(AppLocalizations l, ColorScheme cs) {
    final isEthercat = _inputMode == 'ethercat';
    return Card(
      color: isEthercat ? cs.primaryContainer : cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isEthercat ? Icons.device_hub : Icons.memory,
              size: 32,
              color: isEthercat
                  ? cs.onPrimaryContainer
                  : cs.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.inputModeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isEthercat
                          ? cs.onPrimaryContainer
                          : cs.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    isEthercat ? l.ethercatMode : l.shmemMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isEthercat
                          ? cs.onPrimaryContainer
                          : cs.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (isEthercat)
              _scanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: Text(l.scanDevices),
                      onPressed: _doScan,
                    ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAlias(EthercatSlaveInfo slave) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: slave.userAlias);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deviceAlias),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l.deviceAliasHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.saveAlias),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await _platform.updateSlaveAlias(
        slave.position,
        controller.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? AppLocalizations.of(context)!.aliasUpdated
                  : AppLocalizations.of(context)!.aliasFailed,
            ),
          ),
        );
        if (ok) {
          setState(() {
            _slaves = _slaves.map((s) {
              if (s.position == slave.position) {
                return s.copyWith(userAlias: controller.text.trim());
              }
              return s;
            }).toList();
          });
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SlaveInfoTile extends StatelessWidget {
  final EthercatSlaveInfo slave;
  final VoidCallback onEditAlias;

  const _SlaveInfoTile({required this.slave, required this.onEditAlias});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final role = detectSlaveRole(slave.vendorId, slave.productCode);
    final roleColor = slaveRoleColor(role, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Icon(slaveRoleIcon(role), color: roleColor, size: 20),
        ),
        title: Text(
          slave.userAlias.isNotEmpty
              ? slave.userAlias
              : slave.description.isNotEmpty
              ? slave.description
              : 'Slave #${slave.position}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${l.position}: ${slave.position}  '
          'VID: 0x${slave.vendorId.toRadixString(16).padLeft(8, "0")}  '
          'PID: 0x${slave.productCode.toRadixString(16).padLeft(8, "0")}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                slaveRoleLabel(role, l),
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: roleColor.withOpacity(0.15),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: l.deviceAlias,
              onPressed: onEditAlias,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubsystemCard extends StatelessWidget {
  final SubsystemMappingInfo mapping;
  final String inputMode;
  final VoidCallback onTap;
  final VoidCallback onToggleEnabled;
  final VoidCallback onRemove;

  const _SubsystemCard({
    required this.mapping,
    required this.inputMode,
    required this.onTap,
    required this.onToggleEnabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isLiw = mapping.appType == 0;
    final typeColor = isLiw ? Colors.blue : Colors.green;
    final typeIcon = isLiw ? Icons.trending_down : Icons.local_drink;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // App type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 26),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapping.description.isNotEmpty
                          ? mapping.description
                          : 'Subsystem ${mapping.subsystemId}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isLiw ? l.lossInWeight : l.filling,
                            style: TextStyle(
                              fontSize: 11,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (inputMode == 'ethercat')
                          Text(
                            '${l.position}: ${mapping.scaleId}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: cs.outline),
                          )
                        else
                          Text(
                            '${l.channel}: ${mapping.scaleId}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: cs.outline),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Enabled toggle + menu
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch(
                    value: mapping.enabled,
                    onChanged: (_) => onToggleEnabled(),
                  ),
                  Text(
                    mapping.enabled ? l.enabled : l.disabled,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mapping.enabled ? Colors.green : cs.outline,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: l.removeSubsystem,
                color: cs.error,
                onPressed: onRemove,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
