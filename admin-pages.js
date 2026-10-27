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
    (b.status === "Pending" ? '<div class="fx-act"><button class="btn primary" onclick="setBooking(\'' + id + '\',\'Approved\')">Approve</button><button class="btn" onclick="setBooking(\'' + id + '\',\'Denied\')">Deny</button></div>' : "") + "</div>";
}
function facRequestsPage(all) {
  var pend = all.filter(function (r) { return r.v.status === "Pending"; }), rest = all.filter(function (r) { return r.v.status !== "Pending"; });
  var ok = all.filter(function (r) { return r.v.status === "Approved"; }).length, no = all.filter(function (r) { return r.v.status === "Denied"; }).length;
  var limit = state.facAll ? rest.length : 8;
  return '<div class="stat-row">' + statTile(pend.length, "Waiting for you", pend.length ? "warn" : "") + statTile(ok, "Approved", "good") + statTile(no, "Denied", "") + statTile(all.length, "All requests", "") + "</div>" +
    '<div class="card fx-group"><div class="fx-head"><h2>Needs your decision</h2><span class="hint" style="margin:0">Residents are told as soon as you decide.</span></div>' +
    (pend.map(facRequestCard).join("") || '<p class="empty">Nothing is waiting. New requests show up here.</p>') + "</div>" +
    '<div class="card fx-group"><div class="fx-head"><h2>Earlier requests</h2><span class="hint" style="margin:0">' + rest.length + " in total</span></div>" +
    (rest.slice(0, limit).map(facRequestCard).join("") || '<p class="empty">No earlier requests yet.</p>') +
    (rest.length > 8 ? '<div style="margin-top:10px"><button class="btn" onclick="set({facAll:' + !state.facAll + '})">' + (state.facAll ? "Show fewer" : "Show all " + rest.length) + "</button></div>" : "") + "</div>";
}
function facSlotsPage(fl) {
  if (!fl.length) return emptyCard("No amenities yet. Add one under Amenities.");
  var sel = Math.min(Math.max(0, Number(state.facSel) || 0), fl.length - 1), f = fl[sel];
  var today = new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" });
  return '<div class="card"><div class="fx-head"><h2>' + esc(today) + '</h2><span class="hint" style="margin:0">Select an open slot to close it, or a closed slot to open it again.</span></div>' +
    '<div class="seg small" role="tablist" style="margin:12px 0">' + fl.map(function (x, i) { return '<button type="button" class="' + (i === sel ? "on" : "") + '" onclick="set({facSel:' + i + '})"><span>' + esc(x.name) + "</span></button>"; }).join("") + "</div>" +
    '<p class="hint" style="margin:0 0 10px">' + esc(f.hours) + (f.note ? " · " + esc(f.note) : "") + '</p><div class="slots">' + f.slots.map(function (t, i) {
      var closed = slotClosed(sel, i), bk = bookingAt(sel, i), cls = closed || bk ? "booked" : "open", label = closed ? "Closed" : bk ? "Booked" : "Open";
      return '<button class="slot ' + cls + '" title="' + escAttr(bk ? bk.unit : "") + '" onclick="toggleSlot(' + sel + "," + i + ')"><b>' + esc(t) + "</b><span>" + label + "</span></button>";
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
