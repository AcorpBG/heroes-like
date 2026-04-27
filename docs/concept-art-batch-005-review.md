# Concept Art Batch 005 Review

Status: broader overworld object and town-adjacent concept studies logged for curation; generated PNGs remain external.
Date: 2026-04-26.
Slice: broader-overworld-object-town-studies-10184.

## Scope

This note records three broader overworld object/town-adjacent concept studies generated after `docs/concept-art-batch-004-review.md`: route-law/transit objects, persistent resource fronts/economy sites, and neutral encounter/reward/landmark object families. This is a review and planning artifact only. No generated image was moved, copied, imported, renamed, or registered as a runtime asset in this repository.

External source directory:

```text
/root/.openclaw/media/tool-image-generation
```

Source documents:

- `docs/overworld-object-taxonomy-density.md`
- `docs/concept-art-pipeline.md`
- `docs/concept-art-batch-001-review.md`
- `docs/concept-art-batch-002-review.md`
- `docs/concept-art-batch-003-review.md`
- `docs/concept-art-batch-004-review.md`
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`

Prompt metadata note: exact prompt/model seed metadata is not present in the repository. This review records the source briefs, prompt intent, and preliminary curation from the external filenames and visual outputs.

## Batch Inventory

| Surface | External filename | Source brief | Prompt intent |
| --- | --- | --- | --- |
| Route-law and transit object families | `overworld-route-law-transit-object-sheet-01---f5c2abda-24c1-43d5-9cb8-6364240ee8f2.png` | Route-law objects and transit sites from the object taxonomy: tollhouses, ferry chains, root gates, rail switches, prism road markers, fog/mirror markers, damaged/captured state variants, and readable approach sides. | Test compact object families that communicate road control, path opening, movement discount, route taxation, ownership state, and conditional passage at strategy-map scale. |
| Persistent resource fronts and economy sites | `overworld-resource-front-object-sheet-01---41395c93-5440-40e5-a28e-f278ff64ac2f.png` | Persistent resource fronts from the economy and object foundations: ore quarry, aetherglass/crystal orchard, peatwax cuts, embergrain yard, verdant graft nursery, furnace/contract site, memory-salt or salvage field, and wood/industrial yards. | Test capturable economy-site silhouettes with production state, damaged/claimed variants, clear entrances, ownership signals, and enough material difference to avoid generic mine tokens. |
| Neutral encounters, guarded rewards, pickups, and faction landmarks | `overworld-encounter-reward-landmark-object-sheet-01---58c10152-7c2c-4e74-839b-e0a6efd3ccb1.png` | Neutral encounter presentation, guarded reward sites, pickups, faction landmarks, and town-adjacent world objects from the taxonomy and faction bibles. | Test visible guard presence, reward/readiness cues, small pickups, major landmarks, and faction-flavored object silhouettes without turning the adventure map into a dense icon board. |

## Preliminary Curation

Batch-level read:

- Accept as external concept evidence only. The batch usefully broadens the object/town evidence beyond faction sheets and is sufficient to move into compact implementation-brief prep after AcOrP curation.
- Do not approve any generated image as direct map art, final object sprite reference, town layout, UI icon, terrain tile, or source asset. Future briefs must translate motif, class, footprint, approach, state, and readability constraints into original Godot 4 2D production targets.
- The strongest production value is classification breadth: route-law/transit, persistent economy fronts, guarded rewards, pickups, neutral camps, and faction landmarks can now be briefed as separate object classes instead of being inferred only from faction town studies.
- This batch also reinforces that object art needs state families, not one-off pretty props: neutral/claimed/damaged, blocked/open, exhausted/active, guarded/cleared, and faction-controlled variants should be planned from the start.

Route-law and transit object families:

- Works: the sheet provides a useful route-control vocabulary: tollhouse plazas, bridge/toll approaches, ferry platforms with chain posts, root gates with clear openings, rail switch circles and track junctions, crystal markers, hanging lantern/bell objects, and mirror/prism road markers.
- Works: several rows show state variation clearly enough for later implementation briefs: intact versus damaged tollhouses, claimed versus neutral ferry platforms, living versus corrupted root gates, and clean versus ruined rail switches.
- Works: approach sides are visually legible on many objects. Tollhouse plazas imply front/road approach, ferries imply water-edge approach, root gates imply pass-through corridor, rail switches imply track-linked visit points, and prism/mirror markers imply adjacent service use rather than full building entry.
- Risks: the red-roof and blue-roof tollhouses can drift toward generic castle/kingdom gatehouses if Embercourt road law, Sunvault calibration, or faction-specific route rules are not foregrounded. The blue banners and shield-like marks must not be copied.
- Risks: the root gates are useful but can become generic magical forest portals if Thornwake toll law, route taxation, graft markers, and living-road survey logic are omitted.
- Risks: some route objects are too large or base-like for dense maps. Future briefs must define footprint tiers, route clearance, negative space, and whether each object blocks, discounts, opens, or merely marks a path.
- Decision: keep as sufficient route-law/transit evidence for brief prep. Require briefs to separate Embercourt toll/bridge objects, Mireclaw ferry/chain objects, Thornwake root-gate objects, Brasshollow rail-switch objects, Sunvault prism/relay markers, and Veilmourn bell/mirror/fog markers instead of using one generic transit kit.

Persistent resource fronts and economy sites:

- Works: the sheet gives strong resource-front categories: fenced ore quarries, crystal/aetherglass orchards, peat/black-fuel cuts, granary or embergrain yards, graft/nursery plots, furnace/contract foundries, wreck/salt basins, and wood or rail-yard production sites.
- Works: several resource families include ruined, active, and claimed-looking variants, which supports future state overlays and capture/counter-capture rules better than one static mine sprite.
- Works: the best objects show entrances and work surfaces: quarry ramps, field paths, fenced gates, furnace stairs, rail/wood approaches, and salvage basin edges. These can support explicit visit-tile and approach-side metadata.
- Risks: many objects are highly square, fenced, and isometric, which can make every economy site read like a small fort or mini-town. Implementation briefs need stronger silhouette differences and simpler map-scale reads.
- Risks: blue banners and repeated stone plinths risk becoming a universal ownership visual. Ownership state should be data-driven and faction-aware, not copied from the sheet.
- Risks: resource identity is uneven. Ore, crystal, furnace, and wood read strongly; peatwax, embergrain, verdant grafts, brass scrip, and memory salt will need clearer material anchors in briefs so they do not collapse into generic farm, coal pit, garden, foundry, or wreck field.
- Decision: keep as sufficient persistent resource-front evidence for economy-site brief prep. Require each future resource-site brief to define primary resource, footprint, owner/capture state, guard tier, approach side, production animation hook, exhausted/damaged variant, and how it differs from towns and neutral dwellings.

Neutral encounters, guarded rewards, pickups, and faction landmarks:

- Works: the sheet covers the missing reward/landmark layer well: visible neutral camps, guarded mirror ruins, observatory/lens structures, mire shrines, furnace vaults, orchard graves, wreck salvage, small pickups, root gates, Sunvault towers, Brasshollow crane/rail sites, Veilmourn bell harbor markers, and several faction-flavored landmarks.
- Works: guard presence is explicit around several large sites. The player can read "risk before reward" through nearby figures, camp layouts, blocked entries, torches, banners, and guarded stairs instead of through a surprise panel.
- Works: the pickup row is useful as a reminder that small rewards should be physical world props: coin sacks, crystal clusters, graft bundles, blue flame cairns, egg/nest caches, road stones, scroll bundles, antler shrines, gold ore chunks, and bell/marker posts.
- Works: the bottom-row landmarks help separate faction identity from full towns. Embercourt/Beacon, Mireclaw drum/shrine, Sunvault relay, Thornwake root arch, Brasshollow crane/rail, and Veilmourn bell/dock objects can become local influence markers or high-value sites.
- Risks: some large guarded sites are too iconic and self-contained; direct use would make them feel like copied set pieces rather than map grammar. They need to be decomposed into object families, reward logic, and smaller footprint variants.
- Risks: the red tent camp risks generic bandit-camp language, the observatory risks generic telescope tower, the furnace vault risks generic lava dungeon, and the root arch risks generic tree portal if faction rules and world materials are not explicit.
- Risks: neutral encounters still need a first-class visible unit/army object model. Camps are useful for guarded sites, but wandering or blocking neutral stacks should not all become buildings.
- Decision: keep as sufficient neutral encounter, guarded reward, pickup, and landmark evidence for brief prep. Defer final neutral encounter presentation until AcOrP confirms whether neutral armies appear as first-class overworld objects separate from camps, dwellings, and reward sites.

## Risks, Rejections, And Deferred Notes

- Rejected for repo ingestion: all generated PNGs. They remain external only and are not source assets.
- Rejected for direct use: exact object silhouettes, exact town-adjacent layouts, exact banners, shield marks, state icons, color chips, guard figures, bridge/ferry/rail arrangements, and any generated pseudo-heraldry.
- Deferred: exact prompt text, seed, model/version metadata, and generation settings. Recover them from external tool history if available before any later art provenance review.
- Deferred: AcOrP approval. Batch 005 should be sent or confirmed externally for accept/reject/defer calls, but no image is approved final direction yet.
- Deferred: final town art approval. This batch gives object/town-adjacent evidence, while town exterior implementation briefs should still use the stronger faction-town evidence from batches 003 and 004.
- Risk: state variants may be mistaken for a permission to copy color swaps. State design should be authored as gameplay/readability rules first: neutral, owned, damaged, blocked, open, exhausted, renewed, guarded, and cleared.
- Risk: dense object sheets can tempt map clutter. Future implementation must obey the density model: routes and negative space first, then object pockets, guards, landmarks, and decoration.
- Risk: object classes can blur if every site is a fenced compound. Briefs must keep pickups small, encounters visibly mobile or hostile, economy sites productive, guarded rewards risky, landmarks identity-bearing, transit objects route-changing, and towns dominant but not over-paneled.

## Slice Decision

The broader overworld object/town study evidence is sufficient for the next planning stage. The current slice `broader-overworld-object-town-studies-10184` can be marked completed, with the next current slice set to concept-art implementation-brief prep for selected accepted directions.

This does not mean final art is approved. It means there is enough visual evidence to draft implementation briefs for the highest-confidence object families while AcOrP curation remains open.

## Next Steps

1. Send or confirm delivery of these three external PNGs to AcOrP without importing them into the repo.
2. Ask AcOrP for accept/reject/defer calls on:
   - Route-law/transit direction, especially tollhouses, ferries, root gates, rail switches, and prism/bell/mirror markers.
   - Persistent resource-front direction and whether the site families are distinct enough for staged economy-site briefs.
   - Neutral encounter, guarded reward, pickup, and faction landmark direction, especially whether camps and first-class neutral army objects should be separate.
3. Start `concept-art-implementation-brief-prep-10184` as a documentation/planning slice. Suggested first briefs:
   - Embercourt town/object brief using batch 003 plus route-law objects from batch 005.
   - Mireclaw town/object brief using batch 004 plus ferry/peat/front evidence from batch 005.
   - Core overworld object-class brief covering pickups, transit objects, resource fronts, guarded rewards, landmarks, and neutral encounters.
4. In every brief, specify footprint, approach side, passability, state variants, guard expectations, reward/risk read, animation hook, ownership/capture handling, and rejection constraints.
5. Do not begin JSON migration, map placement, renderer sprite ingestion, or runtime asset import until the implementation briefs are reviewed and their first target slice is explicitly selected.
