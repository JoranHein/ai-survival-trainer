from __future__ import annotations

from dataclasses import asdict, dataclass, field

from alife.utils import clamp


@dataclass
class Belief:
    key_type: str
    key: str
    valence: float = 0.0
    confidence: float = 0.0
    reason: str = "unknown"
    evidence: int = 0
    last_updated: int = 0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Belief":
        return cls(**data)


@dataclass
class BeliefBook:
    beliefs: dict[str, Belief] = field(default_factory=dict)

    def _key(self, key_type: str, key: str) -> str:
        return f"{key_type}:{key}"

    def about(self, key_type: str, key: str | None) -> Belief:
        if not key:
            return Belief(key_type, "unknown")
        return self.beliefs.get(self._key(key_type, key), Belief(key_type, key))

    def set_belief(
        self,
        key_type: str,
        key: str,
        valence: float,
        confidence: float,
        reason: str,
        tick: int = 0,
    ) -> Belief:
        belief = Belief(
            key_type=key_type,
            key=key,
            valence=clamp(valence, -1.0, 1.0),
            confidence=clamp(confidence, 0.0, 1.0),
            reason=reason,
            evidence=1,
            last_updated=tick,
        )
        self.beliefs[self._key(key_type, key)] = belief
        return belief

    def update_from_memory(self, memory) -> None:
        base_valence = self._outcome_valence(memory.outcome, memory.emotion)
        source_weight = {"personal": 1.0, "observed": 0.48, "social": 0.36}.get(memory.source, 0.4)
        strength = clamp(memory.importance * memory.confidence * source_weight, 0.0, 1.0)
        if memory.object_type:
            self._apply(
                "object_type",
                memory.object_type,
                base_valence,
                strength,
                memory.short_text,
                memory.tick,
            )
        color = memory.object_traits.get("color") if memory.object_traits else None
        if color:
            # Trait generalization creates useful but imperfect beliefs.
            self._apply("tag", color, base_valence * 0.38, strength * 0.55, memory.short_text, memory.tick)

    def decay(self, amount: float = 0.00008) -> None:
        for belief in self.beliefs.values():
            belief.confidence = clamp(belief.confidence - amount, 0.0, 1.0)
            belief.valence *= 1.0 - amount * 0.25

    def strongest(self) -> Belief | None:
        if not self.beliefs:
            return None
        return max(self.beliefs.values(), key=lambda item: abs(item.valence) * item.confidence)

    def _apply(
        self,
        key_type: str,
        key: str,
        evidence_valence: float,
        strength: float,
        reason: str,
        tick: int,
    ) -> None:
        storage_key = self._key(key_type, key)
        belief = self.beliefs.get(storage_key, Belief(key_type=key_type, key=key))
        alpha = clamp(0.15 + strength * 0.7, 0.05, 0.85)
        belief.valence = clamp(belief.valence * (1.0 - alpha) + evidence_valence * alpha, -1.0, 1.0)
        belief.confidence = clamp(belief.confidence + strength * (1.0 - belief.confidence) * 0.72, 0.0, 1.0)
        belief.reason = reason
        belief.evidence += 1
        belief.last_updated = tick
        self.beliefs[storage_key] = belief

    def _outcome_valence(self, outcome: str, emotion: str) -> float:
        if outcome in {"sick", "hurt"}:
            return -1.0
        if outcome in {"scared", "warning"}:
            return -0.72
        if outcome in {"good", "fed", "happy", "rested"}:
            return 0.74
        if outcome in {"calm", "safe"}:
            return 0.48
        if emotion == "fear":
            return -0.55
        if emotion in {"happy", "comfort"}:
            return 0.42
        return 0.0

    def to_list(self) -> list[dict]:
        return [belief.to_dict() for belief in self.beliefs.values()]

    @classmethod
    def from_list(cls, data: list[dict]) -> "BeliefBook":
        book = cls()
        for item in data:
            belief = Belief.from_dict(item)
            book.beliefs[book._key(belief.key_type, belief.key)] = belief
        return book
