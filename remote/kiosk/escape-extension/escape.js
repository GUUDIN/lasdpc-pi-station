(function () {
  if (window.top !== window) return;
  if (location.hostname === "localhost" && location.port === "8090") return;

  const MENU = "http://localhost:8090";

  // Volta ao menu pela maquina de modos (lasdpc-mode menu, com tela de
  // carregamento). Se o servidor do menu nao responder, navega direto.
  function goMenu() {
    fetch(MENU + "/api/mode/menu", { method: "POST", mode: "no-cors" }).catch(() => {});
    setTimeout(() => { location.href = MENU + "/"; }, 2500);
  }

  function go(action) {
    if (action === "back") {
      if (history.length > 1) history.back();
      else location.href = "http://localhost:8080/";
    } else if (action === "dashboard") {
      location.href = "http://localhost:8080/";
    } else if (action === "menu") {
      goMenu();
    }
  }

  // Setas ficam livres para a propria pagina (graficos, listas, formularios).
  // Voltar = Backspace (padrao de TV) ou Alt+Seta esquerda (nativo do Chromium).
  document.addEventListener("keydown", (event) => {
    const target = event.target;
    const tag = target && target.tagName ? target.tagName.toLowerCase() : "";
    const editing = target && (target.isContentEditable || tag === "input" || tag === "textarea" || tag === "select");
    if (editing) return;
    const plain = !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey;

    if (event.key === "Backspace" && plain) {
      event.preventDefault();
      event.stopPropagation();
      go("back");
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      go("menu");
    } else if (event.key === "Home" && plain) {
      event.preventDefault();
      event.stopPropagation();
      go("dashboard");
    }
  }, true);

  // Botao "Menu" para quem usa mouse: aparece ao mexer o mouse e some sozinho.
  const btn = document.createElement("button");
  btn.textContent = "← Menu";
  btn.title = "Voltar ao menu (Esc)";
  btn.setAttribute("style", [
    "position:fixed", "top:16px", "left:16px", "z-index:2147483647",
    "font:600 16px system-ui,sans-serif", "color:#fff", "background:rgba(11,16,32,.85)",
    "border:1px solid rgba(255,255,255,.3)", "border-radius:10px", "padding:9px 16px",
    "cursor:pointer", "box-shadow:0 6px 20px rgba(0,0,0,.4)",
    "opacity:0", "pointer-events:none", "transition:opacity .2s",
  ].join(";"));
  btn.addEventListener("click", (e) => { e.preventDefault(); e.stopPropagation(); goMenu(); });
  let hideTimer;
  function show() {
    btn.style.opacity = "1";
    btn.style.pointerEvents = "auto";
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      if (!btn.matches(":hover")) { btn.style.opacity = "0"; btn.style.pointerEvents = "none"; }
    }, 3000);
  }
  btn.addEventListener("mouseleave", show);
  document.addEventListener("mousemove", show, { passive: true });
  (document.body || document.documentElement).appendChild(btn);
})();
