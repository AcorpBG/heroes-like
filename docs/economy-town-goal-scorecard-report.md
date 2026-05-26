# Economy Town Goal Scorecard Report

Slice: `economy-town-goal-scorecard-20260524-10184`

This scorecard is the top-level regression surface for the economy and town-development goal. It consolidates the explicit objective requirements, while focused reports remain the source of detailed evidence.

## Current Scope

The active balance target is Native RMG generated maps. Authored town templates still define town costs, ladders, and development rules, but authored scenario/source placement is not the map-source balance surface for this slice.

The scorecard gates:

- all nine live stockpile resources: `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt`;
- full-resource balance/headless harness accounting coverage, so shared economy pressure and economy delta evidence cannot regress to common-only `gold`, `wood`, and `ore` rows;
- at least 15 town templates completing full development inside the day-24 deterministic completion floor and 30-turn target;
- early/mid/late build distribution, one-build-per-town-turn enforcement, one build per town turn, common-resource-dominant town development, and bounded post-completion common-resource surplus;
- all-rare high-tier pressure: signature rare `4/8/10`, secondary rare `3/5/6`, and each remaining rare `2/3/4`;
- price-band sanity for `gold`, `wood`, `ore`, signature rare, secondary rare, remaining rare min/max, target-building count, and rare-cost building count;
- late rare-resource bottleneck evidence, wood/ore bottleneck evidence, high-tier unit-building pacing floors, and at least one rare-cost upgrade chain per town;
- distinct six-faction town/unit/economy fingerprints plus seven unit tiers and seven matching unit-unlocking town buildings per faction;
- runtime TownShell resource/build UI and recruitment UI coverage for all live resources and seven-tier recruitment;
- Native RMG generated package economy surface coverage, so strict Small package sessions expose town templates, seven-tier ladders, all live generated resource sources, and player-required all-rare town-development sources;
- Native RMG generated package source-route coverage, so player, enemy, and neutral generated towns prove reachable generated `wood`, `ore`, and every required rare-source route after exact package movement, block, guard, route-interaction, and corner-cut rules are applied;
- Native RMG generated package guarded-source pressure, so generated economic expansion sources are guarded rather than free pickups;
- generated package player-town, neutral-town capture, and enemy-town development runway coverage, including rare-resource spend, one-build-per-day guards, source adoption, AI governor behavior, and seven-tier recruitment.

## Current Evidence

Default deterministic evidence passes 15/15 checks. Current deterministic town development covers 15 town templates, completes between day 28 and day 30, keeps all towns inside price-band sanity limits, and proves every town uses all six rare resources with the intended pressure ratios.

The Native RMG package adoption report currently passes in strict Small 36x36 one-level land scope. It proves all nine generated resource source ids are present, all required generated town resource routes are reachable, all required rare-source routes are guarded, generated player/enemy/neutral town runways complete inside the pacing window, and generated towns retain seven-tier recruitment.

The optional runtime-inclusive scorecard currently passes 30/30 checks. It proves live UI, AI, market, and generated-package evidence under the Native RMG source-access scope.

## Boundaries

This is production-readiness regression evidence for the current town economy model and strict Small Native RMG package economy surface. It is not campaign production work, final campaign balance, final encounter pacing, final strategic AI quality, final town UI/art approval, final exact-price approval, broad larger-size RMG economy approval, or a claim that authored scenario source placement has been balanced.

No `SAVE_VERSION` bump. `wood` remains canonical.
