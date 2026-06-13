#!/usr/bin/env bash
# ============================================================
# 121 — Etapa 4: checks AUTOMATIZADOS do perfil gaming.
# TC-4.2 (RetroArch+core N64), TC-4.3 (>=3GB livres), presença ES-DE/cores/wrappers,
# integração lasdpc-mode games -> ES-DE. Exit 0 só se tudo passar (TC-4.10).
# Não cobre TCs manuais (gamepad/jogo) — esses ficam MANUAL-PENDENTE.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 4 — gaming-check em $PI_HOST"
fails=0
check(){ if [ "$1" = 0 ]; then ok "$2"; else err "$2"; fails=$((fails+1)); fi; }

ARCH_TRIPLET="$(pi_ssh 'dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo aarch64-linux-gnu')"
CORE_DIR="/usr/lib/${ARCH_TRIPLET}/libretro"

pi_ssh "command -v retroarch >/dev/null"; check $? "RetroArch presente ($(pi_ssh 'retroarch --version 2>/dev/null | head -1'))"
pi_ssh "test -x /opt/es-de/ES-DE_aarch64.AppImage"; check $? "ES-DE AppImage presente/executável ($(pi_ssh 'head -1 /opt/es-de/VERSION 2>/dev/null'))"
pi_ssh "test -x /usr/local/bin/lasdpc-esde"; check $? "wrapper lasdpc-esde instalado"

for c in nestopia snes9x genesis_plus_gx gambatte parallel_n64; do
  if pi_ssh "ls $CORE_DIR/${c}_libretro.so >/dev/null 2>&1"; then ok "core: $c"; else warn "core ausente: $c (best-effort)"; fi
done
# N64 (TC-4.2): pelo menos um caminho N64 disponível (parallel_n64 OU ares)
if pi_ssh "ls $CORE_DIR/parallel_n64_libretro.so >/dev/null 2>&1 || command -v ares >/dev/null"; then ok "N64 disponível (parallel_n64/ares)"; else err "N64 indisponível"; fails=$((fails+1)); fi

# TC-4.3: >= 3GB livres
FREE=$(pi_ssh "df -BG --output=avail / | tail -1 | tr -dc 0-9")
[ "${FREE:-0}" -ge 3 ]; check $? "espaço livre: ${FREE}G (>=3G)"

# Integração: modo games tem emulador padrão (ares) + ES-DE opt-in disponível
pi_ssh "command -v ares >/dev/null && grep -q 'LASDPC_GAMES_FRONTEND' /usr/local/bin/lasdpc-session"; check $? "games: ares (default) + ES-DE opt-in (ES-DE não renderiza no Pi4 — ver docs)"

# /srv dirs
pi_ssh "test -d /srv/lasdpc-pi-station/roms/n64 && test -d /srv/lasdpc-pi-station/saves"; check $? "diretórios roms/saves em /srv"

echo
if [ "$fails" -eq 0 ]; then ok "gaming-check PASS (TCs automatizados). Manuais (gamepad/jogo): MANUAL-PENDENTE."; exit 0
else err "gaming-check FALHOU em $fails item(ns)."; exit 1; fi
