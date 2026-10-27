/* Administrator dashboard — finance, expenses, reports, complaints and documents, parking,
   rentals, activity log, access, settings, profile, search and notifications. */

/* ==========================================================================
   Finance
   ========================================================================== */
var FIN_PAGE = 10;
// Which payment (method, reference, date) settled each paid charge: charges and payments of the same unit, text and amount are paired oldest to oldest.
function paidThrough(dues, pays) {
  var byKey = {}, out = {};
  pays.slice().sort(function (a, b) { return Number(a.id) - Number(b.id); }).forEach(function (r) { var k = r.v.unit + "|" + r.v.forText + "|" + Number(r.v.amount); (byKey[k] = byKey[k] || []).push(r.v); });
  dues.filter(function (d) { return d.v.paid; }).sort(function (a, b) { return Number(a.id) - Number(b.id); }).forEach(function (d) {
    var k = d.v.unit + "|" + d.v.note + "|" + Number(d.v.amount), p = (byKey[k] || []).shift();
    if (p) out[d.id] = p;
  });
  return out;
}
// The "Paid through" cell: the type of payment the resident used, with its reference number and date.
function paidCell(p, paid) {
  if (!paid) return '<span style="color:var(--muted)">—</span>';
  if (!p) return '<span style="color:var(--muted)">Not recorded</span>';
  return '<b>' + esc(p.method || "—") + '</b><div style="font-size:12px;color:var(--muted)">' + (p.reference && p.reference !== "—" ? "Ref " + esc(p.reference) + " · " : "") + esc(p.date || "") + "</div>";
}
// Goes to another page of the charges list.
function goFinPage(n) { state.finPage = Math.max(0, n); render(); }
function viewFin() {
  var dues = newest(list("due")), open = dues.filter(function (d) { return !d.v.paid; });
  var outstanding = open.reduce(function (s, d) { return s + Number(d.v.amount || 0); }, 0);
  var unpaidUnits = {}; open.forEach(function (d) { unpaidUnits[d.v.unit] = 1; });
  var pays = newest(list("payment"));
  var stats = [["Collected this month", peso(monthEarnings())], ["Outstanding", peso(outstanding)], ["Units with unpaid dues", String(Object.keys(unpaidUnits).length)], ["Payments recorded", String(pays.length)]];
  var fq = (state.finQ || "").trim().toLowerCase();
  var paidDues = dues.filter(function (d) { return d.v.paid; });
  var paidInfo = paidThrough(dues, pays);
  var shownDues = (state.finFilter === "unpaid" ? open : state.finFilter === "paid" ? paidDues : dues).filter(function (d) { return !fq || (d.v.unit + " " + d.v.note + " " + (d.v.name || "")).toLowerCase().indexOf(fq) >= 0; });
  var finPages = Math.max(1, Math.ceil(shownDues.length / FIN_PAGE)), finPage = Math.min(Math.max(0, state.finPage || 0), finPages - 1);
  var rows = shownDues.slice(finPage * FIN_PAGE, (finPage + 1) * FIN_PAGE);
  var year = new Date().getFullYear();
  // collection summary: every day of a month (people pay every day) or every month of the year
  var nowD = new Date(), todayKey = dayKey(nowD), selKey = state.finMonth == null ? thisMonthKey() : state.finMonth;
  var selYear = Math.floor(selKey / 12), selMon = selKey % 12, dayCount = new Date(selYear, selMon + 1, 0).getDate();
  var perDay = [], todayTotal = 0, selTotal = 0;
  for (var di = 1; di <= dayCount; di++) perDay.push({ label: String(di), value: 0, tone: "yellow", title: "" });
  vals("payment").forEach(function (p) {
    var pd = parseShort(p.date); if (!pd) return;
    var amt = Number(p.amount || 0);
    if (dayKey(pd) === todayKey) todayTotal += amt;
    if (pd.getFullYear() === selYear && pd.getMonth() === selMon) { perDay[pd.getDate() - 1].value += amt; selTotal += amt; }
  });
  perDay.forEach(function (x, i) {
    x.tone = (selKey === thisMonthKey() && i + 1 === nowD.getDate()) ? "pink" : "yellow";
    x.title = LONG_MONTHS[selMon] + " " + (i + 1) + ": " + peso(x.value);
  });
  var perMonth = MONTHS.map(function (m, i) {
    var total = vals("payment").filter(function (p) { return monthOf(p.date) === year * 12 + i; }).reduce(function (s, p) { return s + Number(p.amount || 0); }, 0);
    return { label: m, value: Math.round(total), tone: i === new Date().getMonth() ? "pink" : "yellow" };
  });
  var proofs = newest(list("proof")).filter(function (r) { return r.v.status === "Pending"; });
  // the payment desk: one resident/unit, and the unpaid charges ticked as paid
  var deskUnits = {}; open.forEach(function (d) { if (!deskUnits[d.v.unit]) deskUnits[d.v.unit] = d.v.name || ""; });
  var deskUnitIds = sortedUnits().map(function (u) { return u.id; }).filter(function (id) { return deskUnits[id] !== undefined; });
  Object.keys(deskUnits).forEach(function (id) { if (deskUnitIds.indexOf(id) < 0) deskUnitIds.push(id); });
  if (state.payUnit && deskUnits[state.payUnit] === undefined) { state.payUnit = ""; state.payDues = []; }
  var deskDues = open.filter(function (d) { return d.v.unit === state.payUnit; }).sort(function (x, y) { return Number(x.id) - Number(y.id); });
  state.payDues = (state.payDues || []).filter(function (id) { return deskDues.some(function (d) { return String(d.id) === String(id); }); });
  var deskTotal = deskDues.filter(function (d) { return state.payDues.indexOf(String(d.id)) >= 0; }).reduce(function (t, d) { return t + Number(d.v.amount || 0); }, 0);
  var deskPending = state.payUnit ? list("proof").filter(function (o) { return o.unit === state.payUnit && o.v.status === "Pending"; }).length : 0;
  var methods = payMethods();
  var rate = setting("dues_rate_sqm").rate, mrate = setting("motor_rate").rate, drate = setting("motor_rate_daily").rate;
  return '<div class="grid cols-4">' + stats.map(function (s) { return '<div class="card"><div class="stat-label">' + s[0] + '</div><div class="stat-value">' + esc(s[1]) + "</div></div>"; }).join("") + "</div>" +
    '<div class="card" style="margin-top:16px"><h2>Payments to verify</h2><p class="hint">Residents pay at the office, by bank, GCash or Maya, then send the amount, method and reference number. Check them against your records, then verify to issue a receipt. If the details are wrong, reject them and give the reason.</p>' +
    (proofs.length ? proofs.map(function (r) {
      var p = r.v;
      // the same reference number and method already used by another submission (any unit) is flagged
      var dup = list("proof").filter(function (o) { return String(o.id) !== String(r.id) && o.v.status !== "Rejected" && p.reference && p.reference !== "—" && String(o.v.reference).toLowerCase() === String(p.reference).toLowerCase() && o.v.method === p.method; })[0];
      return '<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;padding:10px 0;border-top:1px solid var(--border2)"><div style="min-width:0"><b>' + esc(p.unit) + " · " + esc(p.payer) + '</b><div style="font-size:12.5px;color:var(--muted)">' + esc(p.forText || "") + " · " + esc(p.method) + " · Ref " + esc(p.reference) + " · " + peso(Number(p.amount)) + " · " + esc(p.date) +
        (dup ? ' <span class="chip warn" title="This reference number was already submitted">Duplicate reference · also sent by ' + esc(dup.v.unit) + "</span>" : "") +
        '</div></div><div style="display:flex;gap:8px"><button class="btn" onclick="rejectProof(\'' + escAttr(r.id) + '\')">Reject</button><button class="btn primary" onclick="confirmProof(\'' + escAttr(r.id) + '\')">Verify</button></div></div>';
    }).join("") : '<p class="hint" style="margin:6px 0 0">Nothing waiting. New submissions from residents appear here right away.</p>') + "</div>" +
    '<div class="fin-grid"><div class="fin-main">' +
    '<div class="card"><div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;flex-wrap:wrap"><div><h2 style="margin:0">Collection summary</h2><p class="hint" style="margin:4px 0 0">' +
      (state.finView === "month" ? "Money collected each month of " + year + ", in pesos." : "Money collected each day of " + LONG_MONTHS[selMon] + " " + selYear + ", in pesos.") + '</p></div>' +
      '<div class="filters" style="padding:0"><button class="' + (state.finView !== "month" ? "active" : "") + '" onclick="set({finView:\'day\'})">Daily</button><button class="' + (state.finView === "month" ? "active" : "") + '" onclick="set({finView:\'month\'})">Monthly</button></div></div>' +
      (state.finView === "month" ? "" :
        '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin:12px 0 4px"><button class="btn" style="min-height:32px;padding:0 12px" onclick="finMonthShift(-1)" aria-label="Previous month">&#8249;</button><b style="min-width:130px;text-align:center">' + LONG_MONTHS[selMon] + " " + selYear + '</b><button class="btn" style="min-height:32px;padding:0 12px" onclick="finMonthShift(1)" aria-label="Next month"' + (selKey >= thisMonthKey() ? " disabled" : "") + '>&#8250;</button>' +
        '<span style="font-size:13px;color:var(--muted)">Collected today: <b style="color:var(--ink,inherit)">' + peso(todayTotal) + "</b> &middot; This month: <b>" + peso(selTotal) + "</b></span></div>") +
      (state.finView === "month" ? barChart(perMonth, "₱") : dailyChart(perDay)) + "</div>" +
    dayLogCard(dues) +
    '<div class="card fin-charges" style="padding:0;overflow:hidden"><div class="filters" style="padding:14px 18px">' +
    '<button class="' + (state.finFilter === "unpaid" ? "active" : "") + '" onclick="set({finFilter:\'unpaid\',finPage:0})">Unpaid (' + open.length + ')</button><button class="' + (state.finFilter === "paid" ? "active" : "") + '" onclick="set({finFilter:\'paid\',finPage:0})">Paid (' + paidDues.length + ')</button><button class="' + (state.finFilter === "all" ? "active" : "") + '" onclick="set({finFilter:\'all\',finPage:0})">All (' + dues.length + ')</button>' +
    '<input type="search" id="finSearchInput" value="' + escAttr(state.finQ || "") + '" oninput="set({finQ:this.value,finPage:0})" placeholder="Search unit or description..." autocomplete="off" class="fin-search"></div>' +
    tableRows(rows.map(function (r) {
      var d = r.v, od = !d.paid && isOverdue(d);
      var chip = d.paid ? '<span class="chip good">Paid</span>' : od ? '<span class="chip bad">Overdue</span>' : '<span class="chip warn">Unpaid</span>';
      return '<tr><td class="nw" style="font-weight:700">' + esc(d.unit) + "</td><td>" + esc(d.note) + (billedOn(r.id, d) ? '<div class="cell-sub">Billed ' + esc(billedOn(r.id, d)) + "</div>" : "") + (d.paid ? '<div class="cell-sub">' + paidCell(paidInfo[r.id], d.paid).replace(/<\/?div[^>]*>/g, " ").replace(/<b>/g, "Paid by <b>") + "</div>" : "") + '</td><td class="nw" style="color:var(--muted)">' + esc(d.dueDate || "On receipt") + '</td><td class="nw"><b>' + peso(Number(d.amount)) + '</b><div style="margin-top:4px">' + chip + '</div></td><td><div class="row-actions">' +
        (d.paid ? "" : '<button class="btn primary" onclick="chooseDue(\'' + escAttr(r.id) + '\')">Collect</button><button class="btn" onclick="editDue(\'' + escAttr(r.id) + '\')">Edit</button><button class="btn" onclick="remindDue(\'' + escAttr(r.id) + '\')">Remind</button>') +
        '<button class="btn danger" onclick="deleteDue(\'' + escAttr(r.id) + '\')">Delete</button></div></td></tr>';
    }), ["UNIT", "FOR", "DUE", "AMOUNT", "ACTIONS"], dues.length ? (fq ? "No charge matches your search." : "Nothing unpaid. Everyone is up to date.") : "No charges yet. Use “Bill monthly dues” or “Add charge”.") + (shownDues.length > FIN_PAGE ? pagerHtml(shownDues.length, finPage, FIN_PAGE, "goFinPage") : "") + "</div>" +
    unitDuesCard() +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2>Dues settings</h2><p class="hint" style="margin:0">Dues are charged <b>per square meter</b>. Each unit pays its floor area × this rate every month, so “Bill monthly dues” works out every unit\'s amount by itself. Set a unit\'s floor area under Units. You can still change the amount of one unit\'s charge with “Edit”.</p>' +
    '<div style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap"><label class="fl" style="width:200px">Monthly dues per sqm (₱)<input id="duesRate" type="number" min="0" step="0.01" value="' + escAttr(state.duesDraft != null ? state.duesDraft : (rate || "")) + '" oninput="state.duesDraft=this.value;duesPreview()"></label><button class="btn primary" onclick="saveDuesRate()">Save rate</button>' +
    '<span style="font-size:13px;color:var(--muted)">Current: <b>' + (rate ? peso(rate) + " per sqm" : "not set yet") + '</b></span></div>' +
    '<label style="display:flex;gap:8px;align-items:center;font-size:13.5px"><input type="checkbox" ' + (state.duesRecalc === false ? "" : "checked") + ' onchange="state.duesRecalc=this.checked"> When I save a new rate, also update the unpaid monthly dues to it</label>' +
    '<div id="duesPreview">' + duesPreviewHtml(state.duesDraft != null ? state.duesDraft : rate) + "</div>" +
    '<div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn primary" onclick="billDues()">Bill monthly dues</button><button class="btn" onclick="remindAll()">Send reminders</button><button class="btn" onclick="chargeForm()">Add charge</button><button class="btn" onclick="payMethodsForm()">Payment options</button></div></div>' +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2>Motor parking rental</h2><p class="hint" style="margin:0">Residents rent a motor/motorcycle slot for one month or by the day. Set a rate for each. The board can change them at any time.</p>' +
    '<div style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap"><label class="fl" style="width:170px">Monthly rate (₱ / month)<input id="motorRate" type="number" min="0" value="' + escAttr(state.motorDraft != null ? state.motorDraft : (mrate || "")) + '" oninput="state.motorDraft=this.value"></label><button class="btn primary" onclick="saveRate(\'motor_rate\',\'motorDraft\',\'Monthly parking rate\')">Update monthly</button>' +
    '<span style="font-size:13px;color:var(--muted)">Current: <b>' + (mrate ? peso(mrate) + "/month" : "not set yet") + "</b></span></div>" +
    '<div style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap"><label class="fl" style="width:170px">Daily rate (₱ / day)<input id="motorRateDay" type="number" min="0" value="' + escAttr(state.dailyDraft != null ? state.dailyDraft : (drate || "")) + '" oninput="state.dailyDraft=this.value"></label><button class="btn primary" onclick="saveRate(\'motor_rate_daily\',\'dailyDraft\',\'Daily parking rate\')">Update daily</button>' +
    '<span style="font-size:13px;color:var(--muted)">Current: <b>' + (drate ? peso(drate) + "/day" : "not set yet (daily option hidden)") + "</b></span></div></div></div>" +
    '<aside class="fin-side"><div class="card" id="payDesk" style="display:flex;flex-direction:column;gap:10px"><h2>Record payment</h2>' +
    '<p class="hint" style="margin:0">The resident paid at the office or online but did not update the dashboard? Record it here. The charges you tick are marked paid and the resident\'s dues go down right away.</p>' +
    '<label class="fl">Resident / unit<select onchange="choosePayUnit(this.value)"><option value="">Select a unit with unpaid charges</option>' + deskUnitIds.map(function (id) {
      return '<option value="' + escAttr(id) + '" ' + (state.payUnit === id ? "selected" : "") + ">" + esc(id) + (deskUnits[id] ? " — " + esc(deskUnits[id]) : "") + "</option>";
    }).join("") + "</select></label>" +
    (state.payUnit ? '<div class="fl"><span>Charges that were paid</span>' + deskDues.map(function (d) {
      var on = state.payDues.indexOf(String(d.id)) >= 0;
      return '<label style="display:flex;align-items:center;gap:10px;padding:6px 0;font-size:13.5px;font-weight:600;color:var(--ink,inherit);cursor:pointer"><input type="checkbox" style="width:18px;height:18px;min-height:0;padding:0;margin:0;flex:none;accent-color:#6C5CC7" ' + (on ? "checked" : "") + " onchange=\"togglePayDue('" + escAttr(d.id) + "',this.checked)\"><span style=\"flex:1\">" + esc(d.v.note) + '</span><b>' + peso(Number(d.v.amount)) + "</b></label>";
    }).join("") + "</div>" : "") +
    (deskPending ? '<div class="chip warn" style="white-space:normal;line-height:1.4">This unit also sent ' + deskPending + " payment" + (deskPending > 1 ? "s" : "") + ' for checking. The matching one is closed when you record this, so it is not counted twice.</div>' : "") +
    '<label class="fl">Paid by<select onchange="state.payMethod=this.value">' + methods.map(function (m) { return "<option " + ((state.payMethod || PAY_OFFICE) === m.name ? "selected" : "") + ">" + esc(m.name) + "</option>"; }).join("") + "</select></label>" +
    '<label class="fl">Reference no. (optional)<input id="payRef" value="' + escAttr(state.payRef) + '" oninput="state.payRef=this.value"></label>' +
    '<label class="fl">Date paid<input type="date" id="payDate" max="' + dayKey(new Date()) + '" value="' + escAttr(state.payDate || dayKey(new Date())) + '" onchange="state.payDate=this.value"></label>' +
    '<div class="kv" style="font-size:13px">' + (state.payUnit ? "<span>Charges ticked</span><b>" + state.payDues.length + "</b><span>Total received</span><b>" + peso(deskTotal) + "</b>" : '<span style="grid-column:1/-1">Choose a unit to begin.</span>') + "</div>" +
    '<button class="btn primary" onclick="recordPayment()">Record payment &amp; update dues</button></div>' +
    dailyExpensesCard() +
    '<div class="card" style="display:flex;flex-direction:column;gap:8px"><h2>Receipts</h2>' +
    (pays.slice(0, 6).map(function (r) {
      var p = r.v;
      return '<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;padding:6px 0;border-top:1px solid var(--border2)"><span style="font-size:13px"><b>' + esc(p.receiptNo) + "</b> · " + esc(p.unit) + " · " + peso(Number(p.amount)) + '<br><span style="color:var(--muted);font-size:12px">' + esc(p.method || "") + " · " + esc(p.date || "") + '</span></span><button class="btn" style="min-height:30px;padding:0 10px;font-size:12px" onclick="receiptFor(\'payment\',\'' + escAttr(r.id) + '\')">Receipt</button></div>';
    }).join("") || '<p class="hint" style="margin:0">No payments recorded yet.</p>') +
    '<button class="btn" onclick="exportPayments()">Export payments (.csv)</button><button class="btn" onclick="exportDues()">Export dues (.csv)</button></div></aside></div>';
}
// "Unit dues and payments": every unit's floor area, monthly dues (area x rate), billed, paid and balance, all computed from the records.
// Change a unit's floor area right from the Finance table. The monthly dues follow it automatically (area × rate per sqm).
function editUnitArea(unit) {
  var u = unitRec(unit) || {}, rate = Number(setting("dues_rate_sqm").rate) || 0;
  openForm({
    title: "Unit size and due day · " + unit,
    intro: "Each unit has its own due day, so payments come in on different days of the month. Each unit pays by its floor area, so units of different sizes pay different amounts. Monthly dues = floor area × " + (rate ? peso(rate) + " per sqm" : "the rate per sqm (set it first under Dues settings)") + ".",
    fields: [
      { name: "area", label: "Floor area (sqm)", type: "number", step: "0.01", value: u.area || "", placeholder: "e.g. 45" },
      { name: "dueDay", label: "Dues are due on day (1 to 31)", type: "number", step: "1", value: u.dueDay || "", placeholder: "e.g. 15" },
      { name: "recalc", label: "Charges not paid yet", type: "select", options: ["Recalculate the unpaid monthly dues with the new size", "Keep them as billed"], value: "Recalculate the unpaid monthly dues with the new size" }
    ],
    submit: "Save",
    onSubmit: async function (d) {
      var area = parseFloat(d.area);
      if (!(area > 0)) return { error: "Enter the floor area in square meters, e.g. 45." };
      var dueDay = d.dueDay === "" || d.dueDay == null ? "" : parseInt(d.dueDay, 10);
      if (dueDay !== "" && !(dueDay >= 1 && dueDay <= 31)) return { error: "The due day is a day of the month from 1 to 31." };
      await put("unit", unit, unit, Object.assign({}, u, { unit: unit, area: area, dueDay: dueDay }));
      var n = 0;
      if (rate > 0 && String(d.recalc).indexOf("Recalculate") === 0) {
        var open = list("due").filter(function (r) { return r.v.unit === unit && !r.v.paid && Number(r.v.area) > 0 && Number(r.v.rate) > 0; });
        for (var i = 0; i < open.length; i++) {
          await put("due", open[i].id, unit, Object.assign({}, open[i].v, { area: area, rate: rate, amount: Math.round(area * rate * 100) / 100 }));
          n++;
        }
      }
      logAct("Unit size set, " + unit + ": " + area + " sqm" + (n ? " (" + n + " unpaid monthly charge" + (n === 1 ? "" : "s") + " updated)" : ""), "Units");
      toast(unit + " is now " + area + " sqm" + (rate ? ", monthly dues " + peso(Math.round(area * rate * 100) / 100) : "") + (n ? ". " + n + " unpaid monthly charge" + (n === 1 ? "" : "s") + " updated." : "."));
    }
  });
}
// The price calculator under "Dues settings": what a unit of each size pays at the rate being typed (floor area × rate).
function duesPreviewHtml(raw) {
  var rate = parseFloat(raw), units = sortedUnits();
  if (!(rate > 0)) return '<p class="hint" style="margin:0">Type the price per square meter to see what every unit size will pay. It is worked out automatically (floor area × price).</p>';
  var groups = {}, none = 0, total = 0;
  units.forEach(function (r) { var a = Number(r.v.area) || 0; if (!(a > 0)) { none++; return; } groups[a] = (groups[a] || 0) + 1; total += Math.round(a * rate * 100) / 100; });
  var sizes = Object.keys(groups).map(Number).sort(function (a, b) { return a - b; });
  var rows = sizes.map(function (a) { return '<tr><td style="font-weight:700">' + a + ' sqm</td><td>' + a + " × " + peso(rate) + '</td><td style="font-weight:700">' + peso(Math.round(a * rate * 100) / 100) + "</td><td style=\"color:var(--muted)\">" + groups[a] + " unit" + (groups[a] === 1 ? "" : "s") + "</td></tr>"; }).join("");
  return '<div style="border:1px solid var(--border2);border-radius:14px;overflow:hidden"><div style="padding:10px 14px;font-size:13px;font-weight:700;background:var(--soft,rgba(120,115,217,.08))">Price calculator · ' + peso(rate) + ' per sqm</div>' +
    (rows ? '<div style="max-height:220px;overflow:auto"><table><thead><tr><th>SIZE</th><th>CALCULATION</th><th>MONTHLY DUES</th><th>UNITS</th></tr></thead><tbody>' + rows + "</tbody></table></div>" : '<p class="hint" style="margin:10px 14px">No unit has a floor area yet. Set it with “Edit size” in the table above.</p>') +
    '<div style="padding:10px 14px;font-size:13px;color:var(--muted)">All units, one month: <b style="color:inherit">' + peso(total) + "</b>" + (none ? " · " + none + " unit" + (none === 1 ? " has" : "s have") + " no size yet" : "") + "</div></div>";
}
function duesPreview() { var el = document.getElementById("duesPreview"); if (el) el.innerHTML = duesPreviewHtml(state.duesDraft); }
// Saves the dues rate per sqm; optionally brings the unpaid monthly dues (billed from floor area) up to the new rate.
function saveDuesRate() {
  var n = parseFloat(state.duesDraft);
  if (!(n > 0)) return toast("Enter an amount above zero.");
  act(async function () {
    await put("setting", "dues_rate_sqm", "", { rate: n });
    var k = 0;
    if (state.duesRecalc !== false) {
      var open = list("due").filter(function (r) { return !r.v.paid && Number(r.v.area) > 0 && Number(r.v.rate) > 0 && Number(r.v.rate) !== n; });
      for (var i = 0; i < open.length; i++) { await put("due", open[i].id, open[i].v.unit, Object.assign({}, open[i].v, { rate: n, amount: Math.round(Number(open[i].v.area) * n * 100) / 100 })); k++; }
    }
    logAct("Monthly dues per sqm set to " + peso(n) + (k ? " (" + k + " unpaid monthly charge" + (k === 1 ? "" : "s") + " updated)" : ""), "Finance");
    state.duesDraft = null;
    toast("Monthly dues per sqm saved." + (k ? " " + k + " unpaid monthly charge" + (k === 1 ? "" : "s") + " updated to the new rate." : ""));
  });
}
// Reminders: the resident sees "Reminder from the office" under Notifications until the charge is paid.
function remindDue(id) {
  var row = getRow("due", id); if (!row) return;
  act(async function () {
    var v = Object.assign({}, row.value, { remindedOn: shortDate(new Date()), reminders: (Number(row.value.reminders) || 0) + 1 });
    await put("due", id, v.unit, v);
    logAct("Reminder sent, " + v.unit + ": " + v.note, "Finance");
    toast("Reminder sent to " + v.unit + ". They will see it under Notifications.");
  });
}
// Reminds every unit that has an unpaid charge which is overdue, due within 7 days, or has no due date.
function remindAll() {
  var today = Date.now(), list2 = list("due").filter(function (r) {
    if (r.v.paid) return false;
    if (!r.v.dueDate) return true;
    var d = parseShort(r.v.dueDate); return !d || d.getTime() - today < 7 * 86400000;
  });
  if (!list2.length) return toast("No charge is overdue or due in the next 7 days.");
  var units = {}; list2.forEach(function (r) { units[r.v.unit] = 1; });
  confirmBox("Send reminders?", list2.length + " unpaid charge" + (list2.length === 1 ? "" : "s") + " (" + Object.keys(units).length + " unit" + (Object.keys(units).length === 1 ? "" : "s") + ") are overdue or due within 7 days. Each of those residents will see a reminder under Notifications.", "Send reminders", async function () {
    for (var i = 0; i < list2.length; i++) await put("due", list2[i].id, list2[i].v.unit, Object.assign({}, list2[i].v, { remindedOn: shortDate(new Date()), reminders: (Number(list2[i].v.reminders) || 0) + 1 }));
    logAct("Reminders sent to " + Object.keys(units).length + " unit(s)", "Finance");
    toast("Reminders sent to " + Object.keys(units).length + " unit" + (Object.keys(units).length === 1 ? "" : "s") + ".");
  });
}
function unitDuesCard() {
  var rate = Number(setting("dues_rate_sqm").rate) || 0, tb = 0, tp = 0, tbal = 0;
  var rows = sortedUnits().map(function (r) {
    var x = unitDues(r.id); tb += x.billed; tp += x.paid; tbal += x.balance;
    return "<tr><td style=\"font-weight:700\">" + esc(r.id) + '</td><td style="color:var(--muted)">' + (x.area ? esc(String(x.area)) + " sqm" : '<span class="chip warn">No area</span>') + "</td><td>" + (x.area && rate ? peso(x.monthly) : "—") + '</td><td style="color:var(--muted)">' + (r.v.dueDay ? "Day " + esc(String(r.v.dueDay)) : "—") + "</td><td>" + peso(x.billed) + "</td><td>" + peso(x.paid) + '</td><td style="font-weight:700">' + (x.balance ? peso(x.balance) : "—") + '</td><td><button class="btn" style="min-height:30px;padding:0 12px" onclick="editUnitArea(\'' + escAttr(r.id) + '\')">' + (x.area ? "Edit size" : "Set size") + "</button></td></tr>";
  });
  return '<div class="card" style="padding:0;overflow:hidden"><div style="padding:16px 18px 6px"><h2 style="margin:0">Unit dues and payments</h2><p class="hint" style="margin:4px 0 0">Worked out automatically. Floor area × rate per sqm = monthly dues. Billed, paid and balance come from the charges and receipts, so they update as soon as you bill or record a payment.</p>' +
    '<p style="margin:8px 0 0;font-size:13px;color:var(--muted)">All units: billed <b>' + peso(tb) + "</b> · paid <b>" + peso(tp) + "</b> · balance <b>" + peso(tbal) + "</b></p></div>" +
    '<div style="max-height:380px;overflow:auto">' + tableRows(rows, ["UNIT", "AREA", "MONTHLY DUES", "DUE DAY", "BILLED", "PAID", "BALANCE", ""], "No units yet.") + "</div></div>";
}
// Popup form to change the amount (or due date) of one unit's unpaid charge.
function editDue(id) {
  var row = getRow("due", id);
  if (!row || row.value.paid) return toast("Only an unpaid charge can be edited.");
  var c = row.value;
  openForm({
    title: "Edit charge · " + c.unit,
    intro: (c.note || "") + (c.area && c.rate ? ". Worked out as " + c.area + " sqm × " + peso(c.rate) + " = " + peso(c.area * c.rate) + ". Changing the amount affects this unit only." : ". Changing the amount affects this unit only."),
    fields: [{ name: "amount", label: "Amount (₱)", type: "number", step: "0.01", value: c.amount }, { name: "due", label: "Due date (optional)", value: c.dueDate || "", placeholder: "e.g. Oct 30, 2026" }],
    onSubmit: async function (d) {
      var a = parseFloat(d.amount);
      if (!(a > 0)) return { error: "Enter a valid amount." };
      var due = c.dueDate || "";
      if (d.due) { var p = parseShort(d.due); if (!p) return { error: 'Enter the due date like "Oct 15, 2026".' }; due = shortDate(p); } else due = "";
      var cur = getRow("due", id);
      if (!cur || cur.value.paid) return { error: "This charge was already paid." };
      await put("due", id, cur.unit, Object.assign({}, cur.value, { amount: a, dueDate: due, edited: true }));
      logAct("Charge edited, " + c.unit + ": " + peso(Number(c.amount)) + " to " + peso(a), "Finance");
      toast("Charge updated.");
    }
  });
}
// "Daily expenses" on the Finance page: what was bought on one day, next to what was collected that day.
function dailyExpensesCard() {
  var day = state.finExpDay || dayKey(new Date());
  var items = newest(list("expense")).filter(function (r) { return r.v.date === day; });
  var spent = items.reduce(function (t, r) { return t + expTotal(r.v); }, 0);
  var got = vals("payment").reduce(function (t, p) { var d = parseShort(p.date); return d && dayKey(d) === day ? t + Number(p.amount || 0) : t; }, 0);
  return '<div class="card" style="display:flex;flex-direction:column;gap:8px"><h2>Daily expenses</h2><p class="hint" style="margin:0">Record what the corporation buys each day.</p>' +
    '<label class="fl">Day<input type="date" value="' + escAttr(day) + '" onchange="set({finExpDay:this.value})"></label>' +
    '<div class="kv" style="font-size:13px"><span>Collected</span><b>' + peso(got) + "</b><span>Spent</span><b>" + peso(spent) + "</b><span>Net</span><b>" + (got - spent < 0 ? "-" + peso(spent - got) : peso(got - spent)) + "</b></div>" +
    (items.map(function (r) { var e = r.v; return '<div style="display:flex;justify-content:space-between;gap:8px;padding:6px 0;border-top:1px solid var(--border2);font-size:13px"><span><b>' + esc(e.item) + '</b><br><span style="color:var(--muted);font-size:12px">' + esc(e.payee || e.category || "") + "</span></span><b>" + peso(expTotal(e)) + "</b></div>"; }).join("") || '<p class="hint" style="margin:0">Nothing recorded for this day yet.</p>') +
    '<button class="btn primary" onclick="expenseForm(null,state.finExpDay||dayKey(new Date()))">+ Add expense</button><button class="btn" onclick="set({view:\'expenses\'})">All expenses &amp; monthly report</button></div>';
}
// "Day by day": who paid on a day (today and before) and which charges fall due on a day (today and after).
function dayKeyAdd(k, n) { var p = k.split("-"); return dayKey(new Date(+p[0], +p[1] - 1, +p[2] + n)); }
function dayLogShift(n) { set({ logDay: dayKeyAdd(state.logDay || dayKey(new Date()), n) }); }
function dayLogCard(dues) {
  var today = dayKey(new Date()), sel = state.logDay || today;
  var pays = vals("payment"), openDues = dues.filter(function (d) { return !d.v.paid; });
  function paidOn(k) { return pays.filter(function (p) { var d = parseShort(p.date); return d && dayKey(d) === k; }); }
  function dueOn(k) { return openDues.filter(function (d) { var x = parseShort(d.v.dueDate); return x && dayKey(x) === k; }); }
  function sum(a, f) { return a.reduce(function (t, x) { return t + Number(f(x) || 0); }, 0); }
  var strip = "";
  for (var i = -3; i <= 3; i++) {
    var k = dayKeyAdd(sel, i), p = k.split("-"), dt = new Date(+p[0], +p[1] - 1, +p[2]);
    var future = k > today, a = future ? dueOn(k) : paidOn(k);
    var amt = sum(a, function (x) { return future ? x.v.amount : x.amount; });
    strip += '<button class="btn' + (k === sel ? " primary" : "") + '" style="flex:1;min-width:74px;flex-direction:column;gap:2px;padding:8px 4px;min-height:0;line-height:1.25" onclick="set({logDay:\'' + k + '\'})">' +
      '<span style="font-size:11px;opacity:.8">' + (k === today ? "Today" : dt.toLocaleDateString("en-US", { weekday: "short" })) + '</span><b style="font-size:14px">' + MONTHS[dt.getMonth()] + " " + dt.getDate() + '</b>' +
      '<span style="font-size:11px;font-weight:600">' + (a.length ? a.length + (future ? " due" : " paid") + " · " + peso(amt) : "—") + "</span></button>";
  }
  var paid = paidOn(sel), due = dueOn(sel), isFuture = sel > today;
  var selDate = parseShort(shortDateFromKey(sel));
  var head = (sel === today ? "Today" : selDate.toLocaleDateString("en-US", { weekday: "long" })) + ", " + shortDateFromKey(sel);
  function row(a, b, c) { return '<div style="display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-top:1px solid var(--border2);font-size:13.5px"><span style="min-width:0"><b>' + a + '</b><br><span style="color:var(--muted);font-size:12.5px">' + b + "</span></span><b>" + c + "</b></div>"; }
  var paidHtml = isFuture ? "" : '<h3 style="margin:14px 0 2px;font-size:14px">Paid this day · ' + peso(sum(paid, function (x) { return x.amount; })) + "</h3>" +
    (paid.length ? paid.map(function (x) { return row(esc(x.unit) + " · " + esc(x.payer || ""), esc(x.forText || "") + " · " + esc(x.method || "") + (x.receiptNo ? " · Receipt " + esc(x.receiptNo) : ""), peso(Number(x.amount))); }).join("") : '<p class="hint" style="margin:4px 0 0">Nobody paid on this day.</p>');
  var dueHtml = '<h3 style="margin:14px 0 2px;font-size:14px">' + (sel < today ? "Was due this day and still unpaid" : "Due this day") + " · " + peso(sum(due, function (x) { return x.v.amount; })) + "</h3>" +
    (due.length ? due.map(function (x) { return row(esc(x.v.unit) + (x.v.name ? " · " + esc(x.v.name) : ""), esc(x.v.note || ""), peso(Number(x.v.amount))); }).join("") : '<p class="hint" style="margin:4px 0 0">No charge falls due on this day.</p>');
  return '<div class="card"><div style="display:flex;justify-content:space-between;align-items:flex-start;gap:10px;flex-wrap:wrap"><div><h2 style="margin:0">Day by day</h2><p class="hint" style="margin:4px 0 0">See who paid on each day, and who is expected to pay on the coming days.</p></div>' +
    '<div style="display:flex;gap:6px;align-items:center"><button class="btn" style="min-height:32px;padding:0 12px" onclick="dayLogShift(-1)" aria-label="Previous day">&#8249;</button><input type="date" value="' + escAttr(sel) + '" onchange="set({logDay:this.value||dayKey(new Date())})" style="min-height:32px"><button class="btn" style="min-height:32px;padding:0 12px" onclick="dayLogShift(1)" aria-label="Next day">&#8250;</button>' +
    (sel !== today ? '<button class="btn" style="min-height:32px;padding:0 12px" onclick="set({logDay:\'\'})">Today</button>' : "") + "</div></div>" +
    '<div style="display:flex;gap:6px;margin:12px 0 4px;overflow-x:auto">' + strip + "</div>" +
    '<h3 style="margin:12px 0 0;font-size:15px">' + head + "</h3>" + paidHtml + dueHtml + "</div>";
}
// Bars for every day of a month (small labels, only days with money show an amount).
function dailyChart(days) {
  var max = Math.max.apply(null, days.map(function (d) { return d.value; })) || 1;
  function short(v) { return v >= 1000 ? (Math.round(v / 100) / 10) + "k" : String(Math.round(v)); }
  return '<div class="vbars" style="gap:3px;height:190px;overflow:hidden">' + days.map(function (d) {
    return '<div class="vbar" title="' + escAttr(d.title) + '" style="gap:6px"><div class="vb-track"><span class="vb-val" style="font-size:9.5px;min-height:12px">' + (d.value ? short(d.value) : "") + '</span><i class="' + d.tone + '" style="height:' + Math.max(3, d.value / max * 78) + '%;max-width:22px;border-radius:6px 6px 3px 3px"></i></div><span class="vb-lab" style="font-size:9.5px">' + d.label + "</span></div>";
  }).join("") + "</div>";
}
// Goes to the previous or next month of the daily summary.
function finMonthShift(n) {
  var k = (state.finMonth == null ? thisMonthKey() : state.finMonth) + n;
  if (k > thisMonthKey()) return;
  set({ finMonth: k });
}
// "Collect" on a charge: opens the payment desk for that unit with that charge ticked.
function chooseDue(id) {
  var row = id ? getRow("due", id) : null;
  state.payUnit = row ? row.value.unit : "";
  state.payDues = row ? [String(id)] : [];
  render();
  if (id) { var el = document.getElementById("payDesk"); if (el && window.innerWidth < 1100) el.scrollIntoView({ behavior: "smooth", block: "start" }); }
}
// Picks the resident / unit in the payment desk; the oldest unpaid charge is ticked first.
function choosePayUnit(unit) {
  state.payUnit = unit || "";
  var first = unit ? firstOpenDue(unit) : null;
  state.payDues = first ? [String(first.id)] : [];
  render();
}
// Ticks or unticks a charge in the payment desk.
function togglePayDue(id, on) {
  var l = (state.payDues || []).filter(function (x) { return x !== String(id); });
  if (on) l.push(String(id));
  state.payDues = l;
  render();
}
// Saves a changed rate (dues or parking).
function saveRate(id, draftKey, label) {
  var n = parseFloat(state[draftKey]);
  if (!(n > 0)) return toast("Enter an amount above zero.");
  act(async function () {
    await put("setting", id, "", { rate: n });
    logAct(label + " set to " + peso(n), "Finance");
    state[draftKey] = null;
    toast(label + " saved.");
  });
}
// Deletes a due after confirming.
function deleteDue(id) {
  confirmBox("Delete this charge?", "It will be removed for the resident too.", "Delete", async function () { await del("due", id); logAct("Charge deleted", "Finance"); }, true);
}
// Creates a payment record with a receipt number and marks the due as paid.
async function issuePayment(unit, payer, forText, method, reference, amount, receiptNo, dateText) {
  var no = receiptNo || nextReceiptNo(), date = dateText || shortDate(new Date()), pid = nextId();
  await put("payment", pid, unit, { id: pid, receiptNo: no, unit: unit, payer: payer, forText: forText, method: method, reference: reference || "—", date: date, amount: amount });
  return { no: no, date: date };
}
// Admin records a payment received (cash, bank, GCash...) for one or more charges of a unit. The charges become paid, so the resident's dues go down.
function recordPayment() {
  if (!state.payUnit) return toast("Choose the resident or unit first.");
  var ids = (state.payDues || []).slice().sort(function (x, y) { return Number(x) - Number(y); });
  if (!ids.length) return toast("Tick the charge or charges that were paid.");
  var when = null;
  if (state.payDate) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(state.payDate);
    when = m ? new Date(+m[1], +m[2] - 1, +m[3]) : null;
    if (!when || isNaN(when.getTime())) return toast("Enter a valid date paid.");
    if (when.getTime() > Date.now()) return toast("The date paid cannot be in the future.");
  }
  var dateText = when ? shortDate(when) : shortDate(new Date());
  act(async function () {
    var unit = state.payUnit, done = 0, total = 0, lastNo = "";
    for (var k = 0; k < ids.length; k++) {
      var row = getRow("due", ids[k]);
      if (!row || row.value.paid) continue;
      var cur = row.value;
      // a submission the resident already sent for this charge is closed with the same receipt (so "Verify" cannot settle another charge later)
      var pend = list("proof").filter(function (o) { return o.unit === cur.unit && o.v.status === "Pending" && o.v.forText === cur.note; })[0];
      var method = state.payMethod || (pend && pend.v.method) || PAY_OFFICE, ref = state.payRef || (pend && pend.v.reference !== "—" ? pend.v.reference : "");
      await put("due", ids[k], row.unit, Object.assign({}, cur, { paid: true }));
      var r = await issuePayment(cur.unit, cur.name || cur.unit, cur.note, method, ref, cur.amount, "", dateText);
      if (pend) await put("proof", pend.id, pend.unit, Object.assign({}, pend.v, { status: "Confirmed", method: method, reference: ref || "—", receiptNo: r.no, confirmedOn: r.date }));
      else { var qid = nextId(); await put("proof", qid, cur.unit, { id: qid, unit: cur.unit, payer: cur.name || cur.unit, forText: cur.note, method: method, reference: ref || "—", amount: cur.amount, date: r.date, status: "Confirmed", receiptNo: r.no, confirmedOn: r.date, direct: true }); }
      done++; total += Number(cur.amount || 0); lastNo = r.no;
    }
    if (!done) throw new Error("Those charges are already paid.");
    logAct("Payment recorded, " + unit + " (" + done + " charge" + (done === 1 ? "" : "s") + ", " + peso(total) + ")", "Finance");
    state.payUnit = ""; state.payDues = []; state.payRef = ""; state.payDate = "";
    toast(done === 1 ? "Payment recorded. Receipt " + lastNo + " issued." : done + " charges marked paid (" + peso(total) + "). Receipts issued.");
  });
}
// Verifies a resident's payment proof and issues the receipt.
function confirmProof(id) {
  var row = getRow("proof", id);
  if (!row || row.value.status !== "Pending") return;
  act(async function () {
    var p = Object.assign({}, row.value);
    p.status = "Confirmed"; p.receiptNo = nextReceiptNo(); p.confirmedOn = shortDate(new Date());
    // the charge the resident named, else the oldest open charge (parking and "other" payments settle no charge)
    var open = vals("due").filter(function (d) { return d.unit === p.unit && !d.paid; }).sort(function (a, b) { return a.id - b.id; });
    var named = open.filter(function (d) { return d.note === p.forText; })[0];
    var other = p.forText === "Motor parking rental" || p.forText === "Other charge";
    var due = named || (other ? null : open[0]);
    if (due) {
      await put("due", due.id, p.unit, Object.assign({}, due, { paid: true }));
      p.forText = due.note;
    } else if (!p.forText) p.forText = "Association dues";
    await put("proof", id, row.unit, p);
    await issuePayment(p.unit, p.payer, p.forText, p.method, p.reference, p.amount, p.receiptNo);
    logAct("Payment recorded, " + p.unit, "Finance");
    // a paid parking reservation: the chosen slot goes to the resident straight away
    var assigned = "";
    if (p.forText === PARK_FOR && p.slot) {
      var rq = getRow("request", p.unit), sl = getRow("slot", p.slot);
      if (rq && !rq.value.confirmed && rq.value.slot === p.slot && sl && !sl.value.unit) {
        await put("slot", p.slot, "", parkSlotFromRequest(p.slot, rq.value));
        await put("request", p.unit, rq.unit, Object.assign({}, rq.value, { confirmed: true }));
        logAct("Parking slot " + p.slot + " assigned to " + p.unit + " (paid)", "Parking");
        assigned = p.slot;
      }
    }
    toast(assigned ? "Payment verified. Slot " + assigned + " is now assigned to " + p.unit + "." : "Payment verified. Receipt " + p.receiptNo + " is ready for " + p.unit + ".");
  });
}
// Rejects a payment proof. The administrator gives a reason; it is kept with the submission and shown to the resident.
function rejectProof(id) {
  var row = getRow("proof", id);
  if (!row || row.value.status !== "Pending") return;
  openForm({
    title: "Reject payment details",
    intro: "Tell the resident what is wrong, for example a wrong reference number or amount. They can then send the correct details. The rejected submission stays in the record with your reason, does not count toward the balance and gets no receipt.",
    submit: "Reject",
    fields: [{ name: "reason", label: "Reason", type: "textarea", value: "", placeholder: "e.g. Reference number not found. Please check it." }],
    onSubmit: async function (d) {
      var reason = String(d.reason || "").trim();
      if (!reason) return { error: "Enter the reason so the resident knows what to correct." };
      var cur = getRow("proof", id);
      if (!cur || cur.value.status !== "Pending") return { error: "This submission was already handled." };
      await put("proof", id, cur.unit, Object.assign({}, cur.value, { status: "Rejected", reason: reason, rejectedOn: shortDate(new Date()) }));
      logAct("Payment rejected, " + cur.value.unit + ": " + reason, "Finance");
      toast("Payment details rejected. The resident will see the reason.");
    }
  });
}
// Creates the monthly dues for the units: each unit's floor area x the rate per sqm.
function billDues() {
  var now = new Date();
  openForm({
    title: "Bill monthly dues",
    intro: "Adds one charge for every unit that has not been billed for this month yet. Each charge is worked out automatically: the unit's floor area × the rate per sqm, and it falls due on that unit's own due day, so payments come in all through the month.",
    fields: [{ name: "period", label: "Month", value: LONG_MONTHS[now.getMonth()] + " " + now.getFullYear() },
      { name: "due", label: "Due date for units without a due day (optional)", placeholder: "e.g. " + shortDate(new Date(now.getFullYear(), now.getMonth(), 15)) }],
    submit: "Bill",
    onSubmit: async function (d) {
      var rate = Number(setting("dues_rate_sqm").rate);
      if (!(rate > 0)) return { error: "Set the monthly dues per square meter first." };
      var units = sortedUnits();
      if (!units.length) return { error: "Add the units first." };
      if (!d.period) return { error: "Enter the month, e.g. October 2026." };
      var due = "";
      if (d.due) { var p = parseShort(d.due); if (!p) return { error: 'Enter the due date like "Oct 15, 2026".' }; due = shortDate(p); }
      var note = "Association dues - " + d.period, n = 0, noArea = 0, existing = vals("due");
      var pm = LONG_MONTHS.findIndex(function (m) { return d.period.toLowerCase().indexOf(m.toLowerCase()) >= 0; }), py = (/(20\d\d)/.exec(d.period) || [])[1];
      if (pm < 0) pm = now.getMonth();
      py = py ? Number(py) : now.getFullYear();
      for (var i = 0; i < units.length; i++) {
        var u = units[i], area = Number(u.v.area);
        if (existing.some(function (x) { return x.unit === u.id && x.note === note; })) continue;
        if (!(area > 0)) { noArea++; continue; }
        var id = nextId();
        var ud = Number(u.v.dueDay) >= 1 ? shortDate(new Date(py, pm, Math.min(Number(u.v.dueDay), new Date(py, pm + 1, 0).getDate()))) : due;
        await put("due", id, u.id, { id: id, unit: u.id, name: u.v.name && u.v.name !== "—" ? u.v.name : "", amount: Math.round(area * rate * 100) / 100, area: area, rate: rate, billedOn: shortDate(new Date()), note: note, dueDate: ud });
        n++;
      }
      logAct("Dues billed for " + d.period + ": " + n + " unit" + (n === 1 ? "" : "s"), "Finance");
      toast((n ? "Billed " + n + " unit" + (n === 1 ? "" : "s") + " (floor area × " + peso(rate) + " per sqm). Each resident is notified under Notifications and Dues." : "Nobody new to bill for that month.") + (noArea ? " " + noArea + " unit" + (noArea === 1 ? " has" : "s have") + " no floor area yet; add it under Units." : ""));
    }
  });
}
// Popup form to add a special charge.
function chargeForm() {
  var units = unitNames();
  if (!units.length) return toast("Add a unit first.");
  openForm({
    title: "Add charge",
    fields: [{ name: "unit", label: "Unit", type: "select", options: units }, { name: "amount", label: "Amount (₱)", type: "number", step: "0.01" },
      { name: "note", label: "Description", placeholder: "e.g. Facility damage fee" }, { name: "due", label: "Due date (optional)", placeholder: "e.g. Oct 30, 2026" }],
    onSubmit: async function (d) {
      var a = parseFloat(d.amount);
      if (!(a > 0)) return { error: "Enter a valid amount." };
      if (!d.note) return { error: "Add a short description, e.g. Facility damage fee." };
      var due = "";
      if (d.due) { var p = parseShort(d.due); if (!p) return { error: 'Enter the due date like "Oct 15, 2026".' }; due = shortDate(p); }
      var id = nextId(), u = unitRec(d.unit) || {};
      await put("due", id, d.unit, { id: id, unit: d.unit, name: u.name && u.name !== "—" ? u.name : "", amount: a, note: d.note, dueDate: due, billedOn: shortDate(new Date()) });
      logAct("Charge added, " + d.unit + ": " + d.note, "Finance");
    }
  });
}
// Popup form to choose the allowed payment methods.
function payMethodsForm() {
  var ms = payMethods(), fields = [];
  ms.forEach(function (m, i) {
    fields.push({ name: "en" + i, label: m.name, type: "select", options: [["1", "On"], ["0", "Off"]], value: m.enabled ? "1" : "0" });
    if (m.name !== PAY_OFFICE) fields.push({ name: "d" + i, label: m.name + " — details", type: "textarea", value: m.details });
  });
  openForm({
    title: "Payment options", intro: "Residents see only the options that are On.", fields: fields,
    onSubmit: async function (d) {
      var l = ms.map(function (m, i) { return { name: m.name, details: m.name === PAY_OFFICE ? m.details : (d["d" + i] || m.details), enabled: d["en" + i] === "1" }; });
      await put("setting", "paymethods", "", { list: l });
      logAct("Payment options updated", "Finance");
    }
  });
}
// Downloads payments as CSV.
function exportPayments() {
  exportCSV("payments.csv", ["Receipt no.", "Date", "Unit", "Paid by", "Payment for", "Method", "Reference no.", "Amount"],
    newest(list("payment")).map(function (r) { var p = r.v; return [p.receiptNo, p.date, p.unit, p.payer, p.forText, p.method, p.reference, p.amount]; }));
}
// Downloads dues as CSV.
function exportDues() {
  exportCSV("dues.csv", ["Unit", "For", "Due date", "Amount", "Status"], newest(list("due")).map(function (r) { return [r.v.unit, r.v.note, r.v.dueDate || "", r.v.amount, r.v.paid ? "Paid" : "Unpaid"]; }));
}

/* ==========================================================================
   Expenses
   ========================================================================== */
function expTotal(e) { return Number(e.qty || 1) * Number(e.unitPrice || 0); }
// PAGE: Expenses.
function viewExpenses() {
  var now = new Date();
  if (!state.expMonth) state.expMonth = now.getFullYear() + "-" + pad(now.getMonth() + 1);
  if (!state.expDay) state.expDay = dayKey(now);
  var all = newest(list("expense"));
  var inMonth = all.filter(function (r) { return String(r.v.date || "").slice(0, 7) === state.expMonth; })
    .sort(function (a, b) { return String(b.v.date).localeCompare(String(a.v.date)); });
  var total = inMonth.reduce(function (s, r) { return s + expTotal(r.v); }, 0);
  var dayTotal = all.filter(function (r) { return r.v.date === state.expDay; }).reduce(function (s, r) { return s + expTotal(r.v); }, 0);
  var rows = inMonth.map(function (r) {
    var e = r.v;
    return "<tr><td>" + esc(e.date) + '</td><td><b>' + esc(e.item) + '</b><div style="font-size:12px;color:var(--muted)">' + esc(e.payee || "") + (e.receiptNo ? " · OR " + esc(e.receiptNo) : "") + "</div></td><td>" + esc(e.category) + "</td><td>" + esc(e.area || "") + '</td><td style="font-weight:700">' + peso(expTotal(e)) +
      '</td><td><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="expenseForm(\'' + escAttr(r.id) + '\')">Edit</button> <button class="btn" style="min-height:32px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="deleteExpense(\'' + escAttr(r.id) + '\')">Delete</button></td></tr>';
  });
  return '<div class="expense-toolbar"><label>Report month <input id="expMonth" type="month" value="' + escAttr(state.expMonth) + '" onchange="set({expMonth:this.value})"></label>' +
    '<button class="btn primary" onclick="expenseForm(null)">+ Add purchase</button><button class="btn" onclick="exportExpenses()" ' + (inMonth.length ? "" : "disabled") + ">Export month CSV</button></div>" +
    '<div class="expense-stats grid cols-3" style="margin-bottom:16px"><div class="card"><div class="stat-label">Monthly expenses</div><div class="stat-value">' + peso(total) + '</div><p class="hint" style="margin:6px 0 0">' + inMonth.length + " purchase" + (inMonth.length === 1 ? "" : "s") + " in " + esc(state.expMonth) + "</p></div>" +
    '<div class="card"><label class="stat-label" for="expDay">Daily expenses</label><input id="expDay" type="date" value="' + escAttr(state.expDay) + '" onchange="set({expDay:this.value})"><div class="stat-value">' + peso(dayTotal) + "</div></div></div>" +
    '<div class="card" style="padding:0;overflow:hidden">' + tableRows(rows, ["DATE", "ITEM", "CATEGORY", "FOR", "TOTAL", ""], "No purchases recorded for this month.") + "</div>";
}
// Popup form to add or edit an expense.
function expenseForm(id, day) {
  var e = id ? (getRow("expense", id) || {}).value || {} : {};
  openForm({
    title: id ? "Edit purchase" : "Add purchase",
    fields: [
      { name: "item", label: "What was bought", value: e.item },
      { name: "category", label: "Category", type: "select", options: EXP_CATS, value: e.category || EXP_CATS[0] },
      { name: "area", label: "For", type: "select", options: EXP_AREAS, value: e.area || EXP_AREAS[0] },
      { name: "payee", label: "Store / supplier", value: e.payee },
      { name: "qty", label: "Quantity", type: "number", step: "any", value: e.qty || 1 },
      { name: "unitPrice", label: "Price of one (₱)", type: "number", step: "0.01", value: e.unitPrice },
      { name: "receiptNo", label: "Official receipt no. (optional)", value: e.receiptNo },
      { name: "date", label: "Date", type: "date", value: e.date || day || dayKey(new Date()) },
      { name: "note", label: "Note (optional)", value: e.note }
    ],
    onSubmit: async function (d) {
      if (!d.item) return { error: "Enter what was bought." };
      var qty = d.qty === "" ? 1 : parseFloat(d.qty), price = parseFloat(d.unitPrice);
      if (!(qty > 0)) return { error: "Enter a valid quantity." };
      if (!(price > 0)) return { error: "Enter the price of one." };
      if (!d.date) return { error: "Choose the date." };
      var eid = id || nextId();
      await put("expense", eid, "__admin", { id: Number(eid), item: d.item, category: d.category, area: d.area, payee: d.payee, receiptNo: d.receiptNo, note: d.note, qty: qty, unitPrice: price, date: d.date });
      logAct((id ? "Purchase updated: " : "Purchase recorded: ") + d.item, "Expenses");
    }
  });
}
// Deletes an expense.
function deleteExpense(id) {
  confirmBox("Delete this purchase?", "This cannot be undone.", "Delete", async function () { await del("expense", id); logAct("Purchase deleted", "Expenses"); }, true);
}
// Downloads expenses as CSV.
function exportExpenses() {
  var rows = newest(list("expense")).filter(function (r) { return String(r.v.date || "").slice(0, 7) === state.expMonth; });
  exportCSV("expenses-" + state.expMonth + ".csv", ["Date", "Item", "Category", "For", "Store", "OR no.", "Qty", "Price of one", "Total"],
    rows.map(function (r) { var e = r.v; return [e.date, e.item, e.category, e.area || "", e.payee || "", e.receiptNo || "", e.qty || 1, e.unitPrice, expTotal(e)]; }));
}

/* ==========================================================================
   Reports
   ========================================================================== */
function reportData() {
  var units = list("unit"), open = list("due").filter(function (r) { return !r.v.paid; });
  var unpaidUnits = {}; open.forEach(function (r) { unpaidUnits[r.v.unit] = 1; });
  var nUnpaid = Object.keys(unpaidUnits).length;
  var gr = [0, 1, 2].map(function (k) { return vals("grievance").filter(function (g) { return Math.min(2, Number(g.stage) || 0) === k; }).length; });
  var now = new Date(), months = [];
  for (var k = 5; k >= 0; k--) {
    var d = new Date(now.getFullYear(), now.getMonth() - k, 1), key = d.getFullYear() * 12 + d.getMonth();
    months.push({ label: MONTHS[d.getMonth()], value: Math.round(vals("payment").filter(function (p) { return monthOf(p.date) === key; }).reduce(function (s, p) { return s + Number(p.amount || 0); }, 0)), tone: k === 0 ? "pink" : "yellow" });
  }
  var age = [0, 0, 0, 0];
  open.forEach(function (r) {
    var due = parseShort(r.v.dueDate), m = due ? Math.floor((Date.now() - due.getTime()) / (30 * 86400000)) : 0;
    age[m <= 0 ? 0 : m === 1 ? 1 : m === 2 ? 2 : 3]++;
  });
  var mk = thisMonthKey();
  var fac = facilities().map(function (f, i) {
    return { label: f.name, value: vals("booking").filter(function (b) { var dd = b.day && parseShort(shortDateFromKey(b.day)); return b.status === "Approved" && b.place === f.name && dd && dd.getFullYear() * 12 + dd.getMonth() === mk; }).length, tone: ["blue", "yellow", "green", "pink"][i % 4] };
  });
  return { units: units, nUnpaid: nUnpaid, gr: gr, months: months, age: age, fac: fac };
}
// '2026-10-16' -> 'Oct 16, 2026'.
function shortDateFromKey(k) { var p = String(k).split("-"); return p.length === 3 ? MONTHS[+p[1] - 1] + " " + (+p[2]) + ", " + p[0] : ""; }
// PAGE: Reports.
function viewReports() {
  var r = reportData(), total = r.units.length;
  var rate = total ? Math.round((total - r.nUnpaid) / total * 100) + "%" : "—";
  var occ = r.units.filter(function (u) { return u.v.status !== "Vacant"; }).length;
  var usage = Object.keys(USAGE_NAMES).map(function (k, i) { return { label: USAGE_NAMES[k], value: r.units.filter(function (u) { return (u.v.usage || "owner") === k; }).length, tone: ["green", "blue", "yellow", "pink", "ink", "blue"][i] }; }).filter(function (p) { return p.value > 0; });
  var grd = ["Open", "In progress", "Resolved"].map(function (n, k) { return { label: n, value: r.gr[k], tone: ["pink", "yellow", "green"][k] }; });
  var ageing = [{ label: "Not yet due", value: r.age[0], tone: "blue" }, { label: "1 month", value: r.age[1], tone: "green" }, { label: "2 months", value: r.age[2], tone: "yellow" }, { label: "3+ months", value: r.age[3], tone: "pink" }];
  var openPolls = pollsAll().filter(function (p) { return p.open; });
  var empty = '<p class="empty">Nothing to show yet.</p>';
  return '<div class="filters"><button class="btn" style="margin-left:auto" onclick="downloadReport()">Download report (.csv)</button></div>' +
    '<div class="sc-grid">' + summaryCard("yellow", "Collections", [[rate, "Units paid up"], [r.nUnpaid, "Units with unpaid dues", "fin"]], "cross") +
    summaryCard("pink", "Earnings", [[peso(monthEarnings()), "This month"]], "heart") +
    summaryCard("green", "Occupancy", [[total ? Math.round(occ / total * 100) + "%" : "—", "Occupied"], [total - occ, "Vacant", "units"]], "triangle") +
    summaryCard("blue", "Requests", [[r.gr[0] + r.gr[1], "Open"], [r.gr[2], "Resolved", "req"]], "burst") + "</div>" +
    '<div class="two-col-e"><div class="card"><h2>Collections, last 6 months</h2><p class="hint">Money received, in pesos.</p>' + barChart(r.months, "₱") + "</div>" +
    '<div class="card"><h2>Dues ageing</h2><p class="hint">Unpaid charges by how long they are overdue.</p>' + (r.age.some(Boolean) ? barChart(ageing) : empty) + "</div>" +
    '<div class="card"><h2>Unit usage</h2><p class="hint">From the ' + total + " units on record.</p>" + (usage.length ? donutChart(usage, String(total), "units") : empty) + "</div>" +
    '<div class="card"><h2>Complaints by status</h2><p class="hint">Updates as you move requests forward.</p>' + (r.gr.some(Boolean) ? donutChart(grd, String(r.gr[0] + r.gr[1] + r.gr[2]), "requests") : empty) + "</div>" +
    '<div class="card"><h2>Facility use this month</h2><p class="hint">Approved bookings.</p>' + (r.fac.some(function (f) { return f.value; }) ? barChart(r.fac) : empty) + "</div>" +
    '<div class="card"><h2>Poll turnout</h2><p class="hint">Units that voted in each open poll.</p>' + (openPolls.map(function (p) { return progressBar(esc(p.q), list("vote").filter(function (x) { return Number(x.v.poll) === p.id; }).length, total, "blue"); }).join("") || '<p class="empty">No open polls.</p>') + "</div></div>";
}
// Downloads the summary report as a CSV file.
function downloadReport() {
  var r = reportData(), c = counts(), total = r.units.length;
  exportCSV("city-residences-report.csv", ["Metric", "Value"], [
    ["Units on record", total], ["Earnings this month", monthEarnings()], ["Units with unpaid dues", r.nUnpaid],
    ["Units paid up", total ? Math.round((total - r.nUnpaid) / total * 100) + "%" : "—"], ["Open grievances", c.grievances],
    ["Pending booking requests", c.bookings], ["Parking slots used", list("slot").filter(function (s) { return s.v.unit; }).length + " of " + list("slot").length]]);
  logAct("Report downloaded", "Reports");
}

/* ==========================================================================
   Complaints and documents
   ========================================================================== */
function viewReq() {
  var grs = newest(list("grievance")), names = ["Open", "In progress", "Resolved"];
  var docs = newest(list("doc"));
  return (grs.length ? '<div class="grid cols-3">' + grs.map(function (r) {
    var g = r.v, s = Math.min(2, Math.max(0, Number(g.stage) || 0));
    var steps = names.map(function (n, k) { return '<span class="chip ' + (k === s ? (k === 2 ? "good" : k === 1 ? "warn" : "bad") : "info") + '" style="' + (k === s ? "" : "background:#F1E9D8;color:#6F6753") + '">' + n + "</span>"; }).join(" ");
    return '<div class="card"><div><div style="font:700 17px \'Bricolage Grotesque\',\'Source Sans 3\',sans-serif">' + esc(g.title) + '</div><div style="font-size:12px;color:var(--muted);margin-top:2px">Reported by ' + esc(g.by || r.unit) + '</div><p style="font-size:13px;color:var(--muted);margin:8px 0 0">' + esc(g.body) + "</p></div>" +
      '<div style="display:flex;gap:6px;margin:10px 0">' + steps + "</div>" + (s < 2 ? '<button class="btn primary" style="width:100%" onclick="advanceGr(\'' + escAttr(r.id) + '\')">' + (s === 0 ? "Start working on it" : "Mark resolved") + "</button>" : "") + "</div>";
  }).join("") + "</div>" : emptyCard("No complaints from residents yet.")) +
    '<div class="card" style="padding:0;overflow:hidden;margin-top:16px"><div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;padding:14px 18px"><h2 style="font-size:19px;flex-grow:1">Community documents</h2>' +
    '<select id="docCat" style="height:38px">' + DOC_CATS.map(function (c) { return "<option>" + c + "</option>"; }).join("") + '</select><select id="docAud" style="height:38px"><option value="all">Everyone</option><option value="admin">Admin only</option></select>' +
    '<input type="file" id="docFileInput" style="display:none" onchange="uploadDoc(this)"><button class="btn primary" onclick="document.getElementById(\'docFileInput\').click()">+ Upload file</button></div>' +
    (docs.map(function (r) {
      var d = r.v;
      return '<div style="display:flex;align-items:center;gap:12px;padding:0 18px;min-height:50px;border-top:1px solid var(--border2);font-size:14px;flex-wrap:wrap"><span style="flex-grow:1;font-weight:700">' + esc(d.name) + '</span><span style="color:var(--muted)">' + esc(d.cat || "Other") + '</span><span style="color:var(--muted)">' + esc(d.date) + "</span>" +
        (d.audience === "admin" ? '<span class="chip warn">Admin only</span>' : "") + '<button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="openDoc(\'' + escAttr(r.id) + '\')">View</button><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="removeDoc(\'' + escAttr(r.id) + '\')">Delete</button></div>';
    }).join("") || '<div style="padding:18px;border-top:1px solid var(--border2);color:var(--muted)">No documents yet. Upload a file (up to 2 MB).</div>') + "</div>";
}
// Moves a complaint to its next stage.
function advanceGr(id) {
  var row = getRow("grievance", id); if (!row) return;
  act(async function () {
    var st = Math.min(2, (Number(row.value.stage) || 0) + 1);
    await put("grievance", id, row.unit, Object.assign({}, row.value, { stage: st }));
    logAct("Complaint " + (st === 2 ? "resolved" : "in progress") + ": " + row.value.title, "Requests");
  });
}
// Uploads a document for residents.
function uploadDoc(input) {
  var file = input.files && input.files[0]; if (!file) return;
  if (file.size > 2 * 1024 * 1024) { input.value = ""; return toast("That file is bigger than 2 MB. Choose a smaller file."); }
  var cat = document.getElementById("docCat").value, aud = document.getElementById("docAud").value;
  var rd = new FileReader();
  rd.onload = function () {
    act(async function () {
      var b64 = String(rd.result).split(",")[1] || "";
      var m = /^(.*)\.([A-Za-z0-9]+)$/.exec(file.name), name = m ? m[1] : file.name, ext = m ? m[2].toLowerCase() : "";
      var id = String(nextId());
      await put("doc", id, aud === "admin" ? "__admin" : "", { id: id, name: name, cat: cat, date: shortDate(new Date()), audience: aud, ext: ext, raw: b64 });
      logAct("Document uploaded: " + file.name, "Documents");
      toast("Document uploaded.");
    });
    input.value = "";
  };
  rd.readAsDataURL(file);
}
// Deletes a document.
function removeDoc(id) {
  confirmBox("Delete this document?", "Residents will no longer see it.", "Delete", async function () { await del("doc", id); logAct("Document deleted", "Documents"); }, true);
}

/* ==========================================================================
   Parking
   ========================================================================== */
function sortedSlots() { return list("slot").sort(function (a, b) { return naturalCompare(a.id, b.id); }); }
// PAGE: Parking (slots, requests, rentals).
function viewParking() {
  var slots = sortedSlots(), used = slots.filter(function (s) { return s.v.unit; }).length, rate = setting("motor_rate").rate || 0;
  var monthly = slots.filter(function (s) { return s.v.unit && s.v.plan !== "day"; }).length, daily = used - monthly;
  var reqs = list("request").filter(function (r) { return !r.v.confirmed; }).sort(function (a, b) { return (a.v.at || 0) - (b.v.at || 0); });
  if (!slots.length) {
    return '<div class="card" style="display:flex;flex-direction:column;gap:10px;max-width:520px"><h2>Set up motor parking</h2><p class="hint" style="margin:0">There are no slots yet. Tell the system how many motor parking slots the building has. They are named M-01, M-02, and so on.</p>' +
      '<button class="btn primary" onclick="addSlotsForm()">Add slots</button></div>' + (reqs.length ? '<p class="hint" style="margin-top:12px">' + reqs.length + " resident request(s) are waiting for slots.</p>" : "");
  }
  return '<div class="grid cols-3">' + statCard("Slots in use", used + " of " + slots.length) + statCard("Monthly rentals income", peso(monthly * rate)) + statCard("Requests waiting", String(reqs.length)) + "</div>" +
    '<div class="two-col-r" style="grid-template-columns:minmax(0,1.6fr) minmax(0,1fr)"><div class="card"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><h2>Motor parking slots</h2><button class="btn" onclick="addSlotsForm()">+ Add slots</button></div>' +
    '<p class="hint">Tap a slot to assign it, remove the resident, rename it or delete it. Rates: ' + (rate ? peso(rate) + "/month" : "monthly not set") + " · " + (setting("motor_rate_daily").rate ? peso(setting("motor_rate_daily").rate) + "/day" : "daily not set") + " (change them under Finance).</p>" +
    '<div class="slotgrid">' + slots.map(function (s) { var h = heldSlots()[s.id]; return '<button class="pslot ' + (s.v.unit ? "used" : h ? "held" : "free") + '" onclick="openSlot(\'' + escAttr(s.id) + '\')"><b>' + esc(s.id) + "</b><small>" + esc(s.v.unit || (h ? "Held · " + h : "Free")) + "</small></button>"; }).join("") + "</div></div>" +
    '<div class="card"><h2>Requests</h2><p class="hint">Residents who reserved or asked for a slot. A reserved slot is approved when its payment is verified.</p>' + (reqs.map(function (r) {
      var v = r.v, pr = v.slot ? parkProof(r.id, v.slot) : null, pst = pr ? pr.v.status : "", state;
      var btns;
      if (v.slot && v.amount) {
        state = pr ? (pst === "Confirmed" ? '<span class="chip good">Verified</span>' : '<span class="chip warn">Payment sent · Ref ' + esc(pr.v.reference) + "</span>") : '<span class="chip info">Waiting for payment</span>';
        btns = pr ? (pst === "Confirmed" ? '<button class="btn primary" onclick="approveParking(\'' + escAttr(r.id) + '\')">Assign ' + esc(v.slot) + "</button>" : '<button class="btn primary" onclick="confirmProof(\'' + escAttr(pr.id) + '\')">Verify payment</button>') : '<button class="btn" onclick="approveParkingFree(\'' + escAttr(r.id) + '\')">Assign without payment</button>';
        btns += '<button class="btn" onclick="declineParking(\'' + escAttr(r.id) + '\')">Decline</button>';
      } else {
        state = v.slot ? '<span class="chip info">Chose ' + esc(v.slot) + "</span>" : "";
        btns = '<button class="btn primary" onclick="approveParking(\'' + escAttr(r.id) + '\')">Assign' + (v.slot ? " " + esc(v.slot) : "") + '</button><button class="btn" onclick="declineParking(\'' + escAttr(r.id) + '\')">Decline</button>';
      }
      return '<div class="req-row"><div><b>' + esc(v.unit) + "</b><small>" + esc(v.who || "") + " · " + esc(v.when || "") + (v.slot ? " · Slot " + esc(v.slot) + (v.amount ? " · " + peso(Number(v.amount)) : "") : "") + (v.plan ? " · " + esc(parkPlanText(v.plan, v.days)) : "") + "</small>" + (state ? '<div style="margin-top:6px">' + state + "</div>" : "") + "</div><div>" + btns + "</div></div>";
    }).join("") || '<p class="empty">No requests waiting.</p>') + "</div></div>" + rentalsCard(slots);
}
/* who has a slot: one row each, with how long the rental runs and a Remove button */
function rentalsCard(slots) {
  var rows = slots.filter(function (s) { return s.v.unit; }).sort(function (a, b) { return naturalCompare(a.v.unit, b.v.unit); });
  return '<div class="card" style="padding:0;overflow:hidden;margin-top:16px"><div style="padding:14px 18px"><h2 style="margin:0">Current rentals</h2><p class="hint" style="margin:4px 0 0">Everyone who has a slot, and whether it is rented for a month or by the day. Remove ends the rental and frees the slot.</p></div>' +
    tableRows(rows.map(function (s) {
      var v = s.v, exp = parkExpired(v);
      return '<tr><td style="font-weight:700">' + esc(v.unit) + "</td><td>" + esc(s.id) + "</td><td>" + (v.plan === "day" ? "Daily" : "Monthly") + '</td><td style="color:var(--muted)">' + (v.until ? esc(usageDate(v.from)) + " – " + esc(usageDate(v.until)) : "No end date") + "</td><td>" +
        (exp ? '<span class="chip bad">Ended</span>' : '<span class="chip good">Active</span>') + ' <button class="btn" style="min-height:32px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="removeRental(\'' + escAttr(s.id) + '\')">Remove</button></td></tr>';
    }), ["UNIT", "SLOT", "PLAN", "RENTAL PERIOD", "STATUS"], "No slot is rented yet.") + "</div>";
}
/* the next n slot names (M-01, M-02, ...) that no slot uses yet, so adding never overwrites a slot */
function freshSlotIds(n) {
  var used = {}, top = 0;
  list("slot").forEach(function (r) { used[r.id] = true; var m = /^M-(\d+)$/.exec(r.id); if (m) top = Math.max(top, Number(m[1])); });
  var out = [], i = top;
  while (out.length < n) { i++; var id = "M-" + pad(i); if (!used[id]) out.push(id); }
  return out;
}
// Popup form to add parking slots.
function addSlotsForm() {
  openForm({
    title: "Add motor parking slots", intro: "How many slots should be added? Existing slots stay as they are.",
    fields: [{ name: "n", label: "Number of slots to add", type: "number", value: sortedSlots().length ? "" : "24" }], submit: "Add",
    onSubmit: async function (d) {
      var n = parseInt(d.n, 10);
      if (!(n >= 1 && n <= 200)) return { error: "Enter a number from 1 to 200." };
      var ids = freshSlotIds(n);
      for (var i = 0; i < ids.length; i++) await put("slot", ids[i], "", { id: ids[i] });
      logAct(n + " motor parking slot" + (n === 1 ? "" : "s") + " added", "Parking");
    }
  });
}
// Click on a slot: shows who has it, or (if free) the form to assign it to a unit.
function openSlot(id) {
  var s = getRow("slot", id); if (!s) return;
  if (s.value.unit) {
    openModal("<h2>" + esc(id) + "</h2><p>Assigned to <b>" + esc(s.value.unit) + '</b>.</p><p class="hint" style="margin:0">' + esc(parkRentalLine(s.value) || "Monthly") + (parkExpired(s.value) ? " (ended)" : "") + (s.value.amount ? " · " + peso(Number(s.value.amount)) : "") + '</p><div class="modal-actions"><button class="btn primary" onclick="removeRental(\'' + escAttr(id) + '\')">Remove resident</button><button class="btn" onclick="renameSlotForm(\'' + escAttr(id) + '\')">Rename</button><button class="btn" style="color:#A02B1D" onclick="removeSlot(\'' + escAttr(id) + '\')">Delete</button><button class="btn" onclick="closeModal()">Keep</button></div>');
  } else {
    var taken = vals("slot").map(function (x) { return x.unit; });
    var choices = unitNames().filter(function (u) { return taken.indexOf(u) < 0; });
    var pick = choices.length ? '<label class="fl">Unit<select id="pkUnit">' + choices.map(function (u) { return "<option>" + esc(u) + "</option>"; }).join("") + '</select></label>' : '<p class="hint">Every unit already has a slot, or there are no units yet.</p>';
    var plan = '<label class="fl">Rental<select id="pkPlan"><option value="month">Monthly (1 month)</option><option value="day">Daily (by the day)</option></select></label><label class="fl">Number of days (daily only)<input id="pkDays" type="number" min="1" max="365" value="1"></label>';
    openModal("<h2>" + esc(id) + '</h2><p>This slot is free. Choose a unit and how long it rents it, or rename or delete the slot.</p>' + pick + (choices.length ? plan : "") + '<div class="modal-actions">' + (choices.length ? '<button class="btn primary" onclick="assignSlot(\'' + escAttr(id) + '\')">Assign slot</button>' : "") + '<button class="btn" onclick="renameSlotForm(\'' + escAttr(id) + '\')">Rename</button><button class="btn" style="color:#A02B1D" onclick="removeSlot(\'' + escAttr(id) + '\')">Delete</button><button class="btn" onclick="closeModal()">Cancel</button></div>');
  }
}
// Assigns a slot to a unit.
function assignSlot(id) {
  var unit = document.getElementById("pkUnit").value, plan = document.getElementById("pkPlan").value, days = parseInt(document.getElementById("pkDays").value, 10) || 1;
  closeModal();
  act(async function () {
    var q = parkQuote(plan, days);
    await put("slot", id, "", parkSlotValue(id, unit, q.plan, q.days, q.amount));
    var rq = getRow("request", unit);
    if (rq) await put("request", unit, rq.unit, Object.assign({}, rq.value, { confirmed: true }));
    logAct("Parking slot " + id + " assigned to " + unit + " (" + parkPlanText(q.plan, q.days) + ")", "Parking");
    toast(id + " assigned to " + unit + ".");
  });
}
/* the admin takes a resident off a slot: the rental ends and the slot is free again */
function removeRental(id) {
  var s = getRow("slot", id); closeModal(); if (!s || !s.value.unit) return;
  var unit = s.value.unit;
  confirmBox("Remove " + unit + " from " + id + "?", "The " + (s.value.plan === "day" ? "daily" : "monthly") + " rental ends now and " + id + " becomes free for other residents. Nothing is refunded automatically.", "Remove", async function () {
    await put("slot", id, "", { id: id });
    if (getRow("request", unit)) await del("request", unit);
    logAct("Parking rental ended: " + unit + " removed from " + id, "Parking");
    toast(unit + " removed. " + id + " is free.");
  }, true);
}
// Popup form to rename a slot.
function renameSlotForm(id) {
  var s = getRow("slot", id); closeModal(); if (!s) return;
  openForm({
    title: "Rename " + id, intro: "Use the name painted on the parking space, e.g. B1-05. The resident keeps the slot.",
    fields: [{ name: "name", label: "Slot name", value: id }], submit: "Save",
    onSubmit: async function (d) {
      var name = String(d.name || "").trim();
      if (!name) return { error: "Enter a name for the slot." };
      if (name === id) return;
      if (list("slot").some(function (r) { return r.id.toLowerCase() === name.toLowerCase(); })) return { error: name + " already exists." };
      await put("slot", name, "", Object.assign({}, s.value, { id: name }));
      await del("slot", id);
      logAct("Parking slot " + id + " renamed to " + name, "Parking");
    }
  });
}
// Deletes a parking slot.
function removeSlot(id) {
  var s = getRow("slot", id); closeModal(); if (!s) return;
  var unit = s.value.unit;
  confirmBox("Delete " + id + "?", unit ? id + " is assigned to " + unit + ". Deleting it takes the slot away from them and removes it from the parking area." : "The slot is removed from the parking area. Nobody is using it.", "Delete", async function () {
    await del("slot", id);
    if (unit && getRow("request", unit)) await del("request", unit);
    logAct("Parking slot " + id + " deleted" + (unit ? " (was " + unit + ")" : ""), "Parking");
  }, true);
}
// Approves a parking request and gives the unit its chosen slot (or the first free one).
function approveParking(unit) {
  var rq = getRow("request", unit); if (!rq) return;
  var chosen = rq.value.slot ? getRow("slot", rq.value.slot) : null;
  var target = chosen ? chosen.id : (sortedSlots().filter(function (s) { return !s.v.unit && !heldSlots()[s.id]; })[0] || {}).id;
  if (!target) return toast("There are no free slots right now.");
  if (chosen && chosen.value.unit) return toast(chosen.id + " is already taken. Decline this request or ask the resident to pick another slot.");
  act(async function () {
    await put("slot", target, "", parkSlotFromRequest(target, rq.value));
    await put("request", unit, rq.unit, Object.assign({}, rq.value, { confirmed: true }));
    logAct("Parking slot " + target + " assigned to " + unit + " (" + parkPlanText(rq.value.plan, rq.value.days) + ")", "Parking");
    toast(target + " assigned to " + unit + ".");
  });
}
/* assign without a payment: the office decides to waive it */
function approveParkingFree(unit) {
  confirmBox("Assign without payment?", unit + " has not paid yet. The slot is assigned and no payment is recorded.", "Assign anyway", async function () {
    var rq = getRow("request", unit); if (!rq) return;
    var id = rq.value.slot; if (!id) return;
    var sl = getRow("slot", id); if (!sl || sl.value.unit) throw new Error(id + " is already taken.");
    await put("slot", id, "", parkSlotFromRequest(id, rq.value));
    await put("request", unit, rq.unit, Object.assign({}, rq.value, { confirmed: true }));
    logAct("Parking slot " + id + " assigned to " + unit + " without payment", "Parking");
  }, true);
}
// Declines a parking request.
function declineParking(unit) {
  act(async function () { await del("request", unit); logAct("Parking request declined, " + unit, "Parking"); });
}

/* ==========================================================================
   Rentals and unit usage
   ========================================================================== */
function rentalCards(list) {
  return list.map(function (r) {
      var u = r.v, chip = u.usageStatus === "approved" ? '<span class="chip good">Approved</span>' : u.usageStatus === "rejected" ? '<span class="chip bad">Rejected</span>' : '<span class="chip warn">Pending review</span>';
      return '<div class="card rental-card' + (u.usageStatus === "pending" ? " pending" : "") + '" style="display:flex;flex-direction:column;gap:8px"><div style="display:flex;justify-content:space-between;align-items:baseline;gap:10px;flex-wrap:wrap"><div><span style="font-weight:700;font-size:16px">' + esc(r.id) + '</span><span style="color:var(--muted);font-size:13px"> · ' + esc(u.name || "—") + '</span></div><span style="display:flex;gap:8px;align-items:center">' + chip + '<span class="chip ' + usageChipClass(u.usage) + '">' + esc(usageLabel(u.usage)) + "</span></span></div>" +
        (usageInfoRows(u).length ? '<div class="kv detail-kv">' + usageInfoRows(u).map(function (x) { return "<span>" + esc(x[0]) + "</span><b>" + esc(x[1]) + "</b>"; }).join("") + "</div>" : '<div style="font-size:13px;color:var(--muted)">' + esc(u.statusNote || "No additional details provided.") + "</div>") + (u.usageRemark ? '<div style="font-size:12px;color:#A02B1D">Your note to the resident: “' + esc(u.usageRemark) + "”</div>" : "") +
        (u.usageStatus === "pending" || !u.usageStatus ? '<div style="display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap;border-top:1px solid var(--border2);padding-top:10px"><div class="field" style="flex-grow:1;min-width:200px"><label style="font-size:12px;font-weight:700;color:var(--muted)">Note (optional, shown to resident if rejected)</label><input id="rentalNote-' + escAttr(r.id.replace(/\s+/g, "")) + '" placeholder="e.g. Please submit your barangay business permit"></div><button class="btn primary" onclick="rentalAct(\'' + escAttr(r.id) + '\',\'approved\')">Approve</button><button class="btn" onclick="rentalAct(\'' + escAttr(r.id) + '\',\'rejected\')">Reject</button></div>' : "") + "</div>";
  }).join("");
}
function viewRentals() {
  var units = sortedUnits(), flagged = units.filter(function (r) { return needsApproval(r.v); });
  // pending reviews first, then the rest in unit order
  var waiting = flagged.filter(function (r) { return r.v.usageStatus === "pending"; }), decided = flagged.filter(function (r) { return r.v.usageStatus !== "pending"; });
  var pending = flagged.filter(function (r) { return r.v.usageStatus === "pending"; }).length;
  var approved = flagged.filter(function (r) { return r.v.usageStatus === "approved"; }).length;
  var rejected = flagged.filter(function (r) { return r.v.usageStatus === "rejected"; }).length;
  return '<div class="grid cols-3">' + statCard("Awaiting review", String(pending)) + statCard("Approved", String(approved)) + statCard("Rejected", String(rejected)) + "</div>" +
    '<div class="card" style="margin-top:16px;font-size:13px;color:var(--muted)">Residents declare this themselves under their portal\'s <b>Unit Status</b> page. Short-term rentals (e.g. Airbnb) and home-based businesses need your review here before they are marked Approved — owner-occupied units and long-term tenant leases do not need approval.</div>' +
    (waiting.length === 0 ? '<div class="card" style="margin-top:16px;color:var(--muted)">Nothing is waiting for your review right now.' + (flagged.length ? '' : ' No unit has declared a short-term rental or business yet.') + '</div>' : '<div class="rental-grid">' + rentalCards(waiting) + "</div>") +
    (decided.length ? '<details class="card" style="margin-top:16px"><summary style="cursor:pointer;font-weight:700">Already decided: ' + approved + " approved, " + rejected + ' rejected</summary><div class="rental-grid" style="margin-top:14px">' + rentalCards(decided) + "</div></details>" : "") +
    '<div class="card" style="padding:0;overflow:hidden;margin-top:16px"><div style="display:flex;align-items:center;padding:14px 18px"><h2 style="font-size:19px;flex-grow:1">All units by usage</h2><button class="btn" onclick="exportUnits()">Export .csv</button></div>' +
    tableRows(units.map(function (r) {
      return '<tr><td style="font-weight:700">' + esc(r.id) + "</td><td>" + esc(r.v.name || "—") + "</td><td>" + usageCellHtml(r.v) + '</td><td style="color:var(--muted)">' + esc(r.v.statusNote || "") + '</td><td><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="setUsageForm(\'' + escAttr(r.id) + '\')">Change</button></td></tr>';
    }), ["UNIT", "RESIDENT", "USAGE", "NOTE", ""], "No units yet.") + "</div>";
}
// Approves or rejects a unit's rental/business usage request.
function rentalAct(unit, decision) {
  var u = unitRec(unit); if (!u) return;
  var el = document.getElementById("rentalNote-" + unit.replace(/\s+/g, "")), note = el ? el.value.trim() : "";
  act(async function () {
    await put("unit", unit, unit, Object.assign({}, u, { usageStatus: decision, usageRemark: decision === "rejected" ? (note || "Not approved at this time. Please contact the office.") : "" }));
    logAct((decision === "approved" ? "Approved" : "Rejected") + " unit usage declaration for " + unit, "Units");
  });
}
// Popup form for the admin to set a unit's usage.
function setUsageForm(unit) {
  var u = unitRec(unit) || {};
  openForm({
    title: "Unit usage — " + unit,
    fields: [{ name: "usage", label: "How is the unit used?", type: "select", options: Object.keys(USAGE_NAMES).map(function (k) { return [k, USAGE_NAMES[k]]; }), value: u.usage || "owner" },
      { name: "note", label: "Note (tenant name, platform, business type...)", type: "textarea", value: u.statusNote }],
    onSubmit: async function (d) {
      var date = shortDate(new Date());
      var next = Object.assign({}, u, { usage: d.usage, usageStatus: (d.usage === "shortterm" || d.usage === "business") ? "approved" : "", usageRemark: "", statusNote: d.note, statusDate: date, status: d.usage === "vacant" ? "Vacant" : "Occupied" });
      if (d.usage !== u.usage) delete next.usageInfo;
      await put("unit", unit, unit, next);
      var sid = nextId();
      await put("statusUpdate", sid, unit, { id: sid, unit: unit, key: d.usage, note: d.note, date: date, by: "Admin" });
      logAct(unit + " status set to " + usageLabel(d.usage).toLowerCase(), "Units");
    }
  });
}

/* ==========================================================================
   Activity log
   ========================================================================== */
var LOG_PAGE = 15;
/* page buttons: « ‹ 1 2 [3] 4 5 › » and a "Showing 31–45 of 120" line */
function pagerHtml(total, page, size, fn) {
  var pages = Math.max(1, Math.ceil(total / size)), from = total ? page * size + 1 : 0, to = Math.min(total, (page + 1) * size);
  var lo = Math.max(0, Math.min(page - 2, pages - 5)), hi = Math.min(pages - 1, lo + 4), nums = [];
  for (var i = lo; i <= hi; i++) nums.push('<button class="pg-btn ' + (i === page ? "on" : "") + '" ' + (i === page ? 'aria-current="page"' : "") + ' onclick="' + fn + "(" + i + ')">' + (i + 1) + "</button>");
  return '<div class="pager"><span class="pager-info">Showing ' + from + "–" + to + " of " + total + '</span><div class="pager-btns">' +
    '<button class="pg-btn" ' + (page === 0 ? "disabled" : "") + ' onclick="' + fn + '(0)" aria-label="First page">«</button>' +
    '<button class="pg-btn" ' + (page === 0 ? "disabled" : "") + ' onclick="' + fn + "(" + (page - 1) + ')" aria-label="Previous page">‹ Prev</button>' + nums.join("") +
    '<button class="pg-btn" ' + (page >= pages - 1 ? "disabled" : "") + ' onclick="' + fn + "(" + (page + 1) + ')" aria-label="Next page">Next ›</button>' +
    '<button class="pg-btn" ' + (page >= pages - 1 ? "disabled" : "") + ' onclick="' + fn + "(" + (pages - 1) + ')" aria-label="Last page">»</button></div></div>';
}
// Goes to another page of the activity log.
function goLogPage(n) { state.logPage = Math.max(0, n); render(); window.scrollTo({ top: 0, behavior: "smooth" }); }
// PAGE: Activity log.
function viewLog() {
  var rows = newest(list("activity")), pages = Math.max(1, Math.ceil(rows.length / LOG_PAGE));
  var page = Math.min(Math.max(0, state.logPage || 0), pages - 1);
  return '<div class="filters"><span style="font-size:13px;color:var(--muted)">' + rows.length + ' entries</span><button class="btn" style="margin-left:auto" onclick="exportLog()">Export to Excel (.csv)</button></div>' +
    '<div class="card" style="padding:0;overflow:hidden">' + tableRows(rows.slice(page * LOG_PAGE, (page + 1) * LOG_PAGE).map(function (r) {
      return '<tr><td style="color:var(--muted);white-space:nowrap">' + new Date(Number(r.v.at)).toLocaleString() + '</td><td style="font-weight:700">' + esc(r.v.area || "") + "</td><td>" + esc(r.v.title) + "</td></tr>";
    }), ["WHEN", "AREA", "ACTION"], "Nothing has been recorded yet.") + (rows.length > LOG_PAGE ? pagerHtml(rows.length, page, LOG_PAGE, "goLogPage") : "") + "</div>";
}
// Downloads the activity log as CSV.
function exportLog() { exportCSV("activity-log.csv", ["When", "Area", "Action"], newest(list("activity")).map(function (r) { return [new Date(Number(r.v.at)).toLocaleString(), r.v.area || "", r.v.title]; })); }

/* ==========================================================================
   Access (accounts)
   ========================================================================== */
function viewManage() {
  var m = state.manage, q = state.manageSearch.trim().toLowerCase();
  var accs = DB.accounts.filter(function (a) { return !q || (a.name + " " + a.email + " " + (a.unit || "") + " " + a.role).toLowerCase().indexOf(q) >= 0; });
  var units = unitNames();
  return '<div class="card" style="display:flex;flex-direction:column;gap:12px"><h2 style="font-size:19px">Create a resident account</h2>' +
    '<p style="margin:0;font-size:13px;color:var(--muted)">This is the sign-up. There is no public sign-up form; every resident account is added by hand. A temporary password is shown once. The resident must choose their own password, then confirm their account with a code sent to their email (or by text message, when that is set up).</p>' +
    (units.length ? '<div class="manage-row" style="flex-wrap:wrap"><div class="field"><label>Full name</label><input id="mName" value="' + escAttr(m.name) + '" oninput="state.manage.name=this.value" placeholder="e.g. Ana Reyes"></div>' +
      '<div class="field"><label>Email address</label><input id="mEmail" value="' + escAttr(m.email) + '" oninput="state.manage.email=this.value" placeholder="e.g. ana@email.com"></div>' +
      '<div class="field"><label>Mobile number (optional)</label><input id="mPhone" value="' + escAttr(m.phone) + '" oninput="state.manage.phone=this.value" placeholder="e.g. 0917 555 0000"></div>' +
      '<div class="field" style="flex-grow:0;min-width:210px"><label>Unit</label><div class="combo"><input id="mUnit" autocomplete="off" value="' + escAttr(m.unit) + '" oninput="unitSuggest(this)" onfocus="unitSuggest(this)" onblur="unitMenuHide()" onkeydown="unitKey(event)" placeholder="e.g. Unit 12A"><div class="combo-menu" id="mUnitMenu" hidden></div></div></div>' +
      '<button class="btn primary" onclick="createAccount()">+ Create account</button></div>' : '<p class="hint" style="margin:0"><b>Add a unit first.</b> Every resident account belongs to a unit. <a href="#" onclick="set({view:\'units\'});return false">Go to Units</a></p>') +
    (state.manageErr ? '<div style="font-size:13px;color:#A02B1D;font-weight:600">' + esc(state.manageErr) + "</div>" : "") + "</div>" +
    '<div class="card" style="padding:0;overflow:hidden;margin-top:16px"><div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:14px 18px"><h2 style="font-size:19px;margin:0">People with access</h2>' +
    '<input id="manageSearchInput" value="' + escAttr(state.manageSearch) + '" oninput="set({manageSearch:this.value})" placeholder="Search name, email, unit or role..." style="height:38px;border:1px solid #CFC3A9;border-radius:999px;padding:0 14px;font-size:13px;min-width:220px">' +
    '<span style="font-size:13px;color:var(--muted);margin-left:auto">' + accs.length + " of " + DB.accounts.length + ' accounts</span><button class="btn" onclick="exportAccounts()">Export to Excel (.csv)</button></div>' +
    tableRows(accs.map(function (a) {
      var self = a.id === DB.user.id, adm = a.role === "admin";
      var status = a.suspended ? '<span class="chip bad">Suspended</span>' : (!adm && !a.contact_verified_at) ? '<span class="chip warn">Not verified yet</span>' : (!adm && a.must_change_password) ? '<span class="chip warn">Not signed in yet</span>' : '<span class="chip good">Active</span>';
      return "<tr" + (a.suspended ? ' style="opacity:.55"' : "") + '><td style="font-weight:700">' + esc(a.name) + '</td><td style="color:var(--muted)">' + esc(a.email) + '</td><td style="color:var(--muted)">' + esc(a.phone || "—") + '</td><td style="color:var(--muted)">' + esc(a.unit || "—") + '</td><td><span class="chip ' + (adm ? "info" : "good") + '">' + (adm ? "Administrator" : "Resident") + "</span></td><td>" + status + '</td><td style="display:flex;gap:6px;flex-wrap:wrap">' +
        (adm ? (self ? '<span style="color:var(--muted);font-size:12px">You</span>' : "") : '<button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="resetAccount(\'' + escAttr(a.id) + '\')">Reset password</button><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="suspendAccount(\'' + escAttr(a.id) + '\')">' + (a.suspended ? "Reactivate" : "Suspend") + '</button><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="deleteAccount(\'' + escAttr(a.id) + '\')">Revoke</button>') + "</td></tr>";
    }), ["NAME", "EMAIL", "MOBILE", "UNIT", "ROLE", "STATUS", "ACTION"], "No accounts match.") +
    '<div style="padding:10px 18px;font-size:12px;color:var(--muted);border-top:1px solid var(--border2)">Suspend keeps the account on file but blocks sign-in; Revoke permanently removes it and asks for confirmation first.</div></div>';
}
// Finds an account by its id.
function accById(id) { return DB.accounts.filter(function (a) { return a.id === id; })[0]; }
// Shows a temporary password once, right after creating or resetting an account.
function showPassword(name, email, pw) {
  openInfo("Temporary password", '<p>Give this to <b>' + esc(name) + "</b> (" + esc(email) + '). It is shown only now. They must choose their own password when they sign in, then enter a code sent to their email (or by text message, when that is set up).</p><p style="font:700 22px monospace;letter-spacing:.06em;background:var(--beige);padding:12px;border-radius:12px;text-align:center;user-select:all">' + esc(pw) + "</p>");
}
/* Unit box on "Create a resident account": type to search, or pick from the list (styled, not the browser's own list) */
function unitNorm(t) { return String(t || "").toLowerCase().replace(/unit/g, "").replace(/[^a-z0-9]/g, ""); }
// Shows the unit suggestions under the Unit box while typing.
function unitSuggest(inp) {
  state.manage.unit = inp.value;
  var menu = document.getElementById("mUnitMenu"); if (!menu) return;
  var q = unitNorm(inp.value), raw = inp.value.trim().toLowerCase();
  var list = unitNames().filter(function (u) { return !q || unitNorm(u).indexOf(q) >= 0 || u.toLowerCase().indexOf(raw) >= 0; });
  menu.innerHTML = list.length
    ? list.map(function (u, i) { return '<button type="button" class="combo-opt' + (i === 0 && q ? " on" : "") + '" onmousedown="event.preventDefault();unitPick(\'' + escAttr(u) + '\')">' + esc(u) + "</button>"; }).join("")
    : '<div class="combo-none">No unit like that. Add it under Units first.</div>';
  menu.hidden = false;
}
// Puts the clicked suggestion in the Unit box.
function unitPick(u) {
  state.manage.unit = u;
  var i = document.getElementById("mUnit"); if (i) i.value = u;
  unitMenuHide();
}
// Hides the unit suggestions.
function unitMenuHide() { var m = document.getElementById("mUnitMenu"); if (m) m.hidden = true; }
// Keyboard support (arrows, Enter, Esc) in the unit suggestions.
function unitKey(e) {
  var menu = document.getElementById("mUnitMenu"); if (!menu || menu.hidden) return;
  var opts = Array.prototype.slice.call(menu.querySelectorAll(".combo-opt")), cur = opts.findIndex(function (o) { return o.classList.contains("on"); });
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {
    e.preventDefault(); if (!opts.length) return;
    var n = e.key === "ArrowDown" ? (cur + 1) % opts.length : (cur <= 0 ? opts.length - 1 : cur - 1);
    opts.forEach(function (o, k) { o.classList.toggle("on", k === n); });
    opts[n].scrollIntoView({ block: "nearest" });
  } else if (e.key === "Enter" && cur >= 0) { e.preventDefault(); opts[cur].dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true })); }
  else if (e.key === "Escape") unitMenuHide();
}
// Creates a resident account (calls the manage-users Edge Function).
function createAccount() {
  var m = state.manage, units = unitNames();
  /* the unit is typed (or picked from the list); "12a" and "Unit 12A" both match the unit on record */
  var typed = unitNorm(m.unit), unit = typed ? units.filter(function (u) { return unitNorm(u) === typed; })[0] : "";
  if (!m.name.trim() || !m.email.trim()) return set({ manageErr: "Full name and email are required." });
  if (!/^\S+@\S+\.\S+$/.test(m.email.trim())) return set({ manageErr: "Enter a valid email address." });
  if (m.phone.trim() && !/^(\+?63|0)?9\d{9}$/.test(m.phone.replace(/[\s-]/g, ""))) return set({ manageErr: "Enter a valid Philippine mobile number, e.g. 0917 555 0112." });
  if (!typed) return set({ manageErr: "Type or pick the resident's unit." });
  if (!unit) return set({ manageErr: "That unit is not on record yet. Add it under Units first, then create the account." });
  state.manageErr = "";
  act(async function () {
    var r = await callUsers({ action: "create", name: m.name.trim(), email: m.email.trim(), phone: m.phone.trim(), unit: unit });
    await loadAccounts();
    logAct("Account created: " + unit, "Access");
    var nm = m.name.trim();
    state.manage = { name: "", email: "", phone: "", unit: "" };
    showPassword(nm, r.email, r.password);
  });
}
// Gives the resident a new temporary password.
function resetAccount(id) {
  var a = accById(id); if (!a) return;
  confirmBox("Reset password?", "A new temporary password will be made for " + a.name + ".", "Reset", async function () {
    var r = await callUsers({ action: "reset-password", userId: a.id });
    logAct("Password reset: " + a.unit, "Access");
    showPassword(a.name, a.email, r.password);
    return { keepOpen: true };
  });
}
// Suspends or restores an account.
function suspendAccount(id) {
  var a = accById(id); if (!a) return;
  confirmBox((a.suspended ? "Reactivate " : "Suspend ") + a.name + "?", a.suspended ? "They will be able to sign in again." : "They will not be able to sign in.", a.suspended ? "Reactivate" : "Suspend", async function () {
    await callUsers({ action: "set-suspended", userId: a.id, suspended: !a.suspended });
    await loadAccounts(); logAct((a.suspended ? "Account reactivated: " : "Account suspended: ") + a.unit, "Access");
  });
}
// Deletes an account.
function deleteAccount(id) {
  var a = accById(id); if (!a) return;
  confirmBox("Permanently revoke access for " + a.name + "?", "This removes their account and cannot be undone.", "Revoke", async function () {
    await callUsers({ action: "delete", userId: a.id });
    await loadAccounts(); logAct("Account deleted: " + a.unit, "Access");
  }, true);
}
// Downloads accounts as CSV.
function exportAccounts() {
  exportCSV("residenthub-accounts.csv", ["Name", "Email", "Mobile", "Unit", "Role", "Status"], DB.accounts.map(function (a) { return [a.name, a.email, a.phone || "", a.unit || "", a.role, a.suspended ? "Suspended" : "Active"]; }));
}

/* ==========================================================================
   Settings and profile
   ========================================================================== */
function directory() { var d = setting("directory"); return { contacts: d.contacts || [], rules: d.rules || [] }; }
// PAGE: Settings (contacts, rules, payment methods, password).
function viewSettings() {
  var d = directory();
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px">' +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2>Billing</h2><p class="hint" style="margin:0">Monthly dues: <b>' + (setting("dues_rate_sqm").rate ? peso(setting("dues_rate_sqm").rate) + " per sqm" : "not set") + "</b> · Motor parking: <b>" + (setting("motor_rate").rate ? peso(setting("motor_rate").rate) : "not set") + '</b></p><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn primary" onclick="set({view:\'fin\'})">Open Finance</button><button class="btn" onclick="payMethodsForm()">Payment options</button></div></div>' +
    '<div class="card" style="display:flex;flex-direction:column;gap:10px"><h2>Your preferences</h2><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" onclick="toggleDarkMode()">' + (state.darkMode ? "Switch to light mode" : "Switch to dark mode") + '</button><button class="btn" onclick="changePasswordForm()">Change password</button><button class="btn" onclick="signOut(true)">Log out on all devices</button></div></div></div>' +
    '<div style="display:flex;flex-direction:column;gap:16px"><div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><h2>Directory — who to call</h2><button class="btn primary" onclick="contactForm()">+ Add</button></div><p class="hint">Residents see this under Directory.</p>' +
    (d.contacts.map(function (c, i) { return '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 0;border-top:1px solid var(--border2)"><div><b style="font-size:14px">' + esc(c.name) + '</b><div style="font-size:12px;color:var(--muted)">' + esc(c.note || "") + " · " + esc(c.tel || "") + '</div></div><button class="btn" style="min-height:30px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="removeDirItem(\'contacts\',' + i + ')">Remove</button></div>'; }).join("") || '<p class="empty">No contacts yet.</p>') + "</div>" +
    '<div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><h2>House rules</h2><button class="btn primary" onclick="ruleForm()">+ Add</button></div>' +
    (d.rules.map(function (r, i) { return '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 0;border-top:1px solid var(--border2)"><div><b style="font-size:14px">' + esc(r[0]) + '</b><div style="font-size:12px;color:var(--muted)">' + esc(r[1]) + '</div></div><button class="btn" style="min-height:30px;padding:0 10px;font-size:12px;color:#A02B1D" onclick="removeDirItem(\'rules\',' + i + ')">Remove</button></div>'; }).join("") || '<p class="empty">No rules yet.</p>') + "</div></div></div>";
}
// Saves the contacts and house rules.
function saveDirectory(d) { return put("setting", "directory", "", { contacts: d.contacts, rules: d.rules }); }
// Popup form to add an emergency contact.
function contactForm() {
  openForm({ title: "Add contact", fields: [{ name: "name", label: "Name", placeholder: "e.g. Security desk" }, { name: "note", label: "Note", placeholder: "e.g. Open 24 hours" }, { name: "tel", label: "Number", placeholder: "e.g. Local 101" }],
    onSubmit: async function (f) { if (!f.name || !f.tel) return { error: "Enter a name and a number." }; var d = directory(); d.contacts.push({ name: f.name, note: f.note, tel: f.tel }); await saveDirectory(d); logAct("Directory updated", "Settings"); } });
}
// Popup form to add a house rule.
function ruleForm() {
  openForm({ title: "Add house rule", fields: [{ name: "t", label: "Title", placeholder: "e.g. Quiet hours" }, { name: "x", label: "Rule", type: "textarea" }],
    onSubmit: async function (f) { if (!f.t || !f.x) return { error: "Enter a title and the rule." }; var d = directory(); d.rules.push([f.t, f.x]); await saveDirectory(d); logAct("House rules updated", "Settings"); } });
}
// Removes a contact or a rule.
function removeDirItem(kind, i) {
  act(async function () { var d = directory(); d[kind].splice(i, 1); await saveDirectory(d); logAct("Directory updated", "Settings"); });
}
// Popup form to change your own password.
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
      toast("Password changed.");
    }
  });
}
// PAGE: My profile.
function viewProfile() {
  var p = DB.profile, mine = newest(list("activity")).slice(0, 5);
  return '<div class="profile-grid"><div class="profile-col"><div class="card"><div style="display:flex;align-items:center;gap:16px;flex-wrap:wrap"><span class="avatar big">' + esc(initials(adminName())) + "</span><div><h2>" + esc(adminName()) + '</h2><p style="margin:2px 0 8px;color:var(--muted)">Administrator · City Residences Condominium Corporation</p><span class="chip good">Verified admin</span></div></div></div>' +
    '<div class="card"><h2>Personal information</h2><div class="kv" style="margin-top:10px"><span>Full name</span><b>' + esc(p.name || "—") + "</b><span>Role</span><b>Administrator</b><span>Email</span><b>" + esc(p.email) + "</b><span>Phone</span><b>" + esc(p.phone || "Not added yet") + '</b></div><div style="margin-top:12px"><button class="btn" onclick="changePasswordForm()">Change password</button></div></div>' +
    '<div class="card"><div class="card-head" style="display:flex;justify-content:space-between;align-items:center"><h2>Recent activity</h2><button class="btn" onclick="set({view:\'log\'})">Full log</button></div><div class="tl-list">' +
    (mine.map(function (a) { return '<div class="tl-row"><span class="tl-dot"></span><div><b>' + esc(a.v.title) + "</b><small>" + new Date(Number(a.v.at)).toLocaleString() + "</small></div></div>"; }).join("") || '<p class="empty">Nothing yet.</p>') + "</div></div></div>" +
    '<aside class="profile-col"><div class="card" style="display:flex;flex-direction:column;gap:8px"><h2>Quick links</h2><button class="btn" onclick="set({view:\'ann\'})">Announcements</button><button class="btn" onclick="set({view:\'req\'})">Complaints &amp; files</button><button class="btn" onclick="set({view:\'fin\'})">Finance</button><button class="btn" onclick="set({view:\'settings\'})">Settings</button></div></aside></div>';
}

/* ==========================================================================
   Search and notifications
   ========================================================================== */
function searchIndex() {
  var pages = [["Finance", "fin"], ["Reports", "reports"], ["Parking", "parking"], ["Polls", "polls"], ["Facility booking", "fac"], ["Announcements", "ann"], ["Complaints", "req"], ["Unit status", "rentals"], ["Expenses", "expenses"], ["Activity log", "log"], ["Manage access", "manage"], ["Settings", "settings"], ["My profile", "profile"]];
  return [].concat(
    sortedUnits().map(function (r) { return { t: esc(r.id + " · " + (r.v.name || "—")), s: esc((r.v.type || "") + " · " + (r.v.contact || "")), tag: "Unit", v: "units" }; }),
    list("announcement").map(function (r) { return { t: esc(r.v.title), s: esc(r.v.body || ""), tag: "Announcement", v: "ann" }; }),
    list("event").map(function (r) { return { t: esc(r.v.title), s: esc((r.v.date || "") + " · " + (r.v.place || "")), tag: "Event", v: "ann" }; }),
    pollsAll().map(function (p) { return { t: esc(p.q), s: p.open ? "Open poll" : "Closed poll", tag: "Poll", v: "polls" }; }),
    list("grievance").map(function (r) { return { t: esc(r.v.title), s: esc("Reported by " + (r.v.by || r.unit)), tag: "Complaint", v: "req" }; }),
    list("doc").map(function (r) { return { t: esc(r.v.name), s: esc((r.v.cat || "") + " · " + (r.v.date || "")), tag: "Document", v: "req" }; }),
    DB.accounts.map(function (a) { return { t: esc(a.name), s: esc(a.role + " · " + a.email), tag: "Account", v: "manage" }; }),
    pages.map(function (p) { return { t: p[0], s: "Open this page", tag: "Page", v: p[1] }; }));
}
// The items in the notification bell (what needs the admin's attention).
function bellItems() {
  var c = counts(), l = [];
  if (c.bookings) l.push({ t: c.bookings + " booking request" + (c.bookings > 1 ? "s" : "") + " to review", s: "Facility", v: "fac" });
  if (c.proofs) l.push({ t: c.proofs + " payment" + (c.proofs > 1 ? "s" : "") + " to verify", s: "Finance", v: "fin" });
  if (c.unpaid) l.push({ t: c.unpaid + " unpaid charge" + (c.unpaid > 1 ? "s" : ""), s: "Finance", v: "fin" });
  if (c.grievances) l.push({ t: c.grievances + " open complaint" + (c.grievances > 1 ? "s" : ""), s: "Complaints", v: "req" });
  if (c.rentals) l.push({ t: c.rentals + " unit status to review", s: "Unit status", v: "rentals" });
  if (c.parking) l.push({ t: c.parking + " parking request" + (c.parking > 1 ? "s" : ""), s: "Parking", v: "parking" });
  return l;
}

/* ---------- button press ripple (as before) ---------- */
(function () {
  document.addEventListener("pointerdown", function (e) { var b = e.target.closest(".btn"); if (b) b.classList.add("is-pressed"); });
  ["pointerup", "pointerleave"].forEach(function (ev) { document.addEventListener(ev, function (e) { var b = e.target.closest && e.target.closest(".btn"); if (b) b.classList.remove("is-pressed"); }); });
})();

rhInit();
