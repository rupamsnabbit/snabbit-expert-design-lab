import 'package:snabbit_runner/services/webview/analytics_sink.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// FAF handler: web → native → analytics SDKs (MixPanel + CleverTap).
///
/// Web sends `{name: string, properties?: object}`. We validate `name` and
/// fan it out to every configured SDK via the composite sink. Fire-and-forget
/// per the proposal: analytics are non-critical, so we don't make web wait
/// for a response.
///
/// Validation failures are logged and dropped — the web doesn't get a
/// reply either way. No business logic lives in the web side of analytics.
class TrackEventHandler implements BifrostHandler {
  TrackEventHandler({
    // Web event names aren't in the central catalog, so route them with an
    // explicit Mixpanel + CleverTap target.
    this.sink = const KmpWebAnalyticsSink(),
    this.logger = const MonitoringBifrostLogger(),
  });

  final AnalyticsSink sink;
  final BifrostLogger logger;

  @override
  String get actionName => WebViewConstants.eventTrackEvent;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final name = data['name'];
    if (name is! String || name.isEmpty) {
      logger.logError('webview_track_event_invalid_name', {
        'data': data.toString(),
      });
      return const BifrostResult.empty();
    }

    final rawProperties = data['properties'];
    final properties = rawProperties is Map<String, dynamic>
        ? Map<String, Object?>.from(rawProperties)
        : const <String, Object?>{};

    await sink.track(name, properties);
    return const BifrostResult.empty();
  }
}
