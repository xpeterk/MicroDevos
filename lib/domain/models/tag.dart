class Tag {
  const Tag({
    required this.slug,
    required this.label,
    required this.category,
    this.parentSlug,
    this.isFilter = true,
  });

  final String slug;
  final String label;

  /// `topic`, `life_situation`, or `emotion`.
  final String category;

  /// Null when this tag is a filter topic, or the hierarchy is not loaded.
  final String? parentSlug;

  /// Filter-sheet topics. Child section tags stay false.
  final bool isFilter;

  factory Tag.fromJson(Map<String, dynamic> json) {
    final filter = json['is_filter'] ?? json['isFilter'];
    final parent = json['parent_slug'] ?? json['parentSlug'];
    return Tag(
      slug: json['slug'] as String,
      label: json['label'] as String,
      category: json['category'] as String? ?? 'topic',
      parentSlug: parent is String && parent.isNotEmpty ? parent : null,
      isFilter: filter is bool ? filter : true,
    );
  }
}

/// Selected filter slugs plus every child whose parent is selected.
Set<String> expandTagSelection(Set<String> selected, List<Tag> catalog) {
  if (selected.isEmpty) return selected;
  final wanted = {...selected};
  for (final tag in catalog) {
    final parent = tag.parentSlug;
    if (parent != null && selected.contains(parent)) wanted.add(tag.slug);
  }
  return wanted;
}
