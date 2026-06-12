# ============================================================
# LASDPC Pi Station — orquestração segura por fases.
# Cada alvo é separado. 'deploy' NÃO instala RetroPie (exige passo manual).
# ============================================================
SHELL := /bin/bash
S     := ./scripts

.DEFAULT_GOAL := help

.PHONY: help preflight ssh-test inspect backup base kiosk docker iot kodi \
        retropie-check retropie launcher hardening healthcheck deploy status \
        logs update restore uninstall media-gaming-preflight media-install media-check \
        iot-up iot-down iot-status iot-logs iot-backup iot-update

help: ## Mostra esta ajuda
	@echo "LASDPC Pi Station — alvos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

preflight: ## Preflight LOCAL (ferramentas + .env)
	@$(S)/00-preflight-local.sh
ssh-test: ## Testa SSH (read-only) e registra fingerprint
	@$(S)/01-test-ssh.sh
inspect: ## Coleta informações da Pi (read-only) e valida pré-requisitos
	@$(S)/02-collect-system-info.sh
backup: ## Backup prévio dos arquivos remotos que serão modificados
	@$(S)/03-backup-remote-config.sh
base: ## Sistema-base (hostname, locale, timezone, pacotes, logrotate)
	@$(S)/10-base-system.sh
kiosk: ## Dashboard Chromium em modo kiosk
	@$(S)/20-desktop-kiosk.sh
docker: ## Docker Engine + Compose (repositório oficial)
	@$(S)/30-docker.sh
iot: ## Stack IoT (Mosquitto/Node-RED/Grafana/InfluxDB/homepage)
	@$(S)/40-iot-stack.sh
kodi: ## Kodi e multimídia
	@$(S)/50-kodi.sh
retropie-check: ## Preflight de compatibilidade do RetroPie (NÃO instala)
	@$(S)/60-retropie-preflight.sh
retropie: ## Instala RetroPie (somente após revisar o relatório de compatibilidade)
	@$(S)/61-retropie-install.sh
launcher: ## Menu central LASDPC Station + comandos lasdpc-mode
	@$(S)/70-launcher-ui.sh
hardening: ## Segurança (SSH/firewall/atualizações) — com salvaguardas
	@$(S)/80-hardening.sh
healthcheck: ## Healthcheck (temperatura, throttling, espaço, serviços, containers)
	@$(S)/90-healthcheck.sh
media-gaming-preflight: ## Etapa 0: preflight dos perfis media/gaming
	@$(S)/100-media-gaming-preflight.sh
media-install: ## Etapa 1: instala perfil media (UxPlay + Raspotify)
	@$(S)/110-media-install.sh
media-check: ## Etapa 1: checa perfil media
	@$(S)/111-media-check.sh

deploy: preflight ssh-test inspect backup base docker iot kiosk kodi launcher ## Instala tudo EXCETO RetroPie
	@echo ">> deploy concluído. RetroPie é separado: rode 'make retropie-check' e depois 'make retropie'."

status: ## Estado geral da estação
	@$(S)/90-healthcheck.sh
logs: ## Mostra os logs recentes do projeto
	@ls -lt logs/ | head -20

update: ## Atualizações (sistema/imagens/projeto) — interativo e por etapas
	@$(S)/update-all.sh
restore: ## Restaura configurações a partir de um backup
	@$(S)/restore-config.sh
uninstall: ## Remove SOMENTE componentes do projeto (preserva dados/ROMs/mídia)
	@$(S)/uninstall-project-components.sh

# ---- Atalhos da stack IoT ----
iot-up: ## Sobe a stack IoT
	@$(S)/40-iot-stack.sh up
iot-down: ## Desce a stack IoT
	@$(S)/40-iot-stack.sh down
iot-status: ## Status dos containers IoT
	@$(S)/40-iot-stack.sh status
iot-logs: ## Logs da stack IoT
	@$(S)/40-iot-stack.sh logs
iot-backup: ## Backup dos volumes/configs IoT
	@$(S)/backup-all.sh iot
iot-update: ## Atualiza imagens da stack IoT
	@$(S)/40-iot-stack.sh update
