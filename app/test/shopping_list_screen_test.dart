import 'dart:async';
import 'dart:convert';

import 'package:cartly/api/cartly_api.dart';
import 'package:cartly/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('shows loading, then items in the API order', (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      expect(request.headers['X-User-Id'], 'shopper_1');
      return response.future;
    });
    final api = CartlyApi(
      baseUrl: Uri.parse('http://127.0.0.1:3000'),
      userId: 'shopper_1',
      client: client,
    );

    await tester.pumpWidget(CartlyApp(api: api));
    await tester.pump();
    expect(find.text('Loading your list…'), findsOneWidget);

    response.complete(
      http.Response(
        jsonEncode({
          'items': [
            {'id': '1', 'name': 'Milk', 'quantity': 2, 'isBought': false},
            {'id': '2', 'name': 'Bread', 'quantity': 1, 'isBought': true},
          ],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quantity: 2 · To buy'), findsOneWidget);
    expect(find.text('Quantity: 1 · Bought'), findsOneWidget);
    expect(find.byTooltip('Put Milk in cart'), findsOneWidget);
    expect(find.byTooltip('Take Bread out of cart'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      lessThan(tester.getTopLeft(find.text('Bread')).dy),
    );
  });

  testWidgets('shows the backend error and recovers with retry', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'code': 'INTERNAL_ERROR',
            'message': 'Please try again.',
          }),
          503,
        );
      }
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final api = CartlyApi(
      baseUrl: Uri.parse('http://127.0.0.1:3000'),
      userId: 'shopper_1',
      client: client,
    );

    await tester.pumpWidget(CartlyApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your list'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your list is empty'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('keeps loaded items visible during refresh and after a failure', (
    tester,
  ) async {
    final refresh = Completer<http.Response>();
    var reads = 0;
    final client = MockClient((_) {
      reads++;
      if (reads == 2) return refresh.future;
      return Future.value(
        http.Response(
          jsonEncode({
            'items': [
              {'id': 'milk', 'name': 'Milk', 'quantity': 2, 'isBought': false},
            ],
          }),
          200,
        ),
      );
    });

    await tester.pumpWidget(
      CartlyApp(
        api: CartlyApi(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          userId: 'shopper_1',
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh list'));
    await tester.pump();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Loading your list…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    refresh.complete(
      http.Response(
        jsonEncode({'code': 'NETWORK_ERROR', 'message': 'Could not refresh.'}),
        503,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Could not refresh.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Could not refresh.'), findsNothing);
    expect(reads, 3);
  });
}
