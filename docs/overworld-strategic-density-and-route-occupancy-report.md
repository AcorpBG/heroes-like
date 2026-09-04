# Overworld Strategic Density And Route Occupancy Report

Task: #10230
Slice: `overworld-strategic-density-and-route-occupancy-10230`
Validated: 2026-09-04
Status: completed

## Outcome

The sparse authored maps had two concrete causes. Ninefold Confluence and Third Hearths Confluence had unusually low route-destination counts, and authored `map_objects` were present in scenario data but `ScenarioFactory` did not copy them into the live session. The latter made all authored scenic blockers disappear at runtime.

The correction keeps those scenarios deterministic and data-owned. Ninefold gains 36 low-value, existing raster-backed pickups plus 26 biome-matched scenic blockers whose exact masks occupy 151 body tiles. Third Hearths gains 10 pickups plus 10 blockers occupying 52 body tiles. `ScenarioFactory` now carries authored `map_objects`, while resource batch provenance survives normalization and save-version-9 round trips.

Ninefold's live meaningful-interactable count rises from 153 to 189 (+23.53%, 4.61 per 100 map tiles); Third Hearths rises from 34 to 44 (+29.41%, 6.88 per 100 map tiles). All 46 added pickups were collected in focused runtime coverage, and every one of the 203 new blocker body tiles was enforced by authoritative pathing.

## Generated-map finding

The generated-map density report was stale rather than evidence of dropped content. It read roads from the intentionally empty legacy `setup.generated_map` payload and treated package visit/action cells as impassable. The repaired report reads live package terrain layers, models action cells as terminal reachable cells, and reconciles source objects against live towns, resources, artifacts, encounters, and map objects.

The deterministic native-package matrix resolves with zero missing visitable source objects:

| Size | Package objects | Visitable source objects | Live interactables | Missing visitables |
| --- | ---: | ---: | ---: | ---: |
| Small 36x36 | 277 | 94 | 103 | 0 |
| Medium 72x72 | 1,190 | 355 | 382 | 0 |
| Large 108x108 | 2,888 | 847 | 909 | 0 |
| Extra Large 144x144 | 5,083 | 1,595 | 1,691 | 0 |

No native package record, native RMG placement rule, topology rule, count scalar, or final payload changed. Sparse current-component windows on the Small fixture and guard-separated reachability on larger fixtures remain source-owned diagnostics. Changing those results requires recovered H3MapEd phase/private-state proof and is not approximated here.

## Visual and package evidence

- Inspected `.artifacts/overworld_density_10230/ninefold_density_1920x1080.png` and `ninefold_density_1280x720.png`: original raster pickups and biome scenery create stronger route cadence without clipping the map-first command rail, obscuring roads, or exposing procedural stand-ins.
- Focused runtime report: 26/26 Ninefold authored blockers were indexed and loaded from original raster assets; 151/151 body tiles were blocked; all added pickups collected and restored exactly at save version 9.
- Repository validation, Godot editor parse, generated Small/Medium/Large/Extra Large density distribution, distinct map-object/decorative art reports, live art coverage across 9,752 placements with zero missing runtime textures, and `git diff --check` pass.
- Linux release export and boot pass. Windows release export, native DLL load, boot, main-menu startup, generated setup, Overworld entry, and Town entry pass under Wine after explicit Wine-server cleanup allowed the unchanged harness to close its capture pipes.
- Matching Linux and Windows PCKs are 245,114,576 bytes, 4,885,424 bytes below the unchanged 250,000,000-byte ceiling.

This is a bounded authored-density and runtime-adoption correction, not a claim that every map now matches another game's cadence or that the whole game is release-ready.
