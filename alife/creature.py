from __future__ import annotations

import random
from dataclasses import asdict, dataclass, field

from alife.beliefs import BeliefBook
from alife.genetics import color_from_traits, random_traits
from alife.memory import Memory
from alife.utils import clamp, random_id


CREATURE_NAMES = ("Nimi", "Lumo", "Tavi", "Mira", "Poki", "Sola", "Venn", "Kiri", "Omi")


@dataclass
class Needs:
    hunger: float = 35.0
    energy: float = 80.0
    health: float = 92.0
    happiness: float = 55.0
    fear: float = 8.0
    loneliness: float = 35.0
    comfort: float = 55.0

    def clamp_all(self) -> None:
        for name in self.__dataclass_fields__:
            setattr(self, name, clamp(getattr(self, name), 0.0, 100.0))

    def dominant(self) -> str:
        pressures = {
            "hunger": self.hunger,
            "low energy": 100.0 - self.energy,
            "low health": 100.0 - self.health,
            "fear": self.fear,
            "loneliness": self.loneliness,
            "low comfort": 100.0 - self.comfort,
        }
        return max(pressures, key=pressures.get)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Needs":
        return cls(**data)


@dataclass
class Relationship:
    trust: float = 0.0
    fear: float = 0.0
    attachment: float = 0.0
    rivalry: float = 0.0
    familiarity: float = 0.0
    kinship: float = 0.0

    def clamp_all(self) -> None:
        for name in self.__dataclass_fields__:
            setattr(self, name, clamp(getattr(self, name), 0.0, 1.0))

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Relationship":
        return cls(**data)


@dataclass
class CombatStats:
    level: int = 1
    xp: float = 0.0
    strength: float = 1.0
    guard: float = 1.0
    focus: float = 1.0
    wins: int = 0
    losses: int = 0
    injured_ticks: int = 0

    def gain_xp(self, amount: float) -> bool:
        self.xp += max(0.0, amount)
        leveled = False
        while self.xp >= self.next_level_xp():
            self.xp -= self.next_level_xp()
            self.level += 1
            self.strength += 0.18
            self.guard += 0.14
            self.focus += 0.12
            leveled = True
        return leveled

    def next_level_xp(self) -> float:
        return 18.0 + self.level * 8.0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "CombatStats":
        return cls(**data)


@dataclass
class Creature:
    id: str
    name: str
    x: float
    y: float
    generation: int
    age: int
    parents: list[str]
    color: tuple[int, int, int]
    body_size: float
    alive: bool
    needs: Needs
    traits: dict[str, float]
    combat: CombatStats = field(default_factory=CombatStats)
    fear_boost: float = 0.0
    aggression_boost: float = 0.0
    comfort_boost: float = 0.0
    relationships: dict[str, Relationship] = field(default_factory=dict)
    memories: list[Memory] = field(default_factory=list)
    beliefs: BeliefBook = field(default_factory=BeliefBook)
    current_action: str = "wander"
    target_id: str | None = None
    wander_target: tuple[float, float] | None = None
    decision_debug: dict = field(default_factory=dict)
    speech: str = ""
    speech_timer: int = 0
    action_cooldown: int = 0
    breed_cooldown: int = 0

    @classmethod
    def create(
        cls,
        name: str | None = None,
        x: float = 100.0,
        y: float = 100.0,
        seed: int | None = None,
        traits: dict[str, float] | None = None,
        generation: int = 1,
        parents: list[str] | None = None,
        age: int | None = None,
    ) -> "Creature":
        rng = random.Random(seed)
        traits = dict(traits or random_traits(rng=rng))
        name = name or rng.choice(CREATURE_NAMES)
        color = color_from_traits(traits)
        size = 12 + traits.get("stubbornness", 0.5) * 8 + traits.get("aggression", 0.5) * 5
        return cls(
            id=random_id("cre"),
            name=name,
            x=x,
            y=y,
            generation=generation,
            age=age if age is not None else rng.randint(950, 1600),
            parents=list(parents or []),
            color=color,
            body_size=size,
            alive=True,
            needs=Needs(),
            traits=traits,
        )

    def is_adult(self, adult_age: int) -> bool:
        return self.alive and self.age >= adult_age

    def relationship_with(self, other_id: str) -> Relationship:
        if other_id not in self.relationships:
            self.relationships[other_id] = Relationship()
        return self.relationships[other_id]

    def add_memory(self, memory: Memory) -> None:
        self.memories.append(memory)
        self.beliefs.update_from_memory(memory)

    def strongest_memory(self, object_type: str | None = None) -> Memory | None:
        memories = self.memories
        if object_type:
            memories = [memory for memory in memories if memory.object_type == object_type]
        if not memories:
            return None
        return max(memories, key=lambda memory: memory.importance * memory.confidence)

    def tick_needs(self, weather: str) -> None:
        cold_pressure = 1.0 - self.traits.get("cold_tolerance", 0.5)
        self.age += 1
        self.needs.hunger += 0.018
        self.needs.energy -= 0.017 + (0.02 * cold_pressure if weather == "cold" else 0.0)
        self.needs.loneliness += 0.012
        self.needs.comfort -= 0.008
        self.needs.fear += self.fear_boost * 0.01
        self.needs.happiness += 0.012 if weather == "sunny" else -0.004
        if self.needs.hunger > 88:
            self.needs.health -= 0.025
        if self.needs.energy < 12:
            self.needs.health -= 0.018
        self.fear_boost *= 0.985
        self.aggression_boost *= 0.985
        self.comfort_boost *= 0.99
        self.speech_timer = max(0, self.speech_timer - 1)
        self.action_cooldown = max(0, self.action_cooldown - 1)
        self.breed_cooldown = max(0, self.breed_cooldown - 1)
        self.combat.injured_ticks = max(0, self.combat.injured_ticks - 1)
        self.needs.clamp_all()
        if self.needs.health <= 0:
            self.alive = False
            self.current_action = "dead"

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "x": self.x,
            "y": self.y,
            "generation": self.generation,
            "age": self.age,
            "parents": self.parents,
            "color": list(self.color),
            "body_size": self.body_size,
            "alive": self.alive,
            "needs": self.needs.to_dict(),
            "traits": self.traits,
            "combat": self.combat.to_dict(),
            "fear_boost": self.fear_boost,
            "aggression_boost": self.aggression_boost,
            "comfort_boost": self.comfort_boost,
            "relationships": {key: rel.to_dict() for key, rel in self.relationships.items()},
            "memories": [memory.to_dict() for memory in self.memories],
            "beliefs": self.beliefs.to_list(),
            "current_action": self.current_action,
            "target_id": self.target_id,
            "wander_target": list(self.wander_target) if self.wander_target else None,
            "decision_debug": self.decision_debug,
            "speech": self.speech,
            "speech_timer": self.speech_timer,
            "action_cooldown": self.action_cooldown,
            "breed_cooldown": self.breed_cooldown,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Creature":
        creature = cls(
            id=data["id"],
            name=data["name"],
            x=data["x"],
            y=data["y"],
            generation=data["generation"],
            age=data["age"],
            parents=list(data.get("parents", [])),
            color=tuple(data["color"]),
            body_size=data["body_size"],
            alive=data.get("alive", True),
            needs=Needs.from_dict(data["needs"]),
            traits=dict(data["traits"]),
            combat=CombatStats.from_dict(data.get("combat", {})),
            fear_boost=data.get("fear_boost", 0.0),
            aggression_boost=data.get("aggression_boost", 0.0),
            comfort_boost=data.get("comfort_boost", 0.0),
            relationships={
                key: Relationship.from_dict(value) for key, value in data.get("relationships", {}).items()
            },
            memories=[Memory.from_dict(item) for item in data.get("memories", [])],
            beliefs=BeliefBook.from_list(data.get("beliefs", [])),
            current_action=data.get("current_action", "wander"),
            target_id=data.get("target_id"),
            wander_target=tuple(data["wander_target"]) if data.get("wander_target") else None,
            decision_debug=data.get("decision_debug", {}),
            speech=data.get("speech", ""),
            speech_timer=data.get("speech_timer", 0),
            action_cooldown=data.get("action_cooldown", 0),
            breed_cooldown=data.get("breed_cooldown", 0),
        )
        return creature
