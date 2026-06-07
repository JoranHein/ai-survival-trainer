#!/usr/bin/env bash
set -euo pipefail

cd /opt/ari-ai-server

ensure_env_value() {
  local key="$1"
  local value="$2"
  if [ ! -f .env ]; then
    return
  fi
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    printf '\n%s=%s\n' "$key" "$value" >> .env
  fi
}

ensure_env_value REQUEST_TIMEOUT_SECONDS 5
ensure_env_value DEEP_REQUEST_TIMEOUT_SECONDS 5
ensure_env_value PLANNER_REQUEST_TIMEOUT_SECONDS 5
ensure_env_value SCRIBE_REQUEST_TIMEOUT_SECONDS 4
ensure_env_value REFLECTION_REQUEST_TIMEOUT_SECONDS 12
ensure_env_value BACKGROUND_REQUEST_TIMEOUT_SECONDS 4
ensure_env_value PREDICTION_REQUEST_TIMEOUT_SECONDS 5
ensure_env_value FOREGROUND_PRIORITY_DELAY_SECONDS 0.18
ensure_env_value FAST_MODEL qwen3:0.6b
ensure_env_value PLANNER_MODEL qwen3:0.6b
ensure_env_value SCRIBE_MODEL qwen3:0.6b
ensure_env_value REFLECTION_MODEL qwen3:1.7b
ensure_env_value BACKGROUND_MODEL qwen3:0.6b
ensure_env_value PREDICTION_MODEL smollm2:135m
ensure_env_value DEEP_MODE deterministic
ensure_env_value PLANNER_MAX_TOKENS 180
ensure_env_value REFLECTION_MAX_TOKENS 140
ensure_env_value BACKGROUND_MAX_TOKENS 120
ensure_env_value PREDICTION_MAX_TOKENS 96
ensure_env_value PLANNER_NUM_CTX 1024
ensure_env_value REFLECTION_NUM_CTX 1024
ensure_env_value PREDICTION_NUM_CTX 512
ensure_env_value OLLAMA_NUM_THREAD 4
ensure_env_value OLLAMA_NUM_CTX 4096
ensure_env_value OLLAMA_KEEP_ALIVE 30m
ensure_env_value OLLAMA_NUM_PARALLEL 2
ensure_env_value OLLAMA_MAX_LOADED_MODELS 3
ensure_env_value OLLAMA_MAX_QUEUE 16
ensure_env_value ENABLE_STARTUP_WARMUP true

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

configure_ollama_runtime() {
  mkdir -p /etc/systemd/system/ollama.service.d
  cat >/etc/systemd/system/ollama.service.d/ari-ai-survival.conf <<EOF
[Service]
Environment="OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-2}"
Environment="OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-3}"
Environment="OLLAMA_MAX_QUEUE=${OLLAMA_MAX_QUEUE:-16}"
Environment="OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-30m}"
EOF
  systemctl daemon-reload
  systemctl restart ollama
}

python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

MODEL_BACKEND="${MODEL_BACKEND:-openai}"
if [ "$MODEL_BACKEND" = "ollama" ]; then
  if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi

  systemctl enable --now ollama
  configure_ollama_runtime
  DEFAULT_OLLAMA_MODEL="hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0"
  DEFAULT_FAST_OLLAMA_MODEL="qwen3:0.6b"
  ollama pull "${DEEP_MODEL:-$DEFAULT_OLLAMA_MODEL}" || ollama pull qwen2.5:3b
  ollama pull "${FAST_MODEL:-$DEFAULT_FAST_OLLAMA_MODEL}" || true
  ollama pull "${PLANNER_MODEL:-${DEEP_MODEL:-$DEFAULT_OLLAMA_MODEL}}" || true
  ollama pull "${SCRIBE_MODEL:-${FAST_MODEL:-$DEFAULT_FAST_OLLAMA_MODEL}}" || true
  ollama pull "${REFLECTION_MODEL:-${PLANNER_MODEL:-${DEEP_MODEL:-$DEFAULT_OLLAMA_MODEL}}}" || true
  ollama pull "${BACKGROUND_MODEL:-${FAST_MODEL:-$DEFAULT_FAST_OLLAMA_MODEL}}" || true
  ollama pull "${PREDICTION_MODEL:-${FAST_MODEL:-$DEFAULT_FAST_OLLAMA_MODEL}}" || true
else
  echo "Skipping Ollama install for MODEL_BACKEND=$MODEL_BACKEND"
fi

install -m 0644 systemd/ari-ai-gateway.service /etc/systemd/system/ari-ai-gateway.service
systemctl daemon-reload
systemctl enable --now ari-ai-gateway
