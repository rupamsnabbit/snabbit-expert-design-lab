import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/app_strings.dart';

import '../providers/language_provider.dart';
import '../providers/user_profile.dart';
import '../utils/colors.dart';
import '../utils/common_methods.dart';
import '../utils/enums.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/language_list.dart';

class LanguageHome extends StatefulWidget {
  static const String routeName = "/language-home";

  const LanguageHome({super.key});

  @override
  State<LanguageHome> createState() => _LanguageHomeState();
}

class _LanguageHomeState extends State<LanguageHome> {
  bool init = true;

  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  String? currentLanguage;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentLanguage = userProfileProvider.user?.languagePreference;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        if (currentLanguage != userProfileProvider.user?.languagePreference) {
          userProfileProvider.languagePreference = currentLanguage;
        }
      },
      child: Scaffold(
        appBar: const CommonAppBar(),
        persistentFooterButtons: [
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: !userProfileProvider.loading
                  ? () async {
                      userProfileProvider.loading = true;
                      userProfileProvider.notifyUserListeners();
                      await languageProvider.fetchMessages(
                          userProfileProvider.user?.languagePreference ??
                              AppStrings.defaultLanguage);
                      if (languageProvider.error != null) {
                        userProfileProvider.languagePreference =
                            currentLanguage;
                        if (context.mounted) {
                          showSnackbar(
                            context,
                            "Saving language failed!",
                          );
                        }
                      } else {
                        if (context.mounted) {
                          await userProfileProvider
                              .runnerRegistrationAndErrorHandler(
                            context: context,
                            onSuccess: () {
                              currentLanguage =
                                  userProfileProvider.user?.languagePreference;
                              Navigator.pop(context);
                            },
                            onError: (errorMessage) {
                              showSnackbar(context,
                                  errorMessage ?? "Something went wrong");
                            },
                            navigateNext: false,
                          );
                        }
                      }
                      userProfileProvider.loading = false;
                      userProfileProvider.notifyUserListeners();
                    }
                  : null,
              child: Text(
                languageProvider.getMessage(
                  'confirm',
                  'Confirm',
                ),
              ),
            ),
          ),
        ],
        body: userProfileProvider.loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        "choose_preferred_language",
                        "Choose preferred language",
                      ),
                    ),
                    SizedBox(height: 24.h),
                    const Expanded(
                      child: LanguageList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
