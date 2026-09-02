import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/clevertap.dart';
import '../services/pip_service.dart';
import '../utils/tracking_events.dart';

class PipProvider extends ChangeNotifier {
  static final Logger _logger = Logger();

  bool _isInPipMode = false;
  bool _isPipSupported = false;
  bool _isInitialized = false;

  bool get isInPipMode => _isInPipMode;
  bool get isPipSupported => _isPipSupported;
  bool get isInitialized => _isInitialized;

  PipProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize the PiP service
      PipService.initialize();

      // Check if PiP is supported
      _isPipSupported = await PipService.isPipSupported();

      // Check current PiP mode
      _isInPipMode = await PipService.isPipMode();

      // Set up callback for PiP mode changes
      PipService.setOnPipModeChanged(_onPipModeChanged);

      _isInitialized = true;
      notifyListeners();

      _logger.i(
          'PipProvider initialized - Supported: $_isPipSupported, InPiP: $_isInPipMode');
    } catch (e) {
      _logger.e('Error initializing PipProvider: $e');
    }
  }

  void _onPipModeChanged(bool isInPiPMode) {
    if (_isInPipMode != isInPiPMode) {
      _isInPipMode = isInPiPMode;
      notifyListeners();

      // Call server API when PiP mode changes
      _notifyServerPipModeChange(isInPiPMode);

      _logger.i('PiP mode changed to: $isInPiPMode');
    }
  }

  Future<bool> enterPipMode() async {
    if (!_isPipSupported) {
      _logger.w('Cannot enter PiP - not supported');
      return false;
    }

    if (_isInPipMode) {
      return false;
    }

    final bool success = await PipService.enterPip();

    if (success) {
      // The mode change will be handled by the callback
      _logger.i('Entered PiP mode successfully');
    } else {
      _logger.w('Failed to enter PiP mode');
    }

    return success;
  }

  Future<void> _notifyServerPipModeChange(bool isInPiPMode) async {
    try {
      // Use your existing RunnerHttp service to notify server
      // You can add a new method to RunnerHttp for PiP mode changes
      // For now, just log the change
      _logger.i('PiP mode change notification: $isInPiPMode');
      // print("${GlobalState().navigatorKey.currentContext}");
      if (!isInPiPMode) {
        ClevertapSetup.logEvent(
          TrackingEvents.exitPip,
          {},
        );
      }

      // : Add actual API call using your RunnerHttp service
      // Example:
      // await RunnerHttp.notifyPipModeChange(isInPiPMode);

      // Or create a custom API call:
      /*
      await RunnerHttp.dio.post(
        '/api/runner/pip-status',
        data: {
          'isInPipMode': isInPiPMode,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      */
    } catch (e) {
      _logger.e('Error notifying server about PiP mode change: $e');
    }
  }

  @override
  void dispose() {
    PipService.removeOnPipModeChanged();
    super.dispose();
  }
}
