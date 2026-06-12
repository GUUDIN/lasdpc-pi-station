#!/usr/bin/env bash
# ============================================================
# Instalação do Docker, AUTO-CONTIDA e DESTACADA (roda na Pi como root).
# Repositório OFICIAL. Idempotente. Status em /var/log/lasdpc/docker.status
# NÃO adiciona usuário ao grupo docker (= root); scripts usam sudo.
# ============================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive
mkdir -p /var/log/lasdpc
STATUS=/var/log/lasdpc/docker.status
echo "RUNNING $(date -Iseconds)" > "$STATUS"

. /etc/os-release
ARCH=$(dpkg --print-architecture)
echo ">> Distro $ID codename $VERSION_CODENAME arch $ARCH"

echo ">> Conflitos potenciais (apenas listados)"
for p in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  dpkg -l "$p" 2>/dev/null | grep -q '^ii' && echo "   conflito: $p (não removido)"
done

if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
  echo ">> Docker já instalado: $(docker --version)"
else
  echo ">> Chave + repo oficial"
  apt-get update -qq
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  [ -f /etc/apt/keyrings/docker.gpg ] || { curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; chmod a+r /etc/apt/keyrings/docker.gpg; }
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  echo ">> Instalando Docker Engine + Compose plugin"
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo ">> Habilitar no boot"
systemctl enable --now docker

echo ">> Rotação de logs"
mkdir -p /etc/docker
[ -f /etc/docker/daemon.json ] || { printf '{\n  "log-driver": "json-file",\n  "log-opts": { "max-size": "10m", "max-file": "3" }\n}\n' > /etc/docker/daemon.json; systemctl restart docker; }

echo ">> Versões"
docker version --format '   Engine {{.Server.Version}} | CLI {{.Client.Version}}' 2>/dev/null || true
docker compose version 2>/dev/null || true

echo ">> Teste hello-world (removido em seguida)"
if docker run --rm hello-world >/dev/null 2>&1; then echo "   hello-world OK"; docker image rm hello-world >/dev/null 2>&1 || true; else echo "   FALHA hello-world"; echo "FAILED $(date -Iseconds)" > "$STATUS"; exit 1; fi

echo "DONE $(date -Iseconds)" > "$STATUS"
echo "DOCKER-COMPLETE"
