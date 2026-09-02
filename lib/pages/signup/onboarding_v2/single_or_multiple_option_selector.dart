import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_single_question_screen.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/registration_flow/mcq_option.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class SingleOrMultipleOptionSelector extends StatefulWidget {
  final OnboardingQuestionData questionData;
  final Function(List<OnboardingQuestionOption>?) onChanged;
  final List<OnboardingQuestionOption>? selectedOptions;
  final Widget? floatingActionButton;
  final AppBar appBar;
  final Color backgroundColor;
  final Widget questionHeader;
  final VoidCallback onSubmit;
  final bool isLoading;

  const SingleOrMultipleOptionSelector({
    super.key,
    required this.questionData,
    required this.onChanged,
    this.selectedOptions,
    this.floatingActionButton,
    required this.appBar,
    required this.backgroundColor,
    required this.questionHeader,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<SingleOrMultipleOptionSelector> createState() =>
      _SingleOrMultipleOptionSelectorState();
}

class _SingleOrMultipleOptionSelectorState
    extends State<SingleOrMultipleOptionSelector> {
  late List<OnboardingQuestionOption> _selectedOptions;
  bool get isMultiSelect =>
      widget.questionData.questionType == OnboardingQuestionType.multiSelect;
  late final SingleQuestionUiConfig? uiConfig;

  @override
  void initState() {
    super.initState();
    _selectedOptions = List.from(widget.selectedOptions ?? []);
    if (widget.questionData.uiConfig != null) {
      uiConfig = SingleQuestionUiConfig.fromJson(widget.questionData.uiConfig);
    }
  }

  void _toggleSelection(OnboardingQuestionOption option) {
    setState(() {
      if (isMultiSelect) {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      } else {
        _selectedOptions = [option];
      }
    });
    widget.onChanged(_selectedOptions);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questionData;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar,
      floatingActionButton:
          widget.isLoading ? null : widget.floatingActionButton,
      persistentFooterButtons: widget.isLoading
          ? null
          : [
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 12.h),
                child: ElevatedButton(
                  onPressed: widget.onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    minimumSize:
                        Size.fromHeight(48.h), // Ensures button stretches
                  ),
                  child: Text(
                    'Confirm',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.n0,
                        ),
                  ),
                ),
              )
            ],
      body: widget.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  widget.questionHeader,
                  if (uiConfig?.imageUrl != null &&
                      uiConfig!.imageUrl!.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: 27.h, horizontal: 52.w),
                        child: RemoteImageHandler(
                          imageUrl: uiConfig?.imageUrl?.cdn ??'',
                          fit: BoxFit.cover,
                          width: 1.sw,
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
                    child: Column(
                      children: (question.optionObjects ?? []).map((option) {
                        final bool isSelected =
                            _selectedOptions.contains(option);
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: McqOption(
                            text: option.text ?? option.toString(),
                            isSelected: isSelected,
                            onTap: () => _toggleSelection(option),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 50.h),
                ],
              ),
            ),
    );
  }
}
