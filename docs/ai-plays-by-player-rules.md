# AI Plays By Player Rules

Owner feedback, 2026-10-07: enemy "raids" feel wrong; the AI should play like a human with real heroes that take mines, improve towns and fight map guards under the same rules as the player.

## Current model (before this change)

- `EnemyTurnRules.run_enemy_turn` ran an "empire cycle" per computer player: income, weekly musters, town builds (with an AI-only pacing floor), a hero task board, raid reinforcement, abstract pressure gain, raid launches and an abstract siege counter.
- Enemy armies on the map were raid encounters (`session.overworld.encounters` entries with `spawned_by_faction_id`), spawned at towns once a pressure counter crossed a threshold. Their armies came from encounter templates such as "Mireclaw Raid", led by a commander from the faction roster.
- `EnemyAdventureRules.advance_raids` moved each raid one tile per day (`RAID_BASE_MOVEMENT_STEPS = 1`), chose targets through a large planner, "broke" neutral guards and dwelling guards by comparing strength numbers without losses, pillaged the player's treasury on arrival, and could capture towns through a siege counter without a battle.

## Target model

- Enemy power on the map is heroes. An AI hero is still stored as an encounter entry (so map rendering, fog, battles against the player, saves and turn playback keep working), marked by an `ai_hero` block: daily movement, home town and current goal. Its hero record is `enemy_commander_state`; its army is `enemy_army`, made of real troops.
- Heroes are hired from a tavern in an owned town (needs the Tavern building, the player's hero limit and the template's gold cost, weekly offer of two faction heroes). Every computer player starts with one hero and its faction's default starting army, like the human.
- Each AI hero spends movement points tile by tile (1 point per step, `HeroCommandRules.movement_max_for_hero` at normal difficulty). Pathing uses the player's blocking rules: impassable terrain and water, object bodies, towns; neutral guard zones and armies stop a route and can only be entered to fight.
- Target choice is a simple utility score: value of the object for the faction (resources it is short of count more), divided by days of travel, filtered by a strength check. Candidates: resource pickups, mines and other claimable sites, dwellings, artifacts, neutral guards and wandering armies the hero can beat, neutral towns, player heroes and player towns when strong enough, and its own towns to pick up troops or to defend when a hostile hero is near.
- Fights with neutral guards, dwelling guards and neutral town garrisons run through the player's auto-resolve: a disposable battle session with the AI hero on the attacking side and `BattleAutoResolveRules.resolve_active_battle`. Losses, experience and rewards come from that battle. A lost battle removes the hero.
- Attacks on player heroes and towns start a normal battle the human plays (`hero_intercept` / `town_defense` contexts), exactly as raids did.
- Towns: one build per town per day with the existing build scoring (the AI-only pacing floor is gone; the Tavern comes first while the faction has fewer than two heroes), recruits bought at real cost from real availability into the garrison, and heroes in town take the garrison along.
- Economy: income from owned towns, controlled sites and hero artifacts, exactly like the player. No pillage, no abstract siege capture, no pressure-driven spawns. Difficulty keeps only the battle knobs DifficultyRules defines for the enemy side.

## Reused player rules

- `HeroCommandRules.build_hero_from_template` (shared hero builder; Agent E's starting army and level change belongs in the shared hire path), `movement_max_for_hero`, `army_addition_plan`, `HERO_LIMIT`, `hero_recruit_cost`.
- `OverworldRules` terrain passability, body blocking, guard engagement tiles, town income, controlled site income and weekly growth.
- `BattleRules.create_battle_payload` and `BattleAutoResolveRules.resolve_active_battle` for every AI fight.
- Existing site claim, dwelling hire, artifact and town service code paths in `EnemyAdventureRules` / `EnemyTownServices` for the actual object effects (rewards, controller change, recruits, spells, equipment).

## Save migration

`EnemyTurnRules.normalize_enemy_states` converts every live raid encounter with a commander into an AI hero: it keeps position, army and commander, gets the hero template's movement and a fresh goal, and its encounter template switches to the generic field army. Commanderless raid columns are disbanded and their troops return to the nearest town of their controller (or vanish if it owns none). Old pressure, raid counters and task boards stay in the state but no longer drive anything.

## Test plan

- New `tests/ai_player_rules_report.gd/.tscn`: a small generated skirmish played for several days; asserts an AI hero captures a mine, an AI hero fights a guard through auto-resolve, an AI town builds and recruits with the treasury actually reduced, and no raid entities exist (including a migrated legacy raid).
- Existing AI scenes that encode the raid model are updated to the hero behavior; scenes that test general rules stay.
- `large_generated_map_runtime_profile_report` end-turn timing before and after (its pre-existing signature failure is unrelated).
