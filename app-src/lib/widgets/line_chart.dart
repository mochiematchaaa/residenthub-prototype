// A smooth line chart (collection trend).

import 'package:flutter/material.dart';

import '../core/core.dart';

/// Smooth single-series line chart with grid, labels and a highlighted peak.
class SmoothLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;
  final String Function(double)? format;
  final bool floorAtZero;
  const SmoothLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 170,
    this.format,
    this.floorAtZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // the line draws itself from left to right
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _ChartPainter(values, labels, cs.outlineVariant, cs.onSurfaceVariant, format, floorAtZero, t),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> v;
  final List<String> labels;
  final Color grid, text;
  final String Function(double)? format;
  final bool floorZero;
  final double t; // 0..1 how much of the line is drawn
  _ChartPainter(this.v, this.labels, this.grid, this.text, this.format, this.floorZero, this.t);

  void _label(Canvas c, String s, Offset o, {bool right = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (right) dx -= tp.width;
    if (center) dx -= tp.width / 2;
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    const left = 42.0, bottom = 22.0, top = 14.0;
    final w = size.width - left - 8;
    final h = size.height - bottom - top;
    var lo = v.reduce((a, b) => a < b ? a : b);
    var hi = v.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * 0.25 + 1;
    lo -= pad;
    hi += pad;
    if (floorZero && lo < 0) lo = 0;
    double x(int i) => left + w * i / (v.length - 1);
    double y(double val) => top + h * (1 - (val - lo) / (hi - lo));

    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final gy = top + h * i / 3;
      canvas.drawLine(Offset(left, gy), Offset(size.width - 8, gy), gridPaint);
      final tick = hi - (hi - lo) * i / 3;
      _label(canvas, format != null ? format!(tick) : tick.round().toString(), Offset(left - 6, gy), right: true);
    }
    for (var i = 0; i < labels.length && i < v.length; i++) {
      _label(canvas, labels[i], Offset(x(i), size.height - 6), center: true);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, left + w * t + 8, size.height));
    final path = Path()..moveTo(x(0), y(v[0]));
    for (var i = 0; i < v.length - 1; i++) {
      final mx = (x(i) + x(i + 1)) / 2;
      path.cubicTo(mx, y(v[i]), mx, y(v[i + 1]), x(i + 1), y(v[i + 1]));
    }
    final fill = Path.from(path)
      ..lineTo(x(v.length - 1), top + h)
      ..lineTo(x(0), top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lav.withAlpha(120), lav.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = lavDeep,
    );

    // highlight the peak
    var pk = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[pk]) pk = i;
    }
    canvas.drawLine(Offset(x(pk), y(v[pk])), Offset(x(pk), top + h), Paint()..color = alertDot..strokeWidth = 1.5);
    canvas.drawCircle(Offset(x(pk), y(v[pk])), 6, Paint()..color = alertDot);
    canvas.drawCircle(Offset(x(pk), y(v[pk])), 2.5, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
