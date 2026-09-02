import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hybrid_flutter/hybrid_callback.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/perfios_aadhaar_data.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_webview.dart';
import 'package:snabbit_runner/providers/credentials_management_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/server_requests/aadhaar_reverification_services.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';

/// Thin host for the Perfios Aadhaar `HybridView`, pushed by
/// [OpenPerfiosAadhaarHandler] on the embedded web app's request.
///
/// Fetches Perfios credentials, exchanges them for the SSP URL, mounts the
/// hybrid webview, then pops with a structured result the bifrost handler
/// forwards back to the web. Reuses [AadhaarReverificationWebView] for the
/// scaffold + `HybridView` wiring so the re-KYC flow and this bridge share
/// one implementation.
///
/// No `routeName` / entry in `main.dart`'s routes map: this page is only ever
/// pushed inline by the handler with a typed `MaterialPageRoute` so it can
/// return a `Map<String, dynamic>?` result. It's not a nav-by-name screen.
///
/// Pop shape:
///   - Success: `{ demographics: {...}, rawPerfiosJson: "..." }`
///   - Failure: `{ __error: true, code: <BifrostErrorCode>, message }`
class PerfiosAadhaarBridgePage extends StatefulWidget {
  const PerfiosAadhaarBridgePage({super.key});

  @override
  State<PerfiosAadhaarBridgePage> createState() =>
      _PerfiosAadhaarBridgePageState();
}

class _PerfiosAadhaarBridgePageState extends State<PerfiosAadhaarBridgePage>
    implements Hybridcallback {
  String? _url;
  bool _completed = false;
  bool _init = true;

  @override
  void didChangeDependencies() {
    if (_init) {
      _init = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _start() async {
    final creds = context.read<CredentialsManagementProvider>();
    await creds.getCredentials();
    if (!mounted || _completed) return;

    final username = creds.credentials?.aadhaarValidationUsername;
    final password = creds.credentials?.aadhaarValidationPassword;
    final organizationId = creds.credentials?.aadhaarValidationOrganizationId;
    if (username == null || password == null || organizationId == null) {
      _popError(
        BifrostErrorCodes.perfiosCredentialsUnavailable,
        'Perfios credentials unavailable',
      );
      return;
    }

    final url = await AadhaarReverificationServices.fetchPerfiosAadhaarXmlUrl(
      username: username,
      password: password,
      organizationId: organizationId,
    );
    if (!mounted || _completed) return;
    if (url == null || url.isEmpty) {
      _popError(
        BifrostErrorCodes.perfiosUrlUnavailable,
        'Could not build Perfios URL',
      );
      return;
    }
    setState(() => _url = url);
  }

  void _popResult(Map<String, dynamic> result) {
    if (_completed) return;
    _completed = true;
    Navigator.of(context).pop(result);
  }

  void _popError(String code, String message) {
    _popResult({
      '__error': true,
      'code': code,
      'message': message,
    });
  }

  void _onCancel() {
    _popError(
      BifrostErrorCodes.userCancelled,
      'User cancelled Perfios flow',
    );
  }

  @override
  void onEvent(String eventJsonString) {}

  @override
  void onShutdown(String shutdownJsonString) {
    if (!mounted || _completed) return;

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(shutdownJsonString);
      if (raw is Map) decoded = Map<String, dynamic>.from(raw);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'PERFIOS_BRIDGE_PARSE_FAILED',
        {'error': e.toString()},
      );
    }
    if (decoded == null) {
      _popError(
        BifrostErrorCodes.perfiosError,
        'Could not parse Perfios payload',
      );
      return;
    }

    if (decoded['exitByUser'] == true) {
      _popError(BifrostErrorCodes.userCancelled, 'User exited Perfios');
      return;
    }
    if (decoded['isError'] == true) {
      _popError(BifrostErrorCodes.perfiosError, 'Perfios reported an error');
      return;
    }

    final data = PerfiosAadhaarData.fromJson(decoded);
    if (!data.hasAnyData) {
      _popError(
        BifrostErrorCodes.perfiosNoData,
        'Perfios returned no demographic data',
      );
      return;
    }

    _popResult({
      'demographics': {
        if (data.name != null) 'name': data.name,
        if (data.dob != null) 'dob': data.dob,
        if (data.gender != null) 'gender': data.gender,
        if (data.address != null) 'address': data.address,
        if (data.maskedAadhaarNumber != null)
          'maskedAadhaarNumber': data.maskedAadhaarNumber,
      },
      'rawPerfiosJson': shutdownJsonString,
    });
  }

  @override
  void onError(String errorMessage) {
    if (!mounted || _completed) return;
    MonitoringServiceHelper.logWarning(
      'PERFIOS_BRIDGE_HYBRID_ERROR',
      {'error': errorMessage},
    );
    _popError(BifrostErrorCodes.perfiosError, errorMessage);
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onCancel,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return AadhaarReverificationWebView(
      url: _url!,
      callback: this,
      onCancel: _onCancel,
    );
  }
}
