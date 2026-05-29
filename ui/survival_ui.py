from __future__ import annotations

import math

import pygame

from alife.survival import UPGRADES
from config import SCREEN_HEIGHT, SCREEN_WIDTH


WORLD_W = SCREEN_WIDTH - 340
PANEL_X = WORLD_W


def draw_survival_game(
    surface: pygame.Surface,
    font: pygame.font.Font,
    small_font: pygame.font.Font,
    world,
    show_shop: bool,
    editing_sign: bool,
    sign_buffer: str,
    show_help: bool,
    paused: bool,
) -> None:
    draw_arena(surface, font, small_font, world)
    draw_panel(surface, font, small_font, world, show_shop, editing_sign, sign_buffer, paused)
    if show_help:
        draw_help(surface, small_font)


def draw_arena(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    is_night = world.phase == "night"
    bg = (34, 42, 54) if is_night else (213, 219, 185)
    surface.fill(bg)
    pygame.draw.rect(surface, (26, 29, 33), pygame.Rect(WORLD_W, 0, SCREEN_WIDTH - WORLD_W, SCREEN_HEIGHT))
    pygame.draw.line(surface, (70, 74, 78), (WORLD_W, 0), (WORLD_W, SCREEN_HEIGHT), 2)

    for x in range(0, WORLD_W, 48):
        pygame.draw.line(surface, (190, 196, 170) if not is_night else (48, 56, 70), (x, 0), (x, SCREEN_HEIGHT), 1)
    for y in range(0, SCREEN_HEIGHT, 48):
        pygame.draw.line(surface, (190, 196, 170) if not is_night else (48, 56, 70), (0, y), (WORLD_W, y), 1)

    draw_tree(surface, font, small_font, world)
    draw_dummy(surface, font, world)
    draw_reading_stone(surface, font, small_font, world)
    draw_bed(surface, font, small_font, world)
    draw_sign(surface, font, small_font, world)
    draw_survivor(surface, font, small_font, world)
    for enemy in world.enemies:
        draw_enemy(surface, small_font, enemy)

    phase_text = f"{world.phase.upper()}  Day {world.day}  Wave {world.wave}"
    rendered = font.render(phase_text, True, (245, 238, 190) if is_night else (48, 50, 42))
    surface.blit(rendered, (14, 12))


def draw_tree(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    tree = world.fruit_tree
    x, y = int(tree.x), int(tree.y)
    pygame.draw.rect(surface, (92, 62, 35), pygame.Rect(x - 9, y, 18, 48))
    pygame.draw.circle(surface, (58, 132, 70), (x, y - 8), 38)
    fruit_color = (226, 65, 58) if tree.ready() else (120, 88, 76)
    pygame.draw.circle(surface, fruit_color, (x + 16, y - 16), 7)
    label = "Fruit ready" if tree.ready() else f"Fruit {math.ceil(tree.remaining_ticks / world.ticks_per_second)}s"
    draw_centered(surface, small_font, label, x, y + 55, (34, 38, 30))


def draw_dummy(surface: pygame.Surface, font: pygame.font.Font, world) -> None:
    x, y = int(world.dummy.x), int(world.dummy.y)
    pygame.draw.circle(surface, (100, 82, 62), (x, y - 34), 15)
    pygame.draw.rect(surface, (140, 120, 92), pygame.Rect(x - 13, y - 22, 26, 58), border_radius=4)
    pygame.draw.line(surface, (78, 60, 42), (x - 30, y), (x + 30, y), 5)
    draw_centered(surface, font, "Training Dummy", x, y + 45, (42, 40, 34))


def draw_reading_stone(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    x, y = int(world.reading_stone.x), int(world.reading_stone.y)
    pygame.draw.polygon(surface, (112, 108, 132), [(x, y - 28), (x + 34, y - 4), (x + 20, y + 30), (x - 26, y + 28), (x - 36, y - 4)])
    pygame.draw.rect(surface, (232, 224, 185), pygame.Rect(x - 18, y - 16, 36, 24), border_radius=2)
    pygame.draw.line(surface, (80, 72, 55), (x, y - 16), (x, y + 8), 1)
    draw_centered(surface, font, "Reading Stone", x, y + 38, (42, 40, 34))
    draw_centered(surface, small_font, world.reading_stone.book_title, x, y + 57, (62, 58, 48))


def draw_bed(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    x, y = int(world.bed.x), int(world.bed.y)
    pygame.draw.rect(surface, (112, 82, 72), pygame.Rect(x - 44, y - 22, 88, 48), border_radius=5)
    pygame.draw.rect(surface, (220, 218, 190), pygame.Rect(x - 36, y - 16, 72, 34), border_radius=4)
    pygame.draw.rect(surface, (132, 170, 205), pygame.Rect(x - 36, y - 2, 72, 20), border_radius=3)
    pygame.draw.rect(surface, (245, 238, 212), pygame.Rect(x - 34, y - 14, 24, 14), border_radius=3)
    draw_centered(surface, font, "Bed", x, y + 36, (42, 40, 34))
    draw_centered(surface, small_font, "rest", x, y + 54, (62, 58, 48))


def draw_sign(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    x, y = int(world.sign.x), int(world.sign.y)
    rect = pygame.Rect(x - 72, y - 32, 144, 64)
    pygame.draw.rect(surface, (218, 194, 128), rect, border_radius=4)
    pygame.draw.rect(surface, (82, 62, 38), rect, 2, border_radius=4)
    pygame.draw.line(surface, (82, 62, 38), (x, y + 32), (x, y + 82), 5)
    draw_centered(surface, font, "Sign", x, y - 24, (38, 34, 28))
    lines = wrap_text(world.sign.text, small_font, 128)[:2]
    text_y = y - 4
    for line in lines:
        draw_centered(surface, small_font, line, x, text_y, (42, 34, 25))
        text_y += 15


def draw_survivor(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world) -> None:
    survivor = world.survivor
    x, y = int(survivor.x), int(survivor.y)
    pygame.draw.circle(surface, (96, 160, 220), (x, y), 19)
    pygame.draw.circle(surface, (25, 28, 32), (x - 7, y - 5), 3)
    pygame.draw.circle(surface, (25, 28, 32), (x + 7, y - 5), 3)
    pygame.draw.line(surface, (30, 30, 34), (x - 7, y + 7), (x + 7, y + 7), 2)
    if survivor.current_weapon == "bow":
        pygame.draw.arc(surface, (90, 58, 35), pygame.Rect(x + 17, y - 22, 20, 44), -1.3, 1.3, 3)
        pygame.draw.line(surface, (238, 230, 190), (x + 29, y - 19), (x + 29, y + 19), 1)
    else:
        pygame.draw.line(surface, (190, 195, 205), (x + 18, y - 18), (x + 36, y - 36), 4)
    draw_centered(surface, font, survivor.name, x, y - 42, (38, 38, 34))
    draw_centered(surface, small_font, survivor.current_action, x, y + 26, (42, 42, 38))
    if survivor.thoughts:
        draw_thought_stack(surface, small_font, survivor.thoughts, x, y - 70)


def draw_enemy(surface: pygame.Surface, small_font: pygame.font.Font, enemy) -> None:
    x, y = int(enemy.x), int(enemy.y)
    pygame.draw.circle(surface, (154, 52, 58), (x, y), 15)
    pygame.draw.circle(surface, (35, 20, 20), (x - 5, y - 4), 3)
    pygame.draw.circle(surface, (35, 20, 20), (x + 5, y - 4), 3)
    draw_centered(surface, small_font, f"HP {enemy.hp:.0f}", x, y + 20, (235, 210, 210))


def draw_panel(
    surface: pygame.Surface,
    font: pygame.font.Font,
    small_font: pygame.font.Font,
    world,
    show_shop: bool,
    editing_sign: bool,
    sign_buffer: str,
    paused: bool,
) -> None:
    x = PANEL_X + 16
    y = 14
    survivor = world.survivor
    y = draw_line(surface, font, "Idle Survival Trainer", x, y, (238, 238, 228))
    y = draw_line(surface, small_font, f"{'Paused' if paused else 'Running'} | {world.phase} | {phase_seconds_left(world)}s left", x, y + 3, (174, 180, 176))
    y = draw_line(surface, small_font, f"Time Points: {world.time_points:.1f} (+{world.points_per_second():.2f}/s)", x, y + 6, (135, 224, 170))
    y = draw_line(surface, small_font, f"Day {world.day}  Wave {world.wave}", x, y + 2, (230, 205, 125))

    y += 10
    y = draw_bar(surface, small_font, "HP", survivor.hp, survivor.max_hp(world.permanent), x, y, (100, 210, 130))
    y = draw_bar(surface, small_font, "Hunger", survivor.hunger, 100, x, y, (220, 140, 90))
    y = draw_bar(surface, small_font, "Rest", survivor.energy, 100, x, y, (110, 175, 225))
    y = draw_bar(surface, small_font, "Fear", survivor.fear, 100, x, y, (205, 110, 170))

    y += 8
    y = draw_line(surface, small_font, f"Action: {survivor.current_action}", x, y, (235, 235, 225))
    y = draw_line(surface, small_font, f"Weapon: {survivor.current_weapon}", x, y + 2, (235, 210, 140))
    if world.last_brain_thought:
        y = draw_wrapped(surface, small_font, "Brain: " + world.last_brain_thought, x, y + 2, 295, (190, 210, 245))
    y = draw_line(surface, small_font, f"Literacy {survivor.learned.literacy:.1f}  Words {len(survivor.vocabulary)}", x, y + 6, (210, 190, 245))
    y = draw_wrapped(surface, small_font, "Vocab: " + ", ".join(survivor.vocabulary[:10]), x, y + 2, 295, (174, 180, 176))
    if survivor.last_interpretation:
        y = draw_wrapped(surface, small_font, "Sign read as: " + survivor.last_interpretation, x, y + 2, 295, (230, 210, 150))
    if survivor.pending_sign_words:
        y = draw_wrapped(surface, small_font, "Learning words: " + ", ".join(survivor.pending_sign_words[:6]), x, y + 2, 295, (245, 190, 150))
    if survivor.researching_word:
        needed = world.word_research_ticks_required(survivor.researching_word)
        y = draw_line(surface, small_font, f"Research {survivor.researching_word}: {survivor.research_ticks}/{needed}", x, y + 2, (245, 190, 150))
    learned = survivor.learned
    y = draw_line(surface, small_font, f"Learned atk {learned.attack:.1f} def {learned.defense:.1f} str {learned.strength:.1f}", x, y + 6, (174, 180, 176))
    y = draw_line(surface, small_font, f"Learned hp {learned.hitpoints:.1f} bow {learned.bow:.1f} sword {learned.sword:.1f}", x, y + 2, (174, 180, 176))
    perm = world.permanent
    y = draw_line(surface, small_font, f"Permanent hp {perm.hitpoints:.0f} atk {perm.attack:.0f} def {perm.defense:.0f}", x, y + 6, (150, 215, 185))
    y = draw_line(surface, small_font, f"Permanent bow {perm.bow:.0f} str {perm.strength:.0f} train {perm.training_speed:.0f}", x, y + 2, (150, 215, 185))
    y = draw_line(surface, small_font, f"Word research {perm.word_learning_speed:.0f}  Forever words {len(perm.permanent_words)}", x, y + 2, (150, 215, 185))
    y = draw_wrapped(
        surface,
        small_font,
        f"Born traits: aggression {survivor.aggression:.2f}, curiosity {survivor.curiosity:.2f}, charisma {survivor.charisma:.2f}, perseverance {survivor.perseverance:.2f}",
        x,
        y + 6,
        295,
        (174, 180, 176),
    )

    y += 10
    if editing_sign:
        y = draw_line(surface, font, "Writing Sign", x, y, (238, 238, 228))
        y = draw_wrapped(surface, small_font, sign_buffer + "|", x, y + 4, 295, (245, 225, 150))
        y = draw_wrapped(surface, small_font, "Enter writes it. Esc cancels. Unknown words become book research before the order starts.", x, y + 6, 295, (174, 180, 176))
    elif show_shop:
        draw_shop(surface, font, small_font, world, x, y)
    else:
        y = draw_line(surface, font, "Sign", x, y, (238, 238, 228))
        y = draw_wrapped(surface, small_font, world.sign.text, x, y + 4, 295, (245, 225, 150))
        y = draw_wrapped(surface, small_font, "Press T to write Ari's direct order. Ari researches unknown words, then follows it.", x, y + 6, 295, (174, 180, 176))


def draw_shop(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world, x: int, y: int) -> int:
    y = draw_line(surface, font, "Permanent Upgrades", x, y, (238, 238, 228))
    y = draw_line(surface, small_font, "Press 1-9 to buy. W remembers a word forever.", x, y + 2, (174, 180, 176))
    for index, (upgrade_id, definition) in enumerate(UPGRADES.items(), start=1):
        cost = world.upgrade_cost(upgrade_id)
        affordable = world.time_points >= cost
        color = (145, 225, 165) if affordable else (155, 160, 158)
        field = definition["field"]
        level = getattr(world.permanent, field)
        y = draw_line(surface, small_font, f"{index}. {definition['name']} L{level:.0f} - {cost:.0f} pts", x, y + 5, color)
    word = world.next_permanent_word_candidate()
    if word:
        cost = world.permanent_word_cost(word)
        affordable = world.time_points >= cost
        color = (145, 225, 165) if affordable else (155, 160, 158)
        y = draw_line(surface, small_font, f"W. Remember '{word}' forever - {cost:.0f} pts", x, y + 8, color)
    return y


def draw_help(surface: pygame.Surface, small_font: pygame.font.Font) -> None:
    box = pygame.Rect(14, SCREEN_HEIGHT - 96, WORLD_W - 28, 82)
    pygame.draw.rect(surface, (25, 28, 32), box, border_radius=6)
    pygame.draw.rect(surface, (80, 84, 88), box, 1, border_radius=6)
    lines = [
        "U upgrades | 1-9 buy | W remember word | T write sign | S save | L load",
        "There is no player avatar. Ari must walk to stations before using them.",
        "Unknown sign words are researched at the book before Ari follows the order.",
    ]
    y = box.y + 10
    for line in lines:
        y = draw_line(surface, small_font, line, box.x + 12, y, (232, 234, 224))


def draw_bar(surface: pygame.Surface, font: pygame.font.Font, label: str, value: float, maximum: float, x: int, y: int, color) -> int:
    surface.blit(font.render(label, True, (174, 180, 176)), (x, y))
    bar = pygame.Rect(x + 68, y + 4, 170, 9)
    pygame.draw.rect(surface, (58, 62, 66), bar, border_radius=2)
    fill = pygame.Rect(bar.x, bar.y, int(bar.width * clamp01(value / max(1, maximum))), bar.height)
    pygame.draw.rect(surface, color, fill, border_radius=2)
    surface.blit(font.render(f"{value:.0f}/{maximum:.0f}", True, (235, 235, 226)), (x + 246, y - 1))
    return y + 17


def phase_seconds_left(world) -> int:
    total = world.day_ticks if world.phase == "day" else world.night_ticks
    return max(0, math.ceil((total - world.phase_tick) / world.ticks_per_second))


def draw_thought_stack(surface: pygame.Surface, font: pygame.font.Font, thoughts, x: int, y: int) -> None:
    offset = 0
    for index, thought in enumerate(thoughts[:4]):
        text = thought.visible_text()
        lines = wrap_text(text, font, 230)[:3]
        height = len(lines) * (font.get_height() + 1) + 8
        push = min(1.0, thought.push_ticks / 24)
        rise = int(offset * push + thought.age_ticks * 0.08)
        alpha = 255
        remaining = thought.lifetime_ticks - thought.age_ticks
        if remaining < 45:
            alpha = max(45, int(255 * remaining / 45))
        draw_speech(surface, font, text, x, y - rise, alpha)
        offset += height + 8


def draw_speech(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int, alpha: int = 255) -> None:
    lines = wrap_text(text, font, 220)[:3]
    text_width = max(font.size(line)[0] for line in lines)
    text_height = len(lines) * (font.get_height() + 1)
    rect_width = text_width + 16
    rect_x = max(4, min(WORLD_W - rect_width - 4, x - rect_width // 2))
    rect = pygame.Rect(rect_x, max(4, y), rect_width, text_height + 8)
    bubble = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
    pygame.draw.rect(bubble, (250, 246, 214, alpha), bubble.get_rect(), border_radius=5)
    pygame.draw.rect(bubble, (90, 88, 80, alpha), bubble.get_rect(), 1, border_radius=5)
    line_y = rect.y + 4
    surface.blit(bubble, rect.topleft)
    for line in lines:
        rendered = font.render(line, True, (30, 30, 32))
        rendered.set_alpha(alpha)
        surface.blit(rendered, (rect.x + 8, line_y))
        line_y += font.get_height() + 1


def draw_centered(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int, color) -> None:
    rendered = font.render(text, True, color)
    surface.blit(rendered, (x - rendered.get_width() // 2, y))


def draw_line(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int, color) -> int:
    rendered = font.render(text, True, color)
    surface.blit(rendered, (x, y))
    return y + rendered.get_height() + 2


def draw_wrapped(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int, width: int, color) -> int:
    for line in wrap_text(text, font, width):
        y = draw_line(surface, font, line, x, y, color)
    return y


def wrap_text(text: str, font: pygame.font.Font, width: int) -> list[str]:
    lines: list[str] = []
    line = ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if font.size(candidate)[0] <= width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines or [""]


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))
