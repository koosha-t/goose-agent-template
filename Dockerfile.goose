# Goose Agent Runtime — Multi-stage Build
# ========================================
# Builds the goosed binary from source at a pinned version,
# then packages it with your custom config.
#
# Usage:
#   docker build -f Dockerfile.goose --build-arg GOOSE_VERSION=v1.28.1 -t goose-runtime .

# --- Stage 1: Build goosed from source ---
FROM rust:1.92-bookworm AS builder

ARG GOOSE_VERSION=v1.28.1

RUN apt-get update && apt-get install -y \
    libdbus-1-dev \
    pkg-config \
    cmake \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch ${GOOSE_VERSION} https://github.com/block/goose.git .
RUN cargo build --release -p goose-server

# --- Stage 2: Runtime image ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libdbus-1-3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary
COPY --from=builder /src/target/release/goosed /usr/local/bin/goosed

# Create config directory structure
RUN mkdir -p /goose/config/prompts /goose/data /goose/state

# --- YOUR CUSTOMIZATIONS ---

# Custom system prompt
COPY config/prompts/system.md /goose/config/prompts/system.md

# Optional: other prompt overrides (uncomment as needed)
# COPY config/prompts/compaction.md /goose/config/prompts/compaction.md
# COPY config/prompts/plan.md /goose/config/prompts/plan.md

# Extension config (MCP server endpoints)
COPY config/config.yaml /goose/config/config.yaml

# Permission rules
COPY config/permission.yaml /goose/config/permission.yaml

# Hints file
COPY config/.goosehints /goose/config/.goosehints

# --- ENVIRONMENT ---

# Infrastructure defaults only.
# Behavioral settings (GOOSE_MODE, etc.) come from .env or config.yaml at runtime.
ENV GOOSE_PATH_ROOT=/goose
ENV GOOSE_DISABLE_KEYRING=1
ENV GOOSE_HOST=0.0.0.0
ENV GOOSE_PORT=3000
ENV GOOSE_TLS=false

# WORKDIR must contain .goosehints for Goose to discover it
WORKDIR /goose/config

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/ || exit 1

ENTRYPOINT ["goosed", "agent"]
