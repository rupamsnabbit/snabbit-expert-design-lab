import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/colors.dart';

/// Circular countdown timer widget — used by AWOL breach and delayed check-in
/// penalty overlays.
///
/// [triggerAt] is the absolute timestamp when the penalty fires (the deadline).
/// Remaining time is computed as `triggerAt − now` on every rebuild, so the
/// display is always wall-clock accurate regardless of polling gaps or
/// app-backgrounding.
class CountdownTimerWidget extends StatefulWidget {
  final int totalSeconds;
  final DateTime triggerAt;
  final VoidCallback? onTimeout;
  final double size;
  final String? label;
  final double strokeWidth;
  final bool allowNegative;
  final bool invertProgress;
  final Gradient? progressGradient;

  const CountdownTimerWidget({
    super.key,
    required this.totalSeconds,
    required this.triggerAt,
    this.onTimeout,
    this.size = 160,
    this.label,
    this.strokeWidth = 8.0,
    this.allowNegative = false,
    this.invertProgress = false,
    this.progressGradient,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with WidgetsBindingObserver {

  Timer? _timer;
  bool _hasNotifiedTimeout = false;

  int _computeRemaining() {
    final remaining = widget.triggerAt.difference(DateTime.now()).inSeconds;
    if (widget.allowNegative) {
      return remaining <= widget.totalSeconds ? remaining : widget.totalSeconds;
    }
    return remaining.clamp(0, widget.totalSeconds);
  }

  void _checkTimeout(int remaining) {
    if (!_hasNotifiedTimeout && remaining <= 0) {
      _hasNotifiedTimeout = true;
      widget.onTimeout?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasNotifiedTimeout = _computeRemaining() <= 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      final remaining = _computeRemaining();
      _checkTimeout(remaining);
      if (_hasNotifiedTimeout && !widget.allowNegative) timer.cancel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _checkTimeout(_computeRemaining());
    }
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerAt != oldWidget.triggerAt ||
        widget.totalSeconds != oldWidget.totalSeconds) {
      if (_computeRemaining() > 0) _hasNotifiedTimeout = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _computeRemaining();
    final total = widget.totalSeconds > 0 ? widget.totalSeconds : 1;
    final double progress;
    if (widget.invertProgress) {
      progress = ((total - remaining) / total).clamp(0.0, 1.0);
    } else {
      progress = (remaining / total).clamp(0.0, 1.0);
    }
    final absRemaining = remaining.abs();
    final minutes = absRemaining ~/ 60;
    final seconds = absRemaining % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final timeText = remaining < 0 ? '-$timeStr' : timeStr;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _TimerArcPainter(
          progress: progress,
          progressColor: AppColors.awolTimerArc,
          backgroundColor: AppColors.r10,
          strokeWidth: widget.strokeWidth,
          progressGradient: widget.progressGradient,
        ),
        child: Center(
          child: widget.label != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.size * 11 / 160,
                        fontWeight: FontWeight.w600,
                        color: AppColors.r50,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: widget.size * 30 / 160,
                        fontWeight: FontWeight.w700,
                        color: AppColors.r60,
                      ),
                    ),
                  ],
                )
              : Text(
                  timeText,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: widget.size * 30 / 160,
                    fontWeight: FontWeight.w700,
                    color: AppColors.r60,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TimerArcPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final Gradient? progressGradient;

  _TimerArcPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
    this.progressGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (progressGradient != null) {
      arcPaint.shader = progressGradient!.createShader(arcRect);
    } else {
      arcPaint.color = progressColor;
    }

    canvas.drawArc(arcRect, -pi / 2, 2 * pi * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_TimerArcPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.progressGradient != progressGradient;
}
