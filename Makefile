# goose-agent-template — Developer CLI
# =====================================

GOOSE_VERSION ?= v1.28.1
COMPOSE_FILE := deploy/docker-compose.yaml
COMPOSE := docker compose -f $(COMPOSE_FILE)
K8S_DIR := deploy/k8s

# === Build ===

.PHONY: build build-goose build-mcp

build: build-goose build-mcp ## Build all images

build-goose: ## Build the Goose runtime image
	docker build -f Dockerfile.goose \
		--build-arg GOOSE_VERSION=$(GOOSE_VERSION) \
		-t goose-runtime:latest .

build-mcp: ## Build MCP server images
	docker build -t mcp-hello-world:latest mcp-servers/hello-world/

# === Local Development (Docker Compose) ===

.PHONY: up down logs restart

up: ## Start all services
	$(COMPOSE) --env-file .env up --build -d

down: ## Stop all services
	$(COMPOSE) --env-file .env down

logs: ## Tail logs for all services
	$(COMPOSE) --env-file .env logs -f

restart: down up ## Rebuild and restart all services

# === Kubernetes ===

.PHONY: deploy-k8s undeploy-k8s

deploy-k8s: ## Apply all k8s manifests
	kubectl apply -f $(K8S_DIR)/namespace.yaml
	kubectl apply -f $(K8S_DIR)/

undeploy-k8s: ## Delete all k8s manifests
	kubectl delete -f $(K8S_DIR)/ --ignore-not-found

# === Utilities ===

.PHONY: clean validate-config help

clean: ## Remove built images and volumes
	$(COMPOSE) --env-file .env down -v --rmi local 2>/dev/null || true
	docker rmi goose-runtime:latest mcp-hello-world:latest 2>/dev/null || true

validate-config: ## Check config files for YAML syntax errors
	@echo "Validating config/config.yaml..."
	@python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))" && echo "  OK" || echo "  FAILED"
	@echo "Validating config/permission.yaml..."
	@python3 -c "import yaml; yaml.safe_load(open('config/permission.yaml'))" && echo "  OK" || echo "  FAILED"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
