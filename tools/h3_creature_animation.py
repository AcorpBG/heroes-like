#!/usr/bin/env python3
"""Animate one creature with local MiniMax H3 video, from its painted poses to a candidate handoff.

The shared form of the per-unit produce.py / stage_video.py / prepare.py copies.
A unit is described by <unit_dir>/h3_unit.json:

  unit_id, identity (prompt text), plate (prompt text), canvas [w, h], scale (runtime px
  per video px), key_rgb ([0, 0, 255], or [0, 255, 0] for a palette full of blue), seed,
  optional anchor [x, y] and tiled_decode, and "takes":
  {take_name: {clip, references: [painted frame names], guides: [[video_frame, ref]],
  last: ref, action: prompt text, optional pad [left, top, right, bottom]}}. Append new
  takes (retakes too) at the end: a take's seed is the unit seed plus its position. pad
  widens one take's canvas (multiples of 32) where its swing leaves the unit canvas; the
  figure keeps its anchor and scale.

References name frames of the unit's live reviewed handoff
(art/animation/source/fluid/<unit>/reviewed_handoff.json), so each guide is an accepted
painting at its accepted anchor and scale. One anchor and scale serve every take of a
unit; prepare fits them once (h3_layout.json). Run with a Python that has Pillow, NumPy,
SciPy and PyAV; the ComfyUI service is http://127.0.0.1:8189 unless --url says otherwise.

  survey   UNIT_ID             before writing h3_unit.json: restore the painted sources
                               (--archive-dir), draw every painted frame by clip with its
                               name and suggest a scale
  prepare  UNIT_DIR [TAKE...]  guides, prompts and graphs for takes not prepared yet
                               (an idle prints how far its poses sit from the neutral)
  generate UNIT_DIR [TAKE...]  queue every sampling job, free the models, queue the decodes;
                               then collect lossless originals, matte and draw review sheets;
                               --batch UNIT_DIR... adds other prepared units to the same run
  enqueue  UNIT_DIR [TAKE...]  prepare, then leave a request for the runner (--join: add to
                               the group it is sampling, e.g. retakes)
  run                          the runner: keeps the GPU busy across units. When a group's
                               samplings are done it frees the models once, queues the
                               group's decodes and the next group's samplings behind them,
                               then collects, mattes and draws this group while the GPU
                               samples the next. Prints READY <unit> for review.
  matte    UNIT_DIR TAKE...    matte again: blue-plate unmix plus the edge rule of
                               tools/rematte_blue_plate.py (no purple rim on red edges)
  sheets   UNIT_DIR TAKE...    chronological review sheets under .artifacts/h3/<unit>/;
                               --frames 28-40,88 draws a close-up sheet of just those frames
  propose  UNIT_DIR [TAKE...]  a starting h3_selection.json from the motion in the matte
                               frames; named takes update just their clips
  fit      UNIT_DIR            thin the action clips, holds first, until every pose packs
                               into one 4096 px atlas as the publisher packs it
  build    UNIT_DIR            candidate handoff.json from h3_selection.json
  profile  UNIT_DIR            stage timings of every take

Every stage adds its seconds to <take>/timing.json; GPU times come from the job history.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
import math
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import av
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion, label

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from integrate_fluid_creature_animation import clip_indices, old_pose, pack_compact, source_pose  # noqa: E402
from rematte_blue_plate import clean_edges  # noqa: E402

FRAMES, FPS = 124, 24
UNET = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TEXT = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VAE = "minimax_h3_video_vae_int8_convrot.safetensors"
TILED_DECODE = {"tile_size": 512, "overlap": 64, "temporal_size": 16, "temporal_overlap": 4}
MARGIN = 24          # free pixels every guide keeps from the canvas edge
UNMIX_MARGIN = 2     # protected foreground chroma: bluest opaque guide pixel plus this
EDGE_MARGIN = 6      # edge-rule thresholds: guide blue-minus-green (and, green plate, plate chroma) p99.9 plus this
PLATE_SEPARATION = 243  # a sampled plate's key channel minus the edge rule's other channel (242-246 measured)
IDLE_POSE_FAR = 17   # pose distance above which a three-guide idle holds each pose and pops between them
URL = "http://127.0.0.1:8189"
QUEUE = ROOT / ".artifacts/h3/queue"


def read(path):
    return json.loads(Path(path).read_bytes())


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def node(kind, **inputs):
    return {"class_type": kind, "inputs": inputs}


def call(route, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(URL + route, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as response:
        raw = response.read()
    return json.loads(raw) if raw.strip() else {}  # /free answers with an empty body


def fetch(item):
    query = urllib.parse.urlencode({k: item[k] for k in ("filename", "subfolder", "type") if k in item})
    with urllib.request.urlopen(URL + "/view?" + query, timeout=300) as response:
        return response.read()


def timed(take_dir, stage, seconds):
    path = take_dir / "timing.json"
    timing = read(path) if path.exists() else {}
    timing[stage] = round(timing.get(stage, 0) + seconds, 3)
    write(path, timing)


def drop_slivers(pose, share=0.02):
    """Clear the opaque pieces detached from the figure and smaller than share of its largest piece.
    A painted crop can carry a sliver of the neighbouring pose, which the video then animates as a
    loose object; h3_unit.json "clean_references" names the references that need this."""
    rgba = np.array(pose.convert("RGBA"))
    labels, count = label(rgba[..., 3] >= 8, structure=np.ones((3, 3), dtype=np.uint8))
    if count < 2:
        return pose
    sizes = np.bincount(labels.ravel())[1:]
    keep = np.concatenate([[False], sizes >= share * sizes.max()])
    rgba[~keep[labels]] = 0
    return Image.fromarray(rgba, "RGBA")


def published_away(unit_dir, live, names):
    """Painted frames a publish replaced in the live handoff, so a retake after publishing can
    still be guided by them: read from painted_frames.json, or found in the live handoff's git
    history, newest first, and saved there."""
    cache = unit_dir / "painted_frames.json"
    found = read(cache) if cache.exists() else {}
    missing = set(names) - found.keys()
    if missing:
        path = rel(live)
        log = subprocess.run(["git", "log", "--format=%H", "--", path], cwd=ROOT, capture_output=True, text=True, check=True)
        for commit in log.stdout.split():
            old = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=ROOT, capture_output=True, check=True)
            for frame in json.loads(old.stdout)["units"][0]["frames"]:
                if frame["name"] in missing:
                    found[frame["name"]] = frame
            missing -= found.keys()
            if not missing:
                break
        if missing:
            raise SystemExit(f"painted frames not in the live handoff or its history: {sorted(missing)}")
        write(cache, dict(sorted(found.items())))
    return {name: found[name] for name in names}


class Unit:
    def __init__(self, directory):
        self.dir = Path(directory).resolve()
        self.cfg = read(self.dir / "h3_unit.json")
        self.id = self.cfg["unit_id"]
        live = ROOT / "art/animation/source/fluid" / self.id / "reviewed_handoff.json"
        self.live = read(live)["units"][0]
        self.painted = {f["name"]: f for f in self.live["frames"]}
        wanted = {name for spec in self.cfg["takes"].values() for name in spec["references"]}
        if wanted - self.painted.keys():
            self.painted.update(published_away(self.dir, live, wanted - self.painted.keys()))
        self.canvas = tuple(self.cfg.get("canvas", [960, 640]))
        self.scale = float(self.cfg["scale"])

    def takes(self, names=None):
        names = names or list(self.cfg["takes"])
        unknown = [n for n in names if n not in self.cfg["takes"]]
        if unknown:
            raise SystemExit(f"not in h3_unit.json: {unknown}")
        return names

    def guide_pose(self, name):
        """A painted frame at video scale, and its offset from the anatomical anchor."""
        frame = dict(self.painted[name])
        frame["scale"] = frame["scale"] / self.scale
        # A painting smaller than the video is enlarged as a whole, never per pose.
        grow = max(1.0, frame["scale"])
        pose, (x, y) = source_pose(dict(frame, scale=frame["scale"] / grow), frame.get("alpha_noise_cutoff", 8))
        if name in self.cfg.get("clean_references", []):
            pose = drop_slivers(pose)
        if grow > 1:
            pose = pose.resize((round(pose.width * grow), round(pose.height * grow)), Image.Resampling.LANCZOS)
            x, y = round(x * grow), round(y * grow)
        return pose, (x, y)

    def layout(self):
        """One anchor for every take: the union of all guides, centred, MARGIN from each edge."""
        path = self.dir / "h3_layout.json"
        boxes = {}
        for spec in self.cfg["takes"].values():
            for name in spec["references"]:
                if name not in boxes:
                    pose, (x, y) = self.guide_pose(name)
                    boxes[name] = (x, y, x + pose.width, y + pose.height)
        left, top = min(b[0] for b in boxes.values()), min(b[1] for b in boxes.values())
        right, bottom = max(b[2] for b in boxes.values()), max(b[3] for b in boxes.values())
        if path.exists():
            anchor = read(path)["anchor"]
        else:
            w, h = self.canvas
            anchor = self.cfg.get("anchor") or [round((w - (right - left)) / 2 - left), round((h - (bottom - top)) / 2 - top)]
            write(path, {"anchor": anchor, "guide_union_from_anchor": [left, top, right, bottom], "canvas": list(self.canvas),
                         "scale": self.scale, "rule": "Every guide of every take, centred once; later takes keep this anchor."})
        w, h = self.canvas
        room = [anchor[0] + left, anchor[1] + top, w - anchor[0] - right, h - anchor[1] - bottom]
        if min(room) < MARGIN:
            raise SystemExit(f"guides leave {room} px to the canvas edges (left, top, right, bottom); lower scale or widen canvas")
        return anchor, room


GREEN_ORDER = [0, 2, 1]


def key_order(key_rgb):
    """Channel order that puts the plate's channel last, so the blue-plate rules key it.

    A blue plate keeps RGB. A green plate, for a unit whose palette is full of blue (ice,
    crystal), swaps green and blue: the unmix measures green against max(red, blue) and the
    edge rule green against blue, which blue, cyan and violet parts never approach."""
    order = {(0, 0, 255): [0, 1, 2], (0, 255, 0): GREEN_ORDER}.get(tuple(key_rgb))
    assert order, f"key_rgb {key_rgb}: only a blue or a green plate is supported"
    return order


def measure(guides, order):
    """Plate colour in the painted palette: the unmix guard band, the edge-rule threshold and,
    used on a green plate only, the edge rule's spill limit (plate chroma p99.9 plus EDGE_MARGIN)."""
    values, chromas = [], []
    for rgba in guides:
        a = np.asarray(rgba).astype(float)[..., order + [3]]
        inner = binary_erosion(a[..., 3] > 240, iterations=3)
        chromas.append((a[..., 2] - np.maximum(a[..., 0], a[..., 1]))[inner])
        values.append(a[..., 2][inner] - a[..., 1][inner])
    worst = max(0.0, *(float(c.max()) for c in chromas))
    p999 = float(np.percentile(np.concatenate(values), 99.9))
    chroma_p999 = float(np.percentile(np.concatenate(chromas), 99.9))
    return (max(0, int(worst) + UNMIX_MARGIN), max(6, math.ceil(p999) + EDGE_MARGIN), max(6, math.ceil(chroma_p999) + EDGE_MARGIN),
            {"bluest_opaque": worst, "blue_minus_green_p999": p999, "bluest_p999": chroma_p999})


def guide_image(unit, frame_name, canvas, at):
    """A painted pose placed on the take's canvas at its anchor, as prepare gives it to the video."""
    pose, (x, y) = unit.guide_pose(frame_name)
    rgba = Image.new("RGBA", tuple(canvas))
    rgba.alpha_composite(pose, (at[0] + x, at[1] + y))
    return rgba


def pose_distance(a, b):
    """How far apart two guides sit: mean premultiplied colour difference plus half the mean
    opacity difference, at quarter size. Smooth three-guide idles measured 5.4 and 16.2; those
    that held each pose for about 20 frames and popped between them, 18.2 to 23.6."""
    def lit(im):
        x = np.asarray(im.resize((im.width // 4, im.height // 4), Image.Resampling.BILINEAR)).astype(np.float32)
        return x[..., :3] * x[..., 3:] / 255, x[..., 3]
    (ca, aa), (cb, ab) = lit(a), lit(b)
    return float(np.abs(ca - cb).mean() + np.abs(aa - ab).mean() / 2)


def prepare(unit, names, refresh=False):
    """refresh: prepare again, from the current h3_unit.json, takes the runner has not submitted yet."""
    anchor, room = unit.layout()
    for n, name in enumerate(unit.takes(names)):
        out = unit.dir / name
        if (out / "config.json").exists() and (not refresh or (out / "sampling_submission.json").exists()):
            continue
        started = time.monotonic()
        spec = unit.cfg["takes"][name]
        count = len(spec["references"])
        if not 0 <= spec["last"] < count or any(not 0 <= ref < count for _, ref in spec["guides"]):
            # The service refuses a graph that names a missing image node, and the runner would stop.
            raise SystemExit(f"{name}: last and every guide must name one of its {count} references")
        out.mkdir(exist_ok=True)
        pad = spec.get("pad", [0, 0, 0, 0])
        if any(v % 32 for v in pad):
            raise SystemExit(f"{name}: pad {pad} must be multiples of 32")
        w, h = unit.canvas[0] + pad[0] + pad[2], unit.canvas[1] + pad[1] + pad[3]
        at, free = [anchor[0] + pad[0], anchor[1] + pad[1]], [r + q for r, q in zip(room, pad)]
        guides, refs = [], []
        for i, frame_name in enumerate(spec["references"]):
            rgba = guide_image(unit, frame_name, (w, h), at)
            rgba.save(out / f"guide_{i}_rgba.png")
            plate = Image.new("RGBA", (w, h), tuple(unit.cfg["key_rgb"]) + (255,))
            plate.alpha_composite(rgba)
            plate.convert("RGB").save(out / f"guide_{i}_chroma.png")
            guides.append(rgba)
            source = unit.painted[frame_name]["source"].removeprefix("res://")
            refs.append({"frame": frame_name, "source": source, "source_sha256": sha(ROOT / source),
                         "input_file": f"guide_{i}_chroma.png", "input_sha256": sha(out / f"guide_{i}_chroma.png")})
        order = key_order(unit.cfg["key_rgb"])
        protected, threshold, spill, measured = measure(guides, order)
        if PLATE_SEPARATION - threshold < 80:  # clean_edges' limit: the matte would reject every frame
            raise SystemExit(f"{name}: edge threshold {threshold} leaves the plate under 80 of separation; "
                             f"swap the reference richest in plate colour (green plate: gold, blue plate: violet)")
        prompt =unit.cfg["identity"] + " " + spec["action"] + " " + unit.cfg["plate"]
        seed = unit.cfg["seed"] + list(unit.cfg["takes"]).index(name)
        config = {"unit_id": unit.id, "clip": spec["clip"], "canvas": [w, h], "anchor": at, "scale": unit.scale,
                  "key_rgb": unit.cfg["key_rgb"], "seed": seed, "references": spec["references"], "guides": spec["guides"],
                  "last": spec["last"], "prompt": prompt, "protected_foreground_chroma": protected, "edge_threshold": threshold,
                  **({"edge_spill_threshold": spill} if order == GREEN_ORDER else {}),
                  "palette_measurement": dict(measured, rule="opaque guide interiors (alpha>240, eroded 3 px)"),
                  "tiled_decode": unit.cfg.get("tiled_decode", TILED_DECODE), "frames": FRAMES, "fps": FPS}
        write(out / "config.json", config)
        write(out / "reference.json", {"unit_id": unit.id, "guides": refs, "canvas": [w, h], "ground_anchor": at,
                                       "output_scale": unit.scale, "free_pixels_left_top_right_bottom": free,
                                       "rule": "Accepted painted poses at their accepted anchor and scale, divided by the fixed video scale."})
        (out / "prompt.txt").write_text(prompt + "\n", encoding="utf-8", newline="\n")
        graph = {
            "1": node("UNETLoader", unet_name=UNET, weight_dtype="default"),
            "2": node("CLIPLoader", clip_name=TEXT, type="minimax", device="default"),
            "3": node("VAELoader", vae_name=VAE),
            "5": node("MiniMaxH3ImageToVideo", clip=["2", 0], vae=["3", 0], prompt=prompt, width=w, height=h, length=FRAMES,
                      first_frame=["30", 0], last_frame=[str(30 + spec["last"]), 0]),
            "7": node("RandomNoise", noise_seed=seed),
            "8": node("KSamplerSelect", sampler_name="res_multistep"),
            "9": node("BasicScheduler", model=["1", 0], scheduler="simple", steps=20, denoise=1.0),
            "10": node("SamplerCustomAdvanced", noise=["7", 0], guider=["6", 0], sampler=["8", 0], sigmas=["9", 0], latent_image=["5", 1]),
            # H3 samples a nested video/audio latent; keep only the video and save it before decoding.
            "17": node("LTXVSeparateAVLatent", av_latent=["10", 0]),
            "16": node("SaveLatent", samples=["17", 0], filename_prefix=f"h3/{unit.id}/{name}/sampled")}
        for i in range(len(refs)):
            graph[str(30 + i)] = node("LoadImage", image=f"h3_{unit.id}_{name}_guide_{i}.png")
        previous = "5"
        for i, (frame, ref) in enumerate(spec["guides"]):
            graph[str(40 + i)] = node("MiniMaxH3AddGuide", positive=[previous, 0], latent=["5", 1], frame_idx=frame, vae=["3", 0], image=[str(30 + ref), 0])
            previous = str(40 + i)
        graph["6"] = node("BasicGuider", model=["1", 0], conditioning=[previous, 0])
        write(out / "sampling_workflow_api.json", graph)
        timed(out, "prepare", time.monotonic() - started)
        print(f"PREPARED {name}: {len(refs)} guides, canvas {w}x{h}, anchor {at}, unmix guard {protected}, edge threshold {threshold}", flush=True)
        if spec["clip"] == "idle" and len(guides) > 1:
            # A mean over the canvas: rescale a padded take to the unit canvas, since padding adds only empty pixels.
            far = max(pose_distance(guides[0], g) for g in guides[1:]) * w * h / (unit.canvas[0] * unit.canvas[1])
            note = f" (above {IDLE_POSE_FAR}: expect hold-and-pop; pick a pose nearer the neutral)" if far > IDLE_POSE_FAR else ""
            print(f"  idle pose distance {far:.1f}{note}", flush=True)


def upload(name, path):
    boundary = "----H3CreatureAnimation"
    data = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()
            + Path(path).read_bytes() + f"\r\n--{boundary}--\r\n".encode())
    req = urllib.request.Request(URL + "/upload/image", data=data, headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def history_of(prompt_id):
    """The finished job's history, or None while it is queued or running."""
    try:
        history = call("/history/" + prompt_id)
    except OSError as error:
        print("OBSERVATION", type(error).__name__, flush=True)
        return None
    if prompt_id not in history:
        return None
    result = history[prompt_id]
    if result["status"]["status_str"] != "success":
        raise RuntimeError(f"job {prompt_id} failed: {result['status']}")
    return result


def wait(prompt_id):
    while (history := history_of(prompt_id)) is None:
        time.sleep(3)
    return history


def gpu_seconds(history):
    stamps = {kind: data["timestamp"] for kind, data in history["status"]["messages"] if "timestamp" in data}
    return round((stamps["execution_success"] - stamps["execution_start"]) / 1000, 3)


def release_models():
    queue = call("/queue")
    if queue["queue_running"] or queue["queue_pending"]:
        raise RuntimeError("the service still has jobs; models not released")
    call("/free", {"unload_models": True, "free_memory": True})
    for _ in range(60):
        time.sleep(1)
        free = max(d.get("vram_free", 0) for d in call("/system_stats")["devices"])
        if free >= 16 * 1024 ** 3:
            return free
    raise RuntimeError("models did not release 16 GB of VRAM")


def unfinished(jobs):
    """Prepared takes without a collected original, each once."""
    jobs = {(unit.dir, name): (unit, name) for unit, name in jobs
            if (unit.dir / name / "config.json").exists() and not (unit.dir / name / "original.json").exists()}
    return list(jobs.values())


def submit_sampling(unit, name):
    out, started = unit.dir / name, time.monotonic()
    if (out / "sampling_submission.json").exists():
        return
    graph = read(out / "sampling_workflow_api.json")
    uploaded = {}
    for key, item in graph.items():
        if item["class_type"] == "LoadImage":
            guide = out / f"guide_{int(key) - 30}_chroma.png"
            result = upload(item["inputs"]["image"], guide)
            item["inputs"]["image"] = "/".join(v for v in (result.get("subfolder", ""), result["name"]) if v)
            uploaded[key] = dict(result, sha256=sha(guide))
    write(out / "sampling_workflow_api.json", graph)
    submitted = call("/prompt", {"prompt": graph, "client_id": "h3_creature_animation"})
    write(out / "sampling_submission.json", dict(submitted, queued_unix=time.time(), url=URL, uploaded=uploaded))
    timed(out, "upload_and_queue", time.monotonic() - started)
    print(f"QUEUED sampling {unit.id}/{name} {submitted['prompt_id']}", flush=True)


def submitted(job):
    """Queue a take's sampling; a request the service refuses fails that take, not the run."""
    try:
        submit_sampling(*job)
        return True
    except OSError as error:  # urllib's HTTPError is an OSError
        print(f"FAILED submit {job[0].id}/{job[1]}: {error!r}", flush=True)
        return False


def store_latent(unit, name, history):
    out, started = unit.dir / name, time.monotonic()
    write(out / "sampling_history.json", history)
    location = history["outputs"]["16"]["latents"][0]
    (out / "original.latent").write_bytes(fetch(location))
    write(out / "latent.json", {"output": location, "sha256": sha(out / "original.latent")})
    timed(out, "sampling_gpu", gpu_seconds(history))
    timed(out, "latent_fetch", time.monotonic() - started)
    print(f"SAMPLED {unit.id}/{name} in {gpu_seconds(history)} s", flush=True)


def submit_decode(unit, name, freed):
    out = unit.dir / name
    if (out / "decode_submission.json").exists():
        return
    location = read(out / "latent.json")["output"]
    graph = {
        "3": node("VAELoader", vae_name=VAE),
        "10": node("LoadLatent", latent=f"{location['subfolder']}/{location['filename']} [output]".replace("\\", "/")),
        "11": node("VAEDecodeTiled", samples=["10", 0], vae=["3", 0], **read(out / "config.json")["tiled_decode"]),
        "13": node("CreateVideo", images=["11", 0], fps=FPS, bit_depth=8),
        "14": node("SaveVideo", video=["13", 0], filename_prefix=f"h3/{unit.id}/{name}/original", **{"format": "mp4", "format.codec": "h264"}),
        "15": node("SaveImage", images=["11", 0], filename_prefix=f"h3/{unit.id}/{name}/frames/decoded")}
    write(out / "decode_workflow_api.json", graph)
    submitted = call("/prompt", {"prompt": graph, "client_id": "h3_creature_animation"})
    write(out / "decode_submission.json", dict(submitted, queued_unix=time.time(), url=URL, freed_vram_bytes=freed))


def decode_group(jobs):
    """Free the sampling models once, then queue every decode of the group."""
    started = time.monotonic()
    freed = release_models() if any(not (u.dir / n / "decode_submission.json").exists() for u, n in jobs) else None
    for unit, name in jobs:
        submit_decode(unit, name, freed)
    if freed is not None:
        for unit, name in jobs:
            timed(unit.dir / name, "release_models_shared", (time.monotonic() - started) / len(jobs))


def finish(unit, name):
    """Wait for the decode, then keep the lossless original, matte it and draw the review sheets."""
    out = unit.dir / name
    history = wait(read(out / "decode_submission.json")["prompt_id"])
    write(out / "generation_history.json", history)
    timed(out, "decode_gpu", gpu_seconds(history))
    collect(out, history)
    matte(unit, name)
    sheets(unit, name)


def generate(jobs):
    """jobs: [(unit, take names)]; every take of every unit shares one sampling run and one decode run."""
    jobs = unfinished([(unit, name) for unit, names in jobs for name in unit.takes(names)])
    if not jobs:
        return print("nothing to generate")
    queue = call("/queue")
    pending = [(u, n) for u, n in jobs if not (u.dir / n / "sampling_submission.json").exists()]
    if pending and (queue["queue_running"] or queue["queue_pending"]):
        raise SystemExit("the service is busy; nothing queued")
    # All sampling jobs go in at once: the service runs them back to back with the models loaded.
    for unit, name in pending:
        submit_sampling(unit, name)
    for unit, name in jobs:
        if not (unit.dir / name / "original.latent").exists():
            store_latent(unit, name, wait(read(unit.dir / name / "sampling_submission.json")["prompt_id"]))
    decode_group(jobs)
    # Decodes run on the GPU while finished takes are collected and matted here.
    for unit, name in jobs:
        finish(unit, name)


def enqueue(unit, names, join):
    """Prepare the takes and leave a request for the runner. A join request is added to the
    sampling group on the GPU; any other request becomes a later group of its own."""
    prepare(unit, names)
    names = [name for _, name in unfinished([(unit, n) for n in unit.takes(names)])]
    if not names:
        return print("nothing to enqueue")
    QUEUE.mkdir(parents=True, exist_ok=True)
    path = QUEUE / f"{time.time_ns()}_{unit.id}.json"
    write(path.with_suffix(".tmp"), {"unit_dir": rel(unit.dir), "takes": names, "join": join})
    path.with_suffix(".tmp").replace(path)
    print(f"ENQUEUED {unit.id}: {' '.join(names)}" + (" (joins the running group)" if join else ""), flush=True)


def take_requests(join_only):
    """Unfinished takes of the waiting join requests plus, unless join_only, the oldest other
    request: one unit per group, so later requests wait as a buffer. Taken requests leave the queue."""
    jobs, unit_taken = [], join_only
    for path in sorted(QUEUE.glob("*.json")):
        try:
            request = read(path)
            if not request.get("join"):
                if unit_taken:
                    continue
                unit_taken = True
            unit = Unit(ROOT / request["unit_dir"])
            jobs += [(unit, name) for name in unit.takes(request["takes"])]
            path.unlink()
        except (OSError, ValueError, KeyError, SystemExit) as error:
            print(f"BAD REQUEST {path.name}: {error!r}", flush=True)
            path.replace(path.with_suffix(".bad"))
    return unfinished(jobs)


def run(poll):
    """Keep the GPU busy across units. A group's samplings run back to back; when they are done
    the models are freed once, the group's decodes are queued and the next group's samplings go
    in right behind them, so the GPU samples the next group while this one is collected, matted
    and drawn here. READY <unit> means its takes can be reviewed."""
    print(f"RUNNER watching {rel(QUEUE)}", flush=True)
    group = []
    while True:
        if not group:
            group = take_requests(False)
            if not group:
                time.sleep(poll)
                continue
        group = [job for job in group if submitted(job)]
        waiting =[job for job in group if not (job[0].dir / job[1] / "original.latent").exists()]
        while waiting:
            for unit, name in list(waiting):
                try:
                    history = history_of(read(unit.dir / name / "sampling_submission.json")["prompt_id"])
                except RuntimeError as error:
                    print(f"FAILED sampling {unit.id}/{name}: {error}", flush=True)
                    waiting.remove((unit, name))
                    group.remove((unit, name))
                    continue
                if history is not None:
                    store_latent(unit, name, history)
                    waiting.remove((unit, name))
            running = {(u.dir, n) for u, n in group}
            joining = [(u, n) for u, n in take_requests(True) if (u.dir, n) not in running and submitted((u, n))]
            group += joining
            waiting += joining
            if waiting:
                time.sleep(3)
        following = []
        if group:
            decode_group(group)
        for unit, name in group:
            # The next group's samplings queue behind these decodes.
            for u, n in take_requests(bool(following)):
                if (u.dir, n) not in {(v.dir, m) for v, m in following} and submitted((u, n)):
                    following.append((u, n))
            try:
                finish(unit, name)
            except Exception as error:  # one bad take must not stop the run
                print(f"FAILED finish {unit.id}/{name}: {error!r}", flush=True)
        for unit_id in dict.fromkeys(unit.id for unit, _ in group):
            print(f"READY {unit_id}: " + " ".join(n for u, n in group if u.id == unit_id), flush=True)
        group = following


def collect(out, history):
    """Preserve the decoded frames losslessly (FFV1) and prove every RGB frame."""
    started = time.monotonic()
    images = history["outputs"]["15"]["images"]
    if len(images) != FRAMES:
        raise RuntimeError(f"{out.name}: {len(images)} decoded frames")
    size = tuple(read(out / "config.json")["canvas"])
    target = out / "original_lossless.mkv"
    if target.exists():
        raise RuntimeError(f"{out.name}: original already collected")
    # One write in about 150 failed its re-decode, and the same frames passed when written again,
    # so a mismatch is written once more before the take fails.
    for attempt in (1, 2):
        hashes = []
        with av.open(str(target), "w") as container:
            stream = container.add_stream("ffv1", rate=FPS)
            stream.width, stream.height = size
            stream.pix_fmt = "bgr0"
            for item in images:
                image = Image.open(io.BytesIO(fetch(item))).convert("RGB")
                assert image.size == size
                hashes.append(hashlib.sha256(image.tobytes()).hexdigest())
                for packet in stream.encode(av.VideoFrame.from_image(image)):
                    container.mux(packet)
            for packet in stream.encode():
                container.mux(packet)
        with av.open(str(target)) as container:
            if [hashlib.sha256(f.to_image().convert("RGB").tobytes()).hexdigest() for f in container.decode(video=0)] == hashes:
                break
        target.unlink()
        if attempt == 2:
            raise RuntimeError(f"{out.name}: lossless original differs from the decoded frames")
    for item in history["outputs"].get("14", {}).get("images", []) + history["outputs"].get("14", {}).get("animated", []):
        if isinstance(item, dict) and str(item.get("filename", "")).endswith(".mp4"):
            (out / "original.mp4").write_bytes(fetch(item))
    write(out / "original.json", {"frames": FRAMES, "fps": FPS, "size": list(size), "lossless_codec": "ffv1/bgr0", "sha256": sha(target),
                                  "decoded_rgb_sha256": hashes, "sampling_workflow_sha256": sha(out / "sampling_workflow_api.json"),
                                  "decode_workflow_sha256": sha(out / "decode_workflow_api.json"), "latent_sha256": sha(out / "original.latent"),
                                  "models": {"unet": UNET, "text_encoder": TEXT, "vae": VAE}, "settings": {"steps": 20, "sampler": "res_multistep",
                                  "scheduler": "simple", "turbo_lora": False}})
    timed(out, "collect", time.monotonic() - started)


def key_frame(job):
    """Blue-plate unmix (the produce.py recipe), then the edge rule. Returns (RGBA bytes, detail).
    A green plate runs the same rules with green and blue swapped (key_order) and swaps them back,
    and its edge rule also holds green to the palette's spill limit (clean_edges spill)."""
    rgb, protected, threshold, *rest = job
    order = rest[0] if rest else [0, 1, 2]  # a runner started before key_order sends no order
    spill = rest[1] if len(rest) > 1 else None  # nor one started before the spill limit a spill
    rgb = np.ascontiguousarray(rgb[..., order])
    a = rgb.astype(np.float32)
    tiles = [a[:24, :24], a[:24, -24:], a[-24:, :24], a[-24:, -24:]]
    medians = np.array([np.median(t.reshape(-1, 3), axis=0) for t in tiles])
    bg = np.median(medians, axis=0)
    spread = float(np.max(np.linalg.norm(medians - bg, axis=1)))
    separation = bg[2] - max(bg[0], bg[1])
    if spread > 10 or separation < 80:
        return None, {"rejected": f"plate {bg.round(1).tolist()} spread {spread:.1f} separation {separation:.1f}"}
    chroma = a[..., 2] - np.maximum(a[..., 0], a[..., 1])
    alpha = np.clip((separation - chroma) / (separation - protected), 0, 1)
    alpha[np.linalg.norm(a - bg, axis=2) < 12] = 0
    color = np.clip((a - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], 0.001), 0, 255)
    color[..., 2] -= np.maximum(color[..., 2] - np.maximum(color[..., 0], color[..., 1]), 0) * (alpha < 0.98)
    old = np.dstack([color, alpha * 255]).astype("uint8")
    old[old[..., 3] < 8] = 0
    labels, count = label(old[..., 3] >= 8, structure=np.ones((3, 3), dtype=np.uint8))
    keep = np.zeros(count + 1, dtype=bool)
    keep[np.unique(labels[old[..., 3] >= 128])] = True
    keep[0] = False
    old[~keep[labels]] = 0
    try:
        image, stats = clean_edges(Image.fromarray(rgb), Image.fromarray(old, "RGBA"), threshold, spill)
    except ValueError as error:  # a cyan plate: blue barely exceeds green
        return None, {"rejected": str(error)}
    image = np.asarray(image)[..., order + [3]]
    opacity = image[..., 3]
    haze = ((opacity >= 8) & (opacity < 200)).sum() / max(int((opacity >= 200).sum()), 1)
    return np.ascontiguousarray(image).tobytes(), dict(stats, background_rgb=bg[order].round(3).tolist(),
                                                       corner_median_spread=round(spread, 3), haze=round(float(haze), 3))


def matte(unit, name):
    out = unit.dir / name
    started = time.monotonic()
    c = read(out / "config.json")
    with av.open(str(out / "original_lossless.mkv")) as video:
        frames = [f.to_ndarray(format="rgb24") for f in video.decode(video=0)]
    (out / "matte").mkdir(exist_ok=True)
    hashes, details = [], []
    order = key_order(c["key_rgb"])
    spill = c.get("edge_spill_threshold") if order == GREEN_ORDER else None
    if order == GREEN_ORDER and spill is None:  # prepared before the spill limit: measure the take's guides now
        spill = measure([guide_image(unit, f, c["canvas"], c["anchor"]) for f in c["references"]], order)[2]
    with concurrent.futures.ProcessPoolExecutor() as pool:
        jobs = [(f, c["protected_foreground_chroma"], c["edge_threshold"], order, spill) for f in frames]
        results = list(pool.map(key_frame, jobs, chunksize=4))
        # A pulse that darkens only the plate near the figure passes the corner test and leaves a
        # translucent patch fused to the figure. A clean frame's semi-transparent band stays well under
        # half its opaque area; reject frames above that and above three times the take's median, so a
        # translucent creature raises its own limit.
        hazes = [detail["haze"] for data, detail in results if data is not None]
        limit = max(0.5, 3 * float(np.median(hazes))) if hazes else 0
        for i, (data, detail) in enumerate(results):
            if data is not None and detail["haze"] > limit:
                data, detail = None, dict(detail, rejected=f"translucent patch: band {detail['haze']} of the opaque area, limit {limit:.3f}")
            if data is None:
                hashes.append(None)
            else:
                path = out / "matte" / f"rgba_{i:03}.png"
                Image.frombytes("RGBA", tuple(c["canvas"]), data).save(path)
                hashes.append(sha(path))
            details.append(detail)
    write(out / "matte.json", {"frames": FRAMES, "fps": FPS, "rgba_sha256": hashes, "frame_details": details,
                               "protected_foreground_chroma": c["protected_foreground_chroma"], "edge_threshold": c["edge_threshold"],
                               **({"edge_spill_threshold": spill} if spill is not None else {}), "key_rgb": c["key_rgb"],
                               "recipe": "Flat blue plate (corner spread <= 10, separation >= 80): blue-minus-max(red, green) unmix with the "
                                         "measured guard band, edge-only despill, alpha>=8 regions kept when they hold an alpha>=128 pixel; "
                                         "then the 2 px edge band re-solved by tools/rematte_blue_plate.py clean_edges. Geometry unchanged. "
                                         "A green plate swaps green and blue before these rules and back after them, and its edge "
                                         "band also re-solves pixels whose green over max(red, blue) exceeds edge_spill_threshold "
                                         "(guide p99.9 + 6), keeping re-solved green at most that far above max(red, blue), translucent "
                                         "pixels no higher than it. A frame whose "
                                         "alpha 8-199 band exceeds max(0.5, 3 x the take median) of its alpha>=200 area is rejected "
                                         "as a plate pulse."})
    timed(out, "matte", time.monotonic() - started)
    rejected = sum(h is None for h in hashes)
    print(f"MATTED {name}: {FRAMES - rejected} frames" + (f", {rejected} rejected plates" if rejected else ""), flush=True)


def frame_list(text):
    """'28-40,88,90-96' -> [28, ..., 40, 88, 90, ..., 96]."""
    frames = []
    for part in text.split(","):
        first, _, last = part.partition("-")
        frames += range(int(first), int(last or first) + 1)
    return frames


def sheets(unit, name, frames=None):
    """Chronological 8x8 review sheets of every keyed frame; with frames, one close-up sheet
    of just those frames (4 per row, 400 px cells) named <take>_<first>-<last>.png."""
    out = unit.dir / name
    started = time.monotonic()
    target = ROOT / ".artifacts/h3" / unit.id
    target.mkdir(parents=True, exist_ok=True)
    hashes = read(out / "matte.json")["rgba_sha256"]
    available = [i for i, h in enumerate(hashes) if h and (frames is None or i in frames)]
    images = {i: Image.open(out / "matte" / f"rgba_{i:03}.png") for i in available}
    boxes = [im.getbbox() for im in images.values() if im.getbbox()]
    w, h = read(out / "config.json")["canvas"]
    crop = (max(0, min(b[0] for b in boxes) - 8), max(0, min(b[1] for b in boxes) - 8),
            min(w, max(b[2] for b in boxes) + 8), min(h, max(b[3] for b in boxes) + 8))
    columns, cell = (8, (200, 200)) if frames is None else (4, (400, 400))
    per_sheet = columns * columns if frames is None else len(available)
    for part in range(math.ceil(len(available) / per_sheet)):
        chunk = available[part * per_sheet:(part + 1) * per_sheet]
        rows = math.ceil(len(chunk) / columns) if frames else columns
        sheet = Image.new("RGB", (columns * cell[0], rows * cell[1]), (52, 62, 52))
        draw = ImageDraw.Draw(sheet)
        for j, i in enumerate(chunk):
            x, y = j % columns * cell[0], j // columns * cell[1]
            if (j + j // columns) % 2:
                draw.rectangle((x, y, x + cell[0] - 1, y + cell[1] - 1), fill=(196, 188, 168))
            frame = images[i].crop(crop)
            frame.thumbnail((cell[0] - 4, cell[1] - 16), Image.Resampling.LANCZOS)
            sheet.paste(frame, (x + (cell[0] - frame.width) // 2, y + 14), frame)
            draw.text((x + 4, y + 2), str(i), fill=(200, 60, 40))
        suffix = part if frames is None else f"{chunk[0]}-{chunk[-1]}"
        sheet.save(target / f"{name}_{suffix}.png")
    if frames is None:
        timed(out, "sheets", time.monotonic() - started)


def survey(unit_id, archive_dir):
    """Before writing h3_unit.json: restore the unit's painted sources, draw every live painted
    frame by clip with its name (.artifacts/h3/<unit>/painted.png) and suggest a scale."""
    live = read(ROOT / "art/animation/source/fluid" / unit_id / "reviewed_handoff.json")["units"][0]
    sources = sorted({f["source"].removeprefix("res://") for f in live["frames"]})
    target = ROOT / ".artifacts/h3" / unit_id
    target.mkdir(parents=True, exist_ok=True)
    missing = [s for s in sources if not (ROOT / s).exists()]
    if missing:
        if not archive_dir:
            raise SystemExit(f"{len(missing)} painted sources are archived; pass --archive-dir")
        (target / "restore_paths.txt").write_text("\n".join(missing) + "\n", encoding="utf-8")
        import subprocess
        subprocess.run([sys.executable, "-B", str(ROOT / "tools/restore_archived_source_material.py"), "--archive-dir", str(archive_dir),
                        "--paths-file", str(target / "restore_paths.txt"), "--apply"], cwd=ROOT, check=True)
    poses = {f["name"]: source_pose(f, f.get("alpha_noise_cutoff", 0)) for f in live["frames"]}
    left = min(x for _, (x, y) in poses.values())
    top = min(y for _, (x, y) in poses.values())
    w = max(x + p.width for p, (x, y) in poses.values()) - left
    h = max(y + p.height for p, (x, y) in poses.values()) - top
    # Video px = runtime px / scale; every painted frame fits with 40 px to spare per side.
    scale = math.ceil(max(w / (960 - 80), h / (640 - 80)) * 100) / 100
    rows = list(live["clips"].items())
    # A long video clip (an earlier H3 move) would shrink every row; draw at most 8 of its frames.
    shown = {clip: v["indices"] if len(v["indices"]) <= 8 else [v["indices"][round(k * (len(v["indices"]) - 1) / 7)] for k in range(8)]
             for clip, v in rows}
    cw = w + 8
    sheet = Image.new("RGB", (cw * max(len(v) for v in shown.values()), (h + 22) * len(rows)), (52, 62, 52))
    draw = ImageDraw.Draw(sheet)
    for r, (clip, spec) in enumerate(rows):
        for c, i in enumerate(shown[clip]):
            name = live["frames"][i]["name"]
            x0, y0 = c * cw, r * (h + 22)
            if (r + c) % 2:
                draw.rectangle((x0, y0, x0 + cw - 1, y0 + h + 21), fill=(196, 188, 168))
            pose, (x, y) = poses[name]
            sheet.paste(pose, (x0 + 4 + x - left, y0 + 18 + y - top), pose)
            draw.text((x0 + 3, y0 + 2), name, fill=(200, 40, 30))
    if sheet.width > 2400:
        sheet = sheet.resize((2400, round(sheet.height * 2400 / sheet.width)), Image.Resampling.LANCZOS)
    sheet.save(target / "painted.png")
    print(f"UNIT_DIR {Path(sources[0]).parent.as_posix()}")
    print("CLIPS " + ", ".join(f"{k} {len(v['indices'])}" for k, v in rows))
    print(f"RUNTIME EXTENT {w}x{h} px; suggested scale {scale} (largest painting enlarged "
          f"{max(f['scale'] for f in live['frames']) / scale:.2f}x); sheet {rel(target / 'painted.png')}")


CLIP_MSEC = {"idle": 60, "move": 50, "attack": 42, "ranged": 42, "hit": 35, "defend": 42, "cast": 45, "death": 45}
CLIP_FRAMES = {"attack": 34, "ranged": 36, "hit": 24, "defend": 22, "cast": 30, "death": 34}
CLIP_END = {"attack": 0.97, "ranged": 0.97, "cast": 0.96, "hit": 0.93, "defend": 0.9, "death": 0.985}


def propose(unit, names):
    """A starting h3_selection.json from the motion in the matte frames: every second frame of
    the idle, one gait cycle of the move, and for actions the moving span (quiet lead-in and
    tail trimmed) sampled densely where the figure moves fast and sparsely where it is slow.
    Named takes update just their clips in an existing selection; review before building."""
    path = unit.dir / "h3_selection.json"
    selection = read(path) if path.exists() else {"clips": {}, "preserved_accepted_clips": [],
                                                   "visual_review": {"status": "pending", "notes": ""}}
    if names:
        chosen = {unit.cfg["takes"][n]["clip"]: n for n in unit.takes(names)}
    elif selection["clips"]:
        raise SystemExit(f"{rel(path)} exists; name the takes to propose again")
    else:  # the latest matted take of each clip
        chosen = {s["clip"]: n for n, s in unit.cfg["takes"].items() if (unit.dir / n / "matte.json").exists()}
    for clip, name in chosen.items():
        hashes = read(unit.dir / name / "matte.json")["rgba_sha256"]
        frames = {}
        for i, h in enumerate(hashes):
            if h:
                image = Image.open(unit.dir / name / "matte" / f"rgba_{i:03}.png")
                frames[i] = np.asarray(image.resize((image.width // 4, image.height // 4), Image.Resampling.BILINEAR)).astype(np.float32)
        idx = sorted(frames)
        lit = {i: frames[i][..., :3] * frames[i][..., 3:] / 255 for i in idx}
        motion = [0.0] + [float(np.abs(lit[b] - lit[a]).mean() + np.abs(frames[b][..., 3] - frames[a][..., 3]).mean() / 2)
                          for a, b in zip(idx, idx[1:])]
        if clip == "idle":
            picked = [i for i in idx if i % 2 == 0]
        elif clip == "move":
            picked = [i for i in idx if i % 2 == 0 and i <= 60]
        else:
            cum = np.cumsum(motion)
            first = idx[max(0, int(np.searchsorted(cum, cum[-1] * (0.015 if clip == "death" else 0.02))) - 2)]
            last = idx[min(len(idx) - 1, int(np.searchsorted(cum, cum[-1] * CLIP_END[clip])) + 2)]
            span = [i for i in idx if first <= i <= last]
            # Rejected plates can split the span; the pose jumps across a long gap, so keep the
            # run that holds most of the motion and say so.
            runs = [[span[0]]]
            for i in span[1:]:
                if i - runs[-1][-1] > 12:
                    runs.append([])
                runs[-1].append(i)
            if len(runs) > 1:
                span = max(runs, key=lambda r: sum(motion[idx.index(i)] for i in r[1:]))
                print(f"{clip:7} {name:16} GAP: rejected plates split the action; kept video {span[0]}-{span[-1]}")
            cum = np.cumsum([0.0] + [motion[idx.index(i)] for i in span[1:]])
            picks = sorted({span[0], span[-1]} | {span[int(np.searchsorted(cum, cum[-1] * k / (CLIP_FRAMES[clip] - 1)))]
                                                  for k in range(1, CLIP_FRAMES[clip] - 1)})
            picked = [picks[0]]
            for p in picks[1:]:  # no gap longer than 12 video frames
                while p - picked[-1] > 12:
                    fill = next(i for i in span if i > picked[-1] + 6)
                    if fill >= p:
                        break
                    picked.append(fill)
                picked.append(p)
            rest = [i for i in idx if i >= span[-1]]
            if clip == "death" and idx[-1] not in picked and all(b - a <= 12 for a, b in zip(rest, rest[1:])):
                picked.append(idx[-1])  # the corpse, unless rejected plates lie between
        entry = {"segments": [{"take": name, "frames": picked}], "frame_msec": CLIP_MSEC[clip]}
        if clip in ("attack", "ranged"):  # contact: the figure reaches furthest toward screen right
            core = picked[len(picked) // 6: len(picked) * 5 // 6]
            reach = {i: np.where(frames[i][..., 3].max(axis=0) > 128)[0].max(initial=0) for i in core}
            entry["contact_frame"] = picked.index(max(core, key=reach.get))
        elif clip == "cast":
            entry["contact_frame"] = len(picked) // 2
        selection["clips"][clip] = entry
        print(f"{clip:7} {name:16} {len(picked):3} frames {len(picked) * CLIP_MSEC[clip] / 1000:.2f} s, video {picked[0]}-{picked[-1]}"
              + (f", contact video {picked[entry['contact_frame']]}" if "contact_frame" in entry else "")
              + (f", {124 - len(idx)} REJECTED plates" if len(idx) < 124 else ""))
    order = ["idle", "move", "attack", "ranged", "hit", "defend", "cast", "death"]
    selection["clips"] = dict(sorted(selection["clips"].items(), key=lambda kv: order.index(kv[0]) if kv[0] in order else 99))
    text = json.dumps(selection, indent=2)
    text = re.sub(r"\[\s+([\d,\s]+?)\s+\]", lambda m: "[" + " ".join(m.group(1).split()) + "]", text)
    path.write_text(text + "\n", encoding="utf-8", newline="\n")
    print(f"WROTE {rel(path)}")


FIT_FLOOR = {"attack": 14, "ranged": 14, "cast": 14, "hit": 8, "defend": 10, "death": 14}


def kept_poses(unit, clips):
    """Poses the publisher packs beside the selection: the clips of the last reviewed delivery and
    of the baseline sheet that the selection does not replace (publish combine, then pack_unit)."""
    source = ROOT / "art/animation/source/fluid" / unit.id
    if not (source / "baseline.json").exists():
        return []
    poses, replaced = [], set(clips)
    if (source / "reviewed_handoff.json").exists():
        previous = read(source / "reviewed_handoff.json")["units"][0]
        for name, spec in previous["clips"].items():
            if name not in replaced:
                poses += [source_pose(previous["frames"][i], previous["frames"][i].get("alpha_noise_cutoff", 0)) for i in spec["indices"]]
        replaced |= set(previous["clips"])
    baseline = read(source / "baseline.json")
    legacy = [n for n in baseline["pose_clips"] if n not in replaced and not (n == "dead" and "death" in replaced)]
    if legacy:
        sheet = source / "baseline.png"
        if not sheet.exists():
            raise SystemExit(f"{rel(sheet)} is archived; restore it first, the atlas keeps the legacy clips {legacy}")
        with Image.open(sheet) as image:
            for name in legacy:
                poses += [old_pose(image, baseline, i) for i in clip_indices(baseline["pose_clips"][name], baseline["pose_columns"])]
    return poses


def fit(unit):
    """Thin the selection until every pose packs into one 4096 px atlas, as the publisher packs
    it, together with the older clips the publisher keeps (kept_poses). Each step drops the
    action frame whose neighbours differ least, so holds go first; the idle and move loops, each
    clip's first, last and contact frames, gaps over 16 video frames and the FIT_FLOOR counts
    stay. A dropped frame's own hold passes to the frame before it."""
    path = unit.dir / "h3_selection.json"
    selection = read(path)
    configs, poses, small = {}, {}, {}
    kept = kept_poses(unit, selection["clips"])
    if kept:
        print(f"the atlas also keeps {len(kept)} poses of older clips")

    def pose(take, i):
        if (take, i) not in poses:
            c = configs.setdefault(take, read(unit.dir / take / "config.json"))
            poses[take, i] = source_pose({"name": f"{take}_{i:03}", "source": rel(unit.dir / take / "matte" / f"rgba_{i:03}.png"),
                                          "rects": [[0, 0, *c["canvas"]]], "anchor": c["anchor"], "scale": c["scale"]})
        return poses[take, i]

    def jump(take, a, b):
        for i in (a, b):
            if (take, i) not in small:
                image = Image.open(unit.dir / take / "matte" / f"rgba_{i:03}.png")
                small[take, i] = np.asarray(image.resize((image.width // 4, image.height // 4), Image.Resampling.BILINEAR)).astype(np.float32)
        x, y = small[take, a], small[take, b]
        return float(np.abs(x[..., :3] * x[..., 3:] - y[..., :3] * y[..., 3:]).mean() / 255 + np.abs(x[..., 3] - y[..., 3]).mean() / 2)

    dropped = {}
    while True:
        try:
            pack_compact(kept + [pose(s["take"], i) for spec in selection["clips"].values() for s in spec["segments"] for i in s["frames"]])
            break
        except ValueError:
            pass
        candidates = []
        for clip, spec in selection["clips"].items():
            frames = spec["segments"][0]["frames"]
            if clip not in FIT_FLOOR or len(spec["segments"]) != 1 or len(frames) <= FIT_FLOOR[clip]:
                continue
            contact = frames[spec["contact_frame"]] if "contact_frame" in spec else None
            candidates += [(jump(spec["segments"][0]["take"], frames[k - 1], frames[k + 1]), clip, k)
                           for k in range(1, len(frames) - 1) if frames[k] != contact and frames[k + 1] - frames[k - 1] <= 16]
        if not candidates:
            raise SystemExit("the selection cannot thin further and still overflows one 4096 px atlas; it needs split pages")
        _, clip, k = min(candidates)
        spec = selection["clips"][clip]
        frames = spec["segments"][0]["frames"]
        contact = frames[spec["contact_frame"]] if "contact_frame" in spec else None
        if "frame_durations_msec" in spec:
            spec["frame_durations_msec"][k - 1] += spec["frame_durations_msec"].pop(k)
        dropped.setdefault(clip, []).append(frames.pop(k))
        if contact is not None:
            spec["contact_frame"] = frames.index(contact)
    for clip, frames in dropped.items():
        print(f"{clip:7} dropped {len(frames):2} frames, video {sorted(frames)}; {len(selection['clips'][clip]['segments'][0]['frames'])} left")
    print(f"FITS {sum(len(s['frames']) for spec in selection['clips'].values() for s in spec['segments'])} poses in one 4096 px atlas")
    text = json.dumps(selection, indent=2)
    text = re.sub(r"\[\s+([\d,\s]+?)\s+\]", lambda m: "[" + " ".join(m.group(1).split()) + "]", text)
    path.write_text(text + "\n", encoding="utf-8", newline="\n")


def build(unit):
    selection = read(unit.dir / "h3_selection.json")
    frames, clips, provenance, used = [], {}, {}, []
    for clip, spec in selection["clips"].items():
        start = len(frames)
        for segment in spec["segments"]:
            out = unit.dir / segment["take"]
            c, matte_record = read(out / "config.json"), read(out / "matte.json")
            assert c["clip"] == clip or segment.get("borrowed_from_clip") == c["clip"], (clip, segment["take"])
            for i in segment["frames"]:
                path = out / "matte" / f"rgba_{i:03}.png"
                assert matte_record["rgba_sha256"][i] and sha(path) == matte_record["rgba_sha256"][i], (segment["take"], i)
                frames.append({"name": f"{segment['take']}_{i:03}", "clip": clip, "source": rel(path), "rects": [[0, 0, *c["canvas"]]],
                               "anchor": c["anchor"], "scale": c["scale"], "alpha_noise_cutoff": 0, "video_frame": i,
                               "video_time_seconds": round(i / FPS, 4)})
            used.append(segment["take"])
        entry = {"indices": list(range(start, len(frames))), "frame_msec": spec["frame_msec"], "loop": clip in ("idle", "move"),
                 "static_frame": len(frames) - start - 1 if clip in ("death", "defend") else 0}
        for k in ("contact_frame", "frame_durations_msec"):
            if k in spec:
                entry[k] = spec[k]
        clips[clip] = entry
    for take in dict.fromkeys(used):
        out = unit.dir / take
        for n in ("original_lossless.mkv", "original.json", "original.latent", "sampling_workflow_api.json", "decode_workflow_api.json",
                  "sampling_history.json", "generation_history.json", "prompt.txt", "reference.json", "config.json", "matte.json"):
            provenance[f"{take}/{n}"] = {"path": rel(out / n), "sha256": sha(out / n)}
    entry = {"unit_id": unit.id, "reference_height": unit.live.get("reference_height", 256), "source_facing": unit.live.get("source_facing", "right"),
             "frames": frames, "clips": clips, "alpha_noise_cutoff": 0,
             "source_scale_reason": "Guides are the accepted paintings at their accepted scale; every video frame keeps one fixed extraction scale and anchor.",
             "provenance": provenance, "preserved_accepted_clips": selection.get("preserved_accepted_clips", []),
             "visual_review": selection.get("visual_review", {"status": "pending", "notes": ""})}
    write(unit.dir / "handoff.json", {"schema_version": 1, "units": [entry]})
    print(f"BUILT {unit.dir / 'handoff.json'}: " + ", ".join(f"{k} {len(v['indices'])}" for k, v in clips.items()))


def profile(unit):
    rows = []
    for name in unit.takes():
        path = unit.dir / name / "timing.json"
        if path.exists():
            rows.append((name, read(path)))
    stages = list(dict.fromkeys(k for _, t in rows for k in t))
    print("take".ljust(22) + "".join(s[:14].rjust(15) for s in stages) + "total".rjust(10))
    for name, t in rows:
        print(name.ljust(22) + "".join(f"{t.get(s, 0):15.1f}" for s in stages) + f"{sum(t.values()):10.1f}")
    print("sum".ljust(22) + "".join(f"{sum(t.get(s, 0) for _, t in rows):15.1f}" for s in stages) + f"{sum(sum(t.values()) for _, t in rows):10.1f}")


def main():
    global URL
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("verb", choices=["survey", "prepare", "generate", "enqueue", "run", "matte", "sheets", "propose", "fit", "build", "profile"])
    parser.add_argument("unit_dir", type=Path, nargs="?")
    parser.add_argument("takes", nargs="*")
    parser.add_argument("--url", default=URL)
    parser.add_argument("--batch", type=Path, nargs="+", default=[], metavar="UNIT_DIR",
                        help="generate: also every prepared take of these units, in the same run")
    parser.add_argument("--frames", type=frame_list, help="sheets: close-up of these frames, e.g. 28-40,88")
    parser.add_argument("--join", action="store_true", help="enqueue: add the takes to the group the runner is sampling")
    parser.add_argument("--refresh", action="store_true", help="prepare: rewrite takes that are queued but not yet submitted")
    parser.add_argument("--poll", type=float, default=10, help="run: seconds between looks at an empty queue")
    parser.add_argument("--archive-dir", type=Path, help="survey: newest source-art snapshot, for archived paintings")
    args = parser.parse_args()
    URL = args.url.rstrip("/")
    if args.verb == "run":
        return run(args.poll)
    if args.unit_dir is None:
        parser.error(f"{args.verb} needs a UNIT_DIR")
    if args.verb == "survey":
        return survey(str(args.unit_dir), args.archive_dir)
    unit = Unit(args.unit_dir)
    if args.verb == "prepare":
        prepare(unit, args.takes, args.refresh)
    elif args.verb == "generate":
        generate([(unit, args.takes)] + [(Unit(d), None) for d in args.batch])
    elif args.verb == "enqueue":
        enqueue(unit, args.takes, args.join)
    elif args.verb == "matte":
        for name in unit.takes(args.takes):
            matte(unit, name)
    elif args.verb == "sheets":
        for name in unit.takes(args.takes):
            sheets(unit, name, args.frames)
    elif args.verb == "propose":
        propose(unit, args.takes)
    elif args.verb == "fit":
        fit(unit)
    elif args.verb == "build":
        build(unit)
    else:
        profile(unit)


if __name__ == "__main__":
    main()
