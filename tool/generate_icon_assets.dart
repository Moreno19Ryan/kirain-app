// Regenerates the app icon + native-splash mark PNGs under assets/icon/ and
// assets/splash/ from the "Glass Depth" spec in CLAUDE.md's "App Icon —
// FINAL" section. Not a real test, but needs a `flutter test` invocation
// (not plain `dart run`) for working dart:ui bindings — kept outside test/
// so a bare `flutter test` doesn't re-run it and overwrite the assets.
//
// Usage: flutter test tool/generate_icon_assets.dart
// After running, re-generate the derived launcher/splash outputs with:
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

// Background gradient, 135° diagonal (topLeft -> bottomRight).
const _mintLight = Color(0xFF8FEAD1);
const _mintMid = Color(0xFF6BCBAF);
const _mintDark = Color(0xFF4FAE93);

// App-icon mark colors: dark/neutral left arc reads against the mint
// gradient background specifically — NOT reused for the splash screen's flat
// backgrounds (see _paintMark's leftColor/rightColor params below).
const _iconMarkLeft = Color(0xFF0D1412);
const _iconMarkRight = Color(0xFFFF8B5E);

// Splash mark colors: same fill-vs-strong split KirainColors uses elsewhere
// (mint/coral direct on dark bg, the darkened *Strong variants on light bg)
// so the mark stays legible against a flat solid background instead of the
// icon's gradient.
const _splashMarkLeftDark = Color(0xFF7FE0C4);
const _splashMarkRightDark = Color(0xFFFF8B5E);
const _splashMarkLeftLight = Color(0xFF12946E);
const _splashMarkRightLight = Color(0xFFE2613A);

void _paintBackground(Canvas canvas) {
  final rect = Rect.fromLTWH(0, 0, _size, _size);
  final gradient = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_mintLight, _mintMid, _mintDark],
      stops: [0.0, 0.5, 1.0],
    ).createShader(rect);
  canvas.drawRect(rect, gradient);

  // Glass highlight: radial white->transparent near the top-left, ~10-15%
  // inset from the edge.
  final highlightCenter = Offset(_size * 0.15, _size * 0.15);
  final highlightPaint = Paint()
    ..shader = ui.Gradient.radial(highlightCenter, _size * 0.55, [
      const Color(0x8CFFFFFF), // ~55% white
      const Color(0x00FFFFFF),
    ]);
  canvas.drawRect(rect, highlightPaint);
}

void _paintMark(Canvas canvas, {required Color leftColor, required Color rightColor, bool shadow = true}) {
  // Reference viewBox matching KagetEyebrowsPainter (120x54), scaled so the
  // mark occupies ~62% of the icon's width, centered.
  const refWidth = 120.0;
  const refHeight = 54.0;
  final markWidth = _size * 0.62;
  final scale = markWidth / refWidth;
  final markHeight = refHeight * scale;

  canvas.save();
  // The reference path's own bounding box sits slightly below its nominal
  // viewBox center (measured empirically), so nudge up a touch for true
  // visual centering within the icon canvas.
  canvas.translate((_size - markWidth) / 2, (_size - markHeight) / 2 - _size * 0.024);
  canvas.scale(scale);

  Path arcPath(double startX, double startY, double ctrlX, double ctrlY, double endX, double endY) {
    return Path()
      ..moveTo(startX, startY)
      ..quadraticBezierTo(ctrlX, ctrlY, endX, endY);
  }

  final left = arcPath(6, 40, 30, 2, 54, 30);
  final right = arcPath(66, 30, 90, 2, 114, 40);

  final strokeWidth = 7.0;

  if (shadow) {
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x552F241C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(left, shadowPaint);
    canvas.drawPath(right, shadowPaint);
    canvas.restore();
  }

  final strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;

  canvas.drawPath(left, strokePaint..color = leftColor);
  canvas.drawPath(right, strokePaint..color = rightColor);
  canvas.restore();
}

Future<void> _capture(String path, void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _size, _size));
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_size.toInt(), _size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icon + splash assets', (tester) async {
    await tester.runAsync(() async {
      await _capture('assets/icon/adaptive_background.png', _paintBackground);
      await _capture(
        'assets/icon/adaptive_foreground.png',
        (canvas) => _paintMark(canvas, leftColor: _iconMarkLeft, rightColor: _iconMarkRight),
      );
      await _capture('assets/icon/icon.png', (canvas) {
        _paintBackground(canvas);
        _paintMark(canvas, leftColor: _iconMarkLeft, rightColor: _iconMarkRight);
      });

      // Square, transparent-background mark variants for the native splash's
      // Android 12+ icon slot — mode-matched colors (not the icon's
      // gradient-specific dark/coral) so the mark stays legible on a flat
      // bg/bg_dark background. No drop shadow: a flat solid splash
      // background doesn't need the "floating" depth cue the gradient icon
      // does.
      await _capture(
        'assets/splash/splash_icon_dark.png',
        (canvas) =>
            _paintMark(canvas, leftColor: _splashMarkLeftDark, rightColor: _splashMarkRightDark, shadow: false),
      );
      await _capture(
        'assets/splash/splash_icon_light.png',
        (canvas) => _paintMark(
          canvas,
          leftColor: _splashMarkLeftLight,
          rightColor: _splashMarkRightLight,
          shadow: false,
        ),
      );
    });
  });
}
