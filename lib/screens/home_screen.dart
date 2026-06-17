import 'dart:async';
import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_state.dart';
import 'liw/liw_dashboard.dart';
import 'liw/liw_detail_screen.dart';
import 'filling/filling_dashboard.dart';
import 'filling/filling_detail_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/subsystem_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _setupBannerDismissed = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateProvider.of(context).initialize();
    });
    // 定期刷新所有子系统状态
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final state = AppStateProvider.of(context);
      for (final sub in state.subsystems) {
        state.refreshAppStatusForSubsystem(sub.subsystemId);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = AppStateProvider.of(context);

    // 没有配置子系统时显示提示横幅
    final noSubsystems =
        state.initialized && !state.hasConfiguredSubsystems;
    final showNoSubBanner = noSubsystems && !_setupBannerDismissed;

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
          // ── 未配置子系统提示横幅 ──────────────────────────────────────────
          if (showNoSubBanner)
            MaterialBanner(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.noSubsystemsSetupTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l.noSubsystemsSetupHint),
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
                        builder: (_) => const SubsystemConfigScreen()),
                  ).then((_) {
                    // 返回后刷新子系统列表
                    AppStateProvider.of(context).refreshSubsystems();
                  }),
                  child: Text(l.configureSubsystems),
                ),
              ],
            ),
          Expanded(
            child: !state.initialized
                ? const Center(child: CircularProgressIndicator())
                : noSubsystems
                    ? _buildNoSubsystemsPlaceholder(l, state)
                    : state.subsystems.length == 1
                        ? _buildSingleSubsystem(state)
                        : _buildMultiSubsystemGrid(state),
          ),
        ],
      ),
    );
  }

  /// 未配置子系统时的空状态提示
  Widget _buildNoSubsystemsPlaceholder(AppLocalizations l, AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            l.noSubsystemsSetupTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l.noSubsystemsSetupHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(l.configureSubsystems),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SubsystemConfigScreen()),
            ).then((_) => AppStateProvider.of(context).refreshSubsystems()),
          ),
        ],
      ),
    );
  }

  /// 单子系统：直接嵌入对应 Dashboard
  Widget _buildSingleSubsystem(AppState state) {
    final sub = state.subsystems.first;
    state.setActiveSubsystem(sub.subsystemId);
    if (sub.appType == 1) {
      return const FillingDashboard();
    }
    return const LiwDashboard();
  }

  /// 多子系统：网格展示每个子系统的概要卡片
  Widget _buildMultiSubsystemGrid(AppState state) {
    final subsystems = state.subsystems;
    final crossCount = subsystems.length <= 2 ? subsystems.length : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: subsystems.length,
      itemBuilder: (ctx, i) {
        final sub = subsystems[i];
        return _SubsystemSummaryCard(
          mapping: sub,
          onExpand: () {
            state.setActiveSubsystem(sub.subsystemId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => sub.appType == 1
                    ? const FillingDetailScreen()
                    : const LiwDetailScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Subsystem Summary Card
// ---------------------------------------------------------------------------

class _SubsystemSummaryCard extends StatelessWidget {
  final SubsystemMappingInfo mapping;
  final VoidCallback onExpand;

  const _SubsystemSummaryCard({
    required this.mapping,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = AppStateProvider.of(context);
    final cs = Theme.of(context).colorScheme;

    final weightData = state.getWeightData(mapping.scaleId);
    final appStatus = state.getAppStatus(mapping.subsystemId);

    final isLiw = mapping.appType == 0;
    final typeColor = isLiw ? Colors.blue : Colors.green;
    final typeIcon = isLiw ? Icons.trending_down : Icons.local_drink;
    final typeName = isLiw ? l.lossInWeight : l.filling;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部：类型图标 + 名称 + 展开按钮 ──────────────────────────
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mapping.description.isNotEmpty
                            ? mapping.description
                            : 'Sub ${mapping.subsystemId}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        typeName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: typeColor,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: l.expandDetail,
                  onPressed: onExpand,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 10),
            // ── 重量数据 ────────────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.netWeight,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                      ),
                      Text(
                        '${weightData.netWeight.toStringAsFixed(2)} kg',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.running,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: appStatus.isRunning
                              ? Colors.green.shade100
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          appStatus.isRunning ? l.running : l.idle,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: appStatus.isRunning
                                        ? Colors.green.shade700
                                        : cs.outline,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  if (appStatus.stateString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      appStatus.stateString,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // ── 底部：是否启用 ───────────────────────────────────────────────
            if (!mapping.enabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l.disabled,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

