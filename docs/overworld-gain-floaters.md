# Overworld gain floaters

Slice: `ux-overworld-gain-floaters-20261009` (owner request, 2026-10-09: "when hero picks up resource or anything I want a floating text appearing saying what was gained. Dwellings/resources/artifacts etc. and then slowly fading out").

## What floats

When an action on the map gives the player something, each gain floats up above the hero as one line (icon where one exists, outlined text), and fades out:

- sites the player keeps: "Sawmill claimed" (mines, dwellings, outposts, landmarks: sites with `persistent_control`; one-time pickups are not "claimed")
- artifacts (with their icon) and spells learned ("Learned Waystride")
- resources ("+10 Wood", "+750 Gold", rare resources), each with its resource icon
- troops that joined ("+4 Ember Archers", with the creature portrait)
- command stats ("+1 Attack"), experience, mana, movement restored
- battle boosts from visit buildings ("+2 Cohesion next battle")
- resources an action cost, last and in muted red ("-2 Ore")

## How

- `scripts/core/OverworldGainFeed.gd` takes a snapshot of what an overworld gain can change (stockpile, active hero's experience, command, artifacts, spells, mana, movement, army and boosts, the player's sites) and compares it with the state after the action. Every source counts without each rule reporting it. A walk's own movement cost is added back, so a stable at the end of a route shows what it restored.
- `OverworldShell` snapshots before route and single-step moves, context actions (collect, visit), reward choices, dwelling hires, site recruits and map spells, then hands the lines to the map (`_float_gains_since`). Moves that end in a battle, a town or a hero meeting float nothing (those screens show their own results).
- `scenes/overworld/OverworldGainFloaters.gd` is a layer of the map view above the objects and below the frame. Lines wait until the hero's walk there has finished, start 0.35 s apart, fade in over 0.25 s, rise 44 px, and fade out over the last 1.6 s of 3.4 s. They follow the camera. With reduced motion on they fade without rising. Presentation only.

## Validation

`tests/overworld_gain_floaters_report.tscn` (14 checks): the lines and their order, icons and tones; costs; movement after a walk and after a stable; no hero lines when the active hero changed; a pickup is not "claimed"; and on a generated small map a hero walks onto a wood pile through the real shell: "+10 Wood" is queued, floats after the walk and is gone after its lifetime. With `GAIN_FLOATER_CAPTURE` set in a windowed run it also floats a five-line sample and saves a capture; the 1920x1080 capture was reviewed.
