from __future__ import annotations

from dataclasses import asdict, dataclass


UPGRADE_DEFINITIONS: dict[str, dict] = {
    "auto_feeder": {
        "name": "Auto feeder",
        "cost": {"care": 45, "insight": 0},
        "max_level": 3,
        "description": "Slowly reduces hunger, but can make sheltered creatures less curious.",
    },
    "training_corner": {
        "name": "Training corner",
        "cost": {"care": 80, "insight": 0},
        "max_level": 4,
        "description": "Training dummy practice gives more combat XP.",
    },
    "item_shelf": {
        "name": "Item shelf",
        "cost": {"care": 60, "insight": 12},
        "max_level": 3,
        "description": "Improves the value of placed combat items.",
    },
    "combat_journal": {
        "name": "Combat journal",
        "cost": {"care": 40, "insight": 18},
        "max_level": 4,
        "description": "Fights and training generate more Insight.",
    },
    "arena_mat": {
        "name": "Arena mat",
        "cost": {"care": 100, "insight": 24},
        "max_level": 3,
        "description": "Sparring gives more XP, but competitive creatures spar more often.",
    },
    "med_station": {
        "name": "Med station",
        "cost": {"care": 120, "insight": 20},
        "max_level": 3,
        "description": "Combat hurts less and injured creatures recover faster.",
    },
}


@dataclass
class UpgradeState:
    id: str
    level: int = 0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "UpgradeState":
        return cls(**data)


def default_upgrades() -> dict[str, UpgradeState]:
    return {upgrade_id: UpgradeState(upgrade_id, 0) for upgrade_id in UPGRADE_DEFINITIONS}
