# Strict Small RMG Manual Inspection Summary

Scope: `strict_small_36x36_one_level_land_only`

Generated package pairs: `3`

Status: `ok`

Run: `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_small_manual_inspection_export.tscn`

Do not commit `maps/*.amap` or `maps/*.ascenario`.

## Manual Review Gate

Open these package ids in the built-in map picker/editor:

- `maps_package:manual-strict-small-2p-seed-1`
- `maps_package:manual-strict-small-3p-seed-2`
- `maps_package:manual-strict-small-4p-seed-3`

Accept the strict Small-land baseline only if all reviewed packages satisfy:

- each player starts at an owned player town
- zones read as separate playable regions, not one blended area
- roads read as meaningful route infrastructure between towns/zones
- blockers, decorative obstacles, and guards physically gate zone links
- mines, rewards, and artifact-category rewards are reachable through intended guarded routes
- no free unguarded route bypasses a protected zone/town link

Report defects with package id, seed/player count, visible symptom, and the closest tile/region if possible.

## Case Summary

| Case | Package | Template | Zones | Player towns | Neutral towns | Links | Guarded | Roads | Road tiles | Guards | Blockers | Obstacles | Mines | Rewards | Artifact proxies | Artifact objects | Editor |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| strict_small_2p_seed_1 | maps_package:manual-strict-small-2p-seed-1 | h3maped_template_018 | 6 | 2 | 2 | 5 | 5 | 6 | 62 | 6 | 10 | 484 | 17 | 3 | 1 | 0 | ok |
| strict_small_3p_seed_2 | maps_package:manual-strict-small-3p-seed-2 | h3maped_template_027 | 8 | 3 | 1 | 8 | 8 | 6 | 88 | 9 | 16 | 419 | 17 | 3 | 1 | 0 | ok |
| strict_small_4p_seed_3 | maps_package:manual-strict-small-4p-seed-3 | h3maped_template_000 | 8 | 4 | 4 | 4 | 4 | 28 | 76 | 4 | 8 | 656 | 26 | 2 | 1 | 0 | ok |

## strict_small_2p_seed_1

- Package id: `maps_package:manual-strict-small-2p-seed-1`
- Map path: `res://maps/manual-strict_small_2p_seed_1.amap`
- Scenario path: `res://maps/manual-strict_small_2p_seed_1.ascenario`
- Map hash: `validated:h3maped_small:1:h3maped_template_018`
- Scenario id: `manual-strict_small_2p_seed_1`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `3` total, `1` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
.....XXXXXX..X..............XXXXXXXX
.....XXXXXXX...............XXXXXXXXX
.....XXXXXXXX...........XXXXXXXX.XXX
......XXXXXXXX..XX......XXXXXXXXXXXX
.......XXXXXXXXXXX...XXXXXXXXXXXXXXX
........XXXX$XXXXXN====XMXXXX.XXXXXX
....M....XXXXXXXXXB...=.XXXXX..XXXXX
......M...XXXXBGBXG...=.XXXXXX..XXXX
......X.....XXBBBXBX..=..XXXXXX..XXX
......XXX....XXXXX=MXX==XXXXXXXXXXXX
......XX......XXXX=XXXHBGXXXXXXXXXXX
XX.X....M.XXXXXXX.=...BTBXXXXXXXXXXX
XX.XXXXXXXXXXXX...=...BBXXXXX.....XX
...XXX.XXXXX......=====...XXX.....XX
.......XX.........=.==X.....XXXXX...
..................====XXXXXXXXXMXX..
XXMX.............XX=X=XXXMXXXXXXXX..
XXXXXXXXXXMXXXXXX..=.=XXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXX..=.=XXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXX..=.=XXXXXXXXXXXXX$
............XXX.X..=X=...XXXXXXXXXXX
...........XXXX..===X=..XXXXXXXXXX..
...........XXX...=.=BEH.XXXXXX......
...........XX....==BBBX.XM..........
...........XX....=.GBXX.............
...........X.....=XXX...............
....MXX..........=XXXX...X..........
.....XXXXM....B..=XX.XXXXXX.........
.XXXXXXX.....XG..=XBBXXX.X.XX.......
.XXXXX......XXBXX=BGBXXX...XXXX.....
..XXX..M...XXXXX.=BBXXXX.....XXX....
..XXX.XX..XXXXX..N..................
.....XXXXMXXXX......................
....XXXXXXXXX.......................
.A..XXXXXXXX........................
..M.XXXXXX.....M.........M..........
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,23,11 | 0,22,10 | 0 | 1 | no |
| 2 | enemy | town_riverwatch | 0,21,22 | 0,22,22 | 1 | 1 | yes |

### Route Gates

Unguarded links: `0`

| Link | Zone A | Zone B | Guard value | Helper |
| --- | ---: | ---: | ---: | --- |
| h3maped_small_connection_1 | 0 | 3 | 2000 | 0x4a61bc |
| h3maped_small_connection_2 | 1 | 4 | 2000 | 0x4a61bc |
| h3maped_small_connection_3 | 3 | 4 | 2000 | 0x4a7605 |
| h3maped_small_connection_4 | 2 | 4 | 5000 | 0x4a61bc |
| h3maped_small_connection_5 | 5 | 3 | 5000 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 14 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 12 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 27 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 21 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 14 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 30 | road_h3maped_small_road_route_03_04 |

## strict_small_3p_seed_2

- Package id: `maps_package:manual-strict-small-3p-seed-2`
- Map path: `res://maps/manual-strict_small_3p_seed_2.amap`
- Scenario path: `res://maps/manual-strict_small_3p_seed_2.ascenario`
- Map hash: `validated:h3maped_small:2:h3maped_template_027`
- Scenario id: `manual-strict_small_3p_seed_2`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `3` total, `1` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
..........XX........XXXXXXX.........
X.X........X.....XXXXXXXX.X.........
XX.X.......X.....XXXXXXXX...........
X.XX..............XXXXXXXXXX........
XXXX.......X.....XXX.XXXXXXX........
XX.X......XX.XXXXXMXXXXXXXX.........
X$XXX.....XX.XXXXX...XMXXX.....MXX.X
.XXX.X....XXX.XXXX..XXXXXXXX...XXXXM
.XXXXX......X.......MXXXXXXX...XXX..
.XXXXXX...........XXXXXXXXXX...MX...
.XXXXXXX........XXXXXXXXXXXXXXXXX...
.XXXX.XXX.XX.....X.....X...A..XX.XXX
.....XXXX.XXX....X.....X.====...XXXX
.....XGBXX.XXX.===========..=..XXXXX
....==BBB=BB===N=======XXX..=.XXXXXX
...X=XXBBBGBXXXXXBBXXH=XXX.H=XXXXXXX
...X=====BB======BG==BEBB=.BTBXXXXXX
...HE============BB=BGBBG=BGBGBXXXX.
...XXXXXXXXXXXXXXXXXBBXBB=BBXBBXXX..
...XXXXXXMXXXXXXX.XXXXXXXXXXXXXXB...
....XXXXXXXMXXX...XXXXXXXXXXXXXXG...
.....XXXXXXXXXX.XXXXXXXX..XXXXX.B...
.....XXXBXXXXX..XXXXXXXXXX.XXXX.....
.....XXXGXXXXXXX.XXXXX.XXXXXXXX...M.
....MXXXBXXX..X....XXX.XXXXXXXX.....
......XXXXXXX.XX....XX..XXXXMXX.....
......XXX..XXX.....XXX..XXXXXXX.....
.....M.XX...XXX..XXXXX...XXXXXX.....
.....XXXX....XXX.XXXXX...XXXXXX.M...
.....XXXX.....XX....XX...XXXXXX.....
....XXXX.......X....XX....XXXXX.....
......XX............MX....XXX.X.....
..M...XX............XX.....XX.......
......XX............XX.....XM.X.....
......X.............MX......XXX.....
$....................X......XXX.....
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,28,16 | 0,27,15 | 0 | 1 | no |
| 2 | enemy | town_riverwatch | 0,4,17 | 0,3,17 | 1 | 1 | yes |
| 3 | enemy | town_riverwatch | 0,22,16 | 0,21,15 | 2 | 1 | yes |

### Route Gates

Unguarded links: `0`

| Link | Zone A | Zone B | Guard value | Helper |
| --- | ---: | ---: | ---: | --- |
| h3maped_small_connection_1 | 0 | 4 | 2000 | 0x4a61bc |
| h3maped_small_connection_2 | 0 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_3 | 1 | 4 | 2000 | 0x4a7605 |
| h3maped_small_connection_4 | 1 | 6 | 2000 | 0x4a61bc |
| h3maped_small_connection_5 | 2 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_6 | 2 | 7 | 2000 | 0x4a61bc |
| h3maped_small_connection_7 | 3 | 6 | 2000 | 0x4a61bc |
| h3maped_small_connection_8 | 3 | 7 | 2000 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 27 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 10 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 20 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 15 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 10 | road_h3maped_small_road_route_03_04 |

## strict_small_4p_seed_3

- Package id: `maps_package:manual-strict-small-4p-seed-3`
- Map path: `res://maps/manual-strict_small_4p_seed_3.amap`
- Scenario path: `res://maps/manual-strict_small_4p_seed_3.ascenario`
- Map hash: `validated:h3maped_small:3:h3maped_template_000`
- Scenario id: `manual-strict_small_4p_seed_3`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `2` total, `1` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
.......XXXX.........................
XX..X.XXXXX...................XXXXXX
.XX......XX...........XXXXXXXXXXXXXX
XX............XXXXXXXXXXXXXXXXXXXXXX
...........XXXX.....XXXXXXXXXXXX.XX.
......XXXXMXXXXN=====XXXXXXXXXXXX...
XXMXXMXXMXXXXXXX==.==XXXXX.XXXXX....
XXXXXX..XXXXX...==.==.X...XXXXX.....
X....XXXXXXXX...==X==X..XXXXX.......
X.X.XXXXXXXXXX..===N=X..XXXX........
XXXXXXXX.....XXX==XX=XXMXX..........
XXXXXXXXXXXX....==HX=MXXX...........
XXXXXXXXXXXXM...=EBB=MXX............
XXXXXXXXXXXXM...==GBMXXXXX.XXX......
....XXXXXXXXXXXBBBBB=XXXXX..X..XX...
........XXXX...BGB..=XXXX...XXXXXX..
.....XXXXXX.....TBB==H......XXXXX..X
XXX.XXXXX.......=BGB=XXXXX...XXXX...
XXX..XX..M...X..=GBBEHXXXXXXXX...M.A
XXX.......XXXX..=BBBXXXXXXMXXMXXXX..
...$...XXXXXXXX.E=BB....XXXXXXXXXXXX
....XMXXXXXMXXXXH==X..XXXXXXXXXXXXXX
.XXXXXXXXXXXXXXXX==XXXXXXXXXXXXMXXXX
XXXMXXXXXXXXXX...=NXX.XXX.XXXXXXXXXX
XXXXXXXXXXX......=....XXX.XXXXXXXXXX
XXXXXXXXXXXX.....=....XXXXXXXXX...XX
XXXXXXXXXXXXXXXXX=XXX.XXXXXXXM......
XXXXXXXXXXXXXXXXX=XXXXXXXXXXXX....XX
XXXXXXXXXXXXX....=XXXXXXMXXXXXXXXXMX
XXXXXXXXXXXXX....=XXXXXXXXXXXXMXXXXX
XXX..............=XXXXXXXXXXXXXXXXXX
XXX..............=........XXXXXXXXXX
XXX...M..........=...............XXX
XXXXXXXXXMXXXXXXXNXXXXXXXXXXXXXXXXXX
XXXXMXXXXXXXXXXXXXXXXXXXMXXXXXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,16,16 | 0,21,16 | 0 | 1 | yes |
| 2 | enemy | town_riverwatch | 0,17,12 | 0,18,11 | 1 | 1 | yes |
| 3 | enemy | town_riverwatch | 0,20,18 | 0,21,18 | 2 | 1 | yes |
| 4 | enemy | town_riverwatch | 0,16,20 | 0,16,21 | 3 | 1 | yes |

### Route Gates

Unguarded links: `0`

| Link | Zone A | Zone B | Guard value | Helper |
| --- | ---: | ---: | ---: | --- |
| h3maped_small_connection_1 | 0 | 1 | 3500 | 0x4a61bc |
| h3maped_small_connection_2 | 1 | 2 | 3500 | 0x4a61bc |
| h3maped_small_connection_3 | 2 | 3 | 3500 | 0x4a61bc |
| h3maped_small_connection_4 | 3 | 0 | 3500 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 6 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 7 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 5 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 19 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 11 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 13 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_01_08 | h3maped_small_town_node_01 | h3maped_small_town_node_08 | 10 | road_h3maped_small_road_route_01_08 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 10 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 10 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 22 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 6 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 10 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_02_08 | h3maped_small_town_node_02 | h3maped_small_town_node_08 | 13 | road_h3maped_small_road_route_02_08 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 7 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 19 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 11 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 19 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_03_08 | h3maped_small_town_node_03 | h3maped_small_town_node_08 | 10 | road_h3maped_small_road_route_03_08 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 15 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 15 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 17 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_04_08 | h3maped_small_town_node_04 | h3maped_small_town_node_08 | 6 | road_h3maped_small_road_route_04_08 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 27 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 31 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_05_08 | h3maped_small_town_node_05 | h3maped_small_town_node_08 | 12 | road_h3maped_small_road_route_05_08 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 9 | road_h3maped_small_road_route_06_07 |
| h3maped_small_road_route_06_08 | h3maped_small_town_node_06 | h3maped_small_town_node_08 | 18 | road_h3maped_small_road_route_06_08 |
| h3maped_small_road_route_07_08 | h3maped_small_town_node_07 | h3maped_small_town_node_08 | 22 | road_h3maped_small_road_route_07_08 |
