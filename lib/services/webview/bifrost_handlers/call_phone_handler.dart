import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

typedef CallInitiator = Future<void> Function({
  required String phoneNumber,
  required String callSourceLabel,
});

class CallPhoneHandler implements BifrostHandler {
  CallPhoneHandler({
    CallInitiator? callInitiator,
    this.logger = const MonitoringBifrostLogger(),
  }) : _callInitiator = callInitiator ?? _defaultCallInitiator;

  static final RegExp _phoneFormat = RegExp(r'^[0-9+\-\s()]+$');

  final CallInitiator _callInitiator;
  final BifrostLogger logger;

  @override
  String get actionName => WebViewConstants.eventCallPhone;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final phoneNumber = data['phoneNumber'];
    if (phoneNumber is! String || phoneNumber.isEmpty) {
      logger.logError('webview_call_phone_invalid_data', {
        'data': data.toString(),
      });
      return const BifrostResult.empty();
    }
    if (!_phoneFormat.hasMatch(phoneNumber)) {
      logger.logError('webview_call_phone_invalid_format', {
        'phoneNumber': phoneNumber,
      });
      return const BifrostResult.empty();
    }
    await _callInitiator(
      phoneNumber: phoneNumber,
      callSourceLabel: 'APP_WEB_VIEW',
    );
    return const BifrostResult.empty();
  }

  static Future<void> _defaultCallInitiator({
    required String phoneNumber,
    required String callSourceLabel,
  }) {
    return CallUtils.handleCallInitiation(
      phoneNumber: phoneNumber,
      callSourceLabel: callSourceLabel,
    );
  }
}
