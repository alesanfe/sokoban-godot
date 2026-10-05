# Makefile — Sokoban Mutante
# Juego Godot 4 en la raíz (project.godot) + servidor de comunidad
# Python (server/) + herramientas de capturas/GIF (tools/).
# Requiere: godot en PATH (o GODOT=<ruta>), python, bash.
# Uso: make help

GODOT ?= godot
PY    ?= python

.DEFAULT_GOAL := help
.PHONY: help \
        run \
        test test-runner test-ui test-e2e test-rules test-playthrough test-server test-load verify \
        server \
        shots gif \
        export-web export-windows export-linux \
        clean

# ============================================================
#  HELP
# ============================================================

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ============================================================
#  JUEGO
# ============================================================

run: ## Abre el juego (igual que F5 en el editor)
	$(GODOT) --path .

# ============================================================
#  TESTS (headless)
# ============================================================

test: test-runner test-ui test-e2e test-server ## Batería principal local

test-runner: ## Checks del motor + campaña
	$(GODOT) --headless --path . -s res://tests/test_runner.gd

test-ui: ## UI + comunidad E2E
	$(GODOT) --headless --path . -s res://tests/test_ui.gd

test-e2e: ## E2E de gameplay
	$(GODOT) --headless --path . -s res://tests/test_e2e.gd

test-rules: ## Reglas/mecánicas mutantes
	$(GODOT) --headless --path . -s res://tests/test_rules.gd

test-playthrough: ## Playthrough automatizado de niveles
	$(GODOT) --headless --path . -s res://tests/test_playthrough.gd

test-server: ## Tests del backend de comunidad (sin socket)
	$(PY) server/test_routes.py

test-load: ## Test de concurrencia del servidor
	$(PY) server/test_load.py

verify: ## Verificadores de niveles (clásicos + difíciles)
	$(GODOT) --headless --path . -s res://tests/verify_classics.gd && \
	$(GODOT) --headless --path . -s res://tests/verify_hard.gd

# ============================================================
#  SERVIDOR
# ============================================================

server: ## Levanta el servidor de comunidad
	$(PY) server/community_server.py

# ============================================================
#  ASSETS / EXPORT
# ============================================================

shots: ## Capturas de UI — uso: make shots SHOTS="nombre1 nombre2"
	$(GODOT) --path . -s res://tools/screenshots.gd -- $(SHOTS)

gif: ## Genera el GIF de demo
	$(GODOT) --path . -s res://tools/gif_demo.gd

export-web: ## Exporta el preset "Web" a export/web/
	$(GODOT) --headless --path . --export-release "Web" export/web/index.html

export-windows: ## Exporta "Windows Desktop" a export/windows/
	$(GODOT) --headless --path . --export-release "Windows Desktop" export/windows/sokoban-mutante.exe

export-linux: ## Exporta "Linux/X11" a export/linux/
	$(GODOT) --headless --path . --export-release "Linux/X11" export/linux/sokoban-mutante.x86_64

clean: ## Borra caches y salidas de trabajo de tools/_shots/
	find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	rm -rf tools/_shots/*
