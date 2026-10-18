import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/bible/verse_provider.dart';
import '../../domain/models/bible_version.dart';

/// Crossway ESV API. Inert until [apiKey] is set.
///
/// A public app needs Crossway's license terms confirmed before shipping ESV text.
class EsvVerseProvider implements VerseProvider {
  EsvVerseProvider({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String? apiKey;
  final http.Client _client;

  @override
  BibleVersion get version => BibleVersion.esv;

  @override
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  @override
  Future<VerseText?> getVerse(String reference) async {
    if (!isConfigured) return null;
    final uri = Uri.https('api.esv.org', '/v3/passage/text/', {
      'q': reference,
      'include-headings': 'false',
      'include-footnotes': 'false',
      'include-verse-numbers': 'false',
      'include-short-copyright': 'false',
      'include-passage-references': 'false',
    });
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Token $apiKey'},
    );
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final passages = decoded['passages'];
    if (passages is! List || passages.isEmpty) return null;
    final text = passages.first.toString().trim();
    if (text.isEmpty) return null;
    return VerseText(
      reference: reference,
      text: text,
      version: BibleVersion.esv,
      source: 'crossway',
    );
  }
}
