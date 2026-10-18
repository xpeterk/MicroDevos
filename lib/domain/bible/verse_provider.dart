import '../models/bible_version.dart';

class VerseText {
  const VerseText({
    required this.reference,
    required this.text,
    required this.version,
    required this.source,
  });

  final String reference;
  final String text;
  final BibleVersion version;

  /// `bundle`, `crossway`, or `api.bible`.
  final String source;
}

class ResolvedVerse {
  const ResolvedVerse({
    required this.text,
    required this.reference,
    this.version,
    this.requested,
    this.note,
  });

  final String text;
  final String reference;
  final BibleVersion? version;
  final BibleVersion? requested;
  final String? note;

  bool get usedFallback => requested != null && version != requested;
}

/// Looks up one translation. Implementations return null when the verse is
/// missing or the provider is not configured.
abstract class VerseProvider {
  BibleVersion get version;

  /// False when a required API key or Bible id is absent.
  bool get isConfigured;

  Future<VerseText?> getVerse(String reference);
}

class VerseCatalog {
  const VerseCatalog(this.providers);

  final Map<BibleVersion, VerseProvider> providers;

  Future<ResolvedVerse> resolve({
    required String reference,
    required String fallbackText,
    required BibleVersionSelection selection,
  }) async {
    final requested = selection.reading;
    final order = <BibleVersion>[
      requested,
      ...BibleVersion.displayOrder.where(
        (version) => selection.enabled.contains(version) && version != requested,
      ),
    ];
    for (final version in order) {
      final provider = providers[version];
      if (provider == null || !provider.isConfigured) continue;
      final verse = await provider.getVerse(reference);
      if (verse == null || verse.text.trim().isEmpty) continue;
      return ResolvedVerse(
        text: verse.text.trim(),
        reference: reference,
        version: version,
        requested: requested,
        note: version == requested
            ? null
            : 'Shown in ${version.shortLabel}. ${requested.shortLabel} needs an API key.',
      );
    }
    return ResolvedVerse(
      text: fallbackText,
      reference: reference,
      requested: requested,
      note: requested.isBundled
          ? null
          : 'Shown from the edition text. ${requested.shortLabel} needs an API key.',
    );
  }
}
