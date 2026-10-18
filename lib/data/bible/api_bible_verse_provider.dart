import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/bible/verse_provider.dart';
import '../../domain/models/bible_version.dart';

/// API.Bible lookup for NIV, NLT, NKJV, CSB, and NASB.
///
/// Each translation needs the Bible id from the API.Bible account
/// (`API_BIBLE_ID_NIV` and the matching keys). Publisher approval is separate
/// from having a key.
class ApiBibleVerseProvider implements VerseProvider {
  ApiBibleVerseProvider({
    required this.version,
    required this.apiKey,
    required this.bibleId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final BibleVersion version;

  final String? apiKey;
  final String? bibleId;
  final http.Client _client;

  @override
  bool get isConfigured =>
      apiKey != null &&
      apiKey!.isNotEmpty &&
      bibleId != null &&
      bibleId!.isNotEmpty;

  @override
  Future<VerseText?> getVerse(String reference) async {
    if (!isConfigured) return null;
    final uri = Uri.https('rest.api.bible', '/v1/bibles/$bibleId/search', {
      'query': reference,
      'limit': '1',
    });
    final response = await _client.get(uri, headers: {'api-key': apiKey!});
    if (response.statusCode != 200) return null;
    final text = _textFrom(jsonDecode(response.body));
    if (text == null || text.isEmpty) return null;
    return VerseText(
      reference: reference,
      text: text,
      version: version,
      source: 'api.bible',
    );
  }

  static String? _textFrom(Object? decoded) {
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is! Map) return null;
    final verses = data['verses'];
    if (verses is List && verses.isNotEmpty && verses.first is Map) {
      final verse = verses.first as Map;
      final text = verse['text'] ?? verse['content'];
      if (text != null) return _stripTags(text.toString());
    }
    final passages = data['passages'];
    if (passages is List && passages.isNotEmpty && passages.first is Map) {
      final passage = passages.first as Map;
      final content = passage['content'] ?? passage['text'];
      if (content != null) return _stripTags(content.toString());
    }
    return null;
  }

  static String _stripTags(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
