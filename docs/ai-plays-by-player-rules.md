# AI Plays By Player Rules

Owner feedback, 2026-10-07: enemy "raids" feel wrong; the AI should play like a human with real heroes that take mines, improve towns and fight map guards under the same rules as the player.

## Model before this change

- `EnemyTurnRules.run_enemy_turn` ran an "empire cycle" per computer player: income, weekly musters, town builds (with an AI-only pacing floor), a hero task board, raid reinforcement, abstract pressure gain, raid launches and an abstract siege counter.
- Enemy armies on the map were raid encounters (`session.overworld.encounters` entries with `spawned_by_faction_id`), spawned at towns once a pressure counter crossed a threshold. Their armies came from encounter templates such as "Mireclaw Raid", led by a commander from the faction roster.
- `EnemyAdventureRules.advance_raids` moved each raid one tile per day, chose targets through a large planner, "broke" neutral and dwelling guards by comparing strength numbers without losses, pillaged the player's treasury on arrival, and could capture towns through a siege counter.

## Model now (`scripts/core/AiHeroRules.gd`)

`EnemyTurnRules.run_enemy_turn` calls `AiHeroRules.run_faction_turn` for every computer player. The raid director is removed (2026-10-07). What is left in `EnemyAdventureRules` serves heroes and old saves: commander roster records, raid army normalization for the save migration, the site seizure `_secure_resource_target` and the AI event records. Its multi-level path surfaces are not used in play; the RMG transit and start placement validation tools plan journeys with them, and they are the starting point for heroes that cross levels. `EnemyTurnRules` keeps the turn loop, enemy state normalization and the threat summaries.

### Heroes

- An AI hero is an encounter entry (so map rendering, fog, battles against the human, saves and turn playback keep working) with an `ai_hero` block: hero id, movement `{current, max}`, home town, hire day, private goal and a short avoid list. Its hero record is `enemy_commander_state`; its army is `enemy_army`, made of real troops. The encounter template (`encounter_mire_raid`) only supplies battle settings; battles are called "Battle with <hero>".
- Every computer player starts with one hero and its faction's default starting army, like the human. More heroes are hired in a town with a Tavern through the shared hire path (`HeroCommandRules.tavern_offer` + `build_recruited_hero`), paying the template's gold cost, up to `HERO_LIMIT`. Wanted heroes: 1 + min(towns, 2), plus one from day 14.
- Movement uses the human's rules: `movement_max_for_hero` at normal difficulty, one point per tile, full budget each day. Pathing is an 8-way search with the overworld corner rule; water and rock are impassable, object bodies block, town doorways and site visit tiles can be stood on. Guard zones, armies and heroes end a route. A site that holds nothing more for the hero (a picked-up cache, its own mine) can be walked across.
- Knowledge is fog-honest. Each computer player keeps an explored map (`ai_explored`, base64 bitsets per level). Its towns see as far as the human's (`OverworldRules.TOWN_VISION_RADIUS`), its heroes their scouting radius along every step. Map objects count once explored; human heroes and rival AI heroes only while in sight. With nothing worth doing in reach, a hero walks to the nearest unexplored frontier.

### Choosing what to do

Each decision is a utility score: value / (1 + distance / daily movement), with a bonus for keeping yesterday's goal. Values are gold equivalents.

- Resource pickups, mines and other claimable sites (resources the faction is short of count 1.8x), dwellings (a week of troops) and visit buildings (what the building gives, in gold, only when the hero has the level and the faction the price it asks).
- Artifacts.
- Neutral guards and wandering armies the hero beats with a 1.5x power margin. A guard is worth its reward, plus what stands in its zone (sites, artifacts, a town doorway: on generated maps guards sit next to what they protect without a link), plus the ground it opens: open ground behind its zone the hero cannot reach today counts 300 and 4 for each unexplored tile, and sites already seen there count at half their value (up to 5000 in all). From that come the troops the fight should cost, estimated with Lanchester's square law (a defender r times the hero's strength costs 1 - sqrt(1 - r^2) of it). Before setting out to fight a guard or a rival hero the hero runs the same auto-resolve on a scratch session (skipped at a 3x margin), and goes only when it wins, keeps at least half its strength and the fight still pays with the losses that battle really shows; otherwise it leaves that target for three days.
- Neutral towns (power margin 1.4x over the garrison), human towns (1.4x over garrison plus defending hero), human heroes in sight (1.3x). Town assaults and dwelling guards subtract the same loss estimate.
- Its own towns: the main hero collects the garrison, a lesser hero picks it up to carry it out when the main hero is more than a day's march away, and a hostile hero near the town makes it urgent.
- Its own main hero: a lesser hero walks over and hands its troops to the main hero, keeping one creature of its weakest kind. A hand-over is worth at most what a modest site is worth (600), so lesser heroes finish their own errands first.

Lesser heroes act before the main hero each day, so troops they hand over are with the main hero when it acts. The strongest hero is the main army: it takes the garrison when it visits a town (unless the town is threatened) and holds the gate of a town a hostile hero can reach. A lesser hero near the main hero leaves all but its weakest stack in a town for it.

A guard's zone works as it does for the human: anything inside it is reached by fighting the guard first, and rock or an object's body inside the zone cannot be stood on (only a doorway or visit tile there). A fight that leaves the guard standing sends the hero back to the tile it attacked from, and a hero hemmed in by a zone fights its way out when the odds are at least even.

With nothing worth doing, a hero first takes a second look at up to two fights it dismissed on the estimate: the preview shows what each really costs, and one that pays after all is fought. Otherwise it walks back, over as many days as it takes, to wait within two tiles of its home town's doorway, where the next recruits come from. Idle heroes left in the field used to fill the only exit of a dead end or a one-tile corridor and hold the main army there.

### Fights

- Neutral guards, dwelling guards, neutral town garrisons and rival AI heroes are fought with the human's auto-resolve: a disposable battle session (`BattleRules.create_battle_payload`, `BattleAutoResolveRules.resolve_active_battle`) with the AI hero on the attacking side. Survivors, experience, artifacts and rewards come from that battle. A lost battle removes the hero; a stalemate keeps both armies.
- Attacks on human heroes and towns start a normal battle the human plays (`hero_intercept` / `town_defense`). A hero that wins a town assault captures the town and stays on the map as a hero.

### Towns and economy

- Each day: build a Tavern while the faction needs heroes, hire, recruit, then build. A hire appears at the town even when one of the faction's own heroes stands in the doorway: that hero is in the town, as with the human's visiting heroes. Recruits are bought at real cost from real availability into the garrison (highest tier first). One build per town per day, through the player's build status check and cost: the affordable building with the best value for its price (two weeks of troops from a dwelling, upgrades, two weeks of income, spells, buildings it opens up). A town that musters little favors dwellings.
- When a build or a recruit order is short, a town with a market trades for the difference with the human's quotes (`TownRules.market_trade_quote`, which covers every resource including rares): spare wood and ore convert first, then other spare resources, gold buys the rest, spare resources sell when gold is short, and the weekly usage and caps are recorded the same way as the human's orders.
- Income is the human's: owned towns, controlled sites and artifacts. Generated native maps give computer players the same opening stockpile the human gets. No pillage, no abstract siege capture, no pressure-driven spawns. Difficulty only changes what `DifficultyRules` defines for the enemy side (battle knobs).
- Enemy pressure is still read by scenario conditions, the command risk forecast and battle outcome adjustments, but nothing raises it any more: each computer turn resets it to 0.

## Save migration

- `EnemyTurnRules.normalize_enemy_states` runs `AiHeroRules.migrate_legacy_raids` once per save (`overworld.ai_heroes_version = 1`; new sessions are created with the marker). It is skipped while a battle is pending, because the battle refers to its armies as they are.
- A raid host with a commander becomes a hero: it keeps position, army, level and experience, gets the template's movement and a fresh goal, and drops every raid target field. A commanderless column joins a hero of its side within 3 tiles; troops that do not fit go to the side's nearest town garrison (or are lost if it owns none).
- Each computer turn also converts any host a scenario script placed later. Old pressure, raid counters and task boards stay in the enemy state but no longer drive anything.

## Player-facing text

"Raid" no longer appears in player-facing text: threat lines, briefings, town threat summaries, battle names and enemy activity summaries talk about enemy heroes and armies.

## Performance

Searches use flat byte masks per level: static blocking and site stops are built once per enemy turn and shared by all computer players; armies, guards and heroes are added per search. The search radius is three days of movement (seven when nothing is in reach). Fight previews are skipped at a 3x margin and the previewed battle is reused for the fight.

- `large_generated_map_runtime_profile_report`, one end turn: the rules part went from 1782 ms (raid model) to 903 ms; the whole confirm is dominated by the autosave (3991 ms before, 3779 ms after).
- `AI_PLAYER_RULES_REPORT` perf mode, `homm3_large`, three computer players, 21 days: the AI part of an end turn is 0.4 to 1.6 s on most days and 4.2 s at most (a day with five fight previews and five battles), against `END_TURN_LIMIT_MS` 15000. A preview costs 0.1 to 0.4 s with large armies, which is the main cost to watch.
- Guard valuation by what a fight opens and costs (2026-10-07), same perf run: median 1.2 s against 0.8 s before, worst day 3.0 s against 2.3 s. The computer players fight about twice as often (32 battles and 38 previews against 17 and 15); measuring the ground behind guards adds about a third to decision time outside previews.

## Tests

- `tests/ai_player_rules_report.gd/.tscn`: a small generated skirmish played 16 days. An AI hero captures mines, AI heroes beat guards through auto-resolve, an AI town builds and recruits with the treasury actually reduced, wood and rare purchases match the human's market quotes, no raid entities or raid wording exist, heroes walk more than two tiles a day and none stands still away from its towns for four days, a legacy raid migrates (level and troops kept; a commanderless column's troops go to the garrison) and the state survives a save round trip. A second case regenerates the map of the owner's 2026-10-07 playthrough (seed 579873210) and plays the computer player 28 days with the human idle at home: it has to explore at least 560 of 1296 tiles, beat 4 guards and hold 10 sites with no hero idle in the field for four days. The old scoring reproduced that game there (486 tiles, 2 guards, 6 sites, its main hero stuck in a dead end for 14 days); now it is about 625 tiles, 7 guards and 16 sites. `HEROES_AI_RULES_PERF_SIZE`/`HEROES_AI_RULES_PERF_DAYS` switch it to a timing run; `HEROES_AI_RULES_CAPTURE_DIR` (with a window) saves an overworld capture of the strongest AI hero.
- Raid-model AI scenes are updated to hero behavior: live turn execution, known-world memory (scouting instead of exploration raids), assault grouping (column joins a hero, lesser hero hands troops to the main hero, also after walking), multi-scenario recruitment delivery (recruits reach hero armies via the garrison) and the strategic AI KPI generated-map probe (heroes fielded and objectives taken).
- `HeadlessSimulationHarnessRules` cases are all hero cases now: live turn, route progression, town build and recruit over three days, town retake assault, assault grouping and recruitment delivery, plus the rewritten raid cases: every enemy faction of each authored scenario fields a working hero (pressure coverage); a strong hero assaults the human town (objective targeting); an understrength hero reinforces from its garrison before fighting (regroup); the main hero holds the gate of a threatened town (town defense, single and multi-scenario); a lost site is retaken (resource-site defense). The fixtures pin the session id, because the AI tavern offers are seeded from it and it otherwise comes from the start time.
- The raid director's unit-level tests (task board, commander roles, raid regroup and defense retasks, adventure spells, empire economy runways, raid path plan reuse) were deleted with it. `tests/validate_repo.py` `validate_ai_hero_model` pins the hero-model owners and keeps the raid entry points out.

## Known gaps

- Heroes stay on their map level: native two-level transit is not used yet. AI heroes do not use boats, shipyards or whirlpools yet; water stays impassable for them even though the human can sail (`docs/water-travel.md`).
- Heroes do not plan around scenario objectives; they only value what is on the map. Three `validate_repo` pins for objective types (Great Work, Twin Command, relief routes) look for that in `AiHeroRules` and fail until it exists.
- Heroes do not cast adventure spells (movement or scouting), do not hunt the human's reinforcement convoys and do not send convoys of their own.
- All factions share one decision model. The per-faction strategy weights and priority targets in scenario enemy configs are not read.
- Artifacts are valued flat: set pieces and faction regalia are worth no more to the faction they belong to.
- Skipping the fight preview at a 3x power margin can still lose a fight; a harness run saw a hero lose to the guard it did not preview. The loss estimate is below what this game's battles cost (a guard at 1.6x would have cost more than 40% of the army, where the square law says 23%); the preview corrects it, so a hero whose every exit needs a costly fight waits for its army to grow.
- Lesser heroes hand over all but one creature and then wait at home to carry the next recruits; they do not keep a fighting force of their own.
- Inert until the owner decides (keep, retarget or remove): Border Warden's `raid_pillage_resistance` and `HeroProgressionRules.scale_raid_pillage`, and the `DifficultyRules` enemy pressure and raid knobs (`enemy_pressure_bonus`, `raid_threshold_offset`, `raid_pillage_multiplier` and their adjust/scale functions). Two forecasts still read them, the public pressure gain (`OverworldRules._public_enemy_pressure_gain`) and the raid threshold in the command risk forecast (`EnemyTurnRules._raid_threshold_for_strategy`), and neither predicts anything real now.
