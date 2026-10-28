// The popup form used for adding/editing things. Describe fields with FieldSpec, ChoiceSpec, ToggleSpec, TimeSpec.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../services/doc_files.dart';
import '../services/photo_shrink.dart';
import 'common.dart';

/// Describes a text input in a FormSheet.
class FieldSpec {
  final String key, label;
  final String? hint;
  final int lines;
  final TextInputType? type;
  final bool obscure;
  final String? onlyWhenKey, onlyWhenValue;
  /// Show this field right under the choice named [onlyWhenKey] instead of at the top of the form.
  final bool belowChoice;
  final String initial;
  const FieldSpec(this.key, this.label,
      {this.hint, this.lines = 1, this.type, this.obscure = false, this.onlyWhenKey, this.onlyWhenValue, this.belowChoice = false, this.initial = ''});
}

/// Describes a choice (dropdown/chips) in a FormSheet.
class ChoiceSpec {
  final String key, label;
  final List<String> options;
  final String initial;
  const ChoiceSpec(this.key, this.label, this.options, this.initial);
}

/// Describes an on/off switch in a FormSheet.
class ToggleSpec {
  final String key, label;
  final bool initial;
  const ToggleSpec(this.key, this.label, this.initial);
}

/// A picture the person can add (for example a photo of an online payment). The value is the picture's bytes, or null.
class PhotoSpec {
  final String key, label, hint;
  const PhotoSpec(this.key, this.label, {this.hint = ''});
}

/// A time of day picked from the clock. The value is "HH:MM" (24 hour).
class TimeSpec {
  final String key, label, initial;

  /// Show these times only while the choice named [onlyWhenKey] has the value [onlyWhenValue]
  /// (right under that choice when [belowChoice] is true).
  final String? onlyWhenKey, onlyWhenValue;
  final bool belowChoice;
  const TimeSpec(this.key, this.label, this.initial, {this.onlyWhenKey, this.onlyWhenValue, this.belowChoice = false});
}

/// A date picked from the calendar. The value is "yyyy-mm-dd", or "" when [clearable] and nothing is chosen.
class DateSpec {
  final String key, label, initial, emptyText;
  final bool clearable;
  const DateSpec(this.key, this.label, this.initial, {this.clearable = false, this.emptyText = 'Not set'});
}

/// Generic bottom-sheet form. [onSubmit] returns an error string to keep the
/// sheet open, or null to close it.
Future<void> showFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<FieldSpec> fields = const [],
  List<ChoiceSpec> choices = const [],
  List<ToggleSpec> toggles = const [],
  List<TimeSpec> times = const [],
  List<DateSpec> dates = const [],
  PhotoSpec? photo,
  required String submit,
  required FutureOr<String?> Function(Map<String, dynamic> v) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(
      title: title, subtitle: subtitle, fields: fields, choices: choices,
      toggles: toggles, times: times, dates: dates, photo: photo, submit: submit, onSubmit: onSubmit,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  final String title, submit;
  final String? subtitle;
  final List<FieldSpec> fields;
  final List<ChoiceSpec> choices;
  final List<ToggleSpec> toggles;
  final List<TimeSpec> times;
  final List<DateSpec> dates;
  final PhotoSpec? photo;
  final FutureOr<String?> Function(Map<String, dynamic>) onSubmit;
  const _FormSheet({
    required this.title, this.subtitle, required this.fields, required this.choices,
    required this.toggles, this.times = const [], this.dates = const [], this.photo, required this.submit, required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final Map<String, TextEditingController> ctrls = {};
  final Map<String, dynamic> vals = {};
  String? error;
  bool busy = false;
  Uint8List? _photo;

  Future<void> _pickPhoto() async {
    try {
      final b = await pickPhoto();
      if (b == null) return;
      final small = await shrinkPhoto(b);
      if (mounted) setState(() => _photo = small);
    } on FormatException catch (e) {
      if (mounted) msg(context, e.message);
    } catch (_) {
      if (mounted) msg(context, 'Could not open that picture.');
    }
  }

  Widget _photoBox(PhotoSpec p) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.label, style: TextStyle(fontWeight: FontWeight.w700, color: muted(context), fontSize: 13)),
            if (p.hint.isNotEmpty) Text(p.hint, style: TextStyle(color: muted(context), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_photo != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_photo!, width: 72, height: 72, fit: BoxFit.cover)),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_photo == null ? 'Add a photo' : 'Change'),
                ),
                if (_photo != null) TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Remove')),
              ],
            ),
          ],
        ),
      );

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      ctrls[f.key] = TextEditingController(text: f.initial);
    }
    for (final c in widget.choices) {
      vals[c.key] = c.initial;
    }
    for (final t in widget.toggles) {
      vals[t.key] = t.initial;
    }
    for (final t in widget.times) {
      vals[t.key] = t.initial;
    }
    for (final d in widget.dates) {
      vals[d.key] = d.initial;
    }
  }

  Future<void> _pickDate(DateSpec d) async {
    final today = DateTime.now();
    final cur = DateTime.tryParse('${vals[d.key]}') ?? DateTime(today.year, today.month, today.day);
    final r = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(today.year - 1), lastDate: DateTime(today.year + 5));
    if (r != null && mounted) setState(() => vals[d.key] = dayKey(r));
  }

  Widget _datesRow() => Column(
        children: [
          for (final d in widget.dates)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickDate(d),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: d.label,
                    suffixIcon: d.clearable && '${vals[d.key]}'.isNotEmpty
                        ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => vals[d.key] = ''))
                        : const Icon(Icons.calendar_month_outlined, size: 20),
                  ),
                  child: Text('${vals[d.key]}'.isEmpty ? d.emptyText : isoShort('${vals[d.key]}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      );

  bool _showTime(TimeSpec t) => t.onlyWhenKey == null || vals[t.onlyWhenKey] == t.onlyWhenValue;

  Widget _timesRow(List<TimeSpec> list) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _pickTime(list[i]),
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: list[i].label, suffixIcon: const Icon(Icons.schedule_rounded, size: 20)),
                    child: Text(timeLabel('${vals[list[i].key]}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _fieldBox(FieldSpec f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrls[f.key],
          minLines: f.lines,
          maxLines: f.lines,
          obscureText: f.obscure,
          keyboardType: f.type,
          decoration: InputDecoration(labelText: f.label, hintText: f.hint),
        ),
      );

  Future<void> _pickTime(TimeSpec t) async {
    final cur = toMinutes('${vals[t.key]}') ?? 480;
    final r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (r != null && mounted) setState(() => vals[t.key] = hhmm(r.hour * 60 + r.minute));
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (busy) return;
    final out = <String, dynamic>{...vals};
    ctrls.forEach((k, c) => out[k] = c.text);
    if (widget.photo != null) out[widget.photo!.key] = _photo;
    setState(() => busy = true);
    final err = await widget.onSubmit(out);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        busy = false;
        error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(color: muted(context).withAlpha(90), borderRadius: BorderRadius.circular(9)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: hd(22)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: TextStyle(color: muted(context), height: 1.4)),
            ],
            const SizedBox(height: 16),
            for (final f in widget.fields)
              if (!f.belowChoice && (f.onlyWhenKey == null || vals[f.onlyWhenKey] == f.onlyWhenValue)) _fieldBox(f),
            if (widget.dates.isNotEmpty) _datesRow(),
            if (widget.times.any((t) => !t.belowChoice && _showTime(t))) _timesRow([for (final t in widget.times) if (!t.belowChoice && _showTime(t)) t]),
            for (final c in widget.choices) ...[
              Text(c.label, style: TextStyle(fontWeight: FontWeight.w700, color: muted(context), fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final o in c.options)
                    ChoiceChip(
                      label: Text(o),
                      selected: vals[c.key] == o,
                      showCheckmark: false,
                      selectedColor: lav,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: vals[c.key] == o ? ink : Theme.of(context).colorScheme.onSurface),
                      onSelected: (_) => setState(() => vals[c.key] = o),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (final f in widget.fields)
                if (f.belowChoice && f.onlyWhenKey == c.key && vals[f.onlyWhenKey] == f.onlyWhenValue) _fieldBox(f),
              if (widget.times.any((t) => t.belowChoice && t.onlyWhenKey == c.key && _showTime(t)))
                _timesRow([for (final t in widget.times) if (t.belowChoice && t.onlyWhenKey == c.key && _showTime(t)) t]),
            ],
            if (widget.photo != null) _photoBox(widget.photo!),
            for (final t in widget.toggles)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                value: vals[t.key] == true,
                activeThumbColor: lavDeep,
                onChanged: (v) => setState(() => vals[t.key] = v),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(error!, style: const TextStyle(color: danger, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: busy ? null : _submit, child: Text(busy ? 'Please wait…' : widget.submit)),
            ),
          ],
        ),
      ),
    );
  }
}
