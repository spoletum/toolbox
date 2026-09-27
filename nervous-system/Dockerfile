# syntax=docker/dockerfile:1
#
# Herdr Nervous System: headless herdr server + Hermes (brain) + Omp (worker-spawner)
#
# Build:
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     -t ghcr.io/spoletum/toolbox-herdr-nervous-system:latest \
#     --push .

FROM docker.io/ubuntu:24.04

ARG TARGETARCH
ARG HERDR_VERSION=0.9.1

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV SHELL=/bin/bash
ENV HOME=/root

# =============================================================================
# 1. System dependencies
# =============================================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    curl \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 2. Herdr (the nervous system runtime)
# =============================================================================
RUN ARCH=$(case ${TARGETARCH} in amd64) echo "x86_64";; arm64) echo "aarch64";; esac) \
    && curl -fsSL "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-${ARCH}" \
    -o /usr/local/bin/herdr \
    && chmod +x /usr/local/bin/herdr

# =============================================================================
# 3. Node.js (required by omp / pi agents)
# =============================================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 4. Bun (for omp CLI — @oh-my-pi/pi-coding-agent)
# =============================================================================
RUN curl -fsSL https://bun.sh/install | bash

ENV PATH="/root/.bun/bin:/root/.local/bin:/usr/local/bin:${PATH}"

# =============================================================================
# 5. Hermes Agent (brain harness)
# =============================================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --break-system-packages --no-cache-dir hermes-agent

# Configure Hermes model provider
ENV HERMES_MODEL_PROVIDER=custom
ENV HERMES_MODEL_BASE_URL=http://llama:8080/v1
ENV HERMES_MODEL_DEFAULT=qwen3.6:35b-a3b-ud
RUN hermes config set model.provider "$HERMES_MODEL_PROVIDER" \
    && hermes config set model.base_url "$HERMES_MODEL_BASE_URL" \
    && hermes config set model.default "$HERMES_MODEL_DEFAULT"

# =============================================================================
# 6. Omp (worker-spawner) — @oh-my-pi/pi-coding-agent
# =============================================================================
RUN --mount=type=cache,target=/root/.npm \
    npm install -g --ignore-scripts @oh-my-pi/pi-coding-agent

# =============================================================================
# 7.5 Microsoft Teams CLI (for bot registration)
# =============================================================================
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @microsoft/teams.cli@preview


# =============================================================================
# 7. Herdr configuration
# =============================================================================
RUN mkdir -p /root/.config/herdr

COPY config.toml /root/.config/herdr/config.toml

# =============================================================================
# 6. Startup script
# =============================================================================
COPY init.sh /usr/local/bin/nervous-system-init
RUN chmod 755 /usr/local/bin/nervous-system-init

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/nervous-system-init"]
CMD ["sleep", "infinity"]
