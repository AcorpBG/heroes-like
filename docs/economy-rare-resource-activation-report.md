# Economy Rare Resource Activation Report

Status: implemented staged/report-only activation foundation.
Date: 2026-04-27.
Slice: `economy-rare-resource-activation-10184`.

## Scope

This slice activates rare resources only as validated registry/report concepts. It does not migrate production content, add live rare-resource costs, add broad rare-resource sources, change market behavior, rewrite saves, or bump `SAVE_VERSION`.

The staged rare resources are original Aurelion Reach resources:

| Resource id | Display name | Category | Source-family evidence |
| --- | --- | --- | --- |
| `aetherglass` | Aetherglass | `arcane_material` | aetherglass orchard, lens gallery, relay salvage |
| `embergrain` | Embergrain | `supply` | embergrain yard, granary barge, ration depot |
| `peatwax` | Peatwax | `local_fuel_rite` | peatwax cut, mudglass deposit, ferry rite cache |
| `verdant_grafts` | Verdant grafts | `living_material` | graft nursery, rooted orchard, renewal grove |
| `brass_scrip` | Brass scrip | `contract_credit` | contract foundry, scrip office, pressure rail depot |
| `memory_salt` | Memory salt | `salvage_memory` | wreck field, obituary vault, fog salvage camp |

Source evidence comes from `docs/economy-overhaul-foundation.md`, `docs/economy-resource-schema-migration-plan.md`, `docs/concept-art-implementation-briefs.md`, and batch 005 resource-front notes in `docs/concept-art-batch-005-review.md`. Generated art remains external evidence only.

## Implementation

- Extended the report-only strict registry fixture with the six staged rare resources, categories, affinities, icon hints, material cues, source-family evidence, and `activation_status: staged_report_only`.
- Extended `tests/validate_repo.py` economy reporting with `rare_resources`, `ui_report.resource_rows`, and `activation_gates` sections.
- Added default validation that proves rare resources are report-visible but have zero live production occurrences in costs, rewards, starts, grants, income, or market rules.
- Added strict fixture coverage for a guarded staged rare-resource source metadata case and a normal-market profile that explicitly restricts all staged rare resources.
- Kept `wood` canonical and preserved old-save compatibility without a save-version bump.

## Explicit Non-Changes

- No `content/` production JSON migration.
- No rare-resource town, unit, spell, artifact, scenario, campaign, or hidden grant costs.
- No live resource pool, AI treasury, market, save, or UI runtime adoption.
- No broad market migration or faction-cost rebalance.
- No generated concept-art import.

## Validation Evidence

Required validation for completion:

- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report --economy-resource-report-json /tmp/heroes-economy-resource-report.json`
- `python3 -m json.tool /tmp/heroes-economy-resource-report.json >/tmp/heroes-economy-resource-report-json.txt`
- `python3 tests/validate_repo.py --strict-economy-resource-fixtures`
- canonical wood-id scan for legacy alternate naming
- `python3 -m json.tool ops/progress.json >/tmp/heroes-progress-json.txt`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`
- `git diff --check`

## Next Work

The next P2.3 child should be `economy-market-faction-costs-10184`. It should use this report as a gate: market caps or faction-biased costs can only touch staged rare resources if source paths, UI display, save state, AI behavior, and normal-market restrictions are explicitly implemented and validated.
