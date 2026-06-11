# Arquitetura

> Documento da estação LASDPC Pi Station. Conteúdo detalhado é preenchido conforme cada fase é executada contra a Pi real.

- 4 modos mutuamente exclusivos (Dashboard/Media/Games/Desktop); stack IoT sempre ativa.
- Diretorios: /opt (codigo), /srv (dados), /var/backups (backups).
- Fluxo: menu central -> modo -> servico; healthcheck e supervisao por systemd.
