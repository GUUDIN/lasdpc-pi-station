# Etapa 0 — Preflight media/gaming

Data: 2026-06-12

## Evidencia

O alvo `make media-gaming-preflight` foi executado contra a Pi `100.84.255.77`.

Resultado relevante:

- TC-0.1 PASS: Debian 13 Trixie, `aarch64`.
- TC-0.2 PASS: raiz com 46 GB livres.
- TC-0.3 PASS: `throttled=0x0`.
- TC-0.4 PASS em execucao de 2026-06-12 19:49:02; temperatura depois oscilou entre 59.9 C e 60.8 C durante repeticoes do preflight.
- TC-0.5 PASS: `dtoverlay=vc4-kms-v3d` presente.
- TC-0.6 PASS: `bcm2835_codec` carregado apos `modprobe bcm2835-codec`.
- TC-0.7 PASS: Docker ativo; stack `lasdpc-iot` em execucao; 5 containers healthy em checagem posterior.
- TC-0.8 PASS: menu `http://localhost:8090` responde 200.
- TC-0.9 PASS: `lasdpc-mode desktop` e `lasdpc-mode menu` executam sem erro.
- TC-0.10 PASS: `tailscale status` responde.
- TC-0.11 PASS: `avahi-daemon` ativo; `avahi-browse` retorna entradas mDNS.
- TC-0.12 PASS: repositório local presente; `git status` limpo; remoto configurado.
- TC-0.13 PASS operacional: `smriti --help` disponível; registros explícitos feitos via `smriti ingest file`. Observação: esses registros entram como `generic`, e `smriti search --project Development` não os encontrou por project-id.

## Decisao

O operador enviou `continue` após o bloqueio térmico inicial. A Etapa 0 foi considerada liberada com risco térmico documentado, porque houve execução com TC-0.1 a TC-0.11 PASS e a Pi segue sem throttling (`0x0`).

## Risco

A Pi 4 opera perto do limite conservador de idle `< 60 C`. Para media/gaming, monitorar temperatura e throttling em todos os TCs sob carga. Não foi aplicado overclock, `gpu_mem`, `cmdline.txt` ou alteração de `config.txt`.
