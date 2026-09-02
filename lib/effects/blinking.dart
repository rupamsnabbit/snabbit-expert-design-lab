import 'package:flutter/material.dart';

class BlinkingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool blink; // New flag

  const BlinkingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.blink = true,
  });

  @override
  State<BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<BlinkingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startBlinking();
  }

  void _startBlinking() {
    if (widget.blink && mounted) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0; // Fully visible when not blinking
    }
  }

  @override
  void didUpdateWidget(BlinkingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blink != oldWidget.blink ||
        widget.duration != oldWidget.duration) {
      if (widget.duration != oldWidget.duration) {
        _controller.duration = widget.duration;
      }
      _startBlinking();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.blink) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: widget.child,
        );
      },
    );
  }
}
