# Seguranca

## SSH

Acesso principal:

```sh
ssh -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77
```

Configuracao aplicada:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
```

O usuario `lasdpc` possui sudo NOPASSWD para administracao remota.

## Firewall

UFW esta ativo:

```text
Default: deny incoming, allow outgoing, deny routed
tailscale0: allow in
41641/udp: allow in
22, 5900, 1880, 3000, 8086, 1883, 8080: allow from 10.0.0.0/22
```

Observacao importante: portas publicadas pelo Docker podem contornar regras UFW via chain `DOCKER`. A protecao real esperada e NAT sem encaminhamento externo, Tailscale e segmentacao da LAN.

## Segredos

Nao versionar:

- `.env`
- `docker/.env`
- `/opt/lasdpc-pi-station/docker/.env`
- tokens do InfluxDB
- senhas de Grafana/MQTT
- chaves SSH privadas

Na Pi, segredos ficam em:

```text
/opt/lasdpc-pi-station/docker/.env
```

Com permissao esperada:

```text
root:root 0600
```

## VNC

WayVNC esta ativo na porta 5900. Use Tailscale sempre que possivel:

```text
100.84.255.77:5900
```

Na LAN, UFW permite VNC apenas de `10.0.0.0/22`.

## Atualizacoes

Atualizacoes longas devem rodar destacadas por systemd para nao depender do SSH:

```sh
sudo systemd-run --unit=lasdpc-upgrade --collect /bin/bash -c '...'
```

Antes de reboot:

```sh
cat /var/log/lasdpc/upgrade.status
sudo dpkg --audit
sudo apt-get -f install
```

## Hardening operacional

- Nao ativar encaminhamento de portas no roteador para esses servicos.
- Nao colocar usuario `lasdpc` no grupo `docker` sem necessidade.
- Nao baixar ROMs/BIOS ou scripts remotos com `curl | bash`.
- Manter backups em `/var/backups/lasdpc-pi-station`.
- Apagar o no Tailscale antigo/stale `lasdpc-pi-display-01` no admin console para recuperar o nome sem sufixo.
