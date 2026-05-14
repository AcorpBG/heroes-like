# Native RMG Production Slices

Active slice: `native-rmg-small-h3maped-port-10184`

Current status: `in_progress`

The current native RMG path is not production ready. The active reset scope is strict Small 36x36, one-level, land-only generation derived from `/root/Downloads/h3maped.exe` and the recovered h3maped spec. The generator must stay blocked until the executable-derived phases are actually ported and adopted into runtime map packages.

Latest boundary: private terrain, towns, mines, rewards, roads, connection blockers, and guards now materialize into a non-authoritative package draft in the strict report. Public runtime package output is still blocked.

## Ground Rules

- No archived catalog-auto fallback.
- No translated-template behavior as production authority.
- No count-fitting against a few uploaded maps.
- No proxy blockers, fake guards, visual-only roads, or self-declared validation.
- No runtime package output until terrain, towns, rewards, roads, blockers, guards, and final package serialization are coherent.
- Project/original content ids are adapted only at final object/package boundaries after the matching h3maped phase exists.
- Uploaded `.h3m` evidence maps are inspection data and must not be committed.

## Remaining Slices To Production Ready

These are the remaining implementation slices. They are ordered deliberately: do not expand map sizes, water, underground, or template breadth until Small 36x36 one-level land generation is structurally correct.

1. **Make the strict private state become a real package draft**
   - Input: executable-derived private terrain bytes, town records, mine/reward records, road overlay cells, connection blocker records, and guard records.
   - Implement one h3maped-specific adoption path from that private state into project package tiles and project package objects.
   - Include terrain layers, owned player towns, player starts, mines, rewards, roads, blockers, guards, ownership, and route/link metadata in the draft payload.
   - Keep `runtime_generation_allowed: false` until the draft passes structural validation.
   - Exit condition: strict report contains a complete package draft with no fallback to catalog-auto output and no missing core object family.

2. **Finish roads as actual route infrastructure**
   - Roads are not complete just because road bytes exist in the private report.
   - Convert the road overlay into package road segments with connected cells, road class/type/art metadata, and route graph attachment.
   - Validate that roads connect meaningful anchors: player towns, neutral towns when present, mines, rewards, and zone links.
   - Reject short decorative loops as valid roads unless the executable-derived road routine produced them for a documented local feature.
   - Exit condition: Small land maps have real traversable road networks in package data and in editor/runtime rendering.

3. **Finish blockers and guards as zoning enforcement**
   - Complete the remaining `0x4a79a3` connection family behavior, including `0x4a696b`, `0x4a6cf2`, border/special guard handling, and guard value scaling around `0x4a65a5`.
   - Convert private blocker cells into blocking package objects or terrain blockers that pathing actually respects.
   - Convert private guard records into blocking guard objects with visit/fight metadata.
   - Validate that adjacent zones and towns do not have free unguarded routes through open terrain.
   - Exit condition: every zone link that should be guarded has either a blocking guard, blocking obstacle, or documented h3maped exception.

4. **Finish final `0x49b2b6` writeout**
   - Produce a single authoritative serialization path for terrain bytes, road bytes, river bytes, flip flags, object records, object ownership, player starts, and package metadata.
   - Remove old-generator handoffs from the active h3maped reset path.
   - Ensure seed/config replay is deterministic.
   - Exit condition: the same Small config and seed regenerate the same package structure and serialized map payload.

5. **Enable runtime generation only after structural validation**
   - Add a fast native/Python structural validator for generated packages instead of relying on slow Godot scene reports for map correctness.
   - Validate zones, towns, player ownership, roads, guarded links, blockers, guards, mines, rewards, artifacts, traversability, and unreachable/unguarded paths.
   - Keep Godot tests for editor/runtime integration only.
   - Exit condition: `generate_random_map()` returns a public package only when the structural validator passes.

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

8. **Template selection cleanup**
   - Stop using translated-template behavior as authority where original h3maped template data is available.
   - Select templates from the recovered executable/spec data and only adapt identifiers at the project boundary.
   - Unsupported template/config combinations must fail with explicit blocked status, not fallback behavior.
   - Exit condition: Small land template selection is original-data driven and deterministic.

9. **Expand after Small land is correct**
   - Add water/islands only after Small one-level land passes.
   - Add two-level/underground after aboveground land generation and package adoption are stable.
   - Add Medium, Large, XL only after the Small phase contract is correct.
   - Exit condition: each new size/mode uses the same h3maped phase pipeline and has its own structural audit.

10. **Production audit gate**
    - `native_random_map_production_parity_completion_audit_report` must remain `production_ready: false` until all slices above pass.
    - Production readiness requires correct native generation, broad template coverage, owner-H3M corpus comparison, underground support, editor/runtime adoption, and no false full-parity claims.

## Immediate Next Step

Start **final road/river/writeout adoption**.

The strict package draft now proves the private generated state can be shaped into project package tiles and package objects without falling back to archived generator output. The next required output is finishing river overlay/final `0x49b2b6` writeout and validator authority before `generate_random_map()` may return a public runtime package.
