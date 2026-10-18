import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

void showFeedSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        backgroundColor: const Color(0xFF2C382F),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppTheme.sans,
            color: Colors.white,
          ),
        ),
      ),
    );
}

Future<void> toggleLike(BuildContext context, WidgetRef ref, String id) async {
  final liked = ref.read(favoritesProvider).value?.contains(id) ?? false;
  await ref.read(favoritesProvider.notifier).toggle(id);
  if (!context.mounted) return;
  showFeedSnack(
    context,
    liked ? 'Removed from Saved' : 'Liked · added to Saved',
  );
}
