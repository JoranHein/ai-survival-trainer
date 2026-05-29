from alife.creature import Creature
from alife.memory import MemoryStore
from alife.objects import WorldObject
from alife.social import share_observed_event


def test_observing_creature_get_sick_creates_observed_memory():
    actor = Creature.create(name="Nimi", x=100, y=100, seed=1)
    observer = Creature.create(name="Lumo", x=120, y=100, seed=2)
    food = WorldObject.create("blue_fruit", 105, 100)
    store = MemoryStore()

    personal = store.record_food_outcome(
        tick=10,
        creature_id=actor.id,
        object_id=food.id,
        object_type=food.object_type,
        object_traits=food.traits,
        outcome="sick",
        source="personal",
    )

    observed = share_observed_event(actor, [observer], personal, tick=10, memory_store=store)

    assert len(observed) == 1
    assert observed[0].source == "observed"
    assert observed[0].creature_id == observer.id
    assert observer.beliefs.about("object_type", "blue_fruit").valence < 0.0


def test_high_social_imitation_increases_observed_belief_update():
    actor = Creature.create(name="Nimi", x=100, y=100, seed=1)
    low = Creature.create(name="Tavi", x=115, y=100, seed=2)
    high = Creature.create(name="Lumo", x=118, y=100, seed=3)
    low.traits["social_imitation"] = 0.0
    high.traits["social_imitation"] = 1.0
    food = WorldObject.create("blue_fruit", 105, 100)
    store = MemoryStore()
    personal = store.record_food_outcome(
        tick=10,
        creature_id=actor.id,
        object_id=food.id,
        object_type=food.object_type,
        object_traits=food.traits,
        outcome="sick",
        source="personal",
    )

    share_observed_event(actor, [low, high], personal, tick=10, memory_store=store)

    low_belief = low.beliefs.about("object_type", "blue_fruit")
    high_belief = high.beliefs.about("object_type", "blue_fruit")
    assert abs(high_belief.valence) > abs(low_belief.valence)
