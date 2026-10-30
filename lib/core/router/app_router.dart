import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/create/create_screen.dart';
import '../../features/devo/devo_detail_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/for_you/for_you_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/sign_in_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/browse/story_screen.dart';
import '../../features/today/today_screen.dart';

GoRouter buildRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/for-you',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForYouScreen(),
      ),
      GoRoute(
        path: '/story/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            StoryScreen(initialId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/devo/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => DevoDetailScreen(
          id: state.pathParameters['id']!,
          initialSectionId: state.uri.queryParameters['section'],
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateScreen(),
      ),
    ],
  );
}
