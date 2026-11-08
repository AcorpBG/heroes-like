# Overworld terrain movement

Slice `overworld-terrain-costs-20261108`. The owner asked on 2026-11-08 for the movement penalty for rough terrain, so that Green Path and Mire Stride have something to ease.

## What a step costs

A step costs the ground of the tile it enters, in movement points:

| Ground | Points a step |
|---|---|
| grass, plains, dirt, lava, ash, underground | 1 |
| rough (with hills, highland and ridge), forest, sand (with wastes), snow, frost | 1.5 |
| swamp, mire | 2 |

- A diagonal step costs the same as a straight one.
- A step from a road tile to a road tile costs 1 point on any ground; with the hero's Forge Road, half a point.
- A hop through a portal or a subterranean gate costs 1 point.
- Water: a boat's step costs 1 point; boarding and landing work as before. Rock stays closed.
- An enemy's Scorched Earth doubles a step into its reach, once where several overlap. A wardwood still stops an army that comes near.

Generated maps use dirt, grass, lava, rough, sand, snow, swamp, underground and water. Forest, mire, ash, frost and plains come only from authored maps.

The values are `movement_cost` on each terrain class in `content/terrain_grammar.json`, in half points from 0.5 to 100 (the content check refuses others). The `movement_cost` in `content/biomes.json` was never read and is gone.

## Points and half points

Movement is counted in half points. A step needs its whole cost: a hero with 1 point left cannot take a 1.5 step, and its route goes on the next day. A half point left over stays with the hero for the rest of the day and pays half a step (`map_road_half` on the hero; the name is older than this slice). It goes when the hero's next day starts.

## Routes

- The human route search, the route preview and the computer players' search take the cheapest route in movement, not the fewest steps. Among routes of equal cost they take the first one found.
- The preview counts the same costs as the walk, so the reach it shows is the reach walked. A route that cannot take its next step today says so: "The next step costs more movement than the hero has left today."
- The computer players' search (`ai_search::search`) gives distances in points, half points rounded up, so its callers keep their meaning. The per-tile costs come from the level surface (`terrain_kind`, `terrain_ids`, `road_mask`) through `map_spells::StepCosts::fill`.
- The computer players' old walk counted some tiles past a portal exit farther than they were; the new one counts them right.

## Green Path and Mire Stride

- **Green Path** (Root, tier 2, 4 mana): forest and rough cost the hero's army no more than grass for {1+P/5} days.
- **Mire Stride** (Veil, tier 2, 4 mana): swamp, mire and sand cost the hero's army no more than grass for {1+P/5} days. The earlier draft named coast, which is water; sand takes its place.
- The covered ground is the effect's `terrains`. The hero keeps it as `map_ground_ways` {terrain: last day}, and a second cast runs to the later end.
- A road step stays a road step, so a road through covered ground still costs 1 point, or half a point with Forge Road.
- Computer players cast whichever of Forge Road, Green Path and Mire Stride takes the hero at least three tiles farther along its plan today, before walking (first values, not measured).

## Faction home terrains

Slice `overworld-faction-ground-20261108`. The owner decided on 2026-11-08 that a faction's heroes cross the faction's own terrains without the extra cost, and that the map generator stays as it is.

| Faction | Home terrains |
|---|---|
| Mireclaw | swamp, mire |
| Sunvault | snow, frost |
| Brasshollow | rough (with hills, highland and ridge) |

- A step onto a home terrain costs a hero of that faction what a step onto grass costs, on every day, as Green Path and Mire Stride do on their days. The faction is the hero's own, whoever hires it, as for the preferred spell school.
- Embercourt, Thornwake and Veilmourn list none: the ground of their town types (grass, dirt, underground) already costs 1 point, as does Brasshollow's lava.
- The terrains are `home_terrain_ids` in `content/factions.json`. The content check refuses an id that is not a terrain class of `content/terrain_grammar.json`, and the hero sheet names them ("Home ground: swamp and mire cost the hero's army no more than grass.").
- Generated maps do not put a faction on its home terrain. The generator never sees the factions: it rolls each seat's town type and paints the ground from the template, and the factions are given to the seats afterwards. A faction meets its home terrain only where a map happens to have it, and a seat that starts on rough, snow, sand or swamp moves slower around home, whatever its faction.

## Not in this slice

- No spell eases snow; Sunvault's heroes cross it for free.
- No hero specialty or skill lowers the costs yet; `StepCosts::ground_halves` is where one would go.
