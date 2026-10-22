import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/content/rich_document.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/scripture_quote.dart';

/// Wide and landscape screens keep the feed in a centered column so a
/// full-width banner stays readable and is still shown uncropped.
const feedContentMaxWidth = 720.0;

class CenteredColumn extends StatelessWidget {
  const CenteredColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: feedContentMaxWidth),
        child: child,
      ),
    );
  }
}

class ReadingWidth extends StatelessWidget {
  const ReadingWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: child,
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
        fontFamily: AppTheme.sans,
      ),
    );
  }
}

class DevoCard extends StatelessWidget {
  const DevoCard({required this.devo, required this.onTap, super.key});

  final Devo devo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${devo.position}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.serif,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      devo.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: AppTheme.serif,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      devo.hook,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      devo.verseRef,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontFamily: AppTheme.sans,
                        color: AppColors.readingRef(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerseCard extends StatelessWidget {
  const VerseCard({
    required this.text,
    required this.reference,
    this.note,
    super.key,
  });

  final String text;
  final String reference;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.nightVerse : AppColors.verse;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Featured verse'),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: AppTheme.serif,
              fontWeight: FontWeight.w500,
              height: 1.35,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            reference,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFamily: AppTheme.sans,
              color: AppColors.readingRef(Theme.of(context).brightness),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: AppTheme.sans,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TakeawayBlock extends StatelessWidget {
  const TakeawayBlock({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.secondary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Takeaway'),
          const SizedBox(height: 8),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class ScriptureList extends StatelessWidget {
  const ScriptureList({required this.quotes, super.key});

  final List<ScriptureQuote> quotes;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Scripture'),
        const SizedBox(height: 10),
        for (final quote in quotes) ...[
          Text(
            quote.text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic, height: 1.45),
          ),
          const SizedBox(height: 4),
          Text(
            quote.reference,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: AppTheme.sans,
              color: AppColors.readingRef(Theme.of(context).brightness),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class DevoBody extends StatelessWidget {
  const DevoBody({required this.markdown, super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = parseContent(markdown);
    return Column(
      key: const Key('devo-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          _ContentBlockView(block: block),
          if (block.kind != ContentKind.divider) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ContentBlockView extends StatelessWidget {
  const _ContentBlockView({required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyLarge;
    switch (block.kind) {
      case ContentKind.divider:
        return Divider(color: scheme.outline, height: 24);
      case ContentKind.heading:
        final size = switch (block.level) {
          1 => 28.0,
          2 => 22.0,
          _ => 18.0,
        };
        return Text.rich(
          TextSpan(children: _runs(context, block.runs, body)),
          style: TextStyle(
            fontFamily: AppTheme.serif,
            fontSize: size,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        );
      case ContentKind.quote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text.rich(
            TextSpan(
              text: '“',
              children: [
                ..._runs(context, block.runs, body),
                const TextSpan(text: '”'),
              ],
            ),
            style: body?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      case ContentKind.callout:
        final dark = Theme.of(context).brightness == Brightness.dark;
        final fill = dark ? const Color(0xFF24382C) : const Color(0xFFE7F0E4);
        final ink = dark ? const Color(0xFFE7F0E4) : const Color(0xFF24382C);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text.rich(
            TextSpan(children: _runs(context, block.runs, body)),
            style: body?.copyWith(color: ink),
          ),
        );
      case ContentKind.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: body),
            Expanded(
              child: Text.rich(
                TextSpan(children: _runs(context, block.runs, body)),
              ),
            ),
          ],
        );
      case ContentKind.number:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${block.index ?? 1}.  ', style: body),
            Expanded(
              child: Text.rich(
                TextSpan(children: _runs(context, block.runs, body)),
              ),
            ),
          ],
        );
      case ContentKind.paragraph:
        return Text.rich(TextSpan(children: _runs(context, block.runs, body)));
    }
  }

  List<InlineSpan> _runs(
    BuildContext context,
    List<RichRun> runs,
    TextStyle? base,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final run in runs)
        TextSpan(
          text: run.text,
          style: (base ?? const TextStyle()).copyWith(
            fontWeight: run.bold ? FontWeight.w700 : base?.fontWeight,
            fontStyle: run.italic ? FontStyle.italic : base?.fontStyle,
            fontFamily: run.code ? 'Inter' : base?.fontFamily,
            decoration: _decoration(run),
            color: run.link != null ? scheme.primary : base?.color,
            backgroundColor: run.code ? scheme.surfaceContainerLowest : null,
          ),
          recognizer: run.link == null
              ? null
              : (TapGestureRecognizer()..onTap = () {}),
        ),
    ];
  }

  TextDecoration? _decoration(RichRun run) {
    final parts = <TextDecoration>[];
    if (run.underline || run.link != null) parts.add(TextDecoration.underline);
    if (run.strike) parts.add(TextDecoration.lineThrough);
    if (parts.isEmpty) return null;
    return TextDecoration.combine(parts);
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
