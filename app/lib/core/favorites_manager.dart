import 'package:flutter/foundation.dart';
import '../models/target_item.dart';

class FavoritesManager extends ChangeNotifier {
  FavoritesManager._();
  static final FavoritesManager instance = FavoritesManager._();

  final Map<int, TargetItem> _favorites = {};

  List<TargetItem> get favorites => _favorites.values.toList();
  int get count => _favorites.length;
  bool get isEmpty => _favorites.isEmpty;
  bool get isNotEmpty => _favorites.isNotEmpty;

  bool isFavorite(int id) => _favorites.containsKey(id);

  void init(List<TargetItem>? savedFavorites) {
    _favorites.clear();
    if (savedFavorites != null) {
      for (final target in savedFavorites) {
        _favorites[target.id] = target;
      }
    }
    notifyListeners();
  }

  void toggleFavorite(TargetItem target) {
    if (_favorites.containsKey(target.id)) {
      _favorites.remove(target.id);
    } else {
      _favorites[target.id] = target;
    }
    notifyListeners();
  }

  void addFavorite(TargetItem target) {
    if (!_favorites.containsKey(target.id)) {
      _favorites[target.id] = target;
      notifyListeners();
    }
  }

  void removeFavorite(int id) {
    if (_favorites.remove(id) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_favorites.isNotEmpty) {
      _favorites.clear();
      notifyListeners();
    }
  }
}
