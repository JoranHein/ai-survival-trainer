from __future__ import annotations

import math
import random
import uuid
from typing import Iterable, Sequence, TypeVar


T = TypeVar("T")


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def random_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


def move_toward(
    x: float,
    y: float,
    target_x: float,
    target_y: float,
    speed: float,
) -> tuple[float, float]:
    dx = target_x - x
    dy = target_y - y
    length = math.hypot(dx, dy)
    if length <= speed or length == 0:
        return target_x, target_y
    return x + dx / length * speed, y + dy / length * speed


def move_away(
    x: float,
    y: float,
    source_x: float,
    source_y: float,
    speed: float,
    bounds: tuple[int, int],
) -> tuple[float, float]:
    dx = x - source_x
    dy = y - source_y
    length = math.hypot(dx, dy) or 1.0
    nx = clamp(x + dx / length * speed, 12, bounds[0] - 12)
    ny = clamp(y + dy / length * speed, 12, bounds[1] - 12)
    return nx, ny


def choose(seq: Sequence[T], rng: random.Random) -> T:
    return seq[rng.randrange(len(seq))]


def nearest(items: Iterable[T], point: tuple[float, float], get_pos) -> T | None:
    best_item = None
    best_distance = float("inf")
    for item in items:
        item_distance = distance(point, get_pos(item))
        if item_distance < best_distance:
            best_item = item
            best_distance = item_distance
    return best_item
