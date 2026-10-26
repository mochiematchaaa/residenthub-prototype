// The Notify residents popup: pick everyone or chosen residents (with their mobile numbers), send a notice in the app, and optionally a text message.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/texting.dart';
import '../../widgets/widgets.dart';

/// Opens the Notify residents popup. With a maintenance [task] the title and message are filled in for you.
void showNotifySheet(BuildContext context, [MTask? task]) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NotifySheet(parent: context, task: task),
  );
}

class _NotifySheet extends StatefulWidget {
  final BuildContext parent;
  final MTask? task;
  const _NotifySheet({required this.parent, this.task});

  @override
  State<_NotifySheet> createState() => _NotifySheetState();
}

class _NotifySheetState extends State<_NotifySheet> {
  late final TextEditingController title, body, search;
  bool everyone = true;
  bool text = true;
  final Set<String> picked = {};
  String? error;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    final equip = t == null ? '' : maint.equipOf(t);
    title = TextEditingController(text: t == null ? '' : 'Maintenance notice: ${t.title}');
    body = TextEditingController(
        text: t == null
            ? ''
            : 'Scheduled on ${shortDate(t.due)}: ${t.title}${equip.isEmpty ? '' : ' ($equip)'}. Some areas may be briefly unavailable. Thank you for your understanding.');
    search = TextEditingController();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    search.dispose();
    super.dispose();
  }

  List<Account> get _all => app.residentAccounts;

  List<Account> get _shown {
    final s = search.text.trim().toLowerCase();
    return _all.where((a) => s.isEmpty || '${a.name} ${a.unit} ${a.phone}'.toLowerCase().contains(s)).toList();
  }

  List<Account> get _recipients => everyone ? _all : _all.where((a) => picked.contains(a.id)).toList();

  void _send() {
    final t = title.text.trim();
    final rec = _recipients;
    if (t.isEmpty) return setState(() => error = 'Enter a title.');
    if (rec.isEmpty) return setState(() => error = 'Choose at least one resident.');
    final phones = [for (final a in rec) if (a.hasMobile) AppState.normalizePhone(a.phone)];
    if (text && phones.isEmpty) return setState(() => error = 'None of these residents has a mobile number on file. Turn off the text message or choose other residents.');
    final units = everyone ? <String>[] : rec.map((a) => a.unit).toSet().toList();
    final msgBody = body.text.trim();
    maint.sendNotice(app, t, msgBody,
        units: units, count: rec.length, text: text, textCount: phones.length, noPhone: rec.length - phones.length);
    final parent = widget.parent;
    Navigator.pop(context);
    if (text) {
      textNumbers(parent, phones, t, msgBody);
    } else if (parent.mounted) {
      msg(parent, 'Notice sent to ${everyone ? 'all residents' : '${rec.length} resident${rec.length == 1 ? '' : 's'}'}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = _recipients;
    final withPhone = rec.where((a) => a.hasMobile).length;
    final shown = _shown;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notify residents', style: hd(22)),
            const SizedBox(height: 4),
            Text('Choose who gets this notice and how. It appears under Announcements in their app.', style: TextStyle(color: muted(context), fontSize: 13)),
            const SizedBox(height: 14),
            Text('Send to', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('All residents'), selected: everyone, onSelected: (_) => setState(() => everyone = true)),
              ChoiceChip(label: const Text('Choose residents…'), selected: !everyone, onSelected: (_) => setState(() => everyone = false)),
            ]),
            if (!everyone) ...[
              const SizedBox(height: 10),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search name, unit or number…', prefixIcon: Icon(Icons.search_rounded)),
              ),
              Row(children: [
                TextButton(onPressed: () => setState(() => picked.addAll(shown.map((a) => a.id))), child: const Text('Select shown')),
                TextButton(onPressed: () => setState(picked.clear), child: const Text('Clear')),
                const Spacer(),
                Text('${picked.length} chosen', style: TextStyle(color: muted(context), fontSize: 12.5)),
              ]),
              Container(
                height: 230,
                decoration: BoxDecoration(border: Border.all(color: muted(context).withAlpha(70)), borderRadius: BorderRadius.circular(14)),
                child: shown.isEmpty
                    ? Center(child: Text('No residents match.', style: TextStyle(color: muted(context))))
                    : ListView(
                        children: [
                          for (final a in shown)
                            CheckboxListTile(
                              dense: true,
                              value: picked.contains(a.id),
                              onChanged: (v) => setState(() => v == true ? picked.add(a.id) : picked.remove(a.id)),
                              title: Text('${a.name} · ${a.unit}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(a.hasMobile ? a.phone : 'No mobile number', style: TextStyle(color: a.hasMobile ? muted(context) : danger, fontSize: 12.5)),
                            ),
                        ],
                      ),
              ),
            ],
            const SizedBox(height: 14),
            Text('How', style: TextStyle(color: muted(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Dashboard and app only'), selected: !text, onSelected: (_) => setState(() => text = false)),
              ChoiceChip(label: const Text('Dashboard, app and text message'), selected: text, onSelected: (_) => setState(() => text = true)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Will reach ${rec.length} resident${rec.length == 1 ? '' : 's'}'
              '${text ? ' on the dashboard and in the app, and by text message at the same time. $withPhone ${withPhone == 1 ? 'has' : 'have'} a mobile number to text${rec.length - withPhone > 0 ? ' (${rec.length - withPhone} without)' : ''}' : ''}.'
              '${text ? ' The text opens in your phone\'s messaging app with their numbers filled in; you tap Send.' : ''}',
              style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: body, minLines: 4, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
            if (error != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: danger, fontSize: 13))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _send, child: const Text('Send notice'))),
          ],
        ),
      ),
    );
  }
}
