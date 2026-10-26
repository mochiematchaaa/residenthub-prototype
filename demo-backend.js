/* ResidentHub DEMO backend.
   Stands in for Supabase so the website dashboards can be previewed with made-up (sample) data.
   There is no database: everything lives in this browser (localStorage), is never sent anywhere,
   and can be reset from the DEMO panel. The sample dates are always built around today.
   Loaded INSTEAD of supabase-js and supabase-config.js. The real system does not use this file. */
(function () {
  var KEY = "__rhdemo_v12", SESS = "__rhdemo_session";
  window.RH_SUPABASE = { url: "demo", anonKey: "demo" };
  window.RH_DEMO = true;
  var SHOW_TOOLS = /[?&]tools\b/.test(location.search);

  /* ---------------- who is signed in (per browser tab, so admin and resident can be open side by side) ---------------- */
  var memSess = null;
  function getSess() { try { return sessionStorage.getItem(SESS) || memSess; } catch (e) { return memSess; } }
  function setSess(v) { memSess = v; try { if (v) sessionStorage.setItem(SESS, v); else sessionStorage.removeItem(SESS); } catch (e) { } }

  /* ---------------- sample data ---------------- */
  var MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var MONL = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  function pad(n) { return n < 10 ? "0" + n : "" + n; }
  function sd(d) { return MON[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear(); }
  function dk(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function dayOff(n) { var d = new Date(); d.setHours(12, 0, 0, 0); d.setDate(d.getDate() + n); return d; }
  function clk(min) { var h = Math.floor(min / 60) % 24, m = min % 60; return { t: (h % 12 || 12) + (m ? ":" + pad(m) : ""), ap: h >= 12 ? "PM" : "AM" }; }
  function slotLabel(open, mins, i) {
    var s = open + i * mins, x = clk(s), y = clk(s + mins);
    return x.ap === y.ap ? x.t + "–" + y.t + " " + x.ap : x.t + " " + x.ap + "–" + y.t + " " + y.ap;
  }

  function buildSeed() {
    var now = new Date(), YEAR = now.getFullYear(), recs = [], users = [], seq = 0;
    /* a small fixed random generator, so the sample data looks the same every time */
    var rs = 20261016;
    function rnd() { rs = (rs * 1664525 + 1013904223) % 4294967296; return rs / 4294967296; }
    function ri(a, b) { return a + Math.floor(rnd() * (b - a + 1)); }
    function pick(a) { return a[Math.floor(rnd() * a.length)]; }
    function R(kind, id, unit, value) { recs.push({ kind: kind, id: String(id), unit: unit, value: value }); }
    function tid() { return Date.now() - 100000000 + (++seq); }
    var PW = "Demo@1234", verified = new Date(Date.now() - 20 * 86400000).toISOString();
    function monthDate(off, day) { return new Date(now.getFullYear(), now.getMonth() + off, day, 12); }

    /* ---------- units: 12 floors x A, B, C ---------- */
    var SUR = ["Santos", "Dela Cruz", "Ocampo", "Garcia", "Mendoza", "Torres", "Bautista", "Reyes", "Castillo", "Flores", "Villanueva", "Ramos",
      "Aquino", "Navarro", "Lim", "Tan", "Chua", "Salazar", "Domingo", "Gonzales", "Aguilar", "Pascual", "Rivera", "Mercado", "Santiago",
      "Soriano", "Del Rosario", "Valdez", "Manalo", "Lopez", "Fernandez", "Diaz", "Perez", "Cabrera", "Evangelista", "Magsaysay"];
    var FIRST = ["Elena", "Paolo", "Rhea", "Carlo", "Liza", "Marco", "Rico", "Maria", "Jenny", "Noel", "Cathy", "Dennis", "Joy", "Ben", "Grace",
      "Victor", "Anna", "Ramon", "Joanna", "Mark", "Teresa", "Leo", "Kristine", "Allan", "Bea", "Jun", "Nina", "Edgar", "Faye", "Rommel",
      "Lyn", "Gerald", "Trixie", "Albert", "Sheila", "Dante"];
    var U = [];
    for (var f = 1; f <= 12; f++) ["A", "B", "C"].forEach(function (L) {
      var i = U.length;
      var vacant = i % 9 === 4, tenant = !vacant && i % 5 === 3;
      U.push({ i: i, label: "Unit " + f + L, house: SUR[i] + (i % 2 ? " Household" : " Family"), type: tenant ? "Tenant" : "Owner",
        status: vacant ? "Vacant" : "Occupied", contact: "0917 000 " + (1100 + i + 1), person: FIRST[i] + " " + SUR[i], key: i === 7 ? "resident" : (FIRST[i] + "." + SUR[i]).toLowerCase().replace(/[^a-z.]/g, "") });
    });
    var occ = U.filter(function (u) { return u.status === "Occupied"; });
    var withAcc = occ.slice(0, 24);
    users.push({ id: "demo-admin", email: "admin@demo.test", password: PW, profile: { id: "demo-admin", email: "admin@demo.test", name: "Administrator", role: "admin", unit: null, phone: "0917 000 0000", suspended: false, must_change_password: false, contact_verified_at: verified } });
    withAcc.forEach(function (u, k) {
      var id = "demo-u" + u.i, email = u.key + "@demo.test";
      // sample "new" and "updated" accounts so the Access page has something to show
      var isNew = k === 5 || k === 11, isUpd = k === 2 || k === 8 || k === 15;
      var made = new Date(Date.now() - (isNew ? (k === 5 ? 1 : 3) : 20 + k) * 86400000).toISOString();
      var changed = isUpd ? new Date(Date.now() - (k === 2 ? 1 : k === 8 ? 2 : 4) * 86400000).toISOString() : made;
      // change history, newest first: { at, field, from, to }. "Account created" has no from/to.
      var hist = [];
      if (isUpd) {
        var fld = k === 2 ? "Mobile number" : k === 8 ? "Email address" : "Unit";
        hist.push({ at: changed, field: fld, from: k === 2 ? "0917 555 0102" : k === 8 ? u.key.split(".")[0] + "@oldmail.test" : "Unit " + (1 + (k % 9)) + "A", to: k === 2 ? u.contact : k === 8 ? email : u.label });
      }
      hist.push({ at: made, field: "Account created", from: "", to: "" });
      users.push({ id: id, email: email, password: PW, profile: { id: id, email: email, name: u.person, role: "resident", unit: u.label, phone: u.contact, suspended: false, must_change_password: false, contact_verified_at: verified, created_at: made, updated_at: changed, last_change: isUpd ? (k === 2 ? "Mobile number" : k === 8 ? "Email address" : "Unit") : (isNew ? "New account" : ""), history: hist } });
    });
    var byUnit = {};
    /* floor area by unit type (A smaller, C larger, upper floors a little bigger); dues are charged per square meter */
    function areaOf(label) { var L = label.slice(-1), f = parseInt(label.slice(5), 10); return ({ A: 32, B: 45, C: 60 }[L] || 40) + (f >= 9 ? 8 : 0); }
    var SQM_RATE = 50;
    U.forEach(function (u) { byUnit[u.label] = { unit: u.label, name: u.house, type: u.type, status: u.status, area: areaOf(u.label), contact: u.contact, usage: u.type === "Tenant" ? "tenant" : "owner" }; });
    function tenantInfo(u, from, to) { return { tname: u.person, tphone: u.contact, occupants: String(ri(1, 4)), start: dk(dayOff(from)), end: dk(dayOff(to)), emerg: pick(FIRST) + " " + u.house.split(" ")[0] + ", 0917 000 " + ri(2000, 2999), plates: "ABC " + ri(1000, 9999) }; }
    var tenants = U.filter(function (u) { return u.type === "Tenant" && u.status === "Occupied"; });
    tenants.forEach(function (u, k) {
      var b = byUnit[u.label];
      if (k === 1) { b.usageStatus = "pending"; b.usageInfo = tenantInfo(u, 5, 370); }
      else if (k === 4) { b.usageStatus = "rejected"; b.usageRemark = "The lease dates are missing. Please send the signed lease to the office."; b.usageInfo = tenantInfo(u, -3, 360); }
      else { b.usageStatus = "approved"; b.usageInfo = tenantInfo(u, -ri(60, 300), ri(60, 300)); }
    });
    [[9, "shortterm"], [20, "shortterm"], [11, "business"], [14, "renovation"], [25, "renovation"], [16, "business"]].forEach(function (x, k) {
      var u = U[x[0]]; if (u.status !== "Occupied") return;
      var b = byUnit[u.label]; b.usage = x[1]; b.usageStatus = (k === 3 || k === 5) ? "pending" : "approved";
      if (x[1] === "shortterm") b.usageInfo = { platform: pick(["Airbnb", "Booking.com", "Agoda"]), contact: u.person, phone: u.contact, start: dk(dayOff(-ri(30, 200))), listing: "Cozy unit with city view" };
      else if (x[1] === "business") b.usageInfo = { bname: u.person.split(" ")[1] + " Online Shop", btype: pick(["Online selling", "Tutoring", "Home office", "Baking"]), permit: "DTI-" + ri(100000, 999999), hours: "Mon to Fri, 9 AM to 5 PM", phone: u.contact };
      else b.usageInfo = { work: pick(["New tiles in the kitchen and bathroom", "Repainting and new ceiling", "New cabinets and countertop"]), contractor: pick(["J. Villanueva Builders", "Metro Renovations", "Santos Interiors"]), phone: "0917 000 " + ri(3000, 3999), start: dk(dayOff(ri(3, 12))), end: dk(dayOff(ri(20, 45))) };
    });
    U.forEach(function (u) { R("unit", u.label, u.label, byUnit[u.label]); });

    /* ---------- settings ---------- */
    R("setting", "dues_rate", "", { rate: 2500 });
    R("setting", "dues_rate_sqm", "", { rate: SQM_RATE });
    R("setting", "motor_rate", "", { rate: 1500 });
    R("setting", "motor_rate_daily", "", { rate: 100 });
    R("setting", "paymethods", "", { list: [
      { name: "Cash or check at the office", details: "Pay at the administration office, Monday to Saturday, 8 AM to 5 PM.", enabled: true },
      { name: "Bank transfer", details: "Account name: City Residences Condominium Corp. (sample)\nBank: Sample Bank\nAccount no.: 0000-0000-00", enabled: true },
      { name: "GCash", details: "Account name: City Residences (sample)\nNumber: 0917 000 0000", enabled: true },
      { name: "Maya", details: "Account name: (add name)\nNumber: (add Maya number)", enabled: false }
    ] });
    var AM = [
      { id: "pool", name: "Swimming Pool", open: "06:00", close: "20:00", mins: 120, note: "Free for residents. Guests pay ₱150 per visit, collected at the gate." },
      { id: "hall", name: "Function Hall", open: "08:00", close: "22:00", mins: 120, note: "Good for up to 60 guests. Clean the hall after use." }
    ];
    R("setting", "amenities", "", { list: AM });
    R("setting", "directory", "", {
      contacts: [
        { name: "Security desk", note: "Open 24 hours", tel: "Local 101" },
        { name: "Administration office", note: "Mon to Sat, 8 AM to 5 PM", tel: "Local 110" },
        { name: "Building engineer", note: "Repairs and maintenance", tel: "Local 120" },
        { name: "Housekeeping", note: "Common areas and garbage", tel: "Local 130" },
        { name: "Parking office", note: "Motor parking rentals", tel: "Local 140" },
        { name: "Emergency hotline", note: "Fire, medical, police", tel: "911" }
      ],
      rules: [
        ["Quiet hours", "Please keep noise down from 10 PM to 6 AM."],
        ["Garbage", "Bag your garbage and put it in the chute room on your floor. No bulky items."],
        ["Visitors", "Visitors must register at the lobby and leave a valid ID."],
        ["Pets", "Pets must be on a leash in the common areas."],
        ["Moving in or out", "Tell the office three days before and use the service elevator."],
        ["Smoking", "No smoking in the lobby, hallways, elevators and amenities."]
      ] });

    /* ---------- dues and payments: two months back (mostly paid) and this month ---------- */
    var receipt = 0, METHODS = ["Cash or check at the office", "GCash", "Bank transfer"];
    occ.forEach(function (u, hi) {
      var amt = areaOf(u.label) * SQM_RATE;
      [-2, -1, 0].forEach(function (off) {
        var dd = monthDate(off, 25), note = "Association dues - " + MONL[dd.getMonth()] + " " + dd.getFullYear();
        var idn = new Date(dd.getFullYear(), dd.getMonth(), 1, 9).getTime() + hi;
        var paid = off < 0 ? !(off === -1 && hi % 9 === 3) && !(off === -2 && hi % 23 === 5) : (hi % 5 === 0 || hi % 5 === 2 || hi % 5 === 3);
        var due = { id: idn, unit: u.label, name: u.house, amount: amt, area: areaOf(u.label), rate: SQM_RATE, billedOn: sd(new Date(dd.getFullYear(), dd.getMonth(), 1, 9)), note: note, dueDate: sd(dd) };
        if (paid) due.paid = true;
        R("due", idn, u.label, due);
        if (paid) {
          var pd = monthDate(off, 1 + (hi * 5 + off * 7 + 11) % 27);
          if (pd > now) pd = new Date(now.getFullYear(), now.getMonth(), Math.max(1, now.getDate() - (hi % 10)), 12);
          var no = "OR-" + YEAR + "-" + String(++receipt).padStart(4, "0");
          var method = METHODS[(hi + off + 2) % 3];
          var ref = method === METHODS[0] ? "—" : "REF" + (700000 + receipt * 37);
          R("payment", idn + 5000, u.label, { id: idn + 5000, receiptNo: no, unit: u.label, payer: u.house, forText: note, method: method, reference: ref, date: sd(pd), amount: amt });
          R("proof", idn + 7000, u.label, { id: idn + 7000, unit: u.label, payer: u.house, forText: note, method: method, reference: ref, amount: amt, date: sd(pd), status: "Confirmed", receiptNo: no, confirmedOn: sd(pd) });
        } else if (off === 0 && hi % 7 === 1) {
          R("proof", idn + 7000, u.label, { id: idn + 7000, unit: u.label, payer: u.house, forText: note, method: "GCash", reference: "GC" + (YEAR * 1000000 + 101400 + hi), amount: amt, date: sd(dayOff(-(hi % 3))), status: "Pending" });
        }
      });
      if (hi % 6 === 0) {
        var xid = tid();
        R("due", xid, u.label, { id: xid, unit: u.label, name: u.house, amount: 300, note: "Parking sticker fee", dueDate: sd(dayOff(1 + Math.floor(hi / 6) % 5)) });
      }
    });
    var sid = tid();
    R("due", sid, "Unit 3B", { id: sid, unit: "Unit 3B", name: byUnit["Unit 3B"].name, amount: 800, note: "Special assessment - elevator repair", dueDate: sd(dayOff(9)) });

    /* ---------- expenses (administrator only), six months ---------- */
    var rc = 4100;
    function exp(item, cat, area, payee, qty, price, off, day) {
      var d = monthDate(off, day); if (d > now) return;
      var id = tid(); rc += 7;
      R("expense", id, "__admin", { id: id, item: item, category: cat, area: area, payee: payee, receiptNo: "R-" + rc, qty: qty, unitPrice: price, date: dk(d) });
    }
    for (var m = 0; m >= -5; m--) {
      exp("Security guards - monthly contract", "Security services", "Whole building", "SafeGuard Agency (sample)", 1, 38000, m, 3);
      exp("Common-area electricity", "Common-area utilities", "Lobby and common areas", "Sample Power Co.", 1, 19000 + ri(0, 5000) + 0.5, m, 6);
      exp("Water bill (common areas and pool)", "Common-area utilities", "Swimming pool", "Sample Water District", 1, 7500 + ri(0, 2000), m, 8);
      exp("Janitorial supplies", "Janitorial and maintenance", "Whole building", "CleanPro Supplies", ri(8, 14), 310, m, 11);
      exp("Garbage hauling", "Janitorial and maintenance", "Whole building", "GreenCity Hauling", 1, 4500, m, 14);
      exp("Pool chemicals", "Supplies and equipment", "Swimming pool", "AquaPure Trading", ri(4, 7), 640, m, 17);
      exp("Reserve fund deposit", "Administration and reserve fund", "Whole building", "Bank deposit", 1, 20000, m, 26);
      if (m % 3 === 0) {
        exp("Elevator servicing", "Repairs and improvements", "Elevators", "LiftCare Services", 1, 15500, m, 19);
        exp("Pest control (quarterly)", "Janitorial and maintenance", "Whole building", "BugAway Services", 1, 9800, m, 21);
        exp("Building insurance (quarterly)", "Insurance", "Whole building", "Sample Insurance", 1, 27500, m, 23);
      }
      if (m % 2 === 0) exp("CCTV maintenance", "Repairs and improvements", "Whole building", "SecureView Tech", 1, 6200, m, 22);
    }
    /* small day-to-day purchases for the last 45 days (the office buys something almost every day) */
    var DAILY = [
      ["Cleaning supplies (mops, soap)", "Janitorial and maintenance", "Whole building", "CleanPro Supplies", [1, 2], 350],
      ["Garbage bags", "Janitorial and maintenance", "Whole building", "CleanPro Supplies", [3, 6], 95],
      ["Light bulbs (hallway)", "Supplies and equipment", "Lobby and common areas", "Hardware Depot (sample)", [4, 10], 120],
      ["Drinking water refill", "Supplies and equipment", "Offices and security", "Aqua Station", [3, 5], 40],
      ["Gardening supplies", "Janitorial and maintenance", "Grounds and garden", "Green Thumb Store", [1, 3], 280],
      ["Minor plumbing repair", "Repairs and improvements", "Whole building", "J. Santos Plumbing", [1, 1], 650],
      ["Printing and office supplies", "Administration and reserve fund", "Offices and security", "Copy Corner", [1, 2], 220],
      ["Paint and brushes (touch-up)", "Supplies and equipment", "Lobby and common areas", "Hardware Depot (sample)", [1, 3], 430],
      ["Elevator button cleaning kit", "Supplies and equipment", "Elevators", "CleanPro Supplies", [1, 1], 260],
      ["Parking cones and tape", "Supplies and equipment", "Parking", "Hardware Depot (sample)", [2, 6], 150]
    ];
    for (var dd0 = 0; dd0 < 45; dd0++) {
      var n0 = (dd0 * 5 + 3) % 4;
      for (var k0 = 0; k0 < n0; k0++) {
        var it = DAILY[(dd0 * 3 + k0 * 5) % DAILY.length], day0 = dayOff(-dd0), id0 = tid(); rc += 7;
        R("expense", id0, "__admin", { id: id0, item: it[0], category: it[1], area: it[2], payee: it[3], receiptNo: "R-" + rc, qty: ri(it[4][0], it[4][1]), unitPrice: it[5], date: dk(day0) });
      }
    }
    exp("Parking lot repainting", "Repairs and improvements", "Parking", "ColorWorks Painting", 1, 12400, -2, 12);
    exp("Light bulbs for hallways", "Supplies and equipment", "Lobby and common areas", "Hardware Depot", 24, 85.5, -1, 9);
    exp("Lobby plants and landscaping", "Janitorial and maintenance", "Lobby and common areas", "Green Thumb Landscaping", 1, 5400, -1, 18);

    /* ---------- announcements, events, polls ---------- */
    function ann(title, body, type, off, status) { var id = tid(); R("announcement", id, "", { id: id, title: title, body: body, date: sd(dayOff(off)), status: status || "Published", type: type }); }
    ann("Water interruption this Saturday", "The water supply will be shut off from 9 AM to 3 PM for the cleaning of the water tank. Please store enough water.", "Maintenance", -1);
    ann("Elevator B maintenance", "Elevator B will be out of service next Tuesday from 8 AM to 12 NN. Please use Elevator A.", "Maintenance", -3);
    ann("Reminder: dues are due on the 25th", "Association dues are due every 25th of the month. Pay online in the Dues page or at the office.", "General", -4);
    ann("Fire drill next week", "A building-wide fire drill will be held next Thursday at 2 PM. Please follow the guards' instructions.", "Warning", -6);
    ann("Halloween trick-or-treat in the lobby", "Kids are welcome to trick-or-treat on October 31 from 4 to 6 PM. Costumes encouraged!", "General", -8);
    ann("Pest control schedule", "Pest control will visit the floors on Wednesday from 9 AM. Please let the staff in or tell the office if you prefer another day.", "Maintenance", -10);
    ann("New rule: parking stickers", "All motor parking users must display the new sticker. Get yours at the office for ₱300.", "General", -13);
    ann("Typhoon advisory", "Please keep windows closed and move plants indoors. The guards will lock the pool and the gym when the signal is raised.", "Emergency", -16);
    ann("Lost and found at the lobby", "A set of keys and a blue umbrella were found near the elevator. Claim them at the guard desk.", "General", -20);
    ann("Thank you for the clean-up drive", "Thank you to everyone who joined last month's clean-up. The lobby planters are now back.", "General", -27);
    ann("Year-end party planning", "Draft: we are collecting ideas for the year-end party. Details to follow.", "General", -1, "Draft");
    function evt(title, off, time, place, about) { var id = tid(); R("event", id, "", { id: id, title: title, date: sd(dayOff(off)) + " · " + time, place: place, about: about }); return id; }
    var EV = [
      evt("Community clean-up drive", 8, "7:00 AM", "Lobby", "Bring gloves and a reusable bag. Snacks provided."),
      evt("Kids Halloween party", 15, "4:00 PM", "Function Hall", "Games, costumes and treats for the kids of the building."),
      evt("Quarterly general assembly", 25, "6:00 PM", "Function Hall", "Updates on the budget and the lobby repainting."),
      evt("Morning yoga by the pool", 4, "6:30 AM", "Pool deck", "Bring your own mat. Free for residents."),
      evt("Blood donation drive", 11, "9:00 AM", "Function Hall", "In partnership with the barangay health center."),
      evt("Christmas lights switch-on", 40, "6:00 PM", "Lobby", "Hot chocolate and carols for the whole building.")
    ];
    EV.forEach(function (eid) { withAcc.forEach(function (u) { if (rnd() < 0.35) R("rsvp", u.label + "|" + eid, u.label, { event: eid }); }); });
    R("rsvp", "Unit 3B|" + EV[1], "Unit 3B", { event: EV[1] });
    R("rsvp", "Unit 3B|" + EV[0], "Unit 3B", { event: EV[0] });
    var POLLS = [
      ["Should the lobby be repainted this year?", true, 6, ["Yes, with a new color", "Yes, same color", "No, not needed"]],
      ["Best day for the quarterly general assembly?", false, -12, ["Saturday morning", "Saturday evening", "Sunday afternoon"]],
      ["Add more CCTV cameras in the parking area?", true, 10, ["Yes", "No", "Not sure"]],
      ["How big should the Christmas party budget be?", true, 14, ["₱20,000", "₱35,000", "₱50,000"]]
    ];
    POLLS.forEach(function (p) {
      var id = tid(); R("poll", id, "", { id: id, question: p[0], open: p[1], closes: sd(dayOff(p[2])), options: p[3] });
      withAcc.forEach(function (u) { if (u.label !== "Unit 3B" || p[0].indexOf("Best day") === 0) { if (rnd() < 0.65) R("vote", u.label + "|" + id, u.label, { poll: id, option: Math.floor(rnd() * p[3].length) }); } });
    });

    /* ---------- elections and a survey (formatted text, several questions) ---------- */
    function pollRec(kind, titleHtml, descHtml, title, closesIn, showResults, open, qs) {
      var id = tid(), d = dayOff(closesIn);
      R("poll", id, "", { id: id, kind: kind, question: title, titleHtml: titleHtml, descHtml: descHtml, open: open, closes: sd(d), closeKey: d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2), showResults: showResults, options: qs[0].options || [], questions: qs });
      return id;
    }
    function cast(id, qs, share, fn) {
      withAcc.forEach(function (u) {
        if (u.label === "Unit 3B" && share < 1) return;
        if (rnd() > share) return;
        var a = {}; qs.forEach(function (q, i) { var v = fn(q, i); if (v != null) a[q.id] = v; });
        R("vote", u.label + "|" + id, u.label, { poll: id, answers: a, at: new Date(dayOff(-1).getTime() - Math.floor(rnd() * 6 * 86400000)).toISOString() });
      });
    }
    function pickN(n, k) { var all = []; for (var i = 0; i < n; i++) all.push(i); var out = []; while (out.length < k && all.length) out.push(all.splice(Math.floor(rnd() * all.length), 1)[0]); return out; }
    function pos(i, name, cands, seats) { return { id: "q" + i, type: seats > 1 ? "multi" : "choice", html: name, text: name.replace(/<[^>]+>/g, ""), required: false, max: seats, options: cands }; }
    var elQs = [
      pos(1, "<b>President</b>", ["Carla Aquino \u2014 Unit 5A", "Ramon Dela Cruz \u2014 Unit 1B", "Liza Villanueva \u2014 Unit 4B"], 1),
      pos(2, "<b>Vice President</b>", ["Marco Chua \u2014 Unit 6B", "Anna Reyes \u2014 Unit 3B"], 1),
      pos(3, "<b>Secretary</b>", ["Joy Torres \u2014 Unit 2C", "Ben Santos \u2014 Unit 1A"], 1),
      pos(4, "<b>Treasurer</b>", ["Grace Evangelista \u2014 Unit 12B", "Paolo Mendoza \u2014 Unit 8C"], 1),
      pos(5, "<b>Board Directors</b> <i>(vote for up to 3)</i>", ["Carla Aquino \u2014 Unit 5A", "Ben Santos \u2014 Unit 1A", "Marco Chua \u2014 Unit 6B", "Joy Torres \u2014 Unit 2C", "Liza Villanueva \u2014 Unit 4B"], 3)
    ];
    var elId = pollRec("election", "<b>2026 Board of Directors election</b>", "Choose the people who will manage the building for <b>2026\u20132027</b>.<ul><li>Each unit has <b>one secret ballot</b>.</li><li>You may leave a position blank to abstain.</li><li>The results are shown when voting closes.</li></ul>", "2026 Board of Directors election", 12, "closed", true, elQs);
    cast(elId, elQs, 0.7, function (q) { return q.type === "multi" ? pickN(q.options.length, 1 + Math.floor(rnd() * 3)) : (rnd() < 0.08 ? null : Math.floor(rnd() * q.options.length)); });
    var oldQs = [
      pos(1, "<b>Chairperson</b>", ["Elena Castillo \u2014 Unit 7A", "Roberto Lim \u2014 Unit 9B"], 1),
      pos(2, "<b>Committee members</b> <i>(vote for up to 2)</i>", ["Nina Flores \u2014 Unit 3A", "Victor Gomez \u2014 Unit 10A", "Teresa Ramos \u2014 Unit 11C"], 2)
    ];
    var oldId = pollRec("election", "<b>2025 Homeowners\u2019 committee election</b>", "Closed election. Thank you to everyone who voted.", "2025 Homeowners\u2019 committee election", -40, "closed", false, oldQs);
    cast(oldId, oldQs, 0.75, function (q) { return q.type === "multi" ? pickN(q.options.length, 2) : Math.floor(rnd() * q.options.length); });
    var svQs = [
      { id: "q1", type: "choice", html: "<b>How often</b> do you use the pool?", text: "How often do you use the pool?", required: true, max: 0, options: ["Every week", "A few times a month", "Rarely", "Never"] },
      { id: "q2", type: "multi", html: "Which facilities should be <u>improved first</u>? <i>(choose up to 3)</i>", text: "Which facilities should be improved first?", required: true, max: 3, options: ["Pool", "Gym", "Function Hall", "Parking", "Lobby", "Coffee lounge"] },
      { id: "q3", type: "rating", html: "How satisfied are you with the <b>cleanliness</b> of the common areas?", text: "How satisfied are you with the cleanliness of the common areas?", required: true, max: 0, options: [] },
      { id: "q4", type: "para", html: "Anything else you would like the board to know?", text: "Anything else you would like the board to know?", required: false, max: 0, options: [] }
    ];
    var NOTES = ["More lighting near the parking area, please.", "The gym needs two more treadmills.", "Please repaint the lobby soon.", "Thank you for the quick repairs in March!", "Add more bike racks.", "Quiet hours should be enforced on weekends."];
    var svId = pollRec("poll", "<b>Building facilities survey</b>", "Help us decide what to improve first. It takes <i>two minutes</i>. Your answers are shared with the board.", "Building facilities survey", 9, "vote", true, svQs);
    cast(svId, svQs, 0.6, function (q) {
      if (q.id === "q1") return Math.floor(rnd() * 4);
      if (q.id === "q2") return pickN(6, 1 + Math.floor(rnd() * 3));
      if (q.id === "q3") return 2 + Math.floor(rnd() * 4);
      return rnd() < 0.4 ? NOTES[Math.floor(rnd() * NOTES.length)] : null;
    });

    /* ---------- bookings ---------- */
    function toMin(t) { var m = /^(\d{1,2}):(\d{2})$/.exec(t); return Number(m[1]) * 60 + Number(m[2]); }
    function slotCount(a) { return Math.floor((toMin(a.close) - toMin(a.open)) / a.mins); }
    var used = {};
    function book(unitLabel, ai, si, off, status) {
      var a = AM[ai], d = dayOff(off), key = ai + "|" + dk(d) + "|" + si;
      if (used[key]) return false; used[key] = 1;
      var id = tid();
      R("booking", id, unitLabel, { id: id, who: byUnit[unitLabel].name, unit: unitLabel, place: a.name, when: sd(d) + ", " + slotLabel(toMin(a.open), a.mins, si), status: status, day: dk(d), slot: si });
      return true;
    }
    book("Unit 3B", 0, 2, 6, "Approved"); book("Unit 3B", 1, 0, 3, "Pending"); book("Unit 3B", 0, 4, -6, "Approved");
    var n = 0, guard = 0;
    while (n < 52 && guard++ < 600) {
      var u = pick(withAcc), off = ri(-12, 14), ai = Math.floor(rnd() * 2), si = Math.floor(rnd() * slotCount(AM[ai])), status;
      var x = rnd();
      status = off < 0 ? (x < 0.85 ? "Approved" : "Denied") : (x < 0.55 ? "Approved" : x < 0.88 ? "Pending" : "Denied");
      if (book(u.label, ai, si, off, status)) n++;
    }

    /* ---------- grievances: stage 0 open, 1 in progress, 2 resolved ---------- */
    var GR = [
      ["Leaking pipe in the hallway", "Water drips from the ceiling near the elevator."], ["Broken hallway light", "The light outside the unit keeps flickering."],
      ["Noise from a late-night gathering", "Loud music past midnight on the weekend."], ["Parking gate sensor not working", "The gate sometimes does not open for residents."],
      ["Treadmill in the gym is broken", "The second treadmill stops after a few minutes."], ["Elevator A makes a grinding sound", "A loud noise between the 7th and 8th floor."],
      ["Garbage left in the hallway", "Bags were left outside the chute room again."], ["Pool tiles are slippery", "The shallow end is slippery in the morning."],
      ["No hot water in the gym shower", "Cold water only since Monday."], ["Intercom not working", "The lobby intercom does not ring in the unit."],
      ["Water pressure is low", "Very weak water pressure in the evening."], ["Smoking in the stairwell", "A smell of cigarette smoke on the 5th floor stairs."],
      ["Stray cat in the parking area", "A cat is trapped near the motor parking."], ["Lobby aircon too cold", "The lobby aircon is set too low in the morning."]
    ];
    /* maintenance staff and equipment (admin only), used for repair assignment and the preventive schedule */
    var STAFF = [
      ["S-01", "Mang Ben Ocampo", "Plumber", "0917 555 0141"], ["S-02", "Kuya Rey Santos", "Electrician", "0917 555 0142"],
      ["S-03", "Aling Nena Cruz", "Housekeeping supervisor", "0917 555 0143"], ["S-04", "Dante Villanueva", "Building engineer", "0917 555 0144"],
      ["S-05", "Joel Mercado", "Pool and gym attendant", "0917 555 0145"], ["S-06", "Ramon Dela Cruz", "Head of security", "0917 555 0146"]
    ];
    var staffName = {};
    STAFF.forEach(function (x) { staffName[x[0]] = x[1]; R("staff", x[0], "__admin", { id: x[0], name: x[1], role: x[2], phone: x[3] }); });
    var EQUIP = [
      ["E-01", "Elevator A", "Elevator", "Tower lobby", "Needs repair", -75], ["E-02", "Elevator B", "Elevator", "Tower lobby", "Working", -26],
      ["E-03", "Water pump set", "Plumbing", "Basement pump room", "Working", -48], ["E-04", "Standby generator", "Electrical", "Basement", "Working", -16],
      ["E-05", "Fire alarm panel", "Fire safety", "Ground floor lobby", "Working", -21], ["E-06", "Fire extinguishers", "Fire safety", "Every floor", "Working", -69],
      ["E-07", "Pool filtration pump", "Pool", "Pool deck", "Working", -5], ["E-08", "Treadmill 2", "Gym", "Gym", "Needs repair", -40],
      ["E-09", "Lobby aircon", "Air conditioning", "Lobby", "Working", -29], ["E-10", "Parking gate sensor", "Security", "Motor parking gate", "Under maintenance", -12],
      ["E-11", "Gym shower water heater", "Plumbing", "Gym", "Needs repair", -90], ["E-12", "CCTV system", "Security", "Security office", "Working", -3]
    ];
    EQUIP.push(["E-13", "Billiard table", "Other", "Game Room", "Under maintenance", -200]);
    /* facility it belongs to (closes: the facility cannot be booked while this is not working), vendor, warranty ends in days */
    var EQX = {
      "E-01": ["", 0, "LiftCare Services", -60], "E-02": ["", 0, "LiftCare Services", 20], "E-03": ["", 0, "AquaFlow Trading", 300], "E-04": ["", 0, "PowerPro Gensets", 200],
      "E-05": ["", 0, "SafeGuard Fire Systems", 400], "E-06": ["", 0, "SafeGuard Fire Systems", null], "E-07": ["Swimming Pool", 1, "AquaFlow Trading", 150],
      "E-08": ["", 0, "FitGear Supply", -30], "E-09": ["", 0, "CoolAir Services", 90], "E-10": ["", 0, "SecureTech", 10], "E-11": ["", 0, "AquaFlow Trading", -200],
      "E-12": ["", 0, "SecureTech", 260], "E-13": ["", 0, "FitGear Supply", null]
    };
    var equipName = {};
    EQUIP.forEach(function (x) {
      var X = EQX[x[0]] || ["", 0, "", null];
      equipName[x[0]] = x[1];
      R("equipment", x[0], "__admin", { id: x[0], name: x[1], category: x[2], location: x[3], status: x[4], lastService: dk(dayOff(x[5])), facility: X[0], closes: !!X[1], vendor: X[2], warranty: X[3] == null ? "" : dk(dayOff(X[3])) });
      if (X[0] && X[1] && x[4] !== "Working") R("mclosure", X[0], "", { id: X[0], facility: X[0], equipName: x[1], reason: x[4] });
    });
    /* preventive maintenance tasks (residents can read the schedule): id, title, equipment, every, days, due in days, who, last done in days ago */
    [["T-01", "Elevator inspection and lubrication", "E-01", "Monthly", 30, 5, "S-04", 26], ["T-02", "Fire extinguisher pressure check", "E-06", "Every 3 months", 90, 21, "S-06", 69],
      ["T-03", "Generator test run", "E-04", "Every 2 weeks", 14, -2, "S-02", 16], ["T-04", "Water pump servicing", "E-03", "Every 3 months", 90, 12, "S-01", 78],
      ["T-05", "Pool filter cleaning", "E-07", "Weekly", 7, 2, "S-05", 5], ["T-06", "Fire alarm panel test", "E-05", "Monthly", 30, 9, "S-02", 21],
      ["T-07", "Lobby aircon filter cleaning", "E-09", "Monthly", 30, 0, "S-04", 30], ["T-08", "Water tank cleaning", "", "Every 6 months", 180, 40, "S-01", 140],
      ["T-09", "CCTV camera check", "E-12", "Weekly", 7, 4, "S-06", 3], ["T-10", "Gym equipment inspection", "E-08", "Every 2 weeks", 14, 6, "S-05", 8]
    ].forEach(function (t) {
      R("mtask", t[0], "", { id: t[0], kind: "Routine", title: t[1], equipId: t[2], equipName: t[2] ? equipName[t[2]] : "Rooftop water tank", every: t[3], days: t[4], due: dk(dayOff(t[5])), staffId: t[6], assignee: staffName[t[6]], lastDone: dk(dayOff(-t[7])),
        history: [{ date: dk(dayOff(-t[7])), by: staffName[t[6]] }, { date: dk(dayOff(-t[7] - t[4])), by: staffName[t[6]] }] });
    });
    /* compliance renewals (permits, certificates, tests) */
    [["T-11", "Fire safety inspection certificate renewal", "", "Whole building", "Yearly", 365, 60, "S-06", 305], ["T-12", "Elevator operating certificate renewal", "E-02", "", "Yearly", 365, 95, "S-04", 270],
      ["T-13", "Drinking water quality test", "", "Water supply", "Every 6 months", 180, 20, "S-01", 160]
    ].forEach(function (t) {
      R("mtask", t[0], "", { id: t[0], kind: "Compliance", title: t[1], equipId: t[2], equipName: t[2] ? equipName[t[2]] : t[3], every: t[4], days: t[5], due: dk(dayOff(t[6])), staffId: t[7], assignee: staffName[t[7]], lastDone: dk(dayOff(-t[8])),
        history: [{ date: dk(dayOff(-t[8])), by: staffName[t[7]] }] });
    });
    /* repair assignments on some grievances: stage, staff, target in days, equipment, note, priority, resolved days ago, cost, completion note */
    var GRX = {
      0: [1, "S-01", 2, "", "Checking the pipe above the ceiling near Elevator A.", "High"],
      1: [2, "S-02", -1, "", "Replaced the lamp and the starter.", "Normal", -1, 450, "Lamp and starter replaced."],
      3: [1, "S-02", 3, "E-10", "Waiting for a replacement sensor from the supplier.", "High"],
      4: [1, "S-05", 5, "E-08", "Motor belt ordered. Treadmill 2 is closed until it is fixed.", "Normal"],
      5: [1, "S-04", 1, "E-01", "Elevator technician is scheduled to visit.", "Urgent"],
      7: [2, "S-05", -4, "", "Applied anti-slip coating on the shallow-end steps.", "Normal", -5, 1800, "Anti-slip coating applied."],
      8: [1, "S-01", 4, "E-11", "Heating element must be replaced.", "Normal"],
      10: [2, "S-01", -3, "E-03", "Cleaned the pressure tank and adjusted the pump.", "High", -4, 3500, "Pump pressure restored."]
    };
    GR.forEach(function (g, i) {
      var id = tid() - i * 86400000 * 1.5, u = i < 2 ? U[7] : pick(withAcc), st = i < 2 ? (i === 0 ? 1 : 2) : (rnd() < 0.35 ? 0 : rnd() < 0.5 ? 1 : 2);
      var val = { id: Math.round(id), title: g[0], body: g[1], by: u.label, stage: st }, x = GRX[i];
      if (x) {
        Object.assign(val, { stage: x[0], staffId: x[1], assignee: staffName[x[1]], target: dk(dayOff(x[2])), equipId: x[3], equipName: x[3] ? equipName[x[3]] : "", notes: x[4], priority: x[5] });
        if (x[0] === 2) {
          Object.assign(val, { resolvedOn: dk(dayOff(x[6])), cost: x[7], completion: x[8] });
          var eid = tid();
          R("expense", eid, "__admin", { id: eid, item: "Repair: " + g[0], category: "Repairs and improvements", area: x[3] === "E-03" ? "Whole building" : "Lobby and common areas", payee: staffName[x[1]], receiptNo: "R-" + (9000 + i), qty: 1, unitPrice: x[7], date: dk(dayOff(x[6])), equipId: x[3], grievanceId: Math.round(id) });
        }
      }
      R("grievance", Math.round(id), u.label, val);
    });

    /* ---------- motor parking: 20 slots ---------- */
    var rentedSlots = {};
    function rent(id, unit, plan, off, days, amt) { rentedSlots[id] = 1; R("slot", id, "", { id: id, unit: unit, plan: plan, from: dk(dayOff(off)), until: dk(dayOff(off + days - 1)), amount: amt }); }
    rent("M-02", "Unit 1A", "month", -10, 30, 1500); rent("M-04", "Unit 9B", "day", -1, 4, 400); rent("M-08", "Unit 2B", "month", -20, 30, 1500);
    rent("M-09", "Unit 2A", "month", -5, 30, 1500); rent("M-11", "Unit 3A", "day", 0, 7, 700); rent("M-13", "Unit 4A", "month", -26, 30, 1500);
    rent("M-15", "Unit 6C", "month", -3, 30, 1500); rent("M-16", "Unit 8B", "day", -2, 3, 300); rent("M-18", "Unit 10A", "month", -15, 30, 1500);
    for (var s = 1; s <= 20; s++) { var sid2 = "M-" + pad(s); if (!rentedSlots[sid2]) R("slot", sid2, "", { id: sid2 }); }
    [["Unit 7A", "M-05", 1], ["Unit 5C", "M-06", 2]].forEach(function (q, k) {
      var u = byUnit[q[0]], rpid = tid();
      R("request", q[0], q[0], { unit: q[0], who: u.name, when: k ? "3 hours ago" : "1 hour ago", at: Date.now() - (k ? 10800000 : 3600000), slot: q[1], plan: "month", days: 1, amount: 1500, confirmed: false });
      if (!k) R("proof", rpid, q[0], { id: rpid, unit: q[0], payer: u.name, forText: "Motor parking rental", method: "GCash", reference: "GC" + (YEAR * 1000000 + 101403), amount: 1500, date: sd(now), status: "Pending", slot: q[1] });
    });

    /* ---------- documents (readable inside the page) ---------- */
    function doc(name, cat, aud, blocks, off) {
      var id = tid();
      R("doc", id, aud === "admin" ? "__admin" : "", { id: id, name: name, cat: cat, date: sd(dayOff(off)), audience: aud, ext: "", blocks: blocks });
    }
    doc("House Rules and Regulations", "Policy", "all", [
      { k: "h1", t: "House Rules and Regulations (sample)" }, { k: "h2", t: "1. Quiet hours" }, { k: "p", t: "Keep noise down from 10 PM to 6 AM." },
      { k: "h2", t: "2. Common areas" }, { k: "bullet", t: "Do not leave belongings in the hallways." }, { k: "bullet", t: "Clean the amenity after you use it." }], -60);
    doc("Financial statement (sample)", "Finance", "all", [
      { k: "h1", t: "Statement of collections and expenses (sample numbers)" },
      { k: "table", r: [["Item", "Amount"], ["Dues collected", "₱ 240,000"], ["Operating expenses", "₱ 168,000"], ["Reserve fund", "₱ 72,000"]] }], -20);
    doc("Move-in and move-out form", "Form", "all", [{ k: "h1", t: "Move-in / move-out form (sample)" }, { k: "p", t: "Fill this in and submit it to the office three days before moving." }], -90);
    doc("Minutes of the last general assembly", "Minutes", "all", [{ k: "h1", t: "Minutes (sample)" }, { k: "bullet", t: "The budget was approved." }, { k: "bullet", t: "The lobby repainting will be put to a vote." }], -45);
    doc("Parking policy", "Policy", "all", [{ k: "h1", t: "Motor parking policy (sample)" }, { k: "bullet", t: "Monthly rental is ₱1,500; daily rental is ₱100 per day." }, { k: "bullet", t: "Display the sticker at all times." }], -30);
    doc("Amenity guidelines", "Policy", "all", [{ k: "h1", t: "Amenity guidelines (sample)" }, { k: "p", t: "Bookings are in two-hour times and need the office's approval." }, { k: "bullet", t: "Pool: 6 AM to 8 PM." }, { k: "bullet", t: "Function hall: 8 AM to 10 PM." }], -75);
    doc("Notice: elevator schedule", "Notice", "all", [{ k: "h1", t: "Elevator maintenance schedule (sample)" }, { k: "p", t: "Elevator B will be serviced every first Tuesday of the month." }], -3);
    doc("Board notes (admin only)", "Other", "admin", [{ k: "h1", t: "Board notes (sample)" }, { k: "p", t: "Only the administrator can see this document." }], -5);

    /* ---------- activity log (administrator) ---------- */
    var ACT = [["Payment recorded, ", "Finance"], ["Booking approved, ", "Facilities"], ["Booking denied, ", "Facilities"], ["Account created for ", "Access"], ["Unit usage declaration received, ", "Units"], ["Grievance in progress: ", "Requests"], ["Parking rented to ", "Parking"]];
    var TITLES = ["Announcement published: Water interruption this Saturday", "Expense added: Security guards - monthly contract", "Event added: Community clean-up drive", "Poll created: Should the lobby be repainted this year?", "Charge posted to every occupied unit: October dues", "Amenity updated: Gym", "Document uploaded: Parking policy", "Settings updated: payment methods"];
    var acts = [];
    for (var a = 0; a < 40; a++) { var t = pick(ACT), au = pick(withAcc); acts.push([t[0] + au.label, t[1], a * 0.35 + rnd() * 0.3]); }
    TITLES.forEach(function (ttl, k) { acts.push([ttl, ttl.split(" ")[0] === "Announcement" ? "Announcements" : ttl.split(" ")[0] === "Expense" ? "Expenses" : ttl.split(" ")[0] === "Event" ? "Events" : ttl.split(" ")[0] === "Poll" ? "Polls" : ttl.split(" ")[0] === "Charge" ? "Finance" : ttl.split(" ")[0] === "Amenity" ? "Facilities" : ttl.split(" ")[0] === "Document" ? "Documents" : "Settings", 1 + k * 1.6]); });
    acts.forEach(function (x) {
      var at = Date.now() - Math.round(x[2] * 86400000) - ri(0, 3600000);
      R("activity", at, "__admin", { title: x[0], area: x[1], at: at });
    });
    /* The prototype opens WITH the made-up sample data. "Clear all data" in the tools panel starts empty (only the settings and the two
       sign-in accounts stay) so the import can be tried on empty lists; "Load sample data" brings the made-up data back. */
    var sample = false; try { sample = localStorage.getItem("__rhdemo_mode") !== "empty"; } catch (e) { }
    if (!sample) {
      users = users.filter(function (u) { return u.id === "demo-admin" || u.email === "resident@demo.test"; });
      recs = recs.filter(function (r) { return r.kind === "setting" || (r.kind === "unit" && r.id === "Unit 3B"); });
    }
    return { seedDay: dk(now), empty: !sample, users: users, records: recs, seq: 0 };
  }

  /* ---------------- the in-memory "Supabase" ---------------- */
  function today() { return dk(new Date()); }
  function fresh() { var d = buildSeed(); try { localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) { } return d; }
  /* What you add (imported files, units, notices...) is kept in this browser and is not wiped when the sample data changes.
     If an older copy of the data is found, it is carried over and the new fields are filled in. "Clear all data" starts again. */
  var OLD_KEYS = []; /* older copies held sample data, so they are not carried over: everyone starts empty */
  function migrate(old) {
    var s = buildSeed(), byId = {};
    s.users.forEach(function (u) { byId[u.id] = u.profile; });
    (old.users || []).forEach(function (u) {
      var sp = byId[u.id]; if (!sp || !u.profile) return;
      ["created_at", "updated_at", "last_change", "history"].forEach(function (k) { if (u.profile[k] === undefined && sp[k] !== undefined) u.profile[k] = sp[k]; });
    });
    return old;
  }
  function load() {
    try { var x = JSON.parse(localStorage.getItem(KEY)); if (x && x.users && x.records) return x; } catch (e) { }
    for (var i = 0; i < OLD_KEYS.length; i++) {
      try {
        var o = JSON.parse(localStorage.getItem(OLD_KEYS[i]));
        if (o && o.users && o.records) { o = migrate(o); try { localStorage.setItem(KEY, JSON.stringify(o)); } catch (e) { } return o; }
      } catch (e) { }
    }
    return fresh();
  }
  var db = load();
  function save() { try { localStorage.setItem(KEY, JSON.stringify(db)); } catch (e) { } }
  function reload() { db = load(); }
  var chans = [];
  window.addEventListener("storage", function (e) {
    if (e.key === KEY) { reload(); chans.forEach(function (cb) { cb({}); }); }
  });
  function cur() { var s = getSess(); return s ? db.users.filter(function (u) { return u.id === s; })[0] : null; }
  function role() { var u = cur(); return u ? u.profile.role : null; }
  function myunit() { var u = cur(); return u ? u.profile.unit : null; }
  function err(message, code) { return { message: message, code: code }; }

  /* open as a ready-made role: demo/admin.html?as=admin or demo/resident.html?as=resident */
  (function () {
    var m = /[?&]as=(admin|resident)/.exec(location.search);
    if (!m) return;
    var u = db.users.filter(function (x) { return m[1] === "admin" ? x.profile.role === "admin" : x.email === "resident@demo.test"; })[0];
    if (u) setSess(u.id);
    try { history.replaceState(null, "", location.pathname + location.hash); } catch (e) { }
  })();

  var PUBLIC = ["announcement", "event", "doc", "poll", "vendor", "slot", "setting", "booking", "rsvp", "vote"];
  function canRead(r) {
    if (role() === "admin") return true;
    if (r.kind === "announcement" && r.value && r.value.units && r.value.units.length && r.value.units.indexOf(myunit()) < 0) return false; // a notice sent to chosen units only
    if (r.unit === "__admin") return false;
    if (r.unit === "") return true;
    if (PUBLIC.indexOf(r.kind) >= 0) return true;
    return r.unit === myunit();
  }
  var RES_KINDS = ["booking", "grievance", "proof", "request", "statusUpdate", "rsvp", "vote", "unit", "activity"];
  function guard(op, row, old) {
    if (role() === "admin") return null;
    if (RES_KINDS.indexOf(row.kind) < 0) return "row-level security: kind " + row.kind;
    if (row.unit !== myunit() && row.kind !== "activity") return "row-level security: unit " + row.unit;
    if (row.kind === "activity" && row.unit !== "__admin") return "row-level security: activity";
    var nv = row.value, ov = old ? old.value : null;
    if (op === "update") {
      if (row.kind === "activity") return "Only the administrator can change that.";
      if (row.kind === "unit") {
        var keys = {}; Object.keys(ov || {}).concat(Object.keys(nv)).forEach(function (k) { keys[k] = 1; });
        for (var k in keys) if (JSON.stringify((ov || {})[k]) !== JSON.stringify(nv[k]) && ["usage", "usageStatus", "usageRemark", "usageInfo", "status", "statusNote", "statusDate"].indexOf(k) < 0) return "Only the administrator can change unit details. (" + k + ")";
        if (["", "pending"].indexOf(nv.usageStatus || "") < 0) return "Only the administrator can approve a usage reading.";
      }
    }
    if (op === "insert" && row.kind === "unit") return "row-level security: unit insert";
    if (row.kind === "proof" && ((nv.status || "Pending") !== "Pending" || nv.receiptNo || nv.direct)) return "Only the administrator can confirm a payment.";
    if (row.kind === "booking" && (nv.status || "Pending") !== "Pending") return "Only the administrator can decide a booking.";
    if (row.kind === "grievance" && String(nv.stage || 0) !== "0") return "Only the administrator can update a grievance.";
    if (row.kind === "request" && nv.confirmed) return "Only the administrator can confirm a parking request.";
    if (row.kind === "vote") { if (op === "update") return "Your unit has already voted in this poll."; if (row.id !== row.unit + "|" + nv.poll) return "Invalid vote."; }
    if (row.kind === "rsvp" && row.id !== row.unit + "|" + nv.event) return "Invalid RSVP.";
    return null;
  }

  function query(table) {
    var q = { table: table, op: "select", filters: [], order: null, range: null, patch: null, row: null, single: false };
    var api = {
      select: function () { return api; },
      eq: function (c, v) { q.filters.push([c, v]); return api; },
      order: function () { return api; },
      range: function (a, b) { q.range = [a, b]; return api; },
      insert: function (row) { q.op = "insert"; q.row = row; return api; },
      update: function (p) { q.op = "update"; q.patch = p; return api; },
      delete: function () { q.op = "delete"; return api; },
      maybeSingle: function () { q.single = true; return run(); },
      then: function (a, b) { return run().then(a, b); }
    };
    function match(r) { return q.filters.every(function (f) { return r[f[0]] === f[1]; }); }
    function run() {
      return new Promise(function (resolve) {
        setTimeout(function () {
          reload();
          if (table === "profiles") {
            var all = db.users.map(function (u) { return u.profile; });
            if (q.op === "select") {
              var rows = all.filter(match);
              if (role() !== "admin") rows = rows.filter(function (p) { return p.id === getSess(); });
              return resolve(q.single ? { data: rows[0] || null, error: null } : { data: rows, error: null });
            }
            if (q.op === "update") {
              var u = db.users.filter(function (x) { return match(x.profile); })[0];
              if (u) {
                var kk = Object.keys(q.patch || {}), shown = { name: "Name", phone: "Mobile number", email: "Email address", unit: "Unit" }, hit = kk.filter(function (x) { return shown[x] && String(q.patch[x]) !== String(u.profile[x]); });
                var before = {}; hit.forEach(function (x) { before[x] = u.profile[x]; });
                Object.assign(u.profile, q.patch);
                if (hit.length) { u.profile.history = (u.profile.history || []); hit.slice().reverse().forEach(function (x) { u.profile.history.unshift({ at: new Date().toISOString(), field: shown[x], from: before[x] == null ? "" : String(before[x]), to: String(q.patch[x]) }); }); u.profile.updated_at = new Date().toISOString(); u.profile.last_change = hit.map(function (x) { return shown[x]; }).join(", "); }
                save(); chans.forEach(function (cb) { cb({}); }); }
              return resolve({ data: null, error: null });
            }
          }
          if (table === "records") {
            if (q.op === "select") {
              var rs = db.records.filter(canRead).map(function (r) { return { kind: r.kind, id: r.id, unit: r.unit, value: r.value }; });
              return resolve({ data: rs, error: null });
            }
            if (q.op === "insert") {
              var row = JSON.parse(JSON.stringify(q.row));
              var msg = guard("insert", row, null);
              if (msg) return resolve({ data: null, error: err(msg) });
              if (db.records.some(function (r) { return r.kind === row.kind && r.id === row.id; })) return resolve({ data: null, error: err("duplicate", "23505") });
              if (row.kind === "booking" && ["Pending", "Approved"].indexOf(row.value.status) >= 0 &&
                db.records.some(function (r) { return r.kind === "booking" && r.value.place === row.value.place && r.value.day === row.value.day && r.value.slot === row.value.slot && ["Pending", "Approved"].indexOf(r.value.status) >= 0; }))
                return resolve({ data: null, error: err("duplicate key", "23505") });
              db.records.push(row); save(); chans.forEach(function (cb) { cb({}); });
              return resolve({ data: null, error: null });
            }
            if (q.op === "update") {
              var tgt = db.records.filter(function (r) { return match(r); })[0];
              if (!tgt) return resolve({ data: null, error: null });
              var nr = Object.assign({}, tgt, JSON.parse(JSON.stringify(q.patch)));
              if (role() !== "admin" && q.patch.unit !== undefined && q.patch.unit !== tgt.unit) return resolve({ data: null, error: err("Only the administrator can change that.") });
              if (role() !== "admin" && !canRead(tgt)) return resolve({ data: null, error: null });
              var m2 = guard("update", nr, tgt);
              if (m2) return resolve({ data: null, error: err(m2) });
              Object.assign(tgt, nr); save(); chans.forEach(function (cb) { cb({}); });
              return resolve({ data: null, error: null });
            }
            if (q.op === "delete") {
              var del = db.records.filter(match);
              if (role() !== "admin") {
                var bad = del.filter(function (r) { return ["request", "booking", "rsvp"].indexOf(r.kind) < 0 || r.unit !== myunit(); });
                if (bad.length) return resolve({ data: null, error: null });  // RLS silently hides
              }
              db.records = db.records.filter(function (r) { return del.indexOf(r) < 0; });
              save(); chans.forEach(function (cb) { cb({}); });
              return resolve({ data: null, error: null });
            }
          }
          resolve({ data: null, error: err("unsupported " + table + "." + q.op) });
        }, 5);
      });
    }
    return api;
  }

  var listeners = [];
  window.supabase = {
    createClient: function () {
      return {
        from: query,
        auth: {
          getSession: function () { reload(); var u = cur(); return Promise.resolve({ data: { session: u ? { user: { id: u.id, email: u.email } } : null } }); },
          signInWithPassword: function (c) {
            reload();
            // demo only: the sign-in box takes an email OR a mobile number (0917 000 0000, +63 917 000 0000, 9170000000 all match)
            function phoneKey(s) { var d = String(s || "").replace(/\D/g, ""); if (d.indexOf("63") === 0) d = "0" + d.slice(2); if (d.length === 10 && d.charAt(0) === "9") d = "0" + d; return d; }
            var id = String(c.email || "").trim().toLowerCase(), byPhone = id.indexOf("@") < 0;
            var u = db.users.filter(function (x) {
              var who = byPhone ? (phoneKey(id) && phoneKey(x.profile.phone) === phoneKey(id)) : x.email.toLowerCase() === id;
              return who && x.password === c.password;
            })[0];
            if (!u) return Promise.resolve({ error: { message: "Invalid login credentials" }, data: {} });
            setSess(u.id);
            return Promise.resolve({ error: null, data: { session: { user: { id: u.id, email: u.email } } } });
          },
          signOut: function () { setSess(null); listeners.forEach(function (f) { f("SIGNED_OUT"); }); return Promise.resolve({}); },
          updateUser: function (p) { var u = cur(); if (u && p.password) { u.password = p.password; save(); } return Promise.resolve({ error: null, data: {} }); },
          onAuthStateChange: function (f) { listeners.push(f); }
        },
        functions: {
          invoke: function (name, o) {
            reload();
            var b = o.body, ok = function (d) { return Promise.resolve({ data: d, error: null }); }, bad = function (m) { return Promise.resolve({ data: { error: m }, error: null }); };
            if (name === "manage-users") {
              if (role() !== "admin") return bad("Only the administrator can do that.");
              if (b.action === "create") {
                if (db.users.some(function (u) { return u.email === b.email; })) return bad("An account with that email already exists.");
                var id = "u" + (++db.seq);
                db.users.push({ id: id, email: b.email, password: "Temp#Pass1x", profile: { id: id, email: b.email, name: b.name, role: "resident", unit: b.unit, phone: b.phone, suspended: false, must_change_password: true, contact_verified_at: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(), last_change: "New account", history: [{ at: new Date().toISOString(), field: "Account created", from: "", to: "" }] } });
                save(); return ok({ email: b.email, password: "Temp#Pass1x" });
              }
              var t = db.users.filter(function (u) { return u.id === b.userId; })[0];
              if (!t) return bad("Not found");
              if (b.action === "reset-password") { t.password = "Temp#Pass2x"; t.profile.must_change_password = true; save(); return ok({ password: "Temp#Pass2x" }); }
              if (b.action === "set-suspended") { t.profile.suspended = !!b.suspended; save(); return ok({}); }
              if (b.action === "delete") { db.users = db.users.filter(function (u) { return u !== t; }); save(); return ok({}); }
            }
            if (name === "verify-contact") {
              var me = cur();
              if (b.action === "options") return ok({ email: "ma***@test.com", phone: "+6391*****112", emailReady: !window.__noEmail, smsReady: !window.__noSms });
              if (b.action === "send") { window.__sent = (window.__sent || []).concat(b.channel); return ok({ channel: b.channel, email: "ma***@test.com", phone: "+6391*****112", cooldown: 60 }); }
              if (b.action === "check") { if (b.code === "111111") { me.profile.contact_verified_at = new Date().toISOString(); save(); return ok({ verified: true }); } return bad("That code is not correct."); }
            }
            if (name === "reset-password") {
              if (b.action === "options") return ok({ emailReady: true, smsReady: false });
              if (b.action === "request") { window.__rp = b; return ok({ ok: true }); }
              if (b.action === "confirm") { window.__rp2 = b; return b.code === "111111" ? ok({ ok: true }) : bad("The codes are not correct or have expired."); }
            }
            return bad("unknown function");
          }
        },
        channel: function () { var o = { on: function (t, f, cb) { chans.push(cb); return o; }, subscribe: function () { return o; } }; return o; },
        removeChannel: function () { }
      };
    }
  };


  /* ---------------- the DEMO panel (bottom-left) ---------------- */
  window.rhDemoReset = function () {
    try { localStorage.removeItem(KEY); localStorage.setItem("__rhdemo_mode", "empty"); } catch (e) { }
    location.href = location.pathname;
  };
  window.rhDemoSample = function () {
    try { localStorage.removeItem(KEY); localStorage.setItem("__rhdemo_mode", "sample"); } catch (e) { }
    location.href = location.pathname;
  };
  function addPanel() {
    var admin = (window.RH_ROLE || "") === "admin";
    var st = document.createElement("style");
    st.textContent =
      "#rhDemo{position:fixed;left:14px;bottom:14px;z-index:99999;font:600 13px/1.4 'Source Sans 3',system-ui,sans-serif;color:#1c2a4a}" +
      "#rhDemo .pill{display:flex;align-items:center;gap:8px;padding:9px 14px;border:0;border-radius:999px;background:#F5B544;color:#3a2a00;font:800 12px/1 'Source Sans 3',system-ui,sans-serif;letter-spacing:.06em;cursor:pointer;box-shadow:0 6px 18px rgba(0,0,0,.25)}" +
      "#rhDemo .box{display:none;width:min(320px,calc(100vw - 28px));margin-bottom:10px;padding:16px;border-radius:16px;background:#fff;border:1px solid #e3e6ef;box-shadow:0 14px 38px rgba(20,30,60,.28)}" +
      "#rhDemo.open .box{display:block}#rhDemo .box p{margin:0 0 10px;font-weight:500;color:#4a5570}#rhDemo .box b{color:#1c2a4a}" +
      "#rhDemo .row{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}" +
      "#rhDemo .row a,#rhDemo .row button{flex:1 1 auto;padding:9px 12px;border-radius:10px;border:1px solid #cfd5e6;background:#f5f7fc;color:#1c2a4a;font:700 12.5px 'Source Sans 3',system-ui,sans-serif;text-align:center;text-decoration:none;cursor:pointer}" +
      "#rhDemo .row .go{background:#3B6FD8;border-color:#3B6FD8;color:#fff}" +
      "@media(max-width:900px){#rhDemo{bottom:78px}}";
    document.head.appendChild(st);
    var d = document.createElement("div"); d.id = "rhDemo";
    d.innerHTML =
      '<div class="box"><p><b>Prototype tools.</b> Opens with made-up sample data (dummy data), no database; what you add or import stays in this browser only. Press Clear all data to start empty, or Load sample data to bring the dummy data back.</p>' +
      '<p>Sign in (password <b>Demo@1234</b>) with an email or a mobile number:<br>Admin: <b>admin@demo.test</b> or <b>0917 000 0000</b><br>Resident: <b>resident@demo.test</b> or <b>0917 000 1108</b> (Unit 3B)</p>' +
      '<div class="row"><a class="go" href="' + (admin ? "resident.html?as=resident" : "admin.html?as=admin") + '">Open as ' + (admin ? "Resident" : "Admin") + '</a><button onclick="rhDemoReset()">Clear all data</button><button onclick="rhDemoSample()">Load sample data</button><a href="index.html">Website</a></div></div>' +
      '<button class="pill" onclick="document.getElementById(\'rhDemo\').classList.toggle(\'open\')">PROTOTYPE TOOLS</button>';
    document.body.appendChild(d);
  }
  /* The prototype tools button (switch role, reset sample data) only shows when the address has ?tools, e.g. admin.html?tools */
  if (SHOW_TOOLS) { if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", addPanel); else addPanel(); }
})();
