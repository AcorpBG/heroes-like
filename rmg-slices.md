# Native RMG Production Slices

Active slice: `native-rmg-small-h3maped-port-10184`

Current status: `in_progress`

The current native RMG path is not production ready. The active reset scope is strict Small 36x36, one-level, land-only generation derived from `/root/Downloads/h3maped.exe` and the recovered h3maped spec. The generator must stay blocked until the executable-derived phases are actually ported and adopted into runtime map packages.

Latest boundary: private roads and private connection blocker/guard records now materialize in the strict report. Public runtime package output is still blocked.

## Ground Rules

- No archived catalog-auto fallback.
- No translated-template behavior as production authority.
- No count-fitting against a few uploaded maps.
- No proxy blockers, fake guards, visual-only roads, or self-declared validation.
- No runtime package output until terrain, towns, rewards, roads, blockers, guards, and final package serialization are coherent.
- Project/original content ids are adapted only at final object/package boundaries after the matching h3maped phase exists.
- Uploaded `.h3m` evidence maps are inspection data and must not be committed.

## Remaining Slices

1. **Connections, blockers, and guards**
   - Port the `0x4a79a3` family: `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, and guard scaling around `0x4a65a5`.
   - Materialize zone-link blocker cells and guard records from real connection geometry.
   - Ensure towns and zones are not freely reachable through unguarded open terrain.
   - Current strict report status: private 5/5 connection records, 10 private blocker cells, and 6 private guard records materialize through `0x4a79d8`, `0x4a61bc`, `0x4a7605` / `0x4a7312`, `0x4a65a5`, and `0x4a5e03`.
   - Still private/inspection-only until package adoption is correct.

2. **Public package adoption**
   - Convert strict private generated state into runtime map-package tiles and objects.
   - Adopt terrain, owned towns, neutral towns, mines, rewards, roads, blockers, and guards.
   - Preserve player starts at owned player towns.
   - Keep `runtime_generation_allowed: false` until generated packages pass structural validation.

3. **Final `0x49b2b6` writeout**
   - Produce one final serialization path for terrain bytes, road bytes, river bytes, flip flags, object records, ownership, and package metadata.
   - Remove mixed old-generator handoffs from the active path.
   - Final writeout must be deterministic and replayable from seed/config.

4. **Small-map structural parity audit**
   - Generate many Small 36x36 land maps across supported player counts.
   - Compare against uploaded HoMM3 `.h3m` evidence for zones, player-owned towns, neutral towns, roads, guarded links, blockers, guards, mines, rewards, artifacts, and route closure.
   - Fix general phase logic only; do not tune per sample.

5. **Editor and runtime inspection**
   - Generated maps must appear in the built-in map editor.
   - Player start, ownership, roads, blockers, guards, and rewards must render correctly.
   - Runtime pathing must respect package blockers and unresolved guards.

6. **Water, islands, and underground**
   - Extend only after Small land one-level output is structurally correct.
   - Add water modes, island behavior, two-level/underground generation, and layer-specific validation.

7. **Broad template support**
   - Validate all applicable recovered h3maped templates.
   - Expand from Small to Medium, Large, XL only after the small port has the same phase contract.
   - Unsupported template/size combinations must report explicit blocked status.

8. **Production audit gate**
   - `native_random_map_production_parity_completion_audit_report` must remain `production_ready: false` until all above slices pass.
   - Production readiness requires correct native generation, broad template coverage, owner-H3M corpus comparison, underground support, editor/runtime adoption, and no false full-parity claims.

## Immediate Next Step

Start **public package adoption**.

Road overlay bytes and private blocker/guard records alone do not make a playable map. The next required output is converting the strict private generated state into package tiles and package objects without falling back to archived generator output.
