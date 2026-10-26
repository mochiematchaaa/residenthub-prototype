/* ==========================================================================
   City Residences — public website scripts
   Each block below does one small job.
   ========================================================================== */

// Lets the CSS know JavaScript is running (so scroll animations are safe to use)
document.documentElement.classList.add("js");

// Small helpers
function $(selector) { return document.querySelector(selector); }
function $$(selector) { return Array.from(document.querySelectorAll(selector)); }

var header = $("#header");
var progress = $("#progress");
var toTop = $("#toTop");
var menu = $("#menu");
var menuButton = $("#menuButton");
var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;


/* 1. While scrolling: solid header, progress bar, back-to-top button ---- */
function onScroll() {
  var y = window.scrollY;
  var maxScroll = document.documentElement.scrollHeight - window.innerHeight;

  header.classList.toggle("scrolled", y > 30);
  toTop.classList.toggle("show", y > 600);
  progress.style.transform = "scaleX(" + (maxScroll > 0 ? y / maxScroll : 0) + ")";
}
window.addEventListener("scroll", onScroll, { passive: true });
onScroll();


/* 2. Home links (logo, "Home", "Back to top") always go to the very top -- */
$$("[data-home]").forEach(function (link) {
  link.addEventListener("click", function (event) {
    event.preventDefault();
    window.scrollTo({ top: 0, behavior: "smooth" });
    history.replaceState(null, "", window.location.pathname);   // clean address bar
    closeMenu();
  });
});
toTop.addEventListener("click", function () {
  window.scrollTo({ top: 0, behavior: "smooth" });
});


/* 3. Mobile menu --------------------------------------------------------- */
function closeMenu() {
  menu.classList.remove("open");
  menuButton.setAttribute("aria-expanded", "false");
  menuButton.innerHTML = '<svg class="icon"><use href="#i-menu"/></svg>';
}
menuButton.addEventListener("click", function () {
  var isOpen = menu.classList.toggle("open");
  menuButton.setAttribute("aria-expanded", isOpen ? "true" : "false");
  menuButton.innerHTML = '<svg class="icon"><use href="#' + (isOpen ? "i-close" : "i-menu") + '"/></svg>';
});
menu.addEventListener("click", closeMenu);
document.addEventListener("keydown", function (event) {
  if (event.key === "Escape") closeMenu();
});


/* 4. Fade-in when something scrolls into view ---------------------------- */
function showAll() {
  $$(".reveal, .reveal-wipe").forEach(function (el) { el.classList.add("in"); });
}
if ("IntersectionObserver" in window && !reduceMotion) {
  var revealObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add("in");
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.15 });
  $$(".reveal, .reveal-wipe").forEach(function (el) { revealObserver.observe(el); });
} else {
  showAll();
}


/* 5. Numbers count up when they appear ------------------------------------ */
function countUp(el) {
  var end = Number(el.dataset.count);
  var suffix = el.dataset.suffix || "";
  if (reduceMotion) { el.textContent = end + suffix; return; }

  var start = null;
  function step(time) {
    if (start === null) start = time;
    var t = Math.min((time - start) / 1500, 1);          // 0 → 1 over 1.5 seconds
    var eased = 1 - Math.pow(1 - t, 3);                  // starts fast, ends slow
    el.textContent = Math.round(end * eased) + suffix;
    if (t < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}
if ("IntersectionObserver" in window) {
  var countObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        countUp(entry.target);
        countObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.6 });
  $$("[data-count]").forEach(function (el) { countObserver.observe(el); });
}


/* 6. Amenity photo panels: the one you hover / tap opens up -------------- */
var panels = $$(".panel");
// Opens the side panel for a section of the public site.
function openPanel(panel) {
  panels.forEach(function (p) { p.classList.remove("active"); });
  panel.classList.add("active");
}
panels.forEach(function (panel) {
  panel.addEventListener("click", function () { openPanel(panel); });
  panel.addEventListener("focus", function () { openPanel(panel); });
  panel.addEventListener("mouseenter", function () {
    if (window.matchMedia("(hover: hover)").matches) openPanel(panel);
  });
});


/* 7. Hero photo leans gently toward the mouse ---------------------------- */
var heroVisual = $("#heroVisual");
var tilt = $("#tilt");
if (!reduceMotion && window.matchMedia("(hover: hover)").matches) {
  heroVisual.addEventListener("mousemove", function (event) {
    var box = heroVisual.getBoundingClientRect();
    var x = (event.clientX - box.left) / box.width - 0.5;    // -0.5 … 0.5
    var y = (event.clientY - box.top) / box.height - 0.5;
    tilt.style.setProperty("--ry", (x * 8) + "deg");
    tilt.style.setProperty("--rx", (-y * 8) + "deg");
  });
  heroVisual.addEventListener("mouseleave", function () {
    tilt.style.setProperty("--rx", "0deg");
    tilt.style.setProperty("--ry", "0deg");
  });
}


/* 8. Highlight the menu link of the section you are looking at ----------- */
var menuLinks = {};
$$("#menu a[href^='#']").forEach(function (link) {
  menuLinks[link.getAttribute("href").slice(1)] = link;
});
// Highlights the menu link of the section being viewed.
function highlight(id) {
  $$("#menu a").forEach(function (a) { a.classList.remove("active"); });
  if (menuLinks[id]) menuLinks[id].classList.add("active");
}
highlight("home");
if ("IntersectionObserver" in window) {
  var sectionObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) highlight(entry.target.id);
    });
  }, { rootMargin: "-45% 0px -50% 0px" });
  ["home", "amenities", "about", "contact"].forEach(function (id) {
    var section = document.getElementById(id);
    if (section) sectionObserver.observe(section);
  });
}


/* 9. Coming back with the browser's Back button (from the Sign In page) -- */
window.addEventListener("pageshow", function (event) {
  if (event.persisted) {          // page was restored from the browser's memory
    closeMenu();
    showAll();
    onScroll();
  }
});
