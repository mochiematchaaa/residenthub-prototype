// ADMIN page: Announcements and events.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/texting.dart';
import '../../widgets/widgets.dart';

class AdminAnnouncements extends StatelessWidget {
  const AdminAnnouncements({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: BuildingBackdrop(
          child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: 72,
            leadingWidth: 72,
            leading: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Center(child: CircleBtn(Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.of(context).maybePop())),
            ),
            title: const Text('Announcements'),
            bottom: const TabBar(
              indicatorColor: lavDeep,
              labelColor: ink,
              tabs: [Tab(text: 'Announcements'), Tab(text: 'Events')],
            ),
          ),
          floatingActionButton: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              backgroundColor: lav,
              foregroundColor: ink,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create'),
              onPressed: () {
                final idx = DefaultTabController.of(ctx).index;
                idx == 0 ? _newAnnouncement(context) : _newEvent(context);
              },
            ),
          ),
          body: TabBarView(
            children: [
              _annList(context),
              _eventList(context),
            ],
          ),
        ),
        ),
      ),
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
      toggles: const [ToggleSpec('sms', "Also text residents (opens your messaging app)", true)],
      submit: 'Publish announcement',
      onSubmit: (v) {
        final t = (v['title'] as String).trim();
        if (t.isEmpty) return 'Add a title first.';
        final sms = v['sms'] == true;
        app.addAnnouncement(t, (v['body'] as String).trim(), v['type'] as String, sms);
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

  Widget _annList(BuildContext context) {
    final list = app.announcements;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
      children: [
        if (list.isEmpty) const EmptyBox('No announcements yet.', icon: Icons.campaign_outlined),
        for (final a in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
      ],
    );
  }

  Widget _eventList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
      children: [
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
      ],
    );
  }
}
