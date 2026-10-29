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
  if (typeof navHidden === "function" && navHidden(key)) return "";
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

/* 4 ---------- Calendar + "coming up" (right column on Home) ----------
   One calendar for events, facility bookings, polls and elections (their closing day) and Philippine holidays.
   It is built from the saved records every time it is drawn, so a new event or poll shows up at once (also from
   another tab). A clock ticks every second and the calendar refreshes by itself every 30 seconds. */
var CAL_KINDS = { event: ["Event", "#2fa88a"], booking: ["Booking", "#e8914a"], poll: ["Poll", "#3b82d6"], election: ["Election", "#7b5bd6"], holiday: ["Holiday", "#d64a5a"] };
var calView = null;   // { y, m, sel }: the month on show and the picked day

// Easter Sunday of a year (the church holidays move with it).
function calEaster(y){
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3),
    h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451),
    mo = Math.floor((h + l - 7 * m + 114) / 31), da = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(y, mo - 1, da);
}
// Philippine regular and special non-working days of a year. Holidays set by proclamation each year (the Muslim holidays,
// the Chinese New Year) are not included because their dates are announced late.
function phHolidays(y){
  const k = (m, d) => y + "-" + String(m).padStart(2, "0") + "-" + String(d).padStart(2, "0"), out = [];
  const add = (key, title, regular) => out.push({ key: key, title: title, regular: regular });
  const easter = calEaster(y), off = n => { const d = new Date(easter); d.setDate(d.getDate() + n); return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); };
  let last = new Date(y, 8, 0); while (last.getDay() !== 1) last.setDate(last.getDate() - 1);   // last Monday of August
  add(k(1, 1), "New Year's Day", true); add(off(-3), "Maundy Thursday", true); add(off(-2), "Good Friday", true); add(off(-1), "Black Saturday", false);
  add(k(4, 9), "Araw ng Kagitingan", true); add(k(5, 1), "Labor Day", true); add(k(6, 12), "Independence Day", true); add(k(8, 21), "Ninoy Aquino Day", false);
  add(y + "-08-" + String(last.getDate()).padStart(2, "0"), "National Heroes Day", true); add(k(11, 1), "All Saints' Day", false); add(k(11, 2), "All Souls' Day", false);
  add(k(11, 30), "Bonifacio Day", true); add(k(12, 8), "Feast of the Immaculate Conception", false); add(k(12, 24), "Christmas Eve", false);
  add(k(12, 25), "Christmas Day", true); add(k(12, 30), "Rizal Day", true); add(k(12, 31), "New Year's Eve", false);
  return out;
}
// "6:00 PM" in a text -> minutes after midnight, or -1.
function calMinutes(t){
  t = String(t || "");
  let m = /(\d{1,2})(?::(\d{2}))?\s*(AM|PM)/i.exec(t);
  if (!m) return -1;
  const r = /^\s*(\d{1,2})(?::(\d{2}))?\s*[–-]\s*\d{1,2}(?::\d{2})?\s*(AM|PM)/i.exec(t);   // "12–2 PM": the start has no AM/PM of its own
  let h = Number(m[1]) % 12; if (/pm/i.test(m[3])) h += 12;
  if (r && m[1] !== r[1]) { const mer = /pm/i.test(r[3]) ? 12 : 0; h = (Number(r[1]) % 12) + mer; if (Number(r[1]) > 12 || (/pm/i.test(r[3]) && Number(r[1]) > Number(m[1]) && Number(r[1]) !== 12)) h = (Number(r[1]) % 12) + (Number(r[1]) > Number(m[1]) ? 0 : mer); m = r; }
  return h * 60 + Number(m[2] || 0);
}
// The time part of "Oct 30, 2026 · 6:00 PM" or "Oct 28, 2026, 2:00 PM – 4:00 PM".
function calTimeText(t){
  const r = String(t || "").replace(/^[A-Za-z]{3}[A-Za-z]*\.?\s+\d{1,2},?\s+\d{4}[\s,·]*/, "").trim();
  return calMinutes(r) >= 0 ? r : "";
}
function calPlain(html){ const d = document.createElement("div"); d.innerHTML = String(html || ""); return (d.textContent || "").trim(); }
// Everything that goes on the calendar, as { key, min, time, title, sub, kind }.
function calItems(){
  const out = [], isAdmin = typeof accountOfUnit === "function", me = isAdmin ? "" : myUnit();
  const push = (key, min, time, title, sub, kind) => { if (key) out.push({ key: key, min: min, time: time, title: title, sub: sub || "", kind: kind }); };
  try {
    list("event").forEach(r => {
      const e = r.v, d = parseShort(e.date); if (!d) return;
      const t = calTimeText(e.date);
      push(dayKey(d), calMinutes(t), t, e.title, e.place, "event");
    });
    list("booking").forEach(r => {
      const b = r.v; if (b.status === "Denied" || b.status === "Cancelled" || b.status === "Rejected") return;
      if (!isAdmin && b.unit !== me) return;
      const d = parseShort(b.when), key = b.day || (d ? dayKey(d) : ""), t = calTimeText(b.when);
      push(key, calMinutes(t), t, (b.place || "Facility") + " booking", (isAdmin ? (b.who || b.unit) + " · " : "") + b.status, "booking");
    });
    if (typeof pollsAll === "function") pollsAll().forEach(p => {
      if (!p.closeKey) return;
      const name = calPlain(p.titleHtml) || p.q || "Poll", el = p.kind === "election";
      push(p.closeKey, 24 * 60 - 1, "", (el ? "Election " : "Poll ") + (p.open ? "closes: " : "closed: ") + name, p.open ? "Voting ends at the end of this day" : "Voting has ended", el ? "election" : "poll");
    });
  } catch (e) { }
  const y = new Date().getFullYear();
  [y - 1, y, y + 1].forEach(yr => phHolidays(yr).forEach(h => push(h.key, -1, "", h.title, h.regular ? "Regular holiday" : "Special non-working day", "holiday")));
  return out;
}
function calSort(a, b){ return a.key < b.key ? -1 : a.key > b.key ? 1 : (a.min < 0 ? -1 : a.min) - (b.min < 0 ? -1 : b.min); }
function calDayLabel(key){
  const t = new Date(), today = dayKey(t), tm = new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1);
  if (key === today) return "Today";
  if (key === dayKey(tm)) return "Tomorrow";
  const p = key.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
}
function calClockHtml(){
  const n = new Date();
  return `<div class="cal-clock"><b id="calClock">${n.toLocaleTimeString("en-US")}</b><small id="calDate">${n.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" })}</small></div>`;
}
function calItemHtml(it, withDay){
  const k = CAL_KINDS[it.kind];
  return `<div class="cal-item"><i style="background:${k[1]}"></i><div><b>${esc(it.title)}</b><small>${withDay ? esc(calDayLabel(it.key)) + (it.time ? " · " + esc(it.time) : "") : (it.time ? esc(it.time) : it.kind === "holiday" ? "All day" : "")}${it.sub ? " · " + esc(it.sub) : ""}</small></div><span class="cal-tag" style="color:${k[1]}">${k[0]}</span></div>`;
}
// The month grid, the picked day and the legend.
function calendarHtml(){
  const now = new Date(), todayKey = dayKey(now);
  if (!calView) calView = { y: now.getFullYear(), m: now.getMonth(), sel: todayKey };
  const y = calView.y, m = calView.m, items = calItems(), by = {};
  items.forEach(i => { (by[i.key] = by[i.key] || []).push(i); });
  const offset = (new Date(y, m, 1).getDay() + 6) % 7, total = new Date(y, m + 1, 0).getDate();
  let cells = "";
  for (let i = 0; i < offset; i++) cells += "<span class='blank'></span>";
  for (let d = 1; d <= total; d++){
    const key = y + "-" + String(m + 1).padStart(2, "0") + "-" + String(d).padStart(2, "0"), its = by[key] || [], kinds = [];
    its.forEach(i => { if (kinds.indexOf(i.kind) < 0) kinds.push(i.kind); });
    cells += `<button type="button" class="cal-d ${key === todayKey ? "today" : ""} ${key === calView.sel ? "sel" : ""} ${its.some(i => i.kind === "holiday") ? "hol" : ""}" onclick="calPick('${key}')" title="${esc(its.map(i => i.title).join(" · "))}">${d}<em>${kinds.slice(0, 3).map(k => `<u style="background:${CAL_KINDS[k][1]}"></u>`).join("")}</em></button>`;
  }
  const sel = calView.sel, day = (by[sel] || []).slice().sort(calSort);
  const label = new Date(y, m, 1).toLocaleDateString("en-US", { month: "long", year: "numeric" });
  return `<div class="cal">${calClockHtml()}
    <div class="cal-title"><button type="button" class="cal-nav" onclick="calShift(-1)" aria-label="Previous month">&#8249;</button><span>${label}</span><button type="button" class="cal-nav" onclick="calShift(1)" aria-label="Next month">&#8250;</button><button type="button" class="cal-today" onclick="calToday()">Today</button></div>
    <div class="cal-week">${["Mo","Tu","We","Th","Fr","Sa","Su"].map(d => `<span>${d}</span>`).join("")}</div>
    <div class="cal-days">${cells}</div>
    <div class="cal-legend">${Object.keys(CAL_KINDS).map(k => `<span><u style="background:${CAL_KINDS[k][1]}"></u>${CAL_KINDS[k][0]}</span>`).join("")}</div>
    <div class="cal-day"><h3>${esc(calDayLabel(sel) === "Today" || calDayLabel(sel) === "Tomorrow" ? calDayLabel(sel) + " · " + new Date(+sel.slice(0, 4), +sel.slice(5, 7) - 1, +sel.slice(8)).toLocaleDateString("en-US", { month: "short", day: "numeric" }) : calDayLabel(sel))}</h3>${day.length ? day.map(i => calItemHtml(i, false)).join("") : '<p class="cal-none">Nothing scheduled on this day.</p>'}</div></div>`;
}
// What is next: the coming events, bookings and polls, with the next holiday.
function comingUpHtml(){
  const now = new Date(), today = dayKey(now), mins = now.getHours() * 60 + now.getMinutes();
  const all = calItems().filter(i => i.key > today || (i.key === today && (i.min < 0 || i.min >= mins - 60))).sort(calSort);
  const hol = all.filter(i => i.kind === "holiday").slice(0, 1), rest = all.filter(i => i.kind !== "holiday").slice(0, 4);
  const show = rest.concat(hol).sort(calSort).slice(0, 5);
  return `<h2 class="tl-head">Coming up</h2><div class="timeline">${show.length ? show.map((it, i) => {
    const k = CAL_KINDS[it.kind];
    return `<div class="tl-card ${i === 0 ? "next" : ""}"><b>${esc(it.title)}</b><small>${k[0]}${it.sub ? " · " + esc(it.sub) : ""}</small><em>${esc(calDayLabel(it.key))}${it.time ? " · " + esc(it.time) : ""}</em></div>`;
  }).join("") : '<div class="tl-card"><b>Nothing coming up</b><small>New events, bookings and polls appear here.</small></div>'}</div>`;
}
function calInner(buttonText, buttonView){
  return `${calendarHtml()}<button class="btn-dark" onclick="set({view:'${buttonView}'})">${buttonText}</button>${comingUpHtml()}`;
}
var calAsideArgs = ["", ""];
// The right column of the Home pages. (items is no longer needed: the calendar reads the records itself.)
function asideHtml(items, buttonText, buttonView){
  calAsideArgs = [buttonText, buttonView];
  return `<aside class="side-col" id="calAside">${calInner(buttonText, buttonView)}</aside>`;
}
function refreshCal(){
  const el = document.getElementById("calAside"); if (!el) return;
  el.classList.add("cal-live");   // the entrance animation plays once; redrawing must not blank the calendar again
  el.innerHTML = calInner(calAsideArgs[0], calAsideArgs[1]);
}
function calPick(key){ if (calView) calView.sel = key; refreshCal(); }
function calShift(n){
  if (!calView) return;
  const d = new Date(calView.y, calView.m + n, 1); calView.y = d.getFullYear(); calView.m = d.getMonth();
  const t = new Date(); calView.sel = (calView.y === t.getFullYear() && calView.m === t.getMonth()) ? dayKey(t) : calView.y + "-" + String(calView.m + 1).padStart(2, "0") + "-01";
  refreshCal();
}
function calToday(){ const t = new Date(); calView = { y: t.getFullYear(), m: t.getMonth(), sel: dayKey(t) }; refreshCal(); }
// The clock ticks every second; the whole calendar is redrawn every 30 seconds (and when the day changes).
if (!window.__calTick) {
  window.__calTick = 1;
  let ticks = 0, lastDay = new Date().getDate();
  setInterval(function(){
    const c = document.getElementById("calClock"); if (!c) return;
    const n = new Date(); c.textContent = n.toLocaleTimeString("en-US");
    const dt = document.getElementById("calDate"); if (dt) dt.textContent = n.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" });
    ticks++;
    if (n.getDate() !== lastDay) { lastDay = n.getDate(); calView = null; }
    if (ticks % 30 === 0 || lastDay !== n.getDate()) refreshCal();
  }, 1000);
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
function toast(message, ms){
  let box = document.getElementById("toasts");
  if (!box){ box = document.createElement("div"); box.id = "toasts"; document.body.appendChild(box); }
  // At most 3 messages at a time, so they never pile up over the page
  while (box.children.length >= 3) box.firstChild.remove();
  const el = document.createElement("div");
  el.className = "toast"; el.textContent = message;
  box.appendChild(el);
  setTimeout(() => { el.classList.add("out"); setTimeout(() => el.remove(), 350); }, ms || 3200);
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

/* 8 ---------- Notification bell, Facebook style (each page defines bellItems()) ----------
   Every notification is read or unread on its own (a blue dot, bold text), shows how long ago it appeared, and opens the page it is about.
   There are two tabs (All, Unread) and "Mark all as read". The badge counts what is new since the bell was last opened.
   The read marks live in this browser, one set for each person (the administrator, or each unit). */
function bellScope(){ return typeof myUnit === "function" && myUnit() ? "r-" + myUnit() : "admin"; }
function bellStore(){
  try { const s = JSON.parse(localStorage.getItem("rh_bell_" + bellScope()) || "null"); if (s && s.read && s.seen) return s; } catch (e) { /* storage blocked */ }
  return { read:{}, seen:{}, openedAt:0 };
}
function bellSave(s){ try { localStorage.setItem("rh_bell_" + bellScope(), JSON.stringify(s)); } catch (e) { /* storage blocked */ } }
// A short code for one notification: the same words always give the same code, so "read" is remembered.
function bellKey(n){
  const t = String(n.t).replace(/<[^>]+>/g, "") + "|" + (n.v || "");
  let h = 5381; for (let i = 0; i < t.length; i++) h = ((h << 5) + h + t.charCodeAt(i)) | 0;
  return (h >>> 0).toString(36);
}
// "Just now", "5m", "3h", "2d", "1w".
function bellAgo(ts){
  const s = Math.max(0, (Date.now() - ts) / 1000);
  if (s < 60) return "Just now";
  const m = Math.floor(s / 60); if (m < 60) return m + "m";
  const h = Math.floor(m / 60); if (h < 24) return h + "h";
  const d = Math.floor(h / 24); return d < 7 ? d + "d" : Math.floor(d / 7) + "w";
}
// The notifications with their code, when they first appeared and whether they are unread. Newest first.
function bellList(){
  const items = bellItems(), st = bellStore(), now = Date.now(); let dirty = false;
  items.forEach(n => {
    n.key = bellKey(n);
    if (!st.seen[n.key]) { st.seen[n.key] = now; dirty = true; }
    n.at = st.seen[n.key]; n.unread = !st.read[n.key];
  });
  Object.keys(st.seen).forEach(k => { if (now - st.seen[k] > 45 * 86400000) { delete st.seen[k]; delete st.read[k]; dirty = true; } });
  if (dirty) bellSave(st);
  return items.sort((a, b) => b.at - a.at);
}
function bellToggle(){
  if (!state.bellOpen) { const st = bellStore(); st.openedAt = Date.now(); bellSave(st); }
  set({ bellOpen: !state.bellOpen });
}
// Marks one notification as read, closes the bell and opens what it is about.
function bellGo(key){
  const n = bellList().filter(x => x.key === key)[0]; if (!n) return;
  const st = bellStore(); st.read[key] = Date.now(); bellSave(st);
  if (n.pay) { bellPay(String(n.pay).replace(/'/g, "")); return; }
  set({ view: n.v, bellOpen: false, bellSeen: true });
}
function bellReadAll(){ const st = bellStore(), now = Date.now(); bellList().forEach(n => { st.read[n.key] = now; }); st.openedAt = now; bellSave(st); set({ bellSeen: true }); }
function bellHtml(){
  const all = bellList(), st = bellStore(), tab = state.bellTab === "unread" ? "unread" : "all";
  const unread = all.filter(n => n.unread), fresh = unread.filter(n => n.at > (st.openedAt || 0)).length;
  const shown = tab === "unread" ? unread : all;
  const row = n => `<button class="bn ${n.tone || "info"}${n.unread ? " unread" : ""}" onclick="bellGo('${n.key}')"><span class="bn-ico">${icon(NAV_ICONS[n.v] ? n.v : "bell")}</span><span class="bn-main"><span class="bn-t">${n.t}</span><small class="bn-time">${bellAgo(n.at)}${n.s && n.s !== "Open" ? " · " + n.s : ""}</small></span>${n.unread ? '<i class="bn-dot" aria-label="Unread"></i>' : ""}</button>`;
  const news = shown.filter(n => n.unread), older = shown.filter(n => !n.unread);
  const body = (news.length ? '<div class="bn-sec">New</div>' + news.map(row).join("") : "") + (older.length ? '<div class="bn-sec">Earlier</div>' + older.map(row).join("") : "") ||
    `<p class="bn-empty">${tab === "unread" ? "No unread notifications." : "You're all caught up."}</p>`;
  return `<div class="bell-wrap">
    <button class="icon-btn" title="Notifications" aria-label="Notifications${fresh ? ", " + fresh + " new" : ""}" onclick="bellToggle()">${icon("bell")}${fresh && !state.bellOpen ? `<span class="badge">${fresh > 9 ? "9+" : fresh}</span>` : ""}</button>
    ${state.bellOpen ? `<div class="bell-pop bn-pop"><div class="bn-head"><b>Notifications</b><button onclick="bellReadAll()"${unread.length ? "" : " disabled"}>Mark all as read</button></div>
      <div class="bn-tabs"><button class="${tab === "all" ? "on" : ""}" onclick="set({bellTab:'all'})">All</button><button class="${tab === "unread" ? "on" : ""}" onclick="set({bellTab:'unread'})">Unread${unread.length ? " (" + unread.length + ")" : ""}</button></div>
      <div class="bn-list">${body}</div></div>` : ""}
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

/* ---------- Phone tables: each row becomes a small card, so nobody has to scroll sideways ----------
   The labels come from the table's own header. The look is in history.css (screens up to 640px wide). */
(function () {
  var queued = false;
  function label() {
    queued = false;
    document.querySelectorAll("table:not(.rt):not(.psz):not(.imp-prev)").forEach(function (t) {
      var ths = t.querySelectorAll("thead th");
      if (!ths.length) return;
      var names = Array.prototype.map.call(ths, function (th) { return (th.textContent || "").replace(/\s+/g, " ").trim(); });
      t.querySelectorAll("tbody tr").forEach(function (tr) {
        var i = 0;
        Array.prototype.forEach.call(tr.children, function (td) {
          if (td.tagName !== "TD") return;
          td.setAttribute("data-label", names[i] || "");
          i += td.colSpan || 1;
        });
      });
      t.classList.add("rt");
    });
  }
  function queue() { if (!queued) { queued = true; (window.requestAnimationFrame || setTimeout)(function () { label(); mobNav(); }); } }
  function start() { label(); mobNav(); try { new MutationObserver(queue).observe(document.body, { childList: true, subtree: true }); } catch (e) { /* old browser: tables simply scroll sideways */ } }
  if (document.body) start(); else document.addEventListener("DOMContentLoaded", start);
})();

/* ---------- Phone menu: a bar at the bottom with the main pages and a "More" button ----------
   It is built from the side menu that is already on the page, so it always matches it. Phones only (see history.css). */
function mobNav() {
  var side = document.querySelector(".side");
  var bar = document.getElementById("mnav");
  if (!side || !side.querySelector("nav button")) { if (bar) bar.remove(); return; }
  var admin = /admin/i.test(location.pathname);
  var main = admin ? ["home", "units", "fin", "req"] : ["home", "book", "dues", "parking"];
  var groups = [], all = {}, active = "";
  var label = "";
  Array.prototype.forEach.call(side.children, function (el) {
    if (el.classList.contains("side-label")) { label = (el.textContent || "").trim(); return; }
    if (el.tagName !== "NAV") return;
    var items = [];
    Array.prototype.forEach.call(el.querySelectorAll("button"), function (b) {
      var m = /view:\s*'([\w-]+)'/.exec(b.getAttribute("onclick") || ""); if (!m) return;
      var sv = b.querySelector("svg"), sp = b.querySelector("span");
      var it = { key: m[1], text: sp ? sp.textContent.trim() : m[1], svg: sv ? sv.outerHTML : "", on: b.classList.contains("active") };
      if (it.on) active = it.key;
      all[it.key] = it; items.push(it);
    });
    groups.push({ label: label, items: items });
  });
  var sig = active + "|" + Object.keys(all).join(",");
  if (bar && bar.getAttribute("data-sig") === sig) return;
  if (!bar) { bar = document.createElement("nav"); bar.id = "mnav"; bar.setAttribute("aria-label", "Main pages"); document.body.appendChild(bar); }
  bar.setAttribute("data-sig", sig);
  var shortName = { home: "Home", book: "Book" };
  var btn = function (it) { return '<button class="' + (it.on ? "active" : "") + '" onclick="set({view:\'' + it.key + '\',bellOpen:false});window.scrollTo(0,0)">' + it.svg + "<span>" + (shortName[it.key] || it.text).replace(/</g, "&lt;") + "</span></button>"; };
  var inMain = main.indexOf(active) > -1;
  bar.innerHTML = main.filter(function (k) { return all[k]; }).map(function (k) { return btn(all[k]); }).join("") +
    '<button class="' + (inMain ? "" : "active") + '" onclick="mobMore()"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/></svg><span>More</span></button>';
  window.__mobGroups = groups;
}
// Opens the list of every page.
function mobMore() {
  var html = "<h2>All pages</h2>" + (window.__mobGroups || []).map(function (g) {
    return (g.label ? '<div class="mn-label">' + g.label.replace(/</g, "&lt;") + "</div>" : "") + '<div class="mn-grid">' + g.items.map(function (it) {
      return '<button class="mn-tile' + (it.on ? " on" : "") + '" onclick="closeModal();set({view:\'' + it.key + '\',bellOpen:false});window.scrollTo(0,0)">' + it.svg + "<span>" + it.text.replace(/</g, "&lt;") + "</span></button>";
    }).join("") + "</div>";
  }).join("");
  openModal(html);
}
// The bar hides while a field is being typed in, so the keyboard never covers it.
document.addEventListener("focusin", function (e) { if (/^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) document.body.classList.add("kb"); });
document.addEventListener("focusout", function () { document.body.classList.remove("kb"); });

/* ---------- Pages: a long list is cut into pages so the screen does not grow forever ---------- */
function pageCount(total, per){ return Math.max(1, Math.ceil(total / per)); }
function pageNow(total, per, key){ return Math.min(Math.max(0, Number(state[key]) || 0), pageCount(total, per) - 1); }
function pageSlice(list, per, key){ const p = pageNow(list.length, per, key); return list.slice(p * per, p * per + per); }
// Previous / Next buttons with "Page 2 of 4". key is the state name that holds the page number.
function pagerPN(total, per, key){
  const pages = pageCount(total, per), p = pageNow(total, per, key);
  if (pages <= 1) return "";
  const btn = (n, label, off) => `<button type="button" class="btn" ${off ? "disabled" : ""} onclick="set({${key}:${n}})">${label}</button>`;
  return `<div class="pager">${btn(p - 1, "\u2039 Previous", p === 0)}<span>Page <b>${p + 1}</b> of ${pages} <small>(${total} in all)</small></span>${btn(p + 1, "Next \u203a", p >= pages - 1)}</div>`;
}
/* Complaints: how many open complaints one unit may have at the same time (the office can change it in Settings). */
function grLimit(){ const n = Math.floor(Number(setting("complaint_limit").n)); return n >= 1 ? Math.min(n, 10) : 1; }
