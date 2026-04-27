# Economy Resource Schema Migration Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: economy-resource-schema-migration-planning-10184.

## Purpose

This document defines the staged production data/schema contract for resource ids, economy outputs, persistent resource fronts, market limits, AI valuation hooks, and save compatibility before any JSON migration, resource-site bundle migration, market implementation, renderer sprite ingestion, or save migration.

This is intentionally not an implementation slice. `content/resource_sites.json`, `content/towns.json`, `content/units.json`, `content/factions.json`, runtime economy code, validators, saves, renderer mappings, and content JSON remain unchanged here.

## Source Inputs

- `docs/economy-overhaul-foundation.md`
- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/concept-art-implementation-briefs.md`
- `docs/strategic-ai-foundation.md`
- Reality check against current `content/resource_sites.json`, `content/towns.json`, `content/units.json`, `content/factions.json`, `content/buildings.json`, `tests/validate_repo.py`, and relevant economy scripts

## Current Economy And Resource Reality

Current authored and runtime economy is still the three-resource baseline:

- `content/resource_sites.json` has 48 site records.
- Current site reward and income resource keys are `gold`, `wood`, `ore`, and `experience`.
- `experience` appears as a reward/progression payload and should not become a normal stockpile resource.
- Current resource-site families are `mine`, `scouting_structure`, `transit_object`, `repeatable_service`, `guarded_reward_site`, `frontier_shrine`, `faction_outpost`, and `neutral_dwelling`; several early pickups still omit `family`.
- Persistent sites already use useful fields such as `persistent_control`, `claim_rewards`, `control_income`, `guarded`, `guard_profile`, `repeatable`, `visit_cooldown_days`, `transit_profile`, `vision_radius`, `town_support`, and response/pressure data.
- Current mine-like sites include `site_brightwood_sawmill`, `site_ridge_quarry`, and `site_marsh_peat_yard`; they still output only `wood`, `ore`, or `gold`.
- `content/units.json` has 103 unit records with authored costs using `gold`, `wood`, and `ore`.
- `content/buildings.json` has 77 building records with costs and income using `gold`, `wood`, and `ore`.
- `content/towns.json` has 12 town records with economy profiles still expressed through `gold`, `wood`, and `ore` via base and per-category income.
- `content/factions.json` has 6 faction records with economy profiles and enemy strategy scaffolds still built around the current resource set.
- Current market-facing code and UI copy are explicitly wood/ore/gold oriented.
- `EnemyTurnRules.gd` currently declares `TRACKED_RESOURCES := ["gold", "wood", "ore"]`, so AI treasury normalization is not yet registry-driven.
- `SessionStateStore.gd` currently records save version 9 and stores overworld resources as a dictionary without a separate resource schema version.
- `OverworldRules.gd` and `TownRules.gd` contain multiple helper paths that describe, merge, value, trade, and check resources with `gold`, `wood`, and `ore` assumptions.

This reality means the next implementation cannot safely rename resources, add rare costs, or enforce a broader registry in one pass. The first live changes must be additive and report-oriented.

## Target Resource Id Policy

Resource ids must be stable, lowercase, snake_case identifiers. They are not display names, flavor labels, icon names, or localization strings.

Target full resource set from `docs/economy-overhaul-foundation.md`:

| Canonical id | Display name | Category | Migration stance |
| --- | --- | --- | --- |
| `gold` | Gold | liquidity | Existing canonical id. |
| `wood` | Wood | construction_staple | Existing canonical id. |
| `ore` | Ore | construction_staple | Existing canonical id. |
| `aetherglass` | Aetherglass | arcane_material | New staged resource. |
| `embergrain` | Embergrain | supply | New staged resource. |
| `peatwax` | Peatwax | local_fuel_rite | New staged resource. |
| `verdant_grafts` | Verdant grafts | living_material | New staged resource. |
| `brass_scrip` | Brass scrip | contract_credit | New staged resource. |
| `memory_salt` | Memory salt | salvage_memory | New staged resource. |

Recommended registry fields:

```json
{
  "id": "wood",
  "display_name": "Wood",
  "category": "construction_staple",
  "market_tier": "common",
  "default_visible": true,
  "legacy_aliases": [],
  "faction_affinity": {
    "faction_embercourt": "primary",
    "faction_thornwake": "primary"
  },
  "ui_sort": 20,
  "icon_hint_id": "resource_wood_placeholder",
  "material_cue": "cut beams, road planks, rails, and wood yards"
}
```

Rules:

- Authored content should eventually reference canonical ids only.
- Runtime should continue to reject unknown resource ids until an explicit future migration adds a narrowly scoped adapter.
- Validators must distinguish stockpile resources from non-stockpile reward keys such as `experience`.
- Costs, rewards, site outputs, markets, scenario scripts, campaign carryover caps, AI treasury state, and save payloads must all validate against the same registry or adapter.
- Resource ids must not encode faction names unless the resource is truly faction-specific across the whole game; `brass_scrip` and `memory_salt` are world resources with faction affinity, not private currencies.

## Wood Canonical Policy

Current content and runtime use `wood`, and Wood is the world/display concept.

Canonical decision:

- Keep `wood` as the live storage, authored-content, runtime, and save id.
- Add resource registry metadata that displays `wood` as Wood.
- Do not add an alternate target id or alias path for wood.
- Old saves with `wood` continue to load without resource-id migration.

## Resource Categories

The registry should categorize resources so markets, UI, AI, and validation do not treat everything as a generic colored number.

Target category ids:

- `liquidity`: flexible common spending, currently only `gold`.
- `construction_staple`: common structural resources, `wood` and `ore`.
- `arcane_material`: scarce magic/infrastructure material, `aetherglass`.
- `supply`: readiness, recovery, and long-route pressure, `embergrain`.
- `local_fuel_rite`: regional rite/fuel resource, `peatwax`.
- `living_material`: renewal and living-site resource, `verdant_grafts`.
- `contract_credit`: industrial finance and acceleration resource, `brass_scrip`.
- `salvage_memory`: fog, salvage, morale, and memory economy, `memory_salt`.
- `progression_reward`: non-stockpile progression keys such as `experience`, excluded from normal resource stockpile and markets.

Validation should warn when a resource lacks category metadata and error only when a migrated fixture or bundle declares it uses the new schema.

## Output Cadence Contract

Persistent resource fronts need explicit cadence. Current sites mostly use `claim_rewards` plus `control_income`; the target needs daily, weekly, burst, and service distinctions.

Recommended `resource_outputs` shape:

```json
"resource_outputs": [
  {
    "resource_id": "ore",
    "cadence": "daily",
    "amount": 1,
    "requires_owner": true,
    "starts_after_claim": true,
    "route_link_id": "",
    "weekly_day": 0,
    "cap_per_week": 0
  }
]
```

Cadence values:

- `instant_claim`: one-time reward when claimed or cleared.
- `daily`: deterministic day-advance income while controlled.
- `weekly`: deterministic weekly yield or refresh.
- `limited_charges`: output until charges are spent or the site is depleted.
- `route_linked`: output depends on a route/transit/link condition.
- `service_refresh`: repeatable service inventory or exchange, not passive income.
- `battle_cleanup`: reward after battle or salvage, usually not predictable income.
- `scenario_scripted`: controlled by scenario hooks.

Compatibility mapping:

| Current field | Target interpretation |
| --- | --- |
| `rewards` | `instant_claim` or pickup reward, depending on site class. |
| `claim_rewards` | `instant_claim` for persistent/claimable sites. |
| `control_income` | `daily` income until a weekly field exists. |
| `repeatable` plus `visit_cooldown_days` | `service_refresh` or `cooldown_days`, not passive income. |
| `transit_profile` | route object effect, not resource output unless paired with site output metadata. |

The first implementation should generate inferred reports from current fields. It should not rewrite site records.

## Persistent-Site Capture Values

Persistent resource fronts need more than output amounts. They also need capture and counter-capture values so UI, AI, and map placement can reason about them.

Recommended authored companion fields:

```json
"capture_profile": {
  "capture_model": "capturable",
  "claim_reward": {"gold": 200, "ore": 1},
  "counter_capture_value": 5,
  "pillage_policy": "limited_stock",
  "damaged_state_policy": "temporary_output_pause",
  "retake_recovery_days": 2,
  "defense_investment_ids": [],
  "route_dependency_tags": ["road_control"]
}
```

Target capture values:

- `capture_model`: `none`, `claim_once`, `capturable`, `route_controlled`, `town_controlled`, or `scenario_fixed`.
- `counter_capture_value`: normalized 0-10 value for AI/editor/summary use.
- `pillage_policy`: `none`, `claim_reward_only`, `limited_stock`, `output_pause`, or `scenario_scripted`.
- `damaged_state_policy`: `none`, `temporary_output_pause`, `reduced_output`, `requires_repair_service`, or `scenario_scripted`.
- `retake_recovery_days`: number of day advances before output fully resumes.
- `defense_investment_ids`: future hooks for garrison, patrol, or fortification services.

Rules:

- Current `persistent_control` remains authoritative until capture profiles are adopted.
- Counter-capture should interrupt income or route value in a readable way; it should not silently delete a resource engine.
- High-value rare resource fronts should have higher counter-capture value, stronger guard expectations, and clearer map cues.
- Damaged/retaken states must serialize by placement id or site state, not by mutating authored site records.

## Pickup, Income, And Service Distinction

Future content must separate three economy object roles that current site content can blur.

Pickups:

- One-time local rewards.
- Usually no owner and no persistent state beyond collected/removed.
- May grant resources, progression, a clue, recovery, or a small event.
- Should not be used as the main source for resources needed by high-tier production.

Persistent income sites:

- Claimed or captured map-control objects.
- Produce daily, weekly, limited, route-linked, or conditional output.
- Need owner state, capture value, output cadence, route exposure, and AI valuation.
- Should be the primary map-control source for construction staples and major faction resources.

Services:

- Repeatable or cooldown-based interactions such as market exchange, healing, scouting, route repair, or recruitment access.
- May charge resources and may refresh daily/weekly/cooldown.
- Should not be counted as passive income unless explicitly configured.

Validation should warn when:

- A pickup has `persistent_control`.
- A repeatable service grants uncapped passive rare resources.
- A persistent income site has no output cadence or no capture value.
- A service consumes or grants an unregistered resource id.

## Market And Exchange Caps

Markets should smooth bad starts without erasing map-control pressure.

Recommended market schema concepts:

```json
"exchange_rules": {
  "market_profile_id": "public_exchange_common",
  "refresh_cadence": "weekly",
  "buy_caps": {"wood": 6, "ore": 6},
  "sell_caps": {"wood": 8, "ore": 8},
  "restricted_buy_resource_ids": ["aetherglass", "verdant_grafts", "brass_scrip", "memory_salt"],
  "requires_discovered_site_class": [],
  "scenario_cap_policy": "normal"
}
```

Rules:

- Current market behavior is gold/wood/ore oriented and must remain compatible until a market schema slice replaces it.
- Common construction resources may be buyable in small weekly quantities at poor rates.
- Rare/faction resources should not be broadly buyable from normal markets.
- Rare-resource buy access should require special market profiles, site control, discovery, faction rules, or scenario authorization.
- Weekly caps must be stored in save state once markets can consume caps.
- Scenario scripts must be able to disable, restrict, or cap markets when scarcity is the point.
- AI must evaluate market use with the same caps as the player unless a difficulty profile explicitly grants a labelled exception.

Suggested first cap stance for implementation planning:

- Keep existing wood/ore market behavior active.
- Add reports that classify current market buildings as common-resource exchanges.
- Add no rare-resource market purchases until resource registry, save cap state, UI cap display, and AI market use are ready.

## Faction Preferences

Faction resource preferences should live in data and influence sites, costs, AI, market access, and UI hints without making resources private.

Recommended profile fields:

```json
"resource_preferences": {
  "primary": ["gold", "wood", "embergrain"],
  "secondary": ["ore"],
  "awkward": ["aetherglass", "memory_salt"],
  "shortage_priority": {
    "wood": 1.2,
    "embergrain": 1.35,
    "aetherglass": 0.8
  }
}
```

Initial target preferences:

| Faction | Primary | Secondary | Awkward |
| --- | --- | --- | --- |
| Embercourt | `gold`, canonical `wood`, `embergrain` | `ore` | `aetherglass`, `memory_salt` |
| Mireclaw | `peatwax`, `gold`, raid spoils | canonical `wood`, den/recovery resources | `ore`, `aetherglass`, `brass_scrip` |
| Sunvault | `ore`, `aetherglass`, relay value | `gold` | canonical `wood`, `embergrain` |
| Thornwake | canonical `wood`, `verdant_grafts` | `gold`, recovery resources | `ore`, `brass_scrip`, `aetherglass` |
| Brasshollow | `ore`, `brass_scrip`, furnace throughput | `gold` | canonical `wood`, `embergrain`, `memory_salt` |
| Veilmourn | `memory_salt`, salvage, scouting rewards | `gold`, canonical `wood` | steady `ore`, `brass_scrip` |

Compatibility:

- Current faction economy profiles use `base_income`, `per_category_income`, pressure bonuses, readiness bonuses, and enemy strategy fields. Do not replace them in the first pass.
- Add preference fields only after a validator/report can show how current costs and outputs map to future shortages.
- AI adoption should use preferences as weights, not as absolute rules.

## Town, Recruitment, And Building Cost Compatibility

The future economy must not make current town/recruitment/building loops impossible.

Compatibility rules:

- Existing unit and building costs using `gold`, `wood`, and `ore` remain valid throughout additive schema work.
- No unit, building, hero, spell, or service should require a new resource until there is at least one reachable source, trade rule, or explicit scenario grant for that resource.
- Tier 1 and 2 recruitment should remain mostly `gold` plus at most one common resource when faction identity demands it.
- Higher-tier recruitment may introduce faction resources only after persistent sources, UI hints, AI valuation, and scenario starts are ready.
- Building cost migration should happen by faction vertical slices, not across all buildings at once.
- Market coverage helpers must not silently turn rare-resource shortages into gold-only purchases.
- Current town `economy.base_income` and `economy.per_category_income` remain compatible fields; future resource preference data should layer beside them first.

Validation reports should answer:

- Which resources each faction can produce from towns, sites, rewards, and markets.
- Which buildings and units become unaffordable if a new resource is introduced.
- Whether each faction has a minimum viable opening path on a sample map.
- Whether any capstone or high-tier unit can be bought entirely through market exchange, which should generally be rejected.

## Resource-Site Linkage To Object Schema

This plan depends on the object-schema split in `docs/overworld-object-schema-migration-plan.md`.

Ownership boundary:

- `content/map_objects.json` should own world-object identity, primary class, footprint, body tiles, approach offsets, passability class, visible state vocabulary, animation cue ids, editor placement rules, and high-level AI hints.
- `content/resource_sites.json` should own reward and economy behavior: resource outputs, claim rewards, service costs, persistent control, repeatability, recruitment payloads, transit profiles, guard profiles, and current site behavior.
- Scenario placements should continue to point to site ids and object ids through compatibility fields until a placement schema migration chooses a final join model.

Link rules:

- `persistent_economy_site` objects should normally link to resource sites that have persistent output/capture metadata.
- A resource-site output must reference a registered resource id or accepted legacy alias.
- Object `reward_summary.resource_output_ids` should be a summary of site behavior, not a second source of truth.
- Persistent resource-front bundle migration must wait until canonical `wood`, output cadence, capture profile, market caps, and validation reports are settled.

## AI Valuation Hooks

AI economy planning needs structured resource metadata before it can value object classes correctly.

Recommended resource valuation fields:

```json
"ai_resource_value": {
  "base_value": 400,
  "scarcity_multiplier": 1.0,
  "market_buy_value": 650,
  "market_sell_value": 220,
  "rare_resource": false,
  "stockpile_reserve_floor": 0
}
```

Recommended site valuation fields:

```json
"ai_economy_value": {
  "resource_value_ids": ["ore"],
  "scarcity_solver_tags": ["building_blocker", "heavy_unit_blocker"],
  "counter_capture_priority": 5,
  "route_exposure": 2,
  "defense_value": 3,
  "avoid_until_strength": "standard_guard"
}
```

Rules:

- Runtime AI should compute live value from actual state: faction shortages, current plans, guard strength, travel cost, route exposure, owner, cadence, market caps, and objectives.
- Authored AI fields are hints, not final scores.
- The first AI adoption should replace hardcoded `TRACKED_RESOURCES` with registry/adapter-driven normalization before any rare resources are used in AI treasury.
- Enemy states and commander logic must preserve old saves containing `gold`, `wood`, and `ore`.
- Debug output should expose why a resource site was targeted: shortage solved, income value, denial value, route value, objective value, and risk.

## UI And Readability Implications

The resource model must not become a dashboard over the map.

Rules:

- Common resources may remain visible in compact top/footer displays.
- Rare/faction resources should use compact icons, grouping, contextual popouts, or town/market tabs rather than a large always-open panel.
- The UI must show missing resources at the build/recruit/service decision point.
- Resource-site hover/selection should show owner, output cadence, capture state, guard risk, and route effect in compact language.
- Market UI must show exchange rates and caps before the player commits.
- `wood` displayed as Wood must be consistent across costs, rewards, market lines, and site summaries during compatibility stages.
- Resource icons and material cues need concept-art review before final UI polish, but placeholder ids can exist earlier.

Validation snapshots should eventually prove that the resource strip, town build views, recruit views, site context, and market views expose the right information without covering the scenic/play surface.

## Save And Schema Compatibility

Required save considerations:

- Add a resource schema version before canonical resource migration.
- Preserve current save version 9 behavior until a real save migration is implemented.
- Normalize resource dictionaries through a compatibility adapter that knows canonical ids and aliases.
- Store market cap state once capped exchanges exist: per town/site/profile, refresh turn/week, used buy/sell quantities, and scenario restrictions.
- Store persistent site state separately from authored definitions: owner, claimed state, damaged state, cooldown, limited charges, weekly timers, route link state, optional garrison/patrol state, and last pillaged day.
- Store AI treasury and reserved budgets with canonical ids after the migration boundary.
- Ensure scenario scripts that add resources validate aliases and unknown ids.
- Avoid storing derived AI valuation caches as authoritative save data; they should be rebuildable.

Migration risks:

- Saves with `wood` only.
- Future saves with `wood` only.
- Broken or test saves with both `wood` and `wood`.
- Existing market helper state that assumes only wood/ore exchange.
- Enemy treasury normalization that drops unknown resource ids.
- UI/resource summaries that hide resources outside `gold`, `wood`, and `ore`.

Recommended save migration policy:

1. Add adapter/report support while saves remain unchanged.
2. Add `resource_schema_version` to new saves only after runtime can read absent versions.
3. Keep old saves that contain `wood` valid without rewriting resource ids.
4. Only add future resource-id adapters when a concrete, non-wood id change requires them.

## Validation Levels

Validation should move through levels so current content stays valid until a bundle declares migration.

Level 0, current behavior:

- Existing validation continues to pass.
- Existing `gold`, `wood`, `ore`, and `experience` payloads remain valid.
- Existing content, saves, market UI, and AI helpers keep using current behavior.

Level 1, registry warnings:

- Warn when a resource key is not in the registry or allowed non-stockpile reward keys.
- Warn when a resource registry entry lacks category, display name, market tier, or UI sort metadata.
- Warn when current runtime hardcoded resource lists differ from the registry.

Level 2, availability and cadence reports:

- Report every cost and reward resource across units, buildings, heroes, artifacts, sites, scenarios, campaigns, and scripts.
- Report whether each registered stockpile resource has a source: town income, persistent site, pickup/reward, market, scripted grant, or scenario-block note.
- Warn when a persistent site lacks output cadence, capture value, or owner/capture model.
- Warn when a repeatable service looks like uncapped passive income.

Level 3, strict sample fixtures:

- Require full registry fields for a tiny fixture set.
- Require one sample pickup, one persistent economy site, one repeatable service, one market profile, one faction preference profile, and one save-migration fixture.
- Require `wood` to remain the canonical stockpile id.
- Validate daily, weekly, limited, and service cadence examples without switching production content.

Level 4, migrated bundle errors:

- Require target fields only for declared migration bundles.
- Fail migrated content that uses unknown resources, lacks source paths, has impossible early costs, or flattens rare resources through markets.
- Keep unmigrated legacy content valid through adapters.

Level 5, runtime adoption errors:

- Enforce fields once runtime systems consume them: market caps, AI treasury registry, save schema version, site cadence, and UI summaries.
- Do not deprecate legacy `wood` handling until old-save and content compatibility have passed manual and automated gates.

## Staged Migration Order

1. Planning contract.
   - This document is the contract.
   - No JSON, runtime, validator, save, renderer, or asset changes.

2. Additive schema fields.
   - Add optional resource registry/schema fields after review.
   - Keep current authored resource ids and current behavior.
   - Treat `wood` as explicit canonical metadata.

3. Validator warnings and report.
   - Add warning/report mode for resource ids, categories, source availability, output cadence, market caps, persistent-site capture values, faction preferences, and AI valuation hints.
   - Do not fail existing content yet.

4. Sample fixtures.
   - Add small non-production fixtures for registry behavior, pickup reward, persistent site output, repeatable service, market cap, faction preference, and save compatibility.
   - Validate fixtures strictly.

5. Resource registry helpers.
   - Add shared resource display, validation, spend, describe, market, save, and AI treasury helpers when runtime adoption is selected.
   - Preserve old content and saves.
   - Keep `wood` canonical.

6. Content bundle migration.
   - Migrate in small bundles:
     - registry and current three resources
     - persistent resource-front schema metadata
     - pickups and small rewards
     - common market profiles
     - rare/faction resource source fixtures
     - one or two faction vertical economy slices
   - Do not broaden all costs at once.

7. UI and economy rule adoption.
   - Adopt compact resource display, decision-point shortfall hints, site output summaries, market caps, and cadence/capture states.
   - Keep screen composition scenery-first.

8. AI adoption.
   - Move AI treasury and site valuation to registry/adapter-driven resources.
   - Add shortage-aware site targeting, market-use caps, and faction preference weights.
   - Keep debug explanations available.

9. Save cleanup.
   - Add resource schema version and migration only when a future resource migration needs it.
   - Clean up legacy writes only after old saves load, new saves resume, markets persist caps, AI treasury survives, and persistent sites serialize state.

## Rollback And Compatibility Concerns

- The first implementation must be additive and reversible.
- Existing maps and saves must continue to load when new fields are absent.
- Existing `gold`, `wood`, and `ore` content remains valid until a declared bundle migrates.
- Do not introduce rare resources into production costs before sources, markets, UI, AI, and save compatibility exist.
- If a rare-resource cost blocks a current scenario opening, roll back that bundle rather than adding hidden grants.
- If any future resource migration creates duplicate stockpiles, stop at adapter/report level and resolve before content migration.
- If market caps are not serialized safely, keep markets on current behavior.
- If AI drops unknown resources from treasury, do not enable AI use of the broader resource set.
- Renderer sprite ingestion for resource-front art must wait for the object/resource schema bundle, not lead it.
- Concept-art PNGs remain external planning evidence and are not runtime assets.

## Decisions For AcOrP Review

- Confirm that `wood` remains the permanent internal id and display concept.
- Confirm the nine-resource target set before broad JSON migration, especially `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`.
- Confirm whether the first implementation should be additive schema plus validator warning/report only, before any production content migration.
- Confirm market stance: common wood/ore exchanges first, no broad rare-resource buying until caps, source discovery, UI, AI, and saves support it.
- Confirm that `experience` remains a progression reward key outside the normal stockpile resource registry.
- Confirm capture profile expectations for persistent resource fronts, including counter-capture values, damaged states, and retake recovery.
- Confirm that faction preferences are advisory weights first, not hard locks or private faction currencies.
- Confirm that resource-site output cadence stays behavior-owned by `resource_sites.json`, while map-object schema owns presentation, approach, passability, and visible state metadata.

## Done Criteria For This Planning Slice

- Current resource/economy reality is documented.
- Target resource id policy, canonical `wood`, resource categories, output cadence, persistent-site capture values, pickup/income/service distinction, market caps, faction preferences, town/recruitment/building cost compatibility, resource-site/object linkage, AI hooks, UI implications, save compatibility, validation levels, migration order, and rollback concerns are covered.
- Planning is explicitly separated from implementation.
- The next slice is staged as additive schema and validator warning/report planning or implementation, not JSON migration, resource-site bundle migration, market implementation, renderer sprite ingestion, or save cleanup.
