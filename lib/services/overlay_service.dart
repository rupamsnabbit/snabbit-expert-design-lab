import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../models/overlay/overlay_config.dart';
import '../models/overlay/overlay_events.dart';

/// Thin static wrapper around the MethodChannel/EventChannel that communicates
/// with the native [OverlayChannelManager] on Android.
///
/// All methods are fire-and-forget with error logging. The actual overlay
/// lifecycle is managed by the native [OverlayService] foreground service —
/// this class simply sends commands to it.
///
/// Used exclusively by [OverlayProvider]; other code should go through the
/// provider instead of calling these methods directly.
class OverlayService {
  static final Logger _logger = Logger();
  static const _methodChannel =
      MethodChannel('com.snabbit.runner/compose_overlay/methods');
  static const _eventChannel =
      EventChannel('com.snabbit.runner/compose_overlay/events');

  static Stream<LifecycleEvent>? _lifecycleStream;

  static Future<bool> checkPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (e) {
      _logger.e('Error checking overlay permission: $e');
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      _logger.e('Error requesting overlay permission: $e');
    }
  }

  static Future<void> showOverlay(OverlayConfig config) async {
    try {
      final args = config.toMap();
      args['type'] = 'dialog';
      await _methodChannel.invokeMethod('showOverlay', args);
      _logger.i('Overlay shown: dialog');
    } catch (e) {
      _logger.e('Error showing overlay: $e');
      rethrow;
    }
  }

  static Future<void> showBanner({
    String? message,
    String type = 'info',
    OverlayConfig? config,
  }) async {
    try {
      if (config != null) {
        final args = config.toMap();
        args['type'] = 'banner';
        await _methodChannel.invokeMethod('showOverlay', args);
      } else {
        await _methodChannel.invokeMethod('showBanner', {
          'message': message,
          'type': type,
        });
      }
      _logger.i('Banner shown');
    } catch (e) {
      _logger.e('Error showing banner: $e');
      rethrow;
    }
  }

  static Future<void> updateBanner({
    required String message,
    String type = 'info',
  }) async {
    try {
      await _methodChannel.invokeMethod('updateBanner', {
        'message': message,
        'type': type,
      });
    } catch (e) {
      _logger.e('Error updating banner: $e');
    }
  }

  static Future<void> showMiniOverlay(OverlayConfig config) async {
    try {
      final args = config.toMap();
      args['type'] = 'mini';
      await _methodChannel.invokeMethod('showOverlay', args);
      _logger.i('Mini overlay shown');
    } catch (e) {
      _logger.e('Error showing mini overlay: $e');
      rethrow;
    }
  }

  static Future<void> dismissOverlay() async {
    try {
      await _methodChannel.invokeMethod('dismissOverlay');
      _logger.i('Overlay dismissed');
    } catch (e) {
      _logger.e('Error dismissing overlay: $e');
    }
  }

  static Future<bool> isOverlayVisible() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isOverlayVisible');
      return result ?? false;
    } catch (e) {
      _logger.e('Error checking overlay visibility: $e');
      return false;
    }
  }

  static MethodChannel get methodChannel => _methodChannel;

  static Stream<LifecycleEvent> get lifecycleEvents {
    _lifecycleStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => LifecycleEvent.fromMap(event as Map<dynamic, dynamic>));
    return _lifecycleStream!;
  }
}
