# Amberhook Reapers: Astra comparison candidate

Stable unit: `unit_thornwake_seedcutters_veteran` (not `astra`). Model: GPT-6 Astra, high reasoning.

Source paintings and exact prompts remain in this directory. The inherited source paintings stay in `batch_b/unit_thornwake_seedcutters_veteran`; their handoff crop recipes and generation lineage are referenced, never rewritten. `generation.json` records every new original master, its exact prompt/reference hashes and original tool output. The unselected high-knee key is retained as the generation reference that established foreground-thigh overlap.

The identity is an adult elf with flowered brown bun, cream scarf, green quilted tunic, bark/leaf armor, wicker pod-and-orange basket and two independently gripped amber sickles. The near leg originates below the image-left pouch; its advancing thigh crosses over the tabard. Camera is right-facing three-quarter. The inherited reference height remains 256, with about 232 painted anatomical pixels. All scales are fixed per original sheet.

Final clips: idle 8, reciprocal movement 8, melee attack 8, physical support/cast 8, hit 4, defend 4, death 9. The packer creates persistent dead from the final death painting. Shared attack/reaction sources qualify; new idle/support remove the inherited abrupt hand changes. New middle death preserves release and landing at the right head/torso scale. New motion is painted articulation, not procedural deformation. No individual clip is padded or reversed.

Rebuild from repository root:

```powershell
& C:/Users/acorp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe art/units/source/generated/fluid_animation/comparison_20260924/astra/prepare.py
& C:/Users/acorp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tests/fluid_creature_animation_regression.py --godot D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe --handoff art/units/source/generated/fluid_animation/comparison_20260924/astra/handoff.json --contacts-only --render --output .artifacts/amberhook_model_comparison/astra/submission
```

Python/Pillow recipe and all repository-relative paths are portable; the invocation above records the actual Windows executables. No runtime catalogs, shared source, progress, Git state or user game session were modified. Parent owns integration and acceptance.

Validation: final Windows Godot 4.6.2 candidate passes 117 focused assertions. Original anatomy and ordered native 128px/64px phase renders inspected. The final `submission/*-overview.png` shows all nine death frames (individual contact strips have a fixed eight-frame-wide canvas). Existing root certificate-store and GLES MSAA warnings were emitted; zero assertion failures. Continuous playback and manual game playtest were not observed, and Linux was not run. Usage/token/credit consumption is unavailable.

First complete candidate: 2026-09-24 06:37:31 UTC, 14m43s from recorded start. Five new image calls; twelve inherited shared calls. No parent review rounds yet. Previews are retained for the explicitly requested comparison review; no final publication or parent acceptance is claimed.

## Parent review round 1

First submission was rejected for ambiguous repeated leg contacts and a missed detached blade in death index6. Revision finished 2026-09-24 06:49:51 UTC (9m19s after review start), with four additional calls, nine total. `move_cycle_v1` and `far_half_v2` are retained rejected drafts. New movement uses `near_half_v2` cells0-3 then `far_half_v3` cells0-3. Near contact is native index2: thigh originates below image-left pouch and crosses visibly OVER the rear thigh, displacing the tabard back. Far contact is native index6: advance originates at image-right hip beneath the central tabard, while the foreground thigh trails image-left. Both halves contain separate passing, reach, contact and load paintings. Scales .33/.37 match head/torso size across the two original resolutions. Blank-gutter crop bounds separate faint alpha bridges; no body or blade painting was changed.

Death index6 now explicitly selects both source ground blades at y1205/y1210. The inherited y1120 seed had selected body pixels again. Final revision native move/death contacts were inspected; 117 checks pass. Revision preview directory: `.artifacts/amberhook_model_comparison/astra/revision1/`. First-submission previews remain frozen. Parent acceptance remains pending.
