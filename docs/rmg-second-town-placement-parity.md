# Second-town placement parity and split large maps

Document role: recovery evidence and the native fix it led to (2026-10-17).
Slice: `native-rmg-second-town-placement-20261017`.
Evidence (ignored storage): `.artifacts/rmg_recovery/support/second_town_placement_20261017/`.

## Question

Some generated Large maps from the AI batches are split into walkable areas that no
route connects. Two cases were traced:

| case | game seed | H3MapEd seed | players | template |
| --- | --- | --- | --- | --- |
| m010 (`ai_batch_20261016_large60`) | `1296852778-p6` | 386602547 | 1 human + 5 computer | Dragons |
| m019 (`ai_batch_20261016_120`) | `3590672926-p3` | 1928029988 | 1 human + 2 computer | Dwarven Tunnels |

Both are Large (108), one level, land, monster strength normal. The H3MapEd seed is
the FNV-1a 31-bit hash of `"h3maped_seed:" + game seed`. The references are Wine
controlled references (`tools/rmg_h3maped_controlled_reference.py`) and, for m019, the
same map from Windows H3MapEd driven by `h3trace`; the two are identical.

## m010: the split is H3MapEd's own map

Native already matched H3MapEd for m010: equal tile bytes and all 2,855 objects. The
map splits into areas of 2,158, 1,357 and 517 tiles in H3MapEd too. The links 14-15
(guard 0) and 16-21 (guard 2000, budget 0) pick passage cells whose neighbours are
later covered by tree obstacles (type 199). Changing this is a product decision, not
a parity fix.

## m019: three native deviations in extra-town placement

In m019, player 3's second town sat at (79,41) with its entrance (77,41) walled in.
H3MapEd puts that town at (77,43). The cause is the `0x4a8db2` -> `0x4a901a` extra-town
path. Each deviation is proved with H3MapEd's private state.

1. **Source cell and 3x3 owner window in `0x4a901a`.** At `0x4a910c..0x4a9131`
   H3MapEd reads the zone owner and score at the anchor minus the descriptor's
   source-cell offset (`+0x2c/+0x30` of the `0x658` wrapper's descriptor: 2,0 for
   towns), not at the anchor. After `0x49aa93` accepts a candidate,
   `0x4a9174..0x4a9232` rejects it unless every cell of the 3x3 window around that
   source cell, clipped to the map, has the zone's owner byte (signed, not negative).
   Native read both values at the anchor and had no window check. Winedbg trace of
   the first call (owner 0): with the fix, the same 122 cells reach `0x49aa93` in
   the same order with the same scores, the same 23 pass, every window flag is 1,
   and the vector has the same two candidates.
2. **Zone record `+0x40` is "towns are of same type".** At `0x4a9027..0x4a906b`,
   `0x4a901a` calls the town-type choice `0x49b3c1` (one `rand()`) only when the
   source pair key is -1, or when the selected index is -1 and record `+0x40` is 0.
   For m019 owner 0 the record has `+0x40` = 1 (entry-argument trace), so H3MapEd
   keeps the caller's key and draws nothing. The flag is the template zone's "towns
   are of same type" column: it is set for Dwarven Tunnels zone 1, and the earlier
   Ready or Not medium seed 10 trace (sources 0-2 set, 3-6 clear) matches that
   template's column exactly. Native left `+0x40` at 0 unless a value was hard-coded,
   so it made one extra draw before the candidate pick.
3. **Only `0x4a93a2` writes the pair's route anchor.** `0x4a93a2`'s success path
   writes source-pair `+0x30..+0x38` and `+0x3c` (`0x4a95a1..0x4a95ae`). The weighted
   commit in `0x4a901a` (`0x4a9325..0x4a937e`) only appends the source cell to
   `0x14b0` and stamps the cell below it. Native also moved the pair's route anchor to
   the second town, so the mine coordinate builder (`0x4a9641`, force-distance
   anchor) and later placements measured from the wrong town. With fixes 1 and 2
   alone, m019's RNG stream already matched, but 74 objects still differed.

## Fix

`src/gdextension/src/h3maped_rmg_core.cpp`:

- `weighted_object_candidate_scan_0x4a901a` samples owner and score at the source
  cell from `descriptor_source_cell_offset_from_secondary_mask_0x4906fb` and applies
  the 3x3 owner window (counted in `source_window_owner_reject_count_0x4a9174`).
- `source_order_scheduler_source_record_from_runtime_zone_0x4a8db2` copies the
  template zone's `same_town_type` into `selector_field_0x40`; recovered per-seed
  values still override.
- The `0x4a8db2` scheduler no longer turns a weighted `0x4a901a` commit into a source
  pair route; only the direct `0x4a93a2` path does.

The selftest's weighted-scheduler case now requires that a weighted commit leaves the
route fields unset; the direct `0x4a93a2` cases still require them.

## Validation

- m019 and m010: native equals the H3MapEd references in tile bytes and every object
  (2,940 and 2,855). m019's four player towns are now in one walkable area.
- The Windows H3MapEd `rand()` log for m019 (122,550 draws) equals native's RNG stream
  draw for draw.
- 72-reference semantic sweep (`windows_h3maped_parity_basis_20261009/tools/semsweep.py`):
  60/72 exact before and after, and no reference got worse. XL Monk's Retreat (3+3,
  seed 1778117359) went from 1,121 differing cells and 5,310 objects to 0 cells and
  the reference's 5,365 objects. Three town subtypes there still differ (Tower and
  Castle where H3MapEd has Necropolis, Fortress and Stronghold). That predates this
  change.
- `h3maped_rmg_core_selftest` passes on Windows and Linux.

## Follow-up: the town type drawn in `0x4a901a` picks the object (2026-10-17)

Slice: `native-rmg-extra-town-type-20261017`.

After the fix above, XL Monk's Retreat (3 human + 3 computer, seed 1778117359)
matched H3MapEd in every tile and object position, but three towns had other
subtypes:

| town | zone owner | native before | H3MapEd |
| --- | --- | --- | --- |
| (78,142) | 6 | 2 Tower | 4 Necropolis |
| (143,142) | 7 | 0 Castle | 7 Fortress |
| (143,73) | 8 | 0 Castle | 6 Stronghold |

They are the second towns of the three treasure zones (template zones 7-9: two
neutral towns each, `+0x40` "same type" clear, all nine types allowed). Native gave
each the type of the zone's first town.

**Source.** `0x4a901a` resolves its town-type key first: with `+0x40` = 0 and
selected index -1 it calls `0x49b3c1` (`0x4a9045`). It then takes the type-98
wrapper from generator `+0x658` at that key (`0x4a9096..0x4a90a4`), keeps it in
`[ebp-0x14]` and builds the new object from it (`0x4a92b1` push, `0x4a92bb` call
`0x49ba89`). The direct branch `0x4a93a2` reads `+0x658` at the same key
(`0x4a93eb..0x4a93f1`). The caller's descriptor never decides the object type.

**Private state.** A winedbg trace of H3MapEd generating that seed under Wine
(`traces/winedbg_xl1778117359_4a901a_town_type*`, script
`tools/server_run_trace_xl.sh`) stops at `0x4a9027`, `0x4a904c`, `0x4a90ae` and
`0x4a92c0`. For owners 6, 7 and 8 the caller passes key 2, 0 and 0. `0x49b3c1`
returns 4, 7 and 6. At `0x4a92c0` the new object's `+0x04` is the `+0x658` wrapper
of that key: `0x01676550` for type 4 (the wrapper owner 2's Necropolis uses),
`0x01676250` for type 7 and `0x01676340` for type 6 (the wrapper of owners 0 and 3,
Stronghold). Each zone's second call draws again (0, 8 and 6) and finds no candidate.

**Native deviation.** `weighted_object_candidate_scan_0x4a901a` and the direct
branch in the `0x4a8db2` scheduler drew the same values (the RNG stream already
matched). But when the caller's join was already resolved, they committed the
object from that join, so the drawn type was lost.

**Fix** (`src/gdextension/src/h3maped_rmg_core.cpp`). When the resolved key differs
from the caller's join, both paths rebuild the join from the `+0x658` bucket entry
of the resolved key (`source_type98_descriptor_bridge_from_bucket_selector_0x658`).
For the direct branch the rebuilt join is local to that call. Calls whose key does
not change, such as same-type zones like m019, are unchanged.

**Validation.**

- XL Monk's Retreat 1778117359 equals the reference: 0 cells and all 5,365 objects.
- 72-reference sweep: 61/72 exact (was 60). Only that row changed
  (`traces/semsweep72_town_type_fix.json`).
- `h3maped_rmg_core_selftest` passes on Windows and Linux.
- `tools/core_suite.py`: 16/16 on Windows and on Linux.

## Open follow-ups (not fixed here)

- The final H3M header differs from H3MapEd in main-town designation and player slot
  6 (m010), and the definition table differs in order and count. Tiles and objects
  are unaffected.
- Fixed separately (`rmg-launch-keeps-guard-strength-20261017`): the size-default launch
  path dropped the guard strength, so the AI match runner's weak and strong maps ran
  as normal.
