/* ==========================================================================
   app-links.js — the ONE place that says where the app lives.
   If a link changes (new website address, new release file name), change it here only.
   Every page loads this file; links marked data-app-link="..." are filled in
   automatically.
   ========================================================================== */
window.RESIDENTHUB = {
  // The ResidentHub app running in the browser (built by GitHub Pages from the Flutter project)
  webApp: "https://mochiematchaaa.github.io/Residenthub/",
  // The Android app (.apk), attached to a GitHub Release of the Residenthub repository.
  // "latest/download/residenthub.apk" always points to the newest release, as long as the file is named residenthub.apk
  androidApp: "https://github.com/mochiematchaaa/Residenthub/releases/latest/download/residenthub.apk",
  // This website (a GitHub Pages site, see README: repository named mochiematchaaa.github.io)
  website: "https://mochiematchaaa.github.io/"
};

document.addEventListener("DOMContentLoaded", function () {
  var links = window.RESIDENTHUB;
  Array.prototype.forEach.call(document.querySelectorAll("[data-app-link]"), function (a) {
    var url = links[a.getAttribute("data-app-link")];
    if (url) a.setAttribute("href", url);
  });
});
