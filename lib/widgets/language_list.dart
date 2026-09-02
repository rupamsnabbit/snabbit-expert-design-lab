import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart' show Provider;

import '../providers/language_provider.dart' show LanguageProvider;
import '../providers/preferred_language_provider.dart'
    show LanguageData, PreferredLanguageProvider;
import '../providers/user_profile.dart' show UserProfileProvider;
import '../utils/colors.dart';
import 'circular_checkbox.dart';

class LanguageList extends StatefulWidget {
  const LanguageList({super.key});

  @override
  State<LanguageList> createState() => _LanguageListState();
}

class _LanguageListState extends State<LanguageList> {
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
      Future.microtask(() => preferredLanguageProvider.loadLanguages());
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        2.w,
        24.h,
        20.w,
        24.h,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n50),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: LimitedBox(
        child: (preferredLanguageProvider.isLoading)
            ? const Center(child: CupertinoActivityIndicator())
            : (preferredLanguageProvider.languages.isEmpty)
                ? const Center(child: Text("No languages available"))
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    separatorBuilder: (context, index) {
                      return SizedBox(
                        height: 24,
                        child: Divider(
                          indent: 18.w,
                          color: const Color(0xFFE6E8F0),
                        ),
                      );
                    },
                    itemCount: preferredLanguageProvider.languages.length,
                    itemBuilder: (context, index) {
                      LanguageData currentLanguage =
                          preferredLanguageProvider.languages[index];
                      return ListTile(
                        onTap: () {
                          userProfileProvider.languagePreference =
                              currentLanguage.obj;
                        },
                        contentPadding: const EdgeInsets.all(0),
                        minLeadingWidth: 0,
                        leading: Container(
                          height: 90.r,
                          width: 90.r,
                          decoration: BoxDecoration(
                            color: AppColors.n30.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  currentLanguage.iconText1,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.n50,
                                  ),
                                ),
                                Text(
                                  currentLanguage.iconText2,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.n50,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        title: Text(
                          currentLanguage.nameNative,
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        horizontalTitleGap: 0,
                        subtitle: Text(
                          currentLanguage.name,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.n70,
                          ),
                        ),
                        trailing: CircularCheckbox(
                          value: userProfileProvider.user?.languagePreference ==
                              currentLanguage.obj,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
