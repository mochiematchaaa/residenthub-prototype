/* ==========================================================================
   account.js — Account & security, shared by the admin and resident dashboards.
   One place for: all settings (overview), manage profile, password manager,
   device management and language.
   Language: tr("English text") translates the menus and page titles;
   L("English", "Filipino") is used for text written in this file.
   ========================================================================== */

/* ---------- language ---------- */
var ACCT_LANGS = [
  ["en", "English", "English", "Good morning, welcome back"],
  ["fil", "Filipino", "Wikang Filipino", "Magandang umaga, maligayang pagbabalik"]
];
function curLang() { try { return localStorage.getItem("rh_lang") === "fil" ? "fil" : "en"; } catch (e) { return "en"; } }
// Picks the English or the Filipino text for the language chosen in Settings.
function L(en, fil) { return curLang() === "fil" && fil ? fil : en; }
var LANG_FIL = {
  "General": "Pangkalahatan", "Tools": "Mga kasangkapan", "Admin": "Admin", "Community": "Komunidad", "Account": "Account",
  "Dashboard": "Dashboard", "Units": "Mga unit", "Facility": "Pasilidad", "Announcements": "Mga anunsyo", "Polls": "Mga botohan",
  "Finance": "Pananalapi", "Expenses": "Mga gastos", "Resident profiles": "Profile ng mga residente", "Reports": "Mga ulat",
  "Complaints": "Mga reklamo", "Parking": "Paradahan", "Unit status": "Katayuan ng unit", "Activity log": "Talaan ng gawain",
  "Settings": "Mga setting", "Maintenance": "Pagpapanatili", "Log out": "Mag-log out", "Home": "Home", "Book a facility": "Mag-book ng pasilidad",
  "Reservations": "Mga reserbasyon", "Dues": "Mga bayarin", "Events": "Mga kaganapan", "Directory": "Direktoryo", "Documents": "Mga dokumento",
  "My reservations": "Aking mga reserbasyon", "Community events": "Mga kaganapan sa komunidad", "Complaints & documents": "Mga reklamo at dokumento",
  "Units & residents": "Mga unit at residente", "Facility booking": "Pag-book ng pasilidad", "Polls & voting": "Mga botohan",
  "Manage access": "Pamahalaan ang access", "My profile": "Aking profile", "Community documents": "Mga dokumento ng komunidad",
  "Dues & payment status": "Mga bayarin at katayuan ng bayad", "Motor parking": "Paradahan ng motor",
  "Your unit, announcements, events and notifications in one place.": "Ang iyong unit, mga anunsyo, kaganapan at abiso sa iisang lugar.",
  "Check availability and send a reservation request.": "Tingnan kung bakante at magpadala ng kahilingan sa reserbasyon.",
  "Every facility request you've made, and its current status.": "Lahat ng hiniling mong pasilidad at ang kasalukuyang katayuan nito.",
  "Your monthly charges and outstanding balance.": "Ang iyong buwanang singil at natitirang balanse.",
  "Your parking slot, your request, and which slots are free.": "Ang iyong parking slot, kahilingan, at kung aling slot ang bakante.",
  "See what is coming up and tell us you are going.": "Tingnan ang mga paparating at ipaalam kung sasama ka.",
  "Have your say on community decisions. One vote per unit.": "Ibahagi ang iyong boto sa mga desisyon ng komunidad. Isang boto bawat unit.",
  "Who to call, house rules, and answers to common questions.": "Sino ang tatawagan, mga patakaran, at sagot sa mga karaniwang tanong.",
  "Submit a concern and track its status.": "Magsumite ng hinaing at subaybayan ang katayuan nito.",
  "Files shared by the association.": "Mga file na ibinahagi ng asosasyon.",
  "Renting out your unit or running a business from it? Declare it here.": "Nagpapaupa o may negosyo sa unit mo? Ideklara dito.",
  "Manage your profile, password, appearance, and where you're signed in.": "Pamahalaan ang iyong profile, password, hitsura, wika at mga device na naka-sign in.",
  "All your settings, profile, password, devices and language.": "Lahat ng iyong setting, profile, password, device at wika.",
  "Billing defaults, account and security, access and payments.": "Mga default sa singil, account at seguridad, access at mga bayad.",
  "Your administrator account, recent activity and shortcuts.": "Ang iyong admin account, mga kamakailang gawain at shortcut.",
  "Maintain unit, occupancy, and resident records.": "Panatilihin ang mga tala ng unit, nakatira at residente.",
  "Dues, charges, payment status and payment history.": "Mga bayarin, singil, katayuan at kasaysayan ng bayad.",
  "Publish community announcements and events.": "Maglathala ng mga anunsyo at kaganapan ng komunidad.",
  "A record of what the administrators did, newest first.": "Talaan ng ginawa ng mga administrator, pinakabago muna.",
  "Motor parking slots, who has one, and requests waiting for approval.": "Mga parking slot ng motor, sino ang may hawak, at mga kahilingang naghihintay ng pag-apruba.",
  "Collections, occupancy, dues ageing, facility use and requests at a glance.": "Koleksyon, okupasyon, edad ng bayarin, gamit ng pasilidad at kahilingan sa isang tingin.",
  "Good morning": "Magandang umaga", "Good afternoon": "Magandang hapon", "Good evening": "Magandang gabi"
};
// Translates a menu label or page title when the language is Filipino. Unknown text stays as it is.
function tr(s) { return curLang() === "fil" && LANG_FIL[s] ? LANG_FIL[s] : s; }
function acctSetLang(code) {
  try { localStorage.setItem("rh_lang", code === "fil" ? "fil" : "en"); } catch (e) { /* storage blocked */ }
  document.documentElement.lang = code === "fil" ? "fil" : "en";
  toast(code === "fil" ? "Wika: Filipino. Binago na ang mga menu at pamagat." : "Language: English.");
  render();
}
document.documentElement.lang = curLang() === "fil" ? "fil" : "en";

/* ---------- small helpers ---------- */
function acctIsAdmin() { return typeof viewManage === "function"; }
function acctUid() { return (DB.user && DB.user.id) || (DB.profile && DB.profile.id) || "x"; }
function acctGet(k, d) { try { var v = localStorage.getItem(k + acctUid()); return v == null ? d : v; } catch (e) { return d; } }
function acctPut(k, v) { try { localStorage.setItem(k + acctUid(), v); } catch (e) { /* storage blocked */ } }
function acctAgo(ms) {
  var m = Math.max(0, Math.round((Date.now() - ms) / 60000));
  if (m < 2) return L("Active now", "Aktibo ngayon");
  if (m < 60) return m + L(" minutes ago", " minuto ang nakalipas");
  var h = Math.round(m / 60); if (h < 24) return h + (h === 1 ? L(" hour ago", " oras ang nakalipas") : L(" hours ago", " oras ang nakalipas"));
  var d = Math.round(h / 24); return d + (d === 1 ? L(" day ago", " araw ang nakalipas") : L(" days ago", " araw ang nakalipas"));
}
function acctDate(ms) { return new Date(ms).toLocaleDateString(curLang() === "fil" ? "fil-PH" : "en-US", { month: "short", day: "numeric", year: "numeric" }); }
function acctMarkPw() { acctPut("rh_pwchg_", String(Date.now())); }

/* ---------- devices ---------- */
// What this browser is, read from its user-agent text.
function acctThisDevice() {
  var ua = (navigator.userAgent || ""), br = /Edg\//.test(ua) ? "Edge" : /OPR\/|Opera/.test(ua) ? "Opera" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "Browser";
  var os = /Android/.test(ua) ? "Android phone" : /iPhone/.test(ua) ? "iPhone" : /iPad/.test(ua) ? "iPad" : /Windows/.test(ua) ? "Windows computer" : /Mac OS X/.test(ua) ? "Mac" : /Linux/.test(ua) ? "Linux computer" : "Computer";
  return { name: os + " · " + br, kind: /Android|iPhone/.test(ua) ? "phone" : /iPad/.test(ua) ? "tablet" : "computer" };
}
function acctBrowserId() {
  try { var id = localStorage.getItem("rh_device_id"); if (!id) { id = "d" + Date.now().toString(36) + Math.random().toString(36).slice(2, 7); localStorage.setItem("rh_device_id", id); } return id; } catch (e) { return "d-this"; }
}
// The devices of the signed-in account. This browser is always in the list.
function acctDevices() {
  var list = [], me = acctBrowserId(), now = Date.now();
  try { list = JSON.parse(acctGet("rh_devs_", "null")) || null; } catch (e) { list = null; }
  if (!list) {
    var t = acctThisDevice();
    list = [
      { id: me, name: t.name, kind: t.kind, where: "", first: now, last: now },
      { id: "sample-1", name: "Android phone · Chrome", kind: "phone", where: "Quezon City", first: now - 12 * 86400000, last: now - 2 * 86400000, sample: true },
      { id: "sample-2", name: "iPad · Safari", kind: "tablet", where: "Quezon City", first: now - 40 * 86400000, last: now - 9 * 86400000, sample: true }
    ];
  }
  var mine = list.filter(function (d) { return d.id === me; })[0];
  if (!mine) { var t2 = acctThisDevice(); mine = { id: me, name: t2.name, kind: t2.kind, where: "", first: now, last: now }; list.unshift(mine); }
  mine.last = now;
  acctPut("rh_devs_", JSON.stringify(list));
  return list;
}
function acctSaveDevices(list) { acctPut("rh_devs_", JSON.stringify(list)); }
function acctDevIcon(k) {
  return k === "phone" ? '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>' : k === "tablet" ? '<rect x="4.5" y="3" width="15" height="18" rx="2.5"/><path d="M11 18h2"/>' : '<rect x="3" y="4.5" width="18" height="12" rx="2"/><path d="M8 20h8M12 16.5V20"/>';
}
function acctSignOutDevice(id) {
  var me = acctBrowserId();
  if (id === me) return signOut();
  var list = acctDevices(), d = list.filter(function (x) { return x.id === id; })[0];
  acctSaveDevices(list.filter(function (x) { return x.id !== id; }));
  toast(L("Signed out on ", "Na-sign out sa ") + (d ? d.name : L("that device", "device na iyon")) + ".");
  render();
}
function acctSignOutOthers() {
  var me = acctBrowserId(), list = acctDevices(), n = list.length - 1;
  acctSaveDevices(list.filter(function (x) { return x.id === me; }));
  toast(n > 0 ? L("Signed out on " + n + " other device" + (n > 1 ? "s" : "") + ".", "Na-sign out sa " + n + " pang device.") : L("There are no other devices.", "Walang ibang device."));
  render();
}
function acctToggleAlert(on) { acctPut("rh_devalert_", on ? "1" : "0"); toast(on ? L("You will be told when a new device signs in.", "Aabisuhan ka kapag may bagong device na nag-sign in.") : L("New-device alerts are off.", "Naka-off ang abiso sa bagong device.")); }

/* ---------- pages ---------- */
function acctTabs() {
  var tab = state.acctTab || "overview", tabs = [["overview", L("All settings", "Lahat ng setting")], ["profile", L("Profile", "Profile")], ["password", L("Password", "Password")], ["devices", L("Devices", "Mga device")], ["language", L("Language", "Wika")]];
  return '<div class="filters acct-tabs" role="tablist" style="margin-bottom:16px">' + tabs.map(function (t) { return '<button role="tab" aria-selected="' + (t[0] === tab) + '" class="' + (t[0] === tab ? "active" : "") + '" onclick="set({acctTab:\'' + t[0] + '\'})">' + t[1] + "</button>"; }).join("") + "</div>";
}
// The whole Account & security area (used by both dashboards).
function acctView() {
  var tab = state.acctTab || "overview";
  return acctTabs() + ({ overview: acctOverview, profile: acctProfile, password: acctPassword, devices: acctDevicesView, language: acctLanguage }[tab] || acctOverview)();
}
function acctCard(tab, title, status, extra) {
  return '<div class="acct-card"><div><b>' + title + '</b><small>' + status + "</small></div>" + (extra || '<button class="btn" onclick="set({acctTab:\'' + tab + '\'})">' + L("Open", "Buksan") + "</button>") + "</div>";
}
function acctOverview() {
  var p = DB.profile || {}, devs = acctDevices(), pw = Number(acctGet("rh_pwchg_", "0")), lang = ACCT_LANGS.filter(function (l) { return l[0] === curLang(); })[0];
  var cards = acctCard("profile", L("Manage profile", "Pamahalaan ang profile"), esc(p.name || "—") + " · " + esc(p.email || "")) +
    acctCard("password", L("Password", "Password"), pw ? L("Last changed ", "Huling binago ") + acctDate(pw) : L("Not changed on this browser yet", "Hindi pa nababago sa browser na ito")) +
    acctCard("devices", L("Devices", "Mga device"), devs.length + (devs.length === 1 ? L(" device signed in", " device ang naka-sign in") : L(" devices signed in", " device ang naka-sign in"))) +
    acctCard("language", L("Language", "Wika"), lang[1] + " · " + lang[2]) +
    acctCard("", L("Appearance", "Hitsura"), state.darkMode ? L("Dark mode", "Dark mode") : L("Light mode", "Light mode"), '<button class="btn" onclick="toggleDarkMode()">' + (state.darkMode ? L("Switch to light", "Gawing light") : L("Switch to dark", "Gawing dark")) + "</button>");
  if (acctIsAdmin()) {
    cards += acctCard("", L("Billing and directory", "Singil at direktoryo"), L("Dues rate, contacts and house rules", "Rate ng bayarin, mga contact at patakaran"), '<button class="btn" onclick="set({view:\'settings\',setTab:\'general\'})">' + L("Open", "Buksan") + "</button>") +
      acctCard("", L("Access", "Access"), L("Who can sign in, suspend or remove accounts", "Sino ang makakapag-sign in, i-suspend o alisin ang account"), '<button class="btn" onclick="set({view:\'settings\',setTab:\'access\'})">' + L("Open", "Buksan") + "</button>") +
      acctCard("", L("Payments", "Mga bayad"), L("Automatic posting and payment options", "Awtomatikong pag-post at mga paraan ng bayad"), '<button class="btn" onclick="set({view:\'settings\',setTab:\'payments\'})">' + L("Open", "Buksan") + "</button>");
  } else {
    cards += acctCard("", L("Unit status", "Katayuan ng unit"), L("Renting out or running a business?", "Nagpapaupa o may negosyo?"), '<button class="btn" onclick="set({view:\'rental\'})">' + L("Open", "Buksan") + "</button>");
  }
  return '<div class="acct-grid">' + cards + "</div>" +
    '<div class="card" style="margin-top:16px"><h2 style="font-size:19px;margin-bottom:4px">' + L("Sign out", "Mag-sign out") + '</h2><p class="hint" style="margin:0 0 10px">' + L("Use the second button if you used a shared computer or lost a phone.", "Gamitin ang pangalawang button kung gumamit ka ng shared na computer o nawala ang phone.") + '</p><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" onclick="signOut()">' + L("Log out here", "Mag-log out dito") + '</button><button class="btn" style="color:#A02B1D" onclick="signOut(true)">' + L("Log out on all devices", "Mag-log out sa lahat ng device") + "</button></div></div>";
}

/* --- manage profile --- */
function acctProfile() {
  var p = DB.profile || {}, admin = acctIsAdmin(), hist = (admin ? (p.history || []) : recLogOf(p.unit)).slice(0, 5);
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px"><div class="card" style="display:flex;flex-direction:column;gap:12px"><h2 style="font-size:19px">' + L("Manage profile", "Pamahalaan ang profile") + "</h2>" +
    '<div style="display:flex;align-items:center;gap:14px;flex-wrap:wrap"><span class="avatar big">' + avatarInner(p.photo, p.name || p.email) + '</span><div style="flex:1;min-width:180px"><b style="font-size:16px">' + esc(p.name || "—") + '</b><div class="hint" style="margin:0 0 8px">' + (admin ? L("Administrator", "Administrator") : esc(p.unit || "")) + '</div><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" type="button" onclick="acctPickPhoto()">' + (p.photo ? L("Change picture", "Palitan ang larawan") : L("Add a profile picture", "Magdagdag ng larawan")) + "</button>" + (p.photo ? '<button class="btn" type="button" onclick="acctRemovePhoto()">' + L("Remove", "Alisin") + "</button>" : "") + '</div><div class="hint" style="margin:6px 0 0">' + L("A square picture works best. It is shrunk to fit.", "Mas maganda ang parisukat na larawan. Paliliitin ito para magkasya.") + "</div></div></div>" +
    '<label class="fl">' + L("Full name", "Buong pangalan") + '<input id="acName" value="' + escAttr(p.name || "") + '" autocomplete="name"></label>' +
    '<label class="fl">' + L("Email (used to sign in)", "Email (para sa pag-sign in)") + '<input value="' + escAttr(p.email || "") + '" disabled></label>' +
    '<label class="fl">' + (admin ? L("Mobile number", "Mobile number") : L("Mobile number (verified; ask the office to change it)", "Mobile number (beripikado; hilingin sa opisina na baguhin)")) + '<input id="acPhone" value="' + escAttr(p.phone || "") + '" inputmode="tel" placeholder="0917 555 0112"' + (admin ? "" : " disabled") + "></label>" +
    (admin ? "" : '<label class="fl">' + L("Unit (set by the office)", "Unit (itinakda ng opisina)") + '<input value="' + escAttr(p.unit || "") + '" disabled></label>') +
    '<div><button class="btn primary" onclick="acctSaveProfile()">' + L("Save changes", "I-save ang mga pagbabago") + "</button></div></div></div>" +
    '<div style="display:flex;flex-direction:column;gap:16px"><div class="card"><h2 style="font-size:19px;margin-bottom:8px">' + L("Account", "Account") + '</h2><div class="kv"><span>' + L("Role", "Tungkulin") + "</span><b>" + (admin ? L("Administrator", "Administrator") : L("Resident", "Residente")) + "</b><span>" + L("Status", "Katayuan") + "</span><b>" + (p.suspended ? L("Suspended", "Naka-suspend") : L("Active", "Aktibo")) + "</b><span>" + L("Created", "Ginawa") + "</span><b>" + (p.created_at ? acctDate(new Date(p.created_at).getTime()) : "—") + "</b></div></div>" +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:8px">' + L("Recent changes to your details", "Mga kamakailang pagbabago sa iyong detalye") + "</h2>" +
    (hist.length ? hist.map(function (h) { return '<div class="acct-row"><div><b>' + esc(h.field) + "</b><small>" + esc(h.from || "—") + " → " + esc(h.to || "—") + "</small></div><small>" + acctDate(new Date(h.at).getTime()) + "</small></div>"; }).join("") : '<p class="empty">' + L("No changes yet.", "Wala pang pagbabago.") + "</p>") + "</div></div></div>";
}
// Chooses a new profile picture, shrinks it and saves it on the profile.
async function acctPickPhoto() {
  var data = await pickImage(320, 0.82);
  if (!data) return;
  await acctSavePhoto(data, L("Profile picture updated.", "Na-update ang larawan."));
}
function acctRemovePhoto() { acctSavePhoto("", L("Profile picture removed.", "Naalis ang larawan.")); }
async function acctSavePhoto(data, msg) {
  try {
    var r = await sb.from("profiles").update({ photo: data }).eq("id", DB.user.id);
    if (r.error) throw r.error;
    DB.profile.photo = data;
    if (!acctIsAdmin() && DB.profile.unit) { try { await recLogSelf(DB.profile.unit, [{ field: "Profile picture", from: "", to: data ? "updated" : "" }], DB.profile.name || ""); } catch (e) { /* the picture itself was saved */ } }
    try { await rhRefresh(true); } catch (e) { /* carry on */ }
    toast(msg); render();
  } catch (e) { toast(errText(e)); }
}
async function acctSaveProfile() {
  var name = (document.getElementById("acName").value || "").trim(), admin = acctIsAdmin(), patch = { name: name };
  if (!name) return toast(L("Enter your name.", "Ilagay ang iyong pangalan."));
  if (admin) {
    var ph = (document.getElementById("acPhone").value || "").trim(), dg = ph.replace(/\D/g, "");
    if (ph && !/^(63|0)?9\d{9}$/.test(dg)) return toast(L("Enter a valid mobile number, e.g. 0917 555 0112.", "Maglagay ng tamang mobile number, hal. 0917 555 0112."));
    patch.phone = ph;
  }
  try {
    var r = await sb.from("profiles").update(patch).eq("id", DB.user.id);
    if (r.error) throw r.error;
    var oldName = DB.profile.name || "";
    Object.assign(DB.profile, patch);
    // a resident's change is written on their unit record, so the office sees it under Resident profiles
    if (!admin && DB.profile.unit && oldName !== name) { try { await recLogSelf(DB.profile.unit, [{ field: "Name", from: oldName, to: name }], name); } catch (e) { /* the profile itself was saved */ } }
    try { await rhRefresh(true); } catch (e) { /* carry on */ }
    toast(L("Profile updated.", "Na-update ang profile."));
    render();
  } catch (e) { toast(errText(e)); }
}

/* --- password manager --- */
function acctPwScore(p) {
  var n = PW_RULES.filter(function (r) { return r[1](p); }).length + (p.length >= 12 ? 1 : 0) + (p.length >= 16 ? 1 : 0);
  return p ? Math.min(n, 6) : 0;
}
function acctPwInput() {
  var el = document.getElementById("acNew"), box = document.getElementById("acRules");
  if (!el) return;
  var v = el.value, items = box ? box.querySelectorAll("li") : [];
  for (var i = 0; i < items.length; i++) items[i].className = PW_RULES[i][1](v) ? "ok" : "";
  var s = acctPwScore(v), lab = !v ? "" : s <= 2 ? L("Weak", "Mahina") : s <= 4 ? L("Fair", "Katamtaman") : s === 5 ? L("Good", "Mabuti") : L("Strong", "Matibay");
  var bar = document.getElementById("acBar"), txt = document.getElementById("acBarTxt");
  if (bar) { bar.style.width = (s / 6 * 100) + "%"; bar.style.background = s <= 2 ? "#D8584A" : s <= 4 ? "#E5A33A" : "#14A38B"; }
  if (txt) txt.textContent = lab;
}
function acctShowPw(on) { ["acCur", "acNew", "acNew2"].forEach(function (id) { var e = document.getElementById(id); if (e) e.type = on ? "text" : "password"; }); }
// Makes a random password that follows every rule.
function acctGenerate() {
  var sets = ["ABCDEFGHJKLMNPQRSTUVWXYZ", "abcdefghijkmnopqrstuvwxyz", "23456789", "!@#$%&*?"], all = sets.join(""), out = [], buf = new Uint32Array(20);
  (window.crypto || window.msCrypto).getRandomValues(buf);
  sets.forEach(function (s, i) { out.push(s.charAt(buf[i] % s.length)); });
  for (var i = sets.length; i < 16; i++) out.push(all.charAt(buf[i] % all.length));
  for (var j = out.length - 1; j > 0; j--) { var k = buf[j] % (j + 1), t = out[j]; out[j] = out[k]; out[k] = t; }
  var pw = out.join("");
  document.getElementById("acNew").value = pw; document.getElementById("acNew2").value = pw;
  acctShowPw(true); document.getElementById("acShow").checked = true; acctPwInput();
  toast(L("Strong password made. Copy it and keep it somewhere safe.", "Nakagawa ng matibay na password. Kopyahin at itago sa ligtas na lugar."));
}
function acctCopyPw() {
  var v = (document.getElementById("acNew") || {}).value || "";
  if (!v) return toast(L("Nothing to copy yet.", "Wala pang makokopya."));
  function done() { toast(L("Copied.", "Nakopya na.")); }
  if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(v).then(done, function () { toast(L("Could not copy. Select the password and copy it.", "Hindi makopya. Piliin ang password at kopyahin.")); });
  else { var e = document.getElementById("acNew"); e.select(); try { document.execCommand("copy"); done(); } catch (x) { /* ignore */ } }
}
async function acctSavePw(ev) {
  ev.preventDefault();
  var cur = document.getElementById("acCur").value, pw = document.getElementById("acNew").value, pw2 = document.getElementById("acNew2").value, err = document.getElementById("acErr"), btn = document.getElementById("acSave");
  function bad(m) { err.textContent = m; err.hidden = false; }
  err.hidden = true;
  if (!cur) return bad(L("Enter your current password.", "Ilagay ang kasalukuyan mong password."));
  var pr = pwProblem(pw); if (pr) return bad(pr);
  if (pw !== pw2) return bad(L("New password and confirmation don't match.", "Hindi magkapareho ang bagong password at kumpirmasyon."));
  if (pw === cur) return bad(L("Choose a password you have not used just now.", "Pumili ng ibang password sa kasalukuyan."));
  btn.disabled = true;
  try {
    var chk = await sb.auth.signInWithPassword({ email: DB.profile.email, password: cur });
    if (chk.error) { btn.disabled = false; return bad(L("Your current password is not correct.", "Mali ang kasalukuyan mong password.")); }
    var u = await sb.auth.updateUser({ password: pw });
    if (u.error) { btn.disabled = false; return bad(u.error.message); }
    acctMarkPw();
    var also = document.getElementById("acOthers");
    if (also && also.checked) { var me = acctBrowserId(); acctSaveDevices(acctDevices().filter(function (d) { return d.id === me; })); }
    toast(L("Password changed.", "Napalitan na ang password."));
    state.acctTab = "password"; render();
  } catch (e) { btn.disabled = false; bad(errText(e)); }
}
function acctPassword() {
  var pw = Number(acctGet("rh_pwchg_", "0"));
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px"><form class="card" id="acPwForm" autocomplete="off" onsubmit="acctSavePw(event)" style="display:flex;flex-direction:column;gap:12px"><h2 style="font-size:19px">' + L("Password manager", "Tagapamahala ng password") + "</h2>" +
    '<p class="hint" style="margin:0">' + (pw ? L("Last changed ", "Huling binago ") + "<b>" + acctDate(pw) + "</b>." : L("Change it now and then, and never reuse it on other sites.", "Palitan paminsan-minsan at huwag gamitin sa ibang site.")) + "</p>" +
    '<label class="fl">' + L("Current password", "Kasalukuyang password") + '<input id="acCur" type="password" autocomplete="current-password"></label>' +
    '<label class="fl">' + L("New password", "Bagong password") + '<input id="acNew" type="password" autocomplete="new-password" oninput="acctPwInput()"></label>' +
    '<div class="acct-meter"><div class="vp-bar"><i id="acBar" style="width:0"></i></div><small id="acBarTxt"></small></div>' +
    '<ul class="rules" id="acRules">' + PW_RULES.map(function (r) { return "<li>" + esc(r[0]) + "</li>"; }).join("") + "</ul>" +
    '<label class="fl">' + L("Confirm new password", "Kumpirmahin ang bagong password") + '<input id="acNew2" type="password" autocomplete="new-password"></label>' +
    '<label class="acct-check"><input id="acShow" type="checkbox" onchange="acctShowPw(this.checked)"> ' + L("Show passwords", "Ipakita ang mga password") + "</label>" +
    '<label class="acct-check"><input id="acOthers" type="checkbox" checked> ' + L("Sign out my other devices after changing", "I-sign out ang iba kong device pagkatapos magpalit") + "</label>" +
    '<p class="formerr" id="acErr" hidden></p>' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn primary" id="acSave" type="submit">' + L("Update password", "I-update ang password") + '</button><button class="btn" type="button" onclick="acctGenerate()">' + L("Make a strong one", "Gumawa ng matibay") + '</button><button class="btn" type="button" onclick="acctCopyPw()">' + L("Copy", "Kopyahin") + "</button></div></form></div>" +
    '<div style="display:flex;flex-direction:column;gap:16px"><div class="card"><h2 style="font-size:19px;margin-bottom:8px">' + L("Keep it safe", "Panatilihing ligtas") + '</h2><ul class="acct-tips"><li>' + L("Use a password only you know, at least 12 characters.", "Gumamit ng password na ikaw lang ang nakakaalam, hindi bababa sa 12 character.") + "</li><li>" +
    L("The office and the app will never ask you for your password.", "Hindi hihingin ng opisina o ng app ang iyong password.") + "</li><li>" + L("Use a password manager on your phone or browser to store it.", "Gumamit ng password manager sa phone o browser para itago ito.") + "</li><li>" +
    L("Lost a phone or used a shared computer? Sign out on all devices under Devices.", "Nawala ang phone o gumamit ng shared na computer? Mag-sign out sa lahat ng device sa Mga device.") + "</li></ul></div>" +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:6px">' + L("Forgot it?", "Nakalimutan?") + '</h2><p class="hint" style="margin:0">' + (acctIsAdmin() ? L("Use “Forgot password” on the sign-in page.", "Gamitin ang “Forgot password” sa sign-in page.") : L("Ask the administration office to reset it. You will get a temporary password and choose your own when you sign in.", "Hilingin sa opisina na i-reset. Bibigyan ka ng pansamantalang password at pipili ka ng sarili pag-sign in.")) + "</p></div></div></div>";
}

/* --- device management --- */
function acctDevicesView() {
  var devs = acctDevices(), me = acctBrowserId(), alertOn = acctGet("rh_devalert_", "1") === "1", hasSample = devs.some(function (d) { return d.sample; });
  var rows = devs.map(function (d) {
    var cur = d.id === me;
    return '<div class="acct-dev' + (cur ? " cur" : "") + '"><span class="acct-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + acctDevIcon(d.kind) + "</svg></span>" +
      '<div class="acct-dev-main"><b>' + esc(d.name) + "</b> " + (cur ? '<span class="chip good">' + L("This device", "Ang device na ito") + "</span>" : "") + (d.sample ? ' <span class="chip">' + L("Sample", "Halimbawa") + "</span>" : "") +
      "<small>" + (d.where ? esc(d.where) + " · " : "") + L("Signed in ", "Nag-sign in ") + acctDate(d.first) + " · " + (cur ? L("Active now", "Aktibo ngayon") : acctAgo(d.last)) + "</small></div>" +
      '<button class="btn" style="min-height:34px;padding:0 14px;font-size:13px' + (cur ? "" : ";color:#A02B1D") + '" onclick="acctSignOutDevice(\'' + d.id + '\')">' + (cur ? L("Log out", "Mag-log out") : L("Sign out", "I-sign out")) + "</button></div>";
  }).join("");
  return '<div class="two-col-e"><div style="display:flex;flex-direction:column;gap:16px"><div class="card"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><h2 style="font-size:19px">' + L("Manage devices", "Pamahalaan ang mga device") + "</h2><span class=\"chip\">" + devs.length + "</span></div>" +
    '<p class="hint" style="margin:4px 0 10px">' + L("Where this account is signed in. Sign out any device you do not recognise.", "Kung saan naka-sign in ang account na ito. I-sign out ang device na hindi mo kilala.") + "</p>" + rows +
    (hasSample ? '<p class="hint" style="margin:10px 0 0">' + L("In this prototype the other devices are samples so you can try the buttons. A live system lists real sessions.", "Sa prototype na ito, halimbawa lang ang ibang device para masubukan ang mga button. Totoong session ang ipapakita ng live na sistema.") + "</p>" : "") + "</div></div>" +
    '<div style="display:flex;flex-direction:column;gap:16px"><div class="card" style="display:flex;flex-direction:column;gap:10px"><h2 style="font-size:19px">' + L("Sign out", "Mag-sign out") + '</h2><button class="btn" onclick="acctSignOutOthers()">' + L("Sign out all other devices", "I-sign out ang lahat ng ibang device") + '</button><button class="btn" style="color:#A02B1D" onclick="signOut(true)">' + L("Log out on all devices", "Mag-log out sa lahat ng device") + "</button></div>" +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:8px">' + L("Alerts", "Mga abiso") + '</h2><label class="acct-check"><input type="checkbox" ' + (alertOn ? "checked" : "") + ' onchange="acctToggleAlert(this.checked)"> ' + L("Tell me when a new device signs in to my account", "Abisuhan ako kapag may bagong device na nag-sign in sa account ko") + "</label></div></div></div>";
}

/* --- language --- */
function acctLanguage() {
  var cur = curLang();
  return '<div class="two-col-e"><div class="card" style="display:flex;flex-direction:column;gap:12px"><h2 style="font-size:19px">' + L("Language", "Wika") + '</h2><p class="hint" style="margin:0">' + L("Choose the language for the menus and page titles.", "Piliin ang wika para sa mga menu at pamagat ng pahina.") + "</p>" +
    ACCT_LANGS.map(function (l) {
      return '<button class="acct-lang' + (l[0] === cur ? " on" : "") + '" aria-pressed="' + (l[0] === cur) + '" onclick="acctSetLang(\'' + l[0] + '\')"><span class="acct-radio"></span><span><b>' + l[1] + "</b><small>" + l[2] + "</small><em>" + l[3] + "</em></span></button>";
    }).join("") + "</div>" +
    '<div class="card"><h2 style="font-size:19px;margin-bottom:6px">' + L("What changes", "Ano ang magbabago") + '</h2><p class="hint" style="margin:0">' + L("The side menu, page titles, greetings, dates and this Account & security area change language. Other pages, such as tables and forms, stay in English for now. Your choice is saved on this browser.", "Magbabago ang wika ng side menu, mga pamagat, pagbati, petsa at ng Account at seguridad na ito. Ang ibang pahina, tulad ng mga talahanayan at form, ay nasa English muna. Naka-save ang pinili mo sa browser na ito.") + "</p></div></div>";
}
