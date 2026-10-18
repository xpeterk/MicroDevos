import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/browse_state.dart';
import '../browse/feed_view.dart';
import '../browse/note_pane.dart';

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
            body: 'Weekday editions carry the eight devotions. Open the archive for another day.',
          );
        }
        return _TodayFrame(snapshot: snapshot);
      },
    );
  }
}

class _TodayFrame extends ConsumerWidget {
  const _TodayFrame({required this.snapshot});

  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(noteDraftProvider);
    final selection = ref.watch(passageSelectionProvider);
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: FeedView(
                devos: snapshot.devos,
                edition: snapshot.edition,
                isFallback: snapshot.isFallback,
              ),
            ),
            if (draft != null) NotePane(key: ValueKey(draft.session)),
          ],
        ),
        if (draft != null && selection != null)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Center(child: AnchorToolbar(devoId: draft.devoId)),
          ),
      ],
    );
  }
}
