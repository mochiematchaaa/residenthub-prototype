// ADMIN: the price calculator under the monthly dues settings.
// Dues are billed per month, but the calculator can quote and show a price per day, per month or per year.
// Per day = per year / 365, per month = per year / 12.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

double _toMonthly(double x, String period) => period == 'day' ? x * 365 / 12 : (period == 'year' ? x / 12 : x);
double _fromMonthly(double x, String period) => period == 'day' ? x * 12 / 365 : (period == 'year' ? x * 12 : x);
double _round(double n, [int d = 2]) {
  final f = _pow10(d);
  return (n * f).round() / f;
}

double _pow10(int d) {
  var f = 1.0;
  for (var i = 0; i < d; i++) {
    f *= 10;
  }
  return f;
}

double _parse(String s) => double.tryParse(s.trim().replaceAll(',', '')) ?? double.nan;

const _modes = ['Dues for a size', 'Rate from a total', 'Size from a budget'];
const _periods = ['Per day', 'Per month', 'Per year'];

class PriceCalculator extends StatefulWidget {
  /// The monthly rate per sqm now in the rate box (or saved), used to fill the rate field.
  final double Function() monthlyRate;

  /// Called when the office taps "Use … as the monthly rate".
  final void Function(double monthly) onUseRate;
  const PriceCalculator({super.key, required this.monthlyRate, required this.onUseRate});

  @override
  State<PriceCalculator> createState() => _PriceCalculatorState();
}

class _PriceCalculatorState extends State<PriceCalculator> {
  String mode = _modes[0];
  String period = 'Per month';
  String unit = '';
  final area = TextEditingController();
  final total = TextEditingController();
  final rate = TextEditingController();
  bool rateTouched = false;

  @override
  void initState() {
    super.initState();
    _fillRate();
  }

  @override
  void dispose() {
    area.dispose();
    total.dispose();
    rate.dispose();
    super.dispose();
  }

  String get _key => period == 'Per day' ? 'day' : (period == 'Per year' ? 'year' : 'month');

  void _fillRate() {
    final m = widget.monthlyRate();
    rate.text = m > 0 ? '${_round(_fromMonthly(m, _key), 4)}' : '';
  }

  Widget _num(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {
          if (identical(c, rate)) rateTouched = true;
          if (identical(c, area)) unit = '';
        }),
      );

  Widget _unitPick() {
    final list = [for (final u in app.units) if (u.area > 0) u];
    return DropdownButtonFormField<String>(
      key: ValueKey('$mode-$unit'),
      initialValue: unit.isEmpty ? null : unit,
      isExpanded: true,
      decoration: const InputDecoration(labelText: "Or use a unit's size"),
      items: [for (final u in list) DropdownMenuItem(value: u.unit, child: Text('${u.unit} · ${u.area} sqm'))],
      onChanged: (v) => setState(() {
        unit = v ?? '';
        final u = list.where((x) => x.unit == v).firstOrNull;
        if (u != null) area.text = '${u.area}';
      }),
    );
  }

  /// (label, value, sub) for the big tile, the small tiles, a note, and the monthly rate to offer.
  ({String? label, String value, String sub, List<(String, String)> tiles, String note, double useRate}) _result() {
    final a = _parse(area.text), t = _parse(total.text), r = _parse(rate.text);
    final pl = _key;
    List<(String, String)> tilesFor(double monthly) => [
          ('Per day', peso(_round(monthly * 12 / 365))),
          ('Per month', peso(_round(monthly))),
          ('Per quarter', peso(_round(monthly * 3))),
          ('Per year', peso(_round(monthly * 12))),
        ];
    if (mode == _modes[0]) {
      if (!(a > 0) || !(r > 0)) return (label: null, value: '', sub: '', tiles: const [], note: 'Enter the size and the price per square meter.', useRate: 0.0);
      final amt = a * r;
      return (
        label: 'A ${_round(a)} sqm unit pays',
        value: peso(_round(amt)),
        sub: 'per $pl at ${peso(r)} per sqm per $pl',
        tiles: tilesFor(_toMonthly(amt, _key)),
        note: 'Every unit pays its own size × the rate, so a bigger unit pays more.',
        useRate: _toMonthly(r, _key),
      );
    }
    if (mode == _modes[1]) {
      if (!(a > 0) || !(t > 0)) return (label: null, value: '', sub: '', tiles: const [], note: 'Enter the total amount and the size.', useRate: 0.0);
      final per = t / a, pm = _toMonthly(per, _key);
      return (
        label: 'Price per square meter',
        value: peso(_round(per)),
        sub: 'per sqm per $pl (${peso(t)} ÷ ${_round(a)} sqm)',
        tiles: [
          ('Per sqm per day', peso(_round(pm * 12 / 365))),
          ('Per sqm per month', peso(_round(pm))),
          ('Per sqm per year', peso(_round(pm * 12))),
        ],
        note: 'Use this when you know what a whole unit should pay and want the rate that gives it.',
        useRate: pm,
      );
    }
    if (!(t > 0) || !(r > 0)) return (label: null, value: '', sub: '', tiles: const [], note: 'Enter the budget and the price per square meter.', useRate: 0.0);
    final sq = t / r;
    return (
      label: 'Size that fits the budget',
      value: '${_round(sq)} sqm',
      sub: '${peso(t)} per $pl ÷ ${peso(r)} per sqm',
      tiles: [
        ('Budget per month', peso(_round(_toMonthly(t, _key)))),
        ('Budget per year', peso(_round(_toMonthly(t, _key) * 12))),
        ('Rate per sqm per month', peso(_round(_toMonthly(r, _key)))),
      ],
      note: 'How big a unit can be for a given amount at this rate.',
      useRate: _toMonthly(r, _key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _result();
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: surface, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price calculator', style: hd(16)),
          const SizedBox(height: 2),
          Text('Work out dues for any size, per day, month or year. Nothing is saved until you tap the button at the bottom.', style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 10),
          FilterRow(options: _modes, selected: mode, onSelect: (v) => setState(() => mode = v)),
          const SizedBox(height: 4),
          Text('Quote the price', style: TextStyle(color: muted(context), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FilterRow(
            options: _periods,
            selected: period,
            onSelect: (v) => setState(() {
              period = v;
              rateTouched = false;
              _fillRate();
            }),
          ),
          const SizedBox(height: 8),
          if (mode == _modes[0]) ...[
            _num('Size (sqm)', area),
            const SizedBox(height: 10),
            _unitPick(),
            const SizedBox(height: 10),
            _num('Price per sqm (₱ per $_key)', rate),
          ] else if (mode == _modes[1]) ...[
            _num('Total amount (₱ per $_key)', total),
            const SizedBox(height: 10),
            _num('Size (sqm)', area),
            const SizedBox(height: 10),
            _unitPick(),
          ] else ...[
            _num('Budget (₱ per $_key)', total),
            const SizedBox(height: 10),
            _num('Price per sqm (₱ per $_key)', rate),
          ],
          const SizedBox(height: 12),
          if (res.label == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
              child: Text(res.note, textAlign: TextAlign.center, style: TextStyle(color: muted(context), fontSize: 12.5)),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF6C5CC7), Color(0xFF5B8DB8)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(res.label!.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(res.value, style: hd(28, color: Colors.white)),
                  Text(res.sub, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in res.tiles)
                  Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.surface, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1.toUpperCase(), style: TextStyle(color: muted(context), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                        const SizedBox(height: 2),
                        Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(res.note, style: TextStyle(color: muted(context), fontSize: 12.5)),
            if (res.useRate > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => widget.onUseRate(_round(res.useRate)),
                icon: const Icon(Icons.check_rounded),
                label: Text('Use ${peso(_round(res.useRate))} per sqm as the monthly rate'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
