#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${ARI_AI_BASE_URL:?ARI_AI_BASE_URL is required, e.g. http://host:8088}"
API_KEY="${GAME_AI_API_KEY:?GAME_AI_API_KEY is required}"

curl -fsS -H "X-API-Key: ${API_KEY}" "${BASE_URL%/}/health"
echo
