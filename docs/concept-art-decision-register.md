# Concept Art Decision Register

Status: P2.2 curation register, not runtime asset approval.
Date: 2026-04-27.
Slice: `concept-art-decision-register-10184`.

## Scope

This register consolidates the accept, reject, and defer calls from the concept-art pipeline and batch reviews. It does not import, approve, copy, trace, crop, rename, or register generated PNGs as runtime/source assets.

Source evidence:

- [Concept Art Pipeline](concept-art-pipeline.md)
- [Concept Art Batch 001 Review](concept-art-batch-001-review.md)
- [Concept Art Batch 002 Review](concept-art-batch-002-review.md)
- [Concept Art Batch 003 Review](concept-art-batch-003-review.md)
- [Concept Art Batch 004 Review](concept-art-batch-004-review.md)
- [Concept Art Batch 005 Review](concept-art-batch-005-review.md)
- [Concept Art Implementation Briefs](concept-art-implementation-briefs.md)

## Decision Boundary

Accepted means accepted as external concept evidence and implementation-brief direction only. It does not mean final art, final silhouettes, final palette, final town layouts, final UI, final map data, or runtime asset ingestion.

## Accepted For Brief Direction

| Direction | Source | Decision | Implementation implication |
| --- | --- | --- | --- |
| Infrastructure-fantasy world language: roads, locks, bells, lenses, rails, roots, ferries, harbors, and route law. | [Batch 001](concept-art-batch-001-review.md), [Batch 002](concept-art-batch-002-review.md), [Pipeline](concept-art-pipeline.md) | Accepted as the shared visual foundation. | Future art/content work should translate visual identity into route control, resource pressure, visible accordance anchors, and readable object classes instead of generic medieval fantasy scenery. |
| Ninefold Confluence / route-readability mood. | [Batch 002](concept-art-batch-002-review.md) | Accepted as route-readability evidence, not direct map art. | Region and map workers may use it to reason about hub-and-branch routes, negative space, and object pockets, but must create original terrain, layouts, and object placements. |
| Embercourt town and object direction. | [Batch 001](concept-art-batch-001-review.md), [Batch 003](concept-art-batch-003-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Accepted as the strongest town/object implementation direction. | Brief work can proceed around a civic river-law `3x2` overworld town, lock gates, toll bridge courts, beacon courts, mills, granaries, barge cranes, footprint/approach metadata, state variants, and lock/beacon animation cues. |
| Mireclaw town and object direction. | [Batch 001](concept-art-batch-001-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Accepted as strong town/object evidence after curation. | Brief work can proceed around low marsh town silhouettes, ferries, drums, peat cuts, mudglass deposits, route warnings, linked transit endpoints, and anti-horror/non-raider constraints. |
| Veilmourn material, prop, harbor, and town/object direction. | [Batch 002](concept-art-batch-002-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md) | Accepted for materials, props, harbor language, and first unit-ladder evidence. | Future briefs should emphasize bell harbors, mirror drydocks, black-lacquered boats, charts, memory-salt salvage, fog-route logistics, and obituary law while avoiding pirate, undead, rogue, and gothic-harbor drift. |
| Sunvault calibration, object, building, support-role, and seven-tier direction. | [Batch 002](concept-art-batch-002-review.md), [Batch 004](concept-art-batch-004-review.md) | Accepted as useful calibration-engineering direction and likely enough to exit the anti-paladin recalibration loop. | Future briefs may use survey tools, lens tripods, crystal carts, prism adepts, chorister crews, mirror panels, array carts, and relay/battery silhouettes, while deciding whether high tiers are crews, constructs, wagons, or single large battlefield pieces. |
| Thornwake town/object and support-silhouette direction. | [Batch 001](concept-art-batch-001-review.md), [Batch 003](concept-art-batch-003-review.md) | Accepted for root-road, town/object, and support-role evidence. | Future briefs may use root gates, graft racks, amber lanterns, thorn toll arches, bramble rings, nursery logic, and living-road survey cues, while keeping toll law and renewal debt explicit. |
| Brasshollow object, building, route, and mine-site direction. | [Batch 001](concept-art-batch-001-review.md), [Batch 003](concept-art-batch-003-review.md) | Accepted for furnace/rail/object evidence. | Future briefs may use furnace doors, pressure rails, quarry gantries, drill platforms, gauges, heat vents, slag tiles, and mine-site logic, while adding contract-law, debt-seal, repair-window, and worker-court cues. |
| Route-law and transit object families. | [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Accepted as sufficient evidence for brief prep. | Briefs should separate tollhouses, ferry chains, root gates, rail switches, prism markers, bell docks, mirror/fog markers, route effects, linked endpoints, passability, ownership, and repair/blocked states. |
| Persistent resource fronts and economy sites. | [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Accepted as sufficient evidence for economy-site brief prep. | Future schema/content planning should define resource outputs, footprint, approach side, guard profile, capture state, output cadence, damaged/exhausted variants, and resource-specific silhouettes before any JSON migration. |
| Guarded rewards, pickups, faction landmarks, and neutral encounter presentation. | [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Accepted as object-class evidence, with neutral army presentation still deferred. | Briefs should keep pickups physical and small, guarded rewards visibly risky, landmarks distinct from towns, and neutral encounters fair and visible before combat. |

## Rejected

| Rejected item | Source | Reason | Implementation implication |
| --- | --- | --- | --- |
| Repo ingestion of all generated PNGs. | [Batch 001](concept-art-batch-001-review.md), [Batch 002](concept-art-batch-002-review.md), [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Generated studies remain external curation evidence. | Do not add generated PNGs to `art/`, runtime asset folders, content JSON, imports, manifests, scenes, or renderer code without a later explicit asset-ingestion slice. |
| Direct copying of generated layouts, silhouettes, symbols, banners, pseudo-heraldry, labels, palette chips, guard figures, object arrangements, or exact prop shapes. | [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | These details are generated artifacts and may carry legal, originality, or readability risk. | Implementation briefs must describe original shape language, material rules, footprint logic, and gameplay readability targets rather than reproducing source images. |
| Veilmourn batch 001 sheet as approvable visual reference. | [Batch 001](concept-art-batch-001-review.md), [Batch 002](concept-art-batch-002-review.md) | It included embedded title/label/tagline-style text, violating pipeline constraints. | Use the no-text batch 002 revision and later harbor/object evidence instead; do not carry generated text, label layout, or symbol marks into briefs. |
| Generic or derivative faction reads: human castle/holy order, swamp horror/raider, angelic or paladin light order, elf/druid/treant forest faction, dwarf/decorative steampunk machine army, pirate/undead/assassin harbor faction. | [Pipeline](concept-art-pipeline.md), [Batch 001](concept-art-batch-001-review.md), [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md) | These directions violate the originality and anti-generic constraints. | Every future brief should carry explicit anti-generic notes and world-specific anchors for law, logistics, accordance, economy, and route control. |
| UI-like object badges, decorative base plates, helper glyphs, full-screen panel farms, or text-heavy scenic compositions. | [Pipeline](concept-art-pipeline.md), [Implementation Briefs](concept-art-implementation-briefs.md) | They undermine scenic/play-surface readability and screen composition rules. | Towns and objects must read as world objects with compact state cues, not as UI frames or panels placed on scenery. |
| Hidden-punishment encounters with no visible warning. | [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Encounter danger must be fair and legible before contact. | Ambush states may be uncertain, but future encounter objects need visible danger cues, guard links, or route-warning states. |

## Deferred

| Deferred item | Source | Why deferred | Needed before implementation |
| --- | --- | --- | --- |
| Final AcOrP approval of specific accepted/deferred studies. | [Batch 001](concept-art-batch-001-review.md), [Batch 002](concept-art-batch-002-review.md), [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Review docs repeatedly state AcOrP curation remains open and no image is approved as final art. | Use this register for direction, but keep asset import/final art approval blocked until the asset-ingestion boundary child or later art approval slice resolves provenance and approval. |
| Exact prompt text, seed, model/version metadata, and generation settings. | [Batch 001](concept-art-batch-001-review.md), [Batch 002](concept-art-batch-002-review.md), [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md), [Batch 005](concept-art-batch-005-review.md) | Prompt/model metadata is not present in the repo. | Recover external tool history before any formal provenance review or final art approval. |
| Unit-ladder approval for Embercourt, Mireclaw, Thornwake, Brasshollow, and Veilmourn. | [Batch 003](concept-art-batch-003-review.md), [Batch 004](concept-art-batch-004-review.md) | Current sheets are stronger for town/object/support language than final combat tier progression. | Require silhouette-first seven-tier passes or explicit AcOrP acceptance before combat sprite, animation, or unit JSON visual migration work. |
| Sunvault high-tier implementation form. | [Batch 004](concept-art-batch-004-review.md) | The direction is useful, but some rows imply crews or machinery rather than a single unit body. | Decide whether high tiers are multi-figure crews, construct wagons, or single large battlefield pieces before combat sprite and animation planning. |
| Neutral army presentation model. | [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Camps are useful but should not represent every neutral army. | Decide whether visible neutral armies are first-class overworld objects separate from camps, dwellings, guarded sites, and reward objects. |
| Runtime asset ingestion and source-asset boundary. | [Pipeline](concept-art-pipeline.md), [Implementation Briefs](concept-art-implementation-briefs.md) | P2.2 first child is documentation/curation governance only. | Resolve `concept-art-asset-ingestion-boundary-10184` before any generated image, derivative study, processed art, or runtime asset import. |
| First implementation brief track selection. | [Batch 005](concept-art-batch-005-review.md), [Implementation Briefs](concept-art-implementation-briefs.md) | Multiple directions are viable, but this child only records the decision register. | Resolve `concept-art-implementation-brief-selection-10184`; the highest-evidence candidates are Embercourt town/object, Mireclaw town/object, and core overworld object classes. |

## Near-Term Recommendation

The next P2.2 child should select one implementation brief track, not start asset ingestion or runtime work. The strongest documented candidates are:

- Embercourt town/object direction.
- Mireclaw town/object direction.
- Core overworld object classes.

If no single track is chosen by the next child, defer selection explicitly rather than treating all accepted evidence as implementation approval.
