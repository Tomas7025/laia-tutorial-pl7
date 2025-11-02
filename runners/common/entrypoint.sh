#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  echo "Removing runner..."
  cd /runner
  ./config.sh remove --unattended || true
}
trap cleanup EXIT

/scripts/register.sh

# Make sure Docker CLI can talk to host daemon (docker.sock mounted)
docker version || { echo "Docker daemon not reachable. Did you mount /var/run/docker.sock?"; exit 1; }

cd /runner
exec ./run.sh