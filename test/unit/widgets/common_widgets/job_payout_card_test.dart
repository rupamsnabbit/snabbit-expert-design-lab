import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/job_payout_card.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

PayoutLine _line({
  required String key,
  required String defaultText,
  NudgeLabel? subtitle,
  String? pillText,
  String? iconUrl,
  int? amount,
}) =>
    PayoutLine(
      title: NudgeLabel(key: key, defaultText: defaultText),
      subtitle: subtitle,
      pillText: pillText,
      iconUrl: iconUrl,
      amount: amount,
    );

/// Find a [Text.rich] / [RichText] whose composed plain text contains
/// [substring]. `find.text` only matches plain `Text` widgets.
Finder _richContaining(String substring) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(substring),
  );
}

void main() {
  group('JobPayoutCard', () {
    testWidgets('renders nothing when payoutInfo is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutCard(
          payoutInfo: null,
          headerText: 'You Will Earn',
        ),
      ));

      expect(find.text('You Will Earn'), findsNothing);
    });

    testWidgets('renders header and total earning', (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutCard(
          payoutInfo: PayoutInfo(totalEarning: 150),
          headerText: 'You Will Earn',
        ),
      ));

      expect(find.text('You Will Earn'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
    });

    testWidgets('renders generic breakdown rows with pill + amount',
        (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 290,
            breakdown: [
              _line(
                  key: 'work',
                  defaultText: 'Work',
                  pillText: '1 hr',
                  amount: 250),
              _line(
                  key: 'ot_label',
                  defaultText: 'OT',
                  pillText: '15 min',
                  amount: 40),
            ],
          ),
          headerText: 'You Will Earn',
        ),
      ));

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('1 hr'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      expect(find.text('OT'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
    });

    testWidgets('omits pill when pill_text absent', (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 100,
            breakdown: [
              _line(
                  key: 'summer_bonus',
                  defaultText: 'Summer Bonus',
                  amount: 50),
            ],
          ),
          headerText: 'You Earned',
        ),
      ));

      expect(find.text('Summer Bonus'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
    });

    testWidgets('renders pending check-in row (info tint) when no actual time',
        (tester) async {
      final scheduled = DateTime.now().add(const Duration(minutes: 30));
      final pillTime = formatPayoutCheckInTimeDisplay(scheduled)!;
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            breakdown: [
              _line(
                  key: 'work',
                  defaultText: 'Work',
                  pillText: '1 hr',
                  amount: 120),
            ],
            checkInAmount: 30,
            checkInTime: scheduled,
          ),
          headerText: 'You Will Earn',
        ),
      ));

      expect(_richContaining('Check In by $pillTime'), findsOneWidget);
      expect(find.text('₹30'), findsOneWidget);
    });

    testWidgets('renders early check-in (success tint) when actual ≤ scheduled',
        (tester) async {
      final scheduled = DateTime(2030, 6, 15, 19, 45);
      final actual = scheduled.subtract(const Duration(minutes: 2));
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            checkInAmount: 30,
            checkInTime: scheduled,
            actualCheckInTime: actual,
          ),
          headerText: 'You Earned',
        ),
      ));

      expect(_richContaining('Checked In 2 min early'), findsOneWidget);
    });

    testWidgets('renders late check-in (no tint, red bold) when actual > scheduled',
        (tester) async {
      final scheduled = DateTime(2030, 6, 15, 19, 45);
      final actual = scheduled.add(const Duration(minutes: 5));
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            checkInAmount: 0,
            checkInTime: scheduled,
            actualCheckInTime: actual,
          ),
          headerText: 'You Earned',
        ),
      ));

      expect(_richContaining('Checked In 5 min late'), findsOneWidget);
    });

    testWidgets('on-time (actual == scheduled) renders 0 min early',
        (tester) async {
      final scheduled = DateTime(2030, 6, 15, 19, 45);
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            checkInAmount: 30,
            checkInTime: scheduled,
            actualCheckInTime: scheduled,
          ),
          headerText: 'You Earned',
        ),
      ));

      expect(_richContaining('Checked In 0 min early'), findsOneWidget);
    });

    testWidgets('omits check-in row when checkInAmount is null', (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 250,
            breakdown: [
              _line(
                  key: 'work',
                  defaultText: 'Work',
                  pillText: '1 hr',
                  amount: 250),
            ],
          ),
          headerText: 'You Will Earn',
        ),
      ));

      expect(_richContaining('Check'), findsNothing);
    });

    testWidgets('check-in row inserts after first generic row', (tester) async {
      final scheduled = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 200,
            breakdown: [
              _line(
                  key: 'work',
                  defaultText: 'Work',
                  pillText: '1 hr',
                  amount: 120),
              _line(
                  key: 'long_distance_label',
                  defaultText: 'Long Distance',
                  pillText: '1.2 kms',
                  amount: 20),
            ],
            checkInAmount: 60,
            checkInTime: scheduled,
          ),
          headerText: 'You Will Earn',
        ),
      ));

      // Order should be: Work → Check-In → Long Distance.
      final workTopY = tester.getTopLeft(find.text('Work')).dy;
      final ldTopY = tester.getTopLeft(find.text('Long Distance')).dy;
      final checkInTopY =
          tester.getTopLeft(_richContaining('Check In by')).dy;
      expect(workTopY, lessThan(checkInTopY));
      expect(checkInTopY, lessThan(ldTopY));
    });

    testWidgets('renders subtitle below title when present', (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 250,
            breakdown: [
              _line(
                key: 'work',
                defaultText: 'Work',
                subtitle: const NudgeLabel(
                  key: 'work_sub',
                  defaultText: 'Includes OT',
                ),
                amount: 250,
              ),
            ],
          ),
          headerText: 'You Will Earn',
        ),
      ));

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Includes OT'), findsOneWidget);

      final titleY = tester.getTopLeft(find.text('Work')).dy;
      final subtitleY = tester.getTopLeft(find.text('Includes OT')).dy;
      expect(titleY, lessThan(subtitleY));
    });

    testWidgets('omits subtitle line when subtitle is null', (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 300,
            breakdown: [
              _line(key: 'work', defaultText: 'Work', amount: 250),
            ],
          ),
          headerText: 'You Will Earn',
        ),
      ));

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      expect(find.text('Includes OT'), findsNothing);
    });

    testWidgets('long title/subtitle ellipsize without overflowing row',
        (tester) async {
      await tester.pumpWidget(_wrap(
        JobPayoutCard(
          payoutInfo: PayoutInfo(
            totalEarning: 250,
            breakdown: [
              _line(
                key: 'work',
                defaultText:
                    'A very very very long title that would otherwise overflow the row beyond its width',
                subtitle: const NudgeLabel(
                  key: 'work_sub',
                  defaultText:
                      'A very very very long subtitle that would also otherwise overflow the row',
                ),
                pillText: '1 hr',
                amount: 250,
              ),
            ],
          ),
          headerText: 'You Will Earn',
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses "You Earned" header for post-checkout', (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutCard(
          payoutInfo: PayoutInfo(totalEarning: 100),
          headerText: 'You Earned',
        ),
      ));

      expect(find.text('You Earned'), findsOneWidget);
    });
  });
}
