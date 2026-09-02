import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/camera_permission_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/permission_rationale_bottom_sheet.dart';

/// Renders [CameraPermissionBottomSheet] via `showModalBottomSheet` (exactly
/// how the capture flow shows it) and runs [act] once it's on screen, then
/// returns the value the sheet popped with — `null` if still open.
Future<bool?> _showSheet(
  WidgetTester tester, {
  ValueNotifier<bool>? dismissNotifier,
  Future<void> Function()? act,
}) async {
  bool? popped;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await showModalBottomSheet<bool>(
                      context: ctx,
                      isDismissible: false,
                      enableDrag: false,
                      builder: (_) => CameraPermissionBottomSheet(
                        status: PermissionStatus.denied,
                        dismissNotifier: dismissNotifier,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  if (act != null) {
    await act();
    await tester.pumpAndSettle();
  }
  return popped;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // MonitoringServiceHelper (Coralogix) fires on initState/dismiss; stub it.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('cx_flutter_plugin'),
        (call) async => null,
      );

  group('CameraPermissionBottomSheet', () {
    testWidgets(
      'delegates to PermissionRationaleBottomSheet with camera config',
      (tester) async {
        await _showSheet(tester);

        final sheet = tester.widget<PermissionRationaleBottomSheet>(
          find.byType(PermissionRationaleBottomSheet),
        );
        expect(sheet.permission, Permission.camera);
        expect(sheet.icon, Icons.camera_alt_outlined);
        expect(sheet.logPrefix, 'camera_permission_sheet');
        // Preserves the original external-dismiss analytics taxonomy.
        expect(sheet.externalDismissReason, 'cancel_capture');
      },
    );

    testWidgets('renders the camera copy and both action buttons', (
      tester,
    ) async {
      await _showSheet(tester);

      expect(find.text('Camera Permission Required'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Cancel pops the sheet with false', (tester) async {
      final result = await _showSheet(
        tester,
        act: () => tester.tap(find.text('Cancel')),
      );

      expect(result, isFalse);
      expect(find.byType(CameraPermissionBottomSheet), findsNothing);
    });

    testWidgets('external dismissNotifier closes the sheet with false', (
      tester,
    ) async {
      final dismiss = ValueNotifier<bool>(false);
      final result = await _showSheet(
        tester,
        dismissNotifier: dismiss,
        act: () async => dismiss.value = true,
      );

      expect(result, isFalse);
      expect(find.byType(CameraPermissionBottomSheet), findsNothing);
      dismiss.dispose();
    });
  });
}
