import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/devo_order.dart';
import '../../domain/edition_calendar.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/devo_section.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/repositories/repositories.dart';
import 'supabase_mappers.dart';

const oauthRedirect = 'com.microdevos.microdevos://login-callback';

class SupabaseDevoRepository implements DevoRepository {
  const SupabaseDevoRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, title, hook, body_md, takeaway, verse_text, verse_ref, scriptures, source_url, edition_date, edition_url, position, stars, status, notion_page_id, image_url, image_alt, devo_tags(tags(slug, label))';

  static const _columnsV6 = '$_columns, teaser, prayer';

  static const _columnsOneMinute =
      '$_columnsV6, one_minute_text, one_minute_verse_ref, one_minute_verse_text, one_minute_today';

  /// False after a read against a database that has not added one-minute columns.
  static var includeOneMinuteColumns = true;

  /// False after a read against a database that has not added teaser and prayer.
  static var includeV6Columns = true;

  String get _activeColumns {
    if (includeOneMinuteColumns) return _columnsOneMinute;
    if (includeV6Columns) return _columnsV6;
    return _columns;
  }

  Future<T> _read<T>(Future<T> Function(String columns) run) async {
    try {
      return await run(_activeColumns);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final missingOneMinute =
          message.contains('one_minute') ||
          (includeOneMinuteColumns && message.contains('column'));
      if (includeOneMinuteColumns && missingOneMinute) {
        includeOneMinuteColumns = false;
        return _read(run);
      }
      final missingColumn =
          message.contains('teaser') ||
          message.contains('prayer') ||
          message.contains('column');
      if (!includeV6Columns || !missingColumn) rethrow;
      includeV6Columns = false;
      return run(_columns);
    }
  }

  @override
  Future<Devo?> devoById(String id) async {
    final row = await _read(
      (columns) => _client
          .from('devos')
          .select(columns)
          .eq('id', id)
          .inFilter('status', readerDevoStatuses)
          .maybeSingle(),
    );
    if (row == null) return null;
    final devo = devoFromRow(row);
    final withSections = await _attachSections([devo]);
    return withSections.single;
  }

  @override
  Future<List<Devo>> devosForDate(DateTime date) async {
    final rows = await _read(
      (columns) => _client
          .from('devos')
          .select(columns)
          .eq('edition_date', dateKeyOf(date))
          .inFilter('status', readerDevoStatuses)
          .order('position', ascending: true),
    );
    return devosInReadingOrder(await _attachSections(rows.map(devoFromRow)));
  }

  @override
  Future<List<DateTime>> editionDates() async {
    final rows = await _client
        .from('devos')
        .select('edition_date')
        .inFilter('status', readerDevoStatuses)
        .order('edition_date', ascending: false)
        .limit(5000);
    final dates = <String, DateTime>{};
    for (final row in rows) {
      final raw = row['edition_date'];
      if (raw == null) continue;
      final date = parseDateOnly(raw.toString());
      dates[dateKeyOf(date)] = date;
    }
    final list = dates.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  @override
  Future<List<Devo>> search({String text = '', DateTime? date}) async {
    final rows = await _read((columns) async {
      var filter = _client
          .from('devos')
          .select(columns)
          .inFilter('status', readerDevoStatuses);
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
      return filter
          .order('edition_date', ascending: false)
          .order('position', ascending: true);
    });
    return devosInReadingOrder(await _attachSections(rows.map(devoFromRow)));
  }

  static const _sectionColumns =
      'id, devo_id, position, title, summary, minutes, verse_ref, verse_text, body, section_tags(tags(slug))';

  static const _sectionColumnsWithImages =
      'id, devo_id, position, title, summary, minutes, verse_ref, verse_text, body, image_url, image_alt, section_tags(tags(slug))';

  /// False after a read against a database that has not added section images.
  static var includeSectionImages = true;

  /// Missing table (migration not applied yet) leaves devotions without sections.
  /// Missing image columns retry without them so sections still load.
  Future<List<Devo>> _attachSections(Iterable<Devo> devos) async {
    final list = devos.toList();
    if (list.isEmpty) return list;
    try {
      final rows = await _selectSections(list);
      final grouped = <String, List<DevoSection>>{};
      for (final row in rows) {
        final devoId = row['devo_id']?.toString() ?? '';
        final section = DevoSection.fromJson(
          Map<String, dynamic>.from(row),
          devoId: devoId,
        ).copyWith(tags: tagsFromJoin(row['section_tags']));
        grouped.putIfAbsent(devoId, () => []).add(section);
      }
      return [
        for (final devo in list)
          grouped[devo.id] == null
              ? devo
              : devo.copyWith(sections: grouped[devo.id]!),
      ];
    } catch (_) {
      return list;
    }
  }

  Future<List<Map<String, dynamic>>> _selectSections(List<Devo> list) async {
    final ids = list.map((devo) => devo.id).toList();
    final columns = includeSectionImages
        ? _sectionColumnsWithImages
        : _sectionColumns;
    try {
      final rows = await _client
          .from('devo_sections')
          .select(columns)
          .inFilter('devo_id', ids)
          .order('position', ascending: true);
      return rows;
    } catch (error) {
      final message = error.toString().toLowerCase();
      final missingImage =
          includeSectionImages &&
          (message.contains('image_url') || message.contains('image_alt'));
      if (!missingImage) rethrow;
      includeSectionImages = false;
      final rows = await _client
          .from('devo_sections')
          .select(_sectionColumns)
          .inFilter('devo_id', ids)
          .order('position', ascending: true);
      return rows;
    }
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
    try {
      final rows = await _client
          .from('favorites')
          .select('devo_id, section_id')
          .eq('user_id', _userId)
          .isFilter('section_id', null)
          .not('devo_id', 'is', null);
      return favoriteIdsFromRows(rows);
    } catch (_) {
      final rows = await _client
          .from('favorites')
          .select('devo_id')
          .eq('user_id', _userId)
          .not('devo_id', 'is', null);
      return favoriteIdsFromRows(rows);
    }
  }

  @override
  Future<void> setFavorite(String devoId, bool favorite) async {
    try {
      if (favorite) {
        await _client.from('favorites').insert({
          'user_id': _userId,
          'devo_id': devoId,
          'section_id': null,
        });
        return;
      }
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', _userId)
          .eq('devo_id', devoId)
          .isFilter('section_id', null);
    } catch (_) {
      if (favorite) {
        await _client.from('favorites').upsert({
          'user_id': _userId,
          'devo_id': devoId,
        }, onConflict: 'user_id,devo_id');
        return;
      }
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', _userId)
          .eq('devo_id', devoId);
    }
  }
}

class SupabaseSectionFavoritesRepository implements SectionFavoritesRepository {
  const SupabaseSectionFavoritesRepository(this._client, this._local);

  final SupabaseClient _client;
  final SectionFavoritesRepository _local;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<SectionFavorite>> load() async {
    final userId = _userId;
    if (userId == null) return _local.load();
    try {
      final rows = await _client
          .from('favorites')
          .select('devo_id, section_id')
          .eq('user_id', userId)
          .not('section_id', 'is', null);
      return [
        for (final row in rows)
          if (row['section_id'] != null && row['devo_id'] != null)
            SectionFavorite(
              devoId: row['devo_id'].toString(),
              sectionId: row['section_id'].toString(),
            ),
      ];
    } catch (_) {
      return _local.load();
    }
  }

  @override
  Future<void> setFavorite(
    String devoId,
    String sectionId,
    bool favorite,
  ) async {
    final userId = _userId;
    if (userId == null) {
      await _local.setFavorite(devoId, sectionId, favorite);
      return;
    }
    try {
      if (!favorite) {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('section_id', sectionId);
        return;
      }
      await _client.from('favorites').insert({
        'user_id': userId,
        'devo_id': devoId,
        'section_id': sectionId,
      });
    } catch (_) {
      await _local.setFavorite(devoId, sectionId, favorite);
    }
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
    final row = await _client
        .from('preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
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
    return _client.auth.onAuthStateChange.map(
      (event) => _map(event.session?.user),
    );
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
