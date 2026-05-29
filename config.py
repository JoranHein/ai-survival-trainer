SCREEN_WIDTH = 1040
SCREEN_HEIGHT = 680
HUD_WIDTH = 320
LOG_HEIGHT = 0
WORLD_WIDTH = SCREEN_WIDTH - HUD_WIDTH
WORLD_HEIGHT = SCREEN_HEIGHT - LOG_HEIGHT

FPS = 30
SAVE_PATH = "saves/world_save.json"

PERCEPTION_RANGE = 170
SOCIAL_RANGE = 155
EAT_DISTANCE = 18
INTERACT_DISTANCE = 28
ADULT_AGE = 900
WEATHER_INTERVAL = 1800

WEATHER_TYPES = ("sunny", "rain", "cold")
ITEM_TYPES = (
    "red_fruit",
    "blue_fruit",
    "yellow_fruit",
    "bell",
    "music_stone",
    "nest",
    "training_dummy",
    "soft_gloves",
    "spiky_charm",
    "calm_band",
    "battle_drum",
    "lucky_pebble",
)

BACKGROUND_COLORS = {
    "sunny": (226, 225, 198),
    "rain": (184, 198, 205),
    "cold": (205, 217, 224),
}

OBJECT_COLORS = {
    "red_fruit": (220, 65, 58),
    "blue_fruit": (55, 115, 230),
    "yellow_fruit": (232, 200, 65),
    "bell": (212, 164, 65),
    "music_stone": (116, 88, 172),
    "nest": (150, 105, 58),
    "training_dummy": (135, 120, 96),
    "soft_gloves": (230, 145, 165),
    "spiky_charm": (165, 58, 70),
    "calm_band": (88, 170, 158),
    "battle_drum": (178, 82, 62),
    "lucky_pebble": (112, 132, 138),
}
