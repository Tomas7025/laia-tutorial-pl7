FROM ghcr.io/actions/runner:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq openssl ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://get.docker.com | sh

COPY ../common /scripts
RUN chmod +x /scripts/*.sh

ENV RUNNER_SCOPE="repo" \
    RUNNER_LABELS="self-hosted,linux,x64,deploy" \
    RUNNER_EPHEMERAL="false" \
    RUNNER_WORKDIR="/_work"

WORKDIR /runner
ENTRYPOINT ["/scripts/entrypoint.sh"]