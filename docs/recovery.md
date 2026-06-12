# Recuperacao

## Voltar para o menu

```sh
lasdpc-mode menu
```

## Voltar para desktop normal

```sh
lasdpc-mode desktop
```

Se o Chromium ou Kodi ficarem presos:

```sh
pkill -f -- '--user-data-dir=.*/lasdpc/chromium-kiosk'
pkill -x kodi.bin
lasdpc-mode menu
```

## Reiniciar servicos do projeto

```sh
sudo systemctl restart lasdpc-launcher.service
sudo systemctl restart lasdpc-healthcheck.timer
```

Stack IoT:

```sh
cd /opt/lasdpc-pi-station/docker
sudo docker compose up -d
```

## Reboot seguro

```sh
sudo reboot
```

Depois de voltar:

```sh
systemctl --failed
sudo docker ps
vcgencmd get_throttled
vcgencmd measure_temp
```

## Backups

Backups ficam em:

```text
/var/backups/lasdpc-pi-station
```

Backups especificos feitos durante correcoes finais:

```text
/var/backups/lasdpc-pi-station/config-fixes/
```

Para restaurar um arquivo de configuracao, inspecione antes:

```sh
sudo ls -lah /var/backups/lasdpc-pi-station/config-fixes
sudo diff -u BACKUP /caminho/atual
sudo install -o root -g root -m MODO BACKUP /caminho/atual
```

## Recuperar SSH

Se Tailscale estiver online, use:

```sh
ssh -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77
```

Se Tailscale cair, tente LAN:

```sh
ssh -i ~/.ssh/id_ed25519 lasdpc@10.0.1.218
```

Se SSH estiver inacessivel, use VNC pela tailnet/LAN e abra um terminal local.

## Recuperar armazenamento

O cartao original falhou. Se houver novos erros ext4/I/O:

1. Parar containers para reduzir escrita: `cd /opt/lasdpc-pi-station/docker && sudo docker compose stop`.
2. Copiar logs e dados persistentes de `/srv/lasdpc-pi-station`.
3. Preparar novo microSD/SSD.
4. Reinstalar sistema e reaplicar scripts do projeto.
5. Restaurar dados e segredos a partir de backup conhecido.

Nao rode formatacao/particionamento sem confirmacao explicita.
