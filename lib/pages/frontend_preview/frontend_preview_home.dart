import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/pages/getting_started/getting_started.dart';
import 'package:snabbit_runner/pages/getting_started/learn_more.dart';
import 'package:snabbit_runner/pages/login/send_otp.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Design review entry point for the local frontend-only build.
///
/// This screen intentionally uses local copy and navigation only. It gives a
/// product designer a stable launchpad for reviewing the real app surfaces
/// without pretending that a backend session exists.
class FrontendPreviewHome extends StatelessWidget {
  static const String routeName = '/frontend-preview';

  const FrontendPreviewHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frontend preview'),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.brand.withOpacity(.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.palette_outlined,
                    color: AppColors.brand, size: 24.r),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Design-only mode',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'No API, authentication, OTP, or production service is used here. Screens are opened locally for visual review.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text('App surfaces', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12.h),
          _PreviewTile(
            icon: Icons.waving_hand_outlined,
            title: 'Getting Started',
            subtitle: 'Review the entry screen and brand expression.',
            onTap: () => Navigator.pushNamed(context, GettingStarted.routeName),
          ),
          _PreviewTile(
            icon: Icons.login_outlined,
            title: 'Login and OTP',
            subtitle: 'Use any 10-digit phone number and any 4-digit OTP.',
            onTap: () => Navigator.pushNamed(context, SendOtp.routeName),
          ),
          _PreviewTile(
            icon: Icons.info_outline,
            title: 'Learn More',
            subtitle: 'Review the informational onboarding surface.',
            onTap: () => Navigator.pushNamed(context, LearnMore.routeName),
          ),
          SizedBox(height: 24.h),
          Text('Working rule', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8.h),
          Text(
            'New screens and components should be added here only after they use the app tokens, typography, spacing, states, and interaction patterns documented in docs/design/.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: CircleAvatar(
          backgroundColor: AppColors.brand.withOpacity(.1),
          foregroundColor: AppColors.brand,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
