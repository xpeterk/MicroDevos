import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/tag.dart';
import 'browse_state.dart';

Future<void> openFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return const FractionallySizedBox(
        heightFactor: 0.92,
        child: FilterSheet(),
      );
    },
  );
}

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(browseFilterProvider);
    final catalog = ref.watch(tagCatalogProvider).asData?.value;
    final tags = catalog?.tags ?? const <Tag>[];
    final filters = [
      for (final tag in tags)
        if (tag.isFilter) tag,
    ];
    final emotions = [
      for (final tag in filters)
        if (tag.category == 'emotion') tag,
    ];
    final interests = [
      for (final tag in filters)
        if (tag.category == 'topic' || tag.category == 'life_situation') tag,
    ];
    final today = ref.watch(todayProvider).asData?.value;
    final liked = ref.watch(favoritesProvider).value ?? const <String>{};
    final noted = (ref.watch(notesProvider).value ?? const [])
        .map((note) => note.devoId)
        .whereType<String>()
        .toSet();
    final count = today == null
        ? 0
        : applyBrowseFilter(
            devos: today.devos,
            filter: filter,
            likedIds: liked,
            notedIds: noted,
            catalog: tags,
          ).length;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outline,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              _SwitchRow(
                icon: Icons.favorite_border,
                title: 'Show only liked',
                subtitle: 'Same list as the Saved tab.',
                value: filter.onlyLiked,
                onChanged: (value) =>
                    ref.read(browseFilterProvider.notifier).setOnlyLiked(value),
                switchKey: const Key('show-only-liked'),
              ),
              const SizedBox(height: 18),
              _SectionLabel('Tags', trailing: '${filter.tags.length} selected'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in emotions)
                    FilterChip(
                      key: ValueKey('filter-tag-${tag.slug}'),
                      label: Text(tag.label),
                      selected: filter.tags.contains(tag.slug),
                      onSelected: (_) {
                        final notifier = ref.read(
                          browseFilterProvider.notifier,
                        );
                        if (filter.tags.contains(tag.slug)) {
                          notifier.removeTag(tag.slug);
                        } else {
                          notifier.addTag(tag.slug);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Age range'),
              const SizedBox(height: 4),
              Text(
                'Does not hide devotions yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final age in ageRangeChoices)
                    FilterChip(
                      label: Text(age),
                      selected: filter.ageRange == age,
                      onSelected: (selected) => ref
                          .read(browseFilterProvider.notifier)
                          .setAge(selected ? age : null),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Interests'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in interests)
                    FilterChip(
                      key: ValueKey('filter-tag-${tag.slug}'),
                      label: Text(tag.label),
                      selected: filter.interests.contains(tag.slug),
                      onSelected: (_) => ref
                          .read(browseFilterProvider.notifier)
                          .toggleInterest(tag.slug),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Local'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Devos from news near you',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Off. Uses your approximate location, only if you turn it on.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: AppTheme.sans,
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Switch(value: false, onChanged: null),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(browseFilterProvider.notifier).reset(),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('show-devos'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Show $count devos'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontFamily: AppTheme.sans,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );
    return Row(
      children: [
        Text(text.toUpperCase(), style: style),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: AppTheme.sans,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.switchKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}
