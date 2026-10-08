import 'dart:async';
import 'dart:convert';

import 'package:cartly/api/cartly_api.dart';
import 'package:cartly/list/add_item_sheet.dart';
import 'package:cartly/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'validates locally, shows a backend rejection, then adds an item',
    (tester) async {
      var posts = 0;
      var saved = false;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': saved
                  ? [
                      {
                        'id': 'milk',
                        'name': 'Milk',
                        'quantity': 2,
                        'isBought': false,
                      },
                    ]
                  : [],
            }),
            200,
          );
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/items');
        expect(request.headers['X-User-Id'], 'shopper_1');
        posts++;
        if (posts == 1) {
          return http.Response(
            jsonEncode({
              'code': 'VALIDATION_ERROR',
              'message': 'Please rename this item.',
            }),
            400,
          );
        }
        expect(jsonDecode(request.body), {'name': 'Milk', 'quantity': 2});
        saved = true;
        return http.Response(jsonEncode({'id': 'milk'}), 201);
      });

      await tester.pumpWidget(CartlyApp(api: _api(client)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      final addButton = find.widgetWithText(FilledButton, 'Add item');

      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text('Name is required.'), findsOneWidget);
      expect(posts, 0);

      await tester.enterText(find.byType(TextFormField).first, '  Milk  ');
      await tester.enterText(find.byType(TextFormField).last, '0');
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text('Quantity must be at least 1.'), findsOneWidget);
      expect(posts, 0);

      await tester.enterText(find.byType(TextFormField).last, '2');
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text('Please rename this item.'), findsOneWidget);
      expect(find.byType(AddItemSheet), findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.byType(AddItemSheet), findsNothing);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Quantity: 2'), findsOneWidget);
      expect(posts, 2);
    },
  );

  testWidgets('toggles, deletes, and clears bought items with a fresh list', (
    tester,
  ) async {
    var reads = 0;
    final mutations = <String>[];
    final lists = [
      [_item('milk', 'Milk', false), _item('bread', 'Bread', true)],
      [_item('bread', 'Bread', true), _item('milk', 'Milk', true)],
      [_item('bread', 'Bread', false), _item('milk', 'Milk', true)],
      [_item('milk', 'Milk', true)],
      <Map<String, Object>>[],
    ];
    final client = MockClient((request) async {
      expect(request.headers['X-User-Id'], 'shopper_1');
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'items': lists[reads++]}), 200);
      }
      if (request.method == 'PATCH') {
        expect(jsonDecode(request.body), {
          'isBought': request.url.path == '/items/milk',
        });
      }
      mutations.add('${request.method} ${request.url.path}');
      return http.Response('', 204);
    });

    await tester.pumpWidget(CartlyApp(api: _api(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Put Milk in cart'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );
    expect(find.text('Quantity: 1'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Take Bread out of cart'));
    await tester.pumpAndSettle();
    expect(find.text('Quantity: 1'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );

    await tester.tap(find.byTooltip('Delete Bread'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Milk'), findsOneWidget);

    await tester.tap(find.text('Empty cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Empty cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your list is empty'), findsOneWidget);
    expect(mutations, [
      'PATCH /items/milk',
      'PATCH /items/bread',
      'DELETE /items/bread',
      'DELETE /items/bought',
    ]);
    expect(reads, 5);
  });

  testWidgets('shows a missing-item error and reloads the list', (
    tester,
  ) async {
    var reads = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        reads++;
        return http.Response(
          jsonEncode({
            'items': reads == 1 ? [_item('milk', 'Milk', false)] : [],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({'code': 'ITEM_NOT_FOUND', 'message': 'Item not found.'}),
        404,
      );
    });

    await tester.pumpWidget(CartlyApp(api: _api(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Put Milk in cart'));
    await tester.pumpAndSettle();
    expect(find.text('Item not found.'), findsOneWidget);
    expect(find.text('Your list is empty'), findsOneWidget);
    expect(reads, 2);
  });

  testWidgets('deletes two items without waiting and reconciles once', (
    tester,
  ) async {
    final milkDelete = Completer<http.Response>();
    final breadDelete = Completer<http.Response>();
    var reads = 0;
    final deletedPaths = <String>[];
    final client = MockClient((request) {
      if (request.method == 'GET') {
        reads++;
        return Future.value(
          http.Response(
            jsonEncode({
              'items': reads == 1
                  ? [
                      _item('milk', 'Milk', false),
                      _item('bread', 'Bread', false),
                      _item('eggs', 'Eggs', false),
                    ]
                  : [_item('eggs', 'Eggs', false)],
            }),
            200,
          ),
        );
      }
      deletedPaths.add(request.url.path);
      return request.url.path == '/items/milk'
          ? milkDelete.future
          : breadDelete.future;
    });

    await tester.pumpWidget(CartlyApp(api: _api(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pump();
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Bread'));
    await tester.pump();
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Eggs'), findsOneWidget);
    expect(deletedPaths, ['/items/milk', '/items/bread']);
    expect(reads, 1);

    milkDelete.complete(http.Response('', 204));
    await tester.pump();
    expect(find.text('Eggs'), findsOneWidget);
    expect(reads, 1);

    breadDelete.complete(http.Response('', 204));
    await tester.pumpAndSettle();
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsNothing);
    expect(reads, 2);
  });

  testWidgets('restores a failed delete while keeping a successful one gone', (
    tester,
  ) async {
    final milkDelete = Completer<http.Response>();
    final breadDelete = Completer<http.Response>();
    var reads = 0;
    final client = MockClient((request) {
      if (request.method == 'GET') {
        reads++;
        return Future.value(
          http.Response(
            jsonEncode({
              'items': reads == 1
                  ? [
                      _item('milk', 'Milk', false),
                      _item('bread', 'Bread', false),
                    ]
                  : [_item('milk', 'Milk', false)],
            }),
            200,
          ),
        );
      }
      return request.url.path == '/items/milk'
          ? milkDelete.future
          : breadDelete.future;
    });

    await tester.pumpWidget(CartlyApp(api: _api(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete Bread'));
    await tester.pump();
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsNothing);

    breadDelete.complete(http.Response('', 204));
    await tester.pump();
    milkDelete.complete(
      http.Response(
        jsonEncode({'code': 'REQUEST_ERROR', 'message': 'Delete failed.'}),
        503,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Delete failed.'), findsOneWidget);
    expect(reads, 2);
  });

  testWidgets('an older refresh cannot restore a deleted item', (tester) async {
    final oldRefresh = Completer<http.Response>();
    var reads = 0;
    final client = MockClient((request) {
      if (request.method == 'GET') {
        reads++;
        if (reads == 2) return oldRefresh.future;
        return Future.value(
          http.Response(
            jsonEncode({
              'items': reads == 1
                  ? [
                      _item('milk', 'Milk', false),
                      _item('bread', 'Bread', false),
                    ]
                  : [_item('bread', 'Bread', false)],
            }),
            200,
          ),
        );
      }
      return Future.value(http.Response('', 204));
    });

    await tester.pumpWidget(CartlyApp(api: _api(client)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh list'));
    await tester.pump();
    expect(find.text('Milk'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsOneWidget);
    expect(reads, 3);

    oldRefresh.complete(
      http.Response(
        jsonEncode({
          'items': [
            _item('milk', 'Milk', false),
            _item('bread', 'Bread', false),
          ],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsOneWidget);
  });
}

CartlyApi _api(MockClient client) => CartlyApi(
  baseUrl: Uri.parse('http://127.0.0.1:3000'),
  userId: 'shopper_1',
  client: client,
);

Map<String, Object> _item(String id, String name, bool isBought) => {
  'id': id,
  'name': name,
  'quantity': 1,
  'isBought': isBought,
};
