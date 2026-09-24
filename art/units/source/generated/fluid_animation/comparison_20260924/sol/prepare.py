"""Prepare the Sol Amberhook candidate from original source pixels.

Shared originals remain read-only. New trial masters, including rejects, have
independent lineage in this directory. A failed gait must stay excluded.
"""

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "project.md").is_file())
SHARED = ROOT / "art/units/source/generated/fluid_animation/batch_b/unit_thornwake_seedcutters_veteran"
sys.path.insert(0, str(ROOT / "tools"))
from refine_fluid_frame_crops import body_rectangles


def rel(path):
    return path.resolve().relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


TOOL_DIR = "C:/Users/acorp/.codex/generated_images/01a0d214-36df-73a1-859a-2362814f17f1"
CALLS = [
    ("move_near_v1", "exec-ed234148-000e-4b13-b2ee-3c321e27939c.png", [SHARED / "identity_reference.png", SHARED / "move_v1.png"]),
    ("move_near_v2", "exec-96f683c5-7c9b-42a1-9638-f317403684a0.png", [SHARED / "identity_reference.png", HERE / "near_leg_geometry_reference.png"]),
    ("move_near_v3", "exec-b34a104a-3e85-4c83-990b-1f156e1406bb.png", [HERE / "move_near_v2.png", SHARED / "identity_reference.png", HERE / "near_leg_geometry_reference.png"]),
    ("move_near_v4", "exec-266711cd-3f0d-4237-bc1b-f33b725b03c4.png", [HERE / "identity_upper_reference.png", HERE / "near_leg_geometry_reference.png"]),
    ("move_near_v5", "exec-84dd1f3f-5c1c-4d83-b58a-9650736b19e9.png", [HERE / "identity_upper_reference.png", HERE / "lensbearer_near_leg_pose_reference.png"]),
    ("move_near_v6", "exec-b5c0458c-8d22-4142-9a3d-3cb559d7227b.png", [SHARED / "identity_reference.png", HERE / "move_near_v5.png"]),
    ("move_near_v7", "exec-6e78586c-253e-4039-a04a-a5df6ae68c80.png", [HERE / "move_near_v5.png"]),
    ("move_near_v8", "exec-eb7619af-baf0-4a1b-80d7-44d9599e2340.png", [HERE / "move_near_v7.png", SHARED / "identity_reference.png"]),
    ("move_near_v9", "exec-998a0a0c-2801-48db-997e-6ac87408ae01.png", [HERE / "move_near_v8.png", HERE / "move_near_v8_occlusion_guide.png"]),
    ("move_near_v10", "exec-7851fefb-9d85-408c-8c9f-bfe5bb8c1f1b.png", [HERE / "move_near_v9_overpaint_guide.png", HERE / "move_near_v9.png"]),
]

lineage = []
for stem, tool_file, refs in CALLS:
    image = HERE / f"{stem}.png"
    prompt = HERE / f"{stem}.prompt.txt"
    assert image.is_file() and prompt.is_file(), stem
    lineage.append(dict(
        image=rel(image), image_sha256=sha(image),
        prompt=rel(prompt), prompt_sha256=sha(prompt),
        tool="builtin_image_gen", tool_output_path=f"{TOOL_DIR}/{tool_file}",
        references=[dict(path=rel(r), sha256=sha(r)) for r in refs],
        selected_for_candidate=stem == "move_near_v9",
    ))
(HERE / "generation.json").write_text(json.dumps(dict(schema_version=1, generations=lineage), indent=2) + "\n", encoding="utf-8")

reference = SHARED / "identity_reference.png"
reference_meta = json.loads((SHARED / "identity_reference.json").read_text(encoding="utf-8"))
assert sha(ROOT / reference_meta["source"]) == reference_meta["source_sha256"]
assert sha(reference) == reference_meta["output_sha256"]
with Image.open(ROOT / reference_meta["source"]) as original, Image.open(reference) as saved:
    assert original.crop(tuple(reference_meta["crop"])).convert("RGBA").tobytes() == saved.convert("RGBA").tobytes()

upper = HERE / "identity_upper_reference.png"
with Image.open(reference) as original, Image.open(upper) as saved:
    assert original.crop((0, 0, 627, int(627 * .57))).convert("RGBA").tobytes() == saved.convert("RGBA").tobytes()
lens_original = ROOT / "art/units/source/generated/fluid_animation/batch_b/unit_sunvault_zenith_lensbearers_veteran/move_near_v1.png"
with Image.open(lens_original) as original, Image.open(HERE / "lensbearer_near_leg_pose_reference.png") as saved:
    assert original.crop((180, 220, 650, 510)).convert("RGBA").tobytes() == saved.convert("RGBA").tobytes()
reference_crops = [
    dict(source=rel(ROOT / reference_meta["source"]), source_sha256=reference_meta["source_sha256"],
         crop=reference_meta["crop"], output=rel(reference), output_sha256=sha(reference)),
    dict(source=rel(reference), source_sha256=sha(reference), crop=[0, 0, 627, int(627 * .57)],
         output=rel(upper), output_sha256=sha(upper)),
    dict(source=rel(lens_original), source_sha256=sha(lens_original), crop=[180, 220, 650, 510],
         output=rel(HERE / "lensbearer_near_leg_pose_reference.png"),
         output_sha256=sha(HERE / "lensbearer_near_leg_pose_reference.png")),
]
(HERE / "reference_crops.json").write_text(json.dumps(reference_crops, indent=2) + "\n", encoding="utf-8")

entry = dict(
    unit_id="unit_thornwake_seedcutters_veteran",
    reference_height=256,
    source_facing="right",
    frames=[], clips={}, source_scale_by_image={},
    source_scale_reason="One fixed anatomical scale per original source sheet: approximately 232px original standing hair-to-sole silhouette in the 256px inherited reference. Lower crouched/fallen bounds never receive per-pose resizing.",
    provenance=dict(tool="builtin_image_gen", original_reference=reference_meta,
                    reference=rel(reference), generation_lineage=rel(HERE / "generation.json"),
                    shared_generation_lineage=rel(SHARED / "generation.json"),
                    reference_crops=rel(HERE / "reference_crops.json")),
    accepted_clips=[],
)

SOURCE_SCALE = {
    "idle_v1": .615,
    "move_v1": .615,
    "move_near_v9": .400,
    "attack_v1": .615,
    "attack_windup_correction_v1": .200,
    "reactions_v1": .615,
    "cast_v1": .615,
    "death_v1": .500,
    "death_middle_correction_v1": .270,
}


def source_path(stem):
    path = HERE / f"{stem}.png"
    return path if path.is_file() else SHARED / f"{stem}.png"


def nearby_seed(path, wanted):
    with Image.open(path) as image:
        alpha = image.getchannel("A")
        x, y = wanted
        if alpha.getpixel((x, y)) > 8:
            return [x, y]
        for radius in range(1, 90):
            for dy in range(-radius, radius + 1):
                for dx in (-radius, radius):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < image.width and 0 <= yy < image.height and alpha.getpixel((xx, yy)) > 8:
                        return [xx, yy]
            for dx in range(-radius + 1, radius):
                for dy in (-radius, radius):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < image.width and 0 <= yy < image.height and alpha.getpixel((xx, yy)) > 8:
                        return [xx, yy]
    raise ValueError(f"No original body pixel near {wanted} in {path}")


def add(clip, stem, number, torso, center_x, extra=(), floor=None):
    source = source_path(stem)
    path = rel(source)
    scale = SOURCE_SCALE[stem]
    entry["source_scale_by_image"][path] = scale
    seed = nearby_seed(source, torso)
    rects = body_rectangles(source, seed, 8)
    additional = []
    for wanted in extra:
        e = nearby_seed(source, wanted)
        additional.append(e)
        rects.extend(body_rectangles(source, e, 8))
    rects = [list(r) for r in sorted(set(tuple(r) for r in rects))]
    bounds = [min(r[0] for r in rects), min(r[1] for r in rects), max(r[2] for r in rects), max(r[3] for r in rects)]
    if floor is None:
        floor = bounds[3]
    index = len(entry["frames"])
    entry["frames"].append(dict(name=f"{clip}_{number}", clip=clip, source=path, rects=rects,
                                anchor=[center_x, floor], scale=scale, alpha_noise_cutoff=8,
                                crop_recipe=dict(tool="tools/refine_fluid_frame_crops.py", seed=seed,
                                                 additional_seeds=additional, cutoff=8)))
    entry["clips"].setdefault(clip, dict(indices=[], loop=clip == "idle"))["indices"].append(index)
    print(clip, number, stem, "source bounds", bounds, "anchor", [center_x, floor])


# Eight distinct illustrated idle paintings. The body and each hook are
# connected to the torso in the selected original-pixel components.
idle_torsos = [(285, 190), (760, 190), (280, 570), (760, 570),
               (285, 955), (760, 955), (285, 1340), (760, 1340)]
idle_source_order = (0, 1, 2, 5, 4, 6, 7)
for i, source_index in enumerate(idle_source_order[:4]):
    xy = idle_torsos[source_index]
    add("idle", "idle_v1", i, xy, 285 if source_index % 2 == 0 else 760)
# A ready low-hook painting bridges the close-held grip to the wide arm shift.
add("idle", "attack_v1", 4, (760, 1340), 760)
for i, source_index in enumerate(idle_source_order[4:], start=5):
    xy = idle_torsos[source_index]
    add("idle", "idle_v1", i, xy, 285 if source_index % 2 == 0 else 760)

# A proposed reciprocal cycle alternates four inherited far-leg phases with
# four new near-leg phases. Native review must confirm anatomy before release.
far_move = ((285, 190), (760, 190), (285, 570), (285, 1340))
for i, xy in enumerate(far_move):
    add("move", "move_v1", i, xy, 285 if xy[0] == 285 else 760)
near_move = ((350, 235), (1030, 235), (350, 800), (1030, 800))
for i, xy in enumerate(near_move, start=4):
    add("move", "move_near_v9", i, xy, 350 if xy[0] == 350 else 1030)

# The source's top-right windup obscured a sickle. A new two-grip painting
# replaces it, preserving the seven valid originals.
attack = [("attack_v1", (285, 190), 285),
          ("attack_windup_correction_v1", (650, 560), 650),
          ("attack_v1", (285, 570), 285), ("attack_v1", (760, 570), 760),
          ("attack_v1", (285, 955), 285), ("attack_v1", (760, 955), 760),
          ("attack_v1", (285, 1340), 285), ("attack_v1", (760, 1340), 760)]
for i, (stem, xy, cx) in enumerate(attack):
    add("attack", stem, i, xy, cx)

# Left reaction column is hit; defense is ordered to end on its strongest
# crossed-hook held guard (source row 2 right).
for i, y in enumerate((190, 570, 955, 1340)):
    add("hit", "reactions_v1", i, (285, y), 285)
for i, source_row in enumerate((0, 3, 2, 1)):
    add("defend", "reactions_v1", i, (760, 190 + source_row * 384), 760)

# Original chest-crossed support recovery joined the two hooks; the original
# attack ready painting lowers both separate grips after the wide-arm peak.
for i in range(8):
    if i == 6:
        add("cast", "attack_v1", i, (760, 1340), 760)
    else:
        row, col = divmod(i, 2)
        add("cast", "cast_v1", i, (285 if col == 0 else 760, 190 + row * 384),
            285 if col == 0 else 760)

# Cast source pose 5 raises both hooks above the previous row's two boots.
# A translucent bridge joins their pixels at cutoff 8..16. Keep reviewed
# original pixels from the full current body below row 780 and both upper
# sickles outside the previous boots' x span; discard only boot intrusions.
cast_overhead = entry["frames"][entry["clips"]["cast"]["indices"][4]]
regions = ((0, 780, 512, 1536), (0, 0, 185, 780), (347, 0, 512, 780))
clipped = []
for x0, y0, x1, y1 in cast_overhead["rects"]:
    for a0, b0, a1, b1 in regions:
        left, top, right, bottom = max(x0, a0), max(y0, b0), min(x1, a1), min(y1, b1)
        if left < right and top < bottom:
            clipped.append([left, top, right, bottom])
cast_overhead["rects"] = clipped
cast_overhead["crop_recipe"]["reviewed_original_pixel_regions"] = [list(r) for r in regions]
cast_overhead["crop_recipe"]["reason"] = "Exclude opaque previous-row boots while retaining both high sickles; inspected source pixel overlap."

# Corrected middle fall retains the released near hook on the ground from the
# release frame onward. Its last pose touches source edge, so exclude it.
death = [("death_v1", (285, 190), 285, ()),
         ("death_v1", (760, 190), 760, ()),
         ("death_middle_correction_v1", (300, 330), 300, ()),
         ("death_middle_correction_v1", (940, 330), 940, ((780, 650),)),
         ("death_middle_correction_v1", (300, 950), 300, ((110, 1200), (500, 1200))),
         ("death_v1", (760, 955), 760, ((620, 1210), (900, 1210))),
         ("death_v1", (300, 1340), 300, ((110, 1475), (385, 1475))),
         ("death_v1", (760, 1340), 760, ((620, 1480), (935, 1480)))]
for i, (stem, xy, cx, extra) in enumerate(death):
    add("death", stem, i, xy, cx, extra)

# Ground contact is anatomical: detached sickles may rest below a planted
# boot, knee or fallen torso, and must not lift the body in the atlas.
death_body_floors = (480, 485, 660, 650, 1195, 1195, 1468, 1467)
for i, body_floor in enumerate(death_body_floors):
    frame = entry["frames"][entry["clips"]["death"]["indices"][i]]
    frame["anchor"][1] = body_floor
    frame["crop_recipe"]["body_contact_floor"] = body_floor

for name, spec in entry["clips"].items():
    spec.update(frame_msec={"idle": 155, "attack": 120, "hit": 115,
                            "defend": 130, "cast": 130, "death": 150, "move": 115}[name],
                static_frame=3 if name == "defend" else 7 if name == "death" else 0)
entry["clips"]["attack"]["contact_frame"] = 4
entry["clips"]["cast"]["contact_frame"] = 4
entry["visual_review"] = dict(
    status="pending",
    notes="Sol bounded revision after parent review: idle substitutes a low-hook ready original for the abrupt raised-hand beat; support recovery lowers both arms through that separate-grip original. Death frame 5 now includes both dropped hooks, but middle-fall scale 0.270 appears undersized and death remains unaccepted. Move is structurally present for reproducible evaluation but visually rejected: advancing near thigh still emerges below central tabard and near-half styling changes. Parent has not accepted the seven-clip set. Native phase snapshots were inspected; continuous playback and manual playtest were not observed.",
)
(HERE / "handoff.json").write_text(json.dumps(dict(schema_version=1, units=[entry]), indent=2) + "\n", encoding="utf-8")
print("Prepared", len(entry["frames"]), "frames in", list(entry["clips"]))
