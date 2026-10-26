// ADMIN page: Manage access (create, reset, suspend and delete resident accounts).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

class AdminAccess extends StatefulWidget {
  const AdminAccess({super.key});

  @override
  State<AdminAccess> createState() => _AdminAccessState();
}

class _AdminAccessState extends State<AdminAccess> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = q.trim().toLowerCase();
        final list = app.trusted.where((t) => s.isEmpty || '${t.name} ${t.email} ${t.unit} ${t.role}'.toLowerCase().contains(s)).toList();
        return SubPage(
          title: 'Manage access',
          subtitle: 'Only the administrator can create accounts. There is no public sign-up: every resident account is added by hand and linked to a unit.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New account'),
            onPressed: () => showFormSheet(
              context,
              title: 'Create a new account',
              fields: const [
                FieldSpec('name', 'Full name', hint: 'e.g. Ana Reyes'),
                FieldSpec('email', 'Email address', type: TextInputType.emailAddress, hint: 'e.g. ana.reyes@gmail.com'),
                FieldSpec('phone', 'Mobile number (optional)', type: TextInputType.phone, hint: 'e.g. 0917 555 0000'),
                FieldSpec('unit', 'Unit (must already exist under Units)', hint: 'e.g. Unit 12A'),
              ],
              submit: 'Create account',
              onSubmit: (v) async {
                var unit = (v['unit'] ?? '').toString().trim();
                // accept "12a" or "Unit 12a" and match it with a unit on record
                String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
                final found = app.units.where((u) => norm(u.unit) == norm(unit) && norm(unit).isNotEmpty).toList();
                if (found.isNotEmpty) unit = found.first.unit;
                final r = await session.createResident(v['name'] as String, v['email'] as String, v['phone'] as String, unit);
                if (r.error != null) return r.error;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) _showPassword(context, (v['email'] as String).trim(), r.password ?? '', created: true);
                });
                return null;
              },
            ),
          ),
          children: [
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(hintText: 'Search name, email or unit…', prefixIcon: Icon(Icons.search_rounded)),
            ),
            RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Avatar(initialsOf(app.adminName), size: 42, photo: app.adminPhoto),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.adminName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${app.adminEmail} · cannot be revoked here', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Pill('Administrator', tone: Tone.info),
                ],
              ),
            ),
            for (final t in list)
              Opacity(
                opacity: t.suspended ? 0.6 : 1,
                child: RCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(initialsOf(t.name), size: 42, bg: lavDeep),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(t.email, style: TextStyle(color: muted(context), fontSize: 12.5)),
                                Text('${t.phone}${t.unit.isNotEmpty ? ' · ${t.unit}' : ''}${t.added.isEmpty ? '' : ' · Added ${t.added}'}', style: TextStyle(color: muted(context), fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Pill(t.role, tone: Tone.good),
                              const SizedBox(height: 4),
                              Pill(t.suspended ? 'Suspended' : (t.verified ? 'Active' : 'Not verified yet'), tone: (!t.suspended && !t.verified) ? Tone.warn : null),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirmDialog(context, 'Reset password?', 'This replaces ${t.name}\'s password with a temporary one. Share it with them privately.', confirm: 'Reset');
                            if (!ok || !context.mounted) return;
                            final r = await session.resetPassword(t);
                            if (!context.mounted) return;
                            if (r.error != null) {
                              msg(context, r.error!);
                              return;
                            }
                            await _showPassword(context, t.email, r.password ?? '');
                          },
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: const Text('Reset password'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final err = await session.setSuspended(t, !t.suspended);
                                  if (err != null && context.mounted) msg(context, err);
                                },
                                child: Text(t.suspended ? 'Reactivate' : 'Suspend'),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: danger),
                              onPressed: () async {
                                if (await confirmDialog(context, 'Revoke access?', 'Permanently revoke access for ${t.name}? This removes their account and cannot be undone.', confirm: 'Revoke', destructive: true)) {
                                  final err = await session.deleteAccount(t);
                                  if (err != null && context.mounted) msg(context, err);
                                }
                              },
                              child: const Text('Revoke'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (s.isNotEmpty && list.isEmpty) EmptyBox('No accounts match "$q".', icon: Icons.search_off_rounded),
            if (s.isEmpty && list.isEmpty) const EmptyBox('No resident accounts yet. Add the units first, then tap New account.', icon: Icons.person_add_alt_1_rounded),
            Text('Suspend keeps the account on file but blocks sign-in; Revoke permanently removes it and asks for confirmation first.',
                style: TextStyle(color: muted(context), fontSize: 12)),
          ],
        );
      },
    );
  }
}

Future<void> _showPassword(BuildContext context, String email, String password, {bool created = false}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(created ? 'Account created' : 'Temporary password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: TextStyle(color: muted(ctx), fontSize: 13)),
          const SizedBox(height: 10),
          SelectableText(password, style: hd(24)),
          const SizedBox(height: 10),
          Text(
            'Give this password to the resident privately. It is shown only now. When they sign in, the app asks them to choose their own password and, for a new account, to enter a code sent to their email and a code sent to their mobile number.',
            style: TextStyle(color: muted(ctx), fontSize: 13),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
    ),
  );
}
