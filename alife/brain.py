from __future__ import annotations

import math
import random
from dataclasses import dataclass


@dataclass
class BrainDecision:
    action: str
    scores: dict[str, float]
    probabilities: dict[str, float]
    thought: str


class LocalBrainModel:
    """Small offline intention model for autonomous creature decisions.

    This is deliberately not an argmax policy. It samples from scored intentions so
    personality and uncertainty can change the outcome without direct commands.
    """

    def choose(self, scores: dict[str, float], rng: random.Random, temperature: float) -> BrainDecision:
        probabilities = self.softmax(scores, temperature)
        roll = rng.random()
        cumulative = 0.0
        chosen = next(iter(scores))
        for action, probability in probabilities.items():
            cumulative += probability
            if roll <= cumulative:
                chosen = action
                break
        top = sorted(scores.items(), key=lambda item: item[1], reverse=True)[:3]
        thought = " | ".join(f"{action} {score:.1f}/{probabilities[action]:.0%}" for action, score in top)
        return BrainDecision(chosen, scores, probabilities, thought)

    def softmax(self, scores: dict[str, float], temperature: float) -> dict[str, float]:
        temperature = max(0.35, temperature)
        highest = max(scores.values())
        weighted = {action: math.exp((score - highest) / temperature) for action, score in scores.items()}
        total = sum(weighted.values()) or 1.0
        return {action: value / total for action, value in weighted.items()}
