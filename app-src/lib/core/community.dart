/// Community features that match the website dashboards:
/// polls, motor parking slots and the resident directory.
/// Pure data. It does not import the app state, so app_state.dart can use it.

/// One choice in a poll.
class PollOption {
  final String text;
  int votes;
  PollOption(this.text, this.votes);
}

/// A poll residents vote on (one vote per unit).
class Poll {
  final int id;
  String question;
  bool open;
  String closes;
  final List<PollOption> options;
  Poll(this.id, this.question, this.open, this.closes, this.options);

  int get total => options.fold<int>(0, (s, o) => s + o.votes);
}

/// One motor parking slot. [unit] is empty when the slot is free.
class ParkingSlot {
  final String id;
  String unit;

  /// How the slot is rented: 'month' (one month) or 'day' (by the day). [from] and [until] are
  /// yyyy-mm-dd, [amount] is what was charged. Slots given before plans existed have no dates.
  String plan, from, until;
  num amount;
  ParkingSlot(this.id, [this.unit = '', this.plan = 'month', this.from = '', this.until = '', this.amount = 0]);
  bool get used => unit.isNotEmpty;
  bool get daily => plan == 'day';

  /// True once the last day of the rental has passed.
  bool get ended => used && until.isNotEmpty && until.compareTo(isoDay(DateTime.now())) < 0;

  /// "Monthly · until Nov 13, 2026"
  String get rentalLine => !used ? '' : '${daily ? 'Daily' : 'Monthly'}${until.isEmpty ? '' : ' · until ${isoShort(until)}'}';
}

String isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2026-11-13" as "Nov 13, 2026" (unchanged when it is not a date).
String isoShort(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

/// The last day of a rental that starts on [from]: one month later (minus a day), or [days] days.
String parkUntil(String plan, int days, DateTime from) {
  if (plan == 'day') return isoDay(DateTime(from.year, from.month, from.day + (days < 1 ? 1 : days) - 1));
  final lastOfNext = DateTime(from.year, from.month + 2, 0).day;
  final next = DateTime(from.year, from.month + 1, from.day > lastOfNext ? lastOfNext : from.day);
  return isoDay(DateTime(next.year, next.month, next.day - 1));
}

String parkPlanText(String plan, int days) =>
    plan == 'day' ? 'Daily${days > 0 ? ' · $days day${days == 1 ? '' : 's'}' : ''}' : 'Monthly';

/// Slot names for a motor parking area with [n] slots: M-01, M-02, ...
List<String> slotNames(int n) => [for (var i = 1; i <= n; i++) 'M-${i.toString().padLeft(2, '0')}'];

// ---------------------------------------------------------------- directory

/// An emergency contact shown in the directory.
class ContactInfo {
  final String name, note, tel;
  const ContactInfo(this.name, this.note, this.tel);
}

/// Filled in by the administrator (More > Directory and house rules) and shared with every resident.
final List<ContactInfo> directoryContacts = [];

/// Each rule is [title, text]. Filled in by the administrator.
final List<List<String>> houseRules = [];

const directoryFaq = [
  [
    'How do I book the pool or the Function Hall?',
    'Open Book, pick the place, tap an open time slot and send your request. The office approves it and you will see the result under My reservations.'
  ],
  ['When are monthly dues due?', 'Dues are due on the 15th of every month. Your balance and history are under Dues.'],
  [
    'I rent out my unit. What do I need to do?',
    'Open Unit status and tell us how your unit is used. Long-term leases are saved right away. Short-term rentals and home businesses need the administrator\'s approval.'
  ],
  [
    'How do I request motor parking?',
    'Open Parking, tap a free slot on the map and pay the monthly rental. When the office confirms your payment, the slot is yours.'
  ],
  [
    'How do I report a problem in the building?',
    'Use Grievances to describe the concern. You can follow its status from Open to In progress to Resolved.'
  ],
];
