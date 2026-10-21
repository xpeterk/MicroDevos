import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the reading fonts and Material Icons into the test font engine.
///
/// Flutter's test font draws every glyph as a box. These files are the same
/// ones declared in pubspec.yaml.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFamily('Source Serif 4', const [
    'assets/fonts/SourceSerif4-Regular.ttf',
    'assets/fonts/SourceSerif4-It.ttf',
    'assets/fonts/SourceSerif4-Semibold.ttf',
    'assets/fonts/SourceSerif4-Bold.ttf',
  ]);
  await _loadFamily('Source Sans 3', const [
    'assets/fonts/SourceSans3-Regular.ttf',
    'assets/fonts/SourceSans3-Medium.ttf',
    'assets/fonts/SourceSans3-Semibold.ttf',
  ]);
  await _loadFamily('Playfair Display', const [
    'assets/fonts/PlayfairDisplay-Regular.ttf',
    'assets/fonts/PlayfairDisplay-Italic.ttf',
    'assets/fonts/PlayfairDisplay-Bold.ttf',
    'assets/fonts/PlayfairDisplay-BoldItalic.ttf',
  ]);
  await _loadFamily('Space Grotesk', const [
    'assets/fonts/SpaceGrotesk-Medium.ttf',
    'assets/fonts/SpaceGrotesk-Bold.ttf',
  ]);
  await _loadFamily('Bebas Neue', const ['assets/fonts/BebasNeue-Regular.ttf']);
  await _loadFamily('Caveat', const [
    'assets/fonts/Caveat-Regular.ttf',
    'assets/fonts/Caveat-Bold.ttf',
  ]);
  await _loadFamily('Inter', const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Semibold.ttf',
  ]);
  await _loadFamily('DM Serif Display', const [
    'assets/fonts/DMSerifDisplay-Regular.ttf',
    'assets/fonts/DMSerifDisplay-Italic.ttf',
  ]);
  await _loadFamily('Fraunces', const [
    'assets/fonts/Fraunces-Regular.ttf',
    'assets/fonts/Fraunces-Semibold.ttf',
  ]);
  await _loadFamily('Abril Fatface', const [
    'assets/fonts/AbrilFatface-Regular.ttf',
  ]);
  await _loadMaterialIcons();
}

Future<void> _loadFamily(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

Future<void> _loadMaterialIcons() async {
  final font = _materialIconsFont();
  if (font == null) {
    throw StateError(
      'MaterialIcons font not found from ${Platform.resolvedExecutable}',
    );
  }
  final bytes = Uint8List.fromList(await font.readAsBytes());
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

File? _materialIconsFont() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var hop = 0; hop < 8; hop++) {
    final candidates = [
      File('${dir.path}/material_fonts/MaterialIcons-Regular.otf'),
      File('${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf'),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return null;
}
