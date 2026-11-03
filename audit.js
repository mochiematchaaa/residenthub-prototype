/* Audit trail (administrator only).
   The database writes one line for every add, change and delete of a record or an account:
   who did it, when, and the value before and after. Nobody can edit or delete those lines.
   This page only READS them, a page at a time, straight from the audit_log table. */

var AUD = { rows: [], total: 0, page: 0, size: 20, kind: "", who: "", from: "", to: "", loaded: false, loading: false, err: "", open: {}, stale: true };

var AUD_KINDS = {
  account: "Resident account", unit: "Unit", due: "Charge / due", proof: "Payment", payment: "Payment", slot: "Facility slot", booking: "Facility booking",
  announcement: "Announcement", request: "Parking request", renewal: "Parking renewal", grievance: "Complaint", equipment: "Equipment", poll: "Poll", vote: "Vote",
  mtype: "Maintenance type", mtask: "Maintenance task", mnotice: "Maintenance notice", mclosure: "Maintenance closure", statusUpdate: "Unit status update",
  expense: "Expense", staff: "Staff", fblock: "Facility block", event: "Event", rsvp: "RSVP", walkin: "Walk-in", doc: "Document", setting: "Setting"
};
var AUD_VERB = { INSERT: "Added", UPDATE: "Changed", DELETE: "Deleted" };
var AUD_HIDE = { id: 1, updated_at: 1, at: 1, createdAt: 1 };

// Plain-words name of a record type.
function audKind(k) { return AUD_KINDS[k] || (k ? k.charAt(0).toUpperCase() + k.slice(1) : "Record"); }
// Field name as words: "usageStatus" -> "Usage status".
function audLabel(k) { var s = String(k).replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase(); return s.charAt(0).toUpperCase() + s.slice(1); }
// One value, short enough for a table cell.
function audVal(v) {
  if (v === null || v === undefined || v === "") return "(empty)";
  var s = typeof v === "object" ? JSON.stringify(v) : String(v);
  return s.length > 60 ? s.slice(0, 57) + "…" : s;
}
// The list of "Field: before → after" lines for one audit row.
function audLines(r) {
  var o = r.old_value && typeof r.old_value === "object" ? r.old_value : {}, n = r.new_value && typeof r.new_value === "object" ? r.new_value : {}, out = [], keys = {};
  if (r.action === "UPDATE") {
    Object.keys(o).concat(Object.keys(n)).forEach(function (k) { keys[k] = 1; });
    Object.keys(keys).forEach(function (k) {
      if (AUD_HIDE[k]) return;
      if (JSON.stringify(o[k]) !== JSON.stringify(n[k])) out.push([audLabel(k), audVal(o[k]), audVal(n[k])]);
    });
    return out;
  }
  var src = r.action === "INSERT" ? n : o;
  Object.keys(src).forEach(function (k) {
    if (AUD_HIDE[k] || src[k] === "" || src[k] === null || typeof src[k] === "object") return;
    out.push([audLabel(k), null, audVal(src[k])]);
  });
  return out;
}
// How a row's changes look inside the table.
function audChangeHtml(r) {
  var lines = audLines(r), shown = lines.slice(0, 3);
  if (!lines.length) return '<span style="color:var(--muted)">No visible change</span>';
  return shown.map(function (l) {
    return '<div style="font-size:13px"><b>' + esc(l[0]) + ":</b> " + (l[1] === null ? esc(l[2]) : '<span style="color:var(--muted)">' + esc(l[1]) + "</span> → " + esc(l[2])) + "</div>";
  }).join("") + (lines.length > 3 ? '<div style="font-size:12px;color:var(--muted)">+ ' + (lines.length - 3) + " more (open details)</div>" : "");
}
// The full before / after values of one row.
function audDetailHtml(r) {
  var pre = function (v) { return '<pre style="margin:6px 0 0;white-space:pre-wrap;word-break:break-word;font-size:12px;background:var(--beige);border-radius:10px;padding:10px;max-height:260px;overflow:auto">' + esc(v === null || v === undefined ? "—" : JSON.stringify(v, null, 2)) + "</pre>"; };
  return '<tr><td colspan="5" style="background:var(--card2,transparent)"><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px;padding:6px 4px 12px">' +
    '<div><b style="font-size:12px;color:var(--muted)">BEFORE</b>' + pre(r.old_value) + '</div><div><b style="font-size:12px;color:var(--muted)">AFTER</b>' + pre(r.new_value) + "</div></div>" +
    '<div style="font-size:12px;color:var(--muted);padding:0 4px 8px">Entry #' + esc(r.id) + " · " + esc(r.source_table) + " · record " + esc(r.record_id) + "</div></td></tr>";
}

// Reads one page of the audit trail (filters are applied by the database).
async function auditLoad() {
  if (AUD.loading) return;
  AUD.loading = true; AUD.err = "";
  try {
    var q = sb.from("audit_log").select("*", { count: "exact" });
    if (AUD.kind) q = q.eq("kind", AUD.kind);
    if (AUD.who.trim()) q = q.ilike("actor_name", "%" + AUD.who.trim() + "%");
    if (AUD.from) q = q.gte("at", new Date(AUD.from + "T00:00:00").toISOString());
    if (AUD.to) q = q.lte("at", new Date(AUD.to + "T23:59:59.999").toISOString());
    var res = await q.order("at", { ascending: false }).order("id", { ascending: false }).range(AUD.page * AUD.size, AUD.page * AUD.size + AUD.size - 1);
    if (res.error) throw res.error;
    AUD.rows = res.data || [];
    AUD.total = typeof res.count === "number" ? res.count : AUD.rows.length;
    AUD.loaded = true; AUD.stale = false;
    var pages = Math.max(1, Math.ceil(AUD.total / AUD.size));
    if (AUD.page > pages - 1 && AUD.total) { AUD.page = pages - 1; AUD.loading = false; return auditLoad(); }
  } catch (e) {
    AUD.err = (e && e.message) || "Could not load the audit trail.";
    AUD.loaded = true; AUD.stale = false;
  }
  AUD.loading = false;
  if (state.view === "audit") render();
}
// Re-read from the database (used when opening the page and after filters change).
function auditRefresh(resetPage) { if (resetPage) AUD.page = 0; AUD.open = {}; AUD.stale = true; AUD.loaded = false; auditLoad(); render(); }
function auditPage(n) { AUD.page = Math.max(0, n); AUD.open = {}; AUD.stale = true; auditLoad(); render(); window.scrollTo({ top: 0, behavior: "smooth" }); }
function auditToggle(id) { AUD.open[id] = !AUD.open[id]; render(); }
var audTimer = null;
function auditWho(v) { AUD.who = v; clearTimeout(audTimer); audTimer = setTimeout(function () { auditRefresh(true); }, 350); }
function auditClear() { AUD.kind = ""; AUD.who = ""; AUD.from = ""; AUD.to = ""; auditRefresh(true); }

// Downloads the rows that match the filters (up to 5,000) as CSV.
async function auditExport() {
  try {
    var q = sb.from("audit_log").select("*");
    if (AUD.kind) q = q.eq("kind", AUD.kind);
    if (AUD.who.trim()) q = q.ilike("actor_name", "%" + AUD.who.trim() + "%");
    if (AUD.from) q = q.gte("at", new Date(AUD.from + "T00:00:00").toISOString());
    if (AUD.to) q = q.lte("at", new Date(AUD.to + "T23:59:59.999").toISOString());
    var res = await q.order("at", { ascending: false }).order("id", { ascending: false }).range(0, 4999);
    if (res.error) throw res.error;
    exportCSV("audit-trail.csv", ["Entry", "When", "Who", "Role", "Action", "Type", "Record", "Unit", "Changes", "Before", "After"], (res.data || []).map(function (r) {
      var ch = audLines(r).map(function (l) { return l[1] === null ? l[0] + ": " + l[2] : l[0] + ": " + l[1] + " -> " + l[2]; }).join("; ");
      return [r.id, new Date(r.at).toLocaleString(), r.actor_name, r.actor_role, AUD_VERB[r.action] || r.action, audKind(r.kind), r.record_id, r.unit, ch,
        r.old_value ? JSON.stringify(r.old_value) : "", r.new_value ? JSON.stringify(r.new_value) : ""];
    }));
  } catch (e) { toast((e && e.message) || "Could not export."); }
}

// PAGE: Audit trail.
function viewAudit() {
  if (AUD.stale && !AUD.loading) setTimeout(auditLoad, 0);
  var kinds = Object.keys(AUD_KINDS).sort(function (a, b) { return audKind(a).localeCompare(audKind(b)); });
  var pages = Math.max(1, Math.ceil(AUD.total / AUD.size));
  var filters = '<div class="card" style="display:flex;gap:12px;flex-wrap:wrap;align-items:flex-end">' +
    '<label class="fl" style="min-width:170px">What<select onchange="AUD.kind=this.value;auditRefresh(true)"><option value="">Everything</option>' + kinds.map(function (k) { return '<option value="' + escAttr(k) + '"' + (AUD.kind === k ? " selected" : "") + ">" + esc(audKind(k)) + "</option>"; }).join("") + "</select></label>" +
    '<label class="fl" style="min-width:170px">Who<input id="audWho" value="' + escAttr(AUD.who) + '" placeholder="Name of the person" oninput="auditWho(this.value)"></label>' +
    '<label class="fl">From<input type="date" value="' + escAttr(AUD.from) + '" onchange="AUD.from=this.value;auditRefresh(true)"></label>' +
    '<label class="fl">To<input type="date" value="' + escAttr(AUD.to) + '" onchange="AUD.to=this.value;auditRefresh(true)"></label>' +
    '<div style="margin-left:auto;display:flex;gap:8px;flex-wrap:wrap"><button class="btn" onclick="auditClear()">Clear</button><button class="btn" onclick="auditRefresh(false)">Refresh</button><button class="btn" onclick="auditExport()">Export to Excel (.csv)</button></div></div>';
  var note = '<div class="hint" style="margin:12px 2px 12px">Every add, change and delete is recorded by the database itself, with who did it and the value before and after. Entries are locked: no one, including the administrator, can edit or remove them. Resident photos and temporary passwords are never copied here.</div>';
  var body;
  if (AUD.err) body = '<div class="card" style="color:#A02B1D;font-weight:600">' + esc(AUD.err) + "</div>";
  else if (!AUD.loaded) body = '<div class="card" style="text-align:center;color:var(--muted)">Loading the audit trail…</div>';
  else {
    var trs = [];
    AUD.rows.forEach(function (r) {
      var ac = { INSERT: "#1F7A4D", UPDATE: "#9A6A00", DELETE: "#A02B1D" }[r.action] || "var(--ink)";
      trs.push('<tr><td style="color:var(--muted);white-space:nowrap">' + new Date(r.at).toLocaleString() + "</td>" +
        '<td><b>' + esc(r.actor_name || "—") + '</b><div style="font-size:12px;color:var(--muted)">' + esc(r.actor_role || "") + "</div></td>" +
        '<td><b style="color:' + ac + '">' + esc(AUD_VERB[r.action] || r.action) + "</b> · " + esc(audKind(r.kind)) + '<div style="font-size:12px;color:var(--muted)">' + esc([r.unit && r.unit !== "__admin" ? r.unit : "", r.kind === "account" ? "" : r.record_id].filter(Boolean).join(" · ")) + "</div></td>" +
        "<td>" + audChangeHtml(r) + '</td><td><button class="btn" style="min-height:32px;padding:0 10px;font-size:12px" onclick="auditToggle(\'' + escAttr(r.id) + '\')">' + (AUD.open[r.id] ? "Hide" : "Details") + "</button></td></tr>");
      if (AUD.open[r.id]) trs.push(audDetailHtml(r));
    });
    body = '<div class="card" style="padding:0;overflow:hidden;opacity:' + (AUD.loading ? ".6" : "1") + '">' +
      (AUD.rows.length ? '<div style="overflow:auto"><table><thead><tr><th>WHEN</th><th>WHO</th><th>WHAT</th><th>CHANGE</th><th></th></tr></thead><tbody>' + trs.join("") + "</tbody></table></div>"
        : '<div style="padding:22px;text-align:center;color:var(--muted)">' + (AUD.kind || AUD.who || AUD.from || AUD.to ? "Nothing matches those filters." : "Nothing has been recorded yet.") + "</div>") +
      (AUD.total > AUD.size ? pagerHtml(AUD.total, AUD.page, AUD.size, "auditPage") : "") + "</div>";
  }
  return filters + note + '<div style="font-size:13px;color:var(--muted);margin:0 2px 8px">' + AUD.total + " entries</div>" + body;
}
