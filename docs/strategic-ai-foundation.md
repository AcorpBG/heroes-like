# Strategic AI Foundation

Status: design and technical planning source, not implementation proof.
Date: 2026-04-25.
Slice: strategic-ai-foundation-10184.

## Purpose

This document defines the strategic AI foundation for computer-controlled heroes, towns, sites, economy, objectives, and pressure in Aurelion Reach. It is the last major deep-production foundation planning slice before choosing execution slices for actual concept-art generation or implementation planning.

The goal is not to make the opponent look busy by spawning raids. The goal is to make computer factions play the same strategic game the player plays: collect resources, choose town investments, recruit armies, move heroes, scout, contest sites, defend gains, use spells and artifacts, pressure objectives, and expose their reasoning clearly enough that the player can respond.

Heroes 2, Heroes 3, and Oden Era may inform expectations for strategic opponent pressure, adventure-map density, difficulty readability, and turn pacing only. They are not source material for factions, maps, AI personalities, text, art, or authored scenarios.

## Current Gap

The current codebase already has useful strategic-AI scaffolding:

- `EnemyTurnRules.gd` runs per-faction enemy cycles with treasury, pressure, posture, town income, weekly musters, town building, recruitment, raid launches, siege progress, and public threat summaries.
- `EnemyAdventureRules.gd` advances spawned raid encounters across the map, chooses targets, stores commander records and target memory, values sites/artifacts/rewards, and exposes summaries for visible pressure.
- `BattleAiRules.gd` handles tactical battle decisions, field objectives, commander spell-use constraints, cohesion/momentum logic, and enemy combat behavior.
- `DifficultyRules.gd` provides early difficulty profiles for movement, income/reward scaling, raid pressure, pillage, damage, and initiative.
- Existing content can define enemy faction configs, strategy overrides, pressure rates, raid thresholds, priority targets, town ownership, resource sites, commanders, and encounters.

This is not yet production strategic AI:

- Enemy turns are still closer to an empire pressure/raid director than full hero-and-town play.
- Computer-controlled heroes do not yet fully share the player model for movement points, route choice, scouting, fog memory, town visits, army transfer, spellcasting, artifacts, and objective decisions.
- The economy model is still narrow around `gold`, `wood`, and `ore`, while the target economy foundation requires faction resources, site classes, weekly yields, market limits, and resource-specific shortages.
- Town governors can build and recruit, but they do not yet produce explainable multi-week plans tied to faction strategy, map pressure, scarcity, defense, or future unit tiers.
- Map-object valuation needs to expand with the object taxonomy: decoration, pickups, persistent economy sites, transit, neutral dwellings, visible neutral encounters, guarded rewards, landmarks, and objective objects.
- AI battle entry, avoidance, surrender/retreat, neutral encounter decisions, adventure spells, artifact equip choices, and campaign objective play need stronger shared contracts.
- AI events and animations are not yet modeled as a readable playback sequence. A player may see summaries, but not enough clear cause/effect on the map.
- Difficulty knobs currently scale numbers more than competence, information, risk appetite, and planning depth.

The foundation task is to preserve the good scaffolding while defining the production target before campaign/skirmish maps rely on AI for challenge.

## Design Goals

Strategic AI must satisfy these goals:

1. Play the same rules by default.
   - AI towns, heroes, armies, spells, artifacts, resources, movement, fog, and objectives should use the same core data and rule services as the player unless a difficulty profile explicitly grants an exception.
2. Create pressure without cheating opacity.
   - The player should understand why a threat exists: a faction owns mines, mustered troops, captured an artifact, launched a commander, opened a route, or exploited a visible weakness.
3. Express faction personality.
   - Embercourt should defend roads and crossings differently from Mireclaw raids, Sunvault relay fronts, Thornwake rooted networks, Brasshollow mine staging, and Veilmourn fog/salvage pressure.
4. Stay deterministic enough to test.
   - Turn plans, target scoring, and seeded choices must be replayable from save state and content ids.
5. Scale from River Pass to campaign/skirmish breadth.
   - A small scenario can use scripted guidance and modest AI. A broad skirmish needs independent governors, heroes, scouting, counterplay, and objective priorities.
6. Support fast and readable playback.
   - AI turns must be skippable or fast-resolvable while still surfacing important movement, capture, combat, build, spell, artifact, and objective events.
7. Avoid fake intelligence through surprise.
   - No invisible perfect information, arbitrary teleports, unshown resource creation, or hidden guard outcomes unless the scenario/difficulty explicitly labels that rule.

## Strategic Turn Model

The target AI turn should be a staged pipeline. Each stage emits decisions, state changes, and event records for UI/animation/debug playback.

1. Normalize state.
   - Validate AI faction state, hero rosters, town ownership, site control, resources, fog memory, commander status, active tasks, pending battles, and save/schema versions.
2. Update knowledge.
   - Refresh visible tiles from AI scouting rules, age remembered information, mark stale enemy sightings, and classify unknown risks.
3. Evaluate strategic situation.
   - Score victory objectives, threats to owned towns/sites, economy shortages, recruit pools, build blockers, active enemy heroes, neutral blockers, route opportunities, and known artifacts/spells.
4. Town governor planning.
   - For each AI town, choose build, recruit, garrison, market, study, defense, and support tasks within a multi-week plan.
5. Hero task planning.
   - Assign heroes to roles: scout, collector, site capturer, raider, defender, main army, courier, objective runner, harassment, retreat/rebuild.
6. Movement and action execution.
   - Spend movement through the same pathing model, resolve visits, captures, pickups, transit, neutral battles, town entry, spell actions, and artifacts.
7. Combat decisions.
   - Decide whether to enter, avoid, reinforce, retreat, auto-resolve, or present battle. Battle AI remains tactical but receives strategic intent.
8. Post-action accounting.
   - Apply rewards, losses, commander memory, site control changes, spell cooldowns, artifact state, town pressure, and objective progress.
9. Surface events.
   - Produce a compact, ordered event stream for animation, logs, summaries, and debug explanations.
10. Save-stable commit.
   - Store final strategic state, not transient playback state.

The current `EnemyTurnRules.run_enemy_turn` can remain the near-term entry point, but future implementation should separate the pipeline into testable planners and executors instead of burying all reasoning in one turn cycle.

## AI State Model

Future AI state should be explicit rather than inferred from scattered encounter fields.

Recommended per-faction state:

- `faction_id`
- `ai_profile_id`
- `difficulty_ai_profile_id`
- `treasury`
- `resource_shortages`
- `posture`
- `strategic_plan`
- `town_governor_states`
- `hero_roster_states`
- `active_tasks`
- `known_world_memory`
- `objective_memory`
- `threat_memory`
- `site_memory`
- `artifact_memory`
- `spell_plan_memory`
- `recent_events`
- `turn_seed`

Recommended hero state additions:

- Role: scout, main, raider, defender, collector, courier, objective, recovering.
- Assigned task id and target.
- Planned path and fallback path.
- Army strength estimate, mobility estimate, risk tolerance, retreat threshold.
- Spell and artifact plan references.
- Memory of recent targets, rivals, defeats, and avoided threats.

Recommended town governor state:

- Build plan queue.
- Recruitment plan.
- Garrison target.
- Resource blockers.
- Market use limits.
- Defense priority.
- Support requests from nearby heroes.
- Recovery/stabilization state after capture.

Existing commander roster records and target memory are a good seed. They should be generalized into full hero roster state instead of remaining only raid-host metadata.

## Town Governor AI

Each AI town needs a governor that can act locally while still serving faction strategy.

Governor responsibilities:

- Maintain minimum garrison based on town value, distance to threats, local front state, and difficulty.
- Choose buildings using economy needs, faction identity, unlock goals, growth, defense, magic access, market value, and pressure output.
- Recruit from available pools and assign troops to town defense, active heroes, recovering heroes, or courier logistics.
- Use local markets only within scarcity rules and weekly caps.
- Study or refresh spells when magic buildings exist and heroes can use them.
- Request defense when a player hero approaches or nearby site control collapses.
- Stabilize newly captured towns before converting them into aggressive staging points.
- Preserve faction identity when captured towns are off-faction: useful infrastructure remains, but off-faction recruitment/spell access should be constrained by rules.

Governor planning should use horizons:

- Immediate: survive the next threat and spend affordable high-value actions.
- Weekly: align growth/recruitment with resource availability and hero needs.
- Long-term: unlock faction-defining tiers, magic, economy buildings, and map pressure tools.

Town build scoring should include:

- Marginal daily/weekly income.
- Unlock value for blocked units/spells/services.
- Recruitment growth and quality.
- Defense and recovery value.
- Faction strategy weight.
- Scarce resource opportunity cost.
- Objective support value.
- Whether the build creates a visible player-facing pressure change.

## Hero And Army AI

Strategic AI must eventually treat computer heroes as real map actors, not only spawned hostile contacts.

Hero responsibilities:

- Scout unknown and stale regions.
- Collect safe pickups and guarded rewards when worthwhile.
- Capture and defend mines/resource sites.
- Attack weak player heroes or exposed garrisons.
- Avoid hopeless battles unless delaying matters.
- Transfer or receive troops through towns and logistics sites.
- Use towns for recruiting, spell study, recovery, and artifact management.
- Carry artifacts that match role and army.
- Cast adventure spells when their map value exceeds cost/risk.
- Execute campaign/skirmish objectives.

Army valuation must account for:

- Stack count, tier, current health/count, roles, ranged/melee mix, speed, spell synergy, status traits, and faction strategy.
- Hero command, level, specialties, spellbook, artifacts, morale/cohesion, movement, and scouting.
- Battle context: terrain, field objectives, siege/town defense, guard strength, neutral traits, retreat options.
- Strategic context: can a win produce a site, objective, town capture, artifact, or safe route?

AI hero roles:

| Role | Purpose | Typical behavior |
| --- | --- | --- |
| Scout | Information and route opening | Avoids fights, reveals objects, tags risk, values movement/scouting artifacts |
| Collector | Low-risk economy pacing | Picks caches, claims unguarded sites, returns to town when threatened |
| Capturer | Expansion and site control | Clears standard guards, captures mines, defends route-linked sites |
| Main army | High-value fights and objectives | Stages at towns, takes guarded rewards, attacks major towns/heroes |
| Raider | Harassment and counter-capture | Targets exposed sites, weak towns, delivery routes, and backline economy |
| Defender | Town/site protection | Intercepts threats, garrisons, escorts, retakes local sites |
| Courier | Logistics later | Moves troops/artifacts between towns and main heroes if implemented |
| Recovering | Loss management | Retreats, waits for reinforcements, returns to friendly town |

The existing raid commander model can evolve into these roles. Raid hosts should become one possible role, not the entire strategic AI.

## Economy Planning

AI economy planning must follow `docs/economy-overhaul-foundation.md`.

Near-term compatibility:

- Existing `gold`, `wood`, and `ore` remain valid until the resource migration is implemented.
- AI code should stop hardcoding the current three-resource set where future schema can provide known resources, resource categories, and faction preferences.

Target planning:

- Track current stockpile, daily income, weekly yield, projected spending, and blockers.
- Identify resource shortages by faction plan: building blocker, recruit blocker, spell catalyst blocker, artifact use blocker, market blocker, or objective blocker.
- Value sites by the resources they produce, scarcity they solve, route exposure, guard cost, counter-capture risk, and faction preference.
- Reserve resources for high-priority future purchases instead of spending everything on the first affordable action.
- Use markets conservatively and explainably, respecting exchange caps and faction access.
- Treat rare resources as strategic: aetherglass, embergrain, peatwax, verdant grafts, brass scrip, memory salt.

Faction examples:

- Embercourt values stable income, embergrain recovery, roads, bridges, and defensive support sites.
- Mireclaw tolerates weaker safe income if raids, peatwax, dens, and counter-capture stay active.
- Sunvault hoards ore and aetherglass for quality units, relays, and magic buildings.
- Thornwake protects timber and verdant grafts, links rooted sites, and avoids overextension before networks mature.
- Brasshollow saves ore and brass scrip for capital projects, mine defense, and repair-heavy armies.
- Veilmourn accepts uneven income, scouts aggressively, values memory salt, salvage spikes, fog routes, and hidden reward knowledge.

## Recruitment And Building Planning

Recruitment and building must become linked plans.

Recruitment planning should decide:

- Which unit tiers are affordable now.
- Which missing building unlocks the most important future recruit pool.
- Whether to spend on many low-tier bodies, save for a high-tier unit, rebuild a defeated hero, or garrison a threatened town.
- Which hero receives new troops and why.
- Whether neutral dwelling recruits fit the current army or only drain resources.

Building planning should decide:

- Economy first when safe.
- Dwellings when recruit pool is the bottleneck.
- Magic buildings when hero/spell identity and catalysts justify them.
- Defensive buildings when player proximity, objective value, or recent capture risk is high.
- Market/support buildings when shortages block multiple plans.
- Capstones only when the map is stable enough to protect the investment.

Validation should catch AI governors that:

- Leave towns empty while enemies are nearby.
- Spend rare resources on low-impact builds while blocked from faction-defining plans.
- Recruit units into a town forever without launching or reinforcing heroes.
- Build randomly with no relationship to economy, threats, or faction identity.

## Movement, Pathing, And Object Valuation

AI movement must use a shared pathing model with player movement.

Movement requirements:

- Movement points, terrain passability, roads, transit objects, town/object approach tiles, fog, blockers, and future footprint occupancy must be represented in path evaluation.
- AI should plan routes over multiple turns but re-evaluate after new scouting, player movement, site capture, or battle results.
- Routes need risk labels: safe, contested, guarded, exposed, stale, blocked, costly, hidden, or unknown.
- AI should respect visible neutral encounters and guarded rewards instead of treating them as walkable scenery.

Object valuation must follow `docs/overworld-object-taxonomy-density.md`:

- Decoration/non-interactable: path shape and scouting context only.
- Pickup: low-cost tempo value, higher when solving a shortage or on-route.
- Interactable site/building: service/reward value, revisit cadence, ownership value.
- Persistent economy site: income, resource scarcity, counter-capture value, route exposure.
- Transit/route object: movement savings, objective access, threat projection, denial value.
- Neutral dwelling: recruit value, guard risk, roster fit, refresh timing.
- Overworld neutral encounter: threat, guard relation, experience/reward, route block, avoidance value.
- Guarded reward site: reward class, guard strength, artifact/spell/resource probability, timing.
- Faction landmark: identity pressure, objective hooks, services, morale/magic/economy effects.

Target scoring formula should be transparent enough for debug:

`score = reward_value + strategic_value + scarcity_value + objective_value + denial_value + faction_bias - travel_cost - guard_cost - exposure_risk - opportunity_cost`

The formula can be implemented as weighted components, but debug output must expose the components.

## Site Capture, Defense, And Counter-Capture

AI pressure depends on contestable map control.

Required behavior:

- Capture unowned sites that solve a shortage or support a route.
- Defend high-value owned sites near active fronts.
- Counter-capture exposed player sites when direct town attacks are too risky.
- Retake faction-critical sites such as Embercourt crossings, Sunvault relays, Thornwake roots, Brasshollow mines, Veilmourn fog slips, and Mireclaw ferry/peat sites.
- Pillage or disrupt only when the rules support it and the UI can explain it.
- Avoid endless whack-a-site behavior by considering distance, payoff, and front importance.

Site control events should create:

- Income changes.
- Route changes.
- Threat summaries.
- Animation/event cues.
- Commander memory and rivalry when a player repeatedly contests the same front.

Deep-enough requirement: a skirmish map cannot rely on AI until at least one opponent can capture, lose, retake, and defend economy sites in a way a player can observe and counter.

## Neutral Encounter Decisions

AI must decide whether to fight, avoid, delay, or route around neutral encounters.

Decision inputs:

- Estimated enemy strength and uncertainty.
- AI army strength, casualties expected, spell/artifact counters, and retreat options.
- Reward class of the guarded site.
- Whether the encounter blocks an objective, economy site, transit route, or scouting lane.
- Faction appetite for risk.
- Difficulty profile.
- Time pressure.

Outcomes:

- Fight now.
- Wait for reinforcements.
- Route around.
- Mark as future target.
- Use adventure spell/artifact to reduce risk.
- Ignore permanently if reward is low.

AI should not clear neutrals offscreen without event surfacing when the result matters to the player. Important neutral clearance should appear as an AI event: movement, battle, losses summary, reward/capture, and new threat state.

## Battle Entry And Avoidance

Strategic AI should not enter every possible battle.

Battle decision categories:

- Favorable fight: engage.
- Strategic sacrifice: engage to delay, block, pillage, or protect objective.
- Unfavorable but necessary: engage if losing a town/objective would be worse.
- Avoidable bad fight: retreat, route around, garrison, or call support.
- Ambush/opportunity: engage if payoff is high and risk is acceptable.
- Neutral guard: compare expected loss to reward and timing.

Battle-entry output should include:

- Intent: attack, defend, intercept, clear guard, siege, raid, delay, escape.
- Expected confidence.
- Retreat/surrender threshold.
- Tactical AI posture passed into `BattleAiRules`.
- Event label for UI and debug.

Future battle AI should receive strategic intent. A raider trying to delay should fight differently from a main army trying to preserve elite stacks for a town siege.

## Spell Planning

Spell planning must follow `docs/magic-system-expansion-foundation.md`.

Strategic spell roles:

- Scout unknown or stale tiles.
- Reveal guarded risk.
- Open or discount routes.
- Repair or activate transit objects.
- Boost economy/site output under caps.
- Defend towns or owned sites.
- Hide or misdirect route value.
- Prepare a battle with buffs, wards, or terrain effects.
- Avoid a battle through fog, root, recall, or route control when allowed.

Battle spell roles:

- Finish valuable stacks.
- Protect fragile elites.
- Control movement or line of fire.
- Cleanse or counter high-impact effects.
- Preserve army value for later strategic tasks.

AI spell decisions must evaluate:

- Mana and catalyst costs.
- Spell tier and cooldown.
- Faction affinity and hero mastery.
- Artifact modifications.
- Target legality and scenario safety.
- Whether the spell changes a decision, not just whether it can be cast.

Rule: adventure spells that alter routes, economy, reveal scope, or site state must not ship before AI can understand them enough to avoid breaking maps.

## Artifact Planning

Artifact planning must follow `docs/artifact-system-expansion-foundation.md`.

AI artifact responsibilities:

- Value artifacts before pickup or guarded-site attack.
- Equip artifacts based on hero role, army, faction identity, spells, economy, and current objectives.
- Respect slots, set bonuses, curses/tradeoffs, charges, and scenario restrictions.
- Prefer movement/scouting artifacts on scouts, economy artifacts on governors or support heroes, combat artifacts on main armies, and school artifacts on matching casters.
- Protect or recover high-value artifacts after battle when rules allow.
- Surface artifact-driven pressure in threat summaries.

AI must not treat artifacts as flat stat sticks once sets, school hooks, economy hooks, and curses exist. The valuation contract should expose value drivers: movement, scouting, combat, defense, economy, magic, resistance, route, set, objective, and risk.

## Faction Personalities

Faction AI profiles should be data-driven and overrideable per scenario.

Shared profile fields:

- `exploration_bias`
- `economy_bias`
- `site_capture_bias`
- `town_attack_bias`
- `defense_bias`
- `counter_capture_bias`
- `risk_tolerance`
- `neutral_clearance_bias`
- `artifact_bias`
- `spell_bias`
- `scouting_bias`
- `main_army_bias`
- `raiding_bias`
- `garrison_bias`
- `market_bias`
- `objective_bias`
- `retreat_threshold`
- `information_honesty`

Faction direction:

| Faction | Strategic AI personality |
| --- | --- |
| Embercourt League | Consolidates roads, crossings, towns, and granaries. Retakes public infrastructure, values garrisons, and punishes overextension rather than gambling on deep raids. |
| Mireclaw Covenant | Splits pressure across ferry routes, peat sites, exposed mines, and wounded fronts. Accepts smaller raids, avoids clean sieges until targets are softened, and counter-captures often. |
| Sunvault Compact | Scouts and secures relay/sightline networks before committing expensive armies. Values spell access, aetherglass, ranged lanes, and prepared battles. |
| Thornwake Concord | Seeds territory slowly, defends linked sites, uses recovery and route taxation, and becomes more aggressive once rooted networks mature. |
| Brasshollow Combine | Builds capital projects, protects mines/rails, favors durable main forces, and attacks after resource setup rather than early scatter. |
| Veilmourn Armada | Scouts hard, values salvage and memory salt, bypasses static fronts, attacks weak backline assets, and retreats from poor honest fights. |

Scenario authors can override profiles, but overrides must be named and validated so the behavior remains explainable.

## Scouting, Fog, And Memory

AI information handling must be fair and tunable.

Default rule:

- AI uses its own visibility, scout radius, remembered tiles, and objective clues. It does not get perfect current player positions unless the scenario or difficulty explicitly grants it.

Memory model:

- Known current: visible this turn.
- Recent: remembered with high confidence.
- Stale: known object/location, uncertain owner/army.
- Rumored: clue from scouting spell, objective script, artifact, or event.
- Unknown: no reliable data.

AI should:

- Revisit stale high-value sites.
- Scout likely player routes.
- Infer threat from captured sites, missing guards, and visible towns.
- Avoid acting on stale data as if it were current.
- Use scouting spells/artifacts/sites when uncertainty blocks good decisions.

Difficulty can adjust information honesty:

- Story: slower AI scouting, more visible warnings, less exploitation of stale player weakness.
- Normal: fair scouting and memory.
- Hard: better scouting priorities and faster inference, but still no unlabelled omniscience.

## Campaign And Skirmish Objectives

AI must understand objective types before maps rely on it.

Objective categories:

- Capture town.
- Hold town for duration.
- Capture/hold site network.
- Escort or intercept route.
- Recover artifact.
- Defend artifact or hero.
- Clear guarded region.
- Open transit/objective path.
- Accumulate resources.
- Survive or delay.
- Defeat specific hero.
- Scenario-scripted restoration/sabotage action.

Each objective needs:

- AI priority.
- Target ids.
- Time pressure.
- Failure consequence.
- Whether AI can complete it, block it, defend it, or only react to it.
- UI/debug explanation.
- Save-stable progress state.

Skirmish maps need objective-neutral AI that can pursue towns, resource control, hero pressure, and artifacts. Campaign maps can script stronger priorities, but the AI should still use general planners where possible.

## Difficulty Tuning

Difficulty should mix assistance, pressure, competence, and information policy.

Knob families:

- Economy: income, market generosity, starting resources, resource scarcity tolerance.
- Recruitment: growth, cost discounts, mustering speed, reinforcement priority.
- Movement: movement points, route-risk tolerance, retreat distance.
- Pressure: raid threshold, max active threats, objective urgency, counter-capture frequency.
- Combat: tactical AI depth, damage/initiative modifiers, retreat rules.
- Information: scouting radius, memory decay, hidden objective hints, omniscience allowance.
- Planning: lookahead horizon, candidate count, stochasticity, mistake chance.
- UI warnings: how early the player sees threat summaries and AI intent.

Recommended stance:

- Story should reduce pressure and improve player recovery, not make the AI nonsensical.
- Normal should use fair rules and competent but imperfect planning.
- Hard can plan deeper, coordinate better, and exploit scouting more, but should label any material bonuses.

Avoid difficulty that only changes damage or income. A hard AI should feel better organized, not merely inflated.

## Event And Animation Surfacing

AI turns must feed the animation/event foundation in `docs/animation-systems-foundation.md`.

Event categories:

- Turn start/end.
- Town build/recruit/study/market/garrison.
- Hero movement/path.
- Site capture/counter-capture/pillage/repair.
- Pickup/artifact claim/equip.
- Neutral encounter battle/avoidance.
- Hero-vs-hero or town battle trigger.
- Spell cast/adventure effect.
- Objective progress.
- Fog/scouting reveal.
- Commander defeat/recovery/redeployment.
- Threat posture change.

Each event should include:

- `event_id`
- `turn_id`
- `faction_id`
- `actor_id`
- `actor_kind`
- `event_type`
- `target_kind`
- `target_id`
- `from_position`
- `to_position`
- `summary`
- `public_importance`
- `animation_cue_id`
- `fast_mode_policy`
- `debug_reason`

Playback rules:

- High-importance events animate or focus by default.
- Low-importance events can collapse into a summary.
- Fast mode shortens movement/combat playback but preserves major captures, battles, and objective changes.
- Reduced motion uses focus changes, icons, and resource deltas instead of strong camera movement.

## UI And Debug Explanation

The player needs readable AI intent without a dashboard taking over scenic screens.

Player-facing summaries:

- Threat rail or compact report showing known enemy posture, visible commanders, known targets, and recent events.
- Map pings for important visible AI actions.
- Town/site status deltas after AI captures or pillages.
- Battle trigger previews with attacker, defender, and strategic reason.
- Difficulty bonus summaries in scenario setup and pause/settings detail.

Debug tools for development:

- Per-faction turn plan.
- Candidate target score table.
- Build/recruit decision components.
- Route score and risk classification.
- Scouting/memory state.
- Spell/artifact valuation.
- Battle entry confidence.
- Random seed and deterministic replay id.

Debug explanation should be available in validation snapshots or dev overlays, not forced into the normal player UI.

## Save And Schema Implications

Strategic AI requires versioned save state.

Save state must include:

- AI faction states.
- Town governor states.
- AI hero roster states and active map positions.
- Active tasks and target ids.
- AI resource pools and reserved budgets.
- Fog/memory state.
- Commander records and recovery.
- Spell cooldowns, mana, catalysts, and adventure-spell state.
- Artifact ownership, equipped slots, charges, curses, and set state.
- Objective memory and progress.
- Event history required for summaries.
- AI schema version and migration metadata.

Save state should not include:

- Transient animation playback progress.
- Uncommitted candidate scores unless stored for debug snapshots only.
- Derived values that can be rebuilt safely, unless storing them is necessary for deterministic replay.

Migration principles:

- Existing `enemy_states` should be normalized forward rather than discarded.
- Existing raid encounters should migrate into active AI hero/task records when that model lands.
- Existing `wood` should remain compatible until economy migration resolves `timber`.
- Old saves should load with fallback AI profiles and rebuild missing governor/hero memory.
- Any scenario relying on old pressure raids must continue to work until it is explicitly migrated.

## Validation And Testing Gates

Strategic AI must be validated in layers.

Static/content validation:

- AI profiles reference valid factions, resources, spells, artifacts, objectives, towns, and object classes.
- Strategy weights are numeric and within accepted ranges.
- Objective ids, target ids, and priority targets resolve.
- AI-accessible spells/artifacts obey schema and scenario restrictions.
- Save migration accepts old and new AI state.

Unit tests:

- Town governor build/recruit choices under resource constraints.
- Resource shortage detection and reservation.
- Site valuation by faction and scarcity.
- Pathing around blockers, approach tiles, and neutral encounters.
- Battle entry/avoidance thresholds.
- Spell and artifact valuation components.
- Fog memory aging and stale-target behavior.
- Difficulty profile effects on decisions.

Scenario simulations:

- River Pass-equivalent opponent still pressures without breaking manual play.
- One small two-faction skirmish runs for 30 days without invalid state.
- One dense economy front demonstrates capture, counter-capture, retake, and defense.
- One neutral-heavy route demonstrates fight/avoid/wait choices.
- One objective scenario shows AI can pursue or block the objective.

Live-client gates:

- A player can observe at least three meaningful AI turn events without opening debug tools.
- AI captures and loses a site with clear map/state feedback.
- AI town builds/recruits produce visible later pressure.
- AI hero movement and battle triggers are readable in normal and fast modes.
- Save/resume preserves AI plans enough that behavior continues coherently.

Performance gates:

- AI turn time stays acceptable on target 64x64 maps with multiple factions.
- Debug scoring can be disabled or sampled in release builds.
- Long AI turns can be chunked or presented without freezing the UI.

## Migration Sequence

Strategic AI should migrate in staged slices.

1. Document and validate AI profile schema.
   - Add data contracts for faction personality, target weights, difficulty knobs, and event types.
2. Split current enemy turn logic into planner/executor boundaries.
   - Preserve existing behavior while making town, raid, pressure, and event decisions testable.
3. Add AI event stream.
   - Emit save-safe summaries and animation-ready events from existing pressure/raid/build/recruit actions.
4. Generalize commanders into AI heroes.
   - Represent roles, movement, recovery, army continuity, artifacts, spells, and target memory.
5. Upgrade town governors.
   - Add build queues, recruitment plans, resource reservations, garrison targets, and market rules.
6. Expand economy awareness.
   - Integrate the economy-overhaul resource categories, site outputs, scarcity, market caps, and faction preferences.
7. Upgrade pathing and object valuation.
   - Use footprint/approach rules, transit, neutral encounters, guarded rewards, and persistent site families.
8. Add capture/counter-capture/defense proofs.
   - Build a small validation scenario where site control visibly changes AI priorities.
9. Add battle entry/avoidance and strategic intent handoff.
   - Pass attack/defend/delay/clear/siege intent into battle setup and tactical AI.
10. Add spell and artifact planning.
   - Start with existing spell/artifact data, then migrate to expanded schemas.
11. Add faction-specific personalities.
   - Tune each faction against the faction bible and economy/object/magic/artifact foundations.
12. Add campaign/skirmish objective AI.
   - Make objective pursuit and blocking reliable before broad map production.
13. Add live-client playback and debug tools.
   - Surface AI actions through compact UI, animation cues, summaries, and dev score inspection.
14. Run manual play gates.
   - Prove at least two factions on focused maps before claiming alpha AI readiness.

## Deep-Enough Gate Before Campaign/Skirmish Reliance

Campaign and skirmish maps cannot rely on AI until these conditions exist:

- At least one AI faction can run real town governor turns: build, recruit, garrison, reserve resources, and create later pressure.
- At least one AI hero can move through the map using shared pathing, scout, capture a site, avoid or fight a neutral, return/reinforce, and trigger a battle.
- AI understands persistent site value, counter-capture, and defense well enough to contest economy fronts.
- AI can pursue or block at least one objective type besides generic town pressure.
- AI turn events surface clearly in the live client and are compatible with fast/reduced-motion playback.
- Save/resume preserves AI state, memory, active tasks, and recovery.
- Difficulty settings alter pressure and competence without hidden unlabelled omniscience.
- Validation can run deterministic AI simulations and catch invalid plans, missing ids, impossible paths, and broken save migrations.
- Faction personality exists for at least two factions before alpha-scope maps depend on asymmetric AI.

Until those gates pass, AI should be described as strategic scaffolding, not as a production opponent.

## Next Execution Implication

With the world, faction, concept-art pipeline, economy, object, magic, artifact, animation, and strategic AI foundations documented, the next production choice should move out of foundation planning.

Recommended next action:

- Start the first actual concept-art generation execution slice using `docs/concept-art-pipeline.md`, beginning with world mood and two or three faction direction sheets. When art generation is done, the generated images should be sent to AcOrP on Discord as requested before those images are treated as approved direction for implementation.

Implementation planning can follow after the art-direction evidence starts to exist, with strategic AI likely needing a schema/event/planner slice before broad maps rely on it.
