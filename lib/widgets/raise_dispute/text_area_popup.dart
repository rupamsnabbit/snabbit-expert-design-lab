import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_state.dart';
import 'package:snabbit_runner/pages/raise_dispute/issue_history.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/raise_dispute_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';

class TextAreaPopup extends StatefulWidget {
  final String title;
  final String hintText;
  final String submitButtonText;
  final bool review;

  const TextAreaPopup({
    Key? key,
    required this.title,
    required this.hintText,
    required this.submitButtonText,
    required this.review,
  }) : super(key: key);

  @override
  State<TextAreaPopup> createState() => _TextAreaPopupState();
}

class _TextAreaPopupState extends State<TextAreaPopup> {
  final TextEditingController _textEditingController = TextEditingController();
  bool _isSubmitButtonEnabled = false;
  bool loading = false;
  late LanguageProvider languageProvider;
  late BottomSheetViewProvider bottomSheetViewProvider;
  late int minLength;
  bool init = true;

  @override
  void initState() {
    super.initState();
    _textEditingController.addListener(_updateSubmitButtonState);
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_updateSubmitButtonState);
    _textEditingController.dispose();
    super.dispose();
  }

  // Updates the state of the submit button based on text field content.
  void _updateSubmitButtonState() {
    final text = _textEditingController.text.trim();
    setState(() {
      _isSubmitButtonEnabled = text.isNotEmpty && text.length >= minLength;
    });
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      bottomSheetViewProvider = Provider.of<BottomSheetViewProvider>(context, listen: true);
      if(widget.review){
        minLength = 0;
      } else {
        final issueConfigs = GlobalState().appConfig?.issueTypeConfigs ?? [];
        final issueType = bottomSheetViewProvider.issueData?.issueType;
        final match = issueConfigs.indexWhere((element) => element.type?.toLowerCase() == issueType?.toLowerCase());
        if (match != -1) {
          minLength = issueConfigs[match].commentMinLength ?? 5;
        } else {
          minLength = 5;
        }
      }
    }
    super.didChangeDependencies();
  }

  void onSubmit(String value, BuildContext context) async {
    try {
      setState(() {
        loading = true;
      });
      final bottomSheetViewProvider = context.read<BottomSheetViewProvider>();
      Response? response;
      String successMessage = widget.review
          ? languageProvider.getMessage('review_has_been_requested', "Review has been requested")
          :  languageProvider.getMessage('issue_has_been_raised', "Issue has been raised");
      if(widget.review){
        final issue =
        bottomSheetViewProvider.issueData?.copyWith(appealComment: value);
        response = await RaiseDisputeHttp.requestReview(issue);
      } else {
        final issue =
        bottomSheetViewProvider.issueData?.copyWith(comment: value);
        response =  await RaiseDisputeHttp.reportIssue(issue);
      }
      if (response?.statusCode == 200) {
        Navigator.pushNamedAndRemoveUntil(context, IssueHistory.routeName,
            ModalRoute.withName(DailyEarningState.routeName));
        showToast(context,message:successMessage);
      } else {
        ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            final error = responseError.errors?.first;
            try {
              bottomSheetViewProvider.issueData =
                  IssueData.fromJson(error?.data);
              showDynamicBottomSheet(
                context,
              );
            } catch (_){
              showSnackbar(
                  context, error?.message ?? '');
            }
          },
        );
        setState(() {
          loading = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      Navigator.pop(context);
      showSnackbar(context, "Something went wrong - $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle (top indicator)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h), // Spacing from handle to title
        
            // Title
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  widget.title,
                  style: textTheme.headlineSmall?.copyWith(
                    height: 22 / 17, // Line height: 22px
                    letterSpacing: -0.24.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h), // Spacing from title to text field
        
            // Text Input Area
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _textEditingController,
                maxLines: 4,
                // Allows multiple lines
                // expands: true, // Allows the text field to expand vertically
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: textTheme.bodyLarge?.copyWith(
                    height: 20 / 15, // Line height: 20px
                    letterSpacing: -0.24.sp,
                    color: const Color(0xFF1D2129)
                        .withOpacity(0.5), // Lighter hint color
                  ),
                  border: InputBorder.none,
                  // Removes default TextField border
                  isDense: true,
                  // Reduces vertical padding
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 15.h), // Removes internal padding
                ),
                style: textTheme.bodyLarge?.copyWith(
                  height: 20 / 15, // Line height: 20px
                  letterSpacing: -0.24.sp,
                  color: const Color(0xFF1D2129),
                ),
              ),
            ),
            SizedBox(height: 24.h), // Spacing from text field to button
        
            // Submit Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: 1.sw, // Take full width
                child: ElevatedButton(
                  onPressed: _isSubmitButtonEnabled && !loading
                      ? () {
                          onSubmit(_textEditingController.text, context);
                        }
                      : null, // Disable if text is empty
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    // Adjust vertical padding
                    elevation: 0, // Remove shadow
                  ),
                  child: loading ? const CupertinoActivityIndicator(
                    color: AppColors.n0,
                  ) : Text(
                    widget.submitButtonText,
                    style: textTheme.labelLarge?.copyWith(
                      height: 20 / 15, // Line height: 20px
                      letterSpacing: -0.24.sp,
                      color: AppColors.n0, // Figma: color: #FFFFFF;
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h), // Spacing from button to home indicator
          ],
        ),
      ),
    );
  }
}
