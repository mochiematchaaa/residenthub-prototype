// The lists the administrator can import from an Excel or CSV file, and what each row becomes.
// Used by import_sheet.dart. A row that cannot be added returns a short reason, and the import goes on with the next row.

import '../../core/core.dart';
import '../../services/demo.dart';
import '../../services/session.dart';

/// One column the importer looks for in the file.
class ImportCol {
  final String key, label;
  final bool req;
  final List<String> al; // other names the column may have in the file
  const ImportCol(this.key, this.label, this.al, {this.req = false});
}

/// What a running import collects besides the rows that were added (for example temporary passwords).
class ImportRun {
  final List<List<String>> passwords = [];
}

/// One importable list.
class ImportSpec {
  final String id, label, note;
  final List<ImportCol> cols;
  final List<List<String>> sample;

  /// Adds one row. Returns a reason when the row is skipped, or null when it was added.
  final Future<String?> Function(Map<String, String> v, ImportRun run) add;
  const ImportSpec(this.id, this.label, this.cols, this.sample, this.add, {this.note = ''});
}

// ------------------------------------------------------------------ helpers
String _nk(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

double? _num(String s) => double.tryParse(s.replaceAll(RegExp(r'[₱,\s]|php', caseSensitive: false), ''));

String _fixPhone(String s) {
  final t = s.trim();
  final d = t.replaceAll(RegExp(r'\D'), '');
  if (RegExp(r'^9\d{9}$').hasMatch(d)) return '0$d';
  return t;
}

/// A date typed in many ways, or an Excel date number.
DateTime? importDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^\d{4,6}(\.\d+)?$').hasMatch(s)) {
    final n = double.parse(s);
    if (n > 20000 && n < 90000) {
      final u = DateTime.utc(1899, 12, 30).add(Duration(days: n.floor()));
      return DateTime(u.year, u.month, u.day);
    }
  }
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$').firstMatch(s);
  if (m != null) {
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return DateTime(y, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
  return parseShortDate(s) ?? DateTime.tryParse(s);
}

/// "HH:MM" from 6:00, 6 PM, 6:30 pm or an Excel time fraction. Null when not understood.
String? _clock(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  String two(int n) => n < 10 ? '0$n' : '$n';
  if (RegExp(r'^0?\.\d+$').hasMatch(s)) {
    final mins = (double.parse(s.startsWith('.') ? '0$s' : s) * 1440).round();
    return '${two((mins ~/ 60) % 24)}:${two(mins % 60)}';
  }
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(s);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final mi = m.group(2) == null ? 0 : int.parse(m.group(2)!);
  if (m.group(3) == 'pm' && h < 12) h += 12;
  if (m.group(3) == 'am' && h == 12) h = 0;
  if (h > 23 || mi > 59) return null;
  return '${two(h)}:${two(mi)}';
}

String _pick(List<String> options, String v, String fallback) {
  final t = _nk(v);
  if (t.isEmpty) return fallback;
  for (final o in options) {
    if (_nk(o) == t) return o;
  }
  for (final o in options) {
    if (_nk(o).contains(t) || t.contains(_nk(o))) return o;
  }
  return fallback;
}

String _unitKey(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');

Unit? _unitOf(String t) {
  final k = _unitKey(t);
  if (k.isEmpty) return null;
  for (final u in app.units) {
    if (_unitKey(u.unit) == k) return u;
  }
  return null;
}

String _dateText(DateTime d) => shortDate(d);

// ------------------------------------------------------------------ the lists
final Map<String, ImportSpec> importSpecs = {
  'units': ImportSpec(
    'units',
    'units',
    const [
      ImportCol('unit', 'Unit', ['unit', 'unit no', 'unit number', 'unit name', 'room', 'room no'], req: true),
      ImportCol('name', 'Household or owner', ['household', 'owner', 'resident', 'owner name', 'name', 'full name', 'family']),
      ImportCol('type', 'Owner or Tenant', ['occupancy', 'owner or tenant', 'ownership', 'type']),
      ImportCol('status', 'Occupied or Vacant', ['status', 'occupied', 'vacancy']),
      ImportCol('contact', 'Contact number', ['contact', 'contact number', 'mobile', 'mobile number', 'phone', 'cellphone']),
    ],
    const [
      ['Unit 12A', 'Reyes Family', 'Owner', 'Occupied', '0917 555 0112'],
    ],
    (v, run) async {
      final type = RegExp('tenant', caseSensitive: false).hasMatch(v['type']!) ? 'Tenant' : 'Owner';
      final err = app.addUnit(v['unit']!, v['name']!, type, _fixPhone(v['contact']!));
      if (err != null) return err.contains('already exists') ? 'Already on record' : err;
      if (RegExp('vacant', caseSensitive: false).hasMatch(v['status']!)) {
        final u = _unitOf(v['unit']!);
        if (u != null) {
          u.status = 'Vacant';
          app.changed();
        }
      }
      return null;
    },
  ),
  'accounts': ImportSpec(
    'accounts',
    'resident accounts',
    const [
      ImportCol('name', 'Full name', ['full name', 'name', 'resident', 'resident name'], req: true),
      ImportCol('email', 'Email address', ['email', 'email address', 'e-mail', 'gmail'], req: true),
      ImportCol('phone', 'Mobile number', ['mobile', 'mobile number', 'phone', 'contact', 'contact number', 'cellphone']),
      ImportCol('unit', 'Unit', ['unit', 'unit no', 'unit number', 'unit name', 'room'], req: true),
    ],
    const [
      ['Ana Reyes', 'ana.reyes@gmail.com', '0917 555 0112', 'Unit 12A'],
    ],
    (v, run) async {
      if (v['name']!.isEmpty) return 'No name';
      final email = v['email']!.trim();
      if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return 'Email is not valid';
      if (app.trusted.any((a) => a.email.toLowerCase() == email.toLowerCase())) return 'Email already has an account';
      final ph = _fixPhone(v['phone']!);
      if (ph.isNotEmpty && !AppState.validMobile(AppState.normalizePhone(ph))) return 'Mobile number is not valid';
      final u = _unitOf(v['unit']!);
      if (u == null) return 'Unit is not on record yet (import the units first)';
      if (kDemo) {
        final now = DateTime.now();
        app.setAccounts([
          ...app.trusted,
          Account('imp-${now.microsecondsSinceEpoch}', v['name']!.trim(), email, ph, u.unit, 'Resident', shortDate(now),
              createdAt: now, updatedAt: now, lastChange: 'New account', history: [AccountChange(now, 'Account created')]),
        ]);
        run.passwords.add([v['name']!.trim(), u.unit, email, 'Temp#Pass1x']);
        return null;
      }
      final r = await session.createResident(v['name']!, email, ph, u.unit);
      if (r.error != null) return r.error;
      run.passwords.add([v['name']!.trim(), u.unit, email, r.password ?? '']);
      return null;
    },
    note: 'Each account gets a temporary password. Download the list when the import is done and give each password to the resident privately.',
  ),
  'charges': ImportSpec(
    'charges',
    'charges',
    const [
      ImportCol('unit', 'Unit', ['unit', 'unit no', 'unit number', 'room'], req: true),
      ImportCol('amount', 'Amount (₱)', ['amount', 'charge', 'fee', 'balance', 'total', 'price'], req: true),
      ImportCol('note', 'Description', ['description', 'note', 'particulars', 'for', 'details']),
      ImportCol('due', 'Due date', ['due date', 'due', 'deadline', 'pay by']),
    ],
    const [
      ['Unit 12A', '1500', 'Facility damage fee', 'Nov 15, 2026'],
    ],
    (v, run) async {
      DateTime? d;
      if (v['due']!.isNotEmpty) {
        d = importDate(v['due']!);
        if (d == null) return 'Due date is not understood';
      }
      final note = v['note']!.isEmpty ? 'Charge' : v['note']!;
      final before = app.dues.length;
      final err = app.addCharge(v['unit']!, v['amount']!, note);
      if (err != null) return err.startsWith('No unit') ? 'Unit is not on record' : err;
      if (d != null && app.dues.length > before) app.dues.last.dueDate = _dateText(d);
      app.changed();
      return null;
    },
  ),
  'payments': ImportSpec(
    'payments',
    'payments received',
    const [
      ImportCol('unit', 'Unit', ['unit', 'unit no', 'unit number', 'room'], req: true),
      ImportCol('amount', 'Amount paid (₱, optional)', ['amount', 'amount paid', 'paid', 'payment']),
      ImportCol('method', 'Paid through (optional)', ['method', 'paid through', 'mode', 'payment method', 'channel']),
      ImportCol('reference', 'Reference no. (optional)', ['reference', 'reference no', 'ref', 'ref no', 'transaction']),
    ],
    const [
      ['Unit 12A', '1500', 'GCash', 'GC-123456'],
    ],
    (v, run) async {
      final u = _unitOf(v['unit']!);
      if (u == null) return 'Unit is not on record';
      final a = v['amount']!.isEmpty ? null : _num(v['amount']!);
      if (v['amount']!.isNotEmpty && (a == null || a <= 0)) return 'Amount is not a number above zero';
      var dues = app.dues.where((d) => d.unit == u.unit && !d.paid).toList();
      if (a != null) {
        final exact = dues.where((d) => d.amount == a).toList();
        if (exact.isNotEmpty) dues = exact;
      }
      if (dues.isEmpty) return 'No unpaid charge for this unit';
      app.payDue(dues.first.id, method: v['method']!.isEmpty ? AppState.officePay : v['method']!, reference: v['reference']!);
      return null;
    },
    note: 'Each unit in the file has its unpaid charge marked as paid and a receipt is made. Use it for a list from the bank, GCash or the cashier.',
  ),
  'usage': ImportSpec(
    'usage',
    'unit status',
    const [
      ImportCol('unit', 'Unit', ['unit', 'unit no', 'unit number', 'room'], req: true),
      ImportCol('use', 'How the unit is used', ['status', 'usage', 'use', 'unit status', 'how used', 'occupancy', 'type'], req: true),
      ImportCol('note', 'Note (tenant name, platform, business type)', ['note', 'notes', 'remarks', 'tenant', 'details', 'tenant name']),
    ],
    const [
      ['Unit 12A', 'Leased', 'Tenant: Ana Cruz'],
      ['Unit 12B', 'Short-term rental', 'Airbnb'],
    ],
    (v, run) async {
      final u = _unitOf(v['unit']!);
      if (u == null) return 'Unit is not on record';
      final t = v['use']!.toLowerCase();
      String key = '';
      if (RegExp('vacan').hasMatch(t)) {
        key = 'vacant';
      } else if (RegExp('short|airbnb|booking').hasMatch(t)) {
        key = 'shortterm';
      } else if (RegExp('busin|shop|office').hasMatch(t)) {
        key = 'business';
      } else if (RegExp('renov|repair|construct').hasMatch(t)) {
        key = 'renovation';
      } else if (RegExp('leas|tenant|rent').hasMatch(t)) {
        key = 'tenant';
      } else if (RegExp('own|occup').hasMatch(t)) {
        key = 'owner';
      }
      if (key.isEmpty) return 'Status not understood (use Owner, Leased, Short-term rental, Business, Renovation or Vacant)';
      app.adminSetStatus(u, key, v['note']!);
      return null;
    },
  ),
  'expenses': ImportSpec(
    'expenses',
    'expenses',
    const [
      ImportCol('item', 'What was bought', ['item', 'what was bought', 'description', 'particulars', 'purchase', 'expense'], req: true),
      ImportCol('price', 'Price of one (₱)', ['price', 'unit price', 'price of one', 'cost', 'amount', 'total'], req: true),
      ImportCol('qty', 'Quantity', ['quantity', 'qty', 'pcs']),
      ImportCol('date', 'Date', ['date', 'date purchased', 'purchase date']),
      ImportCol('category', 'Category', ['category', 'type']),
      ImportCol('area', 'For (area)', ['for', 'area', 'location']),
      ImportCol('payee', 'Store or supplier', ['store', 'supplier', 'payee', 'vendor', 'paid to']),
      ImportCol('receipt', 'Receipt no.', ['receipt', 'receipt no', 'or no', 'official receipt']),
      ImportCol('note', 'Note', ['note', 'remarks']),
    ],
    const [
      ['Floor wax, 5 L', '850', '2', 'Oct 20, 2026', 'Janitorial and maintenance', 'Lobby and common areas', 'ABC Hardware', 'OR-1234', ''],
    ],
    (v, run) async {
      DateTime d = DateTime.now();
      if (v['date']!.isNotEmpty) {
        final p = importDate(v['date']!);
        if (p == null) return 'Date is not understood';
        d = p;
      }
      final err = app.addExpense(
        category: _pick(expenseCategories, v['category']!, 'Other'),
        area: _pick(expenseAreas, v['area']!, expenseAreas.first),
        item: v['item']!,
        payee: v['payee']!.isEmpty ? 'Not stated' : v['payee']!,
        qtyRaw: v['qty']!,
        unitPriceRaw: v['price']!,
        receiptNo: v['receipt']!,
        note: v['note']!,
        dateRaw: _dateText(d),
      );
      return err;
    },
  ),
  'slots': ImportSpec(
    'slots',
    'motor parking slots',
    const [
      ImportCol('name', 'Slot name', ['slot', 'slot name', 'slot no', 'slot number', 'name', 'parking', 'number'], req: true),
    ],
    const [
      ['M-25'],
      ['M-26'],
    ],
    (v, run) async {
      final n = v['name']!.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (n.isEmpty) return 'No slot name';
      if (app.slots.any((s) => s.id.toLowerCase() == n.toLowerCase())) return 'Slot already exists';
      app.slots.add(ParkingSlot(n));
      app.slots.sort((a, b) => naturalCompare(a.id, b.id));
      app.logActivity('Motor parking slot added: $n', 'Parking');
      app.changed();
      return null;
    },
  ),
  'announcements': ImportSpec(
    'announcements',
    'announcements',
    const [
      ImportCol('title', 'Title', ['title', 'subject', 'announcement', 'heading'], req: true),
      ImportCol('body', 'Message', ['message', 'body', 'details', 'content', 'text']),
      ImportCol('type', 'Type (General, Maintenance, Warning, Emergency)', ['type', 'category', 'kind']),
    ],
    const [
      ['Water interruption', 'No water on Nov 3 from 9 AM to 12 NN for tank cleaning.', 'Maintenance'],
    ],
    (v, run) async {
      if (v['title']!.isEmpty) return 'No title';
      if (app.announcements.any((a) => a.title.toLowerCase() == v['title']!.toLowerCase())) return 'Same title already posted';
      app.addAnnouncement(v['title']!, v['body']!, _pick(const ['General', 'Maintenance', 'Warning', 'Emergency'], v['type']!, 'General'), false);
      return null;
    },
  ),
  'events': ImportSpec(
    'events',
    'events',
    const [
      ImportCol('title', 'Event title', ['title', 'event', 'event title', 'name', 'activity'], req: true),
      ImportCol('date', 'Date and time', ['date', 'date and time', 'when', 'schedule']),
      ImportCol('place', 'Venue', ['venue', 'place', 'where', 'location']),
    ],
    const [
      ['Christmas party', 'Dec 20, 2026 · 6:00 PM', 'Function hall'],
    ],
    (v, run) async {
      if (v['title']!.isEmpty) return 'No title';
      var when = v['date']!;
      if (RegExp(r'^\d{4,6}(\.\d+)?$').hasMatch(when)) {
        final d = importDate(when);
        if (d != null) when = _dateText(d);
      }
      if (app.events.any((e) => e.title.toLowerCase() == v['title']!.toLowerCase() && e.date == (when.isEmpty ? 'Date TBD' : when))) return 'Already on the list';
      app.addEvent(v['title']!, when, v['place']!);
      return null;
    },
  ),
  'facilities': ImportSpec(
    'facilities',
    'facilities',
    const [
      ImportCol('name', 'Facility name', ['facility', 'name', 'amenity', 'facility name'], req: true),
      ImportCol('open', 'Opens (e.g. 6:00 AM)', ['opens', 'open', 'opening', 'opening time', 'from'], req: true),
      ImportCol('close', 'Closes (e.g. 8:00 PM)', ['closes', 'close', 'closing', 'closing time', 'to', 'until'], req: true),
      ImportCol('mins', 'Minutes for one booking', ['minutes', 'mins', 'duration', 'booking length']),
      ImportCol('note', 'Note for residents', ['note', 'notes', 'remarks', 'fee']),
    ],
    const [
      ['Tennis court', '6:00 AM', '9:00 PM', '60', 'Bring your own racket'],
    ],
    (v, run) async {
      final o = _clock(v['open']!), c = _clock(v['close']!);
      if (o == null || c == null) return 'Opening or closing time is not understood';
      final mins = v['mins']!.isEmpty ? 60 : (_num(v['mins']!) ?? 0).round();
      return app.saveAmenity(null, v['name']!, o, c, mins, v['note']!);
    },
  ),
  'directory': ImportSpec(
    'directory',
    'directory contacts',
    const [
      ImportCol('name', 'Name or office', ['name', 'contact', 'office', 'department', 'who'], req: true),
      ImportCol('tel', 'Number', ['number', 'tel', 'telephone', 'phone', 'local', 'mobile', 'contact number'], req: true),
      ImportCol('note', 'Note (hours or what it is for)', ['note', 'notes', 'hours', 'details', 'description']),
    ],
    const [
      ['Clinic', 'Local 150', 'Mon to Fri, 9 AM to 4 PM'],
    ],
    (v, run) async {
      if (v['name']!.isEmpty) return 'No name';
      if (v['tel']!.isEmpty) return 'No number';
      if (directoryContacts.any((c) => c.name.toLowerCase() == v['name']!.toLowerCase() && _nk(c.tel) == _nk(v['tel']!))) return 'Already in the directory';
      app.setDirectory([...directoryContacts, ContactInfo(v['name']!, v['note']!, v['tel']!)], [for (final r in houseRules) [...r]]);
      return null;
    },
  ),
  'mtasks': ImportSpec(
    'mtasks',
    'maintenance tasks',
    const [
      ImportCol('title', 'Task', ['task', 'title', 'maintenance task', 'job', 'work', 'activity'], req: true),
      ImportCol('due', 'Next due date', ['next due', 'due', 'due date', 'date', 'schedule date'], req: true),
      ImportCol('every', 'How often', ['frequency', 'every', 'how often', 'interval', 'repeat']),
      ImportCol('kind', 'Type (Routine, Compliance or your own)', ['type', 'kind', 'category']),
      ImportCol('equip', 'Equipment', ['equipment', 'asset', 'machine', 'for']),
      ImportCol('who', 'Assigned to', ['assigned to', 'assigned', 'staff', 'person', 'technician', 'in charge']),
    ],
    const [
      ['Generator test run', 'Nov 10, 2026', 'Monthly', 'Routine', 'Standby generator', 'Dante Villanueva'],
    ],
    (v, run) async {
      if (v['title']!.isEmpty) return 'No task';
      if (v['due']!.isEmpty) return 'No due date';
      final d = importDate(v['due']!);
      if (d == null) return 'Due date is not understood';
      if (maint.tasks.any((t) => t.title.toLowerCase() == v['title']!.toLowerCase() && t.due.year == d.year && t.due.month == d.month && t.due.day == d.day)) {
        return 'Already scheduled';
      }
      final e = v['every']!.toLowerCase();
      String every = 'Monthly';
      if (RegExp('week').hasMatch(e)) {
        every = RegExp('2|two|bi|fort').hasMatch(e) ? 'Every 2 weeks' : 'Weekly';
      } else if (RegExp('quarter|3 ?month|three month').hasMatch(e)) {
        every = 'Every 3 months';
      } else if (RegExp('semi|6 ?month|six month|half').hasMatch(e)) {
        every = 'Every 6 months';
      } else if (RegExp('year|annual|12 ?month').hasMatch(e)) {
        every = 'Yearly';
      } else if (RegExp('daily|day').hasMatch(e)) {
        every = 'Weekly';
      }
      final k = v['kind']!.toLowerCase();
      var kind = kindRoutine;
      if (RegExp('compliance|permit|certificate|test|inspection').hasMatch(k) && !k.contains('routine')) {
        kind = kindCompliance;
      } else if (k.isNotEmpty && !RegExp('routine|regular|preventive').hasMatch(k)) {
        kind = maint.addKind(v['kind']!) ?? kindRoutine;
      }
      Equipment? equip;
      for (final x in maint.equipment) {
        if (x.name.toLowerCase() == v['equip']!.toLowerCase()) equip = x;
      }
      StaffMember? who;
      for (final x in maint.staff) {
        if (x.name.toLowerCase() == v['who']!.toLowerCase()) who = x;
      }
      maint.saveTask(app, title: v['title']!, kind: kind, every: every, due: DateTime(d.year, d.month, d.day, 12), equip: equip, who: who);
      return null;
    },
  ),
  'equipment': ImportSpec(
    'equipment',
    'equipment',
    const [
      ImportCol('name', 'Name', ['name', 'equipment', 'asset', 'item'], req: true),
      ImportCol('category', 'Category', ['category', 'type']),
      ImportCol('location', 'Location', ['location', 'where', 'area']),
      ImportCol('status', 'Condition (Working, Needs repair, Under maintenance)', ['condition', 'status']),
      ImportCol('vendor', 'Supplier or service company', ['supplier', 'vendor', 'service company', 'contractor']),
      ImportCol('warranty', 'Warranty ends', ['warranty', 'warranty ends', 'warranty until']),
    ],
    const [
      ['Elevator A', 'Elevator', 'Main lobby', 'Working', 'Otis Services', 'Dec 31, 2027'],
    ],
    (v, run) async {
      if (v['name']!.isEmpty) return 'No name';
      if (maint.equipment.any((x) => x.name.toLowerCase() == v['name']!.toLowerCase())) return 'Already on the list';
      final w = v['warranty']!.isEmpty ? null : importDate(v['warranty']!);
      maint.saveEquipment(app,
          name: v['name']!,
          category: _pick(equipmentCategories, v['category']!, 'Other'),
          location: v['location']!,
          status: _pick(equipmentStatuses, v['status']!, 'Working'),
          facility: '',
          closes: false,
          vendor: v['vendor']!,
          warranty: w);
      return null;
    },
  ),
  'staff': ImportSpec(
    'staff',
    'maintenance staff',
    const [
      ImportCol('name', 'Name', ['name', 'staff', 'full name', 'employee'], req: true),
      ImportCol('role', 'Role', ['role', 'position', 'job', 'title', 'trade']),
      ImportCol('phone', 'Mobile number', ['mobile', 'phone', 'contact', 'contact number', 'mobile number']),
    ],
    const [
      ['Dante Villanueva', 'Electrician', '0917 555 0199'],
    ],
    (v, run) async {
      if (v['name']!.isEmpty) return 'No name';
      if (maint.staff.any((x) => x.name.toLowerCase() == v['name']!.toLowerCase())) return 'Already on the list';
      maint.saveStaff(app, name: v['name']!, role: v['role']!, phone: _fixPhone(v['phone']!));
      return null;
    },
  ),
};
