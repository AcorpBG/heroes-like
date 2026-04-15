# PLAN.md

Task: #10184

## Strategy
We are building toward a full release-ready product, but we will do it in disciplined production phases instead of pretending the whole game appears in one pass.

## Locked stack
- engine: Godot 4 stable series
- gameplay code: GDScript
- content source of truth: JSON files in-repo
- save format: versioned JSON snapshots

## Architecture guardrails
- keep simulation and serialization logic outside scene controllers
- use stable content ids instead of embedding authored data in saves
- autoloads are for cross-cutting services, not for hiding gameplay rules
- preserve a clean split between overworld, battle, save/load, UI, and content pipeline
- each slice must remain compatible with eventual campaign, skirmish, AI, and packaging needs

## Phases

### 1. Preproduction and technical foundation
Difficulty: High
- lock engine and project structure
- define content/data formats and ids
- establish rendering, input, save/load, logging, config, and build pipeline
- define gameplay simulation boundaries for overworld and combat
- ship a runnable shell spanning boot, menu, overworld, battle, and persistence

### 2. Adventure map core
Difficulty: High
- tile/grid or node-based map model
- hero movement, fog of war, pickups, interactables, ownership, pathfinding
- map generation/import pipeline and scenario metadata
- resource economy and turn flow

### 3. Tactical combat core
Difficulty: Very High
- battlefield representation
- initiative/turn order
- movement, attack, retaliation, ranged rules, obstacles, spell effects
- battle AI and battle resolution flow

### 4. Towns, economy, progression
Difficulty: High
- faction definitions
- town screens and building trees
- unit recruitment, hero progression, spell systems, artifacts, resources

### 5. AI and content authoring
Difficulty: Very High
- adventure AI
- combat AI
- scenario scripting hooks
- authoring tools and validation for maps/content

### 6. Campaigns, UX, polish, release systems
Difficulty: High
- campaign progression framework
- menus, settings, audio, accessibility basics, onboarding
- packaging, QA passes, balancing workflow, bug triage

## Production sequencing
1. Build the platform layer once: boot, routing, content loading, persistence, config, and logging.
2. Add overworld capability on top of that platform with rules that are serializable and testable.
3. Add tactical battle capability with its own state machine and clear return path to the overworld session.
4. Layer economy, towns, progression, and richer content onto the same state boundaries.
5. Only then broaden AI, campaign tooling, and release polish around stable systems.

## Current slice acceptance criteria
- fresh boot reaches a main menu without editor-only steps
- starting a scenario enters an overworld shell backed by data files
- overworld state can trigger and return from a tactical battle shell
- current session can be saved and loaded through a stable service boundary
- scenario, encounter, and army-group content references resolve through stable ids
- authored content remains original and placeholder-safe

## Current integrated systems slice
- split authored gameplay data into dedicated domains for factions, heroes, units, army groups, towns, buildings, resource sites, encounters, and scenarios
- bootstrap sessions through core rule modules instead of scene-owned construction logic
- add overworld movement budgets, map-site interactions, town capture, daily economy, town growth, recruitment, and hero experience/leveling
- replace the one-stack battle shell with multi-stack tactical rules including initiative order, ranged vs melee actions, defense stance, retaliation, terrain distance pressure, and survivor sync back to the overworld army
- add authored scenario objectives plus explicit victory/defeat resolution state in saves and runtime session flow
- add the first enemy-faction overworld turn framework with pressure growth, spawned raid encounters, pillage, and siege pressure against player towns
- add hero artifact pickups, equipment slots, and save-backed bonuses that connect overworld movement/economy with battle attack, defense, and initiative
- add a first authored spell system with hero spellbooks, overworld casting, and tactical battle spell effects routed through core rules
- upgrade hostile AI with directed overworld raid targeting/movement and tactical battle decision-making around commander spells, ranged pressure, melee closing, and wounded-target focus
- add a dedicated town visit screen with simulation-backed build, recruit, and spell-learning actions plus mage-guild style building progression
- add a reusable scenario scripting/hooks layer with save-backed fired-state, authored trigger conditions, and map/reward mutations routed through core rules
- add the first authored campaign chain with durable chapter unlock state, menu start flow, and carryover bundles that feed later scenarios
- harden hero artifact inventory management with duplicate-safe ownership, swap-safe equipment flow, and lightweight hero-management UI in town/overworld
- replace the blind single-slot save flow with structured manual save slots, autosave boundaries, safe restore normalization, and a main-menu save browser that exposes real slot metadata
- add a distinct skirmish browser plus pre-launch difficulty setup using authored scenario-selection metadata and the same durable session bootstrap path as campaign starts
- make saved difficulty materially change overworld movement/economy/raid pressure plus tactical initiative/damage through a shared core rules profile
- add a multi-hero command layer with roster persistence, Wayfarers Hall recruitment, town garrison transfer, secondary-hero defeat cleanup, carryover-safe primary-hero import, and thin overworld/town command UI
- make exploration materially matter with save-backed fog-of-war memory, per-hero scouting coverage, visibility-gated overworld information, and thin map abstraction UI
- deepen tactical combat with authored unit abilities, durable battle statuses, and ability-aware enemy decisions while keeping the battle shell thin
- deepen faction identity and town progression with authored dwelling upgrades, weekly musters, economy profiles, blocker-aware construction, and thin town-shell surfacing
- broaden campaign progression with authored downstream chapters, explicit carryover context, and a release-facing campaign browser/detail shell backed by core rules
- add a release-facing settings, onboarding, and accessibility shell with persistent config kept separate from campaign and expedition data
- add a release-facing post-scenario outcome shell with real campaign/skirmish recap, carryover export surfacing, and follow-up actions
- deepen hostile overworld empire management so enemy towns build, recruit, reinforce garrisons, and feed stronger raid hosts through the same authored economy and growth systems as the player
- convert hostile town pressure into real defense battles so raids, sieges, and town loss resolve through concrete combat and overworld consequences instead of abstract takeover ticks
- harden the content pipeline so authored `attack_buff` spells, encounter-clearing objectives, raid-count conditions, objective-not-met checks, and enemy-pressure script effects validate cleanly through the same spell and scenario runtime rules that execute them
- polish the town shell into a release-facing management surface with authored identity, construction, recruitment, defense, and pressure summaries driven from core rules instead of a stacked debug readout
- polish the overworld shell into a release-facing command surface with objective boards, scout-net status, frontier watch, active-tile context, and dispatch summaries driven from core rules instead of scene-owned status strings
- polish the battle shell into a release-facing tactical surface with commander boards, initiative visibility, stack context, effect surfacing, event dispatch, and clearer action guidance driven from core rules instead of a stacked combat dump
- add a release-facing battle-side tactical risk and readiness board inside the real battle shell using current initiative, commander, cohesion, target, objective, and dispatch state instead of a planner or advisor layer
- add a release-facing battle spell-and-ability timing board inside the real battle shell using current spell actions, live statuses, support windows, protection needs, and hostile burst previews instead of a planner or advisor layer
- add authored battlefield control points and hazard objectives to encounters and scenario fronts so objective control changes initiative, ranged pressure, reserve timing, commander safety, and cohesion through the existing battle rules and shell surfaces
- harden release-facing save/load integrity with stronger slot metadata, explicit recovery/blocking rules, and clearer resume-state surfacing without breaking campaign, skirmish, or outcome boundaries
- push release-facing save controls into the active play shells so overworld, town, battle, and outcome use the same router-driven runtime-save and resume surface instead of trapping expedition persistence in the main menu
- broaden authored campaign content into a release-facing package with multiple campaign arcs, deeper chapter count, and richer carryover chains through the existing browser/start/outcome flow
- deepen authored scenario identity with richer side objectives, reactive counterattacks, relief hooks, faction-flavored neutral fronts, and dispatch-visible event pulses routed through existing core scenario systems
- deepen town progression and faction asymmetry with advanced buildings, stronger readiness-pressure tradeoffs, and late-game economic payoffs routed through the current town/faction systems
- deepen Embercourt and Mireclaw tactical combat identity with elite roster hooks, faction attack-buff spells, doctrine-aware initiative and damage hooks, and AI scoring that preserves the current battle rules architecture
- deepen battle encounter variety, commander identity, and terrain-context payoff through authored battle tags, specialized army groups, and commander-trait-aware battle rules without breaking the current architecture
- deepen tactical combat with persistent cohesion pressure, battlefield momentum, morale-aware spell support, and AI scoring that exploits breaks and recoveries without inventing a parallel battle layer
- deepen hostile empire personality and campaign-pressure variety with faction-authored strategy weights, scenario priority fronts, and legible frontier-watch summaries routed through the existing enemy turn and raid systems
- turn the new capital-logistics and recovery layer into active player-side strategy with movement-costed site responses, town recovery stabilization orders, and hostile denial pressure routed through the existing overworld, town, and hero-command surfaces
- turn authored market and exchange buildings into active town-side economy play with faction-aware trade rates, reserve conversion choices, and hostile treasury reuse routed through the existing town and economy rules
- add release-facing campaign briefings, aftermath debriefs, and persistent chronicle summaries through the existing campaign, scenario, selection, and outcome systems instead of a parallel lore codex
- add release-facing commander and loadout previews to campaign and skirmish selection through the existing hero, army, spellbook, artifact, and scenario data boundaries instead of a separate planner
- add a release-facing operational board to campaign and skirmish launch flow using existing scenario, encounter, battlefront, enemy, and objective data instead of a codex or fake cutscene
- surface authored campaign arc goals, finale completion epilogues, and completed-arc defaults through the existing campaign browser and outcome shell instead of falling back to generic completion copy or first-chapter replay
- add a release-facing first-turn command briefing to fresh overworld starts using existing scenario, objective, scouting, logistics, and threat data instead of a tutorial engine or planner layer
- add a release-facing battle-start tactical briefing inside the real battle shell using existing encounter, commander, doctrine, terrain-tag, objective, and live battle-state data instead of a tutorial or planner layer
- add a release-facing town-side defense outlook and dispatch-readiness board inside the real town shell using existing town, hero-command, logistics, recovery, and hostile-pressure data instead of a planner or advisor layer
- add a release-facing town-side order-readiness and affordability ledger inside the real town shell using existing build, recruit, market, response, and hero-command data instead of a planner or advisor layer
- add a release-facing overworld command commitment board inside the real overworld shell using existing context, logistics, hero-coverage, and frontier-risk data instead of a planner or advisor layer
- deepen overworld logistics agency with hero-bound escort and route-security orders that change musters, pressure guard, recovery fallout, and hostile raid incentives through the existing site-response path instead of a new subsystem
- turn town recruitment and reserve production into frontline reinforcement delivery through existing town, overworld, hero-command, logistics-site, and enemy-turn systems instead of a parallel convoy subsystem
- add a release-facing battle-side order consequence board inside the real battle shell using current action availability, damage windows, retaliation exposure, spell windows, objective pull, and likely hostile reply state instead of a planner or advisor layer
- turn battle withdrawal into a release-facing surrender and pursuit aftermath slice through the existing battle, outcome, town, economy, campaign, and shell flow so retreat and surrender produce different strategic fallout instead of sharing one generic exit path
- deepen tactical combat with authored battlefield cover lines, obstruction lanes, and firing-lane identities that change movement pressure, ranged threat, commander safety, target priority, and battle summaries through the existing battle pipeline

## Immediate execution order
1. Confirm engine, language, content, and save strategy in docs.
2. [completed] Scaffold the Godot project with production-minded folders, autoloads, and repository hygiene.
3. [completed] Implement boot flow and main menu shell.
4. [completed] Implement a minimal but real overworld shell backed by scenario data.
5. [completed] Implement a tactical battle shell backed by encounter data and shared session state.
6. [completed] Wire save/load plus scenario loading through versioned JSON snapshots.
7. [completed] Harden project boot config, scene shell flow, and scenario -> encounter -> battle content wiring.
8. [completed] Split content into dedicated gameplay domains and move scenario bootstrap into core rules.
9. [completed] Add overworld interactables plus a first town/economy/progression loop.
10. [completed] Replace the single-stack battle shell with multi-stack tactical combat rules and overworld army persistence.
11. [completed] Add authored scenario objectives and session-level victory/defeat handling.
12. [completed] Add a first enemy overworld turn framework with raid pressure and town-threat state.
13. [completed] Add hero artifacts, map pickups, and simulation-backed equipment bonuses.
14. [completed] Add a first spell system with save-backed hero spellbooks and real overworld/battle casting effects.
15. [completed] Upgrade hostile AI with directed raid movement, target selection, encounter-authored commanders, and spell-aware tactical battle choices.
16. [completed] Add a first dedicated town screen with visit actions, building inspection, recruit flow, and spell-learning access.
17. [completed] Add reusable scenario scripting hooks for authored rewards, events, and map-state mutations.
18. [completed] Add the first authored campaign chain with durable chapter unlock state, carryover bundles, and menu start flow.
19. [completed] Harden hero artifact inventory management with duplicate-safe ownership, swap-safe equipment flow, and thin hero-management UI.
20. [completed] Replace the blind single-slot save flow with structured manual save slots, autosave, and hardened restore validation.
21. [completed] Add a real main-menu save browser plus in-game manual slot selection around the new save-service APIs.
22. [completed] Re-run repository-local validation for save-browser scene wiring and save-management assumptions.
23. [completed] Add a release-facing skirmish browser, authored scenario-selection metadata, and a pre-launch difficulty setup without regressing campaign flow.
24. [completed] Re-run repository-local validation for skirmish metadata, launch-mode save summaries, and menu setup wiring.
25. [completed] Make saved difficulty materially affect overworld and tactical gameplay through `scripts/core` without regressing campaign/skirmish save compatibility.
26. [completed] Re-run repository-local validation for difficulty integration and save-compatibility assumptions.
27. [completed] Finish the multi-hero command slice with save-backed roster state, Wayfarers Hall recruitment, active-hero switching, transfer flow, and safe non-primary defeat handling.
28. [completed] Re-run repository-local validation for hero-command, tavern, transfer, and carryover assumptions.
29. [completed] Make multi-hero exploration matter with save-backed fog-of-war, per-hero scouting contribution, visibility-gated overworld context, and thin UI abstraction.
30. [completed] Re-run repository-local validation for fog/scouting rules, session normalization, and overworld UI wiring.
31. [completed] Deepen tactical combat with authored unit abilities, durable statuses, and ability-aware tactical AI while preserving hero, spell, artifact, difficulty, and specialty hooks.
32. [completed] Re-run repository-local validation for unit ability content, battle-rule status flow, and thin battle UI wiring.
33. [completed] Deepen town and faction progression with authored dwelling upgrades, weekly muster growth, economy profiles, and blocker-aware build rules without breaking save/campaign/skirmish compatibility.
34. [completed] Re-run repository-local validation for faction/town progression content, weekly-growth rules, and thin town-shell wiring.
35. [completed] Broaden authored campaign progression and replace the default-campaign button flow with a release-facing campaign browser/detail shell.
36. [completed] Re-run repository-local validation for campaign chapter metadata, browser hooks, and save-summary wiring.
37. [completed] Add persistent settings, onboarding/help surfacing, and accessibility shell controls through a dedicated autoload and release-facing main-menu tabs.
38. [completed] Re-run repository-local validation for settings persistence, onboarding hooks, and menu settings/help wiring.
39. [completed] Add a dedicated post-scenario outcome flow with campaign progression recap, carryover export surfacing, and skirmish retry/return actions.
40. [completed] Re-run repository-local validation for outcome routing, recap builders, and dedicated result-shell hooks.
41. [completed] Deepen hostile overworld empire management so enemy towns spend treasury on authored builds, weekly musters, and reinforcement priorities.
42. [completed] Re-run repository-local validation for enemy empire-management state, raid-army wiring, and public threat surfacing.
43. [completed] Convert hostile town pressure into real defense battles with raid-army carryover, garrison syncing, and town-loss consequences.
44. [completed] Re-run repository-local validation for queued defense-battle routing, post-battle town state, and raid survivor syncing.
45. [completed] Polish the town shell into a release-facing management view with defense watch, frontier pressure, recruit reserve detail, and clearer dispatch messaging.
46. [completed] Re-run repository-local validation for town-shell release polish hooks, layout nodes, and core summary wiring.
47. [completed] Add a second fully authored campaign arc with original scenarios, towns, encounters, and carryover wiring through the existing campaign systems.
48. [completed] Re-run repository-local validation for campaign breadth, second-arc content wiring, and browser-summary assumptions.
49. [completed] Polish the overworld shell into a release-facing command view with richer objective, scout-net, frontier, context, and dispatch presentation while keeping rules in `scripts/core`.
50. [completed] Re-run repository-local validation for overworld-shell release polish hooks, layout nodes, and core summary wiring.
51. [completed] Polish the battle shell into a release-facing tactical view with commander summaries, initiative visibility, active-stack context, effect surfacing, action guidance, and dispatch messaging while keeping rules in `scripts/core`.
52. [completed] Re-run repository-local validation for battle-shell release polish hooks, layout nodes, core summaries, and save-control wiring.
53. [completed] Harden release-facing save/load integrity with live slot reinspection, partial-payload guardrails, clearer loadability state, and stronger autosave/manual-slot metadata.
54. [completed] Re-run repository-local validation for save-integrity guardrails, save-browser state messaging, and restore-path assumptions.
55. [completed] Deepen hostile expansion so enemy raids contest authored sites, relics, neutral fronts, retake pressure, and objective anchors through save-backed core rules.
56. [completed] Re-run repository-local validation for strategic enemy contestation, persisted node metadata, and overworld threat surfacing.
57. [completed] Add release-facing in-session save controls, latest-save context, and safe menu-return resume flow across active play shells.
58. [completed] Re-run repository-local validation for router-driven save controls, active-shell wiring, and outcome save support.
59. [completed] Expand the authored hero roster with progression-seeded identities, broader faction coverage, and runtime summary surfacing through core rules.
60. [completed] Add a third campaign arc plus additional skirmish variety using current scenario content boundaries and thin selection-flow surfacing.
61. [completed] Re-run repository-local validation for authored hero metadata, multi-faction campaign starts, skirmish-only fronts, and lead-hero breadth.
62. [completed] Deepen authored scenario scripting, neutral encounter variety, and chapter-specific objective/event identity across the expanded campaign and skirmish fronts.
63. [completed] Re-run repository-local validation for reactive hook coverage, encounter-side-objective variety, and scenario-pulse surfacing.
64. [completed] Deepen town progression, faction asymmetry, and late-game economic payoff so Embercourt and Mireclaw towns build and fight differently through current town systems.
65. [completed] Re-run repository-local validation for advanced town works, asymmetric pressure-readiness outputs, and late-game build-tree coverage.
66. [completed] Deepen Embercourt and Mireclaw tactical combat identity with elite doctrine units, faction attack-buff spells, doctrine-aware initiative and damage hooks, and AI late-fight scoring.
67. [completed] Re-run repository-local validation for elite roster payloads, faction spell hooks, doctrine rules, and late-fight AI payoff coverage.
68. [completed] Deepen battle encounter variety, commander identity, and terrain-context payoff with battlefield tags, commander traits, specialized army groups, and context-aware AI/rules.
69. [completed] Re-run repository-local validation for battle tags, commander payloads, specialized encounter groups, and terrain-context combat scoring.
70. [completed] Deepen tactical combat with persistent cohesion pressure, battlefield momentum, commander-trait support, and morale-aware spell/unit interactions through the existing battle rules.
71. [completed] Re-run repository-local validation for cohesion state, momentum hooks, morale-aware spell content, and tactical AI scoring coverage.
72. [completed] Add a third fully playable original faction with authored towns, roster, heroes, encounters, scenarios, and campaign entry through the existing data-driven architecture.
73. [completed] Re-run repository-local validation for third-faction content, doctrine hooks, scenario entry, and full-system playability coverage.
74. [completed] Add authored battlefield control points and hazard objectives to the existing battle, encounter, and scenario systems so battle pressure resolves through real runtime state.
75. [completed] Re-run repository-local validation for battle-objective content, AI scoring, payload normalization, and battle-shell pressure surfacing.
74. [completed] Deepen overworld strategic variety with neutral dwellings, faction outposts, and logistics map objects through the existing data-driven content pipeline.
75. [completed] Re-run repository-local validation for overworld logistics sites, contestation hooks, and scenario placement coverage.
76. [completed] Deepen hostile empire personality and campaign-pressure variety with faction-authored strategy weights, scenario priority fronts, and summary surfacing through the existing enemy turn systems.
77. [completed] Re-run repository-local validation for faction-specific hostile strategy hooks, authored pressure variety, and hostile summary surfacing.
78. [completed] Deepen late-game capital pressure, stronghold escalation, and finale objective identity through existing town, enemy, and scenario systems.
79. [completed] Re-run repository-local validation for capital-project escalation, hostile finale pressure, and strategic-summary surfacing.
80. [completed] Deepen capital-front battle identity, siege-lane encounter depth, and finale assault variety through existing battle, scenario, town, and encounter systems.
81. [completed] Re-run repository-local validation for capital-front battle identity, finale assault content, and battle-summary surfacing.
82. [completed] Deepen capital-project planning, strategic logistics chains, and raid-recovery payoff through the existing town and overworld rules.
83. [completed] Re-run repository-local validation for capital logistics plans, project vulnerability data, and recovery-planning surfacing.
84. [completed] Turn the capital-logistics and recovery layer into active player-side strategic response orders through the existing overworld, town, hero-command, encounter, and logistics-site systems.
85. [completed] Re-run repository-local validation for strategic response orders, hostile logistics denial, and command-surface surfacing.
86. [completed] Turn authored market and exchange buildings into active player-side economy gameplay through the existing town and economy systems.
87. [completed] Re-run repository-local validation for town market actions, exchange-rate surfacing, and hostile treasury reuse.
88. [completed] Add release-facing campaign briefings, aftermath debriefs, and a persistent chronicle layer through the existing campaign, scenario, selection, and outcome systems.
89. [completed] Re-run repository-local validation for authored campaign narrative payloads, menu journal surfacing, and outcome-shell debrief hooks.
90. [completed] Add release-facing commander and loadout previews to campaign and skirmish selection through the existing core selection flow.
91. [completed] Re-run repository-local validation for commander-preview APIs, menu preview wiring, and save-version preservation.
92. [completed] Add a release-facing operational board and battlefield-intel preview to campaign and skirmish launch flow through existing scenario and encounter data.
93. [completed] Re-run repository-local validation for operational-board APIs, menu surfacing, and save-version preservation.
94. [completed] Add a release-facing first-turn command briefing inside the real overworld start flow using existing scenario, objective, scouting, logistics, and threat data.
95. [completed] Re-run repository-local validation for first-turn briefing APIs, overworld-shell surfacing, and save-version preservation.
96. [completed] Add a release-facing battle-start tactical briefing inside the real battle shell using existing encounter, doctrine, terrain-tag, target, and objective data.
97. [completed] Re-run repository-local validation for tactical-briefing APIs, battle-shell surfacing, and save-version preservation.
98. [completed] Add a release-facing end-turn / next-day command-risk forecast inside the real overworld shell using existing runtime pressure, logistics, scouting, readiness, objective, and frontier-watch data.
99. [completed] Re-run repository-local validation for command-risk forecast APIs, overworld-shell surfacing, and save-version preservation.
100. [completed] Add a release-facing town-side defense outlook and dispatch-readiness board inside the real town shell using existing runtime town, hero-command, logistics, recovery, and hostile-pressure data.
101. [completed] Re-run repository-local validation for town-outlook APIs, town-shell surfacing, and save-version preservation.
102. [completed] Add a release-facing battle-side tactical risk and readiness board inside the real battle shell using existing runtime battle, initiative, commander, cohesion, objective, and dispatch data.
103. [completed] Re-run repository-local validation for battle risk-board APIs, battle-shell surfacing, and save-version preservation.
104. Continue broader campaign content, town UX polish, and release-facing shell work on the same data boundaries.
- current item 104 focus: keep the main-menu Play tab genuinely usable at the default `1280x720` window by adding scroll-safe containment to the existing campaign/skirmish shell without removing release-facing launch context or changing the overworld start flow.
105. Record progress continuously and keep the repo runnable.
106. [completed] Add a release-facing battle spell-and-ability timing board inside the real battle shell using current spell actions, unit abilities, live statuses, protection needs, and hostile burst risk.
107. [completed] Re-run repository-local validation for battle timing-board APIs, shell surfacing, and save-version preservation.
108. [completed] Add a release-facing overworld logistics escort and route-security pass through the existing overworld, town, hero-command, and enemy systems.
109. [completed] Re-run repository-local validation for overworld escort-route APIs, hostile contestation, and save-version preservation.
110. [completed] Turn battle withdrawal into a release-facing surrender action with distinct retreat versus surrender consequences through the existing battle and campaign-state rules.
111. [completed] Re-run repository-local validation for surrender action wiring, pursuit aftermath, recap surfacing, and save-version preservation.
112. [completed] Remove the remaining content-pipeline warning gaps for authored `attack_buff` spells, `encounter_resolved` objectives, `objective_not_met` and raid-count conditions, and `add_enemy_pressure` effects through the existing validator and core runtime paths.
113. [completed] Re-run repository-local validation and Godot headless boot so those authored constructs pass without the prior warning spam and save version `9` remains unchanged.
114. [completed] Deepen tactical combat with authored battlefield cover lines, obstruction lanes, and firing-lane identities through the existing encounter, battle, and AI rules pipeline.
115. [completed] Re-run repository-local validation and Godot headless boot for battlefield cover, obstruction, lane-pressure summaries, and save-version preservation.
116. [completed] Turn town recruitment and reserve production into frontline reinforcement delivery through the existing town, overworld, hero-command, logistics-site, and enemy-turn systems.
117. [completed] Re-run repository-local validation and Godot headless boot for reserve-delivery routing, convoy surfacing, hostile disruption, and save-version preservation.
118. [completed] Turn live frontline reserve-delivery pressure into real convoy interception clashes through the existing overworld, encounter, battle, town, and enemy-turn systems.
119. [completed] Re-run repository-local validation and Godot headless boot for convoy-hunt targeting, battle-aftermath routing, interception surfacing, and save-version preservation.
120. [completed] Make the main-menu Play tab genuinely usable for playtesting at the default `1280x720` window through the existing campaign/skirmish scene and controller instead of replacing the release-facing menu flow.
121. [completed] Re-run repository-local validation, validator bytecode compilation, ops JSON parsing, `SAVE_VERSION` verification, and headless Godot boot for the main-menu playtest-usability slice.

## Standards
- no throwaway prototype code if avoidable
- prefer systems that can survive content scale-up
- keep simulation logic testable where practical
- document tradeoffs when choosing speed over purity

## Validation approach
- preferred: headless Godot import and smoke boot if a Godot 4 executable is available
- fallback: JSON validation, file integrity checks, and structural review when the engine is unavailable in the environment

## Current hardening notes
- keep project bootstrap assets present so first launch does not fail on missing config resources
- treat scenario encounter placements as references to authored encounter ids, not duplicated inline battle definitions
- normalize battle payloads on entry so old saves and scene resumes degrade safely instead of crashing
- keep scene controllers thin by routing scenario bootstrap, overworld interactions, and tactical resolution through `scripts/core/`
- save snapshots are now version `9`, with `SaveService.gd` managing three manual slots plus autosave, launch-mode plus difficulty summaries for UI, and restore normalization that safely downgrades broken battle/town state to overworld resume when possible
- logistics-site response orders now also carry escort commander identity and route-security rating on the existing resource-node state, so musters, pressure guard, disruption fallout, and hostile raid incentives stay on current overworld save boundaries without a version bump
- save/load hardening now records service-owned save timestamps and route metadata, re-reads live slot state before restore, blocks saves missing core expedition payload, and surfaces recovered versus blocked state clearly in the main-menu save browser without a save-version bump
- active-play save controls now route through `SaveService.gd` plus `AppRouter.gd`, so manual saves, autosaves, latest-save context, and return-to-menu resume hints stay consistent across overworld, town, battle, and outcome shells without moving persistence rules into scene controllers
- town progression now flows through a dedicated town scene backed by core rules, with build/recruit actions no longer jammed into the overworld context bar
- scenario scripting now resolves through declarative hook conditions/effects in core rules, so authored rewards, spawned encounters, and town mutations stay out of scene controllers and survive save/load
- campaign progression now expects authored `content/campaigns.json`, and repository-local validation derives required content files from `ContentService.gd` so missing content domains fail validation instead of slipping through
- overworld command surfacing now keeps immediate-order, route-pressure, coverage, and hold-risk language in `OverworldRules.gd`, with `OverworldShell.gd` only binding the commitment panel and context-action tooltips so save version `9` remains unchanged
- the main menu campaign flow now routes through a real browser/detail shell driven by `CampaignProgression.gd`, with authored chapter status, unlock blockers, retry state, and carryover context surfaced without moving progression logic into scene controllers
- release-facing settings now persist through a dedicated `SettingsService.gd` config path separate from campaign progression and expedition saves, while the main menu uses tabbed help/settings/saves shells instead of a raw dev-operations stack
- resolved scenarios now route through a dedicated outcome shell, with campaign recap state and skirmish retry flow shaped in core rules while autosave is updated to the resolved snapshot so stale in-progress resume paths do not stay front-and-center
- hostile empire turns now keep per-faction treasury and posture state in `EnemyTurnRules.gd`, normalize raid armies for legacy saves without changing save version `9`, and spend authored town income plus musters on building, garrisoning, and reinforcing raid hosts instead of only ticking abstract pressure
- hostile empire personality now resolves through faction-authored `enemy_strategy` payloads in `content/factions.json` plus scenario-authored `priority_target_placement_ids` and `strategy_overrides`, letting Embercourt, Mireclaw, and Sunvault diverge in build priorities, reinforcement mix, raid cadence, and target focus without adding a parallel AI subsystem
- public enemy-threat summaries now route through visibility-aware raid reporting in `EnemyAdventureRules.gd`, so overworld threat text surfaces the new war-state cleanly without leaking exact hidden raid positions or internal economy values
- hostile raids now use the same save-backed encounter and map-node state to seize resource sites, secure relic caches, contest objective-linked neutral fronts, and raise town retake pressure instead of only marching on player towns
- hostile raids can now interrupt the overworld turn with a queued town-defense battle, and the battle flow reuses the existing encounter `enemy_army` path plus new battle-context metadata instead of splitting siege combat into a second system
- post-battle resolution now syncs surviving raid hosts, defending town garrisons, defending-hero state, and captured-town ownership back into core overworld state so siege outcomes create durable strategic consequences without a save-version bump
- the town shell now uses a sectioned, scroll-safe management layout, while `TownRules.gd` owns dispatch, defense, frontier-watch, construction-ledger, and recruit-reserve formatting so the scene stays declarative
- the town shell now also surfaces a full-width defense-outlook and dispatch-readiness board, while `TownRules.gd` owns the posture grading, visibility-safe threat summary, hero-coverage check, and support-chain messaging from live runtime state instead of a planner layer
- the overworld shell now uses a sectioned command layout, while `OverworldRules.gd` owns objective-board, scout-net, frontier-watch, active-context, and dispatch formatting so the scene stays declarative and visibility-safe
- the overworld shell now also surfaces a live command-risk forecast plus a one-shot end-turn warning, while `OverworldRules.gd` owns the risk scoring, summary shaping, and acknowledgement state from real raid, logistics, readiness, objective, and field-posture data instead of a separate planner or advisor layer
- the battle shell now uses a sectioned tactical layout, while `BattleRules.gd` owns commander, initiative, effect-board, action-guide, pressure, and dispatch formatting so the scene stays declarative and save-safe
- the battle shell now also surfaces a live tactical risk and readiness board, while `BattleRules.gd` derives tempo, commander-cover, cohesion, fire-lane, decisive-target, objective-urgency, and latest-shift messaging entirely from current battle state instead of adding a second advisor subsystem
- Embercourt and Mireclaw battle identity now stays data-driven through authored unit and spell payloads, with elite roster units, attack-buff spell support, post-damage status effects, and doctrine-aware AI scoring all routed through the existing battle rules instead of inventing a parallel faction combat subsystem
- tactical combat now carries persistent per-stack cohesion and momentum through the same battle payload, with casualty shocks, isolation penalties, commander-trait support, morale-aware spell modifiers, and AI target/buff scoring all resolved inside `scripts/core` instead of a separate morale minigame
- battle encounter variety now stays data-driven through authored `battlefield_tags`, commander `battle_traits`, and specialized army-group compositions, with `BattleRules.gd` and `BattleAiRules.gd` reading those payloads for initiative, damage, target priority, and spell-value changes instead of moving context logic into scenes
- battle order surfacing now keeps focused-order, trade-window, command-tool, objective-pull, and likely hostile-reply language in `BattleRules.gd`, with `BattleShell.gd` only binding the consequence panel and action buttons so save version `9` remains unchanged
- campaign content now ships as two authored three-chapter arcs, and repository-local validation enforces multi-arc breadth plus the existing browser/start/outcome wiring instead of allowing regression back to a single short chain
- artifact ownership now normalizes to unique ids across equipped slots and pack inventory, and scripted `award_artifact` effects plus carryover merges reuse that path so duplicate relic rewards degrade safely instead of corrupting state
- main-menu resume UX now reads `SaveService` summaries instead of assuming `slot1`, and overworld/town save controls select an explicit manual slot while autosaves are captured on scene transitions and day advancement
- scenario selection metadata now authors skirmish-browser labels, faction summaries, and launch availability in `content/scenarios.json`, while the main menu routes skirmish starts through `ScenarioSelectRules.gd` so campaign and skirmish launches share bootstrap code without sharing progression side effects
- difficulty now resolves from a shared `DifficultyRules.gd` profile keyed by persisted `session.difficulty`, so restored campaign and skirmish saves pick up the same movement/economy/pressure/battle modifiers as fresh launches without changing save version `9`
- hero command is now normalized in `HeroCommandRules.gd`, with town-only switching and transfer validation preventing remote roster mutation paths from bypassing the active-town invariants
- hero templates now author release-facing identity summaries, roster summaries, starting specialties, and specialty-focus ordering so recruitment, setup summaries, and live hero readouts surface real progression-facing differentiation without scene-owned logic
- overworld and town scenes now expose thin roster, tavern, and transfer bars, while repository-local validation checks the hero-command content assumptions plus the new UI/controller wiring
- overworld fog now persists as save-backed visible/explored tile grids under session state, with restore normalization rebuilding current visibility from the full player roster instead of bumping save version `9`
- scouting radius now aggregates through `HeroCommandRules.gd` from progression and artifact bonuses, and overworld rendering plus scripted map-spawn messaging must avoid surfacing hidden towns, resources, artifacts, or encounters outside current visibility
- tactical combat depth now authors per-unit abilities in `content/units.json`, with `BattleRules.gd` applying reach, brace, harry, backstab, shielding, and volley through the same hero/spell/artifact-influenced damage flow instead of scene-owned exceptions
- durable battle statuses now normalize through `SpellRules.gd` as modifier dictionaries with effect ids, so unit abilities and battle spells can share the same round-to-round stack-effect pipeline while `BattleAiRules.gd` scores around status setup and exploitation
- town progression now normalizes authored build trees through prerequisite and upgrade chains, with faction/town economy profiles plus weekly muster growth resolving in core while `TownShell.gd` only surfaces status, blockers, income, and recruit reserves
- campaign and skirmish breadth now expands through authored scenario content rather than shell branches, with a new Mireclaw-led campaign arc and a skirmish-only Mira front broadening playable starts while preserving save, settings, and campaign boundaries
- authored scenarios now differentiate chapter pressure through encounter-clearing side objectives, hook dependency checks, raid-count reactions, relief/counterattack spawns, and enemy-pressure surges in `ScenarioScriptRules.gd`, while `OverworldRules.gd` surfaces recent scripted beats as a scenario pulse instead of pushing that state into scene controllers
- town progression now carries authored late-game payoff through advanced faction-specific buildings, with `OverworldRules.gd` exposing reinforcement quality, battle readiness, and town pressure output so `EnemyTurnRules.gd` and `TownRules.gd` can value Embercourt strongholds differently from Mireclaw raid-nests without adding a parallel subsystem
- late-front escalation now stays inside the existing town, enemy, and scenario pipeline: towns author strategic roles and capital projects, `EnemyTurnRules.gd` converts those anchors into stronger defense and faster raid cadence, and finale scenarios trigger those projects through authored script hooks instead of a separate endgame layer
- strategic logistics and raid recovery now stay in that same town pipeline: capitals and strongholds author `logistics_plan`, capital projects author support requirements plus vulnerability penalties and recovery guards, and `OverworldRules.gd` turns missing anchor families or battle damage into real recruitment, readiness, pressure, and recovery changes that `TownRules.gd` and `EnemyTurnRules.gd` surface without moving state into scenes
- strategic response orders now stay in that same shared state: persistent logistics sites author response profiles, `HeroCommandRules.gd` spends real movement for relief dispatch, `OverworldRules.gd` applies response watch windows and town recovery relief on the same node and town payloads, and `TownRules.gd` plus the thin shell controllers only surface those core-owned actions and summaries
- town exchange play now stays in that same economy pipeline: `building_market_square`, `building_river_granary_exchange`, and `building_resonant_exchange` drive trade rates through faction and town economy profiles, `OverworldRules.gd` owns player and hostile quote or liquidation logic, and `TownRules.gd` plus the town shell only surface the core-owned exchange hall summaries and actions
- town order readiness now stays in that same shell boundary: `OverworldRules.gd` exposes exchange-aware cost readiness from current reserves plus authored market rates, `TownRules.gd` ranks build, levy, response, and wall-coverage pressure into a single ledger, and `TownShell.gd` only binds the resulting panel instead of adding planner-side state
- battle spell timing now stays in that same shell boundary: `BattleRules.gd` ranks live spell windows, status follow-through, protection pressure, and hostile burst risk from current battle payload only, `SpellRules.gd` adds timing-aware spell summaries, and `BattleShell.gd` only binds the resulting timing panel instead of adding advisor-side state
- battlefield cover and obstruction identity now stays in that same battle boundary: authored encounter `field_objectives` can declare `cover_line` and `obstruction_line`, while `BattleRules.gd` and `BattleAiRules.gd` turn them into movement tax, ranged safety, commander screening, target-priority, and pressure-summary state without adding a separate planner or subsystem
