from __future__ import annotations

import pygame

from config import HUD_WIDTH, ITEM_TYPES, SCREEN_HEIGHT, SCREEN_WIDTH, WORLD_HEIGHT
from alife.upgrades import UPGRADE_DEFINITIONS


PANEL_BG = (32, 34, 38)
PANEL_TEXT = (235, 236, 228)
MUTED = (165, 170, 168)
LINE = (72, 76, 80)


def draw_hud(
    surface: pygame.Surface,
    font: pygame.font.Font,
    small_font: pygame.font.Font,
    world,
    selected,
    selected_item: str,
    paused: bool,
    show_help: bool,
    show_shop: bool,
) -> None:
    panel = pygame.Rect(SCREEN_WIDTH - HUD_WIDTH, 0, HUD_WIDTH, SCREEN_HEIGHT)
    pygame.draw.rect(surface, PANEL_BG, panel)
    pygame.draw.line(surface, LINE, (SCREEN_WIDTH - HUD_WIDTH, 0), (SCREEN_WIDTH - HUD_WIDTH, SCREEN_HEIGHT), 2)

    x = SCREEN_WIDTH - HUD_WIDTH + 16
    y = 14
    y = draw_line(surface, font, "Emergence Pet Lab", x, y, PANEL_TEXT)
    y = draw_line(surface, small_font, f"Tick {world.tick_count}  Weather: {world.weather}", x, y + 4, MUTED)
    y = draw_line(surface, small_font, f"Place: {item_label(selected_item)}", x, y + 8, (245, 220, 130))
    y = draw_line(
        surface,
        small_font,
        f"Care {world.resources.get('care', 0):.0f}  Insight {world.resources.get('insight', 0):.0f}",
        x,
        y + 2,
        (140, 220, 185),
    )
    y = draw_line(surface, small_font, "Paused" if paused else "Running", x, y + 2, (240, 170, 110) if paused else (130, 220, 150))

    y += 12
    if show_shop:
        y = draw_shop(surface, font, small_font, world, x, y)
    elif selected:
        y = draw_creature_panel(surface, font, small_font, selected, x, y)
    else:
        y = draw_wrapped(surface, small_font, "Click a creature to inspect its needs, beliefs, memories, and decision explanation.", x, y, HUD_WIDTH - 28, MUTED)

    if show_help:
        draw_help(surface, small_font)


def draw_creature_panel(
    surface: pygame.Surface,
    font: pygame.font.Font,
    small_font: pygame.font.Font,
    creature,
    x: int,
    y: int,
) -> int:
    y = draw_line(surface, font, f"{creature.name}  Gen {creature.generation}", x, y, PANEL_TEXT)
    y = draw_line(surface, small_font, f"Action: {creature.current_action}", x, y + 4, (245, 220, 130))
    y = draw_line(surface, small_font, f"Age {creature.age}  Health {creature.needs.health:.0f}", x, y + 2, MUTED)
    y = draw_line(
        surface,
        small_font,
        f"Combat L{creature.combat.level} XP {creature.combat.xp:.1f}/{creature.combat.next_level_xp():.0f}",
        x,
        y + 2,
        (230, 180, 120),
    )
    y = draw_line(
        surface,
        small_font,
        f"Str {creature.combat.strength:.1f} Guard {creature.combat.guard:.1f} Focus {creature.combat.focus:.1f}",
        x,
        y + 2,
        MUTED,
    )

    need_names = ["hunger", "energy", "happiness", "fear", "loneliness", "comfort"]
    for name in need_names:
        value = getattr(creature.needs, name)
        y = draw_bar(surface, small_font, name, value, x, y + 4)

    y += 8
    y = draw_line(surface, small_font, "Top action scores", x, y, PANEL_TEXT)
    for score in creature.decision_debug.get("top_scores", [])[:3]:
        y = draw_line(surface, small_font, f"{score['action']}: {score['score']}", x + 8, y + 2, MUTED)

    y += 6
    y = draw_wrapped(
        surface,
        small_font,
        creature.decision_debug.get("explanation", "No decision yet."),
        x,
        y,
        HUD_WIDTH - 28,
        (218, 222, 210),
    )
    y += 6
    y = draw_wrapped(
        surface,
        small_font,
        "Memory: " + creature.decision_debug.get("strongest_memory", "none"),
        x,
        y,
        HUD_WIDTH - 28,
        MUTED,
    )
    y = draw_wrapped(
        surface,
        small_font,
        "Belief: " + creature.decision_debug.get("strongest_belief", "none"),
        x,
        y + 2,
        HUD_WIDTH - 28,
        MUTED,
    )

    y += 8
    trait_text = ", ".join(
        f"{name[:4]} {creature.traits[name]:.2f}"
        for name in ("curiosity", "bravery", "friendliness", "social_imitation", "blue_fruit_tolerance")
    )
    return draw_wrapped(surface, small_font, "Traits: " + trait_text, x, y, HUD_WIDTH - 28, MUTED)


def draw_shop(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world, x: int, y: int) -> int:
    y = draw_line(surface, font, "Upgrade Shop", x, y, PANEL_TEXT)
    y = draw_line(surface, small_font, "Press 1-6 to buy. U closes shop.", x, y + 2, MUTED)
    for index, (upgrade_id, definition) in enumerate(UPGRADE_DEFINITIONS.items(), start=1):
        state = world.upgrades[upgrade_id]
        cost = scaled_cost(definition["cost"], state.level)
        max_level = definition["max_level"]
        key = str(index)
        affordable = all(world.resources.get(name, 0.0) >= amount for name, amount in cost.items())
        color = (148, 224, 166) if affordable and state.level < max_level else MUTED
        cost_text = " ".join(f"{name[0].upper()}{amount:.0f}" for name, amount in cost.items() if amount > 0)
        if state.level >= max_level:
            cost_text = "max"
        y = draw_line(surface, small_font, f"{key} {definition['name']} L{state.level}: {cost_text}", x, y + 5, color)
        y = draw_wrapped(surface, small_font, definition["description"], x + 8, y, HUD_WIDTH - 38, MUTED)
    return y


def scaled_cost(cost: dict[str, float], current_level: int) -> dict[str, float]:
    scale = 1.0 + current_level * 0.65
    return {name: amount * scale for name, amount in cost.items()}


def draw_bar(surface: pygame.Surface, font: pygame.font.Font, label: str, value: float, x: int, y: int) -> int:
    text = font.render(f"{label[:10]:<10}", True, MUTED)
    surface.blit(text, (x, y))
    bar_x = x + 82
    bar = pygame.Rect(bar_x, y + 3, 150, 9)
    pygame.draw.rect(surface, (58, 62, 66), bar, border_radius=2)
    fill = pygame.Rect(bar_x, y + 3, int(150 * max(0.0, min(100.0, value)) / 100.0), 9)
    color = (95, 190, 120)
    if label in {"hunger", "fear", "loneliness"}:
        color = (220, 130, 85) if value > 55 else (160, 190, 115)
    pygame.draw.rect(surface, color, fill, border_radius=2)
    value_text = font.render(f"{value:.0f}", True, PANEL_TEXT)
    surface.blit(value_text, (bar_x + 156, y - 1))
    return y + 16


def draw_help(surface: pygame.Surface, small_font: pygame.font.Font) -> None:
    box = pygame.Rect(12, SCREEN_HEIGHT - 98, SCREEN_WIDTH - HUD_WIDTH - 24, 86)
    pygame.draw.rect(surface, (28, 30, 34), box, border_radius=6)
    pygame.draw.rect(surface, (80, 84, 88), box, 1, border_radius=6)
    lines = [
        "1-9 choose item | Tab cycles all items | Left click place or inspect | Space pause",
        "U shop | 1-6 buy upgrades while shop is open | R reset | S save | L load | H help",
        "Items include foods, comfort objects, training dummy, combat charms, drum, and pebble.",
    ]
    y = box.y + 10
    for line in lines:
        y = draw_line(surface, small_font, line, box.x + 12, y, (230, 232, 224))


def draw_line(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int, color) -> int:
    rendered = font.render(text, True, color)
    surface.blit(rendered, (x, y))
    return y + rendered.get_height() + 2


def draw_wrapped(
    surface: pygame.Surface,
    font: pygame.font.Font,
    text: str,
    x: int,
    y: int,
    width: int,
    color,
) -> int:
    words = text.split()
    line = ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if font.size(candidate)[0] <= width:
            line = candidate
        else:
            if line:
                y = draw_line(surface, font, line, x, y, color)
            line = word
    if line:
        y = draw_line(surface, font, line, x, y, color)
    return y


def item_label(item_type: str) -> str:
    index = ITEM_TYPES.index(item_type) + 1 if item_type in ITEM_TYPES else 0
    return f"{index}. {item_type.replace('_', ' ')}"
