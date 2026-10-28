/* DEMO ONLY: maintenance management for ResidentHub.
   Adds (1) a preventive maintenance schedule, (2) an equipment list, (3) a maintenance staff list and
   (4) repair assignment on complaints (who, target date, equipment, note).
   Loaded by demo/admin.html and demo/resident.html after the real scripts. The real website and the real
   database do not load this file, so nothing here touches production.
   Data kinds (all stored in the demo's in-memory records table):
     staff     unit "__admin"  {id, name, role, phone}
     equipment unit "__admin"  {id, name, category, location, status, lastService}
     mtask     unit ""         {id, title, equipId, equipName, every, days, due, staffId, assignee, lastDone, history[]}
     mclosure  unit ""         {id: facility name, facility, equipName, reason}  (a facility closed for maintenance)
     mtype     unit "__admin"  {id, name}  (a task type the administrator created; a task's kind holds the type name)
     grievance (existing)      + staffId, assignee, target, equipId, equipName, notes, priority, resolvedOn, cost, completion
     expense   (existing)      + equipId, grievanceId, taskId (repair and maintenance spending) */
(function () {
  if (!window.RH_DEMO) return;
  var IS_ADMIN = window.RH_ROLE === "admin";

  var FREQ = [["Weekly", 7], ["Every 2 weeks", 14], ["Monthly", 30], ["Every 3 months", 90], ["Every 6 months", 180], ["Yearly", 365]];
  var EQ_STATUS = ["Working", "Needs repair", "Under maintenance"];
  var EQ_CATS = ["Elevator", "Plumbing", "Electrical", "Fire safety", "Pool", "Gym", "Air conditioning", "Security", "Other"];
  // Task types: two built in, plus any the administrator creates (stored as "mtype" records; a task's "kind" holds the name).
  var TYPES = [["Routine", "Routine maintenance", "Routine"], ["Compliance", "Permit, certificate or test", "Permits and tests"]];
  function customTypes() { return list("mtype").sort(function (a, b) { return String(a.v.name).localeCompare(String(b.v.name)); }); }
  function typeOptions() { return TYPES.map(function (t) { return [t[0], t[1]]; }).concat(customTypes().map(function (r) { return [r.v.name, r.v.name]; })); }
  function typeLabel(k) { k = k || "Routine"; for (var i = 0; i < TYPES.length; i++) if (TYPES[i][0] === k) return TYPES[i][1]; return k; }
  window.maintTypeLabel = typeLabel; // the Excel export uses it
  function cleanTypeName(n) { return String(n || "").replace(/['"\\<>&]/g, "").replace(/\s+/g, " ").trim().slice(0, 40); }
  var BTN = 'class="btn" style="min-height:32px;padding:0 10px;font-size:12px';

  NAV_ICONS.maint = '<rect x="5" y="4" width="14" height="17" rx="2.5"/><path d="M9 4h6v3H9zM9 14l2 2 4-4"/>';

  /* ---------- small helpers ---------- */
  function today() { var d = new Date(); d.setHours(12, 0, 0, 0); return d; }
  function kd(k) { var m = /^(\d{4})-(\d\d)-(\d\d)/.exec(k || ""); return m ? new Date(+m[1], +m[2] - 1, +m[3], 12) : null; }
  function daysTo(k) { var d = kd(k); return d ? Math.round((d - today()) / 86400000) : null; }
  function fd(k) { var d = kd(k); return d ? shortDate(d) : "—"; }
  function addDays(k, n) { var d = kd(k) || today(); d.setDate(d.getDate() + n); return dayKey(d); }
  function plural(n, w) { return n + " " + w + (n === 1 ? "" : "s"); }
  // [label, chip class] for the due date of a task.
  function taskState(t) {
    var n = daysTo(t.due);
    if (n == null) return ["No date", "info"];
    if (n < 0) return ["Overdue by " + plural(-n, "day"), "bad"];
    if (n === 0) return ["Due today", "warn"];
    if (n <= 7) return ["Due in " + plural(n, "day"), "warn"];
    return ["Scheduled", "good"];
  }
  function eqChip(s) { return '<span class="chip ' + (s === "Working" ? "good" : s === "Under maintenance" ? "warn" : "bad") + '">' + esc(s) + "</span>"; }
  function tasks() { return list("mtask").sort(function (a, b) { return String(a.v.due || "").localeCompare(String(b.v.due || "")); }); }
  function byName(a, b) { return String(a.v.name || "").localeCompare(String(b.v.name || "")); }
  function staffList() { return list("staff").sort(byName); }
  function equipList() { return list("equipment").sort(byName); }
  function staffOptions(none) { return [["", none || "— Unassigned —"]].concat(staffList().map(function (s) { return [s.id, s.v.name + " · " + s.v.role]; })); }
  function equipOptions() { return [["", "— None —"]].concat(equipList().map(function (e) { return [e.id, e.v.name + " · " + e.v.location]; })); }
  function staffNameOf(id) { var s = getRow("staff", id); return s ? s.value.name : ""; }
  function equipNameOf(id) { var e = getRow("equipment", id); return e ? e.value.name : ""; }
  var PRIORITIES = ["Urgent", "High", "Normal", "Low"];
  function prioChip(p) { return p ? '<span class="chip ' + (p === "Urgent" ? "bad" : p === "High" ? "warn" : "info") + '">' + esc(p) + "</span>" : ""; }
  function money(n) { return peso(Number(n) || 0); }
  function amenityNames() { return amenities().map(function (a) { return a.name; }); }
  function closureOf(name) { var r = getRow("mclosure", name); return r ? r.value : null; }
  // Facilities that residents cannot book are kept in a public "mclosure" record, so the resident site can read it.
  async function syncClosures() {
    var want = {};
    list("equipment").forEach(function (e) {
      if (e.v.facility && e.v.closes && e.v.status !== "Working") want[e.v.facility] = { id: e.v.facility, facility: e.v.facility, equipName: e.v.name, reason: e.v.status };
    });
    var have = list("mclosure");
    for (var i = 0; i < have.length; i++) if (!want[have[i].id]) await del("mclosure", have[i].id);
    for (var k in want) {
      var cur = getRow("mclosure", k);
      if (!cur || JSON.stringify(cur.value) !== JSON.stringify(want[k])) await put("mclosure", k, "", want[k]);
    }
  }
  function warrantyChip(k) {
    if (!k) return "—";
    var n = daysTo(k);
    return n < 0 ? '<span class="chip bad">Expired</span>' : n <= 30 ? '<span class="chip warn">Ends in ' + plural(n, "day") + "</span>" : esc(fd(k));
  }
  function isMaintExpense(e) { return !!(e.equipId || e.grievanceId || e.taskId); }
  function spentOn(equipId) { return vals("expense").filter(function (e) { return e.equipId === equipId; }).reduce(function (s, e) { return s + expTotal(e); }, 0); }
  function areaFor(equipId) {
    var e = getRow("equipment", equipId), c = e ? e.value.category : "";
    return c === "Elevator" ? "Elevators" : c === "Pool" ? "Swimming Pool" : c === "Security" ? "Offices and security" : "Lobby and common areas";
  }
  function costFields() {
    return [{ name: "cost", label: "Cost of the repair or service (₱, optional)", type: "number", step: "0.01" }, { name: "completion", label: "What was done", type: "textarea", placeholder: "Short note for the record" }];
  }
  // Records the cost of a job as an expense, linked to the equipment and the job.
  async function recordCost(d, item, ids) {
    var cost = parseFloat(d.cost);
    if (!(cost > 0)) return;
    var eid = nextId();
    await put("expense", eid, "__admin", Object.assign({ id: Number(eid), item: item, category: ids.category, area: ids.equipId ? areaFor(ids.equipId) : "Lobby and common areas", payee: ids.who || "", receiptNo: "", qty: 1, unitPrice: cost, date: dayKey(new Date()) }, ids.link));
  }
  function repairStats() {
    var done = list("grievance").filter(function (r) { return Number(r.v.stage) >= 2 && r.v.resolvedOn && r.v.assignee; });
    var days = done.map(function (r) { return Math.max(0, (kd(r.v.resolvedOn) - new Date(Number(r.id)).setHours(12, 0, 0, 0)) / 86400000); });
    var avg = days.length ? days.reduce(function (a, b) { return a + b; }, 0) / days.length : null;
    var now = new Date(), mk = now.getFullYear() + "-" + pad(now.getMonth() + 1);
    var all = vals("expense").filter(isMaintExpense);
    return {
      n: done.length, avg: avg,
      month: all.filter(function (e) { return String(e.date || "").slice(0, 7) === mk; }).reduce(function (s, e) { return s + expTotal(e); }, 0),
      year: all.filter(function (e) { return String(e.date || "").slice(0, 4) === String(now.getFullYear()); }).reduce(function (s, e) { return s + expTotal(e); }, 0)
    };
  }
  function dueCount() { return tasks().filter(function (r) { var n = daysTo(r.v.due); return n != null && n <= 7; }).length; }
  function openRepairs(equipId) { return list("grievance").filter(function (r) { return r.v.equipId === equipId && !(Number(r.v.stage) >= 2); }).length; }

  /* ==========================================================================
     ADMIN
     ========================================================================== */
  function viewMaint() {
    var tab = state.mtab || "sched", kind = state.mkind || "all";
    var ts = tasks(), overdue = ts.filter(function (r) { return daysTo(r.v.due) < 0; }).length;
    var soon = ts.filter(function (r) { var n = daysTo(r.v.due); return n >= 0 && n <= 7; }).length;
    var eq = equipList(), bad = eq.filter(function (e) { return e.v.status !== "Working"; }).length, rs = repairStats();
    var tabs = [["sched", "Schedule (" + ts.length + ")"], ["equip", "Equipment (" + eq.length + ")"], ["staff", "Staff (" + staffList().length + ")"]];
    var closed = list("mclosure");
    if (state.mpage) return maintPage(state.mpage, ts, eq, rs);
    return '<div class="grid cols-4" style="margin-bottom:10px">' + mStat("Overdue tasks", overdue, "overdue") + mStat("Due in the next 7 days", soon, "soon") + mStat("Equipment needing attention", bad, "attn") + mStat("Repair spend this month", money(rs.month), "spend") + "</div>" +
      '<p class="hint" style="margin:0 0 14px">' + (rs.avg == null ? "No finished repairs yet." : "Average repair time " + (rs.avg < 1 ? "under a day" : rs.avg.toFixed(1) + " days") + " across " + plural(rs.n, "finished repair") + ".") + " Maintenance spending this year: <b>" + money(rs.year) + "</b>." + (closed.length ? " Closed to bookings now: <b>" + closed.map(function (c) { return esc(c.v.facility); }).join(", ") + "</b>." : "") + "</p>" +
      '<div class="filters" style="margin-bottom:14px">' + tabs.map(function (t) {
        return '<button class="' + (tab === t[0] ? "active" : "") + '" onclick="set({mtab:\'' + t[0] + '\'})">' + t[1] + "</button>";
      }).join("") + "</div>" + (tab === "equip" ? maintEquip(eq) : tab === "staff" ? maintStaff() : maintSched(ts, kind) + recentNotices());
  }

  function maintTaskRows(shown) {
    return shown.map(function (r) {
      var t = r.v, st = taskState(t);
      return "<tr><td><b>" + esc(t.title) + "</b>" + ((t.kind || "Routine") !== "Routine" ? ' <span class="chip info">' + esc(t.kind === "Compliance" ? "Compliance" : t.kind) + "</span>" : "") + '<div style="font-size:12px;color:var(--muted)">Last done ' + esc(fd(t.lastDone)) + "</div></td><td>" + esc(t.equipName || "—") + "</td><td>" + esc(t.every) + "</td><td>" + esc(fd(t.due)) +
        '<div><span class="chip ' + st[1] + '">' + st[0] + "</span></div></td><td>" + esc(t.assignee || "Unassigned") + "</td><td style=\"white-space:nowrap\">" +
        '<button class="btn primary" style="min-height:32px;padding:0 10px;font-size:12px" onclick="maintDone(\'' + escAttr(r.id) + '\')">Mark done</button> ' +
        "<button " + BTN + '" title="Post a notice to all residents" onclick="maintNotify(\'' + escAttr(r.id) + '\')">Notify residents</button> ' +
        "<button " + BTN + '" onclick="maintTaskForm(\'' + escAttr(r.id) + '\')">Edit</button> <button ' + BTN + ';color:#A02B1D" onclick="maintDelete(\'mtask\',\'' + escAttr(r.id) + '\')">Delete</button></td></tr>';
    });
  }

  function maintEquipRows(eq) {
    return eq.map(function (r) {
      var e = r.v, n = openRepairs(r.id), sp = spentOn(r.id);
      return "<tr><td><b>" + esc(e.name) + '</b><div style="font-size:12px;color:var(--muted)">' + esc(e.category) + (e.vendor ? " · " + esc(e.vendor) : "") + "</div></td><td>" + esc(e.location) + "</td><td>" + eqChip(e.status) +
        (e.facility && e.closes ? '<div style="font-size:12px;color:var(--muted);margin-top:3px">Closes ' + esc(e.facility) + " while not working</div>" : "") + (n ? '<div><span class="chip warn">' + plural(n, "open repair") + "</span></div>" : "") +
        "</td><td>" + warrantyChip(e.warranty) + "</td><td>" + (sp ? money(sp) : "—") + "</td><td>" + esc(fd(e.lastService)) +
        '</td><td style="white-space:nowrap"><button ' + BTN + '" onclick="maintEquipForm(\'' + escAttr(r.id) + '\')">Edit</button> <button ' + BTN + ';color:#A02B1D" onclick="maintDelete(\'equipment\',\'' + escAttr(r.id) + '\')">Delete</button></td></tr>';
    });
  }

  function mStat(label, value, key) {
    var go = "set({mpage:'" + key + "'})";
    return '<div class="card stat-link" role="button" tabindex="0" onclick="' + go + '" onkeydown="if(event.key===\'Enter\'||event.key===\' \'){event.preventDefault();' + go + '}"><div class="stat-label">' + esc(label) + '</div><div class="stat-value">' + esc(value) + '</div><div class="stat-more">View details \u2192</div></div>';
  }
  function maintBack(title, sub) {
    return '<div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-bottom:16px"><button class="btn" onclick="set({mpage:\'\'})">\u2190 Back to Maintenance</button><div><h2 style="margin:0;font-size:22px">' + esc(title) + '</h2>' + (sub ? '<p class="hint" style="margin:3px 0 0">' + sub + '</p>' : '') + '</div></div>';
  }
  var MT_HEAD = ["TASK", "EQUIPMENT", "REPEATS", "NEXT DUE", "ASSIGNED TO", ""];
  // The page a Maintenance card opens: the tasks, equipment or spending behind the number.
  function maintPage(key, ts, eq, rs) {
    var box = function (inner) { return '<div class="card" style="padding:0;overflow:hidden">' + inner + "</div>"; };
    if (key === "overdue") {
      var o = ts.filter(function (r) { return daysTo(r.v.due) < 0; });
      return maintBack("Overdue tasks", "Tasks whose due date has passed. Mark them done, or move the date by editing the task.") + box(tableRows(maintTaskRows(o), MT_HEAD, "Nothing is overdue."));
    }
    if (key === "soon") {
      var n7 = ts.filter(function (r) { var n = daysTo(r.v.due); return n != null && n >= 0 && n <= 7; });
      return maintBack("Due in the next 7 days", "Tasks coming up this week. Use Notify residents when a job will affect them.") + box(tableRows(maintTaskRows(n7), MT_HEAD, "Nothing is due in the next 7 days."));
    }
    if (key === "attn") {
      var bad = eq.filter(function (e) { return e.v.status !== "Working"; });
      return maintBack("Equipment needing attention", "Equipment that is under maintenance or not working.") + box(tableRows(maintEquipRows(bad), ["EQUIPMENT", "LOCATION", "CONDITION", "WARRANTY", "SPENT", "LAST SERVICE", ""], "Everything is working."));
    }
    if (key === "spend") {
      var now = new Date(), mk = now.getFullYear() + "-" + pad(now.getMonth() + 1);
      var ex = vals("expense").filter(isMaintExpense).filter(function (e) { return String(e.date || "").slice(0, 7) === mk; }).sort(function (a, b) { return String(b.date || "").localeCompare(String(a.date || "")); });
      var total = ex.reduce(function (s, e) { return s + expTotal(e); }, 0);
      var rows = ex.map(function (e) {
        return "<tr><td>" + esc(fd(e.date)) + "</td><td><b>" + esc(e.item || "Repair") + '</b><div style="font-size:12px;color:var(--muted)">' + esc(e.category || "") + "</div></td><td>" + esc(e.equipId ? equipNameOf(e.equipId) || e.area || "" : e.area || "") + "</td><td>" + esc(e.payee || "—") + "</td><td><b>" + money(expTotal(e)) + "</b></td></tr>";
      });
      return maintBack("Repair spend this month", "Everything paid for repairs and maintenance in " + now.toLocaleDateString("en-US", { month: "long", year: "numeric" }) + ": <b>" + money(total) + "</b>. This year: <b>" + money(rs.year) + "</b>.") +
        box(tableRows(rows, ["DATE", "WHAT", "EQUIPMENT OR AREA", "PAID TO", "AMOUNT"], "No repair or maintenance spending recorded this month.")) +
        '<div style="margin-top:12px"><button class="btn" onclick="set({mpage:\'\',view:\'expenses\'})">Open Expenses</button></div>';
    }
    return "";
  }

  function maintSched(ts, kind) {
    var shown = ts.filter(function (r) { return kind === "all" || (r.v.kind || "Routine") === kind; });
    var rows = maintTaskRows(shown);
    var kinds = [["all", "All"]].concat(TYPES.map(function (t) { return [t[0], t[2]]; }), customTypes().map(function (r) { return [r.v.name, r.v.name]; }));
    var isCustom = customTypes().some(function (r) { return r.v.name === kind; });
    return '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:12px"><button class="btn primary" onclick="maintTaskForm(null)">+ Add task</button><span class="filters">' + kinds.map(function (k) {
      return '<button class="' + (kind === k[0] ? "active" : "") + '" onclick="set({mkind:\'' + k[0] + '\'})">' + k[1] + "</button>";
    }).join("") + "</span>" + (isCustom ? '<button ' + BTN + '" title="Change the name of this type" onclick="maintRenameType(\'' + escAttr(kind) + '\')">Rename type</button><button ' + BTN + ';color:#A02B1D" title="Remove this type from the list" onclick="maintDeleteType(\'' + escAttr(kind) + '\')">Delete type “' + esc(kind) + '”</button>' : "") + "</div>" +
      '<div class="card" style="padding:0;overflow:hidden">' + tableRows(rows, ["TASK", "EQUIPMENT", "REPEATS", "NEXT DUE", "ASSIGNED TO", ""], "No maintenance tasks yet. Add the first one.") + "</div>";
  }

  function maintEquip(eq) {
    var rows = maintEquipRows(eq);
    return '<div style="margin-bottom:12px"><button class="btn primary" onclick="maintEquipForm(null)">+ Add equipment</button></div>' +
      '<div class="card" style="padding:0;overflow:hidden">' + tableRows(rows, ["EQUIPMENT", "LOCATION", "CONDITION", "WARRANTY", "SPENT", "LAST SERVICE", ""], "No equipment listed yet.") + "</div>";
  }

  function maintStaff() {
    var rows = staffList().map(function (r) {
      var s = r.v;
      var rep = list("grievance").filter(function (g) { return g.v.staffId === r.id && !(Number(g.v.stage) >= 2); }).length;
      var tk = tasks().filter(function (t) { return t.v.staffId === r.id; }).length;
      return "<tr><td><b>" + esc(s.name) + "</b></td><td>" + esc(s.role) + "</td><td>" + esc(s.phone || "—") + "</td><td>" + plural(rep, "open repair") + ", " + plural(tk, "task") +
        '</td><td style="white-space:nowrap"><button ' + BTN + '" onclick="maintStaffForm(\'' + escAttr(r.id) + '\')">Edit</button> <button ' + BTN + ';color:#A02B1D" onclick="maintDelete(\'staff\',\'' + escAttr(r.id) + '\')">Delete</button></td></tr>';
    });
    return '<div style="margin-bottom:12px"><button class="btn primary" onclick="maintStaffForm(null)">+ Add staff</button></div>' +
      '<div class="card" style="padding:0;overflow:hidden">' + tableRows(rows, ["NAME", "ROLE", "PHONE", "ASSIGNED WORK", ""], "No maintenance staff yet.") + "</div>";
  }

  /* ----- forms ----- */
  window.maintTaskForm = function (id) {
    var t = id ? (getRow("mtask", id) || {}).value || {} : {};
    openForm({
      title: id ? "Edit maintenance task" : "Add maintenance task",
      fields: [
        { name: "title", label: "Task", value: t.title, placeholder: "e.g. Elevator inspection" },
        { name: "kind", label: "Type", type: "select", options: typeOptions().concat([["__new__", "+ Add new type…"]]), value: t.kind || "Routine" },
        { name: "newKind", label: "Name of the new type", value: "", placeholder: "e.g. Inspection" },
        { name: "equipId", label: "Equipment (optional)", type: "select", options: equipOptions(), value: t.equipId || "" },
        { name: "every", label: "Repeats", type: "select", options: FREQ.map(function (f) { return f[0]; }), value: t.every || "Monthly" },
        { name: "due", label: "Next due date", type: "date", value: t.due || dayKey(new Date()) },
        { name: "staffId", label: "Assigned to", type: "select", options: staffOptions(), value: t.staffId || "" }
      ],
      onSubmit: async function (d) {
        if (!d.title) return { error: "Enter the task." };
        if (!d.due) return { error: "Choose the next due date." };
        var kindName = d.kind || "Routine", nk = cleanTypeName(d.newKind);
        if (kindName === "__new__") { if (!nk) return { error: "Type the name of the new type, or pick a type from the list." }; kindName = "Routine"; }
        else nk = "";
        if (nk) {
          var known = typeOptions().filter(function (o) { return o[0].toLowerCase() === nk.toLowerCase() || o[1].toLowerCase() === nk.toLowerCase(); })[0];
          if (known) kindName = known[0];
          else { await put("mtype", String(nextId()), "__admin", { name: nk }); kindName = nk; logAct("Maintenance type added: " + nk, "Maintenance"); }
        }
        var f = FREQ.filter(function (x) { return x[0] === d.every; })[0] || FREQ[2], nid = id || String(nextId());
        var v = Object.assign({}, t, { id: nid, kind: kindName, title: d.title, equipId: d.equipId, equipName: d.equipId ? equipNameOf(d.equipId) : (t.equipId ? "" : (t.equipName || "")), every: f[0], days: f[1], due: d.due, staffId: d.staffId, assignee: d.staffId ? staffNameOf(d.staffId) : "" });
        await put("mtask", nid, "", v);
        logAct((id ? "Maintenance task updated: " : "Maintenance task added: ") + d.title, "Maintenance");
      }
    });
    wireTypePicker();
  };

  // The Type dropdown ends with "+ Add new type…". Choosing it shows a name box with an Add button; the new type is
  // saved at once, appears in the dropdown and is selected.
  function wireTypePicker() {
    var form = document.getElementById("rhForm"); if (!form) return;
    var sel = form.querySelector('select[name="kind"]'), inp = form.querySelector('input[name="newKind"]'); if (!sel || !inp) return;
    var lab = inp.parentNode; lab.style.display = "none";
    var row = document.createElement("div"); row.style.cssText = "display:flex;gap:8px;align-items:center";
    lab.insertBefore(row, inp); row.appendChild(inp); inp.style.flex = "1";
    var add = document.createElement("button"); add.type = "button"; add.className = "btn primary"; add.textContent = "Add type"; add.style.whiteSpace = "nowrap";
    row.appendChild(add);
    sel.addEventListener("change", function () { var isNew = sel.value === "__new__"; lab.style.display = isNew ? "" : "none"; if (isNew) inp.focus(); });
    async function addType() {
      var nk = cleanTypeName(inp.value); if (!nk) { inp.focus(); return; }
      var known = typeOptions().filter(function (o) { return o[0].toLowerCase() === nk.toLowerCase() || o[1].toLowerCase() === nk.toLowerCase(); })[0], name;
      if (known) name = known[0];
      else {
        await put("mtype", String(nextId()), "__admin", { name: nk }); name = nk; logAct("Maintenance type added: " + nk, "Maintenance");
        var o = document.createElement("option"); o.value = nk; o.textContent = nk; sel.insertBefore(o, sel.querySelector('option[value="__new__"]'));
      }
      sel.value = name; inp.value = ""; lab.style.display = "none"; toast(known ? "That type already exists. Selected." : "Type “" + name + "” added.");
    }
    add.addEventListener("click", addType);
    inp.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); addType(); } });
  }

  window.maintEquipForm = function (id) {
    var e = id ? (getRow("equipment", id) || {}).value || {} : {};
    openForm({
      title: id ? "Edit equipment" : "Add equipment",
      fields: [
        { name: "name", label: "Name", value: e.name, placeholder: "e.g. Elevator A" },
        { name: "category", label: "Category", type: "select", options: EQ_CATS, value: e.category || EQ_CATS[0] },
        { name: "location", label: "Location", value: e.location, placeholder: "e.g. Basement pump room" },
        { name: "status", label: "Condition", type: "select", options: EQ_STATUS, value: e.status || "Working" },
        { name: "facility", label: "Part of a bookable facility? (optional)", type: "select", options: [["", "— No —"]].concat(amenityNames().map(function (n) { return [n, n]; })), value: e.facility || "" },
        { name: "closes", label: "If it is not working", type: "select", options: [["no", "Keep the facility open for booking"], ["yes", "Close the facility to booking"]], value: e.closes ? "yes" : "no" },
        { name: "vendor", label: "Supplier or service company", value: e.vendor },
        { name: "warranty", label: "Warranty ends (optional)", type: "date", value: e.warranty || "" },
        { name: "lastService", label: "Last serviced", type: "date", value: e.lastService || "" }
      ],
      onSubmit: async function (d) {
        if (!d.name) return { error: "Enter the equipment name." };
        var nid = id || String(nextId());
        await put("equipment", nid, "__admin", Object.assign({}, e, { id: nid, name: d.name, category: d.category, location: d.location, status: d.status, facility: d.facility, closes: d.closes === "yes", vendor: d.vendor, warranty: d.warranty, lastService: d.lastService }));
        await syncClosures();
        logAct((id ? "Equipment updated: " : "Equipment added: ") + d.name, "Maintenance");
      }
    });
  };

  window.maintStaffForm = function (id) {
    var s = id ? (getRow("staff", id) || {}).value || {} : {};
    openForm({
      title: id ? "Edit staff member" : "Add staff member",
      fields: [
        { name: "name", label: "Name", value: s.name },
        { name: "role", label: "Role", value: s.role, placeholder: "e.g. Plumber" },
        { name: "phone", label: "Phone", value: s.phone }
      ],
      onSubmit: async function (d) {
        if (!d.name) return { error: "Enter the name." };
        var nid = id || String(nextId());
        await put("staff", nid, "__admin", { id: nid, name: d.name, role: d.role || "Maintenance", phone: d.phone });
        logAct((id ? "Staff updated: " : "Staff added: ") + d.name, "Maintenance");
      }
    });
  };

  window.maintDone = function (id) {
    var row = getRow("mtask", id); if (!row) return;
    var t = row.value;
    openForm({
      title: "Mark done",
      intro: esc(t.title),
      submit: "Mark done",
      fields: costFields(),
      onSubmit: async function (d) {
        var now = dayKey(new Date()), hist = [{ date: now, by: t.assignee || "Office", note: d.completion || "", cost: parseFloat(d.cost) || 0 }].concat(t.history || []).slice(0, 12);
        var next = addDays(now, Number(t.days) || 30);
        await put("mtask", id, "", Object.assign({}, t, { lastDone: now, due: next, history: hist }));
        if (t.equipId && getRow("equipment", t.equipId)) await put("equipment", t.equipId, "__admin", Object.assign({}, getRow("equipment", t.equipId).value, { lastService: now }));
        await recordCost(d, "Maintenance: " + t.title, { category: "Janitorial and maintenance", equipId: t.equipId, who: t.assignee, link: { equipId: t.equipId || "", taskId: id } });
        logAct("Maintenance done: " + t.title + (parseFloat(d.cost) > 0 ? " (" + money(parseFloat(d.cost)) + ")" : ""), "Maintenance");
        toast("Marked done. Next due " + fd(next) + ".");
      }
    });
  };

  // Notify residents: choose everyone or chosen residents, and whether to also text their mobile numbers.
  // The notice is an announcement; a notice for chosen residents is only readable by the units that were chosen.
  function residentsList() {
    return (DB.accounts || []).filter(function (a) { return a.role !== "admin" && !a.suspended; })
      .sort(function (x, y) { return String(x.unit || "").localeCompare(String(y.unit || ""), undefined, { numeric: true }) || String(x.name).localeCompare(String(y.name)); });
  }
  function recentNotices() {
    var ns = list("mnotice").sort(function (a, b) { return b.v.at - a.v.at; }).slice(0, 5);
    if (!ns.length) return "";
    return '<div class="card" style="margin-top:16px;padding:0;overflow:hidden"><div style="padding:14px 18px"><h3 style="margin:0;font-size:17px">Recent notices</h3><p class="hint" style="margin:4px 0 0">Who each notice was sent to. Text messages are simulated in this prototype; the real system needs a text-message service.</p></div>' +
      tableRows(ns.map(function (r) {
        var n = r.v;
        return "<tr><td><b>" + esc(n.title) + '</b><div style="font-size:12px;color:var(--muted)">' + esc(new Date(n.at).toLocaleString()) + "</div></td><td>" + esc(n.to) + "</td><td>" +
          (n.channel === "sms" ? "Dashboard, app and " + esc(plural(n.smsSent, "text message")) + (n.noPhone ? ' <span class="chip warn">' + esc(plural(n.noPhone, "resident")) + " without a mobile number</span>" : "") : "Dashboard and app only") + "</td></tr>";
      }), ["NOTICE", "SENT TO", "HOW"], "") + "</div>";
  }
  window.maintNotify = function (id) {
    var row = getRow("mtask", id); if (!row) return;
    var t = row.value, res = residentsList(), picked = {};
    openForm({
      title: "Notify residents",
      intro: "Choose who gets this notice and how. It appears under Announcements in their dashboard and app.",
      submit: "Send notice",
      fields: [
        { name: "audience", label: "Send to", type: "select", options: [["all", "All residents (" + res.length + ")"], ["pick", "Choose residents…"]], value: "all" },
        { name: "channel", label: "How", type: "select", options: [["sms", "Dashboard, app and text message (all at once)"], ["app", "Dashboard and app only"]], value: "sms" },
        { name: "title", label: "Title", value: "Maintenance notice: " + t.title },
        { name: "body", label: "Message", type: "textarea", value: "Scheduled on " + fd(t.due) + ": " + t.title + (t.equipName ? " (" + t.equipName + ")" : "") + ". Some areas may be briefly unavailable. Thank you for your understanding." }
      ],
      onSubmit: async function (d) {
        if (!d.title) return { error: "Enter a title." };
        var targets = d.audience === "all" ? res : res.filter(function (a) { return picked[a.id]; });
        if (!targets.length) return { error: "Choose at least one resident." };
        var units = null;
        if (d.audience !== "all") { units = []; targets.forEach(function (a) { if (a.unit && units.indexOf(a.unit) < 0) units.push(a.unit); }); }
        var nid = nextId(), v = { id: nid, title: d.title, body: d.body || "—", date: shortDate(new Date()), status: "Published", type: "Maintenance" };
        if (units) v.units = units;
        await put("announcement", nid, "", v);
        var sms = d.channel === "sms" ? targets.filter(function (a) { return a.phone; }) : [], noPhone = d.channel === "sms" ? targets.length - sms.length : 0;
        var to = units ? plural(targets.length, "resident") + " in " + plural(units.length, "unit") : "All residents (" + targets.length + ")";
        var rid = String(nextId());
        await put("mnotice", rid, "__admin", { id: rid, title: d.title, at: Date.now(), to: to, count: targets.length, channel: d.channel, smsSent: sms.length, noPhone: noPhone });
        logAct("Maintenance notice sent to " + to + (d.channel === "sms" ? ", " + plural(sms.length, "text message") : "") + ": " + d.title, "Announcements");
        toast("Notice sent to " + to + (d.channel === "sms" ? " on the dashboard and app, plus " + plural(sms.length, "text message") + " (text messages are simulated in the prototype)."  : ".") + (d.channel === "sms" ? "" + (noPhone ? " " + plural(noPhone, "resident") + " without a mobile number." : "") : ""));
      }
    });
    var form = document.getElementById("rhForm"); if (!form) return;
    var aud = form.querySelector('select[name="audience"]'), chn = form.querySelector('select[name="channel"]'), lab = aud.parentNode;
    var box = document.createElement("div"); box.style.cssText = "display:none;border:1px solid #d9d2c3;border-radius:12px;padding:8px;background:#fff";
    box.innerHTML = '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:6px"><input type="search" id="mtPickQ" placeholder="Search name or unit" style="flex:1;min-width:140px;height:34px;border:1px solid #d9d2c3;border-radius:999px;padding:0 12px;font-size:13px">' +
      '<button type="button" class="btn" id="mtPickAll" style="min-height:34px;padding:0 10px;font-size:12px">Select shown</button><button type="button" class="btn" id="mtPickNone" style="min-height:34px;padding:0 10px;font-size:12px">Clear</button></div>' +
      '<div id="mtPickList" style="max-height:220px;overflow:auto"></div>';
    lab.parentNode.insertBefore(box, lab.nextSibling);
    var info = document.createElement("div"); info.className = "hint"; info.style.cssText = "margin:0;font-size:13px"; box.parentNode.insertBefore(info, chn.parentNode.nextSibling);
    var qEl = box.querySelector("#mtPickQ"), listEl = box.querySelector("#mtPickList");
    function shown() { var q = qEl.value.trim().toLowerCase(); return res.filter(function (a) { return !q || (a.name + " " + (a.unit || "")).toLowerCase().indexOf(q) >= 0; }); }
    function summary() {
      var tg = aud.value === "all" ? res : res.filter(function (a) { return picked[a.id]; }), ph = tg.filter(function (a) { return a.phone; }).length;
      info.innerHTML = "Will reach <b>" + plural(tg.length, "resident") + "</b>" + (chn.value === "sms" ? " on the dashboard and in the app, and by text message at the same time. <b>" + ph + "</b> have a mobile number to text" + (tg.length - ph ? ' <span class="chip warn">' + (tg.length - ph) + " have no mobile number</span>" : "") + "." : ".");
    }
    function draw() {
      listEl.innerHTML = shown().map(function (a) {
        return '<label style="display:flex;gap:10px;align-items:center;padding:6px 4px;cursor:pointer;border-radius:8px"><input type="checkbox" data-id="' + escAttr(a.id) + '"' + (picked[a.id] ? " checked" : "") + '><span style="font-size:13px;line-height:1.35"><b>' + esc(a.name) + "</b> · " + esc(a.unit || "—") +
          '<br><span style="color:var(--muted)">' + (a.phone ? esc(a.phone) : "No mobile number") + "</span></span></label>";
      }).join("") || '<div class="hint" style="padding:8px">No resident matches.</div>';
      summary();
    }
    listEl.addEventListener("change", function (e) { var id = e.target.getAttribute("data-id"); if (id) { picked[id] = e.target.checked; summary(); } });
    qEl.addEventListener("input", draw);
    qEl.addEventListener("keydown", function (e) { if (e.key === "Enter") e.preventDefault(); });
    box.querySelector("#mtPickAll").addEventListener("click", function () { shown().forEach(function (a) { picked[a.id] = true; }); draw(); });
    box.querySelector("#mtPickNone").addEventListener("click", function () { picked = {}; draw(); });
    aud.addEventListener("change", function () { box.style.display = aud.value === "pick" ? "block" : "none"; summary(); });
    chn.addEventListener("change", summary);
    draw();
  };

  window.maintDelete = function (kind, id) {
    var row = getRow(kind, id); if (!row) return;
    var name = row.value.title || row.value.name, label = kind === "mtask" ? "task" : kind === "staff" ? "staff member" : "equipment";
    confirmBox("Delete " + label, "Delete “" + name + "”? This cannot be undone.", "Delete", async function () {
      if (kind === "staff") {
        var busy = list("grievance").filter(function (g) { return g.v.staffId === id && !(Number(g.v.stage) >= 2); }).length + tasks().filter(function (t) { return t.v.staffId === id; }).length;
        if (busy) return { error: name + " still has " + plural(busy, "assignment") + ". Reassign them first." };
      }
      if (kind === "equipment") {
        var linked = tasks().filter(function (t) { return t.v.equipId === id; }).length + openRepairs(id);
        if (linked) return { error: name + " is still used by " + plural(linked, "linked item") + ". Remove or finish those first." };
      }
      await del(kind, id);
      if (kind === "equipment") await syncClosures();
      logAct("Deleted " + label + ": " + name, "Maintenance");
    }, true);
  };

  window.maintRenameType = function (name) {
    var row = customTypes().filter(function (r) { return r.v.name === name; })[0]; if (!row) return;
    openForm({
      title: "Rename type",
      intro: "Every task of this type is renamed too.",
      submit: "Save name",
      fields: [{ name: "name", label: "Type name", value: name, placeholder: "e.g. Inspection" }],
      onSubmit: async function (d) {
        var nn = cleanTypeName(d.name);
        if (!nn) return { error: "Enter the type name." };
        if (nn !== name) {
          var clash = typeOptions().some(function (o) { return o[0].toLowerCase() === nn.toLowerCase() || o[1].toLowerCase() === nn.toLowerCase(); });
          if (clash) return { error: "There is already a type with that name." };
          await put("mtype", row.id, "__admin", { name: nn });
          var mine = tasks().filter(function (t) { return t.v.kind === name; });
          for (var i = 0; i < mine.length; i++) await put("mtask", mine[i].id, "", Object.assign({}, mine[i].v, { kind: nn }));
          set({ mkind: nn });
          logAct("Maintenance type renamed: " + name + " to " + nn, "Maintenance");
        }
      }
    });
  };

  window.maintDeleteType = function (name) {
    var row = customTypes().filter(function (r) { return r.v.name === name; })[0]; if (!row) return;
    confirmBox("Delete type", "Delete the type “" + name + "”? It is only removed from the list.", "Delete", async function () {
      var used = tasks().filter(function (t) { return t.v.kind === name; }).length;
      if (used) return { error: "“" + name + "” is still used by " + plural(used, "task") + ". Change those tasks to another type first." };
      await del("mtype", row.id);
      set({ mkind: "all" });
      logAct("Maintenance type deleted: " + name, "Maintenance");
    }, true);
  };

  /* ----- repair assignment on complaints ----- */
  window.maintAssignForm = function (id) {
    var row = getRow("grievance", id); if (!row) return;
    var g = row.value;
    openForm({
      title: "Assign repair",
      intro: esc(g.title),
      fields: [
        { name: "staffId", label: "Assigned to", type: "select", options: staffOptions(), value: g.staffId || "" },
        { name: "priority", label: "Priority", type: "select", options: PRIORITIES, value: g.priority || "Normal" },
        { name: "target", label: "Target completion date", type: "date", value: g.target || addDays(dayKey(new Date()), 3) },
        { name: "equipId", label: "Related equipment (optional)", type: "select", options: equipOptions(), value: g.equipId || "" },
        { name: "notes", label: "Note for the repair", type: "textarea", value: g.notes, placeholder: "What needs to be done?" }
      ],
      onSubmit: async function (d) {
        var v = Object.assign({}, row.value);
        v.priority = d.priority;
        if (d.staffId) {
          v.staffId = d.staffId; v.assignee = staffNameOf(d.staffId); v.target = d.target;
          if (!(Number(v.stage) >= 1)) v.stage = 1;
        } else { delete v.staffId; delete v.assignee; delete v.target; }
        if (d.equipId) { v.equipId = d.equipId; v.equipName = equipNameOf(d.equipId); } else { delete v.equipId; delete v.equipName; }
        if (d.notes) v.notes = d.notes; else delete v.notes;
        await put("grievance", id, row.unit, v);
        if (d.staffId && d.equipId) {
          var e = getRow("equipment", d.equipId);
          if (e && e.value.status === "Working") await put("equipment", d.equipId, "__admin", Object.assign({}, e.value, { status: "Under maintenance" }));
          await syncClosures();
        }
        logAct(d.staffId ? "Repair assigned to " + v.assignee + ": " + g.title : "Repair unassigned: " + g.title, "Requests");
        toast(d.staffId ? "Assigned to " + v.assignee + "." : "Assignment removed.");
      }
    });
  };

  // Resolving a complaint asks what was done and what it cost. The cost becomes an expense linked to the equipment.
  window.advanceGr = function (id) {
    var row = getRow("grievance", id); if (!row) return;
    var st = Math.min(2, (Number(row.value.stage) || 0) + 1);
    if (st < 2) {
      return act(async function () {
        await put("grievance", id, row.unit, Object.assign({}, row.value, { stage: st }));
        logAct("Complaint in progress: " + row.value.title, "Requests");
      });
    }
    openForm({
      title: "Mark resolved",
      intro: esc(row.value.title),
      submit: "Mark resolved",
      fields: costFields(),
      onSubmit: async function (d) {
        var now = dayKey(new Date()), g = row.value;
        var v = Object.assign({}, g, { stage: 2, resolvedOn: now });
        if (d.completion) v.completion = d.completion;
        if (parseFloat(d.cost) > 0) v.cost = parseFloat(d.cost);
        await put("grievance", id, row.unit, v);
        if (g.equipId && getRow("equipment", g.equipId)) {
          await put("equipment", g.equipId, "__admin", Object.assign({}, getRow("equipment", g.equipId).value, { status: "Working", lastService: now }));
          await syncClosures();
        }
        await recordCost(d, "Repair: " + g.title, { category: "Repairs and improvements", equipId: g.equipId, who: g.assignee, link: { equipId: g.equipId || "", grievanceId: Number(id) } });
        logAct("Complaint resolved: " + g.title + (v.cost ? " (" + money(v.cost) + ")" : ""), "Requests");
      }
    });
  };

  function initialsOf(n) { return String(n || "?").split(/\s+/).filter(Boolean).slice(0, 2).map(function (w) { return w.charAt(0).toUpperCase(); }).join(""); }
  function assignBlock(r) {
    var g = r.v, s = Math.min(2, Math.max(0, Number(g.stage) || 0)), late = g.target && s < 2 && daysTo(g.target) < 0;
    if (!g.assignee) return '<div class="gr-assign none"><span class="gr-av">?</span><div><b>Not assigned yet</b><small>Pick who will fix it</small></div></div>';
    return '<div class="gr-assign"><span class="gr-av">' + esc(initialsOf(g.assignee)) + '</span><div><b>' + esc(g.assignee) + "</b> " + prioChip(g.priority) +
      '<small>' + (g.target && s < 2 ? "Target " + esc(fd(g.target)) + (late ? ' <span class="chip bad">Late</span>' : "") : "") + (g.equipName ? (g.target && s < 2 ? " · " : "") + esc(g.equipName) : "") + "</small>" +
      (g.notes && s < 2 ? '<small class="gr-note">“' + esc(g.notes) + "”</small>" : "") +
      (s === 2 && (g.completion || g.cost) ? '<small>Done ' + esc(fd(g.resolvedOn)) + (g.completion ? ": " + esc(g.completion) : "") + (g.cost ? " · cost " + money(g.cost) : "") + "</small>" : "") + "</div></div>";
  }

  var origViewReq = window.viewReq;
  /* Complaints & documents: two categories (Complaints, Documents). Complaints that are done are kept apart and compiled by month. */
  window.viewReq = function () {
    var names = ["Open", "In progress", "Resolved"], grs = newest(list("grievance"));
    var docsPart = origViewReq(), cut = docsPart.indexOf('<div class="card" style="padding:0;overflow:hidden;margin-top:16px">');
    docsPart = cut >= 0 ? docsPart.slice(cut).replace('overflow:hidden;margin-top:16px', 'overflow:hidden;margin-top:0') : "";
    var stageOf = function (r) { return Math.min(2, Math.max(0, Number(r.v.stage) || 0)); };
    var active = grs.filter(function (r) { return stageOf(r) < 2; }), done = grs.filter(function (r) { return stageOf(r) === 2; });
    var tab = state.reqTab === "docs" ? "docs" : "complaints", fil = state.reqFilter === "done" ? "done" : "active";
    var bar = subNav([["complaints", "Complaints", active.length || "", true], ["docs", "Documents", list("doc").length]], tab, "reqTab");
    if (tab === "docs") return bar + docsPart;
    var chips = '<div class="filters" style="margin-bottom:14px">' + [["active", "Active (" + active.length + ")"], ["done", "Done (" + done.length + ")"]].map(function (t) {
      return '<button class="' + (fil === t[0] ? "active" : "") + '" onclick="set({reqFilter:\'' + t[0] + '\'})">' + t[1] + "</button>";
    }).join("") + "</div>";
    if (fil === "active") {
      return bar + chips + (active.length ? '<div class="gr-grid">' + pageSlice(active, 6, "grActPage").map(function (r) {
        var g = r.v, s = stageOf(r);
        var steps = names.map(function (n, k) { return '<span class="' + (k < s ? "done" : k === s ? "cur" : "") + '"><i></i>' + n + "</span>"; }).join("");
        return '<div class="card gr-card st' + s + '"><div class="gr-top"><div class="gr-title">' + esc(g.title) + '</div><span class="gr-unit">' + esc(String(g.by || r.unit).replace(/^Unit\s*/i, "")) + '</span></div>' +
          '<small class="gr-by">Reported by ' + esc(g.by || r.unit) + '</small><p class="gr-body">' + esc(g.body) + "</p>" +
          assignBlock(r) + '<div class="gr-steps">' + steps + "</div>" +
          '<div class="gr-actions"><button class="btn" onclick="maintAssignForm(\'' + escAttr(r.id) + '\')">' + (g.assignee ? "Reassign" : "Assign repair") + '</button><button class="btn primary" onclick="advanceGr(\'' + escAttr(r.id) + '\')">' + (s === 0 ? "Start work" : "Mark resolved") + "</button></div></div>";
      }).join("") + "</div>" + pagerHtml(active.length, 6, "grActPage") : emptyCard(grs.length ? "No active complaints. Finished ones are under Done." : "No complaints from residents yet."));
    }
    // Done, compiled by the month it was finished
    var cost = done.reduce(function (t, r) { return t + (Number(r.v.cost) || 0); }, 0), groups = {}, order = [];
    var doneSorted = done.slice().sort(function (a, b) { return String(b.v.resolvedOn || "").localeCompare(String(a.v.resolvedOn || "")) || Number(b.id) - Number(a.id); });
    pageSlice(doneSorted, 8, "grDonePage").forEach(function (r) {
      var k = String(r.v.resolvedOn || "").slice(0, 7) || "none"; if (!groups[k]) { groups[k] = []; order.push(k); } groups[k].push(r);
    });
    var monthName = function (k) { if (k === "none") return "Earlier"; var d = kd(k + "-01"); return d ? d.toLocaleDateString("en-US", { month: "long", year: "numeric" }) : k; };
    var body = order.map(function (k) {
      var rows = groups[k], mc = rows.reduce(function (t, r) { return t + (Number(r.v.cost) || 0); }, 0);
      return '<div class="card" style="padding:0;overflow:hidden;margin-bottom:14px"><div style="display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;padding:14px 18px;background:var(--beige)"><b>' + esc(monthName(k)) + '</b><span style="color:var(--muted);font-size:13px">' + rows.length + " resolved" + (mc ? " · repair cost " + money(mc) : "") + "</span></div>" +
        rows.map(function (r) {
          var g = r.v;
          return '<div style="display:flex;gap:14px;align-items:flex-start;flex-wrap:wrap;padding:12px 18px;border-top:1px solid var(--border2)"><div style="flex:1 1 260px;min-width:0"><b>' + esc(g.title) + '</b><div style="font-size:13px;color:var(--muted)">' + esc(g.by || r.unit || "") + (g.assignee ? " · handled by " + esc(g.assignee) : "") + (g.equipName ? " · " + esc(g.equipName) : "") + "</div>" +
            (g.completion ? '<div style="font-size:13px;margin-top:3px">' + esc(g.completion) + "</div>" : "") + '</div><div style="text-align:right;font-size:13px;color:var(--muted);white-space:nowrap"><span class="chip good">Resolved</span><div style="margin-top:4px">' + (g.resolvedOn ? esc(fd(g.resolvedOn)) : "") + (g.cost ? " · " + money(g.cost) : "") + "</div></div></div>";
        }).join("") + "</div>";
    }).join("");
    return bar + chips + (done.length ? '<div class="stat-row" style="grid-template-columns:repeat(2,minmax(0,1fr));max-width:520px">' + statTile(done.length, "Complaints resolved", "good") + statTile(money(cost), "Total repair cost", "") + "</div>" + body + pagerHtml(doneSorted.length, 8, "grDonePage") : emptyCard("Nothing is done yet. Resolved complaints are compiled here by month."));
  };

  /* ==========================================================================
     Hooks into the real pages (nothing is edited in the real files)
     ========================================================================== */
  // A facility with equipment that is not working (and set to close) cannot be booked.
  var origSlot = window.slotState;
  window.slotState = function (f, i, day) {
    var st = origSlot(f, i, day);
    if (st === "open") { var a = facilities()[f]; if (a && closureOf(a.name)) return "closed"; }
    return st;
  };
  var origBook = window.viewBook;
  if (origBook) {
    window.viewBook = function () {
      var fl = facilities(), cur = fl[Math.min(state.facIdx || 0, fl.length - 1)], c = cur && closureOf(cur.name), h = origBook();
      var today = dayKey(new Date()), notes = cur ? blockList().filter(function (b) { return blockFits(b, cur.name) && (!b.to || b.to >= today); }).sort(function (a, b) { return String(a.from).localeCompare(String(b.from)); }).slice(0, 3) : [];
      var blockHtml = notes.length ? '<div class="card blk-notice"><b>' + esc(cur.name) + ' is not available at these times</b>' + notes.map(function (b) { return "<div><span>" + esc(b.reason) + "</span> " + esc(blockWhenText(b)) + (b.note ? " · " + esc(b.note) : "") + "</div>"; }).join("") + "</div>" : "";
      if (!c) return blockHtml + h;
      return blockHtml + '<div class="card" style="background:var(--warn-bg);color:var(--warn-fg);margin-bottom:12px"><b>' + esc(c.facility) + " is closed for maintenance.</b> " + esc(c.equipName) + " is " + esc(String(c.reason).toLowerCase()) + ". Booking is paused until it is working again.</div>" + h;
    };
  }

  var origTitles = window.titles;
  window.titles = function () {
    if (state.view === "maint" && IS_ADMIN) {
      return state.mpage ? ["Maintenance", "Details behind the numbers on the Maintenance page."] : ["Maintenance", "Preventive maintenance schedule, equipment, and the staff who do the work."];
    }
    return origTitles();
  };
  var origView = window.view;
  window.view = function () { return state.view === "maint" && IS_ADMIN ? viewMaint() : origView(); };

  // Adds the Maintenance button to the side menu, right after Complaints.
  var origMount = window.mountApp;
  window.mountApp = function (app, html) {
    if (!IS_ADMIN) return origMount(app, html);   // residents get maintenance news as announcements, not as a page
    var tag = dueCount() ? dueCount() + " due" : "";
    var btn = navBtn("maint", "Maintenance", tag);
    btn = btn.replace("set({view:'maint',bellOpen:false})", "set({view:'maint',mpage:'',bellOpen:false})");
    html = html.replace(/<button[^>]*set\(\{view:'(?:req|gr)'[^>]*>[\s\S]*?<\/button>/, function (m) { return m + btn; });
    return origMount(app, html);
  };

  if (IS_ADMIN) {
    // A Maintenance card on the dashboard: numbers, two progress bars and the next tasks coming up.
    var st = document.createElement("style");
    st.textContent =
      ".sc.mt{grid-column:1 / -1 !important;min-height:0 !important;display:grid !important;grid-template-columns:minmax(0,1.15fr) minmax(0,1fr);gap:18px 30px;padding:24px 28px}" +
      ".sc.mt .mt-left,.sc.mt .mt-right{position:relative;z-index:1;min-width:0;display:flex;flex-direction:column;gap:14px}" +
      ".sc.mt .mt-head{display:flex;align-items:center;gap:13px}" +
      ".sc.mt .mt-ico{flex:none;width:46px;height:46px;border-radius:16px;display:grid;place-items:center;background:rgba(255,255,255,.75);box-shadow:0 6px 14px rgba(9,39,91,.12)}" +
      ".sc.mt .mt-ico svg{width:24px;height:24px;fill:none;stroke:#09275b;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}" +
      ".sc.mt .mt-head small{display:block;margin-top:2px;font-size:12.5px;opacity:.7}" +
      ".sc.mt .sc-nums{margin-top:0;padding-top:0;flex-wrap:nowrap;gap:6px 18px}.sc.mt .sc-nums span{white-space:nowrap}" +
      ".sc.mt .sc-nums b.bad{color:#b3261e}.sc.mt .sc-nums b.warn{color:#9a5b00}" +
      ".sc.mt .mt-meter{display:flex;flex-direction:column;gap:6px}" +
      ".sc.mt .mt-meter>div:first-child{display:flex;justify-content:space-between;gap:10px;font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;opacity:.75}" +
      ".sc.mt .mt-bar{display:flex;gap:3px;height:12px}" +
      ".sc.mt .mt-bar i{display:block;height:100%;min-width:6px;border-radius:99px;transition:flex .6s ease}" +
      ".sc.mt .mt-bar i.none{flex:1;background:rgba(255,255,255,.65)}" +
      ".sc.mt .mt-leg{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:12px}" +
      ".sc.mt .mt-leg span{display:inline-flex;align-items:center;gap:6px}" +
      ".sc.mt .mt-leg em{width:9px;height:9px;border-radius:50%;display:inline-block}" +
      ".sc.mt .mt-right{background:rgba(255,255,255,.55);border-radius:20px;padding:16px 16px 14px}" +
      ".sc.mt .mt-right h4{margin:0;font-size:15px;font-weight:600;line-height:1.2;color:#09275b;display:flex;justify-content:space-between;align-items:center;gap:10px}" +
      ".sc.mt .mt-right h4 button{border:0;background:none;font-size:12.5px;font-weight:600;font-family:inherit;color:#1d4ed8;cursor:pointer;padding:4px 0}" +
      ".sc.mt .mt-row{display:flex;align-items:center;gap:11px;width:100%;padding:9px 11px;border:0;border-radius:14px;background:rgba(255,255,255,.85);text-align:left;font:inherit;color:inherit;cursor:pointer;transition:transform .2s ease,box-shadow .2s ease}" +
      ".sc.mt .mt-row:hover{transform:translateX(3px);box-shadow:0 6px 14px rgba(9,39,91,.1)}" +
      ".sc.mt .mt-row b{display:block;font-size:14px;font-weight:600;color:#09275b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" +
      ".sc.mt .mt-row small{display:block;margin-top:1px;font-size:12px;opacity:.7;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" +
      ".sc.mt .mt-row>span:nth-child(2){min-width:0;flex:1}" +
      ".sc.mt .mt-when{flex:none;min-width:78px;text-align:center;font-size:11.5px;font-weight:700;padding:6px 9px;border-radius:99px}" +
      ".sc.mt .mt-when.bad{background:#ffd9d4;color:#a02b1d}.sc.mt .mt-when.warn{background:#ffe9b8;color:#8a5a00}.sc.mt .mt-when.good{background:#d6f3e4;color:#1e7a4f}" +
      ".sc.mt .mt-empty{font-size:13.5px;opacity:.75;padding:10px 4px}" +
      "@media (max-width:900px){.sc.mt{grid-template-columns:minmax(0,1fr)}}";
    document.head.appendChild(st);

    function bar(parts, empty) { // parts: [[count, colour], ...]
      var total = parts.reduce(function (s, p) { return s + p[0]; }, 0);
      if (!total) return '<div class="mt-bar"><i class="none"></i></div>';
      return '<div class="mt-bar">' + parts.filter(function (p) { return p[0] > 0; }).map(function (p) { return '<i style="flex:' + p[0] + ';background:' + p[2] + '"></i>'; }).join("") + "</div>";
    }
    function legend(parts) { return '<div class="mt-leg">' + parts.map(function (p) { return '<span><em style="background:' + p[2] + '"></em>' + p[0] + " " + esc(p[1]) + "</span>"; }).join("") + "</div>"; }
    function whenLabel(t) {
      var n = daysTo(t.due);
      if (n == null) return ["No date", "good"];
      if (n < 0) return [-n + (n === -1 ? " day late" : " days late"), "bad"];
      if (n === 0) return ["Today", "warn"];
      if (n <= 7) return ["In " + n + (n === 1 ? " day" : " days"), "warn"];
      return [fd(t.due), "good"];
    }

    var origHome = window.viewHome;
    window.viewHome = function () {
      var h = origHome(), ts = tasks(), eq = equipList();
      var overdue = ts.filter(function (r) { return daysTo(r.v.due) < 0; }).length, soon = dueCount() - overdue, later = Math.max(0, ts.length - overdue - soon);
      var working = eq.filter(function (e) { return e.v.status === "Working"; }).length;
      var under = eq.filter(function (e) { return e.v.status === "Under maintenance"; }).length, bad = eq.length - working - under;
      var RED = "#e5534b", AMB = "#f2a33a", GRN = "#14a38b";
      var tp = [[overdue, "Overdue", RED], [soon, "Due this week", AMB], [later, "Scheduled later", GRN]];
      var ep = [[working, "Working", GRN], [under, "Under maintenance", AMB], [bad, "Needs repair", RED]];
      var next = ts.slice(0, 4).map(function (r) {
        var t = r.v, w = whenLabel(t);
        return '<button class="mt-row" onclick="set({view:\'maint\'})"><span class="mt-when ' + w[1] + '">' + esc(w[0]) + "</span><span><b>" + esc(t.title) + "</b><small>" + esc(t.equipName || "Whole building") + " · " + esc(t.assignee || "Unassigned") + "</small></span></button>";
      }).join("");
      var left = '<div class="mt-left"><div class="mt-head"><span class="mt-ico"><svg viewBox="0 0 24 24">' + NAV_ICONS.maint + "</svg></span><div><h3>Maintenance</h3><small>" + plural(ts.length, "scheduled task") + " · " + plural(eq.length, "piece") + " of equipment</small></div></div>" +
        '<div class="sc-nums"><button onclick="set({view:\'maint\'})"><b class="' + (overdue ? "bad" : "") + '">' + overdue + "</b><span>Overdue tasks</span></button>" +
        '<button onclick="set({view:\'maint\'})"><b class="' + (soon ? "warn" : "") + '">' + soon + "</b><span>Due this week</span></button>" +
        '<button onclick="set({view:\'maint\'})"><b class="' + (bad ? "bad" : "") + '">' + (bad + under) + "</b><span>Equipment to fix</span></button></div>" +
        '<div class="mt-meter"><div><span>Tasks</span><span>' + ts.length + " in total</span></div>" + bar(tp) + legend(tp) + "</div>" +
        '<div class="mt-meter"><div><span>Equipment condition</span><span>' + working + " of " + eq.length + " working</span></div>" + bar(ep) + legend(ep) + "</div></div>";
      var right = '<div class="mt-right"><h4>Coming up<button onclick="set({view:\'maint\'})">See schedule →</button></h4>' + (next || '<div class="mt-empty">No maintenance tasks yet. Add the first one.</div>') + "</div>";
      var card = '<div class="sc yellow mt">' + left + right + "</div>";
      // The dashboard grid has 5 columns and the four cards fill two rows, so this card takes a full row.
      // inside the summary grid (before its closing tag), never inside the "Did they pay?" card that follows it
      return h.indexOf("<!--sc-end-->") >= 0 ? h.replace("<!--sc-end-->", card + "<!--sc-end-->") : h.replace('</div><div class="pills-row">', card + '</div><div class="pills-row">');
    };
  }

  if (IS_ADMIN && window.viewManage) {
    // Access page: mark residents whose account is new or whose details changed in the last 7 days, and count who has no mobile number.
    var origManage = window.viewManage;
    window.viewManage = function () {
      var h = origManage(), week = 7 * 86400000, now = Date.now(), nNew = 0, nUpd = 0, noPhone = 0;
      (DB.accounts || []).forEach(function (a) {
        if (a.role === "admin") return;
        if (!a.phone) noPhone++;
        var c = Date.parse(a.created_at || ""), u = Date.parse(a.updated_at || ""), chip = "";
        if (c && now - c < week) { chip = '<span class="chip good" title="Account created ' + esc(new Date(c).toLocaleDateString()) + '">New</span>'; nNew++; }
        else if (u && now - u < week) { chip = '<span class="chip info" title="Changed ' + esc(new Date(u).toLocaleDateString()) + '">Updated: ' + esc(a.last_change || "details") + "</span>"; nUpd++; }
        var hl = (a.history || []).slice().sort(function (x, y) { return Date.parse(y.at) - Date.parse(x.at); });
        var hist1 = hl.length ? '<details style="margin-top:4px"><summary style="cursor:pointer;font-size:12px;font-weight:600;color:var(--muted)">History (' + hl.length + ")</summary>" +
          '<div style="font-weight:400;font-size:12.5px;line-height:1.5;margin-top:4px">' + hl.map(function (x) {
            return '<div style="padding:3px 0;border-top:1px solid rgba(120,120,140,.18)"><span style="color:var(--muted)">' + esc(new Date(x.at).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })) + "</span> · " + esc(x.field) +
              (x.from || x.to ? ": " + (x.from ? esc(x.from) : "—") + " → " + esc(x.to || "—") : "") + "</div>";
          }).join("") + "</div></details>" : "";
        var cell = '<td style="font-weight:700">' + esc(a.name) + '</td><td style="color:var(--muted)">' + esc(a.email) + "</td>";
        h = h.replace(cell, function () { return '<td style="font-weight:700">' + esc(a.name) + (chip ? " " + chip : "") + hist1 + '</td><td style="color:var(--muted)">' + esc(a.email) + "</td>"; });
      });
      return '<div class="card" style="margin-bottom:16px;display:flex;gap:10px;flex-wrap:wrap;align-items:center"><b>Resident contact info, last 7 days</b>' +
        '<span class="chip good">' + nNew + " new</span><span class=\"chip info\">" + nUpd + " updated</span>" + (noPhone ? '<span class="chip warn">' + noPhone + " without a mobile number</span>" : "") +
        '<span class="hint" style="margin:0;flex:1 1 260px">Notify residents uses this list: the name, unit and mobile number come from each account.</span></div>' + h;
    };
  }
})();

