#!/bin/bash
# ============================================================
# provision.sh — roda no pen drive provisionador, na tela (tty1), como root.
#   1. espera um cartao no slot SD
#   2. teste DESTRUTIVO do cartao (capacidade falsa, setores ruins, velocidade)
#      reprovado -> mostra em vermelho e espera trocar o cartao (testa o proximo)
#   3. baixa o Raspberry Pi OS da internet e grava direto no cartao (sha256)
#   4. configura o 1o boot (cloud-init): usuario/senha do lab, Wi-Fi, SSH, nome,
#      e instala a LASDPC Station sozinho (apps do provision.conf)
#   5. reinicia: a Pi tenta o cartao antes do USB, entao liga no sistema novo
# Configuracao: /boot/firmware/lasdpc/provision.conf (gerado pelo
# lasdpc-make-provisioner; editavel em qualquer computador: particao "bootfs").
# Variaveis de teste: TARGET (dispositivo/arquivo), NO_REBOOT=1, SKIP_TEST=1.
# ============================================================
set -uo pipefail
HERE=/boot/firmware/lasdpc
[ -d "$HERE" ] || HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/provision.conf"
TARGET="${TARGET:-/dev/mmcblk0}"
OS_URL="${OS_URL:-https://downloads.raspberrypi.com/raspios_arm64_latest}"
LOG="$HERE/ultimo-provisionamento.log"

R=$'\e[1;41;97m'; G=$'\e[1;42;30m'; Y=$'\e[1;43;30m'; B=$'\e[1m'; N=$'\e[0m'
banner() { clear; printf '%s\n\n' "${B}══════  LASDPC Station — provisionador  ══════${N}"; }
say()    { echo "$*" | tee -a "$LOG"; }
big()    { printf '\n%s  %s  %s\n\n' "$1" "$2" "$N"; echo "== $2" >> "$LOG"; }
part()   { case "$TARGET" in *[0-9]) echo "${TARGET}p$1" ;; *) echo "${TARGET}$1" ;; esac; }   # mmcblk0p1, sda1

# fonte grande na TV (console)
setfont /usr/share/consolefonts/Lat15-TerminusBold28x14.psf.gz 2>/dev/null || true
: > "$LOG"

# nunca gravar no proprio pen drive
root_disk="/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null)"
if [ "$root_disk" = "$TARGET" ]; then
  banner; big "$R" "O sistema iniciou pelo CARTAO, nao pelo pen drive."
  say "Para provisionar: use um cartao vazio (a Pi so cai no pen drive se o cartao nao inicia)."
  exit 1
fi

wait_card() {
  banner; say "Insira o cartao SD a testar/instalar no slot da Pi..."
  until [ -b "$TARGET" ] || [ -f "$TARGET" ]; do sleep 1; done
  sleep 2
}

wait_swap() {   # espera tirar o cartao e por outro
  say ""; say "Retire este cartao. Para testar outro, insira o proximo."
  while [ -b "$TARGET" ]; do sleep 1; done
  wait_card
}

wait_net() {
  for _ in $(seq 60); do curl -fsI --max-time 5 https://downloads.raspberrypi.com >/dev/null 2>&1 && return 0; sleep 2; done
  return 1
}

ensure_tools() {
  local miss=()
  command -v f3probe >/dev/null || miss+=(f3)
  command -v fio >/dev/null || miss+=(fio)
  command -v xz >/dev/null || miss+=(xz-utils)
  [ ${#miss[@]} -eq 0 ] && return 0
  say "Instalando ferramentas de teste (${miss[*]})..."
  apt-get update -qq >>"$LOG" 2>&1; apt-get install -y -qq "${miss[@]}" >>"$LOG" 2>&1
}

# cartao falso aprovado: a imagem gravada so pode ocupar a parte real. Estica a
# raiz (p2) ate o limite real, cria uma particao "tampao" (p3, tipo da) sobre a
# area que nao existe e tira o "resize" do 1o boot (que esticaria ate o fim declarado).
limit_to_real() {  # limit_to_real <ultimo setor real>
  local last="$1" dev="$TARGET" p2start end loopdev="" p2 bt
  end=$(( (last + 1 - 32768) / 8192 * 8192 ))          # margem de 16 MiB, alinhado a 4 MiB
  p2start="$(sfdisk -d "$dev" | awk -F'[=,]' '/start=/{n++; if(n==2){print $2+0; exit}}')"
  [ -n "$p2start" ] && [ "$end" -gt "$p2start" ] || return 1
  echo "$p2start,$(( end - p2start )),83" | sfdisk -q --no-reread --no-tell-kernel -N 2 "$dev" >>"$LOG" 2>&1 || return 1
  echo "$end,,da" | sfdisk -q --no-reread --no-tell-kernel --append "$dev" >>"$LOG" 2>&1 || return 1
  if [ -f "$dev" ]; then loopdev="$(losetup -fP --show "$dev")"; p2="${loopdev}p2"; bt="${loopdev}p1"
  else partprobe "$dev" 2>/dev/null; udevadm settle; p2="$(part 2)"; bt="$(part 1)"; fi
  e2fsck -fy "$p2" >>"$LOG" 2>&1; resize2fs "$p2" >>"$LOG" 2>&1 || { [ -n "$loopdev" ] && losetup -d "$loopdev"; return 1; }
  local m; m="$(mktemp -d)"; mount "$bt" "$m" && sed -i 's/ resize\b//' "$m/cmdline.txt" && umount "$m"; rmdir "$m"
  [ -n "$loopdev" ] && losetup -d "$loopdev"
  return 0
}

serial4() { tr -d '\0' < /sys/firmware/devicetree/base/serial-number 2>/dev/null | tail -c 4 || echo "$RANDOM"; }

write_cloudinit() {  # write_cloudinit <ponto de montagem do bootfs do cartao>
  local bt="$1" host="${NAME_PREFIX:-lasdpc-}$(serial4)"
  # 1o boot: usuario do lab, SSH, nome; depois instala a estacao sozinho
  cat > "$bt/user-data" <<EOF
#cloud-config
hostname: $host
manage_etc_hosts: true
timezone: ${TIMEZONE:-America/Sao_Paulo}
keyboard:
  model: pc105
  layout: ${KEYBOARD:-br}
users:
- name: $LAB_USER
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: '$LAB_PASS_HASH'
  sudo: ALL=(ALL) NOPASSWD:ALL
$( [ -n "${SSH_KEY:-}" ] && printf '  ssh_authorized_keys:\n  - %s\n' "$SSH_KEY" )
ssh_pwauth: true
write_files:
- path: /var/lib/lasdpc/preseed
  permissions: '0600'
  content: |
    lasdpc-station lasdpc-station/sdcheck boolean false
    lasdpc-station lasdpc-station/name string $host
    lasdpc-station lasdpc-station/apps multiselect $(echo "${APPS:-}" | sed 's/ \+/, /g')
    lasdpc-station lasdpc-station/channel select ${CHANNEL:-stable}
    lasdpc-station lasdpc-station/dashboard_url string ${DASHBOARD_URL:-http://localhost:8080}
    lasdpc-station lasdpc-station/spotify_key select ${SPOTIFY_KEY_MODE:-depois}
- path: /usr/local/sbin/lasdpc-firstboot
  permissions: '0755'
  content: |
    #!/bin/sh
    # instala a LASDPC Station no 1o boot (cartao gravado pelo provisionador)
    exec >>/var/log/lasdpc-firstboot.log 2>&1
    n=0; until curl -fsSL -o /tmp/lasdpc.deb https://guudin.github.io/lasdpc-pi-station/lasdpc.deb; do
      n=\$((n+1)); [ \$n -ge 30 ] && exit 1; sleep 10; done
    debconf-set-selections /var/lib/lasdpc/preseed
    DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=1200 install -y /tmp/lasdpc.deb || exit 1
    # espera a instalacao em segundo plano (lasdpc-setup-*) e reinicia na estacao
    sleep 20
    while systemctl list-units --no-legend --state=activating,active 'lasdpc-setup-*' | grep -q .; do sleep 15; done
    systemctl reboot
runcmd:
- [systemctl, enable, --now, ssh]
- [sh, -c, "systemd-run --unit=lasdpc-firstboot --collect /usr/local/sbin/lasdpc-firstboot"]
EOF
  cat > "$bt/network-config" <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
$( if [ -n "${WIFI_SSID:-}" ]; then printf '  wifis:\n    wlan0:\n      dhcp4: true\n      optional: true\n      regulatory-domain: %s\n      access-points:\n        "%s":\n          password: "%s"\n' "${WIFI_COUNTRY:-BR}" "$WIFI_SSID" "$WIFI_PSK"; fi )
EOF
  printf 'dsmode: local\ninstance_id: lasdpc-%s-%s\n' "$host" "$(date +%s)" > "$bt/meta-data"
  : > "$bt/ssh"
  echo "$host"
}

# ---------------------------------------------------------------- fluxo
while true; do
  REAL_LAST=""
  wait_card
  banner
  size=$(( $( [ -b "$TARGET" ] && blockdev --getsize64 "$TARGET" || stat -c %s "$TARGET") / 1000000000 ))
  say "Cartao detectado: $TARGET (${size} GB declarados)"
  say "Esperando a rede..."
  wait_net || { big "$R" "SEM INTERNET: ligue o cabo de rede e reinicie a Pi."; exit 1; }
  ensure_tools

  # ---- 1. teste destrutivo
  if [ "${SKIP_TEST:-0}" != 1 ]; then
    say ""; say "${B}1/3  Testando o cartao (apaga tudo; ~3-5 min)...${N}"
    out="$(LASDPC_SDCHECK_YES=1 LASDPC_MIN_REAL_GB="${MIN_REAL_GB:-12}" "$HERE/lasdpc-sdcheck" --destrutivo "$TARGET" 2>&1)"; rc=$?
    echo "$out" | grep -v '^LASDPC_' | tee -a "$LOG" | tail -n 16
    REAL_LAST="$(echo "$out" | sed -n 's/^LASDPC_ULTIMO_SETOR_REAL=//p')"
    if [ $rc -ge 2 ]; then
      big "$R" "CARTAO REPROVADO — nao use este cartao."
      wait_swap; continue
    elif [ $rc = 1 ]; then
      big "$Y" "Cartao com RESSALVAS (veja acima): funciona. Continuando em 15 s..."
      sleep 15
    else
      big "$G" "Cartao APROVADO"
    fi
  fi

  # ---- 2. baixar e gravar o Raspberry Pi OS
  say "${B}2/3  Baixando o Raspberry Pi OS e gravando no cartao (~1,4 GB)...${N}"
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$OS_URL")"
  sum="$(curl -fsSL "$url.sha256" | awk '{print $1}')"
  say "imagem: $(basename "$url")"
  curl -fsSL "$url" | tee >(sha256sum | awk '{print $1}' > /tmp/lasdpc-img.sum) \
    | xz -dc | dd of="$TARGET" bs=4M iflag=fullblock status=progress conv=fsync 2>&1 | tr '\r' '\n' | tail -n 1
  sleep 2
  if [ "$(cat /tmp/lasdpc-img.sum 2>/dev/null)" != "$sum" ] || [ -z "$sum" ]; then
    big "$R" "Download corrompido (sha256 nao confere). Tentando de novo..."; continue
  fi
  say "imagem gravada e conferida (sha256)"
  if [ -n "${REAL_LAST:-}" ]; then
    say "cartao falso: limitando o sistema a parte real do cartao..."
    limit_to_real "$REAL_LAST" || { big "$R" "Nao consegui limitar o cartao falso — nao use este cartao."; wait_swap; continue; }
  fi

  # ---- 3. configurar o 1o boot
  say "${B}3/3  Configurando o primeiro boot...${N}"
  [ -b "$TARGET" ] && { partprobe "$TARGET" 2>/dev/null; udevadm settle; }
  mnt="$(mktemp -d)"
  if [ -f "$TARGET" ]; then   # teste com arquivo de imagem
    off=$(( $(sfdisk -d "$TARGET" | awk -F'[=,]' '/start=/{print $2+0; exit}') * 512 ))
    mount -o loop,offset="$off" "$TARGET" "$mnt"
  else
    mount "$(part 1)" "$mnt"
  fi
  host="$(write_cloudinit "$mnt")"
  sync; umount "$mnt"; rmdir "$mnt"
  big "$G" "PRONTO: cartao gravado como '$host'."
  say "Ao reiniciar, a Pi liga pelo cartao e instala a LASDPC Station sozinha"
  say "(apps: ${APPS:-nenhum opcional}). Pode tirar o pen drive e usar na proxima Pi."
  [ "${NO_REBOOT:-0}" = 1 ] && exit 0
  say "Reiniciando em 15 s..."; sleep 15; systemctl reboot; exit 0
done
