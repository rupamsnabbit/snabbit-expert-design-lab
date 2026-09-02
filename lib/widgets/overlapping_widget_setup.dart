import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that allows widgets to overlap each other with configurable overlap amounts.
/// Automatically handles dynamic height changes.
///
/// This widget is perfect for creating card-based layouts where widgets need to
/// overlap each other, and the heights might change dynamically (e.g., loading images,
/// expanding content, etc.).
///
/// Features:
/// - Automatic height tracking for dynamic content (images, text, etc.)
/// - Configurable overlap amounts for top and bottom
/// - Works with any widget, including those with async content loading
///
/// Usage Examples:
///
/// 1. Simple top overlap (most common):
/// ```dart
/// OverlappingStackWidget(
///   topWidget: HeaderCard(),
///   mainWidget: ContentCard(),
///   topOverlap: 20.h,
/// )
/// ```
///
/// 2. Top and bottom overlap:
/// ```dart
/// OverlappingStackWidget(
///   topWidget: AddressWidget(...),
///   mainWidget: MapWidget(...),
///   bottomWidget: ServicesWidget(...),
///   topOverlap: 20.h,
///   bottomOverlap: 16.h,
/// )
/// ```
///
/// 3. Only bottom overlap:
/// ```dart
/// OverlappingStackWidget(
///   mainWidget: ProductCard(),
///   bottomWidget: ActionButtons(),
///   bottomOverlap: 12.h,
/// )
/// ```

class OverlappingStackWidget extends StatefulWidget {
  /// The widget that appears at the back (top layer in stack)
  final Widget? topWidget;

  /// The main widget that overlaps others
  final Widget mainWidget;

  /// The widget that appears at the front (bottom layer in stack)
  final Widget? bottomWidget;

  /// How much the main widget overlaps the top widget (positive value)
  final double topOverlap;

  /// How much the bottom widget overlaps the main widget (positive value)
  final double bottomOverlap;

  const OverlappingStackWidget({
    super.key,
    this.topWidget,
    required this.mainWidget,
    this.bottomWidget,
    this.topOverlap = 0,
    this.bottomOverlap = 0,
  });

  @override
  State<OverlappingStackWidget> createState() => _OverlappingStackWidgetState();
}

class _OverlappingStackWidgetState extends State<OverlappingStackWidget> {
  double topWidgetHeight = 0.0;
  double mainWidgetHeight = 0.0;

  Widget get bottomWidget {
    return mainWidgetHeight == 0
        ? SizedBox()
        : Padding(
      padding: EdgeInsets.only(
        top: topWidgetHeight +
            mainWidgetHeight -
            widget.topOverlap -
            widget.bottomOverlap,
      ),
      child: widget.bottomWidget!,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];

    // Add top widget if provided
    if (widget.topWidget != null) {
      stackChildren.add(
        MeasureSize(
          onChange: (size) {
            if (topWidgetHeight != size.height) {
              setState(() {
                topWidgetHeight = size.height;
              });
            }
          },
          child: widget.topWidget!,
        ),
      );
    }
// Add bottom widget with bottom overlap
    if (widget.bottomWidget != null) {
      stackChildren.add(bottomWidget);
    }
    // Add main widget with top overlap
    stackChildren.add(
      Padding(
        padding: EdgeInsets.only(
          top: widget.topWidget != null && topWidgetHeight > 0
              ? topWidgetHeight - widget.topOverlap
              : 0,
        ),
        child: MeasureSize(
          onChange: (size) {
            if (mainWidgetHeight != size.height) {
              setState(() {
                mainWidgetHeight = size.height;
              });
            }
          },
          child: widget.mainWidget,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: stackChildren,
    );
  }
}

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}

class MeasureSizeRenderObject extends RenderProxyBox {
  Size? oldSize;
  OnWidgetSizeChange onChange;

  MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();

    Size newSize = child!.size;
    if (oldSize == newSize) return;

    oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}
