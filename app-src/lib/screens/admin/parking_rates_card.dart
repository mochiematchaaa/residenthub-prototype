// ADMIN: Motor parking rental rates. The rental depends on the size of the slot, so every size has its own monthly and daily rate.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class ParkingRatesCard extends StatefulWidget {
  const ParkingRatesCard({super.key});

  @override
  State<ParkingRatesCard> createState() => _ParkingRatesCardState();
}

class _ParkingRatesCardState extends State<ParkingRatesCard> {
  late final List<ParkSize> sizes = app.parkSizes;
  late final sqm = [for (final z in sizes) TextEditingController(text: z.sqm == 0 ? '' : '${z.sqm}')];
  late final month = [for (final z in sizes) TextEditingController(text: z.month == 0 ? '' : '${z.month}')];
  late final day = [for (final z in sizes) TextEditingController(text: z.day == 0 ? '' : '${z.day}')];

  @override
  void dispose() {
    for (final c in [...sqm, ...month, ...day]) {
      c.dispose();
    }
    super.dispose();
  }

  num _n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  void _save() {
    final list = [for (var i = 0; i < sizes.length; i++) ParkSize(sizes[i].name, _n(sqm[i]) > 0 ? _n(sqm[i]) : sizes[i].sqm, _n(month[i]), _n(day[i]))];
    final err = app.setParkSizes(list);
    msg(context, err ?? 'Parking rates saved.');
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in app.slots) {
      counts[s.size] = (counts[s.size] ?? 0) + 1;
    }
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const IconBadge(Icons.two_wheeler_rounded, accent: true),
            const SizedBox(width: 12),
            Expanded(child: Text('Motor parking rental', style: hd(17))),
          ]),
          const SizedBox(height: 8),
          Text(
            'The rental depends on the size of the slot. Give every size its own monthly and daily rate. Residents see the price on each slot of the parking map. Set the size of each slot under Motor parking. Leave a daily rate empty to hide the daily option for that size.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
          for (var i = 0; i < sizes.length; i++) ...[
            const Divider(height: 22),
            Row(children: [
              Text(sizes[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('${counts[sizes[i].name] ?? 0} slots', style: TextStyle(color: muted(context), fontSize: 12)),
              const Spacer(),
              Text(_n(sqm[i]) > 0 && _n(month[i]) > 0 ? '${peso((_n(month[i]) / _n(sqm[i])).toDouble())} / sqm / month' : '', style: TextStyle(color: muted(context), fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: sqm[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Slot size (sqm)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: month[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: '₱ / month'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: day[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '₱ / day'))),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Save parking rates'))),
        ],
      ),
    );
  }
}
