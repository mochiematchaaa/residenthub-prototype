/* ==========================================================================
   reminders.js: editable reminders and the pop-up on the resident dashboard.
   Shared by the resident and the administrator pages.

   The office sets, for each kind of reminder (parking rental due, charges due): on or off, how many days before the
   due date the reminder starts, how often it pops up on the resident's dashboard (every time the dashboard is opened,
   once a day, or never: bell only) and the words of the message. The settings are saved as the "reminders" setting.
   ========================================================================== */
var REM_DEFAULTS = {
  parking: { on: "yes", days: 5, freq: "every", msg: "" },
  dues: { on: "yes", days: 2, freq: "daily", msg: "" }
};
var REM_TEXT = {
  parking: "Your parking rental for {slot} is almost up. The next payment is due {date} ({days}). Renew to keep your slot, or tell the office if you no longer plan to rent.",
  dues: "{item} ({amount}) is {when}. Please settle it as soon as you can to avoid a late charge."
};
var REM_FREQ = [["every", "Every time they open the dashboard"], ["daily", "Once a day"], ["bell", "Do not pop up (bell only)"]];
var REM_NAME = { parking: "Parking rental due", dues: "Charges due" };
var REM_TOKENS = { parking: "{slot} {date} {days}", dues: "{item} {amount} {when} {date}" };

// The saved settings with the defaults filled in.
function remCfg() {
  var s = setting("reminders"), out = {};
  Object.keys(REM_DEFAULTS).forEach(function (k) {
    var c = Object.assign({}, REM_DEFAULTS[k], s[k] || {});
    c.days = Math.max(1, Math.round(Number(c.days)) || REM_DEFAULTS[k].days);
    out[k] = c;
  });
  return out;
}
// Days before the next payment when a parking rental counts as "due soon" (0 days = reminders are off).
function parkSoonDays() { var c = remCfg().parking; return c.on === "no" ? -9999 : c.days; }
// The message of a reminder, with {slot} {date} {days} {item} {amount} {when} filled in.
function remText(kind, vars) {
  var c = remCfg()[kind], t = String(c.msg || "").trim() || REM_TEXT[kind];
  return t.replace(/\{(\w+)\}/g, function (m, k) { return vars[k] != null ? vars[k] : m; });
}
// "due today", "due tomorrow", "due in 3 days", "overdue by 2 days".
function remWhen(n) { return n < 0 ? "overdue by " + (-n) + " day" + (n === -1 ? "" : "s") : n === 0 ? "due today" : n === 1 ? "due tomorrow" : "due in " + n + " days"; }


/* ---------- your own reminders (added by the office, shown to residents) ----------
   Saved as the "custom_reminders" setting: {list:[{id,title,text,from,to,freq,aud,units,on,edited}]}.
   freq: "once" (pop up one time), "daily" (once a day), "every" (every dashboard visit), "bell" (bell only). */
var CREM_FREQ = [["once", "One time only"], ["daily", "Once a day"], ["every", "Every time they open the dashboard"], ["bell", "Do not pop up (bell only)"]];
function custList() { var l = setting("custom_reminders").list; return Array.isArray(l) ? l : []; }
function custUnitKey(u) { return String(u || "").toLowerCase().replace(/^unit\s*/, "").replace(/\s+/g, ""); }
// Reminders that apply to this resident today.
function custForMe() {
  var today = dayKey(new Date()), me = custUnitKey(myUnit());
  return custList().filter(function (r) {
    if (r.on === "no" || (r.from && r.from > today) || (r.to && r.to < today)) return false;
    if (r.aud === "units") return String(r.units || "").split(/[,;\n]+/).some(function (u) { return custUnitKey(u) && custUnitKey(u) === me; });
    return true;
  });
}
function custKey(r) { return "cust:" + r.id + ":" + (r.edited || 0); }
function custSave(listNew, note) {
  return put("setting", "custom_reminders", "", { list: listNew }).then(function () { if (note) logAct(note, "Settings"); });
}
function custAudText(r) { return r.aud === "units" ? "Only " + String(r.units || "").split(/[,;\n]+/).map(function (u) { return u.trim(); }).filter(Boolean).join(", ") : "All residents"; }
function custWhenText(r) { return (r.from ? "From " + usageDate(r.from) : "Starts now") + (r.to ? " until " + usageDate(r.to) : ", no end date"); }
function custSettingsHtml() {
  var l = custList().slice().reverse(), shown = pageSlice(l, 5, "custPage");
  return '<div class="card" style="display:flex;flex-direction:column;gap:10px"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><h2 style="margin:0">Your own reminders</h2><button class="btn primary" onclick="custForm()">+ Add reminder</button></div>' +
    '<p class="hint" style="margin:0">Write any reminder you like (a meeting, a water interruption, a deadline). Residents see it as a pop-up and in their notification bell between the dates you choose.</p>' +
    (l.length ? shown.map(function (r) {
      var freq = CREM_FREQ.filter(function (f) { return f[0] === r.freq; })[0];
      return '<div class="rem-row"><div style="min-width:0;flex:1 1 240px"><b>' + esc(r.title) + '</b> <span class="chip ' + (r.on === "no" ? "" : "good") + '">' + (r.on === "no" ? "Off" : "On") + '</span><div class="hint" style="margin:2px 0 0">' + esc(r.text) + '</div><small class="hint">' + esc(custWhenText(r)) + " · " + esc(custAudText(r)) + " · " + esc(freq ? freq[1] : "") + '</small></div>' +
        '<div style="display:flex;gap:6px;flex-wrap:wrap"><button class="btn" onclick="custForm(\'' + escAttr(r.id) + '\')">Edit</button><button class="btn" onclick="custToggle(\'' + escAttr(r.id) + '\')">' + (r.on === "no" ? "Turn on" : "Turn off") + '</button><button class="btn" onclick="custDelete(\'' + escAttr(r.id) + '\')">Delete</button></div></div>';
    }).join("") + pagerPN(l.length, 5, "custPage") : '<div class="rem-empty">No reminders of your own yet. Press “Add reminder” to write one.</div>') + "</div>";
}
function custForm(id) {
  var cur = id ? custList().filter(function (r) { return String(r.id) === String(id); })[0] : null, today = dayKey(new Date());
  openForm({
    title: cur ? "Edit reminder" : "Add a reminder",
    intro: "Residents see this as a pop-up on their dashboard and in the notification bell.",
    submit: cur ? "Save" : "Add reminder",
    fields: [
      { name: "title", label: "Title", value: cur ? cur.title : "", placeholder: "e.g. Water interruption on Friday" },
      { name: "text", label: "Message", type: "textarea", value: cur ? cur.text : "", placeholder: "What should residents know or do?" },
      { name: "from", label: "Start showing on", type: "date", value: cur ? cur.from || "" : today },
      { name: "to", label: "Stop showing after (optional)", type: "date", value: cur ? cur.to || "" : "" },
      { name: "freq", label: "Pop-up on the resident's dashboard", type: "select", options: CREM_FREQ, value: cur ? cur.freq : "once" },
      { name: "aud", label: "Who gets it", type: "select", options: [["all", "All residents"], ["units", "Only certain units"]], value: cur ? cur.aud || "all" : "all" },
      { name: "units", label: "Units (only if you chose certain units)", value: cur ? cur.units || "" : "", placeholder: "e.g. 12C, 8A, 15B" }
    ],
    onSubmit: async function (d) {
      if (!d.title) return { error: "Write a title." };
      if (!d.text) return { error: "Write the message residents will read." };
      if (d.to && d.from && d.to < d.from) return { error: "The end date is before the start date." };
      if (d.aud === "units" && !String(d.units || "").replace(/[,;\s]/g, "")) return { error: "Type at least one unit, or choose all residents." };
      var l = custList().slice(), item = { id: cur ? cur.id : "c" + Date.now(), title: d.title, text: d.text, from: d.from || "", to: d.to || "", freq: d.freq, aud: d.aud === "units" ? "units" : "all", units: d.aud === "units" ? d.units : "", on: cur ? cur.on || "yes" : "yes", edited: Date.now() };
      if (cur) l = l.map(function (r) { return String(r.id) === String(cur.id) ? item : r; }); else l.push(item);
      await custSave(l, (cur ? "Reminder changed: " : "Reminder added: ") + d.title);
      state.custPage = 0;
      toast(cur ? "Reminder saved." : "Reminder added. Residents will see it from " + (d.from ? usageDate(d.from) : "now") + ".");
    }
  });
}
function custToggle(id) {
  var l = custList().map(function (r) { return String(r.id) === String(id) ? Object.assign({}, r, { on: r.on === "no" ? "yes" : "no", edited: Date.now() }) : r; });
  act(async function () { await custSave(l, "Reminder switched: " + (l.filter(function (r) { return String(r.id) === String(id); })[0] || {}).title); toast("Saved."); });
}
function custDelete(id) {
  var r = custList().filter(function (x) { return String(x.id) === String(id); })[0]; if (!r) return;
  confirmBox("Delete this reminder?", "“" + r.title + "” will no longer be shown to residents.", "Delete", async function () {
    await custSave(custList().filter(function (x) { return String(x.id) !== String(id); }), "Reminder deleted: " + r.title); toast("Reminder deleted.");
  }, true);
}

/* ---------- resident: the pop-up ---------- */
function remStore(unit) { try { var s = JSON.parse(localStorage.getItem("rh_rem_" + unit) || "null"); if (s && s.shown) return s; } catch (e) { /* storage blocked */ } return { snooze: "", shown: {} }; }
function remSave(unit, s) { try { localStorage.setItem("rh_rem_" + unit, JSON.stringify(s)); } catch (e) { /* storage blocked */ } }
// The reminders this resident should see now (before the "how often" rule).
function remCandidates() {
  var out = [], c = remCfg(), unit = myUnit();
  if (c.parking.on !== "no" && c.parking.freq !== "bell") {
    var slot = list("slot").filter(function (s) { return s.v.unit === unit; })[0], pd = slot ? parkDueInfo(slot.v) : null;
    if (pd && pd.soon && !leaveNoteOf(unit) && !renewProofOf(unit, slot.id) && !walkinOf(unit, true)) {
      out.push({ key: "park:" + slot.id + ":" + pd.nextDue, kind: "parking", tone: pd.late ? "bad" : "warn", title: pd.late ? "Your parking rental has ended or is due" : "Your parking rental is almost up", ico: "parking",
        text: remText("parking", { slot: slot.id, date: usageDate(pd.nextDue), days: parkDaysText(pd.days) }), btn: "Open Parking", view: "parking" });
    }
  }
  if (c.dues.on !== "no" && c.dues.freq !== "bell") {
    myOpenDues().filter(function (r) { return !hasPendingProof(r.v); }).forEach(function (r) {
      var cd = dueCountdown(r.v); if (!cd || cd.n > c.dues.days) return;
      out.push({ key: "due:" + r.id, kind: "dues", tone: cd.n < 0 ? "bad" : "warn", title: cd.n < 0 ? "Overdue charge" : "Charge coming due", ico: "dues", n: cd.n,
        text: remText("dues", { item: r.v.note, amount: peso(Number(r.v.amount) || 0), when: remWhen(cd.n), date: r.v.dueDate || "" }), btn: "Pay now", pay: r.id });
    });
  }
  out.sort(function (a, b) { return (a.n == null ? 0 : a.n) - (b.n == null ? 0 : b.n); });
  custForMe().filter(function (r) { return r.freq !== "bell"; }).forEach(function (r) {
    out.unshift({ key: custKey(r), kind: "custom", freq: r.freq, tone: "info", title: r.title, ico: "bell", text: r.text });
  });
  return out.slice(0, 5);
}
function remCardHtml(it, i) {
  return '<div class="rem-card ' + it.tone + '"><span class="rem-ico">' + icon(it.ico) + '</span><div class="rem-main"><b>' + esc(it.title) + "</b><span>" + esc(it.text) + "</span></div>" +
    (it.btn ? '<button class="btn primary" onclick="remGo(' + i + ')">' + esc(it.btn) + "</button>" : "") + "</div>";
}
// Shows the pop-up on the dashboard when something is due and the "how often" rule allows it.
function remPopup() {
  if (!state.authed || typeof myUnit !== "function" || !myUnit() || document.getElementById("modal")) return;
  var unit = myUnit(), st = remStore(unit), today = dayKey(new Date()), c = remCfg();
  if (st.snooze === today) return;
  var items = remCandidates().filter(function (it) {
    var f = it.freq || c[it.kind].freq;
    return f === "every" || (f === "once" ? !st.shown[it.key] : st.shown[it.key] !== today);
  });
  if (!items.length) return;
  items.forEach(function (it) { st.shown[it.key] = today; });
  remSave(unit, st);
  window.__remItems = items;
  openModal('<h2>Reminders</h2><p class="hint" style="margin:0 0 12px">' + (items.length === 1 ? "One thing needs your attention." : items.length + " things need your attention.") + '</p><div class="rem-list">' + items.map(remCardHtml).join("") + "</div>" +
    '<div class="modal-actions"><button class="btn" onclick="closeModal()">Remind me later</button><button class="btn" onclick="remSnooze()">Do not show again today</button></div>');
}
function remGo(i) {
  var it = (window.__remItems || [])[i]; closeModal(); if (!it) return;
  if (it.pay) { bellPay(String(it.pay)); return; }
  set({ view: it.view });
}
function remSnooze() { var u = myUnit(), st = remStore(u); st.snooze = dayKey(new Date()); remSave(u, st); closeModal(); toast("OK. No more reminder pop-ups today."); }

/* ---------- administrator: edit the reminders ---------- */
function remSummary(k) {
  var c = remCfg()[k], freq = REM_FREQ.filter(function (f) { return f[0] === c.freq; })[0];
  return c.on === "no" ? "Off. Residents are not reminded." : "On. Starts " + c.days + " day" + (c.days === 1 ? "" : "s") + " before the due date. Pop-up: " + (freq ? freq[1].toLowerCase() : "") + ".";
}
function remSettingsHtml() {
  var c = remCfg();
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px">' + Object.keys(REM_DEFAULTS).map(function (k) {
    return '<div class="card" style="display:flex;flex-direction:column;gap:10px"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><h2 style="margin:0">' + REM_NAME[k] + '</h2><span class="chip ' + (c[k].on === "no" ? "" : "good") + '">' + (c[k].on === "no" ? "Off" : "On") + "</span></div>" +
      '<p class="hint" style="margin:0">' + esc(remSummary(k)) + '</p><div class="rem-msg"><small>Message residents see</small><span>' + esc(String(c[k].msg || "").trim() || REM_TEXT[k]) + "</span></div>" +
      '<div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn primary" onclick="remForm(\'' + k + '\')">Edit reminder</button><button class="btn" onclick="remPreview(\'' + k + '\')">Preview the pop-up</button></div></div>';
  }).join("") + '</div><div style="display:flex;flex-direction:column;gap:16px">' + custSettingsHtml() + '<div class="card"><h2>How reminders reach residents</h2><p class="hint" style="margin:6px 0 0">A reminder shows in three places: a pop-up when the resident opens their dashboard, a line in the notification bell, and a notice on the dashboard itself. “Every time” shows the pop-up on every visit to the dashboard. “Once a day” shows it the first time that day. “Bell only” turns the pop-up off. Residents can also choose “Do not show again today”.</p></div></div></div>';
}
function remForm(kind) {
  var c = remCfg()[kind];
  openForm({
    title: "Edit reminder: " + REM_NAME[kind],
    intro: "You can use these words in the message and they are filled in for each resident: <b>" + REM_TOKENS[kind] + "</b>. Leave the message empty to use the standard one.",
    submit: "Save", fields: [
      { name: "on", label: "Reminder", type: "select", options: [["yes", "On"], ["no", "Off"]], value: c.on },
      { name: "days", label: "Start reminding this many days before the due date", type: "number", value: c.days },
      { name: "freq", label: "Pop-up on the resident's dashboard", type: "select", options: REM_FREQ, value: c.freq },
      { name: "msg", label: "Message", type: "textarea", value: c.msg || "", placeholder: REM_TEXT[kind] }
    ],
    onSubmit: async function (d) {
      var days = Math.round(Number(d.days));
      if (!(days >= 1 && days <= 60)) return { error: "Choose between 1 and 60 days." };
      var cur = setting("reminders"), next = {};
      Object.keys(REM_DEFAULTS).forEach(function (k) { next[k] = Object.assign({}, cur[k] || {}); });
      next[kind] = { on: d.on === "no" ? "no" : "yes", days: days, freq: d.freq, msg: String(d.msg || "").trim() };
      await put("setting", "reminders", "", next);
      logAct("Reminder changed: " + REM_NAME[kind] + " (" + (d.on === "no" ? "off" : days + " days before, " + d.freq) + ")", "Settings");
      toast("Reminder saved. Residents see the change straight away.");
    }
  });
}
// A sample pop-up, so the office can see how it looks.
function remPreview(kind) {
  var cd = kind === "parking"
    ? { kind: "parking", tone: "warn", title: "Your parking rental is almost up", ico: "parking", text: remText("parking", { slot: "M-07", date: "Nov 28, 2026", days: "in 3 days" }), btn: "Open Parking" }
    : { kind: "dues", tone: "warn", title: "Charge coming due", ico: "dues", text: remText("dues", { item: "Association dues, November 2026", amount: peso(2550), when: remWhen(2), date: "Nov 30, 2026" }), btn: "Pay now" };
  openModal('<h2>Preview: what the resident sees</h2><p class="hint" style="margin:0 0 12px">A sample. The real pop-up uses the resident’s own charge or slot.</p><div class="rem-list">' + remCardHtml(cd, 0).replace(/onclick="remGo\(0\)"/, "disabled") + '</div><div class="modal-actions"><button class="btn primary" onclick="closeModal()">Close</button></div>');
}
