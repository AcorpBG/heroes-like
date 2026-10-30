# Cut-off town repair: a deliberate departure from H3MapEd

Document role: design and validation of an owner-approved departure from H3MapEd
(owner decision, 2026-10-17). This is not a parity fix.
Slice: `native-rmg-cut-off-town-repair-20261017`; template re-pick:
`native-rmg-split-template-repick-20261018` (owner decision, 2026-10-18); monolith partners:
`native-rmg-repair-monolith-partner-20261018` (owner decision, 2026-10-18).
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
The game generates every seat as human or computer (see Player setup below). The
catalog then has five such template and player-count combinations:

- Newcomers, 2-3 players: zones 3, 4, 6 and 10-13 lose all their links (islands that
  hold towns but no start).
- 8XM12, 2 players: zone 2 (a start zone) and zones 28-32; 3 players: zones 28-32;
  4 players: zones 29, 31 and 32.

8XM8 was split for every player count too: start zone 8 had no link. Its links are
now corrected instead (8XM8 link zones, below).

## 8XM8 link zones

In `Rmg.txt` (in `H3bitmap.lod`), six 8XM8 links have the first zones 5.9, 6.3, 6.7,
7.1, 7.5 and 7.9, what looks like a spreadsheet fill of 6, 6, 7, 7, 8, 8: the pairs
every other start zone has. H3MapEd reads them as integers, 5, 6, 6, 7, 7, 7, and so does the recovered
catalog. Start zone 8 gets no link, and zones 5 and 7 get three each. Owner decision,
2026-10-29: use the intended zones. `correct_template_link_zones`
(`h3maped_rmg_template_catalog.cpp`) sets links 10, 12, 14 and 15 of 8XM8 to 6-37,
7-41, 8-47 and 8-48. It runs with the re-pick, so `AURELION_RMG_H3MAPED_STRICT` keeps
H3MapEd's links. The corrected template joins every zone for every player count, so
it is never re-picked.

## Player setup: every seat human or computer

Owner decision, 2026-10-29. `generate_random_map` (`map_generation.cpp`) gives
H3MapEd every seat as "human or computer", each on its own team (setup `+0x34` and
`+0x38` = the player count, `+0x3c` and `+0x40` = 0), the dialog's "Human or
Computer: N, Computer only: 0". This is an H3MapEd setting, not a departure. With one
human and the rest computer only, the template pick also offered Gauntlet, the
one-human challenge template, whose 18 zones outside the starts hold no town: 45 of
the 400 XL games of the 2026-10-29 AI batch had 6 towns on it. It also offered
Dragons, which allows at most two humans. Neither is offered now.
2SM4d(3) still is on single-level XL (6 human starts, no other town).

H3MapEd marks every such seat as able to be human. `runtime_seats` picks the game's
own human seats after projection: the first `human_count` active seats in colour
order, as the setup's slot records number them. The others are computer seats, with
the flags a computer-only seat had.

Each seat is its own team only with the team step as H3MapEd runs it. At
`0x4ace1c..0x4ace37` (`FUN_004ac857`), with no computer players, H3MapEd raises the
human team count to at least 2 (`CMP` with 2, `JL` takes the 2). The port had a
minimum of 2 instead, a path no map took while every game had computer-only seats.
From fe8b88e66 every 3-to-8-player map had two teams, and the 2026-10-30 AI batch
ended 721 of 800 games with allies standing. The port now has the maximum.

So `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b`
(`h3maped_rmg_template_catalog.cpp`) checks the runtime links after the roll. If they
leave the runtime zones in more than one group, it lists the other accepted
candidates whose links join every zone, in vector order, and takes entry
`rng_value % joined_count` (owner decision, 2026-10-18). The same roll value is
reused, so there is no extra RNG draw and the choice is deterministic per seed. Each
joined template gets an even part of the split template's share, instead of all of it
going to the template after it. If every candidate is split, the rolled template
stays. Only those combinations change; every other seed keeps H3MapEd's template.

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
   - **Guarded links:** after `0x4a5e03` places the monster, the passage cells in its
     zone of control (its cell and the 8 around it) and the passage cells that touch
     no other zone are recorded for step 3. A passage cell beside another zone's ground
     outside the zone of control is left to H3MapEd's decoration, so keeping the
     passage free never opens a step around the monster.
   - **Every link:** no later object may cover a passage cell with a blocked cell. A
     mine is tested with the game's shape (step 0), a two-level gate pair (`0x4a6cf2`)
     with its H3 body on both levels, and reward objects with their H3 bodies: single
     objects (`0x4a93a2`, `0x4a901a`) and every member of a reward cluster (`0x4aa603`).
     A rejected cell is skipped like any other ineligible candidate.
   - **Monolith links:** `0x4a7605` places one monolith in each zone of a link through
     `0x4a7312`. When `0x4a7312` finds no cell in a zone, H3MapEd places nothing there
     and the other monolith leads nowhere. In the repair pass the missing end goes to
     the first zone, in the failed zone's `0xc8` endpoint record order, where
     `0x4a7312` finds a cell (the link's own two zones and policy-8 zones are skipped).
     It gets the same connection, so it pairs with the placed end, and the same guard
     rule. `route_join_monolith_partner_count` counts these ends.
2. **Join each zone (cause 2).** Right after `0x4aab7e`, per zone:
   - **Route points:** the owner coordinate (anchor) and its `0x404` local-vector cells,
     kept if they are free or action cells and not water or rock; plus every town's
     door (the first action cell left of the town object on its row), as a point of
     the zone that owns that cell.
   - **Object link ends:** a `0x404` cell on an object's body stands for that object's
     action cells. A monolith end is such a record: `0x4a7605` appends the cell
     `0x4a7312` placed the monolith on. The action cells are the cells of the object's
     eight-by-six footprint that carry its key and bit22 (`0x49abd6` stamps the key on
     body and action cells alike). Without them a monolith is no route point, and a zone
     whose monolith and passage lie apart stays split (XL m566, large m085).
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
object bodies block, action cells are open, and monoliths and two-level gates link
their peers. Water is walkable only where a hero can get a boat on it: a body of water
(8-connected water tiles) with a boat (type 8) on it, or with a shipyard's (type 87)
dock. The dock is the nearest water tile around the shipyard's visit tile and body, in
the order the game picks it (`water_travel_rules_ai.cpp`, `dock_tile`). The game has no
other way onto water, so other water blocks (XL m475). A mine (type 53) blocks the
game's three-by-two shape around its visit tile (`scripts/core/CommonMineRules.gd`) in
place of its H3 body. Rare mines do too: the game's movement index
(`overworld_rules::_build_blocked_tile_index`) gives that shape to every resource node
whose `mine_rules::resource` is set, and that counts a rare site's `rare_mine_resource`
(m231). It returns the number of towns outside the area that holds the most towns.

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
  - Five Newcomers maps are re-picked, each to a different template: medium2p/m117 to
    5SB0a, medium3p/m034 to 2SM2h(2), m066 to Ring and m088 to 8MM0e, all with no town
    cut off; medium3p/m087 (normal water) to South of Hell, which the repair joins (1
    to 0).
  - Large m003 (map seed 3507549692, 2 levels, weak, 1+1 players), whose Riverwatch Hold
    sat in 8XM12's unlinked start zone, takes Meeting in Muzgob, which the repair joins
    (3 to 0). H3MapEd's own map for it (Windows reference `cut_m003L.h3m`) is identical
    to the strict native map.
  - The Large selftest seed 73 takes Meeting in Muzgob in place of Newcomers, and XL
    seed 76 takes 6LM10 in place of 8XM12; neither has a town cut off.
  - The first version took the next candidate in vector order. It also left all 74
    clean, but sent all five Newcomers maps to Dwarven Tunnels.
  - The sweep stays 64/72 with the repair on and with `AURELION_RMG_H3MAPED_STRICT=1`,
    the same rows: no reference map uses a split combination.
- **Monolith partners** (the same 74 flagged configurations): all 74 still end with no
  town cut off. Four repaired maps change because a monolith end now gets a partner:
  small180/m057, m060 (three partners), m139 and 2026-10-16/m077. The sweep stays
  64/72 with and without the repair, same rows.
- **Guarded passages** (the same 74 flagged configurations): all 74 still end with no
  town cut off. Eight repaired maps change (small2p/m103, medium2p/m026, m042, m082,
  m083, medium3p/m035, m080, m087). On none of them does a kept passage cell open a
  zone border outside a monster's zone of control. m103 and m026 each lose one such
  border. medium3p/m035 gains one beside its 4-11 guard, at (38,52) on level 1, where
  the reshuffled decoration left a cell open that the earlier repair had covered (see
  Known limits). The sweep stays 64/72 with and without the repair, same rows.
- **Monolith ends and water without boats** (`native-rmg-repair-monolith-doors-boatless-water-20261028`):
  - Checked on all 1,200 maps of the 2026-10-28 mixed batch: every size, one and two
    levels, land and normal water, normal and strong guards. Each map was generated
    and played for one day, before and after the change.
  - Before, 4 maps ended with towns cut off (15 towns): m085, m231, m475 and m566.
    After, none.
  - The repair now runs on 158 maps, one more than before (m475). No map ends with
    more towns cut off.
  - m231's H3MapEd map is cut off in the game: its towns are flagged for a rare mine's
    shape, which the game blocks too (see the next entry).
- **Rare mines keep the game's shape** (`native-rmg-repair-rare-mine-game-shape-20261028`).
  c7d831eae gave the three-by-two shape only to wood, ore and gold mines, on the belief
  that the game blocks rare mines by their H3 body. It does not (see Town check), and
  m231 of the 1,200-game batch stalled to the day cap: its salt pan at (51,62), a rare
  mine, walls the only way to the gate at (53,50) and the last player's towns. The
  rule is reverted; c7d831eae's `0x4ab6ac` exit stays (`docs/overworld-rivers.md`).
  - The same 1,200 maps, generated and played one day: the check flags 158 maps (392
    towns cut off on H3MapEd's maps), and all 158 repair to none. The 12 that kept
    H3MapEd's map under c7d831eae repair again (m231 and m647 from 4 and 3 towns, the
    rest from 1). Small m1017, whose repair pass reached the empty river search, and XL
    m1034 repair to none. No repair pass fails.
  - m231 replayed with its batch seed ends on day 82, won by player 2.
  - The 72-reference sweep stays 64/72 with the repair on, the same rows.
- **Strict mode:** with `AURELION_RMG_H3MAPED_STRICT=1`, m043 (seed 2851495868) is
  byte-identical to H3MapEd.
- **Native selftest:** every H3MapEd parity case runs with the repair off and passes.
  Added cases require XL seed 76 to re-pick 8XM12 and end with no town cut off, and
  the repair to join a cut-off town on m095, on m139, where it needs the mine
  placement step, on m014, where it needs the link endpoint cells, on r23 m003,
  where it needs the monolith partner, and on r4 m030, where it needs the guarded
  passage kept free.
- **Core test:** every map `random_map_small_2p_launch_report` generates must end with no
  town cut off. The seeds that need the repair are covered by the native selftest above,
  not by a core test (owner decision, 2026-10-19: core tests carry no fix-specific cases).

## r23 m003: a monolith with no partner seals a start town

AI match m003 of the 2026-10-18 medium 2-player batch (map seed 3541848141, match
ai-match-1205901623; medium, one level, land, weak guards, template 8SM0c) ran 320 days
without either player reaching the other: Veilmourn's Bellwake Harbor (52,14) sits in
zone 0, a 508-cell area (x 32-71, y 0-30) walled off by rock and decoration.

- **Cause:** zone 0's only link is 0-8, and zones 0 and 8 do not touch, so the link is
  a two-way monolith pair from `0x4a7605`. Zone 8 is the bottom map row plus three
  cells. `0x4a7312` rejects every one of them for the 2x2 monolith (`0x49aa93`
  contour test), so H3MapEd places only zone 0's monolith at (46,3). The 8-9 and 8-11
  links lose their zone-8 ends the same way.
- **H3MapEd:** its own Windows map for this seed equals the strict native map (tiles and
  all 1236 objects) and seals both start towns. The repair joined Riverwatch Hold but
  had no passage to keep for zone 0 (1 town still cut off).
- **Fix:** the repair pass places the three missing ends: 0-8's in zone 4 at (39,60),
  8-9's and 8-11's in zone 0 at (37,6) and (51,16). The map now has no town cut off
  (`towns_cut_off_before` 2, `towns_cut_off_after` 0).

## r4 m030: decoration closes the only guarded north-south link

AI match m030 of the 2026-10-18 large 2-player batch (map seed 4202563664; large, two
levels, land, strong guards, template Dragons, 1+1 players) left 7 towns cut off on
H3MapEd's map, which equals the strict native map (3692 objects).

- **Cause:** the repair joined the zones but its map was discarded. The only link
  between the north half (zones 0-13) and the south is 12-14, guarded at (55,79) on
  level 0 (8000). The repair pass kept only unguarded passages free, and its
  decoration (AVLPNTR2) covered (54-56, 80-81), the passage just south of the monster.
- **Fix:** a guarded link's passage is kept free inside the monster's zone of control
  and where it touches no other zone (step 1). m030 now repairs from 7 to 0, and the
  12-14 monster still stands between the two halves.

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

## m566 and m085: a monolith end is no route point

Two capped games of the 2026-10-28 mixed batch (1,200 games) walled a player off on a
repaired map:

- XL m566 (map seed 2165370044-p6, native seed 2129850540; one level, land, normal guards).
- Large m085 (map seed 1099990833-p4, native seed 101529017; one level, land, normal
  guards).

H3MapEd's maps cut off 6 towns each. The repair kept its maps with 3 and 5 still cut off.

- **m566:** Sunvault's start and two neutral towns sit in zones 30-32, a 750-tile area.
  Its only way out is through zone 29: the unguarded 29-30 passage enters zone 29, and
  zone 29's only other link is the 27-29 monolith pair. The passage cells and the
  monolith end at (56,1) lie in two parts of zone 29, two blocked tiles apart.
- **m085:** zones 21-32 hold 5 towns. Their only way out is the unguarded 16-21 passage
  into zone 21. Zone 21's monolith end of the 21-23 pair lies in another part of zone 21.
- **Cause:** `0x4a7605` records a monolith end in its zone's `0x404` vector at the cell
  `0x4a7312` placed the object on, which is a body cell. The join step dropped it, so a
  zone with a passage and a monolith joined only the passage to its anchor.
- **Fix:** such a record stands for the object's action cells (step 2, object link
  ends). Both maps now end with no town cut off (6 to 0).

## m475: a lake with no boat

XL m475 (map seed 3749470550-p6, native seed 1103082712; two levels, land, normal
guards) kept H3MapEd's map, yet players 2 and 4 could never be reached.

- **Cause:** their zones 1, 3, 9 and 15 join the rest only through zone 19, whose
  monolith ends H3MapEd could not place. The surface between them is a 402-tile lake.
  It touches the main area at one tile and holds no boat, and no shipyard docks on it.
  The town check walked across the water, so it counted no town cut off and the repair
  never ran.
- **Fix:** the check lets a hero onto water only where a boat or a shipyard dock is.
  m475 now counts 3 towns cut off; the repair pass places the missing monolith ends and
  ends with none.

## Known limits

- **Guard bypass on m043** (seed 2851495868, strong). Zone 4's anchor fragment can only
  be reached through zone 2. The cross-zone join therefore opens a walk around the
  strong 2-4 connection guard (9250).
- **m174** (seed 767626670) has 6 zone pairs a hero can walk between without passing a
  monster's zone of control and without an unguarded link. H3MapEd's own map had 12.
  These come from the reshuffled decoration, not from carved paths.
- **Decoration gaps beside a guard.** The repair pass reshuffles H3MapEd's decoration,
  which can leave a cell open beside a monster's zone of control that H3MapEd's own
  run happened to cover. medium3p/m035 (seed 220966679) gains one such step around
  its 4-11 guard at (38,52) on level 1. The kept passages do not cause these.
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
  the rest. They now take 5SB0a and Ring and have no town cut off.
- **Cost.** A repaired map is generated twice, and an unhelped one three times.
