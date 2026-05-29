from __future__ import annotations

import random
import math
from dataclasses import asdict, dataclass, field

from alife.brain import LocalBrainModel
from alife.utils import clamp, move_toward, random_id


VOCABULARY_WORDS = [
    "eat",
    "fruit",
    "tree",
    "night",
    "use",
    "bow",
    "train",
    "defense",
    "attack",
    "strength",
    "hide",
    "sword",
    "book",
    "at",
    "before",
    "hp",
    "rest",
    "sleep",
    "bed",
]


UPGRADES: dict[str, dict] = {
    "max_hp": {"name": "Max HP", "cost": 20, "field": "hitpoints", "amount": 5},
    "attack": {"name": "Attack", "cost": 25, "field": "attack", "amount": 1},
    "defense": {"name": "Defense", "cost": 25, "field": "defense", "amount": 1},
    "strength": {"name": "Strength", "cost": 30, "field": "strength", "amount": 1},
    "bow_mastery": {"name": "Bow Mastery", "cost": 35, "field": "bow", "amount": 1},
    "training_speed": {"name": "Training Speed", "cost": 40, "field": "training_speed", "amount": 1},
    "word_learning_speed": {"name": "Word Research", "cost": 65, "field": "word_learning_speed", "amount": 1},
    "tree_growth": {"name": "Fruit Tree", "cost": 45, "field": "tree_growth", "amount": 1},
    "passive_healing": {"name": "Passive Healing", "cost": 55, "field": "passive_healing", "amount": 1},
}

STATION_WORDS: dict[str, list[str]] = {
    "tree": ["tree", "fruit", "eat"],
    "dummy": ["train", "attack", "defense", "strength"],
    "book": ["book", "use", "bow", "sword", "hide"],
    "sign": ["use", "night", "bow", "defense"],
    "bed": ["bed", "rest", "sleep"],
}

ACTION_RADIUS = 55.0


@dataclass
class LearnedStats:
    attack: float = 0.0
    defense: float = 0.0
    strength: float = 0.0
    hitpoints: float = 0.0
    bow: float = 0.0
    sword: float = 0.0
    literacy: float = 0.0

    def reset(self) -> None:
        self.attack = 0.0
        self.defense = 0.0
        self.strength = 0.0
        self.hitpoints = 0.0
        self.bow = 0.0
        self.sword = 0.0
        self.literacy = 0.0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "LearnedStats":
        return cls(**{key: value for key, value in data.items() if key in cls.__dataclass_fields__})


@dataclass
class PermanentStats:
    attack: float = 0.0
    defense: float = 0.0
    strength: float = 0.0
    hitpoints: float = 0.0
    bow: float = 0.0
    sword: float = 0.0
    training_speed: float = 0.0
    word_learning_speed: float = 0.0
    tree_growth: float = 0.0
    passive_healing: float = 0.0
    permanent_words: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "PermanentStats":
        return cls(**{key: value for key, value in data.items() if key in cls.__dataclass_fields__})


@dataclass
class Thought:
    text: str
    age_ticks: int = 0
    lifetime_ticks: int = 180
    push_ticks: int = 30

    def visible_text(self) -> str:
        visible_chars = max(1, min(len(self.text), self.age_ticks // 2))
        return self.text[:visible_chars]

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Thought":
        return cls(**{key: value for key, value in data.items() if key in cls.__dataclass_fields__})


@dataclass
class SurvivalPlan:
    action: str
    score: float
    reasons: list[str] = field(default_factory=list)


@dataclass
class Survivor:
    id: str = field(default_factory=lambda: random_id("survivor"))
    name: str = "Ari"
    x: float = 230.0
    y: float = 330.0
    hp: float = 45.0
    hunger: float = 22.0
    energy: float = 85.0
    fear: float = 15.0
    confidence: float = 30.0
    aggression: float = 0.35
    curiosity: float = 0.55
    charisma: float = 0.55
    perseverance: float = 0.5
    alive: bool = True
    learned: LearnedStats = field(default_factory=LearnedStats)
    beliefs: dict[str, float] = field(default_factory=lambda: {"bow": 0.0, "sword": 0.1, "tree": 0.2, "dummy": 0.15})
    vocabulary: list[str] = field(default_factory=lambda: ["eat", "night"])
    instructions: list[str] = field(default_factory=list)
    last_interpretation: str = ""
    current_action: str = "watching"
    current_weapon: str = "sword"
    speech: str = ""
    speech_timer: int = 0
    thoughts: list[Thought] = field(default_factory=list)
    thought_cooldown: int = 0
    action_timer: int = 0
    committed_action: str | None = None
    commitment_ticks: int = 0
    explore_target: str | None = None
    pending_sign_words: list[str] = field(default_factory=list)
    researching_word: str | None = None
    research_ticks: int = 0

    def max_hp(self, permanent: PermanentStats) -> float:
        return 45.0 + self.learned.hitpoints * 4.0 + permanent.hitpoints

    def reset_for_new_life(self, permanent: PermanentStats, rng: random.Random | None = None) -> None:
        if rng is not None:
            self.reroll_personality(rng)
        self.learned.reset()
        self.hp = self.max_hp(permanent)
        self.hunger = 22.0
        self.energy = 85.0
        self.fear = 15.0
        self.confidence = 30.0
        self.alive = True
        self.instructions.clear()
        self.beliefs = {"bow": 0.0, "sword": 0.1, "tree": 0.2, "dummy": 0.15}
        self.vocabulary = list(dict.fromkeys(permanent.permanent_words))
        self.last_interpretation = ""
        self.current_action = "reborn"
        self.current_weapon = "sword"
        self.speech = "New day one."
        self.speech_timer = 120
        self.thoughts = [Thought("New day one.", lifetime_ticks=180)]
        self.thought_cooldown = 120
        self.action_timer = 0
        self.committed_action = None
        self.commitment_ticks = 0
        self.explore_target = None
        self.pending_sign_words = []
        self.researching_word = None
        self.research_ticks = 0

    def reroll_personality(self, rng: random.Random) -> None:
        self.aggression = rng.uniform(0.05, 0.85)
        self.curiosity = rng.uniform(0.15, 0.95)
        self.charisma = rng.uniform(0.1, 0.9)
        self.perseverance = rng.uniform(0.1, 0.95)

    def personality_signature(self) -> tuple[float, ...]:
        return tuple(round(value, 3) for value in self.personality_summary().values())

    def personality_summary(self) -> dict[str, float]:
        return {
            "aggression": self.aggression,
            "curiosity": self.curiosity,
            "charisma": self.charisma,
            "perseverance": self.perseverance,
        }

    def literacy_drive(self) -> float:
        return clamp(self.curiosity * 0.65 + self.perseverance * 0.35, 0.0, 1.0)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "x": self.x,
            "y": self.y,
            "hp": self.hp,
            "hunger": self.hunger,
            "energy": self.energy,
            "fear": self.fear,
            "confidence": self.confidence,
            "aggression": self.aggression,
            "curiosity": self.curiosity,
            "charisma": self.charisma,
            "perseverance": self.perseverance,
            "alive": self.alive,
            "learned": self.learned.to_dict(),
            "beliefs": self.beliefs,
            "vocabulary": self.vocabulary,
            "instructions": self.instructions,
            "last_interpretation": self.last_interpretation,
            "current_action": self.current_action,
            "current_weapon": self.current_weapon,
            "speech": self.speech,
            "speech_timer": self.speech_timer,
            "thoughts": [thought.to_dict() for thought in self.thoughts],
            "thought_cooldown": self.thought_cooldown,
            "action_timer": self.action_timer,
            "committed_action": self.committed_action,
            "commitment_ticks": self.commitment_ticks,
            "explore_target": self.explore_target,
            "pending_sign_words": self.pending_sign_words,
            "researching_word": self.researching_word,
            "research_ticks": self.research_ticks,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Survivor":
        survivor = cls()
        if "charisma" not in data:
            old_language = data.get("language_ability", survivor.charisma)
            old_trust = data.get("sign_trust", survivor.charisma)
            data = dict(data)
            data["charisma"] = clamp((old_language + old_trust) / 2, 0.0, 1.0)
        if "perseverance" not in data:
            old_discipline = data.get("discipline", survivor.perseverance)
            old_stubbornness = data.get("stubbornness", 1.0 - survivor.perseverance)
            data = dict(data)
            data["perseverance"] = clamp((old_discipline + (1.0 - old_stubbornness)) / 2, 0.0, 1.0)
        for key, value in data.items():
            if key == "learned":
                survivor.learned = LearnedStats.from_dict(value)
            elif key == "thoughts":
                survivor.thoughts = [Thought.from_dict(item) for item in value]
            elif hasattr(survivor, key):
                setattr(survivor, key, value)
        if not survivor.thoughts and survivor.speech:
            survivor.thoughts = [Thought(survivor.speech, age_ticks=0, lifetime_ticks=max(150, survivor.speech_timer))]
        return survivor


@dataclass
class FruitTree:
    x: float = 115.0
    y: float = 170.0
    cooldown_ticks: int = 1800
    remaining_ticks: int = 0

    def ready(self) -> bool:
        return self.remaining_ticks <= 0

    def tick(self, permanent: PermanentStats) -> None:
        reduction = int(permanent.tree_growth * 3)
        self.remaining_ticks = max(0, self.remaining_ticks - max(1, 1 + reduction))

    def pick(self, permanent: PermanentStats) -> bool:
        if not self.ready():
            return False
        cooldown = max(1, self.cooldown_ticks - int(permanent.tree_growth * 90))
        self.remaining_ticks = cooldown
        return True

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "FruitTree":
        return cls(**data)


@dataclass
class TrainingDummy:
    x: float = 405.0
    y: float = 350.0


@dataclass
class Sign:
    x: float = 610.0
    y: float = 170.0
    text: str = "eat before night"

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Sign":
        return cls(**data)


@dataclass
class ReadingStone:
    x: float = 585.0
    y: float = 365.0
    book_title: str = "First Marks"


@dataclass
class Bed:
    x: float = 255.0
    y: float = 535.0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Bed":
        return cls(**data)


@dataclass
class Enemy:
    id: str
    x: float
    y: float
    hp: float
    attack: float
    defense: float
    speed: float

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Enemy":
        return cls(**data)


@dataclass
class IdleSurvivalWorld:
    seed: int | None = None
    ticks_per_second: int = 30
    day_ticks: int = 3600
    night_ticks: int = 900
    tick_count: int = 0
    day: int = 1
    wave: int = 1
    phase: str = "day"
    phase_tick: int = 0
    time_points: float = 0.0
    permanent: PermanentStats = field(default_factory=PermanentStats)
    survivor: Survivor = field(default_factory=Survivor)
    fruit_tree: FruitTree = field(default_factory=FruitTree)
    dummy: TrainingDummy = field(default_factory=TrainingDummy)
    reading_stone: ReadingStone = field(default_factory=ReadingStone)
    bed: Bed = field(default_factory=Bed)
    sign: Sign = field(default_factory=Sign)
    enemies: list[Enemy] = field(default_factory=list)
    messages: list[str] = field(default_factory=list)
    last_brain_thought: str = ""

    def __post_init__(self) -> None:
        self.rng = random.Random(self.seed)
        self.brain = LocalBrainModel()

    @classmethod
    def new_game(cls, seed: int | None = None) -> "IdleSurvivalWorld":
        world = cls(seed=seed)
        world.survivor.reset_for_new_life(world.permanent, world.rng)
        world.message("Day 1. Ari watches the room.")
        return world

    def update(self) -> None:
        self.tick_count += 1
        self.phase_tick += 1
        self.update_thoughts()
        self.survivor.action_timer = max(0, self.survivor.action_timer - 1)
        self.fruit_tree.tick(self.permanent)
        if self.survivor.alive:
            self.gain_time_points()
            self.tick_survivor_needs()
            if self.survivor.committed_action or self.survivor.action_timer <= 0:
                self.choose_and_do_action()
            self.maybe_update_thought()
        if self.phase == "day" and self.phase_tick >= self.day_ticks:
            self.start_night()
        elif self.phase == "night":
            self.update_enemies()
            if not self.enemies:
                self.finish_night()
            elif self.phase_tick >= self.night_ticks and self.survivor.alive:
                self.update_enemies(force_attack=True)

    def gain_time_points(self) -> None:
        rate = self.points_per_second()
        self.time_points += rate / self.ticks_per_second

    def points_per_second(self) -> float:
        return 1.0

    def tick_survivor_needs(self) -> None:
        survivor = self.survivor
        survivor.hunger = clamp(survivor.hunger + 0.018, 0, 100)
        survivor.energy = clamp(survivor.energy + (0.006 if self.phase == "day" else -0.006), 0, 100)
        if self.permanent.passive_healing > 0 and self.phase == "day":
            survivor.hp = clamp(survivor.hp + self.permanent.passive_healing * 0.004, 0, survivor.max_hp(self.permanent))
        if survivor.hunger > 88:
            survivor.hp -= 0.035
            survivor.fear = clamp(survivor.fear + 0.01, 0, 100)
        if survivor.hp <= 0:
            self.kill_survivor("starved")

    def choose_and_do_action(self) -> None:
        if self.phase == "night" and self.enemies:
            self.clear_commitment()
            self.fight_nearest_enemy()
            self.survivor.action_timer = 18
            return
        if self.survivor.committed_action:
            self.survivor.commitment_ticks = max(0, self.survivor.commitment_ticks - 1)
            if self.perform_day_action(self.survivor.committed_action):
                return
            self.clear_commitment()
        action = self.choose_day_action()
        if action in {"eat", "read_sign", "study_book", "explore", "research_word", "rest_in_bed"} or action.startswith("train_"):
            self.survivor.committed_action = action
            self.survivor.commitment_ticks = self.commitment_length(action)
        self.perform_day_action(action)

    def commitment_length(self, action: str) -> int:
        base = 75 if action in {"read_sign", "study_book", "eat", "explore", "research_word", "rest_in_bed"} else 110
        if action.startswith("train_"):
            base = 90
        return base + int(self.survivor.perseverance * 120)

    def perform_day_action(self, action: str) -> bool:
        self.survivor.current_action = action
        if action == "eat":
            if self.move_to_station("tree", self.fruit_tree.x, self.fruit_tree.y):
                if self.pick_fruit():
                    self.clear_commitment()
                    self.survivor.action_timer = 8
                elif self.should_wait_for_fruit():
                    self.survivor.action_timer = 0
                else:
                    self.clear_commitment()
                    self.survivor.action_timer = 8
            else:
                self.survivor.action_timer = 0
            return True
        elif action == "explore":
            if self.explore():
                self.clear_commitment()
                self.survivor.action_timer = 10
            else:
                self.survivor.action_timer = 0
            return True
        elif action.startswith("train_"):
            if self.move_to_station("dummy", self.dummy.x, self.dummy.y):
                stat = action.removeprefix("train_")
                self.survivor.current_action = f"training {stat}"
                if self.survivor.action_timer <= 0:
                    self.train(stat)
                    self.survivor.action_timer = 8
                if self.survivor.commitment_ticks <= 0 or self.survivor.energy < 8:
                    self.clear_commitment()
                    self.survivor.action_timer = 8
            else:
                self.survivor.action_timer = 0
            return True
        elif action == "study_book":
            if self.move_to_station("book", self.reading_stone.x, self.reading_stone.y):
                self.study_book()
                self.clear_commitment()
                self.survivor.action_timer = 10
            else:
                self.survivor.action_timer = 0
            return True
        elif action == "research_word":
            completed = self.research_sign_word()
            if completed and not self.survivor.pending_sign_words and not self.survivor.researching_word:
                self.clear_commitment()
                self.survivor.action_timer = 10
            else:
                self.survivor.action_timer = 0
            return True
        elif action == "rest_in_bed":
            if self.move_to_station("bed", self.bed.x, self.bed.y):
                self.rest_in_bed()
                if self.survivor.energy >= 98 or self.survivor.commitment_ticks <= 0:
                    self.clear_commitment()
                    self.survivor.action_timer = 8
                else:
                    self.survivor.action_timer = 0
            else:
                self.survivor.action_timer = 0
            return True
        elif action == "read_sign":
            self.read_sign()
            self.clear_commitment()
            self.survivor.action_timer = 10
            return True
        else:
            self.idle_move()
            self.survivor.action_timer = 8
            return True

    def clear_commitment(self) -> None:
        self.survivor.committed_action = None
        self.survivor.commitment_ticks = 0
        if self.survivor.explore_target and self.survivor.current_action != f"walking to {self.survivor.explore_target}":
            self.survivor.explore_target = None

    def choose_day_action(self) -> str:
        if self.queue_unknown_sign_words():
            self.last_brain_thought = f"Learning sign word: {self.survivor.researching_word}"
            return "research_word"
        sign_plan = self.sign_action_plan()
        if sign_plan:
            self.last_brain_thought = self.format_plan_thought(sign_plan)
            return sign_plan.action
        plans = self.day_action_plans()
        scores = {action: plan.score for action, plan in plans.items()}
        temperature = self.day_brain_temperature()
        decision = self.brain.choose(scores, self.rng, temperature)
        self.last_brain_thought = self.format_brain_decision(decision, plans)
        return decision.action

    def day_action_scores(self) -> dict[str, float]:
        return {action: plan.score for action, plan in self.day_action_plans().items()}

    def day_action_plans(self) -> dict[str, SurvivalPlan]:
        survivor = self.survivor
        plans: dict[str, SurvivalPlan] = {}

        def add(action: str, score: float, *reasons: str) -> None:
            plans[action] = SurvivalPlan(action, score, [reason for reason in reasons if reason])

        add(
            "wander",
            5.0 + self.rng.uniform(-1.0, 1.0),
            "scan the room",
            "leave room for unexpected discoveries",
        )
        add(
            "read_sign",
            2.2 + survivor.charisma * 5.5 + survivor.curiosity * 1.6 + survivor.perseverance * 1.2,
            "sign may contain a useful plan",
            f"charisma {survivor.charisma:.2f} affects obedience",
        )
        add(
            "train_attack",
            3.2 + survivor.aggression * 4.8 + survivor.perseverance * 2.0 + survivor.confidence * 0.025 - (100 - survivor.energy) * 0.035,
            "attack helps nights end faster",
            f"aggression {survivor.aggression:.2f} pulls toward force",
        )
        add(
            "train_defense",
            3.4 + survivor.perseverance * 3.2 + survivor.fear * 0.025,
            "defense reduces night damage",
            f"fear {survivor.fear:.0f} makes protection valuable",
        )
        add(
            "train_strength",
            3.0 + survivor.aggression * 2.0 + survivor.perseverance * 2.3 + survivor.confidence * 0.02,
            "strength supports close fights",
            f"perseverance {survivor.perseverance:.2f} supports training",
        )
        add(
            "train_hitpoints",
            2.9 + survivor.perseverance * 3.0 + max(0, 65 - survivor.hp) * 0.04,
            "more hitpoints increase survival margin",
            f"current hp {survivor.hp:.0f}",
        )
        add(
            "train_bow",
            2.8 + self.permanent.bow * 0.25 + survivor.perseverance * 1.5 + self.instruction_weight("bow") * 4.0,
            "bow can hit enemies before contact",
            f"bow instruction weight {self.instruction_weight('bow'):.2f}",
        )
        add(
            "study_book",
            2.4 + survivor.curiosity * 4.4 + survivor.literacy_drive() * 2.8 + self.instruction_weight("book") * 2.0,
            "literacy improves sign use",
            f"curiosity {survivor.curiosity:.2f} pulls toward words",
        )
        add(
            "explore",
            2.9 + survivor.curiosity * 6.2 + max(0, 8 - len(survivor.vocabulary)) * 0.35,
            "exploration teaches station words",
            f"known words {len(survivor.vocabulary)}",
        )
        add(
            "rest_in_bed",
            2.2 + max(0, 75 - survivor.energy) * 0.18 + survivor.perseverance * 0.8 - survivor.aggression * 0.5,
            "rest preserves training and fighting energy",
            f"rest {survivor.energy:.0f}",
        )
        if survivor.hunger > 58 and self.fruit_tree.ready():
            add(
                "eat",
                12.0 + survivor.hunger * 0.09 + survivor.perseverance * 0.8 + survivor.beliefs.get("tree", 0.0) * 2.0,
                f"hunger {survivor.hunger:.0f} needs food",
                "fruit is ready now",
            )
        elif survivor.hunger > 82:
            eta = self.travel_ticks_to(self.fruit_tree.x, self.fruit_tree.y)
            ready_in = self.fruit_tree.remaining_ticks
            action = "eat" if ready_in <= eta + self.tree_wait_window_ticks() else "wait_tree"
            add(
                action,
                7.0 + survivor.hunger * 0.04 + survivor.perseverance,
                f"hunger {survivor.hunger:.0f} is rising",
                f"fruit ready in {ready_in} ticks",
                f"tree travel takes about {eta} ticks",
            )
        if self.phase_tick > self.day_ticks * 0.7:
            plans["train_defense"].score += 2.0
            plans["train_defense"].reasons.append("night is getting close")
            plans["train_bow"].score += self.instruction_weight("bow") * 3.0
            if self.instruction_weight("bow") > 0:
                plans["train_bow"].reasons.append("sign mentions bow before night")
        if any(instruction == self.sign.text.lower().strip() for instruction in survivor.instructions):
            plans["read_sign"].score -= 1.8
            plans["read_sign"].reasons.append("sign was already read")
        return plans

    def day_brain_temperature(self) -> float:
        survivor = self.survivor
        temperature = 0.85 + survivor.curiosity * 0.9 + survivor.fear * 0.006 - survivor.perseverance * 0.45
        if survivor.hunger > 82:
            temperature *= 0.65
        return temperature

    def idle_move(self) -> None:
        survivor = self.survivor
        target = self.rng.choice([(self.fruit_tree.x, self.fruit_tree.y), (self.dummy.x, self.dummy.y), (self.sign.x, self.sign.y), (260, 250)])
        survivor.x, survivor.y = move_toward(survivor.x, survivor.y, target[0], target[1], 3.5)
        survivor.current_action = "thinking"

    def station_distance(self, x: float, y: float) -> float:
        return abs(self.survivor.x - x) + abs(self.survivor.y - y)

    def travel_ticks_to(self, x: float, y: float) -> int:
        distance = math.hypot(self.survivor.x - x, self.survivor.y - y)
        usable_distance = max(0.0, distance - ACTION_RADIUS)
        return math.ceil(usable_distance / max(0.1, self.station_move_speed()))

    def move_to_station(self, station: str, x: float, y: float) -> bool:
        if self.station_distance(x, y) <= ACTION_RADIUS:
            return True
        self.survivor.x, self.survivor.y = move_toward(self.survivor.x, self.survivor.y, x, y, self.station_move_speed())
        self.survivor.current_action = f"walking to {station}"
        return False

    def station_move_speed(self) -> float:
        return 7.0

    def pick_fruit(self) -> bool:
        if self.station_distance(self.fruit_tree.x, self.fruit_tree.y) > ACTION_RADIUS:
            self.survivor.current_action = "too far from tree"
            return False
        if not self.fruit_tree.pick(self.permanent):
            self.survivor.current_action = "waiting for fruit"
            return False
        self.survivor.hunger = clamp(self.survivor.hunger - 42, 0, 100)
        self.survivor.energy = clamp(self.survivor.energy + 4, 0, 100)
        self.survivor.beliefs["tree"] = clamp(self.survivor.beliefs.get("tree", 0.0) + 0.08, -1, 1)
        self.survivor.current_action = "eating fruit"
        self.say("Fruit good. Night later.")
        return True

    def tree_wait_window_ticks(self) -> int:
        personality_wait = 4.0 + self.survivor.perseverance * 7.0 + self.survivor.curiosity * 2.0
        return int(personality_wait * self.ticks_per_second)

    def should_wait_for_fruit(self) -> bool:
        if self.fruit_tree.ready():
            return True
        if self.fruit_tree.remaining_ticks > self.tree_wait_window_ticks():
            return False
        return self.survivor.hunger > 68 or "eat fruit" in self.parse_sign_directives(self.sign.text)

    def rest_in_bed(self) -> None:
        if self.station_distance(self.bed.x, self.bed.y) > ACTION_RADIUS:
            self.survivor.current_action = "too far from bed"
            return
        self.survivor.energy = clamp(self.survivor.energy + 1.8 + self.survivor.perseverance * 0.6, 0, 100)
        self.survivor.fear = clamp(self.survivor.fear - 0.35, 0, 100)
        self.survivor.current_action = "resting in bed"
        if self.tick_count % 90 == 0:
            self.say("Bed warm. Rest returns.")

    def train(self, stat: str) -> None:
        if self.station_distance(self.dummy.x, self.dummy.y) > ACTION_RADIUS and stat != "literacy":
            self.survivor.current_action = "too far from dummy"
            return
        if stat not in {"attack", "defense", "strength", "hitpoints", "bow", "sword", "literacy"}:
            return
        current = getattr(self.survivor.learned, stat)
        gain = (0.32 + self.permanent.training_speed * 0.045) / (1.08**current)
        if stat == "bow":
            gain += self.instruction_weight("bow") * 0.12 / (1.08**current)
        if stat == "literacy":
            gain += self.survivor.literacy_drive() * 0.2 / (1.08**current)
        setattr(self.survivor.learned, stat, getattr(self.survivor.learned, stat) + gain)
        self.survivor.energy = clamp(self.survivor.energy - 0.9, 0, 100)
        self.survivor.confidence = clamp(self.survivor.confidence + 0.5, 0, 100)
        self.survivor.current_action = f"training {stat}"
        if self.tick_count % 120 == 0:
            self.say(f"Practice {stat}.")

    def study_book(self) -> None:
        if self.station_distance(self.reading_stone.x, self.reading_stone.y) > ACTION_RADIUS:
            self.survivor.current_action = "too far from book"
            return
        survivor = self.survivor
        gain = 0.18 + survivor.literacy_drive() * 0.28 + survivor.curiosity * 0.12
        survivor.learned.literacy += gain
        survivor.energy = clamp(survivor.energy - 0.45, 0, 100)
        survivor.current_action = "studying book"
        self.unlock_vocabulary()
        if len(survivor.vocabulary) <= 2:
            self.say("Marks are strange.")
        else:
            self.say("New word found.")

    def unlock_vocabulary(self) -> None:
        survivor = self.survivor
        target_count = min(len(VOCABULARY_WORDS), 2 + int(survivor.learned.literacy / 0.85))
        for word in VOCABULARY_WORDS:
            if len(survivor.vocabulary) >= target_count:
                break
            if word not in survivor.vocabulary:
                survivor.vocabulary.append(word)

    def explore(self) -> str | None:
        station, x, y = self.explore_destination()
        if not self.move_to_station(station, x, y):
            return None
        word = self.explore_station(station)
        self.survivor.explore_target = None
        return word

    def explore_destination(self) -> tuple[str, float, float]:
        stations = {
            "tree": (self.fruit_tree.x, self.fruit_tree.y),
            "dummy": (self.dummy.x, self.dummy.y),
            "book": (self.reading_stone.x, self.reading_stone.y),
            "sign": (self.sign.x, self.sign.y),
            "bed": (self.bed.x, self.bed.y),
        }
        if self.survivor.explore_target not in stations:
            self.survivor.explore_target = self.rng.choice(list(stations))
        x, y = stations[self.survivor.explore_target]
        return self.survivor.explore_target, x, y

    def explore_station(self, station: str) -> str:
        words = STATION_WORDS.get(station, [station])
        unknown = [word for word in words if word not in self.survivor.vocabulary]
        word = unknown[0] if unknown else self.rng.choice(words)
        if word not in self.survivor.vocabulary:
            self.survivor.vocabulary.append(word)
        self.survivor.learned.literacy += 0.08 + self.survivor.literacy_drive() * 0.08
        self.survivor.current_action = f"saying {word}"
        self.say(word)
        return word

    def write_sign(self, text: str) -> None:
        self.sign.text = text.strip()[:80] or "survive"
        self.message(f"Sign now says: {self.sign.text}")
        self.survivor.pending_sign_words = []
        self.survivor.researching_word = None
        self.survivor.research_ticks = 0
        self.read_sign()

    def read_sign(self) -> None:
        text = self.sign.text.lower().strip()
        if not text:
            return
        self.survivor.current_action = "thinking about sign"
        if self.queue_unknown_sign_words():
            return
        if text not in self.survivor.instructions:
            self.survivor.instructions.append(text)
        interpreted = self.parse_sign_directives(text)
        for directive in interpreted:
            if directive not in self.survivor.instructions:
                self.survivor.instructions.append(directive)
        if "use bow" in interpreted or "train bow" in interpreted:
            if "use bow" not in self.survivor.instructions:
                self.survivor.instructions.append("use bow")
            self.survivor.beliefs["bow"] = 1.0
        if "use sword" in interpreted or "train sword" in interpreted:
            self.survivor.beliefs["sword"] = 1.0
        if "eat fruit" in interpreted:
            self.survivor.beliefs["tree"] = 1.0
        if "train defense" in interpreted:
            self.survivor.beliefs["defense"] = 1.0
        self.survivor.last_interpretation = ", ".join(interpreted) if interpreted else text
        self.say("Sign says: " + self.survivor.last_interpretation)

    def sign_words(self) -> list[str]:
        cleaned = self.sign.text.lower().replace(".", " ").replace(",", " ")
        words: list[str] = []
        for raw_word in cleaned.split():
            word = "".join(character for character in raw_word if character.isalnum() or character == "_")
            if word and word not in words:
                words.append(word)
        return words

    def word_known(self, word: str) -> bool:
        return word in self.survivor.vocabulary or word in self.permanent.permanent_words

    def unknown_sign_words(self) -> list[str]:
        return [word for word in self.sign_words() if not self.word_known(word)]

    def queue_unknown_sign_words(self) -> bool:
        unknown = self.unknown_sign_words()
        if not unknown:
            self.survivor.pending_sign_words = []
            if self.survivor.researching_word and self.word_known(self.survivor.researching_word):
                self.survivor.researching_word = None
                self.survivor.research_ticks = 0
            return False
        self.survivor.pending_sign_words = unknown
        if self.survivor.researching_word not in unknown:
            self.survivor.researching_word = unknown[0]
            self.survivor.research_ticks = 0
            self.say(f"{self.survivor.researching_word}....")
        self.survivor.current_action = "reading unknown word"
        self.survivor.last_interpretation = f"learning {self.survivor.researching_word}"
        return True

    def research_sign_word(self) -> bool:
        if not self.queue_unknown_sign_words():
            self.read_sign()
            return True
        word = self.survivor.researching_word
        if not word:
            return False
        if self.station_distance(self.reading_stone.x, self.reading_stone.y) > ACTION_RADIUS:
            self.move_to_station("book", self.reading_stone.x, self.reading_stone.y)
            return False
        self.survivor.current_action = f"researching {word}"
        self.survivor.research_ticks += 1
        self.survivor.energy = clamp(self.survivor.energy - 0.02, 0, 100)
        if self.survivor.research_ticks < self.word_research_ticks_required(word):
            return False
        learned_word = word
        self.learn_word(learned_word)
        self.survivor.research_ticks = 0
        self.survivor.researching_word = None
        self.say(learned_word)
        if self.queue_unknown_sign_words():
            return True
        self.read_sign()
        self.say(learned_word)
        return True

    def learn_word(self, word: str) -> None:
        if word not in self.survivor.vocabulary:
            self.survivor.vocabulary.append(word)
        self.survivor.pending_sign_words = [item for item in self.survivor.pending_sign_words if item != word]
        self.survivor.learned.literacy += 0.18 + self.survivor.literacy_drive() * 0.12

    def word_research_ticks_required(self, word: str) -> int:
        base = 65 + len(word) * 9
        reduction = int(self.permanent.word_learning_speed * 14)
        return max(14, base - reduction)

    def parse_sign_directives(self, text: str) -> list[str]:
        words = set(text.lower().replace(".", " ").replace(",", " ").split())
        directives: list[str] = []
        if "eat" in words or "fruit" in words or "tree" in words:
            directives.append("eat fruit")
        if "book" in words or "study" in words or "read" in words:
            directives.append("study book")
        if "rest" in words or "sleep" in words or "bed" in words:
            directives.append("rest")
        for stat in ("attack", "defense", "strength", "hitpoints", "bow", "sword"):
            if stat in words and ("train" in words or stat in {"bow", "sword"}):
                verb = "use" if stat in {"bow", "sword"} and "use" in words else "train"
                directives.append(f"{verb} {stat}")
        if "hp" in words and "train" in words:
            directives.append("train hitpoints")
        if "hide" in words:
            directives.append("hide")
        return directives

    def sign_day_action(self) -> str | None:
        plan = self.sign_action_plan()
        return plan.action if plan else None

    def sign_action_plan(self) -> SurvivalPlan | None:
        directives = self.parse_sign_directives(self.sign.text)
        for directive in directives:
            if directive == "eat fruit":
                plan = self.plan_eat_fruit_from_sign()
                if plan:
                    return plan
                continue
            if directive == "study book":
                return SurvivalPlan("study_book", 12.0, ["sign asks for study", "book can expand words"])
            if directive == "rest":
                return SurvivalPlan("rest_in_bed", 12.0, ["sign asks for rest", "bed restores rest"])
            if directive.startswith("train "):
                stat = directive.split(" ", 1)[1]
                return SurvivalPlan(f"train_{stat}", 12.0, [f"sign asks to train {stat}", "night rewards preparation"])
            if directive == "use bow":
                return SurvivalPlan("train_bow", 12.0, ["sign asks for bow", "bow helps before contact"])
            if directive == "use sword":
                return SurvivalPlan("train_sword", 12.0, ["sign asks for sword", "sword helps close combat"])
        return None

    def plan_eat_fruit_from_sign(self) -> SurvivalPlan | None:
        survivor = self.survivor
        if survivor.hunger <= 52:
            return None
        eta = self.travel_ticks_to(self.fruit_tree.x, self.fruit_tree.y)
        ready_in = max(0, self.fruit_tree.remaining_ticks)
        time_left = max(0, self.day_ticks - self.phase_tick) if self.phase == "day" else 0
        wait_window = self.tree_wait_window_ticks()
        if self.fruit_tree.ready() and survivor.hunger > 55:
            score = 14.0 + survivor.hunger * 0.08 + survivor.perseverance
            return SurvivalPlan("eat", score, ["sign says eat fruit", "fruit ready now", f"arrive in {eta} ticks"])
        if survivor.hunger <= 70:
            return None
        if ready_in <= eta + wait_window and time_left > max(eta, 1):
            timing = "fruit ready before arrival" if ready_in <= eta else f"ready soon after arrival in {ready_in - eta} ticks"
            score = 11.0 + survivor.hunger * 0.06 + survivor.perseverance * 1.5
            score += max(0.0, (wait_window - max(0, ready_in - eta)) / max(1, wait_window)) * 2.0
            return SurvivalPlan(
                "eat",
                score,
                ["sign says eat fruit", timing, f"arrive in {eta} ticks", f"fruit ready in {ready_in} ticks"],
            )
        return None

    def format_plan_thought(self, plan: SurvivalPlan) -> str:
        return f"Plan {plan.action}: " + "; ".join(plan.reasons[:4])

    def format_brain_decision(self, decision, plans: dict[str, SurvivalPlan]) -> str:
        chosen = plans.get(decision.action)
        if not chosen:
            return decision.thought
        reasons = "; ".join(chosen.reasons[:3])
        return f"Brain chose {chosen.action}: {reasons} | options {decision.thought}"

    def instruction_weight(self, keyword: str) -> float:
        if not any(keyword in instruction for instruction in self.survivor.instructions):
            return 0.0
        return clamp(
            0.15
            + self.survivor.charisma * 0.35
            + min(1.0, self.survivor.learned.literacy / 6.0) * 0.25
            + self.survivor.perseverance * 0.2
            + self.survivor.curiosity * 0.1
            - self.survivor.aggression * 0.1,
            0.0,
            1.2,
        )

    def start_night(self) -> None:
        self.phase = "night"
        self.phase_tick = 0
        self.spawn_wave()
        self.survivor.fear = clamp(self.survivor.fear + 10 + self.wave * 0.8, 0, 100)
        self.message(f"Night {self.day}. Wave {self.wave} arrived.")

    def finish_night(self) -> None:
        self.phase = "day"
        self.phase_tick = 0
        self.day += 1
        self.wave += 1
        self.survivor.fear = clamp(self.survivor.fear - 14, 0, 100)
        self.survivor.confidence = clamp(self.survivor.confidence + 6, 0, 100)
        self.survivor.hp = clamp(self.survivor.hp + 4, 0, self.survivor.max_hp(self.permanent))
        self.message(f"Day {self.day}. Ari survived wave {self.wave - 1}.")

    def spawn_wave(self) -> None:
        self.enemies.clear()
        count = 1 + self.wave // 3
        for index in range(count):
            self.enemies.append(
                Enemy(
                    id=random_id("enemy"),
                    x=760.0 + index * 18,
                    y=300.0 + self.rng.uniform(-85, 85),
                    hp=18.0 + self.wave * 5.0,
                    attack=3.2 + self.wave * 0.7,
                    defense=0.8 + self.wave * 0.22,
                    speed=2.0 + min(1.5, self.wave * 0.08),
                )
            )

    def update_enemies(self, force_attack: bool = False) -> None:
        for enemy in list(self.enemies):
            enemy.x, enemy.y = move_toward(enemy.x, enemy.y, self.survivor.x, self.survivor.y, enemy.speed)
            if abs(enemy.x - self.survivor.x) < 26 and abs(enemy.y - self.survivor.y) < 26:
                self.enemy_hits(enemy)
        if force_attack and self.enemies:
            self.enemy_hits(self.enemies[0])

    def fight_nearest_enemy(self) -> None:
        if not self.enemies:
            return
        enemy = min(self.enemies, key=lambda item: abs(item.x - self.survivor.x) + abs(item.y - self.survivor.y))
        distance = abs(enemy.x - self.survivor.x) + abs(enemy.y - self.survivor.y)
        weapon = self.choose_weapon(enemy_distance=distance)
        self.survivor.current_weapon = weapon
        self.survivor.current_action = f"fighting with {weapon}"
        if weapon == "hide":
            self.survivor.fear = clamp(self.survivor.fear - 0.8, 0, 100)
            return
        damage = self.weapon_damage(weapon)
        enemy.hp -= max(1.0, damage - enemy.defense)
        self.survivor.energy = clamp(self.survivor.energy - (0.7 if weapon == "bow" else 0.95), 0, 100)
        if enemy.hp <= 0:
            self.enemies.remove(enemy)
            self.survivor.confidence = clamp(self.survivor.confidence + 4, 0, 100)
            self.survivor.beliefs[weapon] = clamp(self.survivor.beliefs.get(weapon, 0.0) + 0.06, -1, 1)
            self.say(f"{weapon} worked.")

    def choose_weapon(self, enemy_distance: float) -> str:
        if self.unknown_sign_words():
            self.last_brain_thought = f"Learning sign word: {self.unknown_sign_words()[0]}"
        else:
            directives = self.parse_sign_directives(self.sign.text)
            if "use bow" in directives:
                self.last_brain_thought = "Sign order: use bow"
                return "bow"
            if "use sword" in directives:
                self.last_brain_thought = "Sign order: use sword"
                return "sword"
            if "hide" in directives:
                self.last_brain_thought = "Sign order: hide"
                return "hide"
        survivor = self.survivor
        bow_score = (
            self.permanent.bow * 0.8
            + survivor.learned.bow * 1.1
            + survivor.beliefs.get("bow", 0.0) * 7.0
            + survivor.perseverance * 1.8
            + self.instruction_weight("bow") * 11.0
            + (3.0 if enemy_distance > 50 else -4.0)
            - survivor.fear * 0.035
            + self.rng.uniform(-1.0, 1.0)
        )
        sword_score = (
            self.permanent.sword * 0.65
            + survivor.learned.sword * 1.0
            + survivor.learned.attack * 0.65
            + survivor.learned.strength * 0.45
            + survivor.beliefs.get("sword", 0.0) * 4.0
            + (3.0 if enemy_distance <= 55 else -1.0)
            + survivor.confidence * 0.035
            + survivor.aggression * 2.2
            + self.rng.uniform(-1.0, 1.0)
        )
        hide_score = survivor.fear * (0.08 + (1.0 - survivor.aggression) * 0.035 + (1.0 - survivor.perseverance) * 0.025) - survivor.confidence * 0.04 + self.rng.uniform(-0.6, 0.6)
        scores = {"bow": bow_score, "sword": sword_score, "hide": hide_score}
        temperature = 0.65 + survivor.curiosity * 0.35 + (1.0 - survivor.perseverance) * 0.25 - survivor.confidence * 0.002
        decision = self.brain.choose(scores, self.rng, temperature)
        self.last_brain_thought = "Combat: " + decision.thought
        return decision.action

    def weapon_damage(self, weapon: str) -> float:
        survivor = self.survivor
        if weapon == "bow":
            return 5.0 + self.permanent.bow * 1.1 + survivor.learned.bow * 1.2 + survivor.learned.attack * 0.35
        return (
            4.0
            + self.permanent.attack * 0.8
            + self.permanent.strength * 0.55
            + survivor.learned.attack * 0.85
            + survivor.learned.strength * 0.5
            + survivor.learned.sword * 0.7
        )

    def enemy_hits(self, enemy: Enemy) -> None:
        defense = self.permanent.defense * 0.7 + self.survivor.learned.defense * 0.8 + self.survivor.learned.hitpoints * 0.18
        damage = max(1.0, enemy.attack - defense * 0.35)
        self.survivor.hp -= damage
        self.survivor.fear = clamp(self.survivor.fear + damage * 0.7, 0, 100)
        if self.survivor.hp <= 0:
            self.kill_survivor("fell at night")

    def kill_survivor(self, reason: str) -> None:
        self.message(f"Ari died: {reason}. Permanent upgrades remain.")
        self.day = 1
        self.wave = 1
        self.phase = "day"
        self.phase_tick = 0
        self.enemies.clear()
        self.fruit_tree.remaining_ticks = 0
        self.survivor.reset_for_new_life(self.permanent, self.rng)

    def purchase_upgrade(self, upgrade_id: str) -> bool:
        if upgrade_id not in UPGRADES:
            return False
        definition = UPGRADES[upgrade_id]
        current = getattr(self.permanent, definition["field"])
        cost = self.upgrade_cost(upgrade_id)
        if self.time_points < cost:
            self.message(f"Need {cost:.0f} points for {definition['name']}.")
            return False
        self.time_points -= cost
        setattr(self.permanent, definition["field"], current + definition["amount"])
        self.survivor.hp = min(self.survivor.max_hp(self.permanent), self.survivor.hp + definition["amount"])
        self.message(f"Upgraded {definition['name']}.")
        return True

    def purchase_upgrade_slot(self, slot: int) -> bool:
        upgrade_ids = list(UPGRADES)
        if slot < 1 or slot > len(upgrade_ids):
            return False
        return self.purchase_upgrade(upgrade_ids[slot - 1])

    def upgrade_cost(self, upgrade_id: str) -> float:
        definition = UPGRADES[upgrade_id]
        level = getattr(self.permanent, definition["field"]) / max(1, definition["amount"])
        return definition["cost"] * (1.55**level)

    def permanent_word_cost(self, word: str) -> float:
        word = word.lower().strip()
        level = len(self.permanent.permanent_words)
        return (220 + len(word) * 18) * (1.85**level)

    def purchase_permanent_word(self, word: str) -> bool:
        word = word.lower().strip()
        if not word or word in self.permanent.permanent_words:
            return False
        cost = self.permanent_word_cost(word)
        if self.time_points < cost:
            self.message(f"Need {cost:.0f} points to remember '{word}' forever.")
            return False
        self.time_points -= cost
        self.permanent.permanent_words.append(word)
        if word not in self.survivor.vocabulary:
            self.survivor.vocabulary.append(word)
        self.survivor.pending_sign_words = [item for item in self.survivor.pending_sign_words if item != word]
        if self.survivor.researching_word == word:
            self.survivor.researching_word = None
            self.survivor.research_ticks = 0
        self.message(f"Ari will remember '{word}' forever.")
        self.read_sign()
        return True

    def next_permanent_word_candidate(self) -> str | None:
        for word in self.sign_words():
            if word not in self.permanent.permanent_words:
                return word
        for word in ("eat", "fruit", "train", "defense", "bow", "use", "night", "book"):
            if word not in self.permanent.permanent_words:
                return word
        return None

    def say(self, text: str) -> None:
        self.think(text)

    def think(self, text: str, duration: int | None = None) -> None:
        text = text.strip()
        if not text:
            return
        lifetime = duration if duration is not None else self.thought_lifetime(text)
        for thought in self.survivor.thoughts:
            thought.push_ticks = 0
        thought = Thought(text=text[:120], lifetime_ticks=lifetime)
        self.survivor.thoughts.insert(0, thought)
        self.survivor.thoughts = self.survivor.thoughts[:5]
        self.survivor.speech = thought.text
        self.survivor.speech_timer = thought.lifetime_ticks
        self.survivor.thought_cooldown = max(self.survivor.thought_cooldown, min(120, 35 + len(text)))

    def thought_lifetime(self, text: str) -> int:
        return max(145, min(430, 95 + len(text) * 4))

    def update_thoughts(self) -> None:
        self.survivor.thought_cooldown = max(0, self.survivor.thought_cooldown - 1)
        for thought in self.survivor.thoughts:
            thought.age_ticks += 1
            thought.push_ticks = min(30, thought.push_ticks + 1)
        self.survivor.thoughts = [thought for thought in self.survivor.thoughts if thought.age_ticks < thought.lifetime_ticks]
        if self.survivor.thoughts:
            latest = self.survivor.thoughts[0]
            self.survivor.speech = latest.text
            self.survivor.speech_timer = max(0, latest.lifetime_ticks - latest.age_ticks)
        else:
            self.survivor.speech = ""
            self.survivor.speech_timer = 0

    def maybe_update_thought(self) -> None:
        if self.survivor.thought_cooldown > 0:
            return
        self.think(self.generate_thought())

    def generate_thought(self) -> str:
        survivor = self.survivor
        candidates: list[tuple[float, str]] = [
            (1.0, "Tree, dummy, book, sign. I choose."),
            (0.8 + survivor.curiosity * 2.0, "What changes if I look closer?"),
            (0.8 + survivor.perseverance * 2.0, "Hold the plan a little longer."),
            (0.6 + survivor.charisma * 2.0, "Sign order stays in mind."),
            (0.5 + survivor.aggression * 2.0, "If night comes, I want force ready."),
        ]
        if survivor.hunger > 70:
            candidates.append((2.8 + survivor.hunger * 0.03, "Belly pulls toward fruit."))
        if self.fruit_tree.ready():
            candidates.append((1.8 + survivor.hunger * 0.02, "Tree has fruit now."))
        else:
            seconds = max(1, self.fruit_tree.remaining_ticks // self.ticks_per_second)
            candidates.append((0.8, f"Fruit waits {seconds}s. Need another plan."))
        if survivor.fear > 55:
            candidates.append((2.3 + survivor.fear * 0.02, "Fear is loud. Survive first."))
        if self.phase == "night" or self.enemies:
            candidates.append((3.0, "Enemy near. Bow, sword, or hide?"))
        if "training" in survivor.current_action:
            candidates.append((2.5 + survivor.perseverance, "Practice hurts, but practice grows."))
        if "walking to dummy" in survivor.current_action:
            candidates.append((2.4 + survivor.perseverance, "Dummy ahead. Do not drift."))
        if "walking to tree" in survivor.current_action:
            candidates.append((2.4 + survivor.hunger * 0.02, "Tree first. Then think again."))
        if "sign" in survivor.current_action or self.sign.text:
            known = [word for word in self.sign.text.lower().split() if word in survivor.vocabulary]
            if known:
                candidates.append((1.8 + survivor.charisma, "Known sign words: " + ", ".join(known[:4]) + "."))
            else:
                candidates.append((1.0 + survivor.curiosity, "Sign is clear enough to obey."))
        if survivor.learned.literacy < 2 and survivor.curiosity > 0.55:
            candidates.append((1.6 + survivor.curiosity, "Book marks could become words."))
        if survivor.perseverance < 0.3:
            candidates.append((1.5, "Hard to stay with one idea."))
        total = sum(weight for weight, _ in candidates)
        roll = self.rng.uniform(0, total)
        cumulative = 0.0
        for weight, thought in candidates:
            cumulative += weight
            if roll <= cumulative:
                return thought
        return candidates[-1][1]

    def message(self, text: str) -> None:
        self.messages.append(text)
        self.messages = self.messages[-4:]

    def to_dict(self) -> dict:
        return {
            "seed": self.seed,
            "ticks_per_second": self.ticks_per_second,
            "day_ticks": self.day_ticks,
            "night_ticks": self.night_ticks,
            "tick_count": self.tick_count,
            "day": self.day,
            "wave": self.wave,
            "phase": self.phase,
            "phase_tick": self.phase_tick,
            "time_points": self.time_points,
            "permanent": self.permanent.to_dict(),
            "survivor": self.survivor.to_dict(),
            "fruit_tree": self.fruit_tree.to_dict(),
            "bed": self.bed.to_dict(),
            "sign": self.sign.to_dict(),
            "enemies": [enemy.to_dict() for enemy in self.enemies],
            "messages": self.messages,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "IdleSurvivalWorld":
        world = cls(
            seed=data.get("seed"),
            ticks_per_second=data.get("ticks_per_second", 30),
            day_ticks=data.get("day_ticks", 3600),
            night_ticks=data.get("night_ticks", 900),
            tick_count=data.get("tick_count", 0),
            day=data.get("day", 1),
            wave=data.get("wave", 1),
            phase=data.get("phase", "day"),
            phase_tick=data.get("phase_tick", 0),
            time_points=data.get("time_points", 0.0),
            permanent=PermanentStats.from_dict(data.get("permanent", {})),
            survivor=Survivor.from_dict(data.get("survivor", {})),
            fruit_tree=FruitTree.from_dict(data.get("fruit_tree", {})),
            bed=Bed.from_dict(data.get("bed", {})),
            sign=Sign.from_dict(data.get("sign", {})),
            enemies=[Enemy.from_dict(item) for item in data.get("enemies", [])],
            messages=list(data.get("messages", []))[-4:],
        )
        return world
