// ADMIN: add, rename or remove poll categories (General is the default and stays).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Opens the list of poll categories.
Future<void> showCategoryManager(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CategorySheet(),
    );

/// A small form for one new category. Returns the name that was added, or null.
Future<String?> showNewCategory(BuildContext context) async {
  final c = TextEditingController();
  String? err;
  String? added;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('New category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For example Pets, Elevators or Recreation.', style: TextStyle(color: muted(ctx), fontSize: 13)),
            const SizedBox(height: 10),
            TextField(controller: c, autofocus: true, maxLength: 40, decoration: InputDecoration(labelText: 'Category name', hintText: 'e.g. Pets', errorText: err)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final e = app.addPollCategory(c.text);
              if (e != null) {
                setS(() => err = e);
                return;
              }
              added = c.text.trim().replaceAll(RegExp(r'\s+'), ' ');
              Navigator.pop(ctx);
            },
            child: const Text('Add category', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
  c.dispose();
  return added;
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet();

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _new = TextEditingController();
  final _rename = TextEditingController();
  String? _editing, _asking, _err;

  @override
  void dispose() {
    _new.dispose();
    _rename.dispose();
    super.dispose();
  }

  Widget _row(BuildContext context, String c) {
    final n = app.polls.where((p) => p.category == c).length;
    final plural = '$n poll${n == 1 ? '' : 's'}';
    if (c == 'General') {
      return ListTile(contentPadding: EdgeInsets.zero, title: const Text('General', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(plural), trailing: const Pill('default'));
    }
    if (_editing == c) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: TextField(controller: _rename, autofocus: true, maxLength: 40, decoration: const InputDecoration(counterText: ''))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final e = app.renamePollCategory(c, _rename.text);
                setState(() {
                  _err = e;
                  if (e == null) _editing = null;
                });
              },
              child: const Text('Save'),
            ),
            TextButton(onPressed: () => setState(() => _editing = null), child: const Text('Cancel')),
          ],
        ),
      );
    }
    if (_asking == c) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n > 0 ? 'Move $plural to General and remove "$c"?' : 'Remove "$c"?', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: danger),
                onPressed: () {
                  final e = app.removePollCategory(c);
                  setState(() {
                    _err = e;
                    _asking = null;
                  });
                  if (e == null && context.mounted) msg(context, 'Removed $c${n > 0 ? '. Its polls moved to General.' : '.'}');
                },
                child: const Text('Remove'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => _asking = null), child: const Text('Keep')),
            ]),
          ],
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(plural),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => setState(() {
              _editing = c;
              _asking = null;
              _err = null;
              _rename.text = c;
            }),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, color: danger),
            onPressed: () => setState(() {
              _asking = c;
              _editing = null;
              _err = null;
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.of(context).viewInsets.bottom + 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Poll categories', style: hd(22)),
              const SizedBox(height: 4),
              Text('Add, rename or remove categories. Residents can filter the polls by category.', style: TextStyle(color: muted(context), fontSize: 13)),
              const SizedBox(height: 8),
              for (final c in app.pollCategoryChoices) _row(context, c),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(child: TextField(controller: _new, maxLength: 40, decoration: const InputDecoration(labelText: 'New category name', counterText: ''))),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final e = app.addPollCategory(_new.text);
                      setState(() => _err = e);
                      if (e == null) {
                        msg(context, 'Category added: ${_new.text.trim()}');
                        _new.clear();
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: danger, fontWeight: FontWeight.w600))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
            ],
          ),
        ),
      ),
    );
  }
}
