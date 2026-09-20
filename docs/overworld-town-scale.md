# Town landmark scale

Slice: `art-town-footprint-scale-20260920`

The owner's Heroes III reference establishes the intended proportions: a broad settlement over five columns and three ground rows, with towers rising above the rear of the footprint. The previous renderer limited every town to 2.9 tiles wide; enlarging the source image alone could not overcome that cap.

## Presentation

Current art policy (`art-one-town-per-faction-20260920`): one overworld design per faction, shared by all 32 named-town identities and unchanged across all nine land biomes. Named-town rules, interiors, ownership, placements and save IDs remain distinct. Capturing a town changes the entrance flags, not its architecture.

| Faction | Shared design |
| --- | --- |
| Embercourt League | Riverwatch Hold, weathered front-facing replacement |
| Mireclaw Covenant | Repainted timber-and-bone town based on Duskfen |
| Sunvault Compact | Repainted limestone and blue-roof town based on Prismhearth |
| Thornwake Concord | Repainted rooted timber town based on Rootgate Nursery |
| Brasshollow Combine | Repainted fortified foundry town based on Orevein Gantry |
| Veilmourn Armada | Repainted inland-compatible gothic town based on Bellwake |

`town_identity_sprites` routes every named town to its `town_faction_*` asset. The biome manifest keeps these same six asset IDs on every terrain. A generic frontier fallback remains for missing content. Unselected PNGs and their old asset records are retained as historical art; the wiki marks those pictures as archive and uses the shared faction sprite as each town's overview image.

The follow-up art pass (`art-matched-faction-towns-20260920`) repaints the five other factions against the unchanged Embercourt/Riverwatch reference. All six use an elevated orthographic view, horizontal front facade, dense small-scale buildings, fine weathered materials and one front-centre gate. Their painted width is 480 pixels before the existing 4.80-tile runtime fit; individual tower heights vary naturally. The painted bottom centre uses the same renderer ground anchor, so entrances and the two runtime ownership flags line up without moving gameplay coordinates.

Every town uses neutral structural foundations: no surrounding sea, moat, lava, terrain island or projecting entrance bridge. Thornwake's foliage is part of its architecture. Sunvault's light is confined to small crystal/window details. Brasshollow is a settlement rather than an open mine pit, and Veilmourn uses buildings rather than ships and harbor piers. All six current designs have no baked flags or banners.

Original generated RGBA images, exact prompts and reference roles are retained in `art/overworld/source/generated/towns/matched_factions_20260920/`. The deterministic `tools/pack_faction_towns.py` performs only alpha-bound cropping and uniform downsampling into 512-pixel transparent canvases; it updates the five canonical faction assets. The prior artwork remains archived. Runtime images live in `art/overworld/runtime/objects/towns/matched_factions/`; Embercourt retains its existing Riverwatch path.

- The ground presentation and click mask are five columns by three rows, with the rear corners omitted: 3/5/5 cells. The south-middle cell remains the entrance.
- Existing original town art fits inside a five-by-five visual envelope, capped at 4.80 tiles wide and 4.35 tiles tall. Painted alpha bounds preserve their aspect ratio; narrow towers and broad settlements keep their individual proportions. Painted bottoms sit 0.18 tiles above the entrance-cell bottom.
- The initial scale adjustment covered 58 appearance IDs; the current active set is six faction designs plus the generic fallback. Riverwatch was subsequently regenerated with a centered south-facing gate and no painted banners. Its current version uses an elevated viewpoint, fine weathered masonry, terracotta roofs and dense asymmetric buildings; the earlier clean symmetrical painting is superseded.
- Clicking a body cell resolves to the existing entrance. The enlarged artwork and silhouette are clipped to explored cells. [Two small entrance flags](overworld-control-flags.md) now replace the roof ownership pennant and use the same explored-cell clipping.

## Existing maps and authority

Reloading the updated game applies the new presentation to existing maps and saves; regeneration is unnecessary. Native town placement, explicit visit coordinates, collision/package masks, movement and save data remain authoritative and unchanged. The larger presentation mask is not a replacement for those source gameplay masks. No native RMG rules or generated payloads change.

## Focused verification

The repaint reran the same 74-check helper successfully with the five new sprites and unchanged Embercourt/fallback. The six-design render on actual ground was visually reviewed for camera, width, gate position and terrain neutrality. All six 512-pixel RGBA files and runtime hashes, all 32 named-town/nine-biome routes, and wiki portraits were checked. Only this focused rendering helper ran; no full suite or native generation.

The consolidation reran the existing focused helper below: all 74 checks passed for the seven currently selected appearances, including scale/aspect, entrance/collision, fog and save-state preservation. All 32 named-town mappings, nine biome routes and wiki thumbnails were checked against the six selected paths. The six-design ground render was visually reviewed. No full suite or map generation was run.

The original `tests/overworld_town_scale_regression.py` run rendered the actual map view and all 58 appearances on a tile grid. Its 278 passing checks covered asset availability, aspect/scale limits, the tapered click mask, native entrance and collision preservation, unexplored-cell clipping, and presentation/save-state invariance. All ten gallery pages and the live map render were visually reviewed at that stage.

The focused `overworld_town_footprint_click_entry_routing_report.tscn` also passes: the route reaches the gate without prematurely entering Town, and a body click opens the correct town while preserving movement and source town data. The generated Large-map report's dimensions are updated to the new presentation contract; its native generation run is outside this visual slice.

Run with the Godot executable and a disposable output directory inside the repository:

```powershell
python -B tests/overworld_town_scale_regression.py --godot D:\Games\godot\Godot_v4.6.2-stable_win64_console.exe --output .artifacts/town-scale-review
```

The helper uses an isolated profile, an offscreen window on Windows and Xvfb on Linux. Generated review images/logs are disposable. The full repository suite and native map-generation suite were not run for this visual adjustment, as requested.
