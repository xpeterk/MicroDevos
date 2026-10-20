import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/core/theme/app_theme.dart';
import 'package:micro_devos/data/sample/sample_catalog.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/domain/models/devo_note.dart';
import 'package:micro_devos/features/browse/feed_view.dart';
import 'package:micro_devos/shared/widgets/reading_widgets.dart';

import 'support/load_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List wideBytes;

  setUpAll(() async {
    await loadAppFonts();
    wideBytes = File('test/fixtures/banner_wide.png').readAsBytesSync();
  });

  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
  });

  test('android manifest does not lock portrait', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest.contains('screenOrientation="portrait"'), isFalse);
    expect(manifest, contains('android:screenOrientation="fullUser"'));
    expect(manifest, contains('android:resizeableActivity="true"'));
    expect(supportedOrientations, [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  });

  test('startup allows every orientation', () async {
    final seen = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        seen.addAll((call.arguments as List).cast<String>());
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await prepareFramework();
    expect(seen, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('today feed keeps positions 1 then 2', (tester) async {
    await tester.pumpWidget(_feedApp([_devo(position: 1), _devo(position: 2)]));
    await tester.pump();
    final first = tester.getTopLeft(find.text('1 of 2'));
    final second = tester.getTopLeft(find.text('2 of 2'));
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets('a banner image is full width at its own ratio, with no title', (
    tester,
  ) async {
    const url = 'https://example.com/wide.png';
    debugNetworkImageHttpClientProvider = () => _BytesClient(wideBytes);
    await _pumpSurface(
      tester,
      size: const Size(390, 844),
      child: _post(imageUrl: url),
    );
    try {
      await _settlePhoto(tester, url);

      expect(find.text('IMAGE PLACEHOLDER'), findsNothing);
      expect(find.text('A Refuge That Does Not Move'), findsNothing);
      expect(find.bySemanticsLabel('A still morning'), findsOneWidget);

      final image = tester.widget<Image>(
        find.byKey(const ValueKey('banner-photo-$url')),
      );
      expect(image.fit, BoxFit.fitWidth);
      final banner = tester.getRect(find.byKey(const Key('banner-wide-1')));
      expect(banner.left, closeTo(0, 1));
      expect(banner.width, closeTo(390, 1));
      expect(banner.height, closeTo(390 / 3, 1.5));

      await _capture(
        tester,
        find.byKey(const Key('post-wide-1')),
        'banner-portrait',
      );
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('a missing banner keeps the title and the placeholder', (
    tester,
  ) async {
    await _pumpSurface(
      tester,
      size: const Size(390, 844),
      child: _post(imageUrl: null),
    );
    await tester.pump();
    expect(find.text('IMAGE PLACEHOLDER'), findsOneWidget);
    expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
    final banner = tester.getSize(find.byKey(const Key('banner-wide-1')));
    expect(banner.width, closeTo(banner.height, 1));
  });

  testWidgets(
    'landscape centers a capped column and does not crop the banner',
    (tester) async {
      const url = 'https://example.com/wide.png';
      debugNetworkImageHttpClientProvider = () => _BytesClient(wideBytes);
      const view = Size(1100, 700);
      await _pumpSurface(
        tester,
        size: view,
        child: FeedView(
          devos: [_devo(position: 1, imageUrl: url)],
          edition: DateTime(2026, 10, 19),
          isFallback: false,
        ),
      );
      try {
        await _settlePhoto(tester, url);

        final post = tester.getRect(find.byKey(const Key('post-wide-1')));
        final banner = tester.getRect(find.byKey(const Key('banner-wide-1')));
        expect(post.width, closeTo(feedContentMaxWidth, 1));
        expect(post.left, closeTo((view.width - feedContentMaxWidth) / 2, 1));
        expect(banner.left, closeTo(post.left, 1));
        expect(banner.width, closeTo(post.width, 1));
        expect(banner.height, closeTo(banner.width / 3, 1.5));
        expect(find.text('A Refuge That Does Not Move'), findsNothing);

        final image = tester.widget<Image>(
          find.byKey(const ValueKey('banner-photo-$url')),
        );
        expect(image.fit, BoxFit.fitWidth);
        await _capture(tester, find.byType(FeedView), 'banner-landscape');
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_host(child));
  await tester.pump();
}

Widget _host(Widget child) {
  return ProviderScope(
    overrides: [
      favoritesProvider.overrideWith(_EmptyFavorites.new),
      notesProvider.overrideWith(_EmptyNotes.new),
      sampleCatalogProvider.overrideWith(
        (ref) async => const SampleCatalog(devos: [], tags: []),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(backgroundColor: AppColors.paper, body: child),
    ),
  );
}

Widget _feedApp(List<Devo> devos) {
  return _host(
    FeedView(devos: devos, edition: DateTime(2026, 10, 19), isFallback: false),
  );
}

Widget _post({required String? imageUrl}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SingleChildScrollView(
      child: FeedPost(
        devo: _devo(position: 1, imageUrl: imageUrl),
        total: 8,
        label: 'Courage',
        catalog: null,
      ),
    ),
  );
}

Future<void> _settlePhoto(WidgetTester tester, String url) async {
  final context = tester.element(find.byKey(const Key('banner-wide-1')));
  await tester.runAsync(() async {
    await precacheImage(NetworkImage(url), context);
  });
  await tester.pump();
  final key = ValueKey('banner-photo-$url');
  for (var i = 0; i < 8; i++) {
    if (find.byKey(key).evaluate().isNotEmpty) {
      final banner = tester.getSize(find.byKey(const Key('banner-wide-1')));
      if ((banner.width / banner.height - 3).abs() < 0.08) return;
    }
    await tester.pump();
  }
  final error = tester.takeException();
  fail(
    'banner did not settle at the decoded 3:1 ratio'
    '${error == null ? '' : ' ($error)'}',
  );
}

Future<void> _capture(WidgetTester tester, Finder finder, String name) async {
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
  final bytes = File('test/goldens/$name.png').readAsBytesSync();
  final artifact = File('/opt/cursor/artifacts/$name.png');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsBytesSync(bytes);
}

Devo _devo({required int position, String? imageUrl}) {
  return Devo(
    id: 'wide-$position',
    title: 'A Refuge That Does Not Move',
    hook: 'The day can shake without moving the place you stand.',
    bodyMd: 'The refuge does not relocate when the headlines do.',
    takeaway: 'Sit for one quiet minute.',
    verseText: 'God is our refuge and strength.',
    verseRef: 'Psalm 46:1',
    scriptures: const [],
    editionDate: DateTime(2026, 10, 19),
    position: position,
    status: 'archive',
    tags: const ['courage'],
    imageUrl: imageUrl,
    imageAlt: imageUrl == null ? null : 'A still morning',
  );
}

class _BytesClient extends Fake implements HttpClient {
  _BytesClient(this.bytes);

  final Uint8List bytes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _BytesRequest(bytes);
}

class _BytesRequest extends Fake implements HttpClientRequest {
  _BytesRequest(this.bytes);

  final Uint8List bytes;

  @override
  HttpHeaders get headers => _BytesHeaders();

  @override
  Future<HttpClientResponse> close() async => _BytesResponse(bytes);
}

class _BytesHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _BytesResponse extends Fake implements HttpClientResponse {
  _BytesResponse(this.bytes);

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
