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
import 'reminders.dart';
import 'rich_text.dart';
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
/// "Oct 28, 3:20 PM"
String clockText(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_months[d.month - 1].substring(0, 3)} ${d.day}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "5h 12m", "45 min", "2 days", or "now".
String waitText(Duration d) {
  if (d.inSeconds <= 60) return 'now';
  final m = d.inMinutes, h = m ~/ 60;
  if (h >= 48) return '${(h / 24).round()} days';
  return h > 0 ? '${h}h ${m % 60}m' : '$m min';
}
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

  /// Floor area in square meters. Monthly dues are the area times the rate per sqm (0 = not set yet).
  num area;

  /// The day of the month this unit's dues are due (1 to 31, 0 = not set). Units differ, so payments come in all month.
  int dueDay;
  Unit(this.unit, this.name, this.type, this.status, this.contact, this.usage,
      {this.statusNote = '', this.statusDate = '', this.usageStatus = '', this.usageRemark = '', this.area = 0, this.dueDay = 0, Map<String, String>? usageInfo})
      : usageInfo = usageInfo ?? {};

  /// The household record the office keeps (shown to the resident on their dashboard).
  String email = '', moveIn = '', members = '', pets = '', vehicles = '';
  String emergencyName = '', emergencyRelation = '', emergencyPhone = '';

  /// Shown to the resident / kept private for the office.
  String noteResident = '', noteOffice = '', profileBy = '';
  int residents = 0;

  /// When the office last saved the record (milliseconds, 0 = never).
  int profileUpdated = 0;

  /// When the resident last edited their own household details, and who did it.
  int selfUpdated = 0;
  String selfBy = '';

  /// What the resident changed themselves (name, household details), newest first, the last 20.
  List<SelfChange> selfLog = [];

  /// Short-term rentals and home businesses need the administrator's approval.
  bool get needsApproval => usage == 'shortterm' || usage == 'business';
}

/// One entry in a unit's status history (also drives the admin's update feed).
/// One change a resident made to their own details: the field, the old and new value, when, and who.
class SelfChange {
  final String field, from, to, by;
  final int at;
  const SelfChange(this.field, this.from, this.to, this.at, this.by);
}

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

/// The result of checking a payment a resident sent: [why] lists what does not match (empty = clean).
class ProofCheck {
  final List<String> why;
  final num? expected;
  final Due? due;

  /// One short line per thing the office looks at (amount, reference, charge, photo). ok: true good, false bad, null neutral.
  final List<CheckItem> checks;
  const ProofCheck(this.why, this.expected, this.due, [this.checks = const []]);
  bool get ok => why.isEmpty;
}

class CheckItem {
  final bool? ok;
  final String label;
  const CheckItem(this.ok, this.label);
}

/// A facility booking (place, day, time, status Pending/Approved/Denied).
class Booking {
  final int id;
  final String who, unit, place;
  String when;
  String status; // Pending | Approved | Denied | Completed

  /// The day it is for (yyyy-mm-dd) and the time slot number, so two units cannot book the same slot.
  final String day;
  int slot;
  Booking(this.id, this.who, this.unit, this.place, this.when, this.status,
      {this.day = '', this.slot = -1});
}

/// One charge billed to a unit: monthly association dues, a damage fee, and so on.
class Due {
  final int id;
  final String unit, name;
  String note;
  num amount;

  /// Due date written like "Oct 15, 2026" (empty = due upon receipt).
  String dueDate;
  bool paid;

  /// The day the office billed (uploaded) this charge, like "Oct 1, 2026".
  String billedOn;

  /// For monthly dues: the unit's floor area and the rate per sqm used (0 for other charges).
  num area, rate;

  /// The last day the office sent a reminder for this charge, and how many were sent.
  String remindedOn;
  int reminders;

  /// The message the office wrote for the last reminder (shown to the resident).
  String remindMsg;

  /// "Did they pay?" bookkeeping. checkedAt = when the office last answered "No" (milliseconds, 0 = never) and checkedNo that day;
  /// lateFeeId = the late charge added for this charge; partOf = the full amount when only part was paid;
  /// balanceOf = the charge this one is the unpaid balance of; lateFor = the charge this late charge belongs to.
  int checkedAt, lateFeeId, balanceOf, lateFor;
  String checkedNo;
  num partOf;

  /// When the last reminder was sent (milliseconds, 0 = only the day is known), and whether the late charge was added by the system.
  int remindedAt;
  bool lateFeeAuto;
  Due(this.id, this.unit, this.name, this.amount, this.note,
      {this.dueDate = '', this.paid = false, this.billedOn = '', this.area = 0, this.rate = 0, this.remindedOn = '', this.reminders = 0, this.remindMsg = '',
      this.checkedAt = 0, this.lateFeeId = 0, this.balanceOf = 0, this.lateFor = 0, this.checkedNo = '', this.partOf = 0,
      this.remindedAt = 0, this.lateFeeAuto = false});
  num get amt => amount;

  /// When the last reminder went out, in milliseconds (0 = never).
  int get remindedMs => remindedAt > 0 ? remindedAt : (parseShortDate(remindedOn)?.add(const Duration(hours: 9)).millisecondsSinceEpoch ?? 0);

  /// "Reminded Oct 27, 4:30 PM · 2 times", or '' when nobody was reminded.
  String get remindedLabel {
    if (remindedMs == 0) return '';
    final when = remindedAt > 0 ? clockText(DateTime.fromMillisecondsSinceEpoch(remindedAt)) : remindedOn;
    return 'Reminded $when${reminders > 1 ? ' · $reminders times' : ''}';
  }

  bool remindedWithin(int hours) => remindedMs > 0 && DateTime.now().millisecondsSinceEpoch - remindedMs < hours * 3600000;

  /// Days since the due date (0 = due today). Null when paid or there is no due date.
  int? get daysLate {
    if (paid) return null;
    final x = parseShortDate(dueDate);
    if (x == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(x.year, x.month, x.day)).inDays;
  }

  /// The day it was billed. Older charges without it use the time stored in their id.
  String get billed {
    if (billedOn.isNotEmpty) return billedOn;
    return id > 1000000000000 ? shortDate(DateTime.fromMillisecondsSinceEpoch(id)) : '';
  }
  bool get isCharge => true;
  String get label => note;

  /// Unpaid and past its due date.
  bool get overdue {
    if (paid || dueDate.isEmpty) return false;
    final d = parseShortDate(dueDate);
    return d != null && DateTime.now().isAfter(d.add(const Duration(days: 1)));
  }
}

/// A unit's monthly dues (floor area x rate per sqm) with the totals billed and paid so far.
class UnitDues {
  final num area, rate, monthly, billed, paid;
  const UnitDues(this.area, this.rate, this.monthly, this.billed, this.paid);
  num get balance => billed - paid;
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

  /// Units that should see this notice. Empty means every resident.
  List<String> units;
  Announcement(this.id, this.title, this.body, this.date, this.status,
      this.type, this.sms, {List<String>? units}) : units = units ?? [];

  /// True if a resident living in [unit] should see this notice.
  bool visibleTo(String unit) => units.isEmpty || units.contains(unit);
}

/// A community event residents can join (RSVP).
class EventItem {
  final int id;
  final String title, date, place, about;
  EventItem(this.id, this.title, this.date, this.place, {this.about = ''});
}

/// One change to an account's contact info (or its creation), kept for the Update history list.
class AccountChange {
  final DateTime at;
  final String field, from, to;
  const AccountChange(this.at, this.field, {this.from = '', this.to = ''});
}

/// One sign-in account (a row of the profiles table), shown in Manage access.
class Account {
  final String id;
  String name, email, phone, unit, role, added;
  bool suspended;

  /// Email and mobile number were confirmed with codes.
  bool verified;

  /// When the account was created and last changed, and what changed (e.g. "Mobile number").
  DateTime? createdAt, updatedAt;
  String lastChange;

  /// The temporary password the office gave, kept (office-only) until the resident chooses their own. Empty otherwise.
  String tempPw = '';

  /// Every change to this account, newest first.
  final List<AccountChange> history;
  Account(this.id, this.name, this.email, this.phone, this.unit, this.role, this.added,
      {this.suspended = false, this.verified = false, this.createdAt, this.updatedAt, this.lastChange = '', List<AccountChange>? history})
      : history = history ?? [];

  /// "New" if the account was created in the last [days] days.
  bool isNew([int days = 7]) => createdAt != null && DateTime.now().difference(createdAt!).inDays < days;

  /// True if the contact info changed in the last [days] days (and the account is not just new).
  bool isUpdated([int days = 7]) => !isNew(days) && updatedAt != null && DateTime.now().difference(updatedAt!).inDays < days;

  bool get hasMobile => AppState.validMobile(AppState.normalizePhone(phone));
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

  /// 'computer', 'phone' or 'tablet' (decides the icon). [sample] marks demo entries of the prototype.
  final String kind;
  final bool sample;
  SessionInfo(this.id, this.device, this.location, this.when, this.current, {this.kind = 'computer', this.sample = false});
}

/// A resident's request for a parking slot.
class ParkingReq {
  final String unit, name;
  bool confirmed;

  /// The slot the resident picked on the map ('' for an older request without one), and the
  /// monthly rental that was charged when they picked it.
  String slot;
  num amount;

  /// 'month' or 'day', and the number of days for a daily rental (0 for monthly).
  String plan;
  int days;

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

  /// Language of the menus and titles: 'en' or 'fil' (see core/i18n.dart).
  String lang = 'en';
  void setLang(String code) {
    lang = code == 'fil' ? 'fil' : 'en';
    _n();
  }

  /// Settings > Devices: the alert for a new sign-in, and when the password was last changed here.
  bool newDeviceAlert = true;
  DateTime? passwordChangedAt;
  void setNewDeviceAlert(bool v) {
    newDeviceAlert = v;
    _n();
  }

  /// Signs out one of the other devices (this device is signed out with session.signOut()).
  void signOutSession(int id) {
    sessions = [for (final s in sessions) if (s.id != id || s.current) s];
    _n();
  }

  /// Signs out every device except this one.
  void signOutOtherSessions() {
    sessions = [for (final s in sessions) if (s.current) s];
    _n();
  }

  /// Called after the password was changed from Settings.
  void passwordChangedNow({bool signOutOthers = false}) {
    passwordChangedAt = DateTime.now();
    if (signOutOthers) sessions = [for (final s in sessions) if (s.current) s];
    _n();
  }

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

  /// Resident accounts, in unit order (the list the administrator picks recipients from).
  List<Account> get residentAccounts => [for (final a in trusted) if (a.role == 'Resident') a];

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

  static String _deviceKind() => kIsWeb
      ? 'computer'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android || TargetPlatform.iOS => 'phone',
          _ => 'computer',
        };

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
    sessions = [
      SessionInfo(1, _deviceLabel(), 'Signed in at ${_clock(DateTime.now())}', 'Active now', true, kind: _deviceKind()),
      // The prototype has no real list of sessions, so two sample devices let you try the buttons.
      if (const bool.fromEnvironment('PROTOTYPE', defaultValue: true)) ...[
        SessionInfo(2, 'Android phone · Chrome', 'Quezon City', '2 days ago', false, kind: 'phone', sample: true),
        SessionInfo(3, 'iPad · Safari', 'Quezon City', '9 days ago', false, kind: 'tablet', sample: true),
      ],
    ];
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
    sessions = [];
    passwordChangedAt = null;
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
    fblocks.clear();
    amenities
      ..clear()
      ..addAll(Amenity.defaults());
    bookings.clear();
    dues.clear();
    motorRate = 0;
    motorRateDay = 0;
    parkSizesSaved = [];
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
    walkins.clear();
    leaveNotes.clear();
    book.clear();
    remParking = RemCfg(days: 5, freq: 'every');
    remDues = RemCfg(days: 2, freq: 'daily');
    parkSoonDays = 5;
    smsLog.clear();
    _ballots.clear();
    pollCats
      ..clear()
      ..addAll(pollBuiltInCategories);
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
  String? addUnit(String unitRaw, String household, String type, String contact, {num area = 0, int dueDay = 0}) {
    var label = unitRaw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (label.isEmpty) return 'Enter the unit name, e.g. Unit 12A.';
    if (!label.toLowerCase().startsWith('unit ')) label = 'Unit $label';
    label = 'Unit ${label.substring(5).trim().toUpperCase()}';
    if (units.any((u) => u.unit.toLowerCase() == label.toLowerCase())) return '$label already exists.';
    units.add(Unit(label, household.trim().isEmpty ? '—' : household.trim(), type,
        'Occupied', contact.trim().isEmpty ? '—' : contact.trim(), 'owner', area: area, dueDay: dueDay));
    units.sort((a, b) => naturalCompare(a.unit, b.unit));
    logActivity('Unit added: $label', 'Units');
    _n();
    return null;
  }

  /// Admin: edits the household details of a unit.
  void updateUnit(Unit u, String household, String type, String contact, {num? area, int? dueDay}) {
    if (area != null) u.area = area;
    if (dueDay != null) u.dueDay = dueDay;
    u.name = household.trim().isEmpty ? '—' : household.trim();
    u.type = type;
    u.contact = contact.trim().isEmpty ? '—' : contact.trim();
    _n();
  }

  /// Admin: sets a unit's floor area. When [recalc] is true the unit's unpaid monthly dues are worked out again
  /// with the new size (area × the current rate per sqm). Returns an error text, or null.
  String? setUnitArea(Unit u, String raw, {bool recalc = true, String dueDayRaw = ''}) {
    final a = double.tryParse(raw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter the floor area in square meters, e.g. 45.';
    var day = 0;
    if (dueDayRaw.trim().isNotEmpty) {
      day = int.tryParse(dueDayRaw.trim()) ?? 0;
      if (day < 1 || day > 31) return 'The due day is a day of the month from 1 to 31.';
    }
    u.area = a;
    u.dueDay = day;
    var n = 0;
    if (recalc && duesRate > 0) {
      for (final d in dues.where((d) => d.unit == u.unit && !d.paid && d.area > 0 && d.rate > 0)) {
        d.area = a;
        d.rate = duesRate;
        d.amount = (a * duesRate * 100).round() / 100;
        n++;
      }
    }
    lastRecalcCount = n;
    logActivity('Unit size set, ${u.unit}: $a sqm${n > 0 ? ' ($n unpaid monthly charge${n == 1 ? '' : 's'} updated)' : ''}', 'Units');
    _n();
    return null;
  }

  int lastRecalcCount = 0;

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

  /// Times the administrator closed for cleaning, repairs and so on (any dates, any hours).
  final List<FBlock> fblocks = [];

  /// The block that closes one time slot of an amenity on a day, or null.
  FBlock? slotBlock(int f, int i, String day) {
    if (f >= amenities.length) return null;
    final a = amenities[f];
    final s = (toMinutes(a.open) ?? 0) + i * a.mins;
    for (final b in fblocks) {
      if (b.fits(a.name) && b.closes(day, s, s + a.mins)) return b;
    }
    return null;
  }

  /// True if the admin blocked this time slot today.
  bool slotClosed(int f, int i) =>
      (blockedDay == dayKey(DateTime.now()) && (blocked[_slotKey(f, i)] ?? false)) || slotBlock(f, i, dayKey(DateTime.now())) != null;

  /// Blocks that still matter (not finished) for an amenity, soonest first.
  List<FBlock> blocksFor(String name) {
    final today = dayKey(DateTime.now());
    final l = fblocks.where((b) => b.fits(name) && (b.to.isEmpty || b.to.compareTo(today) >= 0)).toList();
    l.sort((a, b) => a.from.compareTo(b.from));
    return l;
  }

  /// Bookings (waiting or approved) that fall inside a block.
  List<Booking> bookingsInBlock(FBlock b) {
    final out = <Booking>[];
    for (final x in bookings) {
      if (!(x.status == 'Pending' || x.status == 'Approved') || x.day.isEmpty || !b.fits(x.place) || !b.onDay(x.day)) continue;
      final fi = amenities.indexWhere((a) => a.name == x.place);
      if (fi < 0 || x.slot < 0) continue;
      final a = amenities[fi];
      final s = (toMinutes(a.open) ?? 0) + x.slot * a.mins;
      if (b.closes(x.day, s, s + a.mins)) out.add(x);
    }
    return out;
  }

  /// Admin: adds a block, or changes [edit]. Returns a message when something is wrong.
  /// [denyBookings] denies the bookings already made in that time.
  String? saveBlock(FBlock? edit, {required String facility, required String reason, required String note, required String from, required String to, required bool someHours, required String start, required String end, bool denyBookings = false}) {
    if (DateTime.tryParse(from) == null) return 'Choose the first date.';
    if (to.isNotEmpty && DateTime.tryParse(to) == null) return 'Choose a valid last date.';
    if (to.isNotEmpty && to.compareTo(from) < 0) return 'The last date cannot be before the first date.';
    if (someHours) {
      final s = toMinutes(start), e = toMinutes(end);
      if (s == null || e == null) return 'Choose the start and end time.';
      if (e <= s) return 'The end time must be after the start time.';
    }
    final b = edit ?? FBlock('b${DateTime.now().millisecondsSinceEpoch}', facility, reason, note.trim(), from, to, someHours, start, end);
    if (edit != null) {
      b
        ..facility = facility
        ..reason = reason
        ..note = note.trim()
        ..from = from
        ..to = to
        ..someHours = someHours
        ..start = someHours ? start : ''
        ..end = someHours ? end : '';
    } else {
      if (!someHours) {
        b.start = '';
        b.end = '';
      }
      fblocks.add(b);
    }
    final hit = bookingsInBlock(b);
    var denied = 0;
    if (denyBookings) {
      for (final x in hit) {
        x.status = 'Denied';
        denied++;
      }
    }
    lastBlockNote = denied > 0
        ? 'Saved. $denied booking${denied == 1 ? ' was' : 's were'} denied.'
        : hit.isNotEmpty
            ? 'Saved. ${hit.length} booking${hit.length == 1 ? ' is' : 's are'} still inside this time.'
            : 'Saved. Residents can no longer book that time.';
    logActivity('${edit == null ? 'Blocked' : 'Blocked time changed'}: ${facility == '*' ? 'all facilities' : facility} ($reason, ${b.whenText})${denied > 0 ? ', $denied denied' : ''}', 'Facilities');
    _n();
    return null;
  }

  /// What the last [saveBlock] did, for a message.
  String lastBlockNote = '';

  /// Admin: opens a block up again (a block that has not started is cancelled, a running one ends yesterday).
  void endBlock(FBlock b) {
    final today = dayKey(DateTime.now());
    if (b.from.compareTo(today) > 0) {
      fblocks.remove(b);
    } else {
      b.to = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    }
    logActivity('Reopened: ${b.facility == '*' ? 'all facilities' : b.facility} (${b.reason})', 'Facilities');
    _n();
  }

  /// Admin: removes a finished block from the list.
  void removeBlock(FBlock b) {
    fblocks.remove(b);
    _n();
  }

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
    if (slotBlock(f, i, day) != null) return 'closed';
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

  /// Monthly association dues per square meter of floor area (set by the administrator).
  num duesRate = 0;

  /// What a unit pays each month, and what it has been billed and has paid so far (computed from the records).
  UnitDues unitDues(Unit u) {
    var billed = 0.0, paid = 0.0;
    for (final d in dues) {
      if (d.unit != u.unit) continue;
      billed += d.amt;
      if (d.paid) paid += d.amt;
    }
    return UnitDues(u.area, duesRate, (u.area * duesRate * 100).round() / 100, billed, paid);
  }

  /// Payments recorded on one day.
  List<PaymentRecord> paymentsOn(DateTime day) =>
      [for (final p in payments) if (dayKey(p.when) == dayKey(day)) p];

  /// Unpaid charges that fall due on one day.
  List<Due> dueOn(DateTime day) => [
        for (final d in dues)
          if (!d.paid && d.dueDate.isNotEmpty && parseShortDate(d.dueDate) != null && dayKey(parseShortDate(d.dueDate)!) == dayKey(day)) d,
      ];

  /// Purchases recorded on one day.
  List<Expense> expensesOn(DateTime day) => [for (final e in expenses) if (dayKey(e.date) == dayKey(day)) e];

  /// Money collected on every day of a month (index 0 = the 1st).
  List<double> collectedPerDay(int year, int month) {
    final n = DateTime(year, month + 1, 0).day;
    final out = List<double>.filled(n, 0);
    for (final p in payments) {
      final w = p.when;
      if (w.year == year && w.month == month) out[w.day - 1] += p.amount.toDouble();
    }
    return out;
  }
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
  String? submitProof(String method, String reference, String amountRaw, {Due? due, String image = '', String paidOn = ''}) {
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter the amount you paid.';
    if (reference.trim().isEmpty) {
      return 'Enter the reference number from your payment receipt.';
    }
    final paidDay = parseShortDate(paidOn.trim());
    if (paidDay == null) return 'Enter the date you paid, like ${shortDate(DateTime.now())}.';
    if (paidDay.isAfter(DateTime.now())) return 'The date you paid cannot be in the future.';
    final target = (due != null && !due.paid) ? due : _firstOpenDue(myUnit);
    proofs.insert(
        0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), a,
            forText: target == null ? 'Association dues' : target.note, at: DateTime.now().millisecondsSinceEpoch, image: image, paidOn: shortDate(paidDay)));
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

  // ---- automatic posting of the payments residents send

  /// When on, a payment that matches its charge is posted by itself [autoPostHours] after it was sent.
  bool autoPostOn = true;
  int autoPostHours = 24;

  void setAutoPost(bool on, int hours) {
    autoPostOn = on;
    autoPostHours = hours;
    logActivity('Automatic posting ${on ? 'on, after $hours hours' : 'turned off'}', 'Settings');
    _n();
  }

  // ------------------------------------------------------------ reminders and the bell

  RemCfg remParking = RemCfg(days: 5, freq: 'every');
  RemCfg remDues = RemCfg(days: 2, freq: 'daily');

  /// Read marks and "shown today" marks of the notification list and the reminder pop-up.
  final NotifBook book = NotifBook();

  RemCfg remOf(String kind) => kind == 'parking' ? remParking : remDues;

  void setRem(String kind, RemCfg c) {
    if (kind == 'parking') {
      remParking = c;
      parkSoonDays = c.on ? c.days : -9999;
    } else {
      remDues = c;
    }
    logActivity('Reminder changed: ${remNames[kind]} (${c.on ? '${c.days} days before, ${(remFreqLabels[c.freq] ?? '').toLowerCase()}' : 'off'})', 'Settings');
    _n();
  }

  /// The message of a reminder, in the office's words when it has set them.
  String remText(String kind, Map<String, String> vars) {
    final t = remOf(kind).msg.trim();
    return remFill(t.isEmpty ? remDefaultText[kind]! : t, vars);
  }

  /// Whether the office wrote its own words for this reminder.
  bool remCustom(String kind) => remOf(kind).msg.trim().isNotEmpty;

  /// Who the bell belongs to.
  String get bellScope => role == Role.admin ? 'admin' : 'r-$myUnit';

  /// The signed-in resident's notifications with read marks, newest first.
  List<NotifItem> get myBell => book.list(bellScope, [
        for (final n in myNotifs) (text: n[0], tone: n[1], dueId: n.length > 2 ? n[2] : null, icon: null, tab: null),
      ]);

  int bellBadge(List<NotifItem> items) => book.badge(bellScope, items);

  void bellOpened(String scope) {
    book.opened[scope] = DateTime.now().millisecondsSinceEpoch;
    _n();
  }

  void bellRead(String key) {
    book.read[key] = DateTime.now().millisecondsSinceEpoch;
    _n();
  }

  void bellReadAll(List<NotifItem> items) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final n in items) {
      book.read[n.key] = now;
    }
    _n();
  }

  /// Reminders this resident has right now (before the "how often" rule), most urgent first.
  List<Reminder> get remCandidates {
    final out = <Reminder>[];
    final slot = slotOf(myUnit);
    final pd = slot == null ? null : parkDueOf(slot);
    if (remParking.on &&
        remParking.freq != 'bell' &&
        slot != null &&
        pd != null &&
        pd.soon &&
        !leaveNotes.containsKey(myUnit) &&
        renewProofOf(myUnit, slot.id) == null &&
        walkinOf(myUnit, renew: true) == null) {
      out.add(Reminder(
        'park:${slot.id}:${pd.nextDue}',
        'parking',
        pd.late ? 'Your parking rental has ended or is due' : 'Your parking rental is almost up',
        remText('parking', {'slot': slot.id, 'date': isoShort(pd.nextDue), 'days': parkDaysText(pd.days)}),
        'Open Parking',
        pd.late,
        pd.days,
      ));
    }
    if (remDues.on && remDues.freq != 'bell') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final d in myDues.where((d) => !d.paid)) {
        if (myProofs.any((p) => p.status == 'Pending' && p.forText == d.note)) continue;
        final due = parseShortDate(d.dueDate);
        if (due == null) continue;
        final n = DateTime(due.year, due.month, due.day).difference(today).inDays;
        if (n > remDues.days) continue;
        out.add(Reminder(
          'due:${d.id}',
          'dues',
          n < 0 ? 'Overdue charge' : 'Charge coming due',
          remText('dues', {'item': d.note, 'amount': peso(d.amt), 'when': remWhen(n), 'date': d.dueDate}),
          'Pay now',
          n < 0,
          n,
          '${d.id}',
        ));
      }
    }
    out.sort((a, b) => a.n.compareTo(b.n));
    return out.take(4).toList();
  }

  /// The reminders to pop up now. Asking marks them as shown today.
  List<Reminder> remPopupItems() {
    final today = dayKey(DateTime.now());
    if (book.snoozed[myUnit] == today) return [];
    final items = remCandidates.where((r) => remOf(r.kind).freq == 'every' || book.shown['$myUnit|${r.key}'] != today).toList();
    for (final r in items) {
      book.shown['$myUnit|${r.key}'] = today;
    }
    return items;
  }

  void remSnoozeToday() => book.snoozed[myUnit] = dayKey(DateTime.now());

  /// Late charge added by the system when a charge is still unpaid [lateFeeDays] days after its due date.
  bool lateFeeOn = true;
  int lateFeeDays = 1;

  void setLateFee(bool on, int days, num pct) {
    lateFeeOn = on;
    lateFeeDays = days;
    latePct = pct;
    logActivity('Automatic late charge ${on ? 'on, $pct% after $days day${days == 1 ? '' : 's'}' : 'turned off'}', 'Settings');
    _n();
  }

  /// Adds the late charge to every charge still unpaid after the waiting days. Skips charges the resident already sent a payment for,
  /// charges the office answered "No" about, and charges that are themselves a late charge or a balance. Returns how many were added.
  int autoLateFeeCheck() {
    if (!lateFeeOn || role != Role.admin) return 0;
    final pend = <String>{for (final p in proofs) if (p.status == 'Pending') '${p.unit}|${p.forText}'};
    final todo = [
      for (final d in dues)
        if (!d.paid &&
            d.daysLate != null &&
            d.daysLate! >= lateFeeDays &&
            d.daysLate! <= lateFeeDays + 6 &&
            d.amount > 0 &&
            d.lateFeeId == 0 &&
            d.checkedAt == 0 &&
            d.lateFor == 0 &&
            d.balanceOf == 0 &&
            !d.note.startsWith('Late charge') &&
            !pend.contains('${d.unit}|${d.note}'))
          d,
    ];
    for (final d in todo) {
      final amt = (d.amount * latePct).round() / 100;
      if (amt <= 0) continue;
      final lid = nextId();
      dues.add(Due(lid, d.unit, d.name, amt, 'Late charge: ${d.note}',
          dueDate: shortDate(DateTime.now().add(const Duration(days: 7))), billedOn: shortDate(DateTime.now()), lateFor: d.id));
      d.lateFeeId = lid;
      d.lateFeeAuto = true;
      d.remindedOn = shortDate(DateTime.now());
      d.remindedAt = DateTime.now().millisecondsSinceEpoch;
      d.reminders++;
      d.remindMsg = 'This charge is overdue, so a late charge of ${peso(amt)} was added. Please pay now and send your proof under Dues. If you already paid, send your payment details so it is removed.';
      logActivity('Late charge added automatically, ${d.unit}: ${d.note} (${peso(amt)})', 'Finance');
    }
    if (todo.isNotEmpty) _n();
    return todo.length;
  }

  /// A late charge added by the system is taken off again when the resident paid on time.
  void _voidAutoLateFee(Due d, DateTime? paidDate) {
    if (d.lateFeeId == 0 || !d.lateFeeAuto || paidDate == null) return;
    final x = parseShortDate(d.dueDate);
    if (x == null) return;
    final lf = dues.where((e) => e.id == d.lateFeeId).firstOrNull;
    if (lf == null || lf.paid) return;
    if (DateTime(paidDate.year, paidDate.month, paidDate.day).isAfter(DateTime(x.year, x.month, x.day))) return;
    dues.remove(lf);
    logActivity('Late charge removed, ${d.unit}: ${d.note} (paid on time)', 'Finance');
  }

  /// What is wrong (if anything) with a payment the resident sent. Clean ones can be posted automatically.
  ProofCheck proofCheck(PaymentProof p) {
    final why = <String>[];
    final isParking = p.forText == parkingPayFor;
    final named = _openDueNamed(p.unit, p.forText);
    num? expected;
    if (named != null) {
      expected = named.amt;
    } else if (isParking) {
      final req = p.slot.isEmpty ? null : parking.where((r) => r.unit == p.unit && r.slot == p.slot).firstOrNull;
      final rs = p.renew ? slots.where((x) => x.id == p.slot).firstOrNull : null;
      final mr = rs != null ? parkRenewAmount(rs) : ((req != null && req.amount > 0) ? req.amount : parkRatesFor(p.slot.isEmpty ? 'Regular' : slotSize(p.slot)).month);
      if (mr > 0) {
        expected = mr;
      } else {
        why.add('The parking rate is not set, so the amount cannot be checked.');
      }
    } else if (p.forText == 'Other charge') {
      why.add('An "other charge" has no fixed amount. Check it yourself.');
    } else if (dues.any((d) => d.unit == p.unit && d.paid && d.note == p.forText)) {
      why.add('That charge is already marked paid.');
    } else {
      why.add('No unpaid charge named "${p.forText}" for this unit.');
    }
    if (expected != null && (p.amount - expected).abs() > 0.009) {
      final diff = (p.amount - expected).abs();
      why.add('Amount sent ${peso(p.amount)} but it should be ${peso(expected)} (${p.amount < expected ? 'short' : 'over'} by ${peso(diff)}).');
    }
    final checks = <CheckItem>[];
    if (expected == null) {
      checks.add(const CheckItem(null, 'No fixed amount'));
    } else {
      final amtOk = (p.amount - expected).abs() <= 0.009;
      checks.add(CheckItem(amtOk, amtOk ? 'Amount matches the charge' : 'Amount does not match'));
    }
    final whyBeforeRef = why.length;
    final ref = p.reference.trim();
    if (ref.length < 4 || ref == '—') {
      why.add('No reference number.');
    } else {
      final low = ref.toLowerCase();
      final dup = proofs.where((o) => o.id != p.id && o.status != 'Rejected' && o.reference.toLowerCase() == low && o.method == p.method).firstOrNull;
      if (dup != null) {
        why.add('The same reference number was also sent by ${dup.unit}.');
      } else if (payments.any((o) => o.reference.toLowerCase() == low && o.method == p.method)) {
        why.add('This reference number already has a receipt.');
      }
    }
    final refOk = why.length == whyBeforeRef;
    checks.add(CheckItem(refOk, refOk ? 'Reference number is new' : 'Reference number problem'));
    if (named != null) {
      checks.add(const CheckItem(true, 'Charge is open'));
    } else if (isParking) {
      checks.add(const CheckItem(true, 'Parking charge'));
    } else if (p.forText == 'Other charge') {
      checks.add(const CheckItem(null, 'Other charge'));
    } else {
      checks.add(const CheckItem(false, 'Charge not found'));
    }
    checks.add(p.image.isNotEmpty ? const CheckItem(true, 'Photo attached') : const CheckItem(null, 'No photo'));
    final dueDay = named == null ? null : parseShortDate(named.dueDate);
    final paidDay = parseShortDate(p.paidOn);
    if (paidDay == null) {
      checks.add(const CheckItem(null, 'No payment date given'));
    } else if (dueDay == null) {
      checks.add(CheckItem(null, 'Paid on ${p.paidOn}'));
    } else {
      final late = DateTime(paidDay.year, paidDay.month, paidDay.day).difference(DateTime(dueDay.year, dueDay.month, dueDay.day)).inDays;
      checks.add(late <= 0 ? CheckItem(true, 'Paid on time (${p.paidOn})') : CheckItem(null, 'Paid $late day${late == 1 ? '' : 's'} after the due date'));
    }
    return ProofCheck(why, expected, named, checks);
  }

  /// When a pending payment will be posted by itself.
  DateTime autoPostAt(PaymentProof p) => p.sentAt.add(Duration(hours: autoPostHours));

  /// Posts, by itself, every clean payment that has waited long enough. Returns how many were posted.
  int autoPostCheck() {
    if (!autoPostOn || role != Role.admin) return 0;
    final now = DateTime.now();
    final ready = [
      for (final p in proofs)
        if (p.status == 'Pending' && !p.direct && !autoPostAt(p).isAfter(now) && proofCheck(p).ok) p,
    ];
    for (final p in ready) {
      confirmProof(p, auto: true);
    }
    return ready.length;
  }

  /// Admin: the proof checks out - record the payment and issue a receipt. [auto] = posted by the system.
  PaymentRecord confirmProof(PaymentProof p, {bool auto = false}) {
    if (p.status != 'Pending') {
      // Already handled (for example on the website a moment ago): return the receipt that exists.
      for (final r in payments) {
        if (p.receiptNo.isNotEmpty && r.receiptNo == p.receiptNo) return r;
      }
    }
    p.status = 'Confirmed';
    p.auto = auto;
    p.receiptNo = nextReceiptNo();
    p.confirmedOn = shortDate(DateTime.now());
    final isParking = p.forText == parkingPayFor;
    final due = _openDueNamed(p.unit, p.forText) ?? (isParking ? null : _firstOpenDue(p.unit));
    final String forText;
    if (due != null) {
      due.paid = true;
      _voidAutoLateFee(due, parseShortDate(p.paidOn));
      forText = due.note;
    } else {
      forText = p.forText.isNotEmpty ? p.forText : 'Association dues';
    }
    p.forText = forText;
    final rec = _addPayment(p.unit, p.payer, forText, p.method, p.reference, p.amount, proof: p);
    logActivity(auto ? 'Payment posted automatically, ${p.unit} (${p.receiptNo})' : 'Payment recorded, ${p.unit}', 'Finance');
    // A paid parking reservation: the chosen slot goes to the resident straight away. A paid renewal extends the rental.
    if (isParking && p.slot.isNotEmpty) {
      final sl = slots.where((x) => x.id == p.slot).firstOrNull;
      if (p.renew) {
        if (sl != null && sl.unit == p.unit) {
          final now = DateTime.now();
          final today = isoDay(now);
          final cur = DateTime.tryParse(sl.until);
          final start = (cur != null && sl.until.compareTo(today) >= 0) ? DateTime(cur.year, cur.month, cur.day + 1) : now;
          sl.until = parkUntil('month', 1, start);
          walkins.removeWhere((w) => w.unit == p.unit && w.renew);
          leaveNotes.remove(p.unit);
          logActivity('Parking rental renewed: ${sl.id} · ${p.unit} until ${isoShort(sl.until)}', 'Parking');
          sendSms(p.unit, approvedSmsText(sl, p.receiptNo, p.amount, true));
        }
      } else {
        final req = parking.where((r) => r.unit == p.unit && !r.confirmed && r.slot == p.slot).firstOrNull;
        if (req != null && assignRequest(req) == null) {
          walkins.removeWhere((w) => w.unit == p.unit && !w.renew);
          logActivity('Parking slot ${p.slot} assigned to ${p.unit} (paid)', 'Parking');
          if (sl != null) sendSms(p.unit, approvedSmsText(sl, p.receiptNo, p.amount, false));
        }
      }
    }
    _n();
    return rec;
  }

  /// Rejects a payment proof. The reason is kept with the submission and shown to the resident.
  void rejectProof(PaymentProof p, String reason) {
    if (p.status != 'Pending') return;
    p.status = 'Rejected';
    p.reason = reason.trim();
    p.rejectedOn = shortDate(DateTime.now());
    logActivity('Payment rejected, ${p.unit}: ${p.reason}', 'Finance');
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
  /// Published announcements this resident should see: those for everyone and those sent to their unit.
  List<Announcement> get myAnnouncements => [for (final a in announcements) if (a.status == 'Published' && a.visibleTo(myUnit)) a];

  List<List<String>> get myNotifs {
    final out = <List<String>>[];
    final hh = myUnitRec;
    if (hh != null && hh.profileUpdated > hh.selfUpdated && DateTime.now().millisecondsSinceEpoch - hh.profileUpdated < 7 * 86400000) {
      out.add(['The office updated your household record on ${shortDate(DateTime.fromMillisecondsSinceEpoch(hh.profileUpdated))}. You can see it on your dashboard.', 'info']);
    }
    for (final b in myBookings) {
      if (b.status == 'Approved') {
        out.add(['Your ${b.place} booking (${b.when}) was approved.', 'good']);
      } else if (b.status == 'Denied') {
        out.add(['Your ${b.place} booking (${b.when}) was not approved.', 'bad']);
      } else if (b.status == 'Pending') {
        out.add(['Your ${b.place} request (${b.when}) is waiting for approval.', 'info']);
      }
    }
    final openMine = myDues.where((d) => !d.paid).toList();
    if (openMine.isNotEmpty) {
      final owed = openMine.fold<num>(0, (s, d) => s + d.amt);
      final latest = openMine.first;
      out.add([
        'You have ${openMine.length} unpaid charge${openMine.length > 1 ? 's' : ''} (${peso(owed)}). Latest: ${latest.note}, billed ${latest.billed.isEmpty ? 'recently' : latest.billed}.',
        'info'
      ]);
      for (final d in openMine.where((d) {
        final b = parseShortDate(d.billed);
        return b != null && DateTime.now().difference(b).inDays < 14;
      }).take(3)) {
        out.add([
          'New charge from the office: ${d.note} (${peso(d.amt)}), billed ${d.billed}${d.dueDate.isEmpty ? '' : ', due ${d.dueDate}'}.',
          'info'
        ]);
      }
    }
    for (final d in openMine) {
      final rem = parseShortDate(d.remindedOn);
      final due = parseShortDate(d.dueDate);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final days = due?.difference(today).inDays;
      if (rem != null && DateTime.now().difference(rem).inDays < 10) {
        final state = days == null
            ? 'is waiting for your payment.'
            : days < 0
                ? 'is overdue by ${-days} day${days == -1 ? '' : 's'}.'
                : days == 0
                    ? 'is due today.'
                    : 'is due in $days day${days == 1 ? '' : 's'} (${d.dueDate}).';
        out.add(['Reminder from the office (${d.remindedOn})${d.remindMsg.isEmpty ? ':' : ': ${d.remindMsg} —'} ${d.note} (${peso(d.amt)}) $state', days != null && days < 0 ? 'bad' : 'info']);
      }
    }
    // Overdue from the day after the due date, and a heads-up 2 days ahead. Each one has a Pay now action.
    final todayD = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var nLate = 0;
    for (final d in openMine) {
      final due = parseShortDate(d.dueDate);
      if (due == null) continue;
      if (myProofs.any((p) => p.status == 'Pending' && p.forText == d.note)) continue;
      final days = DateTime(due.year, due.month, due.day).difference(todayD).inDays;
      if (days < 0 && nLate < 4) {
        nLate++;
        out.insert(0, ['Overdue by ${-days} day${days == -1 ? '' : 's'}: ${d.note} (${peso(d.amt)}). Tap to pay and send your proof.', 'bad', '${d.id}']);
      } else if (days >= 0 && remDues.on && days <= remDues.days) {
        out.add([
          days == 0
              ? '${d.note} is due TODAY (${d.dueDate}). Pay within the day and send your proof so your dashboard updates.'
              : '${d.note} is due ${days == 1 ? 'tomorrow' : 'in $days days'} (${d.dueDate}). Send your proof before the due date so your dashboard updates.',
          days == 0 ? 'bad' : 'warn',
          '${d.id}'
        ]);
      }
    }
    for (final r in myDueRows) {
      if (r.status == 'Overdue') {
        out.add(['${r.month} is overdue.', 'bad']);
      } else if (r.status == 'Open') {
        // the summary above already lists open charges
      }
    }
    for (final p in myProofs) {
      if (p.status == 'Confirmed') {
        out.add(['Your payment (ref. ${p.reference}) was ${p.auto ? 'posted automatically' : 'verified'}. Receipt ${p.receiptNo} is under Dues & payment.', 'good']);
      } else if (p.status == 'Pending') {
        out.add([
          'We received your payment details (${peso(p.amount)}, ref. ${p.reference}).${autoPostOn ? ' It will be posted to your dues automatically by ${clockText(autoPostAt(p))}. If something does not match, the office will tell you here.' : ' The office will verify it soon.'}',
          'info'
        ]);
      } else if (p.status == 'Rejected') {
        out.add(['Your payment (ref. ${p.reference}) was rejected${p.reason.isEmpty ? ' (please check the reference number)' : ': ${p.reason.replaceAll(RegExp(r'[.\s]+$'), '')}'}. You can send the correct details.', 'bad']);
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
    // a monthly rental that is about to end (or already ended): did they forget, or are they leaving?
    final pd = mySlot == null ? null : parkDueOf(mySlot);
    if (mySlot != null && pd != null && pd.soon && !leaveNotes.containsKey(myUnit) && renewProofOf(myUnit, mySlot.id) == null && walkinOf(myUnit, renew: true) == null) {
      out.insert(0, [
        remCustom('parking')
            ? remText('parking', {'slot': mySlot.id, 'date': isoShort(pd.nextDue), 'days': parkDaysText(pd.days)})
            : 'Your parking rental for ${mySlot.id} ${pd.late ? 'has ended or is due' : 'is almost up'}. The next payment is due ${isoShort(pd.nextDue)} (${parkDaysText(pd.days)}). Renew to keep your slot, or tell the office if you no longer plan to rent.',
        pd.late ? 'bad' : 'warn'
      ]);
    }
    // the texts the office sent (rental approved, next due date)
    for (final m in smsLog.where((m) => m.unit == myUnit && DateTime.now().millisecondsSinceEpoch - m.at < 14 * 86400000).take(2)) {
      out.add(['Text message to your phone: ${m.text}', 'good']);
    }
    for (final a in myAnnouncements.take(2)) {
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
    logActivity('Complaint opened: $title', 'Requests');
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

  /// The request that holds a time of amenity [f] today (waiting or approved), if any.
  Booking? bookingAtSlot(int f, int i) {
    if (f >= amenities.length) return null;
    final today = dayKey(DateTime.now());
    final place = amenities[f].name;
    return bookings.where((b) => b.day == today && b.slot == i && b.place == place && (b.status == 'Pending' || b.status == 'Approved')).firstOrNull;
  }

  /// Admin: changes a request's status and time. Returns an error text when the time is taken or closed.
  String? editBooking(Booking b, String status, int slot) {
    final fi = amenities.indexWhere((a) => a.name == b.place);
    final canSlot = fi >= 0 && b.day.isNotEmpty && slot >= 0 && slot < amenities[fi].slots.length;
    if (canSlot && (status == 'Pending' || status == 'Approved')) {
      final clash = bookings.where((x) => x != b && x.day == b.day && x.place == b.place && x.slot == slot && (x.status == 'Pending' || x.status == 'Approved')).firstOrNull;
      if (clash != null) return 'That time is already taken by ${clash.unit}. Choose another time.';
      if (b.day == dayKey(DateTime.now()) && slotClosed(fi, slot)) return 'That time is closed today. Open it first under Today\'s slots.';
    }
    b.status = status;
    if (canSlot) {
      b.slot = slot;
      final date = DateTime.tryParse(b.day);
      if (date != null) b.when = '${shortDate(date)}, ${amenities[fi].slots[slot]}';
    }
    logActivity('${b.place} booking changed (${status.toLowerCase()}), ${b.unit}', 'Facilities');
    _n();
    return null;
  }

  /// Admin: deletes a request for good, so its time becomes free.
  void removeBooking(Booking b) {
    bookings.remove(b);
    logActivity('${b.place} booking removed, ${b.unit}', 'Facilities');
    _n();
  }

  /// Admin: reserves a time of amenity [f] today for a unit (for example a walk-in at the office).
  String? reserveAmenityTime(int f, int i, String unitRaw) {
    String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = norm(unitRaw);
    final u = key.isEmpty ? null : units.where((x) => norm(x.unit) == key).firstOrNull;
    if (u == null) return 'No unit with that name. Use a name such as "Unit 12A".';
    final a = amenities[f];
    final now = DateTime.now();
    final start = (toMinutes(a.open) ?? 0) + i * a.mins;
    if (start <= now.hour * 60 + now.minute) return 'That time has already passed today. Choose a later time.';
    if (slotBooked(f, i)) return 'That time is no longer open.';
    bookings.insert(0, Booking(nextId(), u.name.isEmpty || u.name == '—' ? u.unit : u.name, u.unit, a.name, '${shortDate(now)}, ${a.slots[i]}', 'Approved', day: dayKey(now), slot: i));
    logActivity('${a.name} reserved for ${u.unit} (${a.slots[i]})', 'Facilities');
    _n();
    return null;
  }

  /// Approves or denies a booking.
  void bookAct(int id, String status) {
    final b = bookings.firstWhere((b) => b.id == id);
    b.status = status;
    logActivity('${b.place} booking ${status.toLowerCase()}, ${b.unit}', 'Facilities');
    _n();
  }

  /// Admin: adds a charge (e.g. a facility damage fee) to a unit.
  static const allUnits = 'All units';

  String? addCharge(String unitRaw, String amountRaw, String note, {String dueRaw = ''}) {
    String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = norm(unitRaw);
    final everyone = unitRaw.trim().toLowerCase() == allUnits.toLowerCase();
    final match = everyone
        ? [for (final u in units) if (u.name.isNotEmpty && u.name != '—') u]
        : (key.isEmpty ? <Unit>[] : units.where((u) => norm(u.unit) == key).toList());
    if (match.isEmpty) return everyone ? 'No unit has a household yet.' : 'No unit with that name. Add the unit first, or use a name such as "Unit 12A", or type All units.';
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter a valid amount.';
    if (note.trim().isEmpty) return 'Add a short description, e.g. Facility damage fee.';
    var due = '';
    if (dueRaw.trim().isNotEmpty) {
      final d = parseShortDate(dueRaw);
      if (d == null) return 'Enter the due date like "Oct 15, 2026".';
      due = shortDate(d);
    }
    for (final u in everyone ? match : [match.first]) {
      dues.add(Due(nextId(), u.unit, u.name, a, note.trim(), dueDate: due, billedOn: shortDate(DateTime.now())));
    }
    logActivity('Charge added, ${everyone ? 'all units (${match.length})' : match.first.unit}: ${note.trim()}', 'Finance');
    _n();
    return null;
  }

  /// Admin: sets what each unit pays every month.
  String? setDuesRate(String raw, {bool recalc = false}) {
    final n = double.tryParse(raw.trim().replaceAll(',', ''));
    if (n == null || n <= 0) return 'Enter the monthly dues per square meter.';
    duesRate = n;
    var k = 0;
    if (recalc) {
      for (final d in dues.where((d) => !d.paid && d.area > 0 && d.rate > 0 && d.rate != n)) {
        d.rate = n;
        d.amount = (d.area * n * 100).round() / 100;
        k++;
      }
    }
    lastRecalcCount = k;
    if (k > 0) logActivity('Monthly dues per sqm set to ${peso(n)} ($k unpaid monthly charge${k == 1 ? '' : 's'} updated)', 'Finance');
    _n();
    return null;
  }

  /// What a unit of each size pays at [rate] per sqm: [size, units, price], smallest first, plus units with no size.
  ({List<(num, int, num)> rows, int noSize, num total}) priceTable(num rate) {
    final groups = <num, int>{};
    var none = 0;
    num total = 0;
    for (final u in units) {
      if (u.area <= 0) {
        none++;
        continue;
      }
      groups[u.area] = (groups[u.area] ?? 0) + 1;
      total += (u.area * rate * 100).round() / 100;
    }
    final sizes = groups.keys.toList()..sort();
    return (rows: [for (final a in sizes) (a, groups[a]!, (a * rate * 100).round() / 100)], noSize: none, total: total);
  }

  // ---- "Did they pay?" (administrator) ----
  /// The late charge, as a percentage of the unpaid charge. The office changes it when answering "No".
  num latePct = 5;

  /// After a "No", the same charge is not asked about again for this many days.
  static const payCheckRecheckDays = 7;
  static const payCheckAsk =
      'Your charge is due. If you already paid, please send your payment details (and a photo of your payment) under Dues so your balance updates. If not yet, please pay soon. Thank you!';
  static const payCheckNoMsg =
      'Our records show this charge is still unpaid. Please pay it, or if you already paid, send your payment details under Dues so your balance updates. Thank you!';

  /// Charges whose due date has come (or passed) with no payment on record and nothing sent by the resident,
  /// oldest first. They may well have been paid already without the resident telling the system.
  List<({Due due, int days})> get payCheckList {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final pend = <String>{for (final p in proofs) if (p.status == 'Pending') '${p.unit}|${p.forText}'};
    final out = <({Due due, int days})>[];
    for (final d in dues) {
      if (d.paid || d.dueDate.isEmpty || d.amount <= 0) continue;
      final x = parseShortDate(d.dueDate);
      if (x == null) continue;
      final days = today.difference(DateTime.utc(x.year, x.month, x.day)).inDays;
      if (days < 0) continue;
      if (pend.contains('${d.unit}|${d.note}')) continue;
      if (d.checkedAt > 0 && now.millisecondsSinceEpoch - d.checkedAt < payCheckRecheckDays * 86400000) continue;
      out.add((due: d, days: days));
    }
    out.sort((a, b) => b.days.compareTo(a.days));
    return out;
  }

  /// The mobile number to call or text for a unit ('' when none is on file).
  String unitPhone(String unit) {
    for (final a in trusted) {
      if (a.role == 'Resident' && a.unit == unit && a.phone.trim().isNotEmpty) return a.phone.trim();
    }
    final u = units.where((x) => x.unit == unit).firstOrNull;
    return (u == null || u.contact == '—') ? '' : u.contact.trim();
  }

  /// YES, they paid. Records what was really paid and issues a receipt. If it is less than the charge, the rest becomes
  /// a new "(balance)" charge with the same due date. Returns an error text, or the receipt number and what is left.
  ({String? error, String receipt, num left}) payCheckYes(Due d, {required String amountRaw, required String method, String dateRaw = '', String reference = ''}) {
    ({String? error, String receipt, num left}) bad(String m) => (error: m, receipt: '', left: 0);
    if (d.paid) return bad('This charge is already paid.');
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return bad('Enter the amount they paid.');
    final amt = (a * 100).round() / 100, full = d.amount;
    if (amt > full + 0.009) return bad('That is more than the charge (${peso(full)}). Enter the amount that applies to this charge.');
    var when = DateTime.now();
    if (dateRaw.trim().isNotEmpty) {
      final x = parseShortDate(dateRaw);
      if (x == null) return bad('Enter the date like "Oct 25, 2026", or leave it empty for today.');
      if (x.isAfter(DateTime.now())) return bad('The date paid cannot be in the future.');
      when = x;
    }
    final date = shortDate(when), ref = reference.trim().isEmpty ? '—' : reference.trim();
    final payer = d.name.isEmpty ? d.unit : d.name;
    final no = nextReceiptNo();
    payments.insert(0, PaymentRecord(nextId(), no, d.unit, payer, d.note, method, ref, date, amt));
    proofs.insert(
      0,
      PaymentProof(nextId(), d.unit, payer, method, ref, date, amt,
          status: 'Confirmed', forText: d.note, receiptNo: no, confirmedOn: date, direct: true),
    );
    final left = ((full - amt) * 100).round() / 100;
    d.paid = true;
    _voidAutoLateFee(d, when);
    if (left > 0.009) {
      d.amount = amt;
      d.partOf = full;
      dues.add(Due(nextId(), d.unit, d.name, left, '${d.note} (balance)',
          dueDate: d.dueDate, billedOn: shortDate(DateTime.now()), balanceOf: d.id, checkedAt: DateTime.now().millisecondsSinceEpoch));
    }
    logActivity('Marked paid, ${d.unit}: ${d.note} ${peso(amt)}${left > 0.009 ? ' (balance ${peso(left)} left)' : ''}', 'Finance');
    _n();
    return (error: null, receipt: no, left: left > 0.009 ? left : 0);
  }

  /// NO, they did not pay. Optionally adds a late charge (due in 7 days) and sends the resident a reminder.
  /// Returns an error text, or a short summary of what was done.
  ({String? error, String done}) payCheckNo(Due d, {required bool late, String pctRaw = '', required bool notify, String message = ''}) {
    if (d.paid) return (error: 'This charge is already paid.', done: '');
    final notes = <String>[];
    if (late) {
      final pct = double.tryParse(pctRaw.trim().replaceAll(',', ''));
      if (pct == null || pct <= 0 || pct > 100) return (error: 'Enter the late charge as a percentage, from 0.1 to 100.', done: '');
      if (d.lateFeeId > 0) return (error: 'A late charge was already added for this charge.', done: '');
      final amt = (d.amount * pct).round() / 100;
      if (amt <= 0) return (error: 'The late charge works out to zero. Raise the percentage.', done: '');
      final lid = nextId();
      dues.add(Due(lid, d.unit, d.name, amt, 'Late charge: ${d.note}',
          dueDate: shortDate(DateTime.now().add(const Duration(days: 7))), billedOn: shortDate(DateTime.now()), lateFor: d.id));
      d.lateFeeId = lid;
      latePct = pct;
      notes.add('late charge ${peso(amt)}');
    }
    if (notify) {
      d.remindedOn = shortDate(DateTime.now());
      d.remindedAt = DateTime.now().millisecondsSinceEpoch;
      d.reminders++;
      d.remindMsg = message.trim().isEmpty ? payCheckNoMsg : message.trim();
      notes.add('reminder sent');
    }
    d.checkedAt = DateTime.now().millisecondsSinceEpoch;
    d.checkedNo = shortDate(DateTime.now());
    logActivity('Not paid, ${d.unit}: ${d.note}${notes.isEmpty ? '' : ' (${notes.join(', ')})'}', 'Finance');
    _n();
    return (error: null, done: notes.isEmpty ? 'Saved. We will ask again in $payCheckRecheckDays days if it is still unpaid.' : 'Saved for ${d.unit}: ${notes.join(' and ')}.');
  }

  /// Sends one message to every unit on the list: "if you already paid, send your payment details". Returns how many units.
  int payCheckAskAll(String message) {
    final l = payCheckList;
    final units = <String>{};
    for (final x in l) {
      x.due.remindedOn = shortDate(DateTime.now());
      x.due.remindedAt = DateTime.now().millisecondsSinceEpoch;
      x.due.reminders++;
      x.due.remindMsg = message.trim().isEmpty ? payCheckAsk : message.trim();
      units.add(x.due.unit);
    }
    if (units.isNotEmpty) logActivity('Asked ${units.length} unit(s) to send proof of payment', 'Finance');
    _n();
    return units.length;
  }

  /// Admin: sends a reminder for one unpaid charge. The resident sees it under Notifications.
  void remindDue(Due d, {String message = ''}) {
    if (d.paid) return;
    d.remindedOn = shortDate(DateTime.now());
    d.remindedAt = DateTime.now().millisecondsSinceEpoch;
    d.reminders++;
    d.remindMsg = message.trim();
    logActivity('Reminder sent, ${d.unit}: ${d.note}', 'Finance');
    _n();
  }

  /// Unpaid charges that are overdue, due within 7 days, or have no due date.
  List<Due> needReminder([int days = 7]) => [
        for (final d in dues)
          if (!d.paid &&
              !d.remindedWithin(24) &&
              (d.dueDate.isEmpty ||
                  parseShortDate(d.dueDate) == null ||
                  parseShortDate(d.dueDate)!.difference(DateTime.now()).inDays < days))
            d,
      ];

  /// Admin: reminds every unit in [needReminder]. Returns how many units were reminded.
  int remindAll({int days = 7, String message = ''}) {
    final list = needReminder(days);
    final units = <String>{};
    for (final d in list) {
      d.remindedOn = shortDate(DateTime.now());
      d.remindedAt = DateTime.now().millisecondsSinceEpoch;
      d.reminders++;
      d.remindMsg = message.trim();
      units.add(d.unit);
    }
    if (units.isNotEmpty) logActivity('Reminders sent to ${units.length} unit${units.length == 1 ? '' : 's'}', 'Finance');
    _n();
    return units.length;
  }

  int lastBilledCount = 0;
  int lastNoAreaCount = 0;

  /// Admin: changes the amount of a charge that is not paid yet (affects that unit only).
  String? editCharge(Due d, String amountRaw, {String? note, String? dueRaw, bool allUnits = false, bool remove = false}) {
    if (d.paid) return 'A paid charge cannot be changed.';
    final oldNote = d.note;
    final same = [for (final x in dues) if (!x.paid && x.note == oldNote) x];
    if (remove) {
      dues.removeWhere((x) => !x.paid && x.note == oldNote);
      logActivity('Charge removed from ${same.length} unit${same.length == 1 ? '' : 's'}: $oldNote', 'Finance');
      _n();
      return null;
    }
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter a valid amount.';
    final newNote = (note ?? oldNote).trim();
    final sameAmt = same.every((x) => (x.amount - d.amount).abs() < 0.005);
    if (newNote.isEmpty) return 'Add a short description.';
    var due = d.dueDate;
    if (dueRaw != null) {
      if (dueRaw.trim().isEmpty) {
        due = '';
      } else {
        final p = parseShortDate(dueRaw);
        if (p == null) return 'Enter the due date like "Oct 15, 2026".';
        due = shortDate(p);
      }
    }
    final old = d.amount;
    for (final x in (allUnits ? same : [d])) {
      for (final p in proofs.where((p) => p.status == 'Pending' && p.unit == x.unit && p.forText == oldNote)) {
        p.forText = newNote;
      }
      if (!(allUnits && !sameAmt && (a - old).abs() < 0.005)) x.amount = a;   // different amounts per unit: keep each unit's own unless a new one was typed
      x.note = newNote;
      x.dueDate = due;
    }
    logActivity('Charge edited, ${allUnits ? '${same.length} units' : d.unit}: $oldNote${newNote != oldNote ? ' → $newNote' : ''} ${peso(old)} to ${peso(a)}', 'Finance');
    _n();
    return null;
  }

  /// Admin: bills the monthly association dues to every unit that has not been billed for [period] yet.
  String? billMonthlyDues(String period, String dueRaw) {
    if (duesRate <= 0) return 'Set the monthly dues per square meter first.';
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
    final pm = _months.indexWhere((m) => p.toLowerCase().contains(m.toLowerCase()));
    final py = int.tryParse(RegExp(r'(20\d\d)').firstMatch(p)?.group(1) ?? '') ?? DateTime.now().year;
    final month = pm >= 0 ? pm + 1 : DateTime.now().month;
    var n = 0, noArea = 0;
    for (final u in units) {
      if (dues.any((d) => d.unit == u.unit && d.note == note)) continue;
      if (u.area <= 0) {
        noArea++;
        continue;
      }
      var ud = due;
      if (u.dueDay >= 1) {
        final last = DateTime(py, month + 1, 0).day;
        ud = shortDate(DateTime(py, month, u.dueDay > last ? last : u.dueDay));
      }
      dues.add(Due(nextId(), u.unit, u.name, (u.area * duesRate * 100).round() / 100, note,
          dueDate: ud, billedOn: shortDate(DateTime.now()), area: u.area, rate: duesRate));
      n++;
    }
    lastBilledCount = n;
    lastNoAreaCount = noArea;
    if (n > 0) logActivity('Dues billed for $p: $n unit${n == 1 ? '' : 's'}', 'Finance');
    _n();
    return null;
  }

  /// Records a payment for a unit's dues and issues a receipt.
  PaymentRecord? payDue(int id, {String method = officePay, String reference = ''}) {
    final d = dues.firstWhere((d) => d.id == id);
    if (d.paid) return null;
    d.paid = true;
    // A submission the resident already sent for this charge is closed with the same receipt,
    // so "Verify" can never settle another charge for the same money.
    final pending = proofs.where((p) => p.status == 'Pending' && p.unit == d.unit && p.forText == d.note).firstOrNull;
    if (pending != null) {
      pending.status = 'Confirmed';
      pending.receiptNo = nextReceiptNo();
      pending.confirmedOn = shortDate(DateTime.now());
    }
    final rec = _addPayment(d.unit, d.name, d.note, method, reference, d.amt, proof: pending);
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

  /// The rates the office saved for each slot size. Empty until they are saved.
  List<ParkSize> parkSizesSaved = [];

  /// Every slot size with its rates. Until the office sets them they come from the single rates.
  List<ParkSize> get parkSizes => parkSizesSaved.isNotEmpty
      ? parkSizesSaved
      : [for (final z in kParkSizeDefaults) ParkSize(z.$1, z.$2, (motorRate * z.$3 / 10).round() * 10, (motorRateDay * z.$3).round())];

  /// The rates of a size name (Regular when the name is unknown).
  ParkSize parkRatesFor(String size) {
    final all = parkSizes;
    return all.where((z) => z.name == size).firstOrNull ?? all.where((z) => z.name == 'Regular').firstOrNull ?? all.first;
  }

  /// The size of a slot by its name.
  String slotSize(String id) => slots.where((s) => s.id == id).firstOrNull?.size ?? 'Regular';

  /// Admin: saves the rates of every slot size. The Regular size also keeps the old single rates in step.
  String? setParkSizes(List<ParkSize> list) {
    for (final z in list) {
      if (z.month <= 0) return 'Enter a monthly rate for the ${z.name} slot.';
    }
    parkSizesSaved = list;
    final reg = list.where((z) => z.name == 'Regular').firstOrNull;
    if (reg != null) {
      motorRate = reg.month;
      motorRateDay = reg.day;
    }
    logActivity('Parking rates by slot size saved', 'Finance');
    _n();
    return null;
  }

  /// Admin: changes the size of a slot. The next resident pays the rate of this size.
  void setSlotSize(ParkingSlot s, String size) {
    s.size = size;
    logActivity('Parking slot ${s.id} set to $size', 'Parking');
    _n();
  }

  /// What a rental costs: the monthly rate, or the daily rate times [days], for a slot [size].
  num parkAmount(String plan, int days, {String size = 'Regular'}) {
    final r = parkRatesFor(size);
    return plan == 'day' ? r.day * (days < 1 ? 1 : days) : r.month;
  }

  /// Resident: saves the household details they may edit themselves (the office sees them).
  void saveMyRecord(Map<String, String> v, {int residents = 0}) {
    final u = myUnitRec;
    if (u == null) return;
    String t(String k) => (v[k] ?? '').trim();
    // what changed goes on the unit record as "Recent changes", so the office can see it
    final changes = <(String, String, String)>[];
    void diff(String label, String a, String b) {
      if (a != b) changes.add((label, a, b));
    }

    diff('People living here', u.residents > 0 ? '${u.residents}' : '', residents > 0 ? '$residents' : '');
    diff('Household members', u.members, t('members'));
    diff('Pets', u.pets, t('pets'));
    diff('Emergency contact', u.emergencyName, t('emergencyName'));
    diff('Emergency relationship', u.emergencyRelation, t('emergencyRelation'));
    diff('Emergency number', u.emergencyPhone, t('emergencyPhone'));
    diff('Vehicles', u.vehicles, t('vehicles'));
    logMyChange(changes);
    u.members = t('members');
    u.pets = t('pets');
    u.vehicles = t('vehicles');
    u.emergencyName = t('emergencyName');
    u.emergencyRelation = t('emergencyRelation');
    u.emergencyPhone = t('emergencyPhone');
    u.residents = residents;
    u.selfUpdated = DateTime.now().millisecondsSinceEpoch;
    u.selfBy = me?.name ?? 'the resident';
    logActivity('Resident updated household record, ${u.unit}', 'Units');
    _n();
  }

  /// Resident: writes what they changed on their own unit record (the office sees it as "Recent changes").
  void logMyChange(List<(String, String, String)> changes) {
    final u = myUnitRec;
    if (u == null || changes.isEmpty) return;
    String cut(String x) {
      x = x.replaceAll(RegExp(r'\s*\n\s*'), ', ');
      return x.length > 60 ? '${x.substring(0, 57)}…' : x;
    }

    final now = DateTime.now().millisecondsSinceEpoch, by = me?.name ?? 'the resident';
    u.selfLog = [for (final c in changes) SelfChange(c.$1, cut(c.$2), cut(c.$3), now, by), ...u.selfLog].take(20).toList();
    u.selfUpdated = now;
    u.selfBy = by;
    _n();
  }

  /// Admin: saves the household record of a unit. The resident sees it on their dashboard.
  void saveRecord(Unit u, Map<String, String> v, {int residents = 0}) {
    String t(String k) => (v[k] ?? '').trim();
    u.name = t('name').isEmpty ? '—' : t('name');
    u.type = t('type').isEmpty ? u.type : t('type');
    u.contact = t('contact').isEmpty ? '—' : t('contact');
    u.email = t('email');
    u.moveIn = t('moveIn');
    u.members = t('members');
    u.pets = t('pets');
    u.vehicles = t('vehicles');
    u.emergencyName = t('emergencyName');
    u.emergencyRelation = t('emergencyRelation');
    u.emergencyPhone = t('emergencyPhone');
    u.noteResident = t('noteResident');
    u.noteOffice = t('noteOffice');
    u.residents = residents;
    u.profileUpdated = DateTime.now().millisecondsSinceEpoch;
    u.profileBy = adminName;
    logActivity('Resident record updated, ${u.unit}', 'Units');
    _n();
  }

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

  /// Admin: changes a resident's request (the slot, the rental and the amount). Returns an error text or null.
  String? editParkingRequest(ParkingReq p, String slotId, String plan, int days, String amountRaw) {
    if (p.confirmed) return 'This request was already handled.';
    final daily = plan == 'day';
    if (daily && (days < 1 || days > 365)) return 'Enter 1 to 365 days.';
    if (slotId.isNotEmpty && slotId != p.slot) {
      final sl = slots.where((x) => x.id == slotId).firstOrNull;
      final holder = heldSlots[slotId];
      if (sl == null || sl.used || (holder != null && holder != p.unit)) return '$slotId is not free.';
    }
    final quote = parkAmount(plan, days, size: slotId.isEmpty ? 'Regular' : slotSize(slotId));
    final typed = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    final changed = slotId != p.slot || plan != p.plan || (daily && days != p.days);
    final amount = (typed != null && typed > 0 && typed != p.amount) ? typed : (changed ? quote : (p.amount > 0 ? p.amount : quote));
    final old = p.slot;
    p.slot = slotId;
    p.plan = daily ? 'day' : 'month';
    p.days = daily ? days : 0;
    p.amount = amount;
    if (slotId != old && old.isNotEmpty) {
      final pr = parkingProofFor(p.unit, old);
      if (pr != null && pr.status == 'Pending') pr.slot = slotId;
    }
    logActivity('Parking request edited, ${p.unit} (${slotId.isEmpty ? 'no slot' : slotId}, ${parkPlanText(p.plan, p.days)}, ${peso(amount)})', 'Parking');
    _n();
    return null;
  }

  /// Admin: changes a current rental (who has the slot, monthly or daily, the dates and the amount).
  String? editRental(ParkingSlot s, {required String unitRaw, required String plan, required String fromRaw, required String untilRaw, required String amountRaw}) {
    String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = norm(unitRaw);
    final u = key.isEmpty ? null : units.where((x) => norm(x.unit) == key).firstOrNull;
    if (u == null) return 'No unit with that name. Use a name such as "Unit 12A".';
    if (u.unit != s.unit && slotOf(u.unit) != null) return '${u.unit} already has a slot.';
    final from = parseShortDate(fromRaw);
    if (from == null) return 'Enter the start date, like ${shortDate(DateTime.now())}.';
    final untilText = untilRaw.trim();
    final until = untilText.isEmpty ? null : parseShortDate(untilText);
    if (untilText.isNotEmpty && until == null) return 'Enter the end date, like ${shortDate(DateTime.now())}.';
    if (until != null && until.isBefore(from)) return 'The end date must be on or after the start date.';
    final amt = amountRaw.trim().isEmpty ? 0.0 : double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (amt == null || amt < 0) return 'Enter a valid amount.';
    final daily = plan == 'day';
    s.unit = u.unit;
    s.plan = daily ? 'day' : 'month';
    s.from = isoDay(from);
    s.until = until != null ? isoDay(until) : parkUntil(s.plan, 1, from);
    s.amount = amt;
    logActivity('Parking rental edited: ${s.id} · ${u.unit} (${daily ? 'daily' : 'monthly'}, ${isoShort(s.from)} to ${isoShort(s.until)})', 'Parking');
    _n();
    return null;
  }

  /// Admin: the resident paid at the office. Records that payment (with a receipt) and assigns the reserved slot.
  String? parkingOfficePayment(ParkingReq p, String amountRaw, String ref, {String via = 'Cash'}) {
    if (p.confirmed || p.slot.isEmpty) return 'This request was already handled.';
    final amt = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (amt == null || amt <= 0) return 'Enter the amount received.';
    final sl = slots.where((x) => x.id == p.slot).firstOrNull;
    if (sl == null || sl.used) return '${p.slot} is already taken.';
    final id = nextId();
    final proof = PaymentProof(id, p.unit, p.name, walkinMethod(via), ref.trim().isEmpty ? 'OFFICE-$id' : ref.trim(), shortDate(DateTime.now()), amt,
        forText: parkingPayFor, slot: p.slot, at: DateTime.now().millisecondsSinceEpoch, paidOn: shortDate(DateTime.now()));
    proofs.insert(0, proof);
    confirmProof(proof);
    return null;
  }

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
    if (daily && parkRatesFor(s.size).day <= 0) return 'Daily rental is not available yet.';
    if (daily && (days < 1 || days > 365)) return 'Enter 1 to 365 days.';
    final d = daily ? days : 0;
    parking.add(ParkingReq(myUnit, myHousehold, slot: id, amount: parkAmount(plan, d, size: s.size), plan: daily ? 'day' : 'month', days: d));
    logActivity('Motor parking slot $id reserved (${parkPlanText(daily ? 'day' : 'month', d)}), $myUnit', 'Parking');
    _n();
    return null;
  }

  /// Resident: "I have paid" for the reserved slot.
  String? submitParkingProof(String method, String reference, {String image = '', String paidOn = ''}) {
    final r = myParkingReq;
    if (r == null || r.slot.isEmpty || r.amount <= 0) return 'Reserve a slot first.';
    if (reference.trim().length < 4) return 'Enter the reference number from your receipt or transaction.';
    final paidDay = parseShortDate(paidOn.trim());
    if (paidDay == null) return 'Enter the date you paid, like ${shortDate(DateTime.now())}.';
    if (paidDay.isAfter(DateTime.now())) return 'The date you paid cannot be in the future.';
    if (proofs.any((p) => p.unit == myUnit && p.status != 'Rejected' && p.method == method && p.reference.toLowerCase() == reference.trim().toLowerCase())) {
      return 'That reference number was already submitted.';
    }
    proofs.insert(
        0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), r.amount,
            forText: parkingPayFor, slot: r.slot, at: DateTime.now().millisecondsSinceEpoch, image: image, paidOn: shortDate(paidDay)));
    logActivity('Payment reference sent, $myUnit', 'Finance');
    _n();
    return null;
  }

  // ---- walk-in, renewal and text messages (motor parking) ----

  /// Residents who said they will pay at the office, residents who said they will not renew (unit -> note), and the texts sent.
  final List<Walkin> walkins = [];
  final Map<String, String> leaveNotes = {};
  final List<SmsMsg> smsLog = [];

  /// What the last text did, for the message shown to the administrator ("A text was sent to 0917 ...").
  String lastSmsNote = '';

  /// How the office can take a walk-in payment, and the method name written on the receipt.
  static const walkinOptions = ['Cash', 'Check', 'Card (debit or credit)', 'E-wallet (GCash or Maya)'];
  static String walkinMethod(String via) => via.startsWith('Card') ? 'Card at the office' : (via.startsWith('E-wallet') ? 'E-wallet at the office' : officePay);

  Walkin? walkinOf(String unit, {bool renew = false}) {
    for (final w in walkins) {
      if (w.unit == unit && w.renew == renew) return w;
    }
    return null;
  }

  /// "Unit 3B will come to the office today." / "... said they would come on Oct 27, 2026 and has not been recorded yet."
  String walkinText(Walkin w, String who) =>
      w.day == isoDay(DateTime.now()) ? '$who will come to the office today.' : '$who said they would come on ${isoShort(w.day)} and has not been recorded yet.';

  /// The renewal payment of a unit that waits for the office, or null.
  PaymentProof? renewProofOf(String unit, String slot) {
    for (final p in proofs) {
      if (p.unit == unit && p.forText == parkingPayFor && p.renew && p.slot == slot && p.status == 'Pending') return p;
    }
    return null;
  }

  /// What a monthly renewal costs: what the unit pays now, else the rate of the slot size.
  num parkRenewAmount(ParkingSlot s) => s.amount > 0 ? s.amount : parkRatesFor(s.size).month;

  /// Resident: "I'll walk in today". Tells the office to expect them (for the reserved slot, or [renew] for the rental).
  String? parkWalkIn({bool renew = false}) {
    final String slotId;
    final num amount;
    if (renew) {
      final s = slotOf(myUnit);
      if (s == null) return 'You do not have a parking slot to renew.';
      slotId = s.id;
      amount = parkRenewAmount(s);
    } else {
      final r = myParkingReq;
      if (r == null || r.slot.isEmpty) return 'Reserve a slot first.';
      slotId = r.slot;
      amount = r.amount;
    }
    walkins.removeWhere((w) => w.unit == myUnit && w.renew == renew);
    walkins.add(Walkin(myUnit, myHousehold, slotId, amount, renew, isoDay(DateTime.now()), DateTime.now().millisecondsSinceEpoch));
    logActivity('Walk-in payment announced, $myUnit ($slotId)', 'Parking');
    _n();
    return null;
  }

  void parkWalkInCancel({bool renew = false}) {
    walkins.removeWhere((w) => w.unit == myUnit && w.renew == renew);
    _n();
  }

  /// Resident: "I won't renew". The slot stays theirs until the rental ends.
  String? parkLeave(String note) {
    final s = slotOf(myUnit);
    if (s == null) return 'You do not have a parking slot.';
    leaveNotes[myUnit] = note.trim();
    logActivity('Will not renew parking: $myUnit (${s.id})', 'Parking');
    _n();
    return null;
  }

  void parkLeaveUndo() {
    leaveNotes.remove(myUnit);
    _n();
  }

  /// Resident: "I have paid" to renew the monthly rental.
  String? submitParkingRenewProof(String method, String reference, {String image = '', String paidOn = ''}) {
    final s = slotOf(myUnit);
    if (s == null) return 'You do not have a parking slot to renew.';
    if (renewProofOf(myUnit, s.id) != null) return 'Your renewal payment was already sent. The office will check it.';
    if (reference.trim().length < 4) return 'Enter the reference number from your receipt or transaction.';
    final paidDay = parseShortDate(paidOn.trim());
    if (paidDay == null) return 'Enter the date you paid, like ${shortDate(DateTime.now())}.';
    if (paidDay.isAfter(DateTime.now())) return 'The date you paid cannot be in the future.';
    if (proofs.any((p) => p.unit == myUnit && p.status != 'Rejected' && p.method == method && p.reference.toLowerCase() == reference.trim().toLowerCase())) {
      return 'That reference number was already submitted.';
    }
    proofs.insert(
        0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), parkRenewAmount(s),
            forText: parkingPayFor, slot: s.id, renew: true, at: DateTime.now().millisecondsSinceEpoch, image: image, paidOn: shortDate(paidDay)));
    logActivity('Renewal payment sent, $myUnit', 'Finance');
    _n();
    return null;
  }

  /// Admin: rentals that need the office: a renewal payment waiting, a walk-in announced, or a resident who will not renew.
  List<({ParkingSlot slot, PaymentProof? proof, Walkin? walkin, String? leave})> get parkRenewals {
    final out = <({ParkingSlot slot, PaymentProof? proof, Walkin? walkin, String? leave})>[];
    for (final s in slots) {
      if (!s.used || s.daily) continue;
      final pr = renewProofOf(s.unit, s.id);
      final w = walkinOf(s.unit, renew: true);
      final l = leaveNotes[s.unit];
      if (pr != null || w != null || l != null) out.add((slot: s, proof: pr, walkin: w, leave: l));
    }
    return out;
  }

  /// "Sends" a text to a unit. The prototype only saves it; a real SMS service would deliver it from here.
  void sendSms(String unit, String text) {
    final phone = unitPhone(unit);
    smsLog.insert(0, SmsMsg(nextId(), unit, phone, text, DateTime.now().millisecondsSinceEpoch, phone.isEmpty ? 'No number' : 'Sent'));
    lastSmsNote = phone.isEmpty ? 'No mobile number is on file for $unit, so no text was sent.' : 'A text was sent to $phone.';
    logActivity('Text ${phone.isEmpty ? 'not sent to $unit (no mobile number)' : 'sent to $unit ($phone)'}: $text', 'Parking');
  }

  /// The text a resident gets when their parking payment is approved: the rental period and the next due date.
  String approvedSmsText(ParkingSlot s, String receipt, num amount, bool renewed) {
    final d = parkDueOf(s);
    return 'ResidentHub: Your parking payment of ${peso(amount)} is approved. Slot ${s.id} is ${renewed ? 'renewed' : 'yours'} until ${isoShort(s.until)}.'
        '${d != null ? ' Next payment due: ${isoShort(d.nextDue)}.' : ' This daily rental ends on ${isoShort(s.until)}.'} Receipt $receipt. Thank you!';
  }

  /// Admin: a resident renews at the office. Records the payment (receipt), extends the rental and texts the resident.
  String? parkingRenewOfficePayment(ParkingSlot s, String amountRaw, String via, String ref) {
    if (!s.used || s.daily) return 'This rental changed. Close this and try again.';
    final amt = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (amt == null || amt <= 0) return 'Enter the amount received.';
    final id = nextId();
    final proof = PaymentProof(id, s.unit, whoOfUnit(s.unit), walkinMethod(via), ref.trim().isEmpty ? 'OFFICE-$id' : ref.trim(), shortDate(DateTime.now()), amt,
        forText: parkingPayFor, slot: s.id, renew: true, at: DateTime.now().millisecondsSinceEpoch, paidOn: shortDate(DateTime.now()));
    proofs.insert(0, proof);
    confirmProof(proof);
    return null;
  }

  /// The household name of a unit (or the unit name).
  String whoOfUnit(String unit) {
    final u = units.where((x) => x.unit == unit).firstOrNull;
    return (u == null || u.name.isEmpty || u.name == '—') ? unit : u.name;
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
  String? addSlots(String raw, {String size = 'Regular'}) {
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
        slots.add(ParkingSlot(id)..size = size);
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
    final renamed = ParkingSlot(name, s.unit, s.plan, s.from, s.until, s.amount)..size = s.size;
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
    walkins.removeWhere((w) => w.unit == unit && w.renew);
    leaveNotes.remove(unit);
    logActivity('Parking rental ended: $unit removed from ${s.id}', 'Parking');
    _n();
  }

  // ---- polls and elections (admin publishes, residents vote once per unit) ----
  final List<Poll> polls = [];
  final Map<String, PollBallot> _ballots = {}; // '<unit>|<pollId>' -> that unit's ballot

  /// The categories the administrator manages (General is always there).
  final List<String> pollCats = [...pollBuiltInCategories];

  /// The categories to choose from: the managed list plus any a poll already uses.
  List<String> get pollCategoryChoices {
    final out = [...pollCats];
    if (!out.contains('General')) out.insert(0, 'General');
    for (final p in polls) {
      if (p.category.isNotEmpty && !out.contains(p.category)) out.add(p.category);
    }
    return out;
  }

  /// My unit's ballot in a poll, or null.
  PollBallot? myBallot(int pollId) => _ballots['$myUnit|$pollId'];

  /// How many open polls my unit has not voted in.
  int get pollsToVote => polls.where((p) => p.open && myBallot(p.id) == null).length;

  /// How many polls are open.
  int get openPolls => polls.where((p) => p.open).length;

  /// The ballots cast in a poll (newest first).
  List<PollBallot> ballotsOf(Poll p) =>
      [for (final b in _ballots.values) if (b.poll == p.id) b]..sort((a, b) => b.at.compareTo(a.at));

  /// Counts every ballot into the results of every poll.
  void recountPolls() {
    for (final p in polls) {
      p.ballots = 0;
      for (final q in p.questions) {
        q.counts = List<int>.filled(q.options.length, 0);
        q.n = 0;
        q.ratingSum = 0;
        q.stars = [0, 0, 0, 0, 0];
        q.written = [];
      }
    }
    final byId = {for (final p in polls) p.id: p};
    for (final b in _ballots.values) {
      final p = byId[b.poll];
      if (p == null) continue;
      p.ballots++;
      for (final q in p.questions) {
        final v = b.answers[q.id];
        if (v == null || v == '') continue;
        if (q.type == 'choice') {
          final i = v is num ? v.toInt() : -1;
          if (i >= 0 && i < q.counts.length) {
            q.counts[i]++;
            q.n++;
          }
        } else if (q.type == 'multi') {
          var any = false;
          for (final x in (v is List ? v : [v])) {
            final i = x is num ? x.toInt() : -1;
            if (i >= 0 && i < q.counts.length) {
              q.counts[i]++;
              any = true;
            }
          }
          if (any) q.n++;
        } else if (q.type == 'rating') {
          final r = v is num ? v.toInt() : 0;
          if (r >= 1 && r <= 5) {
            q.stars[r - 1]++;
            q.ratingSum += r;
            q.n++;
          }
        } else {
          q.written.add(PollAnswer(b.unit, v.toString()));
          q.n++;
        }
      }
    }
  }

  /// For one choice question of an election: 'Elected', 'Tie' or '' for each candidate (only once it has closed).
  List<String> electedStatus(Poll p, PollQuestion q) {
    final seats = p.isElection ? (q.max < 1 ? 1 : q.max) : 0;
    final sorted = [...q.counts]..sort((a, b) => b.compareTo(a));
    final cut = seats > 0 && seats <= sorted.length ? sorted[seats - 1] : 0;
    final above = seats > 0 ? sorted.where((v) => v > cut).length : 0;
    final atCut = seats > 0 ? sorted.where((v) => v == cut).length : 0;
    return [
      for (final v in q.counts)
        if (seats == 0 || p.open || v <= 0)
          ''
        else if (v > cut)
          'Elected'
        else if (v == cut)
          (atCut > seats - above ? 'Tie' : 'Elected')
        else
          '',
    ];
  }

  /// Saves my unit's ballot (returns an error text if it is not allowed or not complete).
  String? castVote(Poll p, Map<String, dynamic> answers) {
    if (!p.open) return 'This poll is closed.';
    if (myBallot(p.id) != null) return 'Your unit has already voted in this poll.';
    final clean = <String, dynamic>{};
    for (var i = 0; i < p.questions.length; i++) {
      final q = p.questions[i];
      final v = answers[q.id];
      final empty = v == null || v == '' || (v is List && v.isEmpty);
      if (empty) {
        if (q.required) return 'Please answer question ${i + 1}.';
        continue;
      }
      if (q.type == 'multi' && q.max > 0 && v is List && v.length > q.max) {
        return 'Choose at most ${q.max} for ${p.isElection ? '"${q.text}"' : 'question ${i + 1}'}.';
      }
      clean[q.id] = v;
    }
    if (clean.isEmpty) return p.isElection ? 'Choose at least one candidate, or leave this election.' : 'Answer at least one question first.';
    _ballots['$myUnit|${p.id}'] = PollBallot(p.id, myUnit, DateTime.now().toIso8601String(), clean);
    recountPolls();
    logActivity('${p.isElection ? 'Ballot' : 'Poll vote'} from $myUnit: ${p.question}', 'Polls');
    _n();
    return null;
  }

  /// Creates a poll or election (returns an error text if something is missing).
  String? publishPoll({
    required String kind,
    required String category,
    required String titleHtml,
    required String descHtml,
    required String closeKey,
    required String showResults,
    required List<PollQuestion> questions,
  }) {
    final el = kind == 'election';
    final title = RtDoc.fromHtml(titleHtml).plain;
    if (title.isEmpty) return 'Give it a title first.';
    if (questions.isEmpty) return el ? 'Add at least one position.' : 'Add at least one question.';
    final qs = <PollQuestion>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final text = RtDoc.fromHtml(q.html).plain;
      if (text.isEmpty) return '${el ? 'Position' : 'Question'} ${i + 1} needs a name.';
      final opts = [for (final o in q.options) if (o.trim().isNotEmpty) o.trim()];
      final type = el ? (q.max > 1 ? 'multi' : 'choice') : q.type;
      final choice = type == 'choice' || type == 'multi';
      if (choice && opts.length < (el ? 1 : 2)) {
        return el ? 'Add at least one candidate for "$text".' : 'Add at least two options for "$text".';
      }
      qs.add(PollQuestion('q${i + 1}', type, q.html, text, q.required, el ? (q.max < 1 ? 1 : q.max) : (type == 'multi' ? q.max : 0), choice ? opts : []));
    }
    final end = DateTime.tryParse(closeKey);
    if (end == null || closeKey.compareTo(isoDay(DateTime.now())) < 0) return 'Pick a closing date that is today or later.';
    polls.insert(
        0,
        Poll(nextId(), title, true, shortDate(end), qs,
            kind: kind, category: category.isEmpty ? 'General' : category, titleHtml: titleHtml, descHtml: descHtml, closeKey: closeKey, showResults: showResults));
    recountPolls();
    logActivity('${el ? 'Election opened' : 'Poll published'}: $title', 'Polls');
    _n();
    return null;
  }

  /// Opens or closes a poll (reopening gives it another week).
  void togglePoll(Poll p) {
    final next = !p.open;
    p.open = next;
    if (next) {
      final end = DateTime.now().add(const Duration(days: 7));
      p.closeKey = isoDay(end);
      p.closes = shortDate(end);
    } else if (p.closeKey.isNotEmpty && p.closeKey.compareTo(isoDay(DateTime.now())) >= 0) {
      p.closes = shortDate(DateTime.now());
    }
    logActivity('${p.isElection ? 'Election' : 'Poll'} ${next ? 'reopened' : 'closed'}: ${p.question}', 'Polls');
    _n();
  }

  /// Deletes a poll and its ballots.
  void deletePoll(Poll p) {
    polls.remove(p);
    _ballots.removeWhere((k, b) => b.poll == p.id);
    logActivity('Poll deleted: ${p.question}', 'Polls');
    _n();
  }

  // ---- poll categories ----
  String? _catName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    return name;
  }

  /// Adds a category (returns an error text, or null when it was added).
  String? addPollCategory(String raw) {
    final name = _catName(raw);
    if (name == null) return 'Type a category name.';
    if (name.length > 40) return 'Keep the name under 40 characters.';
    if (pollCategoryChoices.any((c) => c.toLowerCase() == name.toLowerCase())) return 'That category already exists.';
    pollCats.add(name);
    logActivity('Poll category added: $name', 'Polls');
    _n();
    return null;
  }

  /// Renames a category everywhere it is used.
  String? renamePollCategory(String old, String raw) {
    if (old == 'General') return 'General is the default category and cannot be renamed.';
    final name = _catName(raw);
    if (name == null) return 'Type a category name.';
    if (name.length > 40) return 'Keep the name under 40 characters.';
    if (name == old) return null;
    if (pollCategoryChoices.any((c) => c != old && c.toLowerCase() == name.toLowerCase())) return 'That category already exists.';
    final i = pollCats.indexOf(old);
    if (i >= 0) {
      pollCats[i] = name;
    } else {
      pollCats.add(name);
    }
    for (final p in polls.where((p) => p.category == old)) {
      p.category = name;
    }
    logActivity('Poll category renamed: $old to $name', 'Polls');
    _n();
    return null;
  }

  /// Removes a category; its polls move to General.
  String? removePollCategory(String name) {
    if (name == 'General') return 'General is the default category and cannot be removed.';
    pollCats.remove(name);
    for (final p in polls.where((p) => p.category == name)) {
      p.category = 'General';
    }
    logActivity('Poll category removed: $name', 'Polls');
    _n();
    return null;
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
    logActivity('Complaint ${g.stage == 2 ? 'resolved' : 'in progress'}: ${g.title}', 'Requests');
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
  void addAnnouncement(String title, String body, String type, bool sms, {List<String>? units, bool draft = false}) {
    announcements.insert(
        0,
        Announcement(nextId(), title, body.isEmpty ? '—' : body, shortDate(DateTime.now()),
            draft ? 'Draft' : 'Published', type, sms, units: units));
    logActivity(draft ? 'Announcement saved as draft: $title' : 'Announcement published: $title', 'Announcements');
    _n();
  }

  /// Compose window: keeps what was typed as a draft (like Gmail). Returns the draft's id (0 when there was nothing to keep).
  /// Pass the id of an earlier save to update the same draft.
  int saveAnnouncementDraft(int id, String title, String body, String type) {
    final t = title.trim(), b = body.trim();
    if (t.isEmpty && b.isEmpty) return id;
    if (id != 0) {
      final i = announcements.indexWhere((a) => a.id == id);
      if (i >= 0) {
        final a = announcements[i];
        a.title = t.isEmpty ? '(no title)' : t;
        a.body = b.isEmpty ? '—' : b;
        a.type = type;
        _n();
        return id;
      }
    }
    final n = nextId();
    announcements.insert(0, Announcement(n, t.isEmpty ? '(no title)' : t, b.isEmpty ? '—' : b, shortDate(DateTime.now()), 'Draft', type, false));
    logActivity('Announcement saved as draft: ${t.isEmpty ? '(no title)' : t}', 'Announcements');
    _n();
    return n;
  }

  /// Publishes a draft (or updates a published announcement) from the compose window.
  void publishAnnouncementFrom(int id, String title, String body, String type, {bool sms = false}) {
    final i = announcements.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final a = announcements[i];
    a.title = title.trim();
    a.body = body.trim().isEmpty ? '—' : body.trim();
    a.type = type;
    a.sms = sms;
    if (a.status != 'Published') {
      a.status = 'Published';
      a.date = shortDate(DateTime.now());
      logActivity('Announcement published: ${a.title}', 'Announcements');
    }
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
