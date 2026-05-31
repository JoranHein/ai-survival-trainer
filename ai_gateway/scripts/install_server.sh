#!/usr/bin/env bash
set -euo pipefail

cd /opt/ari-ai-server
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

systemctl enable --now ollama
ollama pull "${DEEP_MODEL:-qwen3:1.7b}" || ollama pull qwen2.5:3b
ollama pull "${FAST_MODEL:-qwen3:1.7b}" || true

install -m 0644 systemd/ari-ai-gateway.service /etc/systemd/system/ari-ai-gateway.service
systemctl daemon-reload
systemctl enable --now ari-ai-gateway
