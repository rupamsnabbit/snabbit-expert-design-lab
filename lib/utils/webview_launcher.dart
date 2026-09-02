import 'package:flutter/widgets.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';

/// Single source of truth for opening the in-app webview ([AppWebViewPage]).
///
/// Centralises what was duplicated between the drawer's `_openWebView` and the
/// deeplink router: the "openable" rule ([isOpenableHttps]), the [WebViewArgs]
/// construction, and the navigation. Call sites keep only their own *failure*
/// handling (the drawer shows a snackbar; the router falls back to Home) and
/// choose the nav mode via [replace].
class WebViewLauncher {
  WebViewLauncher._();

  /// The single definition of an openable webview URL: non-empty, parseable,
  /// and https (we never open insecure or non-http schemes in a webview).
  static bool isOpenableHttps(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https';
  }

  /// Builds [WebViewArgs] and navigates to [AppWebViewPage].
  ///
  /// [replace] == true uses `popAndPushNamed` (the drawer dismisses its own
  /// route before showing the webview); false uses `pushNamed` (the webview
  /// stacks on top of the current screen). Callers should validate the URL with
  /// [isOpenableHttps] first — this method does not re-check.
  ///
  /// [refreshCurrentStateOnClose] — see
  /// [WebViewArgs.refreshCurrentStateOnClose]: re-fetch `current_state` when
  /// this webview closes, for pages that can mutate what the home renders.
  static void open(
    BuildContext context, {
    required String url,
    required String title,
    bool fetchLocation = false,
    bool refreshCurrentStateOnClose = false,
    bool replace = false,
    void Function()? onPageLoaded,
    void Function(String reason)? onPageLoadFailed,
    void Function(String url, bool success)? onExternalUrlOpened,
  }) {
    final args = WebViewArgs(
      url: url,
      title: title,
      fetchLocation: fetchLocation,
      refreshCurrentStateOnClose: refreshCurrentStateOnClose,
      onPageLoaded: onPageLoaded,
      onPageLoadFailed: onPageLoadFailed,
      onExternalUrlOpened: onExternalUrlOpened,
    );
    final navigator = Navigator.of(context);
    if (replace) {
      navigator.popAndPushNamed(AppWebViewPage.routeName, arguments: args);
    } else {
      navigator.pushNamed(AppWebViewPage.routeName, arguments: args);
    }
  }
}
