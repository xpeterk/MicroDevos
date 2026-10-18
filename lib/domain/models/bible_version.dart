/// Translations a reader can turn on.
///
/// ESV and NIV are the featured choices (checkboxes in preferences). KJV is
/// bundled and works offline. The other popular translations are available in
/// Settings and are fetched through API.Bible when that account is configured.
enum BibleVersion {
  esv('esv', 'ESV', 'English Standard Version'),
  niv('niv', 'NIV', 'New International Version'),
  kjv('kjv', 'KJV', 'King James Version'),
  nlt('nlt', 'NLT', 'New Living Translation'),
  nkjv('nkjv', 'NKJV', 'New King James Version'),
  csb('csb', 'CSB', 'Christian Standard Bible'),
  nasb('nasb', 'NASB', 'New American Standard Bible');

  const BibleVersion(this.id, this.shortLabel, this.fullName);

  final String id;
  final String shortLabel;
  final String fullName;

  static const featured = <BibleVersion>[esv, niv];

  static const additional = <BibleVersion>[kjv, nlt, nkjv, csb, nasb];

  /// Order used when more than one translation is on and no reading choice sticks.
  static const displayOrder = <BibleVersion>[
    esv,
    niv,
    kjv,
    nlt,
    nkjv,
    csb,
    nasb,
  ];

  bool get isBundled => this == kjv;

  bool get usesCrossway => this == esv;

  bool get usesApiBible => !isBundled && !usesCrossway;

  static BibleVersion? tryParse(String raw) {
    final key = raw.trim().toLowerCase();
    for (final version in values) {
      if (version.id == key || version.shortLabel.toLowerCase() == key) {
        return version;
      }
    }
    return null;
  }
}

/// Which translations are enabled, and which one verses render in.
///
/// The stored list keeps the reading translation first. At least one
/// translation stays on, and KJV is the offline default.
class BibleVersionSelection {
  const BibleVersionSelection({
    required this.enabled,
    this.readingVersion,
  });

  factory BibleVersionSelection.initial() {
    return const BibleVersionSelection(
      enabled: {BibleVersion.kjv},
      readingVersion: BibleVersion.kjv,
    );
  }

  factory BibleVersionSelection.fromStored(List<String> raw) {
    final parsed = <BibleVersion>[];
    for (final entry in raw) {
      final version = BibleVersion.tryParse(entry);
      if (version != null && !parsed.contains(version)) {
        parsed.add(version);
      }
    }
    if (parsed.isEmpty) return BibleVersionSelection.initial();
    return BibleVersionSelection(
      enabled: parsed.toSet(),
      readingVersion: parsed.first,
    );
  }

  final Set<BibleVersion> enabled;
  final BibleVersion? readingVersion;

  bool get isFeaturedChoice => BibleVersion.featured.contains(reading);

  BibleVersion get reading {
    final preferred = readingVersion;
    if (preferred != null && enabled.contains(preferred)) return preferred;
    for (final version in BibleVersion.displayOrder) {
      if (enabled.contains(version)) return version;
    }
    return BibleVersion.kjv;
  }

  bool canDisable(BibleVersion version) {
    return !(enabled.contains(version) && enabled.length == 1);
  }

  /// Adds or removes a translation. The last remaining one cannot be removed.
  /// Checking a translation makes it the reading translation.
  BibleVersionSelection toggle(BibleVersion version) {
    if (enabled.contains(version)) {
      if (!canDisable(version)) return this;
      final next = {...enabled}..remove(version);
      final nextReading = readingVersion == version ? null : readingVersion;
      return BibleVersionSelection(enabled: next, readingVersion: nextReading);
    }
    return BibleVersionSelection(
      enabled: {...enabled, version},
      readingVersion: version,
    );
  }

  BibleVersionSelection withReading(BibleVersion version) {
    if (!enabled.contains(version)) return this;
    return BibleVersionSelection(enabled: enabled, readingVersion: version);
  }

  /// Reading translation first, then the rest in display order.
  List<String> toStoredList() {
    final current = reading;
    final rest = BibleVersion.displayOrder.where(
      (version) => enabled.contains(version) && version != current,
    );
    return [current.id, ...rest.map((version) => version.id)];
  }

  @override
  bool operator ==(Object other) {
    return other is BibleVersionSelection &&
        other.reading == reading &&
        other.enabled.length == enabled.length &&
        other.enabled.containsAll(enabled);
  }

  @override
  int get hashCode => Object.hash(reading, Object.hashAll(BibleVersion.displayOrder.where(enabled.contains)));
}
