# Overworld Map-First Command Rail Report

Task: #10228
Slice: `ux-overworld-map-first-command-rail-10228`
Validated: 2026-09-04

## Result

The live Overworld is now map-first: the adventure map occupies the main viewport, a narrow persistent right rail carries a functional minimap plus hero, army, town, status, Command, and Frontier controls, and a shallow footer carries resources, date, the contextual action, end turn, save, settings, and menu. Command and Frontier detail replaces the rail's base content while open instead of creating another simultaneous panel column.

The minimap derives explored terrain, visibility, towns, heroes, and the current viewed range from the active session. Pointer or keyboard activation recenters only the map camera. Focused runtime comparison proves that recentering leaves the selected tile, movement payload, and full serialized session exact.

No reference pixels or external art were imported. Existing original Aurelion Reach frame assets and live domain actions remain authoritative.

## Responsive evidence

The deterministic generated Small case uses seed `map-first-command-rail-10228` and produced two inspected captures:

- `.artifacts/overworld_map_first_command_rail/captures/overworld_map_first_1920x1060.png`
- `.artifacts/overworld_map_first_command_rail/captures/overworld_map_first_1280x720.png`

Both captures keep the map, rail, minimap, and footer within the viewport without overlap. The map width share is above the required threshold at each resolution, all seven compact army slots remain inside their rail owner, one generated player town is available through the town roster, and all nine required command/status controls are visible, focusable, and tooltip-described. Visual inspection found no clipped controls or large prose panel obscuring the map.

## Validation

- `python3 tests/overworld_map_first_command_rail_report.py`: PASS, two viewport rows, two captures, session authority exact.
- `godot4 --headless --path . --scene res://tests/overworld_gameplay_movement_input_ownership_regression.tscn`: PASS, all modal/drawer input owners and ordinary movement exact.
- `python3 tests/validate_repo.py`: PASS.
- `python3 tests/packaging_linux_export_smoke.py`: PASS, packaged startup passed.
- `python3 tests/packaging_windows_export_smoke.py`: PASS, Wine startup plus generated setup, Overworld entry, and Town entry passed.
- Linux and Windows PCK size: 245087776 bytes, below the unchanged 250000000-byte ceiling by 4912224 bytes.
- `git diff --check`: PASS.

Two broad legacy reports continue past the affected UI checks and fail on independent stale assertions: `overworld_visual_smoke.tscn` expects the old `lumber_wagon` identity while production resolves `mapobj_wood_wagon`, and `overworld_full_route_movement_regression.tscn` expects the old placeholder route-step VFX while production selects `route_endpoint_snap`. The army-management report passes its Overworld compact-bar case, then its unrelated Town case fails because it still selects the retired fifth management tab. None of these failures was hidden or converted into a claim for this slice.

## Preserved boundaries

Movement, pathing, interaction, generated-map content, save version 9, Town and Battle behavior, RMG topology, AI, and balance were not changed. The minimap remains a presentation surface and the compact army mode is enabled only by the Overworld shell; Town retains its existing default army sizing.
