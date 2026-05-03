# heroes-like Project Charter

Task: #10184  
Document role: strategic project definition  
Reset date: 2026-04-27

## Purpose

Build a full-production, release-bound, original turn-based fantasy strategy game inspired by the feel of Heroes of Might and Magic II/III: exploration, map control, town growth, army management, hero progression, tactical battles, artifacts, magic, campaigns, skirmish play, AI opponents, save/load, and a repeatable content pipeline.

This project must be legally and creatively its own game. Use classic Heroes games as readability, scale, and loop inspiration only. Do not copy names, assets, maps, factions, unit art, music, text, or distinctive protected creative expression.

## Current Reality

The repository is a prototype / pre-alpha foundation with many real systems started. It is not release-ready, not HoMM2/HoMM3 parity, and not a complete playable product.

River Pass has served as proof that a basic manual-play loop can work, but that does not prove production depth. Existing content breadth, validators, reports, UI screens, and smoke tests are evidence surfaces, not product-completion claims.

The current strategic need is to turn the foundation into a coherent strategy game through planned implementation slices, not by accumulating disconnected docs, reports, or UI cue polish.

Random map generation is not complete for alpha purposes until it reaches full HoMM3-style random-map-generation functional parity translated into this original game: template breadth, zone graph semantics, object density, guards, rewards, roads, validation, runtime adoption, and replay boundaries must all work through original content and systems.

## Document Model

- `project.md` is this strategic charter. It defines the product, phases, architecture rules, and durable constraints.
- `PLAN.md` is the tactical execution plan derived from this document. It breaks phases into implementation slices and references detailed requirement docs.
- `docs/*.md` files hold detailed requirements, research, design foundations, reports, and gate reviews.
- `ops/progress.json` tracks operational implementation state for PLAN slices.

Documentation is not implementation unless a slice is explicitly documentation-only. Implementation progress is complete only when code/content/tooling changes satisfy the referenced requirements and validation gates.

## Product Pillars

1. Original world identity: premise, tone, geography, history, conflicts, and visual language.
2. Asymmetric factions: each faction needs distinct town identity, economy pressure, hero identity, units, magic/artifact relationship, map pressure, and battle style.
3. Adventure map strategy: exploration, route planning, resource pressure, guarded rewards, mines/sites, encounters, fog/scouting, and map control.
4. Tactical battles: readable unit roles, initiative/order clarity, terrain pressure, hero influence, spells, artifacts, morale-style momentum, and meaningful outcomes.
5. Town development: construction, recruitment, garrisoning, economy choices, study/magic, defense, recovery, and faction-biased costs.
6. Strategic AI: computer-controlled heroes/towns that make understandable economy, movement, recruitment, objective, and pressure decisions.
7. Production foundations: data-driven content, deterministic rules where useful, robust save/load, validation, tooling, settings, packaging, and mod-friendly boundaries.

## Engine And Stack

Locked stack for the current production foundation:

- Engine: Godot 4 stable series.
- Gameplay language: GDScript.
- Rendering: 2D-first scenes and UI.
- Authored content: JSON files under `content/` until a selected migration replaces specific domains.
- Runtime saves: versioned JSON snapshots and campaign progression under `user://saves/` until a selected migration introduces asset-reference saves plus compact deltas.
- Validation: Python repository checks plus focused Godot smoke/report scenes.
- Native extension candidate: Phase 2 map/scenario persistence may introduce a Godot GDExtension written in C++ for typed map documents, durable map packages, validation, save/load, and migration.

Native extensions, external asset pipelines, or new storage layers may be added only through concrete tactical slices with rollback, compatibility, and validation gates.

## Architecture Rules

- Keep simulation/domain logic outside scene controllers.
- Scene controllers render state and send intents; core rule scripts own gameplay decisions.
- Authored content is immutable at runtime and referenced by stable ids.
- Save data stores mutable state plus content references, not copied authored definitions.
- Map/scenario persistence must separate authored/generated map assets from mutable session deltas; full map payload rewrites are not an acceptable long-term save model.
- Save/load must remain explicit, versioned, and backward-aware.
- New map formats need load, validate, save, and migrate mechanisms before they become authoritative runtime content.
- Autoloads are for cross-cutting services, not hiding gameplay rules.
- Prefer deterministic rule helpers and fixtureable data for tests and reports.
- Public UI must not leak internal/debug score fields.
- Scenic/play surfaces are primary. Do not solve missing usability by covering screens with giant dashboards.
- Fog of war follows the classic Heroes-style permanent exploration model: unexplored tiles stay hidden, and once terrain is explored it remains visible for gameplay and rendering. `visible_tiles` may remain as a compatibility/cache field, but it must not represent a separate transient grey/stale information layer.

## Core System Ownership

Expected ownership boundaries:

- Scenario bootstrap and setup: `ScenarioFactory.gd`, scenario content JSON, and future scenario/map document adapters.
- Map/scenario persistence: current JSON content/save plumbing in `ContentService.gd`, `SaveService.gd`, and `SessionStateStore.gd`; future C++ GDExtension map package ownership once selected by a tactical slice.
- Overworld state, movement, sites, economy ticks, fog, towns, and strategic summaries: `OverworldRules.gd`.
- Battle state, initiative, stack actions, spells/status, exits, and post-battle sync: `BattleRules.gd`.
- Tactical enemy decisions: `BattleAiRules.gd`.
- Town construction, recruitment, study, garrison, market, defense, and town summaries: `TownRules.gd`.
- Heroes, command, roster, transfer, recruitment, progression, and carryover-safe hero state: `HeroCommandRules.gd`, `HeroProgressionRules.gd`.
- Artifacts: `ArtifactRules.gd`.
- Spells: `SpellRules.gd`.
- Objectives, scripts, outcome shaping: `ScenarioRules.gd`, `ScenarioScriptRules.gd`.
- Campaign progression: `CampaignRules.gd`, `CampaignProgression.gd`.
- Strategic AI and enemy turns: `EnemyTurnRules.gd`, `EnemyAdventureRules.gd`.
- Difficulty: `DifficultyRules.gd`.
- Save/load plumbing: `SessionStateStore.gd`, `SaveService.gd`.

If a slice changes ownership boundaries, update this document only when the decision is strategic and durable.

## Content Domains

Primary authored JSON domains:

- factions, heroes, units, army groups;
- towns, buildings;
- resources, resource sites, map objects, biomes, terrain layers/grammar;
- neutral dwellings, encounters;
- artifacts, spells;
- scenarios, scripts, campaigns.

Content breadth is not playability proof. A faction, system, scenario, or campaign is not complete until it is placed into live player flow, validated, and manually understandable.

## Phase Ladder

### Phase 0 — Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

Exit criteria:
- Strategic, tactical, and progress documents have distinct roles.
- Progress tracking measures implementation, not documentation volume.
- Workers can identify the current slice without loading giant history files.

### Phase 1 — Manual Scenario Proof

Goal: one real scenario can be completed manually in the live client.

Exit criteria:
- Player can start, understand, play, save/resume, win/lose, and reach outcome routing.
- Core overworld, town, battle, save/load, and outcome loops are exercised.
- River Pass remains proof history, not broad product readiness.

### Phase 2 — Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

Tracks:
- world and faction identity;
- concept-art direction and curation;
- economy/resource model;
- overworld object taxonomy and encounter representation;
- magic and artifact systems;
- animation/event cue foundations;
- strategic AI foundations;
- terrain/editor/tooling foundations;
- map/scenario document structure and persistence foundations;
- random map generator foundations for scenario prototyping, balance harness input, and later skirmish replayability.

Exit criteria:
- Key systems have implemented, validated, player-facing or tooling-facing slices.
- Requirement docs are connected to implementation slices in PLAN/progress tracking.
- At least two factions have enough identity, economy, unit/town/magic/artifact hooks, placement, and AI pressure to support alpha planning.
- A random map generator foundation exists for controlled prototype maps, with validation hooks and constraints suitable for the later headless balance harness.
- Map/scenario persistence has a selected architecture for durable authored/generated map assets, versioned validation/migration, and session saves that reference map assets plus compact mutable deltas instead of rewriting full map JSON payloads.

### Phase 3 — Headless AI Agent Balance Harness

Goal: create a non-graphical agent/test harness that can run scenarios, AI turns, economy loops, battles, and balance checks faster than manual UI play.

Exit criteria:
- Headless agents can execute core game loops through domain rules without depending on scene graphics.
- The harness can run repeated simulations for scenario viability, economy pressure, AI behavior, battle outcomes, faction balance, and regression detection.
- Reports expose actionable balance and rules failures without becoming player-facing UI or replacing manual play.
- Save/load and deterministic replay boundaries are tested through the harness where practical.

### Phase 4 — Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Exit criteria:
- Multiple scenarios/skirmish setups work end-to-end.
- At least two factions are meaningfully playable and distinct.
- Town, battle, overworld, save/load, AI, economy, and UI loops hold together under repeated play.
- Major UX surfaces are understandable without debug/report panels.

### Phase 5 — Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

Exit criteria:
- More factions/content enter play through the established systems.
- Campaign/skirmish flow, difficulty, AI, balance, and content pipeline are stable enough for broader production.
- Packaging/settings/accessibility/performance requirements are known and tracked.

### Phase 6 — Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with the systemic breadth, density, and replayability expected from classic Heroes-style strategy games.

Exit criteria:
- Multiple original factions, towns, unit ladders, spells, artifacts, neutral sites, handcrafted maps, campaign structure, and reliable AI.
- Deeper faction variety, object density, hero growth, map scripting, strategic pressure, and polish are supported by working loops.
- Breadth is implemented through playable systems and validated content pipelines, not just authored data volume.
- This is a late production horizon, not a near-term claim.

## Current Strategic Focus

Current phase: Phase 2 — Deep Production Foundation.

Immediate strategic priority is not more ad hoc screen polish. Work should be selected through PLAN.md and progress tracking, with source requirements in `docs/*.md`, implementation targets, and validation gates.

## Non-Goals

- Claim release readiness or parity before live-client evidence supports it.
- Treat docs/reports as implemented systems.
- Use UI dashboards or cue text as a substitute for real mechanics/content/tooling.
- Start unanchored “small useful” slices outside the PLAN/progress workflow.
- Make save-schema, map-package, resource-registry, AI-behavior, pathing/occupancy, renderer-asset, or production-JSON migrations without explicit tactical slices and rollback boundaries.
- Multiplayer-first architecture.

## Strategic Guardrails

- Keep work sliceable, validated, and reversible.
- Prefer implementation that strengthens final architecture.
- Preserve legal originality.
- Protect save compatibility unless a migration is explicitly planned.
- Keep public/player-facing surfaces compact and non-debuggy.
- Do not call a slice complete until implementation and validation meet the referenced requirements.
