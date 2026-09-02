import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/single_or_multiple_option_selector.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/yes_or_no_question.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class OnboardingSingleQuestionScreen extends StatefulWidget {
  static const String routeName = "/onboarding_single_question_screen";

  const OnboardingSingleQuestionScreen({
    super.key,
  });

  @override
  State<OnboardingSingleQuestionScreen> createState() =>
      _OnboardingSingleQuestionScreenState();
}

class _OnboardingSingleQuestionScreenState
    extends State<OnboardingSingleQuestionScreen> {
  // For both Yes or No and MCQ questions. For single option answers the list
  // will contain just one option
  final List<OnboardingQuestionOption> _selectedOptions = [];
  late final SingleQuestionUiConfig? uiConfig;
  bool _isPlayingVoiceover = false;
  bool _isPlayingHardRejectAudio = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool init = true;
  late OnboardingStepsProvider onboardingStepsProvider;

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionData? get currentQuestion =>
      onboardingQuestionResponse?.questions?.first;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  String? get audioUrl => uiConfig?.audioUrl;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);

      final previousResponses = currentQuestion?.previousResponse ?? [];
      final allOptions = currentQuestion?.optionObjects ?? [];
      if (currentQuestion?.uiConfig != null) {
        uiConfig = SingleQuestionUiConfig.fromJson(currentQuestion?.uiConfig);
      }
      if (previousResponses.isNotEmpty && allOptions.isNotEmpty) {
        final previousOptionIds = previousResponses
            .where((r) => r.optionId != null)
            .map((r) => r.optionId!)
            .toSet();

        final matchedOptions = allOptions
            .where((option) => previousOptionIds.contains(option.id))
            .toList();

        if (matchedOptions.isNotEmpty) {
          _selectedOptions
            ..clear()
            ..addAll(matchedOptions);
        }
      }
    }
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = GlobalState()
        .audioPlayer
        .onPlayerStateChanged
        .listen((PlayerState state) {
      final bool isPlaying = state == PlayerState.playing;
      if (mounted) {
        setState(() {
          final currentSource = GlobalState().audioPlayer.source;
          if (currentSource is UrlSource &&
              uiConfig?.hardRejectAudio != null &&
              currentSource.url == uiConfig!.hardRejectAudio) {
            _isPlayingHardRejectAudio = isPlaying;
          } else {
            _isPlayingVoiceover = isPlaying;
            _isPlayingHardRejectAudio = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> playSound({String? customAudioUrl}) async {
    try {
      if (GlobalState().audioPlayer.state != PlayerState.playing) {
        setMaxVolume();
        await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.release);
        final urlToPlay = customAudioUrl ?? audioUrl;
        if (urlToPlay != null && urlToPlay.isNotEmpty) {
          await GlobalState()
              .audioPlayer
              .play(UrlSource(urlToPlay), volume: desiredVolume);
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Color get bgColor => AppColors.n0;

  AppBar get appbar => AppBar(
        leading: InkWell(
          onTap: () async {
            await stopAudio();
            onboardingStepsProvider.goBackToPreviousQuestion(
                context, onboardingQuestionResponse!.moduleId!);
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
      );

  Widget get floatingActionButton {
    if (audioUrl == null || audioUrl?.trim().isEmpty == true) {
      return SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(right: 4.w),
      child: IconButton(
        onPressed: () async {
          if (_isPlayingVoiceover) {
            await stopAudio();
          } else {
            await playSound();
          }
        },
        padding: EdgeInsets.zero,
        icon: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 60.w,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RemoteImageHandler(
              imageUrl: _isPlayingVoiceover
                  ? uiConfig?.audioNormalIcon ??
                      "onboarding/active_speaker.svg".cdn
                  : uiConfig?.audioMuteIcon ??
                      "onboarding/muted_speaker.svg".cdn,
              fit: BoxFit.scaleDown,
              width: 60.r,
              errorWidget: Container(
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  border: Border.all(color: AppColors.brand, width: 2.r),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlayingVoiceover
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 24.r,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get isLoading => init || onboardingStepsProvider.loading;

  Widget get header => Column(
        children: [
          SizedBox(height: 6.h),
          OnboardingProgressBar(progressValue: _progressValue),
          SizedBox(height: 33.h),
          _buildQuestionText(currentQuestion?.question ?? ''),
        ],
      );

  void _showNoConfirmationDialog() {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: 19.w,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            backgroundColor: Color(0xffF9DADA),
            child: StatefulBuilder(
              builder: (dialogContext, setState) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 12.w,
                    top: 5.h,
                    right: 5.w,
                    bottom: 16.h,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        // To keep the button right aligned
                        right: 0.w,
                        child: IconButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            padding: EdgeInsets.zero,
                            icon: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 50.w,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: RemoteImageHandler(
                                  imageUrl:
                                      "onboarding/hard_reject_close.png".cdn,
                                  fit: BoxFit.scaleDown,
                                  width: 32.r,
                                  errorWidget: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: Color(0xffFDF4F4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 16.r,
                                      color: Color(0xffEE9191),
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 50,
                          ),
                          Stack(
                            children: [
                              RemoteImageHandler(
                                imageUrl: "onboarding/hard_reject.png".cdn,
                                fit: BoxFit.scaleDown,
                                width: 1.sw,
                                errorWidget: SizedBox(height: 50.h),
                              ),
                              if (uiConfig?.hardRejectAudio != null &&
                                  uiConfig!.hardRejectAudio!.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: IconButton(
                                    onPressed: () async {
                                      if (_isPlayingHardRejectAudio) {
                                        await stopAudio();
                                        setState(() {
                                          _isPlayingHardRejectAudio = false;
                                        });
                                      } else {
                                        await playSound(
                                            customAudioUrl:
                                                uiConfig?.hardRejectAudio);
                                        setState(() {
                                          _isPlayingHardRejectAudio = true;
                                        });
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    icon: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: 60.w,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: RemoteImageHandler(
                                          imageUrl: _isPlayingHardRejectAudio
                                              ? uiConfig?.audioNormalIcon ??
                                                  "onboarding/active_speaker.svg"
                                                      .cdn
                                              : uiConfig?.audioMuteIcon ??
                                                  "onboarding/muted_speaker.svg"
                                                      .cdn,
                                          fit: BoxFit.scaleDown,
                                          width: 34.r,
                                          errorWidget: Container(
                                            padding: EdgeInsets.all(18.r),
                                            decoration: BoxDecoration(
                                              color: Color(0xffF9DADA),
                                              border: Border.all(
                                                  color: AppColors.brand,
                                                  width: 2.r),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isPlayingHardRejectAudio
                                                  ? Icons.volume_up_rounded
                                                  : Icons.volume_off_rounded,
                                              size: 24.r,
                                              color: AppColors.brand,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (uiConfig?.hardRejectText != null) ...[
                            SizedBox(height: 12.h),
                            Text(
                              uiConfig?.hardRejectText ?? '',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontSize: 16.sp,
                                    color: AppColors.r50,
                                  ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (_) {}
  }

  void _nextQuestion() {
    stopAudio();
    final payload = buildAnswerRequest(
      sessionId: onboardingQuestionResponse!.sessionId!,
      questions: [currentQuestion!],
      selectedOptionsMap: {
        currentQuestion!.id!: _selectedOptions,
      },
    );
    onboardingStepsProvider.submitAnswerAndProceed(
      context: context,
      data: payload,
      onSuccess: () {
        setState(() {
          _selectedOptions.clear();
        });
      },
      onError: (CustomError error) {
        showSnackbar(
            context, error.message ?? error.title ?? 'Something went wrong');
      },
    );
  }

  Widget _buildQuestionText(String question) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Text(
        question,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  void _handleYesNoSelection({required int index}) {
    _selectedOptions.clear();

    if ((currentQuestion?.isHardReject ?? false) &&
        (currentQuestion?.optionObjects?[index].isHardReject ?? false)) {
      _showNoConfirmationDialog();
      return;
    }

    final OnboardingQuestionOption? option =
        currentQuestion?.optionObjects?[index];

    if (option != null) _selectedOptions.add(option);
    _nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    switch (currentQuestion?.questionType) {
      case OnboardingQuestionType.yesOrNo:
        return YesOrNoQuestion(
          floatingActionButton: floatingActionButton,
          appBar: appbar,
          backgroundColor: bgColor,
          questionData: currentQuestion!,
          questionHeader: header,
          onOptionTapped: (val) {
            _handleYesNoSelection(index: val);
          },
          isLoading: isLoading,
        );
      case OnboardingQuestionType.singleSelect:
      case OnboardingQuestionType.multiSelect:
        return SingleOrMultipleOptionSelector(
          floatingActionButton: floatingActionButton,
          appBar: appbar,
          backgroundColor: bgColor,
          questionData: currentQuestion!,
          selectedOptions: _selectedOptions,
          onChanged: (List<OnboardingQuestionOption>? options) {
            setState(() {
              _selectedOptions
                ..clear()
                ..addAll(options ?? []);
            });
          },
          questionHeader: header,
          onSubmit: _nextQuestion,
          isLoading: isLoading,
        );
      default:
        return SizedBox.shrink();
    }
  }
}

class SingleQuestionUiConfig {
  final String? hardRejectImage;
  final String? hardRejectText;
  final String? hardRejectAudio;

  final String? audioMuteIcon;
  final String? audioNormalIcon;
  final String? audioUrl;

  final bool? isRequired;
  final String? placeholder;
  final String? questionKey;

  final String? ctaText;
  final String? ctaIcon;
  final Color? ctaColor;
  final Color? textColor;
  final String? imageUrl;

  const SingleQuestionUiConfig(
      {this.hardRejectImage,
      this.hardRejectText,
      this.audioMuteIcon,
      this.audioNormalIcon,
      this.audioUrl,
      this.isRequired,
      this.placeholder,
      this.questionKey,
      this.ctaText,
      this.ctaIcon,
      this.ctaColor,
      this.textColor,
      this.imageUrl,
      this.hardRejectAudio});

  factory SingleQuestionUiConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SingleQuestionUiConfig();

    return SingleQuestionUiConfig(
      hardRejectImage: json['hard_reject_image'],
      hardRejectAudio: json['hard_reject_audio'],
      hardRejectText: json['hard_reject_text'],
      audioMuteIcon: json['audio_mute_icon'],
      audioNormalIcon: json['audio_normal_icon'],
      audioUrl: json['audio_url'],
      isRequired: json['is_required'],
      placeholder: json['placeholder'],
      questionKey: json['question_key'],
      ctaText: json['cta_text'],
      ctaIcon: json['cta_icon'],
      ctaColor: _parseColor(json['cta_color']),
      textColor: _parseColor(json['text_color']),
      imageUrl: json['image_url'],
    );
  }
}

Color? _parseColor(dynamic value) {
  if (value == null) return null;
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    return hexToColor(value);
  }
  return null;
}
