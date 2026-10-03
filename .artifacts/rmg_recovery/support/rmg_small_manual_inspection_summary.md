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
| strict_small_2p_seed_1 | maps_package:manual-strict-small-2p-seed-1 | h3maped_template_048 | 7 | 2 | 5 | 12 | 12 | 21 | 205 | 74 | 24 | 93 | 63 | 46 | 0 | 0 | ok |
| strict_small_3p_seed_2 | maps_package:manual-strict-small-3p-seed-2 | h3maped_template_027 | 8 | 3 | 5 | 8 | 8 | 28 | 253 | 63 | 16 | 90 | 37 | 28 | 0 | 0 | ok |
| strict_small_4p_seed_3 | maps_package:manual-strict-small-4p-seed-3 | h3maped_template_000 | 8 | 4 | 4 | 4 | 4 | 28 | 202 | 50 | 8 | 125 | 31 | 24 | 0 | 0 | ok |

## strict_small_2p_seed_1

- Package id: `maps_package:manual-strict-small-2p-seed-1`
- Map path: `res://maps/manual-strict_small_2p_seed_1.amap`
- Scenario path: `res://maps/manual-strict_small_2p_seed_1.ascenario`
- Map hash: `validated:h3maped_small:1:h3maped_template_048`
- Scenario id: `manual-strict_small_2p_seed_1`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `46` total, `0` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
.................X..............X...
.............XXX....................
................XX..................
..............X.....................
...XX....$....X.......$..XX...G.XX.G
G...XX===MG==GGM==GB=MG...M..$M.X.XX
...M$.===N===G===.BGB=....X.....GG..
......=.....$=M.=..BG=....M.....$...
XXXX..=.....$MX.M...BN==....X......X
..$MGX=...XG.=X.G......=.XX.X.X.XX..
..X.X.=.XMX.G=X.=.....$BB.$MG.XXX...
......=..$BB.=.X$M....MGGBX....XX...
.G....=..BGBX=.GG.....M$BBXX.......G
......=.XBBXX=.BBB===..=.X....X....G
......=....X.=BBBB======G....X.....M
....MG=====..=BG..==XX.=......X..M$$
...==$N....=.=BB..==.X.=............
.G$=........============...M........
.XMG.......M$=====T=====......G...M$
B.M=$MG.....=...BBH=.XX=..$G.X......
GG.=M......$===BBB=$==M=.........M..
G$$G.....GG=.G.GBXGMX.$=======N.....
..G=B.M.BB=.......GG.$BBX.....=..X..
XXM.G$==BGBX...M.X.=..BBB..XB.=..X..
.X$MB....BB.....BB.M..XBGXX.GXM..X..
X.XXX.X...=.....GG.==.....X.G.=$....
X..X.X....=.....BB..==........=M....
.........HE===..X....=........=G.XGM
.............=......$MG..G....=..XX$
.....GM......$.======N==M======..X.X
........G....M.=.......B........X...
.....M.GG....G.=....$..G............
.....$.$M....===..$.MG.BM$.......XXX
.GM....M...$M.....MG.....$.G........
..$......G.G...X.X...M$G.M...M..G...
G...$M....$M.XX.X$MG............M..G
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_duskfen | 0,18,18 | 0,18,19 | 0 | 1 | no |
| 2 | enemy | town_veilmourn_bellwake_harbor | 0,10,27 | 0,9,27 | 1 | 1 | no |

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
| h3maped_small_connection_7 | 2 | 6 | 9500 | 0x4a7605 |
| h3maped_small_connection_8 | 3 | 4 | 2000 | 0x4a61bc |
| h3maped_small_connection_9 | 3 | 6 | 9500 | 0x4a7605 |
| h3maped_small_connection_10 | 4 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_11 | 4 | 6 | 9500 | 0x4a7605 |
| h3maped_small_connection_12 | 5 | 6 | 9500 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 18 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 15 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 16 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 18 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 22 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 15 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 29 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 35 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 29 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 21 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 18 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 30 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 36 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 29 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 23 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 37 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 30 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 17 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 30 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 14 | road_h3maped_small_road_route_06_07 |

## strict_small_3p_seed_2

- Package id: `maps_package:manual-strict-small-3p-seed-2`
- Map path: `res://maps/manual-strict_small_3p_seed_2.amap`
- Scenario path: `res://maps/manual-strict_small_3p_seed_2.ascenario`
- Map hash: `validated:h3maped_small:2:h3maped_template_027`
- Scenario id: `manual-strict_small_3p_seed_2`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `28` total, `0` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
...........................X........
......B.......X.......B..X.XX.......
......G....XXX........G....XX.......
......B.============..BXXX.XX.......
X..G....=...X.G....=G..XX...........
...M$...$M.........N====G=====......
G.......=G$...X......=.$G=...=....MG
...=====NG======.....BG=X=.G.=......
X.X=....G....X=G.....BBB.=...=.G....
X..=........XG===....GBG=====N..X...
...=..........=.===..M.=.=.=........
X..===X......M.=.=.===.=.=BB...X....
...=.=XG.....======GM$===BBB.$X..XX.
...=.=.X.....GB=G..XXX.=.GB=.M.....$
.G.=.========BG=...X...===.=X.$.X..M
...=.=..BB===BBT============..MGX..X
...=.N==BGB..X.H.X.X....===..XXXX.$M
...=....=BG==========G=G===..X....XG
...=$.....=X.X....G.$M..===.....X.XX
.X.=GG....========M======N=.....XX.G
...=.....==X.XXXG..$GXX.=.BGM.G....$
..G=...GG=...XX.M$.M.X..=.GGB.......
.G$.$BB===.X....$...XX..=.=BB.......
XXGM.BGB.=XX....MX.XG...==..XX.....X
.X..G.BB.=......X.X......=..........
...XX....=..........X....=..........
.........=.......X.B.....=..........
........HE===....XXG.....=..$M......
............==...X.B.....=..G.......
.............=..=========EH.........
.G...M......M=..=X.................$
............$==.=................G.M
....$M........=.=XX...........GM$...
...........$GB===X..................
G..$MGGM...M.G..X......$M.........M.
.............B.....$MG....G.......G.
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_prismhearth | 0,15,15 | 0,15,16 | 0 | 1 | yes |
| 2 | enemy | town_duskfen | 0,25,29 | 0,26,29 | 1 | 1 | no |
| 3 | enemy | town_riverwatch | 0,9,27 | 0,8,27 | 2 | 1 | no |

### Route Gates

Unguarded links: `0`

| Link | Zone A | Zone B | Guard value | Helper |
| --- | ---: | ---: | ---: | --- |
| h3maped_small_connection_1 | 0 | 4 | 2000 | 0x4a61bc |
| h3maped_small_connection_2 | 0 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_3 | 1 | 4 | 2000 | 0x4a7605 |
| h3maped_small_connection_4 | 1 | 6 | 2000 | 0x4a61bc |
| h3maped_small_connection_5 | 2 | 5 | 2000 | 0x4a61bc |
| h3maped_small_connection_6 | 2 | 7 | 2000 | 0x4a7605 |
| h3maped_small_connection_7 | 3 | 6 | 2000 | 0x4a61bc |
| h3maped_small_connection_8 | 3 | 7 | 2000 | 0x4a61bc |

### Road Edges

| Road edge | From | To | Cells | Segment |
| --- | --- | --- | ---: | --- |
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 25 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 19 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 21 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 15 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 14 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 15 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_01_08 | h3maped_small_town_node_01 | h3maped_small_town_node_08 | 19 | road_h3maped_small_road_route_01_08 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 27 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 24 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 40 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 33 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 13 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_02_08 | h3maped_small_town_node_02 | h3maped_small_town_node_08 | 31 | road_h3maped_small_road_route_02_08 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 39 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 31 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 17 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 25 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_03_08 | h3maped_small_town_node_03 | h3maped_small_town_node_08 | 37 | road_h3maped_small_road_route_03_08 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 27 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 32 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 15 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_04_08 | h3maped_small_town_node_04 | h3maped_small_town_node_08 | 15 | road_h3maped_small_road_route_04_08 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 17 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 30 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_05_08 | h3maped_small_town_node_05 | h3maped_small_town_node_08 | 18 | road_h3maped_small_road_route_05_08 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 23 | road_h3maped_small_road_route_06_07 |
| h3maped_small_road_route_06_08 | h3maped_small_town_node_06 | h3maped_small_town_node_08 | 30 | road_h3maped_small_road_route_06_08 |
| h3maped_small_road_route_07_08 | h3maped_small_town_node_07 | h3maped_small_town_node_08 | 21 | road_h3maped_small_road_route_07_08 |

## strict_small_4p_seed_3

- Package id: `maps_package:manual-strict-small-4p-seed-3`
- Map path: `res://maps/manual-strict_small_4p_seed_3.amap`
- Scenario path: `res://maps/manual-strict_small_4p_seed_3.ascenario`
- Map hash: `validated:h3maped_small:3:h3maped_template_000`
- Scenario id: `manual-strict_small_4p_seed_3`
- Production scope: `strict_small_36x36_one_level_land_only`
- Editor load: `ok`
- Rewards: `24` total, `0` artifact proxies, `0` literal artifact objects

### Topology Preview

`H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain`

```text
..................XX................
.........X.X....X.X.................
..........X.X.......................
........XX....X.....................
........XX.XX.X.................X...
.....N=====G==.........======N==.X..
........=$X=X=.G.....X.==G..XX.=...M
........=MX=X==========.=G$X.X.=X..G
.G....M$=X.=..==========$=.XX..=....
.....GG.=X=========E=====G....X=X$MX
....$M..=.==..XX..H..=X..M....X=.X..
.......M=.==BBXX....G=...===...=X.X.
...G.....==BGBXXG.M..G.X...=G..=X..G
X........=.BB..X..G.G$M....GM===X.X.
........X=.=...XX.$XX$X.XXXX$.X..X..
........HT========M=GM=.====NXGM....
...........==G========BB=====XX$....
......BB...=.XGX.....=BGB...=.XG....
X...XBBBXXG=M.G......=XBB...=XG.....
X..X.GBXX$M=$.X..X...=XXX.G.=$......
...........=..X.XXX..=XX.X..=M.X....
..X....$M.GMX..X....H=......GXX.....
.X.XX.G.X..==========E=======.......
X.XXXX.....=XXX..XX.....X...=X......
...........=...X.XBB...X....=X......
X..X.......=....XBGB.MGGM...=.......
...........=.....BBMX$.X....=.....G.
...........=.....XX.$.XX....=.......
..........HE===M$===G========......$
..G.................X.XX....N......M
.....GG.....G........X...........G.G
.....$M...........XX.X..........M...
.............G...X....X.............
.............M.....XXG..GM$......$M.
...................XX.............G.
G..M$...............................
```

### Town Starts

| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |
| ---: | --- | --- | --- | --- | ---: | ---: | --- |
| 1 | player | town_prismhearth | 0,9,15 | 0,8,15 | 0 | 1 | no |
| 2 | enemy | town_thornwake_graftroot_caravan | 0,19,9 | 0,18,10 | 1 | 1 | no |
| 3 | enemy | town_brasshollow_orevein_gantry | 0,21,22 | 0,20,21 | 2 | 1 | yes |
| 4 | enemy | town_thornwake_graftroot_caravan | 0,11,28 | 0,10,28 | 3 | 1 | no |

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
| h3maped_small_road_route_01_02 | h3maped_small_town_node_01 | h3maped_small_town_node_02 | 17 | road_h3maped_small_road_route_01_02 |
| h3maped_small_road_route_01_03 | h3maped_small_town_node_01 | h3maped_small_town_node_03 | 20 | road_h3maped_small_road_route_01_03 |
| h3maped_small_road_route_01_04 | h3maped_small_town_node_01 | h3maped_small_town_node_04 | 16 | road_h3maped_small_road_route_01_04 |
| h3maped_small_road_route_01_05 | h3maped_small_town_node_01 | h3maped_small_town_node_05 | 22 | road_h3maped_small_road_route_01_05 |
| h3maped_small_road_route_01_06 | h3maped_small_town_node_01 | h3maped_small_town_node_06 | 34 | road_h3maped_small_road_route_01_06 |
| h3maped_small_road_route_01_07 | h3maped_small_town_node_01 | h3maped_small_town_node_07 | 14 | road_h3maped_small_road_route_01_07 |
| h3maped_small_road_route_01_08 | h3maped_small_town_node_01 | h3maped_small_town_node_08 | 31 | road_h3maped_small_road_route_01_08 |
| h3maped_small_road_route_02_03 | h3maped_small_town_node_02 | h3maped_small_town_node_03 | 16 | road_h3maped_small_road_route_02_03 |
| h3maped_small_road_route_02_04 | h3maped_small_town_node_02 | h3maped_small_town_node_04 | 28 | road_h3maped_small_road_route_02_04 |
| h3maped_small_road_route_02_05 | h3maped_small_town_node_02 | h3maped_small_town_node_05 | 16 | road_h3maped_small_road_route_02_05 |
| h3maped_small_road_route_02_06 | h3maped_small_town_node_02 | h3maped_small_town_node_06 | 30 | road_h3maped_small_road_route_02_06 |
| h3maped_small_road_route_02_07 | h3maped_small_town_node_02 | h3maped_small_town_node_07 | 19 | road_h3maped_small_road_route_02_07 |
| h3maped_small_road_route_02_08 | h3maped_small_town_node_02 | h3maped_small_town_node_08 | 15 | road_h3maped_small_road_route_02_08 |
| h3maped_small_road_route_03_04 | h3maped_small_town_node_03 | h3maped_small_town_node_04 | 17 | road_h3maped_small_road_route_03_04 |
| h3maped_small_road_route_03_05 | h3maped_small_town_node_03 | h3maped_small_town_node_05 | 15 | road_h3maped_small_road_route_03_05 |
| h3maped_small_road_route_03_06 | h3maped_small_town_node_03 | h3maped_small_town_node_06 | 15 | road_h3maped_small_road_route_03_06 |
| h3maped_small_road_route_03_07 | h3maped_small_town_node_03 | h3maped_small_town_node_07 | 34 | road_h3maped_small_road_route_03_07 |
| h3maped_small_road_route_03_08 | h3maped_small_town_node_03 | h3maped_small_town_node_08 | 26 | road_h3maped_small_road_route_03_08 |
| h3maped_small_road_route_04_05 | h3maped_small_town_node_04 | h3maped_small_town_node_05 | 31 | road_h3maped_small_road_route_04_05 |
| h3maped_small_road_route_04_06 | h3maped_small_town_node_04 | h3maped_small_town_node_06 | 19 | road_h3maped_small_road_route_04_06 |
| h3maped_small_road_route_04_07 | h3maped_small_town_node_04 | h3maped_small_town_node_07 | 30 | road_h3maped_small_road_route_04_07 |
| h3maped_small_road_route_04_08 | h3maped_small_town_node_04 | h3maped_small_town_node_08 | 42 | road_h3maped_small_road_route_04_08 |
| h3maped_small_road_route_05_06 | h3maped_small_town_node_05 | h3maped_small_town_node_06 | 15 | road_h3maped_small_road_route_05_06 |
| h3maped_small_road_route_05_07 | h3maped_small_town_node_05 | h3maped_small_town_node_07 | 34 | road_h3maped_small_road_route_05_07 |
| h3maped_small_road_route_05_08 | h3maped_small_town_node_05 | h3maped_small_town_node_08 | 16 | road_h3maped_small_road_route_05_08 |
| h3maped_small_road_route_06_07 | h3maped_small_town_node_06 | h3maped_small_town_node_07 | 48 | road_h3maped_small_road_route_06_07 |
| h3maped_small_road_route_06_08 | h3maped_small_town_node_06 | h3maped_small_town_node_08 | 30 | road_h3maped_small_road_route_06_08 |
| h3maped_small_road_route_07_08 | h3maped_small_town_node_07 | h3maped_small_town_node_08 | 28 | road_h3maped_small_road_route_07_08 |
