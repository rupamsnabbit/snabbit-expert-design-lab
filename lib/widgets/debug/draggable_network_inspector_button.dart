import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Debug-only, app-level draggable launcher for the Chucker network inspector.
///
/// Wraps the whole app via [MaterialApp.builder] so it floats above every
/// screen and survives navigation. Drag it anywhere; tap it to open the
/// inspector. Inserted only in debug builds — see [DebugNetworkInspector.wrap],
/// which returns the bare child (and lets this widget tree-shake away) in
/// profile/release.
///
/// NOTE: [child] (the app's [Navigator]) is placed directly inside a [Stack],
/// NOT inside a `LayoutBuilder` — wrapping the navigator in a `LayoutBuilder`
/// re-scopes its build and breaks `GlobalKey.currentState` resolution, which
/// Chucker relies on to open its screen. Bounds come from [MediaQuery] instead.
class DraggableNetworkInspectorButton extends StatefulWidget {
  const DraggableNetworkInspectorButton({super.key, required this.child});

  /// The app content (the [MaterialApp] navigator) this overlay sits above.
  final Widget child;

  @override
  State<DraggableNetworkInspectorButton> createState() =>
      _DraggableNetworkInspectorButtonState();
}

class _DraggableNetworkInspectorButtonState
    extends State<DraggableNetworkInspectorButton> {
  /// Diameter of the floating button.
  static const double _size = 48;

  /// Inset used for the default resting position and edge clamping.
  static const double _margin = 12;

  /// Current top-left of the button. Null until first build, when it defaults
  /// to the right edge, ~70% down the screen.
  Offset? _position;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxX = (size.width - _size).clamp(0.0, double.infinity);
    final maxY = (size.height - _size).clamp(0.0, double.infinity);

    final resting = _position ?? Offset(maxX - _margin, maxY * 0.7);
    final pos = Offset(
      resting.dx.clamp(0.0, maxX),
      resting.dy.clamp(0.0, maxY),
    );

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  (pos.dx + details.delta.dx).clamp(0.0, maxX),
                  (pos.dy + details.delta.dy).clamp(0.0, maxY),
                );
              });
            },
            onPanEnd: (_) => setState(() => _dragging = false),
            onTap: DebugNetworkInspector.instance.showInspector,
            child: _ButtonVisual(dragging: _dragging, size: _size),
          ),
        ),
      ],
    );
  }
}

class _ButtonVisual extends StatelessWidget {
  const _ButtonVisual({required this.dragging, required this.size});

  final bool dragging;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      shape: const CircleBorder(),
      elevation: dragging ? 12 : 6,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.network_check, color: AppColors.n0, size: size * 0.5),
      ),
    );
  }
}
