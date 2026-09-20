# Common town building template

Owner direction, 2026-09-20: one town per faction; redesign the building system around a general template of common buildings and upgrades before faction-specific differences.

## Implemented consolidation

The active town catalog contains exactly six definitions:

| Faction | Canonical town | Template ID |
| --- | --- | --- |
| Embercourt League | Riverwatch Hold | `town_riverwatch` |
| Mireclaw Covenant | Duskfen Bastion | `town_duskfen` |
| Sunvault Compact | Prismhearth | `town_prismhearth` |
| Thornwake Concord | Graftroot Caravan | `town_thornwake_graftroot_caravan` |
| Brasshollow Combine | Orevein Gantry | `town_brasshollow_orevein_gantry` |
| Veilmourn Armada | Bellwake Harbor | `town_veilmourn_bellwake_harbor` |

The 26 removed definitions are replaced only by ID-to-ID compatibility aliases in `content/towns.json`. They contain no economy, buildings, recruitment, backdrop, or town-variant rules. Catalogs/editors/wiki expose only the six active entries. Legacy placed IDs are deliberately retained in existing maps and saves so template-targeted scenario objectives and scripted events still identify the intended settlement. Content lookups resolve them to the same faction template. New native-package adoption uses canonical runtime identities while preserving original source records, placement IDs, masks, entrances, terrain and ownership.

Each faction temporarily retains the union of its former building lists and spell libraries. The canonical town supplies one set of starting buildings, income/recruitment modifiers, garrison and town rules. Constructed buildings, recruited stocks, ownership, service-claim flags and placement data remain saved state. Former town-specific artifact commissions now use the canonical faction town; the two lower-tier services no longer exclude a removed variant. This is content consolidation, not completion of the new building system. No building art or source/provenance is deleted.

## Proposed common template — not implemented

All factions should share the same building IDs, functions, costs and prerequisite graph for the foundation below. Faction artwork may differ while retaining recognizable functions. The lines and stage counts below are proposals; costs and exact bonuses remain to be agreed before implementation.

| Common building line | Proposed stages | Purpose |
| --- | --- | --- |
| Town Hall | I–IV | Increasing daily gold income; the final stage is the capital upgrade. |
| Fortifications | I–III | Defensive works, then stronger town defenses; explicit siege benefits at each stage. |
| Magic Guild | I–V | Spell tiers 1 through 5 with clearly displayed spell access. |
| Marketplace | I–III | Resource exchange with progressively better rates. |
| Tavern | One | Hero recruitment and visiting-hero information. |
| Workshop | I–II | A common support-equipment service, followed by improved equipment access. Exact equipment is a separate decision. |
| Storehouse | I–II | Common wood/ore supply support. Exact output and unlock timing are balance decisions. |

Creature dwellings and their upgrades are a later layer on this foundation. This proposal does not select or remove faction units, define creature upgrade pairs, or add faction-exclusive special buildings yet.

## Upgrade rules for the implementation slice

- Each line has one current stage. Upgrading advances the same building instead of leaving separately counted bonus buildings behind.
- The displayed effect is the total at the current stage; lower-stage effects must not stack again. For example, a hall upgraded from 500 to 1,000 daily gold produces 1,000, not 1,500. These numbers illustrate the rule, not approved balance.
- Upgrades require the previous stage and explicitly listed common prerequisites. Show the cost and before/after effects before committing.
- One construction order per town per day remains the default rule. Higher-tier upgrades use the same restriction.
- Save/load, AI building choices, construction UI, scene-layer replacement, income, spell access and defenses must all use the same stage authority.
- Old building IDs require an explicit migration table after the replacement design is approved. Do not silently discard built structures, charge construction again, or grant all upgrades during migration.
- Decide whether the final Town Hall stage is limited to one per player before implementing it. Do not infer a faction-specific capital restriction from removed named-town templates.

## Acceptance boundary

Town consolidation is complete only when all six templates resolve, legacy IDs load through aliases, old save/objective identities survive, former buildings remain reachable, the editor/wiki catalog lists six towns, and representative construction and native-package adaptation checks pass. The shared-building redesign remains a proposal until its costs, effects, prerequisites and migration are implemented and separately verified. Full repository validation is outside this owner-directed content pass.

Focused verification on Windows/Godot 4.6.2: 164 runtime/save/construction/adoption checks pass. Content inspection confirms six templates, direct aliases for 26 retired IDs, reachable construction prerequisites and exactly six wiki town entries. Source records and old objective targets are preserved. Full-suite and Linux execution were not run. The cross-platform Python probe is `tests/single_faction_towns_regression.py`; temporary logs/profile are deleted after review.
