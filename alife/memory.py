from __future__ import annotations

from dataclasses import asdict, dataclass, field

from alife.utils import clamp, random_id


@dataclass
class Memory:
    id: str
    tick: int
    creature_id: str
    memory_type: str
    subject_id: str
    object_id: str | None
    object_type: str | None
    object_traits: dict
    outcome: str
    emotion: str
    importance: float
    confidence: float
    source: str
    tags: list[str]
    short_text: str

    def decayed_copy(self, current_tick: int, memory_strength: float) -> "Memory":
        age = max(0, current_tick - self.tick)
        decay = 1.0 - min(0.75, age / 60000.0 * (1.1 - memory_strength))
        data = asdict(self)
        data["importance"] = clamp(self.importance * decay, 0.02, 1.0)
        data["confidence"] = clamp(self.confidence * decay, 0.02, 1.0)
        return Memory(**data)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Memory":
        return cls(**data)


@dataclass
class MemoryStore:
    memories: list[Memory] = field(default_factory=list)

    def add(self, memory: Memory) -> Memory:
        self.memories.append(memory)
        return memory

    def record_food_outcome(
        self,
        tick: int,
        creature_id: str,
        object_id: str,
        object_type: str,
        object_traits: dict,
        outcome: str,
        source: str,
        subject_id: str | None = None,
    ) -> Memory:
        negative = outcome in {"sick", "hurt", "scared"}
        emotion = "fear" if negative else "happy"
        if source == "personal":
            importance = 0.9 if negative else 0.62
            confidence = 0.88 if negative else 0.72
            actor = "I ate"
        elif source == "observed":
            importance = 0.45 if negative else 0.32
            confidence = 0.46
            actor = "I saw"
        else:
            importance = 0.36 if negative else 0.28
            confidence = 0.38
            actor = "I heard"
        text_outcome = "got sick" if outcome == "sick" else "felt good"
        memory = Memory(
            id=random_id("mem"),
            tick=tick,
            creature_id=creature_id,
            memory_type="food_outcome",
            subject_id=subject_id or creature_id,
            object_id=object_id,
            object_type=object_type,
            object_traits=dict(object_traits),
            outcome=outcome,
            emotion=emotion,
            importance=clamp(importance, 0.0, 1.0),
            confidence=clamp(confidence, 0.0, 1.0),
            source=source,
            tags=["food", "bad" if negative else "good", object_type],
            short_text=f"{actor} {object_type} and {text_outcome}.",
        )
        return self.add(memory)

    def to_list(self) -> list[dict]:
        return [memory.to_dict() for memory in self.memories]

    @classmethod
    def from_list(cls, data: list[dict]) -> "MemoryStore":
        return cls([Memory.from_dict(item) for item in data])
