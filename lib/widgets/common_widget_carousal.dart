import 'dart:async';
import 'package:flutter/material.dart';

class CommonWidgetCarousel extends StatefulWidget {
  final List<Widget> children;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool showIndicators;
  final Color activeIndicatorColor;
  final Color inactiveIndicatorColor;
  final double indicatorSize;
  final double indicatorSpacing;
  final double indicatorBottomPadding;
  final Function(int index)? onPageChanged;

  const CommonWidgetCarousel({
    super.key,
    required this.children,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOut,
    this.showIndicators = true,
    this.activeIndicatorColor = Colors.white,
    this.inactiveIndicatorColor = Colors.white54,
    this.indicatorSize = 8.0,
    this.indicatorSpacing = 8.0,
    this.indicatorBottomPadding = 16.0,
    this.onPageChanged,
  });

  @override
  State<CommonWidgetCarousel> createState() => _CommonWidgetCarouselState();
}

class _CommonWidgetCarouselState extends State<CommonWidgetCarousel> {
  int _currentIndex = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && widget.children.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (!mounted) return;

      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.children.length;
      });
      widget.onPageChanged?.call(_currentIndex);
    });
  }

  void _goToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onPageChanged?.call(index);

    // Restart auto-play timer
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.children.length == 1) {
      return widget.children[0];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: widget.animationDuration,
          switchInCurve: widget.animationCurve,
          switchOutCurve: widget.animationCurve,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: SizedBox(
            key: ValueKey<int>(_currentIndex),
            width: double.infinity,
            child: widget.children[_currentIndex],
          ),
        ),
        if (widget.showIndicators && widget.children.length > 1)
          Padding(
            padding: EdgeInsets.only(top: widget.indicatorBottomPadding),
            child: _buildIndicators(),
          ),
      ],
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.children.length,
        (index) => GestureDetector(
          onTap: () => _goToPage(index),
          child: Container(
            width: _currentIndex == index
                ? widget.indicatorSize
                : widget.indicatorSize * 0.8,
            height: _currentIndex == index
                ? widget.indicatorSize
                : widget.indicatorSize * 0.8,
            margin:
                EdgeInsets.symmetric(horizontal: widget.indicatorSpacing / 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == index
                  ? widget.activeIndicatorColor
                  : widget.inactiveIndicatorColor,
            ),
          ),
        ),
      ),
    );
  }
}
