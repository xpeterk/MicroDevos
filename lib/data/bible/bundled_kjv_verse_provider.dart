import 'dart:convert';

import '../../domain/bible/verse_provider.dart';
import '../../domain/bible/verse_reference.dart';
import '../../domain/models/bible_version.dart';

class KjvBundle {
  const KjvBundle(this.verses);

  final Map<String, String> verses;

  factory KjvBundle.parse(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return KjvBundle({
      for (final entry in decoded.entries)
        VerseReference.normalize(entry.key): entry.value as String,
    });
  }

  String? lookup(String reference) {
    final key = VerseReference.normalize(reference);
    final direct = verses[key];
    if (direct != null) return direct;
    final range = RegExp(r'^(.*)\s+(\d+):(\d+)-(\d+)$').firstMatch(key);
    if (range == null) return null;
    final book = range.group(1)!;
    final chapter = range.group(2)!;
    final start = int.parse(range.group(3)!);
    final end = int.parse(range.group(4)!);
    final parts = <String>[];
    for (var verse = start; verse <= end; verse++) {
      final text = verses['$book $chapter:$verse'];
      if (text == null) return null;
      parts.add(text);
    }
    return parts.join(' ');
  }
}

class BundledKjvVerseProvider implements VerseProvider {
  const BundledKjvVerseProvider(this.bundle);

  final KjvBundle bundle;

  @override
  BibleVersion get version => BibleVersion.kjv;

  @override
  bool get isConfigured => true;

  @override
  Future<VerseText?> getVerse(String reference) async {
    final text = bundle.lookup(reference);
    if (text == null || text.trim().isEmpty) return null;
    return VerseText(
      reference: reference,
      text: text.trim(),
      version: BibleVersion.kjv,
      source: 'bundle',
    );
  }
}
