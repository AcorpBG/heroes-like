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
- Test, report, audit, and export tooling should be Python-owned. GDScript should be reserved for live game/runtime behavior, not validation/report launchers.

## Current Tactical State

Current phase: **Phase 6 - Production Alpha Layer**.

- Completed implementation slice: `ux-battle-order-tab-compact-initiative-summary-10184`. The Battle Order tab now shows a contained three-line Initiative/Now/Next summary at 1280x720 and 1920x1080 while its existing tooltip retains the exact full handoff and ordered technical track. Focused Battle board/navigation, visual, tab/focus, animation, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged Battle interaction, controller hardware, certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `ux-battle-order-tab-compact-initiative-summary-10184`
- Completed implementation slice: `ux-main-menu-editor-utility-command-frame-10184`. The Main Menu now preserves its five authored transparent plaque hotspots while the Editor command alone uses the existing secondary normal/hover/pressed/disabled texture frame in the previously unpainted utility gap. Focused 1280x720/1920x1080 geometry and asset proof, menu/outcome, keyboard/controller navigation, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged Editor interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `ux-main-menu-editor-utility-command-frame-10184`
- Completed implementation slice: `content-veilmourn-fogchart-mooring-chapter-10184`. The active catalog now contains twenty campaign/skirmish scenarios, including Veilmourn's Fogchart Mooring chapter with Ruln Vanehook and the Bellwake Privateers defending the previously unused mooring against Sunvault's Halo registry front. Frontier Claims now has five chapters; exact Rootgate victory evidence unlocks Fogchart and imports only bounded common resources and flags, with all six rare resources explicitly capped at zero and no Thornwake hero progression, spells, or artifacts transferred. Real standalone/campaign launch, objective victory and Day 13 defeat, save/resume, 65-encounter queue-clear combat breadth, resource-route and town-development breadth, strategic-AI recruitment/delivery, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `content-veilmourn-fogchart-mooring-chapter-10184`
- Completed implementation slice: `content-thornwake-rootgate-toll-chapter-10184`. The active catalog now contains nineteen campaign/skirmish scenarios, including Thornwake's new Rootgate Toll chapter with Tova Rootwright and the Graftroot Wardens defending Rootgate Nursery against the Clauseworks toll line. Frontier Claims now has four chapters; exact Bellwake victory evidence unlocks Rootgate Toll and imports only bounded resources and flags, never Veilmourn hero progression, spells, or artifacts. Real standalone/campaign launch, objective victory and Day 12 defeat, save/resume, 62-encounter combat breadth with a clear queue, resource-route and town-development breadth, strategic-AI recruitment/delivery, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `content-thornwake-rootgate-toll-chapter-10184`
- Completed implementation slice: `ux-overworld-terminal-end-turn-detached-focus-guard-10184`. The warned End Turn dialog now relies solely on its existing visibility-and-pending guarded next-frame cancel-focus path; the redundant raw deferred cancel-button focus that could execute after terminal routing detached the Overworld is gone. Focused same-stack confirmation/detach proof preserves exact rules, autosave, and session authority, while the real nine-step skirmish defeat flow reaches, saves, leaves, resumes, and leaves Scenario Outcome without detached-focus diagnostics. Ordinary cancel/confirm/stale/low-risk behavior, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged End Turn interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `ux-overworld-terminal-end-turn-detached-focus-guard-10184`
- Completed implementation slice: `economy-town-capital-project-identity-correction-10184`. Capital-project discovery now accepts only explicit nonempty `capital_project` metadata, so Highwater, Nightglass, and Prismhearth each expose their one authored project while Graftroot and Orevein expose none. Real starting capitals remain inactive with zero synthetic project effects and name their actual first dependency; detached 4/4 completion activates only the authored project values/support vulnerability and survives save normalization. Planned-task recruitment, strategic planning, all-town development/recruitment, town balance, a 56-turn native Medium strategic row, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged capital-project interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `economy-town-capital-project-identity-correction-10184`
- Completed implementation slice: `presentation-overworld-encounter-victory-return-feedback-10184`. Real victories over source-validated static encounters now carry detached encounter placement/content/tile identity through the durable Battle-to-Overworld route and publish one exact existing `overworld_object_depleted` consequence on the next Overworld scene. Focused 1280x720/1920x1080 River Pass movement battles resolve `river_pass_hollow_mire`, preserve the guarded `duskfen_bastion_peatwax_front` resource byte-exact, save successfully, consume the cue once, and remain silent for malformed, stale, terminal, unresolved, missing/mutated identity, spawned-raid, non-victory, assault, wrong-surface, refresh, and later-scene controls. Quick-resolve, guarded-site, town/resource return, object-resolution, checkpoint, keyboard focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged encounter interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-encounter-victory-return-feedback-10184`
- Completed implementation slice: `presentation-overworld-resource-assault-victory-return-feedback-10184`. Real victories over a strategically stationed resource defender now carry one validated route-local `resource_site` consequence only after the resolved checkpoint saves, and the exact next Overworld scene consumes it once through the existing persistent-resource capture presenter. Focused 1280x720/1920x1080 public collector battles at Riverwatch Free Company Yard publish the authored capture VFX/audio while preserving control, defender/commander, battle, save, and session authority; malformed, stale, wrong-site/controller/context/surface, nonpersistent, terminal, refresh, and later-scene controls remain silent. Resource-defense, hostile-town return, object-resolution, checkpoint failure/retry, quick-resolve, keyboard focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged resource-assault interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-resource-assault-victory-return-feedback-10184`
- Completed implementation slice: `presentation-town-army-transfer-completion-feedback-10184`. Successful public Town `transfer:<source_holder>:<target_holder>:<unit_id>:<amount>` actions now publish one compact nonblocking TownStage completion only after proving the exact source decrease, target increase, conserved unit total, stationed holder identities, result recap, and active-hero mirror. The semantic cue uses the existing imported UI-confirm audio and compact procedural roster movement with an exact reduced-motion fallback. Eight focused 1280x720/1920x1080 normal/reduced garrison-to-hero and hero-to-garrison rows pass with whole-session TownRules parity and malformed, stale, repeated, invalid, and refresh silence. Transfer/rendezvous, cue/audio, keyboard-focus, Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged transfer interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-army-transfer-completion-feedback-10184`
- Completed implementation slice: `presentation-town-specialty-selection-feedback-10184`. Successful public Town `choose_specialty:<specialty_id>` actions now publish one compact nonblocking TownStage completion only after proving the exact active-hero specialty rank increase, pending-choice consumption, hero identity, result recap, and active-hero mirror. The semantic cue uses the existing imported UI-confirm audio and a compact procedural specialty-rank badge with an exact reduced-motion fallback. Four focused 1280x720/1920x1080 normal/reduced rows pass with whole-session TownRules parity and malformed, refresh, stale, and invalid silence; all 12 compatibility owners, repository/editor checks, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged specialty interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-specialty-selection-feedback-10184`
- Completed implementation slice: `presentation-town-artifact-action-feedback-10184`. Successful public Town commission, equip, and stow actions now publish compact TownStage feedback through the existing artifact-acquired/equipped/unequipped cue policies, production artifact icons, and deterministic audio only after exact reward, provenance, spend, inventory/equipment, slot, and recap authority is proven. Six focused 1280x720/1920x1080 normal, missing-icon, and reduced-motion rows pass with method-equivalent TownRules controls and failed, stale, unaffordable, repeated, malformed, and refresh silence. Artifact commission/icon/runtime, Overworld artifact audio ordering, Town cue/visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged artifact interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-artifact-action-feedback-10184`
- Completed implementation slice: `presentation-town-hero-hire-completion-feedback-10184`. Successful live Town-screen `hire_hero:<hero_id>` orders now publish one compact Town-specific commander-arrival completion through the existing TownStage action presenter, derived from the exact one-hero roster increase and resource spend and carrying an original imported alpha VFX, deterministic 420 ms stereo sound, and exact reduced-motion/missing-asset fallbacks. Six focused 1280x720/1920x1080 public-handler rows prove whole-session TownRules parity, exact recruited-hero identity, unchanged active hero, imported WAV playback, and malformed/unavailable/repeated/refresh silence. Town VFX/cue/action, animation catalog, broad Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged hire interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-hero-hire-completion-feedback-10184`
- Completed implementation slice: `presentation-town-spell-study-completion-feedback-10184`. Successful live Town-screen `learn_spell:<spell_id>` orders now publish one compact Town-specific archive-study completion through the existing TownStage action presenter, derived from the exact active-hero spellbook transition and carrying an original imported alpha VFX, deterministic 400 ms stereo sound, and exact reduced-motion/missing-asset fallbacks. Six focused 1280x720/1920x1080 public-handler rows prove whole-session TownRules parity, one newly learned spell, unchanged mana, mirrored active-hero authority, imported WAV playback, and malformed/already-known/refresh silence. Spell-school icon, Town VFX/cue/route/market, animation catalog, broad Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged study interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-spell-study-completion-feedback-10184`
- Completed implementation slice: `presentation-town-market-exchange-completion-feedback-10184`. Successful live Town-screen `market:<buy|sell>:<wood|ore>:<amount>` orders now publish one compact Town-specific exchange-completion presentation through the existing TownStage action presenter, derived from exact ordered before/after stockpile deltas and carrying an original imported alpha VFX, deterministic 360 ms stereo sound, and exact reduced-motion/missing-asset fallbacks. Six focused 1280x720/1920x1080 public-handler rows prove buy/sell rule-control session parity, weekly-cap authority, exact signed gold/resource deltas, one imported audio record, and malformed/invalid silence. Market-cap, Town VFX/cue/route, animation catalog, broad Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged exchange interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-market-exchange-completion-feedback-10184`
- Completed implementation slice: `presentation-town-route-response-dispatch-feedback-10184`. A successful live Town-screen `site_response:<placement>` order now publishes one compact Town-specific strategic-dispatch presentation through the existing TownStage action presenter, with an original imported alpha VFX, deterministic 380 ms stereo sound, and exact reduced-motion/missing-asset fallbacks. The presenter verifies the live route node, Town origin, same-day provenance, and active response after the authoritative mutation and refreshed stage; malformed and repeated unavailable orders remain silent. Focused six-row 1280x720/1920x1080 proof plus Town VFX/cue, animation catalog, broad Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged Town interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-route-response-dispatch-feedback-10184`
- Completed implementation slice: `presentation-overworld-route-expiry-feedback-10184`. A successful end turn now captures a player response route on its exact final active day, validates the same visible site after rule mutation and autosave, and publishes one `overworld_route_closed` cue only when the day transition naturally deactivates its transit edge. The route keeps player control and its persisted response provenance; enemy seizure closure retains priority, and non-final, already-expired, malformed, refresh, and duplicate controls stay silent. Focused 1280x720/1920x1080 proof plus enemy-closure/open-route, Rope Lift, shared cue, accessibility, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged expiry interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-route-expiry-feedback-10184`
- Completed implementation slice: `presentation-overworld-enemy-route-closure-feedback-10184`. A real enemy resource seizure now adds the exact compact `route_closed` reason only when it interrupts a still-active player response route, and the successful live end-turn/autosave path publishes one authored `overworld_route_closed` cue at the visible seized site. The cue uses an original imported alpha VFX, deterministic 440 ms stereo sound, static reduced-motion icon, and distinct missing-asset gate fallback. Focused 1280x720/1920x1080 live enemy-turn proof preserves the exact `ai_site_seized` event, controller transfer, response clear, transit edge 1->0, save/session authority, and duplicate silence; inactive-route control, Rope Lift, shared cue/VFX, accessibility, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Natural expiry, Town-screen response presentation, packaged interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-enemy-route-closure-feedback-10184`
- Completed implementation slice: `presentation-overworld-field-route-response-open-feedback-10184`. A successful live field `site_response` now publishes one exact, deduped `overworld_route_open` presentation through the existing Shell/MapView queue, with an original imported alpha VFX, deterministic 420 ms stereo production-layer sound, and distinct reduced-motion and missing-asset fallbacks. Focused 1280x720/1920x1080 proof preserves the exact Rope Lift cost, movement, active transit edge, refresh/duplicate silence, session/save authority, and cue identity; transit, shared object-resolution/audio, object-blocked, catalog, accessibility, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Town-screen response presentation, enemy-driven route closure, packaged interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-field-route-response-open-feedback-10184`
- Completed implementation slice: `strategic-ai-battle-pressure-near-objective-commitment-10184`. After the existing understrength/regroup authority, battle-pressure-floor selection now retains only a still-valid resource, artifact, or encounter target whose refreshed route distance is 0 or 1. The original live route now seizes `river_free_company` in 7 turns instead of abandoning it at distance 1, while the exact distance-2 reciprocal still preempts to the player town and long-range, blocked-frontier, neutral-fallback, target/task/session/public-event behavior remains intact. Focused, full headless product harness, strategic compatibility, Medium ordinal-100 health, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged strategic-AI interaction, broad balance/policy changes, Native RMG topology/parity, hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `strategic-ai-battle-pressure-near-objective-commitment-10184`
- Completed implementation slice: `presentation-overworld-guarded-site-production-audio-playback-10184`. Selected guarded resource sites now thread their exact detached `audio_placeholder_guard_warning` identity through the live Shell and play one original deterministic 44.1 kHz stereo 16-bit warning transient only after MapView accepts the complete guarded context. Context-signature ownership prevents unchanged-refresh replay; deselection, guard resolution, malformed/invalid context, and clear stay silent, while a real reselection plays once again. Focused real context and 1280x720/1920x1080 imported/missing/reduced-motion reports preserve guard/resource/route, selection/focus/input, VFX, settings/session/save, service, and other-audio authority; compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass, and both PCKs contain the asset. Blocked-object and route-open/closed audio, final sound design, packaged guarded-site interaction/listening, hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-guarded-site-production-audio-playback-10184`
- Completed implementation slice: `presentation-overworld-object-resolution-production-audio-playback-10184`. Successful visited, captured, and depleted Overworld object outcomes now thread their exact catalog-selected VFX/audio identities through the live Shell and play distinct original deterministic 44.1 kHz stereo 16-bit visit/capture/collect transients exactly once when immediate or route-queued MapView presentation becomes active. Real resource capture, repeatable visit/revisit/cooldown, neutral-town capture, artifact depletion, reduced-motion, refresh, and unsupported-move cases preserve object/resource/artifact/town consequences, route locomotion order, serial/lifetime, dynamic-layer VFX timing/fallback, session/save/input/focus/settings, and other audio. Focused live and 1280x720/1920x1080 asset/fallback reports, route/cue/visual/focus/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass; both PCKs contain all three assets. Guarded/blocked/route-open/closed audio, final sound design, packaged object interaction/listening, hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-object-resolution-production-audio-playback-10184`
- Completed implementation slice: `presentation-overworld-navigation-production-audio-playback-10184`. Successful full-route hero movement and newly rejected route decisions now play their exact existing `audio_placeholder_map_step` and `audio_placeholder_invalid_route` identities once through the reusable Effects-bus service, only after `OverworldMapView` accepts the complete path/final hero or blocked tile/reason. Two byte-distinct original deterministic 44.1 kHz stereo 16-bit transients preserve routing, movement points, action results, serial/signature dedupe, VFX/timing, refresh, focus/input/motion/settings, and session/save authority; duplicate serials, unchanged blocked reselection, refresh, malformed clear, and failed routes never replay. Focused and real full-route 1280x720/1920x1080, cue catalog, active-play focus, Overworld visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass, and both PCKs contain both assets. Per-tile repeated footsteps, route/object/guard audio expansion, final sound design, packaged listening/interaction, hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-navigation-production-audio-playback-10184`
- Completed implementation slice: `presentation-system-save-load-production-audio-playback-10184`. Successful manual saves and routed load/resume now play their exact existing cue identities once through the reusable Effects-bus presentation-audio service. Two byte-distinct original deterministic 44.1 kHz stereo 16-bit transients preserve the established policies while confirmation-pending, canceled, stale, malformed, duplicate-consume, refresh, and expiry paths never replay. Focused real save/load across Overworld, Town, Battle, and Outcome at 1280x720 and 1920x1080 preserves slot/path/summary/continuity, routing, pending consumption, focus/input/motion/settings, save bytes/schema, and session authority; cue catalog, active-play focus, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass, and both PCKs contain both assets. Final sound-design/mixer-mastering approval, other placeholder audio identities, packaged save/load interaction/listening, audio hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-system-save-load-production-audio-playback-10184`
- Completed implementation slice: `presentation-overworld-action-production-audio-playback-10184`. Successful live Overworld field spells, artifact recovery/equip/stow, and resource collection now play their five exact existing cue identities once through the reusable Effects-bus presentation-audio service. Five byte-distinct original deterministic 44.1 kHz stereo 16-bit transients preserve the established policy ids while malformed/failed actions remain silent and refresh/expiry/skip never replay. Focused real actions at 1280x720 and 1920x1080 preserve spell, artifact, resource, presentation, input/focus/motion, settings, and session authority; cue catalog, active-play focus, Overworld visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass, and both PCKs contain all five assets. Final sound-design/mixer-mastering approval, other placeholder audio identities, packaged Overworld interaction/listening, audio hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-action-production-audio-playback-10184`
- Completed implementation slice: `presentation-town-action-production-audio-playback-10184`. Successful live Town construction and recruitment now play the exact existing `audio_placeholder_town_build` and `audio_placeholder_recruit` cue identities once through a reusable Effects-bus presentation-audio service. Two distinct original deterministic 44.1 kHz stereo 16-bit production transients retain the existing policy ids while malformed payloads stay silent, missing imports use deterministic generated fallback, Effects mute and six/three voice budgets remain exact, and refresh/expiry never replay. Focused real actions at 1280x720 and 1920x1080 preserve independent construction/recruitment, presentation serial/lifetime, input, focus, motion settings, session/settings authority; Town/Battle visual, cue catalog, active-play focus, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass. Final sound-design/mixer-mastering approval, other placeholder audio identities, packaged Town interaction/listening, audio hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-action-production-audio-playback-10184`
- Completed implementation slice: `presentation-ui-production-sfx-fidelity-10184`. The complete six-cue live UI click, select, adjust, tab, confirm, and invalid pack now uses six byte-distinct original deterministic 44.1 kHz stereo 16-bit production transients with cue-specific latch, glass-pluck, ratchet, page-turn, seal-chime, and wooden-denial identities. Exact cue ids, paths, roles, durations, volumes, common-control attachment, Effects-bus/mute policy, eight/four-player voice budgets, reduced-repetition cooldowns, generated fallback, settings, input, and gameplay authority remain unchanged. Focused real-control/fallback, active-play/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass; both PCKs contain all six UI assets. Final sound-design/mixer-mastering approval, new cue ids, packaged listening, hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-ui-production-sfx-fidelity-10184`
- Completed implementation slice: `presentation-overworld-ambient-production-loop-fidelity-10184`. The complete eleven-cue Overworld terrain, enemy-pressure, and day-pulse ambience pack now uses eleven byte-distinct original deterministic seamless 12-second 44.1 kHz stereo 16-bit production loops. Imported WAVs play through detached forward-loop clones, keep all three active terrain/pressure/day layers alive beyond a full segment, avoid restarting unchanged signatures, and preserve exact cue ids, paths, roles, volumes, context selection, four-player cap, Effects-bus/mute policy, generated fallback, shell synchronization, settings, save, and gameplay authority. Focused continuity/fallback, active-play/Overworld/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass; both PCKs contain all eleven ambient assets. Final sound-design/mixer-mastering approval, new ambience contexts, packaged listening, audio hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-ambient-production-loop-fidelity-10184`
- Completed implementation slice: `presentation-music-production-loop-fidelity-10184`. The complete twelve-layer menu, overworld, battle, and outcome music pack now uses twelve byte-distinct original deterministic seamless 8-second 44.1 kHz stereo 16-bit layered stems. Imported WAVs play through detached forward-loop clones, retain all three active layers beyond a full segment, avoid restarting unchanged signatures, and preserve exact cue ids, paths, roles, volumes, context routing, Music-bus/mute policy, generated fallback, shell routing, settings, save, and gameplay authority. Focused continuity/fallback, active-play/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass; both PCKs contain all twelve music assets. Final composition/mastering approval, soundtrack expansion, licensed music, packaged listening, audio hardware certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-music-production-loop-fidelity-10184`
- Completed implementation slice: `presentation-battle-production-sfx-fidelity-10184`. The complete existing 21-cue Battle WAV pack now uses 21 byte-distinct original deterministic layered 44.1 kHz stereo 16-bit assets while preserving exact cue ids, paths, durations, volumes, roles, priorities, cooldowns, Effects-bus routing, eight-voice admission/eviction, mute/reduced-repetition policy, generated fallback, event order, and combat authority. Focused all-cue imported playback plus fallback, cue-catalog/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass; both PCKs contain all 21 assets. Final sound-design approval, mastering/hardware certification, packaged Battle listening, music/ambience/UI audio work, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-battle-production-sfx-fidelity-10184`
- Completed implementation slice: `presentation-battle-core-vfx-semantic-distinction-10184`. The eight live core Battle VFX cues now map one-to-one to distinct original imported alpha textures for projectile travel, damage impact, melee, retaliation, cast anchor, status residue, status clear, and brace. Exact cue ids, render modes, source/target/progress records, procedural fallback, timing, reduced-motion/reduced-flash behavior, input, accessibility, and combat authority remain unchanged. Focused all-eight live playback, inspected 1280x720/1920x1080 captures, cue catalog, Board navigation, accessibility, core, routed 1280 layout/save/menu compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass. Packaged Battle interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-battle-core-vfx-semantic-distinction-10184`
- Completed implementation slice: `presentation-active-play-system-feedback-vfx-asset-adoption-10184`. Save-written and load-resumed feedback now renders two distinct original imported alpha effects through one fail-closed, layout-neutral shared renderer inside the visible Save button on Overworld, Town, Battle, and Scenario Outcome. Normal and reduced-motion live save/load matrices pass at both 1280x720 and 1920x1080 with exact text/tint, focus, expiry, session/settings/save authority, while reduced motion and missing assets remain text/tint-only. Compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged save/load interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-active-play-system-feedback-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-action-feedback-vfx-asset-adoption-10184`. Artifact recovery, artifact equip, artifact stow, and resource collection now render four distinct original imported alpha effects inside the existing bottom CueChip and ResourceChip overlays. Normal motion uses the exact existing cue identities; reduced motion and missing assets remain text-only. Focused 1280x720/1920x1080, real action authority, eleven-cue VFX compatibility, broad Overworld visual/input/focus/accessibility/core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged action interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-action-feedback-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-hero-route-step-vfx-asset-adoption-10184`. Normal live hero-route playback now draws one original imported alpha dust-and-rune trail behind the unchanged interpolated hero marker through the exact existing `vfx_placeholder_route_step` cue. The renderer rotates the effect with the current route segment and preserves exact route execution, hero identity/grounding, bounded timing, dynamic-layer lifecycle, marker-only missing-map/missing-texture fallback, and zero-duration reduced-motion endpoint snap. Focused 1280x720/1920x1080, real full-route, seven-cue Overworld VFX manifest, visual/input/focus/accessibility/core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged route interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-hero-route-step-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-route-blocked-vfx-asset-adoption-10184`. Normal live blocked-route playback now draws one original imported alpha warning sigil through the exact existing `vfx_placeholder_blocked_route_marker` cue. The renderer preserves exact route authority, blocked reason, serial/dedupe, bounded timing, dynamic-layer lifecycle, and the prior procedural circle-and-X as missing-map/missing-texture fallback, while reduced motion retains the static `blocked_route_icon`. Focused 1280x720/1920x1080, real blocked/reachable selection, six-cue Overworld VFX manifest, visual/input/focus/accessibility/core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged blocked-route interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-route-blocked-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-guarded-site-vfx-asset-adoption-10184`. Selecting a real unresolved guarded site now draws one original imported alpha warning effect at the authoritative selected tile through the exact existing `vfx_placeholder_guard_warning` cue. The renderer preserves exact site/guard identity, inspection/link copy, context-visible lifecycle, dynamic-layer ownership, and the prior procedural shield as missing-map/missing-texture fallback, while reduced motion retains the static guard badge. Focused 1280x720/1920x1080, real guarded selection/lifecycle, five-cue Overworld VFX manifest, object/spell VFX, guarded reward, Overworld visual/route/input, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged guarded-site interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-guarded-site-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-field-spell-vfx-asset-adoption-10184`. Normal live field-spell playback now draws one original imported alpha arcane waypoint effect at the authoritative hero tile through the exact existing `vfx_placeholder_adventure_spell` cue. The renderer preserves exact spell consequences, bounded progress/alpha/input-blocking lifetime, refresh/skip/expiry/focus behavior, and the prior two rings as missing-map/missing-texture fallback, while reduced motion retains the static nonblocking icon. Focused 1280x720/1920x1080, real field-spell cue, four-cue object/VFX manifest, Overworld visual/route/input, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged field-spell interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-field-spell-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-town-recruitment-vfx-asset-adoption-10184`. Successful live recruitment now draws one original imported alpha muster effect behind the unchanged contained count badge. The renderer preserves exact recruitment consequences, progress/alpha/nonblocking lifetime, refresh/expiry/focus behavior, and the prior three rings as missing-map/missing-texture fallback, while reduced motion retains the static badge. Focused 1280x720/1920x1080, real recruitment cue, construction cue/asset, Town/Battle visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged recruitment interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-recruitment-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-town-building-complete-vfx-asset-adoption-10184`. Normal live construction completion now draws one original imported alpha texture behind the unchanged contained Town badge/text. The renderer preserves exact building consequences, bounded progress/alpha/input-blocking lifetime, skip/expiry/focus behavior, and the prior gold frame as missing-map/missing-texture fallback, while reduced motion retains the static nonblocking badge. Focused 1280x720/1920x1080, real construction cue, Town/Battle visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged building interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-building-complete-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-object-resolution-vfx-asset-adoption-10184`. Capture, visited, and depleted object-resolution events now map one-to-one to three distinct original imported alpha textures through an exact local manifest. The live renderer retains the authoritative tile, bounded progress/alpha/motion behavior, reduced-motion policy, dynamic-layer ownership, and the prior procedural bodies as fail-closed missing-map/missing-texture fallback. Focused 1280x720/1920x1080, object-resolution playback, full-route movement, broad Overworld visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged object interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-object-resolution-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-overworld-enemy-commander-sprite-adoption-10184`. Live strategic-raid encounters now show the exact existing faction commander sprite when roster hero, commander faction, spawning faction, and authored hero faction agree. The renderer retains the hostile encounter ring, grounding/contact treatment, fog/memory behavior, and exact unit-icon then encounter-sprite fallback for absent, unknown, mismatched, or unloadable identity. Focused 1280x720/1920x1080, commander selection, hero hunt, full-route movement, broad Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged strategic-raid interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-enemy-commander-sprite-adoption-10184`
- Completed implementation slice: `presentation-overworld-faction-hero-sprite-adoption-10184`. All 60 production commanders now resolve through their existing faction metadata to one of six distinct original 512x512 Overworld sprites. The live renderer preserves active identity during route interpolation, reserve badges, existing grounding/contact, selection, routing, session, and save version 9 authority, while the procedural figure remains the fail-closed fallback. Focused 1280x720/1920x1080, full-route movement, Ninefold, broad Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged hero interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-faction-hero-sprite-adoption-10184`
- Completed implementation slice: `presentation-overworld-artifact-pickup-icon-adoption-10184`. All 12 production artifact pickups now render their exact existing imported icon on the live Overworld instead of sharing `adventurers_bundle`. The renderer retains the generic bundle only for invalid or unloadable identity and preserves the existing 1x1 footprint, localized grounding, current explored/visible treatment, selection, collection/depletion, fog, route, session, and save version 9 authority. Focused 1280x720/1920x1080, pickup source, object-resolution, broad visual, focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged artifact interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-artifact-pickup-icon-adoption-10184`
- Completed implementation slice: `presentation-overworld-faction-town-sprite-adoption-10184`. All 15 authored towns now resolve through their exact template faction to one of six distinct original 512x512 Overworld town sprites. The existing draw path preserves the 3x2 footprint, bottom-middle entry, grounding, owner pennant/color, visible/remembered treatment, selection, routing, passability, session, and save authority, while `frontier_town` remains the fail-closed fallback. Focused 1280x720/1920x1080, Ninefold, Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged Overworld interaction, hardware/certification, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-faction-town-sprite-adoption-10184`
- Completed implementation slice: `presentation-town-faction-crest-adoption-10184`. The six production factions now own distinct original 256x256 imported crests through an exact manifest and fail-closed resolver. Real Town shells render the active faction crest inside the existing 74x50 medallion at 1280x720 and 1920x1080, keep the 42x40 icon contained, retain the procedural `town` glyph for unknown identity, and preserve Town layout, focus, actions, session, route, and save version 9. Focused, all-faction Town/save, Town visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged Town interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-faction-crest-adoption-10184`
- Completed implementation slice: `ux-shared-resource-stockpile-icon-popover-10184`. One shared focusable native menu now exposes the exact nine live stockpile resources, current amounts, and original icons on the existing Town top bar and Overworld command band. It preserves the existing summary and full-ledger tooltip, opens and closes through public keyboard input, returns focus only after Escape, remains contained at 1280x720 and 1920x1080, and leaves session, economy, save, action, route, and layout authority unchanged. The compact 1280 Overworld form is an 80px `Stores` button inside the existing 96px resource chip. Focused, Town economy, Overworld visual, keyboard focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Packaged popover interaction, hardware/certification, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `ux-shared-resource-stockpile-icon-popover-10184`
- Completed implementation slice: `economy-production-resource-registry-collection-icon-adoption-10184`. The nine live stockpile resources now own exact production metadata and distinct original imported 128x128 material icons. Existing compact Overworld collection actions resolve the selected site's distinctive non-gold claim resource, falling back to gold, and load that exact icon fail-closed while preserving action copy, order, focus, collection consequences, recap, resource-delta cue, session authority, and save version 9 at 1280x720 and 1920x1080. Live stockpile, all active rare-source collection/income, Town economy, Overworld visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass. Market/economy/site/source/AI/save changes, a broad resource-bar redesign, packaged collection interaction, certification, whole-game, and release readiness remain out of scope. Select the next tracker-approved release-readiness implementation slice.
  id: `economy-production-resource-registry-collection-icon-adoption-10184`
- Completed implementation slice: `presentation-town-building-category-sigil-adoption-10184`. All 133 production buildings now resolve through their existing category to one of five distinct original construction sigils. The selectable Town Build options load the exact civic, dwelling, economy, support, or magic sigil fail-closed while preserving selection, readiness, tooltip, order, focus, containment, and real construction consequences at 1280x720 and 1920x1080. Focused construction, building cue, all-town save/resume, Town/Battle visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Unique per-building illustrations, building/economy/balance/save/AI changes, packaged interaction, hardware/certification, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-town-building-category-sigil-adoption-10184`
- Completed implementation slice: `presentation-live-spell-school-sigil-adoption-10184`. All 112 shipped spells now resolve through their existing school id to one of seven distinct original imported material-language sigils. The existing compact Overworld cast, Town study, and Battle cast buttons load the exact school sigil fail-closed while preserving copy, tooltips, order, disabled state, focus, containment, and real action consequences at 1280x720 and 1920x1080. Focused real cast/learn/cast, magic/Town/Battle compatibility, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Per-spell illustrations, spell balance/rules/content, save schema, AI, new panels, packaged spell interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-live-spell-school-sigil-adoption-10184`
- Completed implementation slice: `presentation-authored-artifact-icon-adoption-10184`. All 12 production artifacts now own distinct original painted icons and stable non-placeholder metadata. The existing compact Overworld Command and Town Logistics gear buttons resolve only the exact equipped or packed artifact already owned by each action, load its imported icon fail-closed, and preserve real equip/stow, session, save, copy, tooltip, focus, and ordering authority at 1280x720 and 1920x1080. The Town artifact lane is now first in Logistics so the live buttons remain visible and contained. Focused, artifact compatibility, Town/Battle visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Packaged artifact interaction, final artifact VFX/audio, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-authored-artifact-icon-adoption-10184`
- Completed implementation slice: `overworld-ninefold-rope-lift-live-transit-10184`. Ninefold Confluence's existing `Reeve Rope Lift` response now opens the exact authored two-way land shortcut between 9,51 and 9,54 for its four-day active window. The live player BFS previews it as one movement, full route execution independently revalidates it, activation/expiry changes invalidate cached routes, and malformed, unclaimed, enemy, unsafe, expired, unaffordable, or movement-exhausted cases remain closed. Focused 1280x720/1920x1080 live proof, save normalization, full/cached route, terrain, controller, Ninefold, metadata, AI valuation, core, save/load, focus, accessibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Ferry/ship/water, other transit objects, strategic-AI transit use, RMG, editor placement, packaged transit interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed. Select the next tracker-approved implementation slice.
  id: `overworld-ninefold-rope-lift-live-transit-10184`
- Completed implementation slice: `presentation-active-play-load-resumed-cue-playback-10184`. Successful Main Menu selected-save loads now carry one detached `system_load_resumed` handoff across the real AppRouter transition and publish it exactly once after the authoritative Overworld, Town, Battle, or Scenario Outcome initial refresh. One shared presenter modulates only the existing status control, uses exact normal `load_resume` or reduced-motion `load_icon_static` policy, never blocks input or changes copy/layout, clears mismatched/failed/stale routes, does not replay on refresh, and restores exact visual state after expiry. Focused eight-case 1280x720/1920x1080 real-load proof, stale-file control, save/load confidence, 1280 Battle layout/load, animation policy, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Save schema/restore/routing, final audio/VFX assets, packaged load interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-active-play-load-resumed-cue-playback-10184`
- Completed implementation slice: `presentation-active-play-save-written-cue-playback-10184`. Successful manual saves from Overworld, Town, Battle, and Scenario Outcome now publish the existing authored `system_save_written` cue through one reusable nonblocking presenter attached to each shell's existing Save control/status surface. The component modulates existing controls only, preserves authoritative save/status copy and layout, uses the exact normal `save_confirm` or reduced-motion `save_icon_static` policy, ignores pending/canceled/failed saves, survives refresh without replay, and restores exact visual state after expiry. Focused eight-case 1280x720/1920x1080 proof, the four-route manual-save regression, animation policy, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Autosaves, load/resume, save schema, final audio/VFX assets, packaged save interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-active-play-save-written-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-resource-delta-cue-playback-10184`. Successful live player resource-site collection now publishes one detached `ui_resource_delta` presentation after authoritative stockpile, node, recap, fog, and command-band refresh. The compact Resource chip overlay reports exact ordered nonzero net changes, remains nonblocking in normal and reduced-motion modes, preserves the existing map capture/depletion cue and stockpile text, survives refresh without replay, fails closed for malformed or unavailable actions, and expires cleanly. Focused 1280x720 and 1920x1080 live-button proof matches independent rules and whole-session authority. Object-resolution, live-stockpile, animation-policy, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Economy/collection/reward/income/content/save/schema/AI, final audio/VFX assets, packaged resource interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-resource-delta-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-artifact-acquired-cue-playback-10184`. Successful live player artifact collection now publishes one detached `artifact_acquired` presentation after authoritative node, inventory/equipment, recap, fog, and Artifact rail refresh. Normal playback shows the compact Artifact rail cue while a transparent full-shell layer owns input until timeout or Escape skip; reduced motion uses the exact nonblocking `artifact_badge_added` fallback. Focused 1280x720 and 1920x1080 live-button proof matches an independent rules control and whole session authority, preserves the existing map-depletion cue, survives refresh without replay, fails closed for malformed or unavailable actions, and settles cleanly. Object-resolution, artifact-source, animation-policy, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass. Artifact rules/content/rewards/auto-equip/movement/fog/save/schema/AI, final audio/VFX assets, packaged artifact interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed. Select the next tracker-approved release-readiness implementation slice.
  id: `presentation-overworld-artifact-acquired-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-artifact-slot-cue-playback-10184`. Successful live player equip and stow buttons now publish one detached authored `artifact_equipped` or `artifact_unequipped` presentation after the authoritative Artifact rail refresh. The compact rail label remains nonblocking: normal mode uses the exact slot equip/unequip pulse contracts and reduced motion uses the exact static added/removed badges. Focused 1280x720 and 1920x1080 live-button proof executes stow while the equip cue is still active, matches both actions to independent rules controls and whole session authority, preserves refresh progress, fails closed for malformed or unavailable actions, and expires cleanly. Overworld visual, artifact runtime, animation policy, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Artifact rules/content/stats/inventory/equipment/movement/save/schema/AI, final audio/VFX assets, packaged artifact interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed.
  id: `presentation-overworld-artifact-slot-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-field-spell-cast-cue-playback-10184`. Successful live player movement-restoration and scouting-reveal field spells now publish one detached authored `spell_cast_overworld` presentation after the authoritative Overworld refresh. Normal mode draws the bounded hero-anchored cast rings and spell icon while a transparent full-shell layer owns pointer and keyboard input; `ui_cancel` skips it and returns Overworld focus. Reduced motion uses the exact nonblocking `adventure_spell_icon` fallback. Focused 1280x720 and 1920x1080 live-button proof preserves exact independent mana, movement, fog, recap, session, route, and map authority; refresh does not replay or reset the cue, malformed payloads fail closed, failed casts publish nothing, and expiry or skip leaves no blocker. Overworld visual, magic hooks, full-route, gameplay-input ownership, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Spell rules/content, save/schema, AI, final audio/VFX assets, packaged spell interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed.
  id: `presentation-overworld-field-spell-cast-cue-playback-10184`
- Completed implementation slice: `presentation-town-building-complete-cue-playback-10184`. Successful live player construction now publishes one detached authored `town_building_built` presentation after the authoritative Town refresh. Normal mode draws the bounded build-complete frame and badge while a transparent full-shell layer owns pointer and keyboard input; `ui_cancel` skips it and returns Town focus. Reduced motion uses the exact nonblocking `building_badge_added` fallback. Focused 1280x720 and 1920x1080 live-button proof preserves exact independent construction/session authority, refresh does not replay or reset the cue, malformed payloads fail closed, and expiry or skip leaves no blocker. Recruitment, Town visual, animation-contract, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Construction rules, content, save/schema, AI, final audio/VFX assets, packaged Town interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed.
  id: `presentation-town-building-complete-cue-playback-10184`
- Completed implementation slice: `presentation-town-recruitment-cue-playback-10184`. Successful live player recruitment now publishes the already-authored `town_units_recruited` presentation contract once after the authoritative Town refresh, so its bounded lifetime begins on a renderable scenic stage. Normal mode draws the compact muster rings and count badge; reduced motion uses the exact static `recruit_count_badge` fallback. Focused 1280x720 and 1920x1080 live-button proof preserves exact recruitment/session authority, refresh does not replay or reset the cue, and expiry remains inactive. Town visual, animation-contract, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Recruitment rules, content, save/schema, AI, audio playback/assets, packaged Town interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unchanged or unclaimed.
  id: `presentation-town-recruitment-cue-playback-10184`
- Completed implementation slice: `ux-town-contextual-guide-10184`. The live Town footer now opens one compact contextual Field Manual from the existing authored Town help topic. The modal layer leaves the scenic and management layout unchanged, owns pointer and keyboard focus while open, closes on `ui_cancel` or its Close command, returns focus to Guide, and does not change Town actions, session, save, settings, menu, or leave authority. Focused 1280x720 and 1920x1080 interaction, Town/Battle visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged Town Guide interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `ux-town-contextual-guide-10184`
- Completed implementation slice: `presentation-overworld-guarded-site-context-cue-10184`. Selecting an unresolved guarded resource site now shows the exact authored context-only guard badge at the site tile from the existing blocking-guard and inspection authority. The badge is stable across refresh, clears on deselection or guard resolution, uses the reduced-motion static fallback, draws only on the dynamic layer, and does not create a timed/replayable event. Focused guard lifecycle, existing object-resolution controls, guarded reward, full-route, visual, animation-contract, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Other object/route cues, guard/battle/route/resource rules, packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-guarded-site-context-cue-10184`
- Completed implementation slice: `presentation-overworld-blocked-route-cue-playback-10184`. A changed blocked selected-route decision now plays one exact nonblocking cue at the selected tile, advances only the dynamic layer, and dedupes full refreshes and identical reselection. Focused normal and reduced-motion proof preserves the exact route reason/session authority and uses the catalog's blocked-route icon; reachable destinations retain the compact route path with no cue. Full-route, destination-only, controller, visual, animation-contract, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Other route/object cues, pathfinding/movement policy, packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-blocked-route-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-town-capture-cue-playback-10184`. Successful non-routing neutral-town captures now play one captured cue at the exact authoritative retained-town tile after route locomotion, redraw only the dynamic layer, and do not replay on refresh. Focused normal and reduced-motion proof preserves ownership/objective authority and uses the exact ownership-badge fallback; route/destination, visual, town-battle, object-contract, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Enemy-town assault/battle aftermath, town rules/content/economy, packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-town-capture-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-repeatable-site-visited-state-10184`. Successful nonpersistent repeatable services now remain visible through cooldown, expose their active context again when ready, and play one exact visited cue rather than depletion on both route arrival and direct revisit. The Wayfarer Infirmary focused proof covers an early fail-closed repeat, exact seven-day revisit, reduced-motion check fallback, unchanged costs/rewards/cooldown/session/cache authority, and one-shot serials. Metadata, route/destination, visual, object-contract, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-repeatable-site-visited-state-10184`
- Completed implementation slice: `presentation-overworld-object-resolution-cue-playback-10184`. Successful non-routing persistent resource captures and artifact depletion now play one bounded view-only cue at the exact authoritative interaction tile, queue behind route locomotion, redraw only the dynamic layer, and use the catalog's reduced-motion fallback without replaying on refresh. Focused normal/reduced runtime, inspected 1280x720 and 1920x1080 captures, route/destination/cache/visual/object-contract/accessibility/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-object-resolution-cue-playback-10184`
- Completed implementation slice: `presentation-overworld-hero-route-locomotion-10184`. Successful non-routing field movement now replays the existing active-hero marker over the exact resolved route tiles once, using bounded authored cue timing and dynamic-layer-only redraw; reduced motion snaps directly to the authoritative endpoint. Focused normal/reduced runtime, inspected 1280x720 and 1920x1080 captures, cached-route/incremental-preview/input-ownership/visual/accessibility/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-overworld-hero-route-locomotion-10184`
- Completed implementation slice: `presentation-battle-state-path-vfx-asset-adoption-10184`. All six remaining Board-recognized state/path cues now map one-to-one to distinct original imported alpha textures. The renderer keeps the existing subject, source, target, path, progress, timing, reduced-motion, movement, death, retreat, and surrender authority and retains every procedural state/path function as a missing-map or missing-texture fallback. Focused all-six live proof, actual movement/death/retreat/surrender paths, inspected 1280x720 and 1920x1080 captures, Board navigation, accessibility, core, the 1280 routed layout matrix, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green; both PCKs contain the manifest and all six imported resources. Packaged Battle interaction, particles/shaders, other-screen VFX, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-battle-state-path-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-battle-spell-vfx-asset-adoption-10184`. All seven existing spell-specific Battle cues now map one-to-one to distinct original imported alpha textures. The live renderer uses exact existing source/target/progress records, keeps every procedural spell draw function as fail-closed fallback, and draws beneath stack tokens/counts. Focused all-seven live proof, missing-map fallback, actual Cinder cast, reduced-motion/reduced-flash behavior, inspected 1280x720 and 1920x1080 spell captures, magic/cue/core compatibility, 1280 routed layout, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged Battle interaction, particles/shaders, broader VFX migration, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-battle-spell-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-battle-core-vfx-asset-adoption-10184`. The existing Battle cue runtime now loads three original imported textures through an exact eight-cue manifest for projectile/impact, melee/retaliation, and cast/status/cleanse/brace effects, renders them beneath stack tokens, and retains the prior procedural functions as a missing-map/missing-texture fallback. Focused headless behavior plus inspected 1280x720 and 1920x1080 Xvfb captures, reduced-motion/reduced-flash behavior, 1280 routed layout, cue catalog, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. The broader 40-cue placeholder catalog, final VFX art, packaged Battle interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-battle-core-vfx-asset-adoption-10184`
- Completed implementation slice: `presentation-save-resume-commander-portrait-continuity-10184`. The existing Load/Resume preview now shows the exact authored commander already owned by the selected save summary, through the shared fail-safe portrait component and without changing SaveDetails copy or any save/load policy. Focused 1280x720, 1920x1080, and compact 1024x600 containment, stale-file hiding, delete, manual naming, latest-summary recency, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged portrait interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-save-resume-commander-portrait-continuity-10184`
- Completed implementation slice: `presentation-live-commander-portrait-adoption-10184`. One reusable aspect-preserving `HeroPortraitView` now owns exact ContentService loading, tooltip, and hidden fail-safe behavior for Campaign, Skirmish, Overworld, Town, Battle, and Outcome. Live player portraits follow the authoritative current hero; Battle shows an enemy portrait only when the commander resolves to an authored hero id. Focused 1280x720 and 1920x1080 containment and lifecycle updates, existing visual/focus/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged portrait interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-live-commander-portrait-adoption-10184`
- Completed implementation slice: `presentation-authored-hero-portrait-pipeline-10184`. All 60 authored commanders now have unique deterministic original 384x512 portrait assets and exact data-driven manifest records. ContentService validates and loads the hero-art domain, while the existing Campaign and Skirmish commander cards render the selected hero beside unchanged text with a missing-art fail-safe. Focused complete-roster loading, 1280x720 and 1920x1080 Campaign containment, keyboard/controller navigation, launch/session authority, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green. Packaged portrait interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.
  id: `presentation-authored-hero-portrait-pipeline-10184`
- Completed implementation slice: `presentation-overworld-blocking-object-feedback-10184`. Visible blocking map objects and resource bodies now expose exact authored identity and use a distinct original object-blocked VFX/audio cue instead of misnaming passable ground. Unexplored blockers remain identity-silent; terrain/unreachable routing, body/interaction tiles, selection, session/save authority, 1280x720 and 1920x1080 presentation, reduced/missing fallbacks, compatibility, static/editor, and bounded Linux/Windows export/startup gates are green.
- Latest completed implementation slice: `presentation-scenario-outcome-scenic-epilogue-stage-10184`. Victory and defeat now use distinct original full-screen epilogue panoramas behind the unchanged Outcome authority surfaces, with exact cover crop, translucent cards, a compact action dock, and flat-palette fallback.
- Latest completed implementation slice: `presentation-town-faction-scenic-stage-backdrops-10184`. The Town stage now selects one of six original faction panoramas behind its unchanged live overlays, cover-crops without stretching, and retains the procedural renderer as a fail-safe.
- Latest completed implementation slice: `combat-mireclaw-sporewake-rot-cant-priority-calibration-10184`. Sporewake Rot Cant keeps its round-one tier-four veteran identity and all live consequences while its authored target-priority bonus is calibrated from `1.0` to `0.9`; the exact all-live matrix lowers severity from `187.0` to `183.5`, preserves every non-Mireclaw ordered row, and keeps the active 59-encounter queue clear.
- Latest completed validation/adoption slice: `strategic-ai-medium-long-run-seed-matrix-10184`. Exact current-HEAD Medium seed ordinals 1-100 now pass the 56-turn behavior matrix with zero aggregate behavior, integrity, reachability, or no-active-pressure blockers; the baseline retires only that matrix gap while generated topology/contact/pacing and broader release readiness remain open.
- Latest completed implementation slice: `strategic-ai-known-world-target-catalog-projection-reuse-10184`. Strategic AI now enumerates one exact detached sight-source surface and eligible-target catalog per known-world refresh while keeping every source projection and every later refresh fresh.
- Latest completed implementation slice: `strategic-ai-phase-target-descriptor-enumeration-reuse-10184`. Strategic AI now separates exact ordered detached target descriptors from fresh origin-specific projection and reuses discovery only within one planner invocation or best-open-spawn-point sweep, preserving ordinal-100 behavior while reducing repeated target enumeration.
- Latest completed implementation slice: `ux-map-editor-responsive-top-bar-containment-10184`. The Map Editor now allocates the live TopPad between the clipped full-tooltip header and native package picker while reserving the exact combined minima of Load Map, Save Copy, Play Copy, Menu, and their separations, preserving the map, ToolRail, focus, package, and editor authority at 1280 and 1920.
- Latest completed implementation slice: `accessibility-battle-board-cursor-live-context-coalescing-10184`. Battle now exposes one bounded polite live context for the existing keyboard/controller Board cursor, coalesces changed navigation to its final settled hex, and announces exact existing A/B results without changing combat, input timing, mouse behavior, or battle authority.
- Latest completed implementation slice: `ux-overworld-selected-route-field-readiness-coherence-10184`. Targeted route selection now refreshes the route-owned ObjectiveBrief readiness tooltip, idle Event/action context, End Turn cue, and drawer/handoff cues from the same authoritative cached action and route state while preserving active feedback/recap, compact zero-rich construction, incremental ownership, and all route consequences.
- Latest completed implementation slice: `map-editor-generated-package-play-copy-restore-tile-baseline-10184`. Generated-package Map Editor Play Copy now carries the immutable loaded-package baseline through the in-memory return handoff, so Restore Tile remains exact without authored-scenario fallback, disk reload, generated-content registration, or Native RMG changes.
- Latest completed implementation slice: `accessibility-map-editor-canvas-live-context-coalescing-10184`. The Map Editor canvas now exposes one bounded current tile/tool/action live context, keeps the visual working-copy status non-live, and coalesces held keyboard/controller navigation to the final settled destination without changing editor authority.
- Latest completed implementation slice: `ux-overworld-selected-route-map-cue-coherence-10184`. Targeted Overworld route selection now rematerializes the visible MapCue and tooltip from the same current compact primary action and route decision without stale prior-destination instructions or rich-route construction on compact paths.
- Latest completed implementation slice: `accessibility-overworld-route-cursor-live-context-10184`. The Overworld right-stick route cursor now exposes bounded current-destination context and coalesced held-repeat announcements before A commits, without changing route selection, movement, or save authority.
- Latest completed implementation slice: `ux-map-editor-responsive-tool-rail-containment-10184`. The Map Editor tool rail now keeps every visible command and picker horizontally contained at 1280 and 1920 without shrinking the map, hiding overflow, or changing editor behavior.
- Latest completed implementation slice: `accessibility-map-editor-keyboard-controller-canvas-interaction-10184`. The Map Editor canvas now supports bounded keyboard/controller tile selection, camera follow, and existing-tool activation without changing shared Overworld input or mouse behavior.
- Latest completed implementation slice: `accessibility-map-editor-command-focus-navigation-10184`. Every enabled Map Editor command now joins one bounded keyboard/controller focus cycle without changing editor layout, map pointer ownership, or command consequences.
- Latest completed implementation slice: `accessibility-main-menu-display-change-exclusive-parent-input-10184`. The exclusive display preview confirmation now recovers exact native physical Revert/Keep routing after a blocked parent click without closing Settings or changing transaction authority.
- Latest completed implementation slice: `accessibility-map-editor-dirty-confirmation-exclusive-parent-input-10184`. The exclusive unsaved-map confirmation now recovers exact native physical cancel/confirm routing after a blocked parent click while preserving working-copy, package, save, route, and native-close authority.
- Latest completed implementation slice: `accessibility-outcome-new-session-exclusive-parent-input-10184`. Outcome fresh-expedition confirmations now recover exact native physical cancel/confirm routing after a blocked parent click while preserving resolved-session, save, profile, route, and focus authority.
- Latest completed implementation slice: `accessibility-main-menu-destructive-confirmation-exclusive-parent-input-10184`. Campaign restart, save deletion, and settings reset confirmations now exclusively own parent-window input and retain exact native physical cancel/confirm after blocked background clicks.
- Latest completed implementation slice: `accessibility-overworld-end-turn-confirmation-exclusive-parent-input-10184`. The warned End Turn confirmation now exclusively owns parent-window input and defers exact root-routed physical cancel/confirm into the captured child dialog, preserving expedition, save, route, camera, and confirmation authority across blocked parent clicks.
- Latest completed implementation slice: `save-end-turn-tail-normalization-parity-10184`. A committed End Turn now fully canonicalizes the post-daybreak, hook, enemy, and scenario state before trusted autosave or Manual Save surfaces use it, so live, raw saved, and restored Day-N state remain exact without replaying the turn.
- Latest completed implementation slice: `save-battle-resolution-forecast-checkpoint-parity-10184`. Battle-resolution checkpoints now canonicalize derived command-risk state before trusting the live autosave payload, while explicitly next-day town consequences reuse the same occupation-then-recovery projection as live daybreak so saved, live, and restored forecasts remain exact and truthful.
- Latest completed implementation slice: `accessibility-battle-confirmation-exclusive-parent-input-10184`. Battle Quick Resolve and Withdrawal confirmations are exclusive, block real parent clicks, and defer exact root-routed physical input into the captured child dialog without mutating battle/RNG state or double-routing into combat actions.
- Latest completed implementation slice: `strategic-ai-path-surface-observer-visibility-fingerprint-10184`. Cached player-hero blocker surfaces now fingerprint the exact observer-visible and unsheltered state, so same-day resource-controller or town-ownership changes rebuild affected routes while other observers and hidden/sheltered heroes retain exact reuse.
- Latest completed implementation slice: `accessibility-manual-overwrite-exclusive-parent-input-10184`. The shared four-route overwrite confirmation is now exclusive, blocks real parent-window clicks, and safely forwards only root-routed physical keyboard/controller events into the child dialog after root dispatch, preserving native cancel/confirm and background authority.
- Latest completed implementation slice: `accessibility-overworld-drawer-overwrite-cancel-ownership-10184`. A visible manual-overwrite confirmation now outranks Command/Frontier drawer cancel handling, so the first physical Back/Escape activates native Keep Save, preserves the open drawer and background authority, and restores Save focus before a fresh Back closes the drawer.
- Latest completed implementation slice: `accessibility-town-manual-overwrite-cancel-ownership-10184`. Physical Back/Escape on Town's visible manual-overwrite confirmation is now owned by the native Keep Save action, canceling once, preserving the Town route and save bytes, and restoring Save focus before ordinary Town Back navigation resumes.
- Latest completed implementation slice: `accessibility-overworld-settings-unhandled-command-containment-10184`. Overworld Settings now consumes shell commands that survive native GUI handling, so Enter, Space, debug-overlay keys, and camera recenter cannot mutate gameplay behind the visible modal while native Settings controls and fresh post-close shell commands remain unchanged.
- Latest completed implementation slice: `accessibility-hero-keybindings-live-status-announcements-10184`. The Hero Keybindings capture/result status is now one bounded polite native screen-reader live region, announcing capture prompts, cancellation, rejection, swap, success, reset, and failure updates without changing focus or input behavior.
- Latest completed implementation slice: `gameplay-town-daybreak-economy-forecast-parity-10184`. End Turn now previews full and compact player-town income plus full weekly muster from the same next-day occupation-then-recovery state used by live daybreak, without mutating the live session or conflating occupation releases, site musters, deliveries, or scenario hooks with core town growth.
- Latest completed implementation slice: `gameplay-town-muster-specialty-forecast-parity-10184`. Player-owned Town recruit, build, context, and stable-state end-turn forecasts now use the same hero-specialty-scaled weekly muster payload as the live weekly mutation, while enemy, neutral, sessionless, and strategic-metric growth remain raw.
- Latest completed implementation slice: `accessibility-main-menu-hero-keybindings-focus-containment-10184`. The Main Menu hero-keybindings overlay now owns exact reset-disabled and reset-enabled keyboard/controller cycles over its eight dynamic bindings plus Close and the enabled Reset action; capture input, close-once behavior, hidden-menu authority, persistence, and return focus remain exact on Linux and Windows.
- Latest completed implementation slice: `strategic-ai-recruit-destination-unaffected-raid-target-retention-10184`. Commander-only planned, rebuild, and emergency recruitment now retain the unchanged per-town best-raid destination while raid reinforcement still invalidates it; exact strict-Small behavior is unchanged as best-raid scoring falls from 771ms to 733ms and reinforcement falls from 2508ms to 2460ms.
- Latest completed implementation slice: `accessibility-active-play-settings-focus-containment-10184`. The shared Overworld/Town/Battle Settings overlay now owns an exact 12-control keyboard/controller focus cycle, preserves native slider and popup behavior, and prevents wrapped traversal or Accept from reaching gameplay commands behind the visible modal.
- Latest completed implementation slice: `strategic-ai-town-build-raid-capacity-context-reuse-10184`. One pre-mutation empire build enumeration now derives active-raid capacity once per faction and reuses it across later eligible town score contexts; the strict-Small matrix removes five duplicate capacity loads with exact behavior and lowers the scoped current-town lane from 1206ms to 1188ms, while no aggregate runtime improvement is claimed.
- Latest completed implementation slice: `strategic-ai-recruit-destination-commander-roster-context-reuse-10184`. Each recruitment destination context now shares one exact normalized commander roster across rebuild and planned-task scoring, evicts it after every field reinforcement, and lowers method-matched reinforcement time from 2678ms to 2422ms with exact strict-Small behavior.
- Latest completed implementation slice: `strategic-ai-town-build-planned-task-context-reuse-10184`. One pre-mutation town-build enumeration now shares its immutable planned-task list and path graph across eligible towns, removes five duplicate loads in the strict-Small matrix, preserves per-town saved plans and exact behavior, and holds the method-matched town-build runtime at 2011ms.
- Latest completed implementation slice: `strategic-ai-town-build-front-context-reuse-10184`. Town-build scoring now passes its exact current development metrics into local-front evaluation; strict-Small behavior remains unchanged while current-town-state work falls from 1363ms to 1241ms.
- Latest completed implementation slice: `strategic-ai-active-front-empty-plan-probe-cutoff-10184`. Active-front spawn evaluation now stops constructing commander armies after the first probe proves that an origin has no valid support plan; exact strict-Small behavior remains unchanged while support-candidate time falls from 1068ms to 607ms.
- Latest completed implementation slice: `strategic-ai-recruit-destination-town-front-context-reuse-10184`. Recruitment destination planning now derives the local front from the town-development metrics it already computes; exact strict-Small behavior remains unchanged while reinforcement falls from 4244ms to 2676ms.
- Latest completed implementation slice: `strategic-ai-active-raid-assignment-path-context-reuse-10184`. Each active raid now builds its current path graph once and reuses it across defense redirection, target refresh, and unreachable-target checks; exact strict-Small behavior remains unchanged and the profiled assignment total falls from 2791ms to 2414ms.
- Latest completed implementation slice: `strategic-ai-active-front-shared-spawn-path-context-10184`. Active-front support and ordinary spawn planning now consume one phase-local graph, duplicate loads fall to zero, exact strict-Small behavior remains unchanged, and Linux plus fresh Windows/Wine package boots pass.
- Latest completed implementation slice: `strategic-ai-active-front-path-context-reuse-10184`. One phase-local virtual-probe path graph is now shared across every active-front spawn origin, exact candidates and strict-Small signatures remain unchanged, and Linux plus fresh Windows/Wine package boots pass.
- Latest completed implementation slice: `strategic-ai-spawn-launch-policy-context-reuse-10184`. Each faction spawn loop now lazily loads capital/front launch policy once, reuses it through candidate selection and pressure consumption, preserves no-town short-circuits and exact strict-Small behavior, and passes Linux/Windows package boots.
- Latest rejected candidate: `combat-embercourt-bargebow-crew-durability-calibration-10184` (superseded). HP `14` improves week-three Embercourt/Mireclaw but decisively worsens the full all-live matrix, so production remains at `13` and no active-breadth run or implementation follows.
- Latest completed implementation slice: `combat-veilmourn-undertow-harpooner-damage-calibration-10184`. The exact week-two Mireclaw/Veilmourn row improves from `70/30` to `62.5/37.5`; all non-Veilmourn ordered rows remain exact and the 59-encounter live queue remains clear.
- Latest completed implementation slice: `combat-brasshollow-foundry-saint-sustain-calibration-10184`. Focused `118/118`, all-live 100-seed balance, 59-encounter breadth, compatibility, editor, and repository gates pass; Veilmourn/Brasshollow remains explicitly unchanged at `67/33`.
- Latest completed implementation slice: `combat-mireclaw-drowned-antler-clean-line-pressure-10184`. The exact prior-screen control remains `38 / 332.5 / 13 / 79.0 / 1.6`; focused `118/118`, 59-encounter breadth, compatibility, editor, and repository gates pass.
- Latest completed implementation slice: `combat-mireclaw-drowned-antler-apex-calibration-10184`. The exact prior-screen control remains `38 / 332.5 / 13 / 79.0 / 1.6`; the 59-encounter live queue remains clear at repeated signature `829808c9`, and focused ability, autoplay, balance, core, editor, and repository gates pass.
- Latest completed implementation slice: `combat-mireclaw-drowned-antler-wounded-apex-10184`. The exact prior-screen control reproduces `38 / 332.5 / 13 / 79.0 / 1.6`, while production improves to `37 / 229.0 / 7 / 73.5 / 1.13` with zero structural failures and a clear 59-encounter live queue.
- Latest completed implementation slice: `accessibility-scenario-outcome-recap-tab-controller-navigation-10184`. Campaign/skirmish victory/defeat, real shoulder/D-pad/keyboard/mouse traversal, boundary retention, refresh/recovery-modal persistence, exact terminal/save authority, and Linux plus fresh Windows/Wine packages pass.
- Latest completed implementation slice: `accessibility-battle-info-tab-controller-navigation-10184`. Real shoulder, D-pad, keyboard, and mouse traversal reaches all four tabs with boundary retention, command return, selected-tab persistence through Defend refresh, exact authority, and Linux plus fresh Windows/Wine packaged PASS.
- Latest completed implementation slice: `performance-generated-large-transactional-manual-save-10184`. Generated-Large 20.28MB empty-slot and overwrite saves retain one semantic normalization and exact transactional verification while completing in 2302/2462ms in the Linux package and 2863/3830ms in fresh Windows/Wine.
- Latest completed implementation slice: `performance-generated-large-town-explicit-save-surface-10184`. Exact save-surface copy, authority, recovery, rollback, overwrite, command-risk, Town/core/repository, and Linux plus fresh Windows/Wine packaged gates pass; the separate large transactional-write latency remains follow-up performance debt.
- Latest completed implementation slice: `performance-town-generated-large-cache-hit-first-refresh-10184`. Exact ledger/action/departure parity, resource/context/action invalidation, authority, Town economy/transition/focus/core/repository gates, and Linux plus fresh Windows/Wine packaged performance all pass.
- Latest completed implementation slice: `save-briefing-consumption-alternate-autosave-reconciliation-10184`. Successful and failed End Turn rows, unverified-authority refusal, zero-write stale checks, Battle/generated controls, transaction/focus/visual/core/repository gates, and Linux plus fresh Windows/Wine packages pass at save version 9.
- Latest completed implementation slice: `accessibility-town-management-tab-controller-navigation-10184`. Wide/narrow five-tab keyboard/controller/mouse traversal, exact Town/save authority, market apply controls, Town visual/core/repository gates, and Linux plus fresh Windows/Wine packages pass; the generated-large cache timing red is method-matched pre-existing at HEAD.
- Latest completed implementation slice: `save-generated-opening-alternate-autosave-reconciliation-10184`. Three alternate End Turn success rows, exact failed-End-Turn authority, zero-write stale recovery, original retry controls, End Turn/transaction/timing/focus/visual/core/repository gates, and Linux plus fresh Windows/Wine packages pass at save version 9.
- Latest completed implementation slice: `save-latest-summary-subsecond-recency-10184`. Both fractional orderings, warm/cold cache, Main Menu selection/Continue parity, integer and mtime legacy fallbacks, exact byte/mtime immutability, transaction/menu/core/repository gates, and Linux plus fresh Windows/Wine packages pass at save version 9.
- Latest completed implementation slice: `accessibility-overworld-gameplay-movement-input-ownership-10184`. Ten owner states, short-lived repeat races, ordinary focused movement, right-stick controls, keyboard/controller/focus/core/repository gates, and Linux plus fresh Windows/Wine packaged input matrices pass at save version 9.
- Latest completed implementation slice: `save-generated-opening-autosave-failure-retry-safety-10184`. Forced, precommit, and after-backup exactness, retry deduplication, fast/manual/menu/ordinary controls, generated timing, return/close, focus, visual, core, repository, Linux package, and fresh Windows/Wine package gates pass at save version 9.
- Latest completed implementation slice: `accessibility-battle-quick-resolve-safe-cancel-focus-10184`. Physical controller, real mouse, direct-result parity, checkpoint, animation, active focus, 1280 layout, core, repository, Linux package, and fresh non-headless Windows/Wine native-dialog gates pass.
- Latest completed implementation slice: `scenario-outcome-new-session-confirmation-safe-cancel-10184`. Five campaign/skirmish action rows, immutable duplicate capture, stale identity/action/recovery guards, Save/Menu/overwrite controls, 1280 native-dialog bounds, Outcome compatibility, core, repository, Linux package, and fresh Windows/Wine package gates pass. Save Outcome and Return to Menu remain direct.
- Latest completed implementation slice: `battle-direct-playback-speed-write-failure-recovery-10184`. Precommit, after-backup, and non-regular-live-file failures preserve exact settings bytes/cache, transaction residue state, session/routes, and control focus; cleared success persists once and a fresh Battle consumes it. Focused, settings, animation, ActivePlay, focus, core, repository, Linux package, and Windows/Wine package gates pass.
- Latest completed implementation slice: `combat-brasshollow-rivet-hound-breach-skirmisher-10184`. The final Seam-only form preserves the accepted Brasshollow tempo and all 18 active-cohort signatures; the 59-encounter queue remains clear, and the 12,000-battle matrix changes only four outcomes by one sample each with unchanged maximum dominance and side bias. Universal speed/initiative increases were rejected after proving they materially redistributed live matchups.
- Latest completed implementation slice: `packaging-windows-uninstall-registration-and-pe-version-coherence-10184`. The per-user Windows setup now publishes a standard transactional HKCU Apps & Features registration plus Play and Uninstall shortcuts only after a verified commit, removes them only after an ownership-verified uninstall, and preserves prior program/registry/shortcut state across injected failures and refused uninstalls. Canonical `0.1.0-alpha.1` maps to coherent `0.1.0.1001` game/setup PE resources. Artifact, candidate, repository, full Linux installer, Windows setup/archive, and fresh Wine lifecycle gates pass; signing, native-Windows certification, publication, and overall release readiness remain open.
- Latest completed implementation slice: `ux-overworld-1600-command-band-responsive-fit-10184`. The selectable 1600x900 Overworld layout now reduces only the four command-row gaps at that constrained noncompact width, moving the full band from x=-3/width1606 to x=1/width1598 while retaining every command, map dominance, focus, and compact/full behavior. Strengthened 1024/1280/1600/1920 containment, active focus, repository, Linux package, and Windows/Wine package gates pass.
- Latest completed implementation slice: `accessibility-scenario-outcome-normal-entry-focus-10184`. Ordinary campaign and skirmish victory/defeat Outcomes now enter with the existing enabled primary follow-up focused, expose a deterministic six-control keyboard/controller cycle, preserve valid focus through refresh, keep recovery on Save, and never steal native overwrite-dialog focus. The same Outcome-only responsive pass keeps banner, actions, Save panel, and Save inside 1280x720 while retaining full overflow text in tooltips. Focused, recovery, overwrite, visual, active-focus, repository, Linux package, and Windows/Wine gates pass.
- Latest completed implementation slice: `briefing-consumption-autosave-failure-safety-10184`. Overworld first-turn and Battle tactical briefings now inspect their transactional autosave result. A failed write preserves the visible consumed briefing, emits one bounded issue, shows Save guidance with Save focus, and routes nowhere; one verified manual Save persists `shown=true` so restore does not replay the briefing. Focused failure/recovery, generated-opening defer, Battle/focus/save compatibility, repository, Linux package, and Windows/Wine package gates pass at save version 9.
- Latest completed implementation slice: `battle-resolution-autosave-failure-route-safety-10184`. Finalized nonterminal battles now checkpoint transactionally before exit animation or Overworld routing. Write failure retains the exact completed result in Battle with combat disabled, Save Battle guidance/focus, and zero route; one Save retry persists the canonical autosave and resumes the stored animation/route without replaying rules or rewards. Focused failure/retry, withdrawal, Quick Resolve, animation, controller, save, core, repository, Linux package, and Windows/Wine package gates pass at save version 9.
- Latest completed implementation slice: `map-editor-dirty-working-copy-destructive-transition-safety-10184`. Dirty Map Editor working copies now require one captured-action confirmation before Main Menu, package replacement, or native close. `Keep Editing` owns initial focus, Back/Escape preserve the exact working copy and origin focus, confirmed native close reuses transactional safe quit, and clean transitions remain direct. Focused, editor package, keyboard, core, repository, real Linux WM_DELETE, and packaged Windows/Wine WM_CLOSE gates pass.
- Latest completed implementation slice: `application-scenario-outcome-autosave-failure-recovery-10184`. Failed terminal autosaves now carry a session-bound recovery state into Outcome, surface bounded Save Outcome guidance with Save focus, and block campaign/skirmish follow-up until a verified retry persists the exact terminal session. Return and safe-close recovery remain usable, campaign completion is not replayed, and focused, compatibility, repository, Linux package, and Windows/Wine package gates pass at save/profile versions 9/1.
- Latest completed implementation slice: `overworld-controller-right-stick-route-selection-10184`. Controller users can now move a bounded route cursor with the right stick, inspect the existing route/destination surface without mutating session or save state, press A to invoke the existing primary action once, and press B to return selection/camera to the hero. Left-stick movement, D-pad focus, mouse/keyboard control, and modal ownership remain intact. Focused, live-controller, route/cache/visual, core, repository, Linux package, and Windows/Wine package gates pass at save version 9.
- Latest completed implementation slice: `battle-entry-forced-autosave-failure-route-safety-10184`. Required battle-entry autosave failure now restores the exact pre-route state, keeps the pending encounter in Overworld, records one bounded issue, shows Save-now guidance with Save focus, and performs zero routes. End-turn/manual/resume checkpoints avoid redundant writes and route once from already-durable state. Focused failure/recovery/control, compatibility, core, repository, Linux package, and Windows/Wine package gates pass at save version 9.
- Latest completed implementation slice: `campaign-progression-semantic-storage-fail-closed-10184`. Campaign progression storage is now classified before load or write. Malformed, partial, nested-wrong-shape, and future-version data remains byte-exact and non-overwritable; all campaign mutations fail closed without changing profile/session, while the Main Menu keeps local browsing and non-campaign paths usable. Focused source/live-menu, compatibility, core, repository, Linux package, and Windows/Wine package gates pass at profile version 1 and save version 9.
- Latest completed implementation slice: `active-play-return-to-menu-autosave-failure-safety-10184`. Return to Menu from Overworld, Town, Battle, and Outcome now fails closed when the forced autosave fails: the exact shell/session/intent and prior durable state remain, one bounded issue and Save/retry message appear, and Menu focus returns. One verified retry saves and routes once; no-session/editor direct controls remain intact. The eight-case failure matrix plus safe-close, save transaction, controller, core, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `overworld-pending-battle-manual-save-failure-route-10184`. Failed overworld manual writes now return before pending-battle resolution routing, preserve exact live battle and durable slot state, keep bounded retry feedback and Save focus, and expose the actual write result instead of inferring success from an occupied slot. One verified retry persists the canonical battle payload and routes exactly once. Both failure phases across empty and occupied slots plus compatibility, core, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `accessibility-destructive-confirmation-safe-cancel-10184`. Manual overwrite plus Restart Arc, Delete Save, and Restore Defaults now enter on named safe actions (`Keep Save`, `Keep Progress`, or `Keep Settings`). Controller Back/Escape cancels without mutation and restores the originating command; deliberate confirmation remains exactly once. Focused persistence/progression/settings, controller, compact 1280x720, core, parse, repository, JSON, Python, and diff gates pass.
- Latest completed implementation slice: `overworld-end-turn-autosave-failure-surface-10184`. When an in-progress End Turn commits but autosave fails, the live advanced day is retained while the shell now returns `saved:false`, shows bounded Save-now guidance, and records one runtime issue. Pending battles remain on the overworld until a successful manual Save persists the exact battle-ready state, then route once. Both failure phases, direct/warned/terminal controls, pending-battle recovery, core, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `settings-transactional-cross-platform-persistence-10184`. Device settings now commit through verified same-directory candidate/backup files with bounded recovery. Failed ordinary changes restore exact config bytes, settings, runtime display/audio/accessibility state, and InputMap; valid live files win, only semantically valid backups recover, and candidate artifacts are never promoted. Main Menu, active-play settings, and keybindings report failure truthfully and refresh to committed values. Focused, compatibility, core, repository, and fresh packaged Linux/Windows-Wine gates pass at settings version 14.
- Latest completed implementation slice: `ux-town-departure-end-turn-copy-integrity-10184`. Town departure now uses one authoritative `Return to Field` surface across core, cached, and live states. Remaining movement, exhausted movement, and response-order priority are explicit; the unchanged handler still routes only to the overworld without advancing the day, spending movement, or autosaving. Focused town visual/exit/controller, core, parse, repository, JSON, Python, and diff gates pass.
- Latest completed implementation slice: `campaign-progression-completion-write-failure-atomicity-10184`. Campaign completion now persists a detached profile candidate before publishing it live. A failed write restores the same pre-terminal session object and returns a visible retry message; clearing either injected failure phase lets one reevaluation persist and publish the outcome exactly once. Focused failure/retry, first-defeat, skirmish, campaign replay, core, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `overworld-risk-gated-end-turn-confirmation-10184`. Warned remaining-movement/available-order and unconsumed core-risk End Turn requests now open a compact confirmation with Keep Waiting initially focused. First press, cancel, and stale session/day/status/payload rejection are read-only; valid confirmation consumes the one-shot forecast and enters the unchanged End Turn/autosave path exactly once. Exhausted low-risk turns remain one-click. Focused parity/save, controller, full and targeted 1280x720 visual, generated-profile, core, broad headless, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `campaign-replay-defeat-preserves-cleared-progress-10184`. Campaign completion now preserves an already-banked victory record, exported flags, carryover, victory count, and downstream unlock when a later replay loses, while incrementing attempts and retaining the live defeat outcome. First defeat, defeat-to-victory upgrade, and later-victory refresh remain unchanged. Focused transition-matrix, normalization/progression reload, campaign breadth/frontier/restart/menu/outcome, core, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `application-safe-close-autosave-10184`. AppRouter now disables native auto-accepted quit and owns root-window close, WM-close fallback, and Main Menu Quit through one guarded request. Active overworld, town, battle, or outcome state is transactionally autosaved before exactly one clean exit; save failure leaves the game open with exact live/prior state, records a runtime issue, and shows a bounded desktop error. Reentrant/completed requests cannot save or quit twice, while explicit harness quits remain unaffected. Focused, real Linux/X11, fresh packaged Windows/Wine, core, menu, parse, repository, JSON, Python, and diff gates pass at save version 9.
- Latest completed implementation slice: `save-transactional-cross-platform-commit-10184`. Autosave, manual-slot, generated-opening, and campaign-progression writes now use one same-directory candidate/backup transaction. Candidate bytes, length, JSON root, and exact text are verified before commit; the prior valid live file is restored after precommit or after-backup failures; bounded missing/corrupt-live recovery accepts only a semantically valid destination-matched backup and never promotes a candidate. Cache invalidation and live intent clearing occur only after verified success. Focused recovery, ordinary save, core, repository, fresh packaged Linux, and fresh packaged Windows/Wine gates pass at save version 9.
- Latest completed implementation slice: `battle-player-withdrawal-confirmation-10184`. Retreat and Surrender now open one compact action-bound confirmation populated from their live authored consequence surface. Keep Fighting owns initial focus; cancel, Escape, and controller Back preserve the exact session and return focus to the originating action. Confirm revalidates availability, fails closed when stale, and invokes the existing BattleRules withdrawal path exactly once. Focused direct-rule parity, controller, 1280x720 layout, event-animation, core, parse, repository, JSON, Python, and diff gates pass without changing withdrawal math or save state.
- Latest completed implementation slice: `save-generated-opening-autosave-completion-persistence-10184`. The generated-map opening fast path now writes a detached post-success payload that removes ordinary transition intent plus generated opening/briefing defer flags and records initial-autosave completion. Only a successful write mirrors that state to the live session; failure preserves the existing autosave bytes and exact live retry intent. Restoring the saved session no longer schedules a second opening autosave. Focused generated route/save/restore/failure/ordinary-control, core, regression, deferred-payload, parse, repository, JSON, Python, and diff gates pass at save version 9. The unrelated legacy random-map replay fixture still stops before saves on its obsolete nonempty template-id assertion.
- Latest completed implementation slice: `settings-confirmed-display-mode-rollback-10184`. Player-facing window-mode and resolution changes now enter a SettingsService-owned preview without mutating committed settings or config bytes. A 15-second Keep/Revert modal gives Revert initial focus; Escape/controller Back, timeout, menu exit, replacement preview, and save failure restore the prior runtime display, while Keep persists and survives reload. Windowed/borderless requests clamp uniformly to the active monitor usable rectangle, and Restore Defaults defers its display portion through the same confirmation. Focused service, Main Menu, Restore Defaults, packaged persistence, active-play, Linux/X11, fresh-prefix packaged Windows/Wine, core, parse, repository, JSON, Python, and diff gates pass. Native Windows hardware certification, broader accessibility completion, and overall release readiness remain open.
- Latest completed implementation slice: `packaging-transactional-cross-platform-upgrade-10184`. Linux, Windows archive, and generated NSIS installers now stage and verify a complete manifest-owned payload before replacing an owned live install, remove obsolete prior-manifest files, and restore the prior bootable program set after an injected commit failure. Fresh install, same-version reinstall, A-to-B upgrade, unowned-directory refusal, user-data preservation, and uninstall behavior are matched across Linux and Wine validation. This does not claim signing, native Windows hardware certification, public release execution, stable-channel completion, or overall release readiness.
- Completed implementation slice: `combat-sunvault-aurora-relay-front-10184`. Aurora Bastions' Aurora Facet Wall now screens allied ranged stacks by four percent against melee attackers carrying the authored `bloodrush` committed-assault contract while a Bastion survives. Live damage, tactical-AI estimates, role summaries, the fast benchmark, and focused runtime proof share the same content-owned field without adding inert metadata to normalized battle state. Generic four-percent and one-percent screens were rejected because each increased ordinary outliers from 28 to 30. The accepted all-live matrix keeps 28 outliers, lowers excess severity from 162.5 to 161.0, preserves four rows at or above 65 percent, 68.5 percent maximum dominance, 4.13-point maximum side bias, and zero structural failures, and improves week-four Embercourt/Sunvault from 67.5/32.5 to 66/34. The 59-encounter queue remains clear at signature `829808c9`; focused ability, autoplay, runtime consequence, core, parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`; this is not final Sunvault identity, final faction balance, or overall release completion.
- Completed implementation slice: `combat-sunvault-prism-adept-refraction-volley-10184`. Production Prism Adepts now own Refraction Volley and receive the missing two-percent linked ranged screen while a Shard Warden survives. The all-live matrix remains at 28 outliers and four severe rows while excess severity improves from 161.0 to 158.0, side bias improves from 4.13 to 4.07, maximum dominance remains 68.5, and structural failures remain zero. The 59-encounter active queue remains clear at signature `829808c9`; faction balance remains `needs_tuning` and the game remains incomplete.
- Completed implementation slice: `combat-brasshollow-boiler-rivetcaster-pressure-artillery-10184`. Successful Boiler Rivetcaster ranged attacks now throw up to ten damage into one deterministic enemy adjacent to the primary target, then apply a two-round shared Overheated state that reduces initiative by one and does not refresh before recovery. Live rules, tactical AI, summaries, events, benchmark behavior, content validation, and focused runtime proof share the authored contract. The all-live matrix remains at 28 outliers while severity improves from 158.0 to 153.0, severe rows fall from four to two, maximum dominance improves from 68.5 to 68.0, side bias remains 4.07, and structural failures remain zero. Week-three Brasshollow/Embercourt improves from `31.5/68.5` to `37/63`; the 59-encounter queue remains clear at signature `829808c9`. Faction balance remains `needs_tuning` and the game remains incomplete.
- Completed implementation slice: `combat-embercourt-lantern-sapper-counter-ambush-flare-10184`. A living Lantern Sapper now removes the authored bonus from enemy backstab and fogwake attacks against its side, prevents Fogbound, and flare-reveals a denied fogwake attacker for one round with `-1` defense and initiative. The focused runtime report passes all `106/106` authored ability instances, including lethal fogwake, dead/duplicate/stripped source, unrelated ability, direct-damage, player-summary, tactical-AI, and event paths. The all-live matrix remains exactly at 28 outliers / `153.0` severity / two rows at or above 65 percent / `68.0` maximum dominance / `4.07` side bias / zero structural failures. The originally cited week-three Embercourt/Mireclaw row remains `32/68` because Mireclaw owns neither countered ability and was removed as an invalid causal completion target; actual Embercourt/Veilmourn rows move at weeks one and four from `53.5/46.5` to `55/45` and `48/52` to `48.5/51.5`. The 59-encounter queue remains clear at signature `829808c9`; faction balance and overall release completion remain open.
- Completed implementation slice: `strategic-ai-unreachable-town-defense-retask-10184`. Enemy raid hosts now reject unreachable stabilizing-town defense candidates and release an existing town-defense assignment if its route closes, clearing stale defense lifecycle fields before deterministic retargeting. Focused proof covers both transitions while preserving reachable defense, arrival, overcommit, resource defense, movement, and emergency launch behavior. The shared headless harness and strategic baseline remain green; core, parse, repository, JSON, and diff gates pass. The unrelated town-retake fixture still fails identically on committed HEAD because it asserts the transient regroup target after the raid has already reached the adjacent redoubt, reinforced, and resumed its prior target in the same turn.
- Completed implementation slice: `battle-player-quick-resolve-command-10184`. The live battle action strip now exposes a confirmed Quick Resolve command backed by production-owned deterministic, spell-aware tactical policy. Cancel is non-mutating and controller accessible; confirm resolves through authoritative combat RNG, mana, casualties, objectives, rewards, animation snapshot, and terminal routing. Identical Hollow Mire sessions resolve in four steps with the same victory, three spells, one advance, mana `16 -> 1`, troops `15 -> 5`, `+180` gold, `+2` ore, and objective/encounter completion. The 59-encounter breadth queue remains clear at signature `829808c9`; focused runtime, controller focus, combat balance, headless, core, regression, parse, repository, JSON, and diff gates pass. The scoped 1280x720 layout gate completes without assertions; its detached runner did not retain the numeric exit code.
- Completed corrective validation slice: `strategic-ai-role-state-fixture-reconciliation-10184`. The commander role-state report now matches the unchanged live full-breakdown target surface: River Signal Post and Glassroad Watch Relay both rank third, while the two Free Company cases and memory-continuity target remain first. Eight cases and the compact public leak check pass. Case execution is fail-fast; a forced first-case mismatch emits exactly one report/engine error with no script or later-case errors. Core, editor parse, repository, JSON, and diff gates pass. This changes no strategic-AI runtime behavior and is not gameplay implementation progress.
- Completed implementation slice: `combat-veilmourn-undertow-screen-snare-10184`. Undertow Harpooners' Mourning Nets now gain an authored 1.25 ranged payoff and 2.0 tactical target bonus only against rigid `snare_vulnerable` screens; Ledger Plate, Rivet Hide, and Furnace Screen opt in while ordinary shields remain exact. The implementation resolves new metadata from immutable unit content instead of normalized battle state, preserving unrelated deterministic battle hashes. The all-live 100-seed four-week matrix keeps 28 outliers and 68.5 percent maximum dominance, lowers excess severity from 172.0 to 162.5 and rows at or above 65 percent from five to four, moves week-two Brasshollow/Veilmourn from 68/32 to 55.5/44.5 and week three from 55/45 to 50.5/49.5, and has zero structural failures; the existing week-four Veilmourn lead increases from 58.5 to 61.5 percent. Focused ability, autoplay, 59-encounter clear-queue, core, parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`; this is not final Veilmourn identity, final faction balance, or overall release completion.
- Completed implementation slice: `strategic-ai-live-resource-target-view-reuse-10184`. Live hero-task resource selection now reuses each already scored candidate's normalized reasons, public importance, and debug reason when constructing its commander role view, while ordinary report callers retain the full resource score breakdown. Focused proof matches all 15 behavior-facing fields and keeps the intended Free Company/Signal Post reservation outcomes exact. Medium ordinal 99 preserves row signature `59262e55`, all 171 activity events, 37 turns, the same defeat outcome, and zero behavior, integrity, or reachability failures; local row runtime falls from 298228 to 296997 ms and accumulated target-assignment time from 50029 to 49886 ms across 74 samples. This is a bounded redundant-score cleanup, not broad strategic-AI performance completion or overall release completion.
- Completed implementation slice: `balance-post-identity-active-outlier-repair-10184`. Glassfen Relay Pickets now own a placement-local six-Guard/two-Adept line and Ninefold Drowned Reliquary owns a four-Cutter/nine-Reefbolt guard. Under current live faction mechanics both remain player-advantaged victories: Glassfen resolves in four rounds at 62% terminal margin / 8 enemy damage per round, and the Reliquary in three rounds at 85% / 8. The 59-encounter queue improves from 20 items / 4 high to 16 / 0 high, removes both matrix outliers and the matrix warning, and preserves passing runtime-consequence gates; the remaining 16 medium watches stay open. Focused exact roster/outcome proof, shared armies, default balance, unit abilities, core, Ninefold smoke, editor parse, repository, JSON, and diff gates pass. This is not full active-queue clearance, final encounter/faction balance, or overall release completion.
- Completed implementation slice: `packaging-public-prerelease-promotion-10184`. A manual main-branch workflow can now publish one existing verified draft as a public prerelease without rebuilding or replacing assets. Exact tag-bound confirmation, remote tag commit, draft/prerelease state, candidate and release-index schemas, version/revision identity, the exact seven-asset set, GitHub asset sizes, four package checksums, and all seven downloaded hashes are verified before publication. The workflow re-fetches metadata and downloads the same validated asset ids after `gh release edit`, then requires an immutable release/asset fingerprint to match. It has one contents-write job, one publication command, no automatic trigger, and no create/upload/delete/build path; it can only set draft false, prerelease true, and latest false. The production verifier passes against the retained real 0.1.0-alpha.1 Linux/Windows candidate with fingerprint `d01d8d250933896e76b26abc0ee266a917f417e2cb55be2f0a1796299d77e09a`. Promotion, artifact, candidate, delivery, repository, Python, JSON, workflow-YAML, shell-syntax, and diff gates pass. No live release was created. Manual public-prerelease execution, stable publication, signing, and native Windows hardware certification remain open.
- Completed implementation slice: `combat-sunvault-shard-warden-facet-reprisal-10184`. Shard Wardens now own Facet Reprisal: two-percent incoming ranged-attack mitigation plus ten-percent return of actual damage received while the stack survives. Melee, retaliation, spells, direct health loss, and lethal ranged attacks do not trigger it. Live player and AI attack resolution, tactical target scoring, attack previews, role summaries, the fast benchmark, schema validation, and focused runtime proof consume the same authored fields; returned damage can kill the shooter. The all-live 100-seed four-week matrix preserves 28 outliers / 172.0 severity / five rows at or above 65 percent / 68.5 percent maximum dominance / 3.8-point maximum side bias / zero structural failures. Week-four Sunvault/Veilmourn improves from 54.5/45.5 to 53/47, while Mireclaw/Sunvault keeps the same 62/38 result with a 0.01-point terminal-margin change. Ability, autoplay, balance-regression, core, editor-import, repository, Python, JSON, and diff gates pass. Faction balance remains `needs_tuning`; this is not final Sunvault identity, final faction balance, or overall release completion.
- Completed implementation slice: `packaging-draft-prerelease-channel-10184`. The clean-source build job remains contents-read-only and now passes its immutable verified artifact to the only contents-write job. Version-tag pushes select draft delivery; manual runs remain artifact-only unless explicitly dispatched from a matching tag. A directly tested policy rejects branch delivery and tag/version mismatches. The delivery job revalidates candidate/index version and exact source revision, checks all archive/installer hashes, proves the release tag is absent, and creates a draft prerelease with existing-tag and exact-target guards. It never publishes, replaces assets, or touches an existing release. Focused policy/workflow tests, live candidate identity/hash verification, a read-only GitHub 404 probe, workflow YAML, repository, Python, JSON, and diff gates pass. Signing, human publication, stable-channel selection, and native Windows hardware certification remain open.
- Completed implementation slice: `packaging-native-process-crash-recovery-10184`. Linux and Windows desktop runs now retain at most five rotated Godot engine logs and atomically own `user://debug/heroes_runtime_session.json`; normal autoload shutdown removes only the current process marker. A surviving marker is consumed exactly once on the next launch and records `previous_session_unclean_exit` with at most 64 KiB/40 bounded lines from the newest prior rotated log. Token-level support sanitization redacts Unix and Windows absolute paths even when backtrace frame prefixes precede them, while preserving useful engine, GDScript, and crash context. The real exported-PCK lifecycle intentionally terminates the first process through `OS.crash()` with return code -6, observes the crash marker, recovers exactly one issue on the second process, retains two logs inside the five-file bound, exports the recovered issue through the existing local-only support bundle, and leaves no session marker after clean exit. Existing 26-record packaged issue history, Linux binary export/boot, Windows PE/PCK/DLL export and Wine Boot/MainMenu load, platform readiness, core, editor-import, repository, Python, JSON, and diff gates pass. This closes bounded abnormal-exit recovery, not native minidumps, symbolication, remote reporting, signing, clean-machine/native-Windows certification, release-channel integration, or overall release completion.
- Completed implementation slice: `combat-sunvault-solar-array-screen-strength-10184`. Solar Array Lanes now reduces incoming melee primary and retaliation damage to allied Sunvault ranged stacks by five percent while both its Solar Array Strider source and linked Daybreak Colossus survive; source/link invalidation and exclusions for melee allies, other factions, ranged attacks, spells, and direct health loss remain exact. Live BattleRules, tactical-AI estimates, player summaries, the fast benchmark, focused runtime proof, and repository validation consume the same authored `0.95` multiplier. A six-percent candidate was rejected because outliers increased from 29 to 30. The accepted all-live 100-seed four-week matrix reduces outliers from 29 to 28 and severity from 174.0 to 172.0, keeps five rows at or above 65 percent and maximum dominance at 68.5 percent, moves side bias from 3.67 to 3.8 points inside the seven-point gate, and has zero structural failures. Week-four Embercourt/Sunvault improves from 68.5 to 67.5 percent and Mireclaw/Sunvault from 63 to 62 percent; Brasshollow/Sunvault worsens from 59 to 60 percent and week-three Sunvault/Veilborne from 60.5 to 61 percent without creating a new outlier. Focused ability, autoplay, balance-regression, core, editor-import, repository, Python, JSON, and diff gates pass. Faction balance remains `needs_tuning`; this is not final faction balance or overall release completion.
- Completed implementation slice: `artifact-faction-rare-income-runtime-10184`. Each of the six existing faction-aligned rare relics now provides exactly one matching faction rare resource per day while equipped or captured by a strategic-AI empire: Tollstone Ring/Embergrain, Mudglass Beads/Peatwax, Choir Tuning Fork/Aetherglass, Living Bridge Knot/Verdant Grafts, Pressure Gauge Reliquary/Brass Scrip, and Black-Sail Compass/Memory Salt. Live player end-turn and strategic-AI treasury application, compact effect/comparison summaries, magic/economy reporting, and artifact valuation consume the same authored income. Five rare-capable source tables declare activation while the common pickup table remains inactive; all six source execution reports pass, normal markets remain wood/ore-only, spell costs remain mana-only, existing non-income bonuses and source gates remain intact, and save version 9 is unchanged. Focused six-case runtime proof, artifact/source/taxonomy/set/magic/AI reports, market persistence, broad core smoke, repository validation, Python/JSON, and diff checks pass. This is a bounded live artifact/economy breadth increment, not final artifact catalog breadth, economy balance, or overall release completion.
- Completed implementation slice: `strategic-ai-launch-open-point-snapshot-10184`. One live faction launch decision now loads its open-spawn-point occupancy surface once and shares that read-only snapshot across emergency, planned-task, active-front, and final candidate scans; the next post-spawn decision necessarily reloads after encounter occupancy changes. Focused live proof records one load and four reuses, preserves the exact emergency candidate, and removes the newly occupied point on the next scan. A current-code no-reuse control and final Medium ordinal 99 both preserve row signature `59262e55`, 171 activity events, 37 turns, all event counts, the same player-defeat outcome, and zero behavior, integrity, or reachability failures; local row runtime falls from 302679 ms to 301646 ms and maximum turn time from 11320 ms to 11290 ms. This is a measured 0.34-percent redundant-scan cleanup, not broad strategic-AI performance completion or overall release completion.
- Completed implementation slice: `combat-sunvault-solar-array-lanes-10184`. Solar Array Striders now project Solar Array Lanes while a linked Daybreak Colossus survives, reducing incoming melee primary and retaliation damage to same-side Sunvault ranged stacks by three percent without affecting melee allies, other factions, ranged attacks, spells, or direct health loss. Live BattleRules, tactical AI estimates, player summaries, the fast benchmark, content validation, and focused runtime proof share the authored source/link contract. The accepted all-live 100-seed four-week matrix leaves weeks one and two exact, keeps 29 outliers, lowers severity from 179.0 to 174.0, rows at or above 65 percent from 6 to 5, and maximum dominance from 69.5 to 68.5 percent with zero structural failures. Maximum side bias rises from 2.67 to 3.67 points but remains inside the existing 7-point gate. Ability, autoplay, balance-regression, core, editor-import, repository, Python, JSON, and diff gates pass; faction balance remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-thornwake-sporeglass-mending-fire-10184`. Sporeglass Menders now use Mending Fire after successful ranged attacks to restore three health per living Mender, capped at eight, to one deterministically selected injured surviving allied stack without resurrecting casualties. Live BattleRules, player summaries and heal presentation, the fast benchmark, content validation, and focused runtime proof share the same contract. The accepted all-live 100-seed four-week matrix moves week-one Embercourt/Thornwake from 68.5 to 64.0 percent, lowers severity from 183.5 to 179.0 and rows at or above 65 percent from 7 to 6, keeps 29 outliers / 69.5 percent maximum dominance / 2.67-point maximum side bias / zero structural failures, and leaves every other pair win rate exact. Ability, autoplay, balance-regression, core, editor-import, repository, Python, JSON, and diff gates pass; faction balance remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-veilmourn-final-notice-brace-targeting-10184`. Final Notice now authors its tier-two veteran-brace threshold and bounded 3.75 target priority, and live tactical AI, stack normalization, player ability summaries, effect resolution, and the fast benchmark consume the same fields. Focused runtime proof makes Obituary Scribes choose Thornwhip Carriers over the otherwise preferred Sporeglass ranged line, gives the qualifying brace a 4.0 total once-per-battle score delta while a tier-one brace retains only the unchanged 0.25 base value, and preserves the existing one-round `-2` cohesion / `-20%` retaliation pressure. The accepted all-live 100-seed four-week matrix improves from 30 to 29 outliers, 193.0 to 183.5 severity, 8 to 7 rows at or above 65 percent, and 70.5 to 69.5 percent maximum dominance; maximum side bias moves from 2.53 to 2.67 points with zero structural failures. Ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass; faction balance remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `battle-ai-survivor-recovery-valuation-10184`. Live recovery, tactical-AI targeting, player-facing spell consequences, and the fast benchmark now share a survivor-only recoverable-health contract: casualty-only stacks cannot receive recovery, genuinely injured survivors remain valid targets, and repeated casts cannot restore fallen creatures. Focused reports prove a 38-health stack with ten health per creature caps at 40 and that AI filters a casualty-only 60/80 stack while casting Graft Mend on a 51-health six-survivor stack. The accepted all-live 100-seed four-week matrix has zero structural failures but exposes the honest tuning cost of removing illegal benchmark resurrection and wasted AI casts: outliers move from 29 to 30, severity from 186.5 to 193.0, rows at or above 65 percent from 7 to 8, and maximum dominance from 69.5 to 70.5 percent, while maximum side bias improves from 2.80 to 2.53 points. Magic-AI, spell behavior, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass; faction balance remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-sunvault-relay-activation-10184`. Prism Adepts now enter at initiative six instead of owning unearned first-action tempo, while a living tier-four Resonant Chorister restores that point to the linked Prism stack and activates Sunvault's line-wide multi-calibration damage, initiative, terrain-momentum, tactical-AI, and player-doctrine payoff; defeating the relay immediately removes those linked consequences without removing each stack's personal spell-calibration benefit. Focused live proof passes all 100 authored ability instances. The all-live 100-seed four-week matrix changes only week-one pair rows, reducing outliers from 31 to 29, severity from 203.0 to 186.5, rows at or above 65 percent from 8 to 7, and the week-one Brasshollow-Sunvault result from 69.5 to 58.5 percent while preserving 69.5 percent maximum dominance, 2.80-point side bias, zero structural failures, and every week-two through week-four pair summary. Ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, process-lifecycle, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-veilmourn-fog-ladder-identity-10184`. Veilmourn's production capstones now own the authored late-ladder roles: Mirror-Keel Reavers use a half-force Mirror-Keel Passage to attack across a distance-two lane and gain Black-Sail Breach pressure against harried or staggered targets, while Fogbound Leviathan's Leviathan Fogwake uses actual hex adjacency to deal 12% more primary-strike damage and apply one round of defense, initiative, and cohesion pressure only to unsupported enemy stacks. Shared BattleRules normalization/damage/status behavior, tactical AI scoring, player summaries, the fast benchmark, schema validation, and focused live proof consume the same contracts. The all-live 100-seed four-week matrix keeps 31 outliers / 8 rows at or above 65% / 69.5% maximum dominance, lowers severity from 204.5 to 203.0 and maximum side bias from 2.93 to 2.80 points, leaves weeks 1-2 exact, and has zero structural failures. Ability, autoplay, balance-regression, town-development, core, parse, repository, JSON, Python, process-lifecycle, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-mireclaw-sporewake-veteran-line-10184`. Sporewake Rot Cant now opens against tier-four-or-higher veteran lines with a narrow authored tactical priority, so its two-unit week-two Chanter stack takes the bounded once-per-battle shot instead of casting a routine commander spell and dying before round two. Shared BattleRules normalization, tactical AI scoring, the fast benchmark, schema validation, and focused runtime proof consume the same contract. The all-live 100-seed four-week matrix improves from 33 outliers / 233.5 severity / 74.0% maximum dominance to 31 / 204.5 / 69.5%, rows at or above 65% fall from 10 to 8, and structural failures stay at zero. Ability, autoplay, core, parse, repository, Python, JSON, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `accessibility-option-control-field-semantics-10184`. Shared native accessibility now gives every `OptionButton` a stable field identity derived from its control role instead of announcing only the selected display text. Generated descriptions retain tooltip consequences, reserve bounded space for the current value, and refresh after selection handlers complete; explicitly authored semantics remain unchanged. Focused dynamic and shipped-Settings proof, main-menu and active-play keyboard navigation, core systems, project parsing, repository, Python, JSON, and diff gates pass. Platform NVDA/Orca certification, final accessibility, and overall release completion remain open.
- Completed implementation slice: `combat-embercourt-sluicefire-prepared-breach-10184`. Sluicefire Lindworms now lose 15% primary-attack damage against a clean line while retaining full retaliation damage and their 4% Bloodrush payoff against wounded or disrupted targets. Shared BattleRules behavior, tactical AI estimates, player summaries, the fast benchmark, content validation, and focused runtime proof consume the same authored contract. The all-live 100-seed four-week matrix keeps 33 outliers, lowers excess severity from 248.0 to 233.5, rows at or above 65% from 11 to 10, maximum dominance from 74.5% to 74.0%, and week-four side bias from 2.13 to 1.87 points while the 2.80-point global maximum stays unchanged. Ability, autoplay, town-development, core, parse, repository, JSON, Python, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `balance-thornwake-barkmantle-cohesion-10184`. Barkmantle Screens no longer adds a global cohesion-hold tier, while its 18% incoming-ranged mitigation and 6% engaged/harried counterpressure remain live. Focused runtime proof covers the bounded contract across all 96 authored ability instances. The all-live 100-seed four-week matrix keeps 33 outliers and 74.5% maximum dominance, lowers excess severity from 262.5 to 248.0 and maximum side bias from 3.07 to 2.80 points, and has zero structural failures. Ability, autoplay, town-development, core, parse, repository, JSON, Python, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-thornwake-highroot-capstone-identity-10184`. Thornwake's production capstone pair now has source-aligned live roles: Graft Matriarchs deliver Highroot Graft Salvo with an open-lane floor and stronger payoff into rooted or disrupted enemies, while Worldroot Bastion's passive Worldroot Rampart directly blunts incoming ranged attrition without adding a global cohesion tier. Shared BattleRules behavior, tactical AI consumption, player summaries, the fast benchmark, content validation, and focused runtime proof consume the authored fields. The accepted all-live 100-seed pair and week summaries remain exact at 33 outliers / 262.5 severity / 12 rows at or above 65% / 74.5% maximum dominance / 3.07 maximum side bias with week 1 unchanged. Ability, autoplay, balance-regression, town-development, core, parse, repository, JSON, Python, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-embercourt-charter-ladder-identity-10184`. Embercourt's production tier-4 through tier-7 charter ladder now has source-aligned live roles: Ash-Oath Bailiffs enforce a held line through Ash-Writ Formation, Beacon Lectors spend one Beacon Lane Citation against a tier-4-or-higher breach, Sluicefire Lindworms convert wounded or disrupted prey into supported shock pressure, and Charter Colossus anchors a stronger retaliation through Charter Lock. Shared BattleRules behavior, tactical AI consumption, player summaries, the fast benchmark, content validation, and focused runtime proof consume the authored fields. The all-live 100-seed matrix improves from 35 outliers / 264.0 severity to 33 / 262.5, keeps 12 rows at or above 65% and 74.5% maximum dominance, leaves week 1 exact, and lowers maximum side bias from 3.8 to 3.07 points. Ability, autoplay, balance-regression, town-development, core, parse, repository, JSON, Python, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-sunvault-relay-ladder-identity-10184`. Sunvault's production tier-4 through tier-7 relay ladder now has source-aligned live roles: Resonant Choristers spend one Calibration Cant to expose a tier-6-or-higher line, Solar Array Striders resist 15% of control effects, Aurora Bastions blunt ranged fire and hold cohesion through Aurora Facet Wall, and Daybreak Colossus gains prepared-line and disrupted-target artillery pressure through Daybreak Firing Solution. Shared BattleRules/SpellRules behavior, tactical AI consumption, player summaries, content validation, and focused runtime proof consume the authored fields. The all-live 100-seed matrix keeps 35 outliers and 12 rows at or above 65%, lowers severity from 272.5 to 264.0 and maximum dominance from 75.0% to 74.5%, leaves week 1 exact, and improves week-4 Embercourt/Sunvault from 75% to 71% Embercourt dominance. Ability, resistance, autoplay, balance-regression, town-development, core, parse, repository, JSON, Python, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-veilmourn-mourning-lantern-mark-10184`. Veilmourn Mourning Lanterns now own Wake-Lantern Mark: their first ranged attack against a tier-3-or-higher veteran line applies one round of cohesion pressure, spends one battle use, and then reports the mark as spent. BattleRules, tactical AI scoring, player summaries, the fast benchmark, schema validation, and focused runtime proof share the authored limit and target threshold. The all-live 100-seed matrix improves from 36 outliers / 280.5 severity to 35 / 272.5, keeps 12 rows at or above 65% and 75% maximum dominance, lowers maximum side bias from 4.0 to 3.73 points, and moves week-1 Embercourt/Veilmourn from 62.5% Embercourt dominance to 53.5%. Ability, autoplay, balance-regression, town-development, core, parse, repository, JSON, Python, and diff gates pass; faction balance and overall release completion remain open.
- Completed implementation slice: `combat-brasshollow-pavis-screen-10184`. Furnace Pavis Teams now own Furnace Screen: a non-stacking live Pavis wall blunts incoming missiles and reduces frontal `Brace`/`Reach` line-breaker damage against itself and allied ranged engines by 6% while a screen survives. BattleRules, tactical AI estimates, player summaries, the fast benchmark, schema validation, and focused runtime proof share the contract. The all-live 100-seed matrix keeps 36 outliers and 12 rows at or above 65%, improves severity from 293.5 to 280.5, maximum dominance from 75.5% to 75.0%, week-3 Thornwake/Brasshollow from 75.5% to 67.5%, and week-2 Thornwake/Brasshollow from 61.5% to 50.5%. Ability, autoplay, town-development, core, parse, repository, JSON, and diff gates pass; faction balance and overall release completion remain open.
- Completed implementation slice: `native-rmg-player-release-matrix-adoption-10184`. Generated skirmish setup now exposes the completed native RMG 24-workflow release matrix across Small through Extra Large, land/normal-water/Islands, and one/two levels. Public launch normalization preserves the selected level, Islands no longer rewrites size or player count, and native catalog auto-selection plus fail-closed validation remain intact. Focused runtime proof launches Small two-level normal-water into a skirmish session in one attempt without authored writeback; the full native boundary retains 24/24 workflow shapes, legacy Small/land launch, core, parse, repository, JSON, diff, and 1280x720 visual gates pass. This is runtime adoption of already parity-owned workflows, not a new recovery or arbitrary-configuration parity claim.
- Completed implementation slice: `balance-active-cohort-queue-clear-10184`. Seven placement-local roster corrections clear the final authored-battle cohort queue: Ghoul Grove is a normal round-5 victory at 66% margin / 9 enemy damage per round and a hard round-3 defeat; River Pass Reed Totemists, Bellwake Mirror Lancers, Fen Crown Watch, Orevein Archive Wardens, and Mireford Ford Reavers become bounded defeats, while Glassfen Relay Pickets becomes a bounded victory. Eleven adjacent samples and seven shared armies remain exact. The 59-sample active queue falls from seven medium cohort watches to zero with signature `829808c9`; balance-matrix, runtime-consequence, focused battle, campaign menu, core, parse, repository, JSON, and diff gates pass. Overall release completion remains open.
- Completed implementation slice: `balance-remaining-sample-margin-pressure-10184`. Four placement-local rosters remove the final sample-level terminal-margin watches while preserving player victories: Ironbridge Ford Reavers add two Bog Brutes and move from 89% margin / 4 enemy damage per round to round 4 at 66% / 13; Prismhearth Relay Pickets own a local `6/2` Guard/Adept line and move from 82% / 3 to round 4 at 70% / 7; Glassroad Archive Wardens move from `4/7/1` to `5/7/1` and from 87% / 5 to round 4 at 66% / 12; Reedbarrow Barrow Pickets shift from `16/11` to `15/12` Cutthroats/Slingers and move from round 5 at 76% / 6 to round 6 at 73% / 6. Adjacent outcomes, shared armies, faction-matrix inputs, and runtime-consequence gates remain exact. The 59-sample queue improves from 11 to 7 medium cohort-only watches with zero sample/high items and signature `5200ba7d`; focused battle, breadth acceptance, campaign menu, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-lockmarsh-road-chaplains-outcome-pacing-10184`. Lockmarsh Surge's placement-local Road Chaplains now field nine River Guards, ten Ember Archers, and six Citadel Pikewards. Their deterministic battle moves from a round-2 burst victory at 70% terminal margin / 28 enemy damage per round to a round-6 extended defeat at 51% / 31 with a bounded 69% player/enemy power ratio. Charter Guard remains exact at a round-4 standard victory / 65% / 17 and Archive Wardens at a round-3 standard victory / 70% / 19; all three shared Embercourt armies and faction-matrix inputs remain exact. The 59-sample queue improves from 13 to 11 medium-priority items with zero high and signature `29388bfe`, removing the Road Chaplains pacing and Lockmarsh scenario outcome watches; focused battle, breadth, campaign menu, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-bogbound-archive-wardens-outcome-pressure-10184`. Bogbound Oath's placement-local Archive Wardens now field eight River Guards, twelve Ember Archers, and six Citadel Pikewards. Their deterministic forest battle moves from a round-4 standard victory at 81% terminal margin / 9 enemy damage per round to a round-4 standard defeat at 43% / 47 with a bounded 66% player/enemy power ratio. Lantern Patrol remains exact at a round-3 standard victory / 71% / 8 and Survey Guard at a round-8 extended victory / 16% / 20; the shared `7/7/2` Archive Wardens army and faction-matrix inputs remain exact. The 59-sample queue improves from 17 to 13 medium-priority items with zero high and signature `06dad95c`, removing the Archive sample plus Bogbound, forest, and player-disadvantaged cohort watches; focused battle, breadth, campaign menu, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-reedbarrow-chain-burst-pressure-10184`. Reedbarrow Ferry's placement-local Chain watch now fields five Bog Brutes, seven Mire Slingers, and five Blackbranch Cutthroats. Its deterministic battle moves from a round-2 burst defeat at 77% terminal margin / 63 enemy damage per round to a round-3 standard defeat at 50% / 42. Barrow Pickets remains exact at a round-5 standard victory / 76% / 6 and Levee Totemists at a round-6 extended defeat / 36% / 21; the shared `6/7/5` Reedbarrow Chain army and all faction-matrix inputs remain exact. The 59-sample queue improves from 19 to 17 medium-priority items with zero high and signature `19a4e784`; focused battle, breadth, campaign menu, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-ninefold-rough-exactors-pressure-10184`. Ninefold Confluence's placement-local Orevein Exactors now field nine Scrip Haulers, six Rivet Hounds, and six Furnace Pavis Teams. Their deterministic rough-terrain battle moves from a round-4 standard victory at 76% terminal margin / 9 enemy damage per round to a round-6 extended victory at 32% / 17. Basalt Gatehouse remains exact at a round-4 defeat / 74% / 38, lowering the rough-terrain cohort from 75% to 53%. The shared Orevein Exactors army remains exact. The 59-sample queue improves from 21 to 19 medium-priority items with zero high and signature `daf0f4d8`; focused battle, breadth, Ninefold smoke, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-orevein-archive-wardens-pressure-10184`. Orevein Contract's placement-local Archive Wardens add one Citadel Pikeward for a `6/8/2` formation. Their deterministic battle moves from a round-3 victory at 83% terminal margin / 15 enemy damage per round to round 4 at 59% / 29, and Orevein's scenario cohort falls from 70% to 62%. Bridgeward Levies remain exact at round 5 / 64% / 20 and Beacon Wardens at round 3 / 63% / 28; both shared Embercourt armies remain exact. The 59-sample queue improves from 23 to 21 medium-priority items with zero high and signature `723d6501`; the unrelated rough-terrain cohort remains open. Focused battle, breadth, skirmish/save, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-bellwake-relay-pickets-pressure-10184`. Bellwake Wreck Claim's placement-local Relay Pickets now field nine Shard Guards, seven Prism Adepts, and eight Mirror Duelists. The deterministic battle moves from a two-round victory at 87% terminal margin / 7 enemy damage per round to a four-round victory at 59% / 19; Bellwake's cohort falls from 70% to 61%. Mirror Lancers remain exact at 74% / 26 and Aurora Battery at 50% / 25, while all three shared Sunvault armies remain exact. The 59-sample queue improves from 26 to 23 medium-priority items with zero high and signature `276888b1`; focused battle, skirmish/save, salvage isolation, consequence, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `combat-decisive-attack-and-river-pass-opening-10184`. Shared tactical autoplay now presses an engaged melee strike only when its side retains at least 50% health, the hostile side has at most 40%, and strike trails defense by no more than 2 score; materially superior defense, depleted acting sides, ranged choices, and enemy withdrawal stay unchanged. Ghoul Grove hard moves from a round-7 defeat with 19% enemy health to a round-5 victory at 70% player health while normal remains a round-5 victory at 72%; its proven local `8/16/2` roster and shared Blackbranch army remain exact. The 59-sample queue stays exact at 26 medium / zero high with signature `8039155f`; the separate low-difficulty cohort watch remains open.
- Completed implementation slice: `balance-lockmarsh-surge-cohort-pressure-10184`. Lockmarsh Surge's proven Road Chaplains remain exact at 70% terminal margin and 28 enemy damage per round. Charter Guard now owns a local `7/6/2` roster and moves from 81% margin / 9 damage per round to 65% / 17; Archive Wardens own a local `7/9/2` roster and move from 81% / 9 to 70% / 19. The scenario cohort improves from 77% to 68%, removing its watch and lowering the active queue from 29 to 26 with zero high items and passing matrix/runtime gates. Focused battle, campaign menu, core, parse, repository, JSON, and diff validation pass.
- Completed implementation slice: `balance-reedbarrow-mireford-guard-pressure-10184`. Reedbarrow Ferry's Barrow Pickets now own a local 16-Cutthroat/11-Slinger guard and resolve in five rounds at 76% terminal margin and 6 enemy damage per round. Rootbound Mireford's Reed Totemists own a local 12-Slinger/12-Cutthroat/3-Ripper guard and resolve in three rounds at 74% margin and 25 enemy damage per round. Both shared armies remain exact. The 59-sample active breadth queue improves from 34 items / 4 high to 29 / 0 high, its matrix gate moves from warning to pass, and both runtime consequence gates remain passing. Focused battle, Mireford skirmish/save, campaign menu, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-orevein-contract-encounter-resolution-10184`. Blocked advances now apply their authored field-objective pressure, allowing obstruction lines to be forced aside without moving the blocked stack in that action. Orevein Bridgeward Levies retain their original roster but move from a round-14 stalemate with 87% enemy health to a five-round victory at 64% terminal margin and 20 enemy damage per round. Archive Wardens' local six-Guard/eight-Archer/one-Pikeward roster moves its battle from 91% margin / 6 damage per round to 83% / 15. The active breadth queue improves from 35 items / 6 high to 34 / 4; focused battle, Orevein skirmish, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-ninefold-barrow-vault-pressure-10184`. Ninefold Confluence's medium-difficulty Barrow Vault now owns a placement-local eight-Hedgehook/six-Thornbow guard instead of inheriting the shared 6/4 Bramble Hedge roster. Its deterministic battle moves from a two-round victory at 92% terminal margin and 7 enemy damage per round to a three-round player-advantaged victory at 70% and 15. The 59-sample active breadth queue improves from 38 items / 8 high to 35 / 6 with both runtime consequence gates passing. Shared neutral/faction inputs remain unchanged; focused battle, Ninefold smoke, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-bellwake-mirror-lancers-pressure-10184`. Bellwake Wreck Claim's placement-local Mirror Lancers now field nine Shard Guards, six Prism Adepts, and eight Mirror Duelists; the deterministic battle moves from a two-round victory at 98% terminal margin and 3 enemy damage per round to a three-round victory at 74% and 26. The adjacent zero-pressure Relay Pickets line now resolves at 87% margin and 7 enemy damage per round, while Aurora Battery remains unchanged. The 59-sample active breadth queue improves from 40 items / 10 high to 38 / 8. Shared Sunvault armies and the exact all-live faction matrix remain unchanged; focused battle, Bellwake skirmish, core, parse, repository, JSON, and diff gates pass.
- Completed implementation slice: `balance-ninefold-drowned-reliquary-pressure-10184`. Ninefold Confluence's high-difficulty Drowned Reliquary now owns a placement-local five-Cutter/eight-Reefbolt guard instead of inheriting the shared Skiffyard roster. The deterministic battle remains player-advantaged but moves from a flawless two-round victory to a four-round victory at 71% terminal margin and 11 enemy damage per round. The 59-sample active breadth queue improves from 44 items / 12 high to 40 / 10, and its runtime-consequence matrix moves from fail to pass. The unchanged all-live faction matrix, guarded rewards, core systems, Ninefold smoke, project parse, repository, JSON, and diff gates pass; remaining encounter and faction balance debt stays open.
- Completed implementation slice: `strategic-ai-ninefold-front-launch-retask-10184`. Ninefold Confluence now gives Brasshollow and Veilmourn open passable pressure origins, connects Bellwake Harbor to the badland road, and keeps Bellwake's common and rare development sources local without enclosing its raid host. The defense fixture preserves a real stabilization gap across faction rosters. All five Ninefold factions launch and retask correctly; the broader five-scenario harness records 9/9 pressure launches, 9/9 town-defense retasks, and 9/9 objective-front assignments with no failures. Ninefold smoke, core systems, full headless harness, project parse, repository, JSON, and diff validation pass. Overall game completion remains open.
- Completed implementation slice: `combat-brasshollow-foundry-saint-aura-10184`. Brasshollow's tier-7 Foundry Saint now projects Saint's Temper while alive: active Overheated Brasshollow machinery receives a bounded non-stacking defense bonus, and surviving allied stacks receive bounded non-resurrecting round-start repair with stronger Overheated repair. Readable healing events, tactical AI valuation, live summaries, focused runtime proof, and exact benchmark parity share the authored contract. The unchanged all-live matrix retains 36 outliers and 12 rows at or above 65%, improves severity from 300.0 to 293.5 and maximum dominance from 78.0% to 75.5%, and reduces excessive week-3 Brasshollow losses against Embercourt, Mireclaw, and Thornwake. Ability, focused autoplay balance/regression, town-development, core, parse, repository, JSON, and diff gates pass. The broader standard harness retains identical no-aura-control failures in the pre-existing 44-item active encounter queue and Ninefold Brasshollow/Veilmourn strategic-AI launch/retask cases; those remain overall-game debt rather than this slice's progress.
- Completed implementation slice: `combat-brasshollow-debt-engine-overheat-10184`. Brasshollow's tier-5 Debt-Engine Exactors now open primary strikes at 1.16x damage, then run at 0.83x damage with -2 defense and initiative for a non-refreshing two-round Overheated cycle. Tactical AI, live summaries, runtime resolution, and the fast benchmark share the contract. The unchanged all-live 100-seed matrix keeps 36 outliers and 12 rows at or above 65%, improves severity from 300.5 to 300.0 and maximum dominance from 78.5% to 78.0%, and reduces week-2 Brasshollow dominance versus Embercourt from 69% to 66% and Veilmourn from 71% to 68%. Ability, autoplay, town-development, core, parse, and repository gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `combat-brasshollow-crucible-barrage-10184`. Brasshollow's tier-6 Crucible Crawlers now own a live setup-siege Volley that strengthens long-lane fire and punishes staggered lines. The unchanged all-live 100-seed matrix improves from 37 to 36 outliers and severity 304 to 300.5, keeps maximum dominance at 78.5%, and leaves every week-1/2 row exact. Ability, autoplay, town-development, core, parse, and repository gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed corrective release-gate slice: `terrain-taxonomy-visual-regression-gate-10184`. River Pass now proves controlled legacy forest degradation while Ninefold asserts canonical authored grass/dirt, dirt/sand, and water/land boundaries. The longer River Pass suite was reconciled with shipped persistent-site, encounter-army, artifact-set, Waystride, full-route, and remote-town contracts without weakening detailed route payload checks. Both visual suites, full-route regression, project parsing, repository validation, JSON validation, and diff checks pass. This is validation maintenance, not implementation progress.
- Completed implementation slice: `overworld-hero-action-signature-reliability-10184`. Hero-action cache signatures now preserve nested pending-specialty choice records structurally instead of coercing every array member through `String`. The focused live regression proves unchanged-route reuse plus active-hero, roster, and nested-choice invalidation, including the `choose_specialty:spellwright` action; core systems and project parsing pass without the Godot 4.6 constructor error. Overall release completion remains open.
- Completed implementation slice: `combat-veilmourn-obituary-pressure-10184`. Veilmourn's tier-5 Obituary Scribes now issue one readable Final Notice per battle: the mark drains cohesion, weakens retaliation for one round, and applies stronger pressure to veteran braced lines. Battle tier/use state survives normalization and live BattleRules, Battle AI, and the fast benchmark share the contract. The unchanged all-live 100-seed matrix improves from 38 to 37 outliers, severity 336 to 304, maximum dominance 80.5% to 78.5%, and Thornwake/Veilmourn week 2 from 80.5% to 74.5%, with 12 rows still at or above 65%. Ability, live autoplay, core, parse, repository, JSON, and diff gates pass; the matrix remains `needs_tuning` and overall release completion remains open.
- Completed implementation slice: `ux-active-play-settings-overlay-10184`. Overworld, town, and battle now expose one shared modal Settings surface beside their existing Save/Menu controls. Audio levels, battle playback, UI scale, camera shake, color cues, high contrast, reduced motion, reduced flashes, and reduced repetitive sounds apply and persist without routing away or changing gameplay state; active battles adopt playback changes immediately. Keyboard/controller modal ownership, native accessibility semantics, 1280x720 and 1920x1080 rendered captures, packaged settings, Restore Defaults, core, shell visual, battle-layout, parse, repository, JSON, and diff gates pass. The unrelated pre-existing overworld terrain-degradation assertion remains explicit; overall release completion remains open.
- Completed implementation slice: `combat-battle-sfx-priority-mixing-10184`. All 21 imported battle SFX cues now own low/normal/high/critical priority and repeat-cooldown policy. Live playback rejects immediate duplicates before player creation, keeps the eight-voice cap, replaces the oldest lowest-priority voice only for a higher-priority cue, rejects low-priority arrivals under saturation, and creates no player while Effects is muted. The same slice fixes deferred native accessibility setup for controls freed before callback dispatch. Focused battle presentation, screen-reader semantics, core, parse, repository, JSON, and diff gates pass. Final sound design, platform audio certification, and overall release completion remain open.
- Completed implementation slice: `combat-veilmourn-maskglass-finisher-10184`. Veilmourn's tier-3 Maskglass Corsairs now execute their bible-defined disrupted/wounded-target finisher through the existing live `backstab` contract. Runtime coverage proves all 79/79 authored ability instances have consequences. The unchanged all-live 100-seed matrix improves from 40 to 38 outliers, severity 356 to 336, rows at or above 65% from 16 to 12, and maximum dominance from 83.5% to 80.5%, while structural, pacing, side-bias, town-development, core, parse, and repository gates pass. The matrix remains `needs_tuning`; final faction balance and overall release completion remain open.
- Completed implementation slice: `strategic-ai-task-planner-fit-context-reuse-10184`. The strategic task-board planner now reuses one faction path-distance surface across every planning origin and derives each assignable commander's immutable fit context once per pass. It also uses shallow top-level score overlays and retains already-materialized site families. Focused coverage proves 15/15 candidate scores and ordering remain exact; the strict-Small row preserves signature `9fff0a26` and exact events while one isolated sample moves from 1092 ms to 1083 ms and Mireclaw pre-build planning from 100 ms to 94 ms. This is a bounded redundant-work cleanup, not a broad performance or release-completion claim.
- Completed implementation slice: `packaging-release-source-provenance-10184`. Release-index schema v3 now binds both platform-manifest v2 payloads to one validated full Git revision and source-date epoch, while deterministic `build-info.json` files identify each Linux/Windows build inside archives and installed programs. Local revision derivation rejects tracked worktree changes; CI may provide an exact revision explicitly. Verification rejects invalid revisions, index/manifest disagreement, and build-info tampering. Thirteen focused artifact cases plus isolated Linux and Wine install/boot/uninstall lifecycles pass with both installed provenance files verified and external user data preserved. Code signing, project-license selection, storefront publication, native Windows hardware certification, and overall release completion remain open.
- Completed implementation slice: `combat-faction-pair-stat-tuning-followup-10184`. Reduced Stag-Knot Runner HP from 34 to 32 and maximum damage from 13 to 12, preserving Thornwake's fast reach role while lowering the unchanged all-live 100-seed matrix from 41 to 40 outliers, severity 389 to 356, rows at or above 65% from 18 to 16, and maximum dominance from 85% to 83.5%. Structural, pacing, side-bias, ability, town-development, core, parse, and repository gates pass. The matrix remains `needs_tuning`; final combat balance and overall release completion remain outside this slice.
- Completed implementation slice: `economy-authored-rare-source-breadth-10184`. Added 42 local capturable rare exchanges across all 18 active authored scenarios, with explicit live encounter ownership on 82 guarded resource nodes. All 20 player towns and 22 enemy towns now have reachable authored wood, ore, and all-six-rare routes; weekly exchange income preserves the day-24-to-day-30 development window, and player/AI delayed-source save-resume gates pass 20/20 and 22/22. Common-only markets, generated-map support, save version 9, and Native RMG behavior remain unchanged. Overall release completion remains outside this slice.
- Completed implementation slice: `combat-faction-pair-stat-tuning-10184`. Corrected the misplaced Thornwake `Root Brace` ownership, restored the authored Barkmantle/Pinning multipliers that predated compensation for that defect, and reduced the unchanged all-live 100-seed matrix from 45 to 41 outliers, severity 503.5 to 389, and 23 to 18 rows at or above 65%. Structural, side-bias, pacing, live battle, town-development, project-parse, and repository gates pass. The matrix remains `needs_tuning`; final faction balance, Native RMG, and overall release completion remain outside this slice.
- Completed implementation slice: `ux-manual-save-slot-naming-10184`. Occupied manual slots now accept a bounded optional player name from the shipped Saves board, persist it in the canonical slot payload, retain it through overwrite and reload, display it beside fixed slot identity, and clear it without changing expedition state. Autosave, empty, corrupt, invalid, and forged targets fail closed; unrelated slots, progression, settings, active session state, support diagnostics, and save version 9 remain unchanged. Focused persistence proof, 1280x720 and 1920x1080 captures, overwrite, delete, save/load confidence, menu/outcome, keyboard, core systems, project parsing, and repository validation pass. Cloud sync, save history, Native RMG, and overall release completion remain outside this slice.
- Completed implementation slice: `settings-confirmed-restore-defaults-10184`. The shipped Settings board now exposes a confirmed Restore Defaults command backed by one rollback-capable SettingsService operation. Confirmation names presentation, sound, gameplay, custom movement keys, and readability settings; success applies immediately, persists across reload, refreshes the board, and preserves expedition saves, campaign progress, active session state, support bundles, and save version 9. Focused cancellation/persistence proof, 1280x720 and 1920x1080 captures, packaged settings, menu/outcome, keyboard navigation, core systems, project parsing, and repository validation pass. Per-section resets, cloud/account settings, Native RMG, and overall release completion remain outside this slice.
- Completed implementation slice: `ux-manual-save-overwrite-confirmation-10184`. Manual saves from overworld, town, battle, and scenario outcome now require one shared exact slot-bound confirmation before replacing an occupied or unreadable manual slot, while empty slots remain one-step saves. Cancellation preserves exact bytes, invalid slots fail closed, and changing selection cannot redirect a pending overwrite. Focused four-route proof, 1280x720/1920x1080 captures, save/load confidence, menu/outcome, active-play keyboard, core systems, project parsing, and repository validation pass. Save renaming, cloud sync, undo/history, autosave confirmation, broad save-browser redesign, Native RMG, and overall release completion remain outside this slice.
- Completed implementation slice: `ux-save-slot-delete-workflow-10184`. The live Saves board now exposes a compact Delete Save command for any occupied autosave or manual slot, including corrupt/unloadable files, and requires exact slot-bound confirmation before removal. SaveService derives paths only from canonical autosave/manual identities, rejects unknown or invalid ids and forged paths, invalidates the selected summary cache after deletion, and refreshes the deleted row to Empty while recalculating latest save state. Focused proof covers cancellation, Manual Slot 2, autosave, corrupt-slot deletion, forged-path rejection, three preserved unrelated saves, campaign progression, device settings, active expedition state, and save version 9; 1280x720/1920x1080 captures, 1024x600 save-load confidence, lean boot, menu/outcome, core systems, project parsing, and repository validation pass. Save renaming, cloud sync, bulk deletion, Native RMG, and overall release completion remain open.
- Completed implementation slice: `campaign-arc-restart-workflow-10184`. The live campaign board now exposes a compact Restart Arc command only for arcs with recorded progress and requires a campaign-bound confirmation that reports the exact attempts, victories, and carryover being cleared. Confirmation persists a normalized campaign-local reset, returns the selected arc to its authored Chapter I, hides the now-inapplicable command, and preserves other campaign progress, expedition saves, device settings, selected difficulty, and save version 9. Focused persistence, 1280x720 and 1920x1080 visual captures, player-facing campaign flow, six-campaign breadth, menu/outcome, core systems, project parsing, and repository validation pass. Campaign content, balance, chapter rules, broad menu redesign, Native RMG, and overall release completion remain open.
- Completed implementation slice: `packaging-platform-native-installers-10184`. The verified Linux/Windows release pipeline now emits a reproducible Linux self-installing `.run` and Windows NSIS setup executable from the exact release payloads. Release-index schema v2 links and checksums both installers against their source archives; verification rejects outer and embedded-payload tampering. Isolated Linux and Wine lifecycles install and boot the packaged game, remove owned program and launcher files, and preserve external user data. Code signing, storefront/channel publication, system-wide installation, native Windows hardware certification, and overall release completion remain open.
- Completed implementation slice: `settings-accessibility-reduced-flash-10184`. Device settings now persist Reduce Flashes independently of reduced motion and battle shake. Normal motion, timing, audio, and combat remain unchanged while live battle event VFX use existing non-flashing fallback cues and spell-specific flash overlays are suppressed. The compact Readability settings surface remains reachable at 130% UI scale through a bounded scroll region, including the existing support-bundle command. Direct reload, exported-PCK persistence, menu control, live battle cue behavior, project parsing, core systems, and repository validation pass. Screen-reader integration, subtitles for nonexistent voiceover, broad VFX redesign, Native RMG, and overall release completion remain open.
- Completed implementation slice: `strategic-ai-emergency-recruitment-surface-reuse-10184`. During one enemy faction recruitment phase, non-garrison recruit invalidation now retains the immutable emergency-defense commander rotation/availability candidate list while rebuilding army probes and final point/commander choices from live roster continuity. Focused proof records one retained list, one load/three reuses, four rebuilt probe loads/four reuses, one accepted Reedsnare reinforcement, and the required Sable-to-Vaska destination switch with the same target and 149-strength/22-need selection. Town-defense and planned-task recruitment, core systems, a deterministic three-turn native-generated row with unchanged `fdf8234a` behavior signature, project parsing, and repository validation pass. AI scoring changes, final point-surface reuse, broad cache lifetime, save-state changes, Native RMG behavior, full seed-matrix completion, broad performance claims, and overall release completion remain open.
- Completed implementation slice: `strategic-ai-best-goal-tile-path-context-reuse-10184` makes best-staging-tile selection build one immutable path context and reuse it for the full goal set plus every candidate tile instead of repeatedly fingerprinting the same live state. Focused four-tile parity, two strict-Small generated seeds/six turns, core, editor, repository, and Linux/Windows packaged boots pass. Seed 1 retains exact `6a4530a2` behavior and 13-event mix while its path-heavy third turn improves from 1,926 ms to 1,849 ms in the method-matched sample. This is a bounded redundant-read cleanup, not the full 100-seed/eight-week matrix or release completion.
- Completed implementation slice: `strategic-ai-virtual-front-path-context-reuse-10184` gives each synthetic active-front support probe one immutable path context across all candidate fronts and both reachability/staging-tile reads, while real live-raid callers retain their established per-placement path behavior. Direct legacy candidate parity, active-front launch-surface reuse, two strict-Small seeds/six turns, core, editor, repository, and Linux/Windows packaged boots pass. Both generated signatures/events remain exact and aggregate active-front candidate time falls from 571 ms to 516 ms across six method-matched samples. This remains a bounded read-path cleanup, not broad AI or release completion.
- Completed implementation slice: `strategic-ai-first-movement-step-path-plan-reuse-10184` reuses the already-current pre-movement raid path plan for movement step zero instead of immediately rebuilding it before any position, target, or blocker change. Later steps and the post-move authoritative plan remain live. Trailglyph still casts and moves three steps; regroup/arrival behavior, both strict-Small signatures/events, core, editor, repository, and Linux/Windows packaged boots pass. Aggregate profiled step-path work falls from 40 ms to 28 ms across 16 method-matched active-raid lanes. This is a bounded path-read cleanup, not full matrix or release completion.
- Completed implementation slice: `economy-mireclaw-smuggler-exchange-10184`. Market Square, River Granary Exchange, Resonant Exchange, and Smugglers Flotilla now own authored market profiles instead of runtime building-id branches. The existing three profiles retain their rates, bulk orders, and weekly caps; Mireclaw's Flotilla supersedes Market Square with improved wood/ore liquidation, two-crate orders for either common resource, and 8-buy/10-sell weekly caps. The live Exchange Hall exposes eight ready orders and executes a two-ore sale for 836 gold while preserving common-only trading and save version 9. Focused action/cap persistence, 165 unique-building payoff cases, six town economy UI cases, all 15 town development cases, the 15-check economy scorecard, project parsing, and repository validation pass. Rare-resource trading, broad faction balance, strategic-AI policy, Native RMG behavior, and overall release completion remain open.
- Completed implementation slice: `packaging-player-support-bundle-export-10184`. The shipped runtime issue logger now exports a local `user://debug/heroes_support_bundle.json` with allowlisted app/platform/device-setting metadata and recent sanitized issue records, capped at 25 records and 512 KiB. Sensitive-key values and absolute Linux/Windows user paths are redacted, safe `res://` paths remain diagnostic, and the bundle explicitly contains no save payload, campaign progression, or telemetry destination. The existing Settings board exposes one compact export command with local success/failure feedback and desktop file-manager reveal. Direct runtime coverage proves record-cap and byte-limit trimming preserve the newest issue, the menu outcome smoke covers the player command/privacy contract, and a 185,355,808-byte exported PCK executes the same path successfully. Signing, native Windows hardware certification, automatic upload, crash minidumps, release-channel integration, and overall release completion remain open.
- Completed implementation slice: `strategic-ai-active-front-launch-surface-reuse-10184`. Below-threshold active-front readiness now builds commander/origin support candidates in an isolated phase-local context, passes only the exact completed surface through the existing launch cache, reuses every point during final selection, and consumes the surface before later launch scans. Focused proof covers exact per-origin and selected-candidate parity, isolation from conflicting outer-cache entries, one load/two point reuses/one consume, and live recomputation after consumption. The core systems smoke, strategic planner/recruitment/regroup reports, five-case baseline KPI matrix, generated-map profile, project parse, and repository validation pass. The targeted generated row signature and event counts remain unchanged; one profile shard is not evidence of a broad wall-clock improvement. AI scoring, launch priority, save state, public events, Native RMG output, and overall release completion remain unchanged.
- Completed implementation slice: `hero-field-rendezvous-spell-sharing-10184`. Co-located owned commanders now expose named one-spell teaching actions in both directions through the existing compact keyboard/controller-reachable rendezvous selector. Teaching copies authored spell knowledge without removing it from the source, preserves both mana pools and movement state, removes stale duplicate-knowledge actions, and persists both spellbooks through normalization and save version 9. Remote, stale, uncontrolled, unknown-source, and malformed calls fail without mutation. Focused live UI/save coverage plus troop/artifact rendezvous, adventure/battle spell behavior, resistance/counter-control, core systems, town/battle visual smoke, project parsing, and repository validation pass. Remote teaching, enemy diplomacy, automatic whole-spellbook synchronization, Native RMG changes, and overall release completion remain open.
- Completed implementation slice: `hero-field-rendezvous-artifact-transfer-10184`. Co-located owned commanders now expose named artifact handoffs in both directions through the existing compact keyboard/controller-reachable rendezvous selector. Equipped and packed artifacts move atomically without duplication or loss; empty compatible target slots auto-equip, occupied slot families preserve their loadout and receive the item in inventory, movement deficits and set-aware bonuses update immediately, and both loadouts persist through normalization and save version 9. Remote, stale, duplicate-target, and malformed calls fail without mutation. Focused artifact handoff plus existing troop rendezvous, artifact equipment, core systems, town/battle visual smoke, project parsing, and repository validation pass. Remote logistics, enemy diplomacy, automatic loadout optimization, Native RMG changes, and overall release completion remain open.
- Completed implementation slice: `hero-field-rendezvous-army-transfer-10184`. Visible reserve commanders are now named route destinations; direct and cached route execution resolves a field rendezvous instead of silent overlap. Co-located owned heroes expose a compact keyboard/controller-reachable Command-drawer selector for one, half, or all troops in either direction, matching stacks merge, remote transfers are rejected, and both armies persist through normalization and save version 9. Focused direct/cached route, transfer, UI, and save coverage plus hero-roster refresh, core systems, town/battle visual smoke, project parsing, and repository validation pass. Remote transfers, convoy automation, enemy diplomacy, Native RMG changes, and overall release completion remain open.
- Completed implementation slice: `packaging-user-local-install-workflow-10184`. Verified Linux and Windows release archives now carry per-user install/uninstall scripts alongside their runtime payloads. Linux installs the executable/PCK/native library, command launcher, and desktop entry; Windows installs the EXE/PCK/DLL and Start Menu launcher. Isolated Linux and Wine workflows install, boot the installed build, uninstall all program/launcher files, and preserve external user data. Release manifests, archive verification, focused packaging tests, and repository validation pass. Signing, MSI/NSIS/AppImage generation, system-wide installation, native Windows hardware certification, distribution channels, and overall release completion remain open.
- Completed implementation slice: `artifact-pickup-source-execution-10184`. The final inactive artifact source table now executes through selected Mireford and Orevein common caches with two bounded candidates. Runtime construction deterministically materializes Trailsinger Boots or Quarry Tally Rod from a scenario/placement source key before presentation or AI valuation, persists the item/table/key through repeated normalization and save version 9, and grants/equips that same item through player, assigned strategic-AI, and opportunistic-route claims. Non-opted Bellwake fixed caches remain exact. Focused behavior, all previously live artifact reward paths, taxonomy/source accounting, equipment/set behavior, AI artifact objectives, core systems, project parsing, and repository validation pass. The existing unrelated stale terrain assertion in `overworld_visual_smoke` remains outside this slice, as do rare-resource artifact income, broad random drops, Native RMG changes, and overall release completion.
- Completed implementation slice: `artifact-town-commission-service-10184`. Embercourt Lockhouse Tally and Brasshollow Scalehouse now activate the authored town artifact table through the existing compact gear lane. Eligible player towns expose one common-resource commission after construction, grant and auto-equip Tollstone Ring or Pressure Gauge Reliquary, persist one-time table/source/owner/faction/day/building provenance through save version 9, and reject unbuilt, repeated, unaffordable, or faction-ineligible attempts without charging. Focused behavior, all previously live artifact reward paths, artifact equipment/set behavior, 165 unique-building payoff cases, town build limits, core systems, town/battle visual smoke, project parsing, and repository validation pass. Pickup randomization, AI purchasing, rare-resource costs, broad town UI redesign, artifact balance changes, and overall release completion remain outside this slice.
- Completed implementation slice: `artifact-dwelling-reward-execution-10184`. Rootwatch Hollow is now placed in Rootbound Mireford, and Rootwatch Hollow plus Ninefold's Greenbranch Copse execute the authored Thornwake dwelling-support table. Eligible Thornwake player, direct strategic-AI, and opportunistic-route claims deterministically grant and auto-equip Living Bridge Knot while preserving claim recruits, persistent control, one-time node provenance, AI empire/public-event state, and save-version-9 continuity; Embercourt receives normal dwelling control and recruits without an artifact. Pickup, town-service, broad random drops, rare-resource artifact income, and overall release completion remain outside this slice.
- Completed implementation slice: `packaging-release-artifact-verification-10184`. The production release packager now automatically reopens final Linux and Windows archives and also exposes `--verify-only`; it rejects unsafe, duplicate, encrypted, link, special, stale, unexpected, or oversized entries, proves exact payload membership, validates `SHA256SUMS`, release-index and embedded-manifest agreement, every payload size/hash, Linux x86_64 ELF/executable modes, and Windows x86_64 PE headers for both executables and native sidecars, and fails on tampering. Synthetic destructive cases and real reproducible alpha archives pass without claiming signing, installer/channel integration, clean native Windows-machine certification, or overall release readiness.
- Completed implementation slice: `artifact-shrine-reward-execution-10184`. Starlens Sanctum now executes the authored shrine artifact table through player, direct strategic-AI, and opportunistic route claims. Eligible Sunvault commanders deterministically receive and auto-equip Choir Tuning Fork while Beacon Path, one-time node provenance, faction gating, AI empire tracking, public event boundaries, and save-version-9 continuity remain intact; Embercourt receives the normal shrine and spell reward without an artifact. Pickup, other shrines, dwelling, town-service, broad random drops, rare-resource income, and overall release completion remain outside this slice.
- Completed implementation slice: `strategic-ai-task-reconcile-roster-reuse-10184`. Live task-board reconciliation now loads one normalized faction commander-roster snapshot per pass and reuses it for all actor lifecycle and resume checks, while preserving reconciliation, reservation repair, pruning, planner writes, and exact Medium ordinal-99 behavior. A current-HEAD control and final implementation both terminate after 43 turns with row signature `ffa259b1`, 209 activity events, 30 target assignments, and zero behavior, integrity, reachability, or stall failures. The directly affected three-turn post-raid planner sample fell from 514 ms to 463 ms, while the full-run planner delta was noise-level and whole-row wall time did not improve measurably; this is a redundant-work cleanup, not matrix completion or overall release completion.
- Completed implementation slice: `artifact-battle-salvage-execution-10184`. Bellwake Wreck Claim's Aurora Battery now executes the authored heavy battle-salvage table through the real player-victory path, deterministically grants and auto-equips Warcrest Pennon while reserving the map's Black-Sail Compass, surfaces the claim in battle aftermath, records one-time source provenance, and survives save-version-9 resume. Relay Pickets remain ineligible, duplicate and cross-faction claims are rejected, guarded-site behavior and broad battle/core regressions pass, and this is not overall release completion.
- Completed implementation slice: `artifact-guarded-site-reward-execution-10184`. Barrow Vault and Drowned Reliquary now have live linked guards on Ninefold Confluence; after clearance, first player or strategic-AI capture deterministically awards and auto-equips an eligible guarded-site artifact, records table/source/owner/day provenance, and survives save/resume without a save-version bump. Player collection, AI commander/empire state, repeat-claim rejection, nearby artifact/AI regressions, broad core smoke, and repository validation pass. Pickup, shrine, dwelling, and town-service source tables remain separate follow-ups; this is not overall release completion.
- Completed implementation slice: `frontier-claims-three-faction-campaign-10184`. Frontier Claims is now the sixth player-facing campaign, linking Rootbound Mireford, Orevein Contract, and Bellwake Wreck Claim as three ordered dual-mode chapters. Live campaign rules prove difficulty-aware launch, locks/unlocks, bounded cross-faction resource and objective carryover, faction-specific commander/spell/artifact isolation, save/resume metadata, completion/replay, and unchanged standalone skirmish progression. All 18 authored scenarios are now campaign and skirmish selectable. This is one campaign-breadth increment, not three full faction campaigns or release completion.
- Completed implementation slice: `veilmourn-bellwake-wreck-player-skirmish-10184`. Bellwake Wreck Claim now launches as Veilmourn's first authored player-facing skirmish with Ivara Blacktide, Bellwake Harbor, a four-stack claim army, live Memory Salt and wreck-salvage routes, Sunvault strategic pressure, and three tuned encounter fronts. Focused runtime coverage proves menu exposure, town recruitment/development, save/resume, reachable outcomes, campaign-progression isolation, bounded battles, and a Day 26 seven-tier development runway. This is one production-content increment, not a Veilmourn campaign, six-faction completion, or release completion.
- Completed implementation slice: `brasshollow-orevein-player-skirmish-10184`. The skirmish-only Orevein Contract now launches as Brasshollow with Marka Ironclause, Orevein Gantry, a four-stack contract column, an authored assay-depot economy route, reactive Embercourt pressure, and three scenario-local encounter rosters. Focused live-flow coverage proves town recruitment, save/resume, battle entry, reachable victory/defeat, and campaign-progression isolation; fixed-seed battles finish with 90%, 88%, and 62% player health, and the full town runway completes on Day 26 with delayed-source save/resume. This is one production-content increment, not a Brasshollow campaign, six-faction completion, or release completion.
- Completed implementation slice: `thornwake-mireford-player-skirmish-10184`. The skirmish-only Rootbound Mireford front now launches as Thornwake with Silsa Bramble-Hound, Graftroot Caravan, a scenario-local four-stack army, Verdant Graft route, Thornwake reinforcement hooks, and an exploration-first economy tuned to complete the live town runway on Day 24. Focused production-rule coverage proves menu setup, recruitment, save/resume, Ford Reavers battle entry, victory/defeat reachability, and campaign-progression isolation; both retained Mireclaw encounter balance regressions pass with bounded player health. Targeted runway filtering now keeps per-scenario gates intact without applying full-suite count floors. This is one authored faction-breadth increment, not a complete Thornwake campaign, six-faction completion, or release completion; the unfiltered runway still reports 12 pre-existing early-completion cases outside Mireford.
- Completed implementation slice: `artifact-dual-trinket-set-bonus-runtime-10184`. Hero artifact state now exposes two backward-compatible trinket keys, compatible equip paths fill empty slots before deterministic primary-slot replacement, and the three equipped Wayfarer Compact pieces activate cumulative 2-piece movement and 3-piece scouting thresholds. Focused runtime proof measures +4 movement and +5 scouting including piece bonuses, preserves both trinkets and thresholds through save-version-9 resume, and surfaces active set progress on existing management/town paths. A responsive-shell regression uncovered during validation now hides the wide-screen Order panel while contextual drawers are open and restores it when they close. Source reward execution, rare-resource artifact income, additional sets, broad UI redesign, final artifact balance, and the unrelated stale terrain assertion in `overworld_visual_smoke` remain outside this slice.
- Completed implementation slice: `packaging-platform-readiness-followup-10184`. Linux and Windows release presets now exclude generated developer maps, tests, reports, source art, build/native-source trees, operational metadata, and debug utilities while preserving runtime assets and the native extension manifest. `project.godot` carries alpha version `0.1.0-alpha.1`; `tools/package_release.py` exports both platforms and emits reproducible tar/ZIP bundles, per-platform payload manifests, a release index, and SHA-256 checksums. The packaged Linux binary boots cleanly with imported resources resolved through `ResourceLoader.exists`; Windows export produces a valid PE executable, release DLL, and matching PCK. This does not claim clean Windows-machine execution, signing, installer/channel integration, or overall release readiness.
- Completed implementation slice: `packaging-windows-wine-runtime-smoke-10184`. The Windows Release v2 gate now exports the PE/PCK/DLL set, recreates an isolated Wine prefix, boots the packaged executable headlessly, and requires Godot, Boot, MainMenu, and release GDExtension DLL loader markers with no fatal runtime output. Wine 9's crashing DirectInput path is disabled only for this harness; clean native Windows execution, controller/hardware validation, signing, installer/channel integration, and overall release readiness remain incomplete.
- Completed implementation slice: `strategic-ai-recruitment-path-cache-10184`. One faction recruitment phase now retains immutable raid route contexts, live-task/path state, and per-town saved plans while continuing to rebuild commander/raid strength, reinforcement need, and destination scores after every transfer. Focused coverage loads 10 saved plans once and reuses them 28 times, proves live strength changes can switch the best task and final destination, and reuses a raid route context without changing its decision payload. Exact Medium ordinal 99 preserves row signature `437fc4a9` and all behavior counts while local row runtime falls from `296491ms` to `265400ms` and maximum turn runtime from `13149ms` to `11665ms`. This does not complete all strategic-AI performance work, the paused release matrix, or the game release.
- Completed implementation slice: `settings-accessibility-color-cue-assist-10184`. Settings schema v8 persists Standard or Shape + Palette color cues; the assisted mode applies blue/cyan success and player cues, orange danger and enemy cues, distinct battle-stack side marks, and distinct overworld-town pennant shapes while preserving terrain and faction art. Battle movement guidance no longer depends on “green hex” wording, the live menu remains usable with high contrast at 130-percent scaling, and active-shell plus exported-PCK validation passes. This does not claim medical simulation certification, final accessibility, clean Windows execution, or overall release readiness.
- Completed implementation slice: `native-rmg-source-order-h3maped-alignment-10184` / tracker slice `rmg-small-generalization-hardening-10184`. The source-backed selected release matrix is byte-exact for all 24 workflows across Small, Medium, Large, and XLarge sizes; one and two levels; and land, normal-water, and Islands modes. The final XLarge two-level authorities are exact for normal-water seed 77 (`365777` bytes, `2779` objects, `609` definitions, SHA-256 `3760cbf8b03b9e84b1670ef296cab84a6756eebf9018c3a19bac484108e4d12a`) and Islands seed 78 (`348675` bytes, `1998` objects, `517` definitions, SHA-256 `e0c95a541f8d9727a3755f57dd5c82197706bf6e9035a9fa4b57ac4f88b34d00`). Public `MapPackageService::generate_random_map` now builds the parity-owned payload, paired map/scenario documents, deterministic package-session identity, populated starts, town bindings, visit/body/package tiles, and guard/reward references without external authority files for the supported matrix. Unsupported shapes or monster strengths fail closed. Linux and Windows Debug/Release native outputs build, native self-tests pass on Linux and under Wine, the Godot end-to-end runtime boundary passes, and repository validation passes. This completion claim is limited to the supported 24-workflow release matrix; it does not claim arbitrary H3MapEd configuration or allocator-history parity outside that scope.
- Single H3MapEd RMG recovery ledger: `docs/h3maped-rmg-end-to-end-behavior.md`. Use it as the first source map for recovered H3MapEd phase order, private state, generated-cell words, bit fields, helper behavior, and final writeout evidence before touching native RMG code. It is not native implementation status.
- Native adapter drift audit: `docs/native-rmg-core-h3maped-drift-audit.md` marks where `src/gdextension/src/rmg_native_core.cpp` and its header still diverge from the recovery ledger. Treat those drift IDs as the current native-port backlog, not as completed implementation.
- Latest native RMG implementation correction: the recovered Islands-only `0x4a30c2 -> 0x4a2cdc -> 0x4a2e91` coast path now consumes the H3MapEd RNG stream and writes owner-boundary private state before `0x4a2ec3`, producing exact Small seed-60 Islands output (`21526` bytes, `193` objects). The fail-closed authority profile and CLI gates now include Small Islands, Medium normal-water, and the exact Large seed-18 eight-player/two-team profile; stale strict-scope labels no longer reject supported workflows. The Large team payload is exact at `159868` bytes / `2873` objects and now exports paired runtime packages through the authorized path. Public runtime projection consumes only internally assembled native sections, rejects tampered section streams, and no longer requires authority files for supported configurations. This is real native/runtime behavior and supported-matrix completion, not whole-H3MapEd configuration parity.
- Previous native RMG implementation update: `h3maped_rmg_core` aligns recovered `0x4a901a` weighted candidate source identity and selected type-98 wrapper inputs. Ghidra shows `0x4a901a` compares generated-cell `+0x20` byte2 against the source-pair `+0x00` identity, reads the value floor from the same `+0x20` low word, shrinks scan bounds from the selected type-98 bucket wrapper source record `+0x34/+0x38`, and feeds that selected source record into `0x49aa93`; native follows those inputs instead of using relation owner / outer join source for the weighted scan. The source-pair wrapper overload no longer treats object catalog index as a generated-cell owner identity, and `h3maped_rmg_core_selftest` rejects the stale relation-owner gate.
- Latest native RMG implementation update: `h3maped_rmg_core` now aligns recovered `0x49b3fb` endpoint lookup semantics. Native no longer translates the lookup argument through runtime-zone ids; the helper selects the current relation owner by generated-cell owner key, scans that owner's `+0xc8/+0xcc` 0x1c-byte endpoint records, and compares each record's first dword directly with the single lookup argument, matching the Ghidra dump. `0x4a79a3` reciprocal endpoint lookup now passes the same generated-cell owner keys instead of runtime-zone ids, and the selftest rejects the stale runtime-zone remap. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload is `10872` native bytes vs `17057` H3MapEd bytes, object payload first byte is native `5` vs expected `2`, object appends are `836`, and decorative bit26 candidates are `3078`. Runtime/native map output remains disabled. This is source-backed `0x49b3fb` relation/endpoint-chain alignment, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now aligns the reward/guard `0x4aa9b7/0x4aa603` owner gate with recovered source behavior: `0x4aa9b7` reads `relation+0x00`, dereferences the relation source pointer, and compares that first dword against generated-cell `+0x20` byte2. Native no longer treats the separate relation owner byte as the reward/guard gate when a recovered source-pointer owner is available, and the selftest now rejects the stale split-owner interpretation. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload is `10872` native bytes vs `17057` H3MapEd bytes, native generated-object count is `836`, and successful direct `0x4aa9b7` commits remain `87`. Runtime/native map output remains disabled. This is source-backed reward/guard gate alignment, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now keeps recovered `0x4a4522` TerrainPlacement wrapper finalization unconditional. Ghidra shows `0x4a4522` constructs the local TerrainPlacement wrapper, walks the brush mask, and then always reaches `0x4bd077` finalization; native no longer skips `0x4bd077 -> 0x4bc5f0/0x4bbfcc` when the mask produces an empty `0x4bd099` point feed. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload is `10922` native bytes vs `17057` H3MapEd bytes, native generated-object appends are `845`, native `0x49eb8d` decorative bit26 candidates are `3236` vs recovered H3MapEd `2284`, `0x4a4522` brush calls remain `1`, and the fixture's final-sweep count remains `62208`. Runtime/native map output remains disabled. This corrects a recovered wrapper-lifetime drift; it is source-backed alignment, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now corrects the recovered `0x4a4c8e` second `0x49aa63(true)` callsite bounds from the Ghidra instruction window `0x4e01..0x4e5f`: the boundary-trigger scan remains the recovered 3x3 check, the triggered center still calls `0x49aa63(true)`, the second terrain/object-span-gated candidate pass is narrowed to the current pseudo-coordinate cell, and the following `0x49a932(false)` occupied-clear pass remains the recovered 3x3 object-reference-span-gated loop. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload is `10922` native bytes vs `17057` H3MapEd bytes, native generated-object appends are `845`, native `0x49eb8d` decorative bit26 candidates are `3236` vs recovered H3MapEd `2284`, and post-`0x4a4c8e` cleanup calls `0x49a962` seven times. Runtime/native map output remains disabled. This corrects an over-broad prior implementation of the second candidate callsite; it is source-backed alignment, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` restored the recovered `0x4a4c8e` boundary call shape after checking the Ghidra callsites: the triggered center still calls `0x49aa63(true)`, the neighbor candidate pass calls `0x49aa63(true)` for terrain-non-8 cells with empty object-reference spans, and the following occupied-clear pass calls `0x49a932(false)` using the recovered object-reference-span gate rather than the unrelated `0x49a962` bit22/valid/terrain predicates. Focused no-Godot Medium seed-10 setup-1 still reached final payload compare and remained blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matched `36288/36288`, first mismatch remained offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload was `11234` native bytes vs `17057` H3MapEd bytes, native generated-object appends were `871`, and native `0x49eb8d` decorative bit26 candidates were `3280` vs recovered H3MapEd `2284`. Runtime/native map output remained disabled. This was source-backed `0x4a4c8e` implementation progress, but the second candidate pass bounds were corrected by the latest update.
- Previous native RMG implementation update: `h3maped_rmg_core` now ports the recovered `0x4a8722` route-helper random split span from relation/source `+0x1c`: route recursion fails closed if the carried source span is missing or nonpositive, uses `min(source +0x1c, distance)` as the `0x4e7276` modulus/half-offset span, and still divides the geometric displacement by full `0x4cc5ad` distance as H3MapEd does. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload is `10922` native bytes vs `17057` H3MapEd bytes, native generated objects are `845`, and native `0x49eb8d` decorative bit26 candidates are `3236` vs recovered H3MapEd `2284`. Runtime/native map output remains disabled. This is source-backed route-helper implementation progress, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now splits the recovered generated-cell object-reference span gates for `0x4a5767` and `0x4a89da`: `0x4a5767` preserves the recovered single-reference first-pass coordinate path, while `0x4a89da` skips candidate marking for any positive aligned object-reference span. The `0x4a8260` initial object-span classification is now explicit as the recovered direct bit26/bit27 write block, and `0x4a4c8e` no longer spreads candidate bit26 across a 3x3 neighborhood; only the recovered center candidate write remains while the 3x3 `0x49a932(false)` clear pass is preserved. Focused no-Godot Medium seed-10 setup-1 still reaches final payload compare and remains blocked at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches `36288/36288`, first mismatch remains offset `1` with native byte `53` vs H3MapEd `54`, generated-object payload moved to `11082` native bytes vs `17057` H3MapEd bytes, and native `0x49eb8d` decorative bit26 candidates are `3264` vs recovered H3MapEd `2284`. Runtime/native map output remains disabled. This is source-backed generated-cell mutation/order implementation progress, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries source-order source-record `+0x00` identity through `0x4a8d2c/0x4a8db2/0x4a901a/0x4a93a2` state separately from the relation-owner byte used by the current generated-cell scan path. The unsafe experiment of treating that identity as a universal generated-cell owner gate was rejected because it regressed Small seed-58 before final writeout; the selftest now preserves recovered `0x49b452` source-pointer identity while the live placement scan remains relation-byte based until the remaining owner-byte semantics are reconciled. Focused no-Godot Small seed-58 setup-3 and Medium seed-10 setup-1 both reach `final_payload_compare`; Medium seed-10 setup-1 remains at 809 generated objects / 10,159 generated-object payload bytes and blocks at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`. Runtime/native map output remains disabled. This is source-backed identity preservation and regression prevention, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now routes synthetic `0x4a3dbc` relation owners through the recovered `0x49b452` constructor path instead of hand-building a partial owner. The synthetic source record preserves the recovered type-3 overwrite, fixed treasure bands, appended relation-vector owner byte, and post-constructor relation `+0x0c = 8`; `0x4a4913` now treats empty/sentinel type-8 scan bounds as the recovered no-op loop case instead of failing before the loop. Focused no-Godot Medium seed-10 setup-1 reaches ordered final writeout, writes 809 generated objects / 10,159 generated-object payload bytes, and blocks at `final_payload_compare` with `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length is 36,288 bytes with first mismatch offset 0 (`native=0`, `h3maped=2`), and generated-object payload first mismatch offset 1 (`native=3`, `h3maped=0`). Runtime/native map output remains disabled. This is source-backed synthetic-owner constructor/materialization progress, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now creates the live type-98 town/castle `+0xedc` source-pair feed inside the single relation-pointer source-order workflow instead of requiring it to pre-exist or reconstructing it from runtime-zone fields. `0x4903e8 -> 0x4af785` now creates the source-backed type-98 wrapper/source pair, preserves the `+0xedc` pair back onto generator private state, annotates the carried relation/key/anchor/lane context, and lets `0x4a8d2c/0x4a8db2` run from that wrapper context. Focused no-Godot Small seed-58 setup-3 now advances through source-order, route, relation scan, mine/resource, reward/guard, decoration, roads, final header/tile/object payload assembly, and blocks only at final payload compare because the available same-run authority profile is Medium-scoped. Focused no-Godot Medium seed-10 setup-0 now advances past source-order and route/free-cell, then blocks at the downstream source-backed `connection_tail` reason `0x4a79a3_direct_endpoint_0x4a7312_0x4a54a7_blocked_at_record_4_0x4a79a3_exact_target_object_reference_vector_not_empty`. Runtime/native map output remains disabled. This is source-backed source-order implementation progress, not final-payload parity or runtime generation authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now ports the recovered `0x4aadd2` terrain-pressure alias where relation owner terrain index `-1` increments generator `+0xf60` through the `+0xf64[-1]` alias and then the explicit total increment. The final reward/guard payload path also carries recovered selected-candidate constructor state through `0x4a9f1c -> 0x4aa166 -> 0x4a54a7 -> 0x4ad3eb`: `0x540bf0 -> 0x49c764` builds the dynamic Pandora spell vector from the 70-entry `0x592520`/`sptraits.txt` spell table, and `0x540bc0 -> 0x49c69b` copies monster candidate `+0x14/+0x18` into final object `+0x3c/+0x40`. Focused no-Godot Medium seed-10 setup-0 now serializes all 915 generated objects, writes the `0x4ad3db` final zero sentinel, and emits final payload sections; `bin/h3maped_rmg_core_selftest` is green. The workflow still returns `blocked` at `final_payload_compare` with `same_run_payload_authority_missing_0x49ecf2_setup_profile_join`, tile/object byte parity is still false, `native_rmg_end_to_end_parity_complete=false`, and runtime/native map output remains disabled. This is source-backed final-object serializer implementation progress, not final-payload parity or runtime map-output authorization.
- Superseded native RMG setup note: an earlier update described setup object `+0x48` as a direct caller copy into generator `+0x10bc`. Current recovered caller evidence supersedes that: `0x4adfe1` prepares the `0x49ecf2` callee argument as `clamp(raw + 3, 1, 5)`, and the native workflow now carries raw controlled-case `+0x48` plus the prepared callee value explicitly. Do not reintroduce the stale direct-copy interpretation.
- Previous native RMG implementation update: `h3maped_rmg_core` now removes the stale relation-owner vector-slot override from the recovered `0x4a3a03 -> 0x4a2777/0x4a325d` relation-owner handoff. When a source payload owner word exists, both the private span owner and generated-cell `+0x20` byte2 use that recovered source owner; the selftest forces vector slot `0` with source owner `9` and asserts byte2 carries `9`. The same update stops treating the available stitched H3MapEd final-payload authority as fixed native 2p byte authority: that payload was captured from `Human/Computer=1`, `Computer only=Random`, `Monster strength=Random`, so the focused no-Godot Medium seed-10 fixed 2p workflow now fails closed at `same_run_payload_authority_profile_is_hc1_computer_random_not_fixed_native_2p`. Runtime map output remains unauthorized. This is source-backed owner-state implementation progress and blocker correction, not final-payload parity.
- Previous native RMG implementation update: `h3maped_rmg_core` now uses the recovered `0x57c648[type*16+0x0c]` serialize-first-pass table for `0x4ad1e3` generated-object payload pass splitting, and the split key now comes from the recovered object-record `+0x04 -> source row +0x1c` path via carried `0x4af785` wrapper/source state instead of the native local descriptor/provider field. The old native `+0x0c` constant was actually the 34-entry `+0x02` secondary gate table; it is now separated from the recovered 95-entry `+0x0c` first-pass table. Focused no-Godot Medium seed-10 setup-0 keeps 902 generated objects / 210 definitions / 12,618 generated-object payload bytes, but first-pass records move from 177 to 656 and now start with base decorative source types such as 134/147/119/155 instead of local descriptor type 54 mine/monster records. The same run still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`, and runtime map output remains unauthorized. This is source-backed final-object pass-split behavior progress, not final-payload parity.
- Previous native RMG implementation update: `h3maped_rmg_core` now uses the recovered one-level land template size-score band for supported Small/Medium maps instead of letting Small land collapse to the 21-candidate score-1 set. Small seed-58 setup-3 and Medium seed-10 setup-0 both preserve the recovered 35 accepted candidate containers; Small seed-58 setup-3 selects `3SB0c`, carries 10 relation owners, assembles 248 generated objects / 19,265 payload bytes, and stops at `full_final_payload_same_run_compare_pending_after_ordered_payload_assembly`. Medium seed-10 setup-0 selects `Ready or Not`, carries 10 relation owners, assembles 656 generated objects / 54,857 payload bytes, and still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`. This is source-backed template-selection/private-state alignment progress, not final-payload parity or runtime map-output authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries recovered relation-owner local-vector `+0x404` records as concrete `(x,y)` payloads instead of count-only state, and ports the recovered `0x4a8bfc` vector-count behavior into the `0x4a89da` relation-source-order scan. The first `+0x404` record now drives the recovered projection reset and `0x49a318` propagation path; later records are scanned for the still-unported `0x4a8722` route-helper path and fail closed if that path is actually reached. Focused no-Godot Small seed-58 setup-3 now executes through relation scan, mine/resource, reward/guard, connection/road, final header/tile/object payload assembly, and stops at `final_payload_compare` with `full_final_payload_same_run_compare_pending_after_ordered_payload_assembly` because the same-run authority payload is scoped to the Medium fixture. Focused no-Godot Medium seed-10 setup-0 also reaches `final_payload_compare` and fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`; tile bytes remain 36288 vs 36288 and native map output remains disabled. This is source-backed private-state handoff progress, not final-payload parity or runtime map-output authorization. The active blocker is same-run final tile/generated-object payload parity, starting with upstream generated-cell/TerrainPlacement state before `0x49b2b6` and generated-object payload materialization before `0x4ad3eb`.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries recovered type-98 source-pair `+0x04` wrapper context into live `0x4a8db2` scheduler replays. The relation-pointer and live type-98 scheduler paths no longer pass compact relation-owner vector indexes as context when a type-98 descriptor is required; they require the `0x4af785` selected wrapper index and fail closed as `0x4a8db2_type98_context_wrapper_0x04_missing` if it is absent. `h3maped_rmg_core_selftest` now asserts the entry-to-writeout workflow carries scheduler contexts from the recovered `+0xedc` source-pair wrapper payload. Focused no-Godot Medium seed-10 setup-0 shows the first scheduler contexts as `1328,1329,1330,1330,1331,1328`, matching the recovered type-98 source-pair contexts instead of the old owner-slot values `0..5`. The same run still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile bytes remain 36288 vs 36288 with first mismatch offset 1 (`native=55`, `h3maped=54`); generated-object payload remains 8524 native bytes vs 17057 H3MapEd bytes with first mismatch offset 0 (`native=30`, `h3maped=2`). This is source-backed private-state handoff progress, not final-payload parity or runtime map-output authorization. The active blockers remain upstream generated-cell/TerrainPlacement private state before `0x49b2b6`, plus broader generated-object vector/source-pointer materialization count/order parity before `0x4ad3eb`.
- Previous native RMG implementation update: `h3maped_rmg_core` now keeps recovered type-98 weighted town materialization source-backed without faking a `0x4903e8` descriptor join, while still requiring the `0x4af785` resolver/wrapper state before `0x4a93a2 -> 0x4a901a -> 0x4a54a7` can commit. Type-98 descriptor bridge prep now blocks when the selected wrapper index is missing, and the relation-pointer, live scheduler, and live direct type-98 source-order replay paths use the generator-owned resolver state instead of throwaway local resolver state, preserving the `+0xedc` source-pair mirror back onto generator private state. `h3maped_rmg_core_selftest` covers the distinction: type-98 remains a recovered `0x4a93a2` bridge, not a fake joined target context, but it must carry a selected `0x4af785` wrapper/source-pair and commit-time wrapper `+0x08` reference increment. Focused no-Godot Medium seed-10 setup-0 still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile bytes remain 36288 vs 36288 with first mismatch offset 1 (`native=55`, `h3maped=54`); generated-object payload remains 8524 native bytes vs 17057 H3MapEd bytes with first mismatch offset 0 (`native=30`, `h3maped=2`). This is source-backed generated-object identity implementation progress, not final-payload parity or runtime map-output authorization. The active blockers remain upstream generated-cell/TerrainPlacement private state before `0x49b2b6`, plus broader generated-object vector/source-pointer materialization count/order parity before `0x4ad3eb`.
- Previous native RMG implementation update: `h3maped_rmg_core` now separates the recovered final-sweep class-0 `0x4bbfcc -> 0x4bc5a3 -> toolkit +0x10 / 0x4ba938` selector from the base `0x4bcfc3` selector. Base `0x4bcfc3` still passes `-1` and never preserves a current art row; final-sweep classified class-0 cells now preserve the current scratch visual row when the current row's recovered class word is zero, but keep the caller's classified flag bytes instead of copying stale current scratch flags, then fall back to the existing base selector only when that preservation condition fails. Final-object pass splitting still uses descriptor/provider type `descriptor_type_0x1c`, while copied source records remain definition identity. `h3maped_rmg_core_selftest` remains green. Focused no-Godot Medium seed-10 setup-0 still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile bytes remain 36288 vs 36288 with first mismatch offset 1 (`native=55`, `h3maped=54`); generated-object payload is 8524 native bytes vs 17057 H3MapEd bytes with first mismatch offset 0 (`native=30`, `h3maped=2`); native generated objects are 666 vs H3MapEd 1212, and native flagged first-pass objects remain 18. This is source-backed TerrainPlacement implementation progress, not final-payload parity or runtime map-output authorization.
- Superseded native RMG note: an earlier TerrainPlacement status incorrectly treated base `0x4bcfc3` visual-row selection as directly propagating selected-row flags. Current recovered caller evidence supersedes that: `0x4bcfc3` selects the row, while flag outputs are produced only when the call chain actually invokes `0x4bad0f`. Keep the separate recovered `+0x24` 6-bit terrain-id unpacking work, but do not reuse the stale direct-flag-copy interpretation for TerrainPlacement parity claims.
- Previous native RMG implementation update: `h3maped_rmg_core` now aligns relation-owner boundary handoffs with the recovered source/payload owner word used by `0x4aa9b7`/`0x4aa603` generated-cell owner gating. The old native split wrote compact relation-owner vector indexes into generated-cell `+0x20` byte2 while reward/guard gates compared against the relation-leading source owner; the handoff now writes the recovered source payload owner when available and only falls back to the vector index when the source owner is absent. `h3maped_rmg_core_selftest` now forces `owner_vector_index = 0` with source owner `9` and asserts both boundary payload and generated-cell owner byte carry the recovered source pointer owner word. Focused no-Godot Medium seed-10 setup-0 still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile bytes remain 36288 vs 36288 with first mismatch offset 1 (`native=55`, `h3maped=54`); generated-object payload remains short at 9088 native bytes vs 17057 H3MapEd bytes with first mismatch offset 0 (`native=21`, `h3maped=2`); native generated-object count is 713 and definition count is 170. This is source-backed owner-state implementation progress, not final-payload parity or runtime map-output authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now implements the recovered `0x4ad947` projection wrapper-vector relation handoff instead of stopping at the old pending blocker. `0x540b14` projection objects carry recovered base wrapper pointer `+0x04` and base coordinates `+0x08/+0x0c/+0x10`; `0x4aa3e9` sets those absolute coordinates before dispatch. After the selected `0x57c7cc+0x0c` global entry is written into the owned record `+0x1c`, native scans the generator `+0x88/+0x8c` resolver wrapper vector in order for a wrapper whose copied source record `+0x20` matches that global index, switches wrapper `+0x08` reference counts, derives the source relation owner from generated-cell word `+0x20`, and calls the existing recovered `0x4ad7f7` relation-priority orderer. `h3maped_rmg_core_selftest` now covers the missing-global-table fail-closed path and a global-table/wrapper-vector path selecting global index `9`, switching wrapper `1 -> 3`, deriving relation owner `4`, and building an ordered target relation through `0x4ad7f7`. The no-Godot Medium seed-10 setup-0 run still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length remains 36288 bytes with first mismatch offset 1 (`native=55`, `h3maped=54`), and generated-object payload remains short at 8960 native bytes vs 17057 H3MapEd bytes. This is source-backed `0x4ad947`/`0x4ad7f7` behavior progress, not final-payload parity or runtime map-output authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries the recovered final-object wrapper state instead of keeping definition activity as a local writeout reconstruction. `SourceObjectResolvedWrapper4af785` has explicit recovered `+0x08` reference-count and `+0x0c` definition-index fields; `0x4a54a7` object commits increment the selected/unique resolver wrapper refcount; and `0x4ad1e3` emits generated-object definitions from active wrapper `+0x08 > 0` in preserved `0xe8` bucket order while assigning wrapper `+0x0c` indexes. `h3maped_rmg_core_selftest` now verifies both the commit-time `+0x08` increment and final writeout `+0x0c` assignment. The no-Godot Medium seed-10 setup-0 run still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes with first mismatch offset 1, `native=55` vs `h3maped=54`; generated-object payload remains short at `9088` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0, `native=21` vs `h3maped=2`. This is source-backed final-object private-state progress, not final-payload parity or runtime map-output authorization. Remaining blockers are upstream generated-cell/TerrainPlacement state before `0x49b2b6` and missing H3MapEd object producer/materialization parity before `0x4ad3eb`, not final-map tuning.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries recovered setup object `+0x4c` from `0x49ecf2` into generator field `+0x08` and through `0x4a218c -> 0x49b53d -> 0x49b4e1`; `0x49b4e1` no longer receives a hardcoded non-negative flag when filtering monster-town candidate `8`. `h3maped_rmg_core_selftest` covers setup `+0x4c -> +0x08` propagation and the negative-field candidate-filter path. The no-Godot Medium seed-10 setup-0 run with explicit `setup_object_0x4c=0` still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=55` vs `h3maped=54`, and generated-object payload remains short at `9088` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=21` vs `h3maped=2`. This is source-backed field propagation progress, not final-payload parity or runtime map-output authorization.
- Previous native RMG implementation update: `h3maped_rmg_core` now follows the recovered `0x4bb681` TerrainPlacement branch before entering live feedback: it reads current effective terrain through `0x4bb71b`, calls `0x4bb74b` feedback only when the terrain changes, and routes same-terrain cells through the direct `0x4bcfc3 + 0x4bad0f` visual/scratch rewrite path. Owner/member-gated `0x4a3f27` repaint now calls this same topology path instead of pre-setting terrain and unconditionally posting feedback. `h3maped_rmg_core_selftest` includes a focused same-terrain water-scope regression and remains green. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=57` vs `h3maped=54`, and generated-object payload remains short at `8212` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. The final tile stream hash remains `3123f1bf830e6cc6fbda007cd23e2f86d4f5e05a03cc519d416fc7a5a9d6fb12`, so this closes source-order branch drift but does not close TerrainPlacement/final-payload parity or authorize runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now applies the recovered `0x4ba91d` TerrainPlacement neighbor probe semantics used by `0x4bce6d`: complex same-terrain neighbors only reduce the visual selector mask when the selected neighbor art row has flag A set; simple/rock toolkits still reject same-terrain continuity through the recovered `0x4baa81` path. This removes the stale native check that treated every nonzero `shape_class` row as connectable. `h3maped_rmg_core_selftest` remains green. The no-Godot Medium seed-10 setup-0 run still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=57` vs `h3maped=54`, and generated-object payload remains short at `8212` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. The native tile stream hash changed under this source-backed fix, but broad tile drift remains, so this is implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` no longer injects the old recovered 426-row source-list proxy into `0x4ad1e3` generated-object definition writeout. The native definition table now follows the recovered source spine: two static definitions from generator `+0x4a8/+0x7f8`, then only active descriptor wrappers whose recovered `+0x08` reference count is positive, emitted through the preserved `0xe8` wrapper-bucket order and indexed from `2` onward. Object payload serialization now resolves definition indexes through selected wrapper identity first, with unique source-record fallback only when the selected wrapper was not carried. `h3maped_rmg_core_selftest` remains green. The no-Godot Medium seed-10 setup-0 run writes 169 definitions (2 static + 167 active wrappers), 9792 definition bytes, and serializes all 640 generated objects / 8212 object-payload bytes, then still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=57` vs `h3maped=54`, and generated-object payload remains short at `8212` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. This is source-backed final-writeout implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now ports the recovered `0x4bb74b` toolkit-byte5-zero live-feedback branch for TerrainPlacement. After the current coordinate is removed from set-B, byte5-zero terrains walk the runtime-initialized `0x5a5028..0x5a5068` direction order (`N, NE, E, SE, S, SW, W, NW`), filter neighbors through active scratch terrain, remove and seed existing set-A members that fail `0x4bc988`, and insert absent same-terrain neighbors only when `0x4bc988` accepts them. The existing byte5-nonzero cardinal set-A cleanup remains separate. `h3maped_rmg_core_selftest` remains green. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=57` vs `h3maped=54`, and generated-object payload remains short at `8212` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. This is source-backed TerrainPlacement implementation progress, not parity completion or runtime map output.
- Superseded native RMG note: an earlier TerrainPlacement note incorrectly said the recovered `0x4bce6d` neighbor probe should test `shape_class` instead of `flag_a`. The recovered `0x4ba91d` complex-toolkit probe reads row flag A; native now follows that behavior. Keep the owner-index handoff portion of that earlier slice, but do not reuse the stale `shape_class` interpretation for TerrainPlacement parity claims.
- Previous native RMG implementation update: `h3maped_rmg_core` now carries the recovered owner-grid repaint/member marker through generated-cell word `+0x28`: `0x4a261a/0x4a325d` reserved writes set bit 28 through the recovered `0x4a2e91` `OR byte ptr [cell+0x2b], 0x10` mutation, `0x4a3f27` consumes carried `+0x28` instead of resetting it, and the `0x4a30c2 -> 0x4a2ec3` relation marker path is gated to the recovered generator-mode-2 level-0 branch. Native `cell_flags` remain a support mirror, not repaint authority. `h3maped_rmg_core_selftest` covers reserved-write bit carry, mode-2 marker behavior, and mode-0 carried-bit repaint. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 with `native=57` vs `h3maped=54`, and generated-object payload remains short at `8212` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. This is source-backed generated-cell implementation progress, not parity completion or runtime map output.
- Superseded native RMG note: the earlier TerrainPlacement interpretation that resolved generated-cell `+0x20` byte2 through a relation-owner source byte is superseded for `0x4a2105/0x49b66d` and `0x4a3f27`. Recovered `0x4a3f27` disassembly and the same-run compact owner-byte evidence show TerrainPlacement owner-grid consumers use the relation-owner loop index directly for this supported path. Do not reuse the superseded source-byte helper for TerrainPlacement parity claims.
- Previous native RMG implementation update: `h3maped_rmg_core` now applies the recovered `0x4a3f27` one-level terrain prefill branch: supported one-level land maps skip the terrain-9 full-map visual prefill and begin with the terrain-8 water prefill; two-level terrain-9 behavior remains future-scoped. `h3maped_rmg_core_selftest` reflects the one-level full-map sweep expectation. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch remains offset 1 but is now `native=57` vs `h3maped=54`, and generated-object payload remains short at `7984` native bytes vs `17057` H3MapEd bytes, first mismatch offset 0 `native=35` vs `h3maped=2`. This is source-backed TerrainPlacement implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now ports the recovered `0x4bc5f0` set-A/set-B live-feedback drain to ordered-tree first-node semantics, replacing the previous shadow FIFO vector overlay. Set-A drains fully first, set-B then drains fully, and the loop returns to set-A only after set-B is empty if B processing repopulated A. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch is offset 1 (`native=50`, `h3maped=54`), lane mismatches remain dominated by terrain/art (`terrain=4166`, `art=5049`, `flags=1150`, `road_type=386`, `road_art=371`, `river_type=34`, `river_art=28`), and generated-object payload remains short (`8596` native bytes vs `17057` H3MapEd bytes). This is source-backed TerrainPlacement implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now applies the recovered `0x4a2777 -> 0x4a29c4` randomized source-edge writer branch to every real source-cycle connector, not only the initially selected connector. Later connectors now use `0x4a2413` and the recovered `0x4a29a5` per-edge span-limit selection when the source-order randomized flag is active; `h3maped_rmg_core_selftest` covers multi-connector behavior. The no-Godot Medium seed-10 setup-0 comparison still fails closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, first mismatch is offset 1 (`native=52`, `h3maped=54`), and generated-object payload remains short (`7996` native bytes vs `17057` H3MapEd bytes). This is source-backed `0x4a2777` implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now aligns more of the recovered TerrainPlacement feedback chain. Set-A/set-B feedback drains in recovered ordered-tree first-node order, retouch/candidate probes read active scratch terrain words, `0x4bba59` diagonal seeding uses the recovered byte5-zero neighbor rule, `0x4bc988` and `0x4bbd01` same-class/region branches are limited to toolkit byte5-zero terrain, `0x4bc928` was recovered/checked, `0x4bbd01` zero-run retouch uses the recovered runtime-initialized `0x5a5028..0x5a5068` neighbor direction order, and `0x4bbfcc` still uses the recovered `0x4bcb91`/`0x4bcd43` correction predicates plus `0x4ba938` class-0 current-row preservation. The no-Godot Medium seed-10 setup-0 snapshot remains fail-closed at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, but the first mismatch is offset 1 (`cell=0`, `byte_in_cell=1`, `native=69`, `h3maped=54`) with mismatch_count 11202. This is source-backed TerrainPlacement implementation progress, not parity completion or runtime map output.
- Previous native RMG implementation update: `h3maped_rmg_core` now follows the recovered supported-land `0x4a61bc` border-guard endpoint evidence instead of blocking before fallback. For the recovered Medium seed-10 profile that matches the H3MapEd final header (`Ready or Not`, setup object `+0x44 = 0`), native now treats the sampled `0x4a5e73/0x4a606b` endpoint path as source-excluded only when the recovered D-014 supported-land exclusion and scoped `0x4a7605 -> 0x4a5e03` fallback records are present, then continues through connection/road/final writeout to the final-payload comparison stop. The standalone no-Godot CLI writes `<case>.final_payload.bin` and `<case>.final_payload_sections.json` from the shared `0x4ad1e3` workflow for exact byte comparison. The Medium setup-0 run now emits final payload bytes for the header-compatible `Ready or Not` path: 5184 cells / 36288 tile bytes / 806 generated objects / 10124 generated-object payload bytes / 60465 assembled payload bytes. The exact same-run Medium seed-10 compare against recovered H3MapEd authorities now blocks first at `native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload`: tile stream length matches at 36288 bytes, and the first mismatch is offset 0 (`native=7`, `h3maped=2`). Generated-object payload also mismatches and is short by 6933 bytes (native 10124 vs H3MapEd 17057), with first mismatch offset 0 (`native=39`, `h3maped=2`). The setup-3 path still reaches final payload assembly, but it selects `3SB0b`, so it is not the same-run Medium header authority for the recovered `Ready or Not` comparison. This is source-order workflow progress and source-backed blocker identification, not parity completion or runtime map output; exact generated-cell/private-state mutation parity before `0x49b2b6`, exact runtime descriptor wrapper-bucket `+0x08/+0x0c` replay for full H3MapEd table parity, reward/guard zero-commit parity debt, and descriptor counter replay remain blockers.
- Previous native RMG implementation update: `h3maped_rmg_core` no longer hides the post-private-state source-order phase execution behind `advance_generator_object_private_state_source_order_to_current_blocker()`. The single `run_h3maped_rmg_entry_to_writeout_workflow()` owner now directly drives relation-vector production, relation-pointer source-order replay, route/free-cell sweep, materialization bridge, mine/resource materialization, reward/guard source stream, decorative dispatch, and connection-tail handoff in visible executable order.
- Previous native RMG implementation update: `h3maped_rmg_core` now matches the recovered `0x49cf34` source-order candidate filtering by erasing `wrapper+0x3c..+0x40` candidates in reverse in place instead of rebuilding a forward filtered vector. `h3maped_rmg_core_selftest` covers the reverse `0x49d2e0` execution order and surviving original candidate order. Reward/guard direct-stream candidate scans still produce zero successful `0x4aa9b7` commits on the focused controlled cases, so successful source-owned reward/guard commits remain a parity mismatch to fix without using final-map tuning.
- Previous native RMG implementation update: `h3maped_rmg_core` carries recovered relation-owner reward/guard treasure bands `+0xa0/+0xa4/+0xa8` through `+0xc0`, terrain policy `+0x0c`, stale supported-land cursor `+0xf5c = 0x7a1befdf`, zeroed `+0xf60/+0xf64` terrain-pressure state, recovered `0x57cea0` monster terrain rows, and `0x531cc4` type-17 subtype-to-monster rows. The selected-candidate `0x4ac552 -> 0x4a218c` relation-vector producer is now owned by the shared workflow instead of being prebuilt during setup, and no-Godot snapshots expose its candidate-vector, selected-template, relation-vector, and relation-owner counts. Active workflow progress is blocked later at reward/guard materialization zero successful `0x4aa9b7` commits.
- Previous native RMG implementation update: `h3maped_rmg_core` exposes `run_h3maped_rmg_entry_to_writeout_workflow()` as the ordered entry-to-current-blocker workflow owner. `rmg_native_core.cpp` delegates native workflow phase/status/final-writeout state to that shared result and adapts its diagnostic owner-grid payload from the already-executed shared workflow instead of replaying setup/template/coordinate/object state locally. This removes the duplicate native workflow owner, but it is not parity or final map output.
- Previous native RMG implementation update: shared C++ replays descriptor-joined generic non-type98 `+0xedc` source pairs into the recovered source-order object paths. When a preserved source pair carries `0x4903e8` descriptor context, relation/key/anchor context, relation scan bounds, and copied `0x4c` source count/density fields, native reconstructs the source descriptor join and calls the existing recovered `0x4a8d2c` direct dispatcher and `0x4a8db2` scheduler. Pairs without that context fail closed and are counted as missing descriptor/relation/source-field blockers. This is not full generic object parity: live descriptor producers/raw source-field capture for all real non-type98 pairs, live reward/guard feed, fallback caller order, roads/rivers, and final payload generation remain unported.
- Previous native RMG implementation update: shared C++ now ports recovered reward/guard filters for source-backed helper inputs: `0x49cf34` calls the recovered `0x49d2e0` attach candidate filter, and `0x4aa9b7` now calls a recovered `0x4aa603` feasibility filter instead of a prevalidated coordinate allow-list. `0x4aa603` now checks selected-member body offsets through the `0x49a6f9` footprint gate, attached-wrapper bit22/type-`0x36` rejection, direction-policy cells, `0x49a09c` contour validation, and wrapper/generated-cell overlap bit26 rejection. This is not live reward/guard parity: live `0x4adb72/0x4ad7f7` caller feed still must construct the wrapper/source-relation/object-record inputs with descriptor body offsets, terrain policy, object-reference descriptor resolution, and real object keys; generic non-type98 materialization feed, fallback caller order, roads/rivers, and final payload generation remain unported.
- Native parity reality: native still diverges before object/route/package consumers. Checkpoint 2 remains the active implementation blocker until the native pre-`0x4a4c8e` generated-cell words match H3MapEd private state in Python-owned comparisons. Shared core owns the record-level `0x4a5767`/`0x49a318` projection helpers, `0x4a1f3b` non-sentinel relation scan bounds from generated-cell owner-byte rectangles, recovered `0x4a5767` scan-consumer projection-chain replay over those bounds including the source-backed `0x4a5a23` bit0 object-materialization branch through `0x4a9e40`, `0x4af785`, `0x49ba89`, and `0x4a54a7`, source-backed `0x49a318` high-owner propagation from relation-owner coordinate seeds including source projection clear, same-owner projection/`+0x1c` low-word writes, and cross-owner `+0x1c` high-word/`+0x28` direction/`+0x20` owner-byte writes, reset-time known-empty object-reference vectors from `0x499e65/0x499ea3`, recovered `0x499ee8` object-reference removal/empty-cell reset helper behavior, recovered explicit-input `0x4a606b` connection-region writing, no-object `0x4a5a23` projection-chain behavior, recovered explicit-call `0x4a54a7` object-footprint commit afterstate including descriptor-offset source-cell projection semantics and relation-local `+0x44[descriptor+0x1c]` counter increments, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, `0x4af785` resolver wiring into that prep, copied `0x4c` source-record identity through explicit object commit prep, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` weighted scheduler density-lane threshold state and source-backed direct-prepass/weighted-lane replay, live type-98 runtime-zone `0x4a8db2` scheduler replay from source-zone town/castle count and density fields, source-backed weighted `0x4a901a` local candidate-vector scan/selection with value-floor clearing, source-backed weighted `0x4a93a2 -> 0x4a901a -> 0x4a54a7` type-98 record-tail commit behavior for recovered `0x540a9c` records, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` coordinate scan/wrapper commit behavior with recovered `0x4aa603` feasibility filtering, recovered reward/guard wrapper construction/reset/attach/final-marker helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb` plus source-backed empty-vector `0x49d7c3` contour rebuild for source-backed inputs, and recovered D-014 projection/exclusion/prep state for endpoint/connection materialization including supported one-level-land `+0xd8/+0xdc` compact key count, derived `+0x1104/+0x1108` byte-state sizing, stale `+0xf5c` rejection, disabled live endpoint success path, and exact-prestate `0x4a7605 -> 0x4a5e03` fallback replay through `0x4a54a7` for the two recovered seed-controlled records. The recovered `0x49a318` bit22 object-metadata policy branch is now ported; remaining `0x49a318` work is exact call-site order and same-run private-state comparison, plus live descriptor producers/raw source-field capture for every generic non-type98 pair feeding the now-partial `0x4a8d2c/0x4a8db2` replay bridge, generic object materialization producer/selection order beyond source-owned weighted records and the scan-consumer branch, live reward/guard wrapper/source-relation caller feed into the ported `0x49ce04/0x49cf34/0x49d2e0/0x49d7c3/0x4aa9b7/0x4aa603 -> 0x4aa3e9` path, generic live `0x4a7605 -> 0x4a5e03` fallback payload feed/caller order, roads/rivers, and final writeout are still unported.
- Current source-order object materialization status: weighted `0x4a901a`, direct exact-input `0x4a8d2c -> 0x4a93a2 -> 0x4a54a7`, source-backed `0x4a8db2` direct-prepass/weighted-lane scheduler replay, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` scan/commit with recovered `0x4aa603` feasibility filtering, explicit reward/guard wrapper attach/finalizer helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb`, recovered `0x49d2e0` candidate filtering, and the recovered empty-vector `0x49d7c3` wrapper contour rebuild exist in shared C++ for source-backed inputs. The selected-candidate relation-vector handoff is now executed in source order before relation-pointer replay; it is no longer a setup-time proxy from flat runtime seeds. This is still not full live object parity: native still needs live descriptor producers/raw source-field capture for all generic non-type98 source pairs, live reward/guard wrapper/source-relation caller feed that produces successful `0x4aa9b7` commits, fallback materialization caller feed, downstream caller order, and final payload writer.
- Source-first rule for this slice: inspect native RMG implementation in phase order, patch only source-backed divergences, then run no-Godot native verification. Do not use final-map deltas, density scalars, brute-force retries, GDScript reports, or Godot exports as substitutes for implementing the source behavior.
- Native RMG alignment checkpoints, in execution order:
  1. Final writeout authority: complete. Native final-writeout comparison now uses the H3MapEd `0x4ad1e3 -> 0x49b2b6 -> 0x4ad309/0x4ad3eb` tile/object stream as authority; current mismatches are attributed to pending earlier native checkpoints, not package-draft parity.
  2. Private generated-cell grid: make pre-`0x4a4c8e` native generated-cell words match H3MapEd private state before route/object consumers run.
  3. Reward/object identity: carry source records/descriptors through selection and materialization instead of resolving final identity through placeholder object ids. The recovered `0x49da08` object source-record catalog, metadata `+0x08` `0xe8` `0x49db76` wrapper-bucket lane layer, sampled `0x4af785` wrapper reuse/copy/create support model, sampled `0x4af89f`/`0x4a9e40` selector mechanics, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, copied `0x4c` source-record identity, explicit prepared `0x4a54a7` object commit path including relation-local `+0x44` counter mutation, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` density-lane threshold argument and direct-prepass/weighted-lane scheduler replay, live type-98 runtime-zone scheduler-source feed, recovered `0x4a901a` weighted candidate scan/selection over generated-cell low-word value floors and `0x49aa93` eligibility, source-backed weighted type-98 `0x4a93a2` record-tail commit through `0x4a901a -> 0x4a54a7`, explicit-input reward/guard `0x4aa9b7 -> 0x4aa3e9` scan/selection/wrapper commit with recovered `0x4aa603` feasibility filtering, explicit reward/guard wrapper construction/reset/attach/final-marker helpers `0x49ce04/0x49ce64/0x49cf34/0x49cefb`, recovered `0x49d2e0` filtering, and source-backed empty-vector `0x49d7c3` wrapper contour rebuild are now exposed in shared C++ and mirrored through the native wrapper where live callers exist. Full live weighted/materialization parity still waits on live descriptor producers/raw source-field capture for all generic non-type98 source pairs, live reward/guard wrapper/source-relation/object-record-key caller feed, and downstream relation/reward/guard/object caller order.
     Direct `0x4a8d2c -> 0x4a93a2` exact-input placement is also exposed for source-backed inputs: branch priority is `+0x24`, `+0x20`, `+0x34`, then `+0x30`; selected candidates use nearest-distance local-vector behavior with initial `0x7d00`, `0x49aa93` eligibility, `0x4e7276 % count` selection, `0x540a9c` allocation, and `0x4a54a7` commit. Generic non-type98 descriptor-joined `+0xedc` replay is partially ported; live producer/feed coverage for every real pair and downstream caller order remain blockers.
  4. Metadata claim correction: complete. Exact/adopted phase claims that still have lower-level blockers are downgraded and must only be restored after comparison evidence passes.
  5. Route/free-cell replay: source-order prefix owned for the focused Small/Medium one-level land path through `0x4a8260 -> 0x4a4c8e`; it still needs same-run private-state comparison before it can be called parity.
  6. Connection vector/caller source: blocked before roads. Native owns the first `0x4a79a3` endpoint-prefix dispatch but not the recovered second dispatch through `0x4a696b -> 0x4a7605`, which consumes generator vectors `+0x2e8/+0x2ec/+0x2f8`, `+0x308/+0x30c`, and coordinate vectors `+0x14c0/+0x14d0`. Captured connection-coordinate/RNG/object records are no longer accepted as a substitute.
  7. Connection blockers/guards: model and populate the missing generator vectors from their recovered producers, port `0x4a696b/0x4a7605` in caller order (plus `0x4a6cf2/0x4a68e0` when reached), and only then resume source-owned downstream reward/guard, decorative, road/river, and final-writeout work.
  8. Decorative scoring/vector replay: recovered `0x49e1bf`, `0x49b89c`, and `0x49e700` coordinate-worklist replay are owned for the focused path; remaining work is same-run/final-payload parity validation and any descriptor-mask correction it proves necessary.
- Current checkpoint-2 finding: no runtime/native/GDScript generation surface is allowed to emit comparable pre-`0x4a4c8e` generated-cell words until the shared H3MapEd-aligned state chain owns every mutating phase listed in `docs/native-rmg-generated-cell-mutation-chain.md`. The no-Godot CLI emits the blocked marker `rmg_native_batch_export_cli_shared_h3maped_state_chain_blocked_v1` for `--phase-snapshot-only`; it feeds runtime-zone seeds and links from the recovered 53-template H3MapEd catalog through `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()` only after the recovered `0x49ecf2` setup step has been resolved. If `setup_object_0x44` is supplied, `generator_setup_mode_49ecf2()` copies ordinary modes directly, randomizes sentinel value `3` with one `0x4e7276` RNG call and `% 3`, hands the post-setup RNG state to template selection, then executes the shared coordinate-to-owner-grid support path when the remaining inputs are present. If setup is not supplied, the same-run catalog/runtime-zone feed is blocked with `rmg_setup_object_0x44_before_0x49ecf2_template_selection`; the resolver no longer assumes template selection starts from the raw seed. The Python wrapper no longer accepts `--shared-runtime-input-snapshot`; stale phase snapshots cannot be mined for runtime-zone/link inputs. Missing inputs remain explicit blockers and are not synthesized. The duplicate plain-C++ phase/native-map reconstruction body has been deleted from `src/gdextension/src/rmg_native_core.cpp`; that file now owns controlled-case parsing/filtering, blocked shared-chain marker output, same-run recovered setup/catalog feed resolution, and the call into `h3maped_rmg_core`. The standalone native-core public header does not declare reconstructed phase/native-map writers, the CLI does not call a native-map JSON writer, and `--native-map-json-only` writes only a blocked manifest with `native_map_json_public_api_removed=true` and `legacy_native_generation_surface_removed=true`. H3MapEd Small/Medium validator-gated package/session adoption is also removed from the live runtime authority path: `MapPackageService::generate_random_map` returns a direct exact-state-chain blocked result for supported H3MapEd scopes; runtime H3MapEd scope/status classification calls `h3maped_rmg_core` directly; unsupported runtime output returns a local blocked result; both native and GDScript `convert_generated_payload` paths fail closed; `build_h3maped_small_package_session_adoption` and `build_native_package_session_adoption` return blocked results; the old proxy/reconstruction sources have been renamed to `src/gdextension/src/archived_h3maped_small_rmg_legacy_proxy_20260618.cpp` and `src/gdextension/src/archived_h3maped_small_rmg_embedded_data_legacy_proxy_20260618.cpp`; their headers have moved out of public `include/` into archived source-only headers; and `inspect_h3maped_small_rmg_port` / negative-validator are not declared, bound, advertised, or stubbed by native or the GDScript shim. The GDScript compatibility shim no longer advertises foundation-generation/adoption capabilities and returns blocked instead of generating a fallback map. `NativeRandomMapPackageSessionBridge.gd` no longer reads `native_proxy_*` package fields, and `tests/validate_repo.py` now forbids those bridge tokens and the old active legacy filenames. The shared core now owns recovered RNG, recovered `0x49ecf2` generator-mode setup, Small/Medium one-level-land scope, water-mode code, strict scope labels, size-score calculation, the recovered generated-cell reset `0x49a072 -> 0x499ea3` for words `+0x10/+0x1c/+0x20/+0x24/+0x28/+0x2c`, the recovered `0x49acf6` terrain/art/private-flag helper bit mutation, the recovered low-level boundary helpers for `0x4a2b33` clipping, `0x4a261a` deterministic line writing, `0x4a2413` randomized line writing, owner-word application, and `0x4a325d` span fill, plus a typed `boundary_cycles_from_source_handoffs_4a2777` / `materialize_boundary_source_handoffs_4a2777_4a325d` handoff API that accepts recovered source-node finalized fields and selected `0x4a3a03` source-record `+0x10/+0x14/+0x18` seeds, then materializes selected connector, border wrap/final segments, rectangle fallback, generator `+0x3f4` boundary-vector append records, generated-cell owner-word mutations, and recovered `0x4a325d` seed relocation/span-fill into the shared grid shape. That handoff now preserves the `0x4cca55` source-cycle descriptor indexes, raw `+0x00/+0x04` coordinates, and finalized `+0x1c/+0x20` coordinates instead of flattening the cycle to finalized x/y only. The shared core also exposes typed source-record producer functions for `0x4ac62a..0x4ac6ec` player-slot assignment, `0x4a218c/0x4a1f3b` runtime-zone/link seed construction from template zone/link records, and recovered catalog selection/feed. The shared coordinate seed now carries recovered source-zone town/terrain bytes, interleaves `0x49b3c1` town choice before each initial zone placement, runs `0x49b53d` runtime terrain selection from same-run town choice/source terrain flags, and applies `0x4a3f27` terrain-id repaint and runs TerrainPlacement visual row/terrain flag selection through `0x4bb74b/0x4bad0f/0x4bcfc3/0x4bce6d` into generated-cell `+0x24/+0x28` support words. This is still not parity: later relation/object caller order remains blocked. Downstream terrain, object, relation, route, and package consumers stay blocked until the full generated-cell mutation chain is implemented from source and same-run validated.
- TerrainPlacement final-sweep detail: native now preserves current scratch visual records through the recovered `0x4bc5a3` path for corrected-class `0x4bbfcc` cases that have no direct visual row bucket.
- Current checkpoint-2 snapshot surface: the blocked no-Godot shared-chain snapshot emits only a partial generated-cell surface. It now carries the recovered generator-object private-state shape for generated-cell buffer `+0x14`, dimensions `+0x18/+0x1c/+0x20`, accepted candidate vector `+0x10d4/+0x10d8`, preserved `+0xedc` source-pair payload contents from `0x4af785` including `0x4903e8` descriptor-join context where that path created the pair, source-owner/player-slot counts and actual `+0xed8/+0xee0/+0xee4` arrays, active relation-vector count from selected `0x4ac552 -> 0x4a218c` owner adoption, recovered `0x49b452` relation-owner constructor/default fields plus concrete zeroed `+0x44` descriptor-counter tables and `0x4a1f3b` non-sentinel relation scan bounds from generated-cell owner-byte rectangles, recovered `0x4a5767` scan-consumer projection-chain counters over those bounds including `0x4a5a23` object-branch attempt/commit counters, recovered `0x4a1f3b/0x4a19ed` relation-owner selected coordinate triple `+0x10..+0x18`, source-zone endpoint vector `+0xc8/+0xcc` contents/count for `0x4a1f3b`, supported one-level-land endpoint cursor vector `+0xd8/+0xdc` compact key count `8`, `0x4a17f5/0x4a1ad8` coordinate candidate vectors per relation owner, recovered reciprocal `0x49f7c4` relation-owner records from selected runtime links, recovered `0x4a5767` full-grid projection reset, source-backed `0x49a318` projection/high-owner word mutations and counters, reset-time known-empty generated-cell object-reference vectors from `0x499e65/0x499ea3`, recovered `0x499ee8` object-reference removal/empty-cell reset helper behavior, setup-zeroed endpoint field `+0xf58` while leaving `+0xf5c` unclaimed, recovered `0x49f95a` endpoint byte-state vector `+0x1104/+0x1108` zero-init relationship to endpoint pointer vector `+0xd8/+0xdc` with concrete supported-land count, recovered stale `+0xf5c` rejection for compact keys `0..7`, the recovered static `0x4a5e73` endpoint helper contract for explicit inputs, recovered explicit-input `0x4a606b` 3x3 connection-region writing, recovered `0x4a5a23` projection-chain occupancy/cleanup and object-branch materialization behavior, recovered explicit-call `0x4a54a7` object-footprint commit afterstate including descriptor-offset source-cell projection semantics and relation-local descriptor-counter increments, recovered exact `0x4a7605 -> 0x4a5e03` fallback payload commit helper for the two sampled seed-controlled records, recovered `0x4903e8` descriptor/source join prep for contexts `45/53/54/79`, copied `0x4c` source-record identity through explicit object commit prep, recovered `0x4a93a2` weighted-record allocation / generator `+0xf44` sequence ownership, recovered `0x4a8db2` weighted scheduler density-lane threshold list and source-order replay state, exact-input weighted `0x4a901a` and direct `0x4a8d2c -> 0x4a93a2` object-placement candidate/selection/commit state, D-014 endpoint projection/exclusion/caller-prep state, descriptor counter table `+0x1110` zero initialization from `0x49ecf2` (`0x3a0` bytes / 232 dwords), recovered stride-`0x30` record shape, reset/owner/terrain word overlays, partial `+0x2b` bit-knowledge reporting, the recovered `0x49da08` object source-record catalog identity summary, the recovered metadata `+0x08` `0xe8` `0x49db76` wrapper-bucket summary, sampled `0x4af785` wrapper reuse/copy/create behavior, and sampled `0x4af89f`/`0x4a9e40` source selector behavior. Live relation/object caller order, exact `0x49a318` call-site order/same-run private-state comparison around the now-ported bit22 object-metadata policy branch, live source-order object materialization caller order/object-reference appends/removals beyond the scan-consumer/weighted/direct exact-input paths and descriptor-joined non-type98 replay bridge, complete live source-record `+0x30/+0x34/+0x3c` capture, live source-order fallback `0x4a7605 -> 0x4a5e03` payload feed/caller order, source-order descriptor counter increment/decrement replay beyond explicit prepared calls, and downstream source-order relation/object caller mutations are still not source-owned by the live chain. It reports owner-grid materialization counts, `generated_cell_private_state_comparable=false`, and the missing mutating phases from `docs/native-rmg-generated-cell-mutation-chain.md`. The active source-order chain still calls the recovered one-level land `0x4a3710` finalizer after `0x4a2777 -> 0x4a325d`, but this proves only ordering/owner-grid support; it does not prove checkpoint-2 parity or authorize runtime map output.
- Default proxy-surface fence: the active-source `MapPackageService` implementation has been replaced with a slim package service plus fail-closed RMG normalization/identity/blocked responses. The old reconstruction helper entrypoints (`generate_zone_layout`, `generate_player_starts`, `generate_road_network`, `generate_river_network`, `generate_object_placements`, `generate_town_guard_placements`, `generate_connection_payload_resolution`, and `generate_terrain_grid`) and the `AURELION_ENABLE_ARCHIVED_NATIVE_RMG_RECONSTRUCTION` compile-time escape hatch have been removed from active source. `generate_random_map` now has only fail-closed H3MapEd-exact-chain blocked results until the recovered shared chain owns payload generation. The GDScript compatibility shim no longer carries private `_generate_*` reconstruction helpers, no longer exposes the archived reconstruction blocker helper, and no longer advertises the disabled native RMG placement/provenance schema ids. The old Godot `RmgNativeBatchExportRunner` class/source/header and `tools/rmg_native_batch_export_native.tscn` launcher have been removed, are not linked into the GDExtension, and are guarded by `tests/validate_repo.py`; RMG export tooling is the standalone no-Godot CLI only, which currently fails closed instead of producing maps. This is a guardrail only, not parity progress: successful runtime map generation stays blocked until the exact recovered descriptor/source-cycle/seed producer owns the live payload.
- Shared coordinate/source-node/owner-grid chain port: `h3maped_rmg_core` now owns the recovered `0x49ecf2` generator-mode setup surface, `0x4ac62a..0x4ac6ec` player-slot assignment surface, `0x4a218c/0x4a1f3b` runtime-zone/link seed construction from typed template records, recovered 53-template catalog selection/feed through `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()`, the `0x4a218c -> 0x4a1f3b -> 0x4a19ed` coordinate seeding surface, including the recovered `generator+0x10b8` mode-to-prune-divisor behavior, the recovered `0x4a3a03 -> 0x4ccb64 -> 0x4cca55` source-node footprint producer, the `0x4a2777 -> 0x4a325d` owner-grid/span-fill materializer, and the source-order `0x4a3710` one-level land no-appended-zone finalizer surface. The shared core exposes `generator_setup_mode_49ecf2()`, `runtime_seed_inputs_from_template_records_4a218c_4a1f3b()`, `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()`, and `coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d_4a3710()`, which let source-order C++ flow start from recovered setup/catalog records instead of a prior phase snapshot. Missing setup/generator-mode input remains observable when no same-run setup object `+0x44` value is supplied, source payload fields are preserved, the recovered `0x4a2777` descriptor owner gate (`next_pair_payload <= zone_word`) is applied before source-edge writes, source edges use the recovered two-endpoint shape (`from_clip` / `to_clip`), and the finalizer explicitly blocks non-land/multilevel or appended-zone adjacency paths instead of guessing them. `bin/h3maped_rmg_core_selftest` proves setup sentinel `3` RNG handoff, Small reference catalog selection, Medium catalog feed availability, player assignment, template-record seed/link construction, coordinate seeding with mode `0` divisor `5` and mode `2` divisor `7`, source handoff consumption, coordinate-output RNG handoff, recovered `0x4a3710` finalizer order, and generated-cell owner word production without Godot or map export. This still does not complete checkpoint 2: private-state comparison and live payload ownership must be implemented before any map output can consume owner words.
- Supersession note: earlier `native-rmg-medium-h3maped-land-*` runtime-adoption/public-UI completion evidence is historical support evidence only. It is not current runtime authority for Small/Medium H3MapEd generation after the exact-state-chain fail-closed correction.
- Current guardrails: do not add density scalars, speculative gates, brute-force retries, or final-map delta tuning, and do not use GDScript for reports or exports. `tools/rmg_native_batch_export.py` uses the standalone no-Godot `bin/rmg_native_batch_export_cli`; the wrapper refuses to run while a Godot process is active, refuses native map JSON, and permits paired `.amap`/`.ascenario` output only after no-replay final payload parity. `--phase-snapshot-only` remains diagnostic. Public `MapPackageService::generate_random_map` is enabled only for the 24 supported shape combinations and known monster-strength inputs; everything outside that scope remains fail-closed. Keep Linux and Windows native outputs and validation in sync.
- Historical ordinal-95 correction and evidence: strategic AI resource routing, arrival, saved-task execution, guarded-claim resume, opportunistic capture, and target refresh now use each node's authoritative `visit_tile`, while strategic valuation retains established anchor-distance semantics. Resource visit tiles are pathable to AI factions just as they are to the player, without making the rest of a permanent object body walkable. Generated multi-town launches preserve and distribute spawn origins, failed no-spare regroups request durable commander rebuild pressure, rebuild relaunches reject understrength and one-turn patrol hosts, and player battle-pressure suppression is limited to hosts in the same reachable component. Medium ordinal 95 completes 56/56 turns with row signature `a64b33be` and report signature `2ca1e0a4`: 102 activity events, 84 assignments, 11 regroups, three sites seized, 15 stalled turns, zero battles, zero behavior bugs, zero integrity violations, and zero unreachable targets; runtime is 428562ms with a 10765ms maximum turn. The battle-free result is not tactical parity evidence: the Brightwood Sawmill permanent body closes the only terrain corridor between the Sunvault host and the player region even after its visit tile is correctly exposed. That is generated-map topology/object-placement debt and must not be hidden by making the complete body passable. These runtime behavior changes postdate ordinals 91-94, so those rows are now historical; ordinal 95 was the sole exact-code target row at that checkpoint.
- Historical ordinal-97 correction and evidence: saved strategic resource-task snapshots now use the same authoritative `visit_tile` as live task execution and general resource targeting, closing a remaining blocked-anchor route path. Planned-recruitment scoring preloads the already-reconciled live task array and reuses each actor's saved plan during one scoring pass instead of reconciling and rescanning the same board for every task. Focused assault/resource, planned-recruitment, and commander-spawn suites pass. The exact ordinal-97 rerun preserves row signature `73d51b81`, all 127 activity events, 18 assignments, three successful autoresolutions, one site seizure, zero stalled turns, zero behavior bugs, zero integrity violations, and zero unreachable targets; correct player defeat occurs on turn 29. Runtime falls from 301479ms to 298946ms and the maximum turn from 23781ms to 23423ms; on that turn planned-task scoring falls from 1286ms to 1058ms and total reinforcement work from 6685ms to 6379ms. The remaining spike is still dominated by reinforcement and spawn candidate evaluation and remains a performance gap. Ordinals 95 and 96 became historical after this correction; ordinal 97 was the sole exact-code target row at that checkpoint.
- Historical ordinal-98 correction and evidence: a raid that completes the best reachable frontier toward an inaccessible player town now records that town, frontier anchor, and minimum town gap. While it remains in that reachable component, later pressure selection rejects equal-or-worse frontier waypoints for the same town but still permits a genuinely closer waypoint or direct town route. This removes same-host frontier recycling without timeouts, global topology invalidation, hidden target knowledge, or weakened reachable-town pressure. Focused assault coverage proves a blocked route advances through three waypoints, stops recycling at the terminal frontier, and immediately resumes a town assault when the route opens. Exact ordinal 98 completes 56/56 turns with row signature `02b1e939` and report signature `5c4ae598`: 94 activity events, 80 assignments, three regroups, seven site contests, four sites seized, 14 stalled turns (25%), zero behavior bugs, zero integrity violations, and zero unreachable targets. The former same-host `Riverwatch Hold approach 60,46` reassignments on days 17, 25, 41, 49, and 55 are absent, and no player-town frontier remains active in the final six-host state. Runtime is 492600ms with a 12461ms maximum turn. The row still has zero tactical battles because no direct player or defended-neutral route becomes available; this remains an explicit strategic topology/contact gap, not parity evidence. Ordinal 98 was the sole exact-code target row at that checkpoint.
- Historical ordinal-100 through ordinal-9 matrix evidence: after the ordinal-100 commander-rebuild correction, Medium ordinals 1-9 were rerun against the same code. Ordinals 1, 3-7 reached correct player defeat after 44, 27, 46, 50, 54, and 32 turns with 3, 3, 4, 3, 3, and 3 valid battle handoffs; ordinal 100 completed all 56 turns with one valid town-defense battle. Ordinals 2, 8, and 9 completed all 56 turns without tactical contact and retained explicit topology/contact caveats. All ten rows had zero behavior bugs, integrity violations, and unreachable active targets. This is historical implementation evidence after the ordinal-12 behavior correction, not current matrix credit.
- Historical ordinals 10-11 and launch-scan correction: ordinal 10 reaches correct player defeat after 37 completed turns with four valid battle handoffs, 226 activity events, zero stalls, zero behavior bugs, zero integrity violations, and zero unreachable targets. Ordinal 11 completes all 56 turns with row signature `54de971b`, 224 activity events, two valid town-defense battles, five stalled turns, zero behavior bugs, zero integrity violations, and zero unreachable targets. Its late ready-task launch exposed repeated commander-roster normalization, live-task reconciliation, and path-surface construction for every open spawn point. Spawn selection reuses one read-only scan context while preserving the exact row signature and event counts; the hot launch loop falls from 9519ms to 5956ms, best-point evaluation from 6378ms to 2706ms, maximum turn runtime from 28290ms to 24545ms, and full-row runtime from 606723ms to 592954ms. These rows remain useful historical evidence but no longer count as exact-current-code coverage after the ordinal-12 exploration behavior correction.
- Current ordinal-12 correction and evidence: active exploration hosts retain a bounded history of their 12 most recently completed `explore:x:y` targets, and both frontier and general exploration selection exclude those targets while alternatives exist. Exact-current-code ordinal 12 completes 56/56 turns with row signature `48a96b2d` and report signature `2a2cb45c`: 61 activity events, 55 assignments, two regroups, three site contests, one site seizure, 23 stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Blackbranch Reavers advances through ten distinct late-game scout targets instead of alternating `53,43` and `56,46`. Runtime is 481759ms with a 9704ms maximum turn. The row remains battle-free and correctly in progress with one player town, so tactical contact remains an explicit caveat. This behavior change supersedes ordinals 1-11 and 100 as exact-current-code credit; ordinal 12 is the sole current-code row, 99 remain, and ordinal 13 is next. The full matrix and overall game remain in progress.
- Current ordinal-13 evidence: exact-current-code ordinal 13 reaches correct player defeat after 54 completed turns with row signature `ebd536fc` and report signature `47b3024d`. It records 190 activity events, 38 assignments, two sites seized, three valid autoresolutions (town loss, player hero victory, and final hero defeat), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 413246ms with a 14005ms maximum turn. Together with ordinal 12, two exact-current-code rows pass, 98 remain, and ordinal 14 is next. This is required validation coverage, not an implementation or full-game completion claim.
- Current ordinal-14 evidence: exact-current-code ordinal 14 reaches correct player defeat after 47 completed turns with row signature `f0a64dce` and report signature `a46a04b2`. It records 118 activity events, 37 assignments, three sites seized, four valid autoresolutions (town loss, two player hero victories, and final hero defeat), seven stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 399808ms with a 16305ms maximum turn. Together with ordinals 12-13, three exact-current-code rows pass, 97 remain, and ordinal 15 is next.
- Current ordinal-15 evidence: exact-current-code ordinal 15 completes 56/56 turns with row signature `0e21c638` and report signature `add8f2bd`. It records 273 activity events, 55 assignments, four sites seized, two valid autoresolutions (town loss and player hero victory), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no town but one live hero; six reachable raids remain, including direct hero pressure at distance 31. Runtime is 509099ms with a 13803ms maximum turn. Together with ordinals 12-14, four exact-current-code rows pass, 96 remain, and ordinal 16 is next.
- Current ordinal-16 evidence: exact-current-code ordinal 16 reaches correct player defeat after 30 completed turns with row signature `27e60a24` and report signature `5844b19a`. It records 179 activity events, 103 raid-movement events, nine assignments, four valid autoresolutions (town loss, two player hero victories, and final hero defeat), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 292026ms with a 17022ms maximum turn. Together with ordinals 12-15, five exact-current-code rows pass, 95 remain, and ordinal 17 is next.
- Current ordinal-17 evidence: exact-current-code ordinal 17 completes 56/56 turns with row signature `61b1360c` and report signature `26a03268`. It records 68 activity events, 56 assignments, two sites seized, 28 stalled turns (50%), zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Six reachable raids remain and the Riverwatch frontier sequence advances across distinct coordinates rather than recycling a short target loop. The row has no tactical battle and retains an explicit generated-topology/contact caveat; it is not battle-readiness evidence. Runtime is 355679ms with a 7387ms maximum turn. Together with ordinals 12-16, six exact-current-code rows pass, 94 remain, and ordinal 18 is next.
- Current ordinal-18 evidence: exact-current-code ordinal 18 completes 56/56 turns with row signature `cb19d917` and report signature `80b2f925`. It records 219 activity events, 80 movement events, 19 assignments, two valid autoresolutions (town loss and player hero victory), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no town but one live hero; six reachable raids remain with direct hero pressure at distance 13. Runtime is 591552ms with a 16155ms maximum turn; the hot turn is distributed across spawn selection, town build, reinforcement, and raid advancement rather than a new isolated path. Together with ordinals 12-17, seven exact-current-code rows pass, 93 remain, and ordinal 19 is next.
- Current ordinal-19 evidence: exact-current-code ordinal 19 reaches terminal primary-commander defeat after 18 completed turns with row signature `8da7f818` and report signature `94a12d95`. It records 50 activity events, 28 assignments, three sites seized, one valid hero-intercept autoresolution, one stalled turn, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player still owns one town, but the primary-commander loss is terminal under the explicit `BattleRules` primary/secondary hero contract. Runtime is 162778ms with a 10237ms maximum turn. Together with ordinals 12-18, eight exact-current-code rows pass, 92 remain, and ordinal 20 is next.
- Current ordinal-20 evidence: exact-current-code ordinal 20 reaches correct player defeat after 40 completed turns with row signature `331c75a5` and report signature `6ea9f2ae`. It records 222 activity events, 63 movement events, 38 assignments, one site seized, two valid autoresolutions (town loss and final primary-hero defeat), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 367619ms with a 13292ms maximum turn. Together with ordinals 12-19, nine exact-current-code rows pass, 91 remain, and ordinal 21 is next.
- Current ordinal-21 evidence: exact-current-code ordinal 21 reaches correct player defeat after 54 completed turns with row signature `9d6d8ddb` and report signature `922c0c96`. It records 170 activity events, 65 movement events, 21 assignments, three valid autoresolutions (town loss, player hero victory, and final hero defeat), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 556589ms with a 13737ms maximum turn. Together with ordinals 12-20, ten exact-current-code rows pass, 90 remain, and ordinal 22 is next.
- Current ordinal-22 evidence: exact-current-code ordinal 22 completes 56/56 turns with row signature `15b45eca` and report signature `3f5e49cd`. It records 194 activity events, 50 movement events, 58 assignments, two sites seized, two valid autoresolutions (town loss and player hero victory), zero stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no towns but a live hero; five reachable raids remain. Runtime is 475837ms with a 16942ms maximum turn. Together with ordinals 12-21, eleven exact-current-code rows pass, 89 remain, and ordinal 23 is next.
- Current ordinal-23 evidence: exact-current-code ordinal 23 completes 56/56 turns with row signature `a5c6c305` and report signature `76579e66`. It records 221 activity events, 90 movement events, 33 assignments, one site seized, and three valid autoresolutions (two player hero victories and one town loss), with zero invalid player orders, stalled turns, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain. Runtime is 493339ms with a 13302ms maximum turn. Together with ordinals 12-22, twelve exact-current-code rows pass, 88 remain, and ordinal 24 is next.
- Current ordinal-24 evidence: exact-current-code ordinal 24 reaches correct player defeat after 50 completed turns with row signature `34a877e8` and report signature `298d4e63`. It records 131 activity events, 40 movement events, 11 assignments, two commander rebuilds, and two valid autoresolutions (town loss and final hero defeat), with three stalled turns, zero invalid player orders, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. Runtime is 454676ms with a 17436ms maximum turn. Together with ordinals 12-23, thirteen exact-current-code rows pass, 87 remain, and ordinal 25 is next.
- Current ordinal-25 evidence: exact-current-code ordinal 25 reaches correct player defeat after 24 completed turns with row signature `60ec279c` and report signature `23a78e0f`. It records 105 activity events, 24 movement events, 29 assignments, seven regroups, one site seizure, one commander rebuild, one adventure-spell cast, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 224698ms with a 15177ms maximum turn. Together with ordinals 12-24, fourteen exact-current-code rows pass, 86 remain, and ordinal 26 is next.
- Current ordinal-26 evidence: exact-current-code ordinal 26 reaches correct player defeat after 28 completed turns with row signature `c66eb49b` and report signature `94ab75e8`. It records 165 activity events, 61 movement events, 26 assignments, two site contests, one commander rebuild, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 231847ms with a 12572ms maximum turn. Together with ordinals 12-25, fifteen exact-current-code rows pass, 85 remain, and ordinal 27 is next.
- Current ordinal-27 evidence: exact-current-code ordinal 27 reaches correct player defeat after 48 completed turns with row signature `33fd08e6` and report signature `4968eae1`. It records 273 activity events, 124 movement events, 28 assignments, six regroups, one site contest, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 442755ms with a 12730ms maximum turn. Together with ordinals 12-26, sixteen exact-current-code rows pass, 84 remain, and ordinal 28 is next.
- Current ordinal-28 evidence: exact-current-code ordinal 28 completes 56/56 turns with row signature `9f290e63` and report signature `6a3ec414`. It records 155 activity events, 63 movement events, 41 assignments, nine regroups, two sites seized, and two valid autoresolutions (player hero victory and town loss), with four stalled turns, zero invalid player orders, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain, including direct hero pressure at distance 27. The final zero-distance resource assignment follows the row's second site seizure and is a same-site persistent-defense continuation, not an unresolved claim. Runtime is 462263ms with a 16595ms maximum turn. Together with ordinals 12-27, seventeen exact-current-code rows pass, 83 remain, and ordinal 29 is next.
- Current ordinal-29 evidence: exact-current-code ordinal 29 reaches correct player defeat after 19 completed turns with row signature `8580f512` and report signature `9fa5ee2c`. It records 51 activity events, 17 movement events, 15 assignments, three regroups, two site contests, one site seizure, two adventure-spell casts, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 198660ms with a 19478ms maximum turn. Together with ordinals 12-28, eighteen exact-current-code rows pass, 82 remain, and ordinal 30 is next.
- Current ordinal-30 evidence: exact-current-code ordinal 30 reaches correct player defeat after 34 completed turns with row signature `3abfcea8` and report signature `14b1fa46`. It records 123 activity events, 32 movement events, 37 assignments, four regroups, two site contests, one site seizure, one adventure-spell cast, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 286371ms with a 12221ms maximum turn. Together with ordinals 12-29, nineteen exact-current-code rows pass, 81 remain, and ordinal 31 is next.
- Current ordinal-31 evidence: exact-current-code ordinal 31 completes 56/56 turns with row signature `9ace3167` and report signature `e9c0ba90`. It records 83 activity events, 68 assignments, four regroups, seven site contests, two sites seized, and 24 public-event-stalled turns, with zero behavior bugs, target-integrity violations, or unreachable active targets. Current-state snapshots prove hidden host movement during quiet turns, including one route-frontier host advancing from `(59,15)` through `(59,18)` on days 14-17. Six reachable raids remain and scout/frontier targets continue across distinct coordinates, but the player retains one town and no tactical battle occurs; this is an explicit generated-topology/contact caveat, not battle-readiness evidence. Runtime is 410738ms with an 8841ms maximum turn. Together with ordinals 12-30, twenty exact-current-code rows pass, 80 remain, and ordinal 32 is next.
- Current ordinal-32 evidence: exact-current-code ordinal 32 completes 56/56 turns with row signature `e98689df` and report signature `ff9385a2`. It records 179 activity events, 52 movement events, 34 assignments, nine regroups, one site contest, one adventure-spell cast, and one valid town-loss autoresolution, with one stalled turn, zero invalid player orders, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain and direct hero pressure advances from distance 26 to 14 over the final five turns. Runtime is 510058ms with a 16504ms maximum turn. Together with ordinals 12-31, twenty-one exact-current-code rows pass, 79 remain, and ordinal 33 is next.
- Current ordinal-33 evidence: exact-current-code ordinal 33 completes 56/56 turns with row signature `ba21736a` and report signature `e2c6e418`. It records 184 activity events, 23 movement events, 33 assignments, five regroups, three site contests, one site seizure, one adventure-spell cast, and one valid town-loss autoresolution, with 12 stalled turns, zero invalid player orders, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The player correctly remains in progress with no towns but a live hero; three reachable raids remain. No direct hero pressure remains at the horizon, retaining an explicit contact caveat rather than hero-defeat evidence. Runtime is 493326ms with a 15116ms maximum turn. Together with ordinals 12-32, twenty-two exact-current-code rows pass, 78 remain, and ordinal 34 is next.
- Current ordinal-34 evidence: exact-current-code ordinal 34 reaches correct player defeat after 29 completed turns with row signature `f75d5052` and report signature `184f59b4`. It records 102 activity events, 36 movement events, 13 assignments, three groupings, one regroup, one site contest, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 265335ms with a 11644ms maximum turn. Together with ordinals 12-33, twenty-three exact-current-code rows pass, 77 remain, and ordinal 35 is next.
- Current ordinal-35 evidence: exact-current-code ordinal 35 completes 56/56 turns with row signature `745b90e3` and report signature `1be29709`. It records 340 activity events, 197 movement events, 21 assignments, two groupings, two regroups, two site contests, and one valid town-assault autoresolution, with zero stalled turns, behavior bugs, target-integrity violations, or unreachable active targets. The player retains one town and the scenario remains in progress after eight weeks; the valid battle proves contact without implying terminal pressure. Runtime is 516028ms with a 14071ms maximum turn. Together with ordinals 12-34, twenty-four exact-current-code rows pass, 76 remain, and ordinal 36 is next.
- Current ordinal-36 evidence: exact-current-code ordinal 36 reaches correct player defeat after 19 completed turns with row signature `e1895b13` and report signature `9a84e7ba`. It records 82 activity events, 33 assignments, three groupings, five regroups, two reinforcements, four site contests, two site seizures, two adventure-spell casts, and two valid autoresolutions (town loss and final hero defeat), with three stalled turns and zero behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 188164ms with a 15422ms maximum turn. Together with ordinals 12-35, twenty-five exact-current-code rows pass, 75 remain, and ordinal 37 is next.
- Current ordinal-37 evidence: exact-current-code ordinal 37 completes 56/56 turns with row signature `e2a726ab` and report signature `31b5d5ce`. It records 158 activity events, 78 movement events, 50 assignments, three regroups, five site contests, two site seizures, and one valid town-loss autoresolution, with 15 stalled turns and zero behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain and direct hero pressure is active at distance 23. Runtime is 418893ms with a 16330ms maximum turn. Together with ordinals 12-36, twenty-six exact-current-code rows pass, 74 remain, and ordinal 38 is next.
- Current ordinal-38 evidence: exact-current-code ordinal 38 reaches correct player defeat after 39 completed turns with row signature `09e52e71` and report signature `eb7f1886`. It records 146 activity events, 32 movement events, 35 assignments, one grouping, seven regroups, three reinforcements, two site contests, two site seizures, four adventure-spell casts, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 341780ms with a 12636ms maximum turn. Together with ordinals 12-37, twenty-seven exact-current-code rows pass, 73 remain, and ordinal 39 is next.
- Current ordinal-39 evidence: exact-current-code ordinal 39 reaches correct player defeat after 43 completed turns with row signature `34fca4e3` and report signature `54f9c823`. It records 165 activity events, 76 movement events, 21 assignments, three groupings, three regroups, five reinforcements, one site contest, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 360786ms with a 15365ms maximum turn. Together with ordinals 12-38, twenty-eight exact-current-code rows pass, 72 remain, and ordinal 40 is next.
- Current ordinal-40 evidence: exact-current-code ordinal 40 reaches correct player defeat after 25 completed turns with row signature `5373d6ae` and report signature `9de31fa2`. It records 82 activity events, 23 movement events, 16 assignments, one grouping, three regroups, one site contest, one adventure-spell cast, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 227336ms with a 14081ms maximum turn. Together with ordinals 12-39, twenty-nine exact-current-code rows pass, 71 remain, and ordinal 41 is next.
- Current ordinal-41 evidence: exact-current-code ordinal 41 completes 56/56 turns with row signature `0391f541` and report signature `4d082af8`. It records 170 activity events, 24 movement events, 30 assignments, three groupings, two regroups, three site contests, and one valid town-loss autoresolution, with 14 stalled turns (25%) and zero behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain, but no direct hero pressure remains at the horizon, retaining an explicit contact caveat. Runtime is 541427ms with a 16198ms maximum turn. Together with ordinals 12-40, thirty exact-current-code rows pass, 70 remain, and ordinal 42 is next.
- Current ordinal-42 evidence: exact-current-code ordinal 42 reaches correct player defeat after 31 completed turns with row signature `4b1b3596` and report signature `067ecd00`. It records 141 activity events, 41 movement events, 22 assignments, two groupings, three regroups, three commander preparations, one site contest, one adventure-spell cast, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 282512ms with a 13263ms maximum turn. Together with ordinals 12-41, thirty-one exact-current-code rows pass, 69 remain, and ordinal 43 is next.
- Current ordinal-43 evidence: exact-current-code ordinal 43 reaches correct player defeat after 47 completed turns with row signature `085a32e2` and report signature `d8fe6ddb`. It records 193 activity events, 56 movement events, 32 assignments, one grouping, four regroups, two commander preparations, two commander rebuilds, one site contest, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 417589ms with a 16360ms maximum turn. Together with ordinals 12-42, thirty-two exact-current-code rows pass, 68 remain, and ordinal 44 is next.
- Current ordinal-44 evidence: exact-current-code ordinal 44 completes 56/56 turns with row signature `1fa2483a` and report signature `8bef57c0`. It records 239 activity events, 14 movement events, 44 assignments, seven groupings, eight regroups, one reinforcement, four commander rebuilds, four site contests, and one valid town-loss autoresolution, with zero stalled turns, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain, but no direct hero pressure remains at the horizon, retaining an explicit contact caveat. Runtime is 565674ms with a 17912ms maximum turn. Together with ordinals 12-43, thirty-three exact-current-code rows pass, 67 remain, and ordinal 45 is next.
- Current ordinal-45 evidence: exact-current-code ordinal 45 completes 56/56 turns with row signature `0a748621` and report signature `aca495be`. It records 77 activity events, 59 assignments, three groupings, eight regroups, four site contests, and three site seizures, with 21 stalled turns (38%) and zero behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain, but the player retains one town and no tactical battle occurs; this is an explicit generated-topology/contact caveat, not battle-readiness evidence. Runtime is 439856ms with a 12347ms maximum turn. Together with ordinals 12-44, thirty-four exact-current-code rows pass, 66 remain, and ordinal 46 is next.
- Current ordinal-46 evidence: exact-current-code ordinal 46 reaches correct player defeat after 35 completed turns with row signature `5636f126` and report signature `cb095335`. It records 205 activity events, 129 movement events, 23 assignments, one grouping, four regroups, two site contests, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 309644ms with a 17744ms maximum turn. Together with ordinals 12-45, thirty-five exact-current-code rows pass, 65 remain, and ordinal 47 is next.
- Current ordinal-47 correction and evidence: completed rebuild-frontier targets now persist as a bounded faction-level history across short-lived rebuild requests and alternating commanders, and rebuild relaunch planning excludes those exhausted targets while alternatives exist. The focused regroup and known-world suites prove the failed-regroup state write and a relaunch advancing from `explore:0:0` to `explore:0:4`. Exact-current-code ordinal 47 completes 56/56 turns with row signature `28967678` and report signature `b20f183e`: 59 activity events, 39 assignments, 14 regroups, five site contests, one site seizure, 25 stalled turns (45%), and zero behavior bugs, target-integrity violations, or unreachable active targets. The defective alternating-command loop is absent: `Frontier sweep 60,60` appears once instead of repeating, and later sweeps use distinct frontier coordinates. The player retains one town, three reachable raids remain, and no tactical battle occurs, so topology/contact remains an explicit caveat rather than battle-readiness evidence. Runtime is 470815ms with a 9484ms maximum turn. Together with ordinals 12-46, thirty-six exact-current-code rows pass, 64 remain, and ordinal 48 is next.
- Current ordinal-48 evidence: exact-current-code ordinal 48 reaches correct player defeat after 38 completed turns with row signature `f2724e57` and report signature `82fb57d0`. It records 101 activity events, 27 movement events, 28 assignments, five regroups, 13 garrison reinforcements, nine town builds, 15 town recruitments, one commander preparation, one site contest, and two valid autoresolutions (town loss and final hero defeat), with four stalled turns, zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 328144ms with a 12684ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-47, thirty-seven exact-current-code rows pass, 63 remain, and ordinal 49 is next.
- Current ordinal-49 evidence: exact-current-code ordinal 49 reaches correct player defeat after 52 completed turns with row signature `0df8cd18` and report signature `7ca98c45`. It records 193 activity events, 62 movement events, 32 assignments, two groupings, seven regroups, 34 garrison reinforcements, 18 town builds, 36 town recruitments, one site contest, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 503882ms with a 11773ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-48, thirty-eight exact-current-code rows pass, 62 remain, and ordinal 50 is next.
- Current ordinal-50 evidence: exact-current-code ordinal 50 reaches correct player defeat after 37 completed turns with row signature `bcd29ff6` and report signature `2e86972a`. It records 232 activity events, 99 movement events, 40 assignments, two groupings, three regroups, eight raid reinforcements, 23 garrison reinforcements, 14 town builds, 26 town recruitments, six adventure-spell casts, two site contests, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 306856ms with a 11399ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-49, thirty-nine exact-current-code rows pass, 61 remain, and ordinal 51 is next.
- Current ordinal-51 evidence: exact-current-code ordinal 51 completes 56/56 turns with row signature `5c86915a` and report signature `227da2c0`. It records 44 activity events, 33 assignments, one grouping, four regroups, four site contests, two site seizures, and 38 public-event-stalled turns (68%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Per-turn live snapshots prove the quiet periods are hidden travel rather than dead pressure: minimum reachable goal distance repeatedly counts down from 11 to 1 and from 10 to 1 before site resolution or reassignment. Four reachable raids remain, but the player retains one town and no tactical battle occurs; this is an explicit topology/contact caveat, not battle-readiness evidence. Runtime is 458355ms with a 9082ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-50, forty exact-current-code rows pass, 60 remain, and ordinal 52 is next.
- Current ordinal-52 evidence: exact-current-code ordinal 52 reaches correct player defeat after 44 completed turns with row signature `6ba8f822` and report signature `cfede84b`. It records 183 activity events, 64 movement events, 34 assignments, three groupings, three regroups, one raid reinforcement, 22 garrison reinforcements, 18 town builds, 27 town recruitments, three commander preparations, two adventure-spell casts, two site contests, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 367087ms with a 11726ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-51, forty-one exact-current-code rows pass, 59 remain, and ordinal 53 is next.
- Current ordinal-53 evidence: exact-current-code ordinal 53 completes 56/56 turns with row signature `0a33c9fe` and report signature `169d1ef9`. It records 67 activity events, 52 assignments, two groupings, six regroups, four site contests, three site seizures, and 28 public-event-stalled turns (50%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Quiet-turn snapshots count reachable goal distance down before site resolution, while guard breaks, a quarry seizure, and distinct frontier/town-approach coordinates prove the repeated generic guard labels are progressing objectives rather than one recycled target. Six reachable raids remain, but the player retains one town and no tactical battle occurs; this current-code trajectory supersedes the historical ordinal-53 battle claim and retains an explicit topology/contact caveat. Runtime is 441729ms with a 9393ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-52, forty-two exact-current-code rows pass, 58 remain, and ordinal 54 is next.
- Current ordinal-54 evidence: exact-current-code ordinal 54 completes 56/56 turns with row signature `14a84f38` and report signature `e1da338f`. It records 213 activity events, 32 movement events, 58 assignments, one grouping, five regroups, seven raid reinforcements, 31 garrison reinforcements, seven commander preparations, one commander rebuild, 17 town builds, 44 town recruitments, three site contests, three site seizures, and one valid town-loss autoresolution, with three stalled turns, zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain and direct hero pressure is active at distance 5. Runtime is 530241ms with a 15094ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-53, forty-three exact-current-code rows pass, 57 remain, and ordinal 55 is next.
- Current ordinal-55 evidence: exact-current-code ordinal 55 completes 56/56 turns with row signature `df51ff88` and report signature `a02ec192`. It records 145 activity events, 124 movement events, 15 assignments, five regroups, and one valid town-loss autoresolution on the final requested turn, with one stalled turn, zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; two reachable raids remain, but no direct hero pressure remains at the horizon, retaining an explicit contact caveat. Runtime is 411828ms with a 9909ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-54, forty-four exact-current-code rows pass, 56 remain, and ordinal 56 is next.
- Current ordinal-56 evidence: exact-current-code ordinal 56 completes 56/56 turns with row signature `b0830433` and report signature `7d11e35a`. It records 308 activity events, 120 movement events, 24 assignments, two groupings, four regroups, one raid reinforcement, 42 garrison reinforcements, three commander rebuilds, 18 town builds, 49 town recruitments, two site contests, one site seizure, and four valid autoresolutions (town loss followed by three player hero victories), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but a live hero; six reachable raids remain and direct hero pressure is active at distance 32. Runtime is 521570ms with a 14381ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-55, forty-five exact-current-code rows pass, 55 remain, and ordinal 57 is next.
- Current ordinal-57 evidence: exact-current-code ordinal 57 reaches correct player defeat after 25 completed turns with row signature `eb90d0b2` and report signature `cc3c1ff4`. It records 103 activity events, 48 movement events, 29 assignments, one grouping, six regroups, four garrison reinforcements, four town builds, four town recruitments, one town defense, three adventure-spell casts, one site contest, and four valid autoresolutions (town loss, two player hero victories, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 248480ms with a 15003ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-56, forty-six exact-current-code rows pass, 54 remain, and ordinal 58 is next.
- Current ordinal-58 evidence: exact-current-code ordinal 58 reaches correct player defeat after 33 completed turns with row signature `0f9fd9f9` and report signature `39bd5532`. It records 111 activity events, 43 movement events, 14 assignments, two groupings, two regroups, four raid reinforcements, 15 garrison reinforcements, 12 town builds, 17 town recruitments, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 310741ms with a 13643ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-57, forty-seven exact-current-code rows pass, 53 remain, and ordinal 59 is next.
- Current ordinal-59 evidence: exact-current-code ordinal 59 reaches correct player defeat after 36 completed turns with row signature `7477981a` and report signature `b6f1200a`. It records 211 activity events, 67 movement events, 24 assignments, two groupings, four regroups, 28 garrison reinforcements, five commander rebuilds, 16 town builds, 35 town recruitments, one town defense, four site contests, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 346057ms with a 17351ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 12-58, forty-eight exact-current-code rows pass, 52 remain, and ordinal 60 is next.
- Historical ordinal-60 evidence: ordinal 60 reached correct player defeat after 35 completed turns with row signature `5f7833b7` and report signature `0393cf3a`. It recorded 149 activity events, 40 movement events, 30 assignments, two groupings, four regroups, 22 garrison reinforcements, two commander rebuilds, 14 town builds, 26 town recruitments, two adventure-spell casts, two site contests, two site seizures, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime was 344368ms with a 13498ms maximum turn. The later public-assignment reconciliation correction supersedes ordinals 12-60 as exact-current-code event evidence while preserving them as historical state-trajectory evidence.
- Current ordinal-61 correction and evidence: public `ai_target_assigned` events are reconciled after the complete enemy turn against final active-host targets and same-turn durable target outcomes. Movement alone no longer preserves an assignment that was superseded before the public event stream was compacted; same-target captures, defenses, grouping, and regroup completion still preserve the assignment, including the `regroup` assignment to `town` completion shape. Focused regroup coverage and the strategic baseline pass. Exact-current-code ordinal 61 completes 56/56 turns with row signature `eecc8295` and report signature `a8a48a40`: 63 activity events, 50 assignments, one grouping, five regroups, one site contest, six site seizures, 24 public-event-stalled turns, zero behavior bugs, zero target-integrity violations, and zero unreachable active targets. The stale `Frontier sweep 36,30` summary that previously appeared on six turns is absent. Five reachable raids remain and the player retains one town, so the battle-free result retains a topology/contact caveat. Runtime is 410682ms with an 8809ms maximum turn. Ordinal 61 is the sole exact-current-code row, 99 remain, and ordinal 62 is next.
- Current ordinal-62 evidence: exact-current-code ordinal 62 reaches correct player defeat after 43 completed turns with row signature `bcd8741e` and report signature `ce216541`. It records 169 activity events, 39 movement events, 16 assignments, one grouping, six regroups, 29 garrison reinforcements, two commander rebuilds, 16 town builds, 33 town recruitments, two commander-task plans, two site contests, and two valid autoresolutions (town loss and final hero defeat), with four stalled turns, zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Natural town contact occurs on day 18 and the final hero intercept resolves on day 44. Runtime is 352542ms with an 11944ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinal 61, two exact-current-code rows pass, 98 remain, and ordinal 63 is next.
- Current ordinal-63 evidence: exact-current-code ordinal 63 completes 56/56 turns with row signature `5b6b33ab` and report signature `4e0ca308`. It records 40 activity events, 36 assignments, one regroup, two site contests, one site seizure, and 28 public-event-stalled turns (50%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Four reachable raids remain and the player retains one town, but no tactical battle occurs, so the row retains an explicit topology/contact caveat. A temporary raw-event rerun proved that the repeated `Riverwatch Hold approach 49,46` assignments are not a same-host loop: day 21 belongs to `faction_mireclaw_raid_2`, while day 45 belongs to the later `faction_mireclaw_raid_4`; all temporary diagnostics were removed afterward. Runtime is 387503ms with a 7690ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-62, three exact-current-code rows pass, 97 remain, and ordinal 64 is next.
- Current ordinal-64 evidence: exact-current-code ordinal 64 completes 56/56 turns with row signature `59e3d4e9` and report signature `bda2580e`. It records 214 activity events, 75 movement events, 27 assignments, two groupings, four regroups, 33 garrison reinforcements, two commander preparations, 15 commander-task plans, 18 town builds, 37 town recruitments, one site contest, and two valid town-loss autoresolutions, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain. Runtime is 536569ms with an 18340ms maximum turn. The hot day-50 launch turn is distributed across Mireclaw spawn selection (3664ms), target assignment (3151ms), reinforcement (1227ms), and town building (1227ms), so it remains an explicit measured performance caveat rather than evidence for a narrow semantic correction. This is validation coverage, not a new implementation claim. Together with ordinals 61-63, four exact-current-code rows pass, 96 remain, and ordinal 65 is next.
- Current ordinal-65 implementation and evidence: target, exploration, and frontier scans now acquire one immutable path context instead of rebuilding world fingerprints for every route query; rebuild launch-readiness scans reuse prepared commander probes by encounter and commander; and spawn-point scans reuse exact adventure-spell valuations keyed by commander, route distance, target kind, and target label. Focused coverage requires path/spell reuse and proves 10 prepared understrength probes are reused while all invalid launches remain blocked. Exact-current-code ordinal 65 reaches correct player defeat after 43 completed turns with row signature `935eb2d9` and report signature `b6193e5d`: 180 activity events, 72 movements, 17 assignments, three regroups, five raid reinforcements, 23 garrison reinforcements, three commander rebuilds, 15 town builds, 29 town recruitments, three adventure-spell casts, one site contest, two site seizures, and six valid autoresolutions, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Against the pre-change exact replay, total runtime falls from 500327ms to 479907ms, maximum turn runtime from 28567ms to 25936ms, the day-43 Mireclaw spawn loop from 10735ms to 7536ms, and the day-44 loop from 6557ms to 4612ms while the row signature and event counts remain unchanged. Day-44 emergency recruitment still spends about 3707ms selecting a defender and remains an explicit performance gap. Together with ordinals 61-64, five exact-current-code rows pass, 95 remain, and ordinal 66 is next.
- Current ordinal-66 implementation and evidence: emergency-defense launch and recruitment scans now reuse one exact path surface across spawn points, commander probes, and post-recruit candidate invalidations. Commander armies, readiness, target strength, and fit still recompute after each state mutation; only blocked tiles and derived distance fields are retained. Focused coverage proves identical recruitment candidate payloads across two rescans while loading the path context once and reusing it three times. The exact ordinal-66 replay preserves row signature `f28ef638`, all 144 activity events and counts, both valid autoresolutions, correct day-34 defeat, and zero stalls, invalid orders, behavior bugs, target-integrity violations, or unreachable active targets; report signature is `e04f79ba`. Runtime falls from 241532ms to 240436ms and maximum turn runtime from 13950ms to 12949ms. The strategic baseline remains green with harness signature `bdea055a`. Together with ordinals 61-65, six exact-current-code rows pass, 94 remain, and ordinal 67 is next.
- Current ordinal-67 evidence: exact-current-code ordinal 67 completes 56/56 turns with row signature `2243823c` and report signature `44589798`. It records 208 activity events, 25 movements, 51 assignments, one grouping, 10 regroups, 35 garrison reinforcements, one commander-task plan, 17 town builds, 39 town recruitments, four site contests, and one valid town-loss autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain. Runtime is 522301ms with a 13410ms maximum turn. The hot turn is distributed across normal spawn selection, raid advancement, reinforcement, and town building, so it does not expose a new isolated behavior or performance defect. This is validation coverage, not a new implementation claim. Together with ordinals 61-66, seven exact-current-code rows pass, 93 remain, and ordinal 68 is next.
- Current ordinal-68 evidence: exact-current-code ordinal 68 completes 56/56 turns with row signature `da979a23` and report signature `0f5da68e`. It records 67 activity events, 53 assignments, six regroups, six site contests, two site seizures, and 26 public-event-stalled turns (46%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain and the player retains one town, but no tactical battle occurs, so the row retains an explicit topology/contact caveat. Per-turn snapshots prove hidden travel by repeatedly counting reachable goal distance down to 1; distinct Riverwatch approach coordinates, guard breaks, and two site seizures show objective progression rather than a same-host frontier loop. Runtime is 374773ms with a 7977ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-67, eight exact-current-code rows pass, 92 remain, and ordinal 69 is next.
- Current ordinal-69 evidence: exact-current-code ordinal 69 completes 56/56 turns with row signature `e7d7d54b` and report signature `04666edd`. It records 263 activity events, 168 movements, nine assignments, two regroups, 29 garrison reinforcements, one commander rebuild, four commander-task plans, 15 town builds, 34 town recruitments, one site contest, and one valid town-loss autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; four reachable raids remain, including direct hero pressure. Runtime is 464200ms with a 12069ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-68, nine exact-current-code rows pass, 91 remain, and ordinal 70 is next.
- Current ordinal-70 evidence: exact-current-code ordinal 70 reaches correct player defeat after 21 completed turns with row signature `7e0a3b27` and report signature `dc1afa6b`. It records 49 activity events, 15 movements, 28 assignments, two regroups, three site contests, one site seizure, and one valid hero-intercept autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The pre-turn tactical diagnostic records the final hero target at distance 2, then the next turn moves and resolves the valid intercept; the report retains a remaining-validation no-natural-arrival row because its snapshot convention did not observe distance 0 before battle. Runtime is 147364ms with a 7583ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-69, 10 exact-current-code rows pass, 90 remain, and ordinal 71 is next.
- Current ordinal-71 evidence: exact-current-code ordinal 71 completes 56/56 turns with row signature `2ac75a69` and report signature `88138590`. It records 87 activity events, 66 assignments, four groupings, three regroups, seven site contests, seven site seizures, and 16 public-event-stalled turns (29%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain and the player retains one town, but no tactical battle occurs, so the row retains an explicit topology/contact caveat. Repeated guard breaks and seven distinct site seizures prove objective progression across the quiet periods. Runtime is 387595ms with an 8193ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-70, 11 exact-current-code rows pass, 89 remain, and ordinal 72 is next.
- Current ordinal-72 evidence: exact-current-code ordinal 72 reaches correct player defeat after 34 completed turns with row signature `0d2ea294` and report signature `b11befb4`. It records 181 activity events, 72 movements, 23 assignments, one grouping, four regroups, 20 garrison reinforcements, two commander-task plans, 13 town builds, 22 town recruitments, one town defense, three site contests, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Natural town contact occurs on day 13 and the final hero intercept resolves on day 35. Runtime is 332939ms with a 13442ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-71, 12 exact-current-code rows pass, 88 remain, and ordinal 73 is next.
- Current ordinal-73 evidence: exact-current-code ordinal 73 completes 56/56 turns with row signature `23a4a465` and report signature `706c2dc0`. It records 63 activity events, 48 assignments, seven regroups, four site contests, four site seizures, and 25 public-event-stalled turns (45%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain and the player retains one town, but no tactical battle occurs, so the row retains an explicit topology/contact caveat. Four distinct site seizures and the final four-day goal-distance countdown from 4 to 1 prove objective progression during the quiet periods. Runtime is 385058ms with an 8061ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-72, 13 exact-current-code rows pass, 87 remain, and ordinal 74 is next.
- Current ordinal-74 evidence: exact-current-code ordinal 74 completes 56/56 turns with row signature `06bed0d3` and report signature `c5d144d7`. It records 164 activity events, 49 movements, 28 assignments, three groupings, two regroups, 28 garrison reinforcements, three commander-task plans, 15 town builds, 32 town recruitments, two site contests, and one valid town-loss autoresolution, with four stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but four live heroes; six reachable raids remain, including two direct hero targets. Runtime is 464606ms with a 13322ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-73, 14 exact-current-code rows pass, 86 remain, and ordinal 75 is next.
- Current ordinal-75 evidence: exact-current-code ordinal 75 reaches correct player defeat after 23 completed turns with row signature `99f7b1c5` and report signature `f3d808eb`. It records 104 activity events, 24 movements, 11 assignments, one grouping, two regroups, 16 garrison reinforcements, two commander rebuilds, five commander preparations, three commander-task plans, 14 town builds, 21 town recruitments, one town defense, two adventure-spell casts, one site contest, one site seizure, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 224753ms with an 18254ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-74, 15 exact-current-code rows pass, 85 remain, and ordinal 76 is next.
- Current ordinal-76 evidence: exact-current-code ordinal 76 completes 56/56 turns with row signature `ae75ae54` and report signature `3ea0843b`. It records 183 activity events, 11 movements, 59 assignments, four regroups, 34 garrison reinforcements, six commander-task plans, 17 town builds, 38 town recruitments, one town defense, four site contests, eight site seizures, and two valid town-loss autoresolutions, with seven stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain, including direct hero pressure at distance 8. Runtime is 502975ms with a 14466ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-75, 16 exact-current-code rows pass, 84 remain, and ordinal 77 is next.
- Current ordinal-77 evidence: exact-current-code ordinal 77 reaches correct player defeat after 24 completed turns with row signature `be2358ce` and report signature `3024e49c`. It records 86 activity events, 34 movements, seven assignments, two regroups, 14 garrison reinforcements, one commander-task plan, 11 town builds, 15 town recruitments, one adventure-spell cast, one site contest, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 216226ms with a 12026ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-76, 17 exact-current-code rows pass, 83 remain, and ordinal 78 is next.
- Current ordinal-78 evidence: exact-current-code ordinal 78 reaches correct player defeat after 25 completed turns with row signature `3905f358` and report signature `2e991dba`. It records 93 activity events, 29 movements, 16 assignments, three groupings, three regroups, 13 garrison reinforcements, two commander preparations, two commander-task plans, 10 town builds, 15 town recruitments, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 230245ms with a 10878ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-77, 18 exact-current-code rows pass, 82 remain, and ordinal 79 is next.
- Current ordinal-79 evidence: exact-current-code ordinal 79 reaches correct player defeat after 18 completed turns with row signature `82af38ac` and report signature `0cc1ff23`. It records 56 activity events, 22 movements, 17 assignments, one grouping, two regroups, four garrison reinforcements, one commander-task plan, four town builds, four town recruitments, one site contest, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 155299ms with a 10168ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-78, 19 exact-current-code rows pass, 81 remain, and ordinal 80 is next.
- Current ordinal-80 evidence: exact-current-code ordinal 80 completes 56/56 turns with row signature `810e4485` and report signature `b5826aa7`. It records 65 activity events, 51 assignments, two groupings, four regroups, seven site contests, one site seizure, and 25 public-event-stalled turns (45%), with zero behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain and the player retains one town, but no tactical battle occurs, so the row retains an explicit topology/contact caveat. Repeated private-state goal-distance countdowns (`7` to `1`, `4` to `1`, and a final `9` to `7`), multiple distinct guard breaks, one site seizure, and two completed tasks prove objective progression during the quiet periods. Runtime is 380637ms with a 7649ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-79, 20 exact-current-code rows pass, 80 remain, and ordinal 81 is next.
- Current ordinal-81 evidence: exact-current-code ordinal 81 reaches correct player defeat after 32 completed turns with row signature `e9a2fffc` and report signature `7b306d01`. It records 143 activity events, 23 movements, 38 assignments, five groupings, eight regroups, one raid reinforcement, 18 garrison reinforcements, two commander rebuilds, one commander preparation, one commander-task plan, 13 town builds, 22 town recruitments, four adventure-spell casts, five site contests, two site seizures, and four valid autoresolutions (town loss, two player hero victories, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 323770ms with an 18200ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-80, 21 exact-current-code rows pass, 79 remain, and ordinal 82 is next.
- Current ordinal-82 evidence: exact-current-code ordinal 82 completes 56/56 turns with row signature `e1231330` and report signature `27f24b42`. It records 185 activity events, 58 movements, 15 assignments, two groupings, two regroups, nine raid reinforcements, 32 garrison reinforcements, one commander rebuild, six commander preparations, three commander-task plans, 18 town builds, 39 town recruitments, and one valid town-loss autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain, including two direct hero targets and nearest hero pressure at distance 2. Runtime is 490267ms with a 12912ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-81, 22 exact-current-code rows pass, 78 remain, and ordinal 83 is next.
- Current ordinal-83 evidence: exact-current-code ordinal 83 completes 56/56 turns with row signature `e58ea8f5` and report signature `5cbed553`. It records 102 activity events, eight movements, 55 assignments, four groupings, four regroups, six garrison reinforcements, four town builds, six town recruitments, five site contests, six site seizures, and one valid town-loss autoresolution, with 12 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player correctly remains in progress with no towns but live heroes; six reachable raids remain, including direct hero pressure. Runtime is 419888ms with a 12612ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-82, 23 exact-current-code rows pass, 77 remain, and ordinal 84 is next.
- Current ordinal-84 evidence: exact-current-code ordinal 84 completes 56/56 turns with row signature `032145db` and report signature `95066a84`. It records 127 activity events, 56 movements, 54 assignments, one grouping, 10 regroups, four site contests, two site seizures, and two valid autoresolutions (player hero victory and town loss), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player retains one town and six reachable raids remain. Runtime is 468740ms with a 13487ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-83, 24 exact-current-code rows pass, 76 remain, and ordinal 85 is next.
- Current ordinal-85 evidence: exact-current-code ordinal 85 reaches correct player defeat after 51 completed turns with row signature `7966ede5` and report signature `4dd66e84`. It records 124 activity events, 44 movements, 52 assignments, four regroups, three garrison reinforcements, three commander-task plans, three town builds, four town recruitments, two adventure-spell casts, three site contests, six site seizures, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 361438ms with a 14139ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-84, 25 exact-current-code rows pass, 75 remain, and ordinal 86 is next.
- Current ordinal-86 evidence: exact-current-code ordinal 86 completes 56/56 turns with row signature `63c0f703` and report signature `5dd50c13`. It records 78 activity events, 60 assignments, four regroups, three commander-task plans, five site contests, five site seizures, and one valid town-loss autoresolution, with 21 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player retains one town and six reachable raids remain, with the nearest active target at distance 3; no movement events occur in the final diagnostics. Runtime is 479968ms with a 17803ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-85, 26 exact-current-code rows pass, 74 remain, and ordinal 87 is next.
- Current ordinal-87 evidence: exact-current-code ordinal 87 completes 56/56 turns with row signature `7a0ab3ec` and report signature `736f9020`. It records 69 activity events, 62 assignments, one grouping, one regroup, three site contests, and two site seizures, with 19 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player retains one town and six reachable raids remain, but all final targets are exploration cells and no movement events or battles occur; the nearest active target is distance 2. Runtime is 384786ms with an 8548ms maximum turn. This is validation coverage, not a new implementation claim, and battle frequency plus travel-heavy pacing remain explicit production gaps. Together with ordinals 61-86, 27 exact-current-code rows pass, 73 remain, and ordinal 88 is next.
- Current ordinal-88 evidence: exact-current-code ordinal 88 reaches correct player defeat after 50 completed turns with row signature `a2f7d610` and report signature `cb29c84a`. It records 240 activity events, 66 movements, 45 assignments, two groupings, 12 regroups, one raid reinforcement, 29 garrison reinforcements, six commander-task plans, 16 town builds, 32 town recruitments, one adventure-spell cast, three site contests, four site seizures, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 473954ms with a 15273ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-87, 28 exact-current-code rows pass, 72 remain, and ordinal 89 is next.
- Current ordinal-89 evidence: exact-current-code ordinal 89 reaches correct player defeat after 44 completed turns with row signature `fcb0db62` and report signature `a92acfd6`. It records 105 activity events, 51 movements, 31 assignments, one grouping, eight regroups, nine commander-task plans, two site seizures, and one valid final hero-defeat autoresolution, with one stalled turn and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 353981ms with a 9702ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-88, 29 exact-current-code rows pass, 71 remain, and ordinal 90 is next.
- Current ordinal-90 evidence: exact-current-code ordinal 90 completes 56/56 turns with row signature `114107bc` and report signature `486f67dd`. It records 235 activity events, 168 movements, 26 assignments, three groupings, three regroups, eight garrison reinforcements, five commander-task plans, six town builds, nine town recruitments, two site contests, and one valid town-loss autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player has no towns but correctly remains in progress with live heroes; six reachable raids remain. Runtime is 446012ms with a 12935ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-89, 30 exact-current-code rows pass, 70 remain, and ordinal 91 is next.
- Current ordinal-91 evidence: exact-current-code ordinal 91 completes 56/56 turns with row signature `97443f1d` and report signature `ebafdb4a`. It records 73 activity events, 58 assignments, two groupings, six regroups, four site contests, and three site seizures, with 20 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain, but their final targets are five exploration cells and one resource; no movement events or battles occur. Runtime is 413267ms with an 8500ms maximum turn. This is validation coverage, not a new implementation claim, and battle frequency plus topology/exploration pacing remain explicit production gaps. Together with ordinals 61-90, 31 exact-current-code rows pass, 69 remain, and ordinal 92 is next.
- Current ordinal-92 evidence: exact-current-code ordinal 92 reaches correct player defeat after 26 completed turns with row signature `ba590063` and report signature `0b7738bd`. It records 115 activity events, 47 movements, 17 assignments, three regroups, 11 garrison reinforcements, one commander-task plan, 11 town builds, 11 town recruitments, one adventure-spell cast, two site contests, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 197441ms with a 9443ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-91, 32 exact-current-code rows pass, 68 remain, and ordinal 93 is next.
- Current ordinal-93 evidence: exact-current-code ordinal 93 completes 56/56 turns with row signature `c43e6244` and report signature `845d80a1`. It records 194 activity events, 18 movements, 43 assignments, one grouping, two regroups, 36 garrison reinforcements, one commander-task plan, 17 town builds, 41 town recruitments, two site contests, one site seizure, and one valid town-loss autoresolution, with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. The player has no towns but correctly remains in progress with live heroes; six reachable raids remain. Runtime is 444413ms with a 12855ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-92, 33 exact-current-code rows pass, 67 remain, and ordinal 94 is next.
- Current ordinal-94 evidence: exact-current-code ordinal 94 reaches correct player defeat after 27 completed turns with row signature `c381a01d` and report signature `e812cf98`. It records 75 activity events, 20 movements, 25 assignments, one grouping, five regroups, four garrison reinforcements, one commander rebuild, one commander preparation, one commander-task plan, six town builds, six town recruitments, one adventure-spell cast, two site contests, two site seizures, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with two stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 231182ms with a 12899ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-93, 34 exact-current-code rows pass, 66 remain, and ordinal 95 is next.
- Current ordinal-95 evidence: exact-current-code ordinal 95 completes 56/56 turns with row signature `b18d8de6` and report signature `9a4ef92d`. It records 94 activity events, 74 assignments, two groupings, 12 regroups, three site contests, and three site seizures, with 12 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain on exploration targets, but no movement events or battles occur because the permanent Brightwood Sawmill body closes the only player-region corridor; generated topology/object placement remains an explicit production gap. Runtime is 373386ms with a 9128ms maximum turn. This is validation coverage, not a new implementation or tactical-parity claim. Together with ordinals 61-94, 35 exact-current-code rows pass, 65 remain, and ordinal 96 is next.
- Current ordinal-96 evidence: exact-current-code ordinal 96 reaches correct player defeat after 23 completed turns with row signature `258261c2` and report signature `4af5ce62`. It records 99 activity events, 30 movements, 14 assignments, three groupings, one regroup, 15 garrison reinforcements, one commander rebuild, four commander-task plans, 12 town builds, 17 town recruitments, two adventure-spell casts, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 228828ms with a 13036ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-95, 36 exact-current-code rows pass, 64 remain, and ordinal 97 is next.
- Current ordinal-97 evidence: exact-current-code ordinal 97 reaches correct player defeat after 29 completed turns with row signature `fb7e712d` and report signature `a50e54c7`. It records 128 activity events, 49 movements, 17 assignments, one grouping, three regroups, two raid reinforcements, 16 garrison reinforcements, two commander rebuilds, two commander-task plans, 13 town builds, 19 town recruitments, one adventure-spell cast, one site contest, one site seizure, and three valid autoresolutions (town loss, player hero victory, and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Runtime is 271388ms with a 14970ms maximum turn. This is validation coverage, not a new implementation claim. Together with ordinals 61-96, 37 exact-current-code rows pass, 63 remain, and ordinal 98 is next.
- Current ordinal-98 evidence: exact-current-code ordinal 98 completes 56/56 turns with row signature `5a9c729b` and report signature `06422e2c`. It records 73 activity events, 62 assignments, three regroups, five site contests, and three site seizures, with 18 stalled turns and zero invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. Six reachable raids remain on encounter, exploration, and regroup targets; no player-town frontier remains active, so the former same-host terminal-frontier recycling is absent. No movement events or battles occur because no direct player or defended-neutral route opens; topology/contact and pacing remain explicit production gaps. Runtime is 417675ms with an 8684ms maximum turn. This is validation coverage, not a new implementation or tactical-parity claim. Together with ordinals 61-97, 38 exact-current-code rows pass, 62 remain, and ordinal 99 is next.
- Current ordinal-99 evidence: exact-current-code ordinal 99 reaches correct player defeat after 35 completed turns with row signature `437fc4a9` and focused report signature `318a3f57`. It records 93 activity events, 33 movements, 25 assignments, one grouping, five regroups, seven garrison reinforcements, one commander preparation, five commander-task plans, six town builds, eight town recruitments, two adventure-spell casts, and two valid autoresolutions (town loss and final hero defeat), with zero stalled turns, invalid player orders, behavior bugs, target-integrity violations, or unreachable active targets. After phase-scoped recruitment path reuse, local runtime is 265400ms with a 11665ms maximum turn, down from 296491ms and 13149ms on the same deterministic trajectory. This validates the implementation slice; it is not full-matrix or production-ready evidence. Together with ordinals 61-98, 39 exact-current-code rows pass, 61 remain, and ordinal 100 is next.
- Latest completed slice: `native-rmg-medium-h3maped-land-public-ui-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-runtime-adoption-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-phase-port-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-template-authority-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-reference-corpus-10184`.
- Latest completed slice: `strategic-ai-rmg-medium-generalization-probe-10184`.
- Latest completed slice: `native-rmg-medium-runtime-generation-unblock-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-unblock-routing-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-blocker-classification-10184`.
- Latest completed slice: `strategic-ai-baseline-staged-evidence-adoption-10184`.
- Latest completed slice: `strategic-ai-residual-diagnostic-hardening-10184`.
- Latest completed slice: `strategic-ai-staged-100-evidence-aggregation-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset0-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset98-count2-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset93-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset88-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset83-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset78-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset73-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset68-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset63-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset58-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset53-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset48-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset43-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset38-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset33-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset30-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset29-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset28-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset27-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset26-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset25-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset24-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset23-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset18-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset13-10184`.
- Latest completed slice: `strategic-ai-seed13-route-pressure-execution-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset8-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset3-10184`.
- Latest completed slice: `strategic-ai-broader-handoff-generalization-10184`.
- Latest completed slice: `strategic-ai-tactical-pressure-march-10184`.
- Latest completed slice: `strategic-ai-natural-battle-handoff-matrix-10184`.
- Latest completed slice: `strategic-ai-generated-town-battle-handoff-proof-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-behavior-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-coverage-10184`.
- Latest completed slice: `strategic-ai-generated-regroup-target-integrity-10184`.
- Latest completed slice: `strategic-ai-headless-resource-task-persistence-10184`.
- Latest completed slice: `battle-ai-spell-conservation-tactical-order-10184`.
- Latest completed slice: `battle-ai-shared-spell-tactical-order-10184`.
- Latest completed slice: `strategic-ai-active-front-support-launch-10184`.
- Latest completed slice: `strategic-ai-active-raid-launch-budget-10184`.
- Latest completed slice: `strategic-ai-active-front-event-surface-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-sharding-10184`.
- Latest completed slice: `battle-ai-immediate-threat-targeting-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-roster-sync-10184`.
- Latest completed slice: `battle-ai-overkill-target-discipline-10184`.
- Latest completed slice: `battle-ai-recovery-target-filter-10184`.
- Latest completed slice: `strategic-ai-path-distance-field-efficiency-10184`.
- Latest completed slice: `battle-ai-side-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-rules-commander-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-ai-tactical-order-payload-merge-continuity-10184`.
- Latest completed slice: `battle-ai-force-sync-payload-continuity-10184`.
- Latest completed slice: `battle-ai-outcome-payload-continuity-10184`.
- Latest completed slice: `battle-ai-normalized-payload-preservation-10184`.
- Latest completed slice: `battle-ai-rich-payload-spellbook-merge-10184`.
- Latest completed slice: `battle-ai-live-spell-template-cast-sync-10184`.
- Latest completed slice: `battle-ai-spell-template-spellbook-fallback-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-template-fallback-10184`.
- Latest completed slice: `strategic-ai-risk-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-spell-role-template-fallback-10184`.
- Latest completed slice: `battle-ai-commander-spell-role-valuation-10184`.
- Latest completed slice: `strategic-ai-spell-study-template-role-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-state-fallback-10184`.
- Latest completed slice: `battle-ai-battle-state-enemy-hero-fallback-10184`.
- Latest completed slice: `strategic-ai-path-surface-fingerprint-cache-10184`.
- Latest completed slice: `strategic-ai-indexed-path-search-10184`.
- Latest completed slice: `strategic-ai-path-distance-efficiency-10184`.
- Latest completed slice: `strategic-ai-long-run-progress-telemetry-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-payload-10184`.
- Latest completed slice: `battle-ai-spell-report-payload-bridge-10184`.
- Latest completed slice: `battle-ai-enemy-hero-payload-bridge-10184`.
- Latest completed slice: `battle-ai-commander-withdrawal-personality-10184`.
- Latest completed slice: `strategic-ai-long-run-configurable-matrix-10184`.
- Latest completed slice: `battle-ai-engaged-melee-attack-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-tiebreak-10184`.
- Latest completed slice: `strategic-ai-task-fit-spell-study-10184`.
- Latest completed slice: `battle-ai-lethal-spell-priority-10184`.
- Latest completed slice: `battle-ai-lethal-action-priority-10184`.
- Latest completed slice: `battle-ai-commander-buff-target-selection-10184`.
- Latest completed slice: `battle-ai-cleanse-recovery-urgent-filter-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-commander-fit-10184`.
- Latest completed slice: `battle-ai-damage-status-rider-targeting-10184`.
- Latest completed slice: `battle-strategic-ai-resistance-aware-spell-tuning-10184`.
- Latest completed slice: `strategic-ai-global-commander-task-assignment-10184`.
- Latest completed slice: `strategic-ai-post-recruit-surplus-mobilization-10184`.
- Latest completed slice: `strategic-ai-town-defense-commander-continuity-10184`.
- Latest completed slice: `strategic-ai-post-capture-town-support-continuation-10184`.
- Latest completed slice: `strategic-ai-neutral-town-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-surplus-garrison-mobilization-10184`.
- Latest completed slice: `strategic-ai-artifact-front-support-10184`.
- Latest completed slice: `strategic-ai-site-claim-recruits-10184`.
- Latest completed slice: `strategic-ai-opportunistic-town-resupply-10184`.
- Latest completed slice: `strategic-ai-opportunistic-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-active-town-runway-source-support-10184`.
- Latest completed slice: `strategic-ai-empire-build-arbitration-10184`.
- Latest completed slice: `strategic-ai-rare-resource-targeting-10184`.
- Latest completed slice: `strategic-ai-town-spell-study-10184`.
- Latest completed slice: `strategic-ai-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-personality-regroup-threshold-10184`.
- Latest completed slice: `strategic-ai-same-turn-launch-movement-10184`.
- Latest completed slice: `strategic-ai-midmove-hero-reaction-10184`.
- Latest completed slice: `strategic-ai-route-opportunistic-pickups-10184`.
- Latest completed slice: `strategic-ai-site-event-task-transition-10184`.
- Latest completed slice: `strategic-ai-duplicate-task-reservation-recovery-10184`.
- Latest completed slice: `strategic-ai-risk-regroup-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-target-selection-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-faction-scoped-hero-route-vision-10184`.
- Latest completed slice: `strategic-ai-player-hero-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-post-move-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-multihero-spawn-occupancy-10184`.
- Latest completed slice: `strategic-ai-defensive-threat-known-hero-gating-10184`.
- Latest completed slice: `strategic-ai-convoy-interception-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-hero-front-support-sighting-gate-10184`.
- Latest completed slice: `strategic-ai-active-hero-target-known-gating-10184`.
- Latest completed slice: `strategic-ai-lost-hero-task-reconciliation-10184`.
- Latest completed slice: `strategic-ai-stale-hero-hunt-revalidation-10184`.
- Latest completed slice: `strategic-ai-ordinary-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-persistent-exploration-task-board-10184`.
- Latest completed slice: `strategic-ai-neutral-town-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-no-known-target-exploration-10184`.
- Latest completed slice: `strategic-ai-known-nonhero-target-gating-10184`.
- Latest completed slice: `strategic-ai-no-omniscient-empty-target-fallback-10184`.
- Latest completed slice: `strategic-ai-fresh-launch-commander-fit-10184`.
- Latest completed slice: `strategic-ai-known-world-memory-10184`.
- Latest completed slice: `strategic-ai-post-objective-raid-continuation-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-recruitment-prep-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-launch-10184`.
- Latest completed slice: `strategic-ai-spell-aware-task-launch-10184`.
- Latest completed slice: `strategic-ai-resource-defense-battle-handoff-10184`.
- Latest completed slice: `strategic-ai-resource-defender-stationing-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-consolidation-10184`.
- Latest completed slice: `strategic-ai-live-commander-role-adoption-10184`.
- Latest completed slice: `strategic-ai-threat-recovery-reinforcement-10184`.
- Latest completed slice: `strategic-ai-nearby-threat-avoidance-10184`.
- Latest completed slice: `strategic-ai-commander-risk-tolerance-10184`.
- Latest completed slice: `strategic-ai-planned-launch-host-template-lock-10184`.
- Latest completed slice: `strategic-ai-post-regroup-target-resumption-10184`.
- Latest completed slice: `strategic-ai-commander-outcome-adaptation-10184`.
- Latest completed slice: `strategic-ai-defended-town-capture-stationing-10184`.
- Latest completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184`.
- Latest completed slice: `strategic-ai-planned-task-build-prep-10184`.
- Latest completed slice: `strategic-ai-recruitment-market-coverage-10184`.
- Latest completed slice: `strategic-ai-opportunistic-hero-intercept-10184`.
- Latest completed slice: `strategic-ai-destination-aware-recruitment-10184`.
- Latest completed slice: `strategic-ai-commander-personality-task-fit-10184`.
- Latest completed slice: `strategic-ai-site-contest-event-surfacing-10184`.
- Latest completed slice: `strategic-ai-planned-task-ready-launch-10184`.
- Latest completed slice: `strategic-ai-rmg-small-turn-health-10184`.
- Latest completed slice: `strategic-ai-defended-neutral-town-assault-10184`.
- Latest completed slice: `strategic-ai-neutral-town-expansion-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-10184`.
- Latest completed slice: `strategic-ai-multi-origin-task-planner-10184`.
- Latest completed slice: `strategic-ai-coordinated-task-planner-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-matrix-10184`.
- Latest completed slice: `strategic-ai-threat-arbitration-10184`.
- Latest completed slice: `strategic-ai-battle-task-outcome-lifecycle-10184`.
- Latest completed slice: `strategic-ai-risk-stall-withdrawal-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-support-grouping-10184`.
- Latest completed slice: `strategic-ai-town-defender-rotation-10184`.
- Latest completed slice: `strategic-ai-proactive-risk-regroup-10184`.
- Latest completed slice: `strategic-ai-post-move-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-defense-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-target-aware-spawn-point-selection-10184`.
- Latest completed slice: `strategic-ai-town-rebuild-garrison-safety-10184`.
- Latest completed slice: `strategic-ai-regroup-garrison-aware-routing-10184`.
- Latest completed slice: `strategic-ai-regroup-failure-rebuild-10184`.
- Latest completed slice: `strategic-ai-unreachable-route-recovery-10184`.
- Latest completed slice: `strategic-ai-shared-support-task-reservations-10184`.
- Latest completed slice: `strategic-ai-support-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-active-front-support-10184`.
- Latest completed slice: `strategic-ai-guarded-claim-resumption-10184`.
- Latest completed slice: `strategic-ai-guarded-object-claim-routing-10184`.
- Latest completed slice: `strategic-ai-encounter-arrival-risk-gating-10184`.
- Latest completed slice: `strategic-ai-hero-intercept-risk-gating-10184`.
- Latest completed slice: `strategic-ai-town-assault-risk-gating-10184`.
- Latest completed slice: `strategic-ai-commander-assault-consolidation-10184`.
- Latest completed slice: `strategic-ai-adventure-objective-progression-10184`.
- Latest completed slice: `strategic-ai-town-defender-lifecycle-10184`.
- Latest completed slice: `strategic-ai-town-defense-arrival-10184`.
- Latest completed slice: `strategic-ai-artifact-equipment-10184`.
- Latest completed slice: `strategic-ai-scouting-spell-execution-10184`.
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
- Latest completed slice: `balance-charter-granary-levies-pressure-10184`, a placement-local authored encounter correction that keeps the player victory bounded while removing the current Granary Levies high-margin outlier.
- Latest completed slice: `balance-ford-reavers-pressure-10184`, with separate authored Ironbridge and Mireford rosters that remove both duplicated Ford Reavers high-margin outliers without changing their shared dynamic raid group.
- Latest completed slice: `balance-glassroad-archive-wardens-pressure-10184`, adding one placement-local Ember Archer to remove the Glassroad Archive Wardens high-margin outlier without changing the shared encounter army.
- Latest completed slice: `balance-mireford-silt-hunters-pressure-10184`, reducing only the oversized Mireford Silt Hunters host to restore a bounded player victory without weakening Ironbridge or dynamic raid composition.
- Latest completed slice: `balance-lockmarsh-road-chaplains-pressure-10184`, reinforcing only the Lockmarsh chaplain column so the active authored breadth queue has no high-priority items and its balance-matrix gate passes.
- Previous completed slice: `magic-resistance-countercontrol-10184`.
- Previous completed slice: `battle-spell-valuation-counterplay-followup-10184`.
- Previous completed slice: `battle-spell-parity-counterplay-10184`.
- Previous completed slice: `magic-town-study-full-tier-access-10184`.
- Previous completed slice: `magic-spell-tier-power-bands-10184`.
- Completed slice: `combat-faction-pair-stat-tuning-10184` corrected Thornwake ability ownership and materially reduced full-matrix severity while retaining `needs_tuning` as the honest remaining balance state.
- Previous completed slice: `battle-benchmark-no-round-cap-10184`.
- Previous completed slice: `combat-feel-balance-pass-10184`.
- Earlier completed slice: `battle-fast-faction-benchmark-10184`.
- Earlier completed slice: `economy-native-rmg-required-source-support-10184`.
- `ops/progress.json` remains the operational source of truth for completed evidence, validation commands, and paused/superseded slice state.
- RMG test/report/export work is Python-owned. Do not add or run GDScript report/export launchers for RMG validation; GDScript remains for live in-game runtime behavior.

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
- Current strategic AI target: build from the baseline KPI audit into production behavior. Live commander/raid target choices now write normalized `enemy_states[].hero_task_state`, reuse saved active tasks for later target selection, reserve exclusive targets across active task boards, complete captured resource and artifact tasks, reconcile saved tasks against current target ownership/existence, suspend or invalidate saved tasks whose commander actor is missing, recovering, or unable to deploy, reactivate suspended saved tasks once their commander is deployable again, make new raid spawning prefer deployable commanders with reachable saved tasks before falling back to roster rotation, preserve explicit cancelled history when a commander is retasked to a different objective, persist objective-front encounter targets as first-class durable tasks, close live battle tasks from actual combat outcomes instead of battle queueing, arbitrate competing ready battles by strategic value instead of nearest-only ordering, give Native RMG/generated skeletal enemy configs runtime strategic AI defaults for raid pressure, spawn points, and encounter pools, add an executable generated-map long-run seed-matrix runner, seed coordinated pre-deployment task plans, and keep all of that continuity without a save-version bump.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-expansion-10184` makes generated-map/skirmish AI empires identify and capture reachable empty neutral towns as expansion objectives instead of only attacking player towns and resource/object sites. This is a live behavior slice, not a broad report-only gate or a full production-readiness claim.
- Latest strategic AI completed slice: `strategic-ai-defended-neutral-town-assault-10184` extends neutral-town expansion from empty towns into defended neutral towns by routing ready AI assaults through the live town battle system, risk-gating weak hosts, capturing the town without applying player-collapse consequences to neutral defenders, and letting active retake armies override planned reservations for urgent player-captured town recovery.
- Latest strategic AI completed slice: `strategic-ai-rmg-small-turn-health-10184` makes supported strict-Small Native RMG AI turns execute in the baseline by default and makes generated-map raid deployment expose player-facing target-assignment threat events instead of only pressure summaries.
- Latest strategic AI completed slice: `strategic-ai-planned-task-ready-launch-10184` lets prepared saved commander tasks launch from readiness instead of waiting for generic raid pressure, while unplanned raids still obey pressure thresholds.
- Latest strategic AI completed slice: `strategic-ai-site-contest-event-surfacing-10184` makes resolved encounter/objective-site arrivals emit compact public `ai_site_contested` events instead of silently mutating encounter/task state.
- Latest strategic AI completed slice: `strategic-ai-commander-personality-task-fit-10184` makes the live task planner score targets per commander archetype, command stats, specialty focus, and battle traits so enemy heroes stop acting like interchangeable target consumers.
- Latest strategic AI completed slice: `strategic-ai-destination-aware-recruitment-10184` makes enemy town recruitment pick units for the chosen destination: garrison defense, active raids, commander rebuilds, and planned commander tasks now use different unit-priority profiles.
- Latest strategic AI completed slice: `strategic-ai-opportunistic-hero-intercept-10184` makes active non-defensive raids retarget nearby exposed player heroes when the intercept is reachable and passes existing hero-risk readiness, while preserving defense/support/objective/guarded-claim priorities.
- Latest strategic AI completed slice: `strategic-ai-recruitment-market-coverage-10184` makes enemy town recruitment use live town-market coverage for wood/ore unit costs, consuming market caps when gold-backed recruitment buys missing materials.
- Latest strategic AI completed slice: `strategic-ai-planned-task-build-prep-10184` moves same-turn commander task planning ahead of town construction and gives objective-supporting buildings an explicit planned-task preparation score/reason, so AI towns build toward live commander goals before recruiting for them.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184` makes empty neutral-town expansion transfer the capturing host into the new town garrison, station the commander as defender, and retire the field raid instead of leaving a bare ownership flip.
- Latest strategic AI completed slice: `strategic-ai-defended-town-capture-stationing-10184` makes AI commanders that win defended town assaults consolidate into the captured town as active defenders with survivor-garrison continuity instead of entering generic post-assault recovery.
- Latest strategic AI completed slice: `strategic-ai-commander-outcome-adaptation-10184` makes commander target-selection fit adapt from live outcome memory: repeated success at a target kind increases future task fit for that kind, while defeats reduce it, without a save-version bump or public debug leakage.
- Current strategic AI follow-up: use the new long-run progress telemetry to reduce the strict Small Native RMG enemy-turn bottleneck now measured inside `OverworldRules.end_turn`/enemy turn execution, then broaden the generated-map runner from focused smoke into the full 100-seed eight-week matrix and continue deeper generated-map army/economy timing, retreat/personality, Medium/generalized generated-map behavior, and live-client pacing review. Guarded object routing, encounter-arrival risk, hero-intercept risk, town-assault risk, defended-town capture stationing, adaptive commander outcome memory, coordinated pre-deployment task planning, task-board recruitment prep, multi-origin planning, resource-front support, neutral-town expansion, neutral-town post-capture garrisoning, Small generated-map turn health, planned-task ready launch, site contest event surfacing, commander personality task fit, destination-aware recruitment, recruitment market coverage, planned-task build preparation, and focused long-run smoke are not a full strategic AI release-readiness claim.
- Latest strategic AI performance slice: `strategic-ai-pressure-summary-task-reuse-10184` makes public pressure events describe the durable active/planned commander task already selected that turn, avoiding an immediate duplicate whole-front target scan while retaining a fresh-scan fallback when no valid task exists.
- Latest strategic AI performance slice: `strategic-ai-idle-post-plan-skip-10184` skips the second full commander-task planning pass only when no raid existed to mutate task targets and recruitment did not change the deployable commander set; active fronts and newly ready commanders retain full post-raid planning.
- Latest strategic AI performance slice: `strategic-ai-active-front-empty-scan-skip-10184` rejects active-front support spawn planning before commander/army probe construction when a faction has no active pressure host, while preserving the complete support path whenever a live front exists.
- Latest strategic AI performance slice: `strategic-ai-ready-task-continuity-preflight-10184` skips ready-saved-task path/projection work when no available commander can meet even the minimum prepared-launch army threshold, while preserving ordinary saved-task targeting and the complete ready-launch path for a prepared commander.
- Latest strategic AI performance slice: `strategic-ai-spell-projection-roster-reuse-10184` reuses the phase-normalized commander roster across per-candidate adventure-spell projections without changing any spell valuation, saved-task score, or selected commander.
- Current battle-presentation target: battle resolution should emit a readable event stream for movement, strikes, shots, spell casts, damage, healing, status changes, resisted/immune outcomes, deaths, retaliation, morale/cohesion, and momentum; the battle scene should consume that stream with normal/fast/instant playback controls while keeping combat math unchanged.
- Use the fast battle-balance benchmark evidence to tune faction-pair combat spread now that fake round-cap outcomes have been removed, the public benchmark report uses side-neutral `side_a`/`side_b` terminology, and spell-enabled benchmark availability follows the same Native RMG week surface as army snapshots.
- Before more broad unit-stat nudges, strengthen the magic system as a strategic layer: spell availability, school coverage, field-magic access, and player-readable town/generated-map spell study should improve before trying to balance magic-focused heroes against raw-combat heroes.
- Latest magic follow-up: resistance and counter-control mechanics now run in live battle and in the fast benchmark before remaining spell-enabled benchmark outliers are treated as pure faction/unit imbalance.
- Owner direction has selected bounded campaign/content implementation. Current campaign target: expose a real difficulty choice in the campaign board and carry that choice through primary/chapter launch, session state, and save/resume evidence instead of silently forcing the default difficulty.
- Latest campaign completed slice: `campaign-difficulty-selection-10184` adds a compact campaign-board difficulty selector, synchronizes it with the existing difficulty model, and carries the selected value through live campaign launch and autosave summary state.
- Latest campaign follow-up: `campaign-difficulty-preview-alignment-10184` makes commander, operational, readiness, action-consequence, and launch-handoff previews use the same selected difficulty as the eventual campaign session.

## Completed Slice: River Pass Day 3 Refit Pressure and Relief Window

- Change only River Pass's scenario-local enemy-pressure defeat threshold/label from 8 to 15, its Day 3 relief from 3 to 20 River Guards, and its two-raid bell recall from 2 guards/1 archer to 2 guards/8 archers, producing the proven 34/8 post-Totemist field army after the temporary Fordhook cadets absorb the Totemist loss.
- Prove pressure 14 remains in progress while pressure 15 defeats, with the Day 9 deadline and all other scenario content unchanged. The rejected threshold-10 control reached the Day 3 refit but lost at pressure 14 during the required Day 4 hostile-town approach.
- Drive the authored River Pass economy route through Free Company, north wood, signal post, Ghoul Grove, Hollow Mire, southern ore, the real Day 3 relief/recall, Riverwatch refit, Totemist resolution, and the live intervening raid without forcing battle outcomes or session state. Three full-arc trajectories and the corrected 34-seed sequential raid-plus-town-plus-counterstroke screen reproduce defeats at 33/8 and identify 34/8 as the first continuous all-victory shield; the full arc uses the public confirmed Quick Resolve path for those battles and does not claim manual tactical play.
- Require the full authored three-chapter campaign arc, active battle breadth, deadline/core compatibility, static/editor checks, and bounded Linux/Windows export-startup gates before completion.
- Completion evidence: the 34/8 shield clears the full routed River Pass chapter including the intervening raid, Duskfen assault, counterstroke, outcome save/resume, and next-chapter transition; the same run completes all three chapters, and focused, breadth, compatibility, static/editor, Linux export/headless-startup, and Windows export/fresh-Wine-startup gates pass.
- Do not weaken encounters, global pressure/AI rules, resource or recruitment costs, unit/spell/battle math, save schema, generated maps, Native RMG, or claim broad campaign/release readiness.

## Completed Slice: Causeway Veteran Field and Staging Defense

- Keep the River Pass correction bounded and resolve the independent Causeway Stand conflict through its existing `veteran_supply_train` hook, which already delivers River Guard recruits to Duskfen after the River Pass carryover.
- Preserve Duskfen's authored five-Bog-Brute base garrison and add the veteran Guards through the same carryover hook for the scripted Day 2 Vaska counterraid. Do not transfer, weaken, or replace the base garrison and do not reduce the Gate Marshals, Reedward Camp, Reed Totemist, Blackfen, or counterraid forces.
- Use exact current Causeway snapshots and public Quick Resolve consequences to keep the first stable all-victory field plateau at ten recruit Guards and the first all-victory screened Duskfen defense at 32 garrison Guards. The Totemist control proves four is the first local victory, but the real arc shows its resulting 14-Guard army loses the Blackfen assault. The exact Blackfen snapshot's 33-seed screen still loses at 16 and 17, has a non-monotonic loss at 19, and first enters a continuous all-victory plateau at 20 live Guards, requiring ten field recruits. Two independent live arcs prove 25 and 26 garrison Guards can lose under their session-derived battle seeds; the exact defense snapshot's 34-seed screen keeps losses through 29, first removes defeats at 30, and first produces victory for every screened seed at 32. Reject larger opportunistic tuning.
- Preserve the shipped enemy retreat/surrender decision and reward behavior, but apply the same encounter-authored victory flags used by ordinary battle victory before scenario evaluation. Directly prove a Gate Marshals surrender resolves the encounter, sets `gate_marshals_broken`, clears battle state, and remains a victory.
- Keep the full-arc spell action method-matched to Lyra's authored spellbook: cast her live `spell_waystride` through the public overworld shell before the Fen Crown final march rather than requiring another hero's Trailglyph.
- Route the Fen Crown final march through the same public interrupt-aware town path used elsewhere in the arc, resolving any live raid battle before requiring the exact `fen_crown_redoubt` town-assault context.
- Require the real three-chapter campaign arc to complete through public route, town, battle, save/resume, and outcome paths; then rerun active battle breadth, deadline/core compatibility, repository/static/editor checks, and bounded Linux/Windows export-startup gates.
- Apart from the independently screened one-Guard River Pass relief correction required by the shared full-arc gate, do not change other River Pass values, other Causeway rewards/support sites, any unit, hero, spell, battle/autoresolve, strategic-AI, recruitment-cost, save-schema, generated-map, Native RMG, asset, or project-setting behavior. This is not manual tactical-play, broad campaign-balance, platform-input, signing/publication, whole-game, or release-readiness certification.
- Completion evidence: the full routed arc preserves Duskfen's five Bog Brutes, applies the ten-field/32-garrison veteran split, clears Gate Marshals and three route interrupts, captures Blackfen, and completes outcome save/resume and chapter handoff; the surrender-specific victory-flag report, active breadth, core, static/editor, and bounded Linux/Windows startup gates pass.

## Completed Slice: Fen Crown Final March Veteran Reserve

- Preserve the corrected River Pass 34/8 shield and Causeway ten-field/32-garrison split, and resolve the independently exposed Fen Crown final-march attrition through a scenario-local reinforcement in an existing post-objective hook.
- Use the exact live final-march snapshots and public Quick Resolve consequences for the two real raid interrupts plus the Fen Crown redoubt assault. Zero reserve reproduces the live `10 -> 3 -> defeat` trajectory; 13 reserve Guards wins the observed seeds but still loses two of 34 sequential seed triplets, while 14 is the first `34/34` all-victory plateau. Reject larger opportunistic tuning.
- Deliver exactly 14 reserve River Guards through the captured Blackfen bridgehead and its normal town recruitment path after the Crown Watch objective, without moving, weakening, removing, or bypassing either live raid or the redoubt garrison.
- Require the real three-chapter campaign arc to complete through public route, town, spell, battle, save/resume, and outcome paths; then rerun active battle breadth, deadline/withdrawal/core compatibility, repository/static/editor checks, and bounded Linux/Windows export-startup gates.
- Do not change unit, hero, spell, battle/autoresolve, strategic-AI, recruitment-cost, save-schema, generated-map, Native RMG, asset, or project-setting behavior. This is not manual tactical-play, broad campaign-balance, platform-input, signing/publication, whole-game, or release-readiness certification.
- Completion evidence: the full routed arc collects the 14 Guards through the post-Crown-Watch Blackfen refit, casts Waystride, resolves both live raid interrupts, wins the unchanged redoubt assault, saves/resumes the finale outcome, and reaches the completed campaign browser; focused 14-Guard content proof, the 59/59 clear active-battle queue, compatibility, static/editor, and bounded Linux/Windows startup gates pass.

## Selectable Near-Term Work

Before starting any item, add or select a concrete slice in `ops/progress.json`, mark it `in_progress`, and keep validation evidence there.

Recommended next slices:
- `strategic-ai-long-run-seed-matrix-10184`: expand strategic AI validation from focused fixtures into multi-week generated-map seed matrices once task ownership is durable enough to measure.
- `strategic-ai-multi-origin-task-planner-10184`: make coordinated task-board planning evaluate all owned towns/spawn origins and persist the selected origin on planned tasks.
- `strategic-ai-same-turn-task-prep-10184`: make the live enemy turn plan commander objectives before town recruitment so same-turn recruitment can prepare newly planned tasks.
- `strategic-ai-planned-task-recruitment-prep-10184`: make town recruitment prepare durable planned commander objectives before those objectives spawn as active raids, with emergency garrison and true rebuild priority preserved.
- `combat-faction-pair-stat-tuning-10184`: tune unit stats, growth, and ability power from the full benchmark outlier rows to reduce deterministic faction-pair win-rate spread.
- `battle-spell-valuation-counterplay-followup-10184`: tune spell AI valuation and counterplay from the spell-enabled benchmark evidence, especially heavy control preference, before treating the new outlier set as pure unit-stat imbalance.
- `battle-layout-smoke-followup-10184`: continue battle layout smoke only if the prior manual stop left actionable evidence or a reproducible UI/runtime issue.
- `strategic-ai-quality-pass-10184`: selected for the baseline KPI harness/audit. Do not treat it as full strategic AI production readiness.
- `rmg-small-generalization-hardening-10184`: harden strict Small generated-map evidence without claiming larger sizes, water, underground, or broad template parity.
- `ux-polish-player-comprehension-10184`: improve onboarding, tooltips, town planning clarity, battle intent feedback, save/load confidence, and reduce debug-like seams.
- `packaging-platform-readiness-followup-10184`: continue clean Windows/Linux packaging and smoke-test hardening.
- `headless-balance-harness-next-10184`: expand automated balance harness depth before scaling content.

Do not select:
- campaign/scenario breadth that only adds data or reports without a playable flow; owner direction now permits bounded campaign/content implementation with live validation;
- broad RMG parity claims from strict Small evidence;
- final art direction, final audio, or release packaging claims from generated/runtime placeholder layers;
- new validation gates that merely make reports pass without improving player-readable game behavior.

## Sunvault Solar Array Lanes

id: `combat-sunvault-solar-array-lanes-10184`

Status: completed.

Selected Phase 6 faction-identity and combat-balance slice. The faction bible
defines Solar Array Striders as disruption-resistant construct walkers that
project small firing lanes, but live content currently implements only the
resistance half of that role.

Implementation target:
- author a bounded Solar Array Lane ability on the tier-five Strider;
- while both the Strider source and linked Daybreak Colossus survive, reduce incoming melee damage to same-side Sunvault ranged stacks by three percent;
- consume the same authored source, link, role, faction, and multiplier contract in live BattleRules, tactical AI estimates, and the fast benchmark;
- expose the linked setup and loss condition in player ability summaries.

Completion criteria:
- focused live proof covers active primary and retaliation mitigation, source loss, linked-unit loss, non-Sunvault and melee-target exclusion, and no effect on ranged attacks or direct health loss;
- weeks one and two remain exact because the linked tier-seven unit is absent;
- the all-live 100-seed four-week matrix has zero structural failures and records exact outlier, severity, severe-row, dominance, and side-bias movement;
- ability, autoplay, balance-regression, core, editor-import, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not change unit stats, growth, costs, spells, heroes, benchmark thresholds, saves, strategic AI task planning, campaign content, or Native RMG;
- do not apply broad Sunvault stat buffs, protect melee stacks, reduce ranged/spell/direct damage, or claim final faction balance/overall release completion.

## Thornwake Sporeglass Mending Fire

id: `combat-thornwake-sporeglass-mending-fire-10184`

Status: completed.

Selected Phase 6 faction-identity and combat-balance slice. Sporeglass Menders
are named and priced as a support line, but currently own no ability and deal
less ranged damage than Embercourt's otherwise equivalent Bargebow Crews.
The all-live week-one Embercourt/Thornwake row is 68.5 percent Embercourt.

Implementation target:
- author a bounded Sporeglass mending ability that triggers after a successful primary ranged attack;
- restore only injured surviving creatures, select the target deterministically, and never resurrect casualties;
- consume the same amount and target policy in live BattleRules and the fast benchmark;
- expose the firing consequence in player ability summaries and battle presentation events.

Completion criteria:
- focused live proof covers successful firing, deterministic target choice, dead/no-source behavior, no valid target, and casualty-only non-resurrection;
- the authored contract restores three health per living Mender, capped at eight per attack, to one allied surviving stack;
- the all-live 100-seed four-week matrix has zero structural failures and records exact outlier, severity, dominance, and side-bias movement;
- ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not change unit stats, growth, costs, spells, heroes, benchmark thresholds, saves, strategic AI, campaign content, or Native RMG;
- do not add casualty resurrection, a passive army-wide aura, or final faction-balance/overall-release claims.

## Veilmourn Final Notice Brace Targeting

id: `combat-veilmourn-final-notice-brace-targeting-10184`

Status: completed.

Selected Phase 6 faction-balance and tactical-AI slice. Final Notice already
applies stronger cohesion and retaliation pressure to a veteran braced line,
but both live AI and the benchmark add only a hardcoded 0.25 braced-target
bonus. In the current Thornwake/Veilmourn week-two row, every measured notice
instead targets Sporeglass Menders and the intended counter-line branch never
guides the once-per-battle decision.

Implementation target:
- author a minimum brace tier and bounded braced-target priority on Final Notice rather than keeping the choice in hardcoded AI constants;
- consume the same fields in live tactical AI and the fast balance benchmark;
- keep the existing one-use, one-round cohesion and retaliation pressure unchanged;
- make the player ability window explain when Final Notice is prioritizing a veteran braced line.

Completion criteria:
- focused live proof shows Obituary Scribes select a qualifying braced line over an otherwise attractive ranged target, apply the stronger existing mark, and do not retarget a tier-one brace;
- live AI and the benchmark use the same authored threshold and priority fields;
- the all-live 100-seed four-week matrix has zero structural failures and records exact outlier, severity, dominance, and side-bias movement;
- ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not change unit stats, growth, spell behavior, Final Notice duration/use count/modifiers, benchmark thresholds, saves, strategic AI, campaign content, or Native RMG;
- do not claim final Veilmourn identity, final faction balance, or overall release completion.

Completion result:
- Final Notice owns a tier-two veteran-brace threshold and 3.75 authored target priority shared by live tactical AI and the fast benchmark;
- focused runtime proof selects Thornwhip Carriers over Sporeglass Menders, applies the existing stronger braced mark, and proves tier-one braces receive no added braced priority;
- only four faction-pair rows change: Thornwake/Veilmourn moves from 70.5 to 64.0 percent in week two and from 59.0 percent Veilmourn to 52.0 percent Veilmourn in week four, week-three Thornwake/Veilmourn remains 61.5 percent with pacing movement, and week-three Embercourt/Veilmourn moves from 60.5 to 61.5 percent Veilmourn;
- the accepted all-live matrix passes with zero structural failures at 29 outliers / 183.5 severity / 7 rows at or above 65 percent / 69.5 percent maximum dominance / 2.67-point maximum side bias.

## Survivor-Only Battle Recovery Valuation

id: `battle-ai-survivor-recovery-valuation-10184`

Status: completed.

Selected Phase 6 tactical-AI correctness slice. `BattleRules` already caps
recovery at the remaining health capacity of living creatures, but tactical AI
and the fast benchmark compare against the stack's original full army health.
That mismatch lets enemy commanders value and cast recovery for casualties that
the live resolver cannot restore, while the benchmark resurrects those casualties
and reports balance for behavior the shipped game does not have.

Implementation target:
- define one survivor-only recoverable-health contract and consume it in live recovery resolution and tactical-AI target valuation;
- prevent recovery candidates when a stack has lost whole creatures but every survivor is at full health, while retaining casts for genuinely injured survivors;
- align the fast benchmark's recovery target scoring and health cap with live BattleRules;
- make player-facing recovery summaries explicitly state that fallen creatures are not restored.

Completion criteria:
- focused live proof covers casualty-only, injured-survivor, and full-health recovery targets and proves AI never selects impossible healing;
- live resolution cannot raise a stack above its current living-creature health cap;
- the all-live benchmark has zero structural failures and records any resulting balance movement without claiming balance completion;
- magic-AI, spell behavior, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not change spell costs, restore amounts, unit stats, growth, faction abilities, benchmark thresholds, saves, strategic AI, campaign content, or Native RMG;
- do not add casualty resurrection or claim final spell, faction-balance, or overall release completion.

Completion result:
- shared live and benchmark recovery behavior now caps healing at current surviving-creature capacity and exposes zero value for casualty-only damage;
- focused live reports prove both impossible-target filtering and valid injured-survivor casting, and player action text states that fallen creatures are not restored;
- the accepted all-live matrix passes with zero structural failures at 30 outliers / 193.0 severity / 8 rows at or above 65 percent / 70.5 percent maximum dominance / 2.53-point maximum side bias;
- the resulting balance regression is retained as explicit tuning debt because the previous benchmark behavior resurrected casualties and caused tactical AI to spend mana on impossible healing.

## Sunvault Relay Activation

id: `combat-sunvault-relay-activation-10184`

Status: completed.

Selected Phase 6 combat-balance implementation slice. The accepted all-live
matrix has 31 outliers / 203.0 severity, and Sunvault wins 69.5 percent of its
week-one Brasshollow pairing before its authored tier-four support unit enters
the army. Sunvault's source identity is planned calibration warfare that becomes
strong after relay and support infrastructure, but the live faction doctrine
currently turns multiple independent spell buffs into a line-wide resonance at
every tier. Focused replay also shows Sunvault still wins 57 percent with spells
removed. Exact hero-pair candidate replay rejects lower growth because it worsens
the extreme, while reducing Prism Adept initiative from seven to six lowers that
pairing to 58.5 percent without changing its damage, growth, range, or accuracy role.

Implementation target:
- give Resonant Choristers an authored relay ability that activates Sunvault's line-wide multi-buff damage and initiative payoff while the support stack is alive;
- preserve the existing personal damage and initiative payoff on each individually buffed Sunvault stack before or after relay loss;
- reduce Prism Adept initiative from seven to six before the support ladder arrives, then let a living Resonant Relay restore that point to the linked Prism stack;
- align live combat resolution, tactical AI estimates, player doctrine summaries, the fast benchmark, schema validation, and focused runtime proof.

Completion criteria:
- focused live proof covers relay absent, relay present, linked Prism initiative restoration, and defeated-relay states without changing individual buff consequences;
- the full 100-seed all-live four-week matrix improves week-one Sunvault excess without increasing the accepted 31 outliers, 203.0 severity, 8 rows at or above 65 percent, 69.5 percent maximum dominance, 2.80-point side bias, or zero structural failures;
- ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not change other raw combat stats, unit growth, costs, spells, heroes, scenarios, strategic AI, saves, benchmark thresholds, or Native RMG;
- do not remove Sunvault's individual spell-calibration payoff or claim final faction balance or overall release completion.

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

The current economy identity pass moves towns away from a one-signature-rare model. Native RMG generated-package source support is complete and remains unchanged. The selected authored-source breadth slice separately ensures active campaign/skirmish towns can reach the same costs through persistent, capturable map sources rather than free stockpiles or rare-resource markets.

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

## Combat Faction Pair Stat Tuning

Completed slice: `combat-faction-pair-stat-tuning-10184`.

Result:
- `Root Brace` now belongs to Thornwake Thornwhip Carriers instead of Embercourt Lantern Sappers, and content validation locks that faction ownership;
- Barkmantle Screens and Pinning Reach use their original authored multipliers instead of the later values that compensated for the missing T2 ability;
- the unchanged all-live 100-seed, four-week matrix improved from 45 to 41 outliers, severity 503.5 to 389, and 23 to 18 rows at or above 65%, with no 100-0 rows and all structural gates passing.

Implementation target:
- trace deterministic and high-margin pair outcomes to shipped unit stats, weekly growth, and live ability power rather than changing benchmark gates or outcome rules;
- preserve faction identity and progression while reducing dominant pair outcomes across weeks 1-4;
- keep aggregate side bias low, retain resolved side-a/side-b outcomes only, and preserve existing town-development and live Godot battle behavior.

Completion evidence:
- the deterministic 100-seed four-week matrix has no 100-0 faction-pair rows and materially fewer 45-55% pair outliers than the pre-slice baseline;
- quick iteration rows and the final full matrix use unchanged benchmark semantics and live content files;
- focused content validation, town development/economy checks, live battle/core regressions, project parsing, and repository validation pass.

Non-goals:
- do not change Native RMG generation, strategic-AI policy, benchmark outcome semantics, or save schemas;
- do not claim final magic-vs-might balance, final faction balance, or overall release completion from one tuning pass.

## Veilmourn Obituary Pressure

id: `combat-veilmourn-obituary-pressure-10184`

Completed Phase 5 combat implementation slice. Restores the tier-5 Obituary
Scribes' faction-bible role through live battle behavior instead of another raw
stat adjustment.

Implementation target:
- give Obituary Scribes a bounded ranged obituary effect that drains cohesion and therefore weakens the target's retaliation through the existing morale model;
- normalize, preview, resolve, and value the ability consistently in live BattleRules, Battle AI, and the fast Python benchmark;
- expose readable ability/status feedback and prove the effect changes a real battle outcome without changing turn order or base unit stats.

Completion evidence:
- focused live runtime coverage proves obituary application, cohesion loss, retaliation reduction, expiration, authored text, and stripped-ability control behavior;
- the unchanged all-live 100-seed matrix materially lowers the week-2 Thornwake/Veilmourn `80.5%` baseline and does not increase the baseline `38` outliers or `336` severity;
- unit ability consequence, battle AI, combat/core, project parse, repository, and JSON validation pass.
- final matrix: `37` outliers, `304` severity, `12` rows at or above `65%`, `78.5%` maximum dominance, and `74.5%` Thornwake/Veilmourn week-2 dominance, with zero structural failures.

Non-goals:
- do not alter benchmark thresholds, seed policy, faction growth, raw unit stats, spell catalogs, strategic AI, saves, or campaign progression;
- do not touch Native RMG or claim final faction balance or overall release completion.

## Brasshollow Crucible Barrage

id: `combat-brasshollow-crucible-barrage-10184`

Completed Phase 5 combat implementation slice. Restores the tier-6 Crucible
Crawlers' faction-bible setup-siege role through the existing live Volley
mechanics, without changing benchmark semantics or inflating raw unit stats.

Implementation target:
- give Crucible Crawlers a bounded long-lane barrage that deals modestly stronger ranged damage and punishes already-staggered battle lines;
- use the existing BattleRules, Battle AI, player-facing summary, and fast benchmark Volley contract rather than introducing a content-only marker;
- keep the ability at tier 6 so it cannot worsen Brasshollow's already dominant week-1/2 rows;
- preserve Brasshollow's slow armored identity and current growth, costs, spell access, strategic AI, save, and Native RMG behavior.

Completion evidence:
- focused live ability coverage proves the authored Crawler ability has a real ranged-damage consequence and all authored ability instances remain implemented;
- the unchanged all-live 100-seed matrix improves on the baseline `37` outliers / `304` severity, materially improves at least one targeted week-3 Brasshollow row, and does not exceed `78.5%` maximum dominance;
- structural, pacing, side-bias, town-development, core, project-parse, repository, JSON, and diff gates pass.
- final matrix: `36` outliers, `300.5` severity, `12` rows at or above `65%`, `78.5%` maximum dominance, `2.93` maximum side bias, and zero structural failures; all week-1/2 pair rows remain exact.

Non-goals:
- do not change benchmark thresholds, seeds, faction growth, raw unit stats, spells, strategic AI, saves, campaigns, or Native RMG;
- do not claim final faction balance or overall release completion.

## Brasshollow Debt-Engine Overheat

id: `combat-brasshollow-debt-engine-overheat-10184`

Completed Phase 5 combat implementation slice. Restores the tier-5 Debt-Engine
Exactors' faction-bible burst/overheat cycle as a live tactical tradeoff rather
than mapping it onto an unrelated generic ability.

Implementation target:
- fresh Debt-Engine primary attacks receive a bounded burst multiplier and then apply a visible two-round Overheated effect to the attacking stack;
- Overheated lowers outgoing damage, defense, and initiative until it expires, cannot stack or refresh from repeated attacks, and allows the burst again only after recovery;
- BattleRules previews/resolution, tactical AI attack/defend valuation, player-facing ability/status summaries, the fast benchmark, and focused runtime coverage use the same contract;
- preserve raw unit stats, growth, costs, spell access, save version, strategic AI, and Native RMG behavior.

Completion evidence:
- focused live coverage proves fresh burst, self-application, active penalties, no refresh while active, expiration, and recovered burst behavior;
- the unchanged all-live 100-seed matrix keeps `36` outliers, improves severity `300.5 -> 300.0`, improves maximum dominance `78.5% -> 78.0%`, keeps `12` rows at or above 65%, and reduces week-2 Brasshollow dominance versus Embercourt `69% -> 66%` and Veilmourn `71% -> 68%`;
- structural, pacing, side-bias, ability, autoplay, town-development, core, project-parse, repository, JSON, and diff gates pass.

Non-goals:
- do not change benchmark thresholds, seeds, unit stats, growth, spells, economy, strategic AI, saves, campaigns, or Native RMG;
- do not claim final Brasshollow identity, final faction balance, or overall release completion.

## Brasshollow Foundry Saint Aura

id: `combat-brasshollow-foundry-saint-aura-10184`

Completed Phase 5 combat implementation slice. Restores the tier-7 Foundry
Saint's faction-bible ally-hardening and machine-repair role as live battle
behavior instead of leaving the capstone as raw statistics.

Implementation target:
- while a Foundry Saint stack remains alive, active Overheated Brasshollow machinery receives one bounded non-stacking defense bonus;
- at round start, the same aura repairs bounded damage within each surviving allied stack without resurrecting lost units, with an authored bonus for active Overheated machinery;
- repair emits player-readable battle/presentation events, tactical AI values removing the enemy aura, and live summaries explain the active hardening/repair role;
- BattleRules, Battle AI, the fast benchmark, focused runtime coverage, and content validation use the same authored contract;
- preserve raw unit stats, growth, costs, spell access, saves, campaigns, strategic AI, and Native RMG behavior.

Completion evidence:
- focused live coverage proves Overheated-only side-scoped defense, no ordinary-defend or cross-faction benefit, bounded non-resurrecting repair, Overheated repair priority, aura removal when the Saint dies, and tactical-AI target valuation;
- the unchanged all-live 100-seed matrix does not regress the `36` outlier / `300.0` severity / `78.0%` maximum baseline and reduces at least one excessive week-3 Brasshollow loss;
- structural, pacing, side-bias, ability, focused autoplay balance/regression, town-development, core, project-parse, repository, JSON, and diff gates pass; the broader standard harness's active-encounter queue and Ninefold strategic-AI failures remain byte-for-byte/signature-identical with the Foundry aura removed and stay outside this combat slice.

Non-goals:
- do not change benchmark thresholds, seeds, unit stats, growth, spells, economy, strategic AI, saves, campaigns, or Native RMG;
- do not resurrect destroyed units, stack multiple Saint auras, create a general machine-tag migration, or claim final faction balance/release completion.

## Orevein Contract Encounter Resolution

id: `balance-orevein-contract-encounter-resolution-10184`

Completed Phase 6 authored-combat implementation slice. Repairs Orevein
Contract's placement-local Archive Wardens low-pressure victory and the
Bridgeward Levies deterministic round-14 stalemate.

Implementation target:
- strengthen `orevein_archive_wardens` enough to clear its 91% terminal-margin outlier while retaining a bounded medium-difficulty player victory;
- make blocked advances apply their authored field-objective influence so obstruction lines can be forced aside while preserving the blocked stack's current position for that action;
- preserve Bridgeward Levies' authored local roster and resolve it as a bounded high-difficulty player victory through the corrected objective runtime;
- preserve shared Embercourt army groups and exact faction-benchmark inputs while extending focused ownership regression coverage.

Completion evidence:
- Archive Wardens resolves in three rounds at 83% terminal margin / 15 enemy damage per round, Bridgeward Levies in five rounds at 64% / 20, and unchanged Beacon Wardens in three rounds at 63% / 28;
- focused core coverage proves a blocked advance leaves the stack in place, surfaces the obstruction message, and finishes forcing aside a pre-contested obstruction line;
- exact assertions preserve Archive/Bridgeward local rosters and shared Archive Warden/Causeway Phalanx army groups;
- the 59-sample active-scenario breadth queue improves from 35 items / 6 high-priority items to 34 / 4 with signature `ec937a0e`, zero stalls or invalid orders, and passing runtime consequence gates;
- Orevein skirmish, core systems, project parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change shared armies, global unit stats, battle difficulty labels, rewards, strategic AI, saves, campaigns, or Native RMG;
- do not weaken queue thresholds or claim remaining encounter/faction balance debt or overall release completion.

## Ninefold Barrow Vault Battle Pressure

id: `balance-ninefold-barrow-vault-pressure-10184`

Completed Phase 6 authored-combat implementation slice. Repairs Ninefold
Confluence's medium-difficulty Barrow Vault guard, which previously resolved at
92% terminal margin and was the active breadth queue's largest outlier.

Implementation target:
- give `ninefold_barrow_vault_watch` a placement-local Hedgehook/Thornbow army without changing shared `army_neutral_bramble_hedge_watch` content;
- retain a deterministic player victory while moving terminal margin below the active matrix outlier threshold and producing meaningful enemy damage;
- add focused live regression coverage for outcome, pacing, pressure, exact local roster ownership, and shared-roster preservation.

Completion evidence:
- the focused battle resolves in three rounds as a player-advantaged victory at 70% terminal margin and 15 enemy damage per round, while exact assertions preserve the shared 6/4 army;
- the 59-sample active-scenario breadth queue improves from 38 items / 8 high-priority items to 35 / 6 with signature `b17034f9`, zero stalls or invalid orders, and passing runtime consequence gates;
- the diff changes no faction benchmark input, preserving the previously verified 36-outlier / 293.5-severity / 75.5%-maximum all-live matrix by construction;
- focused battle, Ninefold smoke, core systems, project parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change shared neutral armies, global unit stats, battle difficulty, rewards, strategic AI, saves, campaigns, or Native RMG;
- do not weaken queue thresholds or claim remaining encounter/faction balance debt or overall release completion.

## Bellwake Mirror Lancers Battle Pressure

id: `balance-bellwake-mirror-lancers-pressure-10184`

Completed Phase 6 authored-combat implementation slice. Repairs Bellwake Wreck
Claim's high-difficulty Mirror Lancers guard, which previously resolved as a
two-round victory at 98% terminal margin with negligible enemy pressure.

Implementation target:
- strengthen `bellwake_mirror_lancers` through its placement-local army without changing the shared `army_mirror_lancers` roster;
- strengthen the adjacent placement-local `bellwake_relay_pickets` line enough to apply meaningful pressure while preserving its bounded medium-difficulty victory;
- retain a deterministic player victory while reducing terminal margin below the active matrix outlier threshold and producing meaningful enemy damage;
- extend focused live regression coverage to prove outcome, pacing, pressure, and exact placement-local army ownership.

Completion evidence:
- the focused Bellwake battle suite resolves Relay Pickets at 87% terminal margin / 7 enemy damage per round, Mirror Lancers at 74% / 26, and the unchanged Aurora Battery at 50% / 25; all are bounded player victories;
- the 59-sample active-scenario breadth queue improves from 40 items / 10 high-priority items to 38 / 8 with signature `8958533c`, zero stalls or invalid orders, and passing runtime-consequence gates;
- both shared Sunvault armies retain their exact rosters and the unchanged 100-seed all-live faction matrix retains 36 outliers, 293.5 severity, 12 rows at or above 65%, 75.5% maximum dominance, and zero structural failures;
- focused battle, Bellwake skirmish, core systems, project parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change shared army groups, global unit stats, battle difficulty, rewards, strategic AI, saves, campaigns, or Native RMG;
- do not weaken queue thresholds or claim the remaining active encounter/faction balance debt or overall release is complete.

## Ninefold Drowned Reliquary Battle Pressure

id: `balance-ninefold-drowned-reliquary-pressure-10184`

Completed Phase 6 authored-combat implementation slice. Repairs the active
Ninefold Confluence Drowned Reliquary guard, which previously resolved as a
flawless player victory despite its high-difficulty authored role.

Implementation target:
- give `ninefold_drowned_reliquary_watch` a placement-local army suited to its high-difficulty guarded-artifact role without changing the shared Tidepool Skiffyard army;
- retain a deterministic player-advantaged victory while reducing terminal margin below the active matrix outlier threshold and producing meaningful enemy damage;
- add focused live regression coverage for outcome, pacing, pressure, and exact placement-local army ownership.

Completion evidence:
- the focused battle resolves in four rounds without stalls or invalid orders as a player-advantaged victory at 71% terminal margin and 11 enemy damage per round;
- the 59-sample active-scenario breadth queue improves from 44 items / 12 high-priority items to 40 / 10, with the Drowned Reliquary outliers removed and runtime-consequence matrix status improved from fail to pass;
- the unchanged 100-seed all-live faction matrix retains 36 outliers, 293.5 severity, 12 rows at or above 65%, and 75.5% maximum dominance with zero structural failures;
- guarded-site rewards, core systems, Ninefold smoke, project parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change shared neutral army groups, global unit stats, battle difficulty, rewards, artifact behavior, strategic AI, saves, campaigns, or Native RMG;
- do not weaken queue thresholds or claim the remaining active breadth/faction balance debt is complete.

## Ninefold Strategic AI Front Launch And Retask

id: `strategic-ai-ninefold-front-launch-retask-10184`

Completed Phase 5 strategic-AI implementation slice. Repairs live launch and
defense-priority failures exposed by the standard headless runtime harness in
the shipped Ninefold Confluence scenario.

Implementation target:
- make each authored Ninefold enemy origin produce a reachable launch candidate when its faction owns a town, has an available commander, and exceeds its raid threshold;
- ensure an active raid prioritizes its faction's owned stabilizing town defense gap over ordinary resource pressure, including Bellwake Harbor's authored local layout;
- correct the shared runtime/content contract at its source and retain generic pathing, commander assignment, public AI events, and save-state behavior.

Completion evidence:
- the multi-scenario pressure case launches all five Ninefold factions and emits a target assignment for each launched raid;
- the multi-scenario town-defense case retasks all five Ninefold factions to their own stabilizing town with `town_defense` and `front_stabilization` reasons;
- focused strategic-AI reports prove all five Ninefold pressure launches and town-defense retasks, while the broader harness proves all nine covered faction/scenario cases also select objective fronts;
- the 21-case standard headless harness exits successfully with 19 passes, one existing warning, one existing generated-map deferral, and no failures;
- Ninefold smoke, core systems, project parse, repository, JSON, and diff validation pass.

Non-goals:
- do not weaken path passability, commander availability, defense commitment, or public-event contracts merely to satisfy fixtures;
- do not change combat balance, economy, save version, Native RMG, or claim overall game completion.

## Strategic AI Eight-Way Overworld Pathing

id: `strategic-ai-eight-way-overworld-pathing-10184`

Selected Phase 6 runtime correction. Strategic raids must evaluate and execute
the same eight-way overworld movement surface available to the player, including
the existing blocked-corner rule, so recovered Native RMG object masks do not
become artificial cardinal-only barriers.

Implementation target:
- replace the strategic AI's cardinal-only distance fields, next-step selection, and blocked-goal approach scans with deterministic eight-way traversal;
- reject a diagonal step only when both orthogonal side cells are blocked, matching `OverworldRules.tile_step_cuts_blocked_corner()` without changing terrain or package object masks;
- preserve authoritative Native RMG terrain, body, action, and visit cells and retain deterministic target selection, encounter handling, resource interaction, and save-state behavior.

Completion evidence:
- a focused live pathing regression proves legal diagonals cross a cardinal-only barrier, blocked corners remain rejected, and distance/next-step behavior agree;
- the standard live route captures `river_free_company` in seven turns after reducing route distance from six to two, and intact planner-assigned commanders retain grouping leadership without breaking partial commander rebuild continuity;
- Medium ordinal 95 completes 56/56 deterministic turns and reduces stalls from 12 to 7, while its remaining zero-movement seal is named separately as the parity-proven `AVMsawg0.def` plus `AVLautr7.def` exact-mask overlap rather than misreported as an eight-way pathing failure;
- focused strategic-AI suites, core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not modify recovered Native RMG output, package terrain/object masks, object placement, benchmark thresholds, combat balance, economy, or save schemas;
- do not add retries, density tuning, topology gates, or claim full Native RMG, strategic-AI matrix, or overall release completion from this correction.

## Native RMG Exact-Mask Runtime Start Selection

id: `native-rmg-exact-mask-runtime-start-selection-10184`

Selected Phase 6 runtime correction. Restore the established exact-mask runtime
hero-start selection that the active package service dropped, so a parity-proven
town action tile is not used as the playable start when recovered object bodies
seal every legal first move.

Implementation target:
- select the nearest exact-mask-passable runtime start tile with route continuity from the generated source town, using active package terrain/body/action/visit data and the existing bridge helpers;
- emit `hero_start_tile` and `runtime_start_tile` through the active package contract for Linux and Windows without changing recovered H3MapEd final payload bytes;
- preserve deterministic package identity, town action/visit coordinates, object masks, and fail-closed unsupported-scope behavior.

Completion evidence:
- the Medium ordinal 95 package starts the player on a legal tile in the adjacent reachable component instead of the sealed town action tile `(31,10)`;
- generated-session movement and strategic-AI smoke prove the selected start is playable while exact package terrain/object masks and parity payload hashes remain unchanged;
- native package, bridge, core systems, project parsing, repository, JSON, and diff validation pass on synchronized Linux/Windows contract surfaces.

Non-goals:
- do not delete or move recovered objects, tune density, clear final-map tiles, alter the parity-proven `AVMsawg0.def` plus `AVLautr7.def` overlap, or claim full Native RMG or overall release completion.

## Canonical Terrain Visual Regression Gate

id: `terrain-taxonomy-visual-regression-gate-10184`

Selected Phase 6 corrective validation slice. Aligns authored visual smoke inputs
with the canonical terrain taxonomy introduced by `c24abe70` without changing
runtime terrain selection or generated-map behavior.

Completion evidence:
- the River Pass smoke proves legacy forest-to-grass degradation through a controlled fixture instead of a town-footprint cell that is now authored grass;
- the Ninefold smoke proves current grass/dirt, dirt/sand, and water/land transitions at canonical authored coordinates;
- both visual suites, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not change terrain renderer rules, canonical authored maps, Native RMG, or recovered H3MapEd behavior;
- do not count this release-gate repair as runtime/content implementation progress or overall release completion.

## Overworld Hero Action Signature Reliability

id: `overworld-hero-action-signature-reliability-10184`

Selected Phase 6 runtime correction. The hero-action cache signature must accept
the real nested `pending_specialty_choices` schema used by active progression
without throwing during refresh.

Implementation target:
- preserve arrays of plain nested hero metadata structurally in the JSON cache signature instead of assuming every member is a scalar string;
- retain cache hits for unchanged route selection and cache misses for active-hero, roster, and pending-choice changes;
- keep hero actions, specialty choices, session state, save version 9, and Native RMG behavior unchanged.

Completion evidence:
- focused cache regression covers nested pending specialty records and all existing reuse/invalidation cases without script errors;
- overworld visual specialty flow, core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not redesign progression, action surfaces, renderer behavior, saves, or Native RMG;
- do not claim broad performance, accessibility, or overall release completion.

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

## Strategic AI Current-Tile Objective Target

The completed strategic AI slice makes an idle host explicitly assign a contestable resource under its current tile before adopting a distant saved task.

Target shape:
- town-retake and immediate post-capture support orders retain priority;
- an otherwise idle host standing on a contestable resource assigns that resource before saved-task, active-front, or general target selection;
- the resource claim completes and persists a real live task before the same host adopts its next objective;
- when the bounded task board is full, recent completed tasks survive ahead of regenerable planned tasks instead of being evicted by task-id ordering;
- hosts already marching toward a valid target continue to use opportunistic route pickups without replacing that target;
- Native RMG output, resource rewards, and non-resource target scoring remain unchanged.

Non-goals:
- do not synthesize completed task history for objectives that were never assigned;
- do not change guarded-resource battle requirements;
- do not tune strategic priorities or generated-map placement.

## Persistent Battle Playback Speed

The completed Phase 6 UX/accessibility slice makes battle playback speed a durable device preference instead of a per-encounter reset.

Target shape:
- Settings exposes Normal, Fast, and Instant battle playback defaults;
- the preference persists in the device settings file and migrates older settings to Normal;
- every opened or resumed battle adopts the device preference without changing combat math, turn order, or outcome state;
- changing speed from the battle controls immediately updates both the active battle and the stored preference;
- settings and battle validation prove persistence and live shell adoption.

Non-goals:
- do not change animation durations for any speed mode;
- do not alter combat simulation, save schema, or battle outcome behavior;
- do not redesign the battle command rail or main settings composition.

## Overworld Controller Movement And Navigation

The completed corrective Phase 6 input/accessibility slice makes the primary overworld loop controller-reachable without stealing D-pad focus navigation from command controls.

Target shape:
- the left stick moves the active hero in the dominant cardinal direction through the existing movement methods;
- the stick uses a dead zone, one immediate step, and a bounded held-direction repeat cadence suitable for grid travel;
- returning the stick to neutral clears movement state;
- global controller UI mappings bind the standard D-pad to directional focus, A to accept, and B to cancel;
- D-pad buttons remain owned by Godot UI navigation and can move focus through both the main menu and overworld commands;
- WASD, arrow-key movement, keyboard diagonals, shifted map panning, debug keys, and focused command activation remain unchanged;
- menu and active-play validation prove real D-pad and face-button events navigate/activate UI while a real stick-axis event moves the active hero.

The earlier D-pad-as-hero-movement slice is superseded because consuming D-pad input in `_input` prevented controller users from navigating the focused command UI.

Non-goals:
- do not claim full controller/hardware certification;
- do not add diagonal stick movement, vibration, or button rebinding;
- do not change overworld movement rules or redesign on-screen controls.

## Controller Active-Play Traversal

The completed Phase 6 accessibility slice extends controller ownership from menu/overworld basics into the existing active-play command surfaces.

Target shape:
- standard right/left shoulder buttons traverse the shared next/previous focus cycle without replacing D-pad directional navigation;
- B closes an open overworld command/frontier drawer and restores focus to the overworld command surface;
- in a narrow town, B returns from town orders to the scenic town view before any town exit; from the scenic/wide town surface, B follows the existing Leave handoff;
- real controller A events select and confirm a town construction order and execute a legal battle command through the existing button paths;
- real shoulder, D-pad, A, and B events preserve visible focus across overworld, town, and battle refreshes;
- keyboard focus, keyboard activation, movement rules, town rules, combat simulation, and Native RMG behavior remain unchanged.

Non-goals:
- do not claim full controller or hardware certification;
- do not add rebinding, vibration, diagonal stick movement, or controller-driven battle-board hex selection;
- do not make B trigger retreat, surrender, or another irreversible battle action;
- do not redesign active-play screens or add visible instruction panels.

## Battle Controller Hex-Board Navigation

The completed Phase 6 accessibility slice makes exact tactical board selection available from a controller through the same target and movement dispatch used by mouse input.

Target shape:
- the battle board is a real focus-cycle control without replacing the preferred command-button focus on battle entry or after actions;
- entering board focus exposes a visible hex cursor initialized from the selected target, an available move destination, or the active stack;
- D-pad directions move the cursor across the bounded 11x7 hex board while preserving the existing command focus cycle outside board focus;
- A dispatches the cursor cell through the existing enemy-stack focus/attack or exact legal-destination move signals;
- B exits board focus and restores the current preferred legal battle command without triggering retreat or surrender;
- battle-board state snapshots expose cursor position, cell role, and focus ownership for focused runtime validation;
- mouse board input, combat rules, battle outcomes, keyboard command activation, save state, and Native RMG behavior remain unchanged.

Non-goals:
- do not claim full controller or hardware certification;
- do not add diagonal stick movement, vibration, rebinding, or a second combat rules path;
- do not make controller focus auto-select an irreversible action;
- do not redesign the battle shell or add visible instruction panels.

## Battle Board Cursor Live Context Coalescing

id: `accessibility-battle-board-cursor-live-context-coalescing-10184`

Status: complete.

Selected Phase 6 accessibility implementation slice. The shipped BattleBoard already owns a visible bounded keyboard/controller cursor and exact existing A/B dispatch, but cursor movement has no dedicated bounded native live context for players using screen readers.

Implementation target:
- author exactly one transparent, non-layout `BattleBoardCursorLive` polite live region and keep its text at or below 320 characters;
- derive current hex coordinates, role, stack side/name/count when occupied, or legal/blocked action plus A/Enter and B/Escape guidance from the existing BattleBoard state and intent/tooltip methods;
- publish only changed keyboard/D-pad destinations after navigation settles, keep held movement final-only and mouse hover/click silent, and publish immediate existing A/B results through generation, battle/session/turn/input-lock/focus/tree ownership guards;
- cancel or clear pending context and guarded results on focus loss, battle or session replacement, turn/input-lock change, modal ownership, and tree exit without changing input timing or action consequences.

Completion criteria:
- focused 1280 and 1920 proof covers player and enemy turns, empty legal and blocked hexes, friendly/enemy/active stacks, boundaries and bounded no-ops, held and single-step physical keyboard/D-pad input, focus and modal transitions, existing A move/target outcomes, B command-focus return, battle/session replacement, and stale-result replacement/clear;
- the authored live surface stays unique, polite, transparent, non-layout, bounded, current, and silent for mouse-only hover/click while the visual cursor, focus cycle, exact board dispatch, rules, RNG, animation, saves, files, cache, settings, routes, session, and battle authority remain exact;
- `battle_controller_board_navigation_smoke`, `accessibility_screen_reader_semantics_report`, battle layout/compatibility, core, editor, repository, Linux release, and fresh Windows/Wine gates pass; native Linux AT-SPI semantics are claimed only when observed, and Wine evidence is limited to packaged behavior/tree validation without native Windows UIA or controller certification.

Non-goals:
- do not change BattleRules, BattleAiRules, action selection or consequences, RNG, battle state, keyboard/controller mappings, repeat timing, mouse hover/click behavior, shared UiAccessibility policy, layout, visible instruction panels, save/schema/version, or Native RMG;
- do not add custom narration, arbitrary rebinding, vibration, diagonal-stick behavior, a second battle dispatch path, or automatic irreversible actions;
- do not claim controller or hardware certification, native Windows UIA, medical/accessibility certification, signing, publication, whole-game readiness, or overall release completion.

Completion evidence:
- the authored BattleShell owns exactly one transparent, non-layout `BattleBoardCursorLive` polite live region, while standalone BattleBoard fixtures fail closed when that scene-owned label is absent;
- focused 1280 and 1920 coverage passes the exact bounded context matrix, real keyboard/D-pad coalescing, mouse and no-op silence, exact guarded A/B results and clear lifecycle, stale replacement, focus/modal/session/battle/turn/input-lock/tree cancellation, and full session, battle, RNG, animation, files, settings, routes, and action authority;
- accessibility semantics, independent 1920/1280/1024 battle-layout gates, Quick Resolve, Withdrawal, manual overwrite, active-play focus, deterministic RNG, battle animation, animation cue catalog, repository validation, Python, diff, and editor gates pass;
- official Linux release export and packaged headless startup pass, but that harness does not expose Boot/MainMenu markers or execute packaged BattleBoard interaction;
- official Windows release export and fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, but no packaged BattleBoard interaction, native Linux AT-SPI observation, native Windows UIA, controller or hardware certification, signing/publication, whole-game readiness, or whole-release completion is claimed.

## Map Editor Responsive Top Bar Containment

id: `ux-map-editor-responsive-top-bar-containment-10184`

Status: completed.

Selected Phase 6 UX implementation slice. The completed responsive ToolRail slice explicitly excluded top-bar responsiveness. The shipped TopBar still places the fixed-minimum header, default longest-item MapPackagePicker, and four fixed-minimum commands in one horizontal row; authored package labels can therefore expand the picker and displace commands independently of the contained ToolRail.

Implementation target:
- keep Header, MapPackagePicker, Load Map, Save Copy, Play Copy, and Menu visible, horizontally contained, non-overlapping, and keyboard/controller reachable inside the live TopPad inner rectangle at 1280 and 1920;
- bound only the selected package presentation while preserving exact full package labels, metadata, native popup items, and current selection through a semantic tooltip or equivalent existing discoverability surface;
- derive any compact sizing or reflow from the live TopBar width and current theme/control minima, and preserve exact resize round trips without changing the existing map or ToolRail minimum widths;
- keep package indexing/loading, Save Copy, Play Copy, Menu, dirty-confirmation, focus, canvas, mouse, session, package, file, save, cache, settings, and route authority unchanged.

Completion criteria:
- focused 1280 and 1920 empty, loaded, dirty, and longest-package-label rows prove every visible TopBar descendant is fully contained in the TopPad inner rectangle with no overlap, hidden command, clipped command text, or horizontal overflow;
- MapPackagePicker retains exact item count/order/text/metadata/selection and full current-label discoverability while bounded presentation survives 1280 -> 1920 -> 1280 resize round trips;
- the existing forward/reverse keyboard/controller focus cycle, native picker ownership, Load Map/Save Copy/Play Copy/Menu activation, dirty-confirmation return focus, canvas geometry, ToolRail containment, mouse behavior, and complete working-copy/package/files/save/cache/settings/routes authority remain exact;
- focused Map Editor dirty-working-copy, package/load/save-copy, command-focus/canvas, accessibility, editor, repository, Linux release, and fresh Windows/Wine gates pass; packaged TopBar interaction is claimed only when the platform harness actually exercises it.

Non-goals:
- do not shrink the map below its existing minimum, widen or redesign the ToolRail, hide commands, replace the native OptionButton popup, change package labels or metadata, or change editor information architecture;
- do not change package indexing/loading, Save Copy, Play Copy, Menu, dirty-confirmation, tool/canvas consequences, shared OverworldMapView, live-region policy, input mappings/timing, save/package schema, or Native RMG;
- do not claim controller or hardware certification, native Linux AT-SPI, native Windows UIA, signing, publication, whole-game readiness, or overall release completion.

Closure evidence:
- focused fresh-XDG headless coverage passed the exact 1280/1920 empty, loaded, dirty, longest-label, and resize-roundtrip TopBar containment contract, including native picker items/metadata/selection, full tooltips, focus, canvas, ToolRail, files, cache, settings, routes, and working-copy authority;
- Map Editor smoke, package load, generated-package Play Copy/Restore Tile/Save Copy, active return, maps-folder browser, accessibility, core, repository, Python, diff, and editor compatibility gates passed;
- official Linux export and packaged headless startup passed, and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup passed. These harnesses did not exercise packaged TopBar interaction, so no packaged TopBar parity, controller, AT-SPI, UIA, native-hardware, signing/publication, whole-game, or whole-release claim is made.

## Keyboard Navigation Layout Settings

The completed Phase 6 accessibility slice makes keyboard navigation handedness a durable device preference instead of forcing one letter-key arrangement.

Target shape:
- Settings offers compact WASD + Arrows, IJKL + Arrows, and Arrows Only navigation layouts;
- selecting a layout immediately updates the authoritative directional UI and hero-movement InputMap actions used by menus, overworld movement, town controls, and battle-board navigation;
- controller D-pad bindings and non-navigation keyboard bindings remain unchanged;
- the selected layout persists in device settings and is restored before the first interactive screen;
- active-play input and packaged-settings validation prove live application and persistence on the existing cross-platform settings path.

Non-goals:
- do not claim full arbitrary key rebinding or controller/hardware certification;
- do not change gameplay movement rules, focus ownership, combat rules, save data, or Native RMG behavior;
- do not add a separate input dispatch path per scene or expand the settings panel with instruction text.

## Keyboard Diagonal Movement Layout Completion

The completed corrective Phase 6 accessibility slice makes the persisted keyboard layout own the complete eight-direction overworld movement surface.

Target shape:
- WASD uses Q/E/Z/C for diagonals and IJKL uses U/O/M/Period for diagonals;
- all eight letter-key directions flow through remappable hero-movement InputMap actions instead of direct keycode branches;
- Numpad 7/9/1/3 remains available for diagonal movement in every layout, including Arrows Only;
- Shift plus a configured diagonal pans the map by the existing three-tile delta without moving the hero;
- cardinal movement, arrow/D-pad focus, controller stick movement, saves, combat, and Native RMG remain unchanged.

Non-goals:
- do not add arbitrary per-key rebinding or diagonal controller-stick changes;
- do not remap non-movement shortcuts or change route/pathing rules;
- do not add settings controls or explanatory panels beyond the existing layout picker.

## Custom Hero Movement Keybindings

The completed Phase 6 accessibility slice extends the shared eight-direction hero movement actions from fixed presets into complete device-persisted keyboard customization.

Target shape:
- Settings exposes all eight hero movement directions in a compact modal binding surface;
- selecting a binding captures one physical key, applies it immediately through the existing InputMap actions, and keeps controller input unchanged;
- assigning an already-used movement key swaps the two directions instead of leaving an ambiguous duplicate;
- Escape, interface-confirmation keys, arrow navigation, and layout-independent diagonal numpad keys remain reserved;
- changing the navigation layout or choosing Reset restores the selected preset and clears custom movement bindings;
- schema-11 device settings preserve custom bindings across normal and packaged reloads without changing expedition saves.

Non-goals:
- do not add arbitrary command-shortcut, mouse-button, modifier-chord, or controller rebinding;
- do not change menu focus navigation, movement/pathing rules, save-game schema, battle behavior, or Native RMG;
- do not replace the existing preset picker or add a full-screen settings dashboard.

## Battle Camera Shake Accessibility

The completed Phase 6 accessibility slice gives players direct control over battle camera motion without forcing reduced animation timing or changing combat behavior.

Target shape:
- device settings persist Full, Reduced, or Off battle shake while older settings default to Full;
- the existing compact Readability row exposes the option without adding another panel or obscuring the scenic menu;
- normal battle playback multiplies camera shake by the selected scale, with Reduced capped at 35 percent and Off producing no camera displacement;
- the existing Reduce Motion and fast/instant playback policies continue to suppress shake completely;
- direct settings reload, exported-PCK persistence, live battle camera playback, compact settings layout, and core regressions pass.

Non-goals:
- do not change combat math, battle event ordering, animation duration, VFX, audio, or authored content;
- do not add camera pan/zoom controls or alter non-battle camera behavior;
- do not change expedition saves, packaging payloads, or Native RMG;
- do not claim final accessibility or release completion.

## Reduced Flash Accessibility

The completed Phase 6 accessibility slice separates photosensitive flash reduction from motion reduction.

Target shape:
- device settings persist Reduce Flashes independently of Reduce Motion and Battle Shake;
- normal movement, timing, camera policy, audio, combat, and authored state animation remain unchanged;
- live battle events use the existing reduced-motion fallback VFX tags instead of strong flash cues;
- spell-specific VFX overlays cannot bypass the reduced-flash preference;
- the compact Readability surface exposes the preference without crowding its existing color and motion controls;
- direct settings reload, exported-PCK persistence, live battle cue playback, menu layout, project parsing, and repository validation pass.

Non-goals:
- do not change combat rules, event order, animation duration, audio, camera shake settings, expedition saves, or Native RMG;
- do not redesign the broader VFX catalog or claim medical certification, final accessibility, or release completion.

## Reduced Repetitive Sound Accessibility

Selected slice: `settings-accessibility-reduced-repetitive-sounds-10184`.

Implementation target:
- persist Reduce Repetitive Sounds as a schema-14 device accessibility preference that defaults off for existing settings;
- expose the preference on the existing compact, scrollable Readability settings surface without obscuring the scenic menu;
- rate-limit repeated interface cues before player creation and reduce the live interface voice budget while the preference is enabled;
- double battle-cue repeat cooldowns and reduce the battle voice budget from eight to four while preserving critical-cue displacement of lower-priority voices;
- keep normal-mode audio policy, Effects volume behavior, combat state, and event timing unchanged.

Completion evidence:
- focused UI-audio and battle-audio runtime proof covers normal mode, reduced repetition, mute behavior, duplicate suppression, reduced voice budgets, and critical-cue admission;
- direct and exported-PCK settings persistence prove schema-14 save, reload, legacy default migration, and Restore Defaults behavior;
- 1280x720 and 1920x1080 Settings-board coverage proves the control remains reachable at 130 percent UI scale;
- project parsing, core systems, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not add new audio assets, change cue mastering, redesign music or ambience, or claim platform audio certification;
- do not change combat math, battle event ordering, animation timing, expedition saves, or authored content;
- do not change Native RMG or claim final accessibility or overall release completion.

## Active-Play Settings Access

id: `ux-active-play-settings-overlay-10184`

Selected Phase 6 implementation slice. Overworld, town, and battle must expose
one shared modal device-settings surface without routing away from the active
session.

Implementation target:
- add a compact scrollable settings overlay to all three active-play shells and a Settings command beside their existing Save/Menu controls;
- expose immediately applied audio levels, battle playback speed, UI scale, camera shake, color cues, high contrast, reduced motion, reduced flashes, and reduced repetitive sounds through the existing SettingsService persistence boundary;
- keep the session, current route, battle state, save schema, and campaign progression unchanged while settings are edited;
- make close/back behavior, keyboard focus, controller focus, and 1280x720/1920x1080 layout usable without allowing commands to leak through the modal;
- synchronize a live battle's current presentation speed when that preference changes from the overlay.

Completion evidence:
- focused runtime coverage opens, edits, persists, closes, and reopens the shared overlay from overworld, town, and battle while proving session state is unchanged;
- active-play keyboard/controller focus and close behavior pass on all three surfaces;
- compact and desktop captures prove controls remain reachable without covering the underlying screen when the overlay is closed;
- core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not duplicate custom movement-key editing, support-bundle export, or Restore Defaults inside active play;
- do not change gameplay rules, save version, campaign progression, Native RMG, or claim overall release completion.

## Native Screen Reader Semantics

Selected slice: `accessibility-native-screen-reader-semantics-10184`.

Implementation target:
- keep Godot 4.6 accessibility support in automatic mode so native AccessKit integration activates when Windows or Linux detects a screen reader or Braille display;
- assign stable human-readable accessibility names and descriptions to static and dynamically created focusable controls without replacing authored semantics;
- mark changing menu, overworld, town, battle, outcome, and save status labels as polite live regions while preserving their current visual text and update timing;
- cover controls added after scene startup and refresh derived semantics when a control becomes visible or receives focus.

Completion evidence:
- focused runtime proof covers authored-semantic preservation, text and node-name fallback, tooltip descriptions, dynamic control insertion, and polite live regions;
- real main-menu and active-play control trees expose non-empty names and descriptions for visible focusable controls while existing keyboard/controller navigation remains green;
- packaged startup, project parsing, core systems, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not add a custom text-to-speech narrator, transmit accessibility data, or require game audio for screen-reader output;
- do not claim NVDA/Orca certification, medical certification, final accessibility, Native RMG changes, or overall release completion.

## Option Control Field Semantics

Selected slice: `accessibility-option-control-field-semantics-10184`.

Implementation target:
- make shared native accessibility expose each `OptionButton` as a stable field such as Presentation Mode, UI Scale, or Save Slot instead of using only the currently selected value as its name;
- include the current selected value in the generated description and refresh that description after user selection without replacing authored names or descriptions;
- apply the behavior automatically to static and dynamically inserted controls across menu, active play, outcome, and editor surfaces.

Completion evidence:
- focused runtime proof covers initial and changed values, stable field identity, authored-semantic preservation, dynamic insertion, and real shipped Settings pickers;
- the real main-menu tree retains complete native semantics and existing keyboard/controller navigation remains green;
- core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not add custom speech, platform-specific screen-reader code, visual layout changes, or gameplay changes;
- do not claim NVDA/Orca certification, final accessibility, Native RMG changes, or overall release completion.

## Confirmed Restore Settings Defaults

Selected slice: `settings-confirmed-restore-defaults-10184`.

Implementation target:
- add one SettingsService operation that replaces all current device settings with the canonical defaults, applies them immediately, persists them, and restores the prior state if persistence fails;
- expose a compact Restore Defaults command on the existing scrollable Settings board;
- require confirmation naming presentation, sound, gameplay, custom movement keys, and readability state before reset;
- refresh all live controls and visual styling after confirmation with clear local feedback.

Completion evidence:
- focused runtime proof covers cancel preserving exact config bytes and current runtime values;
- confirmed reset matches the complete canonical default dictionary, clears custom movement keys, applies runtime scale/palette/audio/navigation/pacing state, and survives a SettingsService reload;
- expedition saves, campaign progression, active session state, support bundle state, and save version 9 remain unchanged;
- 1280x720 and 1920x1080 confirmation captures plus packaged settings, menu/outcome, active-play keyboard, project-parse, core-system, and repository validation pass.

Non-goals:
- do not reset campaign progress, expedition saves, active sessions, support bundles, or editor state;
- do not add per-section resets, import/export, cloud settings, account profiles, or a broad Settings redesign;
- do not change save schema, gameplay balance, Native RMG behavior, or claim overall release completion.

## Manual Save Slot Naming

Selected slice: `ux-manual-save-slot-naming-10184`.

Implementation target:
- add one canonical SaveService operation that writes or clears a bounded player-owned name only on an occupied, structurally valid manual slot;
- preserve the optional name when that same manual slot is overwritten from any active-play shell;
- expose a compact keyboard/controller-reachable name field and command on the existing Saves detail board;
- surface the custom name alongside the fixed Manual Slot identity in browser rows and resume previews.

Completion evidence:
- focused runtime proof covers naming, clearing, invalid and forged target rejection, exact non-name payload preservation, overwrite retention, reload/load continuity, and save version 9;
- autosave, empty and corrupt slots, unrelated manual slots, campaign progression, settings, active session state, and support diagnostics remain unchanged;
- 1280x720 and 1920x1080 Saves-board captures plus overwrite, delete, save/load confidence, menu/outcome, keyboard, core-system, project-parse, and repository validation pass.

Non-goals:
- do not rename autosave files or canonical slot paths, create arbitrary slot counts, move/copy saves, add cloud sync, or add save history;
- do not change session schema normalization, gameplay state, save version, Native RMG behavior, or claim overall release completion.

## Platform Native Installers

The completed Phase 6 packaging slice turns verified release payloads into player-runnable installers on both mandatory platforms.

Target shape:
- Linux release packaging emits a reproducible self-installing `.run` artifact with the verified executable, PCK, native library, manifest, and uninstall path;
- Windows release packaging emits an NSIS setup executable with the same verified payload identity and per-user uninstall support;
- final release metadata and checksums include both installers without weakening existing archive verification;
- installers reject missing or mismatched payload inputs and install only files owned by the release manifest;
- isolated Linux and Wine workflows install, boot the packaged game, uninstall program/launcher files, and preserve external user data.

Non-goals:
- do not claim code signing, storefront/channel publication, system-wide installation, native Windows hardware certification, or overall release completion;
- do not change game/runtime behavior, saves, authored content, or Native RMG.

## Release Source Provenance

Completed slice: `packaging-release-source-provenance-10184`.

Implementation target:
- derive one validated Git source revision for a release build, reject a dirty tracked worktree when deriving it locally, and allow CI to provide the exact revision explicitly;
- embed deterministic `build-info.json` provenance in both Linux and Windows payloads with product, version, platform, source revision, and source-date epoch;
- bind that provenance to the platform manifests and release index, and reject archive, manifest, index, or build-info disagreement during verification;
- install and uninstall the provenance file with the existing per-user archives and runnable installers on both platforms.

Completion evidence:
- focused packaging tests prove reproducible source provenance plus invalid revision, dirty-source, cross-platform mismatch, and payload-tampering rejection;
- isolated Linux and Wine installer lifecycles verify the installed provenance payload and preserve external user data;
- release verification, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not add code signing, certificate acquisition, storefront publication, update channels, or native Windows hardware certification;
- do not choose or change the project license, synthesize third-party legal notices, change gameplay/content/save schemas, touch Native RMG, or claim overall release completion.

## Confirmed Save Slot Deletion

The completed Phase 6 UX slice lets players remove one unwanted or damaged expedition save without manually editing the user-data directory.

Target shape:
- the Saves detail surface exposes a compact Delete Save command only for an occupied autosave or manual slot, whether loadable or corrupt;
- deletion requires explicit confirmation naming the selected slot and, when readable, its expedition;
- the save service resolves autosave/manual paths from trusted slot identity and refuses progression files, unknown slot types, invalid manual slot ids, and arbitrary paths;
- successful deletion invalidates summary caches and refreshes selected/latest save state immediately;
- all unrelated save files, campaign progression, device settings, the active in-memory expedition, and save version 9 remain unchanged.

Non-goals:
- do not add save renaming, cloud synchronization, recycling/undo, bulk deletion, or automatic cleanup;
- do not reset campaign progression, delete every save, change save schema, redesign the Saves board, change Native RMG, or claim overall release completion.

## Confirmed Manual Save Overwrite

Completed slice: `ux-manual-save-overwrite-confirmation-10184`.

Implementation target:
- build one trusted manual-save action from the active session and canonical manual slot id;
- save immediately when the selected manual slot is empty;
- require a shared exact slot-bound confirmation before replacing an occupied or unreadable slot from overworld, town, battle, or scenario outcome;
- keep the pending overwrite bound to its original slot even if selection changes before confirmation;
- preserve explicit validation-only direct-save helpers for established active-play smoke coverage.

Completion evidence:
- focused runtime proof covers empty-slot direct save, occupied cancel/confirm, unreadable-slot confirmation, pending-slot binding, and all four active-play shells;
- cancellation preserves exact save bytes, confirmation changes only the bound manual slot, and unrelated manual slots plus autosave remain unchanged;
- campaign progression, device settings, active expedition state, and save version 9 remain unchanged;
- 1280x720 and 1920x1080 confirmation captures plus broad save, active-play, core-system, project-parse, and repository validation pass.

Non-goals:
- do not add save renaming, cloud synchronization, undo/history, bulk operations, or autosave confirmation;
- do not alter save schema/version, campaign progression, settings, gameplay, balance, or Native RMG behavior;
- do not redesign active-play save rails or claim overall release completion.

## Campaign Arc Restart Workflow

The completed Phase 6 campaign slice lets players deliberately begin one authored arc from a clean Chapter I state without deleting unrelated progress.

Target shape:
- the campaign board exposes a compact Restart Arc command only when the selected arc has recorded attempts, victories, or carryover;
- restart requires explicit confirmation that names the selected campaign and describes the deleted campaign-local state;
- confirmation clears only that campaign's scenario records, carryover bundles, and chapter selection, then persists the normalized profile;
- other campaign states, expedition save files, device settings, selected difficulty, and save version 9 remain unchanged;
- the board refreshes to the selected arc's authored starting chapter with downstream chapters locked again.

Non-goals:
- do not change campaign content, unlock requirements, carryover formulas, difficulty rules, or scenario balance;
- do not delete expedition saves, reset every campaign, redesign the campaign board, change Native RMG, or claim overall release completion.

## Strategic AI Emergency Defense Scan Reuse

The completed Phase 5 strategic-AI performance slice removes repeated defender preparation inside one enemy turn without changing emergency-defense priorities or outcomes.

Target shape:
- one emergency scan context normalizes the available commander candidates once and prepares each commander army probe once;
- recruitment scans reuse those commander/probe payloads across every open spawn point and support town;
- launch-readiness stores the exact per-spawn emergency candidate surface and final launch selection reuses it instead of recomputing the same defense scan;
- town defense remains preferred over resource defense, commander-fit scoring and deterministic tie-breaking remain unchanged, and candidate payloads stay behaviorally identical;
- focused River Pass behavior and scan-work counters, strategic AI baseline, hero-task spawn selection, and core regressions pass.

Non-goals:
- do not tune AI priorities, recruitment strength, commander fit, pathing, or authored content;
- do not broaden the long-run seed matrix or add a report-only timing gate;
- do not change save schema, player-facing event text, combat, or Native RMG.

## Strategic AI Active-Front Probe Reuse

The completed Phase 5 strategic-AI performance slice removes repeated commander army preparation while comparing the same active-front support opportunity from multiple open spawn origins.

Target shape:
- one launch scan normalizes available commander candidates and prepares each commander's immutable army/continuity payload once;
- every open spawn origin keeps its own live route plan, goal distance, score, and deterministic tie-breaking;
- commander fit and adventure-spell projection remain candidate-specific and use current session state;
- focused active-front support behavior and scan-work counters prove identical selected payloads with one prepared probe per commander;
- an exact deterministic long-run replay, strategic AI baseline, and core regressions pass.

Non-goals:
- do not tune strategic priorities, pressure, support readiness, commander fit, pathing, or authored content;
- do not cache route geometry, target selection, or mutable post-launch state across origins or turns;
- do not broaden the long-run matrix or add report-only timing gates;
- do not change save schema, player-facing event text, combat, packaging, or Native RMG.

## Strategic AI Exclusive Frontier Target

The completed strategic AI slice makes live frontier scouting honor the same exclusive-target contract already used by saved scout tasks.

Target shape:
- fallback exploration and frontier-sweep selection reject cells already assigned to another active same-faction host or exclusively reserved by another live task;
- the selecting host may keep its own current assignment and reservation;
- two same-faction hosts with no known strategic objective choose distinct reachable frontier cells and advance without assignment collision churn;
- player-town, hero, resource, encounter, regroup, and battle-pressure selection remain unchanged;
- Native RMG output and supported-input policy remain unchanged.

Non-goals:
- do not claim that every generated topology produces tactical contact within eight weeks;
- do not tune Native RMG object placement or final-map payloads from strategic AI outcomes;
- do not add diagnostic-only progress or treat the long-run matrix as implementation.

## Artifact Set Runtime Target

The current artifact slice closes the gap between the authored two-trinket/set schema and live hero equipment behavior.

Target shape:
- hero artifact state exposes two stable trinket equipment keys while continuing to normalize old saves that contain only the original `trinket` key;
- equipping or auto-equipping trinkets fills an empty compatible slot before replacing existing gear;
- artifact set thresholds carry concrete data-driven bonuses and activate cumulatively from equipped pieces only;
- Wayfarer Compact grants a route-tempo bonus at two pieces and an additional scouting bonus at three pieces;
- active set names, threshold progress, and granted bonuses appear on the existing artifact management/runtime surfaces;
- live movement and scouting hooks consume the set bonuses through `ArtifactRules.aggregate_bonuses`;
- save/resume preserves both trinkets and recomputes the same active set thresholds without a save-version bump.

Non-goals:
- do not activate artifact source/reward tables, rare-resource income, or new random drop rules;
- do not add more artifact sets or claim final artifact balance;
- do not redesign the full town/overworld artifact UI.

## Prism Bastion Root Counter-Control

id: `magic-prism-bastion-root-countercontrol-10184`

Completed Phase 5 magic implementation slice. Closes the source-backed
counterplay gap named in `docs/spell-system-player-balance-audit.md`: Sunvault's
Prism Bastion must answer Thornwake root pressure, not only Harried and
Staggered effects.

Implementation target:
- add Rooted to Prism Bastion's cleanse list and matching temporary immunity list;
- execute the existing Briar Bind root, cleanse it through BattleRules, and apply the resulting ward through the current spell-effect path;
- preserve mana cost, modifiers, duration, spell availability, AI thresholds, unit content, saves, and Native RMG behavior.

Completion evidence:
- focused spell behavior proves Harried and Rooted are both removed and the resulting ward blocks Rooted;
- resistance/counter-control and battle-AI reports prove cleanse/immunity symmetry and retained best-ally casting;
- the unchanged all-live 100-seed four-week faction matrix remains structurally valid and does not regress its current balance metrics;
- magic schema, core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not claim the fast benchmark will exercise every player-available counter-control line or complete faction balance;
- do not change spell damage, modifiers, mana, tier, school access, AI scoring, unit stats, growth, or town economy;
- do not change Native RMG or claim overall release completion.

## Brasshollow Pavis Screen

id: `combat-brasshollow-pavis-screen-10184`

Completed Phase 5 combat-balance implementation slice. Closes the authored unit
behavior gap in `docs/factions-content-bible.md`: Furnace Pavis Teams are heavy
shield teams that protect engines and punish frontal attacks, but currently
have no live ability.

Implementation target:
- give Furnace Pavis Teams a bounded shielding contract that reduces incoming ranged pressure on the Pavis stack and frontal Brace/Reach line-breaker pressure on the Pavis and surviving allied ranged stacks;
- apply the allied screen only while a live same-side Pavis stack owns it, without stacking multiple screens;
- keep live BattleRules, tactical AI estimates, player-facing summaries, the fast benchmark, schema validation, and focused runtime proof in parity;
- preserve unit base stats, recruitment, growth, spells, heroes, towns, saves, scenario rosters, and Native RMG behavior.

Completion evidence:
- focused runtime proof measures lower incoming melee damage for an allied ranged engine while the Pavis survives, no protection after the Pavis is removed, and retained self-shielding against ranged fire;
- the unchanged all-live 100-seed four-week matrix improves the 75.5% week-3 Thornwake/Brasshollow row without increasing 36 outliers, 293.5 severity, 12 rows at or above 65%, or the 75.5% maximum baseline;
- unit ability, focused autoplay, town-development, core systems, project parsing, repository, JSON, and diff validation pass.

Non-goals:
- do not tune unrelated unit stats, growth, spell behavior, hero policy, town economy, scenario-local encounter rosters, or strategic AI;
- do not add adjacency simulation to the abstract fast benchmark or stack multiple Pavis screens;
- do not change Native RMG or claim final faction balance or overall release completion.

## Veilmourn Mourning Lantern Mark

id: `combat-veilmourn-mourning-lantern-mark-10184`

Completed Phase 5 faction-identity and combat-balance implementation slice. It
closes the authored behavior gap for Mourning Lanterns: the faction bible names
them as Veilmourn's lantern-mark unit, and their live unit record now carries a
bounded veteran-line mark.

Implemented:
- give Mourning Lanterns one Wake-Lantern Mark per battle through the shared Harried contract, draining a struck tier-3-or-higher stack's cohesion for one round;
- keep live BattleRules, tactical AI targeting, player summaries, the fast benchmark, schema validation, and the existing per-instance runtime consequence proof on the same authored fields;
- improve Veilmourn's week-1 and week-2 matchup deficits without changing unit stats, growth, recruitment, town economy, spells, heroes, or scenario-local armies;
- preserve save compatibility and Native RMG behavior.

Completion evidence:
- focused runtime ability proof shows low-tier targets do not consume the mark, AI values an eligible veteran target, the cohesion mark applies once, cannot be reapplied after its battle use is spent, and disappears when the ability is removed;
- the all-live 100-seed four-week matrix improves 36 outliers / 280.5 severity to 35 / 272.5, keeps 12 rows at or above 65% and 75% maximum dominance, and reduces week-1 Embercourt dominance over Veilmourn from 62.5% to 53.5%;
- focused autoplay, town-development, core, project-parse, repository, JSON, Python syntax, and diff validation pass.

Non-goals:
- do not add a second status subsystem or duplicate Harried mechanics;
- do not tune unrelated unit stats, growth, spells, heroes, towns, scenarios, strategic AI, or Native RMG;
- do not claim final faction balance or overall release completion.

## Overworld Hostile Full-Roster Inspection

id: `ux-overworld-hostile-full-roster-inspection-10184`

Completed Phase 5 player-comprehension implementation slice. Exact-known hostile
contacts can contain four live groups, while the detailed selected-contact
surface previously named only three and collapsed the fourth to `+1 group`.

Implementation target:
- expose all four authored hostile groups, including unit names and counts, on the detailed selected-contact inspection surface;
- keep compact contact cues totals-only and preserve fog/hidden-information boundaries;
- update the stale Ghoul Grove visual-smoke expectation to its current 27-troop, four-group authored placement and require the fourth group by name;
- preserve encounter content, combat balance, saves, strategic AI, and Native RMG behavior.

Completion criteria:
- River Pass Ghoul Grove selected-contact inspection names Mudglass Slingers instead of collapsing the stack to `+1 group`, while hover remains a totals-only compact cue;
- the overworld visual smoke passes through its terrain, fog, compact-layout, and hostile-contact checks;
- core systems, project parsing, repository validation, JSON validation, and diff checks pass.

Non-goals:
- do not add a new panel or expand compact map cues;
- do not reveal armies hidden by fog or non-exact encounter policies;
- do not tune encounter armies, rewards, balance, saves, strategic AI, or Native RMG.

## Sunvault Relay-Ladder Identity

id: `combat-sunvault-relay-ladder-identity-10184`

Completed Phase 5 faction-identity and combat-balance implementation slice. The
production Sunvault tier-4 through tier-7 ladder now expresses its source roles
through shared live ability and resistance contracts.

Implementation target:
- give Resonant Choristers a bounded high-tier focused mark, Solar Array Striders data-driven control resistance, Aurora Bastions a passive close-line prism wall, and the Daybreak Colossus prepared-lane artillery pressure;
- use shared live BattleRules/SpellRules, tactical AI, player-summary, and fast-benchmark contracts instead of faction-only combat branches;
- keep week-1 armies exact and improve Sunvault's late progression without increasing the current 35 outliers, 272.5 severity, 12 rows at or above 65%, or 75% maximum dominance;
- preserve HP, attack, defense, damage, speed, initiative, growth, recruitment, town economy, spells, heroes, saves, scenarios, strategic AI, and Native RMG behavior.

Completion criteria:
- all four high-tier Sunvault roles produce focused live runtime consequences, with the three active abilities retaining player-readable summaries;
- the unchanged all-live 100-seed four-week matrix keeps zero structural failures, leaves week 1 exact, and does not regress any aggregate balance baseline;
- focused ability, battle autoplay, town-development, core, project-parse, repository, JSON, Python syntax, and diff validation pass.

Completion evidence:
- Calibration Cant, 15% array control resistance, Aurora Facet Wall, and Daybreak Firing Solution pass focused live consequence and player-summary proof across 88 authored ability instances;
- the 100-seed all-live matrix leaves week 1 exact, keeps 35 outliers and 12 severe rows, and improves severity `272.5 -> 264.0`, maximum dominance `75.0% -> 74.5%`, and week-4 Embercourt/Sunvault `75% -> 71%`;
- focused ability/resistance, battle autoplay, balance regression, town development, core systems, project parse, repository, JSON, Python syntax, and diff validation pass. The matrix honestly remains `needs_tuning`.

Non-goals:
- do not change Sunvault tier-1 through tier-3 units or duplicate spell/status systems;
- do not tune raw unit stats, growth, costs, buildings, spells, heroes, scenarios, or benchmark thresholds;
- do not change strategic AI or Native RMG, or claim final faction balance or overall release completion.

## Embercourt Charter-Ladder Identity

id: `combat-embercourt-charter-ladder-identity-10184`

Completed Phase 5 faction-identity and combat-balance implementation slice. The
production Embercourt tier-4 through tier-7 ladder now expresses formation
enforcement, beacon support, supported shock, and retaliation anchoring through
shared live ability contracts.

Implementation target:
- give Ash-Oath Bailiffs a bounded formation-enforcement role, Beacon Lectors a compact-line support role, Sluicefire Lindworms supported shock pressure, and the Charter Colossus a retaliation anchor;
- use shared live BattleRules, tactical AI, player-summary, and fast-benchmark contracts rather than faction-only combat branches;
- keep week-1 armies exact and do not increase the current 35 outliers, 264.0 severity, 12 rows at or above 65%, or 74.5% maximum dominance;
- preserve raw unit stats, growth, recruitment, town economy, spells, heroes, saves, scenarios, strategic AI, and Native RMG behavior.

Completion criteria:
- all four high-tier Embercourt roles produce focused live runtime consequences and player-readable summaries;
- the unchanged all-live 100-seed four-week matrix keeps zero structural failures, leaves week 1 exact, and does not regress any aggregate balance baseline;
- focused ability, battle autoplay, town-development, core, project-parse, repository, JSON, Python syntax, and diff validation pass.

Completion evidence:
- Ash-Writ Formation, Beacon Lane Citation, Sluicefire Commitment, and Charter Lock pass focused live consequence, tactical-AI trigger, one-use/tier-gate, and player-summary proof across all 92 authored ability instances;
- the 100-seed all-live matrix leaves week 1 exact, improves outliers `35 -> 33` and severity `264.0 -> 262.5`, keeps 12 severe rows and 74.5% maximum dominance, and lowers maximum side bias `3.8 -> 3.07`;
- focused ability, battle autoplay, balance regression, town development, core systems, project parse, repository, JSON, Python syntax, and diff validation pass. The matrix honestly remains `needs_tuning`.

Non-goals:
- do not change Embercourt tier-1 through tier-3 units or add faction-only combat code;
- do not tune raw unit stats, growth, costs, buildings, spells, heroes, scenarios, benchmark thresholds, or strategic AI;
- do not change Native RMG or claim final faction balance or overall release completion.

## Thornwake Highroot Capstone Identity

id: `combat-thornwake-highroot-capstone-identity-10184`

Completed Phase 5 faction-identity and combat-balance implementation slice. The
production Thornwake tier-6 Graft Matriarchs and tier-7 Worldroot Bastion now
express late backline bramble pressure and a rooted attrition wall through
shared live ability contracts.

Implementation target:
- give Graft Matriarchs a prepared graft salvo that rewards existing bramble pressure and Worldroot Bastion a passive ranged-attrition root rampart;
- use shared live BattleRules, tactical AI, player-summary, and fast-benchmark contracts rather than faction-only combat branches;
- keep week-1 armies exact and do not increase the current 33 outliers, 262.5 severity, 12 rows at or above 65%, 74.5% maximum dominance, or 3.07 maximum side bias;
- preserve raw unit stats, growth, recruitment, town economy, spells, heroes, saves, scenarios, strategic AI, and Native RMG behavior.

Completion criteria:
- both high-tier Thornwake units produce focused live runtime consequences and player-readable summaries for all authored abilities;
- the unchanged all-live 100-seed four-week matrix keeps zero structural failures, leaves week 1 exact, and does not regress any aggregate balance baseline;
- focused ability, battle autoplay, town-development, core, project-parse, repository, JSON, Python syntax, and diff validation pass.

Completion evidence:
- Highroot Graft Salvo measures a `1.01` open-lane modifier and retains stronger rooted/disrupted payoff, while Worldroot Rampart measures `0.97` incoming ranged damage; both names are present in player summaries and all 94 authored ability instances pass focused live consequence proof;
- the accepted 100-seed all-live pair and week summaries remain exact at 33 outliers / 262.5 severity / 12 severe rows / 74.5% maximum dominance / 3.07 maximum side bias with zero structural failures and unchanged week 1;
- focused ability, battle autoplay, balance regression, town development, core systems, project parse, repository, JSON, Python syntax, and diff validation pass. The matrix honestly remains `needs_tuning`.

Non-goals:
- do not change Thornwake tier-1 through tier-5 units or add faction-only combat code;
- do not tune raw unit stats, growth, costs, buildings, spells, heroes, scenarios, benchmark thresholds, or strategic AI;
- do not change Native RMG or claim final faction balance or overall release completion.

## Mireclaw Ferry-Rot Midline Identity

id: `combat-mireclaw-ferry-rot-midline-identity-10184`

Status: completed.

Selected Phase 5 faction-identity and combat-balance implementation slice. The
production Mireclaw tier-4 Ferrychain Lashers and tier-5 Sporewake Chanters have
no authored combat behavior despite explicit lane-pull/pin and rot-support
roles between already implemented lower and upper ladder units.

Implementation target:
- give Ferrychain Lashers cross-lane chain reach and Sporewake Chanters a bounded veteran-line rot chant that weakens retaliation and amplifies wounded-prey pressure;
- use shared live BattleRules, tactical AI, player-summary, and fast-benchmark contracts rather than faction-only combat branches;
- keep week-1 armies exact and do not increase the current 33 outliers, 262.5 severity, 12 rows at or above 65%, 74.5% maximum dominance, or 3.07 maximum side bias;
- preserve raw unit stats, growth, recruitment, town economy, spells, heroes, saves, scenarios, strategic AI, and Native RMG behavior.

Completion criteria:
- both Mireclaw units produce focused live runtime consequences and player-readable summaries for all authored abilities;
- the unchanged all-live 100-seed four-week matrix keeps zero structural failures, leaves week 1 exact, and does not regress any aggregate balance baseline;
- focused ability, battle autoplay, town-development, core, project-parse, repository, JSON, Python syntax, and diff validation pass.

Completion evidence:
- Ferrychain Hookline is a round-two, one-use control lash that uniquely reaches across one broken hex, deals only the engine's minimum control damage, pulls a surviving target into adjacent contact, applies the Ferry-Pinned rooted marker for one round, consumes its use, and leaves ordinary adjacent melee legal;
- Sporewake Rot Cant is a round-two, one-use tier-6 veteran-line call that applies one round of cohesion/retaliation pressure and retains its bounded `1.02` wounded-target rider; tactical AI, active previews, role summaries, normalized runtime payloads, and focused probes consume both shared contracts;
- all 96 authored ability instances have focused live consequences and player-visible names, including opening-round rejection and later-round availability for both new families;
- the final 100-seed all-live four-week pair summaries, ordered matchups, week summaries, and outlier rows remain exact at 33 outliers / 262.5 severity / 12 severe rows / 74.5% maximum dominance / 3.07 maximum side bias with zero structural failures;
- focused ability, live battle autoplay, town development, core systems, project parse, repository, JSON, Python syntax, and diff validation pass. The faction matrix honestly remains `needs_tuning`.

Non-goals:
- do not change other Mireclaw units or add faction-only combat code;
- do not tune raw unit stats, growth, costs, buildings, spells, heroes, scenarios, benchmark thresholds, or strategic AI;
- do not change Native RMG or claim final faction balance or overall release completion.

## Thornwake Barkmantle Cohesion Balance

id: `balance-thornwake-barkmantle-cohesion-10184`

Status: completed.

Selected Phase 5 combat-balance implementation slice. The accepted 100-seed
all-live matrix has 33 pair outliers, and Thornwake's week-two T1-T5 package
dominates Embercourt, Mireclaw, Sunvault, and Veilmourn. Component simulations
identify the Barkmantle Screens cohesion hold as broad excess leverage while its
missile mitigation remains a readable unit-role contract.

Implementation target:
- remove the Barkmantle Screens cohesion hold bonus while retaining its ranged mitigation and close-line counterpressure;
- keep the authored unit description, runtime normalization, tactical AI, and player-visible ability summary aligned with the changed contract;
- prove the change with focused ability runtime coverage and the full 100-seed all-live four-week faction matrix.

Completion criteria:
- Barkmantle Screens no longer increases stack cohesion hold, and focused runtime coverage proves its remaining missile-screen and engagement behavior;
- the full matrix has zero structural failures and improves the accepted 33-outlier / 262.5-severity baseline without increasing the 74.5% maximum dominance or 3.07-point side bias;
- unit JSON, focused runtime, core regression, project parse, repository validation, Python syntax, JSON validation, and diff checks pass.

Non-goals:
- do not change Barkmantle raw stats, growth, cost, brace behavior, other Thornwake units, spells, heroes, scenarios, strategic AI, or benchmark thresholds;
- do not change Native RMG or claim final faction balance or overall release completion.

## Embercourt Sluicefire Prepared Breach

id: `combat-embercourt-sluicefire-prepared-breach-10184`

Status: completed.

Selected Phase 5 combat-balance implementation slice. The current 100-seed
all-live matrix has 33 pair outliers / 248.0 excess severity, and Embercourt's
week-four roster dominates Mireclaw, Sunvault, Thornwake, and Veilmourn. The
faction source defines Sluicefire Lindworms as supported narrow-lane shock that
collapses when isolated, but the live Bloodrush contract has only positive
wounded/disrupted-target riders and no clean-target weakness.

Implementation target:
- add a shared Bloodrush prepared-breach contract that applies an authored offensive penalty only when the target is neither wounded nor disrupted;
- make live BattleRules, tactical AI estimates, player summaries, normalization, and the fast benchmark consume the same authored field;
- calibrate only Sluicefire Commitment, preserving its wounded/disrupted payoff, initiative, momentum, raw stats, growth, and defensive retaliation.

Completion criteria:
- focused runtime proof demonstrates lower clean-target offense, unchanged defensive retaliation, and stronger damage through wounded or disrupted targets, with tactical AI and player-readable text aligned;
- the full 100-seed all-live four-week matrix has zero structural failures and improves the accepted 33-outlier / 248.0-severity baseline without increasing 74.5% maximum dominance or 2.80-point maximum side bias;
- ability, autoplay, town-development, core, project-parse, repository, Python syntax, JSON, and diff checks pass.

Non-goals:
- do not change raw unit stats, growth, costs, buildings, spells, heroes, scenarios, strategic AI, save schemas, benchmark thresholds, or other unit abilities;
- do not change Native RMG or claim final faction balance or overall release completion.

## Legacy Scenario Package Conversion

id: `map-package-legacy-scenario-conversion-10184`

Status: completed.

Completed production content-pipeline implementation slice. The native
`MapPackageService::convert_legacy_scenario_record` boundary now converts
validated authored scenario and terrain-layer drafts into typed cross-platform
`.amap` / `.ascenario` documents without writing authored JSON.

Implementation target:
- convert one authored scenario record plus its terrain-layer record into validated typed `MapDocument` and `ScenarioDocument` instances;
- preserve terrain cells, roads, towns, resources, artifacts, encounters, selection, objectives, hooks, enemy factions, start state, and stable hashes without mutating authored JSON;
- fail closed on missing ids, invalid dimensions, ragged maps, malformed terrain cells, or structurally invalid converted documents;
- keep the converter and native capability available in synchronized Linux and Windows GDExtension builds.

Completion criteria:
- focused runtime proof covers exact River Pass terrain/object conversion, typed validation, negative malformed input, package save/load round trips, and unchanged authored source bytes;
- Linux and Windows native extension builds succeed and the existing package API, package browser/load, core, project-parse, repository, JSON, and diff gates pass;
- the implementation is explicitly a prerequisite for editor Save Copy/writeback, not a claim that the player command already exists.

Non-goals:
- do not write `content/scenarios.json`, `content/terrain_layers.json`, campaign progress, or save data;
- do not change Native RMG generation/parity, map-editor layout, scenario content, or claim overall release completion.

## Map Editor Package Save Copy

id: `map-editor-package-save-copy-10184`

Status: completed.

Completed Phase 6 production-tooling implementation slice. The editor now saves
validated package-backed working copies as unique typed package pairs and adopts
the reloaded result as its new clean baseline.

Implementation target:
- add a visible Save Copy command for loaded editor working copies that converts the validated draft and writes a unique `.amap` / `.ascenario` pair without overwriting its source;
- preserve terrain, roads, every object record, scenario contracts, and player slots through native conversion and package reload;
- clean up partial output on failure, adopt the successful copy as the new clean editor baseline, and list it for editor loading without certifying it for skirmish launch;
- keep authored scenario JSON, campaign progress, saves, and the source package byte-for-byte unchanged.

Completion criteria:
- focused runtime proof edits a package-backed working copy, saves two uniquely named copies, reloads and validates each pair, and proves terrain, roads, object topology, scenario/player contracts, dirty-state reset, and non-overwrite behavior;
- authored JSON and source packages remain unchanged, editor-authored copies remain excluded from the skirmish package index, and failed writes leave no partial pair;
- synchronized Linux and Windows native builds plus package-browser, editor, core, project-parse, repository, JSON, and diff gates pass.

Completion evidence:
- focused runtime proof saves `saved-editor-copy` and `saved-editor-copy-2`, preserves 21 exact object records including opaque standalone/town fields and two explicit player slots, and leaves source/authored bytes unchanged;
- failed validation leaves no partial output, editor indexing lists all three package pairs, and the skirmish index lists none;
- Linux and Windows native builds, conversion/package/editor/accessibility/core runtime proofs, project parsing, repository validation, Python/JSON, and diff checks pass; the full editor smoke exits without engine errors.

Non-goals:
- do not write authored JSON, campaign progress, save data, or provide in-place overwrite;
- do not certify editor copies for skirmish launch or change Native RMG generation/parity;
- do not add broad map migration UI or claim overall game completion.

## Cross-Platform Release Candidate Pipeline

id: `packaging-cross-platform-release-candidate-pipeline-10184`

Status: completed.

Selected Phase 6 packaging implementation slice. Local release tooling can
already export, package, verify, install, boot, and uninstall Linux and Windows
payloads, but the repository has no clean-checkout automation that rebuilds both
native release targets from the selected source revision before those payloads
are published.

Implementation target:
- add one deterministic release-candidate driver that verifies prerequisites, rebuilds Linux and Windows release GDExtensions plus native self-tests from the checked-out submodule/source state, and rejects stale or missing outputs;
- run the Linux self-test directly and the Windows self-test under Wine before export/package work can begin;
- export and package both platform payloads through the existing provenance-bound release tool, verify archives/installers, and emit a compact machine-readable result;
- add a clean-checkout GitHub Actions workflow that uses the driver for manual and version-tag release candidates and retains the verified release artifacts.

Completion criteria:
- dry-run and focused unit coverage prove exact command construction, source-revision binding, prerequisite failures, stale-output rejection, and platform symmetry;
- a live local run rebuilds both release libraries and self-tests, passes Linux and Wine self-tests, exports/packages both platforms from one revision, and verifies all archives/installers;
- repository validation, workflow syntax, Python syntax, JSON validation, and diff checks pass.

Completion evidence:
- commit `51485b818aad7632ff01e4bc8e573ae5a1072bb3` completed the clean-source driver end to end for `0.1.0-rc1`: both Release native targets rebuilt, the Linux and Wine self-tests passed, Godot parsed the project, repository validation passed, both platform archives/installers were produced, and a separate verification-only pass accepted all four payloads;
- the focused pipeline suite covers command order, revision/worktree rejection, stale or wrong-architecture outputs, unsafe output roots, noisy packager output, and workflow contract requirements; the workflow uses the same driver from a recursive clean checkout and retains the verified artifact set;
- this completes release-candidate orchestration only. Signing, publication, native Windows hardware certification, and overall game release readiness remain open.

Non-goals:
- do not add code signing, certificate or secret acquisition, storefront/channel publication, automatic public releases, or native Windows hardware certification;
- do not change gameplay, saves, content, combat balance, strategic AI, or Native RMG behavior;
- do not claim overall release completion from one automated release-candidate path.

## Draft Prerelease Channel

id: `packaging-draft-prerelease-channel-10184`

Status: completed.

Selected Phase 6 delivery implementation slice. The clean-source pipeline now
proves and retains both platform releases, but its 30-day workflow artifact is
not a durable release channel and the workflow intentionally cannot create a
release.

Implementation target:
- keep the clean build job read-only and pass its immutable verified artifact to a separate least-privilege delivery job;
- automatically select draft delivery for version-tag pushes and permit manual delivery only when explicitly requested from an existing matching version tag;
- centralize and directly test tag/ref/version delivery selection in one deterministic workflow helper;
- create one draft prerelease bound to the triggering tag and exact source revision, with the verified release index, release-candidate result, archives, and installers attached;
- fail closed before upload when tag/version identity differs or any GitHub release already exists for the tag, and never publish or replace release assets automatically.

Completion criteria:
- focused policy and workflow coverage proves tag pushes select delivery, ordinary manual runs remain artifact-only, manual delivery requires a tag ref, and version/tag mismatches fail;
- the delivery job downloads only the exact build artifact, has the only `contents: write` permission, verifies the release is absent, and invokes `gh release create` with draft, prerelease, existing-tag, and exact-target guards;
- workflow syntax, release-candidate tests, repository validation, Python/JSON validation, and diff checks pass.

Completion evidence:
- four direct policy cases prove matching version-tag delivery, ordinary manual artifact-only behavior, explicit manual tag delivery, branch rejection, and version mismatch rejection;
- the final workflow has one contents-write grant isolated to the dependent delivery job, downloads the exact commit-named artifact, and revalidates candidate/index identities plus all four payload checksums before any GitHub write;
- a read-only live GitHub API probe confirms the release-absence guard recognizes 404 while failing closed on other responses, and focused workflow, repository, YAML, Python, JSON, and diff validation pass;
- no tag or release was created during validation. Draft publication remains an explicit later human decision.

Non-goals:
- do not publish the draft, select a stable/latest channel, overwrite an existing release, acquire signing credentials, sign binaries, or perform native Windows hardware certification;
- do not change gameplay, saves, content, combat balance, strategic AI, or Native RMG behavior;
- do not claim overall release completion from draft-channel integration.

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

## Sunvault Shard Warden Facet Reprisal

id: `combat-sunvault-shard-warden-facet-reprisal-10184`

Completed Phase 6 faction-identity implementation slice. Shard Wardens are
authored as a durable shield line that reflects minor damage; the production
tier-one unit now owns that bounded live role.

Implementation target:
- give Shard Wardens a bounded shielding contract that reduces incoming ranged damage by two percent and returns ten percent of ranged attack damage actually received while the Warden stack survives;
- keep reflected damage exclusive to direct ranged unit attacks, with no return from melee, retaliation, spells, direct health loss, or attacks that destroy the Wardens;
- make live BattleRules, tactical AI estimates, player-facing attack summaries, the fast benchmark, content validation, and focused runtime proof consume the same authored fields;
- preserve unit base stats, growth, costs, recruitment, heroes, spells, towns, saves, scenarios, strategic AI, and Native RMG behavior.

Completion criteria:
- focused runtime proof measures the exact ranged reduction and return, proves the reflected damage can destroy the shooter, and proves all excluded damage paths remain unchanged;
- tactical AI accounts for expected reflected losses and the player attack summary names the return risk before a ranged attack;
- the all-live 100-seed four-week matrix has zero structural failures and does not regress the accepted 28-outlier / 172.0-severity / 68.5-percent maximum-dominance baseline or seven-point side-bias gate;
- ability, autoplay, balance-regression, core, project-parse, repository, Python, JSON, and diff gates pass.

Non-goals:
- do not add allied-array protection, broad Sunvault stat buffs, Mirror Duelist abilities, or spell reflection in this slice;
- do not change Native RMG, save schemas, strategic AI, campaigns, or benchmark thresholds;
- do not claim final Sunvault identity, faction balance, or overall release completion.

## Verified Public Prerelease Promotion

id: `packaging-public-prerelease-promotion-10184`

Completed Phase 6 release-channel implementation slice. Verified Linux and
Windows draft candidates now have a repository-owned, fail-closed path to
public prerelease publication for external alpha testing.

Implementation target:
- add a manual, main-branch-only promotion workflow that publishes one existing verified draft as a public prerelease without rebuilding or replacing assets;
- validate the draft release id, tag, prerelease state, exact tag commit, candidate and release-index schemas, version and source revision, expected seven-asset set, uploaded asset sizes, and all four packaged-payload checksums before publication;
- require an exact tag-bound confirmation string and re-fetch the public release after publication to prove release id, commit, asset ids, names, sizes, and downloaded payload hashes are unchanged;
- keep the workflow least-privilege and leave automatic promotion, stable/latest publication, signing claims, and native Windows certification disabled.

Completion criteria:
- deterministic policy tests reject branch dispatch, malformed or stable-looking versions, wrong confirmation, wrong draft/public state, tag/revision drift, missing/extra/duplicate assets, schema drift, version/revision drift, size drift, and checksum drift;
- the production workflow has one contents-write job, performs no build or upload, uses the shared verifier before and after `gh release edit`, and can only set `draft=false`, `prerelease=true`, and `latest=false`;
- repository, workflow YAML, Python, JSON, and diff gates pass.

Non-goals:
- do not publish a live release during validation or create/replace release assets;
- do not implement stable/latest publication, signing, certificate acquisition, native Windows hardware certification, telemetry, or auto-update;
- do not change gameplay, content, saves, strategic AI, balance, Native RMG, or overall release-completion claims.

## Post-Identity Active Encounter Pressure Repair

id: `balance-post-identity-active-outlier-repair-10184`

Active Phase 6 authored-combat implementation slice. Later faction unit-role
mechanics reopened two high-priority player-advantaged outliers in the shipped
59-encounter breadth gate.

Implementation target:
- strengthen only `glassfen_relay_pickets` and `ninefold_drowned_reliquary_watch` through placement-local army counts;
- retain deterministic player victories while moving both terminal margins below the 90-percent matrix threshold and producing meaningful enemy pressure;
- refresh focused exact roster/outcome contracts for the current live combat rules;
- preserve shared armies, global unit stats and abilities, battle rules, faction benchmark inputs, and Native RMG behavior.

Completion criteria:
- both focused battles complete without stalls or invalid orders as bounded player-advantaged victories at no more than 90-percent terminal margin and more than two enemy damage per round;
- the active 59-encounter breadth gate removes all four current high-priority items without creating a new high-priority contributor;
- focused battle, unit ability, core, project-parse, repository, JSON, and diff validation pass; the active breadth measurement confirms zero high-priority items while its unrelated medium queue remains open.

Non-goals:
- do not clear unrelated medium cohort watches, weaken queue thresholds, or revert shipped faction unit roles;
- do not change shared armies, global unit stats, battle rules, strategic AI, campaigns, saves, rewards, or Native RMG;
- do not claim final encounter balance, final faction balance, or overall release completion.

## Active Medium Encounter Pressure Repair

id: `balance-active-medium-sample-pressure-10184`

Active Phase 6 authored-combat implementation slice. The remaining active
breadth queue contains five concrete sample-pressure failures and two margin
cohorts attributable to six placement-local encounter armies.

Implementation target:
- tune only the Bellwake Mirror Lancers, Ironbridge Ford Reavers, Orevein Bridgeward Levies, Ninefold Basalt Gatehouse, Ninefold Drowned Reliquary, and Stonewake Sluice Band placement-local army counts;
- remove the five sample margin/pacing watches and move the `resonance_relay` and `road` average terminal margins below the active-queue threshold;
- preserve encounter identity, deterministic bounded completion, shared armies, global unit stats and abilities, battle rules, and Native RMG behavior;
- add focused exact roster and battle-outcome contracts for the corrected placements.

Completion criteria:
- all five current sample watches clear with terminal margins below 75 percent and standard or extended pacing;
- `resonance_relay` and `road` average terminal margins are below 70 percent;
- the 59-encounter queue falls from 16 to at most nine medium items, remains at zero high-priority items, and introduces no new sample watch;
- focused battle, faction ability, core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not force-clear the nine outcome-diversity cohort watches or weaken queue thresholds;
- do not change shared armies, global unit stats or abilities, battle rules, strategic AI, campaigns, saves, rewards, or Native RMG;
- do not claim final encounter balance, final faction balance, or overall release completion.

## Active Outcome-Diversity Queue Clear

id: `balance-active-outcome-diversity-clear-10184`

Active Phase 6 authored-combat implementation slice. The remaining eight
active breadth watches are deterministic one-sided outcome cohorts across six
scenarios, the `sporeglass_mend` ability cohort, and player-disadvantaged
matchups.

Implementation target:
- tune only placement-local armies in Daybreak Spire, Glassroad Sundering, Bellwake Wreck Claim, Charter Pyre, Mireford Skirmish, Prismhearth Watch, and Reedbarrow Ferry;
- produce bounded mixed outcomes in all six watched scenario cohorts while one Mireford defeat also diversifies `sporeglass_mend` outcomes;
- produce one deterministic player victory that remains genuinely player-disadvantaged through Reedbarrow composition tuning;
- preserve shared armies, global unit stats and abilities, combat rules, queue thresholds, and Native RMG behavior.

Completion criteria:
- the six watched scenario cohorts, `sporeglass_mend`, and player-disadvantaged cohorts each have primary outcome percentages at or below 90;
- every corrected battle completes in standard or extended pacing with terminal margin below 75 percent and no invalid order;
- the active 59-encounter breadth queue is fully clear with zero medium or high items and a deterministic repeated signature;
- focused battle, faction ability, core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not weaken queue thresholds, relabel matchup bands, or force outcomes through combat-rule changes;
- do not change shared armies, global unit stats or abilities, strategic AI, campaigns, saves, rewards, or Native RMG;
- do not claim final faction balance or overall release completion.

## Strategic AI Raid Movement Path-Plan Reuse

id: `strategic-ai-raid-movement-path-plan-reuse-10184`

Selected Phase 6 runtime-performance slice. Live raid advancement currently
builds a full-map path field from the raid's current tile for every movement
step, then separately builds or reuses goal-origin fields to select that same
step.

Implementation target:
- derive current goal distance, deterministic next tile, and next goal distance from one goal-origin path plan;
- reuse that plan in initial, per-step, and post-move raid advancement instead of building an additional current-origin distance field for every moved tile;
- preserve eight-way traversal, blocked-corner rejection, occupied/resource/terrain approach semantics, movement allowances, target redirects, and deterministic delta-order tie-breaking;
- add focused runtime proof for open goals, blocked approach goals, multi-goal selection, unreachable goals, and live multi-step raid movement work.

Completion criteria:
- focused path fixtures produce the same distance and next-step results through the existing public helpers and the shared path plan;
- a live multi-step raid follows the same route and emits the same movement outcome while loading no per-step current-origin distance fields;
- an exact Medium long-run row preserves its row signature, outcome, event counts, target integrity, and reachability while reducing path-field work and not regressing runtime beyond local variance;
- focused strategic-AI, core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change strategic priorities, target selection, raid speed, topology, passability, encounter placement, combat, faction balance, saves, packaging, or Native RMG;
- do not add a timing-only gate, broaden the paused long-run matrix, or claim strategic-AI, performance, or overall release completion.

## Ninefold Mireclaw Marsh Priority Recovery

id: `strategic-ai-ninefold-mireclaw-resource-priority-10184`

Selected Phase 6 strategic-AI/content defect slice. Ninefold Confluence declares
Bog Drum Crossing and Bogbell Croft as Mireclaw priority targets, but later
economy-breadth nodes displaced Bogbell from the live top resource-pressure set.

Implementation target:
- preserve the authored Ninefold Mireclaw town, outpost, dwelling, and guard-front priorities through scenario-local configuration;
- restore both player-controlled marsh assets to the live top-six resource-pressure set from the authored Mireclaw origin;
- keep the survey-camp town as the chosen top-level pressure target and preserve compact public assignment events;
- strengthen focused evidence with exact priority ranks and score breakdowns for the declared marsh resource targets.

Completion criteria:
- the focused faction-scenario pressure scene passes all Prismhearth, Glassroad, and Ninefold cases;
- Bog Drum Crossing and Bogbell Croft both rank in Ninefold Mireclaw's top six with positive priority and public reasons;
- the Ninefold chosen target remains the Embercourt survey camp and no score fields leak into public events;
- focused Ninefold/strategic-AI, core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change global strategic-AI score coefficients, target kinds, route/pathing rules, faction defaults, save data, combat, packaging, or Native RMG;
- do not weaken the focused assertion, remove later economy nodes, or claim broad strategic-AI or release completion.

## Strategic AI Live Resource Target-View Reuse

id: `strategic-ai-live-resource-target-view-reuse-10184`

Selected Phase 6 runtime-performance slice. Live hero-task resource selection
already owns a scored candidate, but rebuilds the same score breakdown for every
candidate solely to construct its commander role view.

Implementation target:
- let live target selection reuse the candidate's normalized reason codes, public importance, and debug reason when constructing the resource role view;
- preserve the full score-breakdown path for public/report callers that do not provide a precomputed candidate;
- keep node-anchor target identity, labels, controller/site metadata, role proposals, task priorities, reservations, and deterministic selection exact;
- add focused runtime proof that full and reused role views have identical behavior-facing semantics.

Completion criteria:
- focused proof shows full and reused resource role views match on every field consumed by live role/task behavior while the full report API retains its breakdown;
- primary and companion live target-selection cases remain exact;
- Medium ordinal 99 preserves row signature `59262e55`, outcome, 171 activity events, 37 turns, all event counts, integrity, and reachability with no target-assignment or total-runtime regression;
- focused strategic-AI, core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change score coefficients, priorities, target kinds, role semantics, pathing, content, saves, combat, packaging, or Native RMG;
- do not remove the full score breakdown from report callers, add timing-only gates, or claim broad strategic-AI, performance, or release completion.

## Veilmourn Undertow Screen Snare

id: `combat-veilmourn-undertow-screen-snare-10184`

Selected Phase 6 faction-identity and balance slice. Veilmourn's week-two line
loses 32/68 to Brasshollow while Undertow Harpooners' authored Mourning Nets do
not yet exploit the shield formations they are designed to foul.

Implementation target:
- give Undertow Harpooners a bounded ranged damage and tactical-targeting payoff against rigid screens whose shared `shielding` ability explicitly opts into `snare_vulnerable`;
- keep Mourning Nets' existing harry status, duration, momentum, and unlimited-use behavior unchanged;
- make live BattleRules, tactical AI, player ability previews, the fast benchmark, content validation, and focused runtime proof consume the same authored fields;
- leave unshielded targets, melee/retaliation paths, shared unit stats, growth, recruitment, and unrelated abilities unchanged.

Completion criteria:
- focused runtime proof measures the exact vulnerable-screen multiplier and AI priority while proving ordinary shields, unshielded targets, and stripped-ability controls remain unchanged;
- the all-live week-two Brasshollow/Veilmourn row moves materially toward the 45-55 target without creating a new week-two outlier;
- the full 100-seed four-week matrix improves or preserves the accepted 28-outlier / 172.0-severity / 68.5-percent maximum-dominance baseline, five rows at or above 65 percent, and seven-point side-bias gate with zero structural failures;
- the 59-encounter active breadth queue remains clear at zero items, and focused ability, autoplay, core, project-parse, repository, JSON, Python, and diff validation pass.

Non-goals:
- do not hard-code faction ids, matchup ids, or benchmark-only behavior;
- do not change unit base stats, growth, town economy, spells, heroes, shared battle thresholds, strategic AI, campaigns, saves, packaging, or Native RMG;
- do not claim final Veilmourn identity, final faction balance, or overall release completion.

## Strategic AI Role-State Fixture Reconciliation

id: `strategic-ai-role-state-fixture-reconciliation-10184`

Corrective validation slice for stale commander-role report fixtures. The live
full-breakdown resource ranking now places River Signal Post and Glassroad
Watch Relay third, while the report expects second and first respectively and
continues into dependent cases after its first failure.

Implementation target:
- reconcile the exact Signal Post and Glassroad Watch Relay ranks with the current live target surface;
- execute report cases fail-fast so one assertion cannot create unrelated dictionary or continuity errors;
- preserve production target scoring, role proposals, events, pathing, and saves unchanged.

Completion criteria:
- the commander role-state report passes all eight cases and its public leak check;
- a forced first-case failure cannot execute later dependent cases;
- core, project-parse, repository, JSON, and diff validation pass.

Non-goals:
- do not change strategic-AI scores, resource ordering, target choice, role behavior, content, runtime state, saves, packaging, or Native RMG;
- do not claim test maintenance as gameplay implementation progress or broad strategic-AI completion.

## Sunvault Aurora Relay Front

id: `combat-sunvault-aurora-relay-front-10184`

Selected Phase 6 faction-identity and balance slice. Sunvault's tier-six Aurora
Bastion is authored as a heavy close-line defender, but its current Aurora Facet
Wall protects only itself and does not hold the allied ranged relay front.

Implementation target:
- give Aurora Facet Wall a bounded four-percent melee damage screen for allied ranged stacks against attackers with the authored `bloodrush` committed-assault contract while a source Bastion survives;
- preserve the Bastion's personal ranged mitigation and cohesion hold exactly;
- keep melee allies, ranged attacks, retaliation-source rules, spells, direct health loss, dead-source cases, and stacked-source cases exact;
- use the existing shared shielding contract in live BattleRules, tactical AI estimates, player summaries, the fast benchmark, content validation, and focused runtime proof.

Completion criteria:
- focused runtime proof measures the exact additional 0.96 committed-assault modifier and matching tactical-AI estimate while proving ordinary melee, melee allies, ranged attacks, and dead/stacked sources remain exact;
- the all-live 100-seed four-week matrix improves or preserves the accepted 28-outlier / 162.5-severity baseline, keeps maximum dominance at or below 68.5 percent, creates no new row at or above 65 percent, stays inside the seven-point side-bias gate, and has zero structural failures;
- the 59-encounter active breadth queue remains clear at zero items;
- focused ability, autoplay, balance-regression, core, project-parse, repository, JSON, Python, and diff validation pass.

Non-goals:
- do not hard-code faction ids, matchup ids, benchmark-only behavior, week numbers, or army counts;
- do not change unit base stats, growth, recruitment, town economy, spells, heroes, save data, strategic AI, packaging, or Native RMG;
- do not claim final Sunvault identity, final faction balance, or overall release completion.

## Sunvault Prism Adept Refraction Volley

id: `combat-sunvault-prism-adept-refraction-volley-10184`

Status: completed.

Completed Phase 6 faction-identity and balance slice. The retained Sunvault scaffold
authors Refraction Volley through the shared `volley` contract, while the
production Prism Adepts previously shipped without an ability contract despite their
prepared ranged-relay role. Focused screening proved that the stack is usually
deleted before acting and exposed the bible-defined upstream gap: production
Shard Wardens reflected minor damage but did not yet protect their linked array.

Implementation target:
- adopt the retained Refraction Volley authored fields for the production Prism Adepts through existing shared live damage, tactical-AI, summary, benchmark, and validation behavior;
- give living Shard Wardens an authored two-percent incoming ranged-attack screen linked only to production Prism Adepts, using shared shielding behavior and maximum/nonstacking source resolution;
- preserve ordinary ranged distance behavior and require the existing disrupted-target and allied-defending setup conditions for their additional payoff;
- keep melee, spell, direct-damage, dead-source, unlinked-unit, and duplicate-source paths exact;
- validate early Sunvault setup pressure without runtime faction, matchup, week, or army-count checks.

Completion criteria:
- focused runtime proof covers base volley, disrupted-target payoff, allied-defending payoff, melee exclusion, and stripped-ability controls in live rules and tactical-AI estimates;
- focused runtime proof also measures the exact linked 0.98 screen while dead/stripped sources, unlinked ranged units, melee attacks, and duplicate sources remain exact;
- the all-live 100-seed four-week matrix improves at least one accepted early Sunvault outlier without exceeding 28 outliers, 161.0 severity, four rows at or above 65 percent, 68.5 percent maximum dominance, seven side-bias points, or zero structural failures;
- the 59-encounter active breadth queue remains clear at zero items;
- focused ability, autoplay, balance-regression, core, project-parse, repository, JSON, Python, and diff validation pass.

Non-goals:
- do not introduce new ability families or hard-code faction ids, matchup ids, week numbers, or army counts in runtime behavior;
- do not change base stats, growth, recruitment, economy, spells, heroes, saves, strategic AI, packaging, or Native RMG;
- do not claim final Sunvault identity, final faction balance, or overall release completion.

Result:
- production Prism Adepts now own the retained Refraction Volley contract: `1.12` base ranged force, `1.2544` against staggered targets, and `1.176` while an ally holds the line;
- living Shard Wardens apply one maximum/nonstacking `0.98` ranged screen only to linked Prism Adepts, while dead, stripped, unlinked, melee, spell, and direct-damage paths remain outside the contract;
- the all-live 100-seed four-week matrix remains at 28 outliers and four rows at or above 65 percent while severity improves from `161.0` to `158.0`, side bias improves from `4.13` to `4.07`, maximum dominance remains `68.5`, and structural failures remain zero;
- week-one Embercourt/Sunvault improves from `64.5/35.5` to `64/36`; week-two Mireclaw/Sunvault and week-four Brasshollow/Sunvault regress slightly, but aggregate acceptance bounds pass;
- the 59-encounter active breadth queue remains clear with signature `829808c9`; faction balance remains `needs_tuning` and the game remains incomplete.

## Brasshollow Boiler Rivetcaster Pressure Artillery

id: `combat-brasshollow-boiler-rivetcaster-pressure-artillery-10184`

Status: completed.

Selected Phase 6 faction-identity and balance slice. The faction bible defines
Boiler Rivetcasters as short-range pressure artillery with heat buildup and
splash risk, but the production tier-four unit currently ships without an
ability contract. The current week-three Brasshollow/Embercourt row is the
matrix maximum at `31.5/68.5` against Brasshollow.

Implementation target:
- implement an authored Boiler Rivetcaster pressure-artillery contract in live BattleRules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof;
- make successful primary ranged fire create bounded deterministic secondary pressure against a clustered enemy and a visible heat cost for the firing stack;
- preserve ordinary single-target ranged behavior when no valid secondary target exists and keep melee, retaliation, spell, direct-damage, dead-source, and unrelated-unit paths exact;
- screen the authored values against the full all-live matrix without runtime faction, matchup, week, or army-count checks.

Completion criteria:
- focused runtime proof covers primary fire, deterministic clustered-target selection, no-target behavior, heat buildup and recovery, tactical-AI parity, and all excluded paths;
- the player-facing role line and battle events expose both secondary pressure and the firing stack's heat cost;
- the all-live 100-seed four-week matrix improves the week-three Brasshollow/Embercourt row or aggregate severity without exceeding 28 outliers, four rows at or above 65 percent, 68.5 percent maximum dominance, seven side-bias points, or zero structural failures;
- focused ability, autoplay, balance-regression, core, project-parse, repository, JSON, Python, and diff validation pass.

Non-goals:
- do not reuse Debt-Engine Exactors' exclusive overheat ability or change Boiler Rivetcaster base stats, shots, growth, cost, recruitment, or army snapshots;
- do not change spells, heroes, towns, saves, strategic AI, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not claim final Brasshollow identity, final faction balance, or overall release completion.

Result:
- production Boiler Rivetcasters now own Boiler Pressure Volley: each successful ranged attack deals one fragment damage per living Rivetcaster, capped at ten, to one deterministic lowest-health enemy adjacent to the primary target;
- firing applies the shared Overheated status for two rounds with exactly `-1` initiative, does not refresh while active, and recovers on expiry without reusing the Debt-Engine Exactors' exclusive `overheat` ability or defense penalty;
- focused runtime proof passes all `105/105` authored ability instances and proves live/AI target parity, clustered and no-cluster paths, heat/recovery, player role text, battle events, stripped, melee, allied, distant, and unrelated-unit exclusions;
- the all-live 100-seed four-week matrix remains at 28 outliers while excess severity improves from `158.0` to `153.0`, rows at or above 65 percent fall from four to two, maximum dominance improves from `68.5` to `68.0`, side bias remains `4.07`, and structural failures remain zero;
- week-three Brasshollow/Embercourt improves from `31.5/68.5` to `37/63`; week-two Brasshollow/Sunvault and week-four Brasshollow/Embercourt plus Brasshollow/Mireclaw regress, but aggregate acceptance bounds pass;
- the 59-encounter active breadth queue remains clear with signature `829808c9`; faction balance remains `needs_tuning` and the game remains incomplete.

## Embercourt Lantern Sapper Counter-Ambush Flare

id: `combat-embercourt-lantern-sapper-counter-ambush-flare-10184`

Status: completed.

Selected Phase 6 faction-identity and balance slice. The faction bible defines
Lantern Sappers as lane-preparation, reveal, ember-pot, and anti-ambush control,
but the production tier-two unit currently ships without an ability contract.
The initial candidate screen cited week-three Embercourt/Mireclaw at `32/68`,
but production Mireclaw owns neither backstab nor fogwake. That row is retained as
an explicitly invalid causal target rather than credited to this mechanic.

Implementation target:
- implement one authored Lantern Sapper counter-ambush flare contract in live BattleRules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof;
- make a living Sapper expose and bound the payoff from existing authored backstab/fogwake ambush setup through generic ability/status fields, then mark a denied fogwake ambusher for one round with the bible-backed reveal/ember-pot consequence rather than faction or matchup checks;
- preserve ordinary attacks, non-ambush abilities, dead-source cases, duplicate-source resolution, spells, direct damage, saves, and unrelated units exactly;
- screen candidate values against the full all-live matrix and reject broad Embercourt stat or economy tuning.

Completion criteria:
- focused runtime proof measures the exact counter-ambush effect against both backstab and fogwake setup and proves ordinary, dead-source, duplicate-source, stripped-ability, spell, direct-damage, and unrelated-unit exclusions;
- tactical-AI estimates, player-facing role text, battle events, and benchmark behavior consume the same authored contract as live resolution;
- the all-live 100-seed four-week matrix improves at least one actual Embercourt/Veilmourn authored-ambush row or aggregate severity without exceeding 28 outliers, two rows at or above 65 percent, 68.0 percent maximum dominance, seven side-bias points, or zero structural failures;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, or benchmark-only behavior;
- do not change unit base stats, growth, recruitment, town economy, spells, heroes, saves, strategic AI, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not claim final Embercourt identity, final faction balance, or overall release completion.

Result:
- production Lantern Sappers own one generic Counter-Ambush Flare contract; a living source removes only backstab/fogwake bonus damage, prevents Fogbound, and applies one round of Flare-Revealed with `-1` defense and initiative only to a denied fogwake attacker;
- focused runtime proof passes all `106/106` authored ability instances and covers marked and wounded backstab, isolated and lethal fogwake, exact live/AI modifiers and target scores, dead/duplicate/stripped sources, direct damage, unrelated Bloodrush, summaries, and dedicated presentation events;
- the all-live 100-seed four-week matrix remains exactly at 28 outliers / `153.0` severity / two rows at or above 65 percent / `68.0` maximum dominance / `4.07` maximum side bias / zero structural failures;
- against actual backstab/fogwake owner Veilmourn, week one moves from `53.5/46.5` to the `55/45` boundary and week four improves from `48/52` to `48.5/51.5`; week three keeps `38.5/61.5` wins while terminal margin improves from `3.82` to `3.70`;
- every Embercourt/Mireclaw row remains exact, including week three at `32/68`, because Mireclaw has neither countered ability; the earlier criterion was causally invalid and is not claimed as progress;
- the 59-encounter active breadth queue remains clear at signature `829808c9`; autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning` and the game remains incomplete.

## Mireclaw Early Ladder Identity

id: `combat-mireclaw-early-ladder-identity-10184`

Status: completed.

Selected Phase 6 faction-identity and balance slice. The faction bible defines
Reedsnare Kin as surrounding snarers, Mudglass Slingers as ranged blind/setup
harriers, and Bogplate Maulers as resistant bruisers that punish harried targets.
All three production units currently have no ability contract. Week-two
Mireclaw/Sunvault is a real `34.5/65.5` deficit in armies containing this ladder.

Implementation target:
- implement a bounded low-tier setup/payoff chain through content-owned generic contracts in live BattleRules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof;
- make Reedsnare pressure depend on surrounding support, make Mudglass ranged fire create a visible blind/harry setup, and make Bogplate resistance plus payoff consume that authored setup without faction or matchup checks;
- preserve ordinary attacks, unsupported positioning, unrelated statuses and units, spells, direct damage, saves, and army snapshots exactly;
- screen candidate values against the full all-live matrix and reject broad Mireclaw stat, growth, economy, or benchmark tuning.

Completion criteria:
- focused runtime proof covers each trigger and exact dead-source, unsupported-position, melee/ranged, retaliation, spell, direct-damage, stripped-ability, and unrelated-unit exclusions;
- live resolution, tactical-AI estimates and target selection, player-facing summaries, events, and benchmark behavior consume the same authored contracts;
- the all-live 100-seed four-week matrix improves week-two Mireclaw/Sunvault or aggregate severity without exceeding 28 outliers, two rows at or above 65 percent, `68.0` percent maximum dominance, seven side-bias points, or zero structural failures;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, or benchmark-only behavior;
- do not change unit base stats, growth, recruitment, town economy, spells, heroes, saves, strategic AI, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not claim final Mireclaw identity, final faction balance, or overall release completion.

Result:
- Reedsnare Kin now close a one-use veteran snare only when another living allied stack surrounds the target, Mudglass Slingers apply a one-round attack blind to veteran melee targets, and Bogplate Maulers resist one percent of ranged damage and gain four percent melee damage only against the isolated Mireclaw mark;
- shared live rules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof consume the same authored contracts while legacy ability normalization keeps its exact prior shape;
- all `109/109` authored ability instances across 103 units pass focused runtime consequence proof, including unsupported, spent-use, role, tier, stripped-ability, and unrelated-status controls;
- the all-live 100-seed four-week matrix stays within bounds at 28 outliers / `153.5` severity / two rows at or above 65 percent / `67.5` maximum dominance / `3.93` maximum side bias / zero structural failures; week-two Mireclaw/Sunvault remains `34.5/65.5` while terminal margin improves from `7.76` to `7.71`;
- the 59-encounter active breadth queue remains clear at signature `829808c9`; autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning` and the game remains incomplete.

## Embercourt Early Ladder Completion

id: `combat-embercourt-early-ladder-completion-10184`

Status: complete.

Selected Phase 6 faction-identity implementation slice. Fordhook Cadets and
Bargebow Crews are the remaining ability-empty production units in Embercourt's
seven-tier ladder despite explicit crossing-holder and protected heavy-ranged
roles in the faction bible.

Implementation target:
- give Fordhook Cadets bounded crossing reach, bracing, and objective-adjacent retaliation behavior through shared contracts;
- give Bargebow Crews limited-shot heavy ranged pressure that depends on a protected lane or allied screen;
- carry both roles through live rules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof without faction or matchup checks;
- preserve unit base stats, growth, recruitment, economy, spells, heroes, saves, strategic AI, campaigns, packaging, Native RMG, and benchmark thresholds.

Completion criteria:
- both units produce distinct live runtime consequences and player-readable summaries with dead-source, stripped-ability, melee/ranged, spell, direct-damage, retaliation, unsupported-lane, and unrelated-unit controls;
- the all-live 100-seed four-week matrix keeps zero structural failures and does not exceed 28 outliers, `153.5` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or seven side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, or benchmark-only behavior;
- do not change other units or broad combat rules unless a shared source-backed contract is required by these two roles;
- do not claim final Embercourt identity, final faction balance, or overall release completion.

Result:
- Fordhook Cadets now gain half-damage reach only while their side controls a crossing-shaped field objective, and Crossing Brace adds defend cohesion plus a three-percent retaliation payoff only on that held objective without raising their global base cohesion;
- Bargebow Crews now gain a bounded one-percent heavy-shot multiplier only behind an adjacent defending allied screen or from a controlled cover-line or lane-battery objective, while retaining six shots;
- shared live rules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof consume the same authored contracts; optional fields remain absent from legacy normalized abilities so deterministic battle seeds and unrelated encounter outcomes remain exact;
- all `112/112` authored ability instances across 103 units pass focused runtime consequence proof, including unsupported-lane, stripped-ability, role, distance, live-rule, and tactical-AI controls;
- the all-live 100-seed four-week matrix stays within bounds at 28 outliers / `153.5` severity / two rows at or above 65 percent / `67.5` maximum dominance / `3.93` maximum side bias / zero structural failures;
- the 59-encounter active breadth queue remains clear at signature `829808c9`; autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning` and the game remains incomplete.

## Sunvault Mirror Duelist Reposition

id: `combat-sunvault-mirror-duelist-reposition-10184`

Status: complete.

Selected Phase 6 faction-identity implementation slice. Mirror Duelists are the
only ability-empty production unit in Sunvault's seven-tier ladder despite the
faction bible defining them as reposition melee that exploit reflected lanes and
broken timing.

Implementation target:
- give Mirror Duelists bounded reflected-lane reach and a disrupted-target payoff through existing generic live contracts;
- carry the role through live rules, tactical AI, player summaries, the fast benchmark, content validation, and focused runtime proof without faction or matchup checks;
- preserve unit base stats, growth, recruitment, economy, spells, heroes, saves, strategic AI, campaigns, packaging, Native RMG, legacy ability dictionary shape, and benchmark thresholds.

Completion criteria:
- Mirror Duelists produce live objective-gated reposition reach and disrupted-target pressure with unsupported-lane, clean-target, stripped-ability, primary-melee, distance, retaliation, and tactical-AI controls;
- the all-live 100-seed four-week matrix keeps zero structural failures and does not exceed 28 outliers, `153.5` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or seven side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, or benchmark-only behavior;
- do not change other units, broad combat rules, base stats, economy, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not claim final Sunvault identity, final faction balance, or overall release completion.

Result:
- Mirror Duelists now use Reflected-Lane Step for three controlled lens-line objective types at 75 percent damage and Broken-Timing Cut for a one-percent primary-melee payoff plus one momentum against harried or staggered targets;
- the new primary-melee-only field remains optional in normalized ability state, so every legacy Backstab dictionary and unrelated deterministic battle seed retains its prior shape;
- all `114/114` authored ability instances across 103 units pass focused runtime consequence proof, including unsupported objective lanes, clean targets, ranged misuse, retaliation, stripped abilities, and live/tactical-AI parity;
- the all-live 100-seed four-week matrix stays within bounds at 28 outliers / `153.5` severity / two rows at or above 65 percent / `67.5` maximum dominance / `4.0` maximum side bias / zero structural failures;
- the 59-encounter active breadth queue remains clear at signature `829808c9`; autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning` and the game remains incomplete.

## Thornwake Seedcutter Bramble Ground

id: `combat-thornwake-seedcutter-bramble-ground-10184`

Status: completed.

Selected Phase 6 faction-identity implementation slice. Seedcutters are the only
ability-empty production unit in Thornwake's seven-tier ladder despite the
faction bible defining them as low-tier bramble carriers that improve on rooted
ground.

Implementation target:
- give Seedcutters one cohesive objective-held Bramble Stake role that steadies their defense, strengthens a held-ground retaliation, roots its attacker, and improves primary-melee cuts against rooted targets;
- resolve the conditional role from immutable unit content in live rules and tactical AI so inactive ability metadata cannot perturb deterministic battle RNG state;
- carry the role through player summaries, the fast benchmark, content validation, and focused runtime proof without faction or matchup checks while preserving unit base stats, growth, recruitment, economy, saves, campaigns, packaging, Native RMG, and benchmark thresholds.

Completion criteria:
- Seedcutters produce live objective-held bracing, rooted retaliation pressure, and rooted-target primary-melee payoff with unsupported-objective, clean-target, stripped-authored-identity, ranged, retaliation, and tactical-AI controls;
- the all-live 100-seed four-week matrix keeps zero structural failures and does not exceed 28 outliers, `153.5` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or seven side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, or benchmark-only behavior;
- do not change other units, unrelated broad combat rules, base stats, economy, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not claim final Thornwake identity, final faction balance, or overall release completion.

Outcome:
- Seedcutters now own the `bramble_ground` Bramble Stake family: held cover, obstruction, or breach ground grants one extra defending cohesion, a 1.01 retaliation multiplier, a one-round rooted counter, and a 1.01 primary-melee payoff against rooted targets;
- immutable content lookup keeps the ability player-visible and live in rules/AI while omitting inactive metadata from normalized battle state; the active 59-encounter queue therefore remains exactly clear at signature `829808c9` instead of rerolling unsupported Mireford fights;
- all `115/115` authored ability instances across 103 units pass focused runtime consequence proof, including unsupported ground, held retaliation/root, held cohesion, clean/rooted targets, ranged and retaliation exclusions, stripped authored identity, and live/AI parity;
- the all-live 100-seed four-week matrix stays at 28 outliers / `153.5` severity / two rows at or above 65 percent / `67.5` maximum dominance / `4.0` maximum side bias / zero structural failures; autoplay, balance regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`, Bellwake Oars remain ability-empty, and the game remains incomplete.

## Veilmourn Bellwake Oars Fog Screen

id: `combat-veilmourn-bellwake-oars-fog-screen-10184`

Status: complete.

Selected Phase 6 faction-identity implementation slice. Bellwake Oars are the
last ability-empty production unit across all six seven-tier faction ladders,
while the faction bible defines them as evasive screens and scouts that survive
better in fog.

Implementation target:
- give Bellwake Oars one bounded fog-screen survival role on authored `fog_bank` battlefields without adding unconditional durability;
- resolve conditional fog metadata from immutable unit content so non-fog battles retain exact deterministic state while live rules, tactical AI, player summaries, and the fast benchmark consume the same contract;
- preserve unit base stats, growth, recruitment, economy, saves, campaigns, packaging, Native RMG, and benchmark thresholds.

Completion criteria:
- Bellwake Oars take less incoming damage only in a fog bank, with clear-weather, stripped-authored-identity, melee, ranged, retaliation, live-rule, and tactical-AI controls;
- the all-live 100-seed four-week matrix keeps zero structural failures and does not exceed 28 outliers, `153.5` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or seven side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, encounter ids, or benchmark-only behavior;
- do not change other units, base stats, economy, saves, campaigns, packaging, Native RMG, encounter rosters, or benchmark thresholds;
- do not claim final Veilmourn identity, final faction balance, or overall release completion.

Result:
- Bellwake Oars now own Mistwake Screen, a bounded two-percent incoming-damage reduction that activates only on authored `fog_bank` battlefields and covers melee, ranged, and retaliation damage;
- live rules and tactical AI resolve the conditional role from immutable unit content, keeping clear-weather normalized battle state and deterministic RNG unchanged while player summaries expose both active and waiting states;
- focused runtime proof passes all 116 authored ability instances across 103 units, leaving zero ability-empty production units across the six faction ladders;
- the active 59-encounter queue remains clear with signature `829808c9`, and the all-live 100-seed four-week matrix remains exact at 28 outliers / `153.5` severity / two rows at or above 65 percent / `67.5` maximum dominance / `4.0` maximum side bias / zero structural failures;
- autoplay, balance regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`, the unsupported Native RMG exact-state chain remains fail-closed, and overall release completion remains open.

## Embercourt Beacon Lector Readiness Writ

id: `combat-embercourt-beacon-lector-readiness-writ-10184`

Status: completed.

Selected Phase 6 faction-identity and balance implementation slice. Beacon
Lectors are authored as support casters that refresh readiness and steady compact
formations, but their current production behavior only marks an enemy veteran.

Implementation target:
- add one bounded once-per-battle readiness writ that reactively blocks the first listed disruption against one eligible allied melee veteran while a living Lector has not spent it, clears an existing listed disruption after a shot, or holds the response after a shot when no disruption is active yet;
- resolve the new support role from immutable authored content so battles without an eligible allied disruption retain exact normalized state while live rules, tactical AI, player summaries, and the fast benchmark consume the same contract;
- preserve base stats, existing Beacon Lane Citation behavior, economy, saves, campaigns, packaging, Native RMG, encounters, and benchmark thresholds.

Measured revision evidence:
- the first full matrix proved 32 post-status cleanses but none in a Mireclaw pairing, because the one-round setup marks expired before a later Lector shot could clear them; the matrix therefore remained exact at the accepted baseline;
- the same writ must cover both initiative orders by holding one formation-level response after a shot when no eligible disruption is already active. The preparation is consumed only by the next listed status against one eligible allied melee veteran and does not inspect faction, matchup, week, army, or benchmark identity.
- a second causal smoke proved the held response worked only when the Lector fired before the enemy mark. The final bounded contract therefore permits the living Lector to call the same once-per-battle writ reactively when a listed disruption arrives first; a later shot cannot prepare or cleanse again after that use.

Completion criteria:
- exactly one listed disruption is blocked reactively, cleared after a successful ranged attack, or reserved for one later eligible allied melee veteran; only the listed harried/staggered status families can consume the response, with deterministic target selection, spent/dead/stripped-source controls, readable presentation, and tactical-AI valuation;
- the all-live 100-seed four-week matrix has zero structural failures and improves at least one accepted faction-balance metric without worsening outlier count, `153.5` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or seven side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, encounter ids, or benchmark-only behavior;
- do not change other units, base stats, the existing citation mark, economy, saves, campaigns, packaging, Native RMG, encounter rosters, or benchmark thresholds;
- do not claim final Embercourt identity, final faction balance, or overall release completion.

Completion result:
- Beacon Muster now provides one content-owned once-per-battle readiness response: a living unspent Lector can block the first listed disruption against an allied tier-four melee veteran, a successful shot clears an existing listed disruption, or the shot reserves the same response for later;
- readiness-only effect metadata is normalized only on the prepared writ, so battles without Beacon Muster retain exact state shape and the active 59-encounter queue remains clear at signature `829808c9`;
- focused runtime proof passes all `117/117` authored ability instances across 103 units, including immediate, reserved, reactive, once-only, dead, stripped-source, presentation, summary, AI, and immutable-state boundaries;
- the accepted all-live 100-seed four-week matrix improves from 28 to 27 outliers, `153.5` to `153.0` excess severity, and `4.0` to `3.87` maximum side bias while keeping two rows at or above 65 percent, `67.5` percent maximum dominance, and zero structural failures. Week-two Embercourt/Mireclaw moves from `44.5/55.5` to `52/48`;
- autoplay, balance regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`; unsupported Native RMG exact-state generation and overall release completion remain open.

## Embercourt Charter Colossus Retaliation Aura

id: `combat-embercourt-charter-colossus-retaliation-aura-10184`

Status: completed.

Selected Phase 6 faction-identity and balance implementation slice. The Charter
Colossus is authored as a zone anchor that raises retaliation value, but Charter
Lock currently increases only the Colossus stack's own retaliation.

Implementation target:
- extend Charter Lock with one bounded, content-owned aura that raises retaliation damage for another defending allied veteran melee line while a living Colossus anchors the formation;
- resolve the aura from immutable authored content in live rules, tactical AI, player summaries, and the fast benchmark, with exact behavior when the source is dead, absent, or stripped;
- preserve base stats, the Colossus's existing self-brace, economy, saves, campaigns, packaging, Native RMG, encounters, and benchmark thresholds.

Completion criteria:
- focused runtime proof covers eligible allied retaliation, source-self exclusion, non-defending/ranged/low-tier exclusions, dead and stripped-source controls, tactical-AI valuation, and readable active/waiting summaries;
- the all-live 100-seed four-week matrix has zero structural failures and improves at least one accepted faction-balance metric without worsening 27 outliers, `153.0` severity, two rows at or above 65 percent, `67.5` percent maximum dominance, or `3.87` side-bias points;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, encounter ids, or benchmark-only behavior;
- do not change other units, base stats, growth, recruitment, economy, saves, campaigns, packaging, Native RMG, encounter rosters, or benchmark thresholds;
- do not claim final Embercourt identity, final faction balance, or overall release completion.

Measured revision evidence:
- a four-percent aura with a blanket `+1.0` defend preference failed the accepted matrix, holding 27 outliers while worsening excess severity from `153.0` to `153.5` and maximum dominance from `67.5` to `68.0` percent;
- raising retaliation to eight percent proved damage magnitude alone did not change the worst row. A reduced blanket AI preference preserved the maximum but still worsened Embercourt/Veilmourn, so the final decision bonus is limited to allied brace units while the live aura remains available to every eligible veteran melee line;
- no revision inspects factions, opponents, weeks, army counts, encounters, seeds, or benchmark identity.

Completion result:
- Charter Lock now projects an eight-percent retaliation bonus to another defending tier-four-or-higher melee ally while a living Charter Colossus survives; the Colossus does not buff itself, and ranged, low-tier, non-defending, dead-source, absent-source, and stripped-source cases stay unchanged;
- tactical AI values the aura only for an allied brace line, while player summaries expose active and waiting states and the live doctrine summary names the compact retaliation formation;
- focused runtime proof passes all `117/117` authored ability instances across 103 units, including live/AI parity and every scope boundary;
- the accepted all-live 100-seed four-week matrix keeps 27 outliers, two rows at or above 65 percent, `67.5` percent maximum dominance, and zero structural failures while improving excess severity from `153.0` to `152.0` and maximum side bias from `3.87` to `3.73` points;
- the active 59-encounter queue remains clear at signature `829808c9`, and autoplay, balance regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`; unsupported Native RMG exact-state generation and overall release completion remain open.

## Mireclaw Gorefen Ripper Finisher Role

id: `combat-mireclaw-gorefen-ripper-finisher-role-10184`

Status: completed.

Selected Phase 6 faction-identity and balance implementation slice. Production
Gorefen Rippers are specified as fragile elite finishers for wounded or isolated
prey, but their current production ability is a cohesion-bearing missile screen.

Implementation target:
- replace Gorefen Screen with one content-owned Bloodrush contract that loses force against clean prey and gains bounded damage/initiative/momentum against wounded, disrupted, or isolated prey;
- add isolated-prey handling to the shared Bloodrush live rules, tactical AI, player summaries, normalization, focused proof, and fast benchmark without faction or matchup branches;
- make the fast benchmark's reversed ordered rows keep the same seeded faction as initiative-tie owner, consuming the same random draw while removing correlated internal-side ownership from the paired comparison;
- preserve base stats, growth, costs, buildings, army groups, economy, saves, campaigns, packaging, Native RMG, encounters, and benchmark thresholds.

Completion criteria:
- focused runtime proof covers clean, wounded, disrupted, isolated, supported-target, ranged, retaliation, live/AI parity, initiative, momentum, and player-summary behavior;
- production Gorefen Rippers no longer own cohesion or ranged-damage mitigation, and repository validation enforces the finisher contract;
- the corrected paired-tie benchmark shows the finisher against an old-content Gorefen Screen control under the same method before the all-live acceptance matrix is claimed;
- the all-live 100-seed four-week matrix has zero structural failures and improves at least one method-matched Gorefen Screen control metric without worsening 38 outliers, `344.0` severity, 14 rows at or above 65 percent, `79.0` percent maximum dominance, or `1.67` side-bias points; the earlier `30` / `166.5` / five / `69.0` / `1.53` control omitted exact formation isolation and generic Mireclaw initiative parity, while the prior `27` / `152.0` / two / `67.5` / `3.73` baseline also used correlated internal-side tie ownership, so both are retained only as pre-parity history;
- the 59-encounter active breadth queue remains clear and focused ability, autoplay, balance-regression, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not hard-code faction ids, matchup ids, week numbers, army counts, encounter ids, seeds, or benchmark-only combat behavior;
- do not change other units, base stats, growth, recruitment, economy, saves, campaigns, packaging, Native RMG, encounter rosters, or benchmark thresholds;
- do not claim final Mireclaw identity, final faction balance, or overall release completion.

Completion result:
- production Gorefen Rippers now own Gorefen Cull Rush instead of Gorefen Screen: primary melee attacks deal 75 percent damage into intact prey, then gain bounded 1.02 multipliers against prey below the 25-percent execute threshold, disrupted prey, and isolated prey; isolated targeting gains 0.05 AI priority, wounded windows grant one initiative, and a kill grants one momentum;
- shared live and tactical-AI rules, player summaries, normalization, validation, focused proof, and the fast benchmark implement the same content-driven contract while legacy Bloodrush entries retain their existing optional-field shape and behavior;
- the parity-correct method-matched Gorefen Screen control is 38 outliers / `344.0` severity / 14 severe / `79.0` percent maximum dominance / `1.67` side bias / zero structural failures. The accepted 25-percent execute contract is 38 / `332.0` / 13 / `79.0` / `1.60` / zero: severity improves 12 points, one severe row clears, side bias improves 0.07 points, and no control metric regresses;
- focused proof passes all 117 ability instances across 103 units; the corrected-RNG 59-encounter breadth remains clear at repeated signature `829808c9`; autoplay, balance regression, core, editor parse, repository, JSON, Python, and diff gates pass. Faction balance remains `needs_tuning`; unsupported Native RMG exact-state generation and overall release completion remain open.

## Deterministic Battle Damage RNG State Decoupling

id: `battle-deterministic-rng-state-decoupling-10184`

Status: completed.

Selected Phase 6 prerequisite for trustworthy combat balance and save/resume
behavior. The source audit found player and AI attacks assigning
`hash(JSON.stringify(session.battle))` to Godot RNG state, so playback speed,
tactical-briefing state, ability display text, and other inert metadata could
reroll damage.

Implementation target:
- replace full-battle-dictionary hashing with one battle-local, versioned damage RNG stream initialized from the authoritative `combat_seed` and persisted after every real primary or retaliation damage roll;
- resolve and persist a nonzero combat seed once, normalize old in-progress battles that lack RNG fields through one deterministic seed-based fallback, and preserve the same next roll across save/normalize/resume;
- prove that presentation speed, briefing state, dictionary key order, and inert ability metadata do not change damage, while real consecutive player, AI, and retaliation rolls advance the shared stream;
- keep Windows and Linux on the same packaged Godot version and record that cross-engine-version replay would require a future repository-owned RNG algorithm rather than relying on Godot's implementation-detail PCG stream.

Completion criteria:
- player and AI damage paths restore only a previously persisted RNG state and persist the next state immediately after each actual damage draw;
- invalid orders, tactical previews, AI scoring, presentation changes, and save normalization consume no damage draws;
- focused proof covers inert-metadata invariance, consecutive draws, retaliation ordering, player/AI parity, uninterrupted versus restored continuation, and missing-field legacy fallback;
- core/save-resume, focused ability, autoplay combat, active 59-encounter breadth, balance-regression, editor parse, repository, JSON, Python, and diff gates pass, with any deterministic signature movement recorded rather than hidden.

Non-goals:
- do not tune Gorefen or any other unit, faction, encounter, roster, seed, benchmark threshold, economy, campaign, packaging, or Native RMG behavior;
- do not claim exact replay compatibility across different future Godot RNG implementations;
- do not carry pre-fix live balance signatures forward as method-matched evidence after the RNG architecture changes.

Completion result:
- live player and AI damage now share one versioned battle-local stream seeded from the authoritative combat seed, persist state plus roll count after every real damage draw, and validate a seed/state/count integrity guard before restoration;
- invalid actions, previews, AI scoring, presentation state, briefing state, dictionary key order, and inert ability metadata consume no draws or alter outcomes; retaliation consumes the immediate next draw;
- focused proof covers player, AI, ranged, retaliation, mixed action order, save/normalize/resume, legacy missing-field fallback, and malformed/current/future state recovery;
- the post-RNG child requalified all 59 active encounters at clear signature `829808c9`; core, focused ability, autoplay, balance-regression, editor parse, repository, JSON, Python, and diff gates pass. The balance suite retains only the known unsupported Native RMG exact-state warning.

## Post-RNG Active Encounter Breadth Requalification

id: `combat-post-rng-active-breadth-requalification-10184`

Status: completed.

Selected Phase 6 content child required before the deterministic battle RNG
prerequisite can ship. The corrected seed-owned stream intentionally changed the
live deterministic baseline: all 59 active encounter samples complete without
stalls or invalid orders, but the queue reopened with 13 items at repeatable
signature `6446fd0b`.

Implementation target:
- retune only the smallest placement-local enemy-army counts needed to clear post-RNG sample margins, pacing, and scenario/ability-presence cohort watches;
- keep shared encounter definitions, shared army groups, unit stats and abilities, combat seeds, objectives, difficulty labels, RNG rules, and queue thresholds unchanged;
- update the existing focused placement regression fixtures to the new source-backed rosters and post-RNG deterministic outcomes;
- preserve at least one non-victory in the three-sample Bellwake and Mireford cohorts, with Mireford's adjustment also clearing the four-sample Sporeglass presence watch.

Completion criteria:
- all 59 active authored encounters complete with zero stalls and invalid orders, every combat/runtime gate passes, and the queue is clear on a repeated deterministic signature;
- the Prismhearth Relay Pickets matrix outlier and all seven remaining sample margin/pacing watches are removed without new queue items;
- Bellwake, Mireford, and Sporeglass presence cohorts remain below the 100-percent single-outcome watch boundary;
- focused placement regressions, autoplay combat, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not change shared units, abilities, encounters, army groups, seeds, difficulty labels, objectives, benchmark logic or thresholds, economy, campaigns, packaging, or Native RMG;
- do not use runtime branches, retries, seed selection, or report/gate suppression as balance tuning;
- do not claim final encounter balance, Gorefen completion, faction balance, or overall release readiness.

Completion result:
- ten placement-local count changes clear the post-RNG queue while preserving shared units, army groups, encounters, seeds, objectives, difficulty labels, and thresholds: Prismhearth Relay, Glassfen Relay, Ironbridge Reed Totemists, Ninefold Barrow Vault, Mireford Ford and Silt, Reedbarrow Pickets and Chain, River Ghoul Grove, and Bellwake Mirror Lancers;
- all 59 active authored encounters complete with zero stalls or invalid orders; combat-feel, balance-matrix, runtime-consequence, and consequence-matrix gates pass; the queue is empty at repeated signature `829808c9`;
- Bellwake, Mireford, Sporeglass-presence, player-disadvantaged, and scenario cohorts remain mixed without new sample or cohort watches;
- all affected focused regressions plus autoplay combat, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

## Work Selection Gates

Before starting any worker:
1. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`.
2. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`.
3. Confirm or create the selected slice with source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Strategic AI Unreachable Town-Defense Retask

id: `strategic-ai-unreachable-town-defense-retask-10184`

Status: completed.

Selected Phase 6 strategic-AI correctness slice. Town-defense candidate scoring
currently accepts the pathfinder's unreachable sentinel while resource defense
rejects it, and generic unreachable-target repair exempts defense assignments.
That can repeatedly refresh an active raid at `goal_distance=9999` instead of
preserving real pressure.

Implementation target:
- exclude unreachable owned towns before a new defense retask is scored;
- release or retarget an existing town-defense assignment when its route becomes unreachable;
- preserve reachable town defense, overcommit limits, public-safe events, movement, saves, combat, content, and Native RMG behavior.

Completion criteria:
- focused deterministic proof covers both an initially unreachable stabilizing town and a reachable assignment whose route later closes;
- no active raid adopts or preserves `town_defense` with `goal_distance=9999`;
- the existing reachable retask, arrival, overcommit, raid movement, strategic-AI baseline, core, parse, repository, JSON, and diff gates pass.

Non-goals:
- no scoring-coefficient, faction-personality, map-topology, content, economy, combat, save-schema, packaging, or Native RMG changes;
- no long-run matrix accumulation or broad strategic-AI/release completion claim.

Result:
- unreachable Duskfen defense is rejected while the raid preserves reachable Free Company pressure at distance 6;
- a valid Duskfen defense whose route later closes is observed at distance 9999, releases its defense lifecycle, and deterministically retargets to Free Company at distance 6;
- the focused report retains every reachable town/resource defense, arrival, overcommit, stationing, release, battle, and emergency launch case;
- the shared headless harness passes at signature `ba73a1f3` and the strategic baseline passes at `dfa6d3fd`; remaining warning/deferred states are the known generated-map provenance and Medium long-run coverage gaps.

## Player Battle Quick Resolve

id: `battle-player-quick-resolve-command-10184`

Status: completed.

Selected Phase 6 player-facing battle-flow slice. The battle wireframe requires
an `auto/retreat` command lane, but the live shell currently exposes only manual
orders, retreat, and surrender. A deterministic spell-aware player tactical
policy exists only in headless/report code, so players cannot safely resolve a
routine battle through the authoritative live rules.

Implementation target:
- move the bounded player order, spell, target, and fallback policy into a production-owned battle auto-resolve rule;
- make report/headless autoplay delegate to that production policy so live and validation behavior cannot drift;
- add one compact Quick Resolve action and dedicated confirmation dialog to the existing battle action strip;
- route confirmation through live battle RNG, mana, casualties, objectives, rewards, animation snapshot, and terminal result handling; cancellation must not mutate the session.

Completion criteria:
- identical starting sessions resolve to identical terminal battle/session state, surviving armies, mana, rewards, objective state, and outcome;
- player auto-resolution never selects retreat or surrender and fails safely back to a valid live battle on step-limit or invalid-order exhaustion;
- the shell confirmation states permanent casualty, mana, and outcome consequences; cancel is byte-exact/no-mutation and keyboard/controller focus remains usable;
- the existing 59-encounter autoplay breadth remains clear and focused battle, layout, focus, core, parse, repository, JSON, and diff gates pass.

Non-goals:
- no combat balance, AI-score, content, unit, encounter, difficulty, save-schema, RNG-algorithm, strategic-AI, packaging, or Native RMG changes;
- no animated spectated autobattle, mid-resolution cancellation, undo, or automatic player retreat/surrender;
- no broad battle-UX or release-completion claim.

Result:
- `BattleAutoResolveRules` now owns the shared decision, spell validation, target selection, fallback, forbidden-exit guard, and bounded resolution policy used by live Quick Resolve and headless battle interrupts;
- the battle shell adds one compact confirmed command whose dialog names permanent casualty, mana, outcome, and objective consequences; controller B/Back cancels without mutation and restores command focus;
- focused runtime proof resolves two identical Hollow Mire sessions to byte-identical terminal state in four steps, spends mana `16 -> 1`, syncs casualties `15 -> 5`, grants `180` gold and `2` ore, clears the objective, and never chooses retreat or surrender;
- zero-step/no-battle failures are non-mutating, a one-step limit preserves a normalizable live battle, the 59 active encounters remain clear at `829808c9`, and the shared headless harness remains `ba73a1f3`.

## Transactional Cross-Platform Installer Upgrade

id: `packaging-transactional-cross-platform-upgrade-10184`

Status: completed.

Selected Phase 6 release-safety slice. Linux shell, Windows archive, and generated
NSIS installers currently copy directly into the live program directory. A
failed or membership-changing reinstall can therefore leave mixed executable,
PCK, native-library, and sidecar versions.

Implementation target:
- stage the complete new manifest-owned payload beside the live install and verify every bounded path, size, and SHA-256 identity before commit;
- accept an existing install only when its ownership marker and prior bounded release manifest are valid;
- atomically replace the owned program set, delete files owned only by the prior manifest, and restore the prior exact program set after an injected commit failure;
- keep launcher/shortcut publication outside the live commit and preserve Godot saves, settings, generated maps, and logs outside the program directory;
- keep Linux shell, Windows archive, and generated NSIS ownership and recovery semantics matched.

Completion criteria:
- fresh install, same-version reinstall, and sequential A-to-B upgrades install the exact B manifest/build identity with no stale A-only sidecar;
- deterministic pre-commit and commit-failure injection leaves A exact and bootable;
- missing/invalid payloads and nonempty unowned install directories fail closed without mutation;
- user-data sentinels survive upgrade and uninstall, while uninstall removes only owned program and launcher/shortcut files;
- Linux, Wine/Windows archive, generated NSIS, artifact verification, packaged boot, repository, Python, JSON, shell syntax, and diff gates pass.

Non-goals:
- no signing, public release creation/promotion, stable-channel policy, native Windows hardware certification, save schema, gameplay/content/balance, strategic AI, or Native RMG changes;
- no silent adoption or recursive deletion of an unowned directory and no broad release-completion claim.

Result:
- Linux shell, Windows archive/CMD, and generated NSIS installers now verify exact bounded manifest membership before staging, accept only owned prior roots, commit through sibling program directories, remove stale prior-only rows, and restore byte-exact prior program sets for both precommit and after-backup failure injection;
- the Windows archive uses a shipped deterministic BCrypt helper for strict manifest parsing, SHA-256, exact-root verification, bounded copying, and owned removal, avoiding PowerShell and Wine-incompatible batch parsing;
- uninstall refuses unexpected program-root entries, removes only verified owned files and launchers/shortcuts, and preserves external Godot saves, settings, generated maps, and logs;
- the real-export lifecycle passes Linux `.run`, Windows NSIS, and Windows archive/CMD fresh install, idempotent reinstall, rollback, upgrade, packaged boot, and uninstall with all three paths reporting `ok:true`.

## Confirmed Display-Mode Preview And Rollback

id: `settings-confirmed-display-mode-rollback-10184`

Status: complete.

Selected Phase 6 release-safety slice. Main-menu window-mode and resolution
handlers call immediate SettingsService setters, which apply and save before the
player can confirm that the new display remains usable. The same persisted mode
is then reapplied at the next boot.

Implementation target:
- add one SettingsService-owned pending display preview with an exact prior settings/runtime snapshot and a bounded countdown that survives menu focus changes;
- preview mode and resolution together without mutating or saving committed settings, then commit once on Keep or restore the exact prior committed/runtime state on Revert, Escape/controller Back, timeout, menu exit, or save failure;
- keep existing explicit immediate setters for internal fixtures and route only player-facing main-menu mode/resolution changes and the display portion of Restore Defaults through the transaction;
- constrain windowed and borderless runtime sizes to the current monitor usable rectangle while keeping authored 16:9 choices and compositor-owned positioning portable across Linux and Windows;
- expose one compact dedicated confirmation modal whose safe Revert action owns initial focus and whose copy makes the countdown and persistence boundary clear.

Completion criteria:
- preview leaves committed settings and config bytes unchanged until Keep, and Keep persists exactly one normalized candidate that survives reload;
- Revert, Escape/controller Back, timeout, menu exit, a second preview, and injected save failure restore the exact prior committed/runtime presentation state without touching campaign or expedition data;
- windowed/borderless modes never request a size larger than the active monitor usable rectangle and restore defaults cannot bypass confirmation;
- focused service/runtime, main-menu keyboard/controller, packaged settings, repository, parse, JSON, Python, and diff gates pass;
- Linux compositor and Wine/Windows packaged probes exercise preview, Keep, and rollback, while native Windows hardware certification remains explicitly open.

Non-goals:
- no renderer rewrite, arbitrary custom resolutions, multi-monitor preference persistence, gameplay/content/balance, save-schema, packaging/signing, public promotion, Native RMG, or broad release-completion claim.

Completion evidence:
- the committed settings dictionary and `user://config/settings.cfg` stay byte-exact throughout preview, while Keep persists one normalized candidate and survives reload;
- Revert, controller Back, timeout, replacement preview, menu exit, and injected save failure restore the prior runtime mode, borderless flag, window size, position, and screen without touching campaign or expedition state;
- Restore Defaults saves non-display defaults first and routes its display candidate through the same confirmation boundary;
- X11 at a 1280x720 usable screen uniformly clamps an authored 2560x1440 request to 1280x720, and a fresh Wine prefix runs the same preview/Revert/Keep/reload contract from an exported Windows executable and PCK;
- focused transaction, keyboard/controller, menu visual, Restore Defaults, packaged settings, active-play settings, core, editor parse, repository, Python, JSON, and diff gates pass.

## Generated Opening Autosave Completion Persistence

id: `save-generated-opening-autosave-completion-persistence-10184`

Status: complete.

Selected Phase 6 save/runtime correction. The generated-map fast opening-autosave
path writes `session.to_dict()` while the deferred-opening flags still describe
an autosave that has not completed. The live shell clears those flags only after
the write, so the restored payload can repeat the large opening autosave.

Implementation target:
- make the generated opening autosave persist the post-success flag state: deferred opening and briefing intent absent, initial autosave completion true, and ordinary transition-autosave intent absent;
- apply the same post-success state to the live session only after the write succeeds, while a failed write retains pending intent for a later retry;
- preserve the existing fast path, save version, ordinary manual/autosave behavior, generated-map payload contents, and opening handoff status/timing surfaces;
- add focused save/restore proof that the persisted payload and restored session are complete and do not request another generated opening autosave.

Completion criteria:
- a successful fast generated opening autosave persists no deferred-opening intent and `generated_overworld_initial_autosave_completed=true`, then restores with no second opening autosave pending;
- a failed write does not falsely mark completion or erase the live retry intent;
- ordinary runtime autosaves and non-generated sessions remain exact, save version stays unchanged, and generated payload breadth is preserved;
- focused opening-tail/save-resume, core, regression, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no save-version bump, generated-map generation change, Native RMG change, autosave UI redesign, summary-cache rewrite, broad save-format migration, or overall release-completion claim.

Completion evidence:
- the successful fast payload omits all active transition-autosave intent, generated opening pending, and briefing-defer flags, sets initial-autosave completion true, preserves canonical/generated overworld payload breadth, and mirrors the same canonical flags to the live session;
- restore keeps completion true and AppRouter reports no deferred or generated-deferred autosave, so opening the restored session cannot repeat the opening autosave;
- an injected pre-write failure leaves autosave bytes and every live retry flag exact, including completion false, while ordinary authored autosaves remain loadable and free of generated lifecycle flags;
- the focused generated route remains within its budgets at 278 ms first-visible and 488 ms through the deferred autosave tail;
- core, balance regression, ordinary deferred-payload, editor parse, repository, Python, JSON, and diff gates pass; save version remains 9.

## Player Withdrawal Confirmation

id: `battle-player-withdrawal-confirmation-10184`

Status: complete.

Selected Phase 6 player-safety slice. Retreat and Surrender immediately call the
authoritative action resolver from their action-strip buttons. Both commands can
apply permanent casualties, resource/pressure/logistics aftermath, objective
loss, and terminal routing, but their authored consequence surfaces currently
serve only as tooltips.

Implementation target:
- add one compact BattleShell confirmation dialog shared by Retreat and Surrender, populated from the current live action surface and clearly naming the selected irreversible command;
- cancel, Escape, or controller Back must close without session mutation and restore focus to the originating action button;
- confirm must re-read the current action surface, fail closed if the action became unavailable, and otherwise call the existing `_perform_action(action_id)` exactly once;
- preserve BattleRules withdrawal aftermath, combat math, animation snapshot, outcome routing, and Quick Resolve behavior unchanged.

Completion criteria:
- Retreat and Surrender never execute from the first press and their confirmation copy contains the authored live consequence/confirmation boundary;
- cancel is byte-exact and focus-safe for both actions, including controller Back;
- stale/disabled confirmation fails closed without mutation, while valid confirm matches a method-equivalent direct BattleRules control and routes exactly once;
- focused runtime/controller, battle layout, event-animation, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no withdrawal aftermath, AI withdrawal, combat balance/math, Quick Resolve, save schema, battle exit redesign, or overall release-completion change.

Completion evidence:
- first press for both Retreat and Surrender opens a shared compact modal whose body contains the current live summary, consequence, confirmation, route, and save cues; no action or route is attempted before confirm;
- Keep Fighting owns native-dialog focus, Escape/controller Back closes the modal with a byte-exact session snapshot, and focus returns to the exact originating action button;
- confirm re-reads the live action surface: a disabled Surrender is rejected with zero action/route attempts, while valid Retreat and Surrender each match a method-equivalent direct BattleRules result and gameplay payload with exactly one action and one overworld-route attempt;
- the scoped 1280x720 layout gate exits zero with the modal bounded inside the battle composition, and the 23-case event-animation report retains Retreat/Surrender presentation behavior;
- focused runtime, active controller, layout, event-animation, core, editor parse, repository, Python, JSON, and diff gates pass.

## Transactional Cross-Platform Save Commit

id: `save-transactional-cross-platform-commit-10184`

Status: complete.

Selected Phase 6 release-safety slice. The shared raw-dictionary save primitive opens
the live slot with `FileAccess.WRITE`, truncates it, writes once, invalidates the
summary cache, and returns success without a verified flush/readback. Autosaves,
manual slots, generated-opening saves, and progression payloads therefore share a
cross-platform corruption window that can replace the only good player state.

Implementation target:
- write a complete candidate into the destination directory, flush it, check file errors, and verify exact bytes plus a valid JSON dictionary before touching the live slot;
- preserve the prior valid live file as a bounded backup, commit with a Windows- and Linux-safe rename sequence, and restore the exact prior bytes after any precommit or after-backup failure;
- recover deterministic missing/invalid-live plus valid-backup crash states on inspection/load without adopting malformed or unrelated files;
- invalidate summary caches and let runtime callers clear transition/save intent only after the final live file is verified; successful and rolled-back transactions must leave no stale staging artifacts.

Completion criteria:
- injected `precommit` and `after_backup` failures preserve exact old live bytes, summary cache behavior, active session save intent, and a loadable prior slot;
- successful autosave, manual save, generated-opening save, and progression writes reload the intended payload with no temp/backup residue;
- valid-backup recovery handles missing or corrupt live files deterministically, while malformed backup/staging files fail closed;
- focused transaction/recovery, existing generated-opening/manual/summary/save-load/core, Linux packaged, Windows/Wine packaged, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no save schema/version change, cloud synchronization, application close/Alt-F4 autosave, gameplay mutation, Native RMG recovery, public release, signing, or overall release-completion claim.

Completion evidence:
- the shared writer flushes and verifies same-directory candidate byte count, exact text, JSON dictionary root, and final live bytes before returning a path; a valid prior live file is moved to a bounded backup and removed only after verified commit;
- deterministic `precommit` and `after_backup` failures return failure, preserve exact old bytes, loadability, primed summary cache, and active transition/generated-opening intent, and leave no candidate/backup residue after rollback;
- valid live files win over stale artifacts; missing, corrupt, or parseable-but-semantically-invalid live files recover exact bytes only from a destination-valid backup; malformed or `{}` backups fail closed and candidates are never recovery authority;
- successful manual, autosave/generated-opening, and progression paths reload their intended state, clear runtime intent only after commit, retain save version 9, and leave no transaction artifacts;
- focused transaction, manual overwrite/naming, generated-opening, deferred-summary, campaign restart, core, editor parse, repository, Python, JSON, and diff gates pass under isolated user data;
- fresh Linux packaged PCK and fresh Windows packaged Wine probes both execute the full transactional regression successfully, including real FileAccess/DirAccess rename behavior.

## Safe Application Close Autosave

id: `application-safe-close-autosave-10184`

Status: complete.

Selected Phase 6 release-safety slice. No production owner disables SceneTree's
auto-accepted quit behavior or handles `NOTIFICATION_WM_CLOSE_REQUEST`; the Main
Menu Quit button also exits directly. A player can therefore close the window from
an active battle, town, or overworld route and lose all state after the last
autosave even though the now-transactional save path can preserve it safely.

Implementation target:
- make AppRouter the single production application-close owner, disable auto-accepted quit, and route both window close/Alt-F4 and Main Menu Quit through one request;
- when a playable session exists, save its current battle/town/overworld/outcome state through the verified autosave primitive and quit exactly once only after success;
- on save failure, keep the process and exact live session running, retain save intent/prior bytes, log the failure, and show a bounded player-facing error rather than silently exiting;
- allow immediate clean exit when no playable session exists, prevent reentrant double-close/save calls, and leave test-harness explicit exits unaffected.

Completion criteria:
- active-session window close and Main Menu Quit both save the exact current state and attempt one clean quit only after a verified autosave;
- injected save failure attempts no quit, preserves byte-exact active session/prior autosave, and exposes a player-visible failure;
- no-session close quits directly, repeated close while a request is active is idempotent, and explicit test harness exits remain functional;
- focused close lifecycle, battle/town/overworld active-session cases, Main Menu integration, RuntimeIssueLog clean-exit behavior, Linux packaged, Windows/Wine packaged, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no signal/kill -9 recovery, background/cloud save, save schema/version change, shutdown prompt redesign, campaign replay fix, End Turn confirmation, Native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- AppRouter disables `auto_accept_quit`, connects the root Window `close_requested` signal, retains a WM-close notification fallback, and receives Main Menu Quit after pending display preview is reverted;
- active overworld, town, and battle fixtures each commit the exact current gameplay payload, clear transition intent only after success, restore to the same route/state, and record exactly one save plus one suppressed validation quit;
- injected transactional save failure preserves exact prior autosave bytes, summary cache, live session and intent, attempts zero quits, records `safe_quit_autosave_failed`, exposes a visible error, and permits a successful retry;
- no-session close attempts one direct quit, in-progress/completed repeats are idempotent, and an isolated explicit `SceneTree.quit(37)` child exits 37 while removing its RuntimeIssueLog marker;
- real Linux/X11 and fresh packaged Windows/Wine windows both advertise/receive `WM_DELETE_WINDOW`, exit zero after Main Menu readiness, and remove the owned runtime session marker;
- focused lifecycle, core, menu/outcome, editor parse, repository, Python, JSON, and diff gates pass; the focused injected failure intentionally emits one RuntimeIssueLog error while exiting zero.

## Campaign Replay Preserves Cleared Progress

id: `campaign-replay-defeat-preserves-cleared-progress-10184`

Status: completed.

Selected Phase 6 progression-safety slice. Campaign completion recording currently
replaces the whole scenario record with the latest attempt. A defeat after an
already-recorded victory can erase the victory status and exported flags, causing
campaign progress and downstream unlock requirements to regress while the earlier
victory carryover bundle remains inconsistently banked.

Implementation target:
- once a scenario has a recorded victory, a later non-victory replay increments attempts but preserves the exact victory-bearing record, exported flags, and carryover bundle;
- first-ever defeat remains a defeat with no carryover or unlock, and defeat-to-victory upgrades normally;
- a later victory may refresh the banked victory record and carryover through the existing path;
- preserve current campaign profile normalization, save schema/version, outcome copy, and replay launch behavior.

Completion criteria:
- victory-to-defeat keeps victory count, exported flags, carryover, and downstream unlock exact while attempts increments once;
- first defeat does not unlock or bank carryover, defeat-to-victory unlocks, and victory-to-victory refresh remains valid;
- normalized and saved/reloaded campaign progression preserves the transition matrix;
- focused campaign replay, campaign arc/restart/outcome/menu, progression save, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no campaign content/copy redesign, attempt-history UI, scenario balance, End Turn confirmation, save version change, Native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- `CampaignRules.record_session_completion()` deep-copies an existing normalized victory record for later non-victory outcomes and changes only its attempt count; the victory-only carryover writer remains the authority for first and refreshed victories;
- the focused transition matrix proves victory-to-defeat preserves the exact prior victory snapshot except attempts, keeps exported `gate_marshals_broken`, carryover, two-victory progress, completion pointers, and Fen Crown access while the replay session remains defeated;
- first defeat stays locked without carryover, defeat-to-victory unlocks normally, victory-to-victory refreshes its snapshot and bundle, and normalized transactional progression reload is exact at save version 9;
- campaign replayability, Frontier Claims, campaign arc restart, player campaign menu, outcome menu, core systems, editor parse, repository, JSON, Python, and diff gates pass.

## Risk-Gated End Turn Confirmation

id: `overworld-risk-gated-end-turn-confirmation-10184`

Status: completed.

Selected Phase 6 irreversible-command safety slice. The overworld already builds
an authored End Turn warning surface and a core next-day risk forecast, but the
live button consumes neither warning before resolving the enemy turn. A single
press can therefore forfeit movement or an available order and immediately
expose towns, objectives, routes, or the active hero to next-day pressure.

Implementation target:
- factor the existing authoritative End Turn body into one commit path and open a compact confirmation when the live End Turn surface is warned or the current unconsumed core forecast gates the turn;
- first press and cancel leave the exact session unchanged, perform no End Turn/autosave, and restore End Turn focus for keyboard/controller users;
- confirm revalidates the same live day/session/status and warning surface, consumes the one-shot risk forecast only at commit, then calls the existing rules/autosave/resolution path exactly once;
- preserve one-click End Turn when movement is spent and no unconsumed core risk gate is active.

Completion criteria:
- warned first press/cancel and stale confirmation are exact and non-mutating, while valid confirmation matches direct authoritative End Turn state/result with one rules call and one autosave;
- both remaining-movement/available-order and core-risk-gated cases require confirmation, while an exhausted low-risk case remains direct;
- compact 1280x720 layout, keyboard/controller focus, overworld visual/runtime, save, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no OverworldRules turn math, strategic-AI behavior, forecast thresholds, scenario/content balance, save schema/version, campaign progression, native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- `OverworldShell` now inspects the authored End Turn and core risk surfaces without changing session state, opens one compact action-bound dialog for warned turns, and preserves the existing direct path for exhausted low-risk turns;
- pending requests capture exact session/day/status/payload identity; cancel and stale confirmation perform zero rule/autosave calls, while valid confirmation consumes an unshown risk forecast and commits the existing rules/autosave/resolution path once;
- the focused runtime report matches the direct `OverworldRules.end_turn()` result and gameplay state, verifies the raw autosave payload and overworld restore route, and covers movement/order warning, core-risk gate, three stale families, and one-click low-risk behavior at save version 9;
- controller A opens the dialog, Keep Waiting owns native-popup focus, controller Back and Escape cancel byte-exactly and restore End Turn focus; actual 1280x720 size is 696x262;
- full overworld visual, generated-overworld profile, transactional save, core systems, broad headless simulation, editor parse, repository, JSON, Python, and diff gates pass. The visual fixture's stale Ghoul Grove count was aligned with the already-authored 28-troop roster.

## Campaign Completion Persistence Atomicity

id: `campaign-progression-completion-write-failure-atomicity-10184`

Status: completed.

Selected Phase 6 progression durability slice. Campaign completion currently
publishes its new profile and terminal session before the transactional progression
write is known to have committed. A precommit or after-backup failure can therefore
show victory, carryover, and the next chapter in memory while disk remains old;
the terminal session then bypasses later completion evaluation and cannot retry.

Implementation target:
- build a detached campaign-profile candidate, transactionally persist it, and assign the singleton only after a verified nonempty save path;
- return a structured completion result to `ScenarioRules`; on persistence failure restore the exact pre-terminal session and keep the chapter evaluable, with a visible retry message;
- after the failure hook clears, one reevaluation records the terminal result, attempts, carryover, unlock, disk profile, and live profile exactly once;
- preserve first-defeat, skirmish, profile/save schema, and ordinary successful campaign completion behavior.

Completion criteria:
- precommit and after-backup failures preserve exact prior progression bytes/cache/profile, exact pre-terminal campaign session, locks/carryover/attempt counts, and leave no transaction residue;
- clearing the hook and reevaluating succeeds once, publishes the terminal session/profile, persists/reloads exactly, and repeated terminal evaluation does not duplicate attempts;
- first defeat and skirmish completion remain compatible;
- focused atomicity, transactional save, campaign replay/arc/outcome, core, editor parse, repository, Linux/Windows transaction semantics, JSON, Python, and diff gates pass without version changes.

Non-goals:
- no campaign content/copy redesign, cloud saves, save/profile version change, outcome-layout redesign, End Turn work, Native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- `CampaignProgression.record_session_completion()` saves a detached candidate and assigns the singleton only after a nonempty committed path;
- `ScenarioRules` restores the same full pre-terminal session object after persistence failure and returns an in-progress retry message;
- focused precommit and after-backup cases preserve exact prior bytes, cache, live profile, session, locks, attempts, and carryover with no residue, then retry to one persisted/reloaded victory and remain idempotent;
- first defeat, skirmish, campaign replay, core, editor parse, repository, JSON, Python, and diff gates pass without changing save version 9 or profile schema.

## Town Departure End-Turn Copy Integrity

id: `ux-town-departure-end-turn-copy-integrity-10184`

Status: completed.

Selected Phase 6 command-integrity slice. The exhausted-town Leave control claims
to end the turn, while its production handler only prepares the town handoff and
returns to the overworld. This became more misleading after overworld End Turn
gained a real risk confirmation boundary.

Implementation target:
- make `Return to Field` the authoritative town departure label in both the core surface and live cached refresh;
- when movement remains, state the exact remaining movement; when exhausted, say movement is spent and direct the player to choose End Turn after returning to the field;
- preserve ready-response warning priority, exact town-to-overworld route-only behavior, current day/session, and zero departure autosaves.

Completion criteria:
- authoritative and cached surfaces never promise that town departure ends the turn and agree for remaining/exhausted movement;
- exhausted and remaining-movement copy is explicit, response-order priority remains, and controller activation reaches overworld with End Turn available;
- town exit preserves exact day/status/session gameplay state and performs no End Turn/autosave;
- focused town visual/exit/controller, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no automatic town-side End Turn, new modal, turn math, save behavior, town economy, scenario balance, Native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- `TownRules` and the live cached town surface use the exact `Return to Field` label and explicit response-priority, remaining-movement, and exhausted-movement guidance;
- cached refresh rebuilds the full authoritative departure surface, preventing stale tooltip and next-step copy after movement changes;
- focused exit proof preserves the same session, day, status, and movement, routes only to overworld, and records no save or autosave;
- controller activation reaches overworld with the separate End Turn command focusable, and town visual, core, editor parse, repository, JSON, Python, and diff gates pass.

## Transactional Device Settings Persistence

id: `settings-transactional-cross-platform-persistence-10184`

Status: completed.

Selected Phase 6 release-safety slice. Audio, gameplay, accessibility, display-adjacent,
and keybinding settings currently write the live device config in place. Ordinary setters
apply runtime state and report success even when persistence fails, while a malformed
live config has no verified backup recovery on the next launch.

Implementation target:
- commit settings through a same-directory candidate and backup with verified ConfigFile/schema content, Windows-safe rename/rollback, bounded startup recovery, and deterministic precommit/after-backup failure hooks;
- publish settings, runtime audio/presentation/accessibility state, and InputMap changes only after commit, restoring the exact prior dictionary/runtime/config on failure;
- make Main Menu, active-play settings, and hero keybindings surface failure honestly and refresh controls to the committed state.

Completion criteria:
- both injected failure phases preserve exact prior config bytes, settings dictionary, runtime state, InputMap, and leave no transaction residue;
- valid live config wins and cleans stale artifacts; missing or malformed live recovers only a semantically valid backup; invalid backup/candidate is never adopted;
- successful settings and keybinding changes survive reload at settings version 14, while display confirmation and Restore Defaults retain their existing atomic behavior;
- focused service/UI, settings/display/keybinding compatibility, packaged Linux and Windows/Wine, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no new settings, settings layout redesign, cloud/device sync, save/profile schema change, gameplay balance, Native RMG work, public release, signing, or overall release-completion claim.

Completion evidence:
- SettingsService writes a flushed, byte- and schema-verified same-directory candidate, preserves the prior live file as a bounded backup, verifies the committed live file, and rolls back after precommit or after-backup failures;
- startup recovery keeps a valid live config authoritative, restores only a semantically complete backup for missing/corrupt/partial/future-version live state, removes staging candidates without promoting them, and rejects non-regular live paths without mutation;
- failed setters restore the exact committed settings dictionary, runtime display/audio/accessibility state, and serialized managed InputMap, emit a structured failure, and leave no transaction residue;
- Main Menu, active-play settings, and hero keybindings consume the structured result, show bounded failure copy, and refresh from committed values rather than claiming success;
- focused transaction, display confirmation, Restore Defaults, packaged persistence, keybinding, active-play, Main Menu, core, editor parse, repository, JSON, Python, and diff gates pass;
- fresh packaged Linux and Windows/Wine runs execute the full transaction matrix successfully at settings version 14.

## End Turn Autosave Failure Visibility

id: `overworld-end-turn-autosave-failure-surface-10184`

Status: completed.

Selected Phase 6 command-integrity slice. End Turn commits the strategic day before
its autosave. A transactional write failure preserves the prior disk checkpoint but
the live shell currently returns success and keeps normal completion copy, leaving
the player unaware that the advanced day is not durable.

Implementation target:
- preserve the already-committed live turn on autosave failure, but return an honest `saved: false`, `reason: autosave_failed` result while retaining `committed: true`;
- show compact persistent guidance that the turn advanced but was not saved and direct the player to the existing Save action;
- record a bounded runtime issue and let manual Save or safe close persist the advanced state without rerunning End Turn.

Completion criteria:
- precommit and after-backup failures preserve exact prior autosave bytes and transaction cleanliness while advancing live rules exactly once;
- the result and visible shell state distinguish committed-but-unsaved from ordinary success, with one bounded runtime issue;
- clearing the failure hook and using existing manual Save persists/reloads the exact advanced state without a second End Turn;
- ordinary low-risk, warned-confirmation, terminal-resolution, autosave-success, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no rollback of an already-resolved strategic day, automatic retry loop, new save UI, End Turn math/AI/economy changes, save schema change, Native RMG work, publication, or overall release-completion claim.

Completion evidence:
- precommit and after-backup failures leave prior autosave bytes, summary cache, and transaction artifacts exact while the live session matches one direct rules execution;
- the shell returns `ok:false`, `committed:true`, `saved:false`, `reason:autosave_failed`, shows the exact Save-now guidance, and emits one `end_turn_autosave_failed` runtime issue;
- a successful existing manual Save reloads the canonical advanced state without a second End Turn or autosave attempt;
- when enemy resolution leaves a pending battle, failure performs zero routes; manual Save persists the exact battle state and then takes the existing battle route exactly once;
- direct low-risk, warned confirmation, terminal-unavailable, save transaction, controller, core, editor parse, repository, JSON, Python, and diff gates pass at save version 9.

## Destructive Confirmation Safe Cancel Focus

id: `accessibility-destructive-confirmation-safe-cancel-10184`

Status: complete.

Selected Phase 6 accessibility and input-safety slice. Manual overwrite, campaign
restart, save deletion, and Restore Defaults confirmations currently open with the
irreversible accept action focused, so a repeated controller/keyboard accept can
execute the destructive operation before the player deliberately chooses it.

Implementation target:
- label each safe cancel action explicitly (`Keep Save`, `Keep Progress`, or `Keep Settings`) and give it initial native-dialog focus after popup;
- bind controller Back and keyboard Escape to the real cancel button, close without mutation, and restore exact originating-command focus;
- preserve existing destructive copy, compact layout, persistence transactions, and exactly-once confirm handlers.

Completion criteria:
- controller/keyboard opening focuses the safe action in the dialog subwindow for shared manual overwrite and Main Menu restart/delete/default dialogs;
- Back/Escape cancel preserves exact save bytes, campaign profile, settings, active session, and returns focus to the origin command;
- deliberate confirm invokes the existing action exactly once and all prior atomicity/rollback contracts remain green;
- focused manual-save/campaign/delete/settings/controller/layout, core, parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- no destructive-action consequence changes, new modal framework, settings/save/progression schema change, layout redesign, gameplay balance, Native RMG work, publication, or overall release-completion claim.

Completion evidence:
- shared manual overwrite across Overworld, Town, Battle, and Outcome focuses `Keep Save`; Restart Arc, Delete Save, and Restore Defaults focus `Keep Progress`, `Keep Save`, and `Keep Settings` respectively in the native dialog viewport;
- controller Back and physical Escape preserve exact save bytes, campaign profile, settings, and active session state while restoring the exact originating control;
- focused workflows prove deliberate confirmation executes once, dialogs remain compact at 1280x720, and existing persistence/progression/settings consequences remain unchanged;
- controller suites, core regression, editor parse, repository validator, JSON, Python, and diff gates pass.

## Pending-Battle Manual Save Failure Route Safety

id: `overworld-pending-battle-manual-save-failure-route-10184`

Status: complete.

Selected Phase 6 save-and-route safety slice. The overworld manual Save path records a
failed transactional write but still evaluates the pending battle and routes away,
so the player can lose the only chance to persist the newly spawned battle checkpoint.

Implementation target:
- make the overworld manual Save path branch on the actual write result and retain the live pending battle without routing when persistence fails;
- keep bounded visible retry guidance, exact live session and prior slot bytes/cache, and zero transaction residue across both injected failure phases;
- after the hook clears, let one successful existing manual Save persist the exact battle-ready state and take the existing battle route exactly once.

Completion criteria:
- failed empty-slot and occupied-slot writes preserve the pending battle, prior durable bytes/cache, and exact live retry state with zero route attempts;
- successful retry writes the exact canonical battle payload and routes once without a second End Turn or duplicated rule resolution;
- precommit and after-backup failures, direct/manual controls, save transaction, controller, core, editor parse, repository, JSON, Python, and diff gates pass at save version 9.

Non-goals:
- no battle-generation changes, new save UI, automatic retry, save schema change, broader router policy, Native RMG work, publication, or overall release-completion claim.

Completion evidence:
- precommit and after-backup failures across empty and occupied manual slots preserve exact prior bytes, summary cache, live pending battle, and transaction cleanliness while performing zero resolution routes;
- failed writes return an honest `manual_save_failed` result, bounded visible retry guidance, and usable Save focus instead of treating an old loadable slot as a successful overwrite;
- clearing the hook lets one retry persist and reload the canonical battle payload, then records exactly one battle route without another End Turn rule or autosave call;
- End Turn confirmation, save transaction, controller, core, editor parse, repository validator, JSON, Python, and diff gates pass at save version 9.

## Active-Play Return-to-Menu Autosave Failure Safety

id: `active-play-return-to-menu-autosave-failure-safety-10184`

Status: complete.

Selected Phase 6 cross-screen save-and-route safety slice. The active-play Return to
Menu path records a failed forced autosave but still opens Main Menu, while its helper
clears live transition intent before persistence despite SaveService already owning
success-only intent clearing.

Implementation target:
- make active-play Return to Menu return a structured result and keep the current Overworld, Town, Battle, or Outcome shell active when the forced autosave fails;
- preserve exact live session, transition/generated-opening retry flags, prior autosave bytes/cache, and transaction cleanliness while surfacing one bounded runtime issue and visible Save/retry guidance;
- after clearing the failure hook, let one retry persist the exact canonical state and route to Main Menu exactly once.

Completion criteria:
- both injected failure phases fail closed on all four active-play shells with exact state/bytes/cache preservation, no scene route, no residue, visible feedback, and origin focus;
- transition intent is cleared only after verified persistence, generated-opening retry state survives failure, and success performs one save plus one Main Menu route;
- no-session and editor-return controls retain their existing direct routes;
- focused router/shell, save transaction, controller, core, editor parse, repository, JSON, Python, and Linux/Windows-compatible gates pass at save version 9.

Non-goals:
- no new confirmation dialog, save schema, scene redesign, battle-transition policy, Native RMG work, publication, or overall release-completion claim.

Completion evidence:
- Overworld, Town, Battle, and Outcome preserve exact active shell, session, transition/generated-opening flags, prior autosave bytes/cache, and transaction cleanliness across precommit and after-backup failure with zero routes;
- each shell surfaces the structured failure and bounded Save/retry guidance, restores Menu focus, and the router emits exactly one sanitized `active_play_return_autosave_failed` issue;
- clearing the hook lets one retry persist the canonical active-play payload and record one Main Menu route, while no-session and editor-return controls route directly without a save attempt;
- safe-close, transactional save, controller focus, core, editor parse, repository validator, JSON, Python, and diff gates pass at save version 9.

## Campaign Progression Semantic Storage Fail-Closed Safety

id: `campaign-progression-semantic-storage-fail-closed-10184`

Status: completed.

Selected Phase 6 progression data-integrity slice. Save recovery currently accepts any
profile version at or above the local schema and raw loading returns parseable partial
dictionaries even when semantic recovery rejected them. Campaign normalization then
drops unknown fields, and ordinary selection can permanently overwrite the only bytes.

Implementation target:
- classify progression storage as missing, current-valid, recovered, malformed/partial, or unsupported-future before load or write, and refuse to overwrite existing incompatible bytes;
- keep CampaignProgression profile/session state unchanged on blocked selection, launch, restart, or completion while returning structured failures;
- surface one bounded persistent Main Menu warning, disable campaign-mutating actions, and keep Skirmish, Load, Settings, and support export usable.

Completion criteria:
- malformed, partial, wrong-type, and future-version profiles remain byte-exact with unchanged live profile/session across selection, launch, restart, and completion;
- missing first-run, current-valid, and valid-backup recovery paths remain functional without a profile/save-version bump or candidate/backup residue;
- existing replay, restart, completion atomicity, transactional save, menu/controller, core, editor parse, repository, JSON, Python, and packaged Linux/Windows-Wine compatible gates pass.

Non-goals:
- no progression migration from unknown future schemas, destructive repair command, campaign content change, save/profile version bump, Native RMG work, publication, or overall release-completion claim.

Completion evidence:
- SaveService classifies missing, current-valid, recovered, invalid, and future-version progression storage; validates nested campaign-state, record, and carryover shapes; never promotes candidate staging; and never replaces a future live file with an older backup;
- CampaignProgression persists detached candidates before publishing state and returns structured failures for load, selection, launch, restart, save, and completion when storage becomes incompatible, including late invalidation between precheck and write;
- the live Main Menu keeps campaign/chapter browsing local, disables and revalidates campaign mutations with one bounded warning, and leaves Skirmish, Saves, Settings, and support usable;
- the focused regression passes malformed, partial, top-level and nested wrong-type, future-live/current-backup, missing/current/recovered, direct-write, all-mutation, and live-menu cases at profile version 1/save version 9;
- replay, restart, completion atomicity, menu/controller, core, editor parse, repository validator, JSON, Python, and diff gates pass; fresh packaged Linux and Windows/Wine focused probes also pass.

## Battle-Entry Forced-Autosave Failure Route Safety

id: `battle-entry-forced-autosave-failure-route-safety-10184`

Status: completed.

Selected Phase 6 data-integrity and routing slice. AppRouter currently stages battle
state, performs an explicitly required autosave, then changes to the Battle scene even
when the write failed. The prior save remains intact, but the pending encounter and
preceding movement exist only in memory and no failure guidance reaches the player.

Implementation target:
- return a structured result from the battle-entry route and make failed required saves produce zero scene transitions plus one bounded runtime issue;
- keep the exact live pending battle and prior bytes/cache/transaction cleanliness on failure, and surface Save-now retry guidance with Save focus in Overworld;
- reuse the existing successful manual-save resolution path so one verified retry persists the canonical battle and routes exactly once without replaying gameplay.

Completion criteria:
- precommit and after-backup failures preserve exact prior bytes/cache/live pending battle with no candidate/backup residue, one save attempt, one issue, and zero battle routes;
- clearing the hook and using Manual Save persists a loadable canonical battle, performs one route, and does not repeat the action that created the encounter;
- ordinary battle entry plus missing-session, missing-battle, and terminal/outcome redirects retain correct behavior;
- focused routing/save, controller, core, editor, repository, JSON, Python, and packaged Linux/Windows-Wine compatible gates pass at save version 9.

Non-goals:
- no battle rules, combat balance, outcome-transition failure redesign, controller route cursor, save schema/version, Native RMG, publication, or overall release-completion claim.

Completion evidence:
- AppRouter returns structured battle-entry results, restores pre-route game state on failed required saves, emits one sanitized runtime issue, and records zero scene transitions until a durable checkpoint exists;
- Overworld movement, direct encounter, session-resolution, End Turn, and Manual Save paths consume the result without falsely reporting resolution; failures remain visible with Save focus, while successful manual/end-turn/resume routes skip redundant writes;
- precommit and after-backup focused cases preserve exact prior autosave bytes/cache, transaction cleanliness, and full live pending battle, then one actual Manual Save persists the normalized battle and records one route without replaying gameplay;
- ordinary saved entry, missing session, missing payload, terminal redirect, and durable resume controls pass alongside End Turn, active-play return, safe close, transactional save, controller, core, editor, repository, JSON, Python, and diff gates;
- fresh packaged Linux and Windows/Wine focused probes pass at save version 9; only deliberate injected-failure/control diagnostics and a Linux fixture-exit resource warning appear.

## Overworld Controller Right-Stick Route Selection

id: `overworld-controller-right-stick-route-selection-10184`

Status: completed.

Selected Phase 6 controller-accessibility slice. The Overworld accepts only left-stick
axes and converts them directly into hero movement; right-stick input is ignored. A
controller-only player therefore cannot inspect a remote tile, preview a route, or pan
the map before committing movement.

Implementation target:
- add independent right-stick dead-zone, release, direction, and repeat handling that moves a bounded route cursor through the existing selected-tile and route-preview surfaces;
- pan/follow the route cursor without mutating the session, spending movement, or writing a save; B returns selection/camera to the hero and A continues to use the existing primary action exactly once;
- block route-cursor input while drawers, settings, save popups, or confirmations own interaction, preserving left-stick immediate movement and D-pad command focus.

Completion criteria:
- cardinal, opposed-axis, dead-zone/release, repeat, map-boundary, cancel, and primary-confirm cases are deterministic;
- route preview changes selected tile/camera and exposes the existing destination/action surface while exact session/day/movement/save bytes remain unchanged before confirmation;
- left-stick movement, D-pad focus, mouse selection, keyboard movement/pan, drawers, settings, and confirmations retain current behavior;
- focused controller route, active-play focus, route-cache/full/incremental/destination, visual/layout, core, editor, repository, JSON, Python, and Linux/Windows compatible gates pass.

Non-goals:
- no new movement/pathfinding rules, camera renderer redesign, battle/outcome transition changes, save schema/version, balance, Native RMG, publication, or overall release-completion claim.

Completion evidence:
- OverworldShell owns independent right-stick dead-zone/release hysteresis, cardinal selection, repeat timing, map bounds, cursor/camera reset, and modal/debug input guards while reusing the existing selected-tile, route-preview, and primary-action paths;
- preview selection and camera movement preserve exact full session/day/movement and autosave bytes; B cancels to the hero, A commits exactly once, and left-stick movement clears cursor mode only when immediate movement is actually allowed;
- focused coverage passes dead/release/opposed/cardinal/repeat/boundary, accept/cancel/left-stick, and drawer/settings/save-popup/manual-overwrite/end-turn blockers, while live controller A/B, D-pad focus, 1280x720 visual, full/incremental/cached/destination route, core, editor, repository, JSON, Python, and diff gates pass;
- the cached and destination fixtures were independently reproduced stale at committed pre-slice HEAD, then updated test-only to the already-live compact recap contract and rerun green;
- fresh packaged Linux and Windows/Wine focused probes pass at save version 9; Linux reports only two fixture-shutdown signal-disconnect errors and Wine only normal fresh-prefix/X shutdown lines.

## Application Scenario-Outcome Autosave Failure Recovery

id: `application-scenario-outcome-autosave-failure-recovery-10184`

Status: complete.

Selected Phase 6 terminal-state integrity slice. Campaign completion is transactionally
recorded before Outcome routing, but AppRouter ignores failure of the required terminal
autosave. The player reaches Outcome with no warning while Continue can still restore
the preceding in-progress session.

Implementation target:
- return a structured scenario-outcome route result, preserve the terminal live session and exact prior autosave on failure, emit one sanitized issue, and carry one persistent recovery state into ScenarioOutcomeShell;
- show bounded Save Outcome guidance with Save focus, block campaign/skirmish follow-up actions while recovery is pending, and keep Return to Menu/safe-close recovery available;
- make Save Outcome repair the runtime autosave first, then retain its existing selected-manual-slot behavior, clearing the recovery state only after a verified terminal autosave without replaying campaign completion.

Completion criteria:
- precommit and after-backup terminal-route failures preserve exact prior bytes/cache and terminal live/profile state with no transaction residue, one issue, one Outcome route, and visible recovery guidance;
- campaign/skirmish follow-up is blocked until Save Outcome or another canonical save path repairs the terminal autosave; a verified retry reloads with resume target Outcome and does not add completion attempts or replay rules;
- ordinary success, victory/defeat, campaign/skirmish, no-session, in-progress redirect, Return to Menu, and safe-close controls retain correct behavior;
- focused outcome/save/UI, controller, core, editor, repository, JSON, Python, and packaged Linux/Windows-Wine compatible gates pass at save/profile versions 9/1.

Non-goals:
- no campaign result rules, new outcome screen, cloud saves, save/profile version bump, Native RMG, publication, or overall release-completion claim.

Completion evidence:
- precommit and after-backup failures across campaign/skirmish victory/defeat preserve exact prior autosave bytes/cache, terminal live/profile authority, and clean transaction artifacts while emitting one sanitized issue and routing to Outcome once;
- Outcome shows the bounded recovery warning with Save Outcome focus, blocks both presented and direct follow-up actions, and retries the canonical autosave before the existing manual-slot flow without replaying completion;
- stale-session, ordinary success, durable resume, missing/in-progress redirect, dynamic Return, safe close, campaign completion/replay, save transaction, manual overwrite, controller, visual, and core controls pass;
- fresh packaged Linux and Windows/Wine focused runs pass at save version 9 and profile version 1; production project and export presets remain untouched.

## Map Editor Dirty Working-Copy Destructive Transition Safety

id: `map-editor-dirty-working-copy-destructive-transition-safety-10184`

Status: complete.

Selected Phase 6 editor data-safety slice. The shipped Map Editor labels dirty work as
unsaved but currently discards the in-memory working copy without confirmation when the
player opens Main Menu, loads another package, or closes the native window.

Implementation target:
- add one compact exact-action confirmation for dirty Menu, package replacement, and application close, with `Keep Editing` as the initially focused safe cancel and captured target identity;
- add a bounded AppRouter current-scene close-guard handshake so native close waits for the editor decision, while clean editor and ordinary safe-close behavior remain direct;
- cancel must preserve the exact editor working copy, dirty/tool/selection metadata, authored package files, active expedition/save data, and originating focus; confirm performs only the captured transition once.

Completion criteria:
- dirty Menu, package replacement, and native close each open one compact confirmation; controller Back/Escape cancel exactly and restore origin focus;
- confirmation cannot be redirected by later selection changes, and confirm performs one menu route, captured package replacement, or guarded safe-quit request respectively;
- clean transitions remain one-step, safe-quit save failure stays in the editor, and existing editor play-copy/return behavior remains exact;
- focused editor/runtime, 1280x720 layout, controller, safe-close, core, editor parse, repository, real Linux WM_DELETE, and packaged Windows/Wine WM_CLOSE gates pass.

Non-goals:
- no authored-map export implementation, editor undo/history, map format change, SaveService/schema change, Native RMG behavior, publication, signing, or overall release-completion claim.

Completion evidence:
- dirty Menu, immutable captured-package replacement, and native close share one compact confirmation with `Keep Editing` focused; controller Back and Escape preserve exact working-copy/session/tool/selection/package/save state and restore the exact origin;
- confirmed actions execute once, duplicate close requests fail closed, both transactional safe-quit failure phases retain the dirty editor and retry successfully, and clean Menu/package/close controls remain direct;
- focused runtime, validator, Python, editor parse, package save-copy/load, Main Menu keyboard, core, real 1280x720 Linux WM_DELETE, and fresh packaged Windows/Wine WM_CLOSE gates pass at save version 9; production project and export presets remain untouched.

## Battle Resolution Autosave Failure Route Safety

id: `battle-resolution-autosave-failure-route-safety-10184`

Status: complete.

Selected Phase 6 gameplay data-safety slice. Nonterminal battle finalizers already commit casualties,
rewards, resolved encounters, commander continuity, pressure/task state, and aftermath to the live
session, but the following Overworld route intentionally skips saving. A crash can therefore reload
the pre-resolution battle and discard or duplicate the completed result.

Implementation target:
- transactionally checkpoint finalized nonterminal victory, retreat, surrender, stalemate, secondary-hero defeat, and town-loss state before exit animation or Overworld routing;
- on write failure, retain the exact finalized live result in Battle, route zero times, emit one bounded issue, show `Save Battle` recovery guidance, and focus Save;
- a successful Save retry persists the canonical finalized autosave and routes once without replaying BattleRules, rewards, or aftermath; terminal scenario outcomes retain the existing Outcome recovery path.

Completion criteria:
- ordinary nonterminal resolution saves exactly once before animation/routing, while both injected failure phases preserve exact prior autosave bytes/cache and leave no transaction artifacts;
- failed resolution remains visibly recoverable in Battle with exact finalized live state and zero route; one Save retry yields canonical reload plus one Overworld route without another gameplay action;
- representative victory and withdrawal/secondary-defeat paths, Quick Resolve, exit animation, terminal Outcome, safe-close/Return, core, parse, repository, Linux package, and packaged Windows/Wine gates pass at save version 9.

Non-goals:
- no BattleRules outcome math, reward/casualty tuning, autosave frequency outside the post-resolution boundary, save/schema bump, Native RMG, publication, signing, or overall release-completion claim.

Completion evidence:
- precommit and after-backup failure across Quick Resolve victory and confirmed retreat preserve exact prior autosave bytes/cache, leave no transaction artifacts, match direct finalized gameplay state, emit one bounded issue, and route zero times with Save Battle focused;
- one Save retry makes total checkpoint attempts two, persists a canonical battle-empty Overworld resume payload, and resumes the stored exit animation/route once without another gameplay action, reward, or finalization;
- ordinary animation checkpoints and routes once, terminal Outcome bypass remains exact, and withdrawal, Quick Resolve, event animation, active focus, save transaction, core, validator, parse, Linux package, and fresh Windows/Wine package gates pass at save version 9.

## Briefing Consumption Autosave Failure Safety

id: `briefing-consumption-autosave-failure-safety-10184`

Status: completed.

Selected Phase 6 checkpoint-truthfulness slice. Authored first-turn command briefings and fresh
battle tactical briefings mutate their one-shot `shown` state before autosaving, but both shells
discard the structured save result. A failed write is silent and a crash reloads the unconsumed
briefing checkpoint.

Implementation target:
- consume and display the existing briefing exactly once in live state, but inspect the transactional autosave result on both Overworld and Battle entry;
- on write failure, preserve exact prior bytes/cache and the visible/live consumed briefing, emit one bounded issue, show Save guidance, focus Save, and route nowhere;
- one Save persists the consumed state so restore does not replay the briefing; ordinary success and generated-opening deferred autosave behavior remain unchanged.

Completion criteria:
- precommit and after-backup failures on both shells preserve exact prior durable state with no transaction artifacts while live shown state and briefing presentation remain intact;
- each failure emits one sanitized issue, exposes bounded visible guidance and Save focus, and one verified Save/reload proves the briefing remains consumed without gameplay mutation or route;
- ordinary authored success, generated-opening defer, active controller, save transaction, core, parse, repository, Linux package, and packaged Windows/Wine gates pass at save version 9.

Non-goals:
- no briefing copy/content redesign, tutorial system, generated-opening lifecycle change, gameplay rule change, save/schema bump, Native RMG, publication, signing, or overall release-completion claim.

## Scenario Outcome Normal Entry Focus

id: `accessibility-scenario-outcome-normal-entry-focus-10184`

Status: completed.

Selected Phase 6 controller/keyboard accessibility slice. Ordinary Outcome entry rebuilds the
dynamic follow-up actions but assigns no focus owner; only autosave-recovery entry explicitly
focuses Save. Controller and keyboard players can therefore reach a mandatory victory/defeat
screen with no deterministic command target.

Implementation target:
- configure a live focus cycle spanning enabled dynamic follow-up actions, Save Slot, Save Outcome, Return to Menu, and Guide;
- on ordinary entry prefer the enabled action identified by the existing primary-outcome policy, with a safe enabled fallback, while recovery entry continues to prefer Save;
- preserve existing valid focus during refresh and never steal native manual-overwrite confirmation focus.

Completion criteria:
- ordinary campaign/skirmish victory and defeat entry own a visible enabled focus target and controller/keyboard forward/reverse navigation skips disabled controls;
- controller accept invokes the focused command exactly once, recovery continues to focus Save, and occupied-slot overwrite keeps its safe native Cancel focus and exact origin restoration;
- outcome visual, active focus, manual overwrite, recovery, 1280 layout, core, parse, repository, Linux package, and Windows/Wine gates pass without save/schema or gameplay changes.

Non-goals:
- no Outcome composition/copy redesign, action-policy change, save/router/rules change, broader input remap, Native RMG, publication, signing, or overall release-completion claim.

## Overworld 1600 Command Band Responsive Fit

id: `ux-overworld-1600-command-band-responsive-fit-10184`

Status: completed.

Selected Phase 6 responsive-layout correction. The selectable 1600x900 Overworld frame keeps
the full command-row policy, but its fixed command surfaces render at x=-3 with width 1606.
The 1024x600 and 1280x720 compact breakpoints already fit.

Implementation target:
- fit the entire command band and each End Turn/slot/Save/Settings/Menu control inside the 1600x900 frame using bounded responsive spacing/minimum-width policy;
- preserve all commands, map dominance, enabled focus order, and existing 1024x600, 1280x720, and 1920x1080 behavior.

Completion criteria:
- strict geometry asserts the command band and every live command rect start and end inside 1600x900;
- controller/keyboard navigation and activation remain exact, and compact/full visual contracts remain green;
- repository, Linux/X11, and packaged Windows/Wine gates pass without gameplay/save/schema changes.

Non-goals:
- no command copy redesign, new panels, gameplay/rules/save changes, global UI-scale redesign, Native RMG, publication, signing, or overall release-completion claim.

## Windows Uninstall Registration And PE Version Coherence

id: `packaging-windows-uninstall-registration-and-pe-version-coherence-10184`

Status: completed.

Selected Phase 6 packaging-hardening correction. The transactional per-user Windows installer
writes a verified `uninstall.exe` but does not register the install in the standard current-user
Apps & Features registry surface or expose an uninstall shortcut. Separately, exported game and
setup executables do not carry release-coherent Windows version resources.

Implementation target:
- derive one bounded four-part Windows numeric version from the canonical project semantic version and enforce the same value in the Godot Windows preset, release-candidate tooling, and generated NSIS metadata;
- publish the standard HKCU Uninstall registration only after a verified install commit, including bounded display identity, semantic DisplayVersion, install location, icon, uninstall command, and no-modify/no-repair policy;
- remove that registration only after an ownership-verified successful uninstall, while failed install/upgrade/uninstall paths preserve the prior registration exactly;
- verify both game/setup PE version resources and the registry lifecycle through production packaging tests and fresh Wine install/upgrade/uninstall probes.

Completion criteria:
- Windows game and setup PEs expose the expected numeric version and bounded product/file identity with no nonnumeric Godot version warning;
- a successful per-user install appears under the standard HKCU Apps & Features key and offers a discoverable uninstall path, while successful uninstall removes the key and owned files;
- injected precommit/after-backup install failures and refused uninstall preserve prior registered values and program bytes exactly;
- Linux release artifacts remain unchanged and repository, archive/manifest, Windows export, installer, Wine lifecycle, validator, and diff gates pass.

Non-goals:
- no machine-wide install, elevation, MSI migration, auto-update channel, signing/notarization, native-Windows hardware certification, publication, gameplay/content change, Native RMG work, or overall release-completion claim.

## Brasshollow Rivet Hound Breach Skirmisher

id: `combat-brasshollow-rivet-hound-breach-skirmisher-10184`

Status: completed.

Selected Phase 6 combat-identity correction. Brasshollow's tier-2 Rivet Hounds are authored as
machine skirmishers for anti-raider work and armor-weakness reveal, but live content gives them
only a defensive Rivet Hide passive. This bounded slice owns the missing breach/reveal behavior;
global tempo changes remain outside the accepted balance envelope.

Implementation target:
- preserve the validated speed-4/initiative-6 tempo, Rivet Hide, and existing economy/recruitment identity after rejecting balance-breaking universal tempo increases;
- add one bounded supported primary-melee breach that marks a surviving veteran target with a one-round defense reduction and spends its authored use exactly once;
- surface the effect through shared battle summaries/events and give tactical AI the same availability, support, target, and spent-use contract;
- validate the production unit in a method-matched stripped control and representative Orevein/Ninefold live encounters without tuning final-map or aggregate reports in place of behavior.

Completion criteria:
- ability-versus-stripped fixtures preserve identical tempo and first-hit RNG/damage while only the authored unit applies the mark and only a later defense-derived hit changes;
- unsupported, low-tier, lethal, retaliation, expired, and spent-use cases fail closed, and mid-battle save/reload preserves the mark and use count;
- Scrip Haulers and a method-matched existing melee support-mark unit remain exact, while tactical AI preview/selection agrees with runtime availability;
- focused ability, live Orevein/Ninefold, fast benchmark, active 59-encounter breadth, all-live faction matrix, repository, and Linux/Windows packaged content gates pass without a save-schema change.

Non-goals:
- no broad Brasshollow ladder redesign, universal speed/initiative retuning, repair/machine-class system, economy/recruitment rebalance, art replacement, final faction-balance claim, Native RMG work, publication, signing, or overall release-completion claim.

## Battle Direct Playback Speed Write-Failure Recovery

id: `battle-direct-playback-speed-write-failure-recovery-10184`

Status: completed.

Selected Phase 6 settings/runtime consistency correction. Battle's shipped Normal, Fast, and
Instant buttons first mutate the active session, then discard the structured device-settings
commit result. A failed transactional write restores the committed device setting but leaves the
current battle and highlighted control on the unsaved choice while showing success.

Implementation target:
- consume the existing `SettingsService.set_battle_playback_speed_id` result at the direct Battle control boundary;
- apply the committed speed to the active battle only after success, and resynchronize the session/button state to the prior committed speed on failure;
- retain safe control focus and show bounded truthful not-saved guidance without mutating round, RNG, stacks, routes, or any battle rule state beyond presentation speed;
- validate injected precommit, after-backup, and non-regular-live-file failures plus ordinary successful persistence and subsequent-battle restore.

Completion criteria:
- every failure preserves exact prior settings bytes and transactional residue state, committed/runtime/session speed, battle simulation payload, route state, selected speed, and safe focus;
- failure feedback cannot claim success, while clearing the failure hook persists and applies the requested speed exactly once and a fresh battle consumes that setting;
- existing active-play Settings, battle presentation/animation, controller focus, settings transaction, core, repository, and Linux/Windows packaged focused gates remain green.

Non-goals:
- no battle timing rebalance, animation-system redesign, settings-schema change, display-confirmation redesign, Native RMG work, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Scenario Outcome New-Session Confirmation Safe Cancel

id: `scenario-outcome-new-session-confirmation-safe-cancel-10184`

Status: completed.

Selected Phase 6 destructive-transition safety correction. Normal Outcome entry now focuses its
authored primary follow-up, while campaign and skirmish start/retry/replay actions immediately
replace the resolved active session despite explicit Save Outcome guidance. One controller accept
or accidental click can therefore replace Continue Latest before the player preserves the review.

Implementation target:
- gate only `campaign_start:*` and `skirmish_start:*` Outcome actions behind one compact native confirmation while Save Outcome and Return to Menu remain direct;
- capture the exact action id/label, source session identity/status, and origin control, with `Keep Outcome` initially focused and B/Escape cancellation restoring the exact origin;
- on confirm, revalidate the captured session/action and recovery state before invoking the existing action path exactly once; stale or disabled actions fail closed without routing;
- preserve the resolved session, campaign profile, autosave/manual slots, settings, and route state byte-for-byte on cancel.

Completion criteria:
- real controller A and mouse activation open the modal for skirmish retry, campaign replay/retry, and next-chapter start, while Return to Menu and Save Outcome keep their existing behavior;
- immediate A, B, and Escape cancel safely with exact state preservation and origin-focus restoration, and the modal remains contained at 1280x720;
- deliberate navigation to the destructive confirm button performs the immutable captured action and routes exactly once, while stale identity/action and Outcome autosave recovery pending remain blocked;
- normal Outcome focus, recovery, manual overwrite, visual, controller, core, repository, and Linux/Windows native-dialog package gates pass.

Non-goals:
- no campaign progression redesign, new autosave policy, Save Outcome behavior change, action copy rewrite, broad Outcome layout redesign, Native RMG work, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Accessibility Battle Quick Resolve Safe-Cancel Focus

id: `accessibility-battle-quick-resolve-safe-cancel-focus-10184`

Status: completed.

Selected Phase 6 destructive-dialog accessibility correction. Quick Resolve is intentionally
confirmed because it permanently applies casualties, mana, outcome, rewards, and objective
consequences, but the dialog currently places initial focus on `Resolve Battle`. Controller users
can therefore open it with A and commit it with the next A before making a deliberate choice.

Implementation target:
- label the native cancel action `Keep Fighting` and give it stable initial focus after the Quick Resolve popup;
- preserve existing B/Escape cancellation and exact Quick Resolve origin-focus restoration;
- leave deliberate navigation to `Resolve Battle`, auto-resolution policy, combat RNG/math, checkpointing, and routing unchanged;
- validate physical controller A/B, Escape, mouse behavior, native-dialog bounds, and exactly-once deliberate confirmation.

Completion criteria:
- campaign and skirmish battles open Quick Resolve with `Keep Fighting` focused, and immediate A, B, or Escape cancels with exact session/RNG/save/route preservation and returns focus to Quick Resolve;
- deliberate navigation to `Resolve Battle` then A invokes the existing confirmed path exactly once with direct-result/checkpoint parity, while mouse confirmation remains unchanged;
- active controller focus, Quick Resolve runtime, battle animation/checkpoint, 1280 layout, core, repository, and Linux/Windows native-dialog package gates pass.

Non-goals:
- no Quick Resolve policy, battle math, AI, reward, withdrawal, save-schema, animation, routing, broad Battle layout, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion change.

## Generated Opening Autosave Failure Retry Safety

id: `save-generated-opening-autosave-failure-retry-safety-10184`

Status: completed.

Selected Phase 6 generated-session durability correction. The deferred opening autosave is scheduled
only once. On failure the shell shows compact failed text but retains no actionable recovery state,
does not focus Save, and ordinary fallback persistence can preserve stale opening-pending flags.

Implementation target:
- retain one explicit Overworld recovery state with sanitized issue, bounded Save guidance, and Save focus after generated-opening autosave failure;
- make the first Save retry the existing authoritative generated-opening autosave path, keeping exact pending state on failure and restoring ordinary manual Save only after verified success;
- canonicalize generated-opening success flags in any verified runtime save made while pending, mirroring them into the live session only after commit;
- preserve exact prior bytes/cache/artifacts on forced, precommit, and after-backup failures and prevent briefing/opening replay after reload.

Completion criteria:
- failed opening writes keep exact prior authority, emit one issue, route nowhere, and expose a retryable Save surface without allowing gameplay actions to hide the durability warning;
- retry failure is exact and nonduplicating; one successful retry clears pending/deferred flags, sets completion, reloads canonically, and is not attempted again;
- manual, menu, and safe-close fallback saves cannot durably retain stale generated-opening pending state; ordinary/non-generated controls remain exact;
- save transaction, generated timing, Overworld focus/visual, core, repository, and Linux/Windows packaged focused gates pass without a save-version change.

Non-goals:
- no generated-map rules or parity change, random-map performance redesign, save schema/version bump, manual-slot redesign, Native RMG recovery work, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Overworld Gameplay Movement Input Ownership

id: `accessibility-overworld-gameplay-movement-input-ownership-10184`

Status: completed.

Selected Phase 6 input-ownership correction. Configured keyboard movement currently reaches live hero
movement without consulting interaction-owning drawers or save/debug surfaces, while left-stick movement
omits several modal owners already enforced by the adjacent controller-route input path.

Implementation target:
- introduce one authoritative gameplay-movement blocked reason shared by physical keyboard movement, immediate left-stick movement, and controller repeat;
- cover drawers, active settings, save-slot popup, manual overwrite confirmation, End Turn confirmation/commit, and debug ownership without suppressing ordinary movement merely because a regular command has focus;
- allow blocked keyboard events to remain available to their owning GUI surface instead of consuming them as hero movement.

Completion criteria:
- physical configured movement keys and raw left-stick input cannot mutate hero position, movement points, day/session state, selection, camera, autosave authority, or focus while an owning surface is active;
- repeat state clears safely when ownership changes, and closing the owner lets the same keyboard/axis input move exactly once with the existing cadence;
- normal focused-command movement, right-stick route selection, save/overwrite, End Turn, debug, focus, and layout behavior remain exact;
- focused, controller-route, active-focus, core, repository, and Linux/Windows packaged input gates pass without save-schema or gameplay-rule changes.

Non-goals:
- no movement cost/pathfinding/camera policy, route-selection semantics, input remapping redesign, drawer layout, save behavior, rules/AI/content, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Latest Save Subsecond Recency

id: `save-latest-summary-subsecond-recency-10184`

Status: completed.

Selected Phase 6 save-selection correctness fix. Runtime save payloads already record fractional Unix
timestamps, but summary construction truncates them to integer seconds. Autosave is inspected first and
strict comparison retains it on a same-second tie, allowing Continue Latest to restore older state.

Implementation target:
- retain a precise floating-point recorded timestamp in inspected summaries while preserving the existing integer timestamp and minute-formatted player copy;
- use the precise timestamp for SaveService and Main Menu latest ordering with an integer/modified-time fallback for legacy summaries;
- keep save payload bytes, save version, slot format, integrity checks, and explicit slot loading unchanged.

Completion criteria:
- an older autosave at second fraction .1 followed by a newer manual save at .9 selects the manual save, while the reverse ordering selects autosave;
- runtime-cached and cold-disk inspection agree, integer-only legacy summaries remain loadable/orderable, and summary display copy remains unchanged;
- inspection and selection never rewrite save bytes or transaction artifacts;
- focused, transactional save, Continue Latest/menu, core, repository, and Linux/Windows packaged gates pass without a save-version change.

Non-goals:
- no wall-clock redesign, slot priority policy beyond timestamp ordering, save payload/schema/version change, UI date-format change, autosave timing, gameplay/rules/content, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Generated Opening Alternate Autosave Reconciliation

id: `save-generated-opening-alternate-autosave-reconciliation-10184`

Status: completed.

Selected Phase 6 recovery-state consistency fix. After an opening autosave failure, a successful End Turn
uses the central SaveService canonicalizer and durably clears the authoritative pending flags, but the live
Overworld shell retains its local failure boolean and continues intercepting Save with stale failure guidance.

Implementation target:
- reconcile generated-opening recovery state after any verified in-place alternate autosave that canonically clears the live pending flags;
- clear only stale shell-local warning/retry state, preserve the single historical issue record, and restore ordinary Save behavior without scene exit;
- make the retry entry fail closed but self-heal if authoritative live state is already complete.

Completion criteria:
- after an initial forced/precommit/after-backup opening failure, clearing injection and completing one nonterminal End Turn applies rules once, saves once, and leaves live plus restored completion flags canonical;
- shell recovery pending, stale warning, and forced Save focus clear immediately; the next Save enters ordinary manual/overwrite behavior instead of returning `not_pending`;
- a failing End Turn autosave preserves honest opening recovery and exact durable authority, while issue count remains deduplicated;
- focused generated-opening, End Turn, transaction, focus/visual, core, repository, and Linux/Windows packaged gates pass without SaveService or save-version changes.

Non-goals:
- no End Turn rules/autosave policy, generated-map rules, SaveService canonicalization, save schema/version, manual-slot redesign, routing, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Town Management Tab Controller Navigation

id: `accessibility-town-management-tab-controller-navigation-10184`

Status: completed.

Selected Phase 6 controller-accessibility correction. Town exposes Build, Muster, Spells, Trade, and Log
through a native TabContainer, but the authoritative focus cycle contains only the current tab's controls
and no input path can intentionally move controller focus between management tabs.

Implementation target:
- add the native management TabBar to the Town focus cycle and expose a stable entry path from current-tab commands;
- let ordinary left/right keyboard and D-pad input select each visible enabled tab through native GUI behavior;
- after a tab changes, preserve deterministic focus ownership and make the selected tab's first enabled action reachable without trapping focus.
- keep tab-driven readiness refresh strictly read-only by simulating market coverage against a duplicated town state rather than consuming live weekly market usage.

Completion criteria:
- real keyboard/controller navigation reaches the visible management TabBar, selects all five tabs, and reaches each selected tab's first enabled command;
- traversal alone leaves session, resources, town state, save authority, and routes exact while visible focus remains owned by Town;
- Build confirmation, Save, Settings, Return to Field, Menu, mouse tab selection, narrow-layout drawer behavior, and B/Escape semantics remain exact;
- focused, active-focus, town visual/cache, core, repository, and Linux/Windows packaged controller gates pass without rules, content, or save-version changes.

Non-goals:
- no town rule/economy/recruitment/spell/market/log behavior, tab content/layout redesign, new shortcuts, input remapping, save/routing policy, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Briefing Consumption Alternate Autosave Reconciliation

id: `save-briefing-consumption-alternate-autosave-reconciliation-10184`

Status: completed.

Selected Phase 6 recovery-state consistency fix. Command briefing consumption mutates live `shown` state
before its entry autosave. If that write fails and a later End Turn autosave succeeds, the durable payload
is canonical but Overworld retains its local failure flag, stale warning semantics, and forced Save focus.

Implementation target:
- define the authoritative consumed-briefing predicate and reconcile local recovery only after a verified in-place alternate autosave persists that state;
- preserve the historical issue record while clearing stale pending/copy/focus behavior and restoring ordinary Save flow;
- keep failed End Turn saves honest and make stale preflight/direct recovery self-heal without a write when authority is already durable.

Completion criteria:
- precommit and after-backup entry failures preserve exact old bytes/cache/residue and emit one briefing issue;
- clearing injection and completing one nonterminal End Turn applies rules once, saves once, leaves live/restored briefing shown state canonical, clears local pending/stale copy, retains EndTurn focus, and returns next Save to ordinary manual/overwrite flow;
- a failing End Turn preserves briefing recovery and exact durable authority with truthful retry guidance and deduplicated historical issue;
- focused briefing, End Turn, transaction, focus/visual, core, repository, and Linux/Windows packaged gates pass without SaveService, rules, or save-version changes.

Non-goals:
- no briefing content/consumption policy, End Turn rules/autosave policy, SaveService canonicalization, save schema/version, manual-slot redesign, Battle briefing change, routing, Native RMG, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Generated-Large Town Cache-Hit First Refresh Performance

id: `performance-town-generated-large-cache-hit-first-refresh-10184`

Status: completed.

Selected Phase 6 normal-path performance correction. A generated Large 108x108 same-town re-entry reports
a true entity-cache hit with zero rebuild and sub-millisecond signature work, yet synchronous first refresh
takes about 6.5 seconds because the dynamic Resource Ledger recomputes full build/recruit economy projections.

Implementation target:
- derive the Resource Ledger economy plan from cached build/recruit action models after their dynamic affordability refresh instead of calling full TownRules action builders on cache hits;
- preserve identical player-readable build/muster readiness, bottleneck, income, field-site, and stockpile copy against direct cold controls;
- retain current cache invalidation and full recomputation after real build, recruit, market, session, or town authority changes.

Completion criteria:
- the unchanged deterministic generated-Large same-town regression remains a cache hit with build time zero, signature below 50ms, and synchronous first refresh below the existing 1000ms limit;
- resource changes update cached affordability, bottleneck, build/muster counts, commands, and ledger copy exactly against direct rules controls;
- refresh leaves session, town, resources, market usage, save bytes, routes, and focus authority exact, while real build/recruit/market actions remain mutating and invalidate once;
- focused cache/economy, Town navigation/visual, core, repository, and Linux/Windows packaged performance gates pass without TownRules, save, rules, or content changes unless profiling proves a smaller shared memoization boundary is required.

Non-goals:
- no generated-map/RMG rules or parity, Town economy/rules/content change, UI composition redesign, cache-policy rewrite beyond the selected economy model, save schema/version, broad performance tuning, publication, signing, native Windows hardware certification, or overall release-completion claim.

## Generated-Large Town Explicit Save Surface Performance

id: `performance-generated-large-town-explicit-save-surface-10184`

Status: completed.

Selected Phase 6 data-protection interaction performance correction. On a generated Large Town, real
SaveSlot selection and post-save refresh synchronously build the full in-session save surface in roughly
9.75-9.86 seconds, repeatedly serializing and summarizing the same live session for equivalent recap copy.

Implementation target:
- build one detached live payload and one normalized current-session summary/context per save-surface request;
- derive current context, play/save checks, save/return handoffs, recaps, and menu tooltip from that shared immutable per-call context while retaining exact existing strings;
- derive the retained command-risk watch through the same exact reducer without rebuilding discarded forecast detail, and reuse exact local town/logistics contexts without stale cross-call state;
- reuse already-computed return handoff and avoid any persistent cross-call cache, writer, summary-cache, schema, or routing change.
- reuse Town's already-current cached departure surface during forced slot/post-save refresh instead of re-entering the full generated-map departure projection chain.
- allow a verified slot-summary cache hit before live-file recovery parsing only when no transaction artifact exists and exists/mtime/size identity matches; artifact and cache-miss paths retain full recovery/read behavior.

Completion criteria:
- physical keyboard/controller SaveSlot selection and post-manual-save refresh on the deterministic generated-Large fixture each settle below the existing 1000ms interaction budget;
- every save-surface dictionary field and player-visible string matches direct descriptor controls exactly for Town, Overworld, Battle, and Outcome contexts;
- resource/day/build/recruit/market changes produce fresh exact copy, while selection performs zero writes/session/cache/route/focus mutation;
- successful, failed, overwrite-confirmed, and overwrite-canceled manual saves preserve exact transactional bytes/reload semantics and perform one write;
- focused surface/timing, transaction/overwrite, Town cache/economy/focus, core, repository, and Linux/Windows packaged performance gates pass without save-version change.

Non-goals:
- no persistent save-surface cache, save writer/schema/version, broad summary-cache policy beyond the selected artifact-free verified hit, autosave/manual-slot/overwrite behavior, UI composition/copy change, Town rules/content, generated-map or Native RMG behavior, publication, signing, native Windows hardware certification, or overall release-completion claim.

Completion evidence:
- source focused selection is 348ms wall/163.737ms surface; post-save Town refresh is 816.921ms with cache hit/build0, forced surface 532.308ms, and SaveService surface 386.801ms;
- Linux packaged selection is 140.898ms and all gated surfaces are at most 338.306ms; fresh Windows/Wine selection is 177.893ms and all gated surfaces are at most 786.099ms;
- exact 17-field surface parity, steady/active/nested-enemy risk parity, canonical reload, candidate/backup recovery, injected rollback, cancel/overwrite, Town transition/focus, command-risk/end-turn, core, editor, validator, and repository integrity pass;
- the generated 20MB transactional write still takes several seconds and remains a distinct future performance slice; it is not reported as part of the corrected sub-second surface/feedback budget.

## Generated-Large Transactional Manual Save Performance

id: `performance-generated-large-transactional-manual-save-10184`

Status: completed.

Selected Phase 6 persistence performance correction. The deterministic supported generated-Large fixture
writes about 20.28MB and blocks a manual save for about 7.8 seconds on Linux and 8.9 seconds under fresh
packaged Wine even after its visible save surfaces are sub-second. Profiles attribute most of the remaining
cost to repeated restore/save normalization, deep payload copies, JSON write/readback, and summary-session
reconstruction.

Implementation target:
- retain one full manual restore/semantic normalization because the runtime-normalized signature is intentionally shallow, then transfer that already-detached normalized graph into write preparation without another whole-graph `to_dict`, normalization, or deep copy;
- stamp metadata and clear transition intent on the already-owned prepared payload;
- recover the destination once before retained-name inspection and reuse that verified commit base in the raw transactional writer;
- publish the verified runtime summary cache from the already-authoritative resume target instead of reconstructing another SessionData graph;
- retain candidate and committed-file exact read/parse verification, backup rollback, future-version refusal, timestamps, manual names, and save-version-9 bytes semantics.

Completion criteria:
- deterministic generated-Large empty-slot and overwrite manual saves complete within 3 seconds on Linux and 4 seconds under fresh packaged Windows/Wine, with exactly one transactional write;
- canonical reload, manual name, selected slot, summary cache, live session, focus, message, and candidate/backup residue semantics remain exact;
- precommit, after-backup, corrupt-live, candidate, backup, and future-version recovery/refusal paths preserve prior authority exactly;
- legacy/unnormalized manual sessions retain the full normalization fallback, while ordinary autosave, generated-opening fast save, small-map save, overwrite/cancel, save-surface, command-risk, core, repository, and Linux/Windows package gates pass.

Non-goals:
- no removal or weakening of candidate/committed readback verification, async/background writer, save schema/version, compression-format change, persistent payload cache, UI composition/copy, generated-map rules, Native RMG behavior, publication, signing, native Windows hardware certification, or overall release-completion claim.

Completion evidence:
- manual saves retain one full semantic normalization, then transfer the detached normalized graph through prepared write ownership without a second whole-graph normalization or payload copy;
- candidate and committed files still receive full JSON parse, dictionary-root, and exact-text verification, while unused parser-tree duplication is eliminated;
- empty-slot/overwrite runtime saves complete in 2312/2527ms in the authoritative source run, 2302/2462ms in the Linux package, and 2863/3830ms in fresh Windows/Wine;
- precommit and after-backup rollback, corrupt/candidate/backup/future-version recovery, manual naming, canonical reload, autosave/generated-opening controls, command-risk/core compatibility, editor, validator, repository integrity, and exact Linux/Windows packages pass.

## Battle Information Tab Controller Navigation

id: `accessibility-battle-info-tab-controller-navigation-10184`

Status: completed.

Selected Phase 6 accessibility correction. Battle exposes four live information tabs—Order, Focus, Spells,
and Timing—but its authoritative keyboard/controller focus cycle omits the native TabBar. Mouse selection works,
while controller-only traversal remains confined to commands and system controls.

Implementation target:
- include the exact native Battle TabBar once in the final authoritative focus cycle while preserving suggested-action entry, modal recovery, and failure-recovery Save focus;
- retain native left/right tab selection, hold focus at the first and last selectable boundaries, and keep informational pages non-actionable;
- preserve the selected information tab and a legal focus owner across battle refreshes and real command execution;
- keep Battle rules, content, save schema/version, layout composition, mouse selection, and command behavior unchanged.

Completion criteria:
- physical keyboard/controller input reaches the native TabBar, selects Order, Focus, Spells, and Timing in both directions, and retains focus at both boundaries;
- forward/reverse traversal returns to legal Battle commands without trapping focus, and mouse tab selection remains exact;
- tab traversal and refresh leave battle/session/save/settings/routes/target/initiative/event authority exact;
- suggested-action focus, board navigation, Defend, Quick Resolve, withdrawal dialogs, Save, Settings, Menu, B/Escape, and post-action focus remain exact;
- active-focus, Battle layout/visual, event-animation/checkpoint, core, editor, validator, repository, Linux package, and fresh Windows/Wine controller gates pass.

Non-goals:
- no Battle rules/content/balance changes, tab content redesign, new information panels, layout expansion, save schema/version, broad focus-system rewrite, generated-map or Native RMG work, publication, signing, native Windows hardware certification, or release-completion claim.

Completion evidence:
- the exact native Battle TabBar appears once in the authoritative focus cycle, preserves suggested-action/Save/modal focus, retains both selectable boundaries, and immediately resyncs the selected information tooltip;
- real shoulder, D-pad, keyboard, and mouse traversal covers Order, Focus, Spells, and Timing in both directions, returns to the original legal command, and preserves Timing through a real Defend refresh;
- strict battle/session/save/settings/routes/target/initiative/event authority, active-focus, core, editor, validator, repository, Linux package, and fresh Windows/Wine package gates pass;
- the broad Battle layout harness remains pre-existing test debt: current and isolated committed HEAD both time out at the same detached routed-resolution null viewport/tree teardown before any tab assertion.

## Scenario Outcome Recap Tab Controller Navigation

id: `accessibility-scenario-outcome-recap-tab-controller-navigation-10184`

Status: completed.

Selected Phase 6 accessibility correction. The mandatory terminal Outcome screen exposes five recap pages—Progress,
Arc, Carryover, Aftermath, and Journal—but its focus cycle supplies the TabContainer rather than the internal native
TabBar. Keyboard/controller traversal loops through ordinary actions while the recap remains on Progress; mouse selection works.

Implementation target:
- include the exact native Outcome recap TabBar once in the authoritative focus cycle while preserving primary-action, recovery Save, overwrite, new-session confirmation, Menu, and Guide focus policies;
- retain native left/right selection across all five informational pages, hold focus at first/last selectable boundaries, and immediately synchronize selected-page accessibility copy;
- preserve the selected recap page and a legal focus owner across Outcome refresh/save flows without adding page actions;
- keep outcome rules, progression, save schema/version, routing, layout composition, and mouse behavior unchanged.

Completion criteria:
- real shoulder/D-pad/keyboard input reaches the native TabBar, selects all five recap pages in both directions, retains both boundaries, returns to legal actions, and preserves mouse selection;
- selected recap page and valid focus persist across refresh/save and confirmation cancel paths;
- browsing leaves session/progression/save/cache/settings/routes/action authority and recap copy exact;
- campaign and skirmish victory/defeat, overwrite and new-session confirmation, normal/recovery focus, 1280/1920 layout, core, editor, validator, repository, Linux package, and fresh Windows/Wine package gates pass.

Non-goals:
- no Outcome content/copy redesign, new recap pages, progression/reward/routing changes, save schema/version, broad focus-system rewrite, layout expansion, generated-map or Native RMG work, publication, signing, native Windows hardware certification, or release-completion claim.

Completion evidence:
- the exact native Outcome recap TabBar appears once in the authoritative focus cycle, retains both selectable boundaries, updates selected-page accessibility copy, and preserves primary/recovery/modal focus policy;
- all four campaign/skirmish victory/defeat rows prove real shoulder/D-pad/keyboard/mouse traversal across five pages, reverse traversal, action return, Journal refresh persistence, and exact session/progression/files/cache/settings/routes/actions/recap authority at 1280 and 1920;
- recovery Save physically selects Arc and retains it through an occupied-slot overwrite dialog plus Escape cancel while preserving prior manual bytes;
- Outcome recovery, new-session confirmation, visual, core, editor, validator, repository, Linux package, and fresh Windows/Wine package gates pass.

## Mireclaw Drowned Antler Wounded Apex

id: `combat-mireclaw-drowned-antler-wounded-apex-10184`

Status: completed.

Selected Phase 6 faction-identity and balance implementation slice. The faction bible defines the tier-seven
Drowned Antler Sovereign as an apex pressure piece with wounded-stack dominance, but production still gives it
a generic `0.84` ranged screen, +2 cohesion, and unconditional engaged pressure. Under the corrected-RNG all-live
matrix, Mireclaw wins every week-four pairing and reaches 79-percent dominance.

Implementation target:
- replace Drowned Sovereign Screen with one content-owned primary-melee wounded/disrupted apex contract using the shared Bloodrush rule shape, without faction, matchup, week, seed, or benchmark branches;
- make clean lines resist the apex while wounded, listed-disrupted, or rooted prey open bounded damage and kill-momentum windows;
- keep live BattleRules, tactical AI, player summaries, normalization, focused ability proof, and the fast benchmark on the same authored fields;
- add a method-matched benchmark control that restores only the prior Drowned Sovereign Screen in memory while leaving every other unit, hero, spell, army snapshot, seed, and tie policy exact.

Completion criteria:
- focused runtime proof covers clean, wounded, listed-status, rooted, ranged, retaliation, kill momentum, dead/stripped source, live/AI parity, and readable summaries;
- the corrected-RNG all-live 100-seed four-week matrix improves at least one current control metric without worsening 38 outliers, `332.5` severity, 13 rows at or above 65 percent, `79.0` maximum dominance, or `1.6` side-bias points, with zero structural failures;
- method-matched Drowned Sovereign Screen control and production candidate use identical formation isolation, all-live hero pairs, seeds, weeks, and initiative-tie policy;
- the active 59-encounter breadth queue remains clear, and focused ability, autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not change unit base stats, growth, costs, buildings, army groups, other Mireclaw units, heroes, spells, economy, encounters, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not hard-code factions, opponents, weeks, army counts, encounter ids, seeds, or benchmark identity into combat behavior;
- do not claim final Mireclaw identity, final faction balance, or overall release completion.

Completion evidence:
- Drowned Sovereign Screen is replaced by the content-owned Drowned Antler Rout: a primary-melee clean-line penalty, wounded and harried/staggered/rooted payoff, bounded wounded initiative, and kill-only momentum using the shared Bloodrush rules;
- the focused live ability report passes `118/118` authored instances with exact clean, wounded, disrupted, rooted, ranged, retaliation, tactical-AI, initiative, kill-momentum, normalization, and readable-role proof;
- the exact in-memory prior-screen control and production candidate match on 100 seeds, four weeks, all-live heroes, 120 ordered matchups, army snapshots, spellbooks, and initiative-tie policy;
- the prior-screen control reproduces 38 outliers / 332.5 excess severity / 13 severe rows / 79.0 maximum dominance / 1.6 side bias, while production improves to 37 / 229.0 / 7 / 73.5 / 1.13 with zero structural failures;
- the active scenario breadth report completes `59/59` encounters with zero stalls or invalid orders and a clear zero-item queue at repeated signature `829808c9`;
- balance regression, core systems, Godot editor parse, repository validation, JSON, Python, and diff checks pass; the existing Native RMG exact-state-chain deferral remains explicitly unchanged.

## Mireclaw Drowned Antler Apex Calibration

id: `combat-mireclaw-drowned-antler-apex-calibration-10184`

Status: completed.

Selected Phase 6 faction-balance implementation slice. Drowned Antler Rout restores the source-authored wounded/disrupted apex role and materially improves its exact prior-screen control, but the accepted production matrix still has 37 outliers / `229.0` excess severity / seven rows at or above 65 percent / `73.5` maximum dominance. Mireclaw leads 15 outlier rows, including every week-three pairing.

Implementation target:
- retain the existing content-owned primary-melee Bloodrush contract, clean-line weakness, wounded/listed-status/rooted windows, initiative, and kill-only momentum;
- calibrate only the clean-target, wounded-target, and listed-status damage multipliers from `0.90/1.12/1.06` to the method-matched `0.85/1.10/1.05` candidate;
- keep live BattleRules, tactical AI, player summaries, normalization, focused ability proof, and the fast benchmark on the same authored fields;
- keep the exact prior Drowned Sovereign Screen benchmark control unchanged.

Completion criteria:
- focused runtime proof keeps clean, wounded, disrupted, rooted, ranged, retaliation, initiative, kill-momentum, dead/stripped-source, live/AI parity, and readable-summary behavior exact at the calibrated authored values;
- the corrected-RNG all-live 100-seed four-week matrix keeps weeks one/two exact and improves the accepted `37 / 229.0 / 7 / 73.5 / 1.13` production surface without structural failures or transferring the loss into a worse side-bias row;
- the exact prior-screen control remains `38 / 332.5 / 13 / 79.0 / 1.6` under identical formation, hero, seed, week, and tie methods;
- the active 59-encounter breadth queue remains clear, and focused ability, autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not change the Bloodrush rule shape, unit base stats, growth, costs, buildings, army groups, other units, heroes, spells, economy, encounters, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not hard-code factions, opponents, weeks, army counts, encounter ids, seeds, or benchmark identity into combat behavior;
- do not claim final Mireclaw identity, final faction balance, or overall release completion.

Completion evidence:
- focused runtime proof passes `118/118` consequences and exclusions for Drowned Antler Rout at `0.85/1.10/1.05` without changing Bloodrush rule shape, ranged attacks, retaliation, initiative, or kill-only momentum;
- the authoritative all-live 100-seed matrix improves production from `37 / 229.0 / 7 / 73.5 / 1.13` to `36 / 214.5 / 6 / 71.0 / 1.13` with zero structural failures, while the identical prior-screen control remains `38 / 332.5 / 13 / 79.0 / 1.6`;
- the active scenario breadth report completes `59/59` encounters with zero stalls or invalid orders and a clear queue at repeated signature `829808c9`;
- autoplay balance, balance regression, core systems, Godot editor parse, repository validation, JSON, Python, and diff checks pass. The content-only calibration is platform-neutral and introduces no Linux/Windows-specific runtime or packaging path.

## Mireclaw Drowned Antler Clean-Line Pressure

id: `combat-mireclaw-drowned-antler-clean-line-pressure-10184`

Status: completed.

Selected Phase 6 faction-balance implementation slice. The completed apex calibration preserves Drowned Antler Rout's authored wounded/disrupted role and improves the all-live matrix, but Mireclaw still leads all five week-three pairings and reaches `71.0` percent dominance. A method-matched 100-seed late-week screen shows that changing only the clean-target multiplier from `0.85` to `0.82` retains all 17 late-week outliers while reducing their severity from `105.0` to `97.0` and maximum dominance from `71.0` to `68.5` percent with zero structural failures.

Implementation target:
- retain the existing content-owned primary-melee Bloodrush contract, wounded threshold/payoff, listed-status/rooted payoff, initiative, and kill-only momentum;
- change only Drowned Antler Rout's clean-target damage multiplier from `0.85` to `0.82`, strengthening the source-authored weakness against compact intact lines without matchup, faction, week, seed, or benchmark branches;
- keep live BattleRules, tactical AI, player summaries, normalization, focused runtime proof, and the fast benchmark on the same authored field;
- keep the exact pre-apex Drowned Sovereign Screen control unchanged.

Completion criteria:
- focused runtime proof retains all Drowned Antler Rout triggers and exclusions and reports the exact 18-percent clean-line penalty;
- the corrected-RNG all-live 100-seed matrix keeps weeks one/two exact, does not increase 36 outliers, six severe rows, `71.0` percent dominance, `1.13` side bias, or zero structural failures, and improves the accepted `214.5` severity;
- the exact prior-screen control remains `38 / 332.5 / 13 / 79.0 / 1.6` under identical methods;
- the active 59-encounter breadth queue remains clear, and focused ability, autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not change wounded/status multipliers, threshold, status ids, initiative, momentum, Bloodrush rule shape, unit base stats, growth, costs, buildings, army groups, other units, heroes, spells, economy, encounters, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not hard-code factions, opponents, weeks, army counts, encounter ids, seeds, or benchmark identity into combat behavior;
- do not claim final Mireclaw identity, final faction balance, or overall release completion.

Completion evidence:
- focused runtime proof passes `118/118` consequences and exclusions and reports the exact 18-percent clean-line penalty while the `1.10/1.05` wounded/status payoff, initiative, and kill-only momentum remain unchanged;
- the authoritative all-live 100-seed matrix keeps weeks one/two exact and improves production from `36 / 214.5 / 6 / 71.0 / 1.13` to `36 / 206.5 / 6 / 70.0 / 1.13` with zero structural failures;
- the identical pre-apex Drowned Sovereign Screen control remains `38 / 332.5 / 13 / 79.0 / 1.6` with zero structural failures;
- the active scenario breadth report completes `59/59` encounters with zero stalls or invalid orders and a clear queue at repeated signature `829808c9`;
- autoplay balance, balance regression, core systems, Godot editor parse, repository validation, JSON, Python, and diff checks pass. This content-only change is platform-neutral and introduces no Linux/Windows-specific runtime or packaging path.

## Veilmourn Undertow Harpooner Damage Calibration

id: `combat-veilmourn-undertow-harpooner-damage-calibration-10184`

Status: completed.

Selected Phase 6 faction-balance implementation slice. The week-two Mireclaw/Veilmourn pair is the production matrix's strongest current row at `70/30`, while Veilmourn remains balanced against Brasshollow and Embercourt. Method-matched pair controls show that removing Veilmourn's tier-four or tier-five ability worsens the row and removing Mireclaw's tier-four or tier-five ability leaves it exact. Undertow Harpooners are instead the only tier-four ranged line below the shipped `5-8` damage band at `5-7`; restoring only their maximum damage to `8` improves the exact pair to `62.5/37.5` before full-matrix validation.

Implementation target:
- change only Undertow Harpooners' `max_damage` from `7` to the common tier-four ranged baseline of `8`;
- retain Mourning Nets, ranged role, health, attack, defense, minimum damage, speed, initiative, growth, cost, presentation, AI behavior, and every other Veilmourn unit contract;
- keep production content, focused runtime expectations, validator ownership, and the fast benchmark on the same authored field.

Completion criteria:
- focused runtime and repository proof bind Undertow Harpooners to the exact `5-8` damage contract while retaining Mourning Nets and all unchanged stats;
- the corrected-RNG all-live 100-seed matrix improves the `70/30` Mireclaw/Veilmourn week-two row and the `35 / 200.5 / 5 / 70.0 / 1.13` production baseline without introducing structural failures or worsening maximum dominance or side bias;
- method-matched non-Veilmourn rows remain exact, the active 59-encounter breadth queue remains clear, and ability/autoplay/balance/core/editor/repository/JSON/Python/diff gates pass.

Non-goals:
- do not change Mourning Nets, other abilities, any other unit stat, growth, cost, building, army group, hero, spell, economy, encounter, save, campaign, packaging, Native RMG, or benchmark thresholds;
- do not hard-code factions, opponents, weeks, army counts, encounter ids, seeds, or benchmark identity into combat behavior;
- do not claim final Veilmourn identity, final faction balance, or overall release completion.

Completion evidence:
- focused runtime proof passes `118/118` authored ability consequences, binds Undertow Harpooners to the exact `5-8` band, and retains Mourning Nets and every unchanged authored field;
- the authoritative corrected-RNG all-live 100-seed matrix improves production from `35 / 200.5 / 5 / 70.0 / 1.13` to `34 / 187.0 / 3 / 68.5 / 0.73` with zero structural failures;
- week-two Mireclaw/Veilmourn improves from `70/30` to `62.5/37.5`, week-four Veilmourn/Brasshollow improves from `67/33` to `61/39`, and all non-Veilmourn ordered rows remain exact;
- the active scenario breadth report completes `59/59` encounters with zero stalls or invalid orders and a clear queue at repeated signature `829808c9`;
- autoplay balance, balance regression, core systems, Godot editor parse, repository validation, JSON, Python, and diff checks pass. This content-only change is platform-neutral and introduces no Linux/Windows-specific runtime or packaging path.

## Aurelion Reach Public Title Identity

id: `presentation-aurelion-reach-public-title-identity-10184`

Status: completed.

Selected Phase 6 first-view product implementation slice. The shipped scenic main menu still exposes the internal placeholder `HEROES-LIKE` even though the authored world, faction, magic, economy, object, and art-direction foundations consistently identify the original setting as Aurelion Reach. Establish Aurelion Reach as the explicit public product title and replace the visible placeholder wordmark without conflating the public title with compatibility-sensitive technical identities.

Implementation target:
- declare `Aurelion Reach` as the public product title in the strategic charter and repository entry point;
- render `AURELION REACH` in the compact first-view logo pocket and update the matching screen-composition specification;
- retain `heroes-like` as the Godot project name, executable stem, installer ownership identity, and current `user://` directory until a separately validated Linux/Windows migration owns existing install, save, settings, shortcut, registry, and uninstall continuity;
- add focused runtime and repository guards for the exact public title, placeholder removal, and compact logo-pocket fit.

Completion criteria:
- the live MainMenu first view renders exactly `AURELION REACH`, contains no visible `HEROES-LIKE` placeholder, and keeps the title inside the existing compact logo pocket;
- scenic composition, first-view command labels/anchors, keyboard navigation, save-inspection guard, and existing menu/outcome visual behavior remain unchanged;
- `project.godot`, export/installer technical identities, executable names, and user-data paths remain exact, so the presentation-only title slice cannot strand Linux or Windows saves/settings;
- Godot editor parse, focused visual/runtime, keyboard, repository, Python, JSON, and diff gates pass.

Non-goals:
- installer/product metadata rename, executable rename, registry-key migration, Start Menu/desktop-entry rename, `user://` migration, logo bitmap generation, broader menu composition changes, gameplay, balance, AI, saves, Native RMG, packaging behavior, or release-completion claims;
- treating Aurelion Reach title adoption as proof of final logo art, final marketing identity, certification, publication, or overall release readiness.

Completion evidence:
- the live MainMenu first view renders exactly `AURELION REACH`, rejects the placeholder, and proves both the label rectangle and rendered minimum text size remain inside the compact logo pocket at the default presentation and an explicit `1280x720` control;
- the full menu/outcome visual smoke passes, preserving the painted backdrop, scenic negative space, plaque commands, anchors, and existing Outcome presentation;
- main-menu keyboard/controller navigation passes, and the lean-boot guard reports zero first-view save inspections before the explicit Load action performs the expected six slot inspections;
- Godot editor parse, repository validation, JSON, Python, progress reconciliation, and diff checks pass. `project.godot`, export presets, installer scripts/ownership keys, executable names, and user-data identity remain unchanged for Linux/Windows compatibility.

## Aurelion Reach Package Public Identity Migration

id: `packaging-aurelion-reach-public-identity-migration-10184`

Status: completed.

Selected Phase 6 cross-platform packaging implementation slice. The live first view now uses the approved public title, but Linux desktop entries, Windows PE metadata, Add/Remove Programs, and shipped launchers still expose `Heroes Like`. Migrate those public package surfaces to Aurelion Reach without renaming compatibility-sensitive program roots or ownership identities.

Implementation target:
- publish `Aurelion Reach` through Windows executable/setup version resources, Add/Remove Programs display metadata, NSIS shortcuts, archive launcher names, and Linux desktop entries;
- retain `heroes-like` executable/archive ids, `%LOCALAPPDATA%\Heroes Like` program root, `Software\Heroes Like` ownership key, `...\Uninstall\Heroes Like` registry identity, manifest/marker schemas, environment variables, and Godot `user://` identity;
- make Windows upgrade transactions recognize legacy `Heroes Like` and public `Aurelion Reach` shortcuts, publish only the public shortcuts on success, and restore the exact prior shortcut/registration state on injected publication rollback;
- update static and real installer lifecycle proof for install, same-version upgrade, legacy shortcut migration, injected precommit/after-backup rollback, modified/unowned refusal, boot, uninstall, and external user-data preservation.

Completion criteria:
- Linux desktop entry and Windows PE/ARP/shortcut surfaces display exactly `Aurelion Reach` while technical executable/install/registry/user-data identities remain exact;
- a verified prior `Heroes Like` installation upgrades in place, removes legacy launchers only after successful publication, and retains one public game/uninstall launcher;
- precommit and after-backup failures restore exact program, registry, and legacy/public shortcut state; malformed/unowned uninstall refusal and final uninstall preserve external user data;
- release artifact verification, archive lifecycle, real NSIS/Wine lifecycle, packaged boot, editor, repository, Python, JSON, and diff gates pass.

Non-goals:
- executable stem, archive id, install-root, ownership-key, registry-key, marker/schema, environment-variable, or `user://` rename; save/settings migration; visual logo generation; gameplay, balance, AI, Native RMG, signing, native Windows hardware certification, publication, or release-completion claims.

Completion evidence:
- the authoritative package lifecycle reports `ok=true` for Linux, Windows NSIS, and Windows archive installers; Linux desktop metadata is exactly `Name=Aurelion Reach`, and Windows setup/game PE resources expose exact Aurelion Reach product, description, contributor, copyright, and numeric version fields;
- real fresh-Wine NSIS install/reinstall, legacy shortcut seeding, precommit and after-backup rollback, successful upgrade, packaged Boot/MainMenu/native-DLL load, malformed/unowned refusal, and uninstall pass with exact registry transactions and external user-data preservation;
- the archive `.cmd` installer independently migrates `Heroes Like.cmd` to `Aurelion Reach.cmd`, restores the legacy launcher through both injected failure phases, boots the packaged game, uninstalls cleanly, and preserves external user data;
- the stable `heroes-like` executable/archive id, `%LOCALAPPDATA%\Heroes Like` install root, `Software\Heroes Like` ownership key, `...\Uninstall\Heroes Like` registry key, marker/schema/env identities, Godot project name, and `user://` location remain unchanged;
- release artifact verification `17/17`, platform readiness, Godot editor parse, repository validation, Python, JSON, progress reconciliation, and diff checks pass.

## Aurelion Reach Native Window Title

id: `presentation-aurelion-reach-native-window-title-10184`

Status: completed.

Selected Phase 6 desktop presentation implementation slice. The public menu, desktop metadata, PE resources, ARP entry, and launchers now say Aurelion Reach, but the native desktop window still inherits the compatibility-sensitive Godot project name `heroes-like`. Set the live root window title from Boot without changing the project or user-data identity.

Implementation target:
- define the exact public desktop title once in `Boot.gd` and apply it synchronously before router handoff;
- extend platform readiness to instantiate the real Boot scene, verify the root Window title is exactly `Aurelion Reach`, then remove the fixture before its deferred route executes;
- retain `application/config/name="heroes-like"`, executable/install/registry/marker/schema identities, and current `user://` paths.

Completion criteria:
- live Boot sets the native root Window title to exactly `Aurelion Reach` before MainMenu routing;
- platform readiness proves the public runtime title and stable technical project identity in the same run;
- Boot/MainMenu routing, profile logging, package boot, Linux/Windows metadata, settings/save paths, editor, repository, Python, JSON, and diff gates remain green.

Non-goals:
- Godot project name, executable/install/registry/user-data rename; custom title-bar implementation; icon/logo art; menu layout; gameplay, balance, AI, Native RMG, signing, certification, publication, or release-completion claims.

Completion evidence:
- `Boot.gd` sets the root `Window.title` to exactly `Aurelion Reach` synchronously before profile logging and deferred router handoff;
- platform readiness instantiates the production Boot scene and reports `window_title="Aurelion Reach"` while proving `application/config/name="heroes-like"`, the stable main scene, icon, export presets, native libraries, and `user://` paths;
- the authoritative installer lifecycle rebuilds and boots Linux, Windows NSIS, and Windows archive packages, including fresh-Wine Boot/MainMenu/native-DLL proof, exact legacy upgrade rollback, registry ownership, uninstall, and external user-data preservation;
- release artifact verification `17/17`, Godot editor parse, repository validation, Python, JSON, reconciliation, and diff checks pass.

## Aurelion Reach Linux Desktop Icon

id: `packaging-aurelion-reach-linux-desktop-icon-10184`

Status: completed.

Selected Phase 6 Linux desktop packaging implementation slice. The shipped desktop entry has the public Aurelion Reach name but no `Icon=` key, and the Linux bundle owns no desktop-readable icon file, so desktop shells fall back to a generic application icon even though the game already ships `icon.svg` as its canonical product emblem.

Implementation target:
- add one manifest-owned `aurelion-reach.svg` payload to Linux release bundles from the canonical project icon;
- point the installed `heroes-like.desktop` entry at the exact installed icon path while retaining the stable technical desktop filename and executable identity;
- preserve exact install/upgrade/precommit/after-backup rollback, uninstall ownership, Windows bundle membership, and external user-data behavior.

Completion criteria:
- Linux tar and runnable installer contain the canonical nonempty SVG under the public asset name and verify its exact manifest identity;
- a real user-local install publishes `Name=Aurelion Reach` and an absolute `Icon=` path whose manifest-owned file exists and byte-matches `icon.svg`;
- rollback restores prior desktop-entry/icon state exactly, uninstall removes owned program/desktop assets, and Linux boot remains green;
- Windows archive/setup membership and PE icon behavior remain unchanged; artifact verification, editor, repository, Python, JSON, reconciliation, and diff gates pass.

Non-goals:
- emblem redesign or generated art; Windows icon changes; technical executable/install/registry/user-data rename; desktop-file rename; system-wide install; gameplay, balance, AI, Native RMG, signing, certification, publication, or release-completion claims.

Completion evidence:
- Linux staging copies canonical `icon.svg` to manifest-owned `aurelion-reach.svg`; the release tar payload SHA-256 equals the source icon SHA-256 `18dbdec8d483ba4d5ff8da2534d898a41804ea41464ce7712ed6d85cf800f43a`;
- the real user-local lifecycle reports `desktop_entry_icon_exact=true`, `icon_installed_before_uninstall=true`, `icon_matches_canonical=true`, and verifies all eight Linux payload files;
- precommit and after-backup failures restore the exact prior program tree and desktop entry, while successful uninstall removes the owned program, launcher, and desktop entry and preserves external user data;
- Windows NSIS/archive install, rollback, registry, PE metadata, Boot/MainMenu/native-DLL, uninstall, and user-data gates remain green with unchanged artifact hashes;
- release artifact verification `17/17`, shell syntax, Python, JSON, repository validation, reconciliation, and diff checks pass.

## Brasshollow Foundry Saint Sustain Calibration

id: `combat-brasshollow-foundry-saint-sustain-calibration-10184`

Status: completed.

Selected Phase 6 faction-balance implementation slice. Saint's Temper is Brasshollow's authored apex sustain mechanic, but its one-percent ordinary round repair leaves week-four Brasshollow/Mireclaw at a narrow `43.5/56.5` outlier. A method-matched 100-seed week-four screen changing only ordinary repair to `0.015` brings that pair inside the target band, reduces week-four outliers from six to five and severity from `33.0` to `31.5`, and leaves all other outlier rows, maximum dominance, side bias, and structural failures exact.

Implementation target:
- retain Saint's Temper's living-source requirement, survivor-only non-resurrection rule, Overheated-only defense hardening, extra Overheated repair, AI target priority, presentation event, and all existing exclusions;
- change only `round_repair_pct` from `0.01` to `0.015`, strengthening the source-authored general repair beat without faction, opponent, week, seed, encounter, or benchmark branches;
- keep live BattleRules, tactical AI, summaries, focused runtime proof, and the fast benchmark on the same authored field.

Completion criteria:
- focused runtime proof covers the exact `0.015` contract plus ordinary/Overheated repair ordering, survivor-only cap, no resurrection, dead/stripped source, defense scope, event, and AI behavior;
- the corrected-RNG all-live 100-seed matrix keeps weeks one-three exact, reduces 36 outliers and `206.5` severity without exceeding six severe rows, `70.0` percent dominance, `1.13` side bias, or zero structural failures;
- the active 59-encounter breadth queue remains clear, and focused ability, autoplay, balance-regression, core, editor parse, repository, JSON, Python, and diff gates pass.

Non-goals:
- do not change Overheated bonus repair, defense hardening, AI priority, other abilities, unit stats, growth, costs, buildings, army groups, other units, heroes, spells, economy, encounters, saves, campaigns, packaging, Native RMG, or benchmark thresholds;
- do not hard-code factions, opponents, weeks, army counts, encounter ids, seeds, or benchmark identity into combat behavior;
- do not claim the unchanged Veilmourn/Brasshollow row improved, final Brasshollow identity, final faction balance, or overall release completion.

Completion evidence:
- focused runtime proof passes `118/118` consequences and exclusions, binds ordinary repair to exactly `0.015`, and preserves stronger Overheated repair, defense hardening, survivor-only caps, non-resurrection, dead/stripped-source, event, and AI behavior;
- the authoritative all-live 100-seed matrix improves production from `36 / 206.5 / 6 / 70.0 / 1.13` to `35 / 200.5 / 5 / 70.0 / 1.13` with zero structural failures, while all non-Brasshollow pair rows remain exact;
- week-three Brasshollow/Embercourt improves from `34.5/65.5` to `37.5/62.5`, week-four Brasshollow/Mireclaw reaches the `45/55` boundary, and the unchanged `33/67` Veilmourn row is not claimed;
- the active scenario breadth report completes `59/59` encounters with zero stalls or invalid orders and a clear queue at repeated signature `829808c9`;
- autoplay balance, balance regression, core systems, Godot editor parse, repository validation, JSON, Python, and diff checks pass. This content-only change is platform-neutral and introduces no Linux/Windows-specific runtime or packaging path.

## Embercourt Bargebow Crew Durability Calibration

id: `combat-embercourt-bargebow-crew-durability-calibration-10184`

Status: superseded.

Selected Phase 6 faction-balance implementation candidate. The authoritative all-live matrix remains
`needs_tuning` at 34 outliers / `187.0` excess severity / three rows at or above 65 percent / `68.5`
maximum dominance / `0.73` side bias / zero structural failures. A method-matched week-three
Embercourt/Mireclaw screen identifies Bargebow Crew HP as a reciprocal causal boundary while exact
ability strips do not improve Embercourt: raising only Bargebow HP from `13` to `15` moves Mireclaw
dominance from `68.5` to `46.0` percent, and lowering only Bogplate Mauler HP from `15` to `13` moves
it to `61.0` percent, with both ordered rows moving in the same direction and all other inputs exact.

Implementation target:
- screen and, only if accepted, change only `unit_embercourt_bargebow_crews.hp` from `13` to `14`, retaining their source-authored protected limited-shot ranged role and remaining below Bogplate Maulers at `15` HP;
- compare the candidate against an exact in-memory old-`13` control under identical armies, formations, all-live heroes, spellbooks, seeds, weeks, contexts, and initiative-tie ownership;
- preserve every other unit field, ability, shot count, rule, tactical-AI path, benchmark threshold, and non-Embercourt ordered row.

Completion criteria:
- focused live proof binds Bargebow unit HP and stack total health to `14`, covers casualties and save/normalization round trips, and keeps every other stat, ability, shot, growth, cost, count, formation, and authority exact;
- the corrected-RNG all-live 100-seed weeks-one-through-four matrix improves at least one of 34 outliers / `187.0` severity / three severe rows / `68.5` maximum dominance / `0.73` side bias without worsening any aggregate, keeps zero structural failures, reports every moved row, and keeps every non-Embercourt ordered row exact;
- the active 59-encounter breadth queue remains clear at signature `829808c9`, and focused, autoplay, balance-regression, core, editor, repository, JSON, Python, and diff gates pass.

Non-goals:
- no Bargebow ability, shots, damage, attack, defense, speed, initiative, resistance, cost, growth, count, formation, recruitment, or economy change;
- no Bogplate, Mireclaw, other-unit, BattleRules, BattleAiRules, hero, spell, encounter, save-schema, benchmark-method, threshold, faction/matchup/week/seed branch, Native RMG, packaging, or platform change;
- do not tune beyond `14` if the bounded candidate fails, or claim final faction balance, overall game completion, or release readiness.

Rejection result:
- the exact old-`13` control remains 34 outliers / `187.0` severity / three severe rows / `68.5` maximum dominance / `0.73` side bias / zero structural failures;
- HP `14` improves week-three Embercourt/Mireclaw from `68.5` to `64.5` percent Mireclaw dominance, but the decisive full matrix regresses to 32 outliers / `207.0` severity / five severe rows / `78.0` maximum dominance / `1.07` side bias / zero structural failures;
- all non-Embercourt ordered rows remain exact, while 20 Embercourt pair rows move and week-one Embercourt/Thornwake worsens from `67.5` to `78.0` percent Embercourt dominance;
- the candidate violates the registered no-aggregate-regression gate, so no production change, focused acceptance, active 59-encounter run, or tuning beyond `14` is authorized. A separate source-backed attribution audit is required before selecting any further balance candidate.
- the separate reciprocal week-one Embercourt/Thornwake audit identifies only the tier-three maximum-damage gap as causal, but both bounded midpoint screens also fail the full-matrix gate: Bargebow maximum damage `6` to `5` yields 35 outliers / `180.5` severity / two severe rows / `73.5` maximum dominance / `0.87` side bias / zero structural failures, while Sporeglass maximum damage `4` to `5` yields `38 / 204.5 / 4 / 68.5 / 1.27 / 0`;
- the Bargebow midpoint worsens outliers, maximum dominance, and side bias and moves week-three Embercourt/Mireclaw to `73.5` percent Mireclaw dominance; the Sporeglass midpoint worsens every aggregate except equal maximum dominance. Ownership isolation is exact, active breadth is intentionally unrun, and neither candidate is registered or implemented.

## Strategic AI Phase Target Descriptor Enumeration Reuse

id: `strategic-ai-phase-target-descriptor-enumeration-reuse-10184`

Status: completed.

Selected Phase 6 strategic-AI performance implementation slice. The current ordinal-100 Medium row
passes with exact signature `6e893020`, 36 completed turns, 172 enemy-activity events, zero target
integrity violations, and zero unreachable active targets, but repeated planning and spawn-origin scans
re-enumerate the same live target families. The selected boundary separates that immutable discovery
work from the origin-sensitive route, guard, distance, travel, valuation, and priority projection that
must remain fresh.

Implementation target:
- in `EnemyAdventureRules`, expose one detached, ordered descriptor surface covering siege target,
  defeat-objective towns, victory-objective towns, player towns, neutral towns, resource nodes,
  artifact nodes, encounters, delivery interceptions, and known heroes;
- preserve exact family order, source order, descriptor payload, and current seen/deduplication timing,
  including the existing rule that an eligible earlier duplicate claims its seen key before later
  reachability projection;
- keep every origin-sensitive route, staging, guard/reachability, goal tile, distance, travel,
  valuation, priority, reason, and final task payload calculation in a fresh projection per origin;
- reuse descriptors only within one `plan_enemy_hero_task_board` invocation and within one
  `EnemyTurnRules._best_open_spawn_point` sweep; rebuild on the next invocation and after any live
  mutation instead of introducing a global, day, session, or cross-launch cache;
- expose separate bounded counters for descriptor enumeration and per-origin projection without
  changing selection, scoring, rules, topology, content, or save state.

Completion criteria:
- strategic-planner old-versus-new proof requires byte/value-exact whole candidate arrays, payloads,
  and ordering across every descriptor family, duplicate identities, known and unscouted targets,
  unreachable and guarded targets, and multiple origins;
- spawn-selection proof requires exact selected tasks and spawn points, proves one-sweep reuse, and
  proves mutation and next-launch invalidation/rebuild while keeping each origin projection fresh;
- enumeration and projection counters distinguish the removed repeated discovery work from retained
  origin-dependent work;
- the ordinal-100 Medium row preserves signature `6e893020`, activity-event count and ordering,
  selected tasks, battle/outcome behavior, integrity, and unreachable-target authority, while target
  discovery, planner, and spawn work are materially reduced and row/max-turn runtime is not regressed;
- strategic-planner, spawn-selection, repository-validator, core, editor-parse, Python, JSON, and diff
  gates pass before completion is claimed.

Non-goals:
- no global/day/session cache, cross-invocation reuse, score or priority change, movement/path/guard
  rule change, topology, AI policy, task schema, content, balance, save migration, or Native RMG change;
- no broad strategic-AI completion, full performance completion, platform certification, or overall
  release-readiness claim.

Completion result:
- strategic-planner and spawn-selection focused reports pass independent legacy whole-array/payload
  parity across all ten target families, known/unscouted, duplicate, guarded, unreachable, multi-origin,
  mutation, no-open-point, and next-sweep rebuild cases;
- ordinal-100 retains exact signature `6e893020`, 36 turns, day-37 defeat, 172 events, two planned
  commander tasks, zero integrity or unreachable-target failures, and exact world authority;
- the five descriptor enumerations serve thirteen fresh origin projections with eight sweep-local
  reuses, removing `61.5` percent of repeated discovery in those descriptor-bearing sweeps; row runtime
  improves from `207674` to `205433` ms, maximum turn from `9293` to `8992` ms, planner work from
  `28296` to `26701` ms, spawn work from `14996` to `14297` ms, and fresh target discovery from
  `5736` to `4997` ms;
- focused compatibility, core, repository validator, Python, JSON, diff, exact/generic editor, Linux
  export plus packaged headless startup, and Windows export plus fresh-Wine Godot/Boot/MainMenu/native-
  DLL startup gates pass. The packaged harnesses did not exercise strategic-AI gameplay, so no packaged
  AI parity, controller, accessibility API, native hardware, Native RMG, signing/publication, whole-game,
  or whole-release claim is made.

## Strategic AI Known-World Target Catalog Projection Reuse

id: `strategic-ai-known-world-target-catalog-projection-reuse-10184`

Status: completed.

Selected Phase 6 strategic-AI performance implementation slice. Exact-current-code ordinal 100 keeps
signature `6e893020` and exact behavior authority, but initial known-world refresh consumes `13549` ms
and deferred post-move refresh consumes `13312` ms, or `26861` ms combined (`13.1` percent of the
`205433` ms row). Within each refresh, every sight source independently re-enumerates all towns,
resource nodes, artifact nodes, and encounters even though target eligibility and authored metadata are
source-invariant.

Implementation target:
- in `EnemyAdventureRules`, build one detached ordered sight-source surface and one detached ordered
  eligible-target catalog per `refresh_enemy_known_world_memory` invocation, covering towns, resources,
  artifacts, and encounters in the exact existing family/source order;
- reuse that invocation-local source surface for current hero and non-hero observation, and freshly
  project the eligible-target catalog for every source's radius, Manhattan distance, source identity,
  and memory metadata;
- preserve exact eligibility, content lookup, labels, priorities, per-source traversal, best-by-target
  minimum-distance then priority tie behavior, normalization/order, expiry, merge, and enemy-state sync;
- rebuild both surfaces on every later refresh, including the deferred post-move refresh after session
  mutation; do not introduce a day, session, global, or cross-refresh cache;
- expose bounded catalog-enumeration and per-source projection counters/timers without changing AI
  decisions, visibility, memory, save state, or public events.

Completion criteria:
- an independent current-materializer control and the catalog/projection path produce byte/value-exact
  whole ordered records across multiple overlapping sources, distance and priority ties, every family,
  collected/resolved/pressure-host/contestability exclusions, current hero sightings, and empty cases;
- detached source/catalog mutation cannot alter the session, and source removal, source movement, day
  expiry, target mutation, post-move refresh, and the next invocation rebuild exact current state;
- focused known-world coverage preserves exact memory, enemy-state, target-selection, source metadata,
  normalization, and save authority while proving one catalog enumeration serves multiple source
  projections;
- exact-current ordinal 100 preserves signature `6e893020`, event counts and order, tasks, day-37
  defeat, world counts/owners, battle outcomes, integrity, and unreachable-target authority; row and
  maximum-turn runtime do not regress, and combined initial/deferred known-world time is materially
  lower than the `26861` ms baseline;
- known-world, target-selection, hero-hunt, neutral-town, delivery, regroup, core, repository-validator,
  editor-parse, Python, JSON, diff, official Linux export/startup, and official Windows/fresh-Wine
  export/startup gates pass before completion is claimed.

Non-goals:
- no change to sight radii, target eligibility, labels, priority, tie order, visibility/fog rules,
  memory schema, expiry, merge policy, target selection, routing, movement, combat, economy, content,
  balance, save schema, or Native RMG;
- no cache across refreshes, turns, days, sessions, factions, or launches, and no reuse across live
  mutations;
- no packaged strategic-AI interaction, controller, AT-SPI/UIA, native-hardware, signing/publication,
  broad strategic-AI completion, full performance completion, whole-game, or whole-release claim.

Completion evidence:
- focused known-world runtime proves exact independent legacy parity, order, ties, exclusions, detach,
  movement/removal/expiry rebuilds, memory/session/save authority, and exact enumeration/projection counts;
- exact-current ordinal 100 retains signature `6e893020`, day-37 defeat after 36 turns, exact behavior,
  tasks, world/battle/integrity authority, and reduces combined known-world time from `26861` to `7463`
  ms while row runtime is `186149` ms and maximum-turn runtime is `8472` ms;
- known-world, target-selection, hero-hunt, neutral-town, delivery, regroup, core, repository, Python,
  JSON, diff, and editor gates pass; official Linux export/headless startup and Windows export/fresh-Wine
  Boot/MainMenu/native-DLL startup pass. These are bounded startup claims only, with no packaged AI
  interaction, controller, AT-SPI/UIA, native-hardware, signing/publication, whole-game, or release claim.

## Mireclaw Sporewake Rot Cant Priority Calibration

id: `combat-mireclaw-sporewake-rot-cant-priority-calibration-10184`

Status: completed.

Selected Phase 6 content-balance implementation slice. On exact current HEAD, week-two Brasshollow/Mireclaw is Mireclaw `61.5` percent across both ordered sides (`63/37` and `60/40`). A method-matched one-entry screen identifies Sporewake Rot Cant as the causal surface, and `ai_target_priority_bonus: 0.9` retains the opening ability while moving the ordered rows to `59/41` and `57/43`. The full all-live 100-seed four-week screen preserves all non-Mireclaw ordered rows and improves aggregate excess severity from `187.0` to `183.5` without worsening the `34` outliers, `3` severe rows, `68.5` maximum dominance, `0.73` side bias, or zero structural failures.

Implementation target:
- change only Sporewake Rot Cant's authored `ai_target_priority_bonus` from `1.0` to `0.9` in `content/units.json`;
- keep its round-one availability, tier-four target floor, once-per-battle use, status, duration, cohesion/retaliation pressure, wounded threshold/multiplier, description, and all other unit fields exact;
- keep shared BattleRules, BattleAiRules, benchmark algorithms, thresholds, seeds, formations, heroes, spells, scenarios, and faction content unchanged;
- update focused live ability proof and repository validation to require the exact `0.9` contract and an exact old-`1.0` AI-score control.

Completion criteria:
- focused live runtime proves the exact authored `0.9` bonus, round-one tier-four veteran eligibility, lower-tier rejection, bounded one-use status, unchanged wounded-prey effect, and a method-matched old-`1.0` score delta without changing target order or AI rules;
- the all-live 100-seed four-week matrix reproduces the accepted `34 / 183.5 / 3 / 68.5 / 0.73 / 0` aggregate, moves only Mireclaw-owned ordered rows, and keeps the exact week-two Brasshollow/Mireclaw `59/41` and reverse `57/43` results;
- the 59-scenario active autoplay breadth remains complete with zero queue items and signature `829808c9`;
- ability, battle/autoplay compatibility, core, repository-validator, JSON, Python, diff, editor-parse, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass before completion is claimed.

Completion result:
- the production content changes only Rot Cant's target-priority bonus from `1.0` to `0.9`; focused live runtime proves the exact authored contribution against zero-priority and old-`1.0` controls while all `118/118` authored ability instances retain live consequences;
- the authoritative all-live 100-seed four-week matrix is `34 / 183.5 / 3 / 68.5 / 0.73 / 0`, with week-two Brasshollow/Mireclaw at `59/41`, reverse at `57/43`, and every non-Mireclaw ordered row exact to the current control;
- active breadth completes `59/59` with no stalls, invalid orders, or queue items and repeated signature `829808c9`; runtime-consequence matrix and core compatibility pass;
- repository, JSON, Python, diff, exact/generic editor, Linux export plus packaged headless startup, and Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup gates pass. Platform evidence is bounded to export/startup and does not establish packaged battle interaction or broad release readiness.

Non-goals:
- no Rot Cant timing, tier gate, use count, status, duration, modifier, damage, summary, or ability-identity change;
- no other unit, hero, spell, faction, encounter, scenario, formation, combat rule, tactical-AI algorithm, benchmark branch/threshold, save, economy, strategic-AI, or Native RMG change;
- no opportunistic priority below `0.9`, broad faction-balance completion, packaged battle interaction, controller, accessibility API, native-hardware, signing/publication, whole-game, or release-readiness claim.

## Main Menu Campaign Scenery-First Command Rail

id: `ux-main-menu-campaign-scenery-first-command-rail-10184`

Status: complete.

Selected Phase 6 player-facing UX implementation slice. Current-head live campaign evidence reaches the completed three-chapter browser, but the Campaign submenu covers most of the scenic Main Menu with separate arc, chapter, commander, operational, and journal text panels. That shipped composition conflicts with the repository rule that scenic screens remain scenery-first and that detail exceeding a compact rail belongs in contextual disclosure rather than a panel farm.

Implementation target:
- keep the Campaign submenu as a compact left-side command rail by default, with authored arc and chapter selectors plus difficulty and launch/restart actions directly available;
- collapse selected-arc, selected-chapter, commander, operational, and journal panels behind one explicit `Show Intel` / `Hide Intel` contextual disclosure without deleting their exact content, tooltips, selection state, or accessibility copy;
- give every arc and chapter row its exact full production detail as a native item tooltip, and reset the disclosure to compact on each newly opened Campaign board;
- leave Skirmish, Load, Guide, Settings, first-view command plaques, campaign rules/progression, launch/save behavior, and authored content unchanged.

Completion criteria:
- at 1280x720 and 1920x1080, the default Campaign board occupies at most 56 percent of viewport width and 60 percent of viewport height, keeps at least 40 percent of the scenic width uncovered before the right command plaques, and contains every visible control without overlap or clipping;
- default view exposes arc/chapter selection, difficulty, primary/chapter launch, and permitted restart actions while all five detail surfaces are collapsed; one real `Show Intel` action reveals the exact existing full detail surfaces inside the bounded scroll rail and `Hide Intel` restores the compact view;
- arc and chapter item order, ids, labels, full tooltips, selection, campaign/chapter actions, difficulty, restart confirmation, focus/cancel return, campaign storage authority, and full routed campaign completion remain exact;
- focused layout/action coverage, campaign-menu, keyboard/controller navigation, campaign restart, menu/outcome, full routed campaign, core, repository, Python, JSON, diff, and editor gates pass;
- official Linux export plus packaged headless startup and Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass before completion is claimed.

Completed evidence: the default Campaign board is now a 52.8%-wide, at-most-60%-high left rail with all authored selectors and actions directly available, exact arc/chapter details retained as native tooltips, and the five deeper detail surfaces collapsed behind one real `Show Intel` / `Hide Intel` disclosure. Focused 1280x720 and 1920x1080 interaction/authority coverage, campaign restart, keyboard/controller navigation, menu/outcome, core, and the fresh 121-step three-chapter routed campaign all pass. Official Linux export/headless startup and Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup also pass; these are bounded startup claims, not packaged Campaign interaction or whole-release certification.

Non-goals:
- no campaign rule, progression, scenario, commander, difficulty, save, content, balance, strategic-AI, battle, map, or Native RMG change;
- no Skirmish/Load/Guide/Settings redesign, first-view plaque redesign, global UI-scale rewrite, new modal framework, or removal of authored campaign detail;
- no packaged Campaign interaction, controller hardware, AT-SPI/UIA, native-hardware, signing/publication, whole-game, or release-readiness claim.

## Main Menu Campaign Launch Action Deduplication

id: `ux-main-menu-campaign-launch-action-deduplication-10184`

Status: complete.

Selected Phase 6 player-facing UX implementation slice. Fresh current-head live evidence shows the compact Campaign rail rendering two identical `Start Chapter 1: Break the Pass` actions. Source confirms that `CampaignRules.build_start_action` returns the exact `build_chapter_action` payload when the selected scenario is already the primary campaign scenario, so the second button is duplicate affordance rather than separate authority.

Implementation target:
- keep the primary campaign action visible and hide only the selected-chapter button when its whole production action payload is exact to the primary action;
- restore the selected-chapter button whenever the selected action is distinct, including locked, replay, retry, or non-primary chapter selection;
- preserve both action payloads, labels, tooltips, disabled state, selection, focus, campaign storage, launch, restart, and progression authority.

Completion criteria:
- at 1280x720 and 1920x1080, the default primary chapter exposes exactly one launch affordance while the rest of the scenery-first rail geometry remains bounded and exact;
- selecting a distinct locked or non-primary chapter reveals its exact selected-chapter action without changing the primary action, and returning to the primary chapter collapses the duplicate again;
- actual primary and distinct chapter launch signals, keyboard/controller focus/cancel, restart, menu/outcome, full routed campaign, storage/save authority, and ordered campaign/chapter content remain exact;
- focused, compatibility, core, repository, Python, JSON, diff, editor, Linux export/headless startup, and Windows export/fresh-Wine startup gates pass.

Non-goals:
- no campaign action construction, campaign rules/progression, chapter unlock/status, difficulty, restart, save, scenario, content, balance, AI, battle, map, or Native RMG change;
- no broader Campaign rail, first-view, Skirmish/Load/Guide/Settings, modal, or UI-scale redesign;
- no packaged Campaign interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- the default whole-equal primary/selected action now exposes one launch affordance at 1280x720 and 1920x1080, while a distinct locked chapter restores the exact selected action and returning to the primary chapter collapses it again;
- focused authority, keyboard/controller navigation, restart, menu/outcome, core, and the 121-step routed campaign ending at `campaign_arc_completed_browser` are green;
- repository/editor checks and official Linux export/headless startup plus Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green, without a packaged Campaign interaction or broader release claim.

## Main Menu Campaign Contextual Dock Height

id: `ux-main-menu-campaign-contextual-dock-height-10184`

Status: complete.

Selected Phase 6 player-facing UX corrective slice. Fresh current-head visual evidence shows that the default Intel-collapsed Campaign board still reserves the full expanded 60% viewport height, leaving a large empty dark panel over the scenery. Source confirms the Campaign dock uses one static anchor rectangle for both collapsed and expanded disclosure states.

Implementation target:
- keep the default Intel-collapsed Campaign dock compact enough to contain its visible selectors and actions without reserving the hidden detail area;
- expand to the existing bounded Campaign height only while Intel is shown, then restore the compact height exactly when Intel is hidden or the Campaign board is reopened;
- preserve width, right-side scenic space, scrolling, focus, action visibility, ordered rows, selection, storage, and campaign authority.

Completion criteria:
- at 1280x720 and 1920x1080, the collapsed dock is at most 46% viewport height, contains every visible Campaign control, and leaves the existing scenic width uncovered;
- opening Intel expands the dock to the existing at-most-60% height with all six detail surfaces visible, retains toggle focus, and closing Intel restores the exact compact layout;
- default and distinct chapter action deduplication, campaign rows/tooltips, storage/session authority, keyboard/controller navigation, restart, menu/outcome, core, and the routed campaign remain exact;
- repository, Python, JSON, diff, editor, Linux export/headless startup, and Windows export/fresh-Wine startup gates pass.

Non-goals:
- no campaign data, action construction, progression, unlock/status, difficulty, restart, save, scenario, content, balance, AI, battle, map, or Native RMG change;
- no Campaign width, first-view, other submenu, modal, global UI-scale, or theme redesign;
- no packaged Campaign interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- at 1280x720 and 1920x1080, the collapsed Campaign dock is 44% viewport height with all visible controls contained, Intel expands to the existing 60% height, and hiding Intel restores the exact compact rectangle;
- focused authority, keyboard/controller navigation, restart, menu/outcome, core, and a fresh 121-step routed campaign ending at `campaign_arc_completed_browser` are green, and its current-head screenshot confirms the lower-left scenery is no longer covered by hidden-detail space;
- repository/editor checks and official Linux export/headless startup plus Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green, without a packaged Campaign interaction or broader release claim.

## Town Faction Scenic Stage Backdrops

id: `presentation-town-faction-scenic-stage-backdrops-10184`

Status: complete.

Selected Phase 6 shipped-content and player-facing presentation slice. Fresh current-HEAD live campaign evidence is behaviorally green through all three Reedfall chapters, but the Town stage still spends its dominant surface on generic procedural rectangles, circles, polylines, and polygons. This reads as a placeholder geometry mockup instead of a scenery-first production Town screen.

Implementation target:
- ship one original painterly 16:9 Town panorama for each of Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn, with no text, logos, characters, UI, or copyrighted designs;
- select the exact backdrop from the live active Town faction and cover-crop it inside the existing framed stage without stretching or changing Town layout;
- retain the existing header, status plaques, districts, command markers, hit regions, focus, actions, and authority over the scenic layer;
- retain the current procedural Town stage as a fail-safe when the live faction has no mapped or loadable backdrop.

Completion criteria:
- all six faction assets are distinct, original, readable at 1280x720 and 1920x1080, imported by Godot, and mapped one-to-one to the authored faction ids;
- focused live Town validation proves exact faction selection, cover-crop containment, overlay order, unknown-faction fallback, and unchanged session, town, action, focus, save, route, and campaign authority;
- current Town, battle, menu/outcome, core, and the 121-step routed Reedfall campaign remain green, with current-head visual inspection confirming scenery-first Town composition;
- repository, Python, JSON, diff, editor, Linux export/headless startup, and Windows export/fresh-Wine startup gates pass with the six assets present in packaged payloads.

Non-goals:
- no Town rules, buildings, districts, economy, recruitment, magic, logistics, recovery, threat, actions, focus, save, route, scenario, campaign, combat, AI, balance, map, or Native RMG change;
- no Town shell geometry, command rail, modal, global UI-scale, accessibility semantics, animation, character art, or other screen redesign;
- no packaged Town interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- six distinct original 1600x900 faction panoramas are imported and mapped one-to-one, while two-size focused runtime proves exact cover crop, source/destination containment, overlay order, unknown-faction fallback, and unchanged session authority;
- natural headless and Xvfb Town/Battle smokes pass, with inspected 1280x720 and 1920x1080 captures confirming that scenery is the dominant Town surface and the existing status, district, command, header, and action surfaces remain readable;
- Town exit, active-play focus, menu/outcome, core, and a fresh 121-step routed Reedfall campaign ending at `campaign_arc_completed_browser` pass;
- repository/editor checks and official Linux export/headless startup plus Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass, with all six imported textures present in both PCKs and no packaged Town interaction or broader release claim.

## Scenario Outcome Scenic Epilogue Stage

id: `presentation-scenario-outcome-scenic-epilogue-stage-10184`

Status: complete.

Selected Phase 6 shipped-content and player-facing presentation slice. A fresh current-HEAD 1920x1080 Outcome render shows the full screen as a flat dark panel farm: the only visual is a small procedural shield-and-lines diagram, while an oversized empty `ActionsPanel` covers the dominant lower-left surface. This directly contradicts the scenery-first screen-composition boundary.

Implementation target:
- ship distinct original 16:9 victory and defeat epilogue panoramas with no text, logos, UI, characters, bodies, or copyrighted designs;
- select the exact full-screen panorama from the live terminal scenario status and cover-crop it without stretching;
- make the existing information cards and action surface translucent, and let the action panel shrink to its actual content so the central/lower stage remains scenic rather than an empty black box;
- retain the existing procedural Outcome banner and flat status palette as a fail-safe when the status has no mapped or loadable panorama.

Completion criteria:
- both status assets are distinct, original, imported, and exact 1600x900 images mapped one-to-one to `victory` and `defeat`;
- focused 1280x720 and 1920x1080 live validation proves exact status selection, cover-crop behavior, non-stretched rendering, compact action-panel geometry, translucent information surfaces, readable controls, and fail-safe fallback;
- outcome model, summaries, tabs, actions, save/overwrite, focus, keyboard/controller navigation, recovery, routing, session, progression, and campaign authority remain exact;
- outcome visual, normal-entry focus, new-session safe cancel, recovery, active-play focus, core, routed campaign, repository, editor, Linux export/headless startup, and Windows export/fresh-Wine startup gates pass.

Non-goals:
- no outcome rules, progression, rewards, actions, copy, tabs, save format/version, routing, focus order, input timing, campaign, scenario, combat, AI, balance, map, or Native RMG change;
- no new character art, animation, video, global theme, UI-scale, accessibility semantics, modal, or other screen redesign;
- no packaged Outcome interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- two distinct original 1600x900 victory/defeat panoramas are imported and mapped one-to-one, while focused 1280x720 and 1920x1080 runtime proof covers exact status selection, non-stretched cover crop, flat fallback, translucent surfaces, compact action geometry, and unchanged session authority;
- inspected live victory and defeat captures are scenery-first and readable, and Outcome visual, normal-entry focus, new-session safe cancel, autosave recovery, active-play focus, and core compatibility gates pass;
- a fresh routed Reedfall campaign completes all 121 public route/town/battle/save/resume/Outcome steps through `campaign_arc_completed_browser`;
- repository/editor checks and official Linux export/headless startup plus Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass, with both imported Outcome textures present in the packaged PCK and no packaged Outcome interaction or broader release claim.

## Authored Artifact Icon Adoption

id: `presentation-authored-artifact-icon-adoption-10184`

Selected Phase 6 production-art and live-UX slice. All 12 shipped artifact
records still expose `*_placeholder` icon identities, no artifact icon asset
domain exists under `art/`, and the live Overworld and Town gear action buttons
render text only even though each action resolves one exact owned artifact.

Implementation target:
- produce one coherent original 12-icon artifact set matching the existing painterly fantasy UI and store the project-consumed runtime assets under a dedicated artifact-art domain;
- replace every placeholder artifact icon identity with one unique stable icon id and exact imported path while preserving all non-UI artifact content byte-for-byte;
- make ArtifactRules management actions carry the exact equipped or packed artifact id already owned by the action, then let the existing Overworld and Town gear buttons load its validated icon fail-closed;
- keep the compact action labels, tooltips, order, disabled state, focus, sizing, and equip/stow consequences unchanged at 1280x720 and 1920x1080.

Completion criteria:
- all 12 production artifacts load one distinct non-placeholder icon asset with exact content-to-asset ownership and no missing import;
- real live equip and stow actions in both Overworld and Town show the matching artifact icon while preserving the exact ordered action arrays, button text/tooltips, focus cycle, containment, and whole session/save authority;
- missing or invalid icon metadata yields a text-only button without errors or action changes;
- focused visual/runtime proof, artifact acquisition/slot/rendezvous/town compatibility, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- do not change artifact bonuses, rarity, slot/set rules, inventory/equipment ordering, acquisition/reward tables, economy, movement, scouting, spells, AI valuation, save schema/version, or artifact action consequences;
- do not add a new panel, enlarge the gear rails, cover the map or scenic stage, or change non-artifact buttons;
- do not claim final artifact VFX/audio, packaged artifact interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release readiness.

Completed evidence:
- one coherent original 4x3 painted atlas produced 12 exact 128x128 imported runtime icons, and every production artifact now owns a unique `artifact_icon_*` id and `res://art/artifacts/runtime/` path;
- the live Overworld Command drawer and Town Logistics tab render the exact equipped or packed artifact icon with a bounded 24px theme width while preserving the existing button copy, tooltip, disabled state, binding, and action order;
- the focused report passes real equip/stow presses on both surfaces at 1280x720 and 1920x1080 with whole-session equality against independent rule controls, exact visibility/containment, invalid-id fail-closed behavior, and all 12 icon imports;
- artifact slot presentation, faction/content taxonomy, runtime set effects, field rendezvous transfer, Town/Battle visuals, accessibility semantics, core systems, repository validation, and exact/generic editor parses pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass with no packaged artifact-interaction or broader release claim.

## Live Spell School Sigil Adoption

id: `presentation-live-spell-school-sigil-adoption-10184`

Selected Phase 6 production-art and live-UX slice. All 112 shipped spell records
already belong to the seven authored Beacon, Mire, Lens, Root, Furnace, Veil, and
Old Measure schools, and the magic foundation requires material-language school
identity rather than hue alone. No school-sigil asset domain exists, and the live
Overworld cast, Town study, and Battle cast buttons render text only.

Implementation target:
- produce one coherent original seven-sigil set whose distinct shapes and materials follow the exact authored school language, and store the project-consumed runtime assets under a dedicated magic-school art domain;
- add one exact data-driven school-to-icon manifest and a fail-closed SpellRules resolver so every shipped spell maps through its existing school id without duplicating UI metadata across 112 records;
- render the resolved school sigil on the existing compact Overworld cast, Town study, and Battle cast buttons without changing their labels, tooltips, order, disabled state, focus, sizing, or actions;
- preserve the seven-school content contract and all spell learning, mana, targeting, casting, consequence, save, and AI authority.

Completion criteria:
- all seven schools load one distinct original imported sigil with exact manifest ownership, and every one of the 112 production spells resolves to its school asset with no missing or placeholder identity;
- real live cast/learn/cast actions across Overworld, Town, and Battle show the matching school sigil at 1280x720 and 1920x1080 while preserving exact ordered action arrays, button copy/tooltips, focus cycle, containment, and whole session/save authority against independent rules controls;
- missing, unsupported, or invalid school icon metadata yields a text-only button without errors or action changes;
- focused runtime, magic/Town/Battle compatibility, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- do not claim unique per-spell illustrations; these seven sigils are permanent school/category identity assets rather than substitutes for future spell-specific art;
- do not change spell names, schools, tiers, costs, effects, target modes, spellbooks, learning rules, mana, balance, VFX/audio, AI valuation, save schema/version, or action consequences;
- do not add panels, enlarge command rails, cover the map/battle/town stage, or change non-spell buttons;
- do not claim packaged spell interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release readiness.

Completed evidence:
- one coherent original atlas produced seven distinct 128x128 imported runtime sigils, and one exact manifest owns their stable school, icon, asset, and material-language identities;
- every production spell resolves through its existing school id without per-spell UI metadata, and invalid or unsupported metadata fails closed to the existing text-only action;
- the live Overworld, Town, and Battle spell actions render the exact sigil at a bounded 24px theme width while preserving their existing labels, tooltips, disabled state, focus order, containment, and bindings;
- the focused report passes real Waystride cast, Town study, and Stone Veil battle-cast consequences at 1280x720 and 1920x1080 with whole-session equality against independent rule controls and unchanged save summaries;
- magic schema and behavior, field spell cue, spell sharing, Town/Battle visuals, accessibility semantics, core systems, repository validation, and exact/generic editor parses pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, without a packaged spell-interaction or broader release claim.

## Town Building Category Sigil Adoption

id: `presentation-town-building-category-sigil-adoption-10184`

Selected Phase 6 production-art and live Town UX slice. The 133 shipped building
records already use exactly five stable categories: civic, dwelling, economy,
support, and magic. The existing compact Build plan exposes real selectable
construction actions but renders them as text only, while the production screen
wireframe calls for compact building iconography.

Implementation target:
- produce one coherent original five-sigil set with shape-first civic, dwelling, economy, support, and magic construction identities under a dedicated Town building-category art domain;
- add one exact category-to-icon manifest and fail-closed resolver so every production building maps through its existing category without duplicating icon metadata across 133 records;
- render the resolved category sigil on the existing selectable Build option buttons without changing labels, tooltips, order, toggle state, readiness, focus, sizing, or construction actions;
- preserve building content, costs, prerequisites, daily limits, town progression, save, and strategic-AI authority.

Completion criteria:
- all five categories load one distinct original imported sigil with exact manifest ownership, and every production building resolves to its category asset;
- real live Build selection and construction at 1280x720 and 1920x1080 show the matching sigil while preserving exact option arrays, copy/tooltips, focus cycle, containment, whole session/save authority, and independent construction consequences;
- missing, unsupported, or invalid category icon metadata yields a text-only option without errors or action changes;
- focused runtime, town construction/economy, Town visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- do not claim unique per-building illustrations; these five sigils are permanent category identity assets rather than substitutes for future building-specific art;
- do not change building ids, names, categories, costs, prerequisites, unlocks, effects, build limits, town balance, save schema/version, or strategic-AI policy;
- do not add panels, enlarge the Build rail, cover the Town stage, or change non-build actions;
- do not claim packaged construction interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release readiness.

Completed evidence:
- one coherent original atlas produced five distinct 128x128 imported runtime sigils, and one exact manifest owns their stable civic, dwelling, economy, support, and magic identities;
- every production building resolves through its existing category without duplicated per-building UI metadata, and invalid or unsupported metadata fails closed to the existing text-only option;
- the live selectable Build options render the exact category sigil at a bounded 24px width while preserving their labels, tooltips, toggle/readiness state, focus order, containment, and binding;
- the focused report passes real selection and construction at 1280x720 and 1920x1080 with whole-session equality against an independent rule-plus-recap control and save version 9 unchanged;
- the building-completion cue, all 15 authored town save/resume cases, Town/Battle visuals, accessibility semantics, core systems, repository validation, and exact/generic editor parses pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, without a packaged construction-interaction or broader release claim.

## Production Resource Registry And Collection Icon Adoption

id: `economy-production-resource-registry-collection-icon-adoption-10184`

State: completed on 2026-08-15. Production owns the exact ordered nine-row
registry and nine unique original alpha icons. Focused collection proof passed
all four 1280x720/1920x1080 normal/reduced-motion rows with whole-session,
recap, cue, resolution, refresh, and fail-closed authority intact. Compatibility
covered all 20 active authored rare-source collection/income cases, the live
stockpile and Town resource surfaces, Overworld visual composition,
accessibility, and core systems. Official Linux export/headless startup and
Windows export/fresh-Wine Boot/MainMenu/native-DLL startup passed. These are
bounded export/startup claims, not packaged resource interaction or release
certification.

Selected Phase 6 economy architecture and live-readability slice. Gold, wood,
ore, Aetherglass, Embergrain, Peatwax, Verdant grafts, Brass scrip, and Memory
salt are authoritative live stockpile ids, but their display/category/material
metadata remains fixture-only and their collection commands are text-only.

Implementation target:
- promote the exact nine stockpile definitions into production content with stable display, category, market-tier, ordering, affinity, material, and original icon ownership;
- keep `wood` and all other save/cost ids byte-stable, with no save-version or balance change;
- resolve exact resource identity from the selected live resource site and show its icon on existing compact primary/context collection actions, fail-closed when metadata or imports are invalid;
- preserve action copy, tooltip, order, disabled state, focus, containment, collection result, recap, resource delta cue, and save authority.

Completion criteria:
- production owns exactly nine stockpile resources and nine distinct original imported 128x128 icons, while the strict fixture agrees with the production registry rather than remaining the only authority;
- real live resource-site collection at 1280x720 and 1920x1080 shows the exact yielded-resource icon and matches an independent rules control for stockpile, site, recap, cue, session, and save authority;
- invalid resource/action/icon metadata remains text-only without errors or action changes;
- economy registry/schema, resource-site collection, live stockpile/Town economy, Overworld visual/accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- do not change resource ids, amounts, costs, income, market access/rates/caps, sites, source placement, faction affinity, AI valuation, save schema/version, or collection consequences;
- do not add a full-width resource dashboard, new panel, broad resource-bar redesign, pickup art, site art, or non-resource action icons;
- do not claim packaged collection interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, or release readiness.

## Shared Resource Stockpile Icon Popover

id: `ux-shared-resource-stockpile-icon-popover-10184`

State: completed on 2026-08-15. The Town and Overworld stockpile controls now
reuse one production `ResourceStockpileMenu`. Focused live proof passed all four
1280x720/1920x1080 shell rows with exact nine-row order, icons, amounts, popup
containment, Escape closure, focus return, session/action/save authority, and
the physical 1280 compact width exact. Compatibility, static/editor, and
bounded Linux/Windows export/startup gates are green.

Selected Phase 6 live-UX and resource-readability slice. It reuses the existing
Town top bar and Overworld command band rather than adding a dashboard.

Implementation target:
- add one shared compact stockpile menu component that consumes only detached live stockpile values and the production resource resolver;
- replace the two existing passive resource labels with that focusable menu while preserving their visible summary and full-ledger tooltip contracts;
- populate the native popup with the exact ordered nine resources, exact imported icons, display names, and current amounts, failing closed per invalid row;
- keep the Overworld control available in a bounded compact `Stores` form at 1280x720 and restore the existing summary form at wider sizes;
- close cleanly on `ui_cancel`, preserve focus return, and never mutate session, economy, save, action, or routing authority.

Completion criteria:
- real Town and Overworld shells at 1280x720 and 1920x1080 open the same exact nine-row icon menu through public input, with stable order, amounts, accessible item text/tooltips, containment, and focus return;
- an invalid registry row is omitted, while an invalid icon leaves that exact registered resource text-only; neither case invents identity, changes an amount, or blocks opening the remaining ledger;
- existing visible summary and tooltip/economy readability contracts remain exact, with the compact Overworld resource control staying within the command band;
- focused runtime, Town economy, Overworld visual, keyboard focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- do not change resource ids, amounts, ordering, costs, income, market rules, source sites, AI valuation, save schema/version, or any economy consequence;
- do not add a full-width dashboard, persistent panel, top-level screen, new resource art, pickup/site art, or unrelated icon work;
- do not claim packaged popover interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release readiness.

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
- The source-backed native release matrix is byte-exact for 24 selected workflows across Small through Extra Large, land/normal-water/Islands, and one/two levels.
- Runtime package/session adoption is authorized only for that parity-owned matrix; unsupported configurations and allocator histories remain fail-closed.
- The H3MapEd recovery ledger is prerequisite evidence and source ownership, not permission to claim arbitrary H3MapEd configuration parity.
- Player-facing generated-skirmish controls now adopt the same 24-workflow boundary instead of retaining the older Small/Medium surface-land fence.
- Native/generated package adoption evidence must remain scoped to the selected release matrix and must not be presented as whole-H3MapEd parity.

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

Owner direction has reopened narrow Phase 6 product fixes while Phase 5 debt remains. Select bounded live settings, accessibility, packaging, or performance defects with direct runtime validation; do not claim the broad phase complete until Phase 5 playable-alpha evidence and all Phase 6 release criteria are stable.

### Phase 7 - Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with the systemic breadth, density, and replayability expected from classic Heroes-style strategy games.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or the owner explicitly changes priorities.

## Town Faction Crest Adoption

id: `presentation-town-faction-crest-adoption-10184`

Status: complete.

Selected Phase 6 shipped-content and player-facing presentation slice. The six production factions already own distinct names, authored identity language, unit ladders, buildings, heroes, and scenic Town panoramas, but the existing live Town crest medallion renders the same procedural `town` glyph for every active faction. No production faction-crest asset domain or exact resolver exists.

Implementation target:
- ship one coherent set of six distinct original imported faction crests whose shape and material language follows the authored Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn identities;
- own the exact faction-to-crest mapping through production content and a fail-closed rules resolver;
- render the exact live active-Town faction crest inside the existing crest medallion without changing its rectangle, label, focus order, hit regions, or Town layout;
- retain the existing procedural `town` glyph whenever faction metadata is missing, unmapped, or unloadable.

Completion criteria:
- all six production faction ids map one-to-one to six distinct imported crests, with exact source/runtime asset ownership and no placeholder identity;
- real Town shells at 1280x720 and 1920x1080 render the exact active faction crest with containment, aspect, tooltip, overlay order, unknown-faction fallback, and whole Town/session/save/action/focus authority unchanged;
- all-faction Town/save, Town visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually drives the Town surface.

Non-goals:
- no faction ids, names, rules, economy, recruitment, units, heroes, buildings, towns, scenarios, campaign, combat, AI, balance, save schema, map, or Native RMG changes;
- no Town stage/backdrop, crest-medallion geometry, layout, focus order, input, other screen, global theme, UI-scale, or broad heraldry redesign;
- no packaged Town interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- six distinct original 256x256 alpha crests and one exact ordered faction manifest load through production content and rules ownership;
- live Town shells at 1280x720 and 1920x1080 render all six identities in the unchanged 74x50 medallion with a contained 42x40 icon, exact tooltip, and procedural unknown-faction fallback;
- focused authority preserves the exact session, action catalog, route, layout, focus, and save version 9;
- all-faction Town/save, Town visual, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup gates pass;
- packaged Town interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.

## Overworld Faction Town Sprite Adoption

id: `presentation-overworld-faction-town-sprite-adoption-10184`

Status: complete.

Selected Phase 6 shipped-content and player-facing presentation slice. The live Overworld owns exact town placements and town templates for six production factions, but `_draw_town_sprite` always loads the single `frontier_town` placeholder. This collapses faction identity on the primary play surface even though faction Town panoramas and crests are now authored.

Implementation target:
- ship one coherent set of six distinct original imported overworld town sprites whose silhouettes and material language match Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn;
- own the exact faction-to-sprite mapping in the existing overworld art manifest and resolve the live town template faction without adding gameplay state;
- draw the resolved sprite through the existing Town footprint, grounding, memory modulation, owner pennant, contact, and approach path;
- retain `frontier_town` whenever town placement/template/faction metadata is missing, unmapped, or unloadable.

Completion criteria:
- all six production faction ids map one-to-one to six distinct imported sprites, while all 15 authored town ids resolve through their exact faction and invalid identity falls back to `frontier_town`;
- real Overworld maps at 1280x720 and 1920x1080 render all six faction town sprites with exact containment, footprint, owner pennant, visible/remembered treatment, selection/hit authority, and route/passability unchanged;
- Ninefold six-faction breadth, Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually drives and observes the Overworld town surface.

Non-goals:
- no town ids/templates/placements, faction rules, economy, buildings, recruitment, garrisons, ownership, capture, AI, balance, save schema, map topology, footprints, passability, routing, or Native RMG changes;
- no Town-screen backdrop/crest/layout changes, no owner-pennant redesign, no other overworld object families, no terrain/road/river art changes, and no broad map-renderer rewrite;
- no packaged Overworld interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- six distinct original 512x512 alpha sprites map in exact production faction order through the existing overworld art manifest, with the original 1536x1024 atlas retained as source provenance;
- all six Ninefold town placements resolve through their live town template faction at 1280x720 and 1920x1080, and the invalid-template control resolves only to `frontier_town`;
- focused live presentation preserves the existing 3x2 footprint, bottom-middle visit entry, blocked non-entry cells, no-ellipse grounding, owner color/pennant path, shell containment, whole-session restoration, and save version 9;
- Ninefold, broad Overworld visual, active-play focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup gates pass;
- packaged Overworld interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release readiness remain unclaimed.

## Overworld Artifact Pickup Icon Adoption

id: `presentation-overworld-artifact-pickup-icon-adoption-10184`

Status: complete.

Selected Phase 6 shipped-content and player-facing presentation slice. All 12 production artifacts already own distinct imported 128x128 icons and every normalized map pickup carries an exact `artifact_id`, but `_draw_artifact_sprite` ignores that node identity and always renders `adventurers_bundle`.

Implementation target:
- resolve each live pickup through its existing `artifact_id` and validated `ArtifactRules.artifact_icon_path` without changing artifact content or placement state;
- cache and draw the exact icon through the existing pickup footprint, grounding, current explored/visible treatment, and draw order;
- retain `adventurers_bundle` when the artifact id, metadata, import, or texture is missing or invalid;
- expose detached validation evidence for exact artifact id, icon path, chosen presentation, and fallback while leaving session/save authority untouched.

Completion criteria:
- all 12 production artifact ids render one-to-one through their existing distinct imported icons, while invalid identity falls back only to `adventurers_bundle`;
- real Overworld views at 1280x720 and 1920x1080 preserve exact pickup footprint, grounding, current explored/visible treatment, selection, collection/depletion, fog, route, session, and save version 9 authority;
- artifact pickup/source and object-resolution compatibility, Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually drives and observes an artifact pickup.

Non-goals:
- no new art, artifact ids/content/bonuses/rarity/slots/sets/reward tables, placement selection, acquisition, auto-equip, economy, movement, scouting, AI, balance, save schema, map topology, or Native RMG changes;
- no gear-button, Town, cue, layout, focus, input, other object-family, terrain/road/river, or broad renderer redesign;
- no packaged artifact interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- all 12 existing imported 128x128 artifact icons resolve one-to-one from each normalized pickup's exact artifact id, while malformed identity resolves only to the existing `adventurers_bundle` fallback;
- focused live 1280x720 and 1920x1080 proof covers all 12 identities, exact icon paths and asset ids, current explored/visible semantics, 1x1 footprint, localized grounding, fallback, full restoration, containment, and save version 9;
- artifact pickup source, object-resolution cue, broad Overworld visual, active-play focus, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged artifact interaction or broader release claim.

## Overworld Faction Hero Sprite Adoption

id: `presentation-overworld-faction-hero-sprite-adoption-10184`

Status: completed.

Selected Phase 6 shipped-content and player-facing presentation slice. All 60 production hero records already carry exact faction identity and the map index carries exact hero ids, but `_draw_hero_marker` renders one shared procedural figure for every commander.

Implementation target:
- ship one coherent set of six distinct original alpha commander sprites for Embercourt, Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn;
- map faction to sprite in the existing Overworld art manifest and resolve each indexed hero id through existing ContentService hero faction metadata;
- draw the resolved sprite through the existing hero grounding, movement interpolation, active/reserve stacking badge, and foreground-contact path;
- retain the existing procedural hero marker whenever hero id, faction metadata, manifest mapping, import, or texture is missing.

Completion criteria:
- all 60 production heroes resolve through exact faction to one of six distinct imported sprites, while invalid identity uses only the procedural marker;
- real 1280x720 and 1920x1080 Overworld views preserve exact hero position, active identity, movement path/interpolation, reserve count, grounding/contact, selection, routing, session, and save version 9 authority;
- six-faction scenario breadth, broad Overworld visual, route locomotion, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually drives and observes hero movement.

Non-goals:
- no hero ids/names/portraits/rosters/stats/specialties/spells/armies/recruitment, faction rules, movement/pathfinding, AI, balance, save schema, map topology, or Native RMG changes;
- no 60-hero sprite set, hero portrait replacement, Town/Battle/Outcome UI, input/focus, camera, other object family, terrain/road/river, or broad renderer rewrite;
- no packaged hero interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completed evidence:
- six distinct original 512x512 alpha commander sprites resolve one-to-one from the six production faction ids, and all 60 production heroes retain exact existing faction metadata;
- focused live 1280x720 and 1920x1080 proof covers exact sprite ids and paths, active identity, movement-compatible presentation, reserve/grounding/contact contracts, procedural fallback, whole-session restoration, containment, and save version 9;
- full-route movement, Ninefold scenario breadth, broad Overworld visual, active-play focus, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged hero interaction or broader release claim.

## Overworld Field Spell VFX Asset Adoption

id: `presentation-overworld-field-spell-vfx-asset-adoption-10184`

Status: completed.

Selected Phase 6 player-facing presentation slice. Successful live movement-restoration and scouting-reveal spells already publish the exact `spell_cast_overworld` event and `vfx_placeholder_adventure_spell` cue at the authoritative hero tile, but normal playback still draws only two procedural cast rings plus the existing compact spell icon. The completed field-spell cue-playback slice explicitly left final VFX assets out of scope.

Implementation target:
- add one original source image and one 512x512 runtime alpha texture for Overworld field-spell casting;
- extend the existing Overworld VFX manifest with exactly `vfx_placeholder_adventure_spell` mapped to `spell_cast_overworld`;
- render it at the authoritative hero tile using the current progress, alpha, input-blocking, refresh, skip, and expiry authority, while retaining the existing icon above it;
- preserve the current two cast rings and icon as exact missing-map or missing-texture fallback, while reduced motion continues using only the static `adventure_spell_icon` contract.

Completion criteria:
- normal live field-spell playback selects and visibly draws the exact imported texture at 1280x720 and 1920x1080 without remapping object-resolution or any Battle/Town cue;
- missing manifest rows or unloadable textures use the existing two-ring procedural body without errors, replay, input drift, or state mutation;
- focused live proof preserves exact mana/movement/fog/recap consequences, hero tile, progress, blocking/skip/expiry, refresh, focus, route, session, and save version 9 authority;
- field-spell cue, magic hooks, object-resolution asset, Overworld visual/route/input, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no spell, mana, movement, fog, visibility, recap, route, focus, input, timing, animation-policy, AI, save-schema, or content changes;
- no object-resolution, Town/Battle cue, particles, shaders, audio, spell icon, layout, terrain, or broad renderer rewrite;
- no packaged field-spell interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Town Recruitment VFX Asset Adoption

id: `presentation-town-recruitment-vfx-asset-adoption-10184`

Status: completed.

Selected Phase 6 player-facing presentation slice. Successful live player recruitment already publishes the exact `town_units_recruited` event and `vfx_placeholder_recruit_muster` cue after authoritative Town refresh, but normal playback still draws only three procedural muster rings around the existing contained count badge. The completed recruitment cue-playback slice explicitly left final VFX assets out of scope.

Implementation target:
- add one original source image and one 512x512 runtime alpha texture for recruitment confirmation;
- extend the existing Town VFX manifest with exactly `vfx_placeholder_recruit_muster` mapped to `town_units_recruited`;
- render it behind the existing contained muster badge/text using the current progress, alpha, nonblocking lifetime, refresh, and expiry authority;
- preserve the current three muster rings and badge/text body as exact missing-map or missing-texture fallback, while reduced motion continues using the existing static `recruit_count_badge` contract.

Completion criteria:
- normal recruitment playback selects and visibly draws the exact imported texture at 1280x720 and 1920x1080 without remapping construction or any other Town/Battle/Overworld cue;
- missing manifest rows or unloadable textures use the existing three-ring procedural body without errors, replay, input drift, or state mutation;
- focused live proof preserves exact recruitment consequences, contained stage geometry, progress, nonblocking lifetime, refresh, expiry, focus, session, and save version 9 authority;
- recruitment cue, Town visual/action, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- one original 1254x1254 source image yields one 512x512 alpha runtime texture, and the exact Town manifest maps only construction and recruitment cues to their matching events and render modes;
- focused live 1280x720 and 1920x1080 proof observes the imported draw, exact missing-texture three-ring fallback, static reduced-motion badge, containment, nonblocking behavior, exact recruitment consequences, unchanged post-recruit session authority, and save version 9;
- the real recruitment and construction cues, construction asset, Town/Battle visual, active-play focus, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged recruitment interaction or broader release claim.

Non-goals:
- no unit, cost, availability, recruitment, army, town-state, focus, input, timing, animation-policy, AI, save-schema, or content changes;
- no construction VFX, other Town/Overworld/Battle cue, particles, shaders, audio, layout, scenic backdrop, or broad renderer rewrite;
- no packaged recruitment interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Town Building Complete VFX Asset Adoption

id: `presentation-town-building-complete-vfx-asset-adoption-10184`

Status: completed.

Selected Phase 6 player-facing presentation slice. Successful real Town construction already publishes the exact `town_building_built` event and `vfx_placeholder_build_complete` cue through the live Town stage, but normal playback still draws only a pulsing procedural outline around the existing build-complete badge. The prior cue-playback slice explicitly left final VFX assets out of scope.

Implementation target:
- add one original source image and one 512x512 runtime alpha texture for construction completion;
- map exactly `vfx_placeholder_build_complete` to the imported texture through a small Town VFX manifest;
- render it behind the existing contained badge and text using the current progress/alpha and input-blocking lifetime;
- preserve the current gold frame and badge/text body as exact missing-map or missing-texture fallback, while reduced motion continues using the existing static `building_badge_added` contract.

Completion criteria:
- the normal building-complete cue selects and visibly draws the exact imported texture at 1280x720 and 1920x1080 without remapping recruitment or any other Town/Battle/Overworld cue;
- missing manifest rows or unloadable textures use the existing procedural frame without errors, replay, input drift, or state mutation;
- focused live proof preserves exact building consequence, stage rect containment, progress, blocking/skip/expiry, reduced-motion, focus, session, and save version 9 authority;
- building-complete playback, Town visual/action, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- one original 1254x1254 source image yields one 512x512 alpha runtime texture, and the exact Town manifest maps only `vfx_placeholder_build_complete` to the matching event and render mode;
- focused live 1280x720 and 1920x1080 proof observes the imported draw, exact missing-texture gold-frame fallback, static reduced-motion badge, containment, input-blocking split, unchanged session authority, and save version 9;
- the real construction cue, Town/Battle visual, active-play focus, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged building interaction or broader release claim.

Non-goals:
- no building, cost, economy, action, construction, town-state, focus, input, timing, animation-policy, AI, save-schema, or content changes;
- no recruitment VFX, other Town/Overworld/Battle cue, particles, shaders, audio, layout, scenic backdrop, or broad renderer rewrite;
- no packaged building interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Overworld Object Resolution VFX Asset Adoption

id: `presentation-overworld-object-resolution-vfx-asset-adoption-10184`

Status: completed.

Selected Phase 6 player-facing presentation slice. Successful live object capture, repeatable-site visit, and depletion already publish one bounded view-only presentation at the exact authoritative map tile, but `_draw_object_resolution_presentation` still renders all three states as generic procedural geometry. The earlier cue-playback slice explicitly left final VFX assets out of scope.

Implementation target:
- add one original three-effect source atlas and three distinct runtime alpha textures for capture, visited, and depleted states;
- map exactly `vfx_placeholder_capture_flag`, `vfx_placeholder_object_visit`, and `vfx_placeholder_depleted_dim` through a small production manifest;
- render the mapped texture at the existing authoritative tile with existing progress, alpha, motion/reduced-motion, and dynamic-layer ownership;
- preserve the current procedural capture, visit, and depletion bodies as exact missing-map or missing-texture fallback.

Completion criteria:
- all three existing object-resolution event ids select one distinct exact imported texture and no other Overworld or Battle cue is remapped;
- missing manifest rows or unloadable textures use the existing procedural function for the same event without errors, replay, or state mutation;
- focused 1280x720 and 1920x1080 live proof preserves exact event/tile/progress/reduced-motion/session/save authority and observes asset-first plus procedural fallback behavior;
- object-resolution, repeatable-site, guarded-site, full-route, broad Overworld visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- one original three-panel source atlas yields three distinct 512x512 alpha runtime textures, and the exact local manifest maps only capture, visit, and depleted cue ids to their matching event and texture;
- focused live 1280x720 and 1920x1080 proof observes six imported texture draws, six missing-texture procedural fallbacks, six reduced-motion procedural fallbacks, exact containment, unchanged session authority, and save version 9;
- object-resolution playback (including persistent capture, repeatable visit, guarded context, neutral-town capture, artifact depletion, and reduced motion), full-route movement, broad Overworld visual, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged object-interaction or broader release claim.

Non-goals:
- no object, resource, artifact, reward, capture, visit, depletion, route, movement, fog, input, timing, animation-policy, AI, save-schema, map-topology, or Native-RMG changes;
- no other Overworld cue, Battle VFX, particles, shaders, audio, object sprites, layout, focus, or broad renderer rewrite;
- no packaged object interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Overworld Enemy Commander Sprite Adoption

id: `presentation-overworld-enemy-commander-sprite-adoption-10184`

Status: completed.

Selected Phase 6 player-facing presentation slice. Strategic raids materialize into live encounter rows with exact spawning faction and `enemy_commander_state.roster_hero_id`, but `_draw_encounter_sprite` currently skips that identity and renders only the primary army unit icon or the existing encounter fallback.

Implementation target:
- resolve only a valid strategic-raid commander whose roster hero, commander faction, spawning faction, and authored hero faction agree;
- reuse the existing six faction commander textures inside the current hostile encounter ring, visibility/memory treatment, grounding, and contact path;
- retain the exact current primary-unit icon and mapped/default encounter sprite paths whenever commander identity or texture is absent, invalid, or mismatched;
- expose detached presentation evidence without changing encounter/session authority.

Completion criteria:
- six valid faction raid commanders resolve one-to-one to the shipped faction sprites, while commanderless, unknown, mismatched, or unloadable rows keep the current unit/camp fallback;
- real 1280x720 and 1920x1080 Overworld views preserve exact encounter tile, hostile treatment, fog/remembered semantics, selection, routing, battle payload, commander state, session, and save version 9 authority;
- focused raid presentation, strategic commander continuity, hero-hunt/raid movement, broad Overworld visual, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually observes a strategic raid marker.

Non-goals:
- no hero, unit, encounter, raid, commander-roster, target, movement, fog, battle, AI, balance, save-schema, map-topology, or Native-RMG changes;
- no new assets, per-hero Overworld sprites, player-hero changes, army unit-icon replacement, encounter ring redesign, other object family, or broad renderer rewrite;
- no packaged raid interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- the live encounter draw path prefers the strict commander identity resolver, then preserves the primary-unit icon and mapped/default encounter fallback in exact order;
- focused live proof covers all six faction sprites and four fail-closed identity cases at 1280x720 and 1920x1080 with exact restoration, containment, and save version 9;
- commander selection, hero hunt, full-route movement, broad Overworld visual, active-play focus, accessibility, core, repository validation, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged raid-interaction or broader release claim.

## Selected Slice: Overworld Hero Route-Step VFX Asset Adoption

Slice id: `presentation-overworld-hero-route-step-vfx-asset-adoption-10184`

Implementation boundary:
- create one original source image and one bounded alpha runtime texture for the existing `vfx_placeholder_route_step` cue;
- map only that cue to `overworld_hero_move` through the existing Overworld VFX manifest and draw it behind the existing interpolated hero marker on the dynamic layer;
- retain exact interpolation-only behavior for missing mapping/texture and the current zero-duration `route_endpoint_snap` reduced-motion path;
- preserve exact route tiles/steps, segment interpolation, hero sprite/grounding, duration, progress, refresh lifecycle, route/session/save authority, and all existing Overworld VFX mappings.

Completion criteria:
- normal hero-route playback visibly draws the exact imported texture behind the unchanged hero marker at 1280x720 and 1920x1080, while missing asset and reduced motion retain the unchanged interpolation/endpoint-snap behavior;
- focused and real route proof preserves exact path/steps, interpolated centers/segments, duration/progress, dynamic-only playback, refresh/expiry lifecycle, session authority, and save version 9;
- hero-route cue, existing Overworld VFX assets, broad visual/route/input, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass;
- packaged claims remain bounded to export/startup unless a packaged harness actually observes the route-step effect.

Non-goals:
- no route, pathfinding, action, selection, movement consequence, hero identity/sprite, fog, focus, input, timing, animation-policy, AI, save-schema, content, or map changes;
- no other object/guard/spell/Town/Battle VFX, particles, shaders, audio, layout, terrain, camera, or broad renderer changes;
- no packaged route interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- focused 1280x720 and 1920x1080 runtime proves imported draw center/rotation/containment, exact missing-texture interpolation fallback, exact reduced-motion endpoint snap, session authority, and save version 9;
- the real full-route regression proves policy-derived VFX identity, actual four-step route/interpolated center, dynamic-only progress, refresh/expiry lifecycle, and unchanged route consequences;
- seven-cue object/spell/guard/blocked-route/hero-route VFX, Overworld visual/input, active-play focus, accessibility, core, repository, and exact/generic editor gates pass;
- official Linux export plus packaged headless startup and official Windows export plus fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass, with no packaged route interaction or broader release claim.

## Selected Slice: Overworld Action Feedback VFX Asset Adoption

Slice id: `presentation-overworld-action-feedback-vfx-asset-adoption-10184`

Implementation boundary:
- create one original source atlas and four bounded alpha runtime textures for the existing `vfx_placeholder_artifact_claim`, `vfx_placeholder_slot_equip`, `vfx_placeholder_slot_unequip`, and `vfx_placeholder_resource_delta` cues;
- map only those four cues through the existing Overworld VFX manifest and render each compactly beside the unchanged live artifact/resource feedback text inside the existing command rail;
- retain exact text-only behavior for missing manifest rows or unloadable textures and retain the catalog's existing reduced-motion static fallback identities without importing or animating a normal-motion effect;
- preserve exact artifact/resource consequences, label text/tooltips, input-blocking policy, focus, cue lifetime/progress, refresh/expiry behavior, containment, session authority, save version 9, and all existing Overworld VFX mappings.

Completion criteria:
- normal artifact recovery/equip/stow and resource collection each select and visibly render one distinct exact imported texture at 1280x720 and 1920x1080 without remapping any other cue;
- missing mapping/texture stays fail-closed and text-only, while reduced motion keeps the exact existing static fallback cue and no normal imported effect;
- focused and real action proof preserves event/action/content identity, consequences, text/tooltip, duration/progress, blocking/nonblocking behavior, focus, refresh/expiry lifecycle, session authority, and save version 9;
- artifact acquired/slot and resource-delta cue owners, existing Overworld VFX assets, broad Overworld visual/input/focus/accessibility/core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- four distinct 512x512 alpha runtime effects from one retained 1536x1024 source atlas render through the exact existing artifact/resource cue ids inside the compact bottom command rail at both registered widths;
- missing assets and reduced motion remain exact text-only fallbacks, while real artifact/resource actions preserve independent-rule consequences, input/focus/lifecycle behavior, session authority, and save version 9;
- the focused and compatibility runtime chains, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup are green with bounded claims only.

Non-goals:
- no artifact, resource, reward, inventory, slot, economy, route, object, input, focus, timing, animation-policy, AI, save-schema, content, or map changes;
- no panel expansion, dashboard, command ordering, broader layout redesign, other Overworld/Town/Battle/UI cue, particles, shaders, audio, or global renderer changes;
- no packaged action interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Active-Play System Feedback VFX Asset Adoption

Slice id: `presentation-active-play-system-feedback-vfx-asset-adoption-10184`

Implementation boundary:
- create one original source atlas and two bounded alpha runtime textures for the existing `vfx_placeholder_save_confirm` and `vfx_placeholder_load_resume` cues;
- map only those exact cue ids in a local system-feedback VFX manifest and render them non-blockingly inside the existing save button or status-control bounds through the existing live presenters on Overworld, Town, Battle, and Scenario Outcome;
- retain exact text/tint behavior with no imported icon for reduced motion, missing manifest rows, or unloadable textures;
- preserve save/load payloads, serialization/schema/routing, cue policy and timing, labels/tooltips, layout minima, focus/input, session/settings authority, and every other cue.

Completion criteria:
- normal live save-written and load-resumed playback each visibly renders one distinct exact imported texture at 1280x720 and 1920x1080 on all four active-play surfaces;
- imported icons remain contained, nonblocking, and layout-neutral, while reduced motion and missing mapping/texture remain exact text/tint-only fallbacks;
- focused real save/load proof preserves payload/version/path, label/tooltip, duration/progress, focus, lifecycle, session/settings authority, and existing cross-surface behavior;
- save-written/load-resumed cue owners, save/load compatibility, animation cue policy/catalog, accessibility/core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- one retained 1672x941 alpha source atlas produces two distinct 512x512 alpha runtime textures mapped only to the exact save-confirm and load-resume cue ids;
- focused asset/fallback proof passes at both registered widths, and real save plus cross-scene Main Menu load matrices pass all four surfaces in normal and reduced-motion modes at both widths with exact focus/layout/session/settings/save authority;
- manual overwrite, save/load confidence, keyboard focus, accessibility, animation cue catalog, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass with bounded claims only.

Non-goals:
- no save/load serialization, schema, routing, slot, recovery, autosave, gameplay, session, settings, focus, input, cue timing, or animation-policy changes;
- no panel expansion, status copy rewrite, layout redesign, particles, shaders, audio, other cue/event assets, or global renderer changes;
- no packaged save/load interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Object Focus Cue Adoption

Slice id: `presentation-overworld-object-focus-cue-adoption-10184`

Status: completed.

Completion evidence:
- the live Shell focused report passes at 1280x720 and 1920x1080 with exact Bramble Wall and Brightwood Sawmill body identity, imported object-blocked VFX and 44.1 kHz stereo audio, unchanged-refresh/identical-selection dedupe, real reselection, hidden identity suppression, terrain/unreachable controls, and exact session/save authority;
- reduced-motion and missing-asset runs use the distinct static/procedural object fallback, while the existing generic blocked-route, full-route movement, object-focus, animation-catalog, Overworld visual, and core owners remain green;
- repository/editor validation passes, and official Linux export/headless startup plus Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass with no packaged interaction, accessibility, controller, hardware, signing, publication, whole-game, or release-readiness claim.

Implementation boundary:
- deliver the already-authored `overworld_object_active` catalog cue for an actual user selection of one visible, unguarded town, resource, artifact, or encounter;
- add one original focus-ring source image, one bounded alpha runtime texture, one deterministic production presentation sound, and exact manifest mappings for `vfx_placeholder_object_focus_ring` and `audio_placeholder_object_focus`;
- accept the cue only after selected tile, object kind/stable identity, visibility, catalog policy, and guarded-site precedence agree, then draw/play it once per newly accepted selection context without unchanged-refresh replay;
- preserve programmatic opening/reset selection silence, hero/open/hidden/adjacent-immediate-action silence, guarded warning precedence, and all existing route/object-resolution behavior.

Completion criteria:
- real pointer and keyboard/D-pad route-cursor selection produce the exact imported focus ring and one exact audio play for all four object families at 1280x720 and 1920x1080;
- unchanged refresh does not replay, while leaving the object and genuinely reselecting it does; guarded, hidden, malformed, stale, hero, open, initial, and immediate-action contexts remain fail-closed and silent;
- selection, route/action consequences, guarded-site warning, VFX/audio fallback and reduced-motion policy, focus/input, session/settings/save authority, and all other cue mappings remain exact;
- focused and compatibility runtime, repository/editor validation, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass with bounded claims.

Completion evidence:
- real pointer selection for visible town/resource/artifact/encounter contexts passes at physical 1280x720 and 1920x1080, with imported normal-mode focus art, missing-asset and reduced-motion outline fallbacks, exact one-shot audio, unchanged-refresh dedupe, and genuine-reselection replay;
- keyboard/D-pad route-cursor selection and guarded-site precedence pass while programmatic selection remains silent and session/save authority remains exact;
- all five existing Overworld VFX manifest owners, object-resolution playback, animation catalog, visual composition, active-play focus, accessibility, core, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass;
- platform evidence is export/startup only: packaged object-focus interaction/listening, hardware controller, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release-readiness remain unclaimed.

Non-goals:
- no object, route, movement, reward, guard, fog, action, AI, save/schema, content, or map-topology changes;
- no hover cue, initial/programmatic-selection cue, adjacent action pre-cue, broad object highlighting, particles, shaders, camera, layout, spatial audio, haptics, or final sound mastering;
- no packaged object-focus interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Blocking Object Feedback

id: `presentation-overworld-blocking-object-feedback-10184`

Status: completed.

Implementation boundary:
- expose one detached read-only blocking-object surface from the existing `OverworldRules` blocked-tile inputs for `map_objects` and resource-node body tiles, preserving their production array order and exact body-tile rules;
- when a visible selected blocked tile is owned by that surface, use the exact object/content name and the already-authored `overworld_object_blocked` cue; keep terrain blockers and route-unreachable cases on the existing `overworld_route_blocked` path;
- add one original alpha VFX and one deterministic production presentation sound mapped only to `vfx_placeholder_object_blocked_marker` and `audio_placeholder_blocked_object`, with the current procedural marker and silent playback remaining fail-closed fallbacks;
- preserve pathfinding, blocked indexes, object interaction/visit tiles, fog knowledge, selection/route authority, cue dedupe/lifetime, input/focus, session/settings/save state, and every existing cue mapping.

Completion criteria:
- live visible blocking map-object and resource-body selections at 1280x720 and 1920x1080 report the exact object identity and play/draw one object-blocked cue instead of misnaming the underlying passable terrain;
- hidden or merely remembered blockers do not leak object identity, while rock/water terrain and route-unreachable controls remain exact route-blocked presentations;
- unchanged refresh dedupes, genuine reselection replays once, reduced motion and missing assets retain the exact static/procedural fallback, and malformed/stale payloads fail closed;
- focused object-body/terrain/unreachable proof plus Overworld visual, blocked-route, object-pathing, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass with bounded claims.

Non-goals:
- no pathfinding, passability, body/interaction tiles, object placement/content, rewards, route decisions, movement, fog, AI, Native RMG, save/schema, or map-topology changes;
- no hover/ambient loop, route-open/route-closed adoption, panel/layout redesign, particles, shaders, spatial audio, haptics, or global renderer changes;
- no packaged object interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Field Route-Response Open Feedback

id: `presentation-overworld-field-route-response-open-feedback-10184`

Status: completed.

Implementation boundary:
- after the existing live Overworld context-action path successfully commits `site_response`, derive one detached route-open presentation from its exact post-action recap, placement/site identity, tile, and authored `overworld_route_open` policy;
- add one original alpha VFX and one deterministic production presentation sound mapped only to `vfx_placeholder_route_open` and `audio_placeholder_route_open`, with distinct reduced-motion and missing-asset fallbacks;
- accept and play the cue only after the Overworld Shell confirms success, exact response recap kind, live active response state, visible site tile, and matching stable placement; dedupe unchanged refresh/duplicate serial while allowing a later independently issued response;
- preserve route-response resources/movement/duration/delivery/transit/recovery consequences, route/pathing, input/focus, settings, session/save authority, and every existing presentation mapping.

Completion criteria:
- one real successful field response at 1280x720 and 1920x1080 publishes the exact site identity and route-open event, draws the imported VFX, and plays one exact audio record after MapView accepts it;
- failed, unaffordable, movement-exhausted, already-active, malformed, hidden, stale, and non-response actions remain silent, while unchanged refresh and duplicate payloads do not replay;
- reduced motion uses the exact static route-open fallback and missing assets use a distinct procedural fallback; generic route-blocked, object-blocked, object-focus, guarded, and object-resolution cues remain exact;
- focused Rope Lift/ordinary response proof plus transit, visual, cue-catalog, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass with bounded claims.

Non-goals:
- no response-order availability, resource/movement costs, duration, delivery, transit, recovery, routing/pathfinding, fog, AI, Native RMG, save/schema, content, or map-topology changes;
- no Town-screen response presentation, enemy-driven `overworld_route_closed` adoption, hover/ambient loops, layout redesign, particles, shaders, spatial audio, haptics, or final sound mastering;
- no packaged route-response interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Enemy Route-Closure Feedback

id: `presentation-overworld-enemy-route-closure-feedback-10184`

Status: completed.

Implementation boundary:
- at the two existing enemy resource-seizure mutation points, add one exact `route_closed` public reason code only when the pre-seizure player site response is still active; retain the existing `ai_site_seized` event type, compact public-event boundary, summary, controller transition, event ordering, and all seizure/disruption consequences;
- after a successful live end-turn rule result and autosave, select at most one exact visible compact route-closure event, resolve its stable resource placement against the already-mutated live session, and publish the authored `overworld_route_closed` cue through the existing object-resolution serial/queue without string parsing or inferred expiry;
- add one original alpha VFX and one deterministic production presentation sound mapped only to `vfx_placeholder_route_closed` and `audio_placeholder_route_closed`, with distinct reduced-motion and missing-asset fallbacks;
- preserve enemy target policy, movement, capture, rewards, pressure, task continuation, response/transit/delivery clearing, event privacy/order/limit, end-turn/autosave/battle/outcome routing, selection/input/focus, settings, session/save authority, and every other presentation mapping.

Completion criteria:
- a real enemy turn at 1280x720 and 1920x1080 seizes a player-controlled site with an active response route, closes the exact persisted transit edge, retains the exact compact `ai_site_seized` event, and draws/plays one `overworld_route_closed` presentation for the visible site after successful autosave;
- ordinary player-site seizure without an active response, natural response expiry, hidden/malformed/stale/non-resource events, autosave failure, battle/outcome routing, unchanged refresh, and duplicate payloads remain silent and cannot spoof a closure;
- reduced motion uses the exact static route-closed fallback and missing assets use a distinct procedural fallback; route-open, route-blocked, object-blocked, object-focus, guarded, and generic object-resolution cues remain exact;
- focused live end-turn proof plus enemy live-turn/event-boundary, Rope Lift, visual, cue-catalog, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass with bounded claims.

Non-goals:
- no enemy strategy, target scoring, movement, seizure eligibility, rewards, disruption pressure, task policy, response cost/duration, transit/pathfinding, delivery, fog, event visibility/limit, save/schema, content, Native RMG, or map-topology changes;
- no natural-expiry presentation, Town-screen response presentation, multi-closure carousel, hover/ambient loops, layout redesign, particles, shaders, spatial audio, haptics, or final sound mastering;
- no packaged route-closure interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Route-Expiry Feedback

id: `presentation-overworld-route-expiry-feedback-10184`

Status: completed.

Implementation boundary:
- before the real end-turn rule call, capture detached player-controlled resource responses whose exact `response_until_day` equals the current day and whose linked transit edge is live; after successful autosave and no battle/outcome routing, validate the same resource remains player-controlled, visible, unchanged in identity/provenance, and inactive solely because the day advanced;
- publish at most one `overworld_route_closed` cue through the existing object-resolution serial/queue, reusing the shipped closure VFX/audio and distinguishing expiry ownership in the presentation family/metadata without changing the animation catalog or sound assets;
- give enemy-seizure closure priority and keep autosave failure, routing, hidden/malformed/stale candidates, non-final-day responses, refresh, and duplicates silent;
- preserve response duration/provenance fields, transit/pathfinding, enemy behavior/events, end-turn/autosave, session/save, selection/input/focus, settings, and every other presentation mapping.

Completion criteria:
- real Shell end-turn at 1280x720 and 1920x1080 advances an active final-day Rope Lift response to inactive, closes its exact transit edge, keeps response provenance persisted, saves the post-turn state, and draws/plays one imported `overworld_route_closed` presentation;
- non-final-day, already-expired, enemy-seized, hidden, malformed, autosave-failed, battle/outcome-routed, refresh, and duplicate controls remain silent, with enemy route closure retaining priority;
- reduced-motion and missing-asset fallbacks remain exact while route-open, enemy-closure, route-blocked, object-blocked, guarded, and generic resolution cues remain unchanged;
- focused expiry, enemy closure/open-route, Rope Lift, visual, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass with bounded claims.

Non-goals:
- no response duration/cost/provenance clearing, transit/pathfinding, enemy AI/event, fog, save/schema, content, Native RMG, animation-catalog, VFX, audio-asset, or map-topology changes;
- no Town-screen expiry presentation, multi-expiry carousel, hover/ambient loops, layout, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged expiry interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Town Route-Response Dispatch Feedback

id: `presentation-town-route-response-dispatch-feedback-10184`

Status: completed.

Implementation boundary:
- after the real Town response action succeeds, validate the exact `site_response:<placement>` action and `site_response` recap, then publish one new Town-surface queue-resolved/nonblocking presentation through TownStageView;
- add one original alpha VFX and one deterministic stereo sound with distinct reduced-motion and missing-asset procedural fallbacks;
- preserve TownRules/OverworldRules response mutation, cost/duration/transit, recaps, focus/input, session/save, existing build/recruit presentations, and the separate Overworld route-open cue.

Completion criteria:
- live TownShell 1280x720/1920x1080 response orders activate the exact route and present one imported Town dispatch VFX/audio cue;
- failed, stale, malformed, non-site, refresh, and duplicate controls remain silent; reduced-motion and missing-asset fallbacks are exact;
- focused Town response plus Town action, route, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no response cost/duration/transit/pathfinding, Town economy, enemy AI, fog, save/schema, Native RMG, or map-topology changes;
- no Overworld cue remap, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

Validated result:
- the public Town action dispatcher now emits the unique Town route-response cue only after the exact core action, cache invalidation, resolution guard, and refreshed live stage;
- six focused rows cover 1280x720 and 1920x1080 in normal imported, missing-asset procedural, and reduced-motion static modes with exact core-control session parity, active Town provenance, one imported WAV cue, and silent repeat rejection;
- both prior Town VFX reports, both Town cue reports, the animation catalog, broad Town/Battle visual smoke, core systems, repository/editor checks, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass.

## Selected Slice: Town Market Exchange Completion Feedback

id: `presentation-town-market-exchange-completion-feedback-10184`

Status: completed.

Implementation boundary:
- after the real Town market action succeeds, validate the exact `market:<buy|sell>:<wood|ore>:<amount>` action and derive its exact signed stockpile deltas from the existing Town consequence signatures before publishing one new Town-surface queue-resolved/nonblocking presentation through TownStageView;
- add one original alpha VFX and one deterministic stereo sound with distinct reduced-motion and missing-asset procedural fallbacks;
- preserve TownRules/OverworldRules quote, rate, cost, gain, weekly-cap, recap, focus/input, session/save, common-only market, and all completed Town action-presentation behavior.

Completion criteria:
- live TownShell 1280x720/1920x1080 buy and sell orders execute through the public handler, match method-equivalent core controls, and present exact imported Town exchange VFX/audio with signed input/output stockpile evidence;
- failed, stale, malformed, non-market, and refresh controls remain silent; reduced-motion and missing-asset fallbacks are exact;
- market cap usage, rates, resources, recaps, focus/input, session/save, build/recruit/route presentations, and existing generic UI cues remain exact;
- focused exchange plus market-cap, Town action, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no market rates, costs, gains, caps, rare-resource policy, AI economy, build/recruit affordability, save/schema, Native RMG, or map-topology changes;
- no generic UI cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged exchange interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

Validated result:
- the public Town market handler now publishes only after the exact successful transaction, cache invalidation, resolution guard, and refreshed stage; the presentation validates the action grammar and ordered gold/common-resource deltas without changing rates, gains, costs, caps, or save authority;
- six focused rows cover 1280x720 and 1920x1080 in normal imported, missing-asset procedural, and reduced-motion static modes, with four buy rows, two sell rows, whole-session parity against detached TownRules controls, exact market usage, one imported WAV cue, and silent malformed/invalid controls;
- market-cap persistence, both Town VFX reports, both prior Town cue reports, route feedback, the animation catalog, broad Town/Battle visual smoke, core systems, repository/editor checks, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass.

## Selected Slice: Town Spell Study Completion Feedback

id: `presentation-town-spell-study-completion-feedback-10184`

Status: completed.

Implementation boundary:
- after the real public Town study action succeeds, validate the exact `learn_spell:<spell_id>` action and active-hero spellbook transition before publishing one Town-surface queue-resolved/nonblocking presentation through TownStageView;
- add one original alpha VFX and one deterministic stereo sound with distinct reduced-motion and missing-asset procedural fallbacks;
- preserve SpellRules/TownRules spell access, hero/spellbook/mana, study readiness, recap, focus/input, session/save, and all completed Town presentation behavior.

Completion criteria:
- live TownShell 1280x720/1920x1080 study orders execute through the public handler, match method-equivalent TownRules controls, and present exact imported Town archive-study VFX/audio with one newly learned spell and unchanged mana;
- failed, already-known, malformed, non-study, and refresh controls remain silent; reduced-motion and missing-asset fallbacks are exact;
- spell catalog/access, school/context identity, active hero, spellbook normalization, study readiness, recaps, focus/input, session/save, and prior Town presentations remain exact;
- focused study plus spell-school icon, Town action/VFX/cue, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no spell effects, mana cost, school, tier, catalog access, AI study policy, hero progression, save/schema, Native RMG, or map-topology changes;
- no generic UI cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged study interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

Validated result:
- the public Town study handler now publishes only after the exact successful learn action, recap, cache invalidation, resolution guard, and refreshed stage; it validates a one-spell active-hero spellbook increase while preserving mana, spell catalog/access, hero mirroring, session/save, and failed-action silence;
- six focused rows cover 1280x720 and 1920x1080 in normal imported, missing-asset procedural, and reduced-motion static modes with whole-session parity against detached TownRules controls and exactly one imported 400 ms stereo cue;
- spell-school icon, both Town VFX reports, building/recruitment cue playback, route and market feedback, animation catalog, broad Town/Battle visual smoke, core systems, repository/editor checks, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass.

## Selected Slice: Town Hero Hire Completion Feedback

id: `presentation-town-hero-hire-completion-feedback-10184`

Status: completed.

Implementation boundary:
- after the real public Town tavern action succeeds, validate the exact `hire_hero:<hero_id>` action, one-hero player roster increase, recruited hero identity, and exact resource spend before publishing one Town-surface queue-resolved/nonblocking presentation through TownStageView;
- add one original alpha VFX and one deterministic stereo sound with distinct reduced-motion and missing-asset procedural fallbacks;
- preserve HeroCommandRules/TownRules availability, hero templates/cost/limit, active hero, action recap, focus/input, session/save, and all completed Town presentation behavior.

Completion criteria:
- live TownShell 1280x720/1920x1080 tavern orders execute through the public handler, match method-equivalent TownRules controls, and present exact imported commander-arrival VFX/audio for exactly one newly recruited hero and exact cost;
- failed, already-hired, unaffordable, malformed, non-tavern, and refresh controls remain silent; reduced-motion and missing-asset fallbacks are exact;
- hero catalog/availability, recruited hero payload, active hero, player roster, resources, hero limit, recaps, focus/input, session/save, and prior Town presentations remain exact;
- focused hire plus hero-command, Town action/VFX/cue, visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no hero templates, recruitment cost, hero limit, starting army, roster availability, active-hero selection, AI hiring, save/schema, Native RMG, or map-topology changes;
- no generic UI cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged hire interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

Validated result:
- the public Town tavern handler now publishes only after the exact successful hire action, recap, cache invalidation, resolution guard, and refreshed stage; it validates one new player hero, authored identity/cost, exact resource deltas, unchanged active hero, and failed-action silence;
- six focused rows cover 1280x720 and 1920x1080 in normal imported, missing-asset procedural, and reduced-motion static modes with whole-session parity against detached TownRules controls and exactly one imported 420 ms stereo cue;
- Town building/recruitment VFX and cue playback, route/market/spell feedback, animation catalog, Town/Battle visual smoke, core systems, repository/editor checks, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass.

## Selected Slice: Town Artifact Action Feedback

id: `presentation-town-artifact-action-feedback-10184`

Status: completed.

Implementation boundary:
- after the real public Town artifact action succeeds and the stage refreshes, reuse the existing artifact-acquired, artifact-equipped, or artifact-unequipped policy and deterministic audio through TownStageView;
- for commissions, validate the exact one-time town service building, artifact reward/provenance, resource cost, owned location, and recap; for equip/stow, validate the exact artifact identity, previous/current slot, and active-hero mirror transition;
- render the production artifact icon fail-closed with a compact procedural fallback, while preserving the shared Town input blocker only for the existing normal artifact-acquired policy.

Completion criteria:
- live TownShell 1280x720/1920x1080 public commission/equip/stow actions match method-equivalent TownRules controls and publish the exact existing artifact cue/audio policies with production icons;
- failed, stale, unaffordable, repeated, malformed, refresh, and non-artifact controls remain silent; reduced-motion and missing-icon fallbacks are exact;
- artifact reward tables, service costs/provenance, ownership, inventory/equipment, movement, active-hero mirroring, recaps, focus/input, session/save, and prior Overworld/Town presentations remain exact;
- focused artifact action plus artifact commission/icon/runtime, Town cue/visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no artifact content, reward tables, commission costs, inventory/equipment rules, movement bonuses, auto-equip policy, Town buildings, hero progression, save/schema, AI, Native RMG, or map-topology changes;
- no new artifact art/audio, generic cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged artifact interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Town Specialty Selection Feedback

id: `presentation-town-specialty-selection-feedback-10184`

Status: completed.

Implementation boundary:
- after the real public Town specialty action succeeds and the stage refreshes, validate the exact active hero, one-rank specialty increase, consumed pending choice, remaining-choice count, and recap before publishing one compact queue-resolved/nonblocking TownStage presentation;
- use a semantic Town event with the existing production UI confirmation audio and a compact procedural specialty badge, including an exact reduced-motion static fallback;
- preserve HeroProgressionRules/TownRules availability and mutation authority, hero progression payload, active-hero mirroring, focus/input, session/save, and all completed Town presentations.

Completion criteria:
- live TownShell 1280x720/1920x1080 public specialty actions match method-equivalent TownRules controls and publish the exact selected specialty, new rank, hero identity, and remaining pending-choice count once;
- failed, stale, unavailable, malformed, repeated, refresh, and non-specialty controls remain silent; normal and reduced-motion rendering are exact;
- specialty definitions/ranks/effects, hero level/experience/command, active hero, recaps, focus/input, session/save, and prior Town presentations remain exact;
- focused specialty action plus hero-progression, Town cue/visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Validated result:
- the public Town handler derives the semantic presentation only from an exact one-rank specialty increase, one consumed pending choice, preserved hero identity, mirrored active hero, and successful recap after the authoritative refresh;
- TownStage renders a compact specialty-rank sigil/badge, uses the existing imported UI-confirm cue, and fails closed for malformed, stale, invalid, repeated, refresh, and non-specialty paths;
- the focused four-row 1280x720/1920x1080 normal/reduced report, twelve compatibility owners, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup all pass.

Non-goals:
- no specialty definitions, ranks, effects, choice cadence, level thresholds, hero stats, AI choice policy, save/schema, Native RMG, or map-topology changes;
- no new art/audio, generic UI cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged specialty interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Resource Assault Victory Return Feedback

id: `presentation-overworld-resource-assault-victory-return-feedback-10184`

Status: completed.

Implementation boundary:
- after a real player victory over a stationed resource defender has transferred the exact persistent resource site to player control and the resolved-battle checkpoint is durably saved, carry one detached route-local consequence through `AppRouter` into the next Overworld scene and consume it exactly once;
- derive the payload only from BattleRules' existing detached pre-resolution `resource_assault` snapshot plus the live post-resolution resource node, then publish the existing `overworld_object_captured` / `resource_site` presentation at the exact authored node tile used by direct resource capture;
- preserve BattleRules combat/reward/survivor/commander behavior, OverworldRules resource collection/control/defender behavior, checkpoint retry and save-failure authority, route ordering, direct resource capture presentation, focus/input, settings, session/save schema, and all non-resource-assault outcomes.

Completion criteria:
- real 1280x720 and 1920x1080 stationed-resource victories save successfully, preserve method-matched unarmed Overworld authority, route to Overworld, and publish one exact persistent-resource capture cue after scene readiness with authoritative placement/site/tile/controller identity;
- the route-local payload is absent before successful checkpoint durability, fails closed on malformed/stale/wrong-controller/wrong-context/nonpersistent/terminal routes, is cleared on other routes, and cannot replay after consume, refresh, retry, or later Overworld construction;
- resource controller, defender clearance/commander recovery, survivors, active hero, rewards/aftermath/return notice, battle clearance, autosave bytes, session authority, direct resource capture behavior, and non-victory/ordinary battle outcomes remain exact;
- focused resource-assault return, resource-defense/battle/checkpoint/object-resolution compatibility, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no BattleRules combat, reward, survivor, commander, AI, balance, resource ownership/income/guard/response, save/schema, Native RMG, or map-topology changes;
- no new cue, VFX, audio, generic battle-aftermath stream, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged resource-assault interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Validated result:
- the production strategic-AI stationing path supplies the defender, the public resource collector enters `resource_assault`, BattleRules transfers the exact persistent node and clears defender metadata, and AppRouter validates the detached site/controller/tile before publishing;
- real 1280x720 and 1920x1080 rows preserve method-matched unarmed Overworld session authority and consume one existing capture cue, with refresh/later-scene and eight fail-closed controls remaining silent;
- focused and compatibility runtime owners, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass with no packaged interaction or broader release claim.

## Selected Slice: Overworld Town Assault Victory Return Feedback

id: `presentation-overworld-town-assault-victory-return-feedback-10184`

Status: completed.

Implementation boundary:
- after a real player town-assault victory has transferred the exact hostile town to player ownership and the resolved-battle checkpoint is durably saved, carry one detached route-local consequence through `AppRouter` into the next Overworld scene and consume it exactly once;
- derive the payload only from BattleRules' detached pre-resolution route-context snapshot for the `town_assault` victory plus the live post-resolution town record, then publish the existing `overworld_object_captured` / `town_capture` presentation at that town's exact visible tile;
- preserve BattleRules town ownership/garrison/hero/objective behavior, checkpoint retry and save-failure authority, route ordering, direct neutral-town capture presentation, focus/input, settings, session/save schema, and all non-assault outcomes.

Completion criteria:
- real 1280x720 and 1920x1080 player town-assault victories match an independent BattleRules control, save successfully, route to Overworld, and publish one exact captured-town cue after scene readiness with authoritative placement/content/tile/owner identity;
- the route-local payload is absent before successful checkpoint durability, fails closed on malformed/stale/wrong-owner/wrong-context/terminal routes, is cleared on other routes, and cannot replay after consume, refresh, retry, or a later Overworld construction;
- town ownership, garrison/survivors, active hero, objectives, aftermath/return notice, battle clearance, autosave bytes, session authority, direct capture behavior, and non-victory assault/ordinary battle outcomes remain exact;
- focused assault-return, battle layout/quick-resolve/checkpoint, direct town capture/object resolution, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no BattleRules combat, town ownership, garrison, survivor, objective, reward, AI, balance, save/schema, Native RMG, or map-topology changes;
- no new cue, VFX, audio, generic battle-aftermath stream, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged assault interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Town Army Transfer Completion Feedback

id: `presentation-town-army-transfer-completion-feedback-10184`

Status: completed.

Implementation boundary:
- after the real public Town transfer action succeeds and the stage refreshes, validate the parsed source/target holders, exact unit-count movement, conserved total, stationed-holder identities, recap, and active-hero mirror before publishing one compact queue-resolved/nonblocking TownStage presentation;
- cover both garrison-to-hero and hero-to-garrison transfers with one semantic Town event, the existing production UI confirmation audio, and compact procedural roster movement rendering with an exact reduced-motion fallback;
- preserve HeroCommandRules/TownRules mutation authority, transfer amount resolution, stack order/merge/removal, active-hero mirroring, focus/input, session/save, and all completed Town presentations.

Completion criteria:
- live TownShell 1280x720/1920x1080 public transfer actions match method-equivalent TownRules controls and publish exact source/target holder identity, unit identity, moved count, and before/after counts once;
- source count decreases and target count increases by the same positive amount, total count remains exact, both holders remain stationed, and the active-hero mirror remains exact;
- failed, stale, malformed, repeated, refresh, and non-transfer controls remain silent; normal and reduced-motion rendering are exact;
- focused Town transfer plus field-rendezvous/transfer, Town cue/visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Validated result:
- the public Town transfer handler now publishes only after exact source/target holder snapshots prove one positive unit movement, conserved total count, stationed holders, successful recap, and active-hero mirroring;
- TownStage renders compact roster movement, uses the existing imported UI-confirm cue, and fails closed for malformed, stale, repeated-empty-source, invalid, refresh, and non-transfer paths;
- eight focused 1280x720/1920x1080 normal/reduced direction rows plus transfer/rendezvous, cue/audio, keyboard-focus, Town/Battle visual, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL gates pass.

Non-goals:
- no transfer rules, amount tokens, stack ordering/merge/removal, holder eligibility, army stats, unit content, AI/logistics, save/schema, Native RMG, or map-topology changes;
- no new art/audio, generic UI cue remapping, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged transfer interaction/listening, hardware certification, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Overworld Encounter Victory Return Feedback

id: `presentation-overworld-encounter-victory-return-feedback-10184`

Status: completed.

Implementation boundary:
- before a real ordinary static encounter victory mutates resolution authority, snapshot only its exact placement/content/tile identity alongside the existing detached route context; after the resolved-battle checkpoint is durably saved, validate that identity against the live encounter row and `resolved_encounters`, then carry one route-local consequence through `AppRouter` into the exact next Overworld scene;
- publish the existing `overworld_object_depleted` cue under a truthful `encounter` family at the authored encounter tile, consume it once, and keep source order, VFX/audio policy, reduced-motion behavior, route ordering, and direct object presentations unchanged;
- preserve BattleRules combat/reward/survivor/commander/objective behavior, guarded-resource ownership and collection, checkpoint retry/save-failure authority, town/resource assault return paths, focus/input/settings, session/save schema, and all non-static or non-victory outcomes.

Completion criteria:
- real 1280x720 and 1920x1080 River Pass `river_pass_hollow_mire` victories durably checkpoint, preserve method-matched unarmed Overworld authority, resolve the exact encounter, leave the guarded `duskfen_bastion_peatwax_front` resource byte-exact and unclaimed by the player, and publish one exact encounter-depleted cue at the guard tile after scene readiness;
- the detached payload contains only exact pre-resolution placement/content/tile identity, is absent before successful checkpoint durability, and fails closed for malformed, unresolved, missing/mutated placement/content/tile, spawned-raid, assault, non-victory, terminal, stale, and wrong-surface controls;
- the cue consumes once and cannot replay after refresh, retry, or later Overworld construction; Battle rewards, casualties, active hero, objective/return notice, resolved encounter list, resource guard/control/claim authority, session/save bytes, and existing town/resource return presentations remain exact;
- focused encounter-return plus quick-resolve, guarded-site reward/context, town/resource return, object-resolution, checkpoint failure/retry, active-play focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no combat, reward, casualty, encounter resolution, guard, resource ownership/claim, AI raid, objective, save/schema, Native RMG, or map-topology changes;
- no new cue, VFX, audio, generic battle-aftermath stream, layout redesign, particles, shaders, spatial audio, haptics, or final mastering;
- no packaged encounter interaction/listening, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Active-Play Supported-Viewport Containment

id: `ux-active-play-supported-viewport-containment-10184`

Status: completed.

Implementation boundary:
- at the existing narrow Overworld breakpoint below 1100px, let the already compact-width Status chip clip only its visible label while retaining the exact full day/movement/next-day text in its native tooltip;
- at the existing compact Town breakpoint, let the Banner Header clip only its visible label, retain its exact full text in the native tooltip, and switch the existing native ResourceStockpileMenu to its already-supported compact 80px presentation while retaining the full resource summary and popup;
- on non-compact Town layouts, give the existing management rail enough width for its unchanged action flow to satisfy the supported 1600x900 height budget, using otherwise flexible TownStage width and without hiding or reparenting controls;
- keep the status chip visible, preserve every command and focus target, and let the existing container budget keep the map, command band, and system controls inside the supported 1024x600 frame;
- keep the Town Banner, TownStage, FooterPanel, native resource picker, narrow Town Orders toggle, and every footer command visible, contained, and available;
- preserve the existing 1280x720, 1600x900, and 1920x1080 layouts, sidebar/briefing/cue/save-detail breakpoints, opening-route and Town-build authority, and all gameplay/session behavior.

Completion criteria:
- the live player-comprehension layout owner passes 1024x600 with Map, CommandBand, PrimaryAction, EndTurn, Save, Settings, and Menu rectangles fully contained and all required controls visible/enabled;
- the narrow Status chip keeps exact full status text in its tooltip, uses its authored compact width, clips only the visible label, and returns to ordinary unclipped behavior outside the narrow breakpoint;
- at 1024x600 the live Town Banner, Header, Resources, TownStage, FooterPanel, SaveSlot, Save, Leave, Guide, Settings, Menu, and narrow Town Orders toggle are fully contained; the Header retains its exact full tooltip, and the resource picker retains its full summary, native popup, and selection authority while using compact mode;
- 1280x720, 1600x900, and 1920x1080 geometry/visibility remain contained, the compact Town rail remains 272px, the desktop rail is 400px with its combined minimum honored, and opening route/session plus Town build/session state stays byte-exact until a confirmed action;
- focused layout, resource-stockpile, broad Overworld/Town visual/input/focus/accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no command removal, hidden Status/Header/resource control, text/content rewrite, font or UI-scale change, two-row band, new panel/reparenting, new layout breakpoint, VFX/audio, or broader screen-composition change;
- no Overworld movement, routing, End Turn, Town build/economy, save, settings, input mapping, focus order, accessibility semantics, combat, AI, balance, session/schema, Native RMG, or map-topology changes;
- no packaged Overworld/Town interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Thornwake Rootgate Toll Chapter

id: `content-thornwake-rootgate-toll-chapter-10184`

Status: completed.

Implementation boundary:
- add one nineteenth active authored scenario that gives Thornwake a second real playable front: Tova Rootwright defends the already-authored Rootgate Nursery, breaks a Brasshollow toll line, and captures the already-authored Clauseworks Depot;
- wire the scenario as a fourth `Frontier Claims` chapter after `bellwake-wreck-claim`, importing only bounded resources and campaign flags while retaining Thornwake-owned hero, spell, and artifact authority;
- use only existing shipped terrain, towns, hero, army groups, units, resources, artifacts, encounters, objectives, scripts, campaign/save/runtime systems, and production UI paths.

Completion criteria:
- the active content catalog exposes exactly nineteen campaign- and skirmish-selectable scenarios, with the new scenario preserving exact Rootgate/Clauseworks, Tova/Graftroot Wardens, Thornwake/Brasshollow, deadline, objective, and authored-route identities;
- a real session can launch in both standalone and campaign modes, reach common and rare economy sources, resolve its authored encounters, capture Clauseworks, reach both victory and defeat authority, and survive save normalization/resume without synthetic rule shortcuts;
- `Frontier Claims` unlocks chapter IV only after exact Bellwake victory plus its authored completion flag, imports bounded resources/flags only, and transfers no Veilmourn hero progression, spells, or artifacts into Tova's command;
- active-scenario combat breadth, deadline, campaign/replay, economy-route/runway, strategic-AI, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology system changes;
- no broad faction balance retuning, generic campaign/carryover redesign, cross-faction hero/spell/artifact transfer, generated-map support, visual/audio asset production, or full Thornwake campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Veilmourn Fogchart Mooring Chapter

id: `content-veilmourn-fogchart-mooring-chapter-10184`

Status: completed.

Implementation boundary:
- add one twentieth active authored scenario that gives Veilmourn a second real playable front: Ruln Vanehook and the existing Bellwake Privateers defend the fully authored but unused Fogchart Mooring and break a Sunvault chart-seizure line;
- wire the scenario as a fifth `Frontier Claims` chapter after `rootgate-toll`, importing only bounded common resources and campaign flags while retaining Veilmourn-owned hero, spell, artifact, army, and rare-resource authority;
- use only existing shipped terrain, towns, heroes, army groups, units, resources, artifacts, encounters, objectives, scripts, campaign/save/runtime systems, and production UI paths.

Completion criteria:
- the active content catalog exposes exactly twenty campaign- and skirmish-selectable scenarios, with the new scenario preserving exact Fogchart/Halo, Ruln/Bellwake Privateers, Veilmourn/Sunvault, deadline, objective, and authored-route identities;
- a real session can launch in standalone and campaign modes, reach common and rare economy sources, resolve its authored encounters, capture the Sunvault registry front, reach victory and defeat authority, and survive save normalization/resume without synthetic rule shortcuts;
- `Frontier Claims` unlocks chapter V only after exact Rootgate Toll victory plus its authored completion flag, imports bounded common resources/flags only, and transfers no Thornwake hero progression, spells, artifacts, or verdant grafts into Ruln's command;
- active-scenario combat breadth, deadline, campaign/replay, economy-route/runway, strategic-AI, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology system changes;
- no broad faction balance tuning, generic campaign/carryover redesign, cross-faction hero/spell/artifact/rare-resource transfer, generated-map support, visual/audio asset production, or full Veilmourn campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Brasshollow Clauseworks Counterclaim Chapter

id: `content-brasshollow-clauseworks-counterclaim-chapter-10184`

Status: completed.

Implementation boundary:
- add one twenty-first active authored scenario that gives Brasshollow a second real playable front: Oren Bellfounder and the existing Orevein Exactors operate from Clauseworks Depot as a player town and break an Embercourt charter line at Highwater;
- wire the scenario as a sixth `Frontier Claims` chapter after `fogchart-mooring`, importing only bounded common resources and campaign flags while retaining Brasshollow-owned hero, spell, artifact, army, and rare-resource authority;
- use only existing shipped terrain, towns, heroes, army groups, units, resources, artifacts, encounters, objectives, scripts, campaign/save/runtime systems, and production UI paths.

Completion criteria:
- the active content catalog exposes exactly twenty-one campaign- and skirmish-selectable scenarios, with the new scenario preserving exact Clauseworks/Highwater, Oren/Orevein Exactors, Brasshollow/Embercourt, deadline, objective, and authored-route identities;
- a real session can launch in standalone and campaign modes, reach common and rare economy sources, resolve its authored encounters, capture the Highwater charter front, reach victory and defeat authority, and survive save normalization/resume without synthetic rule shortcuts;
- `Frontier Claims` unlocks chapter VI only after exact Fogchart victory plus its authored completion flag, imports bounded common resources/flags only, and transfers no Veilmourn hero progression, spells, artifacts, or memory salt into Oren's command;
- active-scenario combat breadth, deadline, campaign/replay, economy-route/runway, strategic-AI, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology system changes;
- no broad faction balance tuning, generic campaign/carryover redesign, cross-faction hero/spell/artifact/rare-resource transfer, generated-map support, visual/audio asset production, or full Brasshollow campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Mireclaw Nightglass Ledger Reversal Chapter

id: `content-mireclaw-nightglass-ledger-reversal-chapter-10184`

Status: completed.

Implementation boundary:
- add one twenty-second active authored scenario that makes the sole never-player-owned authored town, Nightglass Redoubt, a real Mireclaw player front led by the unused Kessa Chainboom and Nightglass Dominion army;
- wire the scenario as a seventh `Frontier Claims` chapter after `clauseworks-counterclaim`, importing only bounded common resources and campaign flags while retaining Mireclaw-owned hero, spell, artifact, army, and rare-resource authority;
- use only existing shipped terrain, towns, heroes, army groups, units, resources, artifacts, encounters, objectives, scripts, campaign/save/runtime systems, and production UI paths.

Completion criteria:
- the active content catalog exposes exactly twenty-two campaign- and skirmish-selectable scenarios, with the new scenario preserving exact Nightglass/Clauseworks, Kessa/Nightglass Dominion, Mireclaw/Brasshollow, deadline, objective, and authored-route identities;
- a real session can launch in standalone and campaign modes, reach common and rare economy sources, resolve its authored encounters, capture the Clauseworks counter-front, reach victory and defeat authority, and survive save normalization/resume without synthetic rule shortcuts;
- `Frontier Claims` unlocks chapter VII only after exact Clauseworks victory plus its authored completion flag, imports bounded common resources/flags only, and transfers no Brasshollow hero progression, spells, artifacts, or brass scrip into Kessa's command;
- active-scenario combat breadth, deadline, campaign/replay, economy-route/runway, strategic-AI, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- `nightglass-ledger-reversal` is the exact twenty-second active scenario and seventh `Frontier Claims` chapter, making Nightglass Redoubt, Kessa Chainboom, and Nightglass Dominion live player-owned content through existing campaign/skirmish systems;
- the focused owner proves standalone/campaign launch, live Mireclaw recruitment, three public battle entries, exact Day 13 victory/defeat authority, save/resume, common-only Clauseworks carryover, and no cross-faction hero/spell/artifact/brass-scrip transfer;
- screened rosters pass the authoritative 22-scenario/71-encounter breadth matrix with no stalls or invalid rows and a clear tuning queue (`829808c9`), followed by campaign/deadline/replay/economy/AI/core/static/editor compatibility;
- official Linux export/headless startup and Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass; these are bounded export/startup results, not packaged chapter interaction or release certification.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology system changes;
- no broad faction balance tuning, generic campaign/carryover redesign, cross-faction hero/spell/artifact/rare-resource transfer, generated-map support, visual/audio asset production, or full Mireclaw campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Sunvault Halo Reserve Refraction Claim Chapter

id: `content-sunvault-halo-reserve-refraction-claim-chapter-10184`

Status: completed.

Implementation boundary:
- add one twenty-third active authored scenario that supplies the missing Sunvault player chapter in `Frontier Claims`, led by the unused Neral Glasswind and Halo Reserve through existing content/runtime systems;
- wire it as chapter VIII after `nightglass-ledger-reversal`, importing only bounded common resources and campaign flags while retaining Sunvault-owned hero, spell, artifact, army, and rare-resource authority;
- reuse shipped towns, terrain, units, resources, artifacts, encounters, objectives, campaign/save/runtime systems, and production UI paths without new schemas or policy.

Completion criteria:
- the active catalog exposes exactly twenty-three campaign- and skirmish-selectable scenarios, and the new chapter preserves exact Neral/Halo Reserve, Sunvault/Thornwake, town, deadline, objective, and economy-route identities;
- real standalone and campaign sessions launch, expose live Sunvault town development/recruitment, create all authored public battle payloads, reach victory/defeat authority, and survive save normalization/resume;
- chapter VIII unlocks only after exact Nightglass victory plus `nightglass_claim_recorded`, imports bounded common resources/flags only, and transfers no Mireclaw hero progression, spells, artifacts, or peatwax;
- active combat breadth, campaign/deadline/replay/economy/AI/core compatibility, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- `halo-reserve-refraction-claim` is the exact twenty-third active scenario and eighth `Frontier Claims` chapter, making Halo Spire, Neral Glasswind, and Halo Reserve live player-owned content through existing campaign/skirmish systems;
- the focused owner proves standalone/campaign launch, live Sunvault recruitment, three public battle entries, exact Day 13 victory/defeat authority, save/resume, common-only Nightglass carryover, and no cross-faction hero/spell/artifact/peatwax transfer;
- screened rosters pass the authoritative 23-scenario/74-encounter breadth matrix with no stalls or invalid rows and a clear tuning queue (`829808c9`), followed by campaign/deadline/replay/economy/AI/core/static/editor compatibility;
- official Linux export/headless startup and Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass; these are bounded export/startup results, not packaged chapter interaction or release certification.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology changes;
- no broad faction balance tuning, generic campaign redesign, cross-faction hero/spell/artifact/rare-resource transfer, generated-map support, visual/audio asset production, or full Sunvault campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Embercourt Charter Bastion Counterseal Chapter

id: `content-embercourt-charter-bastion-counterseal-chapter-10184`

Status: completed.

Implementation boundary:
- add one twenty-fourth active authored scenario that completes six-faction player representation inside `Frontier Claims`, led by the authored but player-start-unused Seren Valechant and Charter Bastion Reserve;
- wire it as chapter IX after `halo-reserve-refraction-claim`, importing only bounded common resources and campaign flags while retaining Embercourt-owned hero, spell, artifact, army, and rare-resource authority;
- reuse shipped towns, terrain, units, resources, artifacts, encounters, objectives, campaign/save/runtime systems, and production UI paths without new schemas or policy.

Completion criteria:
- the active catalog exposes exactly twenty-four campaign- and skirmish-selectable scenarios, and the new chapter preserves exact Seren/Charter Bastion Reserve, Embercourt/Sunvault, Highwater/Halo, deadline, objective, and economy-route identities;
- real standalone and campaign sessions launch, expose live Embercourt town development/recruitment, create all authored public battle payloads, reach victory/defeat authority, and survive save normalization/resume;
- chapter IX unlocks only after exact Halo Reserve victory plus `halo_refraction_claim_recorded`, imports bounded common resources/flags only, and transfers no Sunvault hero progression, spells, artifacts, or aetherglass;
- active combat breadth, campaign/deadline/replay/economy/AI/core compatibility, repository/editor validation, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- `charter-bastion-counterseal` is the exact twenty-fourth active scenario and ninth `Frontier Claims` chapter, completing player-owned representation for all six factions through authored Seren Valechant, Charter Bastion Reserve, Highwater Keep, and Halo Spire content;
- focused runtime proves standalone/campaign launch, live Embercourt recruitment, three public battle payloads, exact Day 13 victory/defeat authority, save/resume, common-only Halo carryover, and no Sunvault hero/spell/artifact/aetherglass transfer;
- the screened 7/5/2 relay, 6/5/3 mirror, and 5/4/2 aurora fronts pass the authoritative 24-scenario/77-encounter breadth matrix with stalls 0, invalid 0, and tuning queue clear at signature `829808c9`;
- all prior Frontier chapter owners plus campaign, deadline, replay, economy-route, player/AI start and runway, recruitment-delivery, core, repository, JSON, validator, and exact/generic editor gates pass;
- official Linux export/headless startup and Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass; these are bounded export/startup results, not packaged chapter interaction or release certification.

Non-goals:
- no new units, towns, heroes, spells, artifacts, resource-site types, battle rules, AI policy, economy coefficients, campaign schema, save version, Native RMG, or map-topology changes;
- no broad faction balance tuning, generic campaign redesign, cross-faction hero/spell/artifact/rare-resource transfer, generated-map support, visual/audio asset production, or full Embercourt campaign claim;
- no packaged chapter interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Main Menu Editor Utility Command Frame

id: `ux-main-menu-editor-utility-command-frame-10184`

Status: completed.

Implementation boundary:
- keep Campaign, Skirmish, Load, Settings, and Quit as exact transparent hotspots over the five authored backdrop plaques;
- render only the Editor utility command with the existing asset-backed secondary button states in the unpainted gap between Settings and Quit;
- preserve the command's exact action, tooltip, focus order, keyboard/controller activation, cancel behavior, and Map Editor handoff.

Completion criteria:
- at 1280x720 and 1920x1080 the Editor command has a real nontransparent authored frame, remains inside the right command rail, and does not overlap the adjacent Settings or Quit plaques;
- the other five commands retain their exact text-only painted-plaque styles, anchors, labels, tooltips, order, and actions;
- mouse and keyboard/controller activation still enter the Map Editor through the public router, returning to the menu without changing save, campaign, settings, or session authority;
- focused menu visual/navigation, Map Editor return, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Completion evidence:
- the Editor command alone now uses the existing secondary normal/hover/pressed/disabled texture frames, while Campaign, Skirmish, Load, Settings, and Quit remain exact transparent hotspots over their authored backdrop plaques;
- focused runtime proves the framed Editor rect is contained and nonoverlapping between Settings and Quit at 1280x720 and 1920x1080, with exact asset paths, tooltip, anchors, command order, and unchanged session/menu authority;
- menu/outcome visual behavior, the full keyboard/controller navigation matrix, screen-reader semantics, core systems, repository validation, Python compilation, diff checks, and exact/generic editor parses pass;
- official Linux export/headless startup and Windows export/fresh-Wine Godot/Boot/MainMenu/native-DLL startup pass; these remain bounded packaging/startup results, not packaged Editor interaction or release certification.

Non-goals:
- no backdrop repaint, new art generation, command reordering, submenu redesign, Map Editor behavior change, global theme/UI-scale change, save/campaign/settings change, gameplay/content/balance/AI/Native RMG change, or broad first-view redesign;
- no packaged Editor interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

## Selected Slice: Battle Initiative Strip Readable Stack Identity

id: `ux-battle-initiative-strip-readable-stack-identity-10184`

Status: completed.

Implementation boundary:
- replace only the BattleBoard turn-strip's opaque two-letter initials with bounded readable stack-name labels derived from the same full live stack identity;
- make every painted turn-strip chip participate in the board's native tooltip hit test and expose its exact full stack name, alive count, side, visible initiative slot, and current/queued state;
- derive chip rectangles once and reuse the exact same ordered geometry for drawing and tooltip resolution;
- preserve the existing five-chip cap, side colors, active highlight, board token labels, board cursor semantics, current/next Initiative Handoff surface, and all battle authority.

Completion criteria:
- at 1280x720 and 1920x1080 every visible initiative chip is contained, nonoverlapping, uses a readable compact name rather than an initials-only code, and retains its exact alive count;
- hovering the center of every painted chip returns its exact full name/count/side/slot/current-or-queued tooltip, with the tooltip order and rectangles matching the painted turn order exactly;
- positions outside the strip retain exact occupied-stack, movement, blocked-cell, enemy-turn, and fallback tooltip behavior;
- turn order, turn index, active/selected stacks, combat state, focus/controller behavior, session/save authority, and deterministic battle outcomes remain unchanged;
- focused battle-layout/tooltip, broad Battle visual/navigation/accessibility, animation, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no initiative, turn-order, action, targeting, movement, combat-math, AI, unit, roster, spell, objective, save/schema, content, balance, Native RMG, or map-topology changes;
- no Battle layout redesign, extra panel, larger strip, more than five chips, board-token relabeling, font/UI-scale change, new art/audio/VFX, or new accessibility live region;
- no packaged Battle interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- the exact five-chip turn-order geometry is shared by drawing and native hover hit testing; compact labels retain readable stack-name prefixes and alive counts while full identity remains available in exact per-chip tooltips;
- the focused Board navigation owner passes at 1280x720 and 1920x1080 with exact order, geometry, tooltip, and session/save/settings authority; Battle visual, animation, accessibility, and core compatibility owners pass;
- repository validation, Python compilation, diff checks, exact/generic Godot editor parses, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass;
- packaged Battle interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, and release-readiness remain explicitly unclaimed.

## Selected Slice: Overworld Unexplored Fog Shroud

id: `ux-overworld-unexplored-fog-shroud-10184`

Status: completed.

Implementation boundary:
- replace only the repeated per-tile diagonal X wireframes over unexplored Overworld cells with a subdued deterministic shroud treatment that reads as contiguous hidden territory;
- keep exact unexplored fill opacity, explored/unexplored boundary ownership, map-cell containment, and no-terrain/no-object/no-route information leakage;
- expose the rendered shroud contract through the existing Overworld terrain validation surface and focused visual owner without changing fog state or simulation rules.

Completion criteria:
- at 1280x720 and 1920x1080 unexplored regions render as contained non-wireframe shroud cells without diagonal placeholder crosses, while explored terrain remains scenery-first and unchanged;
- unexplored terrain identity, roads, objects, heroes, encounters, routes, selection, and tooltips remain hidden; newly explored cells reveal the exact existing terrain/object surface and never retain shroud marks;
- exploration/visibility arrays, counts, movement, route legality, focus/controller behavior, session/save authority, and permanent-exploration policy remain exact;
- focused Overworld visual/fog, full-route/input/accessibility/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no fog-of-war rule, visibility radius, scouting, pathing, terrain, road, object, hero, encounter, route, camera, save/schema, content, balance, AI, or Native RMG changes;
- no new bitmap asset, terrain repaint, map layout redesign, additional panel, transient memory-fog layer, animation, audio, or global theme/UI-scale change;
- no packaged Overworld interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- the live Overworld renderer now replaces unexplored-cell diagonal X wireframes with a continuous dark fill and three deterministic, contained, identity-silent mist layers; explored terrain and fog authority are unchanged;
- the public visual owner passes with exact hidden terrain/texture state, no wireframe state, and no shroud on explored cells; fresh 1280x720 and 1920x1080 X11 captures show the contiguous shroud without square veil tiles or diagonal crosses;
- focused Overworld visual, fog-rule, full-route, keyboard-focus, accessibility, and core owners pass with natural exits; repository validation, Python compilation, diff checks, and exact/generic Godot editor parses pass;
- official Linux export/headless startup and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass; packaged Overworld interaction, controller hardware, AT-SPI/UIA, native hardware, signing/publication, whole-game, and release-readiness remain explicitly unclaimed.

## Selected Slice: Overworld Hero Command Rail Compact Fit

id: `ux-overworld-hero-command-rail-compact-fit-10184`

Status: completed.

Implementation boundary:
- compact only the existing Hero rail command-check visible summary so its proportional-font width fits the live label at 1280x720 and 1920x1080, while keeping the full command identity/readiness/movement text in the existing native tooltip;
- remove the duplicate no-reserve placeholder row from the existing HeroActions container; real reserve-command buttons, order, tooltips, focus, and consequences remain unchanged;
- validate live pixel-width containment and exact solo/reserve presentation through the existing public Overworld visual owner without changing hero, movement, action, route, or save authority.

Completion criteria:
- the solo and reserve command summaries fit within the live Heroes label at 1280x720 and 1920x1080 with no visual clipping, while the full tooltip retains active commander, roster, readiness, switch, movement, and next-action context;
- solo state exposes no redundant HeroActions child, while reserve state retains the exact enabled command button and public switch consequence;
- hero identity/card, army, portrait, movement, command cache, focus/input, route, session, and save authority remain exact;
- focused Overworld visual, hero-command/cache, active-focus, accessibility, core, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no hero rules, roster, recruitment, switching consequence, movement, action scoring, pathing, fog, map renderer, save/schema, content, AI, or Native RMG changes;
- no sidebar width, panel height, font/theme, portrait, map size, command drawer, footer, or general rail-summary redesign;
- no packaged Overworld interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- the live solo summary is now `Command: Solo | Move N/N`, the reserve summary is `Command: N reserve(s) | Move N/N`, and the full existing tooltip retains active commander, roster, readiness, switch, movement, next-action, and state-change context;
- solo state creates no duplicate HeroActions child, while the real reserve state retains its enabled Caelen command button and exact public command surfaces;
- the focused Overworld owner measures the themed-font string against the live Heroes label and passes method-matched solo/reserve states; fresh 1280x720 and 1920x1080 X11 captures show the complete summary with reclaimed rail space;
- hero-action cache, active-focus, accessibility, core, repository/editor, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass; packaged Overworld interaction and broader release claims remain unclaimed.

## Selected Slice: Battle Order Tab Compact Initiative Summary

id: `ux-battle-order-tab-compact-initiative-summary-10184`

Status: completed.

Implementation boundary:
- compact only the existing Battle Order tab's visible initiative body from the duplicated full technical track to a bounded three-line Initiative/Now/Next summary derived from the same live handoff state;
- keep the exact full current/next handoff detail and full ordered initiative track in the existing native tooltip;
- validate themed-font line width, vertical containment, exact current/next identity, and tooltip completeness at 1280x720 and 1920x1080 through the existing public Battle controller/board owner.

Completion criteria:
- every visible Order-tab line fits the live proportional-font label without extra autowrap or truncation at 1280x720 and 1920x1080, and the label remains contained in its existing panel;
- visible Now/Next identities and the tooltip's full handoff/order identities match the authoritative battle state and retain exact refresh behavior;
- Battle tab titles/navigation, board initiative strip, turn order/index, active/selected stacks, actions, focus/controller behavior, session/save/settings/routes, and deterministic outcomes remain exact;
- focused board/navigation, Battle tab/focus/visual/animation/accessibility/core compatibility, repository/editor, Linux export/headless startup, and Windows export/fresh-Wine Boot/MainMenu/native-DLL startup gates pass.

Non-goals:
- no initiative, turn-order, action, targeting, movement, combat-math, AI, unit, spell, roster, content, balance, save/schema, or Native RMG changes;
- no sidebar/tab/panel resizing, new panel, font/theme/UI-scale change, board-strip change, tab-navigation change, new art/audio/VFX, or general Battle layout redesign;
- no packaged Battle interaction, controller hardware, AT-SPI/UIA certification, native hardware, signing/publication, whole-game, or release-readiness claim.

Completion evidence:
- the live Order tab renders exactly `Initiative cue:`, `Now: ...`, and `Next: ...` without the duplicated technical track; every themed-font line fits its existing label and the label remains contained at 1280x720 and 1920x1080;
- the existing tooltip retains the exact full Initiative Handoff and full ordered `NOW/UP/DONE`, side, initiative, count, and HP track, while focused independent controls prove current/next identity and whole authority;
- the fresh X11 capture `/tmp/heroes-battle-order-visual.590zIh/order_tab_compact_1280.png` shows the corrected shipped composition; focused board/navigation, Town/Battle visual, active-focus/tab navigation, animation, accessibility, and core owners pass naturally;
- repository validation, Python compilation, diff checks, exact/generic editor parses, official Linux export/headless startup, and official Windows export/fresh-Wine Boot/MainMenu/native-DLL startup pass; broader packaged interaction and release claims remain unclaimed.

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
