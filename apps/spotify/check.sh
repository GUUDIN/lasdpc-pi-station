#!/usr/bin/env bash
# algum receptor Spotify Connect ativo (Soloist com chave, senao a reserva librespot)
if [ -f /etc/lasdpc/soloist.env ]; then
  systemctl is-active --quiet lasdpc-soloist.service || { echo "lasdpc-soloist inativo"; exit 1; }
fi
exit 0
