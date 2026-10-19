import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/generated_devo.dart';
import '../../domain/personalize/personalize_engine.dart';

/// Calls the generate-devo edge function. Sample mode never constructs this.
class GenerateDevoClient {
  GenerateDevoClient(this._client);

  final SupabaseClient _client;

  Future<Object> generate(GenerateRequest request) async {
    try {
      final response = await _client.functions.invoke(
        'generate-devo',
        body: {
          'source': request.verseMode ? 'verse' : 'topic',
          'topic': request.topic,
          'verse_refs': request.verseRefs,
          'style_key': request.styleKey,
          'age_range': request.ageRange,
          'life_situations': request.lifeSituations,
          'bible_version': request.bibleVersion,
          'regenerate': request.regenerate,
        },
      );
      return _ok(response.data);
    } on FunctionException catch (error) {
      return _blocked(error);
    }
  }

  Object _ok(Object? data) {
    if (data is! Map) return _reason('The generator returned an empty result');
    final map = Map<String, dynamic>.from(data);
    final devo = map['devo'];
    if (devo is! Map) return _reason('The generator returned an empty result');
    return GenerateOk(
      devo: GeneratedDevo.fromJson(Map<String, dynamic>.from(devo)),
      cacheHit: map['cache_hit'] == true,
      cap: _cap(map['cap'], allowed: true),
    );
  }

  GenerateBlocked _blocked(FunctionException error) {
    final details = error.details;
    final map = details is Map ? Map<String, dynamic>.from(details) : null;
    final reason = map?['error'] as String? ??
        error.reasonPhrase ??
        'Generation is not available';
    return GenerateBlocked(cap: _cap(map, allowed: false, reason: reason));
  }

  CapSnapshot _cap(Object? raw, {required bool allowed, String? reason}) {
    final cap = raw is Map ? raw : const {};
    final used = (cap['used'] as num?)?.toInt() ?? 0;
    final weekly = (cap['weekly_cap'] as num?)?.toInt() ??
        (cap['weekly'] as num?)?.toInt() ??
        5;
    return CapSnapshot(
      usedThisWeek: used,
      weeklyCap: weekly,
      monthSpendUsd: (cap['spend'] as num?)?.toDouble() ?? 0,
      monthlyCeilingUsd: (cap['ceiling'] as num?)?.toDouble() ?? 25,
      allowed: allowed,
      reason: reason,
    );
  }

  GenerateBlocked _reason(String reason) {
    return GenerateBlocked(cap: _cap(null, allowed: false, reason: reason));
  }
}
