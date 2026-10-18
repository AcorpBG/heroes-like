# Cut-off town repair: a deliberate departure from H3MapEd

Document role: design and validation of an owner-approved departure from H3MapEd
(owner decision, 2026-10-17). This is not a parity fix.
Slice: `native-rmg-cut-off-town-repair-20261017`; template re-pick:
`native-rmg-split-template-repick-20261018` (owner decision, 2026-10-18).
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

## Template re-pick for split link graphs

Some templates cannot be joined by any repair. `0x4a218c` builds the runtime zones and
links and drops every link whose player filter (min/max humans, min/max players) fails.
H3MapEd does not check that the remaining links still join every zone. It does not
reject the template or roll again: the trace shows a single `0x4ac552` selection.
With one human, the catalog has 13 such template and player-count combinations:

- Newcomers, 2-4 players: zones 3, 4, 6 and 10-13 lose all their links (islands that
  hold towns but no start).
- 8XM12, 2 players: zone 2 (a start zone) and zones 28-32; 3 players: zones 28-32;
  4 players: zones 29, 31 and 32.
- 8XM8, 2-8 players: start zone 8 has no link in the template at all.

So `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b`
(`h3maped_rmg_template_catalog.cpp`) checks the runtime links after the roll. If they
leave the runtime zones in more than one group, it takes the next accepted candidate
in vector order (wrapping) whose links join every zone. There is no extra RNG draw,
so the choice is deterministic per seed. If every candidate is split, the rolled
template stays. Only those combinations change; every other seed keeps H3MapEd's
template.

The re-pick is on when the repair is on (`repair_cut_off_towns`) and
`AURELION_RMG_H3MAPED_STRICT` is unset, so the parity paths keep H3MapEd's template.
The repair pass reruns with the same config, so it uses the re-picked template too.

## The repair pass

`run_h3maped_rmg_entry_to_writeout_workflow` (`h3maped_rmg_core.cpp`) runs the H3MapEd
pass, projects the final payload, and counts the towns cut off. If any are, it frees
that result and runs the pass again with `route_join_departure` set. It keeps the
repaired map only when fewer towns are cut off. Otherwise it rebuilds the H3MapEd map,
so a map the steps cannot help stays H3MapEd's. The steps use no
RNG and no retries, so the repaired map is deterministic per seed. The later phases run
unchanged, but the protected cells change which candidates they see, so a repaired map
differs from H3MapEd beyond the carved cells.

0. **Place mines by the game's shape.** In `0x4a9641`, a mine (type 53) is tested by
   the same `0x49a6f9` footprint and `0x49a09c` contour tests, on a copy of its record.
   The copy blocks the H3 body plus the game's three-by-two shape around the visit tile.
   - The contour test rejects a ring that touches another object's action cell (mines
     may not), or that splits into two runs of bad cells.
   - So a mine whose game top row would close a town door, or cut a passage, is
     rejected the way H3MapEd rejects its own bodies.
   - The mine is still stamped with its H3 body, and the rest of `0x4a9911` runs
     unchanged. A smaller candidate set can change which cell a roll picks, so later
     phases see a different map.
1. **Keep link passages (cause 1).** In `0x4a61bc`, a link's passage is its two
   endpoint cells plus the cells the source and target `0x4a5a23` chains stamp. (A
   chain whose start cell has a zero `0x1c` distance word stamps nothing, so the
   endpoint is added on its own.)
   - **Unguarded links:** for guard budget 0 the passage cells are recorded for step 3.
     A border-guard link counts as unguarded: its `0x4a746b` writer gets -1 from
     `0x4a5e73` (stale `+0xf5c` cursor), so H3MapEd never places the border guard.
   - **Every link:** no later object may cover a passage cell with a blocked cell. A
     mine is tested with the game's shape (step 0), a two-level gate pair (`0x4a6cf2`)
     with its H3 body on both levels, and reward objects with their H3 bodies: single
     objects (`0x4a93a2`, `0x4a901a`) and every member of a reward cluster (`0x4aa603`).
     A rejected cell is skipped like any other ineligible candidate.
2. **Join each zone (cause 2).** Right after `0x4aab7e`, per zone:
   - **Route points:** the owner coordinate (anchor) and its `0x404` local-vector cells,
     kept if they are free or action cells and not water or rock; plus every town's
     door (the first action cell left of the town object on its row), as a point of
     the zone that owns that cell.
   - **Components:** points are grouped over cells that are guaranteed walkable: a
     point, or a cell with no object, not water or rock, with bit27 set.
   - **Mines:** every mine (type 53, from `object_records_0xec4_ecc`) blocks the game's
     three-by-two shape (`scripts/core/CommonMineRules.gd`), minus its visit tile. The
     joins treat those cells as occupied, so a join never runs through the row above a
     mine's H3 body.
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
`cut_off_towns_before_repair` and `cut_off_towns_after_repair`, and its
`template_selection_0x4ac552` carries `split_link_graph_repicked` and
`split_link_graph_rolled_template_name`. Generated map packages expose them as
`metadata.cut_off_town_repair` (`applied`, `towns_cut_off_before`,
`towns_cut_off_after`, `split_template_repicked_from`; empty when not re-picked).

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
- **Route joins with the mine shape** (the same 708 configurations; only the 74 flagged
  ones can change):
  - The repair is now kept on 56 of them, and 55 end with no town cut off.
  - 7 maps changed, all for the better:
    - Six now repair fully: small180/m016, m060 and m138, 2026-10-16/m115 and m118,
      and small2p/m091.
    - medium3p/m082 goes from 2 to 0 towns cut off, where before it went from 2 to 1.
  - No other map changed.
- **Mines placed by the game's shape** (the same 74 flagged configurations):
  - The repair is now kept on 67 of them, and 65 end with no town cut off.
  - 12 maps changed, all for the better:
    - Eight of the nine mine-sealed maps now repair: small180/m103, m139 and m155;
      small60/m060; small60_guards/m057; 2026-10-16/m102; small2p/m075; small2p/m103
      (both towns).
    - small2p/m036 goes from 2 to 0 (before, 2 to 1).
    - medium3p/m080, which is cut off under the H3 body check too, goes from 1 to 0.
    - Two of the six-town split maps improve: medium2p/m117 goes from 6 to 4, and
      medium3p/m066 from 6 to 2.
  - No other map changed.
- **Link passages kept clear** (the same 74 flagged configurations):
  - The repair is now kept on 70 of them, and 69 end with no town cut off.
  - 4 maps now repair fully: medium2p/m024 and m079, medium3p/m077 (border-guard links;
    a mine on m024's passage and a two-level gate on m079's), and small180/m014 (a mine
    and decoration on the unguarded 4-1 link's zone-4 endpoint). small180/m057 still
    repairs; it needed the reward-object check, since a dwelling moved onto its 1-4 link
    endpoint.
  - One map got worse: medium2p/m117 keeps H3MapEd's map again (6 cut off; before, 6 to
    4). See Known limits.
  - No other map changed. The sweep stays 64/72 with and without the repair, same rows.
- **Template re-pick** (the same 74 flagged configurations):
  - All 74 now end with no town cut off (before: 70 kept the repair, 69 clean).
  - Five Newcomers maps are re-picked to Dwarven Tunnels: medium2p/m117 (6 cut off on
    Newcomers; 0 on Dwarven Tunnels without the repair), and medium3p/m034, m066, m087
    and m088 (each repairs fully on Dwarven Tunnels).
  - Large m003 (map seed 3507549692, 2 levels, weak, 1+1 players), whose Riverwatch Hold
    sat in 8XM12's unlinked start zone, takes Ring and has no town cut off. H3MapEd's own
    map for it (Windows reference `cut_m003L.h3m`) is identical to the strict native map.
  - The Large selftest seed 73 takes Dwarven Tunnels in place of Newcomers and repairs
    (1 to 0). XL seed 76 takes Ring in place of 8XM12 and has no town cut off.
  - The sweep stays 64/72 with the repair on and with `AURELION_RMG_H3MAPED_STRICT=1`,
    the same rows: no reference map uses a split combination.
- **Strict mode:** with `AURELION_RMG_H3MAPED_STRICT=1`, m043 (seed 2851495868) is
  byte-identical to H3MapEd.
- **Native selftest:** every H3MapEd parity case runs with the repair off and passes.
  Added cases require XL seed 76 to re-pick 8XM12 and end with no town cut off, and
  the repair to join a cut-off town on m095, on m139, where it needs the mine
  placement step, and on m014, where it needs the link endpoint cells.
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
- **Split link graphs (fixed by the template re-pick).** Large seed 73 rolled Newcomers
  and XL seed 76 rolled 8XM12, whose player-filtered links leave zones unjoined. Joins
  inside zones cannot fix that; the re-pick takes another template for those seeds.
  If every candidate for a size and player count were split, the rolled template would
  keep its cut-off towns; no combination in the catalog is like that.
- **Mines below a town door (fixed by step 0).** On 8 maps H3MapEd's town door was a
  one-tile pocket:
  - the town body closes it on three sides;
  - a mine sits two rows below, so the game's top row of the mine covers the three
    tiles under the door.
  - In H3 those tiles are free, because the H3 body is only the mine's bottom row.
  - Example: m139, crystal cavern at (21,11) below the door at (20,9).
  - The repair pass now places those mines elsewhere, and all 8 repair.
- **Six-town split maps (Newcomers, fixed by the template re-pick).** medium2p/m117
  (seed 154192373) and medium3p/m066 left whole islands of zones whose links never join
  the rest. Both now take Dwarven Tunnels and have no town cut off.
- **Cost.** A repaired map is generated twice, and an unhelped one three times.
