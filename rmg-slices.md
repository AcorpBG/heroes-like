# Native RMG Production Slices

Active slice: `native-rmg-small-h3maped-port-10184`

Current status: `in_progress`

The current native RMG path is not production ready. The active reset scope is strict Small 36x36, one-level, land-only generation derived from `/root/Downloads/h3maped.exe` and the recovered h3maped spec. Public generation is allowed only for this supported scope and only behind the native fast structural validator.

Latest local boundary: private terrain, towns, mines, rewards, roads, connection blockers, guards, final `0x49b2b6` tile-byte arrays, fast structural validator authority, validator-gated public `generate_random_map()` output, and direct `convert_generated_payload()` package/session document adoption now materialize for strict Small land configs. The public result is still not production ready because save/load/editor runtime adoption, road/runtime behavior audit, blocker/guard runtime zoning audit, negative validator cases, and corpus audit are still pending.

Current local work target: harden the public package path into authoritative final map/package serialization and then audit editor/runtime adoption. Do not expand size, water, underground, or template breadth yet.

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
10. The package/writeout drafts currently contain the small-land core object families.
11. `generate_random_map()` now returns a public Small land package only when the fast structural validator passes; unsupported configs still return explicit blocked status.
12. `convert_generated_payload()` now accepts the validator-gated h3maped Small result directly and produces `MapDocument` / `ScenarioDocument` package-session records without using the archived translated-generator adopter.

## Remaining Slices To Production Ready

These are the remaining implementation slices. They are ordered deliberately: do not expand map sizes, water, underground, or template breadth until Small 36x36 one-level land generation is structurally correct in the editor and runtime. A private report entry, draft byte array, or passing positive-only report is not enough to mark a slice complete.

1. **Save/load and editor package serialization**
   - Promote the final writeout from draft report data into the single serialization source for terrain bytes, river bytes, road bytes, flip flags, object records, object ownership, player starts, and package metadata.
   - Remove any old-generator handoff from the active h3maped reset path.
   - Keep seed/config replay deterministic.
   - Exit condition: the same Small config and seed regenerate the same package/session documents, save to `.amap` / `.ascenario`, reload cleanly, and appear in the editor map list.

2. **Roads as real route infrastructure**
   - Roads are not complete until they are connected route data, package data, rendered editor/runtime data, and traversable gameplay data.
   - Convert the h3maped road overlay into package road segments with connected cells, road class/type/art metadata, and route graph attachment.
   - Validate that roads connect meaningful anchors: owned player towns, neutral towns when present, mines, rewards, guarded links, and zone entrances.
   - Reject short decorative loops as valid roads unless the executable-derived road routine produced them for a documented local feature.
   - Exit condition: Small land maps have coherent road networks in package data, editor rendering, runtime rendering, and route/path audit output.

3. **Blockers and guards as zoning enforcement**
   - Complete the remaining `0x4a79a3` connection family behavior, including `0x4a696b`, `0x4a6cf2`, border/special guard handling, and guard value scaling around `0x4a65a5`.
   - Convert private blocker cells into blocking package objects or terrain blockers that runtime pathing actually respects.
   - Convert private guard records into blocking guard objects with visit/fight metadata.
   - Validate that adjacent zones and towns do not have free unguarded direct routes through open terrain.
   - Exit condition: every zone link that should be guarded has a blocking guard, blocking obstacle, or documented executable-derived exception, and runtime pathing agrees with the audit.

4. **Validator hardening with negative cases**
   - Add bad-package fixtures or injected failure cases proving the validator rejects missing owned towns, missing player starts, wrong town ownership, missing roads, unguarded links, missing blockers, missing guards, bad tile-byte sizes, duplicate ids, out-of-bounds objects, and unblocked cross-zone paths.
   - Keep the fast validator native and data-only; do not launch Godot just to parse or count map/package structures.
   - Exit condition: validator failures are proven by negative tests, not only by a single passing strict seed.

5. **Small-map corpus audit**
   - Generate a corpus of Small 36x36 one-level land maps across supported player counts and seeds.
   - Compare against uploaded HoMM3 `.h3m` evidence structurally, not by exact count fitting: zones, player-owned towns, neutral towns, zone links, roads, guards, guarded links, blockers, mines, rewards, artifacts, and route closure.
   - Fix executable-phase logic only; no per-map tuning.
   - Exit condition: audit shows no systemic Small land failures and records any known h3maped-derived variance.

6. **Editor and runtime adoption**
   - Generated maps must appear in the built-in map editor.
   - Player starts must spawn at owned player towns.
   - Town ownership, roads, blockers, guards, mines, rewards, artifacts, and zones must render and behave correctly.
   - Runtime pathing must respect blockers and guards.
   - Exit condition: manually inspected generated Small maps match the package/audit report in editor and runtime behavior.

7. **Original template selection boundary**
   - Keep translated-template behavior out of production authority where original h3maped template data is available.
   - Select templates from the recovered executable/spec data and only adapt identifiers at the project asset/package boundary.
   - Unsupported template/config combinations must fail with explicit blocked status, not fallback behavior.
   - Exit condition: Small land template selection is original-data driven, deterministic, and has explicit blocked states for unsupported profiles.

8. **Expansion only after Small land is correct**
   - Add Small water/islands only after Small one-level land passes.
   - Add Small two-level/underground only after aboveground land generation and package adoption are stable.
   - Add Medium, Large, XL only after the Small phase contract is correct.
   - Exit condition: each new size/mode uses the same h3maped phase pipeline and has its own structural audit before runtime exposure.

9. **Production audit gate**
    - `native_random_map_production_parity_completion_audit_report` must remain `production_ready: false` until all slices above pass.
    - Production readiness requires correct native generation, original-data template selection, owner-H3M corpus comparison, underground support, editor/runtime adoption, and no false full-parity claims.

## Immediate Next Step

Start **save/load and editor package serialization**.

The strict package/writeout drafts and fast validator now feed validator-gated public output and direct package/session document adoption for the Small land scope without falling back to archived generator output. The next required output is proving save/load identity and editor visibility before runtime adoption is treated as meaningful.
