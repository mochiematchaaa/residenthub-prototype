// The pastel-styled widgets: circle buttons, cards, glass icons, feature tiles, stat rows.

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'motion.dart';

/// Round white button used in headers (search, bell, back, menu...).
class CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool dot;
  final String? tooltip;
  const CircleBtn(this.icon, {super.key, this.onTap, this.dot = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? '',
      child: Pressable(
        enabled: onTap != null,
        child: Material(
        color: cs.surface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: cs.onSurface),
                if (dot)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: PulseDot(border: cs.surface),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// A big rounded pastel card. Text inside is always ink-colored.
class PastelCard extends StatelessWidget {
  final Pastel color;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const PastelCard({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(color: color.color, borderRadius: radius),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: ink),
                child: IconTheme(data: const IconThemeData(color: ink), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small white circle holding an icon, for use on top of pastel cards.
class GlassIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const GlassIcon(this.icon, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white.withAlpha(190), shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: ink),
    );
  }
}

/// Feature tile: title + icon, a big live number, a short caption and a clear action.
class FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Pastel color;
  final VoidCallback onTap;
  final String cta;
  final String? metric; // big headline value, e.g. "3" or "Occupied"
  final String? badge; // small ink counter on the icon (used when there is no metric)
  const FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.cta = 'Open',
    this.metric,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.2)),
                ),
              ),
              const SizedBox(width: 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GlassIcon(icon, size: 34),
                  if (badge != null && metric == null)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(99)),
                        child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (metric != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedNumber(metric!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 30, letterSpacing: -0.8, height: 1.05)),
            ),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: inkSoft, fontSize: 12, height: 1.3)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withAlpha(170), borderRadius: BorderRadius.circular(99)),
                child: Text(cta, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(color: ink, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card with an illustration on top, a live number on the picture, a short
/// caption and a clear action. Used for "Needs attention" on the admin home.
class ImageTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image; // asset path, e.g. assets/images/need_dues.png
  final String metric;
  final Pastel color;
  final VoidCallback onTap;
  final String cta;
  const ImageTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.metric,
    required this.color,
    required this.onTap,
    this.cta = 'Open',
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Pressable(
      child: Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: color.color, borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  child: Image.asset(
                    image,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: double.infinity, height: 100),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AnimatedNumber(metric, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.8, height: 1.05)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: inkSoft, fontSize: 12, height: 1.25)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(170), borderRadius: BorderRadius.circular(99)),
                              child: Text(cta, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ),
                            const Spacer(),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(color: ink, shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// A row of label-over-big-number stats (Proteins / Fats / Carbs / RDC style).
class StatsRow extends StatelessWidget {
  final List<List<String>> items; // [label, value]
  const StatsRow(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Column(
              children: [
                Text(it[0], style: const TextStyle(color: inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedNumber(it[1], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small white pill button with a lavender icon (horizontal quick actions).
class ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ActionPill(this.icon, this.label, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: lavDeep),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
