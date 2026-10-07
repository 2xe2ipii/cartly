import 'package:flutter/foundation.dart';

import '../api/cartly_api.dart';

enum ShoppingListStatus { loading, ready, error }

class ShoppingListController extends ChangeNotifier {
  ShoppingListController(this.api);

  final CartlyApi api;

  ShoppingListStatus status = ShoppingListStatus.loading;
  List<ShoppingItem> items = const [];
  String? errorMessage;
  bool isMutating = false;
  bool _disposed = false;

  bool get hasBoughtItems => items.any((item) => item.isBought);

  Future<void> load() async {
    status = ShoppingListStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedItems = await api.fetchItems();
      if (_disposed) return;
      // Firestore has already ordered the response. Keep that order in the UI.
      items = loadedItems;
      status = ShoppingListStatus.ready;
    } on CartlyApiException catch (error) {
      if (_disposed) return;
      errorMessage = error.message;
      status = ShoppingListStatus.error;
    } catch (_) {
      if (_disposed) return;
      errorMessage = 'Something went wrong. Please try again.';
      status = ShoppingListStatus.error;
    }

    notifyListeners();
  }

  Future<void> addItem(String name, int quantity) =>
      _mutate(() => api.addItem(name: name, quantity: quantity));

  Future<void> toggleBought(ShoppingItem item) =>
      _mutate(() => api.setBought(item.id, !item.isBought));

  Future<void> deleteItem(ShoppingItem item) =>
      _mutate(() => api.deleteItem(item.id));

  Future<void> clearBought() => _mutate(api.clearBought);

  Future<void> _mutate(Future<void> Function() request) async {
    if (isMutating) {
      throw const CartlyApiException(
        'BUSY',
        'Please wait for the current change.',
      );
    }

    isMutating = true;
    notifyListeners();
    try {
      await request();
      if (!_disposed) await load();
    } finally {
      if (!_disposed) {
        isMutating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
