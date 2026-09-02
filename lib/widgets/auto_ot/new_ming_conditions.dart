import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Banner widget that explains how to earn the new MinG.
///
/// This stateless widget renders a pill-shaped card with a title and three
/// illustrated conditions:
/// - Log in on time
/// - Log out on time
/// - Do not deny jobs
///
/// It uses [RemoteImageHandler] with URLs from [RemoteConfigAssets] so that
/// the icons can be updated remotely, and obtains all display strings from
/// [LanguageProvider] for localization. The layout and styling are based on
/// the Figma design shared for the Auto-OT flow, while remaining responsive
/// via `flutter_screenutil`.
class NewMinGConditions extends StatelessWidget {
  /// Creates a NewMinGConditions banner.
  ///
  /// The widget assumes that [ScreenUtil] has been initialized and that a
  /// [LanguageProvider] is available higher in the widget tree.
  const NewMinGConditions({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        // Localized strings with English defaults matching the Figma copy.
        final title = languageProvider.getMessage(
          'auto_ot_new_ming_conditions_title',
          'Do good shift to earn New MinG',
        );
        final loginOnTimeLabel = languageProvider.getMessage(
          'auto_ot_login_on_time',
          'Log in on time',
        );
        final logoutOnTimeLabel = languageProvider.getMessage(
          'auto_ot_logout_on_time',
          'Log out on time',
        );
        final doNotDenyJobsLabel = languageProvider.getMessage(
          'auto_ot_do_not_deny_jobs',
          'Do not deny jobs',
        );

        return Container(
          width: 1.sw,
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: 12.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.n10,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.n20,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 12 / 12,
                          letterSpacing: -0.24,
                        ),
                  ),
                ),
                SizedBox(height: 16.h),
                // Conditions row
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _NewMinGConditionItem(
                          imageUrl: RemoteConfigAssets.loginOnTime,
                          label: loginOnTimeLabel,
                        ),
                      ),
                      SizedBox(width: 40.w),
                      Flexible(
                        child: _NewMinGConditionItem(
                          imageUrl: RemoteConfigAssets.logOutOnTime,
                          label: logoutOnTimeLabel,
                        ),
                      ),
                      SizedBox(width: 40.w),
                      Flexible(
                        child: _NewMinGConditionItem(
                          imageUrl: RemoteConfigAssets.doNotDenyJobs,
                          label: doNotDenyJobsLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Internal widget that renders a single condition (icon + label).
///
/// The icon is shown inside a circular green background that matches the
/// Figma ellipse, and the label is centered underneath. The widget uses
/// [Flexible] and `FittedBox` to avoid text overflow on smaller screens
/// while preserving the intended layout.
class _NewMinGConditionItem extends StatelessWidget {
  /// Remote image URL for the condition icon.
  final String imageUrl;

  /// Localized label shown below the icon.
  final String label;

  const _NewMinGConditionItem({
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          decoration: const BoxDecoration(
            color: AppColors.g10,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: RemoteImageHandler(
              imageUrl: imageUrl,
              height: 24.r,
              width: 24.r,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 6.h),
        SizedBox(
          width: 84.w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 10 / 10,
                    color: AppColors.n80,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
