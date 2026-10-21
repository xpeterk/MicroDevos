import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/feed_view.dart';

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
      data: (snapshot) {
        if (snapshot.devos.isEmpty) {
          return const StatusMessage(
            title: 'Nothing published for this date',
            body: 'Weekday editions carry the eight devotions. Pull to try again in a moment.',
          );
        }
        return FeedView(
          devos: snapshot.devos,
          edition: snapshot.edition,
          isFallback: snapshot.isFallback,
        );
      },
    );
  }
}
