# RMG audit corrections

Owner direction, 2026-09-05: fix all issues in `docs/rmg-start-placement-and-h3maped-audit.md`; heroes must always start at their own town entrance. This implementation goal supersedes the former off-road start policy, not the recovered native town coordinate or object masks.

## Required outcomes

1. Every generated starting hero uses the owning town's authoritative entrance `(x,y,level)`. No nearest-road relocation. Enter/leave/return-to-town and save/resume must work after complete package adoption; supplemental economy guards/resources must not occupy hero starts or town entrances. Native source placements and masks remain unchanged.
2. Preserve levels throughout live terrain, object/hero/town identity, occupancy, navigation, interaction, vision/minimap, UI and persistence. Small two-level land seed 68 starts on its actual underground entrance and can move. Do not satisfy this by disabling two-level generation or flattening it.
3. Preserve each native player slot and team independently of faction. Six/eight-player cases retain five/seven distinct opposing player states even with repeated factions; AI towns/heroes/turns/ownership and saves agree.
4. Preserve native transit endpoints and functional surface/underground and long-distance connectivity through original assets/content. Validate travel, pathing, AI use, visibility and save/resume. Investigate and correct missing water/Islands traversal exposed by representative complete gameplay; do not substitute a generic local-offset route for a native paired connection.
5. Correct the confirmed Medium normal-water seed-10 native mismatch by identifying the exact recovered function/input/private-state rule in the post-`0x4a4c8e` to pre-`0x49eb8d` window. Prove phase/private-state and full final-writeout parity against matched H3MapEd evidence, with land/water controls. No source replay, count tuning, heuristic topology fixes, gate-only completion, seed exceptions or brute-force retries.
6. Replace stale legacy raw-bank expectations with authoritative authored-pool assertions, retain exact source placement/body/visit data, and expand regressions to enforce all above outcomes across the audited size/water/level/player matrix.

## Execution and compatibility

`project.md` → the correction parent/children in `PLAN.md` → these requirements and the source audit → runtime/native changes → focused and integrated validation → completed tracker evidence. Individual child completion does not complete this full goal.

Native generation semantics and live Aurelion adoption are distinct owners. Entrance starts are an explicit product requirement, not an invented H3MapEd hero-runtime claim. Respect recovered exact masks; legal town interaction must be modeled by rules, not by erasing unrelated blockers. Existing authored one-level scenarios and saved progress remain compatible. If additive fields are insufficient, use an explicit versioned save migration with old/new round-trip coverage rather than silently changing save interpretation.

Player-identity compatibility: new generated sessions retain source players/teams in additive version-1 fields. Already-played generated saves that pooled factions retain their actual historical ownership/economy under explicit `legacy_generated_faction_v0` interpretation, with old-bridge and production-save continuation coverage; do not fabricate missing history or clone pooled treasuries. Reconstructing lost per-player history and multi-human gameplay are not claimed by the one-human runtime correction.

Concrete owners: `map_package_service.cpp`, recovered `h3maped_rmg_core.cpp`, package/session bridge, `OverworldRules.gd`, hero/player/AI rules, persistence and Overworld map/minimap/input owners. Python owns new tests and report orchestration; temporary engine adapters only invoke production paths and collect evidence.

## Validation and completion

- Deterministic native/package/live tests: all 24 size/water/level shapes, seed-165429308 entrance/guard case, underground seed 68, normal-water seed 10, six/eight-player repeated factions, original-content proxy and transit cases; real movement, town interaction, AI turns and save/resume, not config normalization alone.
- Source-backed water checkpoints and complete matched owner payload comparison; retain failed evidence until actual correction. Re-run all 24 retained cases and suitable additional seeds/configurations.
- Python measurement/regression tests; relevant generated-map, occupancy, hero/AI, fog, transit, save and original-object reports; `python3 tests/validate_repo.py`; `git diff --check`.
- Inspect real rendered screenshots at supported resolutions, including both levels and the exact corrected starts; actual cross-level and representative water/Islands gameplay must work.
- Build and test Linux and Windows Debug/Release native outputs together; both native selftests, export/startup and packaged generated Overworld/Town entry; unchanged 250,000,000-byte PCK ceiling.
- Update source-backed requirements/evidence and current strategic/tactical/tracker claims. Commit/push coherent validated implementation; preserve unrelated untracked artifact-retention files/reports.

Non-goals: unrelated art/Town UI/balance/performance rewrites, copied foreign assets/effects, native modes outside the audited/exposed product boundary, arbitrary-seed or whole-game release certification. Source recovery limitations must be named precisely and pursued without replacing the intended outcome with an easier gate or disabled feature.

## Current evidence

The completed entrance-boundary, level-aware runtime and player/team children are recorded in `docs/rmg-town-entrance-correction-report.md`, `docs/rmg-level-aware-runtime-report.md` and `docs/rmg-player-team-identity-correction-report.md`. All 83 sampled native player starts equal their main-town entrances; all 35 supported primary-hero entry/exit/return/save cases pass, including two-level maps. Six/eight-player and explicit-team cases retain independent runtime opponents and pass capture/battle/production-save continuity. Native object/terrain records and payload hashes/lengths are unchanged. The full correction goal remains active: native transit/water navigation, source-proven normal-water parity and integrated regressions remain required.
