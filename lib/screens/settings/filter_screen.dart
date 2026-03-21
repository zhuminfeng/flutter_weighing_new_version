import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final int _scaleId = 0;
  FilterStabilityConfig _config = const FilterStabilityConfig();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _config = await WeighingPlatform.instance.getFilterStability(_scaleId);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await WeighingPlatform.instance.updateFilterStability(_scaleId, _config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.save)),
      );
    }
  }

  FilterStabilityConfig _update({
    int? lowPassLevel,
    bool? notchEnabled,
    double? notchFrequency,
    bool? adaptiveEnabled,
    double? adaptiveRangeD,
    double? motionRangeD,
    double? motionDetectTime,
    double? stabilityTimeout,
  }) {
    return FilterStabilityConfig(
      lowPassLevel: lowPassLevel ?? _config.lowPassLevel,
      notchEnabled: notchEnabled ?? _config.notchEnabled,
      notchFrequency: notchFrequency ?? _config.notchFrequency,
      adaptiveEnabled: adaptiveEnabled ?? _config.adaptiveEnabled,
      adaptiveRangeD: adaptiveRangeD ?? _config.adaptiveRangeD,
      motionRangeD: motionRangeD ?? _config.motionRangeD,
      motionDetectTime: motionDetectTime ?? _config.motionDetectTime,
      stabilityTimeout: stabilityTimeout ?? _config.stabilityTimeout,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取强类型的本地化实例
    final l = AppLocalizations.of(context)!;

    // 将原先静态的 _lpLabels 放在 build 中动态获取，以响应语言切换
    final lpLabels = [l.veryLight, l.light, l.medium, l.heavy];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.filter)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.filter),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: Text(l.save),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Low-pass filter
          Text(l.lowPassFilter, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _config.lowPassLevel,
            decoration: InputDecoration(
              labelText: l.lowPassFilter,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(
              4,
              (i) => DropdownMenuItem(value: i, child: Text(lpLabels[i])),
            ),
            onChanged: (v) =>
                setState(() => _config = _update(lowPassLevel: v)),
          ),

          const Divider(height: 32),

          // Notch filter
          Text(l.notchFilter, style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: Text(l.enabled),
            value: _config.notchEnabled,
            onChanged: (v) =>
                setState(() => _config = _update(notchEnabled: v)),
          ),
          if (_config.notchEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                initialValue: _config.notchFrequency.toString(),
                decoration: InputDecoration(
                  labelText: l.frequencyHz, // 替换为国际化变量
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v > 0) {
                    setState(() => _config = _update(notchFrequency: v));
                  }
                },
              ),
            ),

          const Divider(height: 32),

          // Adaptive filter
          Text(
            l.adaptiveFilter,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            title: Text(l.enabled),
            value: _config.adaptiveEnabled,
            onChanged: (v) =>
                setState(() => _config = _update(adaptiveEnabled: v)),
          ),
          if (_config.adaptiveEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                initialValue: _config.adaptiveRangeD.toString(),
                decoration: InputDecoration(
                  labelText: l.rangeD, // 替换为国际化变量
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v > 0) {
                    setState(() => _config = _update(adaptiveRangeD: v));
                  }
                },
              ),
            ),

          const Divider(height: 32),

          // Stability
          Text(l.stability, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          TextFormField(
            initialValue: _config.motionRangeD.toString(),
            decoration: InputDecoration(
              labelText: '${l.motionRange} (d)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0) {
                setState(() => _config = _update(motionRangeD: v));
              }
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: _config.motionDetectTime.toString(),
            decoration: InputDecoration(
              labelText: '${l.motionDetectTime} (s)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0) {
                setState(() => _config = _update(motionDetectTime: v));
              }
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: _config.stabilityTimeout.toString(),
            decoration: InputDecoration(
              labelText: '${l.stabilityTimeout} (s)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0) {
                setState(() => _config = _update(stabilityTimeout: v));
              }
            },
          ),
        ],
      ),
    );
  }
}
