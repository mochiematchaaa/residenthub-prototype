/* ADMIN: Unit / resident history.
   Everything about one unit in a single view: profile, dues, payments (with receipts), payment submissions, bookings, requests, parking,
   community activity and what the office did. One button exports it all to Excel (see exportUnitHistory in export-all.js).
   Loaded by admin.html after admin-more.js. */
var HIST_PAGE = 10;
var HIST_FILTERS = [["all", "Everything"], ["money", "Dues & payments"], ["requests", "Requests & repairs"], ["community", "Bookings & community"], ["office", "Office log"]];

// Opens the history page for one unit.
function openHistory(unit) { closeModal(); set({ view: "history", histUnit: unit, histFilter: "all", histPage: 0 }); }
function histPickUnit(unit) { set({ histUnit: unit, histFilter: "all", histPage: 0 }); }
function histGoPage(n) { state.histPage = Math.max(0, n); render(); }
function histSetFilter(f) { set({ histFilter: f, histPage: 0 }); }

function histTime(text, fallback) { var d = parseShort(String(text || "")); return d ? d.getTime() : (fallback || 0); }
function histStage(s) { return ["Open", "In progress", "Resolved"][Math.min(2, Math.max(0, Number(s) || 0))]; }
function histTone(status) { return status === "Approved" || status === "Paid" || status === "Confirmed" || status === "Resolved" || status === "Completed" ? "good" : status === "Rejected" || status === "Denied" || status === "Overdue" || status === "Open" ? "bad" : status === "In progress" ? "info" : "warn"; }

// Every record that belongs to the unit, newest first. cat: money, requests, community, office.
function histEvents(unit) {
  var ev = [], label = String(unit);
  list("due").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var d = r.v, od = !d.paid && isOverdue(d), b = billedOn(r.id, d), st = d.paid ? "Paid" : od ? "Overdue" : "Unpaid";
    ev.push({ ts: histTime(b, Number(r.id) > 1e12 ? Number(r.id) : 0), cat: "money", kind: "Charge", title: d.note || "Charge", sub: (b ? "Billed " + b : "") + (d.dueDate ? " · due " + d.dueDate : ""), amount: Number(d.amount) || 0, chip: [st, histTone(st)] });
  });
  list("payment").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var p = r.v;
    ev.push({ ts: histTime(p.date, Number(r.id) > 1e12 ? Number(r.id) : 0) + 1, cat: "money", kind: "Payment", title: "Payment received" + (p.receiptNo ? " · " + p.receiptNo : ""), sub: [p.forText, p.method, p.reference && p.reference !== "—" ? "Ref " + p.reference : ""].filter(Boolean).join(" · "), amount: Number(p.amount) || 0, chip: ["Paid", "good"], receipt: r.id });
  });
  list("proof").filter(function (r) { return r.unit === unit && r.v.status !== "Confirmed"; }).forEach(function (r) {
    var p = r.v;
    ev.push({ ts: proofSentAt(p), cat: "money", kind: "Payment sent", title: "Payment details sent by the resident", sub: [p.forText, p.method, p.reference ? "Ref " + p.reference : "", p.status === "Rejected" && p.reason ? "Reason: " + p.reason : ""].filter(Boolean).join(" · "), amount: Number(p.amount) || 0, chip: [p.status === "Pending" ? "Waiting" : p.status, histTone(p.status)] });
  });
  list("booking").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var b = r.v, m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(b.day || "");
    ev.push({ ts: m ? new Date(+m[1], +m[2] - 1, +m[3]).getTime() : Number(r.id) || 0, cat: "community", kind: "Booking", title: "Booked " + (b.place || "a facility"), sub: b.when || "", chip: [b.status || "Pending", histTone(b.status)] });
  });
  list("grievance").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var g = r.v, st = histStage(g.stage);
    ev.push({ ts: Number(r.id) || 0, cat: "requests", kind: "Complaint", title: g.title || "Complaint", sub: (g.body || "").slice(0, 140) + (g.assignee ? " · Assigned to " + g.assignee : ""), chip: [st, histTone(st)] });
  });
  list("request").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var q = r.v;
    ev.push({ ts: Number(q.at) || 0, cat: "requests", kind: "Parking", title: "Motor parking request" + (q.slot ? " · slot " + q.slot : ""), sub: (q.plan === "month" ? "Monthly" : "By the day") + (q.amount ? " · " + peso(Number(q.amount)) : ""), chip: [q.confirmed ? "Approved" : "Pending", q.confirmed ? "good" : "warn"] });
  });
  list("rsvp").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var e = getRow("event", r.v.event);
    ev.push({ ts: e ? histTime(String(e.value.date || "").split("·")[0], Number(e.id) || 0) : 0, cat: "community", kind: "Event", title: "Going to " + (e ? e.value.title : "an event"), sub: e ? String(e.value.date || "") : "", chip: ["Going", "good"] });
  });
  list("vote").filter(function (r) { return r.unit === unit; }).forEach(function (r) {
    var p = getRow("poll", r.v.poll), at = r.v.at ? new Date(r.v.at).getTime() : (p ? Number(p.id) : 0);
    ev.push({ ts: at || 0, cat: "community", kind: "Poll", title: "Voted in " + (p ? (p.value.question || "a poll").replace(/<[^>]+>/g, "") : "a poll"), sub: "Participation only. How they voted is not shown.", chip: ["Voted", "good"] });
  });
  list("activity").filter(function (r) { return String(r.v.title || "").indexOf(label) >= 0; }).forEach(function (r) {
    ev.push({ ts: Number(r.v.at) || Number(r.id) || 0, cat: "office", kind: "Office", title: r.v.title, sub: r.v.area || "", chip: null });
  });
  return ev.sort(function (a, b) { return b.ts - a.ts; });
}

// A short summary of the unit, used by the page and the Excel export.
function histSummary(unit) {
  var u = unitRec(unit) || {}, d = unitDues(unit), pays = list("payment").filter(function (r) { return r.unit === unit; }).sort(function (a, b) { return histTime(b.v.date) - histTime(a.v.date); });
  var charges = list("due").filter(function (r) { return r.unit === unit; }), open = charges.filter(function (r) { return !r.v.paid; });
  return { u: u, d: d, pays: pays, charges: charges, open: open, overdue: open.filter(function (r) { return isOverdue(r.v); }).length, last: pays[0] || null,
    openReq: list("grievance").filter(function (r) { return r.unit === unit && !(Number(r.v.stage) >= 2); }).length,
    slot: list("slot").filter(function (r) { return r.v.unit === unit; })[0] || null,
    accounts: DB.accounts.filter(function (a) { return a.role === "resident" && a.unit === unit; }) };
}


/* ---------- resident record (profile): the details the office keeps for a unit. Editing saves on the unit, and the resident sees it on their dashboard ---------- */
function recLines(text) { return String(text || "").split(/\n+/).map(function (x) { return x.trim(); }).filter(Boolean); }
function recList(text, empty) { var l = recLines(text); return l.length ? l.map(function (x) { return "<div>" + esc(x) + "</div>"; }).join("") : '<span style="color:var(--muted);font-weight:500">' + (empty || "Not recorded") + "</span>"; }
function recVal(v, empty) { return v ? esc(v) : '<span style="color:var(--muted);font-weight:500">' + (empty || "Not recorded") + "</span>"; }
// The "Resident record" card: view mode, with an Edit record button.
function recordCardHtml(unit) {
  var u = unitRec(unit) || {}, acc = accountOfUnit(unit), upd = Number(u.profileUpdated) || 0;
  var sec = function (title, body) { return '<div class="rec-sec"><h3>' + title + "</h3>" + body + "</div>"; };
  var kv = function (k, v) { return '<div><label>' + k + "</label><b>" + v + "</b></div>"; };
  return '<div class="card rec"><div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;align-items:flex-start"><div><h2 style="font-size:19px;margin:0">Resident record</h2><p class="hint" style="margin:2px 0 0">' +
    (upd ? "Last updated " + esc(shortDate(new Date(upd))) + (u.profileBy ? " by " + esc(u.profileBy) : "") + "." : "Not filled in yet.") + ' What you save here is shown to the resident on their dashboard.</p></div><button class="btn primary" onclick="recordForm(\'' + escAttr(unit) + '\')">Edit record</button></div>' +
    '<div class="rec-grid">' +
    sec("Resident", kv("Name", recVal(u.name && u.name !== "—" ? u.name : "")) + kv("Occupancy", esc(u.type || "Owner")) + kv("Mobile", recVal(u.contact && u.contact !== "—" ? u.contact : "")) + kv("Email", recVal(u.email || (acc && acc.email) || "")) + kv("Moved in", recVal(u.moveIn ? usageDate(u.moveIn) : "")) + kv("Sign-in account", acc ? esc(acc.email) : "None yet")) +
    sec("Household", kv("People living here", recVal(u.residents ? String(u.residents) : "")) + kv("Members", recList(u.members)) + kv("Pets", recVal(u.pets, "None recorded"))) +
    sec("Emergency contact", kv("Name", recVal(u.emergencyName)) + kv("Relationship", recVal(u.emergencyRelation)) + kv("Number", recVal(u.emergencyPhone))) +
    sec("Vehicles and notes", kv("Vehicles", recList(u.vehicles, "None recorded")) + kv("Note for the resident", recVal(u.noteResident, "None")) + kv("Private office note", recVal(u.noteOffice, "None"))) +
    "</div></div>";
}
function recordForm(unit) {
  var u = unitRec(unit) || {}, acc = accountOfUnit(unit);
  openForm({
    title: "Resident record · " + unit,
    intro: "Keep the household details up to date. Everything except the private office note is shown to the resident on their dashboard.",
    fields: [
      { name: "name", label: "Resident / household name", value: u.name && u.name !== "—" ? u.name : "" },
      { name: "type", label: "Occupancy", type: "select", options: ["Owner", "Tenant"], value: u.type || "Owner" },
      { name: "contact", label: "Mobile number", value: u.contact && u.contact !== "—" ? u.contact : "" },
      { name: "email", label: "Email address", type: "email", value: u.email || (acc ? acc.email : "") },
      { name: "moveIn", label: "Moved in on", type: "date", value: u.moveIn || "" },
      { name: "residents", label: "How many people live here", type: "number", step: "1", value: u.residents || "" },
      { name: "members", label: "Household members (one per line, e.g. Ana Reyes, spouse)", type: "textarea", value: u.members || "" },
      { name: "pets", label: "Pets", value: u.pets || "", placeholder: "e.g. 1 dog" },
      { name: "emergencyName", label: "Emergency contact name", value: u.emergencyName || "" },
      { name: "emergencyRelation", label: "Relationship", value: u.emergencyRelation || "", placeholder: "e.g. Sister" },
      { name: "emergencyPhone", label: "Emergency contact number", value: u.emergencyPhone || "" },
      { name: "vehicles", label: "Vehicles (one per line, e.g. Motorcycle · ABC 1234)", type: "textarea", value: u.vehicles || "" },
      { name: "noteResident", label: "Note shown to the resident", type: "textarea", value: u.noteResident || "" },
      { name: "noteOffice", label: "Private office note (the resident does not see this)", type: "textarea", value: u.noteOffice || "" }
    ],
    submit: "Save record",
    onSubmit: async function (d) {
      var res = d.residents === "" || d.residents == null ? "" : parseInt(d.residents, 10);
      if (res !== "" && !(res >= 0 && res <= 99)) return { error: "Enter how many people live in the unit, e.g. 3." };
      var old = unitRec(unit) || {}, me = (DB.user && (DB.user.name || DB.user.email)) || "the office";
      await put("unit", unit, unit, Object.assign({}, old, {
        unit: unit, name: String(d.name || "").trim() || "—", type: d.type, contact: String(d.contact || "").trim() || "—", email: String(d.email || "").trim(), moveIn: d.moveIn || "",
        residents: res, members: String(d.members || "").trim(), pets: String(d.pets || "").trim(), emergencyName: String(d.emergencyName || "").trim(), emergencyRelation: String(d.emergencyRelation || "").trim(),
        emergencyPhone: String(d.emergencyPhone || "").trim(), vehicles: String(d.vehicles || "").trim(), noteResident: String(d.noteResident || "").trim(), noteOffice: String(d.noteOffice || "").trim(),
        profileUpdated: Date.now(), profileBy: me
      }));
      logAct("Resident record updated, " + unit, "Units");
      toast("Resident record saved. " + unit + " will see it on their dashboard.");
    }
  });
}

function viewHistory() {
  var units = sortedUnits();
  if (!units.length) return emptyCard("No units yet. Add a unit first.");
  if (!state.histUnit || !unitRec(state.histUnit)) state.histUnit = units[0].id;
  var unit = state.histUnit, q = (state.histQ || "").trim();
  var shown = units.filter(function (r) { return !q || matchesSearch([r.id, r.v.name, r.v.contact, r.v.type].join(" "), q); });
  var listHtml = shown.map(function (r) {
    var bal = balanceFor(r.id);
    return '<button type="button" class="hist-u ' + (r.id === unit ? "on" : "") + '" onclick="histPickUnit(\'' + escAttr(r.id) + '\')"><span class="hist-av">' + esc(String(r.id).replace(/^Unit\s*/i, "")) + '</span><span class="hist-un"><b>' + esc(r.id) + "</b><small>" + esc(r.v.name && r.v.name !== "—" ? r.v.name : "No name yet") + "</small></span>" + (bal ? '<span class="chip warn">' + peso(bal) + "</span>" : '<span class="chip good">Settled</span>') + "</button>";
  }).join("") || '<p class="hint" style="padding:12px">No unit matches.</p>';

  var S = histSummary(unit), u = S.u, d = S.d, ev = histEvents(unit);
  var counts = {}; HIST_FILTERS.forEach(function (f) { counts[f[0]] = f[0] === "all" ? ev.length : ev.filter(function (e) { return e.cat === f[0]; }).length; });
  var f = state.histFilter || "all", rows = ev.filter(function (e) { return f === "all" || e.cat === f; });
  var pages = Math.max(1, Math.ceil(rows.length / HIST_PAGE)), pg = Math.min(Math.max(0, state.histPage || 0), pages - 1);
  var year = new Date().getFullYear(), now = new Date();
  var bars = [];
  for (var i = 5; i >= 0; i--) {
    var m = new Date(now.getFullYear(), now.getMonth() - i, 1), key = m.getFullYear() * 12 + m.getMonth();
    bars.push({ label: MONTHS[m.getMonth()], value: Math.round(S.pays.filter(function (r) { return monthOf(r.v.date) === key; }).reduce(function (s, r) { return s + (Number(r.v.amount) || 0); }, 0)), tone: i === 0 ? "pink" : "yellow" });
  }
  var paidShare = d.billed ? Math.round(d.paid / d.billed * 100) : 0;
  var tile = function (label, value, note, cls) { return '<div class="hist-tile ' + (cls || "") + '"><span>' + label + "</span><b>" + value + "</b><small>" + note + "</small></div>"; };

  var profile = '<div class="card hist-profile"><div class="hist-ph"><span class="hist-av big">' + esc(String(unit).replace(/^Unit\s*/i, "")) + '</span><div style="flex:1;min-width:200px"><h2 style="font-size:24px">' + esc(unit) + " · " + esc(u.name && u.name !== "—" ? u.name : "No name yet") + '</h2><div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px"><span class="chip">' + esc(u.type || "Owner") + '</span><span class="chip ' + (u.status === "Vacant" ? "warn" : "good") + '">' + esc(u.status || "Occupied") + '</span><span class="chip info">' + esc(usageLabel(u.usage)) + "</span>" + (S.overdue ? '<span class="chip bad">' + S.overdue + " overdue</span>" : "") + '</div></div>' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn primary" onclick="exportUnitHistory(\'' + escAttr(unit) + '\')">Export to Excel</button><button class="btn" onclick="unitForm(\'' + escAttr(unit) + '\')">Edit unit</button><button class="btn" onclick="set({view:\'fin\',finTab:\'pay\',payUnit:\'' + escAttr(unit) + '\'})">Record payment</button></div></div>' +
    '<div class="hist-kv"><div><label>Contact</label><b>' + esc(u.contact || "—") + '</b></div><div><label>Account</label><b>' + (S.accounts.length ? S.accounts.map(function (a) { return esc(a.email) + (a.suspended ? " (suspended)" : !a.contact_verified_at ? " (not verified yet)" : ""); }).join("<br>") : "No account yet") + '</b></div><div><label>Floor area</label><b>' + (d.area ? d.area + " sqm" : "Not set") + '</b></div><div><label>Dues due on</label><b>' + (Number(u.dueDay) > 0 ? "Day " + u.dueDay + " of every month" : "Not set") + '</b></div><div><label>Monthly dues</label><b>' + (d.monthly ? peso(d.monthly) : "—") + '</b></div><div><label>Parking</label><b>' + (S.slot ? "Slot " + esc(S.slot.id) : "None") + "</b></div>" + (u.statusNote ? '<div style="grid-column:1/-1"><label>Unit note</label><b>' + esc(u.statusNote) + "</b></div>" : "") + "</div></div>";

  var tiles = '<div class="hist-tiles">' + tile("Total billed", peso(d.billed), S.charges.length + " charge" + (S.charges.length === 1 ? "" : "s")) + tile("Paid", peso(d.paid), paidShare + "% of what was billed", "good") + tile("Balance", peso(d.balance), S.open.length ? S.open.length + " unpaid" + (S.overdue ? ", " + S.overdue + " overdue" : "") : "All settled", d.balance ? "warn" : "good") +
    tile("Last payment", S.last ? peso(Number(S.last.v.amount) || 0) : "—", S.last ? esc(S.last.v.date || "") + " · " + esc(S.last.v.method || "") : "No payment yet") + tile("Open requests", String(S.openReq), "Complaints and repairs not resolved yet") + "</div>";

  var charts = '<div class="hist-charts"><div class="card"><h2 style="font-size:17px">Payments by month</h2><p class="hint" style="margin:2px 0 8px">Money this unit paid in the last 6 months</p>' + barChart(bars, "₱") + '</div><div class="card"><h2 style="font-size:17px">Billed and paid</h2><p class="hint" style="margin:2px 0 12px">Share of the billed amount that was paid</p><div class="hist-meter"><i style="width:' + paidShare + '%"></i></div><div style="display:flex;justify-content:space-between;font-size:13px;margin:8px 0 14px"><span><b>' + peso(d.paid) + "</b> paid</span><span><b>" + peso(d.balance) + "</b> left</span></div>" +
    ["Paid", "Unpaid", "Overdue"].map(function (st) { var n = S.charges.filter(function (r) { var o = !r.v.paid && isOverdue(r.v); return st === "Paid" ? r.v.paid : st === "Overdue" ? o : (!r.v.paid && !o); }).length; return '<div class="hist-row"><span class="chip ' + histTone(st) + '">' + st + "</span><b>" + n + "</b></div>"; }).join("") + "</div></div>";

  var chips = '<div class="filters" style="margin:0 0 6px">' + HIST_FILTERS.map(function (x) { return '<button class="' + (f === x[0] ? "active" : "") + '" onclick="histSetFilter(\'' + x[0] + '\')">' + x[1] + " (" + counts[x[0]] + ")</button>"; }).join("") + "</div>";
  var tl = rows.slice(pg * HIST_PAGE, (pg + 1) * HIST_PAGE).map(function (e) {
    var dt = e.ts ? new Date(e.ts) : null;
    return '<div class="hist-ev ' + e.cat + '"><div class="hist-date">' + (dt ? "<b>" + dt.getDate() + "</b><span>" + MONTHS[dt.getMonth()] + " " + dt.getFullYear() + "</span>" : "<span>—</span>") + '</div><span class="hist-dot"></span><div class="hist-body"><div class="hist-kind">' + esc(e.kind) + "</div><b>" + esc(e.title) + "</b>" + (e.sub ? "<small>" + esc(e.sub) + "</small>" : "") + '</div><div class="hist-side">' + (e.amount != null ? "<b>" + peso(e.amount) + "</b>" : "") + (e.chip ? '<span class="chip ' + e.chip[1] + '">' + esc(e.chip[0]) + "</span>" : "") + (e.receipt ? '<button class="btn" style="min-height:30px;padding:0 10px;font-size:12px" onclick="receiptFor(\'payment\',\'' + escAttr(e.receipt) + '\')">Receipt</button>' : "") + "</div></div>";
  }).join("") || '<p class="hint" style="padding:16px 4px;margin:0">Nothing on record for this filter.</p>';
  var timeline = '<div class="card"><div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;align-items:baseline"><h2>Everything on record</h2><span class="hint" style="margin:0">Newest first. Receipts can be downloaded from here.</span></div><div style="margin-top:12px">' + chips + "</div>" + tl + (rows.length > HIST_PAGE ? pagerHtml(rows.length, pg, HIST_PAGE, "histGoPage") : "") + "</div>";

  return '<div class="hist-grid"><aside class="hist-left card"><input type="search" id="histSearch" value="' + escAttr(state.histQ || "") + '" oninput="set({histQ:this.value})" placeholder="Search unit or resident..." autocomplete="off"><div class="hist-ul">' + listHtml + '</div></aside><div class="hist-main">' + profile + recordCardHtml(unit) + tiles + charts + timeline + "</div></div>";
}
