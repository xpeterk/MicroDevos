import '../../domain/models/user_preferences.dart';
import '../../domain/repositories/repositories.dart';

class MemoryFavoritesRepository implements FavoritesRepository {
  MemoryFavoritesRepository([Set<String>? seed]) : _ids = {...?seed};

  final Set<String> _ids;

  @override
  Future<Set<String>> load() async => {..._ids};

  @override
  Future<void> setFavorite(String devoId, bool favorite) async {
    if (favorite) {
      _ids.add(devoId);
    } else {
      _ids.remove(devoId);
    }
  }
}

class MemoryPreferencesRepository implements PreferencesRepository {
  MemoryPreferencesRepository([UserPreferences? seed])
    : _preferences = seed ?? UserPreferences.initial();

  UserPreferences _preferences;

  @override
  Future<UserPreferences> load() async => _preferences;

  @override
  Future<void> save(UserPreferences preferences) async {
    _preferences = preferences;
  }
}
