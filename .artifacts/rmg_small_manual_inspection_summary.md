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
| strict_small_2p_seed_1 | maps_package:manual-strict-small-2p-seed-1 | h3maped_template_048 | 7 | 2 | 5 | 12 | 12 | 21 | 201 | 44 | 24 | 278 | 60 | 63 | 1 | 0 | ok |
| strict_small_3p_seed_2 | maps_package:manual-strict-small-3p-seed-2 | h3maped_template_027 | 8 | 3 | 5 | 8 | 8 | 28 | 153 | 31 | 16 | 355 | 34 | 37 | 0 | 0 | ok |
| strict_small_4p_seed_3 | maps_package:manual-strict-small-4p-seed-3 | h3maped_template_000 | 8 | 4 | 4 | 4 | 4 | 28 | 76 | 16 | 8 | 624 | 26 | 28 | 1 | 0 | ok |

## strict_small_2p_seed_1

- Package id: `maps_package:manual-strict-small-2p-seed-1`
- Map path: `res://maps/manual-strict_small_2p_seed_1.amap`
- Scenario path: `res://maps/manual-strict_small_2p_seed_1.ascenario`
- Map hash: `validated:h3maped_small:1:h3maped_template_048`
- Scenario id: `manual-strict_small_2p_seed_1`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `63` total, `1` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
.....XXXXX..........XXX.XXXXXXX.....
.....XXXXXXX.......XX..XXXXXXXX.....
.....XXXXXX...........XXXXXXXXX.....
.....XXXXXX...........XXXXX.XX......
......XXXX..$XXX.$G..XXXXX..........
...$M.XXXX..M..XXXM..XXGX...........
......$XXXXX.$===N====M==...........
......M=====MG.=.....$$X====........
A......======BBG===M$GM=====........
..$M...M$.XXXBGB.XXGBB$....=...M...M
...G...G...XXBBB..XMBBBX...=...$.$.$
.XXX...=...XX=X==XXXXBGX...=...XXMGX
XXMXX==T====GB===$M=BG...XX=..$MXXXX
XX$X.=.H....BBB==XXBBB...==NX......$
.....=......=BB==XXBB=...=.=.......M
.....=......=..==....=..==.=.GM....G
..XXG$.....==..=M.XMG==.=X.=BB$XXM$X
XXXXX$=.M..=====N=$$===.=XX=BGBXXXXX
XXXXXX=$G========G$$M=======XBBXXXXX
XXX....=XBBXXX.=.GM.XXX....=X.XXXX.X
XXX....=XBGGXG$MG.$BBXX....=XX......
.......=XBBBXM$$XMXBGBXX...=........
.......==BB====M$$==BB======.....$..
.......=.....BBGM===========.....M..
......HE.X...BGB...X.XXXXXXN.....G.$
........XG..BGBB......XXXXXX........
.$G$$$GX$M..BB.===....XXBBXXX.......
...M..MXX..XXXX..=$....BGBG.X$M...G.
..GG.XXX...XXXX..=.M...BBXMXXX....M.
....M$X...XXXX...N.G....XXXXXX....$.
......XXX.XXXX..........XXXXXX...$..
.......X$XXXX............XXXX....M..
.....M$XMXXXX...MG......XXX$X.......
......XXGXXX..M.$$M.....XXXMXX.G....
....M$X$MXXX.$$.........XXXXXX$M....
.....$XXXXX..M....$M.....XXXXXM$....
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_duskfen | 0,7,12 | 0,7,13 | 0 | 1 | no |
| 2 | enemy | town_veilmourn_bellwake_harbor | 0,7,24 | 0,6,24 | 1 | 1 | no |

### Route Gates

Unguarded links: `0`

| Link | Zone A | Zone B | Guard value | Helper |
| --- | ---: | ---: | ---: | --- |
| h3maped_small_connection_1 | 0 | 1 | 2000 | 0x4a61bc |
| h3maped_small_connection_2 | 0 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_3 | 0 | 6 | 9500 | 0x4a61bc |
| h3maped_small_connection_4 | 1 | 2 | 2000 | 0x4a61bc |
| h3maped_small_connection_5 | 1 | 6 | 9500 | 0x4a61bc |
| h3maped_small_connection_6 | 2 | 3 | 2000 | 0x4a61bc |
| h3maped_small_connection_7 | 2 | 6 | 9500 | 0x4a61bc |
| h3maped_small_connection_8 | 3 | 4 | 2000 | 0x4a61bc |
| h3maped_small_connection_9 | 3 | 6 | 9500 | 0x4a61bc |
| h3maped_small_connection_10 | 4 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_11 | 4 | 6 | 9500 | 0x4a61bc |
| h3maped_small_connection_12 | 5 | 6 | 9500 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 17 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 28 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 33 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 30 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 17 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 15 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 25 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 32 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 29 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 17 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 22 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 31 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 28 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 16 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 12 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 29 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 19 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 18 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 18 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 15 | road_h3maped_small_road_route_06_07 |

## strict_small_3p_seed_2

- Package id: `maps_package:manual-strict-small-3p-seed-2`
- Map path: `res://maps/manual-strict_small_3p_seed_2.amap`
- Scenario path: `res://maps/manual-strict_small_3p_seed_2.ascenario`
- Map hash: `validated:h3maped_small:2:h3maped_template_027`
- Scenario id: `manual-strict_small_3p_seed_2`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `37` total, `0` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
..........XX..........XXXXX.........
XX.........X........XXXXX.X.........
XX.X.......X........XXXXX..X........
X.XX...............XXXXXXXXX........
XXXX.......X....XXXXXXXXXXXX........
XX.X......XX.....XXXX$MXXXXX.$M.....
XXBXX.....XX..M$..$M.XGXXXX....XXXXX
.XGX.X....XXX.......XXMXXXXX....$MXX
.XBXXX......X.$.....XX$XXXXX...X.X..
.XXXXXX.......M...XXXXXXXXXX...MXX..
.XXX.............XXXXXXXXXXX...$....
.X$X......XX.....X.....X.........XXX
........X.XXX....GM....X.==M=$M$$XXX
..M..XBBXX.XXX.===$=======..G.GXMX$B
....==GB==BG===N==========..=.XXXXXG
...X==BBNBBB===BB=========.H=....XXB
...X=====BB====BBB===BEBB=.BTB===XXX
.XXHE====$======BG==BGBGB=BBBGB.=XX.
...XXXXXGMGXXXXXX=XXBBHBB=GB=BBX=X..
...XXXXXX$M$XXXXX================..G
.XXXXXXXXMGXXXX..N======N=======N.$M
.XXXXXXXMGXXXXX.....XXXXX.XXXXX.....
.XXXXXXXX$XXXXX....GM$XXXXXXXXX.....
.....XXXXXXXXXXX....XX.XX$MXXXX.....
....XXM$XXXX..XX....GX...XGXXXX.....
...MXXXXXXXXX..X$...MX..GMXXXXX....G
...$..XXX..XXX..MGXX$X..X$XXXXX....M
...$M.XXX...XXX.XXXXXX...XXXXXGM...$
...MG.XXX....XXXXXXXXX...XXXXXX$....
...$.XXXX.....XX.XXXXG...XXXXXX.....
......XX.......X.XXX$M....XXXXX.....
......XX.........XXXXX....XXX.X.....
......XX..........XXXX.....XG.......
......XX............XX.....$G.X.....
......X.............XX......$XXM$...
$..GM$...............X......MXXG....
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_prismhearth | 0,28,16 | 0,27,15 | 0 | 1 | no |
| 2 | enemy | town_duskfen | 0,4,17 | 0,3,17 | 1 | 1 | yes |
| 3 | enemy | town_riverwatch | 0,22,16 | 0,22,18 | 2 | 1 | yes |

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
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 9 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 9 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 25 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_01_08 | h3maped_small_town_node_01 | h3maped_small_town_node_08 | 16 | road_h3maped_small_road_route_01_08 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 15 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 32 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 24 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 7 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_02_08 | h3maped_small_town_node_02 | h3maped_small_town_node_08 | 17 | road_h3maped_small_road_route_02_08 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 10 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 15 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 7 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 16 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_03_08 | h3maped_small_town_node_03 | h3maped_small_town_node_08 | 10 | road_h3maped_small_road_route_03_08 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 24 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 16 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 9 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_04_08 | h3maped_small_town_node_04 | h3maped_small_town_node_08 | 9 | road_h3maped_small_road_route_04_08 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 9 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 30 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_05_08 | h3maped_small_town_node_05 | h3maped_small_town_node_08 | 16 | road_h3maped_small_road_route_05_08 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 22 | road_h3maped_small_road_route_06_07 |
| h3maped_small_road_route_06_08 | h3maped_small_town_node_06 | h3maped_small_town_node_08 | 8 | road_h3maped_small_road_route_06_08 |
| h3maped_small_road_route_07_08 | h3maped_small_town_node_07 | h3maped_small_town_node_08 | 15 | road_h3maped_small_road_route_07_08 |

## strict_small_4p_seed_3

- Package id: `maps_package:manual-strict-small-4p-seed-3`
- Map path: `res://maps/manual-strict_small_4p_seed_3.amap`
- Scenario path: `res://maps/manual-strict_small_4p_seed_3.ascenario`
- Map hash: `validated:h3maped_small:3:h3maped_template_000`
- Scenario id: `manual-strict_small_4p_seed_3`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `28` total, `1` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
......XXXX..........................
XXXX.XXXXXX...................XXXXXX
XXXX...XXXXX..........XXXXXXXXXXXXXX
........XXXX..XXXXXXXXXXXXXXXXXXXXXX
..G.......$XXXX.....XXXXXXXXXXXX.XX.
.$M...XXXXMXXXXN=====XXXXXXXXXXXX...
XXXX$XX$MXXXXXXX==.==XXXXX.XXXXX....
XXXXMG..XXXXX...==.==..XX.XXXXX.....
X....XXXXXXXX...==X==...XXXXX.......
X.X.XXXX...XXX..===N=X..X$XX........
XXXXXXXX.....XXX==XX=GM$GM..........
XXXXXXXXXXXX....==HX=X$MX...........
XXXXXXXXXXXXM...BE===$XX............
XXXXX.XXXXM$$...BBB.=MXXXXXXX.......
....XXXXXXXXXXBB=BG.=XXXXXX.XX.XX...
......XXXXXX..BGB=..=XXX...XXXXXX..X
...XX.XXX......BT====H......XXXX..X.
.XXXXXX.........==BBBXXXXX.....X....
XXXXX.A......X..=BBGEXXXX$XXX$M.....
.XX......M$X$M..=BGBHXXXXMXXXXXXX$MG
.GM....XXXXXXGX.E=BB....XXXXXXXXX$XX
..$.XXXXXX$MXXXXH==X..XXXXXXXXXXGMX$
.XXXXXXXXXXXXXXXX==X..XXXXXXXXXXXXXX
XXXXXXXXXXXXXX...=NX.XXXXXXXXXXXXXXX
XXXXXXXXXXX......=.......XXXXXXXXXXX
XXXXXXXXXXXX.....=...........XXX...X
XXXXXXXXXXXXXX$XX=XXX......GM.......
XXXXXXXXXXXXXXMXX=XXXXXMGXXX$X....XX
XXXXXXXXXXXXX....=XXXXX$XXXX$XXXXXXX
XXXX.XXXXXXXX....=XXXXXXXXXXXXXXXXXX
XXX.......XX.....=XXXXXXXXXXXXXXXXXX
XXX..............=........XXXXXXXXXX
XXX..$....G......=...............XXX
XXXXGMXXXXMXXXXXXNXXXXXXX$XXXXXXXXXX
XXXXXXXXXX$$MXXXXXXXXXXXXMXXXXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_prismhearth | 0,16,16 | 0,21,16 | 0 | 1 | yes |
| 2 | enemy | town_thornwake_graftroot_caravan | 0,17,12 | 0,18,11 | 1 | 1 | yes |
| 3 | enemy | town_brasshollow_orevein_gantry | 0,20,18 | 0,20,19 | 2 | 6 | yes |
| 4 | enemy | town_thornwake_graftroot_caravan | 0,16,20 | 0,16,21 | 3 | 1 | yes |

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
