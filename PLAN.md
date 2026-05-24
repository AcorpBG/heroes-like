# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-03
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy its referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.

## Current Tactical State

Current phase: **Phase 5 - Playable Alpha Baseline**.

Completed slice on 2026-05-24: `economy-runtime-market-cap-persistence-20260524-10184` closes the selected normal-market cap persistence gap in the owner-directed economy/town-development goal. Town market state now exposes weekly common-resource buy/sell caps, river and resonant exchange upgrades receive faction-flavored cap bonuses, live market actions disable and reject over-cap exchange orders, cap-aware readiness is used by town/AI economy surfaces, and each town persists weekly `market_usage` through save/resume. The focused Godot report exhausts buy and sell caps, proves over-cap rejection, verifies save/resume keeps the exhausted weekly caps, and advances to the next week to prove caps reset. Normal markets remain wood/ore only; rare resources remain tied to authored sources and high-tier development costs. This is a runtime market-cap production-readiness increment, not final scenario-wide economy tuning, final market UI art, broad AI economy strategy, or campaign balance approval.

Completed slice on 2026-05-24: `economy-live-stockpile-resource-surface-breadth-20260524-10184` closes the remaining common-resource-only surface gap in the live economy wiring. The slice makes global resource summaries, generated-map resource text, runtime stockpile normalization, income merging, spending, and save/resume evidence preserve the full nine-resource stockpile. The focused Godot report proves full-resource visible summaries, zero-valued rare audit summaries, rare site income, live end-turn mutation, and save/resume continuity. This is a resource-wiring production-readiness increment, not final scenario-wide economy tuning, market-cap persistence, broad AI economy planning, or final town UI/art.

Completed slice on 2026-05-24: `economy-authored-town-development-breadth-20260524-10184` extends the owner-directed economy/town-development goal from seed-town proof to authored-town breadth. The slice gives every authored town a 30-turn development balance profile, ensures every faction town exposes the owning faction's seven signature unit-building ladder, expands deterministic and live Godot town-development reports from 6 seed towns to all 15 authored towns, and keeps high-tier signature buildings tied to faction rare resources. Focused evidence covers 15/15 authored towns and 15/15 full seven-building faction ladders, with every authored town completing within 30 turns. This is an authored-town production-readiness increment, not final scenario-wide economy tuning, broad AI economy planning, market-cap persistence, or final town UI/art.

Completed slice on 2026-05-24: `economy-town-development-runtime-balance-proof-20260524-10184` strengthens the owner-directed town-economy goal by moving the 30-turn seed-town balance proof through live Godot town construction rules. The focused runtime report creates six seed-town sessions, drives actual `OverworldRules`/`TownRules` build surfaces, proves same-day second builds are rejected, advances day income through the live end-turn path, verifies high-tier rare-resource spending through live build deductions, and completes all authored seed-town development within the 30-turn target. Current runtime completion days are Embercourt 17, Mireclaw 18, Sunvault 18, Thornwake 7, Brasshollow 7, and Veilmourn 7. This is a runtime evidence increment, not final scenario-wide economy tuning, market-cap persistence, broad AI economy planning, or final town UI/art.

Completed slice on 2026-05-24: `economy-town-development-live-balance-gate-20260524-10184` moves the owner-directed town-economy goal out of report-only rare-resource staging. The slice activates the full nine-resource stockpile set for live runtime normalization and validation, keeps normal markets bounded away from rare-resource buying, enforces one build per town per day, and adds a deterministic 30-turn seed-town development balance report for the six faction seed towns. Focused validation proved all six seed towns complete within the 30-turn target, with completion days ranging from 8 to 21. This is an economy/town-development production-readiness increment, not final market-cap persistence, final scenario balance, broad AI economy planning, or final town UI/art.

Completed slice on 2026-05-24: `battle-layout-death-retention-handoff-smoke-alignment-20260524-10184` realigns the routed battle layout smoke with death-animation retention, compact battle presentation, and truthful non-battle save recaps. Killed target cells may remain visible only as zero-health, non-selected, non-legal, non-occupied presentation cells; routed final-kill menu/outcome checks now read the real latest loadable summary; non-battle save recaps no longer fall back to stale battle aftermath copy; and BattleShell collapses secondary banner/rail/footer surfaces on 1280x720 and 1024x600 while keeping primary combat controls framed. The focused smoke can now isolate viewport cases with `BATTLE_LAYOUT_SMOKE_VIEWPORT_INDEX`, and the full all-viewport battle layout smoke passes. This is a regression and compact-layout fix, not final battle UI art direction, final animation timing, broad combat balance, or a battle UX redesign.

Completed slice on 2026-05-24: `battle-autoplay-hard-difficulty-watch-retune-20260524-10184` reduces the focused normal/hard difficulty sweep's hard-mode watch queue from 6 medium-priority items to 3 while keeping the normal row clear. The pass applies bounded authored combat tuning to River Pass Ghoul Grove, Blackfen Gateward, and Willow Mill Pack; `tests/battle_autoplay_difficulty_sweep_report.gd` now requires `MAX_NORMAL_TUNING_QUEUE_ITEMS := 0` and `MAX_HARD_TUNING_QUEUE_ITEMS := 3`. Current focused evidence keeps both rows passing combat-feel and balance-matrix gates, normal `tuning_queue_item_count = 0`, hard `tuning_queue_item_count = 3`, hard terminal-margin/sample watches clear, and an observable normal-vs-hard effect. This is a hard-difficulty watch reduction, not final combat balance, automatic tuning, runtime balance mutation, or broad encounter redesign.

Completed slice on 2026-05-24: `strategic-ai-multi-scenario-recruitment-delivery-20260524-10184` expands strategic AI recruitment delivery from the single River Pass fixture to required shared-harness and focused-report coverage across `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `bogbound-oath`. The live enemy-turn case seeds owned controller towns with affordable recruits and understrength active raid hosts, then proves recruit pools are consumed into those hosts, host strength rises, active target metadata remains present, `ai_town_recruited` and `ai_raid_reinforced` events surface without internal leak tokens, and no `hero_task_state` save writes or save migration occur. This also fixes controller-town recruitment delivery by using `controlling_faction_id` for enemy town build/reinforce ownership checks. This is a strategic-AI breadth increment, not final recruiting economy, complete grouping strategy, defense rotation, or full AI-quality completion.

Completed slice on 2026-05-24: `packaging-release-bundle-manifest-gate-20260524-10184` adds a post-export release-bundle manifest gate over the existing Linux and Windows local export-smoke artifacts. `tests/packaging_release_bundle_manifest_report.py` requires successful Linux/Windows smoke JSON reports, exact release sidecar contents for executable/PCK/native runtime library bundles, size floors, and zero unexpected or forbidden dev/import/debug files such as `.git`, `.godot`, `.artifacts`, `tmp`, `*.dll.a`, `.import`, `.pdb`, and debug native artifacts. This strengthens packaged-artifact hygiene, not installer readiness, clean-machine smoke coverage, Windows runtime execution, signing, distribution metadata, or release readiness.

Completed slice on 2026-05-24: `battle-autoplay-active-clear-regression-gate-20260524-10184` hardens the active-scenario battle breadth harness after the remaining watch queue was cleared. `tests/battle_autoplay_active_scenario_breadth_report.gd` now fails if the active breadth tuning queue reopens above zero items, while preserving the report-only/no-runtime-tuning policy. Current focused evidence keeps 16 active scenarios, 51/51 authored encounter samples, zero stalls, zero invalid orders, no missing scenario ids, queue status `clear`, item_count `0`, and queue signature `829808c9`; the standard balance CLI passed 4/4 with the hardened active case signature `3be9bc68`. This is a regression gate for the current authored breadth, not final combat balance, automatic tuning, broader encounter redesign, or new scenario content.

Completed slice on 2026-05-24: `battle-autoplay-remaining-watch-retune-20260524-10184` clears the remaining active-scenario combat watch queue after the prior cohort retune left 7 medium-priority items. Placement-local authored army tuning for `glassroad_archive_wardens`, `ninefold_prism_matrix`, `nightglass_drum_circle`, `bridge_silt_hunters` in `ironbridge-stand`, `bridge_silt_hunters` in `mireford-skirmish`, and `ninefold_orevein_exactors` keeps the active breadth report at 51/51 completed authored encounter samples with zero stalls, zero invalid orders, no missing scenario ids, queue status `clear`, item_count `0`, high-priority count `0`, and queue signature `829808c9`. This is not final combat balance, automatic tuning, shared unit-stat mutation, broad combat model redesign, or new scenario breadth.

Completed slice on 2026-05-24: `battle-autoplay-active-watch-cohort-retune-20260524-10184` reduced the active-scenario combat watch queue after the default 12-sample queue was cleared. Placement-local authored army tuning for `prismhearth_halo_reserve`, `daybreak_array`, `daybreak_drum_circle`, `glassfen_relay_pickets`, `glassfen_glasswing_sortie`, and `bridge_silt_hunters` drops active-breadth watch items from `16` to `7`, preserves high-priority count `0`, keeps the active breadth report at 51/51 completed authored encounter samples with zero stalls, zero invalid orders, and no missing scenario ids, and keeps the default queue `clear` with signature `829808c9`. This is not final combat balance, automatic tuning, shared unit-stat mutation, broad combat model redesign, or new scenario breadth.

Completed slice on 2026-05-24: `battle-autoplay-reopened-queue-retune-20260524-10184` clears the reopened deterministic 12-sample battle autoplay queue and removes the active-scenario Basalt Gatehouse high-priority outlier through placement-local authored army tuning for `river_pass_ghoul_grove`, `fen_crown_bone_ferry_watch`, and `ninefold_basalt_gatehouse_watch`. The focused queue is now `clear` with signature `829808c9`; active breadth still samples 16 active scenarios and 51 authored encounter placements with zero stalls, zero invalid orders, no missing scenario ids, queue signature `d8a427ba`, and high-priority count `0`. This is not final combat balance, automatic tuning, broad encounter redesign, or a combat-rules rewrite.

Completed slice on 2026-05-23: `player-facing-campaign-reactivation-smoke-20260523-10184` reactivated the existing authored scenario and campaign domains for player-facing campaign browsing and focused smoke coverage. `content/campaigns.json` now exposes five active campaign arcs, `content/scenarios.json` exposes sixteen active authored scenarios, and `tests/player_facing_campaign_menu_smoke.tscn`, `tests/map_campaign_replayability_breadth_report.tscn`, and `tests/random_map_scenario_load_smoke.tscn` gate the live CampaignRules/menu path plus generated-map non-adoption boundaries. This is not a full campaign-breadth, final balance, or campaign-polish completion claim.

Completed slice on 2026-05-24: `player-facing-authored-skirmish-browser-20260523-10184` exposes active authored skirmish-available scenarios through `ScenarioSelectRules.build_skirmish_browser_entries` and the main-menu skirmish validation path. This closed the immediate post-reactivation gap where `build_skirmish_setup` could launch authored scenarios but the browser list still returned only maps-folder package rows. Generated-map transient draft ids remain excluded from authored skirmish rows.

Completed slice on 2026-05-24: `player-facing-campaign-launch-smoke-20260524-10184` extended the focused campaign menu smoke from active campaign/chapter preview to actual Campaign-mode session launch through `validation_start_selected_campaign_chapter`. This is a live launch proof for the reactivated player-facing campaign board, not a full campaign playthrough or balance claim.

Completed slice on 2026-05-24: `player-facing-authored-skirmish-launch-smoke-20260524-10184` extended the focused authored skirmish browser smoke from active row selection/setup to actual Skirmish-mode session launch through `validation_start_selected_skirmish`. This is a live launch proof for the reactivated player-facing Skirmish board, not a full skirmish playthrough or balance claim.

Completed slice on 2026-05-24: `player-facing-authored-launch-save-summary-smoke-20260524-10184` extends the focused campaign and authored skirmish launch smokes to write and inspect resumable autosave summaries immediately after the selected menu launch. Campaign launch now proves campaign id/name/chapter metadata, Campaign launch mode, saved-from launch mode, in-progress status, and overworld resume target. Authored skirmish launch proves Skirmish launch mode, saved-from launch mode, in-progress status, overworld resume target, and no campaign metadata leak. The slice is limited to save/load confidence for the reactivated player-facing launch paths; it is not a full load-route replay, scenario balance, campaign breadth, or UX overhaul claim.

Completed slice on 2026-05-24: `active-scenario-deadline-loss-breadth-20260524-10184` expands timed defeat pressure from the previous five-scenario sample to every active authored scenario. `tests/scenario_deadline_loss_variety_report.tscn` now derives active scenarios from content, boots each as a live skirmish session, and proves each authored deadline remains in progress one day early and resolves as defeat on the authored day. Current focused evidence covers 16 active scenarios, 15 campaign-available scenarios, 16 skirmish-available scenarios, the skirmish-only front, and the Ninefold finale. This is a scenario-breadth and loss-variety increment, not final scenario balance, new campaign arcs, or playable-alpha completion.

Completed slice on 2026-05-24: `ui-runtime-sfx-asset-layer-20260524-10184` promotes UI audio from generated-only waveform playback to a manifest-backed runtime SFX asset layer. The slice adds reproducible original WAV cues for click/select/adjust/tab/confirm/invalid under `art/audio/runtime/ui/`, keeps generated waveforms as fallback, and regates `tests/ui_audio_cue_runtime_report.tscn` to prove common controls prefer imported runtime UI assets. This is a runtime UI SFX asset layer, not final sound design, music, ambience, or mixer mastering.

Completed slice on 2026-05-24: `overworld-ambient-runtime-sfx-asset-layer-20260524-10184` promotes overworld ambient audio from generated-only segments to a manifest-backed runtime ambient asset layer. The slice adds reproducible original WAV cues for terrain ambience, enemy pressure, and day pulse under `art/audio/runtime/ambient/`, keeps generated ambience as fallback, and regates `tests/overworld_ambient_audio_runtime_report.tscn` to prove direct and OverworldShell sync surfaces load the manifest and prefer imported ambient assets. This is a runtime ambient SFX asset layer, not final sound design, final ambient stems, music, or mixer mastering.

Completed slice on 2026-05-24: `music-runtime-track-asset-layer-20260524-10184` promotes music audio from generated-only layers to a manifest-backed runtime music asset layer. The slice adds reproducible original WAV cue layers for menu, overworld, battle, and outcome contexts under `art/audio/runtime/music/`, keeps generated music as fallback, and regates `tests/music_audio_runtime_report.tscn` to prove direct and menu-shell routes load the manifest and prefer imported runtime music assets. This is a runtime music asset layer, not final composition, final soundtrack direction, licensed music, stems, or mixer mastering.

Completed slice on 2026-05-24: `strategic-ai-multi-scenario-town-defense-retask-20260524-10184` expands the shared headless strategic AI harness from a single River Pass town-defense fixture to multi-scenario/faction town-defense retask coverage. The shared harness now runs `strategic_ai_multi_scenario_town_defense_retask` across `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `ninefold-confluence`, proving 9 enemy faction cases retask active raids to same-faction stabilizing towns, preserve previous target metadata, keep the abandoned resource target uncaptured for that turn, emit compact public assignment reasons, and avoid `hero_task_state`/public-event leaks. The slice also fixes occupied-town faction checks to honor `controlling_faction_id` and prevents resource-site defense from overwriting an existing town-defense target. This is strategic AI breadth evidence, not a final objective planner, durable task board, or full AI-quality claim.

Completed slice on 2026-05-24: `strategic-ai-multi-scenario-objective-targeting-20260524-10184` expands the shared headless strategic AI harness with required `strategic_ai_multi_scenario_objective_targeting` coverage. The new case runs across `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `ninefold-confluence`, proving 9 enemy faction cases select priority, siege, or objective-coded targets through live target assignment with compact public reasons, no `hero_task_state` save writes, and no public-event leaks. The slice also keeps nearby priority encounter blockers selectable when the blocker itself makes normal staging tiles unreachable, and corrects the Ninefold Veilmourn priority list to target the authored `ninefold_bellwake_privateers` lane blocker instead of a future scripted pressure id. This is target-selection breadth evidence, not final strategic AI quality, a persistent task board, or complete objective sequencing.

Completed slice on 2026-05-24: `battle-spell-impact-runtime-presentation-assets-20260524-10184` closes a focused event-driven battle presentation and Audio/VFX gap where resolved battle spells still flowed through generic cast/status placeholder cues. Battle animation events now preserve `spell_id` and `resolution_type`, `BattleBoardView` maps spell casts to distinct runtime VFX cue ids and deterministic imported WAV SFX assets for damage, control, recovery, cleanse, and buff spell families, and focused validation proves real `spell_cinder_burst` presentation selects `vfx_spell_cinder_burst` plus `audio_spell_cinder_burst` while retaining generic fallbacks. The standard headless balance harness also now treats medium-priority difficulty-sweep queues as report-only watch evidence instead of failing unless gates fail or action-required/high-priority items reopen. This is spell impact presentation and runtime asset coverage, not final sound design, final imported VFX art, spell redesign, or combat balance tuning.

Completed slice on 2026-05-24: `battle-event-presentation-shell-surface-20260524-10184` connects the existing battle animation event queue to the BattleShell dispatch rail. `BattleRules.latest_animation_event_presentation_payload(...)` now converts the latest resolved animation event into a compact player-facing action cue, `BattleShell.validation_snapshot()` exposes `battle_presentation_event`, and `tests/battle_event_animation_state_report.tscn` opens a real shell after a strike to prove the cue is visible with event id, actor, target, and tooltip evidence. This is a shell presentation/readability increment over existing event-driven board playback, not combat balance tuning, final authored animation timing, final VFX/audio art, or a broad battle UI redesign.

Completed slice on 2026-05-24: `random-map-generated-setup-pending-retry-surface-20260524-10184` corrects the strict-Small generated-map setup/retry surface after the focused UX report drifted from the current runtime retry policy. Generated setup preview now reads as configured and pending launch validation, the player command is labeled `Validate & Launch`, validation failures use the same generated setup surface as normal launch failures, and the focused report proves the current bounded retry policy without enabling unsupported water, underground, broad size classes, campaign adoption, authored writeback, or native topology changes.

Completed slice on 2026-05-24: `battle-autoplay-active-scenario-breadth-harness-20260524-10184` extends the deterministic battle autoplay harness beyond the current four-scenario default by sampling every active authored campaign/skirmish scenario and all current authored encounter placements. `tests/battle_autoplay_active_scenario_breadth_report.tscn` now derives 16 active authored scenarios, samples all 51 current encounter placements, proves 51 completed samples with zero stalls, zero invalid orders, and no missing scenario ids, and exposes the broader report-only balance state: `combat_feel_gate_status = pass`, `balance_matrix_gate_status = warning`, deterministic queue signature `e4d8c04a`, `balance_tuning_queue.status = action_required`, `item_count = 54`, and `high_priority_count = 28`. The standard headless balance CLI now includes this active-scenario breadth probe. This is active-content balance-harness breadth evidence and tuning backlog exposure, not automatic tuning, content writeback, manual-play replacement, or final combat-balance approval.

Completed slice on 2026-05-24: `battle-autoplay-active-scenario-outlier-retune-20260524-10184` used the active-scenario breadth queue for a bounded authored army-group retune across the first batch of terminal-margin outliers, including `barrow_pickets`, `ninefold_bellwake_privateers`, `glassfen_relay_pickets`, `charter_beacon_wardens`, `prismhearth_halo_reserve`, `daybreak_drum_circle`, `surge_charter_guard`, and `ninefold_orevein_exactors`. The full active breadth report still samples 16 active authored scenarios and 51 authored encounter placements with 51 completed samples, zero stalls, zero invalid orders, and no missing scenario ids. Queue pressure dropped from 54 to 40 total items and from 28 to 14 high-priority items, with deterministic signatures `e4d8c04a` -> `b4a2ed49` -> `04bf99d5`; `combat_feel_gate_status` remains `pass`, while `balance_matrix_gate_status` and `runtime_consequence_matrix_gate_status` remain report-only warnings. This is a first active-content retune pass, not final combat balance, automatic tuning, or runtime balance mutation.

Completed slice on 2026-05-24: `battle-autoplay-active-scenario-second-outlier-retune-20260524-10184` continued the active-scenario breadth queue work against the next top terminal-margin contributors: `daybreak_drum_circle`, `surge_charter_guard`, `ninefold_orevein_exactors`, `glassfen_aurora_battery`, `daybreak_array`, and the newly surfaced repeated `bridge_ford_reavers` blowout. The full active breadth report still samples 16 active authored scenarios and 51 authored encounter placements with 51 completed samples, zero stalls, zero invalid orders, and no missing scenario ids. Queue pressure dropped from 40 to 23 total items and from 14 to 0 high-priority items, with deterministic signatures `04bf99d5` -> `e0c17322` -> `f7818555`; `combat_feel_gate_status` and the active breadth `balance_matrix_gate_status` now pass, while `runtime_consequence_matrix_gate_status` remains a report-only warning. The tuning queue is now `watch`, not `action_required`. This is a second active-content retune pass, not final combat balance, automatic tuning, or runtime balance mutation.

Completed slice on 2026-05-24: `battle-autoplay-active-scenario-watch-retune-20260524-10184` targeted the remaining medium-priority active-scenario breadth watch contributors after high-priority items reached zero. The final authored army-group pass reduced Glassfen Breakers enemy blowout pressure, nudged Daybreak/Bellwake/rough pacing contributors, and preserved the high-priority clear state after reverting an intermediate regressing attempt. The full active breadth report still samples 16 active authored scenarios and 51 authored encounter placements with 51 completed samples, zero stalls, zero invalid orders, and no missing scenario ids. Queue pressure dropped from 23 to 20 total items while high-priority items stayed at 0, with deterministic signatures `f7818555` -> guarded regression `6ae06abb` -> final `c76f4832`; `combat_feel_gate_status` and the active breadth `balance_matrix_gate_status` remain `pass`, while `runtime_consequence_matrix_gate_status` remains a report-only warning. This is a watch-queue retune pass, not final combat balance, automatic tuning, or runtime balance mutation.

Current tactical chain: owner-directed reset archives the native catalog-auto RMG implementation and the overgrown h3maped inspection/report code as legacy evidence/debug code, then restarts from a small 36x36-only h3maped-derived path. The active contract is strict: incomplete executable phases must block generation instead of being replaced by adapters, proxy blockers, count tuning, or self-declared validation. The replacement must derive behavior from `/root/Downloads/h3maped.exe` and the recovered h3maped spec, adapting only final object/content references to our runtime assets and registries after the relevant executable phase is actually ported. Completed child slices remain valid evidence for failure history and specific gates, but they are not a broad HoMM3-style production parity claim.

Do not infer product readiness from the completed queue. Completed Phase 2/RMG/performance/tooling evidence means those specific slices passed their gates; it does not mean playable alpha, campaign breadth, release readiness, broad faction completion, asset parity, or HoMM3 byte-level cloning.

Persistent guardrail: do not import generated PNGs or generated-study derivatives into runtime/source assets without an explicit AcOrP-approved ingestion slice that records provenance, import paths, rollback, and validation.

Owner-directed UI art study and runtime ingestion on 2026-05-23: the overworld, battle, and town interface art gap was audited, then a later explicit runtime ingestion pass imported UI skins under `art/ui/runtime/`. A follow-up correction replaced the initial stretched/cropped look with compact, original, nine-patch-safe panel/bar textures and shared button-state assets. `scripts/ui/FrontierVisualKit.gd` now provides texture-backed panel helpers with bounded margins, flat-style fallbacks, and runtime button skins; the overworld, battle, and town shells apply those runtime skins to their existing surfaces. The ingestion is documented in `docs/ui-art-asset-gap-audit-2026-05-23.md` and validated by `tests/ui_runtime_skin_visual_report.tscn`, which runs in a non-headless Godot client, asserts expected `StyleBoxTexture` panel and button resources, and writes screenshots for all three live shells across the 1280x720, 1600x900, 1920x1080, and 2560x1440 16:9 viewport matrix. This is a corrected runtime skin pass with multi-resolution coverage, not final UI art approval.

Owner-directed unit-art progress on 2026-05-23: every authored unit now has deterministic generated PNG art records for portrait, battle icon, and overworld icon surfaces under `art/units/`, with `content/unit_art_manifest.json` as the source manifest and `tools/generate_unit_art_assets.py` as the reproducible generator. `ContentService` validates the manifest; `BattleBoardView` loads battle icons for stack tokens; `TownShell` shows unit portraits in recruit actions; and `OverworldMapView` shows unit overworld icons for encounter stacks, each with procedural fallbacks where an asset cannot resolve. `tests/unit_art_manifest_report.tscn` checks all unit records, dimensions, unique paths, and live battle/town/overworld art loading; `tests/validate_repo.py` includes the manifest and runtime-hook gate. This is a full-roster generated-art baseline plus first live surface adoption pass, not a claim that final hand-painted unit art direction is complete.

Unit production-readiness gate added on 2026-05-23: `tests/unit_production_readiness_report.tscn` audits all 103 authored units for required gameplay fields, non-empty costs/growth/abilities, live content references, loadable portrait/battle/overworld textures, unique PNG hashes per art surface, and successful `BattleRules` stack materialization/normalization. The unit art generator now stamps battle and overworld icons with deterministic unit-signature marks so every generated PNG surface is byte-unique. This gate proves the current generated unit set is mechanically consumable by battle/content/art systems; it still does not claim final hand-painted art direction or animation sprite-sheet completion.

Unit visual-QA contact-sheet gate added on 2026-05-23: `tests/unit_art_contact_sheet_report.tscn` loads every portrait, battle icon, and overworld icon, verifies visual-density metrics for alpha coverage, visible bounds, luminance range, and quantized color variety, asserts unique composite visual fingerprints, records nearest visual neighbors, and writes review contact sheets plus tile coordinates under `.artifacts/unit_art_contact_sheet_report/`. `tests/validate_repo.py` now gates the report script/scene tokens so this generated-art baseline remains inspectable as the roster changes. This is a production review artifact and blank/flat/duplicate visual guard, not final hand-painted or animated unit-art approval.

Unit battle-animation baseline added on 2026-05-23: `content/unit_animation_manifest.json` now enumerates deterministic generated battle troop sprite sheets for all 103 authored units under `art/animation/runtime/units/`, with 14 cue-aligned states and four 64x64 frames per state. `tools/generate_unit_art_assets.py` produces the static art manifest and animation manifest together, and `tests/unit_animation_manifest_report.tscn` validates state-family coverage, loadability, sheet dimensions, unique sheet hashes, non-empty frames, and per-state frame variation. `tests/validate_repo.py` now gates the animation manifest, generator hooks, PNG sheet presence, and report script/scene tokens. This closes the generated sprite-sheet baseline surface; it is still not final hand-painted animation approval.

Unit animation runtime adoption added on 2026-05-23: `ContentService` now treats `content/unit_animation_manifest.json` as a first-class content manifest with `get_unit_animation()` and startup validation, and `BattleBoardView` draws animated token frames from each unit's generated sprite sheet while retaining static battle icons as fallback. The animation manifest is now cross-checked against `content/animation_event_cues.json` so generated state names match the cue catalog for death, cast, status, retaliation, retreat, and surrender events. `tests/unit_art_manifest_report.tscn` now verifies battle runtime animation sheet loading for visible stacks in addition to town portraits, overworld icons, and battle icons. This is a runtime adoption pass for generated sheets, not a complete authored combat-animation direction pass.

Battle event animation state adoption added on 2026-05-23: `BattleRules` now owns transient per-stack battle animation metadata so resolved movement, melee, ranged, hit, death, cast, status, defend, retaliation, retreat, and surrender events can select cue-catalog unit animation states instead of leaving `BattleBoardView` limited to idle, ready, and defend fallback poses. `BattleBoardView` reads this rule-owned state before fallback selection, and `tests/battle_event_animation_state_report.tscn` proves event-state adoption plus live board summary consumption. This is a presentation-state bridge for generated sheets, not final VFX/audio/camera timing, queued playback, or combat balance tuning.

Battle animation event queue lifecycle added on 2026-05-23: `BattleRules` now records a bounded serial event queue alongside the current per-stack state map, and `BattleBoardView` syncs new records into short playback windows that expire back to active, defend, or idle fallback poses. `tests/battle_event_animation_state_report.tscn` now validates queue coverage for movement, melee, ranged, hit, death, cast, status, and defend events, then proves live board playback expiry. This remains a generated-sheet presentation lifecycle slice, not final VFX/audio/camera timing, authored animation timing, or combat balance tuning.

Battle movement path presentation added on 2026-05-23: `battle_unit_move` records now carry `from_q/from_r` and `to_q/to_r`, and `BattleBoardView` uses those coordinates for `vfx_placeholder_battle_path_ghost` so movement presentation spans the real source and destination cells instead of pulsing only on the final cell. `tests/battle_event_animation_state_report.tscn` now proves a real move emits path coordinates and a distinct path ghost. This is movement event context and placeholder VFX presentation, not final interpolated token travel, authored motion curves, imported VFX/audio, camera work, or combat balance tuning.

Battle movement token motion added on 2026-05-23: `BattleBoardView` now uses active `battle_unit_move` playback records to render the moving stack token, health bar, count badge, caption, and hit shape at an interpolated presentation center between `from_q/from_r` and `to_q/to_r`. `tests/battle_event_animation_state_report.tscn` now proves a real move keeps the stack in `move_path_step`, draws the path ghost, and presents the token in transit instead of snapped directly to the destination. This is runtime event-driven token motion for resolved movement, not final authored motion curves, per-unit locomotion timing, camera work, imported VFX/audio, or combat balance tuning.

Battle attack and hit token feedback added on 2026-05-23: `BattleBoardView` now uses attack, retaliation, ranged, cast, hit, status, and death event context to compute bounded token presentation transforms for lunge, recoil, cast anchoring, hit stagger, status pulse, and death fallback. The same transformed center drives the stack token, health bar, count badge, caption, and hit shape. `tests/battle_event_animation_state_report.tscn` now proves a real melee strike presents the attacker as `melee_lunge`, the target as `hit_stagger`, and keeps cue-driven melee VFX active. This is event-driven token feedback for readability, not final authored attack timing, camera shake, imported VFX/audio, or combat balance tuning.

Battle event token feedback coverage added on 2026-05-23: `BattleBoardView.validation_unit_art_summary()` now exposes active presentation motion totals and per-role counts, and `tests/battle_event_animation_state_report.tscn` proves ranged recoil, status pulse, cast anchor, and death fallback token roles in addition to melee lunge and hit stagger. This is focused validation coverage for existing event-driven token feedback, not final authored animation timing, camera work, imported VFX/audio, or combat balance tuning.

Battle camera presentation added on 2026-05-23: `BattleBoardView` now derives board-side camera focus/shake records from active battle cue playback for movement, melee, retaliation, ranged, hit, death, cast, status, retreat, and surrender events, applies a small bounded battlefield offset in normal animation mode, and exposes `camera_playback` validation summaries. `tests/battle_event_animation_state_report.tscn` now proves ranged/status events create source-target/status camera records and that camera records expire with the event playback lifecycle. This is deterministic camera presentation scaffolding, not final authored cinematic timing, screen shake direction, imported VFX/audio, or combat balance tuning.

Battle cue dispatch adoption added on 2026-05-23: `BattleBoardView` now resolves each active battle animation event through `AnimationCueCatalog.cue_playback_policy_for_event(...)`, keeps a transient board-side cue dispatch record with selected VFX/audio cue ids and preference-aware timing policy, and exposes it through validation summaries. `tests/battle_event_animation_state_report.tscn` proves ranged/status events dispatch projectile/status VFX placeholders plus audio placeholder ids and expire with playback. This is runtime cue dispatch over placeholder ids, not final imported audio/VFX/camera work.

Battle VFX cue presentation added on 2026-05-23: battle animation events now preserve source/target stack context for attacks, retaliation, damage, status, death, and spell events, and `BattleBoardView` maps active VFX cue ids into transient board draw entries and lightweight canvas effects for projectile paths, status residue, damage ticks, melee arcs, stack fades, cast anchors, and movement ghosts. `tests/battle_event_animation_state_report.tscn` now proves ranged/status cue ids produce source-target VFX draw entries and expire with playback. This is visible placeholder VFX presentation, not final imported VFX assets, audio playback, camera work, or combat balance tuning.

Battle death animation retention added on 2026-05-23: `BattleBoardView` now keeps zero-health stacks visible while an active death animation playback record exists, so `battle_unit_death` / `death_rout_remove` and `vfx_placeholder_stack_fade` actually render before the stack disappears from the board. The same visibility filter drives stack-cell assignment and visible-stack summaries so expired defeated stacks do not occupy presentation slots. `tests/battle_event_animation_state_report.tscn` now proves a real killing strike keeps the defeated target visible with `alive_count` 0 during death playback. This is presentation retention for generated sheets and placeholder VFX, not final authored death timing, corpse persistence, imported VFX/audio, camera work, or combat balance tuning.

Battle audio cue playback added on 2026-05-23: `BattleBoardView` now maps active battle audio cue ids into short generated `AudioStreamGenerator` waveforms on the Master bus, with per-cue timbre/duration specs for ranged release, status apply, melee, hit, rout, cast, movement, defend, retaliation, retreat, surrender, ready, status-clear, and idle cues. The board exposes `audio_playback` validation records and rate-limits active generated players. `tests/battle_event_animation_state_report.tscn` proves ranged/status events synthesize audio cue waveforms and expire with playback. This is runtime placeholder audio playback, not final sound design, imported audio assets, music, ambience, mixer polish, or combat balance tuning.

Battle runtime SFX asset layer added on 2026-05-23: `content/battle_sfx_manifest.json` now maps every current battle audio cue id to committed original WAV assets under `art/audio/runtime/battle/`, generated reproducibly by `tools/generate_battle_sfx_assets.py`. `BattleBoardView` prefers manifest-backed imported WAV streams and preserves generated waveform fallback when an asset is absent or unloadable, while `tests/battle_event_animation_state_report.tscn` proves the ranged/status runtime case reports imported SFX assets and lifecycle expiry. This is a runtime SFX asset-loading layer, not final sound design, mixer mastering, platform audio certification, music, ambience, UI audio, or combat balance tuning.

UI audio cue runtime baseline added on 2026-05-23: `UiAudio` is now a generated-audio autoload that scans the scene tree, attaches to common Godot controls, and synthesizes `ui_click`, `ui_select`, `ui_adjust`, `ui_tab`, `ui_confirm`, and `ui_invalid` cue waveforms on the Master bus while preserving bounded validation records and mute state. `tests/ui_audio_cue_runtime_report.tscn` proves Button, OptionButton, HSlider, TabContainer, ItemList, confirm, and invalid-action cues produce playback records. This is runtime placeholder UI audio, not final sound design, imported UI audio assets, music, ambience, or mixer polish.

UI runtime SFX asset layer added on 2026-05-24: `ui-runtime-sfx-asset-layer-20260524-10184` adds `content/ui_sfx_manifest.json`, reproducible WAV generation through `tools/generate_ui_sfx_assets.py`, runtime UI WAV assets under `art/audio/runtime/ui/`, and `UiAudio` manifest loading with generated waveform fallback. `tests/ui_audio_cue_runtime_report.tscn` proves Button, OptionButton, HSlider, TabContainer, ItemList, confirm, and invalid-action cues prefer imported runtime UI assets. This is still not final sound design, music, ambience, or mixer mastering.

Overworld ambient audio runtime baseline added on 2026-05-23: `AmbientAudio` is now a generated-audio autoload that synthesizes bounded overworld ambience from live session terrain, dominant map terrain, day, hero position, and enemy pressure on the Master bus. `OverworldShell` syncs the service during ready/refresh and exposes validation summaries, while `tests/overworld_ambient_audio_runtime_report.tscn` proves terrain ambience, pressure and day-pulse layers, signature-based non-restart behavior, and shell snapshot evidence. This is runtime placeholder map ambience, not final sound design, imported ambient stems, music, or mixer polish.

Overworld ambient runtime SFX asset layer added on 2026-05-24: `overworld-ambient-runtime-sfx-asset-layer-20260524-10184` adds `content/ambient_sfx_manifest.json`, reproducible WAV generation through `tools/generate_ambient_sfx_assets.py`, runtime ambient WAV assets under `art/audio/runtime/ambient/`, and `AmbientAudio` manifest loading with generated waveform fallback. `tests/overworld_ambient_audio_runtime_report.tscn` proves terrain, pressure, and day-pulse layers prefer imported runtime ambient assets. This is still not final sound design, final ambient stems, music, or mixer mastering.

Music audio runtime baseline added on 2026-05-23: `MusicAudio` is now a generated-music autoload that routes deterministic menu, overworld, battle, and outcome context cues through layered `AudioStreamGenerator` playback, respects master/music mute state, and avoids restarting unchanged context signatures. `MainMenu`, `OverworldShell`, `BattleShell`, and `ScenarioOutcomeShell` sync the service and expose validation summaries, while `tests/music_audio_runtime_report.tscn` proves all four direct context routes plus a live menu-shell route. This is runtime placeholder music routing, not final composition, imported stems, mixer mastering, or soundtrack approval.

Music runtime track asset layer added on 2026-05-24: `music-runtime-track-asset-layer-20260524-10184` adds `content/music_runtime_manifest.json`, reproducible WAV generation through `tools/generate_music_runtime_assets.py`, runtime music WAV assets under `art/audio/runtime/music/`, and `MusicAudio` manifest loading with generated waveform fallback. `tests/music_audio_runtime_report.tscn` proves menu, overworld, battle, and outcome routes prefer imported runtime music assets. This is still not final composition, soundtrack approval, final stems, licensed music, or mixer mastering.

Battle event playback sequencing added on 2026-05-23: `BattleBoardView` now preserves event serial timing in active playback records, adds a bounded target-reaction delay for hit/death/status/retaliation cue handoffs, derives generated sheet frame indexes from event progress instead of wall-clock only, and keeps delayed target audio as scheduled until its cue start. `tests/battle_event_animation_state_report.tscn` now proves source ranged cues start before target status cues and that scheduled target audio carries a positive sequence delay. This is deterministic presentation ordering for generated sheets/placeholders, not final authored animation timing, imported audio/VFX, or combat balance tuning.

Battle exit animation handoff added on 2026-05-23: retreat and surrender now preserve pre-resolution `battle_exit_animation_snapshot` payloads before `session.battle` is cleared, `BattleBoardView` can render those presentation snapshots, and `BattleShell` briefly shows the exit animation while inputs are locked before routing to the overworld/outcome flow. `tests/battle_event_animation_state_report.tscn` now proves `battle_unit_retreat`/`retreat_withdraw_column` and `battle_unit_surrender`/`surrender_stand_down` are produced by real exit actions and render through the board snapshot path. This closes an exit-action presentation gap, not final authored animation timing, camera work, imported VFX/audio, or combat balance.

Battle exit event motion presentation added on 2026-05-23: `BattleBoardView` now maps active retreat and surrender playback records into distinct board-token motion roles, `retreat_withdraw` and `surrender_stand_down`, while preserving the existing exit snapshot handoff. Surrender is promoted from retreat-style metadata to a first-class battle troop state family in the cue catalog, generated animation manifest, and deterministic art generator metadata. `tests/battle_event_animation_state_report.tscn`, `tests/animation_battle_troop_state_contract_report.tscn`, and `tests/validate_repo.py` gate the token-motion roles and state-family contract. This is focused exit-action presentation polish, not final authored animation timing, imported VFX/audio, broad battle UX, or combat balance tuning.

Battle status clear presentation added on 2026-05-23: status cleanse and round-expiry removals now emit `battle_status_expired` / `status_expired` instead of reusing status-apply presentation. `BattleBoardView` maps the event to `status_clear` token motion, `vfx_placeholder_status_clear`, `audio_placeholder_status_clear`, and status camera focus records. `tests/battle_event_animation_state_report.tscn` now proves both a real `spell_prism_bastion` cleanse and a round-expired effect purge. This is event-driven status-removal presentation over existing placeholder cues, not final VFX/audio art, spell balance tuning, or broad battle UX polish.

Battle retaliation event presentation added on 2026-05-23: `battle_retaliation` now closes the cue-catalog-to-board gap. `BattleBoardView` materializes `vfx_placeholder_retaliation_arc` as a `retaliation_arc` draw entry, and `tests/battle_event_animation_state_report.tscn` now includes a real counterstrike case that proves `retaliation_release`, target `hit_stagger`, retaliation VFX/audio cue ids, board VFX draw entry, and presentation motion roles. Current focused evidence reports 18 event-animation cases with retaliation present. This is event-driven battle presentation coverage over generated sheets and placeholder cues, not combat balance tuning, final animation timing, or final VFX/audio art.

Battle decision VFX cue coverage added on 2026-05-23: the remaining declared battle VFX cue ids are now mapped in `BattleBoardView`. The board materializes `vfx_placeholder_idle_shadow`, `vfx_placeholder_active_ring`, `vfx_placeholder_brace_outline`, and `vfx_placeholder_surrender_marker`; `tests/battle_event_animation_state_report.tscn` proves real defend and surrender events materialize `brace_outline` and `surrender_marker` draw entries. Current focused evidence reports 18 event-animation cases and zero missing battle VFX ids in the board mapper. This is placeholder event presentation coverage, not final imported VFX art, sound design, combat balance tuning, or broad battle UX redesign.

Battle AI withdrawal decision selected on 2026-05-23: active work targets the tactical gap where enemy battle AI scores attacks, spells, advance, and defend but does not preserve forces by retreating or surrendering from clearly losing field battles. The slice adds an enemy-only withdrawal scorer, runtime enemy exit-action resolution, exit-animation snapshot preservation, and a focused report at `tests/battle_ai_withdrawal_decision_report.tscn`. This is a narrow tactical-AI and battle-resolution increment, not player autoplay withdrawal, final combat balance approval, broad strategic AI quality, or a new surrender economy model.

Headless battle autoplay balance harness added on 2026-05-23: `BattleAutoplayBalanceHarnessRules` now provides deterministic report-only battle sampling for authored encounters, including outcome distribution, action distribution, completed/stalled counts, round/step pacing, side health totals, remaining-health percentages, and compact per-sample turn logs. `HeadlessSimulationHarnessRules` and `BalanceRegressionReportRules` both consume the shared sampler, and their focused tests assert the new pacing/action/health evidence. Current evidence is still narrow authored-scenario sampling for balance work, not automatic tuning, manual-play replacement, or final combat balance approval.

Battle autoplay combat-feel diagnostics added on 2026-05-23: the shared battle autoplay sampler now records per-sample terrain, encounter difficulty, initial stack counts, role mix, ability ids, initiative spread, action mix, invalid-order count, damage dealt by side, damage per round, pacing band, and terminal health margin. `BalanceRegressionReportRules` and `HeadlessSimulationHarnessRules` both surface the aggregate diagnostics, and their focused reports assert the new damage/action/terrain/difficulty/role/ability/initiative fields. This is balance instrumentation for tuning passes, not an automatic rebalance, authored encounter retune, AI rewrite, or final combat-feel approval.

Battle autoplay combat-feel threshold gate added on 2026-05-23: the shared sampler now exposes `combat_feel_gate` with report-only thresholds for sample breadth, stalled samples, invalid orders, action diversity/dominance, damage pacing, terminal health margin, outcome bias, and burst/grind/stalled pacing dominance. The current deterministic samples surface high terminal health margin as a structured warning, so balance risk is visible in the standard reports without automatic tuning, content writeback, or a final combat-feel approval claim.

Battle autoplay combat balance calibration added on 2026-05-23: the prior `high_terminal_health_margin` warning has a first bounded fix. `BattleAiRules` now scores no-attack melee repositioning so stacks do not defend forever after abstract distance closes but hex-board contact is still missing, the sampled early authored army groups have been retuned, and `tests/battle_autoplay_combat_balance_report.tscn` gates the default sampler at 65% average terminal margin. Current focused evidence is `average_terminal_health_margin_pct: 55`, a 3/3 victory/defeat split, preserved `low`/`medium`/`high` difficulty labels, and `combat_feel_gate.status: pass`. This is a first deterministic balance calibration, not final combat balance approval.

Battle autoplay balance matrix diagnostics added on 2026-05-23: the shared deterministic battle autoplay sampler now exposes report-only cohort matrices for difficulty, terrain, scenario, army matchup, and ability presence. `tests/battle_autoplay_combat_balance_report.tscn`, `tests/balance_regression_report_suite.tscn`, and `tests/headless_simulation_harness_report.tscn` assert initial side power, matchup bands, side role/ability maps, matrix cohort rows, and `balance_matrix_gate`. Current evidence surfaces terminal-margin outliers as tuning leads; this is actionable balance instrumentation, not automatic tuning, content writeback, or final combat balance approval.

Battle autoplay expanded sample breadth added on 2026-05-23: the deterministic combat-feel sampler now uses a 12-sample default gate instead of the prior 6-sample pass. The focused combat balance report, balance regression suite, and headless simulation harness all assert that the expanded default breadth is reached, with current evidence covering four authored scenarios, 12 completed samples, 4 action families, `average_terminal_health_margin_pct: 48`, `average_total_damage_per_round: 43`, `combat_feel_gate.status: pass`, `balance_matrix_gate.status: pass`, no terminal-margin outliers, no stalled samples, and no invalid orders. This strengthens automated balance evidence before content scaling, not final combat balance approval or automatic tuning.

Battle autoplay balance tuning queue added on 2026-05-23: the shared sampler now exposes deterministic `battle_autoplay_balance_tuning_queue_v1` report-only output that converts combat-feel gate, balance-matrix gate, sample watch, and cohort watch evidence into prioritized tuning items with ownership and remediation hints. Current evidence reports 9 medium-priority watch items with stable signature `f8dc048d`, including high-margin forest/low-difficulty cohorts, one-sided terrain/scenario cohorts, terminal-margin sample watches, and one burst-pacing sample. This is a triage artifact for future combat-feel work, not automatic tuning, authored content writeback, or final balance approval.

Battle autoplay queue-driven combat balance pass added on 2026-05-23: the tuning queue has been used for a bounded authored retune of current sampled encounter army groups, moving `army_blackbranch_raiders` toward a sturdier bruiser-backed roster and trimming `army_ripper_vanguard` burst pressure. Current focused evidence reduces the queue from 9 medium-priority items with signature `f8dc048d` to 5 medium-priority cohort watches with signature `95f5ac7e`, removes all sample-level watch items, keeps `combat_feel_gate.status: pass` and `balance_matrix_gate.status: pass`, and preserves zero terminal-margin outliers across 12 completed samples. This is focused content calibration over current sampled encounters, not broad faction balance, spell/autocast tuning, or final combat balance approval.

Battle autoplay difficulty-sweep balance harness added on 2026-05-23: `BattleAutoplayBalanceHarnessRules.build_difficulty_sweep_report(...)` now reruns the authored battle sample set across normal and hard launch difficulties, records `launch_difficulty_distribution` on every sample, emits deterministic per-difficulty rows, and reports `normal_vs_hard` deltas for terminal margin, total damage per round, remaining health, and primary outcome evidence. `tests/battle_autoplay_difficulty_sweep_report.tscn` gates sample breadth, completed samples, stalled/invalid-order absence, deterministic sweep signatures, and observed difficulty effect. This strengthens automated combat-feel evidence before broader tuning; it is report-only, not automatic tuning, authored content writeback, or final combat balance approval.

Battle autoplay cohort balance pass added on 2026-05-23: the deterministic tuning queue now drives a second bounded authored-content retune over the remaining cohort watches. `fen_crown_watch` uses a placement-local gate-watch army, `army_blackbranch_raiders` gains one slinger to clear the low-difficulty terminal-margin watch, and `tests/battle_autoplay_balance_tuning_queue_report.tscn` now fails if the resolved `fen-crown`, `grass`, or `high` cohort watches reappear. Current focused evidence reduces the queue from five medium-priority watches with signature `95f5ac7e` to one medium-priority `forest` watch with signature `80bea883`, keeps `combat_feel_gate.status: pass` and `balance_matrix_gate.status: pass`, and leaves no sample-level or gate-level queue items. This is another focused combat-feel calibration pass, not broad faction balance, automatic tuning, or final combat balance approval.

Battle autoplay forest cohort balance pass added on 2026-05-23: the remaining normal-difficulty queue watch has been resolved by retuning Stonewake's authored encounter rosters. `army_willow_mill_pack` is now strong enough that Willow Mill is not an automatic forest victory, `sluice_band` uses a Stonewake-local roster so the scenario and `formation_guard` cohorts remain mixed, and `tests/battle_autoplay_balance_tuning_queue_report.tscn` now gates `MAX_CURRENT_WATCH_ITEMS := 0`. Current focused evidence moves the queue from one medium-priority `forest` watch with signature `80bea883` to `status: clear`, `item_count: 0`, and signature `829808c9`, with `combat_feel_gate.status: pass`, `balance_matrix_gate.status: pass`, and no sample-level, gate-level, or cohort queue items. This closes the current normal-difficulty tuning queue only; it is not final combat balance approval, hard-difficulty balance completion, automatic tuning, or broad faction balance.

Battle autoplay hard difficulty watch pass added on 2026-05-23: the hard launch row now has a bounded follow-up gate after the normal queue was cleared. `DifficultyRules` narrows hard battle damage multipliers from `0.9`/`1.1` to `0.95`/`1.05` while preserving hard strategic penalties and `enemy_initiative_bonus: 1`; `BattleAutoplayBalanceHarnessRules.build_difficulty_sweep_report(...)` now carries per-row queue signature, categories, and top contributors; and `tests/battle_autoplay_difficulty_sweep_report.tscn` asserts the normal queue stays clear and hard remains at or below `MAX_HARD_TUNING_QUEUE_ITEMS := 3`. Current focused evidence keeps normal at signature `829808c9`, `item_count: 0`, and moves hard from seven medium watches with signature `f59ef772` to three watches with signature `8a238ca3`, while `normal_vs_hard` still shows an observable harder launch effect. This is a bounded hard-difficulty combat-feel pass, not final combat balance approval, automatic tuning, broad faction balance, or a claim that all hard-mode encounter tuning is complete.

Battle autoplay hard difficulty queue clear pass added on 2026-05-23: the remaining hard launch row watches are resolved and the deterministic hard sweep gate now requires `MAX_HARD_TUNING_QUEUE_ITEMS := 0`. `river_pass_hollow_mire` and `causeway_reed_camp` use placement-local encounter rosters to clear the hard terminal-margin and burst-pacing watches without changing shared army groups, while `tests/battle_autoplay_difficulty_sweep_report.tscn` carries top contributors for future regressions. Current focused evidence reports `sweep_signature: bc42c7b1`, normal queue signature `829808c9`, hard queue signature `829808c9`, both rows at `tuning_queue_item_count: 0` and `status: clear`, and `normal_vs_hard` still showing an observable harder launch effect. This is a bounded combat-feel tuning pass over current authored samples, not broad faction balance, automatic tuning, or final combat balance approval.

Headless battle difficulty sweep harness added on 2026-05-23: the now-clear normal-vs-hard battle autoplay sweep is part of the required shared `HeadlessSimulationHarnessRules` subsystem set. The `battle_difficulty_sweep_sampling` case wraps `battle_autoplay_difficulty_sweep_v1`, asserts normal and hard tuning queues are clear, preserves the observed normal-vs-hard effect, and exposes compact sweep evidence through the headless report. Current focused evidence reports standalone `sweep_signature: bc42c7b1`, headless case signature `f6e32bbf`, headless harness signature `56ae7622`, normal and hard queue signatures `829808c9`, both rows at `tuning_queue_item_count: 0`, and `no_observed_effect: false`. This is automated balance-harness strengthening, not new encounter retuning, automatic tuning, or final combat balance approval.

Headless balance harness CLI added on 2026-05-23: `tools/run_headless_balance_harness.py` now runs the existing Godot battle autoplay, balance regression, and headless simulation harness reports as one artifact-producing command. The standard suite writes per-case logs plus `.artifacts/headless_balance_harness_cli/manifest.json` with schema `headless_balance_harness_cli_v1`, parsed report markers, statuses, signatures, durations, command lines, and report-only policy checks. This makes the automated balance harness easier to run before content scaling, but it is not automatic tuning, authored content writeback, CI provider wiring, manual-play replacement, or final combat balance approval.

Content runtime overworld family allowlist aligned on 2026-05-23: `ContentService` now accepts the authored resource-site and map-object families already gated by repository validation, including staged resource fronts, support producers, shrines, sign waypoints, scenario objectives, and faction landmarks. A focused battle autoplay report now loads content without `unsupported family` warning spam, reducing debug-like noise in headless balance/simulation logs. This is runtime validation alignment only, not new object mechanics, rare-resource activation, scenario scripting rewrite, generated-map behavior, or balance tuning.

Battle autoplay runtime consequence harness added on 2026-05-23: the deterministic battle balance sampler now extends initial ability presence into observed runtime effects. Each sample emits `battle_autoplay_runtime_consequence_profile_v1`, shared summaries emit `battle_autoplay_runtime_consequence_distribution_v1`, and `runtime_consequence_gate` uses `report_only_runtime_consequence_thresholds_v1`. Current focused evidence has stable distribution signature `a537a308`, 12/12 status-consequence samples, 10 ability-consequence samples, 12 spell-consequence samples, 55 status application events, 118 ability-effect observations, and 117 spell-effect observations. `tests/battle_autoplay_runtime_consequence_report.tscn`, the combat balance report, the balance regression suite, and the headless simulation harness gate the new surface. This is automated combat-feel evidence, not automatic tuning, new ability content, broad encounter retuning, or final combat balance approval.

Battle autoplay runtime consequence matrix added on 2026-05-23: the aggregate runtime consequence harness now breaks observed status, spell, and ability effects into deterministic cohorts for difficulty, terrain, scenario, matchup, and ability presence. The new `battle_autoplay_runtime_consequence_matrix_v1` surface and `report_only_runtime_consequence_matrix_thresholds_v1` gate are asserted by `tests/battle_autoplay_runtime_consequence_matrix_report.tscn`, the existing runtime consequence report, the combat balance report, the balance regression suite, and the headless simulation harness. Current focused evidence reports `matrix_signature: cab8ca24`, 12 samples, 3 difficulty cohorts, 3 terrain cohorts, 4 scenario cohorts, 2 matchup cohorts, 8 ability-presence cohorts, 8 ability-consequence cohorts, and zero zero-consequence samples. This is report-only balance instrumentation, not encounter retuning, new ability content, spell redesign, player-facing UI, or final combat balance approval.

Scenario deadline loss variety added on 2026-05-23: `river-pass`, `causeway-stand`, `fen-crown`, `mireford-skirmish`, and `ninefold-confluence` gained explicit `day_at_least` defeat objectives with player-facing labels. This was expanded on 2026-05-24 by `active-scenario-deadline-loss-breadth-20260524-10184`, which adds deadline loss pressure to every active authored scenario and regates `tests/scenario_deadline_loss_variety_report.tscn` around the full active set. The report boots each scenario as a live skirmish session, proves the deadline does not resolve one day early, then resolves as defeat on the authored day. This is a scenario-breadth and loss-variety increment, not a new campaign arc, final scenario balance approval, or playable-alpha completion claim.

Archived campaign breadth report regate added on 2026-05-23: `tests/map_campaign_replayability_breadth_report.tscn` now aligns with the current archived native campaign-domain contract. The report validates `campaign_ninefold_survey` by direct archived-content inspection, proves player-facing campaign APIs expose zero archived campaigns, still boots archived campaign/skirmish sessions through the session factory/build-session path, records unlock/replay evidence, and keeps random-map provenance plus balance reflection boundaries green. This preserves the reset boundary; it is not campaign-domain reactivation, new menu behavior, or playable-alpha completion.

Battle intent forecast added on 2026-05-23: `BattleRules.intent_forecast_payload(...)` now gives the active battle order window a scored, read-only forecast with preferred order, target, expected result, reason, likely hostile reply, and confidence evidence from `BattleAiRules.choose_stack_tactical_order(...)`. `BattleShell` keeps the compact action-guide visible surface intact and adds the forecast to the action-guide tooltip plus validation snapshot. `tests/battle_intent_forecast_report.tscn` proves the adjacent ranged fixture prefers scored `Strike`, exposes expected damage/risk/confidence copy, does not mutate battle state, and locks truthfully during enemy initiative. This is tactical comprehension and intent feedback, not final balance tuning or final battle UX.

Skirmish launch briefing UX added on 2026-05-23: skirmish setup payloads now expose a compact `briefing_check` that gives the opening briefing and first decision before launch. Authored setups derive it from scenario briefing, objective stakes, front context, and readiness evidence; maps-folder package launches get an equivalent generated-package handoff. `MainMenu` includes the briefing in the Skirmish Front Check tooltip and setup summary, while `tests/menu_outcome_visual_smoke.tscn` gates the visible handoff. This is player-comprehension polish for the launch board, not campaign-domain reactivation, scenario content breadth, save/load changes, or broad onboarding completion.

Headless strategic AI live-turn harness added on 2026-05-23: `HeadlessSimulationHarnessRules` now treats `strategic_ai_live_turn_execution` as a required subsystem, running the River Pass Vaska/Sable resource-front fixture through `EnemyTurnRules.run_enemy_turn(...)`. It also treats `strategic_ai_live_route_progression` as required, running a distant Vaska route through repeated `OverworldRules.end_turn(...)` calls until `river_free_company` is assigned, approached from distance 9 to 0, and seized. A third required subsystem, `strategic_ai_live_regroup_retreat`, seeds an understrength Vaska raid, advances the normal end-turn enemy cycle, and proves it regroups at Duskfen Bastion, pulls garrison strength, emits `ai_raid_regrouped`, and leaves the original resource under player control. `tests/headless_simulation_harness_report.tscn` asserts immediate resource-front seizure, long-route progression, retreat/regroup behavior, assignment/seizure/regroup events, public event output without internal task/score leaks, and report-only harness boundaries. This is focused strategic AI harness evidence, not full AI quality, broad path planning, recruitment grouping, defense rotation, town assault priority, or objective breadth.

Strategic AI recruitment-delivery harness added on 2026-05-23: `HeadlessSimulationHarnessRules` now treats `strategic_ai_live_recruitment_delivery` as a required subsystem, seeding Duskfen Bastion with recruitable Mireclaw units and a stable garrison, then running the normal `EnemyTurnRules.run_enemy_turn(...)` cycle against an underfilled active Vaska raid. `tests/headless_simulation_harness_report.tscn` asserts the town recruits are consumed into the raid host, the raid strength rises from `21` to `183`, `raid_unit_after = 5`, `ai_town_recruited` and `ai_raid_reinforced` events are emitted, the active `river_free_company` target is preserved, and no internal task/score fields leak through public event output. This is a focused live recruitment-routing harness case, not broad recruiting economy, multi-hero grouping, defense rotation, or final strategic AI quality.

Strategic AI live town-governor build execution added on 2026-05-23: `HeadlessSimulationHarnessRules` now treats `strategic_ai_live_town_governor_build_execution` as a required subsystem. The shared headless report seeds Duskfen Bastion with bounded Mireclaw treasury, captures the governor's projected build/recruit choice, runs `EnemyTurnRules.run_enemy_turn(...)`, and asserts the selected building is added, treasury is spent, recruits/garrison mutate, `ai_town_built` and `ai_town_recruited` events are emitted, and public event output does not leak internal score/task fields. This promotes town-governor behavior from report-only diagnostics into a live-turn mutation gate, not broad economy planning or final strategic AI quality.

Strategic AI multi-scenario pressure coverage added on 2026-05-23: `HeadlessSimulationHarnessRules` now treats `strategic_ai_multi_scenario_pressure_coverage` as a required subsystem. The shared headless report primes enemy pressure across `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `ninefold-confluence`, then requires all 9 enemy faction cases to have an owned controller town, launch a live pressure raid, and emit `ai_target_assigned` evidence without save/public-event leaks. This also fixes the Prismhearth Watch occupied-town bug: `halo_spire` is now explicitly controlled by `faction_mireclaw`, scenario factory/normalization preserve `controlling_faction_id`, and enemy AI uses controlled enemy towns as operational bases while same-faction recruitment/building rules remain guarded. This is scenario-breadth pressure launch evidence, not full strategic AI quality, campaign polish, or final objective planning.

Packaging/platform readiness gate added on 2026-05-23: `export_presets.cfg` now defines Linux and Windows release presets targeting `build/linux/heroes-like.x86_64` and `build/windows/heroes-like.exe`, with local/dev exclusions for `.git`, `.godot`, `.artifacts`, `tmp`, and native `.dll.a` import libraries. `tests/packaging_platform_readiness_report.tscn` validates export preset shape, native GDExtension Linux/Windows editor/debug/release library manifest entries, non-empty referenced native `.so`/`.dll` artifacts, packaged settings/debug paths under `user://`, and boot metadata. This is a repository readiness gate for future packaged smoke tests, not installer completion or release readiness.

Packaging pack-export smoke gate added on 2026-05-23: `tests/packaging_pack_export_smoke.py` now creates a real external `Linux Release` PCK under `.artifacts/packaging_pack_export_smoke/`, verifies it is non-empty, boots it through `godot --headless --main-pack`, and writes a scoped report with command summaries, warning/error tails, PCK size, fatal boot pattern checks, and binary export template availability. This is local Linux-PCK smoke evidence only; it does not claim binary export readiness, Windows packaged smoke coverage, installer readiness, clean-machine validation, or release readiness.

Packaged settings persistence smoke gate added on 2026-05-23: `tests/packaged_settings_persistence_smoke.py` now exports a real external `Linux Release` PCK, runs `tests/packaged_settings_persistence_report.tscn` from that PCK through `godot --headless --main-pack --scene`, writes and reloads `SettingsService` values under `user://config/settings.cfg`, verifies direct `ConfigFile` and reloaded service values, and restores any pre-existing local settings file afterward. This is local PCK settings-persistence evidence only; it does not claim binary export readiness, Windows packaged smoke coverage, installer readiness, clean-machine validation, or release readiness.

Packaged runtime issue-log smoke gate added on 2026-05-23: `RuntimeIssueLog` is now a package-safe autoload that writes sanitized runtime issue JSONL records to `user://debug/heroes_runtime_issues.jsonl` plus a latest-issue snapshot at `user://debug/heroes_last_runtime_issue.json`. `tests/packaged_runtime_issue_log_smoke.py` exports a real external `Linux Release` PCK, runs `tests/packaged_runtime_issue_log_report.tscn` from that PCK through `godot --headless --main-pack --scene`, emits one bounded runtime error record, verifies app/platform/session-safe metadata and sanitized variant payloads, and reads the JSONL/snapshot back. This is a local packaged-runtime error-reporting foundation only; it does not claim native process crash capture, remote telemetry upload, binary export readiness, clean-machine validation, or release readiness.

Windows binary export smoke completed on 2026-05-23: `tests/packaging_windows_export_smoke.py` exports the `Windows Release` preset into `.artifacts/packaging_windows_export_smoke/export/`, inspects the produced `heroes-like.exe` MZ/PE header, sidecar `heroes-like.pck`, and required Windows native GDExtension DLL placement, then writes a scoped report. This closes a packaged-artifact evidence gap beyond Linux PCK smokes; it still does not claim Windows runtime execution, Wine execution, installer readiness, clean-machine validation, code signing, or release readiness.

Linux binary export smoke completed on 2026-05-23: `tests/packaging_linux_export_smoke.py` exports the `Linux Release` preset into `.artifacts/packaging_linux_export_smoke/export/`, inspects the produced `heroes-like.x86_64` ELF artifact, sidecar `heroes-like.pck`, executable permission bits, required Linux native GDExtension `.so` placement, and local headless boot. The slice also routes AppRouter scene transitions through preloaded packed scenes so release exports can resolve string-routed menu/town/battle/outcome/editor surfaces, and loads the main-menu backdrop through package-safe `res://` texture loading before source-file fallback. This is local Linux binary artifact evidence matching the Windows smoke, not installer readiness, clean-machine validation, package signing, distribution metadata, or release readiness.

Main menu archived campaign empty-state smoke completed on 2026-05-23: `scenes/menus/MainMenu.gd` now exposes a truthful disabled `archived_empty` campaign board when player-facing campaign APIs return zero campaigns under the current `archived_native_campaign_set_disabled` reset. `tests/menu_outcome_visual_smoke.gd` now validates that archived campaign entries do not leak, keeps skirmish/settings/save/guide/outcome coverage aligned with the current maps-folder package launch surface, and accepts the current blocked-next-chapter outcome branch. `tests/validate_repo.py` gates the boundary plus `docs/main-menu-archived-campaign-empty-state-smoke-report.md`. This is a UX/test-boundary correction for the current reset state, not campaign-domain reactivation, new campaign content, schema migration, or campaign breadth completion.

Strategic AI raid regroup/retreat added on 2026-05-23: understrength enemy raids now retarget to the nearest reachable owned matching-faction town, transfer spare town garrison units into the field host, synchronize commander army continuity, emit public regroup/retarget events, and resume normal objective selection after crossing the regroup floor. `tests/ai_raid_regroup_retreat_report.tscn` proves the River Pass Vaska raid retreats to Duskfen Bastion and leaves the original player-held resource alone. This is a bounded strategic-AI behavior improvement, not full enemy economy planning, multi-hero grouping, town-defense strategy, or difficulty tuning.

Unit animation visual-QA contact-sheet gate added on 2026-05-23: `tests/unit_animation_manifest_report.tscn` now writes a full-roster battle troop animation contact sheet, asserts unique full-sheet visual fingerprints for every generated unit animation sheet, and records nearest visual neighbors for review. This strengthens the generated animation baseline beyond byte hashes and runtime loadability; it is still not final hand-painted animation approval.

Unit ability runtime consequence gate added on 2026-05-23: melee `harry` units now apply their authored status rider through the same battle ability path as ranged harry units, and `tests/unit_ability_runtime_report.tscn` probes all 143 authored unit ability instances across the 103-unit roster for a concrete runtime consequence. This strengthens the "fully implemented units" proof for current authored mechanics; final balance and hand-authored art approval remain outside this slice.

Unit roster deployment gate added on 2026-05-23: `tests/unit_roster_deployment_report.tscn` now proves all 53 faction units are recruitable through matching-faction town build trees with runtime weekly growth, and all 50 neutral units are deployed through neutral dwellings, army groups, and encounters. This closes a semantic deployment gap beyond raw content references; final balance and hand-authored art approval remain outside this slice.

Unit runtime asset-resolution gate added on 2026-05-23: `tests/unit_runtime_asset_resolution_report.tscn` now exercises every authored unit through `ContentService.get_unit_art()`, `ContentService.get_unit_animation()`, `BattleBoardView` battle-icon and animation-sheet loaders, `OverworldMapView` encounter icon resolution, and `TownShell` portrait texture loading. The report passed with 103/103 units resolving portrait, battle icon, overworld icon, animation sheet, battle stack materialization, and 1,442 animation state-row lookups. This closes the full-roster runtime lookup gap beyond sampled screen checks; final combat balance and hand-authored art approval remain outside this slice.

Unit generated-art reproducibility gate added on 2026-05-23: `tests/unit_art_reproducibility_report.py` imports `tools/generate_unit_art_assets.py`, regenerates every unit portrait, battle icon, overworld icon, and battle animation sheet into temporary storage, and byte-compares the generated PNGs plus both manifests against the committed runtime assets. The report passed with 412/412 generated unit assets and both manifests matching generator output. This closes the drift gap between the reproducible generator and committed generated art; final hand-authored art approval remains outside this slice.

Strategic AI resource-site defense selected on 2026-05-23: active work targets the gap where persistent resource sites controlled by an enemy faction stop being valid same-faction strategic targets, making raids able to capture economy sites but not deliberately hold them under player threat. The slice adds defense-coded resource target validity, live retasking, durable defended-site state, `ai_site_defended` public event evidence, and a required `strategic_ai_live_resource_site_defense` headless harness case. This is one resource-defense behavior increment, not final strategic AI quality or broad economy retuning.

Previous owner-directed RMG corrective slice `native-rmg-generalized-policy-regate-10184` is superseded by this reset. It remains evidence for diagnostics, tooling, and failure history, not the production generator direction.

Current owner-directed RMG reset slice:

id: `native-rmg-small-h3maped-port-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Archive the current native catalog-auto RMG path and start a small-map-only h3maped-derived port with no production fallback to hash selection, per-case fitting, or fake road/zone materialization.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-small-h3maped-reset.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/Downloads/h3maped.exe`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_rmg_small_h3maped_port_boundary_report.gd`
- `tools/rmg_fast_audit.py`
- `tools/rmg_fast_validation.py`
- `tools/rmg_h3maped_controlled_reference.py`
- `tools/rmg_h3maped_small_divergence_audit.py`
- `tools/rmg_h3maped_small_divergence_export.gd`
- `tools/rmg_h3maped_small_divergence_export.tscn`
- `tools/rmg_h3m_native_phase_snapshot_export.gd`
- `tools/rmg_h3m_native_phase_snapshot_export.tscn`
- `tools/rmg_phase_drift_audit.py`
- `tools/rmg_small_manual_inspection_export.gd`
- `tools/rmg_small_manual_inspection_export.tscn`
implementationTargets:
- `docs/native-rmg-small-h3maped-reset.md`
- `src/gdextension/include/h3maped_small_rmg.hpp`
- `src/gdextension/src/h3maped_small_rmg.cpp`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_rmg_small_h3maped_port_boundary_report.gd`
- `tests/native_rmg_small_h3maped_port_boundary_report.tscn`
- `PLAN.md`
- `ops/progress.json`
- follow-up isolated small-map generator modules/tests/tools
- `tools/rmg_h3maped_small_divergence_audit.py`
- `tools/rmg_h3maped_small_divergence_export.gd`
- `tools/rmg_h3maped_small_divergence_export.tscn`
completionCriteria:
- Current native RMG output is archived and disabled by default for production generation.
- The replacement direction is documented as small-map-only and h3maped-derived.
- Supported small-map template selection is derived from executable/spec behavior, not hash fallback.
- Small land generation emits runtime packages only after reward mutation, complete object coordinate vector production, roads, blockers, guards, and final project package adoption are strict executable-derived ports.
- Incomplete executable phases return blocked/not-ready status; they must not produce adapter/proxy runtime output.
- Explicit translated-template requests must not bypass the h3maped selector or fall through to the archived native generator.
- Roads serialize real route geometry, not disconnected visual clusters.
- Zone links are physically guarded/blocked on the produced grid.
- Player starts are placed at owned player towns.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No medium, large, or XL production generator work in this reset slice.
- No visual asset parity/import from Heroes III.
- No one-off owner-corpus exact-count fitting as runtime logic.
- No production-ready broad RMG claim.
- No new one-off owner sample count fitting as runtime policy.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Runtime guard engagement repair on 2026-05-22: guard-control tiles from h3maped-derived native guards now materialize as forced runtime engagement tiles instead of passive metadata. `scripts/core/OverworldRules.gd` indexes unresolved guard engagement surfaces and returns encounter contexts/actions when a hero enters those tiles; `scenes/overworld/OverworldShell.gd` retargets validation hostile-town routes to the first unresolved guard engagement on the path, with a nearest-guard fallback for generated hostile-town routes; `scripts/persistence/NativeRandomMapPackageSessionBridge.gd` maps native-only h3maped guard ids to authored guard battle content while preserving the native id for diagnostics; and `src/gdextension/src/h3maped_small_rmg.cpp` now publishes `package_guard_engagement_tiles` for mine, primary, reward, and connection guards and validates missing guard-engagement surfaces as structural failures. Added focused guard-engagement and guarded-victory playtest reports. Validation passed Linux debug/release native builds, Windows debug/release native builds, focused guard-engagement report, generated-map guarded victory playtest, strict Small boundary report, package surface topology report, public template matrix, controlled divergence audit command, `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check`. The generated-map victory playtest reached victory only after 4 guard battles before the hostile-town assault; strict Small boundary reports `guard_required_route_link_count: 8`, `guarded_route_link_count: 8`, `route_link_without_guard_count: 0`, and `guard_engagement_missing_count: 0`. The controlled divergence audit remains diagnostic for exact parity deltas where existing h3maped references are unavailable or still expose upstream object/placement drift, not a reproduced unguarded-route leak.
- Exact H3M blocker/guard surface repair on 2026-05-22: `src/gdextension/src/h3maped_small_rmg.cpp` now uses recovered H3M non-passable body masks as the package movement-blocking source for h3maped-derived towns, mines, rewards, primary/scenic objects, connection blockers, guards, and decorative obstacles; decorative filler no longer collapses large bodies to one anchor, and runtime start selection now works around exact masks instead of trimming/removing decorative blockers. `tools/rmg_phase_drift_audit.py` now emits a focused blocker/guard surface report covering H3M body/action/guard-control records, native body/block/visit/control records, body-vs-block gaps, guard body blocking, guard-control metadata, and trim-marker violations. `tools/rmg_h3m_native_phase_snapshot_export.gd` also fixes a Godot 4.6 warning-as-error type inference issue. Validation passed Python compilation, Linux debug/release native builds, Windows debug/release native builds, strict Small boundary report, package surface topology report, public template matrix, broad controlled divergence audit, focused controlled blocker/guard audits for `small_3p_seed_11_controlled`, `small_2p_seed_28_controlled`, `small_2p_seed_73_controlled`, and `small_3p_seed_3_controlled`, `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check`. The four focused controlled cases now have blocker/guard surface status `pass` with zero invariant violations and zero body/block gaps; their movement-blocked deltas now match object-blocked deltas, leaving remaining gaps attributable to upstream object selection/placement/count drift rather than package movement-mask loss.
- Selector input identity repair on 2026-05-20: `tools/rmg_h3m_native_phase_snapshot_export.gd` now uses controlled-reference manifest `inputs` as the native selector request identity, including seed, player count, human count, optional computer-only count, water mode, and level count, instead of deriving selector inputs from saved-H3M observed humans. `tools/rmg_phase_drift_audit.py` now separates requested selector identity from observed saved-H3M identity and downgrades recovered-from-misplaced-save template mismatches to `controlled_reference_template_identity_unverified` instead of hard `template_selection_drift`. `src/gdextension/src/h3maped_small_rmg.cpp` and the snapshot exporter now expose accepted-template vector diagnostics. Reauditing existing controlled selector snapshots shows `reference_alignment_pass` for 2p seeds `28`/`73` and 3p seeds `3`/`11`; 4p seed `10` remains `controlled_reference_template_identity_unverified` (`012` recovered reference vs native `027`) because fresh h3maped regeneration blocked with `blocked_h3maped_output_missing`. Validation passed Python compile, Linux debug/release native builds, Windows debug/release native builds, strict Small boundary report, package surface topology report, public template matrix, controlled selector reaudit, `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper; full heavy phase snapshot export for seed `11` timed out at 600s and remains a tooling/performance follow-up.
- Town scheduling/input alignment on 2026-05-20: `tools/rmg_h3m_native_phase_snapshot_export.gd` now consumes controlled-reference manifests as generation inputs, including observed human/computer split, instead of auditing h3maped references against stale default player constraints. `src/gdextension/src/h3maped_small_rmg.cpp` now follows the recovered `0x4a8d2c` first-success town/castle scheduling shape by trying one direct minimum settlement per runtime zone, sending remaining minimum/density work through `0x4a8db2`/`0x4a901a`, including player-owned weighted categories, and preserving full closest-candidate tie vectors instead of capping them to 16. Fresh controlled audits show 2p seed `28` and `73` keep `reference_alignment_pass`; 3p/4p controlled cases still expose real template-selection drift (`seed 11` h3maped template `018` vs native `046`, `seed 3` template `000` vs native `024`, `seed 10` template `012` vs native `048`) before object/blocker deltas can be treated as same-template placement gaps. Current 2p deltas still show the remaining blocker surface clearly: object-blocked tiles are low by `201`/`115`, movement-blocked tiles by `447`/`383`, guards by `16`/`12`, and road comparison remains `road_endpoint_vector_drift`. Validation passed Linux debug/release native builds, Windows debug/release native builds, focused controlled snapshot/audit for five seeds, strict Small boundary report, package surface topology report, public template matrix, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper.
- Object/reward/guard coordinate-commit alignment on 2026-05-20: `src/gdextension/src/h3maped_small_rmg.cpp` now uses full source footprints for primary-category object coordinate commits, disables reward score-threshold rebasing/recovery instead of treating it as an alignment mechanism, changes generated-cell score depletion to orthogonal/diagonal `10/14` costs so strict reward thresholds still produce candidates, and routes mine/primary/reward guards through a generated-cell score plus `0x49a09c` single-tile guard selector instead of nearest-adjacent projection. `tools/rmg_phase_drift_audit.py` now separates coordinate-commit aligned records from remaining proxy/catalog domains. Fresh controlled seed-11 audit keeps `reference_alignment_pass`; native now reports package rewards `47` / reward category `65` vs h3maped rewards `52`, guards `29` vs `29`, objects `267` vs `299`, object-blocked tiles `677` vs `816`, movement-blocked tiles `365` vs `816`, road cells `84` vs `81`, reward score rebasing `0`, recovery fallback `0`, and `57` coordinate-commit aligned records. Remaining projected domains are explicit: mine coordinates/adjacent resources plus primary/reward proxy catalogs. Refreshed broad Small-land audit remains `37/37` green with averages `259.16` package objects, `4.73` towns, `21.51` mines, `45.43` rewards, `37.7` connection guards, `17.03` blockers, and `104.24` road-overlay cells; the highest-risk cases remain road-heavy, not unguarded-route leaks. Validation passed Linux debug/release native builds, Windows debug/release native builds, embedded-data audit, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, template hard-lock report, public template matrix, refreshed broad divergence audit, Python compilation, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper.
- Recovered Small-land template selector alignment on 2026-05-20: `src/gdextension/src/h3maped_small_rmg.cpp` now builds accepted templates from the compiled recovered h3maped catalog instead of the reduced local 13-entry table, supports both embedded recovered and imported catalog schemas, filters candidate zone/link rows by requested player counts, and resolves selected templates back to the real h3maped source catalog entry. Focused selector checks now match the previously missing 2-player controlled cases (`seed 28` and `seed 73` both select `h3maped_template_013`) while preserving known 3-player selections (`seed 3 -> h3maped_template_000`, `seed 11 -> h3maped_template_018`). The public template matrix now covers the full 21-template 2-player Small vector and passed all 45 generation/validator cases. The remaining 4-player seed-10 controlled discrepancy stays visible (`h3maped_template_012` reference vs native recovered-vector `h3maped_template_027`) and was not hidden by seed override or count fitting. Validation passed Linux debug/release native builds, Windows debug/release native builds, embedded-data audit, focused selector snapshots, public template matrix, template hard-lock report, strict Small boundary report, package surface topology report, `jq empty ops/progress.json`, and `git diff --check`.
- Behavior-changing object/reward/guard alignment on 2026-05-20: `src/gdextension/src/h3maped_small_rmg.cpp` now keeps h3maped reward candidates eligible even when no exact project proxy exists by creating explicit generic runtime reward adaptations, disables the normal reward score-gate recovery materialization path in favor of visible score-threshold rebasing, reduces reward attempt pressure from placement-budget fitting to density-derived scheduling, places adjacent guards with generated-cell low-word scores and footprint eligibility instead of first-radius projection, and only creates reward guards for higher-value rewards. Fresh controlled seed-11 audit keeps `reference_alignment_pass` and moves the behavior surface materially closer without count fitting: native reward-reference kind count is `52` vs h3maped reward category `52`, guards `27` vs `29`, objects `267` vs `299`, object-blocked tiles `683` vs `816`, guarded-blocked tiles `763` vs `903`, decorative `152` vs `158`, mine-like `18` vs `18`, towns `4` vs `4`, road cells `84` vs `81`, and recovery fallback records `0`. Remaining drift is still explicit: the final reward category metric is `70` vs `52`, movement-blocked surfaces remain far off (`355`/`479` vs `816`/`903`), road endpoint-vector drift remains, and projected private records are still `96`, so this is a usability-alignment behavior slice, not an exact h3maped port claim. Refreshed broad Small-land audit remains `37/37` green with averages `276.3` package objects, `4.89` towns, `23.54` mines, `62.54` rewards, `42.84` connection guards, `16.59` blockers, and `109.78` road-overlay cells. Validation passed Linux debug/release native builds, Windows debug/release native builds, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, refreshed broad divergence export/audit, Python compilation, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper.
- Object/reward/guard port-fidelity audit on 2026-05-19: `src/gdextension/src/h3maped_small_rmg.cpp` now labels mine, reward, primary-category object, adjacent-resource, and guard records with explicit `port_fidelity`, `exact_port_claim`, and `exactness_blocker` metadata instead of leaving “projected semantics” implicit. The object-vector phase now exports `reward_coordinate_selected_count`, `projected_private_record_count`, `recovery_fallback_record_count`, and a phase-level non-exact-port claim. `tools/rmg_phase_drift_audit.py` now fixes the reward-selected telemetry path, emits `port_fidelity_summary`, adds a root-cause finding for projected/recovery object semantics, and includes a Markdown Port Fidelity section. Fresh controlled seed-11 audit keeps `reference_alignment_pass` while reporting `reward_coordinate_selected_count: 9`, `projected_private_record_count: 69`, `recovery_fallback_record_count: 9`, and projected domains covering mine coordinates/guards/resources, primary-category objects/guards, reward coordinates/guards, and reward proxy lookup. This does not claim byte-level or exact h3maped parity; it makes the remaining non-exact object/reward/guard work machine-visible. Validation passed Linux debug/release native builds, Windows debug/release native builds, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, refreshed broad divergence export/audit, Python compilation, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper.
- Guards/rewards/blocker convergence on 2026-05-19: `src/gdextension/src/h3maped_small_rmg.cpp` now materializes reward guard records from the reward commit path, records score-gate recovery for reward coordinates without treating it as exact parity, seeds decorative occupancy from full mine/reward footprints plus reward guards, and adopts decorative objects with recovered H3M source body footprints while keeping movement block masks separate. `tools/rmg_phase_drift_audit.py` now includes reward guard and recovery evidence in private/package counts and earliest-divergence reporting. Fresh controlled seed-11 audit keeps `reference_alignment_pass`; same-seed diagnostic drift is now explicit and smaller on the major blocker surface: rewards 45 vs h3maped 52, guards 24 vs 29, objects 250 vs 299, object-blocked tiles 659 vs 816, guarded-blocked tiles 749 vs 903, movement-blocked tiles 364 vs 816, guarded-movement-blocked tiles 490 vs 903, decorations 163 vs 158, and road cells 84 vs 81. Remaining gaps are real upstream production/placement issues, not hidden package-mask loss. Refreshed broad Small-land audit still has 37/37 green native cases; averages are 253.62 package objects, 4.89 towns, 23.54 mines, 35.49 rewards, 36.92 connection guards, 16.59 blockers, and 109.78 road-overlay cells. Validation passed Linux debug/release native builds, Windows debug/release native builds, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, refreshed broad divergence export/audit, Python compilation, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper.
- Executable-first h3maped convergence on 2026-05-19: `src/gdextension/src/h3maped_small_rmg.cpp` now records `0x4a9c7c` density mine attempts without treating density weights as guaranteed coordinate records, while preserving the template/placement RNG calls and reporting deferred density materialization. `tools/rmg_phase_drift_audit.py` now emits an `earliest_divergence` section with phase-ordered checks and RNG checkpoints. Fresh controlled seed-11 audit keeps `reference_alignment_pass`; mine-like count now matches h3maped at 18/18; road type byte now matches h3maped type 1; and the first divergent phase is correctly reported as `town_castle_endpoint_vector`, with h3maped endpoints `0:10,26 0:20,12 0:25,5 0:28,20` vs native `0:15,6 0:17,21 0:26,13 0:6,15`. Remaining same-seed drift is explicit: rewards 36 vs 52, guards 19 vs 29, road cells 84 vs 81 with 9-cell overlap, objects 245 vs 299, object-blocked tiles 387 vs 816, and movement-blocked tiles 362 vs 816. The refreshed broad Small-land audit still has 37/37 green native cases; current averages are 249.73 package objects, 4.89 towns, 23.54 mines, 23.57 rewards, 28.51 connection guards, 16.59 blockers, and 109.78 road-overlay cells. Validation passed Python compilation, Linux debug/release native builds, Windows debug/release native builds, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, and refreshed broad divergence audit.
- Object/guard mask-surface repair on 2026-05-19: `src/gdextension/src/h3maped_small_rmg.cpp` now preserves source object passability masks into package body surfaces for mines, primary/scenic objects, rewards, towns, guards, and decorative blockers while keeping separately gated package block surfaces for runtime movement. `tools/rmg_fast_audit.py` and `tools/rmg_phase_drift_audit.py` now distinguish diagnostic H3M-style body footprint metrics from runtime movement-block metrics and report native surface totals by object kind. Fresh controlled seed-11 audit keeps `reference_alignment_pass` and improves same-seed diagnostic footprint drift without count fitting: object-blocked tiles are now native 498 vs h3maped 816 (previously 339 vs 816), guarded-blocked tiles are now 611 vs 903 (previously 339 vs 903), and road unique tiles are 84 vs 81. The new runtime-specific movement metrics report movement-blocked tiles 457 vs 816 and guarded-movement-blocked tiles 587 vs 903, confirming remaining divergence is not hidden by the diagnostic body surface. Native surface attribution for the controlled case is connection blockers 38/38 body/block, decorative blockers 195/194, guards 29/29 plus 246 guard-control tiles, mines 180/180, rewards 36/0, scenic 9/9, and towns 52/48. Broad Small-land audit still has 37/37 green native cases; highest structural risk remains excessive road tiles in `matrix_2p_seed_28`, `matrix_2p_seed_4`, and `matrix_3p_seed_3`. Validation passed Python compile, Linux debug/release native builds, Windows debug/release native builds, focused phase snapshot export, controlled phase-drift audit, package surface topology report, strict Small boundary report, and refreshed broad divergence audit.
- Small h3maped divergence audit on 2026-05-19: added `tools/rmg_h3maped_small_divergence_export.tscn` and `tools/rmg_h3maped_small_divergence_audit.py` to quantify native Small 36x36 one-level land divergence without making exact h3maped byte/count parity a runtime success gate. Fresh report `.artifacts/rmg_h3maped_small_divergence_audit/small_divergence_report.json` covers 37 native 2p/3p/4p Small-land cases; all 37 pass the strict public-generation validator. Native broad averages are 290.65 package objects, 4.89 towns, 41.51 mines, 41.51 rewards, 39.14 connection guards, 16.59 blockers, and 109.78 road-overlay cells. Existing same-seed controlled h3maped seed-11 reference was reused without generating new Wine references and keeps `reference_alignment_pass`: native matches h3maped seed/player/template identity and now matches town count and guard count, but still diverges on mines 36 vs 18, rewards 72 vs 52, objects 291 vs 299, object-blocked tiles 339 vs 816, guarded-blocked tiles 339 vs 903, decorations 172 vs 158, road cells 84 vs 81 with only 9-cell overlap, and road placement classified as `road_endpoint_vector_drift`. Highest native structural-risk cases are `matrix_2p_seed_28`, `matrix_2p_seed_4`, and `matrix_3p_seed_3`, all because road tiles exceed the current broad Small-land heuristic. This audit identifies next real implementation pressure in reward/materialization density, package object masks, and endpoint/placement semantics; it remains diagnostic and read-only with respect to generator behavior.
- Small-land usability parity regate on 2026-05-18: owner direction changed the active acceptance from byte/cell/count parity with controlled h3maped references to player-facing usability parity for strict Small 36x36 one-level land. Exact h3maped road/cell/coordinate drift remains diagnostic evidence only; it is not the generation success gate. `tests/native_random_map_package_surface_topology_report.gd` now asserts usable package topology instead of exact template counts: h3maped source provenance, 36x36x1 land, three owned start towns in distinct zones, guarded route links with zero unguarded route-link metrics, nonempty connected route-road records, route-node/town zone consistency, and object/town/guard/road floors. `tests/native_rmg_small_h3maped_port_boundary_report.gd` was reduced from a byte/count ledger to a Small-land usability boundary covering compiled h3maped data provenance, executable-template authority, green fast validator, generation determinism, package/session adoption, map/scenario validation, save/load round trip, explicit-template authority, and out-of-scope Medium rejection. Fresh validation passed both focused Godot gates. Current seed-1 3p usable output reports template `h3maped_template_027`, 4 towns, 274 package objects, 37 mines, 37 rewards, 37 connection guards, 16 blockers, 8/8 guarded route links, 6 connected road records, 92 unique road cells, zero unguarded route links, and zero disconnected road segments.
- Road endpoint-vector repair follow-up on 2026-05-18: `src/gdextension/src/h3maped_small_rmg.cpp` now builds `generator+0x14b0` road endpoints from recovered town/castle append sites only, preserves `0x4a95af` vs `0x4a932e` provenance, reports mine/reward local coordinate records as excluded local vectors, and fixes duplicate inactive-player minimum-town scheduling. `tools/rmg_h3m_native_phase_snapshot_export.gd` and `tools/rmg_phase_drift_audit.py` now expose excluded local coordinates plus H3M/native endpoint-coordinate comparison. Fresh `small_3p_seed_11_controlled` audit keeps `reference_alignment_pass` and reduces native roads from 772 cells / 41 endpoints / 820 chains to 84 cells / 4 endpoints / 6 chains, with 36 local mine coordinates excluded. The exact-parity diagnostic still reports `road_endpoint_vector_drift` because endpoint coordinates differ from controlled H3M towns: H3M `0:10,26 0:20,12 0:25,5 0:28,20` vs native `0:6,15 0:15,6 0:17,21 0:26,13`; H3M road type byte distribution is `1:81` while native is `2:84`.
- Road generation drift repair on 2026-05-18: `src/gdextension/src/h3maped_small_rmg.cpp` removed the local route-pair policy that connected all town-town pairs and each mine to its nearest town. The road phase now follows the `0x4ab52a` vector-order shape by scanning all later `generator+0x14b0` records, preserving endpoint append provenance, recording `0x4aae2f` reset/rerun telemetry, honoring generated-cell `+0x28` bit 25 when upstream materializes it, and refusing to mark `complete_executable_vector_claim` while upstream endpoint producers still drift. `tools/rmg_h3m_native_phase_snapshot_export.gd` now exports exact private road comparison inputs, and `tools/rmg_phase_drift_audit.py` compares controlled H3M road bytes `4/5/6` with native private/package road cells, intersections, native-only/H3M-only cells, coordinate-vector counts, pair counts, accepted-chain contribution, and road byte distributions. Fresh `small_3p_seed_11_controlled` audit keeps `reference_alignment_pass` and classifies the exact road mismatch as diagnostic `road_endpoint_vector_drift`: H3M 81 road cells, native private/package 772, intersection 48, native-only 724, H3M-only 33, coordinate vector 41, pair count 820, accepted chains 820, and route-pair policy `0x4ab52a_vector_order_all_later_records`. This remains diagnostic upstream endpoint-vector/town/mine producer drift rather than a count-fitting target.
- Seed-controlled h3maped reference gate on 2026-05-18: `tools/rmg_h3maped_controlled_reference.py` now supports an artifact-only PE seed patch against the pinned `/root/Downloads/h3maped.exe`, replacing the generator constructor seed-source call at `0x49d9c4` with a requested seed write while preserving h3maped's own RNG seed setter. The runner copies the executable into the artifact runtime before patching, refuses unexpected bytes, records the patch offsets/bytes/SHA in the manifest, drives the real h3maped GUI under Wine/Xvfb/xdotool, and saves the generated H3M even when Wine's Save As dialog remembers another artifact directory. Fresh `small_3p_seed_11_controlled` output is `ready`: saved H3M summary reports seed `11`, template `2SM2f(2)` / `h3maped_template_018`, 3 humans, 36x36x1 land, and compact metrics of 299 objects, 4 towns, 18 mine-like objects, 52 rewards, 29 guards, 158 decorations, and 81 road cells. `tools/rmg_phase_drift_audit.py` now maps observed h3maped template names through the recovered template catalog and classifies same-seed identity separately from seed-control or template-selection drift. The refreshed seed-controlled phase audit reports `reference_alignment_pass` for native seed/player/template identity, then fails only on real behavior deltas: native towns `5` vs h3maped `4`, mine-like `36` vs `18`, rewards `72` vs `52`, road cells `373` vs `81`, object-blocked tiles `302` vs `816`, guarded-blocked tiles `302` vs `903`, and decorations `134` vs `158`. Validation passed Python compilation, real Wine GUI h3maped generation, H3M parsing, and the seed-controlled phase-drift audit.
- Controlled h3maped GUI reference runner on 2026-05-18: `tools/rmg_h3maped_controlled_reference.py` now runs the pinned `/root/Downloads/h3maped.exe` under Wine/Xvfb/xdotool, stages the required HoMM3 LOD resources under a generated `Data/` runtime directory, drives the real File/New random-map dialog, saves the generated `.h3m`, parses compact H3M metrics, and records screenshots plus the h3maped random-map description. Fresh `small_2p_land_gui_seed_11` output is `ready` with parsed 36x36x1 land metrics, observed h3maped template/seed from the saved map description, and explicit `same_seed_parity_supported: false` because the public h3maped dialog exposes no seed field. `tools/rmg_phase_drift_audit.py` now treats such manifests as `controlled_reference_observed_seed_only`, allowing fresh h3maped-vs-native fact comparison without overclaiming same-seed parity. Validation passed Python compilation, a real Wine GUI generation run, H3M parsing, and a controlled-reference phase-drift audit that still fails by design until seed injection/entrypoint-level generation is recovered.
- Controlled-reference gate and first evidence-backed object/guard corrections on 2026-05-18: added `tools/rmg_h3maped_controlled_reference.py` to verify `/root/Downloads/h3maped.exe` by pinned SHA-256 and write controlled-reference manifests while refusing to treat shipped H3M corpus files or caller-supplied maps as same-identity parity evidence. Because this machine has no committed h3maped GUI automation backend and no Wine, the generated manifest for `small_3p_seed_11` correctly reports `blocked_missing_runner_backend` instead of accepting substitute evidence. `tools/rmg_phase_drift_audit.py` now accepts `--controlled-reference-manifest` and classifies exact parity as `reference_alignment_pass` only when native seed/player/template identity matches a ready controlled manifest; otherwise it reports `controlled_reference_blocked` or uncontrolled corpus sanity. `tools/rmg_fast_audit.py` now counts native `package_guard_control_zone_tiles` as guard-control metadata, reducing the apparent package guard-control loss for the current seed from `245 -> 29` to `245 -> 209`. `src/gdextension/src/h3maped_small_rmg.cpp` removed the local one-in-four mine-adjacent-resource throttle, added the recovered mine template second pass without the terrain bitset when no terrain-specific row exists, and emits both endpoint guards for the `0x4a6cf2` executable branch when scaled guard value is positive. Fresh validation passed Linux debug/release native builds, Windows debug/release native builds, `tools/rmg_h3m_native_phase_snapshot_export.tscn`, `tools/rmg_phase_drift_audit.py --controlled-reference-manifest ...`, `tests/native_rmg_small_h3maped_runtime_corpus_acceptance_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, and `tests/random_map_skirmish_menu_button_2p_retry_report.tscn`. The refreshed drift report still fails by design until a real controlled h3maped output exists and remaining town/reward/road/object-placement drift is repaired.
- H3M/native phase-drift audit tooling on 2026-05-18: `tools/rmg_h3m_native_phase_snapshot_export.tscn` now exports compact native private phase counts plus the generated AMAP for `S-RandomNumberofplayers.h3m` / seed `11`, and `tools/rmg_phase_drift_audit.py` classifies final discrepancies across H3M parsed facts, native private phase counts, and package adoption counts. Fresh output under `.artifacts/rmg_h3m_native_phase_drift_audit/` reports the current Small-land comparison as failing by design: towns `6 -> 5`, mine-like objects `14 -> 36`, literal artifacts `2 -> 0`, guards `45 -> 29`, road tiles `91 -> 386`, object-blocked tiles `732 -> 304`, and guard-control tiles `245 -> 29`. The report classifies town count/placement, mine overproduction, reward/artifact materialization, road overdraw, guard underproduction, and decorative density as `native_private_phase_drift`; blocker/control footprint loss is classified as `package_adaptation_drift`; exact seed/template reference identity remains `reference_alignment_unknown` until native and h3maped.exe are bound to the same original generation inputs. Validation passed the fresh headless Godot snapshot export and `python3 -m py_compile tools/rmg_phase_drift_audit.py`.
- Runtime package-mask completion on 2026-05-16: strict Small-land h3maped generation now carries native package masks through the live runtime instead of falling back to authored resource footprints. `scripts/core/OverworldRules.gd` preserves `package_body_tiles`, `package_block_tiles`, `package_visit_tiles`, and `passability_class` during resource-node normalization and uses package block masks as authoritative body tiles before ContentService footprints. `src/gdextension/src/h3maped_small_rmg.cpp` now removes decorative package objects whose primary tile is selected as a runtime start tile, preventing stripped decorative masks from leaving a blocking runtime object at the hero start. This closed the real client-path p4 seed-5 failure where validation passed but runtime pathing started on a blocked package tile. Validation passed Linux/Windows debug/release native builds, the real Skirmish menu 2p launch path without `--quit-after`, 15-case runtime corpus acceptance, public template matrix, negative validator report, and the native embedded-data audit. Strict Small 36x36 one-level land is now completed for this slice; water, underground, Medium/Large/XL, broader template families, and full HoMM3-style parity remain explicitly out of scope rather than fallback-supported.
- Compiled native h3maped data integration on 2026-05-16: active strict Small-land generation no longer reads `/root`, `h3maped.exe`, recovered JSON/CSV, CRTRAITS, environment toggles, or external evidence at runtime. Template, object, reward, decoration, monster, and TerrainPlacement reference data are compiled into `h3maped_small_rmg_embedded_data` and built into Linux/Windows debug/release GDExtension libraries. Runtime metadata/audit now reports compiled data sources only. Guard pathing now blocks only the guard body tile while preserving 3x3 control zones as engagement metadata, fixing false road-chain validation blocks. Validation passed Linux/Windows debug/release native builds, the native RMG compiled-data audit, strict port boundary report, 15-case runtime corpus, real Skirmish menu 2p launch, six-case validation batch retry, public template matrix, `git diff --check`, `jq empty ops/progress.json`, and the heroes-progress helper. The slice remains blocked for intentionally out-of-scope water, underground, Medium/Large/XL, broader template families, and full HoMM3-style parity.
- Town neutralization correction on 2026-05-15: owner manual review exposed that strict Small-land 2p/3p/4p outputs were only materializing player-count towns, unlike h3maped templates that keep inactive source-player minimum town/castle records and write them as neutral owner `-1`. `src/gdextension/src/h3maped_small_rmg.cpp` now schedules inactive source-player minimum towns/castles as neutralized town records, preserves explicit neutral minimum towns, packages neutral towns with nullable player slots, includes neutral towns in road route nodes, and allows package adoption when total towns exceed player starts while still requiring one owned start town per active player. `scripts/persistence/NativeRandomMapPackageSessionBridge.gd` now accepts neutral town owner/player slots without crashing package-session adoption. The corpus, runtime, topology, and strict boundary reports now gate h3maped-scheduled neutral town counts. Regenerated manual packages now report `manual-strict_small_2p_seed_1` as 4 towns / 2 neutral, `manual-strict_small_3p_seed_2` as 4 towns / 1 neutral, and `manual-strict_small_4p_seed_3` as 8 towns / 4 neutral. Validation passed `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_rmg_small_h3maped_corpus_audit_report.tscn`, `tests/native_rmg_small_h3maped_runtime_corpus_acceptance_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `tests/map_editor_load_map_package_report.tscn`, `tools/rmg_small_manual_inspection_export.tscn`, `tests/maps_folder_package_browser_integration_report.tscn`, and `git diff --check`. The slice remains blocked for the remaining owner-reported map-quality defects: blockers/resources, interactable density, road breadth, and edge density.
- Blocked pending owner/manual inspection on 2026-05-15: `rmg-slices.md` now identifies owner inspection of `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3` as the active next gate. Agent-side implementation is blocked until those packages are accepted as the strict Small-land baseline or concrete defects are reported with package id, seed/player count, and visible symptom. Object breadth, water/islands, underground/two-level, Medium, Large/XL, and broader template-family work remain blocked by the slice order.
- Full strict Small-land gate verification on 2026-05-15: after the topology-preview/manual-review documentation update, the current state passed `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_rmg_small_h3maped_runtime_corpus_acceptance_report.tscn`, `tests/native_rmg_small_h3maped_runtime_acceptance_report.tscn`, `tests/native_rmg_small_h3maped_corpus_audit_report.tscn`, `tests/native_rmg_small_h3maped_template_selection_hard_lock_report.tscn`, `tests/native_rmg_small_h3maped_negative_validator_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `tests/map_editor_load_map_package_report.tscn`, `tests/maps_folder_package_browser_integration_report.tscn`, `tools/rmg_small_manual_inspection_export.tscn`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `jq empty ops/progress.json`, `git diff --check`, and the heroes-progress helper. The owner-review export manifest remained green for all three package pairs with 3/3 editor loads, 3/3 maps-folder index hits, zero unguarded route links, and validator-gated topology previews. A follow-up manual-export audit now distinguishes literal artifact objects from artifact-category reward proxies: the three owner-review packages report artifact proxy counts `2/1/2` and literal artifact object counts `0/0/0`. Artifact and broader neutral-object family proof remains a post-owner-acceptance gap, but the current packages do have artifact-category reward proxies.
- Route-node zone correction on 2026-05-15: manual package-data inspection found generated route graph town nodes carrying `runtime_zone_index == -1` while their referenced town records had valid h3maped runtime zones. `src/gdextension/src/h3maped_small_rmg.cpp` now copies the town `runtime_zone_index` into route nodes, and `tests/native_random_map_package_surface_topology_report.gd` now gates missing town references, unknown route-node runtime zones, and route-node/town zone mismatches for both converted and loaded packages. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_random_map_package_surface_topology_report.tscn`, `tools/rmg_small_manual_inspection_export.tscn`, and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the change; regenerated local manual inspection packages now show concrete route-node runtime zones for all 2p/3p/4p cases.
- Manual inspection package export on 2026-05-15: tracked tool scene `tools/rmg_small_manual_inspection_export.tscn` exported three local owner-review strict Small 36x36 one-level land package pairs under `maps/`: `manual-strict_small_2p_seed_1`, `manual-strict_small_3p_seed_2`, and `manual-strict_small_4p_seed_3`. The exporter used native `generate_random_map()`, direct `convert_generated_payload()`, native package save/load, maps-folder index validation, and `MapEditorShell.validation_load_maps_folder_package()`. `.artifacts/rmg_small_manual_inspection_manifest.json` reports all three cases `ok: true`, `full_generation_status: h3maped_small_public_package_production_ready_strict_small_land`, `generation_status: h3maped_small_validated_package_ready`, `production_ready: true`, `production_ready_scope: strict_small_36x36_one_level_land_only`, paired package hashes, maps-folder index discovery for all three package ids, editor load success for all three package-backed working copies, and per-package `inspection_summary` counts for zones, player-owned/human/computer/neutral towns, route links, guarded links, road records, unique/source/segment road cells, guards, connection blockers, decorative obstacles, mines, rewards, artifacts, object totals, and object counts by kind. The manifest also carries compact `town_start_summary`, `route_gate_summary`, and package-derived `topology_preview` sections. The same run writes `.artifacts/rmg_small_manual_inspection_summary.md`, a human-readable owner review handoff with the exact package ids, acceptance checklist, defect-report format, package paths, editor-load status, topology previews, towns/starts, route gates, road edges, guarded/unguarded links, and object-family counts. The exporter fails if player-owned towns, start towns, start contract counts, town-start summaries, route-link counts, guarded-link counts, unguarded links, road records, or topology-preview dimensions are inconsistent with the strict Small-land case. Repeat with `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_small_manual_inspection_export.tscn`. These generated `.amap` / `.ascenario` files are local owner-inspection evidence and must not be committed.
- Strict Small-land production-ready flag boundary on 2026-05-15: `production_ready` is now true only for `strict_small_36x36_one_level_land_only`, with water, underground, larger sizes, broader template families, and full HoMM3-style parity still explicitly blocked. The post-flag rerun passed `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_rmg_small_h3maped_runtime_corpus_acceptance_report.tscn`, `tests/native_rmg_small_h3maped_runtime_acceptance_report.tscn`, `tests/native_rmg_small_h3maped_corpus_audit_report.tscn`, `tests/native_rmg_small_h3maped_template_selection_hard_lock_report.tscn`, `tests/native_rmg_small_h3maped_negative_validator_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `tests/map_editor_load_map_package_report.tscn`, `tests/maps_folder_package_browser_integration_report.tscn`, and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` for the strict Small 36x36 one-level land scope. The runtime-corpus start-to-road regression was closed by matching native reachability to runtime diagonal blocked-corner semantics while preserving connection blockers and guards as hard gates and allowing only removable decorative-obstacle masks to yield at selected starts. Generated root `maps/*.amap` / `maps/*.ascenario` files were cleaned after validation; uploaded `.h3m` evidence remains uncommitted inspection data.
- Focused Small-land runtime/editor/renderer acceptance on 2026-05-15: `tests/native_rmg_small_h3maped_runtime_acceptance_report.gd` now generates a strict Small 36x36 one-level land package, saves it under `maps/`, starts a runtime session from the saved package pair, independently reloads map/scenario packages, checks package/runtime towns, guards, blockers, mines/rewards, roads, body/visit/block masks, finds a playable route from the hero start to a package road tile, and verifies normal overworld rendering, road presentation, route preview, spatial indexes, and town presentation profiles. The report first exposed a real adoption blocker: 30 of 35 focused road tiles were blocked in runtime. The added attribution showed mostly decorative-object bodies claiming road cells. `src/gdextension/src/h3maped_small_rmg.cpp` now tightens the recovered `0x41e951` footprint gate so any invalid/occupied body-mask cell rejects a decorative candidate instead of allowing partial road overlap. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_runtime_acceptance_report.tscn`, `tests/native_rmg_small_h3maped_corpus_audit_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_rmg_small_h3maped_negative_validator_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, and `tests/native_random_map_guard_reward_package_adoption_report.tscn` passed after the change. This is focused Slice H evidence only; template-selection hard lock, broader manual inspection, water/underground/larger sizes, and full production parity remain pending.
- Focused Small-land template-selection hard lock on 2026-05-15: `src/gdextension/src/map_package_service.cpp` now treats successful Small-land h3maped selection as original h3maped source-template authority even when there is no translated/adapted template id. Supported Small land normalizes to `template_selection_mode == h3maped_exe_rng`, `template_selection_authority == h3maped_exe_rng_original_catalog`, and the selected `h3maped_template_*` id; explicit translated-template requests are recorded and overridden. `src/gdextension/src/h3maped_small_rmg.cpp` now propagates source-template authority and no-fallback flags through selection identity, public generation result, map payload, metadata, and blocked results. `tests/native_rmg_small_h3maped_template_selection_hard_lock_report.tscn`, `tests/native_rmg_small_h3maped_runtime_acceptance_report.tscn`, and `tests/native_rmg_small_h3maped_corpus_audit_report.tscn` passed. This is a focused hard-lock gate only; production readiness still needs broader Small-land evidence and unsupported modes remain blocked.
- Focused Small-land corpus audit on 2026-05-15: `tests/native_rmg_small_h3maped_corpus_audit_report.gd` now gates 15 strict Small-land cases across player counts `2/3/4` and seeds `1..5`. It requires native generation status `h3maped_small_validated_package_ready`, fast structural validator green, exact generated-cell source-state claim true, zero owner-transition diagnostic gap, requested player starts and owned towns, guarded route links, blocking connection blockers/guards, attached road route graph, nonzero roads/mines/rewards/decorative obstacles, package save/load object-count preservation, and strict Small-land `production_ready` scope metadata. The corpus initially exposed missing player towns in several 3/4-player configs because the local `0x4a93a2` town-footprint gate required every body tile to stay inside the origin runtime zone; the recovered evidence requires origin candidate zone match plus footprint bounds/terrain/occupancy checks. `src/gdextension/src/h3maped_small_rmg.cpp` now removes that over-strict body-zone rejection. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_corpus_audit_report.tscn` passed after the change. This is focused Slice G evidence only; broader mode expansion and full production parity remain pending.
- Focused Small-land negative-validator audit on 2026-05-15: `MapPackageService.inspect_h3maped_small_rmg_negative_validator_cases()` now runs injected bad-package fixtures directly through the native `h3maped_fast_structural_validator_phase`. `tests/native_rmg_small_h3maped_negative_validator_report.gd` gates 10 expected rejection cases while the base Small seed-1 package remains green: missing player starts, duplicate placement ids, out-of-bounds objects, missing mines, missing rewards, missing connection blockers, missing connection guards, missing route graph, one-cell fake road segments, and bad final tile-byte array sizes. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_negative_validator_report.tscn` passed after the change. This is focused Slice F evidence only; broad Small-land corpus coverage and editor/runtime acceptance remain pending.
- Focused Small-land object-economy package audit on 2026-05-15: `tests/native_random_map_guard_reward_package_adoption_report.gd` now targets active strict Small h3maped packages instead of stale translated-template/broad-size cases. It asserts package/save-load preservation for mine subtype/resource identity, mine body/visit/block masks, reward value-band provenance, reward proxy catalog ids/DEF references, reward visit masks, and reward passability. After the stricter footprint gate, focused seeds `1` and `4` preserve 54 mines covering all seven h3maped mine subtypes `0..6`, 54 mine block tiles, 6 reward references, 6 value-banded rewards, 3 reward proxy catalog ids, and 18 guards after save/load. `src/gdextension/src/h3maped_small_rmg.cpp` now copies reward value source model, band index/low/high/density, proxy catalog id/path/DEF ref, source kind, and original-project asset policy from the private reward coordinate record to the public package object. This is focused Slice E evidence only; exact placement parity, artifact breadth, broad Small-land corpus coverage, and negative validator cases remain pending. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_random_map_guard_reward_package_adoption_report.tscn` passed after the change.
- Focused Small-land runtime blocker/guard pathing audit on 2026-05-15: `tests/native_random_map_disk_package_startup_report.gd` now compares loaded package guard and connection-blocker block masks against the live session `OverworldRules.tile_is_blocked()` surface after disk package startup. The focused seed-4 Small package preserves 12 guards, 24 connection blockers, 12 guard block tiles, 92 connection-blocker block tiles, matching package/session guard and connection-blocker counts, and zero required package block tiles left passable by runtime pathing. This is focused Slice D runtime pathing evidence only; broad Small-land corpus coverage and negative validator cases remain pending. `tests/native_random_map_disk_package_startup_report.tscn` passed after the change.
- Focused Small-land road-infrastructure package audit on 2026-05-15: `tests/native_random_map_package_surface_topology_report.gd` now asserts that the converted and loaded package roads are h3maped predecessor-chain route infrastructure rather than decorative loops. The focused seed/template requires 3 route nodes, 3 route edges, one connected road component, zero disconnected road segments, zero missing edge/node references, zero endpoint mismatches, zero short route segments, 35 unique road tiles, 47 route segment cells, minimum segment length 12, maximum segment length 21, and exact endpoint-node alignment for all three town-route segments after the corrected `0x4a93a2` town-footprint gate. This is focused Slice C package/save-load evidence only; renderer/pathing runtime acceptance and broad Small-land corpus coverage remain pending. `tests/native_random_map_package_surface_topology_report.tscn` passed after the change.
- Focused Small-land zone-skeleton package audit on 2026-05-15: `tests/native_random_map_package_surface_topology_report.gd` now asserts exact converted/loaded package facts for h3maped template `018` instead of loose floors: 6 zones, 3 owned player start towns, 0 neutral towns, 5 route links, 5 guarded route links, one start town per active player slot, distinct start-town zones, and no unresolved/object-only unguarded town routes. This is focused Slice B package-surface evidence only; corpus and runtime acceptance remain pending. `tests/native_random_map_package_surface_topology_report.tscn` passed after the change.
- Generated-cell `0x4a4c8e` land-edge source-state accounting on 2026-05-15: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes filtered reciprocal `0x49b3fb` runtime-zone relation records from recovered h3maped link seeds and consumes them in the generated-cell decoration bit-state phase. The focused Small land seed reports 10 reciprocal relation records, 1296 scanned cells, 189 owner-low sentinel skips, 1107 non-water owner-low source cells, 8461 neighbor probes, 332 relation lookup-miss triggers, 574 relation byte+8==0 triggers, and 605 exact `0x49aa63(1)` bit-26 candidate writes. A 45-case diagnostic sample across seeds 1-15 and 2/3/4 player Small-land configs found the old owner-transition fallback would add 0 new bit-26 cells, so that fallback no longer writes bit 26 and is now diagnostic-only. `exact_upstream_bit_source_claim` is now true per generated-cell source-state report only when that diagnostic gap is zero; this is not a production-ready RMG claim. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, and `tests/native_random_map_package_surface_topology_report.tscn` passed after the change.
- Editor package visibility on 2026-05-14: validator-gated h3maped Small package pairs now save under `maps/`, reload through `MapPackageService`, index as generated package entries, appear in the editor Load Map picker, and load as package-backed editor working copies without authored JSON or transient generated-draft registry leakage. The fix also keeps player-facing auto h3maped configs on normal guard strength so the strict guard/link validator remains positive, and accepts `generated_h3maped_small_validated` source-kind variants in maps-folder package indexing. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/map_editor_load_map_package_report.tscn`, and `tests/maps_folder_package_browser_integration_report.tscn` passed after the change. Remaining gaps: road/runtime behavior audit, blocker/guard runtime zoning audit, validator negative cases, Small corpus audit, and runtime adoption.
- Public generation authority on 2026-05-14: supported Small 36x36 one-level land configs now return a validator-gated public package from `MapPackageService.generate_random_map()` instead of the previous hard `h3maped_small_clean_restart_generation_not_ready` block. The public result is produced only after package adoption, final `0x49b2b6` writeout, and fast structural validation pass. The focused report asserts deterministic repeat generation for seed `1`, `h3maped_small_validated_package_ready`, seven final tile-byte arrays sized to 1296 cells, package objects, owned player towns and starts, mines, reward references, blocking connection blockers, blocking connection guards, guarded route links, zero links missing blockers/guards, and explicit translated-template requests staying on original h3maped source-template authority. Out-of-scope configs still return `archived_legacy_native_rmg_disabled`. Strict Small-land production readiness was enabled only after later road/runtime, blocker/guard runtime, negative-validator, corpus, and editor/runtime gates passed.
- Package/session adoption bridge on 2026-05-14: `MapPackageService.convert_generated_payload()` now accepts the validator-gated h3maped Small result directly instead of routing it through the archived translated-generator adopter. The focused report asserts conversion kind `h3maped_small_validated_package_to_package_session_records`, adoption status `h3maped_small_package_session_production_ready_strict_small_land`, a 36x36x1 `MapDocument`, synchronized player starts/towns, route links, native runtime authority for the scoped package, strict Small-land `production_ready` scope metadata, save/load identity, and editor visibility for strict Small land package pairs.
- Fast structural validator authority on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now adds a `fast_structural_validator` strict phase after the non-authoritative package and final `0x49b2b6` writeout drafts. The validator runs natively over the draft payload without launching a Godot report scene and currently asserts zero failures for seed `1`: 1296 terrain/final tile cells, 40 package objects, 3 owned player towns and 3 starts, 18 mines, 3 reward references, 10 blocking connection blockers, 6 blocking connection guards, 5 guarded route links, zero links missing blockers/guards, zero duplicate placement ids, and zero out-of-bounds objects. Runtime generation remains blocked: validator authority is true for the draft, but `runtime_generation_allowed`, `public_runtime_authoritative`, and `authorizes_public_runtime` remain false until public generation authority and editor/runtime adoption audit are implemented. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the change.
- Strict final `0x49b2b6` writeout draft on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now adds a non-authoritative `final_h3m_writeout` draft phase after package draft adoption. The focused strict report asserts seven tile-byte arrays sized to the 36x36 surface: terrain byte `0`, terrain art byte `1`, zero river bytes `2/3` for the current small-land scope, road bytes `4/5`, and final flag byte `6` combining terrain flags with road flip bits. The draft carries forward 40 package objects and 5 route links, reports `draft_pass_runtime_blocked`, and keeps `runtime_generation_allowed` and `public_runtime_authoritative` false. Runtime generation remains blocked: `generate_random_map()` still returns `h3maped_small_clean_restart_generation_not_ready`, and the next required ports after validator authority are public generation authority and editor/runtime adoption audit. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the change.
- Strict package draft adoption on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now adds a non-authoritative `public_package_adoption` draft phase after private connection blocker/guard materialization. The focused strict report asserts a draft map document with 1296 terrain tiles, one road overlay segment, 3 owned player towns synchronized with 3 player starts, 18 mine objects, 3 reward objects, 10 connection blocker objects, 6 connection guard objects, 40 package objects total, 5 route links, and `draft_pass_runtime_blocked` structural validation. Runtime generation remains blocked: `generate_random_map()` still returns `h3maped_small_clean_restart_generation_not_ready`, `runtime_generation_allowed` remains false, and the next required ports are final `0x49b2b6` writeout and public validator authority. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the change.
- Strict private connection blocker/guard materialization on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now advances the `0x4a79a3` family past payload-only reporting without enabling runtime package output. It derives private owner-low/high channels through `0x4a5767` / `0x49a318`, builds `0x4a79d8` transition vectors, materializes four `0x4a61bc` same-level endpoint pairs, handles the remaining focused-seed link through the `0x4a7605` / `0x4a7312` second-pass fallback, scales link values through `0x4a65a5`, and records private `0x4a5e03` guard cells. The focused strict report now asserts 5/5 materialized connection records, 10 private blocker cells, 6 private guard records, high-owner propagation, transition-vector materialization, one selected `0x4a7605` fallback, and no public object/runtime/package adoption. The next required strict port is public package adoption after private connection guards; rivers and final `0x49b2b6` writeout remain blocked. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the correction.
- Strict road overlay materialization on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now goes beyond the previous pair-cost boundary. The `roads_and_rivers` phase reconstructs accepted predecessor chains from the `0x4aae7b` low-word route scan, selects road type from the recovered h3maped RNG state, marks private road cells, classifies road art/flip with the recovered `0x458a2f` / `0x458893` tables, and stages `0x49b2b6` road overlay bytes (`tile_byte_4_road_type_u8`, `tile_byte_5_road_art_u8`, and `tile_byte_6_road_flags_u8`). The focused strict report now asserts nonzero road cells, nonzero road art, serialized overlay byte arrays sized to the 36x36 surface, and no public runtime/package adoption yet. The next required strict port is connection blockers/guards (`0x4a79a3` family) before package output. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the correction.
- Strict roads/rivers private boundary on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now reports the narrow `0x4ab52a` coordinate-vector walk and `0x4aae7b` low-word path-cost candidate boundary without enabling runtime output. The focused report asserts byte prefixes for `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, and `0x4b4243`, three town/castle `generator+0x14b0` coordinate records from `0x4a95af`, three pair candidate iterations against threshold `0x7530`, private candidate low-word materialization, and no public road bytes, river bytes, runtime-grid adoption, package tiles, blockers, guards, or final writeout. The next required strict port is road toolkit geometry/writeback (`0x4ab37f` / `0x4b4243`) before connection blockers/guards (`0x4a79a3` family). `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the correction.
- Original h3maped template hydration correction on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now hydrates small runtime-zone records and link seeds directly from `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json` using the h3maped-selected `source_catalog_index`. The selected seed `1` case remains `h3maped_template_018` / catalog index `18` / RNG value `41` / vector index `2`, but the translated project template bridge is disabled for runtime-zone/link semantics and `adapted_template_id` is empty in the focused boundary. Project ids/assets remain allowed only at final content adaptation boundaries after the relevant executable-derived phase is ported. `cmake --build .artifacts/map_persistence_native_build --parallel 2` and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the correction.
- Strict reward coordinate filter/mutation port on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` now carries `0x4aa603` / `0x4aa3e9` into the private mines/rewards/object-vector phase without enabling runtime package output. The focused report asserts byte prefixes for `0x4aa603` and `0x4aa3e9`, terrain-matched reward template selection through `0x4a9e40`, 18 reward value previews, 12 terrain/proxy-backed selected reward object lookups, 3 private reward coordinate records, partial private coordinate count `24`, generated-cell `+0x20` owner/score scan coverage over 1107 owned cells, 12 coordinate scans, 203 coordinate candidates, 3 coordinate RNG calls, private generated-cell body/action mutation counts `3/2`, score-depletion helper `0x4a54a7` called 3 times, and runtime generation still blocked with no public objects, package tiles, or runtime-grid adoption. The next required strict port is roads/rivers plus blockers/guards (`0x4ab52a` / `0x4aae7b` / `0x4a79a3` family); supported small generation still returns `h3maped_small_clean_restart_generation_not_ready`.
- Corrective execution plan on 2026-05-14: the current uncommitted `src/gdextension/src/h3maped_small_rmg.cpp` runtime-output attempt is classified as rejected adapter work, not active progress. The recovery path is to preserve that diff under `.artifacts/` for evidence, remove the uncommitted `generate_runtime_payload`/connection fallback/proxy blocker/guard/road runtime-adoption layer from active code, and resume from the last pushed strict baseline. The next implementation step is the actual executable-derived `0x4aa603` / `0x4aa3e9` reward coordinate filter and generated-cell/object mutation. Roads (`0x4ab52a` family) and connections/blockers/guards (`0x4a79a3` family) remain blocked until their prerequisite vector/mutation state is strict-port complete. Validation must prove blocked status for incomplete phases and must not accept self-declared runtime `"pass"` metadata as correctness evidence.
- Numeric h3maped seed boundary correction on 2026-05-14: the active C++ selection path no longer hashes non-numeric seed text into a uint32. `parse_numeric_seed()` now rejects non-numeric input so the module's `no_hash_selection` policy matches runtime behavior, and report/batch callers now pass explicit numeric seeds. `tools/rmg_native_batch_export.gd` assigns numeric case seeds for artifact export instead of `native-batch-*` strings. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `jq empty ops/progress.json`, and `git diff --check` passed after the correction. A fresh numeric-seed export for uploaded `S-RandomNumberofplayers.h3m` generated successfully under `.artifacts/rmg_native_current_small_land`, but fast comparison still fails as expected: current native small land reports 4 towns, 51 guards, 89 decorations, 80 rewards, 41 road cells in one component, and 0 guarded reachable town pairs versus the uploaded owner H3M's 6 towns, 45 guards, 146 decorations, 49 rewards, 91 road cells in two components, and 2 guarded reachable town pairs. Remaining gap: no-hash policy is fixed, but template-shape/road-component/object-density parity remains incomplete.
- Town minimum scheduling correction on 2026-05-14: executable inspection shows `0x4a8d2c` performs at most one priority direct town/castle placement per zone (`player min castle`, then `player min town`, then `neutral min castle`, then `neutral min town`), while `0x4a8db2` routes the remaining minimum town/castle placements through weighted helper `0x4a901a` with threshold `0`. The active small-land port now follows that schedule instead of placing every minimum through direct `0x4a93a2`, while retaining the project-owned start-town bootstrap for active player zones without an executable town quota. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `jq empty ops/progress.json`, and `git diff --check` passed after the correction. Observed package reports still show small scope only: surface topology seed has 6 zones, 4 towns, 60 guards, 137 decorative obstacles, 43 road tiles, and no reachable unguarded town pairs by package block masks; disk startup seed has 7 towns, 48 guards, 58 decorative obstacles, 68 road tiles. Remaining gap: this fixes a concrete town-placement scheduling divergence, but it is not yet a full h3maped parity proof for road/zone-link topology or all small-template visual quality.
- Town candidate-vector append correction on 2026-05-14: executable inspection shows direct `0x4a93a2` appends selected town/castle coordinates to generator `+0x14b0` at `0x4a95af`, while weighted `0x4a901a` builds its own local candidate vector and appends the selected adjusted coordinate to generator `+0x14b0` at `0x4a932e`. The active small-land port now selects from the complete recovered town candidate vector instead of the first 16 diagnostic entries, preserves `0x4a901a` versus `0x4a93a2` provenance on town records, and carries the correct append address into the road endpoint vector. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `jq empty ops/progress.json`, and `git diff --check` passed after the correction. Remaining gap: this removes another executable-divergent town/road-endpoint assumption; it is not a full small-map parity proof for h3maped road/zone-link topology.
- Executable coordinate-vector correction on 2026-05-14: recovered call-site evidence shows `0x4a9641` mine placement and `0x4aa9b7` reward placement build local candidate vectors, while the road consumer `0x4ab52a` reads the generator `+0x14b0` vector populated by recovered `0x4a95af` town/castle appends in the active small-land path. The active road endpoint vector now excludes mine/reward local candidate records, reducing the focused seed road endpoint vector from 84 polluted records to 4 recovered generator-vector records and road pair candidates from 3486 to 6. Mine/reward records remain package-visible through separate final object-adoption records, so rewards, mines, and object guards are not fed into road topology but still save/load as generated objects. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, `jq empty ops/progress.json`, and `git diff --check` passed after the correction. Remaining gap: this fixes a concrete false vector assumption; it is not a full small-map parity proof for h3maped road/zone-link topology.
- Road toolkit/render correction on 2026-05-14: the active C++ road line stepper now follows the recovered `0x458d66` endpoint/backstep/error-accumulator control flow instead of the earlier forward Bresenham approximation, and the overworld renderer now applies preserved h3maped road flip bits when drawing per-tile road frame textures. `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `tests/native_rmg_small_h3maped_port_boundary_report.tscn`, `tests/native_random_map_package_surface_topology_report.tscn`, `tests/native_random_map_disk_package_startup_report.tscn`, and `tests/native_random_map_guard_reward_package_adoption_report.tscn` passed after the correction. This fixes a real port/render handoff issue; the remaining road gap is still structural topology because active small packages can still serialize one broad road overlay component with hundreds of road tiles.
- Runtime blocker adoption correction on 2026-05-14: the player-facing blocked-tile index now honors generated h3maped package body masks for towns, unresolved guard encounters, and decorative blocker map objects. Guard battle handoff invalidates the cached block surface when an encounter is resolved. This closes a runtime/pathing integration bug where generated blockers and guards could exist in the package but not actually stop movement, making zones look open. `tests/native_random_map_disk_package_startup_report.tscn`, `tests/native_random_map_guard_reward_package_adoption_report.tscn`, and `tests/native_rmg_small_h3maped_port_boundary_report.tscn` passed after the correction. Remaining visible gaps are still h3maped road topology/zone-link parity and broader map-size support.
- Player start ownership correction on 2026-05-14: player-slot/runtime-zone assignment now follows the recovered `0x49ba1b` role-bucket capacity semantics instead of treating only fixed ownership masks as assignable starts. Active player start zones without an explicit player town/castle quota now receive the missing owned start-town bootstrap before package adoption, preserving the seed `1` executable boundary while fixing the `native-batch-s_randomnumberofplayers` small 3-player/template `022` regression from two player starts to three. `tests/native_rmg_small_h3maped_port_boundary_report.tscn` now includes that template `022` regression gate. Remaining visible gaps are still road topology, guarded-zone separation, and broader owner-corpus object density parity.
- Superseded road art handoff note from 2026-05-14: road metadata/output adoption claims from this attempt are rejected until the strict `0x4ab52a` road phase is reintroduced after the complete executable coordinate vector and mutation state exist.
- Superseded road-overlay/package-passability note from 2026-05-14: package road/passability adoption claims from this attempt are rejected until roads and objects come from strict executable-derived phases.
- Protected-object guard package linkage on 2026-05-14: h3maped object guards now target generated mine/reward `object_placement` ids instead of only carrying raw target kind/coordinates, so package conversion can mark guarded rewards and mines through `protected_object_placement_id`. Reward placements also retain HoMM3-re proxy/source metadata (`native_proxy_object_id`, reward tier, value source model, and reward object catalog id) after save/load. A fresh seed `1` small-land export reports `guard_reward_package_adoption.status: pass` with `unguarded_high_value_reward_count: 0`; `tests/native_random_map_disk_package_startup_report.tscn` still passes. Remaining visible gaps are unchanged: strict seed `1` still has 4 towns / 24 guards / 97 decorations and the broader guard/reward package test still exposes road/object block-mask overlap that needs a real pathing-surface decision.
- Superseded connection blocker/guard package adoption note from 2026-05-14: public blocker/guard adoption from the adapter attempt is rejected until `0x4a79a3` / `0x4a61bc` / `0x4a696b` / `0x4a6cf2` / `0x4a7605` are strict executable-derived ports.
- Rejected small h3maped runtime package adoption note from 2026-05-14: `generate_runtime_payload` and `h3maped_small_runtime_package` adoption from the uncommitted attempt were removed from active code. Supported small land generation is back to `h3maped_small_clean_restart_generation_not_ready`.
- Rejected roads and connection blocker/guard port note from 2026-05-14: the road/connection fallback sequence from the uncommitted attempt is preserved only in `.artifacts/rmg_recovery/rejected_h3maped_small_rmg_adapter_runtime_output_20260514.patch` and is not active implementation progress.
- Strict mines/rewards/object-vector prerequisite port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes narrow `0x4a9d6a` / `0x4a9911` / `0x4a9641` mine placement, `0x4aab7e` / `0x4aa354` reward scheduling/value lookup, `0x4a9f1c` selector, `0x4aa9b7` coordinate-commit boundary, and `0x49f95a` candidate-vector ordering over private town candidates. The focused report asserts byte prefixes for those anchors, 18 private mine coordinate records, 21 partial coordinate records including towns, 704 single-level candidate-vector slots, 110 static candidate records, 118 monster candidates, type10/type17/type53 counts `40/58/378`, selector limit counts `30/24`, 18 reward previews/lookups, 154 eligible reward candidates, 35090 candidate weight total, mine RNG state `811474043 -> 2346411599`, reward preview RNG state `2346411599 -> 2283988067`, no reward coordinate commit, no public object/runtime-grid/package adoption, next required port `private_reward_filter_and_mutation_0x4aa603_0x4aa3e9`, three pending strict executable-port groups, and runtime generation still blocked.
- Strict town/castle placement port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes narrow `0x4a8d2c` / `0x4a8db2` town/castle scheduling and `0x4a93a2` / `0x49aa93` / `0x49a09c` / `0x49ba89` direct town record projection over private `0x49b2b6` tile-byte candidates. The focused report asserts binary byte prefixes for `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, and `0x49ba89`, four source minimum player castles, three assigned owned player castle candidates, one skipped unassigned source-owner castle, three direct scans, 445 zone/terrain candidates, 85 footprint-eligible anchors, 39 private occupied body cells, two unique selections, one `0x4e7276` tie selection, synchronized private project town/player-start candidates for owner slots `[1,2,3]` at `(26,16)`, `(23,23)`, and `(18,5)`, no town object/package/runtime-grid adoption, next required port `mines_rewards_and_object_vector_0x4a9d6a_0x4a9911_0x4aa354_0x4a9f1c_0x4aa9b7`, three pending strict executable-port groups, and runtime generation still blocked.
- Strict terrain tile-byte writeback port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x49b2b6` tile-byte projection from private live `0x49acf6` TerrainPlacement generated-cell words. The focused report asserts binary byte prefixes for `0x49b2b6` and `0x49acf6`, 1296 private terrain/art/flag byte candidates, zero terrain-byte mismatches, 1238 nonzero terrain-art cells, 1033 nonzero terrain-flag cells, terrain-byte histogram `0:97, 2:138, 4:262, 5:269, 7:444, 8:86`, flag-byte histogram `0:263, 1:112, 2:150, 3:771`, zero road/river bytes, no package/public-grid adoption, next required port `town_object_placement_0x4a8d2c_0x4a8db2_0x4a93a2`, four pending strict executable-port groups, and runtime generation still blocked.
- Strict TerrainPlacement live-feedback port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4bb74b`/`0x4bc5f0` private repaint/queue feedback pass after decoded visual tables. The focused report asserts binary byte prefixes for `0x4bb74b`, `0x4bba59`, `0x4bbd01`, `0x4bc5f0`, `0x4bc988`, `0x4bcfc3`, `0x4bce6d`, `0x4bad0f`, and `0x49acf6`, 2845 visual attempts/writes, 1296 dirty scratch cells, 942 direct repaint attempts, 607 queue repaint attempts, 176 set-A drains, 10522 set-B drains, 386 true set-B candidates, 221 retouched writes, zero missing visual buckets, zero scratch roundtrip/terrain mismatches, no package-tile/public-grid adoption, next required port `terrain_tile_byte_writeback_0x49b2b6`, five pending strict executable-port groups, and runtime generation still blocked.
- Strict TerrainPlacement visual-table port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4bcff5` TerrainPlacement visual-table/toolkit boundary after private `0x4a3f27` terrain cell writeout. The focused report asserts binary byte prefixes for `0x4bcff5`, `0x4bb5ce`, `0x4bd099`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x4ba938`, `0x4ba989`, `0x4baa94`, `0x4baabf`, `0x4bad0f`, and `0x49acf6`, five decoded visual tables at `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88` totaling 230 rows, ten toolkit constructor records, selector samples choosing rows `60/77/20/11`, scratch words `1925/6565/657/371`, generated-cell words `3842/4930/1288/713`, no hash-art fallback, no visual-record/full-art-grid/package/public materialization, next required port `terrainplacement_live_feedback_0x4bb74b_0x4bc5f0`, five pending strict executable-port groups, and runtime generation still blocked.
- Strict terrain cell writeout port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a3f27` private terrain cell writeout over the real `0x4a325d` zone-word buffer and selected `0x49b53d` runtime terrains. The focused report asserts binary byte prefixes for `0x4a3f27`, `0x4a4025`, `0x4a4082`, and `0x4a415a`, 1296 full-map water-prefill cells, 1107 zone repaint cells, 189 unassigned water cells, 1107 reserved cells, owner-low-byte counts `177/91/226/177/207/229`, terrain counts water `189`, grass `177`, dirt `91`, lava `403`, swamp `207`, rough `229`, no terrain-art/road/object/map-cell/runtime-player/package/public materialization, next required port `terrainplacement_visual_tables_0x4bcff5`, five pending strict executable-port groups, and runtime generation still blocked.
- Strict runtime terrain selection port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x49b53d` runtime-zone terrain selector after the small-land footprint finalizer. The focused report asserts binary byte prefix `56 8b f1 57 8b 06 80 b8 84 00 00 00 00 74 11 8b`, table `0x540908` as `[2,2,3,7,0,0,5,4,2]`, allowed terrain flags source `source_zone+0x85..0x8c`, selected h3maped terrain ids `[2,0,7,7,4,5]`, project terrain ids `[grass,dirt,lava,lava,swamp,rough]`, four town-table selections, two allowed-flag RNG selections, zero blank masks, zero forced-subterranean branches, RNG state `255755822 -> 2166683160`, no terrain-cell/terrain-art/map-cell/runtime-player/package/public materialization, next required port `terrain_cell_writeout_0x4a3f27`, six pending strict executable-port groups, and runtime generation still blocked.
- Strict footprint finalizer port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow small-land `0x4a3710` / `0x4a3efc` / `0x4a3f05` / `0x4cca55` / `0x49b61b` / `0x4a3554` footprint finalizer after private span fill. The focused report asserts binary byte prefixes for all six anchors, one land level, synthetic branch disabled, original/final runtime-zone counts `6/6`, zero appended runtime zones, skipped adjacency insertion phases, six ordering resets, six per-zone ordering rebuilds, zero materialized adjacency, no terrain/map-cell/runtime-player/public materialization, next required port `runtime_terrain_selection_0x49b53d`, six pending strict executable-port groups, and runtime generation still blocked.
- Strict boundary/span-fill port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a2777` / `0x4a2b33` / `0x4a261a` / `0x4a2413` / `0x4a325d` private boundary traversal and span-fill buffer after source-node setup without finalizer, terrain, map cells, or public output. The focused report asserts binary byte prefixes for all five anchors, six runtime-zone boundary walks, zero blocked/fallback zones, six connector segments, 12 final segments, six randomized writer segments, 12 deterministic writer segments, 106 randomized RNG calls, 138 inserted midpoint candidates, final boundary RNG state `264218432`, 301 trace writes, 238 unique boundary cells, six filled zones, one blocked seed, 869 unique filled cells, 1107 boundary-or-filled cells, 189 remaining unassigned cells, per-zone distribution `177/91/226/177/207/229`, next required port `zone_footprint_finalizer_0x4a3710`, six pending strict executable-port groups, and runtime generation still blocked.
- Strict zone-footprint source-node port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a3a03` / `0x4cc788` / `0x4cc955` / `0x4ccb64` / `0x4ccdfc` source-node setup after coordinate replay without boundary trace, span fill, terrain, map cells, or public output. The focused report asserts binary byte prefixes for all five anchors, six matching runtime zones, six split calls, six inserted split pairs, 12 bridge pairs, 34 crossing-cleanup scans, 24 crossing tests, eight crossing collapses, 23 allocated/active node pairs, 14 finalized triplets, 42 finalized nodes, 28 active payload nodes, six source-node walks with zero guard exhaustion, no boundary/span/terrain/map-cell/public materialization, next required port `zone_boundary_and_span_fill_0x4a2777_0x4a325d`, six pending strict executable-port groups, and runtime generation still blocked.
- Strict coordinate replay port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a17f5` / `0x4a1701` / `0x4a1ad8` / `0x4a19ed` coordinate candidate replay, pruning, RNG choice, and bbox rescale without zone footprints, terrain, map cells, or public output. The focused report asserts binary byte prefixes for all four anchors, 18 placement steps, 18 coordinate RNG calls, four interleaved `0x49b3c1` town-choice RNG calls, 22 total replay RNG events, final replay RNG state `255755822`, bbox span `84`, scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, `(12,11)`, no footprint/terrain/map-cell/public materialization, next required port `zone_footprints_0x4a3a03_0x4cc788`, six pending strict executable-port groups, and runtime generation still blocked.
- Strict link-seed port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a1f3b` link-seed setup without coordinates, guards, roads, blockers, or public output. The focused report asserts source range `0x4a1f3b`, binary byte prefix `b8 54 a7 52 00 e8 8b 41 04 00 83 ec 2c 8a 45 0b`, candidate generator anchor `0x4a17f5`, distance validation anchor `0x4a1701`, late payload consumer `0x4a79a3`, five link seeds, first link source zones `1 -> 4` mapping runtime zones `0 -> 3` with guard value `3000`, fourth link guard value `6000`, no coordinate/guard/road/blocker/public materialization, next required port `coordinate_replay_0x4a17f5_0x4a1701`, seven pending strict executable-port groups, and runtime generation still blocked.
- Strict runtime-zone port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4a218c` / `0x49b452` runtime-zone record port without restoring the old active private ledger. The focused report asserts source range `0x4a218c/0x49b452`, binary byte prefixes `55 8b ec 83 ec 28 53 8b d9 56 57 ff b3 e8 10 00` and `55 8b ec 53 56 8b f1 33 db 8a 4d 0b 57 8d 86 e4`, `generator+0x10e0/+0x10e4/+0x10e8` vector offsets, `0x414` runtime record size, six runtime-zone records, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum source base size `11`, no coordinates/terrain/map cells/runtime players/public output, next required port `link_seed_setup_0x4a1f3b`, eight pending strict executable-port groups, and runtime generation still blocked.
- Strict player-slot port on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes the narrow `0x4ac62a..0x4ac6ec` player-slot assignment port without restoring the old active private ledger. The focused report asserts source range `0x4ac62a..0x4ac6ec`, binary byte prefix `6a 09 8d be e0 0e 00 00 59 83 c8 ff f3 ab 33 d2`, `generator+0xee0/+0xee4` assignment/mapping offsets, seed `1` slots `[0,1,2,-1,-1,-1,-1,-1]`, human source owner `0` -> color `0`, computer source owners `1/2` -> colors `1/2`, next required port `runtime_zone_records_0x4a218c_0x49b452`, nine pending strict executable-port groups, and runtime generation still blocked.
- Strict executable restart boundary on 2026-05-13: active `src/gdextension/src/h3maped_small_rmg.cpp` now exposes no `active_generation_state`, `small_generation_state`, `private_generation_context`, private ledgers, or partial package payloads. The focused report asserts `/root/Downloads/h3maped.exe` SHA/MZ/size verification, small-only scope, seed `1` h3maped RNG template selection `h3maped_template_018` / `translated_rmg_template_019_v1` / vector index `2` / RNG value `41`, strict state schema `aurelion_h3maped_small_strict_executable_restart_state_v1`, legacy private phase ledgers archived-only, next required port `player_slot_assignment_0x4ac62a_0x4ac6ec`, ten pending strict executable-port groups, supported small generation blocked with `h3maped_small_clean_restart_generation_not_ready`, explicit translated-template requests blocked, and out-of-scope generation blocked with `archived_legacy_native_rmg_disabled`.
Older detailed validation entries below remain failure-history/evidence records from superseded private-ledger attempts. They are not the active compiled generator contract after the strict restart boundary.
- Mine/reward object-vector prerequisite state on 2026-05-13: active fresh h3maped module now ports the private prerequisite boundary after town/castle placement for `0x4a9d6a` mine requirements, `0x4a9911`/`0x4a9641` mine-coordinate attempts, `0x4aab7e`/`0x4aa354` reward-band scheduling and first-cycle reward value previews, `0x49f95a..0x4a1701` candidate-vector order, `0x4a9f1c` value-banded selector metadata/limit tables, `0x4aa1db`/`0x4a9f1c` private reward-object lookup over proxy-backed recovered `0x49f95a` candidates, and `0x4aa9b7` reward coordinate commit boundary, while still refusing runtime map output. The focused report asserts `active_generation_state` status `object_vector_prerequisite_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprints, terrain_cell_writeout, terrainplacement_visual_tables, terrainplacement_live_feedback, terrain_tile_byte_writeback, town_castle_phase, mines_rewards_and_object_vector]`, 704 single-level candidate-vector records, 110 materialized static subset records, 118 CRTRAITS-backed monster candidates, 40 type-10 candidates, 58 type-17 candidates, 378 type-53 candidates, 30 global and 24 per-zone selector limit overrides, seven mine categories totaling 18 minimum/density weights across six runtime zones, 18 private mine coordinate records through `0x4a9911`/`0x4a9641`, partial coordinate-vector count `21` including towns, 18 eligible reward bands with density sum 96, six scheduler zones, 18 first-cycle reward value previews, 18 reward preview RNG calls, 18 private reward object lookups, 18 selected proxy-backed reward candidates, 18 reward object lookup RNG calls, candidate scan source `proxy_backed_recovered_static_candidates_from_0x49f95a`, land budget argument total `300`, no reward coordinate records, no runtime-grid/package adoption, and next blocker `private_mine_reward_coordinate_filter_and_mutation_0x4aa603_0x4aa3e9`.
- Town/castle private placement state on 2026-05-13: active fresh h3maped module now consumes the private `0x49b2b6` tile-byte boundary and ports private `0x4a8d2c`/`0x4a8db2` player minimum town/castle scheduling plus `0x4a93a2` direct town record projection through `0x49aa93`/`0x49a09c` footprint gates and `0x49ba89` record construction, while still refusing runtime map output. The focused report asserts `active_generation_state` status `town_castle_phase_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprints, terrain_cell_writeout, terrainplacement_visual_tables, terrainplacement_live_feedback, terrain_tile_byte_writeback, town_castle_phase]`, four source player-minimum castles, three assigned owned player castle candidates, one skipped unassigned source-owner castle, 445 direct scan candidates, 85 footprint-eligible anchors, 39 private occupied body cells, two unique closest selections, one `0x4e7276` tie selection, synchronized private project town/player-start candidates for owner slots `[1,2,3]` at `(26,16)`, `(23,23)`, and `(18,5)`, no town object/package/runtime-grid adoption, and next blocker `object_vector_prerequisite_phase_4a9d6a_4aab7e`.
- Terrain tile-byte writeback state on 2026-05-13: active fresh h3maped module now passes live `0x49acf6` generated-cell terrain/art/flag words from private `0x4bb74b`/`0x4bc5f0` TerrainPlacement feedback into the private `0x49b2b6` tile-byte projection, while still refusing runtime map output. The focused report asserts `active_generation_state` status `terrain_tile_byte_writeback_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprints, terrain_cell_writeout, terrainplacement_visual_tables, terrainplacement_live_feedback, terrain_tile_byte_writeback]`, 1296 private terrain/art/flag byte candidates, zero terrain-byte mismatches, 1238 nonzero terrain-art cells, 1033 nonzero terrain-flag cells, terrain-byte histogram `0:97, 2:138, 4:262, 5:269, 7:444, 8:86`, flag-byte histogram `0:263, 1:112, 2:150, 3:771`, zero road/river bytes, no package/public-grid adoption, and next blocker `town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2`.
- TerrainPlacement live feedback state on 2026-05-13: active fresh h3maped module now ports the private `0x4bb74b`/`0x4bc5f0` repaint/queue scratch feedback pass after decoded visual tables, while still refusing runtime map output. The focused report asserts `active_generation_state` status `terrainplacement_live_feedback_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprints, terrain_cell_writeout, terrainplacement_visual_tables, terrainplacement_live_feedback]`, addresses `0x4a4025`, `0x4a4082`, `0x4a415a`, `0x4bb74b`, `0x4bba59`, `0x4bbd01`, `0x4bc5f0`, `0x4bc988`, `0x4bcfc3`, `0x4bce6d`, `0x4bad0f`, and `0x49acf6`, 2845 visual attempts/writes, 1296 dirty scratch cells, 942 direct repaint attempts, 607 queue repaint attempts, 176 set-A drains, 10522 set-B drains, 386 true set-B candidates, 221 retouched writes, zero missing visual buckets, zero scratch roundtrip/terrain mismatches, no package-tile/public-grid adoption, and next blocker `private_0x49b2b6_tile_byte_writeback_candidate`.
- TerrainPlacement visual-table state on 2026-05-13: active fresh h3maped module now consumes the private `0x4a3f27` terrain cell writeout and decodes non-public `0x4bcff5` TerrainPlacement visual-table/toolkit state directly from `/root/Downloads/h3maped.exe`, while still refusing runtime map output. The focused report asserts `active_generation_state` status `terrainplacement_visual_tables_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprints, terrain_cell_writeout, terrainplacement_visual_tables]`, visual table addresses `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, `0x542f88`, row counts `79/46/24/33/48` totaling `230`, ten toolkit constructor records, selector samples choosing rows `60/77/20/11`, scratch words `1925/6565/657/371`, generated-cell sample words `3842/4930/1288/713`, no visual-record/full-art-grid/package-tile/public-grid adoption, and next blocker `live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback`.
- Coordinate replay state on 2026-05-13: active fresh h3maped module now materializes non-public one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay after `0x4a1f3b` link-seed setup. The focused report asserts `active_generation_state` status `coordinate_replay_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay]`, 18 coordinate placement steps, four interleaved `0x49b3c1` town-choice RNG calls, final replay RNG state `255755822`, bbox span `84`, scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, `(12,11)`, no zone-footprint/terrain/map-cell/public-output materialization, and next blocker `zone_footprint_source_nodes_0x4a3a03_0x4cc788`.
- Link-seed internal state on 2026-05-13: active fresh h3maped module now materializes non-public `0x4a1f3b` link-seed setup from the selected adapted template links after runtime-zone records. The focused report asserts `active_generation_state` status `link_seed_setup_active_internal_state`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup]`, five link seeds, first link source zones `1 -> 4` mapping runtime zones `0 -> 3` with guard value `3000`, fourth link guard value `6000`, late payload consumer `0x4a79a3`, and no coordinate, road, blocker, guard, or public output materialization; next blocker remains coordinate replay `0x4a17f5` / `0x4a1701`.
- Player-slot and runtime-zone internal state on 2026-05-13: active fresh h3maped module now materializes non-public `0x4ac62a..0x4ac6ec` player-slot assignment and `0x4a218c` / `0x49b452` runtime-zone records from the selected adapted template catalog. The focused report asserts `active_generation_state` schema `aurelion_h3maped_small_active_generation_state_v1`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records]`, generator offsets `+0xed8/+0xee0/+0xee4` and `+0x10e0/+0x10e4/+0x10e8`, source-owner masks `0x0f/0x0f`, mapped slots `[0,1,2,-1,-1,-1,-1,-1]`, assignment records for human owner `0` and computer owners `1/2`, six runtime zones, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum source base size `11`, no runtime players/map cells/public output, and next blocker `coordinate_replay_and_zone_footprints_0x4a1f3b`.
- Fresh report-treadmill archive on 2026-05-13: the previous 8105-line active `src/gdextension/src/h3maped_small_rmg.cpp` report implementation was archived to `src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp`, and the compiled active module was replaced with a thin executable-anchored boundary only. The focused report asserts schema `aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1`, no `small_generation_state` or `private_generation_context` leakage, verified `/root/Downloads/h3maped.exe` SHA/MZ/size, seed `1` selecting `h3maped_template_018` at source index `18` / vector index `2` / RNG value `41`, 13 accepted small templates, ten pending runtime-port phases after template selection, runtime generation blocked with `h3maped_small_clean_restart_generation_not_ready`, and no partial public output.
- Single-level monster candidate materialization on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now parses extracted `CRTRAITS.TXT` from `H3ab_bmp.lod`, follows the executable row-walk from `0x40cc46`, reads terrain/tier gates from the `0x57cea0` monster table, applies the `0x49c5cd` quantity-bucket formula using the `0x58dc08` power table, and emits 118 private single-level monster candidate records for the `0x49f9ed..0x49fa54` loop. The focused report asserts CRTRAITS path, loader `0x40cc46`, initializer `0x40ce11`, constructor `0x49c5cd`, vector indices `2..119`, descending monster insertion order, boundary records keyed by monster-table and CRTRAITS row indexes with name fields omitted, zero missing/inactive/invalid rows, and keeps extended monsters, terrain-vector loops, and `0x4aa9b7` coordinate commits pending.
- Single-level type-17 candidate materialization on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now materializes 58 private single-level records for the executable `0x4a0402..0x4a045a` loop using constructor `0x49c523`, constructor vtable `0x540ba0`, overridden vtable `0x540c00`, type `0x11`, descending subtypes `0x39..0`, value `-1`, and weight `0x28`. The focused report asserts the loop record count, first/last subtypes, vtable override, 0x14-byte record size, and now fixes absolute candidate-vector indices at `192..249` from the executable one-level builder order.
- Monster-table initializer blocker on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x40ce11..0x40d0c8` monster-table initializer required before materializing the `0x49f9ed..0x49fa54` dynamic monster candidate loop. The focused report asserts table pointer `0x581298`, table `0x57cea0`, stride `0x74`, parsed row source `esi+0x04`, confirmed runtime-populated field `+0x40` from `0x40cf65..0x40cf6d` / parsed row `+0x28`, 118 active small single-level rows, 118 raw static denominator-zero rows, and blocks dynamic monster candidate materialization until the initializer or recovered creature rows are ported.
- Static candidate record materialization on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now emits a private 110-record materialized static candidate subset from the exact recovered `0x49f95a` prefix, `0x49fa54..0x49ff54` fixed type-6 value bands, `0x4a00cc..0x4a0eeb` static tail, and `0x4a1194..0x4a1701` constructor tail. The focused report asserts vector indices `0`, `120`, `178`, `675`, and `703`, source addresses `0x49f97b`, `0x49fa63`, `0x4a00d8`, `0x4a1194`, and `0x4a16d7`, materialized static records true, value vfuncs reconstructed, create vfunc families materialized, dynamic monster/type-10/type-17/type-53 counts and one-level candidate-vector ordering materialized, no complete candidate records, and generation still blocked with `h3maped_small_clean_restart_generation_not_ready`.
- Candidate value-vfunc reconstruction on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the executable-derived `0x4a9f1c` value-vfunc call contract at `0x4a9ffd..0x4aa004` and reconstructs value semantics for `0x49c54d`, `0x49c64b`, `0x49c849`, `0x49ca8b`, `0x49cb60`, and `0x49cd97`. The focused report asserts six reconstructed value vfuncs, constant-value, monster-scaling, terrain-vector-gated, and type10-bucket-gated formulas, disabled true/false vfunc anchors `0x49baf5`/`0x49c54a`, value range filtering at `0x4aa006..0x4aa01d`, selector scan materialization, create-vfunc family materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Candidate create/value-vfunc materialization on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x540ba0..0x540cac` candidate create/value/disabled vfunc table for `0x4a9f1c`, reconstructs the six value-vfunc formulas, and materializes all 17 create-vfunc families from `0x49c553..0x49cdb1`. The focused report asserts 17 vtables, 0x10-byte entries, offsets `+0x00`/`+0x04`/`+0x08`/`+0x0c`, sample mappings `0x540ba0 -> 0x49c553/0x49c54d/0x49c54a`, `0x540bc0 -> 0x49c69b/0x49c64b/0x49c54a`, `0x540c60 -> 0x49cac2/0x49ca8b/0x49baf5`, and `0x540ca0 -> 0x49cdb1/0x49cd97/0x49baf5`, create constructors `0x49ba89`/`0x49bdfc`/`0x49c0d3`, helper/table anchors `0x5044b1`/`0x4a9e40`/`0x592520`/`0x4e7276`, no public coordinate commit materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Candidate builder static constructor tail on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x4a1194..0x4a1701` static constructor tail after the terrain-specialized loop. The focused report asserts 29 records, constructor families `direct writes`, `0x49c523`, `0x49c9bf`, `0x49ccc1`, and `0x49ca26`, vtables `0x540ba0`/`0x540c40`/`0x540c50`/`0x540c90`, sample records `0x4a1194` type `0x54`, `0x4a130d` type `0x5d` field `+0x14 = 1`, `0x4a14c7` type `0x64`, and `0x4a16d7` type `0x71`, static candidate materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Candidate builder type-53 object-bucket loop on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x4a0eeb..0x4a1194` loop over `generator+0x568..0x56c` feeding the `0x4a9f1c` generic value-banded selector. The focused report asserts this is executable object bucket `0x53` from the `0x401d24..0x401e0c` metadata initializer and `0x49da08` producer, not an ad hoc terrain list; bucket `0x53` has no remap override, is not in the flag arrays, has three source rows/subtypes `0..2`, and materializes 378 one-level candidate records from three bucket entries times 118 active monster rows plus eight fixed records. The one-level candidate-vector order is materialized through index 703; coordinate commits remain pending; generation still blocks with `h3maped_small_clean_restart_generation_not_ready`.
- Candidate builder static-tail boundary on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` records the pre-materialization `0x4a0402..0x4a045a` type-17 boundary and 61 fixed/static candidate-tail records from `0x4a00cc..0x4a0eeb` feeding the `0x4a9f1c` generic value-banded selector. The focused report asserts constructor `0x49c523`, overridden vtable `0x540c00`, single-level count `0x3a`, extended count `0x50`, value `-1`, weight `0x28`, tail records including `0x4a0992`/`0x4a0a97` extended vtable `0x540c20` thresholds, final type-82 record `0x4a0ebb`, type-17 materialization was later covered by the dedicated single-level type-17 validation entry, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Candidate builder dynamic-prefix boundary on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x49f95a` monster-table loop, fixed type-6 value-band records, and type-10 object-bucket consumer loop feeding the `0x4a9f1c` generic value-banded selector. The focused report asserts monster table pointer `0x581298` -> table `0x57cea0`, stride `0x74`, `0x49c5cd` constructor vtable `0x540bc0`, single-level count `0x76` with 118 active rows, extended count `0x91` with 141 active rows, 18 fixed type-6 value-band records across vtables `0x540bd0`/`0x540be0`/`0x540bf0`, type-10 bucket vector `generator+0xd8..+0xdc`, selection helper `0x48d21c`, five type-10 value records per bucket entry through vtable `0x540ca0`, the `0x401d24..0x401e0c` metadata initializer, default type-10 bucket remap, 8 source bucket entries, and 40 materialized value-band candidate records. Candidate vector completion remains blocked, generation is still blocked with `h3maped_small_clean_restart_generation_not_ready`, and the next blocker is `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Object-vector prerequisite state on 2026-05-13 after the fresh restart correction: active `src/gdextension/src/h3maped_small_rmg.cpp` now carries the recovered `0x4a9d6a` mine minimum/density fields, `0x4a9911`/`0x4a9641` mine placement anchors, `0x49a09c` circular footprint gate, `0x49a1d8` cell validity, the `0x4aab7e`/`0x4aa354` reward-band scheduler/value-selection boundary, and the `0x4a9f1c` generic value-banded selector metadata/limit-table boundary into a non-public prerequisite phase before roads. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5, terrainplacement_live_feedback_4bb74b_4bc5f0, terrain_tile_byte_writeback_49b2b6, town_castle_phase_4a8d2c, object_vector_prerequisite_phase_4a9d6a_4aab7e]`, three town coordinate records, 18 mine minimum scans, 18 private mine coordinate records, partial coordinate-vector count `21`, 18 mine density weight, 18 eligible reward bands, reward-band weight `96`, six reward scheduler zones, 18 first-cycle reward value previews, land budget argument total `300`, `0x4a9f1c` candidate vector offset `generator+0x10f4..+0x10f8`, default object limit `0x7d00`, 30 global-limit overrides, 24 per-zone-limit overrides, metadata flag counts `42/34/42/95`, 1870 mine placement candidates, 135 special wood/ore squared-distance rejections from the confirmed `0x4a9641` metric, no reward object candidate reconstruction, no reward coordinate commits, no public-object/public-road/public-package materialization, roads blocked with `blocked_until_complete_generator_plus_0x14b0_coordinate_vector`, generation blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aab7e_rewards_density_guards_adjacent_resources_before_0x4ab52a`.
- Reward coordinate commit boundary on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the recovered `0x4aa9b7..0x4aab7b` reward coordinate scan/random-pick boundary called by `0x4aab7e`. The focused report asserts generated-cell base `generator+0x14`, score word `+0x20`, scan loop `0x4aaa2d..0x4aab0a`, owner-byte and score-threshold gates, helpers `0x4aa603`, `0x4ae1fd`, `0x4ae52a`, `0x4aa3e9`, RNG `0x4e7276`, and keeps private reward coordinate records, reward object adoption, public objects, roads, and package output blocked until `0x4aa603` and `0x4aa3e9` are ported against project object templates.
- Reward filter/final-commit helper boundaries on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now splits the `0x4aa9b7` blocker into recovered `0x4aa603..0x4aa9b4` filter gates and `0x4aa3e9..0x4aa603` generated-cell/object mutation. The focused report asserts `0x4aa603` child collision `0x49a6f9`, special object type `0x36` neighborhood rejection, direction table `0x5a2658`, validity helper `0x49a1d8`, final footprint helper `0x49a09c`, and body collision scan, plus `0x4aa3e9` coordinate write to object `+0x54..+0x5c`, child vfunc slots `+0x04/+0x08`, transform helper `0x49d2c7`, state setters `0x49a932/0x49aa63`, and keeps private filter evaluation, generated-cell mutation, reward object adoption, and public package output blocked.
- Town/castle private placement state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now runs private `0x4a8d2c`/`0x4a8db2` town/castle scheduling and `0x4a93a2`/`0x49aa93`/`0x49a09c`/`0x49ba89` direct town record projection after `0x49b2b6` tile-byte writeback. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5, terrainplacement_live_feedback_4bb74b_4bc5f0, terrain_tile_byte_writeback_49b2b6, town_castle_phase_4a8d2c]`, three owned player town/castle candidates, three synchronized player starts, one skipped unassigned source-owner castle, 445 direct scan candidates, 85 footprint-eligible anchors, 39 private occupied body cells, two unique closest selections, one `0x4e7276` tie selection, private project town candidates for owner slots `[1,2,3]` at `(26,16)`, `(23,23)`, and `(18,5)`, no package/runtime-grid adoption, generation blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243`.
- Terrain tile-byte writeback state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now projects live `0x4bb74b`/`0x4bc5f0` TerrainPlacement `0x49acf6` generated-cell words through the private `0x49b2b6` terrain tile-byte contract. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5, terrainplacement_live_feedback_4bb74b_4bc5f0, terrain_tile_byte_writeback_49b2b6]`, executable addresses `0x4a4025`, `0x4a4082`, `0x4a415a`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x4bad0f`, `0x49acf6`, and `0x49b2b6`, 1296 private terrain/art/flag byte candidates, zero terrain-byte mismatches, nonzero terrain art byte and terrain flag byte coverage, zero road/river bytes, no package/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `town_castle_phase_4a8d2c_0x4a8db2_0x4a93a2`.
- Runtime terrain selection state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now runs non-public h3maped `0x49b53d` terrain selection after the small-land footprint finalizer, using the nine-town table at `0x540908` and source-zone allowed terrain flags. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d]`, selected h3maped terrain ids `[2,0,7,7,4,5]`, project terrain ids `[grass,dirt,lava,lava,swamp,rough]`, four town-table selections, two allowed-flag RNG selections, zero blank masks, zero forced-subterranean branches, RNG state `255755822 -> 2166683160`, zero terrain-cell/terrain-art/map-cell/runtime-player/package/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `terrain_cell_writeout_4a3f27`.
- Footprint finalizer state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now runs the small-land `0x4a3710` finalizer path after private span fill, with no appended synthetic runtime zones and with adjacency insertion loops skipped. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710]`, call site `0x4a3efc..0x4a3f05`, locator `0x4cca55`, clip helper `0x4a2b33`, ordering reset `0x49b61b`, per-zone order helper `0x4a3554`, one land level, synthetic branch disabled, original/final runtime-zone counts `6/6`, zero appended runtime zones, skipped adjacency insertion phases, six ordering resets, six per-zone ordering rebuilds, zero materialized adjacency, zero terrain/map-cell/runtime-player/package/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `runtime_terrain_selection_49b53d`.
- Span-fill state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now feeds the private `0x4a2777` boundary buffer into recovered `0x4a325d` span fill using runtime-zone `+0x10` seed coordinates, while still refusing public package output. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d]`, boundary source `0x4a2777`, six fill attempts, six filled zones, one blocked initial seed, zero relocations, 869 filled interior cells, 1107 boundary-or-filled private cells, 189 remaining unassigned cells, 1107 reserved-flag cells, 93 pushed/popped spans, max pending span count `3`, zero out-of-bounds spans, per-zone distribution `177/91/226/177/207/229`, zero terrain/map-cell/runtime-player/package/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `footprint_finalizer_4a3710`.
- Generic value-selector candidate-builder prefix on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now records the first two fixed `0x49f95a` candidate-builder records used by the `0x4a9f1c` generic value-banded selector. The focused report asserts candidate vector offset `generator+0x10f4..+0x10f8`, builder address `0x49f95a`, fixed records `0x49f97b` vtable `0x540ba0` type `2` subtype `0` value `100` weight `20` and `0x49f9be` vtable `0x540ba0` type `4` subtype `0` value `3000` weight `50`, dynamic monster-table, type-10, type-17, type-53 counts, and one-level candidate-vector ordering partially materialized, zero reward object materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `port_0x4aa9b7_coordinate_commit_and_reward_object_adoption`.
- Source-node boundary traversal state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now feeds recovered `0x4ccb64`/`0x4ccdfc` source-node cycles into private `0x4a2777` traversal through `0x4a2b33`, `0x4a261a`, and `0x4a2413`. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal]`, six runtime-zone walks, zero fallback zones, six connector segments, zero wrap segments, 12 final segments, 18 appended vertices, 12 skipped out-of-bounds clips, six flagged writer segments, 12 deterministic writer segments, 106 randomized RNG calls, 138 randomized midpoint candidates, final RNG state `264218432`, 301 private trace writes, 238 unique private boundary cells, zero out-of-bounds writes, zero span-fill/terrain/map-cell/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `span_fill_4a325d`.
- Polygon split/finalizer state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now implements compact non-public `0x4ccb64` source-node split insertion/bridge/crossing cleanup and `0x4ccdfc` source-node finalization over the recovered `0x4a19ed` scaled zone centers. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model]`, six split calls, zero duplicate skips, zero edge-removal branches, six inserted split pairs, 12 bridge pairs, 34 crossing-cleanup scans, 24 crossing tests, eight crossing collapses, 23 active source-node pairs, 14 finalized coordinate triplets, 42 finalized nodes, six source-node walks with zero guard exhaustion, zero boundary/span-fill/terrain/map-cell/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `source_node_boundary_traversal_0x4a2777`.
- Zone-footprint source-node boundary on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now implements non-public `0x4a3a03` per-level runtime-zone helper scheduling and `0x4cc788` initial source-node rectangle setup after coordinate replay. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay, zone_footprint_phase_boundary, source_node_rectangle]`, six collected runtime zones, six queued `0x4a2777` helper inputs, no one-level land synthetic zone append, bounds `-200,-200..400,400`, constants `0xffffff38` and `0x190`, four `0x4cc955` rectangle edges, zero source-node-graph/boundary/span-fill/terrain/map-cell/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `polygon_split_model_0x4ccb64_0x4ccdfc`.
- Coordinate replay state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now implements recovered project-template link seeds through `0x4a1f3b` plus one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay as non-public generation state. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay]`, five link seeds with guard values `[3000,3000,3000,6000,6000]`, 18 coordinate placement steps, four interleaved `0x49b3c1` town-choice RNG calls, final replay RNG state `255755822`, bbox span `84`, scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, `(12,11)`, zero zone-footprint/terrain/map-cell/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `zone_footprint_source_nodes_0x4a3a03_0x4cc788`.
- Runtime-zone records state on 2026-05-13 after the fresh restart, corrected on 2026-05-14: active `src/gdextension/src/h3maped_small_rmg.cpp` implements `0x4a218c` / `0x49b452` runtime-zone records as non-public generation state by loading the selected original recovered h3maped template from `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json` and applying the active player-slot mapping. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records]`, `h3maped_template_018` at catalog index `18`, vector offsets `generator+0x10e0/+0x10e4/+0x10e8`, record size `0x414`, six runtime zones, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum base size `11`, zero runtime-zone-coordinate/terrain/map-cell/runtime-player/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `coordinate_replay_and_zone_footprints_0x4a1f3b`.
- Player-slot assignment state on 2026-05-13 after the fresh restart: active `src/gdextension/src/h3maped_small_rmg.cpp` now implements the first post-template h3maped phase as non-public generation state from `0x4ac62a..0x4ac6ec`, using the selected template source-owner masks and `generator+0xed8/+0xee0/+0xee4` slot arrays. The focused report asserts schema `aurelion_h3maped_small_generation_state_v1`, completed phases `[template_selection, player_slot_assignment]`, seed `1` selected template `h3maped_template_018` masks `0x0f/0x0f`, source-owner indices `[0,1,2,3]`, `raw_ee0_slots` and `mapped_ee4_slots` `[0,1,2,-1,-1,-1,-1,-1]`, assignment records human source owner `0` -> color `0` and computer source owners `1/2` -> colors `1/2`, no runtime-player/map-cell/public-output materialization, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `runtime_zone_records_0x4a218c`.
- Fresh restart boundary on 2026-05-13 after owner correction: the overgrown active small h3maped port was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp`, and active `src/gdextension/src/h3maped_small_rmg.cpp` was reduced to binary verification, 36x36 one-level land scope, recovered size/water scoring, h3maped RNG template selection, a strict phase backlog, and blocked runtime output only. The focused report asserts schema `aurelion_native_rmg_small_h3maped_restart_boundary_v2`, no `private_generation_context`, seed `1` selecting `h3maped_template_018` / source catalog index `18` / vector index `2` / RNG value `41`, 13 accepted templates, every phase after template selection `pending_strict_port`, supported small generation blocked with `h3maped_small_clean_restart_generation_not_ready`, explicit translated-template requests blocked, and out-of-scope generation blocked with `archived_legacy_native_rmg_disabled`. Older private-context phase entries below are archived evidence only, not active compiled generator behavior.
- Town/castle private placement boundary on 2026-05-13 after the fresh reset: the compact active h3maped boundary now ports the private `0x4a8d2c`/`0x4a8db2` minimum town/castle schedule and `0x4a93a2`/`0x49aa93`/`0x49a09c`/`0x49ba89` direct town record projection from the executable-derived zone words and live TerrainPlacement terrain grid, without public runtime-grid/package adoption. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5, terrainplacement_live_feedback_4bb74b_4bc5f0, terrain_tile_byte_writeback_49b2b6, town_castle_phase_4a8d2c]`, private context status `town_castle_phase_private_context_ready`, four source player-minimum castles, three assigned owned player castles, one skipped unassigned source-owner castle, three direct town scans, 445 zone/terrain candidates, 85 footprint-eligible anchors, 39 private occupied body cells, two unique selections plus one `0x4e7276` tie selection, synchronized project town/player-start candidates for owner slots `[1,2,3]` at `(26,16)`, `(23,23)`, and `(18,5)`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `roads_and_rivers_0x4ab52a_0x4aae7b_0x4ab37f_0x4b4243`.
- TerrainPlacement live feedback boundary on 2026-05-13 after the fresh reset: the compact active h3maped boundary now ports the private `0x4bb74b`/`0x4bc5f0` repaint/queue feedback pass after the decoded visual-table boundary, without adopting package tiles or public map output. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5, terrainplacement_live_feedback_4bb74b_4bc5f0]`, addresses `0x4a4025`, `0x4a4082`, `0x4a415a`, `0x4bb74b`, `0x4bba59`, `0x4bbd01`, `0x4bc5f0`, `0x4bc988`, `0x4bcfc3`, `0x4bce6d`, `0x4bad0f`, and `0x49acf6`, 2845 visual attempts/writes, 1296 dirty cells, 176 set-A drains, 10522 set-B drains, 386 true set-B candidates, 221 retouched writes, zero missing visual buckets, zero terrain roundtrip mismatches, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `private_0x49b2b6_tile_byte_writeback_candidate`.
- TerrainPlacement visual table/toolkit boundary on 2026-05-13 after the fresh reset: the compact active h3maped boundary now decodes the `0x4bcff5` static terrain visual rows and toolkit constructor records directly from `/root/Downloads/h3maped.exe`, with no hash art fallback and no public package materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27, terrainplacement_visual_tables_4bcff5]`, five decoded visual tables at `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88` totaling 230 rows, ten toolkit constructor records, selector samples for grass row `60`, normal transition row `77`, water transition row `20`, and rock row `11`, scratch/writeback samples through `0x4bad0f` and `0x49acf6`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback`.
- Terrain-cell writeout private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now runs `0x49b53d` runtime terrain selection and `0x4a3f27` terrain/cell writeout from the real private `0x4a325d` span-filled zone-word buffer, with no terrain art, road, object, package-tile, map-cell, runtime-player, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710, runtime_terrain_selection_49b53d, terrain_cell_writeout_4a3f27]`, h3maped terrain ids `[2,0,7,7,4,5]`, project terrains `[grass,dirt,lava,lava,swamp,rough]`, two terrain RNG calls from state `255755822` to `2166683160`, 1296 cells, 1107 non-water terrain cells, 189 unassigned water cells, 1107 reserved-flag cells, owner-byte counts matching span-fill zone distribution `177/91/226/177/207/229`, terrain counts water `189`, grass `177`, dirt `91`, lava `403`, swamp `207`, rough `229`, tile byte-zero terrain packed, tile byte-one art and byte-six terrain flips still zero, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `live_TerrainPlacement_0x4bb74b_0x4bc5f0_scratch_feedback`.
- Footprint finalizer private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now runs the small-land `0x4a3710` finalizer path after private span fill, with no appended synthetic zones and no terrain, map-cell, runtime-player, adjacency, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d, footprint_finalizer_4a3710]`, call site `0x4a3efc..0x4a3f05`, locator `0x4cca55`, clip helper `0x4a2b33`, ordering reset `0x49b61b`, per-zone order helper `0x4a3554`, one land level, synthetic branch disabled, original/final runtime-zone counts `6/6`, zero appended runtime zones, skipped adjacency insertion phases, six ordering resets, six per-zone ordering rebuilds, zero materialized adjacency, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `0x4a3f27_terrain_cell_writeout`.
- Span-fill private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now feeds the private `0x4a2777` boundary buffer into `0x4a325d` span fill without terrain, map-cell, runtime-player, package-tile, public-grid, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal, span_fill_4a325d]`, boundary source `0x4a2777`, seed source `runtime_zone+0x10`, six fill attempts, six filled zones, one blocked seed, zero relocations, 869 filled interior cells, 1107 boundary-or-filled private cells, 189 remaining unassigned cells, 1107 reserved-flag cells, 93 pushed/popped spans, max pending span count 3, zero out-of-bounds spans, per-zone distribution `177/91/226/177/207/229`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `0x4a3710_ordering_finalizer`.
- Source-node boundary traversal private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now feeds recovered `0x4ccb64`/`0x4ccdfc` source-node cycles into private `0x4a2777` traversal evidence through `0x4a2b33`, `0x4a261a`, and `0x4a2413`, without span-fill, terrain, map-cell, runtime-player, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model, source_node_boundary_traversal]`, six consumed runtime-zone walks, zero fallback zones, six connector segments, zero wrap segments, 12 final segments, 18 appended vertices, 12 skipped out-of-bounds clips, 106 randomized RNG calls, 138 inserted midpoint candidates, final RNG state `264218432`, 301 trace writes, 238 unique boundary cells, zero out-of-bounds writes, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `0x4a325d_span_fill`.
- Polygon split private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now ports `0x4ccb64` insertion/bridge/crossing cleanup and `0x4ccdfc` source-node finalization over the recovered `0x4a19ed` zone centers without boundary, span-fill, terrain, map-cell, runtime-player, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle, polygon_split_model]`, six split calls, 12 bridge pairs, 34 crossing-cleanup scans, 24 crossing tests, eight crossing collapses, 23 active source-node pairs, 14 finalized coordinate triplets, 42 finalized nodes, six source-node walks with zero guard exhaustion, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker feeding finalized cycles into real `0x4a2777` boundary traversal.
- Source-node rectangle private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now builds `0x4a3a03` zone-footprint helper scheduling and `0x4cc788` initial source-node rectangle setup without boundary, span-fill, terrain, map-cell, runtime-player, or public-output materialization. The focused report asserts completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints, zone_footprint_phase_boundary, source_node_rectangle]`, six queued `0x4a2777` helper inputs for runtime zones `[0,1,2,3,4,5]`, no synthetic `0xd4` source-zone append for one-level land, initial source-node bounds `-200..400`, constants `0xffffff38` and `0x190`, four `0x4cc955` rectangle edges, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and next blocker `polygon_split_model_0x4ccb64_0x4ccdfc`.
- Coordinate replay private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now builds selected-template `0x4a1f3b` link seeds and one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay without terrain, map-cell, zone-footprint, road, guard, blocker, runtime-player, or public-output materialization. The focused report asserts five link seeds with guard values `[3000,3000,3000,6000,6000]`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records, link_seed_setup, coordinate_replay_and_zone_footprints]`, 18 coordinate placement steps, four interleaved `0x49b3c1` town-choice RNG calls selecting elemental/necropolis/inferno/fortress, final replay RNG state `255755822`, bbox span `84`, scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, `(12,11)`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and no old top-level inspection-ledger fields exposed.
- Runtime-zone private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now builds selected-template `0x4a218c` runtime-zone records without coordinate, terrain, map-cell, runtime-player, or public-output materialization. The focused report asserts `h3maped_template_018` six source zones, vector offsets `generator+0x10e0/+0x10e4/+0x10e8`, `0x414`-byte records, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum source base size `11`, completed phases `[template_selection, player_slot_assignment, runtime_zone_records]`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and no old top-level inspection-ledger fields exposed.
- Player-slot private context on 2026-05-13 after the fresh reset: the compact active h3maped boundary now builds selected-template `0x4ac62a..0x4ac6ec` player assignment context without runtime-player or public-output materialization. The focused report asserts private context schema `aurelion_h3maped_small_private_generation_context_v1`, completed phases `[template_selection, player_slot_assignment]`, `h3maped_template_018` source-owner masks `0x0f/0x0f`, generator offsets `+0xed8/+0xee0/+0xee4`, raw/mapped slots `[0,1,2,-1,-1,-1,-1,-1]`, assignment records human source owner `0` -> color `0` and computers source owners `1/2` -> colors `1/2`, generation still blocked with `h3maped_small_clean_restart_generation_not_ready`, and no old top-level inspection-ledger fields exposed.
- Fresh reset correction on 2026-05-13: the previous active 6.7k-line phase ledger was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`, and `src/gdextension/src/h3maped_small_rmg.cpp` is again a compact strict boundary. The focused report asserts schema `aurelion_native_rmg_small_h3maped_fresh_boundary_v1`, `/root/Downloads/h3maped.exe` SHA/MZ/size verification, small-only scope, seed `1` h3maped RNG template selection `h3maped_template_018` / source index `18` / vector index `2`, 13 accepted templates, absence of old inspection-ledger fields, runtime generation blocked with `h3maped_small_clean_restart_generation_not_ready`, explicit translated-template requests blocked, and out-of-scope generation blocked with `archived_legacy_native_rmg_disabled`. Older detailed phase-ledger validation entries below are archived evidence only, not active compiled generator behavior.
- Same-level transition-vector boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now carries `0x49a318` generated-cell `+0x28` bit25/direction writes into the private terrain-cell grid and ports the `0x4a79a3` transition-vector gate plus `0x4a61bc` directional candidate score scan as inspection-only evidence. The focused report asserts 1107 materialized bit25 cells, 1107 direction-bit cells, 324 transition-vector candidates, 211 directional candidates across five template links, four links with directional candidates, link `0` candidate counts `56/52` with min path scores `12/10`, link `2` candidate counts `0/0`, link `4` candidate counts `24/23`, zero endpoint coordinates, zero guard/road materialization, and remaining blocker in endpoint write/guard branches plus fallback/object placement.
- High-owner propagation `0x4a5767`/`0x49a318` on 2026-05-13 after the hard restart: the active strict h3maped reset now ports the baseline owner/materialized/terrain path as private inspection-only evidence. The focused report asserts six runtime-zone anchor seeds, zero blocked seeds, 3594 popped propagation cells, 1101 same-owner relaxes, 2487 cross-owner high-byte writes, max queue size 73, 1107 materialized high-owner cells, 189 sentinel cells, high-owner counts `0:173`, `1:162`, `2:200`, `3:262`, `4:134`, `5:176`, and all five same-level links with both low and high owner-channel cells. Remaining blockers are the extra `0x49a318` bit22/object metadata branch and actual endpoint candidate success in `0x4a61bc`/`0x4a696b`/`0x4a7605`; runtime generation remains disabled.
- Same-level owner-channel precondition on 2026-05-13 after the hard restart: the active strict h3maped reset exposes the generated-cell owner byte inputs required by `0x4a61bc`/`0x4a696b`. The focused report asserts `owner_low_byte_grid_u8`, `owner_high_byte_grid_i8`, and `zone_word_low_u16` across all 1296 cells; low owner bytes are materialized from the real `0x4a325d` zone words for 1107 cells with counts `0:177`, `1:91`, `2:226`, `3:177`, `4:207`, `5:229`. This entry originally identified high-owner propagation as the next blocker; the newer `0x4a5767`/`0x49a318` entry above supersedes that blocker with materialized high-owner counts, while endpoint geometry and guard/road/object adoption remain pending.
- Late connection payload and same-level dispatch correction on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23` as inspection-only evidence over the real private generated-cell zone grid. The focused report asserts five unique links, ten reciprocal link records, ten processed-marker writes at `+0x0a`, raw guard values `[3000,3000,3000,6000,6000]`, scaled guard values `[2000,2000,2000,5000,5000]`, zero `Wide` suppressions, zero Border Guard special links, corrected `0x4a6cf2` same-level return-false count `5`, zero overlap cells, same-level helper readiness counts `5` for both `0x4a61bc` and `0x4a696b`, second-pass `0x4a7605` pending-if-unprocessed count `5`, and no road/river geometry, endpoint object, guard, blocker, or package materialization.
- Town/castle phase and private town/start projection on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` as inspection-only evidence over the post-queue generated-cell terrain grid. The focused report asserts four source minimum player castles, three assigned owned player castles for owner colors `[0,1,2]`, one skipped unassigned source-owner castle, zero neutral/density town placements, three direct scans, 445 matching generated-cell candidates, 85 footprint-eligible anchors, 39 private occupied body cells, two unique selections plus one `0x4e7276` tie selection, projected castle anchors `(26,16)`, `(23,23)`, and `(18,5)`, synchronized player starts for owner slots `[1,2,3]`, default project town ids `town_riverwatch`, `town_duskfen`, and `town_prismhearth`, and no public runtime-grid/package adoption.
- TerrainPlacement scratch/writeback contract on 2026-05-13 after the hard restart: the active strict h3maped reset now ports bounded `0x4bad0f` scratch-word packing and `0x49acf6` generated-cell bit projection samples under the TerrainPlacement visual-table boundary. The focused report asserts scratch contract bit `0` dirty, bits `1..4` terrain id, bits `5..11` art row, bits `12..13` flags; generated-cell `+0x24` terrain/art and `+0x28` terrain flags; sample scratch/generated words for grass row `60` (`1925`, `3842`, `0`), grass row `77` with flag A (`6565`, `4930`, `32768`), water row `20` (`657`, tile terrain `8`, art `20`), and rock row `11` (`371`, tile terrain `9`, art `11`); no generated-cell grid materialization or package tiles.
- TerrainPlacement visual table/toolkit boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now decodes the h3maped static terrain visual row tables and records toolkit/vtable anchors as inspection-only evidence. The focused report asserts `0x4bcff5`, `0x4bb5ce`, `0x4bd099`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x5436b8`, `0x543780`, `0x54379c`, `0x4ba938`, `0x4ba989`, `0x4baa94`, and `0x4baabf`; ten toolkit constructor records; five decoded visual tables at `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88` totaling 230 rows; selector samples for grass row `60`, normal transition row `77`, water transition row `20`, and rock row `11`; no hash art fallback, visual-record materialization, full art grid, package tiles, or public grid adoption.
- Terrain/cell writeout boundary `0x4a3f27` on 2026-05-13 after the hard restart: the active strict h3maped reset now consumes the real `0x4a325d` zone-word buffer and materializes private generated-cell terrain words plus `0x49b2b6` byte-zero terrain candidates as inspection-only evidence. The focused report asserts 1296 cells, 1107 non-water terrain cells, 189 unassigned water cells, 1107 reserved-flag cells, terrain counts water `189`, grass `177`, dirt `91`, lava `403`, swamp `207`, rough `229`, repaint terrain-code counts `2:177`, `0:91`, `7:403`, `4:207`, `5:229`, zero byte-one art cells, zero byte-six terrain flip cells, and no terrain art, roads, objects, public grid adoption, package tiles, or public package output.
- Interleaved `0x49b3c1`/`0x49b53d` runtime selector boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now consumes four town-choice RNG calls during coordinate replay and then runs runtime terrain selection before terrain writeout. The focused report asserts town choices elemental/necropolis/inferno/fortress for the four town-capable runtime zones, terrain ids `[2,0,7,7,4,5]` / project terrain ids `[grass,dirt,lava,lava,swamp,rough]`, two terrain RNG calls, `0x49b53d` final RNG state `2166683160`, and no terrain-cell, terrain-art, map-cell, or package materialization.
- Small-land `0x4a3710` finalizer boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports the current no-appended-zone finalizer path as private inspection-only evidence. The focused report asserts call site `0x4a3efc..0x4a3f05`, locator `0x4cca55`, clip helper `0x4a2b33`, ordering reset `0x49b61b`, per-zone order helper `0x4a3554`, adjacency vector offset `runtime_zone+0xc4`, ordering vector offset `runtime_zone+0x3e8`, one-level land with synthetic branch disabled, original/final runtime-zone counts 6/6, zero appended runtime zones, skipped adjacency insertion phases, six ordering resets, six per-zone ordering rebuilds, zero materialized adjacency, and no zone-cell, boundary, span-fill, terrain, map-cell, or package materialization.
- Real `0x4a325d` span-fill boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now consumes the current private `0x4a2777` boundary buffer as private span-fill evidence only. The focused report asserts boundary source `0x4a2777`, seed source `runtime_zone+0x10`, six fill attempts, six filled zones, one blocked initial seed, zero relocations, 869 filled interior cells, 1107 boundary-or-filled private cells, 189 remaining unassigned cells, 1107 reserved-flag cells, 93 pushed/popped spans, max pending span count 3, zero out-of-bounds spans, per-zone distribution `177/91/226/177/207/229`, and no terrain, map-cell, runtime-player, package-tile, public-grid, or public package materialization.
- Real `0x4a2777` source-node traversal boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now consumes the current `0x4ccb64`/`0x4ccdfc` recovered source-node cycles through `0x4a2777` as private boundary-buffer evidence only. The focused report asserts six consumed runtime-zone walks, zero fallback zones, six connector segments, zero wrap segments, 12 final segments, 18 appended vertices, 12 skipped out-of-bounds clips, six flagged `0x4a2413` writer segments, 12 deterministic `0x4a261a` writer segments, 106 randomized RNG calls, 138 inserted midpoint candidates, final RNG state `264218432`, 301 private trace writes, 238 unique private boundary cells, zero out-of-bounds writes, no loop guard exhaustion, and no terrain, map-cell, runtime-player, or package materialization.
- Polygon split/finalizer boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4ccb64` source-node split insertion/cleanup and `0x4ccdfc` finalization as private inspection-only graph evidence over the current `0x4a19ed` scaled runtime-zone points. The focused report asserts six split calls, zero edge-removal branches, 12 bridge pairs, 34 crossing cleanup scans, 24 crossing tests, 8 crossing collapses, 23 active node pairs after cleanup, 14 finalized triplets, 42 finalized nodes, six recovered source-node walks, no guard exhaustion, and no public terrain, map-cell, runtime-player, or package materialization.
- Randomized line-writer boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a2413` as an inspection-only flagged `0x4a2777` dependency. The focused report asserts RNG address `0x4e7276`, distance helper `0x4cc5ad`, bounded one-level land sample `(2,2)->(33,31)`, random span limit `6`, 51 RNG calls, 63 inserted midpoint candidates, 64 terminal writes, 63 unique zone-word cells, 64 reserved-flag writes, zero out-of-bounds writes, final RNG state `3821795434`, and no generated boundary/cell adoption.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a2413` randomized line-writer boundary.
- Deterministic line-writer boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a261a` as an inspection-only `0x4a2777` dependency. The focused report asserts zone-word mask `0x00ff0000`, clear mask `0xff00ffff`, reserved flag `0x10`, sample line `(2,3)->(8,3)`, seven writes, seven unique zone-word cells, seven reserved-flag writes, zero out-of-bounds writes, trace endpoints, and no generated boundary/cell adoption.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a261a` deterministic line-writer boundary.
- Clip helper boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a2b33` as an inspection-only `0x4a2777` dependency. The focused report asserts 36x36 clip bounds, representative inside/left/top/right/bottom endpoint clipping, branch evidence, and no boundary traversal, span fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, and `git diff --check` after adding the `0x4a2b33` clip helper boundary.
- Zone-footprint phase boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a3a03` per-level scheduling and `0x4cc788` initial source-node rectangle as inspection-only evidence. The focused report asserts one land level, collected runtime-zone indices `[0,1,2,3,4,5]`, six queued `0x4a2777` helper inputs, no synthetic `0xd4` source-zone append, initial source-node bounds `-200..400`, constants `0xffffff38` and `0x190`, four `0x4cc955` rectangle edges, and no boundary traversal, span fill, terrain, map-cell, runtime-player, or package materialization.
- Coordinate replay boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports one-level `0x49b3c1/0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed` coordinate candidate replay as inspection-only evidence. The focused report asserts seed `1` placement step count `18`, town-choice RNG calls `4`, coordinate RNG calls `18`, total replay RNG events `22`, final replay RNG state `255755822`, bbox span `84`, scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, `(12,11)`, and no map-cell, guard, road, blocker, or package materialization.
- Link seed boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a1f3b` source-zone link endpoint seeds as inspection-only evidence. The focused report asserts five recovered template-18 links (`1-4`, `2-5`, `4-5`, `3-5`, `6-4`), runtime endpoint indices `[0-3]`, `[1-4]`, `[3-4]`, `[2-4]`, `[5-3]`, guard values `3000/3000/3000/6000/6000`, `Value/Wide/Border Guard` preservation for later `0x4a79a3`, and no coordinate, guard, road, blocker, or package materialization.
- Runtime-zone setup boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4a218c` as inspection-only evidence loaded from recovered `rmg-template-catalog.json`. The focused report asserts vector offsets `generator+0x10e0/+0x10e4/+0x10e8`, `0x414`-byte runtime records, h3maped template `018` zone count `6`, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum source base size `11`, and no coordinates, terrain, map cells, runtime players, or packages materialized.
- Player-slot assignment boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now ports `0x4ac62a..0x4ac6ec` as inspection-only evidence. The focused report asserts source-owner masks from recovered template evidence, `generator+0xed8` selected-color ordering, `generator+0xee0/+0xee4` assignment/mapped slots, seed `1` selected template `h3maped_template_018` masks `0x0f/0x0f`, default actual colors `[0,1,2,-1,-1,-1,-1,-1]`, three assignment records, no runtime player materialization, and all later phases pending strict executable ports.
- Hard restart boundary on 2026-05-13: the previous active `src/gdextension/src/h3maped_small_rmg.cpp` h3maped boundary was archived out of the build to `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp`, and the compiled active module was reduced to the strict small-map restart boundary only. The focused report now asserts schema `aurelion_native_rmg_small_h3maped_restart_boundary_v1`, verified `/root/Downloads/h3maped.exe` SHA/MZ/size, small-land h3maped RNG template selection (`h3maped_template_018` for seed `1`), a nine-phase strict executable-port backlog with only template selection active, and no runtime or partial package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after archiving the active h3maped boundary and reducing the compiled module to the strict restart boundary.
- `0x4cc788` source-node rectangle boundary on 2026-05-13: the active clean h3maped reset now ports the initial polygon source-node rectangle as inspection-only evidence before real `0x4a2777` traversal. The focused report asserts function `0x4cc788`, node constructor `0x4cc955`, split/finalization follow-ups `0x4ccb64` / `0x4ccdfc`, constants `0xffffff38` (-200) and `0x190` (400), four initial edges, and no boundary, span-fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4cc788` source-node rectangle boundary.
- `0x4a2413` randomized line writer boundary on 2026-05-13: the active clean h3maped reset now ports the one-level land flagged `0x4a2777` writer dependency as inspection-only evidence. The focused report asserts h3maped RNG-jittered midpoint subdivision from `(2,2)` to `(33,31)`, 51 RNG calls, 63 inserted midpoint candidates, 64 terminal writes, 63 unique zone-word cells, 64 reserved-flag writes, zero out-of-bounds writes, final RNG state `3821795434`, and no boundary, span-fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a2413` randomized line writer boundary.
- `0x4a261a` deterministic line writer boundary on 2026-05-13: the active clean h3maped reset now ports the second direct `0x4a2777` helper dependency as inspection-only evidence. The focused report asserts representative line painting from `(2,3)` to `(8,3)`, seven zone-word writes, seven unique cells, seven reserved-flag writes, zero out-of-bounds writes, and no boundary, span-fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a261a` deterministic line writer boundary.
- `0x4a2b33` clip helper boundary on 2026-05-13: the active clean h3maped reset now ports the first direct `0x4a2777` helper dependency as inspection-only evidence. The focused report asserts `0x4a2b33` clipping against the 36x36 map rectangle for inside, left, top, right, and bottom representative endpoints, with no boundary, span-fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a2b33` clip helper boundary.
- `0x4a2777` helper input queue on 2026-05-13: the active clean h3maped reset now records the first helper-call inputs from the `0x4a3a03` per-level phase. The focused report asserts six queued `0x4a2777` inputs for runtime-zone indices `[0,1,2,3,4,5]` / source-zone ids `[1,2,3,4,5,6]`, with `0x4a325d` and `0x4a3710` materialization still pending and no boundary/cell output.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a2777` helper input queue.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a3a03` zone-footprint phase boundary.
- Zone-footprint phase boundary on 2026-05-13: the active clean h3maped reset now ports the `0x4a3a03` per-level phase boundary as inspection-only evidence. The focused report asserts one level, six collected runtime-zone indices `[0,1,2,3,4,5]`, no synthetic `0xd4` source-zone append for small one-level land, helper sequence `0x4a2777 -> 0x4a325d -> 0x4a3710`, and no boundary, span-fill, terrain, map-cell, runtime-player, or package materialization.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4a218c` runtime-zone setup inspection boundary.
- Runtime-zone setup boundary on 2026-05-13: the active clean h3maped reset now ports `0x4a218c` runtime-zone record setup as inspection-only evidence loaded from the recovered `rmg-template-catalog.json`. The focused report asserts vector offsets `generator+0x10e0/+0x10e4/+0x10e8`, `0x414`-byte runtime records, selected template `h3maped_template_018` zone count `6`, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, four minimum player castles, minimum source base size `11`, and no coordinates, terrain, map cells, runtime players, or packages materialized.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after adding the `0x4ac62a..0x4ac6ec` player-slot assignment inspection boundary.
- Player-slot assignment boundary on 2026-05-13: the active clean h3maped reset now ports `0x4ac62a..0x4ac6ec` as inspection-only evidence. The focused report asserts source-owner masks from recovered template evidence, `generator+0xed8` selected-color ordering, `generator+0xee0/+0xee4` assignment/mapped slots, seed `1` selected template `h3maped_template_018` masks `0x0f/0x0f`, default actual colors `[0,1,2,-1,-1,-1,-1,-1]`, three assignment records, and no runtime player materialization. Runtime generation remains blocked.
- Validated on 2026-05-13 with cmake native rebuild, focused native h3maped boundary report, `jq empty ops/progress.json`, `git diff --check`, and `python3 tests/validate_repo.py` after archiving the active inspection ledger and replacing it with the clean small h3maped restart boundary.
- Clean restart archive boundary on 2026-05-13: the previous active `src/gdextension/src/h3maped_small_rmg.cpp` inspection ledger was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp`, and the active module was replaced with a small strict boundary. The focused report now asserts schema `aurelion_native_rmg_small_h3maped_clean_restart_v3`, verified `/root/Downloads/h3maped.exe` SHA/MZ/size, small-land h3maped RNG template selection (`h3maped_template_018` for seed `1`), a nine-phase executable-port backlog, runtime generation blocked with `h3maped_small_clean_restart_generation_not_ready`, and out-of-scope fallback blocked with `archived_legacy_native_rmg_disabled`.
- Historical note: the older compact h3maped inspection bullets below are retained as archived evidence. They are not the active production generator path after the clean restart archive boundary above.
- Late connection helper schedule on 2026-05-13: the active compact h3maped port now records the recovered `0x4a79a3` late-link helper attempt order alongside the `0x4a6cf2` overlap precondition. The focused report asserts first-pass helpers `0x4a61bc -> 0x4a696b -> 0x4a6cf2`, second-pass fallback helpers `0x4a696b -> 0x4a7605`, overlap-ready link indices `[0,3,4]`, fallback-required link indices `[1,2]`, and per-link helper precondition statuses without runtime geometry or guard adoption.
- Late connection overlap geometry precondition on 2026-05-13: the active compact h3maped port now runs an inspection-only `0x4a6cf2` overlap-rectangle precondition report against the real `0x4a325d` generated zone-word grid. The focused report asserts five links, three overlap-rectangle candidates, two no-overlap cases requiring later/fallback helpers, 472 total reserved cells inside available overlaps, per-link overlap counts `174`, `132`, and `166`, and that `Wide` is read after overlap/candidate geometry. It does not materialize connection geometry or guards; remaining blockers are generator shape-list `+0x6a8`, full `0x49aa93` two-sided validation, endpoint object stamping, guard placement, roads/rivers, blockers, mines, rewards, and final h3maped writeout.
- TerrainPlacement final-sweep boundary counter on 2026-05-13 after the hard restart: the active strict h3maped reset now records the `0x4bc5f0` / `0x4bbd01` / `0x4bc988` / `0x4bbfcc` queue/final-sweep contract and applies the recovered `0x4bbfcc` boundary counter over the private `0x4a3f27` generated terrain grid. The focused report asserts the set A/B offsets, drain order, E/S/SE/SW adjacency scan, correction classes `2->6`, `8->12`, `5->7`, `11->13`, a bounded 3x3 boundary sample, a zero-boundary full/native normalization sample, a 1296-cell generated-grid counter, nonzero boundary and zero-boundary cell coverage, histogram consistency, and no visual-record, full terrain-art grid, package-tile, or public package adoption.
- TerrainPlacement live repaint queue-drain boundary on 2026-05-13 after the hard restart: the active strict h3maped reset now projects private `0x4bcfc3` / `0x4bce6d` / `0x4bad0f` / `0x49acf6` visual writes during the executable-derived `0x4a4025` full-water repaint, per-zone `0x4bb74b` repaint sequence, and recovered `0x4bc5f0` set A/B queue drain. The focused report asserts decoded h3maped visual tables, exact private queue drain active, 2845 visual attempts/writes, 1296 dirty final scratch cells, 1296 initial-water attempts, 942 direct zone repaint attempts, 607 queue repaint attempts, 176 set-A drains, 10522 set-B drains, 386 set-B candidate-gate hits, 221 private retouch terrain writes, no drain guard exhaustion, zero missing visual buckets, zero scratch roundtrip mismatches, 181 post-queue terrain differences versus the pre-drain `0x4a3f27` terrain grid, nonzero private art and flag coverage, neighbor-mask and selector histograms, and no runtime-grid or package-tile adoption. The remaining TerrainPlacement blocker is safe generated-cell art/flag tile-byte/package adoption after later road/object phases are executable-derived.
- Late connection payload postprocess on 2026-05-13: the active compact h3maped port now records inspection-only `0x4a79a3` late link payload handling after the early `0x4a1f3b` endpoint pass. The focused report asserts five unique links, ten reciprocal link records, ten processed-marker writes at `+0x0a`, payload offsets `Value/Wide/Border Guard` at `+0x04/+0x08/+0x09`, global monster strength mode `3`, raw guard values `[3000,3000,3000,6000,6000]`, recovered `0x4a65a5` scaled guard values `[2000,2000,2000,5000,5000]`, zero Wide suppressions, zero Border Guard special links, and no connection geometry or guard materialization. Remaining output blockers are executable-derived connection geometry/guard object placement, roads/rivers, blockers, mines, rewards, and final h3maped writeout.
- Project town/start adoption candidate on 2026-05-13: the active compact h3maped port now bridges the h3maped `0x49ba89` town records into inspection-only project town/player-start candidate schemas. The focused report asserts three project town records, three player starts, owner slots `[1,2,3]`, synchronized start/town anchors at the h3maped-selected castle positions, default project town ids `town_riverwatch`, `town_duskfen`, and `town_prismhearth`, and no public package or runtime-grid adoption. Remaining package output blockers are roads/rivers, blockers, guards, mines, rewards, and final h3maped writeout phases before these candidates can become runtime output.
- Direct town object stamping projection on 2026-05-13: the active compact h3maped port now threads the real `0x4a325d` zone-word buffer into the town/castle phase and projects the `0x4a93a2` / `0x49ba89` direct town object stamping ledger through the recovered `objects.txt` town footprint mask and `0x49aa93` / `0x49a09c` footprint gate. The focused report asserts three direct scans, 451 matching generated-cell zone/source-byte candidates, 97 footprint-valid candidates, zero missing footprint candidates, 39 private body cells marked, two unique selections plus one `0x4e7276` tie selection, selected player-owned castle anchors at `(28,14)`, `(24,23)`, and `(18,5)`, `0x28`-byte `0x540a9c` record fields, and no package adoption or generated-cell state stamping. Remaining package output blockers are safe town package adoption, road/rivers, objects, guards, rewards, and final h3maped writeout phases.
- Town/castle phase schedule on 2026-05-13: the active compact h3maped port now records inspection-only `0x4a8d2c` / `0x4a8db2` town/castle phase evidence, including source-zone fields `+0x20..+0x40`, helper addresses `0x4a93a2` and `0x4a901a`, town chooser `0x49b3c1`, and object constructor `0x49ba89`. The focused report asserts four source minimum player castles, three active assigned player-owned minimum castles for the 3-player small boundary case, one skipped unassigned source-owner castle slot, zero neutral/density town placements, and no town-object/package adoption. Remaining package output blockers are town object stamping, road/rivers, objects, guards, rewards, and final h3maped writeout phases.
- Live tile-byte candidate on 2026-05-13: the active compact h3maped port now maps live `0x4bb74b` / `0x4bc5f0` scratch-feedback `0x49acf6` generated-cell words through the recovered `0x49b2b6` terrain tile-byte layout. The focused report asserts 1296 terrain/art/flag byte candidates, zero terrain mismatches, nonzero terrain art byte `1`, nonzero terrain flag byte `6`, nonzero art/flag deltas against the older drained-grid candidate, and no runtime-grid/package adoption. Remaining package output blockers are road/rivers, objects, towns, guards, rewards, and final h3maped writeout phases.
- Live scratch visual-feedback projection on 2026-05-13: the active compact h3maped port now projects private `0x4bad0f` scratch words and `0x49acf6` generated-cell art/flag words during the copied `0x4a4025` / `0x4bb74b` / `0x4bc5f0` repaint and queue sequence. The focused report asserts decoded visual tables, 2705 live visual writes, all 1296 final scratch cells dirty, zero missing visual buckets, zero scratch round-trip mismatches, zero final terrain mismatches, nonzero live art/flag coverage, nonzero delta against the post-drain masked selector, and no runtime-grid/package adoption. The remaining terrain-art blocker is safe `0x49b2b6` tile-byte/package adoption after road/object phases are executable-derived.
- Masked visual-selection projection on 2026-05-12: the active compact h3maped port now feeds the recovered `0x4bce6d` scratch-neighbor mask into an inspection-only `0x4bcfc3` / `0x4ba938` selector replay over the drained 1296-cell terrain grid. The focused report asserts a complete 1296-cell projection with zero missing buckets, nonzero full/native masked cells, nonzero terrain art/flag candidates, nonzero art-selection delta versus the previous terrain-only selector, generated-cell word arrays, and no live feedback/runtime/package adoption. The remaining TerrainPlacement blocker is moving this mask-aware selector into the live `0x4bb74b` / `0x4bc5f0` scratch update sequence before tile-byte adoption.
- Scratch-neighbor mask projection on 2026-05-12: the active compact h3maped port now projects the recovered `0x4bce6d` scratch-neighbor mask over the full drained scratch grid. The focused report asserts the RMG `0x4bcff5` / `0x4bb5ce` constructor initial mask `4`, west/north/east/south shift order, 1296 mask entries, nonzero full/native cells, nonzero cells with masks below the initial value, mask histogram coverage, and no visual-selection/runtime/package adoption. The remaining TerrainPlacement blocker is feeding this live mask through `0x4bcfc3` / `0x4ba938` during the queue drain instead of selecting art from the post-drain terrain grid.
- Drained-grid scratch-word projection on 2026-05-12: the active compact h3maped port now projects every copied `0x4bc5f0` drained-grid terrain/art/flag word into recovered `0x4bad0f` scratch format and round-trips those 1296 scratch words back to `0x49acf6` generated-cell fields. The focused report asserts dirty scratch coverage for all 1296 cells, zero scratch round-trip mismatches, zero terrain mismatches, nonzero art/flag coverage, and no runtime-grid/package adoption; the remaining TerrainPlacement blocker is live scratch-mask visual selection and safe generated-cell adoption during the queue drain.
- Queue container contract on 2026-05-12: the active compact h3maped port now records the one-level `0x4bc5f0` queue container contract from `0x4bd1c1` ordered insert, `0x4bd374` remove, `0x4bd3c5` lower-bound lookup, and `0x4bd408` pair copy. The focused report asserts ascending `y` then `x` ordering, duplicate insert returning inserted false, one-level ordering emulated by `h3maped_grid_key`, sample order `(0,0)`, `(1,0)`, `(0,1)`, `(2,1)`, and no runtime queue materialization; runtime adoption is still blocked on live `0x4bad0f` scratch-neighbor feedback sequencing and safe generated-cell/package adoption.
- Drained terrain tile-byte writeback candidate on 2026-05-12: the active compact h3maped port now maps the copied per-repaint `0x4bc5f0` drained-grid `0x49acf6` generated-cell words through the recovered `0x49b2b6` serializer bit layout into private tile-byte candidates. The focused report asserts 1296 terrain/art/flag byte candidates, zero terrain mismatches against the drained grid, nonzero terrain art and flag cells, zeroed river/road bytes pending their executable phases, and no runtime-grid or package adoption.
- Drained-grid TerrainPlacement visual projection on 2026-05-12: the active compact h3maped port now feeds the copied per-repaint `0x4bc5f0` drained terrain grid through the recovered `0x4bbfcc` final-sweep boundary counter and `0x4bb075` / `0x4ba938` / `0x4ba989` / `0x4bad0f` / `0x49acf6` visual selector/writeback projection. The focused report asserts 1296 projected cells, zero missing visual buckets, nonzero terrain art and flag candidates, generated-cell word arrays, and no runtime tile-byte or package adoption.
- TerrainPlacement repaint-order queue drain projection on 2026-05-12: the active compact h3maped port now runs an inspection-only `0x4bc5f0` set-A/set-B drain projection over a copied `0x4a3f27` terrain grid per actual repaint call. The report routes set B through `0x4bc988 -> 0x4bb74b`, routes set A through `0x4bbd01`, wires retouch writes back into `0x4bb74b` topology seeding, records the one-level queue container contract, and reaches zero missing visual buckets without guard exhaustion. Runtime adoption remains blocked because the projection still lacks live `0x4bb74b` / `0x4bcfc3` / `0x4bce6d` scratch-neighbor feedback sequencing, generated-cell art/flag copyback, and package-tile materialization.
- TerrainPlacement repaint-order queue seed projection on 2026-05-12: the active compact h3maped port now replays the real `0x4a3f27` water-then-zone repaint order, records changed-cell `0x4bb74b` neighbor branches and `0x4bba59` set-B candidate seeding, and proves the current 20 generated-grid missing visual-bucket cells are all present in the repaint-order set-B frontier before `0x4bc5f0` drain. The focused report asserts 1111 changed-cell terrain updates, 20/20 missing-bucket set-B coverage, 20/20 `0x4bc988` candidate-gate hits, nonempty set A/B candidate counts, and no queue drain, runtime-grid adoption, or package-tile materialization.
- TerrainPlacement missing-bucket retouch projection on 2026-05-12: the active compact h3maped port now applies the recovered `0x4bbd01` vertical/horizontal retouch decisions and same-class zero-run branch to a copied generated terrain grid for the 20 missing visual-row bucket cells. The focused report asserts initial missing count `20`, post-retouch missing count `0`, copied-grid write count, retouch samples, ported addresses `0x4bbd01`/`0x4bc988`/`0x4bb74b`, and no runtime-grid or package-tile adoption. Full runtime adoption remains blocked until the real `0x4bc5f0` set A/B queue is seeded by actual repaint order rather than the missing-bucket list.
- TerrainPlacement missing-bucket frontier gates on 2026-05-12: the active compact h3maped port now reports bounded `0x4bc74c` same-terrain masks, exact `0x4bc928` same-class region gate behavior, `0x4bc674`/`0x4bc6e0` pair gates, and `0x4bc988` candidate gate outcomes over the 20 generated-grid cells that still lack decoded visual-row buckets. The focused report asserts ported address coverage, gate histograms, branch histograms, per-sample masks in `N,NE,E,SE,S,SW,W,NW` order, and no queue-retouch or package-tile materialization.
- Generated-grid TerrainPlacement projection on 2026-05-12: the active compact h3maped port now runs the recovered `0x4bb039` relation classifier, `0x4bb075` shape classifier, decoded `0x4ba938`/`0x4ba989`/`0x4baabf` row selectors, `0x4bad0f` scratch packing, and `0x49acf6` generated-cell bit projection across the actual 36x36 generated terrain-code buffer for inspection. The focused report asserts 1,276 projected cells, 20 queue-normalization-required cells with missing decoded row buckets, missing bucket histograms, projected art/flag arrays, and no runtime tile-byte adoption or package materialization.
- Generated-grid final-sweep boundary counter on 2026-05-12: the active compact h3maped port now applies the recovered `0x4bbfcc` E/S/SE/SW boundary-counter scan to the actual 36x36 generated terrain-code buffer. The focused report asserts the generated-grid counter status, tile dimensions, boundary count array size, nonzero and zero-boundary cell coverage, maximum boundary count bounds, adjacency/increment consistency, and that visual records, full terrain art grid, and package tiles remain unmaterialized.
- TerrainPlacement queue/final-sweep boundary on 2026-05-12: the active compact h3maped port now reports the required `0x4bc5f0` queue drain, `0x4bbd01` frontier processor, `0x4bc988` candidate gate, and `0x4bbfcc` whole-map final sweep contract. The focused report asserts set A/B offsets, drain order, final sweep adjacency directions `E/S/SE/SW`, correction classes `2->6`, `8->12`, `5->7`, `11->13`, a 3x3 boundary-counter sample, and the zero-boundary full/native normalization branch. Terrain art/flag adoption remains blocked until this is applied across the generated grid.
- TerrainPlacement scratch/writeback samples on 2026-05-12: the active compact h3maped port now reports bounded `0x4bad0f` scratch-word packing and `0x49acf6` generated-cell bit projection for the selected row samples. The focused report asserts scratch words and projected terrain/art/flag bytes for grass full row `60`, grass transition row `77`, water row `20`, and rock row `11`; generated-grid art/flag adoption remains blocked until full queue normalization is ported.
- TerrainPlacement visual row selector samples on 2026-05-12: the active compact h3maped port now executes bounded row-selection samples for `0x4ba938`, `0x4ba989`, and `0x4baabf` against visual tables decoded from `/root/Downloads/h3maped.exe`. The focused report asserts grass full/native seed `1` selects row `60` from special bucket `57..72`, normal transition class `28` selects row `77`, water class `16` selects row `20`, and rock class `8` flags `(1,0)` selects row `11` while clearing output flags. Full generated-grid visual selection and writeback remain blocked.
- TerrainPlacement classifier boundary on 2026-05-12: the active compact h3maped port now reports the `0x4bb039` terrain relation function, `0x5436e0` orientation table, and representative `0x4bb075` class decisions through the focused boundary report. The report asserts relation-matrix anchors for dirt, grass, and water plus representative class decisions for full/native class `0`, relation-2 corner class `8`, transposed block class `18`, and compound junction class `28`. Visual-record materialization remains blocked.
- TerrainPlacement static visual table decode on 2026-05-12: the active compact h3maped port now decodes the five terrain visual row tables directly from `/root/Downloads/h3maped.exe` into the focused boundary report. The report asserts row counts for `0x543108`, `0x543380`, `0x5434f0`, `0x5435b0`, and `0x542f88`, plus class/range anchors for normal full/native rows `49..72`, normal classes `27`/`28` at rows `78`/`77`, dirt class `24`, water class `16`, and rock class `8` flag buckets. This advances the exact TerrainPlacement path while keeping visual-record materialization and public package adoption blocked.
- Adapted catalog bridge verification on 2026-05-12: the focused boundary report now asserts that the h3maped-selected source template `h3maped_template_018` resolves through `import_provenance.source_template_index` one-based `19` / internal zero-based catalog index `18` to adapted template `translated_rmg_template_019_v1` and profile `translated_rmg_profile_019_v1`. This verifies the project template/profile bridge for the selected small reset boundary without enabling runtime map generation.
- Public RMG capability policy hardening on 2026-05-12: `MapPackageService.get_api_metadata()` now records `native_rmg_generation_authority: h3maped_small_reset_only`, `native_rmg_runtime_generation_allowed: false`, active reset slice `native-rmg-small-h3maped-port-10184`, and legacy capability policy `inspection_debug_evidence_not_runtime_generation_authority`. The focused boundary report asserts these fields so retained old report capabilities cannot be mistaken for production generation authority.
- h3maped binary anchor hardening on 2026-05-12: the clean reset inspection now checks the actual `/root/Downloads/h3maped.exe` SHA-256 through `FileAccess::get_sha256()` in addition to file size and MZ header. The focused boundary report asserts `sha256_matches: true`, actual SHA `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`, and verification policy `local_file_size_mz_header_and_sha256_checked_against_reset_anchor`.
- Small-map readiness classification correction on 2026-05-12: supported 36x36 one-level land configs now report reset-specific status through public identity/runtime policy helpers: `generation_status: h3maped_small_clean_restart_generation_not_ready`, `full_generation_status: h3maped_small_clean_restart_waiting_for_executable_phase_ports`, `template_family: h3maped_small_reset_template`, and `translated_catalog_structural_profile_supported: false`. This prevents old translated-catalog readiness metadata from describing the blocked h3maped reset path.
- Small-map public identity correction on 2026-05-12: supported 36x36 one-level land configs now route `random_map_config_identity()` through the recovered h3maped template selector instead of the archived catalog-auto hash selector. Seed `1` / 1 human / 3 total players reports `template_selection_mode: h3maped_exe_rng`, source template `h3maped_template_018`, source catalog index `18`, adapted template `translated_rmg_template_019_v1`, and explicit translated-template requests are marked overridden by the h3maped reset gate. Runtime generation remains blocked with `h3maped_small_clean_restart_generation_not_ready`.
- TerrainPlacement repaint schedule on 2026-05-12: the compact h3maped port now records the actual `0x4a3f27` repaint order for the current one-level small map: full-map terrain `8` repaint from `0x4a4025`, then runtime-zone scan from `0x4a4082`, with `1x1` per-cell repaints at `0x4a415a` gated by owner byte `0x4a4142` and reserved/top-nibble bit `0x4a4150`. Seed `1` reports 1296 initial water cells, 1111 single-cell zone repaints, and repaint terrain counts dirt `492`, grass `165`, snow `222`, and rough `232`; final terrain art bytes remain pending.
- TerrainPlacement static lookup contract on 2026-05-12: the compact h3maped port now executes a bounded `0x4ba868` / `0x4ba938` static range lookup sample for terrain id `2` toolkit object `0x5a3988` from static table `0x543108`. The sample materializes key `0` range `49..56`, key `1` range `57..72`, neighbor mask `8`, RNG seed `1`, probability RNG value `41`, threshold `50`, art RNG value `18467`, and selected art index `60`. Full repaint-order integration across the generated terrain grid remains pending.
- TerrainPlacement toolkit constructors on 2026-05-12: the compact h3maped port now records all ten constructor records in `0x5436b8` terrain-table order. Terrain ids `0..8` use `0x4ba868` over globals `0x5a4130`, `0x5a3d58`, `0x5a3988`, `0x5a3b70`, `0x5a3f40`, `0x5a46b8`, `0x5a4c70`, `0x5a4a88`, and `0x5a48a0` with static tables `0x543380`, `0x5434f0`, `0x543108`, and `0x5435b0`; terrain id `9` uses simple zero constructor `0x4baa66` over `0x5a4128`. The next runtime step remains executing the static table range lookup and feeding selected visual records into `0x4bad0f`/`0x49acf6`.
- TerrainPlacement toolkit vfuncs on 2026-05-12: the compact h3maped port now records the concrete methods behind the visual selector: complex toolkit vtable `0x543780` maps `+0x08` to `0x4ba91d`, `+0x0c` to `0x4ba92b`, `+0x10` to `0x4ba938`, and `+0x14` to `0x4ba989`; simple toolkit vtable `0x54379c` maps `+0x08` to `0x4baa81`, `+0x0c` to `0x4baa86`, `+0x10` to `0x4baa94`, and `+0x14` to `0x4baabf`. This corrects the lookup target for the next porting step; visual records still are not materialized.
- TerrainPlacement visual selector on 2026-05-12: the compact h3maped port now records `0x4bcfc3` as the visual selector, `0x4bce6d` as the neighbor-mask reducer, terrain toolkit table `0x5436b8`, toolkit globals `0x5a4130` through `0x5a4128`, constructors `0x4ba868`/`0x4ba9c8`/`0x4baa66`, and static visual tables including `0x543108`, `0x543380`, `0x5434f0`, and `0x5435b0`. This still does not materialize visual records; the next blocker is porting the toolkit static-table lookup bodies and feeding their selected records into `0x4bad0f` and `0x49acf6`.
- Terrain adapter writeback on 2026-05-12: the compact h3maped port now records the `type_random_map` writeback bridge: vtable `0x540a14`, constructor `0x499f60`, virtual write entry `0x49acc5`, cell write helper `0x49acf6`, and readers `0x49ad83`/`0x49adde`/`0x49ae01`. The recovered bit mapping writes terrain id to generated-cell `+0x24` bits `0..5`, terrain art to `+0x24` bits `6..13`, and terrain flags to `+0x28` bits `15..16`; the clean port still does not materialize those art/flag fields before exact visual-record classifier recovery.
- TerrainPlacement copyback gate on 2026-05-12: the compact h3maped port now records `0x4bc988` retouch/copyback gate evidence, including vertical/horizontal neighbor gates, terrain class table `0x5436b8`, same-class region gate `0x4bc928`, ordered insert helper `0x4bd1c1`, container insert `0x4bd374`, and container lookup `0x4bd3c5`. Generated-cell `+0x24/+0x28` art/flag copyback remains pending.
- TerrainPlacement changed-cell boundary on 2026-05-12: the compact h3maped port now records `0x4bb74b` changed-cell update evidence: visual record resolution through `0x4bcfc3` and table `0x5436b8`, scratch write through `0x4bad0f`, neighbor checks through `0x4bba13`/`0x4bba36`, neighbor touches through `0x4bba59`, and fallback neighbor table `0x5a5028..0x5a5068`. The scratch word bit contract is recorded, but tile byte `1` art and byte `6` terrain flags remain blocked until generated-cell `+0x24/+0x28` copyback is recovered.
- TerrainPlacement repaint boundary on 2026-05-12: the compact h3maped port now records constructor `0x4bb5ce`, wrapper `0x4bd099`, rectangle loop `0x4bb681`, cell ensure `0x4bb71b`, changed-cell update `0x4bb74b`, and same-terrain neighbor touch `0x4bad0f` as recovered boundary evidence. The report still does not materialize art indices or terrain flip bits before the deeper update/classifier helpers are ported.
- Tile serializer contract on 2026-05-12: the compact h3maped port now exposes the direct `0x49b2b6` generated-cell serializer bit contract for inspection. The report carries generated-cell `+0x24/+0x28` backing words, maps tile bytes `0..6` to their executable bit ranges, and verifies a bounded seven-byte sample `[7, 171, 12, 93, 9, 110, 91]` covering terrain id/art, river type/art, road type/art, and flip flags. It still does not emit public package tiles.
- TerrainPlacement art/flip guard on 2026-05-12: the compact h3maped port now explicitly reports `blocked_until_exact_h3maped_TerrainPlacement_classifier_recovered` and rejects reuse of the legacy `positive_visual_hash` / `TerrainPlacementRules.gd` visual approximation. Required executable anchors are recorded as `0x4bcff5`, `0x4bd099`, `0x4bb681`, `0x49b2b6`, and terrain toolkit class/vtable evidence before terrain art byte `1` or terrain flip byte `6` bits `0..1` can be populated.
- Terrain byte-zero/grid inspection on 2026-05-12: the compact h3maped port now packs `0x49b2b6` terrain byte `0` from the inspected `0x4a3f27` generated-cell terrain ids and exposes an inspection-only terrain-grid record. Seed `1` reports 1296 terrain bytes, 1111 non-water terrain cells, byte `1` art cells still zero, and byte `6` terrain flip cells still zero. Runtime generation remains blocked before TerrainPlacement art/index/flip normalization and later public package adoption.
- Terrain/cell writeout on 2026-05-12: the compact h3maped port now derives inspection-only `0x4a3f27` terrain/cell counts from the real `0x4a325d` zone-word buffer. Seed `1` reports 1296 cells, 1111 reserved terrain cells, 185 unassigned water/void cells, terrain counts dirt 492, grass 165, snow 222, rough 232, and water 185, while runtime generation remains blocked before TerrainPlacement art/index/flip byte selection and project-grid/package adoption.
- Real span-fill handoff on 2026-05-12: the compact h3maped port now feeds the materialized real `0x4a2777` boundary buffer into the ported `0x4a325d` span-fill primitive for inspection. Seed `1` reports six fill attempts, six filled zones, one in-bounds runtime-zone seed that starts on a non-unassigned boundary cell but still fills through the executable-confirmed left-scan span behavior, 890 filled interior cells, 1111 total boundary-or-filled cells, and 185 remaining unassigned cells. The recovered `0x4a32b2..0x4a338e` relocation branch is ported as an out-of-bounds-seed branch and is not needed for the current in-bounds seed case. Runtime generation remains blocked before terrain/cell writeout and object adoption.
- Reset entry-point cleanup on 2026-05-12, corrected again on 2026-05-14: `MapPackageService.generate_random_map()` no longer carries the unreachable previous catalog-auto map assembly body after the reset return. Supported small land configs currently return `h3maped_small_clean_restart_generation_not_ready`; out-of-scope configs return `archived_legacy_native_rmg_disabled`.
- Reset correction on 2026-05-12: the previous oversized small h3maped inspection implementation was moved out of the active compile path to `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`. That file is historical evidence only. Active production-facing reset work is limited to `src/gdextension/src/h3maped_small_rmg.cpp`.
- The active compact port verifies `/root/Downloads/h3maped.exe`, performs h3maped-derived small-template acceptance/RNG selection, and resolves seed `1` to `h3maped_template_018` -> `translated_rmg_template_019_v1`. It must not emit a supported small land runtime package until the remaining executable-derived phases are strict ports.
- The active compact port includes player-slot assignment `0x4ac62a..0x4ac6ec`: source capability bitmaps, `generator+0xed8`, `generator+0xee0`, and `generator+0xee4`. It remains inspection-only and does not materialize runtime players.
- The active compact port includes runtime-zone record setup `0x4a218c`: six runtime records for seed `1`, owner colors `[0, 1, -1, 2, -1, -1]`, three assigned start zones, one unassigned start zone, two treasure zones, and four minimum player castles. It does not materialize coordinates, terrain, or cells.
- The active compact port includes early endpoint-placement scheduling `0x4a1f3b`: five link seeds, six creation calls, two stabilization passes, 18 total calls, 25 endpoint attempts, and three possible fallback candidates. It explicitly preserves `Value`, `Wide`, and `Border Guard` for later `0x4a79a3` and does not materialize guards.
- The active compact port includes coordinate candidate replay `0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed`: seed `1` reports 18 placement steps, four town-choice RNG calls, 18 coordinate RNG calls, 22 total replay RNG events, and bbox span `84` rescaled onto the 36-tile map. This remains inspection-only and does not materialize terrain, cells, or footprints.
- The active compact port includes runtime terrain selection `0x49b53d`: match-to-town zones use table `0x540908`, treasure zones choose from source terrain flags through `0x4e7276`, and seed `1` selects project terrains `[grass, dirt, lava, lava, swamp, rough]` with two terrain RNG calls. This remains inspection-only and does not materialize cells or terrain art.
- The active compact port includes top-level `0x4a3a03` footprint scheduling, `0x4cc788` initial source-node rectangle setup, all six scheduled `0x4cca55` locators, duplicate-endpoint guards, `0x4ccb64` pre-crossing insertion/bridge-loop passes, `0x4ccc7a`/`0x4cc68e` crossing-cleanup passes, `0x4ccdfc` finalized-coordinate fanout materialization, six finalized source-node cycle walks, real `0x4a2777` boundary traversal from those cycles, standalone `0x4a2b33` clip, `0x4a261a` deterministic line-writer, and `0x4a2413` randomized line-writer primitives, standalone `0x4a2777` rectangle fallback, deterministic connector segment, and boundary-wrapping continuation branches, the standalone `0x4a325d` span-fill primitive, and the small-land `0x4a3710` finalizer boundary: seed `1` has one land level, initial polygon bounds `-200..400`, six matching runtime zones, six materialized locator/insertion/cleanup passes, 12 bridge-pair insertions, 34 crossing-cleanup scans, 24 crossing tests, 8 crossing collapses, 23 active node pairs after cleanup, 14 finalized coordinate triplets, 42 finalized nodes, six source-node walks without guard exhaustion, six consumed boundary walks, 301 boundary trace writes, 238 unique boundary cells, 869 filled interior cells, 1107 boundary-or-filled cells, 189 remaining unassigned cells, no synthetic fallback zone, no appended runtime zones, six ordering reset/rebuild calls scheduled, zero adjacency inserts, and a bounded disassembly-derived span-fill contract sample. This remains inspection-only and does not materialize zone cells.
- Normal 36x36 one-level land generation returns `h3maped_small_clean_restart_generation_not_ready`, including explicit translated-template configs that are routed back through the h3maped selector. Medium/large/XL and other out-of-scope generation returns `archived_legacy_native_rmg_disabled`. Uploaded/generated `.h3m`, `.amap`, and `.ascenario` evidence remains untracked.
- Pending beyond the small runtime slice: broaden h3maped-derived generation to water, underground, medium/large/XL, and deeper owner-corpus parity without reintroducing catalog-auto fallback or exact-count fitting.


Completed owner-requested editor inspection hotfix:

id: `map-editor-generated-package-inspection-index-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Fix the built-in map editor package picker so generated `.amap`/`.ascenario` pairs that load cleanly remain available for inspection even when the stricter skirmish-launch gate rejects them.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
completionCriteria:
- Skirmish/package browser still hides generated packages rejected by launch validation.
- Map editor package selection includes loadable generated package pairs rejected by launch validation as inspection-only entries.
- Map editor can load those inspection-only generated package pairs into a mutable working copy.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
validationResults:
- `tests/maps_folder_package_browser_integration_report.tscn` passed with launch-rejected compact package hidden from skirmish but listed and loadable through the map-editor inspection index.
- `tests/map_editor_load_map_package_report.tscn` passed with the Load Map picker including generated package ids and package-backed editor working-copy loading.

Paused owner-directed RMG corrective checkpoint:

id: `native-rmg-owner-small-islands-underground-corpus-road-checkpoint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `paused`
purpose: Promote the uploaded Small islands two-level owner sample into the hard owner-corpus native comparison path and checkpoint the first road-topology correction for manual review before finishing object/category, town, and guard parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-RandomNumberofplayers-islands-2level.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_randomnumberofplayers_islands_2level` is mapped to the player-facing native catalog-auto Small islands underground comparison path.
- Native Small islands two-level road cell count and per-level component topology match owner evidence: surface `[45, 37, 15, 11, 10]`, underground `[29]`.
- Remaining package object/category, town, and guard gaps are explicitly visible in the owner-corpus gate until corrected by the next implementation pass.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No completion claim for the Small islands two-level owner sample yet.
- No broad Small islands, underground, or full HoMM3 production parity claim.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` ran and remains failing as expected for this checkpoint: mapped comparisons are `8/9`, the Small islands two-level sample has matching road cells/topology (`147`, surface `[45, 37, 15, 11, 10]`, underground `[29]`) but still reports object delta `+4`, town delta `-1`, guard delta `+4`, and category delta total `118`.
- Paused on 2026-05-07 because continued sample-by-sample count fitting is the wrong production path; use this sample as corpus evidence for generalized policy work instead.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-small-normal-water-underground-corpus-shape-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Small normal-water two-level owner sample into the hard owner-corpus native comparison gate and correct the package object/category, town, guard, road-topology, and town-spacing gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-2playerss-normalwater-2level.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_2playerss_normalwater_2level` is mapped to the player-facing native catalog-auto Small normal-water underground comparison path.
- The owner-corpus hard mapped comparison increases from seven to eight passing mapped samples, with unmapped parsed samples reduced to 13.
- Native Small normal-water two-level package counts match owner evidence for package objects, towns, guards, road cells, and owner object categories.
- Native Small normal-water two-level road component sizes match owner topology by level: surface `[84]`, underground `[17]`.
- Native town spacing satisfies the owner-derived semantic floor while preserving guarded route closure.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Small normal-water/islands parity claim beyond this uploaded sample.
- No full HoMM3 production parity claim; 13 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with eight mapped comparisons passing; the Small normal-water two-level mapped comparison reports zero deltas for object, town, guard, and road counts, owner category counts `decoration 196`, `guard 62`, `object 64`, `reward 100`, `town 5`, road component sizes by level `0: [84]`, `1: [17]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 representative cases.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving the broad production-parity gap.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-small-random-land-corpus-shape-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Small random-player single-level land owner sample into the hard owner-corpus native comparison gate and correct the package object/category, guard, and road topology gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-RandomNumberofplayers.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_randomnumberofplayers` is mapped to the player-facing native catalog-auto Small land comparison path.
- The owner-corpus hard mapped comparison increases from six to seven passing mapped samples, with unmapped parsed samples reduced to 14.
- Native Small random-player land package counts match owner evidence for package objects, towns, guards, road cells, and owner object categories.
- Native Small random-player land road component sizes match owner topology for the uploaded sample: `[63, 28]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Small water/islands/two-level parity claim.
- No full HoMM3 production parity claim; 14 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with seven mapped comparisons passing; the Small random-player land mapped comparison reports zero deltas for object, town, guard, and road counts, owner category counts `decoration 146`, `guard 45`, `object 51`, `reward 49`, `town 6`, road component sizes `[63, 28]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 representative cases.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, mapped owner-corpus gate `7/7`, `full_homm3_style_parity false`, and `broad_owner_h3m_comparison_corpus false`.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-corpus-road-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded XL no-water single-level owner sample into the hard owner-corpus native comparison gate and correct the package road count/topology gap exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_xl_nowater` is mapped to the player-facing native catalog-auto XL land comparison path.
- The owner-corpus hard mapped comparison increases from five to six passing mapped samples, with unmapped parsed samples reduced to 15.
- Native XL land package counts match owner evidence for package objects, towns, guards, and road cells.
- Native XL land road component sizes match owner topology for the uploaded sample: `[485, 188, 54]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad XL water/islands or two-level parity claim.
- No full HoMM3 production parity claim; 15 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with six mapped comparisons passing; the XL no-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[485, 188, 54]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `xl_land_seed_a` reports 5,365 package objects, 4,734 generated objects, 12 towns, 619 guards, 727 road cells, and nearest town distance 41.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, `mapped_owner_sample_exact_parity true`, `full_homm3_style_parity false`, and `broad_owner_h3m_comparison_corpus false`.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-corpus-road-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Large no-water single-level owner sample into the hard owner-corpus native comparison gate and correct the package road count/topology gap exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_l_nowater_randomplayers_nounder` is mapped to the player-facing native catalog-auto Large land comparison path.
- The owner-corpus hard mapped comparison increases from four to five passing mapped samples, with unmapped parsed samples reduced to 16.
- Native Large land package counts match owner evidence for package objects, towns, guards, and road cells.
- Native Large land road component sizes match owner topology for the uploaded sample: `[192, 118, 47, 9]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Large water/islands or two-level parity claim.
- No full HoMM3 production parity claim; 16 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with five mapped comparisons passing; the Large no-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[192, 118, 47, 9]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `large_land_seed_a` reports 2,917 package objects, 2,645 generated objects, 8 towns, 264 guards, 366 road cells, and nearest town distance 34.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving representative coverage/full-parity gaps.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-corpus-structural-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Medium normal-water owner sample into the hard owner-corpus native comparison gate and correct the remaining structural road, town-spacing, and guard-count gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_m_normalw_4players` is mapped to the player-facing native catalog-auto Medium normal-water comparison path.
- The owner-corpus hard mapped comparison increases from three to four passing mapped samples, with unmapped parsed samples reduced to 17.
- Native Medium normal-water package counts match owner evidence for package objects, towns, guards, and road cells.
- Native Medium normal-water road component sizes match owner topology for the uploaded sample: `[71, 55, 50, 45]`.
- Native Medium normal-water nearest town spacing meets or exceeds the owner sample spacing while preserving the owner-count target.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad normal-water parity claim across the remaining uploaded samples.
- No full HoMM3 production parity claim; 17 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after the structural fix; `medium_normal_water_seed_a` reports 754 package objects, 667 generated objects, 7 towns, 80 guards, 221 road cells, 2,163 water tiles, and nearest town distance 25.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with four mapped comparisons passing; the Medium normal-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[71, 55, 50, 45]`, and `semantic_layout_match`.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving the broad parity gap while proving representative defaults still pass.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-road-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded Medium normal-water owner sample package road count after the object/town/guard count correction.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Medium normal-water package road overlays serialize 221 road cells, matching the uploaded owner H3M evidence instead of the previous 254-cell native output.
- The correction is scoped to the owner-compared Medium normal-water translated profile and does not claim broad normal-water road parity.
- Object, generated-object, town, guard, and water gates remain passing for `medium_normal_water_seed_a`.
- The auto-template batch hard-gates the corrected Medium normal-water package road target.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No full route-graph topology rewrite; the underlying generated route graph still reports 16 route edges and this slice adjusts serialized package road overlays only.
- No broad normal-water parity claim across Small/Large/XL samples.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after adding the Medium normal-water road-count gate.
- `medium_normal_water_seed_a` now reports 221 package road cells, matching owner `M-NormalW-4players.h3m`; it still reports 754 package objects, 667 generated object placements, 7 towns, and 80 guards.
- The same case reports 2,144 package water tiles against the owner 2,083 target, still inside the existing 96-tile tolerance.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Medium normal-water owner sample to an owner-compared native target and correct native object, town, and guard counts toward that H3M evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Medium normal-water `translated_rmg_template_039_v1` / `translated_rmg_profile_039_v1` is treated as an owner-compared translated profile for native generation policy.
- Native Medium normal-water object, town, and guard counts match the uploaded owner H3M evidence: 754 package objects, 667 generated object placements, 7 towns, and 80 guards.
- Surplus generic reward references are trimmed after required mine/resource/dwelling priority so owner reward-category density can match without suppressing required sites.
- The auto-template batch hard-gates the corrected Medium normal-water count targets while preserving the existing water-count tolerance gate.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No Medium normal-water road topology/count parity in this slice; package roads remain 254 versus owner 221 and are the next explicit corrective gap.
- No broad normal-water parity claim across Small/Large/XL samples.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after adding owner Medium normal-water count gates.
- `medium_normal_water_seed_a` now reports 754 package objects, 667 generated object placements, 7 towns, and 80 guards, matching owner `M-NormalW-4players.h3m` counts.
- The same case reports 2,144 package water tiles against the owner 2,083 target, still inside the existing 96-tile tolerance, and 254 package road cells versus owner 221 remains an explicit non-goal gap.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-decoration-land-pressure-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the Medium normal-water terrain shape regression where decorative/scenic objects placed before terrain forced too much land versus the uploaded owner HoMM3 sample.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Normal-water terrain shaping no longer lets decorative and scenic object bodies force protected land before the water/land shape is chosen.
- Medium normal-water land fractions are retuned after that protected-surface reduction so generated water stays close to the owner sample rather than overshooting.
- The auto-template batch hard-gates the Medium normal-water package water count against the uploaded owner sample evidence.
- Native generation, package conversion, road/object/town/guard validation, and repository validation still pass.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No claim of full normal-water parity across every owner sample.
- No broad water-aware object-placement pipeline reorder in this slice.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after the correction.
- `medium_normal_water_seed_a` now reports 2,097 package water tiles against the owner `M-NormalW-4players.h3m` 2,083 water tiles, compared with 1,610 before this slice.
- The same case reports `protected_land_cell_count 2,213`, `requested_land_count 3,087`, `generated_land_cell_count 3,087`, and `generated_water_cell_count 2,097`, proving decorative/scenic protected land was the previous water cap.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with 21 parsed owner samples, 7 land, 7 normal-water, 7 islands, and the existing 18 unmapped parsed-sample comparison gap still explicit.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-protected-land-diagnostic-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Expose why Medium normal-water still underproduces water versus the uploaded HoMM3 owner sample after first-class normal-water support.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native normal-water terrain shaping records compact requested/protected/generated land-water shape metrics in focused validation output.
- The focused Medium normal-water validation compares native water/object/road/town/guard counts against the owner sample enough to identify the next tuning blocker.
- Normal-water land quota tuning and non-visit decorative approach relaxation are attempted, with evidence preserved if they are not the limiting factor.
- No production parity overclaim is made while water/object density still differs from owner H3M.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No full object-placement-before-water refactor in this slice.
- No exact normal-water owner-H3M parity claim.
- No broad normal-water template sweep.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `medium_normal_water_seed_a` still validates and converts with 1,610 package water tiles, 499 package objects, 254 road cells, 8 towns, and 111 guards.
- The focused shape summary reports `requested_land_count 3574`, `protected_land_cell_count 3574`, `generated_land_cell_count 3574`, and `generated_water_cell_count 1610`, proving protected land surfaces, not the normal-water quota target, are currently capping water generation below the owner sample's 2,083 water tiles.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-mode-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop collapsing HoMM3 normal-water requests to land and add first-class native normal-water generation/package support as a prerequisite for owner-H3M normal-water comparison tuning.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Player-facing random-map setup exposes `normal_water` separately from `land` and `islands`.
- GDScript and native config normalization preserve `normal_water` instead of coercing it to `land`.
- Native catalog support accepts `normal_water` for water-capable translated templates without treating it as islands score halving.
- Native terrain generation materializes mixed surface water for normal-water maps while preserving land around roads, towns, objects, guards, and starts.
- Focused native auto-template validation covers a Medium normal-water package and proves it has nonzero water tiles.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact normal-water owner-H3M parity claim yet.
- No tuning to match `M-NormalW-4players.h3m` object, road, town, guard, and terrain ratios in this slice.
- No broad all-template water-mode parity claim.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 cases; `medium_normal_water_seed_a` preserved `normal_water`, selected `translated_rmg_template_039_v1` / `translated_rmg_profile_039_v1`, validated, converted to a package, and reported 1,582 package water tiles.
- `python3 tests/validate_repo.py` passed.
- `tests/random_map_player_setup_retry_ux_report.tscn` was attempted and still fails on an existing generated-session launch handoff nil path in `ScenarioSelectRules.gd`, outside the normal-water mode selection path.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-terrain-water-mode-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add parsed H3M terrain water/rock ratios and terrain-inferred water-mode evidence to the owner corpus so uploaded samples can be audited by actual map contents, not only filename labels.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus samples expose compact water-mode resolution plus terrain water/rock counts and ratios parsed from H3M tile data.
- Samples with no explicit filename water mode can resolve from terrain inference without changing explicit owner labels.
- Production-audit parsed sample coverage surfaces compact terrain ratios without embedding the full terrain-count payload.
- The audit does not overclaim production readiness; missing corpus/template/tail-parse gaps remain explicit.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No native generator tuning for water/islands profiles in this slice.
- No exact H3M byte/object-art parity claim.
- No synthetic Medium land owner evidence.
validationResults:
- Owner-corpus report passed with schema `native_random_map_homm3_owner_corpus_coverage_report_v5`, `ok true`, 21 readable/parsed samples, and `corpus_ready false`.
- `owner_discovered_s_randomnumberofplayers` now resolves from unknown filename label to terrain-inferred land with surface water ratio 0.0.
- `owner_discovered_m_normalw_4players` remains normal-water with surface water ratio 0.402, confirming it is not the missing Medium land/no-water owner sample.
- `owner_discovered_xl_water_2levels` remains explicitly labeled normal-water but now records a terrain conflict because the parsed surface water ratio is 0.560 and terrain inference classifies it as islands.
- Corpus gaps remain `template_breadth_corpus` and `object_instance_tail_count_mismatch_samples`; production readiness remains unclaimed.
- Production parity audit passed with `ok true`, `production_ready false`, `missing_requirement_count 4`, and compact terrain coverage records.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-density-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the parsed Large no-water owner diagnostic to correct native Large land default object density, town count/spacing, reward category count, and guard count toward owner-H3M scale.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Large land default has a Large diagnostic against the parsed owner no-water surface sample.
- Native Large land default matches the parsed owner sample on package object count, decoration, scenic/object, reward, town, and guard categories, allowing only explicitly validated residuals such as one road-cell delta.
- Large town count uses parsed owner evidence instead of stale catalog minima, and semantic layout remains passing with no native unguarded/object-only town route leaks.
- Production audit still refuses `production_ready` until Medium land owner evidence, broad corpus/template parity, parser tail debt, full parity, and underground readiness are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact Large H3M byte/object-art parity claim while the owner sample still carries a 16-object tail-count parser warning.
- No Medium land synthetic owner evidence.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Owner-corpus Large land diagnostic passed with native package object count 2,917/2,917, decoration 1,840/1,840, scenic/object 376/376, reward 429/429, town 8/8, guard 264/264, and road cells 365 versus owner 366.
- Large semantic layout comparison passes: native nearest-town Manhattan 34 versus owner 35, native object-route reachable town pairs 0 versus owner 28, and native guarded-route reachable town pairs 0/0.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`; remaining missing requirements are representative owner coverage for Medium land, full HoMM3-style parity, broad owner-H3M comparison corpus, and underground production parity.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-tail-parse-coverage-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the uploaded Large no-water surface owner H3M usable as representative coverage while preserving an explicit parser-debt warning for its near-EOF object-instance count mismatch.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The Large no-water surface uploaded H3M no longer disappears from parsed representative owner-sample coverage solely because the strict parser reaches EOF with a small declared object-count tail mismatch.
- The parser reports declared count, parsed count, missing tail count, parse quality, and warning metadata for that sample.
- Corpus readiness remains false while the tail-count mismatch and template-breadth corpus gaps remain unresolved.
- Production audit representative owner sample coverage now has Small land, Small underground, Medium islands, Large land, and XL land evidence, while Medium land remains explicitly missing.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact Large H3M byte/object-art parity claim.
- No native Large land tuning or mapped native comparison for the Large sample.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Owner-corpus report passed with 21 readable samples and 21 parsed metric records; `owner_discovered_l_nowater_randomplayers_nounder` reports `tail_count_mismatch`, 2,917 parsed objects out of 2,933 declared, and 16 missing tail instances.
- Owner-corpus readiness remains false with `missing_coverage` containing `template_breadth_corpus` and `object_instance_tail_count_mismatch_samples`.
- Production parity audit passed with `production_ready false`, `missing_requirement_count 4`, Large land representative coverage matched to `owner_discovered_l_nowater_randomplayers_nounder`, and Medium land still the only missing representative owner sample.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-reward-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to correct native Extra Large land reward-category overproduction after the town-layout pass left native rewards at 952 versus owner 692.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default caps reward-category placement at the parsed owner XL count without suppressing mine/resource/dwelling priority placement.
- The XL land diagnostic reward category moves from native 952 versus owner 692 to exact owner count or an explicit validated residual if infeasible.
- Decoration, scenic/object, guard, town count, town spacing, road, and route-closure evidence from previous XL corrections remains passing.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact reward-value distribution parity claim beyond count/category shape.
- No broad all-template reward tuning.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with exact owner-category counts: package object count 5,365/5,365, decoration 3,413/3,413, scenic/object 629/629, reward 692/692, town 12/12, and guard 619/619.
- Native reward by-kind breakdown is mine 168, neutral_dwelling 57, resource_site 133, and reward_reference 334 after trimming only surplus generic reward references.
- Semantic layout and route closure remain passing: nearest-town Manhattan 41 versus owner 39, native object-route reachable town pairs 0, and native guarded-route reachable town pairs 0.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-town-layout-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to correct native Extra Large land town count and town-spacing semantics after the density pass exposed native towns at 14 versus owner 12 and nearest-town Manhattan 23 versus owner 39.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default applies the owner XL town-count target without dropping player starts.
- The XL land diagnostic no longer reports `native_xl_semantic_layout_gap` solely because native towns are closer than the owner spacing floor.
- Object, decoration, scenic, guard, road, and route-closure evidence from the density correction remains passing.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M byte/object-art parity claim.
- No broad all-template town-layout parity claim.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with native town count 12/12, nearest-town Manhattan 38 versus owner 39, semantic_layout_match, and no actionable gaps.
- Density/passability evidence from the previous slice remains intact: decoration 3,413/3,413, scenic/object 629/629, guards 619/619, native object-route reachable town pairs 0, and native guarded-route reachable town pairs 0.
- Remaining XL category delta is reward count only: native reward 952 versus owner 692; this stays explicit parity debt.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-density-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to raise native Extra Large land default decoration, scenic-object, and guard density toward owner-H3M scale instead of leaving the generator at roughly one-third owner object density.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default adds deterministic owner-informed density targets for decoration, scenic-object, and guards.
- The XL land diagnostic object-density ratio improves materially from the baseline 0.349 and no longer reports decoration/scenic category as effectively absent.
- Representative package route closure and road integrity remain passing after denser blockers/objects are added.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M parity claim from a potentially different HoMM3 template/player-count sample.
- No broad Large/no-water parser repair.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with package_object_count 5,627 versus owner 5,365, object density ratio 1.049, decoration 3,413/3,413, scenic/object 629/629, guard 619/619, and road cells 764 versus 727.
- Route closure remains intact in the diagnostic: native object-route reachable town pairs 0 and native guarded-route reachable town pairs 0.
- Remaining explicit diagnostic gap is semantic town layout spacing: native nearest town Manhattan 23 versus owner 39, with native town count 14 versus owner 12 and reward count 952 versus owner 692.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-density-gap-diagnostic-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the newly parsed owner XL no-water H3M evidence directly comparable to the native XL land player-facing default as a diagnostic density gap, without converting that mismatched template evidence into a false exact-parity gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus output includes an XL land diagnostic comparing `owner_discovered_xl_nowater` to the native Extra Large land default.
- The diagnostic reports native/owner object, guard, town, road, and owner-category count deltas plus density ratios and actionable gap labels.
- The mapped exact-comparison gate remains scoped to supported mapped samples and does not fail on the diagnostic-only XL evidence.
- Production audit consumes and exposes the XL diagnostic while still refusing `production_ready`.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M parity claim from a potentially different HoMM3 template/player-count sample.
- No HoMM3 copyrighted asset/DEF import.
- No Large no-water variable-payload parser repair in this slice.
completionEvidence:
- Owner-corpus schema v3 now includes `xl_land_density_diagnostic` for `owner_discovered_xl_nowater` against native `translated_rmg_template_043_v1` / `translated_rmg_profile_043_v1`.
- The diagnostic reports native XL land at 1,873 package objects versus 5,365 owner objects, a 0.349 object density ratio, and 416 native guards versus 619 owner guards, a 0.672 guard density ratio.
- Category density gaps are explicit: native decoration is 491 versus 3,413 owner decorations, native object/scenic category is 0 versus 629 owner objects, and native rewards are 952 versus 692 owner rewards.
- Roads are not the primary XL land deficit in this sample: native package road cells are 764 versus 727 owner road cells, a 1.051 road-cell ratio.
- Semantic comparison flags native town spacing below the owner floor: native nearest-town Manhattan minimum is 20 versus owner 39, while object-only and guarded route closure remain zero native leaks for this diagnostic.
- Production parity audit schema v7 consumes the diagnostic, keeps it out of the mapped exact-parity gate, and still reports `production_ready: false`.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-h3m-variation-corpus-discovery-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Ingest the newly uploaded local H3M variation directory into the owner-corpus audit as evidence-only comparison input so Large/XL, water, island, and underground coverage gaps become measurable instead of hidden by the previous three-sample corpus.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local evidence under `maps/h3m-maps/*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus discovery includes `maps/h3m-maps` without committing uploaded `.h3m` evidence.
- Filename-derived size/water hints correctly classify S/M/L/XL, no-water/land, normal-water, islands, and two-level samples.
- The corpus report summarizes parsed variation coverage and exposes unmapped or mismatched native comparisons as explicit next-work evidence.
- Production audit consumes the expanded owner-corpus coverage without claiming `production_ready`.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/art parity claim.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Owner-corpus discovery now includes `res://maps/h3m-maps` as local evidence-only input and does not stage or commit uploaded `.h3m` files.
- Filename hints classify `S/M/L/XL`, `nowater` as land, `normalwater`/`normalw` as normal-water, and `islands` as islands; the only remaining unknown parsed sample is the ambiguous `S-RandomNumberofplayers.h3m`.
- Expanded local corpus audit passed with 21 readable samples, 18 parsed metric samples, size coverage across Small/Medium/Large/XL, level coverage across 1 and 2 levels, and water coverage across land/normal-water/islands.
- The mapped exact comparison gate remains limited to the three already-mapped owner samples and reports 15 newly parsed samples as unmapped next-work evidence.
- Production parity audit consumes the expanded corpus and still reports `production_ready: false`; remaining blockers include full template-breadth corpus/parser completion, unmapped variation comparisons, and representative Medium/Large/XL land owner sample gaps.

Active owner-directed RMG corrective slice:

id: `native-rmg-owner-h3m-xl-nowater-parser-cap-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove the owner-corpus parser's too-low placed-object cap so uploaded XL no-water samples with more than 5,000 objects become usable local evidence for XL land comparison coverage.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local evidence under `maps/h3m-maps/XL-nowater*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- XL no-water single-level and two-level uploaded H3M samples metric-parse instead of failing `invalid_object_instance_count`.
- Production audit representative owner sample coverage no longer reports Extra Large land default as missing when the single-level XL no-water sample is present locally.
- The remaining Large single-level no-water parser gap is still explicit rather than hidden.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/art parity claim.
- No Large no-water variable-payload parser repair in this slice.
completionEvidence:
- Owner-corpus parser now accepts uploaded H3Ms with up to 12,000 placed objects instead of rejecting valid XL no-water samples above 5,000.
- Expanded corpus report passed with 20 parsed metric samples out of 21 readable samples; `owner_discovered_xl_nowater` parses at 5,365 objects, 12 towns, 619 guards, and 727 road cells.
- `owner_discovered_xl_nowater_2levels` parses at 5,239 objects, 10 towns, 405 guards, and 879 road cells.
- Production audit now matches `extra_large_land_default` to `owner_discovered_xl_nowater` for representative owner-sample coverage while still reporting `production_ready: false`.
- Remaining representative owner-sample coverage gaps are Medium land and Large land; the Large single-level no-water H3M still exposes a separate `next_object_instance_not_found` variable-payload parser gap.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-owner-sample-coverage-matrix-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Expose owner-H3M sample coverage per representative default so translated-profile support cannot be mistaken for owner-proven production parity when matching H3M evidence is absent.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records parsed owner sample coverage with size class, water mode, underground/surface level shape, object/town/guard counts, and road-cell totals.
- The audit adds a representative owner-H3M sample coverage checklist item.
- Representative cases without a matching owner sample are visible as explicit missing coverage rather than hidden behind generic corpus readiness.
- The broad owner corpus objective checklist consumes this coverage item and remains unsatisfied when representative evidence is incomplete.
nonGoals:
- No synthetic owner-H3M samples or guessed coverage.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit schema v6 adds `parsed_sample_coverage` and `representative_owner_h3m_sample_coverage`.
- Parsed owner sample coverage currently includes Small land single-level, Small land underground, and Medium Islands single-level samples.
- The audit still passes as a no-overclaim audit while `production_ready: false` remains, with missing representative owner evidence for unsupported size/water/level combinations and the broader Large/XL/template-breadth corpus blocker.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-objective-artifact-checklist-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add an explicit prompt-to-artifact completion checklist to the production audit so the owner objective maps to concrete repo evidence and remaining blockers before any production-ready claim.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit restates the native GDExtension RMG production objective as concrete checklist requirements.
- Each requirement maps to repo artifacts and real evidence from the audit completion checklist or owner corpus summary.
- The checklist distinguishes satisfied local evidence from broad parity blockers instead of treating passing reports as full completion.
- The audit still refuses production readiness while broad owner-H3M corpus, broad underground readiness, or full HoMM3-style parity remain missing.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No synthetic owner-corpus evidence or broad production-ready claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit schema v5 adds `objective_artifact_checklist` with entries for native GDExtension activation, player-facing defaults, towns/zones/routes, roads, obstacles/guards/rewards/object density, translated template breadth, broad owner-H3M corpus, broad underground readiness, and full production-ready claim.
- Checklist entries cite concrete repo artifacts and consume real completion-checklist/owner-corpus evidence.
- The audit passes while preserving `production_ready: false`; broad owner-H3M corpus coverage still reports missing Large/XL H3M samples and template-breadth corpus evidence.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-package-road-integrity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Gate representative player-facing defaults on player-visible package road integrity, clarifying the distinction between diagnostic generated road segment totals and unique serialized package road tiles.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records package-road integrity for every representative player-facing default.
- The gate fails empty road packages, zero-tile road records, duplicate serialized road tiles, or package metadata that does not match unique serialized road tiles.
- Raw generated `road_network.road_cell_count` remains visible as diagnostic data and is not confused with player-loaded package roads.
- The audit still reports production not ready while broad owner corpus and broad underground readiness remain unproven.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from representative road integrity evidence.
completionEvidence:
- Production audit adds `package_road_integrity` to each representative case and a satisfied `representative_package_road_integrity` checklist item.
- All representative defaults serialize non-empty package roads with zero duplicate road tiles, zero zero-tile road records, and package component metadata matching unique serialized road tiles.
- The audit explicitly records generated road segment totals as diagnostic because they can include pre-dedup/materialization segment counts, while package road integrity is gated on the actual loaded map surface.
- Production audit still reports `production_ready: false` with broad owner-H3M corpus coverage, broad underground production readiness, and full HoMM3-style parity remaining open.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-mapped-owner-parity-evidence-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make exact mapped owner-H3M parity evidence first-class in the production audit, separating passing local owner comparisons from the remaining broad corpus blocker.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit reports concise mapped-owner sample parity summaries for each compared local H3M sample.
- The audit has a hard satisfied checklist item for exact currently mapped owner-sample parity.
- The checklist requires zero object/town/guard/road deltas, category-count match, per-level road-component match, semantic layout match, and zero native object-only/guarded route leaks.
- Broad owner corpus readiness still fails when Large/XL or template-breadth H3M evidence is absent.
nonGoals:
- No synthesized or guessed owner-H3M corpus coverage.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit now includes `mapped_sample_parity` in the owner corpus summary for Small single-level, Small underground, and Medium Islands owner samples.
- The new `mapped_owner_sample_exact_parity` checklist item passes only when the mapped comparison gate passes and each summarized sample has zero object/town/guard/road deltas, matching owner categories, matching per-level road topology, semantic layout match, and zero native route leaks.
- Local evidence inventory confirmed only three owner map samples are available: two Small land variants and one Medium Islands sample; no Large/XL `.h3m` or broader template corpus exists in `maps/`, inbound media, or recovered artifacts.
- Production audit still reports `production_ready: false` because broad owner-H3M corpus coverage and broad underground production readiness remain unproven.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-representative-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote level-aware package route-closure evidence into the production parity audit for every representative player-facing default, so the audit directly fails start-town, cross-zone, or all-town leaks instead of relying on a separate topology report by implication.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit reports package-level route-closure metrics for each representative default.
- The representative route gate covers object-only and unresolved blockers for start-town, cross-zone, and all-town pairs.
- The gate is level-aware through the shared package topology helper and covers the representative Small underground case on two levels.
- The audit still reports production not ready while broad owner corpus, full parity, and broad underground readiness remain unproven.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from representative route-closure evidence.
completionEvidence:
- Production parity audit schema v4 adds `package_route_closure` per representative case and a satisfied `representative_package_route_closure` checklist item.
- The representative defaults pass package route closure with zero object-only and unresolved reachable pairs for start-town, cross-zone, and all-town checks: Small land, Small underground, Medium land, Medium Islands, Large land, and Extra Large land.
- The Small underground representative records 2 levels, 8 towns, 28 all-town pairs checked, and zero reachable object-only or unresolved pairs.
- The audit still reports `production_ready: false` with `full_homm3_style_parity`, `broad_owner_h3m_comparison_corpus`, and `underground_production_parity` as explicit missing requirements.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-package-topology-level-aware-route-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close a verifier gap where package object-only route-closure checks only searched level 0, so two-level/underground package leaks could be missed despite serialized level data.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_package_surface_topology_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Package topology helper builds town visit points with their actual package/map level.
- Object-only player-start, cross-zone, and all-town path searches stay within the same level and use level-aware blocked-tile keys.
- Broad translated land/underground catalog sweep passes under the stricter level-aware route-closure helper.
- The result does not claim exact HoMM3 byte/object-art parity or full underground production readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from structural route-closure evidence alone.
completionEvidence:
- `tests/native_random_map_package_surface_topology_report.gd` now computes package topology paths with `Vector3i(level, x, y)` visit/start/goal points and level-aware blocked keys.
- The focused package surface topology report passed after the stricter helper change.
- The broad translated catalog underground route-closure sweep passed for 47 eligible land/underground translated templates with zero object-only player-start, cross-zone, or all-town package route leaks.
- The strengthened evidence confirms current translated packages keep guarded/blocked route closure on actual package levels; production parity audit still keeps full HoMM3 parity, broad owner corpus, and broad underground production readiness as blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-small-underground-representative-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the mapped owner Small underground native-auto path into the production parity audit as explicit representative evidence without overclaiming broad underground production readiness.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local uploaded owner Small underground H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production parity audit includes a representative native-auto Small underground case.
- The representative underground case selects `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1`, validates, materializes two levels, and passes active catalog town/castle minima.
- Audit adds a satisfied representative underground checklist item while keeping broad underground production exposure blocked until owner-H3M corpus breadth expands.
- Production audit still reports `production_ready: false` and keeps full parity, broad owner corpus, and broad underground production parity as missing requirements.
nonGoals:
- No broad underground production-ready claim.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity audit now includes `small_underground_default`, which selects `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1`, validates with `owner_compared_translated_profile_not_full_parity`, materializes 2 levels, and passes active catalog town minima with 8 towns against 8 required.
- The representative Small underground output reports 12 zones, 60 guards, 436 package objects, and 157 package road cells.
- A new satisfied `representative_owner_compared_underground_support` checklist item records the representative case and owner corpus underground-sample presence.
- The audit still reports `production_ready: false`; broad owner-H3M corpus breadth, broad underground production exposure, and full HoMM3-style parity remain explicit blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-template-town-minima-materialization-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add a hard production-audit gate for active recovered catalog player castle and neutral town minima, disambiguating active player-filtered zones from inactive source zones so real under-materialization fails without false-counting disabled template branches.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records catalog-derived minimum town/castle expectations for representative defaults.
- Player-facing Large/XL defaults materialize at least the active player castle minima plus neutral town/castle minima from their translated catalog zones.
- The fix does not reintroduce close-town stacking below the current launchable town-spacing floor or route leaks in mapped owner samples.
- Production audit still does not claim full HoMM3 parity or broad owner-corpus readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad corpus/product-ready claim from this single town-minima correction.
completionEvidence:
- Production parity audit schema v3 now records `catalog_town_minima` for representative player-facing defaults, including active-zone count, player-count, active player town/castle minima, neutral town/castle minima, generated town count, and pass/fail status.
- The active filtered defaults pass the minima gate: Small `049` generates 7 towns against 7 required; Medium land `002` generates 6 against 4 required; Medium Islands `001` generates 8 against 4 required; Large `042` generates 16 against 16 required; XL `043` generates 14 against 14 required.
- The XL default was audited as active-filtered 5 player towns plus 9 neutral towns, not the larger inactive source-zone total; this prevents false-positive town-count corrections while still failing real active catalog under-materialization.
- Production parity audit still reports `production_ready: false` with full HoMM3-style parity, broad owner-H3M corpus breadth, and underground production parity remaining as explicit blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-semantic-layout-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend mapped owner-H3M comparisons beyond object/road/category counts so owner-corpus gates catch town-spacing, guard-footprint, and unguarded/object-only route-closure layout failures.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local uploaded owner H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Mapped owner-H3M comparisons include semantic layout metrics for owner and native outputs: nearest-town spacing, object-only town-route closure, unguarded/guard-controlled route closure, and guard-control footprint by level.
- The owner-corpus comparison gate fails mapped samples with native town spacing materially below the owner sample, object-only/unguarded reachable town pairs, or guard-control footprints materially below owner evidence.
- The comparison gate self-check proves synthetic semantic-layout failures are detected.
- Production parity audit consumes the strengthened owner-corpus summary without claiming full HoMM3 parity or broad corpus readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No full production-readiness claim from the current three mapped samples.
completionEvidence:
- Owner-corpus H3M comparisons now include semantic layout metrics for mapped owner/native samples: nearest-town spacing, object-only town-route closure, guard-controlled route closure, terrain/object/guard blocking footprint, and per-level guard-control totals.
- The mapped comparison gate now fails semantic-layout gaps and its self-check proves synthetic `semantic_layout_gap` failures are detected alongside object, guard, road-cell, category, and road-topology gaps.
- Medium Islands native spacing was corrected for the owner-compared translated profile while preserving zero unguarded/object-only reachable town pairs; the uploaded Small single-level native default remains at 7 towns, 150 decorative obstacles, 40 guards, 303 package objects, and closed town topology.
- Production parity audit consumes the strengthened owner-corpus gate and still reports `production_ready: false` with broad owner corpus, full parity, and underground production parity remaining as explicit blockers.
- Validation passed native build plus owner-corpus coverage, uploaded Small comparison, uploaded Small topology, and production parity completion audit reports.

Recently completed owner-directed implementation slice:

id: `native-map-package-document-validation-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace native map/scenario package validation stubs with bounded structural validators so generated package adoption is not relying on a `validation_not_implemented` API surface.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `src/gdextension/src/map_document.cpp`
- `src/gdextension/src/scenario_document.cpp`
- `tests/map_package_api_skeleton_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/map_package_api_skeleton_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `MapPackageService.validate_map_document` returns a real `aurelion_map_validation_report` with `status: pass` for structurally valid package map documents and `status: fail` with concrete failures for missing/null/invalid documents.
- `MapPackageService.validate_scenario_document` returns a real `aurelion_scenario_validation_report` with `status: pass` for structurally valid scenario documents bound to a valid map document and concrete failures for null/invalid/mismatched documents.
- Validation checks include document identity, dimensions/levels, object bounds, duplicate placement ids, terrain layer sizing, road payload sanity, scenario identity, map_ref consistency, and player-slot/objective metrics.
- Existing package save/load and generated package adoption reports pass against the native validator.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No broad semantic parity claim from structural document validation alone.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native `MapPackageService.validate_map_document` and `validate_scenario_document` now return concrete structural pass/fail reports for valid, invalid, null, and mismatched package documents instead of `validation_not_implemented`.
- Structural validation covers document identity, dimensions/levels, object bounds, duplicate placement ids, terrain layer sizing, road payload sanity, scenario identity, map references, player slots, and objective metrics.
- Package API, package adoption, package replay, map-editor load, and maps-folder package browser reports passed against the native validator while preserving the no-full-parity boundary.

Current owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-comparison-hard-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Harden the dynamic owner-H3M corpus report so mapped owner/native comparisons with category, object, town, guard, road-cell, road-topology, generation, validation, or package-conversion gaps fail the report instead of returning `ok: true` as a loose inventory.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local uploaded owner H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The owner-corpus report computes explicit comparison gate failures for mapped readable samples.
- The report exits nonzero if a mapped sample has native generation/conversion failure, native `not_implemented`, generation validation failure, object/town/guard/road-cell deltas, category-count gaps, or road-topology gaps.
- The current three mapped owner samples still pass after the hard gate: Small single-level, Small underground, and Medium Islands.
- The production parity audit continues to consume the owner-corpus summary without claiming full HoMM3 production parity or corpus readiness.
nonGoals:
- No new HoMM3 art/object import or exact byte parity claim.
- No broad owner-corpus readiness claim beyond the currently mapped samples.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner-corpus coverage report now emits `comparison_gate` with hard-gated mapped sample failures for native generation/conversion status, validation status, object/town/guard/road-cell deltas, owner category gaps, and per-level road component topology gaps.
- Owner-corpus report exits nonzero when the real mapped comparison gate or synthetic gate self-check fails; the self-check proves synthetic object, guard, road-cell, category, and road-topology mismatches are detected.
- Current mapped owner samples pass with `mapped_sample_count: 3`, `mapped_pass_count: 3`, and `failure_count: 0` for Small single-level, Small underground, and Medium Islands.
- Production parity audit now rebuilds the owner-corpus native comparisons, fails if the mapped comparison gate fails, and includes the `mapped_comparison_gate` evidence under the broad owner-H3M corpus missing requirement.
- Validation passed owner-corpus coverage, production parity completion audit, progress JSON validation, and diff whitespace checks.

Recently completed owner-directed implementation slice:

id: `native-rmg-production-audit-structural-matrix-evidence-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Update the production parity audit so it separately records the now-passing translated-catalog structural route-closure matrix while preserving the remaining owner-H3M corpus and underground production blockers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit still reports `production_ready: false`.
- Audit includes a satisfied checklist item for translated-catalog structural route-closure matrix evidence across land/surface, Islands/surface, and land/underground.
- Remaining broad owner-H3M corpus blocker no longer ambiguously treats structural route-closure matrix coverage as missing; it specifically names missing owner-H3M corpus coverage for larger sizes and broader recovered-template/water/underground samples.
- Audit still does not claim exact HoMM3 byte/art parity or player-facing underground production readiness.
nonGoals:
- No generator behavior changes.
- No exact HoMM3 byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity audit schema advanced to v2 and now includes a satisfied `translated_catalog_structural_route_closure_matrix` checklist item for land/surface, Islands/surface, and land/underground translated-catalog structural sweeps.
- Audit evidence records the dedicated full-sweep scenes and their passed counts: 51 land/surface, 45 Islands/surface, and 47 land/underground eligible translated templates, all with zero translated `not_implemented`, zero zero-tile roads, and zero object-only route leaks.
- Broad owner-H3M corpus missing scope now specifically names missing Large/XL owner sample coverage, owner-H3M recovered-template breadth corpus, and owner-H3M water/underground matrix coverage, avoiding ambiguity with the now-passing structural matrix.
- Production audit still reports `production_ready: false` with three missing requirements: full HoMM3-style parity, broad owner-H3M comparison corpus, and underground production parity.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-translated-catalog-water-underground-route-closure-sweeps-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add dedicated full translated-catalog route-closure sweeps for Islands/surface and land/underground lanes so non-land structural coverage is repeatable without environment-variable setup.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.tscn`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A dedicated Islands/surface full-sweep report runs eligible recovered translated templates with the default cap disabled and translated-template filtering enabled.
- A dedicated land/underground full-sweep report runs eligible recovered translated templates with the default cap disabled and translated-template filtering enabled.
- Both reports fail if an eligible translated template reports `not_implemented`, lacks roads/towns/guards/objects, contains zero-tile roads, or exposes object-only player-start, cross-zone, or all-town reachable town pairs.
- Passing evidence remains structural coverage only and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or player-facing underground production readiness.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No player-facing exposure of Islands or underground as full production parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Added dedicated Islands/surface and land/underground full-sweep scenes that inherit the translated-catalog full-sweep wrapper and force the relevant water/underground lane without environment variables.
- Islands/surface full sweep passed with 45 eligible translated templates attempted, zero translated `not_implemented` statuses, zero zero-tile roads, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Land/underground full sweep passed with 47 eligible translated two-level templates attempted, zero translated `not_implemented` statuses, zero zero-tile roads, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Skips are now explicit per lane for translated templates that do not have a supported size/profile plan, while local fixture templates are excluded by the translated-template filter.
- Evidence remains structural route-closure coverage and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or player-facing underground production readiness.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-translated-catalog-route-closure-sweep-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add an explicit full translated-catalog route-closure sweep so the capped broad-template smoke report cannot be mistaken for all-template production evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A dedicated full-sweep report runs the broad translated catalog without the default 12-template cap.
- The report fails if any eligible translated template is skipped by a bounded default limit, reports `not_implemented`, lacks roads/towns/guards/objects, or exposes object-only player-start, cross-zone, or all-town reachable town pairs.
- The existing capped broad-template report remains available for faster smoke coverage.
- Passing evidence is explicitly structural route-closure coverage and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or underground production readiness.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No player-facing exposure of every recovered template as production parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Added a dedicated full translated-catalog land/surface sweep report that inherits the broad-template generation/package/route-closure checks, filters to recovered translated templates, and disables the default 12-template cap.
- The full sweep passed with 51 eligible translated templates attempted, zero translated `not_implemented` statuses, zero object-only player-start, cross-zone, or all-town package route leaks, and zero zero-tile roads.
- Only translated templates `009` and `044` were skipped for the land/surface lane because they have no supported land/surface size/profile plan; local fixture templates were excluded by the translated-template filter.
- The existing capped broad-template report remains unchanged for faster smoke coverage, and the new evidence remains structural route-closure coverage rather than exact HoMM3 byte/art parity or underground production readiness.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-single-level-auto-density-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Fix the remaining uploaded owner Small single-level corpus mismatch where `native_catalog_auto` selects owner-compared template `049` but still applies the broad structural auto density supplement, producing extra decorative objects compared with the owner H3M sample.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `scripts/core/ScenarioSelectRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-compared translated profiles selected through `native_catalog_auto` do not receive the broad structural catalog density-floor decoration supplement.
- Uploaded Small single-level owner corpus comparison matches native `049` on total object count and owner categories: decoration 150, guard 40, object 30, reward 76, town 7.
- Uploaded Small topology report continues to pass with route closure, road topology, town count, guard count, and legacy compact diagnostic evidence intact.
- Auto-template, package replay, and production audit reports still pass and still do not claim full HoMM3 production parity.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No broad owner-corpus readiness claim beyond the currently uploaded samples.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native C++ object generation now skips the broad `native_catalog_auto` density-floor supplement when the normalized config is an owner-compared translated profile.
- Owner corpus coverage report now compares the uploaded Small single-level H3M and native auto-selected `translated_rmg_template_049_v1` at exact owner counts: 303 objects, decoration 150, guard 40, object 30, reward 76, town 7, 110 road cells, and road components `[96, 14]`.
- The same owner corpus report still matches the uploaded Small underground and Medium Islands samples exactly on extracted object, town, guard, owner-category, and road metrics.
- Uploaded Small topology report, native auto-template batch, package session authoritative replay, production parity completion audit, full-parity boundary report, and menu wiring report all passed after the density exemption.
- Production audit remains explicitly `production_ready: false`, with full parity, broad owner corpus, and underground production readiness still missing.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-auto-catalog-launch-selection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct player-facing native catalog auto-selection so it prefers owner-compared translated production defaults when available, while keeping broader launchable translated recovered catalog candidates available only as internal/fallback coverage instead of exposing them as HoMM3-like parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `scripts/core/ScenarioSelectRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection rejects `not_implemented`, legacy compact, and foundation templates for normal generated-skirmish startup and prefers owner-compared translated defaults for current size, water, underground, and player-count lanes.
- Representative player-facing auto-selection cases generate, validate, package, and replay through owner-compared templates `049`, `027`, `002`, `001`, `042`, and `043` without reopening the town-stacking or unguarded route regressions.
- Menu setup keeps manual template/profile pickers hidden while documenting that native catalog auto uses an owner-compared default policy plus a broad internal launch gate.
- Production parity audit no longer treats broad structural template exposure as product readiness; it still preserves no full HoMM3 parity, broad owner-corpus, and underground-production overclaim boundaries.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No claim that broad structural or owner-compared auto-selected templates are full parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native catalog auto-selection now prefers owner-compared translated candidates before broad launchable translated catalog fallbacks.
- Random-map menu wiring passed with manual template/profile controls hidden and policy `native_catalog_auto_prefers_owner_compared_defaults_with_broad_internal_launch_gate`.
- Native auto-template batch passed across representative Small, Small underground, Medium, Medium Islands, Large, and XL cases, selecting `translated_rmg_template_049_v1`, `027`, `002`, `001`, `042`, and `043` respectively.
- Package session authoritative replay passed for the owner-compared defaults with runtime call-site adoption and replay identity stable.
- Uploaded Small single-level topology comparison passed for the owner-like native `049` package with 7 towns, 40 guards, 110 road cells, matching `[96, 14]` road components, and zero object-only reachable town pairs; the legacy compact fixture remains correctly diagnosed as bad and launch-blocked.
- Production parity completion audit remains explicitly `production_ready: false` with missing full parity, broad owner corpus, and underground production readiness requirements.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-underground-template-structural-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reduce the underground production-parity blocker by adding a broad translated-template underground structural generation gate and allowing supported two-level translated catalog configs to generate as structural not-full-parity outputs instead of `not_implemented`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Broad template generation report can run with an underground/two-level option against translated templates that declare `supported_counts` containing `2`.
- Supported two-level translated catalog configs report `translated_catalog_structural_profile_not_full_parity`, not `not_implemented`, without claiming full parity or runtime production readiness.
- The broad underground gate validates generation, package conversion, non-empty surfaces, road materialization, and object-only route closure for attempted coherent two-level translated-template cases.
- Existing land and Islands broad structural gates remain passing.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No full HoMM3 production parity claim.
- No player-facing underground exposure.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native translated catalog structural support now accepts `level_count` 1 or 2 while preserving structural-not-full-parity status boundaries.
- Broad land/surface generation passed 54 eligible/attempted templates, with zero translated `not_implemented` statuses and zero object-only player-start, cross-zone, or all-town package route leaks.
- Broad Islands/surface generation passed 45 eligible/attempted translated templates, with zero translated `not_implemented` statuses and zero object-only player-start, cross-zone, or all-town package route leaks.
- Broad land/underground generation passed 47 eligible/attempted coherent two-level translated templates, all reported `translated_catalog_structural_profile_not_full_parity`, with zero `not_implemented` statuses and zero object-only route leaks.
- Dense two-level translated cases in the 026/027/035/037 range now select roomier structural sizes and pass generation/package validation.
- Production parity audit remains explicitly not production-ready with four missing requirements, and the full-parity gate still reports no full HoMM3 parity claim.

id: `native-rmg-production-parity-audit-owner-corpus-refresh-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Refresh the production-parity completion audit so its broad owner-corpus missing-requirement evidence reflects the current three exact uploaded owner comparisons instead of stale Small/Medium wording.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production parity audit still reports `production_ready: false`.
- Broad owner-H3M corpus missing requirement names the current three compared owner samples and the remaining missing corpus scope.
- No full-parity or broad underground/player-facing template support claim is introduced.
nonGoals:
- No generator behavior changes.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity completion audit still reports `production_ready: false` and `missing_requirement_count: 4`.
- Broad owner-H3M corpus missing requirement now names the three exact current uploaded owner comparisons: `owner_small_land_single_level`, `owner_small_with_underground`, and `owner_medium_islands`.
- Remaining corpus blocker is explicit: missing Large/XL owner sample coverage, recovered-template breadth corpus, and broad water/underground matrix coverage.
- No full HoMM3-style parity, broad player-facing 56-template support, or underground production parity claim was introduced.

Previous recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-category-shape-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Medium Islands category-shape comparison so native output no longer hides a 7-object reward/object swap behind matched total object, town, guard, and road counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Medium Islands native owner-category comparison matching decoration 252, guard 61, object 72, reward 103, and town 8.
- Total object count, town count, guard count, road count, and level 0 road component sizes remain matched for the Medium Islands owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad Islands production parity claim beyond the uploaded owner-compared sample.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Medium Islands sample and native `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` comparison matching category counts exactly: decoration 252, guard 61, object 72, reward 103, and town 8.
- The same comparison preserves total and road parity for the bounded sample: 496 objects, 8 towns, 61 guards, 184 road cells, and level 0 road component sizes `[82, 52, 19, 16, 15]`.
- Package object-only breadth report passed after save/load with the `owner_medium_islands_001` case at 496 objects, 8 towns, 61 guards, 184 road tiles, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes missing Large/XL owner corpus samples, full recovered-template owner comparison, and no exact HoMM3 production parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-single-level-road-exact-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Small single-level road comparison so native package output matches the owner road-cell count and component sizes instead of only matching the broad two-component shape.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the uploaded Small single-level native road comparison at 110 road cells with level 0 road component sizes `[96, 14]`.
- Total object count, town count, guard count, and owner category counts remain matched for the Small single-level owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad all-template road topology parity claim.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small single-level sample and native `translated_rmg_template_049_v1` / `translated_rmg_profile_049_v1` comparison both at 110 road cells with level 0 road component sizes `[96, 14]`.
- The same comparison preserves exact object, town, guard, and owner-category counts: 303 objects, 7 towns, 40 guards, decoration 150, object 30, reward 76, and town 7.
- Package object-only breadth report passed after save/load with zero object-only all-town and cross-zone reachable pairs for the Small default and all other covered owner-compared defaults.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes Medium Islands category-shape mismatch, missing Large/XL owner corpus samples, full recovered-template owner comparison, and no exact HoMM3 production parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-category-shape-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Small underground category-shape comparison so native output no longer hides a 52-object reward/object swap behind matching total object counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Small underground native owner-category comparison matching decoration, guard, object, reward, and town counts for the uploaded sample.
- Total object count, town count, guard count, level count, and all-level road topology remain matched for the Small underground owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small underground sample and native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` comparison matching category counts exactly: decoration 151, guard 60, object 100, reward 117, and town 8.
- The same comparison preserves total parity for the bounded sample: 436 objects, 8 towns, 60 guards, 157 road cells, and all-level road topology status `all_level_component_sizes_match`.
- Package object-only breadth report passed the `owner_small_underground_027` case after save/load with 436 objects, 60 guards, 8 towns, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes the Small single-level road-cell delta, Medium Islands category-shape delta, missing Large/XL owner corpus samples, and no full 56-template exact HoMM3 parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-object-density-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the next owner-uploaded Small underground comparison gap by bringing native package object density up to the owner H3M sample while preserving the already-matched town, guard, level, road, and route-closure behavior.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Small underground native comparison at the uploaded owner object-count target or records a precise residual density gap.
- Town count, guard count, level count, and all-level road topology remain matched for the Small underground owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small underground sample and native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` comparison both at 436 total objects, 8 towns, 60 guards, 157 road cells, and all-level road topology status `all_level_component_sizes_match`.
- Native Small underground decoration count now matches the owner H3M sample at 151 while preserving package route closure.
- Package object-only breadth report passed the `owner_small_underground_027` case after save/load with 436 objects, 60 guards, 8 towns, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; the owner-category comparison still reports a category-shape gap with native object category 48 versus owner 100 and native reward category 169 versus owner 117.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-runtime-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded owner Small two-level land comparison from `not_implemented` into bounded owner-compared native package generation so the corpus can measure its actual town, guard, road, level, and route-closure parity gaps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report compares the uploaded Small underground H3M sample against native output instead of reporting `native_not_implemented`.
- Native package conversion preserves two materialized levels and exposes road metrics for both surface and underground levels.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now compares the uploaded Small underground sample with native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` output instead of reporting `native_not_implemented`.
- Native package conversion preserves two levels and exactly matches uploaded owner road metrics for this sample: surface `[116]`, underground `[23, 18]`, total road cells `157`, and all-level road topology status `all_level_component_sizes_match`.
- Package object-only breadth report passed the new `owner_small_underground_027` case after save/load with 8 towns, 60 guards, 318 package objects, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- The comparison remains explicitly not full parity: native object density is still 318 objects versus 436 in the owner H3M sample, and full-generation status remains `owner_compared_translated_profile_not_full_parity`.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-road-component-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the owner-compared Medium Islands road topology so native output no longer collapses the uploaded owner H3M comparison into one giant surface road component plus one-tile stubs.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Medium Islands native comparison with a HoMM3-like multi-component road shape, not one giant connected road component and one-tile artifacts.
- Native object, town, and guard counts for the owner Medium Islands comparison remain matched to the uploaded H3M sample.
- Package object-only route and spatial comparison gates remain valid; roads do not create unguarded gameplay bypasses between zones or towns.
- Full-generation status remains owner-compared not-full-parity and does not claim exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad all-template road topology parity claim.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now compares road topology directly; Medium Islands native output remains 496 objects, 8 towns, 61 guards, and 184 road cells against the owner H3M sample.
- Medium Islands package road components changed from one 181-cell component plus seven one-tile fragments to the owner H3M five-component shape `[82, 52, 19, 16, 15]` with `component_size_abs_delta: 0` for this owner sample.
- Native C++ rebuild, owner corpus coverage, spatial placement comparison, package object-only breadth, repository validation, progress JSON validation, plan sync dry-run, and diff whitespace checks passed.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-runtime-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the exact owner-attached Medium islands template/profile `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` to owner-compared runtime support after fixing same-zone town-pair closure without increasing the owner-observed guard count.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Exact Medium islands template/profile 001 is `owner_compared_translated_profile_supported` while still reporting `owner_compared_translated_profile_not_full_parity`.
- Same-zone town-pair route closure reuses existing guard closure masks when the owner guard cap is reached, preserving owner-like guard/object counts.
- Package conversion, save, and load preserve closure masks and leave zero object-only town traversal routes.
- Full-parity and player-facing UI gates keep islands support bounded and do not expose a broad islands/full-parity claim.
nonGoals:
- No broad islands or underground parity claim.
- No exposure of islands as a general player-facing random-map option.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
- No all-56-template production parity claim.
completionEvidence:
- Medium islands spatial comparison passed for profile 001 with 8 towns, 4 zones, 496 objects, 61 guards, owner-compared support enabled, and full parity still false.
- Package object-only breadth report passed the new `owner_medium_islands_001` case with 8 towns, 61 guards, 496 objects, 206 loaded road tiles, and zero object-only all-town or cross-zone town routes.
- Full parity gate passed with the new Medium islands case runtime-adopted only as owner-compared not-full-parity output.
- Package adoption and authoritative replay reports passed after excluding diagnostic runtime phase timing from replay identity signatures.
- Random-map menu wiring and skirmish UI save/replay reports passed, preserving the four-template player-facing surface and not exposing islands globally.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-template-surface-restriction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Keep the full recovered 56-template catalog available for internal validation while restricting player-facing random-map setup options to the four owner-compared translated size defaults until broad recovered-template production parity exists.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- `random_map_player_setup_options()` reports full internal catalog counts but returns only production-facing size-default template/profile options.
- Main menu generated-map controls remain native catalog auto with manual template/profile pickers hidden.
- Internal validation still builds all 56 catalog template/profile configs.
- Explicit unsupported template launches remain blocked by `full_generation_status: not_implemented` rather than silently falling back to legacy compact output.
nonGoals:
- No broad all-56 production parity claim.
- No runtime-authoritative adoption for unsupported templates.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
completionEvidence:
- Random-map menu wiring report passed with catalog counts 56/56, internal built config count 56, player-facing template/profile counts 4/4, and manual template/profile controls hidden.
- Random-map retry UX report passed, preserving native catalog auto launch provenance and not-implemented launch blocking.
- Random-map skirmish UI save/replay report passed after launching from the asserted setup and checking stable generated identity rather than a regenerated package scenario id.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-default-selection-repair-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Repair the broad recovered-template generation report so it evaluates player-facing Small/Medium/Large/XL translated defaults with the same size-class/player-count selection used by runtime setup, instead of misclassifying supported defaults as arbitrary minimum-template `not_implemented` cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template planning prefers `ScenarioSelectRules.random_map_size_class_default()` when the catalog template/profile is the runtime default for a size class.
- Broad report case summaries record the selection policy used for each attempted template.
- Focused Small/Medium/Large/XL default translated templates report `owner_compared_translated_profile_not_full_parity`, not `not_implemented`.
- Full unbounded broad sweep still attempts every eligible land/surface template with zero skips and keeps unsupported templates explicitly marked as parity debt.
nonGoals:
- No broad all-56 production parity claim.
- No runtime-authoritative generated-skirmish adoption.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
completionEvidence:
- Focused broad sweep for translated defaults `049`, `002`, `042`, and `043` passed with all four using `selection_policy: player_facing_size_default` and `not_implemented_status_count: 0`.
- Full unbounded broad sweep passed 56/56 eligible templates with zero skipped templates, status counts `{not_implemented: 51, owner_compared_translated_profile_not_full_parity: 4, scoped_structural_profile_not_full_parity: 1}`, and selection-policy counts `{minimum_supported_land_surface: 52, player_facing_size_default: 4}`.

Recently completed owner-directed implementation slice:

id: `native-rmg-town-placement-reachability-cache-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Cache per-zone access-anchor reachability during native town placement so recovered translated templates avoid repeated per-candidate BFS while preserving the uploaded Small H3M town/zone/road/object route gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `ops/progress.json`
completionCriteria:
- Native town placement computes one access-reachable lookup per zone/access anchor and uses it for spaced accessible candidate checks instead of running an in-zone path search for each town candidate.
- Serialized package component counts report the actual package road surface count so comparison gates compare owner H3M road counts against loaded package semantics.
- Uploaded Small H3M comparison and topology reports keep the player-facing translated Small default at owner-like town, zone, road, decorative obstacle, and guard counts with zero object-only town routes.
- Focused worst-offender translated template `052` no longer spends most of generation time in repeated town-placement BFS and the unbounded broad template gate remains green for all eligible land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Uploaded Small comparison report passed with player-facing translated Small default at 7 towns, 7 zones, 303 package objects, 150 decorative obstacles, 40 guards, 113 serialized package road tiles, and zero package road gaps.
- Uploaded Small topology report passed with current translated package at 7 towns, 7 zones, 110 road cells, two road components, 150 decorative obstacles, 40 guards, and zero object-only town or cross-zone town routes; the stale compact map still demonstrates the bad baseline with 6 towns, 0 zones, 0 roads, and 10 reachable town pairs.
- Focused `translated_rmg_template_052_v1` broad generation passed in 14.638s after the reachability cache, with generation at 9.564s and no skipped focused case.
- Full unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and 55 templates still honestly marked `full_generation_status: not_implemented`.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-all-town-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the broad recovered-template package topology gate so all-town route checks use package visit-tile semantics and every eligible land/surface package proves object-only town routes are closed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package surface topology preserves town `package_visit_tiles` for all-town and cross-zone route checks instead of falling back to adjacent anchor cells.
- Broad template report fails on object-only all-town route leaks, not just player-start and cross-zone leaks.
- Native package conversion materializes guard control-zone, boundary-choke, and route guard/decorative closure masks before signatures so package topology does not depend on terrain-only barriers.
- Full unbounded sweep covers all currently eligible land/surface templates with zero object-only player-start, cross-zone, or all-town reachable town pairs.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Focused broad report passed for the two previously leaking templates `translated_rmg_template_006_v1` and `translated_rmg_template_010_v1`.
- Unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and zero object-only player-start, cross-zone, or all-town reachable town pairs under package visit-tile semantics.
- The unbounded report still honestly reports 55 templates with `full_generation_status: not_implemented`.

Recently completed owner-directed validation follow-up:

id: `native-rmg-runtime-authority-parity-gate-repair-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Repair the full-parity boundary gate so owner-compared translated packages may be runtime-authoritative without implying full HoMM3 parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
implementationTargets:
- `tests/native_random_map_full_parity_gate_report.gd`
- `ops/progress.json`
completionCriteria:
- The full-parity gate still fails any `full_parity_claim=true` at generation, provenance, or package-adoption boundaries.
- Owner-compared translated Small 049 and Medium 002 package/session adoption may report runtime authority and call-site adoption only with `full_parity_claim=false`.
- Owner-compared package-adoption reports keep explicit remaining parity slices for full parity, islands support, and broad owner comparison.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Full parity gate report passed with legacy compact non-authoritative and owner-compared translated defaults runtime-authoritative without full parity.

Recently completed owner-directed implementation slice:

id: `native-rmg-legacy-compact-launch-block-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the remaining production launch path for the legacy compact random-map generator after uploaded-map comparison showed that compact lineage can produce near-stacked, un-HoMM3-like maps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/autoload/SaveService.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
- `tests/random_map_final_writeout_export_save_schema_report.gd`
- `tests/random_map_scenario_load_smoke.gd`
- `ops/progress.json`
completionCriteria:
- Generated-skirmish startup rejects explicit `border_gate_compact_v1` / `border_gate_compact_profile_v1` requests with `native_rmg_legacy_compact_launch_blocked`.
- Legacy compact output remains available only as internal historical/export test fixture data, not as a production generated-skirmish launch path.
- Maps-folder stale-package rejection still creates a compact package fixture directly through native package service APIs.
- Native package-backed generated skirmish save/restore preserves package provenance and can re-register its transient generated scenario from saved package provenance.
nonGoals:
- No deletion of local uploaded `.h3m`, `.amap`, or `.ascenario` comparison evidence.
- No removal of compact generator component/export fixtures.
- No exact HoMM3 byte/object-art parity claim.
completionEvidence:
- Player setup retry UX report passed after asserting explicit compact launch is blocked with `native_rmg_legacy_compact_launch_blocked`.
- Maps-folder package browser integration report passed with compact fixture rejected and translated package accepted.
- Random-map skirmish UI save/replay report passed on native package provenance and package-backed restore.
- Final writeout export/save schema report passed while keeping compact generation as a legacy export fixture outside production launch.
- Random-map scenario load smoke passed after treating maps-folder package entries separately from archived authored scenarios.

Previously completed owner-directed implementation slice:

id: `native-rmg-broad-template-object-only-route-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend the broad recovered-template generation gate beyond non-empty package surfaces so every eligible land/surface template proves object-only player-start and cross-zone town routes are closed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template report reuses package-surface topology analysis for converted packages.
- Attempted recovered land/surface templates fail if object-only masks allow unguarded player-start town traversal.
- Attempted recovered land/surface templates fail if object-only masks allow unguarded cross-zone town traversal.
- Full unbounded sweep covers all currently eligible land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No same-zone multi-settlement route hard failure; same-zone all-town reachability remains diagnostic because some recovered templates place multiple settlements in one source zone.
- No islands/underground parity implementation.
completionEvidence:
- Bounded broad template report passed after adding object-only start/cross-zone topology gates.
- Unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and no object-only start/cross-zone reachable town pairs.

Previously completed owner-directed implementation slice:

id: `native-rmg-uploaded-small-guard-control-footprint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Materialize HoMM3-style monster/guard control zones into generated package blocking so the owner-uploaded Small comparison no longer understates guarded route closure.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package guard objects include a bounded one-tile control-zone blocking footprint for generated package pathing.
- Uploaded Small comparison fails if native guard blocking falls below the owner H3M parsed guard-control footprint floor.
- Current Small 049 generated package keeps owner-like town/zone/object/road counts and zero object-only town routes.
- Player-facing translated Small/Medium/Large/Extra Large package breadth keeps zero object-only reachable town pairs.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No H3M import/runtime adoption.
- No deletion or committing of uploaded local `.h3m`, `.amap`, or `.ascenario` evidence.
completionEvidence:
- Native build passed after adding package guard control-zone materialization.
- Uploaded Small H3M topology report passed with native guard unique blocked tiles above the owner guard-control lower-bound gate and zero object-only reachable town pairs.
- Package surface topology report passed for converted and saved/loaded Small 049 packages.
- Package object-only breadth report passed for translated Small, Medium, Large, and Extra Large defaults.

Previously completed owner-directed implementation slice:

id: `native-rmg-maps-folder-stale-package-rejection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prevent stale legacy compact generated packages in `maps/` from being exposed as valid skirmish/editor choices after owner-uploaded H3M comparison proved that topology is not HoMM3-like.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/map_editor_load_map_package_report.gd`
- `ops/progress.json`
completionCriteria:
- Maps-folder package index rejects generated packages that are not runtime-authoritative translated RMG outputs.
- Legacy `border_gate_compact_v1` / `border_gate_compact_profile_v1` packages are not exposed in the maps-folder skirmish browser.
- Accepted generated maps-folder packages still load through the native package/session path and editor working-copy path.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No deletion or committing of uploaded local `.h3m`, `.amap`, or `.ascenario` evidence.
completionEvidence:
- Maps-folder package browser integration report passed with a translated native-catalog-auto package accepted and a generated legacy compact package rejected from the index/browser.
- Map editor Load Map package report passed after moving its positive fixture to the translated native-catalog-auto package path.

Previously completed owner-directed implementation slice:

id: `native-rmg-runtime-town-spacing-validation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Move the near-stacked town protection from report-only coverage into native RMG runtime validation so launchable generated maps fail validation if towns are below the size-aware spacing floor.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Native validation emits a town-spacing summary with nearest town Manhattan distance and size-aware floor.
- Launchable native RMG profiles fail validation if nearest town spacing is below the floor.
- Auto-template report verifies its spacing metric agrees with native runtime validation.
- Existing package object-only closure and supported translated broad cases remain green.
nonGoals:
- No exact HoMM3 town-coordinate parity claim.
- No islands/water/underground parity implementation.
completionEvidence:
- Native build passed after adding runtime town-spacing validation.
- Auto-template batch passed with runtime town-spacing validation matching report metrics.
- Package object-only breadth passed with zero object-only reachable town pairs for Small, Medium, Large, and Extra Large defaults.
- Focused broad translated cases 049, 002, 042, and 043 passed generation/package conversion after the validation change.

Previously completed owner-directed implementation slice:

id: `native-rmg-auto-template-town-spacing-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add player-facing native-catalog-auto town-spacing evidence so representative generated maps cannot regress to near-stacked towns without failing validation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Auto-template batch reports nearest town Manhattan distance for each representative generated case.
- Launchable land defaults fail if nearest towns fall below size-aware spacing floors.
- Existing auto-template generation/package coverage remains green.
nonGoals:
- No exact HoMM3 town-coordinate parity claim.
- No generator algorithm change in this slice.
- No islands/water/underground parity implementation.
completionEvidence:
- Auto-template batch report passed with nearest town distances Small 11/14, Medium 17, Large 12, and Extra Large 24 against floors 8/8, 10, 12, and 12.
- The Medium islands not-implemented case remains internally inspectable and launch-blocked.

Previously completed owner-directed implementation slice:

id: `native-rmg-hide-unsupported-underground-control-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove unsupported underground generation from the player-facing generated-map setup surface until native RMG has production-ready underground parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
implementationTargets:
- `scenes/menus/MainMenu.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- The player-facing generated-map snapshot no longer lists underground as a visible control.
- The validation hook rejects attempts to enable unsupported underground generation.
- Internal provenance records underground as unsupported and hidden.
- Existing generated setup retry and menu wiring gates remain green.
nonGoals:
- No underground parity implementation.
- No exact HoMM3 byte/object-art parity claim.
completionEvidence:
- Player setup retry UX report passed with `underground_supported: false`, `underground_player_control_visible: false`, and no `underground` visible control.
- Menu wiring report still passed with native catalog auto defaults and hidden manual template/profile controls.

Previously completed owner-directed implementation slice:

id: `native-rmg-retry-attempt-native-provenance-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Ensure generated-map retry attempt records report the native-selected normalized template/profile ids, especially for blocked not-implemented native-catalog-auto modes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- Retry attempt records prefer native normalized config from setup provenance, validation failure evidence, or deterministic validation identity before falling back to legacy GDScript normalization.
- Blocked not-implemented setup attempts report the same template/profile ids as the native validation failure evidence.
- Existing generated setup retry and auto-template batch gates remain green.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No change to generated map topology or islands parity implementation.
completionEvidence:
- Player setup retry UX report passed after asserting blocked not-implemented attempt ids match native normalized failure config.
- Auto-template batch report passed after the retry attempt provenance correction.

Previously completed owner-directed implementation slice:

id: `native-rmg-not-implemented-launch-block-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prevent generated-skirmish startup from converting native RMG configurations whose recovered-template mode still reports `full_generation_status: not_implemented` into launchable packages.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Generated-skirmish startup blocks not-implemented native RMG modes before package conversion/loading.
- Failure evidence is surfaced through the existing validation/retry boundary with no session/save/campaign startup.
- Representative auto-template islands coverage remains available for internal inspection but is marked blocked for launch while land defaults still launch.
nonGoals:
- No islands/water/underground parity implementation.
- No exact HoMM3 byte/object-art parity claim.
- No removal of internal broad-template inspection for not-implemented recovered templates.
completionEvidence:
- Player setup retry UX report passed after proving a Medium islands native-catalog-auto setup fails with `native_rmg_full_generation_not_implemented` evidence.
- Auto-template batch report passed with Small/Medium/Large/XL land defaults still generating and packaging, while the Medium islands case reports `not_implemented_launch_blocked: true`.

Previously completed owner-directed implementation slice:

id: `native-rmg-player-facing-compact-fallback-removal-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove the old compact template from live generated-map fallback behavior so player-facing setup and invalid-template recovery do not silently produce the bad compact topology found in the owner-uploaded native map comparison.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing generated-map setup keeps manual template/profile controls hidden and launches through native catalog auto-selection.
- Empty/default Small setup previews translated Small 049 instead of compact legacy ids.
- Invalid manual template fallback resolves to translated Small 049 instead of `border_gate_compact_v1`.
- Representative auto-selection cases generate/package through translated owner-compared land templates for Small, Medium, Large, and Extra Large.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground parity implementation; islands still remain explicit not-implemented follow-up.
- No removal of explicit legacy compact fixtures used by old package/schema compatibility tests.
completionEvidence:
- Menu wiring report passed with 56 catalog templates/profiles, hidden manual template/profile controls, and default template `translated_rmg_template_049_v1`.
- Player setup retry UX report passed with native auto launch provenance and translated Small 049 preview/default.
- Auto-template batch report passed; owner-compared land defaults selected translated templates 049, 002, 042, and 043.

Previously completed owner-directed implementation slice:

id: `native-rmg-all-template-structural-breadth-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the hard generation/package failures exposed by running the broad native RMG report across every eligible recovered land/surface template after the uploaded Small map comparison reopened structural parity work.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- All eligible recovered land/surface templates generate, validate, convert to packages, expose non-empty package objects/roads, and serialize zero zero-tile roads.
- Town-pair route closure guards do not collide with existing generated object occupancy.
- Dense required town/castle placement has a bounded last-resort spacing fallback instead of failing package generation.
- Active player-start zones isolated by recovered link player-count filters receive a guarded runtime repair route.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground full-parity implementation.
- No claim that all `not_implemented` recovered-template statuses are resolved.
completionEvidence:
- Full broad native RMG template report passed all 56 eligible templates with 0 skipped and no case failures.
- Focused recovery gates passed translated templates 010/052 for guard occupancy collisions, 041/044 for dense required town placement, and 043 for active player-start connectivity repair.
- Native build passed after the generator corrections.

Previously completed owner-directed implementation slice:

id: `native-rmg-uploaded-small-road-component-split-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded-Small native package road component shape by adding a bounded orphan side-road component and suppressing one deterministic articulation road overlay tile when it splits Small 049 roads into two owner-like package components.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small report exposes road component sizes for owner and native package roads.
- Native Small 049 package road component count moves from one component to the owner-uploaded two-component shape.
- Native Small 049 smaller road component matches the uploaded owner H3M smaller road component size.
- Road-cell count remains within the uploaded Small tolerance and no zero-tile roads are serialized.
- Object-only town closure remains green after the road overlay split.
nonGoals:
- No exact road byte/art parity.
- No exact large road component shape or byte-level road-art parity; the native large component remains 99 cells versus owner 96.
- No broad all-template road-shape parity claim.
completionEvidence:
- Uploaded Small report now shows owner H3M road components `[96, 14]` and native generated Small road components changed from `[105]` through `[99, 5]` to `[99, 14]`.
- Native generated Small road cells changed from 105 to 113 versus owner 110, keeping road-cell delta at +3 and reducing road-component delta from -1 to 0.
- Uploaded Small topology still passed with 7 towns, 7 zones, 303 objects, zero unresolved/object-only town reachable pairs, road small-component delta 0, and object-blocked delta +24 versus owner parsed mask blockers.
- Package object-only breadth still passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town reachable pairs.
- Bounded broad template generation still passed 12 representative land/surface templates.

Previously completed owner-directed implementation slice:

id: `native-rmg-selective-small-boundary-mask-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace uploaded-Small full terrain-rock boundary/route-guard mask materialization with selective package-object town-route closure masks, reducing decorative and guard blocker overcoverage while preserving object-only town isolation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small generated native package keeps 7 towns, 7 zones, 303 objects, 150 decorative obstacles, 40 guards, and zero object-only town routes.
- Decorative boundary choke and Small route-guard closure materialization become path-driven for Small 049 instead of copying every land-boundary rock/opening cell into package blocker masks.
- Uploaded Small object-blocked overage warning clears without reintroducing unresolved or object-only town reachability.
- Package object-only breadth and bounded broad template generation remain green after the selective mask change.
nonGoals:
- No exact HoMM3 full parity or byte/object-art parity claim.
- No claim that older already-exported native `.amap` packages are corrected in place.
- No islands/water/underground parity implementation.
completionEvidence:
- Uploaded Small topology report passed with native object-blocked tiles reduced from 1043 to 747, native-vs-owner mask-blocked delta reduced from +321 to +25, decorative unique block tiles reduced from 640 to 441, guard unique block tiles reduced from 420 to 95, and decorative boundary choke tiles reduced from 343 to 42.
- Uploaded Small topology report still showed 7 towns, 7 zones, 303 objects, 105 road cells, 40 guards, and zero unresolved/object-only town reachable pairs; the prior object-blocked overage warning cleared.
- The report now emits both uploaded native packages: the newer translated-template package closes object-only cross-zone town routes, while the legacy compact package remains diagnostic evidence of the old bad output.
- Package object-only breadth passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town reachable pairs.
- Bounded broad template generation passed after the selective Small mask change.

Previously completed owner-directed implementation slice:

id: `native-rmg-size-scaled-corridor-guard-footprint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reduce Small-map route-guard blocker overreach by replacing full close-town corridor guard walls with size-scaled corridor choke coverage while preserving Medium/Large/XL object-only town-route closure gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- Small translated-template town corridor coverage no longer assigns every close cross-zone town-pair path cell to route guard bodies.
- Uploaded Small comparison keeps zero unresolved and zero object-only reachable town pairs after guard-footprint reduction.
- Package object-only breadth still keeps zero all-town and cross-zone town reachable pairs for Small 049, Medium 002, Large 042, and Extra Large 043.
- Broad land/surface template generation still validates representative catalog templates after the size-scaled guard policy.
nonGoals:
- No exact HoMM3 full parity claim.
- No elimination of all native object-blocked overage versus the uploaded owner map.
- No islands/water/underground parity implementation.
completionEvidence:
- Uploaded Small comparison passed with guard unique block tiles reduced from the prior 615 to 420, clearing the guard-footprint warning while preserving 7 towns, 7 zones, 150 decorations, 40 guards, and zero object-only town routes.
- Uploaded Small object-blocked total improved from 1147 to 1043 in the topology report, with the remaining object-blocked overage still explicitly warned for follow-up.
- Package object-only breadth passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town/cross-zone reachable town pairs; Small package object-only blocked tiles are now 1031 instead of the earlier 1158.
- The rebuilt bounded 12-template broad generation report passed with non-empty package surfaces and zero zero-tile roads.
- Validation passed native build, uploaded Small topology report, package object-only breadth report, bounded 12-template broad generation report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed audit/implementation slice:

id: `native-rmg-uploaded-small-blocker-footprint-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Compare the uploaded Small 3-player single-level HoMM3 map against the current native translated Small package with explicit blocker/guard footprint metrics, and reduce one route-guard overreach without reopening town routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small HoMM3 comparison reports native-vs-owner object, road, town, guard, zone, and blocked/controlled tile deltas.
- Native report distinguishes object blocker coverage from terrain-blocked coverage and exposes per-kind package blocker footprints.
- Route-guard body generation no longer uses every road segment cell as a guard blocker body.
- Existing object-only package closure gates remain green after the guard-footprint adjustment.
nonGoals:
- No claim that native blocker footprint now matches HoMM3.
- No removal of required town-boundary guard coverage until explicit obstacle/choke blockers replace it.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Uploaded Small HoMM3 parse remains 7 towns, 7 zones, 150 decorations, 40 guards, 110 road cells, 722 parsed mask-blocked tiles, and 258 parsed guard-controlled tiles.
- Current native Small 049 package matches headline town/zone/object/decor/guard counts and still has zero object-only reachable town pairs.
- The comparison now warns that native object blockers cover 1147 tiles versus the owner parsed 722 mask-blocked tiles, and native guard blockers cover 615 unique tiles versus the owner parsed 258 guard-controlled tiles.
- Route-guard segment body coverage was narrowed to the guard tile, nearby boundary cells, and immediate neighboring road cells instead of every road segment cell.
- Validation passed native build, uploaded Small comparison, package object-only breadth, bounded 12-template broad generation, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-choke-guard-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the translated-template town/zone and route-guard blocker issues exposed by uploaded Small HoMM3/native map comparison and add a bounded broad generation/package gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_broad_template_generation_report.tscn`
- `ops/progress.json`
completionCriteria:
- Uploaded Small HoMM3/native comparison findings are reflected in native RMG fixes instead of relying on the old compact fallback template behavior.
- Translated catalog zones only become active player-start zones when their source role is a start zone, preventing treasure zones from becoming extra players/towns.
- Route guards own unique choke primary tiles and may displace decorative/scenic filler on the choke instead of duplicating guard occupancy or leaving malformed objects.
- A bounded broad-template report validates generation, output validation, package conversion, non-empty package objects/roads, and zero zero-tile roads for representative land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground full-parity implementation.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Uploaded HoMM3 Small single-level comparison showed 7 towns, 7 zones, 150 decorations, 40 guards, 110 road cells, and no near-stacked towns; the bad native upload was identified as old compact-template output with 6 towns, no zone metadata, zero usable road cells, and unguarded town routes.
- Native translated zone conversion now keeps non-start owned source zones neutral/non-player for player-start purposes while preserving owned faction context where applicable.
- Route guard placement no longer falls back onto an occupied guard tile; it can take a neighboring decorative/scenic choke tile and the choke-clearance pass removes displaced filler from generated object placements.
- Broad template generation report passed 12 bounded land/surface cases: legacy small templates plus translated templates 001 through 009, each with validation OK, non-empty package surfaces, roads, and zero zero-tile roads.
- Validation passed native build and targeted translated template 008/009 broad reports plus bounded 12-case broad report.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-compared-runtime-authority-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Mark owner-compared translated native RMG packages as runtime-authoritative package/session inputs while keeping exact HoMM3/full-parity claims false.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_session_adoption_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_package_session_adoption_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- Native adoption reports `native_runtime_authoritative: true` for owner-compared translated land templates after package/session conversion.
- Runtime authority no longer implies `full_parity_claim`; full parity remains false until exact HoMM3 parity is proven.
- Package/session adoption and replay reports prove stable package/session identity for the owner-compared translated path.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No runtime authority for `not_implemented` islands or unsupported broad catalog templates.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Owner-compared translated package/session adoption now reports `runtime_authoritative_owner_compared_not_full_parity`, with `native_runtime_authoritative: true` and `full_parity_claim: false`.
- Package/session replay evidence for the Medium 002 owner-compared profile preserves stable adoption, changed-map, and disk package replay signatures while keeping full HoMM3 parity pending.
- Package object-only breadth still reports zero object-only unguarded all-town reachable pairs for Small 049, Medium 002, Large 042, and Extra Large 043.
- Validation passed native build, package/session adoption report, Medium 002 authoritative replay report, package object-only breadth report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-water-support-guard-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove unsupported islands generation from the player-facing generated-map setup until native islands templates have owner-compared parity evidence instead of `not_implemented` fallback status.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing random-map water options expose only implemented native land generation.
- Main menu generated-map controls fall back to land if a stale unsupported islands selection is present.
- Menu retry UX and auto-template tests pass without exposing unsupported islands as a production option.
nonGoals:
- No native islands/water parity implementation in this slice.
- No removal of catalog metadata or lower-level explicit test coverage for islands templates.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Player-facing random-map setup now exposes only the implemented native Land water option.
- Main menu generated-map controls fall back to Land when stale state references an unsupported water option.
- Retry UX report now proves water options are `["Land"]`, while auto-template batch retains lower-level islands coverage as non-player-facing `not_implemented` evidence.
- Validation passed menu retry UX report, all-template menu wiring report, auto-template batch report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-production-filter-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop player-facing native catalog auto-selection from choosing broad translated templates whose native generation status is still `not_implemented` when an owner-compared translated land template exists for the requested size.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection prefers owner-compared translated templates for supported land size classes instead of random runtime-valid but not-implemented broad catalog templates.
- Auto-template batch report fails if a supported land size auto-selects a template with `full_generation_status: not_implemented`.
- Existing uploaded Small H3M topology, auto-template batch, package breadth, and replay gates remain green.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water full-parity implementation in this slice.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Native catalog auto-selection now builds a preferred owner-compared translated-template pool for supported land sizes before falling back to the wider catalog.
- Auto-template batch now fails if Small/Medium/Large/XL land auto-selection chooses a broad catalog template instead of the owner-compared translated template/profile.
- Auto-template batch passed with land selections pinned to Small 049, Medium 002, Large 042, and XL 043; the Medium auto density floor was raised to keep owner-compared Medium 002 above package density minimums.
- Validation passed native build, auto-template batch, uploaded Small H3M topology report, default package object-only breadth report, medium replay report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-density-floor-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the sparse-map failure exposed by native catalog auto-selection where broader translated templates can generate valid but underfilled maps, especially Medium land and XL land cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Auto-template batch report enforces size-aware generated/package object density floors, not only non-empty surfaces.
- Native broad catalog auto-selection supplements sparse templates with deterministic in-zone decorative/object fill without touching uploaded evidence files.
- The previously sparse Medium land and XL land auto-selected cases clear the new density floors while preserving validation/package conversion.
- Existing default translated package breadth and replay gates remain green.
nonGoals:
- No exact HoMM3 object-table, art, or byte parity claim.
- No exhaustive all-template density sweep in this slice.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Tightened the auto-template batch report with size-aware generated/package object density floors; the new gate caught Medium land template 029 at 264 generated objects against a 340 floor before the fix.
- Added deterministic native catalog auto-selection density supplementation for underfilled auto-selected maps.
- Post-fix auto-template batch passed six seeded cases, including Medium 029 at 340 generated / 426 packaged objects and XL 051 at 1100 generated / 1196 packaged objects.
- Validation passed native build, auto-template batch report, default package object-only breadth report, medium authoritative replay report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-batch-validation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prove the new player-facing native catalog auto-selection path does not pick templates that only pass metadata filters but fail real native generation, package conversion, or replay-relevant surface checks across seeded size/water/player cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/native_random_map_auto_template_batch_report.tscn`
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- Auto-selection batch report uses empty template/profile generated configs with `native_catalog_auto` mode, not explicit size defaults.
- The batch proves selected template/profile ids are resolved, deterministic, supported by catalog metadata, and diverse across representative seeds.
- Every selected auto-template case passes native generation validation and package conversion surface sanity checks.
- If a selected catalog template fails runtime validation, selector/generator filtering is tightened instead of weakening the test.
nonGoals:
- No exact HoMM3 byte/output parity claim.
- No exhaustive 53-template CI sweep in this slice.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Added `NATIVE_RANDOM_MAP_AUTO_TEMPLATE_BATCH_REPORT`, which uses empty template/profile player configs with `native_catalog_auto` mode.
- Six representative seeded cases selected six distinct catalog templates: Small 049, Small 045, Medium 029, Medium Islands 001, Large 042, and XL 051.
- Every selected case resolved deterministic concrete template/profile ids, passed native generation validation, converted to a map package, and produced non-empty package object/road surfaces.
- The report records a remaining parity gap: several runtime-valid auto-selected templates still have `full_generation_status: not_implemented`, so future slices must harden broader translated-template behavior rather than treating this as production parity.
- Validation passed native build, auto-template batch report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-auto-template-selection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop player-facing generated maps from pinning one hardcoded recovered template/profile per size class. Wire launch-time generation to native catalog auto-selection so the imported HoMM3-style template catalog participates in seeded skirmish generation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing generated skirmish configs can request native catalog auto-selection without forcing the size-class default template/profile.
- Native normalization resolves an empty auto-selection config to a supported catalog template and coherent profile id, deterministically from seed/config.
- UI provenance clearly distinguishes preview defaults from launch-time native catalog auto-selection while keeping manual template/profile controls hidden.
- Existing explicit-template tests keep their pinned-template behavior for targeted regression cases.
- Validation proves auto-selection is used by the player-facing generated launch path and that generated maps still pass package/session adoption gates.
nonGoals:
- No claim that all 53 translated templates are fully HoMM3-equivalent.
- No manual template picker exposure in the first-view generated setup UI.
- No HoMM3 copyrighted asset/DEF import.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Player-facing generated launch config now requests `native_catalog_auto` selection while hidden preview controls still preserve size-class default provenance.
- Native config normalization resolves empty auto-selection configs to a deterministic supported catalog template and first matching catalog profile id.
- Generated setup/retry UX report proves the UI keeps manual template/profile controls hidden and launch provenance resolves a concrete native catalog template/profile.
- Explicit-template paths remain intact for size-default package replay/object-only breadth gates and all-template menu config construction.
- Validation passed native build, generated setup/retry UX, all-template menu wiring, package session replay, package object-only breadth, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-all-town-unguarded-route-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the uploaded Small H3M/native-package comparison to close the current generator gap where package gates protect player-start and cross-zone town routes but allow same-zone town pairs to remain reachable by short unguarded object-only paths.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner-uploaded Small 3-player H3M and native package evidence from 2026-05-06
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package topology reports expose all-town object-only reachable-pair counts, not only player-start and cross-zone town topology.
- Player-facing default translated Small, Medium, Large, and Extra Large package cases reject unguarded object-only town-to-town traversal across all town pairs.
- The uploaded Small H3M comparison continues to report the owner sample, the uploaded old native package, and current native Small 049 without committing uploaded evidence files.
- Generator changes preserve existing object count, guard count, road materialization, package replay, and validation gates for supported translated profiles.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/pathing parity claim.
- No broad recovered-template catalog sweep or runtime-authoritative promotion.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Uploaded Small H3M comparison reports the owner sample, the old uploaded native package, and current native Small 049; current Small 049 has 7 towns, 7 zones, 303 objects, 150 decorative obstacles, 40 guards, and zero object-only all-town reachable pairs.
- Package topology and breadth gates now expose and reject all-town object-only reachable pairs; the pre-fix Medium default case exposed 18 towns and 4 same-zone unguarded reachable town pairs.
- Default translated Medium now avoids optional density town stacking in already-towned zones and reports 6 towns with zero object-only all-town reachable pairs while preserving the owner Medium 001 comparison exemption.
- Validation passed native build, uploaded H3M topology report, package breadth/surface topology reports, full parity gate, owner spatial placement comparison, medium replay gate, repo validation, JSON validation, and diff whitespace check.

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
3. Confirm the selected slice has source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

Closed tactical slices:
- `document-model-reset-10184`
- `progress-tracker-regeneration-10184`

Future work in this phase should be limited to document/process corrections that preserve the `project.md` -> `PLAN.md` -> `ops/progress.json` chain.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

Closed tactical slice:
- `river-pass-proof-preservation-10184`

Future work in this phase should only reopen if manual proof is invalidated by regressions or if AcOrP requests a new proof scenario.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

Primary tracks:
- world and faction identity;
- concept-art direction and curation;
- economy/resource model;
- overworld object taxonomy and encounter representation;
- magic and artifact systems;
- animation/event cue foundations;
- strategic AI foundations;
- terrain/editor/tooling foundations;
- random map generator foundations;
- map/scenario document structure and persistence foundations;
- focused corrective/performance/instrumentation slices selected from real evidence.

Operational state lives in `ops/progress.json`. Completed parent/child evidence is intentionally not repeated here.

Selection rules for new Phase 2 slices:
- Tie the slice to a source doc, owner report, profile artifact, regression, or explicit AcOrP direction.
- Keep implementation targets narrow.
- Include explicit non-goals for save schema, generated-map density/content, renderer/fog behavior, object contracts, public UI, and asset ingestion when relevant.
- Preserve existing validation/analyzer compatibility unless the slice explicitly changes it.
- Do not use profile/instrumentation slices as permission for optimization or gameplay semantics changes.

Completed owner-directed implementation slice:

id: `decorative-blocker-distinct-sprite-assets-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up the decorative/blocker sprite foundation by replacing shared archetype reuse with one distinct generated sprite asset per authored decorative/blocker object while preserving the renderer/generator wiring and no-HoMM3-art boundary.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/decorative_object_sprites.json`
- owner correction on 2026-05-04 that all decorative/blocker objects need distinct assets, not only archetype coverage
implementationTargets:
- `art/overworld/runtime/objects/decorations/distinct/`
- `art/overworld/source/generated/decorations/distinct/`
- `art/overworld/source/trimmed/decorations/distinct/`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `tests/validate_repo.py`
- `tests/overworld_decorative_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- Exactly 200 authored decorative/blocker objects resolve to 200 distinct object asset ids.
- The 16 existing generated decoration sprites are preserved for 16 representative objects and the remaining 184 objects receive newly generated original sprites.
- Each distinct runtime sprite has source/provenance, manifest entry, trimmed source where applicable, and 512x512 runtime validation.
- Validation rejects asset reuse in the decorative/blocker object mapping and proves at least one generated decorative placement renders through a distinct object-specific sprite.
- No HoMM3 copyrighted art/DEF/image assets are imported.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no terrain replacement, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `decorative-blocker-sprite-asset-foundation-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Owner-directed generated-art ingestion slice for decorative/blocker overworld objects: audit renderer and native map-generator object surfaces, generate original 2D sprite assets for decorative/blocker objects lacking art, wire those assets through the overworld renderer/manifest, and validate that generated decorative/blocker objects are represented without relying only on procedural fallback markers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/concept-art-pipeline.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-content-batch-001b-biome-scenic-decoration-report.md`
- `docs/overworld-object-content-batch-001c-biome-blockers-edge-report.md`
- `docs/overworld-object-content-batch-001d-large-footprint-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- owner request on 2026-05-04 to generate sprites for decorative/blocker objects after checking renderer and map generator
implementationTargets:
- `art/overworld/runtime/objects/decorations/`
- `art/overworld/source/trimmed/decorations/`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- focused overworld visual/native decoration report tests as needed
- `ops/progress.json`
completionCriteria:
- Renderer and native map-generator decorative/blocker placement contracts are inspected and documented in the run evidence.
- Decorative/blocker objects lacking 2D assets are represented by generated original sprite assets or a documented, validated archetype mapping sufficient for every authored decorative/blocker object used by the renderer/generator.
- Generated sprite assets are committed only with provenance, runtime/source paths, manifest entries, and validation that files exist at expected dimensions.
- The overworld renderer can draw decorative/blocker map-object placements through mapped sprites while preserving procedural fallback for unmapped object types.
- No HoMM3 copyrighted art/DEF/image assets are imported.
- Validation covers manifest integrity, decorative/blocker asset mapping coverage, and at least one generated decorative/blocker runtime presentation path.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no full replacement of all terrain art, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-spread-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up `native-rmg-homm3-road-placement-parity-10184` by improving the residual owner-like road spread gap: more occupied 6x6 road cells and smaller largest coarse roadless land regions, while preserving count-close roads and reduced reward-road bias.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner follow-up after accfaf1 on 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count stays near owner and reward within 1/4 tiles does not materially regress toward the prior over-road-bias.
- Road nonempty 6x6 cells move closer to owner and largest roadless land 6x6 region is reduced from the accfaf1 baseline.
- Town/start coverage, route reachability, local distribution, land/water shape, guard/reward package adoption, and full parity fixture reports remain passing.
completionEvidence:
- Native owner-like output now adds bounded short service stubs in residual roadless land pockets through the native C++ road materialization path; the active runtime path remains `MapPackageService.generate_random_map()`.
- Road nonempty 6x6 cells moved from 10 to 17 against owner 16, and largest roadless land 6x6 region moved from 25 to 9 against owner 8; road tiles moved from 180 to 201 against owner 184, still below the pre-accfaf1 240 over-road count.
- Reward-road bias remains a documented residual warning rather than full parity: reward within 1 tile stayed 0.125, reward within 4 tiles moved 0.4632 to 0.4779 against owner 0.3727, and town/start road coverage stayed 1.0.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated packages committed, no road art lookup rewrite unless required, no HoMM3 asset import, no full parity claim.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-placement-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Improve native C++ RMG road layout parity for the owner-like translated medium islands case and general native templates by making route materialization more HoMM3-like: intentional trunk/branch roads, less over-connection, measured road/object interaction, and preserved start/town connectivity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count, land-normalized road density, reward distance-to-road ratios, road spread, road graph shape, and start/town coverage are reported against the owner H3M baseline.
- One bounded road placement/layout improvement lands without touching 4-neighbor road rendering, generated-map package commits, or copyrighted HoMM3 assets.
- Validation gates in the owner directive pass, and remaining exact HoMM3-re road-authoring gaps are stated.
completionEvidence:
- Native owner-like road materialization changed from fully materialized deterministic cross-links to a trunk/branch/short-spur policy for imported translated templates, preserving route graph reachability and road renderer lookup.
- Owner-like native road tiles moved from 240 before the slice to 180 against the owner H3M baseline of 184; reward references within 4 road tiles moved from 0.5588 to 0.4632 against owner 0.3727.
- Remaining exact HoMM3-re road authoring gap is documented; no full algorithm or byte parity is claimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated `.amap`/`.ascenario` files committed, no road renderer art/lookup rewrite unless required, no exact HoMM3-re algorithm/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-normalized-object-density-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Compare owner-attached HoMM3 H3M object/category density against native owner-like 72x72 islands output after the land/water fix, then correct one clear land-normalized sparse category without rerouting generation away from native C++.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a land-normalized density report that parses the owner H3M and reports total object, decoration/impassable, reward/resource, guard, town, other-object, and road density per 100 land tiles plus category mix and package surfaces.
- Native owner-like islands output now applies a bounded compact decoration-density supplement for the 72x72 translated Small Ring islands profile, raising total objects from 344 to 488 against owner 496 and decoration/impassable density from 0.330x to 0.804x owner after land normalization.
evidence:
- `tests/native_random_map_homm3_land_normalized_object_density_report.tscn`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-water-shape-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond spatial placement comparison by correcting native C++ owner-like 72x72 islands output that was mostly land, anchoring the owner H3M land/water baseline, and preserving generated gameplay/package surfaces on land.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Native islands terrain for non-structural-parity cases now shapes a water-dominant island mask after routes, objects, towns, and guards are known, protecting starts, roads, object body/visit/approach cells, town/guard cells, and converted package body/visit/block surfaces as land.
- The new report parses the owner H3M tile stream directly and verifies the native owner-like case moved from 4,900 land / 284 water to 2,296 land / 2,888 water against the owner baseline of 1,948 land / 3,236 water.
evidence:
- `tests/native_random_map_homm3_land_water_shape_report.tscn`
- `docs/native-rmg-homm3-land-water-shape-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re terrain-shape/placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-obstacle-identity-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond fill coverage by making native C++ RMG decorative obstacles carry terrain-biased HoMM3-re `rand_trn` source identity/proxy metadata and by adding an empirical comparison/diversity gate against the owner-attached 72x72 Small Ring baseline.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 72x72 Small Ring metrics from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `content/homm3_re_obstacle_proxy_catalog.json`
- `tests/native_random_map_homm3_re_identity_comparison_report.gd`
- `tests/native_random_map_homm3_re_identity_comparison_report.tscn`
- `tests/native_random_map_decoration_generation_report.gd`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ package generation remains the active path and decorative_obstacle records include HoMM3-re `rand_trn` source row/type/subtype/terrain/DEF-reference provenance plus original proxy family mapping.
- No HoMM3 copyrighted image/DEF assets are imported; source identity and DEF names are metadata/provenance only.
- The new report verifies the owner-attached gzip/decompressed H3M size baseline, compares owner parsed metrics against similar 72x72 islands Small Ring native output, reports counts by HoMM3 source type/source row/proxy family, and gates source-row/type diversity and terrain-biased presence.
- Broad seed/template quality sampling fails on low source-row diversity, missing terrain-biased source families, coverage regression, road/object density regression, or visually empty zone coverage regression.
- Existing catalog playability, fill coverage, menu wiring, decoration generation, and full parity fixture gates still pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no full HoMM3-re parity claim beyond the implemented source-identity/proxy and comparison gate, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-object-table-proxy-selection-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond native reward value tiers by making reward-bearing native C++ RMG object records carry HoMM3-re object/reward table source identity and select original proxy object families from a metadata-only proxy catalog.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `content/map_objects.json`
- `content/homm3_re_reward_object_proxy_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
implementation:
- Added a runtime-consumable reward/object proxy catalog with source type/name/subtype/source-row/DEF-reference provenance and original proxy mappings.
- Native `resource_site`, `mine`, `neutral_dwelling`, and `reward_reference` records now expose HoMM3-re source/proxy provenance and `provenance_only_original_proxy_art` policy.
- Reward proxy selection now maps minor, medium, major, and relic bands to different original proxy families/categories instead of only generic placeholder caches.
evidence:
- `tests/native_random_map_homm3_re_object_table_proxy_report.tscn`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-spatial-placement-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native C++ RMG parity work beyond density/count gates by parsing the owner-attached HoMM3 H3M for spatial object/road placement metrics, comparing them to owner-like native output, and reducing a clear native object-distribution skew.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a native spatial comparison report that decompresses the owner H3M, parses the 72x72 tile stream, 297 object definitions, 496 placed object instances, and 184 road tiles, then compares quadrant/coarse-grid density, nearest-neighbor distances, road adjacency, and largest low-content regions against native owner-like generation.
- Changed native non-town zone object placement for mines, dwellings, and rewards from anchor-ring clustering to deterministic coarse-grid scatter inside each owning zone, preserving start-support resource placement and native `MapPackageService.generate_random_map()` as the active path.
evidence:
- `tests/native_random_map_homm3_spatial_placement_comparison_report.tscn`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-guard-reward-package-adoption-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native RMG package parity by making generated package/editor surfaces preserve guard/reward relationships and object body/visit/block masks after native conversion and package save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
implementation:
- Native generated non-parity object placement now reserves materialized road cells before placing non-town objects, preventing reward/site blocking bodies from landing on road corridors.
- Native package conversion enriches generated object records with package body, visit, and block masks plus package occupancy roles.
- Protected rewards/sites now carry direct package guard links, guard references, guarded access requirements, guarded passability, and AI/pathing hints after convert/save/load.
- Guard records serialize as blocking package surfaces with neutral-stack passability metadata.
evidence:
- `tests/native_random_map_guard_reward_package_adoption_report.tscn`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/reward-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-reward-value-distribution-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond obstacle source identity by making native C++ RMG reward references derive values/categories from catalog zone treasure bands and by pairing valuable rewards with guard values scaled from protected reward values.
sourceDocs:
- `project.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
implementation:
- Native reward records now include zone value budget/tier, reward value tier, reward source bucket, HoMM3-re-like treasure-band low/high/density provenance, and reward index/target metadata.
- Native site guards scale from protected reward value and record guard/reward relation metadata; medium rewards reject distant fallback guards while major/relic rewards are required guarded content for the report scope.
- `tests/native_random_map_homm3_re_reward_value_distribution_report.tscn` samples small, medium, large, and XL templates and preserves road/object/fill/decor/package regression checks.
evidence:
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
- `ops/progress.json`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-fill-coverage-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a real HoMM3-style fill coverage gate and raise native generated package decorative/blocking body coverage so generated maps no longer pass with barren token decorations.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/map_objects.json`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 gzip and native `.amap`/`.ascenario` packages from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_fill_coverage_report.gd`
- `tests/native_random_map_homm3_fill_coverage_report.tscn`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated decorations use larger terrain-biased original blocker footprints and reserve full body tiles, not mostly 1x2 token records.
- The report compares HoMM3-re `rand_trn` obstacle catalog scale, authored AcOrP decoration/blocker catalog scale, attached pre-fix package fill, and sampled native small/medium/large/XL output.
- The attached 72x72 2.78% decoration/blocker body coverage package fails the new medium coverage floor, while the same config regenerated through native C++ package generation passes.
- Sampled native package convert/save/load surfaces retain road and object counts, and decorative bodies do not overlap materialized road cells.
- Exact HoMM3-re obstacle identity/art/template parity and compact binary format parity remain explicitly unclaimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re DEF/art/placement parity claim, no compact binary map format claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-catalog-playability-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native generated-map fallback architecture so every exposed local and translated catalog template uses imported topology and materializes visible roads, objects, decorations, towns, resources, rewards, and guards through native package convert/save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_catalog_quality_report.gd`
- `tests/native_random_map_catalog_quality_report.tscn`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated maps load catalog template zone and link data for all exposed templates where catalog records exist.
- Zone count, route edge count, road segments/cells, and object density scale from template topology and selected size instead of collapsing to the tiny foundation stub.
- Roads materialize into package/editor-visible terrain road surfaces after native convert/save/load.
- `decorative_obstacle`, town, mine/resource/reward/dwelling, and guard placements appear at sane scaled counts for sampled local, medium, large, and XL catalog templates.
- Existing tiny native full-parity fixture tests remain valid and do not define broad catalog quality.
- Broad catalog quality report, menu wiring report, decoration report, full parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re byte/placement/art/reward-table parity claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-template-decoration-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the full imported random-map template catalog into the generated skirmish menu and make native C++ GDExtension package generation emit real decorative obstacle placements.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_decoration_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Generated-map menu rules and UI expose all 56 catalog templates and 56 catalog profiles with template-scoped profile selection.
- Player-count options come from catalog template ranges/slots where available, with fallback only for missing catalog data.
- Active generated skirmish launch remains native `MapPackageService.generate_random_map()` package generation.
- Native object placements include scalable `decorative_obstacle` records with body, footprint, blocking, approach, and occupancy metadata.
- Menu wiring, native decoration generation, player-count/template filtering, full native parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no false whole-catalog/full HoMM3-re parity claim, no exact HoMM3 decoration art/family parity claim.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-warning-classification-followup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-a749da2 HoMM3 RMG visual fairness review by reducing remaining warning-level support-resource false positives and classifying accepted HoMM3-like template asymmetry separately from true unresolved regressions.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Visual preview artifacts and warning review identify each remaining warning-level fairness source after `a749da2`.
- Early support-resource diagnostics measure only actual start-support resource routes, not every same-zone mine or dwelling route.
- Reports preserve raw warning and fail-threshold counts while splitting accepted HoMM3-like template asymmetry from unresolved warning-level review items.
- Focused visual, richness, and large visual reports pass with fail-threshold diagnostics still strict.
nonGoals:
- No fairness-threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-support-resource-preview-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-43ab952 HoMM3 RMG parity by separating real warning-level fairness imbalance from acceptable translated-template asymmetry, correcting compact start-support resource drift where present, and adding human-inspectable rendered preview artifacts for manual layout review.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Current visual/richness/large artifacts are reviewed and warning-level fairness issues are classified without hiding or weakening diagnostics.
- Any real compact start-support resource route imbalance is corrected while preserving road coverage and HoMM3-like template asymmetry.
- Visual inspection produces rendered SVG/HTML preview artifacts suitable for manual map review in addition to ASCII/JSON.
- Focused visual/richness/large reports pass and progress tracking records validation/evidence.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-secondary-road-coverage-10184`
phase: `phase-2-deep-production-foundation`
purpose: Review post-fairness RMG road coverage after `ee6015c` and restore HoMM3-like major-object road richness where the route graph remains connected but visually under-roaded.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Visual artifact review distinguishes fairer path shortening from lost HoMM3-like major-object road coverage.
- Any added roads are grounded in source-backed road overlay timing after towns/mines/major objects and remain separate from fairness diagnostics.
- Visual and richness reports pass with no new fail-threshold fairness warnings and record road coverage/richness impact.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-route-resource-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce remaining translated-template route and resource distance unfairness after `random-map-homm3-parity-start-front-fairness-10184`, especially medium translated land templates whose strict diagnostics still exceed fail-threshold route spreads.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- RMG route/resource fairness behavior changes are grounded in translated template zone/link semantics rather than hidden diagnostics or relaxed thresholds.
- The cheap visual inspection report passes and records improved or no-worse total fail-threshold warning counts and distance spreads against the post-7689c3e baseline.
- Focused richness and large visual diagnostics pass or expose any remaining route/resource spread gaps clearly.
nonGoals:
- No fairness-threshold loosening unless an existing metric is proven wrong.
- No rendered asset ingestion, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-town-zone-spacing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG town placement quality by preventing generated start and neutral towns from reading as stacked or zone-collapsed, with deterministic spacing metrics across bounded seeds/templates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Town placement uses a stricter map-size-aware separation policy with a hard no-stack fallback before giving up on a town placement.
- Town/mine/dwelling validation reports all-town, start-town, and same-zone closest-pair spacing metrics.
- The bounded HoMM3 parity richness report validates the stronger spacing requirements across multiple seeds/templates within its runtime budget.
nonGoals:
- No generated terrain-art replacement work.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable town spacing improvement.

Completed owner-directed corrective slice:

id: `native-scenario-active-content-reset-10184`
phase: `phase-2-deep-production-foundation`
purpose: Archive the current native/authored scenario and campaign catalogs out of active player-facing selection while preserving generated random-map skirmish flow and historical compatibility records.
sourceDocs:
- `project.md`
- 2026-05-03 owner direction to clear native scenarios
implementationTargets:
- `content/scenarios.json`
- `content/campaigns.json`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/CampaignRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_scenario_load_smoke.gd`
completionCriteria:
- Authored/native scenario and campaign domains are marked archived/disabled.
- Skirmish and campaign browsers expose zero native authored entries.
- Generated random-map skirmish setup/load remains available and validated.
nonGoals:
- No RMG rewrite.
- No map package adoption.
- No save schema/version bump.
- No renderer, fog, pathing, gameplay, or asset-ingestion redesign.

Completed owner-directed implementation slice:

id: `native-rmg-disk-package-startup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make generated skirmish startup use native RMG package documents saved under `maps/` and loaded back from disk instead of authored `content/scenarios.json` or transient generated JSON scenario drafts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to remove JSON scenario startup and use native RMG packages under `maps/`
implementationTargets:
- `src/gdextension/include/map_document.hpp`
- `src/gdextension/src/map_document.cpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native `MapPackageService` saves and loads generated map and scenario packages enough for generated startup.
- Generated skirmish setup writes `.amap` and `.ascenario` packages under `maps/` in dev/headless and loads them back before session creation.
- Generated startup does not use `ContentService` generated drafts or `content/scenarios.json` as the active launch source.
- Maps directory policy is documented for dev `res://maps` and exported `user://maps` semantics.
- Focused Godot smoke proves native load, generation, package save, package load, disk-backed startup, and no active `scenarios.json`/draft usage.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump or full `SessionDelta` rewrite.
- No renderer, fog, pathing, or broad gameplay redesign.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `native-rmg-package-readable-filenames-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace opaque generated native RMG disk package filenames with deterministic, filesystem-safe, human-readable paired names under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner feedback that native RMG package filenames were dull/debug-sludge
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `tests/native_random_map_package_session_adoption_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Generated native RMG `.amap` and `.ascenario` packages share a readable deterministic base stem.
- The stem uses `size-creative-name-hash` only, with a user-facing size token, a deterministic creative lowercase kebab name derived from normalized seed/config, and an 8-hex deterministic config hash suffix.
- Template/profile/player-count/water-mode/dimensions/hash details stay in package metadata/refs, not the filename.
- Focused native disk-package startup tests assert the corrected shape, reject old debug-name identity parts, and prove package refs/load behavior still work.
nonGoals:
- No native API, C++ document, save-version, authored catalog, renderer, fog, pathing, or gameplay semantics changes.

Completed owner-directed implementation slice:

id: `maps-folder-package-browser-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Populate skirmish and map editor selection flows from generated `.amap`/`.ascenario` package pairs under `maps/` instead of authored JSON scenario records.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to populate skirmish and map editor from generated maps-folder packages
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
completionCriteria:
- A generated maps-folder package index discovers paired `.amap`/`.ascenario` files under the active maps directory and returns readable records with package refs/metadata.
- Skirmish browser entries are built from generated disk package pairs, handle an empty maps folder gracefully, and start sessions by loading the selected package paths.
- Map editor can list and open generated package pairs from `maps/` without `content/scenarios.json` or transient generated draft registration.
- Focused Godot smoke proves package listing, package-backed skirmish launch, map editor package access/open, sane empty-directory behavior, and no authored JSON scenario path for generated package launch/open.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, or RMG generation semantics changes.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `map-editor-load-map-package-ui-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the Map Editor's active old JSON scenario dropdown path with an explicit Load Map flow backed only by generated `.amap`/`.ascenario` package pairs under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to make the map editor load maps from maps-folder packages instead of old JSON scenarios
implementationTargets:
- `scenes/editor/MapEditorShell.gd`
- `scenes/editor/MapEditorShell.tscn`
- `tests/map_editor_load_map_package_report.gd`
- `tests/map_editor_load_map_package_report.tscn`
- `tests/validate_repo.py`
completionCriteria:
- The active Map Editor top-bar flow says `Load Map` and lists generated map package entries from `maps/`.
- The active editor load path uses paired `.amap`/`.ascenario` refs and paths, and creates a package-backed editor working copy.
- Old authored JSON scenario loading is removed from the active editor UI and kept only behind explicit legacy/dev validation naming.
- Empty, invalid-pair, and failed-load states use map-package copy rather than scenario-dropdown copy.
- Focused Godot smoke proves package entries, package refs/paths, no authored JSON scenario/draft registration, and no old scenario dropdown copy in the active flow.
nonGoals:
- No skirmish browser behavior change beyond preserving the shared maps-folder package helper.
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, RMG generation, or asset-ingestion changes.

Completed owner-directed implementation slice:

id: `generated-grastl-runtime-terrain-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the committed generated `grastl` grass terrain replacement frames into the overworld terrain runtime path instead of leaving them unused.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-03 owner directive to load/use generated grastl frames under `art/overworld/runtime/terrain_tiles/generated/grastl/frames_64/`
implementationTargets:
- `content/terrain_grammar.json`
- `scripts/autoload/ContentService.gd`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/generated_grastl_runtime_asset_report.gd`
- `tests/generated_grastl_runtime_asset_report.tscn`
- `tests/overworld_visual_smoke.gd`
- `tests/validate_repo.py`
completionCriteria:
- Grass/grastl terrain runtime asset resolution points at the generated `frames_64` resource directory.
- The overworld map view can resolve generated grastl frame paths while preserving existing terrain selection behavior for other atlases and roads.
- Godot import sidecars exist for the 79 generated grastl frame PNGs.
- Focused validation proves all 79 generated frame resources exist/load and a runtime grass tile resolves through the generated grastl frame bank.
validation:
- `godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/generated_grastl_runtime_asset_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or non-grass terrain atlas redesign.
- No new generated asset ingestion beyond the already committed grastl `frames_64` replacement trial frames.

Selected owner-directed workflow slice:

id: `generated-terrain-classes-runtime-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add the tracked workflow and deterministic scaffolding needed to generate original replacement runtime terrain tiles for every remaining terrain class after `grastl`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/generated-terrain-class-replacement-workflow.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-04 owner directive to continue the grastl workflow for `dirttl`, `lavatl`, `rocktl`, `rougtl`, `sandtl`, `snowtl`, `subbtl`, `swmptl`, and `watrtl`
implementationTargets:
- `docs/generated-terrain-class-replacement-workflow.md`
- `tools/generated_terrain_atlas_tool.py`
- `art/overworld/runtime/terrain_tiles/generated/<class>/source_sheets/`
- `art/overworld/runtime/terrain_tiles/generated/<class>/previews/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A new tracked child slice exists for the remaining generated terrain class replacement workflow and is active in `ops/progress.json`.
- The workflow explicitly lists `dirttl` 46, `lavatl` 79, `rocktl` 48, `rougtl` 79, `sandtl` 24, `snowtl` 79, `subbtl` 79, `swmptl` 79, and `watrtl` 33.
- Deterministic tooling can pack original reference frames into 1024x1024 16x16 magenta-padded atlases, validate/cut later generated 1024 atlases into exact 64x64 class frames, force unused cells to magenta, and produce previews without calling image generation.
- Repo-owned original reference 1024 atlases and previews exist for every listed remaining class.
- Validation includes JSON validation, reference pack dry-run/generation, script syntax validation, `sync-plan` dry-run when available, and `git diff --check`.
validation:
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --dry-run`
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --force`
- `python3 -m py_compile tools/generated_terrain_atlas_tool.py`
- `python3 -m json.tool ops/progress.json`
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan --dry-run /root/dev/heroes-like`
- `git diff --check`
nonGoals:
- No image generation calls from this worker or repo tooling.
- No runtime replacement frame ingestion for non-`grastl` terrain classes until generated candidates exist and pass validation.
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or unrelated renderer redesign.

Selected Phase 2 corrective slice:

id: `native-gdextension-editor-manifest-correction-10184`
phase: `phase-2-deep-production-foundation`
purpose: Fix GDExtension library feature selection so Godot editor/headless smokes load the native Debug library on Linux and Windows instead of falling back to the GDScript compatibility shim.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner report that Windows Godot 4.6.2 headless selects `windows.editor.x86_64`
implementationTargets:
- `src/gdextension/map_persistence.gdextension`
- `src/gdextension/map_persistence.gdextension.in`
- `src/gdextension/README.md`
- `scripts/build_map_persistence_windows.bat`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Linux and Windows editor/headless manifest entries point to the Debug native library.
- Existing debug/release template entries remain intact for export/template builds.
- Windows helper/docs explain that headless/editor smokes use the editor entry and Debug-only builds are sufficient for smokes.
- Linux native rebuild plus native package and RMG smokes still load the native extension.
nonGoals:
- No native API, RMG, gameplay, save, content, package, renderer, fog, pathing, or adoption semantics changes.
- No unsupported macOS library paths.

Selected Phase 2 planning slice:

id: `map-scenario-gdextension-persistence-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the current loose JSON/dictionary map and scenario persistence model with a planned typed map/scenario document architecture, likely backed by a C++ Godot GDExtension, before broad generated-map or scenario production depends on it.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction and RMG/save-path inspection
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd` generation/export boundary
- `scripts/core/ScenarioSelectRules.gd` generated-skirmish setup boundary
- `scripts/core/ScenarioFactory.gd` scenario/session bootstrap adapters
- `scripts/core/SessionStateStore.gd` session save reference/delta boundary
- `scripts/autoload/ContentService.gd` authored/generated scenario loading boundary
- `scripts/autoload/SaveService.gd` save/load JSON hot path
- `content/scenarios.json` split/manifest migration plan
- future `src/gdextension` or equivalent C++ map package module
baselineChecks:
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`
- focused generated-map save/load, scenario-load, and RMG validation smokes selected at kickoff
sliceEvidence:
- Current RMG returns nested Dictionary payloads with `scenario_record`, `metadata`, `staging`, validation, and provenance instead of a typed map object.
- Generated skirmish sessions are memory/session-oriented and preserve no-authored-writeback boundaries rather than producing durable first-class map assets.
- Authored scenarios are bundled in large JSON content records under `content/scenarios.json`.
- `SaveService._save_raw_dictionary()` serializes full save payloads with `JSON.stringify(payload, "\t")` and writes raw JSON strings through `FileAccess`.
- A Small 36x36 generated-map profile wrote about 6.95 MB JSON and took roughly 202-219 ms in the save path, so larger generated maps will amplify the problem.
completionCriteria:
- A typed map/scenario document model is defined with stable ids, schema/version, metadata, terrain/layers, object placements, route/validation data, and generated provenance boundaries.
- A durable map package approach is selected for authored and generated maps, including load, validate, save, migrate, and corruption/tamper handling.
- Runtime saves are redesigned to reference immutable map packages by id/hash/version and store only mutable session deltas where practical.
- `content/scenarios.json` has a migration plan toward an index/manifest plus separate map/scenario package files.
- RMG bridge/export sequencing is defined so existing GDScript generation can emit/import the new format before any full C++ generator rewrite is attempted.
- Backward compatibility, rollback, validation scenes, and performance acceptance gates are named before implementation starts.
nonGoals:
- No immediate coding or coding-agent implementation during planning refinement.
- No breaking existing saves or authored scenarios without an explicit migration slice.
- No full RMG rewrite as the first step.
- No renderer/fog/pathing/gameplay semantics changes unless separately selected.
- No production content migration without provenance, rollback, and validation evidence.

Selected Phase 2 child implementation slice:

id: `native-rmg-gdextension-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Start the native RMG port as a narrow C++ GDExtension foundation: API surface, deterministic minimal config/seed identity, and an empty generated `MapDocument` smoke result.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction to begin the native RMG port without gameplay adoption
implementationTargets:
- `src/gdextension/include/map_package_service.hpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/persistence/MapPackageService.gd`
- `tests/native_random_map_foundation_report.gd`
- `tests/native_random_map_foundation_report.tscn`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native API exposes minimal random-map config normalization, deterministic config identity, and `generate_random_map(config)` foundation behavior.
- Same config/seed produces the same identity and changed seed changes identity.
- Returned generation status is explicitly `partial_foundation` with full generation `not_implemented`.
- Existing GDScript RMG runtime flow remains authoritative and untouched.
- Existing native map package smoke and new native RMG foundation smoke pass after Linux native rebuild.
nonGoals:
- No full RMG rewrite.
- No `RandomMapGeneratorRules.gd` call-site replacement.
- No `ScenarioSelectRules.gd` runtime generation flow change.
- No package adoption, save version bump, authored content migration, generated authored writeback, renderer/fog/pathing/gameplay semantic change, or fake parity claim.

Native RMG parity track:

The native C++ GDExtension RMG must reach functional parity with the current GDScript source of truth in `scripts/core/RandomMapGeneratorRules.gd` before any gameplay adoption. The practical breakdown is:

- `native-rmg-terrain-grid-generation-10184`: deterministic normalized config, terrain/biome palette, width/height/level tile grid, terrain ids/codes, stable signatures, and terrain-grid smoke while preserving `partial_foundation`.
- `native-rmg-zone-player-starts-10184`: deterministic foundation player constraints, assignment metadata, runtime fallback zones, zone seed layout, owner grid, zone bounds/terrain association, start anchors, start spacing metadata, and status/signature reporting.
- `native-rmg-road-river-network-10184`: route/corridor graph, road overlays, river/water/underground transit records, and reachability proof surfaces.
- `native-rmg-object-placement-foundation-10184`: resource/reward/decor/object staging, footprint predicates, occupancy, and deterministic object placement records.
- `native-rmg-town-guard-placement-10184`: primary/neutral towns, mines, dwellings, route guards, border guards, monster/reward bands, and guard pressure records.
- `native-rmg-validation-provenance-parity-10184`: validation reports, phase pipeline, stable signatures, generated provenance, no-authored-write policy, and warning/failure parity.
- `native-rmg-gdscript-comparison-harness-10184`: headless comparison fixtures proving native/GDScript structural parity across supported seeds, sizes, water modes, underground, and player counts.
- `native-rmg-package-session-adoption-10184`: package/session integration behind explicit feature-gated adapters for native output; no save version bump or call-site replacement.
- `native-rmg-full-parity-gate-10184`: final tracked gate proving terrain, objects, roads, rivers, towns, guards, zones/player starts, validation/provenance, comparison harness, package/session integration, Linux, and Windows for the supported 36x36 `homm3_small` comparison profiles before any runtime call-site adoption.

With `native-rmg-full-parity-gate-10184` complete, native RMG may claim full
parity only for the supported tracked comparison profiles. Unsupported native
configs remain incomplete, and `RandomMapGeneratorRules.gd` remains
authoritative for live generated skirmish gameplay until a later explicit
runtime adoption slice changes the call sites.

Known Phase 2 parent tracks already represented in progress history:
- `world-faction-identity-implementation-bridge-10184`
- `concept-art-curation-gate-10184`
- `economy-resource-foundation-implementation-10184`
- `overworld-object-encounter-foundation-implementation-10184`
- `magic-system-foundation-implementation-10184`
- `artifact-system-foundation-implementation-10184`
- `animation-event-cue-foundation-implementation-10184`
- `strategic-ai-foundation-continuation-10184`
- `terrain-editor-tooling-foundation-implementation-10184`
- `random-map-generator-foundation-10184`
- `map-scenario-gdextension-persistence-foundation-10184`

Selected owner-directed corrective slice:

id: `random-map-homm3-parity-richness-corrective-10184`
phase: `phase-2-deep-production-foundation`
purpose: Re-audit generated-map output against owner-visible HoMM3-style RMG expectations and improve concrete generated-map richness where maps still look sparse or structurally wrong.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/random-map-final-homm3-parity-regate-audit.md`
- `docs/random-map-xl-template-alignment-audit.md`
- 2026-05-04 owner directive that generated maps are still not close enough to HoMM3-style RMG
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- focused RMG report/test scenes under `tests/`
- `.artifacts/` generated-map inspection reports/previews when practical
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Multiple deterministic generated-map seeds/templates/sizes are inspected with human-readable evidence.
- Generated maps enforce stronger town spacing/zone placement constraints.
- Roads, rivers where terrain/template policy supports them, movement-shaping blockers/decorations, artifacts/rewards, and guards are generated at visible HoMM3-style densities.
- Validation checks road/river presence or explicit unsupported policy, minimum town distance, blocker/decor density, artifact and guard counts/association, template richness metrics, and native/package startup regressions.
- Remaining parity gaps are explicitly tracked as follow-up instead of being hidden behind a parity claim.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, or broad renderer/fog/pathing redesign unless required by focused validation.
knownFollowUp:
- `translated_rmg_template_002_v1` remains a poor/failing translated template under 72x72 inspection because start viability and decoration route-blocking constraints fail; track a separate template-structure corrective before using it as positive parity evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-bounded-inspection-footprints-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make the HoMM3-style RMG richness inspection reliable in headless runs and improve generated-map blocker footprint parity using real HoMM3 RMG object/passability evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `fa45218`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection previews/reports
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The richness report runs bounded multi-map headless inspections and exits with clear JSON/report output.
- Multiple deterministic seeds/templates include roads, river/water candidates, town spacing, artifacts, guards, decorative blocker density, multi-tile blocker footprint, and object writeout metrics.
- Decorative obstacles use terrain-family passability/body masks instead of all blockers being one-tile placeholders, while route safety remains validated.
- Generated inspection artifacts are written under ignored repo `.artifacts/` or workspace artifacts, not untracked `maps/`.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-guarded-artifact-pairing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG reward semantics by making materialized artifacts explicitly consume nearby object guards before lower-priority filler guards, and prove the pairing in bounded richness reports.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `3b7fc04`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection reports/previews
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Object guard materialization deduplicates artifact reward candidates and prioritizes artifact guards before lower-priority mine, dwelling, and cache guards.
- Guard records carry explicit guarded-object point, distance, adjacency, and placement-id association metadata.
- Bounded richness report includes direct guarded-artifact coverage, missing-count, adjacency, and max-distance metrics across the existing multi-template cases without exceeding the runtime budget.
- Focused RMG report and repository validation pass, and remaining parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-connection-road-controls-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG road quality by making template connection `Value`, `Wide`, and `Border Guard` semantics visible and validated in generated road overlays instead of measuring only road tile counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- 2026-05-04 owner directive to continue RMG parity after `e20d96c`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Generated road overlays carry explicit connection-control markers for normal guarded links and border-guard links.
- Wide links preserve guard-suppressed road semantics without creating normal connection controls.
- Bounded richness metrics validate connection-control coverage, wide route semantics, and special border-guard gate roads across multiple seeds/templates.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-blocker-choke-shaping-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG movement texture by making decorative obstacle filler measurably shape route shoulders and chokepoints instead of only proving global decoration/blocker density.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.csv`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Decorative obstacle candidate scoring accounts for required road/corridor shoulder pressure while preserving path safety.
- Generated decoration records and validation expose movement-shaping metrics for road-adjacent blocker bodies, covered required routes, and choked road tiles.
- Bounded richness report validates route/choke blocker coverage across multiple seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable movement-shaping improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-river-crossing-quality-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG river overlay quality by making land river candidates continuous, body-safe, and measurably crossed by generated roads instead of only counting river candidates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_roads_rivers_writeout_report.gd`
- `ops/progress.json`
completionCriteria:
- Land river candidates are generated as continuous ordered overlay paths that avoid object bodies while allowing explicit road bridge/ford crossing cells.
- Road/river writeout exposes river continuity, body-conflict, isolated-fragment, and road-crossing metrics.
- Bounded richness metrics validate coherent river candidates and road crossing coverage across the selected land/island seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable river/crossing quality improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-zone-richness-bands-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG template richness by ensuring non-connector zones carry measurable economy, treasure-band, guard, decoration, and reward coverage instead of hiding poor zones behind whole-map aggregate counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Runtime zone metadata applies a conservative richness floor only where mine/resource requirements, treasure bands, or monster policy are missing or empty.
- Bounded richness metrics report per-zone richness minimum, poor zone count, object category coverage, reward-band source/fallback counts, value bands, and template variability across multiple seeds/templates.
- Focused richness validation passes within its runtime budget with zero poor eligible zones and no reward-band fallback in the selected cases.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No claim of full HoMM3 RMG parity beyond this measurable zone richness and reward-band improvement.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-visual-inspection-evidence-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add bounded multi-map visual/ASCII/JSON inspection evidence across more seeds, templates, and sizes so RMG parity work does not hide remaining quality gaps behind aggregate richness counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `2ba8fa5`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The report samples multiple deterministic seeds/templates/sizes with bounded runtime and writes human-inspectable ASCII/JSON artifacts under ignored `.artifacts/`.
- Strict positive cases remain green while diagnostic translated-template probes record remaining quality gaps without pretending full parity.
- The tracked gap note records that ASCII/JSON inspection is evidence only and does not complete rendered visual parity, large-template repair, native RMG parity, or asset ingestion.
- Focused RMG reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this inspection evidence and any explicitly fixed concrete gap.

Completed owner-directed corrective slice:

id: `random-map-homm3-parity-visual-diagnostic-runtime-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the bounded RMG visual inspection evidence after `be744e8` by reducing route-heavy translated-template probe cost, separating strict fixture budgets from capped diagnostic probe budgets, and replacing misleading grass-run summary metrics with marker-distribution evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `be744e8`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Route-heavy translated visual probes avoid unnecessary whole-grid path searches where direct or bidirectional route search is sufficient.
- Strict positive fixtures remain on the existing per-case runtime bar, while diagnostic translated-template probes have explicit capped evidence budgets and still report strict-budget overruns as notes.
- Visual summary and matrix expose marker row/column/quadrant coverage and per-route timing so grass terrain runs are not mistaken for blank-map quality failures.
- Focused visual/richness reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this bounded report/runtime correction.

Completed owner-directed follow-up slice:

id: `random-map-homm3-parity-large-visual-diagnostic-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a separate bounded visual diagnostic path for excluded large translated RMG templates, starting with `translated_rmg_template_042_v1` at 108x108, without making the cheap visual gate hang.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `41233b1`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_large_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The existing cheap visual gate keeps its 36x36/72x72 case set and runtime bounds.
- A separate large report mode inspects one deterministic 108x108 `translated_rmg_template_042_v1` case with explicit total and diagnostic per-case budgets.
- Large-template quality gaps are reported as diagnostic gaps with limit 0 for this focused evidence path; strict-budget overruns remain diagnostic notes.
- Focused large/cheap visual reports, richness report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded large-template diagnostic evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-large-layout-quality-metrics-10184`
phase: `phase-2-deep-production-foundation`
purpose: Surface the source-backed large-template fairness/layout quality warnings that are currently present in validation output but hidden from the visual diagnostic matrix and compact metrics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- 2026-05-04 owner directive to continue RMG parity after `6c14f35`
implementationTargets:
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Large/visual inspection metrics expose fairness status, warning counts, fail-threshold warning counts, contest-route distance spread, contest-guard pressure spread, route-guard pressure spread, and town-to-resource distance spread from the existing source-backed fairness report.
- The visual matrix and JSON summaries make large layout-quality warnings visible without changing generator route, object, guard, terrain, save/load, renderer, or runtime semantics.
- The gap note records the newly visible large-template layout warning evidence and identifies layout correction as a separate next slice before strict promotion.
- Focused large visual report, cheap visual report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No route/pathing, zone layout, guard pressure, object placement, content density, save-version, native generator, renderer, fog, or gameplay behavior change.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this clearer diagnostic evidence.

Selected owner-directed implementation slice:

id: `native-rmg-homm3-local-distribution-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native C++ owner-like 72x72 islands output after the land/water and land-normalized density fixes so local interactive placement has fewer barren land windows and fewer oversized piles while preserving small guarded reward clusters.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner screenshots from 2026-05-04 showing desolate regions and localized piles after commit `ed0dad2`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_local_distribution_report.gd`
- `tests/native_random_map_homm3_local_distribution_report.tscn`
- `docs/native-rmg-homm3-local-distribution-report.md`
- `ops/progress.json`
completionCriteria:
- Active native package generation through `MapPackageService.generate_random_map()` remains the only runtime path touched; generation is not rerouted to `scripts/core/RandomMapGeneratorRules.gd`.
- The new report measures local empty-window, pile concentration, window density spread, and nearest-neighbor metrics separately for decorations, interactive rewards/sites, guards, and guarded packages on the owner-like 72x72 generated/native case.
- Native interactive object placement uses deterministic coarse-grid/spacing scoring so non-decorative objects distribute across eligible zone/land windows while guarded reward packages remain compact local pairs, not large piles.
- Existing guard/reward package adoption, road non-conflict/connectivity, source identity/proxy metadata, land/water shape, fill coverage, catalog/menu wiring, decoration generation, and full-parity gates still pass.
nonGoals:
- No generated `.amap`/`.ascenario` commits under `maps/`.
- No copyrighted HoMM3 art/assets, exact HoMM3 byte/object-table/art parity, or full parity claim.
- No save-version bump, authored scenario adoption, renderer/fog rewrite, generated terrain-art ingestion, or route back to old GDScript RMG.

Selected owner-directed implementation slice:

id: `random-map-homm3-parity-start-front-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce the largest newly exposed RMG layout fairness warnings by classifying comparable primary contest/early fronts per active player start from translated template connections, without weakening guard/resource/distance diagnostics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- 2026-05-04 owner directive to continue RMG parity after `cf52aa9`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_richness/`
- `.artifacts/rmg_parity_visual_inspection/`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Translated template connections keep their source guard payloads and required route materialization, including wide and border-guard semantics.
- Layout fairness classifies one deterministic primary contest/early front per active player start, preferring active-opponent fronts and then lower-pressure neutral fronts, so duplicate links and inactive owner-slot links do not inflate one player's comparable start-front pressure.
- Fairness diagnostics remain strict and continue reporting remaining route/resource/guard spread warnings after the corrected primary-front model.
- Richness, visual, large visual if reasonable, JSON/progress sync, diff check, and repository validation pass or any skipped validation is recorded with a concrete reason.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, renderer, fog, pathing, or gameplay loop redesign.
- No promotion of large translated templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded start-front fairness correction.

### Phase 3 - HoMM3-Style Random Map Generator Rework

Goal: rework native random map generation around the recovered HoMM3 RMG execution model, while translating all output into original game content and keeping exact byte/art parity out of scope.

Active tactical slices:

id: `native-rmg-broad-translated-catalog-structural-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop treating recovered translated land/surface catalog templates that already pass generation, validation, package conversion, route-closure, and package-surface topology gates as `not_implemented`; give them a bounded structural-support status that remains non-authoritative and explicitly not full HoMM3 parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `src/gdextension/src/map_package_service.cpp`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Eligible recovered translated land/surface templates report a non-`not_implemented` structural-support full-generation status only when generated through catalog template/profile ids, land water mode, and one native surface level.
- Broad template generation/package report fails if any attempted eligible translated land/surface template remains `not_implemented`.
- Package/session adoption stays feature-gated and non-runtime-authoritative for broad structurally supported templates.
- Owner-compared defaults keep their stronger owner-compared statuses and full-parity gates continue to reject full HoMM3 parity claims.
- Legacy compact foundation tests and unsupported islands/underground controls remain blocked or scoped as before.
nonGoals:
- No broad owner-H3M comparison claim.
- No exact HoMM3 byte/art/DEF parity.
- No runtime-authoritative promotion for broad catalog templates.
- No underground or general islands production support.
completionEvidence:
- Full unbounded broad template generation report passed all 56 eligible land/surface templates with zero skipped templates, zero translated `not_implemented` statuses, full-generation status counts `{not_implemented: 2, scoped_structural_profile_not_full_parity: 1, owner_compared_translated_profile_not_full_parity: 4, translated_catalog_structural_profile_not_full_parity: 49}`, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Focused `translated_rmg_template_044_v1` rerun passed after classifying direct town-spacing pressure as broad-catalog parity debt while keeping package route closure hard-gated.
- Full parity boundary, package object-only breadth, package/session authoritative replay, random-map menu wiring, player setup retry UX, foundation, and town-spacing regression reports passed.
- Native extension rebuild passed after the C++ support-boundary and validation changes.

id: `native-rmg-owner-medium-001-road-shape-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Continue the owner-uploaded medium 001 comparison work by correcting the remaining road-shape gap after category counts, town-road topology, and content clustering were brought into owner-relative gates. The owner-relative spatial gate now covers quadrant unevenness instead of accepting road count alone.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- owner-uploaded 72x72 H3M comparison evidence from 2026-05-06
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `ops/progress.json`
completionCriteria:
- Owner-medium translated template 001 keeps the corrected category counts, town-road connections, road branch/endpoint topology, and content clustering gates passing.
- Native owner-medium road quadrant/coarse-grid shape moves materially toward the uploaded H3M instead of remaining evenly distributed across all quadrants.
- Any new road-shape gate is owner-relative and does not accept road count alone as a proxy for HoMM3-like road layout.
- Small 049 package topology, uploaded-small comparison, choke, startup, repo validation, JSON validation, and diff hygiene remain passing.
completionEvidence:
- Owner-medium 001 route materialization remaps northeast-quadrant road cells into the southern service band and prevents branch/service-stub growth from repopulating the owner H3M's mostly empty northeast road quadrant.
- Owner-medium spatial comparison passed with no warnings: native road quadrants `[39, 4, 58, 87]` versus owner `[41, 0, 51, 92]`, road_quadrant_cv_delta `-0.07`, road_tile_delta `+4`, road_grid_nonempty_delta `+3`, largest_roadless_land_region_delta `0`, road_endpoint_delta `+3`, and road_branch_delta `0`.
- Package object-only breadth, full-parity boundary, and authoritative replay reports passed after the road-shape correction; owner Medium islands remains owner-compared runtime-supported without any full HoMM3 parity claim.
- Uploaded Small H3M comparison/topology reports still pass with current Small 049 output at 7 towns, 303 package objects, 150 decorative obstacles, 40 guards, zero object-only town routes, and loaded package roads close to the owner sample.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No exact byte-level road parity claim.
- No broad generator rewrite outside this owner-medium road-shape correction.
- No save-version bump or runtime-authoritative package/session promotion.

id: `native-rmg-uploaded-small-topology-evidence-gap-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Convert the owner-uploaded single-level Small 3-player H3M comparison into a repeatable local topology audit that parses the uploaded H3M evidence when present and compares it to current native translated Small 049 package output beyond aggregate counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` local untracked owner evidence
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `tests/native_random_map_zone_choke_regression_report.gd`
implementationTargets:
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn`
- `ops/progress.json`
completionCriteria:
- The audit parses the local uploaded H3M object templates, placed object records, passability/action masks, town positions, guard records, and road cells without committing the uploaded `.h3m`.
- Current native Small 049 package output is compared against the parsed owner evidence for town count, nearest-town distance, object categories, guard count, road cells, blocker surfaces, and unresolved town-pair topology.
- The report distinguishes hard regression gates from remaining HoMM3-style parity gaps, especially native reliance on terrain rock barriers rather than object-mask-only obstacle chokes.
completionEvidence:
- Uploaded Small parses as 36x36x1 SoD, 7 towns, 303 objects, 150 decorations, 40 guard records, 76 reward/resource records, 30 other objects, 110 road cells, and 722 object-mask blocked tiles.
- Current native translated Small 049 with the comparison seed produces 7 towns, nearest town distance 10, 303 objects, 150 decorative obstacles, 40 guards, 76 mine/resource/reward objects, 30 scenic objects, 105 road cells, zero duplicate/empty road records, and zero unresolved reachable town pairs.
- Remaining gap is explicit: native currently needs 375 rock terrain barrier tiles plus object blockers to close the topology, so it is not yet an object-mask/guard-only HoMM3-style choke materialization.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No generator behavior change in this evidence slice.
- No exact H3M pathing/byte parity claim from the local parser.

id: `native-rmg-small-object-choke-materialization-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Follow the uploaded Small topology audit by moving current Small 049 package choke closure from terrain-only reliance toward object-surface blocker materialization: decorative obstacle masks must close the town topology even when terrain rock barriers are ignored.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner-uploaded Small 3-player H3M comparison evidence
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Native translated Small 049 keeps owner-like aggregate counts, road cells, town distance, and package topology gates.
- The uploaded Small topology report fails if native object blockers alone allow any reachable town pair when terrain rock blockers are ignored.
- Compact decorative obstacle placement is biased toward owner-grid zone-boundary choke cells, and package decorative obstacle masks materialize nearby land-boundary choke cells without adding generated object records.
- Remaining terrain-rock serialization is reported as a residual warning rather than silently treated as HoMM3-style object-mask parity.
completionEvidence:
- Object-only reachable town pairs moved from 6 before this slice to 0 after boundary-biased compact decoration and decorative package choke masks.
- Native Small 049 still produces 7 towns, nearest town distance 10, 303 objects, 150 decorative obstacles, 40 guards, 105 road cells, zero empty/duplicate road records, and zero unresolved reachable town pairs.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No broad removal of terrain rock boundary serialization in this slice.
- No exact H3M pathing or byte parity claim.

id: `native-rmg-package-object-only-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Follow the Small object choke materialization by hardening the converted/saved/loaded native package surface gate: package object masks alone must close Small 049 town topology without relying on terrain rock blockers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_surface_topology_report.gd`
- owner-uploaded Small 3-player H3M comparison evidence
implementationTargets:
- `tests/native_random_map_package_surface_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Converted and loaded Small 049 package surfaces still preserve recovered template provenance, owner-like counts, roads, town spacing, and no empty/duplicate road records.
- The package surface report computes object-only blocker topology separately from terrain-plus-object topology.
- Converted and loaded package surfaces fail if object masks alone allow any unguarded start-town or cross-zone town route.
- The gate remains explicit that this proves Small 049 package topology only, not broad HoMM3 RMG parity or exact H3M byte/pathing parity.
completionEvidence:
- `tests/native_random_map_package_surface_topology_report.gd` now computes `object_only_start_town_topology` and `object_only_cross_zone_town_topology` separately from terrain-plus-object topology for both converted and loaded package surfaces.
- The package surface report passes with converted and loaded Small 049 packages at 7 towns, 303 objects, 40 guards, 104 unique road tiles, zero empty/duplicate roads, 1000 object-only blocked tiles, 3 checked player-start town pairs, 21 checked cross-zone town pairs, and zero object-only reachable pairs.
nonGoals:
- No C++ behavior change unless the strengthened package-surface gate exposes a regression.
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No runtime-authoritative package/session promotion.

id: `native-rmg-default-size-object-only-breadth-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Broaden object-only package topology validation from the uploaded Small 049 case to the player-facing default translated templates for Small, Medium, Large, and Extra Large maps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.tscn`
- `ops/progress.json`
completionCriteria:
- The report generates, converts, saves, and reloads each player-facing default size-class template.
- Converted and loaded package surfaces fail if object masks alone allow unguarded cross-zone town traversal.
- Each case preserves at least the expected player-start towns, package object records, guard records, and non-empty roads.
- Any unsupported or still-not-HoMM3-equivalent status remains reported rather than promoted to broad production parity.
completionEvidence:
- `tests/native_random_map_package_object_only_breadth_report.tscn` passes for the player-facing default Small 049, Medium 002, Large 042, and Extra Large 043 translated templates through generate, package convert, save, and reload.
- Converted and loaded package surfaces report zero object-only reachable cross-zone town pairs for all four default size-class templates.
- Small 049 package surface still passes the focused package topology report at 7 towns, 303 objects, 40 guards, and no empty or duplicate road records.
- Uploaded Small H3M comparison topology remains passing while reporting that the gate is topology/comparison evidence, not exact H3M byte/pathing parity.
nonGoals:
- No exact H3M byte/pathing parity claim.
- C++ changes are limited to concrete blockers exposed by the breadth gate: zero-value translated land guard fallback, package boundary mask coverage, close cross-zone town corridor guard coverage, edge-aware barriers, and required town materialization fallback.
- No generated package/map evidence committed.

id: `native-rmg-production-claim-boundary-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove misleading native RMG full-parity/authoritative claims from scoped structural profiles now that owner H3M comparisons reopened broad production parity work.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/native-rmg-homm3-spec-rework-gate-report.md`
- owner objective that native RMG must become production-ready and not be treated as alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused native RMG claim/adoption reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Native generation never reports `full_parity_claim=true` or `native_runtime_authoritative=true` for scoped structural profiles.
- Legacy supported-profile behavior remains available as scoped structural support for targeted reports, package conversion, and deterministic regression coverage.
- Package/session conversion remains feature-gated and non-authoritative.
- Focused reports that previously expected full parity are updated to assert truthful production-claim boundaries.
completionEvidence:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed after the native claim-boundary changes.
- `tests/native_random_map_full_parity_gate_report.tscn`, `tests/native_random_map_homm3_validation_adoption_gates_report.tscn`, `tests/native_random_map_package_session_adoption_report.tscn`, `tests/native_random_map_supported_underground_terrain_count_report.tscn`, and `tests/native_random_map_gdscript_port_audit_report.tscn` passed with scoped structural support preserved and `full_parity_claim=false` / `native_runtime_authoritative=false`.
- `tests/native_random_map_package_object_only_breadth_report.tscn` and `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` still pass after the claim boundary correction.
- `tests/native_random_map_gdscript_comparison_report.tscn` passes while reporting remaining road/object/guard/terrain gaps instead of allowing a native full-parity claim.
nonGoals:
- No broad RMG parity claim.
- No generated package/map evidence committed.
- No runtime call-site adoption or authored content writeback.

id: `native-rmg-production-owner-comparison-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Turn the owner-uploaded HoMM3 small single-level comparison and generated native small maps into a production parity gate for towns, zones, roads, obstacles, guards, and unguarded inter-zone routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `maps/small3playermap.h3m`
- owner correction that native RMG must not be treated as alpha/prototype and must approach real HoMM3-style production output
implementationTargets:
- native RMG topology, obstacle, guard, and road generation in `src/gdextension/src/map_package_service.cpp`
- focused uploaded-H3M comparison reports under `tests/`
- `ops/progress.json`
completionCriteria:
- A focused report compares owner HoMM3 and native small three-player single-level maps for town count, zone count, road graph shape, obstacle density, guard count, and cross-zone reachability.
- Native generated small maps do not allow short unguarded direct town-to-town routes between player starts or enemy towns.
- Obstacle and guard placement blocks or guards zone boundaries in a way that is materially closer to the uploaded HoMM3 sample than the current native output.
- The gate remains explicit that byte-level H3M parity and copyrighted asset import are out of scope.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` now compares parsed owner HoMM3 evidence with current native Small 049 on town count, expected zone count, road cells and road connected components, decoration/obstacle count, guard count, nearest town spacing, and unguarded cross-town reachability.
- The same report optionally loads the local uploaded native `.amap` as diagnostic evidence when present. In the owner-uploaded bad package it reports compact-template provenance, 6 towns, 0 road cells, 30 zero-tile road records, 28 decorations, 35 guards, nearest town spacing 3, and 10 reachable town pairs; current generated Small 049 reports 7 zones, 7 towns, 105 road cells, 1 road component versus owner 2, 150 decorations, 40 guards, nearest town spacing 12, and 0 reachable town pairs.
- HoMM3-side unguarded route parsing now treats monster/guard records as guard-controlled blockers so the report can reason about unguarded routes rather than raw passability only.
- `tests/native_random_map_homm3_uploaded_small_comparison_report.tscn` and `tests/native_random_map_package_surface_topology_report.tscn` pass alongside the strengthened topology report.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` pass.
nonGoals:
- No HoMM3 asset import or copyrighted content cloning.
- No broad all-template parity claim.
- No runtime-authoritative adoption before the comparison gate passes.

id: `native-rmg-production-terrain-object-choke-boundary-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace the remaining Small 049 warning-level reliance on terrain rock boundaries with object/guard-owned choke evidence, then broaden the owner-comparison topology gate beyond the single Small evidence map.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner objective that native RMG must become production-ready and not be treated as alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused package/topology reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Current Small 049 no longer reports terrain-rock boundary reliance as a warning in the uploaded-small topology gate.
- Object and guard package masks, not terrain-only walls, explain blocked/guarded town-zone boundaries for the default Small output.
- The topology gate is broadened with at least one additional generated Small/Medium profile seed or size-class case that checks towns, roads, guards, obstacles, and unguarded routes.
- Runtime adoption remains feature-gated and non-authoritative until broader production parity evidence exists.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` now compares the uploaded single-level Small H3M to current native Small 049 and records the uploaded bad native package as non-gating diagnostic evidence.
- The gate now fails on Small count/road/topology drift and checks additional Small and Medium generated cases for towns, roads, guards, decorative blockers, and object-only cross-zone routes.
- `tests/native_random_map_package_surface_topology_report.tscn` and `tests/native_random_map_package_object_only_breadth_report.tscn` passed with current package surfaces.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No claim that all 56 recovered templates are production-ready.

id: `native-rmg-production-owner-comparison-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Move the owner-compared translated default profiles out of `partial_foundation` / `not_implemented` status without claiming full HoMM3 parity or native runtime authority.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_full_parity_gate_report.gd`
- focused package/topology reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Translated Small 049 and Medium 002 default native generation no longer report `status: partial_foundation` or `full_generation_status: not_implemented`.
- The promoted status remains bounded to owner-comparison/topology-supported translated defaults and does not expose `full_parity_claim`, `native_runtime_authoritative`, or runtime call-site adoption.
- Full parity, uploaded-H3M topology, package-surface topology, and object-only breadth reports pass after a Linux native rebuild.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` pass.
completionEvidence:
- Native C++ generation now classifies translated Small 049 and Medium 002 defaults as `owner_compared_translated_profile_supported` with `full_generation_status: owner_compared_translated_profile_not_full_parity`.
- Full parity and runtime authority remain false, and package/session adoption remains feature-gated and non-authoritative.
- `tests/native_random_map_full_parity_gate_report.tscn`, uploaded-H3M topology, package-surface topology, and object-only breadth reports passed after a Linux native rebuild.
remainingGaps:
- Large 042 and XL 043 still report `full_generation_status: not_implemented`; they need separate owner-comparison/topology evidence before promotion.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No claim that all 56 recovered templates are production-ready.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-production-large-xl-owner-status-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Build owner-comparison/topology evidence for translated Large 042 and XL 043 defaults so they can be moved off `full_generation_status: not_implemented` without overclaiming full parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused Large/XL topology and package-surface reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Large 042 and XL 043 default translated profiles have bounded topology evidence comparable to the Small/Medium owner-comparison gates.
- If evidence passes, Large/XL no longer report `full_generation_status: not_implemented`.
- Full parity, runtime authority, and all-56-template production claims remain false until broader audit coverage exists.
completionEvidence:
- Native C++ generation now classifies translated Large 042 and Extra Large 043 defaults as `owner_compared_translated_profile_supported` with `full_generation_status: owner_compared_translated_profile_not_full_parity`.
- `tests/native_random_map_package_object_only_breadth_report.gd` asserts Small 049, Medium 002, Large 042, and XL 043 status promotion, owner-compared support, no full parity claim, no runtime authority, materialized roads, guards, package save/load, and zero object-only reachable start/cross-zone town pairs.
- `tests/native_random_map_package_object_only_breadth_report.tscn` passed after a Linux native rebuild with Large 042 at 108x108/25 zones/16 towns/1332 objects/335 guards and XL 043 at 144x144/25 zones/17 towns/1786 objects/405 guards.
remainingGaps:
- Package/session adoption is still feature-gated and non-authoritative.
- All 56 recovered templates are not yet production-ready.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No blanket all-template promotion.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-uploaded-small-road-component-hard-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Tighten the owner-uploaded Small H3M comparison so native Small 049 road connected-component topology must match the HoMM3 sample exactly instead of allowing warning-level drift.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner request to compare uploaded HoMM3 and native small maps for towns, zones, roads, obstacles, guards, and blocked/guarded inter-zone routes
implementationTargets:
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- The uploaded Small topology report fails if native Small 049 road component count differs from the owner HoMM3 sample.
- Current generated Small 049 still passes town count, zone count, object count, decorative blocker count, guard count, road cell tolerance, exact road component count, no orphan-road drift, and zero unguarded native town routes.
- The report continues to treat uploaded native `.amap` files as diagnostic evidence, not as committed/gating fixtures.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` passed with owner HoMM3 road components `[96, 14]`, current native Small 049 road components `[99, 14]`, `road_component_delta: 0`, `road_small_component_delta: 0`, `road_cell_delta: 3`, 7 towns, 7 zones, 303 objects, 150 decorative blockers, 40 guards, and zero native unguarded/object-only reachable town pairs.
- The same report records the older bad uploaded compact `.amap` as diagnostic evidence only: compact profile, 6 towns, 0 road cells, 28 decorations, 35 guards, nearest town spacing 3, and reachable town pairs.
- `tests/native_random_map_homm3_uploaded_small_comparison_report.tscn` passed and confirms player-facing Small default uses `translated_rmg_template_049_v1` instead of the legacy compact fixture path.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` passed.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-broad-runtime-zone-graph-semantic-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Strengthen the broad recovered-template generation gate so every eligible land/surface template proves exact runtime zone/link semantic preservation, not just plausible generated package surfaces.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_count_range_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template generation fails if the runtime zone graph schema/validation is missing or failed.
- For every attempted eligible land/surface template, runtime zone count and link count exactly match the active recovered catalog rows after player filtering.
- Runtime graph links preserve wide, border-guard, guard value, and source endpoint semantics without connectivity-repair substitutions.
- Runtime graph zones preserve target/cell area coverage, source ids, roles, owner/player slot semantics, terrain/town/mine/resource/treasure/monster rule payloads, adjacency, and runtime link references.
- The existing package-surface gates for roads, objects, guards, package conversion, and object-only town-route closure still pass.
completionEvidence:
- The broad recovered-template gate now validates runtime graph schema/status, exact active catalog zone/link counts, target/cell area coverage, start-zone owner/player semantics, wide and border-guard link counts, guard-value sums, source endpoints, and absence of repair links for every attempted land/surface case.
- Template support now rejects disconnected active recovered graphs. This keeps disconnected translated templates 009 and 044 out of runtime selection and moves translated XL template 043 to the minimum connected player count, 5 players, instead of the disconnected 4-player default.
- `ScenarioSelectRules.gd` now exposes player counts only when the active template graph is connected, while direct compact-template support still preserves the legacy 3-player catalog range.
- `tests/native_random_map_broad_template_generation_report.tscn` passed with 54 attempted eligible templates, 54 successes, 2 disconnected skips (`translated_rmg_template_009_v1`, `translated_rmg_template_044_v1`), zero translated `not_implemented` statuses, and object-only package town/zone route closure for every attempted case.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with XL 043 selected at 5 players, 14 towns, 27 zones, 1902 package objects, 454 guards, and validation status `pass`.
- `tests/native_random_map_package_object_only_breadth_report.tscn`, `tests/native_random_map_full_parity_gate_report.tscn`, and `tests/native_random_map_package_session_authoritative_replay_report.tscn` passed after the stricter graph selection.
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` passed after the stricter graph selection, with the uploaded single-level HoMM3 Small sample and current native Small 049 both at 7 towns, 7 zones, 303 objects, 150 decorations, 40 guards, 2 road components, and zero native object-only reachable town pairs.
- `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`, and `git diff --check` passed.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No broad player-facing exposure of non-owner-compared templates.

id: `native-rmg-player-facing-medium-islands-reactivation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reactivate a bounded player-facing Islands generated-map path by routing Medium islands native catalog auto-selection to the owner-compared translated islands profile instead of the blocked broad `not_implemented` fallback.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection prefers `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` for Medium 4-player islands, matching the already owner-compared runtime-supported islands profile.
- Medium Islands player-facing setup validates and launches through native catalog auto-selection with package/session provenance, without re-enabling underground.
- Auto-template batch reports the Medium islands case as launchable owner-compared native support, not `not_implemented_launch_blocked`.
- Existing land defaults, compact launch blocking, package route closure, replay, and full-parity boundary gates remain green.
completionEvidence:
- Native catalog auto-selection now maps Medium 72x72, 4-player, single-level Islands requests to `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` instead of falling through to the Medium land default and `not_implemented`.
- Player-facing generated-map setup now exposes Islands as a bounded water option and coerces Islands selection to Medium, 4 players, no underground before launch.
- `tests/random_map_player_setup_retry_ux_report.tscn` passed with Islands exposed in the player controls and Medium Islands setup returning `ok`, retry status `pass`, and template/profile 001/001.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with `medium_islands_seed_a` selecting template/profile 001/001, 8 towns, 4 zones, 495 package objects, 60 guards, and `not_implemented_launch_blocked: false`.
- `tests/native_random_map_package_object_only_breadth_report.tscn` passed with `owner_medium_islands_001` at 8 towns, 4 zones, 496 objects, 61 guards, 201 road tiles, and zero object-only all-town or cross-zone reachable pairs.
- `tests/native_random_map_full_parity_gate_report.tscn` passed with Medium Islands runtime-adopted only as owner-compared not-full-parity output, keeping `full_parity_claim: false`.
- `tests/native_random_map_package_session_authoritative_replay_report.tscn` passed after adding `player_facing_medium_islands_001`, proving stable generate/convert/save/load replay for Medium Islands package/session identity.
- `tests/random_map_all_template_menu_wiring_report.tscn` passed with 54 buildable connected recovered templates, 2 disconnected catalog-only templates, manual template/profile controls hidden, and 4 player-facing default template/profile ids.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No claim that every islands size/template is owner-compared or full parity.

id: `native-rmg-broad-islands-structural-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend the broad recovered-template structural gate from land/surface only to explicit surface Islands generation, then allow translated catalog Islands outputs to report structural not-full-parity support only when they pass the same zone, road, object, guard, package, and object-only route-closure gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_broad_template_generation_report.gd`
- owner objective that native RMG must become production-ready and not hide behind land-only parity evidence
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Broad template generation can be run in `land` or `islands` mode with the requested water mode recorded per case and in the report summary.
- Islands planning uses recovered template size-score semantics, including `islands_size_score_halved`, instead of reusing land-only size assumptions.
- Every attempted connected translated surface-Islands template generates, validates, materializes roads/objects/guards, converts to a package, and has zero object-only player-start, cross-zone, and all-town reachable town pairs.
- Translated catalog surface-Islands configs that pass the gate report `translated_catalog_structural_profile_not_full_parity` rather than `not_implemented`.
- Existing owner-compared land defaults and Medium Islands 001 remain bounded and do not become full-parity claims.
completionEvidence:
- `tests/native_random_map_broad_template_generation_report.gd` now has report schema v4 and `NATIVE_RMG_BROAD_WATER_MODE=land|islands`, recording water mode per case and summary.
- Islands broad planning applies recovered `islands_size_score_halved` sizing semantics instead of reusing land-only size assumptions.
- Explicit translated catalog level-1 Islands configs now report structural support as `translated_catalog_structural_profile_not_full_parity` after generation/package topology gates pass.
- Focused Islands broad run passed for templates 001, 002, and 049 with all attempted cases reporting translated catalog structural not-full-parity and zero object-only route leaks.
- Full Islands broad sweep passed 45 attempted connected translated cases, with 45 translated catalog structural not-full-parity statuses, zero translated `not_implemented` statuses, 11 unsupported-size/profile skips, and zero object-only player-start, cross-zone, or all-town route leaks.
- Full land broad sweep passed 54 attempted land/surface cases, with zero translated `not_implemented` statuses, 2 unsupported-size/profile skips, and zero object-only player-start, cross-zone, or all-town route leaks.
- Owner-uploaded Small H3M topology comparison still shows current Small default 049 matching owner-like towns, zones, objects, decoration, guards, road components, and zero object-only town routes while the stale compact package remains diagnostic evidence of the bad baseline.
- Native catalog auto, full-parity boundary, and package object-only breadth gates passed after the broad Islands support change.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No player-facing exposure of every Islands template.
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.

id: `native-rmg-production-parity-completion-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Convert the owner objective that native GDExtension RMG must be production-ready and HoMM3-style, not alpha/prototype, into an explicit completion audit with concrete pass/fail evidence so green focused reports cannot be mistaken for full objective completion.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- owner objective that full production-ready HoMM3-style native RMG is the only acceptable end state
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The audit restates production-ready HoMM3-style RMG as concrete criteria covering native path, representative defaults, false full-parity claims, full parity, broad template support, owner-H3M corpus coverage, owner-compared defaults, and underground parity.
- The audit inspects actual native generation/package evidence for representative Small, Medium, Medium Islands, Large, and Extra Large defaults.
- The audit reports `production_ready: false` until all missing objective requirements are actually satisfied.
- Missing requirements are explicit and actionable rather than hidden behind passing proxy gates.
completionEvidence:
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed as an audit run with native GDExtension active, five representative defaults generating and validating, no false full-parity claim, and `production_ready: false`.
- The audit reported four missing requirements: full HoMM3-style parity, broad player-facing template support beyond 4 of 56 catalog templates, a broad owner-H3M comparison corpus, and underground production parity.
- Representative defaults all remain `owner_compared_translated_profile_not_full_parity`, proving the thread goal is still open and must not be marked complete.
nonGoals:
- No full HoMM3 parity claim.
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.
- No broad player-facing exposure or runtime-authoritative promotion from this audit-only slice.

id: `native-rmg-owner-h3m-corpus-coverage-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Inventory the owner-uploaded/local HoMM3 H3M evidence corpus so the production parity objective can distinguish available comparison evidence from missing sample coverage before broad owner-comparison gates are claimed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `maps/small3playermap.h3m` (local evidence only, not committed)
- `/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz` (local evidence only, not committed)
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The report reads H3M gzip headers without importing H3M content into runtime assets.
- The report identifies present/readable owner evidence samples, size class, level count, underground flag, and declared water mode.
- The report explicitly lists missing corpus coverage needed before broad production parity can be claimed.
completionEvidence:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with 3 readable and metric-parsed local owner H3M samples: Small 36x36 single-level land, Small 36x36 with underground flag set, and Medium 72x72 Islands.
- The report now extracts object definition count, object count, object category counts, counts by level, road cells by level, and road component sizes by level for all three current samples.
- The two-level Small H3M parsed as 436 objects across surface/underground, with 157 total road cells split across level 0 and level 1.
- The report confirms `corpus_ready: false` with remaining missing coverage for Large/XL owner H3M samples and template-breadth corpus coverage.
nonGoals:
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.
- No claim that the current corpus proves broad production parity.
- No runtime generation or player-facing behavior change.

id: `native-rmg-package-session-authoritative-replay-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Isolate nondeterministic native RMG output fields and prove package/session replay before any native runtime-authoritative generated-skirmish adoption.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- package/session adoption and replay reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Supported default translated profiles have stable replay-relevant output signatures across generate, convert, save, and load.
- Nondeterministic diagnostic/profile fields are isolated from authoritative replay identity.
- Runtime call-site adoption remains disabled unless replay and comparison gates prove readiness.
validation:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_small_049 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Small 049 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_medium_002 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Medium 002 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_large_042 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Large 042 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_extra_large_043 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable XL 043 full/adoption/disk replay signatures.
remainingGaps:
- Runtime call-site adoption remains disabled and non-authoritative.
- All 56 recovered templates are not yet production-ready.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No blanket all-template production claim.

id: `overworld-map-object-distinct-sprite-gap-fill-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Owner-directed asset follow-up to audit authored overworld map objects after the decorative/blocker foundation pass and generate distinct original sprite assets for every remaining non-decoration object gap.
sourceDocs:
- `content/map_objects.json`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `docs/overworld-map-object-distinct-sprite-gap-audit.md`
implementationTargets:
- `art/overworld/map_object_sprites.json`
- `art/overworld/manifest.json`
- `art/overworld/runtime/objects/map_objects/distinct/`
- `art/overworld/source/generated/map_objects/distinct/`
- `art/overworld/source/trimmed/map_objects/distinct/`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- `tests/overworld_map_object_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- The audit identifies authored map objects that still lack unique sprite assignments after the 200-object decorative/blocker pass.
- Every identified gap object has one distinct generated 512x512 runtime PNG, trimmed source PNG, source atlas provenance, manifest mapping, and no-HoMM3-art policy.
- Renderer lookup resolves resource and encounter placements through object-specific map object sprite mappings before shared fallback assets.
- Validation proves all 386 authored map objects have distinct assignments after combining the decorative foundation pass, preexisting unique non-decoration assignments, and this gap-fill pass.
nonGoals:
- No HoMM3 copyrighted art/DEF/image/name/text import.
- No town, hero, unit, battle, terrain, road, or UI asset broadening beyond authored overworld map object sprite coverage.
- No generated random map package clutter committed under runtime maps.

id: `native-rmg-homm3-spec-rework-parent-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Parent goal for replacing the current native RMG surface-parity approximation with a recovered-spec-driven, phased generator architecture.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/rmg-profile-20260504/profile_native_rmg_cpp_phases_compare.log`
- existing `docs/native-rmg-*.md` comparison, parity, spatial, and land/water reports
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `content/random_map_template_catalog.json`
- generator support data under `content/` or `docs/` selected by child slices
- focused native RMG Godot report scenes under `tests/`
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `ops/progress.json`
completionCriteria:
- Child slices define and implement the replacement generator data model, runtime phase order, validation gates, and adoption rules.
- The generator no longer relies on count/ratio parity shortcuts as the main quality target for supported profiles.
- Outputs are judged against recovered HoMM3-style structure: template graph, zone semantics, terrain/island shape, roads/rivers, object density/footprints, mines/resources, guards/rewards/monsters, and serialization/adoption boundaries.
- Unsupported exact byte/art/private-toolkit parity gaps remain explicit rather than silently approximated.
nonGoals:
- No HoMM3 copyrighted art/DEF/image/name/text import.
- No claim of binary-compatible `.h3m` output.
- No generated map package clutter committed under runtime maps.
- No save-version bump or campaign adoption until a child adoption slice explicitly gates it.
currentEvidence:
- 2026-05-16: strict Small-land validator-blocked root causes were fixed in the active h3maped Small path: `0x4a6cf2`-style connection fallback for missing blockers/guards, requested-player owner-mask template eligibility, and guard-required route-link validation for zero-value/wide-suppressed links. Linux and Windows GDExtension libraries were rebuilt, the exact failed 2p Small seed `1270881600` is covered by the public template matrix report, and the skirmish menu 2p Small land launch path validates again. Remaining RMG reset work is diagnostic recalibration for the deep port-boundary report and broader unsupported-mode parity, not a fallback to the archived generator.

id: `native-rmg-homm3-spec-gap-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Produce the implementation gap report that maps recovered HoMM3 RMG phases to current native C++ behavior and defines the exact child-slice order.
sourceDocs:
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `src/gdextension/src/map_package_service.cpp`
- `content/random_map_template_catalog.json`
- existing native RMG comparison/profile artifacts
implementationTargets:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Report states, phase by phase, HoMM3 recovered behavior, current native behavior, player-visible effect, and required implementation slice.
- The current XL island scoring bottleneck and object/road/terrain semantic gaps are prioritized before broad adoption.
- Follow-up child slices are reconciled in `ops/progress.json` with source docs, targets, validation, and non-goals.
nonGoals:
- No code rewrite in the audit slice except minimal test/report plumbing if required.

id: `native-rmg-homm3-generator-data-model-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Introduce the reusable generator data model needed for template zones, links, object definitions, terrain masks, footprints, value bands, limits, and validation results.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
implementationTargets:
- native RMG data structs/helpers in `src/gdextension/src/rmg_data_model.cpp` exposed through `MapPackageService`
- original-content generator table `content/random_map_generator_data_model.json`
- focused schema/fixture validator `tests/native_random_map_homm3_generator_data_model_report.gd`
- implementation evidence `docs/native-rmg-homm3-generator-data-model-report.md`
completionCriteria:
- Supported generated objects resolve through explicit definitions with footprint, passability/action, terrain, category, limit, value/density, and writeout metadata.
- Existing package/session surfaces remain backward-compatible or explicitly gated.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_generator_data_model_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No broad gameplay rebalance and no renderer art rewrite.

id: `native-rmg-homm3-runtime-zone-graph-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace radial/Voronoi zone approximation with runtime template/zone graph construction preserving base size, owner, terrain/faction, source role, adjacency, links, and infeasibility diagnostics.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- native zone layout generation
- template catalog import/normalization
- zone/connectivity validation reports
completionCriteria:
- Generated zones preserve source-template semantics and produce connected playable graphs or explicit validation failures.
- Starts, neutral zones, links, and target areas are represented as runtime state before terrain/object placement.
nonGoals:
- Exact HoMM3 footprint heuristics may remain unresolved if documented and bounded.

id: `native-rmg-homm3-terrain-island-shape-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace global protected-land/ratio island shaping with zone-aware terrain and water placement informed by recovered TerrainPlacement semantics and performance constraints.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/rmg-profile-20260504/profile_native_rmg_cpp_phases_compare.log`
- `docs/native-rmg-homm3-land-water-shape-report.md`
implementationTargets:
- native terrain grid generation
- island/water shaping code path
- XL performance fixtures and visual/spatial reports
completionCriteria:
- Terrain and water are painted from runtime zone semantics with explicit allowed-terrain/match-to-town handling.
- XL islands avoid the current candidate-scoring bottleneck and pass focused performance gates.
nonGoals:
- No terrain art replacement or exact terrain queue scratch-bit clone unless selected later.

id: `native-rmg-homm3-towns-castles-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered Phase 4a/4b town/castle placement before cleanup, connection payload handling, roads, rivers, mines, resources, guards, rewards, and decoration.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
implementationTargets:
- native town/castle placement records in `src/gdextension/src/map_package_service.cpp`
- runtime/source-zone faction selection and original town id mapping
- focused native town/castle validation in `tests/native_random_map_town_guard_report.gd`
completionCriteria:
- Player fields `+0x20..+0x2c` place mapped-owner town/castle minimums and density attempts.
- Neutral fields `+0x30..+0x3c` place owner `-1` town/castle minimums and density attempts with deterministic infeasibility diagnostics.
- Source `+0x40` affects neutral weighted same-type faction reuse only; it is not a global map lock.
nonGoals:
- No mines/resources, guards/rewards/monsters, roads/rivers, or decoration implementation in this slice.

id: `native-rmg-homm3-roads-rivers-connections-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: After towns/castles, apply cleanup/connection payload handling so late guard, wide, border-guard, road, and river semantics follow the recovered phase order.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
implementationTargets:
- native cleanup/connection payload handling after town/castle placement
- native road/river network generation
- link/guard validation reports
- road/river overlay metadata
- focused report scene `tests/native_random_map_homm3_roads_rivers_connections_report.tscn`
- implementation evidence `docs/native-rmg-homm3-roads-rivers-connections-report.md`
completionCriteria:
- `Wide` suppresses normal guards, `Border Guard` materializes supported type-9-equivalent original gate behavior, and required links produce corridors or explicit failures after town/castle records exist.
- Roads/rivers are stored as overlays with deterministic autotile/writeout metadata separate from rand_trn decoration scoring.
nonGoals:
- No road renderer art rewrite unless validation proves it is required.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_roads_rivers_connections_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`

id: `native-rmg-homm3-object-placement-pipeline-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Rework object selection, footprints, terrain masks, occupancy, value bands, limits, and decorative filler as the shared placement pipeline used by later mine, reward, guard, and decoration slices.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
- `docs/native-rmg-homm3-local-distribution-report.md`
implementationTargets:
- native object placement
- object definition/footprint validators
- local/spatial distribution reports
- focused report scene `tests/native_random_map_homm3_object_placement_pipeline_report.tscn`
- implementation evidence `docs/native-rmg-homm3-object-placement-pipeline-report.md`
completionCriteria:
- Supported objects resolve through explicit original-content definitions with footprint, passability/action, terrain, category, limit, value/density, and writeout metadata.
- Decoration uses ordinary object-template filler semantics rather than a decoration super-type shortcut.
- XL object-placement cost is measured and bounded enough for broad seed validation.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_object_placement_pipeline_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No HoMM3 asset import, exact DEF frame dependency, or broad economy rebalance.

id: `native-rmg-homm3-mines-resources-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered seven mine/resource categories, minimums/densities, adjacent resources, and placement diagnostics after towns/castles and the shared object-placement pipeline.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
implementationTargets:
- native mine/resource placement
- original-content mine and resource proxy mappings
- focused mine/resource validation reports
- `docs/native-rmg-homm3-mines-resources-report.md`
- `tests/native_random_map_homm3_mines_resources_report.tscn`
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_mines_resources_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
completionCriteria:
- Seven mine/resource categories are implemented for supported profiles with minimum-before-density behavior and original content ids.
- Mine/resource placements report failures with zone/category context and keep adjacent-resource behavior explicit.
nonGoals:
- No broad economy rebalance.
- No HoMM3 mine or resource art/name/text import.

id: `native-rmg-homm3-guards-rewards-monsters-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered monster masks, strength scaling, connection guards, protected rewards, and guard/reward relations using original unit and reward content.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
implementationTargets:
- native guard/reward package generation
- monster mask and strength scaling helpers
- reward value-band selection and guard/reward validators
- focused guard/reward/monster reports
- implementation evidence `docs/native-rmg-homm3-guards-rewards-monsters-report.md`
completionCriteria:
- Monster selection honors match-to-town, allowed faction masks, and recovered local/global strength scaling for supported profiles.
- Connection and protected-object guards use recovered value semantics and original unit/content ids.
- Value-banded rewards preserve low/high/density behavior with explicit unsupported reward boundaries.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_guards_rewards_monsters_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No HoMM3 creature, artifact, spell, skill, or reward art/name/text import.
- No broad combat/economy rebalance beyond generator guard/reward semantics.

id: `native-rmg-generated-cross-zone-town-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the uploaded Small 3-player single-level H3M/native-map comparison to close the raw generated-payload gap where package surfaces hide cross-zone unguarded town routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_zone_choke_regression_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_zone_choke_regression_report.gd`
- `ops/progress.json`
completionCriteria:
- Raw generated town-pair route closure evaluates cross-zone and same-zone town pairs instead of same-zone pairs only.
- Raw zone-choke validation treats guard route-closure mask tiles as guard-controlled blockers, not as decorative body art.
- Uploaded Small comparison continues to show current native Small 049 matching owner counts for towns, zones, objects, roads, decorations, and guards.
- Legacy compact native packages remain diagnostic evidence of the old bad output and are not rewritten in place.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No committed uploaded `.h3m`, generated `.amap`, or `.ascenario` evidence.
completionEvidence:
- Uploaded Small H3M comparison shows the current native Small 049 package matching owner structure: 7 towns, 7 zones, 303 package objects, 150 decorations, 40 guards, 110 road cells, and road components `[96, 14]`, with zero native object-only reachable town pairs.
- The stale bad native sample remains diagnostic evidence of the old compact path: legacy `border_gate_compact_v1`, 6 towns, 152 objects, 28 decorations, 35 guards, 0 roads, nearest town Manhattan distance 3, and 10 object-only reachable town pairs.
- Raw generated town-pair route closure now checks cross-zone pairs as well as same-zone pairs; the zone-choke audit now treats unresolved guard bodies, guard control zones, and route-closure masks as blockers.
- Raw zone-choke regression passes for the compact small control, owner-compared Small 049, and Medium translated land cases with zero unresolved start-town or cross-zone town traversal leaks. Neutral-town permanent blocks are reported as diagnostics rather than used to weaken the unguarded-route gate.
- Focused uploaded Small topology and comparison reports pass after the fix. The broader package object-only breadth report was started as extra validation but did not return in a reasonable window and was stopped without a pass claim.

id: `native-rmg-owner-corpus-dynamic-discovery-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the owner-H3M corpus gate discover newly uploaded local H3M/gzip evidence instead of freezing production-readiness audits to the first three hardcoded samples.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report preserves known exact sample mappings while auto-discovering `.h3m` and `.gz` owner evidence in local upload/map evidence directories.
- Production parity audit reads dynamic owner-corpus coverage instead of embedding stale hardcoded sample counts and missing scopes.
- Audit remains a no-overclaim boundary: if the discovered corpus is still incomplete, `production_ready` remains false and missing requirements remain explicit.
nonGoals:
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No claim that dynamic discovery alone proves HoMM3 parity or production readiness.
completionEvidence:
- Owner corpus coverage now preserves the three known mapped owner samples while dynamically discovering local `.h3m` and `.gz` evidence under `res://maps` and `/root/.openclaw/media/inbound`.
- Production parity completion audit now embeds the dynamic owner-corpus summary instead of a stale hardcoded sample count, and still keeps `production_ready: false` with missing broad corpus, full parity, and underground parity requirements.
- Focused validation passed: `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn`, `tests/native_random_map_production_parity_completion_audit_report.tscn`, `python3 -m json.tool ops/progress.json`.

id: `native-rmg-medium-islands-reward-category-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the owner-mapped H3M category parity gap where recovered HoMM3 shrine objects count as reward-category content and native owner-compared outputs needed their reward/scenic mix aligned to the recovered metadata baseline.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Recovered H3M object categorization treats Shrine of Magic Gesture and Shrine of Magic Thought as reward-category objects consistently across owner-corpus and uploaded-topology reports.
- Native Small single-level, Small underground, and Medium Islands owner-compared generation reach the owner category baselines for reward and ordinary object content without increasing total package object count beyond each owner sample.
- Spatial placement comparison, dynamic owner-corpus coverage, and production parity audit pass while still preserving the no-full-parity/no-production-ready boundary.
nonGoals:
- No import of HoMM3 art or object definitions as runtime copyrighted content.
- No claim that mapped owner-sample category parity alone completes broad HoMM3 RMG production parity.
completionEvidence:
- Owner H3M parsing now uses recovered object metadata names so Shrine of Magic Gesture and Shrine of Magic Thought are classified as reward-category records consistently with Shrine of Magic Incantation.
- Native Small 049 owner target now matches the uploaded single-level Small H3M at 303 objects: decoration 150, guard 40, object 26, reward 80, town 7, 110 road cells, and road components `[96, 14]`.
- Native Small 027 underground category-shape adjustment now matches the uploaded underground Small H3M at 436 objects: decoration 151, guard 60, object 89, reward 128, town 8, 157 road cells, and all-level road topology match.
- Native Medium Islands 001 now matches the owner-attached sample at 496 objects: decoration 252, guard 61, object 65, reward 110, town 8, 184 road cells, and road component sizes `[82, 52, 19, 16, 15]`.
- Validation passed native C++ rebuild, owner-corpus coverage, Medium Islands spatial placement comparison, uploaded Small topology comparison, production parity completion audit, progress JSON validation, and diff whitespace checks.

id: `native-rmg-homm3-validation-adoption-gates-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Gate the reworked generator through validation, fixture comparison, performance, save/replay boundaries, and package/session adoption before gameplay reliance.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `docs/random-map-generator-foundation.md`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
implementationTargets:
- `tests/validate_repo.py`
- native RMG report scenes
- generated package/session adoption records
- `docs/native-rmg-homm3-spec-rework-gate-report.md`
completionCriteria:
- Validators cover template filtering, zone graph connectivity, required placements, footprints/occupancy, object definition references, road/river ranges, guard semantics, and performance budgets.
- Native package/session adoption remains feature-gated until reports prove supported profiles are structurally acceptable.
validation:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_validation_adoption_gates_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_package_session_adoption_report.tscn`
- Selected Phase 3 native RMG reports for runtime zone graph, terrain island shape, roads/rivers/connections, object placement pipeline, mines/resources, and guards/rewards/monsters.
- `python3 -m json.tool ops/progress.json >/dev/null`
- `python3 tests/validate_repo.py`
- `git diff --check`
adoptionStatus:
- Phase 3 closes with package/session adoption structurally ready but feature-gated and non-authoritative.
- `full_output_signature_stable=false` keeps authoritative package/session replay and runtime call-site adoption out of this phase.
- Follow-up: `native-rmg-package-session-authoritative-replay-gate-10184` should isolate nondeterministic full-output signature fields before any native runtime authority claim.
nonGoals:
- No alpha readiness claim; this gate only closes the RMG rework phase.

Completed owner-directed implementation slice:

id: `battle-attack-hit-token-feedback-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Use source/target battle event context to present attack, cast, hit, status, and death token feedback during playback instead of leaving stack tokens visually fixed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-attack-hit-token-feedback-report.md`
- `ops/progress.json`
completionCriteria:
- Active attack/cast/impact playback records compute bounded presentation transforms from source/target stack cells.
- Stack token drawing, labels, health/count overlays, and hit shapes use the event-driven presentation center during normal playback.
- Focused validation proves a real melee strike presents attacker lunge and target hit-stagger feedback while retaining melee VFX evidence.
nonGoals:
- No final authored attack timing, camera shake, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-event-token-feedback-coverage-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add focused board-summary and report coverage for every active token-feedback role currently produced by battle event presentation playback.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-event-token-feedback-coverage-report.md`
- `ops/progress.json`
completionCriteria:
- Board validation summaries expose active presentation motion totals and role counts.
- Focused validation proves ranged recoil, status pulse, cast anchor, and death fallback token roles in addition to existing melee/hit feedback assertions.
- Repository validation gates require the new focused report fields and role assertions.
nonGoals:
- No final authored animation timing, camera work, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-camera-presentation-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Derive bounded board-side camera focus and shake presentation from active battle event playback records.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-camera-presentation-report.md`
- `ops/progress.json`
completionCriteria:
- Active movement, attack, impact, spell, status, and exit battle cue records can produce camera presentation records with focus kind, source/target cells, focus coordinates, and bounded shake strength.
- Normal animation playback applies a bounded battlefield offset while reduced-motion and fast modes suppress camera shake strength.
- Focused validation proves ranged/status event playback creates source-target/status camera records and that camera records expire with event playback.
nonGoals:
- No final authored cinematic timing, screen shake direction, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-movement-token-motion-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Use resolved movement event playback to present the stack token traveling along the source-to-destination path instead of snapping immediately to the destination cell.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-movement-token-motion-report.md`
- `ops/progress.json`
completionCriteria:
- Active `battle_unit_move` playback records compute a stack presentation center from `from_q/from_r`, `to_q/to_r`, and cue playback progress.
- Stack token drawing, labels, health/count overlays, and hit shapes use the movement presentation center during normal playback.
- Focused validation proves a real move action presents the token in transit while retaining `move_path_step` and path-ghost VFX evidence.
nonGoals:
- No final authored motion curves, per-unit locomotion timing, camera work, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-movement-path-presentation-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Preserve movement source/destination hexes on battle move events and use them for board-side path-ghost presentation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scripts/core/BattleRules.gd`
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-movement-path-presentation-report.md`
- `ops/progress.json`
completionCriteria:
- `battle_unit_move` event records preserve source and destination hex coordinates.
- `BattleBoardView` uses movement event coordinates to draw `vfx_placeholder_battle_path_ghost` between distinct cells.
- Focused validation proves a real move action emits path coordinates and a source-to-destination path ghost.
nonGoals:
- No final interpolated token travel, authored motion curves, camera work, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-death-animation-retention-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Keep defeated stacks visible for their active death animation and stack-fade VFX playback instead of dropping them from the board immediately.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-death-animation-retention-report.md`
- `ops/progress.json`
completionCriteria:
- Defeated zero-health stacks with active event playback remain board-visible for the death animation window.
- Expired defeated stacks no longer occupy visible stack lists or board presentation slots.
- Focused validation proves a real killing strike renders `death_rout_remove` and `vfx_placeholder_stack_fade` for the defeated target.
nonGoals:
- No final authored death timing, corpse persistence, camera work, imported VFX/audio assets, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-autoplay-scenario-breadth-gate-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Widen deterministic battle autoplay default coverage across authored scenario encounters and gate multi-scenario requested sample breadth.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `tests/balance_regression_report_suite.gd`
- `tests/headless_simulation_harness_report.gd`
- `tests/validate_repo.py`
- `docs/battle-autoplay-combat-feel-diagnostics-report.md`
- `ops/progress.json`
completionCriteria:
- The default battle autoplay sampler uses an authored scenario set instead of only `river-pass`.
- Aggregate balance/headless battle summaries expose `scenario_distribution` alongside existing combat-feel metrics.
- Focused balance and headless reports fail if default sampling does not reach the requested sample limit or does not span multiple authored scenarios.
nonGoals:
- No encounter retune, automatic balance tuning, authored content writeback, spell autoplay expansion, or final combat balance approval.

Completed owner-directed implementation slice:

id: `battle-event-playback-sequencing-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add deterministic source-action to target-reaction sequencing to active battle event playback so presentation no longer starts every cue at the same wall-clock instant.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-event-playback-sequencing-report.md`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Active playback/cue records expose observed, start, expiry, and sequence-delay timing metadata.
- Hit, death, status, and retaliation target reactions receive a bounded positive sequence delay after source action cues.
- Generated unit animation frame selection uses event playback progress for active event states.
- Focused validation proves ranged source cues start before target status cues and delayed target audio is scheduled with positive sequence delay.
nonGoals:
- No final authored animation timing, imported audio/VFX assets, save-schema change, combat balance tuning, or broad battle UI redesign.

Completed owner-directed implementation slice:

id: `battle-autoplay-combat-feel-threshold-gate-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Turn deterministic battle autoplay diagnostics into report-only combat-feel threshold gates for balance triage.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `tests/balance_regression_report_suite.gd`
- `tests/headless_simulation_harness_report.gd`
- `tests/validate_repo.py`
- `docs/battle-autoplay-combat-feel-diagnostics-report.md`
- `ops/progress.json`
completionCriteria:
- Sampler summary exposes `combat_feel_gate` with thresholds/status/warnings/failures.
- Balance and headless reports assert gate shape and alignment with summary metrics.
- Current deterministic samples surface high terminal health margin as a warning without automatic tuning or content writeback.
nonGoals:
- No authored encounter retune, unit-stat rebalance, automatic tuning, strategic AI rewrite, or final combat balance approval.

Completed owner-directed implementation slice:

id: `battle-autoplay-combat-balance-calibration-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Use the deterministic battle autoplay gate to make a first bounded combat-feel balance calibration over sampled authored encounters.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/battle-autoplay-combat-feel-diagnostics-report.md`
implementationTargets:
- `scripts/core/BattleAiRules.gd`
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `content/army_groups.json`
- `tests/battle_autoplay_combat_balance_report.gd`
- `tests/battle_autoplay_combat_balance_report.tscn`
- `tests/balance_regression_report_suite.gd`
- `tests/headless_simulation_harness_report.gd`
- `tests/validate_repo.py`
- `docs/battle-autoplay-combat-balance-calibration-report.md`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Default deterministic battle autoplay samples no longer trigger `high_terminal_health_margin`.
- Average terminal health margin is at or below 65% for the focused standard sampler.
- Tactical autoplay can advance/reposition no-attack melee stacks instead of repeatedly defending after abstract distance closes.
- Difficulty distribution preserves authored `low`/`medium`/`high` labels.
nonGoals:
- No final combat balance approval, broad faction-vs-faction tuning, automatic content tuning, spell/autocast retune, strategic AI rewrite, or manual playtest replacement.

Completed owner-directed implementation slice:

id: `battle-autoplay-tactical-order-scoring-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Replace deterministic balance autoplay's shoot-first player policy with shared tactical order scoring so combat-feel samples reflect target, action, terrain, ability, cohesion, and defend/advance tradeoffs.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/core/BattleAiRules.gd`
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `tests/battle_autoplay_tactical_order_report.gd`
- `tests/battle_autoplay_tactical_order_report.tscn`
- `tests/balance_regression_report_suite.gd`
- `tests/validate_repo.py`
- `docs/battle-autoplay-combat-feel-diagnostics-report.md`
- `ops/progress.json`
completionCriteria:
- Battle AI exposes a side-agnostic non-spell tactical order scorer for attack, defend, and advance orders.
- Player-side balance autoplay uses the tactical scorer, applies scored targets before acting, and records compact decision evidence in turn logs.
- A focused tactical-order report proves an adjacent ranged stack chooses scored melee strike when both shoot and strike are legal, preventing legacy shoot-first autoplay bias.
nonGoals:
- No automatic tuning, authored content writeback, unit-stat retune, spell/autocast expansion, or final combat balance approval.

Completed owner-directed implementation slice:

id: `battle-autoplay-combat-feel-diagnostics-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Expand deterministic battle autoplay sampling into actionable combat-feel diagnostics for balance work.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `scripts/core/BalanceRegressionReportRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/balance_regression_report_suite.gd`
- `tests/headless_simulation_harness_report.gd`
- `tests/validate_repo.py`
- `docs/battle-autoplay-combat-feel-diagnostics-report.md`
- `ops/progress.json`
completionCriteria:
- Per-sample autoplay evidence includes terrain, encounter difficulty, initial stack profile, role mix, ability ids, initiative spread, action mix, damage totals, damage per round, pacing band, terminal health margin, and invalid-order count.
- Aggregate balance/headless summaries expose damage pacing, action diversity, dominant action, terrain/difficulty distribution, pacing bands, role distribution, ability distribution, and average initiative spread.
- Focused balance and headless reports assert the new combat-feel diagnostics.
nonGoals:
- No automatic tuning or authored content writeback.
- No final combat balance approval.
- No strategic AI rewrite, encounter retune, or manual-play replacement.

Completed owner-directed implementation slice:

id: `music-audio-runtime-baseline-20260523-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Add a runtime music state layer so top-level game contexts have deterministic music routing and validation evidence before final composed audio assets exist.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/autoload/UiAudio.gd`
- `scripts/autoload/AmbientAudio.gd`
- `project.godot`
- `tests/validate_repo.py`
implementationTargets:
- `scripts/autoload/MusicAudio.gd`
- `project.godot`
- `scenes/menus/MainMenu.gd`
- `scenes/overworld/OverworldShell.gd`
- `scenes/battle/BattleShell.gd`
- `scenes/results/ScenarioOutcomeShell.gd`
- `tests/music_audio_runtime_report.gd`
- `tests/music_audio_runtime_report.tscn`
- `docs/music-audio-runtime-baseline-report.md`
- `tests/validate_repo.py`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `MusicAudio` is registered as an autoload and respects master/music mute state.
- Menu, overworld, battle, and outcome contexts sync deterministic generated music layer records.
- Music state avoids restarting when the context signature is unchanged.
- Validation summary exposes schema, current context, cue ids, layers, active player cap, records, and audio bus.
- Focused report proves direct context routing plus a live shell routing path.
nonGoals:
- No final composed soundtrack.
- No imported audio files.
- No broad audio mixer redesign.
- No save migration.

Completed owner-directed implementation slice:

id: `ui-audio-cue-runtime-baseline-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a generated UI audio cue service that attaches to common controls and provides runtime feedback for menu/town/overworld/battle UI interactions.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/autoload/UiAudio.gd`
- `project.godot`
- `tests/ui_audio_cue_runtime_report.gd`
- `tests/ui_audio_cue_runtime_report.tscn`
- `tests/validate_repo.py`
- `docs/ui-audio-cue-runtime-report.md`
- `ops/progress.json`
completionCriteria:
- `UiAudio` is registered as an autoload and attaches to common Godot controls without per-screen wiring.
- Generated UI cue playback uses `AudioStreamGenerator` on the Master bus and exposes bounded validation records.
- Focused validation proves Button, OptionButton, HSlider, TabContainer, ItemList, confirm, and invalid-action cue records.
nonGoals:
- No final imported UI audio assets.
- No music, ambience, mixer polish, or final sound design claim.

Completed owner-directed implementation slice:

id: `battle-audio-cue-playback-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make active battle audio cue ids produce runtime playback through generated cue-specific audio waveforms.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
- `docs/battle-animation-cue-dispatch-report.md`
- `docs/battle-vfx-cue-presentation-report.md`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-audio-cue-playback-report.md`
- `ops/progress.json`
completionCriteria:
- Active battle audio cue ids resolve to runtime generated `AudioStreamGenerator` playback records.
- Generated battle audio routes through the Master bus and respects mute state through existing settings.
- Playback records expose selected audio cue ids, generated waveform metadata, active player count, and expiry.
- Focused validation proves ranged/status events synthesize audio cue waveforms and expire with playback.
nonGoals:
- No final imported audio assets.
- No music, ambience, UI audio, mixer polish, camera, VFX asset, or combat balance tuning.

Completed implementation slice:

id: `battle-runtime-sfx-asset-layer-20260523-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Add committed runtime WAV SFX assets for battle cue ids and make board playback prefer those assets before generated fallback.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/battle-audio-cue-playback-report.md`
- `content/animation_event_cues.json`
implementationTargets:
- `content/battle_sfx_manifest.json`
- `art/audio/runtime/battle/*.wav`
- `tools/generate_battle_sfx_assets.py`
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-runtime-sfx-asset-layer-report.md`
- `ops/progress.json`
completionCriteria:
- Battle cue ids have deterministic original WAV assets listed in `content/battle_sfx_manifest.json`.
- `BattleBoardView` prefers manifest-backed imported `AudioStream` assets and preserves generated waveform fallback.
- Validation summaries expose imported asset counts, asset paths, fallback counts, player caps, bus, mute state, and lifecycle expiry.
- Focused battle event report and repository validation gates pass.
nonGoals:
- No final sound design approval.
- No music, ambience, UI audio, or mixer mastering.
- No combat balance or encounter tuning.
- No broad audio asset import pipeline redesign.

Completed implementation slice:

id: `headless-balance-harness-cli-20260523-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Add a single artifact-producing CLI runner for the existing automated battle balance, balance regression, and headless simulation harness reports.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `scripts/core/BalanceRegressionReportRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
implementationTargets:
- `tools/run_headless_balance_harness.py`
- `tests/validate_repo.py`
- `docs/headless-balance-harness-cli-report.md`
- `ops/progress.json`
completionCriteria:
- `python3 tools/run_headless_balance_harness.py --suite standard` runs battle autoplay combat balance, balance regression, and headless simulation reports as one command.
- The runner writes `.artifacts/headless_balance_harness_cli/manifest.json` with schema `headless_balance_harness_cli_v1`, per-case command, marker, status, signature, duration, and output log paths.
- The CLI preserves report-only policy checks and does not tune content, write authored content, replace manual playtesting, or claim final combat balance.
- Repository validation gates runner tokens and documentation.
validation:
- `python3 tools/run_headless_balance_harness.py --suite standard`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py tools/run_headless_balance_harness.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No automatic balance tuning.
- No authored content writeback.
- No final combat balance approval.
- No CI provider wiring or platform packaging change.

Completed implementation slice:

id: `content-runtime-overworld-family-allowlist-20260523-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Treat currently authored overworld resource-site and map-object families as first-class runtime content families so Godot reports no longer emit unsupported-family warning spam for valid production content.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/autoload/ContentService.gd`
- `content/resource_sites.json`
- `content/map_objects.json`
implementationTargets:
- `scripts/autoload/ContentService.gd`
- `tests/validate_repo.py`
- `docs/content-runtime-overworld-family-allowlist-report.md`
- `ops/progress.json`
completionCriteria:
- Runtime resource-site validation accepts `staged_resource_front`, `support_producer`, `shrine`, `sign_waypoint`, `scenario_objective`, and `faction_landmark`.
- Runtime map-object validation accepts `staged_resource_front`, `support_producer`, `sign_waypoint`, and `scenario_objective` in addition to the existing authored families.
- Repository validation gates the runtime allowlist and focused report document.
- Focused Godot balance report output contains no `unsupported family` warnings.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_combat_balance_report.tscn`
- `! rg -n "unsupported family|WARNING:" .artifacts/content_runtime_overworld_family_allowlist_battle.log`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No new object interaction mechanics.
- No rare-resource activation.
- No scenario scripting rewrite.
- No generated-map/RMG behavior change.
- No combat balance tuning.

Completed implementation slice:

id: `battle-exit-animation-handoff-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Preserve and present retreat/surrender animation events before terminal battle routing clears the live battle payload.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scripts/core/BattleRules.gd`
- `scenes/battle/BattleBoardView.gd`
- `scenes/battle/BattleShell.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-exit-animation-handoff-report.md`
- `ops/progress.json`
completionCriteria:
- Retreat and surrender actions return a pre-resolution `battle_exit_animation_snapshot` carrying their generated animation states and event queue records.
- `BattleBoardView` can render a presentation snapshot without requiring an active live `session.battle`.
- `BattleShell` locks inputs, shows the exit snapshot briefly, and then routes to the normal battle outcome destination.
- Focused validation proves retreat and surrender actions produce and render their expected exit animation states.
nonGoals:
- No final authored animation timing, camera work, imported VFX/audio assets, or combat balance tuning.
- No save migration or durable battle-state replacement.

Completed owner-directed implementation slice:

id: `battle-vfx-cue-presentation-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Materialize active battle VFX cue ids as visible board-side presentation effects tied to event source/target context.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
- `docs/battle-animation-cue-dispatch-report.md`
implementationTargets:
- `scripts/core/BattleRules.gd`
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-vfx-cue-presentation-report.md`
- `ops/progress.json`
completionCriteria:
- Battle animation events carry source/target stack context where resolved actions have a meaningful source-target relationship.
- Active VFX cue ids resolve to board draw entries with stack coordinates and source/target ids.
- `BattleBoardView` draws visible placeholder VFX for projectile paths, status residue, damage ticks, melee arcs, stack fades, cast anchors, and movement ghosts.
- Focused validation proves ranged/status events produce source-target VFX draw entries and expire with playback.
nonGoals:
- No final imported VFX assets.
- No audio playback, camera motion, screen shake, authored timing curves, or combat balance tuning.

Completed owner-directed implementation slice:

id: `battle-animation-cue-dispatch-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Resolve active battle animation events through the cue catalog at runtime and expose selected VFX/audio placeholder cue ids for board-side presentation playback.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/animation_event_cues.json`
implementationTargets:
- `scenes/battle/BattleBoardView.gd`
- `tests/battle_event_animation_state_report.gd`
- `tests/validate_repo.py`
- `docs/battle-animation-cue-dispatch-report.md`
- `ops/progress.json`
completionCriteria:
- Active battle animation events resolve cue-catalog playback policy through `AnimationCueCatalog.cue_playback_policy_for_event(...)`.
- Board validation summaries expose transient cue playback records with selected VFX/audio cue ids.
- Cue records expire with the existing board-side animation playback lifecycle.
- Focused validation proves ranged/status events dispatch projectile/status VFX placeholders plus audio placeholder ids.
nonGoals:
- No final imported audio/VFX assets.
- No camera, screen shake, authored timing curve, or mixer integration.
- No combat balance tuning.

Completed owner-directed implementation slice:

id: `strategic-ai-live-target-selection-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Move the first strategic AI hero-task surface from report-only evidence into bounded live target selection for new enemy raids.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/strategic-ai-hero-task-state-boundary-plan.md`
- `docs/strategic-ai-live-hero-task-adoption-gate-report.md`
implementationTargets:
- `scripts/core/EnemyAdventureRules.gd`
- `tests/ai_hero_task_live_target_selection_report.gd`
- `tests/ai_hero_task_live_target_selection_report.tscn`
- `docs/strategic-ai-live-target-selection-report.md`
- `ops/progress.json`
completionCriteria:
- New raids with deployable commanders use derived live commander tasks for resource retake/contest/defense target selection before falling back to the global selector.
- Active raid target reservations prevent companion commanders from duplicating the same exclusive resource target.
- No durable `hero_task_state`, save-version bump, route actor rewrite, or save migration is introduced.
nonGoals:
- No full strategic AI quality claim.
- No persistent task-board adoption.
- No broad town/hero/artifact target rewrite.

Completed implementation slice:

id: `strategic-ai-live-turn-execution-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Prove live commander resource-front target selection is executed by the real enemy turn loop and produces map-control consequences without adding durable task state.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/strategic-ai-live-target-selection-report.md`
implementationTargets:
- `tests/ai_hero_task_live_turn_execution_report.gd`
- `tests/ai_hero_task_live_turn_execution_report.tscn`
- `docs/strategic-ai-live-turn-execution-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- `EnemyTurnRules.run_enemy_turn(...)` assigns no-target live commanders to derived resource-front targets through the existing raid advancement path.
- River Pass live-turn validation proves Vaska seizes `river_free_company` while companion reservation steers Sable to `river_signal_post`.
- Both assigned live targets emit `ai_target_assigned` and `ai_site_seized` events through normal arrival resolution.
- No durable `hero_task_state`, save-version bump, save migration, or public event leak is introduced.
nonGoals:
- No full strategic AI quality claim.
- No persistent AI task board.
- No long-route path quality, town/hero/artifact target expansion, or UI surfacing.

Completed implementation slice:

id: `strategic-ai-multi-scenario-pressure-coverage-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Add shared headless evidence that enemy factions across multiple authored scenarios can launch live pressure from controlled enemy towns.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `content/scenarios.json`
- `scripts/core/ScenarioFactory.gd`
- `scripts/core/OverworldRules.gd`
- `scripts/core/EnemyTurnRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/headless_simulation_harness_report.gd`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_multi_scenario_pressure_coverage`.
- The standard headless report primes pressure and runs normal `EnemyTurnRules.run_enemy_turn(...)` coverage for `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `ninefold-confluence`.
- The harness proves all 9 enemy faction cases have an owned controller town, launch live pressure raids, emit `ai_target_assigned`, and keep no durable `hero_task_state`, save migration, or public task/score leaks.
- Prismhearth Watch keeps occupied `halo_spire` as a `faction_mireclaw` controller base even though the town template is Sunvault.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No full strategic AI quality claim.
- No campaign/scenario polish pass.
- No final objective planner, defense rotation, or difficulty tuning.

Completed implementation slice:

id: `headless-strategic-ai-live-turn-harness-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Promote live strategic AI resource-front execution into the shared headless simulation harness so AI-quality regressions are visible in the standard report suite.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/strategic-ai-live-turn-execution-report.md`
implementationTargets:
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/headless_simulation_harness_report.gd`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_turn_execution`.
- The standard headless report runs a real `EnemyTurnRules.run_enemy_turn(...)` live commander fixture.
- The harness asserts both River Pass resource fronts are seized, companion target reservation keeps Vaska/Sable targets unique, and assignment/seizure events exist.
- The harness preserves report-only/no-save boundaries and checks public event output for internal score/task/reservation leaks.
nonGoals:
- No full strategic AI quality claim.
- No automatic tuning or authored content writeback.
- No long-route planning, recruitment grouping, defense rotation, retreat timing, or scenario-breadth completion.

Completed implementation slice:

id: `headless-strategic-ai-live-route-progression-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Add long-route live strategic AI route progression evidence to the shared headless harness instead of only proving on-target resource-front execution.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/headless_simulation_harness_report.gd`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_route_progression`.
- The standard headless report seeds a distant no-target Vaska raid and advances it through repeated `OverworldRules.end_turn(...)` calls.
- The harness proves live AI assigns `river_free_company`, records per-turn `route_records`, reduces `initial_goal_distance` from 9 to `final_goal_distance` 0, and seizes the site for `faction_mireclaw`.
- The harness checks assignment/seizure events, no durable `hero_task_state`, no save migration, and no public event leakage of internal task/score/reservation details.
nonGoals:
- No full strategic AI quality claim.
- No broad path-planning, recruitment grouping, town assault, defense rotation, retreat timing, or scenario-breadth completion.

Completed implementation slice:

id: `strategic-ai-town-defense-retask-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make active strategic AI raid hosts defend threatened same-faction towns before continuing opportunistic pressure.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/strategic-ai-raid-regroup-retreat-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `scripts/core/EnemyAdventureRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/ai_town_defense_retask_report.gd`
- `tests/ai_town_defense_retask_report.tscn`
- `tests/headless_simulation_harness_report.gd`
- `docs/strategic-ai-town-defense-retask-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- Non-understrength active raids detect a stabilizing same-faction enemy town front and retask to town defense before normal target selection.
- Defensive retasks emit compact `ai_target_assigned` events with `town_defense` and `front_stabilization` reason codes.
- Focused and shared headless reports prove the behavior without durable `hero_task_state`, save migration, or public score/task leaks.
nonGoals:
- No full strategic AI quality claim.
- No durable commander task board.
- No broad recruitment grouping, retreat timing, objective planner, or difficulty tuning.

Completed implementation slice:

id: `strategic-ai-live-town-retake-assault-harness-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Add live headless evidence that enemy retake-front town targeting executes through the normal enemy turn and queues a real town-defense battle.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/ai_town_retake_assault_report.gd`
- `tests/ai_town_retake_assault_report.tscn`
- `tests/headless_simulation_harness_report.gd`
- `docs/strategic-ai-town-retake-assault-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- A no-target enemy raid on a player-captured retake-front town assigns `duskfen_bastion` through live strategic target selection.
- The normal enemy turn queues a real `town_defense` battle for the player-held retake-front town.
- Focused and shared headless reports prove the behavior without durable `hero_task_state`, save migration, or public score/task leaks.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_town_retake_assault_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No full strategic AI quality claim.
- No automatic battle resolution tuning.
- No broad objective planner rewrite.

Completed implementation slice:

id: `battle-autoplay-terminal-margin-outlier-calibration-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Calibrate the deterministic battle autoplay matrix so sampled authored encounters no longer produce extreme terminal-health-margin outliers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `content/army_groups.json`
- `content/encounters.json`
- `scripts/core/BattleAutoplayBalanceHarnessRules.gd`
- `tests/battle_autoplay_combat_balance_report.gd`
- `tests/balance_regression_report_suite.gd`
- `tests/headless_simulation_harness_report.gd`
- `docs/battle-autoplay-combat-balance-calibration-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- The deterministic battle autoplay report has zero terminal-margin outliers above the matrix threshold.
- The shared headless simulation harness no longer carries the balance-matrix outlier warning for the default authored battle sample.
- Existing combat-feel gates still pass for sample count, action diversity, damage pacing, outcome distribution, and stalled/invalid-order checks.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No final combat balance approval.
- No automatic tuning or authored encounter writeback system.
- No broad battle AI rewrite.

Completed implementation slice:

id: `strategic-ai-live-raid-assault-grouping-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Add live strategic AI evidence and behavior for nearby same-faction raid hosts consolidating before a shared town assault.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `scripts/core/EnemyAdventureRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/ai_raid_assault_grouping_report.gd`
- `tests/ai_raid_assault_grouping_report.tscn`
- `tests/headless_simulation_harness_report.gd`
- `docs/strategic-ai-raid-assault-grouping-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- Nearby same-faction raid hosts assigned to the same player-held town can consolidate a support host into the assault host before battle resolution.
- The donor host is removed from active raid pressure, the leader army gains the donor stacks, commander continuity is refreshed, and a compact `ai_raid_grouped` public-safe event is emitted.
- Focused and shared headless reports prove the behavior without durable `hero_task_state`, save migration, or public score/task leaks.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_raid_assault_grouping_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/headless_simulation_harness_report.tscn`
- `python3 tests/validate_repo.py`
- `python3 -m py_compile tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
nonGoals:
- No full strategic AI quality claim.
- No multi-commander army board or broad hero-party system.
- No automatic combat balance tuning.

Completed implementation slice:

id: `headless-strategic-ai-live-regroup-retreat-20260523-10184`
phase: `phase-4-headless-ai-agent-balance-harness`
purpose: Promote live understrength raid regroup/retreat behavior into the shared headless simulation harness and public end-turn AI event surface.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/strategic-ai-raid-regroup-retreat-report.md`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
implementationTargets:
- `scripts/core/EnemyAdventureRules.gd`
- `scripts/core/OverworldRules.gd`
- `scripts/core/HeadlessSimulationHarnessRules.gd`
- `tests/headless_simulation_harness_report.gd`
- `docs/headless-strategic-ai-live-turn-harness-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- `HeadlessSimulationHarnessRules.REQUIRED_SUBSYSTEM_IDS` includes `strategic_ai_live_regroup_retreat`.
- The standard headless report seeds an understrength Vaska raid aimed at `river_free_company` and advances it through `OverworldRules.end_turn(...)`.
- The harness proves the raid regroups at `duskfen_bastion`, increases strength, drains spare town garrison, clears its regroup target, and leaves `river_free_company` player-controlled.
- The end-turn public event surface includes high-importance regroup events so `ai_raid_regrouped` is visible without leaking internal task/score/reservation fields.
- The harness checks no durable `hero_task_state`, no save migration, and report-only boundaries.
nonGoals:
- No full strategic AI quality claim.
- No broad defense rotation, multi-hero grouping, town assault planner, recruitment economy rewrite, or difficulty tuning.

Completed implementation slice:

id: `strategic-ai-raid-regroup-retreat-20260523-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add bounded strategic AI retreat/regroup behavior so damaged active raids can rebuild at owned towns before resuming pressure.
sourceDocs:
- `project.md`
- `PLAN.md`
implementationTargets:
- `scripts/core/EnemyAdventureRules.gd`
- `tests/ai_raid_regroup_retreat_report.gd`
- `tests/ai_raid_regroup_retreat_report.tscn`
- `docs/strategic-ai-raid-regroup-retreat-report.md`
- `tests/validate_repo.py`
- `ops/progress.json`
completionCriteria:
- Understrength active raids can choose a regroup target at a reachable owned matching-faction town.
- Regroup arrival transfers spare town garrison units into the raid host and synchronizes commander army state.
- Regroup/retarget events remain public-safe and the behavior does not migrate saves or bump `SAVE_VERSION`.
- Focused validation proves the River Pass Vaska raid regroups at Duskfen Bastion and does not capture its original resource objective on that turn.
nonGoals:
- No full strategic AI quality claim.
- No broad enemy economy planner, town-defense rewrite, multi-hero grouping rewrite, or difficulty tuning.

### Phase 4 - Headless AI Agent Balance Harness

Goal: create non-graphical agent/test loops for scenarios, AI turns, economy, battles, balance checks, save/load, and regression detection.

Closed tactical slices:
- `headless-agent-simulation-harness-10184`
- `balance-regression-report-suite-10184`

Future work should be selected only when new gameplay/content systems need harness coverage or balance evidence.

### Phase 5 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Paused tactical slices:

id: `playable-alpha-scenario-set-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Build a small validated scenario/skirmish set after Phase 3 RMG rework and Phase 4 harness foundations are deliberately selected for alpha assembly.
sourceDocs:
- `project.md`
- relevant scenario, faction, economy, AI, town, battle, and RMG docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused Godot smoke/regression scenes selected at kickoff
completionCriteria:
- Multiple setups can be started, played, saved/resumed, won/lost, and understood without developer interpretation.
- At least two factions have enough live distinction to support repeated play.
nonGoals:
- No release claim.
- No content-breadth claim based only on JSON volume.

id: `playable-alpha-ux-onboarding-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Make the selected alpha setups understandable through compact player-facing UX rather than debug/report panels.
sourceDocs:
- `project.md`
- selected UX/onboarding docs or audit produced at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused UI smoke/regression scenes selected at kickoff
completionCriteria:
- New/returning players can launch, choose setup, understand objectives, read core controls, and recover from common mistakes.
- Debug/profile/report surfaces stay optional and non-primary.
nonGoals:
- No giant dashboard substitution for missing mechanics.
- No broad polish pass outside selected alpha paths.

### Phase 6 - Production Alpha Layer

Goal: expand the playable alpha into a production-shaped game slice.

Closed tactical slices:
- `packaging-platform-readiness-20260523-10184`
- `packaging-pack-export-smoke-20260523-10184`
- `packaged-settings-persistence-smoke-20260523-10184`
- `packaged-runtime-issue-log-smoke-20260523-10184`
- `packaging-release-bundle-manifest-gate-20260524-10184`

Paused tactical slices:

id: `production-alpha-content-expansion-10184`
phase: `phase-6-production-alpha-layer`
purpose: Add more factions/content through established systems and validation gates.
sourceDocs:
- `project.md`
- content/faction/scenario docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused content/schema/smoke checks selected at kickoff
completionCriteria:
- New content enters live play through validated mechanics, AI, economy, scenario, save/load, and UI surfaces.
nonGoals:
- No raw content dump.
- No unvalidated asset ingestion.

id: `production-alpha-packaging-settings-performance-10184`
phase: `phase-6-production-alpha-layer`
purpose: Establish packaging, settings, accessibility, and performance requirements for a production alpha.
sourceDocs:
- `project.md`
- selected packaging/settings/accessibility/performance docs or audits
baselineChecks:
- `python3 tests/validate_repo.py`
- platform/performance checks selected at kickoff
completionCriteria:
- Required settings, accessibility boundaries, performance budgets, and packaging targets are explicit and validated for the selected alpha scope.
nonGoals:
- No release readiness claim.
- No platform promise without tested artifact evidence.

### Phase 7 - Broad Production Breadth

Goal: broaden into a full original fantasy strategy package after alpha foundations hold.

Long-horizon tracks:
- broad faction/town/unit/content breadth;
- broader map, campaign, skirmish, and replayability breadth;
- deeper AI/balance/polish/content pipeline maturity.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or AcOrP explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape after this compaction:
- PLAN contains compact tactical gates and future selectable slices.
- Completed implementation/report evidence remains in `ops/progress.json` and `docs/*.md`.
- `sync-plan --dry-run` should report only PLAN ids that already exist in active progress entries.
