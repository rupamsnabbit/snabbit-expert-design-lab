import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:snabbit_runner/modules/snabbit_shield/shield_consent_provider.dart';
import 'package:snabbit_runner/modules/snabbit_shield/ui/shield_background_circles_painter.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

class ShieldConsentBottomSheet extends StatelessWidget {
  final Map<String, dynamic>? eventProps;

  const ShieldConsentBottomSheet({super.key, this.eventProps});

  /// Shows the consent bottom sheet. Returns true if consent was activated.
  static Future<bool> show(BuildContext context,
      {required ShieldConsentProvider consentProvider,
      Map<String, dynamic>? eventProps}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.n0,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: consentProvider,
        child: CommonBottomSheetSetup(
          horizontalPadding: 0,
          bottomPadding: 24,
          // Figma node 22879:8728 – gradient + 5.704px radius (scale-y flipped in dev)
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(52, 163, 252,
                  0), // transparent at top (Figma to 97.759% flipped)
              Color(0xFFFFFFFF), // white at bottom (Figma from 57.805% flipped)
            ],
            stops: [
              0.0,
              0.422
            ], // matches Figma from-[57.805%] to-[97.759%] after -scale-y-100
          ),
          child: ShieldConsentBottomSheet(eventProps: eventProps),
        ),
      ),
    );
    if (result != true) {
      MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentDismiss, {
        ...?eventProps,
      });
    }
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(top: 0.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 234.h,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Figma 22879:8766 – vector lines (427×107) at bottom
                  Positioned(
                    left: -17.w,
                    right: -17.w,
                    top: 20,
                    height: 107.h,
                    child: SvgPicture.asset(
                      'assets/svgs/shield_vector_lines_blue.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ShieldBackgroundCirclesPainter(),
                    ),
                  ),

                  // Figma 22879:8777 – shield icon (82.73×118) centered
                  Positioned(
                    top: 12,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 0.h),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          'assets/pngs/shield_icon_blue.png',
                          width: 190.w,
                          height: 190.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Figma 22929:11266 – "प्रस्तुत है" / Introducing: 13px, Bold, #101840, line-height 20
                  // Figma 22917:9250 – "Snabbit कवच": 32px, #016ee6, Snabbit=Medium, कवच=Extra Bold, line-height 38
                  Positioned(
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.getMessage(
                              'introducing_snabbit_shield', 'INTRODUCING'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.n70,
                            height: 20 / 13,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        _ShieldTitleText(
                          title: lang.getMessage(
                              'snabbit_shield_consent_title_v1', 'Snabbit कवच'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16.h),
                  _FeatureRow(
                    icon: Image.asset(
                      'assets/pngs/shield_protect_icon.png',
                      width: 48.r,
                      height: 48.r,
                      fit: BoxFit.contain,
                    ),
                    title: lang.getMessage(
                        'snabbit_shield_consent_protect_title',
                        'Stay Protected'),
                    subtitle: lang.getMessage(
                        'snabbit_shield_consent_protect_subtitle',
                        'Turn on Snabbit Kavach if you feel unsafe'),
                  ),
                  SizedBox(height: 20.h),
                  _FeatureRow(
                    icon: Image.asset(
                      'assets/pngs/shield_monitoring_icon.png',
                      width: 48.r,
                      height: 48.r,
                      fit: BoxFit.contain,
                    ),
                    title: lang.getMessage(
                        'snabbit_shield_consent_monitor_title',
                        'Smart Monitoring'),
                    subtitle: lang.getMessage(
                        'snabbit_shield_consent_monitor_subtitle',
                        'Audio & location will be used to protect you'),
                  ),
                  SizedBox(height: 20.h),
                  _FeatureRow(
                    icon: Image.asset(
                      'assets/pngs/shield_sos_icon.png',
                      width: 48.r,
                      height: 48.r,
                      fit: BoxFit.contain,
                    ),
                    title: lang.getMessage(
                        'snabbit_shield_consent_sos_title', 'SOS'),
                    subtitle: lang.getMessage(
                        'snabbit_shield_consent_sos_subtitle',
                        'Tap SOS anytime for immediate help'),
                  ),
                  SizedBox(height: 48.h),
                  _buildTncText(context),
                  SizedBox(height: 12.h),
                  _buildActivateButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTncText(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final tncLabel = lang.getMessage(
        'snabbit_shield_consent_tnc_link', 'Terms & Conditions');
    const key = 'snabbit_shield_consent_tnc';
    const defaultTemplate = 'By continuing, you accept the updated {{tnc}}';

    // Template WITHOUT interpolation (contains {{tnc}} if translator kept it)
    final template = lang.getMessage(key, defaultTemplate);
    // Final text WITH interpolation (what we actually show)
    final fullText = lang.getFormattedMessage(
      key,
      defaultTemplate,
      {'tnc': tncLabel},
    );

    int tncStart;
    String linkText;

    const placeholder = '{{tnc}}';
    final placeholderIndex = template.indexOf(placeholder);

    if (placeholderIndex != -1) {
      // Use the placeholder position from the template so underline works
      // consistently across all languages even if the substituted text
      // doesn't exactly match tncLabel.
      tncStart = placeholderIndex;
      linkText = tncLabel;
    } else {
      // Fallback: search for the label directly in the rendered string.
      final labelIndex = fullText.indexOf(tncLabel);
      if (labelIndex != -1) {
        tncStart = labelIndex;
        linkText = tncLabel;
      } else {
        // Last resort: make the entire text tappable without special styling.
        return GestureDetector(
          onTap: () => _openTnc(),
          child: Text(
            fullText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.n60,
                ),
          ),
        );
      }
    }

    final before = fullText.substring(0, tncStart);
    final after = fullText.substring(tncStart + tncLabel.length);

    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11.sp,
          color: AppColors.n70,
        );

    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _openTnc(),
        child: Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              if (before.isNotEmpty) TextSpan(text: before),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.n50,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    linkText,
                    style: baseStyle?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              if (after.isNotEmpty) TextSpan(text: after),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActivateButton(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return Consumer<ShieldConsentProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: provider.isLoading ? null : () => _onActivate(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.shieldBlue,
              foregroundColor: AppColors.n0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: provider.isLoading
                ? SizedBox(
                    height: 20.r,
                    width: 20.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.n0,
                    ),
                  )
                : Text(lang.getMessage(
                    'snabbit_shield_consent_activate', 'I Agree')),
          ),
        );
      },
    );
  }

  Future<void> _onActivate(BuildContext context) async {
    MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentCta, {
      ...?eventProps,
    });

    final consentProvider = context.read<ShieldConsentProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();

    final success = await consentProvider.activateConsent(userProfileProvider);

    if (!context.mounted) return;

    if (success) {
      MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentSuccess, {
        ...?eventProps,
      });
      Navigator.of(context).pop(true);
    } else {
      MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentError, {
        ...?eventProps,
        'error': 'api_failure',
      });
      final lang = context.read<LanguageProvider>();
      showSnackbar(
          context,
          lang.getMessage('snabbit_shield_consent_error_msg',
              'Could not activate. Please try again.'));
    }
  }

  void _openTnc() {
    launchUrl(
      Uri.parse(
          'https://snabbit-app-policies.s3.ap-south-1.amazonaws.com/Privacy_Policy_Expert_App.pdf'),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Figma 22917:9250 – "Snabbit " (Medium) + "कवच" (Extra Bold), 32px, #016ee6, line-height 38.
class _ShieldTitleText extends StatelessWidget {
  final String title;

  const _ShieldTitleText({required this.title});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF016EE6);
    final firstSpace = title.indexOf(' ');
    final firstPart =
        firstSpace >= 0 ? title.substring(0, firstSpace + 1) : title;
    final secondPart = firstSpace >= 0 ? title.substring(firstSpace + 1) : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: firstPart,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w500,
              color: color,
              height: 38 / 32,
            ),
          ),
          TextSpan(
            text: secondPart,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: color,
              height: 38 / 32,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Figma 22917:9264 – feature row with PNG icon, title and subtitle (separate lang keys).
class _FeatureRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.n90,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                      height: 1.3,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.n70,
                      fontSize: 13.sp,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
