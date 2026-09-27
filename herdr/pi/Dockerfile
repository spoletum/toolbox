# syntax=docker/dockerfile:1

FROM ubuntu:26.04

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------------------------
# Minimal OS substrate
#
# These packages exist only to bootstrap Homebrew and provide the
# underlying system environment.
# --------------------------------------------------------------------

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        git \
        procps \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------
# Agent user
#
# Recent Ubuntu images may already contain a user/group with UID/GID
# 1000. Reuse those identities instead of failing on the collision.
# --------------------------------------------------------------------

RUN set -eux; \
    existing_group="$(getent group "${GID}" | cut -d: -f1 || true)"; \
    if [ -n "${existing_group}" ]; then \
        if [ "${existing_group}" != "agent" ]; then \
            groupmod --new-name agent "${existing_group}"; \
        fi; \
    else \
        groupadd --gid "${GID}" agent; \
    fi; \
    existing_user="$(getent passwd "${UID}" | cut -d: -f1 || true)"; \
    if [ -n "${existing_user}" ]; then \
        if [ "${existing_user}" != "agent" ]; then \
            usermod \
                --login agent \
                --home /home/agent \
                --move-home \
                "${existing_user}"; \
        fi; \
        usermod \
            --gid "${GID}" \
            --shell /bin/bash \
            agent; \
    else \
        useradd \
            --uid "${UID}" \
            --gid "${GID}" \
            --create-home \
            --shell /bin/bash \
            agent; \
    fi; \
    mkdir -p \
        /home/agent/workspace \
        /home/agent/.ssh \
        /home/linuxbrew; \
    chmod 700 /home/agent/.ssh; \
    chown -R agent:agent \
        /home/agent \
        /home/linuxbrew

# --------------------------------------------------------------------
# From here onward, everything is installed as the agent user.
# --------------------------------------------------------------------

USER agent

ENV HOME=/home/agent

# --------------------------------------------------------------------
# Homebrew
#
# Cloned manually (Homebrew's documented manual install) and pinned to
# a release tag. The official install.sh clones the moving HEAD, which
# would invalidate this layer - and every layer after it - on every
# Homebrew release. Bump HOMEBREW_VERSION when new formulae require it.
# --------------------------------------------------------------------

ARG HOMEBREW_VERSION=6.0.22

RUN git clone --depth 1 --branch "${HOMEBREW_VERSION}" \
        https://github.com/Homebrew/brew.git \
        /home/linuxbrew/.linuxbrew

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

ENV HOMEBREW_NO_ANALYTICS=1
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_ENV_HINTS=1

# Bottle download cache, backed by a BuildKit cache mount (see workflow).
# Only the *download cache* is mounted; /home/linuxbrew itself is baked
# into the image so installed tools ship inside the final layer.
ENV HOMEBREW_CACHE=/home/agent/.cache/Homebrew

# --------------------------------------------------------------------
# Homebrew-managed userland
#
# uid/gid on the cache mount: BuildKit creates cache mount points as
# root, which the non-root build user cannot write to (EACCES).
# --------------------------------------------------------------------

RUN --mount=type=cache,target=/home/agent/.cache/Homebrew,uid=${UID},gid=${GID} \
    brew install \
        git \
        openssh \
        curl \
        node \
        python \
        go \
        rust \
        ripgrep \
        fd \
        jq \
        yq \
        fzf \
        bat \
        eza \
        gh \
        helix \
        hunk \
        dotnet \
        oh-my-posh \
        herdr \
        docker \
        docker-compose \
        docker-buildx

# --------------------------------------------------------------------
# Docker CLI plugins
#
# The image contains only the Docker CLI and plugins.
# It intentionally does NOT contain or expose the host Docker daemon.
# --------------------------------------------------------------------

RUN mkdir -p /home/agent/.docker \
    && printf '%s\n' \
        '{' \
        '  "cliPluginsExtraDirs": [' \
        '    "/home/linuxbrew/.linuxbrew/lib/docker/cli-plugins"' \
        '  ]' \
        '}' \
        > /home/agent/.docker/config.json

# --------------------------------------------------------------------
# Pi
#
# npm is supplied by Homebrew's Node installation.
# --------------------------------------------------------------------

RUN --mount=type=cache,target=/home/agent/.npm,uid=${UID},gid=${GID} \
    npm install -g --ignore-scripts \
    @earendil-works/pi-coding-agent

# Pi uses llama.cpp on Compose's private network. The dummy API key is
# required by Pi's local-provider configuration but ignored by llama.cpp.
# Hugging Face CLI lets Pi download public GGUFs into the shared models volume.
# Create this directory in the image as agent so Docker initializes its named
# volume with writable ownership on first use.
RUN mkdir -p /home/agent/.pi/agent /home/agent/models

# Homebrew marks its Python as externally managed (PEP 668), so keep the
# application and its dependencies in an isolated virtual environment.
RUN python3 -m venv /home/agent/.local/share/huggingface \
    && /home/agent/.local/share/huggingface/bin/pip install --no-cache-dir huggingface_hub
ENV PATH="/home/agent/.local/share/huggingface/bin:${PATH}"

# Keep the source outside $HOME: Compose persists $HOME/.pi in a named volume.
COPY --chown=agent:agent models.json /usr/local/share/pi/models.json
COPY --chown=agent:agent container-init /usr/local/bin/container-init
RUN chmod 755 /usr/local/bin/container-init

# --------------------------------------------------------------------
# Bash configuration
#
# Homebrew is initialized explicitly for interactive shells.
# Oh My Posh provides the prompt while Bash remains the shell.
# --------------------------------------------------------------------

RUN printf '%s\n' \
        '' \
        '# Homebrew' \
        'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' \
        '' \
        '# Oh My Posh' \
        'eval "$(oh-my-posh init bash)"' \
        >> /home/agent/.bashrc

# --------------------------------------------------------------------
# Workspace
# --------------------------------------------------------------------

WORKDIR /home/agent/workspace

ENTRYPOINT ["/usr/local/bin/container-init"]
CMD ["bash"]
