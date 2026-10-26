// ADMIN page: Settings (rates, payment methods, password).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../shared/profile_widgets.dart';

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

  @override
  void dispose() {
    for (final c in [name, phone, cur, nw, conf]) {
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
        subtitle: 'Your profile, password and appearance.',
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
