import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/job_payout_summary_bar.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 390, child: child),
          ),
        ),
      ),
    ),
  );
}

/// [RichText] is not matched by [find.text]; spans must be found this way.
Finder _richTextContaining(String substring) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(substring),
  );
}

void main() {
  group('JobPayoutSummaryBar', () {
    testWidgets('renders nothing when payoutInfo is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutSummaryBar(payoutInfo: null),
      ));

      expect(find.text('YOU WILL EARN'), findsNothing);
    });

    testWidgets('renders total earning without check-in breakdown',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(totalEarning: 145),
        ),
      ));

      expect(find.text('YOU WILL EARN'), findsOneWidget);
      expect(_richTextContaining('145'), findsOneWidget);
    });

    testWidgets('renders base + check-in amount split', (tester) async {
      final scheduled = DateTime.now().add(const Duration(minutes: 30));
      final pill = formatPayoutCheckInTimeDisplay(scheduled)!;
      await tester.pumpWidget(_wrap(
        JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            checkInAmount: 5,
            checkInTime: scheduled,
          ),
        ),
      ));

      // Base amount = 150 - 5 = 145
      expect(_richTextContaining('145'), findsOneWidget);
      expect(_richTextContaining(' + '), findsOneWidget);
      expect(find.text('Check In by $pill'), findsOneWidget);
    });

    testWidgets('does not show check-in pill when checkInTime is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(
            totalEarning: 150,
            checkInAmount: 5,
          ),
        ),
      ));

      expect(_richTextContaining('145'), findsOneWidget);
      expect(_richTextContaining(' + '), findsOneWidget);
      expect(find.textContaining('Check In by'), findsNothing);
    });

    testWidgets('does not show plus when checkInAmount is 0', (tester) async {
      final scheduled = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(
        JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(
            totalEarning: 145,
            checkInAmount: 0,
            checkInTime: scheduled,
          ),
        ),
      ));

      expect(_richTextContaining('145'), findsOneWidget);
      expect(_richTextContaining('+'), findsNothing);
    });

    testWidgets('does not show plus when checkInAmount is absent',
        (tester) async {
      final scheduled = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(
        JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(
            totalEarning: 145,
            checkInTime: scheduled,
          ),
        ),
      ));

      expect(_richTextContaining('145'), findsOneWidget);
      expect(_richTextContaining('+'), findsNothing);
    });

    testWidgets('header label is uppercase', (tester) async {
      await tester.pumpWidget(_wrap(
        const JobPayoutSummaryBar(
          payoutInfo: PayoutInfo(totalEarning: 100),
        ),
      ));

      expect(find.text('YOU WILL EARN'), findsOneWidget);
    });
  });
}
