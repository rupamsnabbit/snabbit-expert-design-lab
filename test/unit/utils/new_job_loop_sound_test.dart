import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Tests for the KMP/mqtt-cohort new-job alert re-arm primitives:
/// [ensureNewJobLoopSound], [cancelPendingNewJobLoop], [silenceNewJobAlert], and
/// the [JobOverlayChannel] edge handler that drives them.
///
/// Focus is the START-after-STOP *resurrection veto*: `ensureNewJobLoopSound`
/// writes `'stopped'`, yields for 1s, then starts the loop only if its snapshotted
/// `_newJobLoopRequestId` is still current — a STOP landing inside that window must
/// bump the id and leave the loop dead. That branch returns *before* `loopSound`
/// (Timer.periodic + Provider + audio plugin — untestable glue exercised on-device),
/// so it's asserted here purely via the shared `'stopped'` / `'playing'` file state.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// The hard-stop path calls `NotificationService.cancelAll()`, which reaches the
/// local-notifications platform-interface singleton — a `late` field that isn't
/// registered in tests. Stub it so `cancelAll` is a no-op instead of a LateInit throw.
class _FakeLocalNotifications extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();

  late Directory tempDir;

  setUpAll(() {
    // Stub the plugin channels the hard-stop path touches (audio player + local
    // notifications) so their MissingPluginExceptions can't escape as zone errors.
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('dexterous.com/flutter/local_notifications'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotifications();
  });

  setUp(() {
    // A fresh temp docs dir per test → FileStorage read/writeState hit a real file.
    tempDir = Directory.systemTemp.createTempSync('nj_loop_sound');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> invokeEdge(String method) => messenger.handlePlatformMessage(
        'com.snabbit.runner/job_overlay',
        codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );

  group('ensureNewJobLoopSound', () {
    test('isNewJob:false marks the shared state stopped', () async {
      // Arrange
      await FileStorage.writeState('playing');

      // Act
      await ensureNewJobLoopSound(isNewJob: false);

      // Assert
      expect(await FileStorage.readState(), 'stopped');
    });

    test(
        'a stop landing inside the 1s re-arm vetoes the parked START '
        '(loop is never resurrected)', () async {
      // Arrange
      await FileStorage.writeState('stopped');

      // Act — START snapshots the request id, writes stopped, then yields for 1s.
      final armed = ensureNewJobLoopSound(isNewJob: true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // A STOP lands inside the window and bumps the id.
      cancelPendingNewJobLoop();
      await armed;

      // Assert — the parked re-arm was stale → it returned without writing 'playing'.
      expect(await FileStorage.readState(), 'stopped');
    });
  });

  group('silenceNewJobAlert', () {
    test('marks stopped AND cancels a parked START re-arm', () async {
      // Arrange
      await FileStorage.writeState('stopped');

      // Act — park a START, then silence during its 1s window.
      final armed = ensureNewJobLoopSound(isNewJob: true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await silenceNewJobAlert();
      await armed;

      // Assert — silence's cancelPendingNewJobLoop vetoed the parked START; state stays stopped.
      expect(await FileStorage.readState(), 'stopped');
    });
  });

  group('JobOverlayChannel edges', () {
    test('newJobAlertStop routes to the hard-stop (state -> stopped)',
        () async {
      // Arrange
      JobOverlayChannel.init();
      await FileStorage.writeState('playing');

      // Act
      await invokeEdge('newJobAlertStop');

      // Assert
      expect(await FileStorage.readState(), 'stopped');
    });

    test('newJobAlertStart routes to the re-arm; a following stop vetoes it',
        () async {
      // Arrange
      JobOverlayChannel.init();
      await FileStorage.writeState('stopped');

      // Act — START edge parks the re-arm; a quick STOP edge vetoes it before 1s elapses.
      unawaited(invokeEdge('newJobAlertStart'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await invokeEdge('newJobAlertStop');
      await Future<void>.delayed(const Duration(seconds: 1));

      // Assert — the START reached ensureNewJobLoopSound(true) but was silenced → no resurrection.
      expect(await FileStorage.readState(), 'stopped');
    });
  });
}
