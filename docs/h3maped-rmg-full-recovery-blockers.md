# H3MapEd RMG Full Recovery Blockers

Document role: fixed blocker ledger for the remaining H3MapEd random-map-generation recovery work.

This ledger is the reporting baseline for the final recovery push. Do not expand subquestions into new top-level blockers unless there is source-backed proof that a newly discovered path feeds final generated output and cannot fit any blocker below.

## Progress Baseline

Original recovery baseline at ledger creation: about 75% recovered.

Current scored recovery after R5 closure: about 94% recovered.

Remaining fixed recovery budget: 6 of the original 25 points.

Percent movement rule: progress only moves when a blocker or explicitly named sub-blocker is closed by Wine/Ghidra/Python evidence. A new report, trace harness, or diagnostic does not move the percentage unless it proves or excludes required source behavior.

## Remaining Blockers

| ID | Remaining blocker | Weight | Closure criteria |
| --- | ---: | ---: | --- |
| R1 | Reward/guard projection chain: `0x4adb72 / 0x4ad7f7 / 0x4aa9b7 / 0x4aa3e9` | 7 | Closed. Live `0x540b14` projection dispatch is recovered through `0x49c0a6 -> 0x4ad947 -> 0x4ad7f7`, tied to successful `0x4aa9b7 -> 0x4aa3e9` by relation pointer `0x017e0380`; sibling `0x4adb72/+0xc8` and `+0xf5c/+0x1104` surfaces are source-bounded and not ported. |
| R2 | Endpoint/cursor chain: `0x4a5e73 / 0x4a606b / 0x4a746b / 0x4a7605 / 0x4a696b / 0x4a7312` | 4 | Closed for supported one-level land. The stale `generator+0xf5c` endpoint failures, `0x4a696b` source/relation byte-pair gate, `0x4a606b` no-live-hit surface, and Border Guard fallback chain are source-backed; the fresh R1 branch split replaces the older zero-projection assumption without making `0x4adb72/0x4add76` live. |
| R3 | Weighted materialization tail: `0x4a8db2 -> 0x4a901a -> 0x4a54a7` | 3 | Closed. The deterministic seed-58 Large one-level no-water weighted tail is recovered across all three sampled dispatches: return/caller-after, object-vector growth, descriptor counter lane 98, dispatch 0 score-write count, and dispatch 1/2 full matched score-write streams. |
| R4 | Descriptor/source identity crosswalk for mixed lanes | 3 | Closed. Mixed selected lanes `45`, `53`, `54`, and `79` now have a source-backed crosswalk: all 87 selected descriptors join to same-run `0x4903e8` build events; `descriptor+0x00` is a registry/source-key value, not a universal row id; exact catalog identity authority is the copied `0x4c` source record and recovered provider/object-loader surface. |
| R5 | Source-handler pending-entry chain: `0x53eafc / 0x484d9f -> 0x4afa99` | 2 | Closed by source-backed exclusion for the direct RMG target mode. The `0x53eafc` vtable and `0x484d9f -> 0x4afa99 -> 0x4af463/0x4af910/0x4af65e` lifecycle are recovered, but Ghidra reports zero incoming refs to `0x484d9f`, the deterministic direct-generation breakpoint never hits, and `+0xeec/+0xef0/+0xef4` accesses are confined to that orphaned lifecycle. |
| R6 | Relation/scoring semantic replay | 2 | Runtime-name remaining scoring/relation surfaces: `0x49e1bf`, `0x4a5767/0x49a318`, and `0x4a54a7` relation/control linkage. |
| R7 | One continuous ordered private-state replay | 4 | Stitch recovered pieces into ordered replay from RMG entrypoint to final map write, with phase/private-buffer checkpoints. This is the final proof step before native parity changes. |

Original total remaining at ledger creation: 25 points.

Current remaining after R5 closure: 6 points.

## Reporting Rules

- Report only against `R1` through `R7`.
- Keep subfunctions and subquestions inside their parent blocker.
- State the active blocker, evidence added, whether the evidence closes a blocker/sub-blocker, and the new recovered percentage.
- Do not claim native RMG parity from final-map deltas, density scalars, extra gates, brute-force retries, or report-only improvements.
- Use Ghidra, Wine, and Python-owned tooling for recovery evidence. GDScript is for live game behavior, not RMG recovery reports.
- If a path cannot be recovered, the acceptable result is a source-backed exclusion or a named unrecovered function/data structure, not a heuristic replacement.

## Active Blocker

Active blocker: R6.

Current R1 state:

- Recovered: one clean Medium seed-10 same-run `0x4aa354 -> 0x4aa1db -> 0x4a5c07 -> 0x49cf34` attach-order path.
- Recovered: sampled projection object recycle/destructor ownership for one-level land evidence; sampled projection objects are destroyed/freed and later ordinary constructors reuse the heap slots before final sampled slot `+0x08` dispatch.
- Recovered: projection slot static ownership (`0x540b00+0x08 -> 0x49c019 -> 0x4adb72/0x4adef7`, `0x540b14+0x08 -> 0x49c0a6 -> 0x4ad947`). R1 later proves the live `0x540b14 -> 0x49c0a6 -> 0x4ad947 -> 0x4ad7f7` branch while keeping the sibling `0x540b00/0x49c019/0x4adb72` branch unhit in the closure sample.
- Recovered in R1-H1: seed-controlled Small 2-player seed-58 successful `0x4aa9b7 -> 0x4aa3e9` handoff joined to wrapper/member state. The trace records seven false `0x4aa9b7` calls before one success, candidate vector count `2`, selected index `1`, selected coordinate `(4,3,0)`, wrapper `0x0031df5c`, and one selected-member slot `+0x08` callback to ordinary `0x49baf5`; no projection-method target fires.
- Recovered in R1-H2/H3: seed-controlled Small 2-player seed-58 live projection dispatch reaches `0x49c0a6 -> 0x4ad947 -> 0x4ad7f7 -> 0x4ae09a`. The live `0x4ad7f7` entry carries relation pointer `0x017e0380`, matching the previously recovered successful `0x4aa9b7 -> 0x4aa3e9` handoff. Static Ghidra markers prove `0x4ad7f7` reads `+0x10e4/+0x10e8`, writes relation priority at record `+0x40`, builds the ordered local vector through `0x4ccecb`, and calls `0x4aa9b7`. Static ownership bounds sibling `0x4adb72/+0xc8` to the unhit `0x540b00/0x49c019` branch in this closure sample, and existing endpoint/cursor recovery bounds `+0xf5c/+0x1104`; no native RMG behavior changed.
- R1 is closed by `.artifacts/rmg_recovery/r1_projection_chain_closure_summary_20260610.json`.

## R1 Sub-Blockers

| ID | R1 sub-blocker | Status | Evidence |
| --- | --- | --- | --- |
| R1-H1 | Seed-controlled successful `0x4aa9b7 -> 0x4aa3e9` handoff | Closed, +2 points | `.artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_summary_20260610.json` |
| R1-H2 | `0x4adb72/0x4ad7f7` projection-method dispatch live path or source-backed exclusion | Closed, +3 points | `.artifacts/rmg_recovery/r1_projection_chain_closure_summary_20260610.json` proves live `0x540b14 -> 0x49c0a6 -> 0x4ad947 -> 0x4ad7f7`; sibling `0x4adb72` is statically bounded to the unhit `0x540b00/0x49c019` branch in this sample. |
| R1-H3 | Relation-priority/object-vector `+0xc8/+0x1104/+0xf5c` replay around projection methods | Closed, +2 points | `.artifacts/rmg_recovery/r1_projection_chain_closure_summary_20260610.json` joins live relation `0x017e0380` to the successful `0x4aa9b7 -> 0x4aa3e9` handoff, proves `0x4ad7f7` relation-priority/local-vector markers, and source-bounds sibling `+0xc8` plus existing `+0xf5c/+0x1104` cursor surfaces without native behavior changes. |

## R2 Closure

R2 is closed by `.artifacts/rmg_recovery/r2_endpoint_cursor_closure_summary_20260610.json`.

Recovered R2 state:

- The direct `generator+0xf5c` writer surface is bounded to `0x4a5e73`, `0x4adb72`, and `0x4add76`; no unknown direct writer remains in the widened endpoint/cursor access scan.
- Setup initializes `generator+0xf58` and the endpoint byte-state vector, not `generator+0xf5c`. Natural Border Guard endpoint attempts therefore enter `0x4a5e73` with stale cursor `0x7a1befdf` while active endpoint keys are `0..7`.
- All observed `0x4a5e73` entries fail before endpoint mutation; current corpus metrics are `50` entries, `0` success-path hits, and `0` live `0x4a606b` hits.
- All six static `0x4a5e73` caller gates are grouped. Live current-scope callers either fail on stale cursor (`0x4a61bc`), forced-route preconditions (`0x4a746b`), or are blocked earlier (`0x4a696b`); `0x4a6cf2` endpoint callsites are static-only in the current corpus.
- `0x4a696b` is blocked by the recovered `GeneratedCell+0x20` owner/relation byte-pair gate for the supported one-level land target mode: `150` sampled entries, `6` complete grid scans across seeds `1`, `2`, and `10`, `5,752` scanned cells, and `0` owner/relation pair matches.
- The natural Border Guard branch falls through stale endpoint attempts into recovered `0x4a7605 -> 0x4a5e03` fallback materialization.
- R1 supersedes the older zero-projection assumption safely: the live `0x540b14` branch reaches `0x49c0a6 -> 0x4ad947 -> 0x4ad7f7`, but the sibling `0x49c019/0x4adb72` writer path and `0x4adef7/0x4add76` cleanup writer path remain unhit in the same seed-controlled branch ledger.
- R2 is a source-backed supported one-level land target-mode exclusion, not a global all-map-mode exclusion and not native implementation authority.

## R3 Closure

R3 is closed by `.artifacts/rmg_recovery/r3_weighted_materialization_tail_closure_summary_20260611.json`.

Recovered R3 state:

- The recovered deterministic profile is seed-58 Large one-level no-water with Human/Computer `3` and Computer-only `0`; this is recovery evidence only, not a native behavior change.
- The sampled weighted materialization path reaches `0x4a9322`, dispatches through vtable slot `+0x04` into `0x4a54a7`, returns through `0x4a5756`, and reaches caller-after `0x4a9325`.
- Dispatch 0 appends record `0x036b6d40` at `(107, 6, 0)`, increments the object vector by one, increments `generator+0x1110[98]` from `4` to `5`, and has a complete `705`-stop `0x4a56b6` score-write count.
- Dispatch 1 appends record `0x036b68e0` at `(107, 106, 0)`, increments the object vector by one, increments `generator+0x1110[98]` from `6` to `7`, and has `517` matched `0x4a56b6/0x4a56b9` before/after score-write pairs.
- Dispatch 2 appends record `0x036b67e0` at `(18, 6, 0)`, increments the object vector by one, increments `generator+0x1110[98]` from `7` to `8`, and has `1295` matched `0x4a56b6/0x4a56b9` before/after score-write pairs.
- The descriptor type-98 bridge ties the sampled weighted counter increments to the sampled `0x4a54a7` descriptor/relation commit lane without assigning a final human object-kind label.
- R3 does not close global descriptor/source identity, source-handler pending-entry behavior, broader relation/scoring semantics, cleanup/uncommit behavior, endpoint success behavior, or the final ordered private-state replay.

## R4 Closure

R4 is closed by `.artifacts/rmg_recovery/r4_descriptor_source_identity_closure_summary_20260611.json`.

Recovered R4 state:

- All 87 selected mixed-lane descriptors for target contexts `0x004a744a | 45`, `0x004a98f0 | 53`, `0x004a5e6c | 54`, and `0x004a9c3f | 79` join by pointer to exact same-run `0x4903e8` descriptor build events.
- `descriptor+0x00` is recovered as the source-key registry value returned through `0x491eed`; mixed-lane row-mode samples prove it is not a universal zero-based `objects.txt` row id.
- `descriptor+0x1c` is the descriptor type/counter lane, `descriptor+0x20` is the subtype/source object id, and `descriptor+0x24` is the class/group-like selector. These fields are selector metadata, not a replacement for the full source record.
- The base object loader recovers `objects.txt` row stride `0x4c`, row `+0x1c` as object type id, row `+0x20` as subtype-like field, and the type-45 special case.
- The source catalog/template producer recovers full `0x4c` source-record preservation, DEF/name-bearing cache-key fields, and provider dispatch for target lanes 53 Mine, 54 Monster, and 79 Resource.
- Type 45, 54, and 79 sampled type/subtype pairs resolve against the catalog without row guessing. Type 53 mines are intentionally descriptor-only ambiguous because several DEF rows share a mine subtype; the recovered identity rule is to carry the copied source record, not guess among terrain variants.
- R4 did not close pending-entry behavior, relation/scoring semantic replay, ordered replay, or any native RMG parity changes. The pending-entry behavior is closed later by R5 below.

## R5 Closure

R5 is closed by `.artifacts/rmg_recovery/r5_source_handler_pending_entry_closure_summary_20260611.json`.

Recovered R5 state:

- The `0x53eafc` source-handler vtable is recovered from Ghidra constructor and data-reference evidence, including slot `+0x20 -> 0x48047c` queued-key cleanup.
- The source-handler wrapper lifecycle is statically closed under `0x484d9f -> 0x4802ac / 0x4afa99 -> 0x4af463 / 0x4af910 / 0x4af65e`.
- Ghidra reports zero incoming references to `0x484d9f` in the recovered reference surface.
- The deterministic seed-58 direct-generation WineDbg probe armed a breakpoint at `0x484d9f` and did not hit it.
- Generator pending-entry offsets `+0xeec`, `+0xef0`, and `+0xef4` are found in the Ghidra dump corpus, and all instruction-level accesses are within the orphaned `0x4af463` initializer, `0x4af910` cleanup, or `0x4af65e` stack-local teardown lifecycle.
- R5 closes only the direct RMG target-mode blocker. It does not claim the source-handler chain is dead in every game context or map mode, and it does not authorize native RMG parity changes by itself.
