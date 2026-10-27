// ADMIN page: Announcements and events.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/texting.dart';
import '../../widgets/widgets.dart';
import '../shared/import_sheet.dart';

class AdminAnnouncements extends StatefulWidget {
  const AdminAnnouncements({super.key});

  @override
  State<AdminAnnouncements> createState() => _AdminAnnouncementsState();
}

class _AdminAnnouncementsState extends State<AdminAnnouncements> {
  int tab = 0; // 0 announcements, 1 events
  String filter = 'All'; // All | Published | Drafts

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final drafts = app.announcements.where((a) => a.status != 'Published').length;
        return SubPage(
          title: 'Announcements',
          subtitle: 'Publish announcements and plan community events.',
          children: [
            SubTabs(
              items: [SubTabItem('Announcements', count: app.announcements.length), SubTabItem('Events', count: app.events.length)],
              index: tab,
              onChanged: (i) => setState(() => tab = i),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => tab == 0 ? _newAnnouncement(context) : _newEvent(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(tab == 0 ? 'New announcement' : 'Add event'),
              ),
            ),
            if (tab == 0) ..._annList(context, drafts) else ..._eventList(context),
          ],
        );
      },
    );
  }

  void _newAnnouncement(BuildContext context) {
    showFormSheet(
      context,
      title: 'Create announcement',
      fields: const [
        FieldSpec('title', 'Title'),
        FieldSpec('body', 'Message', lines: 4),
      ],
      choices: const [ChoiceSpec('type', 'Type', ['General', 'Maintenance', 'Warning', 'Emergency'], 'General')],
      toggles: const [
        ToggleSpec('draft', 'Save as a draft (do not publish yet)', false),
        ToggleSpec('sms', "Also text residents (opens your messaging app)", true),
      ],
      submit: 'Save',
      onSubmit: (v) {
        final t = (v['title'] as String).trim();
        if (t.isEmpty) return 'Add a title first.';
        final draft = v['draft'] == true;
        final sms = v['sms'] == true && !draft;
        app.addAnnouncement(t, (v['body'] as String).trim(), v['type'] as String, v['sms'] == true, draft: draft);
        if (sms) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) textResidents(context, t, (v['body'] as String).trim());
          });
        }
        return null;
      },
    );
  }

  void _newEvent(BuildContext context) {
    showFormSheet(
      context,
      title: 'Add event',
      fields: const [
        FieldSpec('title', 'Event title'),
        FieldSpec('date', 'Date & time', hint: 'e.g. Oct 4, 2026 · 7:00 AM'),
        FieldSpec('place', 'Venue'),
      ],
      submit: 'Add event',
      onSubmit: (v) {
        final t = (v['title'] as String).trim();
        if (t.isEmpty) return 'Add an event title first.';
        app.addEvent(t, (v['date'] as String).trim(), (v['place'] as String).trim());
        return null;
      },
    );
  }

  List<Widget> _annList(BuildContext context, int drafts) {
    final all = app.announcements;
    final list = [for (final a in all) if (filter == 'All' || (filter == 'Drafts') == (a.status != 'Published')) a];
    final opts = ['All', 'Published', 'Drafts'];
    return [
        FilterRow(
          options: [for (final o in opts) o == 'All' ? 'All (${all.length})' : o == 'Published' ? 'Published (${all.length - drafts})' : 'Drafts ($drafts)'],
          selected: filter == 'All' ? 'All (${all.length})' : filter == 'Published' ? 'Published (${all.length - drafts})' : 'Drafts ($drafts)',
          onSelect: (v) => setState(() => filter = v.split(' ').first),
        ),
        if (list.isEmpty) EmptyBox(all.isEmpty ? 'No announcements yet.' : 'Nothing in this list.', icon: Icons.campaign_outlined),
        for (final a in list)
          Padding(
            padding: EdgeInsets.zero,
            child: RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                      const SizedBox(width: 8),
                      Wrap(spacing: 6, children: [
                        if (a.type != 'General') Pill(a.type, tone: a.type == 'Emergency' ? Tone.bad : Tone.warn),
                        Pill(a.status),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.body, style: TextStyle(color: muted(context), fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Text('${a.date}${a.sms ? ' · 📱 Text alert to residents' : ''}', style: TextStyle(color: muted(context), fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (a.status != 'Published')
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                          onPressed: () {
                            app.publishAnn(a.id);
                            if (a.sms) textResidents(context, a.title, a.body);
                          },
                          child: const Text('Publish'),
                        ),
                      TextButton(
                        onPressed: () => showFormSheet(
                          context,
                          title: 'Edit announcement',
                          fields: [
                            FieldSpec('title', 'Title', initial: a.title),
                            FieldSpec('body', 'Message', lines: 4, initial: a.body),
                          ],
                          submit: 'Save changes',
                          onSubmit: (v) {
                            app.editAnnouncement(a.id, v['title'] as String, v['body'] as String);
                            return null;
                          },
                        ),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (await confirmDialog(context, 'Delete announcement?', '"${a.title}" will be removed.', confirm: 'Delete', destructive: true)) {
                            app.deleteAnnouncement(a.id);
                          }
                        },
                        child: const Text('Delete', style: TextStyle(color: danger)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const ImportBar(['announcements']),
    ];
  }

  List<Widget> _eventList(BuildContext context) {
    return [
        if (app.events.isEmpty) const EmptyBox('No upcoming events.', icon: Icons.celebration_outlined),
        for (final e in app.events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const IconBadge(Icons.celebration_outlined, accent: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${e.date} · ${e.place}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => app.deleteEvent(e.id),
                    icon: const Icon(Icons.delete_outline_rounded, color: danger),
                  ),
                ],
              ),
            ),
          ),
        const ImportBar(['events']),
    ];
  }
}
