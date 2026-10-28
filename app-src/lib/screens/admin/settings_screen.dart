// ADMIN page: Settings (account & security, access, payments).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../resident/reminder_popup.dart';
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

  void _editReminder(String kind) {
    final c = app.remOf(kind);
    showFormSheet(
      context,
      title: 'Edit reminder: ${remNames[kind]}',
      subtitle: 'You can use these words in the message and they are filled in for each resident: ${remTokens[kind]}. Leave the message empty to use the standard one.',
      toggles: [ToggleSpec('on', 'Reminder on', c.on)],
      fields: [
        FieldSpec('days', 'Start reminding this many days before the due date', type: TextInputType.number, initial: '${c.days}'),
        FieldSpec('msg', 'Message', lines: 4, hint: remDefaultText[kind], initial: c.msg),
      ],
      choices: [ChoiceSpec('freq', 'Pop-up on the resident\u2019s home screen', remFreqLabels.values.toList(), remFreqLabels[c.freq] ?? remFreqLabels['every']!)],
      submit: 'Save',
      onSubmit: (v) {
        final days = int.tryParse('${v['days']}'.trim());
        if (days == null || days < 1 || days > 60) return 'Choose between 1 and 60 days.';
        final freq = remFreqLabels.entries.firstWhere((e) => e.value == v['freq'], orElse: () => remFreqLabels.entries.first).key;
        app.setRem(kind, RemCfg(on: v['on'] == true, days: days, freq: freq, msg: '${v['msg']}'.trim()));
        return null;
      },
    );
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
                Text('Reminders', style: hd(18)),
                const SizedBox(height: 4),
                Text(
                  'Reminders pop up on the resident\u2019s home screen, appear in the notification bell and on the dashboard. Choose when they start, how often they pop up and what they say.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                for (final k in remKinds) ...[
                  const Divider(height: 26),
                  Row(children: [
                    Expanded(child: Text(remNames[k]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    Pill(app.remOf(k).on ? 'On' : 'Off', tone: app.remOf(k).on ? Tone.good : Tone.info),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    app.remOf(k).on
                        ? 'Starts ${app.remOf(k).days} day${app.remOf(k).days == 1 ? '' : 's'} before the due date. Pop-up: ${(remFreqLabels[app.remOf(k).freq] ?? '').toLowerCase()}.'
                        : 'Off. Residents are not reminded.',
                    style: TextStyle(color: muted(context), fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: lav.withAlpha(40), borderRadius: BorderRadius.circular(14)),
                    child: Text(app.remCustom(k) ? app.remOf(k).msg.trim() : remDefaultText[k]!, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton(onPressed: () => _editReminder(k), child: const Text('Edit reminder')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => showReminderPreview(context, k), child: const Text('Preview')),
                  ]),
                ],
              ],
            ),
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
