import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/perfios_aadhaar_bridge_page.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/nav_observer.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/call_phone_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/speak_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/close_webview_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/device_storage_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/get_account_setup_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/get_contacts_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/go_live_complete_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/navigate_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/open_perfios_aadhaar_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/open_url_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/permission_request_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/refresh_current_state_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/refresh_runner_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/request_init_data_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/set_rate_card_opted_in_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/token_expired_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/track_event_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_router.dart';
import 'package:snabbit_runner/services/webview/capture_path_handler.dart';
import 'package:snabbit_runner/services/webview/webview_capture_controller.dart';
import 'package:snabbit_runner/services/webview/inapp_webview_channel.dart';
import 'package:snabbit_runner/services/webview/origin_gate.dart';
import 'package:snabbit_runner/services/webview/webview_channel.dart';
import 'package:snabbit_runner/services/webview/webview_routes.dart';
import 'package:snabbit_runner/services/webview_event_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';
import 'package:snabbit_runner/widgets/app_error_widget.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/contacts_permission_bottom_sheet.dart';

typedef WebViewChannelFactory =
    WebViewChannel Function(InAppWebViewController controller);

class AppWebViewPage extends StatefulWidget {
  static const routeName = '/app-web-view';

  const AppWebViewPage({super.key, this.channelFactory});

  /// Injected only by tests; production code uses the default
  /// `InAppWebViewChannel` adapter.
  @visibleForTesting
  final WebViewChannelFactory? channelFactory;

  @override
  State<AppWebViewPage> createState() => _AppWebViewPageState();
}

class _AppWebViewPageState extends State<AppWebViewPage> with RouteAware {
  static const String _authCookieName = 'access_token';
  static const Duration _cookiePrepTimeout = Duration(seconds: 5);
  static const int _locationCacheMaxAgeSecs = 120; // 2 minutes

  /// Widget states that require immediate runner attention and must
  /// auto-dismiss any overlay page (including this WebView).
  static const Set<String> _autoCloseWidgetStates = {'RUNNER_NEW_JOB'};

  bool _init = true;
  WebViewArgs? _args;

  bool _isLoading = true;
  bool _hasError = false;
  bool _initDataSent = false;
  bool _pageLoadTracked = false;
  bool _isPopping = false;
  bool _cookieReady = false;
  int _retryCount = 0;
  WebViewChannel? _channel;
  BifrostRouter? _router;

  /// Owns the bifrost image-capture concern (handlers, permission sheet,
  /// selfie-capture page, asset-loader host/path). The State delegates capture
  /// wiring to it and reads [WebViewCaptureController.isCaptureInProgress] to
  /// suppress its `webViewVisibilityChanged` signal during a capture round-trip
  /// (an inline RPC, not a navigation away). Initialised in [initState].
  late final WebViewCaptureController _captureController;
  /// Held so the utterance can be stopped when this page closes.
  final SpeakHandler _speakHandler = SpeakHandler();
  Future<Map<String, dynamic>?>? _locationFuture;
  RunnerRtDataProvider? _runnerRtDataProvider;
  String? _lastWidgetName;

  /// Fallback timer after a system-back: if the web doesn't acknowledge
  /// the `backPressed` event within this window — either by calling
  /// `closeWebView` or by navigating in-page (observed via
  /// `onUpdateVisitedHistory`) — we force-close so the runner isn't
  /// trapped inside an unresponsive page.
  static const Duration _backWatchdogDuration = Duration(milliseconds: 1500);
  Timer? _backWatchdog;

  bool get _showAppBar => _isLoading || _hasError;

  @override
  void initState() {
    super.initState();
    _captureController = WebViewCaptureController(
      contextProvider: () => context,
      isMounted: () => mounted,
    );
  }

  /// Builds a [WebViewArgs] from a String map — the shape the KMP nav keep-host
  /// bridge delivers when a native Profile tile opens this page. Accepts either a
  /// full `url` or a `webviewPath` (resolved via [buildWebviewUrl]); returns null
  /// if neither yields a usable URL (the caller then treats args as invalid).
  WebViewArgs? _webViewArgsFromMap(Map<dynamic, dynamic> map) {
    final rawUrl = map['url'] as String?;
    final path = map['webviewPath'] as String?;
    // Optional query attribution (e.g. Refer & earn → entry_point=profile_menu),
    // matching the drawer's buildWebviewUrl(query: ...).
    final entryPoint = map['entryPoint'] as String?;
    final query = (entryPoint != null && entryPoint.isNotEmpty)
        ? {'entry_point': entryPoint}
        : null;
    final url = (rawUrl != null && rawUrl.isNotEmpty)
        ? rawUrl
        : (path != null && path.isNotEmpty
            ? buildWebviewUrl(path, query: query)
            : null);
    if (url == null || url.isEmpty) return null;
    return WebViewArgs(
      url: url,
      title: (map['title'] as String?) ?? '',
      fetchLocation: (map['fetchLocation'] as String?) == 'true',
      // String-typed like the rest of this map — the KMP nav bridge only
      // carries Map<String, String>.
      refreshCurrentStateOnClose: (map['refreshOnClose'] as String?) == 'true',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) {
      _init = false;
      final route = ModalRoute.of(context);
      final rawArguments = route?.settings.arguments;
      // KMP opens this page via the nav keep-host bridge, which delivers a String
      // map rather than a WebViewArgs — convert it so both entry points work.
      final arguments =
          rawArguments is Map ? _webViewArgsFromMap(rawArguments) : rawArguments;
      if (arguments is WebViewArgs) {
        _args = arguments;
        if (arguments.fetchLocation) {
          _locationFuture = _fetchLocation();
        }
        _runCookiePrep(arguments.url);
        _runnerRtDataProvider = Provider.of<RunnerRtDataProvider>(
          context,
          listen: false,
        );
        _lastWidgetName = _runnerRtDataProvider?.widgetInfo?.name;
        _runnerRtDataProvider?.addListener(_onRunnerStateChanged);
      } else {
        MonitoringServiceHelper.logError('app_webview_invalid_args', {
          'arguments': arguments?.toString() ?? 'null',
        });
        // Pop this page and show a snackbar on the destination route so
        // the runner sees a hint instead of a silent disappear. We can't
        // attach the snackbar to this page's ScaffoldMessenger because
        // pop disposes it; use the global navigator's context instead
        // which resolves to whatever route we land on.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = GlobalState().navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              showSnackbar(ctx, 'Could not open this page. Please try again.');
            }
          });
        });
      }
    }

    // Subscribe for RouteAware callbacks so we can notify the web when this
    // WebView is covered or revealed by a full-screen Flutter route. Safe to
    // call on every didChangeDependencies — subscribe() dedupes.
    final pageRoute = ModalRoute.of(context);
    if (pageRoute is PageRoute) {
      appRouteObserver.subscribe(this, pageRoute);
    }
  }

  /// A full-screen Flutter route on top of this WebView was popped — the
  /// WebView is foreground again. Tell the web so it can re-sync state the
  /// Page Visibility API can't surface here (the WebView was only covered,
  /// not backgrounded). Covers both a user back-press and the onboarding
  /// flow's programmatic `popUntil(AppWebViewPage)` on completion.
  @override
  void didPopNext() => _notifyWebViewVisibility(true);

  /// A full-screen Flutter route was pushed over this WebView.
  @override
  void didPushNext() => _notifyWebViewVisibility(false);

  void _notifyWebViewVisibility(bool visible) {
    // Skip the capture round-trip: SelfieCapturePage is a full-screen
    // PageRoute, so pushing/popping it would otherwise emit visible:false/true
    // for an in-flow RPC that isn't a real navigation. didPopNext fires
    // synchronously during the pop — before the push future's await clears
    // this flag — so the visible:true is correctly suppressed too.
    if (_captureController.isCaptureInProgress) return;
    final channel = _channel;
    if (channel == null) return;
    unawaited(
      channel
          .pushEvent(WebViewConstants.eventWebViewVisibilityChanged, {
            'visible': visible,
          })
          .catchError((Object e) {
            // pushEvent logs JS-side failures itself; this guards a rejected
            // future (e.g. controller torn down mid-transition) from surfacing
            // as an unhandled async error.
            MonitoringServiceHelper.logError(
              'webview_visibility_changed_failed',
              {'visible': visible, 'error': e.toString()},
            );
          }),
    );
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _captureController.dispose();
    // The TTS engine outlives this page — cut any reply still being read out.
    unawaited(_speakHandler.stop());
    // Pages that can mutate the state the home renders from (lunch-slot
    // selection) ask for a refresh as they close, so the runner doesn't return
    // to a stale home. Fire-and-forget against the provider, which outlives
    // this page — `context` is not safe to touch from dispose(). Safe to leave
    // unawaited: the provider logs and swallows its own failures, so nothing
    // escapes here as an unhandled async error.
    final refreshTarget = _runnerRtDataProvider;
    if (_args?.refreshCurrentStateOnClose == true && refreshTarget != null) {
      unawaited(refreshTarget.refreshCurrentStateAfterWebview());
    }
    _runnerRtDataProvider?.removeListener(_onRunnerStateChanged);
    _backWatchdog?.cancel();
    _backWatchdog = null;
    _channel = null;
    _router = null;
    final url = _args?.url;
    if (url != null) {
      // Fire-and-forget: remove the auth cookie so it does not leak across sessions.
      try {
        CookieManager.instance()
            .deleteCookie(url: WebUri(url), name: _authCookieName)
            .catchError((e) {
              MonitoringServiceHelper.logError(
                'app_webview_delete_auth_cookie_error',
                {'error': e.toString()},
              );
              return false;
            });
      } catch (e) {
        MonitoringServiceHelper.logError(
          'app_webview_delete_auth_cookie_url_parse_error',
          {'error': e.toString()},
        );
      }
    }
    // AnnotatedRegion doesn't restore the previous overlay style on
    // unmount, so re-apply the app-wide style set by PartnerHome.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  void _closeWebView([Map<String, dynamic>? result]) {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    _backWatchdog?.cancel();
    _backWatchdog = null;
    Navigator.of(context).pop(result);
  }

  /// Handles the web's `goLiveComplete` event (the runner tapped "Get started"
  /// after going live; the backend has already flipped them to ACTIVE).
  ///
  /// Go-live runs inside this training hub webview, and the backend changes the
  /// runner's status server-side only — our local user object is stale. A plain
  /// `closeWebView` here would reveal the screen the hub was launched over
  /// (SelectLanguageV2) instead of PartnerHome. So we re-fetch `runners/me` and
  /// route by the runner's current state: [navigateAfterRunnersMe] with
  /// `replace: true` does `pushNamedAndRemoveUntil(PartnerHome, …)` for ACTIVE,
  /// which both routes and tears down the hub — no separate close needed. Falls
  /// back to a plain pop if refresh/routing throws so the runner is never left
  /// frozen on the hub.
  Future<void> _onGoLiveComplete() async {
    if (_isPopping || !mounted) return;
    _isPopping = true;
    _backWatchdog?.cancel();
    _backWatchdog = null;
    try {
      await RegistrationNavigation.refreshRegistrationAndContinue(context);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'app_webview_go_live_complete_route_failed',
        {'error': e.toString()},
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onRunnerStateChanged() {
    final currentName = _runnerRtDataProvider?.widgetInfo?.name;
    if (currentName != null &&
        _autoCloseWidgetStates.contains(currentName) &&
        _lastWidgetName != currentName) {
      MonitoringServiceHelper.logError('app_webview_auto_close_job_assigned', {
        'widget_name': currentName,
        'previous': _lastWidgetName ?? 'null',
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isPopping) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        _closeWebView();
      });
    }
    // Don't consume auto-close state transitions — keep _lastWidgetName
    // at the prior value so the close retries on the next notifyListeners
    // (e.g. if an overlay was blocking isCurrent on this attempt).
    if (currentName == null || !_autoCloseWidgetStates.contains(currentName)) {
      _lastWidgetName = currentName;
    }
  }

  /// (Re)starts the back-press watchdog. If the web page doesn't respond
  /// to `backPressed` by calling `closeWebView` within
  /// [_backWatchdogDuration], we close the webview ourselves so the
  /// runner isn't stuck.
  void _armBackWatchdog() {
    _backWatchdog?.cancel();
    _backWatchdog = Timer(_backWatchdogDuration, () {
      if (!mounted || _isPopping) return;
      MonitoringServiceHelper.logError('bifrost_back_watchdog_fired', {
        'elapsedMs': _backWatchdogDuration.inMilliseconds,
      });
      _closeWebView();
    });
  }

  /// Called whenever the web navigates (history.back / pushState / full
  /// load). If the back watchdog is currently armed, treat the navigation
  /// as proof the web handled the `backPressed` event and cancel the
  /// watchdog — the runner is still on a valid page, just one level back.
  void _onWebHistoryChanged() {
    if (_isPopping) return;
    if (_backWatchdog?.isActive != true) return;
    _backWatchdog?.cancel();
    _backWatchdog = null;
  }

  void _retry() {
    final args = _args;
    if (args == null || !mounted) return;
    _channel = null;
    _router = null;
    _initDataSent = false;
    _pageLoadTracked = false;
    _retryCount++;
    _cookieReady = false;
    _runCookiePrep(args.url);
    if (args.fetchLocation) {
      _locationFuture = _fetchLocation();
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
  }

  /// Kicks off cookie preparation for the current generation of the page,
  /// applies a hard timeout so a hung native call cannot leave the UI stuck on
  /// the loading spinner, and only flips `_cookieReady` if the same generation
  /// is still active when prep completes.
  ///
  /// `whenComplete` (not `then`) is used so the WebView still mounts if cookie
  /// prep fails or times out — the SPA falls back to the JS-bridge initData.
  void _runCookiePrep(String rawUrl) {
    final generation = _retryCount;
    _prepareAuthCookie(rawUrl)
        .timeout(
          _cookiePrepTimeout,
          onTimeout: () {
            MonitoringServiceHelper.logError(
              'app_webview_set_auth_cookie_timeout',
              {},
            );
          },
        )
        .whenComplete(() {
          if (!mounted || _retryCount != generation) return;
          setState(() => _cookieReady = true);
        });
  }

  Future<void> _prepareAuthCookie(String rawUrl) async {
    final WebUri uri;
    try {
      uri = WebUri(rawUrl);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'app_webview_set_auth_cookie_invalid_url',
        {'error': e.toString()},
      );
      return;
    }
    final cookieMgr = CookieManager.instance();

    // Best-effort: clear any stale cookie from a prior session or retry.
    // Failure here must NOT block setting the fresh cookie below.
    try {
      await cookieMgr.deleteCookie(url: uri, name: _authCookieName);
    } catch (e) {
      MonitoringServiceHelper.logError('app_webview_clear_stale_cookie_error', {
        'error': e.toString(),
      });
    }
    if (!mounted) return;

    try {
      final token = await SecureStorageUtils.getAccessToken('APP_WEB_VIEW');
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        // SPA still receives the token via the initData JS bridge, which
        // emits its own initError event when the token is unavailable.
        MonitoringServiceHelper.logError(
          'app_webview_set_auth_cookie_token_null',
          {},
        );
        return;
      }
      await cookieMgr.setCookie(
        url: uri,
        name: _authCookieName,
        value: token,
        path: '/',
        isSecure: uri.scheme == 'https',
        // httpOnly=true: browser attaches the cookie on every request to
        // this origin, but JS can't read it via `document.cookie`. Closes
        // the XSS exfiltration hole for free — web never needs the raw
        // token (auth is same-origin, cookie-driven). Token refresh still
        // works because Flutter owns the cookie via CookieManager.
        isHttpOnly: true,
        sameSite: HTTPCookieSameSitePolicy.LAX,
      );
    } catch (e) {
      MonitoringServiceHelper.logError('app_webview_set_auth_cookie_error', {
        'error': e.toString(),
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchLocation() async {
    // Layer 1: OS cache — instant, no GPS hardware involved.
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final age = DateTime.now().difference(position.timestamp);
        if (age.inSeconds <= _locationCacheMaxAgeSecs) {
          return {
            'lat': position.latitude,
            'lng': position.longitude,
            'source': 'os_cache',
          };
        }
      }
    } catch (e) {
      MonitoringServiceHelper.logError('app_webview_location_os_cache_error', {
        'error': e.toString(),
      });
    }
    if (!mounted) return null;

    // Layer 2: IoT DB cache — best-effort, only works when IoT collection is
    // enabled. DB may not be initialized (throws "Database not initialized" if
    // IoT is off) — that is expected, not an error, so we skip logging it.
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        final cached = await LocationCollector().getLastCollected(
          userId,
          maxAgeSeconds: _locationCacheMaxAgeSecs,
        );
        if (cached != null) {
          return {'lat': cached.lat, 'lng': cached.long, 'source': 'iot_db'};
        }
      }
    } catch (e) {
      final msg = e.toString();
      // "Database not initialized" is expected when IoT is off — not an error.
      if (!msg.contains('not initialized')) {
        MonitoringServiceHelper.logError(
          'app_webview_location_iot_cache_error',
          {'error': msg},
        );
      }
    }
    if (!mounted) return null;

    // Layer 3: Live GPS — current behavior, unchanged.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'source': 'live_gps',
      };
    } catch (e) {
      MonitoringServiceHelper.logError('app_webview_location_fetch_error', {
        'error': e.toString(),
      });
      return {'locationError': 'unavailable'};
    }
  }

  // ---------------------------------------------------------------------------
  // InAppWebView callbacks
  // ---------------------------------------------------------------------------

  /// Grant the page's microphone request (support voice notes).
  ///
  /// The manifest's RECORD_AUDIO grant is necessary but not sufficient: Android
  /// routes `getUserMedia` through `WebChromeClient.onPermissionRequest`, which
  /// the plugin DENIES unless this callback answers. Without it the runner sees
  /// "Microphone permission is needed" even after granting the OS prompt.
  ///
  /// Only the microphone is granted, and only for our own origins — anything
  /// else (camera, a third-party page) still gets denied.
  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final wantsMicOnly = request.resources.every(
      (r) => r == PermissionResourceType.MICROPHONE,
    );
    if (!wantsMicOnly || !_isTrustedOrigin(request.origin)) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }
    // The OS-level grant still has to exist; ask for it if the runner has not
    // been through the prompt yet.
    final status = await Permission.microphone.request();
    return PermissionResponse(
      resources: request.resources,
      action: status.isGranted
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  bool _isTrustedOrigin(WebUri origin) {
    final host = origin.host;
    return host.endsWith('.snabbit.com') ||
        host.endsWith('.snabbit.net') ||
        host == WebViewCaptureController.assetDomain ||
        // Local dev: the emulator's host loopback and a LAN dev server.
        host == '10.0.2.2' ||
        host == 'localhost' ||
        host == '127.0.0.1';
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    final args = _args;
    if (args == null) return;

    final factory = widget.channelFactory ?? InAppWebViewChannel.new;
    final channel = factory(controller);
    _channel = channel;

    _router = BifrostRouter(
      channel: channel,
      originGate: OriginGate(initialUrl: args.url),
      handlers: _buildHandlers(),
    );

    channel.registerInboundHandler(
      WebViewConstants.flutterHandlerName,
      _onJavaScriptMessage,
    );
  }

  Map<String, BifrostHandler> _buildHandlers() {
    final handlers = <BifrostHandler>[
      OpenUrlHandler(onExternalUrlOpened: _args?.onExternalUrlOpened),
      CallPhoneHandler(),
      _speakHandler,
      CloseWebViewHandler(onClose: _closeWebView),
      GoLiveCompleteHandler(onGoLiveComplete: _onGoLiveComplete),
      RequestInitDataHandler(buildInitData: _buildInitDataForRpc),
      NavigateHandler(
        registry: defaultWebViewRouteRegistry(),
        navigator: GlobalKeyAppNavigator(GlobalState().navigatorKey),
      ),
      TrackEventHandler(),
      SetRateCardOptedInHandler(),
      DeviceStorageHandler(),
      TokenExpiredHandler(onClose: () => _closeWebView()),
      PermissionRequestHandler(),
      GetContactsHandler(onPermissionDenied: _showContactsPermissionSheet),
      GetAccountSetupHandler(buildAccountSetup: _buildAccountSetup),
      RefreshCurrentStateHandler(
        onRefresh: () {
          if (!mounted) return;
          Provider.of<RunnerRtDataProvider>(
            context,
            listen: false,
          ).fetchCurrentState();
        },
      ),
      RefreshRunnerHandler(
        onRefresh: () {
          if (!mounted) return;
          Provider.of<UserProfileProvider>(
            context,
            listen: false,
          ).runnersMeSetup();
        },
      ),
      OpenPerfiosAadhaarHandler(
        openPerfios: () {
          final navState = GlobalState().navigatorKey.currentState;
          if (navState == null) {
            return Future<Map<String, dynamic>?>.value(null);
          }
          return navState.push<Map<String, dynamic>>(
            MaterialPageRoute(
              builder: (_) => const PerfiosAadhaarBridgePage(),
            ),
          );
        },
      ),
      ..._captureController.buildHandlers(),
    ];
    return {for (final h in handlers) h.actionName: h};
  }

  /// Shown by [GetContactsHandler] when contacts permission is denied. Mirrors
  /// the camera-capture flow: present a rationale sheet that guides the runner
  /// to app settings and re-checks on resume. Returns `true` if the runner
  /// resolved the permission, `false` to give up (handler → PERMISSION_DENIED).
  Future<bool> _showContactsPermissionSheet(PermissionStatus status) async {
    if (!mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ContactsPermissionBottomSheet(status: status),
    );
    return result == true;
  }

  Future<BifrostResult> _buildInitDataForRpc(
    Map<String, dynamic> requestData,
  ) async {
    if (!mounted) {
      return const BifrostResult.empty();
    }
    final additionalData = (_args?.fetchLocation == true)
        ? await _fetchLocation()
        : null;
    if (!mounted) {
      return const BifrostResult.empty();
    }
    final requestedCapabilities = (requestData['capabilities'] as List?)
        ?.whereType<String>()
        .toList(growable: false);
    return WebViewEventHandler.buildInitData(
      additionalData: additionalData,
      context: context,
      requestedCapabilities: requestedCapabilities,
    );
  }

  /// Resolves the runner's current bank + PAN state from
  /// [UserProfileProvider] into the shape the web Payouts page expects.
  ///
  /// Status mapping:
  /// - `bankVerified == true`                      → `added`
  /// - `bankAccountNumber` present, not verified   → `processing`
  /// - otherwise                                   → `not_added`
  /// - `isPanVerified == true`                     → `added`
  /// - otherwise                                   → `not_added`
  ///
  /// Also forwards [UserProfile.rateCardOptinMonth] (`YYYY-MM` or `null`)
  /// so the web Payouts page can route month requests older than that to
  /// the native v1 earnings screen.
  Future<BifrostResult> _buildAccountSetup() async {
    if (!mounted) return const BifrostResult.empty();
    final userProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );
    final user = userProvider.user;

    final String upiBankStatus;
    if (user?.bankVerified == true) {
      upiBankStatus = 'added';
    } else if ((user?.bankAccountNumber ?? '').isNotEmpty) {
      upiBankStatus = 'processing';
    } else {
      upiBankStatus = 'not_added';
    }

    final String panStatus = user?.isPanVerified == true
        ? 'added'
        : 'not_added';

    final maskedBankNumber = maskAccountNumber(user?.bankAccountNumber ?? '');
    final panNumber = user?.pan;
    final hasPanNumber = panNumber != null && panNumber.isNotEmpty;

    final data = <String, dynamic>{
      'upiBank': {
        'status': upiBankStatus,
        if (maskedBankNumber.isNotEmpty) 'maskedNumber': maskedBankNumber,
      },
      'pan': {'status': panStatus, if (hasPanNumber) 'panNumber': panNumber},
      'rateCardOptinMonth': user?.rateCardOptinMonth,
    };

    if (userProvider.optedForNewRateCard) {
      try {
        data['provisionalAttendanceStatus'] =
            _deriveProvisionalAttendanceStatus();
      } catch (e, st) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'webview_attendance_status',
          fatal: false,
        );
      }
    }

    return BifrostResult(data: data);
  }

  /// Derives the provisional-attendance status for the webview.
  /// Checks [provisionalAttendanceOverride] first (fresh after marking
  /// attendance), falls back to [widgetInfo.name].
  String _deriveProvisionalAttendanceStatus() {
    if (!mounted) return 'not_applicable';
    final rtProvider = Provider.of<RunnerRtDataProvider>(
      context,
      listen: false,
    );

    final override = rtProvider.provisionalAttendanceOverride;
    if (override != null) return override;

    switch (rtProvider.widgetInfo?.name) {
      case 'PA_BEFORE_LOGOUT':
      case 'RUNNER_ATTENDANCE_TOMORROW':
        return 'pending';
      case 'RUNNER_ATTENDANCE_CONFIRMED':
        return 'present';
      case 'RUNNER_ATTENDANCE_ABSENT':
        return 'absent';
      case 'RUNNER_SEE_YOU_TOMORROW':
        return 'completed';
      default:
        return 'not_applicable';
    }
  }

  Future<void> _onJavaScriptMessage(List<dynamic> arguments) async {
    if (arguments.isEmpty) {
      MonitoringServiceHelper.logError('webview_handler_empty_args', {});
      return;
    }
    final router = _router;
    if (router == null) return;
    await router.onInbound(arguments[0] as String);
  }

  Future<void> _onPageCommitVisible(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    final args = _args;
    if (args == null || _initDataSent) return;

    final initialOrigin = Uri.parse(args.url).origin;
    if (url != null && Uri.parse(url.toString()).origin != initialOrigin) {
      return;
    }

    _initDataSent = true;
    final generation = _retryCount;

    final additionalData = await _locationFuture;
    if (!mounted || _channel == null || _retryCount != generation) {
      return;
    }
    try {
      await WebViewEventHandler.sendInitData(
        _channel!,
        additionalData: additionalData,
        context: context,
      );
    } catch (e) {
      _initDataSent = false;
      MonitoringServiceHelper.logError('app_webview_send_init_data_error', {
        'error': e.toString(),
      });
    }
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) {
    if (mounted) {
      if (!_pageLoadTracked) {
        _pageLoadTracked = true;
        _args?.onPageLoaded?.call();
      }
      setState(() => _isLoading = false);
    }
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame ?? false) {
      MonitoringServiceHelper.logError('app_webview_error', {
        'error': error.description,
        'url': request.url.toString(),
      });
      if (mounted && !_hasError) {
        _args?.onPageLoadFailed?.call(error.description);
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null) return const SizedBox.shrink();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showAppBar) {
          _closeWebView();
        } else if (_channel != null && !_isPopping) {
          WebViewEventHandler.sendBackPressed(_channel!).catchError((e) {
            MonitoringServiceHelper.logError('app_webview_back_pressed_error', {
              'error': e.toString(),
            });
          });
          _armBackWatchdog();
        } else if (!_isPopping) {
          // No channel to ask (it never attached, or was torn down after load).
          // The host route defers the gesture to this page, so swallowing the
          // press here would strand the runner with a dead back button.
          _closeWebView();
        }
        // In happy flow, web responds by calling closeWebView before the
        // watchdog fires. The watchdog is the fallback for an unresponsive
        // or crashed web page.
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _showAppBar
              ? CommonAppBar(
                  title: Text(args.title),
                  onBackPressed: _closeWebView,
                )
              : null,
          body: Stack(
            children: [
              if (!_hasError && _cookieReady)
                InAppWebView(
                  key: ValueKey(_retryCount),
                  initialUrlRequest: URLRequest(url: WebUri(args.url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    // Allow inline media (e.g. the referrals intro video) to
                    // autoplay with sound without a user gesture. Web code
                    // still opts into audible playback per-component; other
                    // players stay muted by default.
                    mediaPlaybackRequiresUserGesture: false,
                    requestedWithHeaderOriginAllowList: {},
                    transparentBackground: true,
                    webViewAssetLoader: WebViewAssetLoader(
                      domain: WebViewCaptureController.assetDomain,
                      httpAllowed: false,
                      pathHandlers: [
                        CapturePathHandler(
                          path: WebViewCaptureController.capturePath,
                        ),
                      ],
                    ),
                  ),
                  onWebViewCreated: _onWebViewCreated,
                  onPermissionRequest: _onPermissionRequest,
                  onPageCommitVisible: _onPageCommitVisible,
                  onLoadStop: _onLoadStop,
                  onReceivedError: _onReceivedError,
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    _onWebHistoryChanged();
                  },
                  // Debug-only: forward every console.* call from the web
                  // into the Flutter debug output, so `flutter run` shows
                  // the webview's logs. Invaluable for diagnosing bifrost
                  // flows.
                  onConsoleMessage: kDebugMode
                      ? (controller, message) {
                          debugPrint(
                            '[WebView/${message.messageLevel}] ${message.message}',
                          );
                        }
                      : null,
                  // Debug-only: accept self-signed certs from Vite's HTTPS
                  // dev server. In release builds we return null (default
                  // behaviour = reject) — production MUST NOT bypass TLS.
                  onReceivedServerTrustAuthRequest: kDebugMode
                      ? (controller, challenge) async =>
                            ServerTrustAuthResponse(
                              action: ServerTrustAuthResponseAction.PROCEED,
                            )
                      : null,
                ),

              // Loading overlay — hides WebView's initial flash
              if (_isLoading)
                Container(
                  color: Colors.white,
                  child: const Center(child: CupertinoActivityIndicator()),
                ),

              // Error state with retry
              if (_hasError) AppErrorWidget(onRetry: _retry),
            ],
          ),
        ),
      ),
    );
  }
}
