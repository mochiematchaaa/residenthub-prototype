/* ==========================================================================
   record.js — the household record of a unit, drawn the same way for the office and the resident.
   The office edits everything (history.js: recordForm). The resident edits the household, emergency contact and vehicles
   from their own dashboard (resident.js: recordSelfForm). Shared by admin.html and resident.html.
   ========================================================================== */
/* The number of people is the number of members listed (one per line), so the two can never disagree. Older records that only have a number keep it. */
function recMemberLines(u) { return String((u && u.members) || "").split(/\n/).map(function (x) { return x.trim(); }).filter(Boolean); }
function recHouseCount(u) { var n = recMemberLines(u).length; return n || Number(u && u.residents) || 0; }
var REC_SELF_KEYS = ["residents", "members", "pets", "emergencyName", "emergencyRelation", "emergencyPhone", "vehicles"];

function recLinesOf(text) { return String(text || "").split(/\n+/).map(function (x) { return x.trim(); }).filter(Boolean); }
function recNone(t) { return '<span class="rec2-none">' + (t || "Not on file") + "</span>"; }
function recRow(k, v, edit) { return '<div class="rec2-row"><span>' + k + (edit ? ' <i title="You can edit this" class="rec2-pen">✎</i>' : "") + "</span><b>" + v + "</b></div>"; }
function recChips(text, empty) {
  var l = recLinesOf(text);
  return l.length ? '<div class="rec2-chips">' + l.map(function (x) { return "<em>" + esc(x) + "</em>"; }).join("") + "</div>" : recNone(empty);
}
/* The log of what the resident changed (kept on the unit record as "selfLog", newest first, last 20): [{field, from, to, at, by}] */
function recLogOf(unit) { var u = unitRec(unit) || {}; return Array.isArray(u.selfLog) ? u.selfLog : []; }
// Adds entries to the log and stamps the record as edited by the resident. Used by the profile page; the household form builds its own entries.
async function recLogSelf(unit, entries, by) {
  var old = unitRec(unit) || {}, now = Date.now();
  var log = entries.map(function (e) { return { field: e.field, from: e.from || "", to: e.to || "", at: now, by: by || "" }; }).concat(Array.isArray(old.selfLog) ? old.selfLog : []).slice(0, 20);
  await put("unit", unit, unit, Object.assign({}, old, { selfLog: log, selfUpdated: now, selfBy: by || old.selfBy || "" }));
}
// "Recent changes" list under the record.
function recLogHtml(unit) {
  var l = recLogOf(unit).slice(0, 6);
  if (!l.length) return "";
  return '<div class="rec2-log"><h3>Recent changes by the resident</h3>' + l.map(function (h) {
    return '<div class="rec2-row"><span>' + esc(h.field) + "</span><b>" + (h.from ? esc(h.from) + " → " : "") + esc(h.to || "removed") + ' <small style="color:var(--muted);font-weight:400">· ' + esc(shortDate(new Date(Number(h.at)))) + (h.by ? " · " + esc(h.by) : "") + "</small></b></div>";
  }).join("") + "</div>";
}
// Who changed the record last: the office or the resident.
function recStamp(u) {
  var off = Number(u.profileUpdated) || 0, self = Number(u.selfUpdated) || 0;
  if (!off && !self) return null;
  return self > off ? { ts: self, by: u.selfBy || "the resident", src: "resident" } : { ts: off, by: u.profileBy || "the office", src: "office" };
}
// The record card. o = { admin: true|false, email: sign-in email, button: html for the edit button }.
function recordSheetHtml(unit, o) {
  o = o || {};
  var u = unitRec(unit) || {}, st = recStamp(u), name = u.name && u.name !== "—" ? u.name : "", d = typeof unitDues === "function" ? unitDues(unit) : {};
  var slot = list("slot").filter(function (r) { return r.v.unit === unit; })[0];
  var emer = [u.emergencyName, u.emergencyRelation ? "(" + u.emergencyRelation + ")" : ""].filter(Boolean).join(" ");
  var mob = u.contact && u.contact !== "—" ? esc(u.contact) : recNone();
  var self = !o.admin;
  return '<section class="card rec2"><header class="rec2-head"><span class="rec2-av">' + avatarInner(self ? myPhoto() : unitPhoto(unit), name || String(unit)) + '</span><div class="rec2-id"><h2>' + (name ? esc(name) : "No name on file") + '</h2><div class="rec2-sub"><span class="chip">' + esc(unit) + '</span><span class="chip">' + esc(u.type || "Owner") + "</span>" + (u.moveIn ? '<span class="chip good">Moved in ' + esc(usageDate(u.moveIn)) + "</span>" : "") + "</div></div>" +
    '<div class="rec2-tools">' + (o.button || "") + "</div></header>" +
    '<p class="rec2-stamp">' + (st ? (st.src === "resident" ? '<span class="chip info">Edited by the resident</span> ' : "") + "Last updated " + esc(shortDate(new Date(st.ts))) + " by " + esc(st.by) + (st.src === "resident" ? " (resident)" : st.src === "office" && o.admin ? "" : " (office)") + "." : "Not filled in yet.") +
    (o.admin ? " What you save here is shown to the resident on their dashboard." : " Update your household, emergency contact and vehicles yourself. Ask the office to change anything else.") + "</p>" +
    (u.noteResident ? '<div class="rec2-call info"><b>Note from the office</b>' + esc(u.noteResident) + "</div>" : "") +
    (o.admin && u.noteOffice ? '<div class="rec2-call warn"><b>Private office note · the resident does not see this</b>' + esc(u.noteOffice) + "</div>" : "") +
    '<div class="rec2-cols">' +
    '<div class="rec2-col"><h3>Contact</h3>' + recRow("Mobile", mob) + recRow("Email", u.email || o.email ? esc(u.email || o.email) : recNone()) + (o.admin ? recRow("Sign-in account", o.email ? esc(o.email) : recNone("None yet")) : "") +
    recRow("Floor area", d.area ? esc(String(d.area)) + " sqm" : recNone("Not set")) + recRow("Parking slot", slot ? esc(slot.id) + " · " + esc(slot.v.size || "Regular") : recNone("None")) + "</div>" +
    '<div class="rec2-col"><h3>Household</h3>' + recRow("People living here", recHouseCount(u) ? esc(String(recHouseCount(u))) : recNone(), self) + recRow("Pets", u.pets ? esc(u.pets) : recNone("None on file"), self) + '<div class="rec2-row stack"><span>Members' + (self ? ' <i class="rec2-pen">✎</i>' : "") + "</span>" + recChips(u.members) + "</div></div>" +
    '<div class="rec2-col"><h3>Emergency contact</h3>' + (u.emergencyName || u.emergencyPhone ? '<div class="rec2-person"><span class="rec2-av sm">' + esc(initials(u.emergencyName || "?")) + "</span><div><b>" + esc(emer || "Emergency contact") + "</b><small>" + (u.emergencyPhone ? esc(u.emergencyPhone) : "No number") + "</small></div></div>" : recNone()) + "</div>" +
    '<div class="rec2-col"><h3>Vehicles' + (self ? ' <i class="rec2-pen">✎</i>' : "") + "</h3>" + recChips(u.vehicles, "None on file") + "</div></div>" + recLogHtml(unit) + "</section>";
}
