import 'bible_version.dart';

class UserPreferences {
  const UserPreferences({
    required this.bibleVersions,
    required this.tagSlugs,
    required this.notificationsEnabled,
    required this.notifyHour,
    required this.notifyMinute,
    this.ageRange,
    this.sex,
    this.lifeSituations = const [],
  });

  factory UserPreferences.initial() {
    return const UserPreferences(
      bibleVersions: BibleVersionSelection(
        enabled: {BibleVersion.kjv},
        readingVersion: BibleVersion.kjv,
      ),
      tagSlugs: {},
      notificationsEnabled: false,
      notifyHour: 7,
      notifyMinute: 30,
    );
  }

  final BibleVersionSelection bibleVersions;
  final Set<String> tagSlugs;
  final bool notificationsEnabled;
  final int notifyHour;
  final int notifyMinute;
  final String? ageRange;
  final String? sex;
  final List<String> lifeSituations;

  String get notifyTimeLabel {
    final hour = notifyHour.toString().padLeft(2, '0');
    final minute = notifyMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  UserPreferences copyWith({
    BibleVersionSelection? bibleVersions,
    Set<String>? tagSlugs,
    bool? notificationsEnabled,
    int? notifyHour,
    int? notifyMinute,
    String? ageRange,
    String? sex,
    List<String>? lifeSituations,
    bool clearAgeRange = false,
    bool clearSex = false,
  }) {
    return UserPreferences(
      bibleVersions: bibleVersions ?? this.bibleVersions,
      tagSlugs: tagSlugs ?? this.tagSlugs,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      ageRange: clearAgeRange ? null : ageRange ?? this.ageRange,
      sex: clearSex ? null : sex ?? this.sex,
      lifeSituations: lifeSituations ?? this.lifeSituations,
    );
  }

  Map<String, dynamic> toJson() => {
    'bible_versions': bibleVersions.toStoredList(),
    'tags': tagSlugs.toList()..sort(),
    'notifications_enabled': notificationsEnabled,
    'notify_time': notifyTimeLabel,
    'age_range': ageRange,
    'sex': sex,
    'life_situations': lifeSituations,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final time = (json['notify_time'] as String?) ?? '07:30';
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 7 : 7;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
    final versions = (json['bible_versions'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return UserPreferences(
      bibleVersions: BibleVersionSelection.fromStored(versions),
      tagSlugs: (json['tags'] as List<dynamic>? ?? const []).map((item) => item.toString()).toSet(),
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      notifyHour: hour.clamp(0, 23),
      notifyMinute: minute.clamp(0, 59),
      ageRange: json['age_range'] as String?,
      sex: json['sex'] as String?,
      lifeSituations: (json['life_situations'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
