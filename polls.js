/* Polls and elections: the parts shared by the administrator and resident pages.
   A poll has a title and description (bold / italic text allowed), then one or more questions of these types:
   multiple choice, checkboxes, short answer, paragraph, rating (1 to 5).
   An election is a poll whose questions are positions with candidates; the ballot is secret and the results appear when it closes.
   Each unit votes once. Older single-question polls (a plain question and a list of options) still work. */

var POLL_CATEGORIES = ["General", "Facilities & amenities", "Maintenance & repairs", "Finance & budget", "Safety & security", "Events & community", "Rules & policies", "Governance & elections"];
var POLL_TYPES = [["choice", "Multiple choice"], ["multi", "Checkboxes"], ["text", "Short answer"], ["para", "Paragraph"], ["rating", "Rating (1 to 5)"]];
var RICH_OK = { B: 1, STRONG: 1, I: 1, EM: 1, U: 1, BR: 1, UL: 1, OL: 1, LI: 1, P: 1, DIV: 1, H3: 1 };

// Keeps only simple formatting (bold, italic, underline, lists, a larger heading line). Everything else is removed, so typed or pasted text is safe to show.
function cleanRich(html) {
  var t = document.createElement("template");
  t.innerHTML = String(html || "");
  function walk(node) {
    var out = "";
    node.childNodes.forEach(function (c) {
      if (c.nodeType === 3) { out += esc(c.nodeValue); return; }
      if (c.nodeType !== 1) return;
      var tag = c.tagName;
      if (tag === "SCRIPT" || tag === "STYLE") return;
      var inner = walk(c);
      if (!RICH_OK[tag]) { out += inner; return; }
      var n = tag === "STRONG" ? "b" : tag === "EM" ? "i" : tag.toLowerCase();
      out += n === "br" ? "<br>" : "<" + n + ">" + inner + "</" + n + ">";
    });
    return out;
  }
  var r = walk(t.content);
  return richText(r) ? r : "";
}
// The plain text of formatted text.
function richText(html) {
  var t = document.createElement("template");
  t.innerHTML = String(html || "").replace(/<\/(li|p|div|h3|ul|ol)>|<br\s*\/?>/gi, " $&");
  return (t.content.textContent || "").replace(/ /g, " ").trim();
}
// Formatted text (or the plain fallback) ready to put in a page.
function richHtml(html, text) { return cleanRich(html) || esc(text || ""); }

// The questions of a poll (older polls get one question made from their options).
function pollQuestions(p) {
  if (p.questions && p.questions.length) {
    return p.questions.map(function (q, i) {
      return { id: q.id || ("q" + (i + 1)), type: q.type || "choice", html: q.html || "", text: q.text || richText(q.html), required: !!q.required, max: Number(q.max) || 0, options: (q.options || []).slice() };
    });
  }
  return [{ id: "q1", type: "choice", html: "", text: p.question || "", required: true, max: 0, options: (p.options || []).slice() }];
}

// All polls with their questions and results.
function pollsAll() {
  var votes = list("vote"), today = dayKey(new Date());
  return newest(list("poll")).map(function (r) {
    var p = r.v, id = Number(r.id), qs = pollQuestions(p).map(function (q) {
      q.opts = q.options.map(function (t) { return { t: t, votes: 0 }; });
      q.n = 0; q.sum = 0; q.counts = [0, 0, 0, 0, 0]; q.answers = [];
      return q;
    }), ballots = 0;
    votes.forEach(function (x) {
      if (Number(x.v.poll) !== id) return;
      ballots++;
      var a = x.v.answers || { q1: x.v.option };
      qs.forEach(function (q) {
        var v = a[q.id];
        if (v == null || v === "") return;
        if (q.type === "choice") { if (q.opts[v]) { q.opts[v].votes++; q.n++; } }
        else if (q.type === "multi") {
          var any = false;
          [].concat(v).forEach(function (i) { if (q.opts[i]) { q.opts[i].votes++; any = true; } });
          if (any) q.n++;
        } else if (q.type === "rating") {
          v = Number(v);
          if (v >= 1 && v <= 5) { q.counts[v - 1]++; q.sum += v; q.n++; }
        } else { q.answers.push({ unit: x.unit || "", text: String(v) }); q.n++; }
      });
    });
    var kind = p.kind || "poll";
    return {
      id: id, kind: kind, category: p.category || (kind === "election" ? "Governance & elections" : "General"), legacy: !(p.questions && p.questions.length), q: p.question || qs[0].text, titleHtml: p.titleHtml || "", descHtml: p.descHtml || "",
      open: !!p.open && !(p.closeKey && p.closeKey < today), closes: p.closes || "—", closeKey: p.closeKey || "",
      showResults: p.showResults || (kind === "election" ? "closed" : "vote"), ballots: ballots, questions: qs, options: qs[0].opts
    };
  });
}
// The signed-in unit's answers for a poll (one ballot per unit), or undefined when the unit has not voted.
function myVote(pollId) {
  var r = getRow("vote", myUnit() + "|" + pollId);
  return r ? (r.value.answers || { q1: Number(r.value.option) }) : undefined;
}
// Total votes of a poll's first question.
function pollTotal(p) { return p.options.reduce(function (s, o) { return s + o.votes; }, 0); }

// For an election position: "Elected", "Tie" or "" for each candidate (only once the election is closed).
function pollElected(p, q) {
  var seats = p.kind === "election" ? Math.max(1, q.max || 1) : 0;
  var sorted = q.opts.map(function (o) { return o.votes; }).sort(function (a, b) { return b - a; });
  var cut = seats ? (sorted[seats - 1] || 0) : 0, above = seats ? sorted.filter(function (v) { return v > cut; }).length : 0, atCut = seats ? sorted.filter(function (v) { return v === cut; }).length : 0;
  return q.opts.map(function (o) {
    if (!seats || p.open || o.votes <= 0) return "";
    if (o.votes > cut) return "Elected";
    return o.votes === cut ? (atCut > seats - above ? "Tie" : "Elected") : "";
  });
}
var POLL_TONES = ["yellow", "pink", "green", "blue"];
// Result bars for one question. mine = this unit's answers, admin = show written answers too.
function pollQuestionResults(p, q, mine, admin) {
  var picked = mine ? [].concat(mine[q.id] == null ? [] : mine[q.id]) : [];
  var mark = function (i) { return mine && picked.indexOf(i) >= 0; };
  if (q.type === "choice" || q.type === "multi") {
    var status = pollElected(p, q);
    return q.opts.map(function (o, i) {
      var pct = q.n ? Math.round(o.votes / q.n * 100) : 0, chip = status[i] ? ' <span class="chip ' + (status[i] === "Tie" ? "warn" : "good") + '">' + status[i] + "</span>" : "";
      return '<div class="pollbar ' + (mark(i) ? "mine" : "") + '"><div class="pollbar-top"><span class="pn">' + esc(o.t) + (mark(i) ? " · your vote" : "") + chip + '</span><span class="pv">' + o.votes + " vote" + (o.votes === 1 ? "" : "s") + "</span><b>" + pct + '%</b></div><div class="pbar-track"><i class="' + POLL_TONES[i % 4] + '" style="width:' + pct + '%"></i></div></div>';
    }).join("");
  }
  if (q.type === "rating") {
    var avg = q.n ? (q.sum / q.n).toFixed(1) : "—";
    return '<p class="pq-avg"><b>' + avg + '</b> out of 5 <span>· ' + q.n + " response" + (q.n === 1 ? "" : "s") + (mine && picked.length ? " · you gave " + picked[0] : "") + "</span></p>" +
      [5, 4, 3, 2, 1].map(function (s) {
        var c = q.counts[s - 1], pct = q.n ? Math.round(c / q.n * 100) : 0;
        return '<div class="pollbar ' + (mine && Number(picked[0]) === s ? "mine" : "") + '"><div class="pollbar-top"><span class="pn">' + s + " star" + (s === 1 ? "" : "s") + '</span><span class="pv">' + c + " response" + (c === 1 ? "" : "s") + "</span><b>" + pct + '%</b></div><div class="pbar-track"><i class="' + POLL_TONES[(5 - s) % 4] + '" style="width:' + pct + '%"></i></div></div>';
      }).join("");
  }
  if (!admin) return '<p class="hint" style="margin:0">' + q.n + " written answer" + (q.n === 1 ? "" : "s") + " received. Only the office reads them.</p>";
  return q.answers.length ? '<div class="pq-answers">' + q.answers.slice(0, 40).map(function (a) { return '<div class="pq-answer"><span>' + esc(a.text) + "</span><small>" + esc(a.unit) + "</small></div>"; }).join("") + (q.answers.length > 40 ? '<p class="hint" style="margin:6px 0 0">+ ' + (q.answers.length - 40) + " more in the Excel file.</p>" : "") + "</div>" : '<p class="hint" style="margin:0">No written answers yet.</p>';
}
// All the results of a poll, question by question.
function pollResultsHtml(p, mine, admin) {
  var blocks = p.questions.map(function (q, i) {
    var head = p.legacy ? "" : '<div class="pq-title"><span class="pq-no">' + (p.kind === "election" ? "" : (i + 1) + ".") + '</span><div>' + richHtml(q.html, q.text) + "</div></div>";
    return '<div class="pq-block' + (q.type === "text" || q.type === "para" ? " pq-wide" : "") + '">' + head + pollQuestionResults(p, q, mine, admin) + "</div>";
  }).join("");
  return p.legacy ? blocks : '<div class="pq-grid">' + blocks + "</div>";
}

// The ballot a resident fills in.
function pollBallotHtml(p) {
  var name = function (q) { return "pq-" + p.id + "-" + q.id; };
  var blocks = p.questions.map(function (q, i) {
    var hint = "", body = "";
    if (q.type === "choice") {
      body = '<div class="options">' + q.opts.map(function (o, k) { return '<label class="opt"><input type="radio" name="' + name(q) + '" value="' + k + '"><span>' + esc(o.t) + "</span></label>"; }).join("") + "</div>";
      if (p.kind === "election") hint = "Choose one candidate. Leave it blank to abstain.";
    } else if (q.type === "multi") {
      body = '<div class="options">' + q.opts.map(function (o, k) { return '<label class="opt"><input type="checkbox" name="' + name(q) + '" value="' + k + '"><span>' + esc(o.t) + "</span></label>"; }).join("") + "</div>";
      hint = q.max ? "Choose up to " + q.max + (p.kind === "election" ? ". Leave it blank to abstain." : ".") : "Choose all that apply.";
    } else if (q.type === "text") body = '<input class="pq-input" type="text" maxlength="200" name="' + name(q) + '" placeholder="Your answer">';
    else if (q.type === "para") body = '<textarea class="pq-input" rows="3" maxlength="1000" name="' + name(q) + '" placeholder="Your answer"></textarea>';
    else body = '<div class="rate-row">' + [1, 2, 3, 4, 5].map(function (s) { return '<label class="rate"><input type="radio" name="' + name(q) + '" value="' + s + '"><span>' + s + "</span></label>"; }).join("") + '</div><div class="rate-ends"><span>Not satisfied</span><span>Very satisfied</span></div>';
    var head = p.legacy ? "" : '<div class="pq-title"><span class="pq-no">' + (p.kind === "election" ? "" : (i + 1) + ".") + "</span><div>" + richHtml(q.html, q.text) + (q.required ? ' <span class="pq-req" title="Required">*</span>' : "") + "</div></div>";
    return '<div class="pq-block' + (q.type === "para" ? " pq-wide" : "") + '">' + head + (hint ? '<p class="hint" style="margin:0 0 8px">' + hint + "</p>" : "") + body + "</div>";
  }).join("");
  return p.legacy ? blocks : '<div class="pq-grid">' + blocks + "</div>";
}
// Reads the ballot of one poll from the page; returns {answers} or {error}.
function readBallot(p) {
  var answers = {}, error = "";
  p.questions.forEach(function (q, i) {
    var els = document.querySelectorAll('[name="pq-' + p.id + "-" + q.id + '"]'), v;
    if (q.type === "choice" || q.type === "rating") {
      var on = Array.prototype.filter.call(els, function (e) { return e.checked; })[0];
      if (on) v = Number(on.value);
    } else if (q.type === "multi") {
      var arr = Array.prototype.filter.call(els, function (e) { return e.checked; }).map(function (e) { return Number(e.value); });
      if (q.max && arr.length > q.max && !error) error = "Choose at most " + q.max + " for " + (p.kind === "election" ? "“" + q.text + "”" : "question " + (i + 1)) + ".";
      if (arr.length) v = arr;
    } else if (els[0] && els[0].value.trim()) v = els[0].value.trim();
    if (v != null) answers[q.id] = v;
    else if (q.required && !error) error = "Please answer question " + (i + 1) + ".";
  });
  if (!error && !Object.keys(answers).length) error = p.kind === "election" ? "Choose at least one candidate, or leave this election." : "Answer at least one question first.";
  return error ? { error: error } : { answers: answers };
}
// Saves my unit's ballot (one per unit, cannot be changed).
function castVote(id) {
  var p = pollsAll().filter(function (x) { return x.id === Number(id); })[0]; if (!p) return;
  var b = readBallot(p);
  if (b.error) return toast(b.error);
  var save = function () {
    return act(async function () {
      await put("vote", myUnit() + "|" + id, myUnit(), { poll: Number(id), answers: b.answers, at: new Date().toISOString() });
      toast(p.kind === "election" ? "Your ballot was recorded. Thank you for voting!" : "Your answers were recorded. Thank you!");
    });
  };
  if (p.kind === "election") confirmBox("Submit your ballot?", "Each unit has one ballot. It is secret and cannot be changed after you submit.", "Submit ballot", save);
  else save();
}

// The categories the office manages (General is always there). Starts with the built-in set.
function catList() {
  var l = (setting("poll_categories").list || POLL_CATEGORIES).slice();
  if (l.indexOf("General") < 0) l.unshift("General");
  return l;
}
// The categories you can choose: the managed list, plus any a poll already uses.
function pollCategories() {
  var out = catList();
  list("poll").forEach(function (r) { var c = r.v.category; if (c && out.indexOf(c) < 0) out.push(c); });
  return out;
}
// The category filter above the poll list (shared by both pages).
function pollCatFilterHtml(all) {
  var cur = state.pollCat || "all", used = pollCategories().filter(function (c) { return all.some(function (p) { return p.category === c; }); });
  if (used.length < 2) return "";
  return '<label class="poll-cat"><span>Category</span><select onchange="set({pollCat:this.value})"><option value="all">All categories (' + all.length + ")</option>" + used.map(function (c) {
    return '<option value="' + escAttr(c) + '"' + (cur === c ? " selected" : "") + ">" + esc(c) + " (" + all.filter(function (p) { return p.category === c; }).length + ")</option>";
  }).join("") + "</select></label>";
}
function pollCatMatch(p) { return !state.pollCat || state.pollCat === "all" || p.category === state.pollCat; }
// The little labels on a poll card: its kind and its category.
function pollChips(p) { return '<div class="poll-chips"><span class="chip ' + (p.kind === "election" ? "warn" : "info") + '">' + (p.kind === "election" ? "Election" : "Poll") + '</span><span class="chip cat">' + esc(p.category) + "</span></div>"; }
