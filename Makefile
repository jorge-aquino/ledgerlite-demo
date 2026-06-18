.PHONY: up down logs seed attack tidy

# Load variables from .env if it exists (used for psql credentials below).
-include .env
export

DOCKER_COMPOSE := docker compose

# ── Docker Compose targets ───────────────────────────────────────────────────

up:
	$(DOCKER_COMPOSE) up --build -d

down:
	$(DOCKER_COMPOSE) down -v

logs:
	$(DOCKER_COMPOSE) logs -f app

# ── Database helpers ─────────────────────────────────────────────────────────

seed:
	@echo ">>> Loading seed data..."
	@$(DOCKER_COMPOSE) exec -T db \
		psql --username=$${POSTGRES_USER:-ledger} --dbname=$${POSTGRES_DB:-ledgerlite} \
		< internal/db/seed.sql
	@echo ">>> Seed complete."

# ── Attack demo ──────────────────────────────────────────────────────────────

attack:
	@echo ">>> Running attack-demo.sh..."
	@$(DOCKER_COMPOSE) exec -T db \
		psql --username=$${POSTGRES_USER:-ledger} --dbname=$${POSTGRES_DB:-ledgerlite} \
		< scripts/attack-demo.sh
	@echo ">>> Attack demo complete."

# ── Go helpers ───────────────────────────────────────────────────────────────

tidy:
	go mod tidy
