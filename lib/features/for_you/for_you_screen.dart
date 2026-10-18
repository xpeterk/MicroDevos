import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/reading_widgets.dart';

/// TODO(milestone-3): Replace this stub with tag recommendations backed by
/// pgvector. No model call on the free path. Premium adds a daily personalized pick.
class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReadingWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text('For You', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Recommendations arrive in a later milestone. The free path will match the tags you choose to devotions already in the archive, without an AI call.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'TODO: rank archive devotions by the tags saved in Settings, using the embedding column once it is filled.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: AppTheme.sans,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/settings'),
            child: const Text('Choose tags'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/create'),
            child: const Text('Create a devotion'),
          ),
        ],
      ),
    );
  }
}
