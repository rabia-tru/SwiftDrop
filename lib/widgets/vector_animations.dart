import 'dart:math';
import 'package:flutter/material.dart';

/// Animated motorcycle that drives across the screen
class MotorcyclePainter extends CustomPainter {
  final double progress;
  final double bounceOffset;

  MotorcyclePainter({required this.progress, this.bounceOffset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2 + bounceOffset;
    final s = size.width / 200;

    // Motorcycle body/frame
    paint.color = Colors.white;
    final frame = Path()
      ..moveTo(cx - 10 * s, cy + 10 * s)
      ..lineTo(cx + 30 * s, cy - 20 * s)
      ..lineTo(cx + 60 * s, cy - 15 * s)
      ..lineTo(cx + 65 * s, cy + 10 * s)
      ..lineTo(cx + 65 * s, cy + 35 * s)
      ..lineTo(cx - 10 * s, cy + 35 * s)
      ..close();
    canvas.drawPath(frame, paint);

    // Fuel tank
    paint.color = const Color(0xFFFFB300);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5 * s, cy - 40 * s, 40 * s, 22 * s),
        Radius.circular(10 * s),
      ),
      paint,
    );

    // Delivery box
    paint.color = const Color(0xFFE65100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 70 * s, cy - 45 * s, 55 * s, 55 * s),
        Radius.circular(8 * s),
      ),
      paint,
    );

    // Box lid
    paint.color = const Color(0xFFBF360C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 74 * s, cy - 52 * s, 63 * s, 12 * s),
        Radius.circular(4 * s),
      ),
      paint,
    );

    // Lightning bolt on box
    paint.color = Colors.white;
    final bolt = Path()
      ..moveTo(cx - 52 * s, cy - 38 * s)
      ..lineTo(cx - 42 * s, cy - 18 * s)
      ..lineTo(cx - 50 * s, cy - 18 * s)
      ..lineTo(cx - 44 * s, cy - 2 * s)
      ..lineTo(cx - 32 * s, cy - 22 * s)
      ..lineTo(cx - 38 * s, cy - 22 * s)
      ..close();
    canvas.drawPath(bolt, paint);

    // Rear wheel
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx - 5 * s, cy + 48 * s), 16 * s, paint);
    paint.color = const Color(0xFFFF6D00);
    canvas.drawCircle(Offset(cx - 5 * s, cy + 48 * s), 9 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx - 5 * s, cy + 48 * s), 3 * s, paint);

    // Front wheel
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx + 68 * s, cy + 48 * s), 16 * s, paint);
    paint.color = const Color(0xFFFF6D00);
    canvas.drawCircle(Offset(cx + 68 * s, cy + 48 * s), 9 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx + 68 * s, cy + 48 * s), 3 * s, paint);

    // Handlebar
    paint
      ..color = Colors.white
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx + 50 * s, cy - 28 * s),
      Offset(cx + 62 * s, cy - 48 * s),
      paint,
    );
    canvas.drawLine(
      Offset(cx + 56 * s, cy - 52 * s),
      Offset(cx + 68 * s, cy - 42 * s),
      paint,
    );

    // Headlight glow
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FFEB3B);
    canvas.drawCircle(Offset(cx + 68 * s, cy - 8 * s), 12 * s, paint);
    paint.color = const Color(0xFFFFEB3B);
    canvas.drawCircle(Offset(cx + 68 * s, cy - 8 * s), 6 * s, paint);
  }

  @override
  bool shouldRepaint(MotorcyclePainter old) => old.progress != progress || old.bounceOffset != bounceOffset;
}

/// Animated route/path line
class RouteLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  RouteLinePainter({required this.progress, this.color = Colors.white70});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.1, h * 0.5);
    path.cubicTo(
      w * 0.25, h * 0.2,
      w * 0.45, h * 0.8,
      w * 0.6, h * 0.4,
    );
    path.cubicTo(
      w * 0.75, h * 0.1,
      w * 0.85, h * 0.6,
      w * 0.95, h * 0.35,
    );

    final metrics = path.computeMetrics().first;
    final extractedPath = metrics.extractPath(0, metrics.length * progress);

    // Draw dashed outline
    paint..strokeWidth = 4..color = color.withValues(alpha: 0.2);
    canvas.drawPath(path, paint);

    // Draw animated portion
    paint..strokeWidth = 3..color = color;
    canvas.drawPath(extractedPath, paint);

    // Draw dot at the end
    if (progress > 0) {
      final tangent = metrics.getTangentForOffset(metrics.length * progress);
      if (tangent != null) {
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white;
        canvas.drawCircle(tangent.position, 5, paint);
        paint.color = color;
        canvas.drawCircle(tangent.position, 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(RouteLinePainter old) => old.progress != progress;
}

/// Animated floating particles (dots moving upward)
class ParticlePainter extends CustomPainter {
  final double animationValue;
  final int count;

  ParticlePainter({required this.animationValue, this.count = 15});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (int i = 0; i < count; i++) {
      final baseX = random.nextDouble() * size.width;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * pi;
      final particleSize = 1.5 + random.nextDouble() * 3;

      final t = (animationValue * speed + random.nextDouble()) % 1.0;
      final x = baseX + sin(t * 4 * pi + phase) * 20;
      final y = size.height * (1 - t);

      final alpha = (t < 0.3) ? t / 0.3 : (t > 0.7) ? (1 - t) / 0.3 : 1.0;
      paint.color = Colors.white.withValues(alpha: alpha * 0.4);

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => old.animationValue != animationValue;
}

/// Pulsing circle ring animation
class PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  PulseRingPainter({required this.progress, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.4;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * ringProgress;
      final alpha = (1 - ringProgress) * 0.4;

      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(PulseRingPainter old) => old.progress != progress;
}

/// Animated delivery box that bounces
class DeliveryBoxPainter extends CustomPainter {
  final double progress;
  final double bounceY;

  DeliveryBoxPainter({required this.progress, this.bounceY = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final s = size.width / 100;
    final cx = size.width / 2;
    final cy = size.height / 2 + bounceY;

    // Box body
    paint.color = const Color(0xFFFF6D00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 30 * s, cy - 25 * s, 60 * s, 50 * s),
        Radius.circular(6 * s),
      ),
      paint,
    );

    // Box lid
    paint.color = const Color(0xFFE65100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 34 * s, cy - 30 * s, 68 * s, 10 * s),
        Radius.circular(4 * s),
      ),
      paint,
    );

    // Stripe
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(cx - 24 * s, cy - 8 * s, 48 * s, 8 * s),
      paint,
    );

    // Arrow up
    paint.color = Colors.white;
    final arrow = Path()
      ..moveTo(cx, cy - 20 * s)
      ..lineTo(cx + 12 * s, cy - 8 * s)
      ..lineTo(cx + 5 * s, cy - 8 * s)
      ..lineTo(cx + 5 * s, cy + 10 * s)
      ..lineTo(cx - 5 * s, cy + 10 * s)
      ..lineTo(cx - 5 * s, cy - 8 * s)
      ..lineTo(cx - 12 * s, cy - 8 * s)
      ..close();
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(DeliveryBoxPainter old) =>
      old.progress != progress || old.bounceY != bounceY;
}
