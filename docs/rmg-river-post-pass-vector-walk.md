# River post-pass object walk (`0x4ac4ae`)

Slice: `native-rmg-river-post-pass-vector-walk-20261026` (native fix, 2026-10-26).

## Defect

An Extra Large, 8-player, normal-water, two-level map with seed 72136 crashed the game
(access violation, found by Phase 7.11's setup check on 2026-10-23). Under cdb with the
build's PDBs the fault is in `river_object_post_pass_0x4ac4ae`
(`src/gdextension/src/h3maped_rmg_core.cpp`), reading `copied_source_record_carried` through
a stale iterator: the port walked `state.object_records_0xec4_ecc` with a range-for, and
`river_path_writeback_0x4abd5f` -> `river_side_object_commit_0x4abd5f` ->
`object_footprint_commit_4a54a7` appends the river mouth to that vector during the walk. When
the append reallocates, the iterator points into freed memory.

## H3MapEd

`uf 0x4ac4ae` on the reference `h3maped.exe` (cdb; listing in
`.artifacts/rmg_recovery/cdb_4ac4ae_object_loop_disasm_20261026/`):

- `0x4ac4c5` zeroes the index `[ebp-4]`; `0x4ac545` increments it.
- Every pass, `0x4ac4c9..0x4ac4e1` re-reads begin `[ebx+0xec8]` and end `[ebx+0xecc]`, stops when
  begin is null or the index reaches `(end - begin) / 4`, and `0x4ac4e3..0x4ac4e6` loads
  `begin[index]`.

So H3MapEd walks by index and is safe when `0x4abd5f` reallocates the vector, and it visits
the objects appended during the walk (they then meet the type-`0x6d` test like any other).
The port differed in both points.

## Change

The loop walks by index and re-reads `size()` every pass, as `0x4ac4c9..0x4ac548` does. The
record reference is taken per pass and not used after the two writeback calls.

## Checks

- Seed 72136 (8 players, 144x144, two levels, normal water, normal monsters): the old core
  segfaults, the new one writes the map (41,472 cells, 3,601 objects); through the menu's
  functions in Godot the setup and its session start for two factions.
- 72-reference semantic sweep: 64/72 exact, the same rows and cell counts as the last recorded
  sweep; all 72 native payloads byte-identical between the old and new core.
- 90 further configurations (seeded random; every size, one and two levels, land, normal water
  and Islands, 2 to 8 players, the three monster strengths): byte-identical, none failed.
- `h3maped_rmg_core_selftest` and `rules_selftest` pass; six seeds game against the match
  runner (`rules_parity.py check . . --runner-b`) identical; `tools/core_suite.py` 17/17.
- Windows: the map library, `match_sim_cli`, `rmg_native_batch_export_cli` and the core
  selftest are rebuilt.
- Linux (GCC 13.3, the build server, every Linux binary in `bin/` from this source): both
  selftests pass, `tools/core_suite.py` 17/17, and seed 72136 generates and starts, with the
  same scenario id as on Windows.
