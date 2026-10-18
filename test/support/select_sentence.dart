import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const anchorSentence = 'Being still is not the same as having nothing to do.';

/// Drags across [sentence] with a mouse so the feed scroll view does not
/// take the gesture. A long-press on the paragraph center lands on a period.
Future<void> selectSentence(WidgetTester tester, String sentence) async {
  final finder = find.textContaining(sentence);
  expect(finder, findsWidgets);
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.35);
  await tester.pump();

  final render = _paragraphOf(tester.element(finder.first));
  final plain = render.text.toPlainText();
  final start = plain.indexOf(sentence);
  expect(start, greaterThanOrEqualTo(0));
  final from = _glyphPoint(render, start, leading: true);
  final to = _glyphPoint(render, start + sentence.length - 1, leading: false);

  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    await gesture.moveTo(
      Offset(from.dx + (to.dx - from.dx) * t, from.dy + (to.dy - from.dy) * t),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

RenderParagraph _paragraphOf(Element element) {
  final object = element.renderObject;
  if (object != null) {
    final found = _findParagraph(object);
    if (found != null) return found;
  }
  throw StateError('No selectable paragraph for the sentence');
}

RenderParagraph? _findParagraph(RenderObject object) {
  if (object is RenderParagraph) return object;
  RenderParagraph? found;
  object.visitChildren((child) {
    found ??= _findParagraph(child);
  });
  return found;
}

Offset _glyphPoint(
  RenderParagraph render,
  int charIndex, {
  required bool leading,
}) {
  final left = render.getOffsetForCaret(
    TextPosition(offset: charIndex),
    Rect.zero,
  );
  final right = render.getOffsetForCaret(
    TextPosition(offset: charIndex + 1),
    Rect.zero,
  );
  final wrapped = right.dy > left.dy + 1 || right.dx <= left.dx;
  final dx = wrapped
      ? (leading ? 1.0 : 4.0)
      : (right.dx - left.dx) * (leading ? 0.25 : 0.75);
  return render.localToGlobal(left + Offset(dx, 8));
}
