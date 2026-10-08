import 'package:flutter/material.dart';

import 'api/cartly_api.dart';
import 'list/shopping_list_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);
const _userId = String.fromEnvironment('USER_ID', defaultValue: 'demo_user');

void main() {
  runApp(
    CartlyApp(
      api: CartlyApi(baseUrl: Uri.parse(_apiBaseUrl), userId: _userId),
    ),
  );
}

class CartlyApp extends StatelessWidget {
  const CartlyApp({super.key, required this.api});

  final CartlyApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: ShoppingListScreen(api: api),
    );
  }
}
