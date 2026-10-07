import 'package:flutter/foundation.dart';

import '../api/cartly_api.dart';

enum ShoppingListStatus { loading, ready, error }

class ShoppingListController extends ChangeNotifier {
  ShoppingListController(this.api);

  final CartlyApi api;

  ShoppingListStatus status = ShoppingListStatus.loading;
  List<ShoppingItem> items = const [];
  String? errorMessage;
  bool _disposed = false;

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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
