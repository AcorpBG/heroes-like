# heroes-like (working title)

Task: #10184

Reality reset date: 2026-04-16

## Vision
Create a full-featured, commercially credible, turn-based fantasy strategy game inspired by the exploration, army management, town growth, map control, and tactical combat loop of Heroes of Might and Magic II, while being legally and creatively its own thing.

That long-term goal remains intact. The project should still grow toward a shippable strategy game with original factions, heroes, units, buildings, spells, map objects, campaigns, AI opponents, save/load, settings, packaging, and a repeatable content pipeline.

The current state is not that product. A manual play audit showed that the game is not close to HoMM2/3 parity and is not honestly playable as a complete game. Existing systems, screens, authored content, validators, and routed harnesses are useful foundations, but their presence must not be treated as proof of a coherent player experience.

## Current Reality
- This is a prototype / pre-alpha codebase with many production-minded systems started.
- The live client does not yet prove that a real player can start, understand, play, win, lose, save, resume, and finish a scenario without developer knowledge.
- Several docs previously implied completion, release-facing polish, or broad content readiness. Those claims are no longer accepted unless verified by manual play in the live client.
- HoMM2-class breadth and HoMM3-class breadth are future product horizons, not current milestones.
- The first product milestone was one manually completable scenario rather than a full campaign package, and AcOrP reported that River Pass manual gate passed on 2026-04-18.
- With River Pass manually cleared, implementation has started on all six bible factions as real content scaffolds. This is not a claim that six factions are fully playable; playable alpha still requires deep vertical slices, scenario integration, AI behavior, save/load proof, and manual play evidence.

## Delivery Strategy
The project now advances through explicit proof gates:

1. Prototype / pre-alpha reality
   - Stop using fake-complete language.
   - Keep architecture decisions only where they still help the product.
   - Maintain a parity ledger that separates implemented code, live-player usability, content breadth, and tested acceptance.

2. One manually completable scenario
   - Make River Pass completable end-to-end by a real player in the live client.
   - The scenario must include meaningful overworld movement, town use, recruitment, at least one battle path, save/resume, victory, defeat, and outcome routing.
   - This is the first truth source for whether the game is playable.

3. Playable alpha baseline
   - Expand from one scenario to a small, coherent alpha with at least two deeply proven factions while broader six-faction scaffolds mature under validation.
   - Town, battle, overworld, and front-end UX must be usable without debug interpretation.
   - Units, spells, artifacts, map objects, and scenario content must be deep enough to sustain repeated play.

4. HoMM2-class breadth
   - Build a broad fantasy strategy package at roughly the systemic breadth expected from the Heroes II era: multiple original factions, towns, unit tiers, spells, artifacts, neutral sites, handcrafted maps, campaign structure, and reliable AI.
   - This is not just more data. It requires battle, town, overworld, AI, save/load, and UX loops to hold up under breadth.

5. HoMM3-class breadth
   - After HoMM2-class breadth is stable, expand toward the richer strategic and content density associated with Heroes III: deeper faction variety, more objects, artifacts, magic, hero growth, map scripting, campaign complexity, AI pressure, and polish.
   - This is a late production horizon, not a near-term promise.

## Product Pillars
1. Adventure map exploration with discovery, route planning, visible risk, and resource pressure.
2. Tactical turn-based battles with readable unit roles, terrain pressure, hero influence, spells, morale-style momentum, and meaningful outcomes.
3. Town development, recruitment, resource gating, strategic expansion, defense, and recovery.
4. Strong single-player experience first: handcrafted scenarios, skirmish, campaign framework, AI opponents, save/load, difficulty, and onboarding.
5. Production-ready foundations: data-driven content, deterministic rules where useful, validation, logging hooks, packaging, settings, and practical mod-friendly boundaries.

## Current Non-Goals
- Claiming release readiness.
- Claiming HoMM2/HoMM3 parity before live-client manual play proves the underlying loops.
- Expanding broad campaign content before River Pass is manually completable.
- Hiding playability gaps behind dashboards, validators, smoke tests, or authored data volume.
- Direct recreation of copyrighted names, assets, maps, factions, unit art, music, or text.
- Multiplayer-first architecture.

## Engine and Stack Decision
Decision date: 2026-04-14

The project is locked to the Godot 4 stable series for the first production foundation and early vertical slices.

Stack choice:
- engine: Godot 4, 2D-first rendering and UI
- gameplay language: GDScript
- authored content: JSON files checked into `content/`
- runtime saves: JSON snapshots and campaign progression profiles under `user://saves/`

Rationale:
- Godot 4 supports fast iteration for a strategy game built around scene composition, UI-heavy flows, and toolable content.
- GDScript keeps gameplay code editor-native while the simulation architecture continues to settle.
- JSON content keeps factions, units, heroes, scenarios, encounters, towns, spells, artifacts, and campaign metadata diffable and reviewable.
- If native performance hotspots emerge later, GDExtension can be added surgically without replacing the baseline stack.

## Architecture Kept
These decisions remain directionally valid and should be preserved unless a future manual-play or implementation finding proves they block the product:

- App layer: boot scene plus autoload services for content loading, scene routing, save/load, settings, campaign progression, and active session state.
- Domain layer: core rule scripts own overworld state, tactical battle state, town state, hero command, artifacts, spells, objectives, enemy turns, AI decisions, serialization, and content validation.
- Presentation layer: menu, overworld, town, battle, and outcome scenes render state and issue intents back into domain rules. Scene controllers should stay thin.
- Data boundary: authored content is immutable at runtime and referenced by stable ids; save data stores mutable session state plus content references.
- Save/load boundary: snapshots are versioned and should preserve scenario progress, hero state, resources, day, battle or town return context, resolved encounters, and campaign progression where applicable.
- Determinism stance: rules should avoid hidden frame-timing dependencies so repeatable tests, replay tooling, and live-client diagnosis remain feasible.
- Screen composition stance: scenic or play surfaces are primary. Detailed information belongs in compact rails, command bands, tabs, contextual popouts, or secondary overlays instead of covering the game with text panels.

## Core Rule Ownership
The current split across `scripts/core/` is still the right shape:
- `ScenarioFactory.gd` for scenario bootstrap.
- `OverworldRules.gd` for adventure map state, movement, site resolution, day advancement, economy ticks, fog/scouting, town ownership, and strategic summaries.
- `BattleRules.gd` for battle payloads, initiative, stack actions, spells/status integration, battle exits, and post-battle sync.
- `BattleAiRules.gd` for tactical enemy decisions.
- `TownRules.gd` for build, recruit, study, garrison, market, defense, and town-summary rules.
- `HeroCommandRules.gd` and `HeroProgressionRules.gd` for roster, active hero, transfer, recruitment, progression, and carryover-safe hero state.
- `ArtifactRules.gd` for duplicate-safe artifact ownership, equipment, swaps, rewards, and pickups.
- `SpellRules.gd` for spellbook and spell-effect resolution.
- `ScenarioRules.gd` and `ScenarioScriptRules.gd` for objectives, victory/defeat, scenario hooks, authored events, and outcome shaping.
- `CampaignRules.gd` and `CampaignProgression.gd` for campaign unlocks, completion records, and carryover.
- `EnemyTurnRules.gd` and `EnemyAdventureRules.gd` for hostile economy, raid planning, commander lifecycle, target selection, and strategic contestation.
- `DifficultyRules.gd` for difficulty tuning.

The reset does not require deleting these systems. It requires proving which of them work together in player-facing flow.

## Data Domains
The authored content boundary remains split into JSON domains under `content/`:
- `factions.json`
- `heroes.json`
- `units.json`
- `army_groups.json`
- `towns.json`
- `buildings.json`
- `resource_sites.json`
- `biomes.json`
- `map_objects.json`
- `artifacts.json`
- `spells.json`
- `encounters.json`
- `scenarios.json`
- `campaigns.json`

Near-term content work now shifts from proving River Pass completion to using that passed gate responsibly: begin the six-faction implementation loop as real JSON content scaffolds, then deepen selected factions through complete town, battle, overworld, AI, scenario, save/load, and manual-play slices before calling them playable.

## Content Direction Note
Decision date: 2026-04-18

The target broad faction set is six original, asymmetric factions defined first in `docs/factions-content-bible.md`. The first implementation slice now carries those factions as real scaffold records across faction metadata, unit ladders, hero concepts, signature buildings, and seed towns where needed. This remains content infrastructure, not playability proof. Future JSON and runtime work must preserve the no-commons and no-shared-template constraints: factions need distinct fantasy, mechanics, town identity, hero identity, economy, map pressure, battle style, and unit ladder feel. A faction should not be called fully playable until its scenario placement, AI fronts, town play, battle tuning, save/load behavior, and manual play notes exist.

The next companion design source is `docs/overworld-content-bible.md`. It defines the adventure-map grammar needed to support that faction breadth: biome families, pickup sites, flaggable economy, dwellings, shrines, guarded reward sites, scouting structures, blockers, transit objects, and faction landmarks. The game should move toward richer overworld object vocabulary through explicit content families and biome logic, not by sprinkling random flavor nodes on otherwise empty maps.

Implementation note date: 2026-04-18

The first overworld-content foundation slice now implements that direction as real content domains and runtime hooks: `content/biomes.json`, `content/map_objects.json`, expanded `resource_sites.json` families, ContentService validation/loading, authored biome terrain labels/passability, and expanded overworld site-family context/action handling. This is a foundation for future scenario placement, not proof of broad adventure-map playability.

## Repository Structure
- `content/`: authored gameplay domains.
- `scenes/`: Godot scene assets for boot, menu, overworld, town, battle, and outcome.
- `scripts/autoload/`: cross-cutting services with minimal UI knowledge.
- `scripts/core/`: gameplay state, rules, and serialization helpers.
- `scripts/ui/`: scene controllers for menus and shells.
- `tests/`: simulation, content validation, smoke, and live-client validation coverage.
- `ops/`: planning and progress tracking.
- `docs/`: design notes, wireframes, and process records.

## Near-Term Product Target
River Pass is the first playable proof target.

A player should be able to:
- launch River Pass from the live menu
- understand the objective and starting situation without reading source code
- move the hero on the overworld and make progress through visible choices
- enter and use at least one owned town
- recruit or recover enough forces to matter
- enter battle through normal play
- make tactical choices that resolve the fight
- save and resume from overworld, town, and battle states that the scenario actually uses
- reach a victory or defeat outcome through normal play
- return to menu or restart without corrupting progression or saves

Until that is true, the project remains pre-alpha regardless of how many systems exist.

## Release Bar
A release-ready v1 should eventually include:
- original world, factions, heroes, units, buildings, spells, artifacts, map objects, and campaign content
- stable adventure map loop
- stable tactical combat loop
- usable town/economy/recruitment loop
- campaign and skirmish support
- usable AI for world and battle play
- save/load reliability across normal player behavior
- settings, audio, UX polish, onboarding, packaging, and QA workflow
- repeatable content authoring and validation

This is a future bar. The repository should not describe itself as release-ready until manual play, automated validation, and content completeness all support that claim.
