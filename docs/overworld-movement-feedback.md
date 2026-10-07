# Overworld movement feedback

Owner playtest, 2026-10-07: the hero portrait bar kept stale movement points after map moves, and an order to attack an enemy on the map opened the battle at once, with no walk.

## Rules

- **The portrait bar shows real movement.** The roster reads the active hero's movement and mana from the session mirrors (`overworld.movement`, `overworld.hero`), which are authoritative until `commit_active_hero` copies them into `player_heroes`. Other heroes read their roster entries.
- **Route-only refreshes update the bar in place.** After a route, a step or a battle approach, `_refresh_live_route_status()` updates each existing roster button's Movement and Mana meters, tooltip and accessibility text through `_sync_hero_roster_readiness()`. A per-button readiness signature skips unchanged buttons. Buttons are never rebuilt on this path, so focus and node identity survive. Full refreshes (End Turn, hero switch, context actions, spells, returns from town or battle) rebuild the roster through the same helper.
- **The bar drains with the walk.** While the map plays the active hero's walk, the Movement meter steps down one point per tile on the walk's timing and lands on the real value when the walk ends. Without a walk (reduced motion, no steps), it is set at once.
- **Attacks walk first.** Attack orders (pointer select and confirm, the order button, Enter, the controller's confirm, arrow-key steps into an enemy) already use the normal route pipeline: `execute_prevalidated_route` or `try_move_along_route` moves the hero, spends one point per tile and stages the battle only when the final tile is reached. The shell skipped the walk animation for any result routed to battle and opened the battle at once. It now records the walk for battle results too, plays it, blocks every order, then opens the battle. The march (`_begin_battle_approach`) waits for the walk plus a short arrival beat, at least 0.25 s. Escape or Enter skips it.
- **Out-of-range attacks stop short.** When today's movement cannot reach the enemy, the hero walks as far as it can and nothing is fought. Ordering the attack again on a later day walks the rest and fights on arrival.
- Guards, interruptions, water boarding, auto-resolve, retreat and the post-battle return are unchanged: the battle payload is still created by the rules at arrival, and the shell only delays the screen change.
- Like end-turn playback, the march plays only when a display exists. Headless automation keeps the synchronous battle handoff unless a report opts in with `validation_set_battle_approach_presentation_enabled(true)`. Validation route steps (`validation_route_step_to_*`) skip the march so their results stay settled.

## Validation

`tests/overworld_movement_feedback_report.tscn` (`OVERWORLD_MOVEMENT_FEEDBACK_REPORT`) drives the real shell on a small fixture strip:

- a pointer route updates the portrait bar on the route-only path (no roster rebuild, no hero-action phase) and drains it step by step with the walk;
- an arrow-key step, a hero switch and End Turn keep the bar right;
- an attack order selects without spending, then walks six tiles, spends six points and stages the battle; the battle opens only after the walk has finished, other orders are refused meanwhile, and the battle carries the spent movement;
- clicking a random-map guard selects the nearest tile of its engagement ring; confirming walks there, spends the movement and opens that guard's battle after the walk;
- an out-of-range attack stops after three tiles with no battle; the next day the same order walks the rest and opens the battle on arrival.

Pass `--shots=<dir>` in a windowed run to capture the portrait bar.
