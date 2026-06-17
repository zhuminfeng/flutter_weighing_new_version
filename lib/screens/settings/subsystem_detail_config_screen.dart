import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../material_recipe_screen.dart';
import 'app_settings_screen.dart';
import 'digital_output_settings_screen.dart';
import 'digital_input_settings_screen.dart';
import 'subsystem_config_screen.dart'
    show detectSlaveRole, slaveRoleIcon, slaveRoleColor, slaveRoleLabel;

/// 单个子系统的详细配置页面
class SubsystemDetailConfigScreen extends StatefulWidget {
  final SubsystemMappingInfo mapping;
  final String inputMode;
  final List<EthercatSlaveInfo> slaves;

  const SubsystemDetailConfigScreen({
    super.key,
    required this.mapping,
    required this.inputMode,
    required this.slaves,
  });

  @override
  State<SubsystemDetailConfigScreen> createState() =>
      _SubsystemDetailConfigScreenState();
}

class _SubsystemDetailConfigScreenState
    extends State<SubsystemDetailConfigScreen> {
  final WeighingPlatform _platform = WeighingPlatform.instance;

  late SubsystemMappingInfo _mapping;
  late TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mapping = widget.mapping;
    _nameController = TextEditingController(text: _mapping.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final l = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name == _mapping.description) return;

    setState(() => _saving = true);
    // Re-add with same ID/scaleId but new description
    final ok = await _platform.addSubsystemMapping(
      _mapping.subsystemId,
      name,
      scaleId: _mapping.scaleId,
      ioPosition: _mapping.ioPosition,
      appType: _mapping.appType,
    );
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) {
        setState(() => _mapping = _mapping.copyWith(description: name));
      }
    }
  }

  Future<void> _setAppType(int appType) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final ok = await _platform.setSubsystemAppType(
      _mapping.subsystemId,
      appType,
    );
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) {
        setState(() => _mapping = _mapping.copyWith(appType: appType));
      }
    }
  }

  Future<void> _toggleEnabled() async {
    final l = AppLocalizations.of(context)!;
    final newEnabled = !_mapping.enabled;
    setState(() => _saving = true);
    final ok = await _platform.setSubsystemEnabled(
      _mapping.subsystemId,
      newEnabled,
    );
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l.saveSuccess : l.saveFailedMsg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
      if (ok) {
        setState(() => _mapping = _mapping.copyWith(enabled: newEnabled));
      }
    }
  }

  /// 为该子系统分配 EtherCAT 称重设备
  Future<void> _assignWeighingDevice() async {
    final l = AppLocalizations.of(context)!;
    final weighingSlaves = widget.slaves
        .where(
          (s) => detectSlaveRole(s.vendorId, s.productCode).name == 'weighing',
        )
        .toList();

    if (weighingSlaves.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.noDevicesFound)));
      return;
    }

    final picked = await showDialog<EthercatSlaveInfo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.selectWeighingDevice),
        children: weighingSlaves
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s),
                child: ListTile(
                  leading: const Icon(Icons.scale),
                  title: Text(
                    s.userAlias.isNotEmpty ? s.userAlias : s.description,
                  ),
                  subtitle: Text('${l.position}: ${s.position}'),
                ),
              ),
            )
            .toList(),
      ),
    );

    if (picked == null || !mounted) return;
    final ok = await _platform.updateSubsystemMapping(
      _mapping.subsystemId,
      picked.position,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.mappingUpdated
                : AppLocalizations.of(context)!.mappingFailed,
          ),
        ),
      );
      if (ok) {
        setState(() => _mapping = _mapping.copyWith(scaleId: picked.position));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isLiw = _mapping.appType == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mapping.description.isNotEmpty
              ? _mapping.description
              : 'Subsystem ${_mapping.subsystemId}',
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 名称 ──────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.label,
            title: l.subsystemName,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: l.subsystemDescHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _saveName,
                  child: Text(l.save),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 应用类型 ───────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.category,
            title: l.appType,
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: Text(l.lossInWeight),
                    subtitle: const Text('LIW'),
                    value: 0,
                    groupValue: _mapping.appType,
                    onChanged: _saving ? null : (v) => _setAppType(v!),
                    dense: true,
                    activeColor: Colors.blue,
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: Text(l.filling),
                    subtitle: null,
                    value: 1,
                    groupValue: _mapping.appType,
                    onChanged: _saving ? null : (v) => _setAppType(v!),
                    dense: true,
                    activeColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 输入模式 ──────────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(
                widget.inputMode == 'ethercat'
                    ? Icons.device_hub
                    : Icons.memory,
                color: cs.primary,
              ),
              title: Text(l.inputModeLabel),
              subtitle: Text(
                widget.inputMode == 'ethercat' ? l.ethercatMode : l.shmemMode,
              ),
              trailing: const Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 12),

          // ── EtherCAT 称重设备（仅 ethercat 模式）────────────────────────
          if (widget.inputMode == 'ethercat') ...[
            _SectionCard(
              icon: Icons.scale,
              title: l.slaveRoleWeighing,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.scale),
                title: Text(
                  _mapping.scaleId > 0
                      ? _findSlaveLabel(_mapping.scaleId, l)
                      : l.noDeviceAssigned,
                  style: TextStyle(
                    color: _mapping.scaleId > 0 ? null : cs.outline,
                  ),
                ),
                subtitle: _mapping.scaleId > 0
                    ? Text('${l.position}: ${_mapping.scaleId}')
                    : null,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.link),
                  label: Text(l.selectWeighingDevice),
                  onPressed: _assignWeighingDevice,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // EtherCAT 设备列表（IO/伺服）
            if (widget.slaves.isNotEmpty) ...[
              _SectionCard(
                icon: Icons.device_hub,
                title: l.ethercatDevices,
                child: Column(
                  children: widget.slaves
                      .map((s) => _EthercatSlaveTile(slave: s))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // ── 配方设置 ──────────────────────────────────────────────────────
          _NavigationTile(
            icon: Icons.science,
            title: l.materialRecipeTitle,
            subtitle: l.materialRecipeSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MaterialRecipeScreen(
                  appType: _mapping.appType,
                  subsystemId: _mapping.subsystemId,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 应用参数设置 ──────────────────────────────────────────────────
          _NavigationTile(
            icon: Icons.settings_applications,
            title: l.appSettings,
            subtitle: isLiw ? l.lossInWeight : l.filling,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AppSettingsScreen(subsystemId: _mapping.subsystemId),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 离散输出配置 ───────────────────────────────────────────────────
          _NavigationTile(
            icon: Icons.power,
            title: l.digitalOutputMapping,
            subtitle: l.doBitRouting,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DigitalOutputSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 离散输入配置 ──────────────────────────────────────────────────
          _NavigationTile(
            icon: Icons.input,
            title: l.digitalInputMapping,
            subtitle: l.diInputRouting,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DigitalInputSettingsScreen(
                  subsystemId: _mapping.subsystemId,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 启用/禁用 ──────────────────────────────────────────────────────
          Card(
            color: _mapping.enabled ? cs.primaryContainer : cs.errorContainer,
            child: SwitchListTile(
              secondary: Icon(
                _mapping.enabled ? Icons.check_circle : Icons.cancel,
                color: _mapping.enabled
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
              ),
              title: Text(
                _mapping.enabled ? l.enabled : l.disabled,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _mapping.enabled
                      ? cs.onPrimaryContainer
                      : cs.onErrorContainer,
                ),
              ),
              subtitle: Text(
                _mapping.enabled
                    ? l.subsystemEnabledHint
                    : l.subsystemDisabledHint,
                style: TextStyle(
                  color: _mapping.enabled
                      ? cs.onPrimaryContainer
                      : cs.onErrorContainer,
                ),
              ),
              value: _mapping.enabled,
              onChanged: _saving ? null : (_) => _toggleEnabled(),
            ),
          ),
        ],
      ),
    );
  }

  String _findSlaveLabel(int position, AppLocalizations l) {
    for (final s in widget.slaves) {
      if (s.position == position) {
        return s.userAlias.isNotEmpty
            ? s.userAlias
            : s.description.isNotEmpty
            ? s.description
            : 'Slave #$position';
      }
    }
    return 'Slave #$position';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EthercatSlaveTile extends StatelessWidget {
  final EthercatSlaveInfo slave;

  const _EthercatSlaveTile({required this.slave});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final role = detectSlaveRole(slave.vendorId, slave.productCode);
    final roleColor = slaveRoleColor(role, cs);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: roleColor.withOpacity(0.15),
        child: Icon(slaveRoleIcon(role), color: roleColor, size: 16),
      ),
      title: Text(
        slave.userAlias.isNotEmpty
            ? slave.userAlias
            : slave.description.isNotEmpty
            ? slave.description
            : 'Slave #${slave.position}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${l.position}: ${slave.position}  ${slaveRoleLabel(role, l)}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.outline),
      ),
      dense: true,
    );
  }
}
