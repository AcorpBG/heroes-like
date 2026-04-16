# heroes-like (working title)

Task: #10184

## Vision
Create a full-featured, commercially credible, turn-based fantasy strategy game inspired by the exploration, army management, town growth, map control, and tactical combat loop of Heroes of Might and Magic II, while being legally and creatively its own thing.

## Product pillars
1. Adventure map exploration with strong discovery and risk-reward pressure.
2. Tactical turn-based battles with meaningful terrain, army composition, morale-style effects, and hero influence.
3. Town development, recruitment, resource gating, and strategic expansion.
4. Strong single-player experience first: skirmish, handcrafted maps, campaign framework, AI opponents, save/load, difficulty levels.
5. Production-ready foundations: content pipeline, testing strategy, deterministic simulation where useful, packaging, settings, telemetry/logging hooks, and mod-friendly data boundaries where practical.

## Release bar
A release-ready v1 should include:
- original world, factions, heroes, units, buildings, spells, and map objects
- stable adventure map loop
- stable tactical combat loop
- campaign + skirmish support
- usable AI for world and battle play
- save/load reliability
- settings, audio, UX polish, onboarding, and packaging
- QA-ready architecture and repeatable content authoring workflow

## Non-goals for now
- multiplayer-first architecture
- direct recreation of copyrighted assets or exact game data
- endless engine churn before implementing core systems

## Engine and stack decision
Decision date: 2026-04-14

The project is locked to the Godot 4 stable series for the first production foundation and early vertical slices.

Stack choice:
- engine: Godot 4, 2D-first rendering and UI
- gameplay language: GDScript
- authored content: JSON files checked into `content/`
- runtime saves: JSON snapshots and campaign progression profiles under `user://saves/`

Rationale:
- Godot 4 gives fast iteration for a strategy game built around scene composition, tool scripts, and UI-heavy flows.
- GDScript keeps gameplay code editor-native and lowers integration friction while the core simulation architecture is still taking shape.
- JSON content keeps faction, unit, scenario, and encounter data diffable, reviewable, and mod-friendly.
- If native performance hotspots emerge later, GDExtension can be added surgically without replacing the baseline stack.

## Core architecture
- App layer: a boot scene plus autoload services for content loading, scene routing, save/load, and active session state.
- Domain layer: typed gameplay scripts for overworld state, tactical battle state, serialization, and content validation. Rules should live here instead of in scene scripts.
- Presentation layer: menu, overworld, town, and battle scenes that render session state and issue intents back into the domain layer.
- Data boundary: authored content is immutable at runtime and referenced by stable ids; save data stores only mutable session state plus content references.
- Runtime rules: scenario bootstrap now lives in `scripts/core/ScenarioFactory.gd`, hero-roster/tavern/transfer simulation in `scripts/core/HeroCommandRules.gd`, overworld rules in `scripts/core/OverworldRules.gd`, town visit/state presentation in `scripts/core/TownRules.gd`, tactical combat rules in `scripts/core/BattleRules.gd`, artifact/equipment simulation in `scripts/core/ArtifactRules.gd`, spellbook and spell resolution in `scripts/core/SpellRules.gd`, authored objective resolution in `scripts/core/ScenarioRules.gd`, authored trigger/effect processing in `scripts/core/ScenarioScriptRules.gd`, campaign progression/carryover resolution in `scripts/core/CampaignRules.gd`, difficulty tuning in `scripts/core/DifficultyRules.gd`, hostile adventure targeting in `scripts/core/EnemyAdventureRules.gd`, hostile turn orchestration in `scripts/core/EnemyTurnRules.gd`, and tactical enemy decision scoring in `scripts/core/BattleAiRules.gd` so scene controllers remain thin.
- Save/load boundary: save snapshots are versioned and should preserve scenario progress, hero state, resources, current day, battle return context, and resolved encounters, while campaign unlock/completion/carryover state persists separately through `CampaignProgression.gd` and `SaveService.gd`.
- Save management boundary: `SaveService.gd` now owns structured expedition persistence through manual save slots plus autosave, save-slot metadata summaries for UI, and safe restore normalization before any controller resumes a session.
- Menu launch boundary: main-menu campaign starts and skirmish starts now share the same durable bootstrap through `ScenarioSelectRules.gd` plus `ScenarioFactory.gd`, while session `launch_mode` and `difficulty` persist in save data so skirmish replays of campaign-authored maps do not mutate campaign progression.
- Artifact ownership boundary: hero artifact state is canonicalized in `ArtifactRules.gd` as unique equipped-slot plus pack ownership, so pickups, swaps, scripted awards, and campaign carryover all collapse duplicate ids safely instead of multiplying relics across saves.
- Determinism stance: rules should avoid hidden frame-timing dependencies so later simulation tests and replay/debug tooling remain feasible.

AI decision:
- hostile overworld intent is now planned in `EnemyAdventureRules.gd`, with raids picking targets from towns/objectives and marching across the map instead of only ticking random pressure
- battle encounters can author optional enemy commanders with command and spellbook state, and `BattleAiRules.gd` evaluates spell casts, ranged attacks, melee pressure, and wounded-target focus before `BattleRules.gd` executes the chosen action

Town interaction decision:
- owned towns now open into a dedicated town scene, but town simulation stays in core rules so build, recruit, and study actions remain save-backed and testable
- town templates author spell libraries by tier, while building data authors mage-guild style progression through `spell_tier`, letting town development feed directly into hero spellbook growth without scene-owned spell logic

Town progression decision:
- faction and town templates now author identity, economy, and recruitment profiles, while building data authors categories, upgrade chains, recruit discounts, and dwelling-specific growth bonuses
- weekly town musters now resolve in `OverworldRules.gd` from normalized built structures plus authored faction/town modifiers, and older saves normalize into the richer build tree without changing save version `9`

Town outlook decision:
- the town shell now surfaces a persistent defense-outlook and dispatch-readiness board shaped in `TownRules.gd`, using visibility-safe hostile pressure, live wall strength, hero coverage, logistics, recovery, and response-order state instead of a planner, tutorial, or codex layer
- public raid visibility stays shared with `OverworldRules.gd`, while all mutation for response, recovery, transfer, build, and recruit actions remains in `scripts/core` so save behavior and save version `9` stay unchanged

Town order-readiness decision:
- the town shell now also surfaces a persistent order-readiness ledger shaped in `TownRules.gd`, ranking build, recruit, response, and wall-coverage consequences from live town state instead of a planner, advisor, or codex layer
- `OverworldRules.gd` now exposes exchange-aware town cost readiness from current reserves plus authored market rates, while `TownShell.gd` only binds the new ledger panel and existing action buttons so all mutation stays in core and save version `9` remains unchanged

Hero command decision:
- player command now persists as a core-owned roster under `overworld.player_heroes` with a mirrored `active_hero_id`, so save/load, battle entry, and campaign carryover can switch heroes without scene-owned mutation paths
- additional authored faction heroes are recruited through `HeroCommandRules.gd` from Wayfarers Hall availability, while town garrison transfer, secondary-hero defeat cleanup, and primary-hero carryover all reuse the same core normalization path

Fog and scouting decision:
- overworld visibility now persists in save-backed fog state under `overworld.fog`, separating current visibility from long-term explored memory so old saves can normalize in place without a save-version bump
- scouting radius is aggregated in core from hero progression plus equipped artifacts, with every controlled hero contributing reveal coverage and `OverworldShell.gd` only surfacing map objects, ownership, and scripted reveal details when tiles are currently visible

Scenario scripting decision:
- handcrafted scenarios now author declarative `script_hooks` inside `content/scenarios.json`, with reusable condition/effect evaluation living in `ScenarioScriptRules.gd` instead of one-off scene callbacks
- hook execution is durable across saves through a save-backed fired-hook log plus event history in session state, so campaign rewards, spawned threats, town mutations, and authored progress beats stay deterministic and testable

Campaign progression decision:
- authored campaign structure now lives in `content/campaigns.json`, with chapter unlock requirements plus carryover import/export rules defined in content instead of scene controllers
- menu start flow routes through `CampaignProgression.gd`, while `CampaignRules.gd` applies unlock checks, records chapter completion, and injects carryover resources, hero progression, spellbook state, artifacts, and exported flags into downstream scenarios
- the release-facing main-menu campaign shell now uses browser/detail models from `CampaignProgression.gd` plus `CampaignRules.gd`, and active campaign sessions stamp explicit campaign/chapter flags so save summaries stay correct even if authored scenarios are reused later
- the authored package now includes multiple three-chapter campaign arcs, so release-facing content breadth lives in `content/campaigns.json` plus `content/scenarios.json` rather than hidden menu branches or special-case launch code

Artifact inventory decision:
- `ArtifactRules.gd` now owns duplicate-safe inventory normalization, slot-aware equip/swap/unequip behavior, and direct artifact-claim handling for pickups, scripted rewards, and campaign carryover
- town and overworld scenes only render rule-provided inventory descriptions/actions, so hero equipment management stays runnable without pushing artifact state logic into controllers

Save management decision:
- `SaveService.gd` now exposes three manual expedition slots plus an autosave track, and every save browser row is derived from service-owned metadata instead of controller-owned formatting
- resume flow now restores through normalization/validation helpers that reject missing scenarios, tolerate older payloads, and degrade broken battle or town state back to a safe overworld resume path
- save files now stamp service-owned timestamp and route metadata, letting slot inspection and latest-save selection fall back to recorded save time instead of trusting file metadata alone
- restore now re-reads live slot state before loading, hard-fails saves missing core expedition payload, and marks partial field recovery explicitly so broken saves do not silently half-load
- the main menu now lists available saves with scenario, campaign chapter, hero, integrity, resume target, and loadability state instead of assuming a single blind `slot1.json` continue path

In-session save controls decision:
- runtime expedition saving now routes through `SaveService.gd` plus `AppRouter.gd`, with active-session helpers that sanitize battle, town, overworld, and resolved-outcome snapshots before writing manual slots or autosave
- overworld, town, battle, and outcome shells only bind slot pickers, buttons, and status labels, while the service owns save-surface copy such as latest-ready context, manual-slot intent, and return-to-menu resume hints
- menu continue and targeted load now also route back through `AppRouter.gd`, keeping restore, resume-target routing, and main-menu return notices on the autoload side instead of scattering save-resume decisions across scenes

Presentation and onboarding decision:
- release-facing device settings now persist through `SettingsService.gd` under a dedicated user config path, staying separate from campaign progression profiles and expedition save snapshots
- presentation, audio, and accessibility formatting live in the service, while `MainMenu.gd` only binds the controls and refreshes state from service-owned summaries
- the main menu now keeps play on one dominant war-table board while guide, settings, and save inspection sit in a tucked utility wing, so secondary actions stay available without reading like a tabbed dashboard

Front-end shell presentation decision:
- `MainMenu.tscn` now centers on one dominant play board with a drawn hero stage, a short front brief, side-by-side campaign and skirmish launch surfaces, and a narrow command wing for continue, saves, guide, and settings instead of a repeated-navigation dashboard
- `MainMenu.gd` still only binds campaign, skirmish, help, settings, and save data from the existing rule and autoload helpers, so launch behavior and resume flow stay unchanged while the front end pushes primary play choices forward and tucks secondary actions away

Outcome flow decision:
- resolved scenarios now route into a dedicated `ScenarioOutcomeShell` instead of dropping straight back to the menu, with summary shaping in `ScenarioRules.gd` and campaign-specific consequence modeling in `CampaignRules.gd`
- campaign outcomes now surface recorded chapter state, downstream unlock or blocker status, and carryover import/export recap from the real progression profile, while skirmish outcomes remain self-contained and do not mutate campaign data
- the router overwrites autosave with the resolved session snapshot before showing the outcome shell, keeping restart and recap state durable without bumping save version `9`

Outcome shell presentation decision:
- `ScenarioOutcomeShell.tscn` now uses a visual result banner with outcome-specific palette, recap cards, carryover and chronicle panels, and clear follow-up CTA rows instead of a single long text dump
- `ScenarioOutcomeShell.gd` only applies the result palette and binds rule-owned recap plus save-surface summaries, keeping campaign and skirmish consequence logic in `ScenarioRules.gd`, `CampaignRules.gd`, `SaveService.gd`, and `AppRouter.gd`

Campaign narrative surfacing decision:
- release-facing chapter briefing, intel, stakes, aftermath, and chronicle text now lives in authored `content/campaigns.json` chapter entries and scenario metadata fallbacks, keeping campaign voice on the same content boundary as unlocks and carryover instead of adding a separate lore or codex subsystem
- `CampaignRules.gd` now shapes chapter-detail, campaign-detail, journal, and aftermath summaries from the real progression profile, while `ScenarioRules.gd` and `ScenarioSelectRules.gd` provide skirmish-safe briefing and aftermath fallback from existing scenario selection or objective data
- `MainMenu.gd` and `ScenarioOutcomeShell.gd` only bind those rule-owned summaries into the existing campaign browser and result shell, so narrative continuity stays save-safe, chain-aware, and scene-thin without changing save version `9`

Campaign arc completion surfacing decision:
- authored `content/campaigns.json` now carries campaign-level arc goals plus finale-completion titles and epilogues, so campaign closure is expressed on the same content boundary as chapter unlocks and carryover rather than through hardcoded UI flavor
- `CampaignRules.gd` derives campaign-complete state, finale replay defaults, closing command snapshots, and outcome-shell arc summaries from existing campaign records only, without adding duplicate progression state or changing save version `9`
- `MainMenu.gd` and `ScenarioOutcomeShell.gd` only bind dedicated arc-status labels from `CampaignProgression.gd` and `ScenarioRules.gd`, keeping the existing browser and outcome flow release-facing while scenes remain thin

Selection preview decision:
- pre-battle commander previews now stay inside the existing campaign browser and skirmish setup shell by deriving temporary preview sessions from `ScenarioFactory.gd` plus real campaign carryover in `CampaignRules.gd`, rather than adding a separate roster app or planner subsystem
- `ScenarioSelectRules.gd` owns the preview shaping for commander identity, command stats, battle traits, battle spellbook, artifact loadout, opening army mix, and expected battlefield posture, all sourced from current hero, army-group, spell, artifact, encounter, and scenario data boundaries
- `MainMenu.gd` only binds dedicated preview labels for campaign chapters and skirmish fronts, so selection UX feels release-facing while save-backed simulation state remains canonical in `scripts/core` and `SAVE_VERSION` stays at `9`

Operational board decision:
- prelaunch battlefield-intel now stays inside the existing scenario-selection and campaign-browser flow, with `ScenarioRules.gd` shaping a shared operational board from real scenario sessions instead of adding a codex, planner, or fake cutscene system
- the board derives terrain mix, enemy pressure cadence, raid thresholds, priority targets, opening objectives, likely first-contact encounters, battlefield tags, enemy doctrine, and reinforcement hooks from the current `content/scenarios.json`, `content/encounters.json`, difficulty profile, and bootstrap state
- `CampaignRules.gd`, `ScenarioSelectRules.gd`, and `MainMenu.gd` only route those rule-owned summaries into dedicated launch-preview labels, keeping battle and overworld state canonical in `scripts/core` while making chapter or front start flow feel like a shipped strategy product without changing save version `9`

Scenario-start command briefing decision:
- fresh scenario launches now surface a one-shot first-turn command briefing inside the existing overworld shell, not through a tutorial engine, planner app, or cutscene layer
- `OverworldRules.gd` owns the briefing state and summary shaping from live day-one runtime data including objectives, scouting reveal, nearby towns, logistics sites, enemy posture, and immediate context actions, while `ScenarioRules.gd` only contributes shared objective and first-contact helper text
- `OverworldShell.gd` and `.tscn` only bind the dedicated briefing panel and persist the consumed one-shot state back through autosave so routine resume paths do not replay the same opening guidance, while `SAVE_VERSION` stays at `9`

End-turn risk forecast decision:
- the existing overworld shell now surfaces a live next-day command-risk forecast and gates `End Turn` behind a one-shot warning only when the current posture is materially risky, instead of adding a planner, advisor, or tutorial subsystem
- `OverworldRules.gd` owns the forecast state and summary shaping from current hostile pressure, raid targets, scouting visibility, town readiness, logistics disruption, objective watches, and exposed field posture, so the shell only binds forecast text and acknowledgement flow while `SAVE_VERSION` stays at `9`
- `OverworldShell.gd` and `.tscn` only bind the added frontier-board forecast label plus the reused briefing panel title or text, and autosave the consumed warning state so resume flow does not spam repeat prompts for the same posture

Overworld command commitment decision:
- the existing overworld shell now surfaces a live command-commitment board that compresses immediate order, route pressure, hero coverage, and hold-cost consequences from the current runtime state instead of adding a planner, advisor, tutorial, or codex subsystem
- `OverworldRules.gd` owns the board and action-summary shaping from active context, logistics-site state, nearby towns, reserve-hero coverage, local threat visibility, and the existing command-risk forecast, while `ScenarioRules.gd` continues to supply only shared objective labels
- `OverworldShell.gd` and `.tscn` only bind the added commitment panel plus existing context-action tooltips, so player-visible command consequences deepen without moving simulation or save mutation out of `scripts/core` and while keeping `SAVE_VERSION` at `9`

Overworld logistics escort decision:
- existing logistics-site response orders now create hero-bound escort commitments on the same save-backed resource-node payload, persisting commander identity and route-security rating so town recruitment, recovery relief, pressure guard, and route-break fallout all read one canonical overworld state
- `OverworldRules.gd` owns the escort payoff shaping from the active commander plus current site profile, while `EnemyAdventureRules.gd` and `EnemyTurnRules.gd` contest that same state through higher raid priority and pressure swings when escorted routes are broken instead of through a separate advisor or logistics subsystem
- `OverworldShell.gd` and town response surfaces keep using the existing command actions and summaries, so the slice lands as real gameplay agency on current boundaries without moving mutation out of `scripts/core` or changing `SAVE_VERSION` from `9`

Town reserve-delivery decision:
- town reserve delivery now rides on the existing logistics-site response payload in `OverworldRules.gd`, reserving authored recruits from linked towns, projecting them toward pressured player towns or active field heroes, and resolving arrivals during the normal day-advance flow instead of adding a separate convoy or planner subsystem
- hostile denial stays on the same strategic path: `EnemyAdventureRules.gd` values active delivery manifests when choosing raids, scattered deliveries add pressure when routes are seized, and `EnemyTurnRules.gd` raises defense appetite around towns that are protecting live reinforcement lines
- `TownRules.gd` and existing overworld or town summaries only surface convoy state, load plans, and route outcomes from the shared logistics data, so player-facing delivery status stays thin-shell and save-safe while `SAVE_VERSION` remains `9`

Convoy interception decision:
- live frontline reserve routes now stay on that same logistics-site state, but hostile response escalates through existing raid encounters and battle routing instead of a separate convoy minigame, planner, or map layer
- `EnemyAdventureRules.gd` now scores active delivery lanes as real raid targets for towns and field heroes, `BattleRules.gd` carries delivery-route context into the existing battle start and outcome flow, and battle resolution now decides whether reinforcements arrive, turn back, or are intercepted before reaching the front
- `OverworldRules.gd` and the current town or overworld summaries expose holding, blocking, and route-reopen pressure from the shared delivery state, so interception risk stays legible on current command surfaces while `SAVE_VERSION` remains `9`

Enemy empire-management decision:
- hostile overworld factions now keep save-backed treasury and posture state in `EnemyTurnRules.gd`, reusing authored town income, build trees, recruitment discounts, and weekly musters to decide what enemy towns construct and where fresh troops go
- active raid encounters normalize into dynamic `enemy_army` payloads through `EnemyAdventureRules.gd`, letting enemy reinforcements materially change raid pillage pressure and downstream battle payloads without moving mutation into scene controllers or bumping save version `9`
- overworld threat summaries now report visibility-safe posture and known raid pressure instead of exposing exact hidden raid counts or internal enemy economy values

Strategic enemy contestation decision:
- hostile raids now broaden target selection through `EnemyAdventureRules.gd`, scoring authored towns, resource nodes, relic caches, neutral encounters, and threatened enemy-front towns instead of only marching on the player capital loop
- arrival resolution now mutates the same save-backed overworld state the player uses: resource and artifact nodes record who claimed them, neutral encounters can be marked contested or cleared, and seized relic ids feed back into enemy pressure and daily economy in `EnemyTurnRules.gd`
- overworld threat surfacing stays thin and visibility-safe by reading those core-owned state markers for denied sites, contested neutral fronts, and objective pressure rather than moving strategic logic into `OverworldShell.gd`

Town defense decision:
- hostile raid encounters now escalate into real queued town-defense battles once they reach a player town’s pressure range, reusing the existing encounter battle path plus battle-context metadata instead of inventing a parallel siege-combat system
- `BattleRules.gd` now supports defender commander sources for active heroes, stationed town heroes, and fallback town captains, allowing town defenses to resolve coherently even when the primary hero is elsewhere
- post-battle syncing now writes surviving raid hosts back into encounter or captured-town state, writes surviving defenders back into town garrisons and defending-hero armies, and turns town loss into durable overworld ownership changes rather than abstract pressure ticks

Hostile commander continuity decision:
- hostile raid encounters now carry durable `enemy_commander_state` payloads seeded from authored faction hero rosters plus existing encounter commander doctrine, so opposing overworld pressure reads as named enemy commanders instead of anonymous raid blobs
- `EnemyAdventureRules.gd` owns raid-commander assignment and normalization, `BattleRules.gd` reads and restores that same commander state for battle creation plus save-resume rebuilds, and post-battle sync writes surviving hostile commanders back into the encounter payload instead of resetting them to encounter-template defaults
- `OverworldRules.gd`, `EnemyTurnRules.gd`, and `TownRules.gd` only surface visibility-safe commander names and host labels from that shared encounter state, keeping scene controllers thin and `SAVE_VERSION` at `9`

Hostile commander recovery decision:
- hostile factions now keep a save-backed `commander_roster` inside `enemy_states`, with authored faction hero ids normalized into `available`, `active`, and `recovering` lifecycle entries instead of treating named commanders as disposable encounter labels
- standard enemy-turn raid spawns now require an actually available commander, active raids reserve that commander cleanly, and battle resolution feeds defeated or victorious hostile commanders back into the same roster through explicit recovery timing rather than instantly reusing the same officer
- `EnemyAdventureRules.gd`, `EnemyTurnRules.gd`, `BattleRules.gd`, and `TownRules.gd` reuse the current enemy-turn, battle, restore, and threat-summary flow so commander continuity remains on existing save boundaries, stays visible in frontier or town summaries, and preserves `SAVE_VERSION` at `9`

Hostile commander veterancy decision:
- hostile commander roster entries now also keep a save-backed battle record and derived veterancy signal on that same `enemy_states[].commander_roster` payload, so repeated deployments, enemy victories, and defeats shape later raids without inventing a separate progression subsystem
- `EnemyAdventureRules.gd` reuses `HeroProgressionRules.gd` to auto-resolve focused enemy specialties and command growth from recurring battle record, while `EnemyTurnRules.gd` reads that same commander state back into raid strength demand and future host quality instead of resetting every spawn to authored baseline
- `OverworldRules.gd`, `TownRules.gd`, and `BattleRules.gd` only surface compact veterancy labels and battle-record summaries from the shared commander payload, keeping UI legibility inside current shells and preserving `SAVE_VERSION` at `9`

Hostile commander target-memory decision:
- hostile commander roster entries now also keep save-backed `target_memory` on that same `enemy_states[].commander_roster` payload, recording remembered targets, front anchors, and repeated hero-or-town rivalries instead of inventing a separate diplomacy or meta-strategy subsystem
- `EnemyAdventureRules.gd` reuses the current raid-target pipeline to seed and normalize that memory from raid assignments plus battle context, and later target scoring reads the same memory back as a bias toward repeated towns, hunted heroes, and familiar fronts while still respecting current strategy weights and availability
- `EnemyTurnRules.gd`, `OverworldRules.gd`, `TownRules.gd`, and `BattleRules.gd` only surface compact commander-memory hints from that shared payload inside existing frontier, town, and battle summaries, keeping scenes thin and `SAVE_VERSION` at `9`

Hostile commander army-continuity decision:
- hostile commander roster entries now also keep save-backed `army_continuity` on that same `enemy_states[].commander_roster` payload, recording the commander-bound host’s current stacks, baseline strength, rebuild debt, and scar state instead of inventing a separate army-meta subsystem
- `BattleRules.gd` now feeds battle survivors and wipeouts back into that shared commander payload, `EnemyTurnRules.gd` spends current enemy-town recruitment on inactive commanders with rebuild debt through the same reinforcement loop, and `EnemyAdventureRules.gd` seeds later raid armies from the rebuilt host instead of resetting them to a fresh template army
- `OverworldRules.gd`, `TownRules.gd`, and `BattleRules.gd` only surface compact scarred, shattered, and rebuilding host hints from that shared payload inside existing frontier, town, and commander summaries, keeping UI legibility inside current shells and preserving `SAVE_VERSION` at `9`

Hostile town retake-front decision:
- towns now also keep save-backed `front` state on the existing overworld town payload, recording recent hostile town loss, contested stabilization windows, controlling faction responsibility, and anchor priority instead of inventing a parallel front-war subsystem
- `OverworldRules.gd` updates that same front state on town capture, enemy recapture, and hostile assault aftermath, while `EnemyTurnRules.gd` plus `EnemyAdventureRules.gd` read it back into raid targeting, garrison demand, build priorities, posture, and commander deployment so lost or endangered hostile towns create durable strategic pressure
- `TownRules.gd`, `OverworldRules.gd`, and `BattleRules.gd` only surface compact retake-front and stabilization hints from that shared payload inside current town, frontier, and assault summaries, keeping the map scenery-first, preserving save continuity on current boundaries, and keeping `SAVE_VERSION` at `9`

Captured-town pacification decision:
- towns now also keep save-backed `occupation` state on the existing town payload, recording hostile source faction, current pacification pressure, held local recruits, and last occupation event instead of inventing a separate governor or unrest subsystem
- `OverworldRules.gd` now seeds that state when the player captures an enemy town, advances it during the normal day-roll from current recovery and logistics support, and lets the existing hostile retake-front pressure slow clearance, while income, weekly growth, reserve access, and battle readiness all read the same pacification payload before a town behaves like a normal holding
- `TownRules.gd`, `OverworldRules.gd`, `EnemyAdventureRules.gd`, and save normalization only surface compact occupation clauses and target bias from that shared state, so hostile retake fronts remain the strategic anchor, player occupation stays legible on existing shells, and `SAVE_VERSION` remains `9`

Town shell presentation decision:
- the town scene now uses a sectioned management-shell layout with dedicated command, town hall, construction, recruitment, spellcraft, and logistics panels instead of a single stacked debug column
- `TownRules.gd` owns the release-facing summary shaping for town identity, construction ledgers, recruit reserves, stationed defenders, visibility-safe frontier pressure, and dispatch messaging, keeping `TownShell.gd` thin and save-safe
- local threat surfacing only reports visible raid counts exactly and falls back to fog-safe warnings for unseen hostile movement, preserving scouting and public-information boundaries even inside the town shell
- the town scene now also centers on a dedicated drawn citadel board with crest treatment, wall and district markers, and direct visual readouts for readiness, spell tier, logistics strain, and active management lanes instead of presenting town state as the first text column the player reads
- `TownShell.gd`, `TownShell.tscn`, and `TownStageView.gd` only translate current runtime state plus existing town actions into that visual board and compact summary cards, keeping build, recruit, study, transfer, response, save, and leave-town mutation paths in existing core rules

Overworld shell presentation decision:
- the overworld scene now uses a sectioned command-shell layout with a banner, command wing, frontier watch, active-context panel, and dedicated map column instead of a single stacked status dump
- `OverworldRules.gd` owns the release-facing summary shaping for objective boards, scout-net coverage, frontier watch, active-tile context, and dispatch messaging, keeping `OverworldShell.gd` focused on map rendering, actions, and routing
- local overworld threat surfacing stays fog-safe by summarizing only visible hostile contacts and visible enemy-held towns, while unexplored or unseen hostile movement remains abstract in the command shell

Overworld adventure-shell correction decision:
- the overworld scene now corrects course toward a fixed adventure-map shell inspired by the layout logic of Heroes II and III: one dominant central map board, compact top status chips, a framed HUD wing, and a single bottom command band instead of a general-purpose dashboard
- `OverworldShell.gd` and `.tscn` keep all current movement, context-action, save, and routing behavior, but secondary detail is now hidden behind HUD tabs while primary movement and order buttons stay in one obvious band
- placeholder visuals remain original and local, and `OverworldRules.gd` still owns every summary, risk, briefing, and context string so the presentation correction does not create a parallel gameplay layer or change save version `9`

Overworld visual-map decision:
- the overworld scene now renders through a dedicated drawn map-board control instead of a text-labeled grid, with terrain, towns, resource nodes, artifact caches, encounters, hero markers, route previews, and fog all presented as 2D board elements using local placeholder art
- `OverworldRules.gd` remains the owner of fog, context, movement, and interaction rules, while `OverworldShell.gd` and `OverworldMapView.gd` only translate current session state into visual tile rendering, tile selection, and movement intents so the presentation upgrade does not create a parallel simulation layer
- town and battle shells stay on their current presentation path in this slice, keeping the visual pass focused on the actively tested overworld without widening scope or changing save version `9`

Battle shell presentation decision:
- the battle scene now uses a sectioned command-shell layout with a banner, commander wing, initiative track, active-exchange panel, roster boards, and a dedicated orders footer instead of a stacked combat dump
- `BattleRules.gd` now owns the release-facing summary shaping for commander state, initiative flow, active and target stack context, outcome pressure, recent combat feed, and action guidance so `BattleShell.gd` only binds labels, buttons, and save controls
- active spell and status surfacing now stays in core through durable `recent_events`, effect-board summaries, and spell-action descriptions, preserving the existing rules architecture and save boundary without bumping save version `9`
- the battle scene now also centers on a dedicated drawn battlefield board with deployment cards, distance bands, objective markers, focus links, and turn-order chips so the current fight reads like a tactical board before it reads like a log
- `BattleShell.gd`, `BattleShell.tscn`, and `BattleBoardView.gd` only translate normalized battle payload state into that board plus compact tactical cards, keeping active-stack actions, spell casting, target cycling, save, retreat, and surrender flow inside `BattleRules.gd`

Shell density-family correction decision:
- the main menu, overworld, town, battle, and outcome shells now follow one denser strategy-game layout rule set inspired by Heroes III screen logic: one dominant play surface, one or two tight command rails, compressed chips or short summaries, and tabbed secondary detail instead of permanent report acreage
- `MainMenu.tscn`, `OverworldShell.tscn`, `TownShell.tscn`, `BattleShell.tscn`, `ScenarioOutcomeShell.tscn`, and `scripts/ui/FrontierVisualKit.gd` now coordinate around smaller chrome, shorter copy, and fixed-height shell framing so the screens read as one product family instead of a menu shell plus separate dashboard variants
- the shell smoke scenes now anchor to unique named nodes for each major board or action rail, so layout refactors can keep moving without brittle deep-path test coupling

Main-menu front-end correction decision:
- the main menu now corrects from a still-dashboard-like shell toward a Heroes-style front end: one broad war-table play surface, one obvious continue button, no duplicate nav, and secondary utility hidden in a compact wing instead of competing with launch choices
- campaign and skirmish remain fully live inside that single play board, with the existing browser, preview, difficulty, and start actions preserved but regrouped into larger selection surfaces and shorter text blocks rather than many equally weighted cards
- `MainMenuHeroView.gd` remains the menu art owner and `FrontierVisualKit.gd` still supplies the shared shell treatment, keeping the pass local to scene composition and UI copy density rather than widening into new art or gameplay systems

Shared shell visual-kit decision:
- `scripts/ui/FrontierVisualKit.gd` now owns the reusable panel, button, tab, list, slider, and compact-summary treatment used by the main menu, overworld, town, battle, and outcome shells instead of each scene carrying its own near-duplicate styling helpers
- `scenes/ui/FrontierBannerGlyph.gd` now provides lightweight drawn-code heraldry marks that can be dropped into banner rows across the converted shells, keeping the placeholder UI art original, local, and easy to iterate without widening the asset pipeline
- scene-specific art boards like `MainMenuHeroView.gd`, `OverworldMapView.gd`, `TownStageView.gd`, `BattleBoardView.gd`, and `OutcomeBannerView.gd` remain the owners of their larger compositions, while the shared kit only standardizes shell framing, copy density, and visual identity

Battle-start tactical briefing decision:
- fresh battle entry now surfaces a one-shot tactical briefing inside the existing battle shell, not through a tutorial engine, planner view, or codex subsystem
- `BattleRules.gd` owns the briefing state and summary shaping from live battle payload data including encounter identity, battlefield tags, commander doctrine, army mix, decisive targets, retreat state, and scenario objective context, while the briefing marker persists in the battle payload for save-safe resume behavior
- `BattleShell.gd` and `.tscn` only bind the dedicated tactical-briefing panel and autosave the consumed one-shot state so routine battle resumes do not replay the same opening guidance, while `SAVE_VERSION` stays at `9`

Battle risk and readiness board decision:
- the existing battle shell now surfaces a live tactical risk and readiness board, not through a planner, advisor, tutorial, or codex subsystem
- `BattleRules.gd` owns the board shaping from current initiative windows, commander mana and aura comparison, line cohesion stability, ranged-lane pressure, decisive target priority, scenario-objective urgency, and latest dispatch shift, while keeping every line derived from the current battle payload only
- `BattleShell.gd` and `.tscn` only bind the dedicated risk-board panel, so battle presentation deepens without adding duplicate simulation state or changing save version `9`

Battle objective pressure decision:
- authored encounters and scenario encounter placements now extend the existing battle payload with `field_objectives` for lane batteries, cover lines, obstruction lines, ritual pylons, supply posts, signal beacons, breach points, and hazard zones instead of creating a separate siege, planner, or advisor subsystem
- `BattleRules.gd` now also treats held `cover_line` and `obstruction_line` states as stronger live screen and breach geometry: screened ranged or guard stacks take heavier ranged mitigation, weak advances can stall at the held choke instead of always closing distance, commander exposure swings harder with lane control, and shell summaries stay derived from that same battle payload only
- `BattleAiRules.gd` mirrors those same live screen and choke states in action scoring, so enemies value protected ranged stacks, lane-holding guards, breach-capable advances, and exposed targets instead of treating authored terrain as flavor-only text
- the real battle shell continues to surface this through the existing header, status, pressure, context, briefing, risk, order-consequence, and spell-timing flows, keeping scenes thin and save version `9` unchanged

Battle order consequence decision:
- the existing battle shell now surfaces a live order-consequence board that compresses focused order, trade window, command tools, objective pull, and likely hostile reply from the current battle state instead of adding a planner, advisor, tutorial, or codex subsystem
- `BattleRules.gd` owns the read-only consequence shaping from current action availability, damage windows, retaliation exposure, active abilities, spell windows, field-objective pressure, scenario objective context, and likely hostile reply text sourced through `BattleAiRules.gd`
- `BattleShell.gd` and `.tscn` only bind the added consequence panel plus the richer existing action-button tooltips, so commander decision clarity deepens without moving simulation or save mutation out of `scripts/core` and while keeping `SAVE_VERSION` at `9`

Battle spell timing decision:
- the existing battle shell now surfaces a live spell-and-ability timing board that compresses ready spell windows, support payoff, protection needs, status follow-through, and hostile burst risk from the current battle state instead of adding a planner, advisor, tutorial, or codex subsystem
- `BattleRules.gd` owns the read-only timing shaping from current spell actions, active-stack ability windows, live status marks, vulnerable friendly lanes, and likely hostile reply text sourced through `BattleAiRules.gd`, while `SpellRules.gd` adds timing-aware spell summaries from the same battle payload so the real spell bar stays actionable
- `BattleShell.gd` and `.tscn` only bind the added timing panel, so commander decision clarity deepens without moving simulation or save mutation out of `scripts/core` and while keeping `SAVE_VERSION` at `9`

Battle surrender and pursuit decision:
- the existing battle shell now exposes surrender on the same action surface as retreat, and `BattleRules.gd` owns both preview text and resolution so withdrawal choices stay on the current battle path instead of creating a parallel subsystem
- retreat and surrender now produce different shared-world consequences in core rules: treasury or stockpile loss, post-battle army attrition, hostile pressure shifts, nearby-town recovery pressure, and durable `last_battle_aftermath` recap state that campaign and skirmish outcome flow can read directly
- town-defense lock behavior remains enforced through the existing `retreat_allowed` and `surrender_allowed` battle payload flags, while scenes stay thin and save version `9` remains unchanged

Battle exit aftermath decision:
- the existing battle, commander, convoy, town-front, and outcome paths now also distinguish orderly withdrawal, surrender, and outright collapse instead of treating every non-victory exit as the same retreat-shaped scar
- `BattleRules.gd` now routes retreat into pursuit losses and partial convoy scatter, surrender into tribute plus intact convoy capture, and defeat or town loss into rout-level pressure, treasury seizure, and commander momentum, while `OverworldRules.gd` keeps those scars on current enemy-state, resource-node, town-recovery, and town-front payloads without a save-version bump
- `ScenarioRules.gd` and `CampaignRules.gd` only surface the richer core-owned `last_battle_aftermath` recap lines for commander reaction, logistics fate, and front stabilization, so the same compact summaries stay legible across overworld return, outcome review, and save or restore continuity without adding new panels

Difficulty simulation decision:
- difficulty now resolves through `DifficultyRules.gd` from persisted `session.difficulty`, so campaign starts, skirmish starts, and restored saves all reuse the same rule profile without a save-version bump
- overworld difficulty now changes daily movement, economy/reward scaling, and hostile raid pressure, while tactical difficulty shifts initiative tempo and damage output through derived battle payloads instead of scene-owned conditionals

Tactical combat depth decision:
- authored unit mechanics now live in `content/units.json`, with battle stacks normalizing ability payloads in `BattleRules.gd` so unit archetype behavior stays data-driven and save-safe
- durable battle statuses now flow through the existing `SpellRules.gd` effect pipeline as effect ids plus modifier dictionaries, letting abilities like brace and harry interact with commander buffs, initiative order, retaliation, and damage scoring without adding scene-owned state
- `BattleAiRules.gd` now scores around reach, ranged harry setup, backstab exploitation, brace retaliation value, and shielding pressure, while `BattleShell.gd` stays thin by rendering rule-provided shell summaries, effect context, and action surfaces instead of re-implementing combat logic

Battle faction identity decision:
- Embercourt and Mireclaw battle asymmetry now remains an authored extension of the existing unit, spell, and AI systems rather than a separate faction-combat layer, keeping save and rules boundaries intact at save version `9`
- `content/units.json`, `content/buildings.json`, `content/towns.json`, and `content/army_groups.json` now author elite late-tier doctrine units and unlock paths, so Embercourt can build pike-backed firing lines while Mireclaw can escalate wounded-target collapse through the same roster/build tree model used elsewhere
- `SpellRules.gd` now supports faction attack-buff battle spells alongside existing damage and defense effects, letting authored spells like Lantern Phalanx and Bloodwake Drum feed the same durable modifier pipeline that unit abilities already use
- `BattleRules.gd` now derives faction doctrine payoff from live stack state, elite-ability support, and late-fight pressure windows for initiative and damage timing, while `BattleAiRules.gd` mirrors those rules plus buff and status synergy scoring so faction identity materially changes combat resolution instead of only changing shell copy

Battle variety and commander-context decision:
- authored battle variety now extends through `content/encounters.json` plus `content/army_groups.json` with explicit `battlefield_tags`, specialized stack mixes, and commander-authored `battle_traits`, so repeated roster ids can still create materially different tactical puzzles without inventing a second encounter format
- `ScenarioFactory.gd` now carries player hero battle traits into session state, while `BattleRules.gd` normalizes commander traits and encounter tags directly into battle payloads so old saves can fall back to hero/encounter content without a save-version bump
- `BattleRules.gd` now applies terrain-tag and commander-trait modifiers to starting distance, stack attack/defense totals, initiative order, and damage trades, while `BattleAiRules.gd` mirrors those tags and traits for spell valuation, defend/advance preference, and target scoring so encounter context meaningfully changes battle resolution

Battle cohesion and momentum decision:
- tactical morale pressure now stays inside the existing battle stack state through save-safe `cohesion` and `momentum` values on stacks, with old saves normalizing through `BattleRules.gd` defaults instead of requiring a save-version bump or a separate morale subsystem
- casualty shocks, isolation penalties, commander traits, faction doctrines, terrain tags, and status effects all feed those values in `BattleRules.gd`, while `BattleAiRules.gd` mirrors the same cohesion and tempo model for target selection, defend value, and spell valuation so enemies understand breaks and recoveries instead of only raw damage
- authored unit abilities and battle spells now carry cohesion and momentum riders through the existing `SpellRules.gd` modifier pipeline plus `content/units.json` ability payloads, letting line-holding Embercourt forces stabilize and build disciplined tempo while Mireclaw packs snowball wounded-target collapses through the same data-driven combat architecture

Third playable faction decision:
- the release roster now includes Sunvault Compact as a third fully playable original faction, authored through the same `content/` domains as Embercourt and Mireclaw instead of adding any faction-specific runtime path
- Sunvault identity centers on support-heavy relay formations, positive-effect resonance, and elevated-fire payoff, with towns, buildings, units, heroes, army groups, encounters, scenarios, and a dedicated campaign arc all consumed through the current town, battle, skirmish, and campaign systems
- `BattleRules.gd`, `BattleAiRules.gd`, `TownRules.gd`, and `OverworldRules.gd` now read Sunvault doctrine and economy signals directly from existing faction, stack, and town payloads so town progression, hostile empire behavior, and tactical combat all stay data-driven without a save-version bump beyond version `9`
- validator coverage now treats Embercourt, Mireclaw, and Sunvault as the release-player faction set, enforcing third-faction build-tree depth, spell identity, hero spellbooks, encounter anchors, scenario entry points, and campaign/skirmish availability so regressions fail locally

Overworld logistics-site decision:
- neutral dwellings, faction outposts, and frontier shrines now extend the existing `resource_sites.json` plus `resource_nodes` pipeline instead of introducing a second overworld-object subsystem, keeping save normalization and scene flow inside the current `OverworldRules.gd` path at save version `9`
- persistent logistics sites now use the existing `collected_by_faction_id` and `collected_day` node state to model control, letting players and hostile empires reclaim the same site while one-shot caches still resolve through the old gather-once path
- `OverworldRules.gd` now converts controlled sites into recurring gold flow, weekly recruit musters routed into the nearest owned town, scouting reveal from outpost vision rings, and shrine spell-teaching for the active hero, while `EnemyTurnRules.gd` and `EnemyAdventureRules.gd` read those same site payloads for income, pressure, weekly musters, target priority, and denial behavior
- authored scenarios now place logistics sites directly into current campaign and skirmish maps, and validator coverage enforces the three site families, recurring logistics payloads, scenario placement breadth, and shared overworld-enemy rule hooks so strategic variety cannot silently collapse back to disposable caches

Hostile empire personality decision:
- hostile strategic identity now stays data-driven through faction-authored `enemy_strategy` payloads in `content/factions.json`, covering build-category weights, value weights, reinforcement bias, raid cadence, and target-family preferences instead of branching enemy logic by scene or special-case faction code
- authored scenario fronts can sharpen or redirect that baseline through `priority_target_placement_ids`, `priority_target_bonus`, and nested `strategy_overrides` on `enemy_factions`, letting the same faction behave differently on river crossings, relay fronts, siege roads, and logistics-heavy maps without inventing a second strategy system
- `EnemyTurnRules.gd` now reads those strategy profiles for build scoring, recruit ordering, garrison-versus-raid reinforcement, desired town strength, raid threshold spend, and public frontier-watch posture summaries, while `EnemyAdventureRules.gd` applies the same profiles to town, site, relic, encounter, and hero target scoring so hostile pressure stays legible and materially different across Embercourt, Mireclaw, and Sunvault

Hostile pursuit and town-assault decision:
- hostile raid hosts now cash in hero-hunt pressure through the existing enemy-turn and battle path: when a raid closes on a field hero outside a friendly town, `EnemyTurnRules.gd` switches command to the threatened hero and launches a real interception battle instead of leaving the threat as abstract pressure or optional player cleanup
- hostile-town capture now also cashes in through that same battle path: `OverworldRules.gd` routes defended enemy towns into a real assault battle via `BattleRules.gd`, and victory or stalemate resolve back into town ownership, defender sync, frontier-pressure shifts, and recovery fallout rather than an instant ownership flip
- encounter and town readability remain core-owned: `OverworldRules.gd` now shapes hostile-contact pressure text and defended-town context from live target, garrison, and approach state, while `OverworldShell.gd` only binds those summaries so scene controllers stay thin and save version `9` remains unchanged

## Data domains
The authored content boundary is now split into dedicated JSON domains under `content/`:
- `factions.json`
- `heroes.json`
- `units.json`
- `army_groups.json`
- `towns.json`
- `buildings.json`
- `resource_sites.json`
- `artifacts.json`
- `spells.json`
- `encounters.json`
- `scenarios.json`
- `campaigns.json`

Scenario authoring decision:
- `content/scenarios.json` now includes `selection` metadata for menu UX and launch validation, covering skirmish availability, campaign availability, browser summary text, recommended difficulty, map-size labels, and player/enemy faction summaries.
- hero-led starts now rely on authored scenario metadata plus core summary helpers rather than scene-owned strings, so campaign and skirmish selection can surface clearer commander identity without duplicating rules in controllers

Authored roster and scenario variety decision:
- hero templates now author `roster_summary`, `identity_summary`, `starting_specialties`, and `specialty_focus_ids`, with `HeroProgressionRules.gd` and `HeroCommandRules.gd` using that data to seed real progression bonuses and roster-facing summary text
- release content now targets three-faction playability through authored campaigns and skirmish fronts, expanding beyond the original Embercourt-only selection set without changing save version `9` or moving scenario logic into scenes
- validator coverage now enforces roster breadth, multi-faction campaign starts, skirmish-only front presence, and distinct lead-hero coverage so content regressions fail locally instead of quietly shrinking the playable package

Authored scenario identity decision:
- expanded chapters and fronts now differentiate pressure through additional encounter-clearing objectives, reactive hook conditions such as `objective_not_met`, raid-count checks, and hook dependencies, plus `add_enemy_pressure` effects and authored relief/counterattack spawns inside `content/scenarios.json`
- neutral-front and side-objective variety stays data-driven through `content/army_groups.json` plus `content/encounters.json`, while `ScenarioScriptRules.gd` owns the new trigger/effect behavior so scenes do not gain scenario-owned state mutation
- `OverworldRules.gd` now surfaces recent scripted beats as a scenario-pulse dispatch summary, keeping chapter-specific pressure legible to the player without moving authored event logic into controllers or bumping save version `9`

Content validation support decision:
- `ContentService.gd` now treats battle `attack_buff` spells, `encounter_resolved` objectives, and reactive scenario hook types such as `objective_not_met`, `active_raid_count_at_least`, `active_raid_count_at_most`, `hook_fired`, `hook_not_fired`, and `add_enemy_pressure` as first-class authored constructs instead of tolerated warnings
- `SpellRules.gd`, `ScenarioRules.gd`, `ScenarioScriptRules.gd`, and `EnemyTurnRules.gd` remain the owning runtime paths for those authored constructs, while `tests/validate_repo.py` now guards the validator/runtime parity so Godot headless validation stays materially cleaner without a save-version bump beyond `9`

Validator baseline realignment decision:
- `tests/validate_repo.py` now tracks the shipped shell and rules architecture directly, checking current scene nodes, helper functions, and `*Script` rule integrations instead of obsolete node names, stale class-token aliases, or compatibility-era UI expectations
- validator coverage remains meaningful by asserting current skirmish setup, outcome routing, difficulty hooks, logistics-site pressure, convoy interception, capital-front surfacing, and town-defense battle contracts, so local validation catches real architecture drift without forcing dead-path shims back into the product

Town asymmetry decision:
- town, faction, and building content now author late-game `pressure_bonus` and `readiness_bonus` signals alongside stronger economy and recruitment profiles, letting advanced works push either frontier leverage and defense readiness or wider raid pressure and faster raider musters without inventing a second town subsystem
- `OverworldRules.gd` now derives shared town metrics for reinforcement quality, battle readiness, and pressure output from current build trees, spell access, garrisons, and authored bonuses, so player-facing summaries and hostile empire logic read from the same state
- `EnemyTurnRules.gd` now values those outputs directly when choosing builds, reinforcing towns, and converting enemy-held towns into daily pressure, while `TownRules.gd` only surfaces the asymmetric payoff in the release-facing shell

Late-game capital escalation decision:
- major towns now stay data-driven through `content/towns.json` strategic roles plus faction-specific capital-project buildings in `content/buildings.json`, so capitals and anchor strongholds gain real late-war weight without creating a separate finale subsystem
- `OverworldRules.gd` normalizes strategic role, strategic summary, and active capital-project state from the same town/building graph already used for income, readiness, and recruitment, letting `TownRules.gd`, `EnemyTurnRules.gd`, and `EnemyAdventureRules.gd` read one shared source of truth
- hostile empire logic now folds those anchor states into build scoring, target selection, garrison demand, raid thresholds, active-raid caps, and public threat summaries, while finale scenarios trigger project activation through existing `ScenarioScriptRules.gd` hook effects such as `town_add_building`, `add_enemy_pressure`, and `spawn_encounter`

Capital logistics and raid recovery planning decision:
- strategic towns now author explicit `logistics_plan` payloads in `content/towns.json`, so capitals and strongholds require linked dwellings, outposts, and shrines through the same logistics-site family model already used on the overworld instead of a new support subsystem
- capital-project buildings now author `support_requirements`, `vulnerability_penalties`, and `recovery_guard` inside `content/buildings.json`, letting the existing `OverworldRules.gd` capital-project state turn broken anchor chains or recent raid damage into real readiness, pressure, recruitment, and recovery consequences
- `TownRules.gd` and `OverworldRules.gd` now surface those logistics impacts through build projections, capital-watch summaries, and logistics-watch text, while `EnemyTurnRules.gd` values added recovery relief on capitals and strongholds during build scoring so late-front planning stays inside core rules on both sides

Strategic response orders decision:
- player-side logistics recovery now reuses the same persistent resource-node and town state instead of adding a separate mission or minigame layer, with logistics-site `response_profile` payloads in `content/resource_sites.json` driving costs, watch duration, and payoff for route-secure, shrine-relight, outpost-repair, and similar actions
- `HeroCommandRules.gd` now owns the active-hero movement spend for field dispatch, while `OverworldRules.gd` records active response windows and recovery relief directly on resource nodes and towns so hostile raids, town summaries, and future save restores all read the same canonical state without a save-version bump beyond `9`
- town and overworld shells only surface core-provided response panels and actions, while `EnemyAdventureRules.gd` contests active response routes by prioritizing secured logistics sites and applying stronger disruption pressure when relief lines are overrun, keeping strategic agency and enemy denial inside the existing rules architecture

Town exchange gameplay decision:
- authored market buildings now stay inside the existing town economy path instead of adding a separate trading screen or merchant subsystem, with `building_market_square`, `building_river_granary_exchange`, and `building_resonant_exchange` opening exchange hall actions through `TownRules.gd` and the thin town shell
- `OverworldRules.gd` derives gold-to-resource and resource-to-gold rates from current market buildings plus existing faction or town economy profiles, so Embercourt river towns, Mireclaw stockades, and Sunvault relay cities trade on materially different terms without a save-version bump beyond `9`
- hostile treasuries reuse those same market helpers through `EnemyTurnRules.gd` when judging build affordability and liquidating surplus stock for construction, keeping player and enemy reserve conversion inside one shared core economy model

Capital-front battle identity decision:
- capital and stronghold fights now stay inside the existing battle payload by deriving `battlefront_tags` and summaries from authored town/faction context in `OverworldRules.gd`, so finale fronts gain fortress-lane, reserve-wave, battery-nest, and wall-pressure behavior without a parallel siege subsystem
- `BattleRules.gd` and `BattleAiRules.gd` read those shared tags plus authored encounter tags to change approach distance, initiative, cohesion, momentum, target preference, spell value, and late-wave payoff, keeping tactical differentiation in core rules instead of scene scripts
- finale scenarios now author signature reserve-column, breach-pack, and battery-array encounters in `content/encounters.json` plus scripted capital-project reinforcements in `content/scenarios.json`, so late-front battles become distinct authored puzzles rather than oversized field skirmishes

Screen-design correction decision:
- the next shell rework stage must start from descriptive wireframes and screen-fantasy targets instead of another density or panel-layout pass, because recent iterations proved that cleaner text columns still produce dashboard UX rather than game-screen UX
- `docs/screen-wireframes.md` is now the explicit source of truth for screen grammar across main menu, overworld, town, battle, and outcome, defining each screen's dominant surface, command rails, secondary-detail boundaries, and required art support before implementation resumes
- future shell work should only start after the target screen answers five gating questions clearly: dominant surface, first no-text read, primary command rail, secondary-info hiding strategy, and required generated-asset support

Main-menu scenic composition decision:
- the live main menu now follows one explicit scenic-front composition: a clean logo pocket in the upper-left, one shared lower-left stage dock over a large painted backdrop, a quiet footer pocket, and a far-right command spine for top-level actions instead of a dashboard board plus utility wing
- campaign, skirmish, saves, guide, and settings now all share one summoned `MenuTabs` stage dock that stays off the first view until a spine command requests it, while continue and quit remain direct spine commands
- the first-view menu surface now intentionally shows only the scenic stage, logo pocket, footer pocket, and readable command spine, with deeper launch, save, help, and settings detail opening as secondary overlays instead of permanent screen furniture
- the temporary backdrop art now lives locally under `art/ui/` and `MainMenuHeroView.gd` loads it at runtime, keeping the placeholder art local to the repo and the slice confined to menu presentation code rather than gameplay boundaries

Hostile-pressure save-hardening decision:
- `BattleRules.gd` now treats `hero_intercept` and `town_assault` as first-class restore contexts, rebuilding them from saved battle payload plus live hero or town anchors when older or degraded snapshots no longer carry the original encounter placement verbatim
- in-progress assault resumes now reassert the correct overworld anchor before the shell returns, keeping hostile towns hostile during active town-assault battles and keeping intercepted heroes selected when the player resumes a field interception
- `SaveService.gd` and `AppRouter.gd` now derive resume routing from the normalized live session rather than trusting stale scene-state metadata alone, and save-slot summaries surface the active battle name so autosave and manual-slot resume context stays legible without changing save version `9`

Core-systems regression correction decision:
- overworld turn advance is one-press again: the command-risk forecast remains informational, but `OverworldShell.gd` no longer gates `OverworldRules.end_turn()` behind a preview acknowledgement, so daily movement refresh, mana refresh, economy ticks, and hostile empire turns fire on the intended button press
- post-move interaction now resolves from core rules instead of waiting on extra scene commands for basic site flow: stepping onto claimable resource sites and artifact caches auto-resolves immediately, stepping onto hostile encounters auto-prepares battle and routes there, stepping onto owned towns routes into the town shell, and stepping onto hostile towns leaves them hostile instead of silently converting them into player-town visits
- battle opening and resume flow now drains enemy initiative windows through `BattleRules.gd` before the shell waits for player input, so enemy-first turn orders execute real AI actions instead of leaving the battle stalled on a non-player active stack

Live client validation decision:
- the repo now ships a dormant `LiveValidationHarness.gd` autoload that wakes only for explicit `--live-validation-*` CLI args, so a real Boot -> MainMenu -> skirmish launch -> OverworldShell -> TownShell -> BattleShell routed loop can be exercised through the actual app router instead of only through scene-instantiation smoke
- `MainMenu.gd`, `OverworldShell.gd`, `TownShell.gd`, and `BattleShell.gd` expose narrow `validation_*` hooks that call the same controller paths the live client already uses, letting automation select a skirmish, verify autosave state, route into a player town, take a real town-side order, route into a live encounter, resolve battle-side actions, and confirm routed return without bypassing core gameplay rules
- the same live harness now also proves a real routed save-resume path by saving from `TownShell.gd` into a manual slot, returning through `AppRouter.gd` to `MainMenu.gd`, loading that slot through the shipped save browser, and verifying the router lands back on the town surface with the same durable town-state signature
- `tests/run_live_flow_harness.py` now defaults to that richer town-and-battle flow, launches it with isolated `XDG_DATA_HOME`, writes repo-local screenshot plus JSON report artifacts under `.artifacts/`, and strengthens repeatable routed-client validation without changing save version `9` or normal player startup

This replaces the earlier mixed-content approach and gives towns, armies, recruitment, and battle setup stable ids that can scale into campaign, AI, and authoring tooling.

## Repository structure
- `content/`: factions, heroes, units, towns, buildings, spells, scenarios, and other authored gameplay domains
- `scenes/`: Godot scene assets for boot, menu, overworld, town, and battle
- `scripts/autoload/`: cross-cutting services with minimal UI knowledge
- `scripts/core/`: gameplay state, rules, and serialization helpers
- `scripts/ui/`: scene controllers for menus and shells
- `tests/`: reserved for future simulation and content validation coverage

## First foundation slice
Stand up a production-minded project skeleton with:
- boot flow into a main menu
- a real session bootstrap path for starting a scenario
- a real overworld shell with movement, turn advancement, and encounter hooks
- a real tactical battle shell with turn order, movement, attack resolution, and return-to-overworld outcome handling
- shared content loading and validation boundaries
- save/load scaffolding that survives scene changes
- original placeholder-safe content only
