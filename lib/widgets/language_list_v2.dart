import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart' show Provider;

import '../providers/language_provider.dart' show LanguageProvider;
import '../providers/preferred_language_provider.dart'
    show LanguageData, PreferredLanguageProvider;
import '../providers/user_profile.dart' show UserProfileProvider;
import '../services/analytics/onboarding_analytics.dart';
import '../utils/colors.dart';
import '../utils/tracking_events.dart';

class LanguageListV2 extends StatefulWidget {
  const LanguageListV2({super.key});

  @override
  State<LanguageListV2> createState() => _LanguageListV2State();
}

class _LanguageListV2State extends State<LanguageListV2> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late PreferredLanguageProvider preferredLanguageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      // Fetch languages when the widget initializes
      preferredLanguageProvider =
          Provider.of<PreferredLanguageProvider>(context, listen: true);
      Future.microtask(() async {
        await preferredLanguageProvider.loadLanguages();
        if (!mounted) return;
        OnboardingAnalytics.logEvent(
            TrackingEvents.languageSelectionScreenLoad, {
          'language_list_count': preferredLanguageProvider.languages.length,
          'default_selection': userProfileProvider.user?.languagePreference,
        });
      });
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      child: (preferredLanguageProvider.isLoading)
          ? const Center(child: CupertinoActivityIndicator())
          : (preferredLanguageProvider.languages.isEmpty)
              ? const Center(child: Text("No languages available"))
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  separatorBuilder: (context, index) {
                    return SizedBox(height: 16.h);
                  },
                  itemCount: preferredLanguageProvider.languages.length,
                  itemBuilder: (context, index) {
                    LanguageData currentLanguage =
                        preferredLanguageProvider.languages[index];
                    bool isSelected =
                        userProfileProvider.user?.languagePreference ==
                            currentLanguage.obj;
                    final Color borderColor =
                        isSelected ? AppColors.brand : AppColors.n40;
                    final double borderWidth = isSelected ? 2.0 : 1.0;
                    return GestureDetector(
                      onTap: () {
                        userProfileProvider.languagePreference =
                            currentLanguage.obj;
                        OnboardingAnalytics.registerSuperProperties(
                            {'selected_language': currentLanguage.obj});
                        OnboardingAnalytics.logEvent(
                            TrackingEvents.languageSelected, {
                          'selected_language': currentLanguage.obj,
                        });
                      },
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.symmetric(
                                    vertical: 24.h, horizontal: 20.w)
                                .subtract(EdgeInsets.all(isSelected ? 0.5 : 0)),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: borderColor,
                                width: borderWidth,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  currentLanguage.nameNative,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                Container(
                                  width: 24.r,
                                  height: 24.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppColors.brand
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: borderColor,
                                      width: 2.r,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          color: AppColors.n0,
                                          size: 14.r,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(right: 75.w, top: 6.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                RichText(
                                  textAlign: TextAlign.end,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: currentLanguage.iconText1,
                                        style: TextStyle(
                                          fontSize: 58.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.n50.withAlpha(77),
                                        ),
                                      ),
                                      TextSpan(
                                        text: currentLanguage.iconText2,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 42.sp,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppColors.n50.withAlpha(77),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
