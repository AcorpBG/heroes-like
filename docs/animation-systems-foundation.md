# Animation Systems Foundation

Status: design and technical planning source, not implementation proof.
Date: 2026-04-25.
Slice: animation-systems-foundation-10184.

## Purpose

This document defines the animation foundation needed before final town polish, final battle polish, broad campaign/skirmish production, faction vertical slices, or production asset work can rely on motion. The goal is not to sprinkle tweens on the current prototype. The goal is to define a production animation contract for units, heroes, towns, overworld objects, spells, artifacts, audio cues, UI feedback, and state-change clarity.

Heroes 2, Heroes 3, and Oden Era may inform expectations for strategic readability, turn feedback, and content breadth only. They are not source material for animation timing, assets, effects, sounds, unit identities, town motion, spell visuals, UI layout, or text.

## Current Gap

The current live client has useful presentation scaffolds, but no production animation system.

Reality check as of this slice:

- Battle presentation is mostly static hex-board drawing with colored stack tokens, legal-action highlights, terrain textures, tooltips, and validation snapshots. It does not have authored unit motion states, attack windups, impact reactions, death timing, spell VFX, or synchronized audio.
- Overworld presentation has terrain layers, object sprites/procedural fallbacks, hero/object/town grounding rules, route highlights, panning, fog/memory states, and render-cache layers. It does not yet have hero locomotion, object idle loops, capture transitions, guarded-site warning motion, convoy motion, or animation-aware cache invalidation.
- Town presentation is a static procedural scenic drawing with compact status plaques and district summaries. It does not yet have faction-specific town ambience, building construction states, recruitment/build feedback, defense/readiness motion, or building-level animation contracts.
- UI styling exists through shared visual helpers and button states, but there is no shared microinteraction policy for command confirmation, invalid actions, resource changes, spell casts, artifact equip changes, save/load, or reduced-motion accessibility.
- Audio settings exist, but there is no content contract for animation-synchronized SFX, UI sounds, spell cues, town ambience, battle impacts, or mix priority.
- Gameplay rules and saves are deterministic enough to support validation, but animation is not yet modeled as a presentational replay of rule events. That boundary must be preserved.

The missing work is not only art production. The project needs a stable animation taxonomy, event contract, asset pipeline, readability rules, performance budget, and validation plan that can scale across six factions, seven-tier unit ladders, accord schools, artifacts, towns, objects, and AI turns.

## Design Contract

Animation must serve state clarity first.

Rules:

- Simulation resolves in core rules. Animation visualizes resolved events and previews legal intent; it must not decide outcomes.
- Every major state change needs one readable cue: movement, damage, death, morale/cohesion change, status applied/expired, capture, construction, recruitment, spell cast, artifact pickup/equip, save/load, turn start, AI action, victory, and defeat.
- Motion must be compact enough for repeated turn-based play. It should be satisfying, but never force long waits for routine actions.
- The main map, town, and battle surfaces remain primary. Animation should clarify the surface instead of covering it with text panels or oversized overlays.
- Faction animation languages must follow `docs/worldbuilding-foundation.md` and `docs/factions-content-bible.md`: Beacon, Mire, Lens, Root, Furnace, and Veil motion should be distinguishable by silhouette, rhythm, material, residue, and audio.
- Animation must have reduced-motion and fast-resolution modes from the start of implementation planning.
- Runtime saves store gameplay state, not transient animation progress. Resuming a save should enter a stable state and may replay only safe entry cues.

## Target Animation Surfaces

Animation must cover these surfaces before production polish can depend on it:

| Surface | Required purpose | Examples |
| --- | --- | --- |
| Battle units | Tactical readability and combat feel | idle, select, move, attack, ranged fire, cast support, hit, death, status loop |
| Heroes | Player identity and command clarity | overworld walk, embark/disembark later, town presence, battle command/cast |
| Towns | Scenic production identity and action feedback | ambient loops, building constructed, recruit available, threat/readiness, capture |
| Overworld objects | Map legibility and strategic state | idle loops, visit/capture/depleted/guarded/damaged/owned states |
| Spells and VFX | Accord identity and effect clarity | cast anchor, projectile/area/zone, impact, residue, counter/cleanse |
| Artifacts | Reward/build feedback | pickup shimmer, equip pulse, set completion, curse warning, charged state |
| UI | Intent, confirmation, and errors | hover, press, disabled, resource delta, invalid action, tab changes |
| Audio cues | Timing and readability support | command click, movement step, hit, guard warning, spell school cue, town ambience |

## Animation Taxonomy

Animation should be authored and validated through stable categories.

Primary categories:

- Character locomotion: walk, step, charge, retreat, teleport/displace, embark/disembark later.
- Character combat: ready, melee windup, melee release, ranged aim, ranged release, cast, support, defend/brace, hit, stagger, death, victory/idle return.
- Character status: buff, debuff, dot/residue, shield, root/bind, fog/conceal, overpressure, harried, marked, repairing, renewing.
- Environment idle: town motion, object loops, route motion, weather/terrain ambience, fog/mist, water/wheel/furnace/root/lens/bell loops.
- Environment state transition: capture, ownership change, depleted, refreshed, damaged, repaired, blocked, opened, guarded, cleared.
- Spell/VFX: anchor, launch, travel, area formation, impact, linger, cleanup, counterspell, resisted, fizzled/invalid.
- UI microinteraction: hover, press, focus, confirm, cancel, invalid, warning, resource change, list selection, modal enter/exit.
- Camera and framing: battle focus, short shake on high-impact events, pan to AI action, route preview, town entry/exit. Camera motion must be minimal and optional.
- Audio event: UI, movement, combat, spell school, artifact, object, town ambience, outcome.

Animation states should include:

- `state_id`
- `surface`
- `subject_kind`
- `trigger_event`
- `duration_ms`
- `skippable`
- `reduced_motion_variant`
- `fast_mode_variant`
- `blocking_policy`
- `audio_cue_ids`
- `vfx_cue_ids`
- `readability_priority`
- `validation_tags`

This is future schema direction, not an instruction to edit content JSON in this slice.

## Unit Battle Animation States

Every production battle unit needs a minimum state set before battle polish can call it reliable.

Required states:

| State | Purpose | Notes |
| --- | --- | --- |
| Idle | Identify unit and side without clutter | Distinct silhouette, subtle loop, no distracting bob for small stacks |
| Ready/active | Show whose turn it is | Stronger than hover, weaker than a spell or impact cue |
| Select/focus | Confirm player target or hovered stack | Must not obscure count, health, or legal target state |
| Move | Show path and final occupied hex | Can be path ghost plus short step, not full long travel if fast mode is on |
| Melee windup/release | Tell attacker, target, and timing | Directional anticipation and clear release frame |
| Ranged aim/release | Separate source, projectile path, and impact | Projectiles should not hide neighboring stacks |
| Cast/support | Show unit-based support or special ability | Uses faction/accord anchor language when relevant |
| Defend/brace | Show selected defensive posture | Must persist as a small readable state, not only a flash |
| Hit/light damage | Confirm damage without overdrama | Short impact, health/count delta, optional sound |
| Heavy hit/stagger | Show major loss/status | Stronger hit pose and status cue |
| Death/rout | Remove stack clearly | Must finish with an unambiguous empty hex |
| Status applied | Show new keyword | Icon/residue plus motion cue, no large text panel |
| Status loop | Show persistent keyword | Small edge/residue loop with reduced-motion fallback |
| Status expired/cleansed | Remove state clearly | Short reverse/fade cue |
| Morale/momentum/cohesion change | Show command state changes | Compact banner/icon pulse near stack or rail |

Battle animation readability requirements:

- Attack direction must be legible even when two stacks overlap visually or adjacent hexes are dense.
- Damage and status application must bind visually to the target, not only to an event log.
- Legal move/attack previews remain above terrain and below final action cues.
- Active unit, selected target, blocked target, legal melee target, legal ranged target, and closing-on-target states need different animation emphasis.
- AI turns require the same event clarity as player turns, with an optional faster playback speed.
- Retaliation must be visibly distinct from the original attack.
- Multi-hit, splash, line, cone, radius, and zone effects need separate timing rules so the player can see cause and result.

## Hero Animation

Heroes are the player's main persistent identity and must not stay as static map markers in production.

Overworld hero requirements:

- Idle figure with side/ownership clarity.
- Tile-to-tile step or glide that follows the accepted route and stops cleanly on the destination.
- Short cues for insufficient movement, blocked route, new route preview, entering town, entering battle, collecting pickup, capturing site, and triggering scenario objective.
- Distinct stance or compact emblem state for active hero, reserve hero, enemy commander, and neutral/unknown commander.
- Future embark/disembark and transit-object motion hooks for ferry, rail, root gate, fog slip, and prism road logic.

Town hero requirements:

- Stationed hero presence should be visible without covering the town scene.
- Recruit, garrison transfer, study, market, build, and leave-town actions need compact hero or command cues.
- Captured-town occupation and retake-front states need motion language that reads as tension, not a dashboard.

Battle hero requirements:

- Hero command/cast cues should frame the active army without replacing unit action clarity.
- Might commands, magic casts, artifact triggers, surrender/retreat, morale swings, and outcome transitions need distinct event cues.
- Hero portraits can animate subtly in UI, but combat cause/effect must remain on the board.

Faction rhythm examples:

- Embercourt: steady signal timing, bell strikes, lantern pulses, braced posture.
- Mireclaw: low sudden motions, reed sways, chain snaps, drag/pull impacts.
- Sunvault: precise lens calibration, sharp glints, delayed resonance pulses.
- Thornwake: growth unfurling, root tension, recovery bloom, living-road motion.
- Brasshollow: heavy mechanical beats, pressure venting, repair ticks, heat buildup.
- Veilmourn: fog drift, bell delays, displacement flickers, memory-salt motes.

## Town And Building Animation

Town animation should make the town feel alive while preserving a scenery-first composition.

Town requirements:

- Ambient loops per faction: water wheels and beacons, reed drums and ferries, lens glints and choirs, root gates and fruit lanterns, furnace vents and rails, fog bells and lantern buoys.
- Building states: unbuilt site, available build, under construction if later supported, newly built, upgraded, disabled/damaged, captured, occupied, defended, producing.
- Action feedback: build complete, recruit pool refresh, recruitment purchase, study spell, market trade, garrison transfer, defense/readiness change, threat response, capture, pacification/retake pressure.
- Faction-specific building families from `docs/factions-content-bible.md` must define motion hooks before final art: Embercourt lockworks, Mireclaw chain ferries, Sunvault relays, Thornwake graft halls, Brasshollow pressure rails, Veilmourn bell harbors.
- Town screens must avoid covering the scenic surface with large reports. Animation should be embedded in buildings, skyline, edge rails, command spine, footer pocket, tabs, or contextual popouts.

Deep enough before town polish:

- At least one faction town has an approved animatic and motion board for ambient, build, recruit, study, market, defense, and capture states.
- Building/state animation metadata exists in the implementation plan, even if placeholder art is still used.
- Reduced-motion variants exist for all looping town ambience.
- Validation can detect that a town action produces a visible state-change cue without requiring screenshot-perfect final art.

## Overworld Object Animation

Overworld animation must support the object taxonomy in `docs/overworld-object-taxonomy-density.md`.

Object class requirements:

| Object class | Required animation states |
| --- | --- |
| Decoration/non-interactable | Optional low-cost idle only; must not look visitable |
| Pickup | idle sparkle/attention, collect, depleted/remove |
| Interactable building/site | idle, hover/focus, visit, resolved, refreshed if repeatable |
| Persistent economy site | neutral, owned by player/enemy/neutral, capture, contested, pillaged/damaged, output tick |
| Transit/route object | closed, open, taxed/discounted, repaired, blocked, active travel cue |
| Neutral dwelling | idle, available recruit, visited, refreshed, guarded |
| Neutral encounter | patrol/idle, aggro/warning, battle trigger, cleared |
| Guarded reward site | guarded warning, cleared entrance, reward claim, depleted |
| Faction landmark | influence idle, ownership/faction pulse, scenario objective cue |

Readability rules:

- Decoration must stay quiet. It should not use reward-like shimmer, flag pulses, or command attention.
- Guard warning animation must be visible before interaction. No invisible punishment hidden behind a static object.
- Capture and ownership changes need small but clear color/material/faction cues without turning the map into marker clutter.
- Object loops must respect render-cache layers. Static terrain should stay cacheable; animated objects likely need a dynamic or animation overlay layer.
- Remembered/fogged objects need reduced or ghosted animation states. The player should not infer current live state from old memory unless scouting rules say so.

## Spell, VFX, And Audio Cue Requirements

The magic foundation in `docs/magic-system-expansion-foundation.md` defines seven accord schools. Animation must make those schools readable in battle and on the adventure map.

School cue language:

| School | Motion/VFX language | Audio direction |
| --- | --- | --- |
| Beacon | signal pulses, ash writ lines, lantern marks, ordered rings | bell, brazier flare, command chorus |
| Mire | drag trails, rot blooms, blind splatter, reed vibration | drum, wet chain, low reed scrape |
| Lens | sharp glints, calibration lines, resonance shields, reflection arcs | crystal ping, choir tone, prism hum |
| Root | bramble rise, graft knots, regrowth pulses, movement tax vines | wood strain, leaf rush, deep root thud |
| Furnace | heat bloom, pressure gauge surge, slag burst, repair sparks | vent hiss, metal hit, boiler pulse |
| Veil | fog curl, displacement smear, memory motes, bell-shadow flicker | buoy bell, muffled wave, paper/ink whisper |
| Old Measure | mirror fracture, weather/time ripple, anchor geometry | low chime, reversed shimmer, stone resonance |

VFX requirements:

- Every spell needs cast source, target preview, impact, result, and residue/counter state when applicable.
- Battle VFX must support single target, line, cone, radius, lane, zone, battlefield edge, and conditional target shapes.
- Adventure-map VFX must show range, valid target, ownership/route constraints, cooldown/resource cost, success, and invalid attempt.
- Buff/debuff visuals must remain readable after the initial impact through compact status loops/icons.
- Counterspell, resist, cleanse, reveal, dispel, and failed cast all need distinct cues.

Audio requirements:

- Audio cue ids should be separate from visual ids so mix, localization, accessibility, and platform settings can evolve.
- UI, spell, unit, object, town, and ambience cues need priority classes to prevent sound spam during AI turns or mass effects.
- Reduced-sensory mode should lower harsh flashes, strong shakes, and high-frequency repeated sounds.

## Artifact Feedback

The artifact foundation in `docs/artifact-system-expansion-foundation.md` makes artifacts build-defining. Animation must make artifact state clear without requiring inventory reading.

Required artifact cues:

- Pickup/claim cue by rarity and source: common utility, guarded reward, set piece, cursed, Old Measure, scenario.
- Equip and unequip cue tied to the affected slot.
- Comparison/effect preview cue for changed movement, scouting, battle stat, school focus, economy, resistance, or route effect.
- Set piece progress and set completion cue.
- Cursed/tradeoff warning before equip or pickup when the tradeoff is immediate.
- Charged artifact ready, spent, cooldown, and recharge cue.
- Artifact-granted spell cue that marks the cast as artifact-sourced.

Artifacts must never hide rule changes. If an item modifies a spell, movement, economy, unit keyword, or town support, the cast/action preview must show the modified effect before the player commits.

## UI Feedback And Microinteractions

UI animation should make commands feel responsive and state changes legible, not decorative.

Required shared microinteractions:

- Hover/focus for buttons, tabs, list rows, slots, map objects, stacks, towns, and spell/artifact choices.
- Press/confirm for action buttons, purchases, movement, attack, cast, equip, save, load, and end turn.
- Invalid action for blocked movement, unaffordable build/recruit, invalid spell target, occupied approach tile, unavailable artifact slot, and disabled campaign/skirmish option.
- Resource delta for gains, spending, insufficient resources, daily/weekly income tick, market exchange, and site capture.
- Status delta for movement, mana, morale, cohesion, readiness, threat, occupation, retake pressure, spell duration, and artifact charges.
- Modal and submenu transitions that keep first-view menus clean and avoid dumping detailed selection flows onto scenic surfaces.
- Fast-click protection so a command cannot be double-fired while a blocking animation is resolving.

Microinteraction constraints:

- No large text panels over scenic/play surfaces just to explain animation.
- Do not rely on color alone. Pair color with icon shape, motion pattern, position, or audio.
- All loops must have reduced-motion alternatives.
- UI animations should have short duration budgets: normal command feedback below 200 ms, heavier confirmations below 450 ms unless the user is entering/leaving a major scene.

## State-Change Clarity

The following state changes must eventually have explicit animation/audio feedback:

- Overworld: movement spent, movement blocked, pickup collected, site captured, site counter-captured, guard engaged, road/transit opened or blocked, fog revealed, remembered object found stale, day advanced, weekly refresh, enemy turn action, town threat state changed.
- Town: building built, recruitment purchased, recruits refreshed, garrison changed, hero stationed/left, spell learned, market trade, defense/readiness changed, occupation/pacification advanced, retake pressure visible.
- Battle: turn start, active stack changed, move, attack, retaliation, ranged shot, spell cast, ability trigger, damage, heal/repair, stack killed, status applied/expired, morale/momentum/cohesion changed, retreat/surrender, victory/defeat.
- Artifact: pickup, equip, unequip, set progress, charge spent/recharged, curse/tradeoff applied, artifact-modified spell/action.
- Campaign/skirmish: scenario selected, faction selected, difficulty changed, save written, load resumed, objective advanced, campaign unlock.

Each cue should have a corresponding validation hook or event-log entry so automated tests can verify that the visual layer received the event, even before final art exists.

## Godot 4 Technical Architecture Options

Implementation should choose a conservative architecture that preserves core-rule determinism.

Recommended direction:

- Add a presentation-only animation event layer that consumes resolved rule events from battle, overworld, town, UI, spell, and artifact actions.
- Keep scene controllers thin: controllers emit intents, rules resolve state, animation presenters play event cues, and views redraw stable state.
- Use Godot 4 `AnimationPlayer`/`AnimationTree` for reusable unit/hero/town/object clips where authored scenes exist.
- Use `Tween` sparingly for UI microinteractions and simple property transitions, not as the primary gameplay animation architecture.
- Use `AnimatedSprite2D`, sprite sheets, or texture atlases for 2D unit and object animation once asset production starts.
- Use `GPUParticles2D` or lightweight custom draw effects only where they pass readability and performance budgets.
- Use `AudioStreamPlayer`/bus routing with cue ids and priority classes; avoid hard-wiring sounds inside core rules.
- Keep animation metadata data-driven where practical, but do not add broad JSON schemas until first vertical proof validates the contract.

Possible components:

- `AnimationEventQueue`: presentation-only queue of rule event payloads.
- `BattleAnimationPresenter`: resolves battle event timing, blocking, camera focus, and VFX.
- `OverworldAnimationPresenter`: handles hero movement, object state changes, capture, route/fog cues, and AI action playback.
- `TownAnimationPresenter`: handles building, recruitment, study, market, defense, capture, and ambience.
- `UiMotionKit`: shared hover/press/invalid/resource/status microinteractions.
- `CueCatalog`: maps logical cue ids to animation clips, VFX, audio, reduced-motion variants, and fallback draw cues.

Technical constraints:

- Animation must not mutate authoritative simulation state.
- Blocking animations must have timeouts and skip/fast-forward support.
- Events must be serializable enough for validation/replay logs, but transient playback progress should not enter saves.
- Render-cache boundaries in `OverworldMapView` need animation-aware invalidation before animated map objects ship.
- Battle and town validation snapshots should expose cue/event summaries before relying on screenshot comparisons.

## Asset Pipeline

Production animation assets need a pipeline before broad art starts.

Required pipeline stages:

1. Motion brief.
   - Source docs: worldbuilding, faction bible, concept-art pipeline, object taxonomy, magic, artifacts.
   - Defines surface, unit/object/building/spell role, silhouette, scale, timing, readability, audio needs, and reduced-motion variant.
2. Silhouette and key-pose study.
   - Proves idle, anticipation, release, impact, and state readability at target game scale.
3. Animatic.
   - Low-cost timing test using rough frames, cutouts, or editor-native placeholders.
4. Implementation brief.
   - Converts approved direction into sprite-sheet, scene, VFX, audio, metadata, and validation requirements.
5. Runtime integration.
   - Adds clips/cues through the chosen animation presenter and cue catalog.
6. Readability QA.
   - Tests desktop/mobile-sized viewport equivalents, fast mode, reduced motion, color-blind readability, overlapping objects/stacks, and AI playback.

Folder direction for future implementation:

- `art/animation/source/` for work-in-progress source files if checked in later.
- `art/animation/runtime/units/`
- `art/animation/runtime/heroes/`
- `art/animation/runtime/towns/`
- `art/animation/runtime/objects/`
- `art/animation/runtime/vfx/`
- `audio/cues/` or equivalent once audio production starts.

This slice does not create those folders or assets.

## Concept-Art And Animatic Stage Gates

The concept-art pipeline already requires animation readiness notes. Animation adds these gates:

- Unit ladder gate: every faction's seven-tier sheet must identify idle silhouette, movement posture, attack method, hit reaction, death read, and status-loop risk.
- Hero gate: each hero concept needs overworld scale, portrait/full-body, command gesture, cast/ability anchor, and faction rhythm notes.
- Town gate: each faction town needs ambient motion board, building construction/active states, skyline motion budget, and capture/threat cues.
- Object gate: every object family sheet needs idle/capture/depleted/guarded/refreshed motion notes, or an explicit "static only" decision for decoration.
- Spell gate: every accord family sheet needs cast, target, impact, residue, counter, and audio cue language.
- Artifact gate: artifact families need pickup/equip/set/curse/charge feedback notes.
- Animatic gate: before final town or battle polish, at least one unit combat loop, one spell, one hero map move, one town action, one object capture, and one UI resource delta must be proven in low-fidelity animatic form.

## Performance Constraints

Animation must respect a 2D strategy game's repeated-turn workload.

Budgets to validate during implementation:

- Overworld idle object animation should be limited by visible viewport and importance. Decoration loops should be rare and cheap.
- Animated map objects must not force full terrain/static cache redraws every frame.
- Battle should support multiple animated stacks and VFX without delaying input after events resolve.
- Town ambience should use layered loops with limited animated regions, not full-screen video-like redraw.
- Particle counts must stay low and legible. Prefer authored sprite/VFX shapes over dense particles.
- Audio cue spam must be rate-limited, especially during AI turns, mass damage, resource ticks, and weekly refresh.
- Fast mode should shorten or collapse routine animations while preserving cause/effect cues.

Initial target:

- Common UI feedback: 100-200 ms.
- Routine battle move/attack: 250-700 ms per event in normal mode, shorter in fast mode.
- Major spell/kill/capture: 600-1200 ms with skip support.
- Overworld tile step: short enough that a multi-tile route does not become tedious; long routes may summarize intermediate steps.
- Town action confirmation: 250-600 ms.

## Accessibility And Readability Constraints

Animation must remain usable across accessibility settings.

Requirements:

- Reduced motion: replace large camera moves, shakes, repeated bobbing, and long loops with fades, static icons, or short pulses.
- No critical information by color alone.
- Avoid intense flashes, strobing, rapid high-contrast flickers, or repeated screen shake.
- Fast mode and skip controls must be available for frequent turn-based actions.
- Text and counters must not be obscured by VFX, particles, or status loops.
- Audio cues need visual equivalents for mute/deaf play.
- Hover/focus/target cues must remain visible for color-blind users through shape, outline, icon, or motion pattern.
- Mobile/small-viewport equivalents must keep unit/object/state cues from overlapping.

## Save, Replay, And Determinism Concerns

Animation must be a replayable presentation of resolved state, not a source of truth.

Rules:

- Core rules produce deterministic state changes and event summaries.
- Animation presenters consume event summaries and may be skipped without changing state.
- Saves store the stable post-event gameplay state. They should not resume in the middle of a melee swing, spell flare, town build animation, or route step.
- Manual saves during an animation should either wait for a stable state or save the already-resolved state with no transient playback dependency.
- Replays, validation harnesses, and bug reports should log event ids, subjects, targets, result numbers, status deltas, and cue ids.
- Random visual variance must be seeded from non-authoritative presentation seeds or event ids and must not influence gameplay RNG.
- AI playback can be fast-forwarded while preserving event ordering and final state.

## Editor And Tooling Implications

Future tooling needs:

- Cue catalog validator: verifies every referenced cue has normal, fast, and reduced-motion fallbacks.
- Content validator extensions: warn when production units, spells, artifacts, objects, or buildings lack required animation metadata once the schema exists.
- Map editor preview: show object states and simple animation-readiness flags without requiring final runtime playback.
- Battle validation surface: expose animation event summaries for move, attack, damage, status, spell, death, and outcome.
- Town validation surface: expose action cue summaries for build, recruit, study, market, defense, occupation, and capture.
- Screenshot/readability tests: verify VFX does not obscure stack counts, route paths, resource deltas, or town command surfaces.
- Performance probes: track animated object count, particle count, queue length, skipped events, and cache invalidations.
- Art review checklist: concept source, scale read, frame count, timing, audio cue, reduced-motion cue, implementation status.

## Validation And Testing Gates

Before animation can be treated as a production foundation, implementation must eventually pass these gates:

1. JSON/schema integrity, once animation metadata exists.
   - Missing cue ids, missing fallback variants, invalid state names, unsupported surface ids, and missing reduced-motion variants fail validation.
2. Battle event playback smoke.
   - Move, melee, ranged, spell, hit, status, death, retaliation, and outcome events emit expected cue summaries and leave state unchanged by playback.
3. Overworld event playback smoke.
   - Route movement, pickup, site capture, guard trigger, fog reveal, day advance, and enemy action cues play without static-cache churn.
4. Town action playback smoke.
   - Build, recruit, study, market, garrison, defense, capture, and occupation cues are visible and skippable.
5. UI microinteraction smoke.
   - Hover, press, invalid, resource delta, save/load, and modal transitions have normal/fast/reduced-motion behavior.
6. Accessibility smoke.
   - Reduced motion disables heavy camera/shake/loop effects; color-only cues have alternate indicators.
7. Performance smoke.
   - A dense map viewport, a busy battle, and a town scene stay within the chosen frame budget.
8. Manual play gate.
   - A player can understand AI actions, battle outcomes, site captures, town changes, and spell/artifact effects without reading debug logs.

## Migration Sequence

This is the recommended staged path after this design slice.

1. Define animation event contract.
   - Add event summaries to existing rule/action results without changing outcomes.
   - Start with battle move/attack/damage/status/death, overworld movement/pickup/capture, town build/recruit/study, and UI invalid/resource deltas.
2. Build low-risk UI motion kit.
   - Shared hover/press/invalid/resource/status feedback with reduced-motion support.
3. Build battle presenter prototype.
   - Placeholder motion for active, move, attack, hit, death, status, spell impact, and retaliation using existing static tokens.
4. Build overworld presenter prototype.
   - Hero route step/summary, pickup collect, site capture, fog reveal, guard trigger, and AI action focus without breaking render-cache boundaries.
5. Build town presenter prototype.
   - Build/recruit/study/market/defense/capture cues using existing procedural town stage.
6. Add cue catalog and validation.
   - Normal, fast, reduced-motion, audio ids, VFX ids, blocking policy, and fallback rules.
7. Run concept-art and animatic gates.
   - One faction vertical proof covering unit, hero, town, object, spell, artifact, and UI cue language.
8. Expand data schema only after the prototype proves shape.
   - Add animation metadata to content domains in vertical bundles, not broad empty fields.
9. Production asset integration.
   - Replace placeholders with approved spritesheets/scenes/VFX/audio while keeping validation and fallback cues.
10. Campaign/skirmish reliance gate.
   - Only after battle, town, overworld, UI, spell, artifact, save/resume, fast mode, and reduced-motion cues work together should broad campaign or skirmish production rely on animation.

## Deep Enough Before Town/Battle Polish

Town polish can rely on animation only when:

- At least one faction town has approved ambient/build/recruit/study/market/defense/capture animatics.
- Town actions emit cue summaries and can be skipped or reduced-motion collapsed.
- Building state changes are visible without covering the scenic town with large reports.
- Performance and accessibility gates pass.

Battle polish can rely on animation only when:

- Core unit states exist for at least one vertical faction plus neutral encounter stand-ins.
- Movement, melee, ranged, spell, hit, death, status, retaliation, morale/cohesion, and outcome cues are readable and deterministic as presentation.
- Spell and artifact feedback has school/source identity and preview clarity.
- AI turns can play quickly while preserving event order and player comprehension.
- Save/resume never depends on transient animation progress.

Campaign/skirmish production can rely on animation only when:

- Overworld hero, object, town, battle, UI, spell, and artifact cues share a consistent event/cue contract.
- Object taxonomy states and faction motion languages are represented in concept briefs and validation.
- Strategic AI planning has a way to surface its turns through readable animation events.
- Reduced-motion, fast mode, and mute-equivalent visual feedback exist.

## AcOrP Decision Points

No hard blocker is identified for this documentation slice. Future implementation should ask AcOrP to confirm:

- Whether animation implementation should prioritize battle readability first or overworld/town state clarity first.
- Whether the first vertical proof faction should be Embercourt, because its Beacon/road/town language is already central to River Pass-style proof, or another faction for stronger contrast.
- Whether the production art pipeline should target sprite sheets, cutout scene rigs, or a hybrid for units and heroes.
- How aggressive normal-mode animation pacing should be compared with fast-mode tactical play.
- Which audio direction constraints should be approved before SFX cue production starts.

## Limits

This document is planning only. It does not add gameplay code, scenes, scripts, runtime assets, audio files, content JSON, animation metadata, or playability claims.
