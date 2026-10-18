import 'dart:math';

/// A passage anchor has to contain a letter or digit. Whitespace and
/// punctuation alone, such as a selected period, are ignored.
bool isUsableAnchor(String? text) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) return false;
  return RegExp(r'[0-9A-Za-z]').hasMatch(trimmed);
}

class DevoNote {
  const DevoNote({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.devoId,
    this.generatedDevoId,
    this.anchorText,
    this.anchorStart,
    this.anchorEnd,
    this.section,
  });

  final String id;
  final String? userId;
  final String? devoId;
  final String? generatedDevoId;
  final String body;
  final String? anchorText;
  final int? anchorStart;
  final int? anchorEnd;

  /// `hook`, `body`, `takeaway`, `verse`, or `scripture`. Null attaches the
  /// note to the whole devotion.
  final String? section;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAnchor => isUsableAnchor(anchorText);

  String get targetId => devoId ?? generatedDevoId ?? '';

  DevoNote copyWith({
    String? id,
    String? userId,
    String? devoId,
    String? generatedDevoId,
    String? body,
    String? anchorText,
    int? anchorStart,
    int? anchorEnd,
    String? section,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAnchor = false,
  }) {
    return DevoNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      devoId: devoId ?? this.devoId,
      generatedDevoId: generatedDevoId ?? this.generatedDevoId,
      body: body ?? this.body,
      anchorText: clearAnchor ? null : anchorText ?? this.anchorText,
      anchorStart: clearAnchor ? null : anchorStart ?? this.anchorStart,
      anchorEnd: clearAnchor ? null : anchorEnd ?? this.anchorEnd,
      section: clearAnchor ? null : section ?? this.section,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DevoNote.fromJson(Map<String, dynamic> json) {
    return DevoNote(
      id: json['id'].toString(),
      userId: json['user_id'] as String?,
      devoId: json['devo_id'] as String?,
      generatedDevoId: json['generated_devo_id'] as String?,
      body: json['body'] as String? ?? '',
      anchorText: json['anchor_text'] as String?,
      anchorStart: json['anchor_start'] as int?,
      anchorEnd: json['anchor_end'] as int?,
      section: json['section'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'devo_id': devoId,
    'generated_devo_id': generatedDevoId,
    'body': body,
    'anchor_text': anchorText,
    'anchor_start': anchorStart,
    'anchor_end': anchorEnd,
    'section': section,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

String newNoteId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
