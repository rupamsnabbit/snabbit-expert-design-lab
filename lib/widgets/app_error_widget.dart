import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

/// Reusable error UI with a retry action.
///
/// Note: Named `AppErrorWidget` to avoid clashing with Flutter's built-in `ErrorWidget`.
class AppErrorWidget extends StatelessWidget {
  final String message;
  final FutureOr<void> Function() onRetry;

  const AppErrorWidget({
    super.key,
    required this.onRetry,
    this.message = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: () async {
              await onRetry();
            },
            child: Text(
              languageProvider.getMessage('retry', 'Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
