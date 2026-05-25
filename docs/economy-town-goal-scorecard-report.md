# Economy Town Goal Scorecard Report

Slice: `economy-town-goal-scorecard-20260524-10184`

This slice adds `economy_town_goal_scorecard_report_v1`, a top-level regression scorecard for the owner-directed economy and town-development goal. The scorecard does not replace the focused runtime reports; it consolidates the explicit objective requirements so future regressions fail in one place.

The scorecard gates:

- all nine live stockpile resources: `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`;
- active-scenario source coverage for every live resource;
- full-resource balance/headless harness accounting coverage, so shared economy pressure and economy delta evidence cannot regress to common-only `gold`, `wood`, and `ore` rows;
- at least 15 authored towns completing full development within the 30-turn target;
- one build per town turn through authored `one_build_per_turn` profiles and deterministic build logs;
- common-resource-dominant town development using `gold`, `wood`, and `ore`;
- price-band sanity for total town development costs, rejecting extreme authored totals outside bounded `gold`, `wood`, `ore`, faction rare, target-count, and rare-building-count bands;
- high-tier faction rare-resource pressure with the 4/8/10 rare-resource tier curve;
- at least `MIN_RARE_DEVELOPMENT_SPEND = 24` faction rare spend and `MAX_ENDING_RARE_AFTER_COMPLETION = 13`;
- late rare-resource bottleneck evidence, so every authored town has at least one day 18+ stall where an available high-tier or upgrade building is blocked by its faction rare resource;
- wood/ore bottleneck evidence, so every authored town has at least one development stall caused by common material shortage rather than only gold or rare resources;
- tier 5-7 signature unit-building pacing floors of day 4, day 12, and day 22;
- at least one rare-cost upgrade chain per authored town, with the upgrade chained behind tier 5+ development;
- distinct six-faction town/unit/economy fingerprints plus at least five unique non-unit buildings per authored faction town;
- seven unit tiers and seven matching unit-unlocking town buildings per faction;
- runtime TownShell resource/build UI coverage for all nine resources, rare build bottlenecks, and common-only market boundaries;
- runtime TownShell recruitment UI coverage for seven-tier recruit actions, tier labels, affordability, and loaded unit portraits;
- active-scenario source-route runtime coverage for player-town wood, ore, and faction-rare source reachability through live overworld route rules;
- generated package town-economy runtime surface coverage, so strict Small native package sessions expose authored town templates, seven-tier town ladders, rare-resource development identity, identity diversity across project factions/town templates, and live generated common plus player-faction rare resource sources;
- generated package player-town development runway coverage, so the actual disk-loaded strict Small native package player town builds all initially missing targets through live rules within 30 turns, spends rare resources, blocks same-day second builds, advances generated economy days, and recruits all seven tiers;
- runtime recruitment market coverage, so post-development wood/ore shortfalls are recovered through common-only market purchases and cap-reset waits where needed;
- active AI six-faction town coverage, so live enemy-town development and recruitment evidence includes all six controller factions and native town ladders;
- runtime weekly town-market cap persistence for common-resource exchanges, including cap exhaustion, save/resume continuity, next-week reset, and rare-resource market exclusion.

The default scorecard is intentionally fast and deterministic. Current deterministic evidence passes 13/13 checks, with 15 authored towns completing between day 24 and day 30, tier 7 signature unit buildings arriving between day 22 and day 28, 15/15 authored towns carrying at least one rare-cost upgrade chain, 15/15 towns inside price-band sanity limits, every authored town hitting at least one late rare-resource bottleneck day, every authored town hitting at least one wood/ore bottleneck day, and 4/4 balance/headless harness source files preserving the nine-resource accounting contract. The optional `--include-runtime` mode additionally runs the live Godot town-development runtime report, the active player-town scenario runway report, the active source-route report, the generated package town-economy runtime surface and player-town development runway, the active AI-town scenario runway report, the live unique-building payoff runtime gate, the TownShell resource/build UI surface report, the TownShell recruitment UI surface report, and the runtime market-cap persistence report. Current runtime-inclusive evidence passes 25/25 checks, including 15/15 live runtime town-development and recruitment cases, 105/105 authored-town tier recruitment cases, authored-town runtime recruitment market coverage for post-development common-material shortfalls, 18/18 active player-town runway cases with rare spend, full-session execution, delayed-source replay/save-resume, and 126/126 recruited tiers, 54/54 active player-town source routes reachable for wood, ore, and faction rare resources, 7/7 generated package towns backed by authored templates and seven-tier ladders with 4 generated project factions and 5 generated town templates, player required common and rare resource sources present, 22 initially missing generated player-town targets built by day 22, generated package player town builds all targets, spends rare resources, blocks same-day second builds, and recruits all seven tiers, 20/20 active AI-town runway cases with rare spend, full-session execution, same-day build guards, delayed-source save/resume, 140/140 seven-tier AI recruitment candidates, and all six active AI controller/native town-ladder factions covered, 127/127 unique non-unit building payoff cases with at least four payoff domains per authored town, 6/6 TownShell resource/build UI cases proving rare build bottlenecks and common-only market boundaries, 42/42 TownShell seven-tier recruitment UI cases with loaded portraits, and persisted weekly town-market caps proving buy/sell exhaustion, save/resume continuity, next-week reset, and common-resource-only exchange.

This is production-readiness regression evidence for the current authored economy/town model. It is not final campaign balance, final encounter pacing, final route safety, final strategic AI quality, final town UI/art approval, final exact-price approval, or a claim that every future scenario template has completed economy pacing.

No `SAVE_VERSION` bump. `wood` remains canonical.
