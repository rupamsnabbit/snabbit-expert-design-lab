import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';

void main() {
  group('WebViewLauncher.isOpenableHttps', () {
    test('https URL is openable', () {
      expect(
        WebViewLauncher.isOpenableHttps('https://expert.snabbit.com/x'),
        isTrue,
      );
    });

    test('http (non-https) URL is not openable', () {
      expect(
        WebViewLauncher.isOpenableHttps('http://expert.snabbit.com'),
        isFalse,
      );
    });

    test('null URL is not openable', () {
      expect(WebViewLauncher.isOpenableHttps(null), isFalse);
    });

    test('empty URL is not openable', () {
      expect(WebViewLauncher.isOpenableHttps(''), isFalse);
    });

    test('non-http scheme is not openable', () {
      expect(WebViewLauncher.isOpenableHttps('javascript:alert(1)'), isFalse);
    });
  });

  group('WebViewLauncher.open', () {
    Widget host(GlobalKey<NavigatorState> key) => MaterialApp(
          navigatorKey: key,
          routes: {
            '/': (_) => const Scaffold(body: Text('start')),
            AppWebViewPage.routeName: (_) =>
                const Scaffold(body: Text('webview')),
          },
        );

    testWidgets('replace=false pushes the webview on top', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      WebViewLauncher.open(
        key.currentContext!,
        url: 'https://x.snabbit.com',
        title: 'T',
      );
      await tester.pumpAndSettle();

      expect(find.text('webview'), findsOneWidget);
    });

    testWidgets('replace=true pops the current route then shows the webview',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(key));

      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('dummy')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dummy'), findsOneWidget);

      WebViewLauncher.open(
        key.currentContext!,
        url: 'https://x.snabbit.com',
        title: 'T',
        replace: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('webview'), findsOneWidget);
      expect(find.text('dummy'), findsNothing);
    });
  });
}
