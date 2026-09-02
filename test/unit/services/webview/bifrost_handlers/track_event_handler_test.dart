import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/analytics_sink.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/track_event_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';

class _TrackCall {
  _TrackCall(this.name, this.properties);
  final String name;
  final Map<String, Object?> properties;
}

class _RecordingSink implements AnalyticsSink {
  final List<_TrackCall> calls = [];

  @override
  Future<void> track(String name, Map<String, Object?> properties) async {
    calls.add(_TrackCall(name, properties));
  }
}

TrackEventHandler _handler(_RecordingSink sink) => TrackEventHandler(
      sink: sink,
      logger: const NullBifrostLogger(),
    );

void main() {
  group('TrackEventHandler', () {
    test('is a fire-and-forget handler', () {
      final h = _handler(_RecordingSink());
      expect(h.pattern, BifrostPattern.fireAndForget);
      expect(h.actionName, 'trackEvent');
    });

    test('forwards a valid event with properties to the sink', () async {
      final sink = _RecordingSink();
      final h = _handler(sink);

      await h.handle({
        'name': 'rate_card_opened',
        'properties': {'source': 'drawer', 'tier': 'gold'},
      });

      expect(sink.calls, hasLength(1));
      expect(sink.calls.single.name, 'rate_card_opened');
      expect(sink.calls.single.properties, {
        'source': 'drawer',
        'tier': 'gold',
      });
    });

    test('forwards with empty properties when the field is missing', () async {
      final sink = _RecordingSink();
      final h = _handler(sink);

      await h.handle({'name': 'app_opened'});

      expect(sink.calls.single.name, 'app_opened');
      expect(sink.calls.single.properties, isEmpty);
    });

    test('ignores properties that are not a map', () async {
      final sink = _RecordingSink();
      final h = _handler(sink);

      await h.handle({'name': 'x', 'properties': 'not a map'});
      await h.handle({'name': 'y', 'properties': 42});
      await h.handle({'name': 'z', 'properties': null});

      expect(sink.calls.map((c) => c.name), ['x', 'y', 'z']);
      for (final c in sink.calls) {
        expect(c.properties, isEmpty);
      }
    });

    test('drops events with missing / empty / non-string name', () async {
      final sink = _RecordingSink();
      final h = _handler(sink);

      await h.handle(const {});
      await h.handle({'name': ''});
      await h.handle({'name': 42});
      await h.handle({'properties': {'a': 1}});

      expect(sink.calls, isEmpty);
    });

    test('returns an empty BifrostResult on both success and validation fail',
        () async {
      final sink = _RecordingSink();
      final h = _handler(sink);

      final success = await h.handle({'name': 'x'});
      final fail = await h.handle(const {});

      expect(success.data, isNull);
      expect(success.error, isNull);
      expect(fail.data, isNull);
      expect(fail.error, isNull);
    });
  });
}
