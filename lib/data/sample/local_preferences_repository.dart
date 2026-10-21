import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/devo_section.dart';
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

class LocalSectionFavoritesRepository implements SectionFavoritesRepository {
  LocalSectionFavoritesRepository(this._prefs);

  static const storageKey = 'favorite_sections';

  final SharedPreferences _prefs;

  @override
  Future<List<SectionFavorite>> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => SectionFavorite.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.sectionId.isNotEmpty)
        .toList();
  }

  @override
  Future<void> setFavorite(
    String devoId,
    String sectionId,
    bool favorite,
  ) async {
    final next = [
      for (final item in await load())
        if (item.sectionId != sectionId) item,
    ];
    if (favorite) {
      next.add(SectionFavorite(devoId: devoId, sectionId: sectionId));
    }
    await _prefs.setString(
      storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
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
