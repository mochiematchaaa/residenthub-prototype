// Basic building blocks used everywhere: cards, pills, chips, section headers, empty boxes, avatars.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'motion.dart';

/// Color meaning of a pill/chip: good (green), warn (yellow), bad (red), info (blue).
enum Tone { good, warn, bad, info }

({Color bg, Color fg}) toneOf(BuildContext c, Tone t) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  switch (t) {
    case Tone.good:
      return dark
          ? (bg: const Color(0xFF1F3D2C), fg: const Color(0xFF7FCB98))
          : (bg: const Color(0xFFD9F2E3), fg: const Color(0xFF1F6B3F));
    case Tone.warn:
      return dark
          ? (bg: const Color(0xFF4A3A12), fg: const Color(0xFFF0C36C))
          : (bg: const Color(0xFFFFEFC2), fg: const Color(0xFF7A5200));
    case Tone.bad:
      return dark
          ? (bg: const Color(0xFF4A2119), fg: const Color(0xFFF0968A))
          : (bg: const Color(0xFFFFDADA), fg: const Color(0xFFA32D2D));
    case Tone.info:
      return dark
          ? (bg: const Color(0xFF2A2D52), fg: const Color(0xFFB6B9F5))
          : (bg: const Color(0xFFE6E5FC), fg: const Color(0xFF4A47A8));
  }
}

Tone toneForStatus(String s) {
  switch (s) {
    case 'Approved':
    case 'Paid':
    case 'Active':
    case 'Resolved':
    case 'Published':
    case 'Confirmed':
    case 'Verified':
      return Tone.good;
    case 'Pending':
    case 'In progress':
    case 'Draft':
    case 'Pending review':
    case 'Warning':
      return Tone.warn;
    case 'Denied':
    case 'Rejected':
    case 'Overdue':
    case 'Open':
    case 'Suspended':
    case 'Emergency':
    case 'Vacant':
      return Tone.bad;
    default:
      return Tone.info;
  }
}

Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

/// Bold heading style used for titles and big numbers.
TextStyle hd(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: -0.4, height: 1.15);

void go(BuildContext c, Widget page) => Navigator.of(c).push(appRoute(page));

void msg(BuildContext c, String text) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(BuildContext c, String title, String body,
    {String confirm = 'Confirm', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm, style: TextStyle(color: destructive ? danger : null, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ------------------------------------------------------------------ basics

/// The standard card.
class RCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const RCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(26);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? (color ?? cs.surface) : null,
            gradient: gradient,
            borderRadius: radius,
            // A clear edge, so a white card never melts into the page behind it.
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A3D63) : const Color(0xFFD9D9E8)),
            boxShadow: [
              BoxShadow(color: ink.withAlpha(24), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A small colored label such as 'Paid' or 'Pending'.
class Pill extends StatelessWidget {
  final String text;
  final Tone? tone;
  const Pill(this.text, {super.key, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = toneOf(context, tone ?? toneForStatus(text));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: t.fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Tone? tone;
  final bool accent;
  final double size;
  const IconBadge(this.icon, {super.key, this.tone, this.accent = false, this.size = 44});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    if (accent) {
      bg = lav.withAlpha(90);
      fg = lavDeep;
    } else {
      final t = toneOf(context, tone ?? Tone.info);
      bg = t.bg;
      fg = t.fg;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: size * 0.48),
    );
  }
}

/// A section title with an optional action button.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(tr(title), style: hd(19))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// A titled block of a dashboard: heading (with an optional link), an optional hint, then the content.
/// Every block of the home screens uses this so spacing and titles look the same everywhere.
class DashSection extends StatelessWidget {
  final String title;
  final String? hint;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;
  const DashSection({super.key, required this.title, this.hint, this.action, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, action: action, onAction: onAction),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(hint!, style: TextStyle(color: muted(context), fontSize: 12.5)),
          ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// A small label with a group of menu tiles under it (the More tab).
class NavGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const NavGroup({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(tr(label).toUpperCase(), style: TextStyle(color: muted(context), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }
}

class Reveal extends StatelessWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final ms = 320 + index.clamp(0, 8) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (c, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 22),
          child: Transform.scale(scale: 0.97 + 0.03 * v, child: ch),
        ),
      ),
      child: child,
    );
  }
}

/// The message shown when a list is empty.
class EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyBox(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 38, color: muted(context)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted(context))),
        ],
      ),
    );
  }
}

/// Horizontally scrolling filter chips.
class FilterRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const FilterRow({super.key, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final o = options[i];
          final sel = o == selected;
          return ChoiceChip(
            label: Text(o),
            selected: sel,
            showCheckmark: false,
            selectedColor: dark ? lav : ink,
            side: BorderSide.none,
            backgroundColor: Theme.of(c).colorScheme.surface,
            labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: sel ? (dark ? ink : Colors.white) : Theme.of(c).colorScheme.onSurface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
            onSelected: (_) => onSelect(o),
          );
        },
      ),
    );
  }
}

class NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Tone? tone;
  final Widget? trailing;
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return RCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconBadge(icon, accent: tone == null, tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(tr(subtitle), style: TextStyle(color: muted(context), fontSize: 12.5)),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: muted(context)),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Tone? tone;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    return RCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBadge(icon, tone: tone, accent: tone == null, size: 38),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(20)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A round picture or initials of a person.
class Avatar extends StatelessWidget {
  final String text;
  final double size;
  final Color? bg;

  /// Profile picture. When set it replaces the initials.
  final Uint8List? photo;
  const Avatar(this.text, {super.key, this.size = 40, this.bg, this.photo});

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg ?? lav,
      backgroundImage: p == null ? null : MemoryImage(p),
      child: p == null ? Text(text, style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: size * 0.34)) : null,
    );
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((s) => s[0]).join().toUpperCase();
}


/// An icon that suits an amenity, judged by its name. Anything unknown gets a generic one.
IconData amenityIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> w) => w.any(n.contains);
  if (has(['pool', 'swim'])) return Icons.pool_rounded;
  if (has(['gym', 'fitness', 'workout'])) return Icons.fitness_center_rounded;
  if (has(['basketball', 'court', 'tennis', 'badminton', 'sport'])) return Icons.sports_basketball_rounded;
  if (has(['hall', 'function', 'party', 'event'])) return Icons.celebration_rounded;
  if (has(['play', 'kid'])) return Icons.child_care_rounded;
  if (has(['garden', 'park', 'rooftop', 'deck'])) return Icons.park_rounded;
  if (has(['meeting', 'conference', 'study', 'lounge'])) return Icons.meeting_room_rounded;
  return Icons.event_available_rounded;
}
