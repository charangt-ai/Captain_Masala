import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/customer.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartService extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  Customer? _activeCustomer;

  Map<String, CartItem> get items => _items;
  Customer? get activeCustomer => _activeCustomer;

  int get totalItems {
    int total = 0;
    _items.forEach((key, item) {
      total += item.quantity;
    });
    return total;
  }

  double get subtotalAmount {
    double total = 0.0;
    _items.forEach((key, item) {
      total += item.product.wholesalePrice * item.quantity;
    });
    return total;
  }

  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;
    
    if (quantity <= 0) {
      removeItem(productId);
    } else {
      _items[productId]!.quantity = quantity;
      notifyListeners();
    }
  }

  void setActiveCustomer(Customer customer) {
    _activeCustomer = customer;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _activeCustomer = null;
    notifyListeners();
  }

  /// Syncs cart items with latest product data (prices, availability).
  /// Call before checkout to ensure accurate totals.
  void refreshProducts(List<Product> latestProducts) {
    final keysToRemove = <String>[];
    for (final entry in _items.entries) {
      final latest = latestProducts.where((p) => p.id == entry.key).firstOrNull;
      if (latest != null) {
        _items[entry.key] = CartItem(product: latest, quantity: entry.value.quantity);
      } else {
        // Product was deleted or disabled — mark for removal
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _items.remove(key);
    }
    notifyListeners();
  }
}
