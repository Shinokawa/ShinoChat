import 'package:flutter/material.dart';

class ShinoMark extends StatelessWidget {
  const ShinoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ShinoMarkPainter()),
    );
  }
}

class _ShinoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512;
    canvas.save();
    canvas.scale(scale);

    final dark = Paint()..color = const Color(0xFF1D2026);
    final blue = Paint()..color = const Color(0xFFE85D93);
    final paper = Paint()..color = const Color(0xFFF4F6F8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Radius.circular(116),
      ),
      paper,
    );

    final outer = Path()
      ..moveTo(118, 253)
      ..cubicTo(118, 172, 183, 107, 264, 107)
      ..lineTo(295, 107)
      ..cubicTo(351, 107, 396, 152, 396, 208)
      ..cubicTo(396, 264, 351, 309, 295, 309)
      ..lineTo(260, 309)
      ..lineTo(196, 365)
      ..lineTo(196, 309)
      ..lineTo(174, 309)
      ..cubicTo(143, 309, 118, 284, 118, 253)
      ..close();
    canvas.drawPath(outer, dark);

    final inner = Path()
      ..moveTo(177, 243)
      ..cubicTo(177, 200, 211, 166, 254, 166)
      ..lineTo(294, 166)
      ..cubicTo(324, 166, 348, 190, 348, 220)
      ..cubicTo(348, 250, 324, 274, 294, 274)
      ..lineTo(263, 274)
      ..lineTo(225, 306)
      ..lineTo(225, 274)
      ..lineTo(208, 274)
      ..cubicTo(191, 274, 177, 260, 177, 243)
      ..close();
    canvas.drawPath(inner, paper);

    final wave = Path()
      ..moveTo(174, 382)
      ..cubicTo(205, 351, 247, 333, 291, 333)
      ..lineTo(302, 333)
      ..cubicTo(329, 333, 351, 355, 351, 382)
      ..cubicTo(351, 409, 329, 431, 302, 431)
      ..lineTo(236, 431)
      ..cubicTo(203, 431, 178, 412, 174, 382)
      ..close();
    canvas.drawPath(wave, blue);

    final fin = Path()
      ..moveTo(161, 155)
      ..cubicTo(183, 124, 218, 105, 257, 105)
      ..lineTo(280, 105)
      ..cubicTo(240, 126, 213, 158, 201, 202)
      ..cubicTo(187, 192, 173, 176, 161, 155)
      ..close();
    canvas.drawPath(fin, blue);

    canvas.drawCircle(const Offset(242, 221), 14, dark);
    canvas.drawCircle(const Offset(294, 221), 14, dark);
    canvas.drawArc(
      const Rect.fromLTWH(238, 238, 62, 44),
      0.24,
      2.66,
      false,
      Paint()
        ..color = const Color(0xFF1D2026)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 14,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
