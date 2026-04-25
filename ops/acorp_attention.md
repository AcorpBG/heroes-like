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
- Concept-art curation should get AcOrP accept/reject/defer calls on the first external world mood plus six-faction identity batch recorded in `docs/concept-art-batch-001-review.md`.
- Concept-art curation should confirm whether the world mood direction is useful as broad Aurelion Reach infrastructure-fantasy mood, or whether the next pass should move immediately to cleaner region/readability frames.
- Concept-art curation should confirm whether Embercourt and Mireclaw can move into town/object second-pass briefs, while Sunvault, Thornwake, Brasshollow, and Veilmourn first need stronger anti-generic silhouette passes.
- Concept-art curation should explicitly reject embedded text, generated labels, pseudo-logos, and tagline copy from any future visual reference. The first Veilmourn sheet contains useful motifs, but its embedded labels/text make it non-approvable as-is.
- Concept-art curation should review the second-pass outputs recorded in `docs/concept-art-batch-002-review.md`: cleaner world route readability, no-text Veilmourn, and Sunvault silhouette direction.
- Concept-art curation should confirm whether the no-text Veilmourn revision is acceptable as material/prop direction, while still requiring town exterior and unit-ladder follow-up before implementation briefs.
- Concept-art curation should confirm whether the Sunvault second pass sufficiently reduces holy paladin drift for object/building language, or whether unit silhouettes need another stricter calibration-worker and relay-engineer pass.
- Concept-art curation should review the second-pass expansion outputs recorded in `docs/concept-art-batch-003-review.md`: Thornwake silhouette/town/object, Brasshollow silhouette/town/object, and Embercourt town/object readiness.
- Concept-art curation should confirm whether Embercourt town/object direction can move into compact implementation-brief drafting after remaining second-pass coverage is less lopsided.
- Concept-art curation should confirm whether Thornwake needs a stricter seven-tier unit ladder pass before unit approval, even though the root-gate, graft-nursery, toll-arch, and living-road object language is useful.
- Concept-art curation should confirm whether Brasshollow needs another anti-steampunk, contract-law silhouette pass focused on debt seals, clause tablets, repair windows, worker courts, and machine maintenance.
- Concept-art curation should confirm that the next art slice remains additional second-pass generation for Mireclaw town/object, Veilmourn town/unit, Sunvault seven-tier ladder, and broader object/town studies rather than implementation-brief prep.

## Current Follow-Up

- Concept-art review notes are recorded in `docs/concept-art-batch-001-review.md`, `docs/concept-art-batch-002-review.md`, and `docs/concept-art-batch-003-review.md`; all generated PNGs remain external only. Next production slice should continue second-pass art generation for Mireclaw town/object, Veilmourn town/unit, Sunvault seven-tier ladder, and broader object/town studies while collecting AcOrP curation calls; no hard blocker.
