import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/edition_date_format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../shared/widgets/reading_widgets.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(archiveProvider);
    final dates = ref.watch(editionDatesProvider);
    final query = ref.watch(archiveQueryProvider);
    return ReadingWidth(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archive',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Search the devotions, or browse by edition date.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: AppTheme.sans,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search title, hook, or verse',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      ref.read(archiveQueryProvider.notifier).setText(value),
                ),
                const SizedBox(height: 12),
                dates.when(
                  loading: () => const SizedBox(height: 40),
                  error: (_, _) => const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Edition dates could not be loaded.'),
                  ),
                  data: (editionDates) => SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All dates'),
                            selected: query.date == null,
                            onSelected: (_) => ref
                                .read(archiveQueryProvider.notifier)
                                .setDate(null),
                          ),
                        ),
                        for (final date in editionDates)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(formatEditionDate(date, 'MMM d')),
                              selected:
                                  query.date != null &&
                                  isSameDate(query.date!, date),
                              onSelected: (_) => ref
                                  .read(archiveQueryProvider.notifier)
                                  .setDate(date),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.when(
              loading: () => const LoadingView(),
              error: (error, _) => StatusMessage(
                title: 'The archive could not be searched',
                body: 'Try again in a moment.',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(archiveProvider),
              ),
              data: (devos) {
                if (devos.isEmpty) {
                  return const StatusMessage(
                    title: 'Nothing matches',
                    body: 'Try another word, or clear the date and search the whole set.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: devos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final devo = devos[index];
                    return DevoCard(
                      devo: devo,
                      onTap: () => context.push('/devo/${devo.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
