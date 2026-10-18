import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../shared/widgets/reading_widgets.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return today.when(
      loading: () => const LoadingView(),
      error: (error, _) => StatusMessage(
        title: 'The devotions could not be loaded',
        body: 'Check the connection and try again.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(todayProvider),
      ),
      data: (snapshot) => _TodayBody(snapshot: snapshot),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.snapshot});

  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edition = snapshot.edition;
    final scheme = Theme.of(context).colorScheme;
    return ReadingWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            edition == null ? 'No edition yet' : DateFormat('EEEE').format(edition),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFamily: AppTheme.sans,
              color: scheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            edition == null
                ? 'The archive is empty'
                : DateFormat('MMMM d, y').format(edition),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Eight short devotions for the day.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (snapshot.dates.length > 1 && edition != null) ...[
            const SizedBox(height: 16),
            _EditionStepper(edition: edition, dates: snapshot.dates),
          ],
          if (snapshot.isFallback) ...[
            const SizedBox(height: 16),
            _FallbackNote(edition: edition!),
          ],
          const SizedBox(height: 20),
          if (snapshot.devos.isEmpty)
            const StatusMessage(
              title: 'Nothing published for this date',
              body:
                  'Weekday editions carry the eight devotions. Choose another day, or open the archive.',
            )
          else
            for (final devo in snapshot.devos) ...[
              DevoCard(
                devo: devo,
                onTap: () => context.push('/devo/${devo.id}'),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _FallbackNote extends StatelessWidget {
  const _FallbackNote({required this.edition});

  final DateTime edition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = DateFormat('EEEE, MMMM d').format(edition);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Showing $label, the latest edition on or before today. New sets are published on weekdays.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: AppTheme.sans,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _EditionStepper extends ConsumerWidget {
  const _EditionStepper({required this.edition, required this.dates});

  final DateTime edition;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = dates.indexWhere((date) => isSameDate(date, edition));
    final hasNewer = index > 0;
    final hasOlder = index >= 0 && index < dates.length - 1;
    return Row(
      children: [
        OutlinedButton(
          onPressed: hasOlder
              ? () => ref.read(selectedEditionProvider.notifier).select(dates[index + 1])
              : null,
          child: const Text('Earlier'),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: hasNewer
              ? () => ref.read(selectedEditionProvider.notifier).select(dates[index - 1])
              : null,
          child: const Text('Later'),
        ),
      ],
    );
  }
}
