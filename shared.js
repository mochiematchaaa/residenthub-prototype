/* ==========================================================================
   shared.js — small pieces used by BOTH dashboards (admin.html and resident.html)
   Each page loads this file first, then its own script.
   Sections: 1 icons  2 helpers  3 cards + lists  4 calendar  5 charts
             6 toast + popup  7 search  8 notification bell  9 polls
   ========================================================================== */

/* 1 ---------- Icons (simple line icons, 24x24) ---------- */
const NAV_ICONS = {
  home:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  units:'<path d="M3 21V10l9-6 9 6v11"/><path d="M9 21v-6h6v6"/>',
  fac:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/>',
  book:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18"/>',
  ann:'<path d="M4 10v4a1 1 0 0 0 1 1h3l6 4V5L8 9H5a1 1 0 0 0-1 1z"/><path d="M18 9a4 4 0 0 1 0 6"/>',
  fin:'<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 11h18M7 15h3"/>',
  dues:'<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 11h18M7 15h3"/>',
  req:'<path d="M14.5 6.5a4 4 0 0 0 4.9 4.9L10 20.8a2.1 2.1 0 0 1-3-3L16.5 8.4"/><path d="M14.5 6.5L17 4l3 3-2.5 2.5"/>',
  gr:'<path d="M4 5h16v11H9l-5 4z"/><path d="M8 9h8M8 12h5"/>',
  rentals:'<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M10 21v-4h4v4"/>',
  rental:'<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M10 21v-4h4v4"/>',
  manage:'<rect x="5" y="11" width="14" height="10" rx="3"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  history:'<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.4-3.2 2.6-5 5.5-5"/><circle cx="17" cy="16" r="4.5"/><path d="M17 13.6V16l1.7 1"/>',
  res:'<rect x="5" y="3" width="14" height="18" rx="3"/><path d="M9 8h6M9 12h6M9 16h3"/>',
  docs:'<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>',
  settings:'<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
  polls:'<rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 9l2 2 3-4M8 16h8"/>',
  reports:'<path d="M4 4v16h16"/><path d="M8 15l3-4 3 2 5-6"/>',
  parking:'<rect x="4" y="3" width="16" height="18" rx="4"/><path d="M10 17V8h3a2.5 2.5 0 0 1 0 5h-3"/>',
  log:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  events:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4M16 3v4M3 10h18M9 15l2 2 4-4"/>',
  directory:'<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  logout:'<path d="M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3"/><path d="M16 8l4 4-4 4M20 12H9"/>',
  bell:'<path d="M6 9a6 6 0 0 1 12 0c0 6 2 7 2 7H4s2-1 2-7z"/><path d="M10 20a2 2 0 0 0 4 0"/>',
  moon:'<path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5"/>'
};
// Returns the SVG icon with this name (see the icons table above).
function icon(name){
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${NAV_ICONS[name]||""}</svg>`;
}

/* 2 ---------- Small helpers ---------- */
function peso(n){ return "₱" + n.toLocaleString("en-US",{minimumFractionDigits:2,maximumFractionDigits:2}); }
// Changes the page state and redraws. Buttons use it, e.g. set({view:'units'}).
function set(patch){ Object.assign(state, patch); render(); }
// Makes text safe to put inside an HTML attribute.
function escAttr(s){ return String(s==null?"":s).replace(/'/g,"&#39;").replace(/"/g,"&quot;"); }
// Switches between light and dark mode.
function toggleDarkMode(){ set({ darkMode: !state.darkMode }); }
// 'Good morning / afternoon / evening'.
function greeting(){
  const h = new Date().getHours();
  return tr(h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening");
}
// Today's date as text, e.g. 'Friday, October 16'.
function todayLabel(){
  return new Date().toLocaleDateString(curLang()==="fil"?"fil-PH":"en-US",{weekday:"long",month:"long",day:"numeric"});
}
// One button in the side menu.
function navBtn(key,label,tag){
  return `<button class="${state.view===key?"active":""}" onclick="set({view:'${key}',bellOpen:false})">${icon(key)}<span>${tr(label)}</span>${tag?`<em class="nav-tag">${tag}</em>`:""}</button>`;
}
/* Download a table as a .csv file (opens directly in Excel) */
function exportCSV(filename, headers, rows){
  const esc = v => { const s = String(v==null?"":v); return /[",\n]/.test(s) ? '"'+s.replace(/"/g,'""')+'"' : s; };
  const lines = [headers.map(esc).join(","), ...rows.map(r => r.map(esc).join(","))];
  const blob = new Blob(["﻿" + lines.join("\r\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename; document.body.appendChild(a); a.click();
  document.body.removeChild(a); URL.revokeObjectURL(url);
}

/* 3 ---------- Coloured summary cards and list rows ---------- */
const DECO = {
  cross:'<svg class="deco" viewBox="0 0 100 100"><path d="M38 6h24v32h32v24H62v32H38V62H6V38h32z"/></svg>',
  heart:'<svg class="deco" viewBox="0 0 100 100"><path d="M50 90C8 60 4 28 27 17c12-5 23 3 23 11 0-8 11-16 23-11 23 11 19 43-23 73z"/></svg>',
  triangle:'<svg class="deco" viewBox="0 0 100 100"><path d="M4 10h92L50 94z"/></svg>',
  burst:'<svg class="deco" viewBox="0 0 100 100"><polygon points="50,2 61,25 85,15 77,40 98,50 77,60 85,85 61,75 50,98 39,75 15,85 23,60 2,50 23,40 15,15 39,25"/></svg>'
};
// stats: [[value, label, viewToOpen (optional)], ...]
function summaryCard(tone, title, stats, deco, extra){
  const nums = stats.map(s => {
    const inner = `<b>${s[0]}</b><span>${s[1]}</span>`;
    return s[2] ? `<button onclick="set({view:'${s[2]}'})">${inner}</button>` : `<div>${inner}</div>`;
  }).join("");
  return `<div class="sc ${tone}"><h3>${title}</h3>${extra||""}<div class="sc-nums">${nums}</div></div>`;
}
/* One row in a list: round letter, title, small line, coloured pill on the right */
function listRow(tone, title, sub, pill, view, selected){
  const tag = view ? "button" : "div";
  const click = view ? ` onclick="set({view:'${view}'})"` : "";
  return `<${tag} class="lrow ${selected?"sel":""}"${click}><span class="lav t${tone}">${String(title).charAt(0)}</span><span class="lmain"><b>${title}</b><small>${sub}</small></span><span class="lpill t${tone}">${pill}</span></${tag}>`;
}
function pageTabs(tabs, current, key){   // small pill buttons that switch a section: [[value,label],...]
  return `<div class="filters">${tabs.map(t=>`<button class="${current===t[0]?"active":""}" onclick="set({${key}:'${t[0]}'})">${t[1]}</button>`).join("")}</div>`;
}

/* 4 ---------- Calendar + "coming up" (right column on Home) ---------- */
function eventDays(texts){
  const month = new Date().toLocaleDateString("en-US",{month:"short"});
  return texts.map(t => {
    const m = String(t).match(/^([A-Za-z]{3})[a-z]* (\d{1,2})/);
    return m && m[1] === month ? Number(m[2]) : 0;
  }).filter(Boolean);
}
// Small month calendar; markDays are the days with events.
function calendarHtml(markDays){
  const now = new Date(), y = now.getFullYear(), m = now.getMonth();
  const offset = (new Date(y, m, 1).getDay() + 6) % 7;            // week starts on Monday
  const total = new Date(y, m + 1, 0).getDate();
  let cells = "";
  for (let i = 0; i < offset; i++) cells += "<span></span>";
  for (let d = 1; d <= total; d++){
    cells += `<span class="${d===now.getDate()?"today":""} ${markDays.indexOf(d)>-1?"mark":""}">${d}</span>`;
  }
  const label = now.toLocaleDateString("en-US",{month:"long",year:"numeric"});
  return `<div class="cal"><div class="cal-title"><span>${label}</span></div>
    <div class="cal-week">${["Mo","Tu","We","Th","Fr","Sa","Su"].map(d=>`<span>${d}</span>`).join("")}</div>
    <div class="cal-days">${cells}</div></div>`;
}
// items: [[title, place, when], ...]
function asideHtml(items, buttonText, buttonView){
  return `<aside class="side-col">
    ${calendarHtml(eventDays(items.map(i=>i[2])))}
    <button class="btn-dark" onclick="set({view:'${buttonView}'})">${buttonText}</button>
    <h2 class="tl-head">Coming up</h2>
    <div class="timeline">
      ${items.map((it,i)=>`<div class="tl-card ${i===0?"next":""}"><b>${it[0]}</b><small>${it[1]}</small><em>${it[2]}</em></div>`).join("")}
    </div>
  </aside>`;
}

/* 5 ---------- Charts (plain HTML + CSS, no library) ---------- */
// items: [{label, value, tone}]  tone = yellow | pink | green | blue
function barChart(items, unit, suffix){
  const max = Math.max.apply(null, items.map(i=>i.value)) || 1;
  return `<div class="vbars">${items.map(i=>`<div class="vbar"><div class="vb-track"><span class="vb-val">${unit||""}${i.value.toLocaleString("en-US")}${suffix||""}</span><i class="${i.tone||"yellow"}" style="height:${Math.max(4, i.value/max*78)}%"></i></div><span class="vb-lab">${i.label}</span></div>`).join("")}</div>`;
}
// parts: [{label, value, tone}]
function donutChart(parts, centerText, centerLabel){
  const total = parts.reduce((s,p)=>s+p.value,0) || 1;
  const colour = { yellow:"var(--yellow)", pink:"var(--pink)", green:"var(--green)", blue:"var(--blue)", ink:"var(--ink)" };
  let at = 0;
  const stops = parts.map(p => { const from = at; at += p.value/total*100; return `${colour[p.tone]} ${from}% ${at}%`; }).join(",");
  return `<div class="donut-wrap"><div class="donut" style="background:conic-gradient(${stops})"><div><b>${centerText}</b><small>${centerLabel||""}</small></div></div>
    <ul class="legend">${parts.map(p=>`<li><i class="${p.tone}"></i>${p.label}<b>${p.value}</b></li>`).join("")}</ul></div>`;
}
// A labeled progress bar.
function progressBar(label, value, total, tone){
  const pct = total ? Math.round(value/total*100) : 0;
  return `<div class="pbar"><div class="pbar-top"><span>${label}</span><b>${value} / ${total} · ${pct}%</b></div><div class="pbar-track"><i class="${tone||"green"}" style="width:${pct}%"></i></div></div>`;
}

/* 6 ---------- Toast message + popup window ---------- */
function toast(message){
  let box = document.getElementById("toasts");
  if (!box){ box = document.createElement("div"); box.id = "toasts"; document.body.appendChild(box); }
  const el = document.createElement("div");
  el.className = "toast"; el.textContent = message;
  box.appendChild(el);
  setTimeout(() => { el.classList.add("out"); setTimeout(() => el.remove(), 350); }, 3200);
}
// Shows a popup window with the given HTML.
function openModal(html){
  closeModal();
  const back = document.createElement("div");
  back.id = "modal"; back.className = "modal-back";
  back.onclick = closeModal;
  back.innerHTML = `<div class="modal" role="dialog" onclick="event.stopPropagation()"><button class="modal-x" onclick="closeModal()" aria-label="Close">×</button>${html}</div>`;
  document.body.appendChild(back);
}
// Closes the popup.
function closeModal(){ const m = document.getElementById("modal"); if (m) m.remove(); }
document.addEventListener("keydown", function(e){ if (e.key === "Escape"){ closeModal(); if (state.bellOpen) set({ bellOpen:false }); } });

/* 7 ---------- Search box (each page defines searchIndex() for what can be found) ---------- */
function searchBox(placeholder){
  return `<div class="search"><span class="search-ic">${icon("search")}</span>
    <input id="qBox" type="search" autocomplete="off" placeholder="${placeholder}" oninput="runSearch(this.value)" onfocus="runSearch(this.value)">
    <div id="qOut" class="search-out" hidden></div></div>`;
}
// Fills the search results while the user types.
function runSearch(text){
  const out = document.getElementById("qOut");
  const q = text.trim().toLowerCase();
  if (!out) return;
  if (!q){ out.hidden = true; return; }
  const hits = searchIndex().filter(i => (i.t + " " + i.s).toLowerCase().indexOf(q) >= 0).slice(0, 7);
  out.innerHTML = hits.length
    ? hits.map(h => `<button onclick="set({view:'${h.v}',bellOpen:false})"><b>${h.t}</b><small>${h.s}</small><em>${h.tag}</em></button>`).join("")
    : `<p>No results for “${escAttr(text)}”.</p>`;
  out.hidden = false;
}
document.addEventListener("click", function(e){
  const out = document.getElementById("qOut");
  if (out && !e.target.closest(".search")) out.hidden = true;
  if (state.bellOpen && !e.target.closest(".bell-wrap")) set({ bellOpen:false });
});

/* 8 ---------- Notification bell (each page defines bellItems()) ---------- */
function bellHtml(){
  const items = bellItems();
  const unread = state.bellSeen ? 0 : items.length;
  return `<div class="bell-wrap">
    <button class="icon-btn" title="Notifications" aria-label="Notifications" onclick="set({bellOpen:!state.bellOpen})">${icon("bell")}${unread?`<span class="badge">${unread}</span>`:""}</button>
    ${state.bellOpen ? `<div class="bell-pop"><div class="bell-head"><b>Notifications</b><button onclick="set({bellSeen:true})">Mark all read</button></div>
      ${items.length ? items.map(n=>`<button class="bell-item" onclick="set({view:'${n.v}',bellOpen:false,bellSeen:true})"><b>${n.t}</b><small>${n.s}</small></button>`).join("") : "<p>You're all caught up.</p>"}</div>` : ""}
  </div>`;
}

/* 9 ---------- Polls (used by both: admin creates and reads, residents vote) ---------- */
function samplePolls(){
  return [
    { id:1, q:"Repaint the ground-floor lobby this year?", open:true, closes:"Oct 20, 2026", options:[{t:"Yes, repaint now",votes:31},{t:"Wait until next year",votes:9},{t:"No repaint needed",votes:4}] },
    { id:2, q:"Which weekday should the pool be closed for cleaning?", open:true, closes:"Oct 25, 2026", options:[{t:"Monday",votes:18},{t:"Wednesday",votes:7},{t:"Thursday",votes:12}] },
    { id:3, q:"Add a second coffee-lounge hour in the afternoon?", open:false, closes:"Sep 15, 2026", options:[{t:"Yes",votes:38},{t:"No",votes:6}] }
  ];
}
// Total votes of a poll.
function pollTotal(p){ return p.options.reduce((s,o)=>s+o.votes,0); }
// Draws the result bars of a poll.
function pollBars(p, mine){
  const total = pollTotal(p) || 1;
  return p.options.map((o,i)=>{
    const pct = Math.round(o.votes/total*100);
    return `<div class="pollbar ${mine===i?"mine":""}"><div class="pollbar-top"><span>${o.t}${mine===i?" · your vote":""}</span><b>${pct}%</b></div><div class="pbar-track"><i class="${["yellow","pink","green","blue"][i%4]}" style="width:${pct}%"></i></div><small>${o.votes} vote${o.votes===1?"":"s"}</small></div>`;
  }).join("");
}


/* ---------- 10. Smooth page changes ---------- */
// Keeps the sidebar on screen and only swaps the page area, so clicking a menu item feels like a slide, not a reload.
function mountApp(app, html){
  const tpl = document.createElement("template");
  tpl.innerHTML = html.trim();
  const next = tpl.content.firstElementChild;
  const cur = app.firstElementChild;
  if (!cur || !next || !cur.classList.contains("shell") || !next.classList.contains("shell")){ app.innerHTML = html; return; }
  const curSide = cur.querySelector(".side"), nextSide = next.querySelector(".side");
  const strip = el => el.outerHTML.replace(/\sclass="[^"]*"/g, "");
  if (curSide && nextSide){
    if (strip(curSide) === strip(nextSide)){
      const a = curSide.querySelectorAll("*"), b = nextSide.querySelectorAll("*");
      b.forEach((n, i) => { if (a[i].className !== n.className) a[i].className = n.className; });
    } else curSide.replaceWith(nextSide);
  }
  const curMain = cur.querySelector("main"), nextMain = next.querySelector("main");
  if (curMain && nextMain) curMain.replaceWith(nextMain); else app.innerHTML = html;
}
