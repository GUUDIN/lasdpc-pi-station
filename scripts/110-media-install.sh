#!/usr/bin/env bash
# ============================================================
# 110 — Instala perfil media (UxPlay + Spotify Connect + target systemd).
# Spotify: usa o librespot do pacote raspotify, mas como servico do USUARIO da
# sessao (lasdpc-spotify.service: audio pelo PipeWire, descoberta pelo Avahi);
# o servico de sistema da raspotify fica desligado (ver o unit para o porque).
# Idempotente; o repositório é a fonte da verdade.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

RASPOTIFY_VERSION="0.48.3"
RASPOTIFY_PKGVER="0.48.3~librespot.v0.8.0-939dc5e"
RASPOTIFY_DEB="raspotify_0.48.3.librespot.v0.8.0-939dc5e_arm64.deb"
RASPOTIFY_URL="https://github.com/dtcooper/raspotify/releases/download/${RASPOTIFY_VERSION}/${RASPOTIFY_DEB}"
RASPOTIFY_SHA256="2097b3994824cf17163ecc47c6f6a5a695202987e2ab0b650f50d663291c63f2"

log "Etapa 1 — instalando perfil media em $PI_HOST"

log "Enviando artefatos versionados para /tmp na Pi"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-uxplay" "$PI_USER@$PI_HOST:/tmp/lasdpc-uxplay"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-youtube" "$PI_USER@$PI_HOST:/tmp/lasdpc-youtube"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-mode" "$PI_USER@$PI_HOST:/tmp/lasdpc-mode"
pi_rsync -a "$PROJECT_DIR/remote/bin/lasdpc-session" "$PI_USER@$PI_HOST:/tmp/lasdpc-session"
pi_rsync -a "$PROJECT_DIR/remote/launcher/index.html" "$PI_USER@$PI_HOST:/tmp/lasdpc-launcher-index.html"
pi_rsync -a "$PROJECT_DIR/remote/launcher/server.py" "$PI_USER@$PI_HOST:/tmp/lasdpc-launcher-server.py"
pi_rsync -a "$PROJECT_DIR/remote/systemd/user/uxplay.service" "$PI_USER@$PI_HOST:/tmp/uxplay.service"
pi_rsync -a "$PROJECT_DIR/remote/systemd/user/lasdpc-media.target" "$PI_USER@$PI_HOST:/tmp/lasdpc-media.target"
pi_rsync -a "$PROJECT_DIR/remote/systemd/user/lasdpc-spotify.service" "$PI_USER@$PI_HOST:/tmp/lasdpc-spotify.service"

log "Instalando pacotes, Raspotify e units"
pi_ssh "set -euo pipefail
  export DEBIAN_FRONTEND=noninteractive
  sudo install -d -o root -g adm -m 0775 /var/log/lasdpc
  sudo install -d -o root -g root -m 0755 /var/backups/lasdpc

  backup_file() {
    f=\"\$1\"
    [ -e \"\$f\" ] || return 0
    sudo cp -a \"\$f\" \"/var/backups/lasdpc/\$(basename \"\$f\").\$(date +%Y%m%d-%H%M%S)\"
  }

  if ! command -v uxplay >/dev/null 2>&1 || ! command -v avahi-browse >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y uxplay avahi-daemon avahi-utils curl ca-certificates
  else
    sudo apt-get install -y uxplay avahi-daemon avahi-utils curl ca-certificates
  fi
  sudo systemctl enable --now avahi-daemon

  installed_version=\$(dpkg-query -W -f='\${Version}' raspotify 2>/dev/null || true)
  if [ \"\$installed_version\" != \"${RASPOTIFY_PKGVER}\" ]; then
    curl -fsSL '${RASPOTIFY_URL}' -o /tmp/${RASPOTIFY_DEB}
    echo '${RASPOTIFY_SHA256}  /tmp/${RASPOTIFY_DEB}' | sha256sum -c -
    dpkg-deb -I /tmp/${RASPOTIFY_DEB} | sudo tee /var/log/lasdpc/raspotify-deb-inspect.log >/dev/null
    sudo apt-get install -y /tmp/${RASPOTIFY_DEB}
  fi
  # so o binario librespot e usado; o servico de sistema briga com o PipeWire
  sudo systemctl disable --now raspotify || true

  backup_file /usr/local/bin/lasdpc-uxplay
  backup_file /usr/local/bin/lasdpc-youtube
  backup_file /usr/local/bin/lasdpc-mode
  backup_file /usr/local/bin/lasdpc-session
  sudo install -o root -g root -m 0755 /tmp/lasdpc-uxplay /usr/local/bin/lasdpc-uxplay
  sudo install -o root -g root -m 0755 /tmp/lasdpc-youtube /usr/local/bin/lasdpc-youtube
  sudo install -o root -g root -m 0755 /tmp/lasdpc-mode /usr/local/bin/lasdpc-mode
  sudo install -o root -g root -m 0755 /tmp/lasdpc-session /usr/local/bin/lasdpc-session
  session_pids=\$(ps -u ${PI_USER} -o pid=,comm=,args= | while read -r pid comm arg0 arg1 rest; do
    if [ \"\$comm\" = \"bash\" ] && [ \"\$arg0\" = \"bash\" ] && [ \"\$arg1\" = \"/usr/local/bin/lasdpc-session\" ] && [ -z \"\${rest:-}\" ]; then
      echo \"\$pid\"
    fi
  done)
  if [ -n \"\$session_pids\" ]; then
    kill \$session_pids || true
    sleep 2
  fi

  backup_file /opt/lasdpc-pi-station/launcher/index.html
  backup_file /opt/lasdpc-pi-station/launcher/server.py
  sudo install -o ${PI_USER} -g ${PI_USER} -m 0644 /tmp/lasdpc-launcher-index.html /opt/lasdpc-pi-station/launcher/index.html
  sudo install -o ${PI_USER} -g ${PI_USER} -m 0755 /tmp/lasdpc-launcher-server.py /opt/lasdpc-pi-station/launcher/server.py
  sudo systemctl restart lasdpc-launcher.service

  UID_N=\$(id -u ${PI_USER}); UHOME=\$(getent passwd ${PI_USER} | cut -d: -f6)
  userenv() { sudo -u ${PI_USER} env XDG_RUNTIME_DIR=/run/user/\$UID_N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$UID_N/bus \"\$@\"; }
  sudo install -d -o ${PI_USER} -g ${PI_USER} -m 0755 \$UHOME/.config/systemd/user
  for unit in uxplay.service lasdpc-media.target lasdpc-spotify.service; do
    sudo install -o ${PI_USER} -g ${PI_USER} -m 0644 /tmp/\$unit \$UHOME/.config/systemd/user/\$unit
  done
  userenv systemctl --user daemon-reload
  userenv systemctl --user enable lasdpc-spotify.service
  userenv systemctl --user restart lasdpc-spotify.service
  # saida padrao = HDMI (TV); sem isso o PipeWire pode escolher o conector de fone
  hdmi=\$(userenv wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -m1 HDMI | grep -oE '[0-9]+[.]' | head -1 | tr -d .)
  if [ -n \"\$hdmi\" ]; then userenv wpctl set-default \$hdmi; else echo 'AVISO: sink HDMI nao encontrado'; fi

  {
    echo '## Etapa 1 — media install — '\$(date -Is)
    echo 'Ações executadas: uxplay/avahi instalados via apt; raspotify ${RASPOTIFY_VERSION} (.deb oficial, SHA256) so pelo librespot; lasdpc-spotify.service do usuario; saida HDMI; user units instaladas; lasdpc-mode/session atualizados.'
    echo 'Pacotes/versões instalados: uxplay='\$(dpkg-query -W -f='\${Version}' uxplay 2>/dev/null || true)' raspotify='\$(dpkg-query -W -f='\${Version}' raspotify 2>/dev/null || true)
    echo 'Arquivos criados/modificados: /usr/local/bin/lasdpc-uxplay, /usr/local/bin/lasdpc-youtube, /usr/local/bin/lasdpc-mode, /usr/local/bin/lasdpc-session, /opt/lasdpc-pi-station/launcher/{index.html,server.py}, ~/.config/systemd/user/{uxplay.service,lasdpc-media.target,lasdpc-spotify.service}'
    echo 'TCs: TC-1.1 PENDENTE; TC-1.2..TC-1.9 PENDENTES'
    echo 'Próxima etapa liberada: NÃO'
    echo
  } >> /var/log/lasdpc/IMPLEMENTACAO.md
"

ok "media-install concluido. Rode 'make media-check' para os TCs automatizados."
