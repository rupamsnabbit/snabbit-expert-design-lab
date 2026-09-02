import 'dart:async';

import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Dart wrapper over the native `com.snabbit.runner/awol_overlay` MethodChannel.
/// Mirrors `lib/services/job_overlay_channel.dart` /
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/OverlayLauncherPlugin.kt`.
///
/// The AWOL v2 launcher decides natively (off the KMP `RunnerStateStore`)
/// whether to present the AWOL alert over other apps when the app isn't
/// foreground. The only things that cross from Dart are the Remote Config
/// values — Firebase Remote Config isn't on the native compile classpath, so
/// Dart reads them and pushes here: the overlay kill-switch
/// ([RemoteConfigKeys.enableAwolV2Overlay]), the in-app home-card kill-switch
/// ([RemoteConfigKeys.enableAwolV2HomeCard] — gates the native Compose-home
/// AWOL card), plus the fallback map-image URLs
/// ([RemoteConfigAssets.awolEnterHotspot] / [RemoteConfigAssets.awolBackInHotspot],
/// the same assets the legacy `awol_overlay_converter` resolves). Until
/// pushed, the native side keeps the overlay OFF (ships dark) and the image
/// slot on its placeholder. There is deliberately no `showOverlay` method:
/// presentation is store-driven and dismissal is feed-driven natively.
///
/// [sync] is called at provider init; [listenForUpdates] re-pushes when the
/// key flips mid-session (the legacy `partner_home.dart` re-initialise-on-RC-
/// update behaviour, via [RemoteConfigService.onKeyUpdated]). Best-effort —
/// every path is swallowed + logged so it can never disturb Dart-side startup.
class AwolOverlayChannel {
  AwolOverlayChannel._();

  static const MethodChannel _channel = MethodChannel(
    'com.snabbit.runner/awol_overlay',
  );

  static final List<StreamSubscription<bool>> _updateSubscriptions =
      <StreamSubscription<bool>>[];

  /// Pushes the AWOL overlay + home-card kill-switches and fallback image URLs
  /// to the native side. Never throws.
  static Future<void> setEnabled(
    bool enabled, {
    bool homeCardEnabled = false,
    String? breachImageUrl,
    String? reEnteredImageUrl,
  }) {
    return _channel.invokeMethod<void>('setOverlayEnabled', <String, Object?>{
      'enabled': enabled,
      'homeCardEnabled': homeCardEnabled,
      'breachImageUrl': breachImageUrl,
      'reEnteredImageUrl': reEnteredImageUrl,
    }).catchError((e) => _logFailure('setOverlayEnabled', e));
  }

  /// Reads the RC values (safe defaults: overlay off, bundled CDN asset
  /// paths) and pushes them natively.
  static Future<void> sync() {
    var enabled = false;
    var homeCardEnabled = false;
    try {
      enabled = RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolV2Overlay,
      );
      homeCardEnabled = RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableAwolV2HomeCard,
      );
    } catch (e) {
      _logFailure('readRemoteConfig', e);
    }
    String? breachImageUrl;
    String? reEnteredImageUrl;
    try {
      // Getters never throw for a missing key (they fall back to the bundled
      // CDN paths); this guards service-not-initialised during startup.
      breachImageUrl = RemoteConfigAssets.awolEnterHotspot;
      reEnteredImageUrl = RemoteConfigAssets.awolBackInHotspot;
    } catch (e) {
      _logFailure('readImageAssets', e);
    }
    return setEnabled(
      enabled,
      homeCardEnabled: homeCardEnabled,
      breachImageUrl: breachImageUrl,
      reEnteredImageUrl: reEnteredImageUrl,
    );
  }

  /// Re-pushes the values whenever Remote Config live-updates the
  /// kill-switch or the assets map. Idempotent — only the first call
  /// subscribes.
  static void listenForUpdates() {
    if (_updateSubscriptions.isNotEmpty) return;
    try {
      _updateSubscriptions.add(
        RemoteConfigService.instance
            .onKeyUpdated(RemoteConfigKeys.enableAwolV2Overlay)
            .listen((_) => sync()),
      );
      _updateSubscriptions.add(
        RemoteConfigService.instance
            .onKeyUpdated(RemoteConfigKeys.enableAwolV2HomeCard)
            .listen((_) => sync()),
      );
      _updateSubscriptions.add(
        RemoteConfigService.instance
            .onKeyUpdated(RemoteConfigAssetKeys.assetsRoot)
            .listen((_) => sync()),
      );
    } catch (e) {
      _logFailure('listenForUpdates', e);
    }
  }

  /// Cancels the Remote Config live-update subscriptions and clears the guard
  /// so [listenForUpdates] can re-subscribe. In production these are
  /// app-lifetime (the owning [RunnerRtDataProvider] is a root singleton), so
  /// this exists chiefly for deterministic test isolation.
  static Future<void> reset() async {
    for (final sub in _updateSubscriptions) {
      await sub.cancel();
    }
    _updateSubscriptions.clear();
  }

  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('awol_overlay_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
