// ADMIN: the "Payments to verify" card on Finance. Each payment shows who sent it, how much, whether it matches
// its charge, and when the system will post it by itself.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';
import 'unit_history_screen.dart';

class VerifyPanel extends StatefulWidget {
  final List<PaymentProof> proofs;
  final void Function(PaymentProof) onReject;
  final VoidCallback onChangeSettings;
  const VerifyPanel({super.key, required this.proofs, required this.onReject, required this.onChangeSettings});

  @override
  State<VerifyPanel> createState() => _VerifyPanelState();
}

class _VerifyPanelState extends State<VerifyPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps the countdowns moving while the page is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _post(PaymentProof p) {
    final rec = app.confirmProof(p);
    final slot = p.forText == parkingPayFor ? app.slotOf(p.unit) : null;
    msg(context, slot != null ? 'Payment posted. ${slot.id} is now assigned to ${p.unit}. Receipt ${rec.receiptNo} issued.' : 'Payment posted. Receipt ${rec.receiptNo} issued.');
  }

  Widget _fact(BuildContext context, String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  /// Waiting for more than 2 days.
  bool _late(PaymentProof p) => DateTime.now().difference(p.sentAt) > const Duration(hours: 48);

  Widget _card(BuildContext context, PaymentProof p) {
    final chk = app.proofCheck(p);
    final isLate = _late(p);
    final due = app.autoPostAt(p).difference(DateTime.now());
    final total = Duration(hours: app.autoPostHours <= 0 ? 24 : app.autoPostHours);
    final ready = !due.isNegative && due.inSeconds > 0 ? 1 - (due.inSeconds / total.inSeconds).clamp(0.0, 1.0) : 1.0;
    final scheduled = app.autoPostOn && chk.ok;
    final tone = chk.ok ? Tone.good : Tone.warn;
    final t = toneOf(context, tone);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (isLate ? toneOf(context, Tone.bad).fg : t.fg).withValues(alpha: isLate ? 0.7 : 0.35), width: isLate ? 1.5 : 1),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Avatar(p.payer.isEmpty ? p.unit : p.payer, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.unit} · ${p.payer}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Sent ${clockText(p.sentAt)}${isLate ? ' · waiting over 2 days' : ''}',
                    style: TextStyle(color: isLate ? toneOf(context, Tone.bad).fg : muted(context), fontSize: 12, fontWeight: isLate ? FontWeight.w800 : FontWeight.w400)),
              ]),
            ),
            Text(peso(p.amount), style: hd(20)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 10, children: [
            _fact(context, 'Paying for', p.forText.isEmpty ? 'Association dues' : p.forText),
            _fact(context, 'Method', p.method),
            _fact(context, 'Reference no.', p.reference.isEmpty ? '—' : p.reference),
            _fact(context, 'Expected', chk.expected == null ? 'Not known' : peso(chk.expected!)),
            _fact(context, 'Due date', chk.due == null || chk.due!.dueDate.isEmpty ? '—' : chk.due!.dueDate),
            _fact(context, 'Date paid', p.paidOn.isEmpty ? 'Not given' : p.paidOn),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PHOTO OF PAYMENT', style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  if (proofImageBytes(p.image) != null)
                    InkWell(
                      onTap: () => showProofImage(context, p),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(proofImageBytes(p.image)!, width: 44, height: 44, fit: BoxFit.cover)),
                        const SizedBox(width: 8),
                        const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, decoration: TextDecoration.underline)),
                      ]),
                    )
                  else
                    Text('None attached', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in chk.checks)
              Pill('${c.ok == true ? '✓ ' : c.ok == false ? '✕ ' : '• '}${c.label}', tone: c.ok == true ? Tone.good : c.ok == false ? Tone.bad : Tone.info),
          ]),
          const SizedBox(height: 10),
          Pill(chk.ok ? 'Matches the charge' : 'Needs a look', tone: tone),
          if (chk.ok && scheduled) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ready.toDouble(), minHeight: 7, backgroundColor: t.bg, color: t.fg),
            ),
            const SizedBox(height: 6),
            Text(
              due.isNegative || due.inSeconds <= 0 ? 'Posting automatically now.' : 'Posts automatically in ${waitText(due)} (${clockText(app.autoPostAt(p))}).',
              style: TextStyle(color: muted(context), fontSize: 12.5),
            ),
          ] else if (chk.ok) ...[
            const SizedBox(height: 8),
            Text('Automatic posting is off. Post it yourself when you are ready.', style: TextStyle(color: muted(context), fontSize: 12.5)),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in chk.why)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.error_outline_rounded, size: 16, color: t.fg),
                        const SizedBox(width: 6),
                        Expanded(child: Text(w, style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  const SizedBox(height: 2),
                  Text('This one will not post by itself. Check it, then post or reject it.', style: TextStyle(color: t.fg, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => go(context, UnitHistoryScreen(unit: p.unit)),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Resident profile'),
              ),
              TextButton(onPressed: () => widget.onReject(p), child: const Text('Reject')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _post(p),
                child: Text(chk.ok ? 'Post now' : 'Verify and post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clean = widget.proofs.where((p) => app.proofCheck(p).ok).length;
    final flagged = widget.proofs.length - clean;
    final sum = widget.proofs.fold<num>(0, (a, p) => a + p.amount);
    final sorted = [...widget.proofs]..sort((a, b) {
        final la = _late(a) ? 0 : 1, lb = _late(b) ? 0 : 1;
        return la != lb ? la - lb : a.sentAt.compareTo(b.sentAt);
      });
    final nLate = sorted.where(_late).length;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.fact_check_outlined, accent: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payments to verify', style: hd(17)),
                Text('${widget.proofs.length} waiting · ${peso(sum)}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onChangeSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: toneOf(context, app.autoPostOn ? Tone.good : Tone.warn).bg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(app.autoPostOn ? Icons.bolt_rounded : Icons.pause_circle_outline_rounded, size: 18, color: toneOf(context, app.autoPostOn ? Tone.good : Tone.warn).fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.autoPostOn ? 'Automatic posting is on: matching payments post ${app.autoPostHours} hours after they were sent.' : 'Automatic posting is off. Every payment waits for you.',
                    style: TextStyle(color: toneOf(context, app.autoPostOn ? Tone.good : Tone.warn).fg, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                Text('Change', style: TextStyle(color: toneOf(context, app.autoPostOn ? Tone.good : Tone.warn).fg, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pill('$clean matching', tone: Tone.good),
            if (flagged > 0) Pill('$flagged need${flagged == 1 ? 's' : ''} a look', tone: Tone.warn),
          ]),
          if (nLate > 0)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: toneOf(context, Tone.bad).bg, borderRadius: BorderRadius.circular(14)),
              child: Text('$nLate payment${nLate == 1 ? ' has' : 's have'} been waiting more than 2 days. Check ${nLate == 1 ? 'it' : 'them'} first, then verify or reject.',
                  style: TextStyle(color: toneOf(context, Tone.bad).fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          for (final p in sorted) _card(context, p),
        ],
      ),
    );
  }
}
