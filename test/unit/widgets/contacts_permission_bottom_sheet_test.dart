import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/contacts_permission_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/permission_rationale_bottom_sheet.dart';

/// Renders [ContactsPermissionBottomSheet] via `showModalBottomSheet` (exactly
/// how the `getContacts` flow shows it) and runs [act] once it's on screen,
/// then returns the value the sheet popped with — `null` if still open.
Future<bool?> _showSheet(
  WidgetTester tester, {
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
                      builder: (_) => const ContactsPermissionBottomSheet(
                        status: PermissionStatus.denied,
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

  group('ContactsPermissionBottomSheet', () {
    testWidgets(
      'delegates to PermissionRationaleBottomSheet with contacts config',
      (tester) async {
        await _showSheet(tester);

        final sheet = tester.widget<PermissionRationaleBottomSheet>(
          find.byType(PermissionRationaleBottomSheet),
        );
        expect(sheet.permission, Permission.contacts);
        expect(sheet.icon, Icons.contacts_outlined);
        expect(sheet.logPrefix, 'contacts_permission_sheet');
      },
    );

    testWidgets('renders the contacts copy and both action buttons', (
      tester,
    ) async {
      await _showSheet(tester);

      expect(find.text('Contacts Permission Required'), findsOneWidget);
      expect(find.byIcon(Icons.contacts_outlined), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Cancel pops the sheet with false', (tester) async {
      final result = await _showSheet(
        tester,
        act: () => tester.tap(find.text('Cancel')),
      );

      expect(result, isFalse);
      expect(find.byType(ContactsPermissionBottomSheet), findsNothing);
    });

    testWidgets('hardware back press pops the sheet with false', (
      tester,
    ) async {
      final result = await _showSheet(
        tester,
        act: () async {
          final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
          await widgetsAppState.didPopRoute();
        },
      );

      expect(result, isFalse);
      expect(find.byType(ContactsPermissionBottomSheet), findsNothing);
    });
  });
}
