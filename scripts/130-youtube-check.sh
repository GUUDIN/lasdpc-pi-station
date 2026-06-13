#!/usr/bin/env bash
# ============================================================
# 130 — Checa YouTube na TV (parte automatizável do TC-3).
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 3 — checando YouTube na TV em $PI_HOST"

pi_ssh 'set -euo pipefail
  pass(){ printf "PASS %s\n" "$1"; }
  fail(){ printf "FAIL %s: %s\n" "$1" "$2"; exit 1; }

  lasdpc-mode youtube >/tmp/lasdpc-youtube-check-mode.out
  sleep 20

  ps -u lasdpc -o args= > /tmp/lasdpc-youtube-ps.txt
  grep -q -- "--user-data-dir=.*/chromium-youtube-tv" /tmp/lasdpc-youtube-ps.txt \
    && pass TC-3.1-profile || fail TC-3.1 "Chromium YouTube profile nao encontrado"
  grep -q "https://www.youtube.com/tv" /tmp/lasdpc-youtube-ps.txt \
    && pass TC-3.1-url || fail TC-3.1 "URL youtube.com/tv nao encontrada no processo"
  grep -q -- "--user-agent=" /tmp/lasdpc-youtube-ps.txt \
    && pass TC-3.7-ua || fail TC-3.7 "user-agent configuravel nao aplicado"

  lasdpc-mode menu >/tmp/lasdpc-youtube-check-menu.out
  sleep 5
  ps -u lasdpc -o args= > /tmp/lasdpc-youtube-ps-after.txt
  if grep -q -- "--user-data-dir=.*/chromium-youtube-tv" /tmp/lasdpc-youtube-ps-after.txt; then
    fail TC-3.6 "processo Chromium YouTube ficou orfao"
  else
    pass TC-3.6
  fi

  curl -fsS http://localhost:8090 >/dev/null && pass TC-3.6-menu || fail TC-3.6 "menu nao respondeu apos sair do YouTube"

  {
    echo "## Etapa 3 — YouTube auto — $(date -Is)"
    echo "Ações executadas: lasdpc-mode youtube; checagem de Chromium com perfil dedicado, URL youtube.com/tv e user-agent; retorno para menu."
    echo "TCs: TC-3.1 AUTO-PASS-PARCIAL; TC-3.6 PASS; TC-3.7 PASS; TC-3.2 MANUAL-PENDENTE; TC-3.3 MANUAL-PENDENTE; TC-3.4 MANUAL-PENDENTE; TC-3.5 MANUAL-PENDENTE"
    echo "Riscos/observações: validação remota não confirma que o YouTube exibiu código nem que Android/iPhone pareiam; isso exige operador na TV."
    echo "Próxima etapa liberada: NÃO"
    echo
  } >> /var/log/lasdpc/IMPLEMENTACAO.md
'

ok "youtube-check automatizado concluido; pareamento Android/iPhone continua manual."
