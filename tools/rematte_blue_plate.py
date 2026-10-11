#!/usr/bin/env python3
"""Clean the edges of fluid creature clips that were filmed on a blue backdrop.

  python tools/rematte_blue_plate.py UNIT_ID [UNIT_ID ...] --archive-dir DIR [--publish]
  python tools/rematte_blue_plate.py --all --archive-dir DIR [--publish]

The blue-plate matte in the per-unit produce.py scripts measured how much backdrop
is mixed into a pixel as blue minus max(red, green). On red or orange parts red
wins, so blue mixed into edge pixels was taken for foreground and kept: thin red
parts and outlines came out purple-pink (owner report, 2026-10-11, the Stag-Knot
Runners' antlers).

For every published frame from a blue-plate take this tool:
1. Runs the script that keyed the take (the unit's produce.py, or the take's own
   for early video trials) on its lossless original from the source archive, in a
   scratch folder, and checks every published frame against the archived matte
   pixel for pixel. A unit whose old matte does not reproduce is skipped.
2. Re-solves only the edge band: semi-transparent pixels and opaque pixels within
   EDGE_PX source pixels of them that still hold blue. Such a pixel takes the
   colour of the nearest clean opaque pixel (no blue beyond the unit's own
   palette: blue minus green at most just above the bluest colour of its painted
   idle), and its opacity is the share of that colour between the plate and it;
   opacity may only go down. Pixels with no clean neighbour nearby are unmixed
   against the plate instead. Inside the figure every pixel stays as reviewed,
   so bluish highlights cannot turn into holes. A take filmed on a cyan-tinted
   plate, where blue minus green cannot tell plate from figure, is left as it is.
3. Writes the frames to <take>/matte_blue_edges/ (ignored source media, rebuilt
   by running this tool again) and records the recipe and hashes in
   <take>/matte_blue_edges.json.

--publish then points the unit's reviewed handoff at the new frames, restores the
unit's other archived sources, republishes it with
tools/publish_fluid_creature_animation.py, registers the new atlas in
docs/battle-unit-animation-acceptance.json and removes the restored sources again.
Frame selection, timing, anchors and scale do not change.

Needs numpy, scipy, Pillow and PyAV (the decoder the original takes used).
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import inspect
import io
import json
import math
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion, distance_transform_edt, label

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from integrate_fluid_creature_animation import old_pose, read  # noqa: E402
from restore_archived_source_material import load_index, restore  # noqa: E402

MANIFEST = ROOT / "content/unit_animation_manifest.json"
REGISTER = ROOT / "docs/battle-unit-animation-acceptance.json"
FLUID = ROOT / "art/animation/source/fluid"
BLUE = "flat_blue_chroma_unmix"
TOOL = "tools/rematte_blue_plate.py"
OUTPUT = "matte_blue_edges"  # <take>/matte_blue_edges/ frames, <take>/matte_blue_edges.json record
EDGE_PX = 2           # source pixels inside the cut-out edge that are re-solved
REACH = 3             # source pixels an edge pixel may take its colour from
MIN_PLATE_DISTANCE = 80  # colours closer than this to the plate are unmixed instead
RECIPE_VERSION = 1    # bump when clean_edges() changes, so earlier frames are rebuilt
PALETTE_MARGIN = 6    # threshold above the painted idle's bluest colour (p99.9)
MIN_THRESHOLD = 6


def write(path, value, compact=False):
    path.write_text(json.dumps(value, indent=None if compact else 2,
                               separators=(",", ":") if compact else None) + "\n", encoding="utf-8", newline="\n")


def sha(data):
    return hashlib.sha256(data).hexdigest()


class Archive:
    """Archived source files by repository-relative path, checked against the manifest."""

    def __init__(self, directory):
        self.directory = directory
        self.rows = load_index(directory)
        self.zips = {}

    def read(self, rel):
        row = self.rows.get(rel)
        if row is None:
            raise FileNotFoundError(f"{rel} is not in the source archive")
        if row["archive"] not in self.zips:
            self.zips[row["archive"]] = zipfile.ZipFile(self.directory / row["archive"])
        data = self.zips[row["archive"]].read(rel)
        if sha(data) != row["sha256"]:
            raise RuntimeError(f"archive payload failed its SHA-256 check: {rel}")
        return data


def blue_frames(handoff):
    """{take directory: {frame number: [handoff frame index, ...]}} for the published
    frames that produce.py keyed off a blue plate (a take can switch plates), whether
    they still point at the old matte/ or already at this tool's frames."""
    takes, records = {}, {}
    for index, frame in enumerate(handoff["frames"]):
        source = Path(frame["source"].removeprefix("res://"))
        take = source.parent.parent
        if source.parent.name not in ("matte", OUTPUT) or not (ROOT / take / "matte.json").is_file():
            continue
        if take not in records:  # mattes from other recipes have no per-frame backdrop record
            records[take] = read(ROOT / take / "matte.json").get("background_frames", [])
        number = int(source.stem.split("_")[1])
        detail = records[take][number] if number < len(records[take]) else None
        if isinstance(detail, dict) and detail.get("mode") == BLUE:
            takes.setdefault(take.as_posix(), {}).setdefault(number, []).append(index)
    return takes


def produce_path(take):
    """The script that keyed a take: its own produce.py (early video trials), else its unit's."""
    own = ROOT / take / "produce.py"
    return own if own.is_file() else ROOT / Path(take).parent / "produce.py"


def produce_module(path):
    spec = importlib.util.spec_from_file_location(f"produce_{path.parent.name}", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def old_mattes(module, take, video, wanted):
    """{frame number: (raw RGB, old RGBA)} for the wanted frames, from the unit's own
    produce.py process() run on a scratch copy of the take, so every per-take setting
    (extraction_settings.json, reviewed key ranges, chroma axis) applies as it did.
    Frames that are not wanted are not keyed."""
    recorded = read(ROOT / take / "matte.json")
    keyed = iter([i for i, h in enumerate(recorded["rgba_sha256"]) if h])  # process() keys these, in order
    captured, original = {}, module.key

    def key(rgb, *config):
        number = next(keyed)
        if number not in wanted:
            return Image.new("RGBA", (1, 1)), dict(recorded["background_frames"][number])
        image, detail = original(rgb, *config)
        captured[number] = (rgb, image, detail)
        return image, detail

    module.key = key
    try:
        with tempfile.TemporaryDirectory(prefix="rematte-take-") as tmp:
            for name in ("config.json", "extraction_settings.json", "extract_ranges.json"):
                if (ROOT / take / name).is_file():
                    shutil.copyfile(ROOT / take / name, Path(tmp) / name)
            (Path(tmp) / "original_lossless.mkv").write_bytes(video)
            if inspect.signature(module.process).parameters:
                module.process(Path(tmp), read(ROOT / take / "config.json"))
            else:  # early video trials key their own folder, OUT, with the settings in the script
                folder, module.OUT = module.OUT, Path(tmp)
                try:
                    module.process()
                finally:
                    module.OUT = folder
    finally:
        module.key = original
    if set(captured) != set(wanted):
        raise ValueError(f"{take}: process() keyed {len(captured)} of {len(wanted)} published frames")
    return captured


def palette_threshold(row):
    """Bluest colour of the unit's painted idle, as blue minus green (p99.9), plus a margin."""
    atlas = Image.open(ROOT / row["pose_sheet"].removeprefix("res://")).convert("RGBA")
    idle = row["pose_clips"]["idle"]
    values = []
    for index in idle.get("from_atlas", idle)["indices"]:
        pixels = np.asarray(old_pose(atlas, row, index)[0]).astype(int)
        inner = binary_erosion(pixels[..., 3] >= 240, iterations=3)
        values.append(pixels[inner][:, 2] - pixels[inner][:, 1])
    measured = float(np.percentile(np.concatenate(values), 99.9))
    return max(MIN_THRESHOLD, math.ceil(measured) + PALETTE_MARGIN), measured


class NotBluePlate(ValueError):
    """A take filmed on a cyan or green-tinted plate: blue minus green cannot separate it."""


def plate(a):
    # Same corner-median plate as produce.py key().
    tiles = [a[:24, :24], a[:24, -24:], a[-24:, :24], a[-24:, -24:]]
    return np.median(np.array([np.median(t.reshape(-1, 3), axis=0) for t in tiles]), axis=0)


def clean_edges(rgb, old, threshold):
    """Re-solve the edge band of an old blue-plate matte; returns (RGBA image, stats).

    The generated videos bleed at the figure's edge: a pixel there mixes the plate
    with a colour more saturated than the figure's own, so unmixing it with the
    plate alone leaves a bright rim. A band pixel within REACH source pixels of a
    clean opaque pixel therefore takes that pixel's colour, and its opacity is the
    share of that colour along the line from the plate to it. Further out (wide
    translucent parts) it is unmixed against the plate with blue measured against
    green, and leftover blue is clamped."""
    a = np.asarray(rgb, dtype=np.float32)
    out = np.asarray(old).astype(np.float32)
    alpha_old = out[..., 3] / 255.0
    bg = plate(a)
    separation = bg[2] - bg[1]
    if separation - threshold < 80:
        raise NotBluePlate(f"the plate {bg.round(1).tolist()} is not blue enough to measure against green")
    band = (alpha_old > 0) & (distance_transform_edt(alpha_old >= 0.98) <= EDGE_PX)
    clean = (alpha_old >= 0.98) & (a[..., 2] - a[..., 1] <= threshold)
    fix = band & ~clean
    distance, (iy, ix) = distance_transform_edt(~clean, return_indices=True)
    near = a[iy, ix]
    toward = near - bg
    length = (toward * toward).sum(-1)
    alpha_near = np.clip(((a - bg) * toward).sum(-1) / np.maximum(length, 1), 0, 1)
    alpha_plate = np.clip((separation - (a[..., 2] - a[..., 1])) / (separation - threshold), 0, 1)
    use_near = fix & (distance <= REACH) & (length >= MIN_PLATE_DISTANCE ** 2)
    alpha = alpha_old.copy()
    alpha[fix] = np.minimum(alpha_old, np.where(use_near, alpha_near, alpha_plate))[fix]
    color = np.clip((a - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], 0.001), 0, 255)
    color[..., 2] = np.minimum(color[..., 2], color[..., 1] + threshold)
    color[use_near] = near[use_near]
    out[fix, :3] = color[fix]
    out[fix, 3] = alpha[fix] * 255
    out = out.astype("uint8")
    out[out[..., 3] < 8] = 0
    # Same component rule as key(): keep alpha>=8 regions that hold an alpha>=128 pixel.
    labels, count = label(out[..., 3] >= 8, structure=np.ones((3, 3), dtype=np.uint8))
    keep = np.zeros(count + 1, dtype=bool)
    keep[np.unique(labels[out[..., 3] >= 128])] = True
    keep[0] = False
    out[~keep[labels]] = 0
    removed = float((alpha_old - out[..., 3] / 255.0).clip(0).sum() / max(1.0, alpha_old.sum()))
    return Image.fromarray(out, "RGBA"), {"fixed_pixels": int(fix.sum()), "opacity_removed": round(removed, 5)}


def up_to_date(prior, recipe, out_dir, wanted):
    """True when an earlier run with the same recipe left every wanted frame unchanged."""
    hashes = prior.get("rgba_sha256", {})
    if prior.get("recipe") != recipe or set(hashes) != {f"{n:03}" for n in wanted}:
        return False
    for number in wanted:
        path = out_dir / f"rgba_{number:03}.png"
        if not path.is_file() or sha(path.read_bytes()) != hashes[f"{number:03}"]:
            return False
    return True


def rematte_unit(uid, row, archive, log):
    handoff = read(FLUID / uid / "reviewed_handoff.json")["units"][0]
    takes = blue_frames(handoff)
    if not takes:
        return None
    threshold, measured = palette_threshold(row)
    modules, new_sources = {}, {}
    for take, wanted in sorted(takes.items()):
        script = produce_path(take)
        if script not in modules:
            modules[script] = produce_module(script)
        out_dir = ROOT / take / OUTPUT
        record = ROOT / take / f"{OUTPUT}.json"
        recipe = {"version": RECIPE_VERSION, "edge_px": EDGE_PX, "reach_px": REACH,
                  "min_plate_distance": MIN_PLATE_DISTANCE, "threshold": threshold}
        prior = None
        if record.is_file():
            prior = read(record)
            if prior.get("tool") != TOOL:
                raise ValueError(f"{record} belongs to another tool")
            if up_to_date(prior, recipe, out_dir, wanted):
                for number, indices in wanted.items():
                    for index in indices:
                        new_sources[index] = (out_dir / f"rgba_{number:03}.png").relative_to(ROOT).as_posix()
                log(f"  {Path(take).name}: {len(wanted)} frames up to date")
                continue
        recorded = read(ROOT / take / "matte.json")["rgba_sha256"]
        video_rel = f"{take}/original_lossless.mkv"
        video = archive.read(video_rel)
        cleaned = {}
        try:
            for number, (rgb, old, detail) in sorted(old_mattes(modules[script], take, video, wanted).items()):
                rel = f"{take}/matte/rgba_{number:03}.png"
                if detail["mode"] != BLUE or archive.rows[rel]["sha256"] != recorded[number]:
                    raise ValueError(f"{rel}: not the recorded blue-plate matte")
                if not np.array_equal(np.asarray(old), np.asarray(Image.open(io.BytesIO(archive.read(rel))).convert("RGBA"))):
                    raise ValueError(f"{rel}: produce.py does not reproduce the archived matte")
                cleaned[number] = clean_edges(rgb, old, threshold)
        except NotBluePlate as error:
            log(f"  {Path(take).name}: left as it is, {error}")
            continue
        out_dir.mkdir(exist_ok=True)
        hashes, stats = {}, []
        for number, (image, stat) in cleaned.items():
            path = out_dir / f"rgba_{number:03}.png"
            image.save(path)
            hashes[f"{number:03}"] = sha(path.read_bytes())
            stats.append(stat["opacity_removed"])
            for index in wanted[number]:
                new_sources[index] = path.relative_to(ROOT).as_posix()
        write(record, {
            "tool": TOOL,
            "reason": "Blue-plate edges re-solved: the old blue minus max(red, green) matte kept blue in "
                      "red edges as purple (owner report 2026-10-11); edge pixels now take the nearest "
                      "clean colour and only their opacity is solved.",
            "original": {"path": video_rel, "sha256": sha(video)},
            "old_matte": "this unit's produce.py process() on the original; every published frame "
                         "reproduced the archived matte/ frame exactly",
            "recipe": recipe,
            "threshold_source": f"painted idle blue minus green p99.9 = {measured:.1f}, plus {PALETTE_MARGIN}",
            "opacity_removed_mean": round(float(np.mean(stats)), 5), "opacity_removed_max": round(float(np.max(stats)), 5),
            "rgba_sha256": hashes,
        })
        log(f"  {Path(take).name}: {len(hashes)} frames, opacity removed mean {np.mean(stats):.2%} max {np.max(stats):.2%}")
        if prior and prior.get("recipe") == recipe:  # a rebuild of frames recorded earlier
            same = sum(prior["rgba_sha256"].get(k) == v for k, v in hashes.items())
            log(f"    rebuilt: {same} of {len(hashes)} frames match the recorded SHA-256"
                + ("" if same == len(hashes) else " (library versions differ?); the record now holds the new hashes"))
    return {"handoff": handoff, "new_sources": new_sources, "threshold": threshold, "takes": sorted(takes)}


def publish_unit(uid, result, archive, log):
    import publish_fluid_creature_animation as publisher

    handoff = copy.deepcopy(result["handoff"])
    changed = {i for i, source in result["new_sources"].items()
               if handoff["frames"][i]["source"].removeprefix("res://") != source}
    if not changed:
        log("  already published")
        return
    for index in changed:
        handoff["frames"][index]["source"] = result["new_sources"][index]
    # Republish only the clips that changed: an unchanged idle keeps its RIFE loop sheet.
    clips = [name for name, spec in handoff["clips"].items() if set(spec["indices"]) & changed]
    # The packer reads every source from the checkout: restore the rest from the archive.
    needed = sorted({f["source"].removeprefix("res://") for f in handoff["frames"]} - set(result["new_sources"].values())
                    | {f"art/animation/source/fluid/{uid}/baseline.png"})
    missing = [p for p in needed if not (ROOT / p).exists()]
    counts = restore(ROOT, archive.directory, archive.rows, missing, True)
    if counts["conflict"] or counts["restored"] != len(missing):
        raise RuntimeError(f"restore failed: {counts}")
    try:
        note = ("Blue-backdrop edges re-solved with tools/rematte_blue_plate.py (2026-10-11): purple fringes from "
                "the old blue-minus-max(red, green) matte removed; frames, timing, anchors and scale unchanged. "
                "Earlier review: " + result["handoff"]["visual_review"]["notes"])
        with tempfile.TemporaryDirectory(prefix="rematte-") as tmp:
            path = Path(tmp) / "handoff.json"
            write(path, {"schema_version": 1, "units": [handoff]})
            publisher.publish(path, clips, note, handoff.get("preserved_accepted_clips", []))
        register(uid)
    finally:
        for rel in missing:  # restored copies are byte-identical to the archive
            (ROOT / rel).unlink(missing_ok=True)
    log(f"  published {', '.join(clips)}; restored and removed {len(missing)} archived sources")
    if "idle" in clips:
        log("  the idle changed: its RIFE loop was dropped; rebuild it with tools/idle_inbetweens.py "
            "and tools/integrate_idle_inbetweens.py")


def register(uid):
    catalog, evidence = read(MANIFEST), read(REGISTER)
    row = next(r for r in catalog["items"] if r["unit_id"] == uid)
    accepted = next(u for u in evidence["units"] if u["unit_id"] == uid)
    row["pose_review_status"] = accepted.get("review_status", evidence["status"])
    row["pose_review_evidence"] = "docs/battle-unit-animation-acceptance.json"
    pose = {k: v for k, v in row.items() if k.startswith("pose_") and not k.startswith("pose_review_")}
    accepted["atlas_sha256"] = sha((ROOT / row["pose_sheet"].removeprefix("res://")).read_bytes())
    accepted["pose_metadata_sha256"] = sha(json.dumps(pose, sort_keys=True, separators=(",", ":")).encode())
    accepted["accepted_clips"] = row["pose_accepted_clips"]
    write(MANIFEST, catalog, compact=True)
    write(REGISTER, evidence)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("unit_ids", nargs="*")
    parser.add_argument("--all", action="store_true", help="every unit with a published blue-plate frame")
    parser.add_argument("--archive-dir", type=Path, default=os.environ.get("HEROES_SOURCE_ARCHIVE"),
                        help="source archive snapshot (default: HEROES_SOURCE_ARCHIVE)")
    parser.add_argument("--publish", action="store_true", help="republish and register the cleaned units")
    args = parser.parse_args(argv)
    if args.archive_dir is None:
        parser.error("pass --archive-dir or set HEROES_SOURCE_ARCHIVE")
    rows = {row["unit_id"]: row for row in read(MANIFEST)["items"]}
    ids = [u for u in rows if (FLUID / u / "reviewed_handoff.json").is_file()] if args.all else args.unit_ids
    unknown = [u for u in ids if u not in rows]
    if not ids or unknown:
        parser.error(f"unknown unit ids: {unknown}" if unknown else "name units or pass --all")
    archive = Archive(Path(args.archive_dir))
    failed, done = [], 0
    for uid in ids:
        try:
            if args.all and not blue_frames(read(FLUID / uid / "reviewed_handoff.json")["units"][0]):
                continue
            print(uid, flush=True)
            result = rematte_unit(uid, rows[uid], archive, lambda m: print(m, flush=True))
            if result is None:
                print("  no blue-plate frames")
                continue
            if args.publish:
                publish_unit(uid, result, archive, lambda m: print(m, flush=True))
                rows = {row["unit_id"]: row for row in read(MANIFEST)["items"]}
            done += 1
        except Exception as error:  # report and continue with the next unit
            failed.append(uid)
            print(f"  FAILED {type(error).__name__}: {error}", flush=True)
    print(f"done {done}, failed {len(failed)}: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
