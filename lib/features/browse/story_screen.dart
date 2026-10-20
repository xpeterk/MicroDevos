import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/edition_date_format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../shared/widgets/reading_widgets.dart';
import 'banner.dart';
import 'browse_state.dart';
import 'feed_snack.dart';
import 'share_sheet.dart';

class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({required this.initialId, super.key});

  final String initialId;

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  int? _index;

  void _step(int delta, int length) {
    final current = _index ?? 0;
    final next = current + delta;
    if (next < 0 || next >= length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    return today.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => const Scaffold(
        body: StatusMessage(
          title: 'The devotions could not be loaded',
          body: 'Close this view and try again.',
        ),
      ),
      data: (snapshot) {
        final devos = snapshot.devos;
        if (devos.isEmpty) {
          return const Scaffold(
            body: StatusMessage(
              title: 'Nothing to show',
              body: 'This edition has no devotions.',
            ),
          );
        }
        _index ??= devos.indexWhere((devo) => devo.id == widget.initialId);
        if (_index! < 0) _index = 0;
        final index = _index!.clamp(0, devos.length - 1);
        final devo = devos[index];
        final colors = paletteFor(devo);
        final catalog = ref.watch(tagCatalogProvider).asData?.value;
        final label = devo.tags.isEmpty
            ? 'Devotion'
            : catalog?.tagBySlug(devo.tags.first)?.label ?? devo.tags.first;
        final liked =
            ref.watch(favoritesProvider).value?.contains(devo.id) ?? false;
        return Scaffold(
          backgroundColor: colors.last,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.first, colors.last],
              ),
            ),
            child: SafeArea(
              child: CenteredColumn(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: Row(
                        children: [
                          for (var i = 0; i < devos.length; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: i <= index
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          const _MdMark(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatEditionDate(
                                    devo.editionDate,
                                    'EEE, MMM d',
                                  ),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.sans,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${devo.position} of ${devos.length} · $label',
                                  style: TextStyle(
                                    fontFamily: AppTheme.sans,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('story-close'),
                            tooltip: 'Close',
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final width = context.size?.width ?? 0;
                          _step(
                            details.localPosition.dx < width / 2 ? -1 : 1,
                            devos.length,
                          );
                        },
                        onVerticalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity < -250) context.push('/devo/${devo.id}');
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _StoryBanner(devo: devo),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          label.toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: AppTheme.sans,
                                            color: Colors.white,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        devo.title,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.serif,
                                          fontSize: 32,
                                          height: 1.05,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        devo.hook,
                                        style: TextStyle(
                                          fontFamily: AppTheme.serif,
                                          fontSize: 16,
                                          height: 1.35,
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _StoryCard(devo: devo),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: liked ? 'Remove from saved' : 'Save',
                            onPressed: () => toggleLike(context, ref, devo.id),
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Share',
                            onPressed: () => openShareSheet(context, devo),
                            icon: const Icon(
                              Icons.ios_share,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Note',
                            onPressed: () {
                              ref
                                  .read(noteDraftProvider.notifier)
                                  .openNew(devo.id);
                              context.pop();
                            },
                            icon: const Icon(
                              Icons.sticky_note_2_outlined,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Swipe up for the full devo',
                            style: TextStyle(
                              fontFamily: AppTheme.sans,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '‹ tap: previous          tap: next ›',
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.devo});

  final Devo devo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: AppColors.olive),
              SizedBox(width: 6),
              Text(
                '5-SECOND DEVO',
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.olive,
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
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.verse,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VERSE',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.olive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  devo.verseText,
                  style: const TextStyle(
                    fontFamily: AppTheme.serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    height: 1.35,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  devo.verseRef,
                  style: const TextStyle(
                    fontFamily: AppTheme.sans,
                    fontWeight: FontWeight.w600,
                    color: AppColors.olive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryBanner extends StatelessWidget {
  const _StoryBanner({required this.devo});

  final Devo devo;

  @override
  Widget build(BuildContext context) {
    final imageUrl = devo.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Text(
        'IMAGE PLACEHOLDER',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 10,
          letterSpacing: 0.8,
          color: Colors.white70,
        ),
      );
    }
    final label = bannerLabel(devo);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: UncroppedNetworkImage(
        imageUrl: imageUrl,
        semanticLabel: label,
        error: Semantics(
          label: label,
          image: true,
          child: const SizedBox(height: 48),
        ),
      ),
    );
  }
}

class _MdMark extends StatelessWidget {
  const _MdMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
