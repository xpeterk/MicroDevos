import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/models/devo_note.dart';
import '../../domain/repositories/repositories.dart';

class SupabaseNotesRepository implements NotesRepository {
  const SupabaseNotesRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthUnavailable('Sign in to sync notes.');
    }
    return id;
  }

  @override
  Future<List<DevoNote>> load() async {
    final rows = await _client
        .from('notes')
        .select()
        .eq('user_id', _userId)
        .order('updated_at', ascending: false);
    return rows.map(DevoNote.fromJson).toList();
  }

  @override
  Future<void> upsert(DevoNote note) async {
    await _client.from('notes').upsert(_row(note, includeId: true));
  }

  Future<void> insertNew(DevoNote note) async {
    await _client.from('notes').insert(_row(note, includeId: false));
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('notes').delete().eq('user_id', _userId).eq('id', id);
  }

  Map<String, dynamic> _row(DevoNote note, {required bool includeId}) {
    return {
      if (includeId) 'id': note.id,
      'user_id': _userId,
      'devo_id': note.devoId,
      'generated_devo_id': note.generatedDevoId,
      'body': note.body,
      'anchor_text': note.anchorText,
      'anchor_start': note.anchorStart,
      'anchor_end': note.anchorEnd,
      'section': note.section,
    };
  }
}
