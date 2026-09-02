import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/widgets/attendance_flow/no_show_red_card_cluster.dart';

void main() {
  testWidgets('NoShowRedCardCluster builds for counts 1, 3, 5', (tester) async {
    for (final n in [1, 3, 5]) {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: NoShowRedCardCluster(count: n),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(NoShowRedCardCluster), findsOneWidget);
    }
  });
}
