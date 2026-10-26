// The popup form used for adding/editing things. Describe fields with FieldSpec, ChoiceSpec, ToggleSpec, TimeSpec.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

/// Describes a text input in a FormSheet.
class FieldSpec {
  final String key, label;
  final String? hint;
  final int lines;
  final TextInputType? type;
  final bool obscure;
  final String? onlyWhenKey, onlyWhenValue;
  final String initial;
  const FieldSpec(this.key, this.label,
      {this.hint, this.lines = 1, this.type, this.obscure = false, this.onlyWhenKey, this.onlyWhenValue, this.initial = ''});
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

/// A time of day picked from the clock. The value is "HH:MM" (24 hour).
class TimeSpec {
  final String key, label, initial;
  const TimeSpec(this.key, this.label, this.initial);
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
  required String submit,
  required FutureOr<String?> Function(Map<String, dynamic> v) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(
      title: title, subtitle: subtitle, fields: fields, choices: choices,
      toggles: toggles, times: times, submit: submit, onSubmit: onSubmit,
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
  final FutureOr<String?> Function(Map<String, dynamic>) onSubmit;
  const _FormSheet({
    required this.title, this.subtitle, required this.fields, required this.choices,
    required this.toggles, this.times = const [], required this.submit, required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final Map<String, TextEditingController> ctrls = {};
  final Map<String, dynamic> vals = {};
  String? error;
  bool busy = false;

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
  }

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
              if (f.onlyWhenKey == null || vals[f.onlyWhenKey] == f.onlyWhenValue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: ctrls[f.key],
                    minLines: f.lines,
                    maxLines: f.lines,
                    obscureText: f.obscure,
                    keyboardType: f.type,
                    decoration: InputDecoration(labelText: f.label, hintText: f.hint),
                  ),
                ),
            if (widget.times.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.times.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _pickTime(widget.times[i]),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: widget.times[i].label,
                              suffixIcon: const Icon(Icons.schedule_rounded, size: 20),
                            ),
                            child: Text(timeLabel('${vals[widget.times[i].key]}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
            ],
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
