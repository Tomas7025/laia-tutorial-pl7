#!/usr/bin/env bash
set -euo pipefail

# Required env:
#   RUNNER_SCOPE      (repo or org)
#   RUNNER_TARGET     (e.g. owner/repo for repo-scope, or org name for org-scope)
#   RUNNER_LABELS     (comma separated)
#   RUNNER_EPHEMERAL  (true|false)
#   RUNNER_NAME
#   GITHUB_APP_ID
#   GITHUB_APP_INSTALLATION_ID
#   GITHUB_APP_PRIVATE_KEY
#   RUNNER_WORKDIR    (e.g., _work)

github_api_base="https://api.github.com"

# 1) Mint JWT from GitHub App creds
JWT=$(/scripts/jwt.sh)

# 2) Exchange JWT → installation access token
install_token_resp=$(curl -fsSL -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "${github_api_base}/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens")

INSTALL_TOKEN=$(echo "$install_token_resp" | jq -r .token)

# 3) Get a runner registration token (repo or org scoped)
if [ "$RUNNER_SCOPE" = "repo" ]; then
  # RUNNER_TARGET = owner/repo
  IFS='/' read -r OWNER REPO <<< "$RUNNER_TARGET"
  reg_resp=$(curl -fsSL -X POST \
    -H "Authorization: Bearer $INSTALL_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${github_api_base}/repos/${OWNER}/${REPO}/actions/runners/registration-token")
elif [ "$RUNNER_SCOPE" = "org" ]; then
  # RUNNER_TARGET = org
  reg_resp=$(curl -fsSL -X POST \
    -H "Authorization: Bearer $INSTALL_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${github_api_base}/orgs/${RUNNER_TARGET}/actions/runners/registration-token")
else
  echo "Invalid RUNNER_SCOPE: $RUNNER_SCOPE"
  exit 1
fi

REG_TOKEN=$(echo "$reg_resp" | jq -r .token)

# 4) Configure runner
cd /runner
./config.sh \
  --url "https://github.com/${RUNNER_TARGET}" \
  --token "${REG_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --work "${RUNNER_WORKDIR}" \
  $( [ "$RUNNER_EPHEMERAL" = "true" ] && printf "%s" "--ephemeral" || true ) \
  --unattended

echo "Runner configured. Labels: ${RUNNER_LABELS}, ephemeral=${RUNNER_EPHEMERAL}"