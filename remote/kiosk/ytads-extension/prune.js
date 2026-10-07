// Remove anuncios do YouTube (TV/leanback e web) antes que o player os veja.
// O player recebe a lista de anuncios dentro do JSON da resposta "player"
// (adPlacements, playerAds, adSlots); sem esses campos ele toca direto o video.
// Mesma ideia do scriptlet json-prune do uBlock Origin, que o uBO Lite (MV3) nao
// aplica na interface de TV.
(() => {
  const AD_KEYS = ["adPlacements", "playerAds", "adSlots", "adBreakHeartbeatParams"];
  const strip = (obj, depth = 0) => {
    if (!obj || typeof obj !== "object" || depth > 4) return obj;
    for (const k of AD_KEYS) if (k in obj) delete obj[k];
    // respostas em lote (ex.: { playerResponse: {...} } ou arrays)
    for (const v of Object.values(obj)) {
      if (v && typeof v === "object" && (Array.isArray(v) || "playabilityStatus" in v || "playerResponse" in v)) {
        strip(v, depth + 1);
      }
    }
    if (obj.playerResponse) strip(obj.playerResponse, depth + 1);
    return obj;
  };

  const origParse = JSON.parse;
  JSON.parse = function (text, reviver) {
    const out = origParse.call(this, text, reviver);
    try {
      if (typeof text === "string" && (text.includes("adPlacements") || text.includes("playerAds"))) strip(out);
    } catch (_) {}
    return out;
  };

  const origJson = Response.prototype.json;
  Response.prototype.json = async function () {
    const out = await origJson.call(this);
    try { strip(out); } catch (_) {}
    return out;
  };

  // resposta inicial embutida na pagina (web): ytInitialPlayerResponse
  let initial;
  try {
    Object.defineProperty(window, "ytInitialPlayerResponse", {
      configurable: true,
      get: () => initial,
      set: (v) => { initial = strip(v); },
    });
  } catch (_) {}
})();
