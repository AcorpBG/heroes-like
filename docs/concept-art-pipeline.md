# Concept Art Pipeline

Status: design and art-direction process source, not generated asset output.
Date: 2026-04-25.
Slice: concept-art-pipeline-imagegen-10184.

## Purpose

This document defines the required concept-art pipeline for Aurelion Reach. Image generation is a production art-direction stage before JSON migration, broad maps, final town polish, battle polish, asset implementation, or faction vertical slices.

The pipeline does not authorize copying genre reference art. Heroes 2, Heroes 3, and Oden Era may inform expectations for strategic readability, content density, and scale only. They are not source material for names, maps, factions, units, buildings, UI, music, text, composition, or final assets.

No generated image should be treated as final game art by default. A generated study is evidence for direction, silhouette, palette, and production briefs. Implementation still requires original asset work sized to the Godot 4 2D presentation and the game's content schemas.

## Source Constraints

Every prompt, curation pass, and implementation brief must cite the relevant sections of:

- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`
- The current target surface: world mood, region, faction, town exterior, building language, unit tier ladder, hero, overworld object, artifact/magic, or UI mood.

Global constraints:

- Original fantasy strategy world: Aurelion Reach during the Charter War.
- Bright-readable strategy fantasy with hard-edged logistics.
- Magic is accordance: visible anchors such as lenses, bells, writs, drums, roots, furnaces, mirrors, roads, and formations.
- Art must read at strategy-map and battle-scale first.
- Factions must not share a generic medieval-fantasy ladder or town silhouette.
- Towns are large world objects with infrastructure and approach logic, not badges.
- Overworld objects must classify clearly as decoration, interactable site/building, neutral encounter, resource front, transit object, shrine, ruin, or pickup.
- Scenic screens remain scenery-first. UI mood references may support menus and rails, but must not turn scenic screens into panel farms.

Negative constraints for all prompts:

- No direct Heroes of Might and Magic copying.
- No copyrighted names, characters, maps, factions, unit art, town layouts, icons, music, UI frames, or text.
- No generic fantasy castle, elf forest, dwarf mine, angelic light temple, pirate cove, undead fleet, goblin swamp, stock orc camp, dragon centerpiece, or holy knight faction identity.
- No clean MMO concept-art sameness, no vague high-fantasy castle kits, no photobashed copyrighted-looking production stills.
- No text labels embedded in images unless the study is explicitly a callout sheet placeholder.
- No final UI layouts that cover scenic/play surfaces with large text panels.

## Required Study Tracks

These tracks are mandatory before related implementation. They can run in parallel, but implementation briefs should not be accepted until the relevant track has approved studies.

| Track | Required before | Required outputs |
| --- | --- | --- |
| World mood and feel | Region art, first map-art expansion, menu mood | 12 to 24 mood frames, 3 curated directions, 1 approved world mood board |
| Region studies | Map tiles, object placement, scenario art planning | 6 to 10 studies per major region plus one density sheet |
| Faction identity | Any faction JSON migration beyond scaffold updates | 12 to 20 studies per faction, including palette, silhouettes, materials, and accord anchors |
| Faction town exterior | Town screen polish, overworld town art, town JSON migration | 8 to 12 exterior studies per faction, with approach side and skyline notes |
| Town building language | Building implementation, town interaction polish | 1 building-family sheet per faction, including 7 signature building seeds |
| Unit silhouettes and tier ladder | Unit JSON migration, combat sprites, animation briefs | 7-tier silhouette ladder per faction plus 2 alternates for tiers 1, 4, and 7 |
| Hero portrait/full-body | Hero JSON migration, campaign screens, roster UI | 10 portrait/full-body studies per faction, split might and magic |
| Overworld object families | Object taxonomy and map density work | Object-family sheets for ruins, route law, resources, shrines, hazards, pickups, dwellings, transit, faction landmarks |
| Artifacts and magic visual language | Spell/artifact expansion | Accord-family sheets and artifact material studies |
| UI mood references | Front-end, town, battle, or map UI polish | Small reference sheets for material, frame, icon, rail, and tooltip mood only |

## Image Generation Workflow

1. Prepare the brief.
   - Select the source sections from the world and faction bibles.
   - Define the game surface affected by the study.
   - State the required scale: strategy map, town exterior, battle unit, portrait, building, object, artifact, or UI mood.
   - Add the global negative constraints.

2. Generate candidates.
   - Generate small batches with one variable changed at a time: shape language, material, palette, camera, or density.
   - Do not mix all six factions in one prompt except for contrast-matrix studies.
   - Keep prompt seeds, model/version metadata, and exact prompt text with each output batch.

3. Curate.
   - Reject derivative, generic, unreadable, over-detailed, UI-token-like, or off-world candidates immediately.
   - Keep no more than 20 percent of a raw batch for annotation.
   - Prefer clear silhouette and production usefulness over painterly finish.

4. Annotate.
   - Mark why a candidate works or fails.
   - Identify faction silhouette, approach side, material language, tier role, animation problem, or object classification.
   - Note what must be changed before implementation.

5. Review.
   - Score candidates with the rubric below.
   - Require an explicit accept/reject/defer call.
   - Record decisions in the art-direction log when that log exists; until then, use a short markdown review note near the future output folder.

6. Turn accepted studies into implementation briefs.
   - Implementation briefs must describe what to build, not ask code/assets to copy the generated image.
   - Include scale target, silhouette requirements, palette range, animation needs, gameplay readability notes, and rejection notes.
   - Only then should JSON migration, map placement, scene polish, sprite production, or animation production start.

## Prompt Templates

Use these as starting templates. Replace bracketed fields and cite the source sections used in the review note.

### World Mood And Feel

Prompt:

```text
Original fantasy strategy game concept art mood study for Aurelion Reach during the Charter War. Bright-readable strategy fantasy with hard-edged logistics: broken sky-mirror infrastructure, contested roads, resource routes, civic tolls, root law, furnace valleys, fog harbors, and visible accordance magic anchors. Focus on [REGION_OR_WORLD_THEME]. Composition should support a 2D strategy game art bible, readable silhouettes, material-grounded fantasy infrastructure, scenic negative space, no embedded text, no UI overlay. Palette: [PALETTE]. Mood: adventurous, sincere, built-world, politically contested.

Negative: no direct Heroes of Might and Magic copying, no copyrighted names or assets, no generic fantasy castle, no stock elves/dwarves/orcs/angels/dragons, no grimdark mud, no clean MMO sameness, no text labels, no decorative UI panels covering scenery.
```

Review target:
- Does this establish the world as infrastructure fantasy rather than generic medieval fantasy?
- Can the mood inform terrain, objects, towns, and menus without becoming final asset reference?

### Region Study

Prompt:

```text
Concept art region study for [REGION] in Aurelion Reach, an original fantasy strategy world. Show terrain, route infrastructure, resource pressure, and map-object density for a 2D adventure map. Include [REGION_ANCHORS] with readable strategic paths, compact visitable object silhouettes, and clear negative space. Camera: elevated strategy-art view, not a cinematic character poster. Use material language from the world bible: [MATERIALS]. Palette: [PALETTE].

Negative: no copied game maps, no generic fantasy biome, no copyrighted assets, no massive text panels, no unreadable clutter, no pure atmosphere without gameplay-relevant landmarks.
```

Region anchors:

| Region | Prompt anchors |
| --- | --- |
| Emberflow Basin | river locks, levees, toll bridges, mill islands, beacon towers, granary barges, soot on pale masonry |
| Drowned Marches | reed seas, drowned causeways, chain ferries, peat cuts, drum islands, mudglass glints |
| Glass Uplands | lens fields, crystal orchards, prism roads, mirrored terraces, buried observatories, hard sunlight |
| Walking Green | migrating forest, root gates, graft nurseries, thorn toll arches, pilgrim clearings, living roads |
| Brass Deeps | quarries, pressure rails, pump houses, furnace valleys, gantries, slag roads, warning banners |
| Veil Coast | fog harbors, bell buoys, mirror shoals, black-sail slips, wreck fields, obituary vaults |
| Ninefold Confluence | shattered mirror basin where roads, roots, rails, fog lanes, rivers, and relays compete |

### Faction Identity Study

Prompt:

```text
Original faction concept-art identity sheet for [FACTION] in Aurelion Reach. World role: [WORLD_ROLE]. Show a coherent faction visual language across soldiers, commanders, infrastructure details, banners or markers, accord magic anchors, and material samples. Emphasize unique silhouettes and game-scale readability. Include no final logos and no text labels unless rough callout placeholders are required. Palette: [PALETTE]. Shapes: [SHAPES]. Materials: [MATERIALS]. Avoid generic fantasy archetypes.

Negative: no direct Heroes of Might and Magic copying, no copyrighted names/assets, no generic [FACTION_ANTI_GENERIC], no shared castle/archer/cavalry/caster/flyer ladder thinking, no over-ornate detail that fails at small game scale.
```

Faction brief inputs:

| Faction | World role | Shapes and materials | Anti-generic note |
| --- | --- | --- | --- |
| Embercourt League | Civic river-law power of locks, roads, tolls, beacons, granaries, and oath courts | Rectangles, lock steps, bridge spans, pale stone, river timber, iron chains, red signal ceramics | Not a human kingdom, knightly castle, or holy order |
| Mireclaw Covenant | Marsh sovereignty network of ferries, reed routes, shrine drums, wetland clans, and wounded-prey law | Low profiles, chain curves, reed clusters, wet timber, peat, bone, mudglass | Not orcs, goblins, swamp monsters, or tribal cliche |
| Sunvault Compact | Solar calibration society rebuilding mirror order through relays, lenses, choirs, and crystal engineering | Facets, thin towers, terraces, pale stone, blue-violet crystal, mirror, gold inlay | Not angels, clerics, high elves, or generic holy light |
| Thornwake Concord | Living orchard law and migratory root infrastructure that gives land political force | Branching silhouettes, root arches, graft bands, pale bark, dark leaves, amber fruit glass | Not elves, druids, forest guardians, or treants |
| Brasshollow Combine | Furnace-contract industrial power of ore, debt, rails, repair, and machines | Plates, braces, rails, pipes, gantries, brass, iron, hot ceramic, slag glass | Not dwarves, generic constructs, or decorative steampunk |
| Veilmourn Armada | Fog-maritime salvage houses controlling memory, hidden routes, bells, charts, and wreck rights | Masts, hull curves, bells, lantern dots, black lacquer, tarnished silver, fog cloth | Not pirates, undead, assassins, or dark-elemental stock fantasy |

### Faction Town Exterior

Prompt:

```text
Town exterior concept art for [FACTION] in Aurelion Reach, designed as a large 2D strategy-game town and overworld landmark, not a badge. Show the town's skyline, main approach side, defensive/economic infrastructure, and environmental integration. It must read at small overworld scale and support a later town screen. Include [SIGNATURE_STRUCTURES]. Palette and materials: [PALETTE_MATERIALS]. Mood: lived-in, strategic, original, readable.

Negative: no generic castle/citadel, no direct game copying, no copyrighted assets, no floating UI emblem, no decorative base plate, no unreadable ornamental skyline, no huge text panels.
```

Town exterior anchors:

| Faction | Signature structures |
| --- | --- |
| Embercourt | guarded river crossing, stone weirs, lock gates, barge cranes, beacon court, granary lock exchange |
| Mireclaw | drowned pilings, chain ferries, drum platforms, reed dens, blackwater shrines, hidden boat slips |
| Sunvault | crystal buttresses, lens tracks, resonant cloisters, prism yards, buried observatory, relay crown |
| Thornwake | root wheels, suspended seed vaults, graft halls, living bridges, thorn toll arches, orchard engines |
| Brasshollow | furnace pits, brass lifts, ore elevators, gantry cranes, pressure rail terminal, boiler chapel |
| Veilmourn | bell harbor, mirror drydock, black mooring posts, obituary vault, lantern reef, harpoon gantry |

### Town Building Language

Prompt:

```text
Production concept sheet for [FACTION] town building language. Show 7 signature building families as small exterior silhouettes and material studies for a 2D fantasy strategy town screen. The buildings must feel related but functionally distinct: economy, magic, unit dwelling, defense, transit, elite, and capstone. Use [FACTION_SHAPES], [FACTION_MATERIALS], and visible accordance anchors. Include clear approach/footprint logic and animation potential such as banners, water wheels, furnace glow, bells, root movement, lens light, or fog drift.

Negative: no copied town buildings, no generic fantasy structures, no tiny ornamental detail as the main read, no text labels in final image, no UI panels.
```

### Unit Silhouette And Tier Ladder

Prompt:

```text
Silhouette-first unit ladder concept sheet for [FACTION], 7 tiers for a 2D turn-based tactical battle game. Show each tier as a distinct readable battlefield silhouette at small scale, with role progression from tier 1 to tier 7. Faction identity: [FACTION_IDENTITY]. Unit ladder: [UNIT_LIST]. Emphasize posture, mass, weapon/tool profile, support props, and animation readiness. Keep details bold and original.

Negative: no generic militia/archer/pikeman/goblin/skeleton/zombie/elf/dwarf/angel/dragon ladder, no copied unit art, no shared faction skeleton, no over-rendered costume details that disappear at scale, no unreadable swarm of props.
```

Required unit review notes:

- Tier 1 must be readable as weak but useful.
- Tier 4 must show the faction's midgame tactical turn.
- Tier 7 must be iconic without becoming a genre-copied dragon, angel, titan, or undead lord.
- Adjacent tiers must not collapse into the same silhouette with different armor.

### Hero Portrait And Full-Body

Prompt:

```text
Hero concept study for [HERO_NAME], [MIGHT_OR_MAGIC] hero of [FACTION] in Aurelion Reach. Create portrait and full-body exploration for a strategy game hero roster and campaign dialogue surface. Show profession, faction material language, command role, accordance anchor, travel gear, and personal silhouette. The hero should look like they belong to [FACTION] but remain individually identifiable. No embedded text.

Negative: no copyrighted character likenesses, no generic knight/wizard/rogue archetype, no direct genre copying, no modern fashion, no oversexualized costume, no unreadable accessories, no text labels.
```

### Overworld Object Families

Prompt:

```text
Overworld object-family concept sheet for Aurelion Reach, [OBJECT_FAMILY]. Design compact 2D strategy-map objects with readable classification at small scale. Include variants for [REGIONS_OR_FACTIONS]. Each object needs a clear footprint, approach side or non-interactable status, material identity, and reward/risk implication. Camera: elevated strategy object sheet, not a cinematic scene.

Negative: no generic resource token icons, no copied map objects, no UI badge plates, no decorative clutter hiding routes, no text labels, no scale inconsistency.
```

Required object families:

- Decoration/non-interactable regional texture: fences, ruins, rail remnants, root walls, drift wreckage, reed clusters, lens debris.
- Interactable economy sites: ore quarry, crystal orchard, peat cut, graft nursery, salvage foundry, embergrain yard, memory-salt wreck field.
- Route law and transit sites: tollhouse, ferry chain, root gate, rail switch, fog slip, bridge bastion, prism road marker.
- Neutral dwellings and encounters: dens, old barracks, shrine camps, beast lairs, rogue salvage crews, machine yards.
- Guarded reward sites: mirror ruins, vaults, observatories, debt foundries, obituary vaults, orchard graves.
- Pickups and small rewards: caches, cairns, carts, writ bundles, salvage crates, seed packets, gauge cases.

### Artifacts And Magic Visual Language

Prompt:

```text
Artifact and magic visual-language study for [ACCORD_FAMILY] in Aurelion Reach. Show 8 to 12 original artifact forms and spell-anchor motifs for a 2D fantasy strategy game: [ANCHORS]. Designs must be icon-readable, materially grounded, and tied to gameplay verbs such as reveal, bind, repair, drag, shield, displace, recover, or mark. Use faction/world materials without copying known fantasy items.

Negative: no copyrighted artifacts, no generic glowing sword/orb/crown, no direct Heroes copying, no illegible tiny filigree, no text labels.
```

Accord anchors:

| Accord | Anchors |
| --- | --- |
| Beacon | ash writs, tollstone rings, court bells, signal braziers, road marks |
| Mire | peatwax votives, reed masks, mudglass beads, chain hooks, drum hides |
| Lens | prism sextants, shard mantles, tuning forks, mirror crowns, halometers |
| Root | graft knives, seed masks, thorn rings, amber lanterns, living bridge knots |
| Furnace | pressure gauges, debt seals, rail keys, slag plates, clause tablets |
| Veil | mirror charts, bell clappers, obituary ink, memory-salt reliquaries, black-sail compasses |
| Old Measure | cracked mirror fragments, measuring stones, weather marks, timekeeping rings |

### UI Mood References

Prompt:

```text
UI mood material study for an original 2D fantasy strategy game set in Aurelion Reach. Focus only on compact edge rails, command spine materials, icon frames, tooltip surfaces, faction-color restraint, and readable map/town/battle control affordances. Scenic surface remains primary. Materials: [WORLD_OR_FACTION_MATERIALS]. Style: clean production UI, not a marketing page.

Negative: no full-screen panel farm, no large explanatory text panels, no copied game UI, no ornate unreadable frames, no generic dark fantasy HUD, no embedded text, no one-hue palette.
```

## Review Rubric

Score each accepted candidate from 1 to 5. A production brief needs no score below 3, and the average should be at least 4.

| Criterion | 1 | 3 | 5 |
| --- | --- | --- | --- |
| Readability at game scale | Only works as a large painting | Main shapes survive but details carry too much meaning | Silhouette, value, and material read clearly when reduced |
| Unique faction silhouette | Could belong to several factions | Has some faction cues but weak contrast | Instantly belongs to one faction without labels |
| Town/building consistency | Buildings feel unrelated or generic | Shared palette but uneven forms | Cohesive family with distinct functions and approach logic |
| Unit tier clarity | Tier order is confusing | Tier mass generally progresses | Each tier has a clear role, mass, and silhouette jump |
| Map-object classification clarity | Object looks decorative, UI-like, or ambiguous | Category can be inferred with context | Decoration/site/encounter/transit/pickup is clear at a glance |
| Animation-readiness | Pose or structure cannot animate cleanly | Some likely animation beats exist | Clear idle, move, attack, hit, visit, or state-change hooks |
| Production feasibility | Requires impossible detail or bespoke one-off tech | Feasible with simplification | Fits expected 2D pipeline, scale, palette, and asset budget |
| Non-derivative originality | Obvious genre or franchise echo | Familiar shape but transformed enough to review | World-specific, original, and legally distinct |

Automatic rejection triggers:

- Direct resemblance to copyrighted game factions, towns, units, UI, maps, or icons.
- Generic fantasy identity that ignores Aurelion Reach infrastructure.
- A faction unit ladder that falls back to shared militia, archer, cavalry, caster, flyer, ultimate structure.
- Town exterior that reads as a castle badge, UI emblem, or decorative base.
- Object sheet that cannot distinguish interactable sites from decoration.
- Image relies on text labels to make the idea understandable.
- Candidate cannot be simplified into small 2D game assets without losing its identity.

## Output Organization And Naming

Do not create generated assets in this slice. Future generated studies should live under an art-direction area, separate from runtime assets, for example:

```text
art/concept/
  00_world_mood/
  01_regions/
    emberflow_basin/
    drowned_marches/
    glass_uplands/
    walking_green/
    brass_deeps/
    veil_coast/
    ninefold_confluence/
  02_factions/
    embercourt/
      identity/
      town_exterior/
      building_language/
      units/
      heroes/
    mireclaw/
    sunvault/
    thornwake/
    brasshollow/
    veilmourn/
  03_overworld_objects/
  04_magic_artifacts/
  05_ui_mood/
  _reviews/
```

Generated files should use stable, searchable names:

```text
YYYYMMDD_track_subject_batchNN_candidateNN_status.ext
```

Examples:

```text
20260425_world_mood_aurelion_reach_batch01_candidate03_accept.png
20260425_faction_embercourt_identity_batch02_candidate07_reject.png
20260425_town_veilmourn_exterior_batch01_candidate02_defer.png
20260425_units_brasshollow_ladder_batch03_candidate05_accept.png
```

Review notes should use:

```text
YYYYMMDD_track_subject_review.md
```

Each review note should record:

- Prompt text and negative prompt text.
- Image-generation tool/model/version if known.
- Batch id and candidate ids.
- Source doc sections used.
- Rubric scores.
- Accept/reject/defer decision.
- Required changes before implementation.
- Implementation-brief owner or follow-up slice.

Runtime asset folders such as `art/overworld/runtime/` should not receive generated studies directly. Only original, processed, game-ready assets should enter runtime paths, and only after an implementation slice explicitly accepts them.

## Implementation Brief Format

Accepted studies become briefs with this structure:

```text
# Implementation Brief: [Surface]

Source studies:
- [candidate ids]

Game surface:
- [overworld/town/battle/hero roster/artifact UI/menu/etc.]

Required read:
- [silhouette, palette, approach side, tier role, object class, animation beats]

Do not copy:
- [specific rejected details and derivative risks]

Production constraints:
- [target scale, likely sprite count, animation states, palette limits, Godot scene/runtime notes]

Content dependencies:
- [future JSON ids, faction ids, building ids, unit ids, object families, spell/artifact hooks]

Acceptance:
- [what must be visible in-game or in asset review before the brief is done]
```

## Stage Gates

The following work should not proceed without the matching accepted concept-art evidence:

- Faction JSON migration: faction identity sheet, unit ladder sheet, hero direction, town exterior, building language.
- New faction town screen polish: town exterior and building language sheets.
- Final battle unit polish: unit silhouette ladder and animation-readiness notes.
- Broad map or region polish: world mood, region studies, and overworld object-family studies.
- Overworld object density expansion: object-family classification sheets and review notes.
- Magic/artifact implementation expansion: accord-family and artifact visual-language studies.
- Main-menu or scenic UI polish: world mood and UI mood references that preserve scenic-first composition.

Emergency exceptions should be rare and documented in `ops/acorp_attention.md` or the relevant plan note. A temporary implementation may proceed only when it is explicitly labeled as non-final placeholder work and does not establish final visual direction.

## Current Next Use

The next foundation slice is economy overhaul planning. This concept-art pipeline should shape that work by requiring resource-site, mine, route, faction economy, and artifact/magic visuals to be reviewed before those concepts migrate into production art or major JSON implementation.
