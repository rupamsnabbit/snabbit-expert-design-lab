import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/iot/http/iot_http.dart';

/// Guards [IotHttp.classifyNetworkErrorMessage] — fragile string-matching over
/// the messages Dio produces (HttpService rethrows DioException as
/// `Exception(e.message)`, so the type is lost and the message is all we have).
/// The strings below are the EXACT messages observed in Coralogix for the IoT
/// upload path, so a regression here would silently empty `error_kind` again.
void main() {
  group('IotHttp.classifyNetworkErrorMessage', () {
    test('DNS lookup failure (#1 cause in prod)', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            "Exception: The connection errored: Failed host lookup: 'api-expert.snabbit.com' This indicates an error which most likely cannot be solved by the library."),
        'dns_failure',
      );
    });

    test('connect timeout', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The request connection took longer than 0:00:10.000000 and it was aborted. To get rid of this exception, try raising the RequestOptions.connectTimeout above the duration of 0:00:10.000000 or improve the response time of the server.'),
        'timeout_connect',
      );
    });

    test('receive timeout (must win over the generic "took longer")', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The request took longer than 0:00:10.000000 to receive data. It was aborted. To get rid of this exception, try raising the RequestOptions.receiveTimeout above the duration of 0:00:10.000000 or improve the response time of the server.'),
        'timeout_receive',
      );
    });

    test('send timeout', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The request took longer than 0:00:10.000000 to send data. It was aborted.'),
        'timeout_send',
      );
    });

    test('connection reset (specific wins over generic "connection errored")',
        () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The connection errored: Connection reset by peer This indicates an error which most likely cannot be solved by the library.'),
        'connection_reset',
      );
    });

    test('connection abort (software caused)', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The connection errored: Software caused connection abort This indicates an error which most likely cannot be solved by the library.'),
        'connection_aborted',
      );
    });

    test('connection refused', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The connection errored: Connection refused This indicates an error which most likely cannot be solved by the library.'),
        'connection_refused',
      );
    });

    test('no route to host', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The connection errored: No route to host This indicates an error which most likely cannot be solved by the library.'),
        'no_route_to_host',
      );
    });

    test('generic connection failure falls back to connection_error', () {
      expect(
        IotHttp.classifyNetworkErrorMessage(
            'Exception: The connection errored: Connection failed This indicates an error which most likely cannot be solved by the library.'),
        'connection_error',
      );
    });

    test('bare / unrecognized exception → unknown', () {
      expect(IotHttp.classifyNetworkErrorMessage('Exception'), 'unknown');
      expect(
        IotHttp.classifyNetworkErrorMessage('Some unexpected thing happened'),
        'unknown',
      );
    });
  });
}
