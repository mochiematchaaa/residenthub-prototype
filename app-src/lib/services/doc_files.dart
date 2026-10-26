// Reads and writes Word (.docx) files for the Documents pages.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/core.dart';

// =============================================================== small helpers

String _x(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _unx(String s) => s
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  final out = ZipEncoder().encode(a);
  return Uint8List.fromList(out ?? const <int>[]);
}

String _fileText(ArchiveFile f) => utf8.decode(f.content as List<int>, allowMalformed: true);

/// Joined text of every <tag>…</tag> inside [xml].
String _textOf(String xml, String tag) {
  final re = RegExp('<$tag(?:\\s[^>]*)?>(.*?)</$tag>', dotAll: true);
  return re.allMatches(xml).map((m) => _unx(m.group(1) ?? '')).join();
}

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

// =============================================================== Word (.docx) export

String _run(String t, {bool bold = false, int? size, String? color}) =>
    '<w:r><w:rPr>${bold ? '<w:b/>' : ''}${color != null ? '<w:color w:val="$color"/>' : ''}${size != null ? '<w:sz w:val="$size"/>' : ''}</w:rPr><w:t xml:space="preserve">${_x(t)}</w:t></w:r>';

String _para(String t, {bool bold = false, int? size, String? color, int after = 120, int left = 0, int hanging = 0}) =>
    '<w:p><w:pPr><w:spacing w:after="$after"/>${left > 0 ? '<w:ind w:left="$left" w:hanging="$hanging"/>' : ''}</w:pPr>${t.isEmpty ? '' : _run(t, bold: bold, size: size, color: color)}</w:p>';

String _wordTable(List<List<String>> rows) {
  if (rows.isEmpty) return '';
  final cols = rows.map((r) => r.length).reduce(math.max);
  if (cols == 0) return '';
  final b = StringBuffer('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders>');
  for (final side in const ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
    b.write('<w:$side w:val="single" w:sz="4" w:space="0" w:color="BFC5D6"/>');
  }
  b.write('</w:tblBorders><w:tblCellMar><w:left w:w="100" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>');
  for (var i = 0; i < cols; i++) {
    b.write('<w:gridCol w:w="${(9600 / cols).round()}"/>');
  }
  b.write('</w:tblGrid>');
  for (var r = 0; r < rows.length; r++) {
    b.write('<w:tr>');
    for (var c = 0; c < cols; c++) {
      final v = c < rows[r].length ? rows[r][c] : '';
      b.write('<w:tc><w:tcPr><w:tcW w:w="${(9600 / cols).round()}" w:type="dxa"/>');
      if (r == 0) b.write('<w:shd w:val="clear" w:color="auto" w:fill="E7E3FA"/>');
      b.write('</w:tcPr>${_para(v, bold: r == 0, after: 0)}</w:tc>');
    }
    b.write('</w:tr>');
  }
  b.write('</w:tbl>');
  b.write(_para('', after: 120));
  return b.toString();
}

Uint8List buildDocx(String title, List<DocBlock> blocks) {
  final body = StringBuffer();
  body.write(_para(title, bold: true, size: 40, after: 200));
  for (final k in blocks) {
    switch (k.kind) {
      case BlockKind.h1:
        body.write(_para(k.text, bold: true, size: 30, after: 160));
      case BlockKind.h2:
        body.write(_para(k.text, bold: true, size: 26, after: 120));
      case BlockKind.p:
        body.write(_para(k.text, size: 22));
      case BlockKind.bullet:
        body.write(_para('•\t${k.text}', size: 22, left: 540, hanging: 270, after: 60));
      case BlockKind.table:
        body.write(_wordTable(k.rows));
    }
  }
  return _zip({
    '[Content_Types].xml':
        '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
    '_rels/.rels':
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
    'word/document.xml':
        '$_xmlHead<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body.toString()}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>',
  });
}

// =============================================================== Excel (.xlsx) export

String _col(int index) {
  var i = index + 1;
  var s = '';
  while (i > 0) {
    final m = (i - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    i = (i - m - 1) ~/ 26;
  }
  return s;
}

String? _asNumber(String v) {
  final t = v.replaceAll('₱', '').replaceAll(',', '').trim();
  if (!RegExp(r'^-?(0|[1-9]\d*)(\.\d+)?$').hasMatch(t)) return null;
  return t;
}

Uint8List buildXlsx(String title, List<DocBlock> blocks) {
  // Flatten the blocks into spreadsheet rows. (cells, bold)
  final rows = <(List<String>, bool)>[];
  rows.add(([title], true));
  rows.add((const <String>[], false));
  for (final k in blocks) {
    switch (k.kind) {
      case BlockKind.h1:
      case BlockKind.h2:
        rows.add(([k.text], true));
      case BlockKind.p:
        rows.add(([k.text], false));
      case BlockKind.bullet:
        rows.add((['• ${k.text}'], false));
      case BlockKind.table:
        for (var i = 0; i < k.rows.length; i++) {
          rows.add((k.rows[i], i == 0));
        }
        rows.add((const <String>[], false));
    }
  }
  final maxCols = rows.fold<int>(1, (m, r) => math.max(m, r.$1.length));
  final sheet = StringBuffer(
      '$_xmlHead<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols><col min="1" max="$maxCols" width="26" customWidth="1"/></cols><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    final cells = rows[r].$1;
    if (cells.isEmpty) continue;
    final bold = rows[r].$2;
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < cells.length; c++) {
      final v = cells[c];
      if (v.isEmpty) continue;
      final ref = '${_col(c)}${r + 1}';
      final s = bold ? ' s="1"' : '';
      final n = bold ? null : _asNumber(v);
      if (n != null) {
        sheet.write('<c r="$ref"$s><v>$n</v></c>');
      } else {
        sheet.write('<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">${_x(v)}</t></is></c>');
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  var sheetName = title.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
  if (sheetName.length > 31) sheetName = sheetName.substring(0, 31);
  if (sheetName.isEmpty) sheetName = 'Sheet1';

  return _zip({
    '[Content_Types].xml':
        '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    '_rels/.rels':
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '$_xmlHead<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${_x(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
    'xl/styles.xml':
        '$_xmlHead<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs></styleSheet>',
    'xl/worksheets/sheet1.xml': sheet.toString(),
  });
}

/// The list of all documents as a table (for "Export list").
List<DocBlock> docIndexBlocks(List<DocItem> docs) => [
      DocBlock.table([
        const ['Title', 'Category', 'Date'],
        for (final d in docs) [d.name, d.cat, d.date],
      ]),
    ];

// =============================================================== import / parse

List<DocBlock> parseDocx(Uint8List bytes) {
  final arc = ZipDecoder().decodeBytes(bytes);
  final f = arc.findFile('word/document.xml');
  if (f == null) throw const FormatException('That does not look like a Word (.docx) file.');
  final xml = _fileText(f);
  final out = <DocBlock>[];
  final re = RegExp(r'<w:tbl[\s>].*?</w:tbl>|<w:p[\s>].*?</w:p>', dotAll: true);
  final paraRe = RegExp(r'<w:p[\s>].*?</w:p>', dotAll: true);
  for (final m in re.allMatches(xml)) {
    final s = m.group(0)!;
    if (out.length > 600) break;
    if (s.startsWith('<w:tbl')) {
      final rows = <List<String>>[];
      for (final rm in RegExp(r'<w:tr[\s>].*?</w:tr>', dotAll: true).allMatches(s)) {
        final cells = <String>[];
        for (final cm in RegExp(r'<w:tc[\s>].*?</w:tc>', dotAll: true).allMatches(rm.group(0)!)) {
          final text = paraRe
              .allMatches(cm.group(0)!)
              .map((p) => _textOf(p.group(0)!, 'w:t').trim())
              .where((t) => t.isNotEmpty)
              .join(' ');
          cells.add(text);
        }
        if (cells.isNotEmpty) rows.add(cells);
      }
      if (rows.isNotEmpty) out.add(DocBlock.table(rows.length > 300 ? rows.sublist(0, 300) : rows));
      continue;
    }
    final text = _textOf(s, 'w:t').trim();
    if (text.isEmpty) continue;
    final style = (RegExp(r'<w:pStyle w:val="([^"]+)"').firstMatch(s)?.group(1) ?? '').toLowerCase();
    final size = int.tryParse(RegExp(r'<w:sz w:val="(\d+)"').firstMatch(s)?.group(1) ?? '') ?? 0;
    final bold = s.contains('<w:b/>') || s.contains('<w:b ');
    if (style == 'title' || style == 'heading1' || size >= 28) {
      out.add(DocBlock.h1(text));
    } else if (style.startsWith('heading') || (bold && size >= 24)) {
      out.add(DocBlock.h2(text));
    } else if (style.contains('list') || s.contains('<w:numPr>') || text.startsWith('•')) {
      out.add(DocBlock.bullet(text.replaceFirst(RegExp(r'^•\s*'), '')));
    } else {
      out.add(DocBlock.p(text));
    }
  }
  return out;
}

List<List<String>> parseXlsxRows(Uint8List bytes) {
  final arc = ZipDecoder().decodeBytes(bytes);
  final shared = <String>[];
  final ss = arc.findFile('xl/sharedStrings.xml');
  if (ss != null) {
    for (final m in RegExp(r'<si[\s>].*?</si>|<si/>', dotAll: true).allMatches(_fileText(ss))) {
      shared.add(_textOf(m.group(0)!, 't'));
    }
  }
  final sheets = arc.files
      .where((f) => f.isFile && RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (sheets.isEmpty) throw const FormatException('That does not look like an Excel (.xlsx) file.');
  final xml = _fileText(sheets.first);
  final rows = <List<String>>[];
  for (final rm in RegExp(r'<row[\s>].*?</row>', dotAll: true).allMatches(xml)) {
    final cells = <String>[];
    for (final cm in RegExp(r'<c\s([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true).allMatches(rm.group(0)!)) {
      final attrs = cm.group(1) ?? '';
      final body = cm.group(2) ?? '';
      final letters = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs)?.group(1);
      var idx = cells.length;
      if (letters != null) {
        idx = 0;
        for (final ch in letters.codeUnits) {
          idx = idx * 26 + (ch - 64);
        }
        idx -= 1;
      }
      final type = RegExp(r'\bt="(\w+)"').firstMatch(attrs)?.group(1) ?? 'n';
      final v = _textOf(body, 'v');
      String value;
      if (type == 's') {
        final i = int.tryParse(v.trim());
        value = (i != null && i >= 0 && i < shared.length) ? shared[i] : '';
      } else if (type == 'inlineStr') {
        value = _textOf(body, 't');
      } else if (type == 'b') {
        value = v.trim() == '1' ? 'TRUE' : 'FALSE';
      } else {
        value = v;
      }
      while (cells.length < idx) {
        cells.add('');
      }
      if (idx < cells.length) {
        cells[idx] = value;
      } else {
        cells.add(value);
      }
    }
    rows.add(cells);
    if (rows.length >= 300) break;
  }
  while (rows.isNotEmpty && rows.last.every((c) => c.trim().isEmpty)) {
    rows.removeLast();
  }
  return rows;
}

List<List<String>> parseCsvRows(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  var d = ',';
  var best = -1;
  for (final c in const [',', ';', '\t']) {
    final n = c.allMatches(firstLine).length;
    if (n > best) {
      best = n;
      d = c;
    }
  }
  final rows = <List<String>>[];
  var row = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cur.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == d) {
      row.add(cur.toString());
      cur.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cur.toString());
      cur.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cur.write(ch);
    }
  }
  if (cur.isNotEmpty || row.isNotEmpty) {
    row.add(cur.toString());
    rows.add(row);
  }
  rows.removeWhere((r) => r.every((c) => c.trim().isEmpty));
  return rows.length > 300 ? rows.sublist(0, 300) : rows;
}

List<DocBlock> parsePlainText(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final out = <DocBlock>[];
  final para = StringBuffer();
  void flush() {
    final t = para.toString().trim();
    if (t.isNotEmpty) out.add(DocBlock.p(t));
    para.clear();
  }

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      out.add(DocBlock.h2(line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      flush();
      out.add(DocBlock.h1(line.substring(2).trim()));
    } else if (RegExp(r'^\s*([-*•])\s+').hasMatch(line)) {
      flush();
      out.add(DocBlock.bullet(line.replaceFirst(RegExp(r'^\s*([-*•])\s+'), '').trim()));
    } else {
      if (para.isNotEmpty) para.write(' ');
      para.write(line.trim());
    }
  }
  flush();
  return out;
}

/// A file the user picked, with the readable content extracted (when possible).
class ImportedFile {
  final String name; // file name without extension
  final String ext;
  final Uint8List bytes;
  final List<DocBlock> blocks;
  final List<List<String>> table; // rows of xlsx/csv files, empty otherwise
  const ImportedFile(this.name, this.ext, this.bytes, this.blocks, this.table);
}

const importableExtensions = ['docx', 'xlsx', 'csv', 'txt', 'md', 'pdf'];

/// Opens the system file picker. Returns null when the user cancels.
/// Throws [FormatException] with a friendly message when the file can't be used.
Future<ImportedFile?> pickDocument({List<String> allowed = importableExtensions}) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowed,
    withData: true,
  );
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.first;
  final bytes = f.bytes;
  if (bytes == null) throw const FormatException('Could not read that file. Try another one.');
  if (bytes.length > 8 * 1024 * 1024) throw const FormatException('That file is larger than 8 MB.');
  final dot = f.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
  final base = dot < 0 ? f.name : f.name.substring(0, dot);
  try {
    switch (ext) {
      case 'docx':
        final docxBlocks = parseDocx(bytes);
        return ImportedFile(base, ext, bytes, docxBlocks.isEmpty ? const [DocBlock.p('This document has no readable text.')] : docxBlocks, const []);
      case 'xlsx':
        final xlsxRows = parseXlsxRows(bytes);
        return ImportedFile(base, ext, bytes, xlsxRows.isEmpty ? const [DocBlock.p('This workbook is empty.')] : [DocBlock.table(xlsxRows)], xlsxRows);
      case 'csv':
        final csvRows = parseCsvRows(utf8.decode(bytes, allowMalformed: true));
        return ImportedFile(base, ext, bytes, csvRows.isEmpty ? const [DocBlock.p('This file is empty.')] : [DocBlock.table(csvRows)], csvRows);
      case 'txt':
      case 'md':
        final txtBlocks = parsePlainText(utf8.decode(bytes, allowMalformed: true));
        return ImportedFile(base, ext, bytes, txtBlocks.isEmpty ? const [DocBlock.p('This file is empty.')] : txtBlocks, const []);
      default:
        return ImportedFile(base, ext, bytes, const [
          DocBlock.p('This file type cannot be previewed inside the app.'),
          DocBlock.p('Use "Download original" to open it in another app.'),
        ], const []);
    }
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Could not read that file. If it is an old .xls or .doc, save it as .xlsx or .docx first.');
  }
}

/// Opens the picker for a profile picture. Returns null when the user cancels.
/// Throws [FormatException] with a friendly message when the picture can't be used.
Future<Uint8List?> pickPhoto() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (r == null || r.files.isEmpty) return null;
  final b = r.files.first.bytes;
  if (b == null) throw const FormatException('Could not read that picture. Try another one.');
  if (b.length > 4 * 1024 * 1024) throw const FormatException('That picture is larger than 4 MB.');
  return b;
}

// =============================================================== saving

String safeFileName(String name) {
  final s = name.replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
  return s.isEmpty ? 'document' : s;
}

/// Saves [bytes] through the system "save as" dialog (browser download on web).
/// Returns false when the user cancelled.
Future<bool> saveBytes(String fileName, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
    bytes: bytes,
  );
  return kIsWeb ? true : path != null;
}

Future<bool> exportDocx(String title, List<DocBlock> blocks) =>
    saveBytes('${safeFileName(title)}.docx', buildDocx(title, blocks));

Future<bool> exportXlsx(String title, List<DocBlock> blocks) =>
    saveBytes('${safeFileName(title)}.xlsx', buildXlsx(title, blocks));
