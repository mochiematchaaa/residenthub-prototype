// ADMIN page: Resident profiles. The household record of each unit (editable, shown on the resident's dashboard) plus everything on record for it, with an Excel export.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/unit_history.dart';
import '../../services/unit_history_export.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';
import '../shared/record_sheet.dart';

class UnitHistoryScreen extends StatefulWidget {
  /// The unit to show. Null shows the list of units to pick from.
  final String? unit;
  const UnitHistoryScreen({super.key, this.unit});

  @override
  State<UnitHistoryScreen> createState() => _UnitHistoryScreenState();
}

class _UnitHistoryScreenState extends State<UnitHistoryScreen> {
  String q = '';
  String filter = histFilters.first;
  int page = 0;
  bool exporting = false;
  static const _pageSize = 10;

  IconData _icon(String kind) => switch (kind) {
        'Charge' => Icons.receipt_long_outlined,
        'Payment' => Icons.payments_outlined,
        'Payment sent' => Icons.outbox_outlined,
        'Booking' => Icons.event_available_outlined,
        'Complaint' => Icons.build_circle_outlined,
        'Parking' => Icons.two_wheeler_outlined,
        _ => Icons.history_rounded,
      };

  Future<void> _export(String unit) async {
    setState(() => exporting = true);
    String? err;
    try {
      err = await exportUnitHistory(unit);
    } catch (_) {
      err = 'Could not make the Excel file.';
    }
    if (!mounted) return;
    setState(() => exporting = false);
    msg(context, err ?? 'Excel file ready for $unit.');
  }

  Widget _picker(BuildContext context) {
    final s = q.trim().toLowerCase();
    final list = [for (final u in app.units) if (s.isEmpty || '${u.unit} ${u.name} ${u.contact}'.toLowerCase().contains(s)) u];
    return SubPage(
      title: 'Resident profiles',
      subtitle: 'Pick a unit to view or edit its resident record, and to see its charges, payments, requests, bookings and office actions.',
      children: [
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search a unit or resident'),
        ),
        for (final u in list)
          RCard(
            onTap: () => go(context, UnitHistoryScreen(unit: u.unit)),
            child: Row(children: [
              Avatar(u.name.isEmpty ? u.unit : u.name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.unit, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(u.name, style: TextStyle(color: muted(context), fontSize: 12.5)),
                ]),
              ),
              if (app.unpaidCountFor(u.unit) > 0) Pill(peso(app.balanceFor(u.unit)), tone: Tone.warn),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        if (list.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No unit matches.', style: TextStyle(color: muted(context)))),
      ],
    );
  }

  Widget _tile(BuildContext context, String label, String value, {Tone? tone}) {
    final t = tone == null ? null : toneOf(context, tone);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t?.bg ?? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(color: t?.fg ?? muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value, style: hd(17, color: t?.fg)),
      ]),
    );
  }

  /// The household record: view it here, edit it, and the resident sees it on their dashboard.
  Widget _recordCard(BuildContext context, Unit u) {
    final acc = app.trusted.where((t) => t.unit == u.unit).toList();
    return RecordSheet(
      u: u,
      admin: true,
      email: acc.isEmpty ? '' : acc.first.email,
      action: FilledButton.icon(onPressed: () => _editRecord(context, u), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit record')),
    );
  }

  void _editRecord(BuildContext context, Unit u) {
    showFormSheet(
      context,
      title: 'Edit record, ${u.unit}',
      subtitle: 'Saved details show on the resident\'s dashboard. The private office note does not.',
      choices: [
        ChoiceSpec('type', 'Occupancy', const ['Owner', 'Tenant'], u.type == 'Tenant' ? 'Tenant' : 'Owner'),
      ],
      fields: [
        FieldSpec('name', 'Full name', initial: u.name == '—' ? '' : u.name),
        FieldSpec('contact', 'Mobile number', type: TextInputType.phone, initial: u.contact == '—' ? '' : u.contact),
        FieldSpec('email', 'Email', type: TextInputType.emailAddress, initial: u.email),
        FieldSpec('moveIn', 'Moved in (yyyy-mm-dd)', hint: 'e.g. 2022-03-15', initial: u.moveIn),
        FieldSpec('members', 'People living here (one per line)', hint: 'The number of people is counted from this list.', lines: 4, initial: u.members),
        FieldSpec('pets', 'Pets', hint: 'e.g. 1 dog', initial: u.pets),
        FieldSpec('emergencyName', 'Emergency contact name', initial: u.emergencyName),
        FieldSpec('emergencyRelation', 'Relationship', initial: u.emergencyRelation),
        FieldSpec('emergencyPhone', 'Emergency contact number', type: TextInputType.phone, initial: u.emergencyPhone),
        FieldSpec('vehicles', 'Vehicles', hint: 'One per line, e.g. Honda Beat ABC 123', lines: 3, initial: u.vehicles),
        FieldSpec('noteResident', 'Note shown to the resident', lines: 2, initial: u.noteResident),
        FieldSpec('noteOffice', 'Private office note (not shown)', lines: 2, initial: u.noteOffice),
      ],
      submit: 'Save record',
      onSubmit: (v) {
        final mi = (v['moveIn'] ?? '').toString().trim();
        if (mi.isNotEmpty && DateTime.tryParse(mi) == null) return 'Write the move-in date like 2022-03-15.';
        app.saveRecord(u, {for (final e in v.entries) e.key: (e.value ?? '').toString()});
        return null;
      },
    );
  }

  /// Billed and paid for the last six months, as two bars per month.
  Widget _chart(BuildContext context, UnitSummary s) {
    final now = DateTime.now();
    final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final billed = List<num>.filled(6, 0), paid = List<num>.filled(6, 0);
    for (final d in s.charges) {
      final b = parseShortDate(d.billed);
      if (b == null) continue;
      final i = months.indexWhere((m) => m.year == b.year && m.month == b.month);
      if (i >= 0) billed[i] += d.amt;
    }
    for (final p in s.payments) {
      final i = months.indexWhere((m) => m.year == p.when.year && m.month == p.when.month);
      if (i >= 0) paid[i] += p.amount;
    }
    final top = [...billed, ...paid].fold<num>(0, (a, b) => a > b ? a : b);
    if (top <= 0) return const SizedBox.shrink();
    const h = 110.0;
    Widget bar(num v, Color c) => Container(width: 14, height: (v / top * h).clamp(2, h).toDouble(), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Billed and paid, last 6 months', style: hd(16)),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: lavDeep, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text('Billed', style: TextStyle(color: muted(context), fontSize: 12)),
          const SizedBox(width: 12),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF14A38B), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text('Paid', style: TextStyle(color: muted(context), fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 6; i++)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  bar(billed[i], lavDeep),
                  const SizedBox(width: 3),
                  bar(paid[i], const Color(0xFF14A38B)),
                ]),
                const SizedBox(height: 6),
                Text(names[months[i].month - 1], style: TextStyle(color: muted(context), fontSize: 11)),
              ]),
          ],
        ),
      ]),
    );
  }

  Widget _event(BuildContext context, HistEvent e) {
    final when = e.ts.millisecondsSinceEpoch < 86400000 ? '' : shortDate(e.ts);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: e.receipt == null ? null : () => openReceipt(context, e.receipt!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(_icon(e.kind), tone: e.tone, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (e.sub.isNotEmpty) Text(e.sub, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (e.chip.isNotEmpty) Pill(e.chip, tone: e.tone),
                Text('${e.kind}${when.isEmpty ? '' : ' · $when'}', style: TextStyle(color: muted(context), fontSize: 11.5)),
              ]),
            ]),
          ),
          if (e.amount != null) Text(peso(e.amount!), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    if (unit == null) return ListenableBuilder(listenable: app, builder: (c, _) => _picker(c));
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = unitSummary(unit);
        if (s == null) {
          return SubPage(title: 'Resident profiles', subtitle: 'That unit is no longer on record.', children: const []);
        }
        final cat = histCat(filter);
        final all = unitEvents(unit);
        final list = cat.isEmpty ? all : all.where((e) => e.cat == cat).toList();
        final pages = list.isEmpty ? 1 : (list.length + _pageSize - 1) ~/ _pageSize;
        final pg = page.clamp(0, pages - 1);
        final shown = list.skip(pg * _pageSize).take(_pageSize).toList();
        final u = s.unit;
        return SubPage(
          title: u.unit,
          subtitle: 'Resident profile and history',
          actions: [
            IconButton(
              tooltip: 'Export to Excel',
              onPressed: exporting ? null : () => _export(unit),
              icon: const Icon(Icons.download_rounded),
            ),
          ],
          children: [
            RCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(u.name.isEmpty ? u.unit : u.name, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.name, style: hd(19)),
                      Text('${u.type} · ${usageLabel(u.usage)}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                _kv(context, 'Contact', u.contact.isEmpty ? '—' : u.contact),
                _kv(context, 'Floor area', u.area > 0 ? '${u.area} sqm' : 'Not set'),
                _kv(context, 'Due day', u.dueDay > 0 ? 'Day ${u.dueDay} of every month' : 'Not set'),
                _kv(context, 'Parking', s.slot.isEmpty ? 'None' : 'Slot ${s.slot}'),
                _kv(context, 'Sign-ins', s.accounts.isEmpty ? 'No account yet' : s.accounts.map((a) => a.email).join(', ')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: exporting ? null : () => _export(unit),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: Text(exporting ? 'Making the file…' : 'Export to Excel (with charts)'),
                  ),
                ),
              ]),
            ),
            _recordCard(context, u),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _tile(context, 'Balance', peso(s.dues.balance), tone: s.dues.balance > 0 ? Tone.warn : Tone.good),
              _tile(context, 'Total paid', peso(s.dues.paid)),
              _tile(context, 'Open charges', '${s.open.length}${s.overdue > 0 ? ' · ${s.overdue} overdue' : ''}', tone: s.overdue > 0 ? Tone.bad : null),
              _tile(context, 'Open requests', '${s.openRequests}', tone: s.openRequests > 0 ? Tone.warn : null),
              _tile(context, 'Last payment', s.last == null ? 'None yet' : s.last!.date),
            ]),
            _chart(context, s),
            FilterRow(
              options: histFilters,
              selected: filter,
              onSelect: (v) => setState(() {
                filter = v;
                page = 0;
              }),
            ),
            RCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${list.length} record${list.length == 1 ? '' : 's'}', style: hd(16)),
                if (shown.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Nothing on record here yet.', style: TextStyle(color: muted(context)))),
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _event(context, shown[i]),
                ],
                if (pages > 1) ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton.icon(onPressed: pg == 0 ? null : () => setState(() => page = pg - 1), icon: const Icon(Icons.chevron_left_rounded), label: const Text('Newer')),
                    Text('Page ${pg + 1} of $pages', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    TextButton.icon(
                      onPressed: pg >= pages - 1 ? null : () => setState(() => page = pg + 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Older'),
                    ),
                  ]),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }
}

Widget _kv(BuildContext context, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(k, style: TextStyle(color: muted(context), fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
