# Concept Art Implementation Briefs

Status: implementation-brief prep and P2.2 selection reference, not final asset approval.
Date: 2026-04-27.
Slice: `concept-art-implementation-brief-selection-10184`.

## Scope

These briefs translate the highest-confidence external concept-art evidence into production planning targets. Generated PNGs remain external concept evidence only. Do not copy, trace, crop, import, register, or treat them as runtime/source assets.

AcOrP curation is still open. Planning may continue from these briefs, but implementation slices must preserve the rejection constraints and should not present generated-image details as approved final art.

Primary source docs:

- `docs/concept-art-pipeline.md`
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/economy-overhaul-foundation.md`
- `docs/animation-systems-foundation.md`
- `docs/concept-art-batch-003-review.md`
- `docs/concept-art-batch-004-review.md`
- `docs/concept-art-batch-005-review.md`

## Selected Follow-Up Track

Selected track: **Embercourt Town And Object Direction**.

Selection rationale:

- `docs/concept-art-decision-register.md` names Embercourt as the strongest town/object implementation direction.
- Source evidence spans batch 001 identity, batch 003 town/object study, and batch 005 shared route, resource, encounter, reward, and landmark object sheets.
- The brief already defines concrete implementation implications: `3x2` overworld town footprint, road/river approach logic, lock gates, toll bridge courts, beacon courts, mills, granaries, state variants, route-object behavior, and lock/beacon/capture animation hooks.
- The track strengthens existing Phase 2 foundations without requiring final art approval, generated PNG import, renderer changes, or production JSON migration in this governance slice.

Future implementation reference:

- Start from the Embercourt section below as the selected brief for a later explicit runtime/content slice.
- Create original runtime art/content from the motifs and constraints, not from copied generated-image layouts, silhouettes, banners, symbols, labels, or palette chips.
- Define object metadata before production migration: footprint/body tiles, visit anchor, approach sides, passability class, primary class, ownership/capture states, route effects, guard expectations, and animation cue ids.
- Keep economy-resource work staged behind the `embergrain` and `timber`/`wood` compatibility decisions named in the prerequisites.

Explicit non-goals for this selection:

- No generated PNG import, crop, copy, trace, rename, manifest registration, scene hookup, renderer change, or runtime asset approval.
- No final Embercourt town art approval.
- No unit-ladder, combat sprite, economy migration, save migration, or broad object-schema migration.
- Mireclaw and Core Overworld Object Classes remain accepted concept evidence, but they are not the selected follow-up track for this child.

## Shared Implementation Rules

- Intended surface: Godot 4 2D overworld first, with town-screen and object-animation hooks retained for later.
- Translation rule: use generated studies to identify motif, silhouette family, footprint logic, palette range, and state needs; produce original runtime art and data.
- Generated images are not source assets. Exact layouts, object silhouettes, banners, pseudo-heraldry, shield marks, labels, color chips, and guard figures are rejected for direct use.
- Towns remain large world objects. They must not use visible editor helper overlays, base plates, or UI badge frames.
- Vistable objects need explicit class, footprint, approach side, passability, interaction cadence, guard expectation, state variants, and animation hooks before JSON migration.
- Scenic/play surface readability wins over object-sheet density. Leave negative space around towns, route junctions, guarded sites, and active hero paths.

## Embercourt Town And Object Direction

Source review docs and external filenames:

- `docs/concept-art-batch-001-review.md`: `embercourt-identity-study-01---8cf8ef05-4722-4e09-8385-e30eb9486a30.png`
- `docs/concept-art-batch-003-review.md`: `embercourt-town-object-study-02---2c1eee21-9540-4cda-acda-fc57435d470b.png`
- `docs/concept-art-batch-005-review.md`: `overworld-route-law-transit-object-sheet-01---f5c2abda-24c1-43d5-9cb8-6364240ee8f2.png`, `overworld-resource-front-object-sheet-01---41395c93-5440-40e5-a28e-f278ff64ac2f.png`, `overworld-encounter-reward-landmark-object-sheet-01---58c10152-7c2c-4e74-839b-e0a6efd3ccb1.png`

Intended game surface:

- Primary: overworld town landmark and Emberflow Basin object families.
- Secondary: future Embercourt town-screen building language and object state animation.

Design intent:

- Embercourt should read as civic river law, public works, ration security, road control, and beacon discipline.
- The town is a guarded river-lock complex, not a castle, kingdom capital, or holy order citadel.
- Supporting objects should make crossings, tolls, granaries, mills, beacons, and road courts strategically legible.

Original motifs to translate:

- Stone weirs, lock gates, bridge spans, barge cranes, mill islands, granary barges, beacon towers, court bells, ash-writ posts, red signal ceramics, pale masonry, wet timber, iron chains.
- Translate as simplified original silhouettes and material rules. Do not copy the generated town layout, roofs, tower profiles, banners, or exact bridge/crane arrangements.

Footprint and approach guidance:

- Town footprint: large `3x2` overworld object, with the authored anchor/visit tile at the bottom-middle or lower road-facing side unless a scenario explicitly places it against water and uses a side approach.
- Town body: blocking once true footprint rules exist; no visible footprint helper glyphs in normal play.
- Toll bridge court: small/medium `2x1` or `2x2`, road-aligned, primary approach from road/front side; may have two linked approach sides when it controls a crossing.
- Lock gate: small/medium linear object, path-adjacent or path-spanning, approach from road/riverbank side; pass-through state can open/close a route.
- Beacon court/shrine: small `1x2` or `2x1`, adjacent visit from front/lower side.
- Tollhouse mill, timber yard, embergrain yard: medium `2x2`, entrance on work-yard/front side with road adjacency preferred.

Passability and interaction class:

- Town: blocking visitable town, separate from normal site interaction.
- Toll bridge court and lock gate: transit / route object; may also be persistent economy if owned.
- Tollhouse mill, timber yard, embergrain yard: persistent economy site.
- Beacon court shrine and public ration depot: interactable service/support site.
- Writ bundle, granary sack cache, timber cart: pickup, usually enter-to-collect.
- Lockwall remnants, levee cuts, beacon ash poles: decoration, edge blocker, or non-interactable route texture.

State variants:

- Town: neutral/unowned if scenario allows, player-owned, enemy-owned, occupied/contested, damaged/retaken, defended/readiness raised.
- Transit: closed/blocked, open, taxed, discounted, damaged, repaired, neutral, Embercourt-controlled, enemy-controlled.
- Economy sites: neutral, claimed, enemy-held, pillaged/damaged, output-ready, exhausted if limited-yield.
- Services: available, used this cadence, refreshed, disabled/damaged.
- Pickups: uncollected, highlighted/focused, collected/removed.

Animation hooks:

- Water wheels, lock-gate movement, beacon pulses, lantern glows, court-bell strike, barge crane sway, mill turning, ration depot activity.
- Capture cue should be material and state-based: beacon relight, toll chain reset, small ownership pennant or color accent, not a copied banner.
- Route-object cue should show opened/closed state through gate position, chain slack/tension, or beacon signal, not a large text panel.

Readability constraints:

- At strategy-map scale, the first read must be crossing, lock, beacon, granary, or civic road control.
- Keep roofs and civic ornament subordinate to water-control and road-control shapes.
- Leave road and river lanes visually open; do not crowd the town with all possible buildings in the overworld sprite.
- Red signal accents may help faction read, but ownership cannot rely on red alone.

Rejection constraints:

- Reject generic human castle, knightly citadel, holy order, palace, heroic kingdom gatehouse, or copied HoMM town composition.
- Reject direct generated banners, pseudo-heraldry, roof silhouettes, object arrangements, and exact bridge/lock/crane designs.
- Reject large text panels, badges, decorative base plates, helper circles, or UI-like marker frames around the town.

Implementation prerequisites:

- Object/town schema plan for `footprint`, `approach_sides`, `passability_class`, `primary_class`, `state_variants`, `route_effect`, and `ownership_state`.
- Resource schema migration plan for `embergrain` and `timber`/`wood` compatibility before Embercourt economy sites become production content.
- Renderer/editor plan for true blocking body tiles versus visit/approach tiles.
- Animation cue catalog entries for lock, beacon, capture, damaged, repaired, and output-ready states.

## Mireclaw Town And Object Direction

Source review docs and external filenames:

- `docs/concept-art-batch-001-review.md`: `mireclaw-identity-study-01---41f0bcb3-7fa9-4e44-9ce4-fa68f2cb5f42.png`
- `docs/concept-art-batch-004-review.md`: `mireclaw-town-object-study-02---9d19432e-16f5-4856-87f6-9198e80abfe5.png`
- `docs/concept-art-batch-005-review.md`: `overworld-route-law-transit-object-sheet-01---f5c2abda-24c1-43d5-9cb8-6364240ee8f2.png`, `overworld-resource-front-object-sheet-01---41395c93-5440-40e5-a28e-f278ff64ac2f.png`, `overworld-encounter-reward-landmark-object-sheet-01---58c10152-7c2c-4e74-839b-e0a6efd3ccb1.png`

Intended game surface:

- Primary: overworld town landmark and Drowned Marches object families.
- Secondary: future Mireclaw town-screen building language, ferry/transit hooks, and marsh-site animation.

Design intent:

- Mireclaw should read as marsh sovereignty, ferry law, shrine drums, peat economy, hidden route control, and wounded-prey pressure.
- The town is a low, wet, mobile settlement embedded in lanes and platforms, not a walled town or horror swamp camp.
- Supporting objects should make unsafe shortcuts, peat production, ferry control, reed caches, drum shrines, and den pressure visible.

Original motifs to translate:

- Low drowned pilings, chain ferries, floating platforms, drum towers, reed islands, hidden slips, bone or reed markers, peat blocks, mudglass glints, shrine posts, den pens, ferry booms.
- Translate as compact original silhouettes. Do not copy the generated dock layout, beast shapes, shrine arrangements, red cloth marks, or exact platform clusters.

Footprint and approach guidance:

- Town footprint: large `3x2`, horizontally low and marsh-integrated; authored anchor/visit tile should be bottom-middle or lower dry-lane side, with optional side approach for ferry-adjacent maps.
- Chain ferry: small/medium `2x1` or path-paired endpoints; approach from lane/water-edge side, with linked exit marker when route logic supports it.
- Drum island shrine: small `1x1` or `2x1`, adjacent visit from safe lane; should not block the main path unless authored as a chokepoint.
- Peat cut and mudglass deposit: medium `2x2`, work-surface entrance on dry edge or plank path.
- Beast den/pen: small/medium, adjacent visit from den mouth or fence opening; guard state should not hide the object's class.
- Reed-marked cache and peatwax votive: micro `1x1`, enter-to-collect or adjacent if placed in water-edge art.

Passability and interaction class:

- Town: blocking visitable town.
- Chain ferry and drowned causeway: transit / route object, often conditional pass.
- Peat cut: persistent economy site.
- Drum island shrine and sporewake post: shrine/service, sometimes guarded.
- Beast den/pen: neutral dwelling or guarded support site depending on authored roster.
- Reed sea clumps and chainboom wrecks: decoration, soft blocker, edge blocker, or ambush-lane texture.
- Visible Mireclaw-style neutral packs must remain encounters, not buildings.

State variants:

- Town: neutral/hidden if scenario supports, player-owned, enemy-owned, occupied/contested, damaged after raid, defended.
- Ferry: neutral, claimed, enemy-held, toll active, ambush-warning, blocked, repaired/open.
- Peat/mudglass sites: neutral, claimed, enemy-held, pillaged, flooded/damaged, output-ready.
- Shrines: available, used, refreshed, corrupted/blocked, guarded.
- Dens: guarded, recruit-available, visited, refreshed, cleared if one-time.
- Pickups: uncollected, collected/removed, route-reveal variant for reed-marked caches.

Animation hooks:

- Chain tension/slack, ferry rocking, reed sway, low drum pulse, peat smoke, mudglass glint, shrine-votive flicker, den breathing/cage shift, water ripple.
- Ambush warning can use reed motion, drum beat, spoor, or guard silhouette. It must be visible before combat.
- Capture cues should feel like route control: chain raised, drum answered, shrine marker reset, not a copied flag swap.

Readability constraints:

- At map scale, the first read must be low wet route control, ferry/drum/peat/shrine function, or visible marsh danger.
- Keep the town compact enough for `3x2`; do not preserve the generated horizontal sprawl.
- Use bone and red cloth carefully. They may support culture, but cannot become horror, raider, or generic savage shorthand.
- Main path, side path, and risky marsh pocket must remain visually separable.

Rejection constraints:

- Reject generic swamp monster/orc/goblin/tribal-raider identity, horror swamp palette, blood-cult staging, or monster-camp town logic.
- Reject direct generated dock layouts, beast pen silhouettes, shrine symbols, banner marks, and exact ferry platform forms.
- Reject hidden-punishment encounters with no visible warning.

Implementation prerequisites:

- Object schema plan for transit endpoints, conditional pass, ambush-warning state, and linked approach/exit tiles.
- Economy resource plan for `peatwax` and local fuel/rite outputs before peat cuts become production sites.
- Neutral encounter presentation decision: whether visible neutral armies are first-class overworld objects separate from camps, dwellings, and guarded sites.
- Animation cue catalog entries for ferry, drum, reed warning, capture, damaged/flooded, and refreshed states.

## Core Overworld Object Classes

Source review docs and external filenames:

- `docs/concept-art-batch-002-review.md`: `aurelion-reach-route-readability-study-02---70d345b7-679e-4887-9f72-ec09ec6ad377.png`
- `docs/concept-art-batch-005-review.md`: `overworld-route-law-transit-object-sheet-01---f5c2abda-24c1-43d5-9cb8-6364240ee8f2.png`, `overworld-resource-front-object-sheet-01---41395c93-5440-40e5-a28e-f278ff64ac2f.png`, `overworld-encounter-reward-landmark-object-sheet-01---58c10152-7c2c-4e74-839b-e0a6efd3ccb1.png`
- Supporting faction-town sources: `embercourt-town-object-study-02---2c1eee21-9540-4cda-acda-fc57435d470b.png`, `mireclaw-town-object-study-02---9d19432e-16f5-4856-87f6-9198e80abfe5.png`

Intended game surface:

- Primary: overworld object schema, placement grammar, renderer/editor hints, and later object sprite briefs.
- Secondary: economy-site migration, AI object valuation, animation cue planning, and scenario placement.

Design intent:

- Move the overworld away from generic markers and toward readable world objects with explicit class, route logic, risk, reward, ownership, and state.
- Keep route structure and negative space primary. Object density should create decisions, not a dense icon board.

### Route-Law And Transit Objects

Motifs to translate:

- Tollhouse plazas, bridge approaches, ferry chains, root gates, rail switches, prism road markers, bell docks, mirror/fog markers, damaged route infrastructure.

Footprint and approach:

- Micro/small `1x1` for markers; small `2x1` for tollhouses, ferry posts, prism/bell markers; medium `2x2` for rail switches, root gates, bridge bastions, relay crowns.
- Approach from path-facing side. Pass-through objects may require two linked approach/exit points.
- Keep route clearance around the object; avoid placing other visitables adjacent to both approach tiles.

Passability and interaction:

- Primary class: transit / route object.
- Passability: conditional pass, blocking visitable, or adjacent service marker depending on subtype.
- Effects may include route opening, movement discount/tax, scouting, repair, ferry shortcut, rail logistics, root taxation, prism sightline, fog bypass.

State variants:

- Closed, open, blocked, repaired, damaged, taxed, discounted, neutral, owned, enemy-owned, guarded, scenario-locked.

Animation hooks:

- Chain lift, gate open, rail switch throw, prism glint, bell strike, fog curl, root unfurl, repair spark.

Readability constraints:

- The route effect must be visible without reading a panel. Shape and placement should imply path control.
- Transit objects must not look like pickups or towns.

Rejection constraints:

- Reject generic portal, castle gate, UI marker, copied banner, or one-size-fits-all transit kit.

Prerequisites:

- Schema for route effect, conditional pass, linked endpoints, approach offsets, repair/blocked state, ownership, and AI route valuation.

### Persistent Resource Fronts

Motifs to translate:

- Ore quarry ramps, aetherglass/crystal orchards, peat cuts, embergrain yards, graft nurseries, debt/furnace sites, memory-salt wreck fields, timber/rail yards.

Footprint and approach:

- Usually medium `2x2`; small `2x1` for minor mine heads or yards; large `3x2` only for high-value rail yards, foundries, or wreck fields.
- Approach from clear work entrance: ramp, gate, dock, plank path, stair, or yard opening.

Passability and interaction:

- Primary class: persistent economy site.
- Blocking visitable body with adjacent visit tile.
- Standard guard for normal sites; heavy guard for rare resources such as aetherglass, memory salt, brass scrip, or Old Measure anchors.

State variants:

- Neutral, claimed, player-owned, enemy-owned, guarded, pillaged/damaged, repaired, output-ready, exhausted/limited, weekly-refreshed.

Animation hooks:

- Quarry dust, crystal glint, peat smoke, grain/lamp flicker, graft growth, furnace pulse, salvage lantern, timber crane.
- Output-ready cue should be subtle and physical, not a reward sparkle copied from pickups.

Readability constraints:

- Each resource must have a distinct silhouette and material read. Avoid making every site a fenced square compound.
- Ownership state must be data-driven and faction-aware; do not copy generated blue/red banners or universal plinths.

Rejection constraints:

- Reject generic mine token, mini-town fort, copied fenced layouts, and color-only ownership.

Prerequisites:

- Resource-id migration plan for the nine-resource target or a staged subset.
- Site schema for `site_class`, `resource_outputs`, `daily_income`, `weekly_yield`, `claim_reward`, `guard_profile`, `capture_profile`, `counter_capture_value`, `route_affinity`, and `art_direction_family`.

### Guarded Reward Sites

Motifs to translate:

- Mirror ruins, observatories, vaults, debt foundries, orchard graves, obituary vaults, guarded stairs, blocked entries, visible camps, warning torches, hostile silhouettes.

Footprint and approach:

- Medium `2x2` for most sites; large `3x2` for major vaults, mirror ruins, harbor ruins, or objective complexes.
- Approach from one obvious entrance after guard resolution. Guard placement must not cover the entrance or class silhouette.

Passability and interaction:

- Primary class: guarded reward site.
- Blocking visitable, with explicit visible guard or warning state.
- Interaction usually requires neutral battle before reward claim.

State variants:

- Guarded, guard-engaged, cleared, reward-claimable, depleted, refreshed if limited-repeat, damaged/locked, scenario-locked.

Animation hooks:

- Guard warning motion, torch/lantern pulse, lens shimmer, vault seal open, reward claim cue, cleared entrance.

Readability constraints:

- Player should read risk before reward from the map object itself.
- Reward category should be implied: artifact, resource, spell, scouting, recruitment, or objective.

Rejection constraints:

- Reject surprise-panel combat, generic dungeon/lava vault/tree portal/telescope tower, and copied iconic set-piece layouts.

Prerequisites:

- Guard-visible placement model, reward category metadata, encounter link rules, cleared/depleted state, and AI reward valuation.

### Pickups

Motifs to translate:

- Writ bundles, granary sacks, timber carts, peatwax votives, reed caches, crystal lots, sextant cases, seed packets, gauge cases, ore sleds, salvage crates, obituary ink flasks, mirror cairns, ration cairns.

Footprint and approach:

- Micro `1x1`.
- Usually passable visit-on-enter; adjacent visit only when the art reads as a small shrine/cairn beside an impassable edge.

Passability and interaction:

- Primary class: pickup.
- One-time small reward, route clue, scouting reveal, recovery, or low-risk guarded small reward.

State variants:

- Uncollected, focused, collected/removed, remembered, fogged, small-guard variant.

Animation hooks:

- Very small attention cue by material: paper flutter, crystal glint, ember glow, reed tag sway, gauge tick, bell mote.
- Collection cue must be brief and should remove or visibly deplete the prop.

Readability constraints:

- Pickups must read as physical world props, not UI tokens or floating icons.
- Keep attention loops quieter than guarded rewards and service sites.

Rejection constraints:

- Reject generic coin bags everywhere, floating tokens, copied prop silhouettes, and large reward glows.

Prerequisites:

- Pickup reward metadata, visit-on-enter support, collected/remove state, fog-memory treatment, and small-cue animation policy.

### Faction Landmarks

Motifs to translate:

- Embercourt beacon/tollstone, Mireclaw drum/shrine, Sunvault relay/prism tower, Thornwake root arch/graft nursery marker, Brasshollow crane/rail/gauge site, Veilmourn bell dock/mirror marker.

Footprint and approach:

- Small `2x1` for local influence markers; medium `2x2` for service or capturable landmarks; large `3x2` only for major objective landmarks.
- Approach depends on role: adjacent service visit, route-side use, or non-interactable influence marker.

Passability and interaction:

- Primary class: faction landmark.
- May be decoration, interactable service, transit support, persistent influence site, or scenario objective.
- Must remain distinct from towns.

State variants:

- Neutral, faction-owned, enemy-held, active, inactive, damaged, captured, scenario-linked, influence-pulse.

Animation hooks:

- Faction-specific idle: beacon pulse, drum beat, prism glint, root growth, furnace vent, fog bell.

Readability constraints:

- Landmark must communicate faction pressure without becoming a full town or UI badge.
- Local landmark art should not imply a recruit dwelling unless it actually recruits.

Rejection constraints:

- Reject copied faction symbols, pseudo-heraldry, generic temples, generic banners, and town-miniatures.

Prerequisites:

- Landmark subtype metadata, influence/service/scenario role tags, ownership state rules, and faction-aware visual cue policy.

### Neutral Encounter Presentation

Motifs to translate:

- Visible neutral camps, patrol figures, blocking stacks, hostile silhouettes near rewards, spoor, campfires, warning markers, ambush/fog cues.

Footprint and approach:

- Micro/small `1x1` for visible army/stack object; small/medium camp footprints only when the encounter is a camp or guarded site, not for every neutral army.
- Encounter object itself is the combat trigger. If guarding another object, it must be placed so both guard and target remain readable.

Passability and interaction:

- Primary class: overworld neutral encounter.
- Usually blocking combat object or guarded-route object.
- Can patrol, block chokepoints, guard rewards, guard dwellings, or represent ecology.

State variants:

- Idle, patrol/route-linked later, warning/aggro, guarding, ambush-signaled, engaged, cleared, remembered/fogged.

Animation hooks:

- Idle stance, campfire, patrol bob, weapon/chain movement, warning pulse, fog/reed movement for uncertain encounters, clear/remove cue after battle.

Readability constraints:

- Neutral encounters must be visibly distinct from camps, dwellings, pickups, and guarded reward buildings.
- Danger must be fair and legible before contact. Ambush can be uncertain, but never invisible punishment.

Rejection constraints:

- Reject using a building/camp sprite for every neutral army, generic bandit camp as the only neutral language, and hidden combat without warning.

Prerequisites:

- AcOrP decision on first-class visible neutral army objects.
- Encounter schema plan for footprint, passability, guard-target link, patrol/idle state, danger cue, cleared state, and AI path blocking.

## First Migration Planning Recommendation

The next slice should be overworld object schema migration planning. It should define the data shape for primary object class, secondary tags, footprint/body tiles, approach offsets, passability class, interaction cadence, guard links, reward category, ownership/capture state, route effects, and animation cue ids before any JSON migration, map placement, sprite ingestion, or generated-image asset work.

Economy/resource schema migration should follow as a tightly coupled companion slice, because persistent resource fronts need resource ids, output cadence, capture values, and market/resource compatibility decisions before they can become production content.
