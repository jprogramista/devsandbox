# =============================================================================
# DEV SANDBOX - Makefile
# =============================================================================
# Usage:
#   make build - build images
#   make up - start the environment
#   make down - stop
#   make shell - connect to the sandbox
#   make logs - show logs
# =============================================================================

.PHONY: build up down restart shell logs clean reset help claude

# Default target
.DEFAULT_GOAL := help

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m

## build: Build Docker images
build:
	@echo "$(GREEN)Building Docker images...$(NC)"
	docker-compose build

## up: Start sandbox environment
up:
	@echo "$(GREEN)Starting dev sandbox...$(NC)"
	docker-compose up -d
	@echo ""
	@echo "$(GREEN)✓ Sandbox is running!$(NC)"
	@echo ""
	@echo "SSH:        ssh -p 2222 developer@localhost"
	@echo "Password:   sandbox"
	@echo ""
	@echo "Ports:"
	@echo "  SSH:          localhost:2222"
	@echo "  Spring Boot:  localhost:8080"
	@echo "  Java Debug:   localhost:5005"
	@echo "  Angular:      localhost:4200"
	@echo "  Node Debug:   localhost:9229"
	@echo "  MySQL:        localhost:3306"
	@echo "  PostgreSQL:   localhost:5432"
	@echo "  Redis:        localhost:6379"

## down: Stop environment
down:
	@echo "$(YELLOW)Stopping dev sandbox...$(NC)"
	docker-compose down

## restart: Restart sandbox
restart: down up

## shell: Connect to sandbox as developer
shell:
	@docker exec -it -u developer -w /workspace dev-sandbox bash

## root-shell: Connect to sandbox as root
root-shell:
	@docker exec -it dev-sandbox bash

## logs: Show sandbox logs
logs:
	docker-compose logs -f sandbox

## logs-all: Show logs of all containers
logs-all:
	docker-compose logs -f

## status: Container status
status:
	docker-compose ps

## claude: Run Claude Code in sandbox
claude:
	@docker exec -it -u developer -w /workspace dev-sandbox claude

## clone: ​​Clone repo (usage: make clone URL=https://github.com/...)
clone:
ifndef URL
	@echo "$(YELLOW)Usage: make clone URL=https://github.com/user/repo.git$(NC)"
else
	@docker exec -it -u developer dev-sandbox clone-repo.sh $(URL)
endif

## backend: Run backend with debug
backend:
	@docker exec -it -u developer -w /workspace/repo dev-sandbox start-backend.sh

## frontend: Run frontend with debug
frontend:
	@docker exec -it -u developer -w /workspace/repo/ui dev-sandbox start-frontend.sh

## clean: Remove stuck containers and unused images
clean:
	@echo "$(YELLOW)Cleaning up...$(NC)"
	docker-compose down
	docker system prune -f

## reset: Complete reset (WARNING: deletes data!)
reset:
	@echo "$(YELLOW)WARNING: This will delete all data including workspace!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	docker-compose down -v
	docker-compose build --no-cache
	docker-compose up -d
	@echo "$(GREEN)✓ Sandbox reset complete!$(NC)"

## db-mysql: Connect to MySQL
db-mysql:
	@docker exec -it dev-mysql mysql -udev -pdev123 devdb

## db-postgres: Connect to PostgreSQL
db-postgres:
	@docker exec -it dev-postgres psql -U dev -d devdb

## db-redis: Connect to Redis
db-redis:
	@docker exec -it dev-redis redis-cli

## help: Show help
help:
	@echo ""
	@echo "$(GREEN)DEV SANDBOX - Available commands:$(NC)"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "$(YELLOW)Quick start:$(NC)"
	@echo "  make build && make up"
	@echo "  make clone URL=https://github.com/user/repo.git"
	@echo "  make shell"
	@echo ""
