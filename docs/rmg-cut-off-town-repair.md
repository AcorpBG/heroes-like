# Cut-off town repair: a deliberate departure from H3MapEd

Document role: design and validation of an owner-approved departure from H3MapEd
(owner decision, 2026-10-17). This is not a parity fix.
Slice: `native-rmg-cut-off-town-repair-20261017`.
Evidence (outside the repo): the shared notes of session `local_a8c2da62`,
`zero_guard_passage_prototype/` (`remaining_splits_trace.md`, `all_three_causes_measurement.md`).

## Problem

Native RMG reproduces H3MapEd, and H3MapEd itself sometimes makes a map where a town
cannot be reached on foot from the others. In the 344 configurations of the
2026-10-16/17 AI batches, 19 maps had a town cut off. All 19 are H3MapEd's own
behaviour, not native drift: m003 (seed 1727041229) and m010 were traced to identical
Windows H3MapEd maps (`docs/rmg-second-town-placement-parity.md`).

The traces found three causes:

1. **Unguarded link passages get decorated.** `0x4a61bc` stamps a link's passage cells
   with bit27 through the `0x4a5a23` chain. A zone's `0x4aab7e` reward/guard pass
   (the `0x4aa3e9` wrapper commit) can clear bit27 again and set bit26. `0x49eb8d`
   decoration then places obstacles over the passage. A link with a guard keeps its
   monster on the passage. A link without one (guard budget 0, typical at weak
   strength) is simply closed.
2. **Zone route points are not joined.** H3MapEd keeps no network of protected cells
   inside a zone. The anchor, each link's passage cells and the town door are usually
   walkable only because decoration happens to leave gaps between them. A town door at
   a zone border that `0x4a4c8e` reopened is often not joined to the zone at all.
3. **The underground repaint closes passages.** `0x4a7ecc` paints rock on every level-1
   cell that has bit25 but neither bit27 nor bit22. A passage that lost bit27 in cause 1
   becomes rock.

## Decision

The generator keeps H3MapEd's map unless the finished map leaves a town cut off. Only
then does it generate the same seed again with three extra steps on. This keeps
H3MapEd parity on every map that already works and repairs only the broken ones.

`AURELION_RMG_H3MAPED_STRICT=1` turns the repair off for parity work. The
controlled-case parity tools (`rmg_native_core` controlled cases and the batch export
CLI) always run without it, because they compare against H3MapEd references.

## The repair pass

`run_h3maped_rmg_entry_to_writeout_workflow` (`h3maped_rmg_core.cpp`) runs the H3MapEd
pass, projects the final payload, and counts the towns cut off. If any are, it frees
that result and runs the pass again with `route_join_departure` set. It keeps the
repaired map only when fewer towns are cut off. Otherwise it rebuilds the H3MapEd map,
so a map the steps cannot help stays H3MapEd's. The steps use no
RNG and no retries, so the repaired map is deterministic per seed. The later phases run
unchanged, but the protected cells change which candidates they see, so a repaired map
differs from H3MapEd beyond the carved cells.

1. **Keep unguarded passages (cause 1).** In `0x4a61bc`, for a link with guard budget
   0 that is not a border guard, the cells the source and target `0x4a5a23` chains
   stamp are recorded.
2. **Join each zone (cause 2).** Right after `0x4aab7e`, per zone:
   - **Route points:** the owner coordinate (anchor) and its `0x404` local-vector cells,
     kept if they are free or action cells and not water or rock; plus every town's
     door (the first action cell left of the town object on its row), as a point of
     the zone that owns that cell.
   - **Components:** points are grouped over cells that are guaranteed walkable: a
     point, or a cell with no object, not water or rock, with bit27 set.
   - **Join:** each other component is joined to the one holding the most points by
     the cheapest path. Cells already walkable cost 0, free cells of the zone cost 1.
     If no path exists inside the zone, a second pass may cross other zones' free
     cells at cost 4. Path cells get bit27 with bit26 cleared.
3. **Protect early and late (cause 3, and cause 1 again).** All recorded cells are
   restamped with bit27 (bit26 cleared) right after `0x4aab7e`, before the `0x4a7ecc`
   repaint, and again before `0x49eb8d` decoration.

The map then goes through the normal remaining phases and writeout.

**Town check** (`cut_off_town_count_departure`), on the runtime projection: rock and
object bodies block, water is walkable, action cells are open, and monoliths and
two-level gates link their peers. A mine (type 53) blocks the game's three-by-two shape
around its visit tile (`scripts/core/CommonMineRules.gd`) in place of its H3 body. It
returns the number of towns outside the area that holds the most towns.

**Reported state:** `H3MapedRmgWorkflowResult` carries `cut_off_town_repair_applied`,
`cut_off_towns_before_repair` and `cut_off_towns_after_repair`. Generated map packages
expose them as `metadata.cut_off_town_repair` (`applied`, `towns_cut_off_before`,
`towns_cut_off_after`).

## Validation

- **72-reference sweep** (`windows_h3maped_parity_basis_20261009/tools/semsweep.py`):
  64 of 72 exact before and after, the same rows. No reference map has a town cut off
  on land, so none of them is regenerated. This still holds with the mine shape, with
  the repair on and with `AURELION_RMG_H3MAPED_STRICT=1`.
- **AI-batch configurations** (344 parse; 4 do not parse in either mode). The batch
  script counts towns as the native check does, except that it links every
  subterranean gate to every other one, so it is more lenient on two-level maps.
  - 19 had a town cut off with H3MapEd; 0 do with the repair.
  - Exactly those 19 maps change. The other 325 are byte-identical to H3MapEd.
  - Each repaired map is byte-identical to the scratch prototype that was measured
    before implementation.
- **With the mine shape** (708 configurations: the 344 above and the three 120-game
  batches of 2026-10-17, all generated with the workflow's own check):
  - 74 have a town cut off on H3MapEd's map. 57 of them were cut off under the old
    check too; 17 only because of mine shapes.
  - The repair is kept on 50 of them, and 48 end with no town cut off.
  - Of the first 344, 32 are now flagged and 20 repaired. 18 of the old 19 still
    repair; small180/m060 keeps H3MapEd's map.
  - Of the 17 maps flagged only for mines, 3 are repaired (m095, small60/m049,
    2026-10-16/m101). The other 14 keep H3MapEd's map.
- **Strict mode:** with `AURELION_RMG_H3MAPED_STRICT=1`, m043 (seed 2851495868) is
  byte-identical to H3MapEd.
- **Native selftest:** every H3MapEd parity case runs with the repair off and passes.
  Added cases require the repair to join a cut-off town on XL seed 76 and on m095.
- **Core test:** `random_map_small_2p_launch_report` generates seed 1727041229 (Small,
  land, weak, 1+1 players). It requires the repair to have run and to leave no town cut
  off. Every other seed it generates must also end with no town cut off.

## m095: mines seal a start town

AI match m095 (2026-10-17 medium 3-player batch; map seed `4228448339-p3`, native seed
684022622; medium, two levels, normal water, strong guards) reported no town cut off,
yet player 3's start town at (60,24,0) could not be left on foot.

- **Cause:** the game draws every mine as three by two tiles with the visit tile at the
  bottom middle and blocks that shape in place of the H3 body. So it also blocks the
  row above the H3 body, and leaves open any H3 body cell outside the shape (the
  sawmill's fourth column). Two mines matter here: the crystal cavern at (64,12)
  blocks (62,11) and (63,11), and the sawmill at (70,20) blocks (68,19). Those were the
  pocket's only exits towards the subterranean gate at (69,2,0). The check used the H3
  bodies, so it walked through them.
- **Fix:** the check blocks the same three-by-two shape in place of the H3 body. m095
  now reports one town cut off, and the repair joins it (`towns_cut_off_before` 1,
  `towns_cut_off_after` 0). The repaired map keeps the eight towns where they were.

## Known limits

- **Guard bypass on m043** (seed 2851495868, strong). Zone 4's anchor fragment can only
  be reached through zone 2. The cross-zone join therefore opens a walk around the
  strong 2-4 connection guard (9250).
- **m174** (seed 767626670) has 6 zone pairs a hero can walk between without passing a
  monster's zone of control and without an unguarded link. H3MapEd's own map had 12.
  These come from the reshuffled decoration, not from carved paths.
- **Split link graphs.** On the Large two-level selftest map (seed 73, weak, 1+1
  players), H3MapEd's own links never join zones 2 and 12, or zones 3, 9 and 11, to the
  rest. Joins inside zones cannot fix that, so the generator keeps H3MapEd's map and
  reports `towns_cut_off_before` = `towns_cut_off_after` with `applied` false. On the XL
  two-level selftest map (seed 76) H3MapEd leaves two towns cut off. The repair joins
  one, and keeps the other in zones 15-19, which H3MapEd's links never join to the rest.
  Whether the template's link data or a missing gate link is the cause has not been
  traced.
- **Mine-sealed towns.** The route joins work on the generator grid, which knows only a
  mine's H3 body, not the row above it that the game also blocks. So the repair can
  leave a town sealed by a mine. 14 of the maps flagged only for mines keep H3MapEd's
  map, and so do 5 maps that were cut off under the old check too: small180/m060,
  medium2p/m024 and m079, medium3p/m077 and m080. This has not been traced map by map.
- **Cost.** A repaired map is generated twice, and an unhelped one three times.
