# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native RMG implementations are archived as debug/evidence code. They are not the production generator path, and `MapPackageService.generate_random_map()` must not fall back to them.

## Source Anchor

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- Active module: `src/gdextension/src/h3maped_small_rmg.cpp`
- Archived active boundary: `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp`
- Archived current ledger: `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp`
- Older historical ledger: `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`

## Scope

Initial scope is only 36x36, one-level, land maps.

Medium, large, XL, water, islands, and underground generation are out of scope for this reset until the small land path can materialize zones, terrain, owned starts, towns, roads, blockers, guards, mines, rewards, and final writeout from h3maped-derived phases.

## Current Boundary

The active module is intentionally small again. The previous active h3maped boundary file was archived out of the build at `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp` after owner direction to restart without further incremental drift.

The compiled active module now only:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- ports player-slot assignment `0x4ac62a..0x4ac6ec` as inspection-only evidence, including `generator+0xed8`, `generator+0xee0`, and `generator+0xee4`;
- ports runtime-zone record setup `0x4a218c` as inspection-only evidence from the recovered template catalog, including runtime vector offsets `generator+0x10e0/+0x10e4/+0x10e8` and `0x414`-byte record size;
- ports `0x4a1f3b` source-zone link endpoint seeds as inspection-only evidence, preserving `Value`, `Wide`, and `Border Guard` payloads for later `0x4a79a3`;
- ports one-level coordinate candidate replay `0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed` as inspection-only evidence;
- ports the `0x4a3a03` zone-footprint phase boundary as inspection-only evidence: one level collects the six runtime zones, queues six `0x4a2777` helper inputs, small one-level land appends no synthetic `0xd4` source zone, and helper materialization remains pending;
- ports the `0x4cc788` initial source-node rectangle as inspection-only evidence, including constants `0xffffff38` / `0x190` and the four initial `0x4cc955` edges that later `0x4ccb64` split insertion must mutate before real `0x4a2777` traversal;
- ports the `0x4a2b33` endpoint clip helper as inspection-only evidence for the 36x36 active map rectangle before any `0x4a2777` boundary traversal writes are allowed;
- ports the `0x4a261a` deterministic line writer as inspection-only evidence over a bounded sample buffer before any writes can feed generated map cells;
- ports the `0x4a2413` randomized line writer as inspection-only evidence over a bounded one-level land sample before any writes can feed generated map cells;
- ports the `0x4ccb64` source-node split loop and `0x4ccdfc` finalizer as private inspection-only graph evidence over the current scaled runtime-zone points;
- ports real `0x4a2777` source-node cycle traversal as a private boundary-buffer report using `0x4a2b33`, `0x4a261a`, and `0x4a2413`; it reports six consumed runtime-zone cycles, 326 private trace writes, and 262 unique private boundary cells, but does not feed span fill, terrain, map cells, or public package output;
- ports `0x4a325d` span fill over that private `0x4a2777` boundary buffer as private inspection-only evidence; it reports six fill attempts, 762 filled interior cells, 1024 boundary-or-filled private cells, and 272 remaining unassigned cells, but does not feed terrain, map cells, or public package output;
- ports the small-land `0x4a3710` finalizer as private inspection-only evidence; with no appended synthetic runtime zones, both adjacency insertion phases skip and only six `0x49b61b` ordering resets plus six `0x4a3554` ordering rebuild calls are scheduled;
- records a strict restart backlog for the required executable phase ports;
- refuses runtime generation.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`. Its recovered source-owner masks are `0x0f` for human-capable owners and `0x0f` for player-capable owners; default color ordering maps source owners `0,1,2` to actual colors `0,1,2`. Runtime-zone setup reports six source zones, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, and four minimum player castles. Link seed setup reports five source-zone links: `1-4`, `2-5`, `4-5`, `3-5`, and `6-4`. Coordinate replay reports 18 placement steps, 18 coordinate RNG calls, final replay RNG state `316395082`, bbox span `85`, and scaled zone centers `(30,16)`, `(8,13)`, `(4,21)`, `(23,21)`, `(13,21)`, and `(18,13)`.

The active module materializes private inspection-only zone boundary buffers for `0x4a2777`, private inspection-only span-fill buffers for `0x4a325d`, and private `0x4a3710` small-land finalizer scheduling evidence, but does not materialize map cells, terrain art, runtime players, towns, roads, blockers, guards, mines, rewards, or packages.

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
2. Player-slot assignment: `0x4ac62a..0x4ac6ec` (active inspection only; no runtime player materialization).
3. Runtime-zone records: `0x4a218c` (active inspection only; no coordinates, terrain, cells, or runtime players).
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`, `0x4a3a03`, `0x4cc788`, `0x4ccb64`, `0x4ccdfc`, `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, `0x4a325d`, and `0x4a3710` (`0x4a1f3b` link endpoint seeds, one-level coordinate replay, `0x4a3a03` helper-input queue, `0x4cc788` initial rectangle, `0x4a2b33` clip helper, `0x4a261a` deterministic line writer, `0x4a2413` randomized line writer, `0x4ccb64` split insertion/cleanup, `0x4ccdfc` finalization, real `0x4a2777` traversal, `0x4a325d` span fill, and small-land `0x4a3710` active inspection only; cell materialization pending strict port).
5. Terrain writeout: `0x4a3f27` (pending strict port).
6. Town object placement: `0x4a8d2c`, `0x4a93a2`, `0x49ba89`.
7. Roads and rivers: `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`.
8. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`.
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
