from __future__ import annotations

import random
from dataclasses import dataclass, field

from config import (
    ADULT_AGE,
    EAT_DISTANCE,
    INTERACT_DISTANCE,
    ITEM_TYPES,
    SOCIAL_RANGE,
    WEATHER_INTERVAL,
    WEATHER_TYPES,
    WORLD_HEIGHT,
    WORLD_WIDTH,
)
from alife.creature import CREATURE_NAMES, Creature
from alife.decision import DecisionEngine
from alife.genetics import breed_traits
from alife.memory import Memory, MemoryStore
from alife.objects import WorldObject
from alife.social import share_observed_event, warn_about_object
from alife.upgrades import UPGRADE_DEFINITIONS, UpgradeState, default_upgrades
from alife.utils import clamp, distance, move_away, move_toward, random_id
from alife.voice import RuleBasedVoiceProvider


@dataclass
class World:
    seed: int | None = None
    tick_count: int = 0
    weather: str = "sunny"
    creatures: list[Creature] = field(default_factory=list)
    objects: list[WorldObject] = field(default_factory=list)
    event_log: list[str] = field(default_factory=list)
    memory_store: MemoryStore = field(default_factory=MemoryStore)
    resources: dict[str, float] = field(default_factory=lambda: {"care": 100.0, "insight": 30.0})
    upgrades: dict[str, UpgradeState] = field(default_factory=default_upgrades)

    def __post_init__(self) -> None:
        self.rng = random.Random(self.seed)
        self.decision_engine = DecisionEngine(rng=self.rng)
        self.voice_provider = RuleBasedVoiceProvider()

    @classmethod
    def new_game(cls, seed: int | None = None) -> "World":
        world = cls(seed=seed)
        starts = [(150, 180), (345, 235), (560, 185)]
        for index, (x, y) in enumerate(starts):
            creature = Creature.create(name=CREATURE_NAMES[index], x=x, y=y, seed=world.rng.randrange(999999))
            if index == 0:
                creature.traits["blue_fruit_tolerance"] = 0.22
                creature.traits["social_imitation"] = 0.72
            elif index == 1:
                creature.traits["blue_fruit_tolerance"] = 0.82
                creature.traits["bravery"] = 0.76
            else:
                creature.traits["social_imitation"] = 0.86
                creature.traits["friendliness"] = 0.76
            world.creatures.append(creature)
        for object_type, x, y in (
            ("red_fruit", 240, 420),
            ("blue_fruit", 420, 385),
            ("yellow_fruit", 610, 430),
            ("music_stone", 360, 300),
            ("nest", 640, 245),
            ("training_dummy", 525, 290),
        ):
            world.add_object(object_type, x, y)
        world.log("Three creatures woke in the room.")
        return world

    def reset(self) -> None:
        fresh = World.new_game(seed=self.seed)
        self.tick_count = fresh.tick_count
        self.weather = fresh.weather
        self.creatures = fresh.creatures
        self.objects = fresh.objects
        self.event_log = fresh.event_log
        self.memory_store = fresh.memory_store
        self.resources = fresh.resources
        self.upgrades = fresh.upgrades

    def add_object(self, object_type: str, x: float, y: float) -> WorldObject:
        if object_type not in ITEM_TYPES:
            raise ValueError(f"Unknown object type: {object_type}")
        obj = WorldObject.create(object_type, clamp(x, 10, WORLD_WIDTH - 10), clamp(y, 10, WORLD_HEIGHT - 10), self.tick_count)
        self.objects.append(obj)
        if object_type == "bell":
            self.log("A bell rang softly.")
        else:
            self.log(f"Player placed {obj.label().lower()}.")
        return obj

    def update(self) -> None:
        self.tick_count += 1
        if self.tick_count % WEATHER_INTERVAL == 0:
            self.change_weather()
        for creature in list(self.creatures):
            if not creature.alive:
                continue
            creature.tick_needs(self.weather)
            if self.tick_count % 240 == 0:
                creature.beliefs.decay()
            if creature.action_cooldown <= 0:
                self.decision_engine.choose_action(creature, self)
                creature.action_cooldown = 12 + int(creature.traits.get("patience", 0.5) * 14)
            self.execute_action(creature)
        self.apply_passive_upgrades()
        self.update_idle_economy()
        if self.tick_count % 360 == 0:
            self.try_natural_breeding()
        self.update_social_proximity()

    def update_idle_economy(self) -> None:
        modifiers = self.upgrade_modifiers()
        care_gain = 0.0
        insight_gain = 0.0
        for creature in self.creatures:
            if not creature.alive:
                continue
            care_gain += max(0.0, creature.needs.happiness - 50.0) / 50.0
            care_gain *= 0.998 if creature.needs.health < 35 else 1.0
            insight_gain += len(creature.memories) * 0.00005
            insight_gain += sum(rel.attachment + rel.rivalry for rel in creature.relationships.values()) * 0.00004
        self.resources["care"] = self.resources.get("care", 0.0) + care_gain * 0.015 * modifiers["care_mult"]
        self.resources["insight"] = self.resources.get("insight", 0.0) + insight_gain * modifiers["insight_mult"]

    def apply_passive_upgrades(self) -> None:
        modifiers = self.upgrade_modifiers()
        for creature in self.creatures:
            if not creature.alive:
                continue
            creature.needs.hunger -= modifiers["auto_food_rate"]
            creature.needs.health += modifiers["healing_rate"] if creature.combat.injured_ticks > 0 else 0.0
            creature.aggression_boost += modifiers["aggression_pressure"]
            creature.needs.clamp_all()

    def upgrade_modifiers(self) -> dict[str, float]:
        level = lambda upgrade_id: self.upgrades.get(upgrade_id, UpgradeState(upgrade_id)).level
        return {
            "care_mult": 1.0 + level("auto_feeder") * 0.08,
            "insight_mult": 1.0 + level("combat_journal") * 0.22,
            "training_xp_mult": 1.0 + level("training_corner") * 0.35,
            "item_power_mult": 1.0 + level("item_shelf") * 0.22,
            "combat_insight_mult": 1.0 + level("combat_journal") * 0.32,
            "spar_xp_mult": 1.0 + level("arena_mat") * 0.28,
            "injury_mult": max(0.38, 1.0 - level("med_station") * 0.2),
            "auto_food_rate": level("auto_feeder") * 0.018,
            "aggression_pressure": level("arena_mat") * 0.002,
            "healing_rate": level("med_station") * 0.035,
        }

    def purchase_upgrade(self, upgrade_id: str) -> bool:
        if upgrade_id not in UPGRADE_DEFINITIONS:
            return False
        state = self.upgrades.setdefault(upgrade_id, UpgradeState(upgrade_id))
        definition = UPGRADE_DEFINITIONS[upgrade_id]
        if state.level >= definition["max_level"]:
            self.log(f"{definition['name']} is already max level.")
            return False
        scale = 1.0 + state.level * 0.65
        cost = {name: amount * scale for name, amount in definition["cost"].items()}
        if any(self.resources.get(name, 0.0) < amount for name, amount in cost.items()):
            self.log(f"Not enough resources for {definition['name']}.")
            return False
        for name, amount in cost.items():
            self.resources[name] = self.resources.get(name, 0.0) - amount
        state.level += 1
        self.log(f"Upgraded {definition['name']} to level {state.level}.")
        return True

    def purchase_upgrade_slot(self, slot: int) -> bool:
        upgrade_ids = list(UPGRADE_DEFINITIONS)
        if slot < 1 or slot > len(upgrade_ids):
            return False
        return self.purchase_upgrade(upgrade_ids[slot - 1])

    def change_weather(self) -> None:
        choices = [item for item in WEATHER_TYPES if item != self.weather]
        self.weather = self.rng.choice(choices)
        self.log(f"Weather changed to {self.weather}.")

    def perceived_objects(self, creature: Creature, radius: float) -> list[WorldObject]:
        return [
            obj
            for obj in self.objects
            if distance((creature.x, creature.y), (obj.x, obj.y)) <= radius
        ]

    def perceived_creatures(self, creature: Creature, radius: float) -> list[Creature]:
        return [
            other
            for other in self.creatures
            if other.id != creature.id
            and other.alive
            and distance((creature.x, creature.y), (other.x, other.y)) <= radius
        ]

    def execute_action(self, creature: Creature) -> None:
        if creature.current_action == "dead":
            return
        target_object = self.object_by_id(creature.target_id)
        target_creature = self.creature_by_id(creature.target_id)
        speed = 1.25 + creature.traits.get("bravery", 0.5) * 0.45 + max(0, creature.needs.energy - 25) * 0.012

        if creature.current_action in {"seek_food", "eat"} and target_object:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_object.x, target_object.y, speed)
            if distance((creature.x, creature.y), (target_object.x, target_object.y)) <= EAT_DISTANCE:
                self.eat_object(creature, target_object)
        elif creature.current_action == "avoid" and target_object:
            creature.x, creature.y = move_away(
                creature.x,
                creature.y,
                target_object.x,
                target_object.y,
                speed * 1.25,
                (WORLD_WIDTH, WORLD_HEIGHT),
            )
        elif creature.current_action in {"investigate_object", "observe"} and target_object:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_object.x, target_object.y, speed * 0.75)
            if distance((creature.x, creature.y), (target_object.x, target_object.y)) <= INTERACT_DISTANCE:
                self.touch_object(creature, target_object)
        elif creature.current_action == "rest_in_nest" and target_object:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_object.x, target_object.y, speed * 0.7)
            if distance((creature.x, creature.y), (target_object.x, target_object.y)) <= INTERACT_DISTANCE:
                self.rest_in_nest(creature, target_object)
        elif creature.current_action in {"follow", "play"} and target_creature:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_creature.x, target_creature.y, speed)
            if distance((creature.x, creature.y), (target_creature.x, target_creature.y)) <= 34:
                self.socialize(creature, target_creature, play=creature.current_action == "play")
        elif creature.current_action == "spar" and target_creature:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_creature.x, target_creature.y, speed)
            if distance((creature.x, creature.y), (target_creature.x, target_creature.y)) <= 34:
                self.resolve_spar(creature, target_creature)
                creature.action_cooldown = 80
                target_creature.action_cooldown = 80
        elif creature.current_action == "train" and target_object:
            creature.x, creature.y = move_toward(creature.x, creature.y, target_object.x, target_object.y, speed * 0.75)
            if distance((creature.x, creature.y), (target_object.x, target_object.y)) <= INTERACT_DISTANCE:
                self.train_with_dummy(creature, target_object)
                creature.action_cooldown = 70
        elif creature.current_action == "warn" and target_object:
            self.warn_nearby(creature, target_object)
        elif creature.current_action == "sleep":
            creature.needs.energy += 0.08
            creature.needs.comfort += 0.02
            creature.needs.fear -= 0.02
            creature.needs.clamp_all()
        else:
            self.wander(creature, speed)

    def eat_object(self, creature: Creature, obj: WorldObject) -> None:
        if not obj.is_food or obj not in self.objects:
            return
        obj.uses += 1
        outcome = "good"
        if obj.object_type == "blue_fruit":
            risk = obj.traits.get("sickness_base", 0.1)
            risk += 0.22 if self.weather == "rain" else 0.0
            risk += 0.08 if self.weather == "cold" else 0.0
            risk += (1.0 - creature.traits.get("blue_fruit_tolerance", 0.5)) * 0.42
            risk += creature.traits.get("pain_sensitivity", 0.5) * 0.06
            if self.rng.random() < clamp(risk, 0.02, 0.92):
                outcome = "sick"
        elif self.rng.random() < obj.traits.get("sickness_base", 0.02):
            outcome = "sick"

        if outcome == "sick":
            creature.needs.health -= 12 + creature.traits.get("pain_sensitivity", 0.5) * 16
            creature.needs.fear += 18 + creature.traits.get("pain_sensitivity", 0.5) * 14
            creature.needs.happiness -= 12
            creature.fear_boost += 14
            self.log(f"{creature.name} ate {obj.label().lower()} and became sick.")
        else:
            creature.needs.hunger -= obj.traits.get("nutrition", 15)
            creature.needs.energy += obj.traits.get("energy", 0)
            creature.needs.happiness += obj.traits.get("happiness", 3)
            if obj.object_type == "yellow_fruit":
                creature.aggression_boost += obj.traits.get("aggression_boost", 12)
            self.log(f"{creature.name} ate {obj.label().lower()} and felt good.")
        creature.needs.clamp_all()

        memory = self.memory_store.record_food_outcome(
            tick=self.tick_count,
            creature_id=creature.id,
            object_id=obj.id,
            object_type=obj.object_type,
            object_traits=obj.traits,
            outcome=outcome,
            source="personal",
        )
        creature.add_memory(memory)
        creature.speech = self.voice_provider.generate_speech(
            creature, {"action": "eat", "object_type": obj.object_type, "outcome": outcome}
        )
        creature.speech_timer = 105 if creature.speech else 0
        self.share_event(creature, memory)
        if obj in self.objects:
            self.objects.remove(obj)

    def touch_object(self, creature: Creature, obj: WorldObject) -> None:
        obj.uses += 1
        if obj.object_type == "bell":
            bad_belief = creature.beliefs.about("object_type", "bell")
            scared = bad_belief.valence < -0.25 or (
                self.rng.random() < obj.traits.get("scary", 0.2) * (1.0 - creature.traits.get("bravery", 0.5))
            )
            outcome = "scared" if scared else "good"
            creature.needs.fear += 12 if scared else -4
            creature.needs.happiness += -5 if scared else 3
            memory = Memory(
                id=f"mem_{self.rng.randrange(10000000):07d}",
                tick=self.tick_count,
                creature_id=creature.id,
                memory_type="object_interaction",
                subject_id=creature.id,
                object_id=obj.id,
                object_type=obj.object_type,
                object_traits=dict(obj.traits),
                outcome=outcome,
                emotion="fear" if scared else "happy",
                importance=0.58 if scared else 0.34,
                confidence=0.66 if scared else 0.44,
                source="personal",
                tags=["sound", obj.object_type],
                short_text=f"The bell {'scared me' if scared else 'made a sound'}.",
            )
            self.memory_store.add(memory)
            creature.add_memory(memory)
            self.log(f"{creature.name} {'was startled by' if scared else 'rang'} the bell.")
            self.share_event(creature, memory)
        elif obj.object_type == "music_stone":
            creature.needs.fear -= 0.25
            creature.needs.comfort += 0.12
            creature.needs.happiness += 0.05
            if self.tick_count % 150 == 0:
                self.add_object_memory(creature, obj, "calm", "comfort", 0.38, f"{creature.name} likes the music stone.")
        elif obj.object_type == "nest":
            self.rest_in_nest(creature, obj)
        elif obj.object_type == "training_dummy":
            self.train_with_dummy(creature, obj)
        elif obj.traits.get("combat_item"):
            self.apply_combat_item_touch(creature, obj)
        creature.needs.clamp_all()
        if not creature.speech:
            creature.speech = self.voice_provider.generate_speech(
                creature, {"action": "investigate_object", "object_type": obj.object_type}
            )
            creature.speech_timer = 80 if creature.speech else 0

    def apply_combat_item_touch(self, creature: Creature, obj: WorldObject) -> None:
        obj.uses += 1
        power = self.upgrade_modifiers()["item_power_mult"]
        if obj.object_type == "soft_gloves":
            creature.needs.fear -= 4 * power
            creature.needs.happiness += 2
            outcome = "safe"
            text = f"{creature.name} thinks soft gloves make sparring safer."
        elif obj.object_type == "spiky_charm":
            creature.aggression_boost += 8 * power
            creature.needs.fear += obj.traits.get("fear_risk", 0.1) * 8
            outcome = "bold"
            text = f"{creature.name} felt sharper near the spiky charm."
        elif obj.object_type == "calm_band":
            creature.aggression_boost = max(0.0, creature.aggression_boost - 7 * power)
            creature.needs.fear -= 7 * power
            creature.combat.guard += 0.01 * power
            outcome = "calm"
            text = f"{creature.name} steadied near the calm band."
        elif obj.object_type == "battle_drum":
            creature.aggression_boost += 5 * power
            creature.needs.fear += (1.0 - creature.traits.get("bravery", 0.5)) * 5
            outcome = "charged"
            text = f"{creature.name} heard the battle drum."
        else:
            creature.combat.focus += 0.01 * power
            outcome = "lucky"
            text = f"{creature.name} carried a lucky thought from the pebble."
        memory = self.add_object_memory(creature, obj, outcome, "focus", 0.32, text)
        self.resources["insight"] = self.resources.get("insight", 0.0) + 0.08
        self.share_event(creature, memory)

    def rest_in_nest(self, creature: Creature, obj: WorldObject) -> None:
        creature.needs.energy += 0.16
        creature.needs.comfort += 0.22
        creature.needs.fear -= 0.04
        creature.needs.happiness += 0.025
        creature.needs.clamp_all()
        if self.tick_count % 180 == 0:
            self.add_object_memory(creature, obj, "rested", "comfort", 0.52, f"{creature.name} slept well near the nest.")
            self.log(f"{creature.name} prefers sleeping near the nest.")
        creature.speech = self.voice_provider.generate_speech(creature, {"action": "rest_in_nest"})
        creature.speech_timer = 80 if creature.speech else creature.speech_timer

    def add_object_memory(
        self,
        creature: Creature,
        obj: WorldObject,
        outcome: str,
        emotion: str,
        importance: float,
        text: str,
    ) -> Memory:
        memory = Memory(
            id=f"mem_{self.rng.randrange(10000000):07d}",
            tick=self.tick_count,
            creature_id=creature.id,
            memory_type="object_interaction",
            subject_id=creature.id,
            object_id=obj.id,
            object_type=obj.object_type,
            object_traits=dict(obj.traits),
            outcome=outcome,
            emotion=emotion,
            importance=importance,
            confidence=0.58,
            source="personal",
            tags=[obj.object_type, emotion],
            short_text=text,
        )
        self.memory_store.add(memory)
        creature.add_memory(memory)
        return memory

    def train_with_dummy(self, creature: Creature, obj: WorldObject) -> None:
        if obj.object_type != "training_dummy":
            return
        modifiers = self.upgrade_modifiers()
        base_xp = obj.traits.get("combat_xp", 2.5)
        focus_bonus = creature.traits.get("patience", 0.5) * 0.8 + creature.traits.get("curiosity", 0.5) * 0.3
        leveled = creature.combat.gain_xp((base_xp + focus_bonus) * modifiers["training_xp_mult"])
        creature.needs.energy -= 1.2
        creature.needs.happiness += 0.4
        creature.needs.clamp_all()
        memory = Memory(
            id=random_id("mem"),
            tick=self.tick_count,
            creature_id=creature.id,
            memory_type="combat_training",
            subject_id=creature.id,
            object_id=obj.id,
            object_type=obj.object_type,
            object_traits=dict(obj.traits),
            outcome="trained",
            emotion="focus",
            importance=0.35 + creature.traits.get("memory_strength", 0.5) * 0.2,
            confidence=0.56,
            source="personal",
            tags=["combat", "training", obj.object_type],
            short_text=f"I trained with the dummy and felt stronger.",
        )
        self.memory_store.add(memory)
        creature.add_memory(memory)
        self.resources["insight"] = self.resources.get("insight", 0.0) + 0.05 * modifiers["combat_insight_mult"]
        if leveled:
            self.log(f"{creature.name} reached combat level {creature.combat.level}.")
        elif self.tick_count % 90 == 0:
            self.log(f"{creature.name} practiced on the training dummy.")

    def resolve_spar(self, first: Creature, second: Creature) -> None:
        if not first.alive or not second.alive or first.id == second.id:
            return
        item_mods = self.nearby_combat_item_modifiers((first.x + second.x) / 2, (first.y + second.y) / 2)
        upgrade_mods = self.upgrade_modifiers()
        first_score = self.combat_score(first, item_mods)
        second_score = self.combat_score(second, item_mods)
        winner, loser = (first, second) if first_score >= second_score else (second, first)
        margin = abs(first_score - second_score)
        xp_mult = upgrade_mods["spar_xp_mult"]
        winner_leveled = winner.combat.gain_xp((5.0 + margin * 0.18) * xp_mult)
        loser_leveled = loser.combat.gain_xp((2.8 + min(2.0, margin * 0.08)) * xp_mult)
        injury = clamp(1.0 + margin * 0.22 + item_mods["damage_bonus"] * 5.0, 0.8, 8.0)
        injury *= item_mods["injury_mult"] * upgrade_mods["injury_mult"]
        loser.needs.health = max(8.0, loser.needs.health - injury)
        loser.needs.fear += 3.0 + injury * loser.traits.get("pain_sensitivity", 0.5)
        winner.needs.happiness += 2.2
        winner.needs.energy -= 3.0
        loser.needs.energy -= 2.2
        loser.combat.injured_ticks = int(max(loser.combat.injured_ticks, injury * 35))
        winner.combat.wins += 1
        loser.combat.losses += 1
        winner.needs.clamp_all()
        loser.needs.clamp_all()

        winner_rel = winner.relationship_with(loser.id)
        loser_rel = loser.relationship_with(winner.id)
        rivalry_gain = 0.035 + item_mods["damage_bonus"] * 0.05
        trust_gain = item_mods["trust_bonus"]
        winner_rel.rivalry += rivalry_gain
        loser_rel.rivalry += rivalry_gain + loser.traits.get("stubbornness", 0.5) * 0.015
        winner_rel.trust += trust_gain
        loser_rel.trust += trust_gain * 0.8
        winner_rel.familiarity += 0.04
        loser_rel.familiarity += 0.04
        winner_rel.clamp_all()
        loser_rel.clamp_all()

        self.add_combat_memory(winner, loser, "won", "happy", 0.45 + margin * 0.02)
        self.add_combat_memory(loser, winner, "lost", "fear", 0.55 + injury * 0.04)
        self.resources["insight"] = self.resources.get("insight", 0.0) + (0.18 + margin * 0.01) * upgrade_mods["combat_insight_mult"]
        self.log(f"{winner.name} won a spar with {loser.name}.")
        if winner_leveled:
            self.log(f"{winner.name} reached combat level {winner.combat.level}.")
        if loser_leveled:
            self.log(f"{loser.name} learned from losing and reached combat level {loser.combat.level}.")
        self.social_observe_spar(winner, loser)

    def combat_score(self, creature: Creature, item_mods: dict[str, float]) -> float:
        return (
            creature.combat.level * 2.0
            + creature.combat.strength
            + creature.combat.guard * (1.0 + item_mods["guard_bonus"])
            + creature.combat.focus * (1.0 + item_mods["focus_bonus"])
            + creature.traits.get("aggression", 0.5) * 4.0
            + creature.traits.get("bravery", 0.5) * 3.0
            + creature.aggression_boost * 0.08
            - creature.needs.fear * 0.035
            - max(0, creature.combat.injured_ticks) * 0.006
            + self.rng.uniform(-1.4 - item_mods["luck"], 1.4 + item_mods["luck"])
        )

    def nearby_combat_item_modifiers(self, x: float, y: float) -> dict[str, float]:
        mods = {
            "damage_bonus": 0.0,
            "injury_mult": 1.0,
            "guard_bonus": 0.0,
            "focus_bonus": 0.0,
            "luck": 0.0,
            "trust_bonus": 0.0,
        }
        power = self.upgrade_modifiers()["item_power_mult"]
        for obj in self.objects:
            if not obj.traits.get("combat_item"):
                continue
            if distance((x, y), (obj.x, obj.y)) > 140:
                continue
            mods["damage_bonus"] += obj.traits.get("damage_bonus", 0.0) * power
            mods["injury_mult"] *= obj.traits.get("injury_mult", 1.0)
            mods["guard_bonus"] += obj.traits.get("guard_bonus", 0.0) * power
            mods["focus_bonus"] += obj.traits.get("focus_bonus", 0.0) * power
            mods["luck"] += obj.traits.get("luck", 0.0) * power
            mods["trust_bonus"] += obj.traits.get("trust_bonus", 0.0) * power
        return mods

    def add_combat_memory(
        self,
        creature: Creature,
        other: Creature,
        outcome: str,
        emotion: str,
        importance: float,
    ) -> Memory:
        memory = Memory(
            id=random_id("mem"),
            tick=self.tick_count,
            creature_id=creature.id,
            memory_type="combat",
            subject_id=other.id,
            object_id=other.id,
            object_type="sparring",
            object_traits={"color": "social", "combat": True},
            outcome=outcome,
            emotion=emotion,
            importance=clamp(importance, 0.1, 0.95),
            confidence=0.64,
            source="personal",
            tags=["combat", "spar", outcome],
            short_text=f"I {outcome} a spar with {other.name}.",
        )
        self.memory_store.add(memory)
        creature.add_memory(memory)
        return memory

    def social_observe_spar(self, winner: Creature, loser: Creature) -> None:
        for observer in self.creatures:
            if observer.id in {winner.id, loser.id} or not observer.alive:
                continue
            if distance((observer.x, observer.y), (winner.x, winner.y)) > SOCIAL_RANGE:
                continue
            learned = (0.4 + observer.traits.get("social_imitation", 0.5)) * 0.8
            if self.rng.random() < learned:
                observer.combat.gain_xp(0.8 + observer.traits.get("social_imitation", 0.5))
                observer.relationship_with(winner.id).familiarity += 0.02
                self.log(f"{observer.name} studied {winner.name}'s sparring style.")

    def share_event(self, actor: Creature, memory: Memory) -> None:
        observed = share_observed_event(actor, self.creatures, memory, self.tick_count, self.memory_store, SOCIAL_RANGE)
        for memory_copy in observed:
            observer = self.creature_by_id(memory_copy.creature_id)
            if observer:
                self.log(f"{observer.name} saw {actor.name} react to {memory.object_type}.")

    def warn_nearby(self, creature: Creature, obj: WorldObject) -> None:
        if creature.action_cooldown > 4:
            return
        warned_any = False
        for listener in self.perceived_creatures(creature, SOCIAL_RANGE):
            if self.rng.random() < 0.16 + creature.traits.get("friendliness", 0.5) * 0.36:
                warn_about_object(creature, listener, obj, self.tick_count, self.memory_store)
                listener.speech = self.voice_provider.generate_speech(listener, {"action": "avoid", "object_type": obj.object_type})
                listener.speech_timer = 90 if listener.speech else 0
                warned_any = True
                self.log(f"{creature.name} warned {listener.name} about {obj.label().lower()}.")
        if warned_any:
            creature.speech = self.voice_provider.generate_speech(creature, {"action": "warn", "object_type": obj.object_type})
            creature.speech_timer = 95 if creature.speech else 0

    def socialize(self, creature: Creature, other: Creature, play: bool) -> None:
        rel = creature.relationship_with(other.id)
        other_rel = other.relationship_with(creature.id)
        rel.familiarity += 0.015
        other_rel.familiarity += 0.015
        rel.attachment += 0.01 if play else 0.006
        other_rel.attachment += 0.01 if play else 0.006
        rel.trust += 0.008
        other_rel.trust += 0.008
        creature.needs.loneliness -= 0.08 if play else 0.04
        other.needs.loneliness -= 0.04
        creature.needs.happiness += 0.05 if play else 0.02
        rel.clamp_all()
        other_rel.clamp_all()
        creature.needs.clamp_all()
        other.needs.clamp_all()
        if play and self.tick_count % 210 == 0:
            self.log(f"{creature.name} and {other.name} played together.")

    def wander(self, creature: Creature, speed: float) -> None:
        if creature.wander_target is None or distance((creature.x, creature.y), creature.wander_target) < 8:
            creature.wander_target = (
                self.rng.uniform(30, WORLD_WIDTH - 30),
                self.rng.uniform(30, WORLD_HEIGHT - 30),
            )
        creature.x, creature.y = move_toward(
            creature.x,
            creature.y,
            creature.wander_target[0],
            creature.wander_target[1],
            speed * 0.55,
        )

    def update_social_proximity(self) -> None:
        for creature in self.creatures:
            if not creature.alive:
                continue
            for other in self.creatures:
                if creature.id == other.id or not other.alive:
                    continue
                if distance((creature.x, creature.y), (other.x, other.y)) <= 70:
                    rel = creature.relationship_with(other.id)
                    rel.familiarity += 0.0018
                    rel.attachment += 0.0007
                    rel.clamp_all()
                    creature.needs.loneliness -= 0.002
            creature.needs.clamp_all()

    def try_natural_breeding(self) -> None:
        adults = [creature for creature in self.creatures if creature.is_adult(ADULT_AGE) and creature.breed_cooldown <= 0]
        for index, first in enumerate(adults):
            for second in adults[index + 1 :]:
                if distance((first.x, first.y), (second.x, second.y)) > 55:
                    continue
                if first.needs.hunger > 55 or second.needs.hunger > 55:
                    continue
                if first.needs.energy < 45 or second.needs.energy < 45:
                    continue
                bond = first.relationship_with(second.id).attachment + second.relationship_with(first.id).attachment
                chance = 0.04 + bond * 0.2 + (first.traits.get("friendliness", 0.5) + second.traits.get("friendliness", 0.5)) * 0.03
                if self.rng.random() < chance:
                    self.breed(first, second)
                    return

    def force_breed(self) -> Creature | None:
        adults = [creature for creature in self.creatures if creature.is_adult(ADULT_AGE)]
        if len(adults) < 2:
            return None
        adults.sort(key=lambda creature: creature.x)
        return self.breed(adults[0], adults[1])

    def breed(self, parent_a: Creature, parent_b: Creature) -> Creature:
        traits = breed_traits(parent_a.traits, parent_b.traits, rng=self.rng)
        name = self.rng.choice([name for name in CREATURE_NAMES if name not in {c.name for c in self.creatures}] or CREATURE_NAMES)
        child = Creature.create(
            name=name,
            x=(parent_a.x + parent_b.x) / 2 + self.rng.uniform(-18, 18),
            y=(parent_a.y + parent_b.y) / 2 + self.rng.uniform(-18, 18),
            seed=self.rng.randrange(999999),
            traits=traits,
            generation=max(parent_a.generation, parent_b.generation) + 1,
            parents=[parent_a.id, parent_b.id],
            age=0,
        )
        child.needs.hunger = 48
        child.needs.energy = 82
        child.relationship_with(parent_a.id).kinship = 1.0
        child.relationship_with(parent_b.id).kinship = 1.0
        parent_a.relationship_with(child.id).kinship = 1.0
        parent_b.relationship_with(child.id).kinship = 1.0
        parent_a.relationship_with(parent_b.id).attachment += 0.12
        parent_b.relationship_with(parent_a.id).attachment += 0.12
        parent_a.breed_cooldown = 2200
        parent_b.breed_cooldown = 2200
        self.creatures.append(child)
        self.log(f"{child.name} was born from {parent_a.name} and {parent_b.name}.")
        return child

    def give_attention(self, creature: Creature) -> None:
        creature.needs.loneliness -= 12
        creature.needs.happiness += 7
        creature.needs.fear -= 3
        creature.needs.clamp_all()
        self.log(f"Player gave attention to {creature.name}.")

    def object_by_id(self, object_id: str | None) -> WorldObject | None:
        if object_id is None:
            return None
        return next((obj for obj in self.objects if obj.id == object_id), None)

    def creature_by_id(self, creature_id: str | None) -> Creature | None:
        if creature_id is None:
            return None
        return next((creature for creature in self.creatures if creature.id == creature_id), None)

    def creature_at(self, x: float, y: float) -> Creature | None:
        for creature in reversed(self.creatures):
            if creature.alive and distance((x, y), (creature.x, creature.y)) <= creature.body_size + 5:
                return creature
        return None

    def log(self, text: str) -> None:
        self.event_log.append(text)
        self.event_log = self.event_log[-12:]

    def to_dict(self) -> dict:
        return {
            "seed": self.seed,
            "tick_count": self.tick_count,
            "weather": self.weather,
            "creatures": [creature.to_dict() for creature in self.creatures],
            "objects": [obj.to_dict() for obj in self.objects],
            "event_log": self.event_log,
            "memory_store": self.memory_store.to_list(),
            "resources": self.resources,
            "upgrades": {key: value.to_dict() for key, value in self.upgrades.items()},
        }

    @classmethod
    def from_dict(cls, data: dict) -> "World":
        world = cls(seed=data.get("seed"), tick_count=data.get("tick_count", 0), weather=data.get("weather", "sunny"))
        world.creatures = [Creature.from_dict(item) for item in data.get("creatures", [])]
        world.objects = [WorldObject.from_dict(item) for item in data.get("objects", [])]
        world.event_log = list(data.get("event_log", []))[-12:]
        world.memory_store = MemoryStore.from_list(data.get("memory_store", []))
        world.resources = {"care": 100.0, "insight": 30.0}
        world.resources.update(data.get("resources", {}))
        saved_upgrades = data.get("upgrades", {})
        world.upgrades = default_upgrades()
        for upgrade_id, value in saved_upgrades.items():
            world.upgrades[upgrade_id] = UpgradeState.from_dict(value)
        return world
