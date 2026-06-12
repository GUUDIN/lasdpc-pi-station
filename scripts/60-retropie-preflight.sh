#!/usr/bin/env bash
# ============================================================
# 60 — Preflight de compatibilidade do RetroPie (SOMENTE LEITURA).
# NÃO instala nada. Gera relatório e um veredito claro.
# Bloqueia se a versão do Raspberry Pi OS não for comprovadamente suportada.
# ============================================================
. "$(dirname "$0")/lib/common.sh"
load_env

REPORT="$LOG_DIR/retropie-preflight-$(ts).md"
log "Etapa 10 — preflight RetroPie (read-only) -> $REPORT"

INFO=$(pi_ssh '
. /etc/os-release
echo "CODENAME=$VERSION_CODENAME"
echo "OS=$PRETTY_NAME"
echo "ARCH=$(dpkg --print-architecture)"
echo "MODEL=$(tr -d "\0" < /proc/device-tree/model 2>/dev/null)"
echo "GCC=$(gcc --version 2>/dev/null | head -1 || echo ausente)"
echo "SESSION=${XDG_SESSION_TYPE:-?}"
echo "COMPOSITOR=$(pgrep -ax labwc >/dev/null && echo labwc-wayland || echo outro)"
echo "FREE_GB=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)"
echo "KODI=$(command -v kodi >/dev/null 2>&1 && echo sim || echo nao)"
echo "RETROPIE_DIR=$( [ -d /opt/retropie ] && echo existe || echo ausente )"
echo "ES=$(command -v emulationstation >/dev/null 2>&1 && echo sim || echo nao)"
echo "ROMS_DIR=$( [ -d $HOME/RetroPie/roms ] && echo existe || echo ausente )"
echo "--- controles USB ---"
lsusb 2>/dev/null | grep -iE "gamepad|joystick|controller|xbox|playstation|sony|microsoft|8bitdo" || echo "(nenhum gamepad USB óbvio)"
echo "--- bluetooth ---"
( command -v bluetoothctl >/dev/null 2>&1 && echo "bluetoothctl presente" ) || echo "(bluetooth util ausente)"
echo "--- /dev/input/js* ---"
ls /dev/input/js* 2>/dev/null || echo "(sem joysticks conectados)"
')

CODENAME=$(echo "$INFO" | grep '^CODENAME=' | cut -d= -f2)
ARCH=$(echo "$INFO" | grep '^ARCH=' | cut -d= -f2)
FREE=$(echo "$INFO" | grep '^FREE_GB=' | cut -d= -f2)

# Versões de Raspberry Pi OS comprovadamente suportadas pelo RetroPie-Setup
# (oficial: até Bookworm/Debian 12). Trixie/Debian 13 NÃO suportado.
SUPPORTED="buster bullseye bookworm"
COMPAT="NAO"
echo "$SUPPORTED" | grep -qw "$CODENAME" && COMPAT="SIM"

{
  echo "# Relatório de Compatibilidade — RetroPie"
  echo
  echo "- Data: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Host: ${PI_USER}@${PI_HOST}"
  echo
  echo "## Dados coletados"
  echo '```'
  echo "$INFO"
  echo '```'
  echo
  echo "## Veredito"
  if [ "$COMPAT" = "SIM" ] && [ "$ARCH" = "arm64" -o "$ARCH" = "armhf" ]; then
    echo "**COMPATÍVEL** — codename '$CODENAME' está na lista suportada. Pode prosseguir com 'make retropie'."
  else
    echo "**INCOMPATÍVEL / BLOQUEADO** — o Raspberry Pi OS é **'$CODENAME' (Debian 13 / Trixie)**, que **não** é"
    echo "oficialmente suportado pelo RetroPie-Setup (suporte vai até **Bookworm/Debian 12**)."
    echo
    echo "### Por que não forçar"
    echo "- O RetroPie-Setup compila emuladores assumindo libs/toolchain do Bookworm; em Trixie há quebras"
    echo "  de dependências (GCC/SDL/bibliotecas) que podem corromper o ambiente."
    echo "- Forçar violaria os princípios do projeto (não forçar dependências antigas, não quebrar o OS)."
    echo
    echo "### Alternativa segura recomendada (sem tocar neste OS)"
    echo "1. Use uma **segunda unidade** (microSD ou SSD USB **dedicado a jogos**) com uma imagem própria:"
    echo "   - **Batocera** (recomendado p/ Pi 4, atualizado), **Recalbox**, ou uma **imagem RetroPie compatível**."
    echo "2. Mantenha este cartão (Raspberry Pi OS Trixie) **intacto** como sistema principal."
    echo "3. Para jogar, troque o boot para a unidade de jogos (ver docs/gaming.md: seleção de boot)."
    echo "4. **Nenhuma imagem será gravada sem sua autorização explícita.**"
    echo
    echo "A arquitetura preferencial continua sendo um único Raspberry Pi OS quando houver compatibilidade segura;"
    echo "a unidade separada é apenas a alternativa enquanto o RetroPie não suportar Trixie."
  fi
} | tee "$REPORT" >/dev/null

cat "$REPORT"
echo
if [ "$COMPAT" = "SIM" ]; then
  ok "RetroPie COMPATÍVEL — revise $REPORT e rode 'make retropie' se desejar."
else
  warn "RetroPie BLOQUEADO (Trixie). Relatório: $REPORT. Alternativa documentada em docs/gaming.md."
  warn "O alvo 'make retropie' deve permanecer NÃO executado neste OS."
fi
