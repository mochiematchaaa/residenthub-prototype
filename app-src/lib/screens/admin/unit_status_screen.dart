// ADMIN page: Unit usage (owner, rental, business) and approvals.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';

/// Admin view: the current state of every unit, a feed of recent updates,
/// and the ability to set a unit's status.
class AdminUnitStatus extends StatefulWidget {
  const AdminUnitStatus({super.key});

  @override
  State<AdminUnitStatus> createState() => _AdminUnitStatusState();
}

class _AdminUnitStatusState extends State<AdminUnitStatus> {
  String filter = 'all';
  int _unitPage = 0, _reviewPage = 0;

  @override
  void initState() {
    super.initState();
    // Opening this screen counts as having seen the new resident updates.
    WidgetsBinding.instance.addPostFrameCallback((_) => app.markStatusSeen());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        int count(String k) => app.units.where((u) => u.usage == k).length;
        final labels = <String, String>{
          'all': 'All (${app.units.length})',
          for (final o in statusOptions) o.key: '${o.label} (${count(o.key)})',
        };
        final rows = app.units.where((u) => filter == 'all' || u.usage == filter).toList();
        final feed = app.statusUpdates.take(6).toList();
        final review = app.units.where((u) => u.needsApproval && u.usageStatus == 'pending').toList();
        return SubPage(
          title: 'Unit status',
          subtitle: 'The current state of every unit, kept up to date by residents. You can update any unit too.',
          children: [
            const ImportBar(['usage']),
            PastelCard(
              color: Pastel.pink,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['Occupied', '${count('owner') + count('tenant') + count('shortterm') + count('business')}'],
                ['Rented', '${count('tenant') + count('shortterm')}'],
                ['Business', '${count('business')}'],
                ['Vacant', '${count('vacant')}'],
              ]),
            ),
            if (review.isNotEmpty) ...[
              Text('Declarations to review', style: hd(18)),
              for (final u in pageOf(review, _reviewPage, 5)) _reviewCard(context, u),
              PagerBar(page: _reviewPage, per: 5, total: review.length, onPage: (p) => setState(() => _reviewPage = p)),
            ],
            FilterRow(
              options: labels.values.toList(),
              selected: labels[filter]!,
              onSelect: (v) => setState(() {
                filter = labels.entries.firstWhere((e) => e.value == v).key;
                _unitPage = 0;
              }),
            ),
            if (rows.isEmpty) const EmptyBox('No units in this state.', icon: Icons.apartment_outlined),
            for (final u in pageOf(rows, _unitPage, 8)) _unitCard(context, u),
            PagerBar(page: _unitPage, per: 8, total: rows.length, onPage: (p) => setState(() => _unitPage = p)),
            Text('Recent updates', style: hd(18)),
            RCard(
              child: Column(
                children: [
                  for (var i = 0; i < feed.length; i++) _feedRow(context, feed[i], last: i == feed.length - 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _reviewCard(BuildContext context, Unit u) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${u.unit}${u.name == '—' ? '' : ' · ${u.name}'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Pill(usageLabel(u.usage), tone: Tone.warn),
            ],
          ),
          if (usageInfoRows(u.usage, u.usageInfo).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: toneOf(context, Tone.info).bg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in usageInfoRows(u.usage, u.usageInfo))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r[0], style: TextStyle(color: muted(context), fontSize: 11.5)),
                          Text(r[1], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ] else if (u.statusNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(u.statusNote, style: TextStyle(color: muted(context), fontSize: 13, height: 1.35)),
          ],
          if (u.statusDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Declared ${u.statusDate}', style: TextStyle(color: muted(context), fontSize: 11.5)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    app.reviewUsage(u, true, '');
                    msg(context, '${u.unit} approved.');
                  },
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showFormSheet(
                    context,
                    title: 'Reject ${u.unit}',
                    subtitle: 'The resident will see your note.',
                    fields: const [FieldSpec('note', 'Note to the resident', hint: 'Why it was not approved', lines: 3)],
                    submit: 'Reject',
                    onSubmit: (v) {
                      app.reviewUsage(u, false, v['note'] as String);
                      return null;
                    },
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitCard(BuildContext context, Unit u) {
    final o = statusOf(u.usage);
    return PastelCard(
      color: o.color,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      onTap: () => showAdminStatusSheet(context, u),
      child: Row(
        children: [
          GlassIcon(o.icon, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: u.unit, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  TextSpan(text: u.name == '—' ? '' : '  ${u.name}', style: const TextStyle(color: inkSoft, fontSize: 12.5)),
                ])),
                const SizedBox(height: 2),
                Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (u.statusNote.isNotEmpty)
                  Text(u.statusNote, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: inkSoft, fontSize: 12, height: 1.3)),
                if (u.statusDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Updated ${u.statusDate}', style: const TextStyle(color: inkSoft, fontSize: 11.5)),
                  ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 20),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _feedRow(BuildContext context, StatusUpdate u, {required bool last}) {
    final o = statusOf(u.key);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: o.color.color, shape: BoxShape.circle, border: Border.all(color: lavDeep, width: 2)),
              ),
              if (!last) Expanded(child: Container(width: 2, color: Theme.of(context).colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${u.unit} → ${o.label}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      Text(u.date, style: TextStyle(color: muted(context), fontSize: 11.5)),
                    ],
                  ),
                  if (u.note.isNotEmpty) Text(u.note, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.3)),
                  Text('by ${u.by}', style: TextStyle(color: muted(context), fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form sheet used by the admin to set a unit's status (also called from the Units tab).
void showAdminStatusSheet(BuildContext context, Unit u) {
  final byLabel = {for (final o in statusOptions) o.label: o.key};
  showFormSheet(
    context,
    title: 'Update ${u.unit}',
    subtitle: u.name == '—' ? 'No resident on record.' : u.name,
    fields: [FieldSpec('note', 'Note', hint: 'Optional, shown in the update history', lines: 2, initial: u.statusNote)],
    choices: [ChoiceSpec('status', 'Status', byLabel.keys.toList(), statusOf(u.usage).label)],
    submit: 'Save status',
    onSubmit: (v) {
      app.adminSetStatus(u, byLabel[v['status'] as String] ?? u.usage, v['note'] as String);
      return null;
    },
  );
}
