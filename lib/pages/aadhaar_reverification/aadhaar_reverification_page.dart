import 'package:flutter/material.dart';
import 'package:hybrid_flutter/hybrid_callback.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_intro_view.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_loading_view.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_result_view.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_review_view.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_webview.dart';
import 'package:snabbit_runner/providers/aadhaar_reverification_provider.dart';
import 'package:snabbit_runner/providers/credentials_management_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/server_requests/aadhaar_reverification_services.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Self-contained Aadhaar re-KYC flow opened from the drawer or the suspended
/// screen. Phases (intro → loading → Perfios webview → review → result) are
/// driven by [AadhaarReverificationProvider]; the Perfios webview wiring is a
/// minimal copy of the onboarding `AadhaarValidator` so that flow stays
/// untouched.
class AadhaarReverificationPage extends StatefulWidget {
  static const String routeName = "/aadhaar-reverification";

  const AadhaarReverificationPage({super.key});

  @override
  State<AadhaarReverificationPage> createState() =>
      _AadhaarReverificationPageState();
}

class _AadhaarReverificationPageState extends State<AadhaarReverificationPage>
    implements Hybridcallback {
  String? _url;
  bool _credsError = false;
  bool _init = true;

  @override
  void didChangeDependencies() {
    if (_init) {
      _init = false;
      // Clear any state left over from a previous entry into the flow.
      final reKyc = context.read<AadhaarReverificationProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reKyc.reset();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _start() async {
    final reKyc = context.read<AadhaarReverificationProvider>();
    final credsProvider = context.read<CredentialsManagementProvider>();
    MixpanelSetup.logEvent(TrackingEvents.aadhaarRekycStarted, const {});
    reKyc.goToLoading();
    setState(() {
      _credsError = false;
      _url = null;
    });
    await credsProvider.getCredentials();
    if (!mounted) return;
    await _buildUrl(credsProvider);
    if (!mounted) return;
    if (_url != null && _url!.isNotEmpty) {
      reKyc.goToWebview();
    } else {
      setState(() => _credsError = true);
    }
  }

  /// Resolves the Perfios webview URL via the service (which does the external
  /// OAuth token exchange). Networking lives in the service, not the widget.
  Future<void> _buildUrl(CredentialsManagementProvider credsProvider) async {
    final creds = credsProvider.credentials;
    final username = creds?.aadhaarValidationUsername;
    final password = creds?.aadhaarValidationPassword;
    final organizationId = creds?.aadhaarValidationOrganizationId;
    if (username == null || password == null || organizationId == null) {
      MonitoringServiceHelper.logDebug(
        'AADHAAR_REKYC_CREDENTIALS_INCOMPLETE',
        {
          'env': GlobalState().currentEnv.name,
          'has_username': (username != null).toString(),
          'has_password': (password != null).toString(),
          'has_organization_id': (organizationId != null).toString(),
          'credentials_null': (creds == null).toString(),
        },
      );
      return;
    }
    _url = await AadhaarReverificationServices.fetchPerfiosAadhaarXmlUrl(
      username: username,
      password: password,
      organizationId: organizationId,
    );
  }

  Future<void> _confirmAndSubmit() async {
    // Capture provider refs before the async gap to avoid using context across
    // an await. On `verified` the backend reactivates the runner; we only
    // refresh so the updated state (unsuspended / entry-removed) renders.
    final reKyc = context.read<AadhaarReverificationProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final rtData = context.read<RunnerRtDataProvider>();

    await reKyc.submit(onVerified: () async {
      await userProfileProvider.runnersMeSetup();
      try {
        await rtData.fetchDataNow();
      } catch (e) {
        MonitoringServiceHelper.logError(
          'AADHAAR_REKYC_REFRESH_FAILED',
          {'error': e.toString()},
        );
      }
    });

    final status = reKyc.result?.status ?? 'error';
    MixpanelSetup.logEvent(
        TrackingEvents.aadhaarRekycResult, {'status': status});
  }

  void _onRetry() {
    context.read<AadhaarReverificationProvider>().retry();
    _start();
  }

  void _onDone() {
    Navigator.of(context).pop();
  }

  /// Back-press / cancel from inside the Perfios webview → treat as an
  /// interrupted verification (retryable result) rather than a dead-end.
  void _onWebviewCancel() {
    context.read<AadhaarReverificationProvider>().onPerfiosFailed();
  }

  @override
  void onEvent(String eventJsonString) {}

  @override
  void onShutdown(String shutdownJsonString) {
    if (!mounted) return;
    context.read<AadhaarReverificationProvider>().onPerfiosSuccess(
          shutdownJsonString,
        );
  }

  @override
  void onError(String errorMessage) {
    if (!mounted) return;
    MonitoringServiceHelper.logWarning(
      'AADHAAR_REKYC_PERFIOS_ERROR',
      {'error': errorMessage},
    );
    context.read<AadhaarReverificationProvider>().onPerfiosFailed();
  }

  @override
  Widget build(BuildContext context) {
    final reKyc = context.watch<AadhaarReverificationProvider>();

    switch (reKyc.phase) {
      case ReKycPhase.intro:
        return AadhaarReverificationIntroView(onStart: _start);
      case ReKycPhase.loading:
        return AadhaarReverificationLoadingView(
          credsError: _credsError,
          onRetry: _start,
        );
      case ReKycPhase.webview:
        return AadhaarReverificationWebView(
          url: _url ?? '',
          callback: this,
          onCancel: _onWebviewCancel,
        );
      case ReKycPhase.review:
      case ReKycPhase.submitting:
        return AadhaarReverificationReviewView(
          // reviewData is always non-null once the flow reaches review/submit
          // (onPerfiosSuccess only enters review for a payload that has data).
          data: reKyc.reviewData!,
          submitting: reKyc.phase == ReKycPhase.submitting,
          onConfirm: _confirmAndSubmit,
        );
      case ReKycPhase.result:
        return AadhaarReverificationResultView(
          result: reKyc.result,
          error: reKyc.error,
          canRetry: reKyc.canRetry,
          onRetry: _onRetry,
          onDone: _onDone,
        );
    }
  }
}
