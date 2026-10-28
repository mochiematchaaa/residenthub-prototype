/// Community features that match the website dashboards:
/// polls, motor parking slots and the resident directory.
/// Pure data. It does not import the app state, so app_state.dart can use it.

/// One choice in a poll (used for the results of the first question).
class PollOption {
  final String text;
  int votes;
  PollOption(this.text, this.votes);
}

/// The kinds of question a poll can have, as saved in the shared data (same as the website).
const pollTypes = <List<String>>[
  ['choice', 'Multiple choice'],
  ['multi', 'Checkboxes'],
  ['text', 'Short answer'],
  ['para', 'Paragraph'],
  ['rating', 'Rating (1 to 5)'],
];

String pollTypeLabel(String t) => pollTypes.firstWhere((e) => e[0] == t, orElse: () => pollTypes.first)[1];

/// The built-in poll categories. The administrator can add, rename and remove categories (General stays).
const pollBuiltInCategories = [
  'General',
  'Facilities & amenities',
  'Maintenance & repairs',
  'Finance & budget',
  'Safety & security',
  'Events & community',
  'Rules & policies',
  'Governance & elections',
];

/// A written answer to a "short answer" or "paragraph" question.
class PollAnswer {
  final String unit, text;
  const PollAnswer(this.unit, this.text);
}

/// One question of a poll (or one position of an election).
class PollQuestion {
  String id, type, html, text;
  bool required;

  /// Checkboxes: the most choices allowed (0 = no limit). Election: the number of seats.
  int max;
  List<String> options;

  // Results, counted from the ballots (see AppState.recountPolls).
  List<int> counts = [];
  int n = 0; // answers received
  int ratingSum = 0;
  List<int> stars = [0, 0, 0, 0, 0];
  List<PollAnswer> written = [];

  PollQuestion(this.id, this.type, this.html, this.text, this.required, this.max, this.options);

  bool get isChoice => type == 'choice' || type == 'multi';
  bool get isWritten => type == 'text' || type == 'para';
}

/// One unit's ballot (a unit votes once, and cannot change it).
class PollBallot {
  final int poll;
  final String unit, at;

  /// Question id -> option index (choice), list of option indexes (multi), 1..5 (rating) or text.
  final Map<String, dynamic> answers;
  PollBallot(this.poll, this.unit, this.at, this.answers);
}

/// A poll or an election residents vote on (one ballot per unit).
class Poll {
  final int id;
  String kind; // poll | election
  String category;
  String question; // the title as plain text
  String titleHtml, descHtml;
  String closes; // "Oct 30, 2026"
  String closeKey; // "2026-10-30"; after that day the poll closes by itself
  String showResults; // vote (right after voting) | closed (only when it closes)
  final List<PollQuestion> questions;
  bool _open;

  /// Number of ballots cast.
  int ballots = 0;

  /// True for older single-question polls (a plain question and options).
  final bool legacy;
  Poll(this.id, this.question, bool open, this.closes, this.questions,
      {this.kind = 'poll',
      this.category = 'General',
      this.titleHtml = '',
      this.descHtml = '',
      this.closeKey = '',
      this.showResults = 'vote',
      this.legacy = false})
      : _open = open;

  bool get isElection => kind == 'election';

  /// Open, unless the closing day has passed.
  bool get open => _open && !(closeKey.isNotEmpty && closeKey.compareTo(isoDay(DateTime.now())) < 0);
  set open(bool v) => _open = v;

  /// The saved open/closed switch (before the closing day is looked at).
  bool get openFlag => _open;

  /// Votes for the options of the first question.
  List<PollOption> get options {
    if (questions.isEmpty) return const [];
    final q = questions.first;
    return [for (var i = 0; i < q.options.length; i++) PollOption(q.options[i], i < q.counts.length ? q.counts[i] : 0)];
  }

  /// Answers to the first question.
  int get total => questions.isEmpty ? 0 : questions.first.n;

  /// An election keeps its results hidden until it closes.
  bool get resultsHidden => open && showResults == 'closed';
}

/// A slot size with its own rental rates: [sqm] is the floor area of the slot, [month] and [day] are the prices.
class ParkSize {
  final String name;
  final num sqm, month, day;
  const ParkSize(this.name, this.sqm, this.month, this.day);
}

/// Name, size in sqm and price factor used until the office sets the rates for each size.
const kParkSizeDefaults = [('Small', 2.0, 0.7), ('Regular', 3.0, 1.0), ('Large', 4.5, 1.5)];

/// A resident who will pay for parking at the office ("Walk-in"). [renew] = for a renewal. [day] is yyyy-mm-dd.
class Walkin {
  final String unit, name, slot, day;
  final num amount;
  final bool renew;
  final int at;
  const Walkin(this.unit, this.name, this.slot, this.amount, this.renew, this.day, this.at);
}

/// A text message the office "sent" to a resident (saved here; a real SMS service would deliver it).
class SmsMsg {
  final int id, at;
  final String unit, to, text, status;
  const SmsMsg(this.id, this.unit, this.to, this.text, this.at, this.status);
}

/// The residents are told this many days before the next payment of a monthly rental is due.
/// The office can change it (Settings > Reminders); a very low number means the reminder is off.
int parkSoonDays = 5;

/// When the next monthly payment of a rental is due: [nextDue] is yyyy-mm-dd, [days] counts from today (negative = overdue).
class ParkDue {
  final String until, nextDue;
  final int days;
  const ParkDue(this.until, this.nextDue, this.days);
  bool get soon => days <= parkSoonDays;
  bool get late => days <= 0;
}

/// The next payment of a monthly rental, or null (free slot, daily rental, no end date).
ParkDue? parkDueOf(ParkingSlot s) {
  if (!s.used || s.daily || s.until.isEmpty) return null;
  final u = DateTime.tryParse(s.until);
  if (u == null) return null;
  final next = DateTime.utc(u.year, u.month, u.day + 1);
  final t = DateTime.now();
  return ParkDue(s.until, isoDay(next), next.difference(DateTime.utc(t.year, t.month, t.day)).inDays);
}

/// "in 3 days", "tomorrow", "today", "2 days ago".
String parkDaysText(int d) => d > 1 ? 'in $d days' : (d == 1 ? 'tomorrow' : (d == 0 ? 'today' : '${-d} day${d == -1 ? '' : 's'} ago'));

/// One motor parking slot. [unit] is empty when the slot is free.
class ParkingSlot {
  final String id;
  String unit;

  /// How the slot is rented: 'month' (one month) or 'day' (by the day). [from] and [until] are
  /// yyyy-mm-dd, [amount] is what was charged. Slots given before plans existed have no dates.
  String plan, from, until;
  num amount;

  /// Small, Regular or Large. The rental price depends on it (see ParkSize).
  String size = 'Regular';
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
    'Open Parking, tap a free slot on the map and pay the monthly rental. When the office verifies your payment, the slot is yours.'
  ],
  [
    'How do I report a problem in the building?',
    'Use Complaints to describe the concern. You can follow its status from Open to In progress to Resolved.'
  ],
];
