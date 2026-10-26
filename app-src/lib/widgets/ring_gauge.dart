// A ring gauge (circular progress) used for dues.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core.dart';

/// 270° progress ring with a big number in the middle (like the "1350 Calories" gauge).
class RingGauge extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final String center;
  final String? caption;
  const RingGauge({super.key, required this.value, this.size = 128, required this.center, this.caption});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(center, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
                if (caption != null)
                  Text(caption!, style: const TextStyle(color: inkSoft, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  _RingPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha(200);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = lavDeep;
    canvas.drawArc(rect, start, sweep, false, track);
    if (v > 0) canvas.drawArc(rect, start, sweep * v, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}
