# LASDPC Pi Station

Configuração reproduzível de uma **Raspberry Pi 4 Model B** (laboratório LASDPC — USP) como estação multifuncional:

- **Dashboard web** permanente para projetos de IoT (Chromium em modo kiosk numa TV);
- **Central multimídia** com Kodi;
- **Estação de jogos retrô** com RetroPie / EmulationStation / RetroArch (quando compatível);
- **Host de serviços IoT** em Docker (Mosquitto, Node-RED, Grafana, InfluxDB 2);
- **Administração remota** por SSH.

> Os modos (Dashboard / Media / Games / Desktop) são **mutuamente exclusivos** para que Chromium, Kodi e EmulationStation não disputem tela e áudio. A stack IoT permanece ativa em todos eles.

## Instalar numa Pi nova (caminho padrão)

```sh
sudo apt-get install -y git
sudo git clone https://github.com/GUUDIN/lasdpc-pi-station.git /opt/lasdpc-pi-station/repo
sudo /opt/lasdpc-pi-station/repo/install.sh --nome tv-lab-02 --apps "games airplay"
```

Cada funcionalidade é um **app** (`apps/<id>/app.json`); dashboard, YouTube, Spotify e desktop
são obrigatórios. A Pi se atualiza sozinha seguindo o canal `stable` (com rollback automático).
Ver **[docs/fleet.md](docs/fleet.md)**. As seções abaixo descrevem a instalação antiga, por
fases, a partir de uma máquina de controle.

## Princípios de segurança

- Nada destrutivo sem inspeção prévia. **Não** formata, **não** particiona, **não** desativa SSH.
- Segredos **nunca** versionados (ver `.gitignore`). Senha da Pi **nunca** é gravada em arquivo — digitada interativamente.
- **Sem** `curl | bash`, **sem** overclock inicial, **sem** ROMs/BIOS piratas.
- Todo arquivo é **backupeado** antes de modificado. Scripts **idempotentes**.
- RetroPie só é instalado **após** relatório de compatibilidade aprovado.

## Estrutura de diretórios

| Local (controle) | Função |
|---|---|
| `scripts/` | Fases `00`→`90` + utilitários (update/backup/restore/uninstall) |
| `scripts/lib/common.sh` | Biblioteca comum (env, SSH seguro, logs) |
| `remote/` | Artefatos enviados à Pi (systemd, kiosk, launcher, config) |
| `docker/` | `compose.yml` + configs da stack IoT |
| `inventory/` | Inventário (exemplos versionados; real ignorado) |
| `docs/` | Documentação detalhada |
| `logs/` | Relatórios de inspeção/backup (ignorados pelo Git) |

| Na Raspberry Pi | Função |
|---|---|
| `/opt/lasdpc-pi-station` | Código/artefatos do projeto |
| `/srv/lasdpc-pi-station` | Dados persistentes (volumes) |
| `/var/backups/lasdpc-pi-station` | Backups com timestamp |

## Pré-requisitos (máquina de controle)

`ssh`, `scp`, `rsync`, `git`, `make`, `ssh-keygen`, `sftp`. Verifique com `make preflight`.

## Configuração inicial

```sh
cp .env.example .env        # preencha PI_HOST, PI_USER, DASHBOARD_URL...
# NUNCA escreva a senha da Pi no .env — a autenticação é por chave SSH.
make preflight              # checa ferramentas locais e .env
make ssh-test               # testa SSH (read-only) e registra a fingerprint
make inspect                # coleta dados da Pi e valida pré-requisitos (read-only)
make backup                 # backup prévio dos arquivos que serão modificados
```

## Instalação por fases

```sh
make base        # sistema-base (hostname, locale, timezone, pacotes, logrotate)
make docker      # Docker Engine + Compose (repo oficial)
make iot         # stack IoT (valida 'docker compose config' antes de subir)
make kiosk       # Chromium kiosk + fallback local
make kodi        # Kodi / multimídia
make launcher    # menu central + comandos lasdpc-mode
make hardening   # segurança (com salvaguarda de sessão SSH paralela)
```

Ou tudo de uma vez (**exceto RetroPie**):

```sh
make deploy
```

### RetroPie (passo separado e obrigatório)

```sh
make retropie-check   # relatório de compatibilidade — NÃO instala
# revise o relatório em logs/ e só então:
make retropie         # instala via repositório oficial RetroPie-Setup
```

Se a versão do Raspberry Pi OS **não** for compatível, o preflight bloqueia e documenta a alternativa (unidade dedicada com Batocera/Recalbox) **sem** alterar o sistema principal. Ver [docs/gaming.md](docs/gaming.md).

## Seleção de modos

```sh
lasdpc-mode dashboard   # Chromium kiosk
lasdpc-mode media       # Kodi
lasdpc-mode games       # EmulationStation
lasdpc-mode desktop     # desktop normal (sempre recuperável)
lasdpc-restart-kiosk
lasdpc-status
```

## Serviços e portas (LAN)

| Serviço | Porta padrão | Observação |
|---|---|---|
| Node-RED | 1880 | bind LAN |
| Grafana | 3000 | senha fora do Compose |
| InfluxDB 2 | 8086 | init por variáveis seguras |
| Mosquitto | 1883 | sem acesso anônimo |
| Homepage | 8080 | status/atalhos locais |

Nenhum serviço é exposto à internet por padrão. Ver [docs/security.md](docs/security.md).

## Operação, manutenção e recuperação

```sh
make status      # healthcheck (temp, throttling, espaço, systemd, containers)
make update      # atualizações por etapas (sistema/imagens/projeto)
make backup      # backup de configs (ROMs/mídia excluídos por padrão)
make restore     # restaura a partir de um backup
make uninstall   # remove só componentes do projeto (preserva dados/ROMs)
```

- **Recuperar o desktop:** `lasdpc-mode desktop` → ver [docs/recovery.md](docs/recovery.md).
- **Recuperar o SSH:** procedimento de salvaguarda em [docs/security.md](docs/security.md).
- **Desligar com segurança:** pelo menu central ou `sudo shutdown -h now`.

## Documentação

- [Arquitetura](docs/architecture.md) · [Instalação](docs/installation.md) · [Operação](docs/operation.md)
- [Troubleshooting](docs/troubleshooting.md) · [Jogos/emulação](docs/gaming.md) · [Transferência de ROMs](docs/rom-transfer.md)
- [Segurança](docs/security.md) · [Recuperação](docs/recovery.md) · [Relatório final](docs/final-report.md)

## Estado atual da implementação

Implantação validada na Pi real em 2026-06-12: base, Docker/Compose, stack IoT 5/5 healthy, kiosk/menu, Kodi, VNC, Tailscale, hardening e healthcheck. RetroPie permanece bloqueado por incompatibilidade com Debian/Raspberry Pi OS 13 Trixie; veja [docs/gaming.md](docs/gaming.md).
