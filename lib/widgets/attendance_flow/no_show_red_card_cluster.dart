import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Red card cluster for no-show attendance (current state).
///
/// CDN asset matches [PostActionPopup]; artwork includes any printed penalty amount.
///
/// Layout: centered **pyramid** — top row has [n ~/ 2] cards, bottom row the rest
/// (e.g. 5 → 2 on top, 3 below). Cards in each row **overlap** horizontally
/// ([_CardRow._rowStepFactor]) so the cluster matches design; tune that constant
/// to adjust tightness. One row only for 1–2 cards.
class NoShowRedCardCluster extends StatelessWidget {
  const NoShowRedCardCluster({super.key, required this.count});

  final int count;

  static const String _redCardUrl =
      'https://assets-expert.snabbit.com/payouts/nudges/red_card_display.png';

  static const Color _red700 = Color(0xFFB91C1C);

  static double _sizeForCount(int n) {
    if (n <= 1) return 120.sp;
    if (n <= 2) return 100.sp;
    if (n <= 4) return 85.sp;
    if (n <= 6) return 75.sp;
    return 65.sp;
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = count.abs().clamp(1, 9);
    final assetSize = _sizeForCount(displayCount);

    if (displayCount <= 2) {
      return _CardRow(cardCount: displayCount, assetSize: assetSize);
    }

    final top = displayCount ~/ 2;
    final bottom = displayCount - top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardRow(cardCount: top, assetSize: assetSize),
        SizedBox(height: 6.h),
        _CardRow(cardCount: bottom, assetSize: assetSize),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.cardCount,
    required this.assetSize,
  });

  final int cardCount;
  final double assetSize;

  /// How far each card is stepped from the previous one, as a fraction of
  /// [assetSize]. Lower = more overlap = tighter row (less horizontal gap).
  /// e.g. `0.72` ≈ 28% overlap; `0.85` ≈ 15% overlap; `1.0` = edges touch.
  static const double _rowStepFactor = 0.72;

  @override
  Widget build(BuildContext context) {
    if (cardCount <= 1) {
      return Center(child: _RedCardCell(assetSize: assetSize));
    }

    final step = assetSize * _rowStepFactor;
    final totalWidth = assetSize + (cardCount - 1) * step;

    return Center(
      child: SizedBox(
        width: totalWidth,
        height: assetSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cardCount; i++)
              Positioned(
                left: i * step,
                child: _RedCardCell(assetSize: assetSize),
              ),
          ],
        ),
      ),
    );
  }
}

class _RedCardCell extends StatelessWidget {
  const _RedCardCell({required this.assetSize});

  final double assetSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: assetSize,
      height: assetSize,
      child: CachedNetworkImage(
        imageUrl: NoShowRedCardCluster._redCardUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(
          width: assetSize,
          height: assetSize,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.confirmation_number_rounded,
          size: assetSize,
          color: NoShowRedCardCluster._red700,
        ),
      ),
    );
  }
}
