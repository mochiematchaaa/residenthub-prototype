// RESIDENT page: Dues and payments (ring, payment proof).

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';
import 'dues_widgets.dart';
import 'resident_screens.dart';

/// Opens the pay form: reference number, optional photo, amount. The proof goes to the office to check.
void sendDueProof(BuildContext context, {Due? due}) {
  final online = [
    for (final m in app.enabledPayMethods)
      if (m.name != AppState.officePay) m.name,
  ];
  if (online.isEmpty) {
    msg(context, 'Online payment options are not set up yet. Please pay at the office.');
    return;
  }
  final amount = due != null ? due.amount : app.myBalance;
  final dueLine = due == null ? '' : 'Charge: ${due.note} · ${peso(due.amount)} · ${due.dueDate.isEmpty ? 'due upon receipt' : 'due ${due.dueDate}'}.\n';
  showFormSheet(
    context,
    title: due == null ? 'Send payment proof' : 'Pay ${due.note}',
    subtitle: '${dueLine}Enter the reference number from your payment receipt and add a photo of your payment if you have one. It posts to your dues by itself if it matches, or the office verifies it. Paid at the office? Nothing to send; the office records it.',
    photo: const PhotoSpec('photo', 'Photo of your payment (screenshot or receipt, optional)', hint: 'It helps the office check your payment faster.'),
    choices: [ChoiceSpec('method', 'Paid through', online, online.first)],
    fields: [
      const FieldSpec('ref', 'Reference no.', hint: 'From your GCash / Maya / bank receipt'),
      FieldSpec('amount', 'Amount paid (₱)', type: TextInputType.number, initial: amount > 0 ? amount.toStringAsFixed(2) : ''),
      FieldSpec('paid', 'Date you paid', hint: 'Like ${shortDate(DateTime.now())}', initial: shortDate(DateTime.now())),
    ],
    submit: 'Send',
    onSubmit: (v) {
      final pic = v['photo'];
      final err = app.submitProof(v['method'] as String, v['ref'] as String, v['amount'] as String,
          due: due, image: pic is Uint8List ? proofImageText(pic) : '', paidOn: v['paid'] as String);
      if (err == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) msg(context, 'Sent. The administrator will verify your payment.');
        });
      }
      return err;
    },
  );
}

/// The "I have paid" button: first pick which of your own unpaid charges it was for (amount and due date shown), then send the proof.
void payAChargeSheet(BuildContext context) {
  final open = [
    for (final d in app.myDues)
      if (!d.paid && !app.myProofs.any((p) => p.status == 'Pending' && p.forText == d.note)) d,
  ];
  if (open.isEmpty) {
    msg(context, 'You have no unpaid charges to pay right now.');
    return;
  }
  if (open.length == 1) {
    sendDueProof(context, due: open.first);
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What did you pay for?', style: hd(22)),
          const SizedBox(height: 4),
          Text('Pick one of your unpaid charges.', style: TextStyle(color: muted(ctx))),
          const SizedBox(height: 8),
          for (final d in open)
            Builder(builder: (_) {
              final cd = dueCountdown(d);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(d.note, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${peso(d.amount)} · ${d.dueDate.isEmpty ? 'due upon receipt' : 'due ${d.dueDate}'}${cd != null && cd.days < 0 ? ' · ${cd.text}' : ''}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  sendDueProof(context, due: d);
                },
              );
            }),
        ],
      ),
    ),
  );
}

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

  void _sendProof(BuildContext context, {Due? due}) => sendDueProof(context, due: due);

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

  Widget _alert(BuildContext context, Tone tone, IconData icon, String title, String sub, {String? action, VoidCallback? onTap}) {
    final t = toneOf(context, tone);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.fg.withValues(alpha: 0.35))),
      child: Row(
        children: [
          Icon(icon, color: t.fg, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: t.fg, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: onTap,
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  /// Red for overdue charges, amber for charges due within 2 days, blue when a payment is waiting for the office.
  Widget _alerts(BuildContext context, List<Due> todo) {
    final items = <Widget>[];
    var shownLate = 0;
    for (final d in todo) {
      final st = dueState(d);
      if (st == 'pending') continue;
      final cd = dueCountdown(d);
      if (cd == null) continue;
      if (cd.days < 0 && shownLate < 3) {
        shownLate++;
        items.add(_alert(context, Tone.bad, Icons.priority_high_rounded, '${cd.text}: ${d.note}',
            '${peso(d.amount)} was due ${d.dueDate}. Pay it now and send your proof so the office can check it.',
            action: 'Pay ${peso(d.amount)}', onTap: () => _sendProof(context, due: d)));
      } else if (cd.days >= 0 && cd.days <= 2) {
        items.add(_alert(context, cd.days == 0 ? Tone.bad : Tone.warn, Icons.schedule_rounded, '${d.note} is ${cd.days == 0 ? 'due TODAY' : 'due in ${cd.days} day${cd.days == 1 ? '' : 's'}'}',
            cd.days == 0
                ? '${peso(d.amount)} · ${d.dueDate}. Please pay within the day and send your proof before it ends, so your dashboard updates. Paid at the office? The office records it right away.'
                : '${peso(d.amount)} · ${d.dueDate}. Send your proof before the due date so your dashboard updates.',
            action: cd.days == 0 ? 'Pay and send proof' : 'Pay now', onTap: () => _sendProof(context, due: d)));
      }
    }
    final waiting = todo.where((d) => dueState(d) == 'pending').length;
    if (waiting > 0) {
      items.add(_alert(context, Tone.info, Icons.hourglass_top_rounded, '$waiting payment${waiting == 1 ? '' : 's'} sent, waiting for the office',
          'You will see the result under Payment proofs sent below.'));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: items);
  }

  Widget _flow(BuildContext context) {
    const steps = [
      ('Pay', 'At the office, or by GCash, Maya or bank.'),
      ('Send your proof', 'Reference number and a photo of your payment.'),
      ('The office checks it', 'Posted by itself if it matches, or checked by the office.'),
      ('Receipt', 'Your dues go down and your receipt appears.'),
    ];
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How paying works', style: hd(17)),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 11, backgroundColor: lavDeep, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${steps[i].$1}. ', style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: steps[i].$2, style: TextStyle(color: muted(context))),
                    ]), style: const TextStyle(fontSize: 13, height: 1.35)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One step of a payment's status trail. state: done | now | bad | todo.
  Widget _step(BuildContext context, String label, String sub, String state) {
    final t = toneOf(context, state == 'done' ? Tone.good : state == 'bad' ? Tone.bad : state == 'now' ? Tone.warn : Tone.info);
    final cs = Theme.of(context).colorScheme;
    final dim = state == 'todo';
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: dim ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : t.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(state == 'done' ? Icons.check_circle_rounded : state == 'bad' ? Icons.cancel_rounded : state == 'now' ? Icons.schedule_rounded : Icons.radio_button_unchecked_rounded,
                  size: 15, color: dim ? muted(context) : t.fg),
              const SizedBox(width: 4),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: dim ? muted(context) : t.fg))),
            ]),
            const SizedBox(height: 3),
            Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, height: 1.3, color: dim ? muted(context) : t.fg)),
          ],
        ),
      ),
    );
  }

  Widget _proofCard(BuildContext context, PaymentProof p) {
    final pending = p.status == 'Pending';
    final rejected = p.status == 'Rejected';
    final ok = p.status == 'Confirmed';
    final checkSub = pending
        ? (app.autoPostOn ? 'Posts by ${clockText(app.autoPostAt(p))}' : 'Waiting for the office')
        : rejected
            ? (p.reason.isEmpty ? 'Please check the reference number' : p.reason)
            : (p.auto ? 'Posted automatically' : 'Verified by the office');
    final due = rejected ? app.myDues.where((d) => !d.paid && d.note == p.forText).firstOrNull : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.forText.isEmpty ? '${p.method} · ${peso(p.amount)}' : p.forText, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${p.method} · Ref. ${p.reference} · ${peso(p.amount)}${p.paidOn.isEmpty ? '' : ' · paid ${p.paidOn}'}', style: TextStyle(color: muted(context), fontSize: 12)),
              ]),
            ),
            Pill(ok ? (p.auto ? 'Posted' : 'Verified') : p.status),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _step(context, 'Sent', p.date, 'done'),
            _step(context, 'Office check', checkSub, ok ? 'done' : rejected ? 'bad' : 'now'),
            _step(context, 'Receipt', ok ? p.receiptNo : (rejected ? 'Not issued' : 'After the check'), ok ? 'done' : 'todo'),
          ]),
          if (p.image.isNotEmpty || rejected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 8, children: [
                if (p.image.isNotEmpty) TextButton(onPressed: () => showProofImage(context, p), child: const Text('View my photo')),
                if (rejected) FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => _sendProof(context, due: due),
                  child: const Text('Send again'),
                ),
              ]),
            ),
          const Divider(height: 14),
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
    final label = st == 'paid' ? 'Paid' : (st == 'overdue' ? 'Overdue' : (st == 'pending' ? 'Payment sent' : 'To pay'));
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
                  if (d.billed.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Billed ${d.billed}', style: TextStyle(color: muted(context), fontSize: 12)),
                  ],
                  if (st == 'pending') ...[
                    const SizedBox(height: 4),
                    Text(
                      () {
                        final p = app.myProofs.where((x) => x.status == 'Pending' && x.forText == d.note).firstOrNull;
                        if (p == null) return 'Waiting for the office to verify it';
                        return app.autoPostOn ? 'Posts to your dues by ${clockText(app.autoPostAt(p))} at the latest' : 'Waiting for the office to verify it';
                      }(),
                      style: TextStyle(color: muted(context), fontSize: 12),
                    ),
                  ],
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
        _alerts(context, todo),
        _hero(context, all),
        if (todo.isNotEmpty) _flow(context),
        _trail(context, all),
        if (app.myUnitRec != null && app.myUnitRec!.area > 0 && app.duesRate > 0)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const IconBadge(Icons.square_foot_rounded, accent: true),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Your monthly dues', style: hd(17))),
                ]),
                const SizedBox(height: 10),
                Text('${peso(app.unitDues(app.myUnitRec!).monthly)} a month',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Floor area ${app.myUnitRec!.area} sqm × ${peso(app.duesRate)} per sqm. Billed so far ${peso(app.unitDues(app.myUnitRec!).billed)}, paid ${peso(app.unitDues(app.myUnitRec!).paid)}.',
                    style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        if (app.myParkingReq != null &&
            app.myParkingReq!.slot.isNotEmpty &&
            app.myParkingReq!.amount > 0 &&
            app.slotOf(app.myUnit) == null &&
            !all.any((d) => !d.paid && d.note == parkingPayFor))
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
                  onPressed: () => payAChargeSheet(context),
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
                for (final p in app.myProofs) _proofCard(context, p),
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
                  const TextSpan(text: 'Rent a motor/motorcycle parking slot. The price depends on the slot size: '),
                  TextSpan(
                    text: [for (final z in app.parkSizes) if (z.month > 0) '${z.name} ${peso(z.month)}/month${z.day > 0 ? ' or ${peso(z.day)}/day' : ''}'].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
