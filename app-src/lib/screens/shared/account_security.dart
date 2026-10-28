// ADMIN and RESIDENT: Settings > Account & security. All settings in one place, manage profile,
// password manager, device management and language.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../../services/demo.dart' show kDemo;
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../admin/access_screen.dart';
import 'profile_widgets.dart';

class AccountSecurityScreen extends StatefulWidget {
  /// True for the administrator (a few extra shortcuts, and the mobile number is editable).
  final bool admin;
  final int initialTab;
  const AccountSecurityScreen({super.key, required this.admin, this.initialTab = 0});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityState();
}

class _AccountSecurityState extends State<AccountSecurityScreen> {
  late int tab = widget.initialTab;
  late final name = TextEditingController(text: widget.admin ? app.adminName : app.me?.name ?? '');
  late final phone = TextEditingController(text: widget.admin ? app.adminPhone : app.me?.phone ?? '');
  final cur = TextEditingController();
  final nw = TextEditingController();
  final conf = TextEditingController();
  bool show = false, signOutOthers = true, busy = false;

  @override
  void dispose() {
    for (final c in [name, phone, cur, nw, conf]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _tabs => [L('All settings', 'Lahat ng settings'), L('Profile', 'Profile'), L('Password', 'Password'), L('Devices', 'Devices'), L('Language', 'Language')];

  String _date(DateTime d) => shortDate(d);

  // ------------------------------------------------------------------ overview
  Widget _tile(IconData icon, String title, String sub, {int? goTab, VoidCallback? onTap, Widget? trailing}) {
    return NavTile(
      icon: icon,
      title: title,
      subtitle: sub,
      trailing: trailing,
      onTap: onTap ?? () => setState(() => tab = goTab ?? 0),
    );
  }

  Widget _overview(BuildContext context) {
    final lang = kLanguages.firstWhere((l) => l.code == app.lang);
    final who = widget.admin ? app.adminName : app.me?.name ?? '';
    final mail = widget.admin ? app.adminEmail : app.me?.email ?? '';
    final pw = app.passwordChangedAt;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tile(Icons.person_outline_rounded, L('Manage profile', 'I-manage ang profile'), '$who · $mail', goTab: 1),
      const SizedBox(height: 10),
      _tile(Icons.key_rounded, L('Password', 'Password'), pw == null ? L('Not changed on this device yet', 'Hindi pa nababago sa device na ito') : '${L('Last changed', 'Last na binago noong')} ${_date(pw)}', goTab: 2),
      const SizedBox(height: 10),
      _tile(Icons.devices_other_rounded, L('Devices', 'Devices'), '${app.sessions.length} ${L('signed in', 'naka-sign in')}', goTab: 3),
      const SizedBox(height: 10),
      _tile(Icons.language_rounded, L('Language', 'Language'), '${lang.name} · ${lang.native}', goTab: 4),
      const SizedBox(height: 10),
      RCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(L('Dark mode', 'Dark mode'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(L('Easier on the eyes at night', 'Mas madali sa mata kapag gabi')),
          value: app.dark,
          activeThumbColor: lavDeep,
          onChanged: (_) => app.toggleDark(),
        ),
      ),
      if (widget.admin) ...[
        const SizedBox(height: 10),
        _tile(Icons.admin_panel_settings_outlined, L('Access', 'Access'), '${app.trusted.length + 1} ${L('accounts · who can sign in', 'accounts · sino ang puwedeng mag-sign in')}', onTap: () => go(context, const AdminAccess())),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            if (await confirmDialog(context, L('Log out?', 'Mag-log out?'), L('You will need to sign in again on this device.', 'Kailangan mong mag-sign in ulit sa device na ito.'), confirm: L('Log out', 'Mag-log out'))) {
              await session.signOut();
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text(L('Log out', 'Mag-log out')),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------------ profile
  Widget _profile(BuildContext context) {
    final admin = widget.admin;
    final mail = admin ? app.adminEmail : app.me?.email ?? '';
    return RCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('Manage profile', 'I-manage ang profile'), style: hd(18)),
        const SizedBox(height: 4),
        Text(admin ? L('Your name and mobile number. The email is what you sign in with.', 'Ang name at mobile number mo. Ang email ang gamit mo sa pag-sign in.') : L('Your unit assignment and mobile number can only be changed by the administrator.', 'Ang administrator lang ang puwedeng magpalit ng unit at mobile number mo.'), style: TextStyle(color: muted(context), fontSize: 12.5)),
        const SizedBox(height: 14),
        ProfilePhotoEditor(
          initials: initialsOf(admin ? app.adminName : app.me?.name ?? ''),
          photo: admin ? app.adminPhoto : app.me?.photo,
          onChange: admin ? app.setAdminPhoto : app.setMyPhoto,
        ),
        const SizedBox(height: 14),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: L('Full name', 'Full name'))),
        const SizedBox(height: 10),
        TextField(enabled: false, controller: TextEditingController(text: mail), decoration: InputDecoration(labelText: L('Email address (used to sign in)', 'Email (pang-sign in)'))),
        const SizedBox(height: 10),
        TextField(
          controller: phone,
          enabled: admin,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: admin ? L('Mobile number (optional)', 'Mobile number (optional)') : L('Mobile number (verified; ask the administrator to change it)', 'Mobile number (verified na; sa administrator ka magpabago nito)')),
        ),
        const SizedBox(height: 10),
        TextField(
          enabled: false,
          controller: TextEditingController(text: admin ? L('Owner · Administrator', 'Owner · Administrator') : app.me?.unit ?? ''),
          decoration: InputDecoration(labelText: admin ? L('Role', 'Role') : L('Unit (set by administrator)', 'Unit (itinakda ng administrator)')),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              final err = await session.saveProfile(name.text, phone.text);
              if (context.mounted) msg(context, err ?? L('Profile updated.', 'Na-update na ang profile mo.'));
            },
            child: Text(L('Save changes', 'I-save ang changes')),
          ),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ password manager
  int _score(String p) {
    if (p.isEmpty) return 0;
    final n = passwordRules.where((r) => r.test(p)).length + (p.length >= 12 ? 1 : 0) + (p.length >= 16 ? 1 : 0);
    return min(n, 6);
  }

  void _generate() {
    const sets = ['ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#\$%&*?'];
    final r = Random.secure(), all = sets.join();
    final out = [for (final s in sets) s[r.nextInt(s.length)], for (var i = sets.length; i < 16; i++) all[r.nextInt(all.length)]]..shuffle(r);
    final pw = out.join();
    setState(() {
      nw.text = pw;
      conf.text = pw;
      show = true;
    });
    msg(context, L('Strong password made. Copy it and keep it somewhere safe.', 'Nakagawa na ng matibay na password. I-copy ito at itago sa safe na lugar.'));
  }

  Future<void> _savePassword() async {
    if (cur.text.isNotEmpty && nw.text == cur.text) {
      msg(context, L('Choose a password that is different from the current one.', 'Pumili ng password na iba sa current mo.'));
      return;
    }
    setState(() => busy = true);
    final err = await session.changePassword(cur.text, nw.text, conf.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      msg(context, err);
      return;
    }
    cur.clear();
    nw.clear();
    conf.clear();
    app.passwordChangedNow(signOutOthers: signOutOthers);
    msg(context, kDemo ? L('Password checked. This is the prototype, so your real sign-in password is not changed.', 'Na-check na ang password. Prototype lang ito, kaya hindi nagbabago ang totoong password mo.') : L('Password updated.', 'Napalitan na ang password mo.'));
  }

  Widget _password(BuildContext context) {
    final pw = app.passwordChangedAt;
    return Column(children: [
      RCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Password manager', 'Password manager'), style: hd(18)),
          const SizedBox(height: 4),
          Text(pw == null ? L('Change it now and then, and never reuse it on other sites.', 'Palitan paminsan-minsan, at huwag gamitin sa ibang sites.') : '${L('Last changed', 'Last na binago noong')} ${_date(pw)}.', style: TextStyle(color: muted(context), fontSize: 12.5)),
          const SizedBox(height: 14),
          TextField(controller: cur, obscureText: !show, decoration: InputDecoration(labelText: L('Current password', 'Current password'))),
          const SizedBox(height: 10),
          TextField(controller: nw, obscureText: !show, decoration: InputDecoration(labelText: L('New password', 'New password'))),
          ListenableBuilder(
            listenable: nw,
            builder: (context, _) {
              final s = _score(nw.text);
              final label = nw.text.isEmpty ? '' : s <= 2 ? L('Weak', 'Mahina') : s <= 4 ? L('Fair', 'Okay lang') : s == 5 ? L('Good', 'Maganda') : L('Strong', 'Matibay');
              final color = s <= 2 ? const Color(0xFFD8584A) : s <= 4 ? const Color(0xFFE5A33A) : const Color(0xFF14A38B);
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: s / 6, minHeight: 8, color: color, backgroundColor: color.withAlpha(36)),
                    ),
                  ),
                  SizedBox(width: 74, child: Text('  $label', style: TextStyle(color: muted(context), fontWeight: FontWeight.w700, fontSize: 12))),
                ]),
              );
            },
          ),
          PasswordRulesList(controller: nw),
          const SizedBox(height: 10),
          TextField(controller: conf, obscureText: !show, decoration: InputDecoration(labelText: L('Confirm new password', 'Confirm new password'))),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: show,
            onChanged: (v) => setState(() => show = v ?? false),
            title: Text(L('Show passwords', 'Ipakita ang passwords'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: signOutOthers,
            onChanged: (v) => setState(() => signOutOthers = v ?? false),
            title: Text(L('Sign out my other devices after changing', 'I-sign out ang iba kong devices pagkatapos magpalit'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: busy ? null : _savePassword, child: Text(L('Update password', 'I-update ang password'))),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome_rounded, size: 18), label: Text(L('Make a strong one', 'Gumawa ng matibay na password')))),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () async {
                if (nw.text.isEmpty) {
                  msg(context, L('Nothing to copy yet.', 'Wala pang puwedeng i-copy.'));
                  return;
                }
                await Clipboard.setData(ClipboardData(text: nw.text));
                if (context.mounted) msg(context, L('Copied.', 'Na-copy na.'));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(L('Copy', 'I-copy')),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      RCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Keep it safe', 'Ingatan ito'), style: hd(17)),
          const SizedBox(height: 8),
          for (final t in [
            L('Use a password only you know, at least 12 characters.', 'Gumamit ng password na ikaw lang ang may alam, at at least 12 characters.'),
            L('The office and the app will never ask you for your password.', 'Hindi hihingin ng office o ng app ang password mo kahit kailan.'),
            L('Use a password manager on your phone to store it.', 'Gumamit ng password manager sa phone para hindi mo makalimutan.'),
            L('Lost a phone? Sign out that device under Devices.', 'Nawala ang phone mo? I-sign out ang device na \'yon sa Devices.'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_rounded, size: 17, color: muted(context)),
                const SizedBox(width: 8),
                Expanded(child: Text(t, style: TextStyle(color: muted(context), fontSize: 13, height: 1.35))),
              ]),
            ),
        ]),
      ),
    ]);
  }

  // ------------------------------------------------------------------ devices
  IconData _devIcon(String k) => switch (k) {
        'phone' => Icons.smartphone_rounded,
        'tablet' => Icons.tablet_mac_rounded,
        _ => Icons.computer_rounded,
      };

  Widget _devices(BuildContext context) {
    final list = app.sessions;
    final hasSample = list.any((s) => s.sample);
    return Column(children: [
      RCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(child: Text(L('Manage devices', 'I-manage ang devices'), style: hd(18))),
              Pill('${list.length}'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text(L('Where this account is signed in. Sign out any device you do not recognise.', 'Dito naka-sign in ang account na ito. I-sign out ang device na hindi mo kilala.'), style: TextStyle(color: muted(context), fontSize: 12.5))),
          ),
          for (final s in list)
            ListTile(
              leading: IconBadge(_devIcon(s.kind), tone: s.current ? Tone.good : null, accent: !s.current, size: 40),
              title: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(s.device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (s.current) Pill(L('This device', 'Ang device na ito'), tone: Tone.good),
                if (s.sample) Pill(L('Sample', 'Sample')),
              ]),
              subtitle: Text('${s.location} · ${s.when}'),
              trailing: s.current
                  ? null
                  : TextButton(
                      style: TextButton.styleFrom(foregroundColor: danger),
                      onPressed: () {
                        app.signOutSession(s.id);
                        msg(context, '${L('Signed out on', 'Na-sign out sa')} ${s.device}.');
                      },
                      child: Text(L('Sign out', 'I-sign out')),
                    ),
            ),
          if (hasSample)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(L('In this prototype the other devices are samples so you can try the buttons. A live system lists real sessions.', 'Sa prototype na ito, sample lang ang ibang devices para masubukan ang mga button. Totoong sessions ang makikita sa live na system.'), style: TextStyle(color: muted(context), fontSize: 12)),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      RCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: list.length <= 1
                  ? null
                  : () {
                      app.signOutOtherSessions();
                      msg(context, L('Signed out on all other devices.', 'Na-sign out na ang lahat ng ibang devices.'));
                    },
              child: Text(L('Sign out all other devices', 'I-sign out ang lahat ng ibang device')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: danger),
              onPressed: () async {
                if (await confirmDialog(context, L('Log out on all devices?', 'Mag-log out sa lahat ng devices?'), L('You will need to sign in again everywhere.', 'Kailangan mong mag-sign in ulit sa lahat ng devices.'), confirm: L('Log out', 'Mag-log out'), destructive: true)) {
                  await session.signOut();
                }
              },
              child: Text(L('Log out on all devices', 'Mag-log out sa lahat ng device')),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(L('Tell me when a new device signs in', 'I-notify ako kapag may bagong device na nag-sign in'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            value: app.newDeviceAlert,
            activeThumbColor: lavDeep,
            onChanged: app.setNewDeviceAlert,
          ),
        ]),
      ),
    ]);
  }

  // ------------------------------------------------------------------ language
  Widget _language(BuildContext context) {
    return Column(children: [
      RCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Language', 'Language'), style: hd(18)),
          const SizedBox(height: 4),
          Text(L('Choose the language for the menus and page titles.', 'Piliin ang language para sa mga menu at page titles.'), style: TextStyle(color: muted(context), fontSize: 12.5)),
          const SizedBox(height: 12),
          for (final l in kLanguages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  app.setLang(l.code);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: app.lang == l.code ? lavDeep : muted(context).withAlpha(70), width: app.lang == l.code ? 2 : 1.2),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(app.lang == l.code ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: app.lang == l.code ? lavDeep : muted(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(l.native, style: TextStyle(color: muted(context), fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Text(l.sample, style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      RCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('What changes', 'Ano ang magbabago'), style: hd(17)),
          const SizedBox(height: 6),
          Text(
            L('Menus, page titles and this Account & security area change language. Other screens, such as lists and forms, stay in English for now. The choice is kept while the app is open.', 'Magbabago ang language ng mga menu, page titles, at ng Account at security na ito. Ang ibang screens, gaya ng lists at forms, ay English muna sa ngayon. Nananatili ang pinili mo habang bukas ang app.'),
            style: TextStyle(color: muted(context), fontSize: 13, height: 1.4),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final tabs = _tabs;
        return SubPage(
          title: 'Settings',
          subtitle: L('All your settings, profile, password, devices and language.', 'Lahat ng settings mo: profile, password, devices at language.'),
          children: [
            FilterRow(options: tabs, selected: tabs[tab], onSelect: (v) => setState(() => tab = tabs.indexOf(v))),
            switch (tab) {
              1 => _profile(context),
              2 => _password(context),
              3 => _devices(context),
              4 => _language(context),
              _ => _overview(context),
            },
          ],
        );
      },
    );
  }
}
