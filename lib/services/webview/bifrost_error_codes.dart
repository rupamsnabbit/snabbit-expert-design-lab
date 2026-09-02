/// Stable error codes used across the bifrost. Values are wire-format and must
/// never change once shipped. Add new codes here; do not inline string
/// literals elsewhere.
///
/// Naming convention per proposal §2.9: category prefix
/// (`INVALID_` / `UNKNOWN_` / `PERMISSION_` / `TIMEOUT_` / `INTERNAL_`) then a
/// noun describing what.
class BifrostErrorCodes {
  BifrostErrorCodes._();

  /// Handler exists but the request's pattern (FAF vs RPC) doesn't match
  /// what the handler supports — e.g. fire-and-forget sent a requestId.
  static const String patternMismatch = 'PATTERN_MISMATCH';

  /// No handler is registered for the requested event.
  static const String unknownAction = 'UNKNOWN_ACTION';

  /// Payload was syntactically valid but semantically unusable
  /// (missing required field, bad format).
  static const String invalidPayload = 'INVALID_PAYLOAD';

  /// Handler threw an unexpected exception.
  static const String internalError = 'INTERNAL_ERROR';

  /// Access token could not be read from secure storage.
  static const String tokenUnavailable = 'TOKEN_UNAVAILABLE';

  /// Payload was shaped correctly but the specific action's args failed
  /// validation (missing field, wrong type, out of range).
  static const String invalidArgs = 'INVALID_ARGS';

  /// A handler that dispatches on an `action` field in its payload (e.g.
  /// `DeviceStorageHandler`'s `set`/`get`/`delete`) received a value outside
  /// its supported set.
  static const String invalidAction = 'INVALID_ACTION';

  /// The requested `snabbit://` URI is not in the route registry.
  static const String unknownRoute = 'UNKNOWN_ROUTE';

  /// The request arrived inside the action's debounce window. Safe to ignore.
  static const String debounced = 'DEBOUNCED';

  /// The user cancelled an interactive action (e.g. backed out of the
  /// camera without capturing). Not a hard error — the web can treat
  /// this as a resolved-but-cancelled state.
  static const String userCancelled = 'USER_CANCELLED';

  /// A capture (camera) session is already in progress. The web should
  /// wait for the current capture to resolve before requesting another.
  static const String captureInProgress = 'CAPTURE_IN_PROGRESS';

  /// A required device permission was not granted. The error's `details`
  /// map includes `permission` (the name) and `status` (denied /
  /// permanentlyDenied / restricted).
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// The captured image exceeds the servable size cap (see
  /// `CaptureRegistry.maxCaptureSizeBytes`). The RPC fails with this
  /// instead of returning a URL that the serve layer would reject, so the
  /// web can prompt a retake. `details` includes `fileSizeBytes` and
  /// `maxBytes`.
  static const String fileTooLarge = 'FILE_TOO_LARGE';

  /// A Perfios flow is already in progress; the web must wait for it to
  /// resolve before triggering another.
  static const String perfiosInProgress = 'PERFIOS_IN_PROGRESS';

  /// Perfios credentials could not be loaded from the backend. Retryable.
  static const String perfiosCredentialsUnavailable =
      'PERFIOS_CREDENTIALS_UNAVAILABLE';

  /// The Perfios SSP URL could not be built (OAuth token exchange failed
  /// or returned an empty token). Retryable.
  static const String perfiosUrlUnavailable = 'PERFIOS_URL_UNAVAILABLE';

  /// Perfios's `onShutdown` (or `onError`) reported a failure that isn't a
  /// user cancel. Retryable.
  static const String perfiosError = 'PERFIOS_ERROR';

  /// Perfios finished but returned no usable demographic data. Retryable.
  static const String perfiosNoData = 'PERFIOS_NO_DATA';
}
