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
  late final limitC = TextEditingController(text: '${app.complaintLimit}');
  late Set<String> hid = {...app.hiddenNav};
  int _custPage = 0;

  static const _navPages = [
    ['book', 'Book a facility'],
    ['res', 'My reservations'],
    ['dues', 'Dues and finance documents'],
    ['parking', 'Parking'],
    ['events', 'Events'],
    ['polls', 'Polls'],
    ['directory', 'Directory'],
    ['gr', 'Complaints'],
    ['docs', 'Community documents'],
  ];

  @override
  void dispose() {
    for (final c in [autoHours, limitC]) {
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

  void _editCustom([CustomRem? cur]) {
    showFormSheet(
      context,
      title: cur == null ? 'Add a reminder' : 'Edit reminder',
      subtitle: 'Residents see this as a pop-up on their home screen and in the notification bell.',
      fields: [
        FieldSpec('title', 'Title', hint: 'e.g. Water interruption on Friday', initial: cur?.title ?? ''),
        FieldSpec('text', 'Message', lines: 4, hint: 'What should residents know or do?', initial: cur?.text ?? ''),
        FieldSpec('units', 'Units (only if you chose certain units)', hint: 'e.g. 12C, 8A, 15B', initial: cur?.units ?? '', onlyWhenKey: 'aud', onlyWhenValue: 'Only certain units', belowChoice: true),
      ],
      choices: [
        ChoiceSpec('aud', 'Who gets it', const ['All residents', 'Only certain units'], cur?.aud == 'units' ? 'Only certain units' : 'All residents'),
        ChoiceSpec('freq', 'Pop-up on the resident\u2019s home screen', customFreqLabels.values.toList(), customFreqLabels[cur?.freq ?? 'once']!),
      ],
      dates: [
        DateSpec('from', 'Start showing on', cur?.from ?? dayKey(DateTime.now())),
        DateSpec('to', 'Stop showing after (optional)', cur?.to ?? '', clearable: true, emptyText: 'No end date'),
      ],
      submit: cur == null ? 'Add reminder' : 'Save',
      onSubmit: (v) {
        final title = '${v['title']}'.trim(), text = '${v['text']}'.trim();
        final from = '${v['from'] ?? ''}', to = '${v['to'] ?? ''}';
        final units = v['aud'] == 'Only certain units';
        if (title.isEmpty) return 'Write a title.';
        if (text.isEmpty) return 'Write the message residents will read.';
        if (to.isNotEmpty && from.isNotEmpty && to.compareTo(from) < 0) return 'The end date is before the start date.';
        if (units && '${v['units']}'.replaceAll(RegExp(r'[,;\s]'), '').isEmpty) return 'Type at least one unit, or choose all residents.';
        final freq = customFreqLabels.entries.firstWhere((e) => e.value == v['freq'], orElse: () => customFreqLabels.entries.first).key;
        app.saveCustomRem(CustomRem(
          id: cur?.id ?? 'c${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          text: text,
          from: from,
          to: to,
          freq: freq,
          aud: units ? 'units' : 'all',
          units: units ? '${v['units']}'.trim() : '',
          on: cur?.on ?? true,
        ));
        return null;
      },
    );
  }

  Future<void> _saveLimit() async {
    final n = int.tryParse(limitC.text.trim());
    if (n == null || n < 1 || n > 10) {
      msg(context, 'Enter a whole number from 1 to 10.');
      return;
    }
    if (n == app.complaintLimit) {
      msg(context, 'The limit is already $n.');
      return;
    }
    final ok = await confirmDialog(
      context,
      'Change the complaint limit?',
      'Each unit will be allowed $n open complaint${n == 1 ? '' : 's'} at a time (now ${app.complaintLimit}). ${n > app.complaintLimit ? 'A higher limit can invite spam. ' : ''}Complaints that are already open stay as they are.',
      confirm: 'Yes, change it',
      destructive: n > app.complaintLimit,
    );
    if (!ok || !mounted) return;
    app.setComplaintLimit(n);
    msg(context, 'Saved. Each unit can have $n open complaint${n == 1 ? '' : 's'}.');
  }

  Future<void> _saveNav() async {
    final names = [for (final p in _navPages) if (hid.contains(p[0])) p[1]];
    final ok = await confirmDialog(
      context,
      'Save the resident menu?',
      names.isEmpty ? 'Residents will see every page.' : 'Residents will no longer see: ${names.join(', ')}.',
      confirm: 'Save',
    );
    if (!ok || !mounted) return;
    app.setHiddenNav(hid);
    msg(context, 'Saved. Residents see the new menu straight away.');
  }

  @override
  Widget build(BuildContext context) {
    final customs = app.customRems.reversed.toList();
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
                  Text(L('Account & security', 'Account at security'), style: hd(18)),
                  Text(L('Profile, password, devices, language, appearance', 'Profile, password, devices, language, itsura'), style: TextStyle(color: muted(context), fontSize: 12.5)),
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
                Row(children: [
                  Expanded(child: Text('Your own reminders', style: hd(18))),
                  FilledButton.icon(onPressed: () => _editCustom(), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add')),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Write any reminder you like (a meeting, a water interruption, a deadline). Residents see it as a pop-up and in their notification bell between the dates you choose.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                if (customs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('No reminders of your own yet. Tap Add to write one.', style: TextStyle(color: muted(context))),
                  ),
                for (final r in pageOf(customs, _custPage, 5)) ...[
                  const Divider(height: 24),
                  Row(children: [
                    Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    Pill(r.on ? 'On' : 'Off', tone: r.on ? Tone.good : Tone.info),
                  ]),
                  const SizedBox(height: 2),
                  Text(r.text, style: const TextStyle(fontSize: 13, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(
                    '${r.from.isEmpty ? 'Starts now' : 'From ${shortDate((DateTime.tryParse(r.from) ?? DateTime.now()))}'}${r.to.isEmpty ? ', no end date' : ' until ${shortDate((DateTime.tryParse(r.to) ?? DateTime.now()))}'} \u00B7 '
                    '${r.aud == 'units' ? 'Only ${r.units}' : 'All residents'} \u00B7 ${(customFreqLabels[r.freq] ?? '').toLowerCase()}',
                    style: TextStyle(color: muted(context), fontSize: 12),
                  ),
                  Wrap(spacing: 6, children: [
                    TextButton(onPressed: () => _editCustom(r), child: const Text('Edit')),
                    TextButton(onPressed: () => app.toggleCustomRem(r.id), child: Text(r.on ? 'Turn off' : 'Turn on')),
                    TextButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Delete this reminder?', '\u201C${r.title}\u201D will no longer be shown to residents.', confirm: 'Delete', destructive: true);
                        if (ok) app.deleteCustomRem(r.id);
                      },
                      child: const Text('Delete', style: TextStyle(color: danger)),
                    ),
                  ]),
                ],
                PagerBar(page: _custPage, per: 5, total: customs.length, onPage: (p) => setState(() => _custPage = p)),
              ],
            ),
          ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Complaints', style: hd(18)),
                const SizedBox(height: 4),
                Text(
                  'How many open complaints one unit may have at the same time. A resident can send another one only after you resolve one of theirs. The usual limit is 1.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextField(controller: limitC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Open complaints allowed per unit')),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: toneOf(context, Tone.warn).bg, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'Be careful with this number. A higher limit lets one unit send many complaints at once. That can fill your list with spam and hide the real problems.',
                    style: TextStyle(color: toneOf(context, Tone.warn).fg, fontSize: 12.5, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _saveLimit, child: const Text('Save limit'))),
              ],
            ),
          ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resident menu', style: hd(18)),
                const SizedBox(height: 4),
                Text(
                  'Choose which pages residents see. A page you switch off disappears for every resident until you switch it on again. Home, Unit status and Settings always stay.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                for (final p in _navPages)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p[1], style: const TextStyle(fontWeight: FontWeight.w700)),
                    value: !hid.contains(p[0]),
                    activeThumbColor: lavDeep,
                    onChanged: (v) => setState(() => v ? hid.remove(p[0]) : hid.add(p[0])),
                  ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _saveNav, child: const Text('Save menu'))),
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
