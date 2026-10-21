import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/theme/app_theme.dart';
import 'package:micro_devos/domain/content/rich_document.dart';
import 'package:micro_devos/shared/widgets/reading_widgets.dart';

import 'support/load_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets('structured devotion text paints without markdown markers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const markdown = '''
# Known on every road

God is **near**, *present*, ++faithful++, ~~finished~~, and `refuge`.

Read [Psalm 46](https://example.com/psalm).

- Sit still
- Speak the verse

1. First
2. Second

> You are never out of sight.

:::callout
God knows the way home.
:::

---
''';
    final encoded = encodeContent(markdownToBlocks(markdown));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.paper,
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const Key('formatted-text'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DevoBody(markdown: encoded),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Known on every road'), findsOneWidget);
    expect(find.textContaining('near'), findsOneWidget);
    expect(find.textContaining('present'), findsOneWidget);
    expect(find.textContaining('faithful'), findsOneWidget);
    expect(find.textContaining('finished'), findsOneWidget);
    expect(find.textContaining('refuge'), findsOneWidget);
    expect(find.textContaining('Psalm 46'), findsOneWidget);
    expect(find.textContaining('Sit still'), findsOneWidget);
    expect(find.textContaining('1.'), findsWidgets);
    expect(find.textContaining('First'), findsOneWidget);
    expect(find.textContaining('Second'), findsOneWidget);
    expect(find.textContaining('You are never out of sight.'), findsOneWidget);
    expect(find.textContaining('God knows the way home.'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining(':::'), findsNothing);
    expect(find.textContaining('++'), findsNothing);
    expect(find.textContaining('~~'), findsNothing);

    await expectLater(
      find.byKey(const Key('formatted-text')),
      matchesGoldenFile('goldens/formatted-text.png'),
    );
    final bytes = File('test/goldens/formatted-text.png').readAsBytesSync();
    final artifact = File('/opt/cursor/artifacts/formatted-text.png');
    artifact.parent.createSync(recursive: true);
    artifact.writeAsBytesSync(bytes);
  });
}
