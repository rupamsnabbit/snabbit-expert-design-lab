enum RateCardVersion { v1, v2 }

RateCardVersion parseRateCardVersion(dynamic raw) {
  if (raw == null) return RateCardVersion.v1;
  if (raw is! String) return RateCardVersion.v1;
  final t = raw.trim();
  if (t.isEmpty) return RateCardVersion.v1;
  switch (t.toUpperCase()) {
    case 'V1':
      return RateCardVersion.v1;
    case 'V2':
      return RateCardVersion.v2;
    default:
      return RateCardVersion.v1;
  }
}

bool shouldShowVishwaasBanner(RateCardVersion v) => v == RateCardVersion.v1;

bool isOptedForNewRateCard(RateCardVersion v) => v == RateCardVersion.v2;

/// Parses `rate_card_optin_month` from the `runners/me` response. Expected
/// wire format is `YYYY-MM` (e.g. `"2026-05"`). Non-strings and malformed
/// values return `null`; callers should treat that as "unknown".
String? parseRateCardOptinMonth(dynamic raw) {
  if (raw is! String) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  // Light shape check: YYYY-MM. We don't validate calendar correctness
  // (February 30th etc.) — callers that need a real date can parse
  // further.
  final match = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').firstMatch(t);
  return match == null ? null : t;
}

/// Converts the `YYYY-MM` wire form into a [DateTime] at the first day of
/// the month (local time) so callers can do calendar math. Returns
/// `null` for malformed input.
DateTime? rateCardOptinMonthAsDate(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(raw);
  if (match == null) return null;
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), 1);
}

/// Whether [date] falls in v2 rate-card territory — on or after the first
/// day of the runner's [rateCardOptinMonth]. Returns `false` when the
/// opt-in month is unknown or malformed (caller treats unknown as
/// "stay native"). Used by the v1 earnings screens to detect when a
/// forward step (next month / next day) crosses into v2 — which the
/// native v1 screens don't own — so they can hand back to the webview.
bool isInRateCardV2Territory(DateTime date, String? rateCardOptinMonth) {
  final optinStart = rateCardOptinMonthAsDate(rateCardOptinMonth);
  if (optinStart == null) return false;
  return !date.isBefore(optinStart);
}
