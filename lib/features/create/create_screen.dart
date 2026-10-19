import 'package:flutter/material.dart';

import '../../shared/widgets/reading_widgets.dart';

/// Kept so older links still open. New devotions are created from the top-bar
/// Create button, which opens Personalize.
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('CREATE')),
      body: ReadingWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              'Create is in the top bar',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'The Create button opens Personalize and drafts a new devotion from a topic or a verse. Filter on the feed only narrows devotions that already exist. A finished devotion can be kept in Saved, under Mine.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
