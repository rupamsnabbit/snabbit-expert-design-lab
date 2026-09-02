import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/credentials.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/server_requests/credentials_management_http.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class CredentialsManagementProvider extends ChangeNotifier {
  Credentials? _credentials;
  bool _loading = false;

  Credentials? get credentials => _credentials;

  bool get loading => _loading;

  Future<void> getCredentials() async {
    _loading = true;
    notifyListeners();
    try {
      final response = await CredentialsManagementHttp.getCredentials();
      if (response != null && response.statusCode == 200) {
        _credentials = Credentials.fromJson(response.data);
      } else {
        MonitoringServiceHelper.logDebug("FAILED_TO_FETCH_CREDENTIALS", {
          'response_status_code': response?.statusCode,
          'response_status_message': response?.statusMessage,
          'response_data': response?.data,
        });
        try {
          // wrapped try-catch because context can be null
          showSnackbar(GlobalState().navigatorKey.currentContext!,
              "Failed to get credentials");
        } catch (_) {
          // catch-block intentionally kept empty failure to show snackbar is not operation critical
        }
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        'FAILED_TO_FETCH_CREDENTIALS',
        {
          'error': e.toString(),
        },
        st.toString(),
      );
    }
    _loading = false;
    notifyListeners();
  }
}
