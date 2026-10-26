// DEMO ONLY: maintenance management (preventive schedule, equipment list, maintenance staff, repair assignment).
//
// Nothing here is saved to the database. The screens that use it are only shown in the demo build
// (`--dart-define=DEMO=true`), and the data lives in memory until the page is closed.

import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'expenses.dart';

/// A person who does maintenance work.
class StaffMember {
  final int id;
  String name, role, phone;
  StaffMember(this.id, this.name, this.role, this.phone);
}

/// A piece of equipment of the building.
class Equipment {
  final int id;
  String name, category, location, status; // status: Working, Needs repair, Under maintenance
  DateTime? lastService;
  String facility; // name of the bookable facility it belongs to, or ''
  bool closes; // when not working, the facility cannot be booked
  String vendor;
  DateTime? warranty; // warranty ends
  Equipment(this.id, this.name, this.category, this.location, this.status, this.lastService,
      {this.facility = '', this.closes = false, this.vendor = '', this.warranty});
}

/// Names of the two built-in task types. The administrator can add more (see MaintenanceState.addKind).
const String kindRoutine = 'Routine', kindCompliance = 'Compliance';
const String kindRoutineLabel = 'Routine maintenance', kindComplianceLabel = 'Permit, certificate or test';

/// The text shown for a task type ('Compliance' is shown as 'Permit, certificate or test').
String kindLabel(String k) => k == kindRoutine ? kindRoutineLabel : (k == kindCompliance ? kindComplianceLabel : k);

/// The stored type for a label picked in the form (a custom type is stored as typed).
String kindFromLabel(String l) => l == kindRoutineLabel ? kindRoutine : (l == kindComplianceLabel ? kindCompliance : l);

/// A routine job that repeats, such as 'Generator test run' every 2 weeks.
class MTask {
  final int id;
  String title, every, kind; // kind: Routine or Compliance (permits, certificates, tests)
  int days;
  int? equipId;
  String equipLabel; // shown when the task has no equipment record (for example the water tank)
  DateTime due;
  int? staffId;
  DateTime? lastDone;
  MTask(this.id, this.title, this.every, this.days, this.due,
      {this.kind = 'Routine', this.equipId, this.equipLabel = '', this.staffId, this.lastDone});
}

/// Who repairs a grievance, by when, and what for.
class Assignment {
  int? staffId;
  DateTime? target;
  int? equipId;
  String notes, priority, completion;
  DateTime? resolvedOn;
  num cost;
  Assignment({this.staffId, this.target, this.equipId, this.notes = '', this.priority = 'Normal', this.completion = '', this.resolvedOn, this.cost = 0});
}

/// Money spent on a repair or a maintenance job. It is also added to the Expenses list.
class MaintCost {
  final int id;
  final DateTime date;
  final String item;
  final num amount;
  final int? equipId;
  const MaintCost(this.id, this.date, this.item, this.amount, this.equipId);
}

const List<String> repairPriorities = ['Urgent', 'High', 'Normal', 'Low'];

const List<(String, int)> maintFrequencies = [
  ('Weekly', 7),
  ('Every 2 weeks', 14),
  ('Monthly', 30),
  ('Every 3 months', 90),
  ('Every 6 months', 180),
  ('Yearly', 365),
];
const List<String> equipmentStatuses = ['Working', 'Needs repair', 'Under maintenance'];
const List<String> equipmentCategories = [
  'Elevator', 'Plumbing', 'Electrical', 'Fire safety', 'Pool', 'Gym', 'Air conditioning', 'Security', 'Other'
];

DateTime _today() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, 12);
}

/// Whole days from today to [d] (negative when [d] is in the past).
int daysFromToday(DateTime d) =>
    DateTime(d.year, d.month, d.day, 12).difference(_today()).inDays;

DateTime inDays(int n) => DateTime(_today().year, _today().month, _today().day + n, 12);

String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

/// The words for the due date of a task, and how serious it is: 0 fine, 1 soon, 2 overdue.
(String, int) taskState(MTask t) {
  final n = daysFromToday(t.due);
  if (n < 0) return ('Overdue by ${_plural(-n, 'day')}', 2);
  if (n == 0) return ('Due today', 1);
  if (n <= 7) return ('Due in ${_plural(n, 'day')}', 1);
  return ('Scheduled', 0);
}

/// Holds the maintenance data of the demo. Use the single [maint] object.
/// One notice the administrator sent to residents (shown under Recent notices).
class NoticeLog {
  final String title;
  final DateTime at;
  final int count, textCount, noPhone;
  final bool everyone, text;
  const NoticeLog(this.title, this.at, this.count, {this.everyone = false, this.text = false, this.textCount = 0, this.noPhone = 0});
}

class MaintenanceState extends ChangeNotifier {
  final List<StaffMember> staff = [];
  final List<Equipment> equipment = [];
  final List<MTask> tasks = [];
  final Map<int, Assignment> repairs = {}; // grievance id -> assignment
  final List<MaintCost> costs = [];
  final List<NoticeLog> notices = [];
  int _seq = 1000;
  int _next() => ++_seq;

  void clear() {
    staff.clear();
    equipment.clear();
    tasks.clear();
    repairs.clear();
    costs.clear();
    notices.clear();
    notifyListeners();
  }

  void changed() => notifyListeners();

  // ---- lookups
  StaffMember? staffById(int? id) {
    for (final s in staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  Equipment? equipById(int? id) {
    for (final e in equipment) {
      if (e.id == id) return e;
    }
    return null;
  }

  StaffMember? staffByName(String name) {
    for (final s in staff) {
      if (s.name == name) return s;
    }
    return null;
  }

  Equipment? equipByName(String name) {
    for (final e in equipment) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// The name of the staff member on a task.
  String assigneeOf(MTask t) => staffById(t.staffId)?.name ?? '';

  /// The equipment name shown for a task.
  String equipOf(MTask t) => equipById(t.equipId)?.name ?? t.equipLabel;

  /// The equipment that is keeping a facility closed to booking right now, or null.
  Equipment? closureOf(String facility) {
    for (final e in equipment) {
      if (e.facility == facility && e.closes && e.status != 'Working') return e;
    }
    return null;
  }

  List<Equipment> get closures => equipment.where((e) => e.facility.isNotEmpty && e.closes && e.status != 'Working').toList();

  num spentOn(int equipId) => costs.where((c) => c.equipId == equipId).fold<num>(0, (a, c) => a + c.amount);
  num spentIn(int year, [int? month]) => costs
      .where((c) => c.date.year == year && (month == null || c.date.month == month))
      .fold<num>(0, (a, c) => a + c.amount);

  /// Average days from a report to its repair, over repairs that are finished, and how many there are.
  (double?, int) get repairTime {
    final done = <double>[];
    for (final g in appRef?.grievances ?? const <Grievance>[]) {
      final a = repairs[g.id];
      if (g.stage >= 2 && a?.resolvedOn != null) {
        final days = a!.resolvedOn!.difference(DateTime.fromMillisecondsSinceEpoch(g.id)).inHours / 24;
        done.add(days < 0 ? 0.0 : days);
      }
    }
    if (done.isEmpty) return (null, 0);
    return (done.reduce((a, b) => a + b) / done.length, done.length);
  }

  /// Set when the demo is seeded, so the totals above can read the grievances.
  AppState? appRef;

  /// Adds a cost to the maintenance record and to the Expenses list of the administrator.
  void _recordCost(AppState app, String item, String category, num amount, Equipment? equip, String payee, DateTime date) {
    if (amount <= 0) return;
    final id = DateTime.now().microsecondsSinceEpoch;
    costs.add(MaintCost(id, date, item, amount, equip?.id));
    app.expenses.add(Expense(
      id: id,
      item: item,
      category: category,
      area: _areaFor(equip),
      payee: payee.isEmpty ? 'Maintenance' : payee,
      receiptNo: '',
      note: '',
      qty: 1,
      unitPrice: amount,
      date: date,
    ));
    app.expenses.sort((x, y) => y.date.compareTo(x.date));
  }

  String _areaFor(Equipment? e) {
    switch (e?.category) {
      case 'Elevator':
        return 'Elevators';
      case 'Pool':
        return 'Swimming pool';
      case 'Security':
        return 'Offices and security';
      default:
        return 'Lobby and common areas';
    }
  }

  /// Tasks, soonest first.
  List<MTask> get sortedTasks => [...tasks]..sort((a, b) => a.due.compareTo(b.due));

  int get overdueCount => tasks.where((t) => daysFromToday(t.due) < 0).length;
  int get dueThisWeekCount => tasks.where((t) {
        final n = daysFromToday(t.due);
        return n >= 0 && n <= 7;
      }).length;
  int get equipmentToFix => equipment.where((e) => e.status != 'Working').length;

  /// Open (not resolved) grievances that point to a piece of equipment.
  int openRepairsFor(AppState app, int equipId) => app.grievances
      .where((g) => g.stage < 2 && repairs[g.id]?.equipId == equipId)
      .length;

  // ---- tasks
  void markDone(MTask t, AppState app, {num cost = 0}) {
    final now = _today();
    t.lastDone = now;
    t.due = DateTime(now.year, now.month, now.day + t.days, 12);
    final e = equipById(t.equipId);
    if (e != null) e.lastService = now;
    _recordCost(app, 'Maintenance: ${t.title}', 'Janitorial and maintenance', cost, e, assigneeOf(t), now);
    app.logActivity('Maintenance done: ${t.title}${cost > 0 ? ' (${peso(cost)})' : ''}', 'Maintenance');
    app.changed();
    notifyListeners();
  }

  /// Posts a notice to the chosen residents (or everyone) and keeps a record of who it reached.
  /// [units] lists the units that can read it; empty means every resident.
  void sendNotice(AppState app, String title, String body,
      {required List<String> units, required int count, required bool text, required int textCount, required int noPhone, String type = 'Maintenance'}) {
    app.addAnnouncement(title, body, type, text, units: units);
    notices.insert(0, NoticeLog(title, DateTime.now(), count, everyone: units.isEmpty, text: text, textCount: textCount, noPhone: noPhone));
    notifyListeners();
  }

  void saveTask(AppState app,
      {MTask? existing, required String title, required String kind, required String every, required DateTime? due, required Equipment? equip, required StaffMember? who}) {
    final days = maintFrequencies.firstWhere((f) => f.$1 == every, orElse: () => maintFrequencies[2]).$2;
    if (existing == null) {
      tasks.add(MTask(_next(), title, every, days, due ?? _today(), kind: kind, equipId: equip?.id, staffId: who?.id));
      app.logActivity('Maintenance task added: $title', 'Maintenance');
    } else {
      existing
        ..title = title
        ..kind = kind
        ..every = every
        ..days = days
        ..equipId = equip?.id
        ..staffId = who?.id;
      if (equip != null) existing.equipLabel = '';
      if (due != null) existing.due = due;
      app.logActivity('Maintenance task updated: $title', 'Maintenance');
    }
    notifyListeners();
  }

  // ---- task types

  /// Types the administrator created, in the order they were added.
  final List<String> customKinds = [];

  /// Every type a task can have, as stored: the two built-in ones and the custom ones.
  List<String> get kinds => [kindRoutine, kindCompliance, ...customKinds];

  /// Adds a task type and returns the stored name (the existing one when it is already there), or null for an empty name.
  String? addKind(String raw) {
    var name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    if (name.length > 30) name = name.substring(0, 30).trim();
    for (final k in kinds) {
      if (k.toLowerCase() == name.toLowerCase() || kindLabel(k).toLowerCase() == name.toLowerCase()) return k;
    }
    customKinds.add(name);
    notifyListeners();
    return name;
  }

  /// Renames a custom type and every task that uses it. Returns an error text (or null when it worked) and the final name.
  (String?, String) renameKind(String from, String raw, AppState app) {
    if (!customKinds.contains(from)) return ('Only types you created can be renamed.', from);
    var name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return ('Enter the type name.', from);
    if (name.length > 30) name = name.substring(0, 30).trim();
    if (name != from) {
      for (final k in kinds) {
        if (k != from && (k.toLowerCase() == name.toLowerCase() || kindLabel(k).toLowerCase() == name.toLowerCase())) {
          return ('There is already a type with that name.', from);
        }
      }
      customKinds[customKinds.indexOf(from)] = name;
      for (final t in tasks) {
        if (t.kind == from) t.kind = name;
      }
      app.logActivity('Task type renamed: $from to $name', 'Maintenance');
      notifyListeners();
    }
    return (null, name);
  }

  /// Removes a custom type. Its tasks become routine maintenance.
  void deleteKind(String k, AppState app) {
    if (!customKinds.remove(k)) return;
    for (final t in tasks) {
      if (t.kind == k) t.kind = kindRoutine;
    }
    app.logActivity('Task type deleted: $k', 'Maintenance');
    notifyListeners();
  }

  void deleteTask(MTask t, AppState app) {
    tasks.remove(t);
    app.logActivity('Deleted task: ${t.title}', 'Maintenance');
    notifyListeners();
  }

  // ---- equipment
  void saveEquipment(AppState app,
      {Equipment? existing, required String name, required String category, required String location, required String status,
      required String facility, required bool closes, required String vendor, required DateTime? warranty}) {
    if (existing == null) {
      equipment.add(Equipment(_next(), name, category, location, status, null, facility: facility, closes: closes, vendor: vendor, warranty: warranty));
      app.logActivity('Equipment added: $name', 'Maintenance');
    } else {
      existing
        ..name = name
        ..category = category
        ..location = location
        ..status = status
        ..facility = facility
        ..closes = closes
        ..vendor = vendor
        ..warranty = warranty;
      app.logActivity('Equipment updated: $name', 'Maintenance');
    }
    notifyListeners();
  }

  /// Returns a message if the equipment cannot be deleted yet, otherwise deletes it and returns null.
  String? deleteEquipment(Equipment e, AppState app) {
    final linked = tasks.where((t) => t.equipId == e.id).length + openRepairsFor(app, e.id);
    if (linked > 0) return '${e.name} is still used by ${_plural(linked, 'linked item')}. Remove or finish those first.';
    equipment.remove(e);
    app.logActivity('Deleted equipment: ${e.name}', 'Maintenance');
    notifyListeners();
    return null;
  }

  // ---- staff
  void saveStaff(AppState app, {StaffMember? existing, required String name, required String role, required String phone}) {
    if (existing == null) {
      staff.add(StaffMember(_next(), name, role.isEmpty ? 'Maintenance' : role, phone));
      app.logActivity('Staff added: $name', 'Maintenance');
    } else {
      existing
        ..name = name
        ..role = role.isEmpty ? 'Maintenance' : role
        ..phone = phone;
      app.logActivity('Staff updated: $name', 'Maintenance');
    }
    notifyListeners();
  }

  int openWorkOf(StaffMember s, AppState app) =>
      app.grievances.where((g) => g.stage < 2 && repairs[g.id]?.staffId == s.id).length +
      tasks.where((t) => t.staffId == s.id).length;

  String? deleteStaff(StaffMember s, AppState app) {
    final n = openWorkOf(s, app);
    if (n > 0) return '${s.name} still has ${_plural(n, 'assignment')}. Reassign them first.';
    staff.remove(s);
    app.logActivity('Deleted staff: ${s.name}', 'Maintenance');
    notifyListeners();
    return null;
  }

  // ---- repair assignment on grievances
  void assign(AppState app, Grievance g,
      {required StaffMember? who, required DateTime? target, required Equipment? equip, required String notes, String priority = 'Normal'}) {
    final a = repairs[g.id] ?? Assignment();
    a.priority = priority;
    if (who != null) {
      a.staffId = who.id;
      if (target != null) a.target = target;
      a.target ??= inDays(3);
      if (g.stage < 1) g.stage = 1;
    } else {
      a.staffId = null;
      a.target = null;
    }
    a.equipId = equip?.id;
    a.notes = notes;
    repairs[g.id] = a;
    if (who != null && equip != null && equip.status == 'Working') equip.status = 'Under maintenance';
    app.logActivity(
        who != null ? 'Repair assigned to ${who.name}: ${g.title}' : 'Repair unassigned: ${g.title}', 'Requests');
    notifyListeners();
  }

  /// Moves a grievance to resolved, records what was done and what it cost, and puts its equipment back to Working.
  void resolve(AppState app, Grievance g, {String note = '', num cost = 0}) {
    g.stage = 2;
    final a = repairs[g.id] ?? Assignment();
    final now = _today();
    a.resolvedOn = now;
    a.completion = note;
    a.cost = cost;
    repairs[g.id] = a;
    final e = equipById(a.equipId);
    if (e != null) {
      e.status = 'Working';
      e.lastService = now;
    }
    _recordCost(app, 'Repair: ${g.title}', 'Repairs and improvements', cost, e, staffById(a.staffId)?.name ?? '', now);
    app.logActivity('Complaint resolved: ${g.title}${cost > 0 ? ' (${peso(cost)})' : ''}', 'Requests');
    app.changed();
    notifyListeners();
  }

  /// Fills the demo with sample staff, equipment, tasks and repair assignments.
  /// Residents only see the schedule and the assignments on their own grievances (the screens enforce that).
  void seedDemo(AppState app) {
    clear();
    final s = <StaffMember>[
      StaffMember(1, 'Mang Ben Ocampo', 'Plumber', '0917 555 0141'),
      StaffMember(2, 'Kuya Rey Santos', 'Electrician', '0917 555 0142'),
      StaffMember(3, 'Aling Nena Cruz', 'Housekeeping supervisor', '0917 555 0143'),
      StaffMember(4, 'Dante Villanueva', 'Building engineer', '0917 555 0144'),
      StaffMember(5, 'Joel Mercado', 'Pool and gym attendant', '0917 555 0145'),
      StaffMember(6, 'Ramon Dela Cruz', 'Head of security', '0917 555 0146'),
    ];
    final e = <Equipment>[
      Equipment(1, 'Elevator A', 'Elevator', 'Tower lobby', 'Needs repair', inDays(-75)),
      Equipment(2, 'Elevator B', 'Elevator', 'Tower lobby', 'Working', inDays(-26)),
      Equipment(3, 'Water pump set', 'Plumbing', 'Basement pump room', 'Working', inDays(-48)),
      Equipment(4, 'Standby generator', 'Electrical', 'Basement', 'Working', inDays(-16)),
      Equipment(5, 'Fire alarm panel', 'Fire safety', 'Ground floor lobby', 'Working', inDays(-21)),
      Equipment(6, 'Fire extinguishers', 'Fire safety', 'Every floor', 'Working', inDays(-69)),
      Equipment(7, 'Pool filtration pump', 'Pool', 'Pool deck', 'Working', inDays(-5)),
      Equipment(8, 'Treadmill 2', 'Gym', 'Gym', 'Needs repair', inDays(-40)),
      Equipment(9, 'Lobby aircon', 'Air conditioning', 'Lobby', 'Working', inDays(-29)),
      Equipment(10, 'Parking gate sensor', 'Security', 'Motor parking gate', 'Under maintenance', inDays(-12)),
      Equipment(11, 'Gym shower water heater', 'Plumbing', 'Gym', 'Needs repair', inDays(-90)),
      Equipment(12, 'CCTV system', 'Security', 'Security office', 'Working', inDays(-3)),
    ];
    // title, equipment id, every, days, due in days, staff id, last done days ago
    final t = <(String, int, String, int, int, int, int)>[
      ('Elevator inspection and lubrication', 1, 'Monthly', 30, 5, 4, 26),
      ('Fire extinguisher pressure check', 6, 'Every 3 months', 90, 21, 6, 69),
      ('Generator test run', 4, 'Every 2 weeks', 14, -2, 2, 16),
      ('Water pump servicing', 3, 'Every 3 months', 90, 12, 1, 78),
      ('Pool filter cleaning', 7, 'Weekly', 7, 2, 5, 5),
      ('Fire alarm panel test', 5, 'Monthly', 30, 9, 2, 21),
      ('Lobby aircon filter cleaning', 9, 'Monthly', 30, 0, 4, 30),
      ('Water tank cleaning', 0, 'Every 6 months', 180, 40, 1, 140),
      ('CCTV camera check', 12, 'Weekly', 7, 4, 6, 3),
      ('Gym equipment inspection', 8, 'Every 2 weeks', 14, 6, 5, 8),
    ];
    e.add(Equipment(13, 'Billiard table', 'Other', 'Game Room', 'Under maintenance', inDays(-200)));
    // facility, closes it, vendor, warranty ends in days
    final extra = <int, (String, bool, String, int?)>{
      1: ('', false, 'LiftCare Services', -60), 2: ('', false, 'LiftCare Services', 20), 3: ('', false, 'AquaFlow Trading', 300),
      4: ('', false, 'PowerPro Gensets', 200), 5: ('', false, 'SafeGuard Fire Systems', 400), 6: ('', false, 'SafeGuard Fire Systems', null),
      7: ('Swimming Pool', true, 'AquaFlow Trading', 150), 8: ('', false, 'FitGear Supply', -30), 9: ('', false, 'CoolAir Services', 90),
      10: ('', false, 'SecureTech', 10), 11: ('', false, 'AquaFlow Trading', -200), 12: ('', false, 'SecureTech', 260),
      13: ('', false, 'FitGear Supply', null),
    };
    for (final x in e) {
      final f = extra[x.id];
      if (f == null) continue;
      x
        ..facility = f.$1
        ..closes = f.$2
        ..vendor = f.$3
        ..warranty = f.$4 == null ? null : inDays(f.$4!);
    }
    staff.addAll(s);
    equipment.addAll(e);
    appRef = app;
    app.closedForMaintenance = (name) => closureOf(name) != null;
    var n = 0;
    for (final x in t) {
      tasks.add(MTask(100 + (++n), x.$1, x.$3, x.$4, inDays(x.$5),
          equipId: x.$2 == 0 ? null : x.$2,
          equipLabel: x.$2 == 0 ? 'Rooftop water tank' : '',
          staffId: x.$6,
          lastDone: inDays(-x.$7)));
    }
    // compliance renewals (permits, certificates, tests)
    final comp = <(String, int, String, String, int, int, int, int)>[
      ('Fire safety inspection certificate renewal', 0, 'Whole building', 'Yearly', 365, 60, 6, 305),
      ('Elevator operating certificate renewal', 2, '', 'Yearly', 365, 95, 4, 270),
      ('Drinking water quality test', 0, 'Water supply', 'Every 6 months', 180, 20, 1, 160),
    ];
    for (final x in comp) {
      tasks.add(MTask(100 + (++n), x.$1, x.$4, x.$5, inDays(x.$6),
          kind: 'Compliance', equipId: x.$2 == 0 ? null : x.$2, equipLabel: x.$3, staffId: x.$7, lastDone: inDays(-x.$8)));
    }
    // Repair assignments, matched by the grievance title.
    // title, stage, staff id, target in days, equipment id (0 = none), note, priority, resolved days ago (0 = not yet), cost, what was done
    final r = <(String, int, int, int, int, String, String, int, int, String)>[
      ('Leaking pipe in the hallway', 1, 1, 2, 0, 'Checking the pipe above the ceiling near Elevator A.', 'High', 0, 0, ''),
      ('Broken hallway light', 2, 2, -1, 0, 'Replaced the lamp and the starter.', 'Normal', 1, 450, 'Lamp and starter replaced.'),
      ('Parking gate sensor not working', 1, 2, 3, 10, 'Waiting for a replacement sensor from the supplier.', 'High', 0, 0, ''),
      ('Treadmill in the gym is broken', 1, 5, 5, 8, 'Motor belt ordered. Treadmill 2 is closed until it is fixed.', 'Normal', 0, 0, ''),
      ('Elevator A makes a grinding sound', 1, 4, 1, 1, 'Elevator technician is scheduled to visit.', 'Urgent', 0, 0, ''),
      ('Pool tiles are slippery', 2, 5, -4, 0, 'Applied anti-slip coating on the shallow-end steps.', 'Normal', 5, 1800, 'Anti-slip coating applied.'),
      ('No hot water in the gym shower', 1, 1, 4, 11, 'Heating element must be replaced.', 'Normal', 0, 0, ''),
      ('Water pressure is low', 2, 1, -3, 3, 'Cleaned the pressure tank and adjusted the pump.', 'High', 4, 3500, 'Pump pressure restored.'),
    ];
    for (final x in r) {
      final matches = app.grievances.where((g) => g.title == x.$1);
      if (matches.isEmpty) continue;
      final g = matches.first;
      g.stage = x.$2;
      final a = Assignment(
        staffId: x.$3,
        target: inDays(x.$4),
        equipId: x.$5 == 0 ? null : x.$5,
        notes: x.$6,
        priority: x.$7,
        completion: x.$10,
        resolvedOn: x.$8 == 0 ? null : inDays(-x.$8),
        cost: x.$9,
      );
      repairs[g.id] = a;
      if (x.$2 == 2 && x.$9 > 0) _recordCost(app, 'Repair: ${g.title}', 'Repairs and improvements', x.$9, equipById(a.equipId), staffById(x.$3)?.name ?? '', inDays(-x.$8));
    }
    notifyListeners();
  }
}

/// The single maintenance store used by the demo screens.
final MaintenanceState maint = MaintenanceState();
