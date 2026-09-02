import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/partner_home/lunch_slots_banner.dart';

void main() {
  Widget host({required VoidCallback onUpdate}) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: LunchSlotsBanner(
          title: 'Book your lunch slot for next week',
          ctaLabel: 'Select',
          onUpdate: onUpdate,
        ),
      ),
    ),
  );

  testWidgets('renders the title and the Select CTA', (tester) async {
    await tester.pumpWidget(host(onUpdate: () {}));

    expect(find.text('Book your lunch slot for next week'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
  });

  testWidgets('tapping the strip body (not the CTA) invokes onUpdate', (
    tester,
  ) async {
    // The whole banner is the tap target, not just the button — tapping the
    // title must reach the same destination.
    var taps = 0;
    await tester.pumpWidget(host(onUpdate: () => taps++));

    await tester.tap(find.text('Book your lunch slot for next week'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tapping the CTA invokes onUpdate', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onUpdate: () => taps++));

    await tester.tap(find.text('Select'));

    expect(taps, 1);
  });

  group('LunchSlotsBannerSlot (page dock)', () {
    final tracked = <String>[];

    setUp(() {
      // The provider ctor + the tap's analytics hop touch platform channels
      // that don't exist in a unit test — stub them (same list as the
      // provider test).
      tracked.clear();
      for (final name in const [
        'cx_flutter_plugin',
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
      }
      // Capture analytics so impression/CTA events are assertable.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.snabbit.runner/analytics'),
            (call) async {
              if (call.method == 'track') {
                tracked.add((call.arguments as Map)['name'] as String);
              }
              return null;
            },
          );
    });

    Widget slotHost(RunnerRtDataProvider rtData) => MultiProvider(
      providers: [
        ChangeNotifierProvider<RunnerRtDataProvider>.value(value: rtData),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(fetcher: (_) async => null),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          routes: {
            AppWebViewPage.routeName: (_) =>
                const Scaffold(body: Text('webview-shell')),
          },
          home: const Scaffold(body: LunchSlotsBannerSlot()),
        ),
      ),
    );

    RunnerRtDataProvider makeRtData() => RunnerRtDataProvider(
      periodLeave: PeriodLeaveProvider(),
      userProfile: UserProfileProvider(),
    );

    testWidgets('renders nothing while the flag is off', (tester) async {
      await tester.pumpWidget(slotHost(makeRtData()));

      expect(find.byType(LunchSlotsBanner), findsNothing);
    });

    testWidgets('flag flip shows the banner with the fallback copy', (
      tester,
    ) async {
      final rtData = makeRtData();
      await tester.pumpWidget(slotHost(rtData));

      rtData.showLunchSelection = true;
      rtData.notifyListeners();
      await tester.pump();

      expect(find.text('Book your lunch slot for next week'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('tapping the strip body opens the lunch-slots webview', (
      tester,
    ) async {
      final rtData = makeRtData()..showLunchSelection = true;
      await tester.pumpWidget(slotHost(rtData));

      await tester.tap(find.text('Book your lunch slot for next week'));
      await tester.pumpAndSettle();

      expect(find.text('webview-shell'), findsOneWidget);
    });

    testWidgets('Select opens the lunch-slots webview route', (tester) async {
      final rtData = makeRtData()..showLunchSelection = true;
      await tester.pumpWidget(slotHost(rtData));

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('webview-shell'), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text('webview-shell')))!;
      final args = route.settings.arguments! as WebViewArgs;
      // RC is uninitialised in tests, so the path resolves to the baked-in default.
      expect(args.url, endsWith('/v1/lunch'));
      expect(args.title, 'Lunch Slots');
      // Slot selection mutates `show_lunch_selection`, so the webview must ask
      // for a current_state refresh as it closes — otherwise the runner returns
      // to a home still showing the banner they just acted on.
      expect(args.refreshCurrentStateOnClose, isTrue);
    });
  });
}
