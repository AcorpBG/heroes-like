#!/usr/bin/env python3
"""Animate one creature with local MiniMax H3 video, from its painted poses to a candidate handoff.

The shared form of the per-unit produce.py / stage_video.py / prepare.py copies.
A unit is described by <unit_dir>/h3_unit.json:

  unit_id, identity (prompt text), plate (prompt text), canvas [w, h], scale (runtime px
  per video px), key_rgb, seed, optional anchor [x, y] and tiled_decode, and "takes":
  {take_name: {clip, references: [painted frame names], guides: [[video_frame, ref]],
  last: ref, action: prompt text}}. Append new takes (retakes too) at the end: a take's
  seed is the unit seed plus its position.

References name frames of the unit's live reviewed handoff
(art/animation/source/fluid/<unit>/reviewed_handoff.json), so each guide is an accepted
painting at its accepted anchor and scale. One anchor and scale serve every take of a
unit; prepare fits them once (h3_layout.json). Run with a Python that has Pillow, NumPy,
SciPy and PyAV; the ComfyUI service is http://127.0.0.1:8189 unless --url says otherwise.

  prepare  UNIT_DIR [TAKE...]  guides, prompts and graphs for takes not prepared yet
  generate UNIT_DIR [TAKE...]  queue every sampling job, free the models, queue the decodes;
                               then collect lossless originals, matte and draw review sheets;
                               --batch UNIT_DIR... adds other prepared units to the same run
  matte    UNIT_DIR TAKE...    matte again: blue-plate unmix plus the edge rule of
                               tools/rematte_blue_plate.py (no purple rim on red edges)
  sheets   UNIT_DIR TAKE...    chronological review sheets under .artifacts/h3/<unit>/;
                               --frames 28-40,88 draws a close-up sheet of just those frames
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
from integrate_fluid_creature_animation import source_pose  # noqa: E402
from rematte_blue_plate import clean_edges  # noqa: E402

FRAMES, FPS = 124, 24
UNET = "minimax_h3_fl2va_pruned_int8_convrot.safetensors"
TEXT = "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
VAE = "minimax_h3_video_vae_int8_convrot.safetensors"
TILED_DECODE = {"tile_size": 512, "overlap": 64, "temporal_size": 16, "temporal_overlap": 4}
MARGIN = 24          # free pixels every guide keeps from the canvas edge
UNMIX_MARGIN = 2     # protected foreground chroma: bluest opaque guide pixel plus this
EDGE_MARGIN = 6      # edge-rule threshold: guide blue-minus-green p99.9 plus this
URL = "http://127.0.0.1:8189"


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


class Unit:
    def __init__(self, directory):
        self.dir = Path(directory).resolve()
        self.cfg = read(self.dir / "h3_unit.json")
        self.id = self.cfg["unit_id"]
        live = ROOT / "art/animation/source/fluid" / self.id / "reviewed_handoff.json"
        self.live = read(live)["units"][0]
        self.painted = {f["name"]: f for f in self.live["frames"]}
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


def measure(guides):
    """Blue in the painted palette: the unmix guard band and the edge-rule threshold."""
    worst, values = 0.0, []
    for rgba in guides:
        a = np.asarray(rgba).astype(float)
        inner = binary_erosion(a[..., 3] > 240, iterations=3)
        worst = max(worst, float((a[..., 2] - np.maximum(a[..., 0], a[..., 1]))[inner].max()))
        values.append(a[..., 2][inner] - a[..., 1][inner])
    p999 = float(np.percentile(np.concatenate(values), 99.9))
    return max(0, int(worst) + UNMIX_MARGIN), max(6, math.ceil(p999) + EDGE_MARGIN), {"bluest_opaque": worst, "blue_minus_green_p999": p999}


def prepare(unit, names):
    anchor, room = unit.layout()
    for n, name in enumerate(unit.takes(names)):
        out = unit.dir / name
        if (out / "config.json").exists():
            continue
        started = time.monotonic()
        spec = unit.cfg["takes"][name]
        out.mkdir()
        w, h = unit.canvas
        guides, refs = [], []
        for i, frame_name in enumerate(spec["references"]):
            pose, (x, y) = unit.guide_pose(frame_name)
            rgba = Image.new("RGBA", (w, h))
            rgba.alpha_composite(pose, (anchor[0] + x, anchor[1] + y))
            rgba.save(out / f"guide_{i}_rgba.png")
            plate = Image.new("RGBA", (w, h), tuple(unit.cfg["key_rgb"]) + (255,))
            plate.alpha_composite(rgba)
            plate.convert("RGB").save(out / f"guide_{i}_chroma.png")
            guides.append(rgba)
            source = unit.painted[frame_name]["source"].removeprefix("res://")
            refs.append({"frame": frame_name, "source": source, "source_sha256": sha(ROOT / source),
                         "input_file": f"guide_{i}_chroma.png", "input_sha256": sha(out / f"guide_{i}_chroma.png")})
        protected, threshold, measured = measure(guides)
        prompt = unit.cfg["identity"] + " " + spec["action"] + " " + unit.cfg["plate"]
        seed = unit.cfg["seed"] + list(unit.cfg["takes"]).index(name)
        config = {"unit_id": unit.id, "clip": spec["clip"], "canvas": [w, h], "anchor": anchor, "scale": unit.scale,
                  "key_rgb": unit.cfg["key_rgb"], "seed": seed, "references": spec["references"], "guides": spec["guides"],
                  "last": spec["last"], "prompt": prompt, "protected_foreground_chroma": protected, "edge_threshold": threshold,
                  "palette_measurement": dict(measured, rule="opaque guide interiors (alpha>240, eroded 3 px)"),
                  "tiled_decode": unit.cfg.get("tiled_decode", TILED_DECODE), "frames": FRAMES, "fps": FPS}
        write(out / "config.json", config)
        write(out / "reference.json", {"unit_id": unit.id, "guides": refs, "canvas": [w, h], "ground_anchor": anchor,
                                       "output_scale": unit.scale, "free_pixels_left_top_right_bottom": room,
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
        print(f"PREPARED {name}: {len(refs)} guides, anchor {anchor}, unmix guard {protected}, edge threshold {threshold}", flush=True)


def upload(name, path):
    boundary = "----H3CreatureAnimation"
    data = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()
            + Path(path).read_bytes() + f"\r\n--{boundary}--\r\n".encode())
    req = urllib.request.Request(URL + "/upload/image", data=data, headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def wait(prompt_id):
    while True:
        try:
            history = call("/history/" + prompt_id)
        except OSError as error:
            print("OBSERVATION", type(error).__name__, flush=True)
            history = {}
        if prompt_id in history:
            result = history[prompt_id]
            if result["status"]["status_str"] != "success":
                raise RuntimeError(f"job {prompt_id} failed: {result['status']}")
            return result
        time.sleep(3)


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


def generate(jobs):
    """jobs: [(unit, take names)]; every take of every unit shares one sampling run and one decode run."""
    jobs = {(unit.dir.resolve(), name): (unit, name) for unit, names in jobs for name in unit.takes(names)
            if (unit.dir / name / "config.json").exists() and not (unit.dir / name / "original.json").exists()}
    jobs = list(jobs.values())
    if not jobs:
        return print("nothing to generate")
    queue = call("/queue")
    pending = [(u, n) for u, n in jobs if not (u.dir / n / "sampling_submission.json").exists()]
    if pending and (queue["queue_running"] or queue["queue_pending"]):
        raise SystemExit("the service is busy; nothing queued")
    # All sampling jobs go in at once: the service runs them back to back with the models loaded.
    for unit, name in pending:
        out, started = unit.dir / name, time.monotonic()
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
    for unit, name in jobs:
        out = unit.dir / name
        if (out / "original.latent").exists():
            continue
        job = read(out / "sampling_submission.json")
        history = wait(job["prompt_id"])
        write(out / "sampling_history.json", history)
        started = time.monotonic()
        location = history["outputs"]["16"]["latents"][0]
        (out / "original.latent").write_bytes(fetch(location))
        write(out / "latent.json", {"output": location, "sha256": sha(out / "original.latent")})
        timed(out, "sampling_gpu", gpu_seconds(history))
        timed(out, "latent_fetch", time.monotonic() - started)
        print(f"SAMPLED {unit.id}/{name} in {gpu_seconds(history)} s", flush=True)
    started = time.monotonic()
    freed = release_models() if any(not (u.dir / n / "decode_submission.json").exists() for u, n in jobs) else None
    for unit, name in jobs:
        out = unit.dir / name
        if (out / "decode_submission.json").exists():
            continue
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
    if freed is not None:
        for unit, name in jobs:
            timed(unit.dir / name, "release_models_shared", (time.monotonic() - started) / len(jobs))
    # Decodes run on the GPU while finished takes are collected and matted here.
    for unit, name in jobs:
        out = unit.dir / name
        history = wait(read(out / "decode_submission.json")["prompt_id"])
        write(out / "generation_history.json", history)
        timed(out, "decode_gpu", gpu_seconds(history))
        collect(out, history)
        matte(unit, name)
        sheets(unit, name)


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
        if [hashlib.sha256(f.to_image().convert("RGB").tobytes()).hexdigest() for f in container.decode(video=0)] != hashes:
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
    """Blue-plate unmix (the produce.py recipe), then the edge rule. Returns (RGBA bytes, detail)."""
    rgb, protected, threshold = job
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
        image, stats = clean_edges(Image.fromarray(rgb), Image.fromarray(old, "RGBA"), threshold)
    except ValueError as error:  # a cyan plate: blue barely exceeds green
        return None, {"rejected": str(error)}
    return image.tobytes(), dict(stats, background_rgb=bg.round(3).tolist(), corner_median_spread=round(spread, 3))


def matte(unit, name):
    out = unit.dir / name
    started = time.monotonic()
    c = read(out / "config.json")
    with av.open(str(out / "original_lossless.mkv")) as video:
        frames = [f.to_ndarray(format="rgb24") for f in video.decode(video=0)]
    (out / "matte").mkdir(exist_ok=True)
    hashes, details = [], []
    with concurrent.futures.ProcessPoolExecutor() as pool:
        jobs = [(f, c["protected_foreground_chroma"], c["edge_threshold"]) for f in frames]
        for i, (data, detail) in enumerate(pool.map(key_frame, jobs, chunksize=4)):
            if data is None:
                hashes.append(None)
            else:
                path = out / "matte" / f"rgba_{i:03}.png"
                Image.frombytes("RGBA", tuple(c["canvas"]), data).save(path)
                hashes.append(sha(path))
            details.append(detail)
    write(out / "matte.json", {"frames": FRAMES, "fps": FPS, "rgba_sha256": hashes, "frame_details": details,
                               "protected_foreground_chroma": c["protected_foreground_chroma"], "edge_threshold": c["edge_threshold"],
                               "recipe": "Flat blue plate (corner spread <= 10, separation >= 80): blue-minus-max(red, green) unmix with the "
                                         "measured guard band, edge-only despill, alpha>=8 regions kept when they hold an alpha>=128 pixel; "
                                         "then the 2 px edge band re-solved by tools/rematte_blue_plate.py clean_edges. Geometry unchanged."})
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


def build(unit):
    selection = read(unit.dir / "h3_selection.json")
    frames, clips, provenance, used = [], {}, {}, []
    w, h = unit.canvas
    for clip, spec in selection["clips"].items():
        start = len(frames)
        for segment in spec["segments"]:
            out = unit.dir / segment["take"]
            c, matte_record = read(out / "config.json"), read(out / "matte.json")
            assert c["clip"] == clip or segment.get("borrowed_from_clip") == c["clip"], (clip, segment["take"])
            for i in segment["frames"]:
                path = out / "matte" / f"rgba_{i:03}.png"
                assert matte_record["rgba_sha256"][i] and sha(path) == matte_record["rgba_sha256"][i], (segment["take"], i)
                frames.append({"name": f"{segment['take']}_{i:03}", "clip": clip, "source": rel(path), "rects": [[0, 0, w, h]],
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
    parser.add_argument("verb", choices=["prepare", "generate", "matte", "sheets", "build", "profile"])
    parser.add_argument("unit_dir", type=Path)
    parser.add_argument("takes", nargs="*")
    parser.add_argument("--url", default=URL)
    parser.add_argument("--batch", type=Path, nargs="+", default=[], metavar="UNIT_DIR",
                        help="generate: also every prepared take of these units, in the same run")
    parser.add_argument("--frames", type=frame_list, help="sheets: close-up of these frames, e.g. 28-40,88")
    args = parser.parse_args()
    URL = args.url.rstrip("/")
    unit = Unit(args.unit_dir)
    if args.verb == "prepare":
        prepare(unit, args.takes)
    elif args.verb == "generate":
        generate([(unit, args.takes)] + [(Unit(d), None) for d in args.batch])
    elif args.verb == "matte":
        for name in unit.takes(args.takes):
            matte(unit, name)
    elif args.verb == "sheets":
        for name in unit.takes(args.takes):
            sheets(unit, name, args.frames)
    elif args.verb == "build":
        build(unit)
    else:
        profile(unit)


if __name__ == "__main__":
    main()
