// DEMO MODE ONLY (build with --dart-define=DEMO=true). Fills the app with made-up sample data and never talks to the database.

import '../core/core.dart';

/// Demo build: `flutter build web --dart-define=DEMO=true`.
///
/// The demo is NOT connected to any database. It starts with made-up people, units, dues, bookings
/// and announcements (the same sample data as the website demo, with dates built around today).
/// Everything the visitor changes stays in memory and is gone when the page is closed.
/// Prototype build: `flutter build web --dart-define=PROTOTYPE=true`. Same front end with sample data and no database,
/// but without the "demo" wording on screen.
const bool kPrototype = bool.fromEnvironment('PROTOTYPE', defaultValue: true);
const bool kDemo = bool.fromEnvironment('DEMO') || kPrototype;

/// The demo and the prototype start EMPTY, so the import can be tried on empty lists.
/// Build with `--dart-define=SAMPLE=true` to get the made-up sample data back.
const bool kSampleData = bool.fromEnvironment('SAMPLE', defaultValue: true);

const String kDemoPassword = 'Demo@1234';
const String kDemoAdminEmail = 'admin@demo.test';
const String kDemoResidentEmail = 'resident@demo.test';
const String kDemoResidentUnit = 'Unit 3B';
const String kDemoAdminPhone = '0917 000 0000';
const String kDemoResidentPhone = '0917 000 1108';

/// A mobile number as only digits in the 09XXXXXXXXX form (so 0917 000 1108, +63 917 000 1108 and 9170001108 match).
String _demoPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (d.startsWith('63')) d = '0${d.substring(2)}';
  if (d.length == 10 && d.startsWith('9')) d = '0$d';
  return d;
}

/// Message for things that need a real server (passwords, accounts, text-message codes).
const String kDemoOff = kPrototype ? 'This feature is not available in the prototype.' : 'This is a demo, so this is turned off.';

/// Signs in as the demo administrator or the demo resident, with an email OR a mobile number.
/// Returns an error message, or null.
String? demoSignIn(String idRaw, String pass) {
  final id = idRaw.trim().toLowerCase();
  if (id.isEmpty) return 'Enter your email or mobile number.';
  if (pass.isEmpty) return 'Enter your password.';
  final phone = id.contains('@') ? '' : _demoPhone(id);
  final admin = id == kDemoAdminEmail || (phone.isNotEmpty && phone == _demoPhone(kDemoAdminPhone));
  final resident = id == kDemoResidentEmail || (phone.isNotEmpty && phone == _demoPhone(kDemoResidentPhone));
  if (pass != kDemoPassword || (!admin && !resident)) {
    if (kPrototype) return 'Sign-in details not recognized. Use Quick access below.';
    return 'Demo logins: $kDemoAdminEmail or $kDemoAdminPhone (administrator), $kDemoResidentEmail or $kDemoResidentPhone (resident). Password $kDemoPassword.';
  }
  startDemo(admin ? Role.admin : Role.resident);
  return null;
}

/// Opens the app as the demo administrator or the demo resident (Maria Reyes, Unit 3B).
void startDemo(Role role) {
  final admin = role == Role.admin;
  final unit = admin ? '' : kDemoResidentUnit;
  app.enterSession(
    role: role,
    id: admin ? 'demo-admin' : 'demo-u2',
    name: admin ? (kPrototype ? 'Administrator' : 'Demo Administrator') : 'Maria Reyes',
    email: admin ? kDemoAdminEmail : kDemoResidentEmail,
    phone: admin ? kDemoAdminPhone : kDemoResidentPhone,
    unit: unit,
    mustChange: false,
    verified: true,
  );
  final rows = <CRow>[
    for (final r in _demoRows())
      if (_kept(r) && (admin || _residentMaySee(r, unit))) r,
  ];
  importRows(app, rows);
  if (kSampleData) {
    maint.seedDemo(app);
  } else {
    maint.clear();
    maint.appRef = app;
    app.closedForMaintenance = (name) => maint.closureOf(name) != null;
  }
  if (admin) app.setAccounts([for (final a in _demoAccounts()) if (kSampleData || a.unit == kDemoResidentUnit) a]);
  app.changed();
}

/// Without sample data only the settings (rates, payment methods, amenities, directory) and the demo resident's own
/// unit are kept, so every list starts empty and can be filled with the import.
bool _kept(CRow r) => kSampleData || r.kind == 'setting' || (r.kind == 'unit' && r.id == kDemoResidentUnit);

/// What a resident could read from the real database: public rows and their own unit's rows.
bool _residentMaySee(CRow r, String unit) {
  if (r.unit == '__admin') return false;
  if (r.unit.isEmpty) return true;
  const open = {'announcement', 'event', 'doc', 'poll', 'vendor', 'slot', 'setting', 'booking', 'rsvp', 'vote'};
  if (open.contains(r.kind)) return true;
  return r.unit == unit;
}

// ------------------------------------------------------------------ sample data

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
];

String _two(int n) => n < 10 ? '0$n' : '$n';
String _sd(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';
String _dk(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime _off(int days) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day + days, 12);
}

String _clock(int min) {
  final h = (min ~/ 60) % 24, m = min % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${m == 0 ? '' : ':${_two(m)}'}';
}

String _ap(int min) => ((min ~/ 60) % 24) >= 12 ? 'PM' : 'AM';

/// "6–8 PM" or "10 AM–12 PM" for the i-th time of an amenity.
String _slotLabel(int open, int mins, int i) {
  final s = open + i * mins, e = s + mins;
  return _ap(s) == _ap(e)
      ? '${_clock(s)}–${_clock(e)} ${_ap(s)}'
      : '${_clock(s)} ${_ap(s)}–${_clock(e)} ${_ap(e)}';
}

// A small fixed random generator, so the sample data looks the same every time.
int _rs = 20261016;
double _rnd() {
  _rs = (_rs * 1664525 + 1013904223) % 4294967296;
  return _rs / 4294967296;
}

int _ri(int a, int b) => a + (_rnd() * (b - a + 1)).floor();
T _pick<T>(List<T> a) => a[(_rnd() * a.length).floor()];

const _surnames = [
  'Santos', 'Dela Cruz', 'Ocampo', 'Garcia', 'Mendoza', 'Torres', 'Bautista', 'Reyes', 'Castillo', 'Flores', 'Villanueva', 'Ramos',
  'Aquino', 'Navarro', 'Lim', 'Tan', 'Chua', 'Salazar', 'Domingo', 'Gonzales', 'Aguilar', 'Pascual', 'Rivera', 'Mercado', 'Santiago',
  'Soriano', 'Del Rosario', 'Valdez', 'Manalo', 'Lopez', 'Fernandez', 'Diaz', 'Perez', 'Cabrera', 'Evangelista', 'Magsaysay',
];
const _firstNames = [
  'Elena', 'Paolo', 'Rhea', 'Carlo', 'Liza', 'Marco', 'Rico', 'Maria', 'Jenny', 'Noel', 'Cathy', 'Dennis', 'Joy', 'Ben', 'Grace',
  'Victor', 'Anna', 'Ramon', 'Joanna', 'Mark', 'Teresa', 'Leo', 'Kristine', 'Allan', 'Bea', 'Jun', 'Nina', 'Edgar', 'Faye', 'Rommel',
  'Lyn', 'Gerald', 'Trixie', 'Albert', 'Sheila', 'Dante',
];

/// Floor area in sqm: A smaller, C larger, upper floors a little bigger (same as the website).
int _areaOf(String label) {
  final l = label.substring(label.length - 1);
  final f = int.tryParse(label.substring(5, label.length - 1)) ?? 1;
  return (l == 'A' ? 32 : (l == 'B' ? 45 : (l == 'C' ? 60 : 40))) + (f >= 9 ? 8 : 0);
}

const _sqmRate = 50;

class _DemoUnit {
  final int i;
  final String label, house, type, status, contact, person, key;
  const _DemoUnit(this.i, this.label, this.house, this.type, this.status, this.contact, this.person, this.key);
  bool get occupied => status == 'Occupied';
}

/// 12 floors x A, B, C. Unit 3B is the demo resident (Maria Reyes).
List<_DemoUnit> _demoUnits() {
  final out = <_DemoUnit>[];
  for (var f = 1; f <= 12; f++) {
    for (final l in const ['A', 'B', 'C']) {
      final i = out.length;
      final vacant = i % 9 == 4;
      final tenant = !vacant && i % 5 == 3;
      final key = i == 7 ? 'resident' : '${_firstNames[i]}.${_surnames[i]}'.toLowerCase().replaceAll(RegExp(r'[^a-z.]'), '');
      out.add(_DemoUnit(i, 'Unit $f$l', '${_surnames[i]}${i % 2 == 1 ? ' Household' : ' Family'}', tenant ? 'Tenant' : 'Owner',
          vacant ? 'Vacant' : 'Occupied', '0917 000 ${1100 + i + 1}', '${_firstNames[i]} ${_surnames[i]}', key));
    }
  }
  return out;
}

List<Account> _demoAccounts() {
  final added = _sd(_off(-60));
  final occ = _demoUnits().where((u) => u.occupied).take(24).toList();
  final now = DateTime.now();
  // A few accounts are marked as recently created or changed so the contact list shows New / Updated.
  const newOnes = {5, 11};
  const changed = {2: 'Mobile number', 8: 'Email address', 15: 'Unit'};
  return [
    for (var k = 0; k < occ.length; k++)
      Account('demo-u${occ[k].i}', occ[k].person, '${occ[k].key}@demo.test', occ[k].contact, occ[k].label, 'Resident', added,
          verified: true,
          createdAt: newOnes.contains(k) ? now.subtract(Duration(days: k == 5 ? 1 : 3)) : now.subtract(const Duration(days: 60)),
          updatedAt: newOnes.contains(k)
              ? now.subtract(Duration(days: k == 5 ? 1 : 3))
              : (changed.containsKey(k) ? now.subtract(Duration(days: k + 1)) : null),
          lastChange: newOnes.contains(k) ? 'New account' : (changed[k] ?? ''),
          history: [
            if (changed.containsKey(k))
              AccountChange(now.subtract(Duration(days: k + 1)), changed[k]!,
                  from: k == 2 ? '0917 555 0102' : (k == 8 ? '${occ[k].key.split('.').first}@oldmail.test' : 'Unit ${1 + (k % 9)}A'),
                  to: k == 2 ? occ[k].contact : (k == 8 ? '${occ[k].key}@demo.test' : occ[k].label)),
            AccountChange(newOnes.contains(k) ? now.subtract(Duration(days: k == 5 ? 1 : 3)) : now.subtract(Duration(days: 20 + k)), 'Account created'),
          ]),
  ];
}

List<CRow> _demoRows() {
  _rs = 20261016;
  final now = DateTime.now();
  final year = now.year;
  final rows = <CRow>[];
  var seq = 0;
  int tid() => now.millisecondsSinceEpoch - 100000000 + (++seq);
  void r(String kind, Object id, String unit, Map<String, dynamic> value) => rows.add(CRow(kind, '$id', unit, value));
  DateTime monthDate(int offMonths, int day) => DateTime(now.year, now.month + offMonths, day, 12);

  // ---- units
  final units = _demoUnits();
  final occ = units.where((u) => u.occupied).toList();
  final withAcc = occ.take(24).toList();
  final byUnit = <String, Map<String, dynamic>>{};
  // Every unit has its own due day, so payments come in all through the month.
  final dueDayOf = <String, int>{for (var i = 0; i < units.length; i++) units[i].label: 1 + (i * 7 + 2) % 28};
  for (final u in units) {
    byUnit[u.label] = <String, dynamic>{
      'unit': u.label,
      'name': u.house,
      'type': u.type,
      'status': u.status,
      'contact': u.contact,
      'area': _areaOf(u.label),
      'dueDay': dueDayOf[u.label],
      'usage': u.type == 'Tenant' ? 'tenant' : 'owner',
    };
  }
  Map<String, dynamic> tenantInfo(_DemoUnit u, int from, int to) => <String, dynamic>{
        'tname': u.person,
        'tphone': u.contact,
        'occupants': '${_ri(1, 4)}',
        'start': _dk(_off(from)),
        'end': _dk(_off(to)),
        'emerg': '${_pick(_firstNames)} ${u.house.split(' ').first}, 0917 000 ${_ri(2000, 2999)}',
        'plates': 'ABC ${_ri(1000, 9999)}',
      };
  final tenants = units.where((u) => u.type == 'Tenant' && u.occupied).toList();
  for (var k = 0; k < tenants.length; k++) {
    final b = byUnit[tenants[k].label]!;
    if (k == 1) {
      b['usageStatus'] = 'pending';
      b['usageInfo'] = tenantInfo(tenants[k], 5, 370);
    } else if (k == 4) {
      b['usageStatus'] = 'rejected';
      b['usageRemark'] = 'The lease dates are missing. Please send the signed lease to the office.';
      b['usageInfo'] = tenantInfo(tenants[k], -3, 360);
    } else {
      b['usageStatus'] = 'approved';
      b['usageInfo'] = tenantInfo(tenants[k], -_ri(60, 300), _ri(60, 300));
    }
  }
  const usages = <List<Object>>[
    [9, 'shortterm'],
    [20, 'shortterm'],
    [11, 'business'],
    [14, 'renovation'],
    [25, 'renovation'],
    [16, 'business'],
  ];
  for (var k = 0; k < usages.length; k++) {
    final u = units[usages[k][0] as int];
    if (!u.occupied) continue;
    final kind = usages[k][1] as String;
    final b = byUnit[u.label]!;
    b['usage'] = kind;
    b['usageStatus'] = (k == 3 || k == 5) ? 'pending' : 'approved';
    if (kind == 'shortterm') {
      b['usageInfo'] = <String, dynamic>{
        'platform': _pick(const ['Airbnb', 'Booking.com', 'Agoda']),
        'contact': u.person,
        'phone': u.contact,
        'start': _dk(_off(-_ri(30, 200))),
        'listing': 'Cozy unit with city view',
      };
    } else if (kind == 'business') {
      b['usageInfo'] = <String, dynamic>{
        'bname': '${u.person.split(' ').last} Online Shop',
        'btype': _pick(const ['Online selling', 'Tutoring', 'Home office', 'Baking']),
        'permit': 'DTI-${_ri(100000, 999999)}',
        'hours': 'Mon to Fri, 9 AM to 5 PM',
        'phone': u.contact,
      };
    } else {
      b['usageInfo'] = <String, dynamic>{
        'work': _pick(const ['New tiles in the kitchen and bathroom', 'Repainting and new ceiling', 'New cabinets and countertop']),
        'contractor': _pick(const ['J. Villanueva Builders', 'Metro Renovations', 'Santos Interiors']),
        'phone': '0917 000 ${_ri(3000, 3999)}',
        'start': _dk(_off(_ri(3, 12))),
        'end': _dk(_off(_ri(20, 45))),
      };
    }
  }
  // sample household records (no random numbers, so the other sample data does not change)
  for (var k = 0; k < units.length; k++) {
    final u = units[k];
    if (u.status != 'Occupied') continue;
    final b = byUnit[u.label]!;
    final last = u.person.split(' ').last;
    final n = 1 + (k % 4);
    const first = ['Elena', 'Paolo', 'Rhea', 'Carlo', 'Liza', 'Marco', 'Rico', 'Maria', 'Jenny', 'Noel', 'Cathy', 'Dennis', 'Joy', 'Ben', 'Grace'];
    b['email'] = u.key + '@demo.test';
    b['residents'] = n;
    b['moveIn'] = _dk(_off(-(120 + (k * 53) % 1300)));
    b['members'] = '${u.person}, ${u.type == 'Tenant' ? 'tenant' : 'owner'}'
        '${n > 1 ? '\n${first[(k * 3 + 1) % first.length]} $last, family' : ''}'
        '${n > 2 ? '\n${first[(k * 5 + 2) % first.length]} $last, child' : ''}';
    b['emergencyName'] = '${first[(k * 7 + 3) % first.length]} $last';
    b['emergencyRelation'] = const ['Sister', 'Brother', 'Parent', 'Spouse', 'Friend'][k % 5];
    b['emergencyPhone'] = '0917 000 ${3000 + (k * 37) % 900}';
    if (k % 3 == 0) b['vehicles'] = 'Motorcycle · ${String.fromCharCode(65 + k % 26)}BC ${1000 + (k * 411) % 9000}';
    if (k % 5 == 0) b['pets'] = '1 dog';
    if (k == 0) {
      b['noteResident'] = 'Your parking sticker is ready for pickup at the office.';
      b['noteOffice'] = 'Pays at the office on the first week of the month.';
    }
    b['profileUpdated'] = DateTime.now().millisecondsSinceEpoch - (1 + (k * 3) % 20) * 86400000;
    b['profileBy'] = 'Administrator';
  }
  for (final u in units) {
    r('unit', u.label, u.label, byUnit[u.label]!);
  }

  // ---- settings
  r('setting', 'dues_rate_sqm', '', {'rate': _sqmRate});
  r('setting', 'motor_rate', '', {'rate': 1500});
  r('setting', 'motor_rate_daily', '', {'rate': 100});
  r('setting', 'park_sizes', '', {
    'list': [
      {'name': 'Small', 'sqm': 2, 'month': 1000, 'day': 70},
      {'name': 'Regular', 'sqm': 3, 'month': 1500, 'day': 100},
      {'name': 'Large', 'sqm': 4.5, 'month': 2200, 'day': 150},
    ]
  });
  r('setting', 'paymethods', '', {
    'list': [
      {'name': 'Cash or check at the office', 'details': 'Pay at the administration office, Monday to Saturday, 8 AM to 5 PM.', 'enabled': true},
      {'name': 'Bank transfer', 'details': 'Account name: City Residences Condominium Corp. (sample)\nBank: Sample Bank\nAccount no.: 0000-0000-00', 'enabled': true},
      {'name': 'GCash', 'details': 'Account name: City Residences (sample)\nNumber: 0917 000 0000', 'enabled': true},
    ],
  });
  const amenities = <Map<String, dynamic>>[
    {'id': 'pool', 'name': 'Swimming Pool', 'open': '06:00', 'close': '20:00', 'mins': 120, 'note': 'Free for residents. Guests pay ₱150 per visit, collected at the gate.'},
    {'id': 'hall', 'name': 'Function Hall', 'open': '08:00', 'close': '22:00', 'mins': 120, 'note': 'Good for up to 60 guests. Clean the hall after use.'},
  ];
  r('setting', 'amenities', '', {'list': amenities});
  r('setting', 'directory', '', {
    'contacts': [
      {'name': 'Security desk', 'note': 'Open 24 hours', 'tel': 'Local 101'},
      {'name': 'Administration office', 'note': 'Mon to Sat, 8 AM to 5 PM', 'tel': 'Local 110'},
      {'name': 'Building engineer', 'note': 'Repairs and maintenance', 'tel': 'Local 120'},
      {'name': 'Housekeeping', 'note': 'Common areas and garbage', 'tel': 'Local 130'},
      {'name': 'Parking office', 'note': 'Motor parking rentals', 'tel': 'Local 140'},
      {'name': 'Emergency hotline', 'note': 'Fire, medical, police', 'tel': '911'},
    ],
    'rules': [
      ['Quiet hours', 'Please keep noise down from 10 PM to 6 AM.'],
      ['Garbage', 'Bag your garbage and put it in the chute room on your floor. No bulky items.'],
      ['Visitors', 'Visitors must register at the lobby and leave a valid ID.'],
      ['Pets', 'Pets must be on a leash in the common areas.'],
      ['Moving in or out', 'Tell the office three days before and use the service elevator.'],
      ['Smoking', 'No smoking in the lobby, hallways, elevators and amenities.'],
    ],
  });

  // ---- dues and payments: two months back (mostly paid) and this month
  var receipt = 0;
  const methods = ['Cash or check at the office', 'GCash', 'Bank transfer'];
  for (var hi = 0; hi < occ.length; hi++) {
    final u = occ[hi];
    for (final off in const [-2, -1, 0]) {
      final dueDay = dueDayOf[u.label] ?? 25;
      final dd = monthDate(off, dueDay);
      final note = 'Association dues - ${_monLong[dd.month - 1]} ${dd.year}';
      final idn = DateTime(dd.year, dd.month, 1, 9).millisecondsSinceEpoch + hi;
      final bool paid = off < 0 ? !(off == -1 && hi % 9 == 3) && !(off == -2 && hi % 23 == 5) : (hi % 5 == 0 || hi % 5 == 2);
      final amt = _areaOf(u.label) * _sqmRate;
      r('due', idn, u.label, {
        'id': idn,
        'unit': u.label,
        'name': u.house,
        'amount': amt,
        'area': _areaOf(u.label),
        'rate': _sqmRate,
        'billedOn': _sd(DateTime(dd.year, dd.month, 1, 9)),
        'note': note,
        'dueDate': _sd(dd),
        if (paid) 'paid': true,
      });
      if (paid) {
        var pd = monthDate(off, dueDay - (hi % 4) < 1 ? 1 : dueDay - (hi % 4));
        if (pd.isAfter(now)) {
          pd = DateTime(now.year, now.month, now.day - (hi % 10) > 0 ? now.day - (hi % 10) : 1, 12);
        }
        receipt++;
        final no = 'OR-$year-${receipt.toString().padLeft(4, '0')}';
        final method = methods[(hi + off + 2) % 3];
        final ref = method == methods[0] ? '—' : 'REF${700000 + receipt * 37}';
        r('payment', idn + 5000, u.label, {
          'id': idn + 5000,
          'receiptNo': no,
          'unit': u.label,
          'payer': u.house,
          'forText': note,
          'method': method,
          'reference': ref,
          'date': _sd(pd),
          'amount': amt,
        });
        r('proof', idn + 7000, u.label, {
          'id': idn + 7000,
          'unit': u.label,
          'payer': u.house,
          'forText': note,
          'method': method,
          'reference': ref,
          'amount': amt,
          'date': _sd(pd),
          'status': 'Confirmed',
          'receiptNo': no,
          'confirmedOn': _sd(pd),
        });
      } else if (off == 0 && hi % 7 == 1) {
        r('proof', idn + 7000, u.label, {
          'id': idn + 7000,
          'unit': u.label,
          'payer': u.house,
          'forText': note,
          'method': 'GCash',
          'reference': 'GC${year * 1000000 + 101400 + hi}',
          'amount': amt,
          'date': _sd(_off(-(hi % 3))),
          'at': DateTime.now().subtract(Duration(hours: 5 + (hi % 3) * 20)).millisecondsSinceEpoch,
          'status': 'Pending',
        });
      } else if (off == 0 && hi % 11 == 4) {
        // a payment with the wrong amount: it waits for the office instead of posting by itself
        r('proof', idn + 7000, u.label, {
          'id': idn + 7000,
          'unit': u.label,
          'payer': u.house,
          'forText': note,
          'method': 'GCash',
          'reference': 'GC${year * 1000000 + 101500 + hi}',
          'amount': amt - 250,
          'date': _sd(_off(-1)),
          'at': DateTime.now().subtract(const Duration(hours: 30)).millisecondsSinceEpoch,
          'status': 'Pending',
        });
      }
    }
    if (hi % 6 == 0) {
      final xid = tid();
      r('due', xid, u.label, {
        'id': xid,
        'unit': u.label,
        'name': u.house,
        'amount': 300,
        'billedOn': _sd(_off(-(hi % 4))),
        'note': 'Motor parking rental',
        'dueDate': _sd(_off(5 + hi % 6)),
      });
    }
  }
  // The elevator repair is paid by the corporation (it is in Expenses), so residents are not billed for it.

  // ---- expenses (administrator only), six months
  var rc = 4100;
  void exp(String item, String cat, String area, String payee, int qty, num price, int offMonths, int day) {
    final d = monthDate(offMonths, day);
    if (d.isAfter(now)) return;
    final id = tid();
    rc += 7;
    r('expense', id, '__admin', {
      'id': id,
      'item': item,
      'category': cat,
      'area': area,
      'payee': payee,
      'receiptNo': 'R-$rc',
      'qty': qty,
      'unitPrice': price,
      'date': _dk(d),
    });
  }

  for (var m = 0; m >= -5; m--) {
    exp('Security guards - monthly contract', 'Security services', 'Whole building', 'SafeGuard Agency (sample)', 1, 38000, m, 3);
    exp('Common-area electricity', 'Common-area utilities', 'Lobby and common areas', 'Sample Power Co.', 1, 19000 + _ri(0, 5000) + 0.5, m, 6);
    exp('Water bill (common areas and pool)', 'Common-area utilities', 'Swimming pool', 'Sample Water District', 1, 7500 + _ri(0, 2000), m, 8);
    exp('Janitorial supplies', 'Janitorial and maintenance', 'Whole building', 'CleanPro Supplies', _ri(8, 14), 310, m, 11);
    exp('Garbage hauling', 'Janitorial and maintenance', 'Whole building', 'GreenCity Hauling', 1, 4500, m, 14);
    exp('Pool chemicals', 'Supplies and equipment', 'Swimming pool', 'AquaPure Trading', _ri(4, 7), 640, m, 17);
    exp('Reserve fund deposit', 'Administration and reserve fund', 'Whole building', 'Bank deposit', 1, 20000, m, 26);
    if (m % 3 == 0) {
      exp('Elevator servicing', 'Repairs and improvements', 'Elevators', 'LiftCare Services', 1, 15500, m, 19);
      exp('Pest control (quarterly)', 'Janitorial and maintenance', 'Whole building', 'BugAway Services', 1, 9800, m, 21);
      exp('Building insurance (quarterly)', 'Insurance', 'Whole building', 'Sample Insurance', 1, 27500, m, 23);
    }
    if (m % 2 == 0) exp('CCTV maintenance', 'Repairs and improvements', 'Whole building', 'SecureView Tech', 1, 6200, m, 22);
  }
  exp('Parking lot repainting', 'Repairs and improvements', 'Parking', 'ColorWorks Painting', 1, 12400, -2, 12);
  exp('Light bulbs for hallways', 'Supplies and equipment', 'Lobby and common areas', 'Hardware Depot', 24, 85.5, -1, 9);
  exp('Lobby plants and landscaping', 'Janitorial and maintenance', 'Lobby and common areas', 'Green Thumb Landscaping', 1, 5400, -1, 18);

  // ---- announcements, events, polls
  void ann(String title, String body, String type, int off, [String status = 'Published']) {
    final id = tid();
    r('announcement', id, '', {'id': id, 'title': title, 'body': body, 'date': _sd(_off(off)), 'status': status, 'type': type});
  }

  ann('Water interruption this Saturday', 'The water supply will be shut off from 9 AM to 3 PM for the cleaning of the water tank. Please store enough water.', 'Maintenance', -1);
  ann('Elevator B maintenance', 'Elevator B will be out of service next Tuesday from 8 AM to 12 NN. Please use Elevator A.', 'Maintenance', -3);
  ann('Reminder: dues are due on the 25th', 'Association dues are due every 25th of the month. Pay online in the Dues page or at the office.', 'General', -4);
  ann('Fire drill next week', "A building-wide fire drill will be held next Thursday at 2 PM. Please follow the guards' instructions.", 'Warning', -6);
  ann('Halloween trick-or-treat in the lobby', 'Kids are welcome to trick-or-treat on October 31 from 4 to 6 PM. Costumes encouraged!', 'General', -8);
  ann('Pest control schedule', 'Pest control will visit the floors on Wednesday from 9 AM. Please let the staff in or tell the office if you prefer another day.', 'Maintenance', -10);
  ann('New rule: parking stickers', 'All motor parking users must display the new sticker. Get yours at the office for ₱300.', 'General', -13);
  ann('Typhoon advisory', 'Please keep windows closed and move plants indoors. The guards will lock the pool and the gym when the signal is raised.', 'Emergency', -16);
  ann('Lost and found at the lobby', 'A set of keys and a blue umbrella were found near the elevator. Claim them at the guard desk.', 'General', -20);
  ann('Thank you for the clean-up drive', "Thank you to everyone who joined last month's clean-up. The lobby planters are now back.", 'General', -27);
  ann('Year-end party planning', 'Draft: we are collecting ideas for the year-end party. Details to follow.', 'General', -1, 'Draft');

  int evt(String title, int off, String time, String place, String about) {
    final id = tid();
    r('event', id, '', {'id': id, 'title': title, 'date': '${_sd(_off(off))} · $time', 'place': place, 'about': about});
    return id;
  }

  final events = <int>[
    evt('Community clean-up drive', 8, '7:00 AM', 'Lobby', 'Bring gloves and a reusable bag. Snacks provided.'),
    evt('Kids Halloween party', 15, '4:00 PM', 'Function Hall', 'Games, costumes and treats for the kids of the building.'),
    evt('Quarterly general assembly', 25, '6:00 PM', 'Function Hall', 'Updates on the budget and the lobby repainting.'),
    evt('Morning yoga by the pool', 4, '6:30 AM', 'Pool deck', 'Bring your own mat. Free for residents.'),
    evt('Blood donation drive', 11, '9:00 AM', 'Function Hall', 'In partnership with the barangay health center.'),
    evt('Christmas lights switch-on', 40, '6:00 PM', 'Lobby', 'Hot chocolate and carols for the whole building.'),
  ];
  final going = <String>{};
  for (final eid in events) {
    for (final u in withAcc) {
      if (_rnd() < 0.35) going.add('${u.label}|$eid');
    }
  }
  going.add('Unit 3B|${events[1]}');
  going.add('Unit 3B|${events[0]}');
  for (final key in going) {
    final unit = key.split('|').first;
    r('rsvp', key, unit, {'event': int.parse(key.split('|').last)});
  }
  const polls = <List<Object>>[
    ['Should the lobby be repainted this year?', true, 6, ['Yes, with a new color', 'Yes, same color', 'No, not needed'], 'Maintenance & repairs'],
    ['Best day for the quarterly general assembly?', false, -12, ['Saturday morning', 'Saturday evening', 'Sunday afternoon'], 'Events & community'],
    ['Add more CCTV cameras in the parking area?', true, 10, ['Yes', 'No', 'Not sure'], 'Safety & security'],
    ['How big should the Christmas party budget be?', true, 14, ['₱20,000', '₱35,000', '₱50,000'], 'Finance & budget'],
  ];
  for (final p in polls) {
    final id = tid();
    final opts = (p[3] as List).cast<String>();
    r('poll', id, '', {'id': id, 'question': p[0], 'open': p[1], 'closes': _sd(_off(p[2] as int)), 'options': opts, 'category': p[4]});
    for (final u in withAcc) {
      if (u.label == 'Unit 3B' && !(p[0] as String).startsWith('Best day')) continue;
      if (_rnd() < 0.65) r('vote', '${u.label}|$id', u.label, {'poll': id, 'option': (_rnd() * opts.length).floor()});
    }
  }

  // ---- elections and a survey (formatted text, several questions)
  int pollRec(String kind, String titleHtml, String descHtml, String title, int closesIn, String showResults, bool open,
      List<Map<String, dynamic>> qs, String category) {
    final id = tid();
    final d = _off(closesIn);
    r('poll', id, '', {
      'id': id,
      'kind': kind,
      'question': title,
      'titleHtml': titleHtml,
      'descHtml': descHtml,
      'open': open,
      'closes': _sd(d),
      'closeKey': _dk(d),
      'showResults': showResults,
      'category': category,
      'options': qs.first['options'],
      'questions': qs,
    });
    return id;
  }

  void cast(int id, List<Map<String, dynamic>> qs, double share, Object? Function(Map<String, dynamic> q) fn) {
    for (final u in withAcc) {
      if (u.label == 'Unit 3B' && share < 1) continue;
      if (_rnd() > share) continue;
      final a = <String, dynamic>{};
      for (final q in qs) {
        final v = fn(q);
        if (v != null) a[q['id'] as String] = v;
      }
      r('vote', '${u.label}|$id', u.label, {
        'poll': id,
        'answers': a,
        'at': _off(-1).subtract(Duration(milliseconds: (_rnd() * 6 * 86400000).floor())).toUtc().toIso8601String(),
      });
    }
  }

  List<int> pickN(int n, int k) {
    final all = [for (var i = 0; i < n; i++) i];
    final out = <int>[];
    while (out.length < k && all.isNotEmpty) {
      out.add(all.removeAt((_rnd() * all.length).floor()));
    }
    return out;
  }

  Map<String, dynamic> pos(int i, String name, List<String> cands, int seats) => {
        'id': 'q$i',
        'type': seats > 1 ? 'multi' : 'choice',
        'html': name,
        'text': name.replaceAll(RegExp(r'<[^>]+>'), ''),
        'required': false,
        'max': seats,
        'options': cands,
      };

  final elQs = [
    pos(1, '<b>President</b>', ['Carla Aquino — Unit 5A', 'Ramon Dela Cruz — Unit 1B', 'Liza Villanueva — Unit 4B'], 1),
    pos(2, '<b>Vice President</b>', ['Marco Chua — Unit 6B', 'Anna Reyes — Unit 3B'], 1),
    pos(3, '<b>Secretary</b>', ['Joy Torres — Unit 2C', 'Ben Santos — Unit 1A'], 1),
    pos(4, '<b>Treasurer</b>', ['Grace Evangelista — Unit 12B', 'Paolo Mendoza — Unit 8C'], 1),
    pos(5, '<b>Board Directors</b> <i>(vote for up to 3)</i>',
        ['Carla Aquino — Unit 5A', 'Ben Santos — Unit 1A', 'Marco Chua — Unit 6B', 'Joy Torres — Unit 2C', 'Liza Villanueva — Unit 4B'], 3),
  ];
  final elId = pollRec(
      'election',
      '<b>2026 Board of Directors election</b>',
      'Choose the people who will manage the building for <b>2026–2027</b>.<ul><li>Each unit has <b>one secret ballot</b>.</li><li>You may leave a position blank to abstain.</li><li>The results are shown when voting closes.</li></ul>',
      '2026 Board of Directors election',
      12,
      'closed',
      true,
      elQs,
      'Governance & elections');
  cast(elId, elQs, 0.7, (q) {
    final n = (q['options'] as List).length;
    return q['type'] == 'multi' ? pickN(n, 1 + (_rnd() * 3).floor()) : (_rnd() < 0.08 ? null : (_rnd() * n).floor());
  });
  final oldQs = [
    pos(1, '<b>Chairperson</b>', ['Elena Castillo — Unit 7A', 'Roberto Lim — Unit 9B'], 1),
    pos(2, '<b>Committee members</b> <i>(vote for up to 2)</i>', ['Nina Flores — Unit 3A', 'Victor Gomez — Unit 10A', 'Teresa Ramos — Unit 11C'], 2),
  ];
  final oldId = pollRec('election', '<b>2025 Homeowners’ committee election</b>', 'Closed election. Thank you to everyone who voted.',
      '2025 Homeowners’ committee election', -40, 'closed', false, oldQs, 'Governance & elections');
  cast(oldId, oldQs, 0.75, (q) {
    final n = (q['options'] as List).length;
    return q['type'] == 'multi' ? pickN(n, 2) : (_rnd() * n).floor();
  });
  final svQs = <Map<String, dynamic>>[
    {'id': 'q1', 'type': 'choice', 'html': '<b>How often</b> do you use the pool?', 'text': 'How often do you use the pool?', 'required': true, 'max': 0,
      'options': ['Every week', 'A few times a month', 'Rarely', 'Never']},
    {'id': 'q2', 'type': 'multi', 'html': 'Which facilities should be <u>improved first</u>? <i>(choose up to 3)</i>', 'text': 'Which facilities should be improved first?',
      'required': true, 'max': 3, 'options': ['Pool', 'Gym', 'Function Hall', 'Parking', 'Lobby', 'Coffee lounge']},
    {'id': 'q3', 'type': 'rating', 'html': 'How satisfied are you with the <b>cleanliness</b> of the common areas?',
      'text': 'How satisfied are you with the cleanliness of the common areas?', 'required': true, 'max': 0, 'options': <String>[]},
    {'id': 'q4', 'type': 'para', 'html': 'Anything else you would like the board to know?', 'text': 'Anything else you would like the board to know?',
      'required': false, 'max': 0, 'options': <String>[]},
  ];
  const notes = [
    'More lighting near the parking area, please.',
    'The gym needs two more treadmills.',
    'Please repaint the lobby soon.',
    'Thank you for the quick repairs in March!',
    'Add more bike racks.',
    'Quiet hours should be enforced on weekends.',
  ];
  final svId = pollRec(
      'poll',
      '<b>Building facilities survey</b>',
      'Help us decide what to improve first. It takes <i>two minutes</i>. Your answers are shared with the board.',
      'Building facilities survey',
      9,
      'vote',
      true,
      svQs,
      'Facilities & amenities');
  cast(svId, svQs, 0.6, (q) {
    switch (q['id']) {
      case 'q1':
        return (_rnd() * 4).floor();
      case 'q2':
        return pickN(6, 1 + (_rnd() * 3).floor());
      case 'q3':
        return 2 + (_rnd() * 4).floor();
      default:
        return _rnd() < 0.4 ? notes[(_rnd() * notes.length).floor()] : null;
    }
  });
  r('setting', 'poll_categories', '', {'list': pollBuiltInCategories});

  // ---- bookings
  int toMin(String t) {
    final q = t.split(':');
    return int.parse(q[0]) * 60 + int.parse(q[1]);
  }

  int slotCount(Map<String, dynamic> a) => (toMin(a['close'] as String) - toMin(a['open'] as String)) ~/ (a['mins'] as int);
  final used = <String>{};
  bool book(String unit, int ai, int si, int off, String status) {
    final a = amenities[ai];
    final d = _off(off);
    final key = '$ai|${_dk(d)}|$si';
    if (!used.add(key)) return false;
    final id = tid();
    r('booking', id, unit, {
      'id': id,
      'who': byUnit[unit]!['name'],
      'unit': unit,
      'place': a['name'],
      'when': '${_sd(d)}, ${_slotLabel(toMin(a['open'] as String), a['mins'] as int, si)}',
      'status': status,
      'day': _dk(d),
      'slot': si,
    });
    return true;
  }

  book('Unit 3B', 0, 2, 6, 'Approved');
  book('Unit 3B', 1, 0, 3, 'Pending');
  book('Unit 3B', 0, 4, -6, 'Approved');
  var made = 0, tries = 0;
  while (made < 52 && tries++ < 600) {
    final u = _pick(withAcc);
    final off = _ri(-12, 14);
    final ai = (_rnd() * 2).floor();
    final si = (_rnd() * slotCount(amenities[ai])).floor();
    final x = _rnd();
    final status = off < 0 ? (x < 0.85 ? 'Approved' : 'Denied') : (x < 0.55 ? 'Approved' : x < 0.88 ? 'Pending' : 'Denied');
    if (book(u.label, ai, si, off, status)) made++;
  }

  // ---- grievances: stage 0 open, 1 in progress, 2 resolved
  const griev = <List<String>>[
    ['Leaking pipe in the hallway', 'Water drips from the ceiling near the elevator.'],
    ['Broken hallway light', 'The light outside the unit keeps flickering.'],
    ['Noise from a late-night gathering', 'Loud music past midnight on the weekend.'],
    ['Parking gate sensor not working', 'The gate sometimes does not open for residents.'],
    ['Treadmill in the gym is broken', 'The second treadmill stops after a few minutes.'],
    ['Elevator A makes a grinding sound', 'A loud noise between the 7th and 8th floor.'],
    ['Garbage left in the hallway', 'Bags were left outside the chute room again.'],
    ['Pool tiles are slippery', 'The shallow end is slippery in the morning.'],
    ['No hot water in the gym shower', 'Cold water only since Monday.'],
    ['Intercom not working', 'The lobby intercom does not ring in the unit.'],
    ['Water pressure is low', 'Very weak water pressure in the evening.'],
    ['Smoking in the stairwell', 'A smell of cigarette smoke on the 5th floor stairs.'],
    ['Stray cat in the parking area', 'A cat is trapped near the motor parking.'],
    ['Lobby aircon too cold', 'The lobby aircon is set too low in the morning.'],
  ];
  for (var i = 0; i < griev.length; i++) {
    final id = tid() - i * 129600000;
    final u = i < 2 ? units[7] : _pick(withAcc);
    final st = i < 2 ? (i == 0 ? 1 : 2) : (_rnd() < 0.35 ? 0 : _rnd() < 0.5 ? 1 : 2);
    r('grievance', id, u.label, {'id': id, 'title': griev[i][0], 'body': griev[i][1], 'by': u.label, 'stage': st});
  }

  // ---- motor parking: 20 slots
  final rented = <String>{};
  String sizeOfSlot(int n) => n <= 6 ? 'Small' : (n <= 16 ? 'Regular' : 'Large');
  void rent(String id, String unit, String plan, int off, int days, int amount) {
    rented.add(id);
    r('slot', id, '', {'id': id, 'unit': unit, 'plan': plan, 'from': _dk(_off(off)), 'until': _dk(_off(off + days - 1)), 'amount': amount, 'size': sizeOfSlot(int.parse(id.substring(2)))});
  }

  rent('M-02', 'Unit 1A', 'month', -10, 30, 1000);
  rent('M-04', 'Unit 9B', 'day', -1, 4, 280);
  rent('M-08', 'Unit 2B', 'month', -20, 30, 1500);
  rent('M-09', 'Unit 2A', 'month', -5, 30, 1500);
  rent('M-11', 'Unit 3A', 'day', 0, 7, 700);
  rent('M-13', 'Unit 4A', 'month', -26, 30, 1500);
  rent('M-15', 'Unit 6C', 'month', -3, 30, 1500);
  rent('M-16', 'Unit 8B', 'day', -2, 3, 300);
  rent('M-18', 'Unit 10A', 'month', -15, 30, 2200);
  for (var s = 1; s <= 20; s++) {
    final id = 'M-${_two(s)}';
    if (!rented.contains(id)) r('slot', id, '', {'id': id, 'size': sizeOfSlot(s)});
  }
  const reqs = <List<String>>[
    ['Unit 7A', 'M-05'],
    ['Unit 5C', 'M-06'],
  ];
  for (var k = 0; k < reqs.length; k++) {
    final unit = reqs[k][0];
    final name = byUnit[unit]!['name'];
    r('request', unit, unit, {
      'unit': unit,
      'who': name,
      'when': k == 1 ? '3 hours ago' : '1 hour ago',
      'at': now.millisecondsSinceEpoch - (k == 1 ? 10800000 : 3600000),
      'slot': reqs[k][1],
      'plan': 'month',
      'days': 1,
      'amount': 1000,
      'confirmed': false,
    });
    if (k == 0) {
      final rp = tid();
      r('proof', rp, unit, {
        'id': rp,
        'unit': unit,
        'payer': name,
        'forText': 'Motor parking rental',
        'method': 'GCash',
        'reference': 'GC${year * 1000000 + 101403}',
        'amount': 1000,
        'date': _sd(now),
        'at': now.subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
        'status': 'Pending',
        'slot': reqs[k][1],
      });
    }
  }

  // ---- documents (readable inside the app)
  void doc(String name, String cat, String aud, List<Map<String, dynamic>> blocks, int off) {
    final id = tid();
    r('doc', id, aud == 'admin' ? '__admin' : '', {
      'id': id,
      'name': name,
      'cat': cat,
      'date': _sd(_off(off)),
      'audience': aud,
      'ext': '',
      'blocks': blocks,
    });
  }

  doc('House Rules and Regulations', 'Policy', 'all', [
    {'k': 'h1', 't': 'House Rules and Regulations (sample)'},
    {'k': 'h2', 't': '1. Quiet hours'},
    {'k': 'p', 't': 'Keep noise down from 10 PM to 6 AM.'},
    {'k': 'h2', 't': '2. Common areas'},
    {'k': 'bullet', 't': 'Do not leave belongings in the hallways.'},
    {'k': 'bullet', 't': 'Clean the amenity after you use it.'},
  ], -60);
  doc('Financial statement (sample)', 'Finance', 'all', [
    {'k': 'h1', 't': 'Statement of collections and expenses (sample numbers)'},
    {
      'k': 'table',
      'r': [
        ['Item', 'Amount'],
        ['Dues collected', '₱ 240,000'],
        ['Operating expenses', '₱ 168,000'],
        ['Reserve fund', '₱ 72,000'],
      ],
    },
  ], -20);
  doc('Move-in and move-out form', 'Form', 'all', [
    {'k': 'h1', 't': 'Move-in / move-out form (sample)'},
    {'k': 'p', 't': 'Fill this in and submit it to the office three days before moving.'},
  ], -90);
  doc('Minutes of the last general assembly', 'Minutes', 'all', [
    {'k': 'h1', 't': 'Minutes (sample)'},
    {'k': 'bullet', 't': 'The budget was approved.'},
    {'k': 'bullet', 't': 'The lobby repainting will be put to a vote.'},
  ], -45);
  doc('Parking policy', 'Policy', 'all', [
    {'k': 'h1', 't': 'Motor parking policy (sample)'},
    {'k': 'bullet', 't': 'Monthly rental is ₱1,500; daily rental is ₱100 per day.'},
    {'k': 'bullet', 't': 'Display the sticker at all times.'},
  ], -30);
  doc('Amenity guidelines', 'Policy', 'all', [
    {'k': 'h1', 't': 'Amenity guidelines (sample)'},
    {'k': 'p', 't': "Bookings are in two-hour times and need the office's approval."},
    {'k': 'bullet', 't': 'Pool: 6 AM to 8 PM.'},
    {'k': 'bullet', 't': 'Function hall: 8 AM to 10 PM.'},
  ], -75);
  doc('Notice: elevator schedule', 'Notice', 'all', [
    {'k': 'h1', 't': 'Elevator maintenance schedule (sample)'},
    {'k': 'p', 't': 'Elevator B will be serviced every first Tuesday of the month.'},
  ], -3);
  doc('Board notes (admin only)', 'Other', 'admin', [
    {'k': 'h1', 't': 'Board notes (sample)'},
    {'k': 'p', 't': 'Only the administrator can see this document.'},
  ], -5);

  // ---- activity log (administrator)
  const acts = <List<String>>[
    ['Payment recorded, ', 'Finance'],
    ['Booking approved, ', 'Facilities'],
    ['Booking denied, ', 'Facilities'],
    ['Account created for ', 'Access'],
    ['Unit usage declaration received, ', 'Units'],
    ['Complaint in progress: ', 'Requests'],
    ['Parking rented to ', 'Parking'],
  ];
  const fixedActs = <List<String>>[
    ['Announcement published: Water interruption this Saturday', 'Announcements'],
    ['Expense added: Security guards - monthly contract', 'Expenses'],
    ['Event added: Community clean-up drive', 'Events'],
    ['Poll created: Should the lobby be repainted this year?', 'Polls'],
    ['Charge posted to every occupied unit: October dues', 'Finance'],
    ['Amenity updated: Gym', 'Facilities'],
    ['Document uploaded: Parking policy', 'Documents'],
    ['Settings updated: payment methods', 'Settings'],
  ];
  void act(String title, String area, double daysAgo) {
    final at = now.millisecondsSinceEpoch - (daysAgo * 86400000).round() - _ri(0, 3600000);
    r('activity', at, '__admin', {'title': title, 'area': area, 'at': at});
  }

  for (var a = 0; a < 40; a++) {
    final t = _pick(acts);
    act('${t[0]}${_pick(withAcc).label}', t[1], a * 0.35 + _rnd() * 0.3);
  }
  for (var k = 0; k < fixedActs.length; k++) {
    act(fixedActs[k][0], fixedActs[k][1], 1 + k * 1.6);
  }
  return rows;
}
