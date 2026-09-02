import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('com.snabbit.runner/pip');
  static final Logger _logger = Logger();

  // Callback for PiP mode changes
  static Function(bool)? _onPipModeChanged;

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPModeChanged':
        final bool isInPiPMode = call.arguments['isInPiPMode'] ?? false;
        _logger.i('PiP mode changed: $isInPiPMode');
        _onPipModeChanged?.call(isInPiPMode);
        break;
      default:
        _logger.w('Unknown method call: ${call.method}');
    }
  }

  /// Check if Picture-in-Picture is supported on this device
  static Future<bool> isPipSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod('isPiPSupported');
      return supported ?? false;
    } catch (e) {
      _logger.e('Error checking PiP support: $e');
      return false;
    }
  }

  /// Check if the app is currently in Picture-in-Picture mode
  static Future<bool> isPipMode() async {
    try {
      final bool? isInPiP = await _channel.invokeMethod('isPiPMode');
      return isInPiP ?? false;
    } catch (e) {
      _logger.e('Error checking PiP mode: $e');
      return false;
    }
  }

  /// Enable or disable native auto-PiP entry (cohort gate — Phase 1).
  ///
  /// The MQTT/KMP cohort pushes `false` so backgrounding a reused Flutter flow
  /// can't fracture the task into a stray PiP window beside the KMP host; the
  /// Flutter cohort pushes `true`. One-way invoke — works even when
  /// [initialize] was never called, since the native handler is registered when
  /// the FlutterEngine is configured.
  static Future<void> setPipEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setPipEnabled', {'enabled': enabled});
    } catch (e) {
      _logger.e('Error setting PiP enabled=$enabled: $e');
    }
  }

  /// Enter Picture-in-Picture mode
  static Future<bool> enterPip() async {
    try {
      // Check if PiP is supported first
      final bool supported = await isPipSupported();
      if (!supported) {
        _logger.w('PiP is not supported on this device');
        return false;
      }

      final bool? success = await _channel.invokeMethod('enterPiP');
      final bool result = success ?? false;

      if (result) {
        _logger.i('Successfully entered PiP mode');
      } else {
        _logger.w('Failed to enter PiP mode');
      }

      return result;
    } catch (e) {
      _logger.e('Error entering PiP mode: $e');
      return false;
    }
  }

  /// Set callback for PiP mode changes
  static void setOnPipModeChanged(Function(bool) callback) {
    _onPipModeChanged = callback;
  }

  /// Remove callback for PiP mode changes
  static void removeOnPipModeChanged() {
    _onPipModeChanged = null;
  }
}
