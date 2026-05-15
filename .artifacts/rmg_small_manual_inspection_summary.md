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
| strict_small_2p_seed_1 | maps_package:manual-strict-small-2p-seed-1 | h3maped_template_018 | 6 | 2 | 0 | 5 | 5 | 1 | 14 | 6 | 10 | 539 | 17 | 3 | 2 | 0 | ok |
| strict_small_3p_seed_2 | maps_package:manual-strict-small-3p-seed-2 | h3maped_template_027 | 8 | 3 | 0 | 8 | 8 | 3 | 49 | 9 | 16 | 448 | 17 | 3 | 1 | 0 | ok |
| strict_small_4p_seed_3 | maps_package:manual-strict-small-4p-seed-3 | h3maped_template_000 | 8 | 4 | 0 | 4 | 4 | 6 | 25 | 4 | 8 | 690 | 26 | 2 | 2 | 0 | ok |

## strict_small_2p_seed_1

- Package id: `maps_package:manual-strict-small-2p-seed-1`
- Map path: `res://maps/manual-strict_small_2p_seed_1.amap`
- Scenario path: `res://maps/manual-strict_small_2p_seed_1.ascenario`
- Map hash: `validated:h3maped_small:1:h3maped_template_018`
- Scenario id: `manual-strict_small_2p_seed_1`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `3` total, `2` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
.....XXXXXG.XXXXXXX..XX.....XXXXXXXX
.....XXXXXBX.XXXXXXXXXX..XX.XXXXXXXX
.....XXXXXXXX.XXXX....XXXXXXXXXX.XXX
......XXXXXXXX..XXXX...XXXXXXXXXXXXX
.......XXXXXXXXX.XXX.XXXXXXXXXXXXXXX
...A....XXXXXXXXX.XXXXXXXXXXX.XXXXXX
.........XXXXXXXXXX.....XMXXX..XXXXX
......MX..XXXXXBBXX.....XXXXXX..XXXX
........XXXXXXXBGMXX.....XXXXXX..XXX
........X....XXBBXXXXXXXXXXXX.XXXXXX
.....M........XXXXXXXX.BGXXXXXXXXXXX
X.XX......XXXXXXX.X..HBTBXXXXXXXXXXX
.XX..X.XXXMXXXX...X...BBXXXXX.XXXXX.
.......XXXXX......XXX==...XX..XXX...
.......XX.........X.X=X.....X$XXX...
....M.............XXX=XXXXXXXMXXXM..
XXXX.............XXXX=XXXXXXXXXXXX..
XXXMXXXXXXXXXXXXX....=XXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXX....=XXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXX....=XXXXXXXXXXXXXX
..........XXXXX.X..XX=...XXXXXXXXXXX
...........XXXX..XXXX=..XXXXXXXXXX..
...........XXX...X.XHEX.XXXXXX......
......M....XX....XXBBBX.XM..........
...........XX....X.BGBX.............
..........XX.....XXXX...............
...M.....XXX....XXXXXX...X..........
....XXXXXXX...XXXXXX.XXXXXX.........
....XXXX.....XXXXXXBGXXX.X.XXB......
....XXX.....XXXXXXBBBXXX...XXGX.....
..MXXXX....XXXXX..BBXXXX.....BXX....
...XX.XX..XXXXX.....................
.....XXXXMXXXX......................
....XXMXXXXXX.......................
....XXXXXXXX........................
.A..XXXXXX.....M........M...........
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,23,11 | 0,21,11 | 0 | 2 | no |
| 2 | enemy | town_duskfen | 0,21,22 | 0,20,22 | 1 | 1 | yes |

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
..........XX..........XXXXX.........
X.X........X.......XX.XXX.X.........
XX.X............XXXXXXXXX...........
X.XX............XXXXXXXXXXX.........
XXXX.......X..XXXXXXXXXXXXXX........
XX.X......XX..XXXXX.XMXXXXXX........
X$XXX.....XX...XXXX..XXXXX.....M.XXX
.XXX.X....XX...XXX..XXXXXXXX.....XXM
.XXXXX.......XXXXXX.XXXXXXXX..XXXXX.
.XXXXXX....XXXXXXXXXXXXXXXXX.XXMX...
.XXXXXXX.........XXMXXXXXXXX.XXX....
.XXXX.XXX.XXM....X.....X...A.....XXX
....BXXXXBGXX....X.....X........XXXX
....GXGBBBBXXX..XXX...XXX......XXXXX
....BXBBBBXXXX..XXXXXXXXXX..X.XXXXXX
...XXXXBBXXXXBBXXXXXHXXXXX..HXXXXXXX
...X=========BGB=====BEBB=.BTBXXXXXX
...HE=========BB====BBBGB=BGBBBXXXX.
...XXXXXXXXXXXXXXXXXGBXBB=BBXBGXXX..
...XXXXXXMXXXXXXXXXXXXXXXXXXXXXXX...
....XXXXXXXMXXX.XXXXXXXXX.XXXXXX....
.....XXXXXXXXXX..XXXXXXXXXXXXXX.....
.....XXXXXXXXXX....XXXXXXXXXXXX.....
.....XXXXXXXXXXX..XXXX.XXX.XXXX...M.
....M.XXXXXX..XX....XX.....XXXX.....
....XXXXXXXXX.......XX..XX.XMXX.B...
.....XXXX..XXX......XX..XXXXXXX.G...
.....M.XX...XXX...XXXX...X.XXXX.B...
......XXX....XXX..XXXX...XXXXXX.M...
.....XXXX.....XX...XXX...XXXXXX.....
.....XXX.......X....XX....XXXXX.....
......XX............MX....XXX.X.....
..M...XX............XX.....XX.......
......XX............XX.....XM.X.....
......X.............MX......XXX.....
$....................X......XXX.....
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,28,16 | 0,28,15 | 0 | 3 | no |
| 2 | enemy | town_duskfen | 0,4,17 | 0,3,17 | 1 | 1 | yes |
| 3 | enemy | town_prismhearth | 0,22,16 | 0,20,15 | 2 | 1 | yes |

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
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_02_03 |

## strict_small_4p_seed_3

- Package id: `maps_package:manual-strict-small-4p-seed-3`
- Map path: `res://maps/manual-strict_small_4p_seed_3.amap`
- Scenario path: `res://maps/manual-strict_small_4p_seed_3.ascenario`
- Map hash: `validated:h3maped_small:3:h3maped_template_000`
- Scenario id: `manual-strict_small_4p_seed_3`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `2` total, `2` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
......XXX....XX.....................
..XXXXXXX.X...................XXXXXX
X.XXXX................XXXXXXXXXXXXXX
...XX.........XXXXXXXXXXXXXXXXXXXXXX
...........XXXXXXXXXXXXXXXXXXXXX.XX.
......MXXXMXXXXMXXXXXXXXXXXXXXXXX...
XXXMXXXXXXXXXXXXXXXXXXXXXX.XXXXX....
XXXXXX..XXXXX........X....XXXXX.....
X....XXXXXXXX.....X.....XXXXX.......
X.X.XXXX...XXX...XXXXX..XXXX........
XXXXXXXX.....XXXXXXXXXX.MX..........
XXXXXXXXXXXX.....XXHMXXXX...........
XXXXXXXXXXMX....=EB==XXM............
XXXXXXXXXXXXM...=BGBMXXXXXXX........
....XXXXXXXXXXXGB.BB=XXXXXXX..XXXX..
.....XXXXXXX...BBB..=XXXXX.XXX.XXX..
....XXXX........TB===HXXX......XX...
.XXXXXXXX.......=HXBBXXXXX..........
XXX.X..M.....XXX=GBGEXXXMXXXXX.....A
..X....M..XXXXXX=BBBXXXXXXMXXXXXXX..
..A....XXXXMXXXHEXBB....XXXXXXMXXXXX
....XXXXXXXXXXXXXXXXX.XXXXXXXXXXXXXM
.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
XXXMXXXXXXXXXX.....XXX....XXXXXXXXXX
XXXXXXXXXXX............XXX..XXXXXX..
XXXXXXXXXXXX...........XXXXXXX......
XXXXXXXXXXXXXXXXXMXXX..XXXXXXX......
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX......
XXXXXXXXXXXXXXXXXXXXXXXXMXXXMXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
XXX.XX...........XXXXXXXXXXXXXXXXXXM
XXX.....................XXXXXXXXXXXX
XXX..............................XXX
XXXMXXXXMXXXXXXXXMXXXXXXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXMXXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_riverwatch | 0,16,16 | 0,17,17 | 0 | 1 | yes |
| 2 | enemy | town_duskfen | 0,17,12 | 0,19,11 | 1 | 1 | yes |
| 3 | enemy | town_prismhearth | 0,20,18 | 0,21,16 | 2 | 1 | yes |
| 4 | enemy | town_thornwake_graftroot_caravan | 0,16,20 | 0,15,20 | 3 | 1 | yes |

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
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 10 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 10 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 7 | road_h3maped_small_road_route_03_04 |
