/* ==========================================================================
   parking-flow.js: walk-in payments, renewals and text messages for motor parking.
   Shared by the resident and the administrator pages.

   WALK-IN   A resident who will pay at the office taps "I'll walk in today" on the Parking page. That saves a "walkin"
             record, which the office sees on the request (so it expects the resident). The office records the payment
             at the counter (cash, check, card or e-wallet); that issues the receipt and starts the rental.
   RENEWAL   A monthly rental ends one month after it starts. The reminder days (set by the office) before the next payment is due, the
             resident gets a notice on the dashboard: renew (pay online, or walk in) or tell the office they will not renew.
   TEXTS     When a payment is approved the office "sends" the resident a text with the rental period and the next due
             date. In this prototype the text is saved and shown (nothing leaves the browser); a real SMS provider
             would be connected here: sendSms() is the one place to change.
   ========================================================================== */

// How many days before the next payment the resident is told: see parkSoonDays() in reminders.js (the office can change it).

// yyyy-mm-dd plus n days.
function isoPlus(iso, n) {
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso || ""));
  if (!m) return "";
  return dayKey(new Date(+m[1], +m[2] - 1, +m[3] + n));
}
// Whole days from one yyyy-mm-dd to another (positive when `b` is later).
function isoDaysBetween(a, b) {
  var x = /^(\d{4})-(\d{2})-(\d{2})$/.exec(a), y = /^(\d{4})-(\d{2})-(\d{2})$/.exec(b);
  if (!x || !y) return 0;
  return Math.round((Date.UTC(+y[1], +y[2] - 1, +y[3]) - Date.UTC(+x[1], +x[2] - 1, +x[3])) / 86400000);
}
// When the next monthly payment of a rental is due, and how close that is. Daily rentals have no next payment.
function parkDueInfo(v) {
  if (!v || !v.unit || v.plan === "day" || !v.until) return null;
  var nextDue = isoPlus(v.until, 1), days = isoDaysBetween(dayKey(new Date()), nextDue);
  return { until: v.until, nextDue: nextDue, days: days, soon: days <= parkSoonDays(), late: days <= 0 };
}
// "in 3 days", "tomorrow", "today", "2 days ago".
function parkDaysText(days) {
  return days > 1 ? "in " + days + " days" : days === 1 ? "tomorrow" : days === 0 ? "today" : -days + " day" + (days === -1 ? "" : "s") + " ago";
}
// The monthly amount to renew a rental: what the resident pays now, else the rate of the slot size.
function parkRenewAmount(slotId, v) {
  return Number(v && v.amount) || parkRatesFor((v && v.size) || slotSize(slotId)).month || 0;
}
// The walk-in record of a unit (renew = for a renewal), the "will not renew" note, and a renewal payment waiting for the office.
function walkinOf(unit, renew) { return getRow("walkin", unit + (renew ? "|renew" : "")); }
function leaveNoteOf(unit) { return getRow("renewal", unit); }
function renewProofOf(unit, slotId) {
  return newest(list("proof")).filter(function (r) { return r.unit === unit && r.v.forText === PARK_FOR && r.v.renew && r.v.slot === slotId && r.v.status === "Pending"; })[0] || null;
}
// "Come today" / "said they would come on Oct 27": how a walk-in reads.
function walkinText(w, who) {
  var today = dayKey(new Date());
  return w.day === today ? who + " will come to the office today." : who + " said they would come on " + usageDate(w.day) + " and has not been recorded yet.";
}
// The payment methods the office takes at the counter, and the method name that is written on the receipt.
var WALKIN_VIA = [["Cash", PAY_OFFICE], ["Check", PAY_OFFICE], ["Card (debit or credit)", "Card at the office"], ["E-wallet (GCash or Maya)", "E-wallet at the office"]];
function walkinMethod(via) { var f = WALKIN_VIA.filter(function (x) { return x[0] === via; })[0]; return f ? f[1] : PAY_OFFICE; }

/* ---------- text messages (the administrator "sends" them) ---------- */
// Saves a text for a unit and returns a short note for the toast. No real SMS leaves the prototype.
async function sendSms(unit, text) {
  var phone = typeof unitPhone === "function" ? unitPhone(unit) : "", id = nextId();
  await put("sms", id, unit, { id: id, unit: unit, to: phone, text: text, at: Date.now(), status: phone ? "Sent" : "No number" });
  logAct("Text " + (phone ? "sent to " + unit + " (" + phone + ")" : "not sent to " + unit + " (no mobile number)") + ": " + text, "Parking");
  return phone ? "A text was sent to " + phone + "." : "No mobile number is on file for " + unit + ", so no text was sent.";
}
// The text a resident gets when a parking payment is approved.
function approvedSmsText(slotId, slotVal, receipt, amount, renewed) {
  var d = parkDueInfo(slotVal);
  return "ResidentHub: Your parking payment of " + peso(amount) + " is approved. Slot " + slotId + " is " + (renewed ? "renewed" : "yours") + " until " + usageDate(slotVal.until) + "." +
    (d ? " Next payment due: " + usageDate(d.nextDue) + "." : " This daily rental ends on " + usageDate(slotVal.until) + ".") + " Receipt " + receipt + ". Thank you!";
}

/* ---------- resident: walk-in, renew, "I will not renew" ---------- */
// "I'll walk in today": tells the office to expect the resident.
function parkWalkIn(renew) {
  var unit = myUnit(), slotId, amount;
  if (renew) {
    var mine = list("slot").filter(function (s) { return s.v.unit === unit; })[0];
    if (!mine) return toast("You do not have a parking slot to renew.");
    slotId = mine.id; amount = parkRenewAmount(mine.id, mine.v);
  } else {
    var rq = getRow("request", unit);
    if (!rq || !rq.value.slot) return toast("Reserve a slot first.");
    slotId = rq.value.slot; amount = Number(rq.value.amount) || 0;
  }
  act(async function () {
    await put("walkin", unit + (renew ? "|renew" : ""), unit, { unit: unit, who: myHousehold(), slot: slotId, amount: amount, renew: !!renew, day: dayKey(new Date()), at: Date.now() });
    logAct("Walk-in payment announced, " + unit + " (" + slotId + ")", "Parking");
    toast("Sent. The office will expect you today. Pay at the counter and your " + (renew ? "rental is renewed" : "rental starts") + " as soon as the office records it.");
  });
}
function parkWalkInCancel(renew) {
  act(async function () {
    await del("walkin", myUnit() + (renew ? "|renew" : ""));
    toast("Walk-in cancelled.");
  });
}
// Opens the renewal payment form on the Parking page.
function parkRenewOpen() {
  state.parkRenew = true; state.payFor = "parking-renew"; state.payRef = ""; state.payImg = ""; state.payDate = ""; state.payPulse = true;
  var mine = list("slot").filter(function (s) { return s.v.unit === myUnit(); })[0];
  if (mine) state.payAmt = String(parkRenewAmount(mine.id, mine.v));
  render();
  var el = document.getElementById("payPanel"); if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
}
function parkRenewClose() { state.parkRenew = false; state.payFor = ""; state.payAmt = ""; render(); }
// "I won't renew": the resident tells the office so the slot can go to someone else after the rental ends.
function parkLeave() {
  var unit = myUnit(), mine = list("slot").filter(function (s) { return s.v.unit === unit; })[0];
  if (!mine) return;
  openForm({
    title: "Not renewing " + mine.id,
    intro: "Tell the office you will not renew. You keep the slot until " + usageDate(mine.v.until || "") + ", then it becomes free for other residents. You can change your mind before then.",
    fields: [{ name: "note", label: "Message to the office (optional)", type: "textarea", value: "" }],
    submit: "Tell the office",
    onSubmit: async function (d) {
      await put("renewal", unit, unit, { unit: unit, who: myHousehold(), slot: mine.id, intent: "leave", note: String(d.note || "").trim(), at: Date.now(), day: dayKey(new Date()) });
      logAct("Will not renew parking: " + unit + " (" + mine.id + ")", "Parking");
      toast("The office was told. " + mine.id + " stays yours until " + usageDate(mine.v.until || "") + ".");
    }
  });
}
function parkLeaveUndo() {
  act(async function () { await del("renewal", myUnit()); toast("Thank you. The office knows you may still renew."); });
}
// The warm notice on the resident Home page and Parking page when a rental is about to end.
function parkSoonBanner(onParkingPage) {
  var unit = myUnit(), mine = list("slot").filter(function (s) { return s.v.unit === unit; })[0];
  if (!mine) return "";
  var d = parkDueInfo(mine.v); if (!d || !d.soon || leaveNoteOf(unit)) return "";
  var paid = renewProofOf(unit, mine.id) || walkinOf(unit, true);
  if (paid && onParkingPage) return "";
  return '<div class="soon-banner ' + (d.late ? "late" : "") + '"><div><b>' + (d.late ? "Your parking rental has ended or is due now" : "Your parking rental is almost up") + "</b><span>Slot " + esc(mine.id) + " runs until " + esc(usageDate(d.until)) + ". The next payment is due " + esc(usageDate(d.nextDue)) + " (" + esc(parkDaysText(d.days)) + "). " +
    (paid ? "Your renewal is on its way to the office." : "Did you forget, or do you no longer plan to rent? Renew to keep your slot, or tell the office if you are leaving.") + '</span></div>' +
    (onParkingPage ? "" : '<button class="btn primary" onclick="set({view:\'parking\'})">Open Parking</button>') + "</div>";
}

/* ---------- administrator: the renewal side ---------- */
// Rentals that need the office: a renewal payment waiting, a walk-in announced, or a resident who will not renew.
function parkRenewalItems() {
  return list("slot").filter(function (s) { return s.v.unit && s.v.plan !== "day"; }).map(function (s) {
    var unit = s.v.unit, pr = renewProofOf(unit, s.id), w = walkinOf(unit, true), leave = leaveNoteOf(unit);
    return { slot: s, unit: unit, proof: pr, walkin: w, leave: leave, info: parkDueInfo(s.v) };
  }).filter(function (x) { return x.proof || x.walkin || x.leave; });
}

/* ---------- resident: the Walk-in step of the payment form and the renewal card ---------- */
// Step 3 of the payment form when the resident chose Walk-in: tell the office they are coming.
function walkBlockHtml(fixed) {
  var renew = !!fixed.renew, w = walkinOf(myUnit(), renew), inner;
  if (w) {
    inner = "<b>Walk-in sent</b><span>" + (w.value.day === dayKey(new Date()) ? "The office expects you today." : "You told the office you would come on " + esc(usageDate(w.value.day)) + ".") +
      " Pay at the counter with cash, check, card or e-wallet. When the office records your payment, your " + (renew ? "rental is renewed" : "rental starts") + " and you get a text message with your next due date.</span>" +
      '<button class="btn dz-mini" type="button" onclick="parkWalkInCancel(' + renew + ')">Cancel walk-in</button>';
  } else {
    inner = "<b>Paying at the office?</b><span>Tap the button so the office knows you are coming today. Pay at the counter with cash, check, card or e-wallet. The office records it and your " + (renew ? "rental is renewed" : "rental starts") + "; you get a text message with your next due date.</span>" +
      '<button class="btn primary dz-send" type="button" onclick="parkWalkIn(' + renew + ')">I\'ll walk in today</button>';
  }
  return '<div class="dz-step"><span class="n ok">3</span><div class="dz-walk">' + inner + "</div></div>";
}
// The card on the Parking page when the rental is about to end (or the resident already answered).
function parkRenewCardHtml(mine) {
  var unit = myUnit(), d = parkDueInfo(mine.v), leave = leaveNoteOf(unit), pr = renewProofOf(unit, mine.id), w = walkinOf(unit, true);
  if (!d || (!d.soon && !leave && !pr && !w)) return "";
  var tone = leave ? "info" : pr || w ? "warn" : d.late ? "bad" : "warn", title, body, acts = "";
  if (leave) {
    title = "You told the office you will not renew";
    body = "Slot " + esc(mine.id) + " stays yours until " + esc(usageDate(d.until)) + ", then it becomes free for other residents.";
    acts = '<button class="btn" onclick="parkLeaveUndo()">I changed my mind</button>';
  } else if (pr) {
    title = "Renewal payment sent";
    body = "Reference " + esc(pr.v.reference) + ". The office will verify it, then your rental is extended and you get a text message with your next due date.";
  } else if (w && !state.parkRenew) {
    title = "Walk-in sent";
    body = walkinText(w.value, "You") + " When the office records your payment, your rental is renewed.";
    acts = '<button class="btn" onclick="parkWalkInCancel(true)">Cancel walk-in</button>';
  } else {
    title = d.late ? "Your parking rental has ended or is due now" : "Your parking rental is almost up";
    body = "Slot " + esc(mine.id) + " runs until " + esc(usageDate(d.until)) + ". The next payment of <b>" + peso(parkRenewAmount(mine.id, mine.v)) + "</b> is due " + esc(usageDate(d.nextDue)) + " (" + esc(parkDaysText(d.days)) + "). Did you forget, or do you no longer plan to rent? Renew to keep your slot, or tell the office if you are leaving.";
    acts = '<button class="btn primary" onclick="parkRenewOpen()">Renew now</button><button class="btn" onclick="parkLeave()">I won\'t renew</button>';
  }
  var form = "";
  if (state.parkRenew && !leave && !pr) {
    var item = { id: "parking-renew", park: true, renew: true, title: "Motor parking renewal · " + mine.id + " · Monthly", amount: parkRenewAmount(mine.id, mine.v), dueText: usageDate(d.nextDue) };
    state.payFor = "parking-renew"; state.payAmt = String(item.amount);
    form = payFormHtml(item) + '<div><button class="btn" onclick="parkRenewClose()">Close the payment form</button></div>';
  }
  return '<div class="card soon-card ' + tone + '"><h2 style="font-size:18px;margin:0 0 4px">' + title + '</h2><p class="hint" style="margin:0 0 12px">' + body + "</p>" + (acts ? '<div style="display:flex;gap:10px;flex-wrap:wrap">' + acts + "</div>" : "") + "</div>" + form;
}
