"""Rebuild Luna's Amberhook candidate from immutable source paintings.

The shared six-action handoff remains the source of all selected artwork and
crop geometry. This script validates its hashes/crop lineage, then writes an
independent handoff that explicitly omits movement pending a reciprocal gait.
"""

from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
UNIT_ID = "unit_thornwake_seedcutters_veteran"
LOCAL_GENERATION = HERE / "generation.json"


def find_root(start: Path) -> Path:
    for candidate in (start, *start.parents):
        if (candidate / "project.md").is_file() and (candidate / "art").is_dir():
            return candidate
    raise RuntimeError(f"Could not locate repository root above {start}")


ROOT = find_root(HERE)
SHARED = ROOT / "art/units/source/generated/fluid_animation/batch_b" / UNIT_ID
SHARED_HANDOFF = SHARED / "handoff.json"
SHARED_GENERATION = SHARED / "generation.json"
SHARED_IDENTITY_META = SHARED / "identity_reference.json"
sys.path.insert(0, str(ROOT / "tools"))
from refine_fluid_frame_crops import body_rectangles


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if ROOT.resolve() not in path.parents and path != ROOT.resolve():
        raise ValueError(f"Path escapes repository: {relative}")
    return path


def validate_identity_crop() -> dict:
    meta = json.loads(SHARED_IDENTITY_META.read_text(encoding="utf-8"))
    source = repo_path(meta["source"])
    reference = SHARED / meta["output"]
    assert sha(source) == meta["source_sha256"], "Original identity source hash changed"
    assert sha(reference) == meta["output_sha256"], "Identity crop hash changed"
    with Image.open(source) as original, Image.open(reference) as saved:
        crop = original.crop(tuple(meta["crop"])).convert("RGBA")
        saved_rgba = saved.convert("RGBA")
        assert crop.size == saved_rgba.size, "Identity crop dimensions differ"
        assert crop.tobytes() == saved_rgba.tobytes(), "Identity crop is not original-pixel exact"
        pixel_sha = hashlib.sha256(crop.tobytes()).hexdigest()
        assert pixel_sha == meta["crop_pixel_sha256"], "Identity pixel hash mismatch"
    return meta


def validate_shared_lineage(unit: dict) -> dict:
    generation = json.loads(SHARED_GENERATION.read_text(encoding="utf-8"))
    entries = {entry["image"]: entry for entry in generation["generations"]}
    used = sorted({frame["source"] for frame in unit["frames"]})
    for image_rel in used:
        image_path = repo_path(image_rel)
        entry = entries.get(image_rel)
        assert entry is not None, f"No source generation lineage for {image_rel}"
        prompt_path = repo_path(entry["prompt"])
        assert sha(image_path) == entry["image_sha256"], f"Source image hash changed: {image_rel}"
        assert sha(prompt_path) == entry["prompt_sha256"], f"Source prompt hash changed: {entry['prompt']}"
        with Image.open(image_path) as image:
            alpha = image.convert("RGBA").getchannel("A")
            extrema = alpha.getextrema()
            assert extrema[0] <= 16, f"Unexpected alpha minimum in {image_rel}: {extrema}"
        for reference in entry["references"]:
            reference_path = repo_path(reference["path"])
            assert sha(reference_path) == reference["sha256"], f"Reference hash changed: {reference['path']}"
    return {"shared_generation": generation, "used_sources": used}


def validate_new_generation() -> dict:
    generation = json.loads(LOCAL_GENERATION.read_text(encoding="utf-8"))
    entries = generation.get("generations", [])
    assert len(entries) == 6, "Expected six recorded new image calls"
    for entry in entries:
        image = repo_path(entry["image"])
        prompt = repo_path(entry["prompt"])
        assert sha(image) == entry["image_sha256"], f"New master hash mismatch: {entry['image']}"
        assert sha(prompt) == entry["prompt_sha256"], f"Prompt hash mismatch: {entry['prompt']}"
        with Image.open(image) as opened:
            assert opened.convert("RGBA").getchannel("A").getextrema()[0] <= 16
        for reference in entry["references"]:
            reference_path = repo_path(reference["path"])
            assert sha(reference_path) == reference["sha256"], f"New-call reference hash mismatch: {reference['path']}"
            metadata_path = reference_path.with_suffix(".json")
            if metadata_path.is_file():
                meta = json.loads(metadata_path.read_text(encoding="utf-8"))
                if all(key in meta for key in ("source", "source_sha256", "crop", "output_sha256")):
                    original = repo_path(meta["source"])
                    assert sha(original) == meta["source_sha256"], f"Reference source hash mismatch: {meta['source']}"
                    assert sha(reference_path) == meta["output_sha256"], f"Reference crop hash mismatch: {reference['path']}"
                    with Image.open(original) as source_image, Image.open(reference_path) as saved_image:
                        crop = source_image.crop(tuple(meta["crop"])).convert("RGBA")
                        saved = saved_image.convert("RGBA")
                        assert crop.size == saved.size and crop.tobytes() == saved.tobytes(), f"Reference is not original-pixel exact: {reference['path']}"
                    if "crop_pixel_sha256" in meta:
                        assert hashlib.sha256(crop.tobytes()).hexdigest() == meta["crop_pixel_sha256"]
    return generation


def validate_frame_geometry(unit: dict) -> None:
    scale_by_source: dict[str, set[float]] = {}
    for frame in unit["frames"]:
        source = repo_path(frame["source"])
        scale_by_source.setdefault(frame["source"], set()).add(float(frame["scale"]))
        cutoff = int(frame["alpha_noise_cutoff"])
        assert 0 <= cutoff <= 16, f"Invalid alpha cutoff {cutoff}: {frame['name']}"
        with Image.open(source) as image:
            width, height = image.size
        rects = frame["rects"]
        assert rects, f"No crop regions: {frame['name']}"
        for x0, y0, x1, y1 in rects:
            assert 0 <= x0 < x1 <= width and 0 <= y0 < y1 <= height, f"Out-of-bounds crop: {frame['name']}"
    for source, scales in scale_by_source.items():
        assert len(scales) == 1, f"More than one anatomical scale used for {source}: {scales}"


def main() -> None:
    assert LOCAL_GENERATION.is_file(), "Image generation lineage is missing"
    local_lineage = validate_new_generation()
    source_handoff = json.loads(SHARED_HANDOFF.read_text(encoding="utf-8"))
    shared_unit = next(row for row in source_handoff["units"] if row["unit_id"] == UNIT_ID)
    assert len(shared_unit["frames"]) == 40
    identity = validate_identity_crop()
    lineage = validate_shared_lineage(shared_unit)
    validate_frame_geometry(shared_unit)

    unit = copy.deepcopy(shared_unit)
    unit["unit_id"] = UNIT_ID
    # Reorder the selected original idle paintings so the broad low guard
    # transitions through both raised-hook poses before settling to neutral.
    unit["frames"][3], unit["frames"][4] = unit["frames"][4], unit["frames"][3]
    unit["frames"][3]["name"] = "idle_3"
    unit["frames"][4]["name"] = "idle_4"

    # Support recovery eases through another pose from its own generated
    # sheet, instead of jumping to an unrelated idle grip.
    cast_path = "art/units/source/generated/fluid_animation/batch_b/unit_thornwake_seedcutters_veteran/cast_v1.png"
    cast_source = repo_path(cast_path)
    recovery_seed = [285, 1340]
    recovery_rects = [list(rect) for rect in body_rectangles(cast_source, tuple(recovery_seed), 8)]
    recovery_bounds = [min(r[0] for r in recovery_rects), min(r[1] for r in recovery_rects),
                       max(r[2] for r in recovery_rects), max(r[3] for r in recovery_rects)]
    unit["frames"][30].update({
        "name": "cast_6", "clip": "cast", "source": cast_path, "rects": recovery_rects,
        "anchor": [285, recovery_bounds[3]], "scale": 0.615, "alpha_noise_cutoff": 8,
        "crop_recipe": {"tool": "tools/refine_fluid_frame_crops.py", "seed": recovery_seed,
                        "additional_seeds": [], "cutoff": 8},
    })

    # Keep a dropped hook visible in the middle death frame; the old nearby
    # seed landed on the body component rather than this separate blade.
    death_path = "art/units/source/generated/fluid_animation/batch_b/unit_thornwake_seedcutters_veteran/death_v1.png"
    death_source = repo_path(death_path)
    dropped_blade_seed = (900, 1210)
    death_blade_rects = body_rectangles(death_source, dropped_blade_seed, 8)
    death_frame = unit["frames"][37]
    death_frame["rects"] = [list(rect) for rect in sorted(set(tuple(rect) for rect in death_frame["rects"] + [list(r) for r in death_blade_rects]))]
    death_frame["crop_recipe"]["additional_seeds"] = [list(dropped_blade_seed)]

    correction_path = "art/units/source/generated/fluid_animation/batch_b/unit_thornwake_seedcutters_veteran/death_middle_correction_v1.png"
    unit["source_scale_by_image"][correction_path] = 0.310
    for frame in unit["frames"]:
        if frame["source"] == correction_path:
            frame["scale"] = 0.310
    unit["source_scale_reason"] = (
        "One fixed anatomical scale per source sheet: approximately 232px original standing silhouette in the 256px "
        "reference. The corrected death-middle sheet uses one global 0.310 scale to match head/torso mass; crouch and "
        "fall poses retain their different source heights and are never normalized per pose."
    )
    unit["accepted_clips"] = []
    unit["visual_review"] = {
        "status": "pending_parent_review",
        "notes": (
            "Luna submission: six independently prepared actions (idle, attack, hit, defend, cast, death) are "
            "sampled in the native Godot 128px battle and 64px map phase renders under the assigned temporary directory. The source "
            "paintings are reused directly from the immutable shared starter with its crop selectors and exact "
            "generation lineage; preparation verifies the identity crop pixels, all used source/prompt/reference "
            "hashes, fixed per-sheet scales, frame bounds and alpha cutoffs. Movement is deliberately omitted: "
            "six new calls yielded one visually qualifying near-thigh crossover pose, but not reciprocal contact, "
            "loading and passing phases. This is not a complete seven-action unit and awaits parent scoring. "
            "Native sampled phase images and timing/state assertions are evidence only; continuous playback and "
            "a manual game playtest were not observed. Idle's two near-neutral holds and broad arms-out flourish "
            "are recorded as a temporal-quality caveat. A valid original idle painting supplies cast recovery."
        ),
        "sampled_native_actions": [
            {"clip": "idle", "frames": 8, "sample_times_ms": [0, 155, 310, 465, 620, 775, 930, 1085], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-idle.png", "observation": "Distinct ready/weapon gestures with a broad arms-out flourish and two close neutral holds near loop closure."},
            {"clip": "attack", "frames": 8, "sample_times_ms": [0, 120, 240, 360, 480, 600, 720, 840], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-attack.png", "observation": "Windup, rising dual-sickle action, contact/follow-through and recovery; corrected windup retains two grips."},
            {"clip": "hit", "frames": 4, "sample_times_ms": [0, 115, 230, 345], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-hit.png", "observation": "Ordered recoil beats return to a grounded ready posture."},
            {"clip": "defend", "frames": 4, "sample_times_ms": [0, 130, 260, 390], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-defend.png", "observation": "Four guarded poses finish on a held crossed-sickle brace."},
            {"clip": "cast", "frames": 8, "sample_times_ms": [0, 130, 260, 390, 520, 650, 780, 910], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-cast.png", "observation": "Physical raised and spread dual-sickle gesture; valid original idle painting supplies recovery; no magic or ranged effect is added."},
            {"clip": "death", "frames": 8, "sample_times_ms": [0, 150, 300, 450, 600, 750, 900, 1050], "file": ".artifacts/amberhook_model_comparison/luna/phases/unit_thornwake_seedcutters_veteran-death.png", "observation": "Progressive kneel and grounded collapse with sickles released separately; final painting is the dead hold."},
        ],
        "ready_for_parent_scoring": ["idle", "attack", "hit", "defend", "cast", "death"],
        "pending_actions": {
            "move": "Omitted. One near-thigh crossover pose qualifies, but opposite-side contact, loading and passing phases are missing; no reciprocal clip is authored.",
        },
        "seven_action_unit_complete": False,
        "movement_qualification": {
            "status": "omitted_pending_reciprocal_gait",
            "only_qualifying_pose": "art/units/source/generated/fluid_animation/comparison_20260924/luna/move_pose_first_v1.png",
            "blocked_phases": ["opposite-side contact", "loading", "passing"],
            "reason": "The four-pose follow-up contains one clear foreground near-thigh crossover; remaining cells and two contact edits return to tabard-front or far-leg-leading topology.",
        },
        "continuous_playback_observed": False,
        "manual_playtest_observed": False,
    }
    unit["provenance"] = {
        **unit["provenance"],
        "shared_source_handoff": SHARED_HANDOFF.as_posix(),
        "shared_source_generation_lineage": SHARED_GENERATION.as_posix(),
        "new_generation_lineage": "art/units/source/generated/fluid_animation/comparison_20260924/luna/generation.json",
    }
    # Keep the six actionable source clips verbatim, and make the movement gap
    # explicit in the handoff rather than presenting a one-sided walk as ready.
    unit["clips"].pop("move", None)
    handoff = {"schema_version": 1, "units": [unit]}
    output = HERE / "handoff.json"
    output.write_text(json.dumps(handoff, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Prepared {UNIT_ID}: {len(unit['frames'])} frames, clips={','.join(unit['clips'])}")
    print(f"Verified identity crop, {len(lineage['used_sources'])} shared sheets, and {len(local_lineage['generations'])} new call lineages")
    print(f"Wrote {output.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
