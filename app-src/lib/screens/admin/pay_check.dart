// ADMIN: the "Did they pay?" card. Charges that are due (or past due) with no payment on record and nothing sent by the
// resident may already have been paid. For each one the office answers Yes (mark it paid, enter what was really paid;
// a short payment leaves a balance) or No (optionally add a late charge, remind the resident, or call / text them).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/texting.dart';
import '../../widgets/widgets.dart';

class PayCheckCard extends StatefulWidget {
  /// How many to show at first (0 = all).
  final int limit;

  /// Shown on the dashboard: adds an "Open in Finance" button.
  final VoidCallback? onOpenAll;
  const PayCheckCard({super.key, this.limit = 0, this.onOpenAll});

  @override
  State<PayCheckCard> createState() => _PayCheckCardState();
}

class _PayCheckCardState extends State<PayCheckCard> {
  bool _all = false;

  /// The Finance page shows a few charges at a time (page by page), with a filter.
  static const _pageSize = 8;
  int _page = 0;
  String _filter = 'All';

  String _when(int days) => days <= 0 ? 'Due today' : 'Overdue by $days day${days == 1 ? '' : 's'}';

  List<String> get _methods => [for (final m in app.payMethods) m.name];

  void _yes(Due d) {
    final methods = _methods;
    showFormSheet(
      context,
      title: 'Yes, ${d.unit} paid',
      subtitle: '${d.note} · charge of ${peso(d.amount)}. Enter what they really paid. If it is less than the charge, the rest stays as a balance on their dues. A receipt is issued and the resident sees it right away.',
      choices: [ChoiceSpec('method', 'How they paid', methods, methods.contains('GCash') ? 'GCash' : methods.first)],
      fields: [
        FieldSpec('amount', 'Amount they paid (₱)', type: TextInputType.number, initial: d.amount.toStringAsFixed(2)),
        const FieldSpec('date', 'Date they paid (optional)', hint: 'Like Oct 25, 2026. Empty = today'),
        const FieldSpec('ref', 'Reference no. (optional)'),
      ],
      submit: 'Mark as paid',
      onSubmit: (v) {
        final r = app.payCheckYes(d, amountRaw: v['amount'] as String, method: v['method'] as String, dateRaw: v['date'] as String, reference: v['ref'] as String);
        if (r.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              msg(context, r.left > 0
                  ? 'Recorded for ${d.unit}. The balance of ${peso(r.left)} stays on their dues. Receipt ${r.receipt}.'
                  : 'Marked paid. Receipt ${r.receipt} issued to ${d.unit}.');
            }
          });
        }
        return r.error;
      },
    );
  }

  void _no(Due d) {
    final ph = app.unitPhone(d.unit);
    showFormSheet(
      context,
      title: '${d.unit} has not paid',
      subtitle: '${d.note} · ${peso(d.amount)}. Choose what to do. ${ph.isEmpty ? 'There is no mobile number on file for this unit.' : 'You can also call or text ${d.unit} from the list.'}',
      choices: [
        ChoiceSpec('late', 'Add a late charge?', const ['Yes, add a late charge', 'No late charge'], d.lateFeeId > 0 ? 'No late charge' : 'Yes, add a late charge'),
        const ChoiceSpec('notify', 'Tell the resident in the app?', ['Yes, send a reminder', 'No'], 'Yes, send a reminder'),
      ],
      fields: [
        FieldSpec('pct', 'Late charge (% of this charge)', type: TextInputType.number, initial: '${app.latePct}', onlyWhenKey: 'late', onlyWhenValue: 'Yes, add a late charge'),
        const FieldSpec('msg', 'Message to the resident (you can edit it)', lines: 3, initial: AppState.payCheckNoMsg),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final r = app.payCheckNo(d,
            late: (v['late'] as String).startsWith('Yes'), pctRaw: v['pct'] as String, notify: (v['notify'] as String).startsWith('Yes'), message: v['msg'] as String);
        if (r.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) msg(context, r.done);
          });
        }
        return r.error;
      },
    );
  }

  void _askAll() {
    final l = app.payCheckList;
    if (l.isEmpty) return;
    final units = {for (final x in l) x.due.unit};
    showFormSheet(
      context,
      title: 'Ask everyone to send proof',
      subtitle: 'Sends a reminder to ${units.length} unit${units.length == 1 ? '' : 's'} (${l.length} charge${l.length == 1 ? '' : 's'}). A resident who already paid can then send the payment details and a photo, and it posts to their dues by itself, so you do not have to go one by one.',
      fields: const [FieldSpec('msg', 'Message to the residents (you can edit it)', lines: 3, initial: AppState.payCheckAsk)],
      submit: 'Send to all',
      onSubmit: (v) {
        final n = app.payCheckAskAll(v['msg'] as String);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) msg(context, 'Sent to $n unit${n == 1 ? '' : 's'}.');
        });
        return null;
      },
    );
  }

  Widget _row(BuildContext context, Due d, int days) {
    final ph = app.unitPhone(d.unit);
    final tone = days >= 3 ? Tone.bad : Tone.warn;
    final sms = 'Good day! This is the administration office. Our records show ${d.note} (${peso(d.amount)}) is still unpaid. If you already paid, please send your payment details under Dues in the ResidentHub app so your balance updates. Thank you!';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: toneOf(context, Tone.info).bg.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Avatar(d.unit.replaceFirst(RegExp(r'^Unit\s*', caseSensitive: false), ''), size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name.isEmpty ? d.unit : '${d.unit} · ${d.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${d.note} · due ${d.dueDate}', style: TextStyle(color: muted(context), fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(peso(d.amount), style: hd(17)),
              Text('Did they pay?', style: TextStyle(color: muted(context), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            Pill(_when(days), tone: tone),
            if (d.remindedOn.isNotEmpty) Pill('Reminded ${d.remindedOn}'),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _yes(d), child: const Text('Yes, paid')),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _no(d), child: const Text('No')),
              if (ph.isNotEmpty) ...[
                TextButton.icon(onPressed: () => callNumber(context, ph), icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call')),
                TextButton.icon(onPressed: () => textOne(context, ph, sms), icon: const Icon(Icons.sms_outlined, size: 18), label: const Text('SMS')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = app.payCheckList;
    if (l.isEmpty) return const SizedBox.shrink();
    final units = {for (final x in l) x.due.unit};
    final total = l.fold<num>(0, (s, x) => s + x.due.amount);
    final overdue = l.where((x) => x.days > 0).toList();
    final paged = widget.limit == 0;
    final filtered = !paged ? l : (_filter == 'Overdue' ? overdue : (_filter == 'Today' ? l.where((x) => x.days <= 0).toList() : l));
    final pages = filtered.isEmpty ? 1 : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final pg = _page < 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
    final shown = paged ? filtered.skip(pg * _pageSize).take(_pageSize).toList() : ((widget.limit > 0 && !_all) ? l.take(widget.limit).toList() : l);
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.help_outline_rounded, accent: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Did they pay?', style: hd(17)),
                Text('${l.length} charge${l.length == 1 ? '' : 's'} · ${units.length} unit${units.length == 1 ? '' : 's'} · ${peso(total)}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'These charges are due or past due with no payment on record. They may have paid without updating the app. Residents who send their payment details are handled by themselves, so only these are left.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: _askAll, child: const Text('Ask everyone to send proof'))),
          if (paged) ...[
            const SizedBox(height: 8),
            FilterRow(
              options: ['All (${l.length})', 'Overdue (${overdue.length})', 'Due today (${l.length - overdue.length})'],
              selected: _filter == 'Overdue' ? 'Overdue (${overdue.length})' : (_filter == 'Today' ? 'Due today (${l.length - overdue.length})' : 'All (${l.length})'),
              onSelect: (v) => setState(() {
                _filter = v.startsWith('Overdue') ? 'Overdue' : (v.startsWith('Due today') ? 'Today' : 'All');
                _page = 0;
              }),
            ),
          ],
          for (final x in shown) _row(context, x.due, x.days),
          if (paged && filtered.length > _pageSize)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(onPressed: pg == 0 ? null : () => setState(() => _page = pg - 1), child: const Text('‹ Prev')),
                  Text('${pg * _pageSize + 1}–${(pg + 1) * _pageSize > filtered.length ? filtered.length : (pg + 1) * _pageSize} of ${filtered.length}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  OutlinedButton(onPressed: pg >= pages - 1 ? null : () => setState(() => _page = pg + 1), child: const Text('Next ›')),
                ],
              ),
            ),
          if (widget.limit > 0 && l.length > widget.limit)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => setState(() => _all = !_all), child: Text(_all ? 'Show fewer' : 'Show all ${l.length}')),
                if (widget.onOpenAll != null) OutlinedButton(onPressed: widget.onOpenAll, child: const Text('Open in Finance')),
              ]),
            ),
        ],
      ),
    );
  }
}
