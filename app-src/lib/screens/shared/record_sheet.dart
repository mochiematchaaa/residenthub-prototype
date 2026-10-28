// The household record of a unit, drawn the same way for the office and the resident.
// The office edits everything; the resident edits the household, emergency contact and vehicles.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class RecordSheet extends StatelessWidget {
  final Unit u;

  /// True when the office is looking at it (shows the private note and the sign-in account).
  final bool admin;

  /// The sign-in email of the unit's account.
  final String email;

  /// The edit button.
  final Widget? action;
  const RecordSheet({super.key, required this.u, required this.admin, this.email = '', this.action});

  ({int ts, String by, bool resident})? get _stamp {
    final off = u.profileUpdated, self = u.selfUpdated;
    if (off == 0 && self == 0) return null;
    return self > off ? (ts: self, by: u.selfBy.isEmpty ? 'the resident' : u.selfBy, resident: true) : (ts: off, by: u.profileBy.isEmpty ? 'the office' : u.profileBy, resident: false);
  }

  Widget _none(BuildContext c, [String t = 'Not on file']) => Text(t, style: TextStyle(color: muted(c), fontSize: 13.5));

  Widget _row(BuildContext c, String k, String v, {bool edit = false, String empty = 'Not on file'}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: muted(c).withAlpha(40)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(color: muted(c), fontSize: 13.5)),
        if (edit) const Text(' ✎', style: TextStyle(color: lavDeep, fontSize: 12)),
        const SizedBox(width: 12),
        Expanded(child: v.isEmpty ? Align(alignment: Alignment.centerRight, child: _none(c, empty)) : Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
      ]),
    );
  }

  Widget _chips(BuildContext c, String text, {String empty = 'Not on file'}) {
    final l = text.split(RegExp(r'\n+')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (l.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _none(c, empty));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in l)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: lavDeep.withAlpha(28), borderRadius: BorderRadius.circular(99)),
            child: Text(x, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _head(BuildContext c, String t, {bool edit = false}) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 2),
        child: Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lavDeep.withAlpha(70), width: 2))),
          child: Row(children: [
            Text(t.toUpperCase(), style: const TextStyle(color: lavDeep, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1)),
            if (edit) const Text(' ✎', style: TextStyle(color: lavDeep, fontSize: 12)),
          ]),
        ),
      );

  Widget _call(BuildContext c, String title, String text, Tone tone) {
    final t = toneOf(c, tone);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(color: t.fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 2),
        Text(text, style: TextStyle(color: t.fg, fontSize: 13.5, height: 1.4)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final self = !admin;
    final name = u.name == '—' ? '' : u.name;
    final st = _stamp;
    final slot = app.slotOf(u.unit);
    final emer = [u.emergencyName, if (u.emergencyRelation.isNotEmpty) '(${u.emergencyRelation})'].where((x) => x.isNotEmpty).join(' ');
    final mail = u.email.isNotEmpty ? u.email : email;
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), gradient: const LinearGradient(colors: [Color(0xFF7B6BD6), Color(0xFF5B9BC4)])),
            child: Text(initialsOf(name.isEmpty ? u.unit : name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'No name on file' : name, style: hd(20)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Pill(u.unit),
                Pill(u.type),
                if (u.moveIn.isNotEmpty) Pill('Moved in ${isoShort(u.moveIn)}', tone: Tone.good),
              ]),
            ]),
          ),
        ]),
        if (action != null) ...[const SizedBox(height: 12), SizedBox(width: double.infinity, child: action!)],
        const SizedBox(height: 10),
        Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (st != null && st.resident) const Pill('Edited by the resident', tone: Tone.info),
          Text(
            st == null
                ? 'Not filled in yet.'
                : 'Last updated ${shortDate(DateTime.fromMillisecondsSinceEpoch(st.ts))} by ${st.by}${st.resident ? ' (resident)' : (admin ? '' : ' (office)')}.',
            style: TextStyle(color: muted(context), fontSize: 12.5),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            admin ? 'What you save here is shown to the resident on their dashboard.' : 'Update your household, emergency contact and vehicles yourself. Ask the office to change anything else.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
        ),
        if (u.noteResident.isNotEmpty) _call(context, 'Note from the office', u.noteResident, Tone.info),
        if (admin && u.noteOffice.isNotEmpty) _call(context, 'Private office note · the resident does not see this', u.noteOffice, Tone.warn),
        _head(context, 'Contact'),
        _row(context, 'Mobile', u.contact == '—' ? '' : u.contact),
        _row(context, 'Email', mail),
        if (admin) _row(context, 'Sign-in account', email, empty: 'None yet'),
        _row(context, 'Floor area', u.area > 0 ? '${u.area} sqm' : '', empty: 'Not set'),
        _row(context, 'Parking slot', slot == null ? '' : '${slot.id} · ${slot.size}', empty: 'None'),
        _head(context, 'Household'),
        _row(context, 'People living here', u.residents > 0 ? '${u.residents}' : '', edit: self),
        _row(context, 'Pets', u.pets, edit: self, empty: 'None on file'),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(children: [Text('Members', style: TextStyle(color: muted(context), fontSize: 13.5)), if (self) const Text(' ✎', style: TextStyle(color: lavDeep, fontSize: 12))]),
        ),
        _chips(context, u.members),
        _head(context, 'Emergency contact', edit: self),
        if (u.emergencyName.isEmpty && u.emergencyPhone.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _none(context))
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(colors: [Color(0xFF7B6BD6), Color(0xFF5B9BC4)])),
                child: Text(initialsOf(u.emergencyName.isEmpty ? '?' : u.emergencyName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emer.isEmpty ? 'Emergency contact' : emer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text(u.emergencyPhone.isEmpty ? 'No number' : u.emergencyPhone, style: TextStyle(color: muted(context), fontSize: 13)),
                ]),
              ),
            ]),
          ),
        _head(context, 'Vehicles', edit: self),
        _chips(context, u.vehicles, empty: 'None on file'),
        if (u.selfLog.isNotEmpty) ...[
          _head(context, 'Recent changes by the resident'),
          for (final h in u.selfLog.take(6))
            _row(context, h.field, '${h.from.isEmpty ? '' : '${h.from} → '}${h.to.isEmpty ? 'removed' : h.to} · ${shortDate(DateTime.fromMillisecondsSinceEpoch(h.at))}'),
        ],
      ]),
    );
  }
}
