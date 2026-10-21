import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/generated_devo.dart';
import '../../domain/personalize/personalize_engine.dart';
import '../../domain/personalize/style_catalog.dart';
import '../browse/banner.dart';
import '../browse/feed_snack.dart';
import 'personalize_state.dart';

class PersonalizeWritingScreen extends ConsumerWidget {
  const PersonalizeWritingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(personalizeRunProvider);
    final request = run.request;
    final cap = ref.watch(personalizeEngineProvider).capSnapshot();
    final style = request == null ? null : styleByKey(request.styleKey);
    final contextBits = [
      if (request?.ageRange != null) request!.ageRange!,
      ...?request?.lifeSituations,
    ];

    if (run.blockedReason != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  run.blockedReason!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The weekly cap and the monthly spend ceiling are not decided yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTheme.sans),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      ref.read(personalizeRunProvider.notifier).dismiss(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('personalize-writing'),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE4DDD2), width: 14),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB7C9BC), Color(0xFF7E9A88)],
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Writing your devo...',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Usually under 20 seconds. You can leave this screen. A saved devotion stays on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 15,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (request != null && request.promptLabel.isNotEmpty)
                    _InfoChip(label: request.promptLabel, filled: true),
                  if (style != null)
                    _InfoChip(
                      label: style.isClassic
                          ? style.label
                          : '${style.label} style',
                    ),
                  if (contextBits.isNotEmpty)
                    _InfoChip(label: contextBits.join(' · ')),
                ],
              ),
              const SizedBox(height: 22),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(6)),
                child: LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 6,
                  backgroundColor: Color(0xFFE4DDD2),
                  color: AppColors.olive,
                ),
              ),
              const Spacer(),
              _CapCard(cap: cap),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalizeResult extends ConsumerStatefulWidget {
  const PersonalizeResult({super.key});

  @override
  ConsumerState<PersonalizeResult> createState() => _PersonalizeResultState();
}

class _PersonalizeResultState extends ConsumerState<PersonalizeResult> {
  var _liked = false;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final devo = ref.watch(personalizeRunProvider).devo;
    if (devo == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final banner = devo.isClassic
        ? 'Personalized · Adapted from ${devo.styleLabel} · public domain'
        : 'Personalized · ${devo.styleLabel} style · “${devo.promptLabel}”';

    return ListView(
      key: const Key('personalize-result'),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              const _Avatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized · today',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'For You',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            key: const Key('personalize-banner-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.oliveSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.olive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    banner,
                    style: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.olive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 112,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC5A9C4), Color(0xFF8E6F8C)],
                  ),
                ),
              ),
              const Positioned(right: -20, top: 10, child: _Bubble(size: 120)),
              const Positioned(
                left: -30,
                bottom: -10,
                child: _Bubble(size: 140),
              ),
              Positioned(
                right: 24,
                top: 28,
                child: Icon(
                  Icons.sell_outlined,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              const Positioned(top: 12, right: 12, child: _ImagePill()),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Text(
                  devo.title,
                  style: const TextStyle(
                    fontFamily: AppTheme.serif,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              IconButton(
                key: const Key('heart-generated'),
                tooltip: _liked ? 'Liked' : 'Like',
                onPressed: () => setState(() => _liked = !_liked),
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? scheme.primary : scheme.onSurface,
                ),
              ),
              IconButton(
                key: const Key('share-generated'),
                tooltip: 'Share',
                onPressed: () => _share(context, devo),
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                key: const Key('note-generated'),
                tooltip: 'Note',
                onPressed: () => showFeedSnack(
                  context,
                  'Notes on a new devo stay on this phone.',
                ),
                icon: const Icon(Icons.sticky_note_2_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                devo.hook,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 8),
              const _DashDivider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '5-SECOND DEVO',
                    style: TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                devo.takeaway,
                style: const TextStyle(
                  fontFamily: AppTheme.serif,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (devo.helpNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  devo.helpNote!,
                  key: const Key('help-note'),
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E6C4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERSE',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.line,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      devo.verseText,
                      style: const TextStyle(
                        fontFamily: AppTheme.serif,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${devo.verseRef} KJV',
                      style: const TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                        color: AppColors.line,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('read-full-generated'),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_expanded ? 'Show less' : 'Read the full devo'),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
              if (_expanded)
                for (final section in devo.sections) ...[
                  Text(section, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('save-to-mine'),
                      onPressed: () async {
                        await ref.read(mineProvider.notifier).save(devo);
                        if (!context.mounted) return;
                        showFeedSnack(context, 'Saved on this phone');
                      },
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('regenerate'),
                      onPressed: () => ref
                          .read(personalizeRunProvider.notifier)
                          .regenerate(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, GeneratedDevo devo) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '${devo.title}\n\n${devo.hook}\n\n${devo.verseText}'),
      );
    } catch (_) {
      if (!context.mounted) return;
      showFeedSnack(context, 'Sharing is not available on this device.');
    }
  }
}

class _CapCard extends StatelessWidget {
  const _CapCard({required this.cap});

  final CapSnapshot cap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${cap.left} of ${cap.weeklyCap} left this week',
                key: const Key('cap-label'),
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E0A4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EXAMPLE CAP',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF8A6A1F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < cap.weeklyCap; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < cap.left
                          ? AppColors.olive
                          : const Color(0xFFE4DDD2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Resets Monday. Limit and pricing not decided yet.',
            style: TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: scheme.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: filled ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.olive,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'md',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
      ),
    );
  }
}

class _ImagePill extends StatelessWidget {
  const _ImagePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'IMAGE PLACEHOLDER',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 10,
          letterSpacing: 0.6,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashDivider extends StatelessWidget {
  const _DashDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        final count = (constraints.maxWidth / (dash * 2)).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: dash,
                height: 1,
                margin: const EdgeInsets.only(right: dash),
                color: AppColors.paperDeep,
              ),
          ],
        );
      },
    );
  }
}

class MineTile extends StatelessWidget {
  const MineTile({required this.devo, required this.index, super.key});

  final GeneratedDevo devo;
  final int index;

  @override
  Widget build(BuildContext context) {
    final paletteIndex = minePaletteOrder[index % minePaletteOrder.length];
    final colors = bannerPalettes[paletteIndex];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                devo.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.serif,
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Palette order for personalized tiles.
/// the approved art: plum, sand, blue, olive.
const minePaletteOrder = [2, 4, 0, 1];
