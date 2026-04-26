# Strategic AI Strategy Config Audit Report

Status: completed report-only audit.
Date: 2026-04-26.
Slice: `strategic-ai-strategy-config-audit-report-10184`.

## Scope

This report audits current Embercourt and Mireclaw strategic AI config before any tuning. It classifies existing base weights, scenario overrides, reason vocabulary, site priorities, build weights, and reinforcement/raid bias as `supported`, `questionable`, `contradicted`, or `missing-evidence`.

This slice is behavior-neutral. It does not tune coefficients, edit production content JSON, change scenario balance, migrate resources, add AI state, change UI text, alter pathing/renderer/editor/save behavior, import generated assets, or add neutral encounter migration.

## Fixture Reality

Current `content/scenarios.json` is the source of truth:

| Scenario | Player faction | Enemy faction reality | Audit use |
| --- | --- | --- | --- |
| `river-pass` | `faction_embercourt` | `faction_mireclaw` | Direct Mireclaw pressure fixture. |
| `prismhearth-watch` | `faction_sunvault` | `faction_mireclaw` | Direct Mireclaw sabotage/relay-pressure fixture. Not Embercourt evidence. |
| `glassroad-sundering` | `faction_sunvault` | `faction_embercourt` | Current direct Embercourt enemy fixture. |
| `ninefold-confluence` | `faction_embercourt` | Mireclaw plus Sunvault, Thornwake, Brasshollow, Veilmourn | Broad Mireclaw multi-faction context. No Embercourt enemy claim. |

Decision: `prismhearth-watch` must not be cited as Embercourt evidence. The earlier planning assumption that it exposed Embercourt is contradicted by current fixtures.

## Focused Report Inputs

Rerun focused reports before writing this audit:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Result: all four focused reports returned `"ok": true`.

Important current evidence:

- Mireclaw River Pass: full target selector can still choose `riverwatch_hold`, while resource ordering puts `river_free_company` and `river_signal_post` first when player-controlled.
- Embercourt Glassroad: full target selector chooses `halo_spire_bridgehead`, while resource ordering puts `glassroad_watch_relay` first and `glassroad_starlens` second when player-controlled.
- Mireclaw town governor: `building_slingers_post`, `feeds raid hosts`, active raid reinforcement, commander rebuild, and emergency garrison stabilization are all report-proven.
- Embercourt town governor: `building_market_square`, strong market/income debug components, emergency garrison stabilization, and shared raid/rebuild surfaces are report-proven, but selected public build wording is still `builds pressure`.

## Base Strategy Weights

| Area | Embercourt current config | Mireclaw current config | Classification | Audit decision |
| --- | --- | --- | --- | --- |
| Economy/readiness posture | Base gold `60`, readiness `8`, pressure bonus `0` | Base gold `35`, wood `1`, readiness `2`, pressure bonus `2` | Supported | Clear intended contrast: Embercourt safe civic base, Mireclaw pressure economy. |
| Build categories | Civic `1.2`, economy `1.2`, support `1.3`, dwelling `0.95`, magic `0.75` | Dwelling `1.35`, support `1.15`, economy `0.95`, civic `0.8`, magic `0.7` | Supported | Matches faction bible: civic infrastructure versus den/replacement pressure. |
| Build values | Income `1.15`, readiness `1.45`, pressure `0.7`, growth `0.9` | Growth `1.35`, pressure `1.6`, income `0.85`, readiness `0.7` | Supported | Report output confirms Market Square versus Slingers Post split. |
| Raid target weights | Town `1.35`, resource `0.75`, encounter `0.9`, hero `0.8` | Resource `1.2`, encounter `1.15`, hero `1.25`, town `0.9` | Supported with one question | Good contrast. Embercourt's low base resource value is acceptable only because scenario overrides and family weights lift charter assets when needed. |
| Site family weights | Faction outpost `1.35`, neutral dwelling `0.85`, frontier shrine `0.8` | Neutral dwelling `1.4`, frontier shrine `0.95`, faction outpost `0.85` | Supported with metadata caveat | Contrast is useful, but family names are too coarse for future civic infrastructure versus marsh-den distinctions. |
| Reinforcement | Garrison `1.35`, raid `0.85`, ranged `1.25`, high-tier `1.15` | Garrison `0.75`, raid `1.35`, melee `1.25`, low-tier `1.2` | Supported | Matches front-holding versus raid/replacement identity. |
| Raid posture | Threshold `1.15`, pressure commitment `1.1`, objective `1.2`, town siege `1.35`, site denial `0.8`, hero hunt `0.8` | Threshold `0.85`, max active `+1`, pressure commitment `0.85`, site denial `1.35`, hero hunt `1.25`, town siege `0.85` | Supported | Clean personality contrast before scenario overrides. |

No base value is currently contradicted by report evidence. The only base-weight question is whether Embercourt's `resource: 0.75` and `frontier_shrine: 0.8` are too low once broader civic infrastructure content arrives. Current Glassroad overrides compensate, so this is a later tuning candidate, not a change.

## Scenario Overrides

| Scenario | Current override summary | Classification | Audit finding |
| --- | --- | --- | --- |
| `river-pass` / Mireclaw | Priority targets: `riverwatch_hold`, `river_signal_post`, `river_free_company`, `warcrest_ruin`; resource `1.35`, artifact `1.05`, site denial `1.5`, hero hunt `1.15`, raid bias `1.45` | Supported | Strongly reinforces Riverwatch signal-yard denial while preserving `riverwatch_hold` as the legitimate town front. |
| `prismhearth-watch` / Mireclaw | Priority targets: `prismhearth_hold`, `prismhearth_watch_relay`, `prismhearth_lens_house`, `prismhearth_halo_reserve`; resource `1.3`, encounter `1.25`, hero hunt `1.35`, objective `0.95` | Supported with fixture correction | Coherent sabotage/relay fixture against Sunvault. It is not Embercourt evidence. |
| `glassroad-sundering` / Embercourt | Priority targets: `halo_spire_bridgehead`, `glassroad_watch_relay`, `glassroad_starlens`, `glassroad_beacon_wardens`; faction outpost `1.55`, frontier shrine `1.2`, town `1.4`, resource `0.95`, encounter `1.2`, town siege `1.5` | Supported | Correctly turns Embercourt into charter-road, relay, town-front pressure without making it generic resource raiding. |
| `ninefold-confluence` / Mireclaw | Priority targets: `ninefold_embercourt_survey_camp`, `bog_drum_crossing`, `dwelling_bogbell_croft`, `ninefold_basalt_gatehouse_watch`; neutral dwelling `1.4`, faction outpost `1.5`, frontier shrine `1.2`, town/resource `1.2`, encounter `1.1`, site denial `1.4`, town siege `1.3` | Questionable but acceptable as broad-map context | Coherent as a multi-front Mireclaw rival, but less sharply "Mireclaw" than River Pass because it lifts town and faction-outpost pressure for the broad survey-camp context. Not a same-scenario A/B personality proof. |
| `ninefold-confluence` / Embercourt | No Embercourt enemy faction block | Contradicted if claimed | Do not cite Ninefold as Embercourt enemy AI evidence. |

No override currently needs tuning before a live capture/counter-capture proof. The Ninefold Mireclaw block is the most likely later review target because broad-map context mixes town siege, faction outpost, neutral dwelling, and encounter pressure without a focused report gate.

## Public Reason Vocabulary

| Surface | Current phrases | Classification | Notes |
| --- | --- | --- | --- |
| Target assignment | `town siege remains the main front`, `recruit and income denial`, `income and route vision denial`, `route pressure`, `recruit denial` | Supported | Compact and action-readable. Score-table fields stay out of public output. |
| Pressure summary | `town siege remains the main front` | Supported | Shared state reason, not unique faction personality by itself. |
| Site seizure | `recruit and income denial`, `income and route vision denial` by reason-code path | Supported | Strong for Mireclaw signal-yard denial. |
| Site contest | `objective front` | Supported as generic | Useful state phrase, not faction-specific. |
| Town build | `feeds raid hosts`, `builds pressure`, `unlocks recruits`, `stabilizes garrison`, `expands income`, `supports recovery`, `town development` | Questionable for Embercourt | Current Embercourt Market Square report says `builds pressure` even though dominant debug components are market and income. The compact phrase is valid, but weak as civic/readiness personality evidence. |
| Recruitment/garrison/raid/rebuild | `stabilizes garrison`, `feeds raid hosts`, `rebuilds command` | Supported as shared vocabulary | These prove reusable state surfaces. They should not be overclaimed as unique faction identity. |

Later phrase candidate: make Embercourt economy/readiness builds more often expose `expands income`, `route security`, or `garrison readiness` when those reason codes dominate. This is a public reason/vocabulary candidate, not a coefficient or behavior change.

## Resource And Site Family Priorities

| Placement | Current role in audit | Classification | Finding |
| --- | --- | --- | --- |
| `river_free_company` | River Pass Mireclaw priority target, neutral-dwelling family, recruit plus income denial | Supported | Top resource target when player-controlled; current public reason `recruit and income denial` is strong. |
| `river_signal_post` | River Pass Mireclaw priority target, faction-outpost family, daily income plus route vision | Supported | Second resource target when both signal-yard sites are player-controlled; public reason is strong. |
| `glassroad_watch_relay` | Glassroad Embercourt priority target, faction-outpost family | Supported | Top Embercourt resource target in focused report; matches charter relay/front identity. |
| `glassroad_starlens` | Glassroad Embercourt priority target, frontier-shrine family | Supported with caveat | Ranks second; current public reason `route pressure` is generic because metadata/reason codes are coarse. |
| `glassroad_beacon_wardens` | Glassroad Embercourt priority encounter | Supported | Priority target and `encounter: 1.2` override align with road-front wardens. |
| `prismhearth_watch_relay` | Prismhearth Mireclaw priority target | Supported | Fits sabotage against Sunvault relay infrastructure. |
| `prismhearth_lens_house` | Prismhearth Mireclaw priority target, recruit-support site | Supported | Fits recruit/support denial. |
| `bog_drum_crossing` | Ninefold Mireclaw priority target, Mireclaw-controlled outpost | Supported as broad context | Good marsh-front signal, but needs focused proof before tuning. |
| `dwelling_bogbell_croft` | Ninefold Mireclaw priority neutral dwelling | Supported | Matches Mireclaw neutral-dwelling/den-growth bias. |
| `ninefold_basalt_gatehouse_watch` | Ninefold Mireclaw priority guard encounter | Questionable | Useful multi-front guard target, but not specifically Mireclaw unless future capture/counter-capture or guard-link AI proof validates it. |

Missing metadata remains future planning: site family vocabulary cannot yet distinguish civic relay, charter road asset, recruit yard, marsh den, route law object, and guarded resource front with enough precision. Do not fix that by editing production JSON in this slice.

## Build Category And Value Weights

| Faction | Current matrix | Focused report evidence | Classification |
| --- | --- | --- | --- |
| Embercourt | Civic `1.2`, economy `1.2`, support `1.3`; income `1.15`, readiness `1.45`, pressure `0.7` | Selects `building_market_square`; dominant debug components include weighted market `801.55`, income `368`, quality `216`, pressure `98`; public reason is `builds pressure` | Supported config, questionable phrase |
| Mireclaw | Dwelling `1.35`, support `1.15`; growth `1.35`, pressure `1.6`, readiness `0.7` | Selects `building_slingers_post`; dominant debug components include quality `1285.2`, growth `972`, pressure `896`, raid need `130.5`; public reason is `feeds raid hosts` | Supported |

Embercourt build tuning is not justified yet. The config is doing the right broad thing; the weak part is public reason precedence and the limited town/building content available in the focused fixture.

Mireclaw build weights are currently the cleanest personality evidence in the audit. They explain Slingers Post and replacement-loop pressure while still allowing emergency garrison stabilization when the state demands it.

## Reinforcement, Garrison, Raid, And Commander Rebuild Bias

| Area | Classification | Finding |
| --- | --- | --- |
| Embercourt garrison/ranged/high-tier bias | Supported | Config supports front-holding and readiness. Focused report routes recruits to garrison under a critical wall gap. |
| Embercourt raid/rebuild outputs | Supported as shared behavior | Staged active raid and commander rebuild work, but they prove state handling more than distinct Embercourt hero-role identity. |
| Mireclaw raid/melee/low-tier bias | Supported | Config and focused report support active raid reinforcement and low-tier replacement flow. |
| Mireclaw emergency garrison stabilization | Supported | Low garrison bias does not prevent defense when the critical garrison gap dominates. |
| Commander-role personality | Missing-evidence | Current reports rebuild named commanders, but there is no full AI hero role/task state. Do not claim distinct commander doctrine yet. |

## Classification Summary

Supported:

- Embercourt base civic/economy/support/readiness, town/front, garrison, ranged, and high-tier bias.
- Mireclaw base dwelling/growth/pressure, resource/encounter/hero, neutral-dwelling, raid, melee, low-tier, site-denial, and hero-hunt bias.
- River Pass and Glassroad scenario overrides.
- Prismhearth as Mireclaw sabotage evidence.
- Compact public denial and front-pressure reason vocabulary.

Questionable:

- Embercourt public build phrase `builds pressure` for Market Square despite market/income/readiness debug evidence.
- Embercourt low base `resource` and `frontier_shrine` weights if future scenarios depend on civic infrastructure outside explicit overrides.
- Ninefold Mireclaw override sharpness because broad-map context lifts several pressure families at once.
- `ninefold_basalt_gatehouse_watch` as a Mireclaw personality target without focused proof.

Contradicted:

- Any claim that `prismhearth-watch` is Embercourt enemy evidence.
- Any claim that `ninefold-confluence` has Embercourt as an enemy faction.
- Any claim that Mireclaw always prefers resource denial over town siege; current River Pass town front can legitimately dominate full target selection.
- Any claim that Embercourt's public build wording already reads clearly civic/readiness-specific.

Missing evidence:

- Normal live-client enemy-turn pacing, arrival frequency, and visible pressure comparison.
- Capture/counter-capture proof for either faction taking, losing, retaking, or defending persistent sites.
- Same-scenario Embercourt versus Mireclaw A/B comparison.
- Commander-role/task-state personality.
- Durable AI event logs, save migration, adventure-spell evaluation, artifact planning, and broader strategic planner proof.

## Bounded Future Candidates

These are candidates only; no change is made here.

1. Public reason wording candidate: audit `EnemyTurnRules._town_build_public_reason(...)` precedence so Embercourt income/market/readiness-heavy builds can surface `expands income`, `route security`, or `garrison readiness` when appropriate, while keeping output compact.
2. Embercourt infrastructure coefficient candidate: if a capture/counter-capture proof shows charter assets under-ranking without scenario overrides, consider a bounded review of Embercourt base `raid_target_weights.resource` and `site_family_weights.frontier_shrine`.
3. Ninefold Mireclaw override candidate: after broad-map pressure proof, check whether `faction_outpost: 1.5`, `town: 1.2`, and `town_siege_weight: 1.3` make the faction read too much like general survey-camp siege instead of marsh counter-pressure.
4. Metadata candidate: future object/resource-site metadata should distinguish civic relay, route law, recruit yard, marsh den, guarded economy front, and neutral dwelling rather than overloading three current site families.

Required validation for any later coefficient or phrase change:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Manual live-client gate trigger remains deferred until a follow-up changes coefficients, public turn text, raid cadence, reinforcement strength, target ordering, arrival frequency, visible map pressure, capture/counter-capture behavior, durable event logs, full AI hero task state, save state, pathing, renderer, editor behavior, or production scenario content.

## Next Slice Decision

Recommended next concrete slice: `strategic-ai-capture-countercapture-defense-proof-planning-10184`.

Rationale: the config is mostly coherent enough to avoid immediate coefficient tuning. The largest blocker is missing proof that these personalities can express themselves through actual site control: Mireclaw retaking or denying a logistics site, and Embercourt defending or stabilizing a charter front. A narrow capture/counter-capture planning slice should define one proof path, likely using `river_signal_post` / `river_free_company` for Mireclaw or `glassroad_watch_relay` / `glassroad_starlens` for Embercourt, before coefficient tuning or commander-role state planning.

Deferred:

- Coefficient tuning and behavior tuning.
- Commander-role state planning.
- Production JSON migration.
- `content/resources.json`, `wood` to `timber`, rare resources, and market-cap overhaul.
- Pathing/body-tile/approach adoption, renderer/editor/save changes, generated PNG import, neutral encounter migration, durable AI event logs, full AI hero task state, broad AI rewrite, and River Pass rebalance.
