/* ==========================================================================
   pay-check.js — "Did they pay?" for the administrator.
   A charge whose due date has come (or passed) with no payment recorded and nothing sent by the resident may well
   have been paid already, only the resident did not tell the system. These are listed on the dashboard and under
   Finance. For each one the administrator answers:
     Yes → the charge is marked paid and a receipt is issued. If the resident paid less, the amount actually paid is
           entered; the rest stays as a new "(balance)" charge.
     No  → optionally add a late charge, tell the resident in the app, or call / text them.
   Loaded by admin.html after admin-more.js.
   ========================================================================== */

var PC_PAGE = 8;           // charges shown on one page of "Did they pay?"
function goPcPage(n) { state.pcPage = Math.max(0, n); render(); }
var PC_RECHECK_DAYS = 7;   // after a "No", the same charge is not asked about again for this many days
function pcDayStart(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); }
// Late charge setting: a percentage of the unpaid charge.
function payCheckCfg() { var c = setting("paycheck"); return { pct: Number(c.pct) >= 0 && c.pct !== "" && c.pct != null ? Number(c.pct) : 5 }; }
// The mobile number to call or text for a unit.
function unitPhone(unit) {
  var a = typeof accountOfUnit === "function" ? accountOfUnit(unit) : null, u = unitRec(unit) || {};
  var p = (a && a.phone) || (u.contact && u.contact !== "—" ? u.contact : "");
  return String(p || "").trim();
}
// Charges to check, oldest first. Each: { r: due row, days: days since the due date (0 = due today) }.
function payCheckList() {
  var now = Date.now(), today = pcDayStart(new Date()), out = [], pend = {};
  list("proof").forEach(function (p) { if (p.v.status === "Pending") pend[p.v.unit + "|" + p.v.forText] = 1; });
  list("due").forEach(function (r) {
    var d = r.v; if (d.paid || !d.dueDate || !(Number(d.amount) > 0)) return;
    var x = parseShort(d.dueDate); if (!x) return;
    var days = Math.round((today - pcDayStart(x)) / 86400000); if (days < 0) return;
    if (pend[d.unit + "|" + d.note]) return;                                                  // already waiting under "Payments to verify"
    if (d.checkedAt && now - Number(d.checkedAt) < PC_RECHECK_DAYS * 86400000) return;       // the office already answered "No" lately
    out.push({ r: r, days: days });
  });
  return out.sort(function (a, b) { return b.days - a.days; });
}
function pcWhen(days) { return days <= 0 ? "Due today" : "Overdue by " + days + " day" + (days === 1 ? "" : "s"); }
// The card. limit = how many to show at first (the dashboard shows a few).
function payCheckPanel(limit) {
  var l = payCheckList(); if (!l.length) return "";
  var units = {}, total = 0; l.forEach(function (x) { units[x.r.v.unit] = 1; total += Number(x.r.v.amount) || 0; });
  var nu = Object.keys(units).length, shown = limit && !state.pcAll ? l.slice(0, limit) : l, pager = "";
  if (!limit) {   // the Finance page: a page of its own, a few charges at a time
    var q = (state.pcQ || "").trim().toLowerCase();
    var f = state.pcFilter || "all";
    var all = l.filter(function (x) { return (f === "all" || (f === "over" ? x.days > 0 : x.days <= 0)) && (!q || (x.r.v.unit + " " + (x.r.v.name || "") + " " + x.r.v.note).toLowerCase().indexOf(q) >= 0); });
    var pages = Math.max(1, Math.ceil(all.length / PC_PAGE)), pg = Math.min(Math.max(0, state.pcPage || 0), pages - 1);
    shown = all.slice(pg * PC_PAGE, (pg + 1) * PC_PAGE);
    var nOver = l.filter(function (x) { return x.days > 0; }).length;
    pager = '<div class="filters" style="padding:4px 0 12px"><button class="' + (f === "all" ? "active" : "") + '" onclick="set({pcFilter:\'all\',pcPage:0})">All (' + l.length + ')</button><button class="' + (f === "over" ? "active" : "") + '" onclick="set({pcFilter:\'over\',pcPage:0})">Overdue (' + nOver + ')</button><button class="' + (f === "today" ? "active" : "") + '" onclick="set({pcFilter:\'today\',pcPage:0})">Due today (' + (l.length - nOver) + ')</button>' +
      '<input type="search" id="pcSearchInput" value="' + escAttr(state.pcQ || "") + '" oninput="set({pcQ:this.value,pcPage:0})" placeholder="Search unit or charge..." autocomplete="off" class="fin-search"></div>';
    var pagerEnd = all.length > PC_PAGE ? pagerHtml(all.length, pg, PC_PAGE, "goPcPage") : "";
    state._pcEnd = pagerEnd + (all.length ? "" : '<div style="padding:22px;text-align:center;color:var(--muted)">No charge matches.</div>');
  }
  var rows = shown.map(function (x) {
    var d = x.r.v, id = escAttr(x.r.id), ph = unitPhone(d.unit), digits = ph.replace(/[^\d+]/g, ""), tone = x.days >= 3 ? "bad" : "warn";
    var sms = "Good day! This is the administration office. Our records show " + d.note + " (" + peso(Number(d.amount)) + ") is still unpaid. If you already paid, please send your payment details under Dues in the ResidentHub app so your balance updates. Thank you!";
    return '<div class="pc-item"><span class="pc-unit">' + esc(String(d.unit).replace(/^Unit\s*/i, "")) + '</span><div class="pc-main"><b>' + esc(d.unit) + (d.name ? " · " + esc(d.name) : "") + "</b><small>" + esc(d.note) + " · due " + esc(d.dueDate) + '</small><span class="pc-tags"><span class="chip ' + tone + '">' + pcWhen(x.days) + "</span>" + (d.remindedOn ? '<span class="chip">Reminded ' + esc(d.remindedOn) + "</span>" : "") + "</span></div>" +
      '<div class="pc-amt">' + peso(Number(d.amount)) + "<small>Did they pay?</small></div>" +
      '<div class="pc-act"><button class="btn primary" onclick="payCheckYes(\'' + id + '\')">Yes, paid</button><button class="btn" onclick="payCheckNo(\'' + id + '\')">No</button>' +
      (digits ? '<a class="btn" href="tel:' + escAttr(digits) + '" title="Call ' + escAttr(ph) + '">Call</a><a class="btn" href="sms:' + escAttr(digits) + "?body=" + encodeURIComponent(sms) + '" title="Text ' + escAttr(ph) + '">SMS</a>' : "") + "</div></div>";
  }).join("");
  return '<div class="card pc"><div class="pc-head"><div><h2>Did they pay?</h2><p class="hint" style="margin:4px 0 0"><b>' + l.length + " charge" + (l.length === 1 ? "" : "s") + "</b> from <b>" + nu + " unit" + (nu === 1 ? "" : "s") + "</b> (" + peso(total) + ") " + (l.length === 1 ? "is" : "are") + " due or past due with no payment on record. They may have paid without updating the app. Residents who send their payment details are handled by themselves, so only these are left.</p></div>" +
    '<button class="btn" onclick="payCheckAskAll()">Ask everyone to send proof</button></div>' + pager + '<div class="pc-list">' + rows + "</div>" + (limit ? "" : state._pcEnd || "") +
    (limit && l.length > limit ? '<div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap"><button class="btn" onclick="set({pcAll:' + !state.pcAll + '})">' + (state.pcAll ? "Show fewer" : "Show all " + l.length) + '</button><button class="btn" onclick="set({view:\'fin\',finTab:\'paycheck\',pcPage:0})">Open in Finance</button></div>' : "") + "</div>";
}
// YES: mark it paid. The office enters what was really paid; anything short stays as a balance.
function payCheckYes(id) {
  var row = getRow("due", id); if (!row) return;
  var cur = row.value, methods = payMethods().map(function (m) { return m.name; });
  openForm({
    title: "Yes, " + cur.unit + " paid",
    intro: esc(cur.note) + " · charge of <b>" + peso(Number(cur.amount)) + "</b>. Enter what they really paid. If it is less than the charge, the rest stays as a balance on their dues. A receipt is issued and the resident sees it right away.",
    submit: "Mark as paid",
    fields: [
      { name: "amount", label: "Amount they paid (₱)", type: "number", step: "0.01", value: String(cur.amount) },
      { name: "method", label: "How they paid", type: "select", options: methods, value: methods.indexOf("GCash") >= 0 ? "GCash" : PAY_OFFICE },
      { name: "date", label: "Date they paid (leave empty for today)", type: "date" },
      { name: "ref", label: "Reference no. (optional)" }
    ],
    onSubmit: async function (d) {
      var now = getRow("due", id); if (!now || now.value.paid) return { error: "This charge is already paid." };
      var c = now.value, full = Number(c.amount), amt = Math.round((parseFloat(d.amount) || 0) * 100) / 100;
      if (!(amt > 0)) return { error: "Enter the amount they paid." };
      if (amt > full + 0.009) return { error: "That is more than the charge (" + peso(full) + "). Enter the amount that applies to this charge." };
      var when = null;
      if (d.date) {
        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d.date); when = m ? new Date(+m[1], +m[2] - 1, +m[3]) : null;
        if (!when || isNaN(when.getTime())) return { error: "Enter a valid date." };
        if (when.getTime() > Date.now()) return { error: "The date paid cannot be in the future." };
      }
      var dateText = when ? shortDate(when) : shortDate(new Date()), short = full - amt > 0.009, ref = String(d.ref || "").trim();
      var r = await issuePayment(c.unit, c.name || c.unit, c.note, d.method, ref, amt, "", dateText);
      var qid = nextId();
      await put("proof", qid, c.unit, { id: qid, unit: c.unit, payer: c.name || c.unit, forText: c.note, method: d.method, reference: ref || "—", amount: amt, date: r.date, status: "Confirmed", receiptNo: r.no, confirmedOn: r.date, direct: true, checked: true });
      if (short) {
        // the part that was paid is closed; the rest becomes a new charge with the same due date
        await put("due", id, c.unit, Object.assign({}, c, { paid: true, amount: amt, partOf: full }));
        var bid = nextId();
        await put("due", bid, c.unit, { id: bid, unit: c.unit, name: c.name || "", amount: Math.round((full - amt) * 100) / 100, note: c.note + " (balance)", dueDate: c.dueDate, billedOn: shortDate(new Date()), balanceOf: id, checkedAt: Date.now() });
      } else await put("due", id, c.unit, Object.assign({}, c, { paid: true }));
      await voidAutoLateFee(c, when || new Date());
      logAct("Marked paid, " + c.unit + ": " + c.note + " " + peso(amt) + (short ? " (balance " + peso(full - amt) + " left)" : ""), "Finance");
      toast(short ? "Recorded " + peso(amt) + " for " + c.unit + ". The balance of " + peso(full - amt) + " stays on their dues. Receipt " + r.no + "." : "Marked paid. Receipt " + r.no + " issued to " + c.unit + ".");
    }
  });
}
// NO: add a late charge, tell the resident, or leave it. The office can also call or text from the list.
function payCheckNo(id) {
  var row = getRow("due", id); if (!row) return;
  var cur = row.value, cfg = payCheckCfg(), ph = unitPhone(cur.unit), digits = ph.replace(/[^\d+]/g, "");
  var contact = digits ? ' You can also <a href="tel:' + escAttr(digits) + '"><b>call ' + esc(ph) + '</b></a> or <a href="sms:' + escAttr(digits) + '"><b>send a text</b></a>.' : " There is no mobile number on file for this unit.";
  openForm({
    title: cur.unit + " has not paid",
    intro: esc(cur.note) + " · " + peso(Number(cur.amount)) + " (" + pcWhen(Math.max(0, Math.round((pcDayStart(new Date()) - pcDayStart(parseShort(cur.dueDate) || new Date())) / 86400000))).toLowerCase() + "). Choose what to do." + contact,
    submit: "Save",
    fields: [
      { name: "late", label: "Add a late charge?", type: "select", options: ["Yes, add a late charge", "No late charge"], value: cur.lateFeeId ? "No late charge" : "Yes, add a late charge" },
      { name: "pct", label: "Late charge (% of this charge)", type: "number", step: "0.1", value: String(cfg.pct) },
      { name: "notify", label: "Tell the resident in the app?", type: "select", options: ["Yes, send a reminder", "No"], value: "Yes, send a reminder" },
      { name: "msg", label: "Message to the resident (you can edit it)", type: "textarea", value: "Our records show this charge is still unpaid. Please pay it, or if you already paid, send your payment details under Dues so your balance updates. Thank you!" }
    ],
    onSubmit: async function (d) {
      var now = getRow("due", id); if (!now || now.value.paid) return { error: "This charge is already paid." };
      var c = now.value, v = Object.assign({}, c, { checkedAt: Date.now(), checkedNo: shortDate(new Date()) }), notes = [];
      if (d.late.indexOf("Yes") === 0) {
        var pct = parseFloat(d.pct);
        if (!(pct > 0 && pct <= 100)) return { error: "Enter the late charge as a percentage, from 0.1 to 100." };
        if (c.lateFeeId) return { error: "A late charge was already added for this charge." };
        var amt = Math.round(Number(c.amount) * pct) / 100, lid = nextId(), due = new Date(); due.setDate(due.getDate() + 7);
        if (!(amt > 0)) return { error: "The late charge works out to zero. Raise the percentage." };
        await put("due", lid, c.unit, { id: lid, unit: c.unit, name: c.name || "", amount: amt, note: "Late charge: " + c.note, dueDate: shortDate(due), billedOn: shortDate(new Date()), lateFor: id });
        v.lateFeeId = lid; notes.push("late charge " + peso(amt));
        await put("setting", "paycheck", "", { pct: pct });
      }
      if (d.notify.indexOf("Yes") === 0) {
        v.remindedOn = shortDate(new Date()); v.remindedAt = Date.now(); v.reminders = (Number(c.reminders) || 0) + 1; v.remindMsg = String(d.msg || "").trim() || REMIND_DEFAULT; notes.push("reminder sent");
      }
      await put("due", id, c.unit, v);
      logAct("Not paid, " + c.unit + ": " + c.note + (notes.length ? " (" + notes.join(", ") + ")" : ""), "Finance");
      toast(notes.length ? "Saved for " + c.unit + ": " + notes.join(" and ") + "." : "Saved. We will ask again in " + PC_RECHECK_DAYS + " days if it is still unpaid.");
    }
  });
}
// One message to everyone on the list: if you already paid, send your payment details.
function payCheckAskAll() {
  var l = payCheckList(); if (!l.length) return toast("Nothing to ask about right now.");
  var units = {}; l.forEach(function (x) { units[x.r.v.unit] = 1; });
  openForm({
    title: "Ask everyone to send proof",
    intro: "Sends a reminder to <b>" + Object.keys(units).length + " unit" + (Object.keys(units).length === 1 ? "" : "s") + "</b> (" + l.length + " charge" + (l.length === 1 ? "" : "s") + "). A resident who already paid can then send the payment details and a photo, and it posts to their dues by itself, so you do not have to go one by one.",
    submit: "Send to all",
    fields: [{ name: "msg", label: "Message to the residents (you can edit it)", type: "textarea", value: "Your charge is due. If you already paid, please send your payment details (and a photo of your payment) under Dues so your balance updates. If not yet, please pay soon. Thank you!" }],
    onSubmit: async function (d) {
      var msg = String(d.msg || "").trim() || REMIND_DEFAULT, n = 0;
      for (var i = 0; i < l.length; i++) {
        var cur = getRow("due", l[i].r.id); if (!cur || cur.value.paid) continue;
        await put("due", l[i].r.id, cur.value.unit, Object.assign({}, cur.value, { remindedOn: shortDate(new Date()), remindedAt: Date.now(), reminders: (Number(cur.value.reminders) || 0) + 1, remindMsg: msg })); n++;
      }
      logAct("Asked " + Object.keys(units).length + " unit(s) to send proof of payment", "Finance");
      toast("Sent to " + Object.keys(units).length + " unit" + (Object.keys(units).length === 1 ? "" : "s") + " (" + n + " charge" + (n === 1 ? "" : "s") + ").");
    }
  });
}

/* ---------- reminder labels, overdue warnings and the automatic late charge ---------- */
// When the last reminder was sent (older ones only have the day).
function remindedAtMs(v) { if (Number(v.remindedAt) > 0) return Number(v.remindedAt); var d = parseShort(v.remindedOn || ""); return d ? d.getTime() + 9 * 3600000 : 0; }
function remindedLabel(v) {
  var t = remindedAtMs(v); if (!t) return "";
  var n = Number(v.reminders) || 0;
  return "Reminded " + (Number(v.remindedAt) > 0 ? clockText(t) : v.remindedOn) + (n > 1 ? " · " + n + " times" : "");
}
function remindedRecently(v, hours) { var t = remindedAtMs(v); return !!t && Date.now() - t < (hours || 24) * 3600000; }
// Days since the due date (0 = due today, null = no due date or already paid).
function daysLate(d) { var x = parseShort(d.dueDate || ""); if (!x || d.paid) return null; return Math.round((pcDayStart(new Date()) - pcDayStart(x)) / 86400000); }
// A red notice above the unpaid list: how many are overdue and how many nobody was told about yet.
function lateWarnHtml(open) {
  var over = open.filter(function (r) { return isOverdue(r.v); });
  if (!over.length) return "";
  var sum = over.reduce(function (t, r) { return t + Number(r.v.amount || 0); }, 0), fresh = over.filter(function (r) { return !remindedRecently(r.v, 24); }).length, fees = over.filter(function (r) { return r.v.lateFeeId; }).length;
  return '<div class="late-warn"><span class="late-ic">!</span><div><b>' + over.length + " overdue charge" + (over.length === 1 ? "" : "s") + " (" + peso(sum) + ")</b><small>" + (fees ? fees + " already got a late charge. " : "") + (fresh ? fresh + " not reminded in the last 24 hours." : "Everyone overdue was reminded today.") + '</small></div>' + (fresh ? '<button class="btn primary" onclick="remindAll()">Send reminders</button>' : "") + "</div>";
}
// Late charge setting: added by itself some days after the due date.
function lateFeeCfg() { var c = setting("latefee"); return { on: c.on !== false, days: Number(c.days) >= 1 ? Number(c.days) : 1, pct: payCheckCfg().pct }; }
function lateFeeSettingsHtml() {
  var c = lateFeeCfg();
  return '<div class="lf-set"><b>Late charge</b><p class="hint" style="margin:2px 0 8px">When a charge is still unpaid after its due date, a late charge is added by itself, so an overdue charge never just sits there. It is added during the first week of being overdue (older ones are handled with “Did they pay?”), skipped if the resident already sent their payment, and taken off again if they turn out to have paid on time.</p>' +
    '<label style="display:flex;gap:8px;align-items:center;font-size:13.5px;margin-bottom:8px"><input type="checkbox" id="lfOn" ' + (c.on ? "checked" : "") + '> Add the late charge automatically</label>' +
    '<div style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end"><label class="fl" style="width:190px">After how many days overdue<input id="lfDays" type="number" min="1" max="30" step="1" value="' + c.days + '"></label><label class="fl" style="width:170px">Late charge (% of the charge)<input id="lfPct" type="number" min="0.1" max="100" step="0.1" value="' + c.pct + '"></label><button class="btn" onclick="saveLateFee()">Save late charge</button></div></div>';
}
function saveLateFee() {
  var on = document.getElementById("lfOn").checked, days = parseInt(document.getElementById("lfDays").value, 10), pct = parseFloat(document.getElementById("lfPct").value);
  if (!(days >= 1 && days <= 30)) return toast("Enter the number of days, from 1 to 30.");
  if (!(pct > 0 && pct <= 100)) return toast("Enter the late charge as a percentage, from 0.1 to 100.");
  act(async function () {
    await put("setting", "latefee", "", { on: on, days: days });
    await put("setting", "paycheck", "", { pct: pct });
    logAct("Automatic late charge " + (on ? "on, " + pct + "% after " + days + " day" + (days === 1 ? "" : "s") : "turned off"), "Settings");
    toast(on ? "Saved. A " + pct + "% late charge is added " + days + " day" + (days === 1 ? "" : "s") + " after the due date." : "Saved. Late charges are no longer added by themselves.");
  });
}
// Adds the late charge to every charge that is still unpaid after the waiting days. Skips charges the resident already sent a payment for,
// charges the office already answered "No" about, and charges that are themselves a late charge or a balance.
var _lateBusy = false;
async function autoLateFeeCheck() {
  if (_lateBusy || !state.authed || !isAdmin()) return;
  var cfg = lateFeeCfg(); if (!cfg.on) return;
  var pend = {}; list("proof").forEach(function (o) { if (o.v.status === "Pending") pend[o.v.unit + "|" + o.v.forText] = 1; });
  var todo = list("due").filter(function (r) {
    var d = r.v, n = daysLate(d);
    return !d.paid && n != null && n >= cfg.days && n <= cfg.days + 6 && Number(d.amount) > 0 && !d.lateFeeId && !d.checkedAt && !d.lateFor && !d.balanceOf && !/^Late charge/.test(d.note || "") && !pend[d.unit + "|" + d.note];
  });
  if (!todo.length) return;
  _lateBusy = true;
  var done = 0, units = {};
  try {
    for (var i = 0; i < todo.length; i++) {
      var cur = getRow("due", todo[i].id); if (!cur || cur.value.paid || cur.value.lateFeeId) continue;
      var c = cur.value, amt = Math.round(Number(c.amount) * cfg.pct) / 100; if (!(amt > 0)) continue;
      var lid = nextId(), due = new Date(); due.setDate(due.getDate() + 7);
      await put("due", lid, c.unit, { id: lid, unit: c.unit, name: c.name || "", amount: amt, note: "Late charge: " + c.note, dueDate: shortDate(due), billedOn: shortDate(new Date()), lateFor: todo[i].id, auto: true });
      await put("due", todo[i].id, c.unit, Object.assign({}, c, { lateFeeId: lid, lateFeeAuto: true, remindedOn: shortDate(new Date()), remindedAt: Date.now(), reminders: (Number(c.reminders) || 0) + 1, remindMsg: "This charge is overdue, so a late charge of " + peso(amt) + " was added. Please pay now and send your proof under Dues. If you already paid, send your payment details so it is removed." }));
      logAct("Late charge added automatically, " + c.unit + ": " + c.note + " (" + peso(amt) + ")", "Finance");
      done++; units[c.unit] = 1;
    }
  } catch (e) { /* the rest are tried again next time */ }
  _lateBusy = false;
  if (done) { toast(done + " late charge" + (done === 1 ? " was" : "s were") + " added automatically (" + Object.keys(units).slice(0, 6).join(", ") + (Object.keys(units).length > 6 ? "…" : "") + "). Residents were notified."); render(); }
}
// A late charge added by itself is taken off again when the resident paid on time (or the office finds they paid).
async function voidAutoLateFee(due, paidDate) {
  if (!due || !due.lateFeeId || !due.lateFeeAuto) return;
  var lf = getRow("due", due.lateFeeId); if (!lf || lf.value.paid) return;
  var dd = parseShort(due.dueDate || ""); if (!dd || !paidDate) return;
  if (pcDayStart(paidDate) > pcDayStart(dd)) return;   // really paid late: the late charge stays
  await del("due", due.lateFeeId);
  logAct("Late charge removed, " + due.unit + ": " + due.note + " (paid on time)", "Finance");
}
setInterval(autoLateFeeCheck, 30000);
var _rhEnter2 = rhEnter;
rhEnter = function () { _rhEnter2(); setTimeout(autoLateFeeCheck, 2500); };
