/* DEMO ONLY: "Export all data" for the administrator.
   Builds ONE Excel workbook (.xlsx) with a dashboard overview (key figures and charts) and one formatted sheet for every part of the system
   (units, accounts, dues, payments, expenses, bookings, parking, grievances and repairs, announcements, events,
   polls, maintenance, equipment, staff, activity log), then lets the administrator save it.
   No library is needed: an .xlsx file is a zip of small XML files, written here by hand (zip "store" method).
   Loaded by demo/admin.html after maintenance.js. It reads the data that is already loaded in the page (DB.rows). */
(function () {
  if (!window.RH_DEMO) return;
  var XLSX_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

  /* ---------- tiny zip writer (no compression) ---------- */
  function crc32(bytes) {
    var t = crc32.t;
    if (!t) {
      t = crc32.t = [];
      for (var n = 0; n < 256; n++) { var c0 = n; for (var k = 0; k < 8; k++) c0 = (c0 & 1) ? (0xEDB88320 ^ (c0 >>> 1)) : (c0 >>> 1); t[n] = c0 >>> 0; }
    }
    var c = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) c = t[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }
  function zip(files) {
    var enc = new TextEncoder(), parts = [], central = [], offset = 0, cdSize = 0;
    files.forEach(function (f) {
      var name = enc.encode(f.name), data = enc.encode(f.text), crc = crc32(data), size = data.length;
      var lh = new DataView(new ArrayBuffer(30));
      lh.setUint32(0, 0x04034b50, true); lh.setUint16(4, 20, true); lh.setUint16(6, 0x0800, true); lh.setUint16(8, 0, true);
      lh.setUint16(10, 0, true); lh.setUint16(12, 0x21, true); lh.setUint32(14, crc, true); lh.setUint32(18, size, true);
      lh.setUint32(22, size, true); lh.setUint16(26, name.length, true); lh.setUint16(28, 0, true);
      parts.push(new Uint8Array(lh.buffer), name, data);
      var ch = new DataView(new ArrayBuffer(46));
      ch.setUint32(0, 0x02014b50, true); ch.setUint16(4, 20, true); ch.setUint16(6, 20, true); ch.setUint16(8, 0x0800, true);
      ch.setUint16(10, 0, true); ch.setUint16(12, 0, true); ch.setUint16(14, 0x21, true); ch.setUint32(16, crc, true);
      ch.setUint32(20, size, true); ch.setUint32(24, size, true); ch.setUint16(28, name.length, true); ch.setUint16(30, 0, true);
      ch.setUint16(32, 0, true); ch.setUint16(34, 0, true); ch.setUint16(36, 0, true); ch.setUint32(38, 0, true); ch.setUint32(42, offset, true);
      central.push(new Uint8Array(ch.buffer), name);
      cdSize += 46 + name.length;
      offset += 30 + name.length + size;
    });
    var end = new DataView(new ArrayBuffer(22));
    end.setUint32(0, 0x06054b50, true); end.setUint16(4, 0, true); end.setUint16(6, 0, true); end.setUint16(8, files.length, true);
    end.setUint16(10, files.length, true); end.setUint32(12, cdSize, true); end.setUint32(16, offset, true); end.setUint16(20, 0, true);
    return new Blob(parts.concat(central, [new Uint8Array(end.buffer)]), { type: XLSX_TYPE });
  }

  /* ---------- colours ---------- */
  var C = { deep: "3B3486", brand: "5B4FB3", band: "F7F6FD", tint: "F3F1FC", line: "E4E1F4", text: "1F2340", muted: "6B7090", link: "2563EB",
            green: "14A38B", amber: "F2A33A", red: "E5534B", blue: "3B82F6", gray: "9AA0B5", pink: "D6579B" };
  var FMT = { money: '"₱"#,##0.00', date: "mmm\\ d\\,\\ yyyy", int: "#,##0" };

  /* ---------- xlsx pieces ---------- */
  function x(s) { return String(s == null ? "" : s).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
  function colName(i) { var s = ""; i++; while (i > 0) { var m = (i - 1) % 26; s = String.fromCharCode(65 + m) + s; i = Math.floor((i - 1) / 26); } return s; }
  function serial(d) { return Math.round((Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(1899, 11, 30)) / 86400000); }
  function toDate(v) {
    if (v instanceof Date) return isNaN(v) ? null : v;
    var s = String(v == null ? "" : v).trim(), m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
    if (m) return new Date(+m[1], +m[2] - 1, +m[3]);
    return s ? parseShort(s) : null;
  }

  /* style registry: every look is described once, and gets a number that cells point to */
  var R;
  function resetStyles() {
    R = { fonts: ['<font><sz val="10"/><color rgb="FF' + C.text + '"/><name val="Calibri"/></font>'],
          fills: ['<fill><patternFill patternType="none"/></fill>', '<fill><patternFill patternType="gray125"/></fill>'],
          borders: ["<border><left/><right/><top/><bottom/><diagonal/></border>"], fmts: [],
          xfs: ['<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'], keys: {} };
  }
  function pushU(arr, xml) { var i = arr.indexOf(xml); if (i < 0) { arr.push(xml); i = arr.length - 1; } return i; }
  function side(tag, spec) { return spec ? "<" + tag + ' style="' + spec[0] + '"><color rgb="FF' + spec[1] + '"/></' + tag + ">" : "<" + tag + "/>"; }
  function sty(o) {
    var key = JSON.stringify(o);
    if (R.keys.hasOwnProperty(key)) return R.keys[key];
    var font = "<font>" + (o.b ? "<b/>" : "") + (o.i ? "<i/>" : "") + (o.u ? "<u/>" : "") + '<sz val="' + (o.sz || 10) + '"/><color rgb="FF' + (o.color || C.text) + '"/><name val="Calibri"/></font>';
    var fill = o.fill ? '<fill><patternFill patternType="solid"><fgColor rgb="FF' + o.fill + '"/><bgColor indexed="64"/></patternFill></fill>' : null;
    var border = "<border>" + side("left", o.bl) + side("right", o.br) + side("top", o.bt) + side("bottom", o.bb) + "<diagonal/></border>";
    var fmtId = 0;
    if (o.fmt) { var fi = R.fmts.indexOf(o.fmt); if (fi < 0) { R.fmts.push(o.fmt); fi = R.fmts.length - 1; } fmtId = 164 + fi; }
    var al = (o.h || o.v || o.wrap) ? "<alignment" + (o.h ? ' horizontal="' + o.h + '"' : "") + (o.v ? ' vertical="' + o.v + '"' : "") + (o.wrap ? ' wrapText="1"' : "") + (o.indent ? ' indent="' + o.indent + '"' : "") + "/>" : "";
    var xf = '<xf numFmtId="' + fmtId + '" fontId="' + pushU(R.fonts, font) + '" fillId="' + (fill ? pushU(R.fills, fill) : 0) + '" borderId="' + pushU(R.borders, border) +
      '" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"' + (al ? ' applyAlignment="1">' + al + "</xf>" : "/>");
    R.xfs.push(xf);
    return (R.keys[key] = R.xfs.length - 1);
  }
  var DXFS = ["1E7A4F|DDF3E8", "9A5B00|FFF0D2", "B3261E|FDE2DF", "1D4ED8|DEE9FD", "6B7090|ECEEF5"]; // good, warn, bad, info, muted
  function stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      (R.fmts.length ? '<numFmts count="' + R.fmts.length + '">' + R.fmts.map(function (f, i) { return '<numFmt numFmtId="' + (164 + i) + '" formatCode="' + x(f) + '"/>'; }).join("") + "</numFmts>" : "") +
      '<fonts count="' + R.fonts.length + '">' + R.fonts.join("") + "</fonts>" +
      '<fills count="' + R.fills.length + '">' + R.fills.join("") + "</fills>" +
      '<borders count="' + R.borders.length + '">' + R.borders.join("") + "</borders>" +
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
      '<cellXfs count="' + R.xfs.length + '">' + R.xfs.join("") + "</cellXfs>" +
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
      '<dxfs count="' + DXFS.length + '">' + DXFS.map(function (d) { var p = d.split("|"); return '<dxf><font><b/><color rgb="FF' + p[0] + '"/></font><fill><patternFill><bgColor rgb="FF' + p[1] + '"/></patternFill></fill></dxf>'; }).join("") + "</dxfs></styleSheet>";
  }

  /* a sheet is a grid of cells (row, column from 0), plus merged areas and links */
  function emit(r, c, val, s) {
    var ref = colName(c) + (r + 1), sa = ' s="' + (s || 0) + '"', blank = '<c r="' + ref + '"' + sa + "/>";
    if (val == null || val === "") return blank;
    if (val instanceof Date) return isNaN(val) ? blank : '<c r="' + ref + '"' + sa + "><v>" + serial(val) + "</v></c>";
    if (typeof val === "number") return isFinite(val) ? '<c r="' + ref + '"' + sa + "><v>" + val + "</v></c>" : blank;
    if (typeof val === "object" && val.f) return '<c r="' + ref + '"' + sa + "><f>" + x(val.f) + "</f><v>" + val.v + "</v></c>";
    if (typeof val === "boolean") val = val ? "Yes" : "No";
    return '<c r="' + ref + '"' + sa + ' t="inlineStr"><is><t xml:space="preserve">' + x(val) + "</t></is></c>";
  }
  function Grid() { this.c = {}; this.h = {}; this.merges = []; this.links = []; this.max = 0; }
  Grid.prototype.put = function (r, c, v, s) { (this.c[r] || (this.c[r] = {}))[c] = { v: v, s: s }; if (r > this.max) this.max = r; return this; };
  Grid.prototype.span = function (r, c1, c2, v, s, merge) {
    this.put(r, c1, v, s);
    for (var c = c1 + 1; c <= c2; c++) this.put(r, c, null, s);
    if (merge !== false && c2 > c1) this.merges.push(colName(c1) + (r + 1) + ":" + colName(c2) + (r + 1));
    return this;
  };
  Grid.prototype.link = function (r, c, loc) { this.links.push({ ref: colName(c) + (r + 1), loc: loc }); };
  Grid.prototype.rowsXml = function () {
    var out = "";
    for (var r = 0; r <= this.max; r++) {
      var row = this.c[r], ht = this.h[r];
      if (!row && !ht) continue;
      out += '<row r="' + (r + 1) + '"' + (ht ? ' ht="' + ht + '" customHeight="1"' : "") + ">";
      if (row) Object.keys(row).map(Number).sort(function (a, b) { return a - b; }).forEach(function (c) { out += emit(r, c, row[c].v, row[c].s); });
      out += "</row>";
    }
    return out;
  };

  function sheetXml(sh, first, drawingRid) {
    var g = sh.grid, out = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">';
    out += '<sheetPr>' + (sh.tab ? '<tabColor rgb="FF' + sh.tab + '"/>' : "") + '<pageSetUpPr fitToPage="1"/></sheetPr>';
    out += '<sheetViews><sheetView showGridLines="0"' + (first ? ' tabSelected="1"' : "") + ' workbookViewId="0">' +
      (sh.freeze ? '<pane ySplit="' + sh.freeze + '" topLeftCell="A' + (sh.freeze + 1) + '" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A' + (sh.freeze + 1) + '" sqref="A' + (sh.freeze + 1) + '"/>' : "") + "</sheetView></sheetViews>";
    out += '<sheetFormatPr defaultRowHeight="15"/>';
    out += "<cols>" + sh.widths.map(function (w, i) { return '<col min="' + (i + 1) + '" max="' + (i + 1) + '" width="' + w + '" customWidth="1"/>'; }).join("") + "</cols>";
    out += "<sheetData>" + g.rowsXml() + "</sheetData>";
    if (sh.filter) out += '<autoFilter ref="' + sh.filter + '"/>';
    if (g.merges.length) out += '<mergeCells count="' + g.merges.length + '">' + g.merges.map(function (m) { return '<mergeCell ref="' + m + '"/>'; }).join("") + "</mergeCells>";
    (sh.cfs || []).forEach(function (cf) { out += cf; });
    if (g.links.length) out += "<hyperlinks>" + g.links.map(function (l) { return '<hyperlink ref="' + l.ref + '" location="' + x(l.loc) + '"/>'; }).join("") + "</hyperlinks>";
    out += '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/><pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>';
    if (drawingRid) out += '<drawing r:id="' + drawingRid + '"/>';
    return out + "</worksheet>";
  }

  /* ---------- charts ---------- */
  var PAL = [C.brand, C.green, C.amber, C.red, C.blue, C.gray, C.pink, "7A5AF8"];
  var K_FMT = '[>=1000000]"₱"0.0,,"M";[>=1000]"₱"0.0,"K";"₱"0', N_FMT = "#,##0;;";
  function fillX(c) { return '<a:solidFill><a:srgbClr val="' + c + '"/></a:solidFill>'; }
  function txPr(sz, color, bold) { return '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="' + sz + '" b="' + (bold ? 1 : 0) + '">' + fillX(color) + '</a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>'; }
  function strRef(f, arr) { return "<c:strRef><c:f>" + x(f) + '</c:f><c:strCache><c:ptCount val="' + arr.length + '"/>' + arr.map(function (v, i) { return '<c:pt idx="' + i + '"><c:v>' + x(v) + "</c:v></c:pt>"; }).join("") + "</c:strCache></c:strRef>"; }
  function numRef(f, arr) { return "<c:numRef><c:f>" + x(f) + '</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="' + arr.length + '"/>' + arr.map(function (v, i) { return '<c:pt idx="' + i + '"><c:v>' + (Number(v) || 0) + "</c:v></c:pt>"; }).join("") + "</c:numCache></c:numRef>"; }
  function dLbls(fmt, pos, color) {
    return '<c:dLbls><c:numFmt formatCode="' + x(fmt) + '" sourceLinked="0"/><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>' + txPr(900, color, true) + (pos ? '<c:dLblPos val="' + pos + '"/>' : "") +
      '<c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';
  }
  /* o: kind col | bar | stack | donut, title, cats[], catRef, series[{name,nameRef,vals[],ref,color,ptColors}], fmt (label/axis number format), legend */
  function chartXml(o) {
    var horiz = o.kind === "bar", donut = o.kind === "donut", stack = o.kind === "stack";
    var ser = o.series.map(function (s, i) {
      var head = '<c:idx val="' + i + '"/><c:order val="' + i + '"/><c:tx>' + strRef(s.nameRef, [s.name]) + "</c:tx>";
      var tail = "<c:cat>" + strRef(o.catRef, o.cats) + "</c:cat><c:val>" + numRef(s.ref, s.vals) + "</c:val>";
      var pts = "";
      if (donut) {
        pts = o.cats.map(function (c, k) { return '<c:dPt><c:idx val="' + k + '"/><c:bubble3D val="0"/><c:spPr>' + fillX(s.ptColors[k % s.ptColors.length]) + '<a:ln w="19050">' + fillX("FFFFFF") + "</a:ln></c:spPr></c:dPt>"; }).join("");
        return "<c:ser>" + head + pts + dLbls(o.fmt, null, "FFFFFF") + tail + "</c:ser>";
      }
      if (s.ptColors) pts = s.ptColors.map(function (pc, k) { return '<c:dPt><c:idx val="' + k + '"/><c:invertIfNegative val="0"/><c:bubble3D val="0"/><c:spPr>' + fillX(pc) + "</c:spPr></c:dPt>"; }).join("");
      return "<c:ser>" + head + "<c:spPr>" + fillX(s.color || PAL[i % PAL.length]) + '</c:spPr><c:invertIfNegative val="0"/>' + pts +
        dLbls(o.fmt, stack ? "ctr" : "outEnd", stack ? "FFFFFF" : C.text) + tail + "</c:ser>";
    }).join("");
    var plot;
    if (donut) plot = '<c:doughnutChart><c:varyColors val="1"/>' + ser + '<c:firstSliceAng val="0"/><c:holeSize val="55"/></c:doughnutChart>';
    else {
      var axLine = '<c:spPr><a:ln w="9525">' + fillX("D5D8E6") + "</a:ln></c:spPr>";
      plot = '<c:barChart><c:barDir val="' + (horiz ? "bar" : "col") + '"/><c:grouping val="' + (stack ? "stacked" : "clustered") + '"/><c:varyColors val="0"/>' + ser +
        '<c:gapWidth val="' + (o.gap || 55) + '"/>' + (stack ? '<c:overlap val="100"/>' : "") + '<c:axId val="50010"/><c:axId val="50020"/></c:barChart>' +
        '<c:catAx><c:axId val="50010"/><c:scaling><c:orientation val="' + (horiz ? "maxMin" : "minMax") + '"/></c:scaling><c:delete val="0"/><c:axPos val="' + (horiz ? "l" : "b") + '"/>' +
        '<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>' + axLine + txPr(900, "4A4F6B", false) +
        '<c:crossAx val="50020"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/></c:catAx>' +
        '<c:valAx><c:axId val="50020"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="' + (horiz ? 1 : 0) + '"/><c:axPos val="' + (horiz ? "b" : "l") + '"/>' +
        (horiz ? "" : '<c:majorGridlines><c:spPr><a:ln w="9525">' + fillX("E8EAF2") + "</a:ln></c:spPr></c:majorGridlines>") +
        '<c:numFmt formatCode="' + x(o.fmt) + '" sourceLinked="0"/><c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/><c:spPr><a:ln><a:noFill/></a:ln></c:spPr>' + txPr(900, "6B7090", false) +
        '<c:crossAx val="50010"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>';
    }
    var legend = o.legend ? '<c:legend><c:legendPos val="' + (donut ? "r" : "b") + '"/><c:overlay val="0"/>' + txPr(900, "4A4F6B", false) + "</c:legend>" : "";
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><c:roundedCorners val="0"/><c:chart>' +
      '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1200" b="1"/></a:pPr><a:r><a:rPr lang="en-US" sz="1200" b="1">' + fillX(C.text) + "</a:rPr><a:t>" + x(o.title) + "</a:t></a:r></a:p></c:rich></c:tx><c:overlay val=\"0\"/></c:title>" +
      '<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>' + plot + "</c:plotArea>" + legend + '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>' +
      "<c:spPr>" + fillX("FFFFFF") + '<a:ln w="9525">' + fillX(C.line) + "</a:ln></c:spPr>" + txPr(900, C.text, false) + "</c:chartSpace>";
  }
  function drawingXml(charts) {
    var EMU_COL = 960000, EMU_ROW = 190500;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
      charts.map(function (ch, i) {
        var a = ch.a;
        return "<xdr:twoCellAnchor><xdr:from><xdr:col>" + a[0] + "</xdr:col><xdr:colOff>50000</xdr:colOff><xdr:row>" + a[1] + "</xdr:row><xdr:rowOff>40000</xdr:rowOff></xdr:from>" +
          "<xdr:to><xdr:col>" + a[2] + "</xdr:col><xdr:colOff>" + (EMU_COL - 50000) + "</xdr:colOff><xdr:row>" + a[3] + "</xdr:row><xdr:rowOff>" + (EMU_ROW - 40000) + "</xdr:rowOff></xdr:to>" +
          '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="' + (i + 2) + '" name="Chart ' + (i + 1) + '"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr><xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>' +
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId' + (i + 1) + '"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>';
      }).join("") + "</xdr:wsDr>";
  }

  function safeName(n, used) {
    var s = String(n).replace(/[\[\]:*?\/\\]/g, " ").slice(0, 31).trim() || "Sheet", base = s, k = 2;
    while (used[s.toLowerCase()]) s = base.slice(0, 28) + " " + (k++);
    used[s.toLowerCase()] = 1;
    return s;
  }
  function makeXlsx(sheets) {
    var used = {}, names = sheets.map(function (s) { return safeName(s.name, used); });
    var REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships", PKG = "http://schemas.openxmlformats.org/package/2006/relationships";
    var head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    var ct = "", files = [], chartNo = 0, drawNo = 0, sheetFiles = [];
    sheets.forEach(function (s, i) {
      var rid = null;
      if (s.charts && s.charts.length) {
        drawNo++; rid = "rId1";
        var rels = "";
        s.charts.forEach(function (ch, k) {
          chartNo++;
          files.push({ name: "xl/charts/chart" + chartNo + ".xml", text: ch.xml });
          ct += '<Override PartName="/xl/charts/chart' + chartNo + '.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>';
          rels += '<Relationship Id="rId' + (k + 1) + '" Type="' + REL + '/chart" Target="../charts/chart' + chartNo + '.xml"/>';
        });
        files.push({ name: "xl/drawings/drawing" + drawNo + ".xml", text: drawingXml(s.charts) });
        files.push({ name: "xl/drawings/_rels/drawing" + drawNo + ".xml.rels", text: head + '<Relationships xmlns="' + PKG + '">' + rels + "</Relationships>" });
        files.push({ name: "xl/worksheets/_rels/sheet" + (i + 1) + ".xml.rels", text: head + '<Relationships xmlns="' + PKG + '"><Relationship Id="rId1" Type="' + REL + '/drawing" Target="../drawings/drawing' + drawNo + '.xml"/></Relationships>' });
        ct += '<Override PartName="/xl/drawings/drawing' + drawNo + '.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>';
      }
      sheetFiles.push({ name: "xl/worksheets/sheet" + (i + 1) + ".xml", text: sheetXml(s, i === 0, rid) });
    });
    var defined = "";
    sheets.forEach(function (s, i) { if (s.titles) defined += '<definedName name="_xlnm.Print_Titles" localSheetId="' + i + '">\'' + x(names[i]) + "'!" + s.titles + "</definedName>"; });
    var all = [
      { name: "[Content_Types].xml", text: head + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
        sheets.map(function (s, i) { return '<Override PartName="/xl/worksheets/sheet' + (i + 1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'; }).join("") + ct + "</Types>" },
      { name: "_rels/.rels", text: head + '<Relationships xmlns="' + PKG + '"><Relationship Id="rId1" Type="' + REL + '/officeDocument" Target="xl/workbook.xml"/></Relationships>' },
      { name: "xl/workbook.xml", text: head + '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="' + REL + '"><bookViews><workbookView activeTab="0"/></bookViews><sheets>' +
        names.map(function (n, i) { return '<sheet name="' + x(n) + '" sheetId="' + (i + 1) + '" r:id="rId' + (i + 1) + '"/>'; }).join("") + "</sheets>" + (defined ? "<definedNames>" + defined + "</definedNames>" : "") + '<calcPr fullCalcOnLoad="1"/></workbook>' },
      { name: "xl/_rels/workbook.xml.rels", text: head + '<Relationships xmlns="' + PKG + '">' +
        sheets.map(function (s, i) { return '<Relationship Id="rId' + (i + 1) + '" Type="' + REL + '/worksheet" Target="worksheets/sheet' + (i + 1) + '.xml"/>'; }).join("") +
        '<Relationship Id="rId' + (sheets.length + 1) + '" Type="' + REL + '/styles" Target="styles.xml"/></Relationships>' },
      { name: "xl/styles.xml", text: stylesXml() }
    ];
    return zip(all.concat(sheetFiles, files));
  }

  /* ---------- the data ---------- */
  function days(k) { var d = toDate(k); return d ? Math.round((d - new Date(new Date().setHours(0, 0, 0, 0))) / 86400000) : null; }
  function created(id) { var n = Number(id); return n > 1e12 ? new Date(n) : ""; }
  function stageName(s) { return ["Open", "In progress", "Resolved"][Math.min(2, Math.max(0, Number(s) || 0))]; }
  function sorted(rows, fn) { return rows.slice().sort(fn); }
  function money(n) { return Number(n) || 0; }
  function eqName(id) { var e = id ? getRow("equipment", id) : null; return e ? e.value.name : ""; }

  /* ---------- sheets ---------- */
  var GROUPS = [["Residents", C.brand], ["Money", C.green], ["Facilities", C.blue], ["Maintenance", C.amber], ["System", C.gray]];
  function groupColor(g) { for (var i = 0; i < GROUPS.length; i++) if (GROUPS[i][0] === g) return GROUPS[i][1]; return C.gray; }
  // colours for status words (good / warn / bad / info / muted); "begins" matches the start of the text
  var CF = {
    pay: { good: ["Paid", "Confirmed", "Approved", "Yes"], warn: ["Unpaid", "Pending", "Waiting"], bad: ["Overdue", "Denied", "Rejected"] },
    grv: { bad: ["Open"], info: ["In progress"], good: ["Resolved"] },
    prio: { bad: ["Urgent"], warn: ["High"] },
    cond: { good: ["Working"], warn: ["Under maintenance"], bad: ["Needs repair"] },
    sched: { bad: ["Overdue"], warn: ["Due"], begins: true },
    poll: { good: ["Open"], muted: ["Closed"] },
    pub: { good: ["Published"], warn: ["Draft"] },
    ann: { bad: ["Emergency"], warn: ["Warning"], info: ["Maintenance"] },
    susp: { bad: ["Yes"] },
    occ: { warn: ["Vacant"] }
  };
  var DXF = { good: 0, warn: 1, bad: 2, info: 3, muted: 4 };

  function bannerRows(g, ncols, title, info, backLink) {
    var banner = sty({ sz: 16, b: 1, color: "FFFFFF", fill: C.deep, v: "center", h: "left", indent: 1 });
    g.span(0, 0, ncols - 1, title, banner, false); g.h[0] = 34;
    if (backLink) { g.put(1, 0, "← Overview", sty({ u: 1, color: C.link, sz: 10, v: "center", h: "left", indent: 1 })); g.link(1, 0, "'Overview'!A1"); }
    if (info) g.put(1, backLink ? 1 : 0, info, sty({ i: 1, color: C.muted, sz: 10, v: "center" }));
    g.h[1] = 22;
  }

  /* one table sheet: banner, back link, header, banded rows, optional totals row, filter, status colours */
  function tableSheet(sh) {
    var g = new Grid(), n = sh.cols.length, HR = 2, R0 = 3;
    bannerRows(g, n, sh.name, sh.info, true);
        sh.cols.forEach(function (c, i) {
      var t = c[1] || "text";
      g.put(HR, i, c[0], sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: t === "status" ? "center" : t === "money" || t === "int" ? "right" : "left", indent: 1, bb: ["thin", C.deep] }));
    });
    g.h[HR] = 28;
    sh.rows.forEach(function (row, ri) {
      var band = ri % 2 === 1;
      sh.cols.forEach(function (c, i) {
        var t = c[1] || "text", o = c[2] || {}, v = row[i];
        if (t === "date" && v !== "" && v != null) { var d = toDate(v); if (d) v = d; }
        var st = sty({ fmt: t === "money" || t === "date" || t === "int" ? FMT[t] : undefined, h: t === "status" ? "center" : t === "money" || t === "int" ? "right" : "left",
                       v: "center", wrap: o.wrap ? 1 : undefined, fill: band ? C.band : undefined, bb: ["thin", C.line], indent: t === "status" ? undefined : 1 });
        g.put(R0 + ri, i, v, st);
      });
    });
    var last = R0 + sh.rows.length - 1, lastCol = colName(n - 1);
    // totals row (follows the filter: SUBTOTAL ignores hidden rows)
    var sums = sh.cols.map(function (c, i) { return (c[2] || {}).sum ? i : -1; }).filter(function (i) { return i >= 0; });
    if (sums.length && sh.rows.length) {
      var tr = last + 1, base = { b: 1, fill: C.tint, v: "center", bt: ["thin", C.brand], bb: ["medium", C.brand] };
      sh.cols.forEach(function (c, i) { g.put(tr, i, null, sty(base)); });
      g.put(tr, 0, "Total of shown rows", sty(Object.assign({ indent: 1, h: "left" }, base)));
      sums.forEach(function (i) {
        var tot = sh.rows.reduce(function (s, r) { return s + (Number(r[i]) || 0); }, 0);
        g.put(tr, i, { f: "SUBTOTAL(109," + colName(i) + (R0 + 1) + ":" + colName(i) + (last + 1) + ")", v: tot }, sty(Object.assign({ fmt: FMT[sh.cols[i][1]] || FMT.int, h: "right", indent: 1 }, base)));
      });
    }
    var cfs = [], prio = 1;
    sh.cols.forEach(function (c, i) {
      var o = c[2] || {}, rng = colName(i) + (R0 + 1) + ":" + colName(i) + (last + 1), first = colName(i) + (R0 + 1);
      if (!sh.rows.length) return;
      if (o.cf && CF[o.cf]) {
        var set = CF[o.cf], rules = "";
        Object.keys(DXF).forEach(function (k) {
          (set[k] || []).forEach(function (val) {
            rules += set.begins
              ? '<cfRule type="beginsWith" dxfId="' + DXF[k] + '" priority="' + (prio++) + '" operator="beginsWith" text="' + x(val) + '"><formula>LEFT(' + first + ",LEN(\"" + x(val) + '"))="' + x(val) + '"</formula></cfRule>'
              : '<cfRule type="cellIs" dxfId="' + DXF[k] + '" priority="' + (prio++) + '" operator="equal"><formula>"' + x(val) + '"</formula></cfRule>';
          });
        });
        cfs.push('<conditionalFormatting sqref="' + rng + '">' + rules + "</conditionalFormatting>");
      }
      if (o.bar) cfs.push('<conditionalFormatting sqref="' + rng + '"><cfRule type="dataBar" priority="' + (prio++) + '"><dataBar><cfvo type="num" val="0"/><cfvo type="max"/><color rgb="FFB9B2EE"/></dataBar></cfRule></conditionalFormatting>');
    });
    var widths = sh.cols.map(function (c, i) {
      var o = c[2] || {}, t = c[1] || "text";
      if (o.w) return o.w;
      var w = String(c[0]).length + 5;
      sh.rows.forEach(function (r) {
        var v = r[i];
        if (v == null || v === "") return;
        var l = v instanceof Date ? 13 : typeof v === "number" ? (t === "money" ? 15 : 11) : Math.min(42, String(v).split("\n")[0].length + 3);
        if (l > w) w = l;
      });
      if (t === "date") w = Math.max(w, 15);
      if (t === "money") w = Math.max(w, 16);
      return Math.max(i === 0 ? 16 : 11, Math.min(60, w));
    });
    return { name: sh.name, grid: g, widths: widths, tab: groupColor(sh.group), cfs: cfs, freeze: 3, titles: "$3:$3",
             filter: sh.rows.length ? "A3:" + lastCol + (last + 1) : null, charts: [] };
  }

  function buildSheets() {
    resetStyles();
    var tables = [], count = {};
    function add(group, name, cols, rows, info) { tables.push({ group: group, name: name, cols: cols, rows: rows, info: info }); count[name] = { n: rows.length, info: info, group: group }; }

    add("Residents", "Units", [["Unit"], ["Household", "text", { w: 26 }], ["Type"], ["Occupancy", "status", { cf: "occ" }], ["Contact", "text", { w: 16 }], ["Usage", "text", { w: 24 }], ["Usage status", "text", { w: 18 }]],
      sortedUnits().map(function (r) { var u = r.v; return [r.id, u.name, u.type, u.status, u.contact, typeof usageLabel === "function" ? usageLabel(u.usage || "") : u.usage, u.usageStatus || ""]; }),
      "Every unit, occupancy and how it is used");

    add("Residents", "Accounts", [["Name", "text", { w: 24 }], ["Email", "text", { w: 32 }], ["Mobile", "text", { w: 16 }], ["Role"], ["Unit"], ["Suspended", "status", { cf: "susp" }]],
      (DB.accounts || []).map(function (a) { return [a.name, a.email, a.phone, a.role, a.unit || "", a.suspended ? "Yes" : "No"]; }),
      "Sign-in accounts of residents and administrators");

    var dues = sorted(list("due"), function (a, b) { return String(a.v.unit).localeCompare(String(b.v.unit), undefined, { numeric: true }) || (Number(b.id) - Number(a.id)); });
    function duesState(d) { return d.paid ? "Paid" : (isOverdue(d) ? "Overdue" : "Unpaid"); }
    add("Money", "Dues", [["Unit"], ["Household", "text", { w: 26 }], ["Charge", "text", { w: 38 }], ["Amount", "money", { sum: 1 }], ["Due date", "date"], ["Status", "status", { cf: "pay" }]],
      dues.map(function (r) { var d = r.v; return [d.unit, d.name, d.note, money(d.amount), d.dueDate, duesState(d)]; }),
      "Monthly dues and other charges, paid or unpaid");

    add("Money", "Payments", [["Receipt no."], ["Date", "date"], ["Unit"], ["Paid by", "text", { w: 24 }], ["For", "text", { w: 30 }], ["Method", "text", { w: 26 }], ["Reference", "text", { w: 18 }], ["Amount", "money", { sum: 1 }]],
      newest(list("payment")).map(function (r) { var p = r.v; return [p.receiptNo, p.date, p.unit, p.payer, p.forText, p.method, p.reference, money(p.amount)]; }),
      "Confirmed payments with official receipt numbers");

    add("Money", "Payment proofs", [["Date", "date"], ["Unit"], ["Paid by", "text", { w: 24 }], ["For", "text", { w: 30 }], ["Method", "text", { w: 26 }], ["Reference", "text", { w: 18 }], ["Amount", "money", { sum: 1 }], ["Status", "status", { cf: "pay" }]],
      newest(list("proof")).map(function (r) { var p = r.v; return [p.date, p.unit, p.payer, p.forText, p.method, p.reference, money(p.amount), p.status]; }),
      "Payment details sent by residents, waiting for or past confirmation");

    var exp = sorted(list("expense"), function (a, b) { return String(b.v.date).localeCompare(String(a.v.date)); });
    add("Money", "Expenses", [["Date", "date"], ["Item", "text", { w: 32 }], ["Category", "text", { w: 30 }], ["For", "text", { w: 22 }], ["Supplier", "text", { w: 26 }], ["OR no."], ["Quantity", "int"], ["Price of one", "money"], ["Total", "money", { sum: 1, bar: 1 }], ["Equipment", "text", { w: 24 }], ["Note", "text", { w: 32, wrap: 1 }]],
      exp.map(function (r) { var e = r.v; return [e.date, e.item, e.category, e.area, e.payee, e.receiptNo, Number(e.qty || 1), money(e.unitPrice), expTotal(e), eqName(e.equipId), e.note]; }),
      "Every purchase and repair cost of the corporation");

    add("Facilities", "Facility bookings", [["Facility", "text", { w: 20 }], ["Date", "date"], ["Time", "text", { w: 20 }], ["Unit"], ["Household", "text", { w: 26 }], ["Status", "status", { cf: "pay" }]],
      sorted(list("booking"), function (a, b) { return String(b.v.day).localeCompare(String(a.v.day)); }).map(function (r) { var b = r.v; return [b.place, b.day, String(b.when || "").split(", ").slice(-1)[0], b.unit, b.who, b.status]; }),
      "Reservations of pool, hall, gym and game room");

    add("Facilities", "Parking slots", [["Slot"], ["Unit"], ["Plan"], ["From", "date"], ["Until", "date"], ["Amount", "money", { sum: 1 }]],
      sorted(list("slot"), function (a, b) { return naturalCompare(a.id, b.id); }).map(function (r) { var s = r.v; return [r.id, s.unit || "Free", s.plan === "month" ? "Monthly" : s.plan === "day" ? "Daily" : "", s.from, s.until, s.unit ? money(s.amount) : ""]; }),
      "Motor parking slots and who rents them");

    add("Facilities", "Parking requests", [["Unit"], ["Household", "text", { w: 26 }], ["Slot"], ["Plan"], ["Days", "int"], ["Amount", "money"], ["Confirmed", "status", { cf: "pay" }]],
      list("request").map(function (r) { var q = r.v; return [q.unit, q.who, q.slot, q.plan === "month" ? "Monthly" : "Daily", Number(q.days || 1), money(q.amount), q.confirmed ? "Yes" : "Waiting"]; }),
      "Parking requests waiting for the office");

    add("Residents", "Grievances and repairs", [["Reported", "date"], ["Unit"], ["Subject", "text", { w: 30 }], ["Details", "text", { w: 44, wrap: 1 }], ["Status", "status", { cf: "grv" }], ["Priority", "status", { cf: "prio" }], ["Assigned to", "text", { w: 22 }], ["Target date", "date"], ["Equipment", "text", { w: 24 }], ["Note", "text", { w: 28, wrap: 1 }], ["Resolved on", "date"], ["Cost", "money", { sum: 1 }], ["What was done", "text", { w: 36, wrap: 1 }]],
      newest(list("grievance")).map(function (r) { var g = r.v; return [created(r.id), g.by || r.unit, g.title, g.body, stageName(g.stage), g.priority || "", g.assignee || "", g.target, g.equipName || "", g.notes || "", g.resolvedOn, g.cost ? money(g.cost) : "", g.completion || ""]; }),
      "Resident concerns with repair assignment, cost and result");

    add("Residents", "Announcements", [["Date", "date"], ["Type", "status", { cf: "ann" }], ["Title", "text", { w: 34 }], ["Status", "status", { cf: "pub" }], ["Message", "text", { w: 64, wrap: 1 }]],
      newest(list("announcement")).map(function (r) { var a = r.v; return [a.date, a.type || "General", a.title, a.status || "Published", a.body]; }),
      "Notices posted to residents");

    var rsvps = list("rsvp");
    add("Residents", "Events", [["Date and time", "text", { w: 24 }], ["Event", "text", { w: 32 }], ["Place", "text", { w: 24 }], ["Residents going", "int"], ["About", "text", { w: 54, wrap: 1 }]],
      newest(list("event")).map(function (r) { var e = r.v; return [e.date, e.title, e.place, rsvps.filter(function (q) { return String(q.v.event) === String(r.id); }).length, e.about]; }),
      "Community events and how many units will join");

    var pr = [];
    pollsAll().forEach(function (p) { var tot = p.options.reduce(function (s, o) { return s + o.votes; }, 0); p.options.forEach(function (o) { pr.push([p.q, p.open ? "Open" : "Closed", p.closes, o.t, o.votes, (tot ? Math.round(o.votes / tot * 100) : 0) + "%"]); }); });
    add("Residents", "Polls", [["Question", "text", { w: 44 }], ["Status", "status", { cf: "poll" }], ["Closes"], ["Option", "text", { w: 30 }], ["Votes", "int"], ["Share of votes", "text", { w: 16 }]], pr, "Poll results, one row per option");

    var hasMaint = list("mtask").length || list("equipment").length || list("staff").length;
    var spent = {};
    if (hasMaint) {
      add("Maintenance", "Maintenance schedule", [["Task", "text", { w: 36 }], ["Type", "text", { w: 28 }], ["Equipment", "text", { w: 24 }], ["Repeats", "text", { w: 16 }], ["Next due", "date"], ["Status", "status", { cf: "sched", w: 22 }], ["Assigned to", "text", { w: 22 }], ["Last done", "date"]],
        sorted(list("mtask"), function (a, b) { return String(a.v.due).localeCompare(String(b.v.due)); }).map(function (r) {
          var t = r.v;
          return [t.title, typeof maintTypeLabel === "function" ? maintTypeLabel(t.kind) : (t.kind === "Compliance" ? "Permit, certificate or test" : "Routine"), t.equipName, t.every, t.due, schedState(t.due), t.assignee || "", t.lastDone];
        }), "Preventive maintenance and permit renewals");
      list("expense").forEach(function (r) { if (r.v.equipId) spent[r.v.equipId] = (spent[r.v.equipId] || 0) + expTotal(r.v); });
      add("Maintenance", "Equipment", [["Equipment", "text", { w: 28 }], ["Category", "text", { w: 18 }], ["Location", "text", { w: 22 }], ["Condition", "status", { cf: "cond", w: 20 }], ["Facility", "text", { w: 18 }], ["Closes facility", "status"], ["Supplier", "text", { w: 24 }], ["Warranty ends", "date"], ["Last service", "date"], ["Spent", "money", { sum: 1, bar: 1 }]],
        sorted(list("equipment"), function (a, b) { return String(a.v.name).localeCompare(String(b.v.name)); }).map(function (r) { var e = r.v; return [e.name, e.category, e.location, e.status, e.facility || "", e.facility ? (e.closes ? "Yes" : "No") : "", e.vendor || "", e.warranty, e.lastService, spent[r.id] || ""]; }),
        "Equipment list with condition, warranty and money spent");
      add("Maintenance", "Maintenance staff", [["Name", "text", { w: 24 }], ["Role", "text", { w: 28 }], ["Phone", "text", { w: 18 }], ["Open repairs", "int"], ["Scheduled tasks", "int"]],
        sorted(list("staff"), function (a, b) { return String(a.v.name).localeCompare(String(b.v.name)); }).map(function (r) {
          return [r.v.name, r.v.role, r.v.phone, list("grievance").filter(function (g) { return g.v.staffId === r.id && !(Number(g.v.stage) >= 2); }).length, list("mtask").filter(function (t) { return t.v.staffId === r.id; }).length];
        }), "Maintenance staff and their workload");
    }

    add("System", "Activity log", [["Date and time", "text", { w: 24 }], ["Area", "text", { w: 18 }], ["What happened", "text", { w: 70 }]],
      newest(list("activity")).map(function (r) { var a = r.v; return [new Date(Number(a.at || r.id)).toLocaleString("en-US"), a.area, a.title]; }),
      "What the administrators did, newest first");

    /* group the sheets by area so related ones sit together */
    var order = GROUPS.map(function (g) { return g[0]; });
    tables.sort(function (a, b) { return order.indexOf(a.group) - order.indexOf(b.group); });
    var sheets = tables.map(tableSheet);

    /* numbers behind the charts */
    var now = new Date(), year = String(now.getFullYear()), c = counts();
    var unpaid = dues.filter(function (r) { return !r.v.paid; });
    var CD = [];
    function months() {
      var out = [], i, d;
      for (i = 5; i >= 0; i--) { d = new Date(now.getFullYear(), now.getMonth() - i, 1); out.push({ key: d.getFullYear() * 12 + d.getMonth(), label: d.toLocaleString("en-US", { month: "short" }) + " " + d.getFullYear() }); }
      return out;
    }
    var mo = months();
    function monthSum(rows, dateOf, amountOf) { return mo.map(function (m) { return rows.reduce(function (s, r) { var d = toDate(dateOf(r)); return s + (d && d.getFullYear() * 12 + d.getMonth() === m.key ? amountOf(r) : 0); }, 0); }); }
    CD.push({ key: "month", title: "Collected and spent per month", head: ["Month", "Collected", "Spent"], fmt: "money", cats: mo.map(function (m) { return m.label; }),
              cols: [monthSum(list("payment"), function (r) { return r.v.date; }, function (r) { return money(r.v.amount); }), monthSum(list("expense"), function (r) { return r.v.date; }, function (r) { return expTotal(r.v); })] });
    var catSum = {};
    list("expense").forEach(function (r) { if (String(r.v.date || "").slice(0, 4) === year) { var k = (r.v.category || "Other").replace(/ and /g, " & "); catSum[k] = (catSum[k] || 0) + expTotal(r.v); } });
    var cats = Object.keys(catSum).sort(function (a, b) { return catSum[b] - catSum[a]; }).slice(0, 8);
    CD.push({ key: "cat", title: "Spending by category (this year)", head: ["Category", "Spent"], fmt: "money", cats: cats, cols: [cats.map(function (k) { return catSum[k]; })] });
    var ds = { Paid: 0, Unpaid: 0, Overdue: 0 };
    dues.forEach(function (r) { ds[duesState(r.v)]++; });
    CD.push({ key: "dues", title: "Dues by status", head: ["Status", "Charges"], fmt: "int", cats: ["Paid", "Unpaid", "Overdue"], cols: [[ds.Paid, ds.Unpaid, ds.Overdue]] });
    var gs = [0, 0, 0];
    list("grievance").forEach(function (r) { gs[Math.min(2, Math.max(0, Number(r.v.stage) || 0))]++; });
    CD.push({ key: "grv", title: "Grievances and repairs by status", head: ["Status", "Reports"], fmt: "int", cats: ["Open", "In progress", "Resolved"], cols: [gs] });
    var places = [], bk = {};
    list("booking").forEach(function (r) { var p = r.v.place || "Other", s = ["Approved", "Pending", "Denied"].indexOf(r.v.status) >= 0 ? r.v.status : "Other"; if (!bk[p]) { bk[p] = {}; places.push(p); } bk[p][s] = (bk[p][s] || 0) + 1; });
    places.sort();
    var bst = ["Approved", "Pending", "Denied", "Other"].filter(function (s) { return places.some(function (p) { return bk[p][s]; }); });
    CD.push({ key: "book", title: "Facility bookings by facility", head: ["Facility"].concat(bst), fmt: "int", cats: places, cols: bst.map(function (s) { return places.map(function (p) { return bk[p][s] || 0; }); }), colors: { Approved: C.green, Pending: C.amber, Denied: C.red, Other: C.gray } });
    if (hasMaint) {
      var ms = [0, 0, 0];
      list("mtask").forEach(function (r) { var n = days(r.v.due); if (n == null) return; ms[n < 0 ? 0 : n <= 7 ? 1 : 2]++; });
      CD.push({ key: "mt", title: "Maintenance tasks by status", head: ["Status", "Tasks"], fmt: "int", cats: ["Overdue", "Due in 7 days", "Scheduled later"], cols: [ms] });
      var cond = {}, cl = [];
      list("equipment").forEach(function (r) { var k = r.v.status || "Unknown"; if (!cond[k]) { cond[k] = 0; cl.push(k); } cond[k]++; });
      CD.push({ key: "eq", title: "Equipment by condition", head: ["Condition", "Equipment"], fmt: "int", cats: cl, cols: [cl.map(function (k) { return cond[k]; })] });
      var st = sorted(list("staff"), function (a, b) { return String(a.v.name).localeCompare(String(b.v.name)); });
      CD.push({ key: "wl", title: "Staff workload", head: ["Staff", "Open repairs", "Scheduled tasks"], fmt: "int", cats: st.map(function (r) { return r.v.name; }),
                cols: [st.map(function (r) { return list("grievance").filter(function (g) { return g.v.staffId === r.id && !(Number(g.v.stage) >= 2); }).length; }), st.map(function (r) { return list("mtask").filter(function (t) { return t.v.staffId === r.id; }).length; })] });
    }

    /* the "Chart data" sheet: small tables the charts read from */
    var cg = new Grid(), cdw = [28, 16, 16, 16, 16, 16], row = 3, byKey = {};
    bannerRows(cg, 6, "Chart data", "The numbers behind the charts on the Overview sheet", true);
    var tHead = sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "left", indent: 1 });
    CD.forEach(function (t) {
      cg.span(row, 0, 5, t.title, sty({ sz: 12, b: 1, color: C.deep, bb: ["medium", C.brand], v: "center" }), false); cg.h[row] = 24;
      t.head.forEach(function (h, i) { cg.put(row + 1, i, h, tHead); });
      t.cats.forEach(function (cat, i) {
        var band = i % 2 === 1, base = { v: "center", fill: band ? C.band : undefined, bb: ["thin", C.line] };
        cg.put(row + 2 + i, 0, cat, sty(Object.assign({ h: "left", indent: 1 }, base)));
        t.cols.forEach(function (col, k) { cg.put(row + 2 + i, 1 + k, col[i], sty(Object.assign({ fmt: FMT[t.fmt], h: "right" }, base))); });
      });
      t.r0 = row; // header row (0-based); data starts at row + 2
      byKey[t.key] = t;
      row += t.cats.length + 4;
    });
    var chartSheetName = "Chart data";
    sheets.push({ name: chartSheetName, grid: cg, widths: cdw, tab: C.gray, freeze: 0, charts: [] });
    count[chartSheetName] = { n: CD.length, info: "Small tables the charts read from", group: "System", unit: "tables" };
    function cref(t, col, whole) { var a = whole ? t.r0 + 2 : t.r0 + 3, b = t.r0 + 2 + t.cats.length; return "'" + chartSheetName + "'!$" + colName(col) + "$" + a + ":$" + colName(col) + "$" + b; }
    function hdrRef(t, col) { return "'" + chartSheetName + "'!$" + colName(col) + "$" + (t.r0 + 2); }
    function mk(key, kind, o) {
      var t = byKey[key]; if (!t) return null;
      var cc = o.colors || {}, nz = t.cats.map(function (_, i) { return true; });
      return chartXml({ kind: kind, title: t.title, cats: t.cats, catRef: cref(t, 0), fmt: o.fmt || (t.fmt === "money" ? K_FMT : N_FMT), legend: o.legend,
        series: t.cols.map(function (col, k) {
          var name = t.head[1 + k], color = (t.colors && t.colors[name]) || (o.colors0 && o.colors0[k]) || PAL[k % PAL.length];
          return { name: name, nameRef: hdrRef(t, 1 + k), ref: cref(t, 1 + k), vals: col, color: color, ptColors: o.pts ? o.pts : undefined };
        }) });
    }

    /* ---------- the Overview dashboard ---------- */
    var g = new Grid(), NC = 12, W = 14;
    var bannerS = function (sz, color, b) { return sty({ sz: sz, b: b ? 1 : undefined, color: color, fill: C.deep, v: "center", h: "left", indent: 2 }); };
    g.span(0, 0, NC - 1, "ResidentHub: all administrator data", bannerS(22, "FFFFFF", 1), false); g.h[0] = 42;
    g.span(1, 0, NC - 1, "City Residences Condominium Corporation", bannerS(12, "DDD9F7"), false); g.h[1] = 22;
    g.span(2, 0, NC - 1, "Exported on " + now.toLocaleString("en-US") + " by " + adminName(), bannerS(10, "BDB6EE"), false); g.h[2] = 22;
    g.h[3] = 10;

    function tile(r, c0, label, value, note, accent, fmt) {
      function ts(extra, pos) { var o = Object.assign({ fill: C.tint, v: "center" }, extra); if (pos === 0) o.bl = ["thick", "FFFFFF"]; if (pos === 2) o.br = ["thick", "FFFFFF"]; return sty(o); }
      [0, 1, 2].forEach(function (p) {
        g.put(r, c0 + p, p === 0 ? label : null, ts({ sz: 9, b: 1, color: C.muted, h: "left", indent: 1, bt: ["thick", accent] }, p));
        g.put(r + 1, c0 + p, p === 0 ? value : null, ts({ sz: 22, b: 1, color: accent, h: "left", indent: 1, fmt: fmt }, p));
        g.put(r + 2, c0 + p, p === 0 ? note : null, ts({ sz: 9, color: C.muted, h: "left", indent: 1 }, p));
      });
      g.merges.push(colName(c0) + (r + 1) + ":" + colName(c0 + 2) + (r + 1), colName(c0) + (r + 2) + ":" + colName(c0 + 2) + (r + 2), colName(c0) + (r + 3) + ":" + colName(c0 + 2) + (r + 3));
      g.h[r] = 22; g.h[r + 1] = 36; g.h[r + 2] = 20;
    }
    var expYear = list("expense").filter(function (r) { return String(r.v.date || "").slice(0, 4) === year; }).reduce(function (s, r) { return s + expTotal(r.v); }, 0);
    var unpaidAmt = unpaid.reduce(function (s, r) { return s + money(r.v.amount); }, 0), overdueN = ds.Overdue;
    var vacant = list("unit").filter(function (r) { return r.v.status === "Vacant"; }).length;
    var admins = (DB.accounts || []).filter(function (a) { return a.role === "admin"; }).length;
    var MON = '"₱"#,##0', waiting = c.bookings + c.parking + c.rentals;
    tile(4, 0, "UNITS", list("unit").length, vacant + " vacant", C.brand);
    tile(4, 3, "RESIDENT ACCOUNTS", residentCount(), admins + " administrator account" + (admins === 1 ? "" : "s"), C.blue);
    tile(4, 6, "UNPAID AMOUNT", unpaidAmt, unpaid.length + " unpaid charges, " + overdueN + " overdue", C.red, MON);
    tile(4, 9, "COLLECTED THIS MONTH", monthEarnings(), "Confirmed payments of this month", C.green, MON);
    g.h[7] = 10;
    tile(8, 0, "EXPENSES THIS YEAR", expYear, list("expense").length + " expense records in total", C.amber, MON);
    tile(8, 3, "OPEN GRIEVANCES", c.grievances, list("grievance").length + " reports in total", C.amber);
    tile(8, 6, "WAITING FOR APPROVAL", waiting, c.bookings + " bookings, " + c.parking + " parking, " + c.rentals + " unit status", C.brand);
    var od = list("mtask").filter(function (r) { var n = days(r.v.due); return n != null && n < 0; }).length, needs = list("equipment").filter(function (r) { return r.v.status !== "Working"; }).length;
    if (hasMaint) tile(8, 9, "OVERDUE MAINTENANCE", od, needs + " equipment need attention", od ? C.red : C.green);
    else tile(8, 9, "ANNOUNCEMENTS", list("announcement").length, "Notices posted to residents", C.blue);
    g.h[11] = 12;

    var secS = sty({ sz: 13, b: 1, color: C.deep, bb: ["medium", C.brand], v: "center" }), charts = [], r = 12;
    function section(title, rowsOfCharts) {
      g.span(r, 0, NC - 1, title, secS, false); g.h[r] = 26; r++;
      var made = rowsOfCharts.filter(function (cs) { return cs[0]; });
      made.forEach(function (cs) { charts.push({ xml: cs[0], a: [cs[1], r, cs[2], r + 14] }); });
      r += 16;
    }
    var cMonth = mk("month", "col", { legend: true, colors0: [C.green, C.amber] });
    section("Money", [[cMonth, 0, 5], [mk("cat", "bar", { colors0: [C.brand] }), 6, 11]]);
    section("Residents and requests", [[mk("dues", "donut", { legend: true, fmt: N_FMT, pts: [C.green, C.amber, C.red] }), 0, 3], [mk("grv", "col", { pts: [C.red, C.blue, C.green] }), 4, 7], [mk("book", "stack", { legend: true }), 8, 11]]);
    if (hasMaint) section("Maintenance", [[mk("mt", "col", { pts: [C.red, C.amber, C.green] }), 0, 3], [mk("eq", "donut", { legend: true, fmt: N_FMT, pts: byKey.eq.cats.map(function (k) { return { Working: C.green, "Needs repair": C.red, "Under maintenance": C.amber }[k] || C.gray; }) }), 4, 7], [mk("wl", "stack", { legend: true, colors0: [C.red, C.blue] }), 8, 11]]);

    // key figures
    var hd = sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "left", indent: 1 });
    g.span(r, 0, NC - 1, "Key figures", secS, false); g.h[r] = 26; r++;
    g.span(r, 0, 3, "Figure", hd); g.span(r, 4, 5, "Value", sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "right" })); g.h[r] = 24; r++;
    var kf = [["Units", list("unit").length], ["Resident accounts", residentCount()], ["Unpaid charges", unpaid.length], ["Unpaid amount", unpaidAmt, "money"], ["Collected this month", monthEarnings(), "money"], ["Expenses this year", expYear, "money"],
              ["Booking requests waiting", c.bookings], ["Open grievances", c.grievances], ["Parking requests waiting", c.parking], ["Unit status to review", c.rentals]];
    if (hasMaint) kf.push(["Overdue maintenance tasks", od], ["Equipment needing attention", needs]);
    kf.forEach(function (k, i) {
      var base = { v: "center", fill: i % 2 ? C.band : undefined, bb: ["thin", C.line] };
      g.span(r, 0, 3, k[0], sty(Object.assign({ h: "left", indent: 1 }, base)));
      g.span(r, 4, 5, k[1], sty(Object.assign({ h: "right", b: 1, fmt: k[2] ? FMT.money : FMT.int }, base)));
      r++;
    });
    r++;

    // contents with links
    g.span(r, 0, NC - 1, "What is in this workbook", secS, false); g.h[r] = 26; r++;
    g.span(r, 0, 2, "Sheet", hd); g.put(r, 3, "Records", sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "right" })); g.span(r, 4, NC - 1, "What it contains", hd); g.h[r] = 24; r++;
    var allSheets = sheets.slice();
    GROUPS.forEach(function (gr) {
      var inGroup = allSheets.filter(function (s) { return count[s.name] && count[s.name].group === gr[0]; });
      if (!inGroup.length) return;
      g.span(r, 0, NC - 1, gr[0], sty({ b: 1, color: gr[1], fill: C.tint, v: "center", h: "left", indent: 1 }), false);
      g.put(r, 0, gr[0], sty({ b: 1, color: gr[1], fill: C.tint, v: "center", h: "left", indent: 1, bl: ["thick", gr[1]] })); r++;
      inGroup.forEach(function (s, i) {
        var base = { v: "center", fill: i % 2 ? C.band : undefined, bb: ["thin", C.line] }, ct = count[s.name];
        g.span(r, 0, 2, s.name, sty(Object.assign({ u: 1, color: C.link, h: "left", indent: 2 }, base))); g.link(r, 0, "'" + s.name + "'!A1");
        g.put(r, 3, ct.n, sty(Object.assign({ fmt: FMT.int, h: "right" }, base)));
        g.span(r, 4, NC - 1, ct.info, sty(Object.assign({ color: C.muted, h: "left", indent: 1 }, base)));
        r++;
      });
    });
    var widths = []; for (var i = 0; i < NC; i++) widths.push(W);
    sheets.unshift({ name: "Overview", grid: g, widths: widths, tab: C.deep, freeze: 0, charts: charts });
    return sheets;
  }

  function schedState(due) {
    var n = days(due);
    return n == null ? "" : n < 0 ? "Overdue by " + (-n) + " day(s)" : n === 0 ? "Due today" : n <= 7 ? "Due in " + n + " day(s)" : "Scheduled";
  }

  /* ---------- save ---------- */
  async function saveBlob(blob, name) {
    if (window.showSaveFilePicker) {
      try {
        var h = await window.showSaveFilePicker({ suggestedName: name, types: [{ description: "Excel workbook", accept: { [XLSX_TYPE]: [".xlsx"] } }] });
        var w = await h.createWritable(); await w.write(blob); await w.close();
        return "picked";
      } catch (e) { if (e && e.name === "AbortError") return "cancel"; }
    }
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob); a.download = name; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000);
    return "download";
  }
  /* ---------- one unit's history as an Excel workbook (template: Overview with key figures and charts, then one sheet per record type) ---------- */
  function unitHistorySheets(unit) {
    resetStyles();
    var S = histSummary(unit), u = S.u, d = S.d, now = new Date(), sheets = [], count = {}, tables = [];
    var ev = histEvents(unit);
    function add(group, name, cols, rows, info) { var t = { group: group, name: name, cols: cols, rows: rows, info: info }; tables.push(t); count[name] = { n: rows.length, info: info, group: group }; }
    var charges = S.charges.slice().sort(function (a, b) { return Number(b.id) - Number(a.id); });
    function paidInfo(dd) { var m = S.pays.filter(function (p) { return p.v.forText === dd.v.note && Math.abs((Number(p.v.amount) || 0) - (Number(dd.v.amount) || 0)) < 0.01; })[0]; return m ? m.v : null; }
    add("Money", "Charges", [["Billed on", "date"], ["Charge", "text", { w: 40 }], ["Due date", "date"], ["Amount", "money", { sum: 1 }], ["Status", "status", { cf: "pay" }], ["Paid through", "text", { w: 20 }], ["Receipt no."]],
      charges.map(function (r) { var c = r.v, p = c.paid ? paidInfo(r) : null; return [billedOn(r.id, c), c.note, c.dueDate, Number(c.amount) || 0, c.paid ? "Paid" : isOverdue(c) ? "Overdue" : "Unpaid", p ? p.method : "", p ? p.receiptNo : ""]; }),
      "Every charge billed to this unit");
    add("Money", "Payments", [["Date", "date"], ["Receipt no."], ["For", "text", { w: 36 }], ["Method", "text", { w: 24 }], ["Reference", "text", { w: 18 }], ["Amount", "money", { sum: 1 }]],
      S.pays.map(function (r) { var p = r.v; return [p.date, p.receiptNo, p.forText, p.method, p.reference, Number(p.amount) || 0]; }), "Payments received, with official receipt numbers");
    var proofs = newest(list("proof")).filter(function (r) { return r.unit === unit; });
    add("Money", "Payment submissions", [["Sent", "date"], ["For", "text", { w: 34 }], ["Method", "text", { w: 22 }], ["Reference", "text", { w: 18 }], ["Amount", "money", { sum: 1 }], ["Status", "status", { cf: "pay" }], ["Posted by", "text", { w: 20 }], ["Note", "text", { w: 36 }]],
      proofs.map(function (r) { var p = r.v; return [new Date(proofSentAt(p)), p.forText, p.method, p.reference, Number(p.amount) || 0, statusText(p.status), p.status === "Confirmed" ? (p.auto ? "Automatic posting" : "Office") : "", p.reason || ""]; }), "What the resident sent, and how it was settled");
    var bookings = list("booking").filter(function (r) { return r.unit === unit; }).sort(function (a, b) { return String(b.v.day).localeCompare(String(a.v.day)); });
    add("Facilities", "Bookings", [["Date", "date"], ["Facility", "text", { w: 26 }], ["When", "text", { w: 34 }], ["Status", "status", { cf: "pay" }]],
      bookings.map(function (r) { return [r.v.day, r.v.place, r.v.when, r.v.status]; }), "Facility reservations");
    var grs = list("grievance").filter(function (r) { return r.unit === unit; }).sort(function (a, b) { return Number(b.id) - Number(a.id); });
    add("Residents", "Requests and repairs", [["Reported", "date"], ["Title", "text", { w: 34 }], ["Details", "text", { w: 50, wrap: true }], ["Status", "status", { cf: "grv" }], ["Assigned to", "text", { w: 22 }]],
      grs.map(function (r) { var g = r.v; return [created(r.id), g.title, g.body, stageName(g.stage), g.assignee || ""]; }), "Complaints and repair requests");
    var comm = ev.filter(function (e) { return e.cat === "community" && e.kind !== "Booking"; });
    add("Residents", "Community", [["Date", "date"], ["Type"], ["Detail", "text", { w: 50 }], ["Note", "text", { w: 40 }]],
      comm.map(function (e) { return [e.ts ? new Date(e.ts) : "", e.kind, e.title, e.sub]; }), "Event RSVPs and poll participation (not how they voted)");
    var office = ev.filter(function (e) { return e.cat === "office"; });
    add("System", "Office log", [["Date", "date"], ["What the office did", "text", { w: 60 }], ["Area", "text", { w: 18 }]],
      office.map(function (e) { return [e.ts ? new Date(e.ts) : "", e.title, e.sub]; }), "Office activity that mentions this unit");
    add("System", "Timeline", [["Date", "date"], ["Type", "text", { w: 16 }], ["Detail", "text", { w: 44 }], ["More", "text", { w: 50 }], ["Amount", "money"], ["Status", "status", { cf: "pay" }]],
      ev.map(function (e) { return [e.ts ? new Date(e.ts) : "", e.kind, e.title, e.sub, e.amount != null ? e.amount : "", e.chip ? e.chip[0] : ""]; }), "Everything above, in one list, newest first");
    tables.forEach(function (t) { sheets.push(tableSheet(t)); });

    // chart data: billed and paid per month (last 6 months), charges by status
    var mo = []; for (var i = 5; i >= 0; i--) { var m0 = new Date(now.getFullYear(), now.getMonth() - i, 1); mo.push({ key: m0.getFullYear() * 12 + m0.getMonth(), label: m0.toLocaleString("en-US", { month: "short" }) + " " + m0.getFullYear() }); }
    function msum(rows, dateOf, amt) { return mo.map(function (m) { return rows.reduce(function (s2, r) { var dt = toDate(dateOf(r)); return s2 + (dt && dt.getFullYear() * 12 + dt.getMonth() === m.key ? (Number(amt(r)) || 0) : 0); }, 0); }); }
    var st = { Paid: 0, Unpaid: 0, Overdue: 0 }; S.charges.forEach(function (r) { st[r.v.paid ? "Paid" : isOverdue(r.v) ? "Overdue" : "Unpaid"]++; });
    var CD = [
      { title: "Billed and paid per month", head: ["Month", "Billed", "Paid"], fmt: "money", cats: mo.map(function (m) { return m.label; }), cols: [msum(S.charges, function (r) { return billedOn(r.id, r.v); }, function (r) { return r.v.amount; }), msum(S.pays, function (r) { return r.v.date; }, function (r) { return r.v.amount; })] },
      { title: "Charges by status", head: ["Status", "Charges"], fmt: "int", cats: ["Paid", "Unpaid", "Overdue"], cols: [[st.Paid, st.Unpaid, st.Overdue]] }
    ];
    var cg = new Grid(), row = 3, byT = [];
    bannerRows(cg, 4, "Chart data", "The numbers behind the charts on the Overview sheet", true);
    var tHead = sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "left", indent: 1 });
    CD.forEach(function (t) {
      cg.span(row, 0, 3, t.title, sty({ sz: 12, b: 1, color: C.deep, bb: ["medium", C.brand], v: "center" }), false); cg.h[row] = 24;
      t.head.forEach(function (h, k) { cg.put(row + 1, k, h, tHead); });
      t.cats.forEach(function (cat, k) {
        var base = { v: "center", fill: k % 2 ? C.band : undefined, bb: ["thin", C.line] };
        cg.put(row + 2 + k, 0, cat, sty(Object.assign({ h: "left", indent: 1 }, base)));
        t.cols.forEach(function (col, j) { cg.put(row + 2 + k, 1 + j, col[k], sty(Object.assign({ fmt: FMT[t.fmt], h: "right" }, base))); });
      });
      t.r0 = row; byT.push(t); row += t.cats.length + 4;
    });
    sheets.push({ name: "Chart data", grid: cg, widths: [26, 16, 16, 16], tab: C.gray, freeze: 0, charts: [] });
    count["Chart data"] = { n: CD.length, info: "Small tables the charts read from", group: "System" };
    function cref(t, col) { return "'Chart data'!$" + colName(col) + "$" + (t.r0 + 3) + ":$" + colName(col) + "$" + (t.r0 + 2 + t.cats.length); }
    function hdr(t, col) { return "'Chart data'!$" + colName(col) + "$" + (t.r0 + 2); }
    function mk(t, kind, o) { return chartXml({ kind: kind, title: t.title, cats: t.cats, catRef: cref(t, 0), fmt: o.fmt, legend: o.legend, series: t.cols.map(function (col, k) { return { name: t.head[1 + k], nameRef: hdr(t, 1 + k), ref: cref(t, 1 + k), vals: col, color: (o.colors || PAL)[k % (o.colors || PAL).length], ptColors: o.pts }; }) }); }

    // the Overview sheet (the template front page)
    var g = new Grid(), NC = 12, W = 14;
    var bandS = function (sz, color, b) { return sty({ sz: sz, b: b ? 1 : undefined, color: color, fill: C.deep, v: "center", h: "left", indent: 2 }); };
    g.span(0, 0, NC - 1, "Unit history: " + unit, bandS(22, "FFFFFF", 1), false); g.h[0] = 42;
    g.span(1, 0, NC - 1, (u.name && u.name !== "—" ? u.name : "No name yet") + " · " + (u.type || "Owner") + " · " + (u.status || "Occupied"), bandS(12, "DDD9F7"), false); g.h[1] = 22;
    g.span(2, 0, NC - 1, "Exported on " + now.toLocaleString("en-US") + " by " + adminName(), bandS(10, "BDB6EE"), false); g.h[2] = 22; g.h[3] = 10;
    function tile(r, c0, label, value, note, accent, fmt) {
      function ts(extra, pos) { var o = Object.assign({ fill: C.tint, v: "center" }, extra); if (pos === 0) o.bl = ["thick", "FFFFFF"]; if (pos === 2) o.br = ["thick", "FFFFFF"]; return sty(o); }
      [0, 1, 2].forEach(function (p) {
        g.put(r, c0 + p, p === 0 ? label : null, ts({ sz: 9, b: 1, color: C.muted, h: "left", indent: 1, bt: ["thick", accent] }, p));
        g.put(r + 1, c0 + p, p === 0 ? value : null, ts({ sz: 22, b: 1, color: accent, h: "left", indent: 1, fmt: fmt }, p));
        g.put(r + 2, c0 + p, p === 0 ? note : null, ts({ sz: 9, color: C.muted, h: "left", indent: 1 }, p));
      });
      g.merges.push(colName(c0) + (r + 1) + ":" + colName(c0 + 2) + (r + 1), colName(c0) + (r + 2) + ":" + colName(c0 + 2) + (r + 2), colName(c0) + (r + 3) + ":" + colName(c0 + 2) + (r + 3));
      g.h[r] = 22; g.h[r + 1] = 36; g.h[r + 2] = 20;
    }
    var MON = '"₱"#,##0.00';
    tile(4, 0, "TOTAL BILLED", d.billed, S.charges.length + " charges", C.brand, MON);
    tile(4, 3, "PAID", d.paid, (d.billed ? Math.round(d.paid / d.billed * 100) : 0) + "% of what was billed", C.green, MON);
    tile(4, 6, "BALANCE", d.balance, S.open.length + " unpaid, " + S.overdue + " overdue", d.balance ? C.red : C.green, MON);
    tile(4, 9, "LAST PAYMENT", S.last ? Number(S.last.v.amount) || 0 : 0, S.last ? (S.last.v.date || "") + " · " + (S.last.v.method || "") : "No payment yet", C.blue, MON);
    g.h[7] = 12;
    var secS = sty({ sz: 13, b: 1, color: C.deep, bb: ["medium", C.brand], v: "center" }), charts = [], r = 8;
    g.span(r, 0, NC - 1, "Money", secS, false); g.h[r] = 26; r++;
    charts.push({ xml: mk(byT[0], "col", { fmt: K_FMT, legend: true, colors: [C.amber, C.green] }), a: [0, r, 7, r + 14] });
    charts.push({ xml: mk(byT[1], "donut", { fmt: N_FMT, legend: true, pts: [C.green, C.amber, C.red] }), a: [8, r, 11, r + 14] });
    r += 16;
    var hd = sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "left", indent: 1 });
    g.span(r, 0, NC - 1, "About this unit", secS, false); g.h[r] = 26; r++;
    var facts = [["Unit", unit], ["Household / owner", u.name && u.name !== "—" ? u.name : ""], ["Occupancy", (u.type || "Owner") + " · " + (u.status || "Occupied")], ["Contact", u.contact || ""],
      ["Resident account", S.accounts.map(function (a) { return a.email; }).join(", ") || "None yet"], ["Floor area", d.area ? d.area + " sqm" : "Not set"], ["Dues due on", Number(u.dueDay) > 0 ? "Day " + u.dueDay + " of every month" : "Not set"],
      ["Monthly dues", d.monthly || 0, "money"], ["Usage of the unit", usageLabel(u.usage) + (u.usageStatus ? " (" + u.usageStatus + ")" : "")], ["Motor parking", S.slot ? "Slot " + S.slot.id : "None"], ["Open complaints", S.openReq]];
    facts.forEach(function (k, i) {
      var base = { v: "center", fill: i % 2 ? C.band : undefined, bb: ["thin", C.line] };
      g.span(r, 0, 3, k[0], sty(Object.assign({ h: "left", indent: 1, b: 1 }, base)));
      g.span(r, 4, NC - 1, k[1], sty(Object.assign({ h: "left", indent: 1, fmt: k[2] ? FMT.money : undefined }, base)));
      r++;
    });
    r++;
    g.span(r, 0, NC - 1, "What is in this workbook", secS, false); g.h[r] = 26; r++;
    g.span(r, 0, 2, "Sheet", hd); g.put(r, 3, "Records", sty({ b: 1, color: "FFFFFF", fill: C.brand, v: "center", h: "right" })); g.span(r, 4, NC - 1, "What it contains", hd); g.h[r] = 24; r++;
    sheets.forEach(function (sh, i) {
      var ct = count[sh.name]; if (!ct) return;
      var base = { v: "center", fill: i % 2 ? C.band : undefined, bb: ["thin", C.line] };
      g.span(r, 0, 2, sh.name, sty(Object.assign({ u: 1, color: C.link, h: "left", indent: 1 }, base))); g.link(r, 0, "'" + sh.name + "'!A1");
      g.put(r, 3, ct.n, sty(Object.assign({ fmt: FMT.int, h: "right" }, base)));
      g.span(r, 4, NC - 1, ct.info, sty(Object.assign({ color: C.muted, h: "left", indent: 1 }, base)));
      r++;
    });
    var widths = []; for (var w = 0; w < NC; w++) widths.push(W);
    sheets.unshift({ name: "Overview", grid: g, widths: widths, tab: C.deep, freeze: 0, charts: charts });
    return sheets;
  }
  window.exportUnitHistory = async function (unit) {
    try {
      var sheets = unitHistorySheets(unit), slug = String(unit).replace(/[^A-Za-z0-9]+/g, "-").replace(/^-|-$/g, ""), name = "history-" + slug + "-" + dayKey(new Date()) + ".xlsx";
      var how = await saveBlob(makeXlsx(sheets), name);
      if (how === "cancel") return;
      logAct("Unit history exported to Excel, " + unit, "Reports");
      toast(how === "picked" ? "Saved " + name + "." : "Downloaded " + name + ". Find it in your Downloads folder.");
    } catch (e) { toast("Could not create the Excel file: " + (e && e.message || e)); }
  };
  window.__buildUnitHistory = unitHistorySheets; // used by the automatic test
  window.exportAllData = async function () {
    try {
      var sheets = buildSheets(), name = "ResidentHub-all-data-" + dayKey(new Date()) + ".xlsx";
      var blob = makeXlsx(sheets);
      var how = await saveBlob(blob, name);
      if (how === "cancel") return;
      logAct("All data exported to Excel (" + sheets.length + " sheets with charts)", "Reports");
      toast(how === "picked" ? "Saved " + name + "." : "Downloaded " + name + ". Find it in your Downloads folder.");
    } catch (e) { toast("Could not create the Excel file: " + (e && e.message || e)); }
  };
  window.__buildExportSheets = buildSheets; // used by the automatic test
  window.__rhXlsx = { resetStyles: resetStyles, makeXlsx: makeXlsx, tableSheet: tableSheet, saveBlob: saveBlob }; // used by the polls export

  /* ---------- buttons on the page (the real files are not edited) ---------- */
  var origReports = window.viewReports;
  if (origReports) {
    window.viewReports = function () {
      return '<div class="card" style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:16px"><div style="flex:1 1 260px"><b style="font-size:16px">Export all data to Excel</b>' +
        '<p class="hint" style="margin:4px 0 0">One .xlsx file: a dashboard sheet with key figures and charts, then a neatly formatted sheet for every part of the system (units, accounts, dues, payments, expenses, bookings, parking, grievances and repairs, announcements, events, polls, maintenance, equipment, staff and the activity log). You choose where to save it.</p></div>' +
        '<button class="btn primary" onclick="exportAllData()">Download all data (.xlsx)</button></div>' + origReports();
    };
  }
  var origHome2 = window.viewHome;
  window.viewHome = function () {
    return origHome2().replace('<div class="pills-row">', '<div class="pills-row"><button onclick="exportAllData()">Export all data (Excel)</button>');
  };
})();
