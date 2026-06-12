import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import 'scale_settings_screen.dart';
import 'calibration_screen.dart';
import 'filter_screen.dart';
import 'app_settings_screen.dart';
import 'digital_output_settings_screen.dart'; // 新增
import 'ethercat_device_settings_screen.dart';
import 'signal_analyzer_screen.dart';
import '../central/central_controller_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.scale,
            title: l.scaleSettings,
            subtitle: '${l.capacity}, ${l.division}, ${l.unit}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScaleSettingsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.tune,
            title: l.calibration,
            subtitle: '${l.calZero}, ${l.calSpan}, ${l.calStep}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.filter_alt,
            title: l.filter,
            subtitle: '${l.lowPassFilter}, ${l.notchFilter}, ${l.stability}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FilterScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.settings_applications,
            title: l.appSettings,
            subtitle: '${l.lossInWeight} / ${l.filling}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            ),
          ),

          // 新增：Digital Output Mapping 入口
          _SettingsTile(
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
          _SettingsTile(
            icon: Icons.device_hub,
            title: 'EtherCAT设备配置',
            subtitle: '自动识别设备并分配子系统',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EthercatDeviceSettingsScreen(),
              ),
            ),
          ),

          //中央控制器
          _SettingsTile(
            icon: Icons.dashboard,
            title: '中央控制器',
            subtitle: '多机联动 / 配方管理',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CentralControllerScreen(),
              ),
            ),
          ),

          const Divider(),
          _SettingsTile(
            icon: Icons.analytics,
            title: l.signalAnalyzer,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignalAnalyzerScreen()),
            ),
          ),

          const Divider(),
          _SettingsTile(
            icon: Icons.language,
            title: l.language,
            subtitle: AppStateProvider.of(context).locale.languageCode == 'zh'
                ? l.chinese
                : l.english,
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
