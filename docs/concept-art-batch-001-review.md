# Concept Art Batch 001 Review

Status: first generated concept-art batch logged for curation; generated PNGs remain external.
Date: 2026-04-25.
Slice: concept-art-generation-execution-10184.

## Scope

This note records the first actual image-generation execution for Aurelion Reach art direction. It is a review and planning artifact only. No generated image was moved, copied, imported, renamed, or registered as a runtime asset in this repository.

External source directory:

```text
/root/.openclaw/media/tool-image-generation
```

Source documents:

- `docs/concept-art-pipeline.md`
- `docs/worldbuilding-foundation.md`
- `docs/factions-content-bible.md`

Prompt metadata note: exact prompt/model seed metadata is not present in the repository. This review records the source briefs and prompt intent inferred from the approved pipeline templates and the generated filenames.

## Batch Inventory

| Surface | External filename | Source brief | Prompt intent |
| --- | --- | --- | --- |
| World mood | `aurelion-reach-world-mood-01---0bf475e2-9847-4709-94e6-f0d990cba318.png` | Aurelion Reach during the Charter War; broken sky-mirror infrastructure, contested roads, river crossings, route law, accord anchors, scenic negative space. | Establish a broad world mood for infrastructure fantasy and the Ninefold Confluence without treating it as final map or menu art. |
| Embercourt identity | `embercourt-identity-study-01---8cf8ef05-4722-4e09-8385-e30eb9486a30.png` | Civic river-law power: locks, roads, tolls, beacons, granaries, ash writs, pale stone, river wood, chains, red signal ceramics. | Explore a non-knightly public-works faction with readable river infrastructure, signal tools, banners, crews, and town-object seeds. |
| Mireclaw identity | `mireclaw-identity-study-01---41f0bcb3-7fa9-4e44-9ce4-fa68f2cb5f42.png` | Marsh sovereignty: ferries, reed routes, shrine drums, wetland clans, wounded-prey law, low profiles, chain curves, peat, bone, mudglass. | Explore low wetland silhouettes, ferry-chain objects, ambush routes, drum shrines, and material language without becoming generic swamp monsters. |
| Sunvault identity | `sunvault-identity-study-01---b177564f-a107-42a1-ae73-07be36b1f280.png` | Solar calibration society: relays, lenses, choirs, crystal engineering, facets, thin towers, pale stone, blue-violet crystal, mirror, gold inlay. | Explore disciplined lens infrastructure, crystal object families, relay towers, and calibrated unit silhouettes without holy-light or angelic framing. |
| Thornwake identity | `thornwake-identity-study-01---26bbc3b4-1b46-4015-b58b-292e782a2f1c.png` | Living orchard law: root gates, graft nurseries, thorn toll arches, seed vaults, living roads, pale bark, dark leaves, amber fruit glass. | Explore living infrastructure, root-road silhouettes, graft objects, and settlement-scale root law without elf/druid/treant identity drift. |
| Brasshollow identity | `brasshollow-identity-study-01---b8dbbb90-9ada-43ff-a299-9bd70cf0b2d9.png` | Furnace-contract industrial power: quarries, pressure rails, pump houses, gantries, debt foundries, brass, black iron, hot ceramic, slag glass. | Explore industrial town/object language, heavy armor, rails, gauges, furnace anchors, and repair/siege identity without dwarf or decorative steampunk framing. |
| Veilmourn identity | `veilmourn-identity-study-01---eaeebc13-137e-40e4-ac98-33f9dc99a176.png` | Fog-maritime salvage houses: memory, hidden routes, bells, charts, wreck rights, black lacquer, tarnished silver, fog cloth, mirror plates. | Explore black-sail, bell, chart, salvage, fog-harbor, and obituary-vault language without pirate, undead, assassin, or shadow-fantasy drift. |

## Preliminary Curation

Batch-level read:

- Accept as external concept evidence only. The set gives the world and six factions a stronger visual starting point than text alone.
- Do not approve any image as final asset reference. Each useful element must be translated into original implementation briefs sized for Godot 4 2D strategy readability.
- The batch over-indexes on polished concept-sheet finish. Second-pass prompts should ask for smaller, bolder silhouettes, lower detail density, and explicit overworld/battle/town scale checks.
- The strongest shared direction is infrastructure fantasy: roads, locks, bells, lenses, rails, roots, ferries, and harbors are visually present enough to guide future briefs.

World mood:

- Works: broken mirror infrastructure, contested crossings, water routes, beacon points, cliff basin, and large negative-space routes support Aurelion Reach as a built world.
- Risks: the image leans epic/cinematic and dense; it is too complex to use directly for UI or map composition. Second pass should separate world mood from playable adventure-map density.
- Decision: defer as broad mood reference; request 3 to 5 cleaner region mood frames with stronger route readability and less monumental fantasy spectacle.

Embercourt:

- Works: lock gates, bridge spans, river barges, chains, lanterns, bells, granary and toll objects, red/blue/cream palette, and public-works crews strongly support the civic river-law brief.
- Risks: some figures can drift toward generic robed civic militia if the lock, river, ash-writ, and beacon anchors are removed. Banners include symbol-like marks that should be redesigned before use.
- Decision: keep for second-pass Embercourt town exterior, building language, and object-family briefs.

Mireclaw:

- Works: low wetland profiles, reed cloaks, chain ferries, drum platforms, peat blocks, shrine objects, and silhouette strip support marsh-route sovereignty.
- Risks: the palette and costuming trend grim and could become generic raider/swamp-horror if not balanced with ferry law, shrine culture, and route-control logic.
- Decision: keep with caution; second pass should brighten readable material cues and emphasize ferries, drums, peatwax, mudglass, and wounded-prey gameplay props over horror mood.

Sunvault:

- Works: crystal relays, mirror shields, lens towers, prism road surfaces, and pale stone/gold/blue-violet palette are clear and readable.
- Risks: armor silhouettes risk generic holy paladin/light-order drift. The second pass must emphasize calibration, choir math, engineering, and relay dependency over sanctity.
- Decision: keep for object and town infrastructure direction; defer unit silhouette approval until anti-angelic, non-paladin variants are generated.

Thornwake:

- Works: pale root arches, amber fruit glass, grafted towers, living road forms, and silhouette strips communicate living infrastructure well.
- Risks: some human figures and white-bark ceremonial language may drift toward elegant druid/forest-guardian imagery. Needs stronger toll, law, caravan, and renewal-debt signals.
- Decision: keep as a root-road and object-language reference; second pass should focus on town exterior, graft nurseries, thorn tolls, and functional unit silhouettes.

Brasshollow:

- Works: rails, furnace glow, quarry towns, gantries, gauges, pressure machinery, heavy armor, and industrial object language are strong.
- Risks: close to generic armored industrial/steampunk soldiering if debt law, contracts, repair windows, and furnace religion are not visually explicit.
- Decision: keep for furnace/rail/object briefs; second pass should make legal-contract anchors and maintenance constraints more visible and reduce generic heavy-infantry cues.

Veilmourn:

- Works: fog harbor, black sails, bells, mirror charts, memory tools, obituary vault, and salvage gear are highly aligned with the brief.
- Risks: this sheet contains embedded title text, labels, and tagline-style copy, which violates the pipeline negative constraints for generated studies intended as visual reference. Several figures also risk dark rogue/undead-adjacent drift.
- Decision: visual motifs are useful, but the sheet is not approvable as-is. Second pass must request no embedded text, stronger non-pirate/non-undead salvage-house identity, and clearer game-scale silhouettes.

## Risks, Rejections, And Deferred Notes

- Rejected for repo ingestion: all generated PNGs. They remain external only and are not source assets.
- Deferred: exact prompt text, seed, model/version metadata, and generation settings. Recover them from the external tool history if available before any later art provenance review.
- Deferred: AcOrP approval. These studies are delivered externally for review, but no image should be treated as approved final direction until AcOrP confirms accepts/rejects.
- Risk: concept sheets may smuggle UI labels, pseudo-logos, or generated icon marks into later briefs. Future implementation briefs must describe shapes and function, not copy marks.
- Risk: world mood and several faction sheets are too detailed for small-scale map/battle use. Require silhouette-first and tile/object-scale second passes.
- Risk: Sunvault, Thornwake, Brasshollow, and Veilmourn each have nearby genre traps. Keep anti-generic constraints in every follow-up prompt and review.

## Next Steps

1. Send or confirm delivery of the seven external PNGs to AcOrP for review without importing them into the repo.
2. Ask AcOrP for accept/reject/defer calls by surface: world mood, Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn.
3. Generate a second-pass curation batch focused on:
   - 3 to 5 cleaner world/region mood frames with route readability.
   - One no-text identity sheet revision for Veilmourn.
   - One silhouette-first revision each for Sunvault, Thornwake, and Brasshollow to reduce genre drift.
   - Embercourt and Mireclaw town/object sheets that test small-scale strategy readability.
4. Convert accepted visual directions into implementation briefs only after AcOrP review. Briefs should specify silhouettes, palette ranges, material rules, animation needs, and gameplay readability constraints rather than asking production work to copy generated images.
5. Keep `docs/concept-art-pipeline.md` as the gate for any future town, faction, unit, artifact, magic, or overworld-object art implementation.
