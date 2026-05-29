# Idle Survival Trainer

A focused Python + Pygame idle survival prototype with one autonomous creature. Ari is not directly controllable. The interface allows permanent upgrades and sign writing, but Ari still has to walk, train, eat, and fight inside the world.

Core rule:

> Upgrade potential, not obedience.

## Run

```bash
python main.py
```

## Setup

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Current Game Loop

- One survivor, Ari, tries to live as long as possible.
- Each Day 1 life rerolls Ari's born traits, so the best strategy changes from run to run.
- Ari keeps those traits for the whole life. Surviving to later days does not reroll them.
- The born traits are aggression, curiosity, charisma, and perseverance.
- Each day lasts about two minutes.
- During the day Ari can walk to the fruit tree, training dummy, reading stone, or bed.
- Ari can only use a station from nearby.
- At night a wave of enemies arrives.
- Ari chooses whether to fight with sword, fight with bow, or hide based on stats, fear, beliefs, and distance unless a fully learned sign gives a direct combat order.
- Ari's local brain model interprets those traits into weighted intentions, then samples instead of always taking the top score. The same build can produce different but explainable choices.
- Time Points increase linearly per second while Ari is alive.
- Death returns the run to Day 1 and Wave 1.
- Temporary learned levels reset on death.
- Permanent upgrades bought with Time Points remain.

## Infinite Scaling

Permanent upgrades have no cap, but their costs scale exponentially. Temporary learned stats also have no cap, but training gain slows exponentially as each stat grows.

This allows long-term boundary pushing without letting early point gain explode.

## Controls

- `U`: toggle permanent upgrade shop
- `1`-`9`: buy upgrades while the shop is open
- `W`: buy the next permanent word unlock while the shop is open
- `T`: write on the sign
- `Enter`: commit sign text
- `Esc`: cancel sign editing
- `Space`: pause
- `S`: save
- `L`: load
- `R`: reset
- `H`: toggle help

There is no player avatar and no direct command button for eating, training, fighting, or using the bow.

## World Stations

- Fruit Tree: produces one fruit on cooldown. Ari must walk to it before picking fruit.
- Training Dummy: Ari must walk to it before training attack, defense, strength, hitpoints, bow, or sword.
- Reading Stone: Ari can study a book and explore words.
- Bed: Ari restores Rest and lowers fear by sleeping there.
- Sign: the direct instruction channel. Ari can see it from anywhere, but must learn every word before executing the order.
- Night Edge: enemies enter from the right side at night.

## Literacy And Signs

Ari expands vocabulary by exploring stations and saying new words aloud. Seeing the tree can teach words like `tree`, `fruit`, and `eat`. Seeing the dummy can teach `train`, `attack`, `defense`, and `strength`. The book can teach more abstract words.

Sign instructions are reliable, but vocabulary-gated. Ari reads the sign from anywhere. If a word is unknown, Ari says it with `....`, walks to the Reading Stone, researches it in the book, says the word again, then continues. Once every word is known in the current run, phrases like `use bow`, `train defense`, `eat fruit`, and `study book` become hard goals.

Short signs are faster early. Longer signs become practical after upgrading Word Research or permanently memorizing common words.

The bubble above Ari is not a fixed event log. It is generated from current action, visible world state, sign text, hunger, fear, enemies, and the four born traits.

Example sign text:

```text
use bow at night
eat before night
train defense
study book
rest
```

Even when Ari understands the words, behavior is not guaranteed.

## Permanent Upgrades

- Max HP
- Attack
- Defense
- Strength
- Bow Mastery
- Training Speed
- Word Research
- Fruit Tree
- Passive Healing

The shop also has a `W` word unlock. It is expensive, but the chosen word is remembered forever between deaths and future Day 1 runs.

For example, heavy Bow Mastery investment makes bow use more effective, and writing `use bow at night` on the sign forces Ari to use the bow in combat.

## Save File

```text
saves/world_save.json
```

The save includes day, wave, phase, Time Points, permanent upgrades, Ari's temporary learned stats, personality, vocabulary, sign text, fruit cooldown, and active enemies.

## Tests

```bash
python -m compileall .
python -m pytest
```
