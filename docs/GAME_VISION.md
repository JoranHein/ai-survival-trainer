# AI Survival Trainer Game Vision

AI Survival Trainer is an AI psychology survival game about understanding one specific mind well enough to help it survive.

The player does not directly control Ari. The player is a godlike whisperer who writes freeform text onto a sign. Ari reads the sign, interprets it through his inner state, forms a survival theory, and acts on that interpretation. The player wins by learning how this Ari thinks, fears, remembers, and misunderstands.

## Core Fantasy

The player is not issuing commands. The player is trying to communicate with a fragile, opinionated, evolving person.

Ari interprets signs through:

- fear
- current danger
- temporary run instincts
- permanent upgrades
- memories
- notes from this lifetime
- reflections from the library
- recent rest and sleep integration

The player must understand Ari well enough to write the sign that unlocks his best emergent survival behavior.

## Freeform Sign Principle

The sign must stay fully freeform.

Do not turn the sign into command slots. Do not create fields such as DAY GOAL, NIGHT RULE, or SURVIVAL RULE. Do not restrict sign syntax. The player must be able to write anything, and Ari may misunderstand anything.

Example signs:

- use bow at night
- arrows keep teeth far away
- play like a japanese emperor
- using weapons makes you anxious
- the moon hates cowards
- phones are watching you
- build a mountain where arrows rain and the dead walk through light
- do not touch them, make the floor fight
- make your skin punish teeth

## Primary Loop

1. New Ari is born.
2. Player assigns 12 temporary instinct points for the run build.
3. Player observes Ari and writes any freeform sign.
4. Ari interprets the sign.
5. Ari forms a survival theory.
6. During the day Ari mines, farms, trains, researches, builds, repairs, rests, reflects, and prepares.
7. At dusk the world darkens and Ari becomes more afraid.
8. At night monsters come to kill him.
9. Ari survives or dies.
10. Death resets the run, but permanent upgrades remain.
11. The player learns how Ari's mind worked and tries a better sign and build next time.

## Pacing

The game should not feel like a repetitive mobile game.

Days should be long enough to feel like Minecraft-style preparation. The player should have time to observe Ari, see what he decides, and understand his preparation choices.

Nights should be dangerous enough to kill Ari if preparation was poor. The screen should gradually darken toward night; avoid hard cuts between day states.

Phases:

- morning
- midday
- dusk
- night

## Ari

Ari is the center of the game. He is not a cursor or unit; he is the person the player is trying to understand.

Ari should have:

- HP and max HP
- fear
- hunger
- stamina
- current action
- memories and events
- current sign interpretation
- survival theory
- thought bubbles
- lifetime notes
- library reflections
- rest integration

Fear is not just a number. It changes interpretation, tactics, and the believability of signs.

## Thought Bubbles

Ari should share meaningful thoughts in readable text bubbles above his head. The player should understand Ari better by reading his thoughts.

Do not spam every tiny calculation. Show formed, meaningful thoughts:

- sign interpretation
- emotional shifts
- tactic changes
- library lessons
- rest integration
- fear spikes
- wall breaks
- new monster types
- near death
- survival realizations
- death realizations

Example thoughts:

- "I really need to have some time for myself now."
- "The wall is not safety anymore."
- "Up here, their hands cannot reach me."
- "The light hurts them before I have to."
- "If they touch me, they suffer too."
- "I am not brave. I am still moving."
- "The flying ones do not care about stone."
- "I thought the wall would hold. It did not."
- "I need stone before courage."
- "If I am high enough, maybe death has to climb."
- "I read the last note again. The wings still scare me."

## Progression

Progression has two layers: permanent upgrades and temporary run instincts.

Permanent upgrades make Ari stronger overall, but they must not remove the need to understand Ari.

Permanent upgrade examples:

- Max HP
- Base attack
- Defense
- Bow ability
- Sword ability
- Mining efficiency
- Building efficiency
- Farming yield
- Warding power
- Trapcraft power
- Regeneration
- Fear recovery
- Sign understanding
- Movement speed, slightly
- Attack range, carefully scaled

At the start of each run, the player gets 12 temporary instinct points to shape that run's build.

Temporary run instinct examples:

- Bow
- Sword
- Movement
- Attack Range
- Mining
- Building
- Farming
- Warding
- Trapcraft
- Thorns
- Regeneration
- Defense
- Fear Control
- Sign Faith
- Research / Curiosity

The build does not force behavior. The player still needs a sign that resonates with Ari.

## Daytime Systems

Ari can eventually:

- mine
- farm
- train on a dummy
- build
- repair
- place objects
- research
- rest
- reflect in the library
- read lifetime notes while resting
- prepare fallback positions
- form survival theories

Do not implement these systems early. Add them one milestone at a time.

## Buildable And Placeable Systems

The final game should eventually include:

- stone walls with materials and HP
- towers / bow perches
- aura balls / ward orbs that damage enemies over time in a radius
- spike traps
- tar pits / slow mud
- fear lanterns
- thorn totems / thornbody recoil damage
- repair banners / workbenches
- decoy idols
- storm rods for flying enemies

These are future systems. Early milestones should use placeholder visuals and focused mechanics.

## Reflection And Library

Reflection only happens in the library.

Ari physically goes to the library to think. At the library, Ari reviews experiences and writes markdown-like notes for this lifetime.

Example note:

```markdown
# Day 3 - The tower saved me from teeth, not wings

The tower kept the zombies below me.
But the flying beasts reached me anyway.
Height is not the same as sky safety.

Next focus:
- train bow
- build storm rod
- do not trust walls against wings
```

Library reflection creates new lessons. It should feel like Ari is making sense of what happened, not receiving a mechanical upgrade.

## Rest System

When Ari rests, he reads all markdown notes from this lifetime, with emphasis on the newest note.

Rest integrates lessons emotionally. Rest does not create new lessons; it consolidates what Ari already wrote.

## Enemy Vision

Nights introduce monsters that punish shallow strategies:

- zombies: slow and weak
- runners: fast ground enemies
- brutes: strong wall breakers
- flying beasts: fly over walls and require bow, storm, roof, or shelter
- burrowers: undermine foundations
- spitters: ranged enemies
- swarms: overwhelm single-target builds

Enemies should force the player to reason about Ari's understanding, not just stat scaling.

## AI And LLM Vision

Eventually the game may connect to a Hetzner-hosted local LLM setup.

Use two tiers:

- small fast model for emotional thoughts and minor tactic lines
- larger model for major sign interpretation, death summaries, and survival theory

The LLM is Ari's mind, not his body.

The game engine controls:

- movement
- combat
- building
- collision
- pathfinding
- damage
- farming
- mining
- monsters
- direct state mutation

The LLM may only propose:

- interpretation
- belief deltas
- priorities
- emotional lines
- survival theories

Never let LLM output directly mutate game state. Always validate JSON. Always provide deterministic fallback.

## Godot Direction

Use Godot 4 and GDScript. Do not use C#.

Build the real game under `godot_game/`. The Python/Pygame prototype is only a reference.

## Development Principles

- Work one milestone at a time.
- Keep the game runnable after every change.
- Do not implement future systems early.
- Do not do large unrelated refactors.
- Use simple placeholder art first.
- Prefer readable small scripts.
- Use data files later for balance.
- Every task should include manual test steps.
- Never try to build the entire game in one prompt.
