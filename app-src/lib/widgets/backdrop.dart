// The soft building picture behind the login screen.

import 'package:flutter/material.dart';

/// The City Residences building photo, softly faded behind a screen.
///
/// Wrap a `Scaffold` that has `backgroundColor: Colors.transparent`. The photo sits
/// behind the whole screen and is covered by a veil in the normal page colour, so
/// cards and text stay easy to read in both light and dark mode.
/// To make the building clearer or fainter, change the two alpha numbers below
/// (higher number = fainter photo).
class BuildingBackdrop extends StatelessWidget {
  final Widget child;
  const BuildingBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = theme.scaffoldBackgroundColor;
    final topVeil = dark ? 200 : 185; // over the top of the photo
    final midVeil = dark ? 232 : 228; // lower down
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        Image.asset(
          'assets/images/building.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [base.withAlpha(topVeil), base.withAlpha(midVeil), base],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
