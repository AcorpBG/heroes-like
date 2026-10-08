# Portal networks

Owner direction, 2026-10-08: on a Large random map every portal looked the same, the three HoMM3 portal kinds behaved differently, and one network had four ends. Portals must read at a glance, travel like HoMM3, and a generator quirk must not merge or strand networks.

## What the player sees

HoMM3 Monoliths become three original sites, told apart by shape:

| HoMM3 type | Site | Shape | Stepping on it |
| --- | --- | --- | --- |
| Monolith Two Way (45) | Wayring | upright stone ring | travels to another Wayring of its network; back the same way |
| Monolith One Way Entrance (43) | Waygate | tall pointed archway | travels to a Wayfall of its network; there is no way back |
| Monolith One Way Exit (44) | Wayfall | low dais under a falling beam | arrival only; it cannot be entered |

Every end of one network glows in the same colour, and every network on the map has its own: two-way networks take the first slots, then one-way networks, each in network order (`NativeTransitRules.assign_network_colours`, 16 colours in `NETWORK_COLOURS`, ordered so a map's first networks get the most different hues; past 16 the colours repeat and the shape still tells the kinds apart). A Waygate leads to the Wayfalls of its own colour. Hover text and travel messages use the coloured name ("Azure Wayring") and say where the portal can take you; exits on tiles the player has not explored are counted but not located. The context action reads Step Through, or Inspect on a Wayfall.

Portals draw at landmark size on their one-tile footprint. Subterranean gates keep the Basalt Undergate art.

The sprites are bare stonework: a dark empty opening inside the Wayring's ring and the Waygate's arch, open air above the Wayfall's dais. The magic is the original painting's light, cut into effect layers (the swirl in the opening and the light it spilled on the plinth; the beam and its splash) that `scenes/overworld/OverworldPortalFx.gd` tints with the network colour and moves gently: a Wayring's painted swirl turns slowly inside its ring (squashed to a circle, rotated, stretched back, so the disc stays in place), a Waygate's vortex stays put while fainter copies of it keep shrinking into its centre, and a Wayfall's beam is drawn as light: its white-hot core takes solid colour while the wide haze and fainter copies sliding toward the dais are added as light, so a colour far from the ground's (blue on desert) never reads as a solid pillar; its splash ripples outward. A handful of slow sparks glint on top. Everything is a pure function of time and the portal, so nothing is simulated or saved; the layer is a child of the object layer, so camera pans keep it on the art. The painted light blends normally so the colour stays true on any ground, and the sparks add light on a child layer above it. The layer redraws at 30 fps only while a visible portal is on screen. Portals remembered under fog, and every portal under reduced motion, show one still frame, so the network colour still reads. The layers and their positions are listed in `art/overworld/portal_network_fx.json`, which the sprite packer writes.

## Travel

- A portal with one exit always uses it. A portal with several sends the traveller to a random one, as in HoMM3. There is no destination menu.
- The roll is a stable hash of the portal, the day, the traveller and that traveller's trip count (`overworld.native_transit_trips`), so reloading replays a trip and the next trip can land elsewhere. An exit that is blocked right now is skipped for the next exit in roll order; a hostile army on an exit is fought, as before.
- Walking onto a portal includes the trip. Stepping through while already standing on it costs one movement.
- Legacy raids roll the same way. AI heroes still do not use portals (`docs/ai-plays-by-player-rules.md`, known gaps).

## Networks follow placed connections

The native generator reproduces two H3MapEd behaviours that turned into confusing networks. Both are in the original machine code (`.artifacts/rmg_recovery/ghidra_bit21_candidate_helpers_20260710a/target_004a79a3_FUN_004a79a3.txt`, `.artifacts/rmg_recovery/ghidra_private_state_dump/target_0049b3fb_FUN_0049b3fb.txt`), so generation is not changed:

- `0x4a79a3` turns every template connection it cannot build as a land passage into a portal connection (`0x4a7605`). The portal type comes from a cursor that cycles through the 8 two-way and then the 8 one-way descriptor lanes: `0x4a7e5b..0x4a7e64` computes `(cursor + 1) mod (two-way count + one-way count)`. A 17th portal connection reuses two-way colour 0.
- `0x49b3fb` returns the first relation record whose target matches and never checks the processed byte `+0x0a`. A template link from a zone to itself, or a second link between the same two zones, leaves one record open, and it later becomes another portal connection. Template 6LM10 links zone 13 to itself, which produced two one-way networks whose eight ends all stand in that one small zone.

Each `0x4a7605` call places one connection: a two-way connection puts one end in each zone, a one-way connection an entrance and an exit in each zone. The generator now records, outside any generation state it reads, which call committed each portal end and in which relation-owner zone (`monolith_connection_end_by_object_key_4a7605`). The runtime package exports this on every portal's `native_transit` sidecar: `connection_index`, `network_index` (numbered per kind in placement order), `zone`, `connection_zones` and `same_zone`, with `group_id` per connection. The H3M payload, map hash and object records are byte-identical.

The game then:

- treats each connection as its own network, so a reused colour is a separate network with its own colour;
- leaves off every network whose connection joins a zone to itself (`NativeTransitRules.is_dead_end`). Its portals never take a traveller anywhere new. Their tiles become free ground; the guards the generator placed next to them stay as ordinary guards.

Packages without the bookkeeping (older maps, replayed authority sequences) keep the colour grouping.

## Saves

`overworld.generated_transit_translation_version` 2 gives existing portals their per-kind site and drops dead-end networks when the package records them. Saves already at version 1 only revisit their portals; gates, shipyards and boats stay as they are. The old destination-choice credit (`native_transit_pending_arrival`) is cleared. Maps generated before this change lack connection data, so their networks keep the colour grouping (a reused colour still has four ends) and their dead ends stay.

## Content and art

- `site_wayring` / `object_wayring`, `site_waygate` / `object_waygate`, `site_wayfall` / `object_wayfall`: family `transit_object`, runtime status `portal_network_live`. That status keeps them out of the generic transit-route pool (`portal_network_meaning_placement` in `content/random_map_object_eligibility.json`); they are placed only from HoMM3 Monoliths. Their exits come from the native package contract, never from authored local offsets, so the authored route-effect metadata check does not apply to them.
- Each sprite (`mapobj_<name>.png`) comes from one original painting per kind whose magic is painted in a key magenta. `tools/pack_portal_network_sprites.py` cuts the magic out of the stonework (a dark opening, open air for the beam, neutral stone where light spilled), writes the magic as white-light layers (`mapobj_wayring_vortex`/`_spill`, `mapobj_waygate_vortex`/`_spill`, `mapobj_wayfall_beam`/`_beam_core`/`_splash`) that keep the painted shading, and writes the effect geometry.

## Validation

`tests/portal_networks_report.tscn` regenerates the Large land seed 1041912569 map (template 6LM10) and checks: an unchanged final payload, 50 portals with connection data, nine two-way networks (the reused colour split off), the two self-linked one-way networks flagged and left off (42 portals remain, free tiles), per-kind sites, valid contracts, Wayring round trips at one movement, both Wayfalls of a Waygate reached at random over 16 trips, a reload replaying its exit, an unenterable Wayfall, per-kind text and actions, the version 2 migration and the art files. It also checks that each of the 15 networks has its own colour, that each sprite has a dark solid opening or an open-air beam, and that its two painted light layers are registered. With a window it checks the real map view's sprites, that all three effects run in the south-west cluster, that the particles keep redrawing and change inside every portal between two captures, and that reduced motion keeps a still frame that does not move. `HEROES_PORTAL_FX_FRAMES=<n>` saves a close-up frame sequence for review.
