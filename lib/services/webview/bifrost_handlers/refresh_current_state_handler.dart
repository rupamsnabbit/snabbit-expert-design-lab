import 'dart:ui';

import 'package:snabbit_runner/services/webview/bifrost_handler.dart';

/// Fire-and-forget handler for `refreshCurrentState`. The web calls this
/// after performing an action (e.g. marking attendance) that changes the
/// runner's server-side state, so the native side can fetch fresh data
/// without waiting for the next polling cycle.
class RefreshCurrentStateHandler implements BifrostHandler {
  RefreshCurrentStateHandler({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  String get actionName => 'refreshCurrentState';

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    onRefresh();
    return const BifrostResult.empty();
  }
}
