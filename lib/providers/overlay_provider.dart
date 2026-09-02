import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import '../models/awol/awol_models.dart';
import '../models/overlay/overlay_config.dart';
import '../models/overlay/overlay_events.dart';
import '../services/alarm_silencer.dart';
import '../services/overlay_service.dart';
import '../services/remote_config/remote_config_keys.dart';
import '../services/remote_config/remote_config_service.dart';

/// Flutter-side state manager for the native AWOL overlay system.
///
/// Tracks overlay lifecycle (active/idle), permission state, and foreground
/// dialog state (shown/dismissed/acknowledged). Acts as the single source of
/// truth on the Flutter side — the native [OverlayService] is authoritative
/// for whether an overlay is actually visible on screen.
///
/// Key state flags:
///  - [hasPermission]    — SYSTEM_ALERT_WINDOW granted (checked on resume).
///  - [isOverlayActive]  — a native overlay is currently showing.
///  - [hasAcknowledged]  — user tapped "I understood" on the breach dialog;
///                          subsequent background entries show the mini overlay.
///  - [awolDialogShown]  — the foreground dialog was presented this session.
///  - [awolDialogDismissed] — the foreground dialog was dismissed; used by
///                             partner_home to show the home-card widget.
class OverlayProvider extends ChangeNotifier {
  static final Logger _logger = Logger();
  static const _foregroundChannel =
      MethodChannel('com.snabbit.runner/foreground');

  bool _hasPermission = false;
  bool _isOverlayActive = false;
  bool _isInitialized = false;
  bool _hasAcknowledged = false;
  OverlayConfig? _lastConfig;
  bool _awolDialogShown = false;
  bool _awolDialogDismissed = false;
  bool _isStartingOverlay = false;
  AwolState? _lastAwolState;
  StreamSubscription? _lifecycleSubscription;

  bool get hasPermission => _hasPermission;
  bool get isOverlayActive => _isOverlayActive;
  bool get isInitialized => _isInitialized;
  bool get hasAcknowledged => _hasAcknowledged;
  OverlayConfig? get lastConfig => _lastConfig;
  bool get awolDialogShown => _awolDialogShown;
  bool get awolDialogDismissed => _awolDialogDismissed;
  AwolState? get lastAwolState => _lastAwolState;

  bool get isAwolOverlayEnabled => RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolOverlay,
        defaultValue: false,
      );

  bool get isAwolV2Enabled => RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolV2,
        defaultValue: false,
      );

  /// Kill-switch for the AWOL v2 (KMP) over-other-apps alert. When ON, the
  /// native launcher owns every background/lock-screen/killed-state AWOL
  /// surface, so the legacy background overlay path stands down — flipping
  /// both flags on must never fire two overlay systems for one breach.
  bool get isAwolV2OverlayEnabled => RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolV2Overlay,
        defaultValue: false,
      );

  /// Kill-switch for the AWOL v2 (KMP) home card embedded in partner_home.
  /// When ON, the native card owns the in-app surface: the legacy breach
  /// home card AND the legacy breach/re-entered dialogs are suppressed.
  bool get isAwolV2HomeCardEnabled => RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolV2HomeCard,
        defaultValue: false,
      );

  void Function(double lat, double lng, String? name)? onShowDirections;
  void Function(String actionId)? onCtaTracking;
  void Function(AwolState fromState, AwolState toState)?
      onAwolStateTransitionTracking;

  OverlayProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _hasPermission = await OverlayService.checkPermission();
      _isOverlayActive = await OverlayService.isOverlayVisible();

      // Listen for native overlay callbacks
      OverlayService.methodChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onCTAClicked':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final event = CTAEvent.fromMap(args);
            _handleCTAClicked(event);
            break;
          case 'onOverlayDismissed':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final event = DismissEvent.fromMap(args);
            _handleDismissed(event);
            break;
          case 'onOverlayError':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final error = OverlayError.fromMap(args);
            _logger.e('Overlay error: ${error.code} - ${error.message}');
            break;
        }
      });

      // Listen for lifecycle events
      _lifecycleSubscription =
          OverlayService.lifecycleEvents.listen((event) {});

      _isInitialized = true;
      notifyListeners();
      _logger.i(
          'OverlayProvider initialized - Permission: $_hasPermission, Active: $_isOverlayActive');
    } catch (e) {
      _logger.e('Error initializing OverlayProvider: $e');
    }
  }

  void _handleCTAClicked(CTAEvent event) {
    _logger.i('Overlay CTA clicked: ${event.actionId}');
    debugPrint('>>> _handleCTAClicked: ${event.actionId}, '
        'isActive=$_isOverlayActive, acknowledged=$_hasAcknowledged');
    onCtaTracking?.call(event.actionId);
    switch (event.actionId) {
      case 'understood':
        // The runner acknowledged the breach — stop the alarm on the tap
        // instead of letting it run out its repeat count. Fire-and-forget:
        // silencing must not delay the acknowledged-state notify below.
        unawaited(AlarmSilencer.silence());
        // Mini overlay is now active on native side — keep _isOverlayActive true.
        // Track acknowledged state so re-minimize shows mini instead of dialog.
        _hasAcknowledged = true;
        debugPrint('>>> _hasAcknowledged set to true');
        notifyListeners();
        break;
      case 'show_directions':
        _isOverlayActive = false;
        _hasAcknowledged = false;
        _lastConfig = null;
        notifyListeners();
        final lat = anyValueToDouble(event.data['lat']);
        final lng = anyValueToDouble(event.data['lng']);
        final name = event.data['name']?.toString();
        if (lat != null && lng != null) {
          onShowDirections?.call(lat, lng, name);
        }
        break;
      case 'timeout':
        _logger.i('AWOL breach timer expired');
        break;
    }
  }

  void _handleDismissed(DismissEvent event) {
    _isOverlayActive = false;
    _hasAcknowledged = false;
    _lastConfig = null;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    try {
      await OverlayService.requestPermission();
      _hasPermission = await OverlayService.checkPermission();
      notifyListeners();
    } catch (e) {
      _logger.e('Error requesting overlay permission: $e');
    }
  }

  Future<void> refreshPermission() async {
    try {
      _hasPermission = await OverlayService.checkPermission();
      notifyListeners();
    } catch (e) {
      _logger.e('Error refreshing overlay permission: $e');
    }
  }

  /// Show an overlay. When [replace] is true, sends a new SHOW command even if
  /// an overlay is already active — the native ViewModel handles dismissing the
  /// old view and showing the new one in-place (no service restart needed).
  Future<void> startOverlay({
    required String type,
    required OverlayConfig config,
    bool replace = false,
  }) async {
    // Prevent concurrent overlay creations — duplicate API responses can
    // trigger _onAwolDataChanged multiple times in the same frame.
    if (_isStartingOverlay) return;
    _isStartingOverlay = true;
    try {
      _hasPermission = await OverlayService.checkPermission();
      _logger.i('startOverlay called - type: $type, replace: $replace, '
          'permission: $_hasPermission, active: $_isOverlayActive');
      if (!_hasPermission) {
        _logger.w('Cannot start overlay - permission not granted');
        return;
      }
      if (_isOverlayActive && !replace) {
        _logger.i('Overlay already active, skipping');
        return;
      }
      _lastConfig = config;
      if (type == 'banner') {
        await OverlayService.showBanner(
          message: config.message,
          config: config,
        );
      } else if (type == 'mini') {
        await OverlayService.showMiniOverlay(config);
      } else {
        // Only reset acknowledged state for fresh sessions, not replacements.
        // When replace is true, the native callback that sets _hasAcknowledged
        // may still be in-flight — resetting here would lose it.
        if (!replace) _hasAcknowledged = false;
        await OverlayService.showOverlay(config);
      }
      _isOverlayActive = true;
      notifyListeners();
      _logger.i('Overlay started successfully (type: $type)');
    } catch (e) {
      _logger.e('Error starting overlay: $e');
    } finally {
      _isStartingOverlay = false;
    }
  }

  /// Called by the resume handler when native overlay is confirmed gone.
  /// Syncs Flutter-side flag without sending a dismiss command to native.
  void onNativeOverlayGone() {
    if (_isOverlayActive) {
      _isOverlayActive = false;
      notifyListeners();
    }
  }

  Future<void> stopOverlay() async {
    if (!_isOverlayActive) return;
    await OverlayService.dismissOverlay();
    _isOverlayActive = false;
    _hasAcknowledged = false;
    _lastConfig = null;
    notifyListeners();
    _logger.i('Overlay stopped');
  }

  void markAwolDialogShown() {
    _awolDialogShown = true;
    notifyListeners();
  }

  void markAwolDialogDismissed() {
    _awolDialogDismissed = true;
    notifyListeners();
  }

  void resetAwolForegroundState() {
    _awolDialogShown = false;
    _awolDialogDismissed = false;
    _lastAwolState = null;
    notifyListeners();
  }

  void onAwolStateChanged(AwolState newState) {
    if (_lastAwolState != null && _lastAwolState != newState) {
      onAwolStateTransitionTracking?.call(_lastAwolState!, newState);
      _awolDialogShown = false;
      _awolDialogDismissed = false;
      _hasAcknowledged = false;
      notifyListeners();
    }
    _lastAwolState = newState;
  }

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    super.dispose();
  }
}
