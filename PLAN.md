# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-26
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy the referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.

## Current Tactical State

Current phase: **Phase 5 - Playable Alpha Baseline**.

- Current implementation slice: `strategic-ai-adventure-spell-execution-10184`, completed to let enemy commanders cast bounded self-movement overworld spells during live raid movement when the spell changes objective reach.
- Latest completed slice: `strategic-ai-adventure-spell-execution-10184`.
- Latest completed slice: `strategic-ai-local-recruitment-support-10184`.
- Latest completed slice: `strategic-ai-regroup-task-board-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-task-board-10184`.
- Latest completed slice: `strategic-ai-artifact-task-board-10184`.
- Latest completed slice: `strategic-ai-encounter-objective-task-board-10184`.
- Latest completed slice: `strategic-ai-task-retask-cancellation-10184`.
- Latest completed slice: `strategic-ai-spawn-saved-task-commander-selection-10184`.
- Latest completed slice: `strategic-ai-task-resumption-10184`.
- Latest completed slice: `strategic-ai-task-actor-lifecycle-10184`.
- Latest completed slice: `strategic-ai-task-lifecycle-reconciliation-10184`.
- Latest completed slice: `strategic-ai-persistent-hero-task-board-10184`.
- Latest completed slice: `battle-layout-smoke-followup-10184`, expanded by owner direction into the battle presentation runtime slice.
- Latest completed slice: `combat-mireclaw-packhunter-trait-trim-10184`.
- Previous completed slice: `combat-mireclaw-half-anti-ranged-shielding-10184`.
- Previous completed slice: `combat-mireclaw-t6-t7-hp-revert-10184`.
- Previous completed slice: `battle-benchmark-all-live-hero-matrix-10184`.
- Previous completed slice: `hero-roster-live-diversity-10184`.
- Previous completed slice: `combat-mireclaw-late-anti-ranged-counter-10184`.
- Previous completed slice: `combat-mireclaw-late-tank-buff-10184`.
- Previous completed slice: `combat-thornwake-week2-buff-10184`.
- Previous completed slice: `combat-thornwake-t6-ranged-balance-10184`.
- Previous completed slice: `combat-sunvault-t6-melee-balance-10184`.
- Previous completed slice: `magic-resistance-countercontrol-10184`.
- Previous completed slice: `battle-spell-valuation-counterplay-followup-10184`.
- Previous completed slice: `battle-spell-parity-counterplay-10184`.
- Previous completed slice: `magic-town-study-full-tier-access-10184`.
- Previous completed slice: `magic-spell-tier-power-bands-10184`.
- Paused slice: `combat-faction-pair-stat-tuning-10184` remains needs-tuning; broad stat tuning is paused while the owner-selected battle presentation runtime slice improves player-readable combat flow.
- Previous completed slice: `battle-benchmark-no-round-cap-10184`.
- Previous completed slice: `combat-feel-balance-pass-10184`.
- Earlier completed slice: `battle-fast-faction-benchmark-10184`.
- Earlier completed slice: `economy-native-rmg-required-source-support-10184`.
- `ops/progress.json` remains the operational source of truth for completed evidence, validation commands, and paused/superseded slice state.

Latest economy/town evidence:
- Runtime-inclusive economy/town scorecard: 30/30.
- Deterministic economy/town scorecard: 15/15.
- Authored town development completion: day 28-30.
- Strict Small Native RMG package adoption report: passing for all nine live resource sources, generated town source routes, guarded rare-source pressure, player/enemy/neutral generated town runway pacing, and seven-tier town recruitment within 36x36 one-level land scope.
- Current player-balance finding: Brasshollow, Thornwake, and Veilmourn have the clearest economy identity; Embercourt, Mireclaw, and Sunvault still need deeper identity beyond rare-resource pressure.
- Current rare-cost model: every town uses all six rare resources in high-tier development. The faction signature rare remains highest pressure, one secondary rare is about half pressure, and each remaining rare is about one-third pressure.
- Authored rare-source breadth is paused for this balance slice. The owner-selected balance surface is Native RMG generated maps, not authored scenario/source placement.
- Strict Small generated-map economy evidence is scoped to 36x36 one-level land packages. It is authoritative for this balance slice, but not broad RMG economy approval for larger sizes, water, underground, or broad template families.

Current product focus:
- Keep building toward a playable alpha baseline.
- Prefer player-readable, live-loop improvements over adding new report gates.
- Current strategic AI target: build from the baseline KPI audit into production behavior. Live commander/raid target choices now write normalized `enemy_states[].hero_task_state`, reuse saved active tasks for later target selection, reserve exclusive targets across active task boards, complete captured resource and artifact tasks, reconcile saved tasks against current target ownership/existence, suspend or invalidate saved tasks whose commander actor is missing, recovering, or unable to deploy, reactivate suspended saved tasks once their commander is deployable again, make new raid spawning prefer deployable commanders with reachable saved tasks before falling back to roster rotation, preserve explicit cancelled history when a commander is retasked to a different objective, persist objective-front encounter targets as first-class durable tasks, and keep all of that continuity without a save-version bump.
- Current battle-presentation target: battle resolution should emit a readable event stream for movement, strikes, shots, spell casts, damage, healing, status changes, resisted/immune outcomes, deaths, retaliation, morale/cohesion, and momentum; the battle scene should consume that stream with normal/fast/instant playback controls while keeping combat math unchanged.
- Use the fast battle-balance benchmark evidence to tune faction-pair combat spread now that fake round-cap outcomes have been removed, the public benchmark report uses side-neutral `side_a`/`side_b` terminology, and spell-enabled benchmark availability follows the same Native RMG week surface as army snapshots.
- Before more broad unit-stat nudges, strengthen the magic system as a strategic layer: spell availability, school coverage, field-magic access, and player-readable town/generated-map spell study should improve before trying to balance magic-focused heroes against raw-combat heroes.
- Latest magic follow-up: resistance and counter-control mechanics now run in live battle and in the fast benchmark before remaining spell-enabled benchmark outliers are treated as pure faction/unit imbalance.
- Campaign production remains deferred until explicitly selected in a later phase.

## Selectable Near-Term Work

Before starting any item, add or select a concrete slice in `ops/progress.json`, mark it `in_progress`, and keep validation evidence there.

Recommended next slices:
- `strategic-ai-long-run-seed-matrix-10184`: expand strategic AI validation from focused fixtures into multi-week generated-map seed matrices once task ownership is durable enough to measure.
- `combat-faction-pair-stat-tuning-10184`: tune unit stats, growth, and ability power from the full benchmark outlier rows to reduce deterministic faction-pair win-rate spread.
- `battle-spell-valuation-counterplay-followup-10184`: tune spell AI valuation and counterplay from the spell-enabled benchmark evidence, especially heavy control preference, before treating the new outlier set as pure unit-stat imbalance.
- `battle-layout-smoke-followup-10184`: continue battle layout smoke only if the prior manual stop left actionable evidence or a reproducible UI/runtime issue.
- `strategic-ai-quality-pass-10184`: selected for the baseline KPI harness/audit. Do not treat it as full strategic AI production readiness.
- `rmg-small-generalization-hardening-10184`: harden strict Small generated-map evidence without claiming larger sizes, water, underground, or broad template parity.
- `ux-polish-player-comprehension-10184`: improve onboarding, tooltips, town planning clarity, battle intent feedback, save/load confidence, and reduce debug-like seams.
- `packaging-platform-readiness-followup-10184`: continue clean Windows/Linux packaging and smoke-test hardening.
- `headless-balance-harness-next-10184`: expand automated balance harness depth before scaling content.

Do not select:
- campaign/scenario production breadth unless the owner explicitly changes priority;
- broad RMG parity claims from strict Small evidence;
- final art direction, final audio, or release packaging claims from generated/runtime placeholder layers;
- new validation gates that merely make reports pass without improving player-readable game behavior.

## Magic Availability And Strategic Influence Target

The immediate magic slice should improve what players can learn and do with magic without pretending that magic-focused heroes and raw-combat heroes are balanced yet.

Target shape:
- the live authored spell catalog should stay above a 100-spell floor before balance work treats magic variety as credible;
- every live magic school should have broad authored spell presence, with at least a dozen schema-valid spells per school;
- overworld magic should have at least 20 authored spells across movement and scouting support;
- spell tiers must carry real numeric meaning: tier 1 spells are cheap and limited, tiers 2-3 are useful/strong midgame tools, tier 4 spells are major swings, and tier 5 spells are expensive very-strong effects;
- tier scaling should apply to mana costs, damage and power scaling, wounded bonuses, buff/control duration, modifier magnitude, recovery, movement restoration, and scouting radius;
- every authored town should reach tier 5 spell study through its full development tree without extending the existing town-development day target;
- every authored spell should be reachable through fully developed town study access, not left as catalog-only content;
- Native RMG/generated spell rewards should include tier 1-5 candidates across all schools, even though town development remains the primary full-catalog access path;
- town study should expose faction school access plus Old Measure access by spell tier instead of relying only on short hand-authored per-town lists;
- town study should expose more than faction-flavored battle buffs/damage, especially field scouting and route tools;
- Native RMG/generated reward pools should include multiple spell-access candidates instead of only Beacon Path;
- new field effects must mutate bounded strategic state directly, not just add another report surface;
- no rare-resource spell-cast costs, caster-unit system, school mastery, or final magic-vs-might balance claim is part of this work.

## Economy Rare-Resource Target

The current economy identity pass moves towns away from a one-signature-rare model. Balance evidence for map-source access must be based on Native RMG generated packages for this slice, not authored scenario maps.

Target cost-pressure model for every town template:
- Every rare resource should appear in at least one town-development cost.
- The town faction's signature rare resource should remain the highest-pressure rare and should still define the core late-game faction bottleneck.
- One secondary rare resource should create about half as much pressure as the faction signature rare.
- Each remaining rare resource should create about one-third as much pressure as the faction signature rare.
- `gold`, `wood`, and `ore` should remain the dominant common-resource development shape; multi-rare costs should not turn the economy into all-rare-only pricing.
- Rare-resource use should create meaningful player choices in different building categories, not just append small costs to arbitrary filler buildings.
- Native RMG generated-package support, guarded access, AI town development, and player-facing town UI must be updated with the cost model so every required rare can be acquired through play.

Example pressure interpretation if a faction's signature rare target remains near the current 28-30 total spend:
- faction signature rare: roughly 28-30 total pressure;
- secondary rare: roughly 14-15 total pressure;
- each remaining rare: roughly 9-10 total pressure.

Implemented target at this point:
- signature rare: 28-30 total pressure depending on existing faction-specific upgrade costs;
- secondary rare: 14 total pressure;
- each remaining rare: 9 total pressure;
- all six rare resources appear in high-tier unit-building costs for every faction ladder.

## Battle Balance Benchmark Target

The selected battle-balance slice is a fast Python benchmark, not a final combat tuning claim. It should use current content and port the live battle math closely enough to make faction matchup iteration cheap before wider tactical tuning.

Required benchmark shape:
- pure Python, no Godot runtime for normal benchmark runs;
- live `content/*.json` faction, unit, hero, spell, town, and building data;
- hero spellbooks should include starting battle spells plus Native-RMG week-tier town-study battle spells from faction school access; authored representative-town build timing must not shape the faction matrix;
- reports should expose per-week spellbook coverage and actual spell-cast summaries by school, tier, effect, and faction;
- ordered non-self faction matrix for all six factions;
- deterministic seed count, with `--quick`, `--seeds`, `--weeks`, `--json`, and `--gate` options;
- week 1 army snapshots: initial starting growth plus one recruited week capped at T1-T3;
- week 2 snapshots: initial starting growth plus week-one T1-T4 and week-two T1-T5 recruitment;
- week 3 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three T1-T7 recruitment;
- week 4 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three/week-four T1-T7 recruitment with fully developed growth for final full-tier ticks;
- JSON report rows for win rates, average rounds, action mix, casualties by tier, battle consequences, pair summaries, week summaries, and outliers.

Initial target bands:
- faction-pair dominant win rates should land within 45-55% before the combat-balance goal is complete;
- ordered faction rows, outcomes, casualties, and week side-bias summaries should use `side_a`/`side_b`, not scenario ownership labels;
- army snapshots should use Native RMG-suitable faction/unit growth rather than authored representative-town build logs;
- side bias should stay low;
- no fake stalemate outcome should exist in benchmark data; emergency simulation guard hits are structural failures;
- average rounds should remain readable, and later-week battles should take more turns on average than early battles.

The first benchmark should report outliers as tuning evidence. Do not tune away failures blindly just to make the initial benchmark look green.

## Magic Resistance And Counter-Control Target

The current magic slice turns resistance and counter-control from artifact/theme metadata into live battle mechanics.

Target shape:
- units define bounded `spell_resistance_pct`, `control_resistance_pct`, `spell_school_resistance_pct`, and `status_immunity_ids`;
- T1-T3 units have no general natural resistance, T4-T5 gain light spell resistance, T6-T7 gain stronger spell and control resistance, and faction-school units gain modest own-school resistance;
- hero knowledge contributes bounded incoming spell/control resistance through battle payloads;
- artifacts can add live spell, control, and school resistance bonuses, starting with Choir Tuning Fork;
- cleanse/countermagic spells grant temporary immunity to the statuses they cleanse;
- spell damage is mitigated but still lands for at least one damage, while status/control riders can be resisted or blocked by immunity;
- mana is consumed even when the target resists or is immune;
- guard/status control tiles and tactical status effects remain engagement metadata, not a replacement for body blocking or damage resolution;
- Battle AI and the fast benchmark value expected resisted damage and control success chance instead of assuming all spells land fully;
- the fast benchmark reports resisted spells, immunity blocks, prevented damage, and top resisted spell ids.

Non-goals:
- do not claim final magic-vs-might or faction battle balance from this slice;
- do not add caster-unit spellbooks, rare-resource spell-cast costs, or school mastery;
- do not add broad new report gates beyond one focused resistance/counter-control runtime report.

## Slice Status Model

Each executable slice should map to one `ops/progress.json` entry with:
- `id`: stable slice id ending in `-10184`.
- `phase`: project phase.
- `purpose`: why the slice exists.
- `sourceDocs`: source requirements or evidence docs.
- `implementationTargets`: expected files/systems/content/tooling/report surfaces.
- `baselineChecks`: generic health checks required before completion.
- `sliceEvidence`: focused proof that the slice requirement was met.
- `completionCriteria`: objective completion bar.
- `nonGoals`: explicit boundaries when scope is risky.

Valid operational statuses:
- `pending`: planned, not started.
- `in_progress`: active implementation or review.
- `blocked`: cannot proceed; blocker must be named.
- `completed`: implementation and validation meet criteria.
- `docs_ready`: requirements/design/report exists; implementation is not complete.
- `paused`: intentionally delayed until selected again.
- `pending_after_implementation`: review/gate slice waiting for implementation output.
- `superseded`: replaced by a later accepted slice/path.

## Work Selection Gates

Before starting any worker:
1. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`.
2. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`.
3. Confirm or create the selected slice with source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

State: complete unless document/process drift reappears.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

State: complete as proof history. Reopen only for regressions or explicit owner direction.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

State: foundation evidence is broad but not product completion. Completed implementation/report evidence lives in `ops/progress.json` and `docs/`.

### Phase 3 - HoMM3-Style Random Map Generator Rework

Goal: translate HoMM-style random-map structure into original content and systems.

Current boundary:
- Strict Small 36x36 one-level land package/session evidence exists.
- Larger sizes, water, underground, broad template families, final reward ecology, and full parity remain incomplete.
- Native/generated package adoption evidence must remain scoped and must not be presented as broad RMG production readiness.

### Phase 4 - Headless AI Agent Balance Harness

Goal: run scenarios, economy loops, battles, AI turns, and balance checks faster than manual UI play.

State: meaningful harness/report foundations exist. Further work should make balance changes cheaper and more player-relevant, not merely add pass/fail surfaces.

### Phase 5 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Current emphasis:
- economy and town development are strongly validated but still need deeper faction identity;
- battle and strategic AI need quality and balance passes;
- UX should prioritize player comprehension over debug/report visibility;
- Native RMG generated Small-map source support and guard pressure are the selected economy balance surface;
- authored rare-source breadth is deferred until authored-map work is explicitly selected again.

Exit criteria remain:
- multiple scenarios/skirmish setups work end-to-end;
- at least two factions are meaningfully playable and distinct;
- town, battle, overworld, save/load, AI, economy, and UI loops hold together under repeated play;
- major UX surfaces are understandable without debug/report panels.

### Phase 6 - Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

Do not enter broadly until Phase 5 playable-alpha evidence is stable and owner-approved.

### Phase 7 - Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with the systemic breadth, density, and replayability expected from classic Heroes-style strategy games.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or the owner explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape:
- `project.md` contains durable strategy and current strategic focus.
- `PLAN.md` contains compact tactical state, selection rules, and near-term slice candidates.
- `ops/progress.json` contains operational status, detailed evidence, validation history, and completed-slice records.
