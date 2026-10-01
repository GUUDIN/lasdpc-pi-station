// LASDPC h264ify — roda no contexto da pagina (world: MAIN).
// O Pi 4 so decodifica H.264 por hardware; VP9/AV1 caem para software e
// travam em 1080p, fazendo o YouTube derrubar a qualidade para 480p.
// Rejeitando VP9/AV1 na negociacao de codecs, o YouTube serve H.264.
(function () {
  "use strict";
  // vp8, vp9 (vp09), av1 (av01) — bloqueados. h264 (avc1) passa.
  var BLOCK = /(vp0?[89]|av01)/i;

  if (window.MediaSource && MediaSource.isTypeSupported) {
    var origMSE = MediaSource.isTypeSupported.bind(MediaSource);
    MediaSource.isTypeSupported = function (mime) {
      if (mime && BLOCK.test(mime)) return false;
      return origMSE(mime);
    };
  }

  if (window.HTMLMediaElement && HTMLMediaElement.prototype.canPlayType) {
    var origCanPlay = HTMLMediaElement.prototype.canPlayType;
    HTMLMediaElement.prototype.canPlayType = function (mime) {
      if (mime && BLOCK.test(mime)) return "";
      return origCanPlay.call(this, mime);
    };
  }
})();
