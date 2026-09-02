import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// DEBUG-ONLY QA network debugging. Routes Dart/Dio HTTPS through the device's
/// manual Wi-Fi proxy and trusts its MITM certificate, so QA can inspect and edit
/// traffic in Charles / Proxyman / mitmproxy.
///
/// Why this exists: Dart's [HttpClient] (which Dio uses) ignores BOTH the Android
/// `network_security_config` and the system Wi-Fi proxy — so, unlike OkHttp/Ktor on
/// the KMP side (which pick both up automatically), it needs an explicit
/// [HttpOverrides]. This is:
///  - gated on [kDebugMode] (never behaviour a release build ships), and
///  - a no-op unless a proxy is actually configured, so an un-proxied debug build
///    still validates certificates normally.
///
/// The proxy host:port comes from the device Wi-Fi proxy, read natively (see
/// MainActivity `com.snabbit.runner/qa_proxy`) so QA sets it in ONE place.
Future<void> installQaProxyIfDebug() async {
  if (!kDebugMode) return;
  String? proxy;
  try {
    proxy = await const MethodChannel('com.snabbit.runner/qa_proxy')
        .invokeMethod<String>('getHttpProxy')
        .timeout(const Duration(seconds: 2));
  } catch (e) {
    MonitoringServiceHelper.logInfo(
      'qa_proxy_lookup_skipped',
      {'error': e.toString()},
    );
    return;
  }
  if (proxy == null || proxy.isEmpty) return; // not proxied → normal validation
  HttpOverrides.global = _QaProxyHttpOverrides(proxy);
  MonitoringServiceHelper.logInfo('qa_proxy_installed', {'proxy': proxy});
}

class _QaProxyHttpOverrides extends HttpOverrides {
  _QaProxyHttpOverrides(this._proxy);

  final String _proxy; // "host:port"

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // DEBUG ONLY: accept the proxy's MITM root so Charles/Proxyman can decrypt.
      // Safe because this override is only installed in kDebugMode with a proxy set.
      ..badCertificateCallback = ((cert, host, port) => true)
      ..findProxy = ((uri) => 'PROXY $_proxy');
  }
}
