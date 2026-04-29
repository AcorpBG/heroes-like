# Random Map Generator Foundation Requirements

Status: requirements source, not implementation proof.
Date: 2026-04-29.
Slice: random-map-requirements-doc-10184.

## Purpose

The random map generator foundation must provide deterministic, validated prototype maps for scenario iteration, Phase 3 balance-harness input, and later skirmish replayability. It is not a finished skirmish random map generator.

The generator should produce original Aurelion Reach scenarios that can be inspected, reported, and eventually loaded through the existing scenario pipeline. It must build on existing data-driven domains: terrain layers and grammar, factions, towns, resources, map objects, neutral encounters, objectives, strategic AI, and save-stable scenario ids.

## Determinism

Generation must be reproducible from explicit inputs:

- `generator_version`
- seed string or integer
- size preset
- player count and faction/start constraints
- biome/terrain theme constraints
- difficulty or guard-strength profile
- enabled content packs or allowlists

The same inputs and content ids must produce the same generated scenario payload, validation report, object placements, road graph, objective set, and fairness metrics. Reports must include the normalized seed, generator version, content manifest fingerprint where practical, and any fallback/retry decisions. Runtime clocks, unordered dictionary iteration, filesystem order, renderer state, and editor-only state must not affect generated output.

## Generated Scenario Boundary

The generator should emit a scenario-like payload compatible with the authored scenario model, but it must stay behind an explicit generated-source boundary until later runtime adoption.

Required generated payload shape:

- stable generated scenario id and display name
- map dimensions and tile rows
- terrain-layer payload or terrain-layer references
- player slots, starts, factions, teams, and AI flags
- towns with placement ids, owners, faction/town templates, garrisons, and starting buildings
- heroes or start-hero contracts when selected by a later slice
- resource sites and map-object placements using existing content ids
- neutral encounters, guards, and reward/objective links
- objective definitions and scenario-script hooks limited to supported objective types
- metadata block with seed, generator version, rule profile, validation summary, and non-authoritative debug notes

Generated scenarios must not be written into production campaign content by default. Any durable file export, editor writeback, campaign adoption, or save migration requires a later explicit slice.

## Terrain And Biomes

Terrain generation must produce maps that are readable before art polish:

- Respect existing terrain grammar, layer ids, biome tags, passability, blockers, and renderer/editor contracts.
- Preserve navigable land regions large enough for starts, towns, roads, mines, encounter pockets, and objective sites.
- Keep water, coast, marsh, cliffs, forest, ruins, roads, and blockers in coherent clusters rather than random noise.
- Avoid sealing required starts, towns, resource fronts, objectives, or exit routes behind impassable terrain unless a supported transit/unlock rule opens them.
- Reserve approach space for towns, mines, dwellings, guarded sites, and large-footprint objects.
- Emit terrain-layer validation details for passability, region count, isolated pockets, blocked approaches, and illegal layer combinations.

Biome constraints should bias object families, resources, neutral encounters, and scenic density without creating faction-only maps unless the profile asks for that.

## Towns, Starts, And Players

Each player slot must have a viable start:

- one primary town or explicitly documented townless-start profile
- reachable starting hero or start area once hero generation exists
- nearby early pickups/resource sites appropriate to the economy baseline
- at least one expansion route and one contestable route
- minimum safe build/recruit window before high-threat neutral pressure
- no immediate forced battle above the selected profile's start threshold

Start placement must be symmetric enough for fairness reports but not visually mirrored unless the profile requests it. The generator must track distance from each start to towns, resources, roads, objectives, neutral blockers, and enemy starts. Multi-player generation must support team, free-for-all, and neutral-slot metadata even if only a subset is implemented initially.

## Roads, Connectivity, And Pathing

The generator must create an explicit route graph:

- start-to-town links
- town-to-resource and town-to-objective links
- contest routes between players
- optional bypasses, ferries, bridges, gates, or transit objects
- guarded choke points and alternative paths where the profile supports them

Every required objective, primary town, starting area, and minimum economy site must be reachable under the initial passability rules or through an explicitly reported unlock. Reports must distinguish full connectivity, guarded connectivity, blocked connectivity, and optional dead-end reward pockets.

Pathing validation must use domain-rule expectations, not renderer geometry. Large objects need body tiles and approach tiles; roads must not cut through blocked bodies; guard placement must protect intended routes without occupying impossible visit tiles.

## Resources, Objects, Encounters, And Objectives

Generated maps must place economy and adventure content through existing content ids and future allowlists, not ad hoc inline definitions.

Resource requirements:

- early-access gold, wood, and ore appropriate to current economy reality
- staged support for rare resources only through explicit profile flags
- contested resource fronts at meaningful travel distances
- guarded and unguarded resource sites according to profile
- no resource deadlock that prevents baseline town development

Map-object requirements:

- use object taxonomy roles: pickup, persistent economy site, transit, neutral dwelling, neutral encounter, guarded reward, faction landmark, scenario objective, and scenic/blocker
- respect footprints, approach rules, passability, biome tags, and state variants
- avoid density by duplicating one object family
- record placed-object purpose: start support, expansion, contest, route control, reward pocket, objective, or scenery

Encounter and guard requirements:

- neutral stacks must have difficulty bands tied to distance, reward value, route importance, and objective role
- guard strength must not create unavoidable early unwinnable fights
- guarded rewards must report risk/reward class
- neutral dwellings and visible encounters must remain first-class objects where the content model supports them

Objective requirements:

- generated objectives must be achievable through supported scenario rules
- objective locations must be reachable and visible enough for a prototype scenario
- objective guard and reward pressure must be reported

## Fairness And Minimum Viability

Every generated map must produce a viability report before it can be used by another system.

Minimum viability checks:

- deterministic replay comparison for at least two generations with the same seed
- all required starts and objective sites are reachable
- each player has a minimum early economy package
- each player has a primary town or approved townless-start contract
- early hostile pressure stays under profile thresholds
- no required path is blocked by terrain/object body conflicts
- no duplicate placement ids or invalid content references
- generated objectives are satisfiable by existing rules

Fairness checks:

- travel distance from each start to first town, first mine/front, first objective, and nearest opponent route
- early resource value near each start
- guarded reward value and guard strength by player region
- town count, expansion count, and contestable site distribution
- road access and choke pressure distribution
- faction-start compatibility warnings when map geography strongly favors or harms a faction

Reports should classify results as `pass`, `warning`, or `fail`. A map with warnings may be useful for designer review; a failed map must not feed scenario smoke, campaign content, or balance harness batches except as negative test evidence.

## Validation And Report Harness

The foundation implementation should include a headless report command or focused test that can:

- generate one or more maps from fixed seeds
- emit a compact JSON or text report suitable for CI logs
- validate schema references against content files
- compare deterministic output for a repeated seed
- summarize terrain, placement, route, economy, encounter, guard, objective, and fairness metrics
- fail clearly on invalid generated payloads

The report is a tooling surface, not player UI. It must not require Godot renderer state, editor scene state, campaign progression, or saved games.

## Phase 3 Harness Path

Phase 3 balance harness integration should treat generated maps as test fixtures with known provenance:

- batch seeds by profile and generator version
- feed valid generated scenario payloads into headless domain-rule simulations
- collect economy, AI, combat, objective, and faction-balance metrics
- preserve seed and generator metadata for replaying failures
- keep generated-map reports separate from player-facing scenario selection until a later adoption slice

The generator should expose enough structured metadata for the harness to explain whether a balance failure came from map viability, content values, strategic AI behavior, battle rules, or scenario objective pressure.

## Non-Goals

- No claim of finished skirmish RMG.
- No broad content migration or replacement of authored scenarios.
- No campaign or alpha adoption of generated maps.
- No hidden renderer, terrain art, asset, or editor writeback migration.
- No save-schema migration.
- No new faction, unit, spell, artifact, object, or economy content hidden inside generator work.
- No player-facing random-map menu until a later UX/runtime slice selects it.
