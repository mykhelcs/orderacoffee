import 'package:flutter/material.dart';

class ScooterDeliveryGraphic extends StatefulWidget {
  const ScooterDeliveryGraphic({super.key});

  @override
  State<ScooterDeliveryGraphic> createState() => _ScooterDeliveryGraphicState();
}

class _ScooterDeliveryGraphicState extends State<ScooterDeliveryGraphic>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bounce = (_controller.value * 2.5);
        return SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _ScooterRoadPainter(bounce: bounce),
          ),
        );
      },
    );
  }
}

class _ScooterRoadPainter extends CustomPainter {
  _ScooterRoadPainter({required this.bounce});
  final double bounce;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw smooth curved road trajectory
    final path = Path();
    path.moveTo(0, height * 0.58);
    path.cubicTo(
      width * 0.25, height * 0.72,
      width * 0.45, height * 0.52,
      width * 0.75, height * 0.55,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFD4A373).withValues(alpha: 0.65)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, roadPaint);

    // Checkpoint node dot on the path
    final dotCenter = Offset(width * 0.54, height * 0.545);
    final dotOuterPaint = Paint()..color = const Color(0xFF5A3825);

    canvas.drawCircle(dotCenter, 9, dotOuterPaint);
    // Inner chevron / icon
    final chevronPath = Path();
    chevronPath.moveTo(dotCenter.dx - 2.5, dotCenter.dy - 3.5);
    chevronPath.lineTo(dotCenter.dx + 2, dotCenter.dy);
    chevronPath.lineTo(dotCenter.dx - 2.5, dotCenter.dy + 3.5);
    final chevronPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(chevronPath, chevronPaint);

    // 2. Draw Classic Scooter Courier on the right side
    final scooterX = width * 0.62;
    final scooterY = height * 0.22 + bounce;

    canvas.save();
    canvas.translate(scooterX, scooterY);

    final scooterPaint = Paint()..color = const Color(0xFFC86D36); // warm rust orange
    final darkPaint = Paint()..color = const Color(0xFF2C221E);
    final metalPaint = Paint()..color = const Color(0xFF8A7968);
    final skinPaint = Paint()..color = const Color(0xFFE8B382);
    final boxPaint = Paint()..color = const Color(0xFFF1E3D3);
    final jacketPaint = Paint()..color = const Color(0xFFDCA165);
    final whitePaint = Paint()..color = Colors.white;

    // Ground shadow under wheels
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(45, 88), width: 95, height: 12),
      shadowPaint,
    );

    // Rear Delivery Box
    final boxRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 26, 26, 26),
      const Radius.circular(5),
    );
    canvas.drawRRect(boxRRect, boxPaint);
    // Box strap / lock
    canvas.drawRect(
      const Rect.fromLTWH(11, 26, 4, 26),
      Paint()..color = const Color(0xFFD4A373),
    );

    // Courier Body (Jacket)
    final bodyPath = Path();
    bodyPath.moveTo(22, 28);
    bodyPath.lineTo(36, 16);
    bodyPath.lineTo(44, 24);
    bodyPath.lineTo(38, 48);
    bodyPath.lineTo(24, 46);
    bodyPath.close();
    canvas.drawPath(bodyPath, jacketPaint);

    // Courier Head & Helmet
    // Head / neck
    canvas.drawCircle(const Offset(38, 12), 7, skinPaint);
    // Helmet (Warm Tan / Orange)
    final helmetPath = Path();
    helmetPath.addArc(
      Rect.fromCircle(center: const Offset(37, 10), radius: 10),
      3.14,
      3.14,
    );
    canvas.drawPath(helmetPath, scooterPaint);
    canvas.drawCircle(const Offset(37, 8), 9, scooterPaint);
    // Helmet strap
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(37, 9), radius: 9),
      0,
      1.2,
      false,
      Paint()
        ..color = darkPaint.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Courier Arm & Handlebar grip
    final armPath = Path();
    armPath.moveTo(34, 22);
    armPath.lineTo(48, 28);
    armPath.lineTo(54, 38);
    canvas.drawPath(
      armPath,
      Paint()
        ..color = jacketPaint.color
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Courier Leg
    final legPath = Path();
    legPath.moveTo(28, 44);
    legPath.lineTo(40, 52);
    legPath.lineTo(40, 68);
    legPath.lineTo(48, 70);
    canvas.drawPath(
      legPath,
      Paint()
        ..color = darkPaint.color
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Scooter Body & Mudguards
    // Rear mudguard
    canvas.drawCircle(const Offset(18, 74), 16, scooterPaint);
    // Floorboard & Chassis
    final chassisPath = Path();
    chassisPath.moveTo(14, 64);
    chassisPath.quadraticBezierTo(35, 68, 54, 68);
    chassisPath.lineTo(58, 46);
    chassisPath.lineTo(64, 48);
    chassisPath.lineTo(58, 74);
    chassisPath.lineTo(26, 74);
    chassisPath.close();
    canvas.drawPath(chassisPath, scooterPaint);

    // Front Fairing / Apron
    final frontPath = Path();
    frontPath.moveTo(56, 42);
    frontPath.quadraticBezierTo(68, 52, 68, 72);
    frontPath.lineTo(60, 74);
    frontPath.quadraticBezierTo(60, 56, 52, 44);
    frontPath.close();
    canvas.drawPath(frontPath, scooterPaint);

    // Headlight & Handlebars
    canvas.drawCircle(const Offset(54, 37), 5, metalPaint);
    canvas.drawCircle(const Offset(57, 37), 3, Paint()..color = const Color(0xFFFFF7C2));

    // Wheels
    // Rear Wheel
    canvas.drawCircle(const Offset(18, 78), 12, darkPaint);
    canvas.drawCircle(const Offset(18, 78), 7, whitePaint);
    canvas.drawCircle(const Offset(18, 78), 3, metalPaint);

    // Front Wheel
    canvas.drawCircle(const Offset(68, 78), 12, darkPaint);
    canvas.drawCircle(const Offset(68, 78), 7, whitePaint);
    canvas.drawCircle(const Offset(68, 78), 3, metalPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScooterRoadPainter oldDelegate) =>
      oldDelegate.bounce != bounce;
}
