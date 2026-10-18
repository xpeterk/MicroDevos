class Tag {
  const Tag({
    required this.slug,
    required this.label,
    required this.category,
  });

  final String slug;
  final String label;

  /// `topic`, `life_situation`, or `emotion`.
  final String category;

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      slug: json['slug'] as String,
      label: json['label'] as String,
      category: json['category'] as String? ?? 'topic',
    );
  }
}
