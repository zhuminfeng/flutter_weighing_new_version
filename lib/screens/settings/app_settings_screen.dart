import 'package:flutter/material.dart';
import 'package:weighing_system_elinux/weighing_system_elinux.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';

class AppSettingsScreen extends StatefulWidget {
  final int? subsystemId;
  const AppSettingsScreen({super.key, this.subsystemId});

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppStateProvider.of(context);
    final subId = widget.subsystemId ?? state.activeSubsystemId;
    _appType = state.selectedAppType;

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

  Future<void> _save() async {
    final state = AppStateProvider.of(context);
    final subId = widget.subsystemId ?? state.activeSubsystemId;

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.save)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 强制声明解包获取生成的本地化实例
    final l = AppLocalizations.of(context)!;

    // 动态生成多语言下拉菜单文本
    final appTypeLabels = [l.lossInWeight, l.filling];
    final liwModeLabels = [l.continuous, l.batch, l.systemId];
    final liwSubModeLabels = [l.flowControl, l.fixedFrequency];
    final fillingWorkModeLabels = [
      l.fill,
      l.fillEmpty,
      l.dispense,
      l.refillDispense,
      l.absoluteValue,
    ];
    final powerFailLabels = [l.idle, l.pause];
    final startDelayLabels = [l.disabled, l.min5, l.min15, l.min30];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.appSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appSettings),
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
          // 1. App type selection
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: List.generate(
                  appTypeLabels.length,
                  (i) => ButtonSegment(value: i, label: Text(appTypeLabels[i])),
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
              title: l.baseConfig,
              children: [
                DropdownButtonFormField<int>(
                  value: _liwMode,
                  decoration: InputDecoration(labelText: l.mode),
                  items: List.generate(
                    liwModeLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(liwModeLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _liwMode = v!),
                ),
                if (_liwMode == 0)
                  DropdownButtonFormField<int>(
                    value: _liwSubMode,
                    decoration: InputDecoration(labelText: l.subMode),
                    items: List.generate(
                      liwSubModeLabels.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(liwSubModeLabels[i]),
                      ),
                    ),
                    onChanged: (v) => setState(() => _liwSubMode = v!),
                  ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: l.system,
              children: [
                TextFormField(
                  initialValue: _liwSafetyLimit.toString(),
                  decoration: InputDecoration(labelText: l.safetyLimit),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () =>
                        _liwSafetyLimit = double.tryParse(v) ?? _liwSafetyLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _liwHopperMin.toString(),
                  decoration: InputDecoration(labelText: l.hopperMin),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwHopperMin = double.tryParse(v) ?? _liwHopperMin,
                  ),
                ),
                TextFormField(
                  initialValue: _liwHopperMax.toString(),
                  decoration: InputDecoration(labelText: l.hopperMax),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwHopperMax = double.tryParse(v) ?? _liwHopperMax,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTargetFlow.toString(),
                  decoration: InputDecoration(labelText: l.targetFlow),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTargetFlow = double.tryParse(v) ?? _liwTargetFlow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTargetControlRate.toString(),
                  decoration: InputDecoration(labelText: l.targetControlRate),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTargetControlRate =
                        double.tryParse(v) ?? _liwTargetControlRate,
                  ),
                ),
                SwitchListTile(
                  title: Text(l.preRefill),
                  value: _liwPreRefill,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwPreRefill = v),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: l.systemId,
              children: [
                TextFormField(
                  initialValue: _liwAdjustRangeLower.toString(),
                  decoration: InputDecoration(labelText: l.adjustRangeLower),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwAdjustRangeLower =
                        double.tryParse(v) ?? _liwAdjustRangeLower,
                  ),
                ),
                TextFormField(
                  initialValue: _liwAdjustRangeUpper.toString(),
                  decoration: InputDecoration(labelText: l.adjustRangeUpper),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwAdjustRangeUpper =
                        double.tryParse(v) ?? _liwAdjustRangeUpper,
                  ),
                ),
                SwitchListTile(
                  title: Text(l.smartStepControl),
                  value: _liwSmartStepControl,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwSmartStepControl = v),
                ),
                TextFormField(
                  initialValue: _liwStepDuration.toString(),
                  decoration: InputDecoration(labelText: l.stepDuration),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwStepDuration =
                        double.tryParse(v) ?? _liwStepDuration,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFilterWindowSysId.toString(),
                  decoration: InputDecoration(labelText: l.filterWindowSysId),
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
              title: l.controller,
              children: [
                DropdownButtonFormField<int>(
                  value: _liwTuningMode,
                  decoration: InputDecoration(labelText: l.tuningMode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.auto)),
                    DropdownMenuItem(value: 1, child: Text(l.manual)),
                  ],
                  onChanged: (v) => setState(() => _liwTuningMode = v!),
                ),
                TextFormField(
                  initialValue: _liwFilterWindowCtrl.toString(),
                  decoration: InputDecoration(labelText: l.filterWindowCtrl),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFilterWindowCtrl =
                        double.tryParse(v) ?? _liwFilterWindowCtrl,
                  ),
                ),
                TextFormField(
                  initialValue: _liwKp.toString(),
                  decoration: InputDecoration(labelText: l.kp),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKp = double.tryParse(v) ?? _liwKp),
                ),
                TextFormField(
                  initialValue: _liwKi.toString(),
                  decoration: InputDecoration(labelText: l.ki),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKi = double.tryParse(v) ?? _liwKi),
                ),
                TextFormField(
                  initialValue: _liwKd.toString(),
                  decoration: InputDecoration(labelText: l.kd),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _liwKd = double.tryParse(v) ?? _liwKd),
                ),
                TextFormField(
                  initialValue: _liwMaxFlow.toString(),
                  decoration: InputDecoration(labelText: l.maxFlow),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwMaxFlow = double.tryParse(v) ?? _liwMaxFlow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwStartupTime.toString(),
                  decoration: InputDecoration(labelText: l.startupTime),
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
              title: l.refill,
              children: [
                DropdownButtonFormField<int>(
                  value: _liwRefillMode,
                  decoration: InputDecoration(labelText: l.mode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.auto)),
                    DropdownMenuItem(value: 1, child: Text(l.manual)),
                  ],
                  onChanged: (v) => setState(() => _liwRefillMode = v!),
                ),
                TextFormField(
                  initialValue: _liwLowerLimit.toString(),
                  decoration: InputDecoration(labelText: l.lowerLimit),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwLowerLimit = double.tryParse(v) ?? _liwLowerLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _liwUpperLimit.toString(),
                  decoration: InputDecoration(labelText: l.upperLimit),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwUpperLimit = double.tryParse(v) ?? _liwUpperLimit,
                  ),
                ),
                DropdownButtonFormField<int>(
                  value: _liwRefillControlMode,
                  decoration: InputDecoration(labelText: l.controlMode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.fixed)),
                    DropdownMenuItem(value: 1, child: Text(l.lastFreq)),
                    DropdownMenuItem(value: 2, child: Text(l.smart)),
                  ],
                  onChanged: (v) => setState(() => _liwRefillControlMode = v!),
                ),
                TextFormField(
                  initialValue: _liwRefillControlSetpoint.toString(),
                  decoration: InputDecoration(labelText: l.controlSetpoint),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwRefillControlSetpoint =
                        double.tryParse(v) ?? _liwRefillControlSetpoint,
                  ),
                ),
                TextFormField(
                  initialValue: _liwRefillStabilizeTime.toString(),
                  decoration: InputDecoration(labelText: l.stabilizeTime),
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
              title: l.targetValues,
              children: [
                TextFormField(
                  initialValue: _liwBatchTarget.toString(),
                  decoration: InputDecoration(labelText: l.batchTarget),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () =>
                        _liwBatchTarget = double.tryParse(v) ?? _liwBatchTarget,
                  ),
                ),
                TextFormField(
                  initialValue: _liwInFlight.toString(),
                  decoration: InputDecoration(labelText: l.inFlight),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwInFlight = double.tryParse(v) ?? _liwInFlight,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFineFeedThreshold.toString(),
                  decoration: InputDecoration(labelText: l.fineFeedThreshold),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwFineFeedThreshold =
                        double.tryParse(v) ?? _liwFineFeedThreshold,
                  ),
                ),
                TextFormField(
                  initialValue: _liwFineFeedFlow.toString(),
                  decoration: InputDecoration(labelText: l.fineFeedFlow),
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
              title: l.toleranceCheck,
              children: [
                TextFormField(
                  initialValue: _liwPreCheckDelay.toString(),
                  decoration: InputDecoration(labelText: l.preCheckDelay),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwPreCheckDelay =
                        double.tryParse(v) ?? _liwPreCheckDelay,
                  ),
                ),
                TextFormField(
                  initialValue: _liwStabilityTimeout.toString(),
                  decoration: InputDecoration(labelText: l.stabilityTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwStabilityTimeout =
                        double.tryParse(v) ?? _liwStabilityTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _liwTolerance.toString(),
                  decoration: InputDecoration(labelText: l.tolerance),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwTolerance = double.tryParse(v) ?? _liwTolerance,
                  ),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: l.emptying,
              children: [
                SwitchListTile(
                  title: Text(l.autoStopAtAlarm),
                  value: _liwAutoStopAtAlarm,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwAutoStopAtAlarm = v),
                ),
                TextFormField(
                  initialValue: _liwEmptyingControlSetpoint.toString(),
                  decoration: InputDecoration(labelText: l.controlSetpoint),
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
              title: l.warningConfig,
              children: [
                TextFormField(
                  initialValue: _liwControlRateLower.toString(),
                  decoration: InputDecoration(labelText: l.controlRateLower),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwControlRateLower =
                        double.tryParse(v) ?? _liwControlRateLower,
                  ),
                ),
                TextFormField(
                  initialValue: _liwControlRateUpper.toString(),
                  decoration: InputDecoration(labelText: l.controlRateUpper),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwControlRateUpper =
                        double.tryParse(v) ?? _liwControlRateUpper,
                  ),
                ),
                TextFormField(
                  initialValue: _liwRefillTimeout.toString(),
                  decoration: InputDecoration(labelText: l.refillTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwRefillTimeout =
                        double.tryParse(v) ?? _liwRefillTimeout,
                  ),
                ),
                SwitchListTile(
                  title: Text(l.stopOnError),
                  value: _liwStopOnError,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwStopOnError = v),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: l.flowMonitor,
              children: [
                TextFormField(
                  initialValue: _liwEvaluationWindow.toString(),
                  decoration: InputDecoration(labelText: l.evaluationWindow),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwEvaluationWindow =
                        double.tryParse(v) ?? _liwEvaluationWindow,
                  ),
                ),
                TextFormField(
                  initialValue: _liwDeviationThreshold.toString(),
                  decoration: InputDecoration(labelText: l.deviationThreshold),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwDeviationThreshold =
                        double.tryParse(v) ?? _liwDeviationThreshold,
                  ),
                ),
                TextFormField(
                  initialValue: _liwSurgeThreshold.toString(),
                  decoration: InputDecoration(labelText: l.surgeThreshold),
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
              title: l.advancedConfig,
              children: [
                SwitchListTile(
                  title: Text(l.interlockEnabled),
                  value: _liwInterlockEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _liwInterlockEnabled = v),
                ),
                TextFormField(
                  initialValue: _liwInterlockDelay.toString(),
                  decoration: InputDecoration(labelText: l.interlockDelay),
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
              title: l.stats,
              children: [
                TextFormField(
                  initialValue: _liwSamplePeriod.toString(),
                  decoration: InputDecoration(labelText: l.samplePeriod),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _liwSamplePeriod =
                        double.tryParse(v) ?? _liwSamplePeriod,
                  ),
                ),
                TextFormField(
                  initialValue: _liwSampleTolerance.toString(),
                  decoration: InputDecoration(labelText: l.sampleTolerance),
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
              title: l.general,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingWorkMode,
                  decoration: InputDecoration(labelText: l.workMode),
                  items: List.generate(
                    fillingWorkModeLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(fillingWorkModeLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _fillingWorkMode = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _powerFailRecovery,
                  decoration: InputDecoration(labelText: l.powerFailRecovery),
                  items: List.generate(
                    powerFailLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(powerFailLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _powerFailRecovery = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _startDelay,
                  decoration: InputDecoration(labelText: l.startDelay),
                  items: List.generate(
                    startDelayLabels.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(startDelayLabels[i]),
                    ),
                  ),
                  onChanged: (v) => setState(() => _startDelay = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _fillingFeedSpeed,
                  decoration: InputDecoration(labelText: l.feedSpeed),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.single)),
                    DropdownMenuItem(value: 1, child: Text(l.dual)),
                  ],
                  onChanged: (v) => setState(() => _fillingFeedSpeed = v!),
                ),
              ],
            ),
            _buildExpandableCard(
              context: context,
              title: l.target,
              children: [
                TextFormField(
                  initialValue: _fillingTargetValue.toString(),
                  decoration: InputDecoration(labelText: l.targetValue),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingTargetValue =
                        double.tryParse(v) ?? _fillingTargetValue,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingInFlight.toString(),
                  decoration: InputDecoration(labelText: l.inFlight),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingInFlight =
                        double.tryParse(v) ?? _fillingInFlight,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFeed.toString(),
                  decoration: InputDecoration(labelText: l.feed),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFeed = double.tryParse(v) ?? _fillingFeed,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFeedInhibitTime.toString(),
                  decoration: InputDecoration(labelText: l.feedInhibitTime),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFeedInhibitTime =
                        double.tryParse(v) ?? _fillingFeedInhibitTime,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFastFeedInhibitTime.toString(),
                  decoration: InputDecoration(labelText: l.fastFeedInhibitTime),
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
              title: l.autoTare,
              children: [
                SwitchListTile(
                  title: Text(l.autoTareEnabled),
                  value: _fillingAutoTareEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _fillingAutoTareEnabled = v),
                ),
                TextFormField(
                  initialValue: _fillingContainerTareUpper.toString(),
                  decoration: InputDecoration(labelText: l.containerTareUpper),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingContainerTareUpper =
                        double.tryParse(v) ?? _fillingContainerTareUpper,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingContainerTareLower.toString(),
                  decoration: InputDecoration(labelText: l.containerTareLower),
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
              title: l.tolerance,
              children: [
                TextFormField(
                  initialValue: _fillingPreCheckDelay.toString(),
                  decoration: InputDecoration(labelText: l.preCheckDelay),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingPreCheckDelay =
                        double.tryParse(v) ?? _fillingPreCheckDelay,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingStabilityTimeout.toString(),
                  decoration: InputDecoration(labelText: l.stabilityTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingStabilityTimeout =
                        double.tryParse(v) ?? _fillingStabilityTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingPositiveTolerance.toString(),
                  decoration: InputDecoration(labelText: l.positiveTolerance),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingPositiveTolerance =
                        double.tryParse(v) ?? _fillingPositiveTolerance,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingNegativeTolerance.toString(),
                  decoration: InputDecoration(labelText: l.negativeTolerance),
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
              title: l.spillOpt,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingSpillMode,
                  decoration: InputDecoration(labelText: l.mode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.disabled)),
                    DropdownMenuItem(value: 1, child: Text(l.auto)),
                    DropdownMenuItem(value: 2, child: Text(l.manual)),
                  ],
                  onChanged: (v) => setState(() => _fillingSpillMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustRange.toString(),
                  decoration: InputDecoration(labelText: l.adjustRange),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingSpillAdjustRange =
                        double.tryParse(v) ?? _fillingSpillAdjustRange,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustSamples.toString(),
                  decoration: InputDecoration(labelText: l.adjustSamples),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingSpillAdjustSamples =
                        int.tryParse(v) ?? _fillingSpillAdjustSamples,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingSpillAdjustFactor.toString(),
                  decoration: InputDecoration(labelText: l.adjustFactor),
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
              title: l.cutoffOpt,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingCutoffMode,
                  decoration: InputDecoration(labelText: l.mode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.disabled)),
                    DropdownMenuItem(value: 1, child: Text(l.auto)),
                    DropdownMenuItem(value: 2, child: Text(l.manual)),
                  ],
                  onChanged: (v) => setState(() => _fillingCutoffMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingCutoffReliabilityRange.toString(),
                  decoration: InputDecoration(
                    labelText: l.controlReliabilityRange,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingCutoffReliabilityRange =
                        double.tryParse(v) ?? _fillingCutoffReliabilityRange,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingCutoffAdjustCycles.toString(),
                  decoration: InputDecoration(labelText: l.adjustCycles),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingCutoffAdjustCycles =
                        int.tryParse(v) ?? _fillingCutoffAdjustCycles,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingCutoffAdjustFactor.toString(),
                  decoration: InputDecoration(labelText: l.adjustFactor),
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
              title: l.jog,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingJogMode,
                  decoration: InputDecoration(labelText: l.mode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.disabled)),
                    DropdownMenuItem(value: 1, child: Text(l.auto)),
                    DropdownMenuItem(value: 2, child: Text(l.singlePulse)),
                    DropdownMenuItem(value: 3, child: Text(l.manual)),
                  ],
                  onChanged: (v) => setState(() => _fillingJogMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingJogDuration.toString(),
                  decoration: InputDecoration(labelText: l.jogDuration),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingJogDuration =
                        double.tryParse(v) ?? _fillingJogDuration,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingJogPauseTime.toString(),
                  decoration: InputDecoration(labelText: l.jogPauseTime),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingJogPauseTime =
                        double.tryParse(v) ?? _fillingJogPauseTime,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingJogMaxCycles.toString(),
                  decoration: InputDecoration(labelText: l.maxCycles),
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
              title: l.refill,
              children: [
                TextFormField(
                  initialValue: _fillingRefillUpperLimit.toString(),
                  decoration: InputDecoration(labelText: l.upperLimit),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingRefillUpperLimit =
                        double.tryParse(v) ?? _fillingRefillUpperLimit,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingRefillLowerLimit.toString(),
                  decoration: InputDecoration(labelText: l.lowerLimit),
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
              title: l.emptying,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingEmptyingCompleteMode,
                  decoration: InputDecoration(labelText: l.completeMode),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.residualWeight)),
                    DropdownMenuItem(value: 1, child: Text(l.time)),
                  ],
                  onChanged: (v) =>
                      setState(() => _fillingEmptyingCompleteMode = v!),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingResidualWeight.toString(),
                  decoration: InputDecoration(labelText: l.residualWeight),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingEmptyingResidualWeight =
                        double.tryParse(v) ?? _fillingEmptyingResidualWeight,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingCompletionTime.toString(),
                  decoration: InputDecoration(labelText: l.completionTime),
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
              title: l.events,
              children: [
                TextFormField(
                  initialValue: _fillingInitialFeedTimeout.toString(),
                  decoration: InputDecoration(labelText: l.initialFeedTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingInitialFeedTimeout =
                        double.tryParse(v) ?? _fillingInitialFeedTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingEmptyingTimeout.toString(),
                  decoration: InputDecoration(labelText: l.emptyingTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingEmptyingTimeout =
                        double.tryParse(v) ?? _fillingEmptyingTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingRefillTimeout.toString(),
                  decoration: InputDecoration(labelText: l.refillTimeout),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingRefillTimeout =
                        double.tryParse(v) ?? _fillingRefillTimeout,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingProcessTimeout.toString(),
                  decoration: InputDecoration(labelText: l.processTimeout),
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
              title: l.advancedConfig,
              children: [
                DropdownButtonFormField<int>(
                  value: _fillingCycleConfirm,
                  decoration: InputDecoration(labelText: l.cycleConfirm),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.disabled)),
                    DropdownMenuItem(value: 1, child: Text(l.every)),
                    DropdownMenuItem(value: 2, child: Text(l.outOfTolerance)),
                  ],
                  onChanged: (v) => setState(() => _fillingCycleConfirm = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _fillingFastRecovery,
                  decoration: InputDecoration(labelText: l.fastRecovery),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.auto)),
                    DropdownMenuItem(value: 1, child: Text(l.staticVal)),
                    DropdownMenuItem(value: 2, child: Text(l.disabled)),
                  ],
                  onChanged: (v) => setState(() => _fillingFastRecovery = v!),
                ),
                SwitchListTile(
                  title: Text(l.interlockEnabled),
                  value: _fillingInterlockEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setState(() => _fillingInterlockEnabled = v),
                ),
                TextFormField(
                  initialValue: _fillingFastFeedSpeed.toString(),
                  decoration: InputDecoration(labelText: l.fastFeedSpeed),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(
                    () => _fillingFastFeedSpeed =
                        double.tryParse(v) ?? _fillingFastFeedSpeed,
                  ),
                ),
                TextFormField(
                  initialValue: _fillingFineFeedSpeed.toString(),
                  decoration: InputDecoration(labelText: l.fineFeedSpeed),
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
      ),
    );
  }

  Widget _buildExpandableCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
