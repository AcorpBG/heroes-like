# One description of a map tile

Slice: `ui-shared-tile-description-20261110` (owner decision, 2026-11-10).

## Problem

The adventure map told the player what stands on a tile in three places, each with
its own code, wording and idea of state:

- **Hover** built one pipe-separated line in `OverworldShell._tile_visibility_tooltip`
  from four rule texts: coordinates, "Class:", "Cadence:", "Roles:", "State
  uncollected", the name twice, the effect twice and a "Hover order" hint. The
  Wayside Exchange's line was about 560 characters in a card 360 pixels wide.
- **Right-click** (`OverworldInspection.inspect_tile`) was an army scouting report.
  For a building it read a `description` field none of the 437 sites has, so every
  building said "Visit this site to interact." It matched only the object's own
  tile (the doorstep of a building read "Scouted ground") and had no branch for
  towns or artifacts.
- **Sites (Alt)** (`OverworldInspection.highlight_rows`) stamped Available, Guarded,
  Visited or Exhausted from a `collected` flag hero-visit buildings never set. On a
  revealed medium map 387 of 543 labels read "Available", among them every building
  a hero had just used.

The three disagreed: a guard's ground against its battlefield, troop counts against
a strength word, and the Chartmaker's "once per hero" in its prompt against the
rule's once per player.

## The description

`OverworldInspection.describe_tile(session, tile, level)` returns one record, and
all three views read it. It decides nothing: every fact is a rule query
(`_resource_site_yield_line`, `_resource_node_claimable_by_player`,
`resource_site_blocking_guard`, `guard_engagement_encounter_at_tile`,
`read_tracks_garrison`, the artifact and encounter texts).

| Field | Meaning |
| --- | --- |
| `kind` | `unscouted`, `ground`, `town`, `site`, `army`, `artifact` |
| `in_sight` | false on remembered ground |
| `title`, `subtitle` | the name, and what kind of thing it is (Hero visit, Trade, Mine, Creature dwelling, a faction's town, an army's size) |
| `gives`, `gives_short`, `choices` | what it gives and how often; a building with several offers counts them for the hover and lists them for the report |
| `status`, `tone` | where it stands for the selected hero: ready, used (the rule's own sentence, with the day it opens again), guarded, hostile, yours, neutral |
| `flavour` | the site's `public_text` |
| `guard` | the army that guards it: name, stacks, size, strength against the selected hero's army, battle reward, battlefield |
| `tag`, `tag_tone`, `tag_tile` | the Sites label, its tone and the tile it hangs under |

What stands on a tile is looked up over the whole object: a town's footprint and
gate, a site's own tile, body tiles and visit tiles. A town comes first, then a
site, an army, an artifact, the ground (with the army that watches it).

Remembered ground (explored, out of sight) shows what a building is and, for a
hero-visit building, whether this side has used it: that is the player's own
knowledge. Owners, guards, armies and artifacts show only in sight.

## The three views

- **Hover** (`hover_text`): at most three lines. Name and kind; what it gives; the
  status. "Fortune Ring · Hero visit / +1 momentum next battle, once per hero each
  week / Ready for Lyra Emberwell".
- **Right-click** (`inspect_tile`, `ScoutInspectionDialog.open_report`): the same
  lines with room: the offers one per line, the flavour line, scouting marks, the
  guard with its stacks, what victory brings and the battlefield. A flavour line
  that already states what the building gives says it once.
- **Sites (Alt)** (`highlight_rows`, `OverworldMapView._draw_interaction_highlight`):
  a building's name, with "· used" and a muted tone when the selected hero cannot
  use it now; "· guarded" in red behind a guard; an army's strength word; a town's
  name and owner. Loose pickups carry no label. A label hangs under the middle of
  the object's lowest row of tiles, an army's a line lower. Hero-visit buildings
  keep their label on remembered ground.

One measure of strength is used everywhere: the guard's army against the selected
hero's (Much weaker to Much stronger). A battle is fought on the encounter's own
field, so the report names it as the battlefield and the ground separately.

## Validation

Medium land seed 4103 as Embercourt. With the map revealed, one object of each of
29 site kinds, five towns, three armies and two artifacts read the same in the
hover and the report. In play with real fog: the Wayside Exchange and a Fortune
Ring read Ready; after a trade and a visit the hover, the report and the label of
both say used, with the rule's sentence ("serves you again on day 8"). The
doorstep of the exchange, and every tile of the player's town, name the building.
The labels of a revealed medium map take 0.2 s to build (347 rows).
