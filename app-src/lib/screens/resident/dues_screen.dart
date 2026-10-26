// RESIDENT page: Dues and payments (ring, payment proof).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';
import 'dues_widgets.dart';
import 'resident_screens.dart';

class ResDues extends StatefulWidget {
  const ResDues({super.key});

  @override
  State<ResDues> createState() => _ResDuesState();
}

class _ResDuesState extends State<ResDues> {
  /// 'todo', 'paid' or 'all'. Starts on what is still to pay.
  String? _tab;
  int? _flash;
  double _ringScale = 1;
  final _ringKey = GlobalKey();
  final Map<int, GlobalKey> _keys = {};
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _celebrated) return;
      final l = app.myDues;
      if (l.isNotEmpty && l.every((d) => d.paid)) {
        _celebrated = true;
        _confetti();
      }
    });
  }

  void _confetti() {
    final box = _ringKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    showConfetti(context, box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _pop() {
    setState(() => _ringScale = 1.18);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _ringScale = 1);
    });
    _confetti();
  }

  /// Tap a block of the payment trail: show everything and flash the charge.
  void _jump(Due d) {
    setState(() {
      _tab = 'all';
      _flash = d.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[d.id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3, curve: Curves.easeOutCubic);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _sendProof(BuildContext context, {Due? due}) {
    final online = [
      for (final m in app.enabledPayMethods)
        if (m.name != AppState.officePay) m.name,
    ];
    if (online.isEmpty) {
      msg(context, 'Online payment options are not set up yet. Please pay at the office.');
      return;
    }
    final amount = due != null ? due.amount : app.myBalance;
    showFormSheet(
      context,
      title: due == null ? 'Send payment proof' : 'Pay ${due.note}',
      subtitle: 'Enter the reference number from your payment receipt. The administrator will check it and record your payment.',
      choices: [ChoiceSpec('method', 'Paid through', online, online.first)],
      fields: [
        const FieldSpec('ref', 'Reference no.', hint: 'From your GCash / Maya / bank receipt'),
        FieldSpec('amount', 'Amount paid (₱)', type: TextInputType.number, initial: amount > 0 ? amount.toStringAsFixed(2) : ''),
      ],
      submit: 'Send',
      onSubmit: (v) {
        final err = app.submitProof(v['method'] as String, v['ref'] as String, v['amount'] as String, due: due);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) msg(context, 'Sent. The administrator will verify your payment.');
          });
        }
        return err;
      },
    );
  }

  Widget _hero(BuildContext context, List<Due> all) {
    final paid = all.where((d) => d.paid).length;
    final todo = all.where((d) => !d.paid).toList();
    final overdue = todo.where((d) => d.overdue).length;
    final owed = todo.fold<num>(0, (s, d) => s + d.amount);
    final done = all.isNotEmpty && todo.isEmpty;
    final pct = all.isEmpty ? 1.0 : paid / all.length;
    final cs = Theme.of(context).colorScheme;
    final good = toneOf(context, Tone.good).fg;
    DueCountdown? next;
    for (final d in todo) {
      final c = dueCountdown(d);
      if (c != null && c.days >= 0 && (next == null || c.days < next.days)) next = c;
    }
    final mood = all.isEmpty
        ? 'No charges yet. Nothing to pay.'
        : done
            ? 'You are all paid up. Thank you!'
            : overdue > 0
                ? '$overdue overdue. Pay soon to catch up.'
                : next != null
                    ? '${next.text.replaceFirst('Due', 'Next charge is due')}.'
                    : 'Almost there. ${todo.length} to go.';
    final first = todo.isEmpty ? null : (todo.where((d) => d.overdue).firstOrNull ?? todo.first);
    return RCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: done ? [toneOf(context, Tone.good).bg, cs.surface] : [toneOf(context, Tone.warn).bg, cs.surface],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pop,
                child: AnimatedScale(
                  scale: _ringScale,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    key: _ringKey,
                    width: 112,
                    height: 112,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => CustomPaint(
                        painter: RingPainter(v, cs.outlineVariant, done ? good : lavDeep),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$paid/${all.length}', style: hd(23)),
                              Text('paid', style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(todo.isEmpty ? 'BALANCE' : 'YOU OWE', style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: owed.toDouble()),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(todo.isEmpty ? '₱0' : peso(v), style: hd(34, color: todo.isEmpty ? good : danger)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(mood, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (done) const Pill('All paid up', tone: Tone.good),
              if (all.isNotEmpty && overdue == 0) const Pill('No overdue', tone: Tone.good),
              if (paid > 0) Pill('$paid paid', tone: Tone.info),
              if (todo.isNotEmpty) Pill('${todo.length} to pay', tone: Tone.warn),
            ],
          ),
          const SizedBox(height: 14),
          if (first != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sendProof(context, due: first),
                icon: const Icon(Icons.bolt_rounded),
                label: Text('Pay now · ${peso(first.amount)}'),
              ),
            )
          else if (all.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: _pop, icon: const Icon(Icons.celebration_rounded), label: const Text('Celebrate')),
            ),
        ],
      ),
    );
  }

  Widget _trail(BuildContext context, List<Due> all) {
    final items = all.take(12).toList().reversed.toList();
    if (items.length < 2) return const SizedBox.shrink();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Your payment trail', style: hd(17))),
            Text('Tap a block', style: TextStyle(color: muted(context), fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in items)
                Builder(builder: (context) {
                  final st = dueState(d);
                  final t = toneOf(context, dueTone(st));
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _jump(d),
                    child: Container(
                      width: 52,
                      height: 60,
                      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(dueIcon(st), size: 20, color: t.fg),
                          const SizedBox(height: 2),
                          Text(dueMonth(d), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.fg)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chargeCard(BuildContext context, Due d) {
    final st = dueState(d);
    final tone = dueTone(st);
    final t = toneOf(context, tone);
    final cd = (st == 'open' || st == 'overdue') ? dueCountdown(d) : null;
    final label = st == 'paid' ? 'Paid' : (st == 'overdue' ? 'Overdue' : (st == 'pending' ? 'Waiting for the office' : 'To pay'));
    final key = _keys.putIfAbsent(d.id, () => GlobalKey());
    PaymentRecord? receipt;
    if (st == 'paid') {
      for (final p in app.myPayments) {
        if (p.forText == d.note) {
          receipt = p;
          break;
        }
      }
    }
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: _flash == d.id ? [BoxShadow(color: lavDeep.withAlpha(150), blurRadius: 0, spreadRadius: 4)] : const [],
      ),
      child: RCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(dueIcon(st), color: t.fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.note, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(label, tone: tone),
                      Text(d.dueDate.isEmpty ? 'Due upon receipt' : d.dueDate, style: TextStyle(color: muted(context), fontSize: 12)),
                      if (cd != null) Pill(cd.text, tone: cd.tone),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(peso(d.amount), style: hd(16)),
                const SizedBox(height: 6),
                if (st == 'open' || st == 'overdue')
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => _sendProof(context, due: d),
                    child: const Text('Pay'),
                  )
                else if (receipt != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: () => openReceipt(context, receipt!),
                    child: const Text('Receipt'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = app.myDues;
    final todo = all.where((d) => !d.paid).toList();
    final paid = all.where((d) => d.paid).toList();
    final tab = _tab ?? (todo.isNotEmpty ? 'todo' : 'all');
    final shown = tab == 'all' ? all : (tab == 'paid' ? paid : todo);
    return TabPage(
      title: 'Dues & payment',
      subtitle: 'Your monthly charges and outstanding balance.',
      children: [
        _hero(context, all),
        _trail(context, all),
        if (app.myParkingReq != null && app.myParkingReq!.slot.isNotEmpty && app.myParkingReq!.amount > 0 && app.slotOf(app.myUnit) == null)
          Builder(builder: (context) {
            final r = app.myParkingReq!;
            final proof = app.parkingProofFor(app.myUnit, r.slot);
            return RCard(
              child: Row(
                children: [
                  IconBadge(proof == null ? Icons.two_wheeler_rounded : Icons.schedule_rounded, accent: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Motor parking · ${r.slot}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${peso(r.amount)} · ${parkPlanText(r.plan, r.days)} · ${proof == null ? 'waiting for your payment' : (proof.status == 'Confirmed' ? 'paid' : 'payment sent, waiting for the office')}',
                            style: TextStyle(color: muted(context), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (proof == null) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => sendParkingPayment(context), child: const Text('Pay')),
                ],
              ),
            );
          }),
        if (all.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final e in [('todo', 'To pay (${todo.length})'), ('paid', 'Paid (${paid.length})'), ('all', 'All (${all.length})')])
                ChoiceChip(label: Text(e.$2), selected: tab == e.$1, onSelected: (_) => setState(() => _tab = e.$1)),
            ],
          ),
        if (all.isEmpty)
          const EmptyBox('No charges have been billed to your unit yet.', icon: Icons.receipt_long_outlined)
        else if (shown.isEmpty)
          EmptyBox(tab == 'todo' ? 'Nothing to pay. You are all caught up!' : 'Nothing paid yet. Paid charges and their receipts show up here.', icon: Icons.celebration_outlined)
        else
          for (final d in shown) _chargeCard(context, d),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.account_balance_wallet_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('How to pay', style: hd(17))),
              ]),
              const SizedBox(height: 10),
              if (app.enabledPayMethods.isEmpty)
                Text('Payment options will be posted by the administrator.', style: TextStyle(color: muted(context), fontSize: 13)),
              for (final m in app.enabledPayMethods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(payIcon(m.name), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(m.details, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _sendProof(context),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('I have paid - send reference no.'),
                ),
              ),
            ],
          ),
        ),
        if (app.myProofs.isNotEmpty)
          RCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Payment proofs sent', style: hd(17))),
                ),
                for (final p in app.myProofs)
                  ListTile(
                    title: Text('${p.method} · ${peso(p.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Ref. ${p.reference} · ${p.date}${p.status == 'Rejected' && p.reason.isNotEmpty ? '\nReason: ${p.reason}' : ''}'),
                    trailing: Pill(p.status == 'Confirmed' ? 'Verified' : p.status),
                  ),
              ],
            ),
          ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.receipt_long_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Receipts', style: hd(17))),
              ]),
              const SizedBox(height: 6),
              Text('Your proof of payment. Open a receipt to download it as Word or Excel.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              ReceiptList(app.myPayments),
              OutlinedButton.icon(
                onPressed: () => go(context, const ResFinanceDocs()),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Open finance documents'),
              ),
              if (app.myPayments.isNotEmpty) ...[
                const SizedBox(height: 4),
                HistoryExportButtons(
                  title: 'Payment history ${app.myUnit}',
                  list: () => app.myPayments,
                ),
              ],
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.two_wheeler_rounded, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Motor parking rental', style: hd(17))),
              ]),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Rent a motor/motorcycle parking slot for '),
                  TextSpan(text: app.motorRate > 0 ? '${peso(app.motorRate)}/month' : 'the monthly rate', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (app.motorRateDay > 0) ...[
                    const TextSpan(text: ' or '),
                    TextSpan(text: '${peso(app.motorRateDay)}/day', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  const TextSpan(text: ". Rates may change — check with the office for the latest amount."),
                ]),
                style: TextStyle(color: muted(context), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('${app.freeSlotCount} of ${app.slots.length} slots free', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                  Text('Green = free · Red = taken', style: TextStyle(color: muted(context), fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 8),
              if (app.slots.isEmpty)
                Text('The office has not set up motor parking slots yet.', style: TextStyle(color: muted(context), fontSize: 13)),
              if (app.slots.isNotEmpty)
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.7,
                children: [
                  for (final sl in app.slots)
                    Builder(builder: (context) {
                      final mine = sl.unit == app.myUnit;
                      final t = toneOf(context, sl.used ? Tone.bad : Tone.good);
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mine ? lavDeep : t.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(sl.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: mine ? Colors.white : t.fg)),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 12),
              if (app.slotOf(app.myUnit) != null)
                Pill('Your slot: ${app.slotOf(app.myUnit)!.id}', tone: Tone.good)
              else if (app.parkingRequested)
                const Pill('Request sent — awaiting admin confirmation', tone: Tone.good)
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      app.requestParking();
                      msg(context, 'Parking slot request sent to the administrator.');
                    },
                    child: const Text('Request a parking slot'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
