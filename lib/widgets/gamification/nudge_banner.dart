import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/nudge_pill.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/gamification/nudge_pill_badge.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';

/// Shared structural chrome for all nudge strips: [leading] [label] [trailing].
///
/// Callers own theming via [decoration]; this widget owns padding, corner
/// radius, min-height constraint, slot spacing, and bottom margin so both
/// [NudgeBanner] and the AWOL breach strip share identical layout chrome.
class NudgeStripTile extends StatelessWidget {
  final Widget leading;
  final Widget label;
  final Widget? trailing;
  final BoxDecoration decoration;

  /// When false (e.g. not the last in a column) the bottom padding is halved.
  final bool isLastStrip;

  const NudgeStripTile({
    super.key,
    required this.leading,
    required this.label,
    this.trailing,
    required this.decoration,
    this.isLastStrip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLastStrip ? 24.h : 12.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
        decoration: decoration,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 46.67.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              SizedBox(width: 8.w),
              Expanded(child: label),
              if (trailing != null) ...[
                SizedBox(width: 8.w),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// All pre-action nudges from BE, in order (e.g. three strips if `preActionNudges.length == 3`).
class NudgeBannerList extends StatelessWidget {
  final List<PreActionNudge> nudges;

  const NudgeBannerList({super.key, required this.nudges});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nudges.length; i++)
          NudgeBanner(
            key: ValueKey(
                '${nudges[i].lifecycleActionType}_${nudges[i].iconUrl}_$i'),
            nudge: nudges[i],
            isLastStrip: i == nudges.length - 1,
          ),
      ],
    );
  }
}

/// Key Alerts–style horizontal strip (LLD §2.1, Figma `5510:15594`).
/// Trailing pill is derived from [PreActionNudge.goldCoins] / [PreActionNudge.redCards] only.
///
/// Stack multiple strips with [isLastStrip]: false for every item except the last so spacing
/// matches a single strip’s bottom padding on the final row only.
class NudgeBanner extends StatefulWidget {
  final PreActionNudge nudge;

  /// When another [NudgeBanner] follows below, pass false for a tighter gap between strips.
  final bool isLastStrip;

  const NudgeBanner({
    super.key,
    required this.nudge,
    this.isLastStrip = true,
  });

  @override
  State<NudgeBanner> createState() => _NudgeBannerState();
}

class _NudgeBannerState extends State<NudgeBanner> {
  Timer? _timer;
  bool _expiredHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleExpiryTimer();
  }

  @override
  void didUpdateWidget(covariant NudgeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nudge.expiresAt != widget.nudge.expiresAt) {
      _timer?.cancel();
      _expiredHandled = false;
      _scheduleExpiryTimer();
    }
  }

  void _scheduleExpiryTimer() {
    final exp = widget.nudge.expiresAt;
    if (exp == null) return;
    void tick() {
      if (!mounted) return;
      if (DateTime.now().isBefore(exp)) {
        setState(() {});
        return;
      }
      if (!_expiredHandled) {
        _expiredHandled = true;
        _timer?.cancel();
        context.read<RunnerRtDataProvider>().fetchDataNow();
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final labelText = resolveNudgeLabel(widget.nudge.label, lang);
    final pill = deriveNudgePill(
      goldCoins: widget.nudge.goldCoins,
      redCards: widget.nudge.redCards,
    );
    final isRisk = widget.nudge.isRisk;
    final isBonus = widget.nudge.isBonus;

    // Risk strip — Figma Expert-App-2.0 `5510:13297`: gray-50 → red-200, border red-200 2px.
    final border = isRisk
        ? const Color(0xFFFECACA)
        : isBonus
            ? const Color(0xFF93C5FD)
            : const Color(0xFFFDE68A);
    final gradient = isRisk
        ? const LinearGradient(
            colors: [
              Color(0xFFF9FAFB),
              Color(0xFFFECACA),
            ],
          )
        : isBonus
            ? const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              )
            : const LinearGradient(
                // yellow-50 #fffbeb → cream #fff4c7 (Expert-App-2.0 / 5510:15594)
                colors: [Color(0xFFFFFBEB), Color(0xFFFFF4C7)],
              );

    return NudgeStripTile(
      isLastStrip: widget.isLastStrip,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: border, width: 2),
      ),
      leading: _LeadingIcon(url: widget.nudge.iconUrl),
      label: _NudgeLabelText(
        label: labelText,
        defaultColor: isBonus ? Colors.white : null,
      ),
      trailing: pill.hasPill ? NudgePillBadge(pill: pill) : null,
    );
  }
}

/// Renders the nudge label with mixed weights per Figma 5510:15594:
///   base: Outfit Medium 14/20, color gray-700 (#374151)
///   `**emphasis**` segments: Outfit Bold (700)
///   unwrapped segments: Outfit Regular (400)
///
/// Example translation template: `**Login** by **7:40 AM** to earn` →
///   bold "Login", regular " by ", bold "7:40 AM", regular " to earn".
/// Plain strings without `**` markers render as medium (single span).
class _NudgeLabelText extends StatelessWidget {
  final String label;

  /// When set (e.g. bonus strip), label uses this instead of gray-700.
  final Color? defaultColor;

  const _NudgeLabelText({required this.label, this.defaultColor});

  static const Color _textColor = Color(0xFF374151);

  @override
  Widget build(BuildContext context) {
    final fg = defaultColor ?? _textColor;
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: fg,
          height: 20 / 14,
        );

    final segments = _parseBoldSegments(label);
    if (segments.length == 1 && !segments.first.bold) {
      // No markers — render as single span to preserve original behavior.
      return Text(label, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final s in segments)
            TextSpan(
              text: s.text,
              style: baseStyle?.copyWith(
                fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
                color: fg,
              ),
            ),
        ],
      ),
    );
  }

  /// Parses `**bold**` markers. Unmatched `**` is treated as literal.
  static List<_Segment> _parseBoldSegments(String input) {
    final result = <_Segment>[];
    final buf = StringBuffer();
    var i = 0;
    var bold = false;
    while (i < input.length) {
      if (i + 1 < input.length && input[i] == '*' && input[i + 1] == '*') {
        final rest = input.substring(i + 2);
        final closeIdx = rest.indexOf('**');
        if (!bold && closeIdx >= 0) {
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
    if (buf.isNotEmpty) result.add(_Segment(buf.toString(), bold));
    if (result.isEmpty) result.add(const _Segment('', false));
    return result;
  }
}

class _Segment {
  final String text;
  final bool bold;
  const _Segment(this.text, this.bold);
}

class _LeadingIcon extends StatelessWidget {
  final String url;

  const _LeadingIcon({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: SizedBox(
        width: 36.w,
        height: 36.w,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.n20),
          errorWidget: (_, __, ___) => Icon(Icons.image_not_supported,
              size: 24.sp, color: AppColors.n50),
        ),
      ),
    );
  }
}
