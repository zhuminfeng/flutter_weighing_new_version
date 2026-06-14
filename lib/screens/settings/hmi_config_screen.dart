import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helper: detect slave role from vendor/product codes
// ---------------------------------------------------------------------------
enum _SlaveRole { weighing, digitalIo, servo, unknown }

_SlaveRole _detectRole(int vendorId, int productCode) {
  // AD2020EB 称重仪表
  if (vendorId == 0x00001071 && productCode == 0x00000001) {
    return _SlaveRole.weighing;
  }
  // EC3A-IO1632 数字IO
  if (vendorId == 0x00000b95 && productCode == 0x00001101) {
    return _SlaveRole.digitalIo;
  }
  // InoSV630N 伺服
  if (vendorId == 0x00100000 && productCode == 0x000c0112) {
    return _SlaveRole.servo;
  }
  return _SlaveRole.unknown;
}

IconData _roleIcon(_SlaveRole role) {
  switch (role) {
    case _SlaveRole.weighing:
      return Icons.scale;
    case _SlaveRole.digitalIo:
      return Icons.grid_on;
    case _SlaveRole.servo:
      return Icons.electric_bolt;
    case _SlaveRole.unknown:
      return Icons.device_unknown;
  }
}

Color _roleColor(_SlaveRole role, ColorScheme cs) {
  switch (role) {
    case _SlaveRole.weighing:
      return cs.primary;
    case _SlaveRole.digitalIo:
      return cs.tertiary;
    case _SlaveRole.servo:
      return cs.secondary;
    case _SlaveRole.unknown:
      return cs.outline;
  }
}

String _roleLabel(_SlaveRole role, AppLocalizations l) {
  switch (role) {
    case _SlaveRole.weighing:
      return l.slaveRoleWeighing;
    case _SlaveRole.digitalIo:
      return l.slaveRoleDigitalIO;
    case _SlaveRole.servo:
      return l.slaveRoleServo;
    case _SlaveRole.unknown:
      return l.slaveRoleUnknown;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class HmiConfigScreen extends StatefulWidget {
  const HmiConfigScreen({super.key});

  @override
  State<HmiConfigScreen> createState() => _HmiConfigScreenState();
}

class _HmiConfigScreenState extends State<HmiConfigScreen> {
  final WeighingPlatform _platform = WeighingPlatform.instance;

  bool _loading = true;
  bool _scanning = false;
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

  // Show dialog to edit alias
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
      final ok = await _platform.updateSlaveAlias(slave.position, controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? l.aliasUpdated : l.aliasFailed)),
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

  // Show dialog to assign slave to a subsystem (ethercat mode)
  Future<void> _assignToSubsystem(EthercatSlaveInfo slave) async {
    final l = AppLocalizations.of(context)!;
    if (_mappings.isEmpty) return;
    final selected = await showDialog<SubsystemMappingInfo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.assignToSubsystem),
        children: _mappings
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, m),
                  child: ListTile(
                    leading: const Icon(Icons.widgets),
                    title: Text(m.description.isNotEmpty
                        ? m.description
                        : 'Subsystem ${m.subsystemId}'),
                    subtitle: Text('ID: ${m.subsystemId}'),
                  ),
                ))
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      final ok = await _platform.updateSubsystemMapping(
          selected.subsystemId, slave.position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? l.mappingUpdated : l.mappingFailed)),
        );
        if (ok) {
          setState(() {
            _mappings = _mappings.map((m) {
              if (m.subsystemId == selected.subsystemId) {
                return m.copyWith(scaleId: slave.position);
              }
              return m;
            }).toList();
          });
        }
      }
    }
  }

  // Update subsystem channel (shmem mode)
  Future<void> _updateChannel(SubsystemMappingInfo mapping, int channel) async {
    final l = AppLocalizations.of(context)!;
    final ok =
        await _platform.updateSubsystemMapping(mapping.subsystemId, channel);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? l.mappingUpdated : l.mappingFailed)),
      );
      if (ok) {
        setState(() {
          _mappings = _mappings.map((m) {
            if (m.subsystemId == mapping.subsystemId) {
              return m.copyWith(scaleId: channel);
            }
            return m;
          }).toList();
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.hmiConfig),
        actions: [
          if (_inputMode == 'ethercat')
            _scanning
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: l.scanDevices,
                    onPressed: _doScan,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Input Mode Banner ──────────────────────────────────
                  _InputModeBanner(
                    inputMode: _inputMode,
                    slaveCount: _slaves.length,
                  ),
                  const SizedBox(height: 16),

                  // ── EtherCAT Devices Section ───────────────────────────
                  if (_inputMode == 'ethercat') ...[
                    _SectionHeader(
                      icon: Icons.device_hub,
                      title: l.ethercatDevices,
                      trailing: _slaves.isNotEmpty
                          ? Chip(
                              avatar: const Icon(Icons.sensors, size: 16),
                              label: Text(
                                  l.deviceDiscovered(_slaves.length)),
                            )
                          : null,
                    ),
                    if (_slaves.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off,
                                    size: 48, color: cs.outline),
                                const SizedBox(height: 8),
                                Text(l.noDevicesFound,
                                    style: TextStyle(color: cs.outline)),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  icon: const Icon(Icons.search),
                                  label: Text(l.scanDevices),
                                  onPressed: _scanning ? null : _doScan,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._slaves
                          .map((s) => _SlaveCard(
                                slave: s,
                                onEditAlias: () => _editAlias(s),
                                onAssign: () => _assignToSubsystem(s),
                              ))
                          .toList(),
                    const SizedBox(height: 16),
                  ],

                  // ── Subsystem Scale Binding Section ────────────────────
                  _SectionHeader(
                    icon: Icons.widgets,
                    title: l.subsystemScaleBinding,
                  ),
                  if (_mappings.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(l.noDevicesFound,
                              style: TextStyle(color: cs.outline)),
                        ),
                      ),
                    )
                  else
                    ..._mappings
                        .map((m) => _SubsystemMappingCard(
                              mapping: m,
                              inputMode: _inputMode,
                              slaves: _slaves,
                              onChannelChanged: (ch) =>
                                  _updateChannel(m, ch),
                              onSelectDevice: () async {
                                // In ethercat mode: pick from weighing slaves
                                final weighing = _slaves
                                    .where((s) =>
                                        _detectRole(s.vendorId,
                                            s.productCode) ==
                                        _SlaveRole.weighing)
                                    .toList();
                                if (weighing.isEmpty) return;
                                final picked =
                                    await showDialog<EthercatSlaveInfo>(
                                  context: context,
                                  builder: (ctx) => SimpleDialog(
                                    title: Text(
                                        AppLocalizations.of(context)!
                                            .selectWeighingDevice),
                                    children: weighing
                                        .map((s) => SimpleDialogOption(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, s),
                                              child: ListTile(
                                                leading: const Icon(
                                                    Icons.scale),
                                                title: Text(s.userAlias
                                                        .isNotEmpty
                                                    ? s.userAlias
                                                    : s.description),
                                                subtitle: Text(
                                                    'Pos: ${s.position}'),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                );
                                if (picked != null) {
                                  await _updateChannel(m, picked.position);
                                }
                              },
                            ))
                        .toList(),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _InputModeBanner extends StatelessWidget {
  final String inputMode;
  final int slaveCount;

  const _InputModeBanner(
      {required this.inputMode, required this.slaveCount});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isEthercat = inputMode == 'ethercat';

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
                            : cs.onSecondaryContainer),
                  ),
                  Text(
                    isEthercat ? l.ethercatMode : l.shmemMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isEthercat
                            ? cs.onPrimaryContainer
                            : cs.onSecondaryContainer),
                  ),
                ],
              ),
            ),
            if (isEthercat && slaveCount > 0)
              Chip(
                avatar: const Icon(Icons.sensors, size: 16),
                label: Text('$slaveCount'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});

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

class _SlaveCard extends StatelessWidget {
  final EthercatSlaveInfo slave;
  final VoidCallback onEditAlias;
  final VoidCallback onAssign;

  const _SlaveCard({
    required this.slave,
    required this.onEditAlias,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final role = _detectRole(slave.vendorId, slave.productCode);
    final roleColor = _roleColor(role, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Role icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_roleIcon(role), color: roleColor, size: 26),
            ),
            const SizedBox(width: 12),
            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slave.userAlias.isNotEmpty
                              ? slave.userAlias
                              : slave.description.isNotEmpty
                                  ? slave.description
                                  : 'Slave #${slave.position}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Chip(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        label: Text(_roleLabel(role, l),
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor: roleColor.withOpacity(0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l.position}: ${slave.position}  '
                    '${l.vendorId}: 0x${slave.vendorId.toRadixString(16).padLeft(8, '0')}  '
                    '${l.productCode}: 0x${slave.productCode.toRadixString(16).padLeft(8, '0')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                  if (slave.description.isNotEmpty &&
                      slave.userAlias.isNotEmpty)
                    Text(slave.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.outline)),
                ],
              ),
            ),
            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: l.deviceAlias,
                  onPressed: onEditAlias,
                ),
                IconButton(
                  icon: const Icon(Icons.link, size: 20),
                  tooltip: l.assignToSubsystem,
                  onPressed: onAssign,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubsystemMappingCard extends StatelessWidget {
  final SubsystemMappingInfo mapping;
  final String inputMode;
  final List<EthercatSlaveInfo> slaves;
  final ValueChanged<int> onChannelChanged;
  final VoidCallback onSelectDevice;

  const _SubsystemMappingCard({
    required this.mapping,
    required this.inputMode,
    required this.slaves,
    required this.onChannelChanged,
    required this.onSelectDevice,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${mapping.subsystemId}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mapping.description.isNotEmpty
                        ? mapping.description
                        : 'Subsystem ${mapping.subsystemId}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (inputMode == 'shmem')
                    // shmem: SegmentedButton for channel 0/1
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      segments: [
                        ButtonSegment(
                            value: 0,
                            label: Text(l.channel0),
                            icon: const Icon(Icons.looks_one, size: 16)),
                        ButtonSegment(
                            value: 1,
                            label: Text(l.channel1),
                            icon: const Icon(Icons.looks_two, size: 16)),
                      ],
                      selected: {mapping.scaleId.clamp(0, 1)},
                      onSelectionChanged: (s) => onChannelChanged(s.first),
                    )
                  else
                    // ethercat: show assigned slave or "not configured"
                    _EthercatSlaveSelector(
                      currentScaleId: mapping.scaleId,
                      slaves: slaves,
                      onTap: onSelectDevice,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EthercatSlaveSelector extends StatelessWidget {
  final int currentScaleId;
  final List<EthercatSlaveInfo> slaves;
  final VoidCallback onTap;

  const _EthercatSlaveSelector({
    required this.currentScaleId,
    required this.slaves,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final assigned = slaves.where((s) => s.position == currentScaleId).firstOrNull;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              assigned != null ? Icons.scale : Icons.link_off,
              size: 16,
              color: assigned != null ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 6),
            Text(
              assigned != null
                  ? (assigned.userAlias.isNotEmpty
                      ? assigned.userAlias
                      : assigned.description.isNotEmpty
                          ? assigned.description
                          : 'Pos: ${assigned.position}')
                  : l.noDeviceAssigned,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: assigned != null ? cs.primary : cs.outline),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
