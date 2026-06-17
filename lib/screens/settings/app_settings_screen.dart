import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // LIW configs
  double _liwSafetyLimit = 100;
  double _liwHopperMin = 0;
  double _liwHopperMax = 15;
  double _liwTargetFlow = 10;
  double _liwTargetControlRate = 10;
  bool _liwPreRefill = false;

  double _liwAdjustRangeLower = 0;
  double _liwAdjustRangeUpper = 90;
  bool _liwSmartStepControl = false;
  double _liwStepDuration = 10;
  double _liwFilterWindowSysId = 0.5;

  int _liwTuningMode = 1;
  double _liwFilterWindowCtrl = 0.5;
  double _liwKp = 1;
  double _liwKi = 1;
  double _liwKd = 0;
  double _liwMaxFlow = 100;
  double _liwStartupTime = 0;

  int _liwRefillMode = 0;
  double _liwLowerLimit = 1;
  double _liwUpperLimit = 10;
  int _liwRefillControlMode = 1;
  double _liwRefillControlSetpoint = 10;
  double _liwRefillStabilizeTime = 10;

  double _liwBatchTarget = 1;
  double _liwInFlight = 0;
  double _liwFineFeedThreshold = 0;
  double _liwFineFeedFlow = 2;

  double _liwPreCheckDelay = 0;
  double _liwStabilityTimeout = 0;
  double _liwTolerance = 0;

  bool _liwAutoStopAtAlarm = true;
  double _liwEmptyingControlSetpoint = 10;

  double _liwControlRateLower = 20;
  double _liwControlRateUpper = 80;
  double _liwRefillTimeout = 10;
  bool _liwStopOnError = false;

  double _liwEvaluationWindow = 3;
  double _liwDeviationThreshold = 10;
  double _liwSurgeThreshold = 150;

  bool _liwInterlockEnabled = false;
  double _liwInterlockDelay = 0;

  double _liwSamplePeriod = 60;
  double _liwSampleTolerance = 10;
  int _appType = 0; // 0=liw, 1=filling
  // Subsystem / recipe identity
  String _recipeName = '';
  DioInputConfig _dioConfig = const DioInputConfig();
  late final TextEditingController _recipeNameCtrl =
      TextEditingController(text: _recipeName);
  int _liwMode = 0;
  int _liwSubMode = 0;
  int _fillingWorkMode = 0;
  int _powerFailRecovery = 0;
  int _startDelay = 0;
  // Filling configs
  int _fillingFeedSpeed = 1;
  double _fillingTargetValue = 1;
  double _fillingInFlight = 0;
  double _fillingFeed = 0;
  double _fillingFeedInhibitTime = 0;
  double _fillingFastFeedInhibitTime = 0;
  bool _fillingAutoTareEnabled = false;
  double _fillingContainerTareUpper = 0;
  double _fillingContainerTareLower = 0;
  double _fillingPreCheckDelay = 0;
  double _fillingStabilityTimeout = 0;
  double _fillingPositiveTolerance = 0;
  double _fillingNegativeTolerance = 0;
  int _fillingSpillMode = 0;
  double _fillingSpillAdjustRange = 0;
  int _fillingSpillAdjustSamples = 5;
  double _fillingSpillAdjustFactor = 0.5;
  int _fillingCutoffMode = 0;
  double _fillingCutoffReliabilityRange = 0;
  int _fillingCutoffAdjustCycles = 5;
  double _fillingCutoffAdjustFactor = 0.5;
  int _fillingJogMode = 0;
  double _fillingJogDuration = 0.5;
  double _fillingJogPauseTime = 1;
  int _fillingJogMaxCycles = 3;
  double _fillingRefillUpperLimit = 10;
  double _fillingRefillLowerLimit = 1;
  int _fillingEmptyingCompleteMode = 0;
  double _fillingEmptyingResidualWeight = 0.1;
  double _fillingEmptyingCompletionTime = 5;
  double _fillingInitialFeedTimeout = 30;
  double _fillingEmptyingTimeout = 60;
  double _fillingRefillTimeout = 60;
  double _fillingProcessTimeout = 120;
  int _fillingCycleConfirm = 0;
  int _fillingFastRecovery = 0;
  bool _fillingInterlockEnabled = false;
  double _fillingFastFeedSpeed = 100;
  double _fillingFineFeedSpeed = 30;

  bool _loading = true;

  static const _appTypeLabels = ['Loss-in-Weight', 'Filling/Dispensing'];
  static const _liwModeLabels = [
    'Continuous',
    'Batch',
    'System Identification',
  ];
  static const _liwSubModeLabels = ['Flow Control', 'Fixed Frequency'];
  static const _fillingWorkModeLabels = [
    'Fill',
    'Fill/Empty',
    'Dispense',
    'Refill/Dispense',
    'Absolute Value',
  ];
  static const _powerFailLabels = ['Idle', 'Pause'];
  static const _startDelayLabels = ['Disabled', '5 min', '15 min', '30 min'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recipeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateProvider.of(context);
    final subId = state.activeSubsystemId;
    _appType = state.selectedAppType;

    await _loadSubsystemConfig(subId);

    try {
      if (_appType == 0) {
        final base = await WeighingPlatform.instance.getLiwBaseConfig(subId);
        _liwMode = base.mode;
        _liwSubMode = base.subMode;

        final sys = await WeighingPlatform.instance.getLiwSystemConfig(subId);
        _liwSafetyLimit = sys.safetyLimit;
        _liwHopperMin = sys.hopperMin;
        _liwHopperMax = sys.hopperMax;
        _liwTargetFlow = sys.targetFlow;
        _liwTargetControlRate = sys.targetControlRate;
        _liwPreRefill = sys.preRefill;

        final sysId = await WeighingPlatform.instance.getLiwSystemIdConfig(
          subId,
        );
        _liwAdjustRangeLower = sysId.adjustRangeLower;
        _liwAdjustRangeUpper = sysId.adjustRangeUpper;
        _liwSmartStepControl = sysId.smartStepControl;
        _liwStepDuration = sysId.stepDuration;
        _liwFilterWindowSysId = sysId.filterWindow;

        final ctrl = await WeighingPlatform.instance.getLiwControllerConfig(
          subId,
        );
        _liwTuningMode = ctrl.tuningMode;
        _liwFilterWindowCtrl = ctrl.filterWindow;
        _liwKp = ctrl.kp;
        _liwKi = ctrl.ki;
        _liwKd = ctrl.kd;
        _liwMaxFlow = ctrl.maxFlow;
        _liwStartupTime = ctrl.startupTime;

        final refill = await WeighingPlatform.instance.getLiwRefillConfig(
          subId,
        );
        _liwRefillMode = refill.mode;
        _liwLowerLimit = refill.lowerLimit;
        _liwUpperLimit = refill.upperLimit;
        _liwRefillControlMode = refill.controlMode;
        _liwRefillControlSetpoint = refill.controlSetpoint;
        _liwRefillStabilizeTime = refill.stabilizeTime;

        final target = await WeighingPlatform.instance.getLiwTargetValuesConfig(
          subId,
        );
        _liwBatchTarget = target.batchTarget;
        _liwInFlight = target.inFlight;
        _liwFineFeedThreshold = target.fineFeedThreshold;
        _liwFineFeedFlow = target.fineFeedFlow;

        final tol = await WeighingPlatform.instance.getLiwToleranceCheckConfig(
          subId,
        );
        _liwPreCheckDelay = tol.preCheckDelay;
        _liwStabilityTimeout = tol.stabilityTimeout;
        _liwTolerance = tol.tolerance;

        final empty = await WeighingPlatform.instance.getLiwEmptyingConfig(
          subId,
        );
        _liwAutoStopAtAlarm = empty.autoStopAtAlarm;
        _liwEmptyingControlSetpoint = empty.controlSetpoint;

        final warn = await WeighingPlatform.instance.getLiwWarningConfig(subId);
        _liwControlRateLower = warn.controlRateLower;
        _liwControlRateUpper = warn.controlRateUpper;
        _liwRefillTimeout = warn.refillTimeout;
        _liwStopOnError = warn.stopOnError;

        final flow = await WeighingPlatform.instance.getLiwFlowMonitorConfig(
          subId,
        );
        _liwEvaluationWindow = flow.evaluationWindow;
        _liwDeviationThreshold = flow.deviationThreshold;
        _liwSurgeThreshold = flow.surgeThreshold;

        final adv = await WeighingPlatform.instance.getLiwAdvancedConfig(subId);
        _liwInterlockEnabled = adv.interlockEnabled;
        _liwInterlockDelay = adv.interlockDelay;

        final stats = await WeighingPlatform.instance.getLiwStatsConfig(subId);
        _liwSamplePeriod = stats.samplePeriod;
        _liwSampleTolerance = stats.sampleTolerance;
      } else {
        final gen = await WeighingPlatform.instance.getFillingGeneralConfig(
          subId,
        );
        final sys = await WeighingPlatform.instance.getFillingSystemConfig(
          subId,
        );
        final target = await WeighingPlatform.instance.getFillingTargetConfig(
          subId,
        );
        final tare = await WeighingPlatform.instance.getFillingAutoTareConfig(
          subId,
        );
        final tol = await WeighingPlatform.instance.getFillingToleranceConfig(
          subId,
        );
        final spill = await WeighingPlatform.instance.getFillingSpillOptConfig(
          subId,
        );
        final cutoff = await WeighingPlatform.instance
            .getFillingCutoffOptConfig(subId);
        final jog = await WeighingPlatform.instance.getFillingJogConfig(subId);
        final refill = await WeighingPlatform.instance.getFillingRefillConfig(
          subId,
        );
        final empty = await WeighingPlatform.instance.getFillingEmptyingConfig(
          subId,
        );
        final events = await WeighingPlatform.instance.getFillingEventsConfig(
          subId,
        );
        final adv = await WeighingPlatform.instance.getFillingAdvancedConfig(
          subId,
        );

        _fillingWorkMode = sys.workMode;
        _fillingFeedSpeed = sys.feedSpeed;
        _powerFailRecovery = gen.powerFailRecovery;
        _startDelay = gen.startDelay;

        _fillingTargetValue = target.targetValue;
        _fillingInFlight = target.inFlight;
        _fillingFeed = target.feed;
        _fillingFeedInhibitTime = target.feedInhibitTime;
        _fillingFastFeedInhibitTime = target.fastFeedInhibitTime;

        _fillingAutoTareEnabled = tare.autoTareEnabled;
        _fillingContainerTareUpper = tare.containerTareUpper;
        _fillingContainerTareLower = tare.containerTareLower;

        _fillingPreCheckDelay = tol.preCheckDelay;
        _fillingStabilityTimeout = tol.stabilityTimeout;
        _fillingPositiveTolerance = tol.positiveTolerance;
        _fillingNegativeTolerance = tol.negativeTolerance;

        _fillingSpillMode = spill.mode;
        _fillingSpillAdjustRange = spill.adjustRange;
        _fillingSpillAdjustSamples = spill.adjustSamples;
        _fillingSpillAdjustFactor = spill.adjustFactor;

        _fillingCutoffMode = cutoff.mode;
        _fillingCutoffReliabilityRange = cutoff.controlReliabilityRange;
        _fillingCutoffAdjustCycles = cutoff.adjustCycles;
        _fillingCutoffAdjustFactor = cutoff.adjustFactor;

        _fillingJogMode = jog.mode;
        _fillingJogDuration = jog.jogDuration;
        _fillingJogPauseTime = jog.jogPauseTime;
        _fillingJogMaxCycles = jog.maxCycles;

        _fillingRefillUpperLimit = refill.upperLimit;
        _fillingRefillLowerLimit = refill.lowerLimit;

        _fillingEmptyingCompleteMode = empty.completeMode;
        _fillingEmptyingResidualWeight = empty.residualWeight;
        _fillingEmptyingCompletionTime = empty.completionTime;

        _fillingInitialFeedTimeout = events.initialFeedTimeout;
        _fillingEmptyingTimeout = events.emptyingTimeout;
        _fillingRefillTimeout = events.refillTimeout;
        _fillingProcessTimeout = events.processTimeout;

        _fillingCycleConfirm = adv.cycleConfirm;
        _fillingFastRecovery = adv.fastRecovery;
        _fillingInterlockEnabled = adv.interlockEnabled;
        _fillingFastFeedSpeed = adv.fastFeedSpeed;
        _fillingFineFeedSpeed = adv.fineFeedSpeed;
      }
    } catch (_) {}

    setState(() => _loading = false);
  }

  // ---- load recipe name and DIO config ----
  Future<void> _loadSubsystemConfig(int subId) async {
    try {
      final name =
          await WeighingPlatform.instance.getSubsystemName(subId);
      _recipeNameCtrl.text = name;
      _recipeName = name;
    } catch (_) {}
    try {
      _dioConfig =
          await WeighingPlatform.instance.getDioInputConfig(subId);
    } catch (_) {}
  }

  Future<void> _save() async {
    final state = AppStateProvider.of(context);
    final subId = state.activeSubsystemId;

    if (_appType == 0) {
      await WeighingPlatform.instance.updateLiwBaseConfig(
        subId,
        LiwBaseConfig(mode: _liwMode, subMode: _liwSubMode),
      );
      await WeighingPlatform.instance.updateLiwSystemConfig(
        subId,
        LiwSystemConfig(
          safetyLimit: _liwSafetyLimit,
          hopperMin: _liwHopperMin,
          hopperMax: _liwHopperMax,
          targetFlow: _liwTargetFlow,
          targetControlRate: _liwTargetControlRate,
          preRefill: _liwPreRefill,
        ),
      );
      await WeighingPlatform.instance.updateLiwSystemIdConfig(
        subId,
        LiwSystemIdConfig(
          adjustRangeLower: _liwAdjustRangeLower,
          adjustRangeUpper: _liwAdjustRangeUpper,
          smartStepControl: _liwSmartStepControl,
          stepDuration: _liwStepDuration,
          filterWindow: _liwFilterWindowSysId,
        ),
      );
      await WeighingPlatform.instance.updateLiwControllerConfig(
        subId,
        LiwControllerConfig(
          tuningMode: _liwTuningMode,
          filterWindow: _liwFilterWindowCtrl,
          kp: _liwKp,
          ki: _liwKi,
          kd: _liwKd,
          maxFlow: _liwMaxFlow,
          startupTime: _liwStartupTime,
        ),
      );
      await WeighingPlatform.instance.updateLiwRefillConfig(
        subId,
        LiwRefillConfig(
          mode: _liwRefillMode,
          lowerLimit: _liwLowerLimit,
          upperLimit: _liwUpperLimit,
          controlMode: _liwRefillControlMode,
          controlSetpoint: _liwRefillControlSetpoint,
          stabilizeTime: _liwRefillStabilizeTime,
        ),
      );
      await WeighingPlatform.instance.updateLiwTargetValuesConfig(
        subId,
        LiwTargetValuesConfig(
          batchTarget: _liwBatchTarget,
          inFlight: _liwInFlight,
          fineFeedThreshold: _liwFineFeedThreshold,
          fineFeedFlow: _liwFineFeedFlow,
        ),
      );
      await WeighingPlatform.instance.updateLiwToleranceCheckConfig(
        subId,
        LiwToleranceCheckConfig(
          preCheckDelay: _liwPreCheckDelay,
          stabilityTimeout: _liwStabilityTimeout,
          tolerance: _liwTolerance,
        ),
      );
      await WeighingPlatform.instance.updateLiwEmptyingConfig(
        subId,
        LiwEmptyingConfig(
          autoStopAtAlarm: _liwAutoStopAtAlarm,
          controlSetpoint: _liwEmptyingControlSetpoint,
        ),
      );
      await WeighingPlatform.instance.updateLiwWarningConfig(
        subId,
        LiwWarningConfig(
          controlRateLower: _liwControlRateLower,
          controlRateUpper: _liwControlRateUpper,
          refillTimeout: _liwRefillTimeout,
          stopOnError: _liwStopOnError,
        ),
      );
      await WeighingPlatform.instance.updateLiwFlowMonitorConfig(
        subId,
        LiwFlowMonitorConfig(
          evaluationWindow: _liwEvaluationWindow,
          deviationThreshold: _liwDeviationThreshold,
          surgeThreshold: _liwSurgeThreshold,
        ),
      );
      await WeighingPlatform.instance.updateLiwAdvancedConfig(
        subId,
        LiwAdvancedConfig(
          interlockEnabled: _liwInterlockEnabled,
          interlockDelay: _liwInterlockDelay,
        ),
      );
      await WeighingPlatform.instance.updateLiwStatsConfig(
        subId,
        LiwStatsConfig(
          samplePeriod: _liwSamplePeriod,
          sampleTolerance: _liwSampleTolerance,
        ),
      );
    } else {
      await WeighingPlatform.instance.updateFillingGeneralConfig(
        subId,
        FillingGeneralConfig(
          powerFailRecovery: _powerFailRecovery,
          startDelay: _startDelay,
        ),
      );
      await WeighingPlatform.instance.updateFillingSystemConfig(
        subId,
        FillingSystemConfig(
          workMode: _fillingWorkMode,
          feedSpeed: _fillingFeedSpeed,
        ),
      );
      await WeighingPlatform.instance.updateFillingTargetConfig(
        subId,
        FillingTargetConfig(
          targetValue: _fillingTargetValue,
          inFlight: _fillingInFlight,
          feed: _fillingFeed,
          feedInhibitTime: _fillingFeedInhibitTime,
          fastFeedInhibitTime: _fillingFastFeedInhibitTime,
        ),
      );
      await WeighingPlatform.instance.updateFillingAutoTareConfig(
        subId,
        FillingAutoTareConfig(
          autoTareEnabled: _fillingAutoTareEnabled,
          containerTareUpper: _fillingContainerTareUpper,
          containerTareLower: _fillingContainerTareLower,
        ),
      );
      await WeighingPlatform.instance.updateFillingToleranceConfig(
        subId,
        FillingToleranceConfig(
          preCheckDelay: _fillingPreCheckDelay,
          stabilityTimeout: _fillingStabilityTimeout,
          positiveTolerance: _fillingPositiveTolerance,
          negativeTolerance: _fillingNegativeTolerance,
        ),
      );
      await WeighingPlatform.instance.updateFillingSpillOptConfig(
        subId,
        FillingSpillOptConfig(
          mode: _fillingSpillMode,
          adjustRange: _fillingSpillAdjustRange,
          adjustSamples: _fillingSpillAdjustSamples,
          adjustFactor: _fillingSpillAdjustFactor,
        ),
      );
      await WeighingPlatform.instance.updateFillingCutoffOptConfig(
        subId,
        FillingCutoffOptConfig(
          mode: _fillingCutoffMode,
          controlReliabilityRange: _fillingCutoffReliabilityRange,
          adjustCycles: _fillingCutoffAdjustCycles,
          adjustFactor: _fillingCutoffAdjustFactor,
        ),
      );
      await WeighingPlatform.instance.updateFillingJogConfig(
        subId,
        FillingJogConfig(
          mode: _fillingJogMode,
          jogDuration: _fillingJogDuration,
          jogPauseTime: _fillingJogPauseTime,
          maxCycles: _fillingJogMaxCycles,
        ),
      );
      await WeighingPlatform.instance.updateFillingRefillConfig(
        subId,
        FillingRefillConfig(
          upperLimit: _fillingRefillUpperLimit,
          lowerLimit: _fillingRefillLowerLimit,
        ),
      );
      await WeighingPlatform.instance.updateFillingEmptyingConfig(
        subId,
        FillingEmptyingConfig(
          completeMode: _fillingEmptyingCompleteMode,
          residualWeight: _fillingEmptyingResidualWeight,
          completionTime: _fillingEmptyingCompletionTime,
        ),
      );
      await WeighingPlatform.instance.updateFillingEventsConfig(
        subId,
        FillingEventsConfig(
          initialFeedTimeout: _fillingInitialFeedTimeout,
          emptyingTimeout: _fillingEmptyingTimeout,
          refillTimeout: _fillingRefillTimeout,
          processTimeout: _fillingProcessTimeout,
        ),
      );
      await WeighingPlatform.instance.updateFillingAdvancedConfig(
        subId,
        FillingAdvancedConfig(
          cycleConfirm: _fillingCycleConfirm,
          fastRecovery: _fillingFastRecovery,
          interlockEnabled: _fillingInterlockEnabled,
          fastFeedSpeed: _fillingFastFeedSpeed,
          fineFeedSpeed: _fillingFineFeedSpeed,
        ),
      );
    }

    state.selectAppType(_appType);

    // 保存配方名称和离散输入配置
    await WeighingPlatform.instance
        .updateSubsystemName(subId, _recipeNameCtrl.text);
    await WeighingPlatform.instance
        .updateDioInputConfig(subId, _dioConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('save'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tr('appSettings'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tr('appSettings')),
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
          // 0. 配方名称
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextFormField(
              controller: _recipeNameCtrl,
              decoration: InputDecoration(
                labelText: l.tr('recipeName'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
          ),

          // 1. App type selection: 改用分段按钮直接点击切换
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: List.generate(
                  _appTypeLabels.length,
                  (i) =>
                      ButtonSegment(value: i, label: Text(_appTypeLabels[i])),
                ),
                selected: {_appType},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() {
                    _appType = newSelection.first;
                  });
                },
              ),
            ),
          ),

          // 2. LIW 配置分组
          if (_appType == 0) ...[
            _buildExpandableCard(
              context: context,
              title: 'Base',
              children: [
                DropdownButtonFormField<int>(
                  value: _liwMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: List.generate(
                    _liwModeLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_liwModeLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _liwMode = v!),
                ),
                if (_liwMode == 0)
                  DropdownButtonFormField<int>(
                    value: _liwSubMode,
                    decoration: const InputDecoration(labelText: 'Sub-Mode'),
                    items: List.generate(
                      _liwSubModeLabels.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(_liwSubModeLabels[i]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _liwSubMode = v!),
                  ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'System',
              children: [
                TextFormField(
                  initialValue: _liwSafetyLimit.toString(),
                  decoration: const InputDecoration(labelText: 'Safety Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () =>
                        _liwSafetyLimit = double.tryParse(v) ?? _liwSafetyLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _liwHopperMin.toString(),
                  decoration: const InputDecoration(labelText: 'Hopper Min'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwHopperMin = double.tryParse(v) ?? _liwHopperMin,
                  ),
                ),
                TextFormField(
                  initialValue: _liwHopperMax.toString(),
                  decoration: const InputDecoration(labelText: 'Hopper Max'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwHopperMax = double.tryParse(v) ?? _liwHopperMax,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTargetFlow.toString(),
                  decoration: const InputDecoration(labelText: 'Target Flow'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTargetFlow = double.tryParse(v) ?? _liwTargetFlow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTargetControlRate.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Target Control Rate',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTargetControlRate =
                        double.tryParse(v) ?? _liwTargetControlRate,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Pre Refill'),
                  value: _liwPreRefill,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwPreRefill = v),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'System ID',
              children: [
                TextFormField(
                  initialValue: _liwAdjustRangeLower.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Adjust Range Lower',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwAdjustRangeLower =
                        double.tryParse(v) ?? _liwAdjustRangeLower,
                  ),
                ),
                TextFormField(
                  initialValue: _liwAdjustRangeUpper.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Adjust Range Upper',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwAdjustRangeUpper =
                        double.tryParse(v) ?? _liwAdjustRangeUpper,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Smart Step Control'),
                  value: _liwSmartStepControl,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwSmartStepControl = v),
                ),
                TextFormField(
                  initialValue: _liwStepDuration.toString(),
                  decoration: const InputDecoration(labelText: 'Step Duration'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwStepDuration =
                        double.tryParse(v) ?? _liwStepDuration,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFilterWindowSysId.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Filter Window (SysId)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFilterWindowSysId =
                        double.tryParse(v) ?? _liwFilterWindowSysId,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Controller',
              children: [
                DropdownButtonFormField<int>(
                  value: _liwTuningMode,
                  decoration: const InputDecoration(labelText: 'Tuning Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Auto')),
                    DropdownMenuItem(value: 1, child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() => _liwTuningMode = v!),
                ),
                TextFormField(
                  initialValue: _liwFilterWindowCtrl.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Filter Window (Ctrl)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFilterWindowCtrl =
                        double.tryParse(v) ?? _liwFilterWindowCtrl,
                  ),
                ),
                TextFormField(
                  initialValue: _liwKp.toString(),
                  decoration: const InputDecoration(labelText: 'Kp'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKp = double.tryParse(v) ?? _liwKp),
                ),
                TextFormField(
                  initialValue: _liwKi.toString(),
                  decoration: const InputDecoration(labelText: 'Ki'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKi = double.tryParse(v) ?? _liwKi),
                ),
                TextFormField(
                  initialValue: _liwKd.toString(),
                  decoration: const InputDecoration(labelText: 'Kd'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKd = double.tryParse(v) ?? _liwKd),
                ),
                TextFormField(
                  initialValue: _liwMaxFlow.toString(),
                  decoration: const InputDecoration(labelText: 'Max Flow'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwMaxFlow = double.tryParse(v) ?? _liwMaxFlow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwStartupTime.toString(),
                  decoration: const InputDecoration(labelText: 'Startup Time'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () =>
                        _liwStartupTime = double.tryParse(v) ?? _liwStartupTime,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Refill',
              children: [
                DropdownButtonFormField<int>(
                  value: _liwRefillMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Auto')),
                    DropdownMenuItem(value: 1, child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() => _liwRefillMode = v!),
                ),
                TextFormField(
                  initialValue: _liwLowerLimit.toString(),
                  decoration: const InputDecoration(labelText: 'Lower Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwLowerLimit = double.tryParse(v) ?? _liwLowerLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _liwUpperLimit.toString(),
                  decoration: const InputDecoration(labelText: 'Upper Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwUpperLimit = double.tryParse(v) ?? _liwUpperLimit,
                  ),
                ),
                DropdownButtonFormField<int>(
                  value: _liwRefillControlMode,
                  decoration: const InputDecoration(labelText: 'Control Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Fixed')),
                    DropdownMenuItem(value: 1, child: Text('Last Freq')),
                    DropdownMenuItem(value: 2, child: Text('Smart')),
                  ],
                  onChanged: (v) => setState(() => _liwRefillControlMode = v!),
                ),
                TextFormField(
                  initialValue: _liwRefillControlSetpoint.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Control Setpoint',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwRefillControlSetpoint =
                        double.tryParse(v) ?? _liwRefillControlSetpoint,
                  ),
                ),
                TextFormField(
                  initialValue: _liwRefillStabilizeTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Stabilize Time',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwRefillStabilizeTime =
                        double.tryParse(v) ?? _liwRefillStabilizeTime,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Target Values',
              children: [
                TextFormField(
                  initialValue: _liwBatchTarget.toString(),
                  decoration: const InputDecoration(labelText: 'Batch Target'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () =>
                        _liwBatchTarget = double.tryParse(v) ?? _liwBatchTarget,
                  ),
                ),
                TextFormField(
                  initialValue: _liwInFlight.toString(),
                  decoration: const InputDecoration(labelText: 'In Flight'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwInFlight = double.tryParse(v) ?? _liwInFlight,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFineFeedThreshold.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fine Feed Threshold',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFineFeedThreshold =
                        double.tryParse(v) ?? _liwFineFeedThreshold,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFineFeedFlow.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fine Feed Flow',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFineFeedFlow =
                        double.tryParse(v) ?? _liwFineFeedFlow,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Tolerance Check',
              children: [
                TextFormField(
                  initialValue: _liwPreCheckDelay.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Pre Check Delay',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwPreCheckDelay =
                        double.tryParse(v) ?? _liwPreCheckDelay,
                  ),
                ),
                TextFormField(
                  initialValue: _liwStabilityTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Stability Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwStabilityTimeout =
                        double.tryParse(v) ?? _liwStabilityTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTolerance.toString(),
                  decoration: const InputDecoration(labelText: 'Tolerance'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTolerance = double.tryParse(v) ?? _liwTolerance,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Emptying',
              children: [
                SwitchListTile(
                  title: const Text('Auto Stop At Alarm'),
                  value: _liwAutoStopAtAlarm,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwAutoStopAtAlarm = v),
                ),
                TextFormField(
                  initialValue: _liwEmptyingControlSetpoint.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Control Setpoint',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwEmptyingControlSetpoint =
                        double.tryParse(v) ?? _liwEmptyingControlSetpoint,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Warning',
              children: [
                TextFormField(
                  initialValue: _liwControlRateLower.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Control Rate Lower',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwControlRateLower =
                        double.tryParse(v) ?? _liwControlRateLower,
                  ),
                ),
                TextFormField(
                  initialValue: _liwControlRateUpper.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Control Rate Upper',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwControlRateUpper =
                        double.tryParse(v) ?? _liwControlRateUpper,
                  ),
                ),
                TextFormField(
                  initialValue: _liwRefillTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Refill Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwRefillTimeout =
                        double.tryParse(v) ?? _liwRefillTimeout,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Stop On Error'),
                  value: _liwStopOnError,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwStopOnError = v),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Flow Monitor',
              children: [
                TextFormField(
                  initialValue: _liwEvaluationWindow.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Evaluation Window',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwEvaluationWindow =
                        double.tryParse(v) ?? _liwEvaluationWindow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwDeviationThreshold.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Deviation Threshold',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwDeviationThreshold =
                        double.tryParse(v) ?? _liwDeviationThreshold,
                  ),
                ),
                TextFormField(
                  initialValue: _liwSurgeThreshold.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Surge Threshold',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwSurgeThreshold =
                        double.tryParse(v) ?? _liwSurgeThreshold,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Advanced',
              children: [
                SwitchListTile(
                  title: const Text('Interlock Enabled'),
                  value: _liwInterlockEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwInterlockEnabled = v),
                ),
                TextFormField(
                  initialValue: _liwInterlockDelay.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Interlock Delay',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwInterlockDelay =
                        double.tryParse(v) ?? _liwInterlockDelay,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Stats',
              children: [
                TextFormField(
                  initialValue: _liwSamplePeriod.toString(),
                  decoration: const InputDecoration(labelText: 'Sample Period'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwSamplePeriod =
                        double.tryParse(v) ?? _liwSamplePeriod,
                  ),
                ),
                TextFormField(
                  initialValue: _liwSampleTolerance.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Sample Tolerance',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwSampleTolerance =
                        double.tryParse(v) ?? _liwSampleTolerance,
                  ),
                ),
              ],
            ),
          ],

          // 3. Filling 配置分组
          if (_appType == 1) ...[
            _buildExpandableCard(
              context: context,
              title: 'General',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingWorkMode,
                  decoration: const InputDecoration(labelText: 'Work Mode'),
                  items: List.generate(
                    _fillingWorkModeLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_fillingWorkModeLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _fillingWorkMode = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _powerFailRecovery,
                  decoration: const InputDecoration(
                    labelText: 'Power Fail Recovery',
                  ),
                  items: List.generate(
                    _powerFailLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_powerFailLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _powerFailRecovery = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _startDelay,
                  decoration: const InputDecoration(labelText: 'Start Delay'),
                  items: List.generate(
                    _startDelayLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_startDelayLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _startDelay = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _fillingFeedSpeed,
                  decoration: const InputDecoration(labelText: 'Feed Speed'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Single')),
                    DropdownMenuItem(value: 1, child: Text('Dual')),
                  ],
                  onChanged: (v) => setState(() => _fillingFeedSpeed = v!),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Target',
              children: [
                TextFormField(
                  initialValue: _fillingTargetValue.toString(),
                  decoration: const InputDecoration(labelText: 'Target Value'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingTargetValue =
                        double.tryParse(v) ?? _fillingTargetValue,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingInFlight.toString(),
                  decoration: const InputDecoration(labelText: 'In Flight'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingInFlight =
                        double.tryParse(v) ?? _fillingInFlight,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFeed.toString(),
                  decoration: const InputDecoration(labelText: 'Feed'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFeed = double.tryParse(v) ?? _fillingFeed,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFeedInhibitTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Feed Inhibit Time',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFeedInhibitTime =
                        double.tryParse(v) ?? _fillingFeedInhibitTime,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFastFeedInhibitTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fast Feed Inhibit Time',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFastFeedInhibitTime =
                        double.tryParse(v) ?? _fillingFastFeedInhibitTime,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Auto Tare',
              children: [
                SwitchListTile(
                  title: const Text('Auto Tare Enabled'),
                  value: _fillingAutoTareEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _fillingAutoTareEnabled = v),
                ),
                TextFormField(
                  initialValue: _fillingContainerTareUpper.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Container Tare Upper',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingContainerTareUpper =
                        double.tryParse(v) ?? _fillingContainerTareUpper,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingContainerTareLower.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Container Tare Lower',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingContainerTareLower =
                        double.tryParse(v) ?? _fillingContainerTareLower,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Tolerance',
              children: [
                TextFormField(
                  initialValue: _fillingPreCheckDelay.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Pre Check Delay',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingPreCheckDelay =
                        double.tryParse(v) ?? _fillingPreCheckDelay,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingStabilityTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Stability Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingStabilityTimeout =
                        double.tryParse(v) ?? _fillingStabilityTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingPositiveTolerance.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Positive Tolerance',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingPositiveTolerance =
                        double.tryParse(v) ?? _fillingPositiveTolerance,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingNegativeTolerance.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Negative Tolerance',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingNegativeTolerance =
                        double.tryParse(v) ?? _fillingNegativeTolerance,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Spill Optimization',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingSpillMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Disabled')),
                    DropdownMenuItem(value: 1, child: Text('Auto')),
                    DropdownMenuItem(value: 2, child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() => _fillingSpillMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustRange.toString(),
                  decoration: const InputDecoration(labelText: 'Adjust Range'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingSpillAdjustRange =
                        double.tryParse(v) ?? _fillingSpillAdjustRange,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustSamples.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Adjust Samples',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingSpillAdjustSamples =
                        int.tryParse(v) ?? _fillingSpillAdjustSamples,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustFactor.toString(),
                  decoration: const InputDecoration(labelText: 'Adjust Factor'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingSpillAdjustFactor =
                        double.tryParse(v) ?? _fillingSpillAdjustFactor,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Cutoff Optimization',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingCutoffMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Disabled')),
                    DropdownMenuItem(value: 1, child: Text('Auto')),
                    DropdownMenuItem(value: 2, child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() => _fillingCutoffMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingCutoffReliabilityRange.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Control Reliability Range',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingCutoffReliabilityRange =
                        double.tryParse(v) ?? _fillingCutoffReliabilityRange,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingCutoffAdjustCycles.toString(),
                  decoration: const InputDecoration(labelText: 'Adjust Cycles'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingCutoffAdjustCycles =
                        int.tryParse(v) ?? _fillingCutoffAdjustCycles,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingCutoffAdjustFactor.toString(),
                  decoration: const InputDecoration(labelText: 'Adjust Factor'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingCutoffAdjustFactor =
                        double.tryParse(v) ?? _fillingCutoffAdjustFactor,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Jog',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingJogMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Disabled')),
                    DropdownMenuItem(value: 1, child: Text('Auto')),
                    DropdownMenuItem(value: 2, child: Text('Single Pulse')),
                    DropdownMenuItem(value: 3, child: Text('Manual')),
                  ],
                  onChanged: (v) => setState(() => _fillingJogMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingJogDuration.toString(),
                  decoration: const InputDecoration(labelText: 'Jog Duration'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingJogDuration =
                        double.tryParse(v) ?? _fillingJogDuration,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingJogPauseTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Jog Pause Time',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingJogPauseTime =
                        double.tryParse(v) ?? _fillingJogPauseTime,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingJogMaxCycles.toString(),
                  decoration: const InputDecoration(labelText: 'Max Cycles'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingJogMaxCycles =
                        int.tryParse(v) ?? _fillingJogMaxCycles,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Refill',
              children: [
                TextFormField(
                  initialValue: _fillingRefillUpperLimit.toString(),
                  decoration: const InputDecoration(labelText: 'Upper Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingRefillUpperLimit =
                        double.tryParse(v) ?? _fillingRefillUpperLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingRefillLowerLimit.toString(),
                  decoration: const InputDecoration(labelText: 'Lower Limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingRefillLowerLimit =
                        double.tryParse(v) ?? _fillingRefillLowerLimit,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Emptying',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingEmptyingCompleteMode,
                  decoration: const InputDecoration(labelText: 'Complete Mode'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Residual Weight')),
                    DropdownMenuItem(value: 1, child: Text('Time')),
                  ],
                  onChanged: (v) =>
                      setState(() => _fillingEmptyingCompleteMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingResidualWeight.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Residual Weight',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingEmptyingResidualWeight =
                        double.tryParse(v) ?? _fillingEmptyingResidualWeight,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingCompletionTime.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Completion Time',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingEmptyingCompletionTime =
                        double.tryParse(v) ?? _fillingEmptyingCompletionTime,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Events',
              children: [
                TextFormField(
                  initialValue: _fillingInitialFeedTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Initial Feed Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingInitialFeedTimeout =
                        double.tryParse(v) ?? _fillingInitialFeedTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Emptying Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingEmptyingTimeout =
                        double.tryParse(v) ?? _fillingEmptyingTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingRefillTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Refill Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingRefillTimeout =
                        double.tryParse(v) ?? _fillingRefillTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingProcessTimeout.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Process Timeout',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingProcessTimeout =
                        double.tryParse(v) ?? _fillingProcessTimeout,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: 'Advanced',
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingCycleConfirm,
                  decoration: const InputDecoration(labelText: 'Cycle Confirm'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Disabled')),
                    DropdownMenuItem(value: 1, child: Text('Every')),
                    DropdownMenuItem(value: 2, child: Text('Out of Tolerance')),
                  ],
                  onChanged: (v) => setState(() => _fillingCycleConfirm = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _fillingFastRecovery,
                  decoration: const InputDecoration(labelText: 'Fast Recovery'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Auto')),
                    DropdownMenuItem(value: 1, child: Text('Static')),
                    DropdownMenuItem(value: 2, child: Text('Disabled')),
                  ],
                  onChanged: (v) => setState(() => _fillingFastRecovery = v!),
                ),
                SwitchListTile(
                  title: const Text('Interlock Enabled'),
                  value: _fillingInterlockEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setState(() => _fillingInterlockEnabled = v),
                ),
                TextFormField(
                  initialValue: _fillingFastFeedSpeed.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fast Feed Speed',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFastFeedSpeed =
                        double.tryParse(v) ?? _fillingFastFeedSpeed,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFineFeedSpeed.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Fine Feed Speed',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFineFeedSpeed =
                        double.tryParse(v) ?? _fillingFineFeedSpeed,
                  ),
                ),
              ],
            ),
          ],
        ],

          // DIO 离散输入自定义映射（所有应用类型共用）
          _buildDioInputConfigCard(context),
        ],
      ),
    );
  }

  Widget _buildDioInputConfigCard(BuildContext context) {
    // 16个硬件位可供选择，-1 = 未映射
    const bitOptions = [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    String bitLabel(int bit) => bit < 0 ? 'None' : 'Bit $bit';

    DropdownButtonFormField<int> bitDropdown(
        String label, int value, ValueChanged<int?> onChanged) {
      return DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: bitOptions
            .map((b) => DropdownMenuItem(value: b, child: Text(bitLabel(b))))
            .toList(),
        onChanged: onChanged,
      );
    }

    return _buildExpandableCard(
      context: context,
      title: 'Discrete Input Mapping',
      children: [
        bitDropdown('Start', _dioConfig.start,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: v ?? _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Stop', _dioConfig.stop,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: v ?? _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Execute Refill', _dioConfig.executeRefill,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: v ?? _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Trigger Emptying', _dioConfig.triggerEmptying,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: v ?? _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Interlock', _dioConfig.interlock,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: v ?? _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Tare', _dioConfig.tare,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: v ?? _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Zero', _dioConfig.zero,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: v ?? _dioConfig.zero,
                  jogTrigger: _dioConfig.jogTrigger,
                ))),
        bitDropdown('Jog Trigger', _dioConfig.jogTrigger,
            (v) => setState(() => _dioConfig = DioInputConfig(
                  start: _dioConfig.start,
                  stop: _dioConfig.stop,
                  executeRefill: _dioConfig.executeRefill,
                  triggerEmptying: _dioConfig.triggerEmptying,
                  interlock: _dioConfig.interlock,
                  tare: _dioConfig.tare,
                  zero: _dioConfig.zero,
                  jogTrigger: v ?? _dioConfig.jogTrigger,
                ))),
      ],
    );
  }

  // 辅助方法：生成支持默认折叠的卡片
  Widget _buildExpandableCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias, // 让点击展开的波纹效果限制在圆角内
      child: ExpansionTile(
        initiallyExpanded: false, // 默认折叠
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
