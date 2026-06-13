#!/usr/bin/env bash
# ============================================================
# 150 — Etapa 5: Ship of Harkinian — envia e dispara o build na Pi.
# O build roda detached (systemd-run lasdpc-soh-build) e leva ~40-60 min.
# Acompanhe com: ssh pi 'journalctl --user -u lasdpc-soh-build -f'
# ============================================================
set -euo pipefail
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 5 — SoH install em $PI_HOST"

# Envia build script
pi_ssh 'sudo mkdir -p /usr/local/bin'
scp -i "$PI_SSH_KEY" -o StrictHostKeyChecking=accept-new \
  "$(dirname "$0")/../remote/bin/lasdpc-soh-build.sh" \
  "${PI_USER}@${PI_HOST}:/tmp/lasdpc-soh-build.sh"
pi_ssh 'sudo install -m 755 /tmp/lasdpc-soh-build.sh /usr/local/bin/lasdpc-soh-build.sh'

# Cria diretório de log antes de disparar
pi_ssh 'sudo mkdir -p /var/log/lasdpc && sudo chown lasdpc:lasdpc /var/log/lasdpc'

# Dispara build detached
pi_ssh 'systemd-run --user --unit=lasdpc-soh-build --collect \
  /usr/local/bin/lasdpc-soh-build.sh && echo "SoH build dispatched"'

ok "Build disparado. Acompanhe com:"
ok "  ssh lasdpc@${PI_HOST} 'journalctl --user -u lasdpc-soh-build -f --no-pager'"
ok "  ou: tail -f /var/log/lasdpc/soh-build.log (via SSH)"
