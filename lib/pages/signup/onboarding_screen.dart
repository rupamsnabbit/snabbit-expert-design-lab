import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/onboarding_module.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/go_live/training_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/preferred_language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import '../../widgets/registration_flow/onboarding_step.dart';

class OnboardingScreen extends StatefulWidget {
  static const String routeName = "/onboarding-screen";

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late PreferredLanguageProvider preferredLanguageProvider;

  ModuleGroupResponse? get modulesData =>
      onboardingStepsProvider.onboardingModules;

  String? get titleTextData => modulesData?.currentModuleUiConfig.title;

  String? get subtitleTextData => modulesData?.currentModuleUiConfig.subtitle;

  String? get imageUrl => modulesData?.currentModuleUiConfig.imageUrl;

  String? get languageIconUrl =>
      modulesData?.currentModuleUiConfig.languageIcon;

  List<Module>? get modules =>
      onboardingStepsProvider.onboardingModules?.modules;

  bool get enableGoLive =>
      onboardingStepsProvider.onboardingModules?.enableGoLive == true;

  final GlobalKey _iconKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      preferredLanguageProvider =
          Provider.of<PreferredLanguageProvider>(context, listen: true);
      Future.microtask(
        () async {
          preferredLanguageProvider.loadLanguages();
          await onboardingStepsProvider.setupOnboardingScreen();
          if (!mounted) return;
          _fireRegistrationDashboardScreenLoad();
        },
      );
    }
    super.didChangeDependencies();
  }

  /// Modules the user can currently tap on — buttons are rendered only for
  /// stepStatus == created OR inProgress. Pending = disabled button,
  /// completed = no button (plain text).
  List<String> _clickableModuleKeys() {
    final list = modules;
    if (list == null) return [];
    return list
        .where((m) =>
            m.stepStatus == StepStatus.created ||
            m.stepStatus == StepStatus.inProgress)
        .map((m) => m.moduleKey)
        .toList();
  }

  String? _activeModuleKey() {
    final list = modules;
    if (list == null) return null;
    for (final m in list) {
      if (m.stepStatus == StepStatus.inProgress) return m.moduleKey;
    }
    for (final m in list) {
      if (m.stepStatus == StepStatus.created) return m.moduleKey;
    }
    return null;
  }

  void _fireRegistrationDashboardScreenLoad() {
    OnboardingAnalytics.logEvent(
        TrackingEvents.registrationDashboardScreenLoad, {
      'total_steps': modulesData?.totalModules ?? modules?.length ?? 0,
      'steps_visible': _clickableModuleKeys(),
      'completed_steps_count': modulesData?.completedCount ?? 0,
    });
  }

  /// Handles the "Go live" button. With the go-live webview flag
  /// ([RemoteConfigKeys.isGoLiveV3Enabled]) on, opens the date-selection step
  /// in the webview; otherwise keeps the existing native flow
  /// ([TrainingDetails]). The flag defaults to false, so a missing/unavailable
  /// Remote Config value preserves the native flow (backward compatible).
  void _onGoLivePressed() {
    final goLiveWebViewEnabled = RemoteConfigService.instance.getBool(
      RemoteConfigKeys.isGoLiveV3Enabled,
      defaultValue: false,
    );
    if (goLiveWebViewEnabled) {
      Navigator.of(context).pushNamed(
        AppWebViewPage.routeName,
        arguments: WebViewArgs(
          url: buildWebviewUrl(WebviewRoutes.goLiveSelectDate),
          title: languageProvider.getMessage('go_live', 'Go live'),
          fetchLocation: true,
        ),
      );
    } else {
      Navigator.of(context).pushNamed(TrainingDetails.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = init || onboardingStepsProvider.loading;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.n0,
        appBar: AppBar(
          title: Text(
            languageProvider.getMessage(
                titleTextData ?? '', titleTextData ?? ''),
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontSize: 16.sp, color: AppColors.n90),
          ),
          centerTitle: true,
          elevation: 6,
          actions: isLoading
              ? null
              : [
                  Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: GestureDetector(
                      key: _iconKey,
                      behavior: HitTestBehavior.translucent,
                      onTap: _showOverlayDialog,
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        color: Colors.transparent,
                        child: RemoteImageHandler(
                          imageUrl: languageIconUrl?.cdn ?? '',
                          width: 16.w,
                        ),
                      ),
                    ),
                  )
                ],
        ),
        persistentFooterButtons: [
          SizedBox(
            width: 1.sw,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: ElevatedButton(
                onPressed: enableGoLive ? _onGoLivePressed : null,
                child: Text(
                  enableGoLive
                      ? languageProvider.getMessage(
                          'go_live',
                          'Go live',
                        )
                      : languageProvider.getMessage(
                          'complete_training_to_go_live',
                          'Complete training to go live',
                        ),
                ),
              ),
            ),
          ),
        ],
        body: init || onboardingStepsProvider.loading
            ? Center(
                child: CupertinoActivityIndicator(),
              )
            : onboardingStepsProvider.onboardingScreenErrorResponse != null
                ? Center(
                    child: Text(
                        'Error: ${onboardingStepsProvider.onboardingScreenErrorResponse?.statusCode}'),
                  )
                : SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            RemoteImageHandler(
                              imageUrl: imageUrl?.cdn ?? '',
                              height: 140.h,
                              errorWidget: SizedBox(),
                            ),
                            SizedBox(height: 7.h),
                            Padding(
                              padding: EdgeInsets.only(bottom: 16.h),
                              child: Text(
                                languageProvider.getMessage(
                                    subtitleTextData ?? '',
                                    subtitleTextData ?? ''),
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      fontSize: 17.sp,
                                      color: AppColors.n90,
                                    ),
                              ),
                            ),
                            if (modules != null)
                              ListView.builder(
                                itemCount: modules?.length,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemBuilder: (listviewContext, index) =>
                                    OnboardingStep(
                                  data: modules![index],
                                  stepNumber: index + 1,
                                  onCtaTap: () async {
                                    OnboardingAnalytics.logEvent(
                                        TrackingEvents
                                            .registrationDashboardScreenCtaClick,
                                        {
                                          'active_step': _activeModuleKey(),
                                          'completed_steps_count':
                                              modulesData?.completedCount ?? 0,
                                          'selected_step':
                                              modules![index].moduleKey,
                                        });
                                    if (modules?[index].moduleKey ==
                                        RunnerRegistrationStep
                                            .earlyRegistrationModuleKey) {
                                      await RegistrationNavigation
                                          .openEarlyRegistrationWebView(
                                        context,
                                        moduleId: modules![index].id,
                                      );
                                      return;
                                    }
                                    if (modules?[index].moduleKey ==
                                        "bank_details") {
                                      // For bank_details, call getInitialQuestion first to get session_id
                                      await onboardingStepsProvider
                                          .getInitialQuestion(
                                              context: context,
                                              moduleId: modules![index].id);

                                      // Check if we have a session_id from the question response
                                      if (onboardingStepsProvider
                                              .onboardingQuestionResponse
                                              ?.sessionId !=
                                          null) {
                                        if (mounted) {
                                          Navigator.pushNamed(
                                              context,
                                              AddBankOrUpiDetailsScreen
                                                  .routeName);
                                        }
                                      } else if (onboardingStepsProvider
                                              .onboardingQAError !=
                                          null) {
                                        // Show error message if there's a custom error
                                        if (mounted) {
                                          showSnackbar(
                                              context,
                                              onboardingStepsProvider
                                                      .onboardingQAError
                                                      ?.message ??
                                                  "An error occurred");
                                        }
                                      }
                                      return;
                                    } else {
                                      final route =
                                          await onboardingStepsProvider
                                              .getInitialQuestion(
                                                  context: context,
                                                  moduleId: modules![index].id);
                                      if (mounted &&
                                          context.mounted &&
                                          route != null) {
                                        Navigator.of(context).pushNamed(route);
                                      }
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  void updateLanguage(String language) async {
    _removeOverlay();
    onboardingStepsProvider.loading = true;
    onboardingStepsProvider.notifyUserListeners();

    await languageProvider.fetchMessages(language);
    if (languageProvider.error != null) {
      if (context.mounted) {
        showSnackbar(
          context,
          "Saving language failed!",
        );
      }
    } else {
      if (context.mounted) {
        userProfileProvider.user?.languagePreference = language;
        await userProfileProvider.runnerRegistrationAndErrorHandler(
          context: context,
          onSuccess: () {},
          onError: (errorMessage) {
            showSnackbar(context, errorMessage ?? "Something went wrong");
          },
          navigateNext: false,
          isFirstRoute: true,
        );

        await onboardingStepsProvider.setupOnboardingScreen();
      }
    }

    onboardingStepsProvider.loading = false;
    onboardingStepsProvider.notifyUserListeners();
  }

  void _showOverlayDialog() {
    _removeOverlay();

    final renderBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Dims background
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeOverlay,
                child: Container(
                  color: Colors.black.withAlpha(102),
                ),
              ),
            ),

            // Popup container positioned below the icon
            Positioned(
              top: position.dy + size.height + 8,
              right: MediaQuery.of(context).size.width -
                  (position.dx + size.width),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220.w,
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Change Language",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      SizedBox(height: 20.h),
                      Divider(height: 0, color: AppColors.n40),
                      ...preferredLanguageProvider.languages
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final language = entry.value;

                        bool isSelected =
                            userProfileProvider.user?.languagePreference ==
                                language.obj;
                        final Color borderColor =
                            isSelected ? AppColors.brand : AppColors.n40;

                        return InkWell(
                          onTap: () {
                            updateLanguage(language.obj);
                          },
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: (index ==
                                            preferredLanguageProvider
                                                    .languages.length -
                                                1)
                                        ? EdgeInsets.only(top: 20.h)
                                        : EdgeInsets.symmetric(vertical: 20.h),
                                    child: Text(
                                      language.nameNative,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: const Color(0xFF111A2C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Padding(
                                    padding: (index ==
                                            preferredLanguageProvider
                                                    .languages.length -
                                                1)
                                        ? EdgeInsets.only(top: 12.h)
                                        : EdgeInsets.zero,
                                    child: Container(
                                      width: 24.r,
                                      height: 24.r,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.brand
                                            : Colors.transparent,
                                        border: Border.all(
                                            color: borderColor, width: 2.r),
                                      ),
                                      child: isSelected
                                          ? Icon(Icons.check,
                                              color: AppColors.n0, size: 14.r)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (index !=
                                  preferredLanguageProvider.languages.length -
                                      1)
                                Divider(height: 0, color: AppColors.n40),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
