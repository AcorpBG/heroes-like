# Phase 2.4 Corrective Object Implementation Backlog

Status: corrective planning backlog, not object implementation.
Date: 2026-04-27.
Phase: P2.4 Overworld Object And Neutral Encounter Foundation.

## Purpose And Correction

P2.4 was supposed to establish a broad practical vocabulary of authored overworld object families before forward movement into P2.5 magic work. The intended outcome was not just schema support. It was a production-minded backlog of original Aurelion Reach object types covering map density, route structure, economy pressure, neutral threats, rewards, dwellings, transit, coast objects, landmarks, decorations, and scenario authoring.

The current P2.4 work built useful scaffolding, but it did not complete that breadth goal. Existing work added runtime metadata reading, editor/report validation, representative shape-aware pathing, a few first-class neutral encounter records, bounded AI valuation hooks, and selected transit authoring validation. Those are useful foundations. They are not enough object content.

Corrective rule: stop forward P2.5 implementation until a P2.4 object-content batch starts from this backlog. This document is the missing backlog. It does not implement the objects and must not be used to mark object content complete.

## Current Repo Counts

Current authored object source: `content/map_objects.json`.

Total map objects: 49.

Family breakdown:

| Family | Count | Notes |
| --- | ---: | --- |
| neutral_dwelling | 25 | Broadest current category, but most entries still lack full `primary_class`, `body_tiles`, and `approach` contracts. |
| neutral_encounter | 6 | First-class object-backed encounter records from bounded migrations. |
| mine | 3 | Only Brightwood Sawmill has representative body/approach pathing adoption. |
| faction_landmark | 3 | Mostly identity markers, not a broad landmark set. |
| pickup | 2 | Far too few for production map pacing. |
| guarded_reward_site | 2 | Far too few for reward-pocket variety. |
| transit_object | 2 | Ferry stage and rope lift carry selected route-effect metadata. |
| repeatable_service | 2 | Infirmary and market-like service coverage only. |
| scouting_structure | 2 | Watch/reveal category is only lightly covered. |
| blocker | 2 | Decoration/blocker vocabulary is nearly absent. |

Primary-class metadata breakdown:

| Primary class | Count |
| --- | ---: |
| missing | 33 |
| neutral_encounter | 6 |
| interactable_site | 3 |
| pickup | 2 |
| transit_route_object | 2 |
| decoration | 1 |
| faction_landmark | 1 |
| persistent_economy_site | 1 |

Shape/interaction readiness:

- 16 objects currently have at least one of modern interaction, body, approach, or editor-placement metadata.
- Only 6 objects have explicit `body_tiles`.
- Only 6 objects have explicit `approach` metadata.
- 0 production objects provide top-level `editor_placement` in the editor-authoring report cited below; selected transit/encounter entries now have newer metadata, but broad production object authoring remains incomplete.

Related current source: `content/resource_sites.json` has 48 entries. It contains useful site concepts, but site records alone are not sufficient map-object authoring. P2.4 needs actual object definitions that designers can place, validate, and reason about.

## HoMM3 Extracted Object Evidence

Source files inspected:

- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3bitmap/raw/objects.txt`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3bitmap/raw/objnames.txt`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3bitmap/raw/objtmplt.txt`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3sprite/defs/`

Counts:

| Evidence | Count |
| --- | ---: |
| Declared editor object rows in `objects.txt` | 1326 |
| Actual rows after declaration line | 1326 |
| Unique DEF filenames referenced by editor rows | 1305 |
| Duplicate DEF filename groups in editor rows | 11 |
| First-level extracted DEF manifests/assets under `defs/` | 2565 |
| Editor-row DEF filenames missing from extracted manifests | 0 |

Useful category observations from object names/templates:

- The source object list is large because it includes both interactable adventure objects and many terrain decorations/blockers.
- The largest row groups include monsters, artifacts, creature generators/dwellings, mines, towns, and extensive terrain decoration families such as rocks, mountains, craters, trees, shrubs, lakes, reefs, hills, swamp foliage, and subterranean rocks.
- It includes a broad spread of route, transit, and gate classes: one-way and two-way portals, border/key gates, subterranean gates, whirlpools, shipyards, boats, lighthouses, buoys, and reefs.
- It includes many one-off visitable services/rewards: markets, shrines, wells, fountains, observatories, scholar-like sites, schools, tombs, prisons, signs, events, resource piles, treasure chests, and guarded reward banks.
- `objtmplt.txt` shows the same template structure as `objects.txt`: DEF filename, terrain availability mask, editor/visit masks, and numeric class/subtype/group flags. For our purposes, the important lesson is not the exact encoding. It is that object authoring separates visual template data, placement/passability masks, and object class identity.

Use this evidence only for scale and category seriousness. Do not copy exact names, art, maps, text, or IP-specific identities into Aurelion Reach.

## Corrective Target

Target by the end of corrective P2.4: 220 authored `map_objects` total, including existing objects migrated/normalized where appropriate. This means about 171 net additions or replacements beyond the current 49. The target is intentionally much smaller than the extracted HoMM3 editor list, but large enough to support real map density and object variety.

Target category mix:

| Category | Target total | Current rough count | Corrective need |
| --- | ---: | ---: | --- |
| Decorations and blockers | 48 | 2 | Add blocking and non-blocking scenic families across regions. |
| Raw resources, pickups, and caches | 30 | 2 | Add common resources, staged rare-resource pickups, map clues, and guarded variants. |
| Mines and permanent resource buildings | 24 | 3 | Add common-resource mines and rare-resource fronts without activating rare economy costs. |
| Services, shrines, scouting, signs, and events | 28 | 6 | Add repeatable services, spell/progression sites, reveal sites, signs, and event markers. |
| Transit, coast, and shipyard-like objects | 20 | 2 | Add route gates, ferry/harbor/coast objects, one-way and two-way transit. |
| Dwellings and guarded dwellings | 28 | 25 | Normalize existing dwellings and add guarded high-value dwellings. |
| Guarded reward sites and hostile reward pockets | 22 | 8 including encounters | Add ruins, vaults, banks, lairs, guarded resource pockets, and elite sites. |
| Faction landmarks and scenario objectives | 20 | 3 | Add faction identity anchors, objective frames, and state variants. |
| Total | 220 | 49 | Broad but still sliceable. |

Density goals:

- Sparse wild 16x16 region: 8-14 decoration clusters, 2-4 pickups, 1-2 interactables, and 1 guard/encounter.
- Standard adventure 16x16 region: 12-20 decoration clusters, 4-7 pickups, 3-5 interactables, 2-4 guards/encounters, and 1 landmark.
- Contested economy 16x16 region: 10-16 decoration clusters, 3-5 pickups, 4-7 economy/transit sites, 3-5 guards/encounters, and 1-2 landmarks.
- Ruin or reward pocket 16x16 region: 12-22 decoration clusters, 2-4 pickups, 2-4 guarded sites, 3-6 guards, and 1 objective or landmark.
- Town influence 16x16 region: 8-16 decoration clusters, 2-5 pickups, 3-6 support/economy sites, 2-4 guards, and 1-3 faction landmarks.

Every new or normalized object should distinguish:

- `footprint`: visual footprint width/height, anchor, and tier.
- `body_tiles`: actual blocking body mask. Do not infer rectangular blocking from the visual footprint.
- `approach`: visit offsets or enter-to-collect behavior.
- `passability_class`: passable scenic, passable visit-on-enter, blocking visitable, blocking non-visitable, edge blocker, or conditional pass.
- `interaction`: cadence, remains-after-visit, ownership/guard requirements, and state changes.
- `biome_ids` or region tags.
- validation metadata needed by editor/report tooling.

## Category Backlog

### Decorations And Blockers

Target: 48 total definitions.
Priority: P0/P1 because density and path readability need non-interactable vocabulary before map production.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Non-blocking decoration | 24 | ash pennants, reed mats, lens glints, orchard markers, slag chips, bell ropes, shell drifts, memory-salt flecks | 1x1, 2x1, 2x2 scatter | `passable_scenic`, no interaction, no rewards | Emberflow, Drowned Marches, Glass Uplands, Walking Green, Brass Deeps, Veil Coast |
| Blocking decoration | 16 | lockwall slabs, chainboom wrecks, lens shard ridges, root knots, slag berms, wreck ribs, shardfall blocks | 2x1, 2x2, 3x1, 3x2, 3x3, non-square | `blocking_non_visitable`; body mask may be partial/non-rectangular; no interaction | Region-specific blockers and neutral ruin sets |
| Edge blockers | 8 | levee lips, reef shelves, root fences, rail embankments, cliff teeth | 2x1, 3x1, 4x1, L-shaped masks | `edge_blocker`; blocks lane edge without covering route center; no interaction | River, coast, forest, mountain, industrial routes |

Implementation expectations:

- Split decorations into blocking and non-blocking explicitly.
- Decorations are non-interactable by rule.
- Large scenic sets should include negative-space variants so map authors do not fill every tile with object silhouettes.

### Raw Resources, Pickups, And Caches

Target: 30 total definitions.
Priority: P0 because current pickup variety is the clearest P2.4 content gap.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Common raw resource stacks | 9 | coin purses, timber bundles, ore hods, payroll caskets, split-log piles, quarry chips | 1x1 | `passable_visit_on_enter`; collect on enter; removed after visit | All regions, road/wild variants |
| Staged rare-resource pickups | 9 | aetherglass splinters, embergrain sacks, peatwax tapers, verdant graft cuttings, brass scrip packets, memory-salt jars | 1x1 | collect only through staged/report-safe metadata until rare resources are activated; no live costs | Resource-native regions |
| Caches and map clues | 8 | road writ cache, survey tube, marsh marker bundle, lens case, orchard ration basket, salvage gauge case | 1x1, 2x1 | one-time; may reveal nearby route/site in later phases | Roads, frontiers, ruin pockets |
| Guarded small pickups | 4 | toll coffer, wreck strongbox, sealed seed chest, slag paybox | 1x1, 2x1 | visible guard link; reward after encounter; removed or spent state after visit | Contested economy and ruin pockets |

Implementation expectations:

- Live common resources remain `gold`, `wood`, and `ore`.
- Rare resources are authored as staged object metadata only until economy activation slices permit live stockpile use.
- Use original names and descriptions, not extracted source names.

### Mines And Permanent Resource Buildings

Target: 24 total definitions.
Priority: P0/P1 because resource-front density is core strategy.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Common mines | 9 | timber yard, quarry face, sluice camp, coin assay, ridge pit, marsh cut | 2x2, 2x3, 3x2 | `blocking_visitable`; body mask covers worksite; approach at gate/road; persistent owner/control | Grassland, forest, ridge, marsh, badland |
| Rare-resource fronts | 9 | aetherglass lens house, embergrain granary, peatwax yard, graft nursery, brass scrip mint, memory-salt pan | 2x2, 2x3, 3x3 | blocking visitable; staged output metadata; likely guarded; no live rare economy until later | Native rare-resource regions |
| Permanent support producers | 6 | wind press, saw chain, tide kiln, orchard levy post, smelter annex, charter countinghouse | 2x1, 2x2, 3x2 | owned/capturable or claimable; weekly/daily support; visible approach side | Town influence and contested economy bands |

Implementation expectations:

- Do not convert rare resources into live costs or markets in P2.4.
- Every mine needs explicit body/approach metadata.
- Mines should have guard expectations and AI value hints even when full AI adoption remains bounded.

### Services, Shrines, Scouting, Signs, And Events

Target: 28 total definitions.
Priority: P1 because these create route decisions beyond resources.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Repeatable services | 6 | wayfarer surgery, charter market, repair yard, muster bench, rest hearth, ferry ledger | 2x1, 2x2 | blocking visitable; daily/weekly or paid cadence; approach at entrance | Roads, towns, coast, industrial lanes |
| Shrines and progression sites | 8 | ember vow post, reedscript shrine, starlens sanctum, root oath stone, brass bell chapel, salt-memory dais | 1x1, 2x1, 2x2 | adjacent visit; one-time or cooldown; spell/progression metadata | Faction and biome variants |
| Scouting and information sites | 6 | beacon tower, mist lighthouse, survey kite, lens relay, hill cairn, reef signal buoy | 1x2, 2x2, 2x3 | blocking visitable; reveal radius or route clue; approach from road/path side | Ridge, coast, glass, marsh, road |
| Signs and event markers | 8 | border notice, old mileplate, drowned warning bell, orchard writ board, mine claim board, sealed omen marker | 1x1, 2x1 | non-blocking or blocking small body; interaction text/event only; no large reward by default | Scenario-specific and regional variants |

Implementation expectations:

- Signs/events may be appropriate but must stay compact and optional.
- Avoid turning signs into large text-panel gameplay. They are map authoring hooks and scenario cues.
- Shrines and services should be explicit about one-time versus repeatable cadence.

### Transit, Coast, And Shipyard-Like Objects

Target: 20 total definitions.
Priority: P1 because route control is central to adventure-map strategy.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Waypoints and road services | 3 | mileward post, charter marker, road oath stone | 1x1, 2x1 | visitable waypoint or map marker; may reveal/recover/mark route without moving the hero | Roads, town influence, frontier lanes |
| Two-way land transit | 5 | rope lift, root pass, pressure rail switch, mirror stair, basalt undergate | 1x2, 2x2, 2x3 | conditional pass or visit-to-transfer; linked endpoints; approach on both ends | Ridge, forest, brass, neutral ruins |
| One-way transit | 4 | wind chute, slipgate mirror, spillway drop, tide bore marker | 1x1, 1x2, 2x1 | one-way endpoint contract; clear exit safety | Coast, glass, river, ruins |
| Gates and route locks | 4 | charter gate, thorn seal, brass toll arch, reef chain boom | 2x1, 3x1, 2x2 | blocking conditional; may require key, owner, payment, event, or guard clear | Faction fronts and chokepoints |
| Coast and shipyard-like objects | 4 | skiffyard, harbor pilot post, bell buoy, wreck quay | 2x1, 2x2, 3x2, non-square shoreline masks | coast-adjacent approach; ship/route service metadata; water/land endpoints | Veil Coast, marsh, archipelago, river mouths |

Implementation expectations:

- Route objects must define linked approach endpoints where applicable.
- Coast objects must be authored so later ship/coast movement can adopt them without replacing object ids.
- Do not implement broad ship systems in this corrective P2.4 backlog.

### Dwellings And Guarded Dwellings

Target: 28 total definitions.
Priority: P1. The repo already has many dwellings, but they need normalization and high-value guarded variants.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Existing neutral dwelling normalization | 20 | normalize current lodge, kennel, roost, mooring, croft, yard, kiln, bothy, levy, hedge, skiffyard, hostel, camp, sump, scar, copse, house, warren, arsenal, gatehouse families | 2x1, 2x2 | blocking visitable; gate approach; weekly muster; body/approach metadata | Existing biome coverage |
| New basic dwellings | 4 | salt skirmisher pier, rootwatch hollow, ember cart yard, prism outrider post | 2x1, 2x2 | blocking visitable; light/standard guard options | Undercovered regions |
| Guarded high-value dwellings | 4 | storm rook eyrie, mirror-bound barracks, furnace oath yard, drowned crown hall | 2x2, 3x2, 3x3 | visible guard; stronger weekly recruit or unlock; approach remains clear under guard | Elite pockets and faction borders |

Implementation expectations:

- Existing dwellings count toward the target only after primary class, footprint tier, body mask, approach, interaction cadence, and editor metadata are normalized.
- Guarded dwellings are not the same as guarded reward sites; they provide recurring recruitment access.

### Guarded Reward Sites And Hostile Reward Pockets

Target: 22 total definitions.
Priority: P1/P2 because they create midgame objectives and map drama.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Minor guarded rewards | 6 | barrow cache, toll ruin, wreck locker, amber reliquary, slag purse vault, old orchard crypt | 2x1, 2x2 | blocking visitable; light/standard guard; one-time reward | All regions |
| Major guarded rewards | 6 | drowned reliquary, mirror archive, furnace vault, thorn crown hollow, storm-bell wreck, prism ossuary | 2x2, 2x3, 3x3 | heavy/elite guard; one-time or limited repeat; clear reward type | Ruin/reward pockets |
| Creature-bank-like sites | 5 | sealed muster fort, hive of reeds, glassbound eyrie, rust choir foundry, salt-wight convoy | 3x2, 3x3, 4x3 | fight-first; reward may include resources, artifacts, recruits, or route unlock | Biome/faction-flavored but original |
| Guarded route/reward hybrids | 5 | bridge bastion, chainboom fort, railblock camp, rootgate den, fog quay ambush | 2x2, 3x2, non-square | guard blocks route and protects reward; separate guarded object and approach metadata | Chokepoints and contested economy |

Implementation expectations:

- Guard links must not obscure the guarded object's class.
- "Dragon-Utopia-like" should mean elite guarded capstone reward design only. Do not copy identity, name, art, or encounter text.
- Rewards should declare category: resource, artifact, spell, recruit, scouting, route, town support, or objective.

### Faction Landmarks And Scenario Objectives

Target: 20 total definitions.
Priority: P2, after basic density and economy objects exist.

| Subcategory | Target | Example original families | Footprints | Blocking and interaction | Biome/region variants |
| --- | ---: | --- | --- | --- | --- |
| Faction landmarks | 9 | Embercourt signal court, Mireclaw bog drum, Sunvault prism relay, Thornwake graft arch, Brasshollow gauge shrine, Veilmourn bell mast | 1x1, 2x2, 3x2 | can be decorative, visitable, or capturable; must declare role | Faction-native and frontier variants |
| Scenario objective objects | 7 | broken treaty stone, sealed causeway lever, mirror anchor, crownless standard, drowned toll bell, orchard writ seal, brass oath wheel | 1x1, 2x2, 3x3 | objective interaction; may be guarded or stateful; approach explicit | Scenario-specific |
| Damaged/captured state variants | 4 | burned signal, repaired ferry stage, claimed mine head, withered rootgate | same as base object | alternate state metadata; not separate gameplay unless selected | Attached to route/economy/objective objects |

Implementation expectations:

- Landmarks should reinforce original world identity but remain mechanically clear.
- State variants should avoid duplicating full object definitions unless renderer/content tooling requires it later.

## Corrective Implementation Batches

These batches are sized for coding workers. They should be implemented in order unless the owner explicitly selects a different batch. Each batch should update `content/map_objects.json`, relevant linked site files, validators/reports, and progress state. No batch should claim all P2.4 content complete unless it meets the target count and validation bar.

### Batch 001: Core Density And Pickup Vocabulary

Target additions/normalizations: 30 objects.

Scope:

- Add 12 non-blocking decorations.
- Add 8 blocking or edge-blocker decorations.
- Add 6 common raw resource pickups for `gold`, `wood`, and `ore`.
- Add 4 staged rare-resource pickups with report-only/staged metadata.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json` only if pickups require linked site records.
- `tests/validate_repo.py`
- Strict overworld object fixtures/reports if schema coverage needs expansion.
- A short implementation report doc after validation.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- `git diff --check`

Non-goals:

- No rare-resource live economy activation.
- No renderer sprite import.
- No scenario placement migration beyond tiny fixture/proof placement if required by validation.
- No pathing adoption beyond validating authored metadata.

### Batch 002: Mines And Resource Fronts

Target additions/normalizations: 28 objects.

Scope:

- Add or normalize 9 common-resource mines/fronts.
- Add 9 rare-resource fronts with staged output metadata only.
- Add 6 permanent support producer buildings.
- Normalize 4 existing mine/resource objects to explicit footprint/body/approach contracts.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json`
- Economy/resource reports only where they read staged source metadata.
- Object validator fixtures.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`
- `python3 tests/validate_repo.py --overworld-object-report`
- `git diff --check`

Non-goals:

- No save migration or `SAVE_VERSION` bump.
- No market changes.
- No rare-resource costs, stockpile grants, or UI inventory activation.

### Batch 003: Services, Shrines, Scouting, Signs, And Events

Target additions/normalizations: 28 objects.

Scope:

- Add repeatable service families.
- Add shrine/progression families with explicit cadence.
- Add scouting/reveal structures.
- Add compact sign/event marker families for scenario authors.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json`
- Scenario fixture data only if a sign/event proof is needed.
- Validator/report fixtures.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- Focused smoke/report if reveal/service behavior is touched.
- `git diff --check`

Non-goals:

- No large text-dashboard UI.
- No broad spell-system implementation.
- No final scenario scripting system changes.

### Batch 004: Transit, Coast, And Route Control

Target additions/normalizations: 24 objects.

Scope:

- Add two-way transit objects.
- Add one-way transit objects.
- Add gates/route locks.
- Add coast, harbor, shipyard-like, buoy, ferry, and shoreline route objects.
- Normalize existing ferry/lift metadata if needed.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json`
- Route-effect authoring report fixtures.
- Map editor placement validation if endpoint metadata expands.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- Focused route-effect authoring validation if available.
- `git diff --check`

Non-goals:

- No full ship movement system.
- No broad runtime route-effect migration.
- No renderer asset ingestion.

### Batch 005: Dwelling Normalization And Guarded Dwellings

Target additions/normalizations: 28 objects.

Scope:

- Normalize existing neutral dwellings to primary class, footprint tier, body mask, approach, interaction cadence, and editor metadata.
- Add 4 new basic dwellings for undercovered regions.
- Add 4 guarded high-value dwellings.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json`
- `content/neutral_dwellings.json` if roster links need cleanup.
- Validator/report fixtures.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report` if guarded links use encounter records.
- `git diff --check`

Non-goals:

- No broad unit balance changes.
- No recruitment economy rebalance.
- No live AI behavior rewrite.

### Batch 006: Guarded Rewards And Elite Sites

Target additions/normalizations: 32 objects.

Scope:

- Add minor guarded reward sites.
- Add major guarded reward sites.
- Add creature-bank-like reward sites with original identities.
- Add guarded route/reward hybrids.
- Add clear guard-link metadata.

Likely files touched:

- `content/map_objects.json`
- `content/resource_sites.json`
- Neutral encounter content or fixtures if guard records are required.
- Validator/report fixtures.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `git diff --check`

Non-goals:

- No copied elite-site identity from source games.
- No broad battle balance pass.
- No artifact-system expansion except reward category references.

### Batch 007: Landmarks, Objectives, And State Variants

Target additions/normalizations: 25 objects.

Scope:

- Add faction landmark families.
- Add scenario objective object families.
- Add damaged/repaired/captured state variants or state metadata.
- Ensure landmarks remain map-readable and do not become text panels.

Likely files touched:

- `content/map_objects.json`
- Scenario fixture/content only for selected objective proof.
- Validator/report fixtures.
- `PLAN.md` or progress tracker only if sequencing changes.

Validation required:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --overworld-object-report`
- Focused scenario/objective report if scenario behavior is touched.
- `git diff --check`

Non-goals:

- No campaign expansion.
- No large UI overlays.
- No final art import.

## Deferred Beyond Corrective P2.4

Deferred to later explicit slices:

- Renderer sprite ingestion and final visual assets.
- Save migration, `SAVE_VERSION` changes, and persistent object-state schema changes.
- Rare-resource live economy activation, costs, markets, and stockpile UI.
- Full ship/naval movement system.
- Broad runtime route-effect adoption.
- Broad AI rewrite or final AI coefficients.
- Full random-map generator object grammar.
- Campaign-scale scenario scripting and objective chains.
- Final object animation/audio/VFX polish.
- HoMM-scale 1000+ editor-object breadth.

## Completion Bar For Corrective P2.4

Corrective P2.4 should be considered complete only when:

- The repo has a broad authored object vocabulary near the 220-object target or the owner accepts a revised target.
- Major categories above have actual `map_objects` entries, not only docs.
- New objects distinguish visual footprint, blocking `body_tiles`, and approach/interaction tiles.
- Decorations are split into blocking and non-blocking non-interactable objects.
- Current resources remain compatible: live `gold`, `wood`, `ore`; staged rare resources remain staged unless a later economy slice activates them.
- Validator/report coverage proves the authored metadata is structurally usable.
- P2.5 resumes only after the owner accepts the P2.4 corrective content baseline or explicitly overrides the stop.
