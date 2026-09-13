# Layered Combat Visual Effects

Owner-directed Phase 6 slice: `vfx-combat-layered-feedback-20260913`.

## Required behavior

- Make combat attacks visibly richer: directional melee sweeps, travelling projectile trails, expanding hit bursts, layered casting/target spell feedback and short status/defeat dissipations.
- Reuse existing original raster art through `content/battle_vfx_manifest.json`; preserve spell identity. No new art generation, procedural replacement sprites, full-screen flashes or extra battle delays.
- Compose combat effects over unit artwork where needed, with health/count/status/captions above the effects. Retain ground markers, depth-sorted units, hit geometry and controller navigation.
- Respect reduced motion/flashes and Normal/Fast/Instant playback. Use bounded presentation-only layer counts, cached textures and no gameplay RNG or save-state writes.

## Implementation and validation

Targets: `scenes/battle/BattleBoardView.gd`, `scripts/ui/CombatVfxMotion.gd`, Python-owned `tests/combat_vfx_regression.py` and directly affected composition checks in `tests/validate_repo.py`.

Capture a before/after real battle and inspect motion phases at 1280x720 and 1920x1080. Exercise melee, ranged, spells, impacts and accessibility; compare complete authoritative session state across presentation. Run existing battle readability/VFX coverage, full repository validation, Linux/Windows official exports and same-probe packaged acceptance/parity. Clean task-owned obsolete captures/profiles, preserve caches and unrelated files, commit/push validated changes and verify origin/main.

Non-goals: battle balance, AI, damage/RNG rules, save schema, unit artwork replacement, audio, hero/town/Overworld UI or native RMG changes.

## Evidence

Completed 2026-09-13 after source and Linux/Windows package acceptance.

`CombatVfxMotion.layers` is a pure phase-to-raster-stamp function. Projectile heads have three trailing copies; melee arcs sweep with two afterimages; impacts expand with four localized painted fragments; spell-specific bursts have a counter-rotating echo and three motes; wards counter-rotate and defeat art rises/dissipates. Existing manifests, textures, event routing and durations remain authoritative. No image assets, gameplay rules or persistent state changed.

`BattleBoardView` now draws depth-sorted bodies, foreground combat art, then side/status/health/count/caption readouts. Ground markers retain their earlier pass. Hit shapes retain the same visual centers/radii. The new pass is capped at six stamps per cue and 64 per frame, using the existing texture cache. Reduced motion retains the catalog's quiet fallback policy and any remaining foreground stamp is stationary; reduced flashes attenuates opacity. Existing Instant playback clears effects without an added wait.

Evidence root: `.artifacts/combat-vfx-20260913/`.

- Source 1280x720 and Linux release 1920x1080: 1,095 checks each passed (`source-acceptance-small/report.json`, `linux-packaged/report.json`). Real melee, retaliation, ranged, Cinder Burst, Stone Veil, damage and status cues resolved imported art. Complete session dictionaries match ordinary action resolution; presentation sampling leaves committed state unchanged. Phase captures at 20/50/80 percent and reduced motion were visually inspected at both sizes.
- Windows release: 1,081 checks passed (`windows-packaged/report.json`); same SHA-locked probe and all nonvisual assertions, with 14 screenshot-size checks naturally absent in headless mode. Both official export smokes pass (`linux/report.json`, `windows/report.json`), including Windows generated-map/Town/build entry. Compiled-owner/immutable-export proofs accompany the focused packaged reports.
- Full repository validation passed (`repository-validation.log`), as did `git diff --check`. Package parity passed (`package-parity.json`): 516,838,556 bytes / 8,521 members per platform; only `project.binary` differs. No raster payloads changed; the pack grew by 4,692 bytes from the previous release.
- Pure coverage exercises all manifest-backed motion profiles, deterministic repeatability, endpoint expiry, quiet/static geometry and opacity. Ten thousand projectile cue calculations took about 49–52 ms on this host (not a GPU or full-battle benchmark). Actual sequences used at most seven layers; a crowded-cue control reached exactly the 64-layer cap.
- Existing battle readability: 64 checks passed for Normal and Fast/reduced-motion, including complete action playback, captions, input lock, state invariance and Instant. Before/after evidence: `.artifacts/battle_readability_20260910/combat-vfx-before/`, `combat-vfx-first/`, `combat-vfx-fast-reduced/`.
- Legacy combined event/VFX/audio report: 32 cases executed with **11 pre-existing audio assertions failing**, and no new failure assertions. The same report against the pre-change Board from `86fe362666d1774eb76fdc6bd8eb0588bca7eb51` yields the same 11 failures. They expect retired placeholder/Cinder Burst/ranged-release sound IDs or old audio identity counts, whereas current `AudioPalette` routes production WAVs. Full reports are in `existing-vfx-detail/` and `existing-vfx-baseline-detail/`; comparison is `legacy-report-comparison.json`. This report is not claimed green; audio migration/test reconciliation is outside this VFX slice.

Reproduction (use fresh labels and Wine prefix):

```sh
python3 -B tests/combat_vfx_regression.py --label review-source --render --resolution 1280x720
python3 -B tests/combat_vfx_regression.py --platform linux --binary .artifacts/combat-vfx-20260913/linux/export/heroes-like.x86_64 --pack .artifacts/combat-vfx-20260913/linux/export/heroes-like.pck --label review-linux --render --resolution 1920x1080
python3 -B tests/combat_vfx_regression.py --platform windows --binary .artifacts/combat-vfx-20260913/windows/export/heroes-like.exe --pack .artifacts/combat-vfx-20260913/windows/export/heroes-like.pck --wine-prefix /root/dev/heroes-like/.artifacts/combat-vfx-20260913/review-wine-prefix --label review-windows
python3 tests/validate_repo.py
git diff --check
```

Windows acceptance uses headless Wine, not physical Windows GPU certification. This is a bounded combat-effects improvement, not a new unit-animation art set or whole-game release-readiness claim.

Cleanup removed the superseded `source-first` captures and temporary pre-change Board copy after checking for open files: 10,474,554 apparent bytes, all rebuildable. The baseline is recoverable from the recorded Git commit; comparison/full failure reports remain. Final captures/packages, source art, caches, Wine user data and unrelated pre-existing files are preserved. Python runners remove their temporary probe/user directories; Windows runners retain cleanup receipts.
