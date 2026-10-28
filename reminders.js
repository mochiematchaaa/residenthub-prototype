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
  return out.sort(function (a, b) { return (a.n == null ? 0 : a.n) - (b.n == null ? 0 : b.n); }).slice(0, 4);
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
  var items = remCandidates().filter(function (it) { return c[it.kind].freq === "every" || st.shown[it.key] !== today; });
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
  }).join("") + '</div><div style="display:flex;flex-direction:column;gap:16px"><div class="card"><h2>How reminders reach residents</h2><p class="hint" style="margin:6px 0 0">A reminder shows in three places: a pop-up when the resident opens their dashboard, a line in the notification bell, and a notice on the dashboard itself. “Every time” shows the pop-up on every visit to the dashboard. “Once a day” shows it the first time that day. “Bell only” turns the pop-up off. Residents can also choose “Do not show again today”.</p></div></div></div>';
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
