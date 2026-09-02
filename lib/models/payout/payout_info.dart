import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// One generic earnings line shown inside [JobPayoutCard]'s breakdown.
///
/// The check-in line is NOT a [PayoutLine] — it's rendered separately by the
/// card from the root-level `check_in_*` fields.
class PayoutLine {
  final NudgeLabel title;
  final NudgeLabel? subtitle;
  final String? pillText;
  final String? iconUrl;
  final int? amount;

  const PayoutLine({
    required this.title,
    this.subtitle,
    this.pillText,
    this.iconUrl,
    this.amount,
  });

  factory PayoutLine.fromDynamic(dynamic raw) {
    if (raw is! Map) return const PayoutLine(title: NudgeLabel(key: ''));
    final rawSubtitle = raw['subtitle'];
    return PayoutLine(
      title: NudgeLabel.fromDynamic(raw['title']),
      subtitle: rawSubtitle is Map ? NudgeLabel.fromDynamic(rawSubtitle) : null,
      pillText: raw['pill_text'] as String?,
      iconUrl: raw['icon_url'] as String?,
      amount: anyValueToInt(raw['amount']),
    );
  }
}

/// Server-driven payout breakdown for a single job.
///
/// The card renders nothing when [PayoutInfo] itself is absent.
/// [breakdown] holds generic rows; the optional check-in row is derived from
/// [checkInAmount] + [checkInTime] + [actualCheckInTime] (see [JobPayoutCard]).
class PayoutInfo {
  final int? totalEarning;
  final List<PayoutLine> breakdown;
  final int? checkInAmount;
  final DateTime? checkInTime;
  final DateTime? actualCheckInTime;

  const PayoutInfo({
    this.totalEarning,
    this.breakdown = const [],
    this.checkInAmount,
    this.checkInTime,
    this.actualCheckInTime,
  });

  factory PayoutInfo.fromDynamic(dynamic raw) {
    if (raw is! Map) return const PayoutInfo();
    final list = raw['breakdown'];
    final lines = list is List
        ? list.map(PayoutLine.fromDynamic).toList(growable: false)
        : const <PayoutLine>[];
    return PayoutInfo(
      totalEarning: anyValueToInt(raw['total_earning']),
      breakdown: lines,
      checkInAmount: anyValueToInt(raw['check_in_amount']),
      checkInTime: parsePayoutCheckInTime(raw['check_in_time']),
      actualCheckInTime: parsePayoutCheckInTime(raw['actual_check_in_time']),
    );
  }

  bool get hasCheckInRow => checkInAmount != null;
}
