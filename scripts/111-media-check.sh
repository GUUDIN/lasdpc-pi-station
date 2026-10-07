#!/usr/bin/env bash
# ============================================================
# 111 — Checa perfil media (TC-1.x automatizáveis).
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 1 — checando perfil media em $PI_HOST"

pi_ssh 'set -euo pipefail
  N=$(id -u)
  userctl(){ env XDG_RUNTIME_DIR=/run/user/$N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$N/bus systemctl --user "$@"; }
  pass(){ printf "PASS %s\n" "$1"; }
  fail(){ printf "FAIL %s: %s\n" "$1" "$2"; exit 1; }

  userctl is-active --quiet lasdpc-spotify && pass TC-1.2 || fail TC-1.2 "lasdpc-spotify (Spotify Connect) inativo"
  curl -fsS --max-time 3 "http://127.0.0.1:5354/?action=getInfo" | grep -q "TV LASDPC" && pass TC-1.2-getInfo || fail TC-1.2 "Spotify Connect nao responde em :5354"

  lasdpc-mode media >/tmp/lasdpc-media-check-mode.out
  sleep 5
  userctl is-active --quiet lasdpc-media.target && pass TC-1.4-target || fail TC-1.4 "lasdpc-media.target inativo"
  userctl is-active --quiet uxplay.service && pass TC-1.4-uxplay || fail TC-1.4 "uxplay.service inativo"

  avahi-browse -t _spotify-connect._tcp >/tmp/lasdpc-mdns-spotify.txt 2>/dev/null || true
  avahi-browse -t _raop._tcp >/tmp/lasdpc-mdns-raop.txt 2>/dev/null || true
  grep -q "TV LASDPC" /tmp/lasdpc-mdns-spotify.txt && pass TC-1.3-spotify || fail TC-1.3 "Spotify Connect nao anunciado"
  grep -q "TV LASDPC" /tmp/lasdpc-mdns-raop.txt && pass TC-1.3-airplay || fail TC-1.3 "AirPlay/RAOP nao anunciado"

  errors=$(journalctl --user -u uxplay -b --no-pager 2>/dev/null | grep -Eci "segmentation|traceback|fatal|failed to|cannot open" || true)
  [ "$errors" -eq 0 ] && pass TC-1.6 || fail TC-1.6 "uxplay tem erros fatais no journal"

  lasdpc-mode menu >/tmp/lasdpc-media-check-menu.out
  sleep 3
  if userctl is-active --quiet uxplay.service; then
    fail TC-1.5 "uxplay ainda ativo apos sair do modo media"
  else
    pass TC-1.5
  fi

  {
    echo "## Etapa 1 — media check — $(date -Is)"
    echo "Ações executadas: modo media iniciado; target e uxplay verificados; mDNS Spotify/AirPlay verificado; modo menu restaurado."
    echo "TCs: TC-1.2 PASS; TC-1.3 PASS; TC-1.4 PASS; TC-1.5 PASS; TC-1.6 PASS; TC-1.7 MANUAL-PENDENTE; TC-1.8 MANUAL-PENDENTE; TC-1.9 PENDENTE"
    echo "Próxima etapa liberada: NÃO, aguardando TC-1.7, TC-1.8 e TC-1.9"
    echo
  } >> /var/log/lasdpc/IMPLEMENTACAO.md
'

ok "media-check automatizado concluido; TCs manuais ainda precisam do operador."
