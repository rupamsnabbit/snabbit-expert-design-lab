import 'package:flutter/foundation.dart';

/// Runtime policy for the design-only build.
///
/// Debug builds default to frontend-only mode so the app can be reviewed
/// without authentication, APIs, or production service configuration. A
/// release build keeps the production flow unless explicitly overridden with
/// `--dart-define=FRONTEND_ONLY=true`.
abstract final class FrontendPreview {
  static const bool enabled = bool.fromEnvironment(
    'FRONTEND_ONLY',
    defaultValue: kDebugMode,
  );

  static const String previewPhone = '9876543210';
}
