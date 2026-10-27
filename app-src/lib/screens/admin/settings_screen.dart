// ADMIN page: Settings (rates, payment methods, password).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../shared/profile_widgets.dart';
import 'access_screen.dart';

/// Administrator profile and password (More > Settings).
class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  late final name = TextEditingController(text: app.adminName);
  late final phone = TextEditingController(text: app.adminPhone);
  final cur = TextEditingController();
  final nw = TextEditingController();
  final conf = TextEditingController();
  late bool autoOn = app.autoPostOn;
  late final autoHours = TextEditingController(text: '${app.autoPostHours}');

  @override
  void dispose() {
    for (final c in [name, phone, cur, nw, conf, autoHours]) {
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
        subtitle: 'Your profile, who can sign in, payments, password and appearance.',
        children: [
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: hd(18)),
                const SizedBox(height: 12),
                ProfilePhotoEditor(
                  initials: initialsOf(app.adminName),
                  photo: app.adminPhoto,
                  onChange: app.setAdminPhoto,
                ),
                const SizedBox(height: 16),
                TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: app.adminEmail),
                  decoration: const InputDecoration(labelText: 'Email address', helperText: 'This is the email you sign in with.'),
                ),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number (optional)')),
                const SizedBox(height: 10),
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: 'Owner · Administrator'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final err = await session.saveProfile(name.text, phone.text);
                      if (context.mounted) msg(context, err ?? 'Profile updated.');
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
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
              ],
            ),
          ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: hd(18)),
                const SizedBox(height: 4),
                Text('Change the administrator password.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                const SizedBox(height: 14),
                TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
                const SizedBox(height: 10),
                TextField(controller: nw, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
                PasswordRulesList(controller: nw),
                const SizedBox(height: 10),
                TextField(controller: conf, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final err = await session.changePassword(cur.text, nw.text, conf.text);
                      if (err == null) {
                        cur.clear();
                        nw.clear();
                        conf.clear();
                      }
                      if (context.mounted) msg(context, err ?? 'Password updated.');
                    },
                    child: const Text('Update password'),
                  ),
                ),
              ],
            ),
          ),
          RCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Easier on the eyes at night'),
              value: app.dark,
              activeThumbColor: lavDeep,
              onChanged: (_) => app.toggleDark(),
            ),
          ),
        ],
      ),
    );
  }
}
