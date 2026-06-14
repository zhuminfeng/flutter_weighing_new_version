import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Function Weighing System'**
  String get appTitle;

  /// No description provided for @lossInWeight.
  ///
  /// In en, this message translates to:
  /// **'Loss-in-Weight'**
  String get lossInWeight;

  /// No description provided for @filling.
  ///
  /// In en, this message translates to:
  /// **'Filling / Dispensing'**
  String get filling;

  /// No description provided for @selectApp.
  ///
  /// In en, this message translates to:
  /// **'Select Application'**
  String get selectApp;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @scaleSettings.
  ///
  /// In en, this message translates to:
  /// **'Scale Settings'**
  String get scaleSettings;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'Application Settings'**
  String get appSettings;

  /// No description provided for @calibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibration;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter & Stability'**
  String get filter;

  /// No description provided for @continuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get continuous;

  /// No description provided for @batch.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get batch;

  /// No description provided for @systemId.
  ///
  /// In en, this message translates to:
  /// **'System Identification'**
  String get systemId;

  /// No description provided for @flowControl.
  ///
  /// In en, this message translates to:
  /// **'Flow Control'**
  String get flowControl;

  /// No description provided for @fixedFrequency.
  ///
  /// In en, this message translates to:
  /// **'Fixed Frequency'**
  String get fixedFrequency;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @zero.
  ///
  /// In en, this message translates to:
  /// **'Zero'**
  String get zero;

  /// No description provided for @tare.
  ///
  /// In en, this message translates to:
  /// **'Tare'**
  String get tare;

  /// No description provided for @clearTare.
  ///
  /// In en, this message translates to:
  /// **'Clear Tare'**
  String get clearTare;

  /// No description provided for @presetTare.
  ///
  /// In en, this message translates to:
  /// **'Preset Tare'**
  String get presetTare;

  /// No description provided for @eprint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get eprint;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @grossWeight.
  ///
  /// In en, this message translates to:
  /// **'Gross Weight'**
  String get grossWeight;

  /// No description provided for @netWeight.
  ///
  /// In en, this message translates to:
  /// **'Net Weight'**
  String get netWeight;

  /// No description provided for @tareWeight.
  ///
  /// In en, this message translates to:
  /// **'Tare Weight'**
  String get tareWeight;

  /// No description provided for @flow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get flow;

  /// No description provided for @currentFlow.
  ///
  /// In en, this message translates to:
  /// **'Current Flow'**
  String get currentFlow;

  /// No description provided for @targetFlow.
  ///
  /// In en, this message translates to:
  /// **'Target Flow'**
  String get targetFlow;

  /// No description provided for @controlRate.
  ///
  /// In en, this message translates to:
  /// **'Control Rate'**
  String get controlRate;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

  /// No description provided for @inMotion.
  ///
  /// In en, this message translates to:
  /// **'In Motion'**
  String get inMotion;

  /// No description provided for @overload.
  ///
  /// In en, this message translates to:
  /// **'Overload'**
  String get overload;

  /// No description provided for @underload.
  ///
  /// In en, this message translates to:
  /// **'Underload'**
  String get underload;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @refilling.
  ///
  /// In en, this message translates to:
  /// **'Refilling'**
  String get refilling;

  /// No description provided for @emptying.
  ///
  /// In en, this message translates to:
  /// **'Emptying'**
  String get emptying;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacity;

  /// No description provided for @division.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get division;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @overloadRange.
  ///
  /// In en, this message translates to:
  /// **'Overload Range'**
  String get overloadRange;

  /// No description provided for @autoZeroTracking.
  ///
  /// In en, this message translates to:
  /// **'Auto Zero Tracking'**
  String get autoZeroTracking;

  /// No description provided for @zeroConfig.
  ///
  /// In en, this message translates to:
  /// **'Zero Configuration'**
  String get zeroConfig;

  /// No description provided for @tareConfig.
  ///
  /// In en, this message translates to:
  /// **'Tare Configuration'**
  String get tareConfig;

  /// No description provided for @calZero.
  ///
  /// In en, this message translates to:
  /// **'Zero Calibration'**
  String get calZero;

  /// No description provided for @calSpan.
  ///
  /// In en, this message translates to:
  /// **'Span Calibration'**
  String get calSpan;

  /// No description provided for @calStep.
  ///
  /// In en, this message translates to:
  /// **'Step Calibration'**
  String get calStep;

  /// No description provided for @calStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get calStart;

  /// No description provided for @calSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get calSave;

  /// No description provided for @calAbort.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get calAbort;

  /// No description provided for @calComplete.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get calComplete;

  /// No description provided for @calFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get calFailed;

  /// No description provided for @calInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get calInProgress;

  /// No description provided for @calDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Completed'**
  String get calDynamic;

  /// No description provided for @lowPassFilter.
  ///
  /// In en, this message translates to:
  /// **'Low-Pass Filter'**
  String get lowPassFilter;

  /// No description provided for @notchFilter.
  ///
  /// In en, this message translates to:
  /// **'Notch Filter'**
  String get notchFilter;

  /// No description provided for @adaptiveFilter.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Filter'**
  String get adaptiveFilter;

  /// No description provided for @stability.
  ///
  /// In en, this message translates to:
  /// **'Stability'**
  String get stability;

  /// No description provided for @motionRange.
  ///
  /// In en, this message translates to:
  /// **'Motion Range'**
  String get motionRange;

  /// No description provided for @motionDetectTime.
  ///
  /// In en, this message translates to:
  /// **'Motion Detect Time'**
  String get motionDetectTime;

  /// No description provided for @stabilityTimeout.
  ///
  /// In en, this message translates to:
  /// **'Stability Timeout'**
  String get stabilityTimeout;

  /// No description provided for @systemConfig.
  ///
  /// In en, this message translates to:
  /// **'System Configuration'**
  String get systemConfig;

  /// No description provided for @controllerConfig.
  ///
  /// In en, this message translates to:
  /// **'Controller Configuration'**
  String get controllerConfig;

  /// No description provided for @refillConfig.
  ///
  /// In en, this message translates to:
  /// **'Refill Configuration'**
  String get refillConfig;

  /// No description provided for @targetValues.
  ///
  /// In en, this message translates to:
  /// **'Target Values'**
  String get targetValues;

  /// No description provided for @toleranceCheck.
  ///
  /// In en, this message translates to:
  /// **'Tolerance Check'**
  String get toleranceCheck;

  /// No description provided for @emptyingConfig.
  ///
  /// In en, this message translates to:
  /// **'Emptying Configuration'**
  String get emptyingConfig;

  /// No description provided for @warningConfig.
  ///
  /// In en, this message translates to:
  /// **'Warning Configuration'**
  String get warningConfig;

  /// No description provided for @advancedConfig.
  ///
  /// In en, this message translates to:
  /// **'Advanced Configuration'**
  String get advancedConfig;

  /// No description provided for @statisticsConfig.
  ///
  /// In en, this message translates to:
  /// **'Statistics Configuration'**
  String get statisticsConfig;

  /// No description provided for @flowMonitor.
  ///
  /// In en, this message translates to:
  /// **'Flow Monitoring'**
  String get flowMonitor;

  /// No description provided for @fillMode.
  ///
  /// In en, this message translates to:
  /// **'Fill Mode'**
  String get fillMode;

  /// No description provided for @fillEmpty.
  ///
  /// In en, this message translates to:
  /// **'Fill / Empty'**
  String get fillEmpty;

  /// No description provided for @dispense.
  ///
  /// In en, this message translates to:
  /// **'Dispense'**
  String get dispense;

  /// No description provided for @refillDispense.
  ///
  /// In en, this message translates to:
  /// **'Refill / Dispense'**
  String get refillDispense;

  /// No description provided for @absoluteValue.
  ///
  /// In en, this message translates to:
  /// **'Absolute Value'**
  String get absoluteValue;

  /// No description provided for @autoTare.
  ///
  /// In en, this message translates to:
  /// **'Auto Tare'**
  String get autoTare;

  /// No description provided for @spillOpt.
  ///
  /// In en, this message translates to:
  /// **'Spill Optimization'**
  String get spillOpt;

  /// No description provided for @cutoffOpt.
  ///
  /// In en, this message translates to:
  /// **'Cutoff Optimization'**
  String get cutoffOpt;

  /// No description provided for @jog.
  ///
  /// In en, this message translates to:
  /// **'Fine-Tune (Jog)'**
  String get jog;

  /// No description provided for @refill.
  ///
  /// In en, this message translates to:
  /// **'Refill'**
  String get refill;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events & Warnings'**
  String get events;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @accumulatedWeight.
  ///
  /// In en, this message translates to:
  /// **'Accumulated Weight'**
  String get accumulatedWeight;

  /// No description provided for @totalAccumulated.
  ///
  /// In en, this message translates to:
  /// **'Total Accumulated'**
  String get totalAccumulated;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Remaining Time'**
  String get remainingTime;

  /// No description provided for @batchTarget.
  ///
  /// In en, this message translates to:
  /// **'Batch Target'**
  String get batchTarget;

  /// No description provided for @inFlight.
  ///
  /// In en, this message translates to:
  /// **'In-Flight'**
  String get inFlight;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get auto;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @digitalOutputMapping.
  ///
  /// In en, this message translates to:
  /// **'Digital Output Mapping'**
  String get digitalOutputMapping;

  /// No description provided for @doBitRouting.
  ///
  /// In en, this message translates to:
  /// **'DO bit routing / subsystem mapping'**
  String get doBitRouting;

  /// No description provided for @baseConfig.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get baseConfig;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @controller.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get controller;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @subMode.
  ///
  /// In en, this message translates to:
  /// **'Sub-Mode'**
  String get subMode;

  /// No description provided for @safetyLimit.
  ///
  /// In en, this message translates to:
  /// **'Safety Limit'**
  String get safetyLimit;

  /// No description provided for @hopperMin.
  ///
  /// In en, this message translates to:
  /// **'Hopper Min'**
  String get hopperMin;

  /// No description provided for @hopperMax.
  ///
  /// In en, this message translates to:
  /// **'Hopper Max'**
  String get hopperMax;

  /// No description provided for @targetControlRate.
  ///
  /// In en, this message translates to:
  /// **'Target Control Rate'**
  String get targetControlRate;

  /// No description provided for @preRefill.
  ///
  /// In en, this message translates to:
  /// **'Pre Refill'**
  String get preRefill;

  /// No description provided for @adjustRangeLower.
  ///
  /// In en, this message translates to:
  /// **'Adjust Range Lower'**
  String get adjustRangeLower;

  /// No description provided for @adjustRangeUpper.
  ///
  /// In en, this message translates to:
  /// **'Adjust Range Upper'**
  String get adjustRangeUpper;

  /// No description provided for @smartStepControl.
  ///
  /// In en, this message translates to:
  /// **'Smart Step Control'**
  String get smartStepControl;

  /// No description provided for @stepDuration.
  ///
  /// In en, this message translates to:
  /// **'Step Duration'**
  String get stepDuration;

  /// No description provided for @filterWindowSysId.
  ///
  /// In en, this message translates to:
  /// **'Filter Window (SysId)'**
  String get filterWindowSysId;

  /// No description provided for @tuningMode.
  ///
  /// In en, this message translates to:
  /// **'Tuning Mode'**
  String get tuningMode;

  /// No description provided for @filterWindowCtrl.
  ///
  /// In en, this message translates to:
  /// **'Filter Window (Ctrl)'**
  String get filterWindowCtrl;

  /// No description provided for @kp.
  ///
  /// In en, this message translates to:
  /// **'Kp'**
  String get kp;

  /// No description provided for @ki.
  ///
  /// In en, this message translates to:
  /// **'Ki'**
  String get ki;

  /// No description provided for @kd.
  ///
  /// In en, this message translates to:
  /// **'Kd'**
  String get kd;

  /// No description provided for @maxFlow.
  ///
  /// In en, this message translates to:
  /// **'Max Flow'**
  String get maxFlow;

  /// No description provided for @startupTime.
  ///
  /// In en, this message translates to:
  /// **'Startup Time'**
  String get startupTime;

  /// No description provided for @lowerLimit.
  ///
  /// In en, this message translates to:
  /// **'Lower Limit'**
  String get lowerLimit;

  /// No description provided for @upperLimit.
  ///
  /// In en, this message translates to:
  /// **'Upper Limit'**
  String get upperLimit;

  /// No description provided for @controlMode.
  ///
  /// In en, this message translates to:
  /// **'Control Mode'**
  String get controlMode;

  /// No description provided for @fixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get fixed;

  /// No description provided for @lastFreq.
  ///
  /// In en, this message translates to:
  /// **'Last Freq'**
  String get lastFreq;

  /// No description provided for @smart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get smart;

  /// No description provided for @controlSetpoint.
  ///
  /// In en, this message translates to:
  /// **'Control Setpoint'**
  String get controlSetpoint;

  /// No description provided for @stabilizeTime.
  ///
  /// In en, this message translates to:
  /// **'Stabilize Time'**
  String get stabilizeTime;

  /// No description provided for @fineFeedThreshold.
  ///
  /// In en, this message translates to:
  /// **'Fine Feed Threshold'**
  String get fineFeedThreshold;

  /// No description provided for @fineFeedFlow.
  ///
  /// In en, this message translates to:
  /// **'Fine Feed Flow'**
  String get fineFeedFlow;

  /// No description provided for @preCheckDelay.
  ///
  /// In en, this message translates to:
  /// **'Pre Check Delay'**
  String get preCheckDelay;

  /// No description provided for @tolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get tolerance;

  /// No description provided for @autoStopAtAlarm.
  ///
  /// In en, this message translates to:
  /// **'Auto Stop At Alarm'**
  String get autoStopAtAlarm;

  /// No description provided for @controlRateLower.
  ///
  /// In en, this message translates to:
  /// **'Control Rate Lower'**
  String get controlRateLower;

  /// No description provided for @controlRateUpper.
  ///
  /// In en, this message translates to:
  /// **'Control Rate Upper'**
  String get controlRateUpper;

  /// No description provided for @refillTimeout.
  ///
  /// In en, this message translates to:
  /// **'Refill Timeout'**
  String get refillTimeout;

  /// No description provided for @stopOnError.
  ///
  /// In en, this message translates to:
  /// **'Stop On Error'**
  String get stopOnError;

  /// No description provided for @evaluationWindow.
  ///
  /// In en, this message translates to:
  /// **'Evaluation Window'**
  String get evaluationWindow;

  /// No description provided for @deviationThreshold.
  ///
  /// In en, this message translates to:
  /// **'Deviation Threshold'**
  String get deviationThreshold;

  /// No description provided for @surgeThreshold.
  ///
  /// In en, this message translates to:
  /// **'Surge Threshold'**
  String get surgeThreshold;

  /// No description provided for @interlockEnabled.
  ///
  /// In en, this message translates to:
  /// **'Interlock Enabled'**
  String get interlockEnabled;

  /// No description provided for @interlockDelay.
  ///
  /// In en, this message translates to:
  /// **'Interlock Delay'**
  String get interlockDelay;

  /// No description provided for @samplePeriod.
  ///
  /// In en, this message translates to:
  /// **'Sample Period'**
  String get samplePeriod;

  /// No description provided for @sampleTolerance.
  ///
  /// In en, this message translates to:
  /// **'Sample Tolerance'**
  String get sampleTolerance;

  /// No description provided for @workMode.
  ///
  /// In en, this message translates to:
  /// **'Work Mode'**
  String get workMode;

  /// No description provided for @powerFailRecovery.
  ///
  /// In en, this message translates to:
  /// **'Power Fail Recovery'**
  String get powerFailRecovery;

  /// No description provided for @startDelay.
  ///
  /// In en, this message translates to:
  /// **'Start Delay'**
  String get startDelay;

  /// No description provided for @feedSpeed.
  ///
  /// In en, this message translates to:
  /// **'Feed Speed'**
  String get feedSpeed;

  /// No description provided for @single.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get single;

  /// No description provided for @dual.
  ///
  /// In en, this message translates to:
  /// **'Dual'**
  String get dual;

  /// No description provided for @targetValue.
  ///
  /// In en, this message translates to:
  /// **'Target Value'**
  String get targetValue;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @feedInhibitTime.
  ///
  /// In en, this message translates to:
  /// **'Feed Inhibit Time'**
  String get feedInhibitTime;

  /// No description provided for @fastFeedInhibitTime.
  ///
  /// In en, this message translates to:
  /// **'Fast Feed Inhibit Time'**
  String get fastFeedInhibitTime;

  /// No description provided for @autoTareEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto Tare Enabled'**
  String get autoTareEnabled;

  /// No description provided for @containerTareUpper.
  ///
  /// In en, this message translates to:
  /// **'Container Tare Upper'**
  String get containerTareUpper;

  /// No description provided for @containerTareLower.
  ///
  /// In en, this message translates to:
  /// **'Container Tare Lower'**
  String get containerTareLower;

  /// No description provided for @positiveTolerance.
  ///
  /// In en, this message translates to:
  /// **'Positive Tolerance'**
  String get positiveTolerance;

  /// No description provided for @negativeTolerance.
  ///
  /// In en, this message translates to:
  /// **'Negative Tolerance'**
  String get negativeTolerance;

  /// No description provided for @adjustRange.
  ///
  /// In en, this message translates to:
  /// **'Adjust Range'**
  String get adjustRange;

  /// No description provided for @adjustSamples.
  ///
  /// In en, this message translates to:
  /// **'Adjust Samples'**
  String get adjustSamples;

  /// No description provided for @adjustFactor.
  ///
  /// In en, this message translates to:
  /// **'Adjust Factor'**
  String get adjustFactor;

  /// No description provided for @controlReliabilityRange.
  ///
  /// In en, this message translates to:
  /// **'Control Reliability Range'**
  String get controlReliabilityRange;

  /// No description provided for @adjustCycles.
  ///
  /// In en, this message translates to:
  /// **'Adjust Cycles'**
  String get adjustCycles;

  /// No description provided for @singlePulse.
  ///
  /// In en, this message translates to:
  /// **'Single Pulse'**
  String get singlePulse;

  /// No description provided for @jogDuration.
  ///
  /// In en, this message translates to:
  /// **'Jog Duration'**
  String get jogDuration;

  /// No description provided for @jogPauseTime.
  ///
  /// In en, this message translates to:
  /// **'Jog Pause Time'**
  String get jogPauseTime;

  /// No description provided for @maxCycles.
  ///
  /// In en, this message translates to:
  /// **'Max Cycles'**
  String get maxCycles;

  /// No description provided for @completeMode.
  ///
  /// In en, this message translates to:
  /// **'Complete Mode'**
  String get completeMode;

  /// No description provided for @residualWeight.
  ///
  /// In en, this message translates to:
  /// **'Residual Weight'**
  String get residualWeight;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @completionTime.
  ///
  /// In en, this message translates to:
  /// **'Completion Time'**
  String get completionTime;

  /// No description provided for @initialFeedTimeout.
  ///
  /// In en, this message translates to:
  /// **'Initial Feed Timeout'**
  String get initialFeedTimeout;

  /// No description provided for @emptyingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Emptying Timeout'**
  String get emptyingTimeout;

  /// No description provided for @processTimeout.
  ///
  /// In en, this message translates to:
  /// **'Process Timeout'**
  String get processTimeout;

  /// No description provided for @cycleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cycle Confirm'**
  String get cycleConfirm;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @outOfTolerance.
  ///
  /// In en, this message translates to:
  /// **'Out of Tolerance'**
  String get outOfTolerance;

  /// No description provided for @fastRecovery.
  ///
  /// In en, this message translates to:
  /// **'Fast Recovery'**
  String get fastRecovery;

  /// No description provided for @staticVal.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get staticVal;

  /// No description provided for @fastFeedSpeed.
  ///
  /// In en, this message translates to:
  /// **'Fast Feed Speed'**
  String get fastFeedSpeed;

  /// No description provided for @fineFeedSpeed.
  ///
  /// In en, this message translates to:
  /// **'Fine Feed Speed'**
  String get fineFeedSpeed;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @min5.
  ///
  /// In en, this message translates to:
  /// **'5 min'**
  String get min5;

  /// No description provided for @min15.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get min15;

  /// No description provided for @min30.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get min30;

  /// No description provided for @fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get fill;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @calZeroInProgress.
  ///
  /// In en, this message translates to:
  /// **'Zero calibration in progress...'**
  String get calZeroInProgress;

  /// No description provided for @calZeroCompleted.
  ///
  /// In en, this message translates to:
  /// **'Zero calibration completed'**
  String get calZeroCompleted;

  /// No description provided for @calZeroFailed.
  ///
  /// In en, this message translates to:
  /// **'Zero calibration failed: '**
  String get calZeroFailed;

  /// No description provided for @invalidTestLoad.
  ///
  /// In en, this message translates to:
  /// **'Invalid test load'**
  String get invalidTestLoad;

  /// No description provided for @calSpanInProgress.
  ///
  /// In en, this message translates to:
  /// **'Span calibration in progress...'**
  String get calSpanInProgress;

  /// No description provided for @calSpanWaiting.
  ///
  /// In en, this message translates to:
  /// **'Span calibration - waiting for confirmation'**
  String get calSpanWaiting;

  /// No description provided for @calSpanFailed.
  ///
  /// In en, this message translates to:
  /// **'Span calibration failed: '**
  String get calSpanFailed;

  /// No description provided for @calSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Calibration saved successfully'**
  String get calSavedSuccess;

  /// No description provided for @calSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save calibration'**
  String get calSaveFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: '**
  String get saveFailed;

  /// No description provided for @calAborted.
  ///
  /// In en, this message translates to:
  /// **'Calibration aborted'**
  String get calAborted;

  /// No description provided for @invalidStepWeight.
  ///
  /// In en, this message translates to:
  /// **'Invalid step test weight'**
  String get invalidStepWeight;

  /// No description provided for @calStepStarted.
  ///
  /// In en, this message translates to:
  /// **'Step calibration started...'**
  String get calStepStarted;

  /// No description provided for @calStepFailed.
  ///
  /// In en, this message translates to:
  /// **'Step calibration failed: '**
  String get calStepFailed;

  /// No description provided for @linearDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled (Zero + 1 point)'**
  String get linearDisabled;

  /// No description provided for @linear3Point.
  ///
  /// In en, this message translates to:
  /// **'3-Point (Zero + Mid + High)'**
  String get linear3Point;

  /// No description provided for @linear4Point.
  ///
  /// In en, this message translates to:
  /// **'4-Point (Zero + Low + Mid + High)'**
  String get linear4Point;

  /// No description provided for @linear5Point.
  ///
  /// In en, this message translates to:
  /// **'5-Point (Zero + Low + Mid + MidHigh + High)'**
  String get linear5Point;

  /// No description provided for @clearScalePressStart.
  ///
  /// In en, this message translates to:
  /// **'Clear the scale platform and press Start.'**
  String get clearScalePressStart;

  /// No description provided for @linearCalibration.
  ///
  /// In en, this message translates to:
  /// **'Linear Calibration'**
  String get linearCalibration;

  /// No description provided for @testLoadKg.
  ///
  /// In en, this message translates to:
  /// **'Test Load {num} (kg)'**
  String testLoadKg(int num);

  /// No description provided for @testWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Test Weight (kg)'**
  String get testWeightKg;

  /// No description provided for @validationPassed.
  ///
  /// In en, this message translates to:
  /// **'Configuration validation passed'**
  String get validationPassed;

  /// No description provided for @validationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed: '**
  String get validationFailed;

  /// No description provided for @saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Save successful'**
  String get saveSuccess;

  /// No description provided for @saveFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailedMsg;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteDOMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this Digital Output mapping?'**
  String get confirmDeleteDOMsg;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editMapping.
  ///
  /// In en, this message translates to:
  /// **'Edit Mapping'**
  String get editMapping;

  /// No description provided for @enterValidInteger.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid integer'**
  String get enterValidInteger;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @validate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get validate;

  /// No description provided for @noMappingsMsg.
  ///
  /// In en, this message translates to:
  /// **'No mappings available. Click \"Add\" in the top right corner to add.'**
  String get noMappingsMsg;

  /// No description provided for @veryLight.
  ///
  /// In en, this message translates to:
  /// **'Very Light'**
  String get veryLight;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @heavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get heavy;

  /// No description provided for @frequencyHz.
  ///
  /// In en, this message translates to:
  /// **'Frequency (Hz)'**
  String get frequencyHz;

  /// No description provided for @rangeD.
  ///
  /// In en, this message translates to:
  /// **'Range (d)'**
  String get rangeD;

  /// No description provided for @divisionCount.
  ///
  /// In en, this message translates to:
  /// **'Division count: {count}'**
  String divisionCount(int count);

  /// No description provided for @autoZeroTrackingD.
  ///
  /// In en, this message translates to:
  /// **'Auto Zero Tracking (d)'**
  String get autoZeroTrackingD;

  /// No description provided for @underloadD.
  ///
  /// In en, this message translates to:
  /// **'Underload (d)'**
  String get underloadD;

  /// No description provided for @powerUpZero.
  ///
  /// In en, this message translates to:
  /// **'Power-up Zero'**
  String get powerUpZero;

  /// No description provided for @pushbuttonZero.
  ///
  /// In en, this message translates to:
  /// **'Pushbutton Zero'**
  String get pushbuttonZero;

  /// No description provided for @pushbuttonTare.
  ///
  /// In en, this message translates to:
  /// **'Pushbutton Tare'**
  String get pushbuttonTare;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @grossText.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get grossText;

  /// No description provided for @grossNet.
  ///
  /// In en, this message translates to:
  /// **'Gross + Net'**
  String get grossNet;

  /// No description provided for @lastVal.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get lastVal;

  /// No description provided for @calibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated'**
  String get calibrated;

  /// No description provided for @newVal.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newVal;

  /// No description provided for @fillProgress.
  ///
  /// In en, this message translates to:
  /// **'Fill Progress'**
  String get fillProgress;

  /// No description provided for @fastFeedPhase.
  ///
  /// In en, this message translates to:
  /// **'Fast Feed'**
  String get fastFeedPhase;

  /// No description provided for @fineFeedPhase.
  ///
  /// In en, this message translates to:
  /// **'Fine Feed'**
  String get fineFeedPhase;

  /// No description provided for @emptyingPhase.
  ///
  /// In en, this message translates to:
  /// **'Emptying Container'**
  String get emptyingPhase;

  /// No description provided for @processDetails.
  ///
  /// In en, this message translates to:
  /// **'Process Details'**
  String get processDetails;

  /// No description provided for @refillingPhase.
  ///
  /// In en, this message translates to:
  /// **'Refilling'**
  String get refillingPhase;

  /// No description provided for @feedingPhase.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get feedingPhase;

  /// No description provided for @emptyingFlowPhase.
  ///
  /// In en, this message translates to:
  /// **'Emptying Flow'**
  String get emptyingFlowPhase;

  /// No description provided for @stableIndicator.
  ///
  /// In en, this message translates to:
  /// **'◉ STABLE'**
  String get stableIndicator;

  /// No description provided for @motionIndicator.
  ///
  /// In en, this message translates to:
  /// **'◎ MOTION'**
  String get motionIndicator;

  /// No description provided for @netIndicator.
  ///
  /// In en, this message translates to:
  /// **'NET'**
  String get netIndicator;

  /// No description provided for @signalAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Signal Analyzer'**
  String get signalAnalyzer;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportCsv;

  /// No description provided for @startAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startAnalysis;

  /// No description provided for @stopAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopAnalysis;

  /// No description provided for @showFlow.
  ///
  /// In en, this message translates to:
  /// **'Flow Rate'**
  String get showFlow;

  /// No description provided for @showTargetFlow.
  ///
  /// In en, this message translates to:
  /// **'Target Flow'**
  String get showTargetFlow;

  /// No description provided for @showControlRate.
  ///
  /// In en, this message translates to:
  /// **'Control Rate'**
  String get showControlRate;

  /// No description provided for @showRefill.
  ///
  /// In en, this message translates to:
  /// **'Refill Signal'**
  String get showRefill;

  /// No description provided for @showRunning.
  ///
  /// In en, this message translates to:
  /// **'Run Signal'**
  String get showRunning;

  /// No description provided for @showFillingLevel.
  ///
  /// In en, this message translates to:
  /// **'Filling Level'**
  String get showFillingLevel;

  /// No description provided for @runtimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Runtime Information'**
  String get runtimeInfo;

  /// No description provided for @xAxisViewLength.
  ///
  /// In en, this message translates to:
  /// **'X-Axis View Length (s)'**
  String get xAxisViewLength;

  /// No description provided for @autoStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Auto Stop Recording (s)'**
  String get autoStopRecording;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported to: '**
  String get exportSuccess;

  /// No description provided for @batchTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Batch Target Weight (kg)'**
  String get batchTargetWeight;

  /// No description provided for @currentBatchWeight.
  ///
  /// In en, this message translates to:
  /// **'Current Batch Weight (kg)'**
  String get currentBatchWeight;

  /// No description provided for @eta.
  ///
  /// In en, this message translates to:
  /// **'ETA (hh:mm:ss)'**
  String get eta;

  /// No description provided for @subsystemId.
  ///
  /// In en, this message translates to:
  /// **'Subsystem ID'**
  String get subsystemId;

  /// No description provided for @ioPosition.
  ///
  /// In en, this message translates to:
  /// **'I/O Position'**
  String get ioPosition;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @bitIndex.
  ///
  /// In en, this message translates to:
  /// **'Bit Index'**
  String get bitIndex;

  /// No description provided for @appScope.
  ///
  /// In en, this message translates to:
  /// **'Application Scope'**
  String get appScope;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'Signal Type'**
  String get signal;

  /// No description provided for @activeHigh.
  ///
  /// In en, this message translates to:
  /// **'Active High'**
  String get activeHigh;

  /// No description provided for @hardwareConfig.
  ///
  /// In en, this message translates to:
  /// **'Hardware Configuration'**
  String get hardwareConfig;

  /// No description provided for @signalConfig.
  ///
  /// In en, this message translates to:
  /// **'Signal Configuration'**
  String get signalConfig;

  /// No description provided for @scopeConfig.
  ///
  /// In en, this message translates to:
  /// **'Scope Configuration'**
  String get scopeConfig;

  /// No description provided for @subsystemIdHint.
  ///
  /// In en, this message translates to:
  /// **'The subsystem identifier this output belongs to'**
  String get subsystemIdHint;

  /// No description provided for @ioPosHint.
  ///
  /// In en, this message translates to:
  /// **'Physical I/O module position in the EtherCAT network'**
  String get ioPosHint;

  /// No description provided for @channelHint.
  ///
  /// In en, this message translates to:
  /// **'Weighing channel (0 or 1)'**
  String get channelHint;

  /// No description provided for @bitIndexHint.
  ///
  /// In en, this message translates to:
  /// **'Digital output bit number (0-15)'**
  String get bitIndexHint;

  /// No description provided for @appScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Application scope filter (0 = all)'**
  String get appScopeHint;

  /// No description provided for @signalTypeHint.
  ///
  /// In en, this message translates to:
  /// **'The control signal this output represents'**
  String get signalTypeHint;

  /// No description provided for @activeHighHint.
  ///
  /// In en, this message translates to:
  /// **'Output is active when signal is HIGH'**
  String get activeHighHint;

  /// No description provided for @enabledStatus.
  ///
  /// In en, this message translates to:
  /// **'Enabled Status'**
  String get enabledStatus;

  /// No description provided for @mappingDetails.
  ///
  /// In en, this message translates to:
  /// **'Mapping Details'**
  String get mappingDetails;

  /// No description provided for @outputConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Digital Output Configuration'**
  String get outputConfiguration;

  /// No description provided for @noMappingsHint.
  ///
  /// In en, this message translates to:
  /// **'No digital output mappings configured yet. Tap the \'+\' button to create your first mapping.'**
  String get noMappingsHint;

  /// No description provided for @feedFast.
  ///
  /// In en, this message translates to:
  /// **'Fast Feed'**
  String get feedFast;

  /// No description provided for @feedSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow Feed / Fine Feed'**
  String get feedSlow;

  /// No description provided for @refillValve.
  ///
  /// In en, this message translates to:
  /// **'Refill Valve'**
  String get refillValve;

  /// No description provided for @emptyingValve.
  ///
  /// In en, this message translates to:
  /// **'Emptying Valve'**
  String get emptyingValve;

  /// No description provided for @alarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm Signal'**
  String get alarm;

  /// No description provided for @runningSignal.
  ///
  /// In en, this message translates to:
  /// **'Running Indicator'**
  String get runningSignal;

  /// No description provided for @warningSignal.
  ///
  /// In en, this message translates to:
  /// **'Warning Indicator'**
  String get warningSignal;

  /// No description provided for @confirmDeleteServoMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this Servo Motor mapping?'**
  String get confirmDeleteServoMsg;

  /// No description provided for @bagClamp.
  ///
  /// In en, this message translates to:
  /// **'Bag Clamp / Release'**
  String get bagClamp;

  /// No description provided for @editServoMapping.
  ///
  /// In en, this message translates to:
  /// **'Edit Servo Mapping'**
  String get editServoMapping;

  /// No description provided for @servoPosition.
  ///
  /// In en, this message translates to:
  /// **'Servo Physical Position'**
  String get servoPosition;

  /// No description provided for @servoPositionHint.
  ///
  /// In en, this message translates to:
  /// **'Position index of the servo drive in the EtherCAT network'**
  String get servoPositionHint;

  /// No description provided for @channelServoHint.
  ///
  /// In en, this message translates to:
  /// **'Used to distinguish multiple servo motors with the same function'**
  String get channelServoHint;

  /// No description provided for @addDigitalIo.
  ///
  /// In en, this message translates to:
  /// **'Add Digital I/O'**
  String get addDigitalIo;

  /// No description provided for @addServoMotor.
  ///
  /// In en, this message translates to:
  /// **'Add Servo Motor'**
  String get addServoMotor;

  /// No description provided for @digitalIoMappingSection.
  ///
  /// In en, this message translates to:
  /// **'Digital IO Mapping'**
  String get digitalIoMappingSection;

  /// No description provided for @noDigitalIoConfig.
  ///
  /// In en, this message translates to:
  /// **'No digital IO configuration'**
  String get noDigitalIoConfig;

  /// No description provided for @servoRoutingSection.
  ///
  /// In en, this message translates to:
  /// **'Servo Motor Routing'**
  String get servoRoutingSection;

  /// No description provided for @noServoConfig.
  ///
  /// In en, this message translates to:
  /// **'No servo motor configuration'**
  String get noServoConfig;

  /// No description provided for @scopeBoth.
  ///
  /// In en, this message translates to:
  /// **'Both (General)'**
  String get scopeBoth;

  /// No description provided for @scopeLiwOnly.
  ///
  /// In en, this message translates to:
  /// **'LIW Only'**
  String get scopeLiwOnly;

  /// No description provided for @scopeFillingOnly.
  ///
  /// In en, this message translates to:
  /// **'Filling Only'**
  String get scopeFillingOnly;

  /// No description provided for @slavePositionPrefix.
  ///
  /// In en, this message translates to:
  /// **'Slave Pos'**
  String get slavePositionPrefix;

  /// No description provided for @hmiConfig.
  String get hmiConfig;

  /// No description provided for @hmiConfigSubtitle.
  String get hmiConfigSubtitle;

  /// No description provided for @ethercatDevices.
  String get ethercatDevices;

  /// No description provided for @scanDevices.
  String get scanDevices;

  /// No description provided for @scanning.
  String get scanning;

  /// No description provided for @noDevicesFound.
  String get noDevicesFound;

  /// No description provided for @deviceAlias.
  String get deviceAlias;

  /// No description provided for @deviceAliasHint.
  String get deviceAliasHint;

  /// No description provided for @assignToSubsystem.
  String get assignToSubsystem;

  /// No description provided for @shmemMode.
  String get shmemMode;

  /// No description provided for @ethercatMode.
  String get ethercatMode;

  /// No description provided for @inputModeLabel.
  String get inputModeLabel;

  /// No description provided for @channelSelect.
  String get channelSelect;

  /// No description provided for @noDeviceAssigned.
  String get noDeviceAssigned;

  /// {count} device(s) discovered
  String deviceDiscovered(int count);

  /// No description provided for @subsystemScaleBinding.
  String get subsystemScaleBinding;

  /// No description provided for @selectWeighingDevice.
  String get selectWeighingDevice;

  /// No description provided for @vendorId.
  String get vendorId;

  /// No description provided for @productCode.
  String get productCode;

  /// No description provided for @position.
  String get position;

  /// No description provided for @slaveRoleWeighing.
  String get slaveRoleWeighing;

  /// No description provided for @slaveRoleDigitalIO.
  String get slaveRoleDigitalIO;

  /// No description provided for @slaveRoleServo.
  String get slaveRoleServo;

  /// No description provided for @slaveRoleUnknown.
  String get slaveRoleUnknown;

  /// No description provided for @saveAlias.
  String get saveAlias;

  /// No description provided for @aliasUpdated.
  String get aliasUpdated;

  /// No description provided for @aliasFailed.
  String get aliasFailed;

  /// No description provided for @mappingUpdated.
  String get mappingUpdated;

  /// No description provided for @mappingFailed.
  String get mappingFailed;

  /// No description provided for @channel0.
  String get channel0;

  /// No description provided for @channel1.
  String get channel1;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
