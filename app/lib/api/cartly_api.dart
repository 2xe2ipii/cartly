import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isBought,
  });

  final String id;
  final String name;
  final int quantity;
  final bool isBought;

  factory ShoppingItem.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['quantity'] is! int ||
        value['isBought'] is! bool) {
      throw const FormatException('Invalid item response');
    }

    return ShoppingItem(
      id: value['id'] as String,
      name: value['name'] as String,
      quantity: value['quantity'] as int,
      isBought: value['isBought'] as bool,
    );
  }
}

class CartlyApiException implements Exception {
  const CartlyApiException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class CartlyApi {
  CartlyApi({required this.baseUrl, required this.userId, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final String userId;
  final http.Client _client;

  Future<List<ShoppingItem>> fetchItems() async {
    final response = await _send(
      () => _client.get(baseUrl.resolve('/items'), headers: _headers),
    );
    _expectStatus(response, 200);

    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['items'] is! List) {
        throw const FormatException('Invalid list response');
      }
      return (body['items'] as List).map(ShoppingItem.fromJson).toList();
    } on FormatException {
      throw const CartlyApiException(
        'BAD_RESPONSE',
        'The API returned an unexpected response.',
      );
    }
  }

  Future<void> addItem({required String name, required int quantity}) async {
    final response = await _send(
      () => _client.post(
        baseUrl.resolve('/items'),
        headers: _jsonHeaders,
        body: jsonEncode({'name': name.trim(), 'quantity': quantity}),
      ),
    );
    _expectStatus(response, 201);
  }

  Future<void> setBought(String id, bool isBought) async {
    final response = await _send(
      () => _client.patch(
        _itemUri(id),
        headers: _jsonHeaders,
        body: jsonEncode({'isBought': isBought}),
      ),
    );
    _expectStatus(response, 204);
  }

  Future<void> deleteItem(String id) async {
    final response = await _send(
      () => _client.delete(_itemUri(id), headers: _headers),
    );
    _expectStatus(response, 204);
  }

  Future<void> clearBought() async {
    final response = await _send(
      () => _client.delete(baseUrl.resolve('/items/bought'), headers: _headers),
    );
    _expectStatus(response, 204);
  }

  Map<String, String> get _headers => {'X-User-Id': userId};

  Map<String, String> get _jsonHeaders => {
    ..._headers,
    'Content-Type': 'application/json',
  };

  Uri _itemUri(String id) =>
      baseUrl.resolve('/items/${Uri.encodeComponent(id)}');

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const CartlyApiException(
        'TIMEOUT',
        'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const CartlyApiException(
        'NETWORK_ERROR',
        'Could not reach the API. Check that the backend is running.',
      );
    }
  }

  void _expectStatus(http.Response response, int expected) {
    if (response.statusCode == expected) return;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      throw const CartlyApiException(
        'BAD_RESPONSE',
        'The API returned an unexpected response.',
      );
    }
    throw _responseError(response);
  }

  CartlyApiException _responseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['message'] is String) {
        return CartlyApiException(
          body['code'] is String ? body['code'] as String : 'REQUEST_ERROR',
          body['message'] as String,
        );
      }
    } on FormatException {
      // Use the generic message if the server did not return JSON.
    }
    return CartlyApiException(
      'REQUEST_ERROR',
      'The request failed (${response.statusCode}). Please try again.',
    );
  }
}
