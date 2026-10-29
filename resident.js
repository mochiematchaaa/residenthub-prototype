/* Resident portal — the pages a resident sees, with real data from Supabase (see core.js). */

var state = {
  authed: false, view: "home", darkMode: false, bellOpen: false, bellSeen: false,
  facIdx: 0, pick: null, bookDay: "", calMonth: "", eventFilter: "all", pollFilter: "open",
  payFor: "", payAmt: "", payMethod: "", payRef: "", payImg: "", payDate: "",
  usage: "", usageInfo: {}, usageInfoFor: "", usageMsg: ""
};
try { state.darkMode = localStorage.getItem("rh_dark") === "1"; } catch (e) { /* storage blocked */ }

// Called by core.js after sign-in: shows the portal.
function rhEnter() { state.authed = true; state.view = "home"; state.usage = ""; state.usageInfoFor = ""; render(); }
// Called by core.js on sign-out: clears the page state.
function rhLeave() { state.authed = false; state.view = "home"; }
// Signs the resident out.
function doLogout() { signOut(); }
// The signed-in resident's profile.
function me() { return DB.profile || {}; }
// The resident's name (or email).
function myName() { return me().name || me().email || "Resident"; }
// The household name of the resident's unit.
function myHousehold() { var u = unitRec(myUnit()) || {}; return u.name && u.name !== "—" ? u.name : myName(); }
// The record of the resident's own unit.
function myRec() { return unitRec(myUnit()) || {}; }
// True for unit usages that the admin must approve (short-term rental, business).
function needsApproval(u) { return u && (u.usage === "shortterm" || u.usage === "business"); }
// Color of a status chip (Approved = green, Pending = yellow...).
function chipFor(s) { return s === "Approved" || s === "Paid" || s === "Confirmed" || s === "Completed" ? "good" : s === "Pending" ? "warn" : s === "Denied" || s === "Rejected" || s === "Overdue" ? "bad" : "info"; }
// Color of an announcement type chip.
function typeChipClass(t) { return t === "Emergency" ? "bad" : t === "Warning" ? "warn" : t === "Maintenance" ? "info" : ""; }

/* ---------- mine ---------- */
function myBookings() { return newest(list("booking")).filter(function (r) { return r.unit === myUnit(); }); }
// The dues of my unit.
function myDues() { return newest(list("due")).filter(function (r) { return r.unit === myUnit(); }); }
// My unpaid dues.
function myOpenDues() { return myDues().filter(function (r) { return !r.v.paid; }).sort(function (a, b) { return Number(a.id) - Number(b.id); }); }
// The payment proofs I sent.
function myProofs() { return newest(list("proof")).filter(function (r) { return r.unit === myUnit(); }); }
// Announcements that the admin already published.
function publishedAnns() { return newest(list("announcement")).filter(function (r) { return r.v.status !== "Draft"; }); }
/* the soonest reservation that has not happened yet (a booking made for today counts until the day ends) */
function nextBooking() {
  var today = dayKey(new Date());
  var rows = myBookings().filter(function (r) { return (r.v.status === "Pending" || r.v.status === "Approved") && (!r.v.day || r.v.day >= today); });
  rows.sort(function (a, b) { return (a.v.day || "9999") === (b.v.day || "9999") ? (Number(a.v.slot) || 0) - (Number(b.v.slot) || 0) : ((a.v.day || "9999") < (b.v.day || "9999") ? -1 : 1); });
  return rows[0] || null;
}
// One event with its date parts and how many units are going.
function eventInfo(r) {
  var e = r.v, d = parseShort(e.date), going = list("rsvp").filter(function (x) { return Number(x.v.event) === Number(r.id); }).length;
  return { id: r.id, title: e.title, when: e.date || "", place: e.place || "", about: e.about || "", going: going,
    month: d ? MONTHS[d.getMonth()].toUpperCase() : "EVENT", day: d ? String(d.getDate()) : "•", mine: !!getRow("rsvp", myUnit() + "|" + r.id) };
}
// The items in the notification bell for this resident.
// True if the resident already sent payment details for this charge and the office has not decided yet.
function hasPendingProof(d) { return myProofs().some(function (p) { return p.v.status === "Pending" && p.v.forText === d.note; }); }
// A notice's Pay button: open Dues with that charge ready in the payment form.
function bellPay(id) { state.bellOpen = false; state.bellSeen = true; state.view = "dues"; payThis(id); }
function notifs() {
  var out = [], unit = myUnit(), u = myRec();
  if (u.profileUpdated && Number(u.profileUpdated) > Number(u.selfUpdated || 0) && Date.now() - Number(u.profileUpdated) < 7 * 86400000) out.push(["The office updated your household record on " + shortDate(new Date(Number(u.profileUpdated))) + ". You can see it on your dashboard.", "info", "home"]);
  myBookings().slice(0, 3).forEach(function (r) {
    if (r.v.status === "Approved") out.push(["Your " + r.v.place + " booking (" + r.v.when + ") was approved.", "good", "res"]);
    else if (r.v.status === "Denied") out.push(["Your " + r.v.place + " booking (" + r.v.when + ") was not approved.", "bad", "res"]);
  });
  // charges the office billed: a summary of what is unpaid, and each new charge with the day it was billed
  var openDues = myOpenDues().slice().sort(function (x, y) { return Number(y.id) - Number(x.id); });
  if (openDues.length) {
    var owed = openDues.reduce(function (t, r) { return t + Number(r.v.amount || 0); }, 0), latest = openDues[0];
    out.push(["You have " + openDues.length + " unpaid charge" + (openDues.length > 1 ? "s" : "") + " (" + peso(owed) + "). Latest: " + latest.v.note + ", billed " + (billedOn(latest.id, latest.v) || "recently") + ".", "info", "dues"]);
  }
  openDues.filter(function (r) { var d = parseShort(billedOn(r.id, r.v)); return d && Date.now() - d.getTime() < 14 * 86400000; }).slice(0, 3).forEach(function (r) {
    out.push(["New charge from the office: " + r.v.note + " (" + peso(Number(r.v.amount)) + "), billed " + billedOn(r.id, r.v) + (r.v.dueDate ? ", due " + r.v.dueDate : "") + ".", "info", "dues"]);
  });
  // reminders the office wrote itself
  if (typeof custForMe === "function") custForMe().forEach(function (r) { out.unshift([r.title + ": " + r.text, "info", "home"]); });
  // reminders sent by the office, and charges that fall due in the next 3 days
  myOpenDues().forEach(function (r) {
    var rem = parseShort(r.v.remindedOn || ""), due = parseShort(r.v.dueDate || ""), days = due ? Math.round((due.getTime() - new Date().setHours(0, 0, 0, 0)) / 86400000) : null;
    if (rem && Date.now() - rem.getTime() < 10 * 86400000) out.push(["Reminder from the office (" + r.v.remindedOn + ")" + (r.v.remindMsg ? ": " + r.v.remindMsg + " —" : ":") + " " + r.v.note + " (" + peso(Number(r.v.amount)) + ") " + (days == null ? "is waiting for your payment." : days < 0 ? "is overdue by " + (-days) + " day" + (days === -1 ? "" : "s") + "." : days === 0 ? "is due today." : "is due in " + days + " day" + (days === 1 ? "" : "s") + " (" + r.v.dueDate + ")."), days != null && days < 0 ? "bad" : "info", "dues"]);
    else if (days != null && days >= 0 && days <= remCfg().dues.days && remCfg().dues.on !== "no" && !hasPendingProof(r.v)) out.push([r.v.note + " (" + peso(Number(r.v.amount)) + ") is due " + (days === 0 ? "TODAY. Pay within the day and send your proof so your dashboard updates" : days === 1 ? "tomorrow" : "in " + days + " days") + " (" + r.v.dueDate + "). Tap to pay and send your proof.", days === 0 ? "bad" : "warn", "dues", r.id]);
  });
  // every overdue charge, with a Pay button (the notice shows by itself the day after the due date)
  myOpenDues().filter(function (r) { return isOverdue(r.v) && !hasPendingProof(r.v); }).slice(0, 4).forEach(function (r) {
    var c = dueCountdown(r.v);
    out.unshift(["Overdue" + (c ? " by " + (-c.n) + " day" + (c.n === -1 ? "" : "s") : "") + ": " + r.v.note + " (" + peso(Number(r.v.amount)) + "). Tap to pay and send your proof.", "bad", "dues", r.id]);
  });
  myProofs().slice(0, 3).forEach(function (r) {
    if (r.v.status === "Confirmed" && !r.v.direct) out.push(["Your payment (ref. " + r.v.reference + ") was " + (r.v.auto ? "posted automatically" : "verified") + ". Receipt " + (r.v.receiptNo || "") + " is under Dues.", "good", "dues"]);
    else if (r.v.status === "Pending") { var ap = autoPostCfg(); out.push(["We received your payment details (" + peso(Number(r.v.amount) || 0) + ", ref. " + r.v.reference + ")." + (ap.on ? " It will be posted to your dues automatically by " + clockText(proofSentAt(r.v) + ap.hours * 3600000) + ". If something does not match, the office will tell you here." : " The office will verify it soon."), "info", "dues"]); }
    else if (r.v.status === "Rejected") out.push(["Your payment (ref. " + r.v.reference + ") was rejected" + (r.v.reason ? ": " + String(r.v.reason).replace(/[.\s]+$/, "") : " (please check the reference number)") + ". You can send the correct details.", "bad", "dues"]);
  });
  if (u.usageStatus === "approved") out.push(["Your " + usageLabel(u.usage).toLowerCase() + " was approved.", "good", "rental"]);
  else if (u.usageStatus === "rejected") out.push(["Your " + usageLabel(u.usage).toLowerCase() + " was not approved. " + (u.usageRemark || ""), "bad", "rental"]);
  else if (u.usageStatus === "pending") out.push(["Your " + usageLabel(u.usage).toLowerCase() + " is waiting for the administrator.", "info", "rental"]);
  var slot = list("slot").filter(function (r) { return r.v.unit === unit; })[0];
  if (slot) out.push(["Motor parking slot " + slot.id + " is assigned to your unit.", "good", "parking"]);
  // a monthly rental that is about to end (or already ended): did they forget, or are they leaving?
  var pd = slot ? parkDueInfo(slot.v) : null;
  if (pd && pd.soon && !leaveNoteOf(unit) && !renewProofOf(unit, slot.id) && !walkinOf(unit, true)) out.unshift(["Your parking rental for " + slot.id + " " + (pd.late ? "has ended or is due" : "is almost up") + ". The next payment is due " + usageDate(pd.nextDue) + " (" + parkDaysText(pd.days) + "). Renew to keep your slot, or tell the office if you no longer plan to rent.", pd.late ? "bad" : "warn", "parking"]);
  // the texts the office sent (rental approved, next due date)
  newest(list("sms")).filter(function (r) { return r.unit === unit && Date.now() - Number(r.v.at || 0) < 14 * 86400000; }).slice(0, 2).forEach(function (r) { out.push(["Text message to your phone: " + r.v.text, "good", "parking"]); });
  // every recent announcement from the office is a notification (maintenance notices are announcements too)
  publishedAnns().filter(function (r) { var d = parseShort(r.v.date || ""); return !d || Date.now() - d.getTime() < 14 * 86400000; }).slice(0, 4).forEach(function (r) {
    var m = r.v.type === "Maintenance", em = r.v.type === "Emergency", t = String(r.v.title || "").replace(/^Maintenance notice:\s*/i, "").replace(/[.\s]+$/, "");
    out.push([(m ? "Maintenance notice: " : em ? "Emergency: " : "New announcement: ") + t + ".", em ? "bad" : m ? "warn" : "info", "home"]);
  });
  var toVote = pollsAll().filter(function (p) { return p.open && myVote(p.id) === undefined; }).length;
  if (toVote) out.push([toVote + " poll" + (toVote > 1 ? "s" : "") + " waiting for your vote.", "info", "polls"]);
  return out;
}

/* ---------- page frame ---------- */
function titles() {
  var first = String(myName()).split(/\s+/)[0];
  return {
    home: [greeting() + ", " + first, "Your unit, announcements, events and notifications in one place."],
    book: ["Book a facility", "Check availability and send a reservation request."],
    res: ["My reservations", "Every facility request you've made, and its current status."],
    dues: ["Dues & payment status", "Your monthly charges and outstanding balance."],
    parking: ["Motor parking", "Your parking slot, your request, and which slots are free."],
    events: ["Community events", "See what is coming up and tell us you are going."],
    polls: ["Polls & voting", "Have your say on community decisions. One vote per unit."],
    directory: ["Directory", "Who to call, house rules, and answers to common questions."],
    gr: ["Complaints", "Submit a concern and track its status."],
    docs: ["Community documents", "Files shared by the association."],
    rental: ["Unit status", "Renting out your unit or running a business from it? Declare it here."],
    settings: ["Settings", "Manage your profile, password, appearance, and where you're signed in."]
  }[state.view] || ["", ""];
}
// Picks the page function to draw for state.view.
// Pages the administrator switched off for residents (Settings > Resident menu).
function navHidden(key) {
  if (key === "home" || key === "rental" || key === "settings") return false;
  var h = setting("resident_nav").hidden; return Array.isArray(h) && h.indexOf(key) >= 0;
}
function view() {
  if (navHidden(state.view)) state.view = "home";
  return ({ home: viewHome, book: viewBook, res: viewRes, dues: viewDues, parking: viewParkingPage, gr: viewGr, docs: viewDocs, rental: viewRental, settings: viewSettings, events: viewEvents, polls: viewPolls, directory: viewDirectory }[state.view] || viewHome)();
}
// Red banner shown when an Emergency announcement exists.
function emergencyBanner() {
  var a = publishedAnns().filter(function (r) { return r.v.type === "Emergency"; })[0];
  return a ? '<div class="alert-banner"><div><strong>' + esc(a.v.title) + "</strong> — " + esc(a.v.body) + "</div></div>" : "";
}
// Draws the whole resident portal (menu + current page). Called after every change.
function render() {
  if (!state.authed) return;
  document.documentElement.setAttribute("data-theme", state.darkMode ? "dark" : "light");
  try { localStorage.setItem("rh_dark", state.darkMode ? "1" : "0"); } catch (e) { /* storage blocked */ }
  var app = document.getElementById("app");
  var viewChanged = state.view !== window.__lastView, authChanged = state.authed !== window.__lastAuthed;
  window.__lastView = state.view; window.__lastAuthed = state.authed;
  if (viewChanged) state.dzSig = "";
  app.classList.toggle("enter", viewChanged || authChanged);
  app.classList.toggle("enter-shell", authChanged);
  if (viewChanged && !authChanged) window.scrollTo({ top: 0, behavior: "smooth" });
  var isHome = state.view === "home";
  if (viewChanged && isHome && state.authed) setTimeout(function () { if (typeof remPopup === "function") remPopup(); }, 500);   // reminder pop-up each time the dashboard opens
  keepFocus(function () {
    mountApp(app, '<div class="shell"><aside class="side"><div class="side-brand"><img src="logo.jpg" alt=""><span>ResidentHub</span></div>' +
      '<div class="side-label">' + tr("General") + '</div><nav>' + navBtn("home", "Home") + navBtn("book", "Book a facility") + navBtn("res", "Reservations") + navBtn("dues", "Dues") + navBtn("parking", "Parking", parkingFreeTag()) + navBtn("events", "Events") + "</nav>" +
      '<div class="side-label">' + tr("Community") + '</div><nav>' + navBtn("polls", "Polls") + navBtn("directory", "Directory") + navBtn("gr", "Complaints") + navBtn("docs", "Documents") + "</nav>" +
      '<div class="side-label">' + tr("Account") + '</div><nav>' + navBtn("rental", "Unit status") + navBtn("settings", "Settings") + "</nav>" +
      '<div class="side-foot"><div class="side-user"><span class="avatar">' + avatarInner(myPhoto(), myName()) + "</span><span><b>" + esc(myName()) + "</b><small>" + esc(myUnit()) + "</small></span></div>" +
      '<button class="side-out" onclick="doLogout()">' + icon("logout") + "<span>" + tr("Log out") + "</span></button></div></aside>" +
      '<main><div class="topline">' + searchBox("Search events, polls, documents, contacts...") +
      '<div class="top-actions"><button class="icon-btn" title="Toggle dark mode" aria-label="Toggle dark mode" onclick="toggleDarkMode()">' + icon(state.darkMode ? "sun" : "moon") + "</button>" + bellHtml() + "</div></div>" +
      '<div class="body ' + (isHome ? "with-aside" : "") + '"><div class="col">' + emergencyBanner() +
      '<div class="pagehead"><p class="kicker">' + todayLabel() + "</p><h1>" + tr(titles()[0]) + "</h1><p>" + tr(titles()[1]) + "</p></div>" + view() + "</div>" + (isHome ? homeAside() : "") + "</div></main></div>");
  });
}

/* ==========================================================================
   Home
   ========================================================================== */
function homeAside() {
  var items = newest(list("event")).map(function (r) { var e = eventInfo(r); return [esc(e.title), esc(e.place), esc(e.when)]; });
  var nb = nextBooking();
  if (nb) items.unshift([esc(nb.v.place) + " booking", esc(nb.v.status), esc(nb.v.when)]);
  return asideHtml(items.slice(0, 4), "See all events", "events");
}
// PAGE: Home.

/* "My household record": what the office keeps on file for the unit. The office edits it; it shows up here. */
function myRecordCard() {
  return '<div style="margin-top:18px">' + recordSheetHtml(myUnit(), { admin: false, email: (DB.profile || {}).email || "", button: '<button class="btn primary" onclick="recordSelfForm()">Edit my details</button>' }) + "</div>";
}
// Popup where the resident updates their own household details (the office keeps the name, mobile number and unit).
function recordSelfForm() {
  var unit = myUnit(), u = myRec();
  openForm({
    title: "Edit my details",
    intro: "Keep your household up to date. The office sees what you save. Your name, mobile number and unit are kept by the office, so ask them if one of those is wrong.",
    submit: "Save my details",
    fields: [
      { name: "members", label: "People living here (one per line, e.g. Ana Reyes, spouse). The number of people is counted from this list.", type: "textarea", value: u.members || "" },
      { name: "pets", label: "Pets", value: u.pets || "", placeholder: "e.g. 1 dog" },
      { name: "emergencyName", label: "Emergency contact name", value: u.emergencyName || "" },
      { name: "emergencyRelation", label: "Relationship", value: u.emergencyRelation || "", placeholder: "e.g. Sister" },
      { name: "emergencyPhone", label: "Emergency contact number", value: u.emergencyPhone || "" },
      { name: "vehicles", label: "Vehicles (one per line, e.g. Motorcycle · ABC 1234)", type: "textarea", value: u.vehicles || "" }
    ],
    onSubmit: async function (d) {
      var res = recMemberLines({ members: d.members }).length || "";
      var oldRec = myRec(), now = Date.now(), nv = { residents: res, members: String(d.members || "").trim(), pets: String(d.pets || "").trim(), emergencyName: String(d.emergencyName || "").trim(), emergencyRelation: String(d.emergencyRelation || "").trim(), emergencyPhone: String(d.emergencyPhone || "").trim(), vehicles: String(d.vehicles || "").trim() };
      var labels = { residents: "People living here", members: "Household members", pets: "Pets", emergencyName: "Emergency contact", emergencyRelation: "Emergency relationship", emergencyPhone: "Emergency number", vehicles: "Vehicles" };
      var entries = Object.keys(labels).filter(function (k) { return String(oldRec[k] == null ? "" : oldRec[k]) !== String(nv[k] == null ? "" : nv[k]); }).map(function (k) {
        var cut = function (x) { x = String(x == null ? "" : x).replace(/\s*\n\s*/g, ", "); return x.length > 60 ? x.slice(0, 57) + "…" : x; };
        return { field: labels[k], from: cut(oldRec[k]), to: cut(nv[k]), at: now, by: myName() };
      });
      var log = entries.concat(Array.isArray(oldRec.selfLog) ? oldRec.selfLog : []).slice(0, 20);
      await put("unit", unit, unit, Object.assign({}, oldRec, {
        selfLog: log,
        residents: res, members: String(d.members || "").trim(), pets: String(d.pets || "").trim(), emergencyName: String(d.emergencyName || "").trim(),
        emergencyRelation: String(d.emergencyRelation || "").trim(), emergencyPhone: String(d.emergencyPhone || "").trim(), vehicles: String(d.vehicles || "").trim(),
        selfUpdated: Date.now(), selfBy: myName()
      }));
      logAct("Resident updated household record, " + unit, "Units");
      toast("Saved. The office can see your updated details.");
    }
  });
}
function viewHome() {
  var u = myRec(), open = myOpenDues(), bal = balanceFor(myUnit()), next = open[0], nb = nextBooking();
  var going = list("rsvp").filter(function (r) { return r.unit === myUnit(); }).length;
  var toVote = pollsAll().filter(function (p) { return p.open && myVote(p.id) === undefined; }).length;
  var quick = [["Book a facility", "book"], ["Vote in polls", "polls"], ["See events", "events"], ["Declare unit usage", "rental"], ["Submit a complaint", "gr"]];
  var anns = publishedAnns().slice(0, 4), ns = notifs().slice(0, 5);
  var unitNo = String(myUnit()).replace(/^Unit\s*/i, "");
  return parkSoonBanner(false) + '<div class="sc-grid">' +
    summaryCard("yellow", "Dues", [[bal ? peso(bal) : "None", "Balance", "dues"], [open.length, "Open items", "dues"]], "cross", '<p class="sc-note">' + (next ? "Next due " + esc(next.v.dueDate || "on receipt") : "All dues settled") + "</p>") +
    summaryCard("pink", "Next reservation", [[nb ? esc(nb.v.place) : "None", nb ? esc(nb.v.status) : "Book a facility", nb ? "res" : "book"]], "heart", '<p class="sc-note">' + (nb ? esc(nb.v.when) : "No upcoming reservation") + "</p>") +
    summaryCard("green", "My unit", [[esc(unitNo), "Unit"], [esc(usageLabel(u.usage || "owner")), "Usage", "rental"]], "triangle", '<div class="avatar-stack"><span class="av">' + avatarInner(myPhoto(), myName()) + "</span></div>") +
    summaryCard("blue", "Community", [[toVote, "Polls to vote on", "polls"], [going, "Events going", "events"]], "burst") + "</div>" +
    myRecordCard() +
    '<div class="pills-row">' + quick.map(function (q) { return '<button onclick="set({view:\'' + q[1] + '\'})">' + q[0] + "</button>"; }).join("") + "</div>" +
    '<div class="two-lists"><section><div class="sec-head"><h2>Announcements</h2></div><div class="lrows">' +
    (anns.map(function (r, i) {
      var p = r.v;
      return '<div class="lrow ' + (i === 0 ? "sel" : "") + '"><span class="lav t' + (1 + i % 4) + '">' + esc(String(p.title).charAt(0)) + '</span><span class="lmain"><b>' + esc(p.title) + "</b><small>" + esc(p.body) + '</small></span><span class="lpill t' + (1 + i % 4) + '">' + esc(p.date) + "</span></div>";
    }).join("") || '<p class="empty">No announcements yet.</p>') + "</div></section>" +
    '<section class="panel blue"><div class="sec-head"><h2>Notifications</h2></div>' + (ns.map(function (n) { return '<div class="note' + (n[1] === "bad" ? " note-bad" : n[1] === "warn" ? " note-warn" : "") + '"><b>' + esc(n[0]) + "</b>" + (n[3] ? '<button class="btn primary" style="margin-top:8px;min-height:34px;padding:0 14px;font-size:12.5px" onclick="bellPay(\'' + escAttr(n[3]) + '\')">Pay now</button>' : "") + "</div>"; }).join("") || '<p class="empty">You are all caught up.</p>') + "</section></div>";
}

/* ==========================================================================
   Book a facility and reservations
   ========================================================================== */
var BK_ICON = {
  pool: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 17c2 0 2-1.5 4-1.5S9 17 11 17s2-1.5 4-1.5S17 17 19 17s1-.6 2-1"/><path d="M3 21c2 0 2-1.5 4-1.5S9 21 11 21s2-1.5 4-1.5S17 21 19 21s1-.6 2-1"/><path d="M8 14V6a2 2 0 013-1.7M14 14V6a2 2 0 013-1.7M8 9h6"/></svg>',
  hall: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V9l8-5 8 5v11"/><path d="M9 20v-6h6v6"/></svg>'
};
// The day chosen for booking (never in the past).
function bookDay() {
  var today = dayKey(new Date()), d = state.bookDay;
  if (!d || d < today) d = today;
  return d;
}
// The month shown in the booking calendar.
function calMonthKey() { return state.calMonth || bookDay().slice(0, 7); }
// Day key -> readable date for the booking.
function bookLabel(day) { var d = keyToDate(day); return d ? d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric", year: "numeric" }) : day; }
// The farthest day a resident may book.
function maxBookDay() { var d = new Date(); d.setDate(d.getDate() + BOOK_AHEAD_DAYS); return dayKey(d); }
// The booking calendar with free and taken days.
function bookCalendarHtml(f) {
  var mk = calMonthKey(), y = +mk.slice(0, 4), m = +mk.slice(5, 7) - 1, today = dayKey(new Date()), last = maxBookDay(), sel = bookDay();
  var first = new Date(y, m, 1), days = new Date(y, m + 1, 0).getDate(), cells = [];
  for (var b = 0; b < first.getDay(); b++) cells.push('<span class="bk-day pad"></span>');
  for (var d = 1; d <= days; d++) {
    var key = y + "-" + pad(m + 1) + "-" + pad(d), c = dayCounts(f, key), cls, sub;
    if (key < today) { cls = "past"; sub = "Past date"; }
    else if (key > last) { cls = "past"; sub = "Not open yet"; }
    else if (c.open === c.total) { cls = "vacant"; sub = c.open + " available"; }
    else if (c.open === 0) { cls = c.booked + c.closed > 0 ? "full" : "pend"; sub = c.booked + c.closed > 0 ? "Fully booked" : "Pending"; }
    else { cls = c.pending > 0 && !c.booked ? "pend" : "part"; sub = c.open + " available"; }
    var off = cls === "past";
    cells.push('<button class="bk-day ' + cls + (key === sel ? " sel" : "") + '" ' + (off ? "disabled" : 'onclick="pickDay(\'' + key + '\')"') + ' aria-label="' + esc(bookLabel(key) + ", " + sub) + '"><b>' + d + "</b><small>" + sub + "</small>" + (key === today ? "<em>Today</em>" : "") + "</button>");
  }
  var prevOk = (y + "-" + pad(m + 1)) > today.slice(0, 7), nextOk = (y + "-" + pad(m + 1)) < last.slice(0, 7);
  return '<div class="card bk-cal"><div class="bk-cal-h"><button class="pg-btn" ' + (prevOk ? "" : "disabled") + ' onclick="shiftMonth(-1)" aria-label="Previous month">←</button><h2>' + MONTHS_LONG[m] + " " + y + '</h2><button class="pg-btn" ' + (nextOk ? "" : "disabled") + ' onclick="shiftMonth(1)" aria-label="Next month">→</button></div>' +
    '<div class="bk-cal-sub"><span>' + esc(facilities()[f].name) + '</span><button class="link-btn" onclick="goToday()">Today</button></div>' +
    '<div class="bk-week">' + ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map(function (w) { return "<span>" + w + "</span>"; }).join("") + '</div><div class="bk-grid">' + cells.join("") + "</div>" +
    '<div class="bk-legend"><span class="vacant">Vacant</span><span class="part">Partly booked</span><span class="full">Occupied</span><span class="pend">Pending request</span></div>' +
    '<p class="hint" style="margin:8px 0 0">Availability is shown per ' + esc(String(facilities()[f].mins || 120)) + '-minute time slot. Pending requests hold their slot until the office reviews them.</p></div>';
}
var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
// PAGE: Book a facility.
function viewBook() {
  var fl = facilities();
  if (!fl.length) return '<div class="card"><p class="empty">No facilities can be booked yet. Please check again later.</p></div>';
  var i = Math.min(state.facIdx || 0, fl.length - 1), pick = state.pick, cur = fl[i], day = bookDay(), c = dayCounts(i, day);
  var cards = fl.map(function (f, idx) {
    var k = dayCounts(idx, day);
    return '<button id="bk-fac-' + idx + '" class="bk-fac ' + (i === idx ? "active" : "") + '" aria-pressed="' + (i === idx) + '" onclick="pickFacility(' + idx + ')"><span class="bk-fic">' + (BK_ICON[f.id] || BK_ICON.hall) + '</span><span class="bk-ftxt"><b>' + esc(f.name) + "</b><small>" + esc(f.hours) + "</small>" + (f.note ? "<small>" + esc(f.note) + "</small>" : "") +
      '<span class="bk-chips"><i class="good">' + k.open + ' vacant</i><i class="bad">' + (k.booked + k.closed) + ' occupied</i><i class="warn">' + k.pending + " pending</i></span></span>" + (i === idx ? '<span class="bk-sel">✓ Selected</span>' : "") + "</button>";
  }).join("");
  var slots = cur.slots.map(function (t, idx) {
    var st = slotState(i, idx, day), picked = pick === idx && st === "open";
    var cls = picked ? "picked" : st === "open" ? "open" : st === "pending" ? "pending" : st === "past" || st === "closed" ? "off" : "booked";
    var lab = picked ? "Selected" : st === "open" ? "Vacant" : st === "pending" ? "Pending" : st === "closed" ? ((slotBlock(i, idx, day) || {}).reason || "Unavailable") : st === "past" ? "Unavailable" : "Booked";
    return '<button class="slot ' + cls + '" ' + (st === "open" ? "" : "disabled") + (picked ? ' title="Click again to clear"' : "") + ' onclick="pickSlot(' + idx + ')"><span style="font-size:12px;font-weight:700">' + esc(t) + '</span><span style="font-size:12px">' + lab + "</span>" + (picked ? '<span class="slot-x" aria-hidden="true">×</span>' : "") + "</button>";
  }).join("");
  var req = pick != null && slotState(i, pick, day) === "open" ? '<div class="bk-req"><div><div class="bk-req-k">Your reservation request</div><div class="bk-req-v">' + esc(cur.name) + "</div><div class=\"bk-req-s\">" + esc(bookLabel(day)) + " · " + esc(cur.slots[pick]) + '</div></div><div class="bk-req-b"><button class="btn primary" onclick="submitBooking()">Request this time</button><button class="btn" style="font-size:20px;line-height:1;min-width:44px;padding:0" aria-label="Clear selection" title="Clear selection" onclick="clearPick()">×</button></div></div>' : '<p class="hint" style="margin:6px 0 0">Pick an open time to send a request.</p>';
  return '<div class="bk-wrap"><div class="bk-facs" onkeydown="onFacKey(event)">' + cards + '</div><p class="hint" style="margin:0">Slot counts for ' + esc(bookLabel(day)) + ". Select a facility, date, and available time.</p>" +
    '<div class="bk-cols">' + bookCalendarHtml(i) +
    '<div class="card bk-day-card"><h2 style="font-size:19px">' + esc(cur.name) + '</h2><p class="hint" style="margin:2px 0 10px">' + esc(bookLabel(day)) + '</p><label class="dz-lab">Choose a date<input type="date" min="' + dayKey(new Date()) + '" max="' + maxBookDay() + '" value="' + day + '" onchange="pickDay(this.value)"></label>' +
    (cur.note ? '<div class="bk-note">' + esc(cur.note) + "</div>" : "") + '<div class="slots bk-slots">' + (slots || '<p class="empty">No times are set up for this amenity.</p>') + "</div>" + req + '<p class="hint" style="margin:0">Reservations are subject to approval by the office.</p></div></div></div>';
}
// Chooses a facility to book.
function pickFacility(idx) { state.facIdx = idx; state.pick = null; render(); }
/* arrow keys, Home and End move between the facility cards */
function onFacKey(e) {
  var n = facilities().length, cur = Math.min(state.facIdx || 0, n - 1), next = cur;
  if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (cur + 1) % n;
  else if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (cur + n - 1) % n;
  else if (e.key === "Home") next = 0;
  else if (e.key === "End") next = n - 1;
  else return;
  e.preventDefault();
  pickFacility(next);
  var el = document.getElementById("bk-fac-" + next); if (el) el.focus();
}
// Chooses a day in the booking calendar.
function pickDay(key) {
  var today = dayKey(new Date());
  if (!keyToDate(key)) return;
  if (key < today) key = today;
  if (key > maxBookDay()) key = maxBookDay();
  state.bookDay = key; state.calMonth = key.slice(0, 7); state.pick = null; render();
}
// Goes to the previous or next month in the calendar.
function shiftMonth(n) {
  var mk = calMonthKey(), d = new Date(+mk.slice(0, 4), +mk.slice(5, 7) - 1 + n, 1);
  state.calMonth = d.getFullYear() + "-" + pad(d.getMonth() + 1); render();
}
// Jumps the calendar back to today.
function goToday() { pickDay(dayKey(new Date())); }
// Chooses a time slot.
function pickSlot(idx) { state.pick = state.pick === idx ? null : idx; render(); }
// Clears the chosen time slot.
function clearPick() { state.pick = null; render(); }
// Sends the booking request. The database blocks a double booking of the same slot.
async function submitBooking() {
  if (state.pick == null) return;
  var f = state.facIdx, i = state.pick, unit = myUnit(), fac = facilities()[f], day = bookDay(), date = keyToDate(day);
  if (!fac || !fac.slots[i] || !date) { state.pick = null; return render(); }
  if (slotState(f, i, day) !== "open") { toast("That time is no longer available."); state.pick = null; return render(); }
  var id = nextId();
  DB.busy = true;
  try {
    await put("booking", id, unit, { id: id, who: myHousehold(), unit: unit, place: fac.name, when: shortDate(date) + ", " + fac.slots[i], status: "Pending", day: day, slot: i });
    logAct("Booking request for the " + fac.name + " on " + shortDate(date) + ", " + unit, "Facilities");
    toast("Request sent. You will see it under My reservations once the office decides.");
  } catch (e) {
    toast(errText(e));
    await loadAll().catch(function () {});
  }
  DB.busy = false; state.pick = null; render();
}
// Cancels my booking.
function cancelBooking(id) {
  confirmBox("Cancel this reservation?", "The time becomes free for others.", "Cancel reservation", async function () { await del("booking", id); }, true);
}
// Downloads my reservations as CSV.
function exportMyReservations() {
  exportCSV("my-reservations.csv", ["Facility", "Date & time", "Status"], myBookings().map(function (r) { return [r.v.place, r.v.when, r.v.status]; }));
}
// PAGE: My reservations.
function viewRes() {
  var rows = myBookings().map(function (r) {
    var b = r.v;
    return '<tr><td style="font-weight:700">' + esc(b.place) + '</td><td style="color:var(--muted)">' + esc(b.when) + '</td><td><span class="chip ' + chipFor(b.status) + '">' + esc(b.status) + '</span></td><td>' +
      (b.status === "Pending" || b.status === "Approved" ? '<button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="cancelBooking(\'' + escAttr(r.id) + '\')">Cancel</button>' : "") + "</td></tr>";
  });
  return '<div class="card" style="padding:0;overflow:hidden"><div style="display:flex;justify-content:flex-end;padding:12px 18px"><button class="btn" onclick="exportMyReservations()">Export to Excel (.csv)</button></div>' +
    (rows.length ? '<table><thead><tr><th>FACILITY</th><th>DATE &amp; TIME</th><th>STATUS</th><th></th></tr></thead><tbody>' + rows.join("") + "</tbody></table>" : '<div style="padding:22px;text-align:center;color:var(--muted)">You have not made any reservation yet.</div>') + "</div>";
}

/* ==========================================================================
   Dues, payments and motor parking
   ========================================================================== */
/* ---- Dues: ring, payment trail, charge cards and a three-step pay panel ---- */
var DZ_ICON = {
  paid: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  bad: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 7v6M12 17h.01"/></svg>',
  wait: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/></svg>',
  open: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="6" width="16" height="12" rx="3"/><path d="M4 10h16"/></svg>',
  park: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4" width="16" height="16" rx="4"/><path d="M10 16V8h3a2.5 2.5 0 010 5h-3"/></svg>'
};
/* "Due in 3 days" / "Overdue by 2 days" for a charge with a due date */
function dueCountdown(d) {
  var x = d.dueDate ? parseShort(d.dueDate) : null;
  if (!x) return null;
  var t0 = new Date(); t0 = new Date(t0.getFullYear(), t0.getMonth(), t0.getDate()).getTime();
  var n = Math.round((new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime() - t0) / 86400000);
  if (n < 0) return { n: n, tone: "bad", text: "Overdue by " + (-n) + " day" + (n === -1 ? "" : "s") };
  if (n === 0) return { n: n, tone: "warn", text: "Due today" };
  return { n: n, tone: n <= 3 ? "warn" : "info", text: "Due in " + n + " day" + (n === 1 ? "" : "s") };
}
/* one entry per charge, plus the parking reservation that is waiting to be paid */
function dueItems() {
  var proofs = myProofs(), items = myDues().map(function (r) {
    var d = r.v, pend = proofs.filter(function (p) { return p.v.status === "Pending" && p.v.forText === d.note; })[0], pending = !!pend;
    var conf = proofs.filter(function (p) { return p.v.status === "Confirmed" && p.v.forText === d.note; })[0];
    var st = d.paid ? "paid" : pending ? "pending" : isOverdue(d) ? "overdue" : "open";
    return { id: r.id, title: d.note, amount: Number(d.amount || 0), due: d.dueDate || "", st: st, d: d, billed: billedOn(r.id, d), receipt: conf ? conf.id : "", sent: pend ? proofSentAt(pend.v) : 0, mon: (d.dueDate && parseShort(d.dueDate)) ? MONTHS[parseShort(d.dueDate).getMonth()] : "" };
  });
  var prq = getRow("request", myUnit());
  var hasParkDue = items.some(function (i) { return i.title === PARK_FOR && i.st !== "paid"; });   // one parking item only: the charge the office billed
  if (prq && prq.value.slot && prq.value.amount && !prq.value.confirmed && !hasParkDue) {
    var pp = parkProof(myUnit(), prq.value.slot);
    items.unshift({ id: "parking", title: "Motor parking rental · " + prq.value.slot + " · " + parkPlanText(prq.value.plan, prq.value.days), amount: Number(prq.value.amount), due: "On reservation", st: pp ? (pp.v.status === "Confirmed" ? "paid" : "pending") : "open", d: {}, receipt: "", mon: "P", park: true });
  }
  return items;
}
// One card for a due (paid, open, overdue or pending).
function dueCardHtml(it) {
  var cd = it.st === "open" || it.st === "overdue" ? dueCountdown(it.d) : null;
  var tone = it.st === "paid" ? "good" : it.st === "overdue" ? "bad" : it.st === "pending" ? "warn" : "info";
  var ic = it.park ? DZ_ICON.park : it.st === "paid" ? DZ_ICON.paid : it.st === "overdue" ? DZ_ICON.bad : it.st === "pending" ? DZ_ICON.wait : DZ_ICON.open;
  var label = it.st === "paid" ? "Paid" : it.st === "overdue" ? "Overdue" : it.st === "pending" ? "Payment sent" : "To pay";
  var wait = it.st === "pending" && it.sent ? (autoPostCfg().on ? "Posts to your dues by " + clockText(it.sent + autoPostCfg().hours * 3600000) + " at the latest" : "Waiting for the office to verify it") : "";
  var act = it.st === "paid" ? (it.receipt ? '<button class="btn dz-mini" onclick="receiptFor(\'proof\',\'' + escAttr(it.receipt) + '\')">Receipt</button>' : "")
    : it.st === "pending" ? ""
    : '<button class="btn primary dz-mini" onclick="payThis(\'' + escAttr(it.id) + '\')">Pay ' + peso(it.amount).replace(/\.00$/, "") + "</button>";
  return '<div class="dz-item ' + tone + (state.dzFlash === it.id ? " flash" : "") + '" data-due="' + escAttr(it.id) + '"><span class="dz-ic ' + tone + '">' + ic + '</span><div class="dz-main"><b>' + esc(it.title) + '</b><div class="dz-sub"><span class="chip ' + (tone === "info" ? "info" : tone) + '">' + label + "</span>" +
    (it.due ? '<span class="dz-date">' + esc(it.due) + "</span>" : "") + (it.billed ? '<span class="dz-date" title="The day the office billed this charge">Billed ' + esc(it.billed) + "</span>" : "") + (cd ? '<span class="dz-cd ' + cd.tone + '">' + esc(cd.text) + "</span>" : "") + '</div>' + (wait ? '<small class="dz-wait">' + esc(wait) + "</small>" : "") + '</div><div class="dz-end"><div class="dz-amt">' + peso(it.amount) + "</div>" + act + "</div></div>";
}
// PAGE: Dues and payments.
// "Your monthly dues": how the unit's dues are worked out, and what it has been billed, has paid and still owes.
function unitDuesHtml() {
  var x = unitDues(myUnit());
  if (!(x.area > 0) || !(x.rate > 0)) return "";
  return '<div class="card"><h2 style="font-size:19px;margin-bottom:4px">Your monthly dues</h2><p style="margin:0 0 10px;font-size:13px;color:var(--muted)">Dues are charged per square meter of your unit.</p>' +
    '<div class="kv" style="font-size:13.5px"><span>Floor area</span><b>' + esc(String(x.area)) + ' sqm</b><span>Rate</span><b>' + peso(x.rate) + ' per sqm</b><span>Monthly dues</span><b>' + peso(x.monthly) + '</b><span>Total billed</span><b>' + peso(x.billed) + '</b><span>Paid so far</span><b>' + peso(x.paid) + '</b><span>Balance</span><b>' + (x.balance ? peso(x.balance) : "None") + "</b></div></div>";
}
function viewDues() {
  var items = dueItems(), bal = balanceFor(myUnit());
  var prq = getRow("request", myUnit()), parkOpen = items.filter(function (i) { return i.park && i.st === "open"; })[0];
  var total = items.length, paid = items.filter(function (i) { return i.st === "paid"; }).length;
  var todo = items.filter(function (i) { return i.st !== "paid"; }), overdue = items.filter(function (i) { return i.st === "overdue"; });
  var owed = todo.reduce(function (s, i) { return s + i.amount; }, 0);  /* includes a parking reservation */
  var pct = total ? paid / total : 1, R = 52, C = 2 * Math.PI * R;
  var sig = owed + "|" + paid + "|" + total, fresh = state.dzSig !== sig; state.dzSig = sig;
  var tab = state.duesTab || (todo.length ? "todo" : "all");
  var shown = items.filter(function (i) { return tab === "all" || (tab === "paid") === (i.st === "paid"); });
  var next = todo.map(function (i) { return { i: i, c: dueCountdown(i.d) }; }).filter(function (x) { return x.c; }).sort(function (a, b) { return a.c.n - b.c.n; })[0];
  var mood = !total ? "No charges yet. Nothing to pay." : !todo.length ? "You are all paid up. Thank you!" : overdue.length ? overdue.length + " overdue. Pay soon to catch up." : next && next.c.n >= 0 ? next.c.text.replace("Due", "Next charge is due") + "." : "Almost there. " + todo.length + " to go.";
  var badges = [];
  if (total && !todo.length) badges.push('<span class="dz-badge good">All paid up</span>');
  if (total && !overdue.length) badges.push('<span class="dz-badge good">No overdue</span>');
  if (paid) badges.push('<span class="dz-badge">' + paid + " paid</span>");
  if (todo.length) badges.push('<span class="dz-badge warn">' + todo.length + " to pay</span>");
  var hero = '<div class="card dz-hero' + (fresh ? " fresh" : "") + (!todo.length && total ? " done" : "") + '"><button class="dz-ring" title="' + (total ? "Tap me" : "") + '" onclick="dzPop(event)" aria-label="' + paid + " of " + total + ' charges paid"><svg viewBox="0 0 120 120"><circle class="bg" cx="60" cy="60" r="' + R + '"/><circle class="fg" cx="60" cy="60" r="' + R + '" stroke-dasharray="' + (pct * C).toFixed(1) + " " + C.toFixed(1) + '" transform="rotate(-90 60 60)"/></svg><span><b>' + paid + "/" + total + "</b><small>paid</small></span></button>" +
    '<div class="dz-hero-main"><div class="dz-eyebrow">' + (todo.length ? "You owe" : "Balance") + '</div><div class="dz-big' + (todo.length ? "" : " zero") + '"><span class="dz-count"' + (fresh ? ' data-to="' + owed + '"' : "") + ">" + (todo.length ? peso(owed) : "₱0") + '</span></div><p class="dz-mood">' + esc(mood) + '</p><div class="dz-badges">' + badges.join("") + "</div>" +
    (todo.length ? '<div class="dz-cta"><button class="btn primary" onclick="payThis(\'' + escAttr(todo.slice().sort(function (a, b) { return (b.st === "overdue") - (a.st === "overdue"); })[0].id) + '\')">Pay now</button><button class="btn" onclick="exportMyDues()">Export (.csv)</button></div>' : '<div class="dz-cta"><button class="btn" onclick="dzPop(event)">Celebrate</button><button class="btn" onclick="exportMyDues()">Export (.csv)</button></div>') + "</div>" + payFlowHtml(todo.length) + "</div>";
  var trail = items.filter(function (i) { return !i.park; }).slice(0, 12).reverse();
  var trailHtml = trail.length > 1 ? '<div class="card dz-trail"><div class="dz-trail-h"><h2>Your payment trail</h2><span class="hint" style="margin:0">Tap a block to jump to it</span></div><div class="dz-blocks">' + trail.map(function (i) {
    var tone = i.st === "paid" ? "good" : i.st === "overdue" ? "bad" : i.st === "pending" ? "warn" : "info";
    return '<button class="dz-block ' + tone + '" onclick="focusDue(\'' + escAttr(i.id) + '\')" title="' + escAttr(i.title + " · " + peso(i.amount)) + '"><i>' + (i.st === "paid" ? DZ_ICON.paid : i.st === "overdue" ? DZ_ICON.bad : i.st === "pending" ? DZ_ICON.wait : DZ_ICON.open) + "</i><small>" + esc(i.mon || "·") + "</small></button>";
  }).join("") + "</div></div>" : "";
  var tabs = pageTabs([["todo", "To pay (" + todo.length + ")"], ["paid", "Paid (" + paid + ")"], ["all", "All (" + total + ")"]], tab, "duesTab");
  var list_ = shown.length ? shown.map(dueCardHtml).join("") : '<div class="dz-empty"><b>' + (tab === "paid" ? "Nothing paid yet" : tab === "todo" ? "Nothing to pay" : "No charges yet") + "</b><span>" + (tab === "todo" ? "You are all caught up. Enjoy your day!" : tab === "paid" ? "Paid charges and their receipts show up here." : "Charges from the office show up here.") + "</span></div>";
  setTimeout(duesFx, 30);
  return '<div class="dz-wrap">' + duesAlertHtml(items) + hero + trailHtml + '<div class="two-col dz-cols" style="grid-template-columns:minmax(0,1.5fr) minmax(0,1fr)"><div class="dz-left">' + tabs + '<div class="dz-list">' + list_ + "</div>" + myPaymentsHtml() + parkingLinkHtml() + "</div>" +
    '<div class="dz-right">' + unitDuesHtml() + payFormHtml() + "</div></div></div>";
}
// The "what happens next" strip in the hero: pay, send the proof, the office checks it, the receipt appears.
function payFlowHtml(owing) {
  var ap = autoPostCfg();
  var steps = [["1", "Pay", "At the office, or by GCash, Maya or bank."], ["2", "Send your proof", "Reference number and a photo of your payment."], ["3", "The office checks it", ap.on ? "Posted by itself within " + ap.hours + " hours if it matches." : "The office verifies it."], ["4", "Receipt", "Your dues go down and your receipt appears."]];
  return '<div class="dz-flow' + (owing ? "" : " calm") + '" aria-label="How paying works">' + steps.map(function (x) { return '<div class="dz-fs"><span>' + x[0] + "</span><b>" + x[1] + "</b><small>" + x[2] + "</small></div>"; }).join("") + "</div>";
}
// A notice at the top of the page when a charge is overdue or due within 2 days, with a Pay button.
function duesAlertHtml(items) {
  var over = items.filter(function (i) { return i.st === "overdue" && !i.park; }), soon = items.filter(function (i) { if (i.st !== "open" || i.park) return false; var c = dueCountdown(i.d); return c && c.n >= 0 && c.n <= 2; });
  var sent = items.filter(function (i) { return i.st === "pending" && !i.park; });
  var html = "";
  over.forEach(function (i) {
    var c = dueCountdown(i.d);
    html += '<div class="dz-alert bad"><span class="dz-alert-ic">!</span><div><b>Overdue' + (c ? " by " + (-c.n) + " day" + (c.n === -1 ? "" : "s") : "") + ": " + esc(i.title) + '</b><small>' + peso(i.amount) + " was due " + esc(i.due) + ". Pay it now and send your proof so the office can check it.</small></div><button class=\"btn primary\" onclick=\"payThis('" + escAttr(i.id) + "')\">Pay " + peso(i.amount).replace(/\.00$/, "") + "</button></div>";
  });
  soon.forEach(function (i) {
    var c = dueCountdown(i.d);
    html += '<div class="dz-alert ' + (c.n === 0 ? "bad" : "warn") + '"><span class="dz-alert-ic">⏰</span><div><b>' + esc(i.title) + " is due " + (c.n === 0 ? "TODAY" : c.n === 1 ? "tomorrow" : "in 2 days") + '</b><small>' + peso(i.amount) + " · " + esc(i.due) + (c.n === 0 ? ". Please pay within the day and send your proof before it ends, so your dashboard updates. Already paid at the office? The office records it right away." : ". Send your proof before the due date so your dashboard updates.") + "</small></div><button class=\"btn primary\" onclick=\"payThis('" + escAttr(i.id) + "')\">" + (c.n === 0 ? "Pay and send proof" : "Pay now") + "</button></div>";
  });
  if (sent.length) html += '<div class="dz-alert info"><span class="dz-alert-ic">✓</span><div><b>' + sent.length + " payment" + (sent.length === 1 ? "" : "s") + ' sent, waiting for the office</b><small>You will get a notice and a receipt as soon as it is checked.</small></div></div>';
  return html ? '<div class="dz-alerts">' + html + "</div>" : "";
}
/* count the balance up, and throw confetti the first time the page shows a clear balance */
function duesFx() {
  var el = document.querySelector(".dz-count[data-to]"), reduce = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (el && !reduce) {
    var to = Number(el.getAttribute("data-to")), t0 = performance.now(), final = el.textContent;
    el.removeAttribute("data-to");
    (function tick(now) {
      var k = Math.min(1, (now - t0) / 800), e = 1 - Math.pow(1 - k, 3);
      el.textContent = k < 1 ? peso(Math.round(to * e)) : final;
      if (k < 1) requestAnimationFrame(tick);
    })(t0);
  } else if (el) el.removeAttribute("data-to");
  var hero = document.querySelector(".dz-hero.done.fresh");
  if (hero && !reduce) { hero.classList.remove("fresh"); confetti(hero); }
}
// Small confetti animation when everything is paid.
function confetti(from) {
  var r = from.getBoundingClientRect(), cols = ["#F4D84E", "#F6B7D8", "#AAB968", "#B6C7EC", "#D9A953"], box = document.createElement("div");
  box.className = "dz-confetti"; box.style.cssText = "left:" + (r.left + 70) + "px;top:" + (r.top + 70) + "px";
  for (var i = 0; i < 34; i++) {
    var c = document.createElement("i"), ang = Math.random() * Math.PI * 2, dist = 70 + Math.random() * 130;
    c.style.cssText = "background:" + cols[i % cols.length] + ";--x:" + Math.cos(ang) * dist + "px;--y:" + (Math.sin(ang) * dist - 40) + "px;--r:" + Math.round(Math.random() * 720 - 360) + "deg;animation-delay:" + (Math.random() * 80) + "ms";
    box.appendChild(c);
  }
  document.body.appendChild(box);
  setTimeout(function () { if (box.parentNode) box.parentNode.removeChild(box); }, 1700);
}
// Pop animation on the dues ring.
function dzPop(ev) {
  var b = ev && ev.currentTarget; if (!b) return;
  var hero = b.closest(".dz-hero") || b; confetti(hero);
  var ring = hero.querySelector(".dz-ring"); if (ring) { ring.classList.remove("pop"); void ring.offsetWidth; ring.classList.add("pop"); }
}
/* Pay button on a charge: pick it in the pay panel and bring the panel into view */
function payThis(id) {
  var it = dueItems().filter(function (i) { return i.id === id; })[0];
  state.payFor = id === "parking" ? "parking" : id;
  state.payAmt = it ? String(it.amount) : "";
  state.payPulse = true;
  render();
  var el = document.getElementById("payPanel");
  if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
}
// Scrolls to and highlights one due.
function focusDue(id) {
  state.duesTab = "all"; state.dzFlash = id; render();
  var el = document.querySelector('[data-due="' + id + '"]');
  if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
  setTimeout(function () { state.dzFlash = ""; var e = document.querySelector('[data-due="' + id + '"]'); if (e) e.classList.remove("flash"); }, 1600);
}
// Chooses the payment method.
function pickMethod(name) { state.payMethod = name; render(); }
// Downloads my dues as CSV.
function exportMyDues() {
  exportCSV("my-dues.csv", ["Charge", "Amount", "Due date", "Status"], myDues().map(function (r) { return [r.v.note, r.v.amount, r.v.dueDate || "", r.v.paid ? "Paid" : "Unpaid"]; }));
}
// Chooses which due I am paying.
function choosePayFor(v) {
  state.payFor = v;
  var r = dueItems().filter(function (x) { return x.id === v; })[0];
  state.payPulse = !!v;
  state.payAmt = r ? String(r.amount) : "";
  render();
}
function isoDay(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); }
// One line for the charge picker: what it is, how much, and when it is due.
function payOptionText(i) {
  var c = i.park ? null : dueCountdown(i.d);
  return i.title + " · " + peso(i.amount) + (i.park ? " · due on reservation" : i.due ? " · due " + i.due + (c && c.n < 0 ? " (overdue)" : "") : " · due upon receipt");
}
// The facts about the charge picked in the pay form, so the resident can check it is the right one.
function payChargeHtml(i) {
  if (!i) return "";
  var c = i.park ? null : dueCountdown(i.d), tone = c && c.n < 0 ? "bad" : c && c.n <= 2 ? "warn" : "info";
  return '<div class="dz-chg"><div><small>Charge</small><b>' + esc(i.title) + '</b></div><div><small>Amount to pay</small><b>' + peso(i.amount) + '</b></div><div><small>Due date</small><b>' + esc(i.dueText || (i.park ? "On reservation" : i.due || "Upon receipt")) + '</b></div>' +
    (c ? '<div><small>Status</small><span class="chip ' + tone + '">' + esc(c.text) + "</span></div>" : "") + (i.billed ? '<div><small>Billed</small><b>' + esc(i.billed) + "</b></div>" : "") + "</div>";
}
// The form to send a payment proof.
function payFormHtml(fixed) {
  var payable = dueItems().filter(function (i) { return i.st === "open" || i.st === "overdue"; }), chosen = fixed || payable.filter(function (i) { return i.id === state.payFor; })[0];
  var todayISO = isoDay(new Date()); if (!state.payDate) state.payDate = todayISO;
  var methods = payMethods().filter(function (m) { return m.enabled; });
  if (!methods.length) methods = [{ name: PAY_OFFICE, details: "Pay at the administration office." }];
  if (!state.payMethod || !methods.some(function (m) { return m.name === state.payMethod; })) state.payMethod = (methods.filter(function (m) { return m.name !== PAY_OFFICE; })[0] || methods[0]).name;
  var cur = methods.filter(function (m) { return m.name === state.payMethod; })[0], step = !state.payFor ? 1 : 2, walkIn = state.payMethod === PAY_OFFICE;
  var pulse = state.payPulse; state.payPulse = false;
  return '<div class="card dz-pay' + (pulse ? " pulse" : "") + '" id="payPanel"><h2 style="font-size:19px;margin:0">' + (fixed ? (fixed.renew ? "Renew your parking slot" : "Pay for your parking slot") : "I have paid") + '</h2>' +
    '<p style="margin:0;font-size:13px;color:var(--muted);line-height:1.5">' + (fixed ? "Pay with GCash, Maya or bank transfer, then send the details here with a screenshot of your payment. The office checks it and confirms your rental. Prefer to pay at the office? Choose Walk-in and tell the office you are coming." : "Paid online? Send the details here, with a photo of your payment if you have one. Paid at the office? Nothing to send; the office records it.") + '</p>' +
    (fixed ? '<div class="dz-step"><span class="n ok">✓</span><div style="width:100%">' + payChargeHtml(chosen) + "</div></div>" :
    '<div class="dz-step"><span class="n ' + (state.payFor ? "ok" : "") + '">' + (state.payFor ? "✓" : "1") + '</span><div style="width:100%"><label class="dz-lab">What did you pay for?<select onchange="choosePayFor(this.value)"><option value="">' + (payable.length ? "Choose one of your charges…" : "You have no unpaid charges") + "</option>" + payable.map(function (i) { return '<option value="' + escAttr(i.id) + '" ' + (state.payFor === i.id ? "selected" : "") + ">" + esc(payOptionText(i)) + "</option>"; }).join("") + "</select></label>" + payChargeHtml(chosen) + "</div></div>") +
    '<div class="dz-step"><span class="n ok">2</span><div><div class="dz-lab">How did you pay?</div><div class="dz-methods">' + methods.map(function (m) {
      return '<button type="button" class="dz-method ' + (state.payMethod === m.name ? "on" : "") + '" onclick="pickMethod(\'' + escAttr(m.name) + '\')">' + esc(m.name === PAY_OFFICE ? "Walk-in (pay at the office)" : m.name) + "</button>";
    }).join("") + '</div><div class="dz-how"><b>' + esc(cur.name === PAY_OFFICE ? "Walk-in" : cur.name) + '</b><span>' + esc(cur.details || "") + "</span></div></div></div>" +
    (walkIn && fixed ? walkBlockHtml(fixed) : walkIn ? '<div class="dz-step"><span class="n ok">3</span><div class="dz-walk"><b>Nothing to send for a walk-in payment</b><span>Pay at the counter. The office records it, issues your receipt and your dues go down on this page. If you paid online (GCash, Maya or bank), choose that method above and add a photo of your payment.</span></div></div>' :
    '<div class="dz-step"><span class="n ' + (state.payFor && state.payRef.trim().length >= 4 ? "ok" : "") + '">3</span><div style="display:flex;flex-direction:column;gap:10px;width:100%"><label class="dz-lab">Amount paid (₱)<input id="payAmt" type="number" min="0.01" step="0.01" placeholder="e.g. 450" value="' + escAttr(state.payAmt) + '" oninput="state.payAmt=this.value"></label>' +
    '<label class="dz-lab">Date you paid<input id="payDate" type="date" max="' + todayISO + '" value="' + escAttr(state.payDate) + '" oninput="state.payDate=this.value"></label>' +
    '<label class="dz-lab">Reference number<input id="payRef" type="text" placeholder="Number on your receipt or transaction" value="' + escAttr(state.payRef) + '" oninput="state.payRef=this.value"></label>' +
    '<div class="dz-lab">Photo of your payment <small style="font-weight:400;color:var(--muted)">(screenshot or receipt, optional)</small>' +
    (state.payImg ? '<div class="dz-photo"><img alt="Your payment photo" src="' + escAttr(state.payImg) + '" onclick="viewImage(state.payImg,\'Your payment photo\')"><div><button class="btn dz-mini" type="button" onclick="payPickImage()">Change</button> <button class="btn dz-mini" type="button" onclick="state.payImg=\'\';render()">Remove</button></div></div>'
      : '<button class="btn dz-addphoto" type="button" onclick="payPickImage()">+ Add a photo of your payment</button>') +
    '<small style="display:block;margin-top:4px;color:var(--muted);font-weight:400">' + (fixed ? "Add the screenshot so the office can confirm your rental faster." : "It helps the office check your payment faster.") + '</small></div></div></div>') +
    (walkIn ? "" : '<button class="btn primary dz-send" onclick="submitPaymentProof()">Send payment details</button>') + "</div>";
}
// Chooses the photo of an online payment (shrunk so it fits).
async function payPickImage() {
  var d = await pickImage(1000, 0.72);
  if (d) { state.payImg = d; render(); }
}
// The instructions on how to pay.
function howToPayHtml() {
  var ms = payMethods().filter(function (m) { return m.enabled; });
  return '<div class="card"><h2 style="font-size:17px;margin-bottom:8px">How to pay</h2>' + ms.map(function (m) {
    return '<div style="padding:8px 0;border-top:1px solid var(--border2)"><b style="font-size:14px">' + esc(m.name) + '</b><div style="font-size:12.5px;color:var(--muted);white-space:pre-line">' + esc(m.details) + "</div></div>";
  }).join("") + "</div>";
}
// Sends the payment proof (the admin verifies it).
function submitPaymentProof() {
  if (state.payMethod === PAY_OFFICE) return toast("Walk-in payments are recorded by the office. Tap \"I'll walk in today\" so the office expects you.");
  var amount = parseFloat(state.payAmt), ref = state.payRef.trim();
  if (!state.payFor) return toast("Choose what the payment is for.");
  if (!(amount > 0)) return toast("Enter the amount you paid.");
  if (ref.length < 4) return toast("Enter the reference number from your receipt or transaction.");
  var pd = /^(\d{4})-(\d{2})-(\d{2})$/.exec(state.payDate || ""), paidDay = pd ? new Date(+pd[1], +pd[2] - 1, +pd[3]) : null;
  if (!paidDay || isNaN(paidDay.getTime())) return toast("Enter the date you paid.");
  if (paidDay.getTime() > Date.now()) return toast("The date you paid cannot be in the future.");
  var open = myOpenDues().filter(function (x) { return x.id === state.payFor; })[0];
  var renewing = state.payFor === "parking-renew", mineSlot = renewing ? list("slot").filter(function (s) { return s.v.unit === myUnit(); })[0] : null;
  if (renewing && !mineSlot) return toast("You do not have a parking slot to renew.");
  if (renewing && renewProofOf(myUnit(), mineSlot.id)) return toast("Your renewal payment was already sent. The office will check it.");
  var forText = open ? open.v.note : (state.payFor === "parking" || renewing) ? PARK_FOR : "Other charge";
  if (myProofs().some(function (p) { return p.v.status !== "Rejected" && String(p.v.reference).toLowerCase() === ref.toLowerCase() && p.v.method === state.payMethod; })) return toast("That reference number was already submitted.");
  act(async function () {
    var id = nextId();
    var proofRec = { id: id, unit: myUnit(), payer: myHousehold(), forText: forText, method: state.payMethod, reference: ref, amount: amount, date: shortDate(new Date()), at: Date.now(), status: "Pending", paidOn: shortDate(paidDay) };
    if (state.payImg) proofRec.image = state.payImg;
    var prq = getRow("request", myUnit());
    if (forText === PARK_FOR && prq && prq.value.slot && !renewing) proofRec.slot = prq.value.slot;
    if (renewing) { proofRec.slot = mineSlot.id; proofRec.renew = true; }
    await put("proof", id, myUnit(), proofRec);
    logAct("Payment reference sent, " + myUnit(), "Finance");
    state.payFor = ""; state.payAmt = ""; state.payRef = ""; state.payImg = ""; state.payDate = ""; state.parkRenew = false;
    var ap = autoPostCfg();
    toast(ap.on ? "Payment details sent. It will be posted to your dues automatically by " + clockText(Date.now() + ap.hours * 3600000) + ", and your receipt will appear here." : "Payment details sent. The office will verify them and your receipt will appear here.");
  });
}
// My payment history: each payment shows where it is (sent, checked by the office, receipt).
function myPaymentsHtml() {
  var l = myProofs(), ap = autoPostCfg();
  var cards = l.map(function (r) {
    var p = r.v, st = p.status, sent = proofSentAt(p);
    var s2 = st === "Pending" ? "now" : st === "Rejected" ? "bad" : "done", s3 = st === "Confirmed" ? "done" : "";
    var msg2 = st === "Pending" ? (ap.on ? "Posts automatically by " + clockText(sent + ap.hours * 3600000) + " if it matches" : "Waiting for the office to verify it") : st === "Rejected" ? "Rejected" + (p.reason ? ": " + String(p.reason).replace(/[.\s]+$/, "") : "") : (p.auto ? "Posted automatically" : "Verified by the office") + (p.confirmedOn ? " · " + p.confirmedOn : "");
    return '<div class="pt-card ' + (st === "Rejected" ? "bad" : st === "Confirmed" ? "good" : "warn") + '"><div class="pt-top"><div><b>' + esc(p.forText || "Payment") + '</b><small>' + esc(p.method) + " · Ref " + esc(p.reference) + " · " + peso(Number(p.amount)) + (p.paidOn ? " · paid " + esc(p.paidOn) : "") + '</small></div><span class="chip ' + chipFor(st) + '">' + esc(st === "Confirmed" ? (p.auto ? "Posted" : "Verified") : st === "Pending" ? "In review" : statusText(st)) + "</span></div>" +
      '<ol class="pt-trail"><li class="done"><i>✓</i><span><b>Sent</b><small>' + esc(p.date || "") + "</small></span></li><li class=\"" + s2 + "\"><i>" + (s2 === "done" ? "✓" : s2 === "bad" ? "✕" : "2") + "</i><span><b>Office check</b><small>" + esc(msg2) + "</small></span></li><li class=\"" + s3 + "\"><i>" + (s3 ? "✓" : "3") + "</i><span><b>Receipt</b><small>" + (p.receiptNo ? esc(p.receiptNo) : "After it is checked") + "</small></span></li></ol>" +
      '<div class="pt-act">' + (p.image ? '<button class="btn dz-mini" type="button" onclick="viewProofImage(\'' + escAttr(r.id) + '\')">View my photo</button>' : "") + (st === "Confirmed" ? '<button class="btn dz-mini" onclick="receiptFor(\'proof\',\'' + escAttr(r.id) + '\')">Receipt</button>' : "") + (st === "Rejected" ? '<button class="btn primary dz-mini" onclick="payAgain(\'' + escAttr(r.id) + '\')">Send again</button>' : "") + "</div></div>";
  }).join("");
  return '<div class="card"><h2 style="font-size:19px;margin:0 0 4px">My payments</h2><p style="margin:0 0 12px;font-size:13px;color:var(--muted)">Everything you sent, and where it is. The office checks each one before it counts.</p>' + (cards || '<p style="margin:0;font-size:13px;color:var(--muted)">Nothing sent yet. After you pay, send your details in the box on this page.</p>') + "</div>";
}
// "Send again" on a rejected payment: the form is filled with the same charge, method and amount.
function payAgain(id) {
  var p = getRow("proof", id); if (!p) return;
  var d = myOpenDues().filter(function (x) { return x.v.note === p.value.forText; })[0];
  state.payFor = p.value.forText === PARK_FOR ? "parking" : d ? d.id : "other";
  state.payMethod = p.value.method; state.payAmt = String(p.value.amount || ""); state.payRef = ""; state.payImg = ""; state.payDate = ""; state.payPulse = true;
  render();
  var el = document.getElementById("payPanel"); if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
}
// Parking slots in natural order.
function slotsSorted() { return list("slot").sort(function (a, b) { return naturalCompare(a.id, b.id); }); }
// The parking summary card shown on the dues page.
function parkingLinkHtml() {
  var mine = slotsSorted().filter(function (s) { return s.v.unit === myUnit(); })[0], rq = getRow("request", myUnit());
  var pick = rq && rq.value.slot, proof = pick ? parkProof(myUnit(), pick) : null;
  var text = mine ? "Your slot is <b>" + esc(mine.id) + "</b> · " + esc(parkRentalLine(mine.v) || "Monthly") + (parkExpired(mine.v) ? " (ended)" : "") + "." : pick ? "Slot <b>" + esc(pick) + "</b> is reserved for you. " + (proof ? "Payment " + (proof.v.status === "Confirmed" ? "confirmed" : "sent, waiting for the office") + "." : "<b>" + peso(Number(rq.value.amount || 0)) + "</b> is waiting to be paid.") : rq ? "Your request is waiting for the office." : "Rent a motor parking slot for your unit.";
  return '<div class="card"><h2 style="font-size:17px;margin-bottom:4px">Motor parking</h2><p style="margin:0 0 10px;font-size:13px;color:var(--muted)">' + text + '</p>' +
    (pick && !proof && rq.value.amount ? '<button class="btn primary" style="margin-right:8px" onclick="payForParking()">Pay now</button>' : "") + '<button class="btn" onclick="set({view:\'parking\'})">Open Parking</button></div>';
}
// PAGE: Parking.
function viewParkingPage() {
  var slots = slotsSorted(), unit = myUnit(), sizes = parkSizes(), held = heldSlots();
  var mine = slots.filter(function (s) { return s.v.unit === unit; })[0], req = getRow("request", unit);
  var rv = req ? req.value : null, pick = rv && rv.slot ? rv.slot : "", amount = rv && rv.amount ? Number(rv.amount) : 0;
  var proof = pick ? parkProof(unit, pick) : null, free = slots.filter(function (s) { return !s.v.unit && !held[s.id]; }).length;
  var hero;
  if (mine) hero = '<div class="card park-hero good"><div class="park-big">' + esc(mine.id) + '</div><div><h2 style="font-size:19px;margin:0 0 2px">Your parking slot</h2><p class="hint" style="margin:0">Assigned to ' + esc(unit) + ". <b>" + esc(parkRentalLine(mine.v) || "Monthly") + "</b>" + (mine.v.amount ? " · " + peso(Number(mine.v.amount)) : "") + (parkExpired(mine.v) ? '. This rental has ended. Please contact the office to renew or free the slot.' : ".") + "</p></div></div>";
  else if (req && pick) {
    var st = proof ? (proof.v.status === "Confirmed" ? 3 : 2) : 1;
    var steps = '<div class="rental-steps" style="margin:14px 0 8px"><div class="rental-step done"><div class="dot">✓</div><div class="lbl">Slot chosen</div></div><div class="rental-step ' + (st === 1 ? "current" : "done") + '"><div class="dot">' + (st === 1 ? "2" : "✓") + '</div><div class="lbl">Pay ' + (amount ? peso(amount) : "the rental") + '</div></div><div class="rental-step ' + (st === 3 ? "done" : st === 2 ? "current" : "") + '"><div class="dot">' + (st === 3 ? "✓" : "3") + '</div><div class="lbl">Office approves</div></div></div>';
    var msg = st === 1 ? "Pay the rental, then send the payment details. The slot is held for you until the office decides." : st === 2 ? "Payment details sent (ref. " + esc(proof.v.reference) + "). The office will verify and assign the slot." : "Payment verified. The office will assign the slot.";
    hero = '<div class="card"><div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap"><div class="park-big" style="width:72px;height:72px;font-size:22px;background:var(--warn-bg);color:var(--warn-fg)">' + esc(pick) + '</div><div style="flex:1 1 220px"><h2 style="font-size:19px;margin:0 0 2px">Slot ' + esc(pick) + ' reserved for you</h2><p class="hint" style="margin:0">' + (amount ? "Charge: <b>" + peso(amount) + "</b> · " + esc(parkPlanText(rv.plan, rv.days)) : "No rate set yet") + "</p></div></div>" + steps +
      '<p class="hint" style="margin:0 0 12px">' + msg + '</p><div style="display:flex;gap:10px;flex-wrap:wrap">' + (st === 1 && amount ? '<button class="btn primary" onclick="parkPayScroll()">Pay now</button>' : "") + (st === 1 ? '<button class="btn" onclick="cancelParkingRequest()">Cancel reservation</button>' : "") + "</div></div>";
  } else if (req) hero = '<div class="card park-hero warn"><div class="park-big">…</div><div><h2 style="font-size:19px;margin:0 0 2px">Request sent</h2><p class="hint" style="margin:0 0 10px">The office will assign you a slot when one is free. You will get a notice here.</p><button class="btn" onclick="cancelParkingRequest()">Cancel my request</button></div></div>';
  else hero = '<div class="card park-hero"><div class="park-big">P</div><div><h2 style="font-size:19px;margin:0 0 2px">You do not have a parking slot yet</h2><p class="hint" style="margin:0">' + (slots.length ? "Tap a free slot on the map to reserve it. The rental depends on the size of the slot (see the price list). You pay before the office approves it." : "The office has not set up the parking slots yet.") + "</p></div></div>";
  // Slot reserved but not paid yet: the payment form sits right here (method, screenshot, send).
  var payCard = "";
  if (!mine && req && pick && !proof && amount) {
    var pi = dueItems().filter(function (i) { return (i.park || i.title === PARK_FOR) && (i.st === "open" || i.st === "overdue"); })[0];
    if (pi) {
      if (state.payFor !== pi.id) { state.payFor = pi.id; state.payAmt = String(pi.amount); }
      var shown = Object.assign({}, pi, { amount: amount, title: pi.park ? pi.title : "Motor parking rental · " + pick + " · " + parkPlanText(rv.plan, rv.days) });
      if (state.payAmt !== String(amount)) state.payAmt = String(amount);
      payCard = payFormHtml(shown);
    }
  }
  var canPick = !mine && !req && slots.length;
  var grid = slots.map(function (s) {
    var isMine = mine && s.id === mine.id, u = s.v.unit, h = held[s.id], myHold = h && h === unit;
    var cls = isMine ? "mine" : u ? "taken" : myHold ? "held mine-held" : h ? "held" : "free", label = isMine ? "Yours" : u ? "Taken" : myHold ? "Yours" : h ? "Held" : "Free";
    var click = (canPick && !u && !h) ? ' onclick="reserveSlot(\'' + escAttr(s.id) + '\')"' : "";
    var sz = s.v.size || "Regular", rt = parkRatesFor(sz);
    return "<" + (click ? "button" : "div") + ' class="pk ' + cls + (click ? " pick" : "") + '"' + click + ' title="' + label + " · " + sz + (rt.month ? " · " + peso(rt.month) + " per month" : "") + '"><b>' + esc(s.id) + "</b><small>" + label + "</small><small>" + esc(sz) + "</small>" + (!u && !h && rt.month ? "<small>" + peso(rt.month) + "</small>" : "") + "</" + (click ? "button" : "div") + ">";
  }).join("");
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px">' + hero + (mine ? parkRenewCardHtml(mine) : "") + payCard +
    (slots.length ? '<div class="card"><div style="display:flex;justify-content:space-between;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:10px"><h2 style="font-size:19px">Parking map</h2><span class="hint" style="margin:0">' + free + " of " + slots.length + ' free' + (canPick ? " · tap a free slot" : "") + '</span></div><div class="pk-grid">' + grid + '</div><div class="pk-legend"><span><i class="free"></i>Free</span><span><i class="held"></i>Held</span><span><i class="taken"></i>Taken</span>' + (mine || pick ? '<span><i class="mine"></i>Yours</span>' : "") + "</div></div>" : "") +
    '</div><div style="display:flex;flex-direction:column;gap:16px"><div class="card"><h2 style="font-size:19px;margin-bottom:4px">Rental price by slot size</h2><p class="hint" style="margin:0 0 8px">A bigger slot costs more. Each slot on the map shows its size.</p>' + sizes.map(function (z) { return '<div style="display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-top:1px solid var(--border2);font-size:13.5px"><span><b>' + esc(z.name) + "</b>" + (z.sqm ? ' <span style="color:var(--muted)">· ' + z.sqm + " sqm</span>" : "") + "</span><span><b>" + (z.month ? peso(z.month) + "</b> / month" : "—</b>") + (z.day ? " · <b>" + peso(z.day) + "</b> / day" : "") + "</span></div>"; }).join("") + '</div><div class="card"><h2 style="font-size:19px;margin-bottom:4px">How it works</h2><ol style="margin:0;padding-left:18px;font-size:13px;color:var(--muted);line-height:1.8"><li>Tap a free slot on the map. The slot is held for you.</li><li>You choose a monthly or daily rental, and it shows up as a charge. Pay at the office, by bank transfer, GCash or Maya, then send the payment details.</li><li>When the office verifies your payment, the slot is yours. You get your receipt under Dues.</li></ol></div></div></div>';
}
// Requests a parking slot.
function reserveSlot(id) {
  var unit = myUnit(), size = slotSize(id), rates = parkRatesFor(size);
  if (getRow("request", unit)) return toast("You already have a parking reservation.");
  var sl = getRow("slot", id), held = heldSlots();
  if (!sl || sl.value.unit || held[id]) return toast("That slot was just taken. Please pick another.");
  var opts = [];
  if (rates.month || !rates.day) opts.push(["month", "Monthly (1 month)" + (rates.month ? " · " + peso(rates.month) : "")]);
  if (rates.day) opts.push(["day", "Daily · " + peso(rates.day) + " per day"]);
  openForm({
    title: "Reserve " + id + " · " + size + " slot", intro: "This is a " + size.toLowerCase() + " slot" + (rates.sqm ? " (" + rates.sqm + " sqm)" : "") + ", so the price is set for that size. Choose how long you will rent it. The slot is held for you. Pay the rental and send the payment details, then the office approves it.",
    fields: [{ name: "plan", label: "Rental", type: "select", options: opts, value: opts[0][0] }].concat(rates.day ? [{ name: "days", label: "Number of days (for Daily)", type: "number", value: "1" }] : []),
    submit: "Reserve " + id,
    onSubmit: async function (d) {
      var plan = d.plan === "day" ? "day" : "month", days = parseInt(d.days, 10) || 1;
      if (plan === "day" && !(days >= 1 && days <= 365)) return { error: "Enter 1 to 365 days." };
      if (getRow("request", unit)) return { error: "You already have a parking reservation." };
      var sl2 = getRow("slot", id);
      if (!sl2 || sl2.value.unit || heldSlots()[id]) return { error: "That slot was just taken. Please pick another." };
      var q = parkQuote(plan, days, size);
      await put("request", unit, unit, { unit: unit, who: myHousehold(), when: "Just now", at: Date.now(), slot: id, plan: q.plan, days: q.days, amount: q.amount });
      logAct("Motor parking slot " + id + " reserved (" + parkPlanText(q.plan, q.days) + "), " + unit, "Parking");
      toast(q.amount ? "Reserved. Pay " + peso(q.amount) + " to finish." : "Request sent to the administrator.");
    }
  });
}
// "Pay now" on the Parking page: jump to the payment form on the same page.
function parkPayScroll() {
  state.payPulse = true; render();
  var el = document.getElementById("payPanel"); if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
}
// Goes to pay the parking charge (from the Dues page).
function payForParking() {
  var rq = getRow("request", myUnit()); if (!rq) return;
  set({ view: "dues", payFor: "parking", payAmt: String(rq.value.amount || parkRatesFor(slotSize(rq.value.slot)).month || "") });
}
// Cancels my parking request.
function cancelParkingRequest() {
  var rq = getRow("request", myUnit()), slot = rq && rq.value.slot;
  if (slot && parkProof(myUnit(), slot)) return toast("You already sent a payment for this slot. Please contact the office.");
  confirmBox("Cancel your parking reservation?", "The slot is released for others. You can reserve again any time.", "Cancel reservation", async function () { await del("request", myUnit()); logAct("Motor parking request cancelled, " + myUnit(), "Parking"); }, true);
}

/* ==========================================================================
   Events and polls
   ========================================================================== */
function viewEvents() {
  var all = newest(list("event")).map(eventInfo), list_ = all.filter(function (e) { return state.eventFilter === "all" || e.mine; });
  var goingCount = all.filter(function (e) { return e.mine; }).length;
  return pageTabs([["all", "All events (" + all.length + ")"], ["mine", "I'm going (" + goingCount + ")"]], state.eventFilter, "eventFilter") +
    '<div class="event-grid">' + (list_.map(function (e, i) {
      return '<div class="card event ' + (e.mine ? "yes" : "") + '"><div class="date-badge t' + (1 + i % 4) + '"><small>' + esc(e.month) + "</small><b>" + esc(e.day) + '</b></div><div class="event-main"><h2>' + esc(e.title) + '</h2><p class="meta">' + esc(e.when) + " · " + esc(e.place) + "</p>" + (e.about ? "<p>" + esc(e.about) + "</p>" : "") +
        '<div class="event-foot"><span class="going">' + e.going + ' going</span><button class="btn ' + (e.mine ? "" : "primary") + '" onclick="toggleRsvp(\'' + escAttr(e.id) + '\')">' + (e.mine ? "You're going ✓" : "I'm going") + "</button></div></div></div>";
    }).join("") || '<p class="empty">' + (all.length ? "You have not said you are going to any event yet." : "No events have been posted yet.") + "</p>") + "</div>";
}
// Marks my unit as going or not going to an event.
function toggleRsvp(id) {
  var key = myUnit() + "|" + id, going = !!getRow("rsvp", key);
  act(async function () {
    if (going) await del("rsvp", key); else await put("rsvp", key, myUnit(), { event: Number(id) });
    toast(going ? "Removed from the event." : "See you there!");
  });
}
// PAGE: Polls and elections.
function viewPolls() {
  var all = pollsAll(), open = all.filter(function (p) { return p.open; }).length;
  var shown = all.filter(function (p) { return (state.pollFilter === "all" || (state.pollFilter === "open") === p.open) && pollCatMatch(p); });
  return pageTabs([["open", "Open (" + open + ")"], ["closed", "Closed (" + (all.length - open) + ")"], ["all", "All"]], state.pollFilter, "pollFilter") + pollCatFilterHtml(all) +
    '<div class="poll-list">' + (shown.map(function (p) {
      var voted = myVote(p.id), election = p.kind === "election";
      var canSee = !p.open || (voted !== undefined && p.showResults !== "closed");
      var body = p.open && voted === undefined ? pollBallotHtml(p) + '<div class="ballot-submit"><button class="btn primary" onclick="castVote(' + p.id + ')">' + (election ? "Submit my ballot" : "Submit my answers") + "</button></div>"
        : canSee ? pollResultsHtml(p, voted, false) + '<p class="hint" style="margin:12px 0 0">' + p.ballots + (election ? " ballot" : " response") + (p.ballots === 1 ? "" : "s") + " so far" + (voted !== undefined ? " · thank you for voting" : "") + "</p>"
        : '<p class="poll-note">Your ballot was recorded. The results are shown when voting closes on <b>' + esc(p.closes) + "</b>.</p>";
      return '<div class="card poll-card' + (p.questions.length > 1 || (p.open && voted === undefined) ? " wide" : "") + '"><div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px"><div style="min-width:0">' + pollChips(p) + '<h2 class="poll-title">' + richHtml(p.titleHtml, p.q) + "</h2>" +
        (p.descHtml ? '<div class="poll-desc">' + richHtml(p.descHtml) + "</div>" : "") + '<small style="color:var(--muted)">' + (p.open ? "Closes" : "Closed") + " " + esc(p.closes) + (election ? " · secret ballot, one ballot per unit" : "") + '</small></div><span class="chip ' + (p.open ? "good" : "info") + '">' + (p.open ? "Open" : "Closed") + "</span></div>" + body + "</div>";
    }).join("") || '<p class="empty">No polls here.</p>') + "</div>";
}

/* ==========================================================================
   Directory, complaints, documents
   ========================================================================== */
var FAQ = [
  ["How do I book the pool or the Function Hall?", "Open Book a facility, pick the place, tap an open time slot and send your request. The office approves it and you will see the result under Reservations."],
  ["When are monthly dues due?", "Your balance, due dates and history are under Dues."],
  ["I rent out my unit. What do I need to do?", "Open Unit status and declare how your unit is used. Long-term leases are saved right away. Short-term rentals and home businesses need the administrator's approval."],
  ["How do I request motor parking?", "Open Parking, tap a free slot on the map and pay the monthly rental. When the office verifies your payment, the slot is yours."],
  ["How do I report a problem in the building?", "Use Complaints to describe the concern. You can follow its status from Open to In progress to Resolved."]
];
// The saved contacts and house rules.
function directory() { var d = setting("directory"); return { contacts: d.contacts || [], rules: d.rules || [] }; }
// PAGE: Directory (who to call, house rules).
function viewDirectory() {
  var d = directory();
  return '<section><div class="sec-head"><h2>Who to call</h2></div>' + (d.contacts.length ? '<div class="contact-grid">' + d.contacts.map(function (c, i) {
    return '<div class="contact t' + (1 + i % 4) + '"><b>' + esc(c.name) + "</b><small>" + esc(c.note || "") + "</small><em>" + esc(c.tel || "") + "</em></div>";
  }).join("") + "</div>" : '<p class="empty">The office has not added contact numbers yet.</p>') + "</section>" +
    '<div class="two-lists"><section><div class="sec-head"><h2>House rules</h2></div><div class="lrows">' + (d.rules.map(function (r) { return '<div class="lrow rule"><span class="lmain"><b>' + esc(r[0]) + "</b><small>" + esc(r[1]) + "</small></span></div>"; }).join("") || '<p class="empty">The office has not added house rules yet.</p>') + "</div></section>" +
    '<section><div class="sec-head"><h2>Questions we hear a lot</h2></div><div class="faq">' + FAQ.map(function (f) { return "<details><summary>" + esc(f[0]) + "</summary><p>" + esc(f[1]) + "</p></details>"; }).join("") + "</div></section></div>";
}
// PAGE: Complaints.
function viewGr() {
  var all = newest(list("grievance")).filter(function (r) { return r.unit === myUnit(); }), names = ["Open", "In progress", "Resolved"];
  var limit = grLimit(), open = all.filter(function (r) { return !(Number(r.v.stage) >= 2); }).length, full = open >= limit;
  var shown = pageSlice(all, 5, "grPage");
  var fullNote = full ? '<div class="gr-full"><b>You have ' + open + " open complaint" + (open === 1 ? "" : "s") + ".</b>Each unit can have " + limit + " open at a time, so the office can answer them properly. You can send a new one as soon as the office resolves one of yours.</div>" : "";
  return '<div class="two-col-e"><div class="card"><h2 style="font-size:19px;margin-bottom:4px">Submit a complaint</h2><p style="margin:0 0 12px;font-size:13px;color:var(--muted)">The association will follow up here once reviewed. Open complaints: ' + open + " of " + limit + ".</p>" + fullNote +
    '<div style="display:flex;flex-direction:column;gap:10px"><label>Subject<input id="grTitle" type="text" placeholder="e.g. Leaking pipe in the hallway"' + (full ? " disabled" : "") + '></label><label>Details<textarea id="grBody" rows="3" placeholder="Describe the concern"' + (full ? " disabled" : "") + '></textarea></label><button class="btn primary" style="margin-top:4px"' + (full ? " disabled" : "") + ' onclick="submitGr()">Submit complaint</button></div></div>' +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:6px">My complaints</h2>' + (all.length === 0 ? '<div style="padding:16px;border:2px dashed #D8CCB1;border-radius:12px;text-align:center;font-size:14px;color:var(--muted)">No complaints submitted yet.</div>' :
      shown.map(function (r) {
        var g = r.v, s = Math.min(2, Math.max(0, Number(g.stage) || 0));
        var info = g.assignee ? '<div style="margin-top:8px;font-size:13px;line-height:1.5">Assigned to <b>' + esc(g.assignee) + "</b>" + (g.target && s < 2 ? " · target " + esc(g.target) : "") +
          (g.equipName ? '<div style="color:var(--muted)">Related to: ' + esc(g.equipName) + "</div>" : "") + (g.notes && s < 2 ? '<div style="color:var(--muted)">Update from the office: ' + esc(g.notes) + "</div>" : "") + "</div>" : "";
        return '<div style="padding:12px 0;border-top:1px solid var(--border2)"><div style="font-weight:700;font-size:15px">' + esc(g.title) + '</div><div style="font-size:13px;color:var(--muted);margin:2px 0 6px">' + esc(g.body) + '</div><span class="chip ' + (s === 2 ? "good" : s === 1 ? "warn" : "info") + '">' + names[s] + "</span>" + info + "</div>";
      }).join("") + pagerPN(all.length, 5, "grPage")) + "</div></div>";
}
// Sends a complaint to the admin.
function submitGr() {
  var title = document.getElementById("grTitle").value.trim();
  if (!title) return toast("Enter a subject first.");
  var body = document.getElementById("grBody").value.trim() || "No further details.";
  var open = list("grievance").filter(function (r) { return r.unit === myUnit() && !(Number(r.v.stage) >= 2); }).length;
  if (open >= grLimit()) return toast("You already have " + open + " open complaint" + (open === 1 ? "" : "s") + ". Wait until the office resolves one before sending another.");
  act(async function () {
    var id = nextId();
    await put("grievance", id, myUnit(), { id: id, title: title, body: body, by: myUnit(), stage: 0 });
    state.grPage = 0;
    logAct("Complaint sent, " + myUnit() + ": " + title, "Requests");
    toast("Complaint sent. The office will review it.");
  });
}
// PAGE: Documents.
function viewDocs() {
  var docs = newest(list("doc")).filter(function (r) { return r.v.audience !== "admin"; });
  return '<div class="card" style="padding:0;overflow:hidden">' + (docs.map(function (r) {
    var d = r.v;
    return '<div class="doc-row"><div class="doc-main"><b>' + esc(d.name) + '</b><small>' + esc(d.cat || "Other") + " · " + esc(d.date) + '</small></div><button class="btn" onclick="openDoc(\'' + escAttr(r.id) + '\')">' + (d.raw ? "Download" : "View") + "</button></div>";
  }).join("") || '<div style="padding:22px;text-align:center;color:var(--muted)">The association has not shared any document yet.</div>') + "</div>";
}

/* ==========================================================================
   Unit rental (usage declaration)
   ========================================================================== */
var ICON = function (d) { return '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + d + "</svg>"; };
var USAGE_TYPES = [
  { id: "owner", name: "Owner-occupied", desc: "I live here myself.", icon: ICON('<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>') },
  { id: "tenant", name: "Leased to a tenant", desc: "A long-term lease to a tenant.", icon: ICON('<circle cx="8" cy="8" r="3.2"/><path d="M2.5 20c.4-3.4 2.7-5.2 5.5-5.2s5.1 1.8 5.5 5.2"/><path d="M15 6h6M15 10h6M15 14h4"/>') },
  { id: "shortterm", name: "Short-term rental", desc: "Airbnb, Booking.com and similar.", icon: ICON('<path d="M4 18V8a2 2 0 012-2h12a2 2 0 012 2v10"/><path d="M2 18h20M2 14h20"/><path d="M7 11h4"/>') },
  { id: "business", name: "Home-based business", desc: "An office or business run from the unit.", icon: ICON('<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a1 1 0 011-1h4a1 1 0 011 1v2"/><path d="M3 13h18"/>') },
  { id: "renovation", name: "Under renovation", desc: "Repairs or renovation work.", icon: ICON('<path d="M14 6l4 4L8 20H4v-4z"/><path d="M13 7l4 4"/><path d="M15 3l6 6"/>') },
  { id: "vacant", name: "Vacant", desc: "Nobody is staying in it.", icon: ICON('<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 018 0v3"/>') }
];
/* what the person has typed so far, kept for the type that is picked */
function usageState() {
  var rec = myRec();
  if (!state.usage) state.usage = rec.usage || "owner";
  if (state.usageInfoFor !== state.usage) {
    state.usageInfo = state.usage === rec.usage ? JSON.parse(JSON.stringify(rec.usageInfo || {})) : {};
    state.usageInfoFor = state.usage;
  }
  return rec;
}
// Chooses how the unit is used (owner, rented...).
function pickUnitUsage(id) { state.usage = id; state.usageMsg = ""; usageState(); render(); }
// Remembers what the resident types in the usage form.
function setUsageInfo(k, v) { state.usageInfo[k] = v; }
// One field of the usage form.
function usageFieldHtml(f) {
  var v = state.usageInfo[f.k] == null ? "" : state.usageInfo[f.k], id = "ui-" + f.k, label = esc(f.label) + (f.req ? ' <b class="req">*</b>' : "");
  var on = 'oninput="setUsageInfo(\'' + f.k + '\',this.value)"';
  var inner;
  if (f.type === "select") inner = '<select id="' + id + '" onchange="setUsageInfo(\'' + f.k + '\',this.value)"><option value="">Choose…</option>' + f.options.map(function (o) { return "<option" + (o === v ? " selected" : "") + ">" + esc(o) + "</option>"; }).join("") + "</select>";
  else if (f.type === "textarea") inner = '<textarea id="' + id + '" rows="3" ' + on + ' placeholder="' + escAttr(f.ph || "") + '">' + esc(v) + "</textarea>";
  else inner = '<input id="' + id + '" type="' + (f.type || "text") + '" value="' + escAttr(v) + '" ' + on + ' placeholder="' + escAttr(f.ph || "") + '"' + (f.type === "number" ? ' min="1" inputmode="numeric"' : "") + ">";
  return '<label class="uf' + (f.type === "textarea" ? " wide" : "") + '"><span>' + label + "</span>" + inner + "</label>";
}
// PAGE: Unit status (owner, rental, business).
function viewRental() {
  var rec = usageState();
  var type = USAGE_TYPES.filter(function (u) { return u.id === state.usage; })[0], form = USAGE_FORMS[state.usage];
  var needs = state.usage === "shortterm" || state.usage === "business";
  var recNeeds = needsApproval(rec), st = recNeeds ? (rec.usageStatus === "approved" ? "approved" : rec.usageStatus === "rejected" ? "rejected" : "pending") : null;
  var saved = usageInfoRows(rec);
  var statusCard = rec.usage ? '<div class="card"><h2 style="font-size:19px;margin-bottom:2px">Current status</h2><div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:10px 0 6px"><span class="chip ' + (recNeeds ? "warn" : "good") + '">' + esc(usageLabel(rec.usage)) + "</span>" +
    (recNeeds ? '<span class="chip ' + (st === "approved" ? "good" : st === "rejected" ? "bad" : "warn") + '">' + (st === "approved" ? "Approved" : st === "rejected" ? "Rejected" : "Pending review") + "</span>" : "") + "</div>" +
    (recNeeds ? '<div class="rental-steps"><div class="rental-step done"><div class="dot">✓</div><div class="lbl">Declared</div></div><div class="rental-step ' + (st === "pending" ? "current" : "done") + '"><div class="dot">' + (st === "pending" ? "2" : "✓") + '</div><div class="lbl">Under review</div></div><div class="rental-step ' + (st === "approved" ? "done" : st === "rejected" ? "rejected" : "") + '"><div class="dot">' + (st === "approved" ? "✓" : st === "rejected" ? "✕" : "3") + '</div><div class="lbl">Decision</div></div></div>' : "") +
    (saved.length ? '<div class="kv rental-kv">' + saved.map(function (r) { return "<span>" + esc(r[0]) + "</span><b>" + esc(r[1]) + "</b>"; }).join("") + "</div>" : (rec.statusNote ? '<p style="margin:10px 0 0;font-size:13px;color:var(--muted)">' + esc(rec.statusNote) + "</p>" : "")) +
    (st === "rejected" && rec.usageRemark ? '<p style="margin:10px 0 0;font-size:13px;color:#A02B1D">Admin note: “' + esc(rec.usageRemark) + "”</p>" : "") +
    (rec.statusDate ? '<p style="margin:10px 0 0;font-size:12px;color:var(--muted)">Declared ' + esc(rec.statusDate) + ". Change the form below any time. Sending it again puts it back under review.</p>" : "") + "</div>" : "";
  var details = form ? '<div class="usage-sec"><span class="num">2</span>' + esc(form.title) + '</div><div class="uf-grid">' + form.fields.map(usageFieldHtml).join("") + "</div>" : "";
  var bring = form ? '<div class="card bring"><h2 style="font-size:19px;margin-bottom:4px">What to bring to the office</h2><p class="hint" style="margin:0 0 10px">Have these ready when you visit. The office keeps copies on file.</p><ul class="checklist">' + form.bring.map(function (t) { return "<li>" + esc(t) + "</li>"; }).join("") + "</ul></div>" : "";
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px">' + statusCard +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:10px">' + (rec.usage ? "Update your declaration" : "Declare your unit's usage") + '</h2><div class="usage-sec"><span class="num">1</span>How is your unit used?</div><div class="usage-grid">' +
    USAGE_TYPES.map(function (u) { return '<button type="button" class="usage-card ' + (state.usage === u.id ? "active" : "") + '" onclick="pickUnitUsage(\'' + u.id + '\')"><span class="ico">' + u.icon + '</span><span class="name">' + u.name + '</span><span class="desc">' + u.desc + "</span></button>"; }).join("") + "</div>" +
    '<div style="display:flex;flex-direction:column;gap:12px;margin-top:18px">' + details +
    (needs ? '<div class="note-box">This type needs the administrator\'s approval before it is active. You will see the decision on this page.</div>' : (form ? '<div class="note-box good">This type is saved right away. No approval is needed.</div>' : "")) +
    '<button class="btn primary" style="margin-top:4px;align-self:flex-start" onclick="saveUnitUsage()">' + (needs ? "Send for review" : "Save declaration") + '</button>' + (state.usageMsg ? '<div style="font-size:13px;color:#A02B1D;font-weight:600">' + esc(state.usageMsg) + "</div>" : "") + "</div></div></div>" +
    '<div style="display:flex;flex-direction:column;gap:16px">' + bring + '<div class="card"><h2 style="font-size:19px;margin-bottom:4px">How this works</h2><ol style="margin:0;padding-left:18px;font-size:13px;color:var(--muted);line-height:1.8"><li>Tell us how your unit is actually being used.</li><li>Owner-occupied, leased and vacant units, and units under renovation, are saved right away.</li><li>Short-term rentals (like Airbnb) and home-based businesses need the administrator\'s approval first. You will see the decision right here.</li></ol></div>' +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:4px">Why we ask</h2><div class="benefit-row"><div><h4>Security</h4><p>The office knows who is staying, renting or working in a unit.</p></div></div><div class="benefit-row"><div><h4>Insurance</h4><p>Business or short-term-rental use can change what the building\'s coverage needs to account for.</p></div></div><div class="benefit-row"><div><h4>Fair dues</h4><p>Keeps the association\'s records accurate for everyone, in case usage ever affects dues.</p></div></div></div></div></div>';
}
// True if the text looks like a valid Philippine mobile number.
function phoneOk(v) { var d = String(v || "").replace(/[^\d+]/g, "").replace(/^\+/, ""); if (d.indexOf("63") === 0) d = d.slice(2); else if (d.charAt(0) === "0") d = d.slice(1); return /^9\d{9}$/.test(d); }
// Saves the usage form and sends it to the admin for approval when needed.
function saveUnitUsage() {
  var key = state.usage, form = USAGE_FORMS[key], info = {}, summary = "";
  if (form) {
    var i = state.usageInfo || {};
    for (var n = 0; n < form.fields.length; n++) {
      var f = form.fields[n], v = String(i[f.k] == null ? "" : i[f.k]).trim();
      if (f.req && !v) return set({ usageMsg: "Please fill in: " + f.label + "." });
      if (v && f.type === "tel" && !phoneOk(v)) return set({ usageMsg: f.label + " must be a Philippine mobile number, e.g. 0917 123 4567." });
      if (v && f.type === "number" && !(Number(v) >= 1 && Number(v) <= 999)) return set({ usageMsg: f.label + " must be a number, 1 or more." });
      if (v) info[f.k] = v;
    }
    if (info.start && info.end && info.end < info.start) return set({ usageMsg: "The end date must be after the start date." });
    summary = usageSummary(key, info);
  }
  var rec = unitRec(myUnit());
  if (!rec) return set({ usageMsg: "Your unit record was not found. Please contact the office." });
  act(async function () {
    var date = shortDate(new Date()), needs = key === "shortterm" || key === "business";
    var next = Object.assign({}, rec, { usage: key, usageStatus: needs ? "pending" : "", usageRemark: "", statusNote: summary, statusDate: date, status: key === "vacant" ? "Vacant" : "Occupied" });
    if (form) next.usageInfo = info; else delete next.usageInfo;
    await put("unit", myUnit(), myUnit(), next);
    var sid = nextId();
    await put("statusUpdate", sid, myUnit(), { id: sid, unit: myUnit(), key: key, note: summary, date: date, by: "Resident" });
    logAct(myUnit() + " status set to " + usageLabel(key).toLowerCase(), "Units");
    state.usageMsg = "";
    toast(needs ? "Sent to the administrator for review." : "Saved. Thank you.");
  });
}

/* ==========================================================================
   Settings
   ========================================================================== */
function viewSettings() {
  return acctView();   // account.js: all settings, profile, password, devices, language
}
// Popup form to change my password.
function changePasswordForm() {
  openForm({
    title: "Change password",
    fields: [{ name: "cur", label: "Current password", type: "password" }, { name: "pw", label: "New password", type: "password", rules: true }, { name: "pw2", label: "Confirm new password", type: "password" }],
    onSubmit: async function (d) {
      var bad = pwProblem(d.pw); if (bad) return { error: bad };
      if (d.pw !== d.pw2) return { error: "New password and confirmation don't match." };
      var chk = await sb.auth.signInWithPassword({ email: DB.profile.email, password: d.cur });
      if (chk.error) return { error: "Your current password is not correct." };
      var u = await sb.auth.updateUser({ password: d.pw });
      if (u.error) return { error: u.error.message };
      acctMarkPw(); toast("Password changed.");
    }
  });
}

/* ---------- search and bell ---------- */
function searchIndex() {
  var pages = [["Book a facility", "book"], ["My reservations", "res"], ["Dues and payments", "dues"], ["Motor parking", "parking"], ["Community events", "events"], ["Polls", "polls"], ["Directory", "directory"], ["Complaints", "gr"], ["Documents", "docs"], ["Unit status", "rental"], ["Settings", "settings"]];
  var d = directory();
  return [].concat(
    list("event").map(function (r) { return { t: esc(r.v.title), s: esc((r.v.date || "") + " · " + (r.v.place || "")), tag: "Event", v: "events" }; }),
    pollsAll().map(function (p) { return { t: esc(p.q), s: p.open ? "Open poll" : "Closed poll", tag: "Poll", v: "polls" }; }),
    publishedAnns().map(function (r) { return { t: esc(r.v.title), s: esc(r.v.body || ""), tag: "Announcement", v: "home" }; }),
    list("doc").filter(function (r) { return r.v.audience !== "admin"; }).map(function (r) { return { t: esc(r.v.name), s: esc(r.v.cat || ""), tag: "Document", v: "docs" }; }),
    d.contacts.map(function (c) { return { t: esc(c.name), s: esc((c.note || "") + " · " + (c.tel || "")), tag: "Contact", v: "directory" }; }),
    d.rules.map(function (r) { return { t: esc(r[0]), s: esc(r[1]), tag: "House rule", v: "directory" }; }),
    FAQ.map(function (f) { return { t: esc(f[0]), s: esc(f[1]), tag: "FAQ", v: "directory" }; }),
    pages.map(function (p) { return { t: p[0], s: "Open this page", tag: "Page", v: p[1] }; }));
}
// The items in the notification bell.
function bellItems() { return notifs().map(function (n) { return { t: esc(n[0]), s: n[3] ? "Pay now" : "Open", v: n[2], pay: n[3] || "", tone: n[1] }; }); }

(function () {
  document.addEventListener("pointerdown", function (e) { var b = e.target.closest(".btn"); if (b) b.classList.add("is-pressed"); });
  ["pointerup", "pointerleave"].forEach(function (ev) { document.addEventListener(ev, function (e) { var b = e.target.closest && e.target.closest(".btn"); if (b) b.classList.remove("is-pressed"); }); });
})();

rhInit();
