#!/usr/bin/env bash
set -euo pipefail

# Inputs:
#   GITHUB_APP_ID
#   GITHUB_APP_PRIVATE_KEY  (PEM contents)
# Output: prints a JWT to stdout

header_base64=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -A | tr '+/' '-_' | tr -d '=')

iat=$(date +%s)
exp=$((iat + 540))  # 9 minutes (must be <= 10 min)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$GITHUB_APP_ID")
payload_base64=$(printf "%s" "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')

unsigned="${header_base64}.${payload_base64}"

# Write key to temp file
tmpkey=$(mktemp)
printf "%s" "$GITHUB_APP_PRIVATE_KEY" > "$tmpkey"

sig=$(printf "%s" "$unsigned" \
  | openssl dgst -sha256 -sign "$tmpkey" \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=')

rm -f "$tmpkey"

printf "%s.%s\n" "$unsigned" "$sig"