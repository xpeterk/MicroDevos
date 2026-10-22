import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/bible/verse_reference.dart';
import '../../domain/models/bible_version.dart';
import '../../domain/personalize/style_catalog.dart';
import '../browse/browse_state.dart';
import 'chip_tone.dart';
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
  final _pages = PageController();
  final _gate = _StepGate();

  @override
  void dispose() {
    _topic.dispose();
    _verse.dispose();
    _pages.dispose();
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

  void _go(int step) {
    final form = ref.read(personalizeFormProvider);
    if (step < 0 || step > 2) return;
    if (step > form.step && !personalizeStepReachable(form, step)) return;
    ref.read(personalizeFormProvider.notifier).setStep(step);
    if (_pages.hasClients && (_pages.page?.round() ?? form.step) != step) {
      _pages.jumpToPage(step);
    }
  }

  void _onPageChanged(int page) {
    final form = ref.read(personalizeFormProvider);
    if (!personalizeStepReachable(form, page)) {
      if (_pages.hasClients) _pages.jumpToPage(form.step);
      return;
    }
    if (page != form.step) {
      ref.read(personalizeFormProvider.notifier).setStep(page);
    }
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
    _gate.allowForward =
        form.step < 2 && personalizeStepComplete(form, form.step);
    _gate.allowBack = form.step > 0;

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
              _StepLabel(
                key: const Key('step-what'),
                index: '1',
                label: 'WHAT',
                active: form.step == 0,
                onTap: () => _go(0),
              ),
              const SizedBox(width: 8),
              _StepLabel(
                key: const Key('step-style'),
                index: '2',
                label: 'STYLE',
                active: form.step == 1,
                onTap: () => _go(1),
              ),
              const SizedBox(width: 8),
              _StepLabel(
                key: const Key('step-for-whom'),
                index: '3',
                label: 'FOR WHOM',
                active: form.step == 2,
                onTap: () => _go(2),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            key: const Key('personalize-pager'),
            controller: _pages,
            physics: _GatedPagePhysics(_gate),
            onPageChanged: _onPageChanged,
            children: [
              _WhatStep(
                form: form,
                topic: _topic,
                verse: _verse,
                reading: reading,
                preview: preview,
                previewRef: previewRef,
                onSource: (source) => ref
                    .read(personalizeFormProvider.notifier)
                    .setSource(source),
                onTopic: (value) =>
                    ref.read(personalizeFormProvider.notifier).setTopic(value),
                onSuggestion: (topic) => ref
                    .read(personalizeFormProvider.notifier)
                    .toggleSuggestion(topic),
                onAddVerse: _addVerse,
                onRemoveVerse: (reference) => ref
                    .read(personalizeFormProvider.notifier)
                    .removeVerse(reference),
                onVersion: _setReading,
              ),
              const _StyleStep(),
              const _AudienceStep(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key(
                    form.step == 0 ? 'personalize-cancel' : 'personalize-back',
                  ),
                  onPressed: () {
                    if (form.step == 0) {
                      Navigator.of(context).pop();
                    } else {
                      _go(form.step - 1);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: scheme.outline),
                    foregroundColor: scheme.onSurface,
                  ),
                  child: Text(form.step == 0 ? 'Cancel' : 'Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: form.step == 2
                    ? FilledButton.icon(
                        key: const Key('personalize-generate'),
                        onPressed: _generate,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generate'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: AppTheme.sans,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : FilledButton(
                        key: Key(
                          form.step == 0
                              ? 'personalize-next'
                              : 'personalize-next-for-whom',
                        ),
                        onPressed: personalizeStepComplete(form, form.step)
                            ? () => _go(form.step + 1)
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: AppTheme.sans,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        child: Text(
                          form.step == 0 ? 'Next: pick a style' : 'Next',
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

/// Mutable swipe permission. [PageView] keeps the first [ScrollPhysics]
/// instance, so the flags have to change on that same object.
class _StepGate {
  bool allowForward = false;
  bool allowBack = false;
}

/// Page snapping that refuses to leave a required step still incomplete.
///
/// [PageView] wraps this in its own [PageScrollPhysics]. Drag and fling
/// both pass through [applyBoundaryConditions], so a blocked direction
/// cannot settle on the next page.
class _GatedPagePhysics extends ScrollPhysics {
  const _GatedPagePhysics(this.gate)
    : super(parent: const ClampingScrollPhysics());

  final _StepGate gate;

  @override
  _GatedPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _GatedPagePhysics(gate);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!gate.allowForward && value > position.pixels) {
      return value - position.pixels;
    }
    if (!gate.allowBack && value < position.pixels) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class _WhatStep extends ConsumerWidget {
  const _WhatStep({
    required this.form,
    required this.topic,
    required this.verse,
    required this.reading,
    required this.preview,
    required this.previewRef,
    required this.onSource,
    required this.onTopic,
    required this.onSuggestion,
    required this.onAddVerse,
    required this.onRemoveVerse,
    required this.onVersion,
  });

  final PersonalizeForm form;
  final TextEditingController topic;
  final TextEditingController verse;
  final BibleVersion? reading;
  final String? preview;
  final String? previewRef;
  final ValueChanged<PersonalizeSource> onSource;
  final ValueChanged<String> onTopic;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onAddVerse;
  final ValueChanged<String> onRemoveVerse;
  final ValueChanged<BibleVersion> onVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      key: const Key('personalize-step-what'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                key: const Key('personalize-topic'),
                icon: Icons.sell_outlined,
                label: 'Topic',
                selected: !form.verseMode,
                onTap: () => onSource(PersonalizeSource.topic),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                key: const Key('personalize-verse'),
                icon: Icons.check_box_outline_blank,
                label: 'Verse',
                selected: form.verseMode,
                onTap: () => onSource(PersonalizeSource.verse),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!form.verseMode) ...[
          TextField(
            key: const Key('topic-field'),
            controller: topic,
            textInputAction: TextInputAction.done,
            onChanged: onTopic,
            style: TextStyle(
              fontFamily: AppTheme.sans,
              color: scheme.onSurface,
            ),
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
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 1.6),
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
                  onTap: () => onSuggestion(topic),
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
                  onTap: () => onRemoveVerse(reference),
                  trailing: Icons.close,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('verse-field'),
            controller: verse,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAddVerse(),
            style: TextStyle(
              fontFamily: AppTheme.sans,
              color: scheme.onSurface,
            ),
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
                borderSide: BorderSide(color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('VERSION', trailing: 'default from Settings'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final version in BibleVersion.featured) ...[
                _VersionBox(
                  key: Key('version-${version.id}'),
                  label: version.shortLabel,
                  checked: reading == version,
                  onTap: () => onVersion(version),
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('PREVIEW', trailing: 'KJV shown as sample text'),
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
                    preview!,
                    style: const TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 16,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    VerseReference.normalize(previewRef!).toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: AppColors.verseRef,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
    return ListView(
      key: const Key('personalize-step-style'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        const _SectionLabel('STYLES', trailing: 'pick one'),
        const SizedBox(height: 8),
        _StyleGrid(styles: styles, selected: selected, placeholder: true),
        const SizedBox(height: 16),
        const _SectionLabel('CLASSICS (PUBLIC DOMAIN)'),
        const SizedBox(height: 8),
        _StyleGrid(styles: classics, selected: selected, classic: true),
      ],
    );
  }
}

class _AudienceStep extends ConsumerWidget {
  const _AudienceStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(personalizeFormProvider);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      key: const Key('personalize-step-for-whom'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        Text(
          'Optional. Choose who this devotion is for, or leave it open.',
          style: TextStyle(
            fontFamily: AppTheme.sans,
            fontSize: 14,
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('AGE', trailing: 'optional'),
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
                onTap: () =>
                    ref.read(personalizeFormProvider.notifier).setAge(age),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('LIFE SITUATION', trailing: 'optional'),
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
                onTap: () =>
                    ref.read(personalizeFormProvider.notifier).toggleLife(life),
              ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final tone = ChipTone.resolve(scheme, selected: selected);
    final blurbColor = classic
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.nightOlive
              : AppColors.chipInk)
        : scheme.onSurfaceVariant;
    return Material(
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tone.border, width: selected ? 1.6 : 1),
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
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                        color: tone.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      style.blurb,
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 12,
                        height: 1.25,
                        color: blurbColor,
                      ),
                    ),
                    if (classic)
                      Text(
                        'adapted from public-domain writing',
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 11,
                          height: 1.25,
                          color: blurbColor,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: selected ? tone.accent : tone.border,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        'More styles coming',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          color: scheme.onSurfaceVariant,
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
    required this.onTap,
    super.key,
  });

  final String index;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
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
                color: active ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.sans,
            fontSize: 12,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final tone = ChipTone.resolve(scheme, selected: selected);
    final background = selected
        ? scheme.surfaceContainerLowest
        : Color.alphaBlend(
            scheme.outline.withValues(alpha: 0.45),
            scheme.surface,
          );
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? scheme.outline : Colors.transparent),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w600,
                  color: tone.foreground,
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
    final tone = ChipTone.resolve(
      Theme.of(context).colorScheme,
      selected: selected,
    );
    return Material(
      color: tone.background,
      shape: StadiumBorder(side: BorderSide(color: tone.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && trailing == null) ...[
                Icon(Icons.check, size: 14, color: tone.accent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: tone.foreground,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                Icon(trailing, size: 14, color: tone.accent),
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
    final scheme = Theme.of(context).colorScheme;
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
              color: checked ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
