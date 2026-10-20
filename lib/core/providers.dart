import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../data/bible/api_bible_verse_provider.dart';
import '../data/bible/bundled_kjv_verse_provider.dart';
import '../data/bible/esv_verse_provider.dart';
import '../data/enrichment/disabled_embedding_provider.dart';
import '../data/enrichment/keyword_tagging_provider.dart';
import '../data/sample/local_notes_repository.dart';
import '../data/sample/local_preferences_repository.dart';
import '../data/sample/sample_catalog.dart';
import '../data/sample/sample_devo_repository.dart';
import '../data/supabase/supabase_notes_repository.dart';
import '../data/supabase/supabase_repositories.dart';
import '../domain/bible/verse_provider.dart';
import '../domain/edition_calendar.dart';
import '../domain/enrichment/embedding_provider.dart';
import '../domain/enrichment/tagging_provider.dart';
import '../domain/models/bible_version.dart';
import '../domain/models/devo.dart';
import '../domain/models/devo_note.dart';
import '../domain/models/user_preferences.dart';
import '../domain/repositories/repositories.dart';
import 'config/app_config.dart';
import 'notifications/reminder_service.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences was not initialized'),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final sampleCatalogProvider = FutureProvider<SampleCatalog>((ref) async {
  throw StateError('Sample catalog was not loaded');
});

final kjvBundleProvider = FutureProvider<KjvBundle>((ref) async {
  throw StateError('KJV bundle was not loaded');
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => LocalReminderService(),
);

/// Disabled on purpose. A later milestone can override this with a configured
/// provider. The default never calls a model.
final embeddingProvider = Provider<EmbeddingProvider>(
  (ref) => const DisabledEmbeddingProvider(),
);

/// Local whole-word match against the tag catalog. No model call.
final taggingProvider = Provider<TaggingProvider>(
  (ref) => const KeywordTaggingProvider(),
);

final devoRepositoryProvider = FutureProvider<DevoRepository>((ref) async {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  if (config.useSupabase && client != null) {
    return SupabaseDevoRepository(client);
  }
  final catalog = await ref.watch(sampleCatalogProvider.future);
  return SampleDevoRepository(catalog);
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client?.auth.currentUser;
  if (config.useSupabase && client != null && user != null) {
    return SupabaseFavoritesRepository(client);
  }
  return LocalFavoritesRepository(ref.watch(sharedPreferencesProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client?.auth.currentUser;
  if (config.useSupabase && client != null && user != null) {
    return SupabasePreferencesRepository(client);
  }
  return LocalPreferencesRepository(ref.watch(sharedPreferencesProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  if (config.useSupabase && client != null) {
    return SupabaseAuthRepository(client);
  }
  return UnavailableAuthRepository();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final verseCatalogProvider = FutureProvider<VerseCatalog>((ref) async {
  final config = ref.watch(appConfigProvider);
  final bundle = await ref.watch(kjvBundleProvider.future);
  return VerseCatalog({
    BibleVersion.kjv: BundledKjvVerseProvider(bundle),
    BibleVersion.esv: EsvVerseProvider(apiKey: config.esvApiKey),
    BibleVersion.niv: ApiBibleVerseProvider(
      version: BibleVersion.niv,
      apiKey: config.apiBibleKey,
      bibleId: config.bibleIdFor(BibleVersion.niv),
    ),
    BibleVersion.nlt: ApiBibleVerseProvider(
      version: BibleVersion.nlt,
      apiKey: config.apiBibleKey,
      bibleId: config.bibleIdFor(BibleVersion.nlt),
    ),
    BibleVersion.nkjv: ApiBibleVerseProvider(
      version: BibleVersion.nkjv,
      apiKey: config.apiBibleKey,
      bibleId: config.bibleIdFor(BibleVersion.nkjv),
    ),
    BibleVersion.csb: ApiBibleVerseProvider(
      version: BibleVersion.csb,
      apiKey: config.apiBibleKey,
      bibleId: config.bibleIdFor(BibleVersion.csb),
    ),
    BibleVersion.nasb: ApiBibleVerseProvider(
      version: BibleVersion.nasb,
      apiKey: config.apiBibleKey,
      bibleId: config.bibleIdFor(BibleVersion.nasb),
    ),
  });
});

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.read(sharedPreferencesProvider).setString(_key, stored);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class SelectedEditionController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime? date) => state = date;
}

final selectedEditionProvider =
    NotifierProvider<SelectedEditionController, DateTime?>(
      SelectedEditionController.new,
    );

class TodaySnapshot {
  const TodaySnapshot({
    required this.edition,
    required this.devos,
    required this.isFallback,
    required this.dates,
  });

  final DateTime? edition;
  final List<Devo> devos;
  final bool isFallback;
  final List<DateTime> dates;
}

final todayProvider = FutureProvider<TodaySnapshot>((ref) async {
  final repo = await ref.watch(devoRepositoryProvider.future);
  final selected = ref.watch(selectedEditionProvider);
  final dates = await repo.editionDates();
  final today = ref.watch(clockProvider)();
  final edition = resolveEditionDate(
    today: today,
    editions: dates,
    selected: selected,
  );
  final devos = edition == null ? <Devo>[] : await repo.devosForDate(edition);
  return TodaySnapshot(
    edition: edition,
    devos: devos,
    isFallback:
        edition != null &&
        editionIsFallback(
          today: today,
          edition: edition,
          readerChoseDate: selected != null,
        ),
    dates: dates,
  );
});

class ArchiveQuery {
  const ArchiveQuery({this.text = '', this.date});

  final String text;
  final DateTime? date;

  ArchiveQuery copyWith({
    String? text,
    DateTime? date,
    bool clearDate = false,
  }) {
    return ArchiveQuery(
      text: text ?? this.text,
      date: clearDate ? null : date ?? this.date,
    );
  }
}

class ArchiveQueryController extends Notifier<ArchiveQuery> {
  @override
  ArchiveQuery build() => const ArchiveQuery();

  void setText(String text) => state = state.copyWith(text: text);

  void setDate(DateTime? date) {
    state = date == null
        ? state.copyWith(clearDate: true)
        : state.copyWith(date: date);
  }
}

final archiveQueryProvider =
    NotifierProvider<ArchiveQueryController, ArchiveQuery>(
      ArchiveQueryController.new,
    );

final archiveProvider = FutureProvider<List<Devo>>((ref) async {
  final repo = await ref.watch(devoRepositoryProvider.future);
  final query = ref.watch(archiveQueryProvider);
  return repo.search(text: query.text, date: query.date);
});

final editionDatesProvider = FutureProvider<List<DateTime>>((ref) async {
  final repo = await ref.watch(devoRepositoryProvider.future);
  return repo.editionDates();
});

final tagCatalogProvider = FutureProvider<SampleCatalog>((ref) {
  return ref.watch(sampleCatalogProvider.future);
});

class FavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    ref.watch(authStateProvider);
    return ref.watch(favoritesRepositoryProvider).load();
  }

  Future<void> toggle(String id) async {
    final repo = ref.read(favoritesRepositoryProvider);
    final current = {...state.value ?? await future};
    final nextFavorite = !current.contains(id);
    if (nextFavorite) {
      current.add(id);
    } else {
      current.remove(id);
    }
    state = AsyncData(current);
    await repo.setFavorite(id, nextFavorite);
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
      FavoritesController.new,
    );

class PreferencesController extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() {
    ref.watch(authStateProvider);
    return ref.watch(preferencesRepositoryProvider).load();
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    state = AsyncData(preferences);
    await ref.read(preferencesRepositoryProvider).save(preferences);
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, UserPreferences>(
      PreferencesController.new,
    );

final devoByIdProvider = FutureProvider.family<Devo?, String>((ref, id) async {
  final repo = await ref.watch(devoRepositoryProvider.future);
  return repo.devoById(id);
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client?.auth.currentUser;
  final local = LocalNotesRepository(ref.watch(sharedPreferencesProvider));
  if (config.useSupabase && client != null && user != null) {
    return SyncingNotesRepository(
      local: local,
      remote: SupabaseNotesRepository(client),
    );
  }
  return local;
});

class NotesController extends AsyncNotifier<List<DevoNote>> {
  @override
  Future<List<DevoNote>> build() {
    ref.watch(authStateProvider);
    return ref.watch(notesRepositoryProvider).load();
  }

  Future<void> save(DevoNote note) async {
    final repo = ref.read(notesRepositoryProvider);
    final now = DateTime.now().toUtc();
    final current = [...state.value ?? await future];
    final existing = current.where((item) => item.id == note.id).firstOrNull;
    final stored = note.copyWith(
      id: note.id.isEmpty ? newNoteId() : note.id,
      createdAt: existing?.createdAt ?? note.createdAt,
      updatedAt: now,
    );
    final next = [stored, ...current.where((item) => item.id != stored.id)];
    state = AsyncData(next);
    await repo.upsert(stored);
  }

  Future<void> delete(String id) async {
    final repo = ref.read(notesRepositoryProvider);
    final current = [...state.value ?? await future]
      ..removeWhere((item) => item.id == id);
    state = AsyncData(current);
    await repo.delete(id);
  }
}

final notesProvider = AsyncNotifierProvider<NotesController, List<DevoNote>>(
  NotesController.new,
);
