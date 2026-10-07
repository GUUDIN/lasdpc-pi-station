# Frota de estações (vários cartões / várias Pis)

Cada Pi é uma **estação** que se instala e se atualiza sozinha a partir deste repositório
(público: `https://github.com/GUUDIN/lasdpc-pi-station`). Não é preciso acessar cada Pi para
atualizar: elas buscam o **canal** configurado (padrão `stable`) toda madrugada.

```
GitHub (main) --promover--> GitHub (stable) <--lasdpc-update (04:00 e boot)-- cada Pi
                                                  |-> lasdpc-apply (base + apps)
                                                  |-> lasdpc-health
                                                  '-> rollback automático se falhar
```

## Estação nova (cartão SD)

1. **Raspberry Pi Imager** → *Raspberry Pi OS (64-bit)* **Trixie** (com desktop). Nas
   configurações do Imager: hostname (ex.: `tv-lab-02`), usuário/senha, Wi-Fi do laboratório,
   SSH com chave.
2. Ligue a Pi com a TV e rode (por SSH ou no terminal):

```sh
sudo apt-get install -y git
sudo git clone https://github.com/GUUDIN/lasdpc-pi-station.git /opt/lasdpc-pi-station/repo
sudo /opt/lasdpc-pi-station/repo/install.sh --nome tv-lab-02 --apps "games airplay"
sudo reboot
```

3. (Opcional) Spotify oficial: gere a chave em https://developer.spotify.com/dashboard/soloist
   com uma conta Premium e rode `sudo lasdpc-soloist-setkey`.

O primeiro `install.sh` com o app `games` compila o core N64 (~30 min no Pi 4).

## Apps

| App | Obrigatório | O que é |
|---|---|---|
| `dashboard` | sim | painel IoT no kiosk (URL em Ajustes ou `DASHBOARD_URL`) |
| `youtube` | sim | YouTube TV sem anúncios, 1080p por hardware |
| `spotify` | sim | Spotify Connect "TV LASDPC" (Soloist; librespot de reserva) |
| `desktop` | sim | ambiente gráfico normal |
| `games` | não | RetroArch + N64 rápido + perfis por jogo |
| `airplay` | não | espelhar iPhone/Mac (UxPlay), botão em Ajustes |
| `kodi` | não | central de mídia |

Ligar/desligar apps opcionais numa estação: edite `APPS` em `/etc/lasdpc/station.conf` e rode
`sudo lasdpc-apply`.

### Criar um app

`apps/<id>/app.json`:

```json
{
  "id": "meuapp", "name": "Meu App", "icon": "🧪", "sub": "descrição curta", "order": 70,
  "required": false,
  "launch": {"type": "kiosk", "url": "http://localhost:8090/meuapp.html", "persistent": true},
  "loading": "Abrindo meu app"
}
```

- `launch.type`: `kiosk` (página no Chromium; `persistent: true` relança se cair), `command`
  (`"command": "..."`; `"on_exit": "menu"` volta ao menu quando fecha) ou `desktop`.
- `panel`: abre um painel do menu em vez do app (ex.: lista de jogos).
- `tile: false` + `settings_button`: aparece como botão em Ajustes (ex.: AirPlay).
- `services`: units do systemd do usuário ligadas só enquanto o app está em tela.
- `aliases`: nomes antigos do modo (ex.: `musica` → `spotify`).
- `install.sh` (opcional, roda como root no `lasdpc-apply`, deve ser idempotente; use
  `station/lib/common.sh`) e `check.sh` (opcional, usado pelo `lasdpc-health`).

Cada app roda num scope do systemd do usuário; trocar de modo para o scope e encerra todos os
processos dele. Não é preciso escrever lógica de "fechar o app".

## Publicar uma atualização

1. Desenvolva no `main` e teste numa Pi de desenvolvimento com `CHANNEL="main"` no
   `/etc/lasdpc/station.conf` (`sudo lasdpc-update` aplica na hora).
2. Promova para a frota: `git push origin main:stable`.
3. As estações aplicam entre 04:00 e 04:45 (ou no boot). Para aplicar já: `sudo lasdpc-update`.

Estado da última atualização: `cat /var/lib/lasdpc/update.json` (`ok`, `rolled_back` com o
motivo, ou `failed`). Uma versão que falhou não é tentada de novo até sair outra
(`sudo lasdpc-update --force` força). Saúde da estação: `sudo lasdpc-health`.

## O que fica em cada Pi (fora do repositório)

| Caminho | Conteúdo |
|---|---|
| `/etc/lasdpc/station.conf` | nome, canal, apps opcionais, usuário, dashboard, áudio |
| `/etc/lasdpc/soloist.env` | chave do Spotify Soloist (600, root) |
| `/srv/lasdpc-pi-station/` | ROMs, saves e dados — nunca tocados por atualizações |
| `/opt/lasdpc-pi-station/repo` | checkout do agente (não edite; use um clone de desenvolvimento) |

## Estado e limitações

- Validado nesta Pi (Bookworm): `lasdpc-apply` converge em ~1 min; ciclo atualização →
  falha → rollback → versão pulada → correção aplicada testado com um servidor git local.
- Cartão novo com **Trixie** ainda não testado (precisa de um cartão livre).
- Os scripts antigos em `scripts/` + `Makefile` (instalação "empurrada" por SSH a partir de uma
  máquina de controle) continuam para a stack IoT e o legado; o caminho padrão é este.
