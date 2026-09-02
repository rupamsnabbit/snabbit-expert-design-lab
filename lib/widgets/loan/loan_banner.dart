import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/loan/utils/loan_tracking.dart';

class LoanBanner extends StatefulWidget {
  final VoidCallback onTap;
  final String source;

  const LoanBanner({
    super.key,
    required this.onTap,
    required this.source,
  });

  @override
  State<LoanBanner> createState() => _LoanBannerState();
}

class _LoanBannerState extends State<LoanBanner> {
  static const Map<String, String> _languageMap = {
    'ENGLISH': 'loans/loan_banner_english.webp',
    'HINDI': 'loans/loan_banner_hindi.webp',
    'KANNADA': 'loans/loan_banner_kannada.webp',
    'MARATHI': 'loans/loan_banner_marathi.webp',
    'TAMIL': 'loans/loan_banner_tamil.webp',
    'TELUGU': 'loans/loan_banner_telugu.webp',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackView();
    });
  }

  void _trackView() {
    try {
      LoanTracking.trackLoanBannerImpression(
        source: widget.source,
      );
    } catch (e) {
      // Do nothing
    }
  }

  String _getLoanBannerImageUrl(String? languagePreference) {
    // Default to English if language not found
    final imageUrl = _languageMap[languagePreference?.toUpperCase()] ??
        _languageMap['ENGLISH']!;

    return imageUrl.cdn;
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>().user;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: GestureDetector(
        onTap: () {
          try {
            LoanTracking.trackLoanBannerClick(
              source: widget.source,
            );
          } catch (_) {}
          widget.onTap();
        },
        child: RemoteImageHandler(
          imageUrl: _getLoanBannerImageUrl(userProfile?.languagePreference),
          height: 115.h,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
