from __future__ import annotations

from alife.memory import Memory, MemoryStore
from alife.objects import WorldObject
from alife.utils import clamp, distance, random_id


def share_observed_event(
    actor,
    observers,
    memory: Memory,
    tick: int,
    memory_store: MemoryStore,
    radius: float = 155.0,
) -> list[Memory]:
    observed: list[Memory] = []
    for observer in observers:
        if observer.id == actor.id or not observer.alive:
            continue
        if distance((actor.x, actor.y), (observer.x, observer.y)) > radius:
            continue
        relationship = observer.relationship_with(actor.id)
        social_factor = (
            0.28
            + observer.traits.get("social_imitation", 0.5) * 0.52
            + relationship.trust * 0.22
            + relationship.attachment * 0.12
        )
        copied = Memory(
            id=random_id("mem"),
            tick=tick,
            creature_id=observer.id,
            memory_type=memory.memory_type,
            subject_id=actor.id,
            object_id=memory.object_id,
            object_type=memory.object_type,
            object_traits=dict(memory.object_traits),
            outcome=memory.outcome,
            emotion=memory.emotion,
            importance=clamp(memory.importance * social_factor, 0.05, 1.0),
            confidence=clamp(memory.confidence * social_factor, 0.05, 1.0),
            source="observed",
            tags=list(memory.tags) + ["observed"],
            short_text=f"I saw {actor.name} near {memory.object_type}: {memory.outcome}.",
        )
        memory_store.add(copied)
        observer.add_memory(copied)
        relationship.familiarity += 0.08
        if memory.outcome in {"sick", "hurt", "scared"}:
            relationship.attachment += 0.025
        else:
            relationship.trust += 0.035
        relationship.clamp_all()
        observed.append(copied)
    return observed


def warn_about_object(
    warner,
    listener,
    world_object: WorldObject,
    tick: int,
    memory_store: MemoryStore,
) -> Memory:
    relationship = listener.relationship_with(warner.id)
    reliability = 0.22 + relationship.trust * 0.3 + warner.traits.get("language_ability", 0.5) * 0.22
    reliability += listener.traits.get("social_imitation", 0.5) * 0.2
    memory = Memory(
        id=random_id("mem"),
        tick=tick,
        creature_id=listener.id,
        memory_type="warning",
        subject_id=warner.id,
        object_id=world_object.id,
        object_type=world_object.object_type,
        object_traits=dict(world_object.traits),
        outcome="warning",
        emotion="fear",
        importance=clamp(reliability, 0.08, 0.85),
        confidence=clamp(reliability * 0.82, 0.05, 0.8),
        source="social",
        tags=["warning", world_object.object_type],
        short_text=f"{warner.name} warned me about {world_object.object_type}.",
    )
    memory_store.add(memory)
    listener.add_memory(memory)
    relationship.familiarity += 0.05
    relationship.trust += 0.03
    relationship.clamp_all()
    return memory
