import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/language_home.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_list.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_state.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';
import 'package:snabbit_runner/payout/bonus/pages/festive_bonus_screen.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/route_registry.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_modal_sheet.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/pan_details_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

/// Authoritative map of `snabbit://` URIs the web is allowed to navigate to.
///
/// Additions are a PR — product signs off on the URI list one week before
/// each launch. Keep this list tight: every entry widens the web→native
/// surface area.
RouteRegistry defaultWebViewRouteRegistry() {
  return RouteRegistry([
    RouteEntry.named(
      uri: 'snabbit://add-bank-upi',
      routeName: '/add_bank_or_upi_details',
    ),
    // Unified entry for the web-based onboarding hub. The web fires
    // `snabbit://onboarding_steps?module_id=<int>&module_name=<slug>` per
    // module tap; we fetch that module's first question and push the screen
    // getInitialQuestion resolves — except `bank_details`, which is routed to
    // AddBankOrUpiDetailsScreen gated on a session_id. See _openOnboardingStep.
    RouteEntry(
      uri: 'snabbit://onboarding_steps',
      argsValidator: _validateOnboardingStepArgs,
      opener: _openOnboardingStep,
    ),
    RouteEntry.sheet(
      uri: 'snabbit://add-pan-details',
      maxHeightFraction: 0.7,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const UploadPanModalSheetV2(),
      ),
    ),
    // View-only sheet for an already-added bank account. Mirrors the v1
    // Payouts "View bank details" affordance.
    //
    // Uses a custom opener (not [RouteEntry.sheet]) so we can read the
    // runner profile from [UserProfileProvider] at the navigator's
    // context — reliably above MaterialApp / below MultiProvider — and
    // inject it into the sheet. The viewer's implicit Provider lookup
    // inside the modal route can come back null, leaving the fields
    // empty; passing `user` explicitly is the source-of-truth path
    // (Flutter Provider state, not a web round-trip).
    //
    // `allowEdit: true` keeps the in-sheet "Update details" button,
    // which pops the sheet and pushes /add_bank_or_upi_details (same
    // behavior as v1).
    RouteEntry(
      uri: 'snabbit://view-bank-details',
      opener: (navigator, args, {required replace}) async {
        final ctx = navigator.currentContext;
        if (ctx == null) {
          throw StateError(
            'view-bank-details: no live BuildContext on the navigator key',
          );
        }
        final user = Provider.of<UserProfileProvider>(ctx, listen: false).user;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
        unawaited(
          showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            constraints: BoxConstraints(maxHeight: maxHeight),
            builder: (_) => SafeArea(
              child: BankDetailsModalSheet(
                allowEdit: true,
                user: user,
              ),
            ),
          ),
        );
      },
    ),
    // View-only sheet for an already-added PAN. Mirrors the v1
    // `showPanDetailsBottomSheet` UX (read-only PAN number + OK).
    RouteEntry.sheet(
      uri: 'snabbit://view-pan-details',
      builder: (ctx) => const SafeArea(
        child: CommonBottomSheetSetup(
          child: PanDetailsBottomSheetContent(),
        ),
      ),
    ),
    RouteEntry.named(
      uri: 'snabbit://withdraw-early-payout',
      routeName: '/early-payouts',
    ),
    RouteEntry.named(
      uri: 'snabbit://view-payout-history',
      routeName: '/transaction-history',
    ),
    RouteEntry.named(
      uri: 'snabbit://referral-earnings',
      routeName: '/referral-home',
    ),
    // Web's v2 Payouts page sends the runner back here when they pick a
    // month older than their `rateCardOptinMonth` — the new payouts
    // service doesn't serve v1 data, so we fall back to the native
    // Earnings screen seeded to the requested month.
    RouteEntry.named(
      uri: 'snabbit://earnings-v1',
      routeName: PayoutHome.routeName,
      argsValidator: _validateEarningsV1Args,
    ),
    // Same pre-optin fallback as `earnings-v1`, but for the Daily
    // Earnings list (month-level). Web sends the runner here when they
    // navigate the daily-earnings page to a pre-optin month.
    RouteEntry.named(
      uri: 'snabbit://daily-earnings-v1',
      routeName: DailyEarningsList.routeName,
      argsValidator: _validateDailyEarningsV1Args,
    ),
    // Pre-optin fallback for a specific day — opens the native per-day
    // earnings breakdown seeded to the requested date. Web sends the
    // runner here when they open a pre-optin day in the daily-earnings
    // page.
    RouteEntry.named(
      uri: 'snabbit://daily-earnings-day-v1',
      routeName: DailyEarningState.routeName,
      argsValidator: _validateDailyEarningsDayV1Args,
    ),
    // Payout issue menu on the v2 Payouts page — "Report new issue" and
    // "View issue history" options both drop back into the native
    // dispute flow (same screens the v1 Payouts button opens).
    RouteEntry.named(
      uri: 'snabbit://report-new-issue',
      routeName: '/new-issue-reporter',
    ),
    RouteEntry.named(
      uri: 'snabbit://view-issue-history',
      routeName: '/issue-history',
    ),
    // Festive bonus screen — pushed on top of the webview. Back button
    // returns to the webview (default Navigator.pushNamed semantics).
    // No args — the screen reads everything it needs from providers /
    // its own state.
    RouteEntry.named(
      uri: 'snabbit://festive-bonus',
      routeName: FestiveBonusScreen.routeName,
    ),
    // Language picker from web (e.g. city registration). Awaits the push so
    // the navigate RPC resolves when the user pops LanguageHome — web then
    // refreshInitData() picks up the new languagePreference.
    RouteEntry(
      uri: 'snabbit://change-language',
      opener: (navigator, args, {required replace}) async {
        if (replace) {
          await navigator.pushReplacementNamed(LanguageHome.routeName);
        } else {
          await navigator.pushNamed(LanguageHome.routeName);
        }
      },
    ),
  ]);
}

/// Shared `{ month: 'YYYY-MM' }` parser for the v1 earnings routes.
/// Returns the first-of-month [DateTime], or `null` when the field is
/// missing / not a string / malformed. Reuses [rateCardOptinMonthAsDate]
/// since the wire format is identical (`YYYY-MM`).
DateTime? _parseWebviewMonthArg(Map<String, dynamic> data) {
  final raw = data['month'];
  if (raw is! String) return null;
  return rateCardOptinMonthAsDate(raw.trim());
}

/// Shared `{ date: 'YYYY-MM-DD' }` parser for the v1 daily route.
/// Returns the parsed [DateTime], or `null` when missing / malformed.
///
/// Deliberately a strict regex, not `DateTime.tryParse`: this is a web→native
/// trust boundary and `tryParse` is too lenient here — it also accepts
/// time-bearing ISO strings (e.g. `2026-05-22T09:00`) and does not range-check
/// the month, so `2026-13-01` would silently roll forward to Jan 2027 instead
/// of being rejected. The regex pins the exact `YYYY-MM-DD` shape.
DateTime? _parseWebviewDateArg(Map<String, dynamic> data) {
  final raw = data['date'];
  if (raw is! String) return null;
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$')
      .firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // Reject impossible calendar dates the per-field regex can't catch
  // (e.g. `2026-02-31`): DateTime would silently roll them forward.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Parses `{ month: 'YYYY-MM' }` → [PayoutHomeArgs]. The web is the only
/// caller today; reject anything that doesn't match the shape so we don't
/// silently navigate to the wrong month.
ArgsResult _validateEarningsV1Args(Map<String, dynamic> data) {
  final month = _parseWebviewMonthArg(data);
  if (month == null) {
    return ArgsResult.invalid("Missing or invalid 'month' (expected YYYY-MM)");
  }
  return ArgsResult.ok(
    PayoutHomeArgs(initialMonth: month, fromWebview: true),
  );
}

/// Parses `{ month: 'YYYY-MM' }` → [DailyEarningsListArgs] for the
/// daily-earnings list (month-level) pre-optin fallback.
ArgsResult _validateDailyEarningsV1Args(Map<String, dynamic> data) {
  final month = _parseWebviewMonthArg(data);
  if (month == null) {
    return ArgsResult.invalid("Missing or invalid 'month' (expected YYYY-MM)");
  }
  return ArgsResult.ok(
    DailyEarningsListArgs(initialMonth: month, fromWebview: true),
  );
}

/// Parses `{ date: 'YYYY-MM-DD' }` → [DailyEarningStateArgs] for the
/// per-day earnings breakdown pre-optin fallback.
ArgsResult _validateDailyEarningsDayV1Args(Map<String, dynamic> data) {
  final date = _parseWebviewDateArg(data);
  if (date == null) {
    return ArgsResult.invalid("Missing or invalid 'date' (expected YYYY-MM-DD)");
  }
  return ArgsResult.ok(
    DailyEarningStateArgs(initialDate: date, fromWebview: true),
  );
}

/// Validates `snabbit://onboarding_steps` args → `(moduleId, moduleName)`.
///
/// `module_id` is the only required field — it identifies which onboarding
/// module's first question to fetch. It arrives via the URI query string
/// (`?module_id=1&module_name=…`), so it's a string here; accept an int too
/// for forward-compatibility if the web ever moves it into the data map.
/// `module_name` is optional and used by [_openOnboardingStep] to special-case
/// the bank flow (`bank_details`); other modules don't read it.
ArgsResult _validateOnboardingStepArgs(Map<String, dynamic> data) {
  final raw = data['module_id'];
  final id = raw is int ? raw : int.tryParse('${raw ?? ''}');
  if (id == null) {
    return ArgsResult.invalid("Missing or invalid 'module_id' (expected int)");
  }
  final name = data['module_name']?.toString();
  return ArgsResult.ok((moduleId: id, moduleName: name));
}

/// Module name the web sends for the bank step. Matches the native
/// onboarding hub's `onCtaTap` branch exactly (underscore, not hyphen).
const String _bankDetailsModuleName = 'bank_details';

/// Opener for `snabbit://onboarding_steps`. Fetches the first question for
/// the given module, then navigates. Adapts onboarding_screen's `onCtaTap`
/// to the route-registry opener contract:
///
/// - `bank_details`: getInitialQuestion seeds the native session, then we push
///   [AddBankOrUpiDetailsScreen] only once a `session_id` exists (else surface
///   the provider's error via snackbar). The resolved getCurrentScreen route is
///   intentionally ignored for this module.
/// - everything else: push whichever screen getInitialQuestion resolves.
///
/// The fetch is run detached (`unawaited`) so the navigate RPC doesn't block
/// on the network round-trip, per [RouteOpener]'s "keep it fast" convention.
/// Failures are surfaced natively (provider ErrorHandler / snackbar) — the
/// same UX as the native hub — rather than back through the navigate RPC.
Future<void> _openOnboardingStep(
  AppNavigator navigator,
  Object? args, {
  required bool replace,
}) async {
  final ctx = navigator.currentContext;
  if (ctx == null) {
    throw StateError('onboarding_steps: no live BuildContext on navigator key');
  }
  final (:moduleId, :moduleName) =
      args as ({int moduleId, String? moduleName});
  final provider = ctx.read<OnboardingStepsProvider>();

  unawaited(() async {
    final route = await provider.getInitialQuestion(
      context: ctx,
      moduleId: moduleId,
      launchedFromWebHub: true,
    );

    if (moduleName == _bankDetailsModuleName) {
      final after = navigator.currentContext;
      if (after == null || !after.mounted) return;
      if (provider.onboardingQuestionResponse?.sessionId != null) {
        if (replace) {
          await navigator
              .pushReplacementNamed(AddBankOrUpiDetailsScreen.routeName);
        } else {
          await navigator.pushNamed(AddBankOrUpiDetailsScreen.routeName);
        }
      } else if (provider.onboardingQAError != null) {
        showSnackbar(
          after,
          provider.onboardingQAError?.message ?? 'An error occurred',
        );
      }
      return;
    }

    // Re-check the navigator is still live after the await; error already
    // surfaced by getInitialQuestion when route is null.
    if (route == null || navigator.currentContext == null) return;

    // getInitialQuestion maps page_type:"module" → OnboardingScreen (the
    // native hub).  With V2 the hub IS the training webview — replace the
    // current webview with a fresh instance so the user sees updated state.
    if (route == OnboardingScreen.routeName &&
        RemoteConfigHelperUtils.isTrainingV2Enabled) {
      final ctx = navigator.currentContext;
      if (ctx != null) {
        NavigationUtils.openTrainingWebView(context: ctx, replace: true);
      }
      return;
    }

    if (replace) {
      await navigator.pushReplacementNamed(route);
    } else {
      await navigator.pushNamed(route);
    }
  }());
}
