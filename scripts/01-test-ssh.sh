#!/usr/bin/env bash
# ============================================================
# 01 — Testa SSH (somente leitura). Registra fingerprint do host.
# NUNCA usa StrictHostKeyChecking=no. Não altera a Pi.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Coletando fingerprint do host $PI_HOST:$PI_PORT (registro, não altera nada remoto)"
if ssh-keyscan -p "$PI_PORT" -T 5 "$PI_HOST" 2>/dev/null | ssh-keygen -lf - 2>/dev/null; then
  ok "Fingerprint coletada acima — confira se confere com a esperada da Pi."
else
  warn "Não foi possível coletar fingerprint via ssh-keyscan (host pode estar offline)."
fi

log "Testando conexão SSH (comando read-only: whoami; uname)"
if pi_ssh 'echo CONECTADO; whoami; uname -a' 2>&1; then
  ok "SSH funcional para ${PI_USER}@${PI_HOST}:${PI_PORT}"
else
  die "Falha no SSH. Verifique IP/usuário/porta/chave no .env e a rede."
fi

# Sugere migração para chave se a conexão exigiu senha
if [ ! -f "$PI_SSH_KEY" ]; then
  warn "Você ainda não tem a chave $PI_SSH_KEY. Recomendado migrar para autenticação por chave:"
  warn "  ssh-keygen -t ed25519 -f $PI_SSH_KEY   # NÃO sobrescreva chave existente"
  warn "  ssh-copy-id -i ${PI_SSH_KEY}.pub -p $PI_PORT ${PI_USER}@${PI_HOST}"
fi
ok "Teste de SSH concluído."
