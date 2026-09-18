# RMG Guard Placement and Empty-Space Audit

Owner request, 2026-09-18: investigate poor guard placement and huge empty map
spaces. Phase 6 audit slice `audit-rmg-guards-and-empty-space-20260918`, derived
from `project.md`, `PLAN.md` and `docs/lessons-learned.md`.

## Scope and acceptance

- Reproduce deterministic Medium/Large generated cases with fixed inputs and
  inspect actual rendered contexts, including guard/reward and empty regions.
- Separate source placement/masks, package adoption, gameplay guard control and
  visible raster coverage; do not equate total object count with useful density.
- Trace concrete symptoms to existing source owners and retained recovery
  evidence. Same-template/seed/private-state identity is required for parity
  conclusions; historical reports alone do not establish current behavior.
- Identify the exact function, descriptor/buffer or adapter rule responsible,
  distinguish confirmed causes from unproven recovery gaps, and propose bounded
  follow-up implementation. Finishing this audit does not mean fixing RMG.
- Use existing generation/probe owners, deterministic repeat checks and focused
  diagnostic validation. No Linux/Windows runtime/package change is selected.
  Check tracker consistency and `git diff --check`; validate any new Python
  diagnostic with focused tests and current Godot execution on unchanged code.
- Clean task-owned disposable outputs, preserving original art, caches, saves,
  native reverse-engineering material and unrelated untracked files.

Non-goals: density multipliers, seed retries, synthetic filler or guards,
post-payload mask carving, template/balance changes, native recovery guesses,
new artwork, gameplay fixes, save migration, unrelated UI or whole-game testing.

## Findings — reproduced on unchanged runtime 77f06889

The main confirmed fault is **loss during adoption**, not a demonstrated need
for more generated objects. The native map contains scenery that the live map
neither draws nor uses for collision. This also opens paths around guards.

### 1. Sixteen sampled scenery families fall through classification

`map_package_service.cpp::runtime_object_kind` (line 472) recognizes only a
subset of scenery type IDs. Lakes, lava flows/lakes, volcanoes, hills, mounds,
logs, stumps, foliage and several smaller families fall through to `h3m_object`.
`runtime_objects` labels nonvisitable records
`renderer_managed_nonvisitable_body` even without an assigned runtime identity.
`NativeRandomMapPackageSessionBridge.gd::_map_objects_from_document` (line 680)
then skips a record unless it is explicitly decorative or has an `object_id`.
The supposed renderer-managed objects consequently never reach the renderer.
The standalone `rmg_native_batch_export_cli.cpp` has the same partial kind list.

The records remain in `package_source_objects_by_id`, but that provenance index
is not consumed by `_build_blocked_tile_index` or the map renderer. Original
object masks are retained as metadata while the actual play surface loses them.
No native generation phase needs alteration to explain this fault.

| Case, two players / land / surface | Native records | Dropped scenery | Missing body cells | Of those, now walkable | Native + extra guards |
| --- | ---: | ---: | ---: | ---: | ---: |
| Medium seed 10 | 1,326 | 197 | 745 | 427 | 41 + 16 |
| Large seed 11 | 2,860 | 161 | 846 | 340 | 58 + 22 |
| Large seed 1 | 2,878 | 126 | 510 | 207 | 129 + 37 |

Body counts are unique tiles; overlapping surviving objects can still block
some missing bodies. All sampled body coordinates are in bounds. The missing
source type IDs are 116, 121, 126, 127, 128, 130, 131, 132, 133, 151, 153, 158,
206, 208, 209 and 211. Research labels come from the retained object metadata,
not copied raster assets. Medium loses 113 lava-flow and 18 volcano records;
301 of its newly walkable cells are on lava. Its largest connected newly opened
patch is 106 tiles. This explains part of the particularly bare lava scenery.

### 2. Missing bodies create real guard bypasses

Ground-only connectivity analysis closes all guard control zones and all
interaction tiles. Comparing that surface with the same missing source masks
restored analytically finds new bypasses near 3, 1 and 2 native guards in the
three cases respectively. This is a constrained diagnostic, not a whole-match
reachability or difficulty score; it excludes clearing objects and portals.

Three examples were then exercised using normal
`OverworldRules.try_move_along_route`, without changing blockers or guards:

- Medium: guard `native_h3maped_93c0f05a_object_1318` at `(11,58)` can be skirted
  by `(9,58) → (8,59) → (9,60)`. Missing mound record `...object_0149` owns the
  blocked source cell `(8,59)`. Both steps succeed with no guard engagement.
- Large seed 1: guard `native_h3maped_d986f6b9_object_2127` at `(32,39)` has the
  route `(30,37) → (30,38) → (30,39)`. Missing hill `...object_0360` owns the
  middle cell. Both steps succeed without battle.
- Large seed 11: a 12-step route around guard
  `native_h3maped_05ca1c91_object_1878` at `(49,25)` crosses missing mound/lake
  cells `(52,21)` and `(52,22)` and reaches `(51,23)` without battle.

These are isolated positioning fixtures, not claims that the hero played from
its starting town to each location. The original generated session remains
unchanged. Normal movement confirms the analytical bypass, and the source
object masks identify exactly why the corridor should not exist.

### 3. Extra site guards have a separate presentation/link policy

All extra guards in these three samples come from
`_ensure_generated_guarded_reward_site_guards`, not the now-removed town cache
or the separate rare-source policy. The extra guard is anchored to the site's
first visit tile, often in its painted building. Screenshots show stacks
overlapping structures or sitting alongside an already existing native stack.

`_resource_node_has_linked_guard` checks explicit target IDs; native guards have
spatial control zones but no such target link. Consequently 7/16, 4/22 and 11/37
extra site guards are inside existing native guard control. This confirms
overlapping control/presentation, **not** that internal site defenders and
external wandering guards are semantically interchangeable. Do not delete
these armies or change rewards under the guise of a positioning fix. Their
appropriate presentation/interaction model requires a separate bounded choice.

### 4. Existing green coverage misses the lost categories

The density report's `_package_projection_metrics` only fails for missing
**visitable** records. Every dropped object here has no action tile. The
renderer summary derives its expected bodies from already-adopted
`decorative_blocker_sprite` records, so all three report complete raster
coverage while omitting whole source families. The earlier 386-authored-object
sprite assignment claim covers a different content set; it does not prove
adoption of every generated native nonvisitable record.

The largest completely walkable, action-free square is only 5×5 in each case.
That metric does not capture a broad room dotted with small pickups, missing
scenery, or undersized artwork. Inspected 1920×1080 captures show that visual
emptiness is real, but this audit does not attribute every open region to the
same fault or establish a desired density multiplier.

## Source parity boundary

Fresh standalone generation still matches retained original H3MapEd bytes for
Medium seed 10 (79,333 bytes, SHA-256
`5c257e740c5743d215110a8575059402cd945bfe31670c2acb0db1e99bbc795c`)
and Large seed 11 (147,775 bytes, SHA-256
`2fab2929259a04929bdf7a9c908194b58de6ef1536d32914b764c980ac2f91df`).
The live probe reports matching sizes/FNV identities `e76c8967` / `b13f2b73`;
faction-bound runtime map IDs differ intentionally. The normal menu config's
default `random` strength and explicit `weak` both currently normalize to raw
setup `+0x48 = -1`; these are not a strong-monster test.

Retained comparison evidence:
`.artifacts/rmg_start_audit_20260905/guard_space_retained_20260918/`.
No original bytes are fed into generation. The standalone wrapper still
refuses package adoption with
`same_run_payload_authority_missing_recovered_profile_metadata`; it was not
bypassed. Offline final-byte agreement is not a new same-run private-state
proof. Large seed 1 has no matching original-executable proof in this audit.
The public `full_parity_claim` metadata flag is not accepted as that proof.

## Recommended next correction

Restore all generated nonvisitable scenery at the **classification/adoption
boundary**, with explicit semantic original-art mappings and exact original
body masks, positions and identities. Keep native RNG, phases and final bytes
unchanged. Reconcile the duplicated native/CLI classifiers and add a source-
inventory-based check that fails when any normal body lacks live collision or
appropriate artwork. Preserve old saves deliberately; do not silently mutate
their explored topology. Build/check both native platforms if C++ changes.

Then address site-guard presentation/link semantics separately without weakening
defenders or inventing guard positions. Reassess remaining empty areas only
after the missing bodies are restored. No density increase or art regeneration
can by itself fix objects discarded before rendering.

## Validation and limits

- Six Python diagnostic tests pass.
- First rendered observation: 11,240 assertions; final production-movement
  reproduction: 11,293 assertions, exit zero, no runtime errors. These certify
  reproducibility and the audit fixture, **not acceptable gameplay**.
- Native objects, live blocked grid and analytical results match exactly across
  both full generations of all three cases. All three movement reproductions
  succeed, demonstrating the still-unfixed bug.
- Source/Linux OpenGL 1920×1080 start, empty-region, guard and lost-blocker
  captures inspected. Revealed views are inspection-only; starts use normal fog.
- Two fresh retained native-byte comparisons pass. No new original-executable
  capture or arbitrary-seed/private-state certification is claimed.
- No game source, content, art, native library or save format changed. Windows
  exports/full repository gameplay suites are not rerun for this audit-only
  diagnostic change; corrective implementation requires both platforms.

Reproduce with fresh labels:

```sh
python3 -B -m unittest discover -s tests -p test_rmg_guard_space_audit.py
python3 -B tools/rmg_guard_space_audit.py --label <fresh> --render --resolution 1920x1080 --timeout-seconds 300
python3 -B tools/rmg_guard_space_audit.py --analyze .artifacts/rmg-guard-space-audit-20260918/<fresh>
git diff --check
```

The probe is a known-bug diagnostic, not a release-quality pass gate. Its bypass
expectations must become blocked-route regression expectations in the correction
slice. Native comparison used `rmg_retained_authority_audit.CASES` restricted to
Medium/10/land/one-level and Large/11/land/one-level, leaving its original
generation and refusal rules unchanged. Runtime and standalone probes ran
separately as required by `docs/rmg-python-validation-workflow.md`.

Completion cleanup removed 200,568,832 allocated bytes (200.57 MB) of task-owned
rebuildable runtime snapshots, logs and screenshots after recording the results.
The 307,200-byte fresh native/original comparison directory is retained as RMG
recovery evidence. Exact cleanup targets had no active users. No task temporary
profile remains in `/tmp`; caches, source/art, saves, existing recovery material
and the three unrelated untracked items were not removed or staged.
