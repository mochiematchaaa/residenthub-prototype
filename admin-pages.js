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
  var tools = tab === "events" ? '<button class="btn" onclick="exportEvents()">Export .csv</button><button class="btn primary" onclick="eventForm(null)">+ Add event</button>' : '<button class="btn" onclick="exportAnnouncements()">Export .csv</button><button class="btn primary" onclick="announcementForm()">+ New announcement</button>';
  return subNav([["posts", "Announcements", anns.length, false], ["events", "Events", evs.length]], tab, "annTab", tools) + (tab === "events" ? annEventsPage(evs) : annPostsPage(anns, drafts));
}
function annPostsPage(anns, drafts) {
  var f = ["all", "Published", "Draft"].indexOf(state.annFilter) >= 0 ? state.annFilter : "all";
  var shown = anns.filter(function (r) { return f === "all" || (r.v.status || "Published") === f; });
  return '<div class="filters" style="margin-bottom:12px">' + [["all", "All (" + anns.length + ")"], ["Published", "Published (" + (anns.length - drafts) + ")"], ["Draft", "Drafts (" + drafts + ")"]].map(function (t) {
    return '<button class="' + (f === t[0] ? "active" : "") + '" onclick="set({annFilter:\'' + t[0] + '\'})">' + t[1] + "</button>";
  }).join("") + "</div>" +
    '<div class="ann-list">' + (shown.map(function (r) {
      var a = r.v, status = a.status || "Published", type = a.type || "General", id = escAttr(r.id);
      return '<article class="card ann-card t-' + type.toLowerCase() + '"><div class="ann-top"><h3>' + esc(a.title) + '</h3><span class="ann-chips">' + (type !== "General" ? '<span class="chip ' + typeChipClass(type) + '">' + esc(type) + "</span>" : "") + '<span class="chip ' + (status === "Published" ? "good" : "warn") + '">' + esc(status) + "</span></span></div>" +
        '<p class="ann-body">' + esc(a.body) + '</p><div class="ann-foot"><small>' + esc(a.date) + '</small><span class="fx-act">' + (status !== "Published" ? '<button class="btn primary" onclick="publishAnn(\'' + id + '\')">Publish</button>' : "") +
        '<button class="btn" onclick="editAnn(\'' + id + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="deleteAnn(\'' + id + '\')">Delete</button></span></div></article>';
    }).join("") || '<div class="card" style="text-align:center;color:var(--muted)">' + (anns.length ? "Nothing in this list." : "No announcements yet. Use “New announcement” to publish the first one.") + "</div>") + "</div>";
}
function annEventsPage(evs) {
  return '<div class="ev-list">' + (evs.map(function (r) {
    var e = r.v, going = list("rsvp").filter(function (x) { return Number(x.v.event) === Number(r.id); }).length, id = escAttr(r.id), when = String(e.date || "").split("·");
    return '<article class="card ev-card"><div class="ev-date"><b>' + esc((when[0] || "").trim() || "TBD") + "</b><small>" + esc((when[1] || "").trim()) + '</small></div><div class="ev-main"><h3>' + esc(e.title) + "</h3><small>" + esc(e.place || "Venue TBD") + (e.about ? " · " + esc(e.about) : "") + '</small></div><span class="chip ' + (going ? "good" : "") + '">' + going + ' going</span><span class="fx-act"><button class="btn" onclick="eventForm(\'' + id + '\')">Edit</button><button class="btn" style="color:#A02B1D" onclick="deleteEvent(\'' + id + '\')">Delete</button></span></article>';
  }).join("") || '<div class="card" style="text-align:center;color:var(--muted)">No events yet. Use “Add event” to create one.</div>') + "</div>";
}
// Popup to write a new announcement and publish it now or keep it as a draft.
function announcementForm() {
  openForm({
    title: "New announcement",
    intro: "Residents see a published announcement on their dashboard straight away.",
    submit: "Save",
    fields: [
      { name: "title", label: "Title", placeholder: "e.g. Water interruption on Friday" },
      { name: "body", label: "Message", type: "textarea" },
      { name: "type", label: "Type", type: "select", options: ["General", "Maintenance", "Warning", "Emergency"], value: "General" },
      { name: "when", label: "What to do with it", type: "select", options: ["Publish now", "Save as a draft"], value: "Publish now" }
    ],
    onSubmit: async function (d) {
      var title = String(d.title || "").trim(); if (!title) return { error: "Enter a title." };
      var id = nextId(), live = d.when === "Publish now";
      await put("announcement", id, "", { id: id, title: title, body: String(d.body || "").trim() || "—", date: shortDate(new Date()), status: live ? "Published" : "Draft", type: d.type || "General" });
      logAct((live ? "Announcement published: " : "Announcement saved as draft: ") + title, "Announcements");
      toast(live ? "Announcement published. Residents can see it now." : "Saved as a draft. Publish it when you are ready.");
    }
  });
}
