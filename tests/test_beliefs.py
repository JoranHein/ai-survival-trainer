from alife.beliefs import BeliefBook
from alife.memory import Memory


def make_memory(outcome: str, source: str = "personal", importance: float = 0.8) -> Memory:
    return Memory(
        id=f"{outcome}-{source}",
        tick=1,
        creature_id="c1",
        memory_type="food_outcome",
        subject_id="c1",
        object_id="obj",
        object_type="blue_fruit",
        object_traits={"color": "blue", "edible": True},
        outcome=outcome,
        emotion="fear" if outcome == "sick" else "happy",
        importance=importance,
        confidence=0.8,
        source=source,
        tags=["food"],
        short_text=outcome,
    )


def test_bad_experience_creates_negative_belief_and_blue_generalization():
    book = BeliefBook()

    book.update_from_memory(make_memory("sick"))

    assert book.about("object_type", "blue_fruit").valence < -0.3
    assert book.about("tag", "blue").valence < 0.0


def test_repeated_safe_experience_can_reduce_fear():
    book = BeliefBook()
    book.update_from_memory(make_memory("sick", importance=0.9))
    initial = book.about("object_type", "blue_fruit").valence

    for _ in range(4):
        book.update_from_memory(make_memory("good", importance=0.7))

    assert book.about("object_type", "blue_fruit").valence > initial


def test_observed_memories_are_weaker_than_personal_memories():
    personal = BeliefBook()
    observed = BeliefBook()

    personal.update_from_memory(make_memory("sick", source="personal", importance=0.8))
    observed.update_from_memory(make_memory("sick", source="observed", importance=0.8))

    assert abs(personal.about("object_type", "blue_fruit").valence) > abs(
        observed.about("object_type", "blue_fruit").valence
    )
