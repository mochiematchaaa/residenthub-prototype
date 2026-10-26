// Small pieces of the Dues page: due state, countdown, ring painter and confetti.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// "Due in 3 days" / "Overdue by 2 days" for a charge that has a due date.
class DueCountdown {
  final int days;
  final Tone tone;
  final String text;
  const DueCountdown(this.days, this.tone, this.text);
}

DueCountdown? dueCountdown(Due d) {
  if (d.paid || d.dueDate.isEmpty) return null;
  final x = parseShortDate(d.dueDate);
  if (x == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final n = DateTime(x.year, x.month, x.day).difference(today).inDays;
  if (n < 0) return DueCountdown(n, Tone.bad, 'Overdue by ${-n} day${n == -1 ? '' : 's'}');
  if (n == 0) return DueCountdown(n, Tone.warn, 'Due today');
  return DueCountdown(n, n <= 3 ? Tone.warn : Tone.info, 'Due in $n day${n == 1 ? '' : 's'}');
}

/// The status of a charge as the resident sees it: paid, overdue, pending (a payment was sent) or open.
String dueState(Due d) {
  if (d.paid) return 'paid';
  if (d.overdue) return 'overdue';
  final pending = app.myProofs.any((p) => p.status == 'Pending' && p.forText == d.note);
  return pending ? 'pending' : 'open';
}

Tone dueTone(String st) => st == 'paid' ? Tone.good : (st == 'overdue' ? Tone.bad : (st == 'pending' ? Tone.warn : Tone.info));

IconData dueIcon(String st) =>
    st == 'paid' ? Icons.check_rounded : (st == 'overdue' ? Icons.priority_high_rounded : (st == 'pending' ? Icons.schedule_rounded : Icons.credit_card_rounded));

/// Short month label ("Oct") taken from a charge's due date.
String dueMonth(Due d) {
  final x = parseShortDate(d.dueDate);
  if (x == null) return '·';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return m[x.month - 1];
}

/// A progress ring drawn from 0 to [value] (0..1).
class RingPainter extends CustomPainter {
  final double value;
  final Color track, fill;
  RingPainter(this.value, this.track, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 11.0;
    final rect = Offset.zero & size;
    final r = Rect.fromCircle(center: rect.center, radius: (size.shortestSide - w) / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (value > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(RingPainter old) => old.value != value || old.track != track || old.fill != fill;
}

/// Throws confetti from [origin] (screen position) for about a second and a half.
void showConfetti(BuildContext context, Offset origin) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _ConfettiBurst(origin: origin, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Bit {
  final double angle, dist, spin;
  final Color color;
  _Bit(this.angle, this.dist, this.spin, this.color);
}

class _ConfettiBurst extends StatefulWidget {
  final Offset origin;
  final VoidCallback onDone;
  const _ConfettiBurst({required this.origin, required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    const colors = [Color(0xFFF4D84E), Color(0xFFF6B7D8), Color(0xFFAAB968), Color(0xFFB6C7EC), Color(0xFF7873D9), Color(0xFFD9A953)];
    _bits = [
      for (var i = 0; i < 42; i++) _Bit(rnd.nextDouble() * math.pi * 2, 80 + rnd.nextDouble() * 150, rnd.nextDouble() * 8 - 4, colors[i % colors.length]),
    ];
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_bits, widget.origin, _c.value)),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  final Offset origin;
  final double t;
  _ConfettiPainter(this.bits, this.origin, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final e = 1 - math.pow(1 - t, 3).toDouble();
    for (final b in bits) {
      final dx = math.cos(b.angle) * b.dist * e;
      final dy = math.sin(b.angle) * b.dist * e - 40 * e + 160 * t * t;
      final p = Paint()..color = b.color.withAlpha((255 * (1 - t * t)).clamp(0, 255).round());
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(b.spin * t * 3);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -6, 8, 12), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
