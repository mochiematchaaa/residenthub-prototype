// Model of a document (title + blocks of text/tables) shown in the Documents pages.

import 'dart:typed_data';

/// One piece of a document's body. Documents are stored as a list of blocks so
/// the same content can be shown in the app and exported to Word or Excel.
enum BlockKind { h1, h2, p, bullet, table }

/// One block (heading, paragraph, table) of a document.
class DocBlock {
  final BlockKind kind;
  final String text;
  final List<List<String>> rows; // only for tables (first row = header)

  const DocBlock.h1(String t)
      : kind = BlockKind.h1,
        text = t,
        rows = const [];
  const DocBlock.h2(String t)
      : kind = BlockKind.h2,
        text = t,
        rows = const [];
  const DocBlock.p(String t)
      : kind = BlockKind.p,
        text = t,
        rows = const [];
  const DocBlock.bullet(String t)
      : kind = BlockKind.bullet,
        text = t,
        rows = const [];
  const DocBlock.table(List<List<String>> r)
      : kind = BlockKind.table,
        text = '',
        rows = r;
}

const docCategories = ['Policy', 'Finance', 'Form', 'Notice', 'Minutes', 'Other'];

/// Finance documents are kept apart (Finance documents screen); these are the
/// categories of the general Community documents.
const communityCategories = ['Policy', 'Form', 'Notice', 'Minutes', 'Other'];

/// A document with a title and its blocks.
class DocItem {
  /// Set when the document is saved to the shared database (empty for the live reports).
  final String id;
  final String name, cat, date;

  /// 'all' | 'admin' | 'resident' - who can see this document.
  final String audience;

  /// Original file bytes when the document was imported (so it can be downloaded as-is).
  final Uint8List? raw;
  final String ext;

  final List<DocBlock> _blocks;
  final List<DocBlock> Function()? live;

  DocItem(
    this.name,
    this.cat,
    this.date, {
    List<DocBlock> blocks = const [],
    this.live,
    this.audience = 'all',
    this.raw,
    this.ext = '',
    this.id = '',
  }) : _blocks = blocks;

  DocItem withId(String newId) => DocItem(name, cat, date,
      blocks: _blocks, live: live, audience: audience, raw: raw, ext: ext, id: newId);

  /// Live documents are rebuilt from the app data every time they are opened.
  bool get isLive => live != null;
  List<DocBlock> get blocks => live != null ? live!() : _blocks;
}
