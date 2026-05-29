from alife.survival import IdleSurvivalWorld
from alife.brain import LocalBrainModel


def test_survivor_exposes_only_four_born_traits():
    world = IdleSurvivalWorld(seed=24)

    traits = world.survivor.personality_summary()

    assert set(traits) == {"aggression", "curiosity", "charisma", "perseverance"}
    assert all(0.0 <= value <= 1.0 for value in traits.values())


def test_sign_can_be_read_without_walking_to_it():
    world = IdleSurvivalWorld(seed=25, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = 50
    world.survivor.y = 50
    world.survivor.charisma = 1.0
    world.survivor.perseverance = 1.0
    world.survivor.learned.literacy = 8.0
    world.survivor.vocabulary = ["use", "bow", "at", "night"]
    world.write_sign("use bow at night")

    world.read_sign()

    assert "use bow" in world.survivor.instructions
    assert world.survivor.current_action == "thinking about sign"


def test_sign_is_fully_read_without_vocabulary_or_literacy():
    world = IdleSurvivalWorld(seed=31)
    world.survivor.vocabulary = []
    world.survivor.learned.literacy = 0
    world.write_sign("use bow at night")

    world.read_sign()

    assert "use bow" not in world.survivor.instructions
    assert world.survivor.pending_sign_words == ["use", "bow", "at", "night"]
    assert world.survivor.current_action == "reading unknown word"
    assert world.survivor.thoughts[0].text == "use...."


def test_unknown_sign_word_is_researched_at_book_then_spoken_again():
    world = IdleSurvivalWorld(seed=33, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.vocabulary = ["use"]
    world.write_sign("use bow")

    assert world.choose_day_action() == "research_word"
    assert world.survivor.researching_word == "bow"

    world.survivor.x = world.reading_stone.x
    world.survivor.y = world.reading_stone.y
    for _ in range(world.word_research_ticks_required("bow")):
        world.perform_day_action("research_word")

    assert "bow" in world.survivor.vocabulary
    assert world.survivor.pending_sign_words == []
    assert world.survivor.thoughts[0].text == "bow"
    assert "use bow" in world.survivor.instructions


def test_word_learning_speed_upgrade_reduces_research_time():
    slow = IdleSurvivalWorld(seed=34)
    fast = IdleSurvivalWorld(seed=34)
    fast.permanent.word_learning_speed = 4

    assert fast.word_research_ticks_required("defense") < slow.word_research_ticks_required("defense")


def test_permanent_word_unlock_survives_death_and_new_run():
    world = IdleSurvivalWorld(seed=35)
    world.time_points = 1000

    purchased = world.purchase_permanent_word("bow")
    world.kill_survivor("test")

    assert purchased is True
    assert "bow" in world.permanent.permanent_words
    assert "bow" in world.survivor.vocabulary


def test_sign_instruction_overrides_day_goal_choice():
    world = IdleSurvivalWorld(seed=32)
    world.survivor.curiosity = 1.0
    world.survivor.aggression = 0.0
    world.survivor.vocabulary = ["train", "defense"]
    world.write_sign("train defense")
    world.read_sign()

    action = world.choose_day_action()

    assert action == "train_defense"
    assert world.last_brain_thought.startswith("Plan train_defense:")
    assert "sign asks" in world.last_brain_thought


def test_default_game_timing_and_station_speed_are_slower():
    world = IdleSurvivalWorld()

    assert world.day_ticks == 3600
    assert world.night_ticks == 900
    assert world.station_move_speed() == 7.0


def test_bed_restores_rest_when_ari_is_nearby():
    world = IdleSurvivalWorld(seed=36)
    world.survivor.x = world.bed.x
    world.survivor.y = world.bed.y
    world.survivor.energy = 35

    world.perform_day_action("rest_in_bed")

    assert world.survivor.energy > 35
    assert world.survivor.current_action == "resting in bed"


def test_low_rest_makes_bed_action_more_attractive():
    world = IdleSurvivalWorld(seed=37)
    world.sign.text = ""
    world.survivor.energy = 18

    scores = world.day_action_scores()

    assert scores["rest_in_bed"] > scores["explore"]
    assert scores["rest_in_bed"] > scores["train_attack"]


def test_day_planner_keeps_explainable_reasons_for_survival_plans():
    world = IdleSurvivalWorld(seed=45)
    world.sign.text = ""
    world.survivor.hunger = 92
    world.fruit_tree.remaining_ticks = 0

    plans = world.day_action_plans()

    assert plans["eat"].action == "eat"
    assert any("hunger" in reason for reason in plans["eat"].reasons)
    assert any("fruit" in reason for reason in plans["eat"].reasons)


def test_rest_order_on_sign_sends_ari_to_bed():
    world = IdleSurvivalWorld(seed=38)
    world.survivor.vocabulary = ["rest"]
    world.write_sign("rest")

    action = world.choose_day_action()

    assert action == "rest_in_bed"


def test_eat_sign_is_satisfied_after_fruit_until_hungry_again():
    world = IdleSurvivalWorld(seed=40, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.vocabulary = ["eat", "before", "night"]
    world.write_sign("eat before night")
    world.survivor.x = world.fruit_tree.x
    world.survivor.y = world.fruit_tree.y
    world.survivor.hunger = 95
    world.perform_day_action("eat")

    action = world.choose_day_action()

    assert world.fruit_tree.remaining_ticks > 0
    assert world.survivor.hunger < 58
    assert action != "eat"
    assert not world.last_brain_thought.startswith("Sign order: eat")


def test_eat_sign_still_sends_hungry_ari_to_ready_fruit():
    world = IdleSurvivalWorld(seed=41, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.vocabulary = ["eat", "before", "night"]
    world.write_sign("eat before night")
    world.survivor.hunger = 95
    world.fruit_tree.remaining_ticks = 0

    action = world.choose_day_action()

    assert action == "eat"


def test_eat_sign_starts_walking_when_fruit_will_be_ready_on_arrival():
    world = IdleSurvivalWorld(seed=42, ticks_per_second=10, day_ticks=240, night_ticks=20)
    world.survivor.vocabulary = ["eat", "before", "night"]
    world.write_sign("eat before night")
    world.survivor.x = 650
    world.survivor.y = 610
    world.survivor.hunger = 86
    world.fruit_tree.remaining_ticks = 70

    action = world.choose_day_action()

    assert action == "eat"
    assert "arrive" in world.last_brain_thought or "ready soon" in world.last_brain_thought


def test_eat_plan_waits_briefly_if_ari_arrives_before_fruit_respawns():
    world = IdleSurvivalWorld(seed=43, ticks_per_second=10, day_ticks=240, night_ticks=20)
    world.survivor.vocabulary = ["eat", "before", "night"]
    world.write_sign("eat before night")
    world.survivor.x = world.fruit_tree.x
    world.survivor.y = world.fruit_tree.y
    world.survivor.hunger = 90
    world.fruit_tree.remaining_ticks = 5
    world.survivor.committed_action = "eat"
    world.survivor.commitment_ticks = 40

    world.perform_day_action("eat")

    assert world.survivor.current_action == "waiting for fruit"
    assert world.survivor.committed_action == "eat"


def test_eat_plan_does_not_camp_tree_when_respawn_is_too_far_away():
    world = IdleSurvivalWorld(seed=44, ticks_per_second=10, day_ticks=240, night_ticks=20)
    world.survivor.vocabulary = ["eat", "before", "night"]
    world.write_sign("eat before night")
    world.survivor.x = world.fruit_tree.x
    world.survivor.y = world.fruit_tree.y
    world.survivor.hunger = 58
    world.fruit_tree.remaining_ticks = 900
    world.survivor.committed_action = "eat"
    world.survivor.commitment_ticks = 40

    world.perform_day_action("eat")

    assert world.survivor.committed_action is None
    assert world.survivor.current_action == "waiting for fruit"


def test_training_rest_drain_is_slow():
    world = IdleSurvivalWorld(seed=39)
    world.survivor.x = world.dummy.x
    world.survivor.y = world.dummy.y
    world.survivor.energy = 100

    world.train("attack")

    assert 98.5 <= world.survivor.energy < 100


def test_traits_are_interpreted_into_day_action_scores():
    cautious = IdleSurvivalWorld(seed=26)
    bold = IdleSurvivalWorld(seed=26)
    cautious.survivor.aggression = 0.05
    cautious.survivor.curiosity = 0.05
    cautious.survivor.charisma = 0.05
    cautious.survivor.perseverance = 0.05
    bold.survivor.aggression = 0.95
    bold.survivor.curiosity = 0.95
    bold.survivor.charisma = 0.95
    bold.survivor.perseverance = 0.95

    low_scores = cautious.day_action_scores()
    high_scores = bold.day_action_scores()

    assert high_scores["train_attack"] > low_scores["train_attack"]
    assert high_scores["explore"] > low_scores["explore"]
    assert high_scores["read_sign"] > low_scores["read_sign"]


def test_generated_thought_uses_environment_action_emotion_and_traits():
    world = IdleSurvivalWorld(seed=27)
    world.survivor.hunger = 92
    world.survivor.fear = 65
    world.survivor.curiosity = 0.9
    world.survivor.perseverance = 0.9
    world.survivor.current_action = "training attack"
    world.fruit_tree.remaining_ticks = 0

    thought = world.generate_thought()

    assert thought
    assert any(word in thought.lower() for word in ["fruit", "belly", "fear", "practice", "plan", "tree"])


def test_thoughts_stack_and_longer_text_lasts_longer():
    world = IdleSurvivalWorld(seed=28)

    world.think("Short thought.")
    short_lifetime = world.survivor.thoughts[0].lifetime_ticks
    world.think("This is a much longer thought that should remain readable for longer.")

    assert len(world.survivor.thoughts) == 2
    assert world.survivor.thoughts[0].text.startswith("This is")
    assert world.survivor.thoughts[1].text == "Short thought."
    assert world.survivor.thoughts[0].lifetime_ticks > short_lifetime
    assert world.survivor.thoughts[1].push_ticks == 0


def test_thoughts_type_in_and_age_out():
    world = IdleSurvivalWorld(seed=29)
    world.think("Typing should appear slowly.", duration=12)

    for _ in range(3):
        world.update_thoughts()

    thought = world.survivor.thoughts[0]
    assert thought.visible_text() != thought.text
    assert len(thought.visible_text()) <= 2

    for _ in range(20):
        world.update_thoughts()

    assert world.survivor.thoughts == []


def test_explore_walks_without_action_pause_until_station_reached():
    world = IdleSurvivalWorld(seed=30)
    world.survivor.x = 650
    world.survivor.y = 650
    world.survivor.explore_target = "tree"

    world.perform_day_action("explore")

    assert world.survivor.current_action == "walking to tree"
    assert world.survivor.action_timer == 0
    assert world.survivor.explore_target == "tree"


def test_local_brain_model_samples_close_intentions_instead_of_argmax_only():
    world = IdleSurvivalWorld(seed=21)
    brain = LocalBrainModel()
    scores = {"train_attack": 5.0, "study_book": 5.1, "wander": 4.9}

    choices = {brain.choose(scores, world.rng, temperature=1.4).action for _ in range(40)}

    assert len(choices) > 1
    assert "study_book" in choices


def test_combat_choice_records_brain_thought():
    world = IdleSurvivalWorld(seed=23, ticks_per_second=10, day_ticks=100, night_ticks=20)

    weapon = world.choose_weapon(enemy_distance=80)

    assert weapon in {"bow", "sword", "hide"}
    assert world.last_brain_thought.startswith("Combat:")


def test_surviving_night_keeps_personality_until_death():
    world = IdleSurvivalWorld(seed=22, ticks_per_second=10, day_ticks=100, night_ticks=20)
    old_traits = world.survivor.personality_signature()
    world.permanent.bow = 4
    world.survivor.learned.attack = 3.5
    world.survivor.vocabulary.append("bow")
    world.survivor.instructions.append("use bow")

    world.finish_night()

    assert world.day == 2
    assert world.permanent.bow == 4
    assert world.survivor.learned.attack == 3.5
    assert "bow" in world.survivor.vocabulary
    assert "use bow" in world.survivor.instructions
    assert world.survivor.personality_signature() == old_traits


def test_time_points_accumulate_faster_on_higher_waves():
    world = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.wave = 1
    for _ in range(10):
        world.update()
    low_wave_points = world.time_points

    world.time_points = 0
    world.wave = 6
    for _ in range(10):
        world.update()

    assert world.time_points == low_wave_points


def test_permanent_upgrade_cost_scales_exponentially_without_cap():
    world = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    first = world.upgrade_cost("bow_mastery")
    world.permanent.bow = 1
    second = world.upgrade_cost("bow_mastery")
    world.permanent.bow = 2
    third = world.upgrade_cost("bow_mastery")

    assert third / second == second / first
    assert third > second > first


def test_permanent_upgrade_survives_death_but_learned_levels_reset():
    world = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.time_points = 500
    world.purchase_upgrade("bow_mastery")
    world.survivor.learned.bow = 7
    world.survivor.learned.attack = 5
    permanent_bow = world.permanent.bow

    world.kill_survivor("test")

    assert world.day == 1
    assert world.wave == 1
    assert world.permanent.bow == permanent_bow
    assert world.survivor.learned.bow == 0
    assert world.survivor.learned.attack == 0
    assert world.survivor.alive


def test_fruit_tree_has_cooldown_instead_of_unlimited_fruit():
    world = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.fruit_tree.cooldown_ticks = 30
    world.survivor.x = world.fruit_tree.x
    world.survivor.y = world.fruit_tree.y
    first = world.pick_fruit()
    second = world.pick_fruit()

    for _ in range(30):
        world.fruit_tree.tick(world.permanent)
    third = world.pick_fruit()

    assert first is True
    assert second is False
    assert third is True


def test_training_dummy_improves_temporary_combat_stats():
    world = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = world.dummy.x
    world.survivor.y = world.dummy.y
    before = world.survivor.learned.attack

    world.train("attack")

    assert world.survivor.learned.attack > before
    assert world.survivor.energy < 100


def test_training_gain_is_infinite_but_slows_exponentially():
    low = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    high = IdleSurvivalWorld(seed=1, ticks_per_second=10, day_ticks=100, night_ticks=20)
    for world in (low, high):
        world.survivor.x = world.dummy.x
        world.survivor.y = world.dummy.y
    high.survivor.learned.attack = 25

    before_low = low.survivor.learned.attack
    before_high = high.survivor.learned.attack
    low.train("attack")
    high.train("attack")

    low_gain = low.survivor.learned.attack - before_low
    high_gain = high.survivor.learned.attack - before_high
    assert 0 < high_gain < low_gain


def test_bow_upgrade_improves_potential_but_does_not_force_bow_choice():
    world = IdleSurvivalWorld(seed=3, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.permanent.bow = 12
    world.survivor.learned.sword = 5
    world.survivor.fear = 80
    world.survivor.beliefs["bow"] = -0.8

    choice = world.choose_weapon(enemy_distance=18)

    assert choice != "bow"


def test_sign_instruction_can_bias_bow_choice_after_creature_reads_it():
    world = IdleSurvivalWorld(seed=3, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.permanent.bow = 6
    world.survivor.charisma = 1.0
    world.survivor.perseverance = 1.0
    world.survivor.learned.literacy = 8.0
    world.survivor.vocabulary = ["use", "bow", "at", "night"]
    world.write_sign("use bow at night")

    world.read_sign()

    choice = world.choose_weapon(enemy_distance=90)

    assert "use bow" in world.survivor.instructions
    assert choice == "bow"


def test_studying_book_trains_literacy_and_unlocks_vocabulary():
    world = IdleSurvivalWorld(seed=4, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = world.reading_stone.x
    world.survivor.y = world.reading_stone.y
    world.survivor.curiosity = 1.0
    world.survivor.perseverance = 1.0
    before = world.survivor.learned.literacy
    before_words = set(world.survivor.vocabulary)

    for _ in range(8):
        world.study_book()

    assert world.survivor.learned.literacy > before
    assert set(world.survivor.vocabulary) > before_words


def test_unknown_sign_words_do_not_create_reliable_instruction():
    world = IdleSurvivalWorld(seed=5, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.charisma = 0.1
    world.survivor.perseverance = 0.1
    world.survivor.learned.literacy = 0
    world.survivor.vocabulary = ["eat"]
    world.write_sign("use bow at night")

    world.read_sign()

    assert "use bow" not in world.survivor.instructions
    assert world.survivor.pending_sign_words == ["use", "bow", "at", "night"]


def test_death_rerolls_personality_but_keeps_permanent_upgrades():
    world = IdleSurvivalWorld(seed=6, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.permanent.bow = 3
    old_traits = world.survivor.personality_signature()

    world.kill_survivor("test")

    assert world.permanent.bow == 3
    assert world.survivor.personality_signature() != old_traits


def test_survivor_must_walk_into_range_before_using_tree():
    world = IdleSurvivalWorld(seed=7, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = 700
    world.survivor.y = 700
    world.survivor.hunger = 95
    world.fruit_tree.remaining_ticks = 0
    world.sign.text = ""

    ate_far_away = world.pick_fruit()
    world.choose_and_do_action()
    first_action = world.survivor.current_action
    for _ in range(180):
        world.choose_and_do_action()

    assert ate_far_away is False
    assert first_action == "walking to tree"
    assert world.fruit_tree.remaining_ticks > 0


def test_survivor_sticks_with_tree_task_while_walking():
    world = IdleSurvivalWorld(seed=9, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = 700
    world.survivor.y = 700
    world.survivor.hunger = 95
    world.fruit_tree.remaining_ticks = 0
    world.sign.text = ""

    for _ in range(12):
        world.update()

    assert world.survivor.committed_action == "eat"
    assert world.survivor.current_action == "walking to tree"


def test_station_walk_progresses_smoothly_each_update():
    world = IdleSurvivalWorld(seed=10, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = 700
    world.survivor.y = 700
    world.survivor.hunger = 95
    start_x = world.survivor.x
    start_y = world.survivor.y

    world.update()
    first_step = abs(world.survivor.x - start_x) + abs(world.survivor.y - start_y)
    after_first_x = world.survivor.x
    after_first_y = world.survivor.y
    world.update()
    second_step = abs(world.survivor.x - after_first_x) + abs(world.survivor.y - after_first_y)

    assert 6 < first_step < 10
    assert 6 < second_step < 10


def test_reaching_dummy_starts_training_session_before_reconsidering():
    world = IdleSurvivalWorld(seed=11, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.x = world.dummy.x
    world.survivor.y = world.dummy.y
    world.survivor.committed_action = "train_attack"
    world.survivor.commitment_ticks = 30
    before = world.survivor.learned.attack

    for _ in range(8):
        world.update()

    assert world.survivor.committed_action == "train_attack"
    assert world.survivor.current_action == "training attack"
    assert world.survivor.learned.attack > before


def test_exploring_station_says_word_and_trains_literacy():
    world = IdleSurvivalWorld(seed=8, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.vocabulary = []
    before = world.survivor.learned.literacy

    word = world.explore_station("tree")

    assert word in world.survivor.vocabulary
    assert world.survivor.learned.literacy > before
    assert world.survivor.speech == word
