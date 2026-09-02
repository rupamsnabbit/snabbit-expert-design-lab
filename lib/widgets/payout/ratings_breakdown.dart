import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/providers/payout.dart';

import '../../utils/colors.dart';
import 'custom_progress_bar.dart';

class RatingsBreakdown extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final List<RatingBreakdown>? ratings;

  const RatingsBreakdown({
    required this.averageRating,
    required this.totalReviews,
    this.ratings,
    super.key,
  });

  double _calculatePercentage(int count) {
    if (totalReviews == 0) return 0.0;
    return count / totalReviews;
  }

  Widget _buildRatingRow(BuildContext context, int? star, int count) {
    return Row(
      children: [
        // Star Icon
        Icon(Icons.star_rounded, size: 20.sp),
        SizedBox(width: 4.w),
        Text(
          star.toString(),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(width: 4.w),

        // Progress Bar
        Expanded(
          flex: 92,
          child: CustomProgressBar(
            progress: _calculatePercentage(count),
            color: const Color(0xff05939E),
            addMileStoneLock: false,
            addEndCircle: false,
            lockPosition: 0,
          ),
        ),
        // const SizedBox(width: 8),

        // Count Text
        SizedBox(width: 13.w),
        Expanded(
          flex: 8,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count.toString(),
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.n60),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ratings Breakdown Header
        Text(
          "Ratings breakdown",
          style: Theme.of(context).textTheme.displayMedium,
        ),
        SizedBox(height: 14.h),

        // Average Rating and Total Reviews
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "$averageRating",
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const WidgetSpan(
                child: Icon(
                  Icons.star_rounded,
                  color: Color(0xff40515B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        Center(
          child: Text(
            "$totalReviews ratings",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.n80),
          ),
        ),
        SizedBox(height: 21.h),

        // Ratings Rows
        if (ratings != null)
          ...ratings!.map((e) {
            return _buildRatingRow(context, e.rating, e.count ?? 0);
          }),
        // for (int star = 5; star >= 1; star--)
        //   _buildRatingRow(context, star, ratings[star] ?? 0),
      ],
    );
  }
}
