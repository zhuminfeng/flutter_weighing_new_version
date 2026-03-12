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

  static const _lpLabels = ['Very Light', 'Light', 'Medium', 'Heavy'];

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
        SnackBar(content: Text(AppLocalizations.of(context).tr('save'))),
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
    final l = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tr('filter'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('filter')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: Text(l.tr('save')),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Low-pass filter
          Text(
            l.tr('lowPassFilter'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _config.lowPassLevel,
            decoration: InputDecoration(
              labelText: l.tr('lowPassFilter'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(
              4,
              (i) => DropdownMenuItem(value: i, child: Text(_lpLabels[i])),
            ),
            onChanged: (v) =>
                setState(() => _config = _update(lowPassLevel: v)),
          ),

          const Divider(height: 32),

          // Notch filter
          Text(
            l.tr('notchFilter'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            title: Text(l.tr('enabled')),
            value: _config.notchEnabled,
            onChanged: (v) =>
                setState(() => _config = _update(notchEnabled: v)),
          ),
          if (_config.notchEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                initialValue: _config.notchFrequency.toString(),
                decoration: const InputDecoration(
                  labelText: 'Frequency (Hz)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v > 0)
                    setState(() => _config = _update(notchFrequency: v));
                },
              ),
            ),

          const Divider(height: 32),

          // Adaptive filter
          Text(
            l.tr('adaptiveFilter'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            title: Text(l.tr('enabled')),
            value: _config.adaptiveEnabled,
            onChanged: (v) =>
                setState(() => _config = _update(adaptiveEnabled: v)),
          ),
          if (_config.adaptiveEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                initialValue: _config.adaptiveRangeD.toString(),
                decoration: const InputDecoration(
                  labelText: 'Range (d)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v > 0)
                    setState(() => _config = _update(adaptiveRangeD: v));
                },
              ),
            ),

          const Divider(height: 32),

          // Stability
          Text(
            l.tr('stability'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          TextFormField(
            initialValue: _config.motionRangeD.toString(),
            decoration: InputDecoration(
              labelText: '${l.tr("motionRange")} (d)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0)
                setState(() => _config = _update(motionRangeD: v));
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: _config.motionDetectTime.toString(),
            decoration: InputDecoration(
              labelText: '${l.tr("motionDetectTime")} (s)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0)
                setState(() => _config = _update(motionDetectTime: v));
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: _config.stabilityTimeout.toString(),
            decoration: InputDecoration(
              labelText: '${l.tr("stabilityTimeout")} (s)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v >= 0)
                setState(() => _config = _update(stabilityTimeout: v));
            },
          ),
        ],
      ),
    );
  }
}
