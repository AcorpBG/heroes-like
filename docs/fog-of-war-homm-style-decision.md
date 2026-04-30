# Fog Of War HoMM-Style Decision

Date: 2026-04-30

AcOrP clarified that heroes-like should use the original Heroes-style fog model:

- Unexplored tiles remain hidden/black.
- Once a tile is explored, it remains visible permanently for rules, route planning, renderer terrain, and object presentation.
- There is no separate gameplay layer where explored-but-not-currently-scouted tiles become grey, stale, hidden, or less actionable.
- `visible_tiles` may remain in save/runtime payloads as a compatibility alias or cache for `explored_tiles`, but it must not drive transient line-of-sight hiding.
- Routine movement should add the newly explored hero/site scouting radius and avoid recomputing a full-map current-visibility mask.

Deferred future systems that want stale enemy sightings, uncertain moving threats, or AI-specific scouting memory need their own explicit state contract. They must not overload player terrain visibility.
