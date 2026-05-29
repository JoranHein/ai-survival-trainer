from alife.beliefs import BeliefBook
from alife.memory import Memory, MemoryStore


def test_bad_personal_food_outcome_creates_negative_memory():
    store = MemoryStore()

    memory = store.record_food_outcome(
        tick=4,
        creature_id="c1",
        object_id="obj-blue",
        object_type="blue_fruit",
        object_traits={"color": "blue", "edible": True},
        outcome="sick",
        source="personal",
    )

    assert memory.memory_type == "food_outcome"
    assert memory.outcome == "sick"
    assert memory.emotion == "fear"
    assert memory.importance > 0.7
    assert "blue_fruit" in memory.short_text


def test_memory_importance_affects_belief_strength():
    weak = Memory(
        id="weak",
        tick=1,
        creature_id="c1",
        memory_type="food_outcome",
        subject_id="c1",
        object_id="a",
        object_type="blue_fruit",
        object_traits={"color": "blue"},
        outcome="sick",
        emotion="fear",
        importance=0.2,
        confidence=0.5,
        source="personal",
        tags=["food", "bad"],
        short_text="weak bad blue fruit",
    )
    strong = Memory(
        id="strong",
        tick=2,
        creature_id="c1",
        memory_type="food_outcome",
        subject_id="c1",
        object_id="b",
        object_type="blue_fruit",
        object_traits={"color": "blue"},
        outcome="sick",
        emotion="fear",
        importance=0.9,
        confidence=0.9,
        source="personal",
        tags=["food", "bad"],
        short_text="strong bad blue fruit",
    )

    weak_book = BeliefBook()
    strong_book = BeliefBook()
    weak_book.update_from_memory(weak)
    strong_book.update_from_memory(strong)

    assert abs(strong_book.about("object_type", "blue_fruit").valence) > abs(
        weak_book.about("object_type", "blue_fruit").valence
    )
