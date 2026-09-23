#!/usr/bin/env python3
"""Pack original fluid clips and emit reviewable manifest patches, never edit catalogs.

Each source frame has reviewed rectangles, a ground anchor and a fixed anatomical
scale. Only crop, transparent padding and uniform downsampling are performed.
The common envelope is derived from ink rather than a wasteful 512px canvas.
Existing clips are copied unchanged until explicitly replaced. Pixel uniqueness
is an integrity check, never visual acceptance or proof of coherent motion.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MINIMUMS = dict(idle=8, move=8, attack=8, ranged=8, cast=8, hit=4, defend=4, death=8, dead=1)


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def resolve(source):
    path = (ROOT / str(source).removeprefix("res://")).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f"source must be an existing repository file: {source}")
    return path


def uri(path):
    return "res://" + Path(path).resolve().relative_to(ROOT).as_posix()


def source_pose(frame, alpha_noise_cutoff=0):
    path = resolve(frame["source"])
    with Image.open(path) as source:
        if source.mode != "RGBA" or source.getchannel("A").getextrema()[0] != 0:
            raise ValueError(f"original RGBA cutout required: {path}")
        rects = frame["rects"]
        left, top = min(r[0] for r in rects), min(r[1] for r in rects)
        right, bottom = max(r[2] for r in rects), max(r[3] for r in rects)
        cut = Image.new("RGBA", (right-left, bottom-top))
        for l, t, r, b in rects:
            if not (0 <= l < r <= source.width and 0 <= t < b <= source.height):
                raise ValueError(f"source rectangle outside original: {frame['name']}")
            cut.paste(source.crop((l, t, r, b)), (l-left, t-top))
    if not 0 <= int(alpha_noise_cutoff) <= 16:
        raise ValueError("alpha noise threshold must preserve painted edges (0..16)")
    if alpha_noise_cutoff:
        cut.putalpha(cut.getchannel("A").point(lambda a: 0 if a <= alpha_noise_cutoff else a))
    scale = float(frame["scale"])
    if not 0 < scale <= 1:
        raise ValueError("positive downsampling scale required")
    cut = cut.resize((max(1, round(cut.width*scale)), max(1, round(cut.height*scale))), Image.Resampling.LANCZOS)
    bounds = cut.getchannel("A").getbbox()
    if not bounds:
        raise ValueError(f"empty original pose: {frame['name']}")
    x = round(-(frame["anchor"][0]-left)*scale)
    y = round(-(frame["anchor"][1]-top)*scale)
    return cut.crop(bounds), (x+bounds[0], y+bounds[1])


def old_pose(sheet, row, index):
    w, h = [row["pose_frame_size"][k] for k in ("width", "height")]
    col = row["pose_columns"]
    cut = sheet.crop((index % col*w, index//col*h, (index % col+1)*w, (index//col+1)*h))
    bounds = cut.getchannel("A").getbbox()
    if not bounds:
        raise ValueError("existing pose is empty")
    return cut.crop(bounds), (bounds[0]-w//2, bounds[1]-h+row.get("pose_ground_margin", 0))


def clip_indices(spec, columns):
    return spec.get("indices", [spec.get("row", 0)*columns+spec.get("column", 0)+i for i in range(spec["frames"])])


def pack_unit(entry, previous, output_dir):
    uid = entry["unit_id"]
    reference_height = entry.get("reference_height", previous.get("pose_reference_height", previous["pose_frame_size"]["height"]))
    if reference_height != previous.get("pose_reference_height", previous["pose_frame_size"]["height"]):
        raise ValueError(f"{uid}: shared anatomical reference height must preserve previous scale")
    poses, clips, sources = [], {}, {}
    # Retain every old route until genuinely authored replacement is supplied.
    # This permits small reviewed deliveries without silently deleting actions.
    with Image.open(resolve(previous["pose_sheet"])) as sheet:
        for name, spec in previous["pose_clips"].items():
            if name in entry["clips"]:
                continue
            indices = []
            for index in clip_indices(spec, previous["pose_columns"]):
                indices.append(len(poses))
                poses.append(old_pose(sheet, previous, index))
            clips[name] = dict(spec, indices=indices)
    original_poses = [source_pose(f, f.get("alpha_noise_cutoff", entry.get("alpha_noise_cutoff", 0))) for f in entry["frames"]]
    facing = previous.get("pose_source_facing", "right")
    if entry.get("source_facing", facing) != facing:
        # One orientation conversion for the authored clip; reflection is not
        # a new pose and must never make preserved clips change facing.
        original_poses = [(p.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (-x-p.width, y)) for p, (x,y) in original_poses]
    scales = {float(f["scale"]) for f in entry["frames"]}
    if len(scales) > 1:
        source_scales = entry.get("source_scale_by_image", {})
        if not entry.get("source_scale_reason") or any(source_scales.get(f["source"]) != f["scale"] for f in entry["frames"]):
            raise ValueError(f"{uid}: frame-specific scale would normalize away anatomy; differing source resolutions need one documented scale per original")
    for frame in entry["frames"]:
        path = resolve(frame["source"])
        sources[uri(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name, authored in entry["clips"].items():
        indices = authored["indices"]
        if name not in MINIMUMS or len(indices) < MINIMUMS[name]:
            raise ValueError(f"{uid}/{name}: requires {MINIMUMS.get(name, 'a known clip')} original poses")
        if len(indices) != len(set(indices)):
            raise ValueError(f"{uid}/{name}: repeated source indices are not additional paintings")
        selected = [original_poses[i] for i in indices]
        fingerprints = [hashlib.sha256(p.tobytes()).hexdigest() for p, _ in selected]
        if len(set(fingerprints)) != len(fingerprints):
            raise ValueError(f"{uid}/{name}: duplicate source paintings")
        durations = authored.get("frame_durations_msec", [])
        if durations and (len(durations) != len(indices) or any(not 30 <= int(d) <= 1000 for d in durations)):
            raise ValueError(f"{uid}/{name}: invalid frame holds")
        if not 30 <= int(authored.get("frame_msec", 100)) <= 1000:
            raise ValueError(f"{uid}/{name}: invalid frame timing")
        contact = authored.get("contact_frame")
        if contact is not None and not 0 <= contact < len(indices):
            raise ValueError(f"{uid}/{name}: invalid contact frame")
        start = len(poses)
        poses.extend(selected)
        clips[name] = dict(authored, indices=list(range(start, len(poses))), frames=len(indices), authored_timing=True)
        clips[name].setdefault("frame_msec", 100)
        clips[name].setdefault("loop", name in ("idle", "move"))
        clips[name].setdefault("static_frame", len(indices)-1 if name in ("death", "dead", "defend") else 0)
    # A persistent corpse reuses the final death painting, not a hit or idle.
    if "death" in entry["clips"] and "dead" not in entry["clips"]:
        clips["dead"] = dict(indices=[clips["death"]["indices"][-1]], frames=1, frame_msec=100, loop=False, static_frame=0, authored_timing=True)
    extent = max(max(abs(x), abs(x+p.width)) for p, (x, y) in poses)
    half = math.ceil((extent+4)/4)*4
    top = math.floor((min(y for p, (x, y) in poses)-4)/4)*4
    bottom = math.ceil((max(y+p.height for p, (x, y) in poses)+4)/4)*4
    width, height = half*2, bottom-top
    layouts = [(c, math.ceil(len(poses)/c)) for c in range(1, 33) if c*width <= 4096 and math.ceil(len(poses)/c)*height <= 4096]
    if not layouts:
        raise ValueError(f"{uid}: original envelope cannot fit 4096 atlas; needs authored split pages, never shrink creature")
    columns, rows = min(layouts, key=lambda cr: (cr[0]*cr[1], abs(cr[0]*width-cr[1]*height)))
    atlas = Image.new("RGBA", (columns*width, rows*height))
    for i, (pose, (x, y)) in enumerate(poses):
        atlas.paste(pose, (i % columns*width+half+x, i//columns*height+y-top))
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir/f"{uid}.png"
    # Direct destination write inherits the workspace ACL on Windows. Never
    # rename a private tempfile into the runtime tree.
    atlas.save(path, optimize=True)
    aliases = {k:v for k,v in previous.get("pose_aliases", {}).items() if k not in entry["clips"]}
    result = dict(previous, pose_sheet=uri(path), pose_clips=clips, pose_columns=columns,
                  pose_frame_size=dict(width=width, height=height), pose_ground_margin=bottom,
                  pose_reference_height=reference_height, pose_source_facing=facing,
                  pose_aliases=aliases, pose_provenance="original_fluid_animation")
    review = dict(entry.get("visual_review", {"status":"pending"}))
    return dict(unit_id=uid, animation=result, sources=sources, visual_review=review,
                replaced_clips=list(entry["clips"]), accepted_clips=entry.get("accepted_clips", []),
                texture_bytes_rgba=atlas.width*atlas.height*4, atlas_sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    rows = {r["unit_id"]: r for r in read(ROOT/"content/unit_animation_manifest.json")["items"]}
    patches = [pack_unit(e, copy.deepcopy(rows[e["unit_id"]]), args.output_dir.resolve()) for e in read(args.handoff)["units"]]
    path = args.output_dir/"manifest_patch.json"
    path.write_text(json.dumps(dict(schema_version=1, units=patches), indent=2)+"\n", encoding="utf-8")
    print(f"Packed {len(patches)} candidates; {sum(p['texture_bytes_rgba'] for p in patches):,} uncompressed RGBA bytes. Review required. {path}")


if __name__ == "__main__":
    main()
