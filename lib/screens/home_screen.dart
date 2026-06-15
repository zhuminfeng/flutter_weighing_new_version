import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_state.dart';
import 'liw/liw_dashboard.dart';
import 'filling/filling_dashboard.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _setupBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateProvider.of(context).initialize();
    });
  }

  /// Returns true when required hardware sections are missing from the config.
  bool _isSetupIncomplete(AppState state) {
    if (state.configStatus.isEmpty) return false;
    final hasDigitalOutput =
        state.configStatus['has_digital_output_map'] == true;
    // For ethercat mode, output and input_source slaves must also be present.
    // getInputMode() is not in AppState; use has_output_slaves as proxy
    // (it will be false in shmem mode too, but shmem users typically don't
    // need servo/IO output slaves, so only flag when digital output is also
    // missing).
    return !hasDigitalOutput;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = AppStateProvider.of(context);

    final showSetupBanner = state.initialized &&
        !_setupBannerDismissed &&
        _isSetupIncomplete(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          // Language toggle
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: (locale) {
              AppStateProvider.localeChanger(context)(locale);
              state.setLocale(locale);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: const Locale('zh'), child: Text(l.chinese)),
              PopupMenuItem(value: const Locale('en'), child: Text(l.english)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showSetupBanner)
            MaterialBanner(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.setupRequired,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 4),
                  Text(l.setupRequiredHint),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      setState(() => _setupBannerDismissed = true),
                  child: Text(l.dismiss),
                ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                  child: Text(l.goToSettings),
                ),
              ],
            ),
          Expanded(
            child: !state.initialized
                ? const Center(child: CircularProgressIndicator())
                : state.selectedAppType < 0
                    ? _buildAppSelector(l, state)
                    : state.selectedAppType == 0
                        ? const LiwDashboard()
                        : const FillingDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSelector(AppLocalizations l, AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.selectApp, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppCard(
                icon: Icons.trending_down,
                title: l.lossInWeight,
                color: Colors.blue,
                onTap: () => state.selectAppType(0),
              ),
              const SizedBox(width: 32),
              _AppCard(
                icon: Icons.local_drink,
                title: l.filling,
                color: Colors.green,
                onTap: () => state.selectAppType(1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(l.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AppCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
