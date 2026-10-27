// ADMIN Finance: the day-by-day cards (collections chart, who pays when, daily expenses) and the unit dues table.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _wdLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _k(num v) => v >= 1000 ? '${(v / 100).round() / 10}k' : '${v.round()}';

/// Previous / date / next controls shared by the day cards.
class _DayNav extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onChange;
  const _DayNav(this.day, this.onChange);

  @override
  Widget build(BuildContext context) {
    final isToday = dayKey(day) == dayKey(_today());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Previous day',
          onPressed: () => onChange(DateTime(day.year, day.month, day.day - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        TextButton.icon(
          onPressed: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: day,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (p != null) onChange(DateTime(p.year, p.month, p.day));
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(shortDate(day)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Next day',
          onPressed: () => onChange(DateTime(day.year, day.month, day.day + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (!isToday) TextButton(onPressed: () => onChange(_today()), child: const Text('Today')),
      ],
    );
  }
}

Widget _line(BuildContext context, String a, String b, String c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (b.isNotEmpty) Text(b, style: TextStyle(color: muted(context), fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(c, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        ],
      ),
    );

Widget _cardHead(BuildContext context, IconData icon, String title, String sub) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconBadge(icon, accent: true),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: hd(17))),
        ]),
        const SizedBox(height: 8),
        Text(sub, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
      ],
    );

// ---------------------------------------------------------------- daily collections chart

/// Bars for every day of a month: how much was collected each day.
class DailyCollectionsCard extends StatefulWidget {
  const DailyCollectionsCard({super.key});

  @override
  State<DailyCollectionsCard> createState() => _DailyCollectionsCardState();
}

class _DailyCollectionsCardState extends State<DailyCollectionsCard> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final vals = app.collectedPerDay(month.year, month.month);
    final maxV = vals.fold<double>(0, (m, v) => v > m ? v : m);
    final total = vals.fold<double>(0, (s, v) => s + v);
    final days = vals.where((v) => v > 0).length;
    var best = 0;
    for (var i = 0; i < vals.length; i++) {
      if (vals[i] > vals[best]) best = i;
    }
    final now = DateTime.now();
    final canNext = month.year < now.year || (month.year == now.year && month.month < now.month);
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(context, Icons.bar_chart_rounded, 'Daily collections', 'Money received on each day of the month.'),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(child: Text(monthYear(month), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: canNext ? () => setState(() => month = DateTime(month.year, month.month + 1, 1)) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Text(peso(total), style: hd(24)),
          Text(
            total == 0 ? 'Nothing collected this month.' : '$days day${days == 1 ? '' : 's'} with payments · best day ${shortDate(DateTime(month.year, month.month, best + 1))} (${peso(vals[best])})',
            style: TextStyle(color: muted(context), fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < vals.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${shortDate(DateTime(month.year, month.month, i + 1))}: ${peso(vals[i])}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (vals[i] > 0 && vals.length <= 31)
                              SizedBox(
                                height: 12,
                                child: OverflowBox(
                                  maxWidth: 34,
                                  child: Text(_k(vals[i]), maxLines: 1, softWrap: false, style: TextStyle(color: muted(context), fontSize: 8.5)),
                                ),
                              ),
                            Container(
                              height: maxV == 0 ? 3 : (vals[i] / maxV * 100).clamp(3, 100).toDouble(),
                              decoration: BoxDecoration(
                                color: vals[i] == 0 ? Theme.of(context).colorScheme.outlineVariant : (i == best ? lavDeep : lav),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 12,
                              child: OverflowBox(
                                maxWidth: 24,
                                child: Text(i == 0 || (i + 1) % 5 == 0 ? '${i + 1}' : '', maxLines: 1, softWrap: false, style: TextStyle(color: muted(context), fontSize: 9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- day by day

/// Who paid on a day (today and before) and which charges fall due on a day (today and after).
class DayByDayCard extends StatefulWidget {
  const DayByDayCard({super.key});

  @override
  State<DayByDayCard> createState() => _DayByDayCardState();
}

class _DayByDayCardState extends State<DayByDayCard> {
  DateTime sel = _today();

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final isFuture = sel.isAfter(today);
    final paid = app.paymentsOn(sel);
    final due = app.dueOn(sel);
    final paidTotal = paid.fold<num>(0, (s, p) => s + p.amount);
    final dueTotal = due.fold<num>(0, (s, d) => s + d.amt);
    final cs = Theme.of(context).colorScheme;
    final head = '${dayKey(sel) == dayKey(today) ? 'Today' : _wdLong[sel.weekday - 1]}, ${shortDate(sel)}';
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(context, Icons.event_note_rounded, 'Day by day', 'See who paid on each day, and who is expected to pay on the coming days.'),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: _DayNav(sel, (d) => setState(() => sel = d))),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = -3; i <= 3; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final d = DateTime(sel.year, sel.month, sel.day + i);
                    final future = d.isAfter(today);
                    final n = future ? app.dueOn(d).length : app.paymentsOn(d).length;
                    final on = i == 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => sel = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: on ? lavDeep : null,
                            border: Border.all(color: on ? lavDeep : cs.outlineVariant),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              children: [
                                Text(dayKey(d) == dayKey(today) ? 'Today' : _wd[d.weekday - 1], style: TextStyle(fontSize: 10.5, color: on ? Colors.white70 : muted(context))),
                                Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? Colors.white : null)),
                                Text(n == 0 ? '—' : '$n ${future ? 'due' : 'paid'}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: on ? Colors.white : muted(context))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(head, style: hd(16)),
          if (!isFuture) ...[
            const SizedBox(height: 10),
            Text('Paid this day · ${peso(paidTotal)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (paid.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Nobody paid on this day.', style: TextStyle(color: muted(context), fontSize: 12.5)))
            else
              for (final p in paid)
                _line(context, '${p.unit} · ${p.payer}', '${p.forText} · ${p.method}${p.receiptNo.isEmpty ? '' : ' · Receipt ${p.receiptNo}'}', peso(p.amount)),
          ],
          const SizedBox(height: 10),
          Text('${sel.isBefore(today) ? 'Was due this day and still unpaid' : 'Due this day'} · ${peso(dueTotal)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (due.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('No charge falls due on this day.', style: TextStyle(color: muted(context), fontSize: 12.5)))
          else
            for (final d in due) _line(context, '${d.unit}${d.name.isEmpty || d.name == '—' ? '' : ' · ${d.name}'}', d.note, peso(d.amt)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- daily expenses

/// What was bought on one day, next to what was collected that day.
class DailyExpensesCard extends StatefulWidget {
  const DailyExpensesCard({super.key});

  @override
  State<DailyExpensesCard> createState() => _DailyExpensesCardState();
}

class _DailyExpensesCardState extends State<DailyExpensesCard> {
  DateTime day = _today();

  @override
  Widget build(BuildContext context) {
    final items = app.expensesOn(day);
    final spent = items.fold<num>(0, (s, e) => s + e.amount);
    final got = app.paymentsOn(day).fold<num>(0, (s, p) => s + p.amount);
    final net = got - spent;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(context, Icons.shopping_bag_outlined, 'Daily expenses', 'Record what the corporation buys each day.'),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: _DayNav(day, (d) => setState(() => day = d))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 28,
            runSpacing: 8,
            children: [
              _stat(context, 'Collected', peso(got)),
              _stat(context, 'Spent', peso(spent)),
              _stat(context, 'Net', net < 0 ? '-${peso(-net)}' : peso(net)),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Nothing recorded for this day yet.', style: TextStyle(color: muted(context), fontSize: 12.5)))
          else
            for (final e in items) _line(context, e.item, e.payee.isEmpty ? e.category : e.payee, peso(e.amount)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => showAddPurchase(context, day: day),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense'),
              ),
              OutlinedButton(
                onPressed: () => go(context, const AdminExpenses()),
                child: const Text('All expenses & monthly report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17)),
          Text(k, style: TextStyle(color: muted(context), fontSize: 12)),
        ],
      );
}

// ---------------------------------------------------------------- unit dues

/// Each unit's floor area, monthly dues and what it has been billed, paid and still owes. Ten units per page.
class UnitDuesCard extends StatefulWidget {
  const UnitDuesCard({super.key});

  @override
  State<UnitDuesCard> createState() => _UnitDuesCardState();
}

class _UnitDuesCardState extends State<UnitDuesCard> {
  static const _size = 10;
  int page = 0;

  void _editSize(Unit u) {
    showFormSheet(
      context,
      title: 'Unit size and due day · ${u.unit}',
      subtitle: 'Each unit has its own due day, so payments come in all through the month. Each unit pays by its floor area, so bigger units pay more. Monthly dues = floor area × ${app.duesRate > 0 ? '${peso(app.duesRate)} per sqm' : 'the rate per sqm (set it first)'}.',
      fields: [
        FieldSpec('area', 'Floor area (sqm)', type: const TextInputType.numberWithOptions(decimal: true), hint: 'e.g. 45', initial: u.area <= 0 ? '' : u.area.toString()),
        FieldSpec('dueday', 'Dues are due on day (1 to 31)', type: TextInputType.number, hint: 'e.g. 15', initial: u.dueDay <= 0 ? '' : '${u.dueDay}'),
      ],
      choices: const [
        ChoiceSpec('recalc', 'Charges not paid yet', ['Recalculate the unpaid monthly dues', 'Keep them as billed'], 'Recalculate the unpaid monthly dues'),
      ],
      submit: 'Save size',
      onSubmit: (v) {
        final err = app.setUnitArea(u, v['area'] as String, recalc: (v['recalc'] as String).startsWith('Recalculate'), dueDayRaw: v['dueday'] as String);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final n = app.lastRecalcCount;
              msg(context, '${u.unit} is now ${u.area} sqm${app.duesRate > 0 ? ', monthly dues ${peso(app.unitDues(u).monthly)}' : ''}${n > 0 ? '. $n unpaid monthly charge${n == 1 ? '' : 's'} updated.' : '.'}');
            }
          });
        }
        return err;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = app.units;
    final rows = [for (final u in units) (u, app.unitDues(u))];
    final billed = rows.fold<num>(0, (s, r) => s + r.$2.billed);
    final paid = rows.fold<num>(0, (s, r) => s + r.$2.paid);
    final pages = units.isEmpty ? 1 : (units.length + _size - 1) ~/ _size;
    final pg = page > pages - 1 ? pages - 1 : page;
    final from = pg * _size;
    final to = from + _size > units.length ? units.length : from + _size;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHead(context, Icons.table_rows_rounded, 'Unit dues and payments',
              'Worked out automatically: floor area × the rate per sqm. Billed, paid and balance come from the charges.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            runSpacing: 8,
            children: [
              _s(context, 'Billed', peso(billed)),
              _s(context, 'Paid', peso(paid)),
              _s(context, 'Balance', peso(billed - paid)),
            ],
          ),
          if (units.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('No units yet.', style: TextStyle(color: muted(context)))),
          for (final r in rows.sublist(from, to)) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(child: Text('${r.$1.unit}${r.$1.name == '—' ? '' : ' · ${r.$1.name}'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                if (r.$1.area <= 0) const Pill('No area', tone: Tone.warn) else Text('${r.$1.area} sqm', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: () => _editSize(r.$1),
                  child: Text(r.$1.area <= 0 ? 'Set size' : 'Edit size'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 2,
              children: [
                Text('Due day ${r.$1.dueDay > 0 ? r.$1.dueDay : '—'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                Text('Monthly ${r.$2.monthly > 0 ? peso(r.$2.monthly) : '—'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                Text('Billed ${peso(r.$2.billed)}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                Text('Paid ${peso(r.$2.paid)}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                Text('Balance ${peso(r.$2.balance)}', style: TextStyle(color: r.$2.balance > 0 ? danger : muted(context), fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (units.length > _size) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: pg == 0 ? null : () => setState(() => page = pg - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous page',
                ),
                Expanded(
                  child: Text('Showing ${from + 1}–$to of ${units.length} · page ${pg + 1} of $pages',
                      textAlign: TextAlign.center, style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: pg >= pages - 1 ? null : () => setState(() => page = pg + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next page',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _s(BuildContext context, String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17)),
          Text(k, style: TextStyle(color: muted(context), fontSize: 12)),
        ],
      );
}
