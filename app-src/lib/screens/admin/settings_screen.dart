// ADMIN page: Settings (account & security, access, payments).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/account_security.dart';
import 'access_screen.dart';

/// Administrator settings (More > Settings).
class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  late bool autoOn = app.autoPostOn;
  late bool lateOn = app.lateFeeOn;
  late final lateDays = TextEditingController(text: '${app.lateFeeDays}');
  late final latePctC = TextEditingController(text: '${app.latePct}');
  late final autoHours = TextEditingController(text: '${app.autoPostHours}');

  @override
  void dispose() {
    for (final c in [autoHours]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SubPage(
        title: 'Settings',
        subtitle: 'Your account and security, who can sign in, and payments.',
        children: [
          RCard(
            onTap: () => go(context, const AccountSecurityScreen(admin: true)),
            child: Row(children: [
              Avatar(initialsOf(app.adminName), size: 46, photo: app.adminPhoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(L('Account & security', 'Account at seguridad'), style: hd(18)),
                  Text(L('Profile, password, devices, language, appearance', 'Profile, password, device, wika, hitsura'), style: TextStyle(color: muted(context), fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
          RCard(
            onTap: () => go(context, const AdminAccess()),
            child: Row(children: [
              const IconBadge(Icons.admin_panel_settings_outlined, accent: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Access', style: hd(18)),
                  Text('${app.trusted.length + 1} accounts · create, suspend or remove sign-ins', style: TextStyle(color: muted(context), fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payments', style: hd(18)),
                const SizedBox(height: 4),
                Text(
                  'When a resident sends payment details that match their charge, the system can post the payment and issue the receipt by itself after the waiting time below. Payments that do not match always wait for you.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Post matching payments automatically', style: TextStyle(fontWeight: FontWeight.w700)),
                  value: autoOn,
                  activeThumbColor: lavDeep,
                  onChanged: (v) => setState(() => autoOn = v),
                ),
                TextField(
                  controller: autoHours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Wait this many hours first', helperText: 'Default is 24 hours after the resident sent it.'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final h = int.tryParse(autoHours.text.trim());
                      if (h == null || h < 1 || h > 720) {
                        msg(context, 'Enter a number of hours from 1 to 720.');
                        return;
                      }
                      app.setAutoPost(autoOn, h);
                      msg(context, autoOn ? 'Saved. Matching payments post $h hours after they are sent.' : 'Saved. Automatic posting is off.');
                    },
                    child: const Text('Save payment settings'),
                  ),
                ),
                const Divider(height: 28),
                Text('Late charge', style: hd(18)),
                const SizedBox(height: 4),
                Text(
                  'When a charge is still unpaid after its due date, a late charge is added by itself, so an overdue charge never just sits there. It is added during the first week of being overdue (older ones are handled with “Did they pay?”), skipped if the resident already sent their payment, and taken off again if they turn out to have paid on time.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add the late charge automatically', style: TextStyle(fontWeight: FontWeight.w700)),
                  value: lateOn,
                  activeThumbColor: lavDeep,
                  onChanged: (v) => setState(() => lateOn = v),
                ),
                TextField(controller: lateDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'After how many days overdue')),
                const SizedBox(height: 10),
                TextField(controller: latePctC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Late charge (% of the charge)')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      final days = int.tryParse(lateDays.text.trim());
                      final pct = double.tryParse(latePctC.text.trim());
                      if (days == null || days < 1 || days > 30) {
                        msg(context, 'Enter the number of days, from 1 to 30.');
                        return;
                      }
                      if (pct == null || pct <= 0 || pct > 100) {
                        msg(context, 'Enter the late charge as a percentage, from 0.1 to 100.');
                        return;
                      }
                      app.setLateFee(lateOn, days, pct);
                      msg(context, lateOn ? 'Saved. A $pct% late charge is added $days day${days == 1 ? '' : 's'} after the due date.' : 'Saved. Late charges are no longer added by themselves.');
                    },
                    child: const Text('Save late charge'),
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
