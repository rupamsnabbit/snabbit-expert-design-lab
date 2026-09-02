import 'dart:ui';

import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Fire-and-forget: web asks native to re-fetch `runners/me` after durably
/// changing runner state on the BE (e.g. the tiering-intro ack). [onRefresh]
/// runs the same `runnersMeSetup()` used at launch.
class RefreshRunnerHandler implements BifrostHandler {
  RefreshRunnerHandler({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  String get actionName => WebViewConstants.eventRefreshRunner;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    onRefresh();
    return const BifrostResult.empty();
  }
}
