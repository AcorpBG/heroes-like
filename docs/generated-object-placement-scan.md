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

## Fixed after the scan (owner go-ahead, slice `ux-generated-site-footprint-dressing-20261008`)

- **Art narrower than the footprint**: blocked tiles of a generated site that its painting leaves bare get a small terrain rock from the scenery's rock-contact palette (`OverworldMapView._draw_resource_flank_rocks`), so they no longer look walkable. The entrance stays clear; an opened route body gets none. Presentation only: occupancy is unchanged.
- **Claimed one-time sites vanished**: a collected site now stays on the map when its map object says `interaction.remains_after_visit` (`OverworldRules.resource_node_is_present`). A looted guarded bank keeps blocking and shows its secured art; an opened route camp stays visible but passable; pickups are still taken. AI heroes clear the tiles a site blocked before their claim when the claim opens or removes it (`AiHeroRules`).

## Readability fixes (owner go-ahead, slice `ux-scenery-pickup-readability-20261008`)

- **Blocked scenery that looked walkable**: at index time each blocked scenery cell's painted coverage is sampled from small alpha masks of the art actually drawn there (its own piece, its formation slice, overlapping formations, edge rocks). A cell painted less than 30% gets a filler from its own family and terrain palette (rocks, bushes, deadwood, reeds; the family's tiny "low" pieces excluded). A cell's own piece is also at least 0.62 tile long. On the owner's map 808 of 6,311 cells get a filler; the art caches and the filler result are session-wide, so returning to the overworld costs about 5 ms (about 0.3 s once per map per launch).
- **Tiny or hidden pickups**: artifacts are drawn at 0.62 of a tile (was 0.42) and loose pickups at 0.66 (was 0.56); pickups draw in the foreground pass with structures and armies, so a neighbouring canopy or rock silhouette no longer hides them; a faint static four-point glint marks every visible pickup.

## Validation

`tests/overworld_scenery_pickup_readability_report.tscn` renders a generated small map with and without scenery and requires every scenery-blocked tile to show art, and places artifacts and caches just above scenery and in open ground and requires each to be visible and at least about half a tile.

`tests/generated_site_footprint_dressing_report.tscn` builds a custom yard on a generated small map with only the affected objects (Bell Spire on grass and snow, Slipgate Mirror, Tide Kiln, Basalt Oath Tomb, sawmill, looted Eyrie and Barrow Vault, opened Railblock Camp, unclaimed Eyrie, taken pickup) and checks presence, blocking, the flank rocks and, with a window, that every blocked tile shows art or a rock.

`tests/overworld_object_footprint_alignment_report.tscn` checks every site of a generated map (grounded on the bottom row, centred on and covering the interaction tile; mines inside their three-by-two art).
