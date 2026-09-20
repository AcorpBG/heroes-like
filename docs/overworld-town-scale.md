# Town landmark scale

Current gameplay catalog (2026-09-20): six town templates, one per faction. The 32 named definitions mentioned in earlier artwork work below are historical; 26 retired IDs remain lookup aliases only. Original artwork and provenance remain preserved. See `common-town-building-template.md` for the live consolidation and proposed shared-building replacement.

Slice: `art-town-footprint-scale-20260920`

The owner's Heroes III reference establishes the intended proportions: a broad settlement over five columns and three ground rows, with towers rising above the rear of the footprint. The previous renderer limited every town to 2.9 tiles wide; enlarging the source image alone could not overcome that cap.

## Presentation

Current art policy (`art-one-town-per-faction-20260920`): one overworld design per faction, shared by all 32 named-town identities and unchanged across all nine land biomes. Named-town rules, interiors, ownership, placements and save IDs remain distinct. Capturing a town changes the entrance flags, not its architecture.

| Faction | Shared design |
| --- | --- |
| Embercourt League | Riverwatch Hold, weathered front-facing replacement |
| Mireclaw Covenant | Reed dens, ferry-chain winches and drum platforms on timber pilings |
| Sunvault Compact | Faceted crystal relays, ceramic cloisters and a large brass lens array |
| Thornwake Concord | Mobile living orchard with root wheels, suspended seed vaults and graft caravans |
| Brasshollow Combine | Riveted furnaces, pressure pipes, ore elevators and a bridge-crane rail terminal |
| Veilmourn Armada | Dry-supported funeral-fleet hull buildings, mirror memorials, bells and salvage gantries |

`town_identity_sprites` routes every named town to its `town_faction_*` asset. The biome manifest keeps these same six asset IDs on every terrain. A generic frontier fallback remains for missing content. Unselected PNGs and their old asset records are retained as historical art; the wiki marks those pictures as archive and uses the shared faction sprite as each town's overview image.

The owner rejected the earlier `art-matched-faction-towns-20260920` pass because it copied Embercourt's castle layout across factions. Its replacement, `art-distinct-faction-towns-20260920`, takes construction, silhouette and working infrastructure from `docs/factions-content-bible.md` and each faction's original art. Embercourt remains unchanged and was not supplied as an image reference for the new generation. The shared constraints are the elevated orthographic view, broad ground scale and front-centre entrance; buildings, outlines and skylines remain faction-specific. Painted width is 480 pixels before the existing 4.80-tile fit; heights vary naturally.

Every town uses neutral structural support: no surrounding sea, moat, lava, terrain island or long entrance bridge. Thornwake's foliage and wheels form its living architecture. Sunvault's crystals and mirrors form a calibration complex. Brasshollow has a contained industrial yard. Veilmourn's hull buildings stand in dry cradles, so maritime identity does not require a surrounding water tile. All six current designs have no baked flags or banners.

Original generated RGBA images, exact prompts, references and selected entrance pixels are retained in `art/overworld/source/generated/towns/distinct_factions_20260920/`. The deterministic `tools/pack_faction_towns.py` performs alpha-bound cropping and uniform downsampling into 512-pixel transparent canvases, translating the selected source threshold into `town_entrance_anchor_px` metadata. It updates the five canonical faction assets. The prior artwork remains archived. Current runtime images live in `art/overworld/runtime/objects/towns/distinct_factions/`; Embercourt retains its existing Riverwatch path.

The renderer aligns an authored doorway threshold to the common entrance ground line, instead of using the lowest root, wheel or piling. Anchors are measured in full sprite pixels and transformed through the existing painted-bound crop and aspect fit. Legacy art without metadata keeps its previous bottom-centre anchor. Ownership flag bases and gameplay coordinates do not move.

- The ground presentation and click mask are five columns by three rows, with the rear corners omitted: 3/5/5 cells. The south-middle cell remains the entrance.
- Existing original town art fits inside a five-by-five visual envelope, capped at 4.80 tiles wide and 4.35 tiles tall. Painted alpha bounds preserve their aspect ratio; narrow towers and broad settlements keep their individual proportions. The registered entrance sits 0.18 tiles above the entrance-cell bottom. Unregistered legacy art uses its painted bottom for that same reference line; short supporting roots, wheels and pilings may extend below a registered doorway.
- The initial scale adjustment covered 58 appearance IDs; the current active set is six faction designs plus the generic fallback. Riverwatch was subsequently regenerated with a centered south-facing gate and no painted banners. Its current version uses an elevated viewpoint, fine weathered masonry, terracotta roofs and dense asymmetric buildings; the earlier clean symmetrical painting is superseded.
- Clicking a body cell resolves to the existing entrance. The enlarged artwork and silhouette are clipped to explored cells. [Two small entrance flags](overworld-control-flags.md) now replace the roof ownership pennant and use the same explored-cell clipping.

## Existing maps and authority

Reloading the updated game applies the new presentation to existing maps and saves; regeneration is unnecessary. Native town placement, explicit visit coordinates, collision/package masks, movement and save data remain authoritative and unchanged. The larger presentation mask is not a replacement for those source gameplay masks. No native RMG rules or generated payloads change.

## Focused verification

The distinct-faction revision passed 79 checks in the same helper, including projection of each authored doorway onto the shared entrance. The six-design ground render was reviewed for distinct silhouettes, camera, scale and gate placement. Alpha, hashes, all 32 identities/nine-biome routes and wiki portraits were checked. No full suite or map generation was run.

The repaint reran the same 74-check helper successfully with the five new sprites and unchanged Embercourt/fallback. The six-design render on actual ground was visually reviewed for camera, width, gate position and terrain neutrality. All six 512-pixel RGBA files and runtime hashes, all 32 named-town/nine-biome routes, and wiki portraits were checked. Only this focused rendering helper ran; no full suite or native generation.

The consolidation reran the existing focused helper below: all 74 checks passed for the seven currently selected appearances, including scale/aspect, entrance/collision, fog and save-state preservation. All 32 named-town mappings, nine biome routes and wiki thumbnails were checked against the six selected paths. The six-design ground render was visually reviewed. No full suite or map generation was run.

The original `tests/overworld_town_scale_regression.py` run rendered the actual map view and all 58 appearances on a tile grid. Its 278 passing checks covered asset availability, aspect/scale limits, the tapered click mask, native entrance and collision preservation, unexplored-cell clipping, and presentation/save-state invariance. All ten gallery pages and the live map render were visually reviewed at that stage.

The focused `overworld_town_footprint_click_entry_routing_report.tscn` also passes: the route reaches the gate without prematurely entering Town, and a body click opens the correct town while preserving movement and source town data. The generated Large-map report's dimensions are updated to the new presentation contract; its native generation run is outside this visual slice.

Run with the Godot executable and a disposable output directory inside the repository:

```powershell
python -B tests/overworld_town_scale_regression.py --godot D:\Games\godot\Godot_v4.6.2-stable_win64_console.exe --output .artifacts/town-scale-review
```

The helper uses an isolated profile, an offscreen window on Windows and Xvfb on Linux. Generated review images/logs are disposable. The full repository suite and native map-generation suite were not run for this visual adjustment, as requested.
