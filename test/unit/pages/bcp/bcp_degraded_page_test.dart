import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/bcp/bcp_degraded_page.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  Future<void> pumpPage(WidgetTester tester, {required bool backDisabled}) {
    return tester.pumpWidget(
      _wrap(BcpDegradedPage(
        backDisabled: backDisabled,
        source: BcpDegradedPage.sourceAuto,
      )),
    );
  }

  testWidgets('renders title, subtitle and icon using English fallbacks',
      (tester) async {
    await pumpPage(tester, backDisabled: false);
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Please check your internet connection'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('back-enabled mode shows the back button and pops on tap',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const BcpDegradedPage(
                        backDisabled: false,
                        source: BcpDegradedPage.sourceManual,
                      ),
                    ),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.byType(BcpDegradedPage), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isTrue);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.byType(BcpDegradedPage), findsNothing);
  });

  testWidgets('back-disabled mode hides the back button and blocks pop',
      (tester) async {
    await pumpPage(tester, backDisabled: true);

    expect(find.text('Try Again'), findsNothing);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  test('routeName is the expected constant', () {
    expect(BcpDegradedPage.routeName, '/bcp_degraded');
  });
}
