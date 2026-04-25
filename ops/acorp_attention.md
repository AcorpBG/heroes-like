# AcOrP Attention

Updated: 2026-04-25

## Hard Blockers

- GitHub push/auth is blocked: local commit `c490dca` could not be pushed because GitHub credentials are invalid. Do not spend engineering time on auth until credentials are refreshed.

## Decisions Needed

- Economy implementation will need an AcOrP decision on whether the internal `wood` resource id remains as a compatibility alias/displayed as Timber or migrates to canonical `timber` through a save-aware schema update.
- Economy implementation should also confirm whether the full nine-resource target in `docs/economy-overhaul-foundation.md` is acceptable for staged production, or whether the rare/faction resources should be grouped before JSON migration.
- Object implementation should confirm whether the density bands and object-class contract in `docs/overworld-object-taxonomy-density.md` are acceptable as the production target before schema/editor migration.
- Object implementation should confirm whether neutral encounters should become a first-class visible overworld object model separate from neutral dwellings and guarded reward sites.
- Object implementation should confirm when true footprint occupancy and approach-tile validation should become gameplay rules rather than renderer/editor hints.
- Magic implementation should confirm whether the seven-school accord model in `docs/magic-system-expansion-foundation.md` is the production target before spell schema, UI, AI, and content migration.
- Magic implementation should confirm how aggressively resource catalysts should be used for tier 3+ and adventure-map spells so the future economy model gains meaning without making spellcasting feel like bookkeeping.
- Magic implementation should confirm that Old Measure spells remain rare, scenario-gated, and route/object constrained rather than becoming a normal universal spell school.
- Magic implementation should confirm adventure-spell safety rules before any route bypass, site renewal, economy boost, or reveal spell is implemented in live maps.
- Artifact implementation should confirm the target equipment slot model in `docs/artifact-system-expansion-foundation.md`, especially the dedicated relic slot, two trinket slots, and whether mount/conveyance becomes a real slot or later optional layer.
- Artifact implementation should confirm whether unique sets should become normal skirmish rewards or remain mostly faction landmark, guarded site, Old Measure, and campaign-chain rewards.
- Artifact implementation should confirm how broadly curses/tradeoffs should appear in normal maps, since they add strategic texture but require UI, AI, save, and removal-service support before use.
- Artifact implementation should confirm that Old Measure artifacts remain rare, charged, attuned, or scenario-gated rather than becoming normal high-stat loot.
- Artifact implementation should confirm whether artifact economy hooks may touch rare resources before the economy resource-id migration and market-cap rules are implemented.
- Animation implementation should confirm whether the first vertical proof should prioritize battle readability or overworld/town state clarity.
- Animation implementation should confirm which faction should anchor the first motion proof, with Embercourt as the likely low-risk candidate because Beacon, roads, towns, and River Pass-style proof are already central.
- Animation implementation should confirm whether production units/heroes should target sprite sheets, cutout scene rigs, or a hybrid pipeline before asset production starts.
- Animation implementation should confirm normal-mode versus fast-mode pacing targets before battle and AI-turn playback are implemented.
- Animation implementation should confirm audio direction and cue priority rules before SFX production starts.
- Strategic AI implementation should confirm whether the current pressure/raid enemy model should migrate first into explicit AI event streams or into full AI hero roster/task state.
- Strategic AI implementation should confirm the intended fairness policy for hard difficulty: better planning and scouting inference are acceptable, but any resource, movement, visibility, or combat bonuses should be labelled.
- Strategic AI implementation should confirm which two factions should anchor the first AI personality proof; Embercourt versus Mireclaw is the likely low-risk pair because it contrasts infrastructure defense with raid/counter-capture pressure.
- Strategic AI implementation should confirm whether adventure-map spells that affect scouting, routes, economy, or site state are blocked until AI can evaluate them, as recommended in `docs/strategic-ai-foundation.md`.

## Current Follow-Up

- Strategic AI foundation is documented. Next production slice should execute the first actual concept-art generation pass from `docs/concept-art-pipeline.md`; when art generation is done, send the generated images to AcOrP on Discord before treating them as approved direction.
