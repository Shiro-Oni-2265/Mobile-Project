.PHONY: help init api-up api-down api-logs api-reset api-node api-test clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize the project
	@bash scripts/init.sh

api-up: ## Start the mock API
	docker compose up -d --build api

api-down: ## Stop the mock API
	docker compose down

api-logs: ## View mock API logs
	docker compose logs -f api

api-reset: ## Explicitly discard runtime API edits and restore tracked seed
	docker compose stop api
	cd backend && npm run reset
	docker compose up -d api

api-node: ## Start API in foreground without Docker (npm ci in backend first)
	cd backend && npm start

api-test: ## Run isolated API contract tests
	cd backend && npm test

clean: ## Clean up Docker resources
	docker compose down -v
