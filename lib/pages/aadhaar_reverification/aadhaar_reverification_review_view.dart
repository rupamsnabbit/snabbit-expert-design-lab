import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/perfios_aadhaar_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Shows the Aadhaar details returned by Perfios for the runner to review
/// before they confirm submission. The raw Perfios payload is what actually
/// gets posted — this screen is display-only.
class AadhaarReverificationReviewView extends StatelessWidget {
  const AadhaarReverificationReviewView({
    super.key,
    required this.data,
    required this.submitting,
    required this.onConfirm,
  });

  final PerfiosAadhaarData data;
  final bool submitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.n0,
      appBar: AppBar(
        foregroundColor: AppColors.n90,
        title: Text(
          languageProvider.getMessage(
              'aadhaar_rekyc_review_heading', 'Review your details'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: submitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                disabledBackgroundColor: AppColors.g40,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: submitting
                  ? const CupertinoActivityIndicator(color: AppColors.n0)
                  : Text(
                      languageProvider.getMessage(
                          'aadhaar_rekyc_confirm', 'Confirm & Submit'),
                      style:
                          textTheme.labelLarge?.copyWith(color: AppColors.n0),
                    ),
            ),
          ),
        ),
      ],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getMessage('aadhaar_rekyc_review_subtitle',
                    'Please confirm these match your Aadhaar before submitting.'),
                style: textTheme.bodyLarge?.copyWith(color: AppColors.n70),
              ),
              SizedBox(height: 24.h),
              _DetailsCard(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.data});

  final PerfiosAadhaarData data;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final rows = <Widget>[
      if (data.name != null)
        _DetailRow(
          label: languageProvider.getMessage('aadhaar_rekyc_name', 'Name'),
          value: data.name!,
        ),
      if (data.dob != null)
        _DetailRow(
          label:
              languageProvider.getMessage('aadhaar_rekyc_dob', 'Date of birth'),
          value: data.dob!,
        ),
      if (data.gender != null)
        _DetailRow(
          label: languageProvider.getMessage('aadhaar_rekyc_gender', 'Gender'),
          value: data.gender!,
        ),
      if (data.maskedAadhaarNumber != null)
        _DetailRow(
          label: languageProvider.getMessage(
              'aadhaar_rekyc_number', 'Aadhaar number'),
          value: data.maskedAadhaarNumber!,
        ),
      if (data.address != null)
        _DetailRow(
          label:
              languageProvider.getMessage('aadhaar_rekyc_address', 'Address'),
          value: data.address!,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.n10,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: AppColors.n60),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.n90),
          ),
        ],
      ),
    );
  }
}
