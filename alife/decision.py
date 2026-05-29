from __future__ import annotations

import random
from dataclasses import dataclass

from config import EAT_DISTANCE, INTERACT_DISTANCE, PERCEPTION_RANGE, SOCIAL_RANGE
from alife.objects import WorldObject
from alife.utils import clamp, distance


@dataclass
class ActionScore:
    action: str
    score: float
    target_id: str | None = None
    reason: str = ""


@dataclass
class Decision:
    action: str
    target_id: str | None
    scores: list[ActionScore]
    dominant_need: str
    strongest_memory: str
    strongest_belief: str
    explanation: str


class DecisionEngine:
    def __init__(self, seed: int | None = None, rng: random.Random | None = None):
        self.rng = rng or random.Random(seed)

    def choose_action(self, creature, world) -> Decision:
        objects = world.perceived_objects(creature, PERCEPTION_RANGE) if hasattr(world, "perceived_objects") else world.objects
        others = world.perceived_creatures(creature, SOCIAL_RANGE) if hasattr(world, "perceived_creatures") else []
        candidates: list[ActionScore] = [
            ActionScore(
                "wander",
                4.5 + creature.traits.get("curiosity", 0.5) * 4.0 + self.noise(1.8),
                reason="curiosity and low commitment",
            )
        ]

        if creature.needs.energy < 36:
            candidates.append(
                ActionScore(
                    "sleep",
                    (45 - creature.needs.energy) * 0.45 + creature.traits.get("patience", 0.5) * 4,
                    reason="low energy",
                )
            )

        for obj in objects:
            if obj.is_food:
                action = "eat" if distance((creature.x, creature.y), (obj.x, obj.y)) <= EAT_DISTANCE else "seek_food"
                candidates.append(ActionScore(action, self.food_score(creature, obj, world.weather), obj.id, "food pressure"))
                avoid_score = self.avoid_score(creature, obj)
                if avoid_score > 1.0:
                    candidates.append(ActionScore("avoid", avoid_score, obj.id, "fear and negative belief"))
                observe_score = self.observe_score(creature, obj)
                candidates.append(ActionScore("observe", observe_score, obj.id, "uncertain object"))
            elif obj.object_type == "nest":
                nest_distance = distance((creature.x, creature.y), (obj.x, obj.y))
                action = "rest_in_nest" if nest_distance <= INTERACT_DISTANCE else "investigate_object"
                score = (100 - creature.needs.energy) * 0.2 + (100 - creature.needs.comfort) * 0.16
                score += creature.traits.get("patience", 0.5) * 5 + self.object_belief_bonus(creature, obj) + self.noise(1.2)
                candidates.append(ActionScore(action, score, obj.id, "comfort and sleep value"))
            elif obj.object_type == "training_dummy":
                dummy_distance = distance((creature.x, creature.y), (obj.x, obj.y))
                action = "train" if dummy_distance <= INTERACT_DISTANCE else "investigate_object"
                score = self.combat_interest(creature) + creature.traits.get("patience", 0.5) * 3
                score += max(0.0, creature.needs.energy - 25) * 0.06 + self.object_belief_bonus(creature, obj)
                candidates.append(ActionScore(action, score + self.noise(1.4), obj.id, "safe combat practice"))
            elif obj.object_type == "music_stone":
                score = creature.needs.fear * 0.12 + creature.needs.loneliness * 0.08
                score += creature.traits.get("curiosity", 0.5) * 6 + creature.traits.get("friendliness", 0.5) * 4
                score += self.object_belief_bonus(creature, obj) + self.noise(1.5)
                candidates.append(ActionScore("investigate_object", score, obj.id, "calming social object"))
            elif obj.object_type == "bell":
                belief = creature.beliefs.about("object_type", "bell")
                if belief.valence < -0.2:
                    candidates.append(ActionScore("avoid", abs(belief.valence) * 16 * belief.confidence, obj.id, "bad sound belief"))
                score = creature.traits.get("curiosity", 0.5) * 8 + self.object_belief_bonus(creature, obj)
                score += (1.0 - belief.confidence) * 4 + self.noise(1.6)
                candidates.append(ActionScore("investigate_object", score, obj.id, "sound curiosity"))
            elif obj.traits.get("combat_item"):
                score = creature.traits.get("curiosity", 0.5) * 5 + self.combat_interest(creature) * 0.45
                if obj.object_type == "battle_drum":
                    score += creature.traits.get("aggression", 0.5) * 6 - creature.needs.fear * 0.04
                if obj.object_type == "calm_band":
                    score += creature.needs.fear * 0.08 + creature.traits.get("patience", 0.5) * 3
                candidates.append(ActionScore("investigate_object", score + self.noise(1.2), obj.id, "combat item curiosity"))

            belief = creature.beliefs.about("object_type", obj.object_type)
            if belief.valence < -0.45 and others:
                attach = max((creature.relationship_with(other.id).attachment for other in others), default=0.0)
                warn_score = abs(belief.valence) * belief.confidence * 20
                warn_score += creature.traits.get("friendliness", 0.5) * 8 + attach * 5
                warn_score += creature.traits.get("language_ability", 0.5) * 4 + self.noise(1.0)
                candidates.append(ActionScore("warn", warn_score, obj.id, "negative belief and nearby creature"))

        if others:
            social_score = creature.needs.loneliness * 0.12 + creature.traits.get("friendliness", 0.5) * 7
            social_score -= creature.needs.fear * 0.05
            candidates.append(ActionScore("follow", social_score + self.noise(1.2), others[0].id, "loneliness and social pull"))
            play_score = creature.needs.happiness * 0.035 + creature.traits.get("friendliness", 0.5) * 6
            play_score += max(0.0, creature.needs.energy - 35) * 0.08 - creature.traits.get("aggression", 0.5) * 2
            candidates.append(ActionScore("play", play_score + self.noise(1.0), others[0].id, "friendly energy"))
            spar_score = self.combat_interest(creature) + creature.traits.get("bravery", 0.5) * 5
            spar_score += creature.combat.level * 0.6 - creature.needs.fear * 0.08
            spar_score += max(0.0, creature.needs.energy - 35) * 0.05
            candidates.append(ActionScore("spar", spar_score + self.noise(1.3), others[0].id, "combat confidence and rivalry pressure"))

        candidates.sort(key=lambda item: item.score, reverse=True)
        chosen = candidates[0]
        memory = creature.strongest_memory()
        belief = creature.beliefs.strongest()
        explanation = self.explain(creature, chosen, memory, belief)
        decision = Decision(
            action=chosen.action,
            target_id=chosen.target_id,
            scores=candidates[:3],
            dominant_need=creature.needs.dominant(),
            strongest_memory=memory.short_text if memory else "none",
            strongest_belief=f"{belief.key}: {belief.valence:+.2f} conf {belief.confidence:.2f}" if belief else "none",
            explanation=explanation,
        )
        creature.current_action = decision.action
        creature.target_id = decision.target_id
        creature.decision_debug = {
            "top_scores": [
                {"action": score.action, "score": round(score.score, 2), "reason": score.reason}
                for score in decision.scores
            ],
            "dominant_need": decision.dominant_need,
            "strongest_memory": decision.strongest_memory,
            "strongest_belief": decision.strongest_belief,
            "explanation": decision.explanation,
        }
        return decision

    def food_score(self, creature, obj: WorldObject, weather: str) -> float:
        belief = creature.beliefs.about("object_type", obj.object_type)
        tag_belief = creature.beliefs.about("tag", obj.traits.get("color"))
        negative = max(0.0, -belief.valence * belief.confidence)
        tag_negative = max(0.0, -tag_belief.valence * tag_belief.confidence)
        positive = max(0.0, belief.valence * belief.confidence)
        risk_softener = creature.traits.get("bravery", 0.5) * 10 + creature.traits.get("risk_tolerance", 0.5) * 8
        fear_penalty = negative * max(6.0, 22.0 - risk_softener) + tag_negative * 6
        score = creature.needs.hunger * 0.12 + obj.traits.get("nutrition", 10) * 0.07
        score += positive * 15 + creature.traits.get("risk_tolerance", 0.5) * 8
        score += creature.traits.get("bravery", 0.5) * 8 - fear_penalty
        score -= creature.needs.fear * 0.035
        if obj.object_type == "blue_fruit" and weather == "rain":
            score -= (1.0 - creature.traits.get("blue_fruit_tolerance", 0.5)) * 4.5
        return score + self.noise(1.2)

    def avoid_score(self, creature, obj: WorldObject) -> float:
        belief = creature.beliefs.about("object_type", obj.object_type)
        tag_belief = creature.beliefs.about("tag", obj.traits.get("color"))
        negative = max(0.0, -belief.valence * belief.confidence)
        tag_negative = max(0.0, -tag_belief.valence * tag_belief.confidence)
        score = negative * 40 + tag_negative * 10 + creature.needs.fear * 0.1
        score += creature.traits.get("pain_sensitivity", 0.5) * 9
        score -= creature.traits.get("bravery", 0.5) * 12
        score -= creature.needs.hunger * 0.055
        if negative <= 0.02 and tag_negative <= 0.02:
            score -= 8
        return score + self.noise(1.0)

    def observe_score(self, creature, obj: WorldObject) -> float:
        belief = creature.beliefs.about("object_type", obj.object_type)
        uncertainty = 1.0 - belief.confidence
        return (
            creature.traits.get("curiosity", 0.5) * 7
            + uncertainty * 5
            + creature.needs.fear * 0.035
            - creature.traits.get("bravery", 0.5) * 1.5
            + self.noise(1.0)
        )

    def object_belief_bonus(self, creature, obj: WorldObject) -> float:
        belief = creature.beliefs.about("object_type", obj.object_type)
        return belief.valence * belief.confidence * 10

    def combat_interest(self, creature) -> float:
        score = creature.traits.get("aggression", 0.5) * 8
        score += creature.traits.get("bravery", 0.5) * 5
        score += creature.traits.get("curiosity", 0.5) * 2
        score += creature.aggression_boost * 0.18
        score -= creature.needs.fear * 0.06
        score -= max(0.0, 35 - creature.needs.energy) * 0.12
        if creature.combat.injured_ticks > 0:
            score -= 8
        return score

    def explain(self, creature, chosen: ActionScore, memory, belief) -> str:
        parts = [f"{creature.name} chose {chosen.action} because {chosen.reason} scored highest."]
        if belief:
            if belief.valence < -0.2:
                parts.append(f"Negative belief about {belief.key} pushed caution.")
            elif belief.valence > 0.2:
                parts.append(f"Positive belief about {belief.key} made it appealing.")
        if memory:
            parts.append(f"Memory: {memory.short_text}")
        parts.append(f"Dominant pressure: {creature.needs.dominant()}.")
        return " ".join(parts)

    def noise(self, spread: float) -> float:
        return self.rng.uniform(-spread, spread)
