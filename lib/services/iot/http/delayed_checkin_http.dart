import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

class DelayedCheckinHttp {
  static Future<Response?> submitSupportDisposition({
    required int runnerJobId,
    required int jobId,
    required int runnerId,
    required String dispositionTag,
    required String dispositionMessage,
    Map<String, dynamic>? headers,
  }) async {
    if (runnerJobId <= 0 || jobId <= 0 || runnerId <= 0) {
      FirebaseCrashlytics.instance.recordError(
        'submitSupportDisposition invoked with invalid IDs',
        null,
        reason: 'submitSupportDisposition_invalid_ids',
        information: [
          'runnerJobId=$runnerJobId',
          'jobId=$jobId',
          'runnerId=$runnerId',
        ],
        fatal: false,
      );
      return null;
    }
    if (dispositionTag.isEmpty) {
      FirebaseCrashlytics.instance.recordError(
        'submitSupportDisposition invoked with empty dispositionTag',
        null,
        reason: 'submitSupportDisposition_empty_tag',
        fatal: false,
      );
      return null;
    }
    try {
      final ameyoSupport = RemoteConfigService.instance.getBool(
        RemoteConfigKeys.ameyoSupport,
        defaultValue: false,
      );
      return await HttpService().post(
        GlobalState()
            .serverPath('api/v1/runner_job/penalty/$runnerJobId/disposition'),
        data: {
          'job_id': jobId,
          'runner_id': runnerId,
          'disposition_tag': dispositionTag,
          'disposition_message': dispositionMessage,
        },
        queryParameters: {'ameyo_support': ameyoSupport},
        headers: headers ?? {},
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'submitSupportDisposition',
        fatal: false,
      );
      MonitoringServiceHelper.logError('submitSupportDisposition failed', {'error': e.toString()});
      return null;
    }
  }
}
