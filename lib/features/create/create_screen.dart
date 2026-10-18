import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/reading_widgets.dart';

/// TODO(milestone-2): Premium generator. Chips from the reader profile, a short
/// typed prompt, cache lookup, then the generate-devo edge function. Local news
/// comes from a Google News RSS edge function with daily cost caps.
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
              'Create arrives with Premium',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'You will ask for a short devotion from a chip or a sentence. The reply keeps the usual shape: a hook, a reflection, Scripture, a featured verse, and one next step.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TODO: wire generate-devo, the Google News RSS local-news function, the profile cache, and the daily cost cap before this screen can write anything.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: AppTheme.sans,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              enabled: false,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'What do you need a devotion for?',
                helperText: 'Available when Premium generation ships.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
