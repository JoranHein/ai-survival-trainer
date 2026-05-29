from __future__ import annotations

import json
from pathlib import Path

from alife.survival import IdleSurvivalWorld
from alife.world import World


def save_world(world: World | IdleSurvivalWorld, path: str | Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = world.to_dict()
    if isinstance(world, IdleSurvivalWorld):
        data["mode"] = "idle_survival"
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def load_world(path: str | Path) -> World | IdleSurvivalWorld:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("mode") == "idle_survival" or "survivor" in data:
        return IdleSurvivalWorld.from_dict(data)
    return World.from_dict(data)
