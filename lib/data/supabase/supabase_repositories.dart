import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/models/devo.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/repositories/repositories.dart';
import 'supabase_mappers.dart';

const oauthRedirect = 'com.microdevos.microdevos://login-callback';

class SupabaseDevoRepository implements DevoRepository {
  const SupabaseDevoRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, title, hook, body_md, takeaway, verse_text, verse_ref, scriptures, source_url, edition_date, edition_url, position, stars, status, notion_page_id, image_url, devo_tags(tags(slug, label))';

  @override
  Future<Devo?> devoById(String id) async {
    final row = await _client.from('devos').select(_columns).eq('id', id).maybeSingle();
    if (row == null) return null;
    return devoFromRow(row);
  }

  @override
  Future<List<Devo>> devosForDate(DateTime date) async {
    final rows = await _client
        .from('devos')
        .select(_columns)
        .eq('edition_date', dateKeyOf(date))
        .order('position');
    return rows.map(devoFromRow).toList();
  }

  @override
  Future<List<DateTime>> editionDates() async {
    final rows = await _client.from('devos').select('edition_date').order('edition_date', ascending: false);
    final dates = <String, DateTime>{};
    for (final row in rows) {
      final raw = row['edition_date'];
      if (raw == null) continue;
      final date = parseDateOnly(raw.toString());
      dates[dateKeyOf(date)] = date;
    }
    return dates.values.toList();
  }

  @override
  Future<List<Devo>> search({String text = '', DateTime? date}) async {
    var filter = _client.from('devos').select(_columns);
    if (date != null) {
      filter = filter.eq('edition_date', dateKeyOf(date));
    }
    final query = text.trim();
    if (query.isNotEmpty) {
      final safe = query.replaceAll(',', ' ');
      filter = filter.or(
        'title.ilike.%$safe%,hook.ilike.%$safe%,body_md.ilike.%$safe%,takeaway.ilike.%$safe%,verse_ref.ilike.%$safe%',
      );
    }
    final rows = await filter.order('edition_date', ascending: false).order('position');
    return rows.map(devoFromRow).toList();
  }
}

class SupabaseFavoritesRepository implements FavoritesRepository {
  const SupabaseFavoritesRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthUnavailable('Sign in to sync favorites.');
    }
    return id;
  }

  @override
  Future<Set<String>> load() async {
    final rows = await _client
        .from('favorites')
        .select('devo_id')
        .eq('user_id', _userId)
        .not('devo_id', 'is', null);
    return favoriteIdsFromRows(rows);
  }

  @override
  Future<void> setFavorite(String devoId, bool favorite) async {
    if (favorite) {
      await _client.from('favorites').upsert({
        'user_id': _userId,
        'devo_id': devoId,
      }, onConflict: 'user_id,devo_id');
      return;
    }
    await _client.from('favorites').delete().eq('user_id', _userId).eq('devo_id', devoId);
  }
}

class SupabasePreferencesRepository implements PreferencesRepository {
  const SupabasePreferencesRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthUnavailable('Sign in to sync preferences.');
    }
    return id;
  }

  @override
  Future<UserPreferences> load() async {
    final row = await _client.from('preferences').select().eq('user_id', _userId).maybeSingle();
    if (row == null) return UserPreferences.initial();
    final time = row['notify_time']?.toString() ?? '07:30';
    return UserPreferences.fromJson({
      'bible_versions': row['bible_versions'] ?? const <String>[],
      'tags': row['tags'] ?? const <String>[],
      'notifications_enabled': _notificationsEnabled(row),
      'notify_time': time,
      'age_range': row['age_range'],
      'sex': row['sex'],
      'life_situations': row['life_situations'] ?? const <String>[],
    });
  }

  @override
  Future<void> save(UserPreferences preferences) async {
    await _client.from('preferences').upsert({
      'user_id': _userId,
      'bible_versions': preferences.bibleVersions.toStoredList(),
      'tags': preferences.tagSlugs.toList()..sort(),
      'notify_time': preferences.notifyTimeLabel,
      'age_range': preferences.ageRange,
      'sex': preferences.sex,
      'life_situations': preferences.lifeSituations,
      'widget_config': {
        'notifications_enabled': preferences.notificationsEnabled,
      },
    });
  }

  bool _notificationsEnabled(Map<String, dynamic> row) {
    final config = row['widget_config'];
    if (config is Map && config['notifications_enabled'] is bool) {
      return config['notifications_enabled'] as bool;
    }
    return false;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AuthUser? _map(User? user) {
    if (user == null) return null;
    return AuthUser(id: user.id, email: user.email);
  }

  @override
  AuthUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> authState() {
    return _client.auth.onAuthStateChange.map((event) => _map(event.session?.user));
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: oauthRedirect,
    );
  }

  @override
  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: oauthRedirect,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
