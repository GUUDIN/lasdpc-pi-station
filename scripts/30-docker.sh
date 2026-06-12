#!/usr/bin/env bash
# ============================================================
# 30 — Docker Engine + Compose plugin (repositório OFICIAL).
# Detecta distro/codename/arch, LISTA conflitos (não remove sem mostrar),
# habilita no boot, testa container, configura rotação de logs.
# NÃO usa Docker Desktop, NÃO usa script de conveniência. Idempotente.
# Por segurança, NÃO adiciona o usuário ao grupo docker (= root). Scripts usam sudo.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

log "Etapa 7 — Docker em $PI_HOST"

REMOTE=$(cat <<'REOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
ARCH=$(dpkg --print-architecture)
echo ">> Distro: $ID  codename: $VERSION_CODENAME  arch: $ARCH"
case "$ARCH" in arm64|amd64) ;; *) echo "ERRO: arch $ARCH não suportada por este script"; exit 1 ;; esac

echo ">> Conflitos potenciais (serão listados, não removidos automaticamente)"
CONFLICTS=""
for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  if dpkg -l "$p" 2>/dev/null | grep -q '^ii'; then CONFLICTS="$CONFLICTS $p"; fi
done
if [ -n "$CONFLICTS" ]; then
  echo "   ATENÇÃO, pacotes conflitantes instalados:$CONFLICTS"
  echo "   (não removidos. Remova manualmente se necessário: sudo apt-get remove <pkg>)"
else echo "   nenhum conflito"; fi

if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
  echo ">> Docker já instalado: $(docker --version)"
else
  echo ">> Instalando pré-requisitos e chave/repos oficiais"
  sudo apt-get update -qq
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  echo ">> Instalando Docker Engine + Compose plugin"
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo ">> Habilitar no boot"
sudo systemctl enable --now docker
echo "   docker ativo: $(systemctl is-active docker)"

echo ">> Rotação de logs (json-file 10m x3) — poupa o microSD"
sudo mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  printf '{\n  "log-driver": "json-file",\n  "log-opts": { "max-size": "10m", "max-file": "3" }\n}\n' | sudo tee /etc/docker/daemon.json >/dev/null
  sudo systemctl restart docker
  echo "   daemon.json criado"
else
  echo "   daemon.json já existe (não sobrescrito) — verifique log-opts manualmente"
fi

echo ">> Versões"
sudo docker version --format '   Engine {{.Server.Version}} | CLI {{.Client.Version}}' 2>/dev/null || sudo docker version | head -5
sudo docker compose version

echo ">> Teste: container hello-world (será removido)"
sudo docker run --rm hello-world >/dev/null 2>&1 && echo "   hello-world OK" || { echo "   FALHA no teste de container"; exit 1; }
sudo docker image rm hello-world >/dev/null 2>&1 || true
echo "   imagem de teste removida"

echo ">> NOTA DE SEGURANÇA: pertencer ao grupo 'docker' = acesso root ao host."
echo "   Usuário NÃO foi adicionado ao grupo docker. Os scripts usam 'sudo docker'."
echo "DOCKER-OK"
REOF
)

pi_ssh "$REMOTE" 2>&1 | tee "$LOG_DIR/docker-$(ts).log"
ok "Docker concluído (ver log acima)."
