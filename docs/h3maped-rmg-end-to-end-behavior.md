# H3MapEd RMG End-To-End Recovery Ledger

Document role: single source-backed ledger for recovered `h3maped.exe` random-map-generation behavior from entrypoint to final map writeout.

This document is about H3MapEd recovery, not about the current native implementation. Native files, helper functions, reports, blocked CLI payloads, and prior proxy implementations are not authority for the behavior below. They may only consume this recovered behavior after the source-order state chain is ported and compared.

## Truth Contract

- Authority comes from the recovered H3MapEd binary behavior, Wine runtime traces, Ghidra exports, and Python summarizers listed here.
- Native implementation status is deliberately not used as a recovery status.
- A recovered phase is not a native parity claim. R7 closed the fixed H3MapEd recovery ledger; native RMG parity is still a separate port/adoption task.
- If native output, final-map deltas, density reports, or support snapshots disagree with this document, the native side is wrong until proven otherwise.
- Do not replace a recovered phase with heuristics, density scalars, brute-force retries, package-time trimming, or final-map tuning.
- If a native port cannot implement a behavior listed here, the blocker is the exact missing recovered input, function, buffer, or caller order from this file.

## Evidence Base

Canonical binary:

- `.artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe`
- SHA-256: `f1ab1565fdfb7581cf67ca18a5349bf26fce59f696ea33061f941d80fcc069be`

Primary recovery ledgers and summaries:

- `docs/h3maped-rmg-private-state-recovery.md`
- `docs/h3maped-rmg-full-recovery-blockers.md`
- `.artifacts/rmg_recovery/recovery_manifest_summary_20260610.json`
- `.artifacts/rmg_recovery/r1_projection_chain_closure_summary_20260610.json`
- `.artifacts/rmg_recovery/r2_endpoint_cursor_closure_summary_20260610.json`
- `.artifacts/rmg_recovery/r3_weighted_materialization_tail_closure_summary_20260611.json`
- `.artifacts/rmg_recovery/r4_descriptor_source_identity_closure_summary_20260611.json`
- `.artifacts/rmg_recovery/r5_source_handler_pending_entry_closure_summary_20260611.json`
- `.artifacts/rmg_recovery/r6_relation_scoring_semantic_closure_summary_20260611.json`
- `.artifacts/rmg_recovery/r7_ordered_private_state_replay_summary_20260611.json`
- `.artifacts/rmg_recovery/ordered_writeout_spine_summary_20260610.json`
- `.artifacts/rmg_recovery/same_run_final_payload_summary_20260610.json`
- `.artifacts/rmg_recovery/same_run_final_tile_payload_summary_20260610.json`
- `.artifacts/rmg_recovery/same_run_final_object_payload_replay_summary_20260610.json`
- `.artifacts/rmg_recovery/final_header_metadata_payload_summary_20260610.json`
- `.artifacts/rmg_recovery/final_stream_state_summary_20260610.json`

R7 recovery status:

- Fixed recovery ledger: `100%` for the named R1-R7 blocker set.
- Ordered replay phases recovered: `18`.
- Recovery manifest: `7` checkpoints, `49` frontier summaries, `178` recovered functions.
- Native behavior changed by recovery: `false`.
- Native RMG parity implementation complete: `false`.

## Recovery Status Labels

- `RECOVERED`: source-backed behavior is recovered for the fixed recovery scope.
- `SOURCE_BACKED_EXCLUSION`: source-backed evidence proves the path is not live for the supported direct RMG target mode.
- `STATIC_OR_PARTIAL`: static/function-level behavior is recovered, but full live replay or wider-scope semantics are not claimed.
- `WRITEOUT_RECOVERED`: final serialized output behavior is recovered for the same-run replay.
- `NATIVE_PORT_PENDING`: native adoption is still required; this is not a recovery gap.

## Scope And Limits

Recovered fixed-ledger scope:

- Direct H3MapEd random map generation through the observed one-level land profiles used by the recovery corpus.
- Same-run Medium one-level no-water seed-10 writeout replay for the final payload evidence.
- Small seed-58 traces for generated-cell, route, relation, projection, and reward/guard recovery surfaces.
- Source-backed exclusions for supported one-level land paths where the binary does not execute a candidate path.

Not claimed here:

- Current native RMG parity.
- A completed native map package generator.
- A license to infer behavior from final object counts.
- Unsupported map modes outside the recovered scope unless they are named by a recovery artifact.

## Ordered End-To-End Spine

The recovered high-level ordered spine is:

1. `0x4602c1`: random-map UI entrypoint.
2. `0x4adfe1`: candidate/source setup.
3. `0x49ecf2`: setup-mode/candidate-container producer surface.
4. `0x49f0cd`: candidate-container fill.
5. `0x4ac552`: selected candidate/template phase completion.
6. `0x4a218c / 0x4a1f3b / 0x4a19ed / 0x49b53d / 0x49b4e1`: runtime-zone/link/coordinate placement chain, including per-runtime-zone terrain policy and monster-town policy.
7. `0x4a3a03 / 0x4ccb64 / 0x4cca55`: source-node footprint and descriptor-cycle production.
8. `0x4a2777 / 0x4a325d / 0x4a3710`: boundary traversal, span fill, and one-level land finalizer.
9. `0x4a3f27`: terrain repaint after the per-level owner-grid materialization.
10. `0x4bcff5` family: TerrainPlacement visual/art/flag selection.
11. `0x4a5767 / 0x49a318 / 0x49e700 / 0x4a54a7`: relation-local generated-cell normalization, placement scoring, and relation/control linkage.
12. `0x4a8d2c / 0x4a8db2 / 0x4a93a2`: town/castle and weighted materialization surfaces.
13. `0x4a9d6a / 0x4aa9b7 / 0x4aa3e9`: reward/guard/object-vector selection and generated-cell attachment.
14. `0x4a79a3 / 0x4a61bc / 0x4a7605 / 0x4a5e03`: connection, endpoint, blocker, and guard materialization/fallback surfaces.
15. `0x4ab52a` family: road/river/object-adjacency phase before final tile writeout.
16. `0x4ad1e3`: final map writeout entry.
17. `0x49b2b6 -> 0x4ad251`: final tile cell-write loop and completion.
18. `0x4ad309 / 0x4ad318 / 0x4ad3eb`: object count and object serialization.
19. `0x4ad3de -> 0x4ae09a`: success test and final return.

The R7 summary records these as 18 ordered replay phases by grouping some writeout and R-surface closures.

## Private State Layout

### Generated Cell Record

Recovered generated-cell stride: `0x30`.

| Offset | Meaning |
| --- | --- |
| `+0x04/+0x08` | object-reference vector begin/end observed by `0x49e1bf` and removal helpers |
| `+0x10/+0x14/+0x18` | projection/local coordinate triple written by `0x4a5767` and read by `0x4a606b` |
| `+0x1c` | projection/local word gate forced by `0x4a5767`, thresholded by `0x4a746b`, and cleared/packed by relation helpers |
| `+0x20` | score/owner/relation word consumed by `0x4a4c8e`, relation scans, and final surfaces |
| `+0x24` | terrain/art word; low 6 bits are terrain id; art row is written by `0x49acf6` |
| `+0x28` | generated-cell bit-state word |
| `+0x2b` | validity/private byte; bit `0x02` is tested by `0x49a1d8`, bit `0x04` is cleared by `0x4a5a23` for nearby same-owner cells |
| `+0x2c` | private flags; bit `0x01` suppresses `0x49a932` and `0x49aa63` |

Important `+0x28` bits:

| Bit | Meaning |
| --- | --- |
| `12..14` | packed projection/local direction from `0x4a59e2` |
| `15..16` | terrain flags from `0x49acf6` |
| `22` | object action/control bit used by `0x49a962` filtering and object footprint stamping |
| `25` | reset/object-reference empty state; `0x499ee8` sets it when a cell's object-reference vector becomes empty |
| `26` | candidate bit written by `0x49aa63`; setting it clears bit27 |
| `27` | occupied/blocked bit written by `0x49a932`; setting it clears bit26 |
| `28` | member/repaint gate consumed by `0x4a3f27` at `0x4a4150` |

### Generated Grid Wrapper

The grid wrapper seen by `0x49a072` uses:

| Offset | Meaning |
| --- | --- |
| `+0x08` | generated-cell buffer |
| `+0x0c` | width |
| `+0x10` | height |
| `+0x14` | level count |

### Generator Object

The generator object seen by `0x4a4c8e`, `0x4a8c15`, and later relation/object phases uses:

| Offset | Meaning |
| --- | --- |
| `+0x14` | generated-cell buffer |
| `+0x18` | width |
| `+0x1c` | height |
| `+0x20` | level count |
| `+0xc8/+0xcc` | index-keyed pointer vector begin/end used by endpoint/projection surfaces |
| `+0xd8/+0xdc` | index-keyed pointer vector begin/end used by `0x4a5e73` |
| `+0xec4/+0xecc` | object record vector anchor/end observed by `0x4a54a7` |
| `+0xed4` | optional handler pointer used by `0x49eb8d` for invalid bit26 candidate cells |
| `+0xed8` | source handler pointer assigned by `0x4af463` in the source-handler lifecycle |
| `+0xedc` | source-handler metadata vector initialized by `0x4af463` |
| `+0xeec/+0xef0/+0xef4` | pending-entry vector initialized and consumed only by the source-handler lifecycle excluded for direct target mode |
| `+0xf5c` | endpoint/index cursor used by `0x4a5e73`, `0x4adb72`, and `0x4add76` |
| `+0x10d4/+0x10d8` | candidate-container pointer vector built by `0x49f0cd` and consumed by `0x4ac552` |
| `+0x10e4/+0x10e8` | relation/vector begin/end consumed after `0x4a4c8e` |
| `+0x1104/+0x1108` | byte-state vector sized from the `+0xd8/+0xdc` pointer count and used by `0x4a5e73` |
| `+0x1110` | descriptor-type counter table indexed by descriptor `+0x1c` in `0x4a54a7` |

### Source Records And Descriptors

Copied `0x4c` source records:

| Field | Recovered role |
| --- | --- |
| `+0x18` | mask-word surface used by resolver and selector code |
| `+0x1c` | resolver/relation lane index; indexes generator `+0xee4` |
| `+0x20/+0x24` | wrapper sorting/reuse, selector filtering, and relation branch gating |
| `+0x30/+0x34` | additional relation-builder branch gates |
| `+0x3c` | successful relation-build marker byte |

Runtime zone source fields:

| Field | Recovered role |
| --- | --- |
| `+0x41..+0x49` | allowed town mask consumed by `0x49b3c1` |
| `+0x84` | terrain-match-to-town flag consumed by `0x49b53d` |
| `+0x85..+0x8c` | allowed terrain mask consumed by `0x49b53d` |

Descriptor fields:

| Field | Recovered role |
| --- | --- |
| `+0x00` | source-key registry value from `0x491eed`; not a universal `objects.txt` row id |
| `+0x1c` | descriptor type / counter lane |
| `+0x20` | subtype/source object id |
| `+0x24` | class/group-like selector |
| `+0x29` | projection path enable for `0x4a54a7` |
| `+0x2c/+0x30` | source-cell selection for relation/control linkage |
| `+0x30/+0x40` | score-table adjustment surfaces in local placement scoring |

Relation/control records:

| Field | Recovered role |
| --- | --- |
| `+0x09` | template connection Border Guard endpoint-stamping flag |
| `+0x44[type]` | per-relation descriptor-type occupancy counter |

## Recovered Function Behavior

### Generated Cell Helpers

`0x499e65` constructs one generated-cell record and calls `0x499ea3`.
It zeros the object-reference vector fields at `+0x04/+0x08/+0x0c` before the initializer call.

`0x49a072` resets the full generated-cell grid by walking `width * height * level_count` records at stride `0x30`.

`0x499ea3` initializes a generated-cell record:

- clears the object-reference vector range through `0x42bde9`;
- clears `+0x2c` bit `0`;
- writes `+0x10 = 0xffffffff`;
- writes `+0x1c = 0x7fbc7fbc`;
- writes `+0x20 = 0xffff7fbc`;
- writes `+0x24 = (old & 0xc0000548) | 0x00000548`;
- writes `+0x28 = (old & 0x01000000) | 0x0a000000`.

This initializer intentionally sets bit25 and bit27. Later mutation phases reduce or alter that state; native must not treat reset defaults as the pre-`0x4a4c8e` checkpoint.

`0x49a1d8` returns true only when `+0x2b & 0x02` is non-zero and terrain id `(+0x24 & 0x3f)` is not `9`.

`0x49acf6` writes terrain/art/flags:

- `+0x24 = (old & 0xffffc000) | (terrain & 0x3f) | ((art & 0xff) << 6)`;
- `+0x28` clears bit `15` and writes `((flag_a & 1) | ((flag_b & 1) << 1)) << 15`.

`0x4a59e2` packs relation/local fields:

- stack `+0x04` becomes the high word of `+0x1c`;
- stack `+0x08` is masked to three bits and written to `+0x28` bits `12..14`;
- stack `+0x0c` becomes byte3 of `+0x20`.

`0x4a4c8e` scans generated-cell relation boundaries after `0x4a8260`.
For a neighboring generated cell with a different non-negative owner, it calls
`0x49b3fb` through the current owner relation vector. The boundary trigger is
true when the relation record is missing, when the level index is exactly `1`,
or when relation byte `+0x08` is zero. On one-level land maps, a present
nonzero `+0x08` relation does not trigger the candidate-boundary stamp.

`0x49a932` writes occupied bit27 and is gated by `+0x2c` bit0:

- false clears bit27;
- true sets bit27 and clears bit26.

`0x49aa63` writes candidate bit26 and is gated by `+0x2c` bit0:

- false clears bit26;
- true sets bit26 and clears bit27.

`0x49a85d` stamps a clipped 3x3 bit27 neighborhood with `0x49a932(true)`.

`0x49a962` stamps candidate/occupied neighborhood state with terrain/action filtering:

- center cell gets `0x49aa63(true)`;
- clipped neighbors get `0x49a932(false)` only when bit22 is clear, `0x49a1d8` is true, and terrain id is not `8`.

`0x49abd6` stamps object/vector footprints. The seed-58 trace records five body-cell writes before `0x4a8c15`; those five flats are the observed bit22 cells and retain bit27.

`0x499ee8` removes an object record reference from a generated cell. If the cell object-reference vector becomes empty, it clears bit22, sets bit25, and resets the low word of `+0x20` to `0x7fbc` while preserving the high word.

### Setup, Candidate, Template, And Relation Input

`0x49ecf2` is the setup-mode / candidate-container producer surface. The ordinary setup object `+0x44` mode is copied to generator `+0x10b8`; sentinel `3` consumes one `0x4e7276` RNG call and stores `rand % 3`.

`0x49f0cd` fills candidate containers.

`0x4ac552` consumes accepted candidate containers and completes the selected template/candidate phase. It is the bridge from candidate setup into runtime zone/link materialization and later relation normalization.

`0x4ac62a..0x4ac6ec` assign player/source-owner slots:

- generator `+0xed8`: selected color order;
- generator `+0xee0`: raw source-owner assignment slots;
- generator `+0xee4`: mapped source-owner to player-color slots.

`0x49f2f5 / 0x49f7c4` relation builder surfaces produce relation records. Connection byte `+0x09` is recovered as the template Border Guard flag.

### Runtime Zone, Coordinate, Boundary, And Terrain

`0x4a218c` builds runtime-zone records and consumes player/source-owner assignment.

`0x4a1f3b` walks link endpoints for coordinate candidates. Link value, wide, and Border Guard payloads are preserved for later connection behavior; endpoint walking alone does not materialize blockers.

`0x4a17f5`, `0x4a1701`, and `0x4a1ad8` handle coordinate candidate generation, spacing validation, and one-level pruning. The `generator+0x10b8` mode selects prune divisors `5`, `6`, or `7`.

`0x4a19ed` rescales placed zones through bounding-box logic.

`0x49b3c1` runs during initial zone insertion before coordinate placement. If source zone `+0x41..+0x49` has an allowed-town mask, one RNG call selects the Nth enabled H3 town id; if the mask is empty, town choice remains `-1`.

`0x4a3a03 -> 0x4ccb64 -> 0x4cca55` builds source-node footprint descriptors, split nodes, bridge/crossing cleanup, and source walks.

`0x4a2777` consumes finalized source-node cycles. Its dependencies include:

- `0x4a2b33`: clip source-node segment endpoints to the active map rectangle;
- `0x4a261a`: deterministic boundary line writer;
- `0x4a2413`: randomized/jittered line writer.

`0x4a325d` performs span fill over the private boundary buffer. If the seed is outside bounds, it uses the recovered relocation path through `0x4a2b33`.

`0x4a3710` is the one-level land footprint/order finalizer. For the recovered one-level land no-appended-zone path, it does not append synthetic runtime zones; it resets/rebuilds ordering required by later relation consumers.

Inside `0x4a218c`, `0x49b53d` selects runtime terrain before the caller returns to `0x4ac552` for per-level `0x4a3a03` owner-grid materialization:

- if source zone `+0x84` match-to-town is true, terrain comes from table `0x540908 = {2, 2, 3, 7, 0, 0, 5, 4, 2}`;
- otherwise one RNG call selects among source zone `+0x85..+0x8c` terrain flags;
- terrain id `6` is eligible only on level `1`;
- on level `1`, any selected terrain except lava `7` is forced to cave `6`.

`0x49b4e1` immediately follows `0x49b53d` inside the same `0x4a218c` owner-vector loop and writes monster-town policy from owner `+0x04` or table `0x58db78`.

`0x4a3f27` runs terrain repaint:

- if the recovered generator level count at `+0x20` is greater than one, terrain-9 full-map repaint runs before water; supported one-level land maps skip that branch and begin with terrain-8 water repaint;
- per-zone repaint skips water zones;
- `0x4a2105` prepares relation-owner scan bounds by indexing the relation-owner vector from generated-cell `+0x20` byte2;
- `0x4a2ffa` recenters relation-owner coordinates by comparing generated-cell `+0x20` byte2 to the relation/source pointer owner byte;
- repaint owner gate reads generated-cell `+0x20` byte2 at `0x4a4142` and compares it to the current relation-owner loop index;
- member/repaint gate reads `+0x28 >> 28 & 1` at `0x4a4150`;
- passing cells write terrain id through `0x49acf6`.
- TerrainPlacement visual RNG starts from the post-`0x4a3a03 / 0x4a2777 / 0x4a325d / 0x4a3710` owner-grid RNG state, because `0x4ac552` calls `0x4a3f27` after the per-level owner-grid loop.

### TerrainPlacement

Recovered TerrainPlacement functions:

- `0x4bcff5`: visual table/toolkit setup.
- `0x4bd099` / `0x4bb681`: rectangle/delegated repaint walkers.
- `0x4bb74b`: live visual write.
- `0x4bad0f`: scratch packing.
- `0x4bcfc3`: visual row selection.
- `0x4bce6d`: visual row bucket/classifier helper.
- `0x4bc988`: candidate gate.
- `0x4bc5f0`: queue drain.
- `0x4bbd01`: retouch.
- `0x4bbfcc`: final sweep.
- `0x4bc5a3`: current-record preservation during final sweep.
- `0x49acf6`: generated-cell terrain/art/flag writeback.

Recovered static row tables:

| Table | Rows |
| --- | ---: |
| `0x543108` normal | 79 |
| `0x543380` dirt | 46 |
| `0x5434f0` sand | 24 |
| `0x5435b0` water | 33 |
| `0x542f88` rock | 48 |
| Total | 230 |

`0x4bad0f` scratch word:

| Bits | Meaning |
| --- | --- |
| `0` | dirty marker |
| `1..4` | terrain id |
| `5..11` | selected visual/art row |
| `12` | terrain flag A |
| `13` | terrain flag B |

### Relation, Scoring, And Object Commitment

`0x49e1bf` is bounded to `0x49e700` as a local placement adjacency/compatibility score helper. Positive returns are added to candidate score; no-positive and hard-negative paths reject candidates.

`0x4a5767 / 0x49a318` are relation-local generated-cell normalization and owner/projection propagation:

- reset/projection fields in `+0x10/+0x14/+0x18`;
- projection/local gate state in `+0x1c`;
- owner/score propagation in `+0x20`;
- relation direction bits in `+0x28`.

`0x4a54a7` is the relation/control linkage surface:

- descriptor `+0x29` enables projection path;
- descriptor `+0x2c/+0x30` select source cell;
- relation `+0x44[type]` is the per-relation descriptor-type occupancy counter;
- generated-cell `+0x20` carries source-owner relation index plus local projection distance/score;
- the descriptor-offset source cell is the direct low-word clear anchor for score depletion; the target cell is lowered by the projection wave and is not cleared first unless source and target are the same cell;
- it updates object vectors and descriptor counters for weighted materialization.

R3 closes the weighted materialization tail `0x4a8db2 -> 0x4a901a -> 0x4a54a7` for sampled dispatches, including object-vector growth and descriptor counter lane `98` increments.

R4 closes descriptor/source identity for mixed lanes:

- target contexts `45`, `53`, `54`, and `79` join to same-run `0x4903e8` descriptor build events;
- descriptor `+0x00` is not a universal row id;
- exact catalog identity authority is the copied `0x4c` source record and provider/object-loader surface;
- type `53` mines can be descriptor-ambiguous because several DEF rows share a mine subtype, so native must carry the copied source record instead of guessing.

`0x49da08` loads `objects.txt`, walks `0x4c` rows, reads row `+0x1c` as object type id, uses row `+0x20` as a subtype-like field in special guards, bounds type ids by `0xe8`, initializes `0xe8` wrappers through `0x49db76`, and loads `rand_trn.txt` through `0x49dc9e`.

`0x4af785`, `0x4af89f`, and `0x4a9e40` recover wrapper/source selection:

- reuse or create wrapper records from copied `0x4c` source records;
- select source lanes by mask words;
- filter wrappers by backing source fields `+0x20/+0x24` and mask compatibility;
- choose one passing wrapper by RNG.

### Reward, Guard, Endpoint, And Connection Surfaces

R1 closes the reward/guard projection chain:

- live `0x540b14 -> 0x49c0a6 -> 0x4ad947 -> 0x4ad7f7` branch is recovered;
- successful `0x4aa9b7 -> 0x4aa3e9` handoff is tied to relation pointer `0x017e0380`;
- sibling `0x4adb72/+0xc8` and `+0xf5c/+0x1104` surfaces are source-bounded and not ported from guesses.

`0x4aa9b7` scans generated-cell owner/score candidate cells and randomly selects reward coordinates.

`0x4aa603` filters reward templates. Its `0x49a6f9` footprint helper reads descriptor mask helpers `0x4268eb` and `0x41e951` with bit index `47 - (y * 8) - x` over the 8x6 descriptor-mask fields. That is the recovered row-major descriptor-cell order used by the helper call sites. The `0x4268eb`/secondary-mask branch checks generated-cell validity, bit22 absence, relation owner byte, and optional existing bit26 rejection; the `0x41e951`/primary-mask branch is a separate footprint gate and does not replace the secondary bit26 rule.

`0x4aa3e9` mutates generated-cell/object state for rewards.

R2 closes the endpoint/cursor chain for supported one-level land:

- direct `generator+0xf5c` writer surface is bounded to `0x4a5e73`, `0x4adb72`, and `0x4add76`;
- setup initializes `+0xf58` and the endpoint byte-state vector, not `+0xf5c`;
- observed `0x4a5e73` entries fail before endpoint mutation and before live `0x4a606b`;
- `0x4a696b` is blocked by recovered `GeneratedCell+0x20` owner/relation byte-pair gate in supported one-level land target mode;
- natural Border Guard branch falls through stale endpoint attempts into `0x4a7605 -> 0x4a5e03` fallback materialization.

`0x4a7605` is the fallback endpoint writer path. It can call `0x4a5767`, derive a source cell, choose an endpoint from projection/local offsets or fallback, call `0x4a5e73`, and stamp endpoint offsets through `0x49aa63(true)` and `+0x2c` packing.

`0x4a7312` policy recovery covers descriptor dimensions, source bounds/coordinate copies, `GeneratedCell+0x20` byte3 relation/class candidate filtering, `0x49aa93` eligibility calls, `0x4ae1fd` candidate appends, RNG `% candidate_count` selection, generator vtable slot `+0x04` commit, and candidate-vector destruction.

### Source-Handler Pending Entry Chain

R5 closes the source-handler pending-entry blocker by source-backed exclusion for direct RMG target mode:

- `0x53eafc` source-handler vtable is recovered.
- `0x484d9f -> 0x4802ac / 0x4afa99 -> 0x4af463 / 0x4af910 / 0x4af65e` lifecycle is statically closed.
- Ghidra reports zero incoming references to `0x484d9f`.
- Deterministic direct-generation breakpoint at `0x484d9f` did not hit.
- pending-entry offsets `+0xeec/+0xef0/+0xef4` are confined to that orphaned lifecycle for the direct RMG target mode.

This is not a claim that the source-handler chain is dead in every game context.

## Final Writeout

`0x4ad1e3` is the final map writeout entry.

Tile writeout:

- `0x49b2b6` writes the tile-cell stream.
- Same-run recovered payload: `5184` cells, `36288` bytes.
- SHA-256: `cfe2b13aba85076445f55535ff1e99fd2e373782b3867c95721ce333a0663f65`.

Tile bytes:

| Byte | Meaning |
| --- | --- |
| `0` | terrain id |
| `1` | terrain art / visual row |
| `2` | river byte |
| `3` | river byte / variation |
| `4` | road byte |
| `5` | road byte / variation |
| `6` | flags: terrain flags plus road flip bits |

Object writeout:

- `0x4ad309 / 0x4ad318` write object count.
- `0x4ad3eb` serializes static objects.
- Generated objects are serialized in two passes.
- Same-run recovered payload: `1212` objects, `17057` bytes, `7082` stream writes.
- SHA-256: `4bec25ac2d378ea5c3ca838a53da6b10244ac7260ac57ee3981098512f2bd91c`.

Header/player/metadata writeout:

- `4964` decoded events across `11` sections.
- `0` malformed events.
- Final sentinel hit.
- Payload byte count: `25254`.
- SHA-256: `aea4de28115ae5b6e8715df467b860f4dfc080a3f029ce205b27185b506fbc25`.

Stream state:

- adapter vtable `0x539918`;
- wrapped buffered sink vtable `0x536c94`;
- consistent pointer across traces.

Final success:

- `0x4ad3de` success test sees `EAX=4`.
- `0x4ae09a` returns with `EAX=1`.

## Native Adoption Rule

The recovered H3MapEd behavior above is the source to port. The current native generator must be judged by whether it reproduces this source-order private state and final writeout, not by whether it has a helper with a similar name.

Before native output can be called parity:

1. Port the recovered source-order phases into one native RMG authority.
2. Use the recovered private buffers and record identities, not project object categories or final-map counts.
3. Compare native phase/private-state checkpoints against H3MapEd owner executable evidence.
4. Only after private-state comparison passes, allow route/object/package consumers to use the state.

Current native status, by the recovery ledger:

- H3MapEd fixed recovery ledger: complete.
- Native parity: not complete.
- Remaining work is native port/adoption and comparison, not another recovery loop unless the port exposes a named contradiction in the recovered evidence.

## Invalid Work Patterns

- Calling a native helper implementation proof of H3MapEd behavior.
- Calling a blocked CLI snapshot parity.
- Using object-count or density deltas as the source of a phase rule.
- Translating source H3MapEd semantics into project categories before the source phase is proven in native private state.
- Reintroducing proxy generators, duplicate side replays, or package-adoption patches as implementation authority.
- Treating final tile/object writeout parity as a substitute for earlier private-state parity.
