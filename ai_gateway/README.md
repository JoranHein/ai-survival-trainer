# AI Survival Trainer Ari AI Gateway

FastAPI gateway for Ari sign interpretation. It exposes only game-facing endpoints and calls a local model runtime on the same server. The raw model runtime should stay bound to `127.0.0.1`.

## Endpoints

- `GET /health`
- `POST /ai/deep-interpretation`
- `POST /ai/fast-thought`

All endpoints require `X-API-Key` when `GAME_AI_API_KEY` is set.

## Environment

Copy `.env.example` to `.env` on the server and fill values:

```bash
GAME_AI_API_KEY=replace-with-a-strong-random-key
MODEL_BACKEND=ollama
MODEL_BASE_URL=http://127.0.0.1:11434
FAST_MODEL=qwen3:1.7b
DEEP_MODEL=qwen3:1.7b
PORT=8088
REQUEST_TIMEOUT_SECONDS=6
DEBUG_LOG_SIGNS=false
```

Do not log or store player sign text. `DEBUG_LOG_SIGNS` should remain `false` outside short local debugging.

## Local Run

```bash
cd ai_gateway
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8088
```

## Server Install

The intended server path is:

```bash
/opt/ari-ai-server
```

After copying files there:

```bash
cd /opt/ari-ai-server
cp .env.example .env
# edit .env and set GAME_AI_API_KEY
bash scripts/install_server.sh
```

The installer uses Ollama by default. If a CUDA-capable GPU is available later, set `MODEL_BACKEND=vllm` and `MODEL_BASE_URL=http://127.0.0.1:8000/v1`.

On CPU-only hosts, `qwen3:1.7b` is the current safe default. Set `DEEP_MODEL` to a non-thinking Qwen 4B instruct runtime later when one is available and validated.

## Curl Test

```bash
curl -fsS -H "X-API-Key: $GAME_AI_API_KEY" http://127.0.0.1:8088/health
```

```bash
curl -fsS -X POST http://127.0.0.1:8088/ai/deep-interpretation \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $GAME_AI_API_KEY" \
  -d '{
    "sign_text": "stand behind the wall",
    "ari": {
      "run_build": {"preset": "Builder", "building": 5, "warding": 3},
      "hp": 80,
      "max_hp": 100,
      "current_job": "build_wall",
      "current_reason": "No aura orb yet"
    },
    "world": {
      "day": 1,
      "phase": "midday",
      "time_left": 25,
      "stone": 10,
      "wall_count": 2,
      "aura_orb_count": 1,
      "enemy_count": 0,
      "known_enemy_types": ["zombie"],
      "structures": [{"type": "wall", "status": "intact"}]
    },
    "local_fallback": {
      "interpretation": "The sign mentions wall. Ari thinks about building walls.",
      "priority_hints": {"build_wall": 0.8},
      "sign_strength": 0.4,
      "resonance": 0.4
    }
  }'
```

The desired interpretation for `"stand behind the wall"` is cover behavior, not simply building more walls.
