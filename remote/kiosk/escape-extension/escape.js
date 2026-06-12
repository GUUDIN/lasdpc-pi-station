(function () {
  if (window.top !== window) return;
  if (location.hostname === "localhost" && location.port === "8090") return;

  function go(action) {
    if (action === "back") {
      if (history.length > 1) history.back();
      else location.href = "http://localhost:8080/";
    } else if (action === "dashboard") {
      location.href = "http://localhost:8080/";
    } else if (action === "menu") {
      location.href = "http://localhost:8090/";
    }
  }

  document.addEventListener("keydown", (event) => {
    const target = event.target;
    const tag = target && target.tagName ? target.tagName.toLowerCase() : "";
    const editing = target && (target.isContentEditable || tag === "input" || tag === "textarea" || tag === "select");
    if (editing) return;

    if (event.key === "ArrowLeft" && !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey) {
      event.preventDefault();
      event.stopPropagation();
      go("back");
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      go("menu");
    } else if (event.key === "Home" && !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey) {
      event.preventDefault();
      event.stopPropagation();
      go("dashboard");
    }
  }, true);
})();
