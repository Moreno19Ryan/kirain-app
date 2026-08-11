import 'package:flutter/material.dart';

/// The two asymmetric "raised eyebrow" arcs that are KIRAIN's signature
/// visual mark (CLAUDE.md 6.5) — reinterpreted from the reference SVG paths
/// as a CustomPainter rather than ported directly. `steep` mirrors the
/// reference's Zona Kirain variant: same arcs, pulled tighter for a more
/// urgent "kaget" expression.
///
/// Shared across Home's hero card, Onboarding, and the animated splash
/// screen — any surface that needs the brand mark reuses this instead of
/// redrawing it.
class KagetEyebrows extends StatelessWidget {
  const KagetEyebrows({
    super.key,
    required this.leftColor,
    required this.rightColor,
    this.steep = false,
    this.progress = 1.0,
    this.strokeWidth = 7,
  });

  final Color leftColor;
  final Color rightColor;
  final bool steep;

  /// 0.0-1.0 — how much of each arc is drawn, tip to tip. Used by the splash
  /// screen for a progressive "stroke reveal" animation; everywhere else
  /// (Home, Onboarding) just uses the default 1.0 (fully drawn, instant).
  final double progress;

  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: KagetEyebrowsPainter(
        leftColor: leftColor,
        rightColor: rightColor,
        steep: steep,
        progress: progress,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class KagetEyebrowsPainter extends CustomPainter {
  KagetEyebrowsPainter({
    required this.leftColor,
    required this.rightColor,
    required this.steep,
    this.progress = 1.0,
    this.strokeWidth = 7,
  });

  final Color leftColor;
  final Color rightColor;
  final bool steep;
  final double progress;
  final double strokeWidth;

  /// Reference viewBox from the mockup's SVG — canvas is scaled to fit
  /// whatever size the widget's actually given.
  static const _refWidth = 120.0;
  static const _refHeight = 54.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _refWidth, size.height / _refHeight);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final left = Path();
    final right = Path();
    if (steep) {
      left
        ..moveTo(6, 44)
        ..quadraticBezierTo(30, -2, 54, 26);
      right
        ..moveTo(66, 26)
        ..quadraticBezierTo(90, -2, 114, 44);
    } else {
      left
        ..moveTo(6, 40)
        ..quadraticBezierTo(30, 2, 54, 30);
      right
        ..moveTo(66, 30)
        ..quadraticBezierTo(90, 2, 114, 40);
    }

    canvas.drawPath(_trim(left, progress), paint..color = leftColor);
    canvas.drawPath(_trim(right, progress), paint..color = rightColor);
    canvas.restore();
  }

  /// Cuts [path] down to its first [t] fraction, tip to tip — the mechanism
  /// behind the splash screen's progressive stroke-drawing reveal.
  Path _trim(Path path, double t) {
    if (t >= 1.0) return path;
    if (t <= 0.0) return Path();

    final metric = path.computeMetrics().first;
    return metric.extractPath(0, metric.length * t);
  }

  @override
  bool shouldRepaint(covariant KagetEyebrowsPainter oldDelegate) {
    return leftColor != oldDelegate.leftColor ||
        rightColor != oldDelegate.rightColor ||
        steep != oldDelegate.steep ||
        progress != oldDelegate.progress ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
