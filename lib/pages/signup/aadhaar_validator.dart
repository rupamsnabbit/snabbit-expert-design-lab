import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hybrid_flutter/hybrid_callback.dart';
import 'package:hybrid_flutter/hybrid_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/credentials.dart';
import 'package:snabbit_runner/providers/credentials_management_provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'dart:convert';

import '../../services/monitoring/monitoring_service_helper.dart';

class AadhaarValidator extends StatefulWidget {
  static const String routeName = "/aadhaar-validator";

  const AadhaarValidator({
    super.key,
  });

  @override
  State<AadhaarValidator> createState() => _AadhaarValidatorState();
}

class _AadhaarValidatorState extends State<AadhaarValidator>
    implements Hybridcallback {
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late DocumentsProvider documentsProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  bool init = true;
  HybridViewController? hybridViewController;
  late CredentialsManagementProvider credentialsManagementProvider;
  Document? aadhaarFrontDocument;
  Document? aadhaarBackDocument;
  bool loading = true;
  String? _url;
  String? _username;
  String? _password;
  String? _organizationId;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      documentsProvider = Provider.of<DocumentsProvider>(context, listen: true);
      credentialsManagementProvider =
          Provider.of<CredentialsManagementProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      aadhaarFrontDocument = userProfileProvider.getAadharFrontDocument();
      aadhaarBackDocument = userProfileProvider.getAadharBackDocument();
      Future(() async {
        await _fetchCredentials();
        if (!mounted) return;
        await _buildUrl();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchCredentials() async {
    try {
      // Track credentials fetch
      Trace? credentialsTrace;
      try {
        credentialsTrace = FirebasePerformance.instance
            .newTrace('aadhaar_details_credentials_fetch');
        credentialsTrace.start();
      } catch (_) {}
      await credentialsManagementProvider.getCredentials();
      try {
        credentialsTrace?.stop();
      } catch (_) {}
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        'FAILED_TO_FETCH_AADHAAR_CREDENTIALS',
        {
          'error': e.toString(),
        },
        st.toString(),
      );
    }
  }

  Credentials? get credentials => credentialsManagementProvider.credentials;

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionData? get currentQuestion =>
      onboardingQuestionResponse?.questions?.first;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int? get questionId => currentQuestion?.id;

  void _goBackToPreviousQuestion() {
    if (onboardingQuestionResponse?.moduleId != null) {
      onboardingStepsProvider.goBackToPreviousQuestion(
        context,
        onboardingQuestionResponse!.moduleId!,
      );
    }
  }

  Future<void> _buildUrl() async {
    try {
      _username = credentials?.aadhaarValidationUsername;
      _password = credentials?.aadhaarValidationPassword;
      _organizationId = credentials?.aadhaarValidationOrganizationId;
      if (_username == null || _password == null || _organizationId == null) {
        MonitoringServiceHelper.logDebug("PERFIOS_CREDENTIALS_INCOMPLETE", {
          'env': GlobalState().currentEnv.name,
          'has_username': (_username != null).toString(),
          'has_password': (_password != null).toString(),
          'has_organization_id': (_organizationId != null).toString(),
          'credentials_null': (credentials == null).toString(),
        });
        if (!mounted) return;
        setState(() {
          loading = false;
        });
        return;
      }
      setState(() {
        loading = true;
      });
      final requestEnv = GlobalState().currentEnv.name == "PROD" ? "" : "-test";
      // Raw Dio (third-party Perfios endpoint — must NOT carry Snabbit auth).
      // Attach the debug network inspector so the call shows up in Chucker.
      final dio = Dio();
      DebugNetworkInspector.instance.attach(dio);
      final response = await dio.post(
        "https://hub$requestEnv.perfios.ai/oauth2/token",
        options: Options(headers: {
          "username": _username,
          "password": _password,
          "x-organization-id": _organizationId,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        final authorizationToken = data?["access_token"] ?? "";
        if (authorizationToken.isNotEmpty) {
          _url =
              "https://hub$requestEnv.perfios.ai/ssp/aadhaar-xml/?authorization=$authorizationToken&x-organization-id=$_organizationId";
          loading = false;
          setState(() {});
          MonitoringServiceHelper.logDebug("PERFIOS_URL_CREATION_SUCCESSFUL", {
            'env': GlobalState().currentEnv.name,
            'url': _url,
          });
        } else {
          MonitoringServiceHelper.logDebug("PERFIOS_AUTH_TOKEN_INVALID", {
            'env': GlobalState().currentEnv.name,
          });
          setState(() {
            loading = false;
          });
        }
      } else {
        MonitoringServiceHelper.logDebug("PERFIOS_TOKEN_GENERATION_FAILED", {
          'env': GlobalState().currentEnv.name,
          'response_status_code': response.statusCode,
          'response_status_message': response.statusMessage,
          'response_data': response.data,
        });
        setState(() {
          loading = false;
        });
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        "PERFIOS_URL_CREATION_FAILED",
        {
          'env': GlobalState().currentEnv.name,
          'error': e.toString(),
        },
        st.toString(),
      );
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  bool _isConfigValid() {
    return _username != null && _password != null && _organizationId != null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackToPreviousQuestion();
      },
      child: SafeArea(
        child: Material(
          child: credentialsManagementProvider.loading || loading
              ? Center(
                  child: CupertinoActivityIndicator(),
                )
              : !_isConfigValid()
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Text("Aadhaar Validation URL  not found")),
                          SizedBox(
                            height: 16.h,
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                loading = true;
                              });
                              await GlobalState().setAppConfig();
                              if (!mounted) return;
                              await _fetchCredentials();
                              if (!mounted) return;
                              await _buildUrl();
                            },
                            child: Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : (_url == null || _url!.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(child: Text("Something went wrong")),
                              SizedBox(
                                height: 16.h,
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    loading = true;
                                  });
                                  await _fetchCredentials();
                                  if (!mounted) return;
                                  await _buildUrl();
                                },
                                child: Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : Scaffold(
                          appBar: AppBar(
                            leading: InkWell(
                              onTap: _goBackToPreviousQuestion,
                              child: const Icon(
                                Icons.arrow_back_ios_rounded,
                                color: Color(0xFF6D7783),
                              ),
                            ),
                          ),
                          body: HybridView(
                            onViewCreated: (HybridViewController controller) {
                              hybridViewController = controller;
                            },
                            callback: this,
                            url: _url ?? '',
                          ),
                        ),
        ),
      ),
    );
  }

  @override
  void onError(String errorMessage) async {
    if (!mounted) return;

    // Submit the Perfios error response to backend
    // Backend will return next screen to navigate to
    if (sessionId != null && questionId != null) {
      await onboardingStepsProvider.submitPerfiosValidationResponse(
        context: context,
        jsonString: errorMessage,
        sessionId: sessionId!,
        questionId: questionId!,
        onSuccess: () {
          // Navigation handled by provider
        },
        onError: (backendError) async {
          if (mounted) {
            await _showResultDialog("An Error Occurred",
                "Failed to save validation result: $backendError");
          }
        },
      );
    }
  }

  @override
  void onEvent(String eventJsonString) {}

  @override
  void onShutdown(String shutdownJsonString) async {
    //triggered on successful validation
    if (!mounted) return;

    if (sessionId != null && questionId != null) {
      await onboardingStepsProvider.submitPerfiosValidationResponse(
        context: context,
        jsonString: shutdownJsonString,
        sessionId: sessionId!,
        questionId: questionId!,
        onSuccess: () {
          // Navigation handled by provider
        },
        onError: (error) async {
          if (mounted) {
            await _showResultDialog("Submission Error",
                "Aadhaar validation completed, but failed to save: $error");
          }
        },
      );
    }
  }

  // New helper method to show the dialog
  Future<void> _showResultDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                // This closes the dialog
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then(
      (value) {
        Navigator.pop(context);
      },
    );
  }
}

/// Dart model for a successful Aadhaar API response containing user demographic data.
class AadhaarSuccessfulResponse {
  final String? name;
  final String? dob;
  final String? gender;

  // Full Address and Individual Address Components
  final String? address;
  final String? addressCareof;
  final String? addressHouse;
  final String? addressLoc;
  final String? addressStreet;
  final String? addressLandmark;
  final String? addressVtc; // Village Town City
  final String? addressPc; // Pin Code
  final String? addressPo; // Post Office
  final String? addressSubdist;
  final String? addressDist;
  final String? addressState;
  final String? addressCountry;

  // Verification/Technical Details
  final String? maskedAadhaarNumber;
  final String? mobileHash;
  final String? emailHash;
  final bool? isXmlVerify;
  final String? imagebase64;
  final String? zipFileBase64;

  // Response Metadata
  final int? code;
  final bool? isError;
  final String? requestId;
  final String? genDate;
  final String? sharecode;
  final String? caseId;

  AadhaarSuccessfulResponse({
    this.name,
    this.dob,
    this.gender,
    this.address,
    this.addressCareof,
    this.addressHouse,
    this.addressLoc,
    this.addressStreet,
    this.addressLandmark,
    this.addressVtc,
    this.addressPc,
    this.addressPo,
    this.addressSubdist,
    this.addressDist,
    this.addressState,
    this.addressCountry,
    this.maskedAadhaarNumber,
    this.mobileHash,
    this.emailHash,
    this.isXmlVerify,
    this.imagebase64,
    this.zipFileBase64,
    this.code,
    this.isError,
    this.requestId,
    this.genDate,
    this.sharecode,
    this.caseId,
  });

  /// Factory constructor to create an instance from a JSON map.
  factory AadhaarSuccessfulResponse.fromJson(Map<dynamic, dynamic> json) {
    return AadhaarSuccessfulResponse(
      name: json['name'],
      dob: json['dob'],
      gender: json['gender'],
      address: json['address'],
      addressCareof: json['address_careof'],
      addressHouse: json['address_house'],
      addressLoc: json['address_loc'],
      addressStreet: json['address_street'],
      addressLandmark: json['address_landmark'],
      addressVtc: json['address_vtc'],
      addressPc: json['address_pc'],
      addressPo: json['address_po'],
      addressSubdist: json['address_subdist'],
      addressDist: json['address_dist'],
      addressState: json['address_state'],
      addressCountry: json['address_country'],
      maskedAadhaarNumber: json['maskedAadhaarNumber'],
      mobileHash: json['mobileHash'],
      emailHash: json['emailHash'],
      isXmlVerify: json['isXmlVerify'],
      imagebase64: json['imagebase64'],
      zipFileBase64: json['zipFileBase64'],
      code: json['code'],
      isError: json['isError'],
      requestId: json['requestId'],
      genDate: json['genDate'],
      sharecode: json['sharecode'],
      caseId: json['caseId'],
    );
  }
}

class AadhaarErrorResponse {
  final String? requestId;
  final String? caseId;
  final bool? isError;
  final bool? exitByUser;
  final int? errorType;
  final String? message;

  AadhaarErrorResponse({
    this.requestId,
    this.caseId,
    this.isError,
    this.exitByUser,
    this.errorType,
    this.message,
  });

  /// Factory constructor to create an instance from a JSON map.
  factory AadhaarErrorResponse.fromJson(Map<dynamic, dynamic> json) {
    return AadhaarErrorResponse(
      requestId: json['requestId'],
      caseId: json['caseId'],
      isError: json['isError'],
      exitByUser: json['exitByUser'],
      errorType: json['errorType'],
      message: json['message'],
    );
  }
}
