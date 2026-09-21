import 'package:flutter/foundation.dart';
import '../screens/restaurant_list_screen.dart' show MenuItem, Restaurant;

/// App-wide singleton cart.
///
/// The nav-bar Cart tab and the restaurant detail screen previously kept
/// SEPARATE item lists — items added in a restaurant never showed up in
/// the Cart tab (it was hardcoded to "empty"). This service is the single
/// source of truth both screens read from.
///
/// One cart holds items from ONE restaurant at a time (FoodPanda-style):
/// adding an item from a different restaurant replaces the cart and the
/// user is told via [RestaurantConflict] so the UI can confirm.
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<CartItem> _items = [];
  String? _restaurantId;
  String? _restaurantName;
  double _deliveryFee = 0;
  String? _restaurantImage;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  String? get restaurantImage => _restaurantImage;
  double get deliveryFee => _deliveryFee;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItems => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => _items.fold(0, (sum, i) => i.price * i.quantity);

  /// True when [restaurantId] is set and differs from [newRestaurantId].
  bool hasConflictWith(String newRestaurantId) =>
      _restaurantId != null && _restaurantId != newRestaurantId;

  /// Add one quantity of [item]. Returns false when the cart belongs to a
  /// different restaurant (caller should confirm with the user first).
  bool tryAdd({
    required Restaurant restaurant,
    required MenuItem item,
  }) {
    if (hasConflictWith(restaurant.id)) return false;
    _bindRestaurant(restaurant.id, restaurant.name, restaurant.deliveryFee.toDouble(), restaurant.image);

    final existing = _items.indexWhere((i) => i.menuItemId == item.id);
    if (existing != -1) {
      _items[existing].quantity++;
    } else {
      _items.add(CartItem(
        menuItemId: item.id,
        name: item.name,
        description: item.description,
        price: item.price,
        imageUrl: item.image,
      ));
    }
    notifyListeners();
    return true;
  }

  /// Replace the whole cart with items from another restaurant
  /// (after the user confirms the swap).
  void switchRestaurant({
    required Restaurant restaurant,
    required MenuItem item,
  }) {
    _items.clear();
    _bindRestaurant(restaurant.id, restaurant.name, restaurant.deliveryFee.toDouble(), restaurant.image);
    _items.add(CartItem(
      menuItemId: item.id,
      name: item.name,
      description: item.description,
      price: item.price,
      imageUrl: item.image,
    ));
    notifyListeners();
  }

  void _bindRestaurant(String id, String name, double fee, String image) {
    if (_restaurantId != id) {
      _restaurantId = id;
      _restaurantName = name;
      _deliveryFee = fee;
      _restaurantImage = image;
    }
  }

  void increment(String menuItemId) {
    final i = _items.indexWhere((x) => x.menuItemId == menuItemId);
    if (i != -1) {
      _items[i].quantity++;
      notifyListeners();
    }
  }

  /// Returns the new quantity (0 means removed).
  int decrement(String menuItemId) {
    final i = _items.indexWhere((x) => x.menuItemId == menuItemId);
    if (i == -1) return 0;
    if (_items[i].quantity > 1) {
      _items[i].quantity--;
      notifyListeners();
      return _items[i].quantity;
    }
    _items.removeAt(i);
    _maybeClearRestaurant();
    notifyListeners();
    return 0;
  }

  int quantityOf(String menuItemId) {
    final i = _items.indexWhere((x) => x.menuItemId == menuItemId);
    return i == -1 ? 0 : _items[i].quantity;
  }

  void remove(String menuItemId) {
    _items.removeWhere((x) => x.menuItemId == menuItemId);
    _maybeClearRestaurant();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    _deliveryFee = 0;
    _restaurantImage = null;
    notifyListeners();
  }

  void _maybeClearRestaurant() {
    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
      _deliveryFee = 0;
      _restaurantImage = null;
    }
  }
}

/// One line item in the global cart.
class CartItem {
  final String menuItemId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  int quantity;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toOrderJson() => {
        'name': name,
        'quantity': quantity,
        'price': price.toInt(),
      };
}
