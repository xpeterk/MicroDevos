import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/user_preferences.dart';
import '../../domain/repositories/repositories.dart';

class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository(this._prefs);

  static const _key = 'favorite_devo_ids';

  final SharedPreferences _prefs;

  @override
  Future<Set<String>> load() async {
    return _prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  @override
  Future<void> setFavorite(String devoId, bool favorite) async {
    final next = await load();
    if (favorite) {
      next.add(devoId);
    } else {
      next.remove(devoId);
    }
    await _prefs.setStringList(_key, next.toList()..sort());
  }
}

class LocalPreferencesRepository implements PreferencesRepository {
  LocalPreferencesRepository(this._prefs);

  static const _key = 'user_preferences';

  final SharedPreferences _prefs;

  @override
  Future<UserPreferences> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return UserPreferences.initial();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return UserPreferences.initial();
    return UserPreferences.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    await _prefs.setString(_key, jsonEncode(preferences.toJson()));
  }
}
