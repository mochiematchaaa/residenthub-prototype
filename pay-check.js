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
  var nu = Object.keys(units).length, shown = limit && !state.pcAll ? l.slice(0, limit) : l;
  var rows = shown.map(function (x) {
    var d = x.r.v, id = escAttr(x.r.id), ph = unitPhone(d.unit), digits = ph.replace(/[^\d+]/g, ""), tone = x.days >= 3 ? "bad" : "warn";
    var sms = "Good day! This is the administration office. Our records show " + d.note + " (" + peso(Number(d.amount)) + ") is still unpaid. If you already paid, please send your payment details under Dues in the ResidentHub app so your balance updates. Thank you!";
    return '<div class="pc-item"><span class="pc-unit">' + esc(String(d.unit).replace(/^Unit\s*/i, "")) + '</span><div class="pc-main"><b>' + esc(d.unit) + (d.name ? " · " + esc(d.name) : "") + "</b><small>" + esc(d.note) + " · due " + esc(d.dueDate) + '</small><span class="pc-tags"><span class="chip ' + tone + '">' + pcWhen(x.days) + "</span>" + (d.remindedOn ? '<span class="chip">Reminded ' + esc(d.remindedOn) + "</span>" : "") + "</span></div>" +
      '<div class="pc-amt">' + peso(Number(d.amount)) + "<small>Did they pay?</small></div>" +
      '<div class="pc-act"><button class="btn primary" onclick="payCheckYes(\'' + id + '\')">Yes, paid</button><button class="btn" onclick="payCheckNo(\'' + id + '\')">No</button>' +
      (digits ? '<a class="btn" href="tel:' + escAttr(digits) + '" title="Call ' + escAttr(ph) + '">Call</a><a class="btn" href="sms:' + escAttr(digits) + "?body=" + encodeURIComponent(sms) + '" title="Text ' + escAttr(ph) + '">SMS</a>' : "") + "</div></div>";
  }).join("");
  return '<div class="card pc"><div class="pc-head"><div><h2>Did they pay?</h2><p class="hint" style="margin:4px 0 0"><b>' + l.length + " charge" + (l.length === 1 ? "" : "s") + "</b> from <b>" + nu + " unit" + (nu === 1 ? "" : "s") + "</b> (" + peso(total) + ") " + (l.length === 1 ? "is" : "are") + " due or past due with no payment on record. They may have paid without updating the app. Residents who send their payment details are handled by themselves, so only these are left.</p></div>" +
    '<button class="btn" onclick="payCheckAskAll()">Ask everyone to send proof</button></div><div class="pc-list">' + rows + "</div>" +
    (limit && l.length > limit ? '<div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap"><button class="btn" onclick="set({pcAll:' + !state.pcAll + '})">' + (state.pcAll ? "Show fewer" : "Show all " + l.length) + '</button><button class="btn" onclick="set({view:\'fin\',finTab:\'overview\'})">Open in Finance</button></div>' : "") + "</div>";
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
        v.remindedOn = shortDate(new Date()); v.reminders = (Number(c.reminders) || 0) + 1; v.remindMsg = String(d.msg || "").trim() || REMIND_DEFAULT; notes.push("reminder sent");
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
        await put("due", l[i].r.id, cur.value.unit, Object.assign({}, cur.value, { remindedOn: shortDate(new Date()), reminders: (Number(cur.value.reminders) || 0) + 1, remindMsg: msg })); n++;
      }
      logAct("Asked " + Object.keys(units).length + " unit(s) to send proof of payment", "Finance");
      toast("Sent to " + Object.keys(units).length + " unit" + (Object.keys(units).length === 1 ? "" : "s") + " (" + n + " charge" + (n === 1 ? "" : "s") + ").");
    }
  });
}
