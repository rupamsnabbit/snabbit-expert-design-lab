import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wrapper around the top-level `launchUrl` function from `url_launcher`
/// so the handler can be unit-tested without hitting the platform.
typedef UrlLauncherFn = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
});

class OpenUrlHandler implements BifrostHandler {
  OpenUrlHandler({
    this.onExternalUrlOpened,
    UrlLauncherFn? launcher,
    this.logger = const MonitoringBifrostLogger(),
  }) : _launcher = launcher ?? _defaultLauncher;

  /// Schemes the web is allowed to launch externally. `http` is permitted
  /// in debug builds only — in release we require TLS to prevent the web
  /// from steering runners to plaintext endpoints.
  static final Set<String> _allowedSchemes = {
    'https',
    if (kDebugMode) 'http',
    'geo',
    'mailto',
  };

  final void Function(String url, bool success)? onExternalUrlOpened;
  final UrlLauncherFn _launcher;
  final BifrostLogger logger;

  @override
  String get actionName => WebViewConstants.eventOpenUrl;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final url = data['url'];
    if (url is! String || url.isEmpty) {
      logger.logError('webview_open_url_invalid_data', {
        'data': data.toString(),
      });
      return const BifrostResult.empty();
    }

    bool success = false;
    try {
      final uri = Uri.parse(url);
      if (!_allowedSchemes.contains(uri.scheme)) {
        logger.logError('webview_open_url_invalid_scheme', {
          'url': url,
          'scheme': uri.scheme,
        });
        onExternalUrlOpened?.call(url, false);
        return const BifrostResult.empty();
      }
      success = await _launcher(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.logError('webview_open_url_error', {
        'url': url,
        'error': e.toString(),
      });
    }
    onExternalUrlOpened?.call(url, success);
    return const BifrostResult.empty();
  }

  static Future<bool> _defaultLauncher(Uri uri, {required LaunchMode mode}) {
    return launchUrl(uri, mode: mode);
  }
}
