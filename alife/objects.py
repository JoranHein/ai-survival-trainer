from __future__ import annotations

from dataclasses import asdict, dataclass, field

from alife.utils import random_id


OBJECT_DEFINITIONS: dict[str, dict] = {
    "red_fruit": {
        "label": "Red fruit",
        "color": "red",
        "edible": True,
        "nutrition": 24,
        "energy": 4,
        "happiness": 7,
        "sickness_base": 0.02,
    },
    "blue_fruit": {
        "label": "Blue fruit",
        "color": "blue",
        "edible": True,
        "nutrition": 36,
        "energy": 9,
        "happiness": 10,
        "sickness_base": 0.12,
        "weather_sensitive": True,
    },
    "yellow_fruit": {
        "label": "Yellow fruit",
        "color": "yellow",
        "edible": True,
        "nutrition": 18,
        "energy": 28,
        "happiness": 3,
        "aggression_boost": 15,
        "sickness_base": 0.04,
    },
    "bell": {
        "label": "Bell",
        "color": "gold",
        "sound": True,
        "curiosity": 0.75,
        "scary": 0.28,
    },
    "music_stone": {
        "label": "Music stone",
        "color": "purple",
        "calming": True,
        "curiosity": 0.52,
        "social": 0.7,
    },
    "nest": {
        "label": "Nest",
        "color": "brown",
        "comfort": 0.85,
        "sleep": True,
        "territory": True,
    },
    "training_dummy": {
        "label": "Training dummy",
        "color": "wood",
        "training": True,
        "combat_xp": 2.5,
        "safe": True,
    },
    "soft_gloves": {
        "label": "Soft gloves",
        "color": "pink",
        "combat_item": True,
        "injury_mult": 0.72,
        "trust_bonus": 0.08,
    },
    "spiky_charm": {
        "label": "Spiky charm",
        "color": "red",
        "combat_item": True,
        "damage_bonus": 0.28,
        "aggression": 0.24,
        "fear_risk": 0.12,
    },
    "calm_band": {
        "label": "Calm band",
        "color": "teal",
        "combat_item": True,
        "guard_bonus": 0.25,
        "aggression": -0.18,
        "fear_relief": 0.2,
    },
    "battle_drum": {
        "label": "Battle drum",
        "color": "orange",
        "combat_item": True,
        "spar_pull": 0.28,
        "fear_risk": 0.15,
        "social": 0.35,
    },
    "lucky_pebble": {
        "label": "Lucky pebble",
        "color": "gray",
        "combat_item": True,
        "luck": 0.22,
        "focus_bonus": 0.12,
    },
}


@dataclass
class WorldObject:
    id: str
    object_type: str
    x: float
    y: float
    traits: dict = field(default_factory=dict)
    created_tick: int = 0
    uses: int = 0

    @classmethod
    def create(cls, object_type: str, x: float, y: float, tick: int = 0) -> "WorldObject":
        traits = dict(OBJECT_DEFINITIONS[object_type])
        return cls(id=random_id("obj"), object_type=object_type, x=x, y=y, traits=traits, created_tick=tick)

    @property
    def is_food(self) -> bool:
        return bool(self.traits.get("edible"))

    def label(self) -> str:
        return self.traits.get("label", self.object_type.replace("_", " "))

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "WorldObject":
        return cls(**data)
