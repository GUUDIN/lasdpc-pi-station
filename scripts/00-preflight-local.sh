#!/usr/bin/env bash
# ============================================================
# 00 — Preflight LOCAL: verifica ferramentas e .env na máquina de controle.
# Não toca na Raspberry Pi. Idempotente.
# ============================================================
. "$(dirname "$0")/lib/common.sh"

log "Preflight local — verificando ferramentas necessárias"
missing=0
for t in ssh scp rsync git make ssh-keygen sftp; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t -> $(command -v "$t")"
  else
    err "$t FALTANDO"
    missing=1
  fi
done
[ "$missing" -eq 0 ] || die "Instale as ferramentas faltantes antes de continuar."

log "Verificando .env"
if [ -f "$PROJECT_DIR/.env" ]; then
  ok ".env presente"
  load_env
  ok "PI_HOST=$PI_HOST  PI_USER=$PI_USER  PI_PORT=$PI_PORT"
  if [ -f "$PI_SSH_KEY" ]; then ok "Chave SSH: $PI_SSH_KEY"; else warn "Chave SSH não encontrada em $PI_SSH_KEY (usará senha)"; fi
else
  warn ".env ausente — copie de .env.example e preencha PI_HOST/PI_USER:"
  warn "  cp .env.example .env && \$EDITOR .env"
fi

log "Verificando resolução do host (se .env existir)"
if [ -f "$PROJECT_DIR/.env" ]; then
  if ping -c1 -W2 "$PI_HOST" >/dev/null 2>&1; then
    ok "Host $PI_HOST responde a ping"
  else
    warn "Host $PI_HOST não respondeu a ping (pode estar bloqueando ICMP; o teste real é o 01-test-ssh.sh)"
  fi
fi
ok "Preflight local concluído."
