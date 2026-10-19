import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/bible/verse_reference.dart';
import '../../domain/models/bible_version.dart';
import '../../domain/personalize/style_catalog.dart';
import '../browse/browse_state.dart';
import 'personalize_state.dart';

Future<void> openPersonalizeSheet(BuildContext context, WidgetRef ref) {
  ref.read(showCreateHintProvider.notifier).hide();
  ref.read(personalizeFormProvider.notifier).reset();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return const FractionallySizedBox(
        heightFactor: 0.92,
        child: PersonalizeSheet(),
      );
    },
  );
}

class PersonalizeSheet extends ConsumerStatefulWidget {
  const PersonalizeSheet({super.key});

  @override
  ConsumerState<PersonalizeSheet> createState() => _PersonalizeSheetState();
}

class _PersonalizeSheetState extends ConsumerState<PersonalizeSheet> {
  final _topic = TextEditingController();
  final _verse = TextEditingController();

  @override
  void dispose() {
    _topic.dispose();
    _verse.dispose();
    super.dispose();
  }

  void _addVerse() {
    final text = _verse.text.trim();
    if (text.isEmpty) return;
    ref.read(personalizeFormProvider.notifier).addVerse(text);
    _verse.clear();
  }

  Future<void> _setReading(BibleVersion version) async {
    final prefs = ref.read(preferencesProvider).asData?.value;
    if (prefs == null) return;
    final current = prefs.bibleVersions;
    final next = current.enabled.contains(version)
        ? current.withReading(version)
        : current.toggle(version);
    await ref
        .read(preferencesProvider.notifier)
        .updatePreferences(prefs.copyWith(bibleVersions: next));
  }

  void _generate() {
    final form = ref.read(personalizeFormProvider);
    final reading = ref
        .read(preferencesProvider)
        .asData
        ?.value
        .bibleVersions
        .reading
        .id;
    final request = form.toRequest(bibleVersion: reading);
    Navigator.of(context).pop();
    ref.read(personalizeRunProvider.notifier).start(request);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(personalizeFormProvider);
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(preferencesProvider).asData?.value;
    final reading = prefs?.bibleVersions.reading;
    final bundle = ref.watch(kjvBundleProvider).asData?.value;
    final previewRef = form.verseRefs.isEmpty ? null : form.verseRefs.first;
    final preview = previewRef == null ? null : bundle?.lookup(previewRef);

    return Column(
      key: const Key('personalize-sheet'),
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.outline,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalize',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creates a new devo just for you. Premium.',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              _StepLabel(index: '1', label: 'WHAT', active: form.step == 0),
              const SizedBox(width: 8),
              _StepLabel(index: '2', label: 'STYLE', active: form.step == 1),
              const SizedBox(width: 8),
              const _StepLabel(index: '3', label: 'FOR WHOM', active: false),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            children: [
              if (form.step == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        key: const Key('personalize-topic'),
                        icon: Icons.sell_outlined,
                        label: 'Topic',
                        selected: !form.verseMode,
                        onTap: () => ref
                            .read(personalizeFormProvider.notifier)
                            .setSource(PersonalizeSource.topic),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeButton(
                        key: const Key('personalize-verse'),
                        icon: Icons.check_box_outline_blank,
                        label: 'Verse',
                        selected: form.verseMode,
                        onTap: () => ref
                            .read(personalizeFormProvider.notifier)
                            .setSource(PersonalizeSource.verse),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!form.verseMode) ...[
                  TextField(
                    key: const Key('topic-field'),
                    controller: _topic,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => ref
                        .read(personalizeFormProvider.notifier)
                        .setTopic(value),
                    decoration: InputDecoration(
                      hintText: 'A few words is enough',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.sans,
                        color: scheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.olive,
                          width: 1.4,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.olive,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type anything, a few words is enough.',
                    style: TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('SUGGESTED TOPICS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final topic in suggestedTopics)
                        _Pill(
                          key: Key('topic-suggestion-$topic'),
                          label: topic,
                          selected: form.suggestion == topic,
                          onTap: () => ref
                              .read(personalizeFormProvider.notifier)
                              .toggleSuggestion(topic),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel('READER CONTEXT', trailing: 'optional'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final age in ageRangeChoices)
                        _Pill(
                          key: Key('age-$age'),
                          label: age,
                          selected: form.ageRange == age,
                          onTap: () => ref
                              .read(personalizeFormProvider.notifier)
                              .setAge(age),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final life in lifeSituationChoices)
                        _Pill(
                          key: Key('life-$life'),
                          label: life,
                          selected: form.lifeSituations.contains(life),
                          onTap: () => ref
                              .read(personalizeFormProvider.notifier)
                              .toggleLife(life),
                        ),
                    ],
                  ),
                ] else ...[
                  const _SectionLabel('VERSES', trailing: 'add one or more'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final reference in form.verseRefs)
                        _Pill(
                          key: Key('verse-chip-$reference'),
                          label: reference,
                          selected: true,
                          onTap: () => ref
                              .read(personalizeFormProvider.notifier)
                              .removeVerse(reference),
                          trailing: Icons.close,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('verse-field'),
                    controller: _verse,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addVerse(),
                    decoration: InputDecoration(
                      hintText: '+  Add reference, e.g. Matt 6:34',
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.sans,
                        color: scheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.olive),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel(
                    'VERSION',
                    trailing: 'default from Settings',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final version in BibleVersion.featured) ...[
                        _VersionBox(
                          key: Key('version-${version.id}'),
                          label: version.shortLabel,
                          checked: reading == version,
                          onTap: () => _setReading(version),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel(
                    'PREVIEW',
                    trailing: 'KJV shown as sample text',
                  ),
                  const SizedBox(height: 8),
                  if (preview != null && previewRef != null)
                    Container(
                      key: const Key('verse-preview'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E6C4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview,
                            style: const TextStyle(
                              fontFamily: AppTheme.serif,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            VerseReference.normalize(previewRef).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: AppTheme.sans,
                              fontSize: 12,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w700,
                              color: AppColors.line,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ] else
                const _StyleStep(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key(form.step == 0 ? 'personalize-cancel' : 'personalize-back'),
                  onPressed: () {
                    if (form.step == 0) {
                      Navigator.of(context).pop();
                    } else {
                      ref.read(personalizeFormProvider.notifier).setStep(0);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: scheme.outline),
                  ),
                  child: Text(form.step == 0 ? 'Cancel' : 'Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: Key(
                    form.step == 0 ? 'personalize-next' : 'personalize-generate',
                  ),
                  onPressed: form.step == 0
                      ? (form.canContinue
                            ? () => ref
                                  .read(personalizeFormProvider.notifier)
                                  .setStep(1)
                            : null)
                      : _generate,
                  icon: form.step == 0
                      ? const SizedBox.shrink()
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    form.step == 0 ? 'Next: pick a style' : 'Generate',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StyleStep extends ConsumerWidget {
  const _StyleStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(personalizeFormProvider).styleKey;
    final styles = [
      for (final style in styleCatalog)
        if (!style.isClassic) style,
    ];
    final classics = [
      for (final style in styleCatalog)
        if (style.isClassic) style,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('STYLES', trailing: 'pick one'),
        const SizedBox(height: 8),
        _StyleGrid(
          styles: styles,
          selected: selected,
          placeholder: true,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('CLASSICS (PUBLIC DOMAIN)'),
        const SizedBox(height: 8),
        _StyleGrid(styles: classics, selected: selected, classic: true),
      ],
    );
  }
}

class _StyleGrid extends ConsumerWidget {
  const _StyleGrid({
    required this.styles,
    required this.selected,
    this.classic = false,
    this.placeholder = false,
  });

  final List<StyleProfile> styles;
  final String selected;
  final bool classic;
  final bool placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[
      for (final style in styles)
        _StyleCard(
          key: Key('style-${style.key}'),
          style: style,
          selected: selected == style.key,
          classic: classic,
          onTap: () =>
              ref.read(personalizeFormProvider.notifier).setStyle(style.key),
        ),
      if (placeholder) const _MoreStyles(),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: classic ? 1.45 : 1.7,
      children: tiles,
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.classic,
    required this.onTap,
    super.key,
  });

  final StyleProfile style;
  final bool selected;
  final bool classic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.oliveSoft : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.olive : AppColors.paperDeep,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      style: const TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      style.blurb,
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 12,
                        height: 1.25,
                        color: classic ? AppColors.line : AppColors.inkMuted,
                      ),
                    ),
                    if (classic)
                      const Text(
                        'adapted from public-domain writing',
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 11,
                          height: 1.25,
                          color: AppColors.line,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? AppColors.olive : AppColors.paperDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreStyles extends StatelessWidget {
  const _MoreStyles();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paperDeep),
      ),
      child: const Text(
        'More styles coming',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.index,
    required this.label,
    required this.active,
  });

  final String index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.olive : AppColors.inkMuted;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. $label',
            style: TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? AppColors.olive : AppColors.paperDeep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.sans,
            fontSize: 12,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
            color: AppColors.olive,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 12,
              color: AppColors.inkMuted,
            ),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.card : AppColors.paperDeep.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.paperDeep : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.oliveSoft : AppColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.olive : AppColors.paperDeep,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && trailing == null) ...[
                const Icon(Icons.check, size: 14, color: AppColors.olive),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                Icon(trailing, size: 14, color: AppColors.inkMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBox extends StatelessWidget {
  const _VersionBox({
    required this.label,
    required this.checked,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: checked ? AppColors.olive : AppColors.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.sans,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
