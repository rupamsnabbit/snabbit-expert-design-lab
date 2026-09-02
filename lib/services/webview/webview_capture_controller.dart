import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snabbit_runner/pages/selfie_capture_page.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/cancel_capture_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/capture_image_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/release_capture_handler.dart';
import 'package:snabbit_runner/widgets/camera_permission_bottom_sheet.dart';

/// Owns the bifrost image-capture concern for `AppWebViewPage`: the capture
/// handlers ([CaptureImageHandler] / [CancelCaptureHandler] /
/// [ReleaseCaptureHandler]), the camera-permission bottom sheet, the
/// selfie-capture page push, and the `WebViewAssetLoader` host/path that serve
/// captured images from disk.
///
/// Extracted from `AppWebViewPage`'s State to keep that file focused —
/// behaviour is unchanged. The owning State supplies the current
/// [BuildContext] and `mounted` via callbacks (capture is triggered long after
/// handler wiring, so the controller reads them at call time rather than
/// capturing a context once), owns this controller's lifecycle, and must call
/// [dispose].
class WebViewCaptureController {
  WebViewCaptureController({
    required BuildContext Function() contextProvider,
    required bool Function() isMounted,
  })  : _contextProvider = contextProvider,
        _isMounted = isMounted;

  final BuildContext Function() _contextProvider;
  final bool Function() _isMounted;

  /// Android `WebViewAssetLoader` virtual host + path that serve captured
  /// images from disk. [urlForToken], the loader's `domain`, and the
  /// `CapturePathHandler` path must stay in sync — hence shared constants.
  static const String assetDomain = 'appassets.androidplatform.net';
  static const String capturePath = '/captures/';

  /// Notifier used to dismiss the [SelfieCapturePage] / permission sheet from
  /// the handler side (e.g. web sends `cancelCapture`). The camera page listens
  /// to this and pops itself — avoids a blind [Navigator.pop] that could
  /// dismiss the wrong route (permission sheet, dialog, etc.).
  final ValueNotifier<bool> _dismissNotifier = ValueNotifier(false);

  bool _captureInProgress = false;

  /// True while the selfie-capture page is on screen. The owning State reads
  /// this to suppress its `webViewVisibilityChanged` signal for the capture
  /// round-trip — capture is a web-initiated RPC that returns its result inline
  /// (not a navigation away), so a visibility refetch there is spurious and can
  /// race the web's own capture handler.
  bool get isCaptureInProgress => _captureInProgress;

  /// Builds the `WebViewAssetLoader` URL for a given capture token.
  static String urlForToken(String token) =>
      'https://$assetDomain$capturePath$token.jpg';

  /// Builds the three capture bifrost handlers. The owning State spreads these
  /// into its handler map.
  List<BifrostHandler> buildHandlers() {
    final captureHandler = CaptureImageHandler(
      captureCallback: _captureImage,
      urlBuilder: urlForToken,
      dismissCapture: () {
        _dismissNotifier.value = true;
      },
      onPermissionDenied: (status) async {
        if (!_isMounted()) return false;
        // Reset so a stale cancel signal from a prior capture can't
        // immediately dismiss this sheet; the sheet then listens for a
        // fresh `cancelCapture` to close itself.
        _dismissNotifier.value = false;
        final result = await showModalBottomSheet<bool>(
          context: _contextProvider(),
          isDismissible: false,
          enableDrag: false,
          builder: (_) => CameraPermissionBottomSheet(
            status: status,
            dismissNotifier: _dismissNotifier,
          ),
        );
        return result == true;
      },
    );

    return <BifrostHandler>[
      captureHandler,
      CancelCaptureHandler(captureHandler: captureHandler),
      ReleaseCaptureHandler(),
    ];
  }

  /// Opens the selfie capture page and returns the captured [File], or `null`
  /// if the user cancels. Used as the [ImageCapturer] callback by
  /// [CaptureImageHandler].
  Future<File?> _captureImage() async {
    if (!_isMounted()) return null;
    // Reset so the notifier is ready for a fresh dismiss signal.
    _dismissNotifier.value = false;
    // Suppress webViewVisibilityChanged for the capture round-trip (the owning
    // State checks [isCaptureInProgress]).
    _captureInProgress = true;
    try {
      return await Navigator.of(_contextProvider()).push<File>(
        MaterialPageRoute(
          builder: (_) => SelfieCapturePage(
            popWithResult: true,
            dismissNotifier: _dismissNotifier,
          ),
        ),
      );
    } finally {
      _captureInProgress = false;
    }
  }

  void dispose() {
    _dismissNotifier.dispose();
  }
}
