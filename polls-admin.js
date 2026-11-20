/* Polls: the administrator's page. Build a poll like a form, with formatted text, see the results, export them to Excel.
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
function blankQuestion() { return { type: "choice", html: "", options: ["Option 1", "Option 2"], max: 0, required: false }; }
function newPoll() {
  var end = new Date(Date.now() + 7 * 86400000);
  state.pollDraft = { category: "General", titleHtml: "", descHtml: "", closeKey: dayKey(end), showResults: "vote", questions: [blankQuestion()] };
  render();
}
function pdSet(field, v) { state.pollDraft[field] = v; }
function pqSet(i, field, v) { state.pollDraft.questions[i][field] = v; }
function pqRedraw(i, field, v) { state.pollDraft.questions[i][field] = v; render(); }
function pqAdd() { state.pollDraft.questions.push(blankQuestion()); render(); }
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
// One option per row: typing updates the draft without a redraw; Enter adds a row; pasting several lines makes several rows.
function optSet(i, k, v) { state.pollDraft.questions[i].options[k] = v; }
function optFocus(i, k) { var el = document.querySelector('[data-opt="' + i + "-" + k + '"]'); if (el) { el.focus(); el.select && el.select(); } }
function optAdd(i, at) { var o = state.pollDraft.questions[i].options; o.splice(at == null ? o.length : at, 0, ""); render(); optFocus(i, at == null ? o.length - 1 : at); }
function optDel(i, k) {
  var o = state.pollDraft.questions[i].options;
  if (o.length < 2) { o[0] = ""; render(); return optFocus(i, 0); }
  o.splice(k, 1); render();
}
function optKey(e, i, k) { if (e.key === "Enter") { e.preventDefault(); optAdd(i, k + 1); } }
function optPaste(e, i, k) {
  var t = (e.clipboardData || window.clipboardData).getData("text/plain");
  if (t.indexOf("\n") < 0) return;
  e.preventDefault();
  var lines = t.split(/\r?\n/).map(function (x) { return x.trim(); }).filter(Boolean), o = state.pollDraft.questions[i].options;
  o.splice.apply(o, [k, 1].concat(lines)); render();
}

function optionRows(i, q) {
  var mark = q.type === "multi" ? "sq" : "rd";
  var rows = q.options.map(function (t, k) {
    return '<div class="opt-row"><span class="opt-no ' + mark + '"></span><input type="text" data-opt="' + i + "-" + k + '" value="' + escAttr(t) + '" placeholder="Option ' + (k + 1) + '" oninput="optSet(' + i + "," + k + ',this.value)" onkeydown="optKey(event,' + i + "," + k + ')" onpaste="optPaste(event,' + i + "," + k + ')">' +
      '<button type="button" class="opt-x" title="Remove" aria-label="Remove" onclick="optDel(' + i + "," + k + ')">&times;</button></div>';
  }).join("");
  return '<div class="opt-list">' + rows + '<button type="button" class="opt-add" onclick="optAdd(' + i + ')">+ Add option</button></div>';
}

function pollBuilderHtml() {
  var d = state.pollDraft;
  var nOpts = d.questions.reduce(function (t, q) { return t + q.options.filter(function (x) { return String(x).trim(); }).length; }, 0);
  var qcards = d.questions.map(function (q, i) {
    var typeSel = '<select class="pq-type" onchange="pqRedraw(' + i + ',\'type\',this.value)">' + POLL_TYPES.map(function (t) { return '<option value="' + t[0] + '"' + (q.type === t[0] ? " selected" : "") + ">" + t[1] + "</option>"; }).join("") + "</select>";
    var body = "";
    if (q.type === "choice" || q.type === "multi") {
      body = '<div class="pq-label">Options <small>Press Enter for the next one, or paste a list</small></div>' + optionRows(i, q) +
        (q.type === "multi" ? '<div class="seat-row"><span>Most choices allowed</span><input type="number" min="0" max="20" value="' + (q.max || 0) + '" oninput="pqSet(' + i + ',\'max\',Math.max(0,Number(this.value)||0))"><small>0 = no limit</small></div>' : "");
    } else body = '<div class="pq-demo">' + (q.type === "rating" ? [1, 2, 3, 4, 5].map(function (n) { return "<span>" + n + "</span>"; }).join("") + "<small>Residents rate from 1 to 5</small>" : '<span class="line' + (q.type === "para" ? " tall" : "") + '">' + (q.type === "text" ? "Short answer" : "Long answer") + "</span>") + "</div>";
    return '<div class="pq-card"><div class="pq-head"><span class="pq-badge">' + (i + 1) + "</span><b>Question</b>" + typeSel +
      '<span class="pq-tools"><button type="button" class="btn" title="Move up" onclick="pqMove(' + i + ',-1)"' + (i === 0 ? " disabled" : "") + '>&#8593;</button><button type="button" class="btn" title="Move down" onclick="pqMove(' + i + ',1)"' + (i === d.questions.length - 1 ? " disabled" : "") + '>&#8595;</button><button type="button" class="btn" onclick="pqDup(' + i + ')">Duplicate</button><button type="button" class="btn danger" onclick="pqDel(' + i + ')">Delete</button></span></div>' +
      '<div class="pq-label">Question</div>' + richEditor("q:" + i, q.html, "Type your question", true) + body +
      '<label class="pq-req-row"><input type="checkbox" ' + (q.required ? "checked" : "") + ' onchange="pqSet(' + i + ',\'required\',this.checked)"> Required</label></div>';
  }).join("");
  return '<div class="pb"><div class="pb-hero"><div><span class="pb-kind">Poll</span><h2>New poll</h2><p>Ask one question or several, like a form. Each unit answers once.</p></div><button class="btn" onclick="cancelPoll()">Cancel</button></div>' +
    '<div class="pb-wrap"><div class="pb-main">' +
    '<div class="card pb-sec"><div class="pb-sech"><span class="pb-step">1</span><h3>Details</h3></div>' +
    '<div class="pq-label">Category</div><div class="pb-catrow"><select class="pb-cat" onchange="pdSet(\'category\',this.value)">' + pollCategories().map(function (c) { return '<option' + (d.category === c ? " selected" : "") + ">" + esc(c) + "</option>"; }).join("") + '</select><button type="button" class="btn" onclick="newPollCategory()">+ New category</button><button type="button" class="btn" onclick="manageCategories()">Edit / delete categories</button></div>' +
    '<div class="pq-label">Poll title</div>' + richEditor("title", d.titleHtml, "e.g. Building facilities survey", true) +
    '<div class="pq-label">Description <small>optional</small></div>' + richEditor("desc", d.descHtml, "Tell residents what this is for and how to answer") + "</div>" +
    '<div class="card pb-sec"><div class="pb-sech"><span class="pb-step">2</span><h3>Questions</h3></div>' +
    '<div class="pq-cards">' + qcards + '</div><button type="button" class="pq-addtile" onclick="pqAdd()">+ Add question</button></div></div>' +
    '<aside class="pb-side"><div class="card pb-sec"><div class="pb-sech"><span class="pb-step">3</span><h3>Settings</h3></div>' +
    '<div class="pq-label">Closes on</div><input type="date" min="' + dayKey(new Date()) + '" value="' + escAttr(d.closeKey) + '" onchange="pdSet(\'closeKey\',this.value)">' +
    '<div class="pq-label">Results for residents</div><select onchange="pdSet(\'showResults\',this.value)"><option value="vote"' + (d.showResults === "vote" ? " selected" : "") + '>Right after they answer</option><option value="closed"' + (d.showResults === "closed" ? " selected" : "") + ">Only when it closes</option></select></div>" +
    '<div class="card pb-sec pb-sum"><div class="pb-sum-row"><b>' + d.questions.length + "</b><span>question" + (d.questions.length === 1 ? "" : "s") + "</span></div>" +
    (nOpts ? '<div class="pb-sum-row"><b>' + nOpts + "</b><span>options</span></div>" : "") +
    '<button class="btn primary" style="width:100%;margin-top:10px" onclick="publishPoll()">Publish poll</button><p class="hint" style="margin:8px 0 0;text-align:center">Residents can answer right away.</p></div></aside></div></div>';
}

// Checks the draft and publishes it.
function publishPoll() {
  var d = state.pollDraft;
  if (!richText(d.titleHtml)) return toast("Give it a title first.");
  var qs = [], err = "";
  d.questions.forEach(function (q, i) {
    if (err) return;
    var text = richText(q.html), opts = q.options.map(function (s) { return String(s).trim(); }).filter(Boolean);
    if (!text) { err = "Question " + (i + 1) + " needs a name."; return; }
    var type = q.type, choice = type === "choice" || type === "multi";
    if (choice && opts.length < 2) { err = "Add at least two options for “" + text + "”."; return; }
    qs.push({ id: "q" + (i + 1), type: type, html: cleanRich(q.html), text: text, required: !!q.required, max: type === "multi" ? (q.max || 0) : 0, options: choice ? opts : [] });
  });
  if (err) return toast(err);
  if (!d.closeKey || d.closeKey < dayKey(new Date())) return toast("Pick a closing date that is today or later.");
  act(async function () {
    var id = nextId(), p = d.closeKey.split("-");
    await put("poll", id, "", { id: id, kind: "poll", category: d.category || "General", question: richText(d.titleHtml), titleHtml: cleanRich(d.titleHtml), descHtml: cleanRich(d.descHtml), open: true,
      closes: shortDate(new Date(+p[0], +p[1] - 1, +p[2])), closeKey: d.closeKey, showResults: d.showResults, options: qs[0].options, questions: qs });
    logAct("Poll published: " + richText(d.titleHtml), "Polls");
    state.pollDraft = null; state.pollFilter = "open";
    toast("Poll published. Residents can answer now.");
  });
}

/* ---------- the page ---------- */
function pollTab() { return state.pollFilter === "closed" || state.pollFilter === "cats" ? state.pollFilter : "open"; }
function viewPolls() {
  if (state.pollDraft) return pollBuilderHtml();
  var all = pollsAll(), open = all.filter(function (p) { return p.open; }).length, units = list("unit").length, tab = pollTab();
  var tools = '<button class="btn primary" onclick="newPoll()">+ New poll</button>';
  var bar = subNav([["open", "Open", open, open > 0], ["closed", "Closed", all.length - open], ["cats", "Categories", catList().length]], tab, "pollFilter", tools);
  if (tab === "cats") return bar + pollCategoriesPage(all);
  var shown = all.filter(function (p) { return (tab === "open") === p.open && pollCatMatch(p); });
  return bar + pollCatFilterHtml(all) +
    '<div class="poll-list">' + (shown.map(function (p) {
      return '<div class="card poll-card' + (p.questions.length > 1 ? " wide" : "") + '"><div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:12px"><div style="min-width:0">' + pollChips(p) + '<h2 class="poll-title">' + richHtml(p.titleHtml, p.q) + "</h2>" +
        (p.descHtml ? '<div class="poll-desc">' + richHtml(p.descHtml) + "</div>" : "") + '<small style="color:var(--muted)">' + (p.open ? "Closes " : "Closed ") + esc(p.closes) + (p.legacy ? "" : " · " + p.questions.length + " question" + (p.questions.length === 1 ? "" : "s")) + '</small></div><span class="chip ' + (p.open ? "good" : "info") + '">' + (p.open ? "Open" : "Closed") + "</span></div>" +
        pollResultsHtml(p, null, true) +
        (units ? '<div style="margin-top:14px">' + progressBar("Units that answered", p.ballots, units, "green") + "</div>" : "") +
        '<div style="display:flex;gap:8px;margin-top:14px;flex-wrap:wrap"><button class="btn" onclick="toggleVoters(' + p.id + ')">' + (state.votersOpen === p.id ? "Hide responses" : "Who answered (" + p.ballots + ")") + '</button><button class="btn" onclick="togglePoll(' + p.id + ')">' + (p.open ? "Close poll" : "Reopen") + '</button><button class="btn" onclick="exportPollXlsx(' + p.id + ')">Export to Excel</button><button class="btn" style="margin-left:auto;color:var(--bad-fg)" onclick="deletePoll(' + p.id + ')">Delete</button></div>' + (state.votersOpen === p.id ? votersPanel(p) : "") + "</div>";
    }).join("") || '<p class="empty">' + (tab === "open" ? "No open polls. Start one with “New poll”." : "No closed polls yet.") + "</p>") + "</div>";
}
// Sub-page "Categories": every category with how many polls it has, and the button to manage them.
// Shows the open polls of one category.
function pollCatGo(i) { set({ pollCat: catList()[i] || "all", pollFilter: "open" }); }
function pollCategoriesPage(all) {
  return '<div class="card"><div class="fx-head"><h2>Poll categories</h2><button class="btn primary" onclick="manageCategories()">Manage categories</button></div><p class="hint" style="margin:4px 0 10px">Residents can filter the polls by category.</p>' +
    catList().map(function (c, i) {
      var n = all.filter(function (p) { return p.category === c; }).length, o = all.filter(function (p) { return p.category === c && p.open; }).length;
      return '<div class="am-row"><div><b>' + esc(c) + "</b><small>" + n + " poll" + (n === 1 ? "" : "s") + (o ? " · " + o + " open" : "") + '</small></div><button class="btn" onclick="pollCatGo(' + i + ')">View polls</button></div>';
    }).join("") + "</div>";
}
/* ---------- categories ---------- */
var catEdit = -1, catAsk = -1;
function catClean(name, except) {
  name = String(name || "").trim().replace(/\s+/g, " ");
  if (!name) return { error: "Type a category name." };
  if (name.length > 40) return { error: "Keep the name under 40 characters." };
  var l = catList();
  if (l.some(function (c, k) { return k !== except && c.toLowerCase() === name.toLowerCase(); })) return { error: "That category already exists." };
  return { name: name };
}
function catSave(l) { return put("setting", "poll_categories", "", { list: l }); }
// Adds a category to the list.
async function addCategoryName(name) {
  var r = catClean(name, -1); if (r.error) return r;
  await catSave(catList().concat([r.name]));
  logAct("Poll category added: " + r.name, "Polls");
  return r;
}
// "+ New category" next to the category list of the builder: adds it and picks it.
function newPollCategory() {
  openForm({ title: "New category", intro: "For example Pets, Elevators or Recreation.", submit: "Add category", fields: [{ name: "name", label: "Category name", placeholder: "e.g. Pets" }],
    onSubmit: async function (d) {
      var r = await addCategoryName(d.name);
      if (r.error) return r;
      if (state.pollDraft) state.pollDraft.category = r.name;
    } });
}
// The list of categories: add, rename or remove them.
function manageCategories() {
  var l = catList(), all = pollsAll();
  var row = function (c, i) {
    var n = all.filter(function (p) { return p.category === c; }).length, plural = n + " poll" + (n === 1 ? "" : "s");
    if (c === "General") return '<div class="cat-row"><span class="cat-name">General</span><span class="cat-n">' + plural + '</span><span class="cat-lock">default</span></div>';
    if (catEdit === i) return '<form class="cat-row cat-edit" onsubmit="event.preventDefault();renamePollCategory(' + i + ')"><input id="catRename" maxlength="40" value="' + escAttr(c) + '" autocomplete="off"><button class="btn primary" type="submit">Save</button><button class="btn" type="button" onclick="catEdit=-1;manageCategories()">Cancel</button></form>';
    if (catAsk === i) return '<div class="cat-row cat-ask"><span class="cat-name">' + (n ? "Move " + plural + " to General and remove “" + esc(c) + "”?" : "Remove “" + esc(c) + "”?") + '</span><button class="btn danger" onclick="removePollCategory(' + i + ')">Remove</button><button class="btn" onclick="catAsk=-1;manageCategories()">Keep</button></div>';
    return '<div class="cat-row"><span class="cat-name">' + esc(c) + '</span><span class="cat-n">' + plural + '</span><button class="btn cat-btn" onclick="catEdit=' + i + ';catAsk=-1;manageCategories()">Edit</button><button class="btn cat-btn danger" onclick="catAsk=' + i + ';catEdit=-1;manageCategories()">Delete</button></div>';
  };
  openModal('<h2>Poll categories</h2><p style="margin:0 0 10px;font-size:13.5px;color:var(--muted)">Add, rename or remove categories. Residents can filter the polls by category.</p>' +
    '<div class="cat-list">' + l.map(row).join("") + "</div>" +
    '<form class="cat-add" onsubmit="event.preventDefault();addPollCategoryFromBox()"><input id="catNew" maxlength="40" placeholder="New category name" autocomplete="off"><button class="btn primary" type="submit">Add</button></form><div class="formerr" id="catErr" hidden></div>' +
    '<div class="modal-actions"><button class="btn" onclick="catEdit=-1;catAsk=-1;closeModal()">Done</button></div>');
  var el = document.getElementById(catEdit >= 0 ? "catRename" : "catNew"); if (el) { el.focus(); if (catEdit >= 0) el.select(); }
}
function catError(msg) { var err = document.getElementById("catErr"); if (err) { err.textContent = msg; err.hidden = false; } else toast(msg); }
async function addPollCategoryFromBox() {
  try {
    var r = await addCategoryName(document.getElementById("catNew").value);
    if (r.error) return catError(r.error);
    await rhRefresh(true); manageCategories(); toast("Category added: " + r.name);
  } catch (e) { toast(errText(e)); }
}
// Renames a category everywhere it is used.
async function renamePollCategory(i) {
  var l = catList(), old = l[i], r = catClean(document.getElementById("catRename").value, i);
  if (r.error) return catError(r.error);
  if (r.name === old) { catEdit = -1; return manageCategories(); }
  try {
    l[i] = r.name;
    await catSave(l);
    var rows = list("poll").filter(function (x) { return x.v.category === old; });
    for (var k = 0; k < rows.length; k++) await put("poll", rows[k].id, "", Object.assign({}, rows[k].v, { category: r.name }));
    if (state.pollCat === old) state.pollCat = r.name;
    if (state.pollDraft && state.pollDraft.category === old) state.pollDraft.category = r.name;
    logAct("Poll category renamed: " + old + " to " + r.name, "Polls");
    catEdit = -1; await rhRefresh(true); manageCategories(); toast("Renamed to " + r.name + ".");
  } catch (e) { toast(errText(e)); }
}
// Removes a category; its polls move to General.
async function removePollCategory(i) {
  var l = catList(), name = l[i]; if (name == null || name === "General") return;
  try {
    var rows = list("poll").filter(function (x) { return x.v.category === name; });
    for (var k = 0; k < rows.length; k++) await put("poll", rows[k].id, "", Object.assign({}, rows[k].v, { category: "General" }));
    l.splice(i, 1); await catSave(l);
    if (state.pollCat === name) state.pollCat = "all";
    if (state.pollDraft && state.pollDraft.category === name) state.pollDraft.category = "General";
    logAct("Poll category removed: " + name, "Polls");
    catAsk = -1; await rhRefresh(true); manageCategories(); toast("Removed " + name + (rows.length ? ". Its polls moved to General." : "."));
  } catch (e) { toast(errText(e)); }
}

/* ---------- who voted ---------- */
function toggleVoters(id) { set({ votersOpen: state.votersOpen === id ? null : id, votersTab: "voted" }); }
// Units that answered (with the day and their answers) and units that have not answered yet.
function votersPanel(p) {
  var votes = list("vote").filter(function (x) { return Number(x.v.poll) === p.id; }), byUnit = {};
  votes.forEach(function (x) { byUnit[x.unit] = x; });
  var units = list("unit").slice().sort(function (a, b) { return String(a.id).localeCompare(String(b.id), undefined, { numeric: true }); });
  var who = function (u) { var r = unitRec(u) || {}; return esc(r.name || r.house || ""); };
  var voted = units.filter(function (u) { return byUnit[u.id]; }), not = units.filter(function (u) { return !byUnit[u.id]; });
  var tab = state.votersTab === "not" ? "not" : "voted";
  var answer = function (x) {
    var a = x.v.answers || { q1: x.v.option };
    return p.questions.map(function (q, i) {
      var v = a[q.id]; if (v == null || v === "") return "";
      var t = q.type === "choice" ? q.options[v] : q.type === "multi" ? [].concat(v).map(function (k) { return q.options[k]; }).filter(Boolean).join(", ") : q.type === "rating" ? v + " / 5" : String(v);
      return p.questions.length === 1 ? esc(t) : (i + 1) + ". " + esc(t);
    }).filter(Boolean).join("<br>");
  };
  var head = '<div class="voters"><div class="filters" style="padding:0 0 8px"><button class="' + (tab === "voted" ? "active" : "") + '" onclick="set({votersTab:\'voted\'})">Answered (' + voted.length + ')</button><button class="' + (tab === "not" ? "active" : "") + '" onclick="set({votersTab:\'not\'})">Not yet answered (' + not.length + ")</button></div>";
  if (tab === "not") return head + (not.length ? '<div class="voters-grid">' + not.map(function (u) { return "<div><b>" + esc(u.id) + "</b><span>" + who(u.id) + "</span></div>"; }).join("") + "</div>" : '<p class="hint">Every unit has answered.</p>') + "</div>";
  return head + (voted.length ? '<div class="voters-scroll"><table><thead><tr><th>UNIT</th><th>RESIDENT</th><th>ANSWERED ON</th><th>ANSWERS</th></tr></thead><tbody>' + voted.map(function (u) {
    var x = byUnit[u.id], when = x.v.at ? new Date(x.v.at) : null;
    return '<tr><td class="nw" style="font-weight:700">' + esc(u.id) + "</td><td>" + who(u.id) + '</td><td class="nw" style="color:var(--muted)">' + (when && !isNaN(when) ? shortDate(when) : "—") + "</td>" + "<td>" + (answer(x) || "—") + "</td></tr>";
  }).join("") + "</tbody></table></div>" : '<p class="hint">Nobody has answered yet.</p>') + "</div>";
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
// The sheets of one poll's workbook: Overview, Results, Responses and Turnout.
function pollSheets(p) {
  var X = window.__rhXlsx, units = list("unit"), votes = list("vote").filter(function (x) { return Number(x.v.poll) === p.id; });
  var pct = function (a, b) { return b ? Math.round(a / b * 100) + "%" : "—"; };
  var byUnit = {}; votes.forEach(function (x) { byUnit[x.unit] = x; });
  var title = richText(p.titleHtml) || p.q, sheets = [];
  sheets.push(X.tableSheet({ name: "Overview", group: "System", info: "Results exported " + shortDate(new Date()), cols: [["Item", "text", { w: 30 }], ["Details", "text", { w: 64, wrap: true }]], rows: [
    ["Title", title], ["Category", p.category], ["Description", richText(p.descHtml)], ["Status", p.open ? "Open" : "Closed"], ["Closes", p.closes],
    ["Results shown to residents", p.showResults === "closed" ? "Only when it closes" : "Right after they answer"], ["Responses", p.ballots], ["Units in the building", units.length], ["Units that answered", Object.keys(byUnit).length], ["Participation", pct(Object.keys(byUnit).length, units.length)]] }));
  var rows = [];
  p.questions.forEach(function (q, i) {
    var label = (i + 1) + ". " + q.text;
    if (q.type === "choice" || q.type === "multi") {
      q.opts.forEach(function (o) { rows.push([label, o.t, o.votes, pct(o.votes, q.n)]); });
    } else if (q.type === "rating") {
      [5, 4, 3, 2, 1].forEach(function (s) { rows.push([label, s + " star" + (s === 1 ? "" : "s"), q.counts[s - 1], pct(q.counts[s - 1], q.n)]); });
      rows.push([label, "Average rating", q.n ? Math.round(q.sum / q.n * 100) / 100 : "", ""]);
    } else rows.push([label, "Written answers are on the Responses sheet", q.n, ""]);
  });
  sheets.push(X.tableSheet({ name: "Results", group: "System", info: title, cols: [["Question", "text", { w: 44, wrap: true }], ["Answer", "text", { w: 40, wrap: true }], ["Answers", "int", { bar: true }], ["Share of answers", "text"]], rows: rows }));
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
  sheets.push(X.tableSheet({ name: "Participation", group: "System", info: "Which units took part", cols: [["Unit", "text"], ["Resident", "text", { w: 28 }], ["Answered", "text"]], rows: units.slice().sort(function (a, b) { return String(a.id).localeCompare(String(b.id), undefined, { numeric: true }); }).map(function (u) {
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
