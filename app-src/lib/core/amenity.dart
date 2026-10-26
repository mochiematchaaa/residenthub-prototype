/// A facility residents can book (swimming pool, function hall, gym, ...).
/// The administrator adds, edits and removes these. The bookable time slots are made from the
/// opening and closing time and the length of one booking. This is the same rule the website uses.
class Amenity {
  final String id;
  String name, open, close, note;

  /// Length of one booking, in minutes.
  int mins;
  Amenity(this.id, this.name, this.open, this.close, this.mins, [this.note = '']);

  Amenity copy() => Amenity(id, name, open, close, mins, note);

  /// "6 AM – 8 PM"
  String get hours {
    final o = toMinutes(open), c = toMinutes(close);
    if (o == null || c == null) return '';
    final x = _clock(o), y = _clock(c);
    return '${x.$1} ${x.$2} – ${y.$1} ${y.$2}';
  }

  /// The bookable times, e.g. ["6–8 AM", "8–10 AM", ...]
  List<String> get slots {
    final o = toMinutes(open), c = toMinutes(close);
    final n = mins;
    if (o == null || c == null || c <= o || n < 15) return const [];
    final out = <String>[];
    for (var s = o; s + n <= c; s += n) {
      final x = _clock(s), y = _clock(s + n);
      out.add(x.$2 == y.$2 ? '${x.$1}–${y.$1} ${y.$2}' : '${x.$1} ${x.$2}–${y.$1} ${y.$2}');
    }
    return out;
  }

  /// What residents can book until the administrator changes the list.
  static List<Amenity> defaults() => [
        Amenity('pool', 'Swimming Pool', '06:00', '20:00', 120,
            'Free for residents. Guests pay ₱150 per visit, collected at the gate.'),
        Amenity('hall', 'Function Hall', '08:00', '22:00', 120),
      ];
}

/// "08:30" to minutes after midnight, or null when it is not a time.
int? toMinutes(String t) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}

/// Minutes after midnight to "HH:MM".
String hhmm(int min) {
  final h = (min ~/ 60) % 24, m = min % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// "8", "8:30" and "AM" or "PM".
(String, String) _clock(int min) {
  final h = (min ~/ 60) % 24, m = min % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return ('$h12${m != 0 ? ':${m < 10 ? '0' : ''}$m' : ''}', h >= 12 ? 'PM' : 'AM');
}

/// A time of day as the person reads it: "8:30 AM".
String timeLabel(String t) {
  final m = toMinutes(t);
  if (m == null) return t;
  final c = _clock(m);
  return '${c.$1} ${c.$2}';
}
