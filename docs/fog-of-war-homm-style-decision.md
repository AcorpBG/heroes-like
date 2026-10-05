# Fog Of War HoMM-Style Decision

Date: 2026-04-30

AcOrP clarified that heroes-like should use the original Heroes-style fog model:

- Unexplored tiles remain hidden/black.
- Once a tile is explored, it remains visible permanently for rules, route planning, renderer terrain, and object presentation.
- There is no separate gameplay layer where explored-but-not-currently-scouted tiles become grey, stale, hidden, or less actionable.
- `visible_tiles` may remain in save/runtime payloads as a compatibility alias or cache for `explored_tiles`, but it must not drive transient line-of-sight hiding.
- Routine movement should add the newly explored hero/site scouting radius and avoid recomputing a full-map current-visibility mask.

Deferred future systems that want stale enemy sightings, uncertain moving threats, or AI-specific scouting memory need their own explicit state contract. They must not overload player terrain visibility.

## Scouting radii (2026-10-05)

AcOrP asked for larger starting vision, round rather than diamond sight, and for the AI to see what the player sees. Every radius covers a round area: a tile is in sight when `dx*dx + dy*dy <= r*(r + 1)`, i.e. its centre lies within r + 1/2 tiles (`HeroCommandRules.within_scout_radius`). The same rules apply to authored scenarios and generated maps:

- Heroes: base 6 (`HeroCommandRules.BASE_SCOUT_RADIUS`, doubled from 3), plus Border Warden specialty ranks and artifact/set `scouting_radius` bonuses.
- Owned towns: 8 from the town entrance (`OverworldRules.TOWN_VISION_RADIUS`, raised from 5), with no faction, town-level, or building modifier.
- Held persistent sites: their own `vision_radius`. All 13 scouting structures share a fixed radius of 10. Overworld reveal spells were raised by 3 per tier (7/9/11/14/18). The six Fogbreak survey charts require the whole map, but at radius 10 the central south instrument alone charts the 15x9 map, so those authored surveys no longer need all three instruments; their smoke is an obsolete authored-scenario check (`docs/authored-scenarios-obsolete.md`).
- AI sighting sources use the same rules: owned towns at the town radius from the entrance, raid commanders at `scouting_radius_for_hero` of their commander state, and held persistent sites at their own radius. The previous AI-only radii (towns 7/8, raiders 5, minimum site 3) are removed.
