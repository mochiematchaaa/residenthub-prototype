/// What the office needs to know for each way a unit can be used (same fields as the website).
/// Pure data: it does not import the app state.

enum UsageFieldType { text, phone, number, date, select, multiline }

/// One input of a unit-usage form.
class UsageField {
  final String key, label;
  final bool required;
  final UsageFieldType type;
  final String hint;
  final List<String> options;
  const UsageField(this.key, this.label,
      {this.required = false, this.type = UsageFieldType.text, this.hint = '', this.options = const []});
}

/// The fields a resident fills for a usage (tenant, short-term, business...).
class UsageForm {
  final String title;
  final List<UsageField> fields;

  /// Papers to bring to the office.
  final List<String> bring;
  const UsageForm(this.title, this.fields, this.bring);
}

const usageForms = <String, UsageForm>{
  'tenant': UsageForm(
    'Tenant details',
    [
      UsageField('tname', "Tenant's full name", required: true),
      UsageField('tphone', "Tenant's mobile number", required: true, type: UsageFieldType.phone, hint: '0917 123 4567'),
      UsageField('occupants', 'Number of people staying', required: true, type: UsageFieldType.number, hint: 'e.g. 3'),
      UsageField('start', 'Lease starts', required: true, type: UsageFieldType.date),
      UsageField('end', 'Lease ends', type: UsageFieldType.date),
      UsageField('emerg', 'Emergency contact (name and number)', hint: 'e.g. Ana Cruz, 0917 555 0000'),
      UsageField('plates', 'Vehicle plate numbers (if any)', hint: 'e.g. ABC 1234'),
    ],
    ['Copy of the signed lease contract', 'Valid ID of every adult tenant', 'Emergency contact of the tenant'],
  ),
  'shortterm': UsageForm(
    'Short-term rental details',
    [
      UsageField('platform', 'Where it is listed',
          required: true,
          type: UsageFieldType.select,
          options: ['Airbnb', 'Booking.com', 'Agoda', 'Facebook or direct bookings', 'Other']),
      UsageField('contact', 'Person in charge on site', required: true, hint: 'Who the office can call'),
      UsageField('phone', 'Their mobile number', required: true, type: UsageFieldType.phone, hint: '0917 123 4567'),
      UsageField('start', 'Renting out since', type: UsageFieldType.date),
      UsageField('listing', 'Listing name or link (optional)', hint: 'e.g. Cozy studio near the park'),
    ],
    ['Valid ID of the person in charge', 'Business or tourism permit, if the city requires one'],
  ),
  'business': UsageForm(
    'Business details',
    [
      UsageField('bname', 'Business name', required: true),
      UsageField('btype', 'Type of business', required: true, hint: 'e.g. Online selling, tutoring, home office'),
      UsageField('permit', "Business permit number (DTI or Mayor's permit)", required: true),
      UsageField('hours', 'Operating hours', hint: 'e.g. Mon to Fri, 9 AM to 5 PM'),
      UsageField('phone', 'Contact number', required: true, type: UsageFieldType.phone, hint: '0917 123 4567'),
    ],
    ['Copy of the business permit', 'Valid ID of the owner', 'Any permit needed for signs or deliveries'],
  ),
  'renovation': UsageForm(
    'Renovation details',
    [
      UsageField('work', 'What work will be done', required: true, type: UsageFieldType.multiline, hint: 'e.g. New tiles in the kitchen and bathroom'),
      UsageField('contractor', 'Contractor or foreman', required: true),
      UsageField('phone', "Contractor's mobile number", required: true, type: UsageFieldType.phone, hint: '0917 123 4567'),
      UsageField('start', 'Work starts', required: true, type: UsageFieldType.date),
      UsageField('end', 'Expected finish', required: true, type: UsageFieldType.date),
    ],
    ['Work permit request, signed by the owner', 'Valid ID of the contractor and workers', 'List of materials and equipment brought in'],
  ),
};

/// A Philippine mobile number: 0917 123 4567, +63 917 123 4567 or 9171234567.
bool phoneOk(String raw) {
  var d = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (d.startsWith('+')) d = d.substring(1);
  if (d.startsWith('63')) {
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = d.substring(1);
  }
  return RegExp(r'^9\d{9}$').hasMatch(d);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-11-01" to "Nov 1, 2026".
String usageDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return iso;
  return '${_months[int.parse(m.group(2)!) - 1]} ${int.parse(m.group(3)!)}, ${m.group(1)}';
}

/// One short line for lists and the update history.
String usageSummary(String type, Map<String, String> i) {
  String g(String k) => i[k] ?? '';
  final parts = switch (type) {
    'tenant' => [g('tname'), g('tphone'), g('occupants').isEmpty ? '' : '${g('occupants')} staying', g('start').isEmpty ? '' : 'from ${usageDate(g('start'))}'],
    'shortterm' => [g('platform'), g('contact').isEmpty ? '' : 'on site: ${g('contact')}', g('phone')],
    'business' => [g('bname'), g('btype'), g('permit').isEmpty ? '' : 'permit ${g('permit')}'],
    'renovation' => [g('work'), g('contractor'), (g('start').isEmpty || g('end').isEmpty) ? '' : '${usageDate(g('start'))} to ${usageDate(g('end'))}'],
    _ => <String>[],
  };
  return parts.where((p) => p.isNotEmpty).join(' · ');
}

/// [label, text] pairs to show a saved declaration.
List<List<String>> usageInfoRows(String type, Map<String, String> i) {
  final f = usageForms[type];
  if (f == null) return const [];
  return [
    for (final x in f.fields)
      if ((i[x.key] ?? '').isNotEmpty) [x.label, x.type == UsageFieldType.date ? usageDate(i[x.key]!) : i[x.key]!],
  ];
}

/// Checks a filled-in form. Returns a message for the first problem, or null.
String? validateUsage(String type, Map<String, String> i) {
  final f = usageForms[type];
  if (f == null) return null;
  for (final x in f.fields) {
    final v = (i[x.key] ?? '').trim();
    if (x.required && v.isEmpty) return 'Please fill in: ${x.label}.';
    if (v.isNotEmpty && x.type == UsageFieldType.phone && !phoneOk(v)) {
      return '${x.label} must be a Philippine mobile number, e.g. 0917 123 4567.';
    }
    if (v.isNotEmpty && x.type == UsageFieldType.number) {
      final n = int.tryParse(v);
      if (n == null || n < 1 || n > 999) return '${x.label} must be a number, 1 or more.';
    }
  }
  final s = i['start'] ?? '', e = i['end'] ?? '';
  if (s.isNotEmpty && e.isNotEmpty && e.compareTo(s) < 0) return 'The end date must be after the start date.';
  return null;
}
