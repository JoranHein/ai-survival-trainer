from alife.creature import Creature
from alife.objects import WorldObject
from alife.world import World


def test_happy_creatures_generate_idle_care_and_insight_from_memories():
    world = World(seed=12)
    creature = Creature.create(name="Nimi", x=100, y=100, seed=1)
    creature.needs.happiness = 90
    creature.needs.health = 95
    world.creatures = [creature]
    starting_care = world.resources["care"]

    for _ in range(120):
        world.update()

    assert world.resources["care"] > starting_care
    assert "insight" in world.resources


def test_upgrade_purchase_spends_resources_and_changes_world_modifiers():
    world = World(seed=12)
    world.resources["care"] = 200
    before = world.upgrade_modifiers()["training_xp_mult"]

    purchased = world.purchase_upgrade("training_corner")

    assert purchased is True
    assert world.upgrades["training_corner"].level == 1
    assert world.resources["care"] < 200
    assert world.upgrade_modifiers()["training_xp_mult"] > before


def test_upgrade_can_be_purchased_by_shop_slot_without_function_keys():
    world = World(seed=12)
    world.resources["care"] = 200
    world.resources["insight"] = 100

    purchased = world.purchase_upgrade_slot(1)

    assert purchased is True
    assert world.upgrades["auto_feeder"].level == 1


def test_creatures_move_noticeably_during_idle_simulation():
    world = World.new_game(seed=12)
    start_positions = [(creature.x, creature.y) for creature in world.creatures]

    for _ in range(90):
        world.update()

    moved_distances = [
        ((creature.x - start_x) ** 2 + (creature.y - start_y) ** 2) ** 0.5
        for creature, (start_x, start_y) in zip(world.creatures, start_positions)
    ]
    assert max(moved_distances) > 35


def test_training_dummy_grants_combat_xp_without_rivalry():
    world = World(seed=12)
    creature = Creature.create(name="Nimi", x=100, y=100, seed=1)
    dummy = WorldObject.create("training_dummy", 105, 100)
    world.creatures = [creature]
    world.objects = [dummy]

    before_xp = creature.combat.xp
    world.train_with_dummy(creature, dummy)

    assert creature.combat.xp > before_xp
    assert creature.combat.level >= 1
    assert creature.strongest_memory("training_dummy") is not None


def test_sparring_awards_xp_and_can_create_combat_memory():
    world = World(seed=5)
    first = Creature.create(name="Nimi", x=100, y=100, seed=1)
    second = Creature.create(name="Lumo", x=108, y=100, seed=2)
    first.traits["aggression"] = 0.9
    second.traits["bravery"] = 0.2
    world.creatures = [first, second]

    world.resolve_spar(first, second)

    assert first.combat.xp > 0
    assert second.combat.xp > 0
    assert any(memory.memory_type == "combat" for memory in first.memories + second.memories)
