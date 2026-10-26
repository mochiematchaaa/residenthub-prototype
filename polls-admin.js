/* Polls and elections: the administrator's page. Build a poll or an election with formatted text, see the results, export them to Excel.
   Loaded after export-all.js, which provides the Excel writer. */

/* ---------- formatted text editor (bold, italic, underline, lists, large text) ---------- */
function richEditor(key, html, placeholder, small) {
  var btn = function (cmd, label, title) { return '<button type="button" class="rte-btn" title="' + title + '" aria-label="' + title + '" onmousedown="event.preventDefault()" onclick="rteCmd(\'' + cmd + '\')">' + label + "</button>"; };
  return '<div class="rte"><div class="rte-bar">' + btn("bold", "<b>B</b>", "Bold") + btn("italic", "<i>I</i>", "Italic") + btn("underline", "<u>U</u>", "Underline") +
    btn("h3", "Aa", "Larger text") + btn("insertUnorderedList", "&#8226;&#8801;", "Bulleted list") + btn("insertOrderedList", "1.&#8801;", "Numbered list") + btn("removeFormat", "Clear", "Remove formatting") + "</div>" +
    '<div class="rte-body' + (small ? " sm" : "") + '" contenteditable="true" role="textbox" aria-multiline="true" data-key="' + escAttr(key) + '" data-ph="' + escAttr(placeholder || "") + '" oninput="rteInput(this)" onblur="rteInput(this)" onpaste="rtePaste(event)">' + cleanRich(html) + "</div></div>";
}
function rteCmd(cmd) {
  var a = document.activeElement;
  if (!a || !a.classList || !a.classList.contains("rte-body")) return toast("Click inside the text first, then choose a style.");
  if (cmd === "h3") document.execCommand("formatBlock", false, String(document.queryCommandValue("formatBlock")).toLowerCase() === "h3" ? "div" : "h3");
  else document.execCommand(cmd, false, null);
  rteInput(a);
}
function rtePaste(e) {
  e.preventDefault();
  document.execCommand("insertText", false, (e.clipboardData || window.clipboardData).getData("text/plain"));
}
// Keeps the draft in step with what is typed (no redraw, so the cursor stays where it is).
function rteInput(el) {
  var d = state.pollDraft; if (!d) return;
  var k = el.dataset.key, html = cleanRich(el.innerHTML);
  if (k === "title") d.titleHtml = html; else if (k === "desc") d.descHtml = html;
  else if (k.indexOf("q:") === 0 && d.questions[+k.slice(2)]) d.questions[+k.slice(2)].html = html;
}

/* ---------- the builder ---------- */
var BOARD_POSITIONS = ["President", "Vice President", "Secretary", "Treasurer", "Auditor"];
function blankQuestion(kind) {
  return kind === "election" ? { type: "choice", html: "", options: "", seats: 1, required: false } : { type: "choice", html: "", options: "Option 1\nOption 2", max: 0, required: false };
}
function newPoll(kind) {
  var end = new Date(Date.now() + (kind === "election" ? 14 : 7) * 86400000);
  state.pollDraft = { kind: kind, titleHtml: "", descHtml: "", closeKey: dayKey(end), showResults: kind === "election" ? "closed" : "vote", questions: [blankQuestion(kind)] };
  render();
}
function pdSet(field, v) { state.pollDraft[field] = v; }
function pqSet(i, field, v) { state.pollDraft.questions[i][field] = v; }
function pqRedraw(i, field, v) { state.pollDraft.questions[i][field] = v; render(); }
function pqAdd() { state.pollDraft.questions.push(blankQuestion(state.pollDraft.kind)); render(); }
function pqBoard() {
  var d = state.pollDraft;
  d.questions = d.questions.filter(function (q) { return richText(q.html) || q.options.trim(); });
  BOARD_POSITIONS.forEach(function (n) { var q = blankQuestion("election"); q.html = esc(n); d.questions.push(q); });
  render();
}
function pqMove(i, dir) {
  var qs = state.pollDraft.questions, j = i + dir; if (j < 0 || j >= qs.length) return;
  var t = qs[i]; qs[i] = qs[j]; qs[j] = t; render();
}
function pqDup(i) { var qs = state.pollDraft.questions; qs.splice(i + 1, 0, JSON.parse(JSON.stringify(qs[i]))); render(); }
function pqDel(i) {
  var qs = state.pollDraft.questions;
  if (qs.length < 2) return toast("A poll needs at least one question.");
  qs.splice(i, 1); render();
}
function cancelPoll() { state.pollDraft = null; render(); }

function pollBuilderHtml() {
  var d = state.pollDraft, el = d.kind === "election";
  var qcards = d.questions.map(function (q, i) {
    var typeSel = el ? "" : '<select class="pq-type" onchange="pqRedraw(' + i + ',\'type\',this.value)">' + POLL_TYPES.map(function (t) { return '<option value="' + t[0] + '"' + (q.type === t[0] ? " selected" : "") + ">" + t[1] + "</option>"; }).join("") + "</select>";
    var body = "";
    if (el) {
      body = '<div class="fl"><span>Candidates (one per line, for example: Maria Santos — Unit 5A)</span><textarea rows="4" oninput="pqSet(' + i + ',\'options\',this.value)" placeholder="Maria Santos — Unit 5A&#10;Ramon Dela Cruz — Unit 1B">' + esc(q.options) + "</textarea></div>" +
        '<div class="fl" style="max-width:260px"><span>Residents can vote for up to</span><input type="number" min="1" max="20" value="' + (q.seats || 1) + '" oninput="pqSet(' + i + ',\'seats\',Math.max(1,Number(this.value)||1))"></div>';
    } else if (q.type === "choice" || q.type === "multi") {
      body = '<div class="fl"><span>Options (one per line)</span><textarea rows="4" oninput="pqSet(' + i + ',\'options\',this.value)">' + esc(q.options) + "</textarea></div>" +
        (q.type === "multi" ? '<div class="fl" style="max-width:260px"><span>Most choices allowed (leave 0 for no limit)</span><input type="number" min="0" max="20" value="' + (q.max || 0) + '" oninput="pqSet(' + i + ',\'max\',Math.max(0,Number(this.value)||0))"></div>' : "");
    } else body = '<p class="hint" style="margin:0">' + (q.type === "text" ? "Residents type a short answer." : q.type === "para" ? "Residents type a longer answer." : "Residents rate from 1 to 5.") + "</p>";
    return '<div class="pq-card"><div class="pq-head"><b>' + (el ? "Position " : "Question ") + (i + 1) + "</b>" + typeSel +
      '<span class="pq-tools"><button type="button" class="btn" title="Move up" onclick="pqMove(' + i + ',-1)"' + (i === 0 ? " disabled" : "") + '>&#8593;</button><button type="button" class="btn" title="Move down" onclick="pqMove(' + i + ',1)"' + (i === d.questions.length - 1 ? " disabled" : "") + '>&#8595;</button><button type="button" class="btn" onclick="pqDup(' + i + ')">Duplicate</button><button type="button" class="btn" style="color:var(--bad-fg)" onclick="pqDel(' + i + ')">Delete</button></span></div>' +
      '<div class="fl"><span>' + (el ? "Position (for example President)" : "Question") + "</span>" + richEditor("q:" + i, q.html, el ? "Position name" : "Type your question", true) + "</div>" + body +
      (el ? "" : '<label class="pq-req-row"><input type="checkbox" ' + (q.required ? "checked" : "") + ' onchange="pqSet(' + i + ',\'required\',this.checked)"> Required</label>') + "</div>";
  }).join("");
  return '<div class="card pb"><div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start;flex-wrap:wrap"><div><h2 style="margin:0">' + (el ? "New election" : "New poll") + '</h2><p class="hint" style="margin:4px 0 0">' +
    (el ? "Each unit gets one secret ballot. Residents see the results only after the election closes." : "Ask one question or several, like a form. Each unit answers once.") + '</p></div><button class="btn" onclick="cancelPoll()">Cancel</button></div>' +
    '<div class="fl" style="margin-top:14px"><span>' + (el ? "Election title" : "Poll title") + "</span>" + richEditor("title", d.titleHtml, el ? "e.g. 2026 Board of Directors election" : "e.g. Building facilities survey", true) + "</div>" +
    '<div class="fl"><span>Description (optional)</span>' + richEditor("desc", d.descHtml, "Tell residents what this is for and how to answer", true) + "</div>" +
    '<div class="pb-row"><div class="fl"><span>Closes on</span><input type="date" min="' + dayKey(new Date()) + '" value="' + escAttr(d.closeKey) + '" onchange="pdSet(\'closeKey\',this.value)"></div>' +
    '<div class="fl"><span>Results for residents</span><select onchange="pdSet(\'showResults\',this.value)"><option value="vote"' + (d.showResults === "vote" ? " selected" : "") + '>Right after they vote</option><option value="closed"' + (d.showResults === "closed" ? " selected" : "") + ">Only when it closes</option></select></div></div>" +
    '<h3 style="margin:18px 0 8px">' + (el ? "Positions and candidates" : "Questions") + "</h3>" + qcards +
    '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:12px"><button class="btn" onclick="pqAdd()">+ ' + (el ? "Add position" : "Add question") + "</button>" + (el ? '<button class="btn" onclick="pqBoard()">Add standard board positions</button>' : "") +
    '<button class="btn primary" style="margin-left:auto" onclick="publishPoll()">' + (el ? "Open the election" : "Publish poll") + "</button></div></div>";
}

// Checks the draft and publishes it.
function publishPoll() {
  var d = state.pollDraft, el = d.kind === "election";
  if (!richText(d.titleHtml)) return toast("Give it a title first.");
  var qs = [], err = "";
  d.questions.forEach(function (q, i) {
    if (err) return;
    var text = richText(q.html), opts = q.options.split("\n").map(function (s) { return s.trim(); }).filter(Boolean);
    if (!text) { err = (el ? "Position " : "Question ") + (i + 1) + " needs a name."; return; }
    var type = el ? ((q.seats || 1) > 1 ? "multi" : "choice") : q.type, choice = type === "choice" || type === "multi";
    if (choice && opts.length < (el ? 1 : 2)) { err = (el ? "Add at least one candidate for “" : "Add at least two options for “") + text + "”."; return; }
    qs.push({ id: "q" + (i + 1), type: type, html: cleanRich(q.html), text: text, required: !!q.required, max: el ? (q.seats || 1) : (type === "multi" ? (q.max || 0) : 0), options: choice ? opts : [] });
  });
  if (err) return toast(err);
  if (!d.closeKey || d.closeKey < dayKey(new Date())) return toast("Pick a closing date that is today or later.");
  act(async function () {
    var id = nextId(), p = d.closeKey.split("-");
    await put("poll", id, "", { id: id, kind: d.kind, question: richText(d.titleHtml), titleHtml: cleanRich(d.titleHtml), descHtml: cleanRich(d.descHtml), open: true,
      closes: shortDate(new Date(+p[0], +p[1] - 1, +p[2])), closeKey: d.closeKey, showResults: d.showResults, options: qs[0].options, questions: qs });
    logAct((el ? "Election opened: " : "Poll published: ") + richText(d.titleHtml), "Polls");
    state.pollDraft = null; state.pollFilter = "open";
    toast(el ? "Election opened. Residents can vote now." : "Poll published. Residents can answer now.");
  });
}

/* ---------- the page ---------- */
function viewPolls() {
  if (state.pollDraft) return pollBuilderHtml();
  var all = pollsAll(), open = all.filter(function (p) { return p.open; }).length, units = list("unit").length;
  var shown = all.filter(function (p) { return state.pollFilter === "all" || (state.pollFilter === "open") === p.open; });
  return '<div class="filters" style="margin-bottom:4px"><button class="btn primary" onclick="newPoll(\'poll\')">+ New poll</button><button class="btn" onclick="newPoll(\'election\')">+ New election</button></div>' +
    pageTabs([["open", "Open (" + open + ")"], ["closed", "Closed (" + (all.length - open) + ")"], ["all", "All (" + all.length + ")"]], state.pollFilter, "pollFilter") +
    '<div class="poll-list">' + (shown.map(function (p) {
      var election = p.kind === "election", hidden = election && p.open && p.showResults === "closed";
      return '<div class="card poll-card"><div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px"><div style="min-width:0"><span class="chip ' + (election ? "warn" : "info") + '" style="margin-bottom:8px">' + (election ? "Election" : "Poll") + '</span><h2 class="poll-title">' + richHtml(p.titleHtml, p.q) + "</h2>" +
        (p.descHtml ? '<div class="poll-desc">' + richHtml(p.descHtml) + "</div>" : "") + '<small style="color:var(--muted)">' + (p.open ? "Closes " : "Closed ") + esc(p.closes) + (p.legacy ? "" : " · " + p.questions.length + (election ? " position" : " question") + (p.questions.length === 1 ? "" : "s")) + '</small></div><span class="chip ' + (p.open ? "good" : "info") + '">' + (p.open ? "Open" : "Closed") + "</span></div>" +
        (hidden ? '<p class="poll-note">Ballots are secret. The results stay hidden until the election closes, so nobody can see who is ahead.</p>' : pollResultsHtml(p, null, true)) +
        (units ? '<div style="margin-top:14px">' + progressBar("Units that voted", p.ballots, units, "green") + "</div>" : "") +
        '<div style="display:flex;gap:8px;margin-top:14px;flex-wrap:wrap"><button class="btn" onclick="togglePoll(' + p.id + ')">' + (p.open ? (election ? "Close election" : "Close poll") : "Reopen") + '</button><button class="btn" onclick="exportPollXlsx(' + p.id + ')"' + (hidden ? ' disabled title="Available when the election closes"' : "") + '>Export to Excel</button><button class="btn" style="margin-left:auto;color:var(--bad-fg)" onclick="deletePoll(' + p.id + ')">Delete</button></div></div>';
    }).join("") || '<p class="empty">No polls here yet.</p>') + "</div>";
}
// Opens or closes voting on a poll (reopening gives it another week).
function togglePoll(id) {
  var row = getRow("poll", id); if (!row) return;
  act(async function () {
    var open = !row.value.open, v = Object.assign({}, row.value, { open: open });
    if (open) { var end = new Date(Date.now() + 7 * 86400000); v.closeKey = dayKey(end); v.closes = shortDate(end); }
    else if (v.closeKey && v.closeKey >= dayKey(new Date())) { v.closes = shortDate(new Date()); v.closeKey = dayKey(new Date(Date.now() - 86400000)); }
    await put("poll", id, "", v);
    logAct((open ? "Reopened: " : "Closed: ") + row.value.question, "Polls");
  });
}
// Deletes a poll.
function deletePoll(id) {
  var row = getRow("poll", id); if (!row) return;
  confirmBox("Delete this poll?", "The poll and its results will be removed.", "Delete", async function () {
    await del("poll", id);
    var gone = list("vote").filter(function (r) { return Number(r.v.poll) === Number(id); });
    for (var i = 0; i < gone.length; i++) await del("vote", gone[i].id);
    logAct("Poll deleted: " + row.value.question, "Polls");
  }, true);
}

/* ---------- Excel export ---------- */
// The sheets of one poll's workbook: Overview, Results, Responses (not for elections, to keep ballots secret) and Turnout.
function pollSheets(p) {
  var X = window.__rhXlsx, units = list("unit"), votes = list("vote").filter(function (x) { return Number(x.v.poll) === p.id; });
  var election = p.kind === "election", pct = function (a, b) { return b ? Math.round(a / b * 100) + "%" : "—"; };
  var byUnit = {}; votes.forEach(function (x) { byUnit[x.unit] = x; });
  var title = richText(p.titleHtml) || p.q, sheets = [];
  sheets.push(X.tableSheet({ name: "Overview", group: "System", info: "Results exported " + shortDate(new Date()), cols: [["Item", "text", { w: 30 }], ["Details", "text", { w: 64, wrap: true }]], rows: [
    ["Title", title], ["Type", election ? "Election (secret ballot)" : "Poll"], ["Description", richText(p.descHtml)], ["Status", p.open ? "Open" : "Closed"], ["Closes", p.closes],
    ["Results shown to residents", p.showResults === "closed" ? "Only when it closes" : "Right after they vote"], [election ? "Ballots cast" : "Responses", p.ballots], ["Units in the building", units.length], ["Units that voted", Object.keys(byUnit).length], ["Turnout", pct(Object.keys(byUnit).length, units.length)]] }));
  var rows = [];
  p.questions.forEach(function (q, i) {
    var label = (election ? "" : (i + 1) + ". ") + q.text;
    if (q.type === "choice" || q.type === "multi") {
      var st = pollElected(p, q);
      q.opts.forEach(function (o, k) { rows.push([label, o.t, o.votes, pct(o.votes, q.n), st[k]]); });
    } else if (q.type === "rating") {
      [5, 4, 3, 2, 1].forEach(function (s) { rows.push([label, s + " star" + (s === 1 ? "" : "s"), q.counts[s - 1], pct(q.counts[s - 1], q.n), ""]); });
      rows.push([label, "Average rating", q.n ? Math.round(q.sum / q.n * 100) / 100 : "", "", ""]);
    } else rows.push([label, "Written answers are on the Responses sheet", q.n, "", ""]);
  });
  sheets.push(X.tableSheet({ name: "Results", group: "System", info: title, cols: [[election ? "Position / question" : "Question", "text", { w: 44, wrap: true }], ["Answer", "text", { w: 40, wrap: true }], ["Votes", "int", { bar: true }], ["Share of answers", "text"], ["Result", "text"]], rows: rows }));
  if (!election) {
    var cols = [["Unit", "text"], ["Resident", "text", { w: 26 }], ["Submitted", "text", { w: 20 }]].concat(p.questions.map(function (q, i) { return [(i + 1) + ". " + q.text, "text", { w: 30, wrap: true }]; }));
    sheets.push(X.tableSheet({ name: "Responses", group: "System", info: "One row per unit", cols: cols, rows: votes.map(function (x) {
      var a = x.v.answers || { q1: x.v.option }, u = unitRec(x.unit) || {}, when = x.v.at ? new Date(x.v.at) : null;
      return [x.unit, u.name || u.house || "", when && !isNaN(when) ? shortDate(when) : ""].concat(p.questions.map(function (q) {
        var v = a[q.id]; if (v == null) return "";
        if (q.type === "choice") return q.options[v] || "";
        if (q.type === "multi") return [].concat(v).map(function (k) { return q.options[k]; }).filter(Boolean).join(", ");
        return q.type === "rating" ? Number(v) : String(v);
      }));
    }) }));
  }
  sheets.push(X.tableSheet({ name: "Turnout", group: "System", info: election ? "Who voted, not how they voted" : "Which units took part", cols: [["Unit", "text"], ["Resident", "text", { w: 28 }], ["Voted", "text"]], rows: units.slice().sort(function (a, b) { return String(a.id).localeCompare(String(b.id), undefined, { numeric: true }); }).map(function (u) {
    return [u.id, u.v.name || u.v.house || "", byUnit[u.id] ? "Yes" : "No"];
  }) }));
  return sheets;
}
async function exportPollXlsx(id) {
  var X = window.__rhXlsx; if (!X) return toast("Excel export is not available on this page.");
  var p = pollsAll().filter(function (x) { return x.id === Number(id); })[0]; if (!p) return;
  try {
    var slug = (richText(p.titleHtml) || p.q).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) || "poll";
    var name = "results-" + slug + "-" + dayKey(new Date()) + ".xlsx", how = await X.saveBlob((X.resetStyles(), X.makeXlsx(pollSheets(p))), name);
    if (how === "cancel") return;
    logAct("Poll results exported to Excel: " + p.q, "Polls");
    toast(how === "picked" ? "Saved " + name + "." : "Downloaded " + name + ". Find it in your Downloads folder.");
  } catch (e) { toast("Could not create the Excel file: " + (e && e.message || e)); }
}
