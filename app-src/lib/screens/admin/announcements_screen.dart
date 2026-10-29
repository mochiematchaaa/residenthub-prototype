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
  int _annPage = 0, _evPage = 0;

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
                onPressed: () => tab == 0 ? _compose(context) : _newEvent(context),
                icon: Icon(tab == 0 ? Icons.edit_outlined : Icons.add_rounded),
                label: Text(tab == 0 ? 'Compose' : 'Add event'),
              ),
            ),
            if (tab == 0) ..._annList(context, drafts) else ..._eventList(context),
          ],
        );
      },
    );
  }

  /// Opens the compose page. Going back (or closing it) keeps what was typed as a draft, like Gmail.
  Future<void> _compose(BuildContext context, {Announcement? edit}) async {
    final sent = await Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AnnouncementCompose(existing: edit)));
    if (sent != null && context.mounted && sent['sms'] == '1') {
      textResidents(context, sent['title'] ?? '', sent['body'] ?? '');
    }
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

  String _day(String d) {
    final x = parseShortDate(d);
    if (x == null) return d;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[x.month - 1]} ${x.day}';
  }

  Widget _row(BuildContext context, Announcement a) {
    final draft = a.status != 'Published';
    final tone = a.type == 'Emergency' ? Tone.bad : a.type == 'Warning' ? Tone.warn : a.type == 'Maintenance' ? Tone.info : null;
    final color = tone == null ? muted(context) : toneOf(context, tone).fg;
    final snippet = a.body == '—' ? '' : a.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Dismissible(
      key: ValueKey('ann${a.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDialog(context, 'Delete announcement?', '"${a.title}" will be removed.', confirm: 'Delete', destructive: true),
      onDismissed: (_) => app.deleteAnnouncement(a.id),
      child: InkWell(
        onTap: () => draft ? _compose(context, edit: a) : go(context, AnnouncementReader(a.id, onEdit: () => _compose(context, edit: a))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: 0.16),
                child: Text(a.type.isEmpty ? 'G' : a.type[0], style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (draft) const Text('Draft  ', style: TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w700, fontSize: 13)),
                      Expanded(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: draft ? FontWeight.w800 : FontWeight.w700, fontSize: 14.5))),
                      const SizedBox(width: 8),
                      Text(_day(a.date), style: TextStyle(color: muted(context), fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 2),
                    Text(snippet.isEmpty ? a.type : snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        onSelect: (v) => setState(() {
          filter = v.split(' ').first;
          _annPage = 0;
        }),
      ),
      if (list.isEmpty) EmptyBox(all.isEmpty ? 'No announcements yet. Tap Compose to write the first one.' : 'Nothing in this list.', icon: Icons.campaign_outlined)
      else
        RCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(children: [
              for (var i = 0; i < pageOf(list, _annPage, 10).length; i++) ...[
                if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                _row(context, pageOf(list, _annPage, 10)[i]),
              ],
            ]),
          ),
        ),
      PagerBar(page: _annPage, per: 10, total: list.length, onPage: (p) => setState(() => _annPage = p)),
      Text('Swipe a message left to delete it. Tap a draft to keep writing.', style: TextStyle(color: muted(context), fontSize: 12)),
      const ImportBar(['announcements']),
    ];
  }

  List<Widget> _eventList(BuildContext context) {
    return [
        if (app.events.isEmpty) const EmptyBox('No upcoming events.', icon: Icons.celebration_outlined),
        for (final e in pageOf(app.events, _evPage, 6))
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
        PagerBar(page: _evPage, per: 6, total: app.events.length, onPage: (p) => setState(() => _evPage = p)),
        const ImportBar(['events']),
    ];
  }
}


/// Reading one published announcement (like opening an email).
class AnnouncementReader extends StatelessWidget {
  final int id;
  final VoidCallback onEdit;
  const AnnouncementReader(this.id, {super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final a = app.announcements.where((x) => x.id == id).firstOrNull;
        if (a == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox.shrink();
        }
        return SubPage(
          title: 'Announcement',
          actions: [
            IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, color: danger),
              onPressed: () async {
                if (await confirmDialog(context, 'Delete announcement?', '"${a.title}" will be removed.', confirm: 'Delete', destructive: true)) {
                  app.deleteAnnouncement(a.id);
                }
              },
            ),
          ],
          children: [
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: hd(22)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Pill(a.type, tone: a.type == 'Emergency' ? Tone.bad : a.type == 'Warning' ? Tone.warn : Tone.info),
                    Pill(a.status),
                    Text('${a.date} · shown to all residents', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ]),
                  const Divider(height: 28),
                  Text(a.body == '—' ? 'No message.' : a.body, style: const TextStyle(fontSize: 15, height: 1.55)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The compose page. Going back keeps a new or draft announcement as a draft (like Gmail); a published one is only changed with Save changes.
class AnnouncementCompose extends StatefulWidget {
  final Announcement? existing;
  const AnnouncementCompose({super.key, this.existing});

  @override
  State<AnnouncementCompose> createState() => _AnnouncementComposeState();
}

class _AnnouncementComposeState extends State<AnnouncementCompose> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title == '(no title)' ? '' : widget.existing?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: widget.existing == null || widget.existing!.body == '—' ? '' : widget.existing!.body);
  late String _type = widget.existing?.type ?? 'General';
  late final int _id = widget.existing?.id ?? 0;
  late final bool _pub = widget.existing != null && widget.existing!.status == 'Published';
  bool _sms = false;
  bool _done = false; // published or discarded: nothing to keep as a draft any more

  @override
  void dispose() {
    final t = _title.text, b = _body.text, ty = _type, id = _id;
    final keep = !_done && !_pub;
    _title.dispose();
    _body.dispose();
    // Whichever way the page closes (arrow, system back, swipe), a draft is kept. Done after the frame so listeners are not rebuilt mid-teardown.
    if (keep) WidgetsBinding.instance.addPostFrameCallback((_) => app.saveAnnouncementDraft(id, t, b, ty));
    super.dispose();
  }

  bool get _hasText => _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;

  void _close() {
    final m = ScaffoldMessenger.of(context);
    final keep = _hasText && !_pub && !_done;
    Navigator.of(context).pop();
    if (keep) m.showSnackBar(const SnackBar(content: Text('Draft saved. Find it under Drafts.')));
  }

  void _publish() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      msg(context, 'Add a title first.');
      return;
    }
    final body = _body.text.trim();
    var id = _id;
    if (id == 0) id = app.saveAnnouncementDraft(0, t, body, _type);
    final wasLive = _pub;
    _done = true;
    app.publishAnnouncementFrom(id, t, body, _type, sms: _sms && !wasLive);
    final m = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(<String, String>{'title': t, 'body': body, 'sms': _sms && !wasLive ? '1' : '0'});
    m.showSnackBar(SnackBar(content: Text(wasLive ? 'Changes saved.' : 'Published. Residents can see it now.')));
  }

  Future<void> _discard() async {
    if (_pub) {
      _close();
      return;
    }
    _done = true;
    if (_id != 0) app.deleteAnnouncement(_id);
    final m = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    m.showSnackBar(const SnackBar(content: Text('Draft discarded.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: _pub ? 'Close' : 'Save draft and close', icon: const Icon(Icons.arrow_back_rounded), onPressed: _close),
        title: Text(_pub ? 'Edit announcement' : _id != 0 ? 'Draft' : 'New announcement', style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(tooltip: _pub ? 'Close' : 'Discard', onPressed: _discard, icon: Icon(_pub ? Icons.close_rounded : Icons.delete_outline_rounded)),
          IconButton(tooltip: _pub ? 'Save changes' : 'Publish', onPressed: _publish, icon: const Icon(Icons.send_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in const ['General', 'Maintenance', 'Warning', 'Emergency'])
              ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Write your message to the residents', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
          ),
          if (!_pub) ...[
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also text residents'),
              subtitle: const Text('Opens your messaging app when you publish.'),
              value: _sms,
              onChanged: (v) => setState(() => _sms = v),
            ),
            Text('Going back keeps your text as a draft.', style: TextStyle(color: muted(context), fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}
