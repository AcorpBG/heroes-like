# Overworld Strategic Density And Route Occupancy Requirements

Task: #10230
Slice: `overworld-strategic-density-and-route-occupancy-10230`
Phase: Phase 6 - Production Alpha Layer
Status: completed 2026-09-04

## Owner Direction

The Overworld still feels materially emptier than a classic Heroes adventure map when the amount of usable terrain is compared with the number of meaningful destinations. Correct the live experience through original Aurelion Reach content and authoritative map records.

## Measured Baseline

- The current authored catalog contains 5,206 town, resource, artifact, and encounter placements across 49,410 tiles, but density is uneven: the median scenario is 10.37 placements per 100 tiles while Ninefold Confluence is only 3.52 and several other large scenarios are below 6.5.
- The unchanged generated-density runtime report is red. Its native Large fixture exposes 909 live interactables, but the current report recognizes only 144 as reachable, no road-near objects, and one object in the initial 5x5 reveal. Small and Medium report reachable empty-window ratios of 0.984 and 0.914.
- The report predates disk-package startup: it reads roads and materialization from `setup.generated_map`, which is intentionally empty for current native package launches. Its reachability scan also blocks object body cells without recognizing package action/visit tiles. These measurements must be repaired before they are used as a gameplay gate.
- A checked-in controlled 36x36 H3MapEd reference contains 312 objects: 178 decoration, 22 guards, 41 other visitable objects, 67 rewards, and 4 towns. This is comparison evidence only; no protected names, pixels, maps, DEFs, or content may enter the product.

## Required Outcome

1. Measure authored and native-package maps through the same live-session authority. Report total land/traversable tiles, unique blocked body tiles, actionable/visitable records, reachable action surfaces, road-near destinations, per-screen visible destinations, and largest meaningful empty region without counting one multi-tile footprint as several interactables.
2. Trace every apparent density loss to one concrete owner: authored placement data, package object projection, package road/action/body adoption, live pathing/interaction indexing, or presentation of authoritative occupied cells.
3. Existing native-package objects with valid original-game proxy identities and action tiles must remain visible, reachable through their authoritative interaction surface, and included in density calculations. Current package roads must be read from the live terrain-layer/package surface rather than an obsolete empty setup payload.
4. Exact package body masks must read as coherent occupied terrain masses at play scale. Visual mass may become denser only inside authoritative body ownership; it may not invent collision, hide routes, or create fake interactables.
5. Sparse authored scenarios selected for correction must receive explicit, deterministic, semantically appropriate original content placements in their authored data and authoring source. Added destinations must have real gameplay behavior, art, pathing, save, AI, and objective compatibility; decoration alone does not satisfy the interactable-density requirement.
6. Native RMG generation remains source-parity owned. Do not add density scalars, post-payload placement, synthetic reward sprinkling, brute-force retries, topology gates, or final-map delta tuning. If the remaining generated-map gap is in unrecovered H3MapEd generation behavior, name the exact missing function/private state as a blocker instead of approximating it.

## Validation

- Focused authored/native-package density report with truthful road, action-tile, body-tile, reachability, local-screen, and empty-region metrics.
- Deterministic Small and Large generated-package cases proving unchanged native package identity and no post-payload object insertion.
- Focused gameplay checks for every authored placement added by this slice, including interaction, collection/control/battle as applicable, pathing, and save-version-9 round trip.
- Inspected 1920x1080 and 1280x720 captures of representative corrected authored and generated views.
- Existing object-pool, distinct-art, decorative-sprite, movement/pathing, and generated-package adoption coverage.
- `python3 tests/validate_repo.py`
- `git diff --check`
- Linux and Windows release export/package startup, with generated Overworld entry, below the unchanged 250000000-byte ceiling.

## Non-Goals

- No copied Heroes art, maps, names, DEFs, pixels, or protected expression.
- No guessed Native RMG generation/count/topology/placement change, density multiplier, package-time synthetic object pass, or unsupported parity claim.
- No combat/economy balance redesign, new faction, town UI, battle UI, save-version bump, campaign rewrite, signing, publication, whole-game validation, or release-readiness claim.
- No replacement of real interactables with decorative clutter, labels, badges, procedural geometry, or debug overlays.
