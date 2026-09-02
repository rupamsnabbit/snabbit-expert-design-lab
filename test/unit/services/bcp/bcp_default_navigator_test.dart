import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/bcp/bcp_degraded_page.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/globals.dart';

void main() {
  Future<void> pumpHostApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          navigatorKey: GlobalState().navigatorKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
  }

  testWidgets('no-op when navigator is not attached', (tester) async {
    expect(() => bcpDefaultNavigator(false), returnsNormally);
  });

  testWidgets('pushes BcpDegradedPage with backDisabled=false', (tester) async {
    await pumpHostApp(tester);
    bcpDefaultNavigator(false);
    await tester.pumpAndSettle();

    expect(find.byType(BcpDegradedPage), findsOneWidget);
    final page = tester.widget<BcpDegradedPage>(find.byType(BcpDegradedPage));
    expect(page.backDisabled, isFalse);
  });

  testWidgets('pushes BcpDegradedPage with backDisabled=true', (tester) async {
    await pumpHostApp(tester);
    bcpDefaultNavigator(true);
    await tester.pumpAndSettle();

    final page = tester.widget<BcpDegradedPage>(find.byType(BcpDegradedPage));
    expect(page.backDisabled, isTrue);
  });

  testWidgets('does not stack duplicate degraded pages', (tester) async {
    await pumpHostApp(tester);
    bcpDefaultNavigator(true);
    await tester.pumpAndSettle();
    bcpDefaultNavigator(true);
    await tester.pumpAndSettle();
    bcpDefaultNavigator(false);
    await tester.pumpAndSettle();

    expect(find.byType(BcpDegradedPage), findsOneWidget);
  });
}
