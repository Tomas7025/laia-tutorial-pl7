FROM ghcr.io/actions/runner:latest

# Minimal tools: curl, jq, openssl, docker-cli
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq openssl ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*

# Docker CLI (talks to host via /var/run/docker.sock)
RUN curl -fsSL https://get.docker.com | sh

# Copy scripts
COPY ../common /scripts
RUN chmod +x /scripts/*.sh

# Default env (overridden by compose)
ENV RUNNER_SCOPE="repo" \
    RUNNER_LABELS="self-hosted,linux,x64,training" \
    RUNNER_EPHEMERAL="true" \
    RUNNER_WORKDIR="/_work"

# Work directory for GitHub runner
WORKDIR /runner

# The official image already has the runner bits in /runner
# Entry
ENTRYPOINT ["/scripts/entrypoint.sh"]