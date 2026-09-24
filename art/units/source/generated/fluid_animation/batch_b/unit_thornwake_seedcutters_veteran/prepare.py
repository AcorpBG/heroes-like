"""Prepare the pending Amberhook Reaper six-clip trial from original source pixels.

Movement drafts stay in generation.json, but no move clip is selected: both
correction rounds repeated the same leading leg and failed visual review.
"""

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
sys.path.insert(0, str(ROOT / "tools"))
from refine_fluid_frame_crops import body_rectangles


def rel(path):
    return path.resolve().relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


TOOL_DIR = "C:/Users/acorp/.codex/generated_images/01a0d1dd-361d-7520-92b1-3e31f4ccb31e"
CALLS = [
    ("idle_v1", "exec-642b2b62-b0e9-41d8-81ee-616bb6cd1aae.png", ["identity_reference.png"]),
    ("idle_v2", "exec-52048fea-47d8-4d27-8125-f2275d43fbc3.png", ["idle_v1.png"]),
    ("move_v1", "exec-0cae46fe-6eff-4b56-8bc8-c2aab14a959a.png", ["identity_reference.png"]),
    ("attack_v1", "exec-4d4223ef-7832-402c-81c2-4f18e02f62c4.png", ["identity_reference.png"]),
    ("reactions_v1", "exec-428e39d3-d242-4961-9423-6b349fdbd2d4.png", ["identity_reference.png"]),
    ("cast_v1", "exec-4548db64-453c-4066-a864-786e9b0ebdfd.png", ["identity_reference.png"]),
    ("death_v1", "exec-c4009b32-8c6f-4e98-98e0-6c29ab2c05b8.png", ["identity_reference.png"]),
    ("move_near_v1", "exec-d7e9c567-4830-4f1f-ad42-b5b60a15b83f.png", ["identity_reference.png", "move_v1.png"]),
    ("attack_windup_correction_v1", "exec-909d2ad0-8c68-49aa-8c14-01fea19a1f6f.png", ["identity_reference.png", "attack_v1.png"]),
    ("cast_guard_correction_v1", "exec-ed65a488-d9e3-4515-b4c0-fe79bdb2d7fe.png", ["identity_reference.png", "cast_v1.png"]),
    ("death_middle_correction_v1", "exec-8f71ccde-2206-4898-bd56-6a33db5d0f63.png", ["identity_reference.png", "death_v1.png"]),
    ("move_near_correction_v1", "exec-4064837e-307d-4c41-a9f8-6f1d63493034.png", ["identity_reference.png", "move_near_lift_reference.png"]),
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
        references=[dict(path=rel(HERE / r), sha256=sha(HERE / r)) for r in refs],
        selected_for_candidate=stem in {"idle_v1", "attack_v1", "attack_windup_correction_v1", "reactions_v1", "cast_v1", "death_v1", "death_middle_correction_v1"},
    ))
(HERE / "generation.json").write_text(json.dumps(dict(schema_version=1, generations=lineage), indent=2) + "\n", encoding="utf-8")

reference = HERE / "identity_reference.png"
reference_meta = json.loads((HERE / "identity_reference.json").read_text(encoding="utf-8"))
assert sha(ROOT / reference_meta["source"]) == reference_meta["source_sha256"]
assert sha(reference) == reference_meta["output_sha256"]
with Image.open(ROOT / reference_meta["source"]) as original, Image.open(reference) as saved:
    assert original.crop(tuple(reference_meta["crop"])).convert("RGBA").tobytes() == saved.convert("RGBA").tobytes()

movement_reference_meta = json.loads((HERE / "move_near_lift_reference.json").read_text(encoding="utf-8"))
movement_reference = HERE / movement_reference_meta["output"]
assert sha(ROOT / movement_reference_meta["source"]) == movement_reference_meta["source_sha256"]
assert sha(movement_reference) == movement_reference_meta["output_sha256"]
with Image.open(ROOT / movement_reference_meta["source"]) as original, Image.open(movement_reference) as saved:
    assert original.crop(tuple(movement_reference_meta["crop"])).convert("RGBA").tobytes() == saved.convert("RGBA").tobytes()

entry = dict(
    unit_id=HERE.name,
    reference_height=256,
    source_facing="right",
    frames=[], clips={}, source_scale_by_image={},
    source_scale_reason="One fixed anatomical scale per original source sheet: approximately 232px original standing hair-to-sole silhouette in the 256px inherited reference. Lower crouched/fallen bounds never receive per-pose resizing.",
    provenance=dict(tool="builtin_image_gen", original_reference=reference_meta,
                    reference=rel(reference), generation_lineage=rel(HERE / "generation.json")),
    accepted_clips=[],
)

SOURCE_SCALE = {
    "idle_v1": .615,
    "attack_v1": .615,
    "attack_windup_correction_v1": .200,
    "reactions_v1": .615,
    "cast_v1": .615,
    "death_v1": .500,
    "death_middle_correction_v1": .370,
}


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
    source = HERE / f"{stem}.png"
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
idle_source_order = (0, 1, 2, 5, 4, 3, 6, 7)
idle_torsos = [(285, 190), (760, 190), (280, 570), (760, 570),
               (285, 955), (760, 955), (285, 1340), (760, 1340)]
for i, source_index in enumerate(idle_source_order):
    xy = idle_torsos[source_index]
    add("idle", "idle_v1", i, xy, 285 if source_index % 2 == 0 else 760)

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

# Original chest-crossed support recovery joined the two hooks; an existing
# valid idle painting (row 3 right) supplies a separate-grip recovery beat.
for i in range(8):
    if i == 6:
        add("cast", "idle_v1", i, (760, 955), 760)
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
         ("death_v1", (760, 955), 760, ((620, 1110), (900, 1120))),
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
                            "defend": 130, "cast": 130, "death": 150}[name],
                static_frame=3 if name == "defend" else 7 if name == "death" else 0)
entry["clips"]["attack"]["contact_frame"] = 4
entry["clips"]["cast"]["contact_frame"] = 4
entry["visual_review"] = dict(
    status="pending",
    notes="Parent reviewed original sources and final native 128px phase renders; corrected missing/merged sickles, excluded clipped fingertips, removed prior-row boots from the raised-arm extraction and adjusted fallen-body anchors. Six clips remain candidates, not accepted runtime content. Idle sequencing, attack recovery, held defense, physical support and weapon release were inspected as ordered frames; continuous playback was not verified because browser policy blocked the local animated preview. Final focused Godot candidate check passed 102 assertions. Both generated walking correction rounds still advance the same far/image-right leg, so movement is excluded. No live catalogs were changed. A shared idle painting supplies support recovery; no duplicate painting pads an individual clip.",
)
(HERE / "handoff.json").write_text(json.dumps(dict(schema_version=1, units=[entry]), indent=2) + "\n", encoding="utf-8")
print("Prepared", len(entry["frames"]), "frames in", list(entry["clips"]))
