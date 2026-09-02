import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/aadhaar_update_response.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_result_view.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  group('AadhaarReverificationResultView', () {
    testWidgets('verified shows a success result with only a Done action',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AadhaarReverificationResultView(
          result: AadhaarUpdateResponse.fromJson(const {'status': 'verified'}),
          error: null,
          canRetry: false,
          onRetry: () {},
          onDone: () {},
        ),
      ));

      expect(find.text('Aadhaar verified'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('name_mismatched shows the under-review (terminal) result',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AadhaarReverificationResultView(
          result: AadhaarUpdateResponse.fromJson(
              const {'status': 'name_mismatched'}),
          error: null,
          canRetry: false,
          onRetry: () {},
          onDone: () {},
        ),
      ));

      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('rejected (retryable) shows Try again and Close, wired up',
        (tester) async {
      var retried = false;
      var done = false;
      await tester.pumpWidget(_wrap(
        AadhaarReverificationResultView(
          result: AadhaarUpdateResponse.fromJson(const {'status': 'rejected'}),
          error: null,
          canRetry: true,
          onRetry: () => retried = true,
          onDone: () => done = true,
        ),
      ));

      expect(find.text('Verification failed'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);

      await tester.tap(find.text('Close'));
      expect(done, isTrue);
    });

    testWidgets('a backend error surfaces its title and message',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AadhaarReverificationResultView(
          result: null,
          error: CustomError(
            title: 'Aadhaar already in use',
            message: 'This Aadhaar is linked to another account.',
          ),
          canRetry: true,
          onRetry: () {},
          onDone: () {},
        ),
      ));

      expect(find.text('Aadhaar already in use'), findsOneWidget);
      expect(find.text('This Aadhaar is linked to another account.'),
          findsOneWidget);
    });
  });
}
