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
- tier 5-7 signature unit-building pacing floors of day 4, day 12, and day 22;
- at least one rare-cost upgrade chain per authored town, with the upgrade chained behind tier 5+ development;
- distinct six-faction town/unit/economy fingerprints plus at least five unique non-unit buildings per authored faction town;
- seven unit tiers and seven matching unit-unlocking town buildings per faction.

The default scorecard is intentionally fast and deterministic. Current deterministic evidence passes 11/11 checks, with 15 authored towns completing between day 24 and day 30, tier 7 signature unit buildings arriving between day 22 and day 28, 15/15 authored towns carrying at least one rare-cost upgrade chain, 15/15 towns inside price-band sanity limits, and 4/4 balance/headless harness source files preserving the nine-resource accounting contract. The optional `--include-runtime` mode additionally runs the live Godot town-development runtime report, the active player-town scenario runway report, the active AI-town scenario runway report, and the live unique-building payoff runtime gate. Current runtime-inclusive evidence passes 15/15 checks, including 15/15 live runtime town-development and recruitment cases, 105/105 authored-town tier recruitment cases, 18/18 active player-town runway cases with 126/126 recruited tiers, 20/20 active AI-town runway cases with same-day build guards and delayed-source save/resume, and 127/127 unique non-unit building payoff cases with at least four payoff domains per authored town.

This is production-readiness regression evidence for the current authored economy/town model. It is not final campaign balance, final encounter pacing, final route safety, final strategic AI quality, final town UI/art approval, final exact-price approval, or a claim that every future scenario template has completed economy pacing.

No `SAVE_VERSION` bump. `wood` remains canonical.
