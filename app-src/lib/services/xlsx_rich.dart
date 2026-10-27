// A nicer Excel (.xlsx) writer: a coloured title banner, styled headings, banded rows, peso and number formats,
// and real Excel charts that read the numbers from the sheet. Used by the unit history export.
// An .xlsx file is a zip of small XML files, written here by hand (no extra package needed).

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A chart drawn next to a table. It reads the first column as the labels and [valueCols] as the series.
class RChart {
  final String title;
  final bool donut;
  final List<int> valueCols;
  final List<String> colors; // hex without #
  const RChart(this.title, {this.donut = false, this.valueCols = const [1], this.colors = const ['5B4FB3', '14A38B', 'F2A33A', 'E5534B']});
}

/// One table on a sheet. Cells are String or num. [kinds] gives each column 'text', 'money' or 'int'.
class RTable {
  final String title;
  final List<String> head;
  final List<List<Object>> rows;
  final List<String> kinds;
  final RChart? chart;
  const RTable(this.title, this.head, this.rows, {this.kinds = const [], this.chart});
}

class RSheet {
  final String name, banner, note, tab;
  final List<RTable> tables;
  const RSheet(this.name, this.banner, this.tables, {this.note = '', this.tab = '5B4FB3'});
}

const _head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkg = 'http://schemas.openxmlformats.org/package/2006/relationships';

String _x(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

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

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  final out = ZipEncoder().encode(a);
  return Uint8List.fromList(out ?? const <int>[]);
}

// cell styles (positions in cellXfs below)
const _sBanner = 1, _sNote = 2, _sTitle = 3, _sHeadL = 4, _sHeadR = 5;
int _sCell(String kind, bool band) => switch (kind) { 'money' => band ? 9 : 8, 'int' => band ? 11 : 10, _ => band ? 7 : 6 };

const _styles = '$_head<styleSheet xmlns="$_ns">'
    '<numFmts count="2"><numFmt numFmtId="164" formatCode="&quot;₱&quot;#,##0.00"/><numFmt numFmtId="165" formatCode="#,##0"/></numFmts>'
    '<fonts count="5">'
    '<font><sz val="11"/><color rgb="FF1F2340"/><name val="Calibri"/></font>'
    '<font><b/><sz val="16"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
    '<font><i/><sz val="10"/><color rgb="FF6B7090"/><name val="Calibri"/></font>'
    '<font><b/><sz val="12"/><color rgb="FF3B3486"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="5"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF3B3486"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF5B4FB3"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF7F6FD"/><bgColor indexed="64"/></patternFill></fill></fills>'
    '<borders count="3"><border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="medium"><color rgb="FF5B4FB3"/></bottom><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="thin"><color rgb="FFE4E1F4"/></bottom><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="12">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
    '<xf numFmtId="0" fontId="4" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="0" fontId="4" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="right" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="2" xfId="0" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="0" fontId="0" fillId="4" borderId="2" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="164" fontId="0" fillId="4" borderId="2" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center" indent="1"/></xf>'
    '<xf numFmtId="165" fontId="0" fillId="4" borderId="2" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center" indent="1"/></xf>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';

String _fill(String c) => '<a:solidFill><a:srgbClr val="$c"/></a:solidFill>';
String _txPr(int sz, String color, bool bold) =>
    '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="$sz" b="${bold ? 1 : 0}">${_fill(color)}</a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>';

String _strRef(String f, List<String> arr) =>
    '<c:strRef><c:f>${_x(f)}</c:f><c:strCache><c:ptCount val="${arr.length}"/>${[for (var i = 0; i < arr.length; i++) '<c:pt idx="$i"><c:v>${_x(arr[i])}</c:v></c:pt>'].join()}</c:strCache></c:strRef>';

String _numRef(String f, List<num> arr) =>
    '<c:numRef><c:f>${_x(f)}</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="${arr.length}"/>${[for (var i = 0; i < arr.length; i++) '<c:pt idx="$i"><c:v>${arr[i]}</c:v></c:pt>'].join()}</c:numCache></c:numRef>';

String _dLbls(String fmt, String? pos, String color) =>
    '<c:dLbls><c:numFmt formatCode="${_x(fmt)}" sourceLinked="0"/><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>${_txPr(900, color, true)}${pos == null ? '' : '<c:dLblPos val="$pos"/>'}'
    '<c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';

num _n(Object o) => o is num ? o : (num.tryParse(o.toString()) ?? 0);

/// The XML of one chart. [sheet] is the sheet name, [r0] the first data row (1-based) and [r1] the last.
String _chartXml(RChart c, RTable t, String sheet, int headRow, int r0, int r1) {
  final cats = [for (final r in t.rows) r.first.toString()];
  final q = "'${sheet.replaceAll("'", "''")}'";
  final catRef = '$q!\$A\$$r0:\$A\$$r1';
  const fmt = '#,##0;;';
  final ser = StringBuffer();
  for (var i = 0; i < c.valueCols.length; i++) {
    final vc = c.valueCols[i];
    final name = vc < t.head.length ? t.head[vc] : 'Series ${i + 1}';
    final nameRef = '$q!\$${_col(vc)}\$$headRow';
    final valRef = '$q!\$${_col(vc)}\$$r0:\$${_col(vc)}\$$r1';
    final vals = [for (final r in t.rows) vc < r.length ? _n(r[vc]) : 0];
    final head = '<c:idx val="$i"/><c:order val="$i"/><c:tx>${_strRef(nameRef, [name])}</c:tx>';
    final tail = '<c:cat>${_strRef(catRef, cats)}</c:cat><c:val>${_numRef(valRef, vals)}</c:val>';
    if (c.donut) {
      final pts = [
        for (var k = 0; k < cats.length; k++)
          '<c:dPt><c:idx val="$k"/><c:bubble3D val="0"/><c:spPr>${_fill(c.colors[k % c.colors.length])}<a:ln w="19050">${_fill('FFFFFF')}</a:ln></c:spPr></c:dPt>'
      ].join();
      ser.write('<c:ser>$head$pts${_dLbls(fmt, null, 'FFFFFF')}$tail</c:ser>');
    } else {
      ser.write('<c:ser>$head<c:spPr>${_fill(c.colors[i % c.colors.length])}</c:spPr><c:invertIfNegative val="0"/>${_dLbls(fmt, 'outEnd', '1F2340')}$tail</c:ser>');
    }
  }
  final String plot;
  if (c.donut) {
    plot = '<c:doughnutChart><c:varyColors val="1"/>$ser<c:firstSliceAng val="0"/><c:holeSize val="55"/></c:doughnutChart>';
  } else {
    final axLine = '<c:spPr><a:ln w="9525">${_fill('D5D8E6')}</a:ln></c:spPr>';
    plot = '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/><c:varyColors val="0"/>$ser<c:gapWidth val="55"/><c:axId val="50010"/><c:axId val="50020"/></c:barChart>'
        '<c:catAx><c:axId val="50010"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="b"/>'
        '<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>$axLine${_txPr(900, '4A4F6B', false)}'
        '<c:crossAx val="50020"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/></c:catAx>'
        '<c:valAx><c:axId val="50020"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="l"/>'
        '<c:majorGridlines><c:spPr><a:ln w="9525">${_fill('E8EAF2')}</a:ln></c:spPr></c:majorGridlines>'
        '<c:numFmt formatCode="#,##0" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/><c:spPr><a:ln><a:noFill/></a:ln></c:spPr>${_txPr(900, '6B7090', false)}'
        '<c:crossAx val="50010"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>';
  }
  final legend = (c.donut || c.valueCols.length > 1) ? '<c:legend><c:legendPos val="${c.donut ? 'r' : 'b'}"/><c:overlay val="0"/>${_txPr(900, '4A4F6B', false)}</c:legend>' : '';
  return '$_head<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$_rel"><c:roundedCorners val="0"/><c:chart>'
      '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1200" b="1"/></a:pPr><a:r><a:rPr lang="en-US" sz="1200" b="1">${_fill('1F2340')}</a:rPr><a:t>${_x(c.title)}</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>'
      '<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>$plot</c:plotArea>$legend<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>'
      '<c:spPr>${_fill('FFFFFF')}<a:ln w="9525">${_fill('E4E1F4')}</a:ln></c:spPr>${_txPr(900, '1F2340', false)}</c:chartSpace>';
}

String _drawingXml(List<({int col, int row, int toCol, int toRow})> anchors) {
  const colEmu = 960000, rowEmu = 190500;
  final sb = StringBuffer('$_head<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');
  for (var i = 0; i < anchors.length; i++) {
    final a = anchors[i];
    sb.write('<xdr:twoCellAnchor><xdr:from><xdr:col>${a.col}</xdr:col><xdr:colOff>50000</xdr:colOff><xdr:row>${a.row}</xdr:row><xdr:rowOff>40000</xdr:rowOff></xdr:from>'
        '<xdr:to><xdr:col>${a.toCol}</xdr:col><xdr:colOff>${colEmu - 50000}</xdr:colOff><xdr:row>${a.toRow}</xdr:row><xdr:rowOff>${rowEmu - 40000}</xdr:rowOff></xdr:to>'
        '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${i + 2}" name="Chart ${i + 1}"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr><xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="$_rel" r:id="rId${i + 1}"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>');
  }
  sb.write('</xdr:wsDr>');
  return sb.toString();
}

String _safeName(String raw, Set<String> used) {
  var n = raw.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
  if (n.length > 31) n = n.substring(0, 31);
  if (n.isEmpty) n = 'Sheet';
  final base = n;
  var k = 2;
  while (!used.add(n.toLowerCase())) {
    final suffix = ' ${k++}';
    n = '${base.length + suffix.length > 31 ? base.substring(0, 31 - suffix.length) : base}$suffix';
  }
  return n;
}

Uint8List buildXlsxRich(List<RSheet> sheets) {
  final used = <String>{};
  final names = [for (final s in sheets) _safeName(s.name, used)];
  final files = <String, String>{};
  final overrides = StringBuffer();
  final wbSheets = StringBuffer();
  final wbRels = StringBuffer();
  var chartNo = 0, drawNo = 0;
  for (var i = 0; i < sheets.length; i++) {
    final s = sheets[i];
    final nCols = s.tables.fold<int>(1, (m, t) => math.max(m, t.head.length));
    final widths = List<double>.filled(nCols, 12);
    for (final t in s.tables) {
      for (var c = 0; c < t.head.length; c++) {
        widths[c] = math.max(widths[c], t.head[c].length + 4.0);
      }
      for (final r in t.rows) {
        for (var c = 0; c < r.length && c < nCols; c++) {
          final len = r[c] is num ? 16.0 : math.min(50, r[c].toString().split('\n').first.length + 3).toDouble();
          widths[c] = math.max(widths[c], len);
        }
      }
    }
    // rows are written into a map first (row number -> cell xml)
    final rowsXml = <int, String>{};
    final heights = <int, int>{};
    void put(int r, int c, Object? v, int style) {
      final ref = '${_col(c)}$r';
      final cell = (v == null || (v is String && v.isEmpty))
          ? '<c r="$ref" s="$style"/>'
          : v is num
              ? '<c r="$ref" s="$style"><v>$v</v></c>'
              : '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_x(v.toString())}</t></is></c>';
      rowsXml[r] = (rowsXml[r] ?? '') + cell;
    }

    final width = math.max(nCols + 9, 10);
    put(1, 0, s.banner, _sBanner);
    for (var c = 1; c < width; c++) {
      put(1, c, null, _sBanner);
    }
    heights[1] = 36;
    if (s.note.isNotEmpty) put(2, 0, s.note, _sNote);
    var r = 4;
    final charts = <({RChart c, RTable t, int head, int r0, int r1, int row})>[];
    for (final t in s.tables) {
      final start = r;
      if (t.title.isNotEmpty) {
        put(r, 0, t.title, _sTitle);
        for (var c = 1; c < t.head.length; c++) {
          put(r, c, null, _sTitle);
        }
        heights[r] = 24;
        r++;
      }
      final headRow = r;
      for (var c = 0; c < t.head.length; c++) {
        final kind = c < t.kinds.length ? t.kinds[c] : 'text';
        put(r, c, t.head[c], kind == 'text' ? _sHeadL : _sHeadR);
      }
      heights[r] = 26;
      r++;
      final first = r;
      for (var k = 0; k < t.rows.length; k++) {
        for (var c = 0; c < t.head.length; c++) {
          final kind = c < t.kinds.length ? t.kinds[c] : 'text';
          final v = c < t.rows[k].length ? t.rows[k][c] : '';
          put(r, c, v, _sCell(v is num ? (kind == 'text' ? 'int' : kind) : 'text', k.isOdd));
        }
        r++;
      }
      if (t.chart != null && t.rows.isNotEmpty) {
        charts.add((c: t.chart!, t: t, head: headRow, r0: first, r1: r - 1, row: start));
        final need = start + 16;
        if (r < need) r = need;
      }
      r += 2;
    }
    final sb = StringBuffer('$_head<worksheet xmlns="$_ns" xmlns:r="$_rel">');
    sb.write('<sheetPr><tabColor rgb="FF${s.tab}"/><pageSetUpPr fitToPage="1"/></sheetPr>');
    sb.write('<sheetViews><sheetView showGridLines="0"${i == 0 ? ' tabSelected="1"' : ''} workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>');
    for (var c = 0; c < width; c++) {
      sb.write('<col min="${c + 1}" max="${c + 1}" width="${c < nCols ? math.min(widths[c], 60) : 13}" customWidth="1"/>');
    }
    sb.write('</cols><sheetData>');
    final keys = rowsXml.keys.toList()..sort();
    for (final k in keys) {
      sb.write('<row r="$k"${heights[k] == null ? '' : ' ht="${heights[k]}" customHeight="1"'}>${rowsXml[k]}</row>');
    }
    sb.write('</sheetData><mergeCells count="1"><mergeCell ref="A1:${_col(width - 1)}1"/></mergeCells>');
    sb.write('<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/><pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>');
    if (charts.isNotEmpty) {
      drawNo++;
      sb.write('<drawing r:id="rId1"/>');
      final anchors = <({int col, int row, int toCol, int toRow})>[];
      final drawRels = StringBuffer();
      for (var k = 0; k < charts.length; k++) {
        chartNo++;
        final ch = charts[k];
        files['xl/charts/chart$chartNo.xml'] = _chartXml(ch.c, ch.t, names[i], ch.head, ch.r0, ch.r1);
        overrides.write('<Override PartName="/xl/charts/chart$chartNo.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>');
        drawRels.write('<Relationship Id="rId${k + 1}" Type="$_rel/chart" Target="../charts/chart$chartNo.xml"/>');
        final startCol = ch.t.head.length + 1;
        anchors.add((col: startCol, row: ch.row - 1, toCol: startCol + 6, toRow: ch.row + 14));
      }
      files['xl/drawings/drawing$drawNo.xml'] = _drawingXml(anchors);
      files['xl/drawings/_rels/drawing$drawNo.xml.rels'] = '$_head<Relationships xmlns="$_pkg">$drawRels</Relationships>';
      files['xl/worksheets/_rels/sheet${i + 1}.xml.rels'] = '$_head<Relationships xmlns="$_pkg"><Relationship Id="rId1" Type="$_rel/drawing" Target="../drawings/drawing$drawNo.xml"/></Relationships>';
      overrides.write('<Override PartName="/xl/drawings/drawing$drawNo.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>');
    }
    sb.write('</worksheet>');
    files['xl/worksheets/sheet${i + 1}.xml'] = sb.toString();
    overrides.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    wbSheets.write('<sheet name="${_x(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    wbRels.write('<Relationship Id="rId${i + 1}" Type="$_rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>');
  }
  wbRels.write('<Relationship Id="rId${sheets.length + 1}" Type="$_rel/styles" Target="styles.xml"/>');
  return _zip({
    '[Content_Types].xml':
        '$_head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>$overrides'
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    '_rels/.rels': '$_head<Relationships xmlns="$_pkg"><Relationship Id="rId1" Type="$_rel/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': '$_head<workbook xmlns="$_ns" xmlns:r="$_rel"><bookViews><workbookView activeTab="0"/></bookViews><sheets>$wbSheets</sheets><calcPr fullCalcOnLoad="1"/></workbook>',
    'xl/_rels/workbook.xml.rels': '$_head<Relationships xmlns="$_pkg">$wbRels</Relationships>',
    'xl/styles.xml': _styles,
    ...files,
  });
}
