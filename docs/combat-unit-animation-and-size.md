# Complete Battle Unit Animation and Size

Owner goal, Phase 6: `combat-unit-animation-and-size-20260913`.

Current state: runtime/size increment validated; full goal blocked at original-art workflow approval. No completed-animation claim.

## Acceptance

All 160 current authored units, including neutral and alternate roster identities, need readable idle, move, attack, defend and death clips plus a persistent dead pose. Missing identities/states fail focused coverage. New units inherit this requirement. Pose changes must articulate the creature/weapon, not merely rotate or resize one standing cutout. Keep original identity, transparent raster provenance, grounded alignment and readable silhouettes. Ranged attacks and retaliation retain appropriate routing; accessibility can suppress motion without suppressing state information.

Dead sprites remain on the battlefield until battle exit, including save/resume, below living units and without health bars, targeting or live occupancy. Revival removes the corpse presentation. Do not fade casualties out and call that a dead sprite.

Large units have explicitly authored visual scale and true two-adjacent-hex horizontal footprints, not inferred from tier or display names. Facing determines the rear cell. Placement, movement/path preview, melee/reach/retaliation distances, AI, spell targeting, pointer/controller hit testing and collision must use both cells. Dead units free both. Existing saves require explicit backward compatibility; no silent overlapping deployment or unrelated stat tuning.

## Sequence and boundaries

1. Replace pose ownership/playback with a per-unit clip-aware original-raster pipeline, persistent corpses and a visually reviewed infantry/large-unit vertical slice. Existing low-resolution affine sheets are migration fallbacks, not completed new pose coverage.
2. Integrate shared footprint geometry into battle rules/AI/presentation and explicitly classify large bodies from content/art. Validate edges, crowded deployment, traversal, near/far-cell attacks, AI, death/revival and saves before rollout.
3. Generate/review/register the remaining unit-specific pose sheets in manageable faction/neutral batches. Maintain exact pending/accepted identity lists; a manifest row or a few animated samples does not complete this goal.
4. Consolidated roster playback, real battles, small/wide captures, accessibility, deterministic simulation, save/load, repository validation and Linux/Windows package acceptance; inspect final visuals, clean task-owned temporary artifacts, commit/push coherent validated increments.

Targets: `content/unit_animation_manifest.json`, unit art/size metadata, `scenes/battle/BattleBoardView.gd`, shared runtime clip/footprint helpers, `scripts/core/BattleRules.gd`, `scripts/core/BattleAiRules.gd`, relevant ContentService/save boundaries, Python-owned asset packaging and focused regression tests. Use `python3 tests/validate_repo.py`, both official export smokes and packaged battle probes, plus `git diff --check`.

Non-goals: native RMG/overworld footprints, town/UI rework, copied Heroes art, unrelated balance changes, generic procedural replacement sprites, or claiming all units complete from transform-only legacy sheets. Original raster generation follows the imagegen workflow; source masters/provenance stay separate from runtime packaging. No fixed package-size ceiling; preserve Linux/Windows completeness/parity.

## Current evidence

Started from `32e617e0`: 160 unit definitions, 160 animation mappings. Inspected River Guard's 64px/four-frame legacy sheet and its generator: poses are rotations/scales of one cutout with procedural accents. This is not accepted articulated animation coverage.

### Implemented runtime increment

All 160 shipped battle standees were visually inspected against their manifest identities. `unit_battle_size_manifest.json` explicitly covers the entire roster: 37 long beasts/extended engines occupy two horizontal cells. Nine tall upright identities receive larger visual scale while retaining one ground cell; compact flyers and infantry are classified separately. A name or tier does not determine size (Bog Brute is a human fighter; Aurora Ballista is a wheeled engine). Missing/new identities fail repository size coverage.

`BattleFootprint.gd` owns occupied cells, whole-body bounds/collision and minimum body-to-body distance. Battle deployment, reachable destinations, actual/presented paths, melee approaches, pulls, support adjacency and AI distance use this geometry. UI outlines and cell lookup include the rear cell; sprites center over the body. New stack saves persist footprint/scale. Existing battle saves without these fields keep one-cell occupancy to avoid expanding into neighbors mid-battle.

`BattleUnitPose.gd` accepts explicit per-unit clip layouts, loops and reduced-motion static frames. Board corpse ownership derives from saved dead stacks, excludes living hit targets/occupancy and disappears on revival. **Production corpse presentation requires an approved dedicated dead pose. No production unit has one accepted yet.** Runtime ownership/indexing tests use an isolated clip fixture and do not count as art acceptance.

### Art dependency and rejected attempts

Built-in image generation produced two River Guard 4-column/6-row drafts under `/root/.codex/generated_images/01a05d96-1b3a-7930-839c-fd2fe5a9eccc/` (`exec-4faa609b-99cd-4889-8605-dd18e9c63184.png` and `exec-879c505a-78d9-462f-aef2-db3cf7981a9d.png`). Both were visually inspected and rejected: baked checkerboard instead of alpha, weapon crossing cell boundaries and insufficient walking articulation. No draft was registered or copied into shipped content. Reusing the old rotated death frame also looked wrong in a runtime capture and was rejected, not enabled as a corpse fallback.

Accepted new pose identities: **0/160**. Pending identities: exactly every `unit_id` in `content/unit_animation_manifest.json`. The requested optional CLI transparent-image workflow requires owner approval for the fallback/model and a locally configured API key; no CLI generation or API billing has been authorized or performed. Runtime/size progress does not close this dependency or the overall goal.

### Validation scope

Focused driver: `python3 -B tests/battle_unit_body_runtime_regression.py --label <unique> --render --resolution 1280x720`. It checks all size profiles, both side orientations/board edges, crowded deployment, movement paths, near-body melee/AI distance, a real large-enemy AI turn, hookline pull, invalid relocation, saved/legacy state and coordinate forms, pose indexing/reduced motion, corpse ownership/save/revival and rejection of all 160 unapproved legacy corpses. Packaged mode reuses the same assertions through the release bootstrap and hashes compiled owners. Source `enemy-body-final` and Linux `linux-complete-runtime` passed 951 assertions; Windows `windows-complete-runtime` passed 950 (headless skips the capture-size assertion). This is runtime coverage, not roster-animation completion.

Evidence root: `.artifacts/battle-unit-animation-size-20260913/`. Source `enemy-body-final/large-body.png` at 1280x720 and packaged `linux-complete-runtime/large-body.png` at 1920x1080 were visually inspected: the larger body is centered over its two outlined cells. Initial fast packaged probes failed shutdown error checks despite passing assertions: verbose Windows output identified still-playing battle-entry audio. Test teardown now explicitly stops music/stingers and lets the mixer release playbacks; error scanning remains enabled and both final probes pass without errors. This is not a general game-audio shutdown fix.

Official `final-linux/report.json` and `final-windows/report.json` exports pass, including Windows generated-map/Town/build gameplay and managed Wine cleanup. `package-parity.json` passes: 516,867,256 bytes and 8,526 members per platform; only `project.binary` differs. Windows is headless Wine coverage, not Windows GPU certification. The first refreshed launch failed because its systemd environment lacked the user template path; normal-shell re-exports passed. The stray editor settings produced by that launch were removed and are absent from the final packages.

Existing battle readability (39 headless assertions) and combat VFX (1,081 headless assertions) pass at their `full-body-roster-final` evidence labels. Repository acceptance is recorded in `accepted-repository-validation.log`; the initial source check for a single-cell active outline was updated to the whole-body outline without weakening draw-order assertions. Superseded initial export binaries (about 1.16 GiB) and the task-created stray editor-settings directory were removed. Final packages, visual/rejection evidence, Wine user data, caches, original generated drafts and pre-existing unrelated untracked files remain.
