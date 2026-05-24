# Economy Town Goal Scorecard Report

Slice: `economy-town-goal-scorecard-20260524-10184`

This slice adds `economy_town_goal_scorecard_report_v1`, a top-level regression scorecard for the owner-directed economy and town-development goal. The scorecard does not replace the focused runtime reports; it consolidates the explicit objective requirements so future regressions fail in one place.

The scorecard gates:

- all nine live stockpile resources: `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`;
- active-scenario source coverage for every live resource;
- at least 15 authored towns completing full development within the 30-turn target;
- one build per town turn through authored `one_build_per_turn` profiles and deterministic build logs;
- common-resource-dominant town development using `gold`, `wood`, and `ore`;
- high-tier faction rare-resource pressure with the 2/4/6 rare-resource tier curve;
- at least `MIN_RARE_DEVELOPMENT_SPEND = 14` faction rare spend and `MAX_ENDING_RARE_AFTER_COMPLETION = 13`;
- distinct six-faction town/unit/economy fingerprints plus at least five unique non-unit buildings per authored faction town;
- seven unit tiers and seven matching unit-unlocking town buildings per faction.

The default scorecard is intentionally fast and deterministic. The optional `--include-runtime` mode additionally runs the live Godot town-development runtime report, the active player-town scenario runway report, and the active AI-town scenario runway report. Current runtime-inclusive evidence passes 10/10 checks, including 15/15 live runtime town-development and recruitment cases, 105/105 authored-town tier recruitment cases, 18/18 active player-town runway cases with 126/126 recruited tiers, and 20/20 active AI-town runway cases with same-day build guards and delayed-source save/resume.

This is production-readiness regression evidence for the current authored economy/town model. It is not final campaign balance, final encounter pacing, final route safety, final strategic AI quality, final town UI/art approval, final exact-price approval, or a claim that every future scenario template has completed economy pacing.

No `SAVE_VERSION` bump. `wood` remains canonical.
