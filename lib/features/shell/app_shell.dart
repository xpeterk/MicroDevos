import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../personalize/personalize_run.dart';
import '../personalize/personalize_sheet.dart';
import '../personalize/personalize_state.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(personalizeRunProvider);
    final showHint = ref.watch(showCreateHintProvider);
    final writing = run.writing || run.blockedReason != null;
    final showingResult = run.devo != null && !run.writing;
    final showCreate = shell.currentIndex != 2 && !writing && !showingResult;
    final config = ref.watch(appConfigProvider);
    final client = ref.watch(supabaseClientProvider);
    final isUsingSampleData = !(config.useSupabase && client != null);
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    if (writing) return const PersonalizeWritingScreen();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Text(
          showingResult
              ? 'Your devo'
              : shell.currentIndex == 2
              ? 'Saved'
              : 'Micro Devos',
          style: TextStyle(
            fontFamily: AppTheme.serif,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (showingResult)
            IconButton(
              key: const Key('personalize-close'),
              tooltip: 'Close',
              onPressed: () =>
                  ref.read(personalizeRunProvider.notifier).dismiss(),
              icon: const Icon(Icons.close),
            )
          else ...[
            if (showCreate)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilledButton.icon(
                  key: const Key('create-button'),
                  onPressed: () => openPersonalizeSheet(context, ref),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Create'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ],
      ),
      body: CenteredColumn(
        child: Stack(
          children: [
            if (showingResult) const PersonalizeResult() else shell,
            if (showHint && shell.currentIndex == 0 && !showingResult)
              const Positioned(
                top: 4,
                right: 16,
                left: 56,
                child: CreateHint(),
              ),
            if (kDebugMode && !isTest && isUsingSampleData)
              Positioned(
                bottom: 8,
                left: 12,
                child: IgnorePointer(
                  child: Container(
                    key: const Key('sample-data-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Sample data',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: showingResult ? 1 : shell.currentIndex,
        onDestinationSelected: (index) {
          if (showingResult) {
            ref.read(personalizeRunProvider.notifier).dismiss();
          }
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'For You',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}

class CreateHint extends StatelessWidget {
  const CreateHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('create-hint'),
      color: const Color(0xFF2C4638),
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Text(
          'Personalize makes a brand-new devo from your topic or verse. Filter (below) only narrows existing devos.',
          style: TextStyle(
            fontFamily: AppTheme.sans,
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
