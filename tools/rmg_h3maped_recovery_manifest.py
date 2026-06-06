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
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_H3MAPED = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/h3maped_recovery_manifest.json")

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
    },
    {
        "address": "0x49a1d8",
        "name": "generated_cell_validity_predicate",
        "status": "recovered_static_ghidra",
        "returns_true_when": ["cell+0x2b has bit 0x02 set", "terrain id (cell+0x24 & 0x3f) is not 9"],
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
    },
    {
        "address": "0x49aa63",
        "name": "generated_cell_decor_candidate_writer",
        "status": "recovered_static_and_seed58_pre_0x4a4c8e_runtime",
        "writes": ["when cell+0x2c bit0 clear: arg false clears bit26", "arg true sets bit26 then clears bit27"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e shows 490 calls, all arg true, 490 unique generated-cell flats, then 0x4a4c8e. This matches the seed-58 pre-0x4a4c8e bit26 count.",
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
    },
    {
        "address": "0x49abd6",
        "name": "object_mask_stamp_generated_cell_mutator",
        "status": "recovered_static_and_seed58_body_cell_trace",
        "writes": ["cell+0x28 bit22", "cell+0x28 bit25", "cell+0x28 bit27 via 0x49a932"],
        "runtime_trace": "seed58_interactive_49abd6_to_4a8c15 records five object-footprint calls; seed58_interactive_49abd6_body_cells_to_4a8c15 records five 0x49ac6b body-cell writes at flats 184, 666, 604, 975, and 1059.",
    },
    {
        "address": "0x4aa3e9",
        "name": "reward_object_final_commit_and_wrapper_projection",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49d2c7", "0x49a1d8", "0x49a932", "0x49aa63"],
        "reads": [
            "generator/context pointer in ecx",
            "reward/guard wrapper pointer at stack+0x08",
            "selected coordinate triple args at stack+0x0c/+0x10/+0x14",
            "wrapper generated-cell grid at +0x08/+0x0c/+0x10",
            "wrapper selected-member vector begin/end at +0x2c/+0x30",
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
        "ghidra_dump": "Called by 0x4aa9b7 after that caller selects a candidate coordinate. Static recovery shows the final reward/guard wrapper projection shell: selected coordinate storage at wrapper+0x54, selected-member callback dispatch through the generator/context vtable slot +0x04, overlap projection from generator cells into wrapper cells while preserving source bit26/bit27 through 0x49aa63/0x49a932, conditional source bit27 clear/source bit26 set based on destination/source validity and bit22/terrain gates, and final selected-member vtable slot +0x08 callbacks. Exact selected-member record semantics, callback contracts, and runtime ordered replay remain pending.",
    },
    {
        "address": "0x4a4c8e",
        "name": "land_edge_generated_cell_bit_writer_entry_checkpoint",
        "status": "checkpoint_authority",
        "reads": ["generator+0x14 generated cells", "generator+0x10e4 runtime-zone relation vectors"],
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
        "runtime_trace": "For seed 58, caller-side traces before 0x4a4c8e record 1,686 route insertion call-site events, 52 0x4a80dc pairs, 340 0x49a85d route stamps, and 490 0x49a962 boundary clears. The 0x4a858f stamp coordinate order exactly matches the direct 0x49a85d trace, and the 11 far-cut insertion pairs match the 0x4a80dc squared-distance >= 25 gate.",
    },
    {
        "address": "0x4a8c15",
        "name": "generated_cell_post_terrain_phase_driver",
        "status": "recovered_static_and_seed58_runtime_prefix",
        "calls_in_order": ["0x4a8260", "0x4a4c8e", "per-cell scan calling 0x49a962", "0x4a4913 loop over generator+0x10e4 vector", "0x4a5767", "0x4a4fc5", "0x4a79a3"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e confirms 0x4a8c15 -> 0x4a8260 -> 490 calls to 0x49aa63 -> 0x4a4c8e for the bit26 writer stream.",
    },
    {
        "address": "0x49b3fb",
        "name": "runtime_zone_relation_lookup",
        "status": "known_helper_must_keep_in_manifest",
    },
    {
        "address": "0x49cf34",
        "name": "reward_guard_attach_generated_cell_pass",
        "status": "recovered_static_contract_replay_pending",
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
            "object/member-relative coordinate fields from selected-member records",
            "object/member descriptor chain including a class/terrain-like value read through +0x1c",
            "direction table 0x5a2658..0x5a2698",
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
        "ghidra_dump": "Called by 0x4aa354 and 0x4adb72. Static recovery shows a three-phase reward/guard attach pass: selected-member neighborhood mutation, reverse filtering of wrapper candidate coordinates through bit26 and 0x49d2e0, then random candidate selection with 0x49d69d stamping, direction-neighborhood bit27 writes, wrapper+0x4c/+0x50/+0x48 finalization, candidate-vector range cleanup, and wrapper bounds/candidate refresh. Exact selected-member record fields, object/member descriptor semantics, direction-policy class values, and runtime ordered replay remain pending.",
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
        "address": "0x49d2e0",
        "name": "reward_guard_candidate_acceptance_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a1d8", "0x49a6f9"],
        "reads": ["object descriptor through arg1", "candidate x/y/level args", "wrapper grid at ecx+0x08/+0x0c/+0x10", "direction tables 0x5a2658 and 0x5a2680"],
        "returns": ["true when the candidate passes object terrain/footprint/ring checks", "false when bit22/object adjacency/terrain rules reject it"],
        "ghidra_dump": "Called by 0x49cf34 and 0x49d471. Static pass recovers direction-table scans and 0x49a6f9 footprint probes; exact object descriptor field naming remains replay-pending.",
    },
    {
        "address": "0x49d69d",
        "name": "reward_guard_member_stamp_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x40bb26", "0x49abd6"],
        "reads": ["arg1 object/member pointer", "arg2 x", "arg3 y"],
        "writes": ["appends arg1 to wrapper+0x28 dword vector", "stamps arg2/arg3/level 0 through 0x49abd6"],
        "ghidra_dump": "Called by 0x49cf34. Static contract is recovered; member object projection into final package/object vector remains replay-pending.",
    },
    {
        "address": "0x49d6e0",
        "name": "reward_guard_candidate_grid_refresh_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a1d8"],
        "writes": ["wrapper+0x18/+0x1c initialized to 0x7d00", "wrapper+0x20/+0x24 initialized to 0xffff8300", "updates bounds over cells that are invalid, bit22 set, or bit27 clear"],
        "ghidra_dump": "Called by 0x49cf34, 0x4aa1db, 0x4adb72, and 0x4ad947. Static bounds recomputation is recovered; exact caller ordering and vector contents remain replay-pending.",
    },
    {
        "address": "0x49d7c3",
        "name": "reward_guard_candidate_vector_rebuild_helper",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49a1d8", "0x40bb15"],
        "writes": ["when wrapper+0x38 vector is empty, appends 8-byte coordinates to wrapper+0x38 vector", "traces the contour starting from the first valid bit27 cell with bit22 clear"],
        "ghidra_dump": "Called by 0x49cf34 and reward/guard setup callers. Static contour/vector rebuild contract is recovered; exact runtime coordinate sequence must still be traced and replayed.",
    },
    {
        "address": "0x49eb8d",
        "name": "bit26_decorative_candidate_budget_pass",
        "status": "recovered_static_contract_replay_pending",
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
        "ghidra_dump": "Instruction dump recovers three ordered full-grid passes. Pass 1 counts cells where (GeneratedCell+0x28 >> 26) & 1 is set. If count is nonzero, pass 2 computes budget = 0x4374c / count and scans z/y/x in generator +0x20/+0x1c/+0x18 order; for each bit26 cell it calls 0x49e700 when 0x49a1d8 is true, otherwise calls an optional generator+0xed4 indirect handler with the same budget. Pass 3 scans the grid again and calls 0x49a932(true) when bit27 is clear and 0x49a1d8 is true. Runtime coordinate/count replay remains pending.",
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
            "clears the temporary object-reference flags before returning",
        ],
        "returns": [
            "positive candidate emission score when accepted by 0x49e700",
            "-1 when no positive terrain-class contribution is found",
            "-5000 when a hard placement/neighbor conflict path is hit",
            "terrain-weight total directly when the total is below -1000",
        ],
        "ghidra_dump": "Focused dump recovers the candidate footprint scan, generated-cell addressing, terrain-class score summation, neighbor object-reference flagging, table adjustments through 0x49b89c, and final score/reject return paths. Exact semantic names for the descriptor score tables and object-reference flag classes remain replay-pending.",
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
        "status": "recovered_static_contract_replay_pending",
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
            "updates relation table counters at generator+0x10e4 when descriptor+0x20 high-byte index is non-negative",
            "clears a low word at an addressed generated/object-side +0x20 word before local projection",
            "builds two local vectors, filters/sorts them through 0x4ae20e/0x4ae23e/0x4cce95/0x430b35, and inserts selected dwords through 0x4ccecb",
        ],
        "ghidra_dump": "Instruction dump recovers the object commit shell: first stamp through 0x49abd6, then append to generator+0xec4 vector, update descriptor counters, and run a direction-table local projection loop over 0x5a2658..0x5a2698. Exact semantic names for the local vectors, relation-table entries, and generated-cell +0x20 low-bit projection remain replay-pending.",
    },
    {
        "address": "0x4a5767",
        "name": "cell_occupancy_reset_and_object_anchor_normalization",
        "status": "recovered_static_contract_replay_pending",
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
        "ghidra_dump": "Called by 0x4a8c15, 0x4a746b, and 0x4ac552. Instruction recovery shows the full-grid reset/normalization pass, the relation-vector scan over generator+0x10e4..+0x10e8, generated-cell owner/bit27/terrain/object-ref gates, and the helper calls into 0x49a932/0x49a318/0x4a5a23. Exact relation-record field semantics and runtime ordered replay remain pending.",
    },
    {
        "address": "0x49a318",
        "name": "object_anchor_owner_projection_helper",
        "status": "ghidra_reference_dumped_replay_pending",
        "ghidra_dump": "Called by 0x4a5767 and 0x4a89da. References show direction-table reads and object-anchor projection paths; exact high-owner/anchor replay remains pending.",
    },
    {
        "address": "0x4a5a23",
        "name": "connection_object_selection_helper",
        "status": "ghidra_reference_dumped_replay_pending",
        "calls": ["0x49eb6d", "0x4a9e40", "0x5044b1", "0x49ba89"],
        "ghidra_dump": "Called by 0x4a5767 and 0x4a61bc. References show allocation/object-selection helpers; exact connection object selection replay remains pending.",
    },
    {
        "address": "0x4a606b",
        "name": "connection_region_generated_cell_writer",
        "status": "recovered_static_contract_replay_pending",
        "calls": ["0x49aa63", "0x49a932"],
        "reads": [
            "generator pointer in ecx",
            "coordinate triple args at stack+0x08/+0x0c/+0x10",
            "low-nibble source/flag arg at stack+0x14",
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
        "ghidra_dump": "Called twice by 0x4a61bc. Static recovery shows a clamped connection-region pass around the provided x/y/level coordinate, object-reference-vector emptiness gating, bit26 writes through 0x49aa63(true), private low-bit flag packing in GeneratedCell+0x2c, and a follow-up projected target cell bit27 write through 0x49a932(true). Exact caller coordinate meanings and runtime ordered replay remain pending.",
    },
    {
        "address": "0x4a746b",
        "name": "connection_endpoint_writer",
        "status": "recovered_static_contract_replay_pending",
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
            "observed stack-local five-entry endpoint offset table at ebp-0x48..ebp-0x20",
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
        "ghidra_dump": "Called twice by 0x4a7605. Static recovery shows the normalize-first endpoint writer: it calls 0x4a5767, derives a source cell from the input coordinate, chooses an endpoint either from source projection fields, one of five local offset records with matching owner/bit27, or fallback (x,y+1,level), calls 0x4a5e73, and on success stamps five endpoint-offset cells through 0x49aa63(true) plus GeneratedCell+0x2c low-bit packing. Caller coordinate meanings, local endpoint offset semantics, and runtime ordered replay remain pending.",
    },
    {
        "address": "0x4a5e73",
        "name": "connection_endpoint_selection_helper",
        "status": "ghidra_reference_dumped_replay_pending",
        "calls": ["0x5044b1", "0x49ba89", "0x4a7312"],
        "ghidra_dump": "Called by 0x4a61bc, 0x4a696b, 0x4a6cf2, and 0x4a746b. References show endpoint selection/allocation helpers; exact endpoint vector replay remains pending.",
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
            "+0xec4": "object record vector anchor observed by 0x4a54a7",
            "+0xecc": "object record vector insertion/end pointer observed by 0x4a54a7",
            "+0xed4": "optional handler pointer used by 0x49eb8d for invalid bit26 candidate cells; vtable slot +0x08 is called with the per-cell budget",
            "+0x10e4": "runtime_zone_relation_vector_begin",
            "+0x10e8": "runtime_zone_relation_vector_end",
            "+0x1110": "descriptor-type counter table indexed by descriptor+0x1c in 0x4a54a7",
            "+0x14b0": "strategic_route_coordinate_vector_begin",
            "+0x14b4": "strategic_route_coordinate_vector_end",
            "+0x14b8": "strategic_route_coordinate_vector_capacity",
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
            "+0x1c": "projection/local word gate forced by 0x4a5767 and thresholded by 0x4a746b",
            "+0x20": "owner/score dword consumed by 0x4a4c8e byte2 owner",
            "+0x24": "terrain/art dword consumed by 0x4a4c8e and 0x49b2b6",
            "+0x28": "generated-cell bit-state dword",
            "+0x2b": "validity byte; bit 0x02 is required by 0x49a1d8 and tested by 0x49e1bf neighbor scans",
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
        "name": "H3MapEdObjectRecord",
        "status": "recovered_static_fields_replay_pending",
        "constructor": "0x49ba89",
        "known_fields": {
            "+0x00": "vtable pointer 0x540a74",
            "+0x04": "object descriptor pointer",
            "+0x08": "initialized to -1 by 0x49ba89; later projection field semantics pending",
            "+0x0c": "initialized to -1 by 0x49ba89; later projection field semantics pending",
            "+0x10": "initialized to -1 by 0x49ba89; later projection field semantics pending",
            "+0x18": "start of record-local dword table filled by 0x49b89c",
            "+0xe4": "cache-built byte checked and set by 0x49b89c",
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


def objdump_probe(path: Path, addresses: list[str], context_bytes: int) -> dict[str, Any]:
    result: dict[str, Any] = {"status": "not_run", "functions": {}}
    try:
        completed = subprocess.run(
            ["objdump", "-Mintel", "-D", str(path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=90,
        )
    except Exception as exc:
        result["status"] = "failed"
        result["error"] = str(exc)
        return result
    result["status"] = "pass" if completed.returncode == 0 else "objdump_nonzero"
    text = completed.stdout
    lines = text.splitlines()
    for address in addresses:
        needle = address.lower().replace("0x", "").lstrip("0") or "0"
        found_index = -1
        for index, line in enumerate(lines):
            if line.strip().lower().startswith(needle + ":"):
                found_index = index
                break
        if found_index < 0:
            result["functions"][address] = {"status": "missing"}
            continue
        excerpt = lines[found_index : found_index + context_bytes]
        result["functions"][address] = {"status": "found", "disassembly_excerpt": excerpt}
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--objdump-context-lines", type=int, default=32)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    exe = args.h3maped_exe.resolve()
    if not exe.exists():
        raise SystemExit(f"missing h3maped.exe: {exe}")
    addresses = [str(record["address"]) for record in FUNCTIONS]
    manifest = {
        "schema_id": "h3maped_rmg_end_to_end_recovery_manifest_v1",
        "h3maped_exe": str(exe),
        "h3maped_sha256": sha256(exe),
        "recovery_policy": "no native behavior edits until trace replay matches H3MapEd private state",
        "functions": FUNCTIONS,
        "structs": STRUCTS,
        "checkpoints": CHECKPOINTS,
        "objdump_probe": objdump_probe(exe, addresses, args.objdump_context_lines),
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_RECOVERY_MANIFEST status=pass functions={len(FUNCTIONS)} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
