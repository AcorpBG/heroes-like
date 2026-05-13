# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native RMG implementations are archived as debug/evidence code. They are not the production generator path, and `MapPackageService.generate_random_map()` must not fall back to them.

## Source Anchor

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- Active module: `src/gdextension/src/h3maped_small_rmg.cpp`
- Archived phase ledger: `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`
- Archived active boundary: `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp`
- Archived current ledger: `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp`
- Older historical ledger: `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`

## Scope

Initial scope is only 36x36, one-level, land maps.

Medium, large, XL, water, islands, and underground generation are out of scope for this reset until the small land path can materialize zones, terrain, owned starts, towns, roads, blockers, guards, mines, rewards, and final writeout from h3maped-derived phases.

## Current Boundary

The active module is intentionally small again after the 2026-05-13 owner-directed restart correction. The overgrown active port was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp`; the previous phase ledger remains archived at `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`. Older archived ledgers remain evidence only.

The compiled active module now only:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- builds active non-public player-slot state from `0x4ac62a..0x4ac6ec` source-owner masks and `generator+0xed8/+0xee0/+0xee4` slot arrays;
- reports the strict executable-port backlog with every phase after player-slot assignment marked `pending_strict_port`;
- refuses runtime generation and any partial public package payload.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`, through the h3maped RNG first value `41` and selected vector index `2`. Accepted small-land templates for that profile remain `13`.

The active module no longer exposes the old top-level runtime-zone, coordinate, terrain, town, road, blocker, guard, mine, reward, final-writeout records, or the private phase ledger. The only active generation state beyond template selection is player-slot assignment, which materializes no runtime players, map cells, package tiles, or public output. Older detailed records were archived because they encouraged incremental report growth without a usable generated map. Future phases must be reintroduced as actual runtime generator implementation derived from `h3maped.exe`, not as broad inspection-ledger expansion.

## Runtime Gate

Supported small land generation currently returns:

- `ok: false`
- `generation_status: h3maped_small_clean_restart_generation_not_ready`
- `error_code: h3maped_phase_port_incomplete`
- `runtime_generation_allowed: false`

Out-of-scope generation currently returns `archived_legacy_native_rmg_disabled`.

Explicit translated-template requests do not bypass the reset gate.

## Required Ports

The restart must port these phases from `h3maped.exe` before public package output is allowed:

1. Template selection: `0x49f0cd`, `0x4ac597`, `0x4e7276`.
2. Player-slot assignment: `0x4ac62a..0x4ac6ec` (active non-public generation state; no runtime player/package materialization).
3. Runtime-zone records and terrain selectors: `0x4a218c`, `0x49b3c1`, `0x49b53d` (pending strict runtime implementation).
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`, `0x4a3a03`, `0x4cc788`, `0x4ccb64`, `0x4ccdfc`, `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, `0x4a325d`, and `0x4a3710` (pending strict runtime implementation).
5. Terrain writeout and TerrainPlacement: `0x4a3f27`, `0x4bcff5`, `0x4bd099`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x4ba938`, `0x4ba989`, `0x4baa94`, `0x4baabf`, `0x4bad0f`, `0x49acf6`, `0x4bbd01`, `0x4bc988`, and `0x4bbfcc` (pending strict runtime implementation and package adoption).
6. Town object placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` (pending strict runtime implementation; player starts must come from owned towns).
7. Roads and rivers: `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`.
8. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23` (late payload postprocess, guard value scaling, corrected `0x4a6cf2` same-level return-false gate, same-level dispatch readiness, low/high owner-byte precondition reporting, baseline `0x4a5767`/`0x49a318` high-owner propagation, generated-cell `+0x28` bit25/direction handoff, and `0x4a79a3` transition-vector candidate scan active inspection only; remaining `0x49a318` bit22/object metadata branches, actual `0x4a61bc`/`0x4a696b` endpoint writes, guard object stamping, blockers, mines, rewards, and final adoption still pending).
9. Mines, rewards, and objects: `0x49aa93` object placement family.
10. Final h3m writeout: `0x49b2b6`.

## Hard Rules

- No hash-based template selection as a substitute for h3maped behavior.
- No sample-specific exact-count fitting in runtime generation.
- No road clusters that merely look like road counts.
- No blocker/decoration placement that passes counts while leaving unguarded open paths between zones.
- No player-start repair pass that only patches owner/town fields after placement.
- No validation that treats metadata zone links as sufficient when map cells do not enforce the link.
- No production fallback to archived native catalog-auto output.
- No reuse of legacy hashed TerrainPlacement art/index/flip approximation in the clean h3maped reset path.
