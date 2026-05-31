#!/usr/bin/env bash
set -euo pipefail

API_KEY="${GAME_AI_API_KEY:?GAME_AI_API_KEY is required}"
PORT="${PORT:-8088}"

curl -fsS -H "X-API-Key: ${API_KEY}" "http://127.0.0.1:${PORT}/health"
echo
curl -fsS -X POST "http://127.0.0.1:${PORT}/ai/deep-interpretation" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${API_KEY}" \
  -d '{
    "sign_text": "stand behind the wall",
    "ari": {
      "personality": {"fearfulness": 0.7, "aggression": 0.2, "curiosity": 0.5, "sign_faith": 0.8},
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
echo
