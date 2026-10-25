// Visitor counter: only shows when the interview-mode 3-tier stack is up.
// If /api/ doesn't answer quickly, the counter stays hidden.
(function () {
  "use strict";

  var box = document.getElementById("visit-counter");
  var number = document.getElementById("visit-count");
  if (!box || !number) return;

  var controller = new AbortController();
  var timer = setTimeout(function () { controller.abort(); }, 4000);

  fetch("/api/visits", { cache: "no-store", signal: controller.signal })
    .then(function (res) {
      if (!res.ok) throw new Error("counter unavailable");
      return res.json();
    })
    .then(function (data) {
      if (typeof data.visits !== "number") throw new Error("bad response");
      number.textContent = data.visits.toLocaleString();
      box.hidden = false;
    })
    .catch(function () { /* stack is down: stay hidden */ })
    .finally(function () { clearTimeout(timer); });
})();
