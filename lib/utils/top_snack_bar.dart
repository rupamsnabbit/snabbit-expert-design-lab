import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';

OverlayEntry? _currentEntry;

void showTopSnackBar({
  required String message,
  required bool isSuccess,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = GlobalState().navigatorKey.currentState?.overlay;
  if (overlay == null) return;

  _currentEntry?.remove();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopSnackBar(
      message: message,
      isSuccess: isSuccess,
      duration: duration,
      onDismiss: () {
        if (identical(_currentEntry, entry)) _currentEntry = null;
        entry.remove();
      },
    ),
  );
  _currentEntry = entry;
  overlay.insert(entry);
}

class _TopSnackBar extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopSnackBar({
    required this.message,
    required this.isSuccess,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBar> createState() => _TopSnackBarState();
}

class _TopSnackBarState extends State<_TopSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _dismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _controller.animateTo(0, curve: Curves.easeIn);
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _dismissed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12.h,
      left: 16.w,
      right: 16.w,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.n90,
                borderRadius: BorderRadius.circular(50.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      color: widget.isSuccess ? AppColors.g40 : AppColors.r50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isSuccess ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 14.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
