# Economy Resource Additive Schema And Validator Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: economy-resource-additive-schema-validator-planning-10184.

## Purpose

This document defines the narrow first implementation contract for additive resource metadata, compatibility adapters, validator warnings, and economy reports before any production JSON migration or runtime behavior switch.

This slice deliberately plans scaffolding only. It must not edit production content JSON, change market behavior, change economy runtime behavior, migrate saves, activate rare-resource costs, import sprites, or ingest generated concept-art assets.

## Source Reality

Current production content and runtime are still the `gold`, `wood`, and `ore` economy with `experience` as a non-stockpile progression reward key.

Current validator reality:

- `tests/validate_repo.py` validates resource dictionaries only for nonempty keys and nonnegative amounts in fields such as `rewards`, `claim_rewards`, `control_income`, and `service_cost`.
- Mine-like sites already require `persistent_control` and `control_income`.
- Repeatable services already require `repeatable` and `visit_cooldown_days`.
- Map objects link to resource sites and validate legacy `family`, `footprint`, `passable`, `visitable`, and `map_roles`.
- There is no resource registry, alias policy, source availability report, output cadence report, market cap report, or strict sample fixture mode yet.

Current runtime reality:

- `ScenarioFactory.gd`, `OverworldRules.gd`, `TownRules.gd`, and `EnemyTurnRules.gd` contain explicit `gold`/`wood`/`ore` assumptions.
- `EnemyTurnRules.gd` still uses `TRACKED_RESOURCES := ["gold", "wood", "ore"]`.
- Market code and town UI copy are common-resource oriented and specifically talk about wood and ore exchange.
- `SessionStateStore.gd` saves resource dictionaries without a separate resource schema version.

The first implementation must therefore be report-oriented and compatibility-safe.

## Exact Optional Fields To Add First

The first additive schema should introduce a small non-runtime resource registry fixture or schema payload used by reports and strict tests. It should not require production content to reference this registry yet.

Recommended registry item fields:

```json
{
  "id": "wood",
  "display_name": "Wood",
  "category": "construction_staple",
  "market_tier": "common",
  "default_visible": true,
  "legacy_aliases": [],
  "canonical_status": "canonical_live_id",
  "faction_affinity": {
    "faction_embercourt": "primary",
    "faction_thornwake": "primary"
  },
  "ui_sort": 20,
  "icon_hint_id": "resource_wood_placeholder",
  "material_cue": "cut beams, road planks, rails, and wood yards",
  "stockpile": true,
  "report_only": true
}
```

Minimum fields for strict fixtures:

- `id`
- `display_name`
- `category`
- `market_tier`
- `default_visible`
- `legacy_aliases`
- `ui_sort`
- `stockpile`

Optional first-pass fields:

- `canonical_status`
- `faction_affinity`
- `icon_hint_id`
- `material_cue`
- `ai_resource_value`
- `report_only`

Allowed `canonical_status` values:

- `canonical`
- `canonical_live_id`
- `non_stockpile_reward`

The production registry can start as a test fixture or report fixture. Adding `content/resources.json` to production content should wait for explicit approval because this task forbids production JSON content changes.

## Registry And Report Shape

The validator/report implementation should expose a single economy resource report. Text output should be human-readable, and a JSON report should be available for CI/artifact review.

Suggested JSON shape:

```json
{
  "schema": "economy_resource_report_v1",
  "generated_at": "iso8601",
  "mode": "registry_policy_report",
  "registry": {
    "resource_count": 4,
    "stockpile_resource_ids": ["gold", "wood", "ore"],
    "non_stockpile_reward_ids": ["experience"],
    "alias_pairs": [],
    "missing_metadata": []
  },
  "usage": {},
  "sources": {},
  "cadence": {},
  "capture": {},
  "market_caps": {},
  "warnings": [],
  "errors": []
}
```

The text report should group findings in this order:

1. Registry summary.
2. Resource usage by content domain.
3. Source and availability matrix.
4. Output cadence inference.
5. Persistent-site capture warnings.
6. Market cap and rare-resource access stance.
7. Resource policy notes.
8. Strict fixture results.

## Wood Canonical Reporting

The first implementation must report `wood` explicitly and must not rename production data.

Required behavior:

- Treat `wood` as the live authored and save id.
- Display/report `wood` as Wood where display names are available.
- Treat `wood` as the canonical resource id with no target id or alias path.
- Keep `experience` outside the stockpile registry and report it under non-stockpile reward usage.

Suggested policy report item:

```json
{
  "resource_id": "wood",
  "display_name": "Wood",
  "canonical_status": "canonical_live_id",
  "production_occurrences": 0,
  "target_resource_ids": []
}
```

## Source And Availability Report Shape

The first source report should answer where each resource appears and whether it has any source path.

Suggested shape:

```json
{
  "resource_id": "ore",
  "display_name": "Ore",
  "stockpile": true,
  "used_by": {
    "unit_costs": 0,
    "building_costs": 0,
    "hero_costs": 0,
    "site_rewards": 0,
    "site_income": 0,
    "scenario_starting_resources": 0,
    "scenario_script_grants": 0,
    "campaign_rewards": 0,
    "market_rules": 0
  },
  "source_paths": {
    "town_income": [],
    "persistent_sites": [],
    "pickups": [],
    "repeatable_services": [],
    "market_profiles": [],
    "scenario_grants": []
  },
  "availability": "available",
  "warnings": []
}
```

Availability labels:

- `available`
- `reward_only`
- `cost_only`
- `script_only`
- `registry_only`
- `non_stockpile_reward`
- `unknown_unregistered`

Warnings should be report-only for current production content. They become errors only for strict sample fixtures or declared migrated bundles.

## Output Cadence Inference Warnings

The report should infer cadence from current fields without rewriting site records.

Inference rules:

- `rewards` on a one-shot site implies `instant_claim`.
- `claim_rewards` implies `instant_claim`.
- `control_income` plus `persistent_control: true` implies `daily`.
- `repeatable: true` plus `visit_cooldown_days > 0` implies `service_refresh`.
- `weekly_recruits` implies weekly recruitment refresh, not resource income.
- `transit_profile` implies route effect, not resource output.
- `guarded: true` plus `rewards` or `claim_rewards` implies `battle_cleanup` or guarded `instant_claim` depending on the site family.

Warnings:

- Persistent site has income but no explicit future `resource_outputs` cadence.
- Repeatable service grants resources without a future cap or refresh profile.
- Transit object appears to produce resources without explicit route-linked output metadata.
- Weekly recruit data is being confused with resource output.

No current production site should fail solely because cadence metadata is absent.

## Persistent-Site Capture Warnings

The first report should identify persistent economy and support sites that will eventually need capture metadata.

Suggested report shape:

```json
{
  "site_id": "site_ridge_quarry",
  "family": "mine",
  "persistent_control": true,
  "inferred_outputs": [{"resource_id": "ore", "cadence": "daily", "amount": 1}],
  "capture_profile_present": false,
  "recommended_capture_model": "capturable",
  "recommended_counter_capture_value": 5,
  "warnings": [
    "persistent site lacks capture_profile",
    "persistent site lacks counter_capture_value"
  ]
}
```

Warnings should cover:

- Persistent site lacks `capture_profile`.
- Persistent site lacks `counter_capture_value`.
- Persistent site lacks retake/damaged-state policy.
- Persistent site has high-value or rare output without guard/counter-capture metadata.
- Site has `persistent_control` but no income, town support, recruit source, route effect, scouting value, or other persistent reason.

The report must not add damaged state, retake days, garrisons, or owner serialization.

## Market-Cap Report Shape

The first market report should describe the current market as common-resource smoothing and prove that rare resources are not activated.

Suggested report shape:

```json
{
  "market_profile_id": "legacy_common_exchange",
  "source": "inferred_from_current_town_market_code",
  "buy_resources": ["wood", "ore"],
  "sell_resources": ["wood", "ore"],
  "buy_caps_present": false,
  "sell_caps_present": false,
  "refresh_cadence_present": false,
  "rare_resource_buying_enabled": false,
  "warnings": [
    "legacy market has no serialized weekly caps",
    "legacy market is common-resource only"
  ]
}
```

Warnings:

- Market-cap metadata is absent.
- Market caps are not serialized.
- Market code is hardcoded to wood/ore.
- Any rare/faction resource appears buyable through a normal market.
- A high-tier or capstone future fixture can be bought entirely through normal market exchange.

Current production behavior should remain unchanged.

## Sample Strict Fixture Scope

Strict fixtures should be tiny, non-production, and isolated under a test fixture path such as `tests/fixtures/economy_resource_schema/` only when implementation begins.

Fixture scope:

- One registry fixture containing `gold`, `wood`, `ore`, and `experience`.
- One pickup fixture with `instant_claim` reward.
- One persistent economy site fixture with daily output and capture profile.
- One persistent economy site fixture missing capture profile to prove warning behavior.
- One repeatable service fixture with cooldown/service refresh and no passive income.
- One market profile fixture with common-resource weekly caps.
- One rare-resource market violation fixture.
- One faction preference fixture proving advisory weights only.
- One save-resource fixture proving absent `resource_schema_version` remains accepted and `wood` is not silently dropped.

Strict fixture failures must not imply production content failure unless production content declares the same strict schema version.

## Warning Versus Error Levels

Compatibility mode:

- Errors remain the existing validator errors: malformed JSON, broken references, negative resource amounts, unsupported legacy families, missing required legacy fields.
- New economy findings are warnings or report notes.
- Unknown resource ids should warn unless they appear in a strict fixture or declared migrated bundle.
- `wood` usage is valid production content.

Strict fixture mode:

- Missing required registry fields are errors.
- Unknown stockpile resource ids are errors.
- `experience` as a stockpile resource is an error.
- Persistent fixture sites without cadence/capture metadata are errors unless the fixture is intentionally testing warnings.
- Rare-resource buying through a normal market profile is an error.

Migrated bundle mode, future:

- Declared migrated bundles can promote warnings to errors.
- Unmigrated production content remains valid through compatibility adapters.

## CLI And Report Output Expectations

Implementation should avoid changing the default `python3 tests/validate_repo.py` pass/fail contract until warnings are reviewed.

Suggested CLI additions:

- `python3 tests/validate_repo.py --economy-resource-report`
- `python3 tests/validate_repo.py --economy-resource-report-json /tmp/heroes-economy-resource-report.json`
- `python3 tests/validate_repo.py --strict-economy-resource-fixtures`
- Optional later: `--warnings-as-errors` for CI experiments, not default.

Default validator output should either stay unchanged or print a compact warning count with a path to the report. Report generation must not rewrite content files.

## Resource Registry Helpers

The first implementation may add helper scaffolding only if it is unused by runtime behavior or used only by reports/tests.

Required adapter functions, names to be chosen in code style:

- Get display name for a resource id, including `wood` as Wood.
- Identify stockpile resources versus non-stockpile rewards.
- List canonical live ids for warnings.

Boundaries:

- Do not route live spend/add/market/save code through new helpers in this planning slice.
- Runtime adoption of helpers is a later implementation slice after report scaffolding passes.
- No save payload should be rewritten by report adapters.

## Acceptance Tests

The first implementation slice should be accepted by tests that prove:

- Existing `python3 tests/validate_repo.py` still passes on production content.
- The economy resource report can be generated without changing files.
- The report lists `gold`, `wood`, `ore`, and `experience` from current production content.
- The report calls out canonical `wood` status.
- The report classifies `experience` as non-stockpile.
- The source matrix distinguishes costs, rewards, persistent site income, scenario starts, and script grants.
- Persistent site cadence is inferred from `control_income` without requiring production metadata.
- Repeatable service cadence is inferred from `repeatable` plus `visit_cooldown_days`.
- Missing capture profiles are warnings in compatibility mode.
- Missing market caps are warnings in compatibility mode.
- Strict fixtures fail for unknown resources, negative amounts, missing required registry metadata, and rare-resource normal-market buying.
- Strict fixtures pass for a valid pickup, persistent site, repeatable service, capped market profile, faction preference profile, and old-save resource payload.

## Rollback Boundaries

Rollback must be simple:

- Remove the report/fixture files and validator warning code.
- Keep production JSON untouched.
- Keep runtime behavior untouched.
- Keep save files untouched.
- Keep market behavior untouched.
- Keep generated concept art outside the repository.

If warnings are too noisy, lower report verbosity or scope before promoting any finding to an error. Do not silence warnings by editing production content during the additive report slice.

## Must Not Change

This contract explicitly forbids:

- Production JSON migration in `content/`.
- Resource id migration for `wood`.
- Market/runtime behavior changes.
- Save schema migration or save rewrite.
- Rare-resource economy activation in production costs, rewards, markets, AI, or starts.
- Runtime AI treasury adoption of new resources.
- Map-object/resource-site bundle migration.
- Renderer sprite ingestion or asset/sprite import.
- Generated concept-art PNG import.
- UI redesign or resource strip expansion.
- Claims that the economy is production-ready or balanced.

## AcOrP Review Decisions

AcOrP should review before implementation:

- Confirm that `wood` remains the permanent internal id and display concept.
- Whether the first registry is test/report-only or should later become `content/resources.json`.
- Whether default validator output may print warning counts or report mode should be opt-in only.
- Whether `experience` remains outside stockpile registry as planned.
- Whether missing capture profile and market cap findings are warnings only in compatibility mode.
- Whether strict fixtures may include future rare resources while production content stays on `gold`, `wood`, and `ore`.

## Done Criteria

- The first implementation contract is narrow, additive, and report-first.
- Exact optional resource registry fields and warning/report shapes are defined.
- Canonical `wood`, source availability, cadence inference, capture warnings, market caps, fixture scope, validation levels, CLI expectations, resource registry helpers, acceptance tests, rollback, and hard non-changes are covered.
- The next slice can implement validator/report scaffolding without touching production content JSON or runtime economy behavior.
