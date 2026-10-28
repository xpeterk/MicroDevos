import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../browse/share_sheet.dart';

/// A branded, collapsible 1 Minute Micro Devo section.
/// Displays at the top of a devotion detail screen when 1-minute text is present.
class OneMinuteSection extends StatefulWidget {
  const OneMinuteSection({
    required this.devo,
    this.initiallyExpanded = false,
    super.key,
  });

  final Devo devo;
  final bool initiallyExpanded;

  @override
  State<OneMinuteSection> createState() => _OneMinuteSectionState();
}

class _OneMinuteSectionState extends State<OneMinuteSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final devo = widget.devo;
    if (!devo.hasOneMinute) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Option A3 styling constants
    final barGradient = isDark
        ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFC99A2E), Color(0xFFA97D1C)],
          )
        : const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFF5C93A), Color(0xFFE0A41C)],
          );

    final barShadow = isDark
        ? const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.7),
            offset: Offset(0, 4),
            blurRadius: 14,
          )
        : const BoxShadow(
            color: Color.fromRGBO(150, 100, 0, 0.45),
            offset: Offset(0, 5),
            blurRadius: 14,
          );

    final barBorder = isDark
        ? Border.all(color: const Color.fromRGBO(255, 226, 130, 0.45), width: 1)
        : Border.all(color: const Color.fromRGBO(120, 80, 0, 0.35), width: 1);

    final circleFill = isDark
        ? const Color.fromRGBO(255, 240, 190, 0.28)
        : const Color.fromRGBO(255, 255, 255, 0.55);

    final iconColor = isDark ? const Color(0xFFFFF0BE) : const Color(0xFF3A2A00);
    final titleColor = isDark ? const Color(0xFFFFF6D6) : const Color(0xFF2E2200);
    final sublineColor = isDark ? const Color(0xFFF7E6B0) : const Color(0xFF5B4300);

    final pillBg = isDark ? const Color(0xFFF4D56A) : const Color(0xFF2E2200);
    final pillText = isDark ? const Color(0xFF2A2008) : const Color(0xFFF8D95A);
    final chevronColor = isDark ? const Color(0xFFF4D56A) : const Color(0xFF3A2A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gold Collapsed Bar
        Container(
          key: const Key('one-minute-bar'),
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          decoration: BoxDecoration(
            gradient: barGradient,
            borderRadius: BorderRadius.circular(16),
            border: barBorder,
            boxShadow: [barShadow],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('one-minute-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: SizedBox(
                height: 62,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // Circular Hourglass Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: circleFill,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.hourglass_empty,
                            size: 22,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Subline
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1 Minute Micro Devo',
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The whole devo, fast',
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: sublineColor,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // "1 min" pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '1 min',
                          style: TextStyle(
                            fontFamily: AppTheme.sans,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: pillText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: chevronColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Expanded Card
        if (_expanded)
          _ExpandedContentCard(
            devo: devo,
            isDark: isDark,
          ),
      ],
    );
  }
}

class _ExpandedContentCard extends StatelessWidget {
  const _ExpandedContentCard({
    required this.devo,
    required this.isDark,
  });

  final Devo devo;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF2C2926) : const Color(0xFFFFFFFF);
    final cardBorder = isDark
        ? const Color(0xFF4A453E)
        : const Color(0xFFB9AE97);
    final cardShadow = isDark
        ? const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.6),
            offset: Offset(0, 2),
            blurRadius: 8,
          )
        : const BoxShadow(
            color: Color.fromRGBO(70, 55, 25, 0.18),
            offset: Offset(0, 2),
            blurRadius: 8,
          );

    final textColor = isDark ? const Color(0xFFF6F0E2) : const Color(0xFF1F1B16);
    final todayText = devo.oneMinuteToday?.trim() ?? '';

    // Verse resolution
    final verseText = (devo.oneMinuteVerseText?.trim().isNotEmpty == true)
        ? devo.oneMinuteVerseText!.trim()
        : devo.verseText.trim();
    final verseRef = (devo.oneMinuteVerseRef?.trim().isNotEmpty == true)
        ? devo.oneMinuteVerseRef!.trim()
        : devo.verseRef.trim();
    final hasVerse = verseText.isNotEmpty || verseRef.isNotEmpty;

    return Container(
      key: const Key('one-minute-expanded-card'),
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Share button row (right-aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: const Key('one-minute-share'),
                icon: const Icon(Icons.ios_share, size: 20),
                tooltip: 'Share 1-minute devotion',
                visualDensity: VisualDensity.compact,
                color: isDark ? const Color(0xFFC4BBA8) : const Color(0xFF6B5F4B),
                onPressed: () => openShareSheet(context, devo),
              ),
            ],
          ),

          // 2. Paragraph (1-minute text)
          if (devo.oneMinuteText != null && devo.oneMinuteText!.trim().isNotEmpty)
            Text(
              devo.oneMinuteText!.trim(),
              key: const Key('one-minute-body'),
              style: TextStyle(
                fontFamily: AppTheme.serif,
                fontSize: 17,
                height: 1.55,
                color: textColor,
              ),
            ),

          // 3. 🙏 Today line
          if (todayText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text.rich(
                key: const Key('one-minute-today'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: '🙏 Today: ',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    TextSpan(
                      text: todayText,
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Cream Verse Box (strictly LAST)
          if (hasVerse)
            _OneMinuteVerseBox(
              text: verseText,
              reference: verseRef,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _OneMinuteVerseBox extends StatelessWidget {
  const _OneMinuteVerseBox({
    required this.text,
    required this.reference,
    required this.isDark,
  });

  final String text;
  final String reference;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgCol = isDark ? const Color(0xFF2E2819) : const Color(0xFFF3E9CF);
    final borderCol = isDark ? const Color(0xFF5A4B22) : const Color(0xFFE3D3A8);
    final accentCol = isDark ? const Color(0xFFE8C766) : const Color(0xFFA8291F);
    final textCol = isDark ? const Color(0xFFF3E9CF) : const Color(0xFF2A2420);
    final refCol = isDark ? const Color(0xFFE8C766) : const Color(0xFFA8291F);

    final hasText = text.isNotEmpty;
    final hasRef = reference.isNotEmpty;

    final formattedRef = hasRef
        ? (reference.startsWith('—') || reference.startsWith('\u2014')
            ? reference
            : '— $reference')
        : '';

    return Container(
      key: const Key('one-minute-verse-box'),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3px left accent bar
            Container(
              width: 3,
              color: accentCol,
            ),
            // Text & Reference column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasText)
                      Text(
                        text,
                        key: const Key('one-minute-verse-text'),
                        style: TextStyle(
                          fontFamily: AppTheme.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 16.5,
                          height: 1.45,
                          color: textCol,
                        ),
                      ),
                    if (hasText && hasRef) const SizedBox(height: 10),
                    if (hasRef)
                      Text(
                        formattedRef,
                        key: const Key('one-minute-verse-ref'),
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: refCol,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
