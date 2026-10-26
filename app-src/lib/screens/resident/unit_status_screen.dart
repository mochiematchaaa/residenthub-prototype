// RESIDENT page: Unit status (how the unit is used) and the declaration form.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident posts the current state of their unit; the administrator sees it right away.
class ResUnitStatus extends StatefulWidget {
  const ResUnitStatus({super.key});

  @override
  State<ResUnitStatus> createState() => _ResUnitStatusState();
}

class _ResUnitStatusState extends State<ResUnitStatus> {
  String sel = 'owner';
  final note = TextEditingController();
  String? error;

  // What was typed, kept per way of using the unit so switching tiles does not lose it.
  final Map<String, TextEditingController> _c = {};
  final Map<String, String> _vals = {};
  final Set<String> _agreed = {};

  String _initial(String k) {
    final r = app.myUnitRec;
    return (r != null && r.usage == sel) ? (r.usageInfo[k] ?? '') : '';
  }

  TextEditingController _ctrl(String k) => _c.putIfAbsent('$sel.$k', () => TextEditingController(text: _initial(k)));
  String _v(String k) => _vals['$sel.$k'] ?? _initial(k);
  bool get _agree => _agreed.contains(sel) || (!_agreed.contains('!$sel') && app.myUnitRec?.usage == sel && app.myUnitRec?.usageInfo['agree'] == 'true');

  Map<String, String> _collect(UsageForm form) {
    final out = <String, String>{};
    for (final f in form.fields) {
      final v = (f.type == UsageFieldType.date || f.type == UsageFieldType.select) ? _v(f.key) : _ctrl(f.key).text;
      out[f.key] = v.trim();
    }
    if (_agree) out['agree'] = 'true';
    return out;
  }

  Widget _field(BuildContext context, UsageField f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.type) {
      case UsageFieldType.date:
        final v = _v(f.key);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final cur = DateTime.tryParse(v) ?? now;
            final d = await showDatePicker(
              context: context,
              initialDate: cur,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 10),
            );
            if (d != null) setState(() => _vals['$sel.${f.key}'] = dayKey(d));
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_month_rounded, size: 20)),
            child: Text(v.isEmpty ? 'Choose a date' : usageDate(v),
                style: TextStyle(fontWeight: FontWeight.w600, color: v.isEmpty ? muted(context) : null)),
          ),
        );
      case UsageFieldType.select:
        final v = _v(f.key);
        return DropdownButtonFormField<String>(
          initialValue: f.options.contains(v) ? v : null,
          decoration: InputDecoration(labelText: label),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (x) => setState(() => _vals['$sel.${f.key}'] = x ?? ''),
        );
      default:
        return TextField(
          controller: _ctrl(f.key),
          minLines: f.type == UsageFieldType.multiline ? 2 : 1,
          maxLines: f.type == UsageFieldType.multiline ? 3 : 1,
          keyboardType: f.type == UsageFieldType.phone
              ? TextInputType.phone
              : f.type == UsageFieldType.number
                  ? TextInputType.number
                  : (f.type == UsageFieldType.multiline ? TextInputType.multiline : null),
          decoration: InputDecoration(labelText: label, hintText: f.hint),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    final r = app.myUnitRec;
    if (r != null && r.usage.isNotEmpty) sel = r.usage;
  }

  @override
  void dispose() {
    note.dispose();
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final rec = app.myUnitRec;
        final cur = statusOf(rec?.usage ?? 'owner');
        final history = app.myStatusUpdates;
        final opt = statusOf(sel);
        return SubPage(
          title: 'Unit Rental',
          subtitle: 'Tell the office how your unit is used, and what they need to know.',
          children: [
            // --- current status
            PastelCard(
              color: cur.color,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlassIcon(cur.icon, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${app.myUnit} is currently', style: const TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(cur.label, style: hd(23)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (rec != null && usageInfoRows(rec.usage, rec.usageInfo).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final r in usageInfoRows(rec.usage, rec.usageInfo))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r[0], style: const TextStyle(color: inkSoft, fontSize: 11.5)),
                            Text(r[1], style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                          ],
                        ),
                      ),
                  ] else if (rec != null && rec.statusNote.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(rec.statusNote, style: const TextStyle(color: inkSoft, height: 1.35)),
                  ],
                  if (rec != null && rec.statusDate.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Last updated ${rec.statusDate}', style: const TextStyle(color: inkSoft, fontSize: 12)),
                  ],
                  if (rec != null && rec.needsApproval) ...[
                    const SizedBox(height: 14),
                    _approval(rec),
                  ],
                ],
              ),
            ),

            // --- post an update
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Declare how your unit is used', style: hd(18)),
                  const SizedBox(height: 4),
                  Text('Pick how the unit is used, then fill in the details the office needs.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: [for (final o in statusOptions) _tile(context, o)],
                  ),
                  const SizedBox(height: 14),
                  if (usageForms[sel] != null) ...[
                    Text(usageForms[sel]!.title, style: hd(16)),
                    const SizedBox(height: 10),
                    for (final f in usageForms[sel]!.fields) ...[
                      _field(context, f),
                      const SizedBox(height: 12),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _agree,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _agreed.add(sel);
                          _agreed.remove('!$sel');
                        } else {
                          _agreed.remove(sel);
                          _agreed.add('!$sel');
                        }
                      }),
                      title: Text('${usageForms[sel]!.agree} *', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: toneOf(context, (sel == 'shortterm' || sel == 'business') ? Tone.warn : Tone.good).bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        (sel == 'shortterm' || sel == 'business')
                            ? "This type needs the administrator's approval before it is active. You will see the decision on this page."
                            : 'This type is saved right away. No approval is needed.',
                        style: TextStyle(
                          color: toneOf(context, (sel == 'shortterm' || sel == 'business') ? Tone.warn : Tone.good).fg,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ] else
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Note', hintText: opt.hint),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final form = usageForms[sel];
                        final err = app.declareUnit(sel, form == null ? {} : _collect(form), note.text);
                        setState(() => error = err);
                        if (err == null) {
                          final needs = sel == 'shortterm' || sel == 'business';
                          note.clear();
                          msg(context, needs ? "Sent. The administrator will review it, and you will see the decision here." : 'Saved. The administrator can see it now.');
                        }
                      },
                      child: Text((sel == 'shortterm' || sel == 'business') ? 'Send for review' : 'Save declaration'),
                    ),
                  ),
                ],
              ),
            ),

            // --- what to bring
            if (usageForms[sel] != null)
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What to bring to the office', style: hd(18)),
                    const SizedBox(height: 4),
                    Text('Have these ready when you visit. The office keeps copies on file.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                    const SizedBox(height: 10),
                    for (final t in usageForms[sel]!.bring)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 18, color: toneOf(context, Tone.good).fg),
                            const SizedBox(width: 8),
                            Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5, height: 1.35))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // --- history
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update history', style: hd(18)),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    Text('No updates yet.', style: TextStyle(color: muted(context)))
                  else
                    for (var i = 0; i < history.length; i++) _historyRow(context, history[i], last: i == history.length - 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Short-term rentals and home businesses wait for the administrator's decision.
  Widget _approval(Unit rec) {
    final st = rec.usageStatus.isEmpty ? 'pending' : rec.usageStatus;
    final decided = st != 'pending';
    final rejected = st == 'rejected';
    Widget step(String label, bool done, {bool bad = false}) => Expanded(
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: bad ? danger : (done ? ink : Colors.white.withAlpha(190)), shape: BoxShape.circle),
                child: Icon(bad ? Icons.close_rounded : (done ? Icons.check_rounded : Icons.more_horiz_rounded),
                    size: 16, color: done || bad ? Colors.white : ink),
              ),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            step('Declared', true),
            step('Under review', decided),
            step(rejected ? 'Not approved' : 'Approved', decided, bad: rejected),
          ]),
          const SizedBox(height: 10),
          Text(
            st == 'pending'
                ? 'Waiting for the administrator to review this.'
                : st == 'approved'
                    ? 'The administrator approved this.'
                    : 'Not approved. ${rec.usageRemark}',
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, StatusUpdate u, {required bool last}) {
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(o.label, tone: o.tone),
                      const Spacer(),
                      Text(u.date, style: TextStyle(color: muted(context), fontSize: 12)),
                    ],
                  ),
                  if (u.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(u.note, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                  ],
                  const SizedBox(height: 2),
                  Text('Posted by ${u.by}', style: TextStyle(color: muted(context), fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, StatusOption o) {
    final active = sel == o.key;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() {
        sel = o.key;
        error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? o.color.color : cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? ink : cs.outlineVariant, width: active ? 2 : 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(o.icon, color: active ? ink : cs.onSurfaceVariant),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: active ? ink : cs.onSurface)),
                const SizedBox(height: 2),
                Text(o.help, style: TextStyle(fontSize: 11.5, height: 1.25, color: active ? inkSoft : cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
