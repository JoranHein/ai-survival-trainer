from __future__ import annotations

import random

from alife.utils import clamp


TRAIT_NAMES = (
    "curiosity",
    "bravery",
    "friendliness",
    "aggression",
    "stubbornness",
    "patience",
    "memory_strength",
    "social_imitation",
    "risk_tolerance",
    "pain_sensitivity",
    "language_ability",
    "blue_fruit_tolerance",
    "cold_tolerance",
)


def clamp01(value: float) -> float:
    return clamp(value, 0.0, 1.0)


def random_traits(seed: int | None = None, rng: random.Random | None = None) -> dict[str, float]:
    rng = rng or random.Random(seed)
    return {name: clamp01(rng.uniform(0.2, 0.85)) for name in TRAIT_NAMES}


def breed_traits(
    parent_a: dict[str, float],
    parent_b: dict[str, float],
    mutation_rate: float = 0.18,
    mutation_strength: float = 0.12,
    seed: int | None = None,
    rng: random.Random | None = None,
) -> dict[str, float]:
    rng = rng or random.Random(seed)
    child: dict[str, float] = {}
    for name in TRAIT_NAMES:
        base = (parent_a.get(name, 0.5) + parent_b.get(name, 0.5)) / 2.0
        if rng.random() < mutation_rate:
            base += rng.uniform(-mutation_strength, mutation_strength)
        child[name] = clamp01(base)
    return child


def color_from_traits(traits: dict[str, float]) -> tuple[int, int, int]:
    red = int(95 + traits.get("aggression", 0.5) * 95 + traits.get("bravery", 0.5) * 45)
    green = int(100 + traits.get("friendliness", 0.5) * 95)
    blue = int(105 + traits.get("curiosity", 0.5) * 105)
    return (
        int(clamp(red, 55, 245)),
        int(clamp(green, 65, 235)),
        int(clamp(blue, 75, 245)),
    )
