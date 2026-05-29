from alife.creature import Creature, Needs
from alife.decision import DecisionEngine
from alife.objects import WorldObject
from alife.world import World


def test_hungry_creature_seeks_food():
    world = World(seed=1)
    creature = Creature.create(name="Nimi", x=100, y=100, seed=2)
    creature.needs = Needs(hunger=88, energy=80, health=90, happiness=50, fear=5, loneliness=20, comfort=50)
    food = WorldObject.create("red_fruit", 130, 100)
    world.creatures = [creature]
    world.objects = [food]

    decision = DecisionEngine(seed=3).choose_action(creature, world)

    assert decision.action in {"seek_food", "eat"}
    assert decision.target_id == food.id


def test_strong_negative_belief_can_make_creature_avoid_food():
    world = World(seed=1)
    creature = Creature.create(name="Nimi", x=100, y=100, seed=2)
    creature.traits["bravery"] = 0.1
    creature.traits["risk_tolerance"] = 0.1
    creature.needs = Needs(hunger=60, energy=80, health=90, happiness=40, fear=45, loneliness=20, comfort=50)
    creature.beliefs.set_belief("object_type", "blue_fruit", valence=-0.95, confidence=0.95, reason="got sick")
    food = WorldObject.create("blue_fruit", 125, 100)
    world.creatures = [creature]
    world.objects = [food]

    decision = DecisionEngine(seed=4).choose_action(creature, world)

    assert decision.action == "avoid"
    assert decision.target_id == food.id


def test_bravery_and_risk_tolerance_can_change_food_decision():
    world = World(seed=1)
    cautious = Creature.create(name="Nimi", x=100, y=100, seed=2)
    bold = Creature.create(name="Lumo", x=100, y=100, seed=3)
    for creature in (cautious, bold):
        creature.needs = Needs(hunger=64, energy=80, health=90, happiness=40, fear=25, loneliness=20, comfort=50)
        creature.beliefs.set_belief("object_type", "blue_fruit", valence=-0.5, confidence=0.7, reason="warning")
    cautious.traits["bravery"] = 0.1
    cautious.traits["risk_tolerance"] = 0.1
    bold.traits["bravery"] = 0.95
    bold.traits["risk_tolerance"] = 0.95
    food = WorldObject.create("blue_fruit", 125, 100)
    world.objects = [food]

    engine = DecisionEngine(seed=5)
    cautious_decision = engine.choose_action(cautious, world)
    bold_decision = engine.choose_action(bold, world)

    assert cautious_decision.action == "avoid"
    assert bold_decision.action in {"seek_food", "eat", "investigate_object"}
