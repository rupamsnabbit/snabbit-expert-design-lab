import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_service.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/native_capabilities.dart';
import 'package:snabbit_runner/services/webview/webview_channel.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

class WebViewEventHandler {
  WebViewEventHandler._();

  /// Builds the init-data payload for web: auth token, device info,
  /// runner profile, and optional caller-supplied extras (e.g. location).
  ///
  /// Returns a [BifrostResult] — `data` on success, or `error` with
  /// `TOKEN_UNAVAILABLE` when the access token can't be read. Pure
  /// function w.r.t. the channel: the router (for RPC) or a caller
  /// (for legacy push) is responsible for delivering it to web.
  static Future<BifrostResult> buildInitData({
    Map<String, dynamic>? additionalData,
    BuildContext? context,
    Iterable<String>? requestedCapabilities,
  }) async {
    // context is read synchronously here, before the first await below.
    final runnerInfo = _getRunnerInfo(context);

    final token = await SecureStorageUtils.getAccessToken('APP_WEB_VIEW');
    if (token == null) {
      MonitoringServiceHelper.logError('webview_init_data_token_null', {});
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.tokenUnavailable,
          message: 'Access token is not available in secure storage.',
        ),
      );
    }
    final data = <String, dynamic>{
      'token': token,
      ...?await _getDeviceInfo(),
      ...?runnerInfo,
      'capabilities': NativeCapabilities.intersect(requestedCapabilities),
      'remoteConfig': _getRemoteConfigForWeb(),
    };
    if (additionalData != null) {
      data.addAll(additionalData);
    }
    return BifrostResult(data: data);
  }

  /// Legacy push-based delivery (called on `onPageCommitVisible`).
  /// Delete in slice 1b once all web clients use `requestInitData()` RPC.
  ///
  /// The push has no requested list to intersect against — it fires before the
  /// web asks anything — so it reports everything this build supports rather
  /// than nothing. Passing null here made the push carry `capabilities: []`,
  /// and a web client that let the push win the race against its own RPC then
  /// saw every capability-gated feature as unsupported for the whole session.
  static Future<void> sendInitData(
    WebViewChannel channel, {
    Map<String, dynamic>? additionalData,
    BuildContext? context,
  }) async {
    final result = await buildInitData(
      additionalData: additionalData,
      context: context,
      requestedCapabilities: NativeCapabilities.supported,
    );
    if (result.error != null) {
      // Legacy wire-format: lowercase reason, not the new SCREAMING_SNAKE
      // error code. Old web listeners match on this exact string.
      await channel.pushEvent(WebViewConstants.eventInitError, const {
        'reason': 'token_unavailable',
      });
      return;
    }
    await channel.pushEvent(WebViewConstants.eventInitData, result.data);
  }

  /// Remote Config flags surfaced to web in the init payload so the web app
  /// can branch on the same values native uses. Add new flags here as the web
  /// needs them — keep keys camelCase to match the rest of the init data.
  static Map<String, dynamic> _getRemoteConfigForWeb() => {
        'isReferralsV2Enabled': RemoteConfigHelperUtils.isReferralsV2Enabled,
      };

  static Future<Map<String, dynamic>?> _getDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfoPlugin = DeviceInfoPlugin();

      // Read the currently RUNNING Shorebird patch number directly from
      // the source of truth (the on-disk patch metadata written at app
      // startup). Bypasses ShorebirdManager's cache so we don't hit
      // the cold-start race where the cache is still null while
      // initialize() is in flight. Returns null when no patch is
      // installed (Play Store install state).
      final shorebirdPatchNumber =
          await ShorebirdService.instance.getCurrentPatchNumber();

      final Map<String, dynamic> info = {
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'shorebirdPatchNumber': shorebirdPatchNumber,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info['osVersion'] = androidInfo.version.release;
        info['deviceManufacturer'] = androidInfo.manufacturer;
        info['deviceModel'] = androidInfo.model;
        info['physicalRamSize'] = androidInfo.physicalRamSize; // MB
        info['availableRamSize'] = androidInfo.availableRamSize; // MB
        info['isLowRamDevice'] = androidInfo.isLowRamDevice;
      } else {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info['osVersion'] = iosInfo.systemVersion;
        info['deviceManufacturer'] = 'Apple';
        info['deviceModel'] = iosInfo.utsname.machine;
      }

      return info;
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'webview_device_info',
        fatal: false,
      );
      return null;
    }
  }

  static Map<String, dynamic>? _getRunnerInfo(
    BuildContext? context,
  ) {
    try {
      if (context != null) {
        final user = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        ).user;
        if (user != null) {
          return {
            'runner': {
              'id': user.id,
              'name': user.name,
              'languagePreference': user.languagePreference,
              'phoneNumber': user.phoneNumber,
              'countryCode': user.countryCode,
              'serviceId': user.serviceId,
              'tier': user.tier?.name,
              'tierEffectiveDate':
                  getStringFromDateTime(user.tierEffectiveDate),
              'clusterId': user.clusterId,
              'regionId': user.regionId,
              'status': user.runnerStatus?.name,
              'onDuty': user.onDuty,
              'isActive': user.isActive,
              'hasSeenTierIntro': user.hasViewedIntro,
            },
          };
        }
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'webview_runner_info',
        fatal: false,
      );
    }
    return null;
  }

  static Future<void> sendBackPressed(WebViewChannel channel) async {
    await channel.pushEvent(WebViewConstants.eventBackPressed, null);
  }
}
