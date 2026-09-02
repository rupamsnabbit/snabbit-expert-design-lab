import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

class NavigationUtils {
  static void openTrainingWebView({
    bool replace = false,
    bool popUntil = false,
    required BuildContext context,
  }) {
    final isTrainingV2Enabled = RemoteConfigHelperUtils.isTrainingV2Enabled;

    // The training page lives on the stack as AppWebViewPage in V2 (the
    // equivalent of the legacy TrainingProgress page) — both the push
    // target and the popUntil target must be this same route.
    final String route = isTrainingV2Enabled
        ? AppWebViewPage.routeName
        : TrainingProgress.routeName;

    if (popUntil) {
      // Pop back to the training page already on the stack. Guard with
      // `r.isFirst`: the target route isn't guaranteed to be present in
      // every flow (e.g. go-live), so without this `popUntil` would pop
      // every route off and blank the screen. Stopping at the root keeps
      // the context alive for the startFlow/snackbar that run afterward.
      Navigator.popUntil(
        context,
        (r) => r.settings.name == route || r.isFirst,
      );
      return;
    }

    // arguments are only needed on the push paths (V2 carries the webview
    // URL; legacy TrainingProgress takes none).
    final Object? arguments = isTrainingV2Enabled
        ? WebViewArgs(
            url: buildWebviewUrl(WebviewRoutes.training),
            title: "Training Progress",
            fetchLocation: true,
          )
        : null;

    if (replace) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) =>
            route.settings.name == SelectLanguageV2.routeName ||
            route.settings.name == '/',
        arguments: arguments,
      );
    } else {
      Navigator.of(context).pushNamed(
        route,
        arguments: arguments,
      );
    }
  }
}
