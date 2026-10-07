# Spotify Soloist (receptor Spotify Connect oficial) num Debian Trixie minimo.
# O binario exige glibc >= 2.38 e a Pi roda Bookworm (2.36). O binario NAO entra
# na imagem: o Spotify proibe redistribuir e cada build expira em 90 dias; ele e
# baixado do CDN oficial por lasdpc-soloist-update e montado em /opt/soloist.
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libatomic1 libpipewire-0.3-0t64 libpulse0 \
 && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/opt/soloist/soloist"]
