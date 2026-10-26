// Formatted text for polls. Reads and writes the same simple HTML the website uses
// (bold, italic, underline, bullet lists and a larger heading line), so both show the same text.

import 'package:flutter/material.dart';

const int rtBold = 1, rtItalic = 2, rtUnder = 4, rtLarge = 8;

/// Text with a style (bits above) for every character. Bullet lines start with "• ".
class RtDoc {
  final String text;
  final List<int> styles;
  const RtDoc(this.text, this.styles);

  static const empty = RtDoc('', <int>[]);

  /// The text without formatting, on one line.
  String get plain => text.replaceAll('• ', '').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

  bool get isEmpty => plain.isEmpty;

  /// Reads the simple HTML of the website.
  static RtDoc fromHtml(String html) {
    if (html.trim().isEmpty) return empty;
    final sb = StringBuffer();
    final st = <int>[];
    var bold = 0, italic = 0, under = 0, large = 0;
    String? list; // 'ul' | 'ol' while inside a list
    var olNo = 0;
    var atLineStart = true;

    int cur() => (bold > 0 ? rtBold : 0) | (italic > 0 ? rtItalic : 0) | (under > 0 ? rtUnder : 0) | (large > 0 ? rtLarge : 0);
    void put(String s, int style) {
      for (final u in s.codeUnits) {
        sb.writeCharCode(u);
        st.add(style);
      }
      if (s.isNotEmpty) atLineStart = s.endsWith('\n');
    }

    void newline() {
      if (!atLineStart) put('\n', 0);
    }

    final re = RegExp(r'<(/?)([a-zA-Z0-9]+)[^>]*>|([^<]+)');
    for (final m in re.allMatches(html)) {
      final txt = m.group(3);
      if (txt != null) {
        final t = _decode(txt).replaceAll(RegExp(r'[\r\n]+'), ' ');
        if (t.isEmpty || (t.trim().isEmpty && atLineStart)) continue;
        put(t, cur());
        continue;
      }
      final close = m.group(1) == '/';
      final tag = m.group(2)!.toLowerCase();
      switch (tag) {
        case 'b':
        case 'strong':
          bold += close ? -1 : 1;
        case 'i':
        case 'em':
          italic += close ? -1 : 1;
        case 'u':
          under += close ? -1 : 1;
        case 'h3':
          newline();
          large += close ? -1 : 1;
          if (close) newline();
        case 'br':
          put('\n', 0);
        case 'p':
        case 'div':
          newline();
        case 'ul':
        case 'ol':
          newline();
          list = close ? null : tag;
          olNo = 0;
        case 'li':
          if (close) {
            newline();
          } else {
            newline();
            olNo++;
            put(list == 'ol' ? '$olNo. ' : '• ', 0);
          }
      }
    }
    var text = sb.toString();
    var styles = st;
    // drop trailing line breaks
    while (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
      styles = styles.sublist(0, styles.length - 1);
    }
    return RtDoc(text, styles);
  }

  /// The simple HTML the website understands.
  String toHtml() {
    if (isEmpty) return '';
    final lines = text.split('\n');
    final chunks = <(String, bool)>[]; // (html, isBlock)
    var pos = 0;
    var ul = <String>[];
    void flush() {
      if (ul.isNotEmpty) {
        chunks.add(('<ul>${ul.map((e) => '<li>$e</li>').join()}</ul>', true));
        ul = <String>[];
      }
    }

    for (final line in lines) {
      final from = pos;
      pos += line.length + 1;
      final bullet = line.startsWith('• ');
      final skip = bullet ? 2 : 0;
      final body = _runsHtml(line.substring(skip), styles.sublist(from + skip, from + line.length));
      if (bullet) {
        ul.add(body);
        continue;
      }
      flush();
      final allLarge = line.isNotEmpty && styles.sublist(from, from + line.length).every((s) => s & rtLarge != 0);
      if (allLarge) {
        chunks.add(('<h3>$body</h3>', true));
      } else {
        chunks.add((body, false));
      }
    }
    flush();
    final out = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      if (i > 0 && !chunks[i].$2 && !chunks[i - 1].$2) out.write('<br>');
      out.write(chunks[i].$1);
    }
    return out.toString();
  }

  static String _runsHtml(String t, List<int> st) {
    final sb = StringBuffer();
    var i = 0;
    while (i < t.length) {
      var j = i + 1;
      final s = st[i] & 7;
      while (j < t.length && (st[j] & 7) == s) {
        j++;
      }
      var piece = _escape(t.substring(i, j));
      if (s & rtUnder != 0) piece = '<u>$piece</u>';
      if (s & rtItalic != 0) piece = '<i>$piece</i>';
      if (s & rtBold != 0) piece = '<b>$piece</b>';
      sb.write(piece);
      i = j;
    }
    return sb.toString();
  }

  /// Spans to show this text.
  List<InlineSpan> spans(TextStyle base) {
    final kids = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      var j = i + 1;
      while (j < text.length && styles[j] == styles[i]) {
        j++;
      }
      kids.add(TextSpan(text: text.substring(i, j), style: rtStyle(base, styles[i])));
      i = j;
    }
    return kids;
  }
}

/// The text style for a set of style bits.
TextStyle rtStyle(TextStyle base, int s) {
  var t = base;
  if (s & rtBold != 0) t = t.copyWith(fontWeight: FontWeight.w800);
  if (s & rtItalic != 0) t = t.copyWith(fontStyle: FontStyle.italic);
  if (s & rtUnder != 0) t = t.copyWith(decoration: TextDecoration.underline);
  if (s & rtLarge != 0) t = t.copyWith(fontSize: (base.fontSize ?? 14) * 1.25, fontWeight: FontWeight.w800);
  return t;
}

String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _decode(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

/// Shows formatted text (from the website's HTML, or plain [fallback] text when there is none).
class RichView extends StatelessWidget {
  final String html, fallback;
  final TextStyle style;
  const RichView(this.html, {super.key, this.fallback = '', this.style = const TextStyle(fontSize: 14, height: 1.4)});

  @override
  Widget build(BuildContext context) {
    final d = RtDoc.fromHtml(html);
    if (d.isEmpty) return fallback.isEmpty ? const SizedBox.shrink() : Text(fallback, style: style);
    return Text.rich(TextSpan(style: style, children: d.spans(style)));
  }
}
