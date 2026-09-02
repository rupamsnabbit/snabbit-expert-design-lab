import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

///[UiHelper] is an utility class for building widgets based on different states, such as loading, error, and empty states.
///
/// This class provides methods to create commonly used widgets for various application states,
/// promoting code reuse and consistency in UI presentation.
class UiHelper {

  static Widget showLoader() {
    return const Center(
      child: CupertinoActivityIndicator(),
    );
  }

  static Widget showLoadFailError(BuildContext context) {
    return  Text(
      "Failed to load data.",
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(
        color: AppColors.r40,
      ),
    );
  }
}