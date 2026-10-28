/* ==========================================================================
   admin-pages.js — the Facility and Announcements pages, split into sub-pages so each screen shows one thing.
     Facility:       Requests · Today's slots · Amenities
     Announcements:  Announcements · Events
   (Polls is in polls-admin.js and uses the same sub-page bar.)
   Loaded by admin.html after admin.js.
   ========================================================================== */

/* ---------- the sub-page bar (same look on every page that is split up) ---------- */
// items: [[id, label, count, hot?]]. A "hot" count is shown in colour (something is waiting).
function subNav(items, current, key, tools) {
  return '<div class="subnav"><div class="seg" role="tablist">' + items.map(function (t) {
    var n = t[2] === undefined || t[2] === "" || t[2] === null ? "" : '<i class="n' + (t[3] ? " hot" : "") + '">' + t[2] + "</i>";
    return '<button type="button" role="tab" aria-selected="' + (t[0] === current) + '" class="' + (t[0] === current ? "on" : "") + '" onclick="set({' + key + ":'" + t[0] + '\'})"><span>' + t[1] + "</span>" + n + "</button>";
  }).join("") + "</div>" + (tools ? '<div class="subnav-tools">' + tools + "</div>" : "") + "</div>";
}
// A counter you can click (used to filter a list). Clicking the active one clears the filter.
function statBtn(n, label, tone, on, js) { return '<button type="button" class="stat-t ' + (tone || "") + (on ? " on" : "") + '" aria-pressed="' + !!on + '" onclick="' + js + '"><b>' + n + "</b><span>" + label + "</span></button>"; }
function statTile(n, label, tone) { return '<div class="stat-t ' + (tone || "") + '"><b>' + n + "</b><span>" + label + "</span></div>"; }

/* ==========================================================================
   Facility
   ========================================================================== */
function facTab() { return ["requests", "slots", "amenities"].indexOf(state.facTab) >= 0 ? state.facTab : "requests"; }
function viewFac() {
  var tab = facTab(), bookings = list("booking"), pend = bookings.filter(function (r) { return r.v.status === "Pending"; }).length, fl = facilities();
  var tools = tab === "requests" ? '<button class="btn" onclick="exportBookings()">Export to Excel (.csv)</button>' : tab === "amenities" ? '<button class="btn primary" onclick="amenityForm()">+ Add amenity</button>' : "";
  return subNav([["requests", "Requests", pend || "", true], ["slots", "Today's slots"], ["amenities", "Amenities", fl.length]], tab, "facTab", tools) +
    (tab === "slots" ? facSlotsPage(fl) : tab === "amenities" ? facAmenitiesPage(fl) : facRequestsPage(newest(bookings)));
}
function facRequestCard(r) {
  var b = r.v, tone = b.status === "Approved" ? "good" : b.status === "Denied" ? "bad" : "warn", id = escAttr(r.id);
  return '<div class="fx-card ' + tone + '"><span class="fx-ico">' + icon("fac") + '</span><div class="fx-main"><b>' + esc(b.place) + "</b><small>" + esc(b.unit) + (b.who && b.who !== b.unit ? " · " + esc(b.who) : "") + "</small><small>" + esc(b.when) + '</small></div><span class="chip ' + tone + '">' + esc(b.status) + "</span>" +
    '<div class="fx-act">' + (b.status === "Pending" ? '<button class="btn primary" onclick="setBooking(\'' + id + '\',\'Approved\')">Approve</button><button class="btn" onclick="setBooking(\'' + id + '\',\'Denied\')">Deny</button>' : "") +
    '<button class="btn" onclick="editBooking(\'' + id + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="removeBooking(\'' + id + '\')">Remove</button></div></div>';
}
function facRequestsPage(all) {
  var pend = all.filter(function (r) { return r.v.status === "Pending"; }), rest = all.filter(function (r) { return r.v.status !== "Pending"; });
  var ok = all.filter(function (r) { return r.v.status === "Approved"; }).length, no = all.filter(function (r) { return r.v.status === "Denied"; }).length;
  var fil = ["Pending", "Approved", "Denied", "all"].indexOf(state.facFilter) >= 0 ? state.facFilter : "";
  var limit = state.facAll ? rest.length : 8;
  var tiles = '<div class="stat-row">' + statBtn(pend.length, "Waiting for you", pend.length ? "warn" : "", fil === "Pending", "facFilterSet('Pending')") + statBtn(ok, "Approved", "good", fil === "Approved", "facFilterSet('Approved')") +
    statBtn(no, "Denied", "", fil === "Denied", "facFilterSet('Denied')") + statBtn(all.length, "All requests", "", fil === "all", "facFilterSet('all')") + "</div>" +
    '<p class="hint" style="margin:-4px 0 12px">' + (fil ? "Showing one group. Select the same number again to see everything." : "Select a number to see only those requests.") + " Every request has Edit (change its status or time) and Remove.</p>";
  function group(title, rows, note) {
    return '<div class="card fx-group"><div class="fx-head"><h2>' + title + '</h2><span class="hint" style="margin:0">' + note + "</span></div>" + (rows.map(facRequestCard).join("") || '<p class="empty">Nothing here.</p>') + "</div>";
  }
  if (fil === "Pending") return tiles + group("Needs your decision", pend, "Residents are told as soon as you decide.");
  if (fil === "Approved" || fil === "Denied") { var rows = rest.filter(function (r) { return r.v.status === fil; }); return tiles + group(fil + " requests", rows, rows.length + " in total"); }
  if (fil === "all") return tiles + group("All requests", pend.concat(rest), all.length + " in total");
  return tiles +
    '<div class="card fx-group"><div class="fx-head"><h2>Needs your decision</h2><span class="hint" style="margin:0">Residents are told as soon as you decide.</span></div>' +
    (pend.map(facRequestCard).join("") || '<p class="empty">Nothing is waiting. New requests show up here.</p>') + "</div>" +
    '<div class="card fx-group"><div class="fx-head"><h2>Earlier requests</h2><span class="hint" style="margin:0">' + rest.length + " in total</span></div>" +
    (rest.slice(0, limit).map(facRequestCard).join("") || '<p class="empty">No earlier requests yet.</p>') +
    (rest.length > 8 ? '<div style="margin-top:10px"><button class="btn" onclick="set({facAll:' + !state.facAll + '})">' + (state.facAll ? "Show fewer" : "Show all " + rest.length) + "</button></div>" : "") + "</div>";
}
function facFilterSet(k) { set({ facFilter: state.facFilter === k ? "" : k, facAll: false }); }
// Change a request: its status and its time slot.
function editBooking(id) {
  var row = getRow("booking", id); if (!row) return;
  var b = row.value, fl = facilities(), f = fl.filter(function (x) { return x.name === b.place; })[0], fi = fl.indexOf(f), canSlot = !!(f && b.day && keyToDate(b.day) && b.slot != null && Number(b.slot) >= 0);
  var fields = [{ name: "status", label: "Status", type: "select", options: [["Pending", "Waiting for a decision"], ["Approved", "Approved"], ["Denied", "Denied (frees the time)"]], value: b.status }];
  if (canSlot) fields.push({ name: "slot", label: "Time", type: "select", options: f.slots.map(function (t, i) { return [String(i), t]; }), value: String(b.slot) });
  openForm({
    title: "Edit " + b.place + " request",
    intro: esc((b.unit || "") + (b.who && b.who !== b.unit ? " · " + b.who : "") + " · " + (b.when || "")) + ". The resident is told about the change.",
    submit: "Save", fields: fields,
    onSubmit: async function (d) {
      var slot = canSlot ? Number(d.slot) : b.slot, status = d.status, when = b.when;
      if (canSlot && (status === "Pending" || status === "Approved")) {
        var clash = vals("booking").filter(function (x) { return String(x.id) !== String(id) && x.day === b.day && x.place === b.place && Number(x.slot) === slot && (x.status === "Pending" || x.status === "Approved"); })[0];
        if (clash) return { error: "That time is already taken by " + clash.unit + ". Choose another time." };
        if (b.day === dayKey(new Date()) && slotClosed(fi, slot)) return { error: "That time is closed today. Open it first under Today's slots." };
      }
      if (canSlot) when = shortDate(keyToDate(b.day)) + ", " + f.slots[slot];
      await put("booking", id, row.unit, Object.assign({}, b, { status: status, slot: slot, when: when }));
      logAct(b.place + " booking changed (" + status.toLowerCase() + "), " + b.unit, "Facilities");
      toast("Request updated.");
    }
  });
}
// Deletes a request completely.
function removeBooking(id) {
  var row = getRow("booking", id); if (!row) return;
  confirmBox("Remove this request?", row.value.place + ", " + row.value.unit + ", " + row.value.when + ". It is deleted for good and the time becomes free.", "Remove", async function () {
    await del("booking", id);
    logAct(row.value.place + " booking removed, " + row.value.unit, "Facilities");
  }, true);
}
// Click on a time of today: change its booking, reserve it for a unit, close it, or open it again.
function slotClick(f, i) {
  var fac = facilities()[f]; if (!fac) return;
  if (slotClosed(f, i)) return toggleSlot(f, i);
  var bk = bookingAt(f, i);
  if (bk) return editBooking(bk.id);
  var units = unitNames();
  openForm({
    title: fac.name + " · " + fac.slots[i], intro: "This time is open today. Close it so nobody can book it, or reserve it for a unit (for example a walk-in request at the office).", submit: "Save",
    fields: [{ name: "what", label: "What do you want to do?", type: "select", options: [["close", "Close it for today"], ["book", "Reserve it for a unit"]], value: "close" },
      { name: "unit", label: "Unit (only when reserving)", type: "select", options: units.length ? units : [["", "No units yet"]] }],
    onSubmit: async function (d) {
      if (d.what !== "book") { toggleSlot(f, i); return; }
      if (!d.unit) return { error: "Choose the unit." };
      var today = dayKey(new Date());
      var st = slotState(f, i, today); if (st === "past") return { error: "That time has already passed today. Choose a later time." }; if (st !== "open") return { error: "That time is no longer open." };
      var id = nextId();
      await put("booking", id, d.unit, { id: id, who: whoOf(d.unit), unit: d.unit, place: fac.name, when: shortDate(new Date()) + ", " + fac.slots[i], status: "Approved", day: today, slot: i });
      logAct(fac.name + " reserved for " + d.unit + " (" + fac.slots[i] + ")", "Facilities");
      toast("Reserved for " + d.unit + ".");
    }
  });
}
function facSlotsPage(fl) {
  if (!fl.length) return emptyCard("No amenities yet. Add one under Amenities.");
  var sel = Math.min(Math.max(0, Number(state.facSel) || 0), fl.length - 1), f = fl[sel];
  var today = new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" });
  return '<div class="card"><div class="fx-head"><h2>' + esc(today) + '</h2><span class="hint" style="margin:0">Select a time: an open one can be closed or reserved for a unit, a booked one can be changed or freed, a closed one is opened again.</span></div>' +
    '<div class="seg small" role="tablist" style="margin:12px 0">' + fl.map(function (x, i) { return '<button type="button" class="' + (i === sel ? "on" : "") + '" onclick="set({facSel:' + i + '})"><span>' + esc(x.name) + "</span></button>"; }).join("") + "</div>" +
    '<p class="hint" style="margin:0 0 10px">' + esc(f.hours) + (f.note ? " · " + esc(f.note) : "") + '</p><div class="slots">' + f.slots.map(function (t, i) {
      var closed = slotClosed(sel, i), bk = bookingAt(sel, i), cls = closed || bk ? "booked" : "open", label = closed ? "Closed" : bk ? (bk.status === "Pending" ? "Waiting · " : "Booked · ") + esc(bk.unit.replace(/^Unit\s+/i, "")) : "Open";
      return '<button class="slot adm ' + cls + '" title="' + escAttr(bk ? bk.unit + " · " + (bk.status || "") + " (select to change)" : closed ? "Closed (select to open it again)" : "Open (select to close or reserve it)") + '" onclick="slotClick(' + sel + "," + i + ')"><b>' + esc(t) + "</b><span>" + label + "</span></button>";
    }).join("") + "</div></div>";
}
function facAmenitiesPage(fl) {
  if (!fl.length) return emptyCard("No amenities yet. Add the first one.");
  return '<p class="hint" style="margin:0 0 12px">Add an amenity, or change its name, opening hours or how long one booking is. Residents see the change straight away.</p><div class="am-grid">' + fl.map(function (f) {
    return '<div class="card am-card"><div><b>' + esc(f.name) + "</b><small>" + esc(f.hours || "Set the hours") + "</small><small>" + f.slots.length + " time slot" + (f.slots.length === 1 ? "" : "s") + " of " + (Number(f.mins) || 120) + " min</small></div>" +
      '<div class="fx-act"><button class="btn" onclick="amenityForm(\'' + escAttr(f.id) + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="removeAmenity(\'' + escAttr(f.id) + '\')">Remove</button></div></div>';
  }).join("") + "</div>";
}

/* ==========================================================================
   Announcements and events
   ========================================================================== */
function viewAnn() {
  var tab = state.annTab === "events" ? "events" : "posts", anns = newest(list("announcement")), evs = newest(list("event"));
  var drafts = anns.filter(function (r) { return (r.v.status || "Published") !== "Published"; }).length;
  var tools = tab === "events" ? '<button class="btn" onclick="exportEvents()">Export .csv</button><button class="btn primary" onclick="eventForm(null)">+ Add event</button>' : '<button class="btn" onclick="exportAnnouncements()">Export .csv</button>';
  return subNav([["posts", "Announcements", anns.length, false], ["events", "Events", evs.length]], tab, "annTab", tools) + (tab === "events" ? annEventsPage(evs) : annPostsPage(anns, drafts));
}
/* ---------- Announcements, laid out like an inbox (Gmail style) ---------- */
function annSnippet(t) { t = String(t || "").replace(/\s+/g, " ").trim(); return t === "—" ? "" : t; }
function annShortDay(d) { var x = parseShort(d); return x ? x.toLocaleDateString("en-US", { month: "short", day: "numeric" }) : esc(d || ""); }
var ICO_PEN = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 013 3L7 19l-4 1 1-4z"/></svg>';
var ICO_TRASH = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/></svg>';
var ICO_SEND = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4z"/></svg>';
var ICO_BACK = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/></svg>';
function annPostsPage(anns, drafts) {
  var f = ["all", "Published", "Draft"].indexOf(state.annFilter) >= 0 ? state.annFilter : "all";
  var pubN = anns.length - drafts;
  var side = '<aside class="gm-side"><button type="button" class="gm-compose" onclick="annCompose()">' + ICO_PEN + '<span>Compose</span></button>' +
    [["all", "All announcements", anns.length], ["Published", "Published", pubN], ["Draft", "Drafts", drafts]].map(function (t) {
      return '<button type="button" class="gm-f' + (f === t[0] ? " on" : "") + '" onclick="set({annFilter:\'' + t[0] + '\',annOpen:\'\'})"><span>' + t[1] + "</span>" + (t[2] ? "<i>" + t[2] + "</i>" : "") + "</button>";
    }).join("") + "</aside>";
  var open = state.annOpen ? getRow("announcement", state.annOpen) : null;
  if (open) return '<div class="gm">' + side + '<div class="gm-main">' + annReader(open) + "</div></div>";
  var shown = anns.filter(function (r) { return f === "all" || (r.v.status || "Published") === f; });
  var title = f === "all" ? "All announcements" : f === "Draft" ? "Drafts" : "Published";
  var rows = shown.map(function (r) {
    var a = r.v, draft = (a.status || "Published") !== "Published", type = a.type || "General", id = escAttr(r.id), snip = annSnippet(a.body);
    return '<div class="gm-row' + (draft ? " draft" : "") + '" tabindex="0" onclick="annRowOpen(\'' + id + '\')" onkeydown="if(event.key===\'Enter\')annRowOpen(\'' + id + '\')">' +
      '<span class="gm-dot t-' + esc(type.toLowerCase()) + '" title="' + esc(type) + '"></span>' +
      '<span class="gm-from">' + (draft ? '<em class="gm-draft">Draft</em>' : esc(type)) + "</span>" +
      '<span class="gm-text"><b>' + esc(a.title || "(no title)") + "</b>" + (snip ? '<span> — ' + esc(snip) + "</span>" : "") + "</span>" +
      (type !== "General" && !draft ? '<span class="chip ' + typeChipClass(type) + ' gm-chip">' + esc(type) + "</span>" : "") +
      '<span class="gm-date">' + annShortDay(a.date) + "</span>" +
      '<span class="gm-acts" onclick="event.stopPropagation()">' + (draft ? '<button type="button" title="Publish" onclick="publishAnn(\'' + id + '\')">' + ICO_SEND + "</button>" : "") +
      '<button type="button" title="Edit" onclick="annCompose(\'' + id + '\')">' + ICO_PEN + '</button><button type="button" title="Delete" onclick="deleteAnn(\'' + id + '\')">' + ICO_TRASH + "</button></span></div>";
  }).join("");
  return '<div class="gm">' + side + '<div class="gm-main"><div class="gm-bar"><b>' + title + "</b><small>" + shown.length + " " + (shown.length === 1 ? "message" : "messages") + "</small></div>" +
    (rows || '<p class="gm-empty">' + (anns.length ? "Nothing in " + title.toLowerCase() + "." : "No announcements yet. Select Compose to write the first one.") + "</p>") + "</div></div>";
}
// A drafted message opens in the compose window; a published one opens to read.
function annRowOpen(id) {
  var r = getRow("announcement", id); if (!r) return;
  if ((r.value.status || "Published") !== "Published") return annCompose(id);
  set({ annOpen: String(id) });
}
// Reading one announcement (like opening an email).
function annReader(r) {
  var a = r.value, draft = (a.status || "Published") !== "Published", type = a.type || "General", id = escAttr(r.id), body = a.body === "—" ? "" : a.body;
  return '<div class="gm-bar"><button type="button" class="gm-ic" title="Back to the list" onclick="set({annOpen:\'\'})">' + ICO_BACK + "</button>" +
    '<span class="gm-sp"></span><button type="button" class="gm-ic" title="Edit" onclick="annCompose(\'' + id + '\')">' + ICO_PEN + '</button><button type="button" class="gm-ic" title="Delete" onclick="deleteAnn(\'' + id + '\')">' + ICO_TRASH + "</button></div>" +
    '<article class="gm-read"><h2>' + esc(a.title) + '</h2><div class="gm-meta"><span class="gm-dot t-' + esc(type.toLowerCase()) + '"></span><b>' + esc(type) + "</b>" +
    '<span class="chip ' + (draft ? "warn" : "good") + '">' + (draft ? "Draft" : "Published") + "</span><span>" + esc(a.date || "") + " · shown to all residents</span></div>" +
    '<div class="gm-body">' + (esc(body) || "<i>No message.</i>") + "</div></article>";
}

/* ---------- compose window (bottom right, like Gmail) ---------- */
var CMP = null, cmpPopSkip = false;
function cmpEl(id) { return document.getElementById(id); }
// Opens the compose window: empty for a new announcement, or filled for a draft / published one.
function annCompose(id) {
  if (CMP) closeCompose();
  var row = id ? getRow("announcement", id) : null, a = row ? row.value : null, pub = !!a && (a.status || "Published") === "Published";
  CMP = { id: row ? String(id) : "", pub: pub, dirty: false, timer: null, pushed: false };
  var w = document.createElement("div");
  w.className = "cmp"; w.id = "cmp"; w.setAttribute("role", "dialog"); w.setAttribute("aria-label", "Announcement");
  w.innerHTML = '<div class="cmp-h"><b>' + (pub ? "Edit announcement" : a ? "Draft" : "New announcement") + '</b><span class="cmp-st" id="cmpSt"></span>' +
    '<button type="button" class="cmp-b" title="Minimise" id="cmpMin">&#8211;</button><button type="button" class="cmp-b" title="' + (pub ? "Close" : "Save and close") + '" id="cmpX">&#10005;</button></div>' +
    '<div class="cmp-body"><input id="cmpTitle" class="cmp-subj" placeholder="Title" autocomplete="off" value="' + escAttr(a ? a.title : "") + '">' +
    '<div class="cmp-row"><span>Type</span><select id="cmpType">' + ["General", "Maintenance", "Warning", "Emergency"].map(function (t) { return "<option" + (a && (a.type || "General") === t ? " selected" : "") + ">" + t + "</option>"; }).join("") + "</select></div>" +
    '<textarea id="cmpBody" placeholder="Write your message to the residents">' + esc(a && a.body !== "—" ? a.body : "") + "</textarea></div>" +
    '<div class="cmp-f"><button type="button" class="btn primary" id="cmpSend">' + (pub ? "Save changes" : "Publish") + "</button>" +
    '<span class="cmp-hint">' + (pub ? "Closing without saving drops your changes." : "Close this window and your text is kept as a draft.") + '</span><button type="button" class="cmp-b" title="' + (pub ? "Close" : "Discard") + '" id="cmpTrash">' + ICO_TRASH + "</button></div>";
  document.body.appendChild(w);
  cmpEl("cmpX").onclick = function () { closeCompose(); };
  cmpEl("cmpMin").onclick = function () { w.classList.toggle("min"); };
  cmpEl("cmpSend").onclick = cmpPublish;
  cmpEl("cmpTrash").onclick = cmpDiscard;
  ["cmpTitle", "cmpBody", "cmpType"].forEach(function (k) { cmpEl(k).addEventListener("input", cmpTouch); cmpEl(k).addEventListener("change", cmpTouch); });
  w.addEventListener("keydown", function (e) { if (e.key === "Escape") { e.stopPropagation(); closeCompose(); } });
  try { history.pushState({ cmp: 1 }, ""); CMP.pushed = true; } catch (e) { /* history blocked */ }
  setTimeout(function () { var t = cmpEl(a ? "cmpBody" : "cmpTitle"); if (t) t.focus(); }, 30);
}
function annNew() { annCompose(); }
function announcementForm() { annCompose(); }
function editAnn(id) { annCompose(id); }
function cmpVals() { return { title: cmpEl("cmpTitle").value.trim(), body: cmpEl("cmpBody").value.trim(), type: cmpEl("cmpType").value }; }
function cmpTouch() {
  if (!CMP) return; CMP.dirty = true;
  if (CMP.pub) return;
  clearTimeout(CMP.timer); var st = cmpEl("cmpSt"); if (st) st.textContent = "Saving…";
  CMP.timer = setTimeout(function () { cmpSave(true); }, 900);
}
// Keeps what is typed as a draft (never for an announcement that is already published).
async function cmpSave(quiet) {
  if (!CMP || CMP.pub) return false;
  var v = cmpVals(); if (!v.title && !v.body) return false;
  var first = !CMP.id; if (first) CMP.id = String(nextId());
  var old = getRow("announcement", CMP.id), base = old ? old.value : {};
  try {
    await put("announcement", CMP.id, "", Object.assign({}, base, { id: CMP.id, title: v.title || "(no title)", body: v.body || "—", type: v.type, date: base.date || shortDate(new Date()), status: base.status || "Draft" }));
  } catch (e) { return false; }
  CMP.dirty = false; CMP.saved = true;
  var st = cmpEl("cmpSt"); if (st) st.textContent = "Draft saved " + clockText(Date.now()).replace(/^[A-Za-z]+ \d+, /, "");
  if (typeof render === "function") render();
  return true;
}
// Closes the window. A new or draft announcement is saved as a draft first (like Gmail); a published one is only closed.
async function closeCompose(fromPop) {
  if (!CMP) return;
  var c = CMP; clearTimeout(c.timer);
  var saved = false;
  if (!c.pub) saved = await cmpSave(true);
  else if (c.dirty) toast("Changes dropped. Use Save changes to keep them.");
  var w = cmpEl("cmp"); if (w) w.remove();
  CMP = null;
  if (saved) { toast("Draft saved. Find it under Drafts."); logAct("Announcement saved as draft: " + (getRow("announcement", c.id) || { value: {} }).value.title, "Announcements"); }
  if (c.pushed && !fromPop) { cmpPopSkip = true; try { history.back(); } catch (e) { cmpPopSkip = false; } }
  if (typeof render === "function") render();
}
window.addEventListener("popstate", function () { if (cmpPopSkip) { cmpPopSkip = false; return; } if (CMP) closeCompose(true); });
// Publish (new or draft) or save changes (already published).
async function cmpPublish() {
  if (!CMP) return;
  var v = cmpVals(); if (!v.title) { toast("Enter a title first."); cmpEl("cmpTitle").focus(); return; }
  var c = CMP; clearTimeout(c.timer);
  var id = c.id || String(nextId()), old = getRow("announcement", id), base = old ? old.value : {};
  var live = c.pub ? base.status || "Published" : "Published";
  try {
    await put("announcement", id, "", Object.assign({}, base, { id: id, title: v.title, body: v.body || "—", type: v.type, date: c.pub ? base.date || shortDate(new Date()) : shortDate(new Date()), status: live }));
  } catch (e) { return toast("Could not save. Try again."); }
  logAct(c.pub ? "Announcement edited: " + v.title : "Announcement published: " + v.title, "Announcements");
  var w = cmpEl("cmp"); if (w) w.remove();
  CMP = null;
  if (c.pushed) { cmpPopSkip = true; try { history.back(); } catch (e) { cmpPopSkip = false; } }
  toast(c.pub ? "Changes saved." : "Announcement published. Residents can see it now.");
  set({ annFilter: c.pub ? state.annFilter : "Published", annOpen: "" });
}
// Trash icon: drop what was typed (and the draft made from it).
function cmpDiscard() {
  if (!CMP) return;
  var c = CMP; clearTimeout(c.timer);
  var done = async function () {
    if (!c.pub && c.id && getRow("announcement", c.id)) { try { await del("announcement", c.id); } catch (e) { /* keep */ } }
    var w = cmpEl("cmp"); if (w) w.remove();
    CMP = null;
    if (c.pushed) { cmpPopSkip = true; try { history.back(); } catch (e) { cmpPopSkip = false; } }
    if (!c.pub) toast("Draft discarded.");
    if (typeof render === "function") render();
  };
  var v = cmpVals();
  if (c.pub || (!v.title && !v.body)) return done();
  done();
}
function annEventsPage(evs) {
  return '<div class="ev-list">' + (evs.map(function (r) {
    var e = r.v, going = list("rsvp").filter(function (x) { return Number(x.v.event) === Number(r.id); }).length, id = escAttr(r.id), when = String(e.date || "").split("·");
    return '<article class="card ev-card"><div class="ev-date"><b>' + esc((when[0] || "").trim() || "TBD") + "</b><small>" + esc((when[1] || "").trim()) + '</small></div><div class="ev-main"><h3>' + esc(e.title) + "</h3><small>" + esc(e.place || "Venue TBD") + (e.about ? " · " + esc(e.about) : "") + '</small></div><span class="chip ' + (going ? "good" : "") + '">' + going + ' going</span><span class="fx-act"><button class="btn" onclick="eventForm(\'' + id + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="deleteEvent(\'' + id + '\')">Delete</button></span></article>';
  }).join("") || '<div class="card" style="text-align:center;color:var(--muted)">No events yet. Use “Add event” to create one.</div>') + "</div>";
}
