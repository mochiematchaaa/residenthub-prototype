// Small animations: press effect, counting numbers, fade-in tabs, pulsing dot, staggered lists.

import 'package:flutter/material.dart';

import '../core/core.dart';

// All the small animations of the app live here, so they are easy to find and tune.

/// Page change used everywhere: the new page fades in and slides up a little.
Route<T> appRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Shrinks its child a little while a finger is pressing it (cards, tiles, buttons).
class Pressable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const Pressable({super.key, required this.child, this.enabled = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Shows a whole number counting up from 0. Any other text (like "Open") is shown as it is.
class AnimatedNumber extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const AnimatedNumber(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(text.trim());
    if (n == null) return Text(text, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: n.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

/// Plays a short fade and slide every time its tab becomes the visible one.
class TabFadeIn extends StatefulWidget {
  final bool active;
  final Widget child;
  const TabFadeIn({super.key, required this.active, required this.child});

  @override
  State<TabFadeIn> createState() => _TabFadeInState();
}

class _TabFadeInState extends State<TabFadeIn> with SingleTickerProviderStateMixin {
  // starts finished (value: 1) so the first screen is not animated twice
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: 1);
  late final Animation<double> _v = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(covariant TabFadeIn old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _v,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _v.value,
        child: Transform.translate(offset: Offset(0, (1 - _v.value) * 16), child: child),
      ),
    );
  }
}

/// Small red notification dot that gently pulses.
class PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  final Color border;
  const PulseDot({super.key, this.size = 10, this.color = alertDot, required this.border});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.scale(
        scale: 0.85 + 0.3 * Curves.easeInOut.transform(_c.value),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: widget.border, width: 1.8),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a list of widgets in one after another (tiles, grids).
List<Widget> staggered(List<Widget> items, {int from = 1}) => [
      for (var i = 0; i < items.length; i++) _Stagger(index: from + i, child: items[i]),
    ];

class _Stagger extends StatelessWidget {
  final int index;
  final Widget child;
  const _Stagger({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index.clamp(0, 10) * 80),
      curve: Curves.easeOutBack,
      builder: (_, v, ch) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.92 + 0.08 * v, child: ch),
      ),
      child: child,
    );
  }
}
