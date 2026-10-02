#!/usr/bin/env bash
# ============================================================
# 161 — Core N64 rapido: compila mupen64plus_next (GLideN64/GLES3) na Pi.
# O parallel_n64 do buildbot roda Zelda OoT a ~13 FPS no Pi 4 (parece travado);
# ver remote/bin/lasdpc-n64-core-build.sh. Idempotente; ~30 min no Pi 4.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Core N64 (mupen64plus_next GLES3) em $PI_HOST"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-n64-core-build.sh" "$PI_USER@$PI_HOST:/tmp/lasdpc-n64-core-build.sh"
pi_ssh "sudo install -o root -g root -m 0755 /tmp/lasdpc-n64-core-build.sh /usr/local/bin/lasdpc-n64-core-build.sh"
pi_ssh "/usr/local/bin/lasdpc-n64-core-build.sh"
# a playlist N64 passa a apontar para o core novo
pi_rsync -a "$PROJECT_DIR/remote/launcher/make_n64_playlist.py" "$PI_USER@$PI_HOST:/tmp/make_n64_playlist.py"
pi_ssh "python3 /tmp/make_n64_playlist.py"
ok "Core N64 instalado. O menu central (Jogo) passa a usa-lo automaticamente."
