import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

/// Sends a v2 runner off a native v1 payouts screen when they step forward
/// into v2 rate-card territory (the opt-in month or later) — months the v1
/// native screens don't serve.
///
/// - Reached the v1 screen *from* the v2 webview (`fromWebview == true`):
///   pop back, so the runner lands on their exact prior spot in the webview.
/// - Pure native navigation (`fromWebview == false`): replace the v1 screen
///   with the v2 payouts webview (replaced, not stacked — see below) at the
///   page matching the screen they were on.
///
/// Call only after confirming — via `isRateCardV2Effective` and
/// `isInRateCardV2Territory` — that v2 has taken effect for the runner and
/// the target period is in v2 territory.
void _handoffToV2Payouts(
  BuildContext context, {
  required bool fromWebview,
  required String webviewPath,
  String title = 'Earnings',
}) {
  if (fromWebview) {
    Navigator.of(context).pop();
    return;
  }
  // Replace (not push) the v1 screen, so Back from the webview doesn't land
  // on the v1 boundary screen — which would let the runner step right back
  // into the same handoff (v1 → webview → v1 → …).
  Navigator.of(context).pushReplacementNamed(
    AppWebViewPage.routeName,
    arguments: WebViewArgs(
      url: buildWebviewUrl(webviewPath),
      title: title,
    ),
  );
}

/// v1 monthly earnings (PayoutHome) → v2 monthly summary.
void handoffToV2MonthlyPayouts(
  BuildContext context, {
  required bool fromWebview,
}) =>
    _handoffToV2Payouts(
      context,
      fromWebview: fromWebview,
      webviewPath: WebviewRoutes.payoutsMonthlySummary,
    );

/// v1 daily-earnings list (month level) → v2 daily payouts list.
void handoffToV2DailyPayouts(
  BuildContext context, {
  required bool fromWebview,
}) =>
    _handoffToV2Payouts(
      context,
      fromWebview: fromWebview,
      webviewPath: WebviewRoutes.payoutsDaily,
    );

/// v1 per-day breakdown → v2 day-level summary, seeded to [date] when known
/// (formatted `YYYY-MM-DD`).
void handoffToV2DayPayouts(
  BuildContext context, {
  required bool fromWebview,
  DateTime? date,
}) {
  // Locale pinned to 'en' so the value is always ASCII YYYY-MM-DD — it goes
  // straight into the v2 webview URL path and must not carry native-digit
  // numerals from the runner's app language (Hindi/Telugu/etc.).
  final formatted =
      date == null ? null : DateFormat('yyyy-MM-dd', 'en').format(date);
  _handoffToV2Payouts(
    context,
    fromWebview: fromWebview,
    webviewPath: WebviewRoutes.payoutsDayLevelSummary(date: formatted),
  );
}
