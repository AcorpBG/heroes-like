# Distinct Battle Spell Effects

Owner-directed Phase 6 child: `vfx-spell-effect-variety-20260917`.

## Scope and acceptance

Before this slice, the 97 battle spells had 53 exact artwork mappings and 44 shared
Command Ward routes. Replace the latter with explicit authored mappings to 21
original painted school/effect families: Beacon (advance, signal, protection),
Mire (drums, frenzy, snares), Lens (facets, focus, harmonics), Root (growth,
briars), Furnace (heat, armor, bellows, clamps), Veil (undertow, fog binding,
shrouds, false strikes), and Old Measure (axioms, boundaries).

Related spells may share a semantically accurate family painting; this is not
a claim of 44 individually drawn animations. All 97 spell IDs must resolve
explicitly; none of the 44 may select Command Ward during normal playback.
Existing 53 identities remain unchanged. Artwork must read through silhouette
and motion, not only recoloring. Spell-specific tier/variation metadata may
adjust bounded presentation but cannot change gameplay.

Add clearly different motion for strengthening, haste, protection and binding.
Effects must stay attached to the real target, respect reduced motion/flashes,
Normal/Fast/Instant, rendering budgets, unit/readout visibility and current
event timing. No new waits, simulation RNG, persistent state or save changes.
Use the built-in image-generation workflow, preserve originals, prompts and
hashes, and mechanically derive transparent runtime PNGs. No procedural art
substitutes or copyrighted game pixels. Finish the batch before consolidated
tests; inspect generated paintings and actual combat frames.

## Targets and validation

- `content/battle_vfx_manifest.json`, `art/battle/source/generated/spell_variety/`,
  `art/battle/vfx/`, and reproducible Python asset preparation tooling.
- `scripts/ui/CombatVfxMotion.gd`, `scenes/battle/BattleBoardView.gd` only as
  needed for data-driven motion; no spell or combat rules changes.
- Focused Python-owned runtime coverage for all 97 resolutions, all 44 actual
  casts, imported art, target identity, deterministic presentation, quiet and
  Instant behavior, save invariance and 1280x720/1920x1080 inspected frames.
- `python3 -B tests/spell_effect_variety_regression.py --label source --render`
- `python3 -B tests/combat_vfx_regression.py --label spell-variety --render`
- `python3 -B tools/prepare_spell_variety_assets.py --check`
- `python3 -B tests/test_spell_variety_assets.py`
- Existing battle readability, spell behavior and targeting regressions.
- `python3 -B tests/validate_repo.py`; `git diff --check`.
- `python3 -B tests/packaging_linux_export_smoke.py` and
  `python3 -B tests/packaging_windows_export_smoke.py`, isolated focused package
  probes on both platforms and payload parity. Report measured sizes.

Completion requires implemented live effects, accepted artwork, passing
consolidated validation, truthful results here and in PLAN/progress, cleanup
of task-owned disposable non-RMG outputs, a coherent commit and origin/main
push verification. Preserve original/generated art/provenance, caches, saves,
RMG recovery and unrelated pre-existing files.

Non-goals: spell balance, casting rules, new spell content, audio replacement,
unit animation art, spellbook redesign, Town/Overworld/native RMG, save schema,
or a release-readiness claim.

## Implemented result — 2026-09-17

All 97 battle spells now resolve to explicit owned cues. The 44 formerly shared
spells use 21 new original transparent paintings, grouped by school and effect;
the existing 53 spell paintings and their cue metadata are unchanged. The full
VFX library contains 112 cues backed by 89 distinct textures (including the
retained compatibility Command Ward asset). No current battle spell selects
that compatibility fallback. Future missing or mismatched mappings fail both
the asset checker and repository validation.

Seven bounded motion profiles replace the universal rotating ward treatment:
rising strength, directional haste trails, assembling protection, growing
bindings, compressing clamps, inward-curling mist and stamped boundaries.
New families suppress the redundant generic casting/status halos. Their
painted silhouettes remain target-anchored, use at most three raster layers,
and never introduce another gameplay delay or simulation state. Reduced motion
uses one stationary fading painting; reduced flashes attenuate opacity.

`briefs.json`, `origins.json`, `revision.json`, original PNGs and the source
`manifest.json` retain the built-in generation prompts, provenance, approved
clamp correction and hashes. `tools/prepare_spell_variety_assets.py` performs
only transparent-bound cropping, proportional resizing and padding to 384x384;
`--check` reproduces the runtime PNGs byte for byte. This is original generated
raster artwork, not geometry or recolored generic wards. New runtime PNGs total
2,070,509 bytes; high-resolution sources are excluded from both exports.

## Consolidated validation

Generation of the complete batch preceded the consolidated test round.

- Source rendered 1280x720: **3,960 checks passed**, all 97 mappings, all 44
  actual casts, 21 families, seven profiles, no shared-ward runtime cue.
- Immutable Linux package rendered 1920x1080: **3,960 checks passed**, the same
  probe and compiled runtime owners, with the exported package unchanged.
- Immutable Windows package under headless Wine, Fast policy: **3,897 checks
  passed**. The 63 rendering-only capture checks are correctly skipped, not
  counted as passed. All mapping, cast, targeting, accessibility, Instant,
  determinism and gameplay/save equality assertions remain enabled.
- Existing layered-combat VFX regression: **1,831 checks passed**; existing
  frame budget remains 64 layers. Existing battle readability: **64 checks
  each** for rendered Normal and Fast/reduced-motion. Targeting: **87 passed**.
  Existing shared spellbook: **4,627 passed**, save version 9 unchanged.
- Eight asset/provenance tests passed, including missing mappings, shared-ward
  substitution, wrong schools/motion, duplicate paintings, wrong runtime bytes
  and tampered provenance. Read-only asset reproduction passed.
- Existing magic schema and battle-spell behavior reports passed.
- `python3 -B tests/validate_repo.py`: **VALIDATION PASSED**, exit 0. Its notice
  explicitly excludes 26 absent historical disposable smoke reports; those
  smokes were not rerun or counted as passing. `git diff --check` passed.
- Both official export/boot smokes passed, including all **23 Windows generated
  Overworld/Town steps**. PCKs are **648,421,008 bytes each**: 8,905 entries,
  8,904 byte-identical across platforms, only `project.binary` differs. All 21
  new imported textures are present; source art is absent. Linux executable
  71,071,768 bytes; Windows executable 104,540,160 bytes. Compared with the
  prior spellbook package, this adds 1,774,584 PCK bytes and 42 entries.

Visual review inspected every source painting, all 21 real-cast families at
1280x720, full 1920x1080 battle captures, and 20/50/80-percent motion phases
across all seven profiles. Units, health/count captions and controls remain
readable; clamps are fully contained and effects stay on their targets.
Windows validation is headless Wine coverage, not physical Windows GPU proof.

The first probe attempts exposed harness issues, not accepted results: display
settings reapplied 1920x1080 during small captures, and a replaced fixture left
the shell pointing at the initial session. Tests now persist the requested
resolution and attach the correct normalized session before cloning the direct
casting comparison. No battle rules were changed to satisfy these assertions.

### Explicit legacy-report exception

`battle_event_animation_state_report.gd` is **not green**. Its 32-case headless
run has 122 stale timing/audio/idle-art assertion failures. An isolated snapshot
of the pre-slice `60035b51` Board, motion owner, manifest and report reproduces
the same 122 failure labels. The three new artwork-count mismatches were fixed
(112 cues / 89 textures), and the rerun adds **zero new failure labels**.
Its old explicit/shared spell expectations now reflect 97/0. The report's
broader timing, retired sound-ID and resting-standee assumptions are not repaired
or counted as passes in this visual slice. The current Python-owned focused,
readability and package probes above are passing. This is not a release-ready
claim.

Temporary captures, logs, probes and test exports are disposable under the
owner's no-non-RMG-artifact-retention policy. Reproduction commands and source
provenance remain tracked; cleanup preserves caches, originals, saves, Wine
user-data directories, native RMG recovery material and unrelated files.

Cleanup removed 43 verified task-owned targets: 1,946,244,885 logical bytes,
with filesystem free space increasing by 1,947,033,600 bytes. All three Wine
prefixes were lifecycle-cleaned; their user-data directories remain. Existing
older `/tmp` profiles and the three unrelated untracked paths were left alone.
