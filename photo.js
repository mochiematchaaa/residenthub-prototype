/* ==========================================================================
   photo.js — picking a picture and shrinking it so it fits in the demo storage.
   Used for profile pictures and for the image proof of an online payment.
   Loaded by admin.html and resident.html before account.js.
   ========================================================================== */

// Opens the file picker, shrinks the chosen picture and returns it as a "data:image/jpeg" text, or null if nothing was chosen.
// max = longest side in pixels, quality = 0..1. Shows a message and returns null if the file is not a picture.
function pickImage(max, quality) {
  return new Promise(function (resolve) {
    var inp = document.createElement("input"), done = false;
    inp.type = "file"; inp.accept = "image/*"; inp.style.display = "none";
    function finish(v) { if (done) return; done = true; if (inp.parentNode) inp.parentNode.removeChild(inp); resolve(v); }
    inp.onchange = function () {
      var f = inp.files && inp.files[0];
      if (!f) return finish(null);
      if (!/^image\//.test(f.type)) { toast("Please choose a picture (JPG or PNG)."); return finish(null); }
      if (f.size > 15 * 1024 * 1024) { toast("That picture is too large. Choose one under 15 MB."); return finish(null); }
      var fr = new FileReader();
      fr.onerror = function () { toast("Could not read that picture."); finish(null); };
      fr.onload = function () {
        var img = new Image();
        img.onerror = function () { toast("Could not open that picture."); finish(null); };
        img.onload = function () {
          var s = Math.min(1, (max || 800) / Math.max(img.width, img.height)), w = Math.max(1, Math.round(img.width * s)), h = Math.max(1, Math.round(img.height * s));
          var c = document.createElement("canvas"); c.width = w; c.height = h;
          var g = c.getContext("2d"); g.fillStyle = "#fff"; g.fillRect(0, 0, w, h); g.drawImage(img, 0, 0, w, h);
          finish(c.toDataURL("image/jpeg", quality || 0.75));
        };
        img.src = fr.result;
      };
      fr.readAsDataURL(f);
    };
    // if the picker is closed without choosing, the page simply stays as it was
    window.addEventListener("focus", function once() { window.removeEventListener("focus", once); setTimeout(function () { if (!inp.files || !inp.files.length) finish(null); }, 600); });
    document.body.appendChild(inp); inp.click();
  });
}
// Picture inside a round avatar, or the initials when there is no picture.
function avatarInner(photo, name) {
  return photo && /^data:image\//.test(photo) ? '<img alt="" src="' + escAttr(photo) + '">' : esc(initials(name || "?"));
}
// The picture of the person signed in.
function myPhoto() { return (DB.profile && DB.profile.photo) || ""; }
// The picture of the resident account that belongs to a unit (the administrator can see these).
function unitPhoto(unit) {
  if (DB.profile && DB.profile.role !== "admin") return DB.profile.unit === unit ? (DB.profile.photo || "") : "";
  var a = (DB.accounts || []).filter(function (x) { return x.role === "resident" && x.unit === unit; })[0];
  return (a && a.photo) || "";
}
// Opens the photo a resident attached to a payment.
function viewProofImage(id) {
  var r = getRow("proof", id);
  if (r && r.value.image) viewImage(r.value.image, "Payment photo · " + (r.value.unit || ""));
}
// Full-size look at a picture (profile picture or payment proof).
function viewImage(src, title) {
  if (!src) return;
  var d = document.createElement("div");
  d.className = "img-view"; d.setAttribute("role", "dialog"); d.setAttribute("aria-label", title || "Picture");
  d.innerHTML = '<div class="img-view-in"><div class="img-view-bar"><b>' + esc(title || "Picture") + '</b><button class="btn" type="button">Close</button></div><img alt="" src="' + escAttr(src) + '"></div>';
  d.onclick = function (e) { if (e.target === d || e.target.tagName === "BUTTON") document.body.removeChild(d); };
  document.body.appendChild(d);
}
