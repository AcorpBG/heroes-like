# H3MapEd RMG Full Recovery Blockers

Document role: fixed blocker ledger for the remaining H3MapEd random-map-generation recovery work.

This ledger is the reporting baseline for the final recovery push. Do not expand subquestions into new top-level blockers unless there is source-backed proof that a newly discovered path feeds final generated output and cannot fit any blocker below.

## Progress Baseline

Original recovery baseline at ledger creation: about 75% recovered.

Current scored recovery after the first R1 sub-blocker: about 77% recovered.

Remaining fixed recovery budget: 23 of the original 25 points.

Percent movement rule: progress only moves when a blocker or explicitly named sub-blocker is closed by Wine/Ghidra/Python evidence. A new report, trace harness, or diagnostic does not move the percentage unless it proves or excludes required source behavior.

## Remaining Blockers

| ID | Remaining blocker | Weight | Closure criteria |
| --- | ---: | ---: | --- |
| R1 | Reward/guard projection chain: `0x4adb72 / 0x4ad7f7 / 0x4aa9b7 / 0x4aa3e9` | 7 | Recover a live successful path or source-backed exclusion. Must cover wrapper state, relation priority, `generator+0xc8`, `generator+0x1104`, `generator+0xf5c`, selected-member dispatch, and object-vector deltas. |
| R2 | Endpoint/cursor chain: `0x4a5e73 / 0x4a606b / 0x4a746b / 0x4a7605 / 0x4a696b / 0x4a7312` | 4 | Recover natural successful endpoint/cursor mutation or prove it unreachable for the target one-level land mode. Must explain stale `generator+0xf5c` and source/relation match gates. |
| R3 | Weighted materialization tail: `0x4a8db2 -> 0x4a901a -> 0x4a54a7` | 3 | First weighted dispatch is mostly recovered. Need remaining sampled dispatch write sets, intervening vector/counter mutation, and final per-dispatch generated-cell parity if native-port authority needs it. |
| R4 | Descriptor/source identity crosswalk for mixed lanes | 3 | Finish source-backed mapping for mixed descriptor lanes such as `45`, `53`, `54`, and `79`, source records, and template/catalog identity. No row-id guessing. |
| R5 | Source-handler pending-entry chain: `0x53eafc / 0x484d9f -> 0x4afa99` | 2 | Either recover a live owner/action and replay `generator+0xeec/+0xef0/+0xef4`, or source-exclude it from the direct RMG target mode. |
| R6 | Relation/scoring semantic replay | 2 | Runtime-name remaining scoring/relation surfaces: `0x49e1bf`, `0x4a5767/0x49a318`, and `0x4a54a7` relation/control linkage. |
| R7 | One continuous ordered private-state replay | 4 | Stitch recovered pieces into ordered replay from RMG entrypoint to final map write, with phase/private-buffer checkpoints. This is the final proof step before native parity changes. |

Original total remaining at ledger creation: 25 points.

Current remaining after R1-H1 closure: 23 points.

## Reporting Rules

- Report only against `R1` through `R7`.
- Keep subfunctions and subquestions inside their parent blocker.
- State the active blocker, evidence added, whether the evidence closes a blocker/sub-blocker, and the new recovered percentage.
- Do not claim native RMG parity from final-map deltas, density scalars, extra gates, brute-force retries, or report-only improvements.
- Use Ghidra, Wine, and Python-owned tooling for recovery evidence. GDScript is for live game behavior, not RMG recovery reports.
- If a path cannot be recovered, the acceptable result is a source-backed exclusion or a named unrecovered function/data structure, not a heuristic replacement.

## Active Blocker

Active blocker: R1.

Current R1 state:

- Recovered: one clean Medium seed-10 same-run `0x4aa354 -> 0x4aa1db -> 0x4a5c07 -> 0x49cf34` attach-order path.
- Recovered: sampled projection object recycle/destructor ownership for one-level land evidence; sampled projection objects are destroyed/freed and later ordinary constructors reuse the heap slots before final sampled slot `+0x08` dispatch.
- Recovered: projection slot static ownership (`0x540b00+0x08 -> 0x49c019 -> 0x4adb72/0x4adef7`, `0x540b14+0x08 -> 0x49c0a6 -> 0x4ad947`) and zero live projection-method hits in the scanned corpus.
- Recovered in R1-H1: seed-controlled Small 2-player seed-58 successful `0x4aa9b7 -> 0x4aa3e9` handoff joined to wrapper/member state. The trace records seven false `0x4aa9b7` calls before one success, candidate vector count `2`, selected index `1`, selected coordinate `(4,3,0)`, wrapper `0x0031df5c`, and one selected-member slot `+0x08` callback to ordinary `0x49baf5`; no projection-method target fires.
- Still open: broader proof that `0x4adb72/0x4ad7f7` projection-method dispatch is either naturally reachable or excluded for the selected one-level land target mode, including relation-priority/object-vector `+0xc8/+0x1104/+0xf5c` state around that projection chain.

## R1 Sub-Blockers

| ID | R1 sub-blocker | Status | Evidence |
| --- | --- | --- | --- |
| R1-H1 | Seed-controlled successful `0x4aa9b7 -> 0x4aa3e9` handoff | Closed, +2 points | `.artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_summary_20260610.json` |
| R1-H2 | `0x4adb72/0x4ad7f7` projection-method dispatch live path or source-backed exclusion | Open, 3 points | Existing corpus has zero live hits; needs stronger source exclusion or natural hit. |
| R1-H3 | Relation-priority/object-vector `+0xc8/+0x1104/+0xf5c` replay around projection methods | Open, 2 points | Static surfaces are named; runtime state remains unavailable until R1-H2 is closed. |
