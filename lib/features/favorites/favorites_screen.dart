import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/reading_widgets.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final signedIn = ref.watch(authStateProvider).value != null;
    return ReadingWidth(
      child: favorites.when(
        loading: () => const LoadingView(),
        error: (error, _) => StatusMessage(
          title: 'Saved devotions could not be opened',
          body: 'They are stored on this phone. Try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(favoritesProvider),
        ),
        data: (ids) {
          if (ids.isEmpty) {
            return StatusMessage(
              title: 'Nothing saved yet',
              body: signedIn
                  ? 'Open a devotion and tap the heart. Saves follow this account.'
                  : 'Open a devotion and tap the heart. Saves stay on this phone until you sign in.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text('Saved', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                signedIn
                    ? 'Hearts you keep are stored with your account.'
                    : 'Hearts you keep stay on this phone for now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              for (final id in ids.toList()..sort())
                _FavoriteTile(id: id),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devo = ref.watch(devoByIdProvider(id));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: devo.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox.shrink(),
        data: (value) {
          if (value == null) return const SizedBox.shrink();
          return DevoCard(
            devo: value,
            onTap: () => context.push('/devo/${value.id}'),
          );
        },
      ),
    );
  }
}
