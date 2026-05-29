from __future__ import annotations

import sys
from pathlib import Path

import pygame

from alife.serialization import load_world, save_world
from alife.survival import IdleSurvivalWorld
from config import FPS, SAVE_PATH, SCREEN_HEIGHT, SCREEN_WIDTH
from ui.survival_ui import draw_survival_game


def main() -> None:
    pygame.init()
    pygame.display.set_caption("Idle Survival Trainer")
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    clock = pygame.time.Clock()
    font = pygame.font.SysFont("consolas", 16)
    small_font = pygame.font.SysFont("consolas", 13)

    world = IdleSurvivalWorld.new_game()
    paused = False
    show_help = True
    show_shop = False
    editing_sign = False
    sign_buffer = world.sign.text

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.TEXTINPUT and editing_sign:
                if len(sign_buffer) < 80 and event.text.isprintable():
                    sign_buffer += event.text
            elif event.type == pygame.KEYDOWN:
                if editing_sign:
                    if event.key == pygame.K_RETURN:
                        world.write_sign(sign_buffer)
                        editing_sign = False
                        pygame.key.stop_text_input()
                    elif event.key == pygame.K_ESCAPE:
                        editing_sign = False
                        sign_buffer = world.sign.text
                        pygame.key.stop_text_input()
                    elif event.key == pygame.K_BACKSPACE:
                        sign_buffer = sign_buffer[:-1]
                    continue

                if show_shop and pygame.K_1 <= event.key <= pygame.K_9:
                    world.purchase_upgrade_slot(event.key - pygame.K_1 + 1)
                elif show_shop and event.key == pygame.K_w:
                    word = world.next_permanent_word_candidate()
                    if word:
                        world.purchase_permanent_word(word)
                elif event.key == pygame.K_u:
                    show_shop = not show_shop
                elif event.key == pygame.K_t:
                    editing_sign = True
                    show_shop = False
                    sign_buffer = world.sign.text
                    pygame.key.start_text_input()
                elif event.key == pygame.K_SPACE:
                    paused = not paused
                elif event.key == pygame.K_h:
                    show_help = not show_help
                elif event.key == pygame.K_r:
                    world = IdleSurvivalWorld.new_game()
                    sign_buffer = world.sign.text
                    show_shop = False
                elif event.key == pygame.K_s:
                    save_world(world, SAVE_PATH)
                    world.message(f"Saved to {SAVE_PATH}.")
                elif event.key == pygame.K_l:
                    path = Path(SAVE_PATH)
                    if path.exists():
                        loaded = load_world(path)
                        if isinstance(loaded, IdleSurvivalWorld):
                            world = loaded
                        else:
                            world = IdleSurvivalWorld.new_game()
                            world.message("Old sandbox save ignored for survival mode.")
                        sign_buffer = world.sign.text
                    else:
                        world.message("No save file exists yet.")

        if not paused and not editing_sign:
            world.update()

        draw_survival_game(screen, font, small_font, world, show_shop, editing_sign, sign_buffer, show_help, paused)
        pygame.display.flip()
        clock.tick(FPS)

    pygame.quit()
    sys.exit(0)


if __name__ == "__main__":
    main()
