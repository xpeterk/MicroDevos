import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/bible_version.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/user_preferences.dart';
import '../../shared/widgets/reading_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final themeMode = ref.watch(themeModeProvider);
    final tags = ref.watch(tagCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: preferences.when(
        loading: () => const LoadingView(),
        error: (error, _) => StatusMessage(
          title: 'Settings could not be loaded',
          body: 'Your choices are stored on this phone. Try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(preferencesProvider),
        ),
        data: (value) => ReadingWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Verses, tags, and the time of your daily reminder.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const Eyebrow('Appearance'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) {
                  ref.read(themeModeProvider.notifier).setMode(selection.first);
                },
              ),
              const SizedBox(height: 28),
              const Eyebrow('Bible version'),
              const SizedBox(height: 8),
              Text(
                'ESV and NIV are the featured choices. KJV is bundled and works offline. Other translations appear when their API keys are configured.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final version in BibleVersion.featured)
                _VersionTile(version: version, preferences: value),
              const SizedBox(height: 8),
              Text(
                'More translations',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final version in BibleVersion.additional)
                _VersionTile(version: version, preferences: value),
              if (value.bibleVersions.enabled.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Read verses in',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final version in BibleVersion.displayOrder)
                      if (value.bibleVersions.enabled.contains(version))
                        ChoiceChip(
                          label: Text(version.shortLabel),
                          selected: value.bibleVersions.reading == version,
                          onSelected: (_) async {
                            await ref
                                .read(preferencesProvider.notifier)
                                .updatePreferences(
                                  value.copyWith(
                                    bibleVersions: value.bibleVersions.withReading(
                                      version,
                                    ),
                                  ),
                                );
                          },
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              const Eyebrow('Tags'),
              const SizedBox(height: 8),
              Text(
                'These will shape For You once recommendations ship. They are saved now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              tags.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Tags could not be loaded.'),
                data: (catalog) => _TagPicker(
                  tags: catalog.tags,
                  selected: value.tagSlugs,
                  onToggle: (slug) async {
                    final next = {...value.tagSlugs};
                    if (!next.add(slug)) next.remove(slug);
                    await ref
                        .read(preferencesProvider.notifier)
                        .updatePreferences(value.copyWith(tagSlugs: next));
                  },
                ),
              ),
              const SizedBox(height: 28),
              const Eyebrow('Daily reminder'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                subtitle: Text(
                  'Local notification at ${value.notifyTimeLabel}. Nothing is sent to a server.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: AppTheme.sans,
                  ),
                ),
                value: value.notificationsEnabled,
                onChanged: (enabled) {
                  ref.read(preferencesProvider.notifier).updatePreferences(
                    value.copyWith(notificationsEnabled: enabled),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                trailing: Text(
                  _formatTime(context, value.notifyHour, value.notifyMinute),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.sans,
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: value.notifyHour,
                      minute: value.notifyMinute,
                    ),
                  );
                  if (picked == null) return;
                  await ref.read(preferencesProvider.notifier).updatePreferences(
                    value.copyWith(
                      notifyHour: picked.hour,
                      notifyMinute: picked.minute,
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              const Eyebrow('Account'),
              const SizedBox(height: 8),
              Text(
                ref.watch(appConfigProvider).useSupabase
                    ? 'Email, Google, and Apple sign-in are connected to Supabase.'
                    : 'You are reading the bundled sample. Sign-in turns on when Supabase keys are provided.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/sign-in'),
                child: Text(
                  ref.watch(authStateProvider).value?.email ?? 'Sign in',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, int hour, int minute) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({required this.version, required this.preferences});

  final BibleVersion version;
  final UserPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = preferences.bibleVersions.enabled.contains(version);
    final isReading = preferences.bibleVersions.reading == version;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      title: Text('${version.shortLabel}  ·  ${version.fullName}'),
      subtitle: Text(
        version.isBundled
            ? 'Bundled. Works offline.'
            : isReading
            ? 'Reading translation'
            : version.usesCrossway
            ? 'Crossway API when ESV_API_KEY is set'
            : 'API.Bible when a key and Bible id are set',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: AppTheme.sans,
        ),
      ),
      onChanged: (_) {
        final next = preferences.bibleVersions.toggle(version);
        ref.read(preferencesProvider.notifier).updatePreferences(
          preferences.copyWith(bibleVersions: next),
        );
      },
    );
  }
}

class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          FilterChip(
            label: Text(tag.label),
            selected: selected.contains(tag.slug),
            onSelected: (_) => onToggle(tag.slug),
          ),
      ],
    );
  }
}
