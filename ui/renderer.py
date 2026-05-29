from __future__ import annotations

import math

import pygame

from config import BACKGROUND_COLORS, LOG_HEIGHT, OBJECT_COLORS, SCREEN_HEIGHT, SCREEN_WIDTH, WORLD_HEIGHT, WORLD_WIDTH


def draw_world(surface: pygame.Surface, font: pygame.font.Font, small_font: pygame.font.Font, world, selected_id: str | None) -> None:
    surface.fill((18, 19, 21))
    world_rect = pygame.Rect(0, 0, WORLD_WIDTH, WORLD_HEIGHT)
    pygame.draw.rect(surface, BACKGROUND_COLORS.get(world.weather, (220, 220, 210)), world_rect)
    draw_room_grid(surface, world.tick_count)

    for obj in world.objects:
        draw_object(surface, font, obj)

    for creature in world.creatures:
        draw_creature(surface, font, small_font, creature, selected_id == creature.id)

    log_rect = pygame.Rect(0, WORLD_HEIGHT, WORLD_WIDTH, LOG_HEIGHT)
    pygame.draw.rect(surface, (24, 26, 28), log_rect)
    pygame.draw.line(surface, (62, 65, 68), (0, WORLD_HEIGHT), (WORLD_WIDTH, WORLD_HEIGHT), 2)


def draw_room_grid(surface: pygame.Surface, tick: int) -> None:
    for x in range(0, WORLD_WIDTH, 40):
        pygame.draw.line(surface, (210, 210, 194), (x, 0), (x, WORLD_HEIGHT), 1)
    for y in range(0, WORLD_HEIGHT, 40):
        pygame.draw.line(surface, (210, 210, 194), (0, y), (WORLD_WIDTH, y), 1)
    pulse = int((math.sin(tick / 50) + 1) * 10)
    pygame.draw.rect(surface, (194 + pulse, 188 + pulse, 164), pygame.Rect(8, 8, WORLD_WIDTH - 16, WORLD_HEIGHT - 16), 2)


def draw_object(surface: pygame.Surface, font: pygame.font.Font, obj) -> None:
    color = OBJECT_COLORS.get(obj.object_type, (200, 200, 200))
    x = int(obj.x)
    y = int(obj.y)
    if obj.object_type.endswith("fruit"):
        pygame.draw.circle(surface, color, (x, y), 8)
        pygame.draw.circle(surface, (60, 80, 55), (x + 3, y - 8), 3)
    elif obj.object_type == "bell":
        pygame.draw.polygon(surface, color, [(x, y - 13), (x - 12, y + 10), (x + 12, y + 10)])
        pygame.draw.circle(surface, (80, 60, 35), (x, y + 11), 3)
    elif obj.object_type == "music_stone":
        pygame.draw.polygon(surface, color, [(x, y - 13), (x + 14, y), (x, y + 13), (x - 14, y)])
        pygame.draw.circle(surface, (220, 210, 245), (x, y), 4)
    elif obj.object_type == "nest":
        pygame.draw.ellipse(surface, color, pygame.Rect(x - 18, y - 11, 36, 22))
        pygame.draw.ellipse(surface, (90, 60, 35), pygame.Rect(x - 11, y - 6, 22, 12))
    elif obj.object_type == "training_dummy":
        pygame.draw.rect(surface, color, pygame.Rect(x - 8, y - 18, 16, 34), border_radius=3)
        pygame.draw.circle(surface, (95, 82, 65), (x, y - 24), 8)
        pygame.draw.line(surface, (80, 65, 50), (x - 15, y - 3), (x + 15, y - 3), 4)
    elif obj.object_type == "soft_gloves":
        pygame.draw.circle(surface, color, (x - 6, y), 8)
        pygame.draw.circle(surface, color, (x + 7, y), 8)
    elif obj.object_type == "spiky_charm":
        pygame.draw.polygon(surface, color, [(x, y - 14), (x + 6, y - 3), (x + 14, y), (x + 5, y + 5), (x, y + 14), (x - 5, y + 5), (x - 14, y), (x - 6, y - 3)])
    elif obj.object_type == "calm_band":
        pygame.draw.circle(surface, color, (x, y), 13, 4)
        pygame.draw.circle(surface, (220, 245, 235), (x, y), 5)
    elif obj.object_type == "battle_drum":
        pygame.draw.ellipse(surface, color, pygame.Rect(x - 16, y - 10, 32, 20))
        pygame.draw.line(surface, (80, 50, 40), (x - 10, y - 15), (x + 10, y + 15), 3)
    elif obj.object_type == "lucky_pebble":
        pygame.draw.ellipse(surface, color, pygame.Rect(x - 12, y - 8, 24, 16))
        pygame.draw.circle(surface, (225, 235, 220), (x + 3, y - 2), 3)
    label = font.render(obj.object_type.replace("_", " "), True, (54, 54, 48))
    surface.blit(label, (x - label.get_width() // 2, y + 15))


def draw_creature(
    surface: pygame.Surface,
    font: pygame.font.Font,
    small_font: pygame.font.Font,
    creature,
    selected: bool,
) -> None:
    x = int(creature.x)
    y = int(creature.y)
    radius = int(creature.body_size)
    if selected:
        pygame.draw.circle(surface, (255, 245, 150), (x, y), radius + 6, 3)
    pygame.draw.circle(surface, creature.color, (x, y), radius)
    pygame.draw.circle(surface, (30, 30, 35), (x - radius // 3, y - radius // 4), 3)
    pygame.draw.circle(surface, (30, 30, 35), (x + radius // 3, y - radius // 4), 3)
    mouth_y = y + radius // 4
    if creature.needs.fear > 60:
        pygame.draw.line(surface, (35, 30, 30), (x - 5, mouth_y + 3), (x + 5, mouth_y - 2), 2)
    else:
        pygame.draw.arc(surface, (35, 30, 30), pygame.Rect(x - 6, mouth_y - 6, 12, 10), 0.2, 2.9, 2)

    name = font.render(creature.name, True, (42, 42, 38))
    surface.blit(name, (x - name.get_width() // 2, y - radius - 20))
    action = small_font.render(creature.current_action, True, (62, 62, 58))
    surface.blit(action, (x - action.get_width() // 2, y + radius + 5))
    if creature.speech and creature.speech_timer > 0:
        draw_speech(surface, small_font, creature.speech, x, y - radius - 50)


def draw_speech(surface: pygame.Surface, font: pygame.font.Font, text: str, x: int, y: int) -> None:
    rendered = font.render(text, True, (35, 35, 38))
    rect = pygame.Rect(x - rendered.get_width() // 2 - 8, y, rendered.get_width() + 16, rendered.get_height() + 8)
    pygame.draw.rect(surface, (250, 248, 224), rect, border_radius=5)
    pygame.draw.rect(surface, (100, 100, 90), rect, 1, border_radius=5)
    surface.blit(rendered, (rect.x + 8, rect.y + 4))
