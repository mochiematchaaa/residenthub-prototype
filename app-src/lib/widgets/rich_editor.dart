// A small formatted-text box for polls: bold, italic, underline, bullet list and larger text.
// The text is shown formatted while you type, and is saved as the simple HTML the website uses.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../core/rich_text.dart';

/// A text controller that keeps a style for every character.
class RtController extends TextEditingController {
  List<int> styles = [];
  int pending = 0; // style for the next typed character
  bool _manual = false;

  RtController([String html = '']) {
    final d = RtDoc.fromHtml(html);
    _manual = true;
    styles = [...d.styles];
    value = TextEditingValue(text: d.text);
    _manual = false;
  }

  /// The formatted content as the website's HTML.
  String toHtml() {
    _fit(text.length);
    return RtDoc(text, styles).toHtml();
  }

  /// The text without formatting.
  String get plain => RtDoc(text, _fitted()).plain;

  List<int> _fitted() {
    _fit(text.length);
    return styles;
  }

  void _fit(int n) {
    if (styles.length > n) styles = styles.sublist(0, n);
    while (styles.length < n) {
      styles.add(0);
    }
  }

  @override
  set value(TextEditingValue v) {
    if (!_manual) {
      _fit(text.length);
      final old = text, now = v.text;
      if (old != now) {
        final minLen = math.min(old.length, now.length);
        var p = 0;
        while (p < minLen && old.codeUnitAt(p) == now.codeUnitAt(p)) {
          p++;
        }
        var s = 0;
        while (s < minLen - p && old.codeUnitAt(old.length - 1 - s) == now.codeUnitAt(now.length - 1 - s)) {
          s++;
        }
        styles.removeRange(p, old.length - s);
        styles.insertAll(p, List<int>.filled(now.length - s - p, pending));
      } else if (v.selection.isValid && v.selection.isCollapsed && v.selection != selection) {
        final at = v.selection.baseOffset;
        pending = at > 0 && at <= styles.length ? styles[at - 1] : 0;
      }
    }
    super.value = v;
  }

  bool isOn(int bit) {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      _fit(text.length);
      final a = math.min(sel.start, sel.end), b = math.max(sel.start, sel.end);
      for (var i = a; i < b && i < styles.length; i++) {
        if (text[i] != '\n' && styles[i] & bit == 0) return false;
      }
      return true;
    }
    return pending & bit != 0;
  }

  /// Turns bold / italic / underline on or off for the selection (or for what you type next).
  void toggle(int bit) {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      final on = !isOn(bit);
      final a = math.min(sel.start, sel.end), b = math.max(sel.start, sel.end);
      for (var i = a; i < b && i < styles.length; i++) {
        if (text[i] == '\n') continue;
        styles[i] = on ? (styles[i] | bit) : (styles[i] & ~bit);
      }
    } else {
      pending = isOn(bit) ? (pending & ~bit) : (pending | bit);
    }
    notifyListeners();
  }

  /// The start and end of the lines touched by the selection.
  (int, int) _lineRange() {
    final sel = selection;
    final at = sel.isValid ? math.min(sel.start, sel.end) : text.length;
    final to = sel.isValid ? math.max(sel.start, sel.end) : text.length;
    var a = text.lastIndexOf('\n', at > 0 ? at - 1 : 0);
    a = (at == 0 || a < 0) ? 0 : a + 1;
    var b = text.indexOf('\n', to);
    if (b < 0) b = text.length;
    return (a, b);
  }

  /// Larger text for the whole line(s) of the selection.
  void toggleLarge() {
    _fit(text.length);
    final (a, b) = _lineRange();
    var all = b > a;
    for (var i = a; i < b; i++) {
      if (text[i] != '\n' && styles[i] & rtLarge == 0) all = false;
    }
    for (var i = a; i < b; i++) {
      if (text[i] == '\n') continue;
      styles[i] = all ? (styles[i] & ~rtLarge) : (styles[i] | rtLarge);
    }
    pending = all ? (pending & ~rtLarge) : (pending | rtLarge);
    notifyListeners();
  }

  bool get largeOn {
    final (a, b) = _lineRange();
    _fit(text.length);
    if (b <= a) return pending & rtLarge != 0;
    for (var i = a; i < b; i++) {
      if (text[i] != '\n' && styles[i] & rtLarge == 0) return false;
    }
    return true;
  }

  /// Bullets for the line(s) of the selection.
  void toggleBullets() {
    _fit(text.length);
    final (a, b) = _lineRange();
    final lines = text.substring(a, b).split('\n');
    final allBullets = lines.every((l) => l.startsWith('• '));
    final outText = StringBuffer(text.substring(0, a));
    final outStyles = <int>[...styles.sublist(0, a)];
    var pos = a;
    var delta = 0;
    for (var k = 0; k < lines.length; k++) {
      final l = lines[k];
      if (k > 0) {
        outText.write('\n');
        outStyles.add(0);
      }
      if (allBullets) {
        outText.write(l.substring(2));
        outStyles.addAll(styles.sublist(pos + 2, pos + l.length));
        delta -= 2;
      } else if (l.startsWith('• ')) {
        outText.write(l);
        outStyles.addAll(styles.sublist(pos, pos + l.length));
      } else {
        outText.write('• $l');
        outStyles
          ..add(0)
          ..add(0)
          ..addAll(styles.sublist(pos, pos + l.length));
        delta += 2;
      }
      pos += l.length + 1;
    }
    outText.write(text.substring(b));
    outStyles.addAll(styles.sublist(math.min(b, styles.length)));
    final end = math.max(0, b + delta);
    _manual = true;
    styles = outStyles;
    value = TextEditingValue(text: outText.toString(), selection: TextSelection.collapsed(offset: end));
    _manual = false;
  }

  /// Is the line with the cursor a bullet line?
  bool get bulletsOn {
    final (a, b) = _lineRange();
    if (b <= a) return false;
    return text.substring(a, b).split('\n').every((l) => l.startsWith('• '));
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    _fit(text.length);
    final d = RtDoc(text, styles);
    return TextSpan(style: base, children: d.spans(base));
  }
}

/// A formatted-text input with a small toolbar.
class RichField extends StatelessWidget {
  final RtController controller;
  final String? label, hint;
  final int minLines, maxLines;
  const RichField(this.controller, {super.key, this.label, this.hint, this.minLines = 1, this.maxLines = 6});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Wrap(
            spacing: 4,
            children: [
              _btn(context, 'Bold', Icons.format_bold_rounded, controller.isOn(rtBold), () => controller.toggle(rtBold)),
              _btn(context, 'Italic', Icons.format_italic_rounded, controller.isOn(rtItalic), () => controller.toggle(rtItalic)),
              _btn(context, 'Underline', Icons.format_underlined_rounded, controller.isOn(rtUnder), () => controller.toggle(rtUnder)),
              _btn(context, 'Bullet list', Icons.format_list_bulleted_rounded, controller.bulletsOn, controller.toggleBullets),
              _btn(context, 'Large text', Icons.format_size_rounded, controller.largeOn, controller.toggleLarge),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(14)),
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(BuildContext context, String tip, IconData icon, bool on, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: on ? lav.withAlpha(110) : null,
              border: Border.all(color: on ? lavDeep : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 19, color: on ? lavDeep : null),
          ),
        ),
      );
}
