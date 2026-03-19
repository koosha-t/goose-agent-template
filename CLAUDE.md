# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Template repository for deploying custom **Goose AI agents** (by Block) with custom prompts and MCP (Model Context Protocol) tool servers. Goose runs as a REST API server (port 3000) built from Rust source, with MCP servers written in Python using FastMCP.

## Build & Dev Commands

```bash
make build          # Build all Docker images (Goose + MCP servers)
make build-goose    # Build only Goose runtime image (multi-stage Rust build)
make build-mcp      # Build only MCP server images
make up             # Start all services (builds first)
make down           # Stop all services
make restart        # Rebuild and restart everything
make logs           # Tail all service logs
make validate-config # Validate YAML config files (requires pyyaml)
make deploy-k8s     # Apply all Kubernetes manifests
make undeploy-k8s   # Delete all Kubernetes resources
make clean          # Remove images and volumes
```

## Architecture

**Three-layer system:**

1. **Goose Runtime** (`Dockerfile.goose`) — Multi-stage build that compiles Goose from source (pinned v1.28.1), copies config from `config/`, runs `goosed agent` on port 3000.

2. **Configuration** (`config/`) — Agent behavior is defined here:
   - `config.yaml` — Declares active MCP extensions with URI, type, timeout, auth headers
   - `permission.yaml` — Per-tool access control (always_allow / ask_before / never_allow)
   - `prompts/system.md` — Jinja2 template defining agent identity; receives runtime variables (`extensions`, `current_date_time`, `is_autonomous`, `goose_mode`)
   - `prompts/compaction.md`, `prompts/plan.md` — Conversation summarization and planning templates
   - `.goosehints` — Supplementary context with `@filename` import support

3. **MCP Servers** (`mcp-servers/`) — Each server is a self-contained directory with `server.py`, `requirements.txt`, and `Dockerfile`. The hello-world example demonstrates the pattern: FastMCP decorators (`@mcp.tool()`), stateless HTTP transport, JSON responses, and health checks.

**Deployment paths:**
- **Local dev**: `deploy/docker-compose.yaml` orchestrates Goose + MCP containers with env file injection
- **Production**: `deploy/k8s/` has separate Deployment/Service manifests for Goose and MCP servers in the `goose-agent` namespace

## Adding a New MCP Server

1. Create `mcp-servers/<name>/` with `server.py`, `requirements.txt`, `Dockerfile`
2. Add service entry in `deploy/docker-compose.yaml`
3. Register extension in `config/config.yaml` with URI, type, timeout
4. Define tool permissions in `config/permission.yaml`
5. Run `make restart`

## Key Configuration

- `.env.example` — All environment variables: provider selection (`GOOSE_PROVIDER`, `GOOSE_MODEL`), API keys, runtime mode (`GOOSE_MODE`: auto/smart_approve/approve/chat), model parameters, and MCP URIs (overridable for K8s)
- MCP server URIs differ between Docker Compose (service names) and K8s (cluster DNS) — override via env vars
