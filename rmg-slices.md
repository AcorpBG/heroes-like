# Native RMG Production Slices

Active slice: `native-rmg-small-h3maped-port-10184`

Current status: `in_progress`

The current native RMG path is not production ready. The active reset scope is strict Small 36x36, one-level, land-only generation derived from `/root/Downloads/h3maped.exe` and the recovered h3maped spec. The generator must stay blocked until the executable-derived phases are actually ported and adopted into runtime map packages.

Latest local boundary: private terrain, towns, mines, rewards, roads, connection blockers, guards, final `0x49b2b6` tile-byte arrays, and fast structural validator authority now materialize in the strict report. Public runtime package output is still blocked.

Current local work target: wire public generation authority behind the strict validator, while keeping editor/runtime adoption audit as the final blocker before production confidence.

## Ground Rules

- No archived catalog-auto fallback.
- No translated-template behavior as production authority.
- No count-fitting against a few uploaded maps.
- No proxy blockers, fake guards, visual-only roads, or self-declared validation.
- No runtime package output until terrain, towns, rewards, roads, blockers, guards, and final package serialization are coherent.
- Project/original content ids are adapted only at final object/package boundaries after the matching h3maped phase exists.
- Uploaded `.h3m` evidence maps are inspection data and must not be committed.

## Current Implemented Boundaries

These boundaries are useful progress, but they are not production readiness:

1. H3maped small-template selection is active for the strict reset path.
2. Original h3maped template hydration is used for runtime-zone/link semantics instead of translated-template authority.
3. Terrain repaint, visual selection, and tile-byte candidate phases are materialized as private strict report state.
4. Player towns and starts are synchronized in the package draft.
5. Mine and reward object coordinate records are materialized in the package draft.
6. Road overlay bytes are materialized privately and included in the package draft.
7. Connection blocker and guard records are materialized privately and included in the package draft.
8. The final `0x49b2b6` writeout draft now combines terrain bytes, zero river bytes for the current small-land scope, road bytes, flip flags, and package object payload metadata.
9. A fast native structural validator now checks the package/writeout drafts without launching a Godot report scene.
10. The package/writeout drafts currently contain the small-land core object families, but they are still non-authoritative and runtime-blocked.

## Remaining Slices To Production Ready

These are the remaining implementation slices. They are ordered deliberately: do not expand map sizes, water, underground, or template breadth until Small 36x36 one-level land generation is structurally correct.

1. **Promote final `0x49b2b6` writeout from draft to validator-gated authority**
   - Produce a single validator-gated serialization path for terrain bytes, road bytes, river bytes, flip flags, object records, object ownership, player starts, and package metadata.
   - Remove old-generator handoffs from the active h3maped reset path.
   - Ensure seed/config replay is deterministic.
   - Exit condition: the same Small config and seed regenerate the same package structure and serialized map payload.

2. **Enable runtime generation only behind validator pass**
   - `generate_random_map()` must remain blocked until the fast structural validator passes.
   - Public packages must be produced from the h3maped-derived package/writeout path only, not from catalog-auto fallback or translated-template runtime logic.
   - Public failure states must say which strict phase failed or which validator invariant failed.
   - Exit condition: `generate_random_map()` returns a public package only when final writeout and structural validation both pass.

3. **Harden validator coverage with negative and corpus cases**
   - Add bad-package fixtures or injected failure cases proving the validator rejects missing towns, missing player-start ownership, missing roads, unguarded links, missing blockers, missing guards, bad tile-byte sizes, duplicate ids, and out-of-bounds objects.
   - Add corpus reporting once public generation is enabled.
   - Exit condition: validator failures are proven by negative tests, not only by a single passing strict seed.

4. **Finish roads as actual route infrastructure**
   - Roads are not complete just because road bytes exist in the private report.
   - Convert the road overlay into package road segments with connected cells, road class/type/art metadata, and route graph attachment.
   - Validate that roads connect meaningful anchors: player towns, neutral towns when present, mines, rewards, and zone links.
   - Reject short decorative loops as valid roads unless the executable-derived road routine produced them for a documented local feature.
   - Exit condition: Small land maps have real traversable road networks in package data and in editor/runtime rendering.

5. **Finish blockers and guards as zoning enforcement**
   - Complete the remaining `0x4a79a3` connection family behavior, including `0x4a696b`, `0x4a6cf2`, border/special guard handling, and guard value scaling around `0x4a65a5`.
   - Convert private blocker cells into blocking package objects or terrain blockers that pathing actually respects.
   - Convert private guard records into blocking guard objects with visit/fight metadata.
   - Validate that adjacent zones and towns do not have free unguarded routes through open terrain.
   - Exit condition: every zone link that should be guarded has either a blocking guard, blocking obstacle, or documented h3maped exception.

6. **Small-map evidence audit**
   - Generate a corpus of Small 36x36 one-level land maps across supported player counts and seeds.
   - Compare against uploaded HoMM3 `.h3m` evidence for structure, not exact counts: zones, town ownership, neutral towns, road shape, guarded zone links, blockers, guards, mines, rewards, artifacts, and route closure.
   - Fix executable-phase logic only; no per-map tuning.
   - Exit condition: audit shows no systemic Small land failures and records any known h3maped-derived variance.

7. **Editor and runtime adoption**
   - Generated maps must appear in the built-in map editor.
   - Player starts must spawn at owned player towns.
   - Town ownership, roads, blockers, guards, mines, rewards, artifacts, and zones must render and behave correctly.
   - Runtime pathing must respect blockers and guards.
   - Exit condition: manually inspecting generated Small maps in the editor matches the package/audit report.

8. **Template coverage and unsupported-config policy**
   - Keep translated-template behavior out of production authority where original h3maped template data is available.
   - Select templates from the recovered executable/spec data and only adapt identifiers at the project boundary.
   - Unsupported template/config combinations must fail with explicit blocked status, not fallback behavior.
   - Exit condition: Small land template selection is original-data driven, deterministic, and has explicit blocked states for unsupported profiles.

9. **Expand after Small land is correct**
   - Add water/islands only after Small one-level land passes.
   - Add two-level/underground after aboveground land generation and package adoption are stable.
   - Add Medium, Large, XL only after the Small phase contract is correct.
   - Exit condition: each new size/mode uses the same h3maped phase pipeline and has its own structural audit.

10. **Production audit gate**
    - `native_random_map_production_parity_completion_audit_report` must remain `production_ready: false` until all slices above pass.
    - Production readiness requires correct native generation, broad template coverage, owner-H3M corpus comparison, underground support, editor/runtime adoption, and no false full-parity claims.

## Immediate Next Step

Start **public generation authority after validator pass**.

The strict package/writeout drafts and fast validator now prove the current private generated state can be shaped into project package tiles, package objects, and final tile-byte arrays without falling back to archived generator output. The next required output is making `generate_random_map()` return this package only when the fast validator passes.
