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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateProvider.of(context).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('appTitle')),
        actions: [
          // Language toggle
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: (locale) {
              AppStateProvider.localeChanger(context)(locale);
              state.setLocale(locale);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: const Locale('zh'),
                child: Text(l.tr('chinese')),
              ),
              PopupMenuItem(
                value: const Locale('en'),
                child: Text(l.tr('english')),
              ),
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
      body: !state.initialized
          ? const Center(child: CircularProgressIndicator())
          : state.selectedAppType < 0
          ? _buildAppSelector(l, state)
          : state.selectedAppType == 0
          ? const LiwDashboard()
          : const FillingDashboard(),
    );
  }

  Widget _buildAppSelector(AppLocalizations l, AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.tr('selectApp'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppCard(
                icon: Icons.trending_down,
                title: l.tr('lossInWeight'),
                color: Colors.blue,
                onTap: () => state.selectAppType(0),
              ),
              const SizedBox(width: 32),
              _AppCard(
                icon: Icons.local_drink,
                title: l.tr('filling'),
                color: Colors.green,
                onTap: () => state.selectAppType(1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(l.tr('settings')),
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
