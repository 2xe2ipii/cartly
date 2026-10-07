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
    try {
      final response = await _client
          .get(baseUrl.resolve('/items'), headers: {'X-User-Id': userId})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw _responseError(response);
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['items'] is! List) {
        throw const FormatException('Invalid list response');
      }
      return (body['items'] as List).map(ShoppingItem.fromJson).toList();
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
    } on FormatException {
      throw const CartlyApiException(
        'BAD_RESPONSE',
        'The API returned an unexpected response.',
      );
    }
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
