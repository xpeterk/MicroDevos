import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/devo_note.dart';
import '../../domain/repositories/repositories.dart';
import '../supabase/supabase_notes_repository.dart';

class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository(this._prefs);

  static const storageKey = 'devo_notes';

  final SharedPreferences _prefs;

  @override
  Future<List<DevoNote>> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final notes = decoded
        .whereType<Map>()
        .map((item) => DevoNote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Future<void> upsert(DevoNote note) async {
    final notes = await load();
    final next = [note, ...notes.where((item) => item.id != note.id)];
    await _write(next);
  }

  @override
  Future<void> delete(String id) async {
    final notes = await load();
    await _write(notes.where((item) => item.id != id).toList());
  }

  Future<void> replace(List<DevoNote> notes) => _write(notes);

  Future<void> _write(List<DevoNote> notes) async {
    await _prefs.setString(
      storageKey,
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
  }
}

/// Signed-in notes live in Supabase. Local notes whose devotion id is a real
/// uuid are pushed once; sample ids such as `fri-1` stay on the device.
class SyncingNotesRepository implements NotesRepository {
  SyncingNotesRepository({required this.local, required this.remote});

  final LocalNotesRepository local;
  final SupabaseNotesRepository remote;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<List<DevoNote>> load() async {
    await _pushLocal();
    return remote.load();
  }

  @override
  Future<void> upsert(DevoNote note) => remote.upsert(note);

  @override
  Future<void> delete(String id) => remote.delete(id);

  Future<void> _pushLocal() async {
    final notes = await local.load();
    final keep = <DevoNote>[];
    for (final note in notes) {
      final target = note.devoId ?? note.generatedDevoId ?? '';
      if (!_uuid.hasMatch(target)) {
        keep.add(note);
        continue;
      }
      try {
        await remote.insertNew(note);
      } catch (_) {
        keep.add(note);
      }
    }
    await local.replace(keep);
  }
}
