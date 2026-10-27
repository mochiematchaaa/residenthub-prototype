// The page frames: header, tab page and sub page.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'backdrop.dart';
import 'common.dart';
import 'pastel.dart';

/// Home-style header: avatar + greeting on the left, round buttons on the right.
class AppHeader extends StatelessWidget {
  final String initials;
  final String greeting;
  final VoidCallback? onAvatar;
  final Uint8List? photo;
  final List<Widget> actions;
  const AppHeader({super.key, required this.initials, required this.greeting, this.onAvatar, this.photo, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(onTap: onAvatar, child: Avatar(initials, size: 46, photo: photo)),
        const SizedBox(width: 12),
        Expanded(child: Text(greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(17, w: FontWeight.w700))),
        for (final a in actions) ...[const SizedBox(width: 10), a],
      ],
    );
  }
}

/// Bottom padding that keeps content clear of the floating nav bar.
const double kNavClearance = 118;

/// Frame of a main tab page.
class TabPage extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? header; // replaces title block
  final List<Widget> actions;
  final List<Widget> children;
  const TabPage({
    super.key,
    this.title,
    this.subtitle,
    this.header,
    this.actions = const [],
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, kNavClearance),
      children: [
        header ??
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(title ?? ''), style: hd(28)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(tr(subtitle!), style: TextStyle(color: muted(context), fontSize: 13.5, height: 1.35)),
                      ],
                    ],
                  ),
                ),
                for (final a in actions) ...[const SizedBox(width: 10), a],
              ],
            ),
        const SizedBox(height: 20),
        for (var i = 0; i < children.length; i++)
          Reveal(
            index: i,
            child: Padding(padding: const EdgeInsets.only(bottom: 16), child: children[i]),
          ),
      ],
    );
  }
}

/// Pushed sub-page: round back button, centered title (like the "Health" page).
class SubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? fab;
  const SubPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    return BuildingBackdrop(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(child: CircleBtn(Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop(), tooltip: 'Back')),
        ),
        title: Text(tr(title)),
        actions: [
          ...actions,
          const SizedBox(width: 20),
        ],
      ),
      floatingActionButton: fab,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
          children: [
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(tr(subtitle!), style: TextStyle(color: muted(context), height: 1.4)),
              ),
            for (var i = 0; i < children.length; i++)
              Reveal(
                index: i,
                child: Padding(padding: const EdgeInsets.only(bottom: 14), child: children[i]),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
