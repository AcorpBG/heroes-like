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

## Current Follow-Up

- Magic system expansion foundation is documented. Next foundation slice should plan artifact expansion: artifact breadth, unique sets, spell interactions, faction-specific interactions, economy hooks, hero/build implications, validation gates, and migration sequence.
