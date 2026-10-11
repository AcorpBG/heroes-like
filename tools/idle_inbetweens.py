#!/usr/bin/env python3
"""Smoother creature idle loops: RIFE in-betweens between the accepted frames.

  python tools/idle_inbetweens.py UNIT_ID [UNIT_ID ...] --out DIR [options]
  python tools/idle_inbetweens.py --all --out DIR

For each unit:
1. Reads the idle frames the game plays: the idle clip of
   art/animation/source/fluid/<unit>/reviewed_handoff.json when it has one
   (mirrored when the game mirrors it), otherwise the frames of the unit's
   poses/<unit>/packing.json that its fluid baseline.json plays as idle.
   Source images come from the checkout when they are restored there,
   otherwise straight from the source-art archive, checked against its
   SHA-256 manifest.
2. Aligns the frames on their ground anchors on one canvas.
3. Adds RIFE in-betweens to every neighbouring pair, last to first included.
   Each pair runs over black and over white, and colour and alpha are
   recovered from the two results.
4. Checks every in-between for smear: see-through pixels inside the figure,
   against the two frames around it. A smeared pair is redone with flow
   estimated from a coarser start, keeping whichever smears less. A pair that
   still smears is flagged and, by default, holds its two paintings and snaps
   halfway (--flagged keep leaves the in-betweens).
5. Packs the loop with tools/pack_unit_pose_art, the game's packer.

The accepted frames pass through unchanged as every (in-betweens + 1)-th frame.
The output is a candidate; tools/integrate_idle_inbetweens.py puts it into the game. Needs torch,
safetensors, numpy and Pillow, and ffmpeg for --review. See
docs/idle-inbetweens.md for the environment and the model weights.

Writes, per unit, under DIR/<unit_id>/: idle_frames.png (aligned canvas
sheet), idle_recipe.json, idle_runtime.png (game cells), report.json,
flagged.jpg when a pair is flagged, review.mp4 with --review; and
DIR/summary.json for the whole run.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from pack_unit_pose_art import pack  # noqa: E402
from restore_archived_source_material import load_index  # noqa: E402

MANIFEST = ROOT / "content" / "unit_animation_manifest.json"
DEFAULT_WEIGHTS = Path.home() / ".cache" / "heroes-like" / "rife_v4.26.safetensors"
WEIGHTS_URL = "https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.26.safetensors"
TARGET_MSEC = 60      # --inbetweens auto aims at about this many ms per frame
SMEAR_RATIO = 1.6     # see-through pixels in an in-between vs the frames around it
COLUMNS = 8


class SkipUnit(Exception):
    pass


class Sources:
    """Source images by repository-relative path: the checkout first, then the archive."""

    def __init__(self, archive_dir):
        self.archive_dir = archive_dir
        self.rows = None
        self.zips = {}

    def image(self, rel):
        local = ROOT / rel
        if local.is_file():
            return Image.open(local).convert("RGBA")
        if self.archive_dir is None:
            raise SkipUnit(f"{rel} is not restored here; pass --archive-dir or set HEROES_SOURCE_ARCHIVE")
        if self.rows is None:
            self.rows = load_index(self.archive_dir)
        row = self.rows.get(rel)
        if row is None:
            raise SkipUnit(f"{rel} is neither restored nor in the archive")
        if row["archive"] not in self.zips:
            self.zips[row["archive"]] = zipfile.ZipFile(self.archive_dir / row["archive"])
        data = self.zips[row["archive"]].read(rel)
        if hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise RuntimeError(f"Archive payload failed its SHA-256 check: {rel}")
        return Image.open(io.BytesIO(data)).convert("RGBA")


def idle_recipe(row):
    """The idle the game plays, as {frame_size, ground_margin, frames, flip, from,
    msec} with repository-relative frame sources.

    Follows how tools/publish_fluid_creature_animation built the unit's atlas: the
    idle clip of the reviewed fluid handoff when it has one, otherwise the
    baseline atlas's idle, which tools/pack_unit_pose_art packed from the unit's
    packing.json."""
    uid, idle = row["unit_id"], row["pose_clips"]["idle"]
    folder = ROOT / f"art/animation/source/fluid/{uid}"
    handoff, baseline = folder / "reviewed_handoff.json", folder / "baseline.json"
    entry = None
    if handoff.is_file():
        entry = next((u for u in json.loads(handoff.read_text(encoding="utf-8"))["units"] if u["unit_id"] == uid), None)
    if entry and "idle" in entry["clips"]:
        cutoff = entry.get("alpha_noise_cutoff", 0)
        frames = [dict(entry["frames"][i], alpha_noise_cutoff=entry["frames"][i].get("alpha_noise_cutoff", cutoff))
                  for i in entry["clips"]["idle"]["indices"]]
        size = [row["pose_frame_size"]["width"], row["pose_frame_size"]["height"]]
        # The publisher mirrors a handoff drawn facing the other way.
        flip = entry.get("source_facing", "right") != row.get("pose_source_facing", "right")
        return {"frame_size": size, "ground_margin": row["pose_ground_margin"], "frames": frames, "flip": flip,
                "from": handoff.relative_to(ROOT).as_posix(), "msec": idle["frame_msec"]}
    packing = ROOT / f"art/animation/source/poses/{uid}/packing.json"
    if baseline.is_file() and packing.is_file():
        indices = json.loads(baseline.read_text(encoding="utf-8"))["pose_clips"]["idle"]["indices"]
        spec = json.loads(packing.read_text(encoding="utf-8"))
        poses = packing.parent.relative_to(ROOT).as_posix()
        frames = [dict(spec["frames"][i], source=f"{poses}/{spec['frames'][i]['source']}") for i in indices]
        return {"frame_size": spec["frame_size"], "ground_margin": spec["ground_margin"], "frames": frames, "flip": False,
                "from": f"{packing.relative_to(ROOT).as_posix()} frames {indices[0]}-{indices[-1]}",
                "msec": idle["frame_msec"]}
    raise SkipUnit("no idle recipe found (reviewed fluid handoff idle, or baseline idle and packing.json)")


def cutout(sheet, frame):
    """The frame's rectangles on one image, as tools/pack_unit_pose_art cuts them."""
    rects = frame["rects"]
    x0, y0 = min(r[0] for r in rects), min(r[1] for r in rects)
    image = Image.new("RGBA", (max(r[2] for r in rects) - x0, max(r[3] for r in rects) - y0))
    for left, top, right, bottom in rects:
        image.paste(sheet.crop((left, top, right, bottom)), (left - x0, top - y0))
    # Some recipes give sub-pixel anchors; the packer rounds after scaling too.
    return image, round(frame["anchor"][0] - x0), round(frame["anchor"][1] - y0)


def aligned_frames(recipe, sources):
    """Every frame on one canvas with its ground anchor at the same point, at the
    largest scale any frame uses (a few recipes mix scales), so frames are only
    ever reduced. Canvas sides are multiples of 128, which the coarse flow pass needs."""
    sheets = {s: sources.image(s) for s in sorted({f["source"] for f in recipe["frames"]})}
    scale = max(f.get("scale", 1.0) for f in recipe["frames"])
    pieces = []
    for f in recipe["frames"]:
        image, fx, fy = cutout(sheets[f["source"]], f)
        cutoff = f.get("alpha_noise_cutoff", 0)
        if cutoff:  # before any resize, as the game's packer does; resizing can lift noise past it
            image.putalpha(image.getchannel("A").point(lambda a: 0 if a <= cutoff else a))
        if recipe.get("flip"):
            image, fx = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT), image.width - fx
        ratio = f.get("scale", 1.0) / scale
        if ratio != 1.0:
            image = image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))), Image.LANCZOS)
            fx, fy = round(fx * ratio), round(fy * ratio)
            # The game shrinks this frame in one step, which averages faint source
            # noise (alpha 1-2) away; two steps leave specks that widen its bounds.
            image.putalpha(image.getchannel("A").point(lambda a: 0 if a <= 2 else a))
        pieces.append((image, fx, fy))
    half = max(max(fx, image.width - fx) for image, fx, _ in pieces)
    top = max(fy for _, _, fy in pieces)
    bottom = max(image.height - fy for image, _, fy in pieces)
    up = lambda v: (v + 127) // 128 * 128
    cw, ch = up(2 * half + 8), up(top + bottom + 8)
    ax, ay = cw // 2, ch - bottom - 4
    frames = []
    for image, fx, fy in pieces:
        canvas = Image.new("RGBA", (cw, ch))
        canvas.paste(image, (ax - fx, ay - fy))
        frames.append(np.asarray(canvas).astype(np.float32) / 255.0)
    return frames, (cw, ch, ax, ay), scale


def see_through(rgba):
    """Pixels that are neither solid nor clear."""
    a = rgba[..., 3]
    return int(((a > 0.08) & (a < 0.85)).sum())


class Interpolator:
    def __init__(self, weights, device):
        import torch
        import rife_ifnet

        self.torch = torch
        self.device = device
        self.model = rife_ifnet.load(weights, device)

    def inbetweens(self, a, b, count, coarse):
        """count frames between a and b (RGBA float arrays), straight alpha."""
        torch = self.torch
        scale = 0.5 if coarse else 1.0

        def over(rgba, bg):
            rgb = rgba[..., :3] * rgba[..., 3:4] + bg * (1 - rgba[..., 3:4])
            return torch.from_numpy(np.ascontiguousarray(rgb)).permute(2, 0, 1)[None].to(self.device)

        out = []
        with torch.no_grad():
            pairs = {bg: (over(a, bg), over(b, bg)) for bg in (0.0, 1.0)}
            for j in range(1, count + 1):
                t = j / (count + 1)
                on_black, on_white = (self.model(*pairs[bg], t, scale).clamp(0, 1)[0].permute(1, 2, 0).cpu().numpy()
                                      for bg in (0.0, 1.0))
                alpha = np.clip(1.0 - (on_white - on_black).mean(2, keepdims=True), 0, 1)
                alpha[alpha < 0.02] = 0
                rgb = np.where(alpha > 0, on_black / np.maximum(alpha, 1e-4), 0)
                out.append(np.concatenate([np.clip(rgb, 0, 1), alpha], 2))
        return out


def loop_with_inbetweens(frames, k, coarse_mode, flagged_mode, interp):
    out, checks = [], []
    n = len(frames)
    for i in range(n):
        a, b = frames[i], frames[(i + 1) % n]
        base = max(see_through(a), see_through(b), 1)
        mids = interp.inbetweens(a, b, k, coarse_mode == "always") if k else []
        ratios = [see_through(m) / base for m in mids]
        coarse = coarse_mode == "always"
        if coarse_mode == "auto" and ratios and max(ratios) > SMEAR_RATIO:
            retry = interp.inbetweens(a, b, k, True)
            retry_ratios = [see_through(m) / base for m in retry]
            if max(retry_ratios) < max(ratios):
                mids, ratios, coarse = retry, retry_ratios, True
        # Owner decision 2026-10-11: a pair that still smears holds its paintings
        # and snaps halfway, as the 8-painting loop does, instead of showing a ghost.
        held = flagged_mode == "hold" and bool(ratios) and max(ratios) > SMEAR_RATIO
        if held:
            mids = [(a if (j + 1) / (k + 1) < 0.5 else b).copy() for j in range(k)]
        out.append(a)
        for j, (m, r) in enumerate(zip(mids, ratios)):
            checks.append({"pair": f"{i}->{(i + 1) % n}", "inbetween": j + 1, "coarse": coarse,
                           "smear_ratio": round(r, 2), "flag": r > SMEAR_RATIO, "held": held})
            out.append(m)
    return out, checks


def fit_to_cell(frame, canvas, scale, frame_size, ground_margin):
    """Clears the edge pixels of an in-between that the packer would draw outside
    the game cell, and returns how many it cleared. Some idles reach within a
    pixel of the cell edge; a soft in-between edge there can spill a pixel past
    it once resized. Mirrors tools/pack_unit_pose_art's placement and check."""
    cw, ch, ax, ay = canvas
    fw, fh = frame_size
    px, py = round(fw / 2 - ax * scale), round(fh - ground_margin - ay * scale)
    ys, xs = np.nonzero(frame[..., 3] * 255 + 0.5 >= 1)
    if not len(xs):
        return 0
    # Lanczos spills at most 3 output pixels, so a frame this far inside the cell fits.
    margin = 4
    if (px + xs.min() * scale >= margin and py + ys.min() * scale >= margin
            and px + (xs.max() + 1) * scale <= fw - margin and py + (ys.max() + 1) * scale <= fh - margin):
        return 0
    cleared = 0
    for _ in range(32):
        image = Image.fromarray((frame * 255 + 0.5).astype(np.uint8), "RGBA")
        b = image.resize((max(1, round(cw * scale)), max(1, round(ch * scale))), Image.LANCZOS).getchannel("A").getbbox()
        over = {"left": -(px + b[0]), "top": -(py + b[1]), "right": px + b[2] - fw, "bottom": py + b[3] - fh}
        if max(over.values()) <= 0:
            return cleared
        ys, xs = np.nonzero(frame[..., 3] * 255 + 0.5 >= 1)
        step = lambda o: max(1, int(np.ceil(o / scale)))
        region = np.zeros(frame.shape[:2], bool)
        if over["left"] > 0:
            region[:, :xs.min() + step(over["left"])] = True
        if over["right"] > 0:
            region[:, xs.max() + 1 - step(over["right"]):] = True
        if over["top"] > 0:
            region[:ys.min() + step(over["top"]), :] = True
        if over["bottom"] > 0:
            region[ys.max() + 1 - step(over["bottom"]):, :] = True
        cleared += int((region & (frame[..., 3] > 0)).sum())
        frame[region] = 0
    raise ValueError("in-between still overflows its game cell")


def write_loop(uid, recipe, out, canvas, scale, unit_dir):
    cw, ch, ax, ay = canvas
    rows = (len(out) + COLUMNS - 1) // COLUMNS
    sheet = np.zeros((rows * ch, COLUMNS * cw, 4), np.float32)
    for i, frame in enumerate(out):
        sheet[(i // COLUMNS) * ch:(i // COLUMNS + 1) * ch, (i % COLUMNS) * cw:(i % COLUMNS + 1) * cw] = frame
    Image.fromarray((sheet * 255 + 0.5).astype(np.uint8), "RGBA").save(unit_dir / "idle_frames.png")
    packing = {"unit_id": uid, "frame_size": recipe["frame_size"], "columns": COLUMNS,
               "ground_margin": recipe["ground_margin"],
               "frames": [{"name": f"idle_{i:02d}", "source": "idle_frames.png",
                           "rects": [[(i % COLUMNS) * cw, (i // COLUMNS) * ch, (i % COLUMNS + 1) * cw, (i // COLUMNS + 1) * ch]],
                           "anchor": [(i % COLUMNS) * cw + ax, (i // COLUMNS) * ch + ay], "scale": scale}
                          for i in range(len(out))]}
    (unit_dir / "idle_recipe.json").write_text(json.dumps(packing, indent=1) + "\n", encoding="utf-8")
    pack(unit_dir / "idle_recipe.json", unit_dir / "idle_runtime.png")


def runtime_cells(unit_dir, frame_size, count):
    fw, fh = frame_size
    atlas = Image.open(unit_dir / "idle_runtime.png").convert("RGBA")
    return [atlas.crop(((i % COLUMNS) * fw, (i // COLUMNS) * fh, (i % COLUMNS + 1) * fw, (i // COLUMNS + 1) * fh))
            for i in range(count)]


def write_flagged_strip(unit_dir, frame_size, cells, flagged, k):
    """Each flagged pair as it plays (held or kept), at 2x, for review."""
    fw, fh = frame_size
    strip = Image.new("RGBA", (fw * (k + 2), fh * len(flagged)), (50, 54, 46, 255))
    for row, pair in enumerate(flagged):
        start = int(pair.split("->")[0]) * (k + 1)
        for d in range(k + 2):
            strip.alpha_composite(cells[(start + d) % len(cells)], (d * fw, row * fh))
    strip = strip.resize((strip.width * 2, strip.height * 2), Image.LANCZOS)
    strip.convert("RGB").save(unit_dir / "flagged.jpg", quality=90)


def write_review(row, unit_dir, frame_size, ground_margin, cells, step, path):
    """The current idle above the new loop, at game size (left) and 2x (right),
    on a 2560x1440 battlefield, 14 s at 30 fps."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("--review needs ffmpeg on PATH")
    width, height, fps, seconds = 2560, 1440, 30, 14.0
    game_scale = 241.0 / 256.0  # atlas pixels to screen pixels at 1440p
    msec = row["pose_clips"]["idle"]["frame_msec"]
    fw, fh = frame_size
    new, old = cells, cells[0::step]
    boxes = [c.getchannel("A").getbbox() for c in cells]
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    new, old = [c.crop(union) for c in new], [c.crop(union) for c in old]

    # Draw the figure as tall as the game's own idle frame draws it.
    atlas = Image.open(ROOT / row["pose_sheet"].removeprefix("res://")).convert("RGBA")
    pw, ph = row["pose_frame_size"]["width"], row["pose_frame_size"]["height"]
    i = row["pose_clips"]["idle"]["indices"][0]  # not always frame 0
    if row.get("pose_frame_rects"):  # packed atlas: every frame's rectangle is listed
        x, y, w, h = row["pose_frame_rects"][i]
        cell = (x, y, x + w, y + h)
    else:
        cols = row["pose_columns"]
        cell = ((i % cols) * pw, (i // cols) * ph, (i % cols + 1) * pw, (i // cols + 1) * ph)
    solid = lambda img: img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    game_box, own_box = solid(atlas.crop(cell)), solid(old[0])
    base_scale = (game_box[3] - game_box[1]) / (own_box[3] - own_box[1]) * game_scale

    big, small = ImageFont.load_default(40), ImageFont.load_default(28)
    bg = Image.open(ROOT / "art/battle/runtime/battlefields/forest.png").convert("RGBA").resize((width, height), Image.LANCZOS)
    bg.alpha_composite(Image.new("RGBA", (width, height), (0, 0, 0, 70)))
    draw = ImageDraw.Draw(bg)
    draw.rectangle((width // 2 - 4, 0, width // 2 + 4, height), fill=(18, 16, 14, 255))
    draw.rectangle((0, 718, width, 724), fill=(18, 16, 14, 160))
    text = dict(fill=(255, 235, 185), anchor="mt", stroke_width=4, stroke_fill=(0, 0, 0))
    draw.text((width / 4, 18), f"{row['name']}: game size", font=big, **text)
    draw.text((3 * width / 4, 18), "Zoomed 2x", font=big, **text)
    ground = (690, 1380)
    for cx in (width / 4, 3 * width / 4):
        draw.text((cx, ground[0] + 6), f"Now: {len(old)} frames, {msec} ms each", font=small, **text)
        draw.text((cx, ground[1] + 6), f"New: {len(new)} frames, {msec / step:.0f} ms each", font=small, **text)
    views = []
    for cx, zoom in ((width / 4, 1.0), (3 * width / 4, 2.0)):
        s = base_scale * zoom
        sized = [[c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS) for c in seq]
                 for seq in (old, new)]
        views.append((cx, s, sized))
    proc = subprocess.Popen([ffmpeg, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                             "-s", f"{width}x{height}", "-r", str(fps), "-i", "-", "-c:v", "libx264",
                             "-pix_fmt", "yuv420p", "-crf", "18", str(path)], stdin=subprocess.PIPE)
    for f in range(int(seconds * fps)):
        t_ms = f * 1000.0 / fps
        frame = bg.copy()
        for cx, s, (o, n) in views:
            for r, (seq, frame_ms) in enumerate(((o, msec), (n, msec / step))):
                img = seq[int(t_ms / frame_ms) % len(seq)]
                x = round(cx - (fw / 2 - union[0]) * s)
                y = round(ground[r] - 10 - (fh - ground_margin - union[1]) * s)
                frame.alpha_composite(img, (max(0, x), max(0, y)))
        proc.stdin.write(frame.convert("RGB").tobytes())
    proc.stdin.close()
    if proc.wait():
        raise RuntimeError(f"ffmpeg failed writing {path}")


def run_unit(row, args, sources, interp, weights_sha):
    uid = row["unit_id"]
    seconds = {}
    clock = time.perf_counter()
    recipe = idle_recipe(row)
    frames, canvas, scale = aligned_frames(recipe, sources)
    seconds["read_and_align"] = time.perf_counter() - clock
    k = max(0, round(recipe["msec"] / TARGET_MSEC) - 1) if args.inbetweens == "auto" else int(args.inbetweens)

    clock = time.perf_counter()
    out, checks = loop_with_inbetweens(frames, k, args.coarse, args.flagged, interp)
    seconds["rife"] = time.perf_counter() - clock
    for i, check in enumerate(checks):  # the source frames already fit; trim only in-betweens
        index = (i // k) * (k + 1) + i % k + 1
        check["cell_clipped_px"] = fit_to_cell(out[index], canvas, scale, recipe["frame_size"], recipe["ground_margin"])

    clock = time.perf_counter()
    unit_dir = args.out / uid
    unit_dir.mkdir(parents=True, exist_ok=True)
    for stale in ("flagged.jpg", "review.mp4"):
        (unit_dir / stale).unlink(missing_ok=True)
    write_loop(uid, recipe, out, canvas, scale, unit_dir)
    cells = runtime_cells(unit_dir, recipe["frame_size"], len(out))
    flagged = sorted({c["pair"] for c in checks if c["flag"]}, key=lambda p: int(p.split("->")[0]))
    if flagged:
        write_flagged_strip(unit_dir, recipe["frame_size"], cells, flagged, k)
    seconds["pack"] = time.perf_counter() - clock
    if args.review:
        clock = time.perf_counter()
        write_review(row, unit_dir, recipe["frame_size"], recipe["ground_margin"], cells, k + 1, unit_dir / "review.mp4")
        seconds["review"] = time.perf_counter() - clock

    report = {"unit_id": uid, "source": recipe["from"], "mirrored": recipe["flip"], "source_frames": len(frames),
              "source_msec": recipe["msec"],
              "inbetweens_per_pair": k, "frames": len(out), "frame_msec": round(recipe["msec"] / (k + 1), 1),
              "canvas": list(canvas[:2]), "coarse_mode": args.coarse, "flagged_handling": args.flagged,
              "weights_sha256": weights_sha,
              "seconds": {key: round(v, 2) for key, v in seconds.items()},
              "flagged_pairs": flagged, "inbetweens": checks}
    (unit_dir / "report.json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("unit_ids", nargs="*", help="unit ids from content/unit_animation_manifest.json")
    parser.add_argument("--all", action="store_true", help="every unit in the animation manifest")
    parser.add_argument("--out", type=Path, required=True, help="output directory; one folder per unit")
    parser.add_argument("--inbetweens", default="auto",
                        help=f"frames added per pair, or auto: about {TARGET_MSEC} ms per frame at the idle's timing")
    parser.add_argument("--flagged", default="hold", choices=["hold", "keep"],
                        help="pairs that still smear: hold the paintings and snap halfway (default), or keep the in-betweens")
    parser.add_argument("--coarse", default="auto", choices=["auto", "always", "never"],
                        help="coarse flow start: auto retries smeared pairs with it")
    parser.add_argument("--archive-dir", type=Path, default=os.environ.get("HEROES_SOURCE_ARCHIVE") or None,
                        help="source-art snapshot for sources not restored here (default: $HEROES_SOURCE_ARCHIVE)")
    parser.add_argument("--weights", type=Path, default=os.environ.get("HEROES_RIFE_WEIGHTS") or DEFAULT_WEIGHTS,
                        help=f"RIFE v4.26 safetensors (default: $HEROES_RIFE_WEIGHTS or {DEFAULT_WEIGHTS})")
    parser.add_argument("--device", default=None, help="torch device (default: cuda when available, else cpu)")
    parser.add_argument("--review", action="store_true", help="also write review.mp4: current idle above the new loop")
    args = parser.parse_args(argv)
    if args.inbetweens != "auto" and not args.inbetweens.isdigit():
        parser.error("--inbetweens takes a whole number or auto")
    if bool(args.unit_ids) == args.all:
        parser.error("give unit ids or --all")
    rows = {r["unit_id"]: r for r in json.loads(MANIFEST.read_text(encoding="utf-8"))["items"]}
    unknown = [u for u in args.unit_ids if u not in rows]
    if unknown:
        parser.error("not in the animation manifest: " + ", ".join(unknown))
    if not args.weights.is_file():
        raise SystemExit(f"RIFE weights not found at {args.weights}.\nDownload {WEIGHTS_URL}\n"
                         "and put it there, or pass --weights. See docs/idle-inbetweens.md.")

    import torch

    device = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    weights_sha = hashlib.sha256(args.weights.read_bytes()).hexdigest()
    interp = Interpolator(args.weights, device)
    sources = Sources(args.archive_dir)
    args.out.mkdir(parents=True, exist_ok=True)
    done, skipped, failed = [], {}, {}
    ran = sorted(rows) if args.all else args.unit_ids
    for uid in ran:
        try:
            report = run_unit(rows[uid], args, sources, interp, weights_sha)
        except SkipUnit as reason:
            skipped[uid] = str(reason)
            print(f"SKIP {uid}: {reason}")
            continue
        except Exception as error:  # a batch records the failure and goes on
            if not args.all:
                raise
            failed[uid] = f"{type(error).__name__}: {error}"
            print(f"FAIL {uid}: {failed[uid]}")
            continue
        done.append({key: report[key] for key in ("unit_id", "source_frames", "frames", "frame_msec", "flagged_pairs")})
        flags = ", ".join(report["flagged_pairs"]) or "none"
        print(f"OK {uid}: {report['source_frames']} -> {report['frames']} frames at {report['frame_msec']} ms, "
              f"RIFE {report['seconds']['rife']} s, flagged pairs ({args.flagged}): {flags}")
    # The summary covers every unit in the folder; a later run updates the units it redid.
    summary_path = args.out / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8")) if summary_path.is_file() else {}
    units = {u["unit_id"]: u for u in summary.get("units", []) if u["unit_id"] not in ran}
    units.update({u["unit_id"]: u for u in done})
    keep = lambda old, new: dict(sorted({**{u: r for u, r in old.items() if u not in ran}, **new}.items()))
    summary = {"device": device, "weights_sha256": weights_sha, "flagged_handling": args.flagged,
               "units": [units[u] for u in sorted(units)],
               "skipped": keep(summary.get("skipped", {}), skipped), "failed": keep(summary.get("failed", {}), failed)}
    summary_path.write_text(json.dumps(summary, indent=1) + "\n", encoding="utf-8")
    flagged = sum(1 for u in done if u["flagged_pairs"])
    print(f"IDLE_INBETWEENS done={len(done)} flagged_units={flagged} skipped={len(skipped)} failed={len(failed)} out={args.out}")
    return 1 if failed or (skipped and not args.all) else 0


if __name__ == "__main__":
    sys.exit(main())
