# Generated object placement scan (2026-10-08)

Owner request after the Bell Spire report ("I am also noticing it with other objects too"): check every object, not only the reported ones.

## Method

On a copy of the owner's 108x108 generated map (Day 48, single level, fog fully revealed, reduced motion):

- **Objects, one at a time** (1,096): every drawn resource site (411, 87 types), unresolved guard (216), artifact (43), town (16) and one scenery piece per shape (410). For each, the camera centres on it, the area is captured twice (to mask animation), the object is removed, captured again and restored. The pixel difference is exactly that object's drawing, compared with its body (blocked) tiles and interaction tile.
- **Scenery, whole map**: every screen rendered with and without scenery; per-tile scenery coverage compared with the 6,311 scenery-blocked tiles across all 11,664 tiles. (Per-piece removal does not isolate scenery: formations re-compose around a removed piece.)

## Findings

| Area | Result |
| --- | --- |
| Resource sites, before the fix | Sprites anchored at the HoMM3 bottom-right tile: Bell Spire on its right tile, Eyrie one tile right, Smelter Annex beside its only tile; 37 of 519 sites have x/y outside their body. |
| Resource sites, after the fix | Every site's art stands on its bottom row centred on its interaction tile (the art's entrance is its bottom centre, as mines already did). |
| Towns | All 16 correct. |
| Guards | Correct; guard camps draw only a small marker on the site they guard. |
| Artifacts | All on their tiles but drawn very small (handheld scale); 2 hidden under forest or mountain scenery. |
| Scenery | No art far from its blocked tiles. 398 blocked tiles (6%, every terrain) look empty: small or faint single-tile pieces (twigs, shrubs, swamp reeds), gaps inside forest and mountain formations, a few under another object. 37 walkable tiles are more than 60% covered by neighbouring canopy or overhang. |

## Not fixed (owner decision pending)

- **Art narrower than the footprint**: some generated sites block more tiles than their art covers (HoMM3 footprint, smaller proxy art), e.g. Bell Spire (1x1 art, 3 tiles), Slipgate Mirror (1x1 art, 2 tiles), Tide Kiln and Basalt Oath Tomb (art on the entrance, footprint 3-5 wide). Their extra blocked tiles look walkable.
- **Low-visibility blockers and pickups**: the empty-looking scenery tiles, tiny artifact and cache sprites, and the pickups hidden under scenery.
- **Claimed one-time guarded sites vanish** (`OverworldRules.resource_node_is_present`) instead of staying with their secured art and blocking.

## Validation

`tests/overworld_object_footprint_alignment_report.tscn` checks every site of a generated map (grounded on the bottom row, centred on and covering the interaction tile; mines inside their three-by-two art).
