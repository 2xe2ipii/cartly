import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/cartly_api.dart';

enum ShoppingListStatus { loading, ready, error }

class ShoppingListController extends ChangeNotifier {
  ShoppingListController(this.api);

  final CartlyApi api;

  ShoppingListStatus status = ShoppingListStatus.loading;
  List<ShoppingItem> _serverItems = const [];
  final Set<String> _pendingDeleteIds = {};
  String? errorMessage;
  bool isMutating = false;
  bool isRefreshing = false;
  bool _disposed = false;
  int _loadVersion = 0;

  List<ShoppingItem> get items => _serverItems
      .where((item) => !_pendingDeleteIds.contains(item.id))
      .toList(growable: false);
  bool get hasBoughtItems => items.any((item) => item.isBought);
  bool get hasPendingDeletes => _pendingDeleteIds.isNotEmpty;

  Future<void> load() async {
    final version = ++_loadVersion;
    if (status == ShoppingListStatus.ready) {
      isRefreshing = true;
    } else {
      status = ShoppingListStatus.loading;
    }
    errorMessage = null;
    notifyListeners();

    try {
      final loadedItems = await api.fetchItems();
      if (_disposed || version != _loadVersion) return;
      // Firestore has already ordered the response. Keep that order in the UI.
      _serverItems = loadedItems;
      status = ShoppingListStatus.ready;
    } on CartlyApiException catch (error) {
      if (_disposed || version != _loadVersion) return;
      errorMessage = error.message;
      if (status != ShoppingListStatus.ready) {
        status = ShoppingListStatus.error;
      }
    } catch (_) {
      if (_disposed || version != _loadVersion) return;
      errorMessage = 'Something went wrong. Please try again.';
      if (status != ShoppingListStatus.ready) {
        status = ShoppingListStatus.error;
      }
    }

    isRefreshing = false;
    notifyListeners();
  }

  Future<void> addItem(String name, int quantity) =>
      _mutate(() => api.addItem(name: name, quantity: quantity));

  Future<void> toggleBought(ShoppingItem item) =>
      _mutate(() => api.setBought(item.id, !item.isBought));

  Future<void> deleteItem(ShoppingItem item) async {
    if (isMutating || _pendingDeleteIds.contains(item.id)) {
      throw const CartlyApiException(
        'BUSY',
        'Please wait for the current change.',
      );
    }

    _pendingDeleteIds.add(item.id);
    notifyListeners();
    try {
      await api.deleteItem(item.id);
      if (_disposed) return;
      _removeFromServerItems(item.id);
    } on CartlyApiException catch (error) {
      if (!_disposed && error.code == 'ITEM_NOT_FOUND') {
        _removeFromServerItems(item.id);
      }
      rethrow;
    } finally {
      if (!_disposed) {
        _pendingDeleteIds.remove(item.id);
        notifyListeners();
        if (_pendingDeleteIds.isEmpty) unawaited(load());
      }
    }
  }

  Future<void> clearBought() => _mutate(api.clearBought);

  Future<void> _mutate(Future<void> Function() request) async {
    if (isMutating || hasPendingDeletes) {
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
    } on CartlyApiException catch (error) {
      if (!_disposed && error.code == 'ITEM_NOT_FOUND') unawaited(load());
      rethrow;
    } finally {
      if (!_disposed) {
        isMutating = false;
        notifyListeners();
      }
    }
  }

  void _removeFromServerItems(String id) {
    // Ignore reads started before the delete completed; they may still include it.
    _loadVersion++;
    _serverItems = _serverItems.where((item) => item.id != id).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
