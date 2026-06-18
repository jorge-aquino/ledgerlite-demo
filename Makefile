.PHONY: up down logs seed attack tidy

# Load variables from .env if it exists (used for psql credentials below).
-include .env
export

# ── Docker Compose targets ───────────────────────────────────────────────────

up:
	docker compose up --build -d

down:
	docker compose down -v

logs:
	docker compose logs -f app

# ── Database helpers ─────────────────────────────────────────────────────────

seed:
	@echo ">>> Loading seed data..."
	@docker compose exec -T db \
		psql --username=$${POSTGRES_USER:-ledger} --dbname=$${POSTGRES_DB:-ledgerlite} \
		< internal/db/seed.sql
	@echo ">>> Seed complete."

# ── Attack demo ──────────────────────────────────────────────────────────────

attack:
	@echo ">>> Running attack-demo.sh..."
	@docker compose exec -T db \
		psql --username=$${POSTGRES_USER:-ledger} --dbname=$${POSTGRES_DB:-ledgerlite} \
		< scripts/attack-demo.sh
	@echo ">>> Attack demo complete."

# ── Go helpers ───────────────────────────────────────────────────────────────

tidy:
	go mod tidy
