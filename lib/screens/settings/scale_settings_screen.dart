import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';

class ScaleSettingsScreen extends StatefulWidget {
  const ScaleSettingsScreen({super.key});

  @override
  State<ScaleSettingsScreen> createState() => _ScaleSettingsScreenState();
}

class _ScaleSettingsScreenState extends State<ScaleSettingsScreen> {
  final int _scaleId = 0;
  ScaleParams _params = const ScaleParams();
  ZeroConfig _zeroConfig = const ZeroConfig();
  TareConfig _tareConfig = const TareConfig();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final platform = WeighingPlatform.instance;
      _params = await platform.getScaleParams(_scaleId);
      _zeroConfig = await platform.getZeroConfig(_scaleId);
      _tareConfig = await platform.getTareConfig(_scaleId);
    } catch (_) {
      // Use defaults
    }
    setState(() => _loading = false);
  }

  Future<void> _saveAll() async {
    final platform = WeighingPlatform.instance;
    await platform.updateScaleParams(_scaleId, _params);
    await platform.updateZeroConfig(_scaleId, _zeroConfig);
    await platform.updateTareConfig(_scaleId, _tareConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('save'))),
      );
    }
  }

  static const _unitOptions = ['g', 'kg', 'lb', 't', 'ton'];
  static const _autoZeroOptions = ['off', 'gross', 'gross+net'];
  static const _powerUpZeroOptions = ['last', 'calibrated', 'new'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tr('scaleSettings'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('scaleSettings')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save),
            label: Text(l.tr('save')),
            onPressed: _saveAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Scale Params ===
          _SectionHeader(l.tr('scaleSettings')),

          _DropdownField(
            label: l.tr('unit'),
            value: _params.primaryUnit,
            items: List.generate(
              _unitOptions.length,
              (i) => DropdownMenuItem(value: i, child: Text(_unitOptions[i])),
            ),
            onChanged: (v) =>
                setState(() => _params = _params.copyWith(primaryUnit: v)),
          ),

          _NumberField(
            label: l.tr('capacity'),
            value: _params.capacity,
            min: 0.05,
            max: 20000000,
            onChanged: (v) =>
                setState(() => _params = _params.copyWith(capacity: v)),
          ),

          _NumberField(
            label: l.tr('division'),
            value: _params.division,
            min: 0.0001,
            max: 200,
            onChanged: (v) =>
                setState(() => _params = _params.copyWith(division: v)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${l.tr("division")} count: ${_params.maxDivisions}',
              style: TextStyle(
                color:
                    _params.maxDivisions > 100000 || _params.maxDivisions < 500
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
          ),

          _NumberField(
            label: l.tr('overloadRange'),
            value: _params.overloadRange.toDouble(),
            min: 0,
            max: 99,
            isInt: true,
            onChanged: (v) => setState(
              () => _params = _params.copyWith(overloadRange: v.round()),
            ),
          ),

          const Divider(height: 32),

          // === Auto Zero Tracking ===
          _SectionHeader(l.tr('autoZeroTracking')),

          _DropdownField(
            label: l.tr('autoZeroTracking'),
            value: _zeroConfig.autoZeroMode,
            items: List.generate(
              _autoZeroOptions.length,
              (i) =>
                  DropdownMenuItem(value: i, child: Text(_autoZeroOptions[i])),
            ),
            onChanged: (v) => setState(
              () => _zeroConfig = ZeroConfig(
                autoZeroMode: v!,
                autoZeroRangeD: _zeroConfig.autoZeroRangeD,
                underloadRangeD: _zeroConfig.underloadRangeD,
                powerUpZero: _zeroConfig.powerUpZero,
                powerUpZeroPosPct: _zeroConfig.powerUpZeroPosPct,
                powerUpZeroNegPct: _zeroConfig.powerUpZeroNegPct,
                pushbuttonZeroEnabled: _zeroConfig.pushbuttonZeroEnabled,
                pushbuttonZeroPosPct: _zeroConfig.pushbuttonZeroPosPct,
                pushbuttonZeroNegPct: _zeroConfig.pushbuttonZeroNegPct,
              ),
            ),
          ),

          if (_zeroConfig.autoZeroMode != 0) ...[
            _NumberField(
              label: '${l.tr("autoZeroTracking")} (d)',
              value: _zeroConfig.autoZeroRangeD,
              min: 0,
              max: 100,
              onChanged: (v) => setState(
                () => _zeroConfig = ZeroConfig(
                  autoZeroMode: _zeroConfig.autoZeroMode,
                  autoZeroRangeD: v,
                  underloadRangeD: _zeroConfig.underloadRangeD,
                  powerUpZero: _zeroConfig.powerUpZero,
                  powerUpZeroPosPct: _zeroConfig.powerUpZeroPosPct,
                  powerUpZeroNegPct: _zeroConfig.powerUpZeroNegPct,
                  pushbuttonZeroEnabled: _zeroConfig.pushbuttonZeroEnabled,
                  pushbuttonZeroPosPct: _zeroConfig.pushbuttonZeroPosPct,
                  pushbuttonZeroNegPct: _zeroConfig.pushbuttonZeroNegPct,
                ),
              ),
            ),
          ],

          _NumberField(
            label: 'Underload (d)',
            value: _zeroConfig.underloadRangeD,
            min: 0,
            max: 1000,
            onChanged: (v) => setState(
              () => _zeroConfig = ZeroConfig(
                autoZeroMode: _zeroConfig.autoZeroMode,
                autoZeroRangeD: _zeroConfig.autoZeroRangeD,
                underloadRangeD: v,
                powerUpZero: _zeroConfig.powerUpZero,
                powerUpZeroPosPct: _zeroConfig.powerUpZeroPosPct,
                powerUpZeroNegPct: _zeroConfig.powerUpZeroNegPct,
                pushbuttonZeroEnabled: _zeroConfig.pushbuttonZeroEnabled,
                pushbuttonZeroPosPct: _zeroConfig.pushbuttonZeroPosPct,
                pushbuttonZeroNegPct: _zeroConfig.pushbuttonZeroNegPct,
              ),
            ),
          ),

          const Divider(height: 32),

          // === Zero Settings ===
          _SectionHeader(l.tr('zeroConfig')),

          _DropdownField(
            label: 'Power-up Zero',
            value: _zeroConfig.powerUpZero,
            items: List.generate(
              _powerUpZeroOptions.length,
              (i) => DropdownMenuItem(
                value: i,
                child: Text(_powerUpZeroOptions[i]),
              ),
            ),
            onChanged: (v) => setState(
              () => _zeroConfig = ZeroConfig(
                autoZeroMode: _zeroConfig.autoZeroMode,
                autoZeroRangeD: _zeroConfig.autoZeroRangeD,
                underloadRangeD: _zeroConfig.underloadRangeD,
                powerUpZero: v!,
                powerUpZeroPosPct: _zeroConfig.powerUpZeroPosPct,
                powerUpZeroNegPct: _zeroConfig.powerUpZeroNegPct,
                pushbuttonZeroEnabled: _zeroConfig.pushbuttonZeroEnabled,
                pushbuttonZeroPosPct: _zeroConfig.pushbuttonZeroPosPct,
                pushbuttonZeroNegPct: _zeroConfig.pushbuttonZeroNegPct,
              ),
            ),
          ),

          SwitchListTile(
            title: Text('Pushbutton Zero'),
            value: _zeroConfig.pushbuttonZeroEnabled,
            onChanged: (v) => setState(
              () => _zeroConfig = ZeroConfig(
                autoZeroMode: _zeroConfig.autoZeroMode,
                autoZeroRangeD: _zeroConfig.autoZeroRangeD,
                underloadRangeD: _zeroConfig.underloadRangeD,
                powerUpZero: _zeroConfig.powerUpZero,
                powerUpZeroPosPct: _zeroConfig.powerUpZeroPosPct,
                powerUpZeroNegPct: _zeroConfig.powerUpZeroNegPct,
                pushbuttonZeroEnabled: v,
                pushbuttonZeroPosPct: _zeroConfig.pushbuttonZeroPosPct,
                pushbuttonZeroNegPct: _zeroConfig.pushbuttonZeroNegPct,
              ),
            ),
          ),

          const Divider(height: 32),

          // === Tare Settings ===
          _SectionHeader(l.tr('tareConfig')),

          SwitchListTile(
            title: Text('Pushbutton Tare'),
            value: _tareConfig.pushbuttonTareEnabled,
            onChanged: (v) => setState(
              () => _tareConfig = TareConfig(
                pushbuttonTareEnabled: v,
                presetTareEnabled: _tareConfig.presetTareEnabled,
              ),
            ),
          ),

          SwitchListTile(
            title: Text(l.tr('presetTare')),
            value: _tareConfig.presetTareEnabled,
            onChanged: (v) => setState(
              () => _tareConfig = TareConfig(
                pushbuttonTareEnabled: _tareConfig.pushbuttonTareEnabled,
                presetTareEnabled: v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === Reusable Form Widgets ===

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    this.min = 0,
    this.max = double.infinity,
    this.isInt = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: isInt ? value.round().toString() : value.toString(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: '$min - $max',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (text) {
          final v = double.tryParse(text);
          if (v != null && v >= min && v <= max) {
            onChanged(v);
          }
        },
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
