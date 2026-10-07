import 'package:flutter/material.dart';

import 'api/cartly_api.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: _ConnectionScreen(api: api),
    );
  }
}

class _ConnectionScreen extends StatefulWidget {
  const _ConnectionScreen({required this.api});

  final CartlyApi api;

  @override
  State<_ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<_ConnectionScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _checkConnection() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final items = await widget.api.fetchItems();
      if (!mounted) return;
      setState(
        () => _message = 'Connected. ${items.length} items in your list.',
      );
    } on CartlyApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartly')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 56),
              const SizedBox(height: 16),
              const Text('Your shopping list is taking shape.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _checkConnection,
                child: Text(_loading ? 'Checking…' : 'Check API connection'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
