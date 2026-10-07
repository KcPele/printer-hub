.DEFAULT_GOAL := help
BACKEND := backend
UV := cd $(BACKEND) && uv run

.PHONY: help
help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Install dependencies and create backend/.env
	cd $(BACKEND) && uv sync
	pnpm install
	@test -f $(BACKEND)/.env || cp $(BACKEND)/.env.example $(BACKEND)/.env

.PHONY: infra
infra: ## Start Postgres, Redis, and MinIO
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
dev: ## Run the API (with its embedded worker) with reload on :8000
	$(UV) uvicorn app.main:app --reload --port 8000

.PHONY: worker
worker: ## Run the worker as its own process (set PRINTERHUB_EMBEDDED_WORKER=false on the API)
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
openapi: ## Regenerate the API contract and the TypeScript and Dart clients from it
	$(UV) python -m scripts.export_openapi
	pnpm api:generate
	$(MAKE) dart-client

.PHONY: dart-client
dart-client: ## Regenerate the Dart API client from backend/openapi.json
	cd printerhub/packages/api_client && rm -rf lib/src/generated
	cd printerhub/packages/api_client && dart run swagger_parser
	cd printerhub/packages/api_client && dart run build_runner build --delete-conflicting-outputs
	cd printerhub/packages/api_client && dart format lib/src/generated > /dev/null
	cd printerhub/packages/api_client && python3 tool/make_fixtures.py

.PHONY: client-check
client-check: ## Typecheck and test the TypeScript API client
	pnpm api:check

.PHONY: app-check
app-check: ## Analyze and test the Flutter app and its packages (100% coverage required)
	cd printerhub && dart format --set-exit-if-changed lib test packages
	cd printerhub && flutter analyze
	cd printerhub && dart pub global run very_good_cli:very_good test --recursive --coverage --min-coverage 100 --exclude-coverage '**/*.g.dart'

.PHONY: app-simulator-test
app-simulator-test: ## Run the app's printer protocols against the simulator (needs `make simulator`)
	cd printerhub/packages/printer_protocols && dart test --tags simulator

.PHONY: app-smoke
app-smoke: ## Run the Dart API client against a local backend (needs `make dev`)
	cd printerhub/packages/api_client && dart run tool/smoke.dart

.PHONY: app-goldens
app-goldens: ## Regenerate the golden images after an intended visual change
	cd printerhub/packages/app_ui && flutter test --update-goldens --tags golden

.PHONY: app-dev
app-dev: ## Run the Flutter app's development flavor on a connected device or simulator
	cd printerhub && flutter run --flavor development --target lib/main_development.dart

.PHONY: check
check: lint typecheck test client-check ## Everything backend CI runs (the app has app-check)
