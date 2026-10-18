class VerseReference {
  const VerseReference(this.normalized);

  final String normalized;

  static const aliases = <String, String>{
    'gen': 'genesis',
    'exo': 'exodus',
    'exod': 'exodus',
    'lev': 'leviticus',
    'num': 'numbers',
    'deut': 'deuteronomy',
    'jos': 'joshua',
    'josh': 'joshua',
    'jdg': 'judges',
    'judg': 'judges',
    'ru': 'ruth',
    '1 sam': '1 samuel',
    '2 sam': '2 samuel',
    '1 kgs': '1 kings',
    '2 kgs': '2 kings',
    '1 chr': '1 chronicles',
    '2 chr': '2 chronicles',
    'neh': 'nehemiah',
    'ps': 'psalm',
    'psa': 'psalm',
    'psalm': 'psalm',
    'psalms': 'psalm',
    'prov': 'proverbs',
    'eccl': 'ecclesiastes',
    'song': 'song of solomon',
    'isa': 'isaiah',
    'jer': 'jeremiah',
    'lam': 'lamentations',
    'ezek': 'ezekiel',
    'dan': 'daniel',
    'hos': 'hosea',
    'obad': 'obadiah',
    'mic': 'micah',
    'hab': 'habakkuk',
    'zeph': 'zephaniah',
    'hag': 'haggai',
    'zech': 'zechariah',
    'mal': 'malachi',
    'matt': 'matthew',
    'mt': 'matthew',
    'mk': 'mark',
    'lk': 'luke',
    'jn': 'john',
    'rom': 'romans',
    '1 cor': '1 corinthians',
    '2 cor': '2 corinthians',
    'gal': 'galatians',
    'eph': 'ephesians',
    'phil': 'philippians',
    'col': 'colossians',
    '1 thess': '1 thessalonians',
    '2 thess': '2 thessalonians',
    '1 tim': '1 timothy',
    '2 tim': '2 timothy',
    'tit': 'titus',
    'phlm': 'philemon',
    'heb': 'hebrews',
    'jas': 'james',
    '1 pet': '1 peter',
    '2 pet': '2 peter',
    '1 jn': '1 john',
    '2 jn': '2 john',
    '3 jn': '3 john',
    'rev': 'revelation',
  };

  /// Canonical key: lowercase, abbreviations expanded, single spaces.
  /// "Matt 5:14" and "Matthew 5:14" both become "matthew 5:14".
  static String normalize(String reference) {
    var text = reference.trim().toLowerCase();
    text = text.replaceAll('.', '');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s+(esv|niv|kjv|nlt|nkjv|csb|nasb)$'), '');
    final match = RegExp(r'^(.*)\s+(\d+:\d+(?:-\d+)?)$').firstMatch(text);
    if (match == null) return text;
    final book = _expandBook(match.group(1)!.trim());
    return '$book ${match.group(2)}';
  }

  static String _expandBook(String book) {
    return aliases[book] ?? book;
  }
}
