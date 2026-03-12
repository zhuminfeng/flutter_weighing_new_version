import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import 'scale_settings_screen.dart';
import 'calibration_screen.dart';
import 'filter_screen.dart';
import 'app_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.tr('settings'))),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.science_outlined),
            title: const Text('模拟运行模式'),
            subtitle: Text(
              AppStateProvider.of(context).simulationMode
                  ? '已开启（使用样例数据）'
                  : '已关闭（连接真实设备）',
            ),
            value: AppStateProvider.of(context).simulationMode,
            onChanged: (v) async {
              await AppStateProvider.of(context).setSimulationMode(v);
            },
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.scale,
            title: l.tr('scaleSettings'),
            subtitle:
                '${l.tr('capacity')}, ${l.tr('division')}, ${l.tr('unit')}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScaleSettingsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.tune,
            title: l.tr('calibration'),
            subtitle:
                '${l.tr('calZero')}, ${l.tr('calSpan')}, ${l.tr('calStep')}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.filter_alt,
            title: l.tr('filter'),
            subtitle:
                '${l.tr('lowPassFilter')}, ${l.tr('notchFilter')}, ${l.tr('stability')}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FilterScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.settings_applications,
            title: l.tr('appSettings'),
            subtitle: '${l.tr('lossInWeight')} / ${l.tr('filling')}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            ),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.language,
            title: l.tr('language'),
            subtitle: l.tr(
              AppStateProvider.of(context).locale.languageCode == 'zh'
                  ? 'chinese'
                  : 'english',
            ),
            onTap: () {
              final current = AppStateProvider.of(context).locale;
              final next = current.languageCode == 'zh'
                  ? const Locale('en')
                  : const Locale('zh');
              AppStateProvider.localeChanger(context)(next);
              AppStateProvider.of(context).setLocale(next);
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
