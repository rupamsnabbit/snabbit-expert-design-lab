import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/post_action_outcome.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/widgets/gamification/coin_flight_overlay.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_pill_badge.dart'
    show kNudgePillGoldCoinIconUrl, kNudgePillRedCardIconUrl;
import 'package:snabbit_runner/widgets/gamification/post_action_popup.dart';
import 'package:snabbit_runner/widgets/gamification/waiver_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/partner_home/home_rewards_header_pill.dart';

/// Orchestrates the post-action popup → coin-flight → header-update sequence.
class PostActionOverlayController {
  PostActionOverlayController._();
  static final instance = PostActionOverlayController._();

  bool _isShowing = false;

  /// The dialog route pushed by [_showPopupAndAwaitIdle], so we can remove
  /// exactly this route instead of blindly popping the top (which may be an
  /// unrelated dialog such as the overlay-permission prompt).
  DialogRoute<void>? _dialogRoute;

  /// Parse `postActionOutcome` from an API [responseData].
  /// Returns `null` if the response does not contain an outcome.
  ///
  /// TODO(gamification): Remove [actionType] param once all call sites are
  /// cleaned up — it is no longer used after stub removal.
  static PostActionOutcome? parseFromResponse(
    dynamic responseData,
    String actionType,
  ) {
    if (responseData is Map<String, dynamic>) {
      return PostActionOutcome.tryFromMap(
        responseData['post_action_outcome'] as Map<String, dynamic>? ??
            responseData['postActionOutcome'] as Map<String, dynamic>?,
      );
    }
    return null;
  }

  /// Convenience: parse from response + show in one call.
  /// Await this to ensure the animation completes before state refreshes
  /// (e.g. `fetchDataNow`) that may rebuild the widget tree.
  Future<void> showFromResponse(dynamic responseData, String actionType) async {
    final outcome = parseFromResponse(responseData, actionType);
    if (outcome != null) await show(outcome);
  }

  /// Runs the full reward/penalty animation sequence, or shows a waiver
  /// bottom sheet when the penalty has been waived.
  Future<void> show(PostActionOutcome outcome) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      final ctx = GlobalState().navigatorKey.currentContext;
      if (ctx == null) {
        _isShowing = false;
        return;
      }

      // Waived penalties get a bottom sheet instead of the overlay animation.
      if (outcome.isWaived) {
        try {
          await WaiverBottomSheet.show(ctx, outcome);
        } catch (e, st) {
          FirebaseCrashlytics.instance.recordError(
            e, st,
            reason: 'PostActionOverlayController.waiverSheet',
            fatal: false,
          );
        }
        _isShowing = false;
        return;
      }

      // 0. Precache the asset image so decoding doesn't cause jank mid-anim.
      final iconUrl = outcome.isReward
          ? kNudgePillGoldCoinIconUrl
          : kNudgePillRedCardIconUrl;
      try {
        await precacheImage(
          CachedNetworkImageProvider(iconUrl),
          ctx,
        );
      } catch (e, st) {
        // Non-fatal — animation will still work with placeholder.
        FirebaseCrashlytics.instance.recordError(
          e, st,
          reason: 'PostActionOverlayController.precacheImage',
          fatal: false,
        );
      }
      if (!ctx.mounted) return;

      // 1. Show popup dialog and wait for idle animation to complete.
      final result = await _showPopupAndAwaitIdle(ctx, outcome);
      if (result == null || result.centers.isEmpty) {
        // Must remove the [DialogRoute] or it stays on top of the stack; a later
        // [Navigator.pop] (e.g. from the denial bottom sheet) can pop past the
        // home route and leave the navigator with an empty history.
        _removeDialog();
        return;
      }

      // 2. Measure target position — land on the icon image, not the whole
      //    segment, so coins visually stack on the header icon.
      final iconKey = outcome.isReward
          ? HomeRewardsHeaderPillKeys.coinIconKey
          : HomeRewardsHeaderPillKeys.redCardIconKey;
      final segmentKey = outcome.isReward
          ? HomeRewardsHeaderPillKeys.coinSegmentKey
          : HomeRewardsHeaderPillKeys.redCardSegmentKey;
      final iconCtx = iconKey.currentContext;
      final iconBox = iconCtx?.findRenderObject() as RenderBox?;
      // Fall back to the segment context for Overlay lookup.
      final segmentCtx = segmentKey.currentContext;
      if (iconBox == null ||
          segmentCtx == null ||
          !segmentCtx.mounted) {
        _removeDialog();
        _isShowing = false;
        return;
      }
      final target = iconBox.localToGlobal(Offset.zero) +
          Offset(iconBox.size.width / 2, iconBox.size.height / 2);

      // 3. Insert coin flight overlay — use the segment's context to find
      //    the Overlay (navigatorKey context is the Navigator itself,
      //    which has no Overlay ancestor).
      final overlayState = Overlay.of(segmentCtx);
      final flightCompleter = Completer<void>();
      late final OverlayEntry flightEntry;
      flightEntry = OverlayEntry(
        builder: (_) => CoinFlightOverlay(
          sources: result.centers,
          target: target,
          startSize: result.coinSize,
          iconUrl: result.iconUrl,
          onComplete: () {
            if (!flightCompleter.isCompleted) flightCompleter.complete();
          },
        ),
      );
      overlayState.insert(flightEntry);

      // 4. Remove the popup dialog while coins fly.
      _removeDialog();

      // 5. Await flight completion (with timeout so we never hang forever).
      await flightCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      // 6. Remove flight overlay.
      flightEntry.remove();

      // 7. Update the provider balance.
      if (ctx.mounted) {
        final rt = ctx.read<RunnerRtDataProvider>();
        rt.applyPostActionBalance(
          coinsDelta: outcome.goldCoins,
          redCardsDelta: outcome.redCards,
          coinsTotal: outcome.goldCoinsTotal,
          redCardsTotal: outcome.redCardsTotal,
        );
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'PostActionOverlayController.show',
        fatal: false,
      );
      _removeDialog();
    } finally {
      _isShowing = false;
    }
  }

  /// Shows the popup and returns measured coin center offsets + size after idle.
  Future<_PopupMeasurement?> _showPopupAndAwaitIdle(
    BuildContext ctx,
    PostActionOutcome outcome,
  ) {
    final completer = Completer<_PopupMeasurement?>();
    final navigator = Navigator.of(ctx, rootNavigator: true);

    // Build and push a DialogRoute so we hold a reference to the exact route
    // and can remove it later without affecting other dialogs.
    _dialogRoute = DialogRoute<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => PostActionPopup(
        outcome: outcome,
        onReadyForFlight: (centers, coinSize, iconUrl) {
          if (!completer.isCompleted) {
            completer.complete(
              _PopupMeasurement(centers, coinSize, iconUrl),
            );
          }
        },
      ),
    );

    navigator.push(_dialogRoute!).then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  /// Removes the tracked dialog route specifically, so other dialogs
  /// (e.g. overlay permission prompt) are not accidentally dismissed.
  /// Prefer a [BuildContext] that was checked with [BuildContext.mounted] after
  /// any [await]; if none is available, the root [navigator] key is used.
  void _removeDialog([BuildContext? fromContext]) {
    final route = _dialogRoute;
    _dialogRoute = null;
    if (route == null) return;

    final ctx = (fromContext != null && fromContext.mounted)
        ? fromContext
        : GlobalState().navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      final navigator = Navigator.of(ctx, rootNavigator: true);
      if (route.isActive) {
        navigator.removeRoute(route);
      }
    } catch (e) {
      debugPrint('[PostActionOverlayController] _removeDialog error: $e');
    }
  }
}

class _PopupMeasurement {
  final List<Offset> centers;
  final double coinSize;
  final String iconUrl;
  const _PopupMeasurement(this.centers, this.coinSize, this.iconUrl);
}
