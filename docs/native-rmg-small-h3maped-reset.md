# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native catalog-auto RMG implementation is archived as legacy evidence/debug code. It is not the production random map generator path, and `MapPackageService.generate_random_map` must not fall back to it.

## Source Anchor

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- Active module: `src/gdextension/src/h3maped_small_rmg.cpp`
- Historical ledger only: `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`

If behavior is not supported by executable-derived evidence, recovered spec evidence, or direct generated-map comparison, it is not allowed into the production path.

## Scope

Initial scope is only 36x36, one-level, land maps.

Medium, large, XL, water, islands, and underground generation are out of scope for this reset until the small land path can materialize zones, terrain, owned starts, towns, roads, blockers, guards, mines, rewards, and final writeout from h3maped-derived phases.

## Current Active Boundary

The active compact port currently supports inspection only:

1. Verifies the local h3maped.exe reset anchor by file size and MZ header, while recording the SHA-256 anchor.
2. Selects accepted small-land templates from recovered h3maped template evidence.
3. Uses numeric h3maped RNG `0x4e7269/0x4e7276`; non-numeric seed hashing is blocked.
4. Resolves selected source template `h3maped_template_018` to adapted template `translated_rmg_template_019_v1` for seed `1`, 1 human, 3 total players.
5. Ports player-slot assignment `0x4ac62a..0x4ac6ec` for inspection: source capability masks, `generator+0xed8`, `generator+0xee0`, and `generator+0xee4`.
6. Ports runtime-zone record setup `0x4a218c` for inspection: six active runtime-zone records for the seed-1 boundary case, owner colors `[0, 1, -1, 2, -1, -1]`, three assigned start zones, one unassigned start zone, two treasure zones, and four minimum player castles.
7. Ports early endpoint-placement schedule `0x4a1f3b` for inspection: five link seeds, six creation calls, two stabilization passes, 18 total calls, 25 endpoint attempts, and three possible fallback candidates. This phase consumes only link endpoints; `Value`, `Wide`, and `Border Guard` are preserved for later `0x4a79a3`.
8. Ports coordinate candidate replay `0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed` for inspection: seed `1` reports 18 placement steps, four town-choice RNG calls during `0x49b452`, 18 coordinate RNG calls during `0x4a1f3b`, 22 total replay RNG events, and bbox span `84` rescaled onto the 36-tile map.
9. Ports runtime terrain selection `0x49b53d` for inspection: match-to-town zones use table `0x540908`, treasure zones use `0x4e7276` over source terrain flags `+0x85..+0x8c`, and seed `1` selects project terrains `[dirt, dirt, snow, grass, dirt, rough]` with two terrain RNG calls.
10. Ports the top-level zone-footprint schedule `0x4a3a03` for inspection: one land level collects six runtime zones, records the `0x4cc788` initial source-node rectangle `-200..400`, materializes all six scheduled `0x4cca55` locators, duplicate-endpoint guards, `0x4ccb64` pre-crossing insertions/bridge loops, and `0x4ccc7a`/`0x4cc68e` crossing cleanups against the mutated graph, materializes the `0x4ccdfc` finalized-coordinate fanout through `0x4ccd69`, exposes six finalized `0x4cca55` source-node cycles for the later `0x4a2777` consumer, skips the synthetic fallback zone, and records the helper sequence `0x4a2777 -> 0x4a325d -> 0x4a3710`.
11. Ports the small-land `0x4a3710` finalizer boundary: with no appended synthetic runtime zone, adjacency insertion loops skip, six ordering resets/rebuilds are scheduled, and no cells or adjacency records are materialized.
12. Ports the standalone `0x4a325d` span-fill primitive from disassembly for inspection: 12-byte span records, `0x00ff0000` unassigned zone-word scan, `cell+0x20` zone-byte writes, and `cell+0x2b |= 0x10` reserved-flag writes are covered by a bounded contract sample. This is not connected to runtime output until real `0x4a2777` boundary traversal feeds it.
13. Ports standalone `0x4a2b33` clip and `0x4a261a` deterministic line-writer primitives for inspection: integer truncating segment clipping, max-bound-minus-one clipping, Bresenham-style cell writes, and `cell+0x20`/`cell+0x2b` mutation contracts are covered by bounded samples.
14. Ports the standalone `0x4a2777` rectangle fallback branch for inspection: four `0x4a261a` edge writes and four `runtime_zone+0x3f4` footprint vertices are covered by a bounded sample. This remains disconnected from runtime output until the real source-node traversal branch is ported.
15. Ports the deterministic `0x4a2777` non-fallback connector segment branch for inspection: both endpoints are clipped through `0x4a2b33`, the first clipped endpoint is appended as a `runtime_zone+0x3f4` footprint vertex, and the segment is painted through `0x4a261a`.
16. Ports standalone `0x4a2413` randomized line-writer coverage for inspection: recursive subdivision, midpoint jitter through `0x4e7276`, terminal clamped cell writes, and `0x4a261a`-style cell mutation are covered by a bounded sample. This remains disconnected from the real `0x4a2777` source-node walk.
17. Ports the standalone `0x4a2777` boundary-wrapping continuation for inspection: clipped continuation endpoints walk rectangle edges through `0x4a2a5b..0x4a2af2`, append intermediate `runtime_zone+0x3f4` vertices, and paint the final clipped segment through `0x4a261a`. This remains disconnected from runtime output until real source-node traversal feeds it.

The active port does not materialize map cells, terrain art, towns, roads, blockers, guards, mines, rewards, or final map packages. Coordinate, terrain, footprint scheduling, the small-land no-appended-zone finalizer boundary, standalone boundary/span helper primitives, standalone `0x4a2777` branch and wrapping samples, and standalone `0x4a2413` randomized writer coverage are exposed as inspection data only and are not package generation.

## Runtime Gate

Supported small land generation currently returns:

- `ok: false`
- `generation_status: h3maped_small_clean_restart_generation_not_ready`
- `error_code: h3maped_phase_port_incomplete`
- `runtime_generation_allowed: false`

Out-of-scope generation currently returns `archived_legacy_native_rmg_disabled`.

Explicit translated-template requests do not bypass the reset gate.

## Hard Rules

- No hash-based template selection as a substitute for h3maped behavior.
- No sample-specific exact-count fitting in runtime generation.
- No road clusters that merely look like road counts.
- No blocker/decoration placement that passes counts while leaving unguarded open paths between zones.
- No player-start repair pass that only patches owner/town fields after placement.
- No validation that treats metadata zone links as sufficient when map cells do not enforce the link.
- No production fallback to archived native catalog-auto output.

## Next Required Ports

The next clean phases are:

1. Assemble real `0x4a2777` boundary traversal from finalized source-node cycles plus the ported `0x4a2b33`/`0x4a261a`/`0x4a2413` helpers, then wire its real boundary buffer into the ported `0x4a325d` span-fill primitive. Standalone rectangle/connector/writer samples are not sufficient for runtime generation.
2. Terrain/cell writeout, owned town placement, roads, guards, blockers, mines, rewards, and final package adoption.

Runtime generation remains blocked until these phases collectively produce authoritative cells and objects.
