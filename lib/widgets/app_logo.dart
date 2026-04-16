import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppLogoPainter(),
      ),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  static const Color _tealDark = Color(0xFF0B8A7A);
  static const Color _teal = Color(0xFF14CDBB);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [_tealDark, _teal],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.0,
      5.7,
      false,
      ringPaint,
    );

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..color = _teal;

    void tick(double angle) {
      final p1 = center + Offset.fromDirection(angle, radius * 0.74);
      final p2 = center + Offset.fromDirection(angle, radius * 0.92);
      canvas.drawLine(p1, p2, tickPaint);
    }

    tick(-1.57);
    tick(0);
    tick(1.57);
    tick(3.14);

    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [_tealDark, _teal],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final check = Path()
      ..moveTo(size.width * 0.28, size.height * 0.54)
      ..lineTo(size.width * 0.45, size.height * 0.68)
      ..lineTo(size.width * 0.76, size.height * 0.34);

    canvas.drawPath(check, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}