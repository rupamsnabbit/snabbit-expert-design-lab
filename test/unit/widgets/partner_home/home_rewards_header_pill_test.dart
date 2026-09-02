import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/widgets/partner_home/home_rewards_header_pill.dart';

void main() {
  testWidgets('shows default dummy counts', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => const MaterialApp(
          home: Scaffold(
            body: HomeRewardsHeaderPill(),
          ),
        ),
      ),
    );

    expect(find.text('30'), findsNWidgets(2));
  });

  testWidgets('shows custom counts', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => const MaterialApp(
          home: Scaffold(
            body: HomeRewardsHeaderPill(
              coinsCount: 7,
              ticketsCount: 12,
            ),
          ),
        ),
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
