# Transferencia legal de ROMs

RetroPie/EmulationStation nao estao instalados neste sistema por incompatibilidade com Trixie. Para uso integrado no Debian atual, o modo `games` abre o emulador multi-sistema `ares`.

## Regra

Transfira apenas ROMs, BIOS e midias que o laboratorio/usuario tenha direito legal de usar. Nao baixe conteudo pirateado pela Pi.

## Metodo por SSH/rsync

Exemplo para uma futura arvore de ROMs:

```sh
rsync -avh --progress ./roms/ lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/
```

Exemplo para N64/Ocarina of Time, usando uma ROM legal fornecida por voce:

```sh
rsync -avh --progress ./Ocarina-of-Time.z64 lasdpc@100.84.255.77:/srv/lasdpc-pi-station/roms/n64/
```

Depois abra **Emulador** no menu da TV e carregue o arquivo pelo menu `Load` do ares.

Exemplo para BIOS:

```sh
rsync -avh --progress ./bios/ lasdpc@100.84.255.77:/srv/lasdpc-pi-station/bios/
```

Crie diretorios com permissoes do usuario `lasdpc`:

```sh
sudo mkdir -p /srv/lasdpc-pi-station/roms /srv/lasdpc-pi-station/bios
sudo chown -R lasdpc:lasdpc /srv/lasdpc-pi-station/roms /srv/lasdpc-pi-station/bios
```

## Metodo por SFTP

```sh
sftp -i ~/.ssh/id_ed25519 lasdpc@100.84.255.77
```

Dentro do SFTP:

```text
cd /srv/lasdpc-pi-station/roms
put arquivo.zip
```

## USB

Monte apenas midias conhecidas e copie para uma area persistente. Evite executar scripts ou binarios vindos do pendrive.

## Backups

ROMs e midias pessoais nao sao compactadas por padrao pelos scripts do projeto. Se precisar inclui-las em backup, confirme antes por causa de tamanho, privacidade e licencas.
