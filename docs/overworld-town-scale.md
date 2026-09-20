# Town landmark scale

Slice: `art-town-footprint-scale-20260920`

The owner's Heroes III reference establishes the intended proportions: a broad settlement over five columns and three ground rows, with towers rising above the rear of the footprint. The previous renderer limited every town to 2.9 tiles wide; enlarging the source image alone could not overcome that cap.

## Presentation

- The ground presentation and click mask are five columns by three rows, with the rear corners omitted: 3/5/5 cells. The south-middle cell remains the entrance.
- Existing original town art fits inside a five-by-five visual envelope, capped at 4.80 tiles wide and 4.35 tiles tall. Painted alpha bounds preserve their aspect ratio; narrow towers and broad settlements keep their individual proportions. Painted bottoms sit 0.18 tiles above the entrance-cell bottom.
- The scale adjustment retained all 58 mapped appearances and their lookup identities, including faction defaults, named towns, biome variants and fallback art. Riverwatch was subsequently regenerated with a centered south-facing gate and no painted banners. Its current version matches Highwater Keep with an elevated viewpoint, fine weathered masonry, terracotta roofs and dense asymmetric buildings; the earlier clean symmetrical painting is superseded. Base, land and ash IDs share this biome-neutral replacement without changing the footprint or scale.
- Clicking a body cell resolves to the existing entrance. The enlarged artwork and silhouette are clipped to explored cells. [Two small entrance flags](overworld-control-flags.md) now replace the roof ownership pennant and use the same explored-cell clipping.

## Existing maps and authority

Reloading the updated game applies the new presentation to existing maps and saves; regeneration is unnecessary. Native town placement, explicit visit coordinates, collision/package masks, movement and save data remain authoritative and unchanged. The larger presentation mask is not a replacement for those source gameplay masks. No native RMG rules or generated payloads change.

## Focused verification

`tests/overworld_town_scale_regression.py` renders the actual map view and all 58 appearances on a tile grid. Its 278 passing checks cover asset availability, aspect/scale limits, the tapered click mask, native entrance and collision preservation, unexplored-cell clipping, and presentation/save-state invariance. All ten gallery pages and the live map render were visually reviewed.

The focused `overworld_town_footprint_click_entry_routing_report.tscn` also passes: the route reaches the gate without prematurely entering Town, and a body click opens the correct town while preserving movement and source town data. The generated Large-map report's dimensions are updated to the new presentation contract; its native generation run is outside this visual slice.

Run with the Godot executable and a disposable output directory inside the repository:

```powershell
python -B tests/overworld_town_scale_regression.py --godot D:\Games\godot\Godot_v4.6.2-stable_win64_console.exe --output .artifacts/town-scale-review
```

The helper uses an isolated profile, an offscreen window on Windows and Xvfb on Linux. Generated review images/logs are disposable. The full repository suite and native map-generation suite were not run for this visual adjustment, as requested.
