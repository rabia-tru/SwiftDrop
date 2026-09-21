import 'package:shared_preferences/shared_preferences.dart';

/// Favorites/Bookmarks service — allows customers to save favourite restaurants
class FavoritesService {
  static const String _key = 'favorite_restaurants';
  static List<String> _favorites = [];

  /// Load favorites from local storage
  static Future<List<String>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favorites = prefs.getStringList(_key) ?? [];
      return _favorites;
    } catch (e) {
      return [];
    }
  }

  /// Check if a restaurant is favorited
  static bool isFavorite(String restaurantId) {
    return _favorites.contains(restaurantId);
  }

  /// Toggle favorite status
  static Future<bool> toggleFavorite(String restaurantId) async {
    if (_favorites.contains(restaurantId)) {
      _favorites.remove(restaurantId);
    } else {
      _favorites.add(restaurantId);
    }
    await _saveFavorites();
    return _favorites.contains(restaurantId);
  }

  /// Get all favorite restaurant IDs
  static List<String> getFavorites() => List.from(_favorites);

  static Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _favorites);
    } catch (e) {
      // Silent fail
    }
  }
}
