import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

enum MicPermissionResult { granted, denied, permanentlyDenied }

/// Gates which permissions this dialog is responsible for.
enum ShieldPermissionContext { micAndLocation, micOnly }

class ShieldPermissionHandler {
  static Future<MicPermissionResult> requestMicPermission() async {
    // Re-check current status first so we see grants made in Settings
    // without requiring an app restart (avoids cached permanentlyDenied).
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isGranted) return MicPermissionResult.granted;
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied) {
      MixpanelSetup.logEvent(TrackingEvents.expertShieldError, {
        'error': 'mic_permission_permanently_denied',
      });
      return MicPermissionResult.permanentlyDenied;
    }
    MixpanelSetup.logEvent(TrackingEvents.expertShieldError, {
      'error': 'mic_permission_denied',
    });
    return MicPermissionResult.denied;
  }

  static bool _isDialogShowing = false;

  /// Shows a rationale dialog, then either re-requests or opens Settings.
  /// Returns true only if all required permissions end up granted.
  ///
  /// [hardGate]: no "Not Now" button; dialog stays open on Settings-return
  /// denial until the user grants. Use for mandatory permission blocks.
  static Future<bool> showPermissionDialog(
    BuildContext context, {
    required bool isPermanentlyDenied,
    ShieldPermissionContext permissionContext = ShieldPermissionContext.micOnly,
    bool hardGate = false,
  }) async {
    if (_isDialogShowing) return false;
    _isDialogShowing = true;
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PermissionDialog(
          initialNeedsSettings: isPermanentlyDenied,
          permissionContext: permissionContext,
          hardGate: hardGate,
        ),
      );
      return result ?? false;
    } finally {
      _isDialogShowing = false;
    }
  }
}

class _PermissionDialog extends StatefulWidget {
  final bool initialNeedsSettings;
  final ShieldPermissionContext permissionContext;
  final bool hardGate;

  const _PermissionDialog({
    required this.initialNeedsSettings,
    this.permissionContext = ShieldPermissionContext.micOnly,
    this.hardGate = false,
  });

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  late bool _needsSettings;
  bool _waitingForSettings = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _needsSettings = widget.initialNeedsSettings;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_waitingForSettings || widget.hardGate)) {
      _checkPermissionAfterSettings();
    }
  }

  Future<void> _checkPermissionAfterSettings() async {
    if (_checking) return;
    _checking = true;
    bool popped = false;
    try {
      final granted = await _isPermissionGranted();
      if (!mounted) return;
      if (granted) {
        Navigator.pop(context, true);
        popped = true;
      } else if (!widget.hardGate) {
        // Soft gate: let the caller handle degraded mode.
        MixpanelSetup.logEvent(TrackingEvents.expertShieldError, {
          'error': 'mic_permission_denied_after_settings',
        });
        Navigator.pop(context, false);
        popped = true;
      }
      // Hard gate: dialog stays open — user must grant to proceed.
    } finally {
      _checking = false;
      // Re-enable button if dialog stayed open (hard gate, still denied).
      if (!popped && mounted) {
        setState(() {
          _waitingForSettings = false;
        });
      }
    }
  }

  Future<bool> _isPermissionGranted() async {
    if (widget.permissionContext == ShieldPermissionContext.micAndLocation) {
      final mic = await Permission.microphone.status;
      final locAlways = await Permission.locationAlways.status;
      return mic.isGranted && locAlways.isGranted;
    }
    final mic = await Permission.microphone.status;
    return mic.isGranted;
  }

  Future<void> _onAllowTapped() async {
    if (widget.permissionContext == ShieldPermissionContext.micAndLocation) {
      await _requestMicAndLocation();
      return;
    }
    // mic-only path
    final result = await ShieldPermissionHandler.requestMicPermission();
    if (result == MicPermissionResult.granted) {
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (mounted) setState(() { _needsSettings = true; });
  }

  /// Requests mic → location-while-in-use → location-always in sequence.
  Future<void> _requestMicAndLocation() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) setState(() { _needsSettings = true; });
      return;
    }
    final locStatus = await Permission.location.request();
    if (!locStatus.isGranted) {
      if (mounted) setState(() { _needsSettings = true; });
      return;
    }
    final alwaysStatus = await Permission.locationAlways.request();
    if (mounted) {
      if (alwaysStatus.isGranted) {
        Navigator.pop(context, true);
      } else {
        // Android 11+ silently redirects to Settings during request() and returns denied.
        // Arm the lifecycle observer now so the dialog re-checks and closes when the user returns.
        setState(() {
          _needsSettings = true;
          _waitingForSettings = true;
        });
      }
    }
  }

  Future<void> _onOpenSettingsTapped() async {
    setState(() { _waitingForSettings = true; });
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final isMicAndLoc =
        widget.permissionContext == ShieldPermissionContext.micAndLocation;

    final dialog = AlertDialog(
      title: Text(lang.getMessage(
        isMicAndLoc
            ? 'snabbit_shield_mic_loc_perm_title'
            : 'snabbit_shield_mic_perm_title',
        isMicAndLoc
            ? 'Microphone & Location Required'
            : 'Microphone Permission Required',
      )),
      content: Text(
        _needsSettings
            ? lang.getMessage(
                isMicAndLoc
                    ? 'snabbit_shield_mic_loc_settings_msg'
                    : 'snabbit_shield_mic_perm_denied_msg',
                isMicAndLoc
                    ? 'Microphone and location access are required. Please enable them from App Permissions in Settings.'
                    : 'Microphone permission has been denied. Please enable it from Settings to activate Snabbit Shield security recording.',
              )
            : lang.getMessage(
                isMicAndLoc
                    ? 'snabbit_shield_mic_loc_perm_rationale'
                    : 'snabbit_shield_mic_perm_rationale',
                isMicAndLoc
                    ? 'Snabbit needs microphone and location access to protect you on every job. Please allow both permissions.'
                    : 'Snabbit Shield needs microphone access for security recording during your job. Please grant the permission.',
              ),
      ),
      actions: [
        if (!widget.hardGate)
          TextButton(
            onPressed: _waitingForSettings
                ? null
                : () => Navigator.pop(context, false),
            child: Text(
                lang.getMessage('snabbit_shield_not_now', 'Not Now')),
          ),
        TextButton(
          onPressed: _waitingForSettings
              ? null
              : (_needsSettings ? _onOpenSettingsTapped : _onAllowTapped),
          child: Text(_needsSettings
              ? lang.getMessage(
                  'snabbit_shield_open_settings', 'Open Settings')
              : lang.getMessage('snabbit_shield_allow', 'Allow')),
        ),
      ],
    );

    // Hard gate: back button must not dismiss the dialog.
    return widget.hardGate
        ? PopScope(canPop: false, child: dialog)
        : dialog;
  }
}
