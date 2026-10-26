/* ADMIN: Import a list from an Excel (.xlsx) or CSV file, on every page that has a list.
   The administrator chooses a file, the columns are matched by their names (and can be changed), a preview shows what will be
   added and what will be skipped, and one click adds the rows. This replaces typing each row by hand.
   Lists: units, resident accounts, charges, expenses, motor parking slots, announcements, events, facilities, directory contacts,
   maintenance tasks, equipment and staff.
   Loaded by admin.html after maintenance.js. It uses the same helper functions as the pages (put, list, getRow, logAct...). */
(function () {
  if (window.RH_ROLE !== "admin") return;

  /* ---------------------------------------------------------------- small helpers */
  function lc(s) { return String(s == null ? "" : s).trim().toLowerCase(); }
  function nk(s) { return lc(s).replace(/[^a-z0-9]/g, ""); }
  function num(s) { var t = String(s == null ? "" : s).replace(/[₱,\s]|php/gi, ""); var n = parseFloat(t); return isFinite(n) ? n : NaN; }
  function fixPhone(s) { var t = String(s || "").trim(); if (!t) return ""; var d = t.replace(/\D/g, ""); if (/^9\d{9}$/.test(d)) return "0" + d; return t; }
  function validPhone(s) { return /^(\+?63|0)?9\d{9}$/.test(String(s).replace(/[\s-]/g, "")); }
  function pad2(n) { return (n < 10 ? "0" : "") + n; }
  function ymd(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
  // A date typed in many ways, or an Excel date number, as a Date (or null).
  function toDate(v) {
    var s = String(v == null ? "" : v).trim(); if (!s) return null;
    if (/^\d{4,6}(\.\d+)?$/.test(s)) { var n = parseFloat(s); if (n > 20000 && n < 90000) { var u = new Date(Math.round((n - 25569) * 86400000)); return new Date(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate()); } }
    var m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s); if (m) return new Date(+m[1], +m[2] - 1, +m[3]);
    m = /^(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{2,4})$/.exec(s); if (m) { var y = +m[3]; if (y < 100) y += 2000; return new Date(y, +m[1] - 1, +m[2]); }
    var p = parseShort(s); if (p) return p;
    var t = Date.parse(s); return isNaN(t) ? null : new Date(t);
  }
  // A time of day as "HH:MM" (from 6:00, 6 PM, 6:30 pm or an Excel time fraction), or "".
  function toClock(v) {
    var s = lc(v); if (!s) return "";
    if (/^0?\.\d+$|^0\.\d+$/.test(s)) { var mins = Math.round(parseFloat(s) * 1440); return pad2(Math.floor(mins / 60) % 24) + ":" + pad2(mins % 60); }
    var m = /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/.exec(s); if (!m) return "";
    var h = +m[1], mi = m[2] ? +m[2] : 0; if (m[3] === "pm" && h < 12) h += 12; if (m[3] === "am" && h === 12) h = 0;
    if (h > 23 || mi > 59) return ""; return pad2(h) + ":" + pad2(mi);
  }
  function pick(list, v, fallback) {
    var t = nk(v); if (!t) return fallback;
    for (var i = 0; i < list.length; i++) if (nk(list[i]) === t) return list[i];
    for (var j = 0; j < list.length; j++) if (nk(list[j]).indexOf(t) >= 0 || t.indexOf(nk(list[j])) >= 0) return list[j];
    return fallback;
  }
  function skip(why) { return { skip: why }; }
  function unitMatch(t) { var k = unitNorm(t); if (!k) return ""; var all = unitNames(); for (var i = 0; i < all.length; i++) if (unitNorm(all[i]) === k) return all[i]; return ""; }

  /* ---------------------------------------------------------------- reading files */
  // Splits a CSV text into rows (uses a comma, semicolon or tab, whichever the first line uses).
  function csvRows(text) {
    text = String(text).replace(/^\uFEFF/, "");
    var first = text.split(/\r?\n/)[0] || "", best = ",", cnt = -1;
    [",", ";", "\t"].forEach(function (d) { var c = first.split(d).length; if (c > cnt) { cnt = c; best = d; } });
    var rows = [], row = [], cur = "", q = false;
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      if (q) { if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += ch; }
      else if (ch === '"') q = true;
      else if (ch === best) { row.push(cur); cur = ""; }
      else if (ch === "\n" || ch === "\r") { if (ch === "\r" && text[i + 1] === "\n") i++; row.push(cur); cur = ""; rows.push(row); row = []; }
      else cur += ch;
    }
    row.push(cur); rows.push(row);
    return rows;
  }
  async function inflateRaw(bytes) {
    if (typeof DecompressionStream === "undefined") throw new Error("This browser cannot open .xlsx files. Save the sheet as CSV and try again.");
    var ds = new DecompressionStream("deflate-raw"), w = ds.writable.getWriter();
    w.write(bytes); w.close();
    return new Uint8Array(await new Response(ds.readable).arrayBuffer());
  }
  async function unzip(buf) {
    var u = new Uint8Array(buf), dv = new DataView(buf), e = u.length - 22;
    while (e >= 0 && dv.getUint32(e, true) !== 0x06054b50) e--;
    if (e < 0) throw new Error("This is not a valid Excel (.xlsx) file.");
    var n = dv.getUint16(e + 10, true), p = dv.getUint32(e + 16, true), files = {}, dec = new TextDecoder();
    for (var i = 0; i < n; i++) {
      if (dv.getUint32(p, true) !== 0x02014b50) break;
      var nl = dv.getUint16(p + 28, true), xl = dv.getUint16(p + 30, true), cl = dv.getUint16(p + 32, true);
      files[dec.decode(u.subarray(p + 46, p + 46 + nl))] = { method: dv.getUint16(p + 10, true), size: dv.getUint32(p + 20, true), at: dv.getUint32(p + 42, true) };
      p += 46 + nl + xl + cl;
    }
    return {
      files: files,
      text: async function (name) {
        var f = files[name]; if (!f) return null;
        var nl2 = dv.getUint16(f.at + 26, true), xl2 = dv.getUint16(f.at + 28, true), start = f.at + 30 + nl2 + xl2, data = u.subarray(start, start + f.size);
        return dec.decode(f.method === 0 ? data : await inflateRaw(data));
      }
    };
  }
  function colIndex(ref) { var m = /^([A-Z]+)/.exec(ref || ""); if (!m) return 0; var n = 0; for (var i = 0; i < m[1].length; i++) n = n * 26 + (m[1].charCodeAt(i) - 64); return n - 1; }
  async function xlsxRows(buf) {
    var z = await unzip(buf), P = new DOMParser();
    function xml(t) { return P.parseFromString(t, "application/xml"); }
    var shared = [], ss = await z.text("xl/sharedStrings.xml");
    if (ss) Array.prototype.forEach.call(xml(ss).getElementsByTagName("si"), function (si) { shared.push(Array.prototype.map.call(si.getElementsByTagName("t"), function (t) { return t.textContent; }).join("")); });
    var path = "xl/worksheets/sheet1.xml", wb = await z.text("xl/workbook.xml"), rels = await z.text("xl/_rels/workbook.xml.rels");
    if (wb && rels) {
      var sh = xml(wb).getElementsByTagName("sheet")[0];
      var rid = sh && (sh.getAttribute("r:id") || sh.getAttributeNS("http://schemas.openxmlformats.org/officeDocument/2006/relationships", "id"));
      Array.prototype.forEach.call(xml(rels).getElementsByTagName("Relationship"), function (r) {
        if (r.getAttribute("Id") === rid) { var t = r.getAttribute("Target"); path = t.charAt(0) === "/" ? t.slice(1) : "xl/" + t; }
      });
    }
    var sx = await z.text(path);
    if (!sx) { var any = Object.keys(z.files).filter(function (k) { return /^xl\/worksheets\/sheet\d+\.xml$/.test(k); })[0]; sx = any ? await z.text(any) : null; }
    if (!sx) throw new Error("The workbook has no sheet to read.");
    var rows = [];
    Array.prototype.forEach.call(xml(sx).getElementsByTagName("row"), function (r) {
      var out = [];
      Array.prototype.forEach.call(r.getElementsByTagName("c"), function (c) {
        var t = c.getAttribute("t"), v = c.getElementsByTagName("v")[0], val = "";
        if (t === "s") val = v ? (shared[+v.textContent] || "") : "";
        else if (t === "inlineStr") val = Array.prototype.map.call(c.getElementsByTagName("t"), function (x) { return x.textContent; }).join("");
        else val = v ? v.textContent : "";
        out[colIndex(c.getAttribute("r"))] = val;
      });
      for (var i = 0; i < out.length; i++) if (out[i] == null) out[i] = "";
      rows.push(out);
    });
    return rows;
  }
  async function readFile(file) {
    if (file.size > 5 * 1024 * 1024) throw new Error("That file is bigger than 5 MB. Split it into smaller files.");
    var name = lc(file.name), rows;
    if (/\.xlsx$/.test(name)) rows = await xlsxRows(await file.arrayBuffer());
    else if (/\.(csv|txt|tsv)$/.test(name)) rows = csvRows(await file.text());
    else if (/\.xls$/.test(name)) throw new Error("This is an old .xls file. Open it in Excel, choose Save As, and pick Excel Workbook (.xlsx) or CSV.");
    else throw new Error("Choose an Excel (.xlsx) or CSV file.");
    rows = rows.map(function (r) { return r.map(function (c) { return String(c == null ? "" : c).trim(); }); })
      .filter(function (r) { return r.some(function (c) { return c; }); });
    if (rows.length < 2) throw new Error("The file has no rows to import. The first row must be the column names.");
    return rows;
  }

  /* ---------------------------------------------------------------- the lists */
  var FREQ = [["Weekly", 7], ["Every 2 weeks", 14], ["Monthly", 30], ["Every 3 months", 90], ["Every 6 months", 180], ["Yearly", 365]];
  var EQ_STATUS = ["Working", "Needs repair", "Under maintenance"];
  var EQ_CATS = ["Elevator", "Plumbing", "Electrical", "Fire safety", "Pool", "Gym", "Air conditioning", "Security", "Other"];
  function freqOf(t) {
    var s = lc(t); if (!s) return FREQ[2];
    if (/week/.test(s) && /(2|two|bi|fort)/.test(s)) return FREQ[1];
    if (/week/.test(s)) return FREQ[0];
    if (/(quarter|3 ?month|three month)/.test(s)) return FREQ[3];
    if (/(semi|6 ?month|six month|half)/.test(s)) return FREQ[4];
    if (/(year|annual|12 ?month)/.test(s)) return FREQ[5];
    if (/month/.test(s)) return FREQ[2];
    if (/daily|day/.test(s)) return FREQ[0];
    return FREQ[2];
  }
  function cleanType(n) { return String(n || "").replace(/['"\\<>&]/g, "").replace(/\s+/g, " ").trim().slice(0, 40); }

  var SPECS = {
    units: {
      label: "units", file: "units",
      cols: [
        { k: "unit", label: "Unit", req: 1, al: ["unit", "unit no", "unit number", "unit name", "unit #", "room", "room no"] },
        { k: "name", label: "Household or owner", al: ["household", "owner", "resident", "resident owner", "owner name", "name", "full name", "family"] },
        { k: "type", label: "Owner or Tenant", al: ["occupancy", "owner or tenant", "ownership", "type"] },
        { k: "status", label: "Occupied or Vacant", al: ["status", "occupied", "vacancy"] },
        { k: "area", label: "Floor area (sqm)", al: ["floor area", "floor area sqm", "area", "area sqm", "sqm", "square meters"] },
        { k: "contact", label: "Contact number", al: ["contact", "contact number", "mobile", "mobile number", "phone", "cellphone", "tel"] }
      ],
      sample: [["Unit 12A", "Reyes Family", "Owner", "Occupied", "45", "0917 555 0112"]],
      init: function () { var s = {}; unitNames().forEach(function (n) { s[lc(n)] = 1; }); return { have: s }; },
      check: function (v, c) {
        var label = cleanUnitLabel(v.unit); if (!v.unit || label === "Unit") return skip("No unit name");
        if (c.have[lc(label)]) return skip("Already on record");
        c.have[lc(label)] = 1;
        var type = /tenant/i.test(v.type) ? "Tenant" : "Owner", status = /vacant/i.test(v.status) ? "Vacant" : "Occupied";
        var ar = parseFloat(v.area);
        return { rec: { unit: label, name: v.name || "—", type: type, status: status, area: ar > 0 ? ar : "", contact: fixPhone(v.contact) || "—", usage: type === "Tenant" ? "tenant" : "owner" }, show: { unit: label } };
      },
      save: function (r) { return put("unit", r.unit, r.unit, r); }
    },
    accounts: {
      label: "resident accounts", file: "resident-accounts", note: "Each account gets a temporary password. You can download the list of passwords when the import is done; give each one to the resident privately.",
      cols: [
        { k: "name", label: "Full name", req: 1, al: ["full name", "name", "resident", "resident name"] },
        { k: "email", label: "Email address", req: 1, al: ["email", "email address", "e-mail", "gmail"] },
        { k: "phone", label: "Mobile number", al: ["mobile", "mobile number", "phone", "contact", "contact number", "cellphone"] },
        { k: "unit", label: "Unit", req: 1, al: ["unit", "unit no", "unit number", "unit name", "room"] }
      ],
      sample: [["Ana Reyes", "ana.reyes@gmail.com", "0917 555 0112", "Unit 12A"]],
      init: function () { var s = {}; (DB.accounts || []).forEach(function (a) { s[lc(a.email)] = 1; }); return { have: s }; },
      check: function (v, c) {
        if (!v.name) return skip("No name");
        if (!/^\S+@\S+\.\S+$/.test(v.email || "")) return skip("Email is not valid");
        if (c.have[lc(v.email)]) return skip("Email already has an account");
        var ph = fixPhone(v.phone); if (ph && !validPhone(ph)) return skip("Mobile number is not valid");
        var unit = unitMatch(v.unit); if (!v.unit) return skip("No unit"); if (!unit) return skip("Unit is not on record yet (import the units first)");
        c.have[lc(v.email)] = 1;
        return { rec: { name: v.name, email: v.email, phone: ph, unit: unit }, show: { phone: ph, unit: unit } };
      },
      save: async function (r, ctx) {
        var res = await callUsers({ action: "create", name: r.name, email: r.email, phone: r.phone, unit: r.unit });
        (ctx.out = ctx.out || []).push([r.name, r.unit, res.email || r.email, res.password || ""]);
      },
      after: async function () { await loadAccounts(); }
    },
    charges: {
      label: "charges", file: "charges",
      cols: [
        { k: "unit", label: "Unit", req: 1, al: ["unit", "unit no", "unit number", "room"] },
        { k: "amount", label: "Amount (₱)", req: 1, al: ["amount", "charge", "fee", "balance", "total", "price", "due"] },
        { k: "note", label: "Description", al: ["description", "note", "particulars", "for", "charge for", "details"] },
        { k: "due", label: "Due date", al: ["due date", "due", "deadline", "pay by"] }
      ],
      sample: [["Unit 12A", "1500", "Facility damage fee", "Nov 15, 2026"]],
      init: function () { return { have: vals("due").map(function (d) { return d.unit + "|" + lc(d.note) + "|" + d.amount; }) }; },
      check: function (v, c) {
        var unit = unitMatch(v.unit); if (!v.unit) return skip("No unit"); if (!unit) return skip("Unit is not on record");
        var a = num(v.amount); if (!(a > 0)) return skip("Amount is not a number above zero");
        var due = ""; if (v.due) { var d = toDate(v.due); if (!d) return skip("Due date is not understood"); due = shortDate(d); }
        var note = v.note || "Charge", key = unit + "|" + lc(note) + "|" + a;
        if (c.have.indexOf(key) >= 0) return skip("Already added");
        c.have.push(key);
        return { rec: { unit: unit, amount: a, note: note, dueDate: due }, show: { unit: unit, due: due, note: note } };
      },
      save: function (r) { var id = nextId(), u = unitRec(r.unit) || {}; return put("due", id, r.unit, { id: id, unit: r.unit, name: u.name && u.name !== "—" ? u.name : "", amount: r.amount, note: r.note, dueDate: r.dueDate }); }
    },
    payments: {
      label: "payments received", file: "payments-received", note: "Each unit in the file has its unpaid charge marked as paid and a receipt is made. Use it for a list from the bank, GCash or the cashier.",
      cols: [
        { k: "unit", label: "Unit", req: 1, al: ["unit", "unit no", "unit number", "room"] },
        { k: "amount", label: "Amount paid (₱, optional)", al: ["amount", "amount paid", "paid", "payment"] },
        { k: "method", label: "Paid through (optional)", al: ["method", "paid through", "mode", "payment method", "channel"] },
        { k: "reference", label: "Reference no. (optional)", al: ["reference", "reference no", "ref", "ref no", "transaction", "or no"] }
      ],
      sample: [["Unit 12A", "1500", "GCash", "GC-123456"]],
      init: function () { return { used: {} }; },
      check: function (v, c) {
        var unit = unitMatch(v.unit); if (!v.unit) return skip("No unit"); if (!unit) return skip("Unit is not on record");
        var a = v.amount === "" ? 0 : num(v.amount); if (v.amount !== "" && !(a > 0)) return skip("Amount is not a number above zero");
        var dues = list("due").filter(function (r) { return r.v.unit === unit && !r.v.paid && !c.used[r.id]; });
        if (a) { var exact = dues.filter(function (r) { return Number(r.v.amount) === a; }); if (exact.length) dues = exact; }
        dues.sort(function (x, y) { return String(x.id).localeCompare(String(y.id), undefined, { numeric: true }); });
        if (!dues.length) return skip("No unpaid charge for this unit");
        c.used[dues[0].id] = 1;
        return { rec: { dueId: dues[0].id, unit: unit, method: v.method || PAY_OFFICE, reference: v.reference }, show: { amount: String(dues[0].v.amount) } };
      },
      save: async function (r) {
        var row = getRow("due", r.dueId); if (!row || row.value.paid) throw new Error("Already paid");
        var cur = row.value;
        await put("due", r.dueId, row.unit, Object.assign({}, cur, { paid: true }));
        var x = await issuePayment(cur.unit, cur.name || cur.unit, cur.note, r.method, r.reference, cur.amount), qid = nextId();
        await put("proof", qid, cur.unit, { id: qid, unit: cur.unit, payer: cur.name || cur.unit, forText: cur.note, method: r.method, reference: r.reference || "—", amount: cur.amount, date: x.date, status: "Confirmed", receiptNo: x.no, confirmedOn: x.date, direct: true });
      }
    },
    usage: {
      label: "unit status", file: "unit-status",
      cols: [
        { k: "unit", label: "Unit", req: 1, al: ["unit", "unit no", "unit number", "room"] },
        { k: "use", label: "How the unit is used", req: 1, al: ["status", "usage", "use", "unit status", "how used", "occupancy", "type"] },
        { k: "note", label: "Note (tenant name, platform, business type)", al: ["note", "notes", "remarks", "tenant", "details", "tenant name"] }
      ],
      sample: [["Unit 12A", "Leased", "Tenant: Ana Cruz"], ["Unit 12B", "Short-term rental", "Airbnb"]],
      init: function () { return { seen: {} }; },
      check: function (v, c) {
        var unit = unitMatch(v.unit); if (!v.unit) return skip("No unit"); if (!unit) return skip("Unit is not on record");
        var t = lc(v.use), key = "";
        if (/vacan/.test(t)) key = "vacant"; else if (/short|airbnb|booking/.test(t)) key = "shortterm"; else if (/busin|shop|office/.test(t)) key = "business";
        else if (/renov|repair|construct/.test(t)) key = "renovation"; else if (/leas|tenant|rent/.test(t)) key = "tenant"; else if (/own|occup/.test(t)) key = "owner";
        if (!key) return skip("Status not understood (use Owner, Leased, Short-term rental, Business, Renovation or Vacant)");
        if (c.seen[unit]) return skip("Unit is listed twice"); c.seen[unit] = 1;
        return { rec: { unit: unit, usage: key, note: v.note }, show: { use: USAGE_NAMES[key] } };
      },
      save: async function (r) {
        var u = unitRec(r.unit) || {}, date = shortDate(new Date());
        var next = Object.assign({}, u, { usage: r.usage, usageStatus: (r.usage === "shortterm" || r.usage === "business") ? "approved" : "", usageRemark: "", statusNote: r.note, statusDate: date, status: r.usage === "vacant" ? "Vacant" : "Occupied" });
        if (r.usage !== u.usage) delete next.usageInfo;
        await put("unit", r.unit, r.unit, next);
        var sid = nextId(); await put("statusUpdate", sid, r.unit, { id: sid, unit: r.unit, key: r.usage, note: r.note, date: date, by: "Admin" });
      }
    },
    expenses: {
      label: "expenses", file: "expenses",
      cols: [
        { k: "item", label: "What was bought", req: 1, al: ["item", "what was bought", "description", "particulars", "purchase", "expense"] },
        { k: "price", label: "Price of one (₱)", req: 1, al: ["price", "unit price", "price of one", "cost", "amount", "total"] },
        { k: "qty", label: "Quantity", al: ["quantity", "qty", "pcs", "units"] },
        { k: "date", label: "Date", al: ["date", "date purchased", "purchase date"] },
        { k: "category", label: "Category", al: ["category", "type"] },
        { k: "area", label: "For (area)", al: ["for", "area", "location"] },
        { k: "payee", label: "Store or supplier", al: ["store", "supplier", "payee", "vendor", "paid to"] },
        { k: "receiptNo", label: "Receipt no.", al: ["receipt", "receipt no", "or no", "official receipt"] },
        { k: "note", label: "Note", al: ["note", "remarks"] }
      ],
      sample: [["Floor wax, 5 L", "850", "2", "Oct 20, 2026", "Janitorial and maintenance", "Lobby and common areas", "ABC Hardware", "OR-1234", ""]],
      init: function () { return { have: vals("expense").map(function (e) { return lc(e.item) + "|" + e.date + "|" + e.unitPrice + "|" + e.qty; }) }; },
      check: function (v, c) {
        if (!v.item) return skip("No item");
        var price = num(v.price); if (!(price > 0)) return skip("Price is not a number above zero");
        var qty = v.qty === "" ? 1 : num(v.qty); if (!(qty > 0)) return skip("Quantity is not a number above zero");
        var d = v.date ? toDate(v.date) : new Date(); if (!d) return skip("Date is not understood");
        var rec = { item: v.item, category: pick(EXP_CATS, v.category, "Other"), area: pick(EXP_AREAS, v.area, EXP_AREAS[0]), payee: v.payee, receiptNo: v.receiptNo, note: v.note, qty: qty, unitPrice: price, date: ymd(d) };
        var key = lc(rec.item) + "|" + rec.date + "|" + price + "|" + qty;
        if (c.have.indexOf(key) >= 0) return skip("Already recorded");
        c.have.push(key);
        return { rec: rec, show: { date: rec.date, category: rec.category, area: rec.area } };
      },
      save: function (r) { var eid = nextId(); return put("expense", eid, "__admin", Object.assign({ id: Number(eid) }, r)); }
    },
    slots: {
      label: "motor parking slots", file: "parking-slots",
      cols: [{ k: "name", label: "Slot name", req: 1, al: ["slot", "slot name", "slot no", "slot number", "name", "parking", "number"] }],
      sample: [["M-25"], ["M-26"]],
      init: function () { return { have: {} }; },
      check: function (v, c) {
        var n = v.name.replace(/\s+/g, " ").trim(); if (!n) return skip("No slot name");
        if (getRow("slot", n) || c.have[lc(n)]) return skip("Slot already exists");
        c.have[lc(n)] = 1; return { rec: { name: n }, show: {} };
      },
      save: function (r) { return put("slot", r.name, "", { id: r.name }); }
    },
    announcements: {
      label: "announcements", file: "announcements",
      cols: [
        { k: "title", label: "Title", req: 1, al: ["title", "subject", "announcement", "heading"] },
        { k: "body", label: "Message", al: ["message", "body", "details", "content", "text"] },
        { k: "type", label: "Type (General, Maintenance, Warning, Emergency)", al: ["type", "category", "kind"] }
      ],
      sample: [["Water interruption", "No water on Nov 3 from 9 AM to 12 NN for tank cleaning.", "Maintenance"]],
      init: function () { return { have: vals("announcement").map(function (a) { return lc(a.title); }) }; },
      check: function (v, c) {
        if (!v.title) return skip("No title");
        if (c.have.indexOf(lc(v.title)) >= 0) return skip("Same title already posted");
        c.have.push(lc(v.title));
        return { rec: { title: v.title, body: v.body || "—", type: pick(["General", "Maintenance", "Warning", "Emergency"], v.type, "General") }, show: { type: pick(["General", "Maintenance", "Warning", "Emergency"], v.type, "General") } };
      },
      save: function (r) { var id = nextId(); return put("announcement", id, "", { id: id, title: r.title, body: r.body, date: shortDate(new Date()), status: "Published", type: r.type }); }
    },
    events: {
      label: "events", file: "events",
      cols: [
        { k: "title", label: "Event title", req: 1, al: ["title", "event", "event title", "name", "activity"] },
        { k: "date", label: "Date and time", al: ["date", "date and time", "when", "schedule"] },
        { k: "place", label: "Venue", al: ["venue", "place", "where", "location"] },
        { k: "about", label: "Details", al: ["details", "about", "description", "notes"] }
      ],
      sample: [["Christmas party", "Dec 20, 2026 · 6:00 PM", "Function hall", "Bring a dish to share"]],
      init: function () { return { have: vals("event").map(function (e) { return lc(e.title) + "|" + lc(e.date); }) }; },
      check: function (v, c) {
        if (!v.title) return skip("No title");
        var when = v.date, d = /^\d{4,6}(\.\d+)?$/.test(v.date || "") ? toDate(v.date) : null; if (d) when = shortDate(d);
        var key = lc(v.title) + "|" + lc(when || "Date TBD"); if (c.have.indexOf(key) >= 0) return skip("Already on the list");
        c.have.push(key);
        return { rec: { title: v.title, date: when || "Date TBD", place: v.place || "Venue TBD", about: v.about }, show: { date: when || "Date TBD" } };
      },
      save: function (r) { var id = nextId(); return put("event", id, "", { id: Number(id), title: r.title, date: r.date, place: r.place, about: r.about }); }
    },
    facilities: {
      label: "facilities", file: "facilities",
      cols: [
        { k: "name", label: "Facility name", req: 1, al: ["facility", "name", "amenity", "facility name"] },
        { k: "open", label: "Opens (e.g. 6:00 AM)", req: 1, al: ["opens", "open", "opening", "opening time", "from"] },
        { k: "close", label: "Closes (e.g. 8:00 PM)", req: 1, al: ["closes", "close", "closing", "closing time", "to", "until"] },
        { k: "mins", label: "Minutes for one booking", al: ["minutes", "mins", "duration", "booking length", "slot length"] },
        { k: "note", label: "Note for residents", al: ["note", "notes", "remarks", "fee"] }
      ],
      sample: [["Tennis court", "6:00 AM", "9:00 PM", "60", "Bring your own racket"]],
      init: function () { return { have: amenities().map(function (a) { return lc(a.name); }), add: [] }; },
      check: function (v, c) {
        if (!v.name) return skip("No name");
        if (c.have.indexOf(lc(v.name)) >= 0) return skip("Facility already exists");
        var o = toClock(v.open), cl = toClock(v.close); if (!o || !cl) return skip("Opening or closing time is not understood");
        var om = toMin(o), cm = toMin(cl); if (cm <= om) return skip("Closing time must be after opening time");
        var mins = v.mins === "" ? 60 : Math.round(num(v.mins)); if (!(mins >= 15 && mins <= 480)) return skip("A booking must be 15 to 480 minutes");
        if (om + mins > cm) return skip("One booking is longer than the opening hours");
        c.have.push(lc(v.name));
        return { rec: { id: "a" + Date.now() + c.have.length, name: v.name, open: o, close: cl, mins: mins, note: v.note || "" }, show: { open: o, close: cl, mins: String(mins) } };
      },
      saveAll: function (recs) { return put("setting", "amenities", "", { list: amenities().slice().concat(recs) }); }
    },
    directory: {
      label: "directory contacts", file: "directory-contacts",
      cols: [
        { k: "name", label: "Name or office", req: 1, al: ["name", "contact", "office", "department", "who"] },
        { k: "tel", label: "Number", req: 1, al: ["number", "tel", "telephone", "phone", "local", "mobile", "contact number"] },
        { k: "note", label: "Note (hours or what it is for)", al: ["note", "notes", "hours", "details", "description"] }
      ],
      sample: [["Clinic", "Local 150", "Mon to Fri, 9 AM to 4 PM"]],
      init: function () { return { have: directory().contacts.map(function (x) { return lc(x.name) + "|" + nk(x.tel); }) }; },
      check: function (v, c) {
        if (!v.name) return skip("No name"); if (!v.tel) return skip("No number");
        var key = lc(v.name) + "|" + nk(v.tel); if (c.have.indexOf(key) >= 0) return skip("Already in the directory");
        c.have.push(key); return { rec: { name: v.name, note: v.note, tel: v.tel }, show: {} };
      },
      saveAll: function (recs) { var d = directory(); d.contacts = d.contacts.concat(recs); return saveDirectory(d); }
    },
    mtasks: {
      label: "maintenance tasks", file: "maintenance-tasks",
      cols: [
        { k: "title", label: "Task", req: 1, al: ["task", "title", "maintenance task", "job", "work", "activity"] },
        { k: "due", label: "Next due date", req: 1, al: ["next due", "due", "due date", "date", "schedule date"] },
        { k: "every", label: "How often", al: ["frequency", "every", "how often", "interval", "repeat"] },
        { k: "kind", label: "Type (Routine, Compliance or your own)", al: ["type", "kind", "category"] },
        { k: "equip", label: "Equipment", al: ["equipment", "asset", "machine", "for"] },
        { k: "who", label: "Assigned to", al: ["assigned to", "assigned", "staff", "person", "technician", "in charge"] }
      ],
      sample: [["Generator test run", "Nov 10, 2026", "Monthly", "Routine", "Standby generator", "Dante Villanueva"]],
      init: function () { return { have: vals("mtask").map(function (t) { return lc(t.title) + "|" + t.due; }), newTypes: {} }; },
      check: function (v, c) {
        if (!v.title) return skip("No task");
        var d = toDate(v.due); if (!v.due) return skip("No due date"); if (!d) return skip("Due date is not understood");
        var key = lc(v.title) + "|" + ymd(d); if (c.have.indexOf(key) >= 0) return skip("Already scheduled");
        c.have.push(key);
        var f = freqOf(v.every), k = lc(v.kind), kind = "Routine";
        if (/compliance|permit|certificate|test|inspection/.test(k) && !/routine/.test(k)) kind = "Compliance";
        else if (k && !/routine|regular|preventive/.test(k)) kind = cleanType(v.kind) || "Routine";
        var eq = list("equipment").filter(function (e) { return lc(e.v.name) === lc(v.equip); })[0];
        var st = list("staff").filter(function (s) { return lc(s.v.name) === lc(v.who); })[0];
        if (kind !== "Routine" && kind !== "Compliance") c.newTypes[kind] = 1;
        return { rec: { kind: kind, title: v.title, equipId: eq ? eq.id : "", equipName: eq ? eq.v.name : (v.equip || ""), every: f[0], days: f[1], due: ymd(d), staffId: st ? st.id : "", assignee: st ? st.v.name : (v.who || "") }, show: { due: ymd(d), every: f[0], kind: kind } };
      },
      before: async function (c) {
        var have = list("mtype").map(function (r) { return lc(r.v.name); });
        for (var n in c.newTypes) if (have.indexOf(lc(n)) < 0) await put("mtype", String(nextId()), "__admin", { name: n });
      },
      save: function (r) { var id = String(nextId()); return put("mtask", id, "", Object.assign({ id: id }, r)); }
    },
    equipment: {
      label: "equipment", file: "equipment",
      cols: [
        { k: "name", label: "Name", req: 1, al: ["name", "equipment", "asset", "item"] },
        { k: "category", label: "Category", al: ["category", "type"] },
        { k: "location", label: "Location", al: ["location", "where", "area"] },
        { k: "status", label: "Condition (Working, Needs repair, Under maintenance)", al: ["condition", "status"] },
        { k: "vendor", label: "Supplier or service company", al: ["supplier", "vendor", "service company", "contractor"] },
        { k: "warranty", label: "Warranty ends", al: ["warranty", "warranty ends", "warranty until"] },
        { k: "lastService", label: "Last serviced", al: ["last serviced", "last service", "serviced"] }
      ],
      sample: [["Elevator A", "Elevator", "Main lobby", "Working", "Otis Services", "Dec 31, 2027", "Oct 1, 2026"]],
      init: function () { return { have: vals("equipment").map(function (e) { return lc(e.name); }) }; },
      check: function (v, c) {
        if (!v.name) return skip("No name"); if (c.have.indexOf(lc(v.name)) >= 0) return skip("Already on the list");
        c.have.push(lc(v.name));
        var w = v.warranty ? toDate(v.warranty) : null, ls = v.lastService ? toDate(v.lastService) : null;
        var rec = { name: v.name, category: pick(EQ_CATS, v.category, "Other"), location: v.location, status: pick(EQ_STATUS, v.status, "Working"), facility: "", closes: false, vendor: v.vendor, warranty: w ? ymd(w) : "", lastService: ls ? ymd(ls) : "" };
        return { rec: rec, show: { category: rec.category, status: rec.status } };
      },
      save: function (r) { var id = String(nextId()); return put("equipment", id, "__admin", Object.assign({ id: id }, r)); }
    },
    staff: {
      label: "maintenance staff", file: "maintenance-staff",
      cols: [
        { k: "name", label: "Name", req: 1, al: ["name", "staff", "full name", "employee"] },
        { k: "role", label: "Role", al: ["role", "position", "job", "title", "trade"] },
        { k: "phone", label: "Mobile number", al: ["mobile", "phone", "contact", "contact number", "mobile number"] }
      ],
      sample: [["Dante Villanueva", "Electrician", "0917 555 0199"]],
      init: function () { return { have: vals("staff").map(function (s) { return lc(s.name); }) }; },
      check: function (v, c) {
        if (!v.name) return skip("No name"); if (c.have.indexOf(lc(v.name)) >= 0) return skip("Already on the list");
        c.have.push(lc(v.name)); return { rec: { name: v.name, role: v.role || "Maintenance", phone: fixPhone(v.phone) }, show: {} };
      },
      save: function (r) { var id = String(nextId()); return put("staff", id, "__admin", Object.assign({ id: id }, r)); }
    }
  };

  /* ---------------------------------------------------------------- the popup */
  var S = null; // the import in progress

  function headerRow(rows, spec) {
    var best = 0, score = -1;
    for (var i = 0; i < Math.min(rows.length, 8); i++) {
      var sc = 0; rows[i].forEach(function (h) { spec.cols.forEach(function (c) { if (c.al.indexOf(nk(h)) >= 0 || c.al.map(nk).indexOf(nk(h)) >= 0) sc++; }); });
      if (sc > score) { score = sc; best = i; }
    }
    return score > 0 ? best : 0;
  }
  function autoMap(head, spec) {
    var map = {}, used = {};
    spec.cols.forEach(function (c) {
      var als = c.al.map(nk), idx = -1;
      for (var a = 0; a < als.length && idx < 0; a++) head.forEach(function (h, i) { if (idx < 0 && !used[i] && nk(h) === als[a]) idx = i; });
      for (var b = 0; b < als.length && idx < 0; b++) head.forEach(function (h, i) { if (idx < 0 && !used[i] && als[b].length > 2 && nk(h).indexOf(als[b]) >= 0) idx = i; });
      map[c.k] = idx; if (idx >= 0) used[idx] = 1;
    });
    return map;
  }
  // Excel stores dates and times as numbers; show them the way they will be saved.
  function shown(k, val) {
    if (/^(due|date|warranty|lastService)$/.test(k) && /^\d{4,6}(\.\d+)?$/.test(val)) { var d = toDate(val); return d ? shortDate(d) : val; }
    if (/^(open|close)$/.test(k) && /^0?\.\d+$/.test(val)) return toClock(val) || val;
    return val;
  }
  function valuesOf(row) { var v = {}; S.spec.cols.forEach(function (c) { var i = S.map[c.k]; v[c.k] = i >= 0 && row[i] != null ? String(row[i]).trim() : ""; }); return v; }
  function evaluate() {
    var ctx = S.spec.init(); S.ctx = ctx;
    S.results = S.rows.map(function (r) { return S.spec.check(valuesOf(r), ctx); });
  }
  function modalEl() { return document.getElementById("rhImport"); }
  function close(refresh) { var m = modalEl(); if (m) m.remove(); S = null; if (refresh) rhRefresh(true); }

  function draw() {
    var m = modalEl(); if (!m) return;
    var spec = S.spec, box = m.querySelector(".imp-body");
    if (S.done) {
      var d = S.done;
      box.innerHTML = '<div class="imp-done"><h3>' + esc(d.added + " " + (d.added === 1 ? "row" : "rows") + " added") + "</h3><p>" + (d.skipped ? esc(d.skipped + " skipped.") : "Nothing was skipped.") + "</p>" +
        (d.passwords ? '<p>The temporary passwords are shown only now. <b>Download them and give each one to the resident privately.</b></p><button class="btn primary" id="impPw">Download passwords (.csv)</button> ' : "") +
        '<button class="btn" data-close>Close</button></div>';
      var pw = box.querySelector("#impPw"); if (pw) pw.onclick = function () { exportCSV("temporary-passwords.csv", ["Name", "Unit", "Email", "Temporary password"], d.passwords); };
      box.querySelector("[data-close]").onclick = function () { close(true); };
      return;
    }
    if (!S.rows) {
      box.innerHTML = '<p class="hint" style="margin:0 0 12px">Choose an Excel (.xlsx) or CSV file. The first row must have the column names. The columns are matched by name, and you can change the match before importing.' + (spec.note ? " " + esc(spec.note) : "") + '</p>' +
        '<label class="imp-drop"><input type="file" id="impFile" accept=".xlsx,.csv,.txt,.tsv" hidden><b>Choose a file</b><span>or drop it here</span></label>' +
        '<div style="margin-top:12px"><button class="btn" id="impTpl" type="button">Download a template (.csv)</button></div>' + (S.err ? '<div class="formerr" style="margin-top:12px">' + esc(S.err) + "</div>" : "");
      var inp = box.querySelector("#impFile");
      inp.onchange = function () { take(inp.files && inp.files[0]); };
      var drop = box.querySelector(".imp-drop");
      ["dragover", "dragenter"].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add("over"); }); });
      ["dragleave", "drop"].forEach(function (ev) { drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove("over"); }); });
      drop.addEventListener("drop", function (e) { take(e.dataTransfer.files && e.dataTransfer.files[0]); });
      box.querySelector("#impTpl").onclick = function () { exportCSV(spec.file + "-template.csv", spec.cols.map(function (c) { return c.label; }), spec.sample); };
      return;
    }
    var ok = S.results.filter(function (r) { return r.rec; }).length, bad = S.results.length - ok;
    var reasons = {}; S.results.forEach(function (r) { if (r.skip) reasons[r.skip] = (reasons[r.skip] || 0) + 1; });
    var missing = spec.cols.filter(function (c) { return c.req && S.map[c.k] < 0; });
    var mapHtml = spec.cols.map(function (c) {
      return '<label class="imp-map"><span>' + esc(c.label) + (c.req ? ' <b class="req">*</b>' : "") + '</span><select data-k="' + c.k + '"><option value="-1">— not in the file —</option>' +
        S.head.map(function (h, i) { return '<option value="' + i + '"' + (S.map[c.k] === i ? " selected" : "") + ">" + esc(h || "(column " + (i + 1) + ")") + "</option>"; }).join("") + "</select></label>";
    }).join("");
    var cols = spec.cols.filter(function (c) { return S.map[c.k] >= 0; });
    var prev = S.rows.slice(0, 8).map(function (r, i) {
      var v = valuesOf(r), res = S.results[i];
      return "<tr><td>" + (res.rec ? '<span class="chip good">Add</span>' : '<span class="chip warn" title="' + escAttr(res.skip) + '">Skip</span>') + "</td>" +
        cols.map(function (c) { return "<td>" + esc(shown(c.k, v[c.k])) + "</td>"; }).join("") + '<td style="color:var(--muted);font-size:12px">' + esc(res.skip || "") + "</td></tr>";
    }).join("");
    box.innerHTML = '<div class="imp-file"><b>' + esc(S.fileName) + "</b> · " + (S.rows.length) + " rows <button class=\"btn\" id=\"impOther\" type=\"button\" style=\"min-height:30px;padding:0 10px;font-size:12px\">Choose another file</button></div>" +
      '<div class="imp-maps">' + mapHtml + "</div>" +
      (missing.length ? '<div class="formerr">Match the column for: ' + esc(missing.map(function (c) { return c.label; }).join(", ")) + ".</div>" : "") +
      '<div style="overflow:auto;margin-top:10px"><table class="imp-prev"><thead><tr><th></th>' + cols.map(function (c) { return "<th>" + esc(c.label.split(" (")[0]) + "</th>"; }).join("") + "<th></th></tr></thead><tbody>" + prev + "</tbody></table></div>" +
      (S.rows.length > 8 ? '<p class="hint" style="margin:6px 0 0">Showing the first 8 of ' + S.rows.length + " rows.</p>" : "") +
      '<p style="margin:12px 0 0"><b>' + ok + "</b> will be added" + (bad ? ", <b>" + bad + "</b> will be skipped" : "") + ".</p>" +
      (bad ? '<ul class="imp-why">' + Object.keys(reasons).map(function (k) { return "<li>" + esc(reasons[k] + " × " + k) + "</li>"; }).join("") + "</ul>" : "") +
      '<div class="modal-actions"><button class="btn primary" id="impGo" type="button"' + (ok && !missing.length ? "" : " disabled") + ">Add " + ok + " " + (ok === 1 ? "row" : "rows") + '</button><button class="btn" data-close type="button">Cancel</button></div>';
    box.querySelectorAll("select[data-k]").forEach(function (s) { s.onchange = function () { S.map[s.getAttribute("data-k")] = +s.value; evaluate(); draw(); }; });
    box.querySelector("#impOther").onclick = function () { S.rows = null; S.err = ""; draw(); };
    box.querySelector("[data-close]").onclick = function () { close(false); };
    box.querySelector("#impGo").onclick = go;
  }

  async function take(file) {
    if (!file) return;
    try {
      var rows = await readFile(file), hi = headerRow(rows, S.spec);
      S.head = rows[hi]; S.rows = rows.slice(hi + 1); S.fileName = file.name; S.map = autoMap(S.head, S.spec); S.err = "";
      evaluate();
    } catch (e) { S.rows = null; S.err = (e && e.message) || "Could not read that file."; }
    draw();
  }

  async function go() {
    var spec = S.spec, btn = modalEl().querySelector("#impGo"), recs = [];
    S.results.forEach(function (r) { if (r.rec) recs.push(r.rec); });
    btn.disabled = true;
    var added = 0, failed = 0, ctx = { out: null };
    try {
      if (spec.before) await spec.before(S.ctx);
      if (spec.saveAll) { await spec.saveAll(recs); added = recs.length; }
      else {
        for (var i = 0; i < recs.length; i++) {
          btn.textContent = "Adding " + (i + 1) + " of " + recs.length + "…";
          try { await spec.save(recs[i], ctx); added++; } catch (e) { failed++; }
        }
      }
      if (spec.after) await spec.after();
    } catch (e) { toast(errText(e)); }
    var skipped = S.results.length - recs.length + failed;
    logAct("Imported " + added + " " + spec.label + " from " + S.fileName, "Import");
    toast(added + " " + spec.label + " added" + (skipped ? ", " + skipped + " skipped." : "."));
    S.done = { added: added, skipped: skipped, passwords: ctx.out && ctx.out.length ? ctx.out : null };
    draw();
  }

  window.rhImport = function (key) {
    var spec = SPECS[key]; if (!spec) return;
    var old = modalEl(); if (old) old.remove();
    S = { spec: spec, rows: null, err: "" };
    var wrap = document.createElement("div");
    wrap.innerHTML = '<div class="modal-back" id="rhImport"><div class="modal imp-modal" onclick="event.stopPropagation()"><button type="button" class="modal-x" data-close aria-label="Close">×</button><h2>Import ' + esc(spec.label) + '</h2><div class="imp-body"></div></div></div>';
    var veil = wrap.firstChild; document.body.appendChild(veil);
    veil.addEventListener("mousedown", function (e) { if (e.target === veil) close(!!(S && S.done)); });
    veil.querySelector(".modal-x").addEventListener("click", function () { close(!!(S && S.done)); });
    draw();
  };

  /* ---------------------------------------------------------------- the bar at the top of each page */
  var BAR = {
    units: [["units", "Import units"]],
    manage: [["accounts", "Import resident accounts"]],
    fin: [["charges", "Import charges"], ["payments", "Import payments received"]],
    expenses: [["expenses", "Import expenses"]],
    rentals: [["usage", "Import unit status"]],
    parking: [["slots", "Import parking slots"]],
    ann: [["announcements", "Import announcements"], ["events", "Import events"]],
    fac: [["facilities", "Import facilities"]],
    settings: [["directory", "Import directory contacts"]],
    maint: [["mtasks", "Import tasks"], ["equipment", "Import equipment"], ["staff", "Import staff"]]
  };
  var prev = window.view;
  window.view = function () {
    var html = prev(), b = BAR[state.view];
    if (!b) return html;
    return '<div class="card imp-bar"><span class="imp-bar-t"><b>Already have a list?</b> Import it from Excel or CSV instead of typing each row.</span>' +
      b.map(function (x) { return '<button class="btn" type="button" onclick="rhImport(\'' + x[0] + '\')">' + esc(x[1]) + "</button>"; }).join("") + "</div>" + html;
  };
})();
