.DEFAULT_GOAL := help
BACKEND := backend
UV := cd $(BACKEND) && uv run

.PHONY: help
help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Install dependencies and create backend/.env
	cd $(BACKEND) && uv sync
	@test -f $(BACKEND)/.env || cp $(BACKEND)/.env.example $(BACKEND)/.env

.PHONY: infra
infra: ## Start Postgres, Redis, MinIO, and Soketi
	docker compose up -d --wait

.PHONY: infra-down
infra-down: ## Stop infrastructure (keeps data)
	docker compose down

.PHONY: migrate
migrate: ## Apply database migrations
	$(UV) alembic upgrade head

.PHONY: migration
migration: ## Autogenerate a migration: make migration m="add widgets"
	$(UV) alembic revision --autogenerate -m "$(m)"

.PHONY: seed
seed: ## Load reference data (capability profiles, feature flags)
	$(UV) python -m scripts.seed

.PHONY: dev
dev: ## Run the API with reload on :8000
	$(UV) uvicorn app.main:app --reload --port 8000

.PHONY: worker
worker: ## Run the background worker
	$(UV) arq app.worker.WorkerSettings

.PHONY: simulator
simulator: ## Run the printer simulator on :8631
	$(UV) uvicorn simulator.main:app --reload --port 8631

.PHONY: lint
lint: ## Lint and check formatting
	$(UV) ruff check .
	$(UV) ruff format --check .

.PHONY: format
format: ## Fix lint issues and format
	$(UV) ruff check --fix .
	$(UV) ruff format .

.PHONY: typecheck
typecheck: ## Run mypy
	$(UV) mypy

.PHONY: test
test: ## Run tests
	$(UV) pytest

.PHONY: openapi
openapi: ## Regenerate backend/openapi.json
	$(UV) python -m scripts.export_openapi

.PHONY: check
check: lint typecheck test ## Everything CI runs
