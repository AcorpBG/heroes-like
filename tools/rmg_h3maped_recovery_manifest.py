#!/usr/bin/env python3
"""Emit the canonical H3MapEd RMG recovery manifest.

The manifest is intentionally about reverse-engineering state, not final map
counts. It records the binary identity, required function addresses, generated
cell layout, and checkpoint targets that must be proven before native behavior
changes are allowed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DEFAULT_H3MAPED = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/h3maped_recovery_manifest.json")

FRONTIER_SUMMARIES: list[dict[str, str]] = [
    {
        "id": "sampled_one_level_land_endpoint_reachability",
        "artifact": ".artifacts/rmg_recovery/supported_land_endpoint_reachability_summary_20260610.json",
        "status": (
            "sampled_one_level_land_endpoint_reachability_no_success_path_broader_source_gap_named"
        ),
        "meaning": (
            "Current sampled one-level land evidence has 50 live 0x4a5e73 entries, zero "
            "0x4a5e73 success-path mutation events, zero live 0x4a606b events, all six "
            "0x4a5e73 static callers grouped by gate, and six complete Medium 0x4a696b "
            "grid scans over 5,752 cells with zero owner/relation byte-pair matches. The "
            "checkpoint now also consumes the consolidated 0x4a61bc chain frontier, proving "
            "selected record 0x0361d290 reaches the later 0x4a79a3 payload loop and linked "
            "downstream 0x4a696b/0x4a7605/direct 0x4a7312 surfaces. This is a sampled scope "
            "checkpoint: the remaining proof is natural endpoint-stamping success, or a "
            "broader source/mode exclusion for supported one-level land."
        ),
    },
    {
        "id": "direct_one_level_land_recovery_frontier",
        "artifact": ".artifacts/rmg_recovery/direct_mode_recovery_frontier_summary_20260610.json",
        "status": "direct_mode_recovery_frontier_verified_target_mode_exclusions",
        "meaning": (
            "Current one-level land target-mode recovery excludes the 0x53eafc source-handler "
            "chain, the 0x4a696b direct GeneratedCell+0x28 mutation block, and projection-slot "
            "+0x08 cleanup as active direct-mode blockers. The same artifact keeps full "
            "end-to-end recovery incomplete and names the remaining blockers before native RMG "
            "behavior changes."
        ),
    },
    {
        "id": "0x4a696b_target_mode_reachability",
        "artifact": ".artifacts/rmg_recovery/4a696b_target_mode_reachability_summary_20260610.json",
        "status": "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained",
        "meaning": (
            "The current one-level land evidence has sampled 0x4a696b calls and complete "
            "Medium full-grid scans, but zero source/relation byte-pair matches, zero "
            "candidate appends, and zero direct mutation hits. The canonical source-relation "
            "gate report now also consumes the candidate-predicate trace proving the sampled "
            "empty candidate vectors occur before terrain/helper rejection, 0x49aa93/0x4a6795, "
            "candidate append, selected commit, or direct GeneratedCell+0x28 mutation."
        ),
    },
    {
        "id": "projection_slot_target_mode_reachability",
        "artifact": ".artifacts/rmg_recovery/projection_slot_target_mode_reachability_summary_20260610.json",
        "status": "projection_slot_target_mode_unreached_recycle_boundary_explained",
        "meaning": (
            "Projection slot +0x08 methods and cleanup ownership are statically recovered, but "
            "current Wine evidence shows sampled projection objects are destroyed/freed before "
            "ordinary final slot dispatch, with zero live cleanup/projection target hits."
        ),
    },
    {
        "id": "cleanup_dependency_frontier",
        "artifact": ".artifacts/rmg_recovery/cleanup_dependency_frontier_summary_20260610.json",
        "status": "cleanup_dependency_frontier_downstream_of_unhit_projection_slot",
        "meaning": (
            "Cleanup/uncommit is classified as downstream of the unhit projection-slot chain "
            "for current sampled one-level land evidence. Static ownership remains real, but "
            "0x49c019, 0x49c0a6, 0x4add76, and 0x4adef7 all have zero live hits in the current "
            "corpus, so cleanup is not an active upstream explanation for the missing endpoint "
            "cursor in this sampled scope. Runtime cleanup mutation semantics remain unrecovered "
            "if a projection slot becomes live later."
        ),
    },
    {
        "id": "exact_fallback_coordinate_projection_reconciliation",
        "artifact": ".artifacts/rmg_recovery/coordinate_projection_reconciliation_summary_20260610.json",
        "status": (
            "coordinate_projection_exact_cross_seed_fallback_and_744a_reconciled_remaining_contexts_pending"
        ),
        "meaning": (
            "The older mixed-trace coordinate mismatch is superseded for exact Medium seed-10 "
            "fallback records 0x036260c0 and 0x03626060: construction, state-chain commit, "
            "after-state commit, descriptor/relation coordinates, exact projection writes, "
            "object-vector survival, and phase-tail completion agree for those records. "
            "Medium seed-1/seed-2 evidence also proves all 31 sampled 0x4a5e6c "
            "fallback-return commits clear the sampled GeneratedCell+0x20 low word while "
            "preserving the high word. Focused non-fallback evidence also recovers the sampled "
            "0x4a744a direct endpoint afterstate and descriptor/relation contract; sampled "
            "non-fallback return contexts now have recovered streams at 0x4a98f0, 0x4a9c3f, "
            "and 0x4aa44d."
        ),
    },
    {
        "id": "post_fallback_phase_tail",
        "artifact": ".artifacts/rmg_recovery/post_fallback_phase_tail_summary_20260610.json",
        "status": "post_fallback_49eb8d_49e700_4ac552_phase_tail_recovered",
        "meaning": (
            "Exact deterministic Medium seed-10 post-Border-Guard fallback phase tail is "
            "machine-checked from 0x49eb8d through the first normal 0x49e700 dispatch and "
            "the immediate 0x4ac552 success return: 0x49eb8d counts 2284 bit26 cells, "
            "computes budget 120, the first 0x49e700 dispatch performs 42 commit callbacks "
            "and 67 bit26-only GeneratedCell+0x28 writes, and 0x4ac552 returns to 0x4ae082 "
            "with AL=1. This is exact-path recovery only, not native behavior authorization."
        ),
    },
    {
        "id": "sampled_nonfallback_4a54a7_744a_contract",
        "artifact": ".artifacts/rmg_recovery/nonfallback_4a54a7_return_context_summary_20260610.json",
        "status": "nonfallback_4a54a7_744a_sampled_contract_recovered_remaining_contexts_pending",
        "meaning": (
            "Existing Wine/Ghidra/Python evidence recovers two sampled 0x4a744a direct endpoint "
            "afterstates and two descriptor/relation invocations: object-vector append, target-cell "
            "object reference, GeneratedCell+0x20 low-word clear, +0x28 occupied surface update, "
            "source-coordinate/descriptor-offset match, and relation-counter increment. This does "
            "not by itself authorize native RMG behavior changes."
        ),
    },
    {
        "id": "unresolved_nonfallback_4a54a7_return_owner_frontier",
        "artifact": ".artifacts/rmg_recovery/nonfallback_4a54a7_return_owner_summary_20260610.json",
        "status": "nonfallback_4a54a7_return_owners_sampled_streams_recovered",
        "meaning": (
            "The remaining non-fallback 0x4a54a7 callback return sites are statically owned: "
            "0x4a98f0 is the selected object callback return inside 0x4a9641, 0x4a9c3f is "
            "the selected object callback return inside 0x4a9911, and 0x4aa44d is the "
            "selected-member callback return inside 0x4aa3e9. Existing 0x4aa9b7/0x4aa3e9 "
            "runtime summaries also prove ordered wrapper handoff and sampled 0x4aa3e9 slot "
            "+0x04 callbacks into 0x4a54a7. Focused Wine traces recover one sampled "
            "0x4aa44d same-ledger write stream and one sampled 0x4a98f0 same-ledger write "
            "stream, and a return-site-driven Wine trace recovers one sampled 0x4a9c3f "
            "target-return same-ledger write stream. Broader 0x4aa44d/0x4a98f0/0x4a9c3f "
            "coverage remains pending if all instances are needed."
        ),
    },
    {
        "id": "sampled_4a9641_4a98f0_4a54a7_write_stream",
        "artifact": ".artifacts/rmg_recovery/mine_owner_4a9641_4a54a7_dynamic_summary_20260610.json",
        "status": "mine_owner_4a9641_4a54a7_write_stream_recovered",
        "meaning": (
            "WineDbg live recovery for the 0x4a9641 selected-object callback proves the sampled "
            "path enters 0x4a54a7 and returns to 0x4a98f0. The callback appends the selected "
            "object to the generator object vector, adds that object reference to the target "
            "generated cell, preserves the target +0x20 high word, lowers the target low word "
            "from 27 to 2 without clearing it to zero, and executes 319 unique 0x4a56b6 "
            "projection writes that preserve high words while lowering low words."
        ),
    },
    {
        "id": "sampled_4a9911_4a9c3f_4a54a7_write_stream",
        "artifact": ".artifacts/rmg_recovery/4a54a7_target_return_004a9c3f_dynamic_summary_20260610.json",
        "status": "4a54a7_target_return_004a9c3f_write_stream_recovered",
        "meaning": (
            "WineDbg live recovery selected by stack return proves a sampled 0x4a54a7 callback "
            "returns to 0x4a9c3f, the continuation after the indirect call at 0x4a9c3c inside "
            "0x4a9911. The callback appends the selected object to the generator object vector, "
            "adds that object reference to the target generated cell, preserves the target +0x20 "
            "high word, clears the target low word from 2 to 0, and executes 98 unique 0x4a56b6 "
            "projection writes that preserve high words while lowering low words."
        ),
    },
    {
        "id": "sampled_4aa3e9_4aa44d_4a54a7_write_stream",
        "artifact": ".artifacts/rmg_recovery/4aa3e9_4a54a7_dynamic_summary_20260610.json",
        "status": "4aa3e9_4aa44d_4a54a7_write_stream_recovered",
        "meaning": (
            "WineDbg live recovery for the 0x4aa3e9 selected-member slot +0x04 callback "
            "proves the sampled path enters 0x4a54a7 and returns to 0x4aa44d. The callback "
            "appends the selected-member object to the generator object vector, adds that "
            "object reference to the target generated cell, preserves the target +0x20 high "
            "word, lowers the target low word from 14 to 2 without clearing it to zero, and "
            "executes 90 unique 0x4a56b6 projection writes that preserve high words while "
            "lowering low words."
        ),
    },
    {
        "id": "descriptor_type98_weighted_commit_bridge",
        "artifact": ".artifacts/rmg_recovery/descriptor_type98_bridge_summary_20260610.json",
        "status": "descriptor_type98_weighted_and_commit_lane_recovered",
        "meaning": (
            "Sampled descriptor/counter index 98 is recovered as a shared projection commit "
            "lane across existing Wine/Ghidra evidence: exact 0x4a54a7 descriptor/relation "
            "invocations use descriptor+0x1c value 98 with projection flag +0x29, source "
            "offsets +0x2c/+0x30 = (2,0), 6x6 masks, and relation counter increments; all "
            "three sampled weighted 0x4a901a materializations also return through 0x4a54a7 "
            "and increment generator+0x1110[98] by one while appending one object record. "
            "This is not a final human object-kind label."
        ),
    },
    {
        "id": "0x4a79a3_internal_growth_frontier",
        "artifact": ".artifacts/rmg_recovery/4a79a3_internal_growth_summary_20260609.json",
        "status": "4a79a3_internal_growth_4a61bc_append_boundary_recovered",
        "meaning": (
            "A Wine-backed internal 0x4a79a3 growth trace now has explicit invariant gates: "
            "one 0x4a79a3 entry, eight 0x49b3fb -> 0x4a61bc candidate pairs, six positive "
            "0x4a61bc returns that append one object-record pointer each, one zero-return "
            "pair that does not append, object-vector count 7 -> 13, one capacity "
            "reallocation 8 -> 16, and no later payload-loop reach in that trace. This "
            "recovers the first internal append boundary as 0x4a61bc reached from 0x4a79a3; "
            "0x4a61bc callee-side construction/commit semantics and the ordered bridge into "
            "payload-loop/downstream mutation remain separate blockers."
        ),
    },
    {
        "id": "0x4a61bc_append_commit_payload_frontier",
        "artifact": ".artifacts/rmg_recovery/4a61bc_chain_frontier_summary_20260610.json",
        "status": "4a61bc_append_commit_payload_downstream_frontier_recovered",
        "meaning": (
            "Existing Wine/Ghidra/Python evidence is now consolidated into one gated sampled "
            "chain: 0x4a79a3 reaches 0x4a61bc through 0x49b3fb; 0x4a61bc delegates object "
            "growth through 0x4a5e03; the sampled append occurs inside 0x4a54a7; three "
            "sampled 0x4a54a7 commits prove object-vector, generated-cell object-ref, +0x20, "
            "+0x28, and projection low-word mutation contracts; a selected 0x4a61bc-origin "
            "record reappears in the same run's 0x4a79a3 payload loop; and the linked payload "
            "reaches 0x4a696b and 0x4a7605. The current 0x4a696b sweep remains a negative "
            "frontier with 30 sampled calls, zero source/relation matches, and zero direct "
            "mutation hits."
        ),
    },
    {
        "id": "working_semantic_name_frontier",
        "artifact": ".artifacts/rmg_recovery/semantic_frontier_summary_20260610.json",
        "status": (
            "semantic_frontier_working_names_seed10_chain_cursor_source_and_4a606b_frontiers_recovered_broader_scope_pending"
        ),
        "meaning": (
            "Connection record bytes +0x08/+0x09/+0x0a, candidate record fields "
            "+0x00/+0x04/+0x08/+0x0c, exact descriptor projection flag/offset fields, "
            "relation descriptor-type occupancy counters, selected type-98 weighted/commit "
            "counter-lane mechanics, and selected GeneratedCell +0x20 roles now have "
            "source-backed working names. Connection byte +0x09 is recovered as "
            "the template connection Border Guard flag produced by 0x49f7c4. The exact seed-10 "
            "Border Guard downstream chain is recovered through fallback materialization and "
            "phase tail. 0x4a5e73 is recovered as the cursor-keyed endpoint helper with no "
            "current success-path hits, the non-self +0xf5c writers are bound to the unhit "
            "projection/cleanup slot chain, cursor-source setup/lifetime evidence proves "
            "+0xf58/+0x1104 initialization without +0xf5c seeding, sampled projection objects "
            "are destroyed/freed/reused before ordinary final dispatch, and 0x4a606b is "
            "statically recovered with no live hit in the current target corpus. Broader "
            "relation/control linkage, global descriptor type labels beyond sampled counter-lane "
            "evidence, broader semantic scope, and cleanup/uncommit semantics remain pending."
        ),
    },
    {
        "id": "0x4a5e73_cursor_frontier",
        "artifact": ".artifacts/rmg_recovery/4a5e73_cursor_frontier_summary_20260610.json",
        "status": "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit",
        "meaning": (
            "0x4a5e73 is recovered from Ghidra as the endpoint helper keyed by "
            "generator+0xf5c. It searches generator+0xd8/+0xdc and +0xc8/+0xcc, mutates "
            "GeneratedCell+0x2c/+0x28 only on the success path, marks generator+0x1104, "
            "and advances generator+0xf5c. Current Wine corpus scanning finds 50 live "
            "entries and zero success-path mutation hits; natural and forced Border Guard "
            "samples fail with stale generator+0xf5c before endpoint stamping."
        ),
    },
    {
        "id": "0x4a5e73_caller_gate_surface",
        "artifact": ".artifacts/rmg_recovery/4a5e73_caller_gate_surface_summary_20260610.json",
        "status": (
            "4a5e73_all_caller_gate_surface_recovered_current_scope_success_path_still_unrecovered"
        ),
        "meaning": (
            "All six static callers of 0x4a5e73 are now grouped by gate. Current corpus runtime "
            "hits reach only the 0x4a61bc natural Border Guard caller pair and the forced "
            "0x4a746b endpoint-normalize route; all observed entries still fail before 0x4a5e73 "
            "mutation. The 0x4a696b caller is blocked earlier by the recovered GeneratedCell+0x20 "
            "owner/relation byte-pair gate, and both 0x4a6cf2 endpoint callsites are static-only "
            "in the current corpus. Successful endpoint stamping remains unrecovered; the gap is "
            "now a broader source/mode that makes one of these gates live with seeded "
            "generator+0xf5c, or a source-backed exclusion for supported one-level land."
        ),
    },
    {
        "id": "cursor_writer_owner_frontier",
        "artifact": ".artifacts/rmg_recovery/cursor_writer_owner_exclusion_summary_20260610.json",
        "status": "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots",
        "meaning": (
            "The direct generator+0xf5c writer surface is exhausted to 0x4a5e73, 0x4adb72, "
            "and 0x4add76. Ghidra references bind 0x4adb72 to projection slot 0x540b00+0x08 "
            "through 0x49c019, and bind 0x4add76 under 0x4adef7, whose callers are 0x49c019 "
            "and 0x4ad947; 0x4ad947 is owned by projection slot 0x540b14+0x08 through 0x49c0a6. "
            "Current one-level land Wine evidence has zero projection/cleanup slot hits, so the "
            "remaining cursor-source blocker is outside the currently excluded non-self writer "
            "chain unless a broader mode naturally dispatches those projection slots."
        ),
    },
    {
        "id": "endpoint_cursor_state_access_surface",
        "artifact": ".artifacts/rmg_recovery/endpoint_cursor_state_access_summary_20260610.json",
        "status": "endpoint_cursor_state_access_surface_recovered_f5c_writers_bounded",
        "meaning": (
            "A widened headless Ghidra offset-access scan over endpoint-adjacent generator "
            "state covers 835 instructions touching +0xc8/+0xcc, +0xd8/+0xdc, +0xec4/+0xec8/"
            "+0xecc, +0xf58/+0xf5c, +0x10e4, +0x1104/+0x1108, and +0x1110. The scan still "
            "bounds direct generator+0xf5c writes to 0x4a5e73, 0x4adb72, and 0x4add76; the "
            "only direct +0xf58 write in this endpoint surface is setup path 0x49ecf2 at "
            "0x49ee6b; and +0x1104/+0x1108 accesses stay confined to 0x49f95a plus the "
            "endpoint/projection cleanup helpers. This strengthens the cursor-source frontier "
            "but does not recover a successful endpoint-stamping runtime path."
        ),
    },
    {
        "id": "cursor_source_frontier",
        "artifact": ".artifacts/rmg_recovery/cursor_source_frontier_summary_20260610.json",
        "status": (
            "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered"
        ),
        "meaning": (
            "Wine runtime lifetime evidence and Ghidra-derived access summaries prove the setup "
            "path initializes generator+0xf58 and generator+0x1104, but not generator+0xf5c; "
            "the first natural Border Guard endpoint attempt uses stale cursor 0x7a1befdf while "
            "active +0xd8 keys are 0..7; the direct +0xf5c writer surface is exhausted; and the "
            "known non-self writers are bound to the currently unhit projection/cleanup slot "
            "chain whose sampled projection objects are destroyed/freed/reused before ordinary "
            "final dispatch. A widened Ghidra endpoint-state scan confirms there is no additional "
            "direct +0xf5c writer in that scanned instruction surface. Successful 0x4a5e73/0x4a606b endpoint stamping remains "
            "unrecovered or unexcluded for broader supported one-level land."
        ),
    },
    {
        "id": "candidate_cursor_gate_frontier",
        "artifact": ".artifacts/rmg_recovery/candidate_cursor_gate_frontier_summary_20260610.json",
        "status": "candidate_cursor_gate_frontier_selected_path_f58_only_f5c_candidate_unselected",
        "meaning": (
            "The selected-candidate vtable contract surface now separates projection candidates "
            "gated by generator+0xf58/generator+0x10b4 from the only recovered candidate scorer "
            "directly gated by generator+0xf5c. Current 17 selected-create returns include one "
            "projection selection, but it is the 0x540c60/0x49ca8b path gated by +0xf58; the "
            "0x540ca0/0x49cd97 adjacent projection path gated by +0xf5c is present in the "
            "static contract table but unselected in the sampled trace. This narrows the "
            "endpoint cursor blocker without proving global unreachability or changing native "
            "RMG behavior."
        ),
    },
    {
        "id": "descriptor_category_cursor_gate_surface",
        "artifact": ".artifacts/rmg_recovery/medium_descriptor_category_surface_summary_20260608.json",
        "status": "descriptor_category_surfaces_separated_candidate_cursor_gate_named",
        "meaning": (
            "The descriptor/category surface now keeps candidate+0x04 type indices, "
            "descriptor+0x1c type/counter indices, relation control bytes, and candidate "
            "cursor gates separate. It proves the sampled selected projection candidate has "
            "type 83 on the 0x540c60/0x49ca8b generator+0xf58 path, while the only recovered "
            "generator+0xf5c-gated candidate 0x540ca0/0x49cd97 still has no sampled selected "
            "type index or downstream semantics. Numeric type indices are not human object-kind "
            "labels until source object/template mapping proves them."
        ),
    },
    {
        "id": "descriptor_label_crosswalk",
        "artifact": ".artifacts/rmg_recovery/descriptor_label_crosswalk_summary_20260610.json",
        "status": "descriptor_label_crosswalk_partial_descriptor45_row_unresolved",
        "meaning": (
            "The sampled 0x4a9f1c candidate+0x04 type ids are now source-labeled through "
            "the extracted object metadata table, including Campfire, Creature Bank, "
            "Random Resource, Resource, Seer's Hut, Shrine, Spell Scroll, Treasure Chest, "
            "and Windmill. Sampled descriptor+0x1c type 54 resolves to Monster with all "
            "sampled descriptor ids matching zero-based object-catalog rows; type 98 resolves "
            "to Town with all sampled descriptor ids matching zero-based object-catalog rows. "
            "Type 45 is labeled Monolith Two Way by type id, but sampled descriptor id/class "
            "word 1145 maps to a Cartographer row under the same row rule, so that row-level "
            "descriptor relation remains unrecovered."
        ),
    },
    {
        "id": "descriptor_word_row_mode",
        "artifact": ".artifacts/rmg_recovery/descriptor_word_row_mode_summary_20260610.json",
        "status": "descriptor_word_row_mode_mixed_class_word_recovered",
        "meaning": (
            "Exact sampled 0x4a54a7 descriptor/relation summaries prove descriptor+0x00 "
            "is not a universal zero-based objects.txt row pointer. Across 43 exact samples, "
            "31 descriptor words are row-like and 12 mismatch the zero-based catalog row type. "
            "Type 98 remains row-like in the current exact sample, but type 45 word 1145 maps "
            "to a Cartographer row while descriptor+0x1c is the Monolith Two Way lane; type "
            "53, 54, and 79 fallback samples also include mismatches. Treat descriptor+0x1c "
            "as a counter/type lane and recover each descriptor+0x00 producer path before "
            "using that word as final object identity."
        ),
    },
    {
        "id": "descriptor_producer_contexts",
        "artifact": ".artifacts/rmg_recovery/descriptor_producer_context_summary_20260610.json",
        "status": "descriptor_producer_contexts_named_assignment_paths_pending",
        "meaning": (
            "The descriptor+0x00 row/class-word surface is now separated by producer context. "
            "0x4a5e6c/type54 belongs to fallback/object materialization through 0x4a5e03; "
            "0x4a744a/type45 belongs to the sampled direct endpoint non-fallback return; "
            "0x4a9586/type98 belongs to the sampled pre-scheduler projection/weighted "
            "type-98 commit lane; 0x4a98f0/type53 belongs to the 0x4a9641 selected-object "
            "callback; and 0x4a9c3f/type79 belongs to the 0x4a9911 selected-object callback. "
            "The checkpoint names the remaining blocker directly: descriptor+0x00 assignment "
            "or constructor paths are still pending for the mixed/class-word lanes, so "
            "descriptor+0x00 remains unsafe as universal final object identity."
        ),
    },
    {
        "id": "descriptor_assignment_source_boundary",
        "artifact": ".artifacts/rmg_recovery/descriptor_assignment_source_summary_20260610.json",
        "status": (
            "descriptor_assignment_boundary_recovered_constructor_retains_descriptor_source_paths_pending"
        ),
        "meaning": (
            "Ghidra-backed marker checks verify 0x49ba89 is not the descriptor+0x00 "
            "assignment site. It reads an existing descriptor pointer from the stack, stores "
            "it at object-record +0x04, increments descriptor +0x08, and initializes "
            "object-record coordinate fields. Sampled owners construct or dispatch records "
            "with existing descriptor pointers, while 0x4a9e40 and 0x4af785 are upstream "
            "selector/resolver surfaces. The remaining descriptor identity blocker is the "
            "static/data constructor or loader that populates descriptor records plus selected "
            "descriptor source proof for mixed type 45/53/54/79 lanes."
        ),
    },
    {
        "id": "descriptor_source_resolver_boundary",
        "artifact": ".artifacts/rmg_recovery/descriptor_source_resolver_summary_20260610.json",
        "status": "descriptor_source_resolver_boundary_recovered_source_catalog_identity_pending",
        "meaning": (
            "Ghidra-backed marker checks now recover the wrapper/source resolver boundary. "
            "0x49db76 initializes a 0xe8 wrapper whose +0x00 points at a copied 0x4c "
            "source record. 0x4af785 reuses a matching wrapper or copies the source record, "
            "initializes a new wrapper, appends source-pair metadata to generator+0xedc, "
            "and appends the wrapper into the selected lane bucket. 0x4af89f selects a "
            "source lane by scanning source-record mask words at +0x18. 0x4a9e40 filters "
            "bucket wrappers by backing source-record fields +0x20/+0x24 and mask "
            "compatibility before choosing one passing wrapper by RNG. The remaining "
            "blocker is source-catalog/object-template mapping for those 0x4c source "
            "records, not the wrapper initializer."
        ),
    },
    {
        "id": "source_record_field_surface",
        "artifact": ".artifacts/rmg_recovery/source_record_field_surface_summary_20260610.json",
        "status": "source_record_field_surface_recovered_identity_mapping_pending",
        "meaning": (
            "Ghidra/Wine marker checks now recover the active field-use surface for copied "
            "0x4c source records without claiming final object identity. Source record +0x18 "
            "is the mask-word surface; +0x1c is a resolver/relation lane index and indexes "
            "generator+0xee4; +0x20 and +0x24 participate in wrapper selection and relation "
            "branch gating; +0x30 and +0x34 gate additional relation-builder calls with "
            "index -1; and 0x4a93a2 copies the +0x10 and +0x20 field groups before marking "
            "+0x3c and mutating a related +0x28 bit-state word. The remaining blocker is "
            "still the source-catalog/object-template producer mapping tying these records "
            "to exact type/subtype/DEF rows, especially mixed descriptor lanes 45/53/54/79."
        ),
    },
    {
        "id": "source_record_identity_frontier",
        "artifact": ".artifacts/rmg_recovery/source_record_identity_frontier_summary_20260610.json",
        "status": "source_record_identity_frontier_recovered_producer_mapping_pending",
        "meaning": (
            "Ghidra/Wine/Python evidence now separates source-handler stream-key payload "
            "mapping from final object identity. 0x42b690 returns stream keys; 0x42b62a "
            "unwraps the concrete source pointer and delegates payload lookup to 0x42a83a; "
            "0x42a83a maps the key into a five-dword source-side slot and returns the "
            "nested pointer at slot +0x10 -> +0x08; and 0x42b63b copies the two-dword pair "
            "from the same slot family at +0x08/+0x0c. The sampled copied source-record "
            "+0x00 values are dense local keys 0..9, not recovered final object identities. "
            "The remaining blocker is the exact source catalog/template producer that "
            "populates those nested payloads from objects.txt/objtmplt.txt type/subtype/DEF rows."
        ),
    },
    {
        "id": "source_payload_materializer_frontier",
        "artifact": ".artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json",
        "status": "source_payload_materializer_recovered_catalog_mapping_pending",
        "meaning": (
            "Ghidra/Python evidence now recovers the refcounted nested-payload "
            "access/materialization layer below source-handler key lookup. 0x42a73a reads "
            "source object +0x10, materializes shared payloads through 0x42a75a, and returns "
            "holder +0x08. 0x42a75a clones through virtual slot +0x08, allocates a 12-byte "
            "holder, initializes it through 0x4370f4, decrements the old holder, and stores "
            "the replacement back at +0x10. 0x4370f4 initializes the holder as refcount 1, "
            "tag byte +0x04, payload pointer +0x08; 0x42bfe6 destroys temporary flagged "
            "holders. 0x42a48c confirms the same 20-byte/five-dword slot plus nested "
            "payload shape. This proves lifecycle/accessor mechanics only; the source "
            "catalog/object-template mapping remains pending."
        ),
    },
    {
        "id": "source_payload_producer_frontier",
        "artifact": ".artifacts/rmg_recovery/source_payload_producer_frontier_summary_20260610.json",
        "status": "source_payload_loader_boundary_recovered_catalog_semantics_pending",
        "meaning": (
            "Ghidra/Python evidence now names 0x41f350 as the source object and "
            "source-record loader/constructor boundary for the payload family consumed "
            "through 0x42a83a and copied as 0x4c source records. 0x41f350 initializes "
            "source object +0x00/+0x04, resolves a parsed family through 0x535214..0x535224, "
            "stores the resolved family index at +0x08 and mode byte at +0x0c, writes "
            "source-record +0x20/+0x24, indexes 0x4c-byte records, and copies populated "
            "records through 0x4c025c. 0x42df99 and sibling 0x42ddxx helpers are bounded "
            "as holder payload accessors that copy-on-write when shared and return payload "
            "+0x04. 0x4e6da2 is classified as a generic dynamic lookup/cast helper with "
            "many callers, not the source identity producer. Remaining blockers are the "
            "exact 0x43b0ff/0x433d7d input parse semantics, human category/provider-slot "
            "semantics for later variant builders, and final mapping from populated 0x4c "
            "records to objects.txt/objtmplt.txt type/subtype/DEF rows."
        ),
    },
    {
        "id": "relation_normalization_static_frontier",
        "artifact": ".artifacts/rmg_recovery/relation_normalization_summary_20260610.json",
        "status": "relation_normalization_static_surface_recovered_runtime_replay_pending",
        "meaning": (
            "Ghidra/Python checks prove the 0x4a5767 relation-local generated-cell reset, "
            "relation-bounds scan, 0x49a932 fallback mark, and two 0x49a318 propagation "
            "delegations, plus the 0x49a318 owner/projection propagation helper surface. "
            "Runtime ordered replay and human semantic names for propagated scores, owner-byte "
            "roles, descriptor policy bytes, and relation-field roles remain pending before "
            "native behavior changes."
        ),
    },
    {
        "id": "source_record_parser_frontier",
        "artifact": ".artifacts/rmg_recovery/source_record_parser_summary_20260610.json",
        "status": "source_record_parser_surface_recovered_catalog_identity_pending",
        "meaning": (
            "Ghidra/Python marker checks now recover the 0x4c025c stream-to-source-record "
            "parser surface called by 0x41f350. The parser writes a length-prefixed blob "
            "to source-record +0x10, populates a seven-dword field group at +0x20 through "
            "0x4b3419, expands one read byte into an eight-bit bitset at +0x3c, writes "
            "version-gated boolean flags at +0x40/+0x41, writes two signed word-derived "
            "dwords at +0x44/+0x48, and performs a final guarded 0x10-byte local read. "
            "Remaining blockers are human field names and final mapping from populated source records to "
            "objects.txt/objtmplt.txt type/subtype/DEF rows."
        ),
    },
    {
        "id": "source_record_copy_helper_frontier",
        "artifact": ".artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json",
        "status": "source_record_copy_helper_surface_recovered_identity_mapping_pending",
        "meaning": (
            "Ghidra/Python marker checks recover the generic byte-buffer/string-holder helper "
            "family used by the source-record parser and source payload loader. 0x4019a4 "
            "assigns/copies holder slices, 0x401aa7 erases/shifts ranges after unsharing, "
            "0x401b0e ensures capacity or shrinks/clears, 0x4016fd releases/resets holder "
            "+0x04/+0x08/+0x0c, 0x401caa clones shared buffers before mutation, 0x401a72 "
            "copies bytes into a holder, and 0x401bed/0x401c51 allocate rounded capacity "
            "and commit growth. These helpers do not provide object identity; remaining "
            "blockers are human source-record field names and final source catalog/template "
            "mapping to objects.txt/objtmplt.txt type/subtype/DEF rows."
        ),
    },
    {
        "id": "source_input_layout_frontier",
        "artifact": ".artifacts/rmg_recovery/source_input_layout_frontier_summary_20260610.json",
        "status": "source_input_versioned_layout_recovered_field_semantics_pending",
        "meaning": (
            "Ghidra/Python evidence now recovers the local source-input parser layout below "
            "0x41f350 without claiming final field semantics. 0x43b0ff and 0x433d7d each "
            "have exactly one Ghidra call reference, both from 0x41f350. 0x41f350 parses "
            "into a local source-input record through 0x43b0ff, runs 0x433d7d against the "
            "same source/input wrapper, then matches a parsed field against the global "
            "source-family table 0x535214..0x535224. 0x433d7d unwraps the source/input "
            "wrapper, calls a virtual reader at vtable +0x18, and requires the returned "
            "value to be at least 0x1f. 0x43b0ff initializes a versioned parser-output "
            "record with top-level fields, an eight-entry nested record array anchored at "
            "+0x34, 0x54-byte nested record stride, and version gates including 0x08, 0x09, "
            "0x0a, 0x0d, 0x10, 0x11, 0x12, 0x14, 0x19, and 0x1a. Remaining blockers are "
            "human field labels, exact stream helper semantics, final 0x4c source-record "
            "mapping, and human category/provider-slot semantics for later variant/filter builders."
        ),
    },
    {
        "id": "source_input_stream_helper_frontier",
        "artifact": ".artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json",
        "status": "source_input_stream_helper_surface_recovered_nested_semantics_pending",
        "meaning": (
            "Ghidra/Python evidence now recovers the stream-helper surface below the "
            "0x43b0ff parser. 0x40763d and 0x402461 are guarded one-byte reads through "
            "the source/input virtual reader at vtable +0x18 and require one byte to be "
            "returned. 0x407675 is the matching guarded four-byte read and requires four "
            "bytes to be returned. 0x4190cb is bounded as a length-prefixed blob/vector "
            "copy using a 0x407675 dword length and 0x200-byte chunks. 0x43acf0 reads "
            "three one-byte values into three dwords and normalizes an all-0xff triplet "
            "to -1. 0x43ad49 reads a tag byte plus two boolean bytes and dispatches tag "
            "values 0..10. 0x43aec6 reads a selector byte, uses a word payload for "
            "selector 2, and delegates to 0x43acf0 for selector 0/1. The 0x43bb* helpers "
            "are bounded as bitset/range-to-container population helpers. Remaining "
            "blockers are parser field names, nested container semantics, exact tag-table "
            "meanings, final 0x4c source-record mapping, and human category/provider-slot semantics for later variant/filter builders."
        ),
    },
    {
        "id": "source_input_nested_container_frontier",
        "artifact": ".artifacts/rmg_recovery/source_input_nested_container_summary_20260610.json",
        "status": "source_input_nested_container_surface_recovered_type_names_pending",
        "meaning": (
            "Ghidra/Python evidence now verifies the next source-input helper layer below "
            "the stream-helper frontier. 0x40237c and 0x43bf8f are guarded two-byte reads, "
            "0x43bfc7 is a guarded one-byte read, 0x43bfff is a guarded 0x14-byte read, "
            "0x438937 is a guarded 0x10-byte read, and 0x41941a is a generic counted read "
            "through source/input vtable +0x18 with short-read diagnostics. The 0x4193cb/"
            "0x4192c0/0x419302 byte-buffer helper surface below 0x4190cb is mechanically "
            "bounded. Bitset families 0x416b09/0x416b35, 0x42d05f, 0x42d83c, and "
            "0x43beb9/0x43bee8 are mechanically bounded as word-indexed bit tests or "
            "set/clear helpers using index >> 5 and 1 << (index & 0x1f). Remaining blockers "
            "are human domain names, capacity-helper internals, parser-output field names, "
            "and final 0x4c source-record/catalog mapping."
        ),
    },
    {
        "id": "source_input_tag_table_frontier",
        "artifact": ".artifacts/rmg_recovery/source_input_tag_table_summary_20260610.json",
        "status": "source_input_tag_table_payload_surface_recovered_human_meanings_pending",
        "meaning": (
            "Ghidra/Python evidence now recovers the local 0x43ad49 tag dispatch payload "
            "surface without assigning human tag meanings. The 0x43ae9a table maps tags "
            "0..10 to branch targets 0x43adaa, 0x43add8, 0x43ae1c, 0x43ae41, shared "
            "0x43ae73 for tags 4..7, return-only 0x43ae96 for tags 8..9, and 0x43ae78 "
            "for tag 10. Common header fields are tag dword +0x00 and two boolean bytes "
            "+0x04/+0x05. Payload shapes are recovered for tags 0..10, including version-"
            "gated scalar reads, dword payloads, triplet payloads, and no-extra-payload "
            "tags. Remaining blockers are human tag meanings, output field names, and "
            "final 0x4c source-record/catalog mapping."
        ),
    },
    {
        "id": "source_variant_builder_frontier",
        "artifact": ".artifacts/rmg_recovery/source_variant_builder_summary_20260610.json",
        "status": "source_variant_builder_surface_recovered_category_semantics_pending",
        "meaning": (
            "Ghidra/Python evidence now recovers the helper surface called later by "
            "0x41f350 without assigning final object identities. 0x422868 reads copied "
            "source-record +0x1c as a category/lane selector, dispatches through category "
            "constants and global provider vtable slots, accumulates provider results, "
            "requires a non-null result, and writes an output present byte plus pointer. "
            "0x428d45 bounds source-family ranges through input +0x40/+0x44, global table "
            "0x535214, and descriptor mask predicate 0x41e915. 0x420e6b selects one of two "
            "holder families from +0x18, performs copy-on-write when shared, runs dynamic "
            "lookups through 0x4e6da2, and delegates existing/missing payload paths. 0x434073 "
            "wraps a dynamic lookup and delegates existing/missing result paths. Remaining "
            "blockers are human category/lane names, provider slot meanings, and final "
            "source-catalog/object-template row mapping."
        ),
    },
    {
        "id": "0x4a606b_reachability_frontier",
        "artifact": ".artifacts/rmg_recovery/4a606b_reachability_summary_20260610.json",
        "status": "target_mode_4a606b_static_contract_recovered_no_live_hit",
        "meaning": (
            "0x4a606b is recovered from Ghidra as the 0x4a61bc connection-region "
            "generated-cell writer with callers at 0x4a6516 and 0x4a6548. Natural seed-10 "
            "and forced +0x09 target traces fail before the helper because 0x4a5e73 returns "
            "failure, and the current corpus has breakpoint-only mentions but zero live "
            "0x4a606b stops/events. This is current target-corpus evidence, not a global "
            "unreachable proof."
        ),
    },
    {
        "id": "exact_seed10_border_guard_downstream_chain",
        "artifact": ".artifacts/rmg_recovery/border_guard_downstream_chain_summary_20260610.json",
        "status": "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending",
        "meaning": (
            "For exact Medium seed-10 one-level/no-water generation, the natural Border Guard "
            "+0x09 path is recovered from source flag through stale-cursor 0x4a5e73 misses, "
            "0x4a7605 -> 0x4a5e03 fallback construction of records 0x036260c0/0x03626060, "
            "0x4a54a7 commit/projection state, object-vector survival, first 0x49e700 "
            "mutation set, and 0x4ac552 phase tail. This is exact-record evidence only, not "
            "global native-port authority."
        ),
    },
]

FUNCTIONS: list[dict[str, Any]] = [
    {
        "address": "0x499e65",
        "name": "generated_cell_constructor",
        "status": "recovered_static_ghidra",
        "writes": ["cell+0x00 byte argument", "cell+0x04/+0x08/+0x0c zero", "calls 0x499ea3"],
    },
    {
        "address": "0x49a072",
        "name": "generated_cell_grid_reset",
        "status": "recovered_static_ghidra",
        "reads": ["grid+0x08 cell buffer", "grid+0x0c width", "grid+0x10 height", "grid+0x14 level count"],
        "writes": ["calls 0x499ea3 for width*height*levels cells with stride 0x30"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump recovers this as the full-grid reset loop that walks the wrapper cell buffer by stride 0x30 and delegates each record to 0x499ea3.",
    },
    {
        "address": "0x499ea3",
        "name": "generated_cell_initializer",
        "status": "recovered_static_ghidra",
        "writes": [
            "cell+0x10 = 0xffffffff",
            "cell+0x1c = 0x7fbc7fbc",
            "cell+0x20 = 0xffff7fbc",
            "cell+0x24 = (old & 0xc0000548) | 0x00000548",
            "cell+0x28 = (old & bit24) | bit25 | bit27",
            "cell+0x2c clears bit0",
        ],
        "reason": "This is the source prefill; the bit27 reduction before 0x4a4c8e is caused by later callers of 0x49a932/0x49aa63, not by a different initializer.",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_record_reset_leaf_dump recovers the generated-cell initializer leaf and its exact field writes.",
    },
    {
        "address": "0x49a1d8",
        "name": "generated_cell_validity_predicate",
        "status": "recovered_static_ghidra",
        "returns_true_when": ["cell+0x2b has bit 0x02 set", "terrain id (cell+0x24 & 0x3f) is not 9"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump recovers this predicate as a bit0x02 check on cell+0x2b followed by a terrain-id-not-9 check on cell+0x24 low six bits.",
    },
    {
        "address": "0x49a85d",
        "name": "generated_cell_bit27_neighborhood_stamp",
        "status": "recovered_static_ghidra",
        "writes": [
            "calls 0x49a932(true) for the center cell",
            "calls 0x49a932(true) for every cell in clipped [x-1,x+2) by [y-1,y+2) neighborhood on the same level",
        ],
        "coordinate_formula": "cell = grid+0x08 + 0x30 * (((level * grid_height) + y) * grid_width + x)",
    },
    {
        "address": "0x49a932",
        "name": "generated_cell_occupied_bit_writer",
        "status": "recovered_static_ghidra_hot_helper",
        "writes": ["when cell+0x2c bit0 clear: arg false clears bit27", "arg true sets bit27 then clears bit26"],
        "runtime_trace": "Direct seed58 helper tracing is intentionally bounded because repeated 0x49a85d stamps make 0x49a932 too hot; caller-side traces now explain the pre-0x4a4c8e bit27 surface.",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump confirms cell+0x2c bit0 suppresses mutation; otherwise false clears bit27, while true sets bit27 and clears bit26.",
    },
    {
        "address": "0x49aa63",
        "name": "generated_cell_decor_candidate_writer",
        "status": "recovered_static_and_seed58_pre_0x4a4c8e_runtime",
        "writes": ["when cell+0x2c bit0 clear: arg false clears bit26", "arg true sets bit26 then clears bit27"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e shows 490 calls, all arg true, 490 unique generated-cell flats, then 0x4a4c8e. This matches the seed-58 pre-0x4a4c8e bit26 count.",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump confirms cell+0x2c bit0 suppresses mutation; otherwise false clears bit26, while true sets bit26 and clears bit27.",
    },
    {
        "address": "0x49a962",
        "name": "generated_cell_bit26_center_and_bit27_neighborhood_clear",
        "status": "recovered_static_and_seed58_pre_0x4a4c8e_runtime_replay",
        "writes": [
            "calls 0x49aa63(true) for the center cell",
            "for the clipped 3x3 neighborhood, calls 0x49a932(false) only when bit22 is clear, 0x49a1d8 is true, and terrain id is not 8",
        ],
        "coordinate_formula": "cell = grid+0x08 + 0x30 * (((level * grid_height) + y) * grid_width + x)",
        "runtime_trace": "seed58_interactive_49a962_to_4a4c8e_lite records 490 calls before 0x4a4c8e; replaying its clear rule leaves exactly the 407 dumped bit27 cells.",
    },
    {
        "address": "0x49acf6",
        "name": "generated_cell_terrain_art_and_flag_writer",
        "status": "recovered_static_ghidra",
        "writes": [
            "cell+0x24 = (old & 0xffffc000) | (terrain_arg & 0x3f) | ((arg2 & 0xff) << 6)",
            "cell+0x28 = (old & 0xfffe7fff) | (((arg3 & 1) | ((arg4 & 1) << 1)) << 15)",
        ],
        "callers": ["0x49ce64 full-grid loop after 0x49a072 reset", "0x4af463", "0x49acee local/internal path"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump recovers terrain/art packing into cell+0x24 and two private bits packed into cell+0x28 bits 15..16.",
    },
    {
        "address": "0x4a59e2",
        "name": "generated_cell_projection_field_packer",
        "status": "recovered_static_contract",
        "reads": [
            "generated-cell pointer in ecx",
            "stack+0x04 high-word projection/local argument",
            "stack+0x08 direction/order argument masked to three bits",
            "stack+0x0c owner/source byte argument",
        ],
        "writes": [
            "writes stack+0x04 into the high word of cell+0x1c while preserving the low word",
            "writes (stack+0x08 & 7) into cell+0x28 bits 12..14 while preserving the other bits",
            "writes stack+0x0c into byte3 of cell+0x20 while preserving the lower 24 bits",
        ],
        "callers": ["0x4a5767"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_cell_reset_flag_helper_dump recovers this helper directly. It is the only direct caller-visible 0x4a59e2 contract and is used by 0x4a5767 during generated-cell normalization.",
    },
    {
        "address": "0x49abd6",
        "name": "object_mask_stamp_generated_cell_mutator",
        "status": "recovered_static_and_runtime_body_validity_trace",
        "writes": [
            "accepted descriptor-mask cells set cell+0x2a bit 0x40 and call 0x49a932(true), which sets w28 bit27 and clears bit26",
            "rejected descriptor-mask cells that also fail 0x41e951 clear cell+0x2b bit 0x02, which clears w28 bit25",
            "calls 0x40bb26 after both accepted and rejected cell mutation paths",
        ],
        "runtime_trace": "seed58_interactive_49abd6_to_4a8c15 records five object-footprint calls; seed58_interactive_49abd6_body_cells_to_4a8c15 records five 0x49ac6b body-cell writes at flats 184, 666, 604, 975, and 1059. A same-run direct-generation trace .artifacts/rmg_recovery/direct_generation_49ac8e_clears_to_4a8260 records 48 hits at 0x49ac8e before 0x4a8260; .artifacts/rmg_recovery/direct_generation_49ac8e_bit25_clear_summary.json proves those 48 unique clear flats equal the 48 bit25-clear cells in the 0x4a8260 boundary grid checksum 88d6d7ef92324a2785c9ea7f6c658ac8829f8d5f4f0468d33998c549999dd702.",
    },
    {
        "address": "0x499ee8",
        "name": "generated_cell_object_reference_remove",
        "status": "recovered_static_ghidra",
        "calls": ["0x4cce95"],
        "reads": [
            "generated-cell pointer in ecx",
            "object record pointer at stack+0x04",
            "cell object-reference vector begin/end at cell+0x04/+0x08",
            "cell bit-state word at +0x28",
            "cell owner/score word at +0x20",
        ],
        "writes": [
            "calls 0x4cce95 with the matching object-reference vector position",
            "when the object-reference vector is empty after removal, clears cell+0x28 bit22",
            "when the object-reference vector is empty after removal, sets cell+0x28 bit25",
            "sets the low word of cell+0x20 to 0x7fbc while preserving the high word",
        ],
        "callers": ["0x4add76", "0x4af910"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_499ee8_cell_reference_removal_dump recovers this generated-cell object-reference removal helper and its bit22/bit25/cell+0x20 low-word mutation.",
    },
    {
        "address": "0x4af6db",
        "name": "pending_object_cleanup_bit27_acceptance_predicate",
        "status": "recovered_static_ghidra",
        "calls": ["0x41e951"],
        "reads": [
            "generator/context pointer in ecx",
            "object record pointer at stack+0x08",
            "record coordinate triple at record+0x08/+0x0c/+0x10",
            "descriptor through record+0x04",
            "descriptor dimensions at +0x34/+0x38",
            "descriptor primary mask at +0x04 through 0x41e951",
            "generator generated-cell buffer/dimensions at +0x14/+0x18/+0x1c",
            "generated-cell bit-state word at +0x28",
        ],
        "returns": [
            "false when no in-bounds primary-mask-clear footprint cell is found",
            "false immediately when any in-bounds primary-mask-clear footprint cell has bit27 set",
            "true when at least one in-bounds primary-mask-clear footprint cell exists and none of those cells has bit27 set",
        ],
        "callers": ["0x4af910"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4af6db_pending_cleanup_predicate_dump recovers this as a non-mutating cleanup acceptance predicate used by 0x4af910 before uncommitting queued object records.",
    },
    {
        "address": "0x4af463",
        "name": "source_handler_generator_phase_initializer",
        "status": "recovered_static_contract_direct_owner_excluded",
        "calls": ["0x49d914", "0x49acf6", "0x4af785", "0x49ba89", "0x49e6cd", "0x40bb15"],
        "reads": [
            "generator/context pointer in ecx",
            "source handler pointer at stack+0x08",
            "stack arguments at stack+0x0c and stack+0x10 passed into 0x49d914",
            "source handler width/height at handler+0x04/+0x08",
            "source handler vtable 0x53eafc slots +0x00/+0x04/+0x08/+0x0c/+0x10/+0x14/+0x18",
            "generator generated-cell buffer/width at +0x14/+0x18",
        ],
        "writes": [
            "calls 0x49d914 to initialize the generator cell/object backing state",
            "stores the source handler pointer at generator+0xed8",
            "initializes 16-byte vector anchors at generator+0xedc and generator+0xeec",
            "sets the generator vtable pointer to 0x540cc8",
            "scans handler width/height and writes each generated cell through handler slot +0x10 and 0x49acf6",
            "when handler slot +0x14 accepts and cell+0x2c bit0 is clear, clears cell+0x2b bit 0x08",
            "when handler slot +0x18 accepts and cell+0x2c bit0 is clear, clears generated-cell bit27 and sets bit26 in cell+0x28",
            "streams handler-provided entries through slots +0x00/+0x08/+0x0c/+0x04",
            "resolves an object descriptor through 0x4af785, constructs a 0x1c object record through 0x49ba89, commits it with 0x49e6cd, and appends an 8-byte (handler key, object record) pair to generator+0xeec",
        ],
        "callers": ["0x4afa99"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4af463_source_handler_init_dump recovers this initializer and proves generator+0xed8 is the stack-supplied source handler consumed later by 0x4af910. Focused dump .artifacts/rmg_recovery/ghidra_4802ac_source_handler_constructor_dump and Ghidra-only verifier .artifacts/rmg_recovery/source_handler_53eafc_vtable_ghidra_summary_20260610.json recover the concrete vtable slot functions for this caller. Focused dumps .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump and .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump recover the lower helper chain. Ownership verifier .artifacts/rmg_recovery/source_handler_owner_chain_summary_20260610.json proves 0x4802ac and 0x4afa99 are called only by 0x484d9f, 0x4af463 and 0x4af910 are called only by 0x4afa99, Ghidra has zero incoming references to 0x484d9f, and the existing direct-generation WineDbg probe armed 0x484d9f without a breakpoint stop. This source-handler chain is therefore excluded as the current direct Small/Medium-generation blocker unless a separate live owner/action is later identified.",
    },
    {
        "address": "0x4afa99",
        "name": "source_handler_phase_wrapper",
        "status": "recovered_static_contract_direct_owner_excluded",
        "calls": ["0x4af463", "0x4af910", "0x4af65e"],
        "reads": [
            "caller argument at stack+0x04 forwarded as the source handler into 0x4af463",
            "caller flag at stack+0x08 forwarded into 0x4af910",
            "caller mode/source argument at stack+0x0c forwarded into 0x4af463",
            "caller dimension/budget argument at stack+0x10 forwarded into 0x4af463",
        ],
        "writes": [
            "allocates a stack-local generator/context at EBP-0xf08",
            "calls 0x4af463 on the stack-local generator",
            "immediately calls 0x4af910 on the same stack-local generator with the caller flag",
            "tears down the stack-local generator through 0x4af65e",
        ],
        "callers": ["0x484d9f at 0x484e65", "0x484d9f at 0x484e9e"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4af463_source_handler_init_dump/target_004afa99_FUN_004afa99.txt recovers this wrapper. The two 0x484d9f call sites construct a stack 0x53eafc handler through 0x4802ac and call 0x4afa99(handler, 1, mode, dimension_or_budget); the second call is gated by 0x42a1f9(source) and a source-size check. Ownership verifier .artifacts/rmg_recovery/source_handler_owner_chain_summary_20260610.json proves the wrapper has exactly those two Ghidra callers, both from 0x484d9f, and 0x484d9f has zero incoming Ghidra references. Existing WineDbg direct-generation probe evidence armed 0x484d9f without a breakpoint stop.",
    },
    {
        "address": "0x41f350",
        "name": "source_payload_record_loader_constructor",
        "status": "recovered_loader_boundary_catalog_semantics_pending",
        "calls": [
            "0x43b0ff",
            "0x433d7d",
            "0x42df99",
            "0x42dd11",
            "0x42dd3d",
            "0x4e6da2",
            "0x4c025c",
            "0x422868",
            "0x428d45",
            "0x420e6b",
            "0x434073",
        ],
        "reads": [
            "destination/source object pointer in ecx",
            "caller source/input pointers at stack+0x10 and stack+0x14",
            "parsed source family token compared with global table 0x535214..0x535224",
            "parsed mode byte stored at source object +0x0c",
            "0x4c-byte source-record arrays built from nested helper outputs",
        ],
        "writes": [
            "initializes source object +0x00 and +0x04",
            "stores resolved family index at source object +0x08",
            "stores mode byte at source object +0x0c",
            "writes copied source-record fields +0x20 and +0x24",
            "indexes and copies populated 0x4c source records through 0x4c025c",
        ],
        "unrecovered_semantics": [
            "human semantic labels for the versioned 0x43b0ff parser output fields",
            "human category/lane names and provider-slot meanings for variant/filter builders called from 0x41f350",
            "final objects.txt/objtmplt.txt type/subtype/DEF mapping for populated 0x4c source records",
        ],
        "ghidra_dump": "Focused dumps .artifacts/rmg_recovery/ghidra_source_payload_producer_frontier_dump_20260610 and .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_payload_producer_frontier_summary_20260610.json recover this loader boundary without claiming final catalog identity; .artifacts/rmg_recovery/source_variant_builder_summary_20260610.json recovers the later builder helper surface.",
    },
    {
        "address": "0x4c025c",
        "name": "source_record_stream_parser",
        "status": "recovered_parser_surface_catalog_identity_pending",
        "callers": ["0x41f350 at 0x41fab7", "0x4c1938 at 0x4c1950"],
        "calls": [
            "0x4016fd",
            "0x4190cb",
            "0x4019a4",
            "0x401aa7",
            "0x4b3419",
            "0x402461",
            "0x416b35",
            "0x40763d",
            "0x40237c",
            "0x438937",
        ],
        "reads": [
            "destination 0x4c source-record pointer in ecx",
            "source/input stream wrapper at stack+0x08",
            "format/version value at stack+0x0c",
            "one initial mode/default byte at stack+0x0f",
            "one stream byte expanded into eight bitset entries",
            "two guarded word values sign-extended into dword fields",
        ],
        "writes": [
            "copies a length-prefixed blob into source-record +0x10",
            "populates seven guarded dwords at source-record +0x20 through 0x4b3419",
            "sets/clears eight bitset entries at source-record +0x3c through 0x416b35",
            "writes version-gated boolean flags at source-record +0x40 and +0x41",
            "writes signed word-derived dwords at source-record +0x44 and +0x48",
        ],
        "unrecovered_semantics": [
            "human field names for the populated source-record offsets",
            "final objects.txt/objtmplt.txt type/subtype/DEF mapping for populated source records",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_004c025c_FUN_004c025c.txt plus verifier .artifacts/rmg_recovery/source_record_parser_summary_20260610.json recover this parser surface without claiming catalog identity.",
    },
    {
        "address": "0x4019a4",
        "name": "refcounted_byte_buffer_assign_slice",
        "status": "recovered_generic_helper_identity_mapping_pending",
        "callers": ["many, including 0x4c025c and 0x41f350"],
        "calls": ["0x401aa7", "0x4016fd", "0x401b0e", "0x4e6380"],
        "reads": [
            "target holder pointer in ecx",
            "source holder pointer at stack+0x08",
            "source start offset at stack+0x0c",
            "requested count at stack+0x10",
            "source holder data pointer at +0x04, length at +0x08, capacity at +0x0c",
            "buffer marker/refcount byte at data[-1]",
        ],
        "writes": [
            "target holder data pointer at +0x04",
            "target holder length at +0x08",
            "target holder capacity at +0x0c",
            "increments marker/refcount byte when sharing a full source buffer",
            "zero terminator at copied data[length]",
        ],
        "semantics": (
            "Assigns a bounded slice from one generic byte-buffer/string holder to another. "
            "Self-assignment is handled through two erase-range calls; full-buffer copy may "
            "share the source buffer; partial copy ensures capacity and copies bytes."
        ),
        "unrecovered_semantics": [
            "human field names for caller-specific payloads stored in the holder",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helpers_dump_20260610/target_004019a4_FUN_004019a4.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401aa7",
        "name": "refcounted_byte_buffer_erase_range",
        "status": "recovered_generic_helper_identity_mapping_pending",
        "callers": ["many, including 0x4019a4, 0x4c025c, and 0x41f350"],
        "calls": ["0x401caa", "0x4e66c0", "0x401b0e"],
        "reads": [
            "target holder pointer in ecx",
            "start index at stack+0x0c",
            "requested erase count at stack+0x14",
            "target holder data pointer at +0x04 and length at +0x08",
        ],
        "writes": [
            "moves the tail bytes left over the erased range",
            "updates target holder length at +0x08",
            "zero terminator at data[new_length]",
        ],
        "semantics": (
            "Unshares a generic byte-buffer/string holder, erases a bounded range, shifts "
            "the tail left, shrinks or normalizes capacity, updates length, and zero-terminates."
        ),
        "unrecovered_semantics": [
            "human field names for caller-specific payloads stored in the holder",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helpers_dump_20260610/target_00401aa7_FUN_00401aa7.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401b0e",
        "name": "refcounted_byte_buffer_ensure_capacity_or_shrink",
        "status": "recovered_generic_helper",
        "callers": ["0x4019a4", "0x401aa7", "0x401a72", "many generic holder users"],
        "calls": ["0x4016fd", "0x401bed"],
        "reads": [
            "target holder pointer in ecx",
            "desired length at stack+0x0c",
            "mode flag at stack+0x10",
            "holder data pointer at +0x04, length at +0x08, capacity at +0x0c",
            "buffer marker/refcount byte at data[-1]",
        ],
        "writes": [
            "may release/reset shared holder state",
            "may clear holder length at +0x08",
            "may zero-terminate current data",
            "delegates allocation/growth when capacity is insufficient",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helpers_dump_20260610/target_00401b0e_FUN_00401b0e.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x4016fd",
        "name": "refcounted_byte_buffer_release_reset",
        "status": "recovered_generic_helper",
        "callers": ["many generic holder lifecycle helpers, including 0x4019a4 and 0x401b0e"],
        "calls": ["0x5044da"],
        "reads": [
            "target holder pointer in ecx",
            "release flag at stack+0x08",
            "holder data pointer at +0x04",
            "buffer marker/refcount byte at data[-1]",
        ],
        "writes": [
            "decrements marker/refcount byte for shared buffers",
            "frees unique buffers",
            "clears holder data pointer, length, and capacity at +0x04/+0x08/+0x0c",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helpers_dump_20260610/target_004016fd_FUN_004016fd.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401caa",
        "name": "refcounted_byte_buffer_unshare",
        "status": "recovered_generic_helper",
        "callers": ["0x401aa7", "0x49125b"],
        "calls": ["0x4016fd", "0x4e62c0", "0x401a72"],
        "reads": [
            "target holder pointer in ecx",
            "holder data pointer at +0x04",
            "buffer marker/refcount byte at data[-1]",
        ],
        "writes": [
            "clones shared data and stores it back into the same holder before mutation",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helper_callees_dump_20260610/target_00401caa_FUN_00401caa.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401a72",
        "name": "refcounted_byte_buffer_copy_into_holder",
        "status": "recovered_generic_helper",
        "callers": ["0x401caa"],
        "calls": ["0x401b0e", "0x4e6380"],
        "reads": [
            "target holder pointer in ecx",
            "source byte pointer and length from stack arguments",
        ],
        "writes": [
            "ensures target capacity",
            "copies bytes into target holder data",
            "stores length at +0x08",
            "zero terminator at data[length]",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helper_lifecycle_dump_20260610/target_00401a72_FUN_00401a72.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401bed",
        "name": "refcounted_byte_buffer_allocate_rounded_capacity",
        "status": "recovered_generic_helper",
        "callers": ["0x401b0e"],
        "calls": ["0x5044b1", "0x401c51"],
        "reads": [
            "target holder pointer in ecx",
            "requested capacity at stack+0x08",
        ],
        "writes": [
            "rounds requested capacity with OR 0x1f",
            "allocates a new buffer",
            "jumps into the growth commit helper",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helper_callees_dump_20260610/target_00401bed_FUN_00401bed.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x401c51",
        "name": "refcounted_byte_buffer_growth_commit",
        "status": "recovered_generic_helper",
        "callers": ["0x401bed at 0x401c2a"],
        "calls": ["0x4e6380", "0x4016fd"],
        "reads": [
            "target holder pointer in esi",
            "new data pointer in eax",
            "rounded capacity/length in edi",
            "old holder data pointer and length",
        ],
        "writes": [
            "copies old bytes to new buffer when length is nonzero",
            "releases the old buffer",
            "stores new data pointer at +0x04",
            "stores new length at +0x08",
            "stores new capacity at +0x0c",
            "zero terminator at data[length]",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_copy_helper_lifecycle_dump_20260610/target_00401c51_FUN_00401c51.txt plus verifier .artifacts/rmg_recovery/source_record_copy_helper_summary_20260610.json recover this generic helper.",
    },
    {
        "address": "0x4b3419",
        "name": "source_record_field20_seven_dword_reader",
        "status": "recovered_static_contract_field_names_pending",
        "callers": ["0x4c025c at 0x4c02eb"],
        "calls": ["0x407675"],
        "reads": [
            "source/input stream wrapper at stack+0x08",
            "destination pointer at stack+0x0c",
            "seven guarded dwords from the stream through 0x407675",
        ],
        "writes": [
            "writes seven consecutive dwords to the caller destination",
        ],
        "unrecovered_semantics": [
            "human field names for the seven dwords at source-record +0x20 through +0x38",
        ],
        "ghidra_dump": "Focused caller dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/caller_004b3419_FUN_004b3419.txt plus verifier .artifacts/rmg_recovery/source_record_parser_summary_20260610.json recover the seven-dword read/write loop.",
    },
    {
        "address": "0x43b0ff",
        "name": "source_input_versioned_layout_parser",
        "status": "recovered_layout_field_semantics_pending",
        "callers": ["0x41f350"],
        "calls": [
            "0x4016fd",
            "0x40763d",
            "0x407675",
            "0x402461",
            "0x4190cb",
            "0x43acf0",
            "0x43ad49",
            "0x43aec6",
            "0x43bae0",
            "0x43bb1b",
            "0x43bb58",
            "0x43bb95",
            "0x43bbe1",
            "0x43bc24",
            "0x43bc67",
        ],
        "reads": [
            "caller mode byte at stack +0x0f",
            "source/input wrapper pointer at stack +0x08",
            "version/size value at stack +0x0c",
            "caller-provided source/input pointer passed through stack +0x10/+0x14 from 0x41f350",
        ],
        "writes": [
            "top-level parser-output fields at +0x00, +0x04, +0x08, +0x2c, +0x30, +0x2d4, +0x2f0, +0x300, +0x304, +0x324, and +0x338",
            "eight nested records anchored at output +0x34 with 0x54-byte stride",
            "nested record fields/payloads at -0x04, -0x03, +0x00, +0x04, +0x08, +0x0c, +0x0d, +0x0e, +0x10, +0x14, +0x20, +0x24, +0x28, +0x2c, +0x3c, and +0x44",
        ],
        "unrecovered_semantics": [
            "human semantic labels for individual parser-output and nested-record fields",
            "nested helper/container semantics below the structured parser helpers",
            "exact 0x43ad49 tag table meanings for values 0..10",
            "final mapping from parsed fields to populated 0x4c source records and object catalog rows",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_0043b0ff_FUN_0043b0ff.txt plus verifier .artifacts/rmg_recovery/source_input_layout_frontier_summary_20260610.json recover this versioned layout surface; .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover the primitive stream-read and structured helper surface.",
    },
    {
        "address": "0x40763d",
        "name": "source_input_guarded_read_byte_a",
        "status": "recovered_read_width_guard",
        "callers": ["many, including 0x43b0ff"],
        "calls": ["source/input vtable +0x18", "0x4023b4", "0x4e633b"],
        "reads": ["source/input wrapper pointer at ECX +0x00", "destination pointer at stack +0x08"],
        "guard": "requests one byte through the virtual reader and requires return value >= 1; short reads emit diagnostic path through 0x4e633b",
        "returns": ["original stream wrapper in EAX"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_0040763d_FUN_0040763d.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover this primitive guard.",
    },
    {
        "address": "0x402461",
        "name": "source_input_guarded_read_byte_b",
        "status": "recovered_read_width_guard",
        "callers": ["many, including 0x43b0ff and 0x43acf0"],
        "calls": ["source/input vtable +0x18", "0x4023b4", "0x4e633b"],
        "reads": ["source/input wrapper pointer at ECX +0x00", "destination pointer at stack +0x08"],
        "guard": "requests one byte through the virtual reader and requires return value >= 1; short reads emit diagnostic path through 0x4e633b",
        "returns": ["original stream wrapper in EAX"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_00402461_FUN_00402461.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover this primitive guard.",
    },
    {
        "address": "0x407675",
        "name": "source_input_guarded_read_dword",
        "status": "recovered_read_width_guard",
        "callers": ["many, including 0x43b0ff, 0x41f350, and 0x4190cb"],
        "calls": ["source/input vtable +0x18", "0x4023b4", "0x4e633b"],
        "reads": ["source/input wrapper pointer at ECX +0x00", "destination pointer at stack +0x08"],
        "guard": "requests four bytes through the virtual reader and requires return value >= 4; short reads emit diagnostic path through 0x4e633b",
        "returns": ["original stream wrapper in EAX"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_00407675_FUN_00407675.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover this primitive guard.",
    },
    {
        "address": "0x4190cb",
        "name": "source_input_length_prefixed_blob_reader",
        "status": "recovered_surface_byte_buffer_type_names_pending",
        "callers": ["many, including 0x43b0ff"],
        "calls": ["0x407675", "0x4193cb", "0x4192c0", "0x419302", "0x41941a"],
        "reads": [
            "destination/container pointer at stack +0x0c",
            "source/input wrapper at stack +0x08",
            "dword length read through 0x407675",
        ],
        "writes": ["copies read bytes through 0x200-byte stack-buffer chunks into caller destination/container"],
        "unrecovered_semantics": [
            "human container type name and exact parser field name for the destination buffer",
            "capacity-helper internals below the dynamic byte-buffer helper family",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_004190cb_FUN_004190cb.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json bound this helper surface; .artifacts/rmg_recovery/ghidra_source_input_nested_container_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_nested_container_summary_20260610.json bounds 0x4193cb/0x4192c0/0x419302/0x41941a mechanically.",
    },
    {
        "address": "0x43acf0",
        "name": "source_input_three_byte_triplet_reader",
        "status": "recovered_surface",
        "callers": ["0x43b0ff", "0x43aec6"],
        "calls": ["0x402461"],
        "writes": [
            "three one-byte values widened into dwords at output +0x00/+0x04/+0x08",
            "all-0xff triplet normalized to -1/-1/-1",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_0043acf0_FUN_0043acf0.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover this triplet helper.",
    },
    {
        "address": "0x43ad49",
        "name": "source_input_tagged_record_reader",
        "status": "recovered_payload_surface_human_meanings_pending",
        "callers": ["0x43b0ff"],
        "calls": ["0x40763d", "tag-table branch helpers"],
        "writes": [
            "tag byte widened to output +0x00",
            "two boolean-like bytes at output +0x04 and +0x05",
            "tag 0 writes version-gated scalar at +0x08: word for version >= 0x15, signed byte otherwise",
            "tag 1 writes version-gated scalar at +0x08 and dword at +0x0c; old one-byte 0xff normalizes to -1",
            "tag 2 writes signed byte at +0x08 and dword at +0x0c",
            "tag 3 writes a three-byte triplet at +0x08 plus signed bytes at +0x14 and +0x18",
            "tags 4..7 write a three-byte triplet at +0x08",
            "tags 8..9 have no extra payload beyond the common header",
            "tag 10 writes unsigned byte at +0x08 and a three-byte triplet at +0x0c",
        ],
        "unrecovered_semantics": [
            "human meaning of tag values 0..10",
            "human field names for output offsets +0x08, +0x0c, +0x14, and +0x18",
            "final mapping from tagged payloads into populated 0x4c source records and catalog rows",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_0043ad49_FUN_0043ad49.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover the tagged-record header; .artifacts/rmg_recovery/ghidra_source_input_tag_table_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_tag_table_summary_20260610.json recover the local tag table and payload shapes.",
    },
    {
        "address": "0x43aec6",
        "name": "source_input_selector_record_reader",
        "status": "recovered_surface_selector_semantics_pending",
        "callers": ["0x43b0ff"],
        "calls": ["0x40763d", "0x40237c", "0x43acf0"],
        "writes": [
            "selector byte widened to output +0x00",
            "selector 2 reads a word payload at output +0x04",
            "selector 0/1 delegates to 0x43acf0 after output +0x04",
        ],
        "unrecovered_semantics": ["human meaning of selector values"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_0043aec6_FUN_0043aec6.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json recover this selector-record surface.",
    },
    {
        "address": "0x43bb1b/0x43bb58/0x43bb95/0x43bbe1/0x43bc24/0x43bc67",
        "name": "source_input_bitset_and_range_container_populators",
        "status": "recovered_surface_container_type_names_pending",
        "callers": ["0x43b0ff and related source/parser callers"],
        "calls": [
            "0x43bf8f",
            "0x43bfc7",
            "0x416b09",
            "0x43bfff",
            "0x438937",
            "0x43beb9",
            "0x42d05f",
            "0x416b35",
            "0x42d83c",
            "0x43bee8",
        ],
        "writes": [
            "bitset-selected values into caller-supplied containers",
            "range-selected values into caller-supplied containers",
            "fixed-bound population loops with bounds 0x9c and 0x80",
        ],
        "unrecovered_semantics": [
            "container type names and exact value-domain names",
            "capacity-helper internals below 0x416bac, 0x42f6f4, 0x430070, and 0x43bf35",
            "parser-output field names for the bitset/range container consumers",
        ],
        "ghidra_dump": "Focused dumps .artifacts/rmg_recovery/ghidra_source_input_stream_helpers_dump_20260610/target_0043bb*.txt plus verifier .artifacts/rmg_recovery/source_input_stream_helper_summary_20260610.json bound this helper family surface; .artifacts/rmg_recovery/ghidra_source_input_nested_container_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_nested_container_summary_20260610.json proves the nested bitset test/set/clear mechanics.",
    },
    {
        "address": "0x40237c/0x43bf8f/0x43bfc7/0x43bfff/0x438937/0x41941a",
        "name": "source_input_guarded_block_readers",
        "status": "recovered_read_width_guards",
        "callers": ["0x43b0ff helper family and 0x4190cb"],
        "calls": ["source/input vtable +0x18", "0x4023b4", "0x4e633b"],
        "guard": (
            "fixed/count read wrappers require the virtual reader to return the requested "
            "byte count: 0x40237c and 0x43bf8f request 2 bytes, 0x43bfc7 requests 1 byte, "
            "0x43bfff requests 0x14 bytes, 0x438937 requests 0x10 bytes, and 0x41941a "
            "requests the caller-provided count"
        ),
        "returns": ["original stream wrapper in EAX"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_nested_container_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_nested_container_summary_20260610.json recover these read-width guards.",
    },
    {
        "address": "0x416b09/0x416b35/0x42d05f/0x42d83c/0x43beb9/0x43bee8",
        "name": "source_input_nested_bitset_helpers",
        "status": "recovered_bit_operations_type_names_pending",
        "calls": ["0x416bac", "0x42f6f4", "0x430070", "0x43bf35"],
        "reads": [
            "bitset backing word pointer and current index/count fields",
            "requested bit index from caller or container cursor",
        ],
        "writes": [
            "set helpers OR 1 << (index & 0x1f) into backing word index >> 5",
            "clear helpers AND the inverse bit mask into backing word index >> 5",
        ],
        "returns": [
            "test helpers return booleanized bit presence",
            "set/clear helpers return backing pointer/container pointer",
        ],
        "unrecovered_semantics": [
            "human domain names for each bitset family",
            "capacity-helper internals below 0x416bac, 0x42f6f4, 0x430070, and 0x43bf35",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_input_nested_container_helpers_dump_20260610 plus verifier .artifacts/rmg_recovery/source_input_nested_container_summary_20260610.json recover these bitset operations mechanically.",
    },
    {
        "address": "0x433d7d",
        "name": "source_input_minimum_size_guard",
        "status": "recovered_guard_contract",
        "callers": ["0x41f350"],
        "calls": ["source/input vtable +0x18", "0x4023b4", "0x4e633b"],
        "reads": [
            "source/input wrapper pointer at ECX +0x00",
            "caller-provided diagnostic/context pointer at stack +0x08",
            "virtual reader return value from source/input vtable +0x18",
        ],
        "returns": ["original wrapper/object pointer in EAX"],
        "guard": "requires virtual reader return value to be at least 0x1f; otherwise emits diagnostic/assertion path through 0x4e633b",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_00433d7d_FUN_00433d7d.txt plus verifier .artifacts/rmg_recovery/source_input_layout_frontier_summary_20260610.json recover this guard contract.",
    },
    {
        "address": "0x422868",
        "name": "source_variant_category_dispatch_builder",
        "status": "recovered_surface_category_semantics_pending",
        "callers": ["0x41f350 at 0x41f800", "0x41f350 at 0x41f98d", "0x423832"],
        "calls": [
            "global provider vtable slots, including +0xac and +0xbc",
            "0x412041",
            "0x42bfe6",
            "0x42c913",
            "0x4c6488",
            "0x42c8d9",
            "0x4e633b",
        ],
        "reads": [
            "source record pointer from stack+0x0c",
            "source record +0x1c category/lane selector",
            "global provider object at 0x59e390",
        ],
        "writes": [
            "local candidate/result accumulator",
            "output present byte at caller output +0x00",
            "output pointer at caller output +0x04",
        ],
        "unrecovered_semantics": [
            "human names for category/lane constants such as 0x1a, 0x2a, 0x35, 0x45, 0x46, 0x4d, 0x71, and 0xa2",
            "human meanings for provider vtable slots used by each category path",
            "final source-catalog/object-template row mapping",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_00422868_FUN_00422868.txt plus verifier .artifacts/rmg_recovery/source_variant_builder_summary_20260610.json recover this dispatcher surface without assigning object identities.",
    },
    {
        "address": "0x428d45",
        "name": "source_variant_range_mask_predicate",
        "status": "recovered_surface_field_semantics_pending",
        "callers": ["0x41f350 at 0x41f818", "0x420406", "0x426e08"],
        "calls": ["0x41e915"],
        "reads": [
            "source/input-derived lower bound at +0x40",
            "source/input-derived upper bound at +0x44",
            "global source-family table 0x535214",
            "descriptor mask surface through 0x41e915",
        ],
        "returns": [
            "AL=1 when range checks and descriptor mask predicate pass",
            "AL=0 otherwise",
        ],
        "unrecovered_semantics": [
            "human names for the +0x40/+0x44 bounded fields",
            "final object/category meaning of the accepted range",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_00428d45_FUN_00428d45.txt plus verifier .artifacts/rmg_recovery/source_variant_builder_summary_20260610.json recover this range/mask predicate surface.",
    },
    {
        "address": "0x420e6b",
        "name": "source_variant_dynamic_lookup_inserter",
        "status": "recovered_surface_lookup_semantics_pending",
        "callers": ["0x41f350 at 0x41f9bb", "0x42a058"],
        "calls": ["0x432d56", "0x42a70f", "0x4e6da2", "0x4c242d", "0x428439", "0x4284d0"],
        "reads": [
            "mode byte at stack+0x0c",
            "two holder families selected from source/payload +0x18",
            "caller key/payload at stack+0x10",
            "dynamic lookup metadata constants supplied to 0x4e6da2",
        ],
        "writes": [
            "copy-on-write replacement holder when selected holder is shared",
            "payload mutation through 0x4c242d and existing/missing delegates",
        ],
        "unrecovered_semantics": [
            "human meaning of the two holder families selected by the mode byte",
            "dynamic lookup payload identity below 0x4e6da2/0x4c242d where needed for catalog mapping",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_00420e6b_FUN_00420e6b.txt plus verifier .artifacts/rmg_recovery/source_variant_builder_summary_20260610.json recover this dynamic inserter surface.",
    },
    {
        "address": "0x434073",
        "name": "source_variant_dynamic_lookup_wrapper",
        "status": "recovered_surface_lookup_semantics_pending",
        "callers": ["0x41f350 at 0x41f8d4"],
        "calls": ["0x4e6da2", "0x42825d", "0x4389a7"],
        "reads": [
            "caller dynamic object/source argument at stack+0x08",
            "caller payload arguments at stack+0x0c and stack+0x10",
            "dynamic lookup metadata constants supplied to 0x4e6da2",
        ],
        "returns": ["RET 0x10 after delegating existing-result or missing-result path"],
        "unrecovered_semantics": [
            "human identity of the dynamic lookup target",
            "final catalog mapping of the delegated payload",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610/target_00434073_FUN_00434073.txt plus verifier .artifacts/rmg_recovery/source_variant_builder_summary_20260610.json recover this wrapper surface.",
    },
    {
        "address": "0x4e6da2",
        "name": "generic_dynamic_lookup_or_cast_helper",
        "status": "recovered_generic_helper_not_source_identity_producer",
        "calls": ["0x4e6eee", "0x4e6f08", "0x4e6f62", "0x4e705b", "0x4e7193"],
        "reads": [
            "source/dynamic object pointer at stack+0x04",
            "type/lookup metadata pointers supplied by callers",
        ],
        "returns": [
            "dynamic lookup/cast result used by many unrelated callers",
            "not a final H3MapEd object catalog row identity",
        ],
        "callers": ["239 Ghidra call references in the current focused dump"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_frontier_dump_20260610/target_004e6da2_* and verifier .artifacts/rmg_recovery/source_payload_producer_frontier_summary_20260610 classify this as generic dynamic lookup/cast machinery.",
    },
    {
        "address": "0x42df99",
        "name": "source_holder_payload_accessor",
        "status": "recovered_static_contract",
        "calls": ["0x4337d5 when holder refcount/state requires copy-on-write"],
        "reads": ["holder pointer in ecx", "holder payload through [ecx]"],
        "returns": ["holder payload pointer plus 0x04"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_payload_producer_helpers_dump_20260610 recovers this as one holder payload accessor used repeatedly by 0x41f350.",
    },
    {
        "address": "0x4802ac",
        "name": "source_handler_53eafc_constructor",
        "status": "recovered_static_contract",
        "calls": ["0x42a1ec"],
        "reads": [
            "destination handler pointer in ecx",
            "source pointer at stack+0x04",
            "secondary source/policy pointer at stack+0x08",
            "mode byte at stack+0x0c",
            "source-derived values returned by two calls to 0x42a1ec",
        ],
        "writes": [
            "stores source handler vtable 0x53eafc at handler+0x00",
            "stores second 0x42a1ec result at handler+0x04",
            "stores first 0x42a1ec result at handler+0x08",
            "stores source pointer at handler+0x0c",
            "stores secondary source/policy pointer at handler+0x10",
            "stores mode byte at handler+0x14",
        ],
        "callers": ["0x484d9f at 0x484e56", "0x484d9f at 0x484e8f"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4802ac_source_handler_constructor_dump recovers this stack-handler constructor used by both 0x484d9f calls into 0x4afa99.",
    },
    {
        "address": "0x53eafc",
        "name": "source_handler_53eafc_vtable",
        "status": "recovered_static_disassembly_helper_chain_recovered",
        "slots": {
            "+0x00": "0x4802ea starts stream through 0x42a28e and 0x42b690; false at sentinel 0x535228, otherwise writes key and returns true",
            "+0x04": "0x48031b advances stream key through 0x42b6a7; false at sentinel 0x535228, otherwise updates key and returns true",
            "+0x08": "0x480352 maps key through 0x42b62a and returns mapped+0x04+0x0c for 0x4af785",
            "+0x0c": "0x48037b maps key through 0x42b63b and copies two dwords to the output pointer",
            "+0x10": "0x4803b6 maps x/y through 0x42b60f and returns the low nibble of the mapped record first dword",
            "+0x14": "0x4803e2 returns true when 0x43c5c4(secondary, x, y, mode) == 1",
            "+0x18": "0x4803ff returns true when 0x43c5c4(secondary, x, y, mode) == 2",
            "+0x20": "0x48047c calls 0x429ea3(source, mode, key)",
        },
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_vtable_dump plus Ghidra-only verifier .artifacts/rmg_recovery/source_handler_53eafc_vtable_ghidra_summary_20260610.json recover the concrete slot table installed by 0x4802ac. Focused dumps .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump, .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump, .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_helpers_dump, .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_callees_dump, and .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recover the helper chain used by the slots. Same-run pending-entry replay and source-side nested-vector contents remain pending.",
    },
    {
        "address": "0x42a1ec",
        "name": "source_header_table_lookup",
        "status": "recovered_static_contract",
        "reads": ["source pointer in ecx", "source header through [source]", "header+0x0c index into global table 0x535214"],
        "returns": ["global table dword selected by the source header index"],
        "callers": ["0x4802ac"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this source-header accessor used twice by the 0x53eafc handler constructor.",
    },
    {
        "address": "0x42a1e6",
        "name": "source_header_dword8_accessor",
        "status": "recovered_static_contract",
        "reads": ["source pointer in ecx", "source header through [source]", "header+0x08"],
        "returns": ["dword at source header+0x08"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this source-header sibling accessor.",
    },
    {
        "address": "0x42a1f9",
        "name": "source_header_byte10_accessor",
        "status": "recovered_static_contract",
        "reads": ["source pointer in ecx", "source header through [source]", "header+0x10"],
        "returns": ["byte at source header+0x10"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this source-header sibling accessor.",
    },
    {
        "address": "0x42a28e",
        "name": "source_mode_stream_table_select",
        "status": "recovered_static_contract",
        "reads": ["source pointer in ecx", "mode/index at stack+0x04", "source data/vtable chain at +0x1c"],
        "returns": ["pointer to source+0x1c table entry selected by mode/index"],
        "callers": ["0x4802ea", "0x48031b"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this as the mode-specific stream/table selector used by source-handler stream begin/advance slots.",
    },
    {
        "address": "0x42b690",
        "name": "source_stream_first_key",
        "status": "recovered_static_contract",
        "reads": ["selected stream/table pointer in ecx", "nested table at +0x10/+0x08"],
        "returns": ["first stream key dword"],
        "callers": ["0x4802ea"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this first-key helper used before sentinel 0x535228 is checked.",
    },
    {
        "address": "0x42b6a7",
        "name": "source_stream_next_key",
        "status": "recovered_static_contract",
        "reads": ["selected stream/table pointer in ecx", "current stream key at stack+0x04", "5-dword record table at +0x10/+0x08"],
        "returns": ["next stream key from record index current_key * 5 dwords"],
        "callers": ["0x48031b"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this next-key helper used before sentinel 0x535228 is checked.",
    },
    {
        "address": "0x42b62a",
        "name": "source_key_descriptor_record_lookup_wrapper",
        "status": "recovered_static_contract",
        "calls": ["0x42a83a"],
        "reads": ["source collection pointer in ecx", "stream key at stack+0x04"],
        "returns": ["0x42a83a(collection+0x04, key) result"],
        "callers": ["0x480352"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this wrapper used by source-handler vtable slot +0x08.",
    },
    {
        "address": "0x42a83a",
        "name": "source_key_descriptor_record_lookup",
        "status": "recovered_static_contract",
        "reads": ["collection pointer in ecx", "stream key at stack+0x04", "5-dword record table through collection+0x0c/+0x08", "record slot+0x10 pointer"],
        "returns": ["0 when record slot+0x10 pointer is null", "otherwise dword at pointer+0x08"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump recovers the key-to-record mapping used below 0x42b62a.",
    },
    {
        "address": "0x42a73a",
        "name": "source_payload_accessor_materialize_if_shared",
        "status": "recovered_lifecycle_contract_catalog_mapping_pending",
        "calls": ["0x42a75a"],
        "reads": [
            "source object pointer in ecx",
            "refcounted payload holder at source object +0x10",
            "holder refcount/count at holder +0x00",
            "nested payload pointer at holder +0x08",
        ],
        "writes": [
            "materializes shared holders through 0x42a75a before returning the payload pointer",
        ],
        "returns": [
            "0 when source object +0x10 is null",
            "otherwise nested payload pointer at holder +0x08",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_tail_dump_20260610/target_0042a73a_FUN_0042a73a.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover this accessor boundary. Final source catalog identity remains pending.",
    },
    {
        "address": "0x42a75a",
        "name": "source_payload_copy_on_write_materializer",
        "status": "recovered_lifecycle_contract_catalog_mapping_pending",
        "calls": ["vtable+0x08 on nested payload", "0x5044b1", "0x4370f4", "0x42bfe6"],
        "reads": [
            "source object pointer in ecx",
            "current refcounted payload holder at source object +0x10",
            "nested payload pointer at holder +0x08",
        ],
        "writes": [
            "calls nested payload vtable slot +0x08 to clone/materialize into a temporary holder",
            "allocates a 12-byte replacement holder",
            "initializes the replacement through 0x4370f4",
            "decrements the old holder refcount/count",
            "stores replacement holder at source object +0x10",
            "destroys temporary holder state through 0x42bfe6",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_dump_20260610/target_0042a75a_FUN_0042a75a.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover the materializer mechanics. The payload producer-to-catalog mapping remains pending.",
    },
    {
        "address": "0x4370f4",
        "name": "source_payload_tagged_holder_init",
        "status": "recovered_lifecycle_contract",
        "calls": ["0x42bfe6"],
        "reads": [
            "destination holder in ecx",
            "tag/flag byte at stack+0x04",
            "payload pointer at stack+0x0c",
        ],
        "writes": [
            "sets holder +0x00 refcount/count to 1",
            "stores tag/flag byte at holder +0x04",
            "stores payload pointer at holder +0x08",
            "destroys temporary holder argument through 0x42bfe6 after adoption",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_tail_dump_20260610/caller_004370f4_FUN_004370f4.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover this 12-byte holder initializer.",
    },
    {
        "address": "0x42a600",
        "name": "source_payload_holder_ref_release",
        "status": "recovered_lifecycle_contract",
        "calls": ["0x436cd1", "0x5044da"],
        "reads": [
            "source object pointer in ecx",
            "refcounted payload holder at source object +0x10",
        ],
        "writes": [
            "decrements holder refcount/count",
            "when count reaches zero, destroys through 0x436cd1 and frees through 0x5044da",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_tail_dump_20260610/target_0042a600_FUN_0042a600.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover the release helper.",
    },
    {
        "address": "0x42a48c",
        "name": "source_five_dword_slot_payload_presence_check",
        "status": "recovered_static_contract_catalog_mapping_pending",
        "reads": [
            "source collection table through ecx+0x0c",
            "20-byte/five-dword record slots",
            "record slot +0x10 holder pointer",
            "nested payload pointer at holder +0x08",
        ],
        "returns": [
            "true/nonzero when the selected 20-byte slot has a non-null nested payload pointer",
            "zero otherwise",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_tail_dump_20260610/target_0042a48c_FUN_0042a48c.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json confirm the five-dword slot and nested holder shape also seen at 0x42a83a.",
    },
    {
        "address": "0x42b63b",
        "name": "source_key_coordinate_payload_lookup",
        "status": "recovered_static_contract",
        "reads": ["source collection pointer in ecx", "output pointer at stack+0x04", "stream key at stack+0x08", "5-dword record table through collection+0x10/+0x08"],
        "writes": ["copies record slot+0x08 and slot+0x0c to the output pointer"],
        "callers": ["0x48037b"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this key-to-two-dword-payload helper used by source-handler vtable slot +0x0c.",
    },
    {
        "address": "0x42b60f",
        "name": "source_xy_tile_record_lookup_wrapper",
        "status": "recovered_static_contract",
        "calls": ["0x42a4d0"],
        "reads": ["source collection pointer in ecx", "two coordinate args on stack", "source collection substructures at +0x04 and +0x08/+0x04"],
        "returns": ["tile record pointer returned by 0x42a4d0"],
        "callers": ["0x4803b6"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers this x/y tile-record wrapper used by source-handler vtable slot +0x10.",
    },
    {
        "address": "0x42a4d0",
        "name": "source_xy_tile_record_lookup_6x6",
        "status": "recovered_static_contract",
        "reads": ["tile grid pointer in ecx", "two coordinate args on stack", "grid width at +0x00", "chunk pointer table at +0x08"],
        "returns": ["pointer to a 12-byte per-tile record inside a 6x6 chunk"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump and verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover the 6x6 chunk lookup. Coordinate argument naming is left semantic-pending; the chunked lookup contract is recovered and this is not a source catalog identity producer.",
    },
    {
        "address": "0x43c5c4",
        "name": "secondary_xy_tile_class_lookup_12x12",
        "status": "recovered_static_contract",
        "reads": ["secondary source/policy pointer in ecx", "x at stack+0x04", "y at stack+0x08", "mode byte at stack+0x0c", "12x12 chunk tables selected by mode"],
        "returns": ["packed 2-bit tile class value"],
        "callers": ["0x4803e2", "0x4803ff"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers the 12x12 chunk and packed 2-bit class lookup used by source-handler vtable slots +0x14/+0x18.",
    },
    {
        "address": "0x429ea3",
        "name": "source_mode_key_cleanup_remove",
        "status": "recovered_static_contract",
        "calls": ["0x432c27", "0x42034a"],
        "reads": ["source pointer in ecx", "mode byte at stack+0x04", "queued stream key at stack+0x08", "source holder refcount/count through [source]"],
        "writes": ["when the source holder is shared, clones through 0x432c27 before mutation", "calls 0x42034a(source+0x04, mode != 0, key)"],
        "callers": ["0x48047c"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_helpers_dump recovers the queued-key cleanup wrapper used by source-handler vtable slot +0x20. Focused erase-helper dumps recover the lower 0x42034a/0x432d56/0x42ab68 cleanup path.",
    },
    {
        "address": "0x42034a",
        "name": "source_mode_vector_key_erase_wrapper",
        "status": "recovered_static_contract",
        "calls": ["0x432d56", "0x42ab68"],
        "reads": ["mutable source container in ecx", "mode byte at stack+0x04", "key at stack+0x08", "mode-selected vector under container+0x18"],
        "writes": ["selects one of two vectors by mode != 0", "clones selected vector through 0x432d56 when shared", "erases key through 0x42ab68"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump recovers the source cleanup vector wrapper; focused erase-helper dumps recover the 0x432d56 clone path and 0x42ab68 key erase/free-list path.",
    },
    {
        "address": "0x42ab68",
        "name": "source_5dword_record_key_erase_free_list_push",
        "status": "recovered_static_contract",
        "calls": ["0x434b6f", "0x42b127", "0x42abe8"],
        "reads": [
            "source container in ecx",
            "key at stack+0x04",
            "copy-on-write holder at container+0x0c",
            "free-list head at container+0x08",
            "current/head key at container+0x10",
            "5-dword records addressed by key * 5 dwords",
        ],
        "writes": [
            "clones container+0x0c through 0x434b6f when the holder refcount/count is greater than one",
            "when container+0x10 equals the removed key, clears container+0x10; otherwise calls 0x42b127(container, key)",
            "patches neighbor record first/second dwords to unlink the removed key from the record chain",
            "writes the previous free-list head into the removed record first dword and stores the removed key at container+0x08",
            "calls 0x42abe8 on the removed record pointer to release its auxiliary pointer",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_helpers_dump recovers the key erase/free-list mutation. Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers the non-head edge-maintenance helper at mutation-contract level.",
    },
    {
        "address": "0x42b127",
        "name": "source_key_nested_vector_edge_cleanup",
        "status": "recovered_static_contract_semantic_names_pending",
        "calls": ["0x42efb3", "0x42b432", "0x42ccc6", "0x42b2fb", "0x42af80", "0x4afaea", "0x42b2cc", "0x42af44", "0x42b01f", "0x4cce95"],
        "reads": [
            "source container in ecx",
            "removed key at stack+0x04",
            "copy-on-write holder at container+0x0c through 0x42efb3",
            "removed key 5-dword record payload dwords at slot+0x08/+0x0c",
            "record auxiliary descriptor/payload chain through slot+0x10",
            "descriptor masks through 0x42ccc6 and 0x42af44",
            "nested vectors selected through 0x42b2fb, 0x42af80, and 0x42b01f",
        ],
        "writes": [
            "builds a clipped scan rectangle through 0x42b432 from the removed record payload and descriptor bounds",
            "for primary-mask accepted positions, finds the removed key in an 8-byte vector and erases it through 0x4afaea",
            "for secondary-mask accepted positions, finds the removed key in a 4-byte vector and erases it through 0x4cce95",
            "when nested vectors become empty, releases their holder through 0x42b2cc",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_callees_dump first identified this edge-maintenance helper. Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers the control flow, mask gates, vector erases, and empty-holder release behavior. Exact semantic names for the nested vector families remain pending.",
    },
    {
        "address": "0x42efb3",
        "name": "source_holder_copy_on_write_payload_pointer",
        "status": "recovered_static_contract",
        "calls": ["0x434b6f"],
        "reads": ["holder pointer in ecx", "holder refcount/count through [holder]"],
        "writes": ["clones through 0x434b6f when shared"],
        "returns": ["holder payload pointer at [holder]+0x04"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers this copy-on-write payload accessor used by 0x42b127.",
    },
    {
        "address": "0x42b432",
        "name": "source_key_edge_scan_rectangle_builder",
        "status": "recovered_static_contract_semantic_names_pending",
        "reads": ["source container in ecx", "output pointer at stack+0x04", "removed-record two-dword payload pointer at stack+0x08", "descriptor bounds pointer at stack+0x0c", "global table 0x535214"],
        "writes": ["writes four dwords describing a clipped scan rectangle/range to the output pointer"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers this range builder used before 0x42b127 scans nested source vectors.",
    },
    {
        "address": "0x42af44",
        "name": "source_descriptor_mask44_bit_test",
        "status": "recovered_static_contract",
        "reads": ["descriptor/payload pointer in ecx", "two coordinate args on stack", "bitset at descriptor+0x44"],
        "returns": ["true when the computed bit is set", "false when the computed bit is clear"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers this as a 48-bit descriptor mask predicate sibling used by 0x42b127.",
    },
    {
        "address": "0x42b2cc",
        "name": "source_nested_holder_release",
        "status": "recovered_static_contract",
        "calls": ["0x42b2f3", "0x5044da"],
        "reads": ["holder pointer in ecx", "held pointer/refcount"],
        "writes": ["decrements held refcount/count", "when it reaches zero, destroys through 0x42b2f3 and frees through 0x5044da", "clears the holder pointer"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42b127_source_edge_helper_callees_dump recovers this empty-holder release helper used after 0x42b127 erases nested vectors.",
    },
    {
        "address": "0x42abe8",
        "name": "source_record_aux_ref_release",
        "status": "recovered_static_contract",
        "calls": ["0x436cd1", "0x5044da"],
        "reads": ["record pointer in ecx", "auxiliary pointer at record+0x10", "auxiliary refcount/count at auxiliary+0x00"],
        "writes": ["decrements auxiliary refcount/count", "when it reaches zero, destroys through 0x436cd1 and frees through 0x5044da", "clears record+0x10"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_callees_dump recovers this record auxiliary release helper called by 0x42ab68.",
    },
    {
        "address": "0x42a51c",
        "name": "source_holder_payload_copy_refcount",
        "status": "recovered_static_contract",
        "reads": ["destination holder in ecx", "source holder pointer at stack+0x04", "five source dwords"],
        "writes": ["copies source dwords +0x00/+0x04/+0x08/+0x0c/+0x10 to destination", "increments refcount/count at copied +0x04 pointer", "increments refcount/count at copied +0x0c pointer"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_callees_dump recovers this clone payload copy helper used by 0x432d56.",
    },
    {
        "address": "0x432c27",
        "name": "source_holder_copy_on_write_clone",
        "status": "recovered_static_contract",
        "reads": ["pointer holder in ecx", "current holder pointer/refcount"],
        "writes": ["allocates 0x50 bytes", "initializes clone through 0x43757f", "decrements original refcount", "stores clone into pointer holder"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump recovers this source-holder copy-on-write clone helper used by 0x429ea3.",
    },
    {
        "address": "0x42bfd0",
        "name": "source_handler_holder_move",
        "status": "recovered_static_contract",
        "reads": ["destination holder in ecx", "source holder pointer on stack"],
        "writes": ["copies source holder flag byte and pointer dword to destination", "clears source holder flag byte"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump recovers this small holder move helper.",
    },
    {
        "address": "0x432d56",
        "name": "source_0x18_holder_copy_on_write_clone",
        "status": "recovered_static_contract",
        "calls": ["0x5044b1", "0x42a51c"],
        "reads": ["pointer holder in ecx", "old holder pointer"],
        "writes": ["allocates 0x18 bytes", "sets clone refcount/count to 1", "copies old holder payload into clone+0x04 through 0x42a51c", "decrements old holder refcount/count", "stores clone in pointer holder"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_erase_helpers_dump recovers this 0x18-byte copy-on-write clone helper used by 0x42034a.",
    },
    {
        "address": "0x42bfe6",
        "name": "source_handler_holder_destroy",
        "status": "recovered_static_contract",
        "reads": ["holder pointer in ecx", "holder flag byte", "holder object pointer"],
        "writes": ["when flag is nonzero and object pointer exists, calls object vtable slot +0x00 with true"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_53eafc_source_handler_nested_helpers_dump and verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover this small holder destroy helper.",
    },
    {
        "address": "0x42bde9",
        "name": "source_dword_vector_copy_replace_end",
        "status": "recovered_generic_helper",
        "reads": [
            "vector holder in ecx",
            "destination pointer at stack+0x08",
            "source/current pointer at stack+0x0c",
            "vector end/current limit at holder +0x08",
        ],
        "writes": [
            "copies dwords from the source/current pointer into the destination pointer until the vector end",
            "updates holder +0x08 to the advanced destination pointer",
            "stores the previous end/current pointer back to the caller stack slot",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_source_record_producer_candidate_dump_20260610/target_0042bde9_FUN_0042bde9.txt plus verifier .artifacts/rmg_recovery/source_payload_materializer_summary_20260610.json recover this as a generic vector copy helper, not a source catalog identity producer.",
    },
    {
        "address": "0x4af910",
        "name": "pending_object_cleanup_flush_then_decor_budget_pass",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4af6db", "0x4cce95", "0x4afaea", "0x41e951", "0x4268eb", "0x499ee8", "0x49eb8d"],
        "reads": [
            "generator/context pointer in ecx",
            "stack flag at stack+0x08",
            "8-byte pending vector at generator+0xef0/+0xef4",
            "pending vector anchor at generator+0xeec",
            "generator object-record vector at +0xec8/+0xecc with anchor at +0xec4",
            "source handler pointer at generator+0xed8 assigned by 0x4af463; for 0x484d9f this is the 0x53eafc handler constructed by 0x4802ac",
            "object record pointer from queued entry second dword",
            "queued entry first dword passed to handler vtable slot +0x20",
            "record descriptor through record+0x04",
            "descriptor byte +0x29",
            "descriptor dimensions +0x34/+0x38",
            "record coordinate triple at +0x08/+0x0c/+0x10",
            "generator generated-cell buffer/dimensions at +0x14/+0x18/+0x1c",
        ],
        "writes": [
            "when the stack flag is nonzero, walks the pending vector in reverse",
            "skips queued records whose descriptor byte +0x29 is nonzero or whose 0x4af6db check fails",
            "erases accepted records from the generator object-record vector through 0x4cce95",
            "calls generator+0xed8 vtable slot +0x20 with the queued entry first dword; for vtable 0x53eafc this dispatches to 0x48047c and then 0x429ea3(source, mode, key)",
            "erases the queued 8-byte entry through 0x4afaea",
            "walks the descriptor footprint and calls 0x499ee8(cell, record) for cells where the primary mask is clear or the secondary mask is set",
            "destroys the object record through vtable slot +0x00 with argument true",
            "calls 0x49eb8d after the optional cleanup loop",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_499ee8_cell_reference_removal_dump/caller_004af910_FUN_004af910.txt recovers this pending-object cleanup path and its handoff into 0x49eb8d. Focused dumps .artifacts/rmg_recovery/ghidra_4af463_source_handler_init_dump, .artifacts/rmg_recovery/ghidra_4802ac_source_handler_constructor_dump, and .artifacts/rmg_recovery/ghidra_53eafc_source_handler_vtable_dump prove generator+0xed8 is the stack-supplied source handler and recover the concrete cleanup slot for the 0x484d9f caller. Ownership verifier .artifacts/rmg_recovery/source_handler_owner_chain_summary_20260610.json excludes this closed source-handler chain as the current direct-generation blocker; natural projection, 0x4a696b, and cleanup/reselection blockers remain separate.",
    },
    {
        "address": "0x49d2c7",
        "name": "coord12_triple_store",
        "status": "recovered_static_contract",
        "reads": [
            "destination pointer in ecx",
            "coordinate dword 0 at stack+0x04",
            "coordinate dword 1 at stack+0x08",
            "coordinate dword 2 at stack+0x0c",
        ],
        "writes": [
            "writes stack+0x04 to destination+0x00",
            "writes stack+0x08 to destination+0x04",
            "writes stack+0x0c to destination+0x08",
            "returns the destination pointer in eax",
        ],
        "callers": ["0x49cf34", "0x4aa603", "0x4aa3e9", "0x4a79a3", "0x4ab6ac", "0x4aba05", "0x4abd5f"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_reward_guard_probe_helper_dump recovers this as a direct 12-byte coordinate-triple store helper used by reward/guard probe and projection callers.",
    },
    {
        "address": "0x4ae1fd",
        "name": "coord12_vector_append_one",
        "status": "recovered_static_contract",
        "calls": ["0x430b35"],
        "reads": [
            "12-byte vector anchor in ecx",
            "vector end pointer at ecx+0x08",
            "source 12-byte coordinate record pointer at stack+0x04",
        ],
        "writes": [
            "delegates to 0x430b35 with insertion position vector+0x08, count 1, and the source coordinate record pointer",
            "appends one 12-byte coordinate record to the vector",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump recovers this as the common 12-byte coordinate append wrapper used by reward/guard, connection, terrain, and decorative candidate scans.",
    },
    {
        "address": "0x4ae52a",
        "name": "coord12_vector_erase_range",
        "status": "recovered_static_contract",
        "reads": [
            "12-byte vector anchor in ecx",
            "vector end pointer at ecx+0x08",
            "destination pointer at stack+0x04",
            "source pointer at stack+0x08",
        ],
        "writes": [
            "moves 12-byte records from [source, vector_end) down to destination",
            "updates vector end pointer at ecx+0x08 to destination plus the moved tail length",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump recovers this as a 12-byte coordinate-vector range erase/shift helper used by candidate-vector filters.",
    },
    {
        "address": "0x4ae2d0",
        "name": "coord8_vector_erase_range",
        "status": "recovered_static_contract",
        "reads": [
            "8-byte vector anchor in ecx",
            "vector end pointer at ecx+0x08",
            "destination pointer at stack+0x04",
            "source pointer at stack+0x08",
        ],
        "writes": [
            "moves 8-byte records from [source, vector_end) down to destination",
            "updates vector end pointer at ecx+0x08 to destination plus the moved tail length",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump recovers this as an 8-byte coordinate-vector range erase/shift helper used by wrapper candidate cleanup and other coordinate-vector paths.",
    },
    {
        "address": "0x4aa3e9",
        "name": "reward_object_final_commit_and_wrapper_projection",
        "status": "recovered_static_and_sampled_ordered_source_mutation_replay",
        "calls": ["0x49d2c7", "0x49a1d8", "0x49a932", "0x49aa63"],
        "reads": [
            "generator/context pointer in ecx",
            "reward/guard wrapper pointer at stack+0x08",
            "selected coordinate triple args at stack+0x0c/+0x10/+0x14",
            "wrapper generated-cell grid at +0x08/+0x0c/+0x10",
            "wrapper selected-member vector begin/end at +0x2c/+0x30",
            "selected-member vtable at record+0x00 and relative coordinate triple at +0x08/+0x0c/+0x10",
            "generator generated-cell buffer/width/height at +0x14/+0x18/+0x1c",
            "generated-cell owner/score word at +0x20",
            "generated-cell terrain/art word at +0x24",
            "generated-cell bit-state word at +0x28, including bit22, bit26, and bit27",
        ],
        "writes": [
            "copies the selected coordinate triple into wrapper+0x54/+0x58/+0x5c",
            "iterates wrapper selected-member pointers and calls generator/context vtable slot +0x04 with each member pointer and member-relative coordinate plus the selected coordinate triple",
            "computes the overlap rectangle between the wrapper grid and generator grid at the selected coordinate",
            "for each overlapped cell, maps a source generator cell at selected x/y/level plus local offset and a destination wrapper cell at the local offset",
            "captures source bit26 and bit27 from source cell +0x28",
            "when source terrain is not 8, destination bit27 is clear, destination/source cells are valid, and destination/source bit22 are clear, calls 0x49a932(false) on the source cell",
            "under the same accepted branch, if destination bit26 is set, calls 0x49aa63(true) on the source cell",
            "copies captured source bit26 to the destination wrapper cell through 0x49aa63(captured_bit26)",
            "copies captured source bit27 to the destination wrapper cell through 0x49a932(captured_bit27)",
            "after projection, iterates wrapper selected-member pointers again and calls each member vtable slot +0x08",
        ],
        "runtime_trace": "Focused cell-projection trace .artifacts/rmg_recovery/direct_generation_4aa3e9_cell_projection_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa3e9_cell_projection_trace/4aa3e9_cell_projection_summary.json, records 296 parsed events from a manually cut trace: one 0x4aa3e9 entry, 98 complete source/destination loop samples, and one incomplete loop sample. For every completed sample, source ESI and destination EDI pointers remain stable from 0x4aa54f through 0x4aa5a9 and 0x4aa5bd, and the destination wrapper cell's post-mirror bit26/bit27 exactly match the source generated cell's pre-mirror bit26/bit27. The first completed sample mirrors source +0x28=0x16007000 into destination +0x28=0x07000000, preserving source bit26 true and bit27 false while retaining destination non-mirrored bits. Follow-up source-conditional trace .artifacts/rmg_recovery/direct_generation_4aa3e9_source_conditional_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa3e9_source_conditional_trace/4aa3e9_source_conditional_summary.json, records 31 parsed events: 12 entries, 8 paired 0x49a932(source,false) before/after samples, and 3 entries into the optional 0x49aa63(source,true) branch. The paired clear samples prove stable source/destination pointers, source bit27 false after the call, and source bit26 unchanged by the clear call; optional set-branch entries occur on source cells already seen after the clear path. Focused source-set-after trace .artifacts/rmg_recovery/direct_generation_4aa3e9_source_set_after_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa3e9_source_set_after_trace/4aa3e9_source_set_after_summary.json, records 138 parsed events: one entry, 2 paired before/after source bit26-set samples, and 135 after-set site stops. Each paired sample keeps source and destination pointers stable, leaves source bit27 unchanged, and records source bit26 true after the optional set call. Focused ordered single-call trace .artifacts/rmg_recovery/direct_generation_4aa3e9_ordered_single_call_trace/winedbg_interactive_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa3e9_ordered_single_call_trace/4aa3e9_ordered_summary.json, records 1,284 parsed events for one complete 0x4aa3e9 invocation: one entry, one selected-member slot +0x04 callback, 256 branch-after sites, 256 destination bit26 mirror pairs, 256 destination bit27 mirror pairs, one selected-member slot +0x08 callback, and one pre-return. This sampled invocation did not enter the optional source clear/set branch, and every destination bit26/bit27 after-call state matches the call argument. Focused source-site ordered trace .artifacts/rmg_recovery/direct_generation_4aa3e9_source_sites_ordered_trace/winedbg_interactive_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa3e9_source_sites_ordered_trace/4aa3e9_source_sites_ordered_summary.json, records 196 parsed events over 30 completed 0x4aa3e9 calls: 23 source bit27-clear before/after pairs and 8 completed calls that reach the source bit26 set-before site. The paired clear samples leave source bit27 false and source bit26 stable, and completed calls preserve wrapper pointer and selected-coordinate state from entry to return. This source-site ordered trace intentionally omits 0x4aa5a9, so source bit26 after-set state remains covered by the separate source-set-after trace.",
        "ghidra_dump": "Called by 0x4aa9b7 after that caller selects a candidate coordinate. Static recovery shows the final reward/guard wrapper projection shell: selected coordinate storage at wrapper+0x54, selected-member coordinate dispatch using object-record +0x08/+0x0c/+0x10 through the generator/context vtable slot +0x04, overlap projection from generator cells into wrapper cells while preserving source bit26/bit27 through 0x49aa63/0x49a932, conditional source bit27 clear/source bit26 set based on destination/source validity and bit22/terrain gates, and final selected-member vtable slot +0x08 callbacks. Focused runtime trace .artifacts/rmg_recovery/direct_generation_4aa3e9_projection_state_ebx_exit/4aa3e9_projection_summary.json pairs 12 entry/pre-return records; every exit wrapper pointer matches entry, every exit selected coordinate at wrapper+0x54/+0x58/+0x5c matches the stack coordinate args, selected-member vectors are non-empty, and the sampled distribution is 10 one-member wrappers plus 2 two-member wrappers. Follow-up inner trace summary .artifacts/rmg_recovery/direct_generation_4aa3e9_inner_calls/4aa3e9_inner_summary.json combines three focused traces and proves sampled dispatch/mutation sites: 16 generator/context slot +0x04 member callbacks all target 0x4a54a7, 14 final member slot +0x08 callbacks all target 0x49baf5, 109 destination bit26 mirror calls pair with 109 destination bit27 mirror calls, and the conditional source branch records 14 0x49a932(false) source bit27-clear calls plus 5 0x49aa63(true) source bit26-set calls. The corrected pre-return wrapper source is EBX because [EBP+8] is reused as an internal loop variable. Follow-up static summary .artifacts/rmg_recovery/direct_generation_4aa3e9_inner_calls/49baf5_static_summary.json verifies 0x49baf5 is mov al,1; ret, writes no memory, and is linked by the 0x4aa3e9 inner trace as the final selected-member slot +0x08 target. Follow-up broad slot +0x08 runtime summary .artifacts/rmg_recovery/direct_generation_4aa3e9_slot8_broad_trace/4aa3e9_slot8_summary.json records 12 paired 0x4aa3e9 entry/pre-return boundaries and 18 final selected-member slot +0x08 callbacks, all targeting 0x49baf5, with no sampled 0x540b00/0x540b14 projection-object vtables and no hits at 0x49c019, 0x49c0a6, 0x4adb72, 0x4ad947, 0x4ad7f7, or 0x4adb07. Sampled destination mirror replay, source bit27-clear replay inside completed calls, source bit26-set after-call state, one complete non-source-mutating entry-to-return invocation, and broad slot +0x08 no-projection-dispatch evidence are now proven; caller-to-generator object/vector commit ordering and the projection-object dispatch site remain pending.",
    },
    {
        "address": "0x4a4c8e",
        "name": "land_edge_generated_cell_bit_writer_entry_checkpoint",
        "status": "checkpoint_authority",
        "reads": ["generator+0x14 generated cells", "generator+0x10e4 runtime-zone relation vectors"],
        "runtime_trace": "Fresh direct-generation trace .artifacts/rmg_recovery/seed58_interactive_4a4c8e_fresh_boundary hit 0x4a4c8e once with generator 0x0031e058, dimensions 36x36x1, generated-cell buffer 0x0188b6d4, and live +0xc8/+0xd8 vector anchors. This trace uses the seed58 runtime directory but does not control H3MapEd's random seed. Full-grid summary .artifacts/rmg_recovery/seed58_4a4c8e_grid_summary.json records 1296 cells, w28 bit22=8 bit25=1200 bit26=652 bit27=368, nonzero w2c=0, owner-byte2 counts {-1:1,0:136,1:222,2:196,3:137,4:204,5:151,6:150,7:99}, and w20/w24/w28/w2c sha256 b5e238bc3f17d9f8891f76619bc8017f4ae5316c3daef699214b0bc29618ef3d. Treat these as direct-generation phase-shape evidence, not controlled seed-58 parity evidence.",
    },
    {
        "address": "0x4a80dc",
        "name": "route_line_cut_point_picker",
        "status": "recovered_static_and_seed58_runtime_pairs",
        "reads": ["grid generated-cell bit27 neighborhoods along a Bresenham-style line"],
        "returns": ["an output coordinate pair written through the caller-provided pointer"],
        "runtime_trace": "seed58_interactive_4a80dc_return_to_4a4c8e records 52 entry/return pairs before 0x4a4c8e.",
    },
    {
        "address": "0x4072b5",
        "name": "route_coordinate_vector_insert",
        "status": "recovered_static_ghidra",
        "reads": ["ecx vector begin/end/capacity at +0x04/+0x08/+0x0c", "insert position pointer", "count", "source pointer"],
        "writes": ["inserts count 8-byte coordinate records", "reallocates through 0x5044b1 when capacity is insufficient", "updates vector begin/end/capacity"],
        "returns": ["ret 0x0c; no caller-visible data return used by the traced route path"],
    },
    {
        "address": "0x40bb15",
        "name": "route_coordinate_vector_append_one",
        "status": "recovered_static_ghidra",
        "calls": ["0x4072b5"],
        "reads": ["ecx vector end at +0x08", "stack source pointer to one 8-byte coordinate"],
        "writes": ["appends one 8-byte coordinate record at vector end"],
    },
    {
        "address": "0x4ccecb",
        "name": "dword_vector_insert",
        "status": "recovered_static_ghidra",
        "reads": ["ecx vector begin/end/capacity at +0x04/+0x08/+0x0c", "insert position pointer", "count", "source pointer"],
        "writes": ["inserts count 4-byte records", "reallocates through 0x5044b1 when capacity is insufficient", "updates vector begin/end/capacity"],
        "returns": ["ret 0x0c; no caller-visible data return used by 0x40bb26"],
    },
    {
        "address": "0x40bb26",
        "name": "dword_vector_append_one",
        "status": "recovered_static_ghidra",
        "calls": ["0x4ccecb"],
        "reads": ["ecx vector end at +0x08", "stack source pointer to one 4-byte record"],
        "writes": ["appends one 4-byte record at vector end"],
    },
    {
        "address": "0x41e951",
        "name": "object_mask_bit_test",
        "status": "recovered_static_ghidra",
        "reads": ["object descriptor bitset at ecx+0x04", "x arg", "y arg"],
        "returns": ["true when bit 47 - 8*y - x is set in the descriptor bitset", "false when that bit is clear"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_object_projection_helper_dump recovers the exact bit index formula and bitset base. Calls 0x42f2ec when computed index is outside the expected 0..47 range.",
    },
    {
        "address": "0x4268eb",
        "name": "object_mask_secondary_bit_test",
        "status": "recovered_static_ghidra",
        "reads": ["object descriptor bitset at ecx+0x0c", "x arg", "y arg"],
        "returns": ["true when bit 47 - 8*y - x is set in the descriptor bitset", "false when that bit is clear"],
        "callers": [
            "0x42650e",
            "0x42b4b1",
            "0x49a6f9",
            "0x49b76d",
            "0x49abd6",
            "0x4aa195",
            "0x4ad3eb",
            "0x46b686",
            "0x47dac4",
            "0x4af910",
            "0x4add76",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4268eb_descriptor_mask_helper_dump recovers the exact bit index formula and bitset base. It is the ecx+0x0c sibling of 0x41e951's ecx+0x04 lookup and calls 0x42f2ec when computed index is outside 0..47.",
    },
    {
        "address": "0x41e915",
        "name": "object_mask_tertiary_bit_test",
        "status": "recovered_static_ghidra",
        "reads": ["object descriptor bitset at ecx+0x3c", "x arg", "y arg"],
        "returns": ["true when bit 47 - 8*y - x is set in the descriptor bitset", "false when that bit is clear"],
        "callers": ["0x41e84b", "0x428d45", "0x42ac12", "0x4205b9", "0x49b89c"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_41e915_descriptor_mask_helper_dump recovers the exact bit index formula and bitset base. It is the ecx+0x3c sibling of 0x41e951's ecx+0x04 lookup and 0x4268eb's ecx+0x0c lookup, and calls 0x42f2ec when computed index is outside 0..47.",
    },
    {
        "address": "0x4ae501",
        "name": "route_coordinate_vector_insert_one_return_position",
        "status": "recovered_static_ghidra",
        "calls": ["0x4072b5"],
        "reads": ["ecx vector begin at +0x04", "insert position pointer", "source pointer"],
        "writes": ["inserts one 8-byte coordinate record at the requested position"],
        "returns": ["pointer to the inserted coordinate after possible reallocation"],
    },
    {
        "address": "0x4afaea",
        "name": "route_coordinate_vector_erase_one",
        "status": "recovered_static_ghidra",
        "reads": ["ecx vector end at +0x08", "stack pointer to an 8-byte coordinate record"],
        "writes": ["shifts following 8-byte coordinate records left by one slot", "decrements vector end by 8 bytes"],
    },
    {
        "address": "0x4ae64c",
        "name": "route_coordinate_list_node_alloc",
        "status": "recovered_static_ghidra",
        "writes": ["allocates a 16-byte node", "node+0x00 prev pointer", "node+0x04 next pointer"],
        "payload": "node+0x08 contains one 8-byte coordinate record when used by 0x4ae5a8.",
    },
    {
        "address": "0x4ae5a8",
        "name": "route_coordinate_list_insert_after",
        "status": "recovered_static_ghidra",
        "calls": ["0x4ae64c"],
        "reads": ["existing node pointer", "source pointer to one 8-byte coordinate"],
        "writes": ["inserts a linked-list node after the existing node", "copies the 8-byte coordinate into node+0x08", "increments list count at ecx+0x08", "writes new node pointer through the caller output pointer"],
    },
    {
        "address": "0x4ae5e6",
        "name": "route_coordinate_list_remove_node",
        "status": "recovered_static_ghidra",
        "reads": ["node pointer"],
        "writes": ["unlinks and frees the node through 0x5044da", "decrements list count at ecx+0x08", "writes previous node pointer through the caller output pointer"],
    },
    {
        "address": "0x4a8260",
        "name": "pre_land_edge_route_and_boundary_phase",
        "status": "recovered_seed58_route_call_site_stream_and_static_route_helpers",
        "calls": [
            "0x40bb15 route coordinate append helper",
            "0x4ae501 route coordinate insert helper",
            "0x4afaea route coordinate erase helper",
            "0x4ae5a8 route coordinate list insert helper",
            "0x4ae5e6 route coordinate list remove helper",
            "0x4a80dc route cut helper",
            "0x49a85d route/neighborhood stamp",
            "0x49a962 boundary center and neighborhood clear",
        ],
        "runtime_trace": "For seed 58, caller-side traces before 0x4a4c8e record 1,686 route insertion call-site events, 52 0x4a80dc pairs, 340 0x49a85d route stamps, and 490 0x49a962 boundary clears. The 0x4a858f stamp coordinate order exactly matches the direct 0x49a85d trace, and the 11 far-cut insertion pairs match the 0x4a80dc squared-distance >= 25 gate. A separate non-seed-pinned direct-generation full-grid trace .artifacts/rmg_recovery/direct_generation_4a8260_entry_to_return_full_grid_esi proves the 0x4a8c15->0x4a4c8e state mutation is isolated inside 0x4a8260: same grid base 0x0188b6d4 at 0x4a8260 and 0x4a8c25, 1040 changed state cells, w28-only changes, bit26 delta +793, bit27 delta -1040. The matching helper-stream summary .artifacts/rmg_recovery/direct_generation_4a8260_stamp_clear_stream_summary.json records 200 0x49a85d calls, 793 0x49a962 calls, 793 unique 0x49a962 centers matching the bit26 delta, and 1080 raw 0x49a962 clipped-3x3 coverage cells. The 40 raw-coverage skips classify as 4 bit22-set cells and 36 bit25-clear cells; the bit22 case matches the recovered explicit exclusion, and a same-run 0x49ac8e clear trace proves the upstream bit25-clear source is 0x49abd6 clearing GeneratedCell+0x2b bit 0x02.",
    },
    {
        "address": "0x4a8c15",
        "name": "generated_cell_post_terrain_phase_driver",
        "status": "recovered_static_and_seed58_runtime_prefix",
        "calls_in_order": ["0x4a8260", "0x4a4c8e", "per-cell scan calling 0x49a962", "0x4a4913 loop over generator+0x10e4 vector", "0x4a5767", "0x4a4fc5", "0x4a79a3"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e confirms 0x4a8c15 -> 0x4a8260 -> 490 calls to 0x49aa63 -> 0x4a4c8e for the controlled seed-58 bit26 writer stream. A separate non-seed-pinned direct-generation full-grid trace summarized at .artifacts/rmg_recovery/direct_generation_4a8c15_to_4a4c8e_grid_delta_summary.json records the same phase shape from 0x4a8c15 bit26=0/bit27=1296 to 0x4a4c8e bit26=793/bit27=256, with 1040 changed state cells, bit26 delta +793, bit27 delta -1040, and unchanged owner-byte2 distribution. Focused object-vector trace .artifacts/rmg_recovery/4a79a3_object_vector_trace_summary.json records a later same-run hit at 0x4a79a3, repeated 0x4a7d2c/0x4a7d36 object-vector begin/end reads, EDX=19 at 0x4a7d99 after the shifted count, and a later 0x49eb8d handoff.",
    },
    {
        "address": "0x4a79a3",
        "name": "connection_postprocess_object_vector_consumer",
        "status": "partial_live_recovery_object_vector_payload_and_dispatch_replay_pending",
        "calls": ["0x49d2c7", "0x49b3fb"],
        "reads": [
            "generator pointer in ecx/ebx during the sampled direct-generation run",
            "generator object-record vector begin/end at +0xec8/+0xecc",
            "generator object-record vector anchor at +0xec4 for diagnostic snapshots",
            "object-record pointers exposed through EDX at 0x4a7d36 during the vector loop",
            "object record vtables and descriptor wrapper pointers from the 19 sampled entries",
            "nested source pointer through object record +0x04 -> descriptor wrapper [0]",
            "nested source field +0x1c compared to 0x57 at 0x4a7d51",
            "generated-cell +0x20 owner byte for records that pass the source-type gate",
            "generator +0xc8/+0xcc 0x1c-byte records through 0x49b3fb lookup calls",
        ],
        "writes": [
            "connection/blocker/guard post-processing state remains payload-replay pending",
            "paired +0xc8 records are marked through byte +0x0a at 0x4a7e21 and 0x4a7e25 in the sampled dispatch path",
        ],
        "runtime_trace": "Focused trace .artifacts/rmg_recovery/direct_generation_4a79a3_object_vector_trace/winedbg_interactive_trace.log summarized by .artifacts/rmg_recovery/4a79a3_object_vector_trace_summary.json records the 0x4a4c8e -> 0x4a79a3 object-vector boundary and later 0x49eb8d handoff. Follow-up payload, filter/dispatch, and endpoint traces prove the sampled payload records, one 0x4a696b return, one 0x4a7605 return, two direct 0x4a7312 endpoint commits, and paired +0xc8 processed marks at 0x4a7e21/0x4a7e25. Field summary .artifacts/rmg_recovery/connection_record_field_summary.json now names +0x09 as connection_recipe.border_guard_endpoint_stamping_enabled and verifies its source producer as 0x49f7c4 copying the template connection Border Guard column from source row +0x140. The sampled +0x09==0 path skips delegated 0x4a746b; clean seed-pinned Medium seed-10 Border Guard traces naturally reach +0x09!=0, all six 0x4a5e73 endpoint attempts fail on stale generator+0xf5c, and generation continues through 0x4a7605 -> 0x4a5e03 fallback materialization. Corpus-wide 0x4a5e73 cursor-frontier scanning records 50 live entries, zero success-path mutation hits, and no current 0x4a606b live hit dependent on a successful 0x4a5e73 return. Cursor-owner exclusion summary proves the only non-self +0xf5c writers, 0x4adb72 and 0x4add76, are owned by the unhit projection/cleanup slot chain in current one-level land evidence. Producer static summary .artifacts/rmg_recovery/connection_record_producer_static_summary.json still rules out 0x4b3c03 as the direct generator+0xc8/+0xcc semantic producer in the checked static surface; corrected runtime boundary summary proves the consumed ESI record is a separate edge/control record and that the rejected watch command was not valid evidence.",
        "ghidra_dump": "Static classification .artifacts/rmg_recovery/object_vector_surface_summary.json and focused dump .artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump/caller_004a79a3_FUN_004a79a3.txt prove 0x4a79a3 reads generator +0xec8/+0xecc, computes (end - begin) / 4, and uses the object/vector state after the 0x4a8c15 ordered phase prefix.",
        "remaining_gap": "0x4a696b and 0x4a7605 now have static callee-side surfaces, the sampled 0x4a7605 direct 0x4a7312 commit path is live-replayed, sampled +0x09==0 skip behavior is explained, and the clean seed-10 +0x09!=0 Border Guard branch/fallback behavior is recovered for the sampled sequence. For the current one-level land target mode, .artifacts/rmg_recovery/4a696b_target_mode_reachability_summary_20260610.json proves 0x4a696b direct mutation is unreached because the source/relation byte-pair gate never matches, .artifacts/rmg_recovery/4a5e73_cursor_frontier_summary_20260610.json proves 0x4a5e73's cursor-precondition frontier plus current-corpus no-success-path-hit state, .artifacts/rmg_recovery/cursor_writer_owner_exclusion_summary_20260610.json proves non-self +0xf5c writers are bound to the unhit projection/cleanup slot chain, and .artifacts/rmg_recovery/4a606b_reachability_summary_20260610.json proves 0x4a606b's static contract plus current-corpus no-live-hit state. Runtime ordered replay still needs broader relation/control linkage, any source path that seeds generator+0xf5c outside the currently excluded non-self writer chain or a source-backed endpoint-stamping exclusion for the supported one-level land scope, exact +0xc8/+0xd8 record semantic names, and full before/after GeneratedCell+0x20/+0x24/+0x28/+0x2c state before changing native RMG behavior.",
    },
    {
        "address": "0x4a696b",
        "name": "connection_dispatch_direct_generated_cell_mutator",
        "status": "target_mode_direct_mutation_unreached_pair_gate_explained_global_reachability_pending",
        "calls": ["0x49aa93", "0x49ba89", "0x40bb15", "0x4a68e0", "0x4a65a5", "0x4a5e73"],
        "reads": [
            "generator pointer in ecx/ebx",
            "stack args at +0x08/+0x0c",
            "relation vector at generator+0x10e4",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "GeneratedCell+0x20/+0x24/+0x28/+0x2c",
        ],
        "writes": [
            "filters candidate coordinates through 0x49aa93 and appends accepted coordinates through 0x40bb15",
            "when GeneratedCell+0x2c bit0 is clear, writes GeneratedCell+0x28 = (old & 0xfbffffff) | 0x08000000, clearing bit26 and setting bit27",
            "allocates/initializes a 0x1c-byte record through 0x49ba89 and continues through 0x4a68e0/0x4a65a5/0x4a5e73",
        ],
        "runtime_trace": "Prior 0x4a79a3 dispatch summary proves at least one 0x4a696b call returned from the 0x4a79a3 +0xc8 dispatch path in the sampled run. Target-mode reachability summary .artifacts/rmg_recovery/4a696b_target_mode_reachability_summary_20260610.json aggregates 150 0x4a696b entries and six complete seed-pinned Medium one-level/no-water full-grid scans across seeds 1, 2, and 10. It records zero source/relation-match hits, zero candidate append/path hits, zero direct mutation hits, and zero cells matching both expected owner/relation bytes in 5,752 scanned cells.",
        "ghidra_dump": "Static summary .artifacts/rmg_recovery/696b_7605_static_surface_summary.json checks .artifacts/rmg_recovery/ghidra_object_projection_helper_dump/caller_004a696b_FUN_004a696b.txt for the direct mutation sites at 0x4a6c13/0x4a6c1c/0x4a6c21/0x4a6c26 and the required helper calls.",
        "remaining_gap": "For the current one-level land target evidence, the direct mutation block is excluded as active native-port behavior because the source/relation byte-pair gate never matches. This is not a global proof for every H3MapEd mode/source state. Broader reachability still needs either a natural source/relation-match sample outside the current target mode or static/data proof explaining where the block can execute. Exact source/relation/+0xc8 semantic names remain pending.",
    },
    {
        "address": "0x4a7605",
        "name": "connection_dispatch_fallback_endpoint_coordinator",
        "status": "partial_static_fallback_endpoint_coordinator_surface_recovered_replay_pending",
        "calls": ["0x4a65a5", "0x49ba89", "0x4a7312", "0x40bb15", "0x4a746b", "0x4a5e03", "0x40bb26"],
        "reads": [
            "generator pointer in ecx/ebx",
            "relation/source args and control byte gates",
            "generator relation/vector state around +0x10e4, +0x308/+0x30c, +0x2e8/+0x2f8, and source/relation +0x404 coordinate vectors",
        ],
        "writes": [
            "runs four 0x4a7312 endpoint-placement attempts and initializes records through 0x49ba89",
            "records source/relation coordinates through four 0x40bb15 appends and three 0x40bb26 appends/merges",
            "calls 0x4a746b twice for endpoint state writes and 0x4a5e03 twice for downstream materialization",
            "does not show a direct GeneratedCell+0x28 write in the recovered static surface; generated-cell mutation is delegated through callees",
        ],
        "runtime_trace": "Prior 0x4a79a3 dispatch summary proves at least one fallback 0x4a7605 call returned from the 0x4a79a3 +0xc8 dispatch path in the sampled run. Follow-up live endpoint trace .artifacts/rmg_recovery/dispatch_endpoint_runtime_summary.json proves that sampled 0x4a7605 invocation executes two direct 0x4a7312 commits from return sites 0x4a76f3 and 0x4a77e7. The selected coordinates observed at 0x4a7447 are (12,11,0) with object record 0x0361edd0/source relation 0x017e0380 and (33,30,0) with object record 0x0361ecb0/source relation 0x0178e010. Follow-up branch-gate summary .artifacts/rmg_recovery/7605_branch_gate_summary.json proves why the same sample records zero 0x4a746b/0x4a5e73 endpoint-writer hits: after both direct commits, [ESI+0x09] was 0 at compare sites 0x4a774a and 0x4a783a, execution hit skip targets 0x4a7773 and 0x4a7860, and delegated call sites 0x4a7763 and 0x4a7853 were absent.",
        "ghidra_dump": "Static summary .artifacts/rmg_recovery/696b_7605_static_surface_summary.json checks .artifacts/rmg_recovery/ghidra_downstream_state_dump/caller_004a7605_FUN_004a7605.txt for four 0x4a7312 calls, two 0x4a746b calls, four 0x40bb15 appends, three 0x40bb26 appends/merges, four 0x49ba89 initializers, two 0x4a5e03 calls, and one 0x4a65a5 call.",
        "remaining_gap": "Runtime ordered replay is still pending for broader 0x4a746b/0x4a5e73 delegated endpoint-writer semantics. The clean seed-10 [ESI+0x09] != 0 branch is recovered for the sampled sequence: it attempts three endpoint pairs, all six 0x4a5e73 calls fail on stale generator+0xf5c, and execution falls back through two 0x4a7605 -> 0x4a5e03 materializations. 0x4a606b now has a recovered static contract and current-corpus no-live-hit evidence; remaining work is a natural successful 0x4a606b path or source-backed exclusion for the supported one-level land scope, 0x4a5e03/0x4a54a7 outcomes beyond sampled fallback records, generated-cell before/after state, full candidate-vector contents around 0x4a7312 appends/RNG, and exact source/relation/vector-entry semantic names.",
    },
    {
        "address": "0x49b3fb",
        "name": "generator_c8_record_lookup",
        "status": "recovered_static_contract_replay_pending",
        "reads": [
            "generator pointer in ecx",
            "lookup key at stack+0x08",
            "generator+0xc8/+0xcc record vector",
        ],
        "returns": [
            "matching generator+0xc8 slot address when the first dword of a 0x1c-byte record equals the lookup key",
            "null when no matching 0x1c-byte record exists",
        ],
        "ghidra_dump": "Called by 0x4a4c8e, 0x4a4fc5, and 0x4a79a3. Static recovery shows +0xc8/+0xcc is consumed here as 0x1c-byte records with slot[0] compared to the lookup key. Exact producer semantics and same-run replay remain pending.",
    },
    {
        "address": "0x4b3c03",
        "name": "compact_record_copy_adapter_plus9_writer_candidate",
        "status": "partial_static_ruleout_direct_generator_c8_producer",
        "reads": [
            "calls wrapped vtable slot +0x10 to fill a stack-local 12-byte record",
            "copies the returned local record first three dwords into a caller output buffer",
        ],
        "writes": [
            "writes output+0x08 from local record byte +0x08",
            "writes output+0x09 from the high byte of local record word +0x08",
        ],
        "ghidra_dump": "Full offset scan .artifacts/rmg_recovery/connection_record_offset_access_scan.txt found this as the only non-stack global +0x09 write candidate: 0x4b3c37 MOV byte ptr [EAX+0x09],CH. Focused static summary .artifacts/rmg_recovery/connection_record_producer_static_summary.json, backed by .artifacts/rmg_recovery/ghidra_connection_record_plus9_writer_dump/, shows this function is reached through data/vtable references, calls vtable slot +0x10 to fill a stack-local 12-byte record, copies local bytes to caller output +0x08/+0x09, and is not directly tied to generator+0xc8/+0xcc in the checked caller surface.",
        "remaining_gap": "0x4b3c03 remains ruled out as the direct generator+0xc8/+0xcc semantic producer in the checked static surface. The recovered +0x09 semantic producer for relation records is 0x49f7c4 copying the template connection Border Guard column; the remaining target is broader relation/control ownership and linkage for the edge/control-record block selected by 0x4a79a3, not another guess at the +0x09 meaning.",
    },
    {
        "address": "0x4a7dcd",
        "name": "connection_edge_control_record_pair_selector",
        "status": "partial_runtime_boundary_checkpoint_downstream_linkage_pending",
        "reads": [
            "edge/control record selected by the 0x4a79a3 iterator before +0x0a processed checks",
            "edge/control-record +0x08 dword whose byte +0x09 gates 0x4a7605 delegated endpoint stamping",
        ],
        "runtime_trace": "Boundary summary .artifacts/rmg_recovery/connection_record_runtime_boundary_summary.json proves the fixed UI path reaches the intended direct-generation flow, corrects the rejected +0x09 watch command, shows the consumed ESI record is separate from the 0x4a8c15 generator+0xc8 pointer-vector header, and rules out 0x4b3c4e/0x4b3d3c before the sampled fallback consumer. Relation-builder summary .artifacts/rmg_recovery/relation_builder_runtime_summary.json proves eight pre-boundary calls through 0x4a8d2c -> 0x4a93a2 -> relation vslot +0x04, resolving that vslot to 0x4a54a7 before source-field writes at 0x4a95a4/0x4a95e6.",
        "remaining_gap": "Recover the broader owner and population path for the edge/control-record block iterated by 0x4a79a3 before 0x4a7dcd/0x4a7dd0 selects a pair, and link it to the already recovered 0x49f7c4 Border Guard relation records where applicable. The next live checkpoint should snapshot the iterator records and their source owner relation records before pair selection.",
    },
    {
        "address": "0x49cf34",
        "name": "reward_guard_attach_generated_cell_pass",
        "status": "recovered_static_and_live_finalization_replay",
        "calls": [
            "0x49d7c3",
            "0x49d2c7",
            "0x49a1d8",
            "0x49aa63",
            "0x49a932",
            "0x49d2e0",
            "0x4afaea",
            "0x4e7276",
            "0x49d69d",
            "0x4ae2d0",
            "0x49d6e0",
        ],
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "object/member record pointer at stack+0x08",
            "wrapper generated-cell grid at +0x08/+0x0c/+0x10",
            "wrapper selected-member vector begin/end at +0x2c/+0x30",
            "wrapper candidate-coordinate vector begin/end at +0x3c/+0x40",
            "selected-member vtable at record+0x00, used later by 0x4aa3e9",
            "selected-member descriptor/payload pointer at record+0x04",
            "selected-member relative coordinate triple at record+0x08/+0x0c/+0x10",
            "selected-member descriptor/payload chain including bounds/anchor words at descriptor +0x2c/+0x30 and a class/terrain-like value at +0x1c",
            "direction table 0x5a2658..0x5a2698",
            "direction-policy table pointer at 0x57c648 used to choose five or eight reverse offsets from descriptor +0x1c",
            "generated-cell terrain/art word at +0x24",
            "generated-cell bit-state word at +0x28, including bit22, bit26, and bit27",
        ],
        "writes": [
            "calls 0x49d7c3 first to populate or refresh wrapper candidate coordinates",
            "iterates the existing selected-member vector and, for each member, probes direction offsets through 0x49d2c7",
            "for each selected-member probe that maps to a valid wrapper cell with bit22 clear, calls 0x49aa63(true) on that cell",
            "after each accepted selected-member probe, scans the 3x3 neighborhood around the probe result and calls 0x49a932(false) on valid cells whose bit22 is clear",
            "filters the candidate-coordinate vector in reverse; candidates whose cell bit26 is clear are erased through 0x4afaea",
            "for candidates whose cell bit26 is set, calls 0x49d2e0(wrapper, candidate coordinate, object/member descriptor) and erases the candidate when that helper rejects it",
            "returns false if the filtered candidate-coordinate vector is empty",
            "chooses one remaining candidate with 0x4e7276 modulo candidate count",
            "calls 0x49d69d(wrapper, object/member record, chosen x, chosen y) to append the member and stamp its footprint",
            "computes the chosen member relative coordinate from the selected coordinate and prior selected-member anchor fields",
            "walks the eight direction offsets around the chosen relative coordinate and calls 0x49a932(true) on valid accepted wrapper cells",
            "writes wrapper+0x4c/+0x50 to the chosen relative x/y and sets wrapper+0x48 to 1",
            "calls 0x4ae2d0 over the candidate-coordinate vector range, then refreshes bounds/candidates through 0x49d6e0 and 0x49d7c3",
            "returns true after successful candidate selection and wrapper refresh",
        ],
        "runtime_trace": "Direct-generation trace .artifacts/rmg_recovery/direct_generation_49cf34_finalization_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49cf34_finalization_trace/49cf34_finalization_summary.json, records 4 entries, 3 completed success paths, one incomplete final call from manual trace cut, 32 primary 0x49a932(true) bit27 write call-site stops at 0x49d1ed, and 21 neighbor bit27 write call-site stops at 0x49d270. In every completed sampled success path, wrapper+0x4c/+0x50 match the relative x/y locals, wrapper byte +0x48 is set to 1, the candidate-coordinate vector is non-empty before 0x4ae2d0 cleanup, empty immediately after cleanup, and rebuilt by the 0x49d6e0/0x49d7c3 refresh before success. The first completed path records relative coordinate (8,7), clears a 9-entry candidate vector to 0, and returns with 32 candidate coordinates rebuilt. Focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json proves sampled 0x540b14 projection-object constructors return through 0x4aa168 into the selected-object consumer branches. Focused consumer/stamp trace .artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/49c_consumer_stamp_summary.json proves two sampled 0x540b14 returns enter the initial 0x4aa22b path and are passed as the object argument to 0x49abd6. Projection pointer summary .artifacts/rmg_recovery/projection_pointer_trace_summary.json proves another sampled 0x540b14 pointer reaches 0x4aa168 and 0x49abd6, while cold 0x49ec51 dispatch uses handler vtable 0x00539660 with slot +0x08 target 0x0045e1a6, ruling out sampled 0x49ec51 as the 49c projection-method dispatch. Projection 0x4add76 trace summary .artifacts/rmg_recovery/projection_4add76_trace_summary.json records 552 bounded direct-generation events with three sampled 0x540b14 constructor returns, 84 0x4a54d1 and 84 0x4a54ea storage callbacks, and zero hits at 0x4add76/0x4adef7/0x4adb72/0x4ad947 or 0x49c019/0x49c0a6.",
        "ghidra_dump": "Called by 0x4aa354 and 0x4adb72. Static recovery shows a three-phase reward/guard attach pass: selected-member neighborhood mutation using object-record fields +0x04 and +0x08/+0x0c/+0x10, reverse filtering of wrapper candidate coordinates through bit26 and 0x49d2e0, then random candidate selection with 0x49d69d stamping, direction-neighborhood bit27 writes, wrapper+0x4c/+0x50/+0x48 finalization, candidate-vector range cleanup, and wrapper bounds/candidate refresh. Runtime finalization/cleanup replay is proven through the direct-generation trace. The caller-side projection-driver family around 0x49c019/0x49c0a6 is now recovered to static vtable, sampled constructor boundaries, sampled 0x540b14 selected-create return adoption, sampled initial-path stamp into 0x49abd6, 0x4a54a7 storage/queue shape, and sampled 0x49ec51 negative dispatch evidence, but exact descriptor/payload semantic names, direction-policy class values, pointer-paired projection-method dispatch, full caller-to-generator object projection, and generated-cell before/after parity remain pending.",
    },
    {
        "address": "0x49c0d3",
        "name": "projection_object_base_initializer",
        "status": "recovered_static_and_sampled_constructor_replay",
        "reads": ["projection object pointer in ecx"],
        "writes": [
            "installs base vtable 0x540b28 at object+0x00",
            "initializes object+0x1c and object+0x2c to -1",
            "initializes object+0x20, object+0x28, and object+0x30 to 0",
            "initializes object+0x24 to 6",
        ],
        "runtime_trace": "Constructor trace .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_constructor_summary.json, records 7 sampled 0x49c0d3 calls paired with projection-object constructors.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump verifies 0x49c0d3 as the base initializer used by constructors 0x49cac2, 0x49cb83, and 0x49cc22. Static verifier .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_static_summary.json proves the raw projection-vtable layout: 0x540b00 contains 0x49c019 at slot +0x08, 0x540b14 contains 0x49c0a6 at slot +0x08, and 0x540b28 contains 0x49baf5 at slot +0x08. The same verifier proves the candidate descriptor create slots 0x540c60/0x540c70/0x540c80/0x540ca0 point to 0x49cac2/0x49cb83/0x49cc22/0x49cdb1 respectively.",
    },
    {
        "address": "0x49cac2",
        "name": "projection_object_constructor_a",
        "status": "recovered_static_and_sampled_constructor_replay",
        "calls": ["0x49c0d3", "0x4a9e40"],
        "writes": [
            "allocates/initializes the projection object through 0x49c0d3",
            "stores constructor arguments into object+0x1c/+0x20/+0x24",
            "copies source fields through the object+0x20 pointer into object+0x2c/+0x30",
            "installs final vtable 0x540b14",
        ],
        "runtime_trace": "Constructor trace records 2 sampled 0x49cac2 entries, each immediately paired with 0x49c0d3 returning to 0x49caf0. Focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json records one 0x49cac2 pre-return at 0x49cb52 followed immediately by 0x4aa168; the same EAX pointer retains vtable 0x540b14 and continues to 0x4aa2fd. Separate focused consumer/stamp trace .artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/49c_consumer_stamp_summary.json records one 0x49cac2/0x49cb52 sample returning through 0x4aa168 into 0x4aa22b and then 0x49abd6 with the same object pointer as the stamp argument.",
        "ghidra_dump": "Ghidra caller dump shows 0x49cac2 calls 0x49c0d3 at 0x49caeb, calls 0x4a9e40 at 0x49cb01, and installs final vtable 0x540b14.",
    },
    {
        "address": "0x49cb83",
        "name": "projection_object_constructor_b",
        "status": "recovered_static_and_sampled_constructor_replay",
        "calls": ["0x49c0d3", "0x4a9e40"],
        "writes": [
            "allocates/initializes the projection object through 0x49c0d3",
            "stores constructor arguments into object+0x1c/+0x20/+0x24",
            "copies source +0x14 into object+0x20 after the secondary object-record build",
            "installs final vtable 0x540b14",
        ],
        "runtime_trace": "Constructor trace records 4 sampled 0x49cb83 entries, each immediately paired with 0x49c0d3 returning to 0x49cbb3. Selected-dispatch trace .artifacts/rmg_recovery/direct_generation_49c_selected_create_dispatch_trace/49c_selected_dispatch_summary.json records one 0x4aa166 selected-create event with candidate vtable 0x540c70 immediately followed by 0x49cb83. Focused consumer/stamp trace .artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/49c_consumer_stamp_summary.json records one 0x49cb83/0x49cc12 sample returning through 0x4aa168 into 0x4aa22b and then 0x49abd6 with the same object pointer as the stamp argument.",
        "ghidra_dump": "Ghidra caller dump shows 0x49cb83 calls 0x49c0d3 at 0x49cbae, calls 0x4a9e40 at 0x49cbc6, and installs final vtable 0x540b14.",
    },
    {
        "address": "0x49cc22",
        "name": "projection_object_constructor_c",
        "status": "recovered_static_and_sampled_constructor_replay",
        "calls": ["0x49c0d3", "0x4a9e40"],
        "writes": [
            "allocates/initializes the projection object through 0x49c0d3",
            "stores constructor arguments into object+0x1c/+0x20/+0x24",
            "sets object+0x24 to 6 and copies source +0x14 into object+0x28 after the secondary object-record build",
            "installs final vtable 0x540b14",
        ],
        "runtime_trace": "Constructor trace records 1 sampled 0x49cc22 entry paired with 0x49c0d3 returning to 0x49cc50. Selected-dispatch trace .artifacts/rmg_recovery/direct_generation_49c_selected_create_dispatch_trace/49c_selected_dispatch_summary.json records four 0x4aa166 selected-create events with candidate vtable 0x540c80 immediately followed by 0x49cc22. Focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json records two 0x49cc22 pre-returns at 0x49ccb0 followed immediately by 0x4aa168; both keep the same EAX pointer with vtable 0x540b14 and continue to 0x4aa22b.",
        "ghidra_dump": "Ghidra caller dump shows 0x49cc22 calls 0x49c0d3 at 0x49cc4b, calls 0x4a9e40 at 0x49cc61, and installs final vtable 0x540b14.",
    },
    {
        "address": "0x49cdb1",
        "name": "projection_object_adjacent_constructor",
        "status": "recovered_static_candidate_create_callback",
        "calls": ["0x5044b1", "0x49ba89"],
        "reads": [
            "candidate descriptor/context pointer in ecx",
            "stack arguments at +0x08/+0x0c used by 0x49ba89 and object+0x1c",
            "descriptor/context +0x0c copied into object+0x20",
        ],
        "writes": [
            "allocates a 0x24-byte projection object through 0x5044b1",
            "initializes the copied object record through 0x49ba89",
            "stores object+0x20 from descriptor/context +0x0c",
            "stores object+0x1c from stack +0x0c",
            "installs adjacent projection vtable 0x540b00",
        ],
        "runtime_trace": "The 0x49cdb1 constructor has static candidate-create recovery only in this checkpoint; focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json instrumented 0x49cdb1 and 0x49cdf4 but recorded zero hits in this bounded sample. Ordered runtime dispatch through 0x540b00+0x08 remains pending.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_object_projection_helper_dump/caller_0049cdb1_FUN_0049cdb1.txt plus static verifier .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_static_summary.json prove candidate descriptor vtable 0x540ca0 slot +0x00 targets 0x49cdb1 and that 0x49cdb1 installs projection vtable 0x540b00.",
    },
    {
        "address": "0x49be93",
        "name": "projection_object_writer_helper_a",
        "status": "recovered_static_writer_surface_runtime_nohit",
        "calls": ["0x49baf8"],
        "reads": [
            "writer/context pointer from stack+0x08 into ESI",
            "projection object pointer from ECX into EDI",
            "projection object fields including +0x1c, +0x3c, +0x40, +0x48, +0x4c",
            "writer vtable from [ESI] before repeated slot +0x08 dispatch",
        ],
        "runtime_trace": "Focused writer-surface summary .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_writer_surface_summary.json verifies the constructor/generation trace was instrumented for 0x49be93 and recorded zero hits in that sampled generation path.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump/target_0049be93_FUN_0049be93.txt shows ESI loaded from stack+0x08, EDI loaded from ECX, a common 0x49baf8 preamble, and 16 repeated CALL [EAX+0x08] dispatches with ECX reset to ESI. The shape is writer/serializer-like and does not dispatch projection-object vtables 0x540b00 or 0x540b14 in the sampled generation trace.",
    },
    {
        "address": "0x49c273",
        "name": "projection_object_writer_helper_b",
        "status": "recovered_static_writer_surface_runtime_nohit",
        "calls": ["0x49baf8", "0x4e71c0"],
        "reads": [
            "writer/context pointer from stack+0x08 into ESI",
            "projection object pointer from ECX into EDI",
            "projection object fields including +0x20, +0x24, +0x28",
            "writer vtable from [ESI] before repeated slot +0x08 dispatch",
        ],
        "runtime_trace": "Focused writer-surface summary .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_writer_surface_summary.json verifies the constructor/generation trace was instrumented for 0x49c273 and recorded zero hits in that sampled generation path.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump/target_0049c273_FUN_0049c273.txt shows ESI loaded from stack+0x08, EDI loaded from ECX, a common 0x49baf8 preamble, and 17 repeated CALL [EAX+0x08] dispatches with ECX reset to ESI. The shape is writer/serializer-like and does not dispatch projection-object vtables 0x540b00 or 0x540b14 in the sampled generation trace.",
    },
    {
        "address": "0x49c019",
        "name": "projection_object_attachment_vtable_method",
        "status": "recovered_static_vtable_method_runtime_nohit",
        "calls": ["0x4adb72", "0x4adef7"],
        "reads": [
            "projection object fields initialized by the 0x49c0d3 constructor family",
            "adjacent vtable slot 0x540b00+0x08 referenced from raw data address 0x540b08",
        ],
        "runtime_trace": "Separate wrapper-execution no-hit trace .artifacts/rmg_recovery/direct_generation_49c019_49c0a6_projection_driver_hit_trace/winedbg_recovery_trace_ledger.json completed a 36x36 generation path with zero hits at 0x49c019, 0x49c0a6, 0x4adb72, 0x4ad947, 0x4ad7f7, and 0x4adef7. Writer-surface summary .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_writer_surface_summary.json further verifies nearby helpers 0x49be93/0x49c273 are writer/serializer-like slot +0x08 dispatch surfaces with zero sampled generation hits. Projection consumer surface summary .artifacts/rmg_recovery/projection_consumer_surface_summary.json rules out the sampled 0x4aa3e9 final-wrapper slot +0x08 surface, sampled 0x49eb8d/0x49ec51 optional invalid-cell dispatch, and a bounded 0x4add76/0x4adef7 cleanup-driver direct-generation sample, leaving the still-unhit 0x540b00/0x540b14 method dispatch consumer downstream of 0x4a54a7 storage unrecovered. Focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json proves sampled 0x540b14 objects return through selected-create; this 0x540b00 method still has no ordered runtime hit.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump proves 0x49c019 is the direct caller of 0x4adb72 and 0x4adef7. Static verifier .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_static_summary.json links it to raw vtable slot 0x540b00+0x08, not the constructor-installed 0x540b14 table. Ghidra references show incoming references to 0x49c019 only from vtable data 0x540b08 in this dump. Ordered execution replay remains pending.",
    },
    {
        "address": "0x49c0a6",
        "name": "projection_object_relation_vtable_method",
        "status": "recovered_static_vtable_method_runtime_nohit",
        "calls": ["0x4ad947"],
        "reads": [
            "projection object fields initialized by the 0x49c0d3 constructor family",
            "constructor-installed vtable slot 0x540b14+0x08 referenced from raw data address 0x540b1c",
        ],
        "runtime_trace": "Separate wrapper-execution no-hit trace .artifacts/rmg_recovery/direct_generation_49c019_49c0a6_projection_driver_hit_trace/winedbg_recovery_trace_ledger.json completed a 36x36 generation path with zero hits at 0x49c019, 0x49c0a6, 0x4adb72, 0x4ad947, 0x4ad7f7, and 0x4adef7. Writer-surface summary .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_writer_surface_summary.json further verifies nearby helpers 0x49be93/0x49c273 are writer/serializer-like slot +0x08 dispatch surfaces with zero sampled generation hits. Projection consumer surface summary .artifacts/rmg_recovery/projection_consumer_surface_summary.json rules out the sampled 0x4aa3e9 final-wrapper slot +0x08 surface, sampled 0x49eb8d/0x49ec51 optional invalid-cell dispatch, and a bounded 0x4add76/0x4adef7 cleanup-driver direct-generation sample, leaving the still-unhit 0x540b00/0x540b14 method dispatch consumer downstream of 0x4a54a7 storage unrecovered. Focused constructor-return trace .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json proves three sampled 0x540b14 constructor returns flow through 0x4aa168 while preserving the same EAX object pointer; later ordered slot +0x08 dispatch into 0x49c0a6 remains pending.",
        "ghidra_dump": "Ghidra dump .artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump proves 0x49c0a6 is the direct caller of 0x4ad947. Static verifier .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_static_summary.json links it to constructor-installed vtable slot 0x540b14+0x08. Ghidra references show incoming references to 0x49c0a6 only from vtable data 0x540b1c in this dump. Ordered execution replay remains pending.",
    },
    {
        "address": "0x4adb72",
        "name": "reward_guard_vector_attachment_attempt",
        "status": "recovered_static_contract_constructor_boundary_replay_pending",
        "calls": ["0x49ce04", "0x49ba89", "0x4aa1db", "0x49cf34", "0x49d6e0", "0x49d7c3", "0x49cefb", "0x4ad7f7", "0x49cebd", "0x4aad8e"],
        "reads": [
            "generator pointer in ecx",
            "input object/member record at stack+0x08",
            "input object/member descriptor through record+0x04",
            "descriptor-side id at descriptor+0x20",
            "generator+0xc8/+0xcc entry vector searched by dereferenced record+0x20",
            "input record relative coordinate triple at +0x08/+0x0c/+0x10",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "source generated-cell +0x20 byte2 owner/relation id",
            "relation pointer from generator+0x10e4 indexed by source owner/relation id",
            "byte-state vector at generator+0x1104/+0x1108 and cursor at +0xf5c",
        ],
        "writes": [
            "returns false immediately when no generator+0xc8 entry has dereferenced record+0x20 matching the descriptor-side id",
            "constructs a stack-local reward/guard wrapper through 0x49ce04",
            "allocates a 0x1c-byte object record from the matched +0xc8 entry through 0x49ba89",
            "temporarily marks generator+0x1104[descriptor_id] = 1",
            "resets generator+0xf5c to zero and advances it over marked byte-state entries",
            "runs 0x4aa1db and then 0x49cf34 for the wrapper/object attempt",
            "on success refreshes wrapper bounds/candidates through 0x49d6e0 and 0x49d7c3, finalizes through 0x49cefb and 0x4ad7f7, and returns true",
            "on failure destroys the allocated object, tears down the wrapper, clears generator+0x1104[descriptor_id], resets/advances +0xf5c again, and returns false",
        ],
        "ghidra_dump": "Instruction recovery shows this is the reward/guard attachment attempt wrapper around 0x49cf34 and a temporary consumer/mutator of +0xc8, +0x1104, and +0xf5c. Ghidra dump .artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump proves direct vtable caller 0x49c019 and downstream 0x4ad7f7. Constructor summary .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_constructor_summary.json proves sampled constructors pair with 0x49c0d3; constructor-return summary .artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/49c_constructor_return_summary.json proves sampled 0x540b14 constructor objects are returned/adopted by 0x4a9f1c. Separate wrapper no-hit ledger .artifacts/rmg_recovery/direct_generation_49c019_49c0a6_projection_driver_hit_trace/winedbg_recovery_trace_ledger.json generated a 36x36 map with 0 hits at 0x49c019/0x49c0a6/0x4adb72/0x4ad947/0x4ad7f7/0x4adef7. Runtime ordered replay for 0x4adb72 remains pending.",
    },
    {
        "address": "0x499f60",
        "name": "reward_guard_wrapper_grid_constructor",
        "status": "recovered_static_contract",
        "reads": ["wrapper pointer in ecx", "width arg", "height arg", "level-count arg"],
        "writes": [
            "wrapper vtable 0x540a14 at +0x00",
            "wrapper+0x0c width, +0x10 height, +0x14 level count",
            "allocates width*height*level_count generated-cell records with stride 0x30 plus a leading count dword",
            "constructs generated-cell records through 0x499e65",
            "stores the generated-cell buffer pointer at wrapper+0x08",
        ],
        "ghidra_dump": "Used by 0x49ce04 with arguments 0x10, 0x10, 1 to construct the reward/guard wrapper grid.",
    },
    {
        "address": "0x49ce04",
        "name": "reward_guard_wrapper_constructor",
        "status": "recovered_static_contract",
        "calls": ["0x499f60", "0x49ce64"],
        "writes": [
            "calls 0x499f60(wrapper, 0x10, 0x10, 1)",
            "initializes selected-member vector anchor at +0x28 with begin/end/capacity at +0x2c/+0x30/+0x34",
            "initializes candidate-coordinate vector anchor at +0x38 with begin/end/capacity at +0x3c/+0x40/+0x44",
            "clears wrapper flags +0x48 and +0x60",
            "calls 0x49ce64 to reset vectors and wrapper generated-cell state",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_reward_guard_wrapper_helper_dump recovers the constructor shell.",
    },
    {
        "address": "0x49ce64",
        "name": "reward_guard_wrapper_reset",
        "status": "recovered_static_contract",
        "calls": ["0x42bde9", "0x4ae2d0", "0x49a072", "0x49acf6"],
        "writes": [
            "clears selected-member vector range +0x2c..+0x30 through 0x42bde9",
            "clears candidate-coordinate vector range +0x3c..+0x40 through 0x4ae2d0",
            "calls 0x49a072 to reset the wrapper generated-cell grid",
            "clears wrapper flags +0x48 and +0x60",
            "walks every wrapper generated cell and calls 0x49acf6(cell, 0, 0, 0, 0)",
        ],
        "ghidra_dump": "Called by 0x49ce04, 0x49cebd, and 0x4aa354. Static reset contract is recovered; runtime phase ordering remains replay-pending.",
    },
    {
        "address": "0x49cebd",
        "name": "reward_guard_wrapper_selected_member_destroy_and_reset",
        "status": "recovered_static_contract",
        "calls": ["selected_member_vtable+0x04", "selected_member_vtable+0x00", "0x49ce64"],
        "reads": ["selected-member vector begin/end at wrapper+0x2c/+0x30"],
        "writes": [
            "iterates selected-member pointers",
            "calls each selected member vtable slot +0x04",
            "destroys non-null selected members through vtable slot +0x00 with argument true",
            "calls 0x49ce64 after the selected-member sweep",
        ],
        "ghidra_dump": "Focused dump recovers the selected-member cleanup and reset path.",
    },
    {
        "address": "0x49cefb",
        "name": "reward_guard_wrapper_candidate_cell_marker",
        "status": "recovered_static_contract",
        "reads": ["candidate-coordinate vector begin/end at wrapper+0x3c/+0x40", "wrapper generated-cell buffer/width at +0x08/+0x0c"],
        "writes": [
            "sets wrapper byte +0x60 to 1",
            "iterates 8-byte candidate coordinate records",
            "maps each candidate x/y into the wrapper generated-cell grid",
            "sets byte cell+0x2a |= 0x80 for each candidate coordinate",
        ],
        "ghidra_dump": "Called before final reward/guard projection from 0x4adb72, 0x4ad947, and 0x4aa354.",
    },
    {
        "address": "0x4aad8e",
        "name": "reward_guard_wrapper_destructor",
        "status": "recovered_static_contract",
        "calls": ["0x42c92d", "0x49a030"],
        "writes": [
            "destroys candidate-coordinate vector at +0x38 through 0x42c92d",
            "destroys selected-member vector at +0x28 through 0x42c92d",
            "calls 0x49a030 to release wrapper generated-cell grid storage",
        ],
        "ghidra_dump": "Focused dump recovers the reward/guard wrapper teardown shell.",
    },
    {
        "address": "0x4aa1db",
        "name": "reward_guard_wrapper_object_seed_helper",
        "status": "recovered_static_and_sampled_selected_lifetime_replay",
        "calls": ["0x4a9f1c", "0x40bb26", "0x49abd6", "0x49d471", "0x49d6e0"],
        "reads": [
            "generator/context pointer in ecx",
            "selector/object bucket arg at stack+0x08",
            "reward/guard wrapper pointer at stack+0x0c",
            "budget/value args at stack+0x10/+0x14",
            "wrapper dimensions at +0x0c/+0x10",
            "selected object descriptor dimensions at descriptor +0x34/+0x38",
        ],
        "writes": [
            "tries initial object selection through 0x4a9f1c up to three times",
            "appends the selected object record to wrapper+0x28 through 0x40bb26",
            "computes a centered wrapper coordinate from selected descriptor dimensions and wrapper dimensions",
            "stamps the selected object through 0x49abd6",
            "uses remaining budget/value space to attempt secondary object selections through 0x4a9f1c",
            "validates secondary records through 0x49d471 and destroys rejected records through their vtable",
            "calls 0x49d6e0 before returning the consumed/current value",
        ],
        "runtime_trace": "Focused selected-lifetime trace .artifacts/rmg_recovery/direct_generation_49c_selected_lifetime_trace/winedbg_interactive_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49c_selected_lifetime_trace/49c_selected_lifetime_summary.json, records 421 breakpoint events: 62 0x4a9f1c selected-create returns through 0x4aa168, 29 initial-consumer returns at 0x4aa22b, 33 secondary-consumer returns at 0x4aa2fd, 32 secondary validator entries at 0x49d471, 21 validator stamp calls from 0x49d636 into 0x49abd6, 11 failed-secondary cleanup pairs through returned-object slot +0x04 then destructor slot +0x00, and 127 total 0x49abd6 stamp-helper hits. The sampled selected-object lifetime path did not hit 0x49c019 or 0x49c0a6 and returned no objects with vtables 0x540b00/0x540b14. Focused consumer/stamp trace .artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/49c_consumer_stamp_summary.json records two 0x540b14 projection-object returns, both through 0x4aa22b/0x4aa23d and 0x4aa27e into 0x49abd6, with the 0x49abd6 object argument matching the selected projection object pointer.",
        "ghidra_dump": "Focused dump recovers the selection/stamp/retry shell. The live selected-lifetime trace proves sampled 0x4a9f1c returns are consumed by the initial and secondary 0x4aa1db paths, with secondary acceptance validated by 0x49d471 and stamped through 0x49abd6. The 49c consumer/stamp trace proves sampled projection-object returns can take the initial append/stamp branch. Exact budget argument names, full same-run object sequence, and the separate projection-object vtable dispatch path remain replay-pending.",
    },
    {
        "address": "0x4a9f1c",
        "name": "reward_guard_value_bounded_object_selector",
        "status": "recovered_static_and_sampled_selected_lifetime_replay",
        "calls": ["0x4a9e40", "0x49a6f9", "0x40bb26", "0x4e7276", "0x42bde9", "0x42c92d"],
        "reads": [
            "generator/context pointer in ecx",
            "selector/bucket pointer at stack+0x08",
            "value bounds at stack+0x0c/+0x10",
            "selected-value output pointer at stack+0x14",
            "policy bytes/flags across stack+0x18/+0x1c/+0x20",
            "additional copied coordinate/scalar arguments in the remaining stack area consumed by ret 0x28",
            "generator relation/bucket vector at generator+0x10f4/+0x10f8",
            "candidate type/id at candidate+0x04",
            "candidate weight/value field at candidate+0x10",
            "generator per-type count table at generator+0x1110",
            "global per-type limit table at 0x5a26e4",
            "selector-local per-type limit table at selector+0x44",
            "selector-local global limit table at 0x5a2a8c",
            "policy table at 0x57c648 indexed by candidate type*0x10",
        ],
        "writes": [
            "builds local accepted-candidate and selected-descriptor dword vectors",
            "optionally clears those local vectors when the selected value band changes",
            "appends accepted candidate records and selected descriptors through 0x40bb26",
            "accumulates accepted candidate weights from candidate+0x10",
            "writes the chosen candidate value through the stack+0x14 output pointer",
        ],
        "returns": [
            "selected object/member record pointer after weighted final selection",
            "null when no accepted candidate survives filtering",
        ],
        "callers": ["0x4aa1db", "0x4adef7"],
        "runtime_trace": "Focused selected-lifetime trace .artifacts/rmg_recovery/direct_generation_49c_selected_lifetime_trace/winedbg_interactive_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49c_selected_lifetime_trace/49c_selected_lifetime_summary.json, records 62 selected-create returns at 0x4aa168. The selected-create callbacks sampled at 0x4aa166 were 0x49c553 x30, 0x49c58a x3, 0x49c6e2 x1, 0x49c806 x1, 0x49c8b0 x18, 0x49c9e3 x4, and 0x49ccec x5. Returned object vtables at 0x4aa168 were 0x540a74 x30, 0x540ab0 x1, 0x540ac4 x3, 0x540ad8 x18, 0x540aec x1, 0x540b64 x4, and 0x540b78 x5; no sampled return used 0x540b00 or 0x540b14.",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4a9f1c_reward_guard_object_selector_dump recovers this as the higher-level reward/guard object selector used before 0x4aa1db stamping. It scans generator+0x10f4 buckets, enforces per-type limits, delegates descriptor choice to 0x4a9e40, optionally gates placement through 0x49a6f9, builds accepted vectors, performs weighted 0x4e7276 selection, writes the selected value, and returns the selected object record. The sampled selected-object lifetime through 0x4aa1db/0x49d471/0x49abd6 is now proven; exact stack-argument names, full candidate vtable contracts, and the separate 0x540b00/0x540b14 projection-object method-dispatch consumer remain pending.",
    },
    {
        "address": "0x4aa195",
        "name": "object_descriptor_primary_secondary_mask_extent_count",
        "status": "recovered_static_ghidra",
        "calls": ["0x41e951", "0x4268eb"],
        "reads": [
            "descriptor pointer at stack+0x04",
            "descriptor width at +0x34",
            "descriptor height at +0x38",
            "primary descriptor bitset at descriptor+0x04 through 0x41e951",
            "secondary descriptor bitset at descriptor+0x0c through 0x4268eb",
        ],
        "returns": [
            "count of footprint cells where the primary mask is clear",
            "plus cells where both primary and secondary masks are set",
        ],
        "callers": ["0x4a9f1c"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4aa195_object_mask_extent_helper_dump recovers the exact width/height loop and mask-count rule. 0x4a9f1c uses the returned count as a divisor in its accepted-candidate value-band check.",
    },
    {
        "address": "0x4add76",
        "name": "object_record_uncommit_and_cell_reference_cleanup",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4cce95", "0x41e951", "0x4268eb", "0x499ee8"],
        "reads": [
            "generator/context pointer in ecx",
            "object record pointer at stack+0x08",
            "record coordinate triple at record+0x08/+0x0c/+0x10",
            "descriptor pointer at record+0x04",
            "descriptor type/class at +0x1c",
            "descriptor id at +0x20",
            "descriptor offsets at +0x2c/+0x30",
            "descriptor dimensions at +0x34/+0x38",
            "generator object-record vector at generator+0xec8/+0xecc with anchor at +0xec4",
            "generator generated-cell buffer/dimensions at +0x14/+0x18/+0x1c",
            "generator relation pointer vector at +0x10e4",
            "generator byte-state vector at +0x1104/+0x1108 and cursor at +0xf5c",
        ],
        "writes": [
            "erases the object record from the generator object-record vector through 0x4cce95",
            "decrements generator+0x1110[descriptor_type]",
            "decrements relation+0x44+descriptor_type*4 when the source generated cell owner byte is nonnegative",
            "for descriptor type/class 9, clears generator+0x1104[descriptor_id] and advances generator+0xf5c over marked byte-state entries",
            "walks the descriptor footprint and calls 0x499ee8(cell, record) for cells where the primary mask is clear or the secondary mask is set",
        ],
        "callers": ["0x4adef7"],
        "runtime_trace": "Projection 0x4add76 trace summary .artifacts/rmg_recovery/projection_4add76_trace_summary.json records 552 bounded direct-generation events with active constructor/stamp/storage evidence but zero hits at 0x4add76 or its immediate 0x4adef7 caller. This is negative runtime evidence for the sampled direct-generation span, not proof the static cleanup helper is unused globally.",
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4aa195_object_mask_extent_helper_dump/caller_004add76_FUN_004add76.txt recovers the object uncommit/cleanup shell used before 0x4adef7 asks 0x4a9f1c for a replacement. Exact vector erase edge behavior, descriptor type names, and same-run ordered replay remain pending.",
    },
    {
        "address": "0x4adef7",
        "name": "direct_relation_cell_object_reselection_and_commit",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4add76", "0x4a9f1c", "generator_vtable+0x04"],
        "reads": [
            "generator/context pointer in ecx",
            "existing object record pointer at stack+0x08",
            "value/budget scalar at stack+0x0c",
            "object record coordinate triple at record+0x08/+0x0c/+0x10",
            "generator generated-cell buffer/dimensions at +0x14/+0x18/+0x1c",
            "generated-cell owner/relation byte from cell+0x20",
            "generator relation pointer vector at +0x10e4",
        ],
        "writes": [
            "calls 0x4add76 to uncommit the existing object record",
            "derives the relation pointer for the copied coordinate",
            "calls 0x4a9f1c with the relation pointer and value bounds derived from stack+0x0c",
            "when 0x4a9f1c returns a replacement record, calls generator/context vtable slot +0x04 with the copied coordinate triple and replacement record",
        ],
        "callers": ["0x4ad947"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4a9f1c_reward_guard_object_selector_dump/caller_004adef7_FUN_004adef7.txt recovers this as the non-wrapper caller of 0x4a9f1c. It consumes a replacement record by passing it as an argument to generator/context vtable slot +0x04, not by dispatching the replacement object's slot +0x08. Exact value scalar meaning, stack flag names, and vtable callback contract remain replay-pending.",
    },
    {
        "address": "0x4ad7f7",
        "name": "reward_guard_relation_ordering_projection_driver",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4ad6a8", "0x4e7276", "0x4ccecb", "0x4aa9b7", "0x42c92d"],
        "reads": [
            "generator pointer in ecx",
            "wrapper arg at stack+0x08",
            "source relation pointer arg at stack+0x0c",
            "relation pointer vector at generator+0x10e4/+0x10e8",
            "relation leading descriptor pointer and descriptor+0x04",
            "relation type/class at +0x0c",
            "relation priority/value at +0x40",
        ],
        "writes": [
            "calls 0x4ad6a8 first",
            "randomizes each relation +0x40 priority with 0x4e7276 % 10",
            "when old +0x40 is 1, writes 1000 + random_mod_10",
            "otherwise writes old_value * 10 + random_mod_10",
            "builds a sorted local relation pointer vector through 0x4ccecb",
            "skips the source relation, relations whose leading descriptor +0x04 is 3, relations with +0x40 > 2000, and relation type/class 8",
            "calls 0x4aa9b7(generator, wrapper, relation, true) for sorted relations until one succeeds",
            "destroys the local relation vector through 0x42c92d",
        ],
        "returns": ["true after the first successful 0x4aa9b7 projection", "false if no sorted relation succeeds"],
        "ghidra_dump": "Focused dump recovers reward/guard relation ordering and projection dispatch. Static direct callers are 0x4adb72 and 0x4ad947; their projection-object vtable wrappers 0x49c019 and 0x49c0a6 are now recovered to static vtable and sampled constructor boundaries through .artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump and .artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_constructor_summary.json. The completed 36x36 wrapper-execution trace hit none of 0x49c019/0x49c0a6/0x4adb72/0x4ad947/0x4ad7f7/0x4adef7, so runtime ordered replay for this relation projection path remains pending.",
    },
    {
        "address": "0x4ad6a8",
        "name": "reward_guard_relation_distance_priority_prepass",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x42d8d8", "0x4cce95", "0x4ccecb", "0x42c92d"],
        "reads": [
            "generator pointer in ecx",
            "source relation pointer at stack+0x08",
            "relation pointer vector at generator+0x10e4/+0x10e8",
            "relation leading descriptor pointer at relation+0x00",
            "relation priority/value at +0x40",
            "leading descriptor 0x1c-byte records at +0xc8/+0xcc",
        ],
        "writes": [
            "initializes every relation +0x40 priority/value to 0x4e20",
            "sets source relation +0x40 to 0",
            "appends the source relation to a stack-local work vector through 0x42d8d8",
            "pops/erases work-vector entries through 0x4cce95",
            "for each current relation, scans its leading descriptor +0xc8/+0xcc records with stride 0x1c",
            "reads each record's first pointed dword as a relation index into generator+0x10e4",
            "lowers target relation +0x40 when the existing target priority is greater than current +0x40 + 1",
            "inserts lowered target relations back into the work vector through 0x4ccecb using relation +0x40 ordering",
            "destroys the local work vector through 0x42c92d",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_reward_guard_projection_callee_dump recovers the relation-distance priority propagation prepass called by 0x4ad7f7. Descriptor +0xc8 producer semantics and same-run replay remain pending.",
    },
    {
        "address": "0x4aa9b7",
        "name": "reward_guard_coordinate_scan_and_commit",
        "status": "recovered_static_and_sampled_ordered_commit_replay",
        "calls": ["0x4aa603", "0x4ae52a", "0x4ae1fd", "0x4e7276", "0x4aa3e9", "0x42c92d"],
        "reads": [
            "generator pointer in ecx",
            "reward/guard wrapper pointer at stack+0x08",
            "relation pointer at stack+0x0c",
            "minimum low-word score/value at stack+0x10",
            "boolean policy byte at stack+0x13",
            "relation leading descriptor through relation+0x00",
            "relation coordinate/range fields at +0x10..+0x1c",
            "relation scan bounds at +0x20..+0x2c",
            "wrapper bounds at +0x18..+0x24",
            "generator generated-cell buffer/width/height/depth at +0x14/+0x18/+0x1c/+0x20",
            "generated-cell owner/score word at +0x20",
        ],
        "writes": [
            "builds the overlap scan rectangle between relation bounds and wrapper bounds",
            "scans generator cells in that rectangle",
            "keeps candidates whose generated-cell +0x20 byte2 matches relation leading descriptor +0x00",
            "requires the generated-cell +0x20 low word to be at least the current threshold",
            "calls 0x4aa603(generator, wrapper, candidate coordinate, relation) for each score-passing candidate",
            "when an accepted candidate raises the low-word threshold, clears the previous local coordinate vector through 0x4ae52a",
            "appends accepted 12-byte coordinates at the current threshold through 0x4ae1fd",
            "selects one accepted coordinate with 0x4e7276 % candidate_count",
            "calls 0x4aa3e9(generator, wrapper, selected coordinate) to project the selected wrapper into the generator",
            "destroys the local coordinate vector through 0x42c92d",
        ],
        "returns": ["true after selecting and projecting a coordinate", "false when the accepted coordinate vector is empty"],
        "runtime_trace": "Focused ordered commit trace .artifacts/rmg_recovery/direct_generation_4aa9b7_ordered_commit_trace/winedbg_interactive_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_4aa9b7_ordered_commit_trace/4aa9b7_ordered_commit_summary.json, records 403 parsed events over 85 completed 0x4aa9b7 calls: 79 false returns, 6 successful commits into 0x4aa3e9, 9 accepted-candidate stops, 4 threshold resets, and 9 candidate appends. For every successful sampled commit, the selected vector element pointer equals local candidate-vector begin plus selected index times 12, the copied selected coordinate matches the stack coordinate at the 0x4aa3e9 call site, the 0x4aa3e9 entry receives the same wrapper pointer and coordinate triple, and false returns do not enter the 0x4aa3e9 commit path.",
        "ghidra_dump": "Focused dump recovers the coordinate scan, best-score candidate vector, random selection, and 0x4aa3e9 commit call. Sampled runtime replay now proves the ordered local-vector-to-0x4aa3e9 handoff. Caller-side 0x4ad7f7/0x4adb72 wrapper-constructor class is now recovered to vtable construction/no-hit boundary, but ordered execution replay for the relation/object projection path remains pending.",
    },
    {
        "address": "0x4aa603",
        "name": "reward_guard_coordinate_feasibility_filter",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a6f9", "0x49d2c7", "0x49a1d8", "0x49d65c", "0x49a09c"],
        "reads": [
            "generator pointer in ecx",
            "reward/guard wrapper pointer at stack+0x08",
            "candidate x/y/level at stack+0x0c/+0x10/+0x14",
            "relation pointer at stack+0x18",
            "wrapper selected-member vector at +0x2c/+0x30",
            "wrapper selected-member attached flag and relative coordinates at +0x48/+0x4c/+0x50",
            "wrapper candidate-coordinate vector anchor at +0x38",
            "member descriptor pointer at member+0x04",
            "member relative coordinate triple at +0x08/+0x0c/+0x10",
            "last selected member descriptor bounds +0x2c/+0x30 and type/class +0x1c",
            "policy table 0x57c648 and direction offsets 0x5a2658",
            "generator generated-cell grid through +0x14/+0x18/+0x1c",
            "wrapper generated-cell grid through +0x08/+0x0c",
            "generated-cell terrain/art word +0x24 and bit-state +0x28",
        ],
        "writes": [
            "tests every selected member footprint at the candidate coordinate through 0x49a6f9",
            "when wrapper +0x48 is set, probes from wrapper +0x4c/+0x50 plus the candidate coordinate through 0x49d2c7",
            "rejects the probe neighborhood when a bit22 object resolves to descriptor type/class 0x36",
            "uses last selected member descriptor policy to scan either the reduced or full direction-offset set",
            "requires at least one wrapper source direction cell with bit27 set, valid state, bit22 clear, and bit23 set",
            "requires the mapped generator destination cell to match the terrain-8 policy implied by relation+0x0c == 8, be valid, bit22 clear, and bit27 clear",
            "calls 0x49a09c(generator+0x0c, wrapper+0x38, candidate coordinate, require_unattached_flag, relation, true)",
            "scans the wrapper/generator overlap rectangle after 0x49a09c and rejects candidates that would cover an already bit26-marked generator destination from a wrapper cell whose bit27 is clear",
        ],
        "returns": ["true only when all footprint, probe, directional, rectangle, and overlap gates pass", "false on the first rejected gate"],
        "ghidra_dump": "Focused dump recovers the candidate feasibility filter underneath 0x4aa9b7. Runtime ordered replay remains pending.",
    },
    {
        "address": "0x49d65c",
        "name": "reward_guard_selected_member_policy_table_check",
        "status": "recovered_static_contract_replay_pending",
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "wrapper selected-member vector at +0x2c/+0x30",
            "selected member descriptor through member+0x04",
            "descriptor type/class at descriptor+0x1c",
            "policy table 0x57c648 at slot (descriptor_type << 4) + 2",
        ],
        "returns": [
            "true when the selected-member vector is empty",
            "true when every selected member has a nonzero policy byte at table slot +2",
            "false on the first selected member whose policy byte is zero",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_reward_guard_filter_side_effect_dump recovers the selected-member policy helper called by 0x4aa603.",
    },
    {
        "address": "0x49a09c",
        "name": "reward_guard_candidate_offset_contour_validator",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a1d8"],
        "reads": [
            "generated-cell grid wrapper in ecx",
            "candidate-offset vector anchor at stack+0x08 with begin/end at anchor+0x04/+0x08",
            "candidate x/y/level at stack+0x0c/+0x10/+0x14",
            "allow-existing-bit22 flag at stack+0x18",
            "relation pointer at stack+0x1c",
            "require-bit27 flag at stack+0x20",
            "relation type/class at +0x0c",
            "relation leading descriptor id through relation+0x00 -> descriptor -> +0x00",
            "grid generated-cell buffer/width/height at +0x08/+0x0c/+0x10",
            "generated-cell owner/score word +0x20, terrain/art word +0x24, and bit-state +0x28",
        ],
        "returns": [
            "false on hard existing-bit22 rejection when allow-existing-bit22 is false",
            "false on disallowed invalid/gap patterns across the offset contour",
            "true when the contour passes bounds, validity, terrain, owner, bit22, and optional bit27 checks",
        ],
        "writes": ["no generated-cell mutation observed; only stack-local flags are mutated"],
        "ghidra_dump": "Focused dump recovers the contour/vector validator called by 0x49aa93 and 0x4aa603. Same-run replay and exact contour-gap semantic naming remain pending.",
    },
    {
        "address": "0x49aa93",
        "name": "source_relation_object_coordinate_eligibility_gate",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a6f9", "0x49b76d", "0x49a09c", "0x49a1d8"],
        "reads": [
            "generated-cell grid wrapper pointer in ecx",
            "object record/descriptor argument at stack+0x08",
            "candidate x/y/level at stack+0x0c/+0x10/+0x14",
            "source/relation record pointer at stack+0x18",
            "source/relation leading pointer chain used to derive relation id",
            "object descriptor through the object argument, including type/class +0x1c, policy byte +0x29, offsets +0x2c/+0x30, and candidate-offset anchor at object argument +0x14",
            "policy table pointer 0x57c648, including slots (descriptor_type << 4) + 1 and +2",
            "generated-cell grid buffer/width/height at wrapper+0x08/+0x0c/+0x10",
            "generated-cell owner/score word +0x20, terrain/art word +0x24, and bit-state +0x28",
            "source/relation type/class at +0x0c for the terrain-8 comparison",
        ],
        "returns": [
            "false when 0x49a6f9 reports the object footprint is rejected",
            "false when 0x49a09c rejects the candidate-offset contour",
            "true after 0x49a09c when descriptor byte +0x29 is clear",
            "false when descriptor byte +0x29 is set and the descriptor-offset source cell is out of bounds, invalid, has a mismatched owner/relation byte, fails occupied-cell policy checks, or fails the terrain-8 relation policy comparison",
            "true when all footprint, contour, descriptor-offset source-cell, owner, occupied-cell, and terrain-policy gates pass",
        ],
        "writes": ["no generated-cell mutation observed; only stack-local temporaries and copied coordinate triples are mutated"],
        "callers": ["0x4a696b", "0x4a6cf2", "0x4a7312", "0x4a901a", "0x4a93a2", "0x4a9911", "0x4a9641"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_49aa93_eligibility_helper_dump recovers the source/relation object-coordinate eligibility gate from instruction/reference evidence. Ghidra decompile still fails, so exact semantic names and ordered replay remain pending.",
    },
    {
        "address": "0x49b76d",
        "name": "object_descriptor_contour_vector_cache_builder",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x41e951", "0x4268eb", "0x40bb15"],
        "reads": [
            "object descriptor/cache record pointer in ecx",
            "descriptor pointer at record+0x00",
            "8-byte vector begin/end pointers at record+0x18/+0x1c for the vector anchored at record+0x14",
            "descriptor dimensions at descriptor+0x34/+0x38",
            "descriptor mask tests through 0x41e951 and 0x4268eb",
            "direction offsets at 0x5a2658..0x5a2698",
        ],
        "writes": [
            "early-outs without mutation when record+0x18 is nonzero and the record+0x14 vector has a nonzero 8-byte record count",
            "uses stack-local x/y trace coordinates and direction ordinals to walk descriptor-mask contour edges",
            "appends 8-byte coordinate records to the vector anchored at record+0x14 through 0x40bb15",
        ],
        "returns": ["no explicit boolean return contract observed; callers use it as a cache-populating side-effect helper"],
        "callers": ["0x49aa93", "0x4a9641"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_49b76d_policy_helper_dump recovers the descriptor contour/vector cache builder. Ghidra decompile still fails; exact descriptor-mask semantic names and ordered vector replay remain pending.",
    },
    {
        "address": "0x49a6f9",
        "name": "object_descriptor_footprint_acceptance_gate",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4268eb", "0x49a1d8", "0x41e951"],
        "reads": [
            "object descriptor pointer through arg1",
            "object width/height at descriptor+0x34/+0x38",
            "candidate x/y/level/owner/mode args",
            "wrapper grid at ecx+0x08/+0x0c/+0x10",
            "generated cell +0x20 owner, +0x24 terrain, +0x28 bit state",
        ],
        "returns": [
            "false when every footprint/body cell passes bounds, validity, owner, terrain, optional bit26, and 0x41e951 mask tests",
            "true when any footprint/body cell rejects the candidate",
        ],
        "ghidra_dump": "Called by 0x49aa93, 0x49d2e0, and 0x4aa603. Static contract is recovered; exact descriptor field names beyond dimensions and terrain policy branches remain replay-pending.",
    },
    {
        "address": "0x49d471",
        "name": "reward_guard_secondary_member_validator_and_stamper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49d2e0", "0x4ae1fd", "0x4e7276", "0x40bb26", "0x49abd6", "0x42c92d"],
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "candidate object/member record at stack+0x08",
            "candidate descriptor through candidate record+0x04",
            "candidate descriptor dimensions at +0x34/+0x38",
            "candidate descriptor offsets at +0x2c/+0x30",
            "wrapper dimensions at +0x0c/+0x10",
            "existing selected-member vector begin/end at wrapper+0x2c/+0x30",
            "selected-member descriptor through selected member record+0x04",
            "selected-member relative coordinates at +0x08/+0x0c/+0x10",
            "selected-member descriptor type/class at +0x1c and offsets at +0x2c/+0x30",
            "policy table 0x57c648 and direction offsets 0x5a2658..0x5a2698",
        ],
        "writes": [
            "builds a stack-local 12-byte accepted-coordinate vector",
            "rejects when the selected-member vector is empty or the computed index/window gates fail",
            "for existing selected members, chooses a reduced or full direction-offset scan from policy table slot (descriptor_type << 4) + 1",
            "for each in-bounds candidate coordinate, calls 0x49d2e0(wrapper, candidate record, coordinate triple)",
            "appends accepted 12-byte coordinate triples to the local vector through 0x4ae1fd",
            "returns false when the accepted-coordinate vector is empty",
            "selects one accepted coordinate with 0x4e7276 modulo candidate_count",
            "appends the candidate record to wrapper+0x28 through 0x40bb26",
            "stamps the selected coordinate into the wrapper generated-cell grid through 0x49abd6",
            "destroys the local accepted-coordinate vector through 0x42c92d before returning",
        ],
        "returns": ["true after appending and stamping the selected secondary member", "false when no accepted coordinate exists"],
        "callers": ["0x4aa1db"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_49d471_secondary_reward_guard_validator_dump recovers the secondary reward/guard member validation and stamping helper called by 0x4aa1db. Runtime ordered coordinate replay remains pending.",
    },
    {
        "address": "0x49d2e0",
        "name": "reward_guard_candidate_acceptance_helper",
        "status": "recovered_static_contract_runtime_exerciser_pending",
        "calls": ["0x49a1d8", "0x49a6f9"],
        "reads": [
            "reward/guard wrapper in ecx",
            "object/member descriptor through arg1",
            "candidate x/y/level args adjusted by descriptor offsets +0x2c/+0x30",
            "wrapper grid at ecx+0x08/+0x0c/+0x10",
            "descriptor type/class at +0x1c and dimensions/offset fields",
            "policy table 0x57c648",
            "direction tables 0x5a2658 and 0x5a2680",
            "GeneratedCell+0x28 bit22/bit26 state through mapped wrapper cells",
        ],
        "returns": [
            "true when at least one required adjacent/control direction remains valid for the object type policy",
            "false when bit22 adjacency, 0x49a1d8 validity, bit26 availability, or 0x49a6f9 footprint/object rules reject the candidate",
        ],
        "runtime_trace": "The earlier focused traces .artifacts/rmg_recovery/direct_generation_49d2e0_runtime_outcomes_to_4a8c15 and .artifacts/rmg_recovery/direct_generation_reward_chain_hits_to_4a8c15 reached 0x4a8c15 only and therefore stopped before the reward/guard chain. The later same-run trace summarized by .artifacts/rmg_recovery/direct_generation_reward_chain_through_4ac552/reward_chain_trace_summary.json proves that the 0x4ac552 span reaches 0x4aab7e after 0x4a8c15 and records 459 hits at 0x49d2e0: 347 returning to 0x49d5a5 inside 0x49d471 and 112 returning to 0x49d111 inside 0x49cf34. A focused entry/outcome trace summarized by .artifacts/rmg_recovery/direct_generation_49d2e0_entry_outcomes/49d2e0_outcome_summary.json pairs 140 candidate entries with outcome paths: 124 accept at 0x49d468 and 16 reject at 0x49d3e8, split across 0x49cf34 (52 accept, 5 reject, 1 manually-cut missing) and 0x49d471 (72 accept, 11 reject). A branch-reason trace summarized by .artifacts/rmg_recovery/direct_generation_49d2e0_branch_reasons/49d2e0_branch_summary.json pairs 99 entries with 91 accepts, 8 rejects, and 1 manually-cut missing outcome; five rejects are classified by exact internal branch site (0x49d3ad x3, 0x49d3a7 x1, 0x49d466 x1) and three lacked an intermediate branch stop. The follow-up fallthrough trace summarized by .artifacts/rmg_recovery/direct_generation_49d2e0_fallthrough_reasons/49d2e0_fallthrough_summary.json pairs 18 entries with 11 accepts and 7 rejects, and classifies three reject samples at 0x49d3e2 as non-54/9 0x49a6f9 true-return fallthrough to false.",
        "ghidra_dump": "Called by 0x49cf34 and 0x49d471. Static pass recovers direction-table scans, policy-byte gates, bit22/bit26 checks, and 0x49a6f9 footprint probes. Same-run reward-chain exercising, candidate accept/reject outcomes, partial internal reject-branch classification, and the 0x49d3e2 non-special 0x49a6f9 fallthrough rejection class are now proven through focused traces; exact descriptor field names, residual unclassified warm-up/direct-false samples, and final wrapper/object-vector mutation remain pending.",
    },
    {
        "address": "0x49d69d",
        "name": "reward_guard_member_stamp_helper",
        "status": "recovered_static_and_live_selected_coordinate_replay",
        "calls": ["0x40bb26", "0x49abd6"],
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "stack+0x08 object/member record pointer",
            "stack+0x0c selected candidate x from 0x49cf34",
            "stack+0x10 selected candidate y from 0x49cf34",
        ],
        "writes": [
            "calls 0x40bb26 with ecx=wrapper+0x28 and source=&arg1, appending the member pointer to the selected-member dword vector",
            "builds a local 12-byte coordinate triple (arg2, arg3, 0)",
            "calls 0x49abd6 with ecx=wrapper, arg1=member pointer, and the local coordinate triple",
        ],
        "runtime_trace": "Direct-generation trace .artifacts/rmg_recovery/direct_generation_49d69d_runtime_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49d69d_runtime_trace/49d69d_runtime_summary.json, records 38 entries and 37 completed stamp cycles before manual cut. Entry stack layout is return address, member pointer, selected x, selected y. At 0x49d6af EAX points to the member-pointer argument copied into wrapper+0x28 through 0x40bb26. At 0x49d6d4 the 0x49abd6 stack payload is member pointer followed by (x,y,0). Every completed sampled call preserves selected x/y into the stamp coordinate and grows the selected-member vector by one. Wrapper finalization and caller-side cleanup remain pending.",
        "ghidra_dump": "Called by 0x49cf34 after that caller filters candidate coordinates and chooses one with 0x4e7276. Static/Ghidra-backed summary .artifacts/rmg_recovery/direct_generation_49d69d_static/49d69d_static_summary.json verifies the exact call shape, including caller push order selected_y/selected_x/member, wrapper+0x28 vector append through 0x40bb26, local (x,y,0) stamp through 0x49abd6, and ret 0x0c. The helper does not perform RNG, candidate filtering, wrapper+0x4c/+0x50/+0x48 finalization, or final package/object-vector projection.",
    },
    {
        "address": "0x49d6e0",
        "name": "reward_guard_candidate_grid_refresh_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a1d8"],
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "wrapper generated-cell buffer at +0x08",
            "wrapper grid width/height at +0x0c/+0x10",
            "GeneratedCell+0x28 bit22 and bit27 state",
        ],
        "writes": [
            "wrapper+0x18/+0x1c initialized to 0x7d00",
            "wrapper+0x20/+0x24 initialized to 0xffff8300",
            "scans y outer/x inner over the wrapper grid with 0x30-byte generated-cell stride",
            "updates inclusive min x/y and exclusive max x/y bounds for cells that are invalid, bit22 set, or bit27 clear",
            "skips bounds updates only for cells that are valid, bit22-clear, and bit27-set",
        ],
        "ghidra_dump": "Called by 0x49cf34, 0x4aa1db, 0x4adb72, and 0x4ad947. Static/Ghidra-backed summary .artifacts/rmg_recovery/direct_generation_49d6e0_static/49d6e0_static_summary.json verifies wrapper+0x08/+0x0c/+0x10 grid reads, sentinel initialization for +0x18/+0x1c/+0x20/+0x24, 0x49a1d8 validity gating, bit22/bit27 inclusion rules, and exclusive max-bound writes as x+1/y+1. Exact caller ordering and concrete wrapper cell contents remain replay-pending.",
    },
    {
        "address": "0x49d7c3",
        "name": "reward_guard_candidate_vector_rebuild_helper",
        "status": "recovered_static_and_live_append_runtime_replay",
        "calls": ["0x49a1d8", "0x40bb15"],
        "reads": [
            "reward/guard wrapper pointer in ecx",
            "candidate-coordinate vector begin/end through wrapper+0x3c/+0x40",
            "wrapper generated-cell buffer and dimensions at +0x08/+0x0c/+0x10",
            "GeneratedCell+0x28 bit22 and bit27 state",
            "direction records from 0x5a2658/0x5a265c",
        ],
        "writes": [
            "returns without rebuilding when the wrapper+0x38 candidate-coordinate vector already has nonzero 8-byte entries",
            "scans y outer/x inner and advances over cells that are bit22-clear, 0x49a1d8-valid, and bit27-set",
            "starts contour work at the first boundary/control cell that is bit22-set, invalid, or bit27-clear",
            "uses initial contour coordinate boundary x and boundary y-1",
            "appends 8-byte coordinates to wrapper+0x38 through 0x40bb15",
            "probes up to four direction-table neighbors before stepping and loops until it returns to the initial x/y pair",
        ],
        "runtime_trace": "Direct-generation trace .artifacts/rmg_recovery/direct_generation_49d7c3_runtime_trace/winedbg_recovery_trace_ledger.json, summarized by .artifacts/rmg_recovery/direct_generation_49d7c3_runtime_trace/49d7c3_runtime_summary.json, records 20 entries, 19 completed calls, and 259 append-call-site hits at 0x49d868 before manual cut. At each append, EAX points to the local coordinate pair at EBP-0x0c/EBP-0x08 and wrapper+0x3c/+0x40/+0x44 expose pre-append vector begin/end/capacity. The first completed call appends 18 coordinates from an empty vector and exits with vector count 18. Broader caller-specific replay through 0x49cf34 filtering/selection and object-vector mutation remains pending.",
        "ghidra_dump": "Called by 0x4aa354, 0x49cf34, 0x4adb72, and 0x4ad947. Static/Ghidra-backed summary .artifacts/rmg_recovery/direct_generation_49d7c3_static/49d7c3_static_summary.json verifies the non-empty vector no-op, seed scan, boundary/control-cell start condition, wrapper+0x38 8-byte coordinate append through 0x40bb15, direction-table contour walk, and expected caller set.",
    },
    {
        "address": "0x49eb8d",
        "name": "bit26_decorative_candidate_budget_pass",
        "status": "recovered_static_contract_seed58_breakpoint_layout_replay_pending",
        "calls": ["0x49a1d8", "0x49e700", "0x49a932"],
        "reads": [
            "generator pointer in ecx",
            "generated-cell buffer at generator+0x14",
            "map width/height/level count at generator+0x18/+0x1c/+0x20",
            "GeneratedCell+0x28 bit-state word",
            "optional handler pointer at generator+0xed4",
        ],
        "writes": [
            "calls 0x49e700 for valid bit26 candidate cells with x/y/level and budget",
            "calls optional generator+0xed4 vtable slot +0x08 for invalid bit26 candidate cells",
            "calls 0x49a932(true) for valid cells whose bit27 is clear after decorative attempts",
        ],
        "runtime_trace": "tools/rmg_h3maped_49eb8d_trace_summary.py parses the existing seed58 raw winedbg logs into .artifacts/rmg_recovery/seed58_49eb8d_trace_summary.json. The 0x49ec01 breakpoint log proves generated-cell dimensions 36x36x1, bit26 count local [EBP-0x8] = 406, and computed budget 0x4374c // 406 = 680 for that run. A separate 0x49e700 entry breakpoint log proves stack argument layout x=3, y=0, level=0, budget=678 for its first captured dispatch. These are separate debugger runs, so they are layout/count evidence and not a same-run ordered replay. Projection pointer summary .artifacts/rmg_recovery/projection_pointer_trace_summary.json proves a cold 0x49ec51 sample dispatches handler vtable 0x00539660 with slot +0x08 target 0x0045e1a6, not sampled 0x540b00/0x540b14 projection-object methods.",
        "ghidra_dump": "Instruction dump recovers three ordered full-grid passes. Pass 1 counts cells where (GeneratedCell+0x28 >> 26) & 1 is set. If count is nonzero, pass 2 computes budget = 0x4374c / count and scans z/y/x in generator +0x20/+0x1c/+0x18 order; for each bit26 cell it calls 0x49e700 when 0x49a1d8 is true, otherwise calls an optional generator+0xed4 indirect handler with the same budget. The optional handler dispatch is at 0x49ec51 and uses CALL [EAX+0x08] after loading ECX from generator+0xed4 and EAX from [ECX]. Pass 3 scans the grid again and calls 0x49a932(true) when bit27 is clear and 0x49a1d8 is true. Same-run coordinate/count/dispatch replay remains pending; sampled 0x49ec51 must not be treated as the 49c projection-object dispatch without new pointer-paired evidence.",
    },
    {
        "address": "0x49eb6d",
        "name": "generated_cell_at_xyz_helper",
        "status": "recovered_static_ghidra",
        "reads": ["wrapper cell buffer at ecx+0x08", "width at ecx+0x0c", "height at ecx+0x10", "x/y/level args"],
        "returns": ["cell pointer = buffer + (((level * height) + y) * width + x) * 0x30"],
    },
    {
        "address": "0x49ba89",
        "name": "object_record_constructor",
        "status": "recovered_static_ghidra",
        "calls": ["0x49bae3"],
        "reads": ["descriptor pointer arg"],
        "writes": ["record vtable 0x540a74 at +0x00", "descriptor pointer at +0x04", "increments descriptor+0x08 refcount", "initializes record +0x08/+0x0c/+0x10 to -1"],
        "returns": ["constructed record pointer in eax"],
    },
    {
        "address": "0x49b89c",
        "name": "object_record_mask_score_cache_builder",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x41e915", "0x41e951"],
        "reads": ["object record pointer in ecx", "descriptor pointer at record+0x00", "descriptor dimensions at +0x34/+0x38", "descriptor mask tests"],
        "writes": ["record+0xe4 cache-built byte", "record-local dword table beginning at +0x18"],
        "ghidra_dump": "Focused dump shows the helper is idempotent on record+0xe4, walks descriptor width/height, calls descriptor mask helpers, and fills a record-local dword table with relative mask classifications. Exact table semantic names remain replay-pending.",
    },
    {
        "address": "0x4a9e40",
        "name": "object_descriptor_random_selector",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x401b93", "0x40bb26", "0x4e7276"],
        "reads": ["bucket/context pointer in ecx", "selector args", "descriptor pointer vector at bucket+0x38/+0x3c", "descriptor type/category field at +0x20", "descriptor class field at +0x24", "descriptor bitset at +0x18"],
        "returns": ["one candidate descriptor pointer selected by 0x4e7276 % candidate_count", "null when no candidate matches"],
        "ghidra_dump": "Focused dump recovers candidate filtering and random tie selection. Exact semantic names for selector args and descriptor class values remain replay-pending.",
    },
    {
        "address": "0x42ccc6",
        "name": "descriptor_bitset48_index_test",
        "status": "recovered_static_ghidra",
        "reads": ["bitset base pointer in ecx", "bit index at stack+0x04"],
        "returns": [
            "true when bitset[index >> 5] has bit (1 << (index & 31)) set",
            "false when that bit is clear",
        ],
        "range_guard": "unsigned index must be below 48; out-of-range calls 0x42f2ec before continuing",
        "callers": ["0x42650e", "0x42ac12", "0x42b127", "0x47dac4", "0x49e1bf"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42ccc6_42cc99_descriptor_predicate_dump recovers this as a generic 48-bit bitset predicate. In 0x49e1bf it is used against descriptor mask storage at descriptor+0x3c and descriptor+0x04 during decorative footprint/border scoring.",
    },
    {
        "address": "0x42cc99",
        "name": "descriptor_bitset10_index_test",
        "status": "recovered_static_ghidra",
        "reads": ["bitset base pointer in ecx", "bit index at stack+0x04"],
        "returns": [
            "true when bitset[index >> 5] has bit (1 << (index & 31)) set",
            "false when that bit is clear",
        ],
        "range_guard": "unsigned index must be below 10; out-of-range calls 0x401b93 before continuing",
        "callers": ["0x4205b9", "0x49e1bf", "0x4a9911"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_42ccc6_42cc99_descriptor_predicate_dump recovers this as a generic 10-bit bitset predicate. In 0x49e1bf it is called with descriptor+0x14 and the signed terrain/class extracted from GeneratedCell+0x24 bits 26..31.",
    },
    {
        "address": "0x49e1bf",
        "name": "decorative_object_scoring_and_emission_feasibility",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x42ccc6", "0x42cc99", "0x49b89c", "0x40bb26", "0x42c92d"],
        "reads": [
            "generator pointer in ecx with generated-cell buffer/width/height at +0x14/+0x18/+0x1c",
            "object record arg at stack+0x08 and descriptor pointer at record+0x00",
            "candidate x/y/level args at stack+0x0c/+0x10/+0x14",
            "descriptor dimensions at +0x34/+0x38",
            "descriptor mask ranges at +0x04/+0x14/+0x3c",
            "candidate descriptor terrain policy at +0x14 checked through 0x42cc99",
            "candidate object terrain score table at record+0x10 with ten terrain-class contributions",
            "candidate descriptor neighbor score tables at +0x30 and +0x40",
            "GeneratedCell+0x04/+0x08 object-reference vector",
            "GeneratedCell+0x24 terrain/art word",
            "GeneratedCell+0x28 bit-state word",
            "GeneratedCell+0x2b validity byte",
        ],
        "writes": [
            "stack-local footprint records with flags 0x1/0x2/0x4 and stride 0x20",
            "stack-local terrain-class hit vector with ten buckets",
            "stack-local scratch rectangle used for neighbor scans",
            "temporary object-reference flags at +0x14/+0x15/+0x16/+0x17/+0x18",
            "appends flagged object-reference pointers to a local dword vector through 0x40bb26",
            "adds descriptor +0x30/+0x40 table contributions for flagged neighbor references",
            "clears the temporary object-reference flags at +0x14..+0x18 before returning",
        ],
        "returns": [
            "positive candidate emission score when accepted by 0x49e700",
            "-1 when no positive terrain-class contribution is found",
            "-5000 when a hard placement/neighbor conflict path is hit",
            "terrain-weight total directly when the total is below -1000",
        ],
        "ghidra_dump": "Focused dump recovers the ordered footprint pass and neighbor-reference pass. The footprint pass walks descriptor height/width, checks descriptor masks through 0x42ccc6, validates terrain through descriptor+0x14/0x42cc99, rejects bit27 cells, records ten terrain-class hits, and expands a stack-local scratch rectangle. The neighbor pass walks descriptor dimensions plus a one-cell border, gates on the scratch rectangle, scans GeneratedCell+0x04/+0x08 object references, prepares referenced records through 0x49b89c, sets temporary flags +0x14..+0x18, appends flagged references through 0x40bb26, applies descriptor +0x30/+0x40 score-table adjustments, clears flags, and returns the final score/rejection. Exact semantic names for record+0x10 terrain scores, descriptor +0x30/+0x40 neighbor tables, object-reference flag classes, and runtime ordered replay remain pending.",
    },
    {
        "address": "0x49e700",
        "name": "decorative_object_candidate_filler",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x4ae20e", "0x4ae23e", "0x49eb6d", "0x41e951", "0x49e1bf", "0x40bb26"],
        "reads": [
            "generator/wrapper pointer in ecx",
            "candidate x/y/level args",
            "generated cell via 0x49eb6d",
            "terrain-object descriptor table 0x54092c..0x5409e0",
            "object descriptor width/height at +0x34/+0x38",
            "object descriptor type/subtype fields including +0x1c",
        ],
        "writes": [
            "accumulates accepted object emission weights",
            "appends accepted emission weights through 0x40bb26",
            "after weighted selection, creates/projects one decorative object and clears bit26 around the selected footprint unless cell+0x2c bit0 suppresses mutation",
        ],
        "ghidra_dump": "Called by 0x49eb8d. Static pass recovers the terrain-object table loop, local footprint scan through 0x41e951, 0x49e1bf scoring/emission feasibility, weighted-selection setup, and surrounding bit26 cleanup. Exact object record allocation/projection fields remain replay-pending.",
    },
    {
        "address": "0x4a54a7",
        "name": "object_footprint_commit_and_local_owner_projection",
        "status": "recovered_static_contract_projection_storage_candidate_replay_pending",
        "calls": ["0x49abd6", "0x42d8d8", "0x4ae20e", "0x4ae23e", "0x4cce95", "0x430b35", "0x4ccecb", "0x42c92d"],
        "reads": [
            "generator pointer in ecx",
            "generated-cell grid wrapper at generator+0x0c with buffer/width/height at +0x08/+0x0c/+0x10",
            "object record arg at stack+0x08",
            "candidate x/y/level args at stack+0x0c/+0x10/+0x14",
            "object descriptor fields reached through record+0x04",
            "generator object vector anchored at +0xec4",
            "generator relation table at +0x10e4",
            "direction tables 0x5a2658..0x5a2698",
        ],
        "writes": [
            "calls 0x49abd6 to stamp the object footprint into generated cells",
            "inserts the object record into the generator object vector anchored at +0xec4 through 0x42d8d8",
            "increments generator+0x1110 descriptor-type counter indexed by descriptor+0x1c",
            "if descriptor byte +0x29 is zero, exits after object commit and counter update",
            "computes the descriptor-offset source cell from candidate x/y/level minus descriptor +0x2c/+0x30",
            "when source GeneratedCell+0x20 byte2 is nonnegative, increments relation +0x44 + descriptor_type*4",
            "clears the source cell +0x20 low word to zero",
            "seeds a 12-byte coordinate work vector with the source coordinate through 0x4ae20e",
            "seeds a parallel 4-byte low-word score vector with zero through 0x42d8d8",
            "removes the last coordinate and score through 0x4ae23e and 0x4cce95",
            "derives a proposed neighbor score from current GeneratedCell+0x20 low word + 2, with one additional cost on odd direction indices",
            "for each in-bounds direction neighbor whose +0x20 low word is greater than the proposed score, rewrites the low word while preserving the high 16 bits",
            "binary-searches the score vector, inserts the neighbor coordinate into the 12-byte work vector through 0x430b35, and inserts the proposed score into the dword vector through 0x4ccecb",
            "destroys both local vectors through 0x42c92d",
        ],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_object_commit_projection_vector_dump recovers the object commit shell and its sorted low-word projection loop. Projection consumer surface summary .artifacts/rmg_recovery/projection_consumer_surface_summary.json proves the direct 0x49abd6 stamp call, generator +0xec4/+0xecc vector append through 0x42d8d8, descriptor-type counter update at generator+0x1110, and second vector append/worklist surface. This makes 0x4a54a7 the current storage/queue candidate for sampled 0x540b14 projection objects before any later consumer; sampled 0x49eb8d/0x49ec51 is ruled out as that projection-object method dispatch. Exact semantic names for descriptor +0x29/+0x2c/+0x30, relation counter roles, runtime ordered replay, and pointer pairing into the later dispatch remain pending.",
    },
    {
        "address": "0x4ae20e",
        "name": "coord12_vector_append_one_and_return_slot",
        "status": "recovered_static_contract",
        "calls": ["0x430b35"],
        "reads": ["12-byte vector anchor in ecx", "insert/source coordinate pointer args"],
        "writes": [
            "delegates to 0x430b35 with count 1 to insert one 12-byte coordinate record",
            "returns the address corresponding to the inserted 12-byte slot after delegating insertion",
        ],
        "ghidra_dump": "Focused vector-helper dump recovers this as a thin 12-byte vector append/insert wrapper used by 0x4a54a7, 0x49a318, and 0x49e700.",
    },
    {
        "address": "0x4ae23e",
        "name": "coord12_vector_erase_one",
        "status": "recovered_static_contract",
        "reads": ["12-byte vector anchor in ecx", "slot pointer at stack+0x08"],
        "writes": [
            "moves following 12-byte records down by one slot",
            "decrements vector end pointer by 12 bytes",
        ],
        "ghidra_dump": "Focused vector-helper dump recovers this as a 12-byte coordinate-vector erase helper used by 0x4a54a7, 0x49a318, 0x49e700, and connection helpers.",
    },
    {
        "address": "0x430b35",
        "name": "coord12_vector_insert_count",
        "status": "recovered_static_contract",
        "reads": ["12-byte vector anchor in ecx", "insert position pointer", "record count", "source record pointer"],
        "writes": [
            "grows allocation when needed through allocator/free helpers 0x5044b1/0x5044da",
            "moves existing 12-byte records around the insertion point",
            "copies count 12-byte records from the source pointer",
            "updates vector begin/end/capacity pointers",
        ],
        "ghidra_dump": "Focused vector-helper dump recovers this as the generic 12-byte coordinate vector insertion helper used by 0x4a54a7 and related projection code.",
    },
    {
        "address": "0x4cce95",
        "name": "dword_vector_erase_one",
        "status": "recovered_static_contract",
        "reads": ["dword vector anchor in ecx", "slot pointer at stack+0x08"],
        "writes": [
            "moves following 4-byte entries down by one slot",
            "decrements vector end pointer by 4 bytes",
        ],
        "ghidra_dump": "Focused vector-helper dump recovers this as a dword-vector erase helper used by relation/score work vectors.",
    },
    {
        "address": "0x4ccecb",
        "name": "dword_vector_insert_count",
        "status": "recovered_static_contract",
        "reads": ["dword vector anchor in ecx", "insert position pointer", "entry count", "source pointer"],
        "writes": [
            "grows allocation when needed through allocator/free helpers 0x5044b1/0x5044da",
            "moves existing 4-byte entries around the insertion point",
            "copies count dword entries from the source pointer",
            "updates vector begin/end/capacity pointers",
        ],
        "ghidra_dump": "Focused vector-helper dump recovers this as the generic dword vector insertion helper used by 0x4a54a7, 0x4ad6a8, 0x4ad7f7, and 0x49a318.",
    },
    {
        "address": "0x4a5767",
        "name": "cell_occupancy_reset_and_object_anchor_normalization",
        "status": "relation_normalization_static_surface_recovered_runtime_replay_pending",
        "calls": ["0x4a59e2", "0x49a1d8", "0x49a932", "0x49a318", "0x4a5a23"],
        "reads": [
            "generator pointer in ecx",
            "generated-cell buffer/width/height/level count at generator+0x14/+0x18/+0x1c/+0x20",
            "relation pointer vector at generator+0x10e4..+0x10e8",
            "relation record +0x0c type/class value compared with 8",
            "relation record +0x10..+0x1b copied as a 12-byte coordinate/range triple",
            "relation record +0x20..+0x2f copied as four dwords of scan bounds",
            "generated-cell +0x04/+0x08 object-reference vector begin/end",
            "generated-cell +0x1c local word gate",
            "generated-cell +0x20 byte2 owner/relation index",
            "generated-cell +0x24 terrain id",
            "generated-cell +0x28 bit27 occupancy",
        ],
        "writes": [
            "full-grid pass calls 0x4a59e2(cell, 0x7d00, 0, -1), forces cell+0x1c low word to 0x7d00, and copies a local triple into cell+0x10/+0x14/+0x18",
            "for each relation pointer, scans the relation +0x20 bounds for matching generated-cell owner byte2 and valid bit27 candidate cells",
            "when the first scan does not find a candidate, computes a generated-cell pointer from the current local triple and calls 0x49a932(true)",
            "calls 0x49a318 with generator+0x0c grid wrapper, a 12-byte local coordinate triple, and a boolean derived from relation+0x0c == 8",
            "runs a second relation-bounds scan and calls 0x4a5a23(generator, coordinate triple, false) for valid occupied cells, followed by another 0x49a318 call",
        ],
        "ghidra_dump": "Called by 0x4a8c15, 0x4a746b, and 0x4ac552. Instruction recovery plus verifier .artifacts/rmg_recovery/relation_normalization_summary_20260610.json show the full-grid reset/normalization pass, the relation-vector scan over generator+0x10e4..+0x10e8, generated-cell owner/bit27/terrain/object-ref gates, and the helper calls into 0x49a932/0x49a318/0x4a5a23. Exact relation-record field semantics and runtime ordered replay remain pending.",
    },
    {
        "address": "0x49a318",
        "name": "object_anchor_owner_projection_helper",
        "status": "relation_normalization_static_surface_recovered_runtime_replay_pending",
        "calls": ["0x4ae20e", "0x42d8d8", "0x4ae23e", "0x4cce95", "0x4ccecb", "0x430b35"],
        "reads": [
            "generated-cell grid wrapper pointer in ecx with buffer/width/height at +0x08/+0x0c/+0x10",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "policy boolean at stack+0x14",
            "direction table 0x5a2658..0x5a2698",
            "generated-cell projection triple at +0x10/+0x14/+0x18",
            "generated-cell local word gate/priority word at +0x1c",
            "generated-cell owner/score word at +0x20, including byte2 owner/relation index",
            "generated-cell terrain/art word at +0x24",
            "generated-cell bit-state word at +0x28, including bit22, bit25, and bit27",
            "object descriptor policy table through 0x57c648 when bit22 is set",
        ],
        "writes": [
            "seeds a local 12-byte coordinate work vector with the input coordinate through 0x4ae20e/0x42d8d8",
            "resets the source coordinate cell by clearing the low word of +0x1c and writing -1/-1/-1 to +0x10/+0x14/+0x18",
            "pops/scans 12-byte coordinates from the work vector through 0x4ae23e/0x4cce95",
            "for each work coordinate, scans direction offsets from 0x5a2658 with an eight-direction or five-direction policy depending on bit22/descriptor-table gates",
            "rejects candidate cells that are out of bounds, have a negative owner word, lack bit25, or have terrain id 9",
            "applies additional descriptor-table gates for bit22 object cells",
            "when the candidate owner differs from the source owner but matches the previous owner relation, updates the high word of candidate +0x1c, packs the direction ordinal into +0x28 bits 12..14, and writes the source owner into +0x20 byte3",
            "when the candidate owner matches the source owner, updates the low word of candidate +0x1c and copies the current coordinate into candidate +0x10/+0x14/+0x18",
            "for zero-score same-owner candidates with bit27 set, may force the propagated score to zero based on terrain id 8 and the policy boolean",
            "inserts propagated scores into a sorted local dword vector through 0x4ccecb",
            "inserts propagated coordinates into the work vector through 0x430b35",
            "continues until the local coordinate work vector is empty",
        ],
        "ghidra_dump": "Called by 0x4a5767 and 0x4a89da with generator+0x0c grid wrapper, a coordinate triple, and a boolean policy flag. Static recovery plus verifier .artifacts/rmg_recovery/relation_normalization_summary_20260610.json show a work-vector projection/priority propagation helper: it resets the source cell projection, walks direction neighbors, gates on owner/bit25/bit22/terrain/descriptor-table policy, updates GeneratedCell+0x1c high or low word depending on owner relationship, writes projection triples, packs direction bits into +0x28, writes owner byte3 in +0x20, and maintains sorted score plus coordinate work vectors until exhausted. Exact semantic names for the propagated scores, owner-byte roles, descriptor-table policy bytes, and runtime ordered replay remain pending.",
    },
    {
        "address": "0x4a5a23",
        "name": "connection_object_selection_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49eb6d", "0x4a9e40", "0x5044b1", "0x49ba89"],
        "reads": [
            "generator pointer in ecx",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "cleanup-suppression boolean at stack+0x14",
            "generated-cell grid wrapper at generator+0x0c through 0x49eb6d",
            "generated-cell projection triple at +0x10/+0x14/+0x18",
            "generated-cell local word gate at +0x1c",
            "generated-cell owner/score word at +0x20, including byte2 owner/relation index",
            "generated-cell bit-state word at +0x28",
            "generated-cell validity/private byte at +0x2b",
            "generated-cell private flags at +0x2c, including bit0 and bits 1..4 packed source",
        ],
        "writes": [
            "maps the input coordinate through 0x49eb6d using generator+0x0c",
            "returns immediately when the mapped cell +0x1c low word is zero or >= 0x7530",
            "when mapped cell +0x2c bit0 is set, calls 0x4a9e40(generator, 0, 9, ((cell+0x2c >> 1) & 0x0f))",
            "allocates a 0x1c-byte object record and initializes it through 0x49ba89 with the selected descriptor",
            "clears the mapped cell +0x2c low five bits",
            "sets mapped cell bit27 and clears bit26 in +0x28 unless cell+0x2c bit0 suppresses mutation",
            "calls generator vtable slot +0x04 with the current coordinate triple and allocated object record",
            "when cell +0x2c bit0 is clear, sets bit27 and clears bit26 in +0x28",
            "copies the mapped cell +0x10/+0x14/+0x18 projection triple and uses it as the next coordinate",
            "when the cleanup-suppression boolean is false, scans a clipped rectangle from x-1/y-1 through x+1/y+1 around the input coordinate",
            "for same-owner cells in that rectangle whose +0x2c bit0 is clear, clears bit 0x04 in +0x2b",
            "continues following the projection triple chain while the next mapped cell +0x1c low word remains positive",
        ],
        "ghidra_dump": "Called by 0x4a5767 and 0x4a61bc. Static recovery shows a projected-cell chain helper: it maps coordinates through generator+0x0c, gates on GeneratedCell+0x1c, optionally materializes an object from the packed GeneratedCell+0x2c low-nibble source via 0x4a9e40/0x49ba89 and generator vtable slot +0x04, forces bit27/clears bit26, optionally clears GeneratedCell+0x2b bit0x04 in nearby same-owner cells, and follows +0x10/+0x14/+0x18 projection triples until the chain terminates. Exact descriptor category semantics, +0x2b bit0x04 meaning, and runtime ordered replay remain pending.",
    },
    {
        "address": "0x4a606b",
        "name": "connection_region_generated_cell_writer",
        "status": "recovered_static_contract_current_corpus_no_live_hit",
        "calls": ["0x49aa63", "0x49a932"],
        "reads": [
            "generator pointer in ecx",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "low-nibble source/flag arg at stack+0x14; both 0x4a61bc callers pass the nonnegative return value from 0x4a5e73",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "generated-cell object-reference vector begin/end at +0x04/+0x08",
            "generated-cell projection triple at +0x10/+0x14/+0x18",
            "generated-cell private flags at +0x2c",
        ],
        "writes": [
            "clamps a 3x3 rectangle around the x/y coordinate args to [0,width) and [0,height) on the supplied level",
            "for cells in that rectangle whose object-reference vector is empty, calls 0x49aa63(true)",
            "for the same accepted cells, writes cell+0x2c = (old & 0xffffffe1) | ((arg4 & 0x0f) << 1) | 1",
            "after the rectangle pass, reads the source coordinate cell's +0x10/+0x14/+0x18 projection triple",
            "when that projected x/y is in bounds, clears low five bits of the projected target cell +0x2c and calls 0x49a932(true)",
        ],
        "caller_contract": "Both 0x4a61bc call sites are gated by control byte [arg2+0x09] and a successful 0x4a5e73 return. The first call passes the selected 12-byte temporary candidate coordinate at EBP-0x3c..-0x34 after 0x4a5e73(generator, selected_candidate, true, relation_record_from_generator+0x10e4) returns nonnegative. The second call passes the direction-adjacent coordinate at EBP-0x48..-0x40, computed from the selected candidate plus direction offset 0x5a2658[(selected_cell+0x28 >> 12) & 7], after 0x4a5e73(generator, direction_adjacent, true, stack_arg+0x08) returns nonnegative. In both calls the 0x4a606b low-nibble arg is the 0x4a5e73 return value.",
        "ghidra_dump": "Called twice by 0x4a61bc. Static recovery shows a clamped connection-region pass around the provided x/y/level coordinate, object-reference-vector emptiness gating, bit26 writes through 0x49aa63(true), private low-bit flag packing in GeneratedCell+0x2c, and a follow-up projected target cell bit27 write through 0x49a932(true). Caller coordinate meanings are statically recovered from 0x4a61bc. .artifacts/rmg_recovery/4a606b_reachability_summary_20260610.json proves the current target corpus has breakpoint-only mentions and zero live 0x4a606b stops/events; broader reachability or source-backed exclusion remains pending.",
    },
    {
        "address": "0x4a746b",
        "name": "connection_endpoint_writer",
        "status": "recovered_static_contract_caller_offsets_replay_pending",
        "calls": ["0x4a5767", "0x4a5e73", "0x49aa63"],
        "reads": [
            "generator pointer in ecx",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "source/flag arg at stack+0x14",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "generated-cell local word gate at +0x1c",
            "generated-cell projection triple at +0x10/+0x14/+0x18",
            "generated-cell owner/score dword at +0x20, including byte2 owner/relation index",
            "generated-cell bit-state dword at +0x28, including bit27",
            "generated-cell private flags at +0x2c",
            "stack-local five-entry endpoint offset table at ebp-0x48..ebp-0x20: (0,1), (1,0), (-1,0), (1,1), (-1,1)",
        ],
        "writes": [
            "calls 0x4a5767(generator) before endpoint selection",
            "derives the source generated cell from the input x/y/level coordinate triple",
            "returns false before endpoint helper work when the source cell +0x1c low word is >= 0x7530",
            "when the source cell +0x1c low word is positive, uses source cell +0x10/+0x14/+0x18 as the selected endpoint triple",
            "otherwise scans the five local endpoint offsets for a candidate cell whose +0x20 byte2 matches the source owner/relation index and whose +0x28 bit27 is set",
            "when no local endpoint offset matches, falls back to selected endpoint triple (x, y + 1, level)",
            "calls 0x4a5e73(generator, selected endpoint triple, true, arg4)",
            "when 0x4a5e73 returns nonnegative, stamps the same five local offset cells with 0x49aa63(true)",
            "for each stamped cell, writes cell+0x2c = (old & 0xffffffe1) | ((result & 0x0f) << 1) | 1",
            "returns true when 0x4a5e73 returns nonnegative and false otherwise",
        ],
        "caller_contract": "Both 0x4a7605 call sites are gated by control byte [arg2+0x09] and pass the newly allocated object record's relative coordinate triple at record+0x08/+0x0c/+0x10. The first call validates the allocated record against the original stack arg1, appends it to the generator+0x14c0/0x14d0 vector selected by local flag -0x14, records the coordinate in arg1+0x404, and calls 0x4a746b(generator, record+0x08 triple, relation record selected from generator+0x10e4 by arg2 index). The second call validates against that selected relation record, appends to the generator vector, records the coordinate in relation+0x404, and calls 0x4a746b(generator, record+0x08 triple, original stack arg1).",
        "ghidra_dump": "Called twice by 0x4a7605. Static recovery shows the normalize-first endpoint writer: it calls 0x4a5767, derives a source cell from the input coordinate, chooses an endpoint either from source projection fields, one of five local offset records with matching owner/bit27, or fallback (x,y+1,level), calls 0x4a5e73, and on success stamps the five endpoint-offset cells (0,1), (1,0), (-1,0), (1,1), and (-1,1) through 0x49aa63(true) plus GeneratedCell+0x2c low-bit packing. Checked chain summary .artifacts/rmg_recovery/connection_endpoint_chain_static_summary.json verifies the exact instruction sites for 0x4a5767 normalization, 0x7530 low-word rejection, five-offset owner/bit27 tests, y+1 fallback, 0x4a5e73 call, 0x49aa63 stamps, and packed low-nibble cell+0x2c writes. Caller coordinate meanings, local endpoint offsets, and the downstream 0x4a7312 selection policy are statically recovered. Live 0x4a7605 branch-gate summary .artifacts/rmg_recovery/7605_branch_gate_summary.json proves the sampled invocation skipped both 0x4a746b call sites because [ESI+0x09] was 0; runtime ordered replay of an executed 0x4a746b path remains pending.",
        "next_runtime_replay": [
            "find a live 0x4a7605 sample with [ESI+0x09] != 0 or another caller path that actually reaches 0x4a746b",
            "capture 0x4a746b entry source cell, low word, owner byte, and source projection triple",
            "capture selected endpoint at 0x4a7593, 0x4a5e73 return value, and five stamped offset cells at 0x4a75f1",
        ],
    },
    {
        "address": "0x4a5e73",
        "name": "connection_endpoint_selection_helper",
        "status": "recovered_static_contract_current_corpus_success_path_unhit",
        "calls": ["0x5044b1", "0x49ba89", "0x4a7312"],
        "reads": [
            "generator pointer in ecx",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "repeat/count arg at stack+0x14",
            "mode/source arg passed to 0x4a7312 at stack+0x18",
            "current generator index at +0xf5c",
            "index-keyed pointer vector at generator+0xd8/+0xdc",
            "index-keyed pointer vector at generator+0xc8/+0xcc",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "generated-cell private flags at +0x2c",
            "generated-cell bit-state word at +0x28",
            "generator byte-state vector at +0x1104/+0x1108",
        ],
        "writes": [
            "searches generator+0xd8/+0xdc for an entry whose dereferenced record +0x20 matches generator+0xf5c",
            "returns -1 when the +0xd8 vector has no matching entry",
            "searches generator+0xc8/+0xcc for an entry whose dereferenced record +0x20 matches generator+0xf5c",
            "returns 0 when the +0xd8 match exists but the +0xc8 vector has no matching entry",
            "allocates a 0x1c-byte object record and initializes it through 0x49ba89 using the +0xd8 matched entry",
            "calls 0x4a7312(generator, allocated record, arg5) and returns -1 after destroying the record when that helper rejects it",
            "when repeat/count arg is positive, allocates one 0x1c-byte object record per repeat and initializes it through 0x49ba89 using the +0xc8 matched entry",
            "for each repeated coordinate, clears low five bits of generated-cell +0x2c, then sets bit27 and clears bit26 in +0x28",
            "calls generator vtable slot +0x04 with the current coordinate triple and the per-repeat object record",
            "increments x for each repeat and decrements the repeat counter until exhausted",
            "marks generator+0x1104[original +0xf5c] = 1",
            "resets generator+0xf5c to zero and advances it while generator+0x1104[index] is nonzero within the +0x1104/+0x1108 byte-vector range",
            "returns the original generator+0xf5c index after successful validation/projection",
        ],
        "ghidra_dump": "Called by 0x4a61bc, 0x4a696b, 0x4a6cf2, and 0x4a746b. Static recovery shows an endpoint helper keyed by generator+0xf5c: it matches entries in generator+0xd8/+0xdc and +0xc8/+0xcc pointer vectors, validates an allocated +0xd8-derived object through 0x4a7312, optionally projects a repeated run of +0xc8-derived records across generated cells while forcing bit27 and clearing bit26, updates the byte-state vector at +0x1104/+0x1108, advances +0xf5c, and returns the original index or a failure sentinel. Checked chain summary .artifacts/rmg_recovery/connection_endpoint_chain_static_summary.json verifies the exact instruction sites for +0xf5c cursor reads/writes, +0xd8/+0xdc and +0xc8/+0xcc vector scans, +0x2c/+0x28 generated-cell mutation, generator vtable slot +0x04 calls, and +0x1104/+0x1108 byte-state cursor advancement. Cursor-frontier summary .artifacts/rmg_recovery/4a5e73_cursor_frontier_summary_20260610.json verifies 50 current-corpus entries, 20 observed early failures at 0x4a5f84, and zero success-path mutation hits. Cursor-owner exclusion summary .artifacts/rmg_recovery/cursor_writer_owner_exclusion_summary_20260610.json proves the only non-self +0xf5c writers are bound to currently unhit projection/cleanup slot methods. Exact vector-entry semantic names and any source path that seeds generator+0xf5c outside that excluded chain remain pending.",
        "next_runtime_replay": [
            "find or source-exclude a path that seeds generator+0xf5c to a live +0xd8/+0xc8 key before 0x4a5e73 outside the currently excluded non-self writer chain",
            "capture successful 0x4a5e73 entry/return generator+0xf5c, +0xd8/+0xdc, +0xc8/+0xcc, +0x1104/+0x1108, stack coordinate triple, repeat/count, and return value",
            "capture generated-cell address plus +0x20/+0x24/+0x28/+0x2c before and after the 0x4a5fd8/0x4a5ff1 repeat projection mutation",
        ],
    },
    {
        "address": "0x4a7312",
        "name": "connection_endpoint_source_bounded_object_picker",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49aa93", "0x4ae1fd", "0x4e7276", "generator_vtable+0x04", "0x42c92d"],
        "reads": [
            "generator pointer in ecx",
            "object record arg at stack+0x08",
            "source/relation record arg at stack+0x0c",
            "object descriptor through object record+0x04",
            "descriptor dimensions at +0x34/+0x38",
            "source/relation coordinate triple at +0x10/+0x14/+0x18",
            "source/relation scan bounds at +0x20/+0x24/+0x28/+0x2c",
            "source/relation leading pointer chain used to derive the owner/relation id",
            "generated-cell buffer/width/height at generator+0x14/+0x18/+0x1c",
            "generated-cell owner/score word at +0x20, including byte2 owner/relation id",
        ],
        "writes": [
            "scans candidate x/y positions inside the source/relation bounds adjusted by descriptor width/height",
            "rejects candidates whose generated-cell +0x20 byte2 owner/relation id does not match the source/relation id",
            "calls 0x49aa93(generator, object descriptor/record, candidate coordinate triple, source/relation record) for matching-owner candidates",
            "appends accepted 12-byte coordinate triples into a local vector through 0x4ae1fd",
            "returns false when the accepted-coordinate vector is empty or its 12-byte record count is zero",
            "selects one accepted coordinate with 0x4e7276 % candidate_count",
            "calls generator vtable slot +0x04 with the selected coordinate triple and object record",
            "destroys the local coordinate vector through 0x42c92d before return",
        ],
        "returns": ["true after committing the selected object coordinate through generator vtable slot +0x04", "false when no eligible coordinate exists"],
        "ghidra_dump": "Focused dump .artifacts/rmg_recovery/ghidra_4a7312_policy_dump recovers the policy from assembly. Checked chain summary .artifacts/rmg_recovery/connection_endpoint_chain_static_summary.json verifies the exact instruction sites for descriptor dimension reads, source bounds/coordinate copies, owner-byte candidate filtering, 0x49aa93 eligibility calls, 0x4ae1fd candidate appends, 0x4e7276 % candidate_count selection, generator vtable slot +0x04 commit, and 0x42c92d candidate-vector destruction. Ghidra decompile still fails, so exact source/relation field names and runtime ordered replay remain pending.",
        "next_runtime_replay": [
            "capture 0x4a7312 entry source/relation record fields, object record/descriptor fields, and candidate scan bounds",
            "capture 0x4a73e0 candidate vector appends, 0x4e7276 selected index, 0x4a7447 selected coordinate, and object record passed to generator vtable slot +0x04",
        ],
    },
]

STRUCTS: list[dict[str, Any]] = [
    {
        "name": "H3MapEdGenerator",
        "status": "must_recover_with_xrefs_and_runtime_dumps",
        "known_fields": {
            "+0x14": "generated_cell_buffer_begin",
            "+0x18": "map_width",
            "+0x1c": "map_height",
            "+0x20": "level_count",
            "+0xc8": "index-keyed pointer vector begin used by 0x4a5e73",
            "+0xcc": "index-keyed pointer vector end used by 0x4a5e73",
            "+0xd8": "index-keyed pointer vector begin used by 0x4a5e73",
            "+0xdc": "index-keyed pointer vector end used by 0x4a5e73",
            "+0xec4": "object record vector anchor observed by 0x4a54a7, 0x4add76, 0x4af910, and diagnostic snapshots for 0x4a79a3",
            "+0xec8": "object record vector begin pointer read by cleanup consumers and the 0x4a79a3 phase consumer",
            "+0xecc": "object record vector end/insertion pointer observed by 0x4a54a7 and read by cleanup consumers plus the 0x4a79a3 phase consumer",
            "+0xed4": "optional handler pointer used by 0x49eb8d for invalid bit26 candidate cells; vtable slot +0x08 is called with the per-cell budget",
            "+0xed8": "source handler pointer assigned by 0x4af463 from stack+0x08 and used by 0x4af910",
            "+0xedc": "16-byte vector/anchor initialized by 0x4af463",
            "+0xeec": "pending-entry vector anchor initialized by 0x4af463; holds 8-byte (handler key, object record) entries consumed by 0x4af910",
            "+0xef0": "pending-entry vector begin read by 0x4af910",
            "+0xef4": "pending-entry vector end read by 0x4af910",
            "+0xf5c": "current endpoint/index cursor used and advanced by 0x4a5e73",
            "+0x10e4": "runtime_zone_relation_vector_begin",
            "+0x10e8": "runtime_zone_relation_vector_end",
            "+0x1104": "byte-state vector begin used by 0x4a5e73 to mark and advance index cursor",
            "+0x1108": "byte-state vector end used by 0x4a5e73",
            "+0x1110": "descriptor-type counter table indexed by descriptor+0x1c in 0x4a54a7",
            "+0x14b0": "strategic_route_coordinate_vector_begin",
            "+0x14b4": "strategic_route_coordinate_vector_end",
            "+0x14b8": "strategic_route_coordinate_vector_capacity",
        },
    },
    {
        "name": "SourceHandler_53eafc",
        "status": "recovered_static_contract",
        "known_fields": {
            "+0x00": "vtable pointer 0x53eafc installed by 0x4802ac",
            "+0x04": "second source-derived dimension/index value returned by 0x42a1ec",
            "+0x08": "first source-derived dimension/index value returned by 0x42a1ec",
            "+0x0c": "source pointer used by vtable slots +0x00/+0x04/+0x08/+0x0c/+0x10/+0x20",
            "+0x10": "secondary source/policy pointer used by vtable slots +0x14/+0x18",
            "+0x14": "mode byte passed into 0x42a28e, 0x43c5c4, and 0x429ea3",
        },
        "vtable_slots": {
            "+0x00": "0x4802ea stream begin",
            "+0x04": "0x48031b stream advance",
            "+0x08": "0x480352 stream key to descriptor/source pointer",
            "+0x0c": "0x48037b stream key to two-dword coordinate/source payload",
            "+0x10": "0x4803b6 x/y terrain low-nibble lookup",
            "+0x14": "0x4803e2 x/y class equals 1 predicate",
            "+0x18": "0x4803ff x/y class equals 2 predicate",
            "+0x20": "0x48047c queued-key cleanup through 0x429ea3",
        },
    },
    {
        "name": "GeneratedCell",
        "stride_bytes": 0x30,
        "status": "must_match_per_cell_at_checkpoints",
        "known_fields": {
            "+0x04": "object-reference dword vector begin pointer observed by 0x49e1bf",
            "+0x08": "object-reference dword vector end pointer observed by 0x49e1bf",
            "+0x10": "projection/local coordinate dword 0 written by 0x4a5767 and read by 0x4a606b",
            "+0x14": "projection/local coordinate dword 1 written by 0x4a5767 and read by 0x4a606b",
            "+0x18": "projection/local coordinate dword 2 written by 0x4a5767 and read by 0x4a606b",
            "+0x1c": "projection/local dword; 0x4a59e2 writes the high word and 0x4a5767 forces the low word before 0x4a746b thresholds it",
            "+0x20": "owner/score dword consumed by 0x4a4c8e byte2 owner; 0x4a59e2 writes byte3 while preserving the lower 24 bits",
            "+0x24": "terrain/art dword consumed by 0x4a4c8e and 0x49b2b6; 0x49acf6 writes terrain low six bits and an arg2 byte at bits 6..13",
            "+0x28": "generated-cell bit-state dword; 0x4a59e2 writes bits 12..14, 0x49acf6 writes bits 15..16, 0x49abd6 clears bit25 through byte +0x2b bit 0x02, and 0x49aa63/0x49a932 toggle bits 26/27",
            "+0x2b": "validity/private byte; bit 0x02 is required by 0x49a1d8, tested by 0x49e1bf neighbor scans, and cleared by 0x49abd6 at 0x49ac8e for rejected descriptor-mask cells; bit 0x04 is cleared by 0x4a5a23 for nearby same-owner cells",
            "+0x2c": "cell private flags; bit0 skips 0x49a932/0x49aa63 helpers",
        },
    },
    {
        "name": "H3MapEdRelationRecord",
        "status": "observed_static_fields_replay_pending",
        "known_fields": {
            "+0x0c": "type/class value compared with 8 by 0x4a5767",
            "+0x10..+0x1b": "12-byte coordinate/range triple copied by 0x4a5767 before object-anchor projection",
            "+0x20..+0x2f": "four dword scan bounds copied by 0x4a5767 for relation-local generated-cell scans",
        },
    },
    {
        "name": "RouteCoordinateVector",
        "record_size_bytes": 8,
        "status": "recovered_static_helper_contract",
        "known_fields": {
            "+0x04": "begin pointer",
            "+0x08": "end pointer",
            "+0x0c": "capacity pointer",
        },
    },
    {
        "name": "Coord12CandidateVector",
        "record_size_bytes": 12,
        "status": "recovered_static_helper_contract",
        "known_fields": {
            "+0x04/+0x08/+0x0c": "begin/end/capacity pointer triad for 12-byte coordinate records; helper callers may pass the anchor or an interior anchor depending on wrapper layout",
            "+0x08": "end pointer read/written by 0x4ae1fd and 0x4ae52a when ecx is the vector anchor",
        },
    },
    {
        "name": "DwordVector",
        "record_size_bytes": 4,
        "status": "recovered_static_helper_contract",
        "known_fields": {
            "+0x04": "begin pointer",
            "+0x08": "end pointer",
            "+0x0c": "capacity pointer",
        },
    },
    {
        "name": "RewardGuardGridWrapper",
        "status": "recovered_static_fields_replay_pending",
        "known_fields": {
            "+0x08": "generated_cell_buffer",
            "+0x0c": "width",
            "+0x10": "height",
            "+0x18": "candidate_bounds_min_x",
            "+0x1c": "candidate_bounds_min_y",
            "+0x20": "candidate_bounds_max_x_exclusive",
            "+0x24": "candidate_bounds_max_y_exclusive",
            "+0x28": "selected_member_dword_vector_anchor; vector begin/end/capacity at +0x2c/+0x30/+0x34",
            "+0x38": "candidate_coordinate_vector_anchor; vector begin/end/capacity at +0x3c/+0x40/+0x44",
            "+0x48": "selected-member attached flag set by 0x49cf34 after successful candidate selection",
            "+0x4c": "selected_member_relative_x_after_0x49cf34",
            "+0x50": "selected_member_relative_y_after_0x49cf34",
            "+0x54..+0x5c": "selected coordinate triple written by 0x4aa3e9 before final wrapper projection",
        },
    },
    {
        "name": "H3MapEdObjectDescriptorMaskFields",
        "status": "recovered_static_fields_semantics_pending",
        "known_fields": {
            "+0x04": "48-bit object descriptor bitset tested by 0x41e951 with bit index 47 - 8*y - x",
            "+0x0c": "48-bit object descriptor bitset tested by 0x4268eb with bit index 47 - 8*y - x",
            "+0x14": "10-bit descriptor terrain/policy bitset tested by 0x42cc99 with a generated-cell terrain/class index",
            "+0x34": "descriptor width used by placement, footprint, and contour helpers",
            "+0x38": "descriptor height used by placement, footprint, and contour helpers",
            "+0x3c": "48-bit object descriptor bitset tested by 0x41e915 with bit index 47 - 8*y - x and by 0x42ccc6 with caller-computed flat indices in decorative scoring",
        },
    },
    {
        "name": "H3MapEdObjectRecord",
        "status": "recovered_static_fields_replay_pending",
        "constructor": "0x49ba89",
        "known_fields": {
            "+0x00": "vtable pointer 0x540a74",
            "+0x04": "object descriptor pointer",
            "+0x08": "initialized to -1 by 0x49ba89; relative x coordinate in reward/guard selected-member wrapper passes",
            "+0x0c": "initialized to -1 by 0x49ba89; relative y coordinate in reward/guard selected-member wrapper passes",
            "+0x10": "initialized to -1 by 0x49ba89; relative level/z coordinate in reward/guard selected-member wrapper passes",
            "+0x18": "start of record-local dword table filled by 0x49b89c",
            "+0xe4": "cache-built byte checked and set by 0x49b89c",
        },
    },
    {
        "name": "ObjectDescriptorContourCacheRecord",
        "status": "recovered_static_fields_replay_pending",
        "producer": "0x49b76d",
        "known_fields": {
            "+0x00": "object descriptor pointer read by 0x49b76d",
            "+0x14": "8-byte coordinate/vector anchor populated by 0x49b76d",
            "+0x18": "vector begin pointer for the record+0x14 vector",
            "+0x1c": "vector end pointer for the record+0x14 vector",
            "+0x20": "vector capacity pointer inferred from the standard 8-byte vector anchor layout",
        },
    },
    {
        "name": "GeneratedCellObjectReference",
        "status": "recovered_static_field_offsets_semantics_pending",
        "known_fields": {
            "+0x04": "object record pointer passed to 0x49b89c and descriptor score-table reads",
            "+0x08": "x-like coordinate used by 0x49e1bf table lookup",
            "+0x0c": "y-like coordinate used by 0x49e1bf table lookup",
            "+0x14": "temporary neighbor flag set/cleared by 0x49e1bf",
            "+0x15": "temporary neighbor flag set/cleared by 0x49e1bf; paired with +0x14 for hard-conflict rejection",
            "+0x16": "temporary neighbor flag set/cleared by 0x49e1bf; applies descriptor +0x30 score table when record+0x10 is present",
            "+0x17": "temporary neighbor flag set/cleared by 0x49e1bf after 0x49b89c table comparison",
            "+0x18": "temporary neighbor flag set/cleared by 0x49e1bf; applies descriptor +0x40 score table or hard rejection when record+0x10 is absent",
        },
    },
    {
        "name": "RouteCoordinateListNode",
        "record_size_bytes": 16,
        "status": "recovered_static_helper_contract",
        "known_fields": {
            "+0x00": "prev pointer",
            "+0x04": "next pointer",
            "+0x08": "coord_x dword",
            "+0x0c": "coord_y dword",
        },
    },
]

CHECKPOINTS: list[dict[str, Any]] = [
    {"id": "after_terrain_live_feedback", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "after_town_castle", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "object_vector_entry", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "after_each_0x49a932_call", "required_words": ["0x28", "0x2c"], "requires_caller": True},
    {"id": "after_each_0x49aa63_call", "required_words": ["0x28", "0x2c"], "requires_caller": True},
    {"id": "after_object_vector_exit", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "pre_0x4a4c8e", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    exe = args.h3maped_exe.resolve()
    if not exe.exists():
        raise SystemExit(f"missing h3maped.exe: {exe}")
    manifest = {
        "schema_id": "h3maped_rmg_end_to_end_recovery_manifest_v1",
        "h3maped_exe": str(exe),
        "h3maped_sha256": sha256(exe),
        "recovery_policy": "no native behavior edits until trace replay matches H3MapEd private state",
        "tooling_policy": "Wine/Ghidra/Python only for active recovery; no objdump probe is run by this manifest.",
        "functions": FUNCTIONS,
        "structs": STRUCTS,
        "checkpoints": CHECKPOINTS,
        "frontier_summaries": FRONTIER_SUMMARIES,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_RECOVERY_MANIFEST status=pass functions={len(FUNCTIONS)} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
