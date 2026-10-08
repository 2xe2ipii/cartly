import 'package:cartly/api/cartly_api.dart';
import 'package:cartly/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shopping actions work on a device with the local API', (
    tester,
  ) async {
    final api = CartlyApi(
      baseUrl: Uri.parse(_apiBaseUrl),
      userId: 'phase3_${DateTime.now().millisecondsSinceEpoch}',
    );
    addTearDown(() async {
      for (final item in await api.fetchItems()) {
        await api.deleteItem(item.id);
      }
    });

    await tester.pumpWidget(CartlyApp(api: api));
    await _waitFor(tester, find.text('Your list is empty'));

    await _addItem(tester, 'Milk', '2');
    await _waitFor(tester, find.text('Milk'));
    await _addItem(tester, 'Bread', '1');
    await _waitFor(tester, find.text('Bread'));

    await tester.tap(find.byTooltip('Put Milk in cart'));
    await _waitFor(tester, find.byTooltip('Take Milk out of cart'));
    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );

    await tester.tap(find.byTooltip('Delete Bread'));
    await _waitFor(tester, find.text('Bread'), present: false);
    await tester.tap(find.text('Empty cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Empty cart'));
    await _waitFor(tester, find.text('Your list is empty'));
  });
}

Future<void> _addItem(WidgetTester tester, String name, String quantity) async {
  await tester.tap(find.text('Add item'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.enterText(find.byType(TextFormField).last, quantity);
  await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
  await _waitFor(tester, find.byType(TextFormField), present: false);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  bool present = true,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty == present) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  expect(finder, present ? findsWidgets : findsNothing);
}
