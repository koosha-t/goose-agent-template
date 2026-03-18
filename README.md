# goose-agent-template

A template repository for deploying custom [Goose](https://github.com/block/goose) AI agents with your own prompts and MCP tool servers. Goose is an open-source agent framework by Block — this template lets you use it as a runtime for domain-specific agents without forking the source code.

Supports local development with Docker Compose and production deployment on Kubernetes.

> **Alternative interface:** This template uses the Goose REST API (`goosed agent`) for richer session management. If you prefer the simpler [ACP (Agent Client Protocol)](https://github.com/block/goose#acp), see the [Advanced](#advanced) section.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- An LLM API key (Anthropic, OpenAI, Google, etc.)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (optional, for Kubernetes deployment)

## Quickstart

```bash
# 1. Clone the repo
git clone https://github.com/your-org/goose-agent-template.git
cd goose-agent-template

# 2. Configure your provider credentials
cp .env.example .env
# Edit .env — set GOOSE_PROVIDER, GOOSE_MODEL, and your API key

# 3. (Optional) Customize the system prompt
# Edit config/prompts/system.md

# 4. Start the agent
make up

# 5. Interact with the agent at http://localhost:3000
```

## Customizing Your Agent

### System Prompt

Edit `config/prompts/system.md` to define your agent's identity and behavior. This is a [Jinja2 template](https://jinja.palletsprojects.com/) — the following variables are available at runtime:

| Variable | Type | Description |
|----------|------|-------------|
| `extensions` | Array | Active extensions with `.name`, `.instructions`, `.has_resources` |
| `current_date_time` | String | Current timestamp |
| `is_autonomous` | Bool | `true` when mode is `auto` |
| `goose_mode` | Enum | Current mode: Auto, Approve, SmartApprove, Chat |

### Hints

Edit `config/.goosehints` for deployment-specific context that supplements the system prompt. Supports `@filename` imports for larger reference docs.

### Permissions

Edit `config/permission.yaml` to control which tools require approval. Tool names use the pattern `extension_name__tool_name` (double underscore):

```yaml
user:
  always_allow:
    - my-extension__read_data
  ask_before:
    - my-extension__write_data
  never_allow:
    - my-extension__delete_all
```

## Adding an MCP Server

1. Create a directory under `mcp-servers/`:
   ```
   mcp-servers/my-tools/
   ├── server.py
   ├── requirements.txt
   └── Dockerfile
   ```

2. Add a service to `deploy/docker-compose.yaml`:
   ```yaml
   my-tools:
     build:
       context: ../mcp-servers/my-tools
     expose:
       - "8080"
   ```

3. Add an extension entry to `config/config.yaml`:
   ```yaml
   extensions:
     my-tools:
       enabled: true
       type: streamable_http
       name: my-tools
       uri: http://my-tools:8080/mcp
       timeout: 300
   ```

4. Rebuild: `make restart`

See `mcp-servers/hello-world/` for a complete example.

## Connecting to Existing MCP Servers

No container needed. Add an entry to `config/config.yaml`:

```yaml
extensions:
  my-existing-service:
    enabled: true
    type: streamable_http
    name: my-existing-service
    uri: http://my-mcp-server.other-namespace.svc.cluster.local:8080/mcp
    timeout: 300
    # Optional: auth headers (supports ${VAR} substitution)
    # headers:
    #   Authorization: "Bearer ${MCP_AUTH_TOKEN}"
```

## Provider Configuration

| Provider | `GOOSE_PROVIDER` | Required Variables |
|----------|------------------|--------------------|
| Anthropic (Claude) | `anthropic` | `ANTHROPIC_API_KEY` |
| OpenAI | `openai` | `OPENAI_API_KEY` |
| Azure OpenAI | `openai` | `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT` |
| Google (Gemini) | `google` | `GOOGLE_API_KEY` |
| GCP Vertex AI | `gcp-vertex` | `GCP_PROJECT_ID`, `GCP_REGION`, `GOOGLE_APPLICATION_CREDENTIALS` |
| AWS Bedrock | `bedrock` | AWS credentials (env or instance profile) |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` |
| Ollama (local) | `ollama` | None |
| Databricks | `databricks` | Databricks credentials |

Set your provider in `.env`. Only one provider should be active at a time.

## Deploying to Kubernetes

1. Build and push images to your container registry:
   ```bash
   make build
   docker tag goose-runtime:latest your-registry/goose-runtime:latest
   docker tag mcp-hello-world:latest your-registry/mcp-hello-world:latest
   docker push your-registry/goose-runtime:latest
   docker push your-registry/mcp-hello-world:latest
   ```

2. Update image references in `deploy/k8s/goose-deployment.yaml` and `deploy/k8s/mcp-deployment.yaml`.

3. Create secrets:
   ```bash
   cp deploy/k8s/secrets.yaml.example deploy/k8s/secrets.yaml
   # Edit secrets.yaml with base64-encoded values
   kubectl apply -f deploy/k8s/secrets.yaml
   ```

4. Deploy:
   ```bash
   make deploy-k8s
   ```

5. Verify:
   ```bash
   kubectl get pods -n goose-agent
   ```

**TLS:** TLS is disabled by default (`GOOSE_TLS=false`) because the container is expected to run behind a cluster Service or load balancer. To enable TLS for direct external exposure, set `GOOSE_TLS=true` and mount TLS certificates.

## Observability

### OpenTelemetry

Goose has built-in OTEL support. Set these env vars to enable:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_SERVICE_NAME=goose-agent
```

For local development, uncomment the Jaeger service in `deploy/docker-compose.yaml` to visualize traces at `http://localhost:16686`.

### Logging

Goose logs to stdout. Control log level with `RUST_LOG`:

```bash
RUST_LOG=info    # default
RUST_LOG=debug   # verbose
RUST_LOG=warn    # quiet
```

## Advanced

### Context Compaction

Goose automatically summarizes conversation history when it reaches 80% of the context window (`GOOSE_AUTO_COMPACT_THRESHOLD`). If domain-specific context is lost during compaction, override `config/prompts/compaction.md` to customize what gets preserved.

### Additional Prompt Templates

Beyond `system.md`, you can override these prompt templates in `config/prompts/`:

| File | Purpose |
|------|---------|
| `compaction.md` | How conversation history gets summarized |
| `plan.md` | Step-by-step plan generation format |
| `subagent_system.md` | Prompt for spawned sub-agents |
| `permission_judge.md` | Read-only tool detection for SmartApprove mode |

### Secrets File Alternative

Goose supports a `secrets.yaml` file at `$GOOSE_PATH_ROOT/config/secrets.yaml` as an alternative to env vars for API keys. This can be useful when env var injection is impractical.

### ACP Alternative

If you prefer the [Agent Client Protocol](https://github.com/block/goose) over the REST API, build the ACP server binary (`cargo build --release -p goose-acp`) and use this entrypoint:

```
ENTRYPOINT ["goose-acp-server", "--host", "0.0.0.0", "--port", "3284", "--builtin", ""]
```

## Reference

### Environment Variables

See `.env.example` for the complete list with descriptions.

### Config Files

| File | Purpose |
|------|---------|
| `config/prompts/system.md` | Agent identity and behavior (Jinja2 template) |
| `config/config.yaml` | MCP server/extension configuration |
| `config/permission.yaml` | Per-tool permission rules |
| `config/.goosehints` | Auxiliary agent context |

### Links

- [Goose](https://github.com/block/goose) — the agent framework
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk) — for building MCP servers
- [MCP Specification](https://modelcontextprotocol.io/) — protocol documentation
