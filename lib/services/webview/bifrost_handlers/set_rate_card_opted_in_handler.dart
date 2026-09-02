import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/kmp_remote_config_mirror.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// SharedPreferences key for "runner has opted into the v2 (Vishwaas)
/// rate card". Set by the webview's
/// `bifrost.send('setRateCardOptedIn', { value: true })` call after a
/// successful upgrade API response. Read by
/// [UserProfileProvider.showVishwaasBanner] to suppress the drawer
/// banner + provisional-rate-card bottom sheet immediately, before the
/// next `runners/me` refresh propagates v2 into the user model.
///
/// Both writer (this handler) and reader (`user_profile.dart`) import
/// this constant so the literal key string lives in one place.
const String kAlreadyDidV2OptInPrefsKey = 'already_did_v2_opt_in';

/// FAF handler: web → native SharedPreferences write.
///
/// Web sends `{ value: bool }` after the upgrade API succeeds. We
/// persist immediately so the next render of the drawer (and the next
/// logout flow's provisional sheet) skips the Vishwaas surfaces.
///
/// Fire-and-forget per the proposal: the webview optimistically advances
/// its own UX before this lands, so blocking on the prefs write would
/// only add latency to the close-webview path. Errors are silent — if
/// the write fails, the surface gates fall through to the existing
/// version-check (which catches up once `runners/me` returns v2).
class SetRateCardOptedInHandler implements BifrostHandler {
  @override
  String get actionName => WebViewConstants.eventSetRateCardOptedIn;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    // Coerce non-bool / missing values to false. The contract is
    // strictly `{ value: bool }`, but defensive parsing keeps an older
    // web build that mis-types the field from corrupting the store.
    final value = data['value'] == true;

    // Prefer the cached `GlobalState().prefs` (initialized at app
    // start in `main.dart`). If the cache somehow isn't ready yet,
    // fall through to a fresh fetch — extremely unlikely by the time
    // a webview event fires, but harmless.
    final prefs = GlobalState().prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(kAlreadyDidV2OptInPrefsKey, value);

    // Mirror the opt-in flag to KMP right away so the native Profile's Vishwaas
    // banner suppresses immediately (parity with the drawer's live prefs read),
    // not only on the next RC push cycle. Fire-and-forget (push swallows errors).
    unawaited(KmpRemoteConfigMirror.push());

    return const BifrostResult.empty();
  }
}
