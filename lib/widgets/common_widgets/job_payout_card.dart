import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';

/// Visual variant of the dedicated check-in row.
/// `info` and `success` paint a tinted background that bleeds edge-to-edge
/// within the card; `danger` is a regular row with red emphasis on the
/// dynamic "X min late" portion of the title.
enum _CheckInVariant { info, success, danger }

const _kCardPadding = 16.0;
const _kRowVerticalSpacing = 8.0;

const _kLabelGray = Color(0xFF6B7280);
const _kAmountDark = Color(0xFF374151);
const _kAmountMuted = Color(0xFF9CA3AF);
const _kCardBg = Color(0xFFF9FAFB);
const _kCardBorder = Color(0xFFF3F4F6);
const _kSolidDivider = Color(0xFFE5E7EB);
const _kPillBlueBg = Color(0xFFEFF6FF);
const _kPillBlueBorder = Color(0xFFDBEAFE);
const _kPillBlueText = Color(0xFF1D4ED8);
const _kInfoBg = Color(0xFFEFF6FF);
const _kInfoBorder = Color(0xFFDBEAFE);
const _kInfoAccent = Color(0xFF1D4ED8);
const _kSuccessBg = Color(0xFFECFDF5);
const _kSuccessBorder = Color(0xFFD1FAE5);
const _kSuccessAccent = Color(0xFF059669);
const _kDangerAccent = Color(0xFFDC2626);
const _kTotalGreen = Color(0xFF059669);
const _kHeaderGray = Color(0xFF6B7280);

/// Full payout breakdown card showing total earning and line-item details.
///
/// Used on New Job Assigned and Job Completed (Rating) screens.
/// Renders nothing if [payoutInfo] is null.
class JobPayoutCard extends StatelessWidget {
  final PayoutInfo? payoutInfo;
  final String headerText;

  const JobPayoutCard({
    super.key,
    required this.payoutInfo,
    required this.headerText,
  });

  @override
  Widget build(BuildContext context) {
    final info = payoutInfo;
    if (info == null) return const SizedBox.shrink();

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final rows = _buildRows(info, languageProvider);
        final children = <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _kCardPadding.w),
            child: Column(
              children: [
                Text(
                  headerText,
                  style: TextStyle(
                    color: _kHeaderGray,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  formatIndianCurrency(info.totalEarning),
                  style: TextStyle(
                    color: _kTotalGreen,
                    fontSize: 40.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ];

        if (rows.isNotEmpty) {
          children.add(SizedBox(height: 12.h));
          children.add(Padding(
            padding: EdgeInsets.symmetric(horizontal: _kCardPadding.w),
            child: Container(height: 1, color: _kSolidDivider),
          ));
          children.add(SizedBox(height: 12.h));
          for (var i = 0; i < rows.length; i++) {
            final row = rows[i];
            if (i > 0) {
              final prev = rows[i - 1];
              final showDivider = !prev.tinted && !row.tinted;
              if (showDivider) {
                children.add(Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _kCardPadding.w,
                    vertical: _kRowVerticalSpacing.h,
                  ),
                  child: const _DottedDivider(),
                ));
              } else {
                children.add(SizedBox(height: _kRowVerticalSpacing.h));
              }
            }
            children.add(row.widget);
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            border: Border.all(color: _kCardBorder),
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(vertical: _kCardPadding.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }

  List<_RowEntry> _buildRows(PayoutInfo info, LanguageProvider lp) {
    final entries = <_RowEntry>[];
    for (final line in info.breakdown) {
      final subtitle = line.subtitle;
      entries.add(_RowEntry(
        widget: Padding(
          padding: EdgeInsets.symmetric(horizontal: _kCardPadding.w),
          child: _PayoutRow(
            title: resolveNudgeLabel(line.title, lp),
            subtitle: subtitle == null ? null : resolveNudgeLabel(subtitle, lp),
            pillText: line.pillText,
            iconUrl: line.iconUrl,
            amount: line.amount,
          ),
        ),
        tinted: false,
      ));
    }

    final checkIn = _buildCheckInRow(info);
    if (checkIn != null) {
      // Convention: insert after the first generic row when one exists.
      // Matches Figma where check-in sits between Work and Long Distance.
      final position = entries.isEmpty ? 0 : 1;
      entries.insert(position, checkIn);
    }

    return entries;
  }

  _RowEntry? _buildCheckInRow(PayoutInfo info) {
    if (!info.hasCheckInRow) return null;

    final scheduled = info.checkInTime;
    final actual = info.actualCheckInTime;

    final String template;
    final Map<String, dynamic> params;
    final _CheckInVariant variant;

    if (actual == null) {
      final byTime = formatPayoutCheckInTimeDisplay(scheduled) ?? '';
      template = 'Check In by **{{time}}**';
      params = {'time': byTime};
      variant = _CheckInVariant.info;
    } else {
      final diffMins =
          scheduled == null ? 0 : actual.difference(scheduled).inMinutes;
      if (diffMins <= 0) {
        template = 'Checked In **{{mins}} min early**';
        params = {'mins': diffMins.abs()};
        variant = _CheckInVariant.success;
      } else {
        template = 'Checked In **{{mins}} min late**';
        params = {'mins': diffMins};
        variant = _CheckInVariant.danger;
      }
    }

    final widget = _CheckInPayoutRow(
      template: _substitute(template, params),
      amount: info.checkInAmount,
      variant: variant,
    );

    final tinted = variant != _CheckInVariant.danger;
    return _RowEntry(widget: widget, tinted: tinted);
  }

  static String _substitute(String tpl, Map<String, dynamic> params) {
    var out = tpl;
    params.forEach((k, v) => out = out.replaceAll('{{$k}}', '$v'));
    return out;
  }
}

class _RowEntry {
  final Widget widget;
  final bool tinted;

  const _RowEntry({required this.widget, required this.tinted});
}

class _PayoutRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? pillText;
  final String? iconUrl;
  final int? amount;

  const _PayoutRow({
    required this.title,
    this.subtitle,
    this.pillText,
    this.iconUrl,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kLabelGray,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kLabelGray,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (iconUrl != null && iconUrl!.isNotEmpty) ...[
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CachedNetworkImage(
                    imageUrl: iconUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              SizedBox(width: 8.w),
              if (pillText != null && pillText!.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _kPillBlueBg,
                    border: Border.all(color: _kPillBlueBorder),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    pillText!,
                    style: TextStyle(
                      color: _kPillBlueText.withValues(alpha: 0.6),
                      fontSize: 12.sp,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        if (amount != null)
          Text(
            formatIndianCurrency(amount),
            style: TextStyle(
              color: _kAmountDark,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

/// Special row for the check-in line. Tinted (info/success) variants paint a
/// full-card-width background; the danger variant renders as a regular row
/// with a red bold span on the dynamic late-by-N text and a muted amount.
class _CheckInPayoutRow extends StatelessWidget {
  /// `Check In by **7:45 PM**` style template — `**...**` portion is the accent.
  final String template;
  final int? amount;
  final _CheckInVariant variant;

  const _CheckInPayoutRow({
    required this.template,
    required this.amount,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final isLate = variant == _CheckInVariant.danger;
    final accent = _accentFor(variant);
    final amountColor = isLate ? _kAmountMuted : _kAmountDark;

    final inner = Row(
      children: [
        Expanded(
          child: _BoldAccentText(
            template: template,
            baseColor: _kLabelGray,
            accentColor: accent,
          ),
        ),
        if (amount != null)
          Text(
            formatIndianCurrency(amount),
            style: TextStyle(
              color: amountColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );

    if (isLate) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: _kCardPadding.w),
        child: inner,
      );
    }

    final bg = variant == _CheckInVariant.info ? _kInfoBg : _kSuccessBg;
    final border =
        variant == _CheckInVariant.info ? _kInfoBorder : _kSuccessBorder;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: border),
            bottom: BorderSide(color: border),
          )),
      padding: EdgeInsets.symmetric(
        horizontal: _kCardPadding.w,
        vertical: 8.h,
      ),
      child: inner,
    );
  }

  static Color _accentFor(_CheckInVariant v) {
    switch (v) {
      case _CheckInVariant.info:
        return _kInfoAccent;
      case _CheckInVariant.success:
        return _kSuccessAccent;
      case _CheckInVariant.danger:
        return _kDangerAccent;
    }
  }
}

/// Renders text with `**bold**` segments highlighted in [accentColor].
/// Plain segments use [baseColor]. Same parser semantics as `_NudgeLabelText`.
class _BoldAccentText extends StatelessWidget {
  final String template;
  final Color baseColor;
  final Color accentColor;

  const _BoldAccentText({
    required this.template,
    required this.baseColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseBoldSegments(template);
    return Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(
              text: s.text,
              style: TextStyle(
                color: s.bold ? accentColor : baseColor,
                fontSize: 14.sp,
                fontWeight: s.bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  static List<_Segment> _parseBoldSegments(String input) {
    final result = <_Segment>[];
    final buf = StringBuffer();
    var i = 0;
    while (i < input.length) {
      if (i + 1 < input.length && input[i] == '*' && input[i + 1] == '*') {
        final rest = input.substring(i + 2);
        final closeIdx = rest.indexOf('**');
        if (closeIdx >= 0) {
          if (buf.isNotEmpty) {
            result.add(_Segment(buf.toString(), false));
            buf.clear();
          }
          result.add(_Segment(rest.substring(0, closeIdx), true));
          i = i + 2 + closeIdx + 2;
          continue;
        }
      }
      buf.write(input[i]);
      i++;
    }
    if (buf.isNotEmpty) result.add(_Segment(buf.toString(), false));
    if (result.isEmpty) result.add(const _Segment('', false));
    return result;
  }
}

class _Segment {
  final String text;
  final bool bold;
  const _Segment(this.text, this.bold);
}

class _DottedDivider extends StatelessWidget {
  const _DottedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotSize = 2.0;
        const gap = 4.0;
        final count = (constraints.constrainWidth() / (dotSize + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                color: _kSolidDivider,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
