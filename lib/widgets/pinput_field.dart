import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../utils/colors.dart';

class PinputField extends StatefulWidget {
  final bool isError;
  final bool loading;
  final Function(String) onSubmit;
  final String? subtitleKey;
  final String? subtitleDefault;

  const PinputField({
    super.key,
    required this.loading,
    required this.isError,
    required this.onSubmit,
    this.subtitleKey,
    this.subtitleDefault,
  });

  @override
  State<PinputField> createState() => _PinputFieldState();
}

class _PinputFieldState extends State<PinputField> {
  bool init = true;
  TextEditingController otpTextController = TextEditingController();
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50.r,
      height: 50.r,
      textStyle:
          Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.n50),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(10.r),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.brand),
      borderRadius: BorderRadius.circular(10.r),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );
    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.r50),
      ),
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );
    return Column(
      children: [
        Pinput(
          isCursorAnimationEnabled: false,
          // enabled: !widget.loading,
          cursor: Text(
            "0",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n50),
          ),
          controller: otpTextController,
          preFilledWidget: Text(
            "0",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.n50),
          ),
          errorBuilder: (String? errorText, String pin) {
            return Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Center(
                child: Text(errorText ?? "",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.r50)),
              ),
            );
          },
          mainAxisAlignment: MainAxisAlignment.center,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: widget.isError ? errorPinTheme : submittedPinTheme,
          errorPinTheme: errorPinTheme,
          length: 3,
          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
          showCursor: true,
          onChanged: (_) {
            setState(() {});
          },
        ),
        if (widget.subtitleKey != null && widget.subtitleDefault != null)
          Padding(
            padding: EdgeInsets.only(top: 18.h),
            child: Text(
              languageProvider.getMessage(
                widget.subtitleKey!,
                widget.subtitleDefault!,
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.n80),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: 28.h),
          child: SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: otpTextController.text.length == 3 ? () {
                widget.onSubmit(otpTextController.text);
              } : null,

              child: Text(
                languageProvider.getMessage(
                  'submit',
                  'Submit',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
