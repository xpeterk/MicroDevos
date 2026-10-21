import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/theme/app_theme.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/domain/models/devo_note.dart';
import 'package:micro_devos/features/browse/feed_view.dart';

import 'support/load_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List bannerBytes;

  setUpAll(() async {
    await loadAppFonts();
    bannerBytes = File('test/fixtures/banner.png').readAsBytesSync();
  });

  testWidgets(
    'feed card paints a banner, and the placeholder when it is null',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpCard(tester, devo: _devo(imageUrl: null, imageAlt: null));
      expect(find.text('IMAGE PLACEHOLDER'), findsNothing);
      expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
      expect(find.text('3 SEC'), findsOneWidget);
      await _capture(tester, 'build-banner-fallback');

      const imageUrl = 'https://example.com/notion-banner.png';
      debugNetworkImageHttpClientProvider = () =>
          _BannerHttpClient(bannerBytes);
      try {
        await _pumpCard(
          tester,
          devo: _devo(imageUrl: imageUrl, imageAlt: 'A still morning'),
        );
        await tester.runAsync(() async {
          await precacheImage(
            NetworkImage(imageUrl),
            tester.element(find.byType(FeedPost)),
          );
        });
        await tester.pump();
        expect(find.text('IMAGE PLACEHOLDER'), findsNothing);
        expect(find.bySemanticsLabel('A still morning'), findsOneWidget);
        expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
        await _capture(tester, 'build-banner');
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }

      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpCard(WidgetTester tester, {required Devo devo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        favoritesProvider.overrideWith(_EmptyFavorites.new),
        notesProvider.overrideWith(_EmptyNotes.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.paper,
          body: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: FeedPost(
                devo: devo,
                total: 8,
                label: 'Courage',
                catalog: null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Devo _devo({required String? imageUrl, required String? imageAlt}) {
  return Devo(
    id: 'banner-card',
    title: 'A Refuge That Does Not Move',
    hook: 'The day can shake without moving the place you stand.',
    bodyMd: 'The refuge does not relocate when the headlines do.',
    takeaway: 'Sit for one quiet minute.',
    verseText: 'God is our refuge and strength.',
    verseRef: 'Psalm 46:1',
    scriptures: const [],
    editionDate: DateTime(2026, 10, 16),
    position: 1,
    status: 'published',
    tags: const ['courage'],
    imageUrl: imageUrl,
    imageAlt: imageAlt,
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(const Key('post-banner-card')),
    matchesGoldenFile('goldens/$name.png'),
  );
  final bytes = File('test/goldens/$name.png').readAsBytesSync();
  final artifact = File('/opt/cursor/artifacts/$name.png');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsBytesSync(bytes);
  expect(bytes.length, greaterThan(8000), reason: '$name png is too small');
  expect(bytes[0], 0x89);
  expect(bytes[1], 0x50);
}

class _BannerHttpClient extends Fake implements HttpClient {
  _BannerHttpClient(this.bytes);

  final Uint8List bytes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _BannerRequest(bytes);
}

class _BannerRequest extends Fake implements HttpClientRequest {
  _BannerRequest(this.bytes);

  final Uint8List bytes;

  @override
  HttpHeaders get headers => _BannerHeaders();

  @override
  Future<HttpClientResponse> close() async => _BannerResponse(bytes);
}

class _BannerHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _BannerResponse extends Fake implements HttpClientResponse {
  _BannerResponse(this.bytes);

  final Uint8List bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _EmptyFavorites extends FavoritesController {
  @override
  Future<Set<String>> build() async => <String>{};
}

class _EmptyNotes extends NotesController {
  @override
  Future<List<DevoNote>> build() async => <DevoNote>[];
}
