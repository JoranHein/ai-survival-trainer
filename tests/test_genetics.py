from alife.genetics import TRAIT_NAMES, breed_traits, clamp01


def test_child_traits_are_inherited_with_mutation_and_clamped():
    parent_a = {name: 0.0 for name in TRAIT_NAMES}
    parent_b = {name: 1.0 for name in TRAIT_NAMES}

    child = breed_traits(parent_a, parent_b, mutation_rate=1.0, mutation_strength=0.75, seed=7)

    assert set(child) == set(TRAIT_NAMES)
    assert all(0.0 <= value <= 1.0 for value in child.values())
    assert any(value != 0.5 for value in child.values())


def test_clamp01_limits_trait_values_to_unit_range():
    assert clamp01(-0.25) == 0.0
    assert clamp01(1.25) == 1.0
    assert clamp01(0.4) == 0.4
