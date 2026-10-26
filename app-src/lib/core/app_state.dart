// THE BRAIN OF THE APP. AppState holds all data (units, dues, bookings, polls...) and every action that changes it.
// The global `app` is this object. Screens redraw with ListenableBuilder(listenable: app, ...) and change data by calling its methods. Saving to the database is done by cloud_sync.dart.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'amenity.dart';
import 'community.dart';
import 'doc_model.dart';
import 'doc_seed.dart';
import 'expenses.dart';
import 'payments.dart';
import 'usage_forms.dart';

part 'cloud_codec.dart';

/// Who is signed in: a resident or the administrator.
enum Role { resident, admin }

String peso(num n) {
  final s = n.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0]
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '₱$whole.${parts[1]}';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];
String longDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String shortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

String usageLabel(String u) =>
    const {
      'owner': 'Owner-occupied',
      'tenant': 'Rented out (long-term)',
      'shortterm': 'Short-term rental',
      'business': 'Home business',
      'vacant': 'Vacant',
      'away': 'Owner away',
      'renovation': 'Under renovation',
    }[u] ??
    '—';

// ---------------------------------------------------------------- models

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One condominium unit with its household, contact, status and how it is used.
class Unit {
  String unit, name, type, status, contact;
  String usage; // current unit state: owner | tenant | shortterm | business | vacant | away | renovation
  String statusNote, statusDate;

  /// For short-term rentals and home businesses: '' | pending | approved | rejected.
  String usageStatus;

  /// The administrator's note shown to the resident when a declaration is rejected.
  String usageRemark;

  /// The details the resident gave for this way of using the unit (see usage_forms.dart).
  Map<String, String> usageInfo;
  Unit(this.unit, this.name, this.type, this.status, this.contact, this.usage,
      {this.statusNote = '', this.statusDate = '', this.usageStatus = '', this.usageRemark = '', Map<String, String>? usageInfo})
      : usageInfo = usageInfo ?? {};

  /// Short-term rentals and home businesses need the administrator's approval.
  bool get needsApproval => usage == 'shortterm' || usage == 'business';
}

/// One entry in a unit's status history (also drives the admin's update feed).
class StatusUpdate {
  final int id;
  final String unit, key, note, date, by; // by: 'Resident' | 'Admin'
  const StatusUpdate(this.id, this.unit, this.key, this.note, this.date, this.by);
}

/// One line in the administrator's "Recent activity" list.
class ActivityEntry {
  final String title, area;
  final DateTime at;
  const ActivityEntry(this.title, this.area, this.at);
}

/// A facility booking (place, day, time, status Pending/Approved/Denied).
class Booking {
  final int id;
  final String who, unit, place, when;
  String status; // Pending | Approved | Denied | Completed

  /// The day it is for (yyyy-mm-dd) and the time slot number, so two units cannot book the same slot.
  final String day;
  final int slot;
  Booking(this.id, this.who, this.unit, this.place, this.when, this.status,
      {this.day = '', this.slot = -1});
}

/// One charge billed to a unit: monthly association dues, a damage fee, and so on.
class Due {
  final int id;
  final String unit, name, note;
  final num amount;

  /// Due date written like "Oct 15, 2026" (empty = due upon receipt).
  final String dueDate;
  bool paid;
  Due(this.id, this.unit, this.name, this.amount, this.note, {this.dueDate = '', this.paid = false});
  num get amt => amount;
  bool get isCharge => true;
  String get label => note;

  /// Unpaid and past its due date.
  bool get overdue {
    if (paid || dueDate.isEmpty) return false;
    final d = parseShortDate(dueDate);
    return d != null && DateTime.now().isAfter(d.add(const Duration(days: 1)));
  }
}

/// One month in the dues list: month, amount, due date and status.
class MonthDue {
  final String month, due, status;
  final num amt;
  MonthDue(this.month, this.amt, this.due, this.status);
}

/// A complaint or request sent by a resident. stage 0 = new, 1 = in progress, 2 = resolved.
class Grievance {
  final int id;
  final String title, body, by; // by = unit label
  int stage; // 0 open, 1 in progress, 2 resolved
  Grievance(this.id, this.title, this.body, this.by, this.stage);
  String get statusLabel => const ['Open', 'In progress', 'Resolved'][stage];
}

/// A notice from the admin to all residents.
class Announcement {
  final int id;
  String title, body, date, status, type;
  bool sms;
  Announcement(this.id, this.title, this.body, this.date, this.status,
      this.type, this.sms);
}

/// A community event residents can join (RSVP).
class EventItem {
  final int id;
  final String title, date, place, about;
  EventItem(this.id, this.title, this.date, this.place, {this.about = ''});
}

/// One sign-in account (a row of the profiles table), shown in Manage access.
class Account {
  final String id;
  String name, email, phone, unit, role, added;
  bool suspended;

  /// Email and mobile number were confirmed with codes.
  bool verified;
  Account(this.id, this.name, this.email, this.phone, this.unit, this.role, this.added,
      {this.suspended = false, this.verified = false});
}

/// The signed-in person's profile.
class ResidentUser {
  String name, unit, email, phone;
  Uint8List? photo;
  ResidentUser(this.name, this.unit, this.email, this.phone);
  String get unitLabel => unit.split(' · ').first;
}

/// A device/session shown in the settings.
class SessionInfo {
  final int id;
  final String device, location, when;
  final bool current;
  SessionInfo(this.id, this.device, this.location, this.when, this.current);
}

/// A resident's request for a parking slot.
class ParkingReq {
  final String unit, name;
  bool confirmed;

  /// The slot the resident picked on the map ('' for an older request without one), and the
  /// monthly rental that was charged when they picked it.
  final String slot;
  final num amount;

  /// 'month' or 'day', and the number of days for a daily rental (0 for monthly).
  final String plan;
  final int days;

  /// Shown to the administrator ("Just now", "2 days ago") and used to keep requests in order.
  final String when;
  final int at;
  ParkingReq(this.unit, this.name,
      {this.confirmed = false, this.when = 'Just now', int? at, this.slot = '', this.amount = 0, this.plan = 'month', this.days = 0})
      : at = at ?? DateTime.now().millisecondsSinceEpoch;
}

// ---------------------------------------------------------------- state

final AppState app = AppState();

/// All app data and actions (see the note at the top of this file).
class AppState extends ChangeNotifier {
  Role? role;
  bool dark = false;
  ResidentUser? me;
  int resTab = 0;
  int adminTab = 0;

  /// Id of the signed-in account (the Supabase user id).
  String userId = '';

  /// True while the app checks whether a sign-in from last time is still valid.
  bool booting = true;

  /// True after the administrator created or reset this account: a new password must be chosen.
  bool mustChangePassword = false;

  /// False for a resident who has not yet confirmed the email and mobile number with codes.
  bool contactVerified = true;

  /// True once the first copy of the shared data has arrived after signing in.
  bool loaded = false;

  int _lastId = 0;

  /// An id that is unique across devices (milliseconds), so the app and the website never clash.
  int nextId() {
    var t = DateTime.now().millisecondsSinceEpoch;
    if (t <= _lastId) t = _lastId + 1;
    _lastId = t;
    return t;
  }

  /// A new unique id for a record.
  int cloudId() => nextId();

  /// Tells every screen that the data changed so they redraw.
  void _n() => notifyListeners();

  /// Called by the sync after it has changed the data.
  void changed() => _n();

  /// Switches dark mode.
  void toggleDark() {
    dark = !dark;
    _n();
  }

  /// Changes the tab of the resident dashboard.
  void setResTab(int i) {
    resTab = i;
    _n();
  }

  /// Changes the tab of the admin dashboard.
  void setAdminTab(int i) {
    adminTab = i;
    _n();
  }

  // ---- administrator profile (read from the account) ----
  String adminName = '';
  String adminEmail = '';
  String adminPhone = '';
  Uint8List? adminPhoto;
  String get adminFirstName {
    final parts = adminName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Admin' : parts.first;
  }

  /// Saves the admin's profile photo.
  void setAdminPhoto(Uint8List? bytes) {
    adminPhoto = bytes;
    _n();
  }

  /// Saves the resident's profile photo.
  void setMyPhoto(Uint8List? bytes) {
    final u = me;
    if (u == null) return;
    u.photo = bytes;
    _n();
  }

  /// Accounts shown in Manage access (loaded from the database for the administrator).
  final List<Account> trusted = [];

  /// Replaces the list of accounts loaded from the database.
  void setAccounts(List<Account> list) {
    trusted
      ..clear()
      ..addAll(list);
    _n();
  }

  /// Mobile numbers of the resident accounts (used to text announcements).
  List<String> get residentPhones => [
        for (final a in trusted)
          if (a.role == 'Resident' && validMobile(normalizePhone(a.phone))) normalizePhone(a.phone),
      ];

  /// Turns a typed mobile number into the 09XXXXXXXXX form.
  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('63') && d.length == 12) d = '0${d.substring(2)}';
    return d;
  }

  /// True if the number is a valid Philippine mobile number.
  static bool validMobile(String normalized) => RegExp(r'^09\d{9}$').hasMatch(normalized);

  // ---------------------------------------------------------------- session

  /// Accounts live in Supabase Auth; the only session shown is this device.
  List<SessionInfo> sessions = [];

  static String _deviceLabel() {
    if (kIsWeb) return 'Web browser · ResidentHub';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android phone · ResidentHub app',
      TargetPlatform.iOS => 'iPhone · ResidentHub app',
      _ => 'Computer · ResidentHub',
    };
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// Called by services/session.dart once Supabase has signed the person in.
  void enterSession({
    required Role role,
    required String id,
    required String name,
    required String email,
    required String phone,
    required String unit,
    required bool mustChange,
    bool verified = true,
  }) {
    clearData();
    this.role = role;
    userId = id;
    mustChangePassword = mustChange;
    contactVerified = role == Role.admin || verified;
    if (role == Role.admin) {
      adminName = name.trim().isEmpty ? 'Administrator' : name.trim();
      adminEmail = email;
      adminPhone = phone;
      me = null;
    } else {
      me = ResidentUser(name.trim().isEmpty ? email : name.trim(), unit, email, phone);
    }
    sessions = [SessionInfo(1, _deviceLabel(), 'Signed in at ${_clock(DateTime.now())}', 'Active now', true)];
    resTab = 0;
    adminTab = 0;
    booting = false;
    _n();
  }

  /// Called when loading is done, so the loading screen goes away.
  void finishBoot() {
    booting = false;
    _n();
  }

  /// Called after the resident chose a new password.
  void passwordChanged() {
    mustChangePassword = false;
    _n();
  }

  /// Called after the email/mobile codes were confirmed.
  void contactVerifiedNow() {
    contactVerified = true;
    _n();
  }

  /// Saves the resident's name and phone.
  void setMyProfile(String name, String phone) {
    final u = me;
    if (u != null) {
      u.name = name;
      u.phone = phone;
    } else {
      adminName = name;
      adminPhone = phone;
    }
    _n();
  }

  /// Signs out on this device and empties everything that was loaded.
  void clearSession() {
    role = null;
    me = null;
    userId = '';
    mustChangePassword = false;
    contactVerified = true;
    resTab = 0;
    adminTab = 0;
    clearData();
    _n();
  }

  /// Empties all data (used when signing out).
  void clearData() {
    loaded = false;
    units.clear();
    statusUpdates.clear();
    newStatusUpdates = 0;
    blocked.clear();
    blockedDay = '';
    amenities
      ..clear()
      ..addAll(Amenity.defaults());
    bookings.clear();
    dues.clear();
    motorRate = 0;
    motorRateDay = 0;
    duesRate = 0;
    parking.clear();
    slots.clear();
    payments.clear();
    proofs.clear();
    expenses.clear();
    grievances.clear();
    docs.removeWhere((d) => !d.isLive);
    announcements.clear();
    events.clear();
    polls.clear();
    _votes.clear();
    _rsvps.clear();
    activityLog.clear();
    trusted.clear();
    directoryContacts.clear();
    houseRules.clear();
    annualBudget.clear();
    for (final m in payMethods) {
      m.enabled = m.name == officePay;
      m.details = _defaultDetails[m.name] ?? '';
    }
  }

  // ---------------------------------------------------------------- units

  final List<Unit> units = [];

  /// Newest first. Residents and the admin both post here.
  final List<StatusUpdate> statusUpdates = [];
  int newStatusUpdates = 0; // resident updates the admin has not opened yet

  /// Admin: adds a unit. The unit name is what ties accounts, charges and bookings together.
  String? addUnit(String unitRaw, String household, String type, String contact) {
    var label = unitRaw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (label.isEmpty) return 'Enter the unit name, e.g. Unit 12A.';
    if (!label.toLowerCase().startsWith('unit ')) label = 'Unit $label';
    label = 'Unit ${label.substring(5).trim().toUpperCase()}';
    if (units.any((u) => u.unit.toLowerCase() == label.toLowerCase())) return '$label already exists.';
    units.add(Unit(label, household.trim().isEmpty ? '—' : household.trim(), type,
        'Occupied', contact.trim().isEmpty ? '—' : contact.trim(), 'owner'));
    units.sort((a, b) => naturalCompare(a.unit, b.unit));
    logActivity('Unit added: $label', 'Units');
    _n();
    return null;
  }

  /// Admin: edits the household details of a unit.
  void updateUnit(Unit u, String household, String type, String contact) {
    u.name = household.trim().isEmpty ? '—' : household.trim();
    u.type = type;
    u.contact = contact.trim().isEmpty ? '—' : contact.trim();
    _n();
  }

  /// Admin: removes a unit that has no account. Returns an error message or null.
  String? removeUnit(Unit u) {
    if (trusted.any((a) => a.unit == u.unit && a.role == 'Resident')) {
      return 'An account is still assigned to ${u.unit}. Remove that account first.';
    }
    units.remove(u);
    dues.removeWhere((d) => d.unit == u.unit);
    logActivity('Unit removed: ${u.unit}', 'Units');
    _n();
    return null;
  }

  /// Number of unpaid dues of a unit.
  int unpaidCountFor(String unit) => dues.where((d) => d.unit == unit && !d.paid).length;
  /// Total unpaid amount of a unit.
  num balanceFor(String unit) =>
      dues.where((d) => d.unit == unit && !d.paid).fold<num>(0, (s, d) => s + d.amt);

  // ---------------------------------------------------------------- facilities

  /// The facilities residents can book. The administrator manages this list.
  final List<Amenity> amenities = Amenity.defaults();

  /// Slots the administrator closed, for the day in [blockedDay]. Keys look like "pool-3"
  /// (the amenity's id, then the slot number).
  final Map<String, bool> blocked = {};
  String blockedDay = '';

  String _slotKey(int f, int i) => '${f < amenities.length ? amenities[f].id : f}-$i';

  /// True if the admin blocked this time slot.
  bool slotClosed(int f, int i) =>
      blockedDay == dayKey(DateTime.now()) && (blocked[_slotKey(f, i)] ?? false);

  /// True if the time slot is blocked or already booked.
  bool slotBooked(int f, int i) {
    if (f >= amenities.length) return false;
    final today = dayKey(DateTime.now());
    if (slotClosed(f, i)) return true;
    final place = amenities[f].name;
    return bookings.any((b) =>
        b.day == today &&
        b.slot == i &&
        b.place == place &&
        (b.status == 'Pending' || b.status == 'Approved'));
  }

  /// DEMO ONLY: tells whether a facility is closed because its equipment is not working. Null in the real app.
  bool Function(String facility)? closedForMaintenance;

  /// One time of one amenity on one day (yyyy-mm-dd): past | closed | booked | pending | open.
  String slotState(int f, int i, String day) {
    if (f >= amenities.length) return 'closed';
    final now = DateTime.now();
    final today = dayKey(now);
    if (day.compareTo(today) < 0) return 'past';
    final a = amenities[f];
    final start = (toMinutes(a.open) ?? 0) + i * a.mins;
    if (day == today && start <= now.hour * 60 + now.minute) return 'past';
    if (day == blockedDay && (blocked[_slotKey(f, i)] ?? false)) return 'closed';
    if (closedForMaintenance?.call(a.name) ?? false) return 'closed';
    for (final b in bookings) {
      if (b.day == day && b.slot == i && b.place == a.name && (b.status == 'Pending' || b.status == 'Approved')) {
        return b.status == 'Approved' ? 'booked' : 'pending';
      }
    }
    return 'open';
  }

  /// How many times of an amenity are in each state on a day.
  Map<String, int> dayCounts(int f, String day) {
    final c = {'open': 0, 'booked': 0, 'pending': 0, 'closed': 0, 'past': 0, 'total': 0};
    if (f >= amenities.length) return c;
    final n = amenities[f].slots.length;
    for (var i = 0; i < n; i++) {
      final s = slotState(f, i, day);
      c[s] = (c[s] ?? 0) + 1;
      c['total'] = (c['total'] ?? 0) + 1;
    }
    return c;
  }

  /// Adds an amenity, or changes [edit]. Returns a message when something is wrong.
  String? saveAmenity(Amenity? edit, String name, String open, String close, int mins, String note) {
    name = name.trim();
    if (name.isEmpty) return "Enter the amenity's name.";
    final o = toMinutes(open), c = toMinutes(close);
    if (o == null || c == null) return 'Choose the opening and closing time.';
    if (c <= o) return 'The closing time must be after the opening time.';
    if (mins < 15 || mins > 480) return 'A booking must be between 15 and 480 minutes.';
    if (o + mins > c) return 'One booking is longer than the opening hours.';
    if (amenities.any((a) => a != edit && a.name.toLowerCase() == name.toLowerCase())) return '$name already exists.';
    if (edit == null) {
      amenities.add(Amenity('a${DateTime.now().millisecondsSinceEpoch}', name, open, close, mins, note.trim()));
      logActivity('Amenity added: $name', 'Facilities');
    } else {
      edit
        ..name = name
        ..open = open
        ..close = close
        ..mins = mins
        ..note = note.trim();
      logActivity('Amenity updated: $name', 'Facilities');
    }
    _n();
    return null;
  }

  /// Today's requests that are still waiting or approved for [a].
  int activeBookingsToday(Amenity a) {
    final today = dayKey(DateTime.now());
    return bookings
        .where((b) => b.place == a.name && b.day.compareTo(today) >= 0 && (b.status == 'Pending' || b.status == 'Approved'))
        .length;
  }

  /// Removes a facility (returns an error text if it can't).
  String? removeAmenity(Amenity a) {
    if (amenities.length <= 1) return 'Keep at least one amenity so residents can still book.';
    amenities.remove(a);
    logActivity('Amenity removed: ${a.name}', 'Facilities');
    _n();
    return null;
  }

  final List<Booking> bookings = [];

  // ---------------------------------------------------------------- finance

  final List<Due> dues = [];
  num motorRate = 0;

  /// Daily parking rate (per day). 0 means the daily option is not offered.
  num motorRateDay = 0;

  /// What one unit pays each month in association dues (set by the administrator).
  num duesRate = 0;
  final List<ParkingReq> parking = [];
  final List<ParkingSlot> slots = [];

  // The account details are filled in by the administrator in Finance > Payment options.
  static const officePay = 'Cash or check at the office';
  static const _defaultDetails = <String, String>{
    officePay: 'Pay at the administration office.',
    'Bank transfer': 'Account name: (add account name)\nBank: (add bank name)\nAccount no.: (add account number)',
    'GCash': 'Account name: (add name)\nNumber: (add GCash number)',
    'Maya': 'Account name: (add name)\nNumber: (add Maya number)',
  };
  final List<PayMethod> payMethods = [
    PayMethod(officePay, _defaultDetails[officePay]!),
    PayMethod('Bank transfer', _defaultDetails['Bank transfer']!, enabled: false),
    PayMethod('GCash', _defaultDetails['GCash']!, enabled: false),
    PayMethod('Maya', _defaultDetails['Maya']!, enabled: false),
  ];

  final List<PaymentRecord> payments = [];
  final List<PaymentProof> proofs = [];

  /// My unit's payments.
  List<PaymentRecord> get myPayments =>
      payments.where((p) => p.unit == myUnit).toList();
  /// The payment proofs my unit sent.
  List<PaymentProof> get myProofs =>
      proofs.where((p) => p.unit == myUnit && !p.direct).toList();
  /// How many payment proofs wait for the admin.
  int get pendingProofs => proofs.where((p) => p.status == 'Pending').length;
  /// The payment methods currently allowed.
  List<PayMethod> get enabledPayMethods =>
      payMethods.where((m) => m.enabled).toList();

  /// Total of the payments recorded in the given month.
  num collectedIn(int year, int month) => payments
      .where((p) => p.when.year == year && p.when.month == month)
      .fold<num>(0, (s, p) => s + p.amount);

  num get collectedThisMonth {
    final n = DateTime.now();
    return collectedIn(n.year, n.month);
  }

  /// Total of all payments received.
  num get totalCollected => payments.fold<num>(0, (s, p) => s + p.amount);

  /// The last [n] months (oldest first) ending with the current month.
  List<DateTime> trendMonths([int n = 6]) {
    final now = DateTime.now();
    return [for (var i = n - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
  }

  /// Amounts collected per month for the chart.
  List<double> collectionTrend([int n = 6]) =>
      [for (final m in trendMonths(n)) collectedIn(m.year, m.month).toDouble()];

  /// Month names for the chart.
  List<String> collectionTrendLabels([int n = 6]) =>
      [for (final m in trendMonths(n)) _months[m.month - 1].substring(0, 3)];

  /// The next receipt number of this year, counted from every receipt on record.
  String nextReceiptNo() {
    final year = DateTime.now().year;
    final re = RegExp(r'^OR-(\d{4})-(\d+)$');
    var max = 0;
    for (final s in [...payments.map((p) => p.receiptNo), ...proofs.map((p) => p.receiptNo)]) {
      final m = re.firstMatch(s);
      if (m != null && int.parse(m[1]!) == year) {
        final n = int.parse(m[2]!);
        if (n > max) max = n;
      }
    }
    return 'OR-$year-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// Records a payment and its receipt. A payment the office records itself is also added to
  /// [proofs] as already confirmed, so the website shows the same receipt.
  PaymentRecord _addPayment(String unit, String payer, String forText,
      String method, String reference, num amount,
      {PaymentProof? proof}) {
    final no = (proof != null && proof.receiptNo.isNotEmpty) ? proof.receiptNo : nextReceiptNo();
    final date = shortDate(DateTime.now());
    final rec = PaymentRecord(
      nextId(),
      no,
      unit,
      payer,
      forText,
      method,
      reference.trim().isEmpty ? '—' : reference.trim(),
      date,
      amount,
    );
    payments.insert(0, rec);
    if (proof == null) {
      proofs.insert(
        0,
        PaymentProof(nextId(), unit, payer, method, rec.reference, date, amount,
            status: 'Confirmed', forText: forText, receiptNo: no, confirmedOn: date, direct: true),
      );
    }
    return rec;
  }

  /// The oldest unpaid charge of a unit.
  Due? _firstOpenDue(String unit) {
    final open = dues.where((d) => d.unit == unit && !d.paid).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return open.isEmpty ? null : open.first;
  }

  /// The unpaid charge of [unit] with this note, if any.
  Due? _openDueNamed(String unit, String note) {
    for (final d in dues) {
      if (d.unit == unit && !d.paid && d.note == note) return d;
    }
    return null;
  }

  /// The signed-in resident's charges, newest first.
  List<Due> get myDues => dues.where((d) => d.unit == myUnit).toList()..sort((a, b) => b.id.compareTo(a.id));

  /// Resident: "I have paid" with the reference number. [due] is the charge being paid (the oldest open one when null).
  String? submitProof(String method, String reference, String amountRaw, {Due? due}) {
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter the amount you paid.';
    if (reference.trim().isEmpty) {
      return 'Enter the reference number from your payment receipt.';
    }
    final target = (due != null && !due.paid) ? due : _firstOpenDue(myUnit);
    proofs.insert(
        0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), a,
            forText: target == null ? 'Association dues' : target.note));
    logActivity('Payment reference sent, $myUnit', 'Finance');
    _n();
    return null;
  }

  // ---- expenses (administrator) ----
  final List<Expense> expenses = [];

  /// Records one purchase of the corporation. Returns an error message or null.
  String? addExpense({
    required String category,
    required String area,
    required String item,
    required String payee,
    required String qtyRaw,
    required String unitPriceRaw,
    required String receiptNo,
    required String note,
    required String dateRaw,
  }) {
    if (item.trim().isEmpty) return 'Enter what was bought.';
    final qty = qtyRaw.trim().isEmpty ? 1.0 : double.tryParse(qtyRaw.trim().replaceAll(',', ''));
    if (qty == null || qty <= 0) return 'Enter a valid quantity.';
    final price = double.tryParse(unitPriceRaw.trim().replaceAll(',', ''));
    if (price == null || price <= 0) return 'Enter the price of one piece or one unit.';
    if (payee.trim().isEmpty) return 'Enter the store or supplier.';
    final d = dateRaw.trim().isEmpty ? DateTime.now() : parseShortDate(dateRaw);
    if (d == null) return 'Enter the date like "Oct 10, 2026".';
    final e = Expense(
      id: nextId(),
      item: item.trim(),
      category: category,
      area: area,
      payee: payee.trim(),
      receiptNo: receiptNo.trim(),
      note: note.trim(),
      qty: qty,
      unitPrice: price,
      date: d,
    );
    expenses.add(e);
    expenses.sort((x, y) => y.date.compareTo(x.date));
    logActivity('Purchase recorded: ${e.item}, ${peso(e.amount)}', 'Finance');
    _n();
    return null;
  }

  /// Deletes an expense.
  void removeExpense(Expense e) {
    expenses.remove(e);
    _n();
  }

  /// Admin: sets the approved yearly budget of each category (a blank or 0 removes the line).
  void setBudget(Map<String, int> values) {
    annualBudget.clear();
    values.forEach((k, v) {
      if (v > 0) annualBudget[k] = v;
    });
    _n();
  }

  /// Total spent in a given month.
  num spentIn(int year, int month) => expenses
      .where((e) => e.date.year == year && e.date.month == month)
      .fold<num>(0, (s, e) => s + e.amount);

  /// Expenses of the current month.
  num get spentThisMonth {
    final n = DateTime.now();
    return spentIn(n.year, n.month);
  }

  /// Date -> 'October 2026'.
  String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// Admin: the proof checks out - record the payment and issue a receipt.
  PaymentRecord confirmProof(PaymentProof p) {
    if (p.status != 'Pending') {
      // Already handled (for example on the website a moment ago): return the receipt that exists.
      for (final r in payments) {
        if (p.receiptNo.isNotEmpty && r.receiptNo == p.receiptNo) return r;
      }
    }
    p.status = 'Confirmed';
    p.receiptNo = nextReceiptNo();
    p.confirmedOn = shortDate(DateTime.now());
    final isParking = p.forText == parkingPayFor;
    final due = isParking ? null : (_openDueNamed(p.unit, p.forText) ?? _firstOpenDue(p.unit));
    final String forText;
    if (due != null) {
      due.paid = true;
      forText = due.note;
    } else {
      forText = p.forText.isNotEmpty ? p.forText : 'Association dues';
    }
    p.forText = forText;
    final rec = _addPayment(p.unit, p.payer, forText, p.method, p.reference, p.amount, proof: p);
    logActivity('Payment recorded, ${p.unit}', 'Finance');
    // A paid parking reservation: the chosen slot goes to the resident straight away.
    if (isParking && p.slot.isNotEmpty) {
      final req = parking.where((r) => r.unit == p.unit && !r.confirmed && r.slot == p.slot).firstOrNull;
      if (req != null && assignRequest(req) == null) {
        logActivity('Parking slot ${p.slot} assigned to ${p.unit} (paid)', 'Parking');
      }
    }
    _n();
    return rec;
  }

  /// Rejects a payment proof.
  void rejectProof(PaymentProof p) {
    if (p.status != 'Pending') return;
    p.status = 'Rejected';
    logActivity('Payment reference not confirmed, ${p.unit}', 'Finance');
    _n();
  }

  /// Saves the details and on/off of a payment method.
  void updatePayMethod(PayMethod m, String details, bool enabled) {
    if (details.trim().isNotEmpty) m.details = details.trim();
    m.enabled = enabled;
    _n();
  }

  // ---------------------------------------------------------------- community

  final List<Grievance> grievances = [];

  final List<DocItem> docs = liveDocs();

  /// Documents the signed-in role is allowed to see.
  List<DocItem> get visibleDocs {
    final mine = role == Role.admin ? 'admin' : 'resident';
    return docs.where((d) => d.audience == 'all' || d.audience == mine).toList();
  }

  /// General documents (everything except finance).
  List<DocItem> get communityDocs =>
      visibleDocs.where((d) => d.cat != 'Finance').toList();

  /// Finance documents are kept separate from the general documents.
  List<DocItem> get financeDocs =>
      visibleDocs.where((d) => d.cat == 'Finance').toList();

  final List<Announcement> announcements = [];
  final List<EventItem> events = [];

  /// What happened in the app, newest first (shown as "Recent activity").
  final List<ActivityEntry> activityLog = [];

  /// Adds a line to the activity log.
  void logActivity(String title, String area) {
    activityLog.insert(0, ActivityEntry(title, area, DateTime.now()));
    if (activityLog.length > 200) activityLog.removeRange(200, activityLog.length);
  }

  /// "just now", "5 minutes ago", "Yesterday", "Oct 8, 2026".
  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
    if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    if (d.inDays == 1) return 'Yesterday';
    return shortDate(t);
  }

  /// Bookings to show as "upcoming": approved first, then waiting for approval.
  List<Booking> get upcomingBookings {
    final l = [
      ...bookings.where((b) => b.status == 'Approved'),
      ...bookings.where((b) => b.status == 'Pending'),
    ];
    return l.take(3).toList();
  }

  /// The signed-in resident's notifications, built from what is really on record.
  /// Each entry is [text, tone] with tone good | bad | info.
  List<List<String>> get myNotifs {
    final out = <List<String>>[];
    for (final b in myBookings) {
      if (b.status == 'Approved') {
        out.add(['Your ${b.place} booking (${b.when}) was approved.', 'good']);
      } else if (b.status == 'Denied') {
        out.add(['Your ${b.place} booking (${b.when}) was not approved.', 'bad']);
      } else if (b.status == 'Pending') {
        out.add(['Your ${b.place} request (${b.when}) is waiting for approval.', 'info']);
      }
    }
    for (final r in myDueRows) {
      if (r.status == 'Overdue') {
        out.add(['${r.month} is overdue.', 'bad']);
      } else if (r.status == 'Open') {
        out.add(['Open charge: ${r.month}.', 'info']);
      }
    }
    for (final p in myProofs) {
      if (p.status == 'Confirmed') {
        out.add(['Your payment (ref. ${p.reference}) was confirmed. The receipt is under Dues & payment.', 'good']);
      } else if (p.status == 'Rejected') {
        out.add(['Your payment (ref. ${p.reference}) could not be confirmed. Please check the reference number.', 'bad']);
      }
    }
    final rec = myUnitRec;
    if (rec != null && rec.needsApproval) {
      if (rec.usageStatus == 'approved') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} was approved.', 'good']);
      } else if (rec.usageStatus == 'rejected') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} was not approved. ${rec.usageRemark}', 'bad']);
      } else if (rec.usageStatus == 'pending') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} is waiting for the administrator.', 'info']);
      }
    }
    if (pollsToVote > 0) {
      out.add(['$pollsToVote poll${pollsToVote > 1 ? 's' : ''} waiting for your vote.', 'info']);
    }
    final mySlot = slotOf(myUnit);
    if (mySlot != null) out.add(['Motor parking slot ${mySlot.id} is assigned to your unit.', 'good']);
    for (final a in announcements.where((a) => a.status == 'Published').take(2)) {
      out.add(['New announcement: ${a.title}.', 'info']);
    }
    return out;
  }

  // ---------------------------------------------------------------- resident

  /// The signed-in resident's unit name.
  String get myUnit => me?.unitLabel ?? '';
  Unit? get myUnitRec {
    final l = units.where((u) => u.unit == myUnit).toList();
    return l.isEmpty ? null : l.first;
  }

  /// The household name of my unit.
  String get myHousehold => myUnitRec?.name ?? me?.name ?? '';
  /// My unit's bookings.
  List<Booking> get myBookings =>
      bookings.where((b) => b.unit == myUnit).toList();
  /// The grievances my unit sent.
  List<Grievance> get myGrievances =>
      grievances.where((g) => g.by == myUnit).toList();
  /// True if my unit already asked for parking.
  bool get parkingRequested => parking.any((p) => p.unit == myUnit);

  /// Every charge billed to the signed-in resident's unit, open ones first.
  List<MonthDue> get myDueRows {
    final mine = dues.where((d) => d.unit == myUnit).toList()
      ..sort((a, b) {
        if (a.paid != b.paid) return a.paid ? 1 : -1;
        return b.id.compareTo(a.id);
      });
    return [
      for (final d in mine)
        MonthDue(d.note, d.amt, d.dueDate.isEmpty ? 'upon receipt' : d.dueDate,
            d.paid ? 'Paid' : (d.overdue ? 'Overdue' : 'Open')),
    ];
  }

  /// My unit's total unpaid amount.
  num get myBalance =>
      myDueRows.where((d) => d.status != 'Paid').fold<num>(0, (s, d) => s + d.amt);

  Booking? get upcomingBooking {
    final l = myBookings
        .where((b) => b.status == 'Approved' || b.status == 'Pending')
        .toList();
    return l.isEmpty ? null : l.first;
  }

  /// Resident: asks for one time of an amenity on [day] (yyyy-mm-dd, today when empty).
  void submitBooking(int f, int slot, {String day = ''}) {
    final date = DateTime.tryParse(day) ?? DateTime.now();
    bookings.insert(
        0,
        Booking(nextId(), myHousehold, myUnit, amenities[f].name,
            '${shortDate(date)}, ${amenities[f].slots[slot]}', 'Pending',
            day: dayKey(date), slot: slot));
    logActivity('Booking request for the ${amenities[f].name} on ${shortDate(date)}, $myUnit', 'Facilities');
    _n();
  }

  /// Sends a new grievance.
  void addGrievance(String title, String body) {
    grievances.insert(0,
        Grievance(nextId(), title, body.isEmpty ? 'No further details.' : body, myUnit, 0));
    logActivity('Grievance opened: $title', 'Requests');
    _n();
  }

  /// Sends a parking request.
  void requestParking() {
    if (!parkingRequested) parking.add(ParkingReq(myUnit, myHousehold));
    logActivity('Motor parking requested, $myUnit', 'Parking');
    _n();
  }

  /// Usage changes my unit declared.
  List<StatusUpdate> get myStatusUpdates =>
      statusUpdates.where((u) => u.unit == myUnit).toList();

  /// Resident posts the new state of their unit. Takes effect immediately.
  String? postMyStatus(String key, String note) {
    final u = myUnitRec;
    if (u == null) return 'Unit record not found.';
    if (const ['tenant', 'shortterm', 'business', 'renovation'].contains(key) &&
        note.trim().isEmpty) {
      return 'Add a short note first, e.g. tenant name, platform, business type or expected end date.';
    }
    _applyStatus(u, key, note.trim(), 'Resident');
    _n();
    return null;
  }

  /// Resident declares how the unit is used. Tenants, short-term rentals, businesses and renovations
  /// come with the details the office needs.
  String? declareUnit(String key, Map<String, String> info, String note) {
    final u = myUnitRec;
    if (u == null) return 'Unit record not found.';
    if (usageForms.containsKey(key)) {
      final err = validateUsage(key, info);
      if (err != null) return err;
      final clean = {for (final e in info.entries) if (e.value.trim().isNotEmpty) e.key: e.value.trim()};
      _applyStatus(u, key, usageSummary(key, clean), 'Resident', info: clean);
    } else {
      _applyStatus(u, key, note.trim(), 'Resident', info: <String, String>{});
    }
    _n();
    return null;
  }

  /// Admin sets the state of any unit.
  void adminSetStatus(Unit u, String key, String note) {
    _applyStatus(u, key, note.trim(), 'Admin');
    _n();
  }

  /// Marks the usage decision as seen by the resident.
  void markStatusSeen() {
    if (newStatusUpdates == 0) return;
    newStatusUpdates = 0;
    _n();
  }

  /// Applies a usage declaration to the unit and records it.
  void _applyStatus(Unit u, String key, String note, String by, {Map<String, String>? info}) {
    final date = shortDate(DateTime.now());
    // The details only belong to the way the unit was declared as. Another way starts empty.
    u.usageInfo = info ?? (key == u.usage ? u.usageInfo : <String, String>{});
    u.usage = key;
    final needs = key == 'shortterm' || key == 'business';
    // A resident's declaration waits for the administrator; the administrator's own change is approved.
    u.usageStatus = !needs ? '' : (by == 'Admin' ? 'approved' : 'pending');
    u.usageRemark = '';
    u.statusNote = note;
    u.statusDate = date;
    u.status = key == 'vacant' ? 'Vacant' : 'Occupied';
    statusUpdates.insert(0, StatusUpdate(nextId(), u.unit, key, note, date, by));
    logActivity('${u.unit} status set to ${usageLabel(key).toLowerCase()}', 'Units');
  }

  // ---------------------------------------------------------------- admin

  /// How many dues are unpaid (all units).
  int get unpaidCount => dues.where((d) => !d.paid).length;
  /// How many grievances are not yet resolved.
  int get openGrievances => grievances.where((g) => g.stage < 2).length;
  /// How many bookings wait for a decision.
  int get pendingBookings => bookings.where((b) => b.status == 'Pending').length;
  /// How many parking requests wait for the admin.
  int get pendingParking => parking.where((p) => !p.confirmed).length;

  /// Blocks or opens a time slot of a facility.
  void toggleSlot(int f, int i) {
    final today = dayKey(DateTime.now());
    if (blockedDay != today) {
      blocked.clear();
      blockedDay = today;
    }
    final k = _slotKey(f, i);
    blocked[k] = !(blocked[k] ?? false);
    _n();
  }

  /// Approves or denies a booking.
  void bookAct(int id, String status) {
    final b = bookings.firstWhere((b) => b.id == id);
    b.status = status;
    logActivity('${b.place} booking ${status.toLowerCase()}, ${b.unit}', 'Facilities');
    _n();
  }

  /// Admin: adds a charge (e.g. a facility damage fee) to a unit.
  String? addCharge(String unitRaw, String amountRaw, String note) {
    String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = norm(unitRaw);
    final match = key.isEmpty ? <Unit>[] : units.where((u) => norm(u.unit) == key).toList();
    if (match.isEmpty) return 'No unit with that name. Add the unit first, or use a name such as "Unit 12A".';
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter a valid amount.';
    if (note.trim().isEmpty) return 'Add a short description, e.g. Facility damage fee.';
    dues.add(Due(nextId(), match.first.unit, match.first.name, a, note.trim()));
    logActivity('Charge added, ${match.first.unit}: ${note.trim()}', 'Finance');
    _n();
    return null;
  }

  /// Admin: sets what each unit pays every month.
  String? setDuesRate(String raw) {
    final n = double.tryParse(raw.trim().replaceAll(',', ''));
    if (n == null || n <= 0) return 'Enter the monthly dues amount.';
    duesRate = n;
    _n();
    return null;
  }

  int lastBilledCount = 0;

  /// Admin: bills the monthly association dues to every unit that has not been billed for [period] yet.
  String? billMonthlyDues(String period, String dueRaw) {
    if (duesRate <= 0) return 'Set the monthly dues amount first.';
    if (units.isEmpty) return 'Add the units first.';
    final p = period.trim();
    if (p.isEmpty) return 'Enter the month, e.g. October 2026.';
    String due = '';
    if (dueRaw.trim().isNotEmpty) {
      final d = parseShortDate(dueRaw);
      if (d == null) return 'Enter the due date like "Oct 15, 2026".';
      due = shortDate(d);
    }
    final note = 'Association dues - $p';
    var n = 0;
    for (final u in units) {
      if (dues.any((d) => d.unit == u.unit && d.note == note)) continue;
      dues.add(Due(nextId(), u.unit, u.name, duesRate, note, dueDate: due));
      n++;
    }
    lastBilledCount = n;
    if (n > 0) logActivity('Dues billed for $p: $n unit${n == 1 ? '' : 's'}', 'Finance');
    _n();
    return null;
  }

  /// Records a payment for a unit's dues and issues a receipt.
  PaymentRecord? payDue(int id, {String method = officePay, String reference = ''}) {
    final d = dues.firstWhere((d) => d.id == id);
    if (d.paid) return null;
    d.paid = true;
    final rec = _addPayment(d.unit, d.name, d.note, method, reference, d.amt);
    logActivity('Payment recorded, ${d.unit}', 'Finance');
    _n();
    return rec;
  }

  /// Saves the monthly parking rate (returns an error text if invalid).
  String? setRate(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || n < 0) return 'Enter a valid amount before updating the rate.';
    motorRate = n;
    _n();
    return null;
  }

  /// Saves the daily parking rate (returns an error text if invalid).
  String? setDailyRate(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || n < 0) return 'Enter a valid amount before updating the rate.';
    motorRateDay = n;
    _n();
    return null;
  }

  /// What a rental costs: the monthly rate, or the daily rate times [days].
  num parkAmount(String plan, int days) => plan == 'day' ? motorRateDay * (days < 1 ? 1 : days) : motorRate;

  /// Writes a rental on a slot: who has it, the plan, the dates and the charge.
  void _stamp(ParkingSlot s, String unit, String plan, int days, num amount) {
    final now = DateTime.now();
    s.unit = unit;
    s.plan = plan == 'day' ? 'day' : 'month';
    s.from = isoDay(now);
    s.until = parkUntil(s.plan, days, now);
    s.amount = amount;
  }

  /// Gives the first free slot to a parking request. Returns an error message or null.
  String? assignRequest(ParkingReq p) {
    ParkingSlot? free;
    if (p.slot.isNotEmpty) {
      free = slots.where((x) => x.id == p.slot).firstOrNull;
      if (free == null) return '${p.slot} no longer exists. Decline this request.';
      if (free.used) return '${p.slot} is already taken. Decline this request.';
    } else {
      free = freeSlot;
    }
    if (free == null) return 'There are no free slots right now.';
    _stamp(free, p.unit, p.plan, p.days, p.amount);
    p.confirmed = true;
    logActivity('Parking slot ${free.id} assigned to ${p.unit} (${parkPlanText(p.plan, p.days)})', 'Parking');
    _n();
    return null;
  }

  /// Confirms a parking request and assigns the slot.
  void confirmParking(ParkingReq p) => assignRequest(p);

  /// Declines a parking request.
  void declineParking(ParkingReq p) {
    parking.remove(p);
    logActivity('Parking request declined, ${p.unit}', 'Parking');
    _n();
  }

  ParkingSlot? get freeSlot {
    final held = heldSlots;
    for (final s in slots) {
      if (!s.used && !held.containsKey(s.id)) return s;
    }
    return null;
  }

  /// Slots a resident picked and has not been approved for yet: slot name to unit.
  Map<String, String> get heldSlots => {
        for (final r in parking)
          if (r.slot.isNotEmpty && !r.confirmed) r.slot: r.unit,
      };

  /// Slots nobody has and nobody holds.
  int get freeSlotCount {
    final held = heldSlots;
    return slots.where((s) => !s.used && !held.containsKey(s.id)).length;
  }

  ParkingReq? get myParkingReq {
    for (final r in parking) {
      if (r.unit == myUnit) return r;
    }
    return null;
  }

  /// The latest payment a unit sent for a parking slot that was not rejected.
  PaymentProof? parkingProofFor(String unit, String slot) {
    for (final p in proofs) {
      if (p.unit == unit && p.forText == parkingPayFor && p.slot == slot && p.status != 'Rejected') return p;
    }
    return null;
  }

  /// Resident: picks a free slot. The slot is held and the rental becomes a charge.
  String? reserveSlot(String id, {String plan = 'month', int days = 0}) {
    if (myParkingReq != null || slotOf(myUnit) != null) return 'You already have a parking slot or reservation.';
    final s = slots.where((x) => x.id == id).firstOrNull;
    if (s == null || s.used || heldSlots.containsKey(id)) return 'That slot was just taken. Please pick another.';
    final daily = plan == 'day';
    if (daily && motorRateDay <= 0) return 'Daily rental is not available yet.';
    if (daily && (days < 1 || days > 365)) return 'Enter 1 to 365 days.';
    final d = daily ? days : 0;
    parking.add(ParkingReq(myUnit, myHousehold, slot: id, amount: parkAmount(plan, d), plan: daily ? 'day' : 'month', days: d));
    logActivity('Motor parking slot $id reserved (${parkPlanText(daily ? 'day' : 'month', d)}), $myUnit', 'Parking');
    _n();
    return null;
  }

  /// Resident: "I have paid" for the reserved slot.
  String? submitParkingProof(String method, String reference) {
    final r = myParkingReq;
    if (r == null || r.slot.isEmpty || r.amount <= 0) return 'Reserve a slot first.';
    if (reference.trim().length < 4) return 'Enter the reference number from your receipt or transaction.';
    if (proofs.any((p) => p.unit == myUnit && p.status != 'Rejected' && p.method == method && p.reference.toLowerCase() == reference.trim().toLowerCase())) {
      return 'That reference number was already submitted.';
    }
    proofs.insert(
        0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), r.amount,
            forText: parkingPayFor, slot: r.slot));
    logActivity('Payment reference sent, $myUnit', 'Finance');
    _n();
    return null;
  }

  /// How many parking slots are rented.
  int get slotsUsed => slots.where((s) => s.used).length;

  /// The slot a unit has been given, or null.
  ParkingSlot? slotOf(String unit) {
    for (final s in slots) {
      if (s.unit == unit) return s;
    }
    return null;
  }

  /// Admin: adds [raw] more motor parking slots (M-01, M-02, ...). New names never reuse a name that is taken.
  String? addSlots(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1 || n > 200) return 'Enter how many slots to add (1 to 200).';
    final taken = {for (final s in slots) s.id};
    var top = 0;
    for (final s in slots) {
      final m = RegExp(r'^M-(\d+)$').firstMatch(s.id);
      if (m != null) top = top > int.parse(m.group(1)!) ? top : int.parse(m.group(1)!);
    }
    var added = 0;
    while (added < n) {
      top++;
      final id = 'M-${top.toString().padLeft(2, '0')}';
      if (taken.add(id)) {
        slots.add(ParkingSlot(id));
        added++;
      }
    }
    slots.sort((a, b) => naturalCompare(a.id, b.id));
    logActivity('$n motor parking slot${n == 1 ? '' : 's'} added', 'Parking');
    _n();
    return null;
  }

  /// Admin: gives a slot another name (the resident keeps it).
  String? renameSlot(ParkingSlot s, String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Enter a name for the slot.';
    if (name == s.id) return null;
    if (slots.any((x) => x != s && x.id.toLowerCase() == name.toLowerCase())) return '$name already exists.';
    final i = slots.indexOf(s);
    final renamed = ParkingSlot(name, s.unit, s.plan, s.from, s.until, s.amount);
    slots[i] = renamed;
    slots.sort((a, b) => naturalCompare(a.id, b.id));
    logActivity('Parking slot ${s.id} renamed to $name', 'Parking');
    _n();
    return null;
  }

  /// Admin: deletes a slot. A resident who had it loses it, and their request is cleared.
  void removeSlot(ParkingSlot s) {
    final unit = s.unit;
    slots.remove(s);
    if (unit.isNotEmpty) parking.removeWhere((r) => r.unit == unit);
    logActivity('Parking slot ${s.id} deleted${unit.isEmpty ? '' : ' (was $unit)'}', 'Parking');
    _n();
  }

  /// Resident: takes back a parking request the office has not answered yet.
  String? cancelMyParkingRequest() {
    final r = myParkingReq;
    if (r != null && r.slot.isNotEmpty && parkingProofFor(myUnit, r.slot) != null) {
      return 'You already sent a payment for this slot. Please contact the office.';
    }
    parking.removeWhere((r) => r.unit == myUnit && !r.confirmed);
    logActivity('Motor parking request cancelled, $myUnit', 'Parking');
    _n();
    return null;
  }

  /// Assigns a parking slot to a unit for a plan (monthly or daily).
  void assignSlot(ParkingSlot s, String unit, {String plan = 'month', int days = 1}) {
    final d = plan == 'day' ? (days < 1 ? 1 : days) : 0;
    _stamp(s, unit, plan, d, parkAmount(plan, d));
    for (final r in parking.where((r) => r.unit == unit)) {
      r.confirmed = true;
    }
    logActivity('Parking slot ${s.id} assigned to $unit (${parkPlanText(s.plan, d)})', 'Parking');
    _n();
  }

  /// Admin: ends a rental. The resident is taken off the slot and it is free again.
  void releaseSlot(ParkingSlot s) {
    final unit = s.unit;
    s
      ..unit = ''
      ..plan = 'month'
      ..from = ''
      ..until = ''
      ..amount = 0;
    if (unit.isNotEmpty) parking.removeWhere((r) => r.unit == unit);
    logActivity('Parking rental ended: $unit removed from ${s.id}', 'Parking');
    _n();
  }

  // ---- polls (admin publishes, residents vote once per unit) ----
  final List<Poll> polls = [];
  final Map<String, int> _votes = {}; // '<unit>|<pollId>' -> option index

  /// The option my unit voted for in a poll, or null.
  int? myVote(int pollId) => _votes['$myUnit|$pollId'];
  /// How many open polls my unit has not voted in.
  int get pollsToVote => polls.where((p) => p.open && myVote(p.id) == null).length;
  /// How many polls are open.
  int get openPolls => polls.where((p) => p.open).length;

  /// Saves my unit's vote (returns an error text if not allowed).
  String? castVote(Poll p, int option) {
    if (!p.open) return 'This poll is closed.';
    if (myVote(p.id) != null) return 'Your unit has already voted in this poll.';
    if (option < 0 || option >= p.options.length) return 'Pick an option first.';
    p.options[option].votes++;
    _votes['$myUnit|${p.id}'] = option;
    logActivity('Poll vote from $myUnit: ${p.question}', 'Polls');
    _n();
    return null;
  }

  /// Creates a poll (returns an error text if invalid).
  String? addPoll(String question, String optionsRaw) {
    final opts = optionsRaw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (question.trim().isEmpty || opts.length < 2) return 'Add a question and at least two options (one per line).';
    final closes = shortDate(DateTime.now().add(const Duration(days: 7)));
    polls.insert(0, Poll(nextId(), question.trim(), true, closes, [for (final o in opts) PollOption(o, 0)]));
    logActivity('Poll published: ${question.trim()}', 'Polls');
    _n();
    return null;
  }

  /// Opens or closes a poll.
  void togglePoll(Poll p) {
    p.open = !p.open;
    logActivity('Poll ${p.open ? 'reopened' : 'closed'}: ${p.question}', 'Polls');
    _n();
  }

  /// Deletes a poll.
  void deletePoll(Poll p) {
    polls.remove(p);
    _votes.removeWhere((k, _) => k.endsWith('|${p.id}'));
    logActivity('Poll deleted: ${p.question}', 'Polls');
    _n();
  }

  // ---- events (residents say they are going) ----
  final Set<String> _rsvps = {}; // '<unit>|<eventId>'

  /// The events the signed-in resident's unit is going to.
  Set<int> get rsvp => {
        for (final k in _rsvps)
          if (k.startsWith('$myUnit|')) int.tryParse(k.substring(myUnit.length + 1)) ?? -1,
      };

  /// How many units are going to an event.
  int goingCount(EventItem e) => _rsvps.where((k) => k.endsWith('|${e.id}')).length;

  /// Marks my unit as going or not going.
  void toggleRsvp(EventItem e) {
    final k = '$myUnit|${e.id}';
    if (!_rsvps.remove(k)) _rsvps.add(k);
    logActivity('${_rsvps.contains(k) ? 'Going to' : 'No longer going to'}: ${e.title}', 'Events');
    _n();
  }

  // ---- unit rentals (the administrator reviews short-term rentals and home businesses) ----
  int get rentalsToReview => units.where((u) => u.needsApproval && u.usageStatus == 'pending').length;

  /// Admin approves or rejects a unit's usage declaration.
  void reviewUsage(Unit u, bool approve, String note) {
    u.usageStatus = approve ? 'approved' : 'rejected';
    u.usageRemark = approve ? '' : (note.trim().isEmpty ? 'Not approved at this time. Please contact the office.' : note.trim());
    logActivity('${approve ? 'Approved' : 'Rejected'} ${usageLabel(u.usage).toLowerCase()} for ${u.unit}', 'Units');
    _n();
  }

  /// Moves a grievance to its next stage.
  void advanceGrievance(int id) {
    final g = grievances.firstWhere((g) => g.id == id);
    if (g.stage < 2) g.stage++;
    logActivity('Grievance ${g.stage == 2 ? 'resolved' : 'in progress'}: ${g.title}', 'Requests');
    _n();
  }

  /// Publishes an announcement.
  void publishAnn(int id) {
    final a = announcements.firstWhere((a) => a.id == id);
    a.status = 'Published';
    logActivity('Announcement published: ${a.title}', 'Announcements');
    _n();
  }

  /// Creates an announcement (and can text the residents).
  void addAnnouncement(String title, String body, String type, bool sms) {
    announcements.insert(
        0,
        Announcement(nextId(), title, body.isEmpty ? '—' : body, shortDate(DateTime.now()),
            'Published', type, sms));
    logActivity('Announcement published: $title', 'Announcements');
    _n();
  }

  /// Edits an announcement.
  void editAnnouncement(int id, String title, String body) {
    final a = announcements.firstWhere((a) => a.id == id);
    if (title.trim().isNotEmpty) a.title = title.trim();
    if (body.trim().isNotEmpty) a.body = body.trim();
    _n();
  }

  /// Deletes an announcement.
  void deleteAnnouncement(int id) {
    announcements.removeWhere((a) => a.id == id);
    _n();
  }

  /// Creates an event.
  void addEvent(String title, String date, String place) {
    events.insert(
        0,
        EventItem(nextId(), title, date.isEmpty ? 'Date TBD' : date,
            place.isEmpty ? 'Venue TBD' : place));
    _n();
  }

  /// Deletes an event.
  void deleteEvent(int id) {
    events.removeWhere((e) => e.id == id);
    _rsvps.removeWhere((k) => k.endsWith('|$id'));
    _n();
  }

  /// Largest file the shared database holds for one document.
  static const maxDocBytes = 2 * 1024 * 1024;

  /// Admin: adds a document everybody (or only residents / only the administrator) can open.
  String? addDoc(DocItem d) {
    if ((d.raw?.length ?? 0) > maxDocBytes) {
      return 'That file is larger than 2 MB. Use a smaller file.';
    }
    docs.insert(0, d.id.isEmpty ? d.withId('${nextId()}') : d);
    _n();
    return null;
  }

  /// Deletes a document.
  void removeDoc(DocItem d) {
    docs.remove(d);
    _n();
  }

  // ---- directory and house rules (administrator) ----
  void setDirectory(List<ContactInfo> contacts, List<List<String>> rules) {
    directoryContacts
      ..clear()
      ..addAll(contacts);
    houseRules
      ..clear()
      ..addAll(rules);
    _n();
  }
}

/// Orders "Unit 2A" before "Unit 12A".
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final x = re.allMatches(a).map((m) => m[0]!).toList();
  final y = re.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
    final c = (nx != null && ny != null) ? nx.compareTo(ny) : x[i].toLowerCase().compareTo(y[i].toLowerCase());
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}
