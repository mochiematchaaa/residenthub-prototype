/* Administrator dashboard — layout, home, units, facility, announcements and polls.
   Real data from Supabase (see core.js). More pages are in admin-more.js. */

var state = {
  authed: false, view: "home", darkMode: false,
  bellOpen: false, bellSeen: false,
  unitSearch: "", facIdx: 0,
  newAnnTitle: "", newAnnBody: "", newAnnType: "General",
  newPollQ: "", newPollOpts: "", pollFilter: "open",
  finFilter: "unpaid", finQ: "", finPage: 0, payUnit: "", payDues: [], payDate: "", payMethod: "", payRef: "", duesDraft: null, motorDraft: null, dailyDraft: null, logPage: 0,
  expMonth: "", expDay: "",
  manage: { name: "", email: "", phone: "", unit: "" }, manageSearch: "", manageErr: ""
};
try { state.darkMode = localStorage.getItem("rh_dark") === "1"; } catch (e) { /* storage blocked */ }

// Called by core.js after sign-in: shows the dashboard.
function rhEnter() { state.authed = true; state.view = "home"; render(); }
// Called by core.js on sign-out: clears the page state.
function rhLeave() { state.authed = false; state.view = "home"; }
// Signs the administrator out.
function doLogout() { signOut(); }
// The administrator's name.
function adminName() { return (DB.profile && (DB.profile.name || DB.profile.email)) || "Administrator"; }
// First word of the name, for the greeting.
function firstName() { return String(adminName()).split(/\s+/)[0]; }
// True for unit usages that the admin must approve (short-term rental, business).
function needsApproval(u) { return u && (u.usage === "shortterm" || u.usage === "business"); }

/* ---------- counts used on several pages ---------- */
function counts() {
  return {
    unpaid: vals("due").filter(function (d) { return !d.paid; }).length,
    grievances: vals("grievance").filter(function (g) { return !(g.stage >= 2); }).length,
    bookings: vals("booking").filter(function (b) { return b.status === "Pending"; }).length,
    rentals: vals("unit").filter(function (u) { return needsApproval(u) && u.usageStatus === "pending"; }).length,
    parking: vals("request").filter(function (r) { return !r.confirmed; }).length,
    proofs: vals("proof").filter(function (p) { return p.status === "Pending"; }).length
  };
}
// Number of active resident accounts.
function residentCount() { return DB.accounts.filter(function (a) { return a.role === "resident" && !a.suspended; }).length; }
// Total payments received this month.
function monthEarnings() {
  var k = thisMonthKey();
  return vals("payment").filter(function (p) { return monthOf(p.date) === k; }).reduce(function (s, p) { return s + Number(p.amount || 0); }, 0);
}
// Color of an announcement type chip (Emergency = red...).
function typeChipClass(t) { return t === "Emergency" ? "bad" : t === "Warning" ? "warn" : t === "Maintenance" ? "info" : ""; }

/* ---------- page frame ---------- */
function titles() {
  return {
    home: [greeting() + ", " + firstName(), homeSummary()],
    units: ["Units & residents", "Maintain unit, occupancy, and resident records."],
    fac: ["Facility booking", "Manage facilities, check availability, and approve or deny reservation requests."],
    expenses: ["Expenses", "Record every purchase of the corporation and review monthly totals."],
    fin: ["Finance", "Dues, charges, payment status and payment history."],
    req: ["Complaints & documents", "Track resident concerns and manage shared files."],
    manage: ["Manage access", "Create resident accounts. Only the administrator can create accounts — there is no public sign-up."],
    ann: ["Announcements", "Publish community announcements and events."],
    rentals: ["Unit status", "Approve what residents declare about their unit, and keep the occupancy registry up to date."],
    polls: ["Polls & voting", "Ask residents what they think and see the results as votes come in."],
    reports: ["Reports", "Collections, occupancy, dues ageing, facility use and requests at a glance."],
    parking: ["Parking", "Motor parking slots, who has one, and requests waiting for approval."],
    log: ["Activity log", "A record of what the administrators did, newest first."],
    settings: ["Settings", "Billing defaults, the resident directory and your preferences."],
    profile: ["My profile", "Your administrator account, recent activity and shortcuts."]
  }[state.view] || ["", ""];
}
// Picks the page function to draw for state.view.
function view() {
  var f = { home: viewHome, units: viewUnits, fac: viewFac, expenses: viewExpenses, fin: viewFin, manage: viewManage, ann: viewAnn,
    rentals: viewRentals, polls: viewPolls, reports: viewReports, parking: viewParking, log: viewLog, settings: viewSettings,
    profile: viewProfile, req: viewReq }[state.view] || viewHome;
  return f();
}

// Draws the whole admin dashboard (menu + current page). Called after every change.
function render() {
  if (!state.authed) return;
  document.documentElement.setAttribute("data-theme", state.darkMode ? "dark" : "light");
  try { localStorage.setItem("rh_dark", state.darkMode ? "1" : "0"); } catch (e) { /* storage blocked */ }
  var app = document.getElementById("app");
  var viewChanged = state.view !== window.__lastView, authChanged = state.authed !== window.__lastAuthed;
  window.__lastView = state.view; window.__lastAuthed = state.authed;
  app.classList.toggle("enter", viewChanged || authChanged);
  app.classList.toggle("enter-shell", authChanged);
  if (viewChanged && !authChanged) window.scrollTo({ top: 0, behavior: "smooth" });
  var isHome = state.view === "home";
  keepFocus(function () {
    mountApp(app, '<div class="shell">' +
      '<aside class="side">' +
      '<div class="side-brand"><img src="logo.jpg" alt=""><span>ResidentHub</span></div>' +
      '<div class="side-label">General</div><nav>' + navBtn("home", "Dashboard") + navBtn("units", "Units") + navBtn("fac", "Facility") + navBtn("ann", "Announcements") + navBtn("polls", "Polls") + "</nav>" +
      '<div class="side-label">Tools</div><nav>' + navBtn("fin", "Finance") +
      '<button type="button" title="Expenses" class="' + (state.view === "expenses" ? "active" : "") + '" onclick="set({view:\'expenses\'})">' + icon("fin") + "<span>Expenses</span></button>" +
      navBtn("reports", "Reports") + navBtn("req", "Complaints") + navBtn("parking", "Parking", parkingFreeTag()) + navBtn("rentals", "Unit status") + "</nav>" +
      '<div class="side-label">Admin</div><nav>' + navBtn("log", "Activity log") + navBtn("manage", "Access") + navBtn("settings", "Settings") + "</nav>" +
      '<div class="side-foot"><button class="side-user" title="Open my profile" onclick="set({view:\'profile\'})"><span class="avatar">' + esc(initials(adminName())) + "</span><span><b>" + esc(adminName()) + "</b><small>Administrator</small></span></button>" +
      '<button class="side-out" onclick="doLogout()">' + icon("logout") + "<span>Log out</span></button></div></aside>" +
      "<main>" +
      '<div class="topline">' + searchBox("Search units, residents, announcements, polls...") +
      '<div class="top-actions"><button class="icon-btn" title="Toggle dark mode" aria-label="Toggle dark mode" onclick="toggleDarkMode()">' + icon(state.darkMode ? "sun" : "moon") + "</button>" + bellHtml() + "</div></div>" +
      '<div class="body ' + (isHome ? "with-aside" : "") + '"><div class="col">' +
      '<div class="pagehead"><p class="kicker">' + todayLabel() + "</p><h1>" + titles()[0] + "</h1><p>" + titles()[1] + "</p></div>" +
      view() + "</div>" + (isHome ? homeAside() : "") + "</div></main></div>");
  });
}

/* small building blocks */
function inputStyle() { return 'style="height:44px;border:1px solid #CFC3A9;border-radius:10px;padding:0 12px;font-size:14px"'; }
// A card that says 'nothing here yet'.
function emptyCard(text) { return '<div class="card" style="text-align:center;color:var(--muted)">' + text + "</div>"; }
// A small card with a label and a big number.
function statCard(label, value) { return '<div class="card"><div class="stat-label">' + esc(label) + '</div><div class="stat-value">' + esc(value) + "</div></div>"; }
// All units in natural order (Unit 2 before Unit 10).
function sortedUnits() { return list("unit").sort(function (a, b) { return naturalCompare(a.id, b.id); }); }
// Just the unit names.
function unitNames() { return sortedUnits().map(function (r) { return r.id; }); }
// The resident account that belongs to a unit.
function accountOfUnit(unit) { return DB.accounts.filter(function (a) { return a.role === "resident" && a.unit === unit; })[0]; }
// Household name of a unit (or the unit name if none).
function whoOf(unit) { var u = unitRec(unit) || {}; return u.name && u.name !== "—" ? u.name : unit; }
// Builds a table from rows; shows a message if there are no rows.
function tableRows(rows, cols, empty) {
  if (!rows.length) return '<div style="padding:22px;text-align:center;color:var(--muted)">' + empty + "</div>";
  return '<table><thead><tr>' + cols.map(function (c) { return "<th>" + c + "</th>"; }).join("") + "</tr></thead><tbody>" + rows.join("") + "</tbody></table>";
}

/* ==========================================================================
   Home
   ========================================================================== */
function homeSummary() {
  var c = counts();
  if (!list("unit").length) return "Welcome. Start by adding your units, then create the resident accounts.";
  if (!c.unpaid && !c.bookings && !c.grievances && !c.proofs) return "Nothing is waiting for you today at City Residences.";
  return c.unpaid + " unpaid dues, " + c.bookings + " booking requests and " + c.grievances + " open complaints are waiting for you today at City Residences.";
}
// The right column of the home page (upcoming events and bookings).
function homeAside() {
  var ev = newest(list("event")).map(function (r) { return [esc(r.v.title), esc(r.v.place || ""), esc(r.v.date || "")]; });
  var bk = newest(list("booking")).filter(function (r) { return r.v.status === "Approved"; })
    .map(function (r) { return [esc(r.v.place) + " booking", esc(r.v.who || r.v.unit), esc(r.v.when || "")]; });
  return asideHtml(ev.concat(bk).slice(0, 4), "Add event", "ann");
}
// PAGE: Home / overview.
function viewHome() {
  var c = counts(), units = list("unit").length;
  var dues = newest(list("due")).slice(0, 12).reverse();
  var maxAmt = Math.max.apply(null, dues.map(function (d) { return Number(d.v.amount) || 0; }).concat([1]));
  var bars = dues.map(function (d) {
    return '<i class="' + (d.v.paid ? "on" : "") + '" style="height:' + (25 + Math.round((Number(d.v.amount) || 0) / maxAmt * 60)) + '%" title="' + escAttr(d.v.unit) + '"></i>';
  }).join("");
  var quick = [["Create Announcement", "ann"], ["New Poll", "polls"], ["Add Finance Charge", "fin"], ["View Reports", "reports"], ["Assign Parking", "parking"], ["My Profile", "profile"], ["Settings", "settings"]];
  var pendBk = newest(list("booking")).filter(function (r) { return r.v.status === "Pending"; }).slice(0, 2);
  var openGr = newest(list("grievance")).filter(function (r) { return !(r.v.stage >= 2); }).slice(0, 2);
  var rows = pendBk.map(function (r, i) { return listRow(1 + i % 2, esc(r.v.place), esc(r.v.who || r.v.unit), esc(String(r.v.when || "").split(",")[0]), "fac", i === 0); })
    .concat(openGr.map(function (r, i) { return listRow(3 + i % 2, esc(r.v.title), "Reported by " + esc(r.v.by || r.unit), "Open", "req", false); }));
  var slots = list("slot"), used = slots.filter(function (s) { return s.v.unit; }).length;
  var openPolls = pollsAll().filter(function (p) { return p.open; }).length;
  var anns = newest(list("announcement")).slice(0, 3);
  var act = newest(list("activity")).slice(0, 4);
  return (!units ? '<div class="card" style="margin-bottom:16px;background:var(--info-bg);color:var(--info-fg)"><b>The system is empty.</b> Nothing is sample data — you decide what goes in. Open <a href="#" onclick="set({view:\'units\'});return false" style="color:inherit;font-weight:700">Units</a> to add each unit (or import a CSV), then create the resident accounts under <a href="#" onclick="set({view:\'manage\'});return false" style="color:inherit;font-weight:700">Access</a>.</div>' : "") +
    '<div class="sc-grid">' +
    summaryCard("yellow", "Community", [[units, "Units", "units"], [residentCount(), "Residents", "manage"], [list("doc").length, "Documents", "req"]], "cross") +
    summaryCard("pink", "Finance", [[peso(monthEarnings()), "Earnings this month", "fin"], [c.unpaid, "Unpaid dues", "fin"]], "heart", bars ? '<div class="bars" title="One bar per recent charge. Solid bars are paid.">' + bars + "</div>" : "") +
    summaryCard("green", "Needs attention", [[c.grievances, "Complaints", "req"], [c.bookings, "Bookings", "fac"], [c.rentals, "Unit status to review", "rentals"]], "triangle") +
    summaryCard("blue", "Community life", [[openPolls, "Open polls", "polls"], [used + "/" + slots.length, "Parking used", "parking"]], "burst") +
    "</div>" +
    '<div class="pills-row">' + quick.map(function (q) { return '<button onclick="set({view:\'' + q[1] + '\'})">' + q[0] + "</button>"; }).join("") + "</div>" +
    '<div class="two-lists"><section><div class="sec-head"><h2>Pending requests</h2><button class="btn-dark sm" onclick="set({view:\'fac\'})">Open requests</button></div>' +
    '<div class="lrows">' + (rows.join("") || '<p class="empty">Nothing is waiting for you. Nice work.</p>') + "</div></section>" +
    '<section class="panel pink"><div class="sec-head"><h2>Announcements</h2><button class="btn-dark sm" onclick="set({view:\'ann\'})">See all</button></div>' +
    (anns.map(function (r) {
      var a = r.v;
      return '<div class="note"><b>' + esc(a.title) + "</b>" + (a.type && a.type !== "General" ? '<span class="chip ' + typeChipClass(a.type) + '">' + esc(a.type) + "</span>" : "") + "<small>" + esc(a.status || "Published") + " · " + esc(a.date) + "</small></div>";
    }).join("") || '<p class="empty">No announcements yet.</p>') + "</section></div>" +
    '<section><div class="sec-head"><h2>Recent activity</h2><button class="btn-dark sm" onclick="set({view:\'log\'})">Full log</button></div>' +
    '<div class="activity">' + (act.map(function (r) { return "<div><b>" + esc(r.v.title) + "</b><small>" + esc(r.v.area || "") + " · " + new Date(Number(r.v.at)).toLocaleString() + "</small></div>"; }).join("") || '<p class="empty">Nothing yet.</p>') + "</div></section>";
}

/* ==========================================================================
   Units
   ========================================================================== */
function usageChipClass(u) { return (u === "shortterm" || u === "business") ? "warn" : u === "tenant" ? "info" : "good"; }
// The usage chip in the Units table.
function usageCellHtml(u) {
  if (!u.usage) return '<span style="color:var(--muted)">—</span>';
  var st = needsApproval(u) ? (u.usageStatus === "approved" ? " · Approved" : u.usageStatus === "rejected" ? " · Rejected" : " · Pending") : "";
  return '<span class="chip ' + usageChipClass(u.usage) + '" title="' + escAttr(u.statusNote || "") + '">' + esc(usageLabel(u.usage)) + st + "</span>";
}
// True if the text contains every word typed in the search box.
function matchesSearch(content, query) {
  var norm = function (v) { return String(v == null ? "" : v).normalize("NFKD").replace(/[̀-ͯ]/g, "").toLocaleLowerCase(); };
  var text = norm(content);
  return norm(query).trim().split(/\s+/).filter(Boolean).every(function (w) { return text.indexOf(w) >= 0; });
}
// PAGE: Units (list, add, import, export).
function viewUnits() {
  var rows = sortedUnits().filter(function (r) {
    var u = r.v, bal = balanceFor(r.id);
    return matchesSearch([r.id, u.name, u.type, u.status, u.contact, usageLabel(u.usage), bal > 0 ? "overdue unpaid dues" : "settled paid dues"].join(" "), state.unitSearch);
  });
  var html = rows.map(function (r) {
    var u = r.v, bal = balanceFor(r.id);
    return '<tr><td style="font-weight:700">' + esc(r.id) + "</td><td>" + esc(u.name || "—") + '</td><td style="color:var(--muted)">' + esc(u.type || "Owner") + '</td><td><span class="chip ' + (u.status === "Vacant" ? "warn" : "good") + '">' + esc(u.status || "Occupied") + '</span></td><td style="color:var(--muted)">' + esc(u.contact || "—") + "</td><td>" + usageCellHtml(u) +
      "</td><td>" + (bal ? peso(bal) : '<span style="color:var(--muted)">—</span>') + '</td><td><button class="btn" style="min-height:34px;padding:0 14px;font-size:12.5px" onclick="showUnit(\'' + escAttr(r.id) + '\')">View</button></td></tr>';
  });
  return '<div class="unit-search-panel"><label for="unitSearchInput">Search units &amp; residents</label>' +
    '<input type="search" id="unitSearchInput" value="' + escAttr(state.unitSearch) + '" oninput="set({unitSearch:this.value})" placeholder="Search unit, resident, contact, status, usage or dues..." autocomplete="off">' +
    '<p>Search any record information. Combine words, such as “Reyes owner” or “vacant overdue”.</p></div>' +
    '<div class="filters unit-actions"><span role="status" style="margin-right:auto;font-size:13px;color:var(--muted)">' + rows.length + " matching " + (rows.length === 1 ? "unit" : "units") + "</span>" +
    '<button class="btn primary" onclick="unitForm(null)">+ Add unit</button>' +
    '<button class="btn" onclick="exportUnits()">Export CSV</button></div>' +
    '<div class="card" style="padding:0;overflow:hidden">' + tableRows(html, ["UNIT", "RESIDENT / OWNER", "OCCUPANCY", "STATUS", "CONTACT", "USAGE", "BALANCE", ""], list("unit").length ? "No units match your search." : "No units yet. Tap “Add unit” or import a CSV.") + "</div>";
}
// Downloads the units as a CSV file.
function exportUnits() {
  exportCSV("units.csv", ["Unit", "Resident/Owner", "Occupancy", "Status", "Contact", "Usage", "Usage details"], sortedUnits().map(function (r) {
    return [r.id, r.v.name || "", r.v.type || "", r.v.status || "", r.v.contact || "", usageLabel(r.v.usage), r.v.statusNote || ""];
  }));
}
// Downloads an empty CSV template for importing units.
function unitsTemplate() { exportCSV("units-template.csv", ["Unit", "Household", "Occupancy", "Status", "Contact"], []); }
// Makes a unit name tidy: 'unit  101' -> 'Unit 101'.
function cleanUnitLabel(s) {
  var t = String(s || "").replace(/[^A-Za-z0-9 \-]/g, "").replace(/\s+/g, " ").trim();
  if (!t) return "";
  if (!/^unit /i.test(t)) t = "Unit " + t;
  return "Unit " + t.slice(5).trim().toUpperCase();
}
// True if a unit with this name already exists.
function unitExists(label) { return unitNames().some(function (k) { return k.toLowerCase() === label.toLowerCase(); }); }
// Popup form to add or edit a unit.
function unitForm(edit) {
  var u = edit ? unitRec(edit) || {} : {};
  openForm({
    title: edit ? "Edit " + edit : "Add unit",
    fields: [
      { name: "unit", label: "Unit name", value: edit || "", placeholder: "e.g. Unit 12A", readonly: !!edit },
      { name: "name", label: "Household / owner name", value: u.name && u.name !== "—" ? u.name : "" },
      { name: "type", label: "Occupancy", type: "select", options: ["Owner", "Tenant"], value: u.type || "Owner" },
      { name: "status", label: "Status", type: "select", options: ["Occupied", "Vacant"], value: u.status || "Occupied" },
      { name: "contact", label: "Contact number", value: u.contact && u.contact !== "—" ? u.contact : "" }
    ],
    onSubmit: async function (d) {
      var label = edit;
      if (!edit) {
        label = cleanUnitLabel(d.unit);
        if (!label || label === "Unit ") return { error: "Enter the unit name, e.g. Unit 12A." };
        if (unitExists(label)) return { error: label + " already exists." };
      }
      var old = edit ? unitRec(edit) || {} : {};
      await put("unit", label, label, Object.assign({}, old, { unit: label, name: d.name || "—", type: d.type, status: d.status, contact: d.contact || "—", usage: old.usage || "owner" }));
      logAct((edit ? "Unit updated: " : "Unit added: ") + label, "Units");
    }
  });
}
// Deletes a unit after confirming.
function removeUnit(id) {
  var hasAcc = !!accountOfUnit(id);
  closeModal();
  confirmBox("Remove " + id + "?", hasAcc ? "This unit still has a resident account. Delete or move that account first." : "Its charges and history stay in the database.", "Remove", async function () {
    if (hasAcc) throw new Error("This unit still has a resident account.");
    await del("unit", id); logAct("Unit removed: " + id, "Units");
  }, true);
}
// Popup with the details of one unit.
function showUnit(unit) {
  var u = unitRec(unit); if (!u) return;
  var bal = balanceFor(unit), acc = accountOfUnit(unit);
  openModal("<h2>" + esc(unit) + "</h2><p>" + esc(u.name || "—") + "</p>" +
    '<div class="kv"><span>Occupancy</span><b>' + esc(u.type || "Owner") + "</b><span>Status</span><b>" + esc(u.status || "Occupied") + "</b><span>Contact</span><b>" + esc(u.contact || "—") +
    "</b><span>Usage</span><b>" + esc(usageLabel(u.usage)) + (needsApproval(u) ? " (" + esc(u.usageStatus || "pending") + ")" : "") + "</b>" +
    (usageInfoRows(u).length ? usageInfoRows(u).map(function (x) { return "<span>" + esc(x[0]) + "</span><b>" + esc(x[1]) + "</b>"; }).join("") : (u.statusNote ? "<span>Note</span><b>" + esc(u.statusNote) + "</b>" : "")) +
    "<span>Dues</span><b>" + (bal ? peso(bal) + " unpaid" : "Settled") + "</b><span>Account</span><b>" + (acc ? esc(acc.email) : "None yet") + "</b></div>" +
    '<div class="modal-actions"><button class="btn primary" onclick="closeModal();unitForm(\'' + escAttr(unit) + '\')">Edit</button>' +
    (acc ? "" : '<button class="btn" onclick="closeModal();set({view:\'manage\',manage:Object.assign(state.manage,{unit:\'' + escAttr(unit) + '\'})})">Create account</button>') +
    '<button class="btn" onclick="closeModal();setUsageForm(\'' + escAttr(unit) + '\')">Change usage</button>' +
    '<button class="btn" style="color:#A02B1D" onclick="removeUnit(\'' + escAttr(unit) + '\')">Remove</button></div>');
}
// Reads CSV text into rows (handles quotes).
function parseCSV(text) {
  var rows = [], row = [], cur = "", q = false;
  text = String(text).replace(/^﻿/, "");
  for (var i = 0; i < text.length; i++) {
    var ch = text[i];
    if (q) {
      if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ",") { row.push(cur); cur = ""; }
    else if (ch === "\n" || ch === "\r") { if (ch === "\r" && text[i + 1] === "\n") i++; row.push(cur); cur = ""; if (row.some(function (c) { return c.trim(); })) rows.push(row); row = []; }
    else cur += ch;
  }
  row.push(cur); if (row.some(function (c) { return c.trim(); })) rows.push(row);
  return rows;
}
// Adds many units from an uploaded CSV file.
function importUnits(input) {
  var file = input.files && input.files[0]; if (!file) return;
  var rd = new FileReader();
  rd.onload = function () {
    act(async function () {
      var rows = parseCSV(rd.result);
      if (rows.length < 2) throw new Error("The file has no rows. Use the template.");
      var head = rows[0].map(function (h) { return h.trim().toLowerCase(); });
      var col = function (names) { for (var i = 0; i < head.length; i++) if (names.indexOf(head[i]) >= 0) return i; return -1; };
      var ci = { unit: col(["unit", "unit name"]), name: col(["household", "name", "owner", "resident", "resident/owner"]), type: col(["occupancy", "type"]), status: col(["status"]), contact: col(["contact", "contact number", "phone"]) };
      if (ci.unit < 0) throw new Error("The file needs a “Unit” column. Use the template.");
      var added = 0, skipped = 0;
      for (var i = 1; i < rows.length; i++) {
        var r = rows[i], label = cleanUnitLabel(r[ci.unit]);
        if (!label || label === "Unit " || unitExists(label)) { skipped++; continue; }
        var get = function (k) { return ci[k] >= 0 ? String(r[ci[k]] || "").trim() : ""; };
        var type = /tenant/i.test(get("type")) ? "Tenant" : "Owner";
        var status = /vacant/i.test(get("status")) ? "Vacant" : "Occupied";
        await put("unit", label, label, { unit: label, name: get("name") || "—", type: type, status: status, contact: get("contact") || "—", usage: type === "Tenant" ? "tenant" : "owner" });
        added++;
      }
      logAct("Units imported: " + added, "Units");
      toast(added + " unit" + (added === 1 ? "" : "s") + " added" + (skipped ? ", " + skipped + " skipped (blank or already there)." : "."));
    });
    input.value = "";
  };
  rd.readAsText(file);
}

/* ==========================================================================
   Facility
   ========================================================================== */
function bookingAt(f, i) {
  var today = dayKey(new Date()), place = (facilities()[f] || {}).name;
  return vals("booking").filter(function (x) { return x.day === today && Number(x.slot) === i && x.place === place && (x.status === "Pending" || x.status === "Approved"); })[0];
}
// PAGE: Facility (booking requests and time slots).
function viewFac() {
  var bookings = newest(list("booking"));
  var order = { Pending: 0, Approved: 1, Denied: 2 };
  bookings.sort(function (a, b) { return (order[a.v.status] != null ? order[a.v.status] : 3) - (order[b.v.status] != null ? order[b.v.status] : 3) || Number(b.id) - Number(a.id); });
  var rows = bookings.map(function (r) {
    var b = r.v;
    return '<tr><td style="font-weight:700">' + esc(b.place) + "</td><td>" + esc(b.unit) + (b.who && b.who !== b.unit ? ' <span style="color:var(--muted)">· ' + esc(b.who) + "</span>" : "") + '</td><td style="color:var(--muted)">' + esc(b.when) + '</td><td><span class="chip ' + (b.status === "Approved" ? "good" : b.status === "Denied" ? "bad" : "warn") + '">' + esc(b.status) + '</span></td><td style="display:flex;gap:6px">' +
      (b.status === "Pending" ? '<button class="btn primary" onclick="setBooking(\'' + escAttr(r.id) + '\',\'Approved\')">Approve</button><button class="btn" onclick="setBooking(\'' + escAttr(r.id) + '\',\'Denied\')">Deny</button>' : "") + "</td></tr>";
  });
  var fl = facilities();
  var manage = '<div class="card" style="margin-bottom:16px"><div style="display:flex;align-items:center;gap:12px;flex-wrap:wrap"><h2 style="font-size:19px;flex-grow:1">Amenities</h2><button class="btn primary" onclick="amenityForm()">+ Add amenity</button></div>' +
    '<p class="hint">Add a new amenity, change its name, opening hours or how long one booking is. Residents see the change straight away.</p>' +
    (fl.length ? '<div style="display:flex;flex-direction:column;gap:8px;margin-top:6px">' + fl.map(function (f) {
      return '<div style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;border-top:1px solid var(--border2);padding-top:10px"><div style="flex-grow:1;min-width:200px"><b>' + esc(f.name) + '</b><div style="font-size:13px;color:var(--muted)">' + esc(f.hours || "Set the hours") + " · " + f.slots.length + " time slot" + (f.slots.length === 1 ? "" : "s") + " of " + (Number(f.mins) || 120) + ' min</div></div>' +
        '<button class="btn" onclick="amenityForm(\'' + escAttr(f.id) + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="removeAmenity(\'' + escAttr(f.id) + '\')">Remove</button></div>';
    }).join("") + "</div>" : '<p class="empty">No amenities yet. Add the first one.</p>') + "</div>";
  return manage + '<div class="facility-today-grid">' + fl.map(function (f, fi) {
    return '<div class="card"><h2>' + esc(f.name) + ' · Availability today</h2><p class="hint">' + esc(f.hours) + " · Select an open slot to close it, or a closed slot to open it</p>" +
      (f.note ? '<p class="hint">' + esc(f.note) + "</p>" : "") + '<div class="slots">' + f.slots.map(function (t, i) {
        var closed = slotClosed(fi, i), bk = bookingAt(fi, i);
        var cls = closed || bk ? "booked" : "open", label = closed ? "Closed" : bk ? "Booked" : "Open";
        return '<button class="slot ' + cls + '" title="' + escAttr(bk ? bk.unit : "") + '" onclick="toggleSlot(' + fi + "," + i + ')"><b>' + esc(t) + "</b><span>" + label + "</span></button>";
      }).join("") + "</div></div>";
  }).join("") + "</div>" +
    '<div class="card" style="padding:0;overflow:hidden;margin-top:16px"><div style="display:flex;align-items:center;padding:14px 18px"><h2 style="font-size:19px;flex-grow:1">Reservation requests</h2><button class="btn" onclick="exportBookings()">Export to Excel (.csv)</button></div>' +
    tableRows(rows, ["FACILITY", "UNIT", "WHEN", "STATUS", ""], "No reservation requests yet.") + "</div>";
}
// Blocks or opens one time slot of a facility.
function toggleSlot(f, i) {
  var bk = bookingAt(f, i);
  if (bk && !slotClosed(f, i)) return toast("Already reserved by " + bk.unit + ". Deny or cancel the booking to free it.");
  act(async function () {
    var today = dayKey(new Date()), cur = setting("blocked");
    var keys = cur.day === today ? (cur.keys || []).slice() : [];
    var k = slotKey(f, i), at = keys.indexOf(k);
    if (at >= 0) keys.splice(at, 1); else keys.push(k);
    await put("setting", "blocked", "", { day: today, keys: keys });
  });
}
/* ---------- amenities ---------- */
function amenityForm(id) {
  var cur = id ? amenities().filter(function (a) { return a.id === id; })[0] : null;
  var a = cur || { name: "", open: "08:00", close: "20:00", mins: 120, note: "" };
  openForm({
    title: cur ? "Edit " + cur.name : "Add amenity",
    intro: "Residents can book one time slot at a time. The slots are made from the opening and closing time and the length of one booking." + (cur ? " Tip: changing the name, hours or booking length does not move requests already made today, so check them under Reservation requests." : ""),
    fields: [
      { name: "name", label: "Name", value: a.name, placeholder: "e.g. Gym, Basketball court, Rooftop deck" },
      { name: "open", label: "Opens at", type: "time", value: a.open },
      { name: "close", label: "Closes at", type: "time", value: a.close },
      { name: "mins", label: "Length of one booking (minutes)", type: "number", value: a.mins, placeholder: "e.g. 60 or 120" },
      { name: "note", label: "Note shown to residents (optional)", type: "textarea", value: a.note || "", placeholder: "e.g. Guests pay a fee. Bring your own towel." }
    ],
    onSubmit: async function (d) {
      var name = String(d.name || "").trim(), mins = Math.round(Number(d.mins));
      if (!name) return { error: "Enter the amenity's name." };
      var o = toMin(d.open), c = toMin(d.close);
      if (o == null || c == null) return { error: "Choose the opening and closing time." };
      if (c <= o) return { error: "The closing time must be after the opening time." };
      if (!(mins >= 15 && mins <= 480)) return { error: "A booking must be between 15 and 480 minutes." };
      if (o + mins > c) return { error: "One booking is longer than the opening hours." };
      var list = amenities().slice();
      if (list.some(function (x) { return x.id !== id && x.name.toLowerCase() === name.toLowerCase(); })) return { error: name + " already exists." };
      var rec = { id: id || "a" + Date.now(), name: name, open: String(d.open).trim(), close: String(d.close).trim(), mins: mins, note: String(d.note || "").trim() };
      if (cur) list = list.map(function (x) { return x.id === id ? rec : x; }); else list.push(rec);
      await put("setting", "amenities", "", { list: list });
      logAct((cur ? "Amenity updated: " : "Amenity added: ") + name, "Facilities");
    }
  });
}
// Removes a facility from the list.
function removeAmenity(id) {
  var a = amenities().filter(function (x) { return x.id === id; })[0]; if (!a) return;
  if (amenities().length <= 1) { toast("Keep at least one amenity so residents can still book."); return; }
  var today = dayKey(new Date());
  var live = vals("booking").filter(function (b) { return b.place === a.name && b.day >= today && (b.status === "Pending" || b.status === "Approved"); }).length;
  confirmBox("Remove " + a.name + "?", (live ? live + " upcoming booking" + (live === 1 ? " is" : "s are") + " still active. " : "") + "Past reservations stay in the list. Residents can no longer book it.", "Remove", async function () {
    await put("setting", "amenities", "", { list: amenities().filter(function (x) { return x.id !== id; }) });
    logAct("Amenity removed: " + a.name, "Facilities");
  }, true);
}
// Approves or declines a booking request.
function setBooking(id, status) {
  var row = getRow("booking", id); if (!row) return;
  act(async function () {
    await put("booking", id, row.unit, Object.assign({}, row.value, { status: status }));
    logAct(row.value.place + " booking " + status.toLowerCase() + ", " + row.value.unit, "Facilities");
  });
}
// Downloads the bookings as CSV.
function exportBookings() {
  exportCSV("reservations.csv", ["Facility", "Unit", "Resident", "When", "Status"], newest(list("booking")).map(function (r) { return [r.v.place, r.v.unit, r.v.who || "", r.v.when, r.v.status]; }));
}

/* ==========================================================================
   Announcements and events
   ========================================================================== */
function viewAnn() {
  var anns = newest(list("announcement")), evs = newest(list("event"));
  return '<div class="two-col-r" style="grid-template-columns:minmax(0,1.3fr) minmax(0,1fr)"><div style="display:flex;flex-direction:column;gap:16px">' +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2 style="font-size:19px">Create announcement</h2>' +
    '<input id="annTitle" placeholder="Title" value="' + escAttr(state.newAnnTitle) + '" oninput="state.newAnnTitle=this.value" ' + inputStyle() + ">" +
    '<textarea id="annBody" placeholder="Message" oninput="state.newAnnBody=this.value" style="min-height:70px;border:1px solid #CFC3A9;border-radius:10px;padding:10px 12px;font-size:14px;font-family:inherit;resize:vertical">' + esc(state.newAnnBody) + "</textarea>" +
    '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap"><div class="field" style="flex-grow:0"><label style="font-size:12px;font-weight:700;color:var(--muted)">Type</label>' +
    '<select onchange="state.newAnnType=this.value" style="height:40px;border:1px solid #CFC3A9;border-radius:10px;padding:0 10px;font-size:14px">' +
    ["General", "Maintenance", "Warning", "Emergency"].map(function (t) { return "<option " + (state.newAnnType === t ? "selected" : "") + ">" + t + "</option>"; }).join("") + "</select></div></div>" +
    '<button class="btn primary" onclick="addAnnouncement()">Publish announcement</button></div>' +
    '<div class="card" style="padding:0;overflow:hidden"><div style="display:flex;align-items:center;padding:14px 18px"><h2 style="font-size:19px;flex-grow:1">Announcements</h2><button class="btn" onclick="exportAnnouncements()">Export to Excel (.csv)</button></div>' +
    (anns.map(function (r) {
      var a = r.v, status = a.status || "Published", type = a.type || "General";
      return '<div style="padding:12px 18px;border-top:1px solid var(--border2)"><div style="display:flex;justify-content:space-between;align-items:baseline;gap:10px"><div style="font-weight:700;font-size:15px">' + esc(a.title) + '</div><span style="display:flex;gap:6px;flex-shrink:0">' +
        (type !== "General" ? '<span class="chip ' + typeChipClass(type) + '">' + esc(type) + "</span>" : "") + '<span class="chip ' + (status === "Published" ? "good" : "warn") + '">' + esc(status) + "</span></span></div>" +
        '<div style="font-size:13px;color:var(--muted);margin:4px 0">' + esc(a.body) + '</div><div style="display:flex;justify-content:space-between;align-items:center"><span style="font-size:12px;color:var(--muted)">' + esc(a.date) + '</span><span style="display:flex;gap:6px">' +
        (status !== "Published" ? '<button class="btn" onclick="publishAnn(\'' + escAttr(r.id) + '\')">Publish</button>' : "") +
        '<button class="btn" style="font-size:12px" onclick="editAnn(\'' + escAttr(r.id) + '\')">Edit</button><button class="btn" style="font-size:12px;color:#A02B1D" onclick="deleteAnn(\'' + escAttr(r.id) + '\')">Delete</button></span></div></div>';
    }).join("") || '<div style="padding:18px;border-top:1px solid var(--border2);color:var(--muted)">No announcements yet.</div>') + "</div></div>" +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2 style="font-size:19px">Add event</h2><button class="btn primary" onclick="eventForm(null)">+ Add event</button>' +
    '<div style="border-top:1px solid var(--border2);margin-top:6px;padding-top:10px;display:flex;justify-content:space-between;align-items:baseline"><h2 style="font-size:16px">Upcoming events</h2><button class="btn" onclick="exportEvents()" style="font-size:12px;min-height:34px">Export .csv</button></div>' +
    (evs.map(function (r) {
      var e = r.v, going = list("rsvp").filter(function (x) { return Number(x.v.event) === Number(r.id); }).length;
      return '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 0;border-top:1px solid var(--border2)"><div><div style="font-weight:700;font-size:14px">' + esc(e.title) + '</div><div style="font-size:12px;color:var(--muted)">' + esc(e.date) + " · " + esc(e.place) + " · " + going + ' going</div></div><span style="display:flex;gap:6px"><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="eventForm(\'' + escAttr(r.id) + '\')">Edit</button><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="deleteEvent(\'' + escAttr(r.id) + '\')">Delete</button></span></div>';
    }).join("") || '<p class="empty">No events yet.</p>') + "</div></div>";
}
// Saves a new announcement draft from the form.
function addAnnouncement() {
  var title = state.newAnnTitle.trim();
  if (!title) return toast("Enter a title first.");
  act(async function () {
    var id = nextId();
    await put("announcement", id, "", { id: id, title: title, body: state.newAnnBody.trim() || "—", date: shortDate(new Date()), status: "Published", type: state.newAnnType || "General" });
    logAct("Announcement published: " + title, "Announcements");
    state.newAnnTitle = ""; state.newAnnBody = ""; state.newAnnType = "General";
    toast("Announcement published. Residents can see it now.");
  });
}
// Publishes an announcement so residents can see it.
function publishAnn(id) {
  var row = getRow("announcement", id); if (!row) return;
  act(async function () {
    await put("announcement", id, "", Object.assign({}, row.value, { status: "Published", date: shortDate(new Date()) }));
    logAct("Announcement published: " + row.value.title, "Announcements");
  });
}
// Popup form to edit an announcement.
function editAnn(id) {
  var row = getRow("announcement", id); if (!row) return;
  var a = row.value;
  openForm({
    title: "Edit announcement",
    fields: [{ name: "title", label: "Title", value: a.title }, { name: "body", label: "Message", type: "textarea", value: a.body === "—" ? "" : a.body },
      { name: "type", label: "Type", type: "select", options: ["General", "Maintenance", "Warning", "Emergency"], value: a.type || "General" }],
    onSubmit: async function (d) {
      if (!d.title) return { error: "Enter a title." };
      await put("announcement", id, "", Object.assign({}, a, { title: d.title, body: d.body || "—", type: d.type }));
      logAct("Announcement edited: " + d.title, "Announcements");
    }
  });
}
// Deletes an announcement.
function deleteAnn(id) {
  confirmBox("Delete announcement?", "Residents will no longer see it.", "Delete", async function () { await del("announcement", id); logAct("Announcement deleted", "Announcements"); }, true);
}
// Popup form to add or edit an event.
function eventForm(id) {
  var e = id ? (getRow("event", id) || {}).value || {} : {};
  openForm({
    title: id ? "Edit event" : "Add event",
    fields: [{ name: "title", label: "Event title", value: e.title }, { name: "date", label: "Date & time", placeholder: "e.g. Oct 24, 2026 · 7:00 AM", value: e.date },
      { name: "place", label: "Venue", value: e.place }, { name: "about", label: "Details (optional)", type: "textarea", value: e.about }],
    onSubmit: async function (d) {
      if (!d.title) return { error: "Enter the event title." };
      var eid = id || nextId();
      await put("event", eid, "", { id: Number(eid), title: d.title, date: d.date || "Date TBD", place: d.place || "Venue TBD", about: d.about });
      logAct((id ? "Event updated: " : "Event added: ") + d.title, "Events");
    }
  });
}
// Deletes an event.
function deleteEvent(id) {
  confirmBox("Delete event?", "Residents will no longer see it.", "Delete", async function () {
    await del("event", id);
    var gone = list("rsvp").filter(function (r) { return Number(r.v.event) === Number(id); });
    for (var i = 0; i < gone.length; i++) await del("rsvp", gone[i].id);
    logAct("Event deleted", "Events");
  }, true);
}
// Downloads announcements as CSV.
function exportAnnouncements() {
  exportCSV("announcements.csv", ["Title", "Body", "Type", "Date", "Status"], newest(list("announcement")).map(function (r) { return [r.v.title, r.v.body, r.v.type || "General", r.v.date, r.v.status || "Published"]; }));
}
// Downloads events as CSV.
function exportEvents() { exportCSV("events.csv", ["Title", "Date", "Venue"], newest(list("event")).map(function (r) { return [r.v.title, r.v.date, r.v.place]; })); }

/* ==========================================================================
   Polls
   ========================================================================== */
function viewPolls() {
  var all = pollsAll(), open = all.filter(function (p) { return p.open; }).length, units = list("unit").length;
  var shown = all.filter(function (p) { return state.pollFilter === "all" || (state.pollFilter === "open") === p.open; });
  return '<div class="two-col-r" style="grid-template-columns:minmax(0,1fr) 360px"><div style="display:flex;flex-direction:column;gap:14px">' +
    pageTabs([["open", "Open (" + open + ")"], ["closed", "Closed (" + (all.length - open) + ")"], ["all", "All (" + all.length + ")"]], state.pollFilter, "pollFilter") +
    (shown.map(function (p) {
      var voted = list("vote").filter(function (x) { return Number(x.v.poll) === p.id; }).length;
      return '<div class="card"><div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px"><div><h2>' + esc(p.q) + '</h2><small style="color:var(--muted)">' + (p.open ? "Closes" : "Closed") + " " + esc(p.closes) + '</small></div><span class="chip ' + (p.open ? "good" : "info") + '">' + (p.open ? "Open" : "Closed") + "</span></div>" +
        pollBars(p) + (units ? '<div style="margin-top:14px">' + progressBar("Units that voted", voted, units, "green") + "</div>" : "") +
        '<div style="display:flex;gap:8px;margin-top:14px;flex-wrap:wrap"><button class="btn" onclick="togglePoll(' + p.id + ')">' + (p.open ? "Close poll" : "Reopen poll") + '</button><button class="btn" onclick="exportPoll(' + p.id + ')">Export results</button><button class="btn" style="margin-left:auto;color:var(--bad-fg)" onclick="deletePoll(' + p.id + ')">Delete</button></div></div>';
    }).join("") || '<p class="empty">No polls here yet.</p>') + "</div>" +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2>New poll</h2><p style="margin:0;font-size:13px;color:var(--muted)">Residents see open polls in their portal and vote once per unit.</p>' +
    '<label class="fl">Question<input id="newPollQ" value="' + escAttr(state.newPollQ) + '" oninput="state.newPollQ=this.value" placeholder="e.g. Extend pool hours on weekends?"></label>' +
    '<label class="fl">Options (one per line)<textarea id="newPollOpts" rows="4" oninput="state.newPollOpts=this.value" placeholder="Yes&#10;No&#10;Not sure">' + esc(state.newPollOpts) + '</textarea></label>' +
    '<button class="btn primary" onclick="addPoll()">Publish poll</button></div></div>';
}
// Creates a new poll from the form.
function addPoll() {
  var options = state.newPollOpts.split("\n").map(function (s) { return s.trim(); }).filter(Boolean);
  if (!state.newPollQ.trim() || options.length < 2) return toast("Add a question and at least two options.");
  act(async function () {
    var id = nextId(), end = shortDate(new Date(Date.now() + 7 * 86400000));
    await put("poll", id, "", { id: id, question: state.newPollQ.trim(), open: true, closes: end, options: options });
    logAct("Poll published: " + state.newPollQ.trim(), "Polls");
    state.newPollQ = ""; state.newPollOpts = ""; state.pollFilter = "open";
    toast("Poll published. Residents can vote now.");
  });
}
// Opens or closes voting on a poll.
function togglePoll(id) {
  var row = getRow("poll", id); if (!row) return;
  act(async function () {
    var open = !row.value.open;
    await put("poll", id, "", Object.assign({}, row.value, { open: open }));
    logAct((open ? "Poll reopened: " : "Poll closed: ") + row.value.question, "Polls");
  });
}
// Deletes a poll.
function deletePoll(id) {
  var row = getRow("poll", id); if (!row) return;
  confirmBox("Delete this poll?", "The poll and its results will be removed.", "Delete", async function () {
    await del("poll", id);
    var gone = list("vote").filter(function (r) { return Number(r.v.poll) === Number(id); });
    for (var i = 0; i < gone.length; i++) await del("vote", gone[i].id);
    logAct("Poll deleted: " + row.value.question, "Polls");
  }, true);
}
// Downloads one poll's results as CSV.
function exportPoll(id) {
  var p = pollsAll().filter(function (x) { return x.id === Number(id); })[0]; if (!p) return;
  exportCSV("poll-results.csv", ["Option", "Votes"], p.options.map(function (o) { return [o.t, o.votes]; }));
}
