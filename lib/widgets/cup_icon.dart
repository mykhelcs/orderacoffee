import 'package:flutter/material.dart';

class CupIcon extends StatelessWidget {
  const CupIcon({
    super.key,
    this.size = 34.0,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CupPainter(color),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Cup body: M8 12h22l-2 20a3 3 0 0 1-3 3H13a3 3 0 0 1-3-3L8 12Z
    final bodyPath = Path()
      ..moveTo(8, 12)
      ..lineTo(30, 12)
      ..lineTo(28, 32)
      ..arcToPoint(
        const Offset(25, 35),
        radius: const Radius.circular(3),
        clockwise: false,
      )
      ..lineTo(13, 35)
      ..arcToPoint(
        const Offset(10, 32),
        radius: const Radius.circular(3),
        clockwise: false,
      )
      ..close();

    final bodyPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Handle: M30 16h3a3 3 0 0 1 0 8h-4
    final handlePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final handlePath = Path()
      ..moveTo(30, 16)
      ..lineTo(33, 16)
      ..arcToPoint(
        const Offset(33, 24),
        radius: const Radius.circular(4),
        clockwise: true,
      )
      ..lineTo(29, 24);
    canvas.drawPath(handlePath, handlePaint);

    // Steam waves: M14 6c0 3 3 3 3 6M21 6c0 3 3 3 3 6
    final steamPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final steam1 = Path()
      ..moveTo(14, 6)
      ..cubicTo(14, 9, 17, 9, 17, 12);
    canvas.drawPath(steam1, steamPaint);

    final steam2 = Path()
      ..moveTo(21, 6)
      ..cubicTo(21, 9, 24, 9, 24, 12);
    canvas.drawPath(steam2, steamPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CupPainter oldDelegate) =>
      oldDelegate.color != color;
}
