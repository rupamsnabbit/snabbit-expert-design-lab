import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/perfios_aadhaar_data.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_review_view.dart';
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
  group('AadhaarReverificationReviewView', () {
    testWidgets('renders the parsed details and confirms', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(_wrap(
        AadhaarReverificationReviewView(
          data: PerfiosAadhaarData.fromJson(const {
            'name': 'Ravi Kumar',
            'maskedAadhaarNumber': 'XXXX1234',
          }),
          submitting: false,
          onConfirm: () => confirmed = true,
        ),
      ));

      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('XXXX1234'), findsOneWidget);

      await tester.tap(find.text('Confirm & Submit'));
      expect(confirmed, isTrue);
    });

    testWidgets('disables confirm while submitting', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(_wrap(
        AadhaarReverificationReviewView(
          data: PerfiosAadhaarData.fromJson(const {'name': 'Ravi Kumar'}),
          submitting: true,
          onConfirm: () => confirmed = true,
        ),
      ));

      // Confirm label is replaced by a spinner and the button is disabled.
      expect(find.text('Confirm & Submit'), findsNothing);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(confirmed, isFalse);
    });
  });
}
