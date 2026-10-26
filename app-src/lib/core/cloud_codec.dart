// Converts AppState <-> database rows (see the long note below).

part of 'app_state.dart';

// Turns everything the app holds into rows of the shared `records` table (and back).
// One row = one thing: a unit, a booking, a charge, a payment, a setting, ...
// The website reads and writes the very same rows, so both always show the same data.

/// One row of the `records` table.
class CRow {
  final String kind, id;

  /// Who the row belongs to: a unit name, '' for rows every resident can read,
  /// or '__admin' for rows only the administrator can read.
  final String unit;
  final Map<String, dynamic> value;
  const CRow(this.kind, this.id, this.unit, this.value);
  String get key => '$kind|$id';
}

/// Kinds a resident may delete (matches the database rules).
const residentDeletable = {'request', 'booking', 'rsvp'};

// ---------------------------------------------------------------- helpers

dynamic _clean(dynamic v) {
  if (v is Map) {
    final m = <String, dynamic>{};
    for (final e in v.entries) {
      final c = _clean(e.value);
      if (_isEmpty(c)) continue;
      m[e.key.toString()] = c;
    }
    return m;
  }
  if (v is List) return [for (final x in v) _clean(x)];
  return v;
}

bool _isEmpty(dynamic v) =>
    v == null ||
    v == '' ||
    v == false ||
    (v is num && v == 0) ||
    (v is Map && v.isEmpty) ||
    (v is List && v.isEmpty);

String _stable(dynamic v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_stable(v[k])}').join(',')}}';
  }
  if (v is List) return '[${v.map(_stable).join(',')}]';
  if (v is num) return (v.isFinite && v == v.truncate()) ? v.truncate().toString() : v.toString();
  return jsonEncode(v);
}

/// A comparable form of a record: keys sorted, empty values left out.
String canonJson(dynamic v) => _stable(_clean(v));

String _s(Map j, String k, [String d = '']) {
  final v = j[k];
  return v == null ? d : v.toString();
}

int _i(Map j, String k, [int d = 0]) {
  final v = j[k];
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? d;
}

num _num(Map j, String k, [num d = 0]) {
  final v = j[k];
  if (v is num) return v;
  return num.tryParse('${v ?? ''}') ?? d;
}

bool _b(Map j, String k) => j[k] == true || j[k] == 'true';

// ---------------------------------------------------------------- one by one

Map<String, dynamic> _unitJson(Unit u) => {
      'unit': u.unit,
      'name': u.name,
      'type': u.type,
      'status': u.status,
      'contact': u.contact,
      'usage': u.usage,
      'statusNote': u.statusNote,
      'statusDate': u.statusDate,
      'usageStatus': u.usageStatus,
      'usageRemark': u.usageRemark,
      'usageInfo': {for (final e in u.usageInfo.entries) e.key: e.key == 'agree' ? e.value == 'true' : e.value},
    };

Unit? _unitFrom(Map<String, dynamic> j) {
  final id = _s(j, 'unit');
  if (id.isEmpty) return null;
  return Unit(id, _s(j, 'name', '—'), _s(j, 'type', 'Owner'), _s(j, 'status', 'Occupied'),
      _s(j, 'contact', '—'), _s(j, 'usage', 'owner'),
      statusNote: _s(j, 'statusNote'),
      statusDate: _s(j, 'statusDate'),
      usageStatus: _s(j, 'usageStatus'),
      usageRemark: _s(j, 'usageRemark'),
      usageInfo: {
        if (j['usageInfo'] is Map)
          for (final e in (j['usageInfo'] as Map).entries)
            if (e.value != null && e.value.toString().isNotEmpty && e.value != false) e.key.toString(): e.value.toString(),
      });
}

Map<String, dynamic> _updateJson(StatusUpdate s) =>
    {'id': s.id, 'unit': s.unit, 'key': s.key, 'note': s.note, 'date': s.date, 'by': s.by};

StatusUpdate? _updateFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return StatusUpdate(_i(j, 'id'), _s(j, 'unit'), _s(j, 'key'), _s(j, 'note'), _s(j, 'date'), _s(j, 'by'));
}

Map<String, dynamic> _bookingJson(Booking b) => {
      'id': b.id,
      'who': b.who,
      'unit': b.unit,
      'place': b.place,
      'when': b.when,
      'status': b.status,
      'day': b.day,
      'slot': b.slot,
    };

Booking? _bookingFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return Booking(_i(j, 'id'), _s(j, 'who'), _s(j, 'unit'), _s(j, 'place'), _s(j, 'when'),
      _s(j, 'status', 'Pending'),
      day: _s(j, 'day'), slot: _i(j, 'slot', -1));
}

Map<String, dynamic> _dueJson(Due d) => {
      'id': d.id,
      'unit': d.unit,
      'name': d.name,
      'amount': d.amount,
      'note': d.note,
      'dueDate': d.dueDate,
      'paid': d.paid,
    };

Due? _dueFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return Due(_i(j, 'id'), _s(j, 'unit'), _s(j, 'name'), _num(j, 'amount'), _s(j, 'note', 'Charge'),
      dueDate: _s(j, 'dueDate'), paid: _b(j, 'paid'));
}

Map<String, dynamic> _grievanceJson(Grievance g) =>
    {'id': g.id, 'title': g.title, 'body': g.body, 'by': g.by, 'stage': g.stage};

Grievance? _grievanceFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return Grievance(_i(j, 'id'), _s(j, 'title'), _s(j, 'body'), _s(j, 'by'), _i(j, 'stage').clamp(0, 2));
}

Map<String, dynamic> _annJson(Announcement a) => {
      'id': a.id,
      'title': a.title,
      'body': a.body,
      'date': a.date,
      'status': a.status,
      'type': a.type,
      'sms': a.sms,
      if (a.units.isNotEmpty) 'units': a.units,
    };

Announcement? _annFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return Announcement(_i(j, 'id'), _s(j, 'title'), _s(j, 'body'), _s(j, 'date'),
      _s(j, 'status', 'Published'), _s(j, 'type', 'General'), _b(j, 'sms'),
      units: j['units'] is List ? [for (final u in j['units'] as List) '$u'] : null);
}

Map<String, dynamic> _eventJson(EventItem e) =>
    {'id': e.id, 'title': e.title, 'date': e.date, 'place': e.place, 'about': e.about};

EventItem? _eventFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return EventItem(_i(j, 'id'), _s(j, 'title'), _s(j, 'date'), _s(j, 'place'), about: _s(j, 'about'));
}

Map<String, dynamic> _pollJson(Poll p) => {
      'id': p.id,
      'question': p.question,
      'open': p.open,
      'closes': p.closes,
      'options': [for (final o in p.options) o.text],
    };

Poll? _pollFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  final opts = j['options'];
  return Poll(_i(j, 'id'), _s(j, 'question'), _b(j, 'open'), _s(j, 'closes'),
      [if (opts is List) for (final o in opts) PollOption(o.toString(), 0)]);
}

Map<String, dynamic> _docJson(DocItem d) => {
      'id': d.id,
      'name': d.name,
      'cat': d.cat,
      'date': d.date,
      'audience': d.audience,
      'ext': d.ext,
      if (d.raw != null) 'raw': base64Encode(d.raw!),
      'blocks': [
        for (final b in d.blocks)
          {
            'k': b.kind.name,
            't': b.text,
            if (b.kind == BlockKind.table) 'r': b.rows,
          }
      ],
    };

DocBlock _blockFrom(Map j) {
  final t = _s(j, 't');
  switch (_s(j, 'k')) {
    case 'h1':
      return DocBlock.h1(t);
    case 'h2':
      return DocBlock.h2(t);
    case 'bullet':
      return DocBlock.bullet(t);
    case 'table':
      final r = j['r'];
      return DocBlock.table([
        if (r is List)
          for (final row in r)
            if (row is List) [for (final c in row) c.toString()]
      ]);
    default:
      return DocBlock.p(t);
  }
}

DocItem? _docFrom(Map<String, dynamic> j) {
  final id = _s(j, 'id');
  if (id.isEmpty) return null;
  final blocks = j['blocks'];
  final raw = _s(j, 'raw');
  Uint8List? bytes;
  if (raw.isNotEmpty) {
    try {
      bytes = base64Decode(raw);
    } catch (_) {}
  }
  return DocItem(_s(j, 'name'), _s(j, 'cat', 'Other'), _s(j, 'date'),
      blocks: [if (blocks is List) for (final b in blocks) if (b is Map) _blockFrom(b)],
      audience: _s(j, 'audience', 'all'),
      raw: bytes,
      ext: _s(j, 'ext'),
      id: id);
}

Map<String, dynamic> _slotJson(ParkingSlot s) =>
    {'id': s.id, 'unit': s.unit, 'plan': s.plan, 'from': s.from, 'until': s.until, 'amount': s.amount};

ParkingSlot? _slotFrom(Map<String, dynamic> j) {
  final id = _s(j, 'id');
  return id.isEmpty ? null : ParkingSlot(id, _s(j, 'unit'), _s(j, 'plan', 'month') == 'day' ? 'day' : 'month', _s(j, 'from'), _s(j, 'until'), _num(j, 'amount'));
}

Map<String, dynamic> _requestJson(ParkingReq r) =>
    {'unit': r.unit, 'who': r.name, 'when': r.when, 'at': r.at, 'confirmed': r.confirmed, 'slot': r.slot, 'amount': r.amount, 'plan': r.plan, 'days': r.days};

ParkingReq? _requestFrom(Map<String, dynamic> j) {
  final unit = _s(j, 'unit');
  if (unit.isEmpty) return null;
  return ParkingReq(unit, _s(j, 'who'),
      confirmed: _b(j, 'confirmed'), when: _s(j, 'when', 'Just now'), at: _i(j, 'at'), slot: _s(j, 'slot'), amount: _num(j, 'amount'), plan: _s(j, 'plan', 'month') == 'day' ? 'day' : 'month', days: _i(j, 'days'));
}

Map<String, dynamic> _paymentJson(PaymentRecord p) => {
      'id': p.id,
      'receiptNo': p.receiptNo,
      'unit': p.unit,
      'payer': p.payer,
      'forText': p.forText,
      'method': p.method,
      'reference': p.reference,
      'date': p.date,
      'amount': p.amount,
    };

PaymentRecord? _paymentFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  return PaymentRecord(_i(j, 'id'), _s(j, 'receiptNo'), _s(j, 'unit'), _s(j, 'payer'),
      _s(j, 'forText'), _s(j, 'method'), _s(j, 'reference', '—'), _s(j, 'date'), _num(j, 'amount'));
}

Map<String, dynamic> _expenseJson(Expense e) => {
      'id': e.id,
      'item': e.item,
      'category': e.category,
      'area': e.area,
      'payee': e.payee,
      'receiptNo': e.receiptNo,
      'note': e.note,
      'qty': e.qty,
      'unitPrice': e.unitPrice,
      'date': dayKey(e.date),
    };

Expense? _expenseFrom(Map<String, dynamic> j) {
  if (j['id'] is! num) return null;
  final d = DateTime.tryParse(_s(j, 'date'));
  if (d == null) return null;
  return Expense(
    id: _i(j, 'id'),
    item: _s(j, 'item'),
    category: _s(j, 'category', 'Other'),
    area: _s(j, 'area'),
    payee: _s(j, 'payee'),
    receiptNo: _s(j, 'receiptNo'),
    note: _s(j, 'note'),
    qty: _num(j, 'qty', 1),
    unitPrice: _num(j, 'unitPrice'),
    date: DateTime(d.year, d.month, d.day),
  );
}

Map<String, dynamic> _activityJson(ActivityEntry a) =>
    {'title': a.title, 'area': a.area, 'at': a.at.millisecondsSinceEpoch};

ActivityEntry? _activityFrom(Map<String, dynamic> j) {
  final at = _i(j, 'at');
  if (at == 0) return null;
  return ActivityEntry(_s(j, 'title'), _s(j, 'area'), DateTime.fromMillisecondsSinceEpoch(at));
}

// ---------------------------------------------------------------- export

/// Everything this person is allowed to write, as rows. The sync compares these with the
/// database and sends only what changed.
List<CRow> exportRows(AppState a) {
  final admin = a.role == Role.admin;
  final rows = <CRow>[];
  void add(String kind, String id, String unit, Map<String, dynamic> v) => rows.add(CRow(kind, id, unit, v));

  for (final u in a.units) {
    add('unit', u.unit, u.unit, _unitJson(u));
  }
  for (final s in a.statusUpdates) {
    add('statusUpdate', '${s.id}', s.unit, _updateJson(s));
  }
  for (final b in a.bookings) {
    add('booking', '${b.id}', b.unit, _bookingJson(b));
  }
  for (final g in a.grievances) {
    add('grievance', '${g.id}', g.by, _grievanceJson(g));
  }
  for (final p in a.proofs) {
    add('proof', '${p.id}', p.unit, p.toJson());
  }
  for (final r in a.parking) {
    add('request', r.unit, r.unit, _requestJson(r));
  }
  for (final k in a._rsvps) {
    final i = k.indexOf('|');
    add('rsvp', k, k.substring(0, i), {'event': int.tryParse(k.substring(i + 1)) ?? 0});
  }
  for (final e in a._votes.entries) {
    final i = e.key.indexOf('|');
    add('vote', e.key, e.key.substring(0, i), {'poll': int.tryParse(e.key.substring(i + 1)) ?? 0, 'option': e.value});
  }
  for (final x in a.activityLog) {
    add('activity', '${x.at.millisecondsSinceEpoch}', '__admin', _activityJson(x));
  }
  if (!admin) return rows;

  for (final d in a.dues) {
    add('due', '${d.id}', d.unit, _dueJson(d));
  }
  for (final p in a.payments) {
    add('payment', '${p.id}', p.unit, _paymentJson(p));
  }
  for (final e in a.expenses) {
    add('expense', '${e.id}', '__admin', _expenseJson(e));
  }
  for (final x in a.announcements) {
    add('announcement', '${x.id}', '', _annJson(x));
  }
  for (final e in a.events) {
    add('event', '${e.id}', '', _eventJson(e));
  }
  for (final p in a.polls) {
    add('poll', '${p.id}', '', _pollJson(p));
  }
  for (final d in a.docs.where((d) => !d.isLive && d.id.isNotEmpty)) {
    add('doc', d.id, d.audience == 'admin' ? '__admin' : '', _docJson(d));
  }
  for (final s in a.slots) {
    add('slot', s.id, '', _slotJson(s));
  }
  add('setting', 'motor_rate', '', {'rate': a.motorRate});
  add('setting', 'motor_rate_daily', '', {'rate': a.motorRateDay});
  add('setting', 'dues_rate', '', {'rate': a.duesRate});
  add('setting', 'paymethods', '', {
    'list': [
      for (final m in a.payMethods) {'name': m.name, 'details': m.details, 'enabled': m.enabled}
    ]
  });
  add('setting', 'amenities', '', {
    'list': [
      for (final m in a.amenities) {'id': m.id, 'name': m.name, 'open': m.open, 'close': m.close, 'mins': m.mins, 'note': m.note}
    ]
  });
  add('setting', 'blocked', '', {
    'day': a.blockedDay,
    'keys': [for (final e in a.blocked.entries) if (e.value) e.key]
  });
  add('setting', 'budget', '', {'map': Map<String, dynamic>.from(annualBudget)});
  add('setting', 'directory', '', {
    'contacts': [
      for (final c in directoryContacts) {'name': c.name, 'note': c.note, 'tel': c.tel}
    ],
    'rules': [for (final r in houseRules) r],
  });
  return rows;
}

// ---------------------------------------------------------------- import

void _mergeList<T>(
  List<T> list,
  Iterable<CRow> rows, {
  required Map<String, dynamic> Function(T) enc,
  required T? Function(Map<String, dynamic>) dec,
  required String Function(T) id,
  int Function(T, T)? cmp,
}) {
  final old = {for (final x in list) id(x): x};
  final out = <T>[];
  for (final r in rows) {
    final ex = old[r.id];
    if (ex != null && canonJson(enc(ex)) == canonJson(r.value)) {
      out.add(ex);
      continue;
    }
    final n = dec(r.value);
    if (n != null) out.add(n);
  }
  if (cmp != null) out.sort(cmp);
  list
    ..clear()
    ..addAll(out);
}

/// Makes the app show exactly what the database holds.
void importRows(AppState a, Iterable<CRow> all) {
  final by = <String, List<CRow>>{};
  for (final r in all) {
    (by[r.kind] ??= []).add(r);
  }
  List<CRow> of(String k) => by[k] ?? const <CRow>[];
  int newestFirst(int x, int y) => y.compareTo(x);
  final admin = a.role == Role.admin;

  // who voted / who is going (counts are worked out from these)
  a._votes
    ..clear()
    ..addEntries([for (final r in of('vote')) MapEntry(r.id, _i(r.value, 'option'))]);
  a._rsvps
    ..clear()
    ..addAll([for (final r in of('rsvp')) r.id]);

  _mergeList<Unit>(a.units, of('unit'),
      enc: _unitJson, dec: _unitFrom, id: (u) => u.unit, cmp: (x, y) => naturalCompare(x.unit, y.unit));

  final knownUpdates = {for (final s in a.statusUpdates) s.id};
  _mergeList<StatusUpdate>(a.statusUpdates, of('statusUpdate'),
      enc: _updateJson, dec: _updateFrom, id: (s) => '${s.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  if (admin && a.loaded) {
    a.newStatusUpdates +=
        a.statusUpdates.where((s) => !knownUpdates.contains(s.id) && s.by == 'Resident').length;
  }

  _mergeList<Booking>(a.bookings, of('booking'),
      enc: _bookingJson, dec: _bookingFrom, id: (b) => '${b.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<Due>(a.dues, of('due'),
      enc: _dueJson, dec: _dueFrom, id: (d) => '${d.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<Grievance>(a.grievances, of('grievance'),
      enc: _grievanceJson, dec: _grievanceFrom, id: (g) => '${g.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<PaymentProof>(a.proofs, of('proof'),
      enc: (p) => p.toJson(), dec: PaymentProof.fromJson, id: (p) => '${p.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<PaymentRecord>(a.payments, of('payment'),
      enc: _paymentJson, dec: _paymentFrom, id: (p) => '${p.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<Expense>(a.expenses, of('expense'),
      enc: _expenseJson, dec: _expenseFrom, id: (e) => '${e.id}', cmp: (x, y) => y.date.compareTo(x.date));
  _mergeList<Announcement>(a.announcements, of('announcement'),
      enc: _annJson, dec: _annFrom, id: (x) => '${x.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<EventItem>(a.events, of('event'),
      enc: _eventJson, dec: _eventFrom, id: (x) => '${x.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  _mergeList<Poll>(a.polls, of('poll'),
      enc: _pollJson, dec: _pollFrom, id: (p) => '${p.id}', cmp: (x, y) => newestFirst(x.id, y.id));
  for (final p in a.polls) {
    for (final o in p.options) {
      o.votes = 0;
    }
  }
  for (final e in a._votes.entries) {
    final i = e.key.indexOf('|');
    final pid = int.tryParse(e.key.substring(i + 1));
    for (final p in a.polls.where((p) => p.id == pid)) {
      if (e.value >= 0 && e.value < p.options.length) p.options[e.value].votes++;
    }
  }

  final others = a.docs.where((d) => !d.isLive).toList();
  _mergeList<DocItem>(others, of('doc'),
      enc: _docJson, dec: _docFrom, id: (d) => d.id, cmp: (x, y) => y.id.compareTo(x.id));
  final live = a.docs.where((d) => d.isLive).toList();
  a.docs
    ..clear()
    ..addAll([...others, ...live]);

  _mergeList<ParkingSlot>(a.slots, of('slot'),
      enc: _slotJson, dec: _slotFrom, id: (s) => s.id, cmp: (x, y) => naturalCompare(x.id, y.id));
  _mergeList<ParkingReq>(a.parking, of('request'),
      enc: _requestJson, dec: _requestFrom, id: (r) => r.unit, cmp: (x, y) => x.at.compareTo(y.at));

  if (admin) {
    _mergeList<ActivityEntry>(a.activityLog, of('activity'),
        enc: _activityJson,
        dec: _activityFrom,
        id: (x) => '${x.at.millisecondsSinceEpoch}',
        cmp: (x, y) => y.at.compareTo(x.at));
  }

  // settings
  final st = {for (final r in of('setting')) r.id: r.value};
  a.motorRate = _num(st['motor_rate'] ?? const {}, 'rate');
  a.motorRateDay = _num(st['motor_rate_daily'] ?? const {}, 'rate');
  a.duesRate = _num(st['dues_rate'] ?? const {}, 'rate');
  final pm = st['paymethods']?['list'];
  for (final m in a.payMethods) {
    m.enabled = m.name == AppState.officePay;
    m.details = AppState._defaultDetails[m.name] ?? '';
  }
  if (pm is List) {
    for (final x in pm) {
      if (x is! Map) continue;
      for (final m in a.payMethods.where((m) => m.name == _s(x, 'name'))) {
        m.details = _s(x, 'details', m.details);
        m.enabled = _b(x, 'enabled');
      }
    }
  }
  final am = st['amenities']?['list'];
  a.amenities.clear();
  if (am is List && am.isNotEmpty) {
    for (final x in am) {
      if (x is! Map) continue;
      final name = _s(x, 'name');
      if (name.isEmpty) continue;
      a.amenities.add(Amenity(
          _s(x, 'id', name), name, _s(x, 'open', '08:00'), _s(x, 'close', '20:00'), (_num(x, 'mins', 120).toInt() > 0 ? _num(x, 'mins', 120).toInt() : 120), _s(x, 'note')));
    }
  }
  if (a.amenities.isEmpty) a.amenities.addAll(Amenity.defaults());
  final bl = st['blocked'] ?? const <String, dynamic>{};
  a.blockedDay = _s(bl, 'day');
  a.blocked.clear();
  final keys = bl['keys'];
  if (keys is List) {
    for (final k in keys) {
      a.blocked[k.toString()] = true;
    }
  }
  annualBudget.clear();
  final bm = st['budget']?['map'];
  if (bm is Map) {
    bm.forEach((k, v) {
      if (v is num && v > 0) annualBudget[k.toString()] = v.toInt();
    });
  }
  final dir = st['directory'] ?? const <String, dynamic>{};
  directoryContacts.clear();
  final cs = dir['contacts'];
  if (cs is List) {
    for (final c in cs) {
      if (c is Map) directoryContacts.add(ContactInfo(_s(c, 'name'), _s(c, 'note'), _s(c, 'tel')));
    }
  }
  houseRules.clear();
  final rs = dir['rules'];
  if (rs is List) {
    for (final r in rs) {
      if (r is List && r.length >= 2) houseRules.add([r[0].toString(), r[1].toString()]);
    }
  }

  a.loaded = true;
}
