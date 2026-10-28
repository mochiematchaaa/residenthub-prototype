// Reminders and the notification list (the bell): the office's reminder settings, the wording, and which
// notifications a person has already read. Pure data, it does not import the app state.

import 'package:flutter/widgets.dart';

/// The settings of one kind of reminder.
class RemCfg {
  bool on;

  /// Start reminding this many days before the due date.
  int days;

  /// How often the pop-up shows on the resident's home: every | daily | bell (never pop up).
  String freq;

  /// The office's own wording. Empty = the standard message.
  String msg;
  RemCfg({this.on = true, this.days = 5, this.freq = 'every', this.msg = ''});
  RemCfg copy() => RemCfg(on: on, days: days, freq: freq, msg: msg);
}

/// A reminder the office wrote itself (Settings > Reminders > Add reminder).
class CustomRem {
  final String id;
  String title, text, from, to, freq, aud, units;
  bool on;

  /// Changes each time the office edits it, so an edited reminder pops up again.
  int edited;
  CustomRem({required this.id, required this.title, required this.text, this.from = '', this.to = '', this.freq = 'once', this.aud = 'all', this.units = '', this.on = true, this.edited = 0});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'text': text, 'from': from, 'to': to, 'freq': freq, 'aud': aud, 'units': units, 'on': on ? 'yes' : 'no', 'edited': edited};

  static CustomRem? fromJson(Object? j) {
    if (j is! Map) return null;
    String s(String k) => j[k] == null ? '' : '${j[k]}';
    final id = s('id');
    if (id.isEmpty) return null;
    final f = s('freq');
    return CustomRem(
      id: id,
      title: s('title'),
      text: s('text'),
      from: s('from'),
      to: s('to'),
      freq: customFreqLabels.containsKey(f) ? f : 'once',
      aud: s('aud') == 'units' ? 'units' : 'all',
      units: s('units'),
      on: s('on') != 'no',
      edited: int.tryParse(s('edited')) ?? 0,
    );
  }
}

const customFreqLabels = {
  'once': 'One time only',
  'daily': 'Once a day',
  'every': 'Every time they open the dashboard',
  'bell': 'Do not pop up (bell only)',
};

/// "Unit 12C", "12c" and "12 C" all become "12c", so the office can type units loosely.
String unitKey(String u) => u.toLowerCase().replaceAll(RegExp(r'^unit\s*'), '').replaceAll(RegExp(r'\s+'), '');

const remKinds = ['parking', 'dues'];
const remNames = {'parking': 'Parking rental due', 'dues': 'Charges due'};
const remFreqLabels = {
  'every': 'Every time they open the dashboard',
  'daily': 'Once a day',
  'bell': 'Do not pop up (bell only)',
};
const remDefaultText = {
  'parking':
      'Your parking rental for {slot} is almost up. The next payment is due {date} ({days}). Renew to keep your slot, or tell the office if you no longer plan to rent.',
  'dues': '{item} ({amount}) is {when}. Please settle it as soon as you can to avoid a late charge.',
};
const remTokens = {'parking': '{slot} {date} {days}', 'dues': '{item} {amount} {when} {date}'};

/// Fills {slot} {date} ... in a message.
String remFill(String template, Map<String, String> vars) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);

/// "due today", "due tomorrow", "due in 3 days", "overdue by 2 days".
String remWhen(int n) => n < 0
    ? 'overdue by ${-n} day${n == -1 ? '' : 's'}'
    : n == 0
        ? 'due today'
        : n == 1
            ? 'due tomorrow'
            : 'due in $n days';

/// One reminder for the signed-in resident (shown in the pop-up on the home screen).
class Reminder {
  final String key, kind, title, text, btn;
  final bool late;

  /// Days until the due date (negative = overdue).
  final int n;

  /// The charge to pay (dues reminders).
  final String? dueId;

  /// "How often" for a reminder the office wrote itself (null = the setting of its kind).
  final String? freq;
  const Reminder(this.key, this.kind, this.title, this.text, this.btn, this.late, this.n, [this.dueId, this.freq]);
}

/// What a screen hands over to build the notification list.
typedef NotifSeed = ({String text, String tone, String? dueId, IconData? icon, int? tab});

/// One line of the notification list.
class NotifItem {
  final String key, text, tone;
  final String? dueId;
  final IconData? icon;
  final int? tab;

  /// When it was first seen (ms since 1970).
  final int at;
  final bool unread;
  const NotifItem(this.key, this.text, this.tone, this.dueId, this.icon, this.tab, this.at, this.unread);
}

/// "Just now", "5m", "3h", "2d", "1w".
String agoText(int ms) {
  final s = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
  if (s < 60) return 'Just now';
  if (s < 3600) return '${s ~/ 60}m';
  if (s < 86400) return '${s ~/ 3600}h';
  if (s < 604800) return '${s ~/ 86400}d';
  return '${s ~/ 604800}w';
}

/// Remembers, for each notification, when it was first seen and whether it was read, and which
/// reminder pop-ups were already shown today.
class NotifBook {
  final Map<String, int> seen = {}, read = {}, opened = {};
  final Map<String, String> shown = {}, snoozed = {};

  void clear() {
    seen.clear();
    read.clear();
    opened.clear();
    shown.clear();
    snoozed.clear();
  }

  /// The list for one person (scope), newest first. Reading is by key, so a notification
  /// whose words change (a new count, a new date) counts as new again.
  List<NotifItem> list(String scope, List<NotifSeed> seeds) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <NotifItem>[];
    final order = <String, int>{};
    for (final s in seeds) {
      final key = '$scope|${s.text}';
      if (order.containsKey(key)) continue;
      order[key] = order.length;
      out.add(NotifItem(key, s.text, s.tone, s.dueId, s.icon, s.tab, seen.putIfAbsent(key, () => now), !read.containsKey(key)));
    }
    out.sort((a, b) {
      final c = b.at.compareTo(a.at);
      return c != 0 ? c : order[a.key]!.compareTo(order[b.key]!);
    });
    return out;
  }

  /// The number on the bell: unread ones that arrived since the bell was last opened.
  int badge(String scope, List<NotifItem> items) {
    final o = opened[scope] ?? 0;
    return items.where((n) => n.unread && n.at > o).length;
  }
}
