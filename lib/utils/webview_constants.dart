class WebViewConstants {
  WebViewConstants._();

  /// Name of the JS handler registered on the Flutter side for receiving events from web.
  static const String flutterHandlerName = 'flutterHandler';

  /// Event names sent FROM web TO Flutter
  static const String eventOpenUrl = 'openUrl';
  static const String eventCallPhone = 'callPhone';
  static const String eventSpeak = 'speak';
  static const String eventCloseWebView = 'closeWebView';
  static const String eventRequestInitData = 'requestInitData';
  static const String eventNavigate = 'navigate';
  static const String eventTrackEvent = 'trackEvent';
  static const String eventTokenExpired = 'tokenExpired';
  static const String eventPermissionRequest = 'permissionRequest';
  static const String eventGetAccountSetup = 'getAccountSetup';

  /// Web requests the device phonebook to render the "Refer Friends" contact
  /// list. RPC — returns a normalised `{ name, phone }` list. Web is expected
  /// to grant `contacts` via [eventPermissionRequest] first; this handler
  /// fails with `PERMISSION_DENIED` if it hasn't.
  static const String eventGetContacts = 'getContacts';

  /// Persist the runner's "I've opted into the v2 (Vishwaas) rate card"
  /// decision to SharedPreferences. Fired by the webview immediately
  /// after a successful `POST /payouts/me/rate_card/upgrade`.
  /// Payload: `{ value: bool }`.
  static const String eventSetRateCardOptedIn = 'setRateCardOptedIn';

  /// Generic device-storage bridge (SharedPreferences). One RPC event for all
  /// ops; the value is persisted as a jsonEncoded string.
  /// Payload: `{ action: 'set' | 'get' | 'delete', key: string, value? }`
  /// → `{ value: <any JSON> | null }`.
  static const String eventDeviceStorage = 'deviceStorage';

  /// Web requests native image capture (camera). RPC — returns the
  /// captured image's asset-loader URL and an opaque release token.
  static const String eventCaptureImage = 'captureImage';

  /// Web signals that a previously captured image is no longer needed.
  /// Fire-and-forget — deletes the backing file and frees disk.
  static const String eventReleaseCapture = 'releaseCapture';

  /// Web requests cancellation of an in-flight image capture.
  /// Fire-and-forget — pops the native camera page. The pending
  /// `captureImage` RPC resolves with USER_CANCELLED automatically.
  static const String eventCancelCapture = 'cancelCapture';

  /// Web signals the runner finished going live (backend has already flipped
  /// them to ACTIVE). Fire-and-forget — native re-fetches `runners/me` and
  /// routes by the runner's current state (ACTIVE → PartnerHome), which also
  /// tears down the training hub. Replaces `closeWebView` for the go-live
  /// completion path; the web feature-detects this via [NativeCapabilities].
  static const String eventGoLiveComplete = 'goLiveComplete';

  /// Web asks native to re-fetch `runners/me` after durably changing runner
  /// state on the BE (e.g. the tiering-intro ack). Fire-and-forget.
  static const String eventRefreshRunner = 'refreshRunner';

  /// Web asks native to open the Perfios Aadhaar SDK (`HybridView`) and
  /// return the shutdown payload. RPC. On success returns
  /// `{ demographics: {...}, rawPerfiosJson: "..." }`; failures surface as
  /// structured errors (`USER_CANCELLED`, `PERFIOS_ERROR`,
  /// `PERFIOS_CREDENTIALS_UNAVAILABLE`, `PERFIOS_URL_UNAVAILABLE`,
  /// `PERFIOS_NO_DATA`, `PERFIOS_IN_PROGRESS`). The re-KYC drawer flow keeps
  /// its own entry point; this event is a separate handle for the embedded
  /// web app's onboarding.
  static const String eventOpenPerfiosAadhaar = 'openPerfiosAadhaar';

  /// Event names sent FROM Flutter TO web
  static const String eventInitData = 'initData';
  static const String eventInitError = 'initError';
  static const String eventBackPressed = 'backPressed';

  /// The WebView regained the foreground after a full-screen native route on
  /// top of it was popped (`visible: true`), or was covered when one was
  /// pushed (`visible: false`). Lets the web re-sync state it can't refresh
  /// via the Page Visibility API — `visibilitychange` doesn't fire when the
  /// WebView is merely covered by a Flutter route (it isn't backgrounded).
  /// Payload: `{ visible: bool }`.
  static const String eventWebViewVisibilityChanged =
      'webViewVisibilityChanged';
}
