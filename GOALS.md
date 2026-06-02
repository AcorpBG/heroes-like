# Immediate Goals

Task: #10184
Document role: owner-facing near-term goal sheet
Source docs: `project.md`, `PLAN.md`, `ops/progress.json`

## Purpose

This file names the next immediate goals clearly enough for implementation work to start without rereading long history. It is not a progress log and does not replace `PLAN.md` or `ops/progress.json`.

The current owner-selected focus is extending the strict native H3MapEd random-map generator from Small land maps to **Medium 72x72 one-level land maps**. Campaign production remains deferred.

## Latest Immediate Goal - Native H3MapEd Medium Land RMG

The existing production-ready H3MapEd native scope is strict Small 36x36 one-level land. Medium currently has translated/proxy runtime evidence for AI probes, but that is not the target here.

Target state:
- native public generation supports Medium `72x72x1` land maps through the same executable-derived H3MapEd method used for Small;
- source template selection comes from original recovered H3MapEd catalog/RNG behavior, not translated-template defaults, hashes, or archived fallback generators;
- generated Medium packages pass structural validation, package save/load, disk startup, runtime adoption, pathing, and basic playability gates before public generation is allowed;
- Small strict generation remains unchanged and production-ready;
- Medium water, islands, normal-water, underground, Large, and XL remain blocked until separately scoped.

Non-goals:
- do not accept translated/proxy Medium output as success for this track;
- do not claim full HoMM3 byte/art/object parity;
- do not import or commit H3M/H3MapEd reference artifacts;
- do not start campaign production;
- do not tune units, spells, economy, town costs, or strategic AI behavior in this track.

## Goal 1 - Medium H3MapEd Reference Corpus

Progress slice: `native-rmg-medium-h3maped-land-reference-corpus-10184`

Build controlled reference evidence from the original `h3maped.exe` flow before touching runtime output.

Required scope:
- size: `homm3_medium`;
- dimensions: `72x72`;
- level count: `1`;
- water mode: `land`;
- player counts: `2`, `3`, and `4`;
- numeric seeds only.

Required metrics:
- h3maped executable SHA-256 matches `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`;
- every controlled reference records seed, player count, observed source template id, source catalog index when available, map dimensions, object counts, town counts, road cells, guards, rewards, blockers, body tiles, block tiles, visit tiles, and route/guard topology;
- controlled reference manifests and generated H3M files stay under `.artifacts/` and are not committed;
- phase-drift audit can compare each reference against native inspection snapshots.

## Goal 2 - Medium Source Template Authority

Progress slice: `native-rmg-medium-h3maped-land-template-authority-10184`

Extend the strict H3MapEd source-template selection boundary from Small to Medium land.

Required behavior:
- accepted Medium land templates come from recovered original H3MapEd catalog filters for the requested human/player counts;
- template selection uses the recovered H3MapEd RNG path;
- `random_map_config_identity()` and the H3MapEd inspection API expose original source-template authority;
- translated-template authority is not used for this strict Medium path.

Required metrics:
- player counts `2`, `3`, and `4` each expose a deterministic accepted-template vector;
- bounded seed matrices prove every accepted source template can be selected or explicitly report why it cannot;
- explicit translated-template requests do not bypass the H3MapEd source selector;
- unsupported Medium water/underground modes return blocked/no-fallback status.

## Goal 3 - Medium Executable Phase Port

Progress slice: `native-rmg-medium-h3maped-land-phase-port-10184`

Generalize the existing Small strict executable-derived phase chain to 72x72 land.

Required phase coverage:
- player-slot assignment;
- runtime-zone records;
- link seeds;
- coordinate replay and zone footprinting;
- terrain selection and terrain/writeout state;
- town/castle placement;
- mines, rewards, guards, blockers, decorative obstacles, and object masks;
- roads;
- final `0x49b2b6` tile-byte writeout.

Required metrics:
- final tile-byte arrays are exactly `5184` cells;
- owned player starts equal requested player count;
- owned start towns equal requested player count;
- inactive/neutral H3MapEd-scheduled towns are materialized instead of silently dropped;
- mines, rewards, connection blockers, connection guards, roads, and decorative blockers are nonzero in every accepted corpus case;
- route links that require blockers/guards have blocking package objects;
- package objects preserve full body/block/visit masks;
- no duplicate placement ids, out-of-bounds objects, disconnected roads, missing route edges, missing blockers, missing guards, or one-cell fake roads.

## Goal 4 - Medium Runtime Package Adoption

Progress slice: `native-rmg-medium-h3maped-land-runtime-adoption-10184`

Enable public Medium land generation only after validator-gated package adoption succeeds.

Required public contract:
- `generation_status`: `h3maped_medium_validated_package_ready`;
- `full_generation_status`: `h3maped_medium_public_package_production_ready_strict_medium_land`;
- `production_ready_scope`: `strict_medium_72x72_one_level_land_only`;
- `runtime_generation_allowed`: `true`;
- `public_runtime_authoritative`: `true`.

Required metrics:
- package save/load preserves terrain layers, tile bytes, roads, route graph, objects, player starts, towns, guards, blockers, rewards, and source-template authority;
- generated `.amap` and `.ascenario` packages start a real runtime session through disk package startup;
- runtime movement/pathing sees exact package blocker and guard masks;
- generated Medium land setup succeeds through bounded retry without authored scenario writeback;
- at least one public Medium 4-player land map can be launched through the generated-map flow after validation.

## Goal 5 - Public Scope Exposure

Progress slice: `native-rmg-medium-h3maped-land-public-ui-10184`

Expose Medium land only after the runtime package adoption gate passes.

Required metrics:
- public size options include `homm3_medium` only for land, one-level generation;
- Medium water, islands, normal-water, underground, Large, and XL remain hidden or blocked;
- public UI and launch metadata preserve strict scope text;
- Small strict generation remains available and unchanged.

## Validation

Required validation for the full Medium land track:

```bash
cmake --build .artifacts/map_persistence_native_build --parallel 2
cmake --build .artifacts/map_persistence_native_build_release --parallel 2
cmake --build .artifacts/map_persistence_native_build_windows_mingw_debug_linux_cross --parallel 2
cmake --build .artifacts/map_persistence_native_build_windows_mingw_release_linux_cross --parallel 2
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/native_rmg_medium_h3maped_template_selection_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 600 --scene res://tests/native_rmg_medium_h3maped_corpus_audit_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 600 --scene res://tests/native_rmg_medium_h3maped_runtime_acceptance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 300 --scene res://tests/native_random_map_package_surface_topology_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 300 --scene res://tests/native_random_map_disk_package_startup_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Reference/audit workflow:

```bash
python3 tools/rmg_h3maped_controlled_reference.py --size medium --water land --level-count 1 --players 4 --human-players 1 --seed <seed> --case <case_id>
godot --headless --path . --script tools/rmg_h3m_native_phase_snapshot_export.gd -- --size-class-id homm3_medium --water land --level-count 1 --players 4 --seed <seed> --case-id <case_id>
python3 tools/rmg_phase_drift_audit.py --snapshot <snapshot> --h3m <controlled_reference_h3m>
```

Success means:
- strict Medium land generation is executable-derived and validator-gated;
- public runtime generation is enabled only for `strict_medium_72x72_one_level_land_only`;
- Small strict generation remains green;
- no unsupported mode gets proxy fallback output;
- no reference H3M or generated evidence package is committed.
