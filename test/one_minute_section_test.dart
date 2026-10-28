import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/features/devo/one_minute_section.dart';

import 'support/load_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
  });

  Devo makeDevo({
    String? oneMinuteText,
    String? oneMinuteVerseRef,
    String? oneMinuteVerseText,
    String? oneMinuteToday,
    String verseText = 'Main verse text.',
    String verseRef = 'Romans 8:28',
  }) {
    return Devo(
      id: 'test-devo',
      title: 'Forgiveness on National TV',
      hook: 'Her husband was killed in Libya.',
      bodyMd: 'Full body content here.',
      takeaway: 'Forgiving points people to Jesus.',
      verseText: verseText,
      verseRef: verseRef,
      scriptures: const [],
      editionDate: DateTime(2026, 10, 27),
      position: 1,
      status: 'published',
      tags: const ['forgiveness'],
      oneMinuteText: oneMinuteText,
      oneMinuteVerseRef: oneMinuteVerseRef,
      oneMinuteVerseText: oneMinuteVerseText,
      oneMinuteToday: oneMinuteToday,
    );
  }

  Widget wrapWidget(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        fontFamily: 'Fraunces',
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when oneMinuteText is null or empty', (
    tester,
  ) async {
    final devoNull = makeDevo(oneMinuteText: null);
    await tester.pumpWidget(wrapWidget(OneMinuteSection(devo: devoNull)));
    expect(find.byKey(const Key('one-minute-bar')), findsNothing);

    final devoEmpty = makeDevo(oneMinuteText: '   ');
    await tester.pumpWidget(wrapWidget(OneMinuteSection(devo: devoEmpty)));
    expect(find.byKey(const Key('one-minute-bar')), findsNothing);
  });

  testWidgets('renders collapsed bar with A3 elements and toggles expansion', (
    tester,
  ) async {
    final devo = makeDevo(
      oneMinuteText: 'Ronnie and Anita Smith moved to Benghazi...',
      oneMinuteToday: 'Pray for believers in Libya.',
      oneMinuteVerseText: 'Love your enemies.',
      oneMinuteVerseRef: 'Luke 6:27-28 (ESV)',
    );

    await tester.pumpWidget(wrapWidget(OneMinuteSection(devo: devo)));

    // Collapsed state
    expect(find.byKey(const Key('one-minute-bar')), findsOneWidget);
    expect(find.text('1 Minute Micro Devo'), findsOneWidget);
    expect(find.text('The whole devo, fast'), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byKey(const Key('one-minute-expanded-card')), findsNothing);

    // Tap to expand
    await tester.tap(find.byKey(const Key('one-minute-toggle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byKey(const Key('one-minute-expanded-card')), findsOneWidget);
    expect(find.byKey(const Key('one-minute-share')), findsOneWidget);
    expect(find.byKey(const Key('one-minute-body')), findsOneWidget);
    expect(find.textContaining('Ronnie and Anita Smith moved'), findsOneWidget);
    expect(find.byKey(const Key('one-minute-today')), findsOneWidget);
    expect(find.textContaining('Pray for believers in Libya.'), findsOneWidget);
    expect(find.byKey(const Key('one-minute-verse-box')), findsOneWidget);
    expect(find.text('Love your enemies.'), findsOneWidget);
    expect(find.text('— Luke 6:27-28 (ESV)'), findsOneWidget);

    // Tap to collapse again
    await tester.tap(find.byKey(const Key('one-minute-toggle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byKey(const Key('one-minute-expanded-card')), findsNothing);
  });

  testWidgets('falls back to main verse text and ref when 1-minute verse fields are omitted', (
    tester,
  ) async {
    final devo = makeDevo(
      oneMinuteText: 'Short 1-minute summary.',
      verseText: 'Trust in the Lord with all your heart.',
      verseRef: 'Proverbs 3:5',
    );

    await tester.pumpWidget(
      wrapWidget(OneMinuteSection(devo: devo, initiallyExpanded: true)),
    );

    expect(find.byKey(const Key('one-minute-verse-box')), findsOneWidget);
    expect(find.text('Trust in the Lord with all your heart.'), findsOneWidget);
    expect(find.text('— Proverbs 3:5'), findsOneWidget);
    // Today line omitted since it was not provided
    expect(find.byKey(const Key('one-minute-today')), findsNothing);
  });

  testWidgets('omits verse box when both 1-minute and main verses are empty', (
    tester,
  ) async {
    final devo = makeDevo(
      oneMinuteText: 'Summary without any verse.',
      verseText: '',
      verseRef: '',
    );

    await tester.pumpWidget(
      wrapWidget(OneMinuteSection(devo: devo, initiallyExpanded: true)),
    );

    expect(find.byKey(const Key('one-minute-expanded-card')), findsOneWidget);
    expect(find.byKey(const Key('one-minute-verse-box')), findsNothing);
  });

  testWidgets('renders dark mode cleanly without error', (tester) async {
    final devo = makeDevo(
      oneMinuteText: 'Dark mode test paragraph.',
      oneMinuteToday: 'Reflect on God today.',
      oneMinuteVerseText: 'The Lord is my shepherd.',
      oneMinuteVerseRef: 'Psalm 23:1',
    );

    await tester.pumpWidget(
      wrapWidget(
        OneMinuteSection(devo: devo, initiallyExpanded: true),
        brightness: Brightness.dark,
      ),
    );

    expect(find.byKey(const Key('one-minute-bar')), findsOneWidget);
    expect(find.byKey(const Key('one-minute-expanded-card')), findsOneWidget);
    expect(find.text('The Lord is my shepherd.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
