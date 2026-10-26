// ADMIN page: Manage access (create, reset, suspend and delete resident accounts).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../shared/notify_sheet.dart';

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
            _ContactSummary(),
            const _UpdateHistory(),
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
                                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (t.isNew()) const Pill('New', tone: Tone.good),
                                  if (t.isUpdated()) Pill('Updated: ${t.lastChange.isEmpty ? 'info' : t.lastChange}', tone: Tone.info),
                                ]),
                                Text(t.email, style: TextStyle(color: muted(context), fontSize: 12.5)),
                                Text('${t.phone.isEmpty ? 'No mobile number' : t.phone}${t.unit.isNotEmpty ? ' · ${t.unit}' : ''}${t.added.isEmpty ? '' : ' · Added ${t.added}'}', style: TextStyle(color: t.hasMobile ? muted(context) : danger, fontSize: 12)),
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

/// A short summary of resident contact info that is new or changed, with a button to notify residents.
class _ContactSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final res = app.residentAccounts;
    final fresh = res.where((a) => a.isNew()).length;
    final upd = res.where((a) => a.isUpdated()).length;
    final noPhone = res.where((a) => !a.hasMobile).length;
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resident contact info, last 7 days', style: hd(15)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pill('$fresh new', tone: fresh > 0 ? Tone.good : Tone.info),
            Pill('$upd updated', tone: Tone.info),
            if (noPhone > 0) Pill('$noPhone without a mobile number', tone: Tone.warn),
          ]),
          const SizedBox(height: 8),
          Text('Notify residents uses this list: the name, unit and mobile number come from each account.', style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => showNotifySheet(context), icon: const Icon(Icons.campaign_outlined), label: const Text('Notify residents')),
        ],
      ),
    );
  }
}

/// A dropdown that lists every change to resident contact info, newest first, with a filter for one resident.
class _UpdateHistory extends StatefulWidget {
  const _UpdateHistory();

  @override
  State<_UpdateHistory> createState() => _UpdateHistoryState();
}

class _UpdateHistoryState extends State<_UpdateHistory> {
  String who = '';

  @override
  Widget build(BuildContext context) {
    final res = app.residentAccounts;
    final all = <(Account, AccountChange)>[
      for (final a in res) for (final c in a.history) (a, c),
    ]..sort((x, y) => y.$2.at.compareTo(x.$2.at));
    final shown = who.isEmpty ? all : all.where((e) => e.$1.id == who).toList();
    final names = [for (final a in res) if (a.history.isNotEmpty) a]..sort((x, y) => x.name.compareTo(y.name));
    return RCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(children: [
            Text('Update history', style: hd(15)),
            const SizedBox(width: 8),
            Pill('${shown.length} change${shown.length == 1 ? '' : 's'}', tone: Tone.info),
          ]),
          children: [
            DropdownButtonFormField<String>(
              value: who,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Show history for'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All residents')),
                for (final a in names) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${a.unit}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => who = v ?? ''),
            ),
            const SizedBox(height: 10),
            if (shown.isEmpty) Text('No changes yet.', style: TextStyle(color: muted(context))),
            for (final e in shown.take(40))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(e.$2.from.isEmpty && e.$2.to.isEmpty ? Icons.person_add_alt_1_rounded : Icons.edit_note_rounded,
                        tone: e.$2.from.isEmpty && e.$2.to.isEmpty ? Tone.good : Tone.info, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.$1.name} · ${e.$1.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(e.$2.from.isEmpty && e.$2.to.isEmpty ? e.$2.field : '${e.$2.field}: ${e.$2.from.isEmpty ? '—' : e.$2.from} → ${e.$2.to}',
                              style: const TextStyle(fontSize: 13)),
                          Text(shortDate(e.$2.at), style: TextStyle(color: muted(context), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
