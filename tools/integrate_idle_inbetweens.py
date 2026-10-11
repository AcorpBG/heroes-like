#!/usr/bin/env python3
"""Put the RIFE idle loops of tools/idle_inbetweens.py into the game.

  python tools/integrate_idle_inbetweens.py UNIT_ID [UNIT_ID ...] --from DIR
  python tools/integrate_idle_inbetweens.py --all --from DIR [--check]

DIR is an output folder of tools/idle_inbetweens.py. For each unit that has
in-betweens:

1. Checks every accepted frame of the new loop against the frame the game plays
   now (same painting, scale and ground anchor), so a stale or wrong candidate
   cannot replace an idle. The loop's frames are all resampled on one grid, so
   they differ from the atlas's at the edges by under a pixel; the loop is moved
   by the median offset of its accepted frames, so it stands where the old idle
   stood.
2. Writes the loop as its own sheet, art/animation/runtime/idle/<unit>.png: all
   frames on one shared crop and ground anchor, in a grid of at most 4096 px a
   side. The action atlas and its accepted pixels are not touched.
3. Points the manifest idle clip at that sheet (scripts/ui/BattleUnitPose.gd
   sheet_path). The clip keeps `from_atlas`, the atlas idle the loop was made
   from, so the tool can run again and a republish can keep the loop.
4. Points the unit's overworld idle (art/overworld/creature_idle.json) at the
   same sheet and removes its old strip.
5. Registers the sheet in docs/battle-unit-animation-acceptance.json and the
   unit's art/animation/source/fluid/<unit>/provenance.json.

--check only reports the frame check. See docs/idle-inbetweens.md.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from integrate_fluid_creature_animation import old_pose  # noqa: E402
from pack_overworld_creature_idle import extract  # noqa: E402

MANIFEST = ROOT / "content/unit_animation_manifest.json"
OVERWORLD = ROOT / "art/overworld/creature_idle.json"
REGISTER = ROOT / "docs/battle-unit-animation-acceptance.json"
SHEETS = ROOT / "art/animation/runtime/idle"
MAX_SIDE = 4096       # the action atlases' limit too
PADDING = 8           # transparent gutter around the shared crop, for filtering and the map outline
MAX_MISMATCH = 0.2    # alpha difference of an accepted frame vs the game's, as a share of its alpha
MASS_RANGE = (0.97, 1.03)


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value, compact=False):
    text = json.dumps(value, indent=None if compact else 2, separators=(",", ":") if compact else None)
    Path(path).write_text(text + "\n", encoding="utf-8", newline="\n")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def uri(path):
    return "res://" + Path(path).resolve().relative_to(ROOT).as_posix()


def atlas_idle(row):
    """The idle clip as it plays from the action atlas."""
    idle = row["pose_clips"]["idle"]
    base = idle.get("from_atlas", idle)
    return {"indices": list(base["indices"]), "frame_msec": base["frame_msec"],
            "static_frame": base.get("static_frame", 0)}


def loop_poses(unit_dir, report):
    """The loop's frames as (ink crop, offset from the ground anchor)."""
    recipe = read(unit_dir / "idle_recipe.json")
    (fw, fh), gm, columns = recipe["frame_size"], recipe["ground_margin"], recipe["columns"]
    poses = []
    with Image.open(unit_dir / "idle_runtime.png") as image:
        sheet = image.convert("RGBA")
    for i in range(report["frames"]):
        cell = sheet.crop((i % columns * fw, i // columns * fh, (i % columns + 1) * fw, (i // columns + 1) * fh))
        box = cell.getchannel("A").getbbox()
        if box is None:
            raise ValueError(f"frame {i} of the loop is empty")
        poses.append((cell.crop(box), (box[0] - fw // 2, box[1] - (fh - gm))))
    return poses


def compare(new, old):
    """Best offset (dx, dy) of a new frame against the game's, the alpha
    mismatch there as a share of the game frame's alpha, and the alpha mass ratio."""
    (p, (px, py)), (q, (qx, qy)) = new, old
    a = np.asarray(p)[..., 3].astype(np.int32)
    b = np.asarray(q)[..., 3].astype(np.int32)
    reach = 3
    left, top = min(px, qx) - reach, min(py, qy) - reach
    width = max(px + a.shape[1], qx + b.shape[1]) + reach - left
    height = max(py + a.shape[0], qy + b.shape[0]) + reach - top
    game = np.zeros((height, width), np.int32)
    game[qy - top:qy - top + b.shape[0], qx - left:qx - left + b.shape[1]] = b
    best = None
    for dx in range(-reach, reach + 1):
        for dy in range(-reach, reach + 1):
            ours = np.zeros_like(game)
            x, y = px + dx - left, py + dy - top
            ours[y:y + a.shape[0], x:x + a.shape[1]] = a
            error = int(np.abs(ours - game).sum())
            if best is None or error < best[0]:
                best = (error, dx, dy)
    mass = max(1, int(b.sum()))
    return best[1], best[2], best[0] / mass, int(a.sum()) / mass


def check_keys(row, sheet, poses, report):
    """Per accepted frame (dx, dy, mismatch, mass); raises if one is not the game's frame."""
    k = report["inbetweens_per_pair"]
    base = atlas_idle(row)
    if len(base["indices"]) != report["source_frames"] or base["frame_msec"] != report["source_msec"]:
        raise ValueError(f"the loop was made from {report['source_frames']} frames at {report['source_msec']} ms; "
                         f"the game plays {len(base['indices'])} at {base['frame_msec']} ms")
    results = []
    for j, index in enumerate(base["indices"]):
        dx, dy, mismatch, mass = compare(poses[j * (k + 1)], old_pose(sheet, row, index))
        if mismatch > MAX_MISMATCH or not MASS_RANGE[0] <= mass <= MASS_RANGE[1]:
            raise ValueError(f"accepted frame {j} does not match the game's (mismatch {mismatch:.2f}, alpha mass {mass:.3f})")
        results.append((dx, dy, mismatch, mass))
    return results


def build_sheet(poses):
    """One shared crop around every frame and the ground anchor, in a grid."""
    left = min(min(x for _, (x, _) in poses), 0) - PADDING
    top = min(min(y for _, (_, y) in poses), 0) - PADDING
    right = max(max(x + p.width for p, (x, _) in poses), 0) + PADDING
    bottom = max(max(y + p.height for p, (_, y) in poses), 0) + PADDING
    cw, ch = right - left, bottom - top
    # The fewest rows that fit, filled evenly: an empty tail would still cost video memory.
    rows = math.ceil(len(poses) / max(1, MAX_SIDE // cw))
    columns = math.ceil(len(poses) / rows)
    if columns * cw > MAX_SIDE or rows * ch > MAX_SIDE:
        raise ValueError(f"{len(poses)} frames of {cw}x{ch} do not fit a {MAX_SIDE} px sheet")
    sheet = Image.new("RGBA", (columns * cw, rows * ch))
    for i, (pose, (x, y)) in enumerate(poses):
        sheet.paste(pose, (i % columns * cw + x - left, i // columns * ch + y - top))
    return sheet, {"columns": columns, "frame_size": {"width": cw, "height": ch},
                   "ground_margin": bottom, "anchor_x": -left}


def integrate(row, unit_dir, overworld, register, check_only):
    """Checks and builds everything for one unit first; changes the shared data
    only once nothing can fail, so a unit that fails keeps its idle untouched."""
    uid = row["unit_id"]
    report = read(unit_dir / "report.json")
    k = report["inbetweens_per_pair"]
    if k == 0:
        return f"SKIP {uid}: no in-betweens at {report['source_msec']} ms; idle unchanged"
    # Hold and keep differ only on flagged pairs; the owner chose hold (2026-10-11).
    handling = report.get("flagged_handling", "hold" if not report["flagged_pairs"] else "keep")
    if report["flagged_pairs"] and handling != "hold":
        raise ValueError("flagged pairs were kept; rerun tools/idle_inbetweens.py with --flagged hold")
    poses = loop_poses(unit_dir, report)
    with Image.open(ROOT / row["pose_sheet"].removeprefix("res://")) as image:
        atlas = image.convert("RGBA")
    keys = check_keys(row, atlas, poses, report)
    sx = -int(np.median([d[0] for d in keys]).round())
    sy = -int(np.median([d[1] for d in keys]).round())
    worst = max(d[2] for d in keys)
    summary = f"{uid}: {report['source_frames']} -> {report['frames']} frames, accepted frames match (worst mismatch {worst:.2f}, moved {sx},{sy})"
    if check_only:
        return "OK " + summary
    sheet, grid = build_sheet([(p, (x - sx, y - sy)) for p, (x, y) in poses])
    SHEETS.mkdir(parents=True, exist_ok=True)
    path = SHEETS / f"{uid}.png"
    sheet.save(path, optimize=True)
    try:
        digest = sha256(path)
        base = atlas_idle(row)
        idle = {key: value for key, value in row["pose_clips"]["idle"].items()
                if key not in ("from_atlas", "sheet", "columns", "frame_size", "ground_margin", "anchor_x")}
        idle.update(frames=report["frames"], indices=list(range(report["frames"])),
                    frame_msec=int(round(base["frame_msec"] / (k + 1))),
                    static_frame=base["static_frame"] * (k + 1), sheet=uri(path), **grid, from_atlas=base)
        updated = dict(row, pose_clips=dict(row["pose_clips"], idle=idle))
        strip, entry = extract(updated)
        if strip is not None or entry["path"] != uri(path):
            raise ValueError("the overworld idle does not play the new sheet")
        provenance_path = ROOT / row["pose_provenance"].removeprefix("res://")
        provenance = read(provenance_path)
        provenance["idle_inbetweens"] = {
            "tool": "tools/idle_inbetweens.py", "integration": "tools/integrate_idle_inbetweens.py",
            "source": report["source"], "mirrored": report.get("mirrored", False),
            "from_atlas": base, "inbetweens_per_pair": k, "frames": report["frames"],
            "frame_msec": idle["frame_msec"], "flagged_handling": handling, "held_pairs": report["flagged_pairs"],
            "weights_sha256": report["weights_sha256"], "sheet": uri(path), "sheet_sha256": digest,
            "review": "Owner chose RIFE in-betweens and holding flagged pairs (2026-10-11); "
                      "accepted frames checked against the game's before integration.",
        }
        accepted = next(u for u in register["units"] if u["unit_id"] == uid)
        pose = {key: value for key, value in updated.items() if key.startswith("pose_") and not key.startswith("pose_review_")}
        pose_digest = hashlib.sha256(json.dumps(pose, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    except Exception:
        path.unlink(missing_ok=True)
        raise

    row["pose_clips"]["idle"] = idle
    old_strip = overworld["units"].get(uid, {}).get("path", "")
    overworld["units"][uid] = entry
    if old_strip.startswith("res://art/overworld/runtime/creature_idle/"):
        for stale in (ROOT / old_strip.removeprefix("res://"), ROOT / (old_strip.removeprefix("res://") + ".import")):
            stale.unlink(missing_ok=True)
    write(provenance_path, provenance)
    accepted["pose_metadata_sha256"] = pose_digest
    accepted["clip_sheet_sha256"] = {"idle": digest}
    return "OK " + summary + f"; sheet {sheet.width}x{sheet.height}"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("unit_ids", nargs="*")
    parser.add_argument("--all", action="store_true", help="every unit with a folder in --from")
    parser.add_argument("--from", dest="source", type=Path, required=True, help="output folder of tools/idle_inbetweens.py")
    parser.add_argument("--check", action="store_true", help="only check the accepted frames; change nothing")
    args = parser.parse_args(argv)
    catalog, overworld, register = read(MANIFEST), read(OVERWORLD), read(REGISTER)
    rows = {row["unit_id"]: row for row in catalog["items"]}
    ids = [uid for uid in rows if (args.source / uid / "report.json").is_file()] if args.all else args.unit_ids
    unknown = [uid for uid in ids if uid not in rows]
    if not ids or unknown:
        parser.error(f"unknown unit ids: {unknown}" if unknown else "name units or pass --all")
    failed = []
    for uid in ids:
        try:
            print(integrate(rows[uid], args.source / uid, overworld, register, args.check), flush=True)
        except Exception as exc:  # one bad unit must not stop the roster; it keeps its idle
            failed.append(uid)
            print(f"FAIL {uid}: {exc}", flush=True)
    if not args.check:
        write(MANIFEST, catalog, compact=True)
        write(OVERWORLD, overworld)
        write(REGISTER, register)
    print(f"IDLE_INTEGRATION units={len(ids)} failed={len(failed)}{' check-only' if args.check else ''}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
